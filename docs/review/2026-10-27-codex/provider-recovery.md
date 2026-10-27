# Provider attribution and recovery: independent source review

Reviewed commit: `54feb532e05039054640fef04b417e62110e4341` (`main`, 27 October
2026), in `lane/codex-review-provider`. No production code changed. This review
found three actionable defects in the newer durable-ticket composition, plus
two bounded leads below. It does not repeat the old claims that tickets live
only in memory, forwarded bodies escape their grants, or all uncertain/non-200
calls are unsettleable: current source repairs those claims.

## Confirmed findings

### P1 — A broker failure after sending becomes a proven no-send and zero settlement

**Where:** `native/grain-runtime/src/provider.rs:1643–1646`,
`native/mini-keys/src/server/provider.rs:515–520`,
`native/grain-runtime/src/main.rs:9711–9720,9016–9023`.

**Reachable trigger:** a valid ticket is forwarded; the provider completes and
may charge; the broker's `put_answer` or final `put` fails (disk full, I/O error,
or directory fsync failure). These calls happen *after* `send` returns and turn
into the ordinary `ticket-journal` refusal. The broker sends that refusal over
the still-live client socket. The gateway treats **every** `client::answer`
error as `ProviderOutcome::refused`, on the obsolete assumption that “the broker
refuses only before it sends.” That constructs `NotSent`, not `Uncertain`.

The same API now returns `forward-uncertain` for durable Sending/Uncertain
records (`mini-keys/src/server/provider.rs:468–470`) and for an Answered record
whose retained answer is missing (`:463`). Such refusals also contradict the
assumption, although this review did not establish a normal Hermes retry that
presents one of those old tickets.

**Consequence:** the controller records `not-sent:refused:…`, returns charge
`Some("0")`, and after the gateway acknowledges the record calls
`provider_settle("0")`. A possibly billed call loses its external uncertainty
and releases the Mini hold at zero. This does **not** bypass the broker's own
pool-spend ceiling; it breaks the provider-purse settlement boundary. No
automatic second provider send is claimed here.

**Concrete fix:** make physical send knowledge explicit in the broker result:
`proven-not-sent`, `possibly-sent`, or a retained completed answer, bound to the
exact ticket/body. Map only proven pre-send failures to NotSent. Unknown,
malformed and `ticket-journal` failures must remain uncertain unless the broker
can supply the stronger evidence. Do not merely whitelist `ticket-journal` as
pre-send: the same code occurs on both sides of the send. Add a post-send
answer-publication fault test through gateway outcome recording and assert no
zero settle and no resend.

**Evidence here:** the isolated program seeds an Uncertain broker ticket, calls
the actual public forward handler, gets `forward-uncertain`, and feeds the exact
tag emitted by the gateway/controller mapping into the real
`provider_failure.rs` module. It produces `ReleasedNotSent`. The mapping and
zero-settle connection above were read in source. No disk-full provider call,
full controller process or native settlement was executed.

### P2 — Concurrent exact authorize retries mint two independently spendable tickets

**Where:** `native/mini-keys/src/server/provider.rs:150–166,169–224`;
`native/mini-keys/src/server/ticket.rs:188–190,276–284`.

**Reachable trigger:** two provider-role connections with identical authorize
parameters overlap before either ticket is minted. Both `find_request` calls
return none; each chooses a random ID. `pool_grant` serializes each individual
quota update under the provider authority lock, but it never rechecks the
request identity after acquiring that lock. Both calls therefore mint and
count. The enclosing broker serves requests on separate threads
(`server/mod.rs:509–551`); its provider class permits eight connections. The
single-controller gateway usually serializes its own calls, so this is a broker
retry/concurrent-client defect, not proof that one room message currently
starts two Hermes turns.

**Consequence:** the promised idempotent authorize retry is charged twice and
returns two Counted tickets, each eligible for a separate forward. Quota may be
exhausted without two intended calls. `MAX_LIVE_PER_PEER` is checked outside the
same atomic region and can also be exceeded by overlapping requests. The
provider-wide spend and usage locks still enforce their monetary limits; this
is not a claim those counters race past their ceilings.

