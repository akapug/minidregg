#!/usr/bin/env python3
"""objective-manifest.py -- the Objective contract manifests and their ratchet.

The scanner (Verify/ObjectiveManifest.lean, run by scripts/ObjectiveManifest.lean and
scripts/ObjectiveManifestMathlib.lean) writes, per run, the covered declarations (`R` lines), the
constant records of their closure (`C` lines) and the expression DAG those records point into
(node lines). This tool hashes them and ratchets the result against the pinned per-module
manifests, scripts/gates/objective-manifest/<Module>.tsv.

Hashes (SHA-256 throughout):
  node     H(tag, fields, child node hashes): a Merkle hash of the elaborated term, binder names
           and metadata excluded, universe parameters by name.
  self     H(kind, universe parameters, shape, root node hashes) of one constant: its type, plus
           its body for a definition, plus the shape and constructors of an inductive. A leaf of
           the cut (outside the repository, an axiom, an opaque) has its type only.
  stmt     H(kind, universe parameters, type node hash): the elaborated statement (constants it
           mentions by name: the statement as written).
  closure  the CONTENT of the constant: the self hash in which every repository constant a term
           mentions is replaced by that constant's content, recursively (members of a cycle -- an
           inductive and its constructors -- by position). A verbatim move or rename of a
           definition, or a new constant nothing old mentions (a @[csimp] twin), changes no
           closure; a changed definition body anything reaches does (`def Safe := True` under an
           unchanged theorem). Proofs are never in it: a theorem's content is its statement.
  contract H(key, kind, stmt, closure, axioms): the row's recorded identity.

Manifest row (tab-separated): kind, key, contract, stmt, closure, self (first 16 hex), axioms,
statement text. The key is the shown name, `private <name> @<module>` for a private one. A row's
contract is recomputed on load: a hand-edited pin refuses to load.

The ratchet, per key (every event but rerendered needs a DECISION):
  added       not pinned                                    RED unless a decision admits it
  removed     pinned, gone                                  RED unless a decision admits it
  restated    kind or stmt hash changed                     RED unless a decision admits it
  redefined   stmt same, closure (content) changed          RED unless a decision admits it
  axioms      stmt and closure same, axiom set changed      RED unless a decision admits it
  rerendered  hashes and axioms same, text differs          passes; `pin` refreshes the text
The decisions, scripts/gates/objective-contract-decisions.txt, one admitted event per line:
  name <TAB> old <TAB> new <TAB> kind <TAB> commit <TAB> reason
where old/new are the event's witnesses, `-` for the absent side:
  added (-, W(new))  removed (W(old), -)  restated (W(old), W(new))   W = H(kind, stmt)
  redefined (old closure, new closure)    axioms (H(old axioms), H(new axioms))
An entry admits exactly that (name, old, new, kind). A REMOVED row is admitted only when its reason
says what replaces it (ROOT, 10-07, after b23 let `replay_changed_ingress_refused` go with no successor):
  successor: <Full.Name>[, <Full.Name>...] [-- note]   every name a declaration of the fresh run
                                                        (a private one by its full name, without `private`/`@Module`)
  derivable: <how it follows from what remains>
  obsolete: <why the claim no longer applies>
A RESTATED theorem's reason says why the new statement is at least as strong (review rule).
`pin` writes nothing unless every event is admitted; `pin --rehash` (once, when the hash itself
changes) re-pins closures and contracts only, refusing any statement, axiom or key event.

usage:
  objective-manifest.py check  --pins DIR --decisions FILE RUN...   ratchet; exit 1 on any red
  objective-manifest.py pin    --pins DIR --decisions FILE RUN...   ratchet, then write the pins
  objective-manifest.py draft  --pins DIR --decisions FILE RUN...   print decision lines (reason TODO,
                                                                 which the gate refuses) for review
  objective-manifest.py draft --attribute FROM..TO --out LINES --review REVIEW ... the same lines with
      commit and reason filled from the commits of FROM..TO that touched each change's cause module
      (UNATTRIBUTED + TODO where none did), plus a review file: every removed and restated row by
      name with its commit, redefined rows grouped by root. Appending LINES is the reviewer's act.
  objective-manifest.py expect --pins DIR --decisions FILE RUN --changed KEY=KIND[:VIA]... [--plant KEY] [--against RUN0]
      a scratch run (a copy of one module, mutated): every public row it shows must match its pin
      except the named ones, which must classify as KIND (and, for `redefined`, name VIA among the
      changed definitions of their closure), and the ratchet must be red on them; --plant KEY: KEY
      must classify `added` and the ratchet must pass; --against RUN0: compare with RUN0's rows
      instead of the pins.
  objective-manifest.py selftest --pins DIR --decisions FILE RUN... the ratchet logic on synthetic
      removals, restatements, redefinitions, additions and decisions over the real rows.
"""
import argparse
import hashlib
import os
import re
import sys

KINDS = ("added", "removed", "restated", "redefined", "axioms")
HEX64 = re.compile(r"^[0-9a-f]{64}$")


def H(*parts):
    h = hashlib.sha256()
    for p in parts:
        if isinstance(p, str):
            p = p.encode()
        h.update(len(p).to_bytes(4, "big"))
        h.update(p)
    return h.digest()


