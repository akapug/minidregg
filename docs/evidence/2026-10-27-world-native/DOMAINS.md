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
| call | methods `(View, args)` Activity | `PlanN: call` only; `Returned: returned` (Calls.obend:26-36) | await/call-only: admissible on the call route; needs two objects (not run) |
| send | methods Activity | `PlanS: send`, `PlanN`, `Queued`/`Acked` (Sends.obend:32-51) | send-kernel Plans: admissible on the send route; not run |
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
