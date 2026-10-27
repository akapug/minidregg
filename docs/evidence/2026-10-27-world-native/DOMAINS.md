# world/ domains against the activity kernel (candidate-independent, source reading, 2026-10-27)

The activity kernel (`Kernel/ObjectiveActivity.lean`) admits a published entry that (1) takes ONE input
value (`instantiate`, else `inputType`), (2) returns `Activity<P,R,A>` whose response type has a `reply` row
and is `resumed {outcome, view}` typed for every kernel outcome (`loadProgram`, `outcomeProtocol`), and
(3) yields only `await` Plans (`decodePlan`: "the kernel performs only `await` Plans"); the call and send
kernels add `call` / `send` Plans (Kernel/ObjectiveCall, ObjectiveSend). Evidence for the gap: dues, run
on the Host, `dues-activity-route/`.

| domain | entry shape | Plan / Response (file:line) | route now |
|---|---|---|---|
| activity | `tally(Start)` Activity | `sum Plan: await` only; `Resumed: resumed{outcome,view}` (Tally.obend, `sum Plan`, `sum Resumed`) | **admitted** (203ed84c, `tally-activity-route/`) |
| call | methods `(View, args)` Activity | `PlanN: call` only; `Returned: returned` (Calls.obend:26-36) | **admitted** on the call route (203ed84c, `call/`) |
| send | methods Activity | `PlanS: send`, `PlanN`, `Queued`/`Acked` (Sends.obend:32-51) | **admitted** on the send route (203ed84c, `send/`) |
| ballot | `serve(Poll)` Activity | `Plan: await \| publish` (SealedBallot.obend:211); `Response: event\|settled\|refused` (:215) | gap: `publish` Plan, event Response |
| bounty (Board) | `serve(State)` | `Plan: await \| disburse` (BountyBoard.obend:231); `Response: event...` (:235) | gap: `disburse`, event |
| bounty (Escrow) | pure `Plan` list for the seat kernel | `Plan: nil\|cons Action` (BountyEscrow.obend) | seat-kernel route (README: executed natively there) |
| commons | `serve(State)` | `Plan: await \| admit` (ResidentServiceCommons.obend:684); `Response: admitted\|refused\|event` (:722) | gap: `admit`, event |
| drex | `batch(Market)` | `Plan: nil\|cons Action` (DrexBatch.obend:159); `Response: tick\|settled\|refused` (:246) | gap: action list Plan, tick Response |
| dues | `dues(Terms, Nat)` | `Plan: await \| pay` (StandingDues.obend, `sum Plan`); `Response: event\|settled\|refused` | gap: `pay`, event; also two-argument entry |
| play | `serve(Game)` | `Plan: await \| disburse` (CommitReveal.obend:242); `Response: event...` (:246) | gap: `disburse`, event |
| story | `serve(Story)` | `Plan: await \| publish` (CoAuthor.obend:308); `Response: event...` (:312) | gap: `publish`, event |
| seats | `Broker` returns `Plan` | `Plan: nil\|cons Action` (Broker.obend:94) | seat-kernel route, not the activity kernel |
| automatafl | pure transition | no Activity | Route A (objective-invoke) or none; README: no native claim |
| collective | pure functions | no Activity | Route A candidates |
| market | pure settlement math (7 modules) | no Activity | Route A candidates |
| station | pure functions | no Activity | Route A candidates |
| workshop | pure functions (5 modules) | no Activity | Route A candidates |

Only `world/activity` (Tally, TallyV2) is await-only with one input and a `resumed{outcome,view}`
response today. Every preview-first app (ballot, bounty Board, commons, dues, play, story) writes its Plans as
effects in its own vocabulary (`pay`, `disburse`, `publish`, `admit`) and its Response as `event`; they are
one gap: the activity kernel has no effect Plan and no event response. Pure-function domains have no
Activity and take the Route A entry contract (`world/NativeReceipt.obend`), which a hostInput adapter would
make them fit; none was attempted.

## Continuation note
- Admitted natively on candidate 203ed84c, each with state read back, one law and one named refusal: activity
  (Tally), call (Calls), send (Sends); driver `native/resource-client/world-activity-admit.py`, runner
  `scripts/world-native-admit.sh DOMAIN --route activity --scenario tally|call|send`.
- Waiting on ONE kernel feature: ballot, bounty Board, commons, drex, dues, play, story (effect Plans `pay`,
  `disburse`, `publish`, `admit`, an action list; `event` / `tick` Responses). Dues is the probe: birth refused
  `inputType` then `outcomeProtocol "reply"` (`dues-activity-route/`).
