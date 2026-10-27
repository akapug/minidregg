#!/usr/bin/env python3
"""scripts/lean-modularize.py -- move Lean files onto Lean 4.30's module system, mechanically.

    scripts/lean-modularize.py [--check] FILE.lean...
    scripts/lean-modularize.py --batches ROOT...     print the import-closed conversion batches of ROOT's closure

Why (docs/COORDINATION-2026-10-27.md §3, the lane loop): a non-`module` .olean carries every proof
body, so a one-line proof edit changes the olean and Lake rebuilds every transitive dependent. A
`module`'s public .olean carries statements and exposed definitions only; theorem bodies live in
.olean.private, and Lake's output-hash cutoff stops at a module whose public .olean did not change.
Measured on Lake 4.30 (scratch toy, 2026-10-27): a proof edit under `module` rebuilds no dependent
unless it changes the theorem's exported axiom set or adds a public auxiliary declaration (e.g. the
first `simp [f]` that generates `f.eq_1`); a NON-module importer still rebuilds (it loads the private
parts), and a `module` may import only modules, so conversion runs bottom-up in import-closed batches.

The transform, statement-preserving (no declaration text changes):
  * `module` before the first import;
  * every `import X` becomes `public import X` (keeps today's transitive visibility);
  * a file that evaluates code at elaboration (`native_decide`, `#eval`, `#guard <term>`, `decide +native`)
    also gets `meta import X` for each import (meta imports load the compiled IR, transitively);
  * `@[expose] public section` right after the header: definitions stay unfoldable downstream
    (`decide`, `rfl`, `simp [f]`), theorems are opaque as they always were in the kernel's sense.
  The package-wide `backward.privateInPublic` (lakefile.toml leanOptions) lets a module's OWN private
  names appear in its public statements and exposed bodies; another module still cannot name them,
  so the private-constructor token discipline (TokenCensus) is unchanged.
--check exits 1 if any FILE is not yet a module (no rewrite).
"""
import os, re, subprocess, sys, collections
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from lean_imports import header_layout, file_imports

EVAL = re.compile(r"native_decide|^\s*#eval\b|^\s*#guard\s(?!_msgs)|^\s*#guard_expr\b|decide\s*\+\s*native|^\s*#reduce\b", re.M)


def convert(text):
    first, imports, end, keywords = header_layout(text)
    if "module" in keywords:
        return None
    if "prelude" in keywords:
        raise SystemExit("prelude files are not converted")
    mods = [m for (_, _, _, m) in imports]
    evals = bool(EVAL.search(text[end:]))
    head = "module\n\n"
    head += "".join(f"public import {m}\n" for m in mods)
    if evals:
        head += "".join(f"meta import {m}\n" for m in mods)
    head += "\n@[expose] public section\n"
    return text[:first] + head + "\n" + text[end:].lstrip("\n")


def batches(roots):
    files = [f for f in subprocess.check_output(["git", "ls-files", "*.lean"]).decode().split("\n") if f]
    mods = {f[:-5].replace("/", "."): f for f in files}
    imp = {}
    seen, stack = set(), list(roots)
    while stack:
        m = stack.pop()
        if m in seen or m not in mods:
            continue
        seen.add(m)
        imp[m] = [d for d in file_imports(mods[m]) if d in mods]
        stack += imp[m]
    depth = {}
    sys.setrecursionlimit(20000)
    def d(m):
        if m not in depth:
            depth[m] = 0
            depth[m] = 1 + max([d(x) for x in imp[m]] or [0])
        return depth[m]
    for m in seen:
        d(m)
    return mods, depth


def main(argv):
    if argv[:1] == ["--batches"]:
        mods, depth = batches(argv[1:])
        lay = collections.defaultdict(list)
        for m, k in depth.items():
            lay[k].append(m)
        for k in sorted(lay):
            print(k, len(lay[k]), " ".join(sorted(mods[m] for m in lay[k])))
        return 0
    check = argv[:1] == ["--check"]
    files = argv[1:] if check else argv
    bad = 0
    for f in files:
        text = open(f, encoding="utf-8").read()
        new = convert(text)
        if new is None:
            continue
        if check:
            print(f"not a module: {f}")
            bad = 1
        else:
            open(f, "w", encoding="utf-8").write(new)
    return bad


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
