# resource-client shard C: money (pay, join, credit, market, agent reserve, jobs, clock)

| | |
|---|---|
| Shard | resource-client shard C, "money: pay, join, credit, market, agent reserve, jobs, clock" |
| Crate | `native/resource-client` (binary `mini`, `native/resource-client/Cargo.toml:9-11`) |
| Date | 2026-10-26 |
| Reader | Opus reader, fan-out review (read-only; no build or test run) |
| Total lines | 17,121 (21 files; ~13,380 code, ~3,740 in `#[cfg(test)]` regions) |

Files covered (all under `native/resource-client/src/`, every one read in full):

| file | lines | | file | lines |
|---|---:|---|---|---:|
| `pay.rs` | 2,560 | | `credit.rs` | 1,083 |
| `pay_claim.rs` | 1,798 | | `market.rs` | 629 |
| `pay_memo_v2.rs` | 1,164 | | `meter.rs` | 253 |
| `pay_status.rs` | 773 | | `agent_payer.rs` | 242 |
| `pay_refill.rs` | 155 | | `agent_reserve.rs` | 803 |
| `join_solana.rs` | 1,278 | | `agent_reserve/lifetime_v3.rs` | 526 |
| `join_solana_v2.rs` | 1,445 | | `agent_reserve/lifetime_v3/paid.rs` | 852 |
| `paid_context.rs` | 788 | | `agent_lifetime_grant.rs` | 592 |
| `paid_onboarding.rs` | 218 | | `job.rs` | 1,123 |
| `well.rs` | 256 | | `clock.rs` | 401 |
| `checkpoint.rs` | 182 | | | |

Context read: `PAID-COLD-ENTRY.md`, `jpay-claim-law.sh/.jq`, `jpay-claim-law-tests.sh` (head),
`journey.d/job-refund-recovery.py`, `paid-entry-adapter.py` (structure), `native/pay-watcher/README.md`,
`deploy/pay/enrol-terms.json`, `deploy/pay/README.md` (lines 25-45), `deploy/pay/mini-pay-watcher` (grep),
`deploy/clock/*`, `deploy/checkpoint/*`, `deploy/shell/templates/job/law.job.shell`, the Lean receivers named
below, `protocol/host-operations.json`, `protocol/HOST-OPERATIONS.md`, README.md "Honest state".

## Executive summary (15 lines)

1. Rust in this shard almost never computes a price, a balance or a verdict that gets trusted: every money turn is
   authored by the Host (`author`, op 7), planned by a Lean receiver, signed over a Host-printed header, and admitted by Lean.
2. The exceptions are real but narrow: the sealed-market allocation (`market.rs:271-286`) is computed in Rust and Lean only
   bounds each fill; the room-week membership-for-payment decision lives in the Rust concierge (`grain-runtime/src/concierge.rs`)
   for which `credit.rs` is the client; the clock's `now` is a Rust wall-clock oracle (`clock.rs:151-156`) that Lean only bounds.
3. The payment oracle itself is the pay-watcher (another crate): Lean never verifies a Solana transaction; it trusts the observer's
   signed report and checks only mint/program/address/assignment/amount/nullifier (`Kernel/PayObservation.lean:198-211`).
4. One transfer cannot be credited twice: the nullifier is `"soltx:" ‖ signature ‖ address` (`Kernel/PayObservation.lean:162-167`),
   the same bytes as the v2 claim id that `pay_status.rs:492-497` checks.
5. README "Payments" row (README.md:94) is stale: the tariff is v4 with `nodeWeekRate` stored, not derived
   (`Kernel/PayTariff.lean:30-35`); `enrol-terms.json:8` sets 50,000,000 atomic = exactly 50 DREGG; Rust copies the quote verbatim
   (`join_solana.rs:636`, `pay_memo_v2.rs:521`). No Rust code computes the week price.
6. `join_solana.rs` (v1, 400-byte memo) and `join_solana_v2.rs` (v2, 485-byte memo) are both live, selected by
   `--memo-version v2` at `main.rs:3198-3200`; they are distinct protocols with distinct Lean receivers, not byte twins, but v1 should go.
7. Dead code: the stale-root retry branches of `pay address`/`pay book` (`pay.rs:685-694`, `821-830`) can never fire, because op 105
   is a blind submission whose refusals are all `undisclosed` (`Host/Main.lean:6923-6930`, `Kernel/NativeHost.lean:3142-3145`).
8. Lost-reply hazards that CAN become a second operation: `mini well mint|burn|floor` (no lookup op exists; uncertain is reported as
   "refused", `well.rs:168-175` vs `Host/Main.lean:7055-7063`) and `mini credit pay|topup|refund` after a process crash (no
   operation record, fresh nonce on rerun, `credit.rs:779`, `813`, `975`). Lean does not dedupe these (fresh nonces).
9. Real bug: `agent-lifetime-paid-lookup` after a successful `agent-lifetime-paid-submit` always fails, because submit retains a
   4-field receipt (`paid.rs:645-647`) and lookup compares it with a 5-field one carrying `reserveIndex` (`paid.rs:710-717`,
   `agent_reserve.rs:133-136`).
10. Twins: `lifetime_v3/paid.rs` seal/submit/lookup (ops 79/76/77) duplicates `native/spk-host/src/agent_api_lifetime_paid_native_v3.rs:147,183`
   and `agent_api_lifetime_dispatch_native_v3.rs:167`; the live caller is spk-host. Three copies of one plan/seal/submit/lookup custody
   state machine (`agent_reserve.rs`, `lifetime_v3.rs`, `agent_lifetime_grant.rs`); the Lean creditFor formula re-typed in `pay.rs:1859-1875`.
11. Jobs: refunds cannot double (the job law closes a job once, `law.job.shell:18,46-48`) and a lost settle reply is recovered by
   exact lookup then same-bytes resubmit (`job.rs:487-498`); `fund`/`claim` lack recovery but Lean refuses a second fund/claim.
12. Clock: a tick is a Lean-admitted transition (ops 126-128) under the clock subject's `C_tick`; Lean enforces monotone and a
   per-tick step bound only, so a holder of the clock key can fast-forward time without limit (catch-up loop `clock.rs:372-390`).
13. Wiring: pay/join/pay-claim/credit/clock/checkpoint/job/well/market/meter/agent_* all reach a `mini` subcommand; market via
   `workspace.rs:7038-7076`; meter and agent_* via grain-runtime; journeys JPAY1-4, JPAYE1-3, JPAY6, JJOB*, KC, KW, JMKT run in `journey.sh`.
14. Not in the journey runner: `jpay-v2.sh`, `jpay-e4.sh`, `job-refund-recovery.py`, `jpay-bootstrap-budget.py`; nothing in this shard
   is deployed (README.md:94; FRIENDS.md "paying to enrol ... no").
15. A no-payments demo can drop ~15.2K of these 17.1K lines; a pay-to-enrol-v2 demo can still drop ~3-4K (estimates, section 6).

---

## 1. What this code is and does

### 1.0 Shared shape of every money verb in this shard

Almost every module here is the same four-step client against a Lean receiver family, retaining every byte:

1. **author**: either a local Host subprocess (`HOST CONFIG author KIND IN OUT`, e.g. `pay.rs:448-454`,
   `agent_reserve.rs:239-248`) or Host op 7 over the socket with a `u16le kind-length ‖ kind ‖ JSON` payload
   (`job.rs:91-100`, `clock.rs:98-108`, `checkpoint.rs:74-84`, `pay_refill.rs:30-36`);
2. **plan**: a Host op returns a signing plan; Rust inspects it through the Host (`inspect`, local subprocess or op 8),
   checks that the plan names the command it authored, and signs the plan's `header.canonical` bytes with an Ed25519 seed
   (`pay.rs:461-471`, `job.rs:356-358`, `clock.rs:284-291`);
3. **assemble**: `u32le len(plan) ‖ plan ‖ signature(s)` to the assemble op (`pay.rs:473-477`, `pay_refill.rs:43-52`);
4. **submit once, then lookup only**: a durable submit marker is written before the frame leaves; a lost reply is resolved by a
   receipt-only lookup op on the exact retained ingress (`pay.rs:486-499`, `518-526`; `agent_reserve.rs:587-660`).

Frame convention (all modules): reply byte 0 equals the request op on success; 255 is the Host refusal/outcome envelope;
254 is a transport refusal (`protocol/host-operations.json` `response_markers`). Modules differ in whether they accept 254
(`job.rs:83`, `clock.rs:86`, `checkpoint.rs:62` do; `pay.rs:213-222`, `well.rs:78-85` do not name it and fall into
"invalid frame").

### 1.1 `pay.rs` (2,560 lines): the PAY P4 client (`mini pay`)

Entry: `pay::run` (`pay.rs:2236-2346`), reached from `main.rs:3267` (`"pay" => pay::run(args)`). Actions:
`address | status | book | watch-config | observe | heartbeat | audit | refill` (`pay.rs:2342-2344`); `refill` is forwarded to
`pay_refill::run` before any workspace is opened (`pay.rs:2242-2244`).

**Session and routing.** `Session` (`pay.rs:96-107`) holds the workspace root, the parsed workspace, the Host path, config,
the global pinned socket (`SOCKET`), the key path, the subject and an optional operator socket. `Session::call`
(`pay.rs:160-169`) routes ops 117-120 to `--operator-socket` only and everything else to the public socket. `open_for_audit`
(`pay.rs:114-146`) loads either the live workspace or a retained snapshot (`--offline true`) and creates `pay/`,
`pay/receipts/`, `pay/quarantine/` as private dirs.

**Ops used** (constants `pay.rs:37-58`): assignment/book 103-106 (`ASSIGN_OPS`), observation 108-111 (`OBSERVE_OPS`),
self-enrollment 117-120 (`ENROL_OPS`), pay view 107, clock view 129, enrollment view 112, plus 181 (paid status) at
`pay.rs:1461` and `1931`.