**Concrete fix:** serialize lookup, live-bound check, ticket creation and final
Counted publication as one operation, using the same ticket-state lock/order as
forward. A per-request reservation/index can avoid holding one global lock
while a user grant observes the Host. Define one lock ordering with the provider
credential lock; do not add an opposite nesting order. Preserve recovery
of Minted records without allowing a concurrent authorize to overwrite a
Sending/Answered transition. Test simultaneous exact retries return one ID and
consume one quota/spend reservation, including restart and count-publication
failure boundaries.

**Evidence here:** two actual authorize handlers were held behind the same
provider authority lock, then released. They returned distinct tickets and
charged member 22 **10000 µUSD**, twice the configured **5000 µUSD** call
reservation. Both reproduction runs observed this. No forward or provider call
was needed. The 300 ms overlap aid is a local scheduling aid, not a formal
scheduler proof or a timing bound.

### P2 — Answer retention is only swept on startup, so steady service grows without bound

**Where:** `native/mini-keys/src/server/ticket.rs:34–36,185,263–284,287–312`;
`native/mini-keys/src/server/provider.rs:461–466`.

**Reachable trigger:** leave the broker running while normal provider calls
complete. `Tickets::sweep()` has one production caller, `Tickets::open()` at
startup; neither the serve loop nor authorization/forward sweeps. Answers
therefore remain past the documented 3600-second retention. `forward_ticket`
returns Answered bytes before checking any expiry/retention condition. Each
later `find_request`/`live_for` scans and parses every ticket JSON, including
old terminal records.

**Consequence:** plaintext reply retention and ticket count increase throughout
a long-lived broker run. Disk use is not bounded by one hour's traffic, and
normal authorization work grows with total historical calls. An individual
answer is bounded, and this is not evidence of immediate OOM. Sending records
are intentionally retained for uncertainty and need a separate tombstone
policy; deleting them must not authorize another send.

**Concrete fix:** run a bounded periodic/incremental sweep under a defined
interaction with ticket writes/in-flight state; enforce terminal retention on
lookup too. Keep a compact non-resend record where needed instead of retaining
reply plaintext forever. Index current request identities rather than scanning
all historical JSON for every authorization. Test a running instance advances
past retention without restart, removes the bytes, refuses/reports expiry
without forwarding, and never sweeps an active send.

**Evidence here:** an Answered record with `settled = now − 3601` survived an
ordinary authorization and its actual forward handler still replayed the
synthetic answer. Calling the existing explicit `sweep()` then removed it. No
wall-clock wait or external service was used.

## Two leads with limited end-to-end reachability

- **Member attribution is absent from the retry identity.** The gateway sends
  `prompt_member` as `member` (`grain-runtime/src/main.rs:9362–9366`), but
  `ticket::request_key` contains uid/kind/provider/runner/owner/body digest and
  no member (`ticket.rs:153–156`); Ticket itself stores no pool member. Changing
  only `member` from 20 to 21 while an identical Counted ticket exists returns
  that ticket *before* member-21 quota validation (`provider.rs:155–159`). The
  local reproduction charged 20=5000 and 21=0. Bind member and the full intended
  authorization scope to the retry key and persisted ticket. **Limit:** normal
  resident prompts include their selected request/author in the prompt body,
  and controllers serialize their own turns. I did not construct two genuine
  different-author resident invocations with identical complete model bytes.
  This is a reproduced broker API attribution collision, not an established
  stranger-to-stranger budget theft through the normal room route.

- **The broker's recoverable answer has no durable controller handle.**
  `ProviderRouteRecord` (`grain-runtime/src/main.rs:343–351`) and
  `ProviderAttempt` (`:1258–1303`) persist provider/endpoint/credential and exact
  request hashes but no broker ticket. `provider_route` keeps it only in the
  transient Route (`:9355–9399`). A crash after the broker commits Answered and
  before the gateway/controller retains the reply therefore loses the handle.
  Startup records CrashAfterSend (`:16062–16076`); recovery
  (`provider_recovery.rs:67–131`, main `:16542–16635`) does not query the broker.
  Authorizing the same bytes again cannot recover an Answered ticket:
  `find_request` considers only live Minted/Counted records, and the repro
  observed a new ticket/count. Add the ticket to the attempt before send and a
  **read-only** broker lookup; never use an effectful forward or new authorize
  as a substitute for lookup. **Limit:** the current pessimistic hold charge
  on unresolved after-send work is deliberate (`Kernel/ProviderMetering.lean:322,
  331`), not a safety violation. This is a concrete recovery/cost improvement;
  I did not run a controller-kill/native restart acceptance test.