class Run:
    """One scanner output: rows with their hashes."""

    def __init__(self, path):
        self.path = path
        nodes = []
        raw = []  # per node: (tag, payload, child ids) for the content hash
        self.consts = {}  # name -> [internal, kind, lps, extra, roots, deps]
        raw_rows = []
        failures = []
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\n")
                t = line[:1]
                if t == "C":
                    p = line.split("\t")
                    roots = [int(r) for r in p[6].split()]
                    self.consts[p[1]] = [p[2] == "I", p[3], p[4], p[5], roots, p[7:]]
                elif t == "R":
                    raw_rows.append(line.split("\t", 6))
                elif t == "a":
                    _, i, j = line.split(" ")
                    nodes.append(H("a", nodes[int(i)], nodes[int(j)]))
                    raw.append(("a", "", (int(i), int(j))))
                elif t in ("l", "f"):
                    _, bi, i, j = line.split(" ")
                    nodes.append(H(t, bi, nodes[int(i)], nodes[int(j)]))
                    raw.append((t, bi, (int(i), int(j))))
                elif t == "t":
                    _, nd, i, j, k = line.split(" ")
                    nodes.append(H("t", nd, nodes[int(i)], nodes[int(j)], nodes[int(k)]))
                    raw.append(("t", nd, (int(i), int(j), int(k))))
                elif t == "p":
                    _, idx, j, s = line.split(" ", 3)
                    nodes.append(H("p", idx, s, nodes[int(j)]))
                    raw.append(("p", (idx, s), (int(j),)))
                elif t == "c":
                    nodes.append(H("leaf", line))
                    _, lv, name = line.split(" ", 2)
                    raw.append(("c", lv, name))
                elif t in ("b", "s", "n", "x"):
                    nodes.append(H("leaf", line))
                    raw.append(("leaf", line, ()))
                elif t in ("F", "M"):
                    failures.append(f"instrument: a free variable or metavariable in a constant: {line}")
                    nodes.append(H("leaf", line))
                    raw.append(("leaf", line, ()))
                else:
                    failures.append(f"instrument: unparseable line in {path}: {line[:80]}")
        if failures:
            raise SystemExit("\n".join(failures[:20]))
        self.self_ = {}
        self.stmt = {}
        for name, (internal, kind, lps, extra, roots, _deps) in self.consts.items():
            self.self_[name] = H("C", kind, lps, extra, "I" if internal else "E",
                                 *[nodes[r] for r in roots])
            self.stmt[name] = H("S", kind, lps, nodes[roots[0]])
        self.closure = self._content_closures(raw)
        self.rows = {}
        for _, name, shown, module, kind, axioms, text in raw_rows:
            key = f"{shown} @{module}" if shown.startswith("private ") else shown
            if name not in self.consts:
                raise SystemExit(f"instrument: row {name} has no constant record")
            row = Row(kind, key, self.stmt[name].hex(), self.closure[name].hex(),
                      self.self_[name].hex()[:16], axioms, text, module)
            row.name = name
            if key in self.rows:
                raise SystemExit(f"instrument: two rows with key {key}")
            self.rows[key] = row

    def deps(self, name):
        c = self.consts[name]
        return [d for d in c[5] if d in self.consts] if c[0] else []

    def _components(self):
        """Strongly connected components of the constant graph, callees first (iterative Tarjan)."""
        index, low, onstack, stack, comps = {}, {}, set(), [], []
        counter = 0
        for root in self.consts:
            if root in index:
                continue
            work = [(root, iter(self.deps(root)))]
            index[root] = low[root] = counter
            counter += 1
            stack.append(root)
            onstack.add(root)
            while work:
                v, it = work[-1]
                advanced = False
                for w in it:
                    if w not in index:
                        index[w] = low[w] = counter
                        counter += 1
                        stack.append(w)
                        onstack.add(w)
                        work.append((w, iter(self.deps(w))))
                        advanced = True
                        break
                    elif w in onstack:
                        low[v] = min(low[v], index[w])
                if advanced:
                    continue
                work.pop()
                if work:
                    u = work[-1][0]
                    low[u] = min(low[u], low[v])
                if low[v] == index[v]:
                    members = []
                    while True:
                        w = stack.pop()
                        onstack.discard(w)
                        members.append(w)
                        if w == v:
                            break
                    comps.append(sorted(members))
        return comps

    def _content_closures(self, raw):
        """The closure hash by CONTENT, not by name: a repository constant a term mentions is hashed
        as the content of that constant (its kind, universe parameters, shape and roots, the
        constants it mentions hashed the same way), so moving or renaming a definition verbatim,
        or adding a constant nothing old mentions (a @[csimp] twin), moves no closure; changing a
        body anything reaches does. Inside a cycle (an inductive, its constructors) a member is
        named by its position in the component. A constant outside the repository is named (it
        has no content in the run). The row's own name is not in its closure hash: the key is."""
        comps = self._components()
        comp_of = {m: i for i, ms in enumerate(comps) for m in ms}
        cyclic = {i for i, ms in enumerate(comps) if len(ms) > 1 or ms[0] in self.deps(ms[0])}
        content = {}
        gmemo = [None] * len(raw)

        def internal(name):
            c = self.consts.get(name)
            return c is not None and c[0]

        def ref(name, levels, rec):
            if internal(name):
                if rec is not None and name in rec:
                    return H("rec", levels, str(rec[name]))
                if name not in content:
                    raise SystemExit(f"instrument: {name} hashed before its component")
                return H("cref", levels, content[name])
            return H("ext", levels, name)

        def compute(n, get, rec):
            tag, payload, kids = raw[n]
            if tag == "c":
                return ref(kids, payload, rec)
            if tag == "p":
                return H("p2", payload[0], ref(payload[1], "", rec), get(kids[0]))
            return H("n2", tag, payload, *[get(k) for k in kids])

        def hash_node(root, memo, rec):
            stack = [root]
            while stack:
                n = stack[-1]
                if memo[n] is not None:
                    stack.pop()
                    continue
                kids = raw[n][2] if raw[n][0] != "c" else ()
                missing = [k for k in kids if memo[k] is None]
                if missing:
                    stack.extend(missing)
                    continue
                memo[n] = compute(n, memo.__getitem__, rec)
                stack.pop()
            return memo[root]

        def extra_of(kind, extra):
            # constructor and inductive names are positions in the component, not part of the content
            if kind == "inductive":
                return " ".join(x if "=" not in x else x.split("=")[0] + "=" + str(len([y for y in x.split("=", 1)[1].split(",") if y]))
                                for x in extra.split(" "))
            if kind == "ctor":
                return " ".join(extra.split(" ")[1:])
            return extra

        for cid, members in enumerate(comps):
            if cid in cyclic:
                rec = {m: i for i, m in enumerate(members)}
                memo = [None] * len(raw)
            else:
                rec, memo = None, gmemo
            pre = []
            for m in members:
                internal_, kind, lps, extra, roots, _ = self.consts[m]
                pre.append(H("C2", kind, lps, extra_of(kind, extra), "I" if internal_ else ("E:" + m),
                             *[hash_node(r, memo, rec) for r in roots]))
            if cid in cyclic:
                k = H("K2", *pre)
                for i, m in enumerate(members):
                    content[m] = H("M2", k, str(i))
            else:
                content[members[0]] = pre[0]
        return content

    def reach(self, name):
        seen, todo = set(), [name]
        while todo:
            n = todo.pop()
            if n in seen:
                continue
            seen.add(n)
            todo.extend(self.deps(n))
        return seen


