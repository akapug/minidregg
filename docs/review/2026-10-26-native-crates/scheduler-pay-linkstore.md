# Native crates review: inference-scheduler, pay-watcher, hyperdocument-link-sqlite-store, hyperdocument-link-store

Reader report, 2026-10-26. All four crates read in full: every `src/`, `tests/`, `build.rs`, `Cargo.toml`, README and script. Fixture JSON was sampled, not read file by file. Paths are relative to `/Users/ember/dev/minidregg/`. Abbreviations: **IS** = `native/inference-scheduler`, **PW** = `native/pay-watcher`, **SQ** = `native/hyperdocument-link-sqlite-store`, **LS** = `native/hyperdocument-link-store`.

## Executive summary

**SQ is the most load-bearing crate of the four.** It is the Lean Host's durable byte store, shipped as `bin/minidregg-link-sqlite-store` (`deploy/candidate/package.py:61`). It holds:
- an append-only durable log, the fn archive journal and history-accumulator nodes;
- a mutable checkpoint table and a legacy one-slot CAS record;
- a sibling SHA-256 "head anchor" file that detects rollback.

It is opaque and decides almost nothing. The one wire flaw: bound violations come back as `Conflict` (exit 4), and Lean reads exit 4 as a definite CAS conflict (`Compiler/DurableReceiverCore.lean:162`).

**LS is an orphan predecessor of SQ** (a twin, not a trait crate). It is not a workspace member. `cargo metadata` on it now fails with "believes it's in a workspace when it's not", so it cannot build at all from the tree. SQ's tests still `include_bytes!` its fixture (`SQ/tests/lifecycle.rs:12`). It survives only as the companion of the Lean module `Assurance/HyperdocumentLinkLocalFileStore.lean` and two scripts.

**PW decides more of "what counts as a payment" than the design laws allow.** It applies:
- net positive balance delta to book-owned token accounts;
- unanimous agreement across all endpoints;
- the RPC's "finalized";
- memo binding (1 memo, UTF-8, ≤566 bytes);
- an enrollment journal floor.

Lean re-checks the floor and memo grammar, and the kernel nullifier makes exactly-once the kernel's job. But PW **advances its persistent enrollment cursor past below-floor transfers permanently**, and the floor it uses comes from an operator env var (`PAY_JOURNAL_FLOOR`), not from the signed tariff that carries the same field (`native/resource-client/src/pay.rs:907`, `Kernel/PayTariff.lean:88`). If the two values drift, real enrollments are lost for good. Per-payer indices use a newest-100 window that dust can overflow. PW's `CurlTransport` doubles as resource-client's general HTTP client.

