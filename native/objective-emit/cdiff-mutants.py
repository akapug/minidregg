#!/usr/bin/env python3
"""Planted miscompiles of native/objective-emit/runtime.c, for the generated-program
differential's controls (scripts/check-objective-proofs.sh cgen plants the two below).

usage: cdiff-mutants.py list
       cdiff-mutants.py apply NAME RUNTIME_C OUT_C

Each mutant is one exact-text replacement that must match exactly once: a mutation that
did not happen is an error, never a quiet copy (a control that mutates nothing reads as
a differential that "caught" nothing and a gate that "passed"). `apply` prints the one
line that changed.

The mutants are ordered by how easily a random well-typed program finds them. They are
semantic faults of the kind a C transcription of `stepRaw` could really contain, not
crashes: every one compiles under -Wall -Werror and runs.
"""
import sys

MUTANTS = {
    # naturals: a limb sum of 2^31 or more carries into the next limb
    "add-carry": ("r->limb[i] = (uint32_t)s; carry = s >> 32;",
                  "r->limb[i] = (uint32_t)s; carry = s >> 31;"),
    # applying a specification runs its metadata instead of its extension
    "spec-apply-metadata": ("if (v.tag == V_SPEC) { enter(v.y); return; }",
                            "if (v.tag == V_SPEC) { enter(v.x); return; }"),
}

def main():
    if sys.argv[1:2] == ["list"]:
        for name in MUTANTS: print(name)
        return 0
    if len(sys.argv) == 5 and sys.argv[1] == "apply":
        name, source, out = sys.argv[2:]
        if name not in MUTANTS:
            print(f"cdiff-mutants: unknown mutant {name!r}", file=sys.stderr); return 64
        old, new = MUTANTS[name]
        text = open(source).read()
        if text.count(old) != 1:
            print(f"cdiff-mutants: {name}: the target text occurs {text.count(old)} times in {source}, not once", file=sys.stderr)
            return 1
        mutated = text.replace(old, new)
        assert mutated != text
        open(out, "w").write(mutated)
        print(f"mutant {name}: {old}  ->  {new}")
        return 0
    print(__doc__, file=sys.stderr); return 64

sys.exit(main())