class Row:
    def __init__(self, kind, key, stmt, closure, self16, axioms, text, module):
        self.kind, self.key, self.stmt, self.closure = kind, key, stmt, closure
        self.self16, self.axioms, self.text, self.module = self16, axioms, text, module
        self.contract = H("R", key, kind, stmt, closure, axioms).hex()
        self.name = None

    def line(self):
        return "\t".join([self.kind, self.key, self.contract, self.stmt, self.closure,
                          self.self16, self.axioms, self.text])


CONSTANTS = "constants.content"  # in the pins directory: every repository constant's name-based self and content
PIN_CONSTS = {}  # name -> (self16, content hex) of the pinned constants


def consts_of(runs):
    out = {}
    for r in runs:
        for n, c in r.consts.items():
            if c[0]:
                out[n] = (r.self_[n].hex()[:16], r.closure[n].hex())
    return out


def write_constants(d, runs):
    with open(os.path.join(d, CONSTANTS), "w", encoding="utf-8") as f:
        f.write("# every repository constant the covered rows reach: name, self (by name, 16 hex), content (64 hex).\n"
                "# A constant whose content AND own body changed is a CAUSE: a redefined row is admitted by a\n"
                "# decision for each cause in its closure (scripts/objective-manifest.py).\n")
        for n, (s16, c) in sorted(consts_of(runs).items()):
            f.write(f"{n}\t{s16}\t{c}\n")


def load_pins(d):
    pins, problems = {}, []
    if not os.path.isdir(d):
        return pins, [f"no manifest directory {d}"]
    PIN_CONSTS.clear()
    cpath = os.path.join(d, CONSTANTS)
    if os.path.exists(cpath):
        for line in open(cpath, encoding="utf-8"):
            if line.startswith("#") or not line.strip():
                continue
            n, s16, c = line.rstrip("\n").split("\t")
            PIN_CONSTS[n] = (s16, c)
    for fn in sorted(os.listdir(d)):
        if fn == CONSTANTS:
            continue
        if not fn.endswith(".tsv"):
            problems.append(f"{d}/{fn}: not a manifest (expected <Module>.tsv)")
            continue
        module = fn[:-4]
        for n, line in enumerate(open(os.path.join(d, fn), encoding="utf-8"), 1):
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            p = line.split("\t", 7)
            if len(p) != 8:
                problems.append(f"{fn}:{n}: malformed row")
                continue
            kind, key, contract, stmt, closure, self16, axioms, text = p
            row = Row(kind, key, stmt, closure, self16, axioms, text, module)
            if row.contract != contract:
                problems.append(f"{fn}:{n}: {key}: the contract hash does not match the row (hand-edited pin)")
            if key in pins:
                problems.append(f"{fn}:{n}: {key}: pinned twice")
            pins[key] = row
    return pins, problems


