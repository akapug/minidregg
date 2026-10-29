# Iteration-speed lane: state (present-state; rewrite whole, never append)

The Host closure is on Lean 4.30's module system (landed on `lane/iter-speed`, merged by the integrator).
Agent: the iter-speed successor (lane continuation by about 580k tokens, hand off at about 600k).

## What makes an edit expensive (measured, Lake/Lean 4.30)

- Under `module`, a theorem's proof lives in the module's private olean. A proof edit that keeps the
  theorem's exported facts leaves the public olean byte-identical, and no importer rebuilds. Measured on
  the real tree: a proof edit in `Theory/Store.set_ne` rebuilds 9 modules (Store itself plus the persisted-codec
  census and its 7 non-module importers), not 631.
- Exceptions (each changes the public olean, so every importer rebuilds): a changed statement or definition;
  a proof whose rfl-lemma status changes (`:= rfl` to a tactic proof: the first NativeHost probe, 98
  modules); a new public auxiliary (first `simp [f]` creating `f.eq_1`); a changed exported axiom set.
- Lake keys a rebuild on the TRANSITIVE import closure's oleans: a data change (a pin value, a new registry
  tag) rebuilds every module below it even when their own outputs would not change. Measured on the warm
  converted tree: one pin value 438 modules / 1,531 s / 22.3 GB; one new tag in
  `Compiler.PersistedCodecTags` 479 modules / 2,114 s. The cure is dependency inversion (below), not more seats.
- A non-module importer of a module rebuilds on every edit below it (it reads the private part too):
  the census (`KEEP`, 235 s) and its importers. `Kernel/ConsentAnchor` imports the census only as a build-order
  gate; cutting that import takes the census and the 7 consent files out of every lane closure.
- `lake build <Module>` compiles no C objects; only exe targets do.
- Per file: `scripts/pipeline/lane-check FILE` is the only entry point (its own stale check, rebuilds through
  the slot/closure-lock, then `lake lean`, which applies leanOptions; `lake env lean` does not, and a bare
  `lake lean` builds stale imports outside any lock).

## Numbers (dregg-ref, closure-lock, cache off)

See the landing commit message for the before/after table (filled from `scratch/after2/summary.txt`,
`scratch/deep-conv/summary.txt`, `scratch/leanask/`, `scratch/regen-probe/summary.txt` in `/build/lanes/iter-speed`).

## The conversion (scripts/lean-modularize.py; statement-preserving)

`module`; `public import` of every import; `meta import` where the file evaluates code or defines an
elaborator/macro; `@[expose] public section`; RULES and PER_FILE header lines (each printed by
`scripts/module-hidden-bodies.sh FILE` on a box, never guessed); KEEP: files that stay non-modules (the
persisted-codec census and its importers). lakefile: `backward.privateInPublic`, `backward.proofsInPublic`,
`compiler.relaxedMetaCheck`. Hand-written: `Theory/DeriveEncodable.lean` (Mathlib's Encodable handler with
`S` public; delete when Mathlib exposes `S`). `Host.run` is a dispatcher over one `runCommand<Name>` per
command (the single 2,900-line declaration ran past its heartbeat budget as a module; same profile as the
non-module build). Re-derivation over a newer main: `scratch/land.py wip/iter-speed-modules` in a clean
worktree on the tip (it 3-way merges COORDINATION and the census, applies the split, converts, regenerates).

## The codec census (StoreEpoch moved once at this landing)

The census hashes compiler auxiliaries (`match_N`, `_sparseCasesOn_N`, `_proof_N`) by structure, recursively,
so a module and a non-module build agree; teeth in `Compiler/PersistedCodecTagCensusSelfTest.lean`. Pins were
re-emitted once from the tree's own census (never a saved copy of it: a stale copy without A11's owners fix
emitted placeholder fingerprints) and are byte-identical from hbox and dregg-ref; no identity bumped; the
derived StoreEpoch moved: the next candidate re-geneses (DEMO-PREFIX §5).

## Next (the build-time quest; ember's ruling: one seam end to end first)

1. Codec registry seam, as interface plus instance (`docs/BUILD-INVERSION-2026-10-28.md`, to write first):
   pins and the concrete `StoreEpoch.current`/`persistedCodecCorpus` leave `Compiler.DurableCheckpointCodec`
   for one downstream module; kernel code uses the existing `...For epoch` forms; identities are spelled at
   their owners and the registry becomes a downstream manifest imported only by the census and emitters;
   ConsentAnchor→census import cut. Before/after: pin change 438 modules / 1,531 s; new tag 479 / 2,114 s.
2. Theory.Store and WorldRoot seams only if (1) takes a pin regen to seconds or minutes.
3. RAM build on hbox (tmpfs tree, seats by memory) vs dregg-build's 4x2; shared input-keyed Lake cache with
   locked writes only.
4. mk-lane: `.lake/build` as a real copy (`cp -a --reflink=auto`), never hard links (drafted in the lane's
   scratch; hbox ZFS has block cloning enabled on the pool but `zfs_bclone_enabled=0`, so real copies there).
   Trace check on hbox (2026-10-28): every trace in the pipeline base and 9 lane trees agrees with its olean;
   no re-seeding needed.

## Lane pool (stopped mid-quest, 2026-10-28, on the root's word)

- `scripts/pipeline/lane-tree` (acquire LANE [REF] | release | renew | status | gc | init SEED N), configured per box by `pool.env`; `lane-check` renews a pooled tree's lease and both refuse loudly when swarm-build cannot reach the user bus (lib.sh `pipeline_user_bus`). Not yet in COORDINATION or the lane brief.
- dregg-ref only: `/build/pool/{pool.env,bin/lane-tree,repo.git,t1,t2,t3}`; shared read-only packages `/build/shared/packages-ed3deb884a05` (7.6 GB, one copy: 516 s, today's per-lane packages cost); cache `/build/lake-cache`. t1 holds a real-copied `.lake/build` from 694415d5d; t2/t3 have none. No leases held.
- Use: `. /build/pool/pool.env; t=$(/build/pool/bin/lane-tree acquire <lane> origin/lane/<lane>)`, sync or check out there, `scripts/pipeline/lane-check FILE`, `lane-tree release <lane>`. Never as root, never inside closure-lock.
- Not done: the measurement (t1 cache fill, t2 build from the cache, incremental lane-check), hbox and dregg-build pools, reclaim, docs. A queued `closure-lock swarm-build lake build Host.Main Host.ClientConsentSession` from the stopped measurement (PID 2023359, cwd /build/pool, no PID file) is still waiting for the lock: when it runs it fails at once (not a Lake project); left for the owner to stop.
