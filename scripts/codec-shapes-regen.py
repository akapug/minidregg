#!/usr/bin/env python3
"""Re-emit Compiler/PersistedCodecShapes.lean and bump every persisted identity
whose codec structure changed under it.

usage: scripts/codec-shapes-regen.py [--check]

1. Builds the census's imports (`lake build`, wrapped in `swarm-build` when it
   exists), then runs the census with `#emit_persisted_codec_shapes` in place of
   `#assert_persisted_codec_tags` on a temporary copy, writing fresh pins.
2. An identity whose fingerprint moved is BUMPED where it is spelled: a
   `.../vN` string literal becomes `.../v(N+1)` in every *.lean and native/**/*.rs
   file that spells it exactly; a trailing version byte (`"P".toUTF8.toList ++ [N]`)
   becomes `[N+1]` the same way; and a registry version constant that composes the
   identity (`abbrev V : Nat := N` used as `s!"P/v{V}"` or `++ [UInt8.ofNat V]` in
   Compiler/PersistedCodecTags) becomes N+1, once per round however many identities
   share it.  An identity with none of these forms (a bare prefix) cannot be bumped
   mechanically: it is listed and the script exits 2 without writing pins.
3. Repeats until no fingerprint moves (a bumped identity moves the fingerprint
   of every codec that nests it), then writes the pins module.
4. A BARE PREFIX (an identity with no version of its own: `Compiler/PersistedCodecTags`
   declares it as `abbrev prefix_<...> : String`) whose fingerprint moved is re-pinned,
   by name, only when (1) an identity it is a strict byte-prefix of was bumped in this
   run (a pinned identity under it is gone from the census and a new one under it
   appeared, whether this script or a hand edit renamed it) and (2) it is never a
   complete frame itself: every spelling of the literal in Lean and Rust source is
   followed by `++` (a frame built on it carries its own version). Any other moved
   identity without a `/vN` still exits 2. `--selftest` checks this rule.
A source file whose text contains `codec-shapes-regen: frozen` (a frozen descriptor
of an earlier deployment, which must keep spelling the OLD names) is never rewritten.
Every run first refuses a TWIN: a literal spelling, outside the registry, of an
identity the registry composes from a version constant (a bump of the constant would
miss the literal). `--twins` runs only that check (no Lean); `--selftest` checks the
bump forms and the twin rule on fixtures.
After the pins are written (and under --check), the census is built with its own
`#assert_persisted_codec_tags`: an identity reachable from the Host and unregistered in
Compiler/PersistedCodecTags (or registered and unreachable) exits 3.
--check: emit and compare only; exit 1 if the pins are out of date.
"""
import os, pathlib, re, shutil, subprocess, sys, tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
CENSUS = ROOT / "Compiler/PersistedCodecTagCensus.lean"
PINS = ROOT / "Compiler/PersistedCodecShapes.lean"
PIN_LINE = re.compile(r'\("([0-9a-f]*)", "([0-9a-f]{16})"\),?  -- (.*)$')
TAGS = ROOT / "Compiler/PersistedCodecTags.lean"
FROZEN = "codec-shapes-regen: frozen"
PREFIX_DECL = re.compile(r'abbrev prefix_\w+ : String := "([^"]*)"')


def build():
    targets = ["Kernel.NativeHostReplay", "Compiler.PersistedCodecTags", "Compiler.PersistedCodecShapes"]
    command = ["lake", "build", *targets]
    if shutil.which("swarm-build"):
        command = ["swarm-build", *command]
    for slot in (pathlib.Path("/srv/pipeline/slots/with-lean-slot"),
                 pathlib.Path("/tank/dregg-build/pipeline/slots/with-lean-slot")):
        if slot.exists():
            command = [str(slot), *command]
            break
    subprocess.run(command, cwd=ROOT, check=True)


def assert_census():
    """The census itself, with its tag-set assertion: an identity reachable from the Host but
    absent from Compiler/PersistedCodecTags (or the reverse) stops the regen here, not a later
    consent stage. The emitter alone never runs that assertion."""
    command = ["lake", "build", "Compiler.PersistedCodecTagCensus"]
    if shutil.which("swarm-build"):
        command = ["swarm-build", *command]
    if subprocess.run(command, cwd=ROOT).returncode != 0:
        print("census refused after the pins were written: register or delete the identities "
              "it names in Compiler/PersistedCodecTags.lean, then rerun")
        sys.exit(3)