- Files the feature touches: `decodePlan` in Kernel/ObjectiveActivity.lean (today only `await`, "the kernel
  performs only `await` Plans"), `outcomeProtocol` (the response must be `resumed {outcome, view}` typed for every
  kernel outcome), `loadProgram`/`replyType` (the `reply` row), plus the receiver wire
  (Kernel/ObjectiveActivityReceiverCore.lean, Refusal encoding) and Host/ObjectiveInvocationQuote only if a new
  Plan changes the quote.
- Also owed per app: a single-input entry (dues needs `Opening{terms, deposit}`), and heights from the kernel,
  not caller-supplied `now` fields.
- Pure-function domains (automatafl, collective, market, station, workshop) are Route A (objective-invoke) and
  need a hostInput adapter; none attempted.

## The effect Plan: statement first (deputy, 2026-10-27; written before any Lean)

**Design.** The seven domains' Plans are effect requests performed now (`pay`, `disburse`, `publish`,
`admit`), answered `settled` or `refused`, beside `await`. The activity kernel keeps its two load-bearing
contracts unchanged: ONE extraction per segment (`runSegment`, `single_extraction_reservation_budget`) and
every kernel outcome typed at birth (`outcomeProtocol`). So an effect is not performed inside a segment:
an effect Plan is a YIELD whose await is decided by the kernel at the yield. `decodePlan` widens to
`await | transfer {to, amount, write} | commit {write}`, each decoded to a `PlanAwait` whose source is a new
`PlanSource.performed (effect)`. `commitYield` judges the effect in the same batch: a `transfer` posts
`amount` from the activity's purse to account `to` when the purse still reserves the await's fee pair and
its storage after it and `to` is an open account other than the purse, the collector and the issuer well;
`commit` applies `write` through the object's law exactly as `await.write` does (`stateWrite`). The await is
recorded already decided: outcome `settled` (a new `AwaitOutcome`) when performed, `refused` otherwise,
with nothing posted and nothing written. The next `deliver` turn (any subject; no decider, no due height)
resumes the activity with `resumed {outcome, view}`, so every unfolding past a yield still costs one
admitted turn. `settled` is not added to `kernelOutcomes` (Tally and every existing program stay valid);
an effect yield instead requires the outcome type to type `settled` and `refused`, or the Plan is refused
(`Refusal.plan "effect outcomes"`). `publish` and `admit` are `commit` (a declared-state write);
`pay` and `disburse` are `transfer`. Not in this change: drex's action list (a batch of effects) and
Route A's pure domains. No new registry operation, no new Store kind: the transfer is a posting in the
activity turn's existing batch; the record gains one await-source tag (a persisted-byte change carried by
the codec identity gate, a re-emit commit, not a kind).

**Keystone (the Prop, before proof).** For a birth or delivery whose segment yields `transfer {to, amount, write}`:
1. *Performed.* If `purse(before) ≥ amount + reserve(record)` and `to` is admissible, the committed batch
   moves exactly `amount` of the credit asset from the purse to `to`, the object's state is
   `stateWrite … write`, the record's await is decided `settled`, and the Book's total of every asset is
   unchanged (conservation, as `Batch.apply` already proves for the activity's postings).
2. *Refused (teeth).* If either premise fails, the batch posts nothing from the purse to `to`, the object
   state is unchanged, and the await is decided `refused` by name (the reason recorded); a delivery then
   resumes with outcome `refused`.
3. *Resumed.* A delivery of a performed await resumes the segment with exactly
   `responseData (.settled | .refused) view` and needs no decider.

**Poles.**
- *Satisfiable:* a Tally-shaped program (world/activity) whose step yields `commit {write: total add n}` then
  `transfer {to: payer, amount: 1}` is born with a deposit covering both, both effects are performed, and its
  responses decode as `settled`. Witnessed natively on the activity route by `world-native-admit.sh`, and
  in Lean by a decided example over the kernel's own `commitYield`.
- *Teeth:* the same program with `amount` one above `purse − reserve` is refused by name; the purse, the
  recipient and the state are byte-identical before and after (decided example plus the native row).
  A second tooth: `to` = the purse itself is refused.
- *Premise inhabitation:* `∃` a purse balance, reserve and amount with `purse ≥ amount + reserve`
  (the birth deposit of the satisfiable pole), and an open account other than purse/collector/well
  (the payer's own account).

**Proof that it is used.** dues first, then bounty Board and play (`transfer`), ballot, story and commons
(`commit`): each domain re-expressed in the kernel's response shape (`resumed {outcome: reply Event |
settled | refused | unknown | timedOut | broken | upgraded, view}`, one input value), its preview cohort
still green, and admitted natively through `world-native-admit.sh DOMAIN --route activity` with one law
asserted as the Host's decided outcome and one refusal by name.
