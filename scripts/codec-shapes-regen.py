#!/usr/bin/env python3
"""Re-emit Compiler/PersistedCodecShapes.lean and bump every persisted identity
whose codec structure changed under it.

usage: scripts/codec-shapes-regen.py [--check]

1. Builds the census's imports (`lake build`, wrapped in `swarm-build` when it
   exists), then runs the census with `#emit_persisted_codec_shapes` in place of
   `#assert_persisted_codec_tags` on a temporary copy, writing fresh pins.
2. An identity whose fingerprint moved is BUMPED where it is spelled: a
   `.../vN` string literal becomes `.../v(N+1)` in every *.lean and native/**/*.rs
   file that spells it exactly.  An identity with no `/vN` suffix (a raw version
   byte, a bare prefix) cannot be bumped mechanically: it is listed and the
   script exits 2 without writing pins.
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
    ]
    failed = [name for name, got, want in cases if got != want]
    for name, got, want in cases:
        print(("ok   " if got == want else "FAIL ") + name + ("" if got == want else f": {got} != {want}"))
    sys.exit(1 if failed else 0)


def bump(identity_text):
    match = re.fullmatch(r"(.*/v)(\d+)", identity_text)
    if not match:
        return None
    new = f"{match.group(1)}{int(match.group(2)) + 1}"
    old_literal, new_literal = f'"{identity_text}"', f'"{new}"'
    touched = []
    for path in spelled_files():
        text = path.read_text(errors="surrogateescape")
        if old_literal in text:
            path.write_text(text.replace(old_literal, new_literal), errors="surrogateescape")
            touched.append(str(path.relative_to(ROOT)))
    return new, touched


def main():
    if "--selftest" in sys.argv[1:]:
        selftest()
    check = "--check" in sys.argv[1:]
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
            return
        unbumped = []
        for hexid, text in moved:
            result = bump(text)
            if result is None or not result[1]:
                unbumped.append((hexid, text))
            else:
                bumped.add(hexid)
                print(f"BUMPED {text} -> {result[0]} in {result[1]}")
        sources = [(str(path.relative_to(ROOT)), path.read_text(errors="surrogateescape"))
                   for path in source_files() if path not in (TAGS, PINS)]
        repins, manual = classify(unbumped, baseline, fresh, bumped,
                                  declared_prefixes(TAGS.read_text()), sources)
        if not manual and len(repins) == len(moved):
            for text, child in repins:
                print(f"RE-PINNED bare prefix {text} (a strict prefix of the bumped {child})")
            PINS.write_text(fresh_text)
            print(f"wrote {PINS.relative_to(ROOT)}: {len(fresh)} pins (round {round_})")
            return
        if manual:
            print("structure moved under identities with no mechanical bump (edit by hand, then rerun):")
            for text in manual:
                print(f"  {text}")
            sys.exit(2)
    sys.exit("no fixed point after 8 rounds")


if __name__ == "__main__":
    main()