def emit():
    marker = "\n#assert_persisted_codec_tags\n"
    census = CENSUS.read_text()
    assert census.count(marker) == 1, "census marker not found exactly once"
    with tempfile.TemporaryDirectory() as scratch:
        out = pathlib.Path(scratch) / "pins.lean"
        # A plain file outside any Compiler/ directory: Lean would otherwise resolve
        # every Compiler.* import against the scratch directory.
        probe = pathlib.Path(scratch) / "EmitShapes.lean"
        probe.write_text(census.replace(marker, f'\n#emit_persisted_codec_shapes "{out}"\n'))
        subprocess.run(["lake", "env", "lean", str(probe)], cwd=ROOT, check=True)
        return out.read_text()


def parse(text):
    pins = {}
    for line in text.splitlines():
        match = PIN_LINE.search(line)
        if match:
            pins[match.group(1)] = (match.group(2), match.group(3))
    return pins


def source_files():
    for path in ROOT.rglob("*.lean"):
        if ".lake" not in path.parts:
            yield path
    for path in (ROOT / "native").rglob("*.rs"):
        if "target" not in path.parts:
            yield path


def spelled_files():
    """The files a bump may rewrite: every source file but the frozen ones."""
    for path in source_files():
        if FROZEN not in path.read_text(errors="surrogateescape"):
            yield path


def declared_prefixes(tags_text):
    return set(PREFIX_DECL.findall(tags_text))


def complete_frame_spellings(text, sources):
    """(file, offset) of each spelling of the literal `text` NOT followed by `++`
    (after an optional `.toUTF8.toList`): a use of it as a whole frame."""
    literal = f'"{text}"'
    tail = re.compile(r'(\.toUTF8\.toList)?\s*\+\+')
    found = []
    for name, body in sources:
        start = body.find(literal)
        while start != -1:
            if not tail.match(body, start + len(literal)):
                found.append((name, start))
            start = body.find(literal, start + 1)
    return found


def classify(moved, baseline, fresh, bumped, prefixes, sources):
    """Split moved identities with no mechanical bump into re-pinnable bare
    prefixes and the rest. `moved`: [(hexid, text)]; `baseline`, `fresh`: pins
    (hexid -> (fingerprint, text)) at the start of the run and now; `bumped`: the
    hexids this run renamed; `prefixes`: declared bare-prefix texts; `sources`:
    [(file, text)] that are not the registry or the pins.
    A prefix whose child this run renamed in the current round, before the build
    that births the new name, is neither: it is judged again next round.
    Returns (repins: [(text, child text)], manual: [text])."""
    renamed = set(bumped) | {h for h in baseline if h not in fresh}
    born = {h for h in fresh if h not in baseline}
    repins, manual = [], []
    for hexid, text in moved:
        if text not in prefixes:
            manual.append(text)
            continue
        under = lambda h: h.startswith(hexid) and len(h) > len(hexid)
        gone = sorted(h for h in renamed if under(h))
        new = sorted(h for h in born if under(h))
        if gone and not new and any(h in bumped for h in gone) \
                and not complete_frame_spellings(text, sources):
            continue  # its child was renamed this round; the new name is born next round
        if not gone or not new or complete_frame_spellings(text, sources):
            manual.append(text)
            continue
        child = baseline[gone[0]][1] if gone[0] in baseline else gone[0]
        repins.append((text, child))
    return repins, manual


