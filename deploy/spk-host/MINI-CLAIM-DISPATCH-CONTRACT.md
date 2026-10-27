# Mini-to-SPK-host dispatch contract

The contract between the resident's HTTP dispatch and Mini's Host: which
operations are called, in what order, which durable markers exist before and
after each, and how every Host answer (or lack of one) becomes an HTTP answer.
Lean admits every request; Rust holds the physical fd 3 and the evidence.

Code: `native/spk-host/src/dispatch_delivery.rs` (`deliver_once`, the sequence),
`dispatch_native.rs` (operator transport, authoring, submit), `dispatch_author.rs`
(signing), `dispatch_fence.rs` (per-call fence and settlement),
`dispatch_inspection.rs` and `dispatch_web_input.rs` (projection and
matching). Lean: `Host/Main.lean` (`serveFrame`,
`dispatchApplicationSubmitSession`, `applicationDispatchLookupSession`),
`Kernel/ApplicationDispatchReceiver.lean`, `Kernel/ApplicationDispatchLookup.lean`.
The operation numbers and names are `protocol/host-operations.json` (34
`APPLICATION_DISPATCH_SUBMIT`, 35 `APPLICATION_DISPATCH_LOOKUP`, 36
`APPLICATION_DISPATCH_PLAN`, 37 `APPLICATION_DISPATCH_ASSEMBLE`, 164
`APPLICATION_ROUTE_BOUND_DISPATCH`; response markers 164, 253, 255 in
`response_markers`).

Status: **exists** (unit tests in the files above, including a double-send
qualification fixture behind the `integration-qualification` feature, which the
candidate does not build). Ops 36, 37 and 34 **journeyed** for GET and POST in
J-SPK-1 on the 2026-10-01 binaries, 35.5 to 47.0 s per request
(`docs/evidence/2026-10-01-spk-apps/jspk1/rows.tsv`, rows `s1-get-a`,
`s1-post-a`, `s3-get-b`), and for WebSocket opens in J-SPK-10
(`docs/evidence/2026-10-01-spk-ws/jspk10/rows.tsv`). Op 164 (added 2026-10-02,
`4f0e1e06`), the per-call fence and op 35 settlement (2026-10-26, `f06170dd`)
have no recorded run.

## Who calls whom

The resident (`spk-host resident-bootstrap`, the operator uid) is the only
caller. It talks to the Host through `PrivateOperator`
(`dispatch_native.rs:506-575`): a version-2 envelope carrying the pinned Host
config and the Host image SHA-256, over the operator socket; the reply opcode
must be the requested one, 255, or the pair below. Authoring and inspection
use the same pinned Host image as helper commands (`author`, `inspect`,
`signatures`): Rust never decodes a Mini codec itself
(`dispatch_fence.rs:349-358`). The participant signature is the one thing
produced in Rust, with the route's seed, over header bytes the Host planned
(`dispatch_author.rs:175-252`).

## One request

1. Preflight of the projected request: no operation number, no Store write
   (`dispatch_delivery.rs:91-101`, `dispatch_web_input.rs`).
2. The physical fd 3 slot (`<journal>/dispatch-active.json`, hostd) must be
   free; it is held only while one delivery is in the app. If held, the
   request is answered `mini-spk-admission-v1` status `uncertain`
   (`dispatch_delivery.rs:107-118`).
3. `dispatch_fence::admit_new_call` (`dispatch_fence.rs:558`): one op 35 lookup
   of the oldest undecided call, evidence collection, then refusal if
   `MAX_UNDECIDED` calls remain undecided (`:56`; `MAX_SETTLED`, `:58`, bounds
   retained settled attempts).
4. A fresh fsynced operation ID (`hostd.rs:1067`), then authoring under
   `dispatch-op-<N>/`: `author` request, op 36 plan, `inspect` plan and
   signature check against the pinned signer slots, `signatures`, op 37 assembly
   (`dispatch_native.rs:937-1010`). A refused plan or assembly keeps its frame
   and helper stderr as refusal evidence; nothing was submitted
   (`dispatch_fence.rs:306-330`).
5. `submit-requested.json` and `submit-active.json` are written create-new and
   fsynced before the submit (`dispatch_fence.rs:232-236`,
   `dispatch_native.rs:1110-1130`). The submit is op 34, or op 164 when the
   route carries a continuity binding (`dispatch_native.rs:1157-1163`). The same
   attempt can never be submitted twice.