## What the real source path does, and what was covered

| Boundary | Actual path inspected | Review result |
| --- | --- | --- |
| Request attribution | signed room/tool discovery in `hermes_room.rs:523–555`; resident assignment serialization `room_resident.rs:71–86,130–151`; `resident_prompt_member`, main `:2513–2517,14649`; provider request main `:9362–9366` | Source identity is projected by trusted controller code; request fields alone do not grant an outsider broker access. Reproduced the narrower broker retry-key omission above. Did not rerun the full resident preparation/admission proof. |
| Credential/budget selection | main `:9334–9403`; mini-keys `server/mod.rs:600–658`; authorize `provider.rs:115–224`; `credentials/store.rs:557–604,667–720` | OS peer role gates the broker; user epoch is observed; body caps are checked on forward. Provider lock and usage lock protect counter updates. Retry identity is not atomic with those updates. |
| Physical invocation/cancellation | gateway `provider.rs:1578–1710`; broker `provider.rs:255–386,437–525`; bridge delivery acknowledgement gateway `:1203–1234` | Exact body/ticket and durable Sending precede provider I/O. Broker cancellation preserves uncertainty. Gateway's blanket refusal mapping discards that knowledge (P1). No live curl/HTTP test executed. |
| Durable result and settlement | broker `ticket.rs:197–258`; controller main `:9682–9810,10377–10540,16542–16680`; `provider_recovery.rs`; `provider_history.rs` source anchors; `Host/ProviderUsage.lean:266–322`; `Kernel/ProviderMetering.lean:315–331` | Complete replies use source-owned quotes; no-send zero settle and after-send pessimistic hold are separate intended paths. P1 crosses them incorrectly. Exact result/settlement history is retained; broker ticket identity is not. |
| Native/client consumers | `native/mini-keys/src/client.rs:115–149`, `wire.rs:55–115`; `native/resource-client/src/meter.rs:162–212` request/quote framing; `Host/ProviderUsage.lean`; `Kernel/ProviderRoute.lean` | Frame completion distinguishes a partial broker request from a completed send; provider usage is an assertion from retained bytes, not an invoice proof. This review does not claim the Lean theorem proves Rust effect classification. |

Known/active work was checked in `docs/review/2026-10-27-redteam/REDTEAM.md` and
the 26 October `grain-runtime--B-provider-credentials-custody.md` /
`verifier-keys-testprovider.md` reports, then compared against actual current
source. Their old ticket/body-cap/global-slot/audit descriptions are historical,
not new findings here. Oracle and lifetime-grant repairs were not touched.

## Reproduction and handoff

`provider-recovery-repro/` is an isolated Cargo package using the current
mini-keys library and the actual provider-failure classifier source. From the
repository root:

```sh
mkdir -p /ABS/OWN-SCRATCH
CARGO_TARGET_DIR=/ABS/OWN-TARGET cargo run --offline \
  --manifest-path docs/review/2026-10-27-codex/provider-recovery-repro/Cargo.toml \
  -- /ABS/OWN-SCRATCH
```

On this Mac, the final run exited **0**, all assertions passed, and emitted
`provider_calls:0`, `servers_started:0`. It uses synthetic sealed credentials,
direct Rust handlers and one unserved Unix listener; no provider network, Host
process, running broker service or real credential was used. Initial build
16.10 s; adding the real classifier dependency compiled the coherent final
reproduction in 18.58 s. These are reproduction times, not product benchmarks.
The output is retained in `provider-recovery-repro/observed.json` with the local
scratch path elided. No production patch, closure build or deployment is claimed.

**BATCH FOR THE PARENT:** validate/fix P1 with a gateway/broker post-send journal
fault test and native zero/held-settle assertion; integrate authorization
idempotency and running-broker retention repairs under their current owner;
then decide whether to connect read-only ticket recovery. The two limited leads
need full controller/resident evidence before claiming normal end-user exploits.