def selftest():
    p = "44" * 2  # the prefix's bytes
    child_old, child_new = p + "0a", p + "0e"
    baseline = {p: ("0" * 16, "P"), child_old: ("1" * 16, "P?")}
    fresh_bumped = {p: ("2" * 16, "P"), child_new: ("3" * 16, "P?")}
    fresh_same = {p: ("2" * 16, "P"), child_old: ("1" * 16, "P?")}
    ok_src = [("A.lean", 'def f := "P".toUTF8.toList ++ [14]')]
    whole_src = ok_src + [("B.lean", 'def g := "P".toUTF8.toList\n')]
    moved = [(p, "P")]
    cases = [
        ("prefix moved, nothing under it bumped: refused",
         classify(moved, baseline, fresh_same, set(), {"P"}, ok_src), ([], ["P"])),
        ("prefix moved, a frame under it bumped: re-pinned",
         classify(moved, baseline, fresh_bumped, set(), {"P"}, ok_src), ([("P", "P?")], [])),
        ("prefix also spelled as a whole frame: refused",
         classify(moved, baseline, fresh_bumped, set(), {"P"}, whole_src), ([], ["P"])),
        ("not declared a bare prefix: refused",
         classify(moved, baseline, fresh_bumped, set(), set(), ok_src), ([], ["P"])),
        ("only an old child gone, no new one born: refused",
         classify(moved, baseline, {p: ("2" * 16, "P")}, set(), {"P"}, ok_src), ([], ["P"])),
        ("a child bumped this round, its new name not built yet: judged next round",
         classify(moved, baseline, {p: ("2" * 16, "P"), child_old: ("4" * 16, "P?")}, {child_old},
                  {"P"}, ok_src), ([], [])),
    ]
    hx = lambda t: t.encode().hex()
    tags = "T.lean"
    byte_files = {tags: 'abbrev x : List UInt8 := "P/Q".toUTF8.toList ++ [5]',
                  "A.lean": 'def f := "P/Q".toUTF8.toList ++ [5] ++ y'}
    seed_files = {tags: 'abbrev s : String := "P/S"\nabbrev sv : Nat := 4\n'
                        'abbrev b : List UInt8 := s.toUTF8.toList ++ [UInt8.ofNat sv]'}
    clock_files = {tags: 'abbrev cv : Nat := 4\nabbrev c : String := s!"P/C/v{cv}"',
                   "A.lean": 'def w : String := "P/C/v4"'}
    clock_once = {tags: clock_files[tags], "A.lean": "def w : String := Tags.c"}
    thm = {"K.lean": 'theorem t : f = "this Host P/L/v4" := by native_decide\n'
                     '-- P/L/v4 in a comment\n/- P/L/v4 /- nested -/ -/\n'
                     'def u := "P/L/v40"\ndef c := \'"\'\ndef w := "P/L/v4 again"',
           "R.rs": 'const X: &str = "P/L/v4 left";'}
    cases += [
        ("a bumped tag still spelled inside a theorem literal: refused by file:line",
         stale_spellings(thm, ["P/L/v4"]), [("K.lean", 1, "P/L/v4"), ("K.lean", 6, "P/L/v4")]),
        ("comments, a longer version and Rust are not Lean string spellings: clean",
         stale_spellings({k: v for k, v in thm.items() if k != "K.lean"} |
                         {"K.lean": thm["K.lean"].split("def w")[0].replace("this Host P/L/v4", "x")},
                         ["P/L/v4"]), []),
        ("trailing version byte spelled as a literal: bumped everywhere",
         plan_bump(hx("P/Q") + "05", "P/Q?", byte_files, tags),
         ("P/Q?", {tags: 'abbrev x : List UInt8 := "P/Q".toUTF8.toList ++ [6]',
                   "A.lean": 'def f := "P/Q".toUTF8.toList ++ [6] ++ y'}, [])),
        ("trailing version byte from a registry constant: the constant bumped",
         plan_bump(hx("P/S") + "04", "P/S?", seed_files, tags),
         ("P/S?", {tags: seed_files[tags].replace("sv : Nat := 4", "sv : Nat := 5")}, ["sv"])),
        ("a constant another identity bumped this round: not bumped twice",
         plan_bump(hx("P/S") + "04", "P/S?", seed_files, tags, {"sv"}), ("P/S?", {}, ["sv"])),
        ("/vN from a registry constant and a literal twin: both bumped",
         plan_bump(hx("P/C/v4"), "P/C/v4", clock_files, tags),
         ("P/C/v5", {tags: clock_files[tags].replace(":= 4", ":= 5"),
                     "A.lean": 'def w : String := "P/C/v5"'}, ["cv"])),
        ("a bare prefix has no version form: not bumped",
         plan_bump(hx("P/Q"), "P/Q", byte_files, tags), None),
        ("a literal twin of a composed identity: refused",
         composite_twins(clock_files, tags), [("A.lean", '"P/C/v4"')]),
        ("a trailing-byte twin of a composed identity: refused",
         composite_twins({**seed_files, "B.lean": '"P/S".toUTF8.toList ++ [4]'}, tags)[0][0], "B.lean"),
        ("the identity spelled once, through the registry: accepted",
         composite_twins(clock_once, tags), []),
    ]
    failed = [name for name, got, want in cases if got != want]
    for name, got, want in cases:
        print(("ok   " if got == want else "FAIL ") + name + ("" if got == want else f": {got} != {want}"))
    sys.exit(1 if failed else 0)


NAT_DECL = re.compile(r'abbrev (\w+) : Nat := (\d+)')
STRING_DECL = re.compile(r'abbrev (\w+) : String := "([^"]*)"')


def version_forms(hexid, text):
    """The two version forms of an identity: `.../vN` text -> ("v", prefix, N);
    printable bytes then one version byte -> ("byte", prefix, N); else None."""
    match = re.fullmatch(r"(.*/v)(\d+)", text)
    if match:
        return "v", match.group(1), int(match.group(2))
    raw = bytes.fromhex(hexid)
    if len(raw) > 1 and all(32 <= b < 127 and b != 34 for b in raw[:-1]) and raw[-1] < 32:
        return "byte", raw[:-1].decode(), raw[-1]
    return None


