# un-effects: continuation state (2026-10-27)

Branch `lane/un-effects` (worktree `/Users/ember/dev/minidregg-lanes/un-effects`). Statement:
`DOMAINS.md`, "The effect Plan: statement first". Design note: `scratch/DESIGN.md` in the worktree,
which is not committed.

## What landed (pushed)
- a913a98c: the Lean change.
  - `decodePlan` reads `await | transfer | commit`. Both effects use `PlanSource.performed`.
  - The record's await source gains `performed (Verdict)`, with a two-octet verdict wire. ACTIVITY-RECORD goes from v8 to v9, renamed in PersistedCodecTags.
  - `AwaitOutcome.settled` and `effectProtocol`.
  - `commitYield`, `segmentCommit` and `resumedSegment` gain a `funds` argument. `transferVerdict`, `effectOps` and `withEffect` are new.
  - `settle` handles a performed await. deliver loads the Book first.
  - `ObjectiveActivityEffect.lean` holds the statements.
- 5e116ec9: the keystone is proved in `Kernel/ObjectiveActivityEffect.lean`. Statements and their proofs:

  | Statement | Stated at | Proof |
  |---|---|---|
  | PerformedStatement | :60 | `performed` |
  | DeliveryPerformedStatement | :80 | `deliveryPerformed` |
  | TransferMovesStatement | :94 | `transferMoves` |
  | RefusedStatement | :103 | `refused` |
  | VerdictStatement | :120 | `verdict` |
  | DeliveryRefusedStatement | :135 | `deliveryRefused` |
  | CommitJudgedStatement | :149 | `commitJudged` |
  | ResumedStatement | :161 | `resumed` |

  The poles (`satisfiable`, `teeth`, `premiseInhabited`) are proved too. Axioms are pinned.

  At that point the ObjectiveProofs umbrella built green on the Mac, before the rebase onto main 9cafd22f.
- 2aaf5ec9: the audit's pass-11 additions.
  - Statements: FundsAgree :179, DepositIndependent :203, BirthCommitJudged :214, DeliverLawRefuses :226, CommitWritesPole :315, CommitLawRefusedPole :331.
  - Their proofs: `fundsAgree`, `depositIndependent`, `birthCommitJudged`, `deliverLawRefuses`, `commitWrites`, `commitLawRefused`.
  - Kernel fix: `deliver` refuses `payerInvalid` when the submitter's account or the collector is the purse (`Delivery.purseApart`).
  - `commitYield_spec`'s write clause is restated; consumers use `commitYield_built`.
  - The auditor accepted these statements (addendum on lane/audit-platform 01293d350).
- e6c7ed42: dues, bounty Board, play, ballot, story and commons are re-expressed on the kernel protocol.
  - `check-preview.ts` checks rows marked `"protocol": "kernel"`.
  - Native scenarios `dues` and `effect` (world/activity/Effects.obend) are added.
- 0fa0eb98: two more native rows in the `effect` scenario, `deliver-from-the-purse-refused` and `effect-law-refuses-delivery`. Also the dues README and the DOMAINS table.

## Elaboration status (the Mac, load ~200)
- At the tip, `Kernel/ObjectiveActivity.lean` elaborated green in build8.
- Still elaborating, or not yet reached, at the handoff:
  - `Kernel/ObjectiveActivityEffect.lean` (the pass-11 proofs are unrun)
  - `ObjectiveUpgradeInvariant`, `ObjectiveActivityUpgrade`, `ObjectiveCheckpointInvariant`, `ObjectiveReferenceLift`, `ObjectiveTurnTotalityStorage`, `ObjectLawEnforced`
  - `Host.ObjectiveActivityJson`, `Host.ObjectiveBendFrontEnd`
- build8: PID file `scratch/build8.pid`, log `scratch/build8.log`.
- The codec pins (`Compiler/PersistedCodecShapes.lean`) are NOT re-emitted. Run `scripts/codec-shapes-regen.py` on a box. Until then the census line for ACTIVITY-RECORD v9 is red.

## build8 result (arrived after the handoff): ObjectiveActivityEffect.lean RED, by name
- :235-244 `addCapacity` unknown in DeliverLawRefusesStatement: open `Minidregg.Kernel.ObjectiveTariff (addCapacity)`.
- :587-604 `applyOperations`, `registerAccounts`, `deregisterAccounts`, `deregisterAccounts_accounts` unknown: add
  them to the `open Minidregg.Theory.CanonicalResourceKernel (...)` line; then recheck `fundsAgree`'s `omega` goals.
- :660 `deliverLawRefuses`: a `dsimp only` made no progress (drop it, then re-read the next goal).
- Everything else in the file elaborated (no other errors named; the pass-11 statements, commitWrites,
  commitLawRefused, depositIndependent, birthCommitJudged passed). Importers beyond the file were not reached.

## Owed
1. Read build8's result and fix forward any red in the Effect file. Its proofs have not been elaborated yet; the riskiest are `fundsAgree`, `deliverLawRefuses`, `commitWrites` (`rfl`) and `encodeRecord_length_verdict`.
2. `payerInvalid`'s docstring (`Kernel/ObjectiveActivity.lean`, Refusal) must name "a delivery's submitter account, or the collector, is the activity's purse". The auditor would prefer a distinct constructor; the deputy says only if the shared name is ambiguous.
3. Re-emit the codec pins: `scripts/codec-shapes-regen.py`.
4. Run the cohort gate and record counts. Rows renamed:
   - ballot `BallotActivityTallyYieldsPublication`
   - story `StoryActivitySealCommitsOnce`
   - commons `CommonsLifecycleRefusedAdmissionStaysAtYield` and `CommonsLifecycleAdmissionAnsweredOnlyBySettled`

   The obend syntax of the rewritten apps (`if ... then ... else` with calls, the nested `match`) is unverified by the front end.
5. Native rows on a candidate built from main with this branch merged:
   - `effect`, with the satisfiable, teeth, purse-as-submitter and law-refused rows
   - `dues`
   - then scenarios to write for bounty, play, ballot, story and commons (the driver has only dues and effect)

   Write evidence under `docs/evidence/2026-10-27-world-native/<domain>/`, and update each README's native line (only dues is updated so far).
6. drex is out of scope (an action list).

## Commands
- Cohort gate (Mac or any box with bun): `bash scripts/check-world-cohorts.sh` (subset: `WORLD_COHORTS_ONLY="world/dues world/bounty world/play world/ballot world/story world/commons"`).
- Native (dregg-build, worktree at the candidate's commit, under `swarm-build`, PID file, one box-wait):
  - `scripts/world-native-admit.sh activity --route activity --scenario effect --method world/activity/Effects.obend --entry effects --deposit 100000000`
  - `scripts/world-native-admit.sh dues --route activity --scenario dues --entry dues --deposit 300000000`
  - `scripts/world-native-admit.sh bounty --route activity --scenario bounty --method world/bounty/BountyBoard.obend --entry bounty --deposit 300000000`
  - `scripts/world-native-admit.sh play --route activity --scenario play --entry play --deposit 300000000`
  - `scripts/world-native-admit.sh ballot --route activity --scenario ballot --entry ballot --deposit 100000000`
  - `scripts/world-native-admit.sh story --route activity --scenario story --entry tell --deposit 100000000`
  - `scripts/world-native-admit.sh commons --route activity --scenario commons --entry lifecycle --deposit 100000000`
  - For `dues`, the driver builds the `Opening` input and the `{paid: Nat}` state type itself.
