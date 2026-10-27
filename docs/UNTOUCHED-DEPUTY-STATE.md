# Untouched-areas deputy: state (rewritten whole; 2026-10-27 evening)

Inputs: docs/review/2026-10-27-untouched-areas/{LEAN,NATIVE}.md, docs/review/2026-10-27-blind-spots/BLIND-SPOTS.md Sweep 1.
Lanes live under /Users/ember/dev/minidregg-lanes/un-<area> on lane/un-<area>; the integrator reads lane/* at its cuts.

## Landed (reviewed against the code)
- lane/un-verify 9f5a7cf4: Generic Simplex gate (harness, log-reopen, 20-op load; three plants red). The load curve gets published only from the cut's dregg-build run.
- lane/un-bend 91f8a83c: `bend publish|run|show|lookup|retry`; jbend 29/0 incl. the step-6 lost-reply shape on the committed branch; lose-reply transport fix (poll until readable, then drop); scripts/author-objective-policy.sh (demo genesis seam handed to infra).
- lane/un-world e279d8ac: Tally, call, send admitted natively (activity route, candidate 203ed84c); dues split; DOMAINS.md: seven domains wait on effect Plans + event Response in the activity kernel.
- lane/un-pb-codec 470f41e7: private-backend R8 (fixtures built and gated, bit-rot fixed, check-boundary.sh deleted, explicit exclude, sha3 pin); rows green on Linux.
- lane/un-assurance e9749a75: census, kernel-subject verdicts, Door 11, gen-storylaw row, StoryHistory with R1 proved.
- lane/un-native-rows 6fae5fa4, lane/un-moves e9d0f2c1, lane/un-pred-census f8677835, lane/un-fixtures a6a32103, lane/un-deputy (this file, EFFECTS.md): as batch 2.

## In flight
- un-pb-exec (R7, P9, KAT), un-pb-wal (R2, P1-P4, protocol_store delete), un-pb-seal (R3, P7, P13).
- un-pred-census: TokenCensus 23 defects. un-moves: four DEAD kernel modules. un-assurance: story law generator into Kernel/StoryLaw.lean.

## Decided
- fn: out of this demo (ember); the exchange row stays UNCONFIGURED by name; sentence published.
- provider-services/Check.lean is JPAY6's (L1). The resource-client dead dep is the L2 successor's.
- private-backend STAYS (ember, E5/q6; the MOVE is cancelled). Source: docs/review/2026-10-26-native-crates/private-backend.md §5, SYNTHESIS §C row 21.
  - Tier 1, NOW (faerie batches): R7 pinned_execution.rs as the one copy (resource-client's transport.rs twin deleted; reader thread; legacy native_worker path deleted) + P12 KAT [lane/un-pb-exec, in flight]; R8 the two Lean codec fixtures as gated lean_exe rows vs check-wire-fixtures/circuit_batch.rs, hbox paths dropped, workspace member or explicit exclude, one sha3 pin [lane/un-pb-codec, in flight]; R2 transition_journal repaired (torn tail refused, interior truncation refused, re-deal test inverted, P4 dzk test gated) and promoted to the anchor's WAL [next]; R3 capsule epoch bound to CurrentRecipientRecord, seeds wrapped at rest, secrets zeroized (P7, P13) [next]; delete the ~2.2K true twins of §5.3 with grep proof [after R2/R7, which touch custody.rs/native_worker.rs].
  - Tier 2, AFTER the opening: R1, the in-process four-party MPC run as a demo door "private computation" (a CLI arm, a derived form, one row, the curious-holder transcript as the page's evidence, labelled research; no transport). R4-R6 (transport, ReleaseAdmission, ACS wiring) stay parked as Phase 3.
- Contracts Cuts/Snapshot/Refinements/Futures: kept (parked, proved, censused).
- Pred BoundedQuantifiedView/CoordinationDial: kept (no live consumer without closure growth).
- four-source fixture: not in the Simplex gate (a four-process mesh); it is second-node work.
- Effects: label repaired; registry is a Phase-3 redesign over the live admission (EFFECTS.md); no toy wire.
- world/dues runs on the activity route (an Activity), split into app + scenario modules.

## Seams named upward
- Demo genesis lacks objectiveInvocation (infra adds the helper to the genesis fill).
- Door 11's sentence (web lane / tour row owner); roomkey.rs:3100 hand-reimplements wrapAtomId (Room lane).

## Next three
1. Review R7/R2/R3 landings; then the private-backend twin deletions (§5.3 of the review), one faerie, after R2/R7.
2. Review TokenCensus fixes, DEAD module deletions, the story-law move.
3. If the coordinator assigns it: the activity kernel's effect Plan + event Response, statement first (DOMAINS.md continuation note).