def version_constants(form, prefix, n, tags_text):
    """Registry Nat constants that carry this identity's version: `s!"P/v{V}"` or
    `<"P" or a String abbrev spelling P>.toUTF8.toList ++ [UInt8.ofNat V]`, V = n."""
    nats = {name: int(value) for name, value in NAT_DECL.findall(tags_text)}
    names = {name for name, value in STRING_DECL.findall(tags_text) if value == prefix}
    found = []
    for v, value in nats.items():
        if value != n:
            continue
        if form == "v":
            hit = f's!"{prefix}{{{v}}}"' in tags_text
        else:
            heads = [re.escape(f'"{prefix}"')] + [rf"\b{re.escape(x)}" for x in names]
            hit = re.search(rf"(?:{'|'.join(heads)})\.toUTF8\.toList\s*\+\+\s*\[UInt8\.ofNat {v}\]",
                            tags_text) is not None
        if hit:
            found.append(v)
    return found


def plan_bump(hexid, text, files, tags_name, done=frozenset()):
    """The edits that bump one identity, over `files` ({name: text}): every literal
    spelling (`"P/vN"`, or `"P".toUTF8.toList ++ [N]`) and every registry version
    constant that composes it (`V : Nat := N` in `tags_name`), unless a constant is
    in `done` (already bumped this round by an identity sharing it).
    Returns (new identity text, {name: new text}, constants bumped) or None."""
    forms = version_forms(hexid, text)
    if forms is None:
        return None
    form, prefix, n = forms
    edits = {}
    if form == "v":
        old, new = f'"{prefix}{n}"', f'"{prefix}{n + 1}"'
        for name, body in files.items():
            if old in body:
                edits[name] = body.replace(old, new)
        new_text = f"{prefix}{n + 1}"
    else:
        literal = re.compile(rf'({re.escape(chr(34) + prefix + chr(34))}\.toUTF8\.toList\s*\+\+\s*\[){n}\]')
        for name, body in files.items():
            if literal.search(body):
                edits[name] = literal.sub(lambda m: f"{m.group(1)}{n + 1}]", body)
        new_text = f"{prefix}?"
    constants = []
    if tags_name in files:
        tags = edits.get(tags_name, files[tags_name])
        for v in version_constants(form, prefix, n, files[tags_name]):
            if v not in done:
                tags = re.sub(rf"abbrev {v} : Nat := {n}\b", f"abbrev {v} : Nat := {n + 1}", tags)
            constants.append(v)
        if constants and tags != files[tags_name]:
            edits[tags_name] = tags
    if not edits and not (constants and set(constants) <= set(done)):
        return None
    return new_text, edits, constants


def lean_string_literals(text):
    """(line, contents) of every string literal in Lean source, comments excluded
    (`--` to end of line, nested `/- -/`); a char literal `'"'` opens nothing."""
    out, i, n, line = [], 0, len(text), 1
    while i < n:
        c = text[i]
        if c == "\n":
            line += 1
            i += 1
        elif text.startswith("--", i):
            j = text.find("\n", i)
            i = n if j < 0 else j
        elif text.startswith("/-", i):
            depth, i = 1, i + 2
            while i < n and depth:
                if text.startswith("/-", i):
                    depth, i = depth + 1, i + 2
                elif text.startswith("-/", i):
                    depth, i = depth - 1, i + 2
                else:
                    line += text[i] == "\n"
                    i += 1
        elif text.startswith("'\"'", i) or text.startswith("'\\\"'", i):
            i = text.index("'", i + 1) + 1
        elif c == '"':
            start, j = line, i + 1
            while j < n and text[j] != '"':
                if text[j] == "\\":
                    j += 1
                line += j < n and text[j] == "\n"
                j += 1
            out.append((start, text[i + 1:j]))
            i = j + 1
        else:
            i += 1
    return out


def stale_spellings(files, olds):
    """Old `.../vN` identity texts a bump left behind inside a Lean string literal
    (a theorem's message, an #assert, an interpolated label: any literal that is not
    exactly the identity, which the bump rewrote). Returns [(file, line, old)]."""
    pats = [(old, re.compile(re.escape(old) + r"(?!\d)")) for old in olds]
    hits = []
    for name, body in files.items():
        if not name.endswith(".lean"):
            continue
        for line, lit in lean_string_literals(body):
            for old, pat in pats:
                if pat.search(lit):
                    hits.append((name, line, old))
    return hits


