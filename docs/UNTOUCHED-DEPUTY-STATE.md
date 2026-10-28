# Untouched-areas deputy: state (rewritten whole; 2026-10-27 night)

Inputs: docs/review/2026-10-27-untouched-areas/{LEAN,NATIVE}.md, docs/review/2026-10-27-blind-spots/BLIND-SPOTS.md Sweep 1.
Each lane: /Users/ember/dev/minidregg-lanes/un-<area> on lane/un-<area>.

## Rules in force (ember; COORDINATION §4 on main)
- Lanes may build, elaborate and run rows again, but ONLY in a warm, incremental tree on dregg-ref or hbox: never the Mac, never a cold build, never a hard-linked build/ dir (seed only .lake/packages). Stop only your own processes, by PID file (or the harness task that started them).
- The integrator fixes the reds it finds in main's build itself; only reds needing a design decision come back to the deputy.
- No Lean on the Mac, ever. Each faerie works only in its own worktree. Never search the filesystem from / or ~ (a whole-disk find overflowed the Mac's file table).
- Statements go directly to the statements auditor (af7a93e7b8ba729d4), copying the deputy.
- Integration is continuous (no cuts). Re-genesis is free (flag days are not held).
- Never kill by pattern; no PID file: tell the coordinator.

## Landed earlier (on main)
un-verify (Generic Simplex gate), un-bend (bend verb + lost reply), un-world (Tally/call/send native; DOMAINS.md), un-assurance (census, Door 11, StoryHistory, Kernel/StoryLaw), un-native-rows, un-moves, un-fixtures, un-seats, un-pb-codec (R8), un-pb-exec (R7/P9), un-pb-seal (R3 whole), un-pb-wal (R2 + all five two-step dealers, 68d9f28e).

## Pushed, waiting on the central build (reasoned; built only by the integrator so far)
- un-effects 2acd8acf (fix 2b9de248 "ready" told; five more world scenarios bounty/play/ballot/story/commons 2d4ff2bd..2acd8acf, unrun). The effect Plan: keystone proved 5e116ec9 (on main). Pass-11 additions (FundsAgree, DepositIndependent, BirthCommitJudged, DeliverLawRefuses + two poles; commitYield_spec restated) at 2aaf5ec9. Kernel fix: deliver refuses payerInvalid when the submitter or the collector is the purse (Delivery.purseApart); payerInvalid docstring names it. 2b9de248 adds the missing opens (addCapacity; applyOperations/registerAccounts/deregisterAccounts/_accounts) and drops a no-progress dsimp. World apps (dues, bounty Board, play, ballot, story, commons) on the kernel protocol, e6c7ed42; native scenarios dues/effect + purse-as-submitter/law-refused rows 0fa0eb98. OWED to the central build: codec pins re-emit (scripts/codec-shapes-regen.py, ACTIVITY-RECORD v9), cohort gate (renamed rows: ballot 1, story 1, commons 2), native rows on a main candidate, README native lines; scenarios for bounty/play/ballot/story/commons not yet written. Continuation: docs/evidence/2026-10-27-world-native/EFFECTS-STATE.md. Its faerie is retired (~536k); the deputy owns the remainder.
- un-pred-census 44479e30 (the integrator takes it for the cut-14 ReceivingVerifier red): Vouchers conversion = the whole sweep (every receiver is a Kernel.Receiving.Family through Family.receiver, now fixed to receiverVerifier with Answered = Ran). Ran private, one mint; live_voucher_has_ran (CredentialSignatureAdmission.lean:391); gate rows receiver-verifier (text) and ran-mint (term-level, needs AxiomCensusResearch built). L1's three receivers got forced edits only (PayEnrolReceiver 1182,1192,1195,1596-1601; V2 818-823,843,847; SubjectKeyRotation 427-428); L1 merges before editing them. Faerie retired (~299k).
- un-stream-continuity 0d95b3e1 on main via cut 14; its 14 statement-file reds are the integrator's (faerie's 6544ea37 offered as a start; a pole statement change comes to the deputy and auditor). Was: hot-route op154 refusal fixed at the cause (Appended.headTagExact; exactCandidate carries the tag; withOpenedFreshTip through verdict with Head.verify; distinct refusals). Statement accepted (e0916a53). Gate: japps co-edit row; then L13 reruns DDP. Faerie (a4e312352a7091f59, ~220k) fixes forward routed reds.
- un-pb-twins 134535c2: §5.3 deletions (reconstruction, two_bit_addition, source_endpoint outcome side, PROGRESS v1, dealer_start, binding v1, sequential Engine + store, circuit_batch items, reserve_material, custody Pool/Cut + CLI arms + crash-probes.py); AnchorFixture replaced by the real serve(listener, stop) (blocking accept, wake connect); P6 receipt verifier rebuilt on the anchor with its test (extends case shown); LayerEngine non-Boolean test. Faerie (a1d3a428143ff3b8e, ~294k) retired.

