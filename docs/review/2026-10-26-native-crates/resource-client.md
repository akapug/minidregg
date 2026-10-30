# resource-client (`mini`): crate synthesis

| | |
|---|---|
| Crate | `native/resource-client` (`minidregg-resource-client`, binary `mini`; a member of the root workspace, no `Cargo.lock` of its own) |
| Size | 113,789 lines of Rust in `src/` (113,884 counting the loose `selected-release-drop-reply.rs`), plus 48,420 lines of scripts and prose at the crate root (shard G) |
| Date | 2026-10-26 |
| Method | Synthesis of seven shard reports, each written by a reader who read its shard in full. I read their executive summaries and sections 3, 5, 6, 7 and 8, A's command table, G's script and demo-path tables, and every flaw heading. The Rust source was opened only to settle disagreements; each such check is cited with a path and line. Nothing was built or run. |
| Inputs | `resource-client--A-entry-shell-workspace.md` (A), `--B-transport-relay-traffic.md` (B), `--C-pay-credit-money.md` (C), `--D-identity-enrollment-fleet.md` (D), `--E-documents-web-receipts.md` (E), `--F-chat-hermes-private-selected.md` (F), `--G-journeys-contracts.md` (G), all in this directory. Scratch tables: `rc-A/arm-module.tsv`, `rc-A/reach.tsv`, `rc-A/other-crate-callers.txt`, `rc-G/step-hook-status.txt`, `rc-G/inv.txt` under `/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/`. |

Citations of the form "A F2", "C D1", "D S-1", "E S10" or "F V9" point to items in the shard reports. `path:line` citations are copied from those reports unless marked "(checked)", which means I opened the line myself for this synthesis.

## Verdict in twelve lines

1. `mini` is one binary carrying about fifteen products. The deployed demo (the hosted shell, documents and boards over ssh) needs roughly a third of its Rust: about 41K of 114K lines. About 45 of its 127 live commands have no caller of any kind, and about 30 more are reached only by `grain-runtime` subprocess calls or by `scripts/`.
2. The wire is sound and narrow. It is one framing on Unix sockets plus an ssh pipe, its 254 marker means "never forwarded", it resends nothing on its own, and its two allowlists match the registry byte for byte (B).
3. "Rust decides nothing semantic" is not true of this crate. Rust authors the content of every law the shell installs (document, room, board, chat, private room, story, Hermes till and budget, fleet and genesis permit-alls). It computes the sealed-market allocation, the room-key entitlement and the provider-allowance expiry. It is the only gate on 69 operator-only Host operations, and it writes a raw session-close state transition. Section 3 has 48 rows.
4. The retry contract is four contracts. Only one of them, exact resubmission of retained bytes judged by a Lean replay check, matches the README promise. Three paths author a new operation after a fresh nonce with no durable record (`credit pay|topup|refund`, `well mint|burn|floor`, `activity submit` for non-invoke turns). Four paths author a new operation after a decoded refusal (append recovery, chat `staleTarget`, `fleet-sign`, birth release), and `fleet-sign` treats `uncertain` as "never admitted" (section 5).
5. Rust treats a 255 frame as a refusal at four sites (shell and web, `well`, key rotation, `activity`), but Lean also answers 255 for `unavailable` and for any thrown handler exception. That is the single most dangerous misreading in the crate. Whether Lean can throw after a commit is the first Lean question (section 8, Q1).
6. Twin census: about 9 hand-rolled custody state machines beside `mini_sdk::custody`, three traffic-privacy stacks (8,891 lines, none deployed), three disagreeing consent op lists, 8 pair-framing copies, about 15 inline frame encoders in scripts, 7 lost-reply proxies, 159 literal op numbers that bypass the generated constants, and about 80 custody `type` strings in shard F alone (section 4).
7. The demo-minimal build drops about 72.6K of the 113.8K Rust lines (64%) for tier 1 (hosted shell, documents and boards). The blocking couplings are few and named in section 6: `agent_reserve.rs` helpers, the `private.rs` slice that `keygen` uses, `fleet.rs` record helpers, `current_birth`, `room_schema`, `render`/`shared_names`, and `receipt_continuity`'s carry hooks.
8. The journey corpus is 45K lines, and its CI gate never finishes: it is killed at 10,800 s against a 14,400 s budget. Only J0–J8, G, J12X, JSERVE, K4, KT, JJ and K10 have repeatable PASS results on main. A demo set of about 4.5K lines covers the demo path (G).
9. Deployability: a friend running `mini --remote` needs a local Lean `minidregg-host` and `minidregg-client-consent`. Every `mini` process forks a codec child and may leave a `setsid` consent daemon behind. All hosted members share one uid, so they can read each other's key files. One member can monopolize the single Host thread for up to 600 s per request (section 7).
10. The README "Honest state" table is stale in four rows: Payments (the code says exactly 50 DREGG), J5/J8 (now pass in CI), call/send (runner rows exist), and chat (J14 did join chat to a native Host on a lane build, before the in-process rewrite). See section 9.
11. Readers disagree in four places, all settled in section 9. One is A's "`consent-resident` unreached": `client_consent.rs:418-420` (checked) self-spawns it from every signing `mini` process. Another is B's "115 public ops": the registry has 113.
12. The roughly 110 shard questions for Lean reduce to 45 (section 8). The ones that gate the most decisions are Q1 (throw after commit), Q2 (refused at admission implies no append), Q5 (the replay key) and Q9 (a definitive `absent`).

---

## 1. What the crate is

`mini` is the member-side and operator-side client of the Lean Host, plus several servers and research stacks that grew inside the same binary. Lean authors and admits. `mini` keeps keys, authors intents through the Host's own codec (op 7, locally or over the socket), signs Host-printed headers after a local Lean consent check, sends the exact bytes, keeps every attempt on disk, and asks the Host to decode every answer. That description holds for the core (A, B, D 3.3, C 3.3). The exceptions are the subject of sections 3 and 5.

### 1.1 Family map

Lines are `wc -l` of `src/` today (test regions included; per-shard test shares are in section 6). Families are product surfaces, not shards.

| # | Family (product surface) | Modules | Lines | Shard | Demo tier |
|---|---|---|---:|---|---|
| 1 | Entry and argument dispatch | `main.rs` (127 arms, USAGE, keygen, bootstrap, submit/query/retry/author/inspect pipeline, fn-consumer helper block `:2575-3129`) | 5,209 | A | keep (trim ~1.6K) |
| 2 | Hosted shell | `shell.rs`, `shell/{session_fs,doc_render,template,law}.rs` | 5,730 | A | keep |
| 3 | Workspace authoring layer | `workspace.rs` | 8,795 | A | keep |
| 4 | Wire: client transport and `mini serve` | `transport.rs`, `serve_queue.rs`, `proxy.rs`, `bounds.rs`, `fsio.rs`, `trace.rs` | 4,818 | B | keep |
| 5 | Split-topology ingress and drain | `public_proxy.rs`, `operator_drain.rs` | 1,200 | B | optional (not deployed) |
| 6 | Read-path verification | `hiding.rs`, `content_privacy.rs` | 851 | B | keep |
| 7 | Refusal retention and re-plan | `replan.rs`, `prepare_refusal.rs`, `query_refusal.rs` | 872 | F | keep |
| 8 | Consent provider client | `client_consent.rs` | 1,130 | D | keep |
| 9 | Participant identity and enrollment | `participant_enrollment.rs`, `participant_namespace.rs`, `participant_provisioning.rs`, `fresh_onboarding.rs`, `current_birth.rs` | 4,605 | D | keep |
| 10 | Key rotation, adoption, provider-key broker client | `key_rotation.rs`, `key_rotation_custody.rs`, `key_adoption.rs`, `keys.rs`, `key_service.rs` | 3,306 | D | drop (keep `key_rotation.rs:1-330`) |
| 11 | Laws and affordances | `can.rs`, `law_export.rs`, `lawsat.rs` | 1,353 | D | keep (law check, can) |
| 12 | Rendering and documents | `render/*`, `shared_names.rs`, `doc_search.rs`, `inspect_views.rs`, `room_schema.rs` | 3,551 | E | keep |
| 13 | Protected (sealed) documents | `protected_*.rs`, `protected_object/*` | 4,946 | E | drop for tier 1 |
| 14 | Web face and Studio | `web.rs`, `web/*`, `web_admission.rs`, `web_actions.rs`, `workspace/{studio,studio_preview,web_author,web_create}.rs` | 5,351 | E, A | drop for tier 1 |
| 15 | Receipt continuity and carry | `receipt_continuity.rs`, `receipt_continuity/carry.rs`, `carry/verifier.rs` | 3,414 | E | keep `receipt_continuity.rs` only |
| 16 | App connector, lifecycle, context, world kinds | `app_document.rs`, `app_lifecycle.rs`, `context_projection.rs`, `world_kind.rs`, `world_prototype.rs`, `world_surface.rs` | 2,948 | E | drop (keep `world_kind.rs` if boards need it) |
| 17 | Operation proofs and historical receipts | `append_proof.rs`, `historical_call_receipt.rs` | 665 | E | drop |
| 18 | Fleet turns and helm adapter | `fleet.rs`, `fleet_sign.rs` | 2,423 | D | keep `fleet.rs` record helpers; drop the rest for tier 1 |
| 19 | Member home, seats | `member.rs`, `member_app.rs`, `seat.rs` | 1,379 | D | drop |
| 20 | SPK sessions and application shares | `session_enrollment.rs`, `session_reenroll.rs`, `share_issue.rs`, `share_issue_receipt.rs`, `grain_share_issue.rs` | 3,551 | D | drop |
| 21 | Paid entry over HTTP | `enrollment_bootstrap.rs` | 1,553 | D | tier 3 only |
| 22 | Pay rail and pay-to-enrol | `pay.rs`, `pay_claim.rs`, `pay_memo_v2.rs`, `pay_status.rs`, `pay_refill.rs`, `join_solana.rs`, `join_solana_v2.rs`, `paid_context.rs`, `paid_onboarding.rs` | 10,179 | C | tier 3 (v2 only) |
| 23 | Room credit, clock, checkpoint, meter | `credit.rs`, `clock.rs`, `checkpoint.rs`, `meter.rs` | 1,919 | C | keep `clock`, `checkpoint`; `credit` with rooms |
| 24 | Market, wells, jobs | `market.rs`, `well.rs`, `job.rs` | 2,008 | C | drop |
| 25 | Agent reserves and payers | `agent_reserve.rs`, `agent_reserve/lifetime_v3.rs`, `.../paid.rs`, `agent_payer.rs`, `agent_lifetime_grant.rs` | 3,015 | C | drop (move helpers first) |
| 26 | Chat, story, Hermes composing verbs | `chat.rs`, `capture.rs`, `story.rs`, `hermes.rs` | 5,024 | F | tier 2 (chat) |
| 27 | Private rooms | `private.rs`, `roomkey.rs` | 5,303 | F | drop (keep keygen slice of `private.rs`) |
| 28 | Hermes resident handoff and provider continuity | `hermes_handoff.rs`, `provider_continuity.rs` | 2,631 | F | drop |
| 29 | Objective Bend client | `activity.rs`, `objective_invoke.rs`, `bend_session.rs` | 467 | F | drop (keep 392 if Objective is shown) |
| 30 | fn consumer and origin publication | `drain.rs`, `worker.rs`, `fn_namespace.rs`, `fn_frontier.rs`, `publisher.rs` | 5,058 | B, F | drop (move the fn POST half of `worker.rs` if selected exchange stays) |
| 31 | Selected-source release and exchange | `selected_release.rs`, `selected_publisher.rs`, `selected_exchange.rs` | 2,024 | F | drop |
| 32 | Traffic privacy (three stacks) | `relay.rs`, `channel.rs`, `pq_mailbox.rs`, `cohort_tcp.rs`, `scheduled_transport.rs`, `async_dispatch.rs` (+ `../crypto_transit.rs` 380) | 8,511 (+380) | B | drop |
| | **Total** | 140 files | **113,789** | | |

Shards, for reference: A 21,476 Rust lines, B 18,424, C 17,121, D 19,300, E 19,133, F 18,335 (plus the 95-line loose program), G 48,420 non-Rust lines. These sum to 113,789.

### 1.2 Binaries and entry arms

- **One binary**, `mini` (`Cargo.toml:9-11`). Every module is reached through it. There is no `fn main` elsewhere in the crate. The loose `selected-release-drop-reply.rs` is compiled with bare `rustc` at run time by `selected-release-acceptance.sh:381` (G 1.4).
- **127 live commands**: 125 arms in `run` (`main.rs:3196-4499`) and 2 dispatched before argument parsing, `bend-session-sign` (`main.rs:4508`) and `fleet-sign` (`main.rs:4514`). Three more names are tombstones that refuse by name: `key-service`, `key-service-config` and `key-namespace` (`main.rs:3235`). `USAGE` (`main.rs:642-839`) omits 12 live commands: `activity`, `checkpoint`, `clock`, `consent-resident`, `hermes-handoff`, `member`, `mix`, `mix-live`, `seat`, `story-law`, `traffic` and `bend-session-sign` (A 1). Section 2 has the full table.
- **In-process sub-entries.** `mini shell` runs each line through `main::run` in the same process under `catch_unwind` (`shell.rs:2569-2581`). Chat runs its sub-operations through `capture::command` → `crate::run` under a process-wide fd-1/fd-2 swap (`capture.rs:60-104`); `hermes::quietly` is a second fd swap (F). `mini web` is a thread-per-connection HTTP/1.1 server bound to loopback (E).
- **Servers inside `mini`:** `serve`, `serve-operator`, `serve-public-proxy`, `socket-proxy` (the ssh forced command), `consent-resident` (self-spawned), `web` (loopback), `enrollment-bootstrap` (HTTP, meant to sit behind TLS), `relay`/`relay-witness`, `traffic --action server`, `mix-live` (TCP listeners), and `consumer-worker` (an NNTP-woken daemon).

### 1.3 How `mini` reaches the Host (summary of B 1.2)

1. **One framing everywhere:** `u32 LE length ‖ bytes`, `1 ≤ length ≤ MAX_FRAME` (`transport.rs:629-674`). A length prefix reserves no memory, because the body is read with `take(size)`.
2. **Client → service envelope:** `version (1|2) ‖ u32 LE config length ‖ exact config bytes ‖ [v2: 32-byte SHA-256 of the client's chosen Host image] ‖ op ‖ payload` (`transport.rs:930-947`, `:1118-1126`). The service refuses a mismatched config or image pin. v1 is still accepted (`transport.rs:177`) and still sent by `main.rs:3137` (op 112), `main.rs:3152` (op 8) and `publisher.rs:154` (op 18), which contradicts the crate README (`README.md:195-198`).
3. **Service → Host:** the service strips the envelope and writes `u32 LE len ‖ op ‖ payload` to one `minidregg-host CONFIG stdio` child (`transport.rs:1495-1514`). Lean's `serveSession` (`Host/Main.lean:2667-2694`) agrees on bytes and on the op-153 special bound (`frameBound`).
4. **Replies:** the request byte on success; 255 for any Lean refusal *or thrown exception* (`Host/Main.lean:2652-2663`); 34/164 for the dispatch pair; and **254, emitted only by the Rust service**, for a request it never forwarded (busy, pin mismatch, op not allowed, caller gone). Each 254 site is judged just before the Host write (`transport.rs:1566-1578`, `:1770-1776`).
5. **Sockets:** Unix stream sockets only, in a 0700 directory, 0600 socket, `SO_PEERCRED` in operator mode. Remote access is `ssh:DEST` through `mini_sdk::operator::SshPool` to `mini socket-proxy` (`proxy.rs:75-98`). There is no TCP in `transport.rs`.
6. **Allowlists:** `allowed_operation` (`transport.rs:308-512`, public) and `allowed_operator_operation` (`:526-618`, operator) match `routes` in `protocol/host-operations.json`. Lean's `dispatchSession` sees only `(op, payload)` (`Host/Main.lean:2006-2011`), so routing is decided in Rust alone.
7. **Deadlines:** client read 600 s; Host budget 120 s for ops 0 and 6–11 ("pure"), 600 s otherwise; queue residence 60 s; 64 connections; 32 queue slots; **one Host thread** (`transport.rs:53-68`, `:1548-1550`).
8. **No resend in transport.** A Host failure mid-request closes the connection without a frame, and the client reports "uncertain" (`transport.rs:1181`, `:1787-1796`). Every resend is made by application code and is the exact retained `call.bin` (`main.rs:2453-2457`, `:2520`).
9. **Pinning:** on Linux the Host image and config are executed from sealed memfds (`transport.rs:1368-1456`). A workspace pins `hostSha256` at init, so a Host upgrade breaks every workspace until a continuity carry re-pins it (A F5).
10. **The pure codec runs locally.** Ops 7–11 (author, inspect, signatures, assemble, outcome decoding) go to a local `minidregg-host` codec child that every `mini` process spawns, not to the server (`main.rs:603-605`, `client_consent.rs:1015-1017`). This is why a remote friend needs a Lean Host binary (section 7).

---

## 2. The command table

All 130 names `mini` dispatches. That is the 125 arms of `run`, the 2 pre-parse arms (`bend-session-sign`, `fleet-sign`; together these make the 127 live commands) and the 3 tombstones. The table is the spine of the deletion plan.

**Sources.**
- Arm lines and reach counts come from `rc-A/arm-module.tsv` and `rc-A/reach.tsv`. The tsv lacks the two pre-parse arms (G noticed `fleet-sign`; `bend-session-sign` is missing too), and its module column is wrong for about 15 rows: `keygen` → `hiding::verify_view`, `retry` → `selected_release::submit`, `store` → `roomkey::enc_public_hex`, and others. I took modules from A's section 1.3 report table, which is correct, and from the other shards.
- Journey steps and runs come from G 1.2 and 5.3, the CI logs G downloaded (`rc-G/ci-*`), C 5.1, D 1.0, E 5.2 and F 5.1.

