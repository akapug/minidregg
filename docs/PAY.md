# PAY: how $DREGG pays for a Mini deployment

This is the present-state description of the payment rail. The Lean modules are the authority;
this document says what they do and where they are. Section numbers are kept from the design
of 2026-09-30 so that the `PAY §N` citations in `Kernel/Pay*.lean`, `Kernel/PurseRefill*.lean`,
`native/pay-watcher`, `native/resource-client` and `deploy/pay` resolve here. Lane names in
those comments (P1 … P6, P3b, P3b-1, P3b-2) are listed in §6 and §11.9.

Each section is marked **shipped** (in `main`, with the module named), **changed** (shipped,
but not as first designed: the difference is stated) or **design** (not built).

## 0. Summary

A payment is an observation of a finalized Solana transfer of the DREGG token (an SPL
Token-2022 mint) to an address in the deployment's pay cell. An enrolled observer subject
reports it in a signed command; the kernel lowers it to one Book mint of the credit asset plus
one durable nullifier, so the same transfer can never be credited twice. Credit is a service
allowance on the deployment, not a claim on the token: the kernel never sends a Solana
transaction and nothing redeems credit. Credit buys membership weeks and funds Hermes purses.
A stranger can join by paying the deployment's enrollment address with a signed memo.

The DREGG mint is `XkeTXo1125vz5H9svJpGiw4JvLbN8VmMu9cmMvspump` (6 decimals, Token-2022
program `TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb`), pinned in `deploy/pay/enrol-terms.json`.

## 1. What is trusted

| party | what it can do if it lies or is stolen | what bounds it |
|---|---|---|
| the RPC endpoints | invent, misreport or hide a transfer | the per-observation cap (§3.6); every configured endpoint must agree (§3.3); `mini pay audit` compares credit with the chain |
| the observer's Mini key | mint credit without a transfer, up to the cap per observation, at the heartbeat rate | the cap; revocation by the factory controller; the audit identity (§2.4) |
| the enrollment receiving key | move what the enrollment address has received | it is on the box (§4, **changed**) |
| Solana finality | reorg a finalized block | outside the threat model |

What the rail refuses to do: no mirror token, no redemption or refund, no bridge or vault, no
sweeper.

## 2. The constructs on the kernel

### 2.1 The unit. **Shipped.**

Credit is the tariff's `asset` (`Kernel/PayTariff.lean`, `Tariff.asset`; asset 0 is the
deployment's fee asset). At the published terms 1 atomic unit of DREGG = 1 credit
(`creditPerAtomic = 1`).

### 2.2 Deposit binding. **Shipped.**

The pay cell's `book` holds 32-byte deposit addresses written by the factory controller
(`Kernel/PayBookReceiver.lean`, append-only, `book_write_once`). `mini pay address` binds the
next free index to a Book account the requesting subject owns (`Kernel/PayAssignmentReceiver.lean`:
`assignment_requires_owner`, `assignment_requires_book`, `assignment_write_once`,
`assignment_requires_valid_tariff`). An ordinary deposit address belongs to one account, so no
memo is read for it. Row 0 is the enrollment address (§11.2); further rows come from
`render-enrol --book-extra`.

The pay cell (`Kernel/PayCell.lean`) has thirteen namespaces: `tariff`, `book`, `assignment`,
`enrolment`, `sshIndex`, `journal`, `claim`, `claimConsumption`, `pendingOwner`, `chainTip`,
`pendingOwnerHistory`, `computeUsage`, `computeActivation`. `Kernel/PayCellUpgrade.lean` is the
explicit v4 → v6 payload carry.

### 2.3 The tariff. **Shipped, changed.**