- un-effects-rows 4dc6225d3 (sha sent to the integrator): effect/bounty/play/ballot/story rows green natively on 0ce31391 (owner budget 1000000 for 104-150 KB publishes; laws read state/NAME; ballot SealedVote rename). commons red at publish (308,499 > SOURCE_BYTES 262,144): ruled split app + scenarios as dues, policy bound kept. Faerie ade649a1df3da1347 splitting it and running the cohort gates on dregg-build (bun at /build/tools/bun/node_modules/.bin/bun; dregg-ref has none), then README native lines.

## Owed / unowned
- ember's ruling (memory "no hand-written kernel effects"): kernel effects must come from a revived Effects/ derivation engine. un-effects' transfer/commit are hand-written in Kernel/ObjectiveActivity.lean: deferrable for the demo, owed after (EFFECTS.md has the Phase-3 design: EffectSpec widened with refusal, authority demand and frame; the dispatch keystone; the hand arm deleted in the same commit).
- private-backend helper-copy merges (Lagrange, Horner, PRG/urandom into Entropy, Nat cursors into one Cursor::nat, outbox codecs into one Outbox): in flight on lane/un-pb-helpers (Sonnet ad546f4c4b4fe0ede, from main 92ec75c3). One commit per family; outputs and wire bytes pinned by a test before each merge; non-twins kept and named; warm builds on dregg-build in /build/lanes/un-pb-helpers with the un-pb-seal-target. Shas go to the integrator as they land.
- private-backend P6 (lost reply on reserve/burn): open; the verifier exists.
- Tier 2 (after the opening): R1 the in-process MPC as a door. The sibling product deputy (a5a600787670d2be5) now owns the MPC demo door, invite codes, Host request rate, web3.js serializer, grain class slices: not ours.

## Web item (done)
- un-web-front 0da04999: the public front page renders the operator's published document. mini-web-spawn reads /etc/mini/front-doc and passes --front-doc to the public body only; it falls back to the index. Infra writes `welcome` there (demo-vm 3b8e729, run-sheet step 9c); its check line: an anonymous GET / renders welcome. Sha sent to the integrator.

## Decided
fn out; private-backend stays; Effects/ registry is Phase 3 (EFFECTS.md); dues and six more ride the effect Plan; DreggNet lease cluster parked; Contracts Cuts/Snapshot/Refinements/Futures kept; Pred BoundedQuantifiedView/CoordinationDial kept; twin conflict on un-pb-twins resolved to un-pb-wal 68d9f28e's design (82f3710b).

## Next three
1. Read the central build's verdict on un-effects 2b9de248; fix routed reds by reasoning; get the codec pins re-emitted; write the remaining world scenarios (bounty, play, ballot, story, commons) in world-activity-admit.py and README native lines.
2. Route any central reds on un-stream-continuity / un-pred-census / un-pb-twins to their faeries; tell the coordinator when the japps co-edit row is green.
3. Review each un-pb-helpers landing (pinning test green on the box, bytes identical); send the shas to the integrator.
