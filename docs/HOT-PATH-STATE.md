# HOT-PATH lane state (2026-10-27 evening)

Active branch `lane/hot-path-v4` (from main cut 12 f1ce1626); Mac worktree
`/Users/ember/dev/minidregg-lanes/hot-path-world-checkpoint` (its `.lake/build` is an APFS clone, 0 hard links; per-file
`lake env lean --load-dynlib=.lake/native/libmini_kernels_lean.so F.lean -o .lake/build/lib/lean/F.olean -i …ilean`
regenerates a module in dependency order; no closure on the Mac). Design: `docs/HOT-PATH-2026-10-27.md` §2(h).
Ruling (ember): snapshots fast-forwarded, replay = `store audit`; re-genesis is free, so v4 lands on its own cut.

## Landed

| where | what | verified |
|---|---|---|
| main (cuts ≤ 12) | (a) codec resident; J12X 253; THIN; open laps; World/cell compaction a20dad89+6eb74814; the first Spec drafts | see earlier rows on main |
| hot-path-v4 571f9981 | `Compiler/DurableFastForwardSpec.lean`: one `Impl`, one `Spec` (MAC gate, suffix/genesis gates on `ffState`, `Impl.ff` = `ffState` ∘ chain gate ∘ non-executing rebuild, `exact` over the pair, keystone over `Wrote` incl. the light session, `inhabited`, `cutHonest` + backup rule, audit, head seal) | auditor passes 5–9; ninth look: PROOFS MAY START |
| hot-path-v4 107f040d | option A code: `Body.system`/`semantics` (frame v4, epoch `checkpoint/v5`, `.foreignSemantics`); `worldOfCheckpoint`, `trackFrom` in `loadChained`; `Loaded.system` into every sealer; light session `Opening.world` advanced per suffix and append; `sealHead`, Host verb `checkpoint`, seal at a session's clean end; spec `Body4 := Body` | Mac per-file: codec, TurnLog, DurableHistory, DurableLogTags, WorldCompact, DurableReceiverCore, 5 modules after, DurableServed, spec; NOT yet: `DurableStoreAudit`, `Host.Main` (closure) |
| hot-path-v4 77b8f896, af8dd3a1, 5e554051 | `Compiler/DurableFastForwardProofs.lean`: `headState_snapshot`, `resume_honest`, `foldRecords_append`, `worldAt_fastForward`, `openSealed_foreign_semantics` | standard axioms |

## Running

- dregg-ref: compaction candidate build 8f66d6cc (6236826f + compaction), PID file `/build/lanes/hot-path-compact.pid`,
  log `/build/lanes/hot-path-compact-build.log` (+ `out/logs/host-build.log`); 791 modules, seats=2, empty cache;
  predates `closure-lock`.
- dregg-build: BEFORE workload, PID file `/build/lanes/hot-path-codec-perf-before.pid`, output `/build/lanes/hot-path-codec-perf/`.

## Next

1. When the compaction build is DONE (count linked files = 0): launch `/build/lanes/hot-path-v4-build.sh <v4 sha>` on
   dregg-ref (`closure-lock swarm-build`, own PID file `/build/lanes/hot-path-v4.pid`); fix what the closure finds
   (expected: `DurableStoreAudit`, `Host.Main`, persisted-codec census/shape pins for the v4 body).
2. Paired compaction measurement: copy `out/bin/minidregg-host` to dregg-build; profile-open the 483-record snapshot
   (`/build/lanes/hpc-laps/cand-n1/snap`) with it and with the candidate's own Host (`/build/lanes/hot-path-codec-profile-open.sh`).
3. v4 measurement on the cut's candidate (integrator takes hot-path-v4 when closure green + proofs in): a world born
   under it, ~500 and ~1.7k records, cold open before/after; `checkpoint` verb then open (zero fast-forward).
4. OPEN QUESTION for the auditor before the instantiation: the audited `FastForward` hands the open the prefix
   RECORD bytes only; the real open also verifies every prefix tag and reads each entry's receipt root from its tag
   into `rootLog` (old receipts answered without evaluation). Either amend `FastForward` to take the prefix ENTRIES
   (records + tags; `Impl.ff`'s gate then also verifies the prefix tags from the seed's chain, stronger) or move
   `rootLog` into option B. Proposed: the amendment.
4. Proofs: instantiate `Spec` with the real code (`stateHead` = `State.ofSnapshot`, `ffState` = `loadChained`'s
   executing part): next lemmas `foldRecords_append` (suffix fold from the checkpoint World = genesis fold), the
   `worldOfCheckpoint` round trip against `SnapRepresents` (if it fails at a corner, suspect retired/absent cells
   in `State.snapshot`), `sealOpens` from `openSealed_seal`.
5. Then option B (journal read at use, ~50 consumers) statement-first; the `TurnOfIntent` written-keys statement.

Standing: never kill by pattern; stop only by PID files; filtered tests; never the demo box; named-file commits;
dregg-ref closures one at a time through `closure-lock`; seed only `.lake/packages`.