**IS is a Rust-authored fair-share scheduler.** Ordering (least virtual service), per-principal caps, backend choice (cheapest estimate), lease expiry and operator "resolve" charging are all decided in Rust, with no Lean counterpart. Lean owns only the homelab fee (`Kernel/ProviderRoute.lean:10,390`). Controller identity is a self-asserted field, checked only against the peer uid, so controllers that share a uid (the README's own example) can impersonate one another. The README names `deploy/hermes/mini-inference.service`, which does not exist.

---

## 1. What it is and does

### 1a. hyperdocument-link-sqlite-store (SQ) — 2,818 lines of Rust src+tests

- `src/lib.rs` (2,058 lines; 1,494–2,058 are unit tests) is a hand-written FFI to the system `libsqlite3` (`lib.rs:46-88`). There is no rusqlite.
- `SqliteByteStore::open_with_identity` (`lib.rs:413`):
  - creates the root `0700` and canonicalizes it;
  - opens `forward-link.sqlite3` with `SQLITE_OPEN_NOFOLLOW|FULLMUTEX` (`lib.rs:438-447`);
  - sets `journal_mode=DELETE`, `synchronous=EXTRA`, `fullfsync=ON` and a 5 s busy timeout (`lib.rs:465-473`);
  - runs `upgrade_schema` on every open (`lib.rs:492`).
- **Schema v5** (`lib.rs:554-566`):

| Table | Shape | Mutability |
|---|---|---|
| `opaque_record` | slot=1 BLOB ≤64 MiB, the legacy link/image record | CAS/UPSERT |
| `durable_seed` | slot=1 | written once |
| `durable_log` | `(height, record, tag)` | append-only at head+1 |
| `durable_node` | `(space, key, height) → value` | written with an entry, never rewritten |
| `durable_checkpoint` | `height → bytes` | **UPSERT: replaceable** (`lib.rs:1292`) |
| `archive_journal` | `(seq, record, tag)` | append-only at head+1 |

- **Operations:**
  - `compare_exchange` (`lib.rs:608-659`) and `publish` = CAS from absent;
  - `durable_init` (`:858`), `durable_read[_from_checkpoint]` (`:912-979`), `durable_history` (`:984`), `durable_append[_with_hook]` (`:1036-1159`);
  - `journal_append` and `journal_read` (`:1165-1271`), `durable_checkpoint[_at]` (`:1277-1327`), `durable_anchor_enroll` (`:783`);
  - big-endian binary encoders for the read files (`:1334-1492`).
- `src/anchor.rs` (275 lines) is the sidecar file `<root>.head-anchor` (`anchor.rs:103`), 120 bytes, magic `MINIANC2`.
  - It holds SHA-256 of identity‖seed, the log head height plus a digest of the head entry, and the journal head height plus a digest of its head entry (`anchor.rs:31-81`).
  - An `flock` on `<anchor>.lock` with a 5 s deadline serializes every operation (`anchor.rs:158-191`).
  - A custody check requires the file to be owned by the euid, with no group/other bits, in a directory owned by that uid or root and not group/other-writable unless sticky (`anchor.rs:117-137`).
  - Publish is write tmp → fsync → rename → fsync dir. A process-local `SYNCED` cache skips the re-fsync when the head is unchanged (`anchor.rs:214-275`).
  - Every read path re-verifies the retained head against the DB, then **re-publishes** the current head. Reads therefore write the anchor whenever it lags (`lib.rs:973`).
- `src/main.rs` (403 lines) is a CLI with 21 verbs (`main.rs:26`), an optional leading `--anchor-identity X`, and a `serve` coprocess mode (`main.rs:329-403`).
  - Request frame: `u32 argc, (u32 len, bytes)*`. Reply: `MDCOPRC1, u32 code, u64 len, stdout, u64 len, stderr`.
  - Exit codes: 0 ok, 2 usage, 3 Missing, 4 Conflict, 5 retired, 1 everything else (`main.rs:290-295`).
  - Crash and hold verbs fork their own child (`main.rs:303-306`).
- `build.rs` (62 lines): on Linux without `libsqlite3.so`, copies `libsqlite3.so.0` into `OUT_DIR` as a linker alias.
- Tests: `native/hyperdocument-link-sqlite-store/tests/lifecycle.rs` (311 lines) and `native/hyperdocument-link-sqlite-store/tests/durable_anchor.rs` (285 lines) drive the real binary through crash phases, concurrency, corruption, coprocess identity, and serve-versus-one-shot equality.

### 1b. hyperdocument-link-store (LS) — 713 lines

- `src/lib.rs` (222 lines): `LocalLinkStore` stores one ≤4,096-byte opaque record.
  - `stage` writes `forward-link.recovery.staged` (create_new + fsync).
  - `install_staged` hard-links it to `forward-link.recovery` (no overwrite), syncs the directory and unlinks the staged file.
  - `publish` = stage + install. Conflict on different bytes (`lib.rs:142-213`).
- `src/main.rs` (71 lines): the `minidregg-link-store read|stage|install|publish|discard-stage` CLI.
- `src/bin/forward_link_e2e_bench.rs` (314 lines): a child process per lifecycle stage, with p50/p95/p99 timings.
- `fixtures/hyperdocument-link-recovery-v1.bin`: 14 bytes, `a24a1ed8 01 "HYPERLNK" 6e`.
- `native/hyperdocument-link-sqlite-store/tests/lifecycle.rs` (106 lines).
- Last commit 2026-08-11 (`git log`). There is a 37 MB untracked `target/` inside the crate.

### 1c. pay-watcher (PW) — 2,380 src lines, 1,340 test lines, 707-line generator, ~63K lines of generated JSON fixtures

- Binary: `pay-watcher --config FILE --out DIR [--rpc-fixture DIR]... [--spool DIR] [--durable-ticks] [--ack-tick ID]` (`main.rs:37-69`).
- `config.rs` (189 lines): strict JSON with keys `asset{mint,tokenProgram}`, `book[{index,address}]`, optional `enrol{index,journalFloor,cursorFile}`, `maxPages` (default 4), `pageSize` (default 25, ≤1000), `minEndpoints` (default 2) and `receiptsDir` (`config.rs:73-170`). Endpoints come only from the `PAY_RPC_ENDPOINTS` env var (`main.rs:227`).
- `transport.rs` (405 lines):
  - `CurlTransport` spawns a hard-coded `/usr/bin/curl` (`transport.rs:179`) with `env_clear`, `--proto =https`, no proxy, no redirects, timeouts, `--max-filesize`, `RLIMIT_FSIZE`/`RLIMIT_CORE` set in `pre_exec`, and the URL fed on stdin via `--config -` (`:282-333`);
  - files are spooled privately in the spool dir;
  - `validate_endpoint` allows https, or http only to loopback (`:193-215`);
  - extra public methods `request` and `post_binary` (`:249-257`) exist for resource-client;
  - `FixtureTransport` maps each call to a file name and enforces `commitment: finalized` (`:67-141`).
- `decode.rs` (425 lines):
  - `token_accounts` (`:95`) and `signatures_of` (`:167`);
  - `transaction_credit` (`:214`) computes Σ(post−pre) over the watched accounts with attribution refusals (wrong program, mint or owner; PRE/POST disagreement; index out of range; signature or slot mismatch);
  - `transaction_version` (`:34`) accepts legacy, 0 and 1 and checks the v1 shape.
- `memo.rs` (118 lines): memo instructions (SPL Memo v1/v2) in execution order, top-level then inner; `bind` gives none / one valid / `memoInvalid` / `memoUnbound` (`memo.rs:27-34`).
- `model.rs` (303 lines): the `Reason` taxonomy (refusals, skips, notes), and the `Observation` JSON with hex byte fields (`model.rs:180-193`).
- `watch.rs` (617 lines):
  - `run` (`:448`): `common_tip`, the minimum finalized slot whose block time all endpoints agree on (`:162-195`);
  - per book index, `view_index` per endpoint (`:254-444`);
  - unanimous agreement per signature (`:508-567`);
  - `advance_cursor` for the enrollment index (`:586-617`);
  - receipts are read from directory entry names `SIGNATURE.ADDRESS` (`:119-158`).
- `main.rs` (296 lines) has two modes:
  - plain: atomic writes of `observations.json` and `events.json`, then the cursor;
  - durable: `pending.json` (type `minidregg-pay-watcher-tick-v1`) is fsynced first, its outputs are republished until `--ack-tick` renames it into `ticks/ID.json` (`main.rs:147-199,258-272`), under `flock` on `OUT/.tick.lock` (`:101-109`).
- Exit codes: 0 ok, 3 written with refusals, 2 nothing written.

### 1d. inference-scheduler (IS) — 1,793 src lines, 2,251 test lines, two Python journeys (977 lines)

- `src/lib.rs` (141 lines): the wire.
  - JSON frames with a u32 big-endian length, ≤64 KiB (`lib.rs:12,103-124`).
  - `Command` (tagged `command`): `status`, `status-groups`, `drain`, `enqueue`, `inspect`, `dispatch`, `finish`, `cancel`, `resolve` (`lib.rs:21-61`).
  - `Reply`: `status`, `job`, `refused`.
  - Client helpers `request` and `operate` use 5 s timeouts.
- `src/core.rs` (855 lines): `Config` (groups, controllers→{uid, principal, pool}, backends→{pool, group, endpoint, models→{context, max_output, tools, input_us, output_us}}) at `core.rs:7-50`.
  - Job states: `Queued`, `Placed{lease, expires}`, `Dispatched`, `Uncertain`, `Terminal{outcome}` (`:68-99`).
  - `enqueue` (`:271`), `schedule` (`:376-482`), `dispatch` (`:492`), `finish` (`:528`), `resolve` (`:646`), `cancel` (`:662`), `set_draining` (`:705`), `advance_floor` (`:738`), `recover` (`:778`).
- `src/service.rs` (739 lines):
  - a single-threaded UnixListener (`service.rs:466-527`) checks `SO_PEERCRED` (Linux only, `:530-554`);
  - the whole state is saved as `state.json` per mutating command (tmp + fsync + rename + dir fsync, `:278-300`);
  - immutable terminal receipts go to `receipts/<id>` (`:214-276`);
  - a failed save poisons the process (`:386-390`);
  - status pagination fits a 64 KiB frame (`:595-738`).
- `src/main.rs` (58 lines): `CONFIG STATE_DIR SOCKET` serves. The `check`, `status`, `status-groups`, `drain [wait]`, `resume` and `resolve` verbs follow. Serving requires `/etc/...` to be root-owned (`main.rs:6-15,48`).
- Only consumer: `native/grain-runtime/src/homelab.rs` (190 lines) and `grain-runtime/src/main.rs:9326-9350`, which builds the `Request`. Its id is `digest(domain, task, parent_generation, prompt_operation_id, request_digest)`.

---

## 2. What it assumes of its surroundings

### 2a. SQ

- **The Lean callers match the verbs.**
  - `Compiler/DurableReceiverCore.lean` issues `durable-read` (`:222,378`), `durable-append` (`:257`), `durable-checkpoint` (`:270`), `durable-init` (`:281`), `durable-seed` (`:301`), `durable-history` (`:355`), `durable-checkpoint-at` (`:398`) and `--anchor-identity` (`:154`).
  - `Host/FnArchivePublisher.lean` issues `journal-read` (`:308`) and `journal-append` (`:333`).
  - `Compiler/PortableParticipantPinIO.lean:46` uses `cas`; `Host/Main.lean:8882,8959,9002` use `read-to`.
- **Coprocess frame:** `Compiler/NativeCoprocess.lean:64` has `replyTag = "MDCOPRC1"` and `maxField = 64 MiB`. Both match `main.rs:336` and `lib.rs:25`.
- **Exit-code contract:** Lean treats 0 as success, 4 as conflict (`DurableReceiverCore.lean:157-165`), 3 as missing (`:228`) and anything else as uncertain. The Rust side maps more error classes onto 4 than "conflict" means; see §4.
- **Not in `protocol/host-operations.json` or `Host/Json.lean`.** This is a helper-process wire, not a host operation. Its byte formats are documented only in Rust doc comments (`lib.rs:1330-1333,1365-1368,1398-1399,1452-1453,1478-1479`); Lean has a matching parser.
- **Rust-only vocabulary:**
  - `durable-anchor-enroll` has no caller anywhere outside the crate (grep across `*.lean`, `*.sh`, `*.py`);
  - `cas-crash`, `publish-crash`, `publish-hold`, `durable-append-crash` and `journal-append-crash` are test fixtures, used by the crate's own tests and by `scripts/kn2/*`-style probes;
  - `database-path` is used only by tamper probes.
- **Filesystem assumptions:**
  - the anchor's parent directory is owned by the store uid or root, and is not group/other-writable or else sticky (`anchor.rs:122-127`);
  - POSIX `flock`; `libc::geteuid`;
  - Unix only (`std::os::unix`, `lib.rs:421`).

### 2b. LS

- Assumes Lean's `Assurance/HyperdocumentLinkLocalFileStore.lean` authored the fixture. That module models the store abstractly ("This is the entire callable native storage boundary", `:203`).
- No runtime caller. The only references are `test-hyperdocument-link-local-store.sh [deleted 52c252e3]:5-6`, `run-forward-link-e2e-benchmark.sh [deleted 52c252e3]:49` and SQ's test `include_bytes!`.

### 2c. PW

- **Output vs Lean parser.**
  - `Host/Json.lean:3611-3626` (`payObservationRecord`) expects exactly `index, address, signature, slot, blockTime, amount, mint, tokenProgram, memo, memoError`, which matches `model.rs:180-193`.
  - `payMemoField` (`Host/Json.lean:3598-3608`) accepts `memoUnbound` and `memoInvalid` and refuses both-set, which matches `model.rs:112-118`.
  - `payClock` takes `{slot, blockTime}` (`:3628-3631`), which matches `watch.rs:86`.
  - `natOrNumber` (`:3587`) accepts PW's JSON integers.
- **Envelope.** PW's `observations.json` is not itself a host command. resource-client `mini pay observe` wraps it into `payObservationCommand` (`Host/Json.lean:3636`), adding `observer`, `capability`, `nonce` and two roots, which travel through ops 108–110 (`protocol/host-operations.json:1226-1260`, owner `payments`). For enrollment, `payEnrolCommand` is used (`Host/Json.lean:3655`).
- **Config provenance.** `mini pay watch-config` writes the config (`native/resource-client/src/pay.rs:861-915`):
  - **mint and tokenProgram come from the signed tariff** (`:889-891`);
  - **enrol index and journalFloor come from CLI flags fed by env** `PAY_ENROL_INDEX`/`PAY_JOURNAL_FLOOR` (`deploy/pay/mini-pay-watcher:73-75`).
- **Receipts.** The resource-client observer workspace writes `receipts/` entries named `SIGNATURE.ADDRESS` (`deploy/pay/mini-pay-watcher:13-14`). The nullifier on the Lean side is `soltx:`‖sig‖address (`Kernel/PayEnrolClaim.lean:256`, `Compiler/PersistedCodecTags.lean:230`).
- **External.** Solana JSON-RPC (`getSlot`, `getBlockTime`, `getTokenAccountsByOwner`, `getSignaturesForAddress`, `getTransaction` with `jsonParsed` and `maxSupportedTransactionVersion:1`), plus `/usr/bin/curl`.
- **Dangling references.** README and docs cite `PAY.md`, `planning/pay/p1-watcher.md`, `p1b-enroll.md` and `journey.d/jpay1.sh` at the repo root. None exist in this repo (`ls` fails). `journey.d/jpay1.sh` exists only as `native/resource-client/journey.d/jpay1.sh`, and `jpay-e1.sh` was not found.

### 2d. IS

- Wire consumer: grain-runtime only. There is no host operation, no `Host/Json.lean` key, and no Lean reference to the socket, the config or `queueTimeoutMs` (grep). Lean's view of homelab is the provider route `homelab` (`Host/Json.lean:2684`, `Kernel/ProviderRoute.lean:10,192,206,390`), which charges a fee.
- Assumes Linux (`SO_PEERCRED`; non-Linux returns an error, `service.rs:549-553`), a root-owned config, and a private state directory owned by the euid.
- The README assumes `deploy/hermes/mini-inference.service` (README "Operation and supervision"). **It does not exist**: `deploy/hermes/` holds only `mini-hermes.service` and `README.md`. The candidate packager does ship the binary (`deploy/candidate/package.py:65,85`).

---

## 3. Does it decide anything semantic?

### 3a. SQ: essentially no, with three small exceptions

- **Append ordering and dedup** (`lib.rs:1099-1114,1198-1210`): it enforces "append h+1 at head h" and "identical bytes = AlreadyPresent". This is physical CAS, and Lean owns the meaning of the chain and MAC (comment at `lib.rs:662-665`). Acceptable.
- **The anchor is a Rust-authored integrity policy.** It refuses a store that is behind the retained head or has a different entry at the retained height (`lib.rs:822-854`). Lean has no counterpart for the anchor format (`anchor.rs` digest domains `mini-opaque-anchor-*-v1`); it sees only "exit 1 / error". It is a physical rollback guard rather than admission, but it is a security decision made in Rust. Its threat model is spelled out in `anchor.rs:109-116`: the digest is unkeyed, so custody is the only protection.
- **Checkpoint replacement is allowed** (UPSERT, `lib.rs:1292`), justified as "a key rotation re-seals" (`:1273-1276`). Whether a replaced checkpoint is acceptable is left to Lean's MAC verification; Rust allows the overwrite.
- **Schema migration policy** (`lib.rs:505-536`): v0 migrates, v2–4 unseeded upgrade, v2–4 seeded refuse. Physical.

### 3b. LS: no. Stage, install, conflict

### 3c. PW: yes, several decisions

| Decision | Where | Lean counterpart |
|---|---|---|
| A credit is Σ(post−pre)>0 over the token accounts the book address currently owns for the mint | `decode.rs:259-267`, `watch.rs:408` | Kernel receives `amount` and trusts it; none found re-deriving it |
| Attribution: post-balance programId, mint and owner must equal config | `decode.rs:292-305` | none (Lean never sees balances) |
| Finality = RPC `finalized`; tip = min slot across endpoints with agreed blockTime | `watch.rs:162-195` | Kernel checks tip non-regression (`tipInvalidOrRegressing` mentioned at `deploy/pay/mini-pay-watcher:113`) |
| **Agreement = unanimity of all configured endpoints**; `minEndpoints` is only a floor on the count | `watch.rs:512`, `:454` | none |
| **Enrollment journal floor**: below-floor credits not emitted and marked *settled* (the cursor passes them) | `watch.rs:414-417`, `:230-241` | `Kernel/PayEnrolDecision.lean:146,177` re-checks `tariff.journalFloor ≤ o.amount` but never sees dropped ones |
| Memo binding: exactly one memo, UTF-8, ≤566 bytes, else `memoInvalid`/`memoUnbound` | `memo.rs:22-34` | `Kernel/PayEnrolMemo.lean:419` has the same 566 constant (duplicated, not shared) |
| What is "settled" (failed, zero delta, net debit, below floor, receipted) | `watch.rs:230-241,507` | none |
| Dedup of repeat observations: none in PW; it resubmits until a receipt exists | `watch.rs:314-321` | kernel nullifier `soltx:` (`Kernel/PayEnrolClaim.lean:256`), correctly the kernel's |
| Which book rows are watched (assigned rows below `nextFree` plus the enroll row) | resource-client `pay.rs:879-883` | pay view (signed) |

Exactly-once and lost replies:
- **Exactly-once credit is the kernel's.** A payment observed twice (same tick, two accounts) is deduplicated in-process by signature (`watch.rs:288,326-346`). Across ticks it is resubmitted until a receipt file appears, and the kernel nullifier refuses the second credit ("a spent nullifier is 'already credited'", `deploy/pay/mini-pay-watcher:25-27`). One transaction paying two book addresses gives two observations, because receipts are keyed per (sig, address) (`watch.rs:107-110,473-477`).
- **Lost reply to Lean:**
  - in durable mode the pending tick is replayed byte-identically until `--ack-tick`, and the wrapper acks only on observer exit 0 or 3 (`deploy/pay/mini-pay-watcher:104-110`);
  - an uncertain observer (exit 4) keeps the tick, and the next run republishes the same observations at the same tip (`main.rs:224-226`);
  - the resource client's "exact retained call / lookup" settles it.
- **Who decides that a payment counts:** PW decides which on-chain events become candidate observations, and which are permanently dropped. The kernel decides credit.

### 3d. IS: yes, all of placement

| Decision | Where | Lean counterpart |
|---|---|---|
| Admission to queue: model, context+output ≤ context, tools, pool, per-principal queue cap, global `max_jobs`, archive budget | `core.rs:288-346`, `service.rs:345-363` | none found |
| **Ordering/priority**: least accumulated virtual service, then FIFO `order`, then cost, then backend name | `core.rs:449-460` | none |
| Fairness floor for idle or new principals | `core.rs:348-360,738-771` | none |
| Backend/endpoint selection (cheapest-estimate eligible backend with a free group slot) | `core.rs:437-479` | grain-runtime re-checks the selected endpoint against the provider table (`grain-runtime/src/homelab.rs:104-113`); Lean none |
| Cost estimate `max_input*input_us + max_output*output_us`, charged as virtual service; refunded and replaced by wall time on completion | `core.rs:444-448,627-640` | not money; Lean fee is `schedule.homelab` (`Kernel/ProviderRoute.lean:192,206`) |
| Lease expiry / queue deadline → `Expired` | `core.rs:378-399` | none |
| Retry policy: restart re-queues `Placed` with a fresh lease, caps old-lease guards at 1,024, then `NotSent` | `core.rs:786-808` | none |
| Operator `resolve` charges elapsed wall time | `core.rs:646-660` | none |
| **Identity binding** controller→principal (config); principal→Mini subject (grain-runtime `main.rs:9329-9334`) | IS config + grain-runtime | none in Lean |

**Pricing and budget** stay in Lean (homelab fee, reserve). Ordering, priority and identity binding are Rust's, by design ("This is an initial equal-weight, request-boundary policy", README). By ATLAS §7 ("Every decision point is a Lean export"), IS is a whole Rust-authored policy surface.

---

## 4. Flaws, each with a failure scenario

### SQ

1. **Bound violations reported as `Conflict` (exit 4).** `durable_append` returns `StoreError::Conflict` for `height==0`, `tag>4096`, `nodes>4096`, oversize node key/value, duplicate node keys (`lib.rs:1077-1088`), and for `seq==0` or tag>4096 in `journal_append` (`:1185-1187`). Lean maps exit 4 to `.conflict`, the CAS-contention path that "reloads and recomputes" (`DurableReceiverCore.lean:162`, README "CAS contention reloads and recomputes").
   - *Scenario:* a Lean codec change produces a 4,097-byte tag. Every append returns 4, Lean reloads, recomputes the same tag, and retries.
   - *Result:* a livelock, or a misleading "contention" diagnosis instead of a hard error. Nothing is written, so there is no data loss.
2. **Reads write.** `durable_read`, `durable_history`, `journal_read` and `durable_checkpoint_at` all call `guard.publish(&anchor_head)` (`lib.rs:973,1026,1269,1325`). After a restart, the `SYNCED` cache is empty, so the first read of an unchanged head performs file and directory fsyncs (`anchor.rs:219-234`). A read on a read-only mount or a full disk fails, not degrades.
   - *Scenario:* the disk fills; read-only Host views (web docuverse queries) begin failing although no write is needed.
3. **Each `serve` request reopens the database and runs `upgrade_schema` under `BEGIN IMMEDIATE`** (`main.rs:86,95,...` → `lib.rs:480,493`). Every query takes the write lock plus five PRAGMAs. Under concurrent Host refreshes this serializes readers, and the 5 s busy timeout turns contention into exit 1, which Lean reads as "uncertain".
4. **Anchor-before-seed ordering at genesis** (`lib.rs:886-888`). The genesis anchor is published before the seed transaction commits. If the commit fails for a non-crash reason (SQLITE_FULL), the anchor names a genesis the DB lacks. A later `durable_init` with a *different* seed is refused, which is intended. But any `durable_*` read reports `Missing` (no seed) while the anchor exists, and `durable_anchor_enroll` has no caller, so recovery is manual.
5. **Leaked anchor temp files.** A crash between `create_new` and `rename` (`anchor.rs:243-252`) leaves `<anchor>.<pid>.<n>.tmp` in the parent directory forever. Nothing cleans them. It is harmless but accumulates.
6. **`compare_exchange` ABA tolerance** (`lib.rs:637-641`): if current == proposed it returns `AlreadyPresent` whatever `expected` was. This is intended idempotence. It means a CAS whose precondition was false reports success when the state already matches. The legacy one-slot users (`cas` in `PortableParticipantPinIO`) must not infer "my precondition held".
7. **README is stale and contradicts the code.**
   - "dependency-free Rust crate": it depends on `sha2` and `libc` (`Cargo.toml:16-18`).
   - "Opening the original 4096-byte schema upgrades it transactionally": true for v0, but v2–4 seeded stores are refused as `RetiredSchema`, and a `MINIANC1` anchor is refused (`anchor.rs:84-88`).
   - It never mentions the anchor, the journal or the nodes.
   - *Harm:* operators reading the README will not back up `<root>.head-anchor`. The anchor deliberately lives outside the store directory (`anchor.rs:102`), so a directory-only restore refuses: "missing anchor; existing Stores require explicit audited enrollment" (`lib.rs:823-825`), and the enroll verb has no wrapper.

### LS

8. **It cannot build.** `cargo metadata --manifest-path Cargo.toml [deleted 52c252e3]` fails: "current package believes it's in a workspace when it's not". `test-hyperdocument-link-local-store.sh [deleted 52c252e3]` and `run-forward-link-e2e-benchmark.sh [deleted 52c252e3]` therefore fail as soon as they reach cargo. The crate has no `[workspace]` table to opt out, and it is not a member.
9. **A partial staged file wedges it.** If a crash lands after `create_new` but before `write_all` completes (`lib.rs:159-176`), a later `stage(bytes)` reads the truncated staged file and returns `Conflict` (`:152-156`). It keeps doing so until someone runs `discard-stage`, and no caller does that automatically.

### PW

10. **Operator floor vs tariff floor gives permanent loss.** `journalFloor` is taken from `PAY_JOURNAL_FLOOR` (`deploy/pay/mini-pay-watcher:73-75` → `pay.rs:907-908`), not from `tariff.journalFloor`, which the signed pay view already carries (`Kernel/PayTariff.lean:88,144`). Below-floor transfers count as *settled*, and the enrollment cursor moves past them forever (`watch.rs:230-241,608-615`).
    - *Scenario:* the tariff lowers the floor from 1 DREGG to 0.5 DREGG and the operator env is not updated. A 0.7 DREGG enrollment is skipped as `belowJournalFloor`, the cursor passes it, and the kernel never sees it.
    - *Harm:* the payer has paid and is never enrolled. The only trace is an audit event.
11. **The newest-N window on per-payer indices can be overflowed by dust.** For non-enrollment indices only `maxPages×pageSize` (default 4×25 = 100) signatures are read per account. `PageBound` is a *note*, not a refusal (`watch.rs:361-372`, `model.rs:35`), so the exit code stays 0.
    - *Scenario:* during an endpoint disagreement or watcher outage (a payment emitted but not yet receipted, or a refused one), an attacker sends more than 100 dust transfers to the payer's book address. The address is public once used. The unreceipted payment drops out of the window and is never re-read.
    - The README's premise, "a per-payer address receives a few transfers, all from its payer" (`README.md:23`), is an assumption about attackers, not a property of the chain.
12. **Unanimity is a liveness lever.** A single lagging or faulty endpoint that answers differently, or fails a call, refuses the whole index for that run (`watch.rs:478-491`). Persistent disagreement on one signature holds the enrollment cursor (`watch.rs:595-606`), and nothing escalates beyond events.
13. **A stuck pending tick stalls all PAY.** In durable mode, while `pending.json` exists, every run republishes the old tick without scanning (`main.rs:224-226`). If `mini pay observe` keeps exiting 4, or anything outside {0, 3}, no new payment is ever observed.
    - The README says never delete the pending record ("Errors can leave a durable pending record ... never delete it", `main.rs:15`), and there is no operator verb to quarantine it.
    - *Harm:* every payer waits indefinitely behind one undecidable record.
14. **A token account closed after receiving funds loses unprocessed credits.** Accounts are re-listed live each run (`watch.rs:268-279`). If the book's ATA receives a payment and is closed before the watcher processes it (by the book key holder, or after Token-2022 close authority changes), its signatures are never listed. This is operator-caused but undetected.
15. **Plain (non-durable) mode advances the cursor before Lean consumes the output.** `observations.json` can be overwritten by the next run before observe reads it. Only settled sigs pass the cursor, so emitted credits re-emit, and this is safe. The flaw is weaker: plain mode and durable mode have different audit semantics, and both remain supported (`main.rs:273-279`).
16. **Two memo-limit constants.** `MEMO_MAX = 566` in Rust (`memo.rs:22`) and in Lean (`Kernel/PayEnrolMemo.lean:419`, `Host/Json.lean:3596`) are not one exported value. A change on one side silently misclassifies: Rust emits `memoInvalid` for something Lean would accept, or the reverse.

### IS

17. **Controllers that share a uid can impersonate one another.** `execute` authenticates only `registration.uid == peer uid` for the self-declared `controller` field (`service.rs:306-317`). The README's example config gives `hermes-alice` and `hermes-bob` the same uid 991.
    - *Scenario:* Alice's resident sends `enqueue{controller:"hermes-bob"}`. Bob's principal (43) is charged virtual service and fills Bob's per-principal queue, so Bob is starved. Alice can also `cancel` or `finish` Bob's jobs if she learns the 64-hex id, and `inspect` reveals endpoints.
    - The README admits the shared trusted uid. The design is "operator pin", but the pin is not enforced.
18. **Single-threaded accept loop.** One client that connects and stalls holds the loop for the 2 s read timeout (`service.rs:488-495`). A loop of such connects from any registered uid, or from any uid, since uid is checked after the frame, starves every controller. Local only, but Hermes residents are semi-trusted.
19. **Cost is O(state) per request.** Every command clones `Core`, runs `schedule` twice, serializes the whole state JSON and fsyncs it (`service.rs:319,384-391`; `save_snapshot` at `:278`). With `max_jobs` up to 100,000 (`core.rs:176`) and state up to 128 MiB (`:88`), each enqueue or inspect becomes a multi-MB fsync. `inspect` also mutates and saves when expiries fire.
20. **Expiry runs only when a command arrives.** No timer exists. Placed leases past `expires_ms` hold capacity until some command runs `schedule`. Usually that is the waiting controller polling, so this is benign but implicit.
21. **`cancel` on a running job only sets `stop_requested`** (`core.rs:680-696`). Nothing acts on that flag, so capacity is released only by `finish` or operator `resolve`.
22. **`check` and `serve` disagree on the config owner.** `check` validates owner == euid (`main.rs:20`); `serve` requires owner == 0 (`main.rs:48`). A non-root `check` passes, then the service refuses to start.
23. **The README describes a unit file that is absent** (§2d). `mini-components --apply` integration is described but cannot be verified in this tree.

---

## 5. Unwired, undone, dead, twins

- **LS is the predecessor twin of SQ's `publish`/`read`.**
  - The same 14-byte fixture, the same "lost-response / exact retry / conflict" lifecycle, the same `PublishStatus{Installed, AlreadyPresent}` and `MAX_RECORD_BYTES` names. SQ even keeps `pub type SqliteLinkStore = SqliteByteStore` "for existing link clients" (`SQ/lib.rs:403-405`).
  - Not a trait crate: SQ does not depend on it.
  - It is an orphan with one live tendril, the fixture file SQ's tests include.
  - By ATLAS law 13 ("delete the twin") it should go. The Lean side `Assurance/HyperdocumentLinkLocalFileStore.lean` and `HyperdocumentLinkClientLocalFileCutover.lean` are imported by `Assurance/HyperdocumentLinkSqliteTransactionalStore.lean:17`, so that dependency must be handled first.
- **SQ dead or test-only verbs shipped in the production binary** (`main.rs:106-159,206-220,239-252`):
  - `cas-crash`, `publish-crash`, `publish-hold`, `durable-append-crash`, `journal-append-crash` call `std::process::exit` mid-transaction. `publish-hold` busy-waits on a filesystem path.
  - `serve` forwards them (`main.rs:303-306`). Any caller of the deployed coprocess can make it crash or hang a child at will.
  - `durable-anchor-enroll` has no caller outside the crate.
  - Legacy `publish`/`read` on `opaque_record` are live via `read-to` and `cas`. Once a store holds a durable seed, the record must be absent (`refuse_retired_image`, `lib.rs:713`), so one DB serves two incompatible roles.
- **PW's `CurlTransport::request` and `post_binary`** (`transport.rs:249-257`) exist only for resource-client (`pay_claim.rs:191,229,252`, `join_solana_v2.rs:191,213,1372`, `app_document.rs:97`).
  - PW is the de-facto general bounded-HTTP library of the workspace. Its doc names `native/grain-runtime/src/provider.rs` `forward` as the shape it copied (`transport.rs:4-6`), so a second spool-curl implementation exists in grain-runtime.
  - That is a twin; check the grain-runtime report for the other half.
- **PW `FixtureTransport`** is test-only but deployed, reachable by `PAY_RPC_FIXTURES` rehearsal (`deploy/pay/mini-pay-watcher:80-83`). This is intentional.
- **PW plain mode vs durable mode:** two output protocols. Only durable is deployed (`deploy/pay/mini-pay-watcher:77`), and plain remains for fixtures and journeys.
- **IS `Dispatched.stop_requested`** is written and never read except by status (§4.21).
- **IS Python journeys** (`native-two-member.py` 575 lines, `native-journey.py` 402 lines) need systemd user units, bwrap and sudo. They are not run by `cargo test`; they are qualification scripts.
- **No TODO, FIXME, `todo!` or `unimplemented!`** in any of the four crates (grep).

---

## 6. Size and shape

| Crate | src (lines) | tests | other | deps (normal) |
|---|---|---|---|---|
| SQ | lib 2,058 (565 unit tests), main 403, anchor 275, build.rs 62 | 596 | README 53 | `sha2 =0.10.9`, `libc =0.2.189`, system libsqlite3 |
| LS | lib 222, main 71, bench 314 | 106 | README 31, 14-byte fixture | none |
| PW | watch 617, decode 425, transport 405, model 303, main 296, config 189, memo 118, lib 27 = 2,380 | 1,340 | generate.py 707, ~63K lines of generated fixture JSON, README 114 | `bs58`, `libc`, `serde_json` |
| IS | core 855, service 739, lib 141, main 58 = 1,793 | 2,251 | 2 Python journeys 977, README 264 | `serde`+derive (syn 3), `serde_json`, `sha2`, `libc` (`cargo tree --offline`) |

**DEMO-MINIMAL cut.** Assumes a public Hetzner demo with ssh shell, web docuverse, SPK grains, Hermes residents, PAY and Discord.

- **SQ: needed in full.** The Host's durable receiver and fn archive both depend on it.
  - Removable today: the five crash/hold verbs plus their `crash_phase` and `needs_own_process` helpers, about 110 lines (`main.rs:47-57,106-159,206-220,239-252,301-306`), after moving them behind `#[cfg(test)]` or a test-only binary. The kn2 probes would need the same.
  - `durable-anchor-enroll` stays as a recovery tool but needs a wrapper.
- **LS: delete.** First move the 14-byte fixture into SQ (or emit it from `scripts/EmitHyperdocumentLinkRecoveryFixture.lean` into SQ's tree), retire the two scripts, and decide whether the Lean LocalFile assurance survives without its Rust companion. That removes 713 lines plus the 37 MB untracked `target/`.
- **PW: needed for PAY.**
  - Keep `watch`, `decode`, `memo`, `model`, `config`, the durable path in `main`, and `CurlTransport::call`.
  - Candidates: plain mode in `main.rs:273-295`, once journeys use durable mode. `request`/`post_binary` should move to a shared HTTP crate instead of being deleted.
  - The fixtures (about 63K lines) are tests and do not ship.
- **IS: not needed for the demo unless homelab inference is shown.** Hermes residents on API providers do not touch it; only `providerTask.homelab` does (`grain-runtime/src/main.rs:9326`).
  - grain-runtime depends on it at compile time (`grain-runtime/Cargo.toml:25`), so removing it needs a feature gate there.
  - For the demo, ship the binary unused or omit it from `package.py:65`.

---

## 7. Deployability on a small public Linux VM

**SQ**
- *Build:* a C toolchain (`cc`) plus `libsqlite3`. `build.rs` copes with a missing dev symlink and panics with a clear message if no `.so.0` exists (`build.rs:47-51`). Its fallback search covers only x86_64 and aarch64 Debian multiarch paths (`build.rs:38-43`).
- *Runtime:* `libsqlite3.so.0` (Debian: `libsqlite3-0`, usually present).
- *State:* `ROOT/forward-link.sqlite3` plus `-journal`, the sibling `ROOT.head-anchor` and `ROOT.head-anchor.lock` in ROOT's **parent**. The parent must be owned by the store uid or root and not group/other-writable (`anchor.rs:122-127`). A systemd `StateDirectory=` parent (`/var/lib/mini`, root 0755) satisfies that.
- *Backups* must include the anchor sidecar, or restore refuses.
- No ports, no secrets.
- `--anchor-identity` carries the deployment identity in argv, which is visible in `ps`. The identity is not a secret.

**LS:** not deployable (does not build in the tree); not packaged.

**PW**
- *Runtime:*
  - `/usr/bin/curl` at exactly that path (`transport.rs:179`). It is not installed by default on Debian minimal or cloud images, so `apt install curl` is needed.
  - The wrapper also needs `jq` and `flock` (`deploy/pay/mini-pay-watcher:57-58`); `flock` is in util-linux.
- *Systemd:* `deploy/pay/mini-pay-watcher.service` (oneshot, `User=mini`, `ProtectSystem=strict`, `ReadWritePaths=/var/lib/mini`, `MemoryMax=512M`) and `.timer` (60 s). The unit is well hardened.
- *Secrets:* `/etc/mini/pay/rpc.env` holds provider URLs with credentials. They are never placed in argv; they go to curl on stdin (`transport.rs:326-330`).
- *State:* `/var/lib/mini/pay/{watcher.json, tick/pending.json, tick/ticks/*.json, enrol-cursor.json}`. The tick archive grows forever ("Nothing deletes them", README:93); at 60 s ticks that is ~525K files per year.
- *Network:* egress HTTPS to at least two RPC endpoints (`minEndpoints` default 2). Public mainnet RPC prunes history and rate-limits, so `PrunedTransaction` and `Transport` refusals will be common unless paid RPCs are configured.

**IS**
- Linux only. Runs as a service uid; the config `/etc/mini/inference.json` must be root-owned (`main.rs:48`); the state dir is 0700 owned by the euid; the socket's parent dir is 0700 (`service.rs:468`).
- No network ports. The backends are loopback http or https endpoints, never contacted by IS itself (it holds only metadata).
- *State:* `state.json` (≤128 MiB) plus `receipts/` (up to 1M files / 8 GiB by default, never deleted, README "Terminal retention").
- The unit file is missing (§2d). A fresh Debian box needs a hand-written systemd unit, and the drain-on-stop behaviour the README describes then has nothing implementing it.

---

## 8. Questions for the Lean side

1. **PAY floor and enroll index:** should `mini pay watch-config` read `enrolIndex` and `journalFloor` from the signed tariff (`Kernel/PayTariff.lean:88,144`) instead of from operator flags? If both remain, should Lean refuse an observer report whose watcher floor differs from the tariff?
2. **Settling below-floor transfers:** should PW still advance the enrollment cursor past them? Alternatively, could the kernel journal them, so that "permanent skip" is a Lean decision with a receipt?
3. **Credited amount:** should the kernel accept PW's `amount` (Σ post−pre over book-owned accounts) as is, or should Lean define the credited-amount rule as an exported spec that PW only evaluates?
4. **Per-payer window:** is the newest-100 window an accepted loss bound? If so, where is it stated as a premise: a PAY ledger entry, or the `PageBound` note becoming a refusal?
5. **Endpoint agreement:** unanimity versus `minEndpoints`. Which is the intended agreement rule, and should the observer command carry how many endpoints agreed?
6. **Memo limit:** can `MEMO_MAX = 566` become a single Lean-emitted constant that PW reads (`memo.rs:22` vs `Kernel/PayEnrolMemo.lean:419`)?
7. **Stuck pending tick:** what is the sanctioned operator action when an observer stays undecided (exit 4) indefinitely? The pending tick blocks every later payment.
8. **SQ exit codes:** should bound violations get a distinct exit code (not 4)? `DurableReceiverCore.lean:162` should not treat a malformed append as CAS contention.
9. **SQ anchor:** is the `MINIANC2` format and its refusal policy something Lean should own as a spec, given that it is a rollback-protection decision currently made only in Rust? And who calls `durable-anchor-enroll` after a restore?
10. **Mutable checkpoints:** does Lean's checkpoint MAC verification make a replaced `durable_checkpoint` row harmless in every read path, `durable-checkpoint-at` included?
11. **IS policy ownership:** should the scheduling policy (ordering, per-principal caps, and above all the controller→principal binding) be a Lean export? Or is IS formally outside the "decides nothing semantic" law as a physical-capacity broker? If outside, which ATLAS clause covers it?
12. **IS principal binding:** should the principal sent to IS be bound by Lean (a signed provider-task field), rather than matched by string in grain-runtime (`main.rs:9329-9334`) and by name in IS config?
13. **LS retirement:** can `Assurance/HyperdocumentLinkLocalFileStore.lean` and `...ClientLocalFileCutover.lean` be retired with LS, or does `HyperdocumentLinkSqliteTransactionalStore.lean:17` need them as a model?