def load_decisions(path):
    admitted, problems = {}, []
    if not os.path.exists(path):
        return admitted, [f"no decisions file {path}"]
    for n, line in enumerate(open(path, encoding="utf-8"), 1):
        line = line.rstrip("\n")
        if not line.strip() or line.startswith("#"):
            continue
        p = line.split("\t")
        if len(p) != 6:
            problems.append(f"decisions:{n}: expected 6 tab-separated fields (name, old, new, kind, commit, reason)")
            continue
        name, old, new, kind, commit, reason = p
        if kind not in KINDS:
            problems.append(f"decisions:{n}: kind {kind!r} is not one of {', '.join(KINDS)}")
        if (kind == "added") != (old == "-") or (old != "-" and not HEX64.match(old)):
            problems.append(f"decisions:{n}: old must be `-` exactly when the kind is added, else a SHA-256 hex digest")
        if (kind == "removed") != (new == "-") or (new != "-" and not HEX64.match(new)):
            problems.append(f"decisions:{n}: new must be `-` exactly when the kind is removed, else a SHA-256 hex digest")
        if not commit.strip() or not reason.strip() or reason.strip() == "TODO":
            problems.append(f"decisions:{n}: a commit and a reason are required")
        admitted[(name, old, new, kind)] = (n, reason.strip())
    return admitted, problems


REMOVAL_REASON = re.compile(r"^(successor|derivable|obsolete):\s*(\S.*)$")


def removal_refusal(reason, fresh):
    """Why a removed row's decision reason does not admit it, or None. `successor:` names must be
    declarations of the fresh run (full names, comma- or space-separated, before an optional ` -- `)."""
    m = REMOVAL_REASON.match(reason)
    if not m:
        return "a removal's reason must start with `successor:`, `derivable:` or `obsolete:`"
    if m.group(1) != "successor":
        return None
    names = [x for x in re.split(r"[,\s]+", m.group(2).split(" -- ")[0]) if x]
    if not names:
        return "`successor:` names no declaration"
    private = {k.split(" @")[0][len("private "):] for k in fresh if k.startswith("private ")}
    missing = [x for x in names if x not in fresh and x not in private]
    if missing:
        return f"successor not a declaration of this run: {', '.join(missing)}"
    return None


def with_entry_reason(admitted, key, reason):
    out = dict(admitted)
    out[key] = (0, reason)
    return out


def classify(p, f):
    if f is None:
        return "removed"
    if p is None:
        return "added"
    if p.kind != f.kind or p.stmt != f.stmt:
        return "restated"
    if p.closure != f.closure:
        return "redefined"
    if p.axioms != f.axioms:
        return "axioms"
    if p.text != f.text or p.module != f.module:
        return "rerendered"
    return "same"


def fresh_rows(runs):
    rows = {}
    for r in runs:
        for k, row in r.rows.items():
            if k in rows:
                raise SystemExit(f"instrument: {k} is covered by two runs (the partition overlaps)")
            rows[k] = (row, r)
    return rows


AUX = re.compile(r"\.(match_\d+|_proof_\d+|proof_\d+|eq_\d+|eq_def|_unfold|_sunfold|_unary|_binary|_mutual|_cstage\d*|_spec_\d+|_rarg|_lambda_\d+|_closed_\d+|_aux_\d+)$")


def owner(n, run):
    """A compiler-generated auxiliary (`f.match_3`, `f._proof_1`, ...) is part of the declaration
    it was generated for: a decision names `f` and admits the change of `f`'s content."""
    while True:
        m = AUX.search(n)
        if not m:
            return n
        parent = n[:m.start()]
        if parent not in run.consts or parent not in PIN_CONSTS:
            return n
        n = parent


def via(run, row, pins):
    """The CAUSES in `row`'s closure: pinned constants whose content and own body both changed
    (a constant whose content moved only because a dependency changed is not a cause; one whose
    own body changed is, also when a dependency changed too). Without pinned constants: the
    pinned rows of the closure whose own self hash changed."""
    if PIN_CONSTS:
        out = set()
        for n in run.reach(row.name):
            pc = PIN_CONSTS.get(n)
            if pc and run.consts[n][0] and pc[1] != run.closure[n].hex() and pc[0] != run.self_[n].hex()[:16]:
                out.add(owner(n, run))
        return sorted(out)
    out = []
    for n in sorted(run.reach(row.name)):
        p = pins.get(n)  # a public constant's key is its name
        if p is not None and p.self16 != run.self_[n].hex()[:16]:
            out.append(n)
    return out


REFUSALS = {}  # key -> why its removal entry did not admit it (for the report)


def witness(kind, p, f):
    """The (old, new) pair a decision names for an event: what the event is about, nothing else,
    so an admitted restatement stays admitted when a later closure moves under it."""
    w = lambda r: H("W", r.kind, r.stmt).hex()
    a = lambda r: H("A", r.axioms).hex()
    if kind == "added":
        return "-", w(f)
    if kind == "removed":
        return w(p), "-"
    if kind == "restated":
        return w(p), w(f)
    if kind == "redefined":
        return p.closure, f.closure
    if kind == "axioms":
        return a(p), a(f)
    return (p.contract if p else "-"), (f.contract if f else "-")