**Columns.**
- **J/D/S**: counts of journey-script files, `deploy/` files and `scripts/` files that name the command (A's heuristic; `key` and `store` are inflated by `mini-keys`/`mini-store`).
- **X:**: a subprocess caller in another crate.
- **CI**: the GitHub `Build and gates` runs on main of 2026-10-16, 10-17 (`334316d`) and 10-23 (`307b13e`). Their gate always times out, but the J0–J8 rows inside them pass.
- **Runner**: a `scripts/pipeline/journey-rows` row, whose results live on the journey box and are not in this repository.
- **Lane**: a run of a lane build recorded in `docs/evidence`.

**Verdicts.**
- **deployed**: on the 2026-10-01 candidate's path (a unit or script under `deploy/`, or a verb the deployed shell runs in-process).
- **demo-needed**: not deployed as a unit, but needed to run, test or operate the demo.
- **wired (run on record)**: has a caller and a recorded run, but is not demo.
- **wired-but-unrun**: has a caller (journey, runner row, script, other crate) but no run recorded in this repository.
- **unreached**: no caller anywhere.
- **broken**: fails on current code for a named reason.

| # | Command | Arm (`main.rs`) | Module / function | J/D/S | Journey step, runner row, deploy unit, other-crate caller | Latest recorded run | Verdict |
|---:|---|---|---|---|---|---|---|
| 1 | `join` | 3198 | `join_solana_v2::run` (with `--memo-version v2`), `join_solana::run` (`--solana`/`--wait`/`--renew`, arm 3200), `participant_enrollment::join` (plain, arm 3202) | 6/2/1 | plain: FRIENDS.md path, `welcome-continuity-journey.sh` (runner `welcomecontinuity`), `fleet-journey.sh`, `deploy/candidate/build.sh`; v2: `jpay-v2.sh` (unhooked), `paid-entry-adapter.py`; v1: `jpay-e4.sh` (unhooked), `jpay-bootstrap-budget.py` | plain: runner rows only (results outside repo). v2: none ("runtime qualification remains pending", `jpay-v2.sh:10`). v1: persvati run outside repo (`deploy/pay/README.md`, PAID-COLD-ENTRY.md:162-172) | plain **demo-needed**; v2 wired-but-unrun (tier 3); v1 delete (C 5.4 item 8) |
| 2 | `socket-proxy` | 3204 | `proxy::serve` | 1/1/1 | **deploy** `deploy/shell/mini-socket-proxy:35`; runner row `sshe2e` | runner only | deployed artifact, but README:79 says the node has no proxy mode: **demo-needed** only if proxy mode ships |
| 3 | `workspace` | 3210 | `workspace::run` (76 actions) | 83/5/8 | journey J2–J4, J6, J8 inline, 83 journey files; **deploy** `deploy/candidate/run.sh:237-246`, `deploy/pay/mini-pay-watcher:31`; shell (in-process) | CI 10-16/17/23 J0–J8 PASS (not in docs/evidence); docs/evidence 2026-09-30-candidate | **deployed** |
| 4 | `member` | 3211 | `member::run` (shell `home`) | 2/1/2 | `joined-member-journey.py`, `composed-scenario.py`, `latency-same-store.py` (all ungated) | none | wired-but-unrun |
| 5 | `web` | 3213 | `web::run` | 4/0/0 | WEB (`jweb.sh`), JDV (`jdocuverse.sh`), `doc-search-journey.py` | WEB "blocked" in CI 10-23; never PASS on record; POST and Studio routes never exercised | wired-but-unrun |
| 6 | `operation-proof` | 3215 | `append_proof::run` | 0/0/0 | X: `grain-runtime/src/resident_delivery.rs:716` | one manual qualification (APPEND-PROOF.md:18-22), no evidence dir | unreached as CLI (grain-runtime only) |
| 7 | `enroll` | 3217 | `participant_enrollment::run`; shell `enroll` | 11/0/0 | J1 inline; 11 journey files; `deploy/shell/OPERATOR.md:44-66` onboarding | CI 10-16/17/23 J1 PASS | **deployed** (operator onboarding) |
| 8 | `clock` | 3218 | `clock::run` | 10/3/0 | **deploy** `deploy/clock/mini-clock-tick.service:49` (1/min); KC (`jclock.sh`); jpay2/3/4, jjob1 | KC FAIL 21/32 in all three CI runs; docs/evidence 2026-10-05-clock-law (lane) | **deployed** unit; **KC red** |
| 9 | `checkpoint` | 3219 | `checkpoint::run` | 3/1/2 | **deploy** `deploy/checkpoint/mini-checkpoint-certify.service:24`; `journey_certify` inside `journey.sh:413-432`; KT (`jtail.sh`) | CI KT PASS 12/12; certify runs inside every CI journey | **deployed** |
| 10 | `job` | 3221 | `job::run`; shell `job`/`jobs` | 5/0/0 | JJOB1, JJOB, JJOBM (defined twice) | never reached in CI (after the gate cut); record FAIL instead of UNCONFIGURED without `JOB_PROGRAMS` | wired-but-unrun |
| 11 | `activity` | 3222 | `activity::run` | 5/0/2 | runner rows `activity`, `seats`, `chargedfailure`, `upgrade`, `call`, `send`, `domain`, `objectrecord` via `activity_world.py` | runner only (README: "integrated on scratch worlds") | wired-but-unrun (runner); not in USAGE |
| 12 | `seat` | 3223 | `seat::run` | 2/0/0 | runner rows `seats`, `bounty` | runner only | wired-but-unrun (runner); not in USAGE |
| 13 | `shell` | 3225 | `shell::run` (in-process `main::run` per line) | 17/8/6 | **deploy** `deploy/shell/mini-shell-ssh:23,26`; M4 (`shell-journey.sh`, runner `m4`); Discord entrance via ssh | docs/evidence 2026-09-30-shell-journey 89/89 (lane `m4-shell`, persvati) | **deployed** |
| 14 | `key` | 3229 | `keys::run` (broker client); hiding actions `export-blinding`/`cell-blinding`/`derive-salt` at arm 3738 (`hiding::*`) | 36/4/9 | X: `grain-runtime/src/provider_owner.rs:45` (`owner-status`); KH uses `cell-blinding`, `derive-salt`; shell `key` | KH FAIL "create 3 failed" (CI 10-17); split tenancy "run on no box"; `export-blinding` never called | wired-but-unrun; `export-blinding` unreached |
| 15 | `key-service` | 3235 | tombstone: refuses by name (`main.rs:3235`) | 0/0/0 | none | n/a | unreached: delete |
| 16 | `key-service-config` | 3235 | tombstone: refuses by name (`main.rs:3235`) | 0/0/0 | none | n/a | unreached: delete |
| 17 | `key-namespace` | 3235 | tombstone: refuses by name (`main.rs:3235`) | 0/0/0 | none | n/a | unreached: delete |
| 18 | `fleet` | 3238 | `fleet::run` | 2/0/0 | M8 (`fleet-journey.sh`, runner `m8`); J17; `fleet-contention.sh` | docs/evidence 2026-09-30-fleet-surface (lane, persvati); J17 PASS lane 10-01 | wired (run on record, lane) |
| 19 | `relay` | 3240 | `relay::run_relay` / `run_emit` / `run_witness` / `run_key` | 3/2/0 | KCHR, KCHC | KCHR/KCHC FAIL "no channel library" in all three CI runs (`check-journey.sh` never runs `channel-lib/build.sh`) | **broken** in the gate; not demo |
| 20 | `relay-emit` | 3242 | `relay::run_relay` / `run_emit` / `run_witness` / `run_key` | 1/0/0 | KCHR, KCHC | KCHR/KCHC FAIL "no channel library" in all three CI runs (`check-journey.sh` never runs `channel-lib/build.sh`) | **broken** in the gate; not demo |
| 21 | `relay-witness` | 3244 | `relay::run_relay` / `run_emit` / `run_witness` / `run_key` | 2/0/0 | KCHR, KCHC | KCHR/KCHC FAIL "no channel library" in all three CI runs (`check-journey.sh` never runs `channel-lib/build.sh`) | **broken** in the gate; not demo |
| 22 | `relay-key` | 3246 | `relay::run_relay` / `run_emit` / `run_witness` / `run_key` | 2/0/0 | KCHR, KCHC | KCHR/KCHC FAIL "no channel library" in all three CI runs (`check-journey.sh` never runs `channel-lib/build.sh`) | **broken** in the gate; not demo |
| 23 | `channel` | 3248 | `channel::run`; shell `channel` | 2/0/0 | KCHC | FAIL "no channel library" in all three CI runs | **broken** in the gate; not demo |
| 24 | `traffic` | 3250 | `scheduled_transport::run` | 0/0/0 | none | TRAFFIC-PRIVACY.md cites private hbox runs only | unreached; not in USAGE |
| 25 | `mix` | 3252 | `pq_mailbox::run` | 0/0/0 | `cohort-native-tcp.py` (root, ungated); the cited `qualification/pq-native-pipeline.py` does not exist | docs/evidence/traffic-v13 (2026-10-04/08, lane W15) | unreached by any gate (evidence-only); not in USAGE |
| 26 | `mix-live` | 3254 | `cohort_tcp::run` | 0/0/0 | `cohort-native-tcp.py`, `cohort-two-host/*`; `native/resource-client/scripts/cohort-native-tcp.py` passes `--key` (broken) | docs/evidence/traffic-v13 two-host PASS | unreached by any gate (evidence-only); not in USAGE |
| 27 | `adopt-next-key` | 3256 | `key_adoption::run`; shell verb | 0/1/0 | `deploy/hermes-dispatch/receiving.py`; `journey-key-adoption.py` (ungated) | none: "remains unverified" (KEY-ADOPTION.md:122-124) | wired-but-unrun |
| 28 | `rotate-key` | 3258 | `key_rotation::rotate_key`; shell verb | 3/1/0 | JROT (runner `journey`), JPRIV1 | README: JROT 3 of 30 checks red at `4795b657` (runner, outside repo) | **broken**: a refused rotation wedges the workspace (D F-1); JROT red |
| 29 | `key-status` | 3260 | `key_rotation::key_status`; shell verb | 3/0/1 | JROT, JROTL (runner `journey`) | README: JROTL PASS at `4795b657` (runner, outside repo) | wired (runner) |
| 30 | `credit` | 3262 | `credit::run`; shell `credit`/`pay ROOM`/`tariff`/`topup`/`room status`; `hermes.rs:618-793`; grain-runtime concierge | 2/0/0 | J17, J14 | docs/evidence 2026-10-01-p-credit J17 PASS (lane, frontier J6) | wired (lane run); tier 2; C F2 hazard |
| 31 | `hermes-handoff` | 3263 | `hermes_handoff::run` | 0/2/0 | `deploy/hermes-dispatch/*.py` (no unit); X: `grain-runtime/src/hermes_room.rs:516,526` | none located | wired-but-unrun; not in USAGE |
| 32 | `story-law` | 3265 | `story::law_command` | 0/1/1 | `scripts/gen-storylaw.py` (regenerates `Assurance/StoryLaw.lean`) | used as a generator | tooling (the Rust emitter Lean imitates; F V1) |
| 33 | `well` | 3266 | `well::run` | 4/0/0 | KW; `objective-seat-native-acceptance.py`, `objective-bounty-native-acceptance.py` | KW cascade-FAIL 10-23; runner only otherwise | wired-but-unrun; C F1 double-mint hazard |
| 34 | `pay` | 3267 | `pay::run` | 12/3/0 | **deploy** `deploy/pay/mini-pay-watcher:77,102` (inactive on node); JPAY2/3/4/6, JPAYE2/3 (runner `jpay`) | 2026-10-02 composed rehearsal (outside docs/evidence); JPAY3 on lane 2026-10-05-clock-law | wired-but-unrun (unit inactive); tier 3 |
| 35 | `pay-claim` | 3269 | `pay_claim::run` | 0/0/0 | `jpay-v2.sh` (unhooked, never passed); `jpay-claim-law-tests.sh` tests a jq file | none | unreached by any run; tier 3 |
| 36 | `enrollment-bootstrap` | 3271 | `enrollment_bootstrap::run` (HTTP) | 2/0/0 | `jpay-e4.sh`, `jpay-bootstrap-budget.py` (both unhooked); no deploy unit (only a Caddyfile template) | persvati runs outside repo (PAID-COLD-ENTRY.md:162-172) | wired-but-unrun; tier 3 |
| 37 | `enrollment-view` | 3272 | `main.rs::enrollment_view` (op 112, op 8; **v1 envelope**) | 3/0/0 | `jpay-bootstrap-budget.py`, `jpay-e*` | outside repo only | wired-but-unrun; tier 3 |
| 38 | `selected-exchange` | 3280 | `selected_exchange::run` | 1/0/0 | runner row `exchange` (`selected-exchange-journey.sh`) | docs/evidence 2026-10-08-selected-exchange-local-fn: PASS ×2 + one planted FAIL on `0ea31db5` (main lineage); phases `receive`, `cover-*`, `ack`, `verify` never run | wired (run on record); not demo |
| 39 | `serve` | 3291 | `transport::serve` | 55/7/18 | **deploy** `deploy/candidate/run.sh:157,182,261`, `deploy/grain-host/install-operator-stack:133`; 55 journey files | CI every run | **deployed** |
| 40 | `consent-resident` | 3306 | `client_consent::resident` | 0/0/0 | **self-spawned** by every signing `mini` process (`client_consent.rs:418-420`, checked) | implicitly in every CI journey | **deployed** (internal); not in USAGE. A lists it as unreached (section 9) |
| 41 | `serve-operator` | 3313 | `transport::serve_operator` | 3/0/2 | `platform-provision.py:58`; `jpay-e4.sh:147`, `jpay-v2.sh:151`, `jpay-bootstrap-budget.py:66` | outside repo only | wired-but-unrun; `--peer-uid` dead and dangerous (B 5.2) |
| 42 | `serve-public-proxy` | 3326 | `public_proxy::serve` | 3/0/1 | `platform-provision.py:59`; jpay journeys; `public-ingress-process.py` (echo Host) | PUBLIC-INGRESS.md:63-81 (persvati, echo Host, outside repo) | wired-but-unrun |
| 43 | `operator-status` | 3338 | `operator_drain::command` | 0/0/0 | X: `grain-runtime/src/quiescence_transport.rs:424`, `resident_preflight.rs:51`; `platform-service-cut.py`, `latency-same-store.py`, `public-ingress-process.py` | none in repo | wired-but-unrun (grain-runtime, platform tooling) |
| 44 | `drain-operator` | 3338 | `operator_drain::command` | 0/0/0 | X: `grain-runtime/src/quiescence_transport.rs:424`, `resident_preflight.rs:51`; `platform-service-cut.py`, `latency-same-store.py`, `public-ingress-process.py` | none in repo | wired-but-unrun (grain-runtime, platform tooling) |
| 45 | `host-command` | 3349 | `main.rs::host_command` | 0/0/0 | none | none | unreached |
| 46 | `consumer-poll` | 3357 | `main.rs::consumer_poll` (op 12/14), `consumer_ack` (op 13/15) | 0/0/2 | only `.patch` files under `scripts/fn-e1e2` | none | unreached |
| 47 | `reply-consumer-poll` | 3357 | `main.rs::consumer_poll` (op 12/14), `consumer_ack` (op 13/15) | 0/0/0 | only `.patch` files under `scripts/fn-e1e2` | none | unreached |
| 48 | `consumer-ack` | 3377 | `main.rs::consumer_poll` (op 12/14), `consumer_ack` (op 13/15) | 0/0/2 | only `.patch` files under `scripts/fn-e1e2` | none | unreached |
| 49 | `reply-consumer-ack` | 3377 | `main.rs::consumer_poll` (op 12/14), `consumer_ack` (op 13/15) | 0/0/0 | only `.patch` files under `scripts/fn-e1e2` | none | unreached |
| 50 | `origin-outbox-prepare` | 3402 | `main.rs::origin_outbox_prepare` (op 16) | 0/0/0 | none (in-process from `publisher.rs`) | 2026-09-26 lane only | unreached |
| 51 | `origin-outbox-export` | 3417 | `main.rs::origin_outbox_export` (op 18, **v1 envelope**) | 0/0/0 | none | 2026-09-26 lane only | unreached |
| 52 | `origin-publish` | 3435 | `publisher::publish` | 0/0/0 | none | manual run 2026-09-26 (`docs/evidence/2026-09-26-workroom-content-publisher/`) | unreached |
| 53 | `provider-continuity` | 3461 | `provider_continuity::resolve_attempt` | 0/0/0 | X: `grain-runtime/src/provider_resolution.rs:387`, `provider_continuity_rejection.rs:128,359,361` | none located | wired-but-unrun (grain-runtime) |
| 54 | `continuity` | 3476 | `main.rs::continuity` (op 17, legacy framing) | 0/0/0 | X: `grain-runtime/src/main.rs:9837` | none located | wired-but-unrun (grain-runtime) |
| 55 | `meter` | 3492 | `meter::meter` (op 19) | 0/0/0 | X: `grain-runtime/src/main.rs:10125`, `hermes_outcome.rs:96` | J14 lane 10-01 (through Hermes) | wired-but-unrun (grain-runtime) |
| 56 | `consumer-drain-once` | 3512 | `drain::run`, `drain::run_reply` | 0/0/0 | none | docs/evidence 2026-09-26-host-session, 2026-09-26-mini-a-worker (lane) | unreached; B: `drain.rs:1303-1310` wedge bug |
| 57 | `reply-consumer-drain-once` | 3512 | `drain::run`, `drain::run_reply` | 0/0/0 | none | docs/evidence 2026-09-26-host-session, 2026-09-26-mini-a-worker (lane) | unreached; B: `drain.rs:1303-1310` wedge bug |
| 58 | `consumer-resume-ack` | 3546 | `drain::resume_held_ack`, `resume_held_reply_ack` | 0/0/0 | none | 2026-09-26 lane | unreached |
| 59 | `reply-consumer-resume-ack` | 3546 | `drain::resume_held_ack`, `resume_held_reply_ack` | 0/0/0 | none | 2026-09-26 lane | unreached |
| 60 | `consumer-host-upgrade` | 3569 | `drain::upgrade_host` | 0/0/0 | none | none | unreached |
| 61 | `consumer-worker` | 3603 | `worker::run`, `worker::run_reply` | 0/0/0 | none (no unit) | 2026-09-26 lane | unreached |
| 62 | `reply-consumer-worker` | 3603 | `worker::run`, `worker::run_reply` | 0/0/0 | none (no unit) | 2026-09-26 lane | unreached |
| 63 | `store` | 3625 | `main.rs::store_run` (Host `store-audit`) | 10/11/18 | JAUDIT (runner `journey`), M7 (runner `m7`), `jhostupgrade.sh` (runner `hostupgrade`); counts inflated by `mini-store` | docs/evidence 2026-09-30-candidate (M7 PASS, lane) | **demo-needed** (JAUDIT in the demo journey set) |
| 64 | `audit` | 3626 | Host `audit` through `process` | 18/0/1 | 18 journey files (most K hooks) | CI, inside the K hooks | **demo-needed** |
| 65 | `profile` | 3638 | `process` (op 6, op 0) | 3/0/4 | profile: JPAY6, 3 journey files; describe: 1 | runner only | wired; keep (op 0 and 6 are the probes) |
| 66 | `describe` | 3638 | `process` (op 6, op 0) | 1/0/2 | profile: JPAY6, 3 journey files; describe: 1 | runner only | wired; keep (op 0 and 6 are the probes) |
| 67 | `enc-public` | 3650 | `roomkey::enc_public_hex`, `enc_key_id_hex` (shell `whoami` uses the latter in-process) | 0/0/0 | none | none | unreached |
| 68 | `enc-key-id` | 3661 | `roomkey::enc_public_hex`, `enc_key_id_hex` (shell `whoami` uses the latter in-process) | 0/0/0 | none | none | unreached |
| 69 | `escrow-recover` | 3673 | `private::recover_escrowed_seed` | 0/0/0 | none | none | unreached |
| 70 | `keygen` | 3696 | `main.rs::keygen` (uses `private.rs` notice, marker, escrow) | 31/2/9 | **deploy** `deploy/candidate/run.sh:79,84`; 31 journey files; shell `keygen` | CI J0 PASS | **deployed** |
| 71 | `verify-view` | 3729 | `hiding::verify_view` | 1/0/0 | KH (`jhide.sh`) | KH FAIL "create 3 failed" (CI 10-17) | wired, KH red (probably a script lag behind K-FIELD-CLOSURE, G Q8) |
| 72 | `bootstrap` | 3807 | `main.rs::bootstrap` | 16/2/7 | **deploy** `deploy/candidate/run.sh:91`; J0 via `newparticipant-acceptance.sh` | CI J0 PASS | **deployed** |
| 73 | `author` | 3818 | `main.rs::author` (local codec) | 5/1/5 | J12X, JSERVE (CI), J5 stranger leg | CI J12X 20/20, JSERVE 12/12 | **demo-needed** |
| 74 | `inspect` | 3827 | `main.rs::inspect_public` | 1/1/0 | JGATE (runner `journey`) | runner only | **demo-needed** (operator diagnosis) |
| 75 | `current-application-intent` | 3841 | `current_birth::author` | 0/0/3 | X: `grain-runtime/src/main.rs:10844-10845`; `scripts/application-current-birth/*` | docs/evidence 2026-09-30-newcomer-provisioning (via workspace in-process) | wired-but-unrun as commands (grain-runtime) |
| 76 | `current-session-intent` | 3841 | `current_birth::author` | 0/0/1 | X: `grain-runtime/src/main.rs:10844-10845`; `scripts/application-current-birth/*` | docs/evidence 2026-09-30-newcomer-provisioning (via workspace in-process) | wired-but-unrun as commands (grain-runtime) |
| 77 | `current-resource-intent` | 3841 | `current_birth::author` (workspace calls it in-process, `workspace.rs:4742`) | 0/0/0 | none as a command | n/a | unreached as a command (the function is demo-needed) |
| 78 | `agent-reserve-plan` | 3869 | `agent_reserve::*` (event21, ops 58/59) | 0/0/0 | X: `grain-runtime/src/main.rs:4748-4996` | docs/evidence 2026-09-27-agent-payer-client, -agent-participant-payer-split (lane) | wired-but-unrun (grain-runtime) |
| 79 | `agent-reserve-seal` | 3887 | `agent_reserve::*` (event21, ops 58/59) | 0/0/0 | X: `grain-runtime/src/main.rs:4748-4996` | docs/evidence 2026-09-27-agent-payer-client, -agent-participant-payer-split (lane) | wired-but-unrun (grain-runtime) |
| 80 | `agent-reserve-submit` | 3894 | `agent_reserve::*` (event21, ops 58/59) | 0/0/0 | X: `grain-runtime/src/main.rs:4748-4996` | docs/evidence 2026-09-27-agent-payer-client, -agent-participant-payer-split (lane) | wired-but-unrun (grain-runtime) |
| 81 | `agent-reserve-lookup` | 3900 | `agent_reserve::*` (event21, ops 58/59) | 0/0/0 | X: `grain-runtime/src/main.rs:4748-4996` | docs/evidence 2026-09-27-agent-payer-client, -agent-participant-payer-split (lane) | wired-but-unrun (grain-runtime) |
| 82 | `agent-lifetime-reserve-plan` | 3906 | `agent_reserve::lifetime_*` (`lifetime_v3.rs`, ops 80/81) | 0/0/0 | X: `grain-runtime/src/main.rs:4311-4595` | docs/evidence 2026-09-27-spk-lifetime-paid-native (lane) | wired-but-unrun (grain-runtime) |
| 83 | `agent-lifetime-reserve-seal` | 3924 | `agent_reserve::lifetime_*` (`lifetime_v3.rs`, ops 80/81) | 0/0/0 | X: `grain-runtime/src/main.rs:4311-4595` | docs/evidence 2026-09-27-spk-lifetime-paid-native (lane) | wired-but-unrun (grain-runtime) |
| 84 | `agent-lifetime-reserve-submit` | 3931 | `agent_reserve::lifetime_*` (`lifetime_v3.rs`, ops 80/81) | 0/0/0 | X: `grain-runtime/src/main.rs:4311-4595` | docs/evidence 2026-09-27-spk-lifetime-paid-native (lane) | wired-but-unrun (grain-runtime) |
| 85 | `agent-lifetime-reserve-lookup` | 3937 | `agent_reserve::lifetime_*` (`lifetime_v3.rs`, ops 80/81) | 0/0/0 | X: `grain-runtime/src/main.rs:4311-4595` | docs/evidence 2026-09-27-spk-lifetime-paid-native (lane) | wired-but-unrun (grain-runtime) |
| 86 | `agent-lifetime-paid-plan` | 3943 | `agent_reserve::lifetime_paid_*` (`paid.rs`, op 78) | 0/0/0 | X: `grain-runtime/src/main.rs:5339,5432` | docs/evidence 2026-09-27-agent-lifetime-paid-client{,-linux} (lane) | wired-but-unrun (grain-runtime) |
| 87 | `agent-lifetime-paid-payer-sign` | 3951 | `agent_reserve::lifetime_paid_*` (`paid.rs`, op 78) | 0/0/0 | X: `grain-runtime/src/main.rs:5339,5432` | docs/evidence 2026-09-27-agent-lifetime-paid-client{,-linux} (lane) | wired-but-unrun (grain-runtime) |
| 88 | `agent-lifetime-paid-seal` | 3958 | `agent_reserve::lifetime_paid_*` (ops 79/76/77) | 0/0/0 | none; the live path is `spk-host` (`agent_api_lifetime_paid_native_v3.rs:183`, `agent_api_lifetime_dispatch_native_v3.rs:167`) | 2026-09-27 lane only | unreached and **broken** (lookup after submit always fails, C F3): delete |
| 89 | `agent-lifetime-paid-submit` | 3965 | `agent_reserve::lifetime_paid_*` (ops 79/76/77) | 0/0/0 | none; the live path is `spk-host` (`agent_api_lifetime_paid_native_v3.rs:183`, `agent_api_lifetime_dispatch_native_v3.rs:167`) | 2026-09-27 lane only | unreached and **broken** (lookup after submit always fails, C F3): delete |
| 90 | `agent-lifetime-paid-lookup` | 3971 | `agent_reserve::lifetime_paid_*` (ops 79/76/77) | 0/0/0 | none; the live path is `spk-host` (`agent_api_lifetime_paid_native_v3.rs:183`, `agent_api_lifetime_dispatch_native_v3.rs:167`) | 2026-09-27 lane only | unreached and **broken** (lookup after submit always fails, C F3): delete |
| 91 | `agent-lifetime-grant-plan` | 3977 | `agent_lifetime_grant::*` | 0/0/1 | `scripts/spk-platform/issue-agent-lifetime-grant.sh:202,230` only | none specific | wired-but-unrun (script only) |
| 92 | `agent-lifetime-grant-seal` | 3987 | `agent_lifetime_grant::*` | 0/0/1 | `scripts/spk-platform/issue-agent-lifetime-grant.sh:202,230` only | none specific | wired-but-unrun (script only) |
| 93 | `agent-lifetime-grant-submit` | 3994 | `agent_lifetime_grant::*` | 0/0/1 | `scripts/spk-platform/issue-agent-lifetime-grant.sh:202,230` only | none specific | wired-but-unrun (script only) |
| 94 | `agent-lifetime-grant-lookup` | 4000 | `agent_lifetime_grant::*` | 0/0/1 | `scripts/spk-platform/issue-agent-lifetime-grant.sh:202,230` only | none specific | wired-but-unrun (script only) |
| 95 | `session-reenroll` | 4006 | `session_reenroll::run` | 0/0/0 | `scripts/spk-platform/ws-continuity-fixture.py` (fixture); `deploy/spk-host/SAME-STORE-AND-CHECKPOINT.md` (doc) | none ("not yet qualified", SESSION-REENROLL.md:151-158) | unreached; exits 0 on refusal (D F-5); raw session close (D S-1) |
| 96 | `session-enrollment-plan` | 4023 | `session_enrollment::*` | 0/0/3 | `scripts/session-enrollment/native-acceptance.sh`, `scripts/spk-platform/grain-journey.sh` | docs/evidence 2026-09-27-session-enrollment{,-client} (lane) | wired-but-unrun (script only) |
| 97 | `session-enrollment-seal` | 4033 | `session_enrollment::*` | 0/0/2 | `scripts/session-enrollment/native-acceptance.sh`, `scripts/spk-platform/grain-journey.sh` | docs/evidence 2026-09-27-session-enrollment{,-client} (lane) | wired-but-unrun (script only) |
| 98 | `session-enrollment-submit` | 4040 | `session_enrollment::*` | 0/0/2 | `scripts/session-enrollment/native-acceptance.sh`, `scripts/spk-platform/grain-journey.sh` | docs/evidence 2026-09-27-session-enrollment{,-client} (lane) | wired-but-unrun (script only) |
| 99 | `session-enrollment-lookup` | 4046 | `session_enrollment::*` | 0/0/2 | `scripts/session-enrollment/native-acceptance.sh`, `scripts/spk-platform/grain-journey.sh` | docs/evidence 2026-09-27-session-enrollment{,-client} (lane) | wired-but-unrun (script only) |
| 100 | `agent-payer-sign` | 4052 | `agent_payer::sign` (op 48) | 0/0/0 | X: `grain-runtime/src/main.rs:5672` | docs/evidence 2026-09-27-agent-payer-client (lane) | wired-but-unrun (grain-runtime) |
| 101 | `share-issue-prepare` | 4074 | `share_issue::*` (event 15) | 0/0/1 | `scripts/application-share-issue/native-acceptance.sh`, `scripts/spk-platform/issue-*.sh` | docs/evidence 2026-09-27-application-share-issue-* (lane) | wired-but-unrun (script only) |
| 102 | `share-issue-submit` | 4087 | `share_issue::*` (event 15) | 0/0/1 | `scripts/application-share-issue/native-acceptance.sh`, `scripts/spk-platform/issue-*.sh` | docs/evidence 2026-09-27-application-share-issue-* (lane) | wired-but-unrun (script only) |
| 103 | `share-issue-lookup` | 4093 | `share_issue::*` (event 15) | 0/0/1 | `scripts/application-share-issue/native-acceptance.sh`, `scripts/spk-platform/issue-*.sh` | docs/evidence 2026-09-27-application-share-issue-* (lane) | wired-but-unrun (script only) |
| 104 | `share-issue-receipt-lookup` | 4099 | `share_issue_receipt::lookup` | 0/0/0 | X: `grain-runtime/src/shared_app_refs.rs:112,657` | docs/evidence 2026-09-27-shared-app-recipient-refs (lane) | wired-but-unrun (grain-runtime) |
| 105 | `grain-share-issue-plan` | 4131 | `grain_share_issue::*` (event 22) | 0/0/4 | `scripts/spk-platform/*`, `scripts/application-share-issue/*` | docs/evidence 2026-09-27-application-share-issue-grain*, -grain-share-plan-preview (lane) | wired-but-unrun (script only) |
| 106 | `grain-share-issue-prepare` | 4143 | `grain_share_issue::*` (event 22) | 0/0/5 | `scripts/spk-platform/*`, `scripts/application-share-issue/*` | docs/evidence 2026-09-27-application-share-issue-grain*, -grain-share-plan-preview (lane) | wired-but-unrun (script only) |
| 107 | `grain-share-issue-submit` | 4156 | `grain_share_issue::*` (event 22) | 0/0/6 | `scripts/spk-platform/*`, `scripts/application-share-issue/*` | docs/evidence 2026-09-27-application-share-issue-grain*, -grain-share-plan-preview (lane) | wired-but-unrun (script only) |
| 108 | `grain-share-issue-lookup` | 4162 | `grain_share_issue::*` (event 22) | 0/0/8 | `scripts/spk-platform/*`, `scripts/application-share-issue/*` | docs/evidence 2026-09-27-application-share-issue-grain*, -grain-share-plan-preview (lane) | wired-but-unrun (script only) |
| 109 | `grain-share-issue-receipt-lookup` | 4168 | `share_issue_receipt::lookup_grain` (op 55, operator-only in the registry) | 0/0/0 | X: `grain-runtime/src/shared_app_refs.rs:113,661` | 2026-09-27 lane | wired-but-unrun; uses an operator-only op for a recipient (D F-14) |
| 110 | `historical-call-receipt-lookup` | 4200 | `historical_call_receipt::lookup` (also in-process from `hermes_handoff.rs:349`) | 0/0/0 | X: `grain-runtime/src/main.rs:7673` | none located | wired-but-unrun (grain-runtime); bypasses continuity (E F6) |
| 111 | `fn-namespace-plan` | 4232 | `fn_namespace::*` (ops 40-43) | 0/0/0 | none | manual r3 2026-09-27: op 40 refused, op 41 absent (`docs/evidence/2026-09-27-fn-namespace-native-r3/`) | unreached |
| 112 | `fn-namespace-register` | 4241 | `fn_namespace::*` (ops 40-43) | 0/0/0 | none | manual r3 2026-09-27: op 40 refused, op 41 absent (`docs/evidence/2026-09-27-fn-namespace-native-r3/`) | unreached |
| 113 | `fn-namespace-lookup` | 4252 | `fn_namespace::*` (ops 40-43) | 0/0/0 | none | manual r3 2026-09-27: op 40 refused, op 41 absent (`docs/evidence/2026-09-27-fn-namespace-native-r3/`) | unreached |
| 114 | `fn-frontier-plan` | 4261 | `fn_frontier::*` (ops 60-65); also `selected-exchange --phase cover-*` (itself unreached) | 0/0/0 | none | unit, clippy and fmt logs only (`2026-09-27-fn-frontier-receiving/`) | unreached |
| 115 | `fn-frontier-advance` | 4281 | `fn_frontier::*` (ops 60-65); also `selected-exchange --phase cover-*` (itself unreached) | 0/0/0 | none | unit, clippy and fmt logs only (`2026-09-27-fn-frontier-receiving/`) | unreached |
| 116 | `fn-frontier-lookup` | 4292 | `fn_frontier::*` (ops 60-65); also `selected-exchange --phase cover-*` (itself unreached) | 0/0/0 | none | unit, clippy and fmt logs only (`2026-09-27-fn-frontier-receiving/`) | unreached |
| 117 | `submit` | 4300 | `main.rs::submit_with_continuity` / `submit` | 58/0/29 | 58 journey files, 29 scripts; shell (in-process) | CI J0–J8 PASS | **deployed** |
| 118 | `query` | 4328 | `main.rs::query` (optional `workspace::load`) | 10/1/26 | 10 journey files, 26 scripts; shell (in-process) | CI J0–J8 PASS | **deployed** |
| 119 | `objective-invoke` | 4373 | `objective_invoke::submit` | 1/0/0 | runner row `objective` (`objective-native-acceptance.py`) | README: 17 rows PASS at `4795b657` (runner, outside repo) | wired (runner) |
| 120 | `retry` | 4390 | `main.rs::retry` (`--mode lookup|submit`, exact `call.bin`) | 7/0/8 | J6 inline, BD, acceptance scripts; shell `retry` (resubmits) and `lookup` | CI J6 PASS ("exact retry replays the original receipt") | **deployed** |
| 121 | `selected-release-submit` | 4411 | `selected_release::submit` / `main.rs::selected_release_sign` / `selected_release::lookup` | 2/0/0 | runner row `exchange`; `selected-release-acceptance.sh` (broken) | 2026-10-08 exchange PASS; acceptance script fails on current code (schemaVersion "1", TRAFFIC-PRIVACY.md:206-211) | wired (run on record); not demo |
| 122 | `selected-release-sign` | 4423 | `selected_release::submit` / `main.rs::selected_release_sign` / `selected_release::lookup` | 2/0/0 | runner row `exchange`; `selected-release-acceptance.sh` (broken) | 2026-10-08 exchange PASS; acceptance script fails on current code (schemaVersion "1", TRAFFIC-PRIVACY.md:206-211) | wired (run on record); not demo |
| 123 | `selected-source-sign` | 4433 | `selected_publisher::sign_source` / `publish` (Host CLI ops 24/25) | 1/0/0 | runner row `exchange` (inside prepare/publish); `selected-source-publisher-acceptance.sh` (never run) | 2026-10-08 via exchange | wired (run on record); not demo |
| 124 | `selected-source-publish` | 4447 | `selected_publisher::sign_source` / `publish` (Host CLI ops 24/25) | 1/0/0 | runner row `exchange` (inside prepare/publish); `selected-source-publisher-acceptance.sh` (never run) | 2026-10-08 via exchange | wired (run on record); not demo |
| 125 | `selected-release-lookup` | 4458 | `selected_release::submit` / `main.rs::selected_release_sign` / `selected_release::lookup` | 1/0/0 | runner row `exchange`; `selected-release-acceptance.sh` (broken) | 2026-10-08 exchange PASS; acceptance script fails on current code (schemaVersion "1", TRAFFIC-PRIVACY.md:206-211) | wired (run on record); not demo |
| 126 | `selected-release-retry` | 4464 | `selected_release::retry_submit` | 0/0/0 | none | none | unreached |
| 127 | `export-evidence` | 4469 | Host CLI through `host_files` | 0/0/0 | none | none | unreached |
| 128 | `verify-evidence` | 4484 | Host CLI through `host_files` | 0/0/0 | none | none | unreached |
| 129 | `bend-session-sign` | 4508 | `bend_session::run` (pre-parse) | n/a | none (only `.spw` maps mention it) | none | unreached; not in USAGE |
| 130 | `fleet-sign` | 4514 | `fleet_sign::run` (pre-parse); `dregg-client-sign` shim | n/a | runner row `fleetsign` (`fleet-sign-journey.sh`); `fleet-sign-growth.sh`, `fleet-migration-replay.sh` | docs/evidence 2026-10-06-fleet-migration (`result: pass`, 31 calls; lane) | wired (run on record); D F-3 double-commit hazard; omitted from `rc-A/arm-module.tsv` |

**Totals** (130 names):

| Verdict | Count | Names |
|---|---:|---|
| deployed | 12 (+1) | `serve`, `shell`, `workspace`, `keygen`, `bootstrap`, `enroll`, `submit`, `query`, `retry`, `clock` (KC red), `checkpoint`, `consent-resident` (self-spawned); plus `socket-proxy`, which has a deploy artifact although proxy mode is off on the node |
| demo-needed | 5 | `join` (plain), `store` (audit), `audit`, `author`, `inspect` |
| wired (run on record) | 14 | `fleet`, `fleet-sign`, `key-status`, `credit`, `selected-exchange`, `selected-release-{submit,sign,lookup}`, `selected-source-{sign,publish}`, `objective-invoke`, `profile`, `describe`, `verify-view` |
| wired-but-unrun | 50 | everything driven only by grain-runtime (about 23 names), only by `scripts/` (15 names), or by ungated or uncompleted journeys (`member`, `web`, `job`, `activity`, `seat`, `key`, `hermes-handoff`, `well`, `pay`, `enrollment-bootstrap`, `enrollment-view`, `serve-operator`, `serve-public-proxy`, `adopt-next-key`, ...) |
| unreached | 41 | the 3 tombstones; `traffic`, `mix`, `mix-live` (evidence-only); `host-command`; the 12 fn-consumer and origin names; 6 `fn-namespace-*`/`fn-frontier-*`; `pay-claim`; `enc-public`, `enc-key-id`, `escrow-recover`; `current-resource-intent`; `agent-lifetime-paid-{seal,submit,lookup}` (also broken); `session-reenroll`; `selected-release-retry`; `export-evidence`, `verify-evidence`; `bend-session-sign`; `operation-proof` as a CLI |
| broken | 6 | `relay`, `relay-emit`, `relay-witness`, `relay-key`, `channel` (the gate never builds the channel library); `rotate-key` (D F-1 wedge, JROT 3/30 red) |
| tooling | 1 | `story-law` (generator for `Assurance/StoryLaw.lean`) |

**What this means for deletion.**
- **Delete outright** (41 unreached names, no product loses anything): the 12 fn-consumer and origin arms plus `main.rs:2575-3129`; the 6 fn-custody arms; `traffic`/`mix`/`mix-live` with the three stacks; `session-reenroll`; `agent-lifetime-paid-{seal,submit,lookup}`, a broken twin of spk-host; `export-evidence`/`verify-evidence`, `host-command`, `enc-*`, `escrow-recover`, `selected-release-retry`, `bend-session-sign`; the tombstones.
- **Delete with the grain-runtime and SPK product decision** (about 39 names): every `agent-*`, `share-issue-*`, `grain-share-issue-*`, `session-enrollment-*`, `current-{application,session}-intent`, `historical-call-receipt-lookup`, `provider-continuity`, `continuity`, `meter`, `operation-proof`, `hermes-handoff`, `operator-status`, `drain-operator`. Each is a subprocess call from `grain-runtime` (`rc-A/other-crate-callers.txt`). These cannot go until grain-runtime calls a library or loses the feature.
- **Keep for the demo** (17): the 12 deployed, `socket-proxy`, `join`, `store`, `audit`, `author`, `inspect`. Add `profile`/`describe` as probes.
- **Undocumented live commands.** `USAGE` omits 12 live commands (section 1.2). `mini` with no arguments exits 0 (A F10), so a script with an empty variable "succeeds".

---

## 3. Where Rust decides semantics, crate-wide

This merges every section-3 row of A–G, deduplicated, and ranks the rows by blast radius. Authority and money come first, then law content, privacy, double operations, availability, shared conventions and presentation.

- **IS**: nothing on the Lean side refuses if Rust gets it wrong.
- **MIRROR**: Rust pre-checks or re-derives what Lean decides again.
- **ORACLE**: an external fact Lean cannot check by construction.
- **POLICY**: a Rust choice that bounds availability or UX, not authority.

Where a reader named the Lean module that should own the decision, it is given. Otherwise the cell says what is missing, as a question.

| # | Site | What Rust decides | Class | Lean counterpart that should own it | Blast radius | Source |
|---:|---|---|---|---|---|---|
| 1 | `transport.rs:308-618` (`allowed_operation`, `allowed_operator_operation`) | Which socket may invoke each op. 69 ops are operator-only (22-23, 26-27, 32-85 except 28-31, 117-120, 152, 154, 164, 206-209), and **only** this routing protects them: `dispatchSession` receives `(op, payload)` and nothing about the caller (`Host/Main.lean:2006-2011`). Op 42 takes "all selectors from pinned operator settings" (`transport.rs:554-556`). | IS (by design, a physical boundary, but a single point of failure) | None today. A per-receiver caller check, or at least a Lean statement of which operator ops are safe against any caller (Q15). The registry check (`scripts/host-operations.py`) compares Rust against hand-written JSON. | Any operator op becomes publicly invocable if a list, a socket mode (`--peer-uid`, B 5.2) or a directory mode slips. | B 3.1 |
| 2 | `genesis.sh:115-219` (shipped as the candidate's genesis template, `deploy/candidate/package.py:106-107`) | Every genesis field, including a permit-all `factoryPredicate` (`:125`) and permit-all `accountPredicate` for sponsor and clock subject (`:136`, `:146`). | IS (semantic default chosen in jq; Lean admits it at bootstrap) | A Lean genesis author for `minidregg-candidate-genesis-params-v1`; `Host/Json.lean:3805` already lists a `genesis` kind (Q24) | Every deployed Store's factory law: anyone holding a factory observe grant may birth under it. | G 3.1 |
| 3 | `shell.rs:147-162` `document_law`, `:172-187` `room_law`, `:709-719` `board_law`; `web_create.rs:237` | The **content of the laws** on every shell- or web-created document, room and board: "draft" = payload ≤ 16384 on mutate, "note" = no edits or tombstones, "realm" = only founder and referees may `place`, board = monotone state with write-once owner on fields 2-5. | IS | Lean-emitted law templates, as the job law already is (`Kernel/Job.lean` → `scripts/gen-joblaw.py` → `deploy/shell/templates/job/law.job.{shell,json}`) (Q25) | Who may write every demo document and board. A typo silently changes it. | A D1 |
| 4 | `fleet.rs:1084-1091`; `deploy/shell/OPERATOR.md:66-70` (`permit-all.json`); `hermes.rs:621-625` (`credit-permit-all.json` till), `:637` (budget account `all[]`); `roomkey.rs:146-148` (`law.room.json` = `all[]` for `room new --private`) | Default law of every fleet-joined account, every shell-provisioned member account, the Hermes till and budget account, and the private room cell: **permit-all**. | IS | A Lean-emitted default account or room policy (Q26) | Every member account on the demo node runs under a law that admits any step its capabilities allow. | D S-4, F V6 |
| 5 | `story.rs:146-381` (`table_of`, `player_clauses`, `table_sealed_law`, `staging_law`, `scenes_law`); `my_cell` `:987-1006` | Which story tables are valid, and the exact law installed on every player's cell. `Assurance/StoryLaw.lean` proves theorems about a Lean `law` that `scripts/gen-storylaw.py` makes **equal by `rfl` to this generator's output for the one built-in tale only**. | IS (law 13 inverted: Rust emits, Lean imitates) | `Assurance/StoryLaw.lean` `law`/`clauses` as the emitter (a Host `author story-law`), plus a Lean table checker (Q27) | A generator bug installs a law that does not enforce the table. Players' clients accept it, because they compare against the same generator. | F V1 |
| 6 | `chat.rs:137` (`law.author.json`), `roomkey.rs:133-135` (keys and room laws) via `include_str!`; test `the_template_laws_are_the_ones_the_lean_theorems_name` compares a template with a literal | Chat author law and private-room keys law are Rust-crate template files, not Lean artifacts. | IS (template not emitted) | `Kernel/PrivateRoomKeys.lean` (`keysLaw`) and a chat-room law module to emit them | Room write and wrap discipline. | F 12, F 5.5 |
| 7 | `chat.rs:1979`, `hermes.rs:522`, `story.rs:878`, `roomkey.rs:2145` | `maxCost "50000"` on every delegation the composing verbs create. | IS | The room tariff (`room_schema::TARIFF_FIELDS`), or a Lean-emitted delegation template | The spend ceiling of every room grant. | F V6 |
| 8 | `market.rs:271-286` (`clear`), proposed by `settle` `:476-504` | The whole sealed-market allocation and clearing price. `law.market` refuses only a fill above a slot's revealed quantity and out-of-phase writes. | IS | An `allocate` predicate in `Kernel/SealedMarket.lean`, or a Lean receiver for `settle` (Q37) | Today a number in a cell (`DEPOSIT_UNAVAILABLE`). A theft vector the day deposits land. | C D1 |
| 9 | `grain-runtime/src/concierge.rs:147-180` (decide), driven by `credit.rs` (program text `:619-624`) | "This payer paid ≥ the week price at height H within 64 heights, so issue `member` until `max(entry.height, notAfter) + period`; otherwise refund." | IS | A room-membership receiver of the same shape as `PayEnrolDecision` (Q38) | A faulty concierge keeps payments and issues nothing, issues windows for free, or refunds the wrong amount. Members have no Lean-enforced claim. | C D2 |
| 10 | `drain.rs:1144-1147` | A held ACK may be retried once iff the prior 255 frame's decoded `phase` equals hex "fn-session". | IS (small) | An explicit no-effect/retryable bit in `NativeHostCodec.Outcome` (Q4) | A second fn cursor ACK after a refusal that had an effect. | B 3.7 |
| 11 | `workspace.rs:3599-3657` with `replan.rs:109-126`; `chat.rs:1558-1571`; `workspace.rs:4308-4342`, `:4707-4713`; `fleet_sign.rs:510-511`, `:545` | **Author a new operation** after a refusal: append recovery (decoded `refused` at phase `admission`, or the exact `staleTarget` prepare detail, plus a read showing the preimage moved); chat re-propose on the *substring* `staleTarget`; birth release after `Standing::Refused`; `fleet-sign` treats any non-confirmed outcome of an exact resubmit, **including `uncertain`**, as never admitted and deletes the record. | IS (retry policy) | A Lean predicate on `Outcome` naming the retry-safe classes, with a theorem "refused at this phase ⇒ not committed" (Q1, Q2, Q3) | Duplicate document text, duplicate chat posts, a second birth (backstopped by reserved IDs), a double fleet commit. | A D5-D6, F V4-V5, D F-3 |
| 12 | `credit.rs:779`, `:813`, `:975`; `well.rs:104-120`; `activity.rs:114-127`; `workspace.rs:3592-3594` | That a rerun after an uncertain or crashed submit is a **new** operation (fresh nonce, no durable record): `credit pay`/`topup`/`refund`, `well mint`/`burn`/`floor`, `activity submit` for non-invoke turns, `workspace submit` without `--attempt`. | IS (by omission) | Replay identity at intent level, or a Lean at-most-once rule per turn kind (Q5, Q6, Q7) | A second payment, a second mint, a second purse top-up. | C F1-F2, F F3, A F3 |
| 13 | `roomkey.rs:1301-1326`, `:271-310`, `:667-699`, `:2059-2110`, `:2582-2629` | Who receives epoch e+1 (members at head ∩ `who` − kicked), which epoch is current, rollback and fork detection, the founder-key chain, the two-phase release machine. `Kernel/PrivateRoomKeys.lean:46-55` concedes: "The clients decide". | IS (by design, documented) | `Kernel/RoomReleaseCurrent.lean`, `RoomReleaseAuthority`, `-Intent`, `-Lineage`, `-Admission`, `Host/RoomKeyReleaseAuthor.lean`, `Compiler/RoomKeyReleaseCodec.lean`: **unwired**, imported only by `ResearchWip.lean:91-116` (Q28) | Privacy: a removed member kept, or a kept member dropped. "DEVNET QUALITY; PRIVACY NOT AUDITED". | F V9 |
| 14 | `workspace.rs:2791-2820` (`sealing_room`), `:2867-2870`, `:3075-3094`, `:878-887` | Whether a write to a private-room cell is encrypted at all. No Lean law refuses plaintext into a private room's cell. | IS | A room law clause or Kernel check that private-room cells accept only sealed atoms (Q29) | A plaintext leak into a private room if local refs are wrong. | A D4 |
| 15 | `session_reenroll.rs:601-667` (intent `:630`), encodings `:416-430`, `:615-626`, `:702-719` | **Authors the session-close state transition** as a raw scalar `invoke`: field 2 := generation+1, field 3 := status+1. Asserts "app field 1 = 4 = serving", "status 1 = web active, 5 = api active". | IS | A Lean session lifecycle command, or a Lean-emitted state view (Q30) | SPK app sessions get a well-typed but meaningless state that Lean admits as an authorized scalar write. | D S-1 |
| 16 | `provider_continuity.rs:436-477`, decision string `:832` | A contention-held provider call is "expired, never admissible" (`validUntil < genesis + count`). grain-runtime then releases the held allowance (`provider_resolution.rs:387-394`). | IS | A typed Host answer "exact call expired, never admissible at height ≥ H" (Q10, Q11) | Off by one, and the allowance is released while the call can still land: a double spend of the provider allowance. | F V8 |
| 17 | `world_kind.rs:460-487` | Compute credits = admitted steps − remaining free steps, refusing unless `freeSteps == 1000000` and `creditsPerStep == 1` (hard-coded tariff), plus `expectedPayerBalance`/`expectedBookRoot` CAS fields. | undetermined (MIRROR if Lean recomputes) | `Kernel/RunComputeView.lean:16-25` `ComputeQuote`; `Kernel/DeclaredResourceController.lean:1140` `computeFunding` arm (Q39) | If Lean takes `credits` as given, a client can underfund compute. Any tariff change refuses every call. | E S3 |
| 18 | `pay.rs:1188-1238`, `:1618-1636`, `:1824-1836` | Which nullifier an `alreadyConsumed` refusal refers to (the tick's or record k's). Rust then writes a receipt symlink that stops the watcher re-emitting the record. | IS (attribution) | The observation receiver naming the spent nullifier (Q34) | A false "already credited": a payment never credited, nothing quarantined. | C D3, F4 |
| 19 | `pay.rs:861-917`, `:2282-2289` | The pay watcher's scope (`--enrol-index`) and journal floor, taken from CLI flags, not from the signed tariff. | IS (scope of observation) | `Kernel/PayTariff.lean:18-21` (`enrolIndex`, `journalFloor`), derived from the signed view (Q35) | Payments below a stale floor are permanently skipped. | C D4, F5 |
| 20 | `clock.rs:151-156`, `:262-271`, catch-up `:372-390` | `now` is the clock subject's wall clock. The catch-up loop has no iteration cap. | ORACLE under capability | `Kernel/ClockTickReceiver.lean` bounds monotone + per-tick step; no rate bound (Q32, Q33) | One compromised clock key moves time without bound. One stuck attempt stops time. | C M18, D5, F6 |
| 21 | `key_service.rs:148-158`; `key_adoption.rs:91-103`; `mini-keys/src/server/native.rs:79` | "This key is the current owner, so the provider-credential action may proceed", from Lean status facts. The grant table (tokens/day, until-height) lives in the broker. | IS (a Rust authority domain) | None; provider-key grants are outside Lean | Who may spend a pooled or member provider key. | D S-5 |
| 22 | Journeys `shell-journey.sh:281`, `j12.sh:132` and seven more; `deploy/shell/OPERATOR.md:44-49`; `key_rotation.rs:526-539`, `key_rotation_custody.rs:24-26` | **Custodial copies of other people's secrets.** The operator onboarding copies the newcomer's daily secret into the sponsor's home. `rotate-key` keeps the old daily key, the old next key and the new after-next key in `attempts/rotate-ID/` forever. | IS (custody policy) | No Lean owner is needed. The contract owner should pick the `--action possess` flow (SELECTED-EXCHANGE.md:101-112), which exists. | On the shared-uid node every member can read these. Pre-rotation is defeated. | G 4.3(7), D F-2 |
| 23 | `transport.rs:39-49`, `:308-618` | About 25 per-op body bounds (op 7 ≤ 258 + 4 MiB, op 9 ≤ 16 KiB, 121/181/182 ≤ 4096, 30/31 ≤ 256 KiB, 91 ≤ 4 MiB, 214/219 ≤ 64 KiB, 19 response ≤ 8 MiB, ...). | POLICY (false refusals are decided in Rust) | `Kernel.Bounds` (only `frameBytesMax`/`lookupFrameBytesMax` are emitted into `bounds.rs`) (Q19) | Availability and UX, and drift (law 13). | B 3.2 |
| 24 | `transport.rs:53-68` (`host_budget`) | Ops 0 and 6–11 get 120 s because they "read no Store", yet op 0 calls `sessionOpened` and op 8 audience walks call `sessionWalked` (`Host/Main.lean:2016`, `:2050-2066`). | POLICY (false claim) | An emitted per-op purity or cost class (Q20, Q21) | A Host restart on a large audience walk; every queued caller pays the reopen. | B 3.3 |
| 25 | `drain.rs:943-953`; `drain.rs:558-570` | At most one exact ACK retry, then Held. Receipt identity across Host images = four equal canonical fields. | POLICY | Op 13/15 idempotence (Q7); a continuity-of-identity declaration across images | One duplicate ACK at most; operator tooling only. | B 3.6, 3.8 |
| 26 | `receipt_continuity.rs:843-876` (`finish_attempt`) | That a `confirmed` outcome's `(acceptedCount, worldRoot)` anchors **this call**. Only the point is proved to be on the chain, with no inclusion of the call's transaction. | IS (implicit trust) | An inclusion opening from op 151 or a sibling, in `Kernel.ReceiptContinuity` or `Host.ReceiptContinuity` (Q16) | A lying Host confirms a call it never admitted; the client stops retrying; the operation is lost. | E S10, F3 |
| 27 | `historical_call_receipt.rs:14-32`, `:111`; `append_proof.rs:131-140`, `:274-287` | "Receipt equals expected" by string equality on four fields, **bypassing continuity custody**. | MIRROR, but unanchored | Same as row 26 | A rolled-back Host can mint "proofs". | E S13, F6 |
| 28 | `receipt_continuity.rs:626-689` (`walk`); `:830-841` (`receipt_mode`); `carry.rs:1323-1413` | Whether a verified hop is valid progress; the allowlist of confirmation kinds; op-153 field allowlist plus an extra lower segment bound. | custody POLICY around a Lean proof / MIRROR (fail closed) | `Kernel.ReceiptContinuity.opens_sound`; `NativeHostCodec.Outcome`; `Host/RetainedSegmentInspection.lean:281-292` | Accept a fork, or refuse honest progress. | E S9, S11, S12 |
| 29 | `shell/law.rs:59-67` (`VERBS`), `:79-405` (grammar); `story.rs:412-449` (`render`/`explained`) | The verb-tag table (a hand copy of `CredentialAuthorityEntryCodec.verbTag`), the law grammar parser, and a second clause renderer. | IS (twin of Lean codecs) | `CredentialAuthorityEntryCodec.verbTag` as an emitted table; `Compiler/RefusalReason.lean` `renderClause`, `LawLeaf.explained` (Q31) | `law show` prints one thing while `law` installs another; `verb == place` compiles to the wrong tag. | A D2-D3, F 5.3 |
| 30 | `content_privacy.rs:148-150` and the closed action list | Which content actions exist, their exact fields, and that `link/unlink/mark/unmark` cannot be sealed. | POLICY with a duplicated grammar | `Host/Json.lean:899-960` `contentAction`; the Rust grammar should be emitted | Drift between client and Host grammars. | B 3.12 |
| 31 | `hiding.rs:117-245`, `:462-490` | "View refused" by re-implementing StoreCodec hashing, leaf encoding and the hiding root. | client verification (legitimate), implemented as a twin | `Compiler/StoreCodec.lean`, `Compiler/Sp800185Kmac256.lean`; only KMAC and the ratchet are vector-pinned (Q22) | A false "view refused", or a missed forgery, on drift. | B 3.13 |
| 32 | `shared_names.rs:34-93`, `:153-415`, `:337-363` | What a room name means (`KIND/ID`, canonical form, absence), and which local capabilities to attach (borrowing from any local ref with the same target). | IS (naming convention) | A Lean `SharedName` decoder; `Kernel/ContentResource.lean:1779-1812` `sharedNameAt` knows only the scheme and uniqueness (Q17) | A wrong resolution; name rebinding redirects a victim's next write (E 7.3); a malformed link is a render DoS (E F2). | E S1 |
| 33 | `room_schema.rs:27-70`; `hermes_handoff.rs:439-440`, `:476`, `:518-519` (`"1008"`, `"1009"`); roster layout `ROSTER_FROM + 2k − 1, + 2k` | Room field layout: names index, open flag, tariff, roster founder and members. | IS (layout) | No Lean declaration exists; Lean knows only the generic `fieldsFrom` tail (Q18) | Two clients with different constants read different rooms. | E S2, F V12 |
| 34 | `chat.rs:29-46`, `:930-1038`, `:1349-1404`, `:1019-1024` | Feed merge order, entry numbering `#N`, "only the founder's topic and pin count", reactions, payload kinds, the Discord `via` display. | IS (display-level room semantics) | A Host view returning the merged feed and the effective topic and pin by a declared rule | Clients and the Discord mirror disagree about topic and pin; `pin N`/`react N` target renumbered entries. | F V2 |
| 35 | `chat.rs:2121-2126`, `:2171-2174`; `hermes.rs:581-586` | Founder-only adopt and invite, by the roster's founder row or a local file's `founder` field. | IS for adopted open workrooms (MIRROR for `chat new` rooms) | The workroom law clause or `RoomBirthGate` declaration forbidding non-founder writes to field 2000 (Q40) | A member who rewrites the founder row becomes "founder" for topic and pin. | F V3 |
| 36 | `hermes_handoff.rs:71-124`, `:305-493`, `:691-744`; `hermes.rs:480-511`, `:201-240` | Whether a summon bundle is authentic (founder key current only on *first* delivery), which assignment is current (comparing `acceptedCount` strings), which resident a summon selects, request status and "cancellable". | IS (client-side gate) | A Host view "current Hermes assignment for room cell C" (Q41) | Which room's task a resident works on. A bundle signed by a key later revoked for compromise keeps activating (F F24). | F V7 |
| 37 | `participant_enrollment.rs:885-891`; `key_rotation.rs:518-525`, `:653-656` | KeyRecord content: `keyEpoch 1` (or epoch+1), `algorithm 1`, `activeFrom 0`, `activeUntil u64::MAX`. A key never expires. | IS unless Lean pins them | The enrollment and rotation receivers (Q13) | Every enrolled key is permanently valid by client choice. | D S-3 |
| 38 | `participant_namespace.rs:178-286`; `workspace.rs:3364-3374`, `:4570-4577` | Fresh subject numbers, keyIds, resource and capability IDs (random 63/64-bit draws). | MIRROR in effect (Lean refuses collisions) | `Kernel/ParticipantKeyEnrollmentReceiver.lean` uniqueness (Q12) | A refused plan on collision; identities are client-chosen and permanent. | D S-2, A D7 |
| 39 | `fleet.rs:174-189`, `:208-210` | A fleet turn's fee must equal `tariffBase` from the local pinned config. | MIRROR (consent; fail closed) | `config.tariff` (`Kernel/NativeHost.lean:1468`, `FleetTurnReceiver`) (Q36) | A non-flat tariff makes every fleet turn refuse. | D S-6 |
| 40 | `law_export.rs:14-66` | The next policy revision number and which facets carry over. | MIRROR if the installer checks `version`/`previous` | The install-policy receiver (Q31) | Rust picks revisions if Lean does not check. | D S-9 |
| 41 | `enrollment_bootstrap.rs:453-471`; `join_solana.rs:888-898`; `pay_status.rs:573-581` | Public lease state `enrolled`/`expired` from `hour < expiresAt`; the `inactive_membership` UX gate; recomputed `leaseState`. | MIRROR / presentation (published to strangers) | The lease predicate in `Kernel/PayClaimStatus.lean` and behind `DREGG/PAY/ENROLMENT-VIEW/v3` (Q35) | The status page disagrees with Lean at the boundary hour. | D S-7, C M7-M8 |
| 42 | `workspace.rs:266-268`, `:287-288`, `:2625-2635`; `workspace.rs:5162-5181` (`cell_storage`), `:5410-5417` | Hand-copied kernel constants (`CONTENT_COMMAND_VERSION = "10"`; the comment at `:3178-3181` says 9). Storage kind and link-target type are inferred **from JSON shape**. | MIRROR (constants; stale values refuse loudly) / IS (link target type) | Emitted constants; a typed storage field in the Host's view JSON (Q18) | A wrong link record type. | A D9-D10 |
| 43 | `protected_format.rs:119-200`; `protected_atoms.rs:67-92`, `protected_document.rs:263-307`; `object_epoch_cli.rs:159-191`; `protected_document_members.rs:328-336` | "Carry formatting" semantics (no `carryFormatting` verb exists in Lean); sealed-atom rollback and equivocation rule; next audience phase (enroll/freeze/resume); revocation completeness on member removal. | IS (carry and rollback rules) / MIRROR (phases, revokes) | Lean `carryFormatting`; a content-receiver check of `seq`/`prev`; the `install-source` audience validator (Q29) | A false "rollback" locks a line, or a real rollback is shown; a missed grant lets a removed member observe structure. | E S5-S8 |
| 44 | `append_proof.rs:52-113`, `:340-357`; `app_document.rs:290-349`, `:554-566` | A Rust-authored `minidregg-append-operation-proof-v1` statement signed by nobody; app-connector receipts whose operation, transaction and event IDs are never verified against Mini. | IS (evidence documents) | None | Consumers that trust `proof.json`, or connector provenance text, trust Rust's linkage. | E S14, S19 |
| 45 | `fleet_sign.rs:381-412` | Mints `turn_hash`/`receipt_hash` under a Rust domain (`MINI.FLEET-SIGN.RECEIPT-HASH/v1\0`) that helm may store as receipt identity. | IS (harness compatibility) | None; receipts are Lean's four fields | A Rust digest no Lean component verifies. | D S-8 |
| 46 | `cohort_tcp.rs:472-539`, `:740`; `pq_mailbox.rs:381-427`; `relay.rs:617` | Cohort slot admission from a roster JSON, registrar admitted sets, channel lease admission. | IS (admitted by the docs: "not Mini sender authority") | `Schedule.assembleTagged` re-checks part of the lease (Q23) | Privacy and availability of research cohorts only. | B 3.11 |
| 47 | `publisher.rs:208-282` vs `selected_publisher.rs:357-375`; `worker.rs:501-516` | NNTP repost policy, decided twice and inconsistently (one re-POST vs never); fn POST reply classification by exact human-readable text. | IS (external transport) | None (fn's Message-ID dedupe) | Duplicate or stranded fn articles; fail-closed reclassification. | F V11, B 3.9 |
| 48 | `activity.rs:175-209`, `:191-192`; `selected_exchange.rs:714-731`; `session_reenroll.rs:353,629,721`; `seat.rs:94-100` | Activity budget doubling keyed on substrings of Lean's verdict text; the event13 owner-packet representation (schema `11`, id = transaction id); nonce arithmetic `nonce+100+index`. | MIRROR / IS (small conventions) | Typed verdict fields (`Host/ObjectiveActivityJson.lean:372-373`); an event13 declaration (Q41) | Confusing refusals; a wrong verify verdict. | F V10, V12, D S-10 |

**What Rust correctly defers.** Every reader recorded a large deferred core, and it is real:
- Lean authors intent, plan, call and signature-list bytes through op 7, locally or on the Host. Rust signs only the Host-printed `header.canonical` after the local Lean consent provider re-derives the plan (A 3.3, C 1.0, D 3.3, F 3.2).
- Every outcome is decoded by the Host or the local codec, never parsed by Rust. The exceptions are the 255 sites in section 4.7.
- No module evaluates a law (`lawsat.rs` and `can.rs` only build op 150 and op 130 queries; D 3), and no module computes a trusted price (C 3.1).
- Method bodies run on the Host (E). The relay's channel semantics are Lean exports called in process (B 3.14).

The violations above are the authored *artifacts* (laws, templates, defaults), the *retry policy*, the *routing*, and a handful of *conventions* with no Lean declaration.

---

## 4. Twins and dead code

Each line count is the reader's measured figure or a `wc -l` of today's file. "Delete" means the repo law: nothing lands beside what it supersedes, so the twin goes.

### 4.1 Hand-rolled custody state machines vs `mini_sdk::custody`

`mini_sdk::custody` describes itself as "ONE state machine … bugs D2/D5/D7 were divergences between copies" (`native/mini-sdk/src/custody.rs:1-7`). In this crate it is used only by `workspace.rs:4028-4030` and `app_document.rs:12` (D 5.1). The hand-rolled copies:

| Copy | Shard | Approx. lines of custody code | Divergence found |
|---|---|---:|---|
| `key_rotation.rs` (+ `key_rotation_custody.rs`) | D | ~640 | refused-at-submit wedges forever (D F-1) |
| `key_adoption.rs` | D | ~565 code | never passed natively |
| `participant_enrollment.rs` (submit/lookup part) | D | ~400 | a definitive refusal wedges on lookup (D F-9) |
| `participant_provisioning.rs` | D | ~485 code | same (D F-9, F-12) |
| `session_enrollment.rs` | D | ~520 code | — |
| `share_issue.rs` + `grain_share_issue.rs` (near copies of each other) | D | ~1,180 code | — |
| `fleet.rs` (`turn`, `operation_record`, `recover_operation`) | D | ~600 | exact resubmit; `pay_turn` without a record (C F2) |
| `seat.rs` | D | ~213 | no submit marker (D F-19) |
| `agent_reserve.rs`, `agent_reserve/lifetime_v3.rs`, `agent_lifetime_grant.rs` | C | ~1,300 (1,579 code) | receipt projections disagree, so lookup after submit fails (C F3) |
| `agent_reserve/lifetime_v3/paid.rs` seal/submit/lookup | C | ~400 | a twin of spk-host's live path; broken (C F3) |
| `fn_namespace.rs` ↔ `fn_frontier.rs` | F | ~1,200 code | structurally identical; neither has a driver |
| `job.rs`, `clock.rs`, `checkpoint.rs`, `pay_refill.rs`, `well.rs` Host-call boilerplate (`with_kind`/`author`/`inspect`/`pair`/`reply`/`invoke`) | C | ~400 | `well` has no marker and no lookup (C F1) |
| `pay.rs`, `pay_claim.rs`, `join_solana*.rs`, `paid_context.rs`, `pay_memo_v2.rs` frame helpers | C | ~300 | 254 not named in `pay.rs`/`well.rs` (falls into "invalid frame") |
| `selected_release.rs`, `publisher.rs`, `selected_publisher.rs` post custody | F | ~900 | two repost rules (F V11) |
| `roomkey.rs` `turn` | F | ~200 | sound (exact lookup) |
| `drain.rs` phase machine | B | ~1,450 code | stale leftover convention (B, `drain.rs:1303-1310`) |

Count: at least 9 copies on the enrollment and key side (D's count), 3 plus 1 in agent reserves (C), 2 fn-custody copies (F), and the publisher pair, so **about 15 machines** doing what one parameterised SDK machine is meant to do. They split into two retry philosophies (section 5). D F-20 records the split, and the SDK comment is the warning.

### 4.2 Three traffic-privacy stacks: 8,891 lines, none deployed

| Stack | Files | Lines | Membership | Crypto | Callers / evidence |
|---|---|---:|---|---|---|
| 1. CH-RELAY channel | `relay.rs`, `channel.rs` (+ `channel-lib/` 131) | 2,398 | lease file | Ed25519 hello, **raw X25519** sealing (`channel.rs:201-208`, contradicting `hybrid_kem.rs:1-15` "every key exchange is hybrid"), Lean via `dlopen` | KCHR/KCHC, always red in CI (no channel library) |
| 2. PQ mix cascade | `pq_mailbox.rs`, `cohort_tcp.rs`, `async_dispatch.rs`, `../crypto_transit.rs` | 5,248 | roster v3 (MCE4) | hybrid KEM / ML-DSA | `cohort-native-tcp.py`; docs/evidence/traffic-v13 (the README "Traffic privacy" row) |
| 3. PSK fixed-cell facade | `scheduled_transport.rs` | 1,245 | pre-shared key | PSK cells | none; orphaned-request re-dispatch after restart (B 4.1, H) |

Plus non-Rust: about 1,970 lines (COHORT-TCP.md, PQ-MAILBOX.md, TRAFFIC-PRIVACY.md, six `.txt` diaries, the applied patch, both `cohort-native-tcp.py` copies, `cohort-two-host/*`, five `check-*` scripts, one of which filters on a test name that no longer exists) (B 5.2, G 6.2). Every stack opens a TCP listener with stranger-reachable resource bugs (B 4.2). Keep at most stack 2 if traffic privacy stays a research line. It is the one the README cites.

### 4.3 Versioned pairs still live

| Pair | Status | Action | Source |
|---|---|---|---|
| `join_solana.rs` (v1, 400-byte memo, 1,278 lines) vs `join_solana_v2.rs` (v2, 485-byte memo, 1,445) | both live behind `--memo-version` (`main.rs:3198-3200`); distinct receivers | keep v2; move ~350 lines of shared helpers out; delete v1 flows (~900) and `pay.rs:1487-1526` | C 5.4(8) |
| `agent_reserve.rs` (event21 v2 format) vs `lifetime_v3.rs` (event27) | both wired to grain-runtime | retire event21 upstream, then delete `agent_reserve` flow + `agent_payer.rs` (~1,700) | C 5.5 |
| Socket envelope v1 vs v2 | service accepts v1 (`transport.rs:177`); **3 Rust senders**: `main.rs:3137` (op 112), `main.rs:3152` (op 8), `publisher.rs:154` (op 18); **9 journey scripts** send v1 (`journey-stranger.py:34`, `j12x.sh:55` (both), `jnock2/3/3p/5.sh`, `jjob.sh`, `jjob1.sh`, `jeval.sh`; `j12x.sh` sends v1 on purpose, as a malformed-input row) | migrate the 3 callers and the scripts (through `hostraw.py`), then refuse v1; README:195-198 already claims it is gone | B 1.2, A 5, G 5.2 |
| `enrollment_bootstrap` v1 routes (op 121 quote, op 112 full-view scan) vs v2 (181-186) | both live | v2 only | D 5.4 |
| op 17 provider-continuity legacy/v2/v3 framings | legacy still used by `main.rs:3113` | drop legacy with the `continuity` arm | F 5.4 |
| `open_atom` legacy `MINI/PROTECTED-DOCUMENT-ATOM/v1` vs authored fragments | read-only history | delete when no legacy atoms remain | E 5.3 |
| `mini-web-edit-v1` session; Studio v1 draft and `prototype` field; legacy `manifest-{n}.json` | parsed only to refuse or to read history | delete with Studio | A 5 |
| Refuse-by-name scar tissue | MCE2/MCE3, roster v1/v2, bare 32-byte keys, `MPB1`/`MPM1`, v1 KEM secrets (B 5.2); rotation v1 attempts (D 5.4); v1/v2 encryption records, v1 keyrings, v1 rooms (F 5.4) | correct pattern; goes with each module | |

### 4.4 Wire-level twins

| Twin | Count | Sites | Keep |
|---|---:|---|---|
| Literal Host op numbers vs generated `native/host-operations.rs` | **159 call sites in 39 files, 88 distinct numbers** (tiny-crates report, `tiny-crates-and-shared-root.md:875`); the generated constants are used only by `member_app.rs:8-11` | e.g. `main.rs:1311-1341`, `:2588-2606`, `:2940`, `:2981`, `:3114`, `:3137`, `:3152` (A 5) | the generated constants; the registry check should scan for literals (`protocol/HOST-OPERATIONS.md:57-59`) |
| Consent op lists | **3, disagreeing** | `client_consent.rs:1093-1095` (31 ops); `mini-sdk/src/consent.rs:19-20` (29, without 210 and 215); Lean `NativeSpecializedConsent.supported` (15, `Kernel/NativeSpecializedConsent.lean:29-30`). Grain share plan op 56 and app-dispatch plan op 194 are in none. | one list, emitted from Lean (Q42) | 
| Consent framer | 2 | `client_consent.rs` vs `mini-sdk/src/consent.rs` (used only by `mini-sdk/src/flow.rs`) | one |
| Consent frame namespace 220-233 | unregistered | `Host/ClientConsentCore.lean:369-610`; 224/226/227 share the u8 space with the registry; 227 is load-bearing for `objective-invoke` | register (Q42) |
| `pair` framing | **8** | `participant_enrollment::pair`, `fleet::pair` (refuse empty), `client_consent::pair` (allows empty), `member_app::pair`, `seat::pair` (unbounded, `seat.rs:87-92`), inline in `share_issue.rs:567-570`, `grain_share_issue.rs:499-502`, `session_enrollment.rs:277-284`; vs `mini_sdk::frame::pair` | `mini_sdk::frame::pair` (D 5.1) |
| Socket frame codec | 2 | `mini_sdk::operator` (`operator.rs:360-387`, bound `HOST_MAX_FRAME + 1`) vs `transport::invoke_inner`/`read_frame` (bound `MAX_FRAME`) | one codec (B 5.4) |
| Deadline I/O | 2 + 3 | `transport::connect_unix_deadline` vs `public_proxy::connect`; `DeadlinePipe` vs `BoundedStream`; three `SocketGuard`s; hand-declared `poll`/`fcntl` FFI beside `libc` in the same file | one each (B 5.4) |
| Randomness | 3-4 | `hybrid_kem::random`, `mini_sdk::random`, ring `SystemRandom` (`operator_drain.rs:21`), `seat.rs:94-100` `/dev/urandom` | `mini_sdk::random` |
| Host one-shot inspection | 4 | `share_issue::source_process`/`source_inspect`, `share_issue_receipt::inspect_direct`, `grain_share_issue::inspect_bounded`, `agent_reserve::source_inspect`, all contradicting `client_consent.rs:1053-1055` ("no client path runs a one-shot `HOST CONFIG inspect` any more") | the codec child |
| Receipt projections | 4 | `agent_reserve.rs:111-138` (+`reserveIndex`), `agent_lifetime_grant.rs:59-78` (+`grantIndex`), `paid.rs:25-39`, `paid.rs:556-567`; their disagreement is C F3 | one |
| Inline frame encoders in scripts | **~15** (9 use v1) | `jnock2/3/3p/5.sh`, `jjob.sh`, `jjob1.sh`, `jjob-money.sh`, `jeval.sh`, `j12x.sh`, `journey-stranger.py`, `journey-key-adoption.py`, `paid-entry-adapter.py`, `cohort-scratch-world.py`, `jpay-v2.sh` vs `journey.d/lib/hostraw.py:47-50` | `hostraw.py` (G 5.2) |
| Lost-reply / fault proxies | **7** | `hostraw.py proxy` (lose-reply, never-forward), `selected-release-drop-reply.rs` (95, rustc at run time), `selected-source-drop-reply.sh`, `acceptance.sh`'s generated `drop-first-submit.sh`, `welcome-continuity-journey.sh` heredoc `proxy.py` + `ssh-shim`, `jpay-v2.sh` fault relay, `cohort-native-tcp.py` 2 s delay relay | `hostraw.py`, with delay and drop modes added (G 5.2) |
| Lean codec re-implemented in Python | 1 | `journey.d/lib/thin-proxy.py:46-107` (base-255 nats, slot list located by `difflib`) | a Lean-emitted forged-plan fixture (Q42) |
| Short-dir allocators | 4 | `shortdir.sh` vs `jinspect.sh:14` mktemp vs `/tmp/mini-continuity.*` vs `jchan-*.sh` `/home/ember/build/ch*` defaults | `shortdir.sh` |

### 4.5 Semantic twins of Lean (law 13)

| Rust copy | Lean original | Source |
|---|---|---|
| `shell/law.rs` grammar and `VERBS` verb-tag table | `Compiler/RefusalReason.lean` `renderClause`; `CredentialAuthorityEntryCodec.verbTag` | A D2-D3 |
| `story::render`/`explained` | `renderClause`, `LawLeaf.explained` | F 5.3 |
| `story::player_clauses` (live) | `Assurance/StoryLaw.lean` `clauses`/`law` (imitation, tale only) | F V1 |
| `content_privacy.rs` grammar | `Host/Json.lean:899-960` `contentAction` | B 3.12 |
| `hiding.rs` StoreCodec, KMAC, root | `Compiler/StoreCodec.lean`, `Compiler/Sp800185Kmac256.lean` | B 5.4 |
| `pay.rs:1859-1875` `creditFor` (audit) | `Kernel/PayTariff.lean:105-106` | C 5.4(4) |
| `pay_memo_v2.rs:87-134` v2 memo codec | `Kernel/PayEnrolMemoV2.lean:124-136` (defensible as a signing check) | C 5.4(6) |
| `pay_status.rs:409-413` reason-code table | `Kernel/PayEnrolMemo.lean:495-499` | C 5.4(5) |
| `key_rotation.rs:156-160` `NEXT_POSSESSION_TAG` | `Kernel/ParticipantKeyEnrollment.lean:64-68` (deliberate, so keygen runs offline; needs a persisted-tag test) | D 5.1 |
| `member_app.rs:96-102` authentication frame | `Host/ApplicationDispatchReady.lean:27-30` | D 5.1 |
| `key_service.rs:141-147` broker frame (serde_json key order on both sides, D F-8) | `mini-keys/src/server/member.rs:34-38` (Rust-to-Rust) | D 5.1 |
| `workspace.rs` `TreeModel` and the test's `applied` | the kernel's `editElementStep` | A 5 |
| `roomkey.rs:1712-2110` release machine (live) | `Kernel/RoomRelease*.lean` (unwired) | F 5.3 |
| `world_kind.rs:465` tariff constants | `Kernel/RunComputeView.lean:16-25` | E 5.3 |
| `shared_names.rs:13` `"mini-name"` scheme decoding | `Kernel/ContentResource.lean:1779` | E 5.3 |
| `room_schema.rs` layout; `hermes_handoff.rs` `"1008"`/`"1009"` | none declared (Q18) | E, F |
| `workspace.rs:266-288` constants | `Kernel/ContentResource.lean:432` (only the content version is test-guarded) | A D9 |

### 4.6 Custody `type` strings with no Lean declaration

F counted **about 80 distinct JSON `type` strings in its shard alone** (`"(mini|minidregg|fn)-…-vN"`; F 1.9), none with a Lean declaration: chat (3), story (3), Hermes shell (6), Hermes handoff (10+), provider continuity (4), private rooms (8+), fn custody (6), origin publisher (6), selected publication (8+). A, C, D and E add their own: attempt manifests, worker pins, `minidregg-join-solana-v1`/`-v2`, `minidregg-enrol-pin-v1`/`-v2`, `enrollment-bootstrap-v1`/`-v2`, `minidregg-retained-rotation-v2`, `minidregg-workspace-seen-document-v2`, `mini-member-workspace-v1`, `mini-member-app-v1`, `minidregg-append-operation-proof-v1`, the receipt-continuity files, and the share and session custody files. Crate-wide the figure is plausibly 150–200. I did not count it; that would need a grep of the source, which this synthesis avoids. These are client custody records, so a Lean declaration is not required. But each versioned format adds a migration surface, and most belong to the families section 6 drops.

### 4.7 The "255 is not a refusal" family

Lean writes 255 for refusals *and* for `.unavailable "host session reopening"` *and* for any handler exception (`Host/Main.lean:2646-2663`; `RequestRefusal.answer_refused` proves the answer always *says* refused, `Host/RequestRefusal.lean:91-99`). Op 125 returns 255 for every non-confirmed outcome, including `uncertain` and `contention` (`Host/Main.lean:7055-7063`). Rust sites that read every 255 as "refused, so a new attempt is safe":

| Site | Effect | Source |
|---|---|---|
| `main.rs:1349-1364` (`socket_process` records every 255 as `RefusedFrame`); `shell.rs:2452-2468` (exit 3); `web_author.rs:230-251`, `web_create.rs:181-188` ("The Store refused this operation" for any recorded decision, including `uncertain`) | the user is invited to save again after an undecided save | A F1, F15 |
| `well.rs:78-85`, `:168-175` | "host refused" for an uncertain mint; the natural rerun mints twice | C F1 |
| `key_rotation.rs:679-684`, `:748-751` | the inverse: op 142 returns its refusal *inside a 142 frame*, so a real refusal is never recognised and the workspace wedges | D F-1 |
| `activity.rs:61-74` | 254 and 255 conflated and printed as lossy text; Lean is never asked to decode | F F9 |
| `fn_namespace.rs:460-462`, `fn_frontier.rs:584-586`; `publisher.rs:163-168`; `receipt_continuity.rs:610-612`, `carry.rs:640-642` | refusal frame retained but never decoded; the reason is lost | F F10-F11, E F7 |
| `drain.rs:1383-1389` | holds on "refused" (safe for drain) | B 4.1 |

### 4.8 The "refusal read from prose" family

| Site | What is matched | Effect | Source |
|---|---|---|---|
| `chat.rs:686`, `:800`; `chat.rs:1561` | stderr prefix `refused: stale-root`; substring `staleTarget` anywhere in the captured block | control flow: retries, and **new operations** | F F2, V4 |
| `pay.rs:318-363` | constructor paths in Lean `repr` output (`Minidregg.Kernel.PayObservation.Reject.stalePay` inside `...Refusal.family (...)`) | control flow (named retries; a rename becomes "unnamed") | C Q19 |
| `key_rotation.rs:139` (`status_if_enrolled`) | English detail text | proceed/refuse UX in `workspace.rs:607` (fail closed) | D 3.2 |
| `workspace.rs:5983` (`frozen_roster`), `main.rs:426` (`refusal_hint`), `web.rs:362-369` (`refusal_text`) | `law-denied` + `sealed`; a constructor path; `"host refused "`/`"; encoded refusal: "` | display only, contradicting "never from error prose" (`main.rs:231-233`) | A F7 |
| `activity.rs:191-192` | substrings `frontEndExhausted`, `postageFrontEnd` of Lean's verdict | budget doubling | F V10 |
| `story.rs:1121-1128` | Lean's explanation text | display | F 3.2 |
| `worker.rs:501-516` | exact NNTP reply texts | retry classification (fail closed) | B 3.9 |
| `journey.sh:332-335` | one exact English sentence for `consent_refused` | gate result (fail closed, brittle) | G 4.4 |
| `hostraw.py:147-173` | operator log literal `host: submission refused (operator log):` | test oracle | G 1.1 |

### 4.9 Unreached modules and dead code (Rust)

| Module(s) | Lines | Evidence | Source |
|---|---:|---|---|
| fn consumer: `drain.rs`, consumer half of `worker.rs`, `main.rs:2575-3129` block + 12 arms | 2,136 + ~480 + ~985 | no unit, no row; lane evidence 2026-09-26 only | A, B |
| `fn_namespace.rs`, `fn_frontier.rs` | 1,462 | no caller; one manual r3 run refused | F |
| `publisher.rs` (`origin-publish`) | 552 | manual 2026-09-26 | F |
| traffic stacks | 8,891 incl. `crypto_transit.rs` | section 4.2 | B |
| `session_reenroll.rs` | 1,150 | fixture script only | D |
| `bend_session.rs` | 75 | hidden pre-parse arm, no caller | F |
| `selected_exchange.rs` fn-e path (`receive`, `cover-*`, `ack`, `verify`) and `selected_release::retry_submit` | ~400 | no caller; fn stores `fn-r`, path refuses it | F 5.2 |
| `paid.rs:432-723` (lifetime paid seal/submit/lookup) | ~290 + tests | spk-host owns the live path; broken | C |
| `web/surface.rs`, `world_surface.rs` | 130 + 200 | no caller outside own tests (builds with warnings) | E 5.1 |
| `export-evidence`/`verify-evidence`, `host-command`, `enc-*`, `escrow-recover`, `export-blinding` arms | ~150 in `main.rs` | no caller | A |
| Tombstones `key-service*` | 3 lines | refuse by name | A |
| Dead branches: `pay.rs:685-694`, `:821-830` (stale-root retry after blind op 105); `join_solana.rs` `--view` path; `--peer-uid` of `serve-operator`; 10 of 12 `bounds.rs` constants; stale TAIL-BOUND arms `transport.rs:593-597`; `drain.rs:1303-1310` leftover branch; `agent_lifetime_grant.rs:39-57` re-implementing `mini_sdk::decimal::predecessor`; `object_cli::receive_epoch` `hybridSecret` branch; vestigial `let _ =` parameters (`chat.rs:1068`, `hermes_handoff.rs:230`, `activity.rs:320`, `seat.rs:209`, `protected_document_members.rs:396`) | small | | B, C, D, E, F |
| `protected_object/source-snapshot.json` | 1,460 bytes | no reader; leaks `/Users/ember/workbox/...` | E |
| Duplicate hex test modules `main.rs:5186-5209` | 24 | | A |

### 4.10 Stale documents (the prose that contradicts code)

- **Root README "Honest state"**: four rows are stale (section 9).
- **Crate README**:
  - `README.md:195-198` says v1 envelopes are not sent; three callers send them.
  - It recommends the broken `acceptance.sh` (`:962`).
  - It documents unreached commands (the fn consumer, origin publish, evidence export) as if live.
  - Its `author --kind` list is a subset of what Lean accepts (G 1.3).
- **`docs/JOURNEY.md`** names 6 runner rows where there are 30, says "call and send are not rows", and points at `journey.sh:189` (now `:192`) (G 4.5).
- **Traffic diaries**:
  - PQ-MAILBOX.md:184 says MCE2; the code is MCE4. It cites a nonexistent `qualification/pq-native-pipeline.py`.
  - TRAFFIC-ENROLLMENT-CONSTRUCTION.txt says "pure ML-KEM768, MCA1"; the code is hybrid and has no MCA1.
  - COHORT-TCP.md contradicts itself ("uncompiled" vs "PASS 9/9").
  - CRYPTO-TRANSIT-CONSTRUCTION.txt asks for an integration that is done (B 5.2, G 4.5).
- **Code comments and module docs**:
  - `workspace.rs:262`, `:3178-3181` say grammar 9; the constant is 10.
  - The workspace error lists 42 of 76 actions (A F11).
  - `jweb.sh:2` calls `mini web` read-only; it has POST forms.
  - `credit.rs:1-13` says "Nothing here decides admission", which misleads about the concierge.
  - `join_solana.rs:3-22` still advertises `--view`, and `--renew` "one node week".
  - `object_epoch_cli.rs:97`.
  - `hybrid_kem.rs:1-15` claims "every key exchange is hybrid".
- **Diaries to rewrite as present state**: six `.txt` files, and the dated tails of COHORT-TCP, PQ-MAILBOX, TRAFFIC-PRIVACY, PAID-COLD-ENTRY, MEMBER-WORKSPACE and APPEND-PROOF (about 1,000 of 3,170 prose lines, G 1.3).

---

## 5. The retry and lost-reply contract as it exists

The README promise: "a lost reply keeps the original operation and its exact retry rather than licensing a second one." The transport keeps it. The application layer keeps it in some modules and breaks it in others.

### 5.1 Lost-reply matrix at the wire (B appendix B, 20 rows, summarised)

| Class | Rows | What the client sees | Could it have executed? |
|---|---|---|---|
| Certain, never forwarded | 1 (no connect), 2 (254 read after a failed write), 4 (bad envelope, pin, or op not allowed), 5 (queue full or displaced), 6 (60 s residence), 7 (caller gone), 13 (ssh proxy filter), 15 (public relay before the upstream write) | `cannot connect` or `socket rejected request: …` (254) | **no**, guaranteed by judging `unforwardable` just before the Host write (`transport.rs:1570-1578`, test `serve_refuses_254_only_before_forward`) |
| Uncertain | 3 (write failed, no 254), 8 (Host died or stalled mid-request), 9 (budget exceeded), 10 (reply over bound), 11 (reply write to client failed), 14 (ssh upstream failed), 16 (public relay after the upstream write), 18 (traffic reply over `max_body`, 65,536) | EOF: `uncertain host response …` | **possible**; the caller must look up the exact call |
| Lean says definitive | 12 (handler throws) | `255 refused operationRejected` | **unknown**: depends on whether a handler can throw after a durable append (Q1) |
| Automatic re-dispatch | 17 (traffic facade queue full after persisting `<ticket>.request`) | connection closed with no frame | **yes, later**: `recover_local` re-queues it on the next start, possibly after the caller authored a fresh call (B 4.1, H) |
| Application recovery | 19 (drain submit uncertain → lookup → `absent` → same bytes), 20 (drain ACK uncertain → one fenced exact retry → Held) | | Lean dedups exact bytes; op 13 idempotence assumed (Q7) |

No layer in `transport.rs`, `proxy.rs` or `public_proxy.rs` resends anything. The service never synthesises an outcome. So the matrix is sound, with two holes: row 12, which needs a Lean answer, and row 17, a research stack to delete.

### 5.2 The four philosophies, and which modules hold each

| # | Philosophy | Modules (sites) | Safe iff |
|---|---|---|---|
| P1 | **Exact resubmit** of the retained bytes, relying on Lean answering `replayed` | `mini retry --mode submit` and shell `retry ID` (`main.rs:2444-2532`; the shell's `retry` *resubmits*, `lookup` is the read-only one, A F4); `fleet` turns (`fleet.rs:706-728`); `seat --action resubmit` (`seat.rs:188-192`); `clock` (every run resubmits retained attempts first, `clock.rs:227-244`); `activity --action resubmit` (`activity.rs:299-303`); `drain` and `selected_release` (resubmit only after a decoded `absent`, `drain.rs:1430`, `selected_release.rs:254-283`); `job settle` (same bytes on `absent`, `job.rs:487-498`); `publisher.rs` (one re-POST to fn after transport loss, `:264-281`) | the op is replay-first in Lean. That is true for fleet (`Kernel/FleetTurnReceiver.lean:186-188`), and asked for 142, 88, 94, 189, 84, 28, 54 and 217 (Q6). The replay key must be the call or an identity that survives re-signing (Q5). |
| P1′ | **Re-sign the same intent** after a decoded `stale-root` | `submit`, `query_retained` and batch reads through `replan::replan` (≤5, `MINI_REPLAN_MAX`; `main.rs:1859-1864`, `:2179-2184`, `:2275-2277`); chat's own outer loop (≤10, `chat.rs:683-758`, `:785-807`), so up to **60 signed attempts per `say`** (F F1) | `stale-root` is definitive no-effect (Q2, Q4); the intent's command nonce makes a second admission impossible (Q5) |
| P2 | **Lookup only, never resubmit** | `rotate-key`, `adopt-next-key`, `enroll`, `workspace provision`, `session-enrollment-*`, `share-issue-*`, `grain-share-issue-*` (D); `pay`, `pay-claim` (never resubmits an `absent` ingress, C F10), `agent-*` reserve and grant machines (C); `fn-namespace-*`/`fn-frontier-*` ("no automatic resubmit"); `app_lifecycle` recover, carry lookups, protected-document enrollment and epoch phases (E); `selected_publisher` (never re-POSTs) | always safe against double operations. A lost-then-refused or never-forwarded submit **wedges**: D F-1 (rotation forever "submitted", `--new-attempt` refused), D F-9 (enrollment, adoption, provisioning). Liveness needs a definitive `absent` (Q9) |
| P3 | **Author a new operation after a decoded refusal** | append recovery (`workspace.rs:3599-3657`: `refused` at phase `admission` or the exact `staleTarget` prepare detail, plus a read showing the preimage moved; A D6, F V5); chat re-propose on the *substring* `staleTarget` (`chat.rs:1558-1571`, ≤3; F V4); birth release after `Standing::Refused` (`workspace.rs:4308-4342`; A D5, backstopped by reserved IDs); **`fleet-sign`** (`fleet_sign.rs:510-511`: *any* non-confirmed outcome of the exact resubmit, including `uncertain` and `unavailable`, is "never admitted"; the record is deleted, `:545`, and the caller may commit a fresh turn; D F-3) | Lean never answers `refused` after committing (Q1, Q2, Q3). `fleet-sign` is unsafe regardless: `uncertain` is not a refusal. |
| P4 | **No record, fresh nonce on rerun** | `credit pay`/`topup`/`refund` (`credit.rs:779`, `:813`, `:975` → `fleet::pay_turn` without an operation record, while `turn` and `return` in the same file have one; C F2); `well mint`/`burn`/`floor` (no marker, no lookup op, new attempt dir and nonce per run, uncertain reported as "refused"; C F1); `activity submit` for every non-invoke turn (`activity.rs:114-127`; F F3); `workspace --action submit` without `--attempt` (`workspace.rs:3592-3594`; A F3; the shell always passes `--attempt`); chat `invite` rerun (a new delegation each time, F F5); `job fund`/`claim` (fresh dirs, but Lean refuses a second fund or claim, C 3.4(5)) | never safe, unless Lean dedups at intent or content level (Q5, Q7) |

### 5.3 Concrete double-operation hazards found

| Hazard | Trigger | Lean containment | Severity | Source |
|---|---|---|---|---|
| Double **well mint** | op 125 commits, the reply is `uncertain` (255) or the socket drops; the CLI says "host refused"; the referee reruns | none (distinct nonces; no lookup op exists) | high | C F1 |
| Double **room payment** | `credit pay lab` from the shell; the ssh proxy drops after submit; the member reruns | none (fresh nonce); the concierge then extends or refunds by Rust rules | high | C F2 |
| Double **fleet commit** | `fleet-sign` exact resubmit returns `uncertain` | none if the first landed | high (helm-on-Mini path) | D F-3 |
| Double **purse top-up** | lost op-212 reply for `topUp`; rerun with a new `--out` | unknown (Q7) | medium | F F3 |
| Duplicate **document text** | append recovery when Lean answers `refused`/admission for a call that landed | depends on Q1/Q2 | medium | A F2 |
| Duplicate **chat post** | Lean refusal text containing `staleTarget` for a committed call, or a future detail quoting the word | depends on Q3 | medium | F F2 |
| Second **web save** | 255 `unavailable` after commit, rendered as "refused"; the user re-types the line | depends on Q1 | medium | A F1 |
| Second **ordinary invoke** | `mini workspace --action submit` rerun without `--attempt` | depends on Q5 | medium (CLI only) | A F3 |
| **Orphaned traffic request** | queue full after persisting; dispatched after restart beside the caller's fresh call | depends on Q5 | high, but research stack | B 4.1 |
| **Stacked grants** | `chat invite` rerun after a partial failure | none (each grant is a valid delegation); later kicks must revoke all | low | F F5 |
| **Allowance double spend** | provider expiry off by one (`validUntil` inclusive vs `<`) | Q10, Q11 | medium | F V8 |
| Lost operation (the inverse) | a lying Host confirms at a real point; continuity anchors only the point | none (Q16) | medium | E F3 |
| Wedged attempt (liveness) | refused or never-forwarded rotation, enrollment or provisioning submit | n/a | high for rotation (no exit) | D F-1, F-9 |

### 5.4 The one contract the crate should have

1. **One custody machine.** Every signed submission goes through `mini_sdk::custody`, with ops and formats as parameters. It writes a durable submit marker with the exact call bytes before the frame leaves. Delete the ~15 hand-rolled copies (section 4.1).
2. **Classify only by decoded outcome type.** 254 means *certain, not forwarded*. A 255 frame is always decoded by the Host or the local codec. Only a decoded `type == refused` whose reason belongs to a **Lean-declared no-effect class** counts as "not done". `uncertain`, `unavailable`, `contention` and a thrown-handler answer all count as *unknown*. This removes the 255 family (section 4.7) and every prose match in control flow (section 4.8).
3. **On unknown: look up the exact call.** If Lean answers *confirmed*, done. If Lean answers a definitive *absent / never admissible*, resubmit **the same bytes** when the op is replay-first; otherwise report and stop. **Never** mint a new nonce for the same request.
4. **A new operation only after a Lean-declared retry-safe refusal.** It is recorded as a successor of the refused attempt in the same custody directory. That covers append recovery, chat `staleTarget` and birth release. `fleet-sign`'s "uncertain ⇒ never admitted" goes.
5. **The CLI refuses a rerun without its record.** `credit pay|topup|refund`, `well *`, `activity submit` and `workspace submit` require `--attempt`/`--operation-record` (or create one deterministically from the request) and refuse to author a second operation while an unresolved attempt for the same request exists. This is what `credit turn`/`return` already do.
6. **One retry budget**, owned by `replan.rs`. Chat's loops go (F F1).

Lean dependencies, as questions (section 8):
- Q1: can a handler commit and then answer 255?
- Q2/Q3: does `refused` at `admission`, or `staleTarget`, imply no event?
- Q4: can the outcome carry a machine-readable no-effect/retryable class instead of a phase string or `repr`?
- Q5: is the replay key the call, the (signer, nonce) pair, or the intent?
- Q6: which submit receivers are replay-first?
- Q9: is there a definitive `absent` that can never later become admitted?
- Q7: which turn kinds are at-most-once by content?

---

## 6. Size and shape

### 6.1 Lines by family, tests vs code

Section 1.1 gives lines per family. Per shard, as measured by the readers (test region = `#[cfg(test)]` to end of module):

| Shard | Rust lines | Test lines | Test share | `#[test]` | Note |
|---|---:|---:|---:|---:|---|
| A entry, shell, workspace | 21,476 | 4,362 | 20% | 149 | several tests replay a Rust model of `editElementStep` (A 5) |
| B transport, relay, traffic | 18,424 | ~5,965 | 32% | 173 | allowlist tests test hand-written expectations; relay tests never load Lean |
| C money | 17,121 | 3,741 | 22% | 99 | `clock.rs`, `checkpoint.rs`, `pay_refill.rs` have zero tests; marker-only tests let C F3 survive |
| D identity, enrollment, fleet | 19,300 | ~5,061 | 26% | 168 | `key_adoption.rs` is 58% tests, all against fakes |
| E documents, web, receipts | 19,133 | ~5,077 | 27% | n/a | `get_router_calls_no_submit_path` is a prose-scanning test (E 5.4) |
| F chat, Hermes, private, selected | 18,335 (+95 loose) | 4,100 | 22% | 166 | `roomkey`'s `FakeHost` implements none of `keysLaw`; `activity`, `bend_session`, `objective_invoke` have no tests |
| **Rust total** | **113,789** | **~28,300** | **~25%** | **≥755** | |
| G scripts | 45,250 | (all test) | | | plus 1,556 lines of test-of-test (`test_*.py`) |
| G prose | 3,170 | | | | about 1,000 are appended diaries |

**Shape observations.**
- About a third of the money code is custody ceremony (retain, pin, re-hash, re-inspect, compare), not protocol (C 6.2).
- `main.rs` is 5.2K lines and holds a 470-line fn-consumer block and literal op bytes (A).
- `workspace.rs` (8.8K) is a full client-side authoring layer: it builds intents, reserves IDs, derives child capability records, diffs lines into element-tree edits (A 1.7).
- `agent_reserve.rs` doubles as a general utility module imported by at least ten modules (C 6.2), so it must be emptied before it can be deleted.

### 6.2 The demo-minimal build in three tiers

Line figures are today's `wc -l` (section 1.1) plus the readers' in-file trim estimates. Each tier includes the tiers above it.

#### Tier 1: hosted shell, documents and boards only (the 2026-10-01 candidate's surface)

**Keep (~41.2K lines):**
- Families 1 (trimmed), 2, 3 (trimmed), 4, 6, 7, 8, 9, 11, 12.
- `receipt_continuity.rs` (1,470).
- `fleet.rs` (1,476: record helpers that `credit`, `chat` and `append_proof` import).
- `clock.rs` and `checkpoint.rs` (583); `credit.rs` (1,083) while the shell's `credit`/`tariff` verbs remain.
- `world_kind.rs` (630, if boards use world instances, `web.rs:887`).
- `private.rs` (1,440: the keygen notice, hosted marker, escrow, and `legacy_content` used by `workspace`, `render`, `doc_search`, `context_projection`).
- `key_rotation.rs:1-330`.
- About 80 lines of `agent_reserve.rs` helpers, moved into `fsio`.

**Drop:**

| Dropped | Lines | Source |
|---|---:|---|
| Traffic stacks (family 32) + `../crypto_transit.rs` | 8,511 + 380 | B 6.2 |
| fn consumer, fn custody, origin publisher (family 30) | 5,058 | B, F |
| Selected release and exchange (family 31) | 2,024 | F |
| Pay rail and pay-to-enrol (family 22) | 10,179 | C 6.3(A) |
| Paid-entry HTTP (family 21) | 1,553 | D |
| Market, wells, jobs (family 24) | 2,008 | C |
| Agent reserves and payers (family 25) less moved helpers | 2,935 | C |
| `meter.rs` | 253 | C |
| SPK sessions and shares (family 20) | 3,551 | D |
| Key rotation executor, adoption, broker client (family 10 minus `key_rotation.rs:1-330`) | 2,976 | D 6 |
| `fleet_sign.rs` | 947 | D 6 |
| Member home, seats (family 19) | 1,379 | D 6 |
| Protected documents (family 13) | 4,946 | E 6 tier 2 |
| Web face and Studio (family 14) | 5,351 | E 6 tier 3, A 6 |
| Carry and portable verifier | 1,944 | E 6 tier 1 |
| App connector, lifecycle, context, `world_prototype`, `world_surface` (family 16 minus `world_kind`) | 2,318 | E 6 |
| Operation proofs, historical receipts (family 17) | 665 | E 6 |
| Chat, story, Hermes verbs (family 26) | 5,024 | F 6.2 |
| `roomkey.rs` | 3,863 | F 6.2 |
| Hermes handoff, provider continuity (family 28) | 2,631 | F 6.2 |
| Objective client (family 29) | 467 | F 6.2 (keep 392 if Objective is shown) |
| Split-topology ingress and drain (family 5) | 1,200 | B 6.2 |
| `main.rs` trims (fn block `:2575-3129` + arms + tests ~985; unreached arms ~520; USAGE ~110) | ~1,615 | A 6 |
| `workspace.rs` trims (dispatch arms to dropped modules ~110, thin consent and kick ~150, their tests ~900) | ~1,160 | A 6 |
| **Total dropped** | **~72.6K of 113.8K (64%)** | |

#### Tier 2: add public rooms and chat (no private rooms, no Hermes, no fn)

Add back `chat.rs` and `capture.rs` (2,767), and optionally `story.rs` (1,246), with the room templates (`shell/template.rs` stays). `credit.rs` and `room_schema.rs` are already kept. The kept set is **~44.0K–45.2K**; the dropped set is **~68.6K–69.8K**. Chat's `--private` arms (`chat.rs:1153-1202`, `:2042`, `:2153-2205`) must refuse instead of calling `roomkey`. Story stays only if its law generator is either accepted as a Rust-authored law or replaced by a Lean emitter (section 3 row 5). Before chat is shown, fix F F1 (60-attempt retry nesting), F F2 (prose classification) and F F5 (non-atomic invite).

#### Tier 3: add pay-to-enrol, v2 only

Add back:
- `pay.rs` (2,560, less the v1 enrol branch `:1487-1526`);
- `pay_memo_v2.rs` (1,164, less the 163-line packet fixture);
- `pay_status.rs` (773), `join_solana_v2.rs` (1,445), about 350 lines of helpers moved out of `join_solana.rs`;
- `paid_context.rs` (788), `paid_onboarding.rs` (218), `pay_claim.rs` (1,798);
- `enrollment_bootstrap.rs` (1,553);
- `public_proxy.rs` + `operator_drain.rs` (1,200), if the split topology is how ops 117-120 reach the operator socket.

That is about 11.6K–12.8K more, so the kept set is **~56K–58K** and the dropped set **~56K–58K**. C's tier-B estimate is the same delta from the money side (≈3.6K dropped of the 17.1K money lines). Before it ships, fix C F4 (nullifier attribution), C F5 (watch floor from flags), C F7 (pay-claim cannot survive a Host upgrade) and D F-16/F-17 (bootstrap accept loop, anchor retention).

### 6.3 Cross-module couplings that block the drops (merged from B, C, D, E, F)

| Coupling | Blocks dropping | Resolution | Source |
|---|---|---|---|
| `agent_reserve.rs` doubles as a utility module (`field`, `bounded`, `private_bytes`, `retain_json`, `source`, `source_inspect`, `digest`), imported by `job.rs:27`, `clock.rs:34`, `checkpoint.rs:23`, `session_enrollment` and at least 7 other modules | family 25 | move ~80 lines into `fsio` first | C 6.2 |
| `main.rs:2448` `retry_with_upgrade` uses `drain::HostUpgrade` | `drain.rs` (family 30) | move `HostUpgrade` next to `retry`, or delete upgrade-retry | B 1.1 |
| `worker.rs` fn POST half used by `publisher.rs:295/391`, `selected_publisher.rs:403/472` | `worker.rs` | goes with families 30 and 31 together | B 6.2 |
| `private.rs` carries keygen's notice, hosted marker and escrow (`main.rs:1140-1166`), the passphrase adoption at `main` (`:4505`), and `legacy_content`/`opened_text`/`is_private_kind` used by `workspace.rs`, `context_projection.rs:51-52`, `doc_search.rs:87-88`, `render/mod.rs:365-370` | `private.rs` | keep the slice or move it next to keygen; make `legacy_content` refuse every private action | F 6.2 |
| `roomkey.rs` referenced 30× from `workspace.rs` (e.g. `:43-48`, `:2823`, `:3088`, `:4848`, `:6381-6539`), from `shell.rs:176-177`, `:456`, `:789`, `:2626`, from `key_rotation.rs:610-614`, `:822`, from `main.rs` (`enc-*`, `escrow-recover`), and from `chat.rs` | `roomkey.rs` | remove private-room support from workspace and shell (shard A edits) | F 6.2 |
| `fleet.rs` `operation_record`, `recover_operation`, `account_balance`, `digest`, `confirmed` imported by `credit.rs`, `chat.rs`, `append_proof.rs` | `fleet.rs` | keep `fleet.rs`; drop only `join`/`feed` (~200) | D 6 |
| `current_birth.rs` used in process by `workspace.rs:4742-4755` | `current_birth.rs` | keep (drop only the two CLI arms) | D 6 |
| `key_rotation.rs:1-330` (status, digest, cosign, `check_commitment`) used by `participant_enrollment`, `workspace.rs:334,410-419,607,690`, `member_app`, `join_solana_v2.rs:581`, `roomkey`, `main.rs:333,1120-1186` | the rest of `key_rotation.rs` | split the file | D 6 |
| `receipt_continuity.rs:3,454,700,729,737` and `main.rs:2459` call carry | `carry.rs`, `verifier.rs` | remove the hooks | E 6 |
| `hermes_handoff.rs:349` uses `historical_call_receipt` | `historical_call_receipt.rs` | drop together | E 6 |
| `render/mod.rs:432` uses `shared_names::binding` | `shared_names.rs` | keep; with rooms off it can shrink to `binding` | E 6 |
| `room_schema.rs` used by `chat.rs`, `credit.rs`, `member.rs`, `hermes_handoff.rs`, `shared_names.rs`, `web/resident.rs` | `room_schema.rs` | keep (small) | E 1.0 |
| `workspace.rs:51-54`, `:3052-3165` and `render/mod.rs:365-377` reach protected documents | family 13 | small edits; `doc_search.rs:346` is test-only | E 6 |
| `web/resident.rs` uses `chat::room_feed` and `hermes::request_rows`; `workspace/web_author.rs`, `web_create.rs` sit under workspace | family 14 | drop web before chat, or keep the read-only feed | F 6.2, A 6 |
| `provider_continuity` called by `grain-runtime/src/main.rs:8317`, `provider_resolution.rs:387`; `submit --provider-continuity` arm `main.rs:4313-4326`, `:1953-1970` | family 28 | grain-runtime edits | F 6.2 |
| `enrollment_bootstrap.rs` imports `pay_status` | `pay_status.rs` | drop together (tier 1) or keep together (tier 3) | C 6.3 |
| About 23 `mini` subcommands spawned by `grain-runtime` (`rc-A/other-crate-callers.txt`); `spk-host` owns the lifetime-paid path | families 17, 20, 25, 28 | a product decision on grain-runtime and SPK, not a Rust edit | A 1.3, C 5.4 |
| `content_privacy.rs` used by `workspace.rs:2727`, `protected_document.rs`, `private.rs:789` | (keep) | keep | B 1.1 |
| `../hybrid_kem.rs` (471, outside `src/`) used by private rooms and protected documents | drops with families 13 and 27 if both go | | B 6.1 |
| `deploy/shell/templates/room/*` compiled in by `shell/template.rs:25-41`; job law templates generated from Lean | `template.rs` | keep for tier 2 | A |

### 6.4 The journey corpus cut (G 6.2)

**Keep about 4.5K of 48.4K lines (≈9%)**:
- `journey.sh`, trimmed from 1,180 to ~900 lines, after fixing G 4.1 and items 1–4 of G 4.3;
- `journey.d/lib/shortdir.sh`, `genesis-params.sh`, `hostraw.py`;
- `newparticipant-acceptance.sh`;
- `genesis.sh` + `genesis-params.example.json` (deployed; move them to `deploy/candidate/`);
- `journey-stranger.py`, `journey-private.sh`;
- `shell-journey.sh` + `m4.sh`; `provisioning-acceptance.sh` + `m3.sh`;
- `j12.sh`; `j12w.sh` (fix `:121`); `j12x.sh`, `jserve.sh`, `jrefusal-lane.sh`; `jdisclose.sh` (fix `:48`); `jstoreaudit.sh`.

**Optional, if boards and law are shown:** `law-leaf-journey.sh` + `j13.sh` (351), `jclosure.sh` (147), `jtail.sh` (158).

**Delete or move out of the client crate:**

| Group | Lines |
|---|---:|
| legacy acceptance | 1,250 |
| traffic and cohort | 1,114 |
| platform, joined, composed, latency, plus their tests | 4,325 + 1,556 |
| pay | 6,052 |
| nock, compute, world programmer | 3,999 |
| Objective (move to its lane) | 5,398 |
| rooms, chat, private, Hermes, channel | 3,888 |
| selected and fn | 1,381 |
| continuity and keys | 1,216 |
| fleet | 972 |
| non-demo K-rows (move to a nightly kernel journey) | ~6,700 |
| non-demo lane wrappers | ~1,900 |
| loose files | 103 |
| diaries | ~1,000 prose |

**Split the definition of done.** Make a demo journey that finishes inside the 3 h gate (J0–J8, G, M3, M4, J12, J12W, J12X, JSERVE, JRLANE, JDISCLOSE, JAUDIT) and a nightly kernel journey for the rest (G Q10). Also fix:
- the gate budget mismatch: 14,400 s journey budget vs a 10,800 s gate kill (G 4.1);
- the liveness check that only runs after a *successful* hook, which turned K11's hang into 17 cascade reds (G 4.1);
- `check-journey.sh`, which never builds the channel library (G 4.1).

---

## 7. Deployability of `mini` on the Hetzner VM

### 7.1 Processes

| Process | Started by | Lifetime | Source |
|---|---|---|---|
| `mini serve --host --config --socket` (public mode) | candidate unit (`deploy/candidate/run.sh:157`, `:249-271`; `Type=simple`, `UMask=0077`, `KillMode=control-group`) | long-lived; readiness is the log line `mini: host process N` (`run.sh:187`), i.e. log scraping | B 7.1 |
| one `minidregg-host CONFIG stdio` child | `mini serve`; on Linux exec'd from sealed memfds (`/proc/<pid>/fd/<n>`) | restarted after any exchange error; the in-flight caller sees "uncertain" | B 1.2 |
| `mini shell` per ssh login (forced command `deploy/shell/mini-shell-ssh`) and `mini socket-proxy` per ssh session (`deploy/shell/mini-socket-proxy`) | sshd | per session; `socket-proxy` reads ssh stdin with no deadline, so idle sessions are unbounded except by sshd (`proxy.rs:38`) | A 7, B 4.2 |
| a **local codec Host child** (`minidregg-host` storeless codec loop) | **every** `mini` process that authors, inspects, signs or decodes (`client_consent.rs:1015-1017`; `main.rs:603-605`) | per `mini` process | D 7.1, A 1.9 |
| `mini consent-resident` daemons | **self-spawned** with `setsid` by signing `mini` processes (`client_consent.rs:418-420`, checked) | 600 s idle exit; one per (consent executable inode, settings bytes) binding; each holds an admitted Store image in memory; PID files and logs under `~/.mini/consent-anchors/` | D 7.1 |
| `minidregg-client-consent` | the resident or the signing process | per use; **every signing flow refuses without it** (`participant_enrollment.rs:1036-1041`, `client_consent.rs:104-111`) | D 7.1 |
| `mini clock --action tick` (1/min), `mini checkpoint --action certify` (user timer) | `deploy/clock/mini-clock-tick.{service,timer}`, `deploy/checkpoint/mini-checkpoint-certify.{service,timer}` | oneshot; without certify the node stops accepting writes after `L` records | C 7.1 |
| `mini pay watch-config`/`observe` under `mini-pay-watcher.timer` | `deploy/pay/` (**inactive on the node**) | oneshot, `MemoryMax=512M` | C 7.1 |
| `stty` (interactive shell), `ssh` (`MINI_SSH`, the remote path), `ssh-keygen` (join), `/usr/bin/curl` (connector, bootstrap), GNU `timeout` + Host `objective-front` (Studio preview only; absent on macOS) | various | per call | A 1.9, C 7.1, E 7 |
| Not on the demo, must stay off | `relay`/`relay-witness`, `traffic --action server`, `mix-live`, `consumer-worker`, `enrollment-bootstrap` (unless tier 3), `mini web` (loopback per member) | | B 7.3, E 7 |

The `mini-store.service` unit that the clock unit names in `After=`/`Requires=` lives outside this repository, in dregg-infra (A 7).

### 7.2 Sockets, files, environment

- **Sockets:**
  - `mini.sock` (0600) in a 0700 directory, with `mini.lock`, `mini.config` and `mini.mode` (`public-v1`/`operator-v1`; a public pin can never become operator);
  - `mini.control` for `serve-operator` drain;
  - resident consent sockets `~/.mini/consent-anchors/r-<binding>.sock` (peer-uid checked);
  - `mini web` on `127.0.0.1` only (refuses `0.0.0.0`, `jweb.sh:137`);
  - `enrollment-bootstrap --listen 127.0.0.1:8794` behind a TLS proxy, if deployed.
- **Files:**
  - `/var/lib/mini/{store,clock,sessions,…}`, `/usr/local/bin/mini`, `/usr/local/lib/mini/FRIENDS.md` (fixed path, `shell.rs:141`);
  - per-member `HOME/keys/` (0600 seeds) and owner-private workspaces (`workspace.json`, `refs/`, `attempts/`, `sources/`, `proposals/`, `private/keys.cache`, `protected-documents/storage.key`, `receipt-continuity/*`);
  - the sponsor's `namespaceRoot` and `HOME/enroll/NAME`;
  - `/etc/mini/keys-client.json`, `/etc/mini/pay/{watcher,rpc}.env`, `/etc/mini/hermes-residents.json` (no installer), `/etc/mini/hosted-subjects`.
- **Environment:** `MINI_VERIFY_HOST`, `MINI_AUDIT_TIMING`, `MINI_REPLAN_MAX`, `MINI_REPLAN_LOG` (appends to any path the invoking user can write), `MINI_KEYCACHE_PASSPHRASE` (adopted and removed early), `MINIDREGG_STUDIO_PREVIEW_CONFIG`, `MINI_LOCAL_HOST`, `MINI_THIN_CONSENT`, `MINI_CONSENT_*`, `MINI_TRACE`, `MINI_SSH`, `MINI_CLOCK_WORKSPACE`, `MINI_CHECKPOINT_CONTROL=53`, `MINI_CHECKPOINT_MIN_TAIL`, `MINI_HOSTED_SUBJECTS`, `HOME` (A 1.9, C 7.1, D 7.2, F 7.2).
- **Kernel features:** Unix sockets, `memfd_create` with sealing, `/proc/self/fd` exec, `SO_PEERCRED`, `openat`/`renameat`/`O_NOFOLLOW`, `flock`. No bwrap, cgroups or seccomp in this crate.

### 7.3 The client-side Lean Host requirement

A friend who runs `mini` on their own machine (`--remote ssh:DEST`, `join`, `pay-claim`, continuity) needs **a local `minidregg-host` build, a `minidregg-client-consent` build and the pinned config**:
- the pure codec (author, inspect, signatures, assemble, and the decoding of every 255 frame) runs locally (`client_consent.rs:50-56`; A 2);
- every join and claim flow runs Host subcommands locally (`join_solana.rs:523-525`, `join_solana_v2.rs:249-255`, `pay_claim.rs:156-171`; C 7.1);
- every signing flow refuses without the consent binary (D 7.1);
- continuity needs `--verifier LOCAL-HOST` (`receipt_continuity.rs:895-900`; E 7).

USAGE tells `--remote` users their workspace "has no Host image" (`main.rs:833-834`), which contradicts this (A 2). For a public demo it means shipping Lean binaries to every stranger who wants a laptop client. The hosted shell avoids it, because everything runs on the box. A Host upgrade also breaks every pinned workspace until a continuity carry re-pins it (A F5), which matters for a demo that redeploys.

### 7.4 The shared-uid hosted shell

The node runs every hosted member's `mini shell` under one `mini` account (`docs/review/2026-10-26-deploy/HCLOUD-GAP.md:124,174`; split tenancy is "compiled; run on no box"). Consequences found across shards:
- **Every member can read every other member's files.** That covers key seeds, the rotation copies in `attempts/rotate-*` and the sponsor-side custody copies of newcomers' secrets (D 7.3, 7.5; D F-2; G 4.3(7)). D calls this "the largest real risk until split tenancy runs". The shell banner says hosted keys are readable by root (`shell.rs:138`).
- One member's session can connect to another member's resident consent provider for the same binding. The provider only re-derives plans, so this is a confidentiality question, not an authority one (D 7.3).
- `serve_queue` fairness is per peer uid, so with one uid it **degenerates to FIFO**, and one member can fill the 32-slot queue alone (B 4.2, `serve_queue.rs:10-14`).
- Each shell line runs in process under `catch_unwind`, but a stack overflow (A F9: unbounded `not(` nesting in the law parser) aborts the session process.

### 7.5 Single-Host-thread monopolization

`mini serve` has **one Host thread**. Public state ops get a 600 s Host budget, queue residence is 60 s, and there are 32 queue slots and 64 connections (`transport.rs:53-68`, `:1548-1550`). A member who sends heavy requests back to back keeps the Host busy, and everyone else gets `254 busy: queue residence deadline` after 60 s. Heavy requests include NOCK dry runs 131-137, law-sat 150, op 7 author up to 4 MiB, op 19 with an 8 MiB response, op 16 with a 1.5 MB carrier, and `can --all`'s ~16 dry runs per resource. In the split topology the public relay shares one fairness peer and the 64-connection budget with the operator's lifecycle and drain clients, so a public flood starves operator control (B 4.2, H). This is "the most practical griefing vector for a small public demo, and it needs no protocol bug" (B 7.5).

### 7.6 What a stranger can reach

- **Without an authorized ssh key: nothing in this crate.** The Host socket is Unix-only; `mini web` is loopback; the research TCP listeners are not deployed (A 7, B 7.4, E 7, F 7.4).
- **With an accepted ssh key**, the stranger is a member: forced-command `mini shell` lines or the byte proxy, the latter filtered by `public_envelope` on every frame (`proxy.rs:69`). J5 and J8 show unenrolled keys refused by the Host at `challenge` (CI passes both on main; section 9).
- **If `enrollment-bootstrap` is deployed (tier 3):**
  - metadata; quotes (121, 182); status (112 full-view scan, 181); the claim plan, assemble, submit and lookup relay (183-186);
  - rate limits of 6 quote-class and 12 status-class requests per minute per IPv4 address or IPv6 /64, global Host concurrency 2, responses ≤ 16 KiB. Without `--trusted-proxy`, every client shares one bucket (D F-16);
  - the status route publicly **links an ssh key to a subject** and its lease state (D 7.4, by design);
  - floor-sized memo payments (1 DREGG each, journaled) delay honest enrollments in the watcher's FIFO (C 7.3).
- **Dangerous to expose:**
  - the operator socket: 69 routing-only ops; never use `--peer-uid`; never loosen the 0700 directory;
  - `mini web`'s port: whoever holds the printed URL has the member's full authority, including signed POST edits, with no CSRF token. The URL is printed to stdout;
  - `MINI_TRACE` pointed at a world-readable path;
  - `key --action export-blinding`, which prints a secret;
  - any multi-threaded server that reaches `capture.rs`'s process-wide fd swap (A 7, B 7.3, E 7, F 7.3).

### 7.7 What a malicious enrolled member can do (all shards' section 7.5)

| Attack | Effect on others | Source |
|---|---|---|
| Monopolise the single Host thread; fill the shared FIFO; hold idle ssh `socket-proxy` sessions | denial of service for all members | B 7.5 |
| **Write one malformed `mini-name` link into a shared document** | every reader's `doc show`, web page and search for that document fails until someone unlinks it, and unlinking needs the editor to render it. **On the demo document path.** | E F2 |
| **Write terminal escapes into a line, then edit it** | every reader of `doc history`/`doc diff` gets OSC 52 clipboard writes or cursor control. **On the demo document path.** | E F1 |
| Rebind a room name through an index they can write | the victim's next write lands in the substituted cell | E 7.3 |
| Read other members' keys and custody copies (shared uid) | key theft | D 7.5 |
| Spam their own chat stream | every reader's `tail` re-reads all history (O(history) signed reads) | F 7.5, F21 |
| Post `say --via discord --via-id --via-name` | a spoofed bridge author for `tail --json` consumers | F 7.5 |
| Rewrite the roster founder row in an adopted open workroom | becomes "founder" for topic and pin | F V3 |
| Supply any story table as an author | a Rust-generated law that both sides accept | F V1 |
| Accept invitations and idle | each founder `chat invite` retry adds a standing grant and a paid stream birth | F F5 |
| `can --all`, `law check`, `can --any` | unbounded attempts and Host work per probe; refused calls cost nothing | D 7.5 |
| Deeply nested law text | self-DoS only (stack overflow) | A F9 |
| As a market founder, allocate arbitrarily | no money moves today | C 7.4 |
| A malicious app server behind the connector | false provenance IDs embedded in documents | E 7.4 |
| Pre-ACK fn transactions (if the fn service is configured) | pushes the operator's consumer worker into Held (Q7) | B 7.5 |

**Fixes before the demo opens to members, in order** (none of these is a new feature):
1. Per-uid accounts (split tenancy), or at least key files the shared uid cannot read. Retire the operator-copies-newcomer-secret onboarding in favour of the `possess` flow.
2. E F2 (a malformed binding must render as invalid, not fail) and E F1 (`text::one_line` in history and diff).
3. A F1/F15: classify 255 by decoded type in the shell and web.
4. A lower per-op Host budget, or a per-uid share, so one member cannot hold the Host for 600 s.
5. Drop every research listener and unreached command from the shipped binary (section 2).

---

## 8. Questions for the Lean side

I merged roughly 110 shard questions (A 12, B 16, C 19, D 16, E 13, F 19, G 13) into 45 distinct ones. Each is phrased so a Lean reader can answer by pointing at a declaration. Shard question numbers are in brackets.

### 8.1 Refusal and 255 semantics

- **Q1. Throw after commit.** In `serveFrame` (`Host/Main.lean:2616-2666`), can any handler reached through `dispatchSession` or `fnDispatch` append a durable event and *then* throw or return, so the request is answered `255 refused operationRejected` (`RequestRefusal.answer_refused`, `Host/RequestRefusal.lean:91-99`) or `255 unavailable "host session reopening"` (`:2646-2654`)? Which declaration orders the durable append after every fallible step, or does session invalidation (`state := none`, `:2659-2662`) cover every post-commit failure? A sub-question: is there a declaration that the Host never emits response byte 254, which Rust treats as "never forwarded, certain" (`transport.rs:1136-1141`, `:1166-1173`)? A second sub-question: can op 128 (clock submit) answer 255 for a well-formed retained ingress after the clock root moved? [A Q1, A Q5, B Q1, B Q9, C Q10]
- **Q2. Refused at admission implies no append.** Is there a theorem that an `Outcome` with `type = refused` and `phase = "admission"` from op 2 means the call was not committed? The append path authors a new operation on this basis (`replan.rs:109-117`, `workspace.rs:3634-3645`). [A Q2, F Q8.1]
- **Q3. `staleTarget` only before commit.** Is `DeclaredResourceController.Reject.staleTarget` (`Kernel/DeclaredResourceController.lean:2089`) ever returned after a write is recorded, through any path (a prepare/submit replay, carried history)? Chat re-proposes on the substring (`chat.rs:1561`). [F Q8.2]
- **Q4. A machine-readable retry class.** Can `NativeHostCodec.Outcome` carry an explicit no-effect/retryable class (or a stable refusal code), so Rust stops branching on prose? Today Rust branches on:
  - the phase string "fn-session" (`drain.rs:1144-1147`);
  - `repr` constructor paths (`pay.rs:321-363`);
  - English key-status text (`key_rotation.rs:139`; `Kernel/NativeHost.lean:498`);
  - verdict substrings (`activity.rs:191-192`; `Host/ObjectiveActivityJson.lean:372-373`).

  Related: why do op 151 refusals drop their inner reason (`Host/Main.lean:6734`)? And is the local codec's `inspect outcome` guaranteed to decode a 255 frame identically to the serving Host when the images differ? [B Q15, C Q19, D Q13, F Q8.18, E Q8.12, A Q11]

### 8.2 Replay keys and lookups

- **Q5. The replay key.** What key does replay detection for op 2 and op 3 use: the full signed call, (signer, nonce), or the intent? If the same `intent.json` is observed, prepared and signed twice into two different `call.bin`s, is the second refused, answered `replayed`, or admitted? [B Q5, A Q3]
- **Q6. Which submit receivers are replay-first?** Does each of these look up the ingress's operation identity before admission, as `FleetTurnReceiver.receiveLoaded` does (`Kernel/FleetTurnReceiver.lean:186-188`)?
  - op 142 (`NativeHost.receivingSubmitLoaded … SubjectKeyRotation.family`, `Host/Main.lean:7015-7020`);
  - op 88 (`enrollmentSubmitLoaded`), op 94, op 189 (`NativeHostKeyCommitmentAdoption.submitLoaded`);
  - ops 84, 28, 54, and op 217 (seat submit).

  Also: is there any receipt-only lookup for op 125 (realm well), and does `RealmWellReceiver` dedupe by anything but the nonce? [D Q2, D Q3, C Q7]
- **Q7. At-most-once by content.** Does `Kernel/ObjectiveActivityReceiver` refuse or dedupe a second `topUp` (or `publish`, `create`, `birth`, `resolve`, `abandon`) with identical content and a different nonce? `deliver` has `second_same_await_is_collision`. Do `JobMoneyReceiver` FUND and CLAIM refuse a second call independently of the job law text? Which public ops are not deduplicated by call identity at all (candidates: 12-19, 131-137, 150)? Is op 13/15 ACK idempotent for the same txn, is op 12/14 poll free of durable writes, and what authorizes a public caller to ACK? [F Q8.3, C Q13, B Q16, B Q2-Q4]
- **Q8. Lookup answers.** Can lookups 89, 95, 143, 190, 85, 29 or 55 ever return `contention`, or `refused` for an admitted original? (Op 99 cannot: `Kernel/NativeHost.lean:1500-1511`.) Does op 77 return the same receipt fields as op 76's committed `dispatchReceipt`? What is the intended recovery for a pay claim whose reply was lost before a Host upgrade, given that op 191 is reserved without a receiver? [D Q7, C Q12, C Q16]
- **Q9. A definitive `absent`.** Does op 3 have an answer meaning "never admitted" for these exact call bytes, final in the sense that it can never later become admitted? Which declaration guarantees it? It would replace Rust's "newest outcome is refused" rule for births (`workspace.rs:4308-4342`) and unwedge the lookup-only machines. [A Q4]
- **Q10. Height convention.** Is the next transaction's height `genesisHeight + acceptedCount` and the last accepted one's `… − 1`? Is a slot with `validUntil = h` admissible at `h`? (`provider_continuity.rs:455-470` vs `hermes_handoff.rs:383-390`.) [F Q8.4]
- **Q11. "Expired, never admissible".** Could the Host answer, for an exact retained call, that it can never be admitted at any height ≥ H? Today Rust derives `retire-expired-contention` (`provider_continuity.rs:832`). [F Q8.5]

### 8.3 Identity and keys

- **Q12. Uniqueness.** Which declaration in `Kernel/ParticipantKeyEnrollmentReceiver.lean` refuses a client-chosen `subject` or `keyId` that already exists, including a keyId of a revoked or rotated-away key of another subject? [D Q1]
- **Q13. KeyRecord defaults.** Do the enrollment and rotation receivers require `keyEpoch = 1` (or current + 1), `activeFrom = 0`, `activeUntil = 2^64 − 1` and `algorithm = 1`, or accept any? Confirm the op-87 assembly layout (64- or 160-byte second half, `participant_enrollment.rs:1561-1567`). [D Q6, D Q15]
- **Q14. Revoked vs rotated.** Is there a Host query distinguishing "key rotated away" from "key revoked for compromise" for a past key (`hermes_handoff.rs:340` checks currency only on first delivery)? Is `verify_strict` in the Host verifier meant to refuse every signature that ed25519-dalek's non-strict `verify` accepts, so client pre-checks should be strict too? [F Q8.8, D Q16]

### 8.4 Routing, bounds and wire

- **Q15. Routing-only ops.** For each of the 69 operator-only ops, is there a Lean check that refuses a non-operator caller independently of socket routing? Op 42, 64, 32/33, 36/37 and 117-120 look routing-only. Related:
  - op 55 is operator-only in the registry but used for a recipient lookup (`share_issue_receipt.rs`). Should it list `public`?
  - ops 24/25 are "stdio only" with empty routes, yet `dispatchSession` has arms for them (`Host/Main.lean:2093-2098`). Which is current?

  [B Q10, D Q4, F Q8.10]
- **Q16. Inclusion.** Can op 151 (or a sibling) return an opening proving that the accepted record at `acceptedCount` carries a given `transactionId`/`eventId`, so `finish_attempt` can bind a confirmation to its call rather than to a point (`receipt_continuity.rs:843-876`)? [E Q8.5]
- **Q17. Shared names.** Should `sharedNameAt` (`Kernel/ContentResource.lean:1782-1788`) refuse non-canonical `mini-name` links (the `KIND/ID` path, canonical decimal, kind set) in every content document, so the renderer's strictness cannot be weaponised (E F2)? [E Q8.6]
- **Q18. Layouts with no declaration.** Is the ROOM-SCHEMA v2 field assignment (1001-1012, roster tail from 2000, `room_schema.rs:27-55`) declared anywhere in Lean? Does content admission accept a `link` whose target type disagrees with the cell's storage (`workspace.rs:5410-5417` infers it from JSON shape)? Is `render.view = "moved"` produced only by the Host, or is the client's rewrite after a refused `at` read (`workspace.rs:1952-1955`) its only producer? [E Q8.8, A Q9, E Q8.13]
- **Q19. Per-op bounds.** Does Lean bound op bodies beyond `Kernel.Bounds.frameBytesMax`? Rust hard-codes about 25 limits (`transport.rs:39-49`, `:308-618`; list in B Q6). Should `Kernel.Bounds` emit them? Do the decoders accept exactly what Rust filters for:
  - op 153 (header `minidregg-carried-call-lookup-v1`, 1..1024);
  - op 17 (legacy, v2, v3 shapes);
  - op 19 (`u32le|metadata|u32le|request|response`);
  - ops 12-18 and 112;
  - ops 131/132/134 (Rust sends `u32le(len) ‖ jam ‖ ABI JSON`, ASCII decimal, and JSON)?

  [B Q6, B Q13, B Q14, C Q18, A Q6, E Q8.9]
- **Q20. Op 0 side effects.** Does `sessionOpened` (op 0, `Host/Main.lean:2016`) write anything? [B Q8]
- **Q21. Op 8 cost.** Are op 8 `object-audience`/`-roster` (`sessionWalked`, `:2050-2066`) read-only, and what is their worst-case cost? Rust budgets them at 120 s as "pure" and kills the Host on overrun. [B Q7]
- **Q22. Hiding root.** Is `hiding::verify_view`'s root (`ROOT/v2 = cSHAKE256(frame ‖ leaf_1 ‖ … ‖ leaf_n)`, `hiding.rs:317-321`, `:462-480`) exactly the `Compiler/StoreCodec.lean` hiding root, including how `frame` is encoded? Which test vector pins the root? [B Q12]
- **Q23. Channel assemble.** Does `Schedule.assembleTagged` (`relay.rs:1077`) drop cells whose holder is not the slot's lease holder, and what does it do with two cells from one holder in one tick? [B Q11]

### 8.5 Laws Lean should emit

- **Q24. Genesis.** Is there a Lean genesis author for `minidregg-candidate-genesis-params-v1` that `genesis.sh` could call (`Host/Json.lean:3805` lists `genesis`)? Is a permit-all `factoryPredicate` (`genesis.sh:125`) the intended deployed factory law? [G Q3]
- **Q25. Shell law templates.** Can `document_law("draft"|"note"|"index")`, `room_law("open"|"realm"|"private")` and `board_law` be emitted by Lean, as the job law is (`Kernel/Job.lean` via `scripts/gen-joblaw.py`)? Which module should own them? [A Q8]
- **Q26. Default policies.** Is `{"type":"all","predicates":[]}` the intended law for a sponsor-funded member or agent account (`fleet.rs:1088`, `deploy/shell/OPERATOR.md:66-70`), for the Hermes till and budget account, and for the private room cell, or should Lean emit a default? [D Q11]
- **Q27. Story law.** Is `Assurance/StoryLaw.lean` `law` (`:111`) meant to become the emitter for every table (a Host `author story-law`)? Is there a Lean counterpart of `story::table_of`'s validity rules? Does `RoomBirthGate` still judge a placement without naming the new cell's law (`story.rs:46-51`)? [F Q8.13, F Q8.16]
- **Q28. Room keys.** Is the `Kernel/RoomRelease*.lean` family plus `Host/RoomKeyReleaseAuthor.lean`, imported only by `ResearchWip.lean:91-116`, meant to replace the client release machine (`roomkey.rs:1712-2110`)? Which op is reserved for "event67"? Is `Kernel/PrivateRoomWrapGrant.lean` still "AUTHORED, NOT COMPILED" (`Kernel.lean:156`)? Does `who` (`Host/Json.lean:1509`) list only current, unrevoked, unexpired grants covering the room cell? [F Q8.14, Q8.15, Q8.17]
- **Q29. Privacy checks Lean could make.** Is there any Kernel or law check that private-room cells accept only sealed atoms (A D4)? Does the content receiver check a sealed atom's `seq`/`prev` binding (`protected_atoms.rs:3-12`)? Which declaration validates an audience phase transition on `install-source`? Does `objectAudienceRosterLoaded` check that every package in a resume manifest wraps to a roster device? Is a Lean `carryFormatting` planned? [A Q10, E Q8.3, Q8.4, Q8.7, Q8.11]
- **Q30. Session lifecycle.** Which declaration defines app field 1 = 4 as "serving" and session status 1 = web active, 5 = api active, status + 1 = closed? Is there a Lean command for closing an event-28 session that `session_reenroll.rs:630` should use? [D Q5]
- **Q31. Codec tables and policy revisions.** Is `CredentialAuthorityEntryCodec.verbTag` exactly read 1, write 2, delegate 3, install 4, revoke 5, append 7, place 10 (`shell/law.rs:59-67`), and can it be emitted as a table? Does the install-policy receiver require `version = previous + 1` and `previous = current head` (`law_export.rs:14-66`)? Should kind revision be strictly increasing intrinsically, or only by law (`Kernel/WorldKindProjection.lean:118-126`)? [A Q7, D Q12, E Q8.2]

### 8.6 Clock and time

- **Q32. Clock monotonicity.** Which declaration in `Kernel/ClockTickReceiver.lean` refuses `now ≤ current.now` (strictly), and is `maxStepSeconds = 0` refused at genesis? `clock.rs:372-390` loops until a non-confirmed tick. [C Q8]
- **Q33. Clock rate.** Is there any Lean bound on ticks per independent witness (pay-observed `blockTime`, height)? Without one, a clock key's blast radius is unbounded. [C Q9]

### 8.7 Money

- **Q34. Nullifiers.** Do `PayObservation.nullifier` (`Kernel/PayObservation.lean:164-167`), the self-enrollment receiver and the claim receiver spend one `StableNullifier` space for the same `(signature, address)`? Can an `alreadyConsumed` refusal (op 110, op 119) name *which* nullifier was spent (the tick's or record k's)? [C Q1, C Q2]
- **Q35. Floors, leases, quotes.** Is `tariff.journalFloor` applied to ordinary book rows too, or only to the enrollment index? Is a lease active iff `leaseUntil > clockHour` (strictly; `Kernel/PayClaimStatus.lean`, `DREGG/PAY/ENROLMENT-VIEW/v3`)? Is `PayClaimQuote.maxQuoteLifetimeHours` the constant 1, and which declaration defines the processing hour? [C Q17, C Q5, D Q14, C Q4]
- **Q36. Fleet fee.** Is a fleet turn's fee always exactly `config.tariff`'s base (`fleet.rs:208-210`)? [D Q10]
- **Q37. Market.** Does `Kernel/SealedMarket.lean` (or `law.market`) constrain the allocation beyond fill ≤ revealed quantity and phase? Is a Lean `clear` with a theorem planned? [C Q14]
- **Q38. Room membership.** Is there any Lean receiver tying a `renew` publication on a till to a member window, or is the concierge (`grain-runtime/src/concierge.rs:147-180`) the only judge? [C Q15]
- **Q39. Compute credits.** Does `RunComputeBudgetDomain.prepare` or the `computeFunding` arm (`Kernel/DeclaredResourceController.lean:1140`) refuse `credits ≠ max(0, steps − (freeSteps − usedSteps)) × creditsPerStep` against the signed `ComputeQuote`, and re-read `expectedPayerBalance`/`expectedBookRoot` as CAS guards? [E Q8.1, Q8.10]

### 8.8 Rooms, chat, Hermes

- **Q40. Roster writes.** In an adopted workroom or social room, can a non-founder holding `mutate` or `place` write field 2000 (the founder row)? Which clause forbids it? Does a scalar `create` on an object field that already holds a value refuse (chat writes roster slots with `create`)? [F Q8.6, F Q8.7]
- **Q41. Assignment and representation views.** Could the Host expose "current Hermes assignment for room cell C" (F V7)? What does admission answer for a `revoke` naming a grant the recipient does not hold (`hermes::dismiss`)? Is "the event13 owner packet is an `inlineObject` atom of schema `11` whose id equals the receipt's `transactionId`" stated in Lean (`selected_exchange.rs:714-731`)? [F Q8.12, F Q8.19]

### 8.9 Consent coverage, wire versions, journey reds, money details

- **Q42. Consent coverage and registry.** What is the authoritative list of plan ops requiring local consent reconstruction: `NativeSpecializedConsent.supported` (15 ops) plus `extraExpected` in `Host.ClientConsentSpecializedSession`? Specifically, are ops 32, 36, 44, 48, 50, 52, 58, 66, 68, 70, 74, 78, 80, 82, 201 and 206 covered, and should 56 and 194 be? Should frames 220-233 (`Host/ClientConsentCore.lean:369-610`) get a registry beside `protocol/host-operations.json`, with 224/226/227 named, and 228/229/233 marked as resident-only? Is `take_stale_observation` per-thread? Can the Lean side emit a forged-plan fixture so `thin-proxy.py` stops re-implementing the codec? [D Q8, D Q9, F Q8.9, F Q8.11, G Q6]
- **Q43. Wire and grammar versions.** Is there a reason to keep envelope v1 (`transport.rs:177`)? Which declaration refuses a content target whose `schemaVersion` is not 10 (`Kernel/ContentResource.lean:432`), and with what reason? Was the Host CLI verb `link-index` dropped on purpose (merge `a26328e9`)? Is pre-rotation mandatory for every shell-enrolled newcomer (the `enroll plan NAME KEY NEXT COSIGN` grammar that breaks JMKT, J12W and JDISCLOSE)? [G Q5, G Q2, A Q12, G Q1, G Q4]
- **Q44. Persistent journey reds.** Which rows of K-CLOCK (21/32) and KBW ("1 rows off") disagree with `ClockLaw.clockPredicate` and `birthSlack`? Is KH's "create 3 failed" a script lag behind K-FIELD-CLOSURE (`undeclaredField`)? Why do K11's six appends and four tails take 2,566–3,409 s? [G Q7, G Q8, G Q9]
- **Q45. Money details.** At consumption, does `PayEnrolV2Decision` re-check `creditedRemainder ≥ minimumStarterCredit`, `membershipCredit > 0` and renewal `birthFee = 0`? Does `PayAssignmentReceiver` bound book rows per subject? Is a reserve always the last accepted transition of its batch, so that `reserveIndex = acceptedCount − 1`? [C Q3, C Q6, C Q11]

---

## 9. Where the reports disagree, and claims that look wrong

| # | Claim | By | Settlement |
|---:|---|---|---|
| 1 | "`rc-A/arm-module.tsv` omits `fleet-sign`" | G 5.1 | **True for the tsv only, and incomplete.** The tsv also omits `bend-session-sign`, and its module column is wrong for about 15 rows (section 2). A's *report* table (A 1.3) lists both pre-parse arms (`main.rs:4508`, `:4514`), and A's count of 127 live commands already **includes** `fleet-sign` (125 `run` arms + 2 pre-parse). "127 commands plus `fleet-sign`" therefore double-counts. The right figures are 127 live and 130 names with the tombstones. |
| 2 | "`consent-resident` has no live caller" (in A's ~45 unreached) | A 1.3, A 5 | **Wrong.** `client_consent.rs:418-420` (checked) starts `std::env::current_exe()` with the argument `consent-resident`, so every signing `mini` process can spawn it. D 7.1 describes the resulting daemons. A's reach scan looked only for external callers. It is deployed (internal), not unreached. |
| 3 | "115 public ops" | B 2.2 | **Off by two.** `protocol/host-operations.json` (checked with a one-off count) has 186 entries: 113 active `["operator","public"]`, 69 active `["operator"]`, 2 active stdio-only (24/25), and 2 reserved with `["operator","public"]` (191, 192). The tiny-crates report says 113. B's 115 evidently counted the two reserved entries as public, though B's own row says they are refused. B's conclusion (no exposure change, lists agree with the registry) stands. |
| 4 | "Chat: compiled; no recorded run has joined chat to a native Host" | root README row "Chat" (`README.md`, Honest state) | Not A's claim; it is the README's. **Stale as worded.** F found J14 PASS (`docs/evidence/2026-10-01-p-hermes-room/j14.tsv:33,38`, `tail-final.txt`) running `chat new`, `chat invite`, `say`, `tail` and `ask` through `mini shell` against a native Host on a lane build. That run predates the in-process rewrite (`336b7c0e`) and ROOM-SCHEMA v2, so the **current** chat code has no recorded run, and JCHAT is SKIPPED in all three 10-01 results. Suggested row: "executed on a lane build (J14, 2026-10-01) before `336b7c0e`; current code unrun". |
| 5 | README: main "fails J5 and J8 … the fix is open" | root README (Native Host row) | **Stale.** CI on main passes J5 ("8/8 refused") and J8 ("5/5 refused") on 10-16, 10-17 and 10-23 (G 4.5). |
| 6 | README: "the call (C1-C8) and send (S1-S7) drivers exist and no journey row runs them" | root README (Objective activities row) | **Stale.** `journey-rows:105-133` has run `call` and `send` since `f5897dd8` (2026-10-07), plus `domain`, `upgrade` and `chargedfailure`; send is now S1–S13 (G 4.5). |
| 7 | README: "the tariff counts hours, so the quoted week is 49.999992 DREGG, not 50" | root README (Payments row) | **Stale.** The tariff is v4 with `nodeWeekRate` stored (`Kernel/PayTariff.lean:30-35`); `deploy/pay/enrol-terms.json:8` sets 50,000,000 atomic = exactly 50; Rust copies the quote verbatim (C 7.5). |
| 8 | README: Studio has "no member-reachable route" | root README (Studio row) | **Nuanced, not wrong.** No public route exists. On main, the Studio routes are reachable inside a member's own loopback `mini web` (`web.rs:603-637`), and no unit or journey reaches them (A 1, E 5.2). The row could say "loopback only". |
| 9 | `mix`, `mix-live` "unreached" | A 1.3 | **A difference of definition.** A counts journeys, deploy and `scripts/`. G shows the root-level `cohort-native-tcp.py` and `cohort-two-host/*` drive them, with docs/evidence/traffic-v13 as the record. Both are right: unreached by any gate, evidence-only. |
| 10 | "Nothing in this shard is deployed" | C exec 14 | **Scope.** True of pay (the watcher is inactive) and of the public node as the README describes it. But `deploy/clock/mini-clock-tick.*` and `deploy/checkpoint/mini-checkpoint-certify.*` are units in this repository, and A counts `clock`/`checkpoint` as deployed. Whether those timers run on the public node is not recorded in-repo (the node state was read "outside this repository"). |
| 11 | A's demo minimum includes `pay`, `join` and `enroll` arms | A 10 | **Disagrees with C and the README** for the current demo: pay is not deployed. I keep `join` (plain) and `enroll` in tier 1 and move `pay` to tier 3. |
| 12 | A F6 "possible panic on an empty reply on the `--remote` path" | A F6 (asked shard B) | **Settled by B 4.3:** no panic today. `transport::read_frame` refuses length 0 (`transport.rs:645`) and `mini_sdk::operator::read_frame` refuses `size == 0` (`native/mini-sdk/src/operator.rs:379`). The assumption is implicit, and the deadline variant checks it explicitly (`:961`). |
| 13 | v1 envelope senders: A lists `main.rs:3137`, `:3152`; B adds `publisher.rs:154` | A 5, B 1.2 | Consistent: three Rust senders. `publisher.rs:154` is also unpinned (`transport::invoke`, not `invoke_pinned`, F F8). |
| 14 | Custody machines: "about 9" | D 5.1 | A count within D's shard. Crate-wide it is about 15 (section 4.1). |
| 15 | JPD (protected documents) is a registered journey step | G 1.2 | Registered, but its target script says it "has only had bash syntax checking" (`scripts/protected-document-journey.sh:2-4`). E 5.2 independently finds no evidence for protected documents. Treat it as unproven. |
| 16 | `jweb.sh` describes `mini web` as "read-only" | `jweb.sh:2` | **Wrong now.** E 1 and A 1 show POST routes for edit, create and Studio. `jweb.sh` checks only that one POST returns 405. |
| 17 | `hybrid_kem.rs:1-15`: "every key exchange is hybrid" | code doc | **Wrong.** `channel.rs:201-208` uses raw X25519 (B 5.4). |
| 18 | `credit.rs:1-13`: "Nothing here decides admission" | code doc | True of the file, misleading about the system: the payment-for-membership decision is the Rust concierge's (C D2). |

No other cross-shard contradictions turned up. Where two readers looked at the same site (`transport.rs` from A and B, `client_consent` from A and D, `replan.rs` from A and F, `room_schema` from E and F, the retry paths from A, C, D and F), their findings agree and are merged above.

---

*End of synthesis. Shard reports: `resource-client--{A..G}-*.md` in this directory. Generator for the section 2 table: `/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/rc-synth/cmd.py`.*