6. Only Lean's committed permit is used: `inspect application-dispatch-committed`,
   matched against the request and the fixed custody, then DeliveryRequested is
   recorded in hostd and the request is delivered to fd 3 once
   (`dispatch_native.rs:1250-1297`, `dispatch_delivery.rs:144-181`). A
   committed permit that cannot be inspected or matched is never delivered; the
   call settles `recorded-undelivered` (`dispatch_native.rs:1277-1297`).

## The fence is per signed call

Lean's exactly-once unit is the signed call: its transaction identity comes from
the call's own operation ID (`Kernel/ApplicationDispatchReceiver.lean`,
`refusalAtTip?`, the `findIdx?` on `transactionId`). No generation-wide marker
exists: one undecided call never stops another member. A call is settled only
from Lean's answers (`dispatch_fence.rs:1-35`, `decide` at `:429`):

| Lean's answer | settlement | member sees |
|---|---|---|
| the 164-opcode frame `DREGG/APPLICATION/DISPATCH-NO-RECORD-REFUSAL/v1` (`PRIVATE_DISPATCH_NO_RECORD`), in reply to op 34 or 164 | no record | 403 `refused` |
| op 34 outcome `confirmed` (a non-winner or a historical receipt) | recorded, never delivered | 502 `recorded-undelivered` |
| any other reply or a lost reply, then op 35 `confirmed replayed` | recorded, never delivered | 502 `recorded-undelivered` |
| an answered outcome frame (op 34 or 255), then op 35 `absent` | no record | 503 `contention`, 403 `refused` or 503 `unavailable`, per the original outcome |
| a lost reply, then op 35 `absent` | undecided | 503 `undecided`, retry `same-call` |
| op 35 unanswerable (Host down, 255, malformed) | undecided | 503 `undecided`, retry `same-call` |
| 8 undecided calls already | nothing authored | 503 `uncertain-backlog`, retry later |

Status words, HTTP codes, `Retry-After` and the body
(`mini-spk-dispatch-outcome-v1`: `status`, `recorded`, `retry`, `operation`,
`lean`) are `dispatch_fence.rs:70-175`. The host never resends a call.

`absent` after a lost reply is not read as never-happened (ruling
2026-10-26): that would rest on the operator socket's ordering
(`resource-client/src/transport.rs`, `ServeBounds`), which no theorem states.
Such a call stays undecided until Lean's positive no-record frame exists for
it (`dispatch_fence.rs:20-30`, `:498-504`).

## Where Rust and Lean disagree on 253

`Host/Main.lean:2508-2553` answers op 34 and op 164 outcomes that the receiver
decided before any append (`rejected`, `contention`, `unavailable`) under
marker 253 `NO_RECORD`, and `Host/RequestRefusal.lean` (`returnedMarker`,
`exceptionAnswer`) sends a refused op 36/37 answer under 253 too. The resident's
transport knows no 253: `invoke_until` accepts a reply only when its opcode is
the requested one, 255, or the 34/164 no-record pair
(`dispatch_native.rs:569-575`), and 253 appears nowhere in `native/spk-host`.
Such an answer is therefore an opcode-mismatch error on op 34/164, treated as a
lost reply (rows 3 to 6 above, so `undecided` unless op 35 finds the record),
and an error on op 36/37 answered as plain 503 unavailable. Lean's
`NO_RECORD` semantics (`protocol/host-operations.json`, marker 253) are what the
fence's "positive no-record frame" row waits for; reading 253 in
`PrivateOperator` is that change.

## Lookups never authorize

Op 35 (`Host/Main.lean` `applicationDispatchLookupSession`, line 1931, over
`Kernel/ApplicationDispatchLookup.lean` `lookupVerified`) takes the exact
retained ingress and returns a receipt or `absent`
(`dispatch_fence.rs:379-420`). It can never mint a delivery permit
(`historical_lookup_receipt_only`, `Kernel/ApplicationDispatchReceiver.lean`).

## What Lean must still state

- A theorem that admission of call B depends on call A's unknown outcome only
  through the tip B's plan reads. The fence relies on that independence
  (`dispatch_fence.rs:1-9`); neither `Kernel/ApplicationDispatchReceiver.lean` nor
  `Kernel/ApplicationDispatchLookup.lean` states it.