def ratchet(pins, fresh, admitted, partial=False):
    """[(kind, key, old, new, row, run, ok)] for every key that is not `same`."""
    out = []
    keys = set(fresh) if partial else set(pins) | set(fresh)
    for k in sorted(keys):
        p = pins.get(k)
        f, run = fresh.get(k, (None, None))
        kind = classify(p, f)
        if kind == "same":
            continue
        old, new = witness(kind, p, f)
        entry = admitted.get((k, old, new, kind))
        ok = kind == "rerendered" or entry is not None
        if not ok and kind == "redefined" and PIN_CONSTS:
            causes = via(run, f, pins)
            ok = bool(causes) and all((n, PIN_CONSTS[n][1], run.closure[n].hex(), "redefined") in admitted for n in causes)
        why = None
        if ok and kind == "removed":
            why = removal_refusal(entry[1], fresh)
            ok = why is None
        out.append((kind, k, old, new, f, run, ok))
        if why:
            REFUSALS[k] = f"decisions:{entry[0]}: {why}"
    return out


def report(changes, pins, label):
    red = 0
    counts = {}
    for kind, k, old, new, f, run, ok in changes:
        counts[kind] = counts.get(kind, 0) + 1
        if kind == "rerendered":
            continue
        tag = "admitted" if ok else "RED"
        line = f"{label}: {tag} {kind} {k} old={old} new={new}"
        if not ok and k in REFUSALS:
            line += f" ({REFUSALS[k]})"
        if kind == "redefined" and f is not None:
            v = via(run, f, pins)
            line += f" via {', '.join(v[:12]) + (' ...' if len(v) > 12 else '') if v else '(a generated or unpinned constant of its closure)'}"
        print(line)
        red += not ok
    added = [k for kind, k, *_ in changes if kind == "added"]
    summary = ", ".join(f"{n} {k}" for k, n in sorted(counts.items())) or "no changes"
    unpinned = len(added) + counts.get("rerendered", 0)
    print(f"{label}: {summary}; {red} unadmitted"
          + (f"; {unpinned} rows unpinned: `scripts/check-objective-proofs.sh proofs --pin` and commit" if unpinned else ""))
    return red


def write_pins(d, pins, fresh, changes, runs=None):
    new = dict(pins)
    for kind, k, old, new_c, f, run, ok in changes:
        assert ok
        if kind == "removed":
            del new[k]
        else:
            new[k] = f
    by_module = {}
    for k, row in new.items():
        by_module.setdefault(row.module, []).append(row)
    os.makedirs(d, exist_ok=True)
    for fn in os.listdir(d):
        if fn.endswith(".tsv") and fn[:-4] not in by_module:
            os.remove(os.path.join(d, fn))
    for module, rows in by_module.items():
        if module == "<local>":
            raise SystemExit("pin: refusing to pin a scratch run's rows")
        with open(os.path.join(d, module + ".tsv"), "w", encoding="utf-8") as f:
            f.write(f"# {module}: Objective contract manifest. Written by `scripts/check-objective-proofs.sh proofs --pin`;\n"
                    f"# an added, removed, restated, redefined or re-axiomed row needs a line in scripts/gates/objective-contract-decisions.txt.\n")
            for row in sorted(rows, key=lambda r: r.key):
                f.write(row.line() + "\n")
    if runs is not None:
        write_constants(d, runs)


def cmd_expect(a, pins, admitted):
    run = Run(a.runs[0])
    if a.against:
        # compare with another run of the same tree instead of the pins (the planted-theorem
        # self-test: the plant run must be the run plus the plant, whatever the tree changed)
        against = Run(a.against)
        pins = against.rows
        PIN_CONSTS.clear()
        PIN_CONSTS.update(consts_of([against]))
    fresh = {k: (r, run) for k, r in run.rows.items() if not k.startswith("private ")}
    changes = {c[1]: c for c in ratchet(pins, fresh, admitted, partial=True)}
    want = {}
    for spec in a.changed:
        key, kind = spec.rsplit("=", 1)
        kind, _, v = kind.partition(":")
        want[key] = (kind, v)
    failures = []
    for key, (kind, v) in want.items():
        c = changes.get(key)
        if c is None and kind == "removed" and key in pins and key not in fresh:
            # partial: the scratch run covers one module, so a removal is read off directly
            old_w, _ = witness("removed", pins[key], None)
            ok = (key, old_w, "-", "removed") in admitted
            print(f"expect: {key}: removed old={old_w} new=- {'admitted' if ok else 'RED'}")
            if ok:
                failures.append(f"{key}: the ratchet admitted it (expected RED)")
            continue
        if c is None:
            failures.append(f"{key}: unchanged against its pin (expected {kind})")
            continue
        if c[0] != kind:
            failures.append(f"{key}: classified {c[0]} (expected {kind})")
        if c[6]:
            failures.append(f"{key}: the ratchet admitted it (expected RED)")
        if kind == "redefined":
            p = pins[key]
            if p.text != c[4].text:
                failures.append(f"{key}: the statement text changed (the plant must keep it identical)")
            names = via(run, c[4], pins)
            if v and v not in names:
                failures.append(f"{key}: the report does not name {v} (named: {names[:12]})")
        print(f"expect: {key}: {c[0]} old={c[2]} new={c[3]} {'admitted' if c[6] else 'RED'}"
              + (f" via {', '.join(via(run, c[4], pins)[:6])}" if c[0] == "redefined" else ""))
    if a.plant:
        c = changes.get(a.plant)
        if c is None or c[0] != "added" or c[6]:
            failures.append(f"{a.plant}: expected an addition the gate refuses without a decision, got "
                            f"{(c[0] + (' admitted' if c[6] else '')) if c else 'nothing'}")
    unexpected = [c for k, c in changes.items() if k not in want and k != a.plant and c[0] not in ("rerendered",)
                  and not (a.allow_downstream and c[0] == "redefined")]
    for c in unexpected[:10]:
        failures.append(f"{c[1]}: unexpected {c[0]}")
    compared = len(fresh)
    if compared < a.floor:
        failures.append(f"only {compared} rows compared (floor {a.floor})")
    for f in failures:
        print(f"expect: FAIL {f}")
    # a scratch copy's rows carry module `<local>`: that alone is `rerendered`, not a contract change
    differ = sum(1 for c in changes.values() if c[0] != "rerendered")
    print(f"expect: {compared} rows compared, {differ} differ in contract, {len(failures)} failure(s)")
    return 1 if failures else 0