**Answer model.** `Answer` = `Confirmed(Value) | Refused{reason, phase, detail} | Undecided(String)` (`pay.rs:274-286`).
`answer()` (`pay.rs:374-398`) maps the Host's inspected outcome JSON: `type=confirmed`, `type=refused` with hex `phase`/`detail`,
and anything else (uncertain/unavailable/contention/absent) to `Undecided`. `refusal_reason()` (`pay.rs:321-363`) is a strict
parser of Lean `repr` text: it collapses whitespace (Lean's pretty printer wraps lines, `pay.rs:322-324`), requires the exact
`Minidregg.Theory.Receiving.Refusal.family (...)` wrapper for phase `pay-observation` (`pay.rs:327-333`), recognises the durable
nullifier refusal `ALREADY_CONSUMED` only under phase `durable` (`pay.rs:63-64`, `334-336`), and otherwise accepts a
constructor name directly after one of four `Reject.` prefixes (`pay.rs:65-70`), with a special `decision:<leaf>` /
`verifier:<leaf>` form for `PayEnrolReceiver.Reject.decision|verifier (...)` (`pay.rs:350-360`). A blind `reason:"undisclosed"`
short-circuits (`pay.rs:385-388`). The tests at `pay.rs:2453-2528` pin these spellings, including the wrapped forms.

**Decision records.** Every attempt directory gets an immutable `decision.json` of type `minidregg-pay-decision-v1`
(`pay.rs:528-541`) published by `publish_decision_json` (`pay.rs:193-211`): create-new via
`mini_sdk::durable::create_new`; an existing file must be byte-equal as JSON or the call refuses ("retained payment decision
differs"). Decisions used: `assigned | abandoned | retried | refused | installed | credited | absent | waiting | probed |
alreadyCredited | quarantined | enrolled | renewed | journalled | claimRetained | alreadyDecided`.

**`pay address`** (`pay.rs:636-710`): finds the account reference (`account_reference`, `pay.rs:566-590`), returns a retained
`pay/address-ACCOUNT.json` if present (`pay.rs:648-651`), otherwise first settles any submitted-but-undecided assign attempt
for the same account by op 106 lookup (`pay.rs:653-668`), then authors `pay-assign` with
`{subject, capability, account, index: view.nextFree, nonce, expectedAuthorityRoot, expectedPayRoot}` (`pay.rs:673-677`),
submits once, and on confirmation writes the address record (`finish_address`, `pay.rs:617-634`) whose address is
`view.book[index]` and whose tariff is the view's. Exit codes: 3 refused, 4 undecided (`pay.rs:697`, `701`).

**`pay status`** (`pay.rs:712-766`): prints the retained deposit address, the Book balance of the tariff asset read from a
signed resource view of the account (`workspace::signed_view`, `pay.rs:732-747`), the clock and the tariff version/validity.
Read-only.

**`pay book`** (operator) (`pay.rs:770-846`): reads a JSON `{control, book:[addr...], tariff?}`, normalises each address and the
tariff's `mint`/`tokenProgram` from base58-or-hex to hex (`key_hex`, `pay.rs:258-269`), authors `pay-book` with
`bookStart = view.bookSize` and the expected factory/authority/pay roots (`pay.rs:801-806`), submits through op 105.

**`pay watch-config`** (`pay.rs:861-917`): writes the pay-watcher's config (`asset.mint`, `asset.tokenProgram` in base58, the
assigned book rows `index < nextFree` plus the enrollment row, `receiptsDir`, optional `minEndpoints/maxPages/pageSize` and
`enrol {index, journalFloor, cursorFile}`) with `fsio::replace_private`. The enrollment index and journal floor come from CLI
flags (`pay.rs:2282-2289`), not from the signed tariff (see section 4).

**`pay observe` / `heartbeat` / `--resume`** (the watcher's submit path): `observe` (`pay.rs:1271-1356`):
1. `resolve_pending` (`pay.rs:1098-1133`) first resolves every self-enrollment attempt (`resolve_pending_enrolments`,
   `pay.rs:1681-1725`) and every submitted-but-undecided report by exact lookup (op 111 / op 120); `absent` lets the records be
   observed again, `confirmed` writes receipts;
2. parses the watcher file `{tip:{slot,blockTime}, observations:[...]}` (16 MiB cap, `pay.rs:2201-2214`); `Record::parse`
   (`pay.rs:933-945`) requires `signature` 64 bytes lowercase hex, `address` 32 bytes, canonical `index` and `amount`; records whose
   `SIGNATURE.ADDRESS` receipt symlink exists are skipped (`pay.rs:1291-1299`);
3. partitions records at the tariff's `enrolIndex` (`enrol_index_of`, `pay.rs:1361-1369`) from ordinary records;
4. ordinary records go into ONE report per tip (`observe_records`, `pay.rs:1786-1852`): confirmed → `credited` and receipts;
   `stalePay|staleAuthority` → one rebuilt retry; `tipInvalidOrRegressing` → final refusal; `tickTooSoon|tipBehindClock` → wait;
   `alreadyConsumed` with `clock.slot == tip.slot` → the tick nullifier was spent (wait, `tipReported`); a per-observation reason
   or `alreadyConsumed` at a newer tip → `probe` each record one per report (`pay.rs:1170-1216`) and `settle_one`
   (`pay.rs:1221-1252`): `alreadyConsumed` = already credited (receipt), any `PER_OBSERVATION` reason (`pay.rs:73-85`) = quarantine
   (`pay/quarantine/NAME.json`, `pay.rs:1016-1028`) and exit 3; the loop is bounded by `2*len+4` reports (`pay.rs:1795`);
5. enrollment-index records go ONE per submission to ops 117-120 on the operator socket (`enrol_records`, `pay.rs:1586-1677`),
   with the before/after enrollment views (op 112) retained; a confirmed submission is classified by `enrol_decided`
   (`pay.rs:1477-1564`): for a v2 memo it asks op 181 for the exact source status and maps `pendingV2 → claimRetained`,
   `consumedV2/originalMemo → enrolled|renewed`, `consumedV2/acceptCurrentQuote → claimRetained`, `journalV1Negative → journalled`
   (`v2_enrol_classification`, `pay.rs:1416-1450`); for v1 it reads the after-view journal row by `(signature,address)` or the memo
   key's entry (new = enrolled, present before = renewed, `pay.rs:1487-1526`). Only one confirmed enrollment per tip; the rest
   print `enrol-pending` so the tick script runs more rounds (`pay.rs:1344-1353`; `deploy/pay/mini-pay-watcher` "PAY_ENROL_ROUNDS").

`heartbeat` (`pay.rs:2327-2335`) submits an empty report at a CLI-chosen tip (advances the pay clock slot). `--hold true`
builds but does not submit (`pay.rs:1312-1316`); `--resume ATTEMPT` submits a held report (`pay.rs:1728-1753`).

**Receipts directory contract.** `pay/receipts/SIGNATURE.ADDRESS` is a symlink to the deciding attempt (`pay.rs:1004-1014`);
"the first decider wins". The pay-watcher reads this directory as its receipts (`pay.rs:24-25`, `pay-watcher` README
"The only memory it has is the receipts directory").

**`pay audit`** (`pay.rs:2032-2133`): sums the credit of every `credited` report as `min(amount, maxPerObservation) *
creditPerAtomic` from the retained `view.json` tariff (`report_credit`, `pay.rs:1859-1875`), re-looks-up every report (op 111)
and v1 enrollment (op 120) expecting `confirmation:"replayed"`, and for v2 origins asks op 181 (online) or runs the local
`Host CONFIG pay-claim-audit IN OUT` full re-admission (offline, `v2_audit_source`, `pay.rs:1925-1991`, with Host and config
digests checked before and after, a streamed bounded JSONL reader `audit_json_line`, `pay.rs:1899-1916`, and an exact
completion footer). Offline it then checks the ledger identity `-well_now = -well_genesis + Σ credited` against
`pay-ledger-genesis.json` beside the pinned config (`ledger_identity`, `pay.rs:2138-2197`, or `verified_ledger_identity`,
`pay.rs:2018-2030`). Findings → exit 3.

**Files and directories touched:** `WORKSPACE/attempts/pay-{assign,book,report-SLOT,enrol-SLOT}-NONCE/{view.bin,pay-view.json,
clock.bin,clock.json,view.json,command.json,command.bin,plan.bin,plan.json,signature.bin,ingress.bin,submit-marker.json,
outcome.{bin,json},lookup-NNNN.{bin,json},decision.json,records.json,enrolment-{before,after}.{bin,json},memo.{bin,json},
enrol.json,enrol-status-v2.json}`; `WORKSPACE/pay/{address-ACCOUNT.json,receipts/,quarantine/,enrol-cursor.json,.view-*,
.ledger-*,audit-*}`; the watcher config path given by `--out`; `pay-ledger-genesis.json` beside the config.

### 1.2 `pay_claim.rs` (1,798 lines): pending-claim custody (`mini pay-claim`, ops 182-186)

Entry: `pay_claim::run` (`pay_claim.rs:875-991`), `main.rs:3269`. Actions `quote | accept | rotate | lookup`.

**Purpose.** A v2 deposit that the kernel could not consume (terms stale, quote expired, authority stale) stays a pending claim
with zero credit (`pay_status.rs:129-142`). The owner either accepts the current quote (`acceptCurrentQuote`) or, for a pending
owner rotation, signs with the precommitted successor (`rotatePendingOwner`) (`command_action`, `pay_claim.rs:364-374`).

**`quote`** (`run_quote`, `pay_claim.rs:762-873`): builds `{"kind":"claim","claimId":hex(origin),"mode","weeks","starter",
"expiryHour","nonce"}` (`pay_claim.rs:797-798`) where the origin claim id comes from the retained join (`paid_context`), asks op 182
over the socket (`Session::quote`, `pay_claim.rs:212-244`) or `POST {bootstrap}/quote` (HTTPS via the pay-watcher curl transport,
5 s, 16 KiB), decodes `signing.canonicalCommand` through the pinned local Host (`inspect pay-claim-command`), and binds the
quote to the request in `validate_quote_command` (`pay_claim.rs:696-758`): identity, authorizing key, epoch, both roots, the
102-byte claim id, mode/weeks/starter/expiry/nonce, `priceReserved == false`, every split field canonical. Writes OUTPUT (the
canonical unsigned command), `OUTPUT.quote.json` (the summary sidecar, published first) and `OUTPUT.evidence/`.

**`accept`/`rotate`** (`execute`, `pay_claim.rs:583-680`): reserves the operation directory atomically
(`make_private_dir`), writes `config.json`, the manifest and origin, inspects the command, gets the op 183 plan (bound 3072),
checks the plan names the same command, prints the source command to stderr, signs `signingMessage` with the key that must equal
`authorizingKey`/`successorKey` (`signer`, `pay_claim.rs:968-976`), assembles via op 184 (bound 4096), inspects the ingress and
validates it (`validate_ingress`, `pay_claim.rs:497-515`) to get the expected receipt `{transactionId,eventId}`, writes the
immutable `operation.json` (`minidregg-pay-claim-operation-v1`, with sha256 of command/plan/signature/ingress/config), then
submits op 185 exactly once (`exchange_outcome`, `pay_claim.rs:468-495`).

**Recovery** (`recover`, `pay_claim.rs:517-581`): any existing directory means lookup only: it re-verifies every retained digest,
re-inspects the plan and ingress through the pinned local Host, requires the original expected receipt, and sends op 186 on the
exact ingress. A confirmed outcome must name exactly the expected `(transactionId,eventId)` and a known confirmation kind
(`Decision::source`, `pay_claim.rs:413-440`).

**Transports.** `Endpoint::Socket` uses `transport::invoke_pinned_with_local` (the local Host image and config are pinned); 
`Endpoint::Bootstrap` uses closed HTTP routes `/claim/{plan,assemble,submit,lookup}` (`claim_route`, `pay_claim.rs:39-47`) whose
reply is `{"type":"payClaimWire","operation":"N",FIELD:hex}` with exactly three keys and 1..4096 bytes
(`decode_claim_wire`, `pay_claim.rs:49-75`); `/metadata` is checked once against the local `profile` (domain, semantics,
`hostSha256`, `quoteType`, `statusType`, `expiryClock = processingChainHour`, `recovery = acceptCurrentQuote`, memo `enrol:v2`;
`validate_metadata`, `pay_claim.rs:118-141`). `check_pins` (`pay_claim.rs:144-152`) re-hashes the Host image and config before
and after every local invocation.

### 1.3 `pay_memo_v2.rs` (1,164 lines): the v2 memo and quote validator

Constants: unsigned 229 bytes, binary 357 bytes, ASCII memo 485 bytes, SSH namespace `dregg-enrol@v2`, prefix `enrol:v2:`, tag
`DREGG/PAY/ENROL/POSSESSION/v2` (`pay_memo_v2.rs:13-18`).

* `Unsigned` (`pay_memo_v2.rs:51-64`): mode byte, deployment commitment, pricing commitment, identity key, authorizing key,
  epoch (u64 LE), ssh key, next digest, weeks (u32 LE), starter (u64), expiry hour (u64), amount (u64). `validate`
  (`pay_memo_v2.rs:67-77`) = Lean `Unsigned.WellFormed` (`Kernel/PayEnrolMemoV2.lean:107-111`): epoch and weeks positive; mode 1
  requires authorizing = identity and epoch 1; mode 3 requires a zero next digest. `encode`/`decode` (`pay_memo_v2.rs:87-134`).
  `frame` = tag ‖ unsigned ‖ mint ‖ token program ‖ recipient (`pay_memo_v2.rs:136-145`).
* `Uint256` (`pay_memo_v2.rs:151-198`): four-limb exact arithmetic used only for the split conservation check.
* `validate_purchase_quote` (`pay_memo_v2.rs:304-564`): strict key sets at every level (`keys`, `pay_memo_v2.rs:247-255`), JSON
  ≤ 8192 bytes, `priceReserved == false`, `maxQuoteLifetimeHours == 1`, `asOf.hour == blockTime / 3600` and expiry in
  `[hour, hour+1]` (`pay_memo_v2.rs:346-350`), settlement context equal to the pinned one and non-zero, owner = local identity,
  current key, epoch and NEXT, wire mode derived from (mode, NEXT) (`pay_memo_v2.rs:448-456`), every unsigned field equal to local
  intent, `unsignedCanonical` equal to the Rust encoding, `miniMessage`/`sshMessage` equal to the Rust frame, split amount = signed
  amount, `birthFee + membershipCredit + creditedRemainder == mintedCredit`, remainder ≥ requested starter, membership and minted
  credit non-zero, renewal birth fee zero (`pay_memo_v2.rs:521-553`).
* `SignedMemo` (`pay_memo_v2.rs:566-628`): `verify` checks both signatures with `verify_strict` (Ed25519 over the frame, and the
  SSH key over the SSHSIG signed data for namespace v2); `parse` requires 485 ASCII bytes, no `=`, prefix, 357-byte decode, and
  canonical re-encoding equal to the input (`pay_memo_v2.rs:601-622`).
* `sign_and_assemble` (`pay_memo_v2.rs:654-686`): refuses a different local Mini key, checks the SSHSIG armour is one canonical
  envelope ≤ 4096 bytes (`check_armour`, `pay_memo_v2.rs:632-650`), extracts and verifies the SSH signature before making the Mini
  signature, verifies both.
* Tests: the Lean literal vector (`pay_memo_v2.rs:785-803`), every binding tampered (`829-894`), and ~160 lines of hex Solana
  transaction packets used to show a 485-byte memo fits a legacy/v0 transaction under 1232 bytes (`pay_memo_v2.rs:1001-1163`); that
  last test exercises no production code beyond `MEMO_LENGTH`.

### 1.4 `pay_status.rs` (773 lines): typed decoder of the op 181 `payStatus` JSON

`Nat` keeps canonical decimals below 2^256 as strings (`pay_status.rs:14-74`). `parse(value, request)` (`pay_status.rs:429-598`)
enforces the exact field sets of `Host/PayClaims.lean:177-185`, the identity echo, the locator echo and that
`claimId == "soltx:" ‖ signature ‖ recipient` (`pay_status.rs:492-497`), `asOf.hour == blockTime/3600` (`pay_status.rs:512-515`),
freshness/as-of consistency, `leaseState` recomputed from `entry.leaseUntil > clockHour` (`pay_status.rs:573-581`), and payment
states `notRequested | unobservedOrUnknownPositiveV1 | pendingV2 | consumedV2 | journalV1Negative` (`pay_status.rs:302-427`),
including split conservation and "authorization originalMemo ⇔ no accepted request" for `consumedV2` (`pay_status.rs:366-393`) and
the journal reason code table `0..=8 | 100..=105` (`pay_status.rs:409-413`, the Lean table is `Kernel/PayEnrolMemo.lean:495-499`).
Used by `pay.rs`, `join_solana_v2.rs`, `paid_context.rs`, `pay_claim.rs` and also `enrollment_bootstrap.rs` (outside the shard).

### 1.5 `pay_refill.rs` (155 lines): `mini pay refill` (PAY P6, ops 113-116)

`submit` (`pay_refill.rs:82-129`): reads the pay view (op 107) over op 8 inspection, authors `pay-refill`
`{subject,capability,account,task,amount,gain,nonce,expectedAuthorityRoot}` via op 7, plans (op 113), checks
`/command/canonical`, signs `/header/canonical`, assembles (op 114), submits (op 115) and prints the inspected outcome; every frame is
retained in a FRESH directory (`fsio::create_private_dir`, `pay_refill.rs:98`). `lookup` (`pay_refill.rs:131-142`) sends op 116 on
the retained `ingress.bin`. No submit marker, but the fresh-directory rule makes a rerun of `submit` on the same `--dir` refuse.

### 1.6 `join_solana.rs` (1,278 lines): v1 pay-to-enrol (`mini join --mode solana|wait|renew`)

Reached when `--mode` is `solana|wait|renew` and `--memo-version v2` is absent (`main.rs:3198-3200`).

* Memo v1 = `enrol:v1:<hex miniKey>:<unpadded base64 sshBlob>:<hex miniSig>:<hex sshSig>`, exactly 400 bytes (`encode_memo`,
  `join_solana.rs:102-110`; `MEMO_LENGTH`, `:39`). Mini possession frame = `"DREGG/PAY/ENROL/POSSESSION/v1" ‖ mint ‖ address ‖
  sshBlob` (`:113-115`); SSHSIG message = `mint ‖ address ‖ miniKey` (`:118-120`).
* Shared helpers also used by v2: `ssh_blob`, `b64_encode/b64_decode` (`:57-97`), `sshsig_signed_data_for` (`:131-141`),
  `sshsig_raw_signature_for` (`:162-210`, field-by-field SSHSIG parse), `ssh_public_key` (`:216-235`, FIDO refused by name),
  `run_ssh_keygen` (`:438-451`), `admitted_workspace_v2` (`:875-884`).
* `solana` (`:541-655`): refuses an existing directory; makes or takes the Mini key and ssh key; fetches the Host quote (op 121 over
  the socket, `POST /mini/v1/quote`, or an offline `--quote FILE`; `quoted_terms`, `:365-383`) and checks it echoes key, mode, weeks,
  starter, deployment domain, `priceReserved:false` and the pinned enrollment address (`terms`, `:332-363`); signs both possessions
  (ssh via `ssh-keygen -Y sign -n dregg-enrol@v1`), verifies both, has the local Host's codec read the memo back
  (`host_reads_back`, `:516-539`), writes `join.json` and prints the address, amount (from `atomicAmount`, `:636`), memo, a Solana
  Pay link and an `spl-token transfer` line (`print_payment`, `:407-434`).
* `renew` (`:665-702`): re-quotes with mode `renew`, re-derives the memo fields from the retained memo text by fixed slices
  (`:681-682`), requires the canonical re-encoding and the Host read-back, prints the same memo with the new amount.
* `wait` (`:900-1021`): polls the enrollment view (op 112 or `GET /mini/v1/enrollment/KEY[?signature=]`), finds the entry by Mini
  key, refuses an expired or absent lease (`inactive_membership`, `:888-898`), derives stable ids with
  `Host CONFIG pay-enrol-ids KEY OUT`, and builds the member's workspace (`admitted_workspace`, `:706-860`), which pins a
  `workspace-setup.json`, publishes the workspace atomically via a staged rename, attaches a published birth context with sponsor
  funding replaced by the member's own grants (`:723-738`), imports the account and factory references and completes fresh
  onboarding. A journaled payment (by `--signature`) exits 3 with "ask the operator to comp it" (`:998-1011`).

### 1.7 `join_solana_v2.rs` (1,445 lines): v2 paid entry (`mini join --memo-version v2 ...`)

* `Pin` (`join_solana_v2.rs:58-127`): `minidregg-enrol-pin-v2` with exactly six fields, canonical non-zero base58 keys,
  `decimals ≤ 38`, an SSH login. `Common` (`:129-140`) pins the Host image sha and config bytes; `check_pins` (`:150-156`) re-checks.
* `request` (`:179-206`): op 181/182 over the socket, or `POST {base}/status|/quote` over HTTPS (8 KiB, 5 s); 4096-byte request cap.
* `source_context` (`:263-293`): local `Host CONFIG pay-enrol-v2-context IN OUT` gives the deployment commitment and NEXT digest.
* `expiry` (`:306-324`): requires `chainFreshness == fresh` and chooses `hour+1` (or a given hour in `[hour, hour+1]`).
* `prepare_payment` (`:399-523`): status (mode must agree with membership, `:422-426`), context, quote request
  `{kind:"purchase", identityKey, sshKey, mode, weeks, starter|null, expiryHour, freshNext?}` (`:433-438`), the starter taken from
  the quote's `minimumStarterCredit` when not given (`:458-461`), `validate_purchase_quote`, `ssh-keygen -Y sign`,
  `sign_and_assemble`, `parse_and_verify`, then `save_payment` (`:359-375`): `payments/NONCE.json`, `join.json` once (create-new),
  `latest-payment.json` replaced.
* `initial` (`:718-810`): resumable preparation keyed by `preparation.json` pins (key, ssh, NEXT, Host/config/domain/seed/bootstrap/pin).
* `wait` (`:593-717`): requires an explicit transaction signature (or the retained locator file), asks op 181 with the exact locator,
  and acts on the payment state: pending → the "do not pay again" message, journal → error, consumed → amount must equal the
  retained one and, if the lease is active, the SSH blob and stable ids must agree and `admitted_workspace_v2` builds the
  workspace (with `paid_onboarding::reconcile` for custody changes); `paid-onboarding-recovery.json` is replayed first (`:607-611`).

### 1.8 `paid_context.rs` (788 lines) and `paid_onboarding.rs` (218 lines)

`paid_context` builds the closed transport/origin snapshot `pay_claim` uses: `Source::Workspace` (an admitted workspace; strict
retained projection on lookup, `paid_context.rs:227-298`) or `Source::Join` (a signed v2 `join.json` or a selected
`payments/RECORD.json`, `paid_context.rs:300-484`), re-verifying the v2 memo with both signatures and every retained field against it
(`:401-413`), the locator (`:414-429`), and computing the origin claim id `"soltx:" ‖ signature ‖ recipient` (`:430-432`).
`binding()` (`:149-168`) is what `operation.json` pins; `retained_lookup` (`:492-540`) rebuilds a context for an existing operation
record without any signing key and refuses if the binding changed. `validate_source_command` (`:198-224`) refuses an accept whose
claim id is not the retained origin, and enforces current-vs-next key intent.

`paid_onboarding` is a local two-phase journal for changing which key file a paid workspace uses: `reconcile`
(`paid_onboarding.rs:108-163`) writes `paid-custody-NONCE.json` with exact before/after values for at most three files
(`workspace/workspace.json`, `workspace-setup.json`, the `onboarding-<sha256(memo)>.json` selection), points
`paid-onboarding-recovery.json` at it, and `replay`/`apply` (`:44-92`) publish each `after` only if the current file equals `after`
or `before`. It hashes the JSON journal with `host_image_sha256` (`:83`, `:161`), a function named for Host images.

### 1.9 `credit.rs` (1,083 lines): room tariffs and room-week credit (`mini credit`)

Entry `credit::run` (`credit.rs:698-1004`), `main.rs:3262`; also used in process by `shell.rs` (verb table `shell.rs:100`,
`client("credit", ...)` at `shell.rs:1787-1838`), `hermes.rs:618-793`, `chat.rs:2039`, and as a subprocess by
`native/grain-runtime/src/concierge.rs:348-445`.

Data model: a room's tariff is a set of declared fields on the room cell `R` (`TARIFF_FIELDS` from `room_schema`, `credit.rs:22`);
`Room {target, height, root, fields}` from a signed read (`room`, `credit.rs:143-157`) or a signed historical read at height
(`room_at`, `credit.rs:178-195`). Founder-settable fields: `week, birth, hermes/turn, period, open` (`credit.rs:31`). Member verbs
`observe, place, append`; concierge verbs add `delegate` (`credit.rs:41-44`). Default period 2016 heights, delegation `maxCost`
50000 (`credit.rs:46-47`).

Actions: `balance` (signed read via `fleet::account_balance`), `room [--at H]`, `tariff [--set F --value N]` (one scalar
create/write turn, `set_fields`, `credit.rs:238-268`), `pay` (a fleet turn from my account to the till publishing
`"room R week W at H"` on topic `renew`, `credit.rs:750-795`; a week-0 room files a request JSON in an outbox instead),
`topup` (to the Hermes budget or runner account), `turn` (one Hermes turn's payment, recorded operation), `return` (Hermes budget
minus the fleet base fee back to the founder, recorded), `renew` (delegate a member window under R ending at a height, proposal id
`renew-SUBJECT-NOTAFTER`, `credit.rs:501-536`), `status` (window adoption from an inbox and display, `credit.rs:908-963`),
`refund` (till → payer on topic `refund`), `ledger` (Host op 180 incoming ledger via `fleet::incoming`), `install` (the founder
births the till and runner, writes tariff account fields, delegates the concierge, writes the concierge program description,
`credit.rs:546-626`), `adopt` (import inbox references, `credit.rs:631-684`), `lookup-operation`.

Window adoption (`adopt_window`, `credit.rs:389-469`) chooses the delegated reference whose signed capability view has the latest
`notAfter` and `place`, imports it under a staged alias and swaps the reference with an exact-prior publish (`switch_window`,
`credit.rs:473-488`).

### 1.10 `market.rs` (629 lines): sealed-bid market

Reached through `workspace.rs:7038-7076` (`law-show`, `market-open`, `market-bid`, `market-reveal|settle`, `market-bids`) and the
shell. One declared cell under `deploy/shell/templates/market/sealed/law.market` (`LAW_TEMPLATE`, `market.rs:36-39`), 4 slots
(`market.rs:47`), fields 1-5 and `16+8k+0..5` (`slot_fields`, `market.rs:65-68`). A bid commits
`cSHAKE256(S="DREGG.PRED.HASHEQ/v2")` over the `Pred.HashEqDigest.Opening.preimage` encoding (`preimage`, `market.rs:125-139`;
`digest`, `:142-148`); the opening is kept privately in `WORKSPACE/market/NAME/ID.json` (`:379-383`). `settle` (`:476-504`) runs
`clear` (`:271-286`: revealed positive bids by price desc then slot asc, clearing price = lowest filled price) and proposes the
fills. Deposits are refused by name (`DEPOSIT_UNAVAILABLE`, `:42`, `:325-327`): no money moves in this module at all.

### 1.11 `meter.rs` (253 lines): provider usage quote (op 19)

`meter` (`meter.rs:133-196`) reads the retained provider metadata (v3: `providerResourceId`, `route ∈ {user,pool,homelab}`),
request and response (1 MiB / 8 MiB caps), copies them into a private consumer attempt, sends op 19 with
`u32le|metadata|u32le|request|response`, and validates the Host's `minidregg-provider-metering-v2` reply shape and provenance
string (`quoted_report`, `meter.rs:61-131`). It computes no charge. Called by `native/grain-runtime/src/main.rs:10114-10148`
(`mini meter ...`); CLI arm `main.rs:3492-3511`.

### 1.12 `agent_payer.rs`, `agent_reserve.rs`, `agent_reserve/lifetime_v3.rs`, `agent_reserve/lifetime_v3/paid.rs`, `agent_lifetime_grant.rs`

Operator custody for AgentGrain purse reserves and paid dispatch. All five are the same state machine:
`plan` (author request locally, inspect, plan op on the operator socket, inspect plan, retain `pin.json` with Host/config/socket/
request/plan digests) → `seal` (re-inspect, compare to an operator approval JSON, `client_consent::operator_plan` re-derivation,
sign each slot with `approve_slot`, encode signatures with the local Host, assemble op, retain `call.bin` + `seal.json`) →
`submit` (one-shot marker, submit op, inspect outcome, retain `receipt.json`) → `lookup` (numbered markers, lookup op, must be
`replayed`, receipt must equal the retained one).

| module | event | plan / assemble / submit / lookup ops | CLI (`main.rs`) | caller |
|---|---|---|---|---|
| `agent_reserve.rs` | event21 purse reserve (v2) | 58 / 59 / 2 (public) / 3 (public) | `agent-reserve-{plan,seal,submit,lookup}` `main.rs:3869-3905` | `grain-runtime/src/main.rs:4748,4942,4955,4996` |
| `agent_payer.rs` | event21 paid dispatch payer signatures | 48 (re-plan only) | `agent-payer-sign` `main.rs:4052-4072` | `grain-runtime/src/main.rs:5672` |
| `lifetime_v3.rs` | event27-backed lifetime reserve (v3) | 80 / 81 / 2 / 3 | `agent-lifetime-reserve-*` `main.rs:3906-3942` | `grain-runtime/src/main.rs:4311,4530,4542,4595` |
| `lifetime_v3/paid.rs` | event26 lifetime paid dispatch | 78 / 79 / 76 (operator) / 77 (operator) | `agent-lifetime-paid-{plan,payer-sign,seal,submit,lookup}` `main.rs:3943-3976` | plan+payer-sign: `grain-runtime/src/main.rs:5339,5432`; seal/submit/lookup: none (CLI + evidence only) |
| `agent_lifetime_grant.rs` | event27 lifetime grant | 74 / 75 / 72 / 73 (all operator) | `agent-lifetime-grant-*` `main.rs:3977-4005` | `scripts/spk-platform/issue-agent-lifetime-grant.sh:202,230` |

`approve_slot` (`agent_reserve.rs:296-325`) is the one signing gate: role/index/keyId/keyEpoch/algorithm "1"/header sha256 must
equal the approval, the key file must be private and its public key equal the approval's. `exact_receipt`
(`agent_reserve.rs:111-138`) projects the four receipt fields and adds `reserveIndex = acceptedCount - 1`;
`agent_lifetime_grant.rs:59-78` does the same with `grantIndex`. `agent_reserve.rs` also exports general helpers (`field`, `bounded`,
`private_bytes`, `retain_json`, `source`, `source_inspect`, `digest`) that `job.rs`, `clock.rs`, `checkpoint.rs`, `fleet.rs`,
`session_enrollment.rs`, `activity.rs`, `key_adoption.rs`, `receipt_continuity.rs`, `member_app.rs`, `fn_frontier.rs` import.

### 1.13 `job.rs` (1,123 lines): `mini job` (COMPUTE; job money ops 160-163)

Entry `job::run` (`job.rs:952-969`), `main.rs:3221`. A job is a declared cell (fields 0-15, names `job.rs:39-42`, states
`open, claimed, answered, upheld, slashed, void, closed` `job.rs:38`) born in a room under `law.job.json` with `{CALLER}`,
`{PROGRAM}`, `{WINDOW}`, `{NEG_WINDOW}` bound (`post`, `job.rs:591-595`). Every field write is a workspace proposal + submit run
in-process through `crate::run` (`client`, `job.rs:161-179`; `write`, `job.rs:278-309`). Money moves only through
`money` (`job.rs:324-362`): pay view (op 107) for the authority root, author `job-money`
`{subject,capability,jobCapability,job,action,account,amount,nonce,expectedAuthorityRoot}` (op 7), plan op 160 (a `jobRefused [k]`
refusal is annotated with the law clause text, `job.rs:344-353`), sign, assemble op 161, retain `ingress.bin` +
`custody-origin.json` (`job.rs:372-382`), write `submit-ID.started.json` (`job.rs:386-393`), submit op 162, retain
`outcome-ID.json`. Actions FUND=1, CLAIM=2, SETTLE=3 (`job.rs:48-50`).

`post` (`job.rs:560-642`) births, writes the order (fields 0-11) and funds; `claim` (`:644-700`) imports the job reference under the
room grant and bonds; `answer` (`:761-791`) runs the kernel dry run (op 132 program show + op 134 dry run, `dry_run`,
`:512-539`) unless `--output` is given and writes state 1→2, output, steps, `finalAt = now + window`; `truth` (`:746-759`) writes
the truth field with the run claim; `check` (`:793-858`) decides stall (1→4), sync uphold (1→3), timeout (2→3) or truth then
match/mismatch (2→3/4), retrying once on `sampleStale`; `settle` (`:860-912`) first recovers any retained settlement whose sends
are not all definitively refused (`settlement_needs_recovery`, `:416-471`; `recover_settlement`, `:487-498`: op 163 lookup, and on
`absent` resubmission of the same bytes), else plans a fresh SETTLE.

### 1.14 `well.rs` (256 lines): realm wells (`mini well`, ops 123-125)

`new` = `workspace create --kind account --in REALM` (`well.rs:214-233`). `mint|burn|floor` (`command`, `well.rs:88-183`): author
`well-command` locally, plan op 123, inspect `well-plan`, check `commandBytes`, sign `header`, assemble op 124, submit op 125. A
non-123/124/125 reply with 255 is reported as "host refused" with the hex outcome and a `refusal.txt` (`well.rs:168-175`). Files
are written with `create_public` (`well.rs:63-65`), not private. `ledger` runs `Host CONFIG well-ledger OUT` (`well.rs:185-208`).

### 1.15 `clock.rs` (401 lines) and `checkpoint.rs` (182 lines)

`clock` (`clock.rs:342-401`, `main.rs:3218`): `init` writes a `minidregg-clock-workspace-v1` (`clock.rs:310-340`); `tick`
(`clock.rs:246-308`) resolves retained attempts by byte-for-byte resubmission (`resolve_pending`, `:227-244`), reads the clock view
(op 129), proposes `now` = wall clock (`unix_now`, `:151-156`) or `--now`, clamped in catch-up mode to `current_now +
maxStepSeconds` (`:262-271`), carries the slot from the view, authors `clock-tick`
`{sponsor,capability,nonce,expectedAuthorityRoot,expectedClockRoot,now,slot}`, plans op 126, signs, assembles op 127, retains
`clock-attempts/t-NONCE/{tick.json,ingress.bin}` before submitting op 128, deletes the attempt and appends one line to
`clock-journal.tsv` (rotated at 1 MiB) when the outcome is definite (`resolve`, `:211-224`). Without `--now` it loops ticks until
the target is reached or a tick is not confirmed (`:372-390`). Deployed by `deploy/clock/mini-clock-tick.{service,timer}` once a
minute as user `mini`.

`checkpoint` (`checkpoint.rs:156-182`, `main.rs:3219`): `view` (op 173) and `certify` (`checkpoint.rs:117-154`): optional
`--min-tail` gate on `tail` from the view, author `certify` with the current head and chain digest, plan op 170, sign, assemble
op 171, submit op 172. Deployed by `deploy/checkpoint/mini-checkpoint-certify.{service,timer}` (user unit, operator workspace,
`MINI_CHECKPOINT_CONTROL=53`).

---

## 2. What it assumes of its surroundings

### 2.1 Host operations used, with the Lean cross-check

Registry entries are from `protocol/host-operations.json`; Lean arms are in `Host/Main.lean` unless stated.

| op | symbol (registry) | routes | Rust site(s) | Lean arm | agreement |
|---:|---|---|---|---|---|
| 2 / 3 | SUBMIT / LOOKUP | public, operator | `agent_reserve.rs:598,639`; `lifetime_v3.rs:342-348,403-410` | `fnDispatch` | Rust inspects the outcome through the local Host; receipt projection is Rust (`exact_receipt`). |
| 7 / 8 | AUTHOR / INSPECT | public, operator | `job.rs:98-105`, `clock.rs:106-114`, `checkpoint.rs:82-90`, `pay_refill.rs:38-41,111` | `dispatchSession` | payload `u16le len ‖ kind ‖ body` built identically in four modules. |
| 19 | PROVIDER_USAGE_QUOTE | public, operator | `meter.rs:166-172` | `:6744` | Rust frames `u32le|meta|u32le|req|resp`; it validates the reply shape only. Lean decoding not read in detail (section 8). |
| 48 | AGENT_PAID_DISPATCH_PLAN | operator | `agent_payer.rs:125` | `:2166`, `:7771` | Rust requires the reply to equal `48 ‖ plan` byte-for-byte (`agent_payer.rs:41-46`). |
| 58 / 59 | AGENT_RESERVE_PLAN / ASSEMBLE | operator | `agent_reserve.rs:263,536` | `:2134`, `:2147` | plan frame retained and re-checked as `58 ‖ plan` (`agent_reserve.rs:183-185`). |
| 72-75 | AGENT_LIFETIME_GRANT_* | operator | `agent_lifetime_grant.rs:20-23,181,307,393-399,455-462` | `:6771`, `:6775`, `:7649`, `:7658` | consistent op numbers. |
| 76 / 77 | AGENT_LIFETIME_DISPATCH_SUBMIT / LOOKUP | operator; receivers `serveFrame` / `dispatchSession` | `paid.rs:622-631,685-691` | `:2103` (77) | Rust sends 76 and 77 on the OPERATOR socket (`paid.rs:625`, `688`), matching the registry routes. |
| 78 / 79 | AGENT_LIFETIME_DISPATCH_PLAN / ASSEMBLE | operator | `paid.rs:206-212,343-349,463-469,511-517` | `:2241`, `:2254` | assembly payload `pair(plan, pair(app, pair(grant64, payer)))` (`paid.rs:508-510`), pinned by test `paid.rs:800-813`. |
| 80 / 81 | AGENT_LIFETIME_RESERVE_PLAN / ASSEMBLE | operator | `lifetime_v3.rs:17-18,141,257-263` | `:2210`, `:2222` | consistent. |
| 103-106 | PAY_COMMAND_* | public, operator | `pay.rs:37-42` (address, book) | `:6908-6934` | **op 105 is blind**: every refusal becomes `refused undisclosed "admission"` (`:6923-6930`, `Kernel/NativeHost.lean:3142-3145`). Rust still branches on named reasons (dead code, section 5). |
| 107 | PAY_VIEW | public, operator | `pay.rs:407`, `pay_refill.rs:102`, `job.rs:335` | `:7040-7043` | inspected as `pay-view`. |
| 108-111 | PAY_OBSERVATION_* | public, operator | `pay.rs:43-48` | `:7088-7111` | op 110 returns the full outcome (not blind), so the `PER_OBSERVATION` names reach Rust. Detail wrapper `Theory.Receiving.Refusal.family (...)` required by Rust (`pay.rs:327-333`). |
| 112 | PAY_ENROLLMENT_VIEW | public, operator | `pay.rs:1373`, `join_solana.rs:931` | `:7112-7118` | inspected as `pay-enrolment-view`. |
| 113-116 | PAY_REFILL_* | public, operator | `pay_refill.rs:113-140` | `:7218-7245` | op 115 blind (`:7234-7241`). |
| 117-120 | PAY_SELF_ENROLLMENT_* | operator only | `pay.rs:49-54`, `160-169` | `:7167-7190` | op 119 returns the full outcome; reasons `decision (...)`/`verifier (...)` parsed at `pay.rs:350-360`. |
| 121 | PAY_ENROLLMENT_QUOTE | public, operator | `join_solana.rs:42,376-378` | `:7119-7128` | 4096-byte UTF-8 JSON request, both sides. |
| 123-125 | REALM_WELL_* | public, operator | `well.rs:138,159-168` | `:7044-7063` | **op 125 returns 255 for every non-confirmed outcome** (refused AND uncertain/contention) (`:7059-7063`); Rust treats 255 as a refusal (`well.rs:80-84`). No well lookup op exists in the registry. |
| 126-129 | CLOCK_TICK_* / CLOCK_VIEW | public, operator | `clock.rs:147,283,292,205` | `:7065-7087` | op 128 always returns 128 with the outcome; a thrown error becomes 255 (outer handler). |
| 132 / 134 | NOCK_PROGRAM_SHOW / NOCK_DRY_RUN | public, operator | `job.rs:514,531` | `:7337`, `:7359` | not read further. |
| 160-163 | JOB_MONEY_* | public, operator | `job.rs:342,359,397,492` | `:7191-7217` | op 162 blind (`:7207-7213`); op 160 plan refusal carries `jobRefused [k]`. |
| 170-173 | CERTIFY_* | public, operator | `checkpoint.rs:113,140,149,150` | `:7246-7268` | consistent. |
| 180 | FLEET_INCOMING_LEDGER | public, operator | via `fleet::incoming` from `credit.rs:985` | `:6857` | owned by the fleet reader. |
| 181 / 182 | PAY_CLAIM_VIEW / PAY_CLAIM_QUOTE | public, operator | `pay.rs:1461,1931`; `join_solana_v2.rs:11-12`; `pay_claim.rs:221` | `:7129-7142` | request ≤ 4096 UTF-8 JSON, response ≤ 8192 both sides (`pay.rs:1463`, `join_solana_v2.rs:181,204`). Field names of `payStatus` match `Host/PayClaims.lean:177-185` and `pay_status.rs:448-461`; quote request keys match `Host/PayClaims.lean:113-131`; `starter:null` is normalised to the recommended allowance by Lean (`Host/PayClaims.lean:286-293`), which Rust relies on (`join_solana_v2.rs:433`). |
| 183-186 | PAY_CLAIM_PLAN / ASSEMBLE / SUBMIT / LOOKUP | public, operator | `pay_claim.rs:625,658,679,580` | `:7143-7166` | bounds agree: plan ≤ 3072 (`:7147-7148` vs `pay_claim.rs:626`), assembly and ingress ≤ 4096 (`:7151-7152`, `:7157-7158` vs `pay_claim.rs:659`, `548`). Op 185 is NOT blind, so named refusals reach the client. |
| 191 | CARRY_PAY_CLAIM_LOOKUP | reserved, no receiver | not used; `transport.rs:3650-3651` asserts the client refuses to send it | none | consistent: reserved on both sides (`protocol/HOST-OPERATIONS.md:76-79`). |

Representation checks settled by reading both sides:

* `digest` fields in `payQuote`/`payStatus` are lowercase hex of 32-byte LITTLE-endian encodings (`Host/PayClaims.lean:74`);
  `pay_claim.rs:90-105` converts the profile's decimal domain/semantics to 32-byte LE before comparing with the plan's
  `domain`/`semantics` (`validate_plan_profile`, `pay_claim.rs:107-116`). Agree.
* v2 memo layout and well-formedness: `pay_memo_v2.rs:87-134` vs `Kernel/PayEnrolMemoV2.lean:107-136` (widths
  `[1,32,32,32,32,8,32,32,4,8,8] + 8`). Agree; pinned by the Lean literal vector test (`pay_memo_v2.rs:785-803`).
* Journal reason codes: `pay_status.rs:409-413` vs `Kernel/PayEnrolMemo.lean:495-499`. Agree.
* creditFor: `pay.rs:1871` vs `Kernel/PayTariff.lean:105-106` (`min amount maxPerObservation * creditPerAtomic`). Agree (twin).

### 2.2 OS facilities

* Unix only: `std::os::unix::fs::symlink` (`pay.rs:35`), `OpenOptionsExt::mode` (`clock.rs:39`), `DirBuilderExt`/`MetadataExt`
  (`agent_reserve.rs:6`); the CLI arms for `join`, `pay-claim`, `credit`, `job` are `#[cfg(unix)]` (`main.rs:3197-3269`).
* External programs: the local `minidregg-host` binary (author/inspect/profile/pay-enrol-ids/pay-enrol-v2-context/pay-ledger/audit/
  pay-claim-audit/well-ledger/signatures) is required on the CLIENT for every join and claim flow (`join_solana.rs:523-525`,
  `955-961`; `join_solana_v2.rs:249-255`; `pay_claim.rs:156-171`); `ssh-keygen` (`join_solana.rs:438-451`); `/usr/bin/curl` through
  `minidregg_pay_watcher::CurlTransport` (`native/pay-watcher/src/transport.rs:179`, `282`) for every HTTPS bootstrap request.
* No SQLite, no Cap'n Proto, no seccomp/bwrap in this shard. Durability via `fsync` of files and directories
  (`sync_directory_ancestors`, `mini_sdk::durable::create_new`).
* Locks: `transport::service_lock` on `workspace-setup.lock` and `key-transition.lock` (`join_solana.rs:708`,
  `paid_onboarding.rs:99-101,112`); the pay watcher wrapper uses `flock -n` (`deploy/pay/mini-pay-watcher:63`).

### 2.3 Network services

* Solana: none directly. The pay-watcher (another crate) reads RPC; this shard consumes its `observations.json`.
* HTTPS bootstrap endpoints `.../mini/v1` (`join_solana.rs:473-506`) and `.../mini/v2` (`join_solana_v2.rs:172-239`,
  `pay_claim.rs:31-37`, `paid_context.rs:91-105`) served by `mini enrollment-bootstrap` (outside the shard). Plain `http` is allowed
  only to `127.0.0.1`/`[::1]` (`native/pay-watcher/src/transport.rs:193-208`).
* SSH remote transport when the socket is `--remote` (`join_solana.rs:739-745`, `paid_context.rs:186-190`).

### 2.4 File layouts and config

* Workspace layout: `workspace.json`, `refs/`, `attempts/`, `proposals/`, `sources/`, `pay/`, `jobs/`, `market/`, `credit/`.
* Join directory (v1): `join.json`, `mini.key`, `mini.pub`, `ssh/id_ed25519`, `read-NONCE/`, `workspace-setup.json`, `workspace/`,
  `namespace/`, `home/`. Join directory (v2): `preparation.json`, `join.json`, `latest-payment.json`, `payments/`,
  `payment-SHA.locator.json`, `onboarding-SHA.json`, `paid-custody-*.json`, `paid-onboarding-recovery.json`, `v2-NONCE/`.
* Operator inputs: `ENROL.json` (`minidregg-enrol-pin-v1`, `join_solana.rs:245-272`) and `ENROL-V2.json`
  (`minidregg-enrol-pin-v2`, `join_solana_v2.rs:66-112`), both written by `deploy/pay/render-enrol` from
  `deploy/pay/enrol-terms.json`; the pay book JSON for `mini pay book`; approval JSONs for every agent_* seal.
* `pay-ledger-genesis.json` beside the pinned config (`pay.rs:2159-2164`).

### 2.5 Other crates

`minidregg-mini-sdk` (durable writes, decimal/hex helpers), `minidregg-pay-watcher` (transport, `CurlTransport`), `mini-keys`
(not used in this shard), `ed25519-dalek`, `sha2`, `sha3` (cSHAKE for market), `bs58`, `serde_json` with `arbitrary_precision`
(`Cargo.toml:20`), which is why `Value::Number` decimals round-trip exactly (`pay.rs:235`, `pay_status.rs:21`).

---
## 3. Does it decide anything semantic? (the design test)

Method: every place in the 21 files where a balance, price, tariff, refund, quote, rate, "enough credit", "claim valid",
"memo matches", time or verdict is computed or compared was located and classified. "MIRROR" = Rust pre-checks or re-derives
something Lean independently refuses; the Lean side is named. "DECISION" = nothing on the Lean side would refuse if Rust got it
wrong. "ORACLE" = an external fact that Lean cannot check by construction, admitted under a capability.

### 3.1 The central question: where does Rust compute money?

| # | site | what Rust computes or compares | classification | Lean counterpart / gate |
|---|---|---|---|---|
| M1 | `pay.rs:1859-1875` (`report_credit`) | `credit += min(amount, maxPerObservation) * creditPerAtomic`; residual over cap | MIRROR, audit-only (a twin of the Lean formula) | `Kernel/PayTariff.lean:105-106` `Tariff.creditFor`; the audit compares Rust's sum to the Host-computed ledger well (`pay.rs:2172`) and the Host's own `audit` (`pay.rs:2179-2196`). A wrong Rust formula yields a false FINDING, never a credit. |
| M2 | `pay.rs:2018-2030`, `2138-2197` | ledger identity `well_now == well_genesis - credited` | MIRROR, audit-only | the Host reads the ledger (`pay-ledger`, `pay-claim-audit`), Lean `well_tracks_observed` (named in the comment `pay.rs:2136`; not opened by this reader). |
| M3 | `pay.rs:1993-2016` (`consumed_origin_credit`) | splits v2 minted credit into observer-memo vs independent claim acceptance | MIRROR, audit-only | values come from op 181 / `pay-claim-audit` (`Host/PayClaims.lean:160-170`); Rust only attributes. |
| M4 | `pay_memo_v2.rs:532-539` | `birthFee + membershipCredit + creditedRemainder == mintedCredit` in 256-bit | MIRROR (consistency check before signing) | `Kernel/PayEnrolPricing.lean:60-70` `quotePurchase` and `quotePurchase_split`; Lean authored the split. Rust refuses to SIGN an inconsistent quote; it never produces numbers. |
| M5 | `pay_memo_v2.rs:540-553` | remainder ≥ requested starter; membership and minted credit non-zero; renewal birth fee 0 | MIRROR (refuse-to-sign) | `Kernel/PayClaimQuote.lean` (quote), `PayEnrolV2Decision` at consumption (section 8 Q3). |
| M6 | `pay_memo_v2.rs:346-350`; `join_solana_v2.rs:306-324` | quote expiry window `[blockTime/3600, +1]`; requires `chainFreshness == fresh` | MIRROR | `PayClaimQuote.maxQuoteLifetimeHours` (`Host/PayClaims.lean:274`) and the v2 receiver's processing-chain-hour expiry (`PAID-COLD-ENTRY.md` "Expiry is the processing chain hour"). A too-strict Rust check refuses to pay; a too-lax one is caught by Lean (a pending claim, zero credit). |
| M7 | `pay_status.rs:573-581` | `leaseState` recomputed as `leaseUntil > clockHour` and compared with Lean's | MIRROR (consistency of a Lean response) | `Kernel/PayClaimStatus.lean` lease state; if Lean's boundary were `≥`, Rust would refuse valid statuses (fail closed). |
| M8 | `join_solana.rs:888-898` (`inactive_membership`) | `hour >= expiresAt` ⇒ expired: do not build the workspace | MIRROR (UX gate) | lease admission in the Host (SSH proxy and session enrollment); not a credit decision. |
| M9 | `join_solana.rs:323-329`, `join_solana_v2.rs:116-126` | atomic amount → decimal display string | display only | the exact atomic amount printed beside it comes verbatim from the Host quote (`join_solana.rs:636`, `pay_memo_v2.rs:521`). |
| M10 | `credit.rs:873-883` (`return`) | `returned = balance - tariffBase` | MIRROR (Lean refuses an overdraft) | the fleet turn admission (ops 96-98); a wrong fee estimate makes the turn refuse (`bookRefused`), never overdraw. TOCTOU between read and turn is fail-closed. |
| M11 | `credit.rs:490-493`, `899-904` | renewal window end `height + period` (or `--for N`) | the founder's own delegation choice | the delegation is a Lean-admitted turn bounded by the founder's capability; Lean does not know what was paid. See D2. |
| M12 | `credit.rs:924-934` | heights left in my window | display only | |
| M13 | `job.rs:587-589` | `claimBy = now + deadline/2`, `answerBy = now + deadline` | caller's parameter choice | law clauses 13-14 (`law.job.shell:13-14`) require `now ≤ claimBy ≤ answerBy`. |
| M14 | `job.rs:781` | `finalAt = now + window` | MIRROR | law clauses 38-39 force `finalAt == now + WINDOW` exactly (`law.job.shell:38-39`). |
| M15 | `job.rs:804`, `815`, `847` (`check`) | stall: `clock > answerBy`; timeout: `clock > finalAt`; verdict `truth == output ? upheld : slashed` | MIRROR | law clauses 42-44 (`law.job.shell:42-44`): 2→3 requires `truth == output` or (no truth and `finalAt < now`); 2→4 requires a truth ≠ output; 1→4 requires no truth and `answerBy < now`. The truth write itself requires `ran PROGRAM` (`law.job.shell:26`), re-executed by the kernel. |
| M16 | `job.rs:731-734` | fund amount defaults to the job's price field | MIRROR | law clause 18 (`law.job.shell:18`): fund only from escrow 0 to exactly `field 5`. |
| M17 | `market.rs:271-286` (`clear`) | the whole allocation: who gets how many units and the clearing price | **DECISION** | `law.market` only refuses a fill above a slot's revealed quantity and out-of-phase writes (`market.rs:13-19` says so: "the allocation itself is accountable, not judged"). |
| M18 | `clock.rs:151-156`, `262-271` | `now` = the clock subject's wall clock; catch-up clamps to `now + maxStepSeconds` | **ORACLE** under capability | `ClockTickReceiver` (`Host/Main.lean:7065-7087`; `clock.rs:14-15` cites `clock_monotone`): capability `C_tick`, monotone, step ≤ `maxStepSeconds`. Lean cannot know real time. |
| M19 | `checkpoint.rs:119-127` | certify only when `tail ≥ min-tail` | operator cadence policy | `CertifyReceiver.certified_advances` (cited `checkpoint.rs:9`); skipping only delays; the tail bound refuses writes past `L`. |
| M20 | `agent_reserve.rs:133-136`; `agent_lifetime_grant.rs:73-76`; `paid.rs:58-63`, `166-170` | `reserveIndex`/`grantIndex = acceptedCount - 1` | MIRROR | Lean finds the reserve by index in verified history and binds it to the context (`Kernel/ApplicationDispatchAgentPaidAuthoring.lean:264-273`); a wrong index is refused ("agent reserve absent from verified history"). It is a hint, but it encodes an unstated assumption that the reserve is the LAST accepted transition of its batch (section 8 Q11). |
| M21 | `pay.rs:1188`, `1618`, `1824` | attribution of `alreadyConsumed`: tick nullifier if `clock.slot == tip.slot`, else the record's | **DECISION** on attribution (not on credit) | Lean says only "a nullifier in this report was spent". Rust decides which one and then writes a receipt that stops the watcher re-reading the record. See flaw F5. |
| M22 | `pay.rs:880-883`, `907-909` | which book rows the watcher watches (`index < nextFree` + enrollment row); journal floor for the watcher | **DECISION** (scope of observation) | the pay-watcher permanently skips amounts below the floor it is given (`native/pay-watcher/README.md` "a permanent skip ... below the journal floor"); Lean's floor is in the tariff. See flaw F6. |

**Answer to the central test.** No Rust code in this shard computes a price, quote, refund amount or credit that is then submitted
and trusted. Quotes are Lean's (ops 121/182, `Host/PayClaims.lean:283-300`); the client copies `atomicAmount`/`amountAtomic`
verbatim into what it prints and signs (`join_solana.rs:636`, `pay_memo_v2.rs:515-521`); the credit a payment mints is Lean's
(`PayObservation.decideObservation`, `PayEnrolDecision.decideEnrol`, `Kernel/PayEnrolDecision.lean:286-287`); job money is moved
only by `JobMoneyReceiver` (`law.job.shell:48` requires `authority/operation/job-money == 1` for any escrow/bond change). The
Rust computations of money (M1-M3) are audit re-derivations that can only raise a false finding. The real Rust DECISIONS are
M17 (market allocation), M21 (nullifier attribution → receipts), M22 (watch scope and floor), and, outside this shard but driven
by `credit.rs`, the concierge's paid-membership decision (D2 below). M18 is an oracle by nature.

### 3.2 Decisions Rust owns that a Lean admission should own

**D1. Sealed-market allocation (`market.rs:271-286`, proposed by `settle`, `market.rs:476-504`).** The founder's runner computes
fills by price then slot and writes them with `expected "0"`; the market law refuses only a fill larger than the slot's revealed
quantity (`market.rs:13-15`). A founder (or a modified client) can fill a lower bid and skip a higher one, set any clearing price,
or fill its own slot first. Lean counterpart that should exist: an `allocate` predicate in the market law (or a Lean receiver
for `settle`) that re-runs the clearing on the revealed tuples, in `Kernel/SealedMarket.lean` (present in `Kernel/`; this reader
did not open it, section 8 Q14). Blast radius today: small, because no money moves (`DEPOSIT_UNAVAILABLE`, `market.rs:42`) and
fills are numbers in a cell; it becomes a theft vector the day deposits land.

**D2. Room-week membership for payment (the concierge, driven by `credit.rs`).** `credit.rs:1-13` says "Nothing here decides
admission", which is true of `credit.rs` itself, but the decision "this payer paid at least the week price quoted at height H,
within 64 heights, in the pinned asset, and is admitted ⇒ issue `member` until `max(entry.height, notAfter) + period`; otherwise
refund" is made in Rust by `native/grain-runtime/src/concierge.rs` (`decide`, `concierge.rs:147-180`, called at `:436`; ledger read at
`:374-377`, historical tariff at `:414`, refund at `:445`, issuance through `mini credit renew`), as written into the program
description by `credit.rs:619-624`. Lean admits only that the concierge holds `delegate` under R and `transfer` on the till
(`credit.rs:600-614`). Blast radius: a faulty or malicious concierge can keep payments and issue nothing, issue windows for free,
or refund the wrong amount; members have no Lean-enforced claim. Lean counterpart that should exist: a room-membership receiver
whose admission is "a `renew` publication on the till at height H with amount ≥ tariff.week@H mints a window", i.e. the same shape
as `PayEnrolDecision` for Book credit.

**D3. Nullifier attribution and receipts (`pay.rs:1188-1197`, `1221-1238`, `1618-1636`, `1824-1836`).** See flaw F5. Lean
counterpart: the observation receiver could name WHICH nullifier was spent (the tick's vs record k's) in its refusal, removing
the heuristic.

**D4. Observation scope (`pay.rs:861-917`, `2282-2289`).** See flaw F6. Lean counterpart: watch-config should be derived entirely
from the signed pay view: the tariff already carries `enrolIndex` and `journalFloor` (`Kernel/PayTariff.lean:18-21`).

**D5. Wall-clock time (`clock.rs:151-156`).** Inherent oracle. What Lean could add: a rate limit tying ticks to an independent
witness (e.g. the pay observer's finalized Solana `blockTime`, which the pay cell already carries), so that one compromised
clock key cannot move `now` arbitrarily far (flaw F12).

### 3.3 Places Rust correctly defers (selected, with evidence)

* Pay refusals: Rust acts only on reason names parsed from Lean's own `repr`, refusing anything else as unnamed
  (`pay.rs:318-363`, tests `pay.rs:2453-2528`).
* Self-enrollment outcome: Rust reads the decision back from the Host (enrollment view or op 181), never re-derives
  (`pay.rs:1474-1476` doc; `1484-1527`). The v1 memo key is read through the Host's codec (`memo_key`, `pay.rs:1382-1396`).
* v1 memo: printed only after the local Host's own codec reads back all four fields (`join_solana.rs:516-539`).
* v2 memo: Rust re-encodes and compares with Lean's `unsignedCanonical` and messages before signing (`pay_memo_v2.rs:491-500`).
* Quotes never computed: `join_solana.rs:312` and `353-358` ("Bounded native display, not a recomputation of any fee").
* Claim admission: `pay_claim.rs:760-761` ("the source remains responsible for price/admission"); `paid_context.rs:195-197`.
* Agent reserves: every plan is re-derived by the operator Host (`client_consent::operator_plan`, `agent_reserve.rs:494`,
  `lifetime_v3.rs:214-215`, `agent_lifetime_grant.rs:264-265`) and re-inspected before signing; the paid plan must equal a fresh
  op 48/78 selection byte-for-byte (`agent_payer.rs:125-128`, `paid.rs:343-354`, `463-474`).
* Metering: the charge is Lean's (op 19); Rust validates shape and provenance (`meter.rs:1-4`, `61-131`).
* Well, clock, certify, refill, job money: Rust authors via the Host, signs the Host-printed header, submits; the receivers decide.

### 3.4 Answers to the prompt's specific questions

**(1) Where does Rust compute money?** Section 3.1. Nowhere that is trusted; audit twins only; DECISIONS D1-D4 above.

**(2) The Solana path, end to end.**
1. The friend runs `mini join [--memo-version v2] --solana`. v1 prints a 400-byte `enrol:v1:...` memo bound to
   `mint ‖ enrolAddress ‖ sshBlob` (Mini signature) and `mint ‖ enrolAddress ‖ miniKey` (SSHSIG, namespace `dregg-enrol@v1`)
   (`join_solana.rs:113-120`); the amount is the Host quote's `atomicAmount` (op 121). v2 prints a 485-byte `enrol:v2:` memo whose
   signed frame binds deployment commitment, pricing commitment, identity, authorizing key, epoch, ssh key, NEXT, weeks, starter,
   expiry hour, amount, mint, token program and recipient (`pay_memo_v2.rs:87-145`), both signatures verified locally.
2. The friend pays from a wallet with the memo. No Rust in this repo submits a Solana transaction (`join_solana_v2.rs:1-2`,
   `520`; `join_solana.rs:15-16`).
3. The pay-watcher (another crate, run by `deploy/pay/mini-pay-watcher`) reads finalized transfers to the book addresses from
   several RPC endpoints, requires endpoint agreement, and emits `Observation` records with the memo as raw hex (never parsed,
   `native/pay-watcher/README.md` "The watcher never parses the memo").
4. `mini pay observe` (`pay.rs:1271`) submits the records under the observer's capability: ordinary rows in ONE report per tip
   (ops 108-110), enrollment-row records one per submission to ops 117-119 on the operator socket.
5. Lean decides: `PayObservation.decideObservation` (wrong mint/program/address/unassigned index/payer is issuer/zero
   amount/after tip, `Kernel/PayObservation.lean:198-205`), then Book credit `creditFor amount`; for the enrollment row,
   `PayEnrolDecision.decideEnrol` (v1: memo grammar, both signatures, price `birthFee + nodeWeekRate`, ssh/subject uniqueness,
   journal otherwise; `Kernel/PayEnrolDecision.lean:51`, `136`) or the v2 receiver (`Kernel/PayEnrolV2Receiver.lean`,
   `PayEnrolV2Decision.lean`, consumption or pending claim).
6. The friend runs `mini join --wait`, which reads the enrollment view (v1) or the exact op 181 status (v2) and builds the workspace.

**Who verifies the transaction?** Nobody cryptographically. The pay-watcher trusts the RPC endpoints (agreement across
`minEndpoints`); Lean trusts the observer's signature over the report (the observer capability is genesis-issued). Rust in this
shard only carries bytes. This is an oracle by design (PAY.md §3), and it is the single largest trust assumption in the money
path: a compromised observer key can mint `maxPerObservation * creditPerAtomic` per invented observation, bounded per record by
`creditFor_le_cap` (`Kernel/PayTariff.lean:108-111`).

**Replay / double spend of one transfer across two enrollments.** Prevented by Lean: the observation nullifier is
`"soltx:" ‖ signature(64) ‖ address(32)` (`Kernel/PayObservation.lean:162-167`), proved injective (`nullifier_binds_transfer`,
`:187-192`); the v2 claim id is the same byte string (`pay_status.rs:492-497`, `paid_context.rs:430-432`). Rust adds a second,
non-authoritative layer: the receipt symlink skip (`pay.rs:1291-1299`) and `alreadyConsumed` handling. Whether the
observation receiver, the self-enrollment receiver and the claim receiver share ONE nullifier space is asked in section 8 Q1.

**Memo parsing on untrusted bytes.** v1 memos are never parsed by Rust on the receiving side: `memo_key` hands the raw bytes to
the Host's `inspect pay-enrol-memo` (`pay.rs:1382-1396`). v2 memos ARE parsed by Rust on the receiving side, for routing only
(`v2_memo_identity`, `pay.rs:1401-1409`): hex decode, UTF-8 check, `SignedMemo::parse` which first checks length 485, ASCII, no
`=`, prefix (`pay_memo_v2.rs:602-608`), then decodes exactly 357 bytes and slices fixed widths after the length check
(`pay_memo_v2.rs:609-619`; the two `unwrap`s at `:617`/`:618` are unreachable after the 357 check). The parsed identity selects an
op 181 query; the comment correctly says it is "not signature verification or an admission decision" (`pay.rs:1398-1400`). The
watcher bounds memos at 566 bytes. No panic path found on watcher bytes.

**(3) pay_claim vs Lean receivers (181-186, 191).** Section 2.1 table: ops, bounds and field names agree; op 185 is not blind;
191 is reserved without a receiver on both sides. One gap: recovery after a Host upgrade (section 4 F13).

**(4) agent_reserve / lifetime_v3 / paid: which is wired, what differs, what to delete.** All three are wired to grain-runtime
(1.12 table). `agent_reserve.rs` (event21, ops 58/59, approval `minidregg-agent-reserve-approval-v1`) is the v2 purse reserve;
`lifetime_v3.rs` (event27-backed, ops 80/81, approval adds `context`, `bindings`, `canonicalHttpHex`, `lifetime_v3.rs:201-210`)
is the v3 reserve; the comment `lifetime_v3.rs:1-2` says the v2 format "remain[s] historical and cannot be reinterpreted".
`agent_payer.rs` signs payer slots for the event21 paid dispatch (op 48); `lifetime_v3/paid.rs` does plan + payer-only signing for
event26 (ops 78) AND carries seal/submit/lookup (79/76/77) that only the CLI and the 2026-09-27 evidence use
(`docs/evidence/2026-09-27-agent-lifetime-paid-client/README.md:3`); the live 79/76 path is spk-host
(`native/spk-host/src/agent_api_lifetime_paid_native_v3.rs:183`, `agent_api_lifetime_dispatch_native_v3.rs:167`). Delete:
`paid.rs` seal/submit/lookup (≈ `paid.rs:432-723` plus tests, ~400 lines) as a twin of spk-host; and, if the v2 event21 dispatch is
retired upstream, `agent_reserve.rs` plan/seal/submit/lookup and `agent_payer.rs`. Fold the three copies of the custody state
machine into one generic (section 5).

**(5) job.rs money and refunds.** Double refund: impossible at Lean level. SETTLE moves a job from 3/4/5 to 6 exactly once, with
escrow and bond zeroed (`law.job.shell:6`, `18-19`, `46-47`), and only the job-money receiver may change escrow/bond
(`law.job.shell:48`). A second settle plan on a closed job is refused at op 160. Lost refund: the settle path retains the
ingress and per-send markers (`job.rs:372-399`); the next `settle` resolves every retained send that is not definitively refused by
op 163 lookup, and resubmits the SAME bytes only on `absent` (`job.rs:487-498`); journey `journey.d/job-refund-recovery.py` checks
"no second refund; closed native job" (`job-refund-recovery.py:92-99`) on a fixture whose missing confirmation is simulated by
moving outcome records (`:7-9`). Gaps: `fund` and `claim` have no recovery path (fresh directories `job.rs:681`, `736`), but Lean
refuses a second fund/claim (law clauses 18-21), so the worst case is a confusing error, not a double debit. The job state value
from a signed read indexes a 7-element array without a bound (`job.rs:771`, flaw F17).

**(6) clock.rs / checkpoint.rs.** Time is advanced by the clock subject's oneshot (`deploy/clock/mini-clock-tick.service`, every
minute, `mini clock --action tick`). A tick is a Lean-admitted transition (ops 126-128; capability `C_tick`, monotone, bounded step)
whose VALUE is a Rust wall-clock reading (oracle). The pay observer separately advances the pay clock SLOT with each accepted report
(`pay.rs:1316-1320` comment; `heartbeat`, `pay.rs:2327-2335`). Checkpoint certification is a Lean-admitted transition under the
factory control capability; the cadence (`--min-tail`) is the operator's.

**(7) market.rs, well.rs, meter.rs: wired or dead?** All wired. market: `workspace.rs:7038-7076`, journey JMKT
(`journey.sh:1025`). well: `main.rs:3266`, journey KW (`journey.sh:1042`), objective acceptances
(`objective-bounty-native-acceptance.py`, `objective-seat-native-acceptance.py`). meter: `main.rs:3492-3511`, called by
`native/grain-runtime/src/main.rs:10125`.

---
## 4. Flaws noticed

Ordered by severity. Each has the exact line, a concrete failure scenario, and whether Lean contains it.

### F1 (high). `mini well mint|burn|floor`: an uncertain submission is reported as a refusal, and there is no lookup, so the natural retry is a second mint

* `Host/Main.lean:7055-7063`: op 125 returns `(125, outcome)` only for `.confirmed`; EVERY other outcome, including
  `uncertain`/`unavailable`/`contention`, is returned as `(255, publicSubmissionOutcome outcome)` (the non-refused ones pass
  through `publicSubmissionOutcome` unchanged, `Kernel/NativeHost.lean:3142-3145`).
* `well.rs:78-85` maps any 255 to `Err("host refused ...; encoded refusal: HEX")`, and `well.rs:168-175` writes `refusal.txt` and exits
  with that error. The registry has no well lookup op (only 123/124/125, `protocol/host-operations.json`).
* `well.rs:104-111`: the next run defaults to a NEW attempt directory with a NEW nonce (`well.rs:119-120`).
* Scenario: the referee mints 1,000 to an account; the Host commits but the write path answers `uncertain` (or the socket drops
  after commit, which `session_invoke` surfaces as an error, `well.rs:77`). The CLI says "host refused". The referee runs the
  same command again; the fresh nonce makes it a distinct command; Lean admits it; 2,000 minted.
* Lean containment: none (two distinct signed commands). Fix: a well lookup op (exact retained ingress, receipt-only), a durable
  submit marker before op 125, and decoding the 255 body's outcome type before calling it a refusal.
* Secondary: well attempt files are created world-readable (`create_public`, `well.rs:63-65`; `fs::create_dir_all`, `well.rs:112`).

### F2 (high). `mini credit pay | topup | refund`: a crash after submit, followed by a rerun, is a second payment

* `credit.rs:779-786` (`pay`), `credit.rs:813` (`topup`), `credit.rs:975-976` (`refund`) call `fleet::pay_turn` with no operation
  record (`fleet.rs:889-898` → `turn(...)`). Inside one process the fleet attempt resolves a transport error by exact lookup
  (`fleet.rs:566-586`), but if the PROCESS dies after the submit marker (`fleet.rs:559-562`), nothing ever looks that attempt up again:
  a rerun of `mini credit pay` authors a fresh draft with a fresh nonce (`fleet.rs:489-495`) and pays again.
* `turn` and `return` in the same module accept `--operation-record` and recover by exact lookup (`credit.rs:830`, `846`, `858`,
  `864-869`); `pay`, `topup` and `refund` do not.
* Scenario: a member runs `credit pay lab` from the shell, the laptop sleeps or the SSH proxy drops after the submit; the shell
  shows an error; the member pays again. Both payments are admitted (distinct nonces); the concierge issues one window for the first
  and either extends the window or refunds the second depending on its rules (`concierge.rs:178-179`), which is Rust's choice (D2).
  For `refund`, the concierge guards itself by reading the till's `refund` topic before refunding (`concierge.rs:396-409`); a
  human operator running `credit refund` directly has no such guard.
* Repo law violated: README "a lost reply keeps the original operation and its exact retry rather than licensing a second one".
  Fix: route every money verb through `pay_turn_recorded` with a mandatory operation record (as `turn` does).

### F3 (medium, real bug). `agent-lifetime-paid-lookup` after a successful `agent-lifetime-paid-submit` always fails

* `paid.rs:645-647`: submit retains `receipt.json` = `four_fields(dispatchReceipt)` (exactly four keys, `paid.rs:556-567`).
* `paid.rs:710-717`: lookup computes `exact_receipt(&outcome)` from `agent_reserve.rs:111-138`, which inserts a FIFTH key
  `reserveIndex` (`agent_reserve.rs:133-136`), then requires equality with the retained 4-key receipt ⇒
  "lifetime paid historical receipt differs from original".
* Only the lost-reply path (no `receipt.json` yet) works. The test `lost_paid_submit_reply_never_reissues_and_lookups_are_numbered`
  (`paid.rs:752-781`) exercises markers only, never the receipt comparison. The live 76/77 path is spk-host's (Q4 above), which is
  why nobody noticed; this is another reason to delete the twin.

### F4 (medium). Nullifier-attribution heuristic can write a false "already credited" receipt (lost credit)

* `build_report` reads the pay view BEFORE preparing and submitting (`pay.rs:1053-1062`). On `alreadyConsumed`, the report path
  decides "the tick nullifier was spent" only if THAT pre-submit view had `clock.slot == tip.slot` (`pay.rs:1824-1828`); otherwise a
  one-record report is settled as the record's own nullifier (`pay.rs:1830-1836` → `settle_one`, `pay.rs:1229-1238`), which writes
  the receipt symlink. The same holds for a single enrollment record (`pay.rs:1597`, `1626-1636`).
* Scenario: between the view read and op 110, another report at the same tip commits (a manual `mini pay heartbeat`, a second
  observer process, or an operator re-run while the timer tick is in flight: the wrapper's `flock` covers only wrapper ticks,
  `deploy/pay/mini-pay-watcher:63`). The second report's tick nullifier is the one spent; Rust attributes it to the record, writes
  `pay/receipts/SIG.ADDR`, prints `already-credited`, and the watcher never emits the record again (`pay.rs:1291-1299`; watcher
  README "The only memory it has is the receipts directory"). The payment is never credited and nothing is quarantined.
* Multi-record reports are safe: `probe` re-reads the view per one-record report (`pay.rs:1181`), so it would see the advanced clock.
* Lean containment: none for the client-side receipt; the transfer remains creditable if someone deletes the symlink. Fix: have
  Lean name the spent nullifier, or re-read the view after the refusal before attributing.

### F5 (medium). Watch scope and journal floor come from operator flags, not from the signed tariff

* `pay.rs:2282-2289` takes `--enrol-index` and `--journal-floor` from the command line; `watch_config` writes them into the watcher
  config (`pay.rs:874-889`, `907-909`) without comparing them to the view's `tariff.enrolIndex` / `tariff.journalFloor`, although
  `enrol_index_of` (`pay.rs:1361-1369`) reads the tariff's index elsewhere. The deploy wrapper passes them from env
  (`PAY_ENROL_INDEX PAY_JOURNAL_FLOOR`, `deploy/pay/mini-pay-watcher:38`), rendered once by `render-enrol` (`render-enrol:178`).
* The watcher treats "amount below the journal floor" as a permanent skip and advances the cursor past it (watcher README, cursor rule).
* Scenario: the tariff's floor is lowered on-chain-side (a new `pay book`) but `watcher.env` is not re-rendered; payments between the
  two floors are recorded once as `belowJournalFloor` in `events.json` and never reach Lean, so neither credit nor journal row. A
  mistyped `PAY_ENROL_INDEX` watches the wrong row.
* Fix: derive both from the signed view (`view.tariff`), refuse a mismatch loudly.

### F6 (medium). The clock: one stuck attempt stops time; one compromised clock key moves time without bound

* `clock.rs:227-244`: every run first resubmits every retained attempt; if any resubmission returns a non-definite outcome or ERRORS
  (a 255 frame from a Host exception, or a transport error, both surfacing from `invoke`, `clock.rs:94-96`, `202-207`),
  `resolve_pending` returns `Err` and the tick never happens. Nothing removes a poisoned attempt except an operator. While stuck,
  `clock/now` freezes: laws over `clock/now` (job windows, leases measured in clock hours) stop moving. Loud (systemd unit fails each
  minute), but a liveness hazard on a single VM.
* `clock.rs:372-390`: the catch-up loop has no iteration cap. With a confirmed but non-advancing tick it would spin until
  `TimeoutStartSec=50` (`deploy/clock/mini-clock-tick.service`); the deploy comment says the Host refuses non-advancing ticks
  (section 8 Q8 asks for the declaration).
* Blast radius of the clock key: each tick may advance `maxStepSeconds`; the catch-up loop issues ticks back-to-back with no real-time
  pacing, so a holder of the clock key (scope: tick only, per the unit's comment) can move `now` arbitrarily far in seconds. Effects:
  job stalls and timeouts become decidable early (`law.job.shell:42`, `44`: an answered job past `finalAt` is upheld without a truth,
  paying the provider; a claimed job past `answerBy` slashes the bond), and every `clock/now` law opens. The pay-side lease clock is
  the processing-chain hour from observer evidence (`PAID-COLD-ENTRY.md`), so memberships are not directly affected.

### F7 (medium). `pay-claim` lookup cannot survive a Host upgrade

* `pay_claim.rs:144-152`: every local inspection (and therefore every recovery) requires the ORIGINAL Host image digest and config
  bytes; `paid_context::retained_lookup` refuses if `hostSha256` in the binding differs (`paid_context.rs:530-536`).
* The carry adapter that would bridge an upgrade is op 191, reserved without a receiver (`protocol/HOST-OPERATIONS.md:76-79`).
* Scenario: accept submitted, reply lost, operator upgrades the Host. The member's `pay-claim --action lookup` refuses
  ("claim requires its original pinned local Host inspector") unless the old Host binary is still at the same path. Fail-closed
  (no double consumption: the origin is consumed once), but the member cannot learn the outcome.

### F8 (low-medium). Dead stale-root retry on blind op 105, and the reason is invisible to the user

* `pay.rs:685-694` (`pay address`) and `pay.rs:821-830` (`pay book`) retry once on `stalePay | staleAuthority | indexNotNext |
  bookIndexPresent`. Op 105 is blind: all refusals become `refused undisclosed "admission"` (`Host/Main.lean:6923-6930`), and
  `answer()` maps that to reason `undisclosed` (`pay.rs:385-387`). The branches can never match. Effect: a race on `nextFree` (two
  members asking for addresses at once) ends in "pay address refused undisclosed (phase admission)", exit 3, with no hint that a
  rerun will succeed. Delete the branches; document "rerun" or give the assigner a non-blind plan-time staleness check.

### F9 (low). Silent truncation and unchecked arithmetic

* `pay.rs:904`, `908`, `2332`: `value as u64` on CLI-provided `u128` (watcher bounds, enrollment index/floor, heartbeat slot and
  block time) silently wraps above 2^64.
* `pay.rs:1871-1872`, `2045-2047`, `2082-2084`: unchecked `u128` multiply/add in the audit; release builds wrap (root `Cargo.toml`
  has no `[profile]` enabling `overflow-checks`). The v2 audit path uses `checked_add` (`pay.rs:2105-2112`); the v1 path does not.

### F10 (low). `pay-claim` recovery never resubmits an `absent` ingress

`recover` sends only op 186 (`pay_claim.rs:580`). If the original op 185 never reached the Host (request lost, not reply), the
operation is lookup-only forever and `absent` is printed (`Decision::Absent`, `pay_claim.rs:434`); the member must build a new
operation with a new nonce. Safe (no double), documented ("An absent or uncertain reply is not confirmation",
`PAID-COLD-ENTRY.md`), but inconsistent with `job.rs:493-494`, which resubmits the same bytes on `absent`.

### F11 (low). Local-file panics and UX traps in v1 join

* `join_solana.rs:681-682`: `renew` slices the retained memo string at fixed byte offsets BEFORE any length/ASCII check; a truncated
  or hand-edited `join.json` panics (`&text[143..271]`, `&text[272..]`).
* `join_solana.rs:543-549`: `solana` creates the join directory first and refuses an existing one; any failure afterwards (quote
  endpoint down, `ssh-keygen` missing) leaves a directory the next run refuses; the friend must delete it, including a freshly
  generated Mini key (`join_solana.rs:557-559`). v2 fixed this with resumable `preparation.json` (`join_solana_v2.rs:727-750`).
* `join_solana.rs:78-97`: `b64_decode` ignores trailing pad bits and any trailing `=` run (non-canonical base64 accepted for ssh
  key lines and SSHSIG armour). Not exploitable here (blobs are checked field by field and signatures verified), but v2 had to add
  `check_armour` (`pay_memo_v2.rs:630-650`) to refuse it.
* Generated SSH identities have no passphrase (`-N ""`, `join_solana.rs:574-584`, `join_solana_v2.rs:776-786`); the proxy key that
  reaches the box is unencrypted at rest on the member's disk.

### F12 (low). Panics on signed-read values

* `job.rs:771`: `STATES[get(&f, STATE)? as usize]`: a state outside 0..=6, or negative (`i128 as usize`), panics. The job law
  restricts writes of field 0 to {0..6} (`law.job.shell:5`), but `record` accepts any referenced cell as a job
  (`job.rs:204-207`).
* `market.rs:454-455`: `close - 1`, `reveal_end - 1` on cell values: a cell holding 0 underflows (panic in debug, wrap in release).
* `job.rs:563`: `&random_nonce()?[..8]` assumes ≥ 8 characters (a decimal u128 string; practically always true).

### F13 (low). Unbounded reads of local files

`fs::read` without a size bound on local, user-owned files: `pay.rs:455`, `487`, `519`, `1950`; `well.rs:137`, `151`;
`job.rs:65`; `clock.rs:60-63` and `checkpoint.rs:36-39` (read the whole file, then check 64 KiB); `join_solana.rs:593`,
`719`; `join_solana_v2.rs:503`, `536`. Network inputs ARE bounded: watcher file 16 MiB (`pay.rs:2205-2210`), op 181 ≤ 8192
(`pay.rs:1463`, `1933`), HTTPS replies 5 s and 8/16/256 KiB (`join_solana_v2.rs:192`, `pay_claim.rs:196`, `join_solana.rs:485`),
claim wire ≤ 16 KiB (`pay_claim.rs:50-52`), audit rows ≤ 8193 bytes (`pay.rs:1908`).

### F14 (low). Smaller correctness notes

* `pay.rs:1312-1316`: `--hold true` builds a report of the ordinary records only; enrollment-row records are dropped from the run
  without an `enrol-pending` line.
* `pay.rs:121-124`: `pay audit --offline true` still requires a pinned session socket it never uses.
* `pay.rs:543-549`: a corrupt `decision.json` reads as "no decision", so the attempt is looked up again (safe: lookup only).
* `credit.rs:946-949`, `957-960`: balance read errors are swallowed into display text (status only).
* `paid_onboarding.rs:83`, `161`: hashes a JSON journal with `host_image_sha256`, a function whose name and remote-mode behaviour
  (`main.rs:494-501` returns a pinned SHA for an empty path) are Host-specific; works for a real path, misleading to readers.

### F15 (informational). Key handling

Keys are read from private files per use (`read_secret`, `fsio::read_secret_in_private_dir`), never placed in argv or env; the
Ed25519 dependency has `zeroize` enabled (`Cargo.toml:18`). `approve_slot` refuses a key whose public half differs from the approval
(`agent_reserve.rs:320-323`); `pay_claim` refuses a key that is not the command's authorizing/successor key (`pay_claim.rs:968-976`);
`pay_memo_v2::sign_and_assemble` refuses a different Mini key (`pay_memo_v2.rs:659-663`). No key material is logged.

---
## 5. Unwired / undone

### 5.1 Reachability of every module

| module | binary arm | journey hooks (`native/resource-client/journey.sh`) | deploy unit | recorded run |
|---|---|---|---|---|
| `pay.rs` | `main.rs:3267` | JPAY2 (`:1066`), JPAY3 (`:1047`), JPAYE2 (`:1049`), JPAYE3 (`:1050`), JPAY4 (`:1051`); not in STEPS: `jpay-e4.sh`, `jpay-v2.sh` | `deploy/pay/mini-pay-watcher.{service,timer}` (wrapper calls `mini pay watch-config` and `mini pay observe`) | `deploy/pay/README.md` "current composed rehearsal 2026-10-02" (outside `docs/evidence`); README.md:94 "executed (fixtures)" |
| `pay_refill.rs` | via `pay.rs:2242-2244` | JPAY6 (`:1052`, needs hbox env) | none | none found in `docs/evidence` |
| `pay_claim.rs` | `main.rs:3269` | none in STEPS (`jpay-v2.sh`, `jpay-claim-law-tests.sh` use it) | none | none in `docs/evidence` |
| `pay_memo_v2.rs`, `pay_status.rs`, `paid_context.rs`, `paid_onboarding.rs` | via v2 join, pay, pay-claim (and `enrollment_bootstrap.rs` for `pay_status`) | none in STEPS | none | none |
| `join_solana.rs` (v1) | `main.rs:3200` | none in STEPS (`jpay-e4.sh` is v1) | none | none in `docs/evidence` |
| `join_solana_v2.rs` | `main.rs:3198` | none in STEPS (`jpay-v2.sh`, `paid-entry-adapter.py`) | none | `PAID-COLD-ENTRY.md` cites `/home/ember/build/pay-bootstrap-budget-6075-{8,9}/` on another machine |
| `credit.rs` | `main.rs:3262`; shell verbs (`shell.rs:100`, `1787-1838`); `hermes.rs:618-793`; grain-runtime concierge | J17 (`:1031`), J14 (`:1029`) | none of its own (concierge runs under grain-runtime) | `docs/evidence/2026-10-01-p-credit/` (J17 rows) |
| `market.rs` | `workspace.rs:7038-7076` | JMKT (`:1025`) | none | none found |
| `meter.rs` | `main.rs:3492-3511` | via grain-runtime journeys (J14) | none | none specific |
| `agent_reserve.rs`, `agent_payer.rs` | `main.rs:3869-3905`, `4052-4072` | none in resource-client STEPS; grain-runtime tests (`dispatch_runtime_tests.rs`) | none | `docs/evidence/2026-09-27-agent-payer-client/`, `2026-09-27-agent-participant-payer-split/` |
| `lifetime_v3.rs` | `main.rs:3906-3942` | none in STEPS | none | `docs/evidence/2026-09-27-spk-lifetime-paid-native/` (by name) |
| `lifetime_v3/paid.rs` | `main.rs:3943-3976` | none | none | `docs/evidence/2026-09-27-agent-lifetime-paid-client{,-linux}/`, `2026-09-27-agent-lifetime-paid-ingress/`, `2026-09-27-agent-lifetime-payer-only/` |
| `agent_lifetime_grant.rs` | `main.rs:3977-4005` | none | `scripts/spk-platform/issue-agent-lifetime-grant.sh:202,230` | none specific |
| `job.rs` | `main.rs:3221` | JJOB1 (`:1058`), JJOB (`:1059`), JJOBM (`:1053`/`:1060`); not in STEPS: `job-refund-recovery.py`, `job-refund-legacy-recovery.py` | none | none found |
| `well.rs` | `main.rs:3266` | KW (`:1042`) | none | none found |
| `clock.rs` | `main.rs:3218` | KC (`:1002`); used by jpay2/3/4, jjob1 | `deploy/clock/mini-clock-tick.{service,timer}` | `docs/evidence/2026-10-05-clock-law/` |
| `checkpoint.rs` | `main.rs:3219` | KT (`:1000`, `journey.d/jtail.sh`) | `deploy/checkpoint/mini-checkpoint-certify.{service,timer}` | none specific |

Duplicate step names: `JJOBM` is defined twice in `journey.sh` (`:1053` and `:1060`, the second wins in bash), and titled twice
(`:249`, `:274`).

### 5.2 TODO / FIXME / unimplemented / dead_code

None of `TODO`, `FIXME`, `XXX`, `unimplemented!`, `todo!`, `#[allow(dead_code)]` appears in non-test code of the 21 files. The
non-test `unwrap`/`expect`/`unreachable!` sites are all guarded: `pay_memo_v2.rs:114`, `617-618` (after exact length checks),
`pay.rs:1437` (after `coordinates()` returned `Some`), `join_solana.rs:147` (`get(..4)` succeeded), `:234` (length 51 checked),
`:753` (object literal), `:931` (`bootstrap.is_none()` implies the socket check at `:906`).

### 5.3 Dead code

| site | why it is dead |
|---|---|
| `pay.rs:685-694` | retry on named reasons after op 105; op 105 refusals are always `undisclosed` (F8) |
| `pay.rs:821-830` | same, for `pay book` |
| `join_solana.rs:457`, `1031`, `1040`, `1080-1082` | `Common.view` is parsed and then always refused ("--view cannot quote receiver fees"); the module doc still advertises `--view` (`join_solana.rs:3`, `7`) |
| `join_solana.rs:20-22` (doc) | "`--renew` prints the same memo again with one node week's amount": the amount is now the source quote for `--weeks N` |
| `credit.rs:1-13` (doc) | "Nothing here decides admission" is true of the file and misleading about the system: the payment-for-membership decision is the Rust concierge's (D2) |
| `paid.rs:432-723` | `agent-lifetime-paid-seal/submit/lookup`: no caller in scripts, deploy, grain-runtime; the live op 79/76 path is spk-host (`native/spk-host/src/agent_api_lifetime_paid_native_v3.rs:183`, `agent_api_lifetime_dispatch_native_v3.rs:167`); also broken (F3) |
| `agent_lifetime_grant.rs:39-57` (`preceding`) | re-implements `mini_sdk::decimal::predecessor`, which `agent_reserve.rs:140-143` already uses |

### 5.4 Twins (the repo law: delete the twin)

1. **Lifetime paid dispatch custody**: `agent_reserve/lifetime_v3/paid.rs` (plan op 78 ✓ used; seal op 79, submit op 76, lookup op
   77 unused) vs `native/spk-host/src/agent_api_lifetime_paid_native_v3.rs:147` (op 78), `:183` (op 79),
   `native/spk-host/src/agent_api_lifetime_dispatch_native_v3.rs:167` (op 76). Keep spk-host's for 79/76; delete `paid.rs:432-723`.
2. **One custody state machine, three copies**: `agent_reserve.rs:145-660`, `lifetime_v3.rs:25-432`, `agent_lifetime_grant.rs:80-484`
   each define their own `Pin`, `pin`/`pinned`, `same_pin`, `sealed`, `outcome`, `send_once`/`submit`, `lookup_once`/`lookup` and
   receipt projection, differing in op numbers, format strings, which socket submits, and two approval fields. ~1,300 lines that
   one parameterised implementation (ops, formats, approval comparator) would replace.
3. **Receipt projection, four copies**: `agent_reserve.rs:111-138` (+`reserveIndex`), `agent_lifetime_grant.rs:59-78`
   (+`grantIndex`), `paid.rs:25-39` (`receipt`, 4 fields), `paid.rs:556-567` (`four_fields`). Their disagreement is bug F3.
4. **creditFor**: `pay.rs:1859-1875` vs `Kernel/PayTariff.lean:105-106` (audit re-derivation). Lean already exposes the ledger and a
   full re-admission audit (`pay-claim-audit`, `Host/PayClaims.lean:204-210`); the v1 report/enrol credit sum could come from the Host.
5. **Journal reason code table**: `pay_status.rs:409-413` vs `Kernel/PayEnrolMemo.lean:495-499` (a range check, low risk).
6. **v2 memo codec**: `pay_memo_v2.rs:87-134` vs `Kernel/PayEnrolMemoV2.lean:124-136`. Defensible as a signing-side check (the quote
   carries Lean's `unsignedCanonical`, compared at `pay_memo_v2.rs:491-495`), but the Rust side could sign Lean's bytes directly
   and keep only the decode-and-compare.
7. **Host-call boilerplate**: `with_kind`/`author`/`inspect`/`pair`/`reply`/`invoke` re-typed in `job.rs:79-112`, `clock.rs:83-121`,
   `checkpoint.rs:59-97`, `pay_refill.rs:13-52`, `well.rs:52-86`; `frame_body`/`text`/`number`/`field`/`fixed` in `pay.rs:213-269`,
   `pay_claim.rs:315-383`, `join_solana.rs:274-310`, `join_solana_v2.rs:14-57`, `paid_context.rs:50-90`, `pay_memo_v2.rs:256-299`.
8. **v1 vs v2 paid entry**: not byte twins (different memos, receivers, records), but two live implementations of one product
   ("pay to enrol"). v2 is the superset (quote-bound, NEXT commitment, pending-claim recovery, resumable preparation). Keep v2; delete
   the v1 flows (`join_solana.rs` `Terms`/`terms`/`quoted_terms`/`print_quote`/`solana`/`renew`/`wait`/v1 bootstrap, ≈ lines 239-702
   and 886-1088, plus v1-only tests), after moving the shared helpers (`b64_*`, `ssh_blob`, SSHSIG parse, `ssh_public_key`,
   `run_ssh_keygen`, `admitted_workspace`) into a small module. The Lean v1 receiver (`PayEnrolReceiver`/`PayEnrolDecision`) is the
   Lean reader's decision; the pay-observe v1 branch (`pay.rs:1487-1526`) goes with it.

### 5.5 Versioned siblings still present

`join_solana` (v1) + `join_solana_v2`; `agent_reserve` (event21 v2 format) + `lifetime_v3` (event27 v3), the comment at
`lifetime_v3.rs:1-2` stating v2 attempts "remain historical"; `pay_memo_v2` (no v1 module, v1 memo lives in `join_solana.rs`);
decision/record format strings `minidregg-join-solana-v1`/`-v2`, `minidregg-enrol-pin-v1`/`-v2`, `enrollment-bootstrap-v1`/`-v2`.

### 5.6 Tests that do not test (or test only fixtures)

* `agent_reserve.rs:698-710`: lines 704-705 compare the test's own JSON fields with each other and `assert_ne!` an unrelated digest;
  only the final `approve_slot` refusal exercises code.
* `well.rs:249-255` (`decimal_names_are_ids`) tests `mini_sdk::decimal`, not `well.rs`.
* `pay_memo_v2.rs:1001-1163`: ~160 lines decoding four fixture Solana packets with a test-local parser; it checks transaction sizing
  facts about the fixtures, not any production function (only `MEMO_LENGTH`).
* `credit.rs:1057-1073` (`members_never_mutate_or_delegate`, `a_founder_sets_prices_not_accounts`): constant-table assertions.
* `paid.rs:752-781`, `lifetime_v3.rs:440-491`, `agent_lifetime_grant.rs:492-543`: marker-only tests with closures standing in for the
  Host; they never compare receipts, which is how F3 survived.
* `join_solana.rs:1128-1162`: a "Host" that is a text file; the test proves refusal paths only (stated in its comment `:1131-1133`).
* No test anywhere covers `well.rs` command flow, `clock.rs`, `checkpoint.rs` or `pay_refill.rs` (zero `#[test]` in the latter three).

---

## 6. Size and shape

### 6.1 Lines per file (`wc -l`; test region = from the first `#[cfg(test)]` to end of file)

| file | total | tests | code | `#[test]` count |
|---|---:|---:|---:|---:|
| `pay.rs` | 2,560 | 213 | 2,347 | 11 |
| `pay_claim.rs` | 1,798 | 806 | 992 | 15 |
| `join_solana_v2.rs` | 1,445 | 453 | 992 | 6 |
| `join_solana.rs` | 1,278 | 189 | 1,089 | 9 |
| `pay_memo_v2.rs` | 1,164 | 477 | 687 | 8 |
| `job.rs` | 1,123 | 153 | 970 | 6 |
| `credit.rs` | 1,083 | 78 | 1,005 | 6 |
| `paid.rs` (`agent_reserve/lifetime_v3/paid.rs`) | 852 | 128 | 724 | 5 |
| `agent_reserve.rs` | 803 | 142 | 661 | 4 |
| `paid_context.rs` | 788 | 247 | 541 | 4 |
| `pay_status.rs` | 773 | 174 | 599 | 4 |
| `market.rs` | 629 | 114 | 515 | 7 |
| `agent_lifetime_grant.rs` | 592 | 107 | 485 | 3 |
| `lifetime_v3.rs` (`agent_reserve/lifetime_v3.rs`) | 526 | 93 | 433 | 2 |
| `clock.rs` | 401 | 0 | 401 | 0 |
| `well.rs` | 256 | 17 | 239 | 2 |
| `meter.rs` | 253 | 56 | 197 | 2 |
| `agent_payer.rs` | 242 | 40 | 202 | 2 |
| `paid_onboarding.rs` | 218 | 54 | 164 | 3 |
| `checkpoint.rs` | 182 | 0 | 182 | 0 |
| `pay_refill.rs` | 155 | 0 | 155 | 0 |
| **total** | **17,121** | **3,741** | **13,380** | **99** |

(`pay_status.rs` has two `#[cfg(test)]` items: the shared `fixture` fn at `:600` and the test module at `:615`.)

### 6.2 Shape observations

* Roughly a third of the code is custody ceremony (retain, pin, re-hash, re-inspect, compare) rather than protocol: e.g.
  `agent_reserve.rs`, `lifetime_v3.rs`, `agent_lifetime_grant.rs` together are 1,579 code lines for four Host round trips each.
* `agent_reserve.rs` doubles as a general utility module (`field`, `bounded`, `private_bytes`, `retain_json`, `source`,
  `source_inspect`, `digest`) imported by `job.rs:27`, `clock.rs:34`, `checkpoint.rs:23` and at least seven modules outside the
  shard (section 1.12). Deleting agent code requires moving these first.
* The pay rail is ~4,700 code lines across `pay.rs`, `pay_claim.rs`, `pay_memo_v2.rs`, `pay_status.rs`, `paid_context.rs`,
  `paid_onboarding.rs`, plus ~2,080 for the two join flows.

### 6.3 Minimal versions

**(A) Demo without payments** (the README's deployed candidate has no pay-to-enrol and the pay watcher is inactive, README.md:94).
Keep: `clock.rs` (401: the deployment clock unit), `checkpoint.rs` (182: without certification the node stops accepting writes after
`L` records, `deploy/checkpoint/mini-checkpoint-certify.service` comment), `credit.rs` (1,083: rooms, the shell's `credit` verb and
`room_declared_fields`, Hermes), `meter.rs` (253, only if Hermes with a provider is on). Kept: 1,919 lines.
Drop: `pay.rs` 2,560, `pay_claim.rs` 1,798, `pay_memo_v2.rs` 1,164, `pay_status.rs` 773, `pay_refill.rs` 155, `join_solana.rs`
1,278, `join_solana_v2.rs` 1,445, `paid_context.rs` 788, `paid_onboarding.rs` 218, `market.rs` 629, `well.rs` 256, `job.rs` 1,123,
`agent_payer.rs` 242, `agent_reserve.rs` 803, `lifetime_v3.rs` 526, `paid.rs` 852, `agent_lifetime_grant.rs` 592.
**Removed: 15,202 lines.** Preconditions: move the `agent_reserve.rs` helpers (~80 lines) into `fsio`; `enrollment_bootstrap.rs`
(outside the shard) imports `pay_status` and must go with it; grain-runtime's agent dispatch and the job/well/market journeys go
dark (JJOB*, KW, JMKT, JPAY*).

**(B) Demo with pay-to-enrol, v2 only.** Keep the v2 path: `pay.rs` (observe, address, book, watch-config, status; the v1 enrol
branch `pay.rs:1487-1526` can go), `pay_memo_v2.rs`, `pay_status.rs`, `join_solana_v2.rs`, shared helpers out of `join_solana.rs`
(~350 lines), `paid_context.rs`, `paid_onboarding.rs`, `pay_claim.rs`, plus everything in (A).
Drop: `market.rs` 629, `well.rs` 256, `job.rs` 1,123 (if the COMPUTE floor is not in the demo), `pay_refill.rs` 155, `paid.rs`
seal/submit/lookup ~400, v1 join flows ~900 (estimate: `join_solana.rs` 1,278 minus ~350 shared helpers and tests kept),
`pay_memo_v2.rs:1001-1163` packet fixture 163. **Removed: ≈ 3,600 lines (estimate).** If the event21 agent path is retired upstream,
another ~1,700 (`agent_reserve.rs` reserve flow + `agent_payer.rs`).

---
## 7. Deployability on a small public Linux VM

### 7.1 What must exist on the box (per feature)

| feature | binaries | users / dirs | sockets | units | operator-configured |
|---|---|---|---|---|---|
| clock | `/usr/local/bin/mini`, Host | user `mini`; `/var/lib/mini/clock` (0700) with `workspace.json`, `clock.key` (0600), `clock-attempts/`, `clock-journal.tsv` | the PUBLIC socket (connect only) | `mini-clock-tick.{service,timer}` (1/min, `ProtectSystem=strict`, `ReadWritePaths=/var/lib/mini/clock`) | genesis `.clock.subject`, `.clock.tickCapabilityId`, `.clock.genesisNow`, `.clock.maxStepSeconds`; `mini clock --action init` once |
| checkpoint | `mini`, Host | the operator's home, `%h/mini/operator-workspace` | public socket | `mini-checkpoint-certify.{service,timer}` (USER units) | `MINI_CHECKPOINT_CONTROL=53` (factory control capability), `MINI_CHECKPOINT_MIN_TAIL` |
| pay watcher + observe | `/opt/mini/bin/{mini,pay-watcher}`, Host, `/usr/bin/curl`, `jq`, `flock` | user `mini`; `/var/lib/mini/pay` (StateDirectory 0700); observer workspace | public socket; OPERATOR socket for 117-120 | `mini-pay-watcher.{service,timer}` (`MemoryMax=512M`) | `/etc/mini/pay/watcher.env` (observer workspace, capability, `PAY_ENROL_INDEX`, `PAY_JOURNAL_FLOOR`, `PAY_ENROL_CAPABILITY`, `PAY_OPERATOR_SOCKET`), `/etc/mini/pay/rpc.env` (RPC endpoints); `observer.key`; the tariff and book installed with `mini pay book` |
| paid entry HTTP | `mini enrollment-bootstrap` (outside shard) | — | public socket | infra unit (not in this repo's `deploy/`) | metadata JSON, `enrol-v2.json` published to friends, reverse proxy |
| rooms / credit | `mini`, grain-runtime concierge | per-room workspaces | public socket | concierge under grain-runtime | room tariff fields set by founders |
| agent reserves | `mini`, grain-runtime / spk-host | operator custody dirs | OPERATOR socket (private; `private_socket` check, `agent_reserve.rs:25`, `230`) | grain/spk units (outside shard) | approval JSONs, purse key files |

Kernel features: none beyond Unix sockets, `fsync`, symlinks. Linux-specific: nothing in this shard (the CLI arms are
`#[cfg(unix)]`).

The CLIENT side (a friend's machine) needs: `mini`, a matching local `minidregg-host` binary and pinned config (every join/claim
flow runs Host subcommands locally, `join_solana.rs:523-525`, `join_solana_v2.rs:249-255`, `pay_claim.rs:156-171`),
`ssh-keygen`, and `/usr/bin/curl` for HTTPS bootstrap. Shipping a Lean Host binary to every stranger who wants to pay is a large
client prerequisite for a public demo.

### 7.2 Dangerous to expose

* The OPERATOR socket (ops 48, 58/59, 72-81, 117-120 are operator-only in the registry). This shard always routes them there
  (`pay.rs:160-169`, `agent_reserve.rs:263`, `paid.rs:206-212`); `protocol/HOST-OPERATIONS.md:68-69` makes 117-120 operator-only and `deploy/shell/FRIENDS.md:35` notes the deployed node's
  single-socket entry has no operator socket, which is why self-enrollment is not live (FRIENDS.md "paying to enrol ... no").
* Keys with money authority on the box: the observer key (mints Book credit through reports, bounded per record by
  `maxPerObservation * creditPerAtomic`, `Kernel/PayTariff.lean:108-111`); the observer's `C_enrol` (enrols members); the clock key
  (fast-forwards time, F6); the factory control capability used by checkpoint (`53` in the unit); purse/payer keys for agent
  reserves; the till/concierge keys (D2).
* The pay watcher's RPC trust: whoever controls a quorum of the configured RPC endpoints controls what "was paid" (section 3.4 (2)).

### 7.3 What a stranger on the internet could exercise (through this shard's verbs)

* Read-only public ops: 107, 112, 121, 129, 173, 181, 182 (bounded JSON requests ≤ 4096 bytes, responses ≤ 8192; HTTP side rate
  limited per `PAID-COLD-ENTRY.md`, six quotes per minute per address).
* Pay on Solana to the enrollment address: each transfer ≥ `journalFloor` (1,000,000 atomic = 1 DREGG in `enrol-terms.json:11`)
  costs the observer one operator-socket submission and spends ONE tip per decision (`pay.rs:1612-1616`); with
  `PAY_ENROL_ROUNDS` (default 8) per timer tick, a spammer paying many floor-sized memo payments delays honest enrollments in a
  FIFO queue (cost to the attacker: 1 DREGG each, which is journaled, not refunded). Below-floor dust is skipped by the watcher once.
* Ops 183-186 require a signature by the owner key of an existing pending claim (`pay_claim.rs:364-374`); a stranger without a
  deposit has nothing to claim.
* Op 105 assignment, ops 113-116 refill, ops 160-163 job money, ops 123-125 well require capabilities a stranger does not hold.

### 7.4 What a malicious enrolled member could exercise

* `mini credit pay/topup` to any till (their own money); exploit F2 only against themselves.
* `mini job post/claim/answer/check/settle`: the job law enforces every edge (`law.job.shell`); a provider can stall and lose the
  bond; a caller can choose a tiny `--window` (law placeholder `{WINDOW}`, `job.rs:570-573`, `594-595`), making challenges
  impractical for jobs they post themselves.
* `mini market-*`: as a market founder, allocate arbitrarily (D1); no money moves today.
* `mini pay address`: consume book rows (one per account; `nextFree` assignment is sequential, `pay.rs:857-860`); whether one
  subject can obtain many rows by holding many accounts is a Lean question (section 8 Q6).
* `mini pay-claim` for their own pending payment only.

### 7.5 The README "Payments" row (README.md:94): 49.999992 vs exactly 50, settled

* Claim in README.md:94: "a known defect is open: the tariff counts hours, so the quoted week is 49.999992 DREGG, not 50".
* Code now: the tariff is `DREGG/PAY/TARIFF/v4`; "`nodeHourRate` is deleted and `nodeWeekRate` is the Book credit one node week costs,
  so the operator's week price is stored, not derived. The hourly unit made 50 DREGG a week unrepresentable (`50 000 000 / 168` is
  not an integer; the floor was 49.999992)" (`Kernel/PayTariff.lean:30-35`); a v3 tariff's bytes refuse to decode (same lines).
  Enrollment price is `price.birthFee + tariff.nodeWeekRate` (`Kernel/PayEnrolDecision.lean:51`); v2 purchase pricing is
  `birthFee + weeks * nodeWeekRate + starter` rounded up to atomic units (`Kernel/PayEnrolPricing.lean:60-64`).
* Terms: `deploy/pay/enrol-terms.json:8` `"weekPriceAtomic": "50000000"`, `:9` `"creditPerAtomic": "1"`; `deploy/pay/README.md:32-38`:
  `render-enrol` writes `nodeWeekRate = weekPriceAtomic * creditPerAtomic = 50000000`, "exactly 50.000000 DREGG, no division, no floor".
* Rust: no week-price arithmetic anywhere in this shard. v1 prints `atomicAmount` from the Host quote verbatim (`join_solana.rs:636`,
  `652`); v2 signs and prints the quote's `amountAtomic` (`pay_memo_v2.rs:442`, `521`; `join_solana_v2.rs:378-381`); the only
  conversion is decimal display (`join_solana.rs:323-329`, `join_solana_v2.rs:116-126`), which renders 50,000,000 atomic with 6
  decimals as `50`.
* Verdict: **the code says exactly 50; README.md:94 is stale** (last README change `307b13ea`, 2026-10-23; the v4 tariff file's last
  change `a83d0204`, 2026-10-17, per `git log -1`). The lease clock still counts hours (`168 · weeks`) as a duration
  (`Kernel/PayTariff.lean:34-35`), which is not a price. The README row should be rewritten (owner's call).

---

## 8. Questions for the Lean side

Each is phrased so a Lean reader can answer by pointing at a declaration.

1. **One nullifier space?** Do `PayObservation.nullifier` (`Kernel/PayObservation.lean:164-167`), the self-enrollment receiver's
   consumption (`Kernel/PayEnrolReceiver.lean` / `PayEnrolV2Receiver.lean`) and the claim receiver's origin consumption
   (`Kernel/PayClaimReceiver.lean`) spend the SAME `StableNullifier` for the same `(signature, address)`, so that one transfer cannot be
   credited once as an ordinary observation and again as an enrollment or claim? Which theorem states it?
2. **Which nullifier was spent?** When op 110 or op 119 refuses with `durable alreadyConsumed`, can the refusal name whether the tick
   nullifier (`tickNullifier domain command.tip`, `Kernel/PayObservation.lean:182-183`) or observation k's nullifier was spent? (Would
   remove flaw F4's heuristic.)
3. **v2 consumption checks.** At consumption, does `PayEnrolV2Decision` re-check `creditedRemainder ≥ minimumStarterCredit`,
   `membershipCredit > 0` and renewal `birthFee = 0` (Rust refuses to sign otherwise, `pay_memo_v2.rs:540-553`), or only the pricing
   commitment? Name the declaration.
4. **Quote lifetime constant.** Is `PayClaimQuote.maxQuoteLifetimeHours` (rendered at `Host/PayClaims.lean:274`) a constant 1, and is
   the v2 expiry rule "`expiryHour ∈ [processingHour, processingHour + 1]`" the one `pay_memo_v2.rs:346-350` mirrors? Which
   declaration defines the processing hour (observer evidence, not `blockTime` of the transfer)?
5. **Lease boundary.** In `Kernel/PayClaimStatus.lean`, is a lease active iff `leaseUntil > clockHour` (strict), as
   `pay_status.rs:573-577` and `join_solana.rs:896` assume? If it is `≥`, the Rust consistency check refuses valid statuses.
6. **Assignment per subject.** Does `PayAssignmentReceiver` bound how many book rows one subject (or one owner of many accounts) can
   take? `pay address` assigns `nextFree` per account (`pay.rs:673-677`).
7. **Well receipts.** Is there any receipt-only lookup for op 125 (`Host/Main.lean:7055-7063`)? If not, what makes a retried
   mint after an `uncertain` reply safe (flaw F1)? Does `RealmWellReceiver` dedupe by anything other than the nonce?
8. **Clock monotonicity.** Which declaration in `Kernel/ClockTickReceiver.lean` refuses a tick with `now ≤ current.now` (strict), and is
   `maxStepSeconds = 0` refused at genesis? (`clock.rs:372-390` loops until a non-confirmed tick.)
9. **Clock rate.** Is there any Lean bound on how many ticks may be admitted per pay-observed Solana `blockTime` (or per height)? If not,
   the clock key's blast radius is unbounded (F6).
10. **Clock submit errors.** Can op 128 return 255 (a thrown error) for a well-formed, previously assembled ingress, e.g. after the
    clock root moved? `clock.rs:227-244` treats that as "unresolved" forever.
11. **Reserve index.** Is a reserve always the last accepted transition of its batch, so that `reserveIndex = acceptedCount - 1`
    (`agent_reserve.rs:133-136`) and `grantIndex = acceptedCount - 1` (`agent_lifetime_grant.rs:73-76`) hold? Which theorem
    (`ApplicationDispatchAgentReserve*`, `ApplicationAgentLifetimeGrant*`) says so? (Lean refuses a wrong index,
    `Kernel/ApplicationDispatchAgentPaidAuthoring.lean:264-267`, so this is liveness, not safety.)
12. **Op 77 vs op 3.** Does the lifetime dispatch lookup (op 77, `Host/Main.lean:2103`) return the same receipt fields as op 76's
    committed `dispatchReceipt` (`paid.rs:593`)? (Relevant to F3 once the projection is fixed.)
13. **Job money once.** Confirm that `JobMoneyReceiver` refuses FUND when escrow ≠ 0 and CLAIM when the job is not open, independently of
    the job law text (`law.job.shell:18-21`), so that `job.rs` `fund`/`claim` without recovery can never double-debit.
14. **Market allocation.** Does `Kernel/SealedMarket.lean` (or the `law.market` template) constrain the settlement allocation beyond
    "fill ≤ revealed qty" and phase (`market.rs:13-19`)? If not, is a Lean `clear` with a theorem planned (D1)?
15. **Room membership.** Is there any Lean receiver that ties a `renew` publication on a till to a member window (D2), or is the
    concierge (`native/grain-runtime/src/concierge.rs:147-180`) the only judge?
16. **Pay-claim across carry.** What is the planned receiver for op 191 (`protocol/HOST-OPERATIONS.md:76-79`), and until it exists,
    what is the intended recovery for a claim whose reply was lost before a Host upgrade (F7)?
17. **Observation floor.** Is `tariff.journalFloor` applied by Lean to ORDINARY book rows too, or only to the enrollment index
    (`Kernel/PayTariff.lean:18-21`)? The watcher applies the CLI floor only to the enrollment row (`pay.rs:907-909`).
18. **Provider metering (op 19).** Which declaration decodes the `u32le|metadata|u32le|request|response` payload (`meter.rs:166-171`),
    and does it bound the response it hashes to `HOST_MAX_FRAME`?
19. **Refusal text stability.** `pay.rs:321-363` parses Lean `repr` output (constructor paths such as
    `Minidregg.Kernel.PayObservation.Reject.stalePay` inside `Minidregg.Theory.Receiving.Refusal.family (...)`). Is there a
    machine-readable refusal code the Host could emit instead, so a Lean rename cannot silently turn a named reason into "unnamed"?