The tariff is a versioned value in the pay cell, set by the factory controller through
`PayBookReceiver` with a strictly increasing version (`tariff_version_monotone`). Fields
(`Kernel/PayTariff.lean`, `structure Tariff`): `version`, `asset`, `mint`, `tokenProgram`,
`decimals`, `creditPerAtomic`, `maxPerObservation`, `minTickSlots`, `nodeWeekRate`,
`enrolIndex`, `journalFloor`, `slashCallerPermille`. `creditFor` caps one observation's credit
(`creditFor_le_cap`). The genesis default is invalid by construction (`genesisDefault_invalid`),
so nothing is assigned or credited until the operator sets a tariff.

Changed from the design: the week is in the tariff. `nodeWeekRate` is the credit one node
week costs (tariff v4); the hourly rate was deleted because 50 DREGG a week is not an integer
number of credits per hour. The codec frame is `DREGG/PAY/TARIFF/v8`; older frames refuse to
decode.

### 2.4 The observation ingress and the mint. **Shipped.**

`Kernel/PayObservation.lean` holds the watcher's record (`Observation`: book index, address,
64-byte signature, slot, block time, amount added, mint, token program, memo field), the command carrying a list of them with the finalized tip the observer read
them at (slot and block time), and the pure decision. `Kernel/PayObservationReceiver.lean` is the signed turn: it writes the pay cell (the
finalized tip, `PayChainTip.patch`), the deployment clock cell, and the Book (one
`.mint asset payer (creditFor amount)` per observation). An empty report is a heartbeat.

The nullifier's bytes are `"soltx:" ‖ signature(64) ‖ address(32)` (§10 erratum 1).

Proved in `Kernel/PayObservationProofs.lean`: `observation_mints_exactly`,
`report_credits_exactly`, `well_tracks_observed` (the audit identity: along any log of
accepted reports, `−well_h = −well_0 + Σ credited`), `overcap_mints_cap`,
`heartbeat_advances_clock`, `clock_monotone_by_observation`, `second_credit_refused`,
`distinct_address_same_signature_admitted`. `Kernel/PayLedger.lean` extends the identity over
refills and job money: `−well_h = −well_0 + credited − refilled − retired`.

### 2.5 The clock. **Changed.**

The design put a chain clock in the pay cell. Today the deployment has one clock cell
(`Kernel/ClockCell.lean`, law `Kernel/ClockLaw.lean`); an observation report advances its slot
and time. The pay cell separately retains the authenticated finalized tip
(`Kernel/PayChainTip.lean`), which paid-entry decisions use with a bounded freshness policy.

### 2.6 Membership. **Changed.**

The design made membership a Book `lease` priced by a `MembershipLeaseReceiver`. That receiver
was not built. Membership today is the enrollment receiver's lease leg: whole weeks at
`nodeWeekRate`, paid as a Book `.fee` from the enrollment float to the collector
(`Kernel/PayEnrolReceiver.lean`, `leaseCost`, `enrolBatch`, `renewBatch`), with the expiry kept
in the `enrolment` row's `leaseUntil`. The lease gates the ssh login through the roster sync
(§11.5); it does not gate kernel admission.

### 2.7 Inference settlement: purse refill. **Shipped.**

`Kernel/PurseRefill.lean` and `Kernel/PurseRefillReceiver.lean` (lane P6): the owner of Book
account `A` burns credit from `A` and the AgentGrain purse gains exactly that, in one joint turn
whose resource law at the credit coordinate must sum to zero (`overclaim_fails_commit`,
`refill_conserves`, `refill_requires_owner`, `purse_never_mints`). The purse's AgentGrain law
admits the `refill` edge only under the slot this receiver projects. Reserve, settle and
uncertain-attempt handling are AgentGrain's (`Kernel/AgentGrain.lean`); an uncertain provider
call keeps its reservation held and is never resent.

### 2.8 Unpaid keys. **Partly shipped.**

