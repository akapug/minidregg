# HOT-PATH lane state (2026-10-27 night)

Branch `lane/hot-path-v4` (from main cut 12 f1ce1626). Mac worktree `/Users/ember/dev/minidregg-lanes/hot-path-world-checkpoint`
(edit and git only). **No Lean on the Mac at all** (coordinator, after the Mac ran out of swap): every elaboration runs
on dregg-ref (`ssh -o IdentitiesOnly=yes -i ~/.ssh/id_portable lanes@2.31.71.194`; packages warm at
`/build/minidregg/.lake/packages`; per-file `lake env lean --load-dynlib=.lake/native/libmini_kernels_lean.so F.lean` there,
closures through `closure-lock swarm-build`). Integration is continuous (pushes land on main as they arrive); no lane waits
on its own closure; the continuous build names reds, fix them forward. Statements go to the auditor (agent
af7a93e7b8ba729d4) with a copy to the coordinator. Stop processes only by PID file or the harness task that started them.
Rulings: snapshots fast-forwarded, replay = `store audit` (ember); option A now, B next; re-genesis is free.

## Landed on lane/hot-path-v4

| sha | what |
|---|---|
| e4e22cb0, aa025c8d, fce764f7, cfc70253 (spec part) | `Compiler/DurableFastForwardSpec.lean`, auditor passes 5–14, NOTHING FURTHER from the auditor (pass 14 addendum, lane/audit-platform c8f30e7bb). One `Impl`, one `Spec`. `FastForward` takes the prefix ENTRIES; `Impl.ff` = `ffState` (prefix-free) then the gate (count, prefix tags from the seed's chain, chain = checkpoint's) then decode + root log from tags. `ofOpened : Opened → Except String Loaded4` (the session build may refuse); laws `viewOpened` (on success), `reopens` (succeeds under `exact`'s hypotheses), `buildSound` (a built session's snapshot is `resume` of the whole image from `stateCheckpoint` at its height: a reused prefix nullifier makes the build refuse); `suffixGate`/`genesisGate` pin `stateCheckpoint` to `body.state` / `State.ofSeed`. Plus MAC gate, `exact`, `representsFromDerived`, keystone over `Wrote`, `inhabited`, `cutHonest`, audit, `headSealZero`. |
| 107f040d | option A code: v4 body (`system`, `semantics`), frame v4, epoch `checkpoint/v5`, `.foreignSemantics`; every sealer seals the session's World; the light session advances its World; `sealHead` + Host verb `checkpoint` + seal at a session's clean end. |
| cfc70253 | `Kernel/DurableEngineSuffix.lean` (standard axioms): `Engine.Beneath`, `preflight_light_congr`, `replay_beneath` (+`_of_left`), `resume_suffix` (admissible + `Disjoint` + the prefix-free replay reaching `e` ⇒ `resume = some ((headState e).snapshot all)`), `resume_disjoint` (converse), `disjointFast_iff`. |
| ebf92e7b | the open split: `openState` (executing; checkpoint + suffix only: suffix tags from `body.chain`, decode, frontier walk, replay from `Engine.ofState state []`, World fold from the checkpoint's World) then `openLoaded` (the gate; accumulator vs the prefix's last tag; prefix decode; `admissibleFast` + `disjointFast`; resume proof by `resume_suffix`; engine = `Engine.ofState (headState e) all`; chains = prefix's ++ suffix's tail; indexes, root log, track via `trackOfWorld`; head root check). `trackFrom` deleted; `trackOf` = `trackOfWorld` over the genesis fold. Proofs: `firstBadTag_append`, `firstBadTag_head`, `verifyTags_append` (the tag split at a checkpoint). |
| 77b8f896, af8dd3a1, 5e554051 | proofs: `headState_snapshot`, `resume_honest`, `foldRecords_append`, `worldAt_fastForward`, `openSealed_foreign_semantics`. |

Checked: Mac per file (before the rule) the core, HostRefinesWorldCore, DurableHistoryStoreCore, DurableEngineSuffix, the
Spec at fce764f7+gate pins, the tag lemmas in a scratch module. UNCHECKED: DurableReceiverIO, CredentialAuthorityDomainReceiver,
DurableServed, DurableStoreAudit, Host.Main, DurableFastForwardProofs at ebf92e7b (the appended tag lemmas).

## Measured: the compaction (dregg-build, 2026-10-27 20:11Z, load 15-19, the 483-record snapshot)

Paired cold opens (`HOST CONFIG describe`), alternating: candidate 6236826f Host **189.4 s, 193.7 s**; the same plus the
compaction (8f66d6cc, built on dregg-ref) **69.1 s, 64.1 s**: 2.9x, `describe` output byte-identical. Sampled (121
samples, `/build/lanes/hpc-laps/compact-n483/profile.txt`): still 98% in `trackOf` -> `foldRecords` (the genesis fold):
`DFinsupp.update` 62%, `TurnOfIntent.ofCells` 52%, `World.admit` 40%. v4 (no genesis fold at open) is the fix; the
`TurnOfIntent` written-keys item shrinks each suffix step.

## Running

- dregg-ref: the v4 closure `/build/lanes/hot-path-v4-build.sh e4e22cb0` (PID file `/build/lanes/hot-path-v4.pid`, log
  `/build/lanes/hot-path-v4-build.log`, tree `/build/lanes/hot-path-v4`; queued on `closure-lock`). It checks 107f040d's
  DurableStoreAudit and Host.Main, NOT the split (ebf92e7b).
- dregg-build: BEFORE workload, PID file `/build/lanes/hot-path-codec-perf-before.pid`, output `/build/lanes/hot-path-codec-perf/`.

## Next (successor: start here)

1. When the v4 closure ends: fix forward what it names. Then overlay the files changed since e4e22cb0 into its tree
   (`git archive ebf92e7b Kernel/DurableEngineSuffix.lean Compiler/DurableReceiverCore.lean Compiler/DurableFastForwardSpec.lean
   Compiler/DurableFastForwardProofs.lean docs | tar -x -C /build/lanes/hot-path-v4/<src>`) and rebuild incrementally through
   `closure-lock swarm-build` (the core's ~430 dependents, Host.Main included): the check of the split.
2. Instantiate `Spec` (one more amendment first, statement to the auditor): the session build reads the entries BELOW the
   checkpoint (the last prefix tag for the accumulator check, the tags for the root log and head tag, the bytes for the
   chain proof), so `Opened` needs `below : List Entry` (opaque, never executed). Then `Loaded4 := Loaded`,
   `State4 := Σ suffix, OpenState rootBytes suffix`, `ffState := openState`, `stateBase := (base.1, baseChain)`,
   `stateCheckpoint := base.2.1`, `stateHead := headState engine`, `stateWorld := world.toOption`, `ofOpened` = the
   session half of `openLoaded`. Proofs in hand: `buildSound` from `Loaded.resumed`; `reopens` and `exact` from
   `resume_disjoint` + `resume_honest` + `verifyTags_append` + `worldAt_fastForward`; teeth pole: a reused prefix nullifier
   makes `resume` none (`nullifiersFreshCheck`, `.alreadyConsumed`).
3. When the BEFORE run ends: its reopen row at ~1.7k (`/build/lanes/hot-path-codec-perf/`).
4. v4 measurement on the cut's candidate: a world born under it (~500, ~1.7k records), cold open before/after; the
   `checkpoint` verb then an open (zero fast-forward).
5. Option B statement-first (journal read at use; ~50 consumers); the `TurnOfIntent` written-keys statement.