def cmd_selftest(pins, fresh, admitted):
    """The ratchet's own logic on synthetic changes of the real rows."""
    failures = []
    thm = next(k for k, (r, _) in sorted(fresh.items()) if r.kind == "theorem" and k in pins)
    base = dict(fresh)

    def red_on(mut, kind, key):
        ch = [c for c in ratchet(pins, mut, admitted) if c[1] == key]
        return ch and ch[0][0] == kind and not ch[0][6], ch

    def verdict(mut, adm, key):
        return [c[6] for c in ratchet(pins, mut, adm) if c[1] == key]

    def with_entry(mut, key):
        # only `key`'s verdict: the tree itself may carry other (real) changes
        ch = [c for c in ratchet(pins, mut, admitted) if c[1] == key][0]
        adm = with_entry_reason(admitted, (key, ch[2], ch[3], ch[0]), "obsolete: selftest")
        good = verdict(mut, adm, key) == [True]
        bad = True
        if ch[3] != "-":
            wrong = with_entry_reason(admitted, (key, ch[2], "0" * 64, ch[0]), "obsolete: selftest")
            bad = verdict(mut, wrong, key) == [False]
        other = "restated" if ch[0] != "restated" else "redefined"
        bad = bad and verdict(mut, with_entry_reason(admitted, (key, ch[2], ch[3], other), "obsolete: selftest"), key) == [False]
        return good, bad

    def mutated(field, value):
        r, run = base[thm]
        r2 = Row(r.kind, r.key, r.stmt, r.closure, r.self16, r.axioms, r.text, r.module)
        setattr(r2, field, value)
        r2.contract = H("R", r2.key, r2.kind, r2.stmt, r2.closure, r2.axioms).hex()
        r2.name = r.name
        m = dict(base)
        m[thm] = (r2, run)
        return m

    r0, run0 = base[thm]
    plant = Row("theorem", "Minidregg.ObjectiveManifest.Plant.selftest", r0.stmt, r0.closure, r0.self16,
                r0.axioms, r0.text, r0.module)
    with_plant = dict(base)
    with_plant[plant.key] = (plant, run0)
    cases = [("removed", {k: v for k, v in base.items() if k != thm}),
             ("restated", mutated("stmt", "1" * 64)),
             ("redefined", mutated("closure", "2" * 64)),
             ("axioms", mutated("axioms", "sorryAx"))]
    cases = [(kind, m, thm) for kind, m in cases] + [("added", with_plant, plant.key)]
    for kind, m, key in cases:
        ok, ch = red_on(m, kind, key)
        if not ok:
            failures.append(f"{kind} of {key}: not RED as {kind} ({ch})")
            continue
        good, bad = with_entry(m, key)
        if not good:
            failures.append(f"{kind} of {key}: the exact decision did not admit it")
        if not bad:
            failures.append(f"{kind} of {key}: a decision with the wrong new witness or kind admitted it")
    gone = {k: v for k, v in base.items() if k != thm}
    rm = [c for c in ratchet(pins, gone, admitted) if c[1] == thm][0]
    other = next(k for k in sorted(gone) if k != thm)
    priv = next((k.split(" @")[0][len("private "):] for k in sorted(gone) if k.startswith("private ")), None)
    for reason, want in [("removed: module changed by a commit (attributed)", False),
                         ("successor:", False),
                         ("successor: Minidregg.ObjectiveManifest.NoSuchSuccessor", False),
                         (f"successor: {thm} -- itself, which this removal deletes", False),
                         (f"successor: {other} -- the selftest's stand-in", True),
                         *([(f"successor: {priv} -- a private declaration, named without its key", True)] if priv else []),
                         ("derivable: by the stand-in", True),
                         ("obsolete: the claim no longer applies", True)]:
        got = verdict(gone, with_entry_reason(admitted, (thm, rm[2], rm[3], "removed"), reason), thm)
        if got != [want]:
            failures.append(f"removal reason {reason!r}: {'admitted' if got == [True] else 'RED'}, expected {'admitted' if want else 'RED'}")
    # a closure that moves under an admitted restatement does not re-open it: the witness is the statement
    rs = mutated("stmt", "1" * 64)
    ch = [c for c in ratchet(pins, rs, admitted) if c[1] == thm][0]
    adm = with_entry_reason(admitted, (thm, ch[2], ch[3], "restated"), "obsolete: selftest")
    r1, run1 = rs[thm]
    r2 = Row(r1.kind, r1.key, r1.stmt, "3" * 64, r1.self16, r1.axioms, r1.text, r1.module)
    r2.name = r1.name
    rs2 = dict(rs)
    rs2[thm] = (r2, run1)
    if verdict(rs2, adm, thm) != [True]:
        failures.append("a restatement admitted by its decision is re-opened by a closure move")
    for f in failures:
        print(f"selftest: FAIL {f}")
    print(f"selftest: added/removed/restated/redefined/axioms of {thm} RED, admitted by their exact decision only "
          f"(not a wrong new witness, not a wrong kind); a removal only with successor/derivable/obsolete (a named successor must exist); "
          f"an admitted restatement survives a closure move: {'PASS' if not failures else 'FAIL'}")
    return 1 if failures else 0


