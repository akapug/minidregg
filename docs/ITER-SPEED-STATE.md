# Iteration-speed lane: state (present-state; rewrite whole, never append)

Branches: `lane/iter-speed` (tooling, safe for main), `wip/iter-speed-modules` (the Host closure on the
module system; NOT for main until the whole closure builds green on a box). Mac worktree
`/Users/ember/dev/minidregg-lanes/iter-speed` (edits only, no Lean); dregg-ref `/build/lanes/iter-speed`;
hbox `/tank/dregg-build/iter-speed/src` (wave builds, `wave2.sh`, PID `wave2.pid`).

## What makes an edit expensive (measured, Lake/Lean 4.30)

- Lake already has output-hash cutoff: a module whose outputs are byte-identical stops the cascade
  (a comment edit rebuilds one module). But a non-`module` `.olean` contains every proof body, so a
  proof edit changes it and every transitive dependent rebuilds.
- Under `module`, theorem bodies live in `.olean.private`; a proof edit leaves the public `.olean`
  identical and NO dependent rebuilds (toy: A edited, B and C untouched). Exceptions: the edit changes
  the theorem's exported axiom set (`exportedAxiomsExt` is public), or creates a public auxiliary
  declaration (first `simp [f]` creates `f.eq_1`). A `meta import` dependent also cuts off.
- A NON-module importer of a module still rebuilds on every edit (it loads the private parts), and a
  `module` may import only modules: conversion is bottom-up and pays off only once the edited file and
  its direct importers are modules. NativeHost needs 781 of the 789 Host-closure modules converted;
  the longest import chain in the closure is 90 modules. Mathlib, Batteries and Lean core are modules.
- `lake build <Module>` compiles no C objects and links nothing (the `.c` is emitted by the same
  `lean` process); only exe targets compile C and link.
- `lake env lean FILE` does not pass the package's leanOptions; `lake lean FILE` does (3 false errors
  vs 0 on a converted file, 4.4 s, 2.1 GB).

## The conversion (scripts/lean-modularize.py, mechanical, statement-preserving)

`module`; every import `public import`; `meta import` of each import where the file evaluates code
(`native_decide`, `#eval`, `#guard` term); `@[expose] public section`; `import all` of the core modules
in `CORE_REDUCE` where the file uses `decide` (core does not expose `Nat.toDigits`, `List`/`Array`
toString, `Array.map`, `Array.zip`, the UTF-8 encoder). lakefile.toml: `backward.privateInPublic`
(a module's own private names in its public statements; other modules still cannot name them, so the
TokenCensus private-constructor discipline holds) and `compiler.relaxedMetaCheck` (an in-file elaborator
calling a plain def, e.g. `#assert_axioms` -> `standard`); `.warn` silenced in moreLeanArgs.

## Numbers

| step | where | result |
|---|---|---|
| batch 1: 109 Theory modules as modules | dregg-ref | green, 124 s, cgroup peak 4.5 GB |
| wave 2: 791 Host-closure modules | hbox | running |
| baseline (a)/(b)/(c) on a warm non-module tree | dregg-ref | waiting for cut 13's build/ (scratch/baseline.sh) |

## Next

1. Wave 2 errors: fix the frontier (grow CORE_REDUCE / per-file `import all` / meta), rebuild, until green.
2. Measure on the converted warm tree: proof edit in Kernel/NativeHost -> `lake build Host.Main` rebuild count.
3. Baseline on dregg-ref when warm; lean-ask round trip (`check --stdin`) on NativeHost.
4. COORDINATION §3 lane loop with the numbers; land wip as one push (one full invalidation, not per batch).
