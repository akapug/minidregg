#!/usr/bin/env python3
"""check-guard-discipline.py — the `#guard` population may only RATCHET DOWN, per module.

Ported from Bread (`breadstuffs/scripts/check-guard-discipline.py`, policy
`breadstuffs/metatheory/docs/GUARD-DISCIPLINE.md`) on 2026-10-14 (next 0125b224), when Mini had no
check on them at all. ⚠ The figure that prompted it — "4,392 `#guard` lines" — was a grep for the
string `#guard`, and ~4,300 of those are `#guard_msgs (…) in #print axioms <thm>`: EXACT axiom-set
pins on named theorems, which this gate does not count (they are the instrument, not the sin). The
real population at the port was 70 `#guard` commands in 7 modules.

═══ THE ARGUMENT ══════════════════════════════════════════════════════════════════
`#guard e` evaluates ONE closed instance at elaboration time. It proves nothing about all
inputs, PRODUCES NO TERM anything can build on, and is invisible to axiom accounting.

It is not a cheaper check either. Lean, `Lean/Elab/Tactic/Guard.lean` (evalGuardCmd):

    let v ← unsafe evalExpr (checkMeta := false) Bool (mkConst ``Bool) e

`#guard` runs the unsafe compiled evaluator — the engine `native_decide` runs on. So
`#guard e` is `theorem _ : e = true := by native_decide` with three things deleted: the NAME
(nothing can cite it), the TERM (nothing can compose on it), and the AXIOM RECORD (`#assert_axioms`
and the axiom census cannot see it). A `#guard` does not avoid trusting the compiler; it trusts
it silently.

The conversion, in order of preference:
  1. kernel reaches it:   `theorem foo : lhs = rhs := by decide` (or `rfl`) + `#assert_axioms foo`
                          (strictly STRONGER than the guard was);
  2. only the compiler:   `theorem foo : lhs = rhs := by native_decide` + `#assert_compiled foo`
                          (Theory/AssertCompiled.lean; a confession, not a certificate);
  3. ⚑ the guard was one instance of a general fact: PROVE THE FACT, and keep the instance as a
     corollary only if something should cite it.
Every converted guard asserts exactly what it asserted, over the same object.

═══ THE RATCHET ═══════════════════════════════════════════════════════════════════
A per-module baseline in `scripts/gates/guard-discipline-baseline.txt` that may only SHRINK:

  (a) ABOVE baseline — a module gained guards: RED, by name.
  (b) BELOW baseline — a STALE ROW: you converted and did not retire the number. RED, so the
      ledger tracks the tree exactly and the count in a commit message is the count on disk.
  (c) UNLISTED and carrying guards — RED: the population cannot grow sideways into new files.
  (d) the REFRESH is gated (`--update-baseline`): (d1) no surviving row may rise; (d2) the TOTAL
      may not rise — that is what catches a module SPLIT, which in Bread laundered 23 guards on
      2026-08-02 while no row rose; (d3) every refresh records provenance (sha, dirtiness,
      totals, a mandatory `--reason`). `--allow-increase` exists, needs `--reason`, and stamps
      INCREASED — loud, not absent.
  (e) the LEDGER checks itself: `# TOTAL <n>` and the last provenance line must equal the sum of
      the rows, so a hand-edited row reds for anyone running the gate.
  `--only <path>` retires exactly the rows a lane earned; a whole-tree refresh in a shared tree
  absorbs a sibling's in-flight guards. Use it by default.

⚠ WHAT THIS DOES NOT CATCH: WHICH guards remain or what they claim; a guard converted to a
vacuous theorem (`theorem t : True := trivial` counts as burned down); a guard DELETED rather
than converted (the diff says which). `#assert_axioms`/`#guard_msgs` are not counted.

USAGE
  python3 scripts/gates/check-guard-discipline.py                # working tree
  python3 scripts/gates/check-guard-discipline.py --rev HEAD     # clean extract of a revision
  python3 scripts/gates/check-guard-discipline.py --top 25       # + the heaviest modules
  python3 scripts/gates/check-guard-discipline.py --closure scripts/gates/host-closure.pin
                                                                 # + per-module counts in a closure
  python3 scripts/gates/check-guard-discipline.py --update-baseline --only Kernel/World.lean --reason "..."
  python3 scripts/gates/check-guard-discipline.py --self-test    # red-proof (synthetic tree)
Exit: 0 green · 1 violation / stale row / vacuous scan / bad ledger · 2 environment error
      3 REFUSED refresh (the baseline would have risen)
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

_HERE = Path(__file__).resolve().parent

# `#guard` ONLY. `#guard_msgs` is a different command and is excluded by the lookahead.
GUARD_RE = re.compile(r'#guard(?![A-Za-z0-9_])')

# Pruned anywhere in the path. Everything else that is a tracked-or-not `.lean` file counts:
# a guard in scripts/, docs/, tests/ or scratch/ is still a guard, and "no new #guard anywhere"
# has no exempt directory.
IGNORE_DIRS = {".lake", ".git", "build", "target", "node_modules", "__pycache__"}

THEOREM_RE = re.compile(r'(?<![A-Za-z0-9_.])theorem(?![A-Za-z0-9_])')

# Non-vacuity floors. The guard count is meant to reach ZERO, so it cannot be its own floor: a
# blinded reader (a broken walk, extract, or a stripper that blanks the file after a phantom
# string) would read as a finished burndown. The floor is on what the SAME stripped text must
# still show: `theorem` tokens. Measured at next 0125b224: 1,617 files, 19,825 theorems
# (see the baseline header); set well under.
MIN_FILES_SCANNED = 1200
MIN_THEOREMS_FOUND = 15000

SCOPE_ANSWERS = (
    "does any *.lean file in the repository (.lake/.git/build/target pruned; comments, string and "
    "char literals stripped) hold a different NUMBER of `#guard` tokens than its row in "
    "scripts/gates/guard-discipline-baseline.txt — above it, below it, or carrying guards with no "
    "row — and does that ledger's header TOTAL and last provenance line equal the rows present?"
)
SCOPE_DOES_NOT_ANSWER = (
    "what any surviving guard CLAIMS, or whether a fallen count was a conversion or a DELETION; a "
    "guard converted into a vacuous theorem counts as burned down; and even under --rev the ledger "
    "graded against is the working-tree baseline file."
)
SCOPE_ANSWERS_SELFTEST = (
    "can this INSTRUMENT still fire? Against a synthetic tree it plants each fault in turn — a module "
    "above its row, below it, deleted, unlisted, a (d1)/(d2)/(d3) refresh that would launder a split, "
    "a hand-raised ledger row, a blinded scan — and requires each to go red while the controls stay "
    "green (a tree at its own baseline; `#guard` in a comment, a string, after a '\"' char literal, "
    "`#assert_axioms`, `#guard_msgs`)."
)
SCOPE_DOES_NOT_ANSWER_SELFTEST = (
    "anything about this repository or its ledger: an all-PASS red-proof is a fact about the READER."
)


def strip_lean_noise(text: str) -> str:
    """Blank Lean comments, string literals and char literals, preserving newlines.

    Bread's lexer (check-guard-modules.py) plus char literals: Mini's codecs are full of `'"'`,
    and without this a `'"'` opens a phantom string that blanks the rest of the file. A `'` is a
    char-literal opener only where it cannot be an identifier prime (`foo'`)."""
    out = list(text)
    i, n = 0, len(text)

    def blank(a: int, b: int) -> None:
        for k in range(a, min(b, n)):
            if out[k] != "\n":
                out[k] = " "

    while i < n:
        c = text[i]
        if c == "-" and i + 1 < n and text[i + 1] == "-":
            j = text.find("\n", i)
            j = n if j < 0 else j
            blank(i, j)
            i = j
        elif c == "/" and i + 1 < n and text[i + 1] == "-":
            depth, j = 0, i
            while j < n:
                if text.startswith("/-", j):
                    depth += 1
                    j += 2
                elif text.startswith("-/", j):
                    depth -= 1
                    j += 2
                    if depth == 0:
                        break
                else:
                    j += 1
            blank(i, j)
            i = j
        elif c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if (text[j] == "\\" and j + 1 < n) else 1
            blank(i, j + 1)
            i = j + 1
        elif c == "'" and (i == 0 or not (text[i - 1].isalnum() or text[i - 1] in "_'!?.")):
            if i + 2 < n and text[i + 1] != "\\" and text[i + 2] == "'":
                blank(i, i + 3)
                i += 3
            elif i + 1 < n and text[i + 1] == "\\":
                j = text.find("'", i + 2)
                if 0 < j - i <= 12:
                    blank(i, j + 1)
                    i = j + 1
                else:
                    i += 1
            else:
                i += 1
        else:
            i += 1
    return "".join(out)


def repo_root() -> Path:
    try:
        out = subprocess.run(["git", "-C", str(_HERE), "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True, check=True)
        return Path(out.stdout.strip())
    except Exception:
        return _HERE.parent.parent


DEFAULT_BASELINE = _HERE / "guard-discipline-baseline.txt"


N_THEOREMS = [0]


def scan(root: Path) -> tuple[dict[str, int], int]:
    """{repo-relative lean path -> #guard count}, and the number of .lean files scanned.
    The `theorem` count of the same stripped text lands in N_THEOREMS[0] (the reader floor)."""
    counts: dict[str, int] = {}
    n_files = 0
    N_THEOREMS[0] = 0
    for p in sorted(root.rglob("*.lean")):
        rel = p.relative_to(root)
        if any(part in IGNORE_DIRS for part in rel.parts):
            continue
        n_files += 1
        try:
            text = p.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        stripped = strip_lean_noise(text)
        N_THEOREMS[0] += len(THEOREM_RE.findall(stripped))
        k = len(GUARD_RE.findall(stripped))
        if k:
            counts[rel.as_posix()] = k
    return counts, n_files


def read_baseline(path: Path) -> dict[str, int]:
    if not path.exists():
        return {}
    out: dict[str, int] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("#"):
            continue
        parts = line.strip().split("\t")
        if len(parts) == 2 and parts[0].isdigit():
            out[parts[1]] = int(parts[0])
    return out


PROV_PREFIX = "# BASELINE-PROVENANCE"


def read_provenance(path: Path) -> list[str]:
    if not path.exists():
        return []
    return [ln.rstrip() for ln in path.read_text(encoding="utf-8").splitlines()
            if ln.startswith(PROV_PREFIX)]


def audit_baseline_integrity(path: Path) -> list[str]:
    """(e) The ledger checks itself: header TOTAL and last provenance total = sum of rows."""
    if not path.exists():
        return []
    rows = read_baseline(path)
    total = sum(rows.values())
    text = path.read_text(encoding="utf-8")
    findings: list[str] = []
    m = re.search(r'^#\s*TOTAL\s+(\d+)\s+guards', text, re.MULTILINE)
    if m is None:
        findings.append("the baseline header has no `# TOTAL <n> guards` line — it was not "
                        "written by the gated refresh")
    elif int(m.group(1)) != total:
        findings.append(
            f"the baseline header says TOTAL {m.group(1)} but its rows sum to {total} "
            f"({total - int(m.group(1)):+d}) — the ledger was EDITED without going through "
            "`--update-baseline`, which is the one path that records why")
    prov = read_provenance(path)
    if prov:
        pm = re.search(r'(\d+)\s*(?:→|->)\s*(\d+)', prov[-1])
        if pm and int(pm.group(2)) != total:
            findings.append(
                f"the last BASELINE-PROVENANCE line ends at {pm.group(2)} but the rows sum to "
                f"{total} — a row moved after the last recorded refresh")
    return findings


def _head_sha_and_dirt() -> tuple[str, bool]:
    root = repo_root()
    try:
        sha = subprocess.run(["git", "-C", str(root), "rev-parse", "--short", "HEAD"],
                             capture_output=True, text=True, check=True).stdout.strip()
        st = subprocess.run(["git", "-C", str(root), "status", "--porcelain", "--", "*.lean"],
                            capture_output=True, text=True, check=True).stdout.strip()
        return (sha, bool(st))
    except Exception:
        return ("unknown", True)


def write_baseline(path: Path, counts: dict[str, int], total_files: int,
                   provenance: list[str] | None = None) -> None:
    total = sum(counts.values())
    lines = [
        "# guard-discipline-baseline.txt — per-module `#guard` counts. A BURNDOWN LEDGER.",
        "# scripts/gates/check-guard-discipline.py reds when a module goes ABOVE its row, BELOW it",
        "# (a stale row — retire the number when you convert), or carries guards with no row.",
        "# So this file may only ever SHRINK. Refresh ONLY through",
        "#   python3 scripts/gates/check-guard-discipline.py --update-baseline --only <path> --reason '...'",
        "# which refuses to raise any row or the TOTAL. Never hand-edit: the header TOTAL and the last",
        "# provenance line are checked against the rows on every run.",
        f"# TOTAL {total} guards across {len(counts)} modules ({total_files} .lean files scanned, "
        f"{N_THEOREMS[0]} theorems seen).",
        "# format: <count><TAB><path relative to the repository root>",
    ]
    lines.extend(provenance or [])
    lines.append("")
    for p in sorted(counts):
        lines.append(f"{counts[p]}\t{p}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def refresh_baseline(path: Path, counts: dict[str, int], n_files: int,
                     reason: str | None, allow_increase: bool,
                     quiet: bool = False, only: list[str] | None = None,
                     create: bool = False) -> int:
    """(d1)/(d2)/(d3). Returns 0 written, 3 REFUSED. `create` is the first write only."""
    def say(*a):
        if not quiet:
            print(*a)

    if create and path.exists():
        say("REFUSED: --create on an existing baseline; refresh it with --update-baseline")
        return 3
    if not create and not path.exists():
        say(f"REFUSED: no baseline at {path}; the first one is written with --create")
        return 3
    old = read_baseline(path)
    if only is not None:
        sel = set(only)
        merged = dict(old)
        for p in sel:
            if p in counts:
                merged[p] = counts[p]
            else:
                merged.pop(p, None)
        untouched = sorted(p for p in counts if p not in old and p not in sel)
        counts = merged
        say(f"── targeted refresh: {len(sel)} row(s) named; "
            f"{len(untouched)} unlisted guard-carrying module(s) LEFT ALONE ──")
    old_total, new_total = sum(old.values()), sum(counts.values())
    rises = [(p, old[p], counts[p]) for p in sorted(counts) if p in old and counts[p] > old[p]]
    added = {p: k for p, k in counts.items() if p not in old}
    say(f"── proposed refresh: {old_total} → {new_total} guards ({len(old)} → {len(counts)} rows) ──")
    for p, a, b in rises:
        say(f"     RISE +{b - a}  {p}: {a} → {b}")
    if added and not create:
        say(f"   rows that would be ADDED: {len(added)} carrying {sum(added.values())} guards")

    refusals: list[str] = []
    if rises and not allow_increase:
        refusals.append(f"(d1) {len(rises)} row(s) would RISE — the ratchet only turns DOWN")
    if new_total > old_total and not allow_increase and not create:
        refusals.append(f"(d2) the TOTAL would RISE {old_total} → {new_total} "
                        f"(+{new_total - old_total}) — the SPLIT/RENAME shape")
    if not reason:
        refusals.append("(d3) `--reason` is REQUIRED")
    if refusals:
        for r in refusals:
            say(f"REFUSED: {r}")
        say("The baseline was NOT written.")
        return 3

    sha, dirty = _head_sha_and_dirt()
    delta = new_total - old_total
    verdict = "CREATED" if create else (
        "INCREASED" if delta > 0 else ("DECREASED" if delta < 0 else "LEVEL"))
    prov = read_provenance(path) if path.exists() else []
    prov.append(f"{PROV_PREFIX} {sha}{'-DIRTY' if dirty else ''} {old_total}→{new_total} "
                f"({delta:+d}) {verdict} — {reason}")
    write_baseline(path, counts, n_files, prov)
    say(f"wrote {path} — {new_total} guards across {len(counts)} modules  [{verdict} {delta:+d}]")
    return 0


def evaluate(counts: dict[str, int], n_files: int, baseline: dict[str, int],
             enforce_floors: bool, label: str, top: int, quiet: bool = False) -> int:
    def say(*a):
        if not quiet:
            print(*a)

    total = sum(counts.values())
    say(f"── guard-discipline census [{label}] ──")
    say(f"   {total} `#guard`s across {len(counts)} modules ({n_files} .lean files scanned, "
        f"{N_THEOREMS[0]} theorems seen)")
    say(f"   baseline: {sum(baseline.values())} across {len(baseline)} modules")
    findings: list[str] = []
    if enforce_floors:
        if n_files < MIN_FILES_SCANNED:
            findings.append(f"VACUOUS SCAN: {n_files} .lean files scanned, floor {MIN_FILES_SCANNED}")
        if N_THEOREMS[0] < MIN_THEOREMS_FOUND:
            findings.append(f"VACUOUS SCAN: the stripped text shows {N_THEOREMS[0]} `theorem` "
                            f"tokens, floor {MIN_THEOREMS_FOUND} — the reader is blind, and a "
                            "blind reader looks exactly like a finished burndown")
        if not baseline:
            findings.append("NO BASELINE: the ledger is missing or empty")

    grew, stale, unlisted = [], [], []
    for p, k in sorted(counts.items()):
        if p not in baseline:
            unlisted.append((p, k))
        elif k > baseline[p]:
            grew.append((p, baseline[p], k))
        elif k < baseline[p]:
            stale.append((p, baseline[p], k))
    for p, k in sorted(baseline.items()):
        if p not in counts:
            stale.append((p, k, 0))
    if grew:
        say("\n⚑ RED — a module gained `#guard`s (the ratchet only turns DOWN; name the fact):")
        for p, was, now in grew:
            say(f"   {p}: {was} → {now}  (+{now - was})")
        findings.append(f"{len(grew)} module(s) ABOVE baseline")
    if unlisted:
        say("\n⚑ RED — guard-carrying module with NO baseline row (population grew sideways):")
        for p, k in unlisted:
            say(f"   {p}: {k}")
        findings.append(f"{len(unlisted)} unlisted guard-carrying module(s)")
    if stale:
        say("\n⚑ RED — STALE baseline row (you converted; retire it with "
            "`--update-baseline --only <path> --reason ...`):")
        for p, was, now in stale:
            say(f"   {p}: baseline {was}, actual {now}  (−{was - now})")
        findings.append(f"{len(stale)} stale baseline row(s)")
    if top:
        say(f"\n── the {top} heaviest modules ──")
        for p, k in sorted(counts.items(), key=lambda kv: -kv[1])[:top]:
            say(f"   {k:6d}  {p}")
    say("")
    if findings:
        for f in findings:
            say(f"FAIL: {f}")
        return 1
    say("PASS: guard-discipline ratchet green.")
    return 0


def report_closure(counts: dict[str, int], pin: Path) -> None:
    mods = [ln.strip() for ln in pin.read_text(encoding="utf-8").splitlines()
            if ln.strip() and not ln.startswith("#")]
    inside = {m.replace(".", "/") + ".lean" for m in mods}
    rows = sorted(((counts[p], p) for p in inside if p in counts), reverse=True)
    print(f"\n── closure {pin}: {len(mods)} modules, {sum(k for k, _ in rows)} guards in "
          f"{len(rows)} of them ──")
    for k, p in rows:
        print(f"   {k:6d}  {p}")


def extract_rev(git_root: Path, rev: str, dest: Path) -> Path:
    ar = subprocess.run(["git", "-C", str(git_root), "archive", rev, "--", ":(glob)**/*.lean"],
                        capture_output=True)
    if ar.returncode != 0:
        raise RuntimeError(f"git archive {rev} failed: {ar.stderr.decode(errors='replace')[:400]}")
    tar = subprocess.run(["tar", "-x", "-C", str(dest)], input=ar.stdout, capture_output=True)
    if tar.returncode != 0:
        raise RuntimeError("tar -x of the git archive failed")
    return dest


# ═══ RED-PROOF ═════════════════════════════════════════════════════════════════════

def _mk(tree: Path, rel: str, body: str) -> None:
    p = tree / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(body, encoding="utf-8")


def run_self_test() -> int:
    tmp = Path(tempfile.mkdtemp(prefix="guard-discipline-selftest-"))
    ok = True

    def check(name: str, held: bool, detail: str) -> None:
        nonlocal ok
        print(f"   {'PASS' if held else 'FAIL'}  {name}")
        if not held:
            ok = False
            print(f"         {detail}")

    try:
        mt = tmp / "repo"
        _mk(mt, "A.lean", "#guard 1 == 1\n#guard 2 == 2\n")
        _mk(mt, "sub/B.lean", "theorem t : 1 = 1 := rfl\n#guard 3 == 3\n")
        _mk(mt, "sub/Clean.lean", "theorem u : 2 = 2 := rfl\n")
        _mk(mt, "Prose.lean", '/- we emit #guard s -/\n-- #guard x\ndef s := "#guard x"\n')
        _mk(mt, "NotAGuard.lean", "#assert_axioms t\n#guard_msgs in\n#eval 1\n")
        # `#guard_msgs in #print axioms` is an EXACT axiom-set pin on a named theorem (the shape
        # ~4,300 lines on next take) and is not counted: it is the instrument, not the sin
        _mk(mt, "Pins.lean", "/-- info: 'X.t' depends on axioms: [propext] -/\n"
                             "#guard_msgs (whitespace := lax) in #print axioms t\n")
        # a '"' char literal must not open a phantom string that hides the next guard; an
        # identifier prime must not open a char literal that hides one either
        _mk(mt, "Chars.lean", "def q := '\"'\n#guard q == q\ndef x' := 1\ndef y' := x'\n#guard 1 == 1\n"
                              "def e := '\\n'\n#guard 2 == 2\n")
        _mk(mt, ".lake/packages/X.lean", "#guard 1 == 1\n")
        bl = tmp / "baseline.txt"
        counts, nf = scan(mt)
        check("counts only real #guard (comments/strings/chars/#assert_axioms/#guard_msgs/.lake out)",
              counts == {"A.lean": 2, "sub/B.lean": 1, "Chars.lean": 3}, f"got {counts}")

        check("first write needs --create (refresh on a missing ledger is refused)",
              refresh_baseline(bl, counts, nf, "x", False, quiet=True) == 3, "")
        rc = refresh_baseline(bl, counts, nf, "create", False, quiet=True, create=True)
        check("--create writes the first ledger", rc == 0, f"rc={rc}")
        rc = evaluate(counts, nf, read_baseline(bl), False, "self-test", 0, quiet=True)
        check("CONTROL: tree at its own baseline is GREEN", rc == 0, f"rc={rc}")
        check("CONTROL: a gate-written ledger is self-consistent", not audit_baseline_integrity(bl),
              f"{audit_baseline_integrity(bl)}")

        _mk(mt, "A.lean", "#guard 1 == 1\n#guard 2 == 2\n#guard 4 == 4\n")
        rc = evaluate(*scan(mt), read_baseline(bl), False, "self-test", 0, quiet=True)
        check("RED (a): a module that GAINED a guard fails", rc == 1, f"rc={rc}")
        _mk(mt, "A.lean", "#guard 1 == 1\n")
        rc = evaluate(*scan(mt), read_baseline(bl), False, "self-test", 0, quiet=True)
        check("RED (b): a CONVERTED module with a stale row fails", rc == 1, f"rc={rc}")
        (mt / "A.lean").unlink()
        rc = evaluate(*scan(mt), read_baseline(bl), False, "self-test", 0, quiet=True)
        check("RED (b'): a DELETED baselined module fails as stale", rc == 1, f"rc={rc}")
        _mk(mt, "A.lean", "#guard 1 == 1\n#guard 2 == 2\n")
        _mk(mt, "sub/New.lean", "#guard 9 == 9\n")
        rc = evaluate(*scan(mt), read_baseline(bl), False, "self-test", 0, quiet=True)
        check("RED (c): a NEW guard-carrying module with no row fails", rc == 1, f"rc={rc}")
        (mt / "sub/New.lean").unlink()

        # (d1) a refresh that raises a row is refused and leaves the file untouched
        _mk(mt, "A.lean", "#guard 1 == 1\n#guard 2 == 2\n#guard 3 == 3\n")
        before = bl.read_text(encoding="utf-8")
        rc = refresh_baseline(bl, *scan(mt), "bake in a regrowth", False, quiet=True)
        check("REFUSED (d1): a refresh that RAISES a row", rc == 3, f"rc={rc}")
        check("(d1) …and the ledger on disk is untouched", bl.read_text(encoding="utf-8") == before, "")
        # (d2) split into pieces that sum higher: no row rises, the total does
        _mk(mt, "A.lean", "#guard 1 == 1\n#guard 2 == 2\n")
        (mt / "sub/B.lean").unlink()
        _mk(mt, "sub/B1.lean", "#guard 3 == 3\n")
        _mk(mt, "sub/B2.lean", "#guard 4 == 4\n")
        rc = refresh_baseline(bl, *scan(mt), "split B", False, quiet=True)
        check("REFUSED (d2): a SPLIT whose pieces sum HIGHER", rc == 3, f"rc={rc}")
        (mt / "sub/B2.lean").unlink()
        rc = refresh_baseline(bl, *scan(mt), "split B into B1", False, quiet=True)
        check("CONTROL: a LEVEL split is accepted", rc == 0, f"rc={rc}")
        # (d3)
        _mk(mt, "A.lean", "#guard 1 == 1\n")
        rc = refresh_baseline(bl, *scan(mt), None, False, quiet=True)
        check("REFUSED (d3): a refresh with NO --reason", rc == 3, f"rc={rc}")
        rc = refresh_baseline(bl, *scan(mt), "converted A", False, quiet=True)
        check("a DOWNWARD refresh with a reason is accepted", rc == 0, f"rc={rc}")
        check("…and stamped DECREASED provenance",
              any("DECREASED" in ln and "converted A" in ln for ln in read_provenance(bl)), "")
        # override is loud
        _mk(mt, "sub/Loud.lean", "#guard 5 == 5\n")
        check("--allow-increase still requires --reason",
              refresh_baseline(bl, *scan(mt), None, True, quiet=True) == 3, "")
        rc = refresh_baseline(bl, *scan(mt), "new, paid later", True, quiet=True)
        check("--allow-increase with a reason stamps INCREASED",
              rc == 0 and any("INCREASED" in ln for ln in read_provenance(bl)), f"rc={rc}")
        # --only cannot absorb a sibling
        (mt / "sub/Loud.lean").unlink()
        refresh_baseline(bl, *scan(mt), "reset", True, quiet=True)
        _mk(mt, "sub/SiblingWip.lean", "#guard 7 == 7\n")
        (mt / "A.lean").write_text("", encoding="utf-8")
        rc = refresh_baseline(bl, *scan(mt), "retire A", False, quiet=True, only=["A.lean"])
        after = read_baseline(bl)
        check("--only retires the named row and leaves the sibling unlisted",
              rc == 0 and "A.lean" not in after and "sub/SiblingWip.lean" not in after, f"{after}")
        check("…and the sibling still REDS",
              evaluate(*scan(mt), after, False, "self-test", 0, quiet=True) == 1, "")
        _mk(mt, "A.lean", "#guard 1 == 1\n")
        check("--only cannot raise its own row",
              refresh_baseline(bl, *scan(mt), "sneak", False, quiet=True, only=["A.lean"]) == 3, "")
        # (e) hand-edit detection
        (mt / "sub/SiblingWip.lean").unlink()
        refresh_baseline(bl, *scan(mt), "clean", True, quiet=True)
        txt = bl.read_text(encoding="utf-8")
        hand = txt.replace("1\tA.lean", "9\tA.lean")
        check("the hand-edit plant applied", hand != txt, "")
        bl.write_text(hand, encoding="utf-8")
        f_e = audit_baseline_integrity(bl)
        check("RED (e): a HAND-RAISED row is detected (TOTAL and provenance)",
              any("EDITED" in x for x in f_e) and any("after the last" in x for x in f_e), f"{f_e}")
        bl.write_text("5\tA.lean\n", encoding="utf-8")
        check("RED (e): a ledger with no header is refused",
              any("no `# TOTAL" in x for x in audit_baseline_integrity(bl)), "")
        # floors
        N_THEOREMS[0] = 0
        check("a BLINDED scan trips the floors (zero guards is not a pass when the reader saw nothing)",
              evaluate({}, 0, {"A.lean": 1}, True, "blind", 0, quiet=True) == 1, "")
        check("a missing ledger trips the floors", evaluate({}, 0, {}, True, "blind", 0, quiet=True) == 1, "")
        print("\nguard-discipline self-test: " + ("PASS" if ok else "FAIL"))
        return 0 if ok else 1
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main() -> int:
    ap = argparse.ArgumentParser(description="per-module `#guard` downward ratchet")
    ap.add_argument("--rev", help="scan a clean `git archive` extract of this revision")
    ap.add_argument("--baseline", type=Path, default=DEFAULT_BASELINE)
    ap.add_argument("--update-baseline", action="store_true")
    ap.add_argument("--create", action="store_true", help="write the FIRST ledger (refused if one exists)")
    ap.add_argument("--reason")
    ap.add_argument("--allow-increase", action="store_true")
    ap.add_argument("--only", action="append", metavar="PATH", help="repo-relative; repeatable")
    ap.add_argument("--top", type=int, default=0)
    ap.add_argument("--closure", type=Path, help="also print guard counts for the modules in this pin")
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--root", type=Path, help="override the scanned root (testing)")
    args = ap.parse_args()

    if args.self_test:
        print(f"ANSWERS:         {SCOPE_ANSWERS_SELFTEST}", flush=True)
        print(f"DOES NOT ANSWER: {SCOPE_DOES_NOT_ANSWER_SELFTEST}", flush=True)
        return run_self_test()
    print(f"ANSWERS:         {SCOPE_ANSWERS}", flush=True)
    print(f"DOES NOT ANSWER: {SCOPE_DOES_NOT_ANSWER}", flush=True)

    root = repo_root()
    tmpdir = None
    try:
        if args.root:
            scan_root, label = args.root, str(args.root)
        elif args.rev:
            tmpdir = Path(tempfile.mkdtemp(prefix="guard-discipline-rev-"))
            scan_root, label = extract_rev(root, args.rev, tmpdir), args.rev
        else:
            scan_root, label = root, "working tree"
        counts, n_files = scan(scan_root)
        if args.create or args.update_baseline:
            return refresh_baseline(args.baseline, counts, n_files, args.reason,
                                    args.allow_increase, only=args.only, create=args.create)
        rc = evaluate(counts, n_files, read_baseline(args.baseline),
                      enforce_floors=True, label=label, top=args.top)
        integrity = audit_baseline_integrity(args.baseline)
        if integrity:
            print("\n⚑ RED — the BASELINE ITSELF does not add up (a refresh was bypassed):")
            for f in integrity:
                print(f"   {f}")
            print("\nFAIL: baseline integrity")
            rc = 1
        if args.closure:
            report_closure(counts, args.closure)
        return rc
    except Exception as e:  # noqa: BLE001
        print(f"check-guard-discipline: FATAL — {e}", file=sys.stderr)
        return 2
    finally:
        if tmpdir:
            shutil.rmtree(tmpdir, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
