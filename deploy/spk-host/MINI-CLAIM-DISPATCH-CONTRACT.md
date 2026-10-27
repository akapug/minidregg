# Mini-to-SPK-host dispatch contract

Present state of `native/spk-host/src/dispatch_{native,delivery,fence,inspection}.rs`.
Lean admits every request; Rust holds the physical fd 3 and the evidence.

## One request

1. Preflight of the projected request (no operation number, no Store write).
2. The physical fd 3 slot (`<journal>/dispatch-active.json`, hostd) must be
   free; it is held only while one delivery is in the app.
3. `dispatch_fence::admit_new_call`: at most 8 undecided calls per generation
   journal (one op 35 lookup of the oldest per new call; settled attempts keep
   markers only, at most 256 retained).
4. A fresh fsynced operation ID, then author (op 36 plan, custodial signatures,
   op 37 assembly) under `dispatch-op-<N>/`. A refused plan or assembly keeps
   its frame and helper stderr as refusal evidence; nothing was submitted.
5. `submit-requested.json` and `submit-active.json` are written (create-new,
   fsynced) before op 34, or op 164 for a route sealed to an admitted binding.
   The same attempt can never be submitted twice.
6. Only Lean's fresh committed permit is inspected (`inspect
   application-dispatch-committed`), matched against the request, recorded
   DeliveryRequested in hostd, and delivered to fd 3 once.

## The fence is per signed call

Lean's exactly-once unit is the signed call (its transaction identity comes
from the call's own operation ID). No generation-wide marker exists: one
undecided call never stops another member. A call is settled only from Lean's
answers:

| Lean's answer | settlement | member sees |
|---|---|---|
| op 164 `DISPATCH-NO-RECORD-REFUSAL` frame | no record | 403 `refused` |
| op 34 outcome `confirmed` (non-winner or historical) | recorded, never delivered | 502 `recorded-undelivered` |
| any other reply or a lost reply, then op 35 `confirmed replayed` | recorded, never delivered | 502 `recorded-undelivered` |
| an answered outcome frame (or 255), then op 35 `absent` | no record | 503 `contention` / 403 `refused` / 503 `unavailable` per the original outcome |
| a lost reply, then op 35 `absent` | undecided | 503 `undecided`, retry `same-call` |
| op 35 unanswerable (Host down, 255, malformed) | undecided | 503 `undecided`, retry `same-call` |
| 8 undecided calls already | nothing authored | 503 `uncertain-backlog`, retry later |

`absent` after a lost reply is not read as never-happened (ruling
2026-10-26): that would rest on the operator socket's ordering
(`resource-client/src/transport.rs`, `ServeBounds`), which no theorem states.
The call stays undecided until Lean's positive no-append frame exists; then
that branch becomes "settled by Lean's NO_RECORD frame". Every outcome body
carries `recorded`, the operation number, Lean's own outcome words and the
retry. The host never resends a call.

## Lookups never authorize

op 35 (`APPLICATION_DISPATCH_LOOKUP`, `Host/Main.lean`
`applicationDispatchLookupSession` over
`Kernel/ApplicationDispatchLookup.lookupVerified`) takes the exact retained
ingress and returns a receipt or `absent`. It can never mint a delivery permit.

## What Lean must still answer

- Which op 34 outcomes are proven no-append, so the Host can answer them with
  the positive NO_RECORD frame and the lookup becomes unnecessary for them.
- A stated independence property: admission of call B depends on call A's
  unknown outcome only through the tip B's plan reads.