`Kernel/PayStarterAllowance.lean` computes the recommended starter credit for a new paid
member from the creation tariff. The operator "comp" mint (a second observation branch under
the controller's capability) was not built; an underpaid or journaled enrollment is settled by
the operator by hand.

### 2.9 Summary

| construct | module | state |
|---|---|---|
| pay cell, tariff, book, assignment | `PayCell`, `PayTariff`, `PayBookReceiver`, `PayAssignmentReceiver` | shipped |
| observation, mint, nullifier, heartbeat | `PayObservation*`, `PayChainTip`, `ClockCell` | shipped |
| membership lease | lease leg of `PayEnrolReceiver` | changed (§2.6) |
| purse refill | `PurseRefill*` | shipped |
| self-enrollment v1 and v2, claims, pending custody | `PayEnrol*`, `PayClaim*`, `PayPendingRotation` | shipped (§11) |
| comp mint | none | design |
| watcher | `native/pay-watcher` | shipped |
| box units | `deploy/pay` | shipped |

## 3. The watcher. **Shipped.**

`native/pay-watcher` (Rust) turns finalized transfers to book addresses into `Observation`
records; `deploy/pay/mini-pay-watcher` runs one tick and submits one report with
`mini pay observe`. Its README is the operating reference.

### 3.1 Contract

A port of the sound core of breadstuffs' `dregg-pay` watcher, with the token program as data
(the live mint is Token-2022; the old library pinned the legacy program and would have credited
nothing). The hostile fixtures under `native/pay-watcher/fixtures/` are the contract
(`tests/vectors.rs`): wrong program, wrong mint, wrong owner, zero delta, failed or pruned
transaction, pre/post disagreement, out-of-range account index, restart re-yields the same set.

### 3.2 Finality

Every RPC call is at `commitment: "finalized"`. Idempotency does not depend on finality: the
nullifier makes a resubmission a refusal.

### 3.3 Endpoints

The watcher polls a list of endpoints and emits an observation only when every endpoint
returns the same facts for it (`minEndpoints`, default 2; `PAY_MIN_ENDPOINTS=1` is an explicit
weakening). The dClutch relay is not consumed.

### 3.4 Statelessness

Ordinary indexes are read statelessly: each run lists the newest `maxPages × pageSize`
signatures (default 4 × 25), and the receipts directory plus the kernel's nullifiers are the only
memory. A full window is recorded as a `pageBound` refusal. The enrollment index keeps a
persistent cursor (§11.7). The tick is a systemd oneshot 60 s after the previous one finished.

### 3.5 Key custody

The observer key is `/etc/mini/pay/observer.key` (0600, owner `mini`), enrolled at genesis
(`payObserver` in the genesis source). RPC endpoints with their API key are in
`/etc/mini/pay/rpc.env` (root 0600), never in git or argv. The observer capability is
revocable by the controller.

### 3.6 The per-observation cap

`maxPerObservation` = 10 000 DREGG at the published terms. An over-cap payment credits the cap;
the residual is visible to `mini pay audit` and is the operator's to settle.

## 4. Custody of the money. **Changed.**

The design kept every receiving key offline. As built, `deploy/door/infra/mini-enrol-keygen`
makes the enrollment receiving key on the box at install
(`/var/lib/mini-core/secret/enrol.key`, mini-core 0600, with a Solana CLI keypair copy for
ember to move funds). So the enrollment address's balance is spendable by whoever holds root or
the `mini-core` user on the box until ember moves it. There is no sweeper.

## 5. The friend's path. **Shipped.**

`mini pay address` (an index for an account you own), `mini pay status`, and for strangers
`mini join --solana` / `--wait` / `--renew` (`native/resource-client/src/join_solana.rs`,
`join_solana_v2.rs`). `mini pay audit` is the operator's check of chain balances against credit.
`deploy/pay/README.md` "What a friend sees" has the transcript.

## 6. Lanes and journeys

| lane | what | state | journey |
|---|---|---|---|
| P1 | watcher on fixtures | shipped | `jpay1.sh` |
| P2 | pay cell, tariff, book, assignment | shipped | `jpay2.sh` |
| P3 | observation, mint, nullifier, clock | shipped | `jpay3.sh` |
| P4 | client and shell verbs | shipped | `jpay4.sh` |
| P5 | membership lease receiver | not built (§2.6) | none |
| P6 | purse refill | shipped | `jpay6.sh` |
| P7 | box units | shipped (`deploy/pay`) | `jpay-rail.sh` |
| P8 | mainnet flip | the demo contract requires one mainnet pay-to-enrol (`docs/DEMO-PREFIX-2026-10-26.md` §1) | — |
| P1b, P3b-1, P3b-2, JOIN-SOLANA | self-enrollment (§11) | shipped | `jpay-e1.sh` … `jpay-e4.sh`, `jpay-v2.sh` |
| C3 | job money in credit (COMPUTE) | shipped (`PayLedger`, tariff `slashCallerPermille`) | — |

## 7. Decisions

Answered: the week price is 50 DREGG (ember, 2026-10-04; `deploy/pay/enrol-terms.json`
`weekPriceAtomic = 50000000`); credit is asset 0 at 1 credit per atomic unit; the cap is
10 000 DREGG; ordinary payments use per-account deposit addresses; the relay is not consumed.

Open: see §4 (an on-box receiving key with no sweep policy) and §2.8 (no comp mint).

## 10. Errata adopted from lane P1

1. The nullifier covers the address as well as the signature, so one transaction paying two
   deposit addresses is two credits (`distinct_address_same_signature_admitted`).
2. Paging runs to the page bound, not to the first receipted transfer.
3. Endpoint agreement covers `blockTime`; present at one endpoint and absent at another is a
   disagreement.
4. `amount` is the net added to the address across all its token accounts.
5. The watcher refuses a returned transaction whose signature or slot differ from the listing,
   a listing with no slot, and a pruned transaction, each by name in `events.json`.
6. On the wire, signatures, addresses, mint and program are lowercase hex of the raw bytes.
7. Journey hooks follow the M7 contract (verdict line, artifact path).

## 11. Self-enrollment via Solana. **Shipped.**

### 11.1 The flow

The stranger runs `mini join --solana`, which makes a Mini key locally and prints the
enrollment address, the Host's quote, and one memo carrying two possession signatures (the Mini
key's, and the ssh key's via `ssh-keygen -Y sign`). They send at least the quote with that memo.
The watcher reports the transfer; the observer submits it alone to the enrollment receiver; one
accepted intent enrolls the key, births and funds its account, grants factory observation,
assigns a deposit index if one is free, pays the lease, and records the ssh key. A payment that
cannot enroll is journaled with its reason and credits nothing. The roster sync adds the ssh key
as a proxy-mode login; `mini join --wait` then writes the remote workspace.

