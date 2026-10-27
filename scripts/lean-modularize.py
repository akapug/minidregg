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


# Core definitions that kernel reduction (`decide`, `decide +kernel`) in this tree unfolds and that
# Lean's own modules do not expose; a module reaching them sees an opaque constant and `decide` gets
# stuck (measured: `toString`/`s!` of Nat and List, `Array.map`, `Array.zip`). `import all` of the core
# module restores the bodies for that one file. The toolchain never changes under a build, so the
# private-olean dependency costs no rebuild. Grow this list when a converted file's `decide` sticks.
CORE_REDUCE = ["Init.Data.Repr", "Init.Data.ToString.Basic", "Init.Data.ToString.Extra", "Init.Data.Array.Basic",
               "Init.Data.ByteArray.Basic", "Init.Data.String.Decode", "Init.Data.String.Defs"]
DECIDE = re.compile(r"\bdecide\b")
CORE_NOTE = "-- `decide` reduces these core definitions, which core does not expose (module system).\n"
SECTION = "@[expose] public section\n"
CORE_BLOCK = re.compile(r"\n-- `decide` reduces these core definitions[^\n]*\n(?:import all [^\n]*\n)+")


def convert(text):
    """The module form of text, or None when text is already in it."""
    first, imports, end, keywords = header_layout(text)
    if "prelude" in keywords:
        raise SystemExit("prelude files are not converted")
    have_all = {m for (s, e, mods, m) in imports if text[s:e].split()[-2:-1] == ["all"]}
    want_all = [m for m in CORE_REDUCE if m not in have_all] if DECIDE.search(text[end:]) else []
    if "module" in keywords:
        if not want_all:
            return None
        # one core block per file: drop the old one, write the union once
        core = [m for m in CORE_REDUCE if m in have_all or m in want_all]
        text = CORE_BLOCK.sub("\n", text)
        i = text.find("\n" + SECTION)
        if i < 0:
            raise SystemExit("a module without `@[expose] public section` after its header: convert it by hand")
        return text[:i + 1] + CORE_NOTE + "".join(f"import all {m}\n" for m in core) + text[i + 1:]
    mods = [m for (_, _, _, m) in imports]
    evals = bool(EVAL.search(text[end:]))
    head = "module\n\n"
    head += "".join(f"public import {m}\n" for m in mods)
    if evals:
        head += "".join(f"meta import {m}\n" for m in mods)
    if want_all:
        head += "\n" + CORE_NOTE + "".join(f"import all {m}\n" for m in want_all)
    head += "\n" + SECTION
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