def composite_twins(files, tags_name):
    """Identities the registry composes from a version constant that some other
    file ALSO spells as a literal: two spellings, one of which a bump can miss.
    Returns [(file, literal)]."""
    tags = files.get(tags_name, "")
    nats = {name: int(value) for name, value in NAT_DECL.findall(tags)}
    strings = dict(STRING_DECL.findall(tags))
    literals = []
    for prefix, v in re.findall(r's!"([^"{]*)\{(\w+)\}"', tags):
        if v in nats:
            literals.append(f'"{prefix}{nats[v]}"')
    for head, v in re.findall(r'("[^"]*"|\b\w+)\.toUTF8\.toList\s*\+\+\s*\[UInt8\.ofNat (\w+)\]', tags):
        prefix = head[1:-1] if head.startswith('"') else strings.get(head)
        if prefix is not None and v in nats:
            literals.append(re.compile(rf'"{re.escape(prefix)}"\.toUTF8\.toList\s*\+\+\s*\[{nats[v]}\]'))
    twins = []
    for name, body in files.items():
        if name == tags_name:
            continue
        for lit in literals:
            if (lit in body) if isinstance(lit, str) else lit.search(body):
                twins.append((name, lit if isinstance(lit, str) else lit.pattern))
    return twins


def source_texts():
    return {str(path.relative_to(ROOT)): path.read_text(errors="surrogateescape")
            for path in spelled_files()}


def bump(hexid, identity_text, done):
    plan = plan_bump(hexid, identity_text, source_texts(), str(TAGS.relative_to(ROOT)), done)
    if plan is None:
        return None
    new_text, edits, constants = plan
    for name, body in edits.items():
        (ROOT / name).write_text(body, errors="surrogateescape")
    done.update(constants)
    return new_text, sorted(edits) + [f"{c} (constant)" for c in constants]


def refuse_twins():
    twins = composite_twins(source_texts(), str(TAGS.relative_to(ROOT)))
    for name, literal in twins:
        print(f"twin: {name} spells {literal}, which the registry composes from a version constant")
    if twins:
        sys.exit("refused: use the registry constant instead of the literal (one spelling per identity)")


def main():
    if "--selftest" in sys.argv[1:]:
        selftest()
    check = "--check" in sys.argv[1:]
    refuse_twins()
    if "--twins" in sys.argv[1:]:
        print("no composite twins")
        return
    baseline = parse(PINS.read_text())
    bumped = set()
    for round_ in range(8):
        build()
        fresh_text = emit()
        fresh, current = parse(fresh_text), parse(PINS.read_text())
        moved = [(hexid, fresh[hexid][1]) for hexid in fresh
                 if hexid in current and current[hexid][0] != fresh[hexid][0]]
        if check:
            if fresh != current:
                print(f"pins out of date: {len(moved)} moved, "
                      f"{len(set(fresh) - set(current))} unpinned, {len(set(current) - set(fresh))} stale")
                sys.exit(1)
            print("pins up to date")
            assert_census()
            return
        unbumped, done, olds = [], set(), []
        for hexid, text in moved:
            result = bump(hexid, text, done)
            if result is None or not result[1]:
                unbumped.append((hexid, text))
            else:
                bumped.add(hexid)
                if version_forms(hexid, text) and version_forms(hexid, text)[0] == "v":
                    olds.append(text)
                print(f"BUMPED {text} -> {result[0]} in {result[1]}")
        stale = stale_spellings(source_texts(), olds)
        for name, line, old in stale:
            print(f"stale: {name}:{line} still spells {old} inside a string literal")
        if stale:
            sys.exit("refused: a bumped identity's old name survives the bump (spell it from the registry "
                     "constant or interpolate its label; then rerun)")
        sources = [(str(path.relative_to(ROOT)), path.read_text(errors="surrogateescape"))
                   for path in source_files() if path not in (TAGS, PINS)]
        repins, manual = classify(unbumped, baseline, fresh, bumped,
                                  declared_prefixes(TAGS.read_text()), sources)
        if not manual and len(repins) == len(moved):
            for text, child in repins:
                print(f"RE-PINNED bare prefix {text} (a strict prefix of the bumped {child})")
            PINS.write_text(fresh_text)
            print(f"wrote {PINS.relative_to(ROOT)}: {len(fresh)} pins (round {round_})")
            assert_census()
            return
        if manual:
            print("structure moved under identities with no mechanical bump (edit by hand, then rerun):")
            for text in manual:
                print(f"  {text}")
            sys.exit(2)
    sys.exit("no fixed point after 8 rounds")


if __name__ == "__main__":
    main()