### 11.2 The enrollment address

Book row 0, assigned to the enrollment float, and named by the tariff's `enrolIndex`
(`none` turns self-enrollment off; the book receiver refuses an `enrolIndex` whose row is
unassigned, `enrolIndexUnassigned`). The address is a fresh per-deployment key (§4), a
deployment parameter rendered into the pin, never a literal in the repo.

### 11.3 The memo

v1 (`Kernel/PayEnrolMemo.lean`): 400 ASCII bytes,
`enrol:v1:<mini-pubkey hex 64>:<ssh-ed25519 blob base64 68>:<mini-sig hex 128>:<ssh-sig hex 128>`,
canonical (`parse_canonical`, `parse_encode`). The Mini key signs
`"DREGG/PAY/ENROL/POSSESSION/v1" ‖ mint ‖ enrolAddress ‖ sshBlob`; the ssh key signs
`mint ‖ enrolAddress ‖ miniKey` as SSHSIG under namespace `dregg-enrol@v1`, verified by the
native `verify-sshsig` (`native/credential-signature-verifier`). The watcher passes at most
566 memo bytes, the room left in a one-transfer transaction. Both signatures are needed:
without the first anyone could enroll someone else's Mini key, without the second anyone could
squat a public ssh key.

v2 (`Kernel/PayEnrolMemoV2.lean`, `enrol:v2:`): quote-bound. The signed value carries a
deployment commitment, a pricing commitment, the enrollment identity and authorizing keys with
their epoch, the ssh key, the next-key digest, the requested weeks, a minimum starter credit,
an expiry in chain hours, and the amount. Because it binds the deployment, a v2 memo does not
replay into another deployment.

