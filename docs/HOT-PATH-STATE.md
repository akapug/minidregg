# HOT-PATH lane state (2026-10-27 night)

Branch `lane/hot-path-v4` (from main cut 12 f1ce1626). Mac worktree `/Users/ember/dev/minidregg-lanes/hot-path-world-checkpoint`
(`.lake/build` is an APFS clone, 0 hard links). Per-file check, in dependency order, writing the olean so importers see it:
`lake env lean --load-dynlib=.lake/native/libmini_kernels_lean.so F.lean -o .lake/build/lib/lean/F.olean -i .lake/build/lib/lean/F.ilean`
(the dynlib is needed for the `native_decide` epoch pins). The modules downstream of the codec in `Host.Main`'s closure, in
order, are listed by the script in this file's history (430; DurableReceiverCore is 6th, DurableServed 12th, DurableStoreAudit
269th). Rules: no closure on the Mac; do not block on a closure (the integrator's hourly cut is the closure; fix its reds
forward); dregg-ref closures through `closure-lock`; seed only `.lake/packages`; stop processes only by PID file.
Rulings: snapshots fast-forwarded, replay = `store audit` (ember); option A now, B next; re-genesis is free, v4 lands on its
own cut when the closure is green and the proofs are in.

## Landed on lane/hot-path-v4

| sha | what |
|---|---|
| e4e22cb0 | `Compiler/DurableFastForwardSpec.lean` (auditor passes 5–13): one `Impl`, one `Spec`. `FastForward` takes the prefix ENTRIES (records + tags); `Impl.ff` = `ffState` (executing: head state and World from checkpoint + suffix; no prefix in its type) then the gate (count = checkpoint height, every prefix tag verifies from the seed's chain, recomputed chain = checkpoint chain), then records decoded and the root log read from tags. `Opened.view` = executed part + `rebuildDerived` + `State.snapshot head records` + root log. Laws: MAC gate (+ `sealOpens`, `.foreignSemantics`/`.badMac`), `suffixGate`/`genesisGate` on `ffState`, `exact` over the pair, `viewOpened`, `representsFromDerived`, keystone over `Wrote` (full + light sessions, seals at any height via one `bodyOf`, reopens of the Store's own entries), `inhabited`, `cutHonest` (+ backup rule `newestAtOrBelow`/`openInputs`), audit sound/refuses, `headSealZero`. `View.Honest` pins the root log to `replayRoot`. |
| 107f040d | option A code: codec `Body.system`/`semantics`, frame v4, epoch `checkpoint/v5`, `.foreignSemantics`; `worldOfCheckpoint`, `trackFrom` in `loadChained`; `Loaded.system` in every sealer; light session `Start.world`/`Opening.world` advanced per suffix and append; `sealHead` + Host verb `checkpoint` + seal at a session's clean end; spec `Body4 := Body`, `Body.world`. Per-file green on the Mac up to DurableServed; `DurableStoreAudit`, `Host.Main` unchecked until a closure. |
| 77b8f896, af8dd3a1, 5e554051 | `Compiler/DurableFastForwardProofs.lean` (standard axioms): `headState_snapshot`, `resume_honest`, `foldRecords_append`, `worldAt_fastForward`, `openSealed_foreign_semantics`. |

## Measured: the compaction (dregg-build, 2026-10-27 20:11Z, load 15-19, the 483-record snapshot)

Paired cold opens (`HOST CONFIG describe`), alternating: candidate 6236826f Host **189.4 s, 193.7 s**; the same plus the
compaction (8f66d6cc, built on dregg-ref) **69.1 s, 64.1 s**: 2.9x, `describe` output byte-identical. Sampled (121
samples, `/build/lanes/hpc-laps/compact-n483/profile.txt`): still 98% in `trackOf` -> `foldRecords` (the genesis fold):
`DFinsupp.update` 62% (chains between compactions), `TurnOfIntent.ofCells` 52%, `World.admit` 40% (`absentCheck`/
`retired` 31%, `pinCheck` 30%, `cellRoot` -> `StoreCodec.encode` 29%). The fold is the whole remaining cost: v4 (no
genesis fold at open) is the fix; the `TurnOfIntent` written-keys item would shrink each suffix step.

## Running (nothing of mine waits on them)

- dregg-ref: compaction build 8f66d6cc DONE (rc 0, 56 min, peak 21.5 G; binaries `/build/lanes/hot-path-compact/out/bin/`). The v4 closure
  `/build/lanes/hot-path-v4-build.sh e4e22cb0` (PID file `/build/lanes/hot-path-v4.pid`, log `hot-path-v4-build.log`; it
  waits for the compaction PID to exit, then `closure-lock swarm-build` the candidate builder; prints linked-file count).
- dregg-build: BEFORE workload, PID file `/build/lanes/hot-path-codec-perf-before.pid`, output `/build/lanes/hot-path-codec-perf/`.

## Next (successor: start here)

1. Restructure the open as `ffState` ∘ gate ∘ rebuild (coordinator's order): extract from `loadChained` a pure
   `openState key seed checkpoint suffix head : Except String OpenState` (checkpoint open with semantics; suffix tags from
   `body.chain`; frontier walk; replay of the suffix from the checkpoint state; `trackFrom`'s suffix fold), and a gate +
   rebuild (prefix tags from the seed's chain, chain = `body.chain`, decode, indexes/journal/history, root log from tags).
   OBSTACLE found: `resume` decides `State.Admissible image`, which needs every cell id of the WHOLE log; under the
   split, admissibility moves to the gate (a non-executing check over the decoded records); the Spec's `ffState` then
   resumes without it. Needed lemma: `verifyTags` over all entries from the seed's chain = prefix tags from the seed's
   chain ∧ suffix tags from the chain at the checkpoint height (split of `firstBadTag`).
2. Instantiate `Spec` with the real code (`stateHead` = `State.ofSnapshot`, `stateWorld` = the track's World): the pieces
   proved so far give `exact` (`headState_snapshot`, `resume_honest`, `worldAt_fastForward`) and half of `macRefusals`.
3. When the BEFORE run ends: its reopen row at ~1.7k (`/build/lanes/hot-path-codec-perf/`).
4. v4 measurement on the cut's candidate: a world born under it (~500, ~1.7k records), cold open before/after; the
   `checkpoint` verb then an open (zero fast-forward).
5. Option B statement-first (journal read at use; ~50 consumers); the `TurnOfIntent` written-keys statement.
