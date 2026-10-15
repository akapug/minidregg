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
--check: emit and compare only; exit 1 if the pins are out of date.
"""
import os, pathlib, re, shutil, subprocess, sys, tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
CENSUS = ROOT / "Compiler/PersistedCodecTagCensus.lean"
PINS = ROOT / "Compiler/PersistedCodecShapes.lean"
PIN_LINE = re.compile(r'\("([0-9a-f]*)", "([0-9a-f]{16})"\),?  -- (.*)$')


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


def spelled_files():
    for path in ROOT.rglob("*.lean"):
        if ".lake" not in path.parts:
            yield path
    for path in (ROOT / "native").rglob("*.rs"):
        if "target" not in path.parts:
            yield path


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
    check = "--check" in sys.argv[1:]
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
        if not moved:
            PINS.write_text(fresh_text)
            print(f"wrote {PINS.relative_to(ROOT)}: {len(fresh)} pins (round {round_})")
            return
        manual = []
        for hexid, text in moved:
            result = bump(text)
            if result is None or not result[1]:
                manual.append(text)
            else:
                print(f"BUMPED {text} -> {result[0]} in {result[1]}")
        if manual:
            print("structure moved under identities with no mechanical bump (edit by hand, then rerun):")
            for text in manual:
                print(f"  {text}")
            sys.exit(2)
    sys.exit("no fixed point after 8 rounds")


if __name__ == "__main__":
    main()