### 11.4 The receivers

v1: `Kernel/PayEnrolDecision.lean` (refused / journaled / renew / enrol, with `enrolPrice =
birthFee + nodeWeekRate`) and `Kernel/PayEnrolReceiver.lean` (one intent over the authority
cell, factory, Book, new account, its law source, and the pay cell). Proved in
`Kernel/PayEnrolProofs.lean`: `multi_cell_intent_atomic`, `enrol_atomic`,
`self_enroll_nullifier`, `enrolled_key_has_no_grant_beyond_membership`,
`journal_mints_nothing`, `renew_only_extends`; `observer_control_confined` is in
`Kernel/NativeHostGenesis.lean` (the observer's factory capability admits only
self-enrollment).

v2: `Kernel/PayEnrolV2Decision.lean`, `PayEnrolV2Legs.lean`, `PayEnrolV2Receiver.lean`,
priced by `PayEnrolPricing.lean` and quoted read-only by `PayEnrolQuote.lean`
(`mini join` prints the Host's quote, op 121). A deposit whose quote went stale becomes an
immutable claim (`PayEnrolClaim.lean`) held as pending value with zero mint, recoverable once
through the closed claim surface (`PayClaimCommand`, `PayClaimDecision`, `PayClaimReceiver`,
`PayClaimLaw`, `PayClaimQuote`, `PayClaimStatus`); a not-yet-admitted owner can pre-rotate its
key (`PayPendingRotation.lean`). `Kernel/PayReceivingContract.lean` names the receiving
revision.

### 11.5 The roster sync

A root timer renders `/etc/mini/authorized_keys` from the Host's public enrollment view
(`mini enrollment-view`, socket op 112): operator lines first, then one forced-command proxy line per live
enrollment. It lives in dregg-infra, not this repo. A lapsed lease removes the login; the
subject, account and data stay.

### 11.6 Client and docs

`mini join --solana|--wait|--renew` (`--memo-version v2` for the quote-bound memo); the pin is
rendered from `deploy/pay/enrol-terms.json` and published with the friend bundle; the client
refuses a pin whose address differs from the box's book row 0. `deploy/shell/FRIENDS.md` has the
friend-facing text, including that the wallet, ssh key and Mini key are linked publicly on
Solana.

### 11.7 Threat model

A memo naming someone else's Mini or ssh key fails a possession check and is journaled. A
replayed memo in a new transaction is a renewal for its owner. The same transaction observed
twice is refused by the nullifier. Memo-less dust is refused on chain if required memos are
enabled on the receiving token account (an operator step, not enforced by this repo);
memo-bearing dust below `journalFloor` is never submitted. The enrollment index pages back to a
persistent cursor with no page bound, so dust cannot push a real enrollment out of view
(`native/pay-watcher/README.md`). Self-enrollment ops 117-120 are served only on the
owner-private operator socket.

### 11.8 Numbers

50 DREGG per node week, `journalFloor` 1 DREGG, cap 10 000 DREGG, `minTickSlots` 1500,
`slashCallerPermille` 500 (`deploy/pay/enrol-terms.json`).

### 11.9 Lanes

P1b (watcher enrollment index and memo, `jpay-e1.sh`), P3b-1 (decision, state and memo codec,
`jpay-e2.sh`), P3b-2 (composed receiver, ops, replay, `jpay-e3.sh`), JOIN-SOLANA (client,
`jpay-e4.sh`), then the v2 receiving revision (`jpay-v2.sh`).