def git(*args):
    import subprocess
    r = subprocess.run(["git", *args], capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit(f"attribute: git {' '.join(args)}: {r.stderr.strip()}")
    return r.stdout


def cmd_attribute(a, pins, changes):
    """Ledger lines for every unadmitted change, each attributed to the commits of RANGE that touched
    the source module of its cause: the row's own module for removed/restated/axioms; for redefined,
    the modules of the pinned rows its closure reaches whose own content changed (`via`), else its own.
    A change no commit of the range explains keeps commit UNATTRIBUTED and reason TODO, which the
    gate refuses: a human must place it. Writes the lines to --out and a review to --review."""
    rng = a.attribute
    if ".." not in rng:
        raise SystemExit("attribute: expected FROM..TO")
    order = git("rev-list", "--reverse", rng).split()
    pos = {c: i for i, c in enumerate(order)}
    subject = {}
    touch = {}

    def note(cs):
        for c in cs:
            if c not in subject:
                subject[c] = git("log", "-1", "--format=%s", c).strip()
        return sorted(cs, key=lambda c: pos.get(c, -1))

    def commits(mod):
        if mod not in touch:
            path = mod.replace(".", "/") + ".lean"
            touch[mod] = note(git("log", "--format=%H", rng, "--", path).split())
        return touch[mod]

    narrow = {}

    def commits_for(name, mod):
        """The commits of RANGE touching `mod`, narrowed to those whose diff of it has a line naming
        `name`'s last component, when that narrowing is non-empty."""
        if (name, mod) not in narrow:
            cs = commits(mod)
            short = re.escape(name.replace("private ", "").split(" @")[0].rsplit(".", 1)[-1])
            hit = git("log", "--format=%H", f"-G\\b{short}\\b", rng, "--", mod.replace(".", "/") + ".lean").split() if cs else []
            narrow[(name, mod)] = note(hit) if hit else cs
        return narrow[(name, mod)]

    module_of_const = {k: r.module for k, r in pins.items()}

    def const_module(n):
        m = re.match(r"_private\.(.*?)\.0\.", n)
        if m:
            return m.group(1)
        parts = n.split(".")
        for i in range(len(parts), 0, -1):
            pre = ".".join(parts[:i])
            if pre in module_of_const:
                return module_of_const[pre]
        return None

    def candidates(run, f):
        """Touched modules of the row's closure: where a change outside the pinned rows can be."""
        mods = {const_module(n) for n in run.reach(f.name) if run.consts[n][0]}
        return sorted(m for m in mods if m and commits(m))

    lines, review_rows, by_root = [], [], {}
    for kind, k, old, new, f, run, ok in changes:
        if ok:
            continue
        own = (f.module if f is not None else pins[k].module)
        roots = via(run, f, pins) if kind == "redefined" else []
        causes = [(r, pins[r].module) for r in roots if r in pins] or [(k, own)]
        mods = sorted({m for _, m in causes})
        cs = sorted({c for r, m in causes for c in commits_for(r, m)}, key=lambda c: pos.get(c, -1))
        if cs:
            commit = "+".join(c[:8] for c in cs)
            reason = (("TODO successor:|derivable:|obsolete: -- " if kind == "removed" else "")
                      + ("TODO why the new statement is at least as strong -- " if kind == "restated" else "")
                      + f"{kind}: {', '.join(mods)} changed by "
                      + "; ".join(f"{c[:8]} {subject[c][:90]}" for c in cs) + f" (attributed by module, {rng})")
        else:
            # nothing in the range touched the row's module or a pinned root: the cause is a generated
            # or private constant elsewhere in the closure. The commit field lists the candidates (the
            # touched modules of its closure); the reason stays TODO, which the gate refuses.
            cand = candidates(run, f) if f is not None and kind == "redefined" else []
            ccs = sorted({c for m in cand for c in commits(m)}, key=lambda c: pos.get(c, -1))
            commit = "UNATTRIBUTED:" + ("+".join(c[:8] for c in ccs) or "none")
            reason = "TODO"
            mods = cand
        lines.append("\t".join([k, old, new, kind, commit, reason]))
        if kind == "redefined":
            key = ", ".join(roots[:3]) + (" ..." if len(roots) > 3 else "") if roots else "(a generated or unpinned constant)"
            if not roots and commit.startswith("UNATTRIBUTED"):
                key = f"(outside the pins; closure candidates {', '.join(mods) or 'none'})"
            g = by_root.setdefault(key, [0, set()])
            g[0] += 1
            g[1].update(cs)
        else:
            k_kind = pins[k].kind if k in pins else (f.kind if f else "?")
            review_rows.append((kind, k_kind, k, commit))
    with open(a.out, "w") as fh:
        fh.write(f"# attributed by objective-manifest.py draft --attribute {rng}: {len(lines)} changes\n")
        for x in lines:
            fh.write(x + "\n")
    with open(a.review, "w") as fh:
        fh.write(f"# review for {rng}: every added, removed, restated and axioms row (theorems first), redefined rows grouped by root\n")
        for kind in ("added", "removed", "restated", "axioms"):
            rows = sorted((r for r in review_rows if r[0] == kind), key=lambda r: (r[1] != "theorem", r[2]))
            fh.write(f"## {kind}: {len(rows)}\n")
            for _, kk, key, commit in rows:
                fh.write(f"{kk}\t{key}\t{commit}\n")
                if kind == "restated":
                    fresh = next(f for ck, k, _, _, f, _, _ in changes if ck == kind and k == key)
                    fh.write(f"  old statement: {pins[key].text}\n")
                    fh.write(f"  new statement: {fresh.text}\n")
        fh.write(f"## redefined: {sum(g[0] for g in by_root.values())} rows, {len(by_root)} root groups\n")
        for key, (n, cs) in sorted(by_root.items(), key=lambda x: -x[1][0]):
            fh.write(f"{n}\t{key}\t{'+'.join(c[:8] for c in sorted(cs, key=lambda c: pos.get(c, -1))) or 'UNATTRIBUTED (reason TODO: place by hand)'}\n")
    un = sum(1 for x in lines if "\tUNATTRIBUTED" in x)
    print(f"attribute: {len(lines)} decision lines -> {a.out} ({un} UNATTRIBUTED, refused until placed); review -> {a.review}")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("command", choices=["check", "pin", "draft", "expect", "selftest"])
    ap.add_argument("--pins", required=True)
    ap.add_argument("--decisions", required=True)
    ap.add_argument("--rehash", action="store_true",
                    help="pin: re-pin closures/contracts after a change of the hash itself; refuses any other event")
    ap.add_argument("--label", default="objective-manifest")
    ap.add_argument("--changed", action="append", default=[])
    ap.add_argument("--plant")
    ap.add_argument("--against", help="expect: compare with this run's rows instead of the pins")
    ap.add_argument("--floor", type=int, default=1)
    ap.add_argument("--attribute", metavar="FROM..TO", help="draft: attribute each change to the commits of FROM..TO")
    ap.add_argument("--out", help="draft --attribute: write the decision lines here")
    ap.add_argument("--review", help="draft --attribute: write the review (removed, restated, redefined by root) here")
    ap.add_argument("--allow-downstream", action="store_true",
                    help="expect: other rows of the scratch module may be `redefined` (they reach the plant)")
    ap.add_argument("runs", nargs="+")
    a = ap.parse_args()
    pins, problems = load_pins(a.pins)
    admitted, lproblems = load_decisions(a.decisions)
    problems += lproblems
    for p in problems:
        print(f"{a.label}: {p}")
    if problems:
        return 1
    if a.command == "expect":
        return cmd_expect(a, pins, admitted)
    runs = [Run(p) for p in a.runs]
    fresh = fresh_rows(runs)
    if a.command == "selftest":
        return cmd_selftest(pins, fresh, admitted)
    changes = ratchet(pins, fresh, admitted)
    if a.command == "draft":
        if a.attribute:
            return cmd_attribute(a, pins, changes)
        done = set()
        for kind, k, old, new, f, run, ok in changes:
            if not ok:
                causes = via(run, f, pins) if kind == "redefined" and PIN_CONSTS else []
                if causes:
                    for n in causes:
                        line = "\t".join([n, PIN_CONSTS[n][1], run.closure[n].hex(), "redefined", "COMMIT", "TODO why the meaning is unchanged"])
                        if line not in done:
                            done.add(line)
                            print(line)
                    continue
                if kind == "redefined":
                    print(f"# {k}: no cause among the pinned constants: a row-level decision")
                print("\t".join([k, old, new, kind, "COMMIT", "TODO"]))
        return 0
    if a.command == "pin" and a.rehash:
        other = [c for c in changes if c[0] not in ("redefined", "rerendered")]
        for c in other[:20]:
            print(f"{a.label}: rehash REFUSED: {c[0]} {c[1]}")
        if other:
            print(f"{a.label}: rehash REFUSED: {len(other)} statement, axiom or key event(s); nothing written")
            return 1
        write_pins(a.pins, pins, fresh, [c[:6] + (True,) for c in changes], runs)
        print(f"{a.label}: rehashed {sum(1 for c in changes if c[0] == 'redefined')} closures; pinned {len(fresh)} rows into {a.pins}")
        return 0
    red = report(changes, pins, a.label)
    if a.command == "pin":
        if red:
            print(f"{a.label}: pin REFUSED: {red} unadmitted change(s); nothing written")
            return 1
        write_pins(a.pins, pins, fresh, changes, runs)
        print(f"{a.label}: pinned {len(fresh)} rows into {a.pins}")
    return 1 if red else 0


if __name__ == "__main__":
    sys.exit(main())
