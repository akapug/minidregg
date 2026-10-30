# private-backend, shard A: entry, wire, custody, stores, outputs, worker

| Field | Value |
| --- | --- |
| Shard | private-backend A ("entry, wire, custody, stores, outputs, worker") |
| Crate | `native/private-backend` (package `mini-private-backend` 0.1.0, lib + bin `mini-private-backend`; own `[workspace]` and `Cargo.lock`; not a root workspace member) |
| Date | 2026-10-26 |
| Reader | Opus reader, fan-out review (read-only; nothing built or run) |
| Files covered | 24 crate files (11,195 lines) + 3 `#[path]`-included shared root files (1,096 lines) = **12,291 lines** read in full; plus `Cargo.toml`, `Cargo.lock` (skimmed), `CONSTRUCTION.txt` (406 lines, read in full), `.config/nextest.toml`, `fixtures/` (listed; JSON profile read), and 10 Lean files (1,255 lines) on the claimed Lean side |

Files and line counts (test lines = `#[cfg(test)]` regions, counted by brace matching; `transcript.rs` and `private_view.rs` are test-only modules, `lib.rs:14-17`):

| File | Lines | Test | Code |
| --- | ---: | ---: | ---: |
| `src/lib.rs` | 65 | 4 | 61 |
| `src/main.rs` | 71 | 0 | 71 |
| `src/transcript.rs` | 48 | 48 | 0 |
| `src/private_initial.rs` | 73 | 0 | 73 |
| `src/entropy.rs` | 95 | 37 | 58 |
| `src/codec.rs` | 380 | 28 | 352 |
| `src/consensus_wire.rs` | 288 | 30 | 258 |
| `src/transition_journal.rs` | 331 | 164 | 167 |
| `src/protocol_store.rs` | 341 | 60 | 281 |
| `src/allocation_receipt.rs` | 404 | 178 | 226 |
| `src/custody.rs` | 528 | 131 | 397 |
| `src/source_endpoint.rs` | 589 | 211 | 378 |
| `src/recipient_seal.rs` | 590 | 0 | 590 |
| `src/authenticated_ingress.rs` | 1,031 | 456 | 575 |
| `src/sealed_outbox.rs` | 1,269 | 611 | 658 |
| `src/private_send.rs` | 478 | 173 | 305 |
| `src/private_send_store.rs` | 297 | 55 | 242 |
| `src/private_view.rs` | 405 | 405 | 0 |
| `src/private_output.rs` | 483 | 0 | 483 |
| `src/private_output_store.rs` | 909 | 725 | 184 |
| `src/native_worker.rs` | 681 | 155 | 526 |
| `src/asks.rs` | 698 | 211 | 487 |
| `src/arithmetic_reference.rs` | 512 | 477 | 35 |
| `src/circuit_batch.rs` | 629 | 349 | 280 |
| **crate subtotal** | **11,195** | **4,508** | **6,687** |
| `native/hybrid_kem.rs` (shared, `lib.rs:41`) | 471 | 95 | 376 |
| `native/crypto_transit.rs` (shared, `lib.rs:43`) | 380 | 178 | 202 |
| `native/pinned_execution.rs` (shared, `lib.rs:64`) | 245 | 72 | 173 |
| **total** | **12,291** | **4,853** | **7,438** |

Not in this shard but in the crate and missing from the lead's shard-B list: `src/vaba/byz.rs` (2,268) and `src/vaba/byz_targeted.rs` (273), the seeded Byzantine harnesses that `CONSTRUCTION.txt:111-147` cites. The crate is therefore about 24.7K lines with them, not 22.1K.

## Executive summary

1. The binary (`src/main.rs`) has seven arms. Five are test harnesses (`check-wire-fixtures`, `provision-test`, `reserve`, `recover`, `journal-empty`), one is a Unix-socket "anchor" service (`anchor`), and one is a Linux-only recipient worker (`worker`). No systemd unit, journey script, deploy file, `resource-client` module or Host operation refers to any of them. The only callers are two orphan scripts at the repository root (`crash-probes.py`, `check-boundary.sh`, the second with hard-coded hbox paths).
2. The crate sends and receives **zero Host protocol operations**. The "native205" and "network203" routes that `CONSTRUCTION.txt` and the doc comments name do not exist: codes 203-205 are unallocated in `protocol/host-operations.json`.
3. The Lean names the worker depends on do not exist anywhere in the tree: `Host.JointBackendPartyInner` (`source_endpoint.rs:76`) and `Host.PrivatePartyReserveAuthor` (`CONSTRUCTION.txt:379`). So no Lean producer or verifier exists for the inner credential, the sealed capsule, the worker dispatch, the progress-v2 or the batch-reserve frames.
4. Four frame families do have Lean codecs: the custody journal, allocation receipt, reservation request and circuit Plan. The byte formats agree (base-255 Nat with a 255 terminator, length-prefixed bytes, the same domain strings). But every Lean decoder except the journal lives only in the opt-in `ResearchWip` root, no Host receiver calls any of them, and the agreement is checked by four hand-run fixture frames (`main.rs:20-41`), not by a gate.
5. There are two real Rust-vs-Lean mismatches on the party codec. Rust accepts request frames up to 262,144 bytes where Lean `decodeRequest` refuses above 262,078 (`source_endpoint.rs:11` vs `JointBackendPartyCodec.lean:155`). Rust has six protocol tags and the worker requires tag 5, while Lean `Party.bounded` admits only tags below 4 (`authenticated_ingress.rs:20-27` vs `JointBackendPartyCodec.lean:44`).
6. Rust makes one physical decision on its own: whether a one-use correlation row is spent. It does this in a Rust copy of `Kernel.PrivateSuccessorCustody.reserve` (`codec.rs:245-289`) held by a Rust Unix-socket anchor (`custody.rs:71-217`). The anchor has no peer authentication, never records Lean's `burn`, and stops accepting reservations forever once its journal reaches 16 MiB (`codec.rs:283`).
7. On the brief's question 4: `asks.rs` is ASKS, the asynchronous secret key sharing of ePrint 2024/677, not an order book. `allocation_receipt.rs` records one-use row reservations. **Neither computes balances, prices or allocations of value.** No tariff or balance logic appears anywhere in this shard.
8. On question 3: `authenticated_ingress` does no signature verification itself. Its only production `SourcePartyAuthority` (`native_worker.rs:268-281`) accepts whatever envelope an operator-pinned external image vouched for. That image has no Lean source, so the effective admission is "whatever binary the operator config hashes".
9. On question 5: the worker checks the pin on the legacy path (the only path the CLI uses) by hashing the open fd and then exec'ing `/proc/self/fd/N` (`native_worker.rs:300-325`). An in-place write between hash and exec runs different code. That path also lacks `--kill-after`, and it writes up to 16 MiB to the child's stdin before reading stdout, which can deadlock. The sealed memfd successor (`pinned_execution.rs`) fixes the race but is dead (nothing calls `receive_sealed`).
10. On question 6: stores fsync records and parent directories, and `snapshot()` uses temp-and-rename. But the three WAL formats disagree on torn tails. `transition_journal` truncates them. `protocol_store` and the anchor log refuse forever, so one power loss can permanently brick the anchor. `transition_journal` also silently truncates every record after a corrupted interior length field, which under bit rot can re-issue different protocol messages for the same steps (equivocation).
11. At rest, secrets are plaintext under mode 0600: pool rows (never erased after "one-use" release), recipient key seeds, shares, dealing polynomials and hiding nonces. Secret `Vec<u8>` copies are not zeroized (`crypto_transit.rs:72`, `recipient_seal.rs:485-504`, `entropy.rs:19-22`).
12. Production cannot provision the worker. Nothing outside tests generates recipient keys (`generate_epoch`) or writes a worker `Config`. The output bootstrap the config pins is produced by a `#[test]` driven by environment variables (`private_output_store.rs:319-465`) with "deterministic reference preprocessing".
13. Dead or twin code inside the shard: `protocol_store.rs` (a second WAL format, no consumer), `allocation_receipt::reserve_material`/`verify_anchor_receipt` (test-only), all of `sealed_outbox.rs`, `source_endpoint::OutcomeClaim`, `SealedNative`/`receive_sealed`/`pinned_execution.rs`, the `Pool`/`reserve_release`/`circuit_batch::reserve_plan_release` raw-row material path (superseded by King-checked stocks in `field_network`), `Asks::dealer_start`, and a hand-written 2-bit adder (`arithmetic_reference.rs:5-30`) that duplicates a Lean-emitted fixture.
14. Across crates, `hybrid_kem.rs` and `crypto_transit.rs` are `#[path]`-shared with `resource-client`. `pinned_execution.rs` sits at `native/` root as if shared but has exactly one includer, while `resource-client/src/transport.rs:1368-1392` carries a near-verbatim twin of its memfd sealing. There is no other code or wire overlap with `resource-client`: `private.rs`, `pq_mailbox.rs` and `journey-private.sh` are unrelated.
15. For the Hetzner demo the whole crate is off the critical path: nothing on the box would run it, a stranger or a member can reach none of it, and dropping it removes about 11.4K lines (11,195 plus the single-consumer `pinned_execution.rs`). If it stays as research, about 3.3K lines are removable without touching the executed MPC path (section 6).

---

## 1. What this code is and does

### 1.0 Crate frame

- `Cargo.toml` pins exact versions (`sha2 =0.10.9`, `libc =0.2.189`, `aws-lc-rs =1.18.1` non-FIPS, `chacha20poly1305 =0.10.1`, `ring =0.17.14`, `sha3 =0.10.8`, `x25519-dalek =2.0.1` with `static_secrets,zeroize`, `zeroize =1.9.0`, `aws-lc-sys =0.45.0`). It ends with an empty `[workspace]`, which makes the crate its own workspace root. `Cargo.lock` has 61 packages, all pure-Rust crypto plus the AWS-LC C build (`cc`, `cmake`, `fs_extra`, `jobserver`) and Windows target shims. `aws-lc-sys` is pinned to the same 0.45.0 as the root workspace lock. That pin is load-bearing: `hybrid_kem.rs:241` links the versioned symbol `aws_lc_0_45_0_EVP_PKEY_keygen_deterministic` by name, so the two crates' locks must be bumped together or linking fails.
- Separate workspace, orphan or deliberate? **Deliberate.** `scripts/check-rust-tests.sh:83` runs each gate row as `cd native/$crate && cargo test --release --locked`, and four rows name this crate (`private-backend-recovery`, `private-backend-hybrid`, `private-transition-wal`, `private-king-store`; `check-rust-tests.sh:147-153,433-437,475-477,480-488`). `.config/nextest.toml` excludes the 5-minute "heavy" Objective-identity test from the default profile. The cost is a second lock to keep in step with the root one.
- `CONSTRUCTION.txt` (406 lines) is an appended run diary (r13 to r42, timestamps, manifest hashes) rather than a present-state document. It names Lean declarations and Host routes that do not exist (`Host.PrivatePartyReserveAuthor`, line 379; "native205", lines 191, 242, 309, 357). Its own limits section (lines 34-39) is the honest summary: variable-time GF(2^128), static f<n/3, classical ROM, honest crash disks, no simulator, no GOD.
- `fixtures/`: `addition-network-2-plan.bin` (139 B), `addition-network-8-plan.bin` (379 B), `objective-identity-{source,input,expected}.bin` (102/153/154 B), `objective-identity-network.bin` (265,118 B), `public-minimal-plan.bin` (142,645 B, used by `field_network_layers.rs`), and `objective-identity-profile.json` (documentation only; no code reads it). All are consumed by tests only (`private_output_store.rs`, `private_view.rs`, `field_network_layers.rs`).

### 1.1 `src/lib.rs` (65)

Module table. 37 `pub mod`s plus two `#[cfg(test)]` modules (`transcript`, `private_view`, `lib.rs:14-17`) and one private module (`private_initial`, `lib.rs:57`). Three modules are mounted from outside the crate by `#[path]`: `hybrid_kem` (`lib.rs:41-42`), `crypto_transit` (`lib.rs:43-44`) and `pinned_execution` (`lib.rs:64-65`). There is no prelude and no feature gating: every MPC protocol module is public library API, which is why rustc reports no unused-code warnings for the dead parts listed in section 5.

### 1.2 `src/main.rs` (71): what the binary runs (question 1)

`main` (`main.rs:7-16`) calls `run()`. On error it prints `private-backend: REFUSED <e>`, or for the `worker` arm the fixed string `private-backend: REFUSED native worker` (deliberately hiding the reason), and exits 1. `run()` (`main.rs:17-70`) dispatches on `argv[1]`:

| Arm | Lines | What it does | Production meaning |
| --- | --- | --- | --- |
| `check-wire-fixtures FILE` | 20-41 | Reads a 4-line text file of JSON byte arrays. Builds the same Generation/Correlation as `Compiler/PrivateBackendBoundaryFixture.lean:8-13` (invocation 2^255+42, command `signed.command`, attempt 3, generation 255, configuration 2^256-1, pool 2^255+12345, row 254, purpose HolderPad), and checks that the four frames (empty journal, request, one-allocation journal, allocation receipt with descriptor `[9,8,7]` and commitment `[6;32]`) are byte-equal to Rust's encoding and decode back. Prints `PRIVATE-BACKEND NATIVE/RUST WIRE PASS`. | Interop check. Its input is produced by `check-boundary.sh:15` on hbox (`lean --run Compiler/PrivateBackendBoundaryFixture.lean`). No gate runs it and no output is in the repo. |
| `worker CONFIG` | 42-48 | `native_worker::Config::load`, reads stdin (at most 16 MiB + 1), `DispatchClaim::decode`, `native_worker::receive` (legacy invocation), writes the pending receipt to stdout. | The only "service" logic. Unprovisionable (section 5). |
| `anchor ROOT SOCKET` | 49 | `custody::run_anchor`: a single-threaded Unix-socket server holding the one-use journal. | Test or research service. No unit or script except `crash-probes.py:13-21`. |
| `provision-test POOL COUNT` | 50-56 | Writes 1..10,000 rows of 32 random bytes from `/dev/urandom` as plaintext files plus a manifest. | Test harness. |
| `reserve POOL ROW SOCKET LOCAL OUTPUT CUT` | 57-66 | `custody::reserve_release` with a **hard-coded** Generation `{7,[9],0,1,2}` (`main.rs:61`; the comment says "Source receiving will supply these exact native bytes, not this test fixture"). Purpose is HolderPad. It parses a crash-injection CUT (`none`, `before-anchor`, `after-anchor`, `after-snapshot`, `after-secret-read`) and writes the released **secret** to a new 0600 file. | Test harness exposing secret release plus a crash hook in the shipped binary. |
| `recover SOCKET LOCAL` | 67 | `custody::recover_snapshot`; prints the tombstone count. | Test harness. |
| `journal-empty` | 68 | Prints the empty journal as hex. | Test harness. |

Reachability of the binary from the rest of the system (exact greps over `deploy/`, `native/resource-client/`, `scripts/`, `Host/`, `Kernel/`, `Compiler/`, `docs/evidence/`):

- `deploy/`: no match for `private-backend`, `mini-private-backend`, `native_worker` or `DREGG.PRIVATE.WORKER`.
- `native/resource-client/`: no match. `journey-private.sh` exists, but it is a 9-line `install_private` file-copy helper (`journey-private.sh:1-9`) that does not touch this crate. `src/private.rs` (1,440) is the private-room cell codec described by `docs/PRIVATE-CELL.md`; `src/pq_mailbox.rs` (2,074) is the mix cascade. Neither speaks any frame of this crate (greps for `DREGG.JOINT.PRIVATE`, `DREGG.PRIVATE.SEALED`, `DREGG.PRIVATE.AUTH\x01`, `WORKER.DISPATCH`, `DREGG.PRIVATE.INGRESS`, `DREGG.PRIVATE.CORRELATIONS` and `DREGG.PRIVATE.ALLOCATION` return only this crate).
- Root orphans: `crash-probes.py` (62 lines) drives `provision-test`, `anchor`, `reserve` with every CUT, `recover` and `journal-empty`, and writes `RESULTS.json` to a caller-supplied root. `check-boundary.sh` (16 lines) hard-codes `/home/hbox/workbox/codex-private-backend-20261003`, `/tank/dregg-build/...` and a Lean toolchain path. Both arrived in one commit (`2ebce376`). Neither is referenced by a gate.
- `docs/evidence/`: no evidence directory records a run of this binary. `docs/evidence/2026-10-02-private-object-components` matches the grep but concerns protected objects in `resource-client`. The run claims in `CONSTRUCTION.txt` (r13-r42) and `docs/MPC-PROFILE-P2.md` cite hbox lane logs that are not in the repository.

**Verdict:** the binary is a research harness. Nothing in the deployed system or the journeys reaches it.

### 1.3 `src/codec.rs` (380): the custody codec

Doc line 1 says "Canonical subset of Compiler.PrivateSuccessorCustodyCodec".

- `MAX = 16 MiB` (`codec.rs:6`) is the crate-wide frame bound. `bad()` builds an `InvalidData` error.
- `Nat(Vec<u8>)` (`codec.rs:11-51`): little-endian base-255 digits, terminated by the byte 255 on the wire (`put`, 40-43). `from_be` converts big-endian bytes, so 256-bit digests become Nats. `value()` is a checked fold into u64 that refuses anything wider ("physical Nat bound"). The empty digit list is zero, so `Nat::new(0)` encodes as `[255]`.
- `bytes()` (52-55) writes a Nat length followed by the raw bytes.
- `Reader` (56-109) is a cursor bounded by `MAX`. `nat()` scans to 255 and refuses a most-significant zero digit ("noncanonical Nat", 77-79). `count()` refuses values above `MAX`. `finish()` refuses trailing data.
- `Generation {invocation: Nat, command: Vec<u8>, attempt, generation, configuration: Nat}` (110-135) is the job identity used everywhere.
- `Correlation {pool: Nat, row: Nat}` (136-152) is a physical one-use row id.
- `Purpose` enum (153-168): Triple=0, Coin=1, HolderPad=2, AudiencePad=3; other codes are refused.
- `Allocation {id, generation, purpose, consumed}` and `Journal {spent: Vec<Correlation>, allocations: Vec<Allocation>}` (169-180).
- `Journal::encode` (182-197): `bytes("DREGG.PRIVATE.CORRELATIONS\x01")`, then a count and the spent ids, then a count and the allocations (id, generation, purpose Nat, consumed Nat 0/1).
- `Journal::decode` (198-234): strict and canonical (re-encode equality, 226). It additionally requires no duplicate spent ids, no duplicate allocation ids, and set(spent) == set(allocated ids) (224-231). That is a reachability condition Lean's decoder does not impose (section 2.2).
- `reserve` / `reserve_batch` (235-289): refuse an empty batch or one over 65,536. Refuse any id already spent or repeated in the batch (`AlreadyExists`, 254-262). Prepend the batch reversed to both lists, which makes the bytes equal to repeated single reserves in order. Refuse once the encoded journal would exceed 16 MiB ("journal exhausted: source retirement proof required", 283-285). The `shrink_to_fit` on line 287 does nothing semantically, despite the comment above it.
- `extends` (290-293) checks that the old spent set is a subset of the new one. `preserves_allocations` (294-303) checks that every old allocation is unchanged in the new journal.
- `request` / `parse_request` (305-319): an unframed `Correlation ‖ Generation ‖ Purpose` record.
- `batch_request` / `parse_batch_request` (349-380): raw prefix `DREGG.PRIVATE.RESERVE.BATCH\x01` (not length-prefixed, unlike the journal frame), then Generation, Purpose, count (1..65,536) and ids, with re-encode equality.
- Tests (320-347): Nat roundtrip at 0/1/254/255/256/u64::MAX, an empty-journal fixture written as literal bytes `[27,255,"DREGG...",255,255]`, and trailing-byte refusal.

### 1.4 `src/consensus_wire.rs` (288)

This is the strict transport encoding for the ACS/VABA/Gather layers (shard B's protocols), with sender identity taken from the authenticated channel (doc lines 1-2).

- `Cursor` (10-56) is a second bounded cursor alongside `codec::Reader`, with fixed-width reads (`byte`, little-endian `u16`/`u64`, `fixed32`, `take`). Its `bytes()` re-parses a Nat length by scanning to 255 and handing the slice to `Reader::count` (42-49).
- Phase messages Init/Echo/Ready are tags 0/1/2 followed by bytes (57-82). Sets go through `acs::set_bytes`/`acs::read_set` (83-88).
- Cover (Gather) messages (89-128): 32-byte context; tag 0 Gather{0 Inform(set) | 1 Ack | 2 Prepare(set)}, tag 1 Ra(u16, phase), tag 2 Withdraw.
- `encode_vaba`/`decode_vaba` (129-186): `DREGG.VABA.WIRE\x01 ‖ context32 ‖ view u64 ‖ tag`, where tag 0 is Asks(u16, bytes(ASKS wire)), 1 Pre(u16, phase), 2 Vote(u16, phase), 3 Cover, 4 Final(phase), with re-encode equality.
- `encode_acs`/`decode_acs` (187-221): `DREGG.ACS.WIRE\x01 ‖ context32 ‖ tag`, where 0 is Selector(u16, phase) and 1 is Vaba(bytes).
- `encode_outbox`/`decode_outbox` (222-258): a Nat count of at most MAX/48, then per packet `to:u16 ‖ bytes(ACS message)`, with the recipient checked against `n`.
- No Lean counterpart exists for these frames. They are internal to the MPC committee (section 2.2).

### 1.5 `src/transition_journal.rs` (331): the generic WAL

- `trait Machine: Clone { fn apply(&mut self, event) -> Result<Vec<u8>> }` (23-25) is a deterministic state machine whose output is the "outbox".
- `Journal<M>` (26-32) holds the file, current state, replayed outboxes, a `poisoned` flag and a lock file.
- `open` (40-136):
  - Takes an exclusive non-blocking `flock` on `path.with_extension("lock")` (44-53).
  - Creates the file if missing. The header is `DREGG.TRANSITION.WAL\x01 ‖ bytes(identity) ‖ SHA-256(header so far)` (60-62). It is written and the parent directory fsynced when the file is empty (63-67).
  - Reads the **whole file into memory** with no size bound (68-70).
  - Repairs a torn header that is a strict prefix of the expected one (71-78) and refuses any other header (79-81).
  - Then loops over records `len:u64le ‖ body ‖ SHA-256(body)` (85-127):
    - fewer than 8 bytes left: truncate and stop (87-91);
    - length over MAX: refuse (94-96);
    - record extends past EOF: truncate and stop (102-106);
    - checksum mismatch on the final record: truncate and stop (108-114);
    - checksum mismatch on an interior record: refuse;
    - the body is `bytes(event) ‖ bytes(expected outbox)`; the event is re-applied and the outbox must match ("transition outbox replay mismatch", 121-124).
- `append` (143-166): refuses if poisoned. Applies the event to a clone of the state; if `apply` fails nothing is written. Writes length, body and hash, then `sync_all`. On any I/O error sets `poisoned` and returns the error. Commits the state and outbox only after a successful fsync.
- Users: `authenticated_ingress::Receiver`, `recipient_seal::RecipientKeyCustody`, `sealed_outbox::Store`, `private_send_store::Store` and `private_output_store::Store` in this shard, plus `acs_store`, `acss_id_store`, `dzk_store`, `field_network_store`, `king_store` and `sh2t_id_store` in shard B.
- Tests (168-330): replay and incomplete-tail recovery; an invalid event leaves the file length unchanged; every-byte crash cut across one appended record; a zeroed final body and a flipped final checksum both truncate to the prior prefix; an interior checksum flip refuses; every-byte cut of the header recovers.

### 1.6 `src/protocol_store.rs` (341): a second WAL format

Durable event and outbox replay for one ASKS instance (`asks::Asks`).

- Lock file `root/protocol.lock` (133-142).
- File `root/transcript`: `len:u32le ‖ header`, where the header is `DREGG.ASKS.TRANSCRIPT\x02 ‖ Generation ‖ me ‖ dealer ‖ n u64 ‖ f u64` (143-162). Then records `len:u32le ‖ body ‖ SHA-256(body)` (178-212).
- Events (16-90): `Dealer(two coefficient polynomials)`, `Receive(sender, ASKS message)`, `Reconstruct`.
- `apply` (100-113) refuses a second Dealer event ("dealer cannot regenerate same instance").
- `dealer_start` (254-268) returns the retained outbox if the dealer has already started, and otherwise draws f+1 coefficients per polynomial from `/dev/urandom` and journals them.
- A total retained-byte bound of 16 MiB applies at open and at append (208-211, 233-235).
- Torn tail policy: **refuse** (any short read in the loop is an `UnexpectedEof` error at 183-191; the test `truncated_transcript_fails_closed`, 327-340, asserts it). That is the opposite of `transition_journal`.
- Consumers: **none**. Only `lib.rs:11` declares it; no other module or binary uses `protocol_store` (grep). It is a twin of `transition_journal` + `Machine`, which `private_send_store` and others use for the same job.

### 1.7 `src/private_initial.rs` (73)

`Initial` (14-73) is an immutable "original creation" file at `path.with_extension("initial")`, containing `domain ‖ bytes(initial) ‖ SHA-256` and locked by `path.with_extension("initial.lock")`.

- `create` (22-49) refuses if the WAL path already exists ("event WAL already exists; recover original"). It opens `.initial` with `create_new` and mode 0600, writes it, fsyncs file and parent, and reads it back.
- `load` (50-72) bounds the size to 16 MiB, verifies the checksum and domain, and parses the bytes.
- A torn `.initial` (crash before the fsync completes) makes both `create` (EEXIST) and `load` ("initial checksum" or "initial incomplete; source repair required") refuse permanently. There is no repair path.
- Users: `private_output_store::Store` (create/reopen) and `native_worker` (the pending-receipt key, `native_worker.rs:501-512`).

### 1.8 `src/custody.rs` (528): the one-use anchor and the plaintext pool

- `hash` = SHA-256 (13-15). `create()` is `create_new` with mode 0600 (16-22). `parent_sync()` fsyncs the parent directory (23-25). `nonce()` reads 8 urandom bytes (26-30).
- `snapshot(p, b)` (31-38) writes a temp file at `p.with_extension("pending-<pid>-<nonce>")`, fsyncs, renames over `p` and fsyncs the parent. Atomic replace.
- `read_packet`/`write_packet` (39-57): `len:u32le ‖ body` with body at most 16 MiB.
- `lock()` (58-70): exclusive non-blocking `flock`.
- `Anchor` (71-190), the "external monotonic anchor":
  - `open` creates `root` and **chmods it 0700 even if it already existed** (79-80). It takes `root/authority.lock` and opens `root/authority.log` for append.
  - It replays records of the form `len:u32le ‖ Journal bytes ‖ SHA-256`. **Each record is the entire journal after that step** (95-135), so the log grows quadratically in the number of reservation calls.
  - Each record must equal `previous.reserve_batch(prefix ids, one generation, one purpose)` with 1..65,536 new allocations, all unconsumed and sharing one generation and purpose (113-133). A batch containing a consumed allocation is refused (121-124). Lean's `burn` therefore can never be recorded.
  - A torn or short record is a hard error (`read_exact` fails, 97-111); the test `torn_anchor_refuses` (499-512) asserts it.
  - `reserve`/`reserve_batch` (143-172) append the whole next journal and fsync, and poison on I/O error.
  - `handle` (173-189) dispatches request byte 0 (read the journal), 1 (single reserve) and 2 (batch reserve).
- `run_anchor` (191-217):
  - binds a `UnixListener`, then chmods the socket 0600 (193-194);
  - serves connections **sequentially**, with 10 s read and write timeouts (195-198);
  - answers `0 ‖ journal` or `1 ‖ error text`;
  - ignores write errors (`let _ = write_packet`, 214);
  - does no peer-credential check of any kind.
- `rpc` (218-229) is the client: connect, send, receive, map tag 1 to `Error::other(text)`.
- `Pool` (230-319) is an "immutable" plaintext material pool:
  - `provision` creates `root` (0700), writes `row-<i>` files (0600, fsync) and a `manifest` = `DREGG.PRIVATE.IMMUTABLE.POOL\x01 ‖ n u64 ‖ SHA-256(row_i)...` (236-256);
  - the pool id is `Nat::from_be(SHA-256(manifest))` (274);
  - `row()` reads the file **with no size bound** and checks its hash (278-291); `row_fixed()` checks the exact length and refuses growth (292-305);
  - rows are **never deleted or overwritten after release**.
- `Cut` and `cut()` (320-332) are **crash injection in library code**: `std::process::exit(70)` when the selected cut matches.
- `reserve_release` (333-381):
  1. lock `local.with_extension("reservation.lock")`;
  2. read the journal from the anchor;
  3. preflight reserve locally;
  4. cut BeforeAnchor;
  5. send request 1;
  6. require the confirmed journal to extend the earlier one and contain the unconsumed allocation;
  7. cut AfterAnchor;
  8. snapshot locally and read it back;
  9. re-read the anchor and require it to extend the confirmed journal;
  10. cut AfterSnapshot;
  11. read the pool row;
  12. cut AfterSecretRead;
  13. return the secret.
- `recover_snapshot` (382-397): reads the anchor, refuses if a local journal exists that the anchor does not extend ("anchor behind local"), then snapshots and reads back.
- Tests (398-528):
  - a 9,418-row batch is one log record ("one complete append for the whole fixed Plan");
  - a refused batch leaves the journal untouched;
  - reopening restores the completed batch;
  - a flipped checksum is a hard refusal;
  - lost reply then relabel is refused;
  - torn anchor refuses;
  - row substitution and exhaustion are refused;
  - a second `Anchor::open` on the same root fails.

### 1.9 `src/allocation_receipt.rs` (404)

- `AllocationReceipt {request, descriptor_bytes, journal_bytes, row_commitment: [u8;32]}` (10-53). The frame is `bytes("DREGG.PRIVATE.ALLOCATION\x01") ‖ bytes(request) ‖ bytes(descriptor) ‖ bytes(journal) ‖ bytes(commitment)`. Decode checks that the request parses, the journal decodes, the commitment is 32 bytes, the descriptor is non-empty, and re-encoding is exact.
- `VerifiedAnchorReceipt` (54-61) has a private constructor. `PreparedMaterial` (62-74) moves out `(receipt, secret)`.
- `verify_anchor_receipt` (75-123):
  1. the request bytes equal the expected request;
  2. the descriptor bytes are exact;
  3. the row commitment equals the pool manifest hash;
  4. the captured journal contains the id and the exact allocation;
  5. `recover_snapshot` reads the live anchor, which must extend the captured journal and contain the allocation;
  6. the "original prefix" (the allocation and everything older) must be identical in captured and live journals.
- `reserve_material` (124-162) chains `reserve_release`, `recover_snapshot` and `verify_anchor_receipt`. The secret is returned only after the second readback; any failure drops it, so the row stays burnt.
- `SourceAllocationReceipt` (164-192): frame `DREGG.PRIVATE.ALLOCATION.SOURCE\x01`, then request, descriptor, commitment, the original-prefix SHA-256 and the prefix count as a Nat. `planned_byte_bound` (185-191) is an upper bound on the encoded size.
- `original_prefix` (193-211) assumes `spent` and `allocations` are aligned position by position (it slices both at the allocation's index).
- **Does it compute balances, prices or allocations?** No. "Allocation" here means "which physical one-use row went to which job identity and purpose". There is no amount, tariff or balance anywhere (question 4).
- Consumers: `main.rs:36-39` uses only `AllocationReceipt::{encode,decode}` for the fixture check. `reserve_material`, `verify_anchor_receipt` and `source_projection` are called only by this file's own test (264-403).

### 1.10 `src/circuit_batch.rs` (629)

- `Op {Constant(bool), Xor(u64,u64), And(u64,u64)}`, `Network {input_count, gates, outputs}`, and `Plan {generation, network, public_ticks, binding_bytes, rows: Vec<Correlation>}` (14-33).
- `assignments` (35-58) yields tick-major order over AND positions.
- `validate` (59-98) requires:
  - at most 65,536 gates, 65,536 inputs and 65,536 rows, and at most 4,096 ticks;
  - non-empty binding bytes;
  - forward operands only, and outputs in range;
  - rows = ticks × AND count;
  - no aliased rows.
- `encode`/`decode` (99-187): `bytes("DREGG.PRIVATE.CIRCUIT.ALLOCATION\x01") ‖ Generation ‖ input_count ‖ gate count ‖ (tag,a,c)* ‖ output count ‖ outputs ‖ ticks ‖ bytes(binding) ‖ row count ‖ rows`, re-encode exact. Decode also validates.
- `reserve_plan_release` (205-280):
  1. preflight the whole plan against the pool;
  2. one batch reservation (request 2) for every row;
  3. require the result to extend and preserve the prospective journal;
  4. snapshot and read back;
  5. re-read the anchor;
  6. only then read each pool row with `row_fixed`.
  A failure after the batch leaves every row burnt ("Partial prefixes remain spent", `CONSTRUCTION.txt:85-92`).
- Tests (281-629) include `actual_native_plan_fixture_byte_identity_and_schedule` (367-420), which embeds the bytes `Host.PrivateCircuitPlanFixture` printed (`Host/PrivateCircuitPlanFixture.lean:10-26`). That Lean file is in no lakefile root and imported by nothing; the bytes were captured once by hand.
- Consumers of `reserve_plan_release`: none outside this file's tests. The executed MPC path reserves through `field_network::Engine::reserve*` and `triple_king::burn_preparation` (`field_network.rs:433-447`) over King-checked stocks, not pool rows. `Plan`, `Network` and `Op` are the live types for those modules.

### 1.11 `src/entropy.rs` (95)

`Entropy {key: [u8;32], counter: u64}` (19-22).

- `os()` reads 32 urandom bytes; `from_seed()` takes a key.
- `fork(label)` = SHA-256(`DREGG.PRIVATE.ENTROPY.FORK.V1` ‖ key ‖ bytes(label)) (36-41).
- `bytes32()` = SHA-256(`...STREAM.V1` ‖ key ‖ counter LE), and the counter increments (42-48).
- `field()` takes the first 16 bytes of `bytes32()` as a GF(2^128) element (50-52).
- `test_root()` (`#[cfg(test)]`, 58-79) reads `MINI_PRIVATE_TEST_ENTROPY=<64 hex>` or the OS key, and **prints the key to stderr** so runs can be replayed.
- The key is not zeroized on drop. Production user: `private_output_store::Store::start` via `Entropy::os()` (`private_output_store.rs:154-156`).

### 1.12 `src/transcript.rs` (48, test-only)

`Wire` (an enum over ACSS, Sh2t, King, Layer and Output messages), `Frame {phase, sender, wire}`, and `Tap` (records frames addressed to one "curious" holder). It is the instrument behind `private_view.rs`.

### 1.13 `src/asks.rs` (698): ASKS, not "asks" (question 4)

Asynchronous secret key sharing (ePrint 2024/677 Algorithm 2) and Reliable Agreement (Algorithm 1), over a concrete Bracha reliable broadcast.

- `PhaseMessage` (Init/Echo/Ready); `Body` (Commit, PrivateShare(2 field words), Ra, Reconstruct).
- `Bracha` (39-123): each sender may echo or ready once; ready on n-f echoes or f+1 readies; output on n-f readies. `input_ra` lets a dealer-less RA instance echo `[1]`.
- `Asks::new` (147-172) requires n = 3f+1 ≤ 16. The instance id is SHA-256 of `DREGG.ASKS.V2`, the Generation, n, f and the dealer.
- `dealer_with_coefficients` (231-257) evaluates two degree-f polynomials at x = i+1. The commitment for holder i is h(i+1, words) with h = SHA-256(`DREGG.ASKS.H.V2` ‖ instance ‖ index ‖ words). It broadcasts the commitment vector by RBC and sends each private share.
- `receive` (259-308):
  - accepts private shares only from the dealer, and freezes them once accepted or once sharing has terminated (replacement after an RA echo cannot erase the retained share, as the test at 517-564 shows);
  - buffers Reconstruct messages.
- `progress` (309-376):
  - a commitment-matching share triggers RA input;
  - an RA output of `[1]` freezes `SharingOutput`;
  - in reconstruction, valid points (commitment-matching) beyond f are interpolated at x = 0 after a coherence check against all n commitments;
  - an incoherent dealer yields the fixed key `[0;32]` (the documented "malicious-dealer default").
- `dealer_start` (216-230) draws coefficients from urandom. **No caller outside tests** (`protocol_store::dealer_start` is a different function).
- Wire (577-670): `DREGG.ASKS.WIRE\x02 ‖ instance32 ‖ tag`, where tag 0/1 is Commit/Ra plus a phase tag and bytes, and tag 2/3 is PrivateShare/Reconstruct as Nat(2) and 2×16 bytes. The total is at most 4,096 bytes and re-encoding is exact.
- No balances, prices or bids exist here.

### 1.14 `src/private_send.rs` (478)

Recipient-private payload delivery adapted from ePrint 2024/1666 Appendix C (doc lines 1-6).

- `PrivateSend::new` (63-104) derives `context` = SHA-256(`DREGG.PRIVATE.SEND.V1` ‖ g ‖ dealer ‖ n ‖ f ‖ length). The inner ASKS runs under a Generation whose invocation is that context. A ciphertext Bracha has the dealer as broadcaster, and an n×n grid of request Brachas covers (receiver, requester) pairs.
- `dealer_with_coefficients` (128-143) masks the plaintext with `mask(context, ASKS key, ·)`, a SHA-256 counter-mode pad (294-305). It sends the ASKS dealing plus the ciphertext RBC Init to all parties.
- `request_delivery(receiver)` (146-160) starts the RBC for this requester's request on behalf of `receiver`.
- `receive` (161-221):
  - refuses public ASKS openings ("public key opening forbidden", 169-171);
  - requires the ciphertext to have the fixed length;
  - requires request payloads to be exactly `[1]`;
  - buffers `Transfer` shares addressed to this party (first one per sender kept, 216).
- `progress` (222-292): once the key sharing and ciphertext RBC have both output, a receiver is authorized when more than f request RBCs for it have output `[1]`. Authorized receivers get this party's local share by a private `Transfer`. The receiver reconstructs the ASKS key locally (it discards the generated public packets and refuses any side effect) and unmasks.
- Tests: the dealer disappears and only the requested recipient learns; f corrupt requests cannot reveal; cross-recipient transfer and stale context are refused; a corrupt dealer gives a receiver-independent fallback plaintext.

### 1.15 `src/private_send_store.rs` (297)

- Wire `DREGG.PRIVATE.SEND.WIRE\x01 ‖ context32 ‖ tag` (37-104): 0 is Key(bytes(ASKS)), 1 is Cipher(phase), 2 is Request(receiver u16, requester u16, phase), 3 is Transfer(receiver, Nat 2, 2×16 bytes). Re-encode exact.
- Outbox = count (at most MAX/50) of `to ‖ bytes(msg)` (105-146).
- `DeliveryMachine` (147-183) implements `Machine`. Event 0 is dealer(plaintext, 2(f+1) coefficients), 1 is request_delivery(u16), 2 is receive(sender, msg).
- `Store` (184-242) is a `transition_journal` with identity `DREGG.PRIVATE.DELIVERY.PARTY.V1 ‖ g ‖ me ‖ dealer ‖ n ‖ f ‖ length`. `dealer()` draws coefficients from urandom inside the journalled event. `replay_outboxes` re-parses the retained outboxes.
- Tests: a dropped reply replays the identical ciphertext and key shares, and a second dealer call is refused.

### 1.16 `src/authenticated_ingress.rs` (1,031) (question 3)

This module is the "enrolled-party packet" layer for shuffled opaque transport.

- `Protocol` enum (19-27): Acs=0, PrivateSend=1, AcssId=2, Dzk=3, FieldNetwork=4, PrivateOutput=5.
- `Context {protocol, generation, authority_epoch: Nat, session, recipient: u16, recipient_role}` and `CommitteeParty {context, party: u16, subject, key_epoch: Nat, key_binding, credential_purpose}` (28-45).
- `CommitteeParty::encode` (47-63): `DREGG.PRIVATE.COMMITTEE.PARTY\x01 ‖ protocol u8 ‖ bytes(Generation) ‖ authority_epoch Nat ‖ bytes(session) ‖ party u16le ‖ recipient u16le ‖ bytes(role) ‖ bytes(subject) ‖ key_epoch Nat ‖ bytes(binding) ‖ bytes(purpose)`. Decode (64-117) re-encodes and requires non-empty session, role, subject, binding and purpose.
- `Envelope {party, sequence: u64, message, credential}` (133-183):
  - signing bytes = `DREGG.PRIVATE.AUTH.SIGN\x01 ‖ bytes(party) ‖ seq u64le ‖ bytes(message)`;
  - wire = `DREGG.PRIVATE.AUTH\x01 ‖ bytes(party) ‖ seq ‖ bytes(message) ‖ bytes(credential)`, at most 131,072 bytes, message and credential non-empty.
- `trait SourcePartyAuthority { verify_enrolled_packet(party, signing_bytes, credential) }` (184-196). The doc comment calls it "an integration seam, not an implemented source authority" and names `NativeHost.Opened` and `CredentialSignatureAdmission.verifyNative` as what an implementation must use.
- `verify_packet` (209-235) decodes, requires the exact expected context, party < n, recipient < n and 1 ≤ n ≤ 16, then calls the authority. The **only** check of the credential is the trait call.
- Carrier `DREGG.PRIVATE.INGRESS\x01 ‖ bytes(envelope)`, at most 131,100 bytes (`carrier`/`public_ingress_gate`, 236-262).
- `AuthenticatedMachine<M>` (263-315) wraps an inner machine with replay and quota rules:
  - the replay key is (party, sequence);
  - a repeat with identical signing bytes returns the old outbox; with different bytes it is "conflicting replay";
  - a per-party count of accepted ids is capped at `capacity_per_party`, and old ids are never pruned;
  - the inner event is `2 ‖ party u16 ‖ bytes(message)`.
- `ProgressClaim` (327-388): `DREGG.PRIVATE.PROTOCOL.PROGRESS\x01 ‖ bytes(signing) ‖ outbox SHA-256 ‖ outbox len u64`. Decode re-parses the signing bytes.
- `trait IngressMachine` (405-409) has impls for `AcsMachine`, `DeliveryMachine`, `AcssMachine` and `DzkMachine` (410-480), plus `OutputMachine` in `private_output_store.rs:96-111`. Each recomputes the expected protocol context from the Generation and checks that receiver, n and context match.
- `Receiver<M>` (482-575):
  - `open_bound` requires 1 ≤ n ≤ 16, recipient < n and 1 ≤ capacity ≤ 65,536, and validates the ingress context;
  - the WAL identity is `DREGG.PRIVATE.AUTH.RECEIVER\x02 ‖ protocol ‖ g ‖ epoch ‖ session ‖ recipient ‖ role ‖ n ‖ capacity [‖ ORIGINAL.BINDING ‖ bytes(binding)]`;
  - `receive` (545-571) re-verifies the **current** authority even for duplicates, returns `Replayed` with the retained outbox for an exact semantic duplicate, and otherwise appends the canonical packet.
- Tests use an HMAC fixture authority explicitly marked "must NOT install this fixture as a source authority" (584-635). They cover context, party, epoch, subject and message variants refusing; replay plus transition as one durable record; a freshly re-randomized credential for the same semantic packet replaying; quota isolation per party across restart; and a changed bootstrap binding refusing.

### 1.17 `src/recipient_seal.rs` (590) (question 3)

Recipient-only sealed AUTH capsules. The doc comment (lines 1-4) says "Decryption proves confidentiality/integrity binding, NOT native source authority".

- Frames:
  - `DREGG.PRIVATE.SEALED.INGRESS\x03` (v2 is refused by name, 15-17, 199-204);
  - algorithm 2 is the hybrid X25519+ML-KEM-768 suite and algorithm 1 is refused by name (18-20, 33-48);
  - sign domain `DREGG.PRIVATE.SEALED.SOURCE.SIGN\x03`;
  - pad domain `DREGG.PRIVATE.RECIPIENT.PAD\x02`;
  - `MAX_PLAINTEXT` 131,168 and `MAX_SEALED` 262,078.
- `RecipientSpec {algorithm, key_epoch, key_id, plaintext_bound}` (25-54). `key_id` = SHA-512(`...RECIPIENT.KEY.ID\x03` ‖ bytes(public)) (55-59).
- `opaque_message_marker` (63-73) = `DREGG.PRIVATE.OPAQUE.MESSAGE\x01 ‖ bytes(party) ‖ seq ‖ semantic64`.
- `DraftPublic` (77-138) is the pre-seal public projection, framed `DREGG.PRIVATE.SEALED.DRAFT\x01`.
- `semantic_commitment` (139-144) = SHA-512(`...SEMANTIC\x02` ‖ hiding nonce ‖ bytes(signing)).
- `SealedIngress` (145-310):
  - public binding = frame, party, seq, algorithm, epoch, key id, bound and semantic commitment;
  - wire = public binding ‖ hybrid ct (1,120) ‖ nonce 24 ‖ key/cipher commitment 32 ‖ bytes(ct) ‖ bytes(outer native credential);
  - the ciphertext length must equal the bound + 16.
- `open` (245-309):
  1. caller-supplied expected party, seq and spec must equal the capsule's;
  2. the retained public key must match `key_id`;
  3. `crypto_transit::validate_keypair` (the seed regenerates the public key);
  4. `crypto_transit::open` with AAD (epoch bytes, public binding);
  5. the plaintext is `PAD ‖ len u32 ‖ hiding nonce 32 ‖ AUTH envelope ‖ zero padding`, with nonzero padding refused;
  6. the inner envelope's party and seq must equal the capsule's and its semantic commitment must recompute.
  It returns `DecryptedEnvelope` (311-344), which has a private constructor and no Debug or Clone.
- `HidingDraft` (359-480) samples a 32-byte urandom hiding nonce at creation and seals with a caller-supplied inner credential.
- `KeyState` (482-505) is a `Machine` whose events are `epoch ‖ bytes(secret) ‖ bytes(public)`. It refuses epoch reuse and capacity overflow and validates the pair. The state is `BTreeMap<Nat,(secret,public)>`, derives `Clone`, and so copies every secret on each append.
- `RecipientKeyCustody` (506-590) is a `transition_journal` with identity `DREGG.PRIVATE.RECIPIENT.KEY.WAL\x02 ‖ bytes(endpoint id) ‖ capacity`.
  - `generate_epoch` (552-570) is idempotent per epoch, generates a hybrid pair and journals **the secret seed in plaintext**.
  - `open_capsule` (572-589) looks up the exact epoch, requires `key_id` to match, and calls `open`.

### 1.18 `src/sealed_outbox.rs` (1,269)

The endpoint-private durable draft and capsule store (sender side).

- `nullifier(party, seq)` = `...SEALED.NULLIFIER\x02 ‖ protocol ‖ g ‖ session ‖ party ‖ seq` (17-25).
- State machine `State {entries: BTreeMap<nullifier, Entry>, max_entries}`, with events (92-238):
  - 0 draft (party, seq, spec, public key, hiding nonce, message);
  - 1 seal (key, inner credential, capsule);
  - 2 outer credential;
  - 3 refinement (a new inner credential gives a new capsule, at most 8, `MAX_REFINEMENTS`, line 56);
  - 4 refined outer.
- `Store` (279-569) runs `prepare`, `seal`, `attach_outer`, `refine_inner`, `refined_capsule`, `attach_refined_outer` and `retained_capsule`. All are idempotent and return the original bytes on retry.
- `batch_for_outcome` (510-568) binds every retained capsule to the actual protocol outbox from an `authenticated_ingress::Outcome`, in order, with the recipient and context matching.
- `ProgressDigestClaim` (582-620): `DREGG.PRIVATE.PROTOCOL.PROGRESS\x02 ‖ semantic64 ‖ SHA-512(sealed outbox) ‖ bytes u64 ‖ count u64`. `ActualProgress::new` (621-653) builds it.
- The WAL holds message plaintext and hiding nonces (events 0 and 3).
- Consumers: **none outside this file's tests**. `native_worker` does not use it.

### 1.19 `src/source_endpoint.rs` (589)

The "Exact native JointBackendPartyCodec REQUEST/OUTCOME adapter".

- `RequestClaim {candidate_bytes, participant: Nat, full_generation_bytes, manifest_root: Nat, raw_carrier}` (19-75): frame `DREGG.JOINT.PRIVATE.REQUEST\x01`, at most `MAX_REQUEST` = 262,144 (11). `protocol_binding` (60-74) gates the carrier through `public_ingress_gate` and requires the inner Generation to equal the full-generation bytes.
- `InnerCredentialRequest` (76-141): frame `DREGG.JOINT.PRIVATE.INNER.REQUEST\x01`, at most 16 MiB (`MAX_LOCAL_INNER`). `from_opened` (118-140) requires the original carrier to equal the opened capsule's exact bytes and the generation bytes to match. The doc comment says "Exact Host.JointBackendPartyInner request", but **no such Lean declaration exists**.
- `InnerCredentialOutcome` (142-254): frame `...INNER.OUTCOME\x01`; tag 0 is Refused(bytes), tag 1 is CredentialCheckedClaim{source index, party bytes, seq, semantic64, enrollment bytes, source receipt bytes}. `matches_opened` (226-253) checks equality with the opened envelope plus **non-emptiness** of the enrollment and receipt bytes.
- `OutcomeClaim` (255-368): frame `DREGG.JOINT.PRIVATE.OUTCOME\x01`; tag 0 Refused(Nat), 1 Unknown, 2 Progress(5 byte strings); at most 262,070. `matches_request` (337-367) compares the progress signing bytes.
- `admit_complete_transport_frame` (371-378) checks request ≤ 262,078 and reply ≤ 262,070.
- Production consumers: `native_worker` uses `RequestClaim::decode` and `InnerCredential{Request,Outcome}`. `OutcomeClaim`, `ProgressOutcomeClaim`, `matches_request` and `admit_complete_transport_frame` are test-only.

### 1.20 `src/native_worker.rs` (681) (questions 3 and 5)

The "Closed recipient-local Protocol5 worker".

- `DispatchClaim` (24-70): frame `DREGG.PRIVATE.WORKER.DISPATCH\x01 ‖ bytes(request) ‖ source index Nat ‖ bytes(enrollment) ‖ bytes(source record) ‖ bytes(source receipt) ‖ bytes(certificate) ‖ bytes(worker profile)`. This is the stdin input.
- `Config` (71-265): frame `DREGG.PRIVATE.WORKER.CONFIG\x01` with local party, n, capacity per party, key identity, key capacity, key WAL path, output initial base path, output context, output recipient, bootstrap SHA-256, receiver WAL path, anchor socket path, native program path, native image SHA-256, argv (at most 32) and worker profile.
  - `load` (183-264) requires a regular file, mode `& 0o077 == 0` and size at most 16 MiB (no owner check). It also requires protocol PrivateOutput, party == context.recipient, n ≤ 16, capacity bounds, non-empty profile and key identity, and absolute paths.
  - `validate_paths` (141-182) canonicalizes parents. It refuses role-name collisions across the 12 derived role paths (WAL, `.lock`, `.initial`, `.initial.lock` per store, plus the anchor and program), symlinks and hard-link inode aliases.
- `NativeAuthority` (266-281) is the only production `SourcePartyAuthority`. It accepts exactly the envelope it was built from (party, signing bytes and credential equal).
- `invoke_native` (282-345), the legacy pin:
  1. refuses on non-Linux;
  2. opens the program, hashes the fd and compares with the pin;
  3. clears `FD_CLOEXEC`;
  4. spawns `/usr/bin/timeout 45s /proc/self/fd/N argv...`;
  5. writes the encoded `InnerCredentialRequest` to stdin;
  6. reads stdout up to 16 MiB + 1;
  7. requires success and decodes `InnerCredentialOutcome`.
- `SealedNative` (346-384) is the successor path. It uses `pinned_execution::SealedInvocation`, replaces argv[0] with the held settings fd, and rechecks that the config bytes are unchanged.
- `NativeInvocation` (385-394) selects legacy or sealed. `receive_sealed` (398-400) uses sealed; `receive` (404-406) uses legacy.
- `receive_with_invocation` (407-525):
  1. the dispatch worker profile must equal the config's, and enrollment, record and receipt must be non-empty;
  2. validate paths;
  3. decode `RequestClaim`, then `SealedIngress` from its carrier;
  4. the capsule context must equal the config's local party context and the sender must be < n;
  5. open the key custody;
  6. `open_capsule(&capsule, &capsule.party, capsule.sequence, &capsule.recipient)`. The expected values are **the capsule's own fields** (see F6);
  7. build the `InnerCredentialRequest`;
  8. invoke the native image; `matches_opened` must hold, and the claim's enrollment and receipt bytes must equal the dispatch's;
  9. build `NativeAuthority` from the opened inner envelope;
  10. `private_output_store::Store::reopen` the frozen bootstrap;
  11. hash the bootstrap WAL file and compare with the pin;
  12. `Receiver::open_bound` on the receiver WAL with `OutputMachine{bootstrap state}` and original binding = `WORKER.ORIGINAL.BINDING ‖ bootstrap sha ‖ context ‖ bytes(profile)`;
  13. `receiver.receive`;
  14. load or create a 32-byte endpoint "pending key" (`Initial` at `receiver_wal.with_extension("pending-key")`, which after `with_extension("initial")` lands on `<stem>.initial`, a role `validate_paths` already lists);
  15. the response is `DREGG.PRIVATE.WORKER.PENDING\x01 ‖ semantic64 ‖ SHA-512(raw carrier) ‖ SHA-512(PENDING.OUTBOX ‖ key ‖ bytes(outbox))`.
- The worker never calls `request_delivery` and never exports the result (doc lines 4-6). It only feeds `PrivateOutput` protocol messages into the recipient's output machine.

### 1.21 `src/private_output.rs` (483)

Fixed-recipient reconstruction of completed shared Boolean outputs.

- `PrivateOutput::reserve` (83-171):
  1. preflights that the parent `LayerEngine` has completed output, no failure, recipient < n, a 1..65,536-byte descriptor and 1..4,092 outputs;
  2. computes `context` = SHA-256 of the binding (generation, parent context, recipient, descriptor, n, f, count);
  3. computes a **stable one-use id** that excludes the descriptor: pool = SHA-256(`...OUTPUT.ONE.USE\x01 ‖ parent context ‖ recipient`), row 0. A changed descriptor cannot reserve the same result for the same recipient again;
  4. reserves it at the anchor as HolderPad, snapshots a burn receipt, re-reads the anchor;
  5. only then reads the output shares.
- `initial` (172-221) creates n `PrivateSend` instances (one per dealer) with payload length 36 + 16·count.
- `start_with_coefficients` (263-281) sends this holder's shares (context ‖ me ‖ recipient ‖ shares) privately.
- `request_delivery` (282-296) is the "explicit SOURCE ENVIRONMENT request" and is not gated in code.
- `receive` (297-315) refuses cross-recipient requests and transfers.
- `progress` (316-354), at the recipient only:
  - rejects malformed dealer plaintexts (records the dealer in `rejected`) without erroring;
  - `acss_id::correct_polynomials` with n-f matching degree-f points;
  - a value above 1 sets `invalid_result`;
  - otherwise builds a `RecipientResult`.
- `initial_bytes`/`restore_initial` (355-458): frame `DREGG.PRIVATE.OUTPUT.INITIAL\x01`, holding the generation, context, parent context, holder, recipient, n, f, count, descriptor, burn journal and **local shares in clear**. Restore re-checks the anchor still retains the burn allocation, requires n = 3f+1 with f ≤ 5, and re-encodes exactly.
- Wire `DREGG.PRIVATE.OUTPUT.WIRE\x01 ‖ context32 ‖ dealer u16 ‖ bytes(private send wire)` (460-483).

### 1.22 `src/private_output_store.rs` (909; 184 code)

- `OutputMachine` (61-95): event 0 is start(2(f+1) coefficients), 1 is request_delivery, 2 is receive(sender, msg). It implements `IngressMachine` for protocol PrivateOutput (96-111).
- `Store::create` (122-129) runs `Initial::create(path, DOMAIN, initial_bytes)` and then `Journal::open` with identity `...OUTPUT.PARTY.WAL\x01 ‖ SHA-256(initial)`. `reopen` (130-146) is the restore path. `start` uses OS entropy.
- Test `source_generation_bootstrap_retains_real_output_wal_and_recursive_packet` (319-465) is **the production bootstrap producer**:
  - with `MINI_PRIVATE_SOURCE_GENERATION`, `MINI_PRIVATE_BOOTSTRAP_DEST` and `MINI_PRIVATE_SOURCE_DESCRIPTOR` set, it runs a complete reference MPC (255+1, width 8);
  - it writes `generation.bin`, `source-descriptor.bin`, a sample message and, per party, `output.wal`, `output.initial`, `output-context.bin`, `output-bootstrap-sha256.bin` and a copy of the anchor `authority.log`, plus `PROFILE.txt`;
  - `PROFILE.txt` says "No source authority, recipient enrollment, current release, Qualified successor, simulator, GOD/PQ claim".
- The other tests run the 429-stock Objective identity diagnostic (heavy, about 5 minutes), a 170-input parity, the width-8 adder, Nat2, pending/completed recovery and the malformed-corrupt-sender case.

### 1.23 `src/arithmetic_reference.rs` (512; 35 code)

- `two_bit_addition()` (5-30) is a **hand-written** Boolean network: 4 inputs, counted bit-qualification ANDs and a ripple-carry adder.
- The rest is `pub(crate) mod tests` (36-512): `InputParty` (dealing from party-local entropy), `equivocate` (a simulator witness), `share_inputs`, `completed_private_inputs*`, `completed_word_network*` and `completed_boolean_network_many`. Those are harness builders for shard-B engines, re-used by `private_output_store` and `private_view` tests.

### 1.24 `src/private_view.rs` (405, test-only)

The curious-holder secrecy check behind README "Honest state" (8,067 frames). It runs world A = (255,1), constructs worlds B = (1,255) and (128,128) by moving dealings and King extraction so holder 3's points and every opened value stay fixed, runs them through the actual protocol, and compares holder 3's transcripts frame by frame. Only two ROM-hidden classes may differ (other holders' PrivSend row ciphertexts and dZK column frames, 285-297). A falsifier shows the retired public-coefficient dealing is decodable (384-405). It is honest about scope: no simulator proof, no King view, no coalition (doc lines 26-29).

### 1.25 Shared root files (context only; another reader owns their report)

- `native/hybrid_kem.rs` (471): `HybridPublic`/`HybridSecret`, seeded ML-KEM-768 via the versioned AWS-LC symbol (239-297), transcript and cSHAKE256 combiner, encapsulate/decapsulate with low-order refusal. Secrets use `Zeroizing`.
- `native/crypto_transit.rs` (380): XChaCha20-Poly1305 plus an HMAC key/cipher commitment over the hybrid KEK.
  - `seal_raw_context`/`open_raw_context` (used by `resource-client/src/pq_mailbox.rs:71,88`);
  - `seal`/`open` with a recipient context (used only by this crate, `recipient_seal.rs:274,466`);
  - `generate_keypair` copies the `Zeroizing` secret into a plain `Vec<u8>` (`crypto_transit.rs:71-74`).
- `native/pinned_execution.rs` (245): memfd snapshot, then seal, then hash (22-55, 60-99). `output_with_input` spawns `/usr/bin/timeout --kill-after=2s Ns /proc/<pid>/fd/<image> /proc/<pid>/fd/<settings>` (103-172); the fds keep `MFD_CLOEXEC` and are reached through the parent's procfs.
- How this crate uses them: `recipient_seal` and `native_worker` (via `RecipientKeyCustody`) call `crypto_transit::{generate_keypair, validate_keypair, seal, open, HYBRID_CIPHERTEXT_BYTES}`. `native_worker::SealedNative` (dead) calls `pinned_execution::SealedInvocation`. Nothing in the crate calls `hybrid_kem` directly.
- The `#[path]` pattern is judged in section 5.4.

### 1.26 Data model and state machines (summary)

| Type | Defined | Role |
| --- | --- | --- |
| `Nat`, `Generation`, `Correlation`, `Purpose`, `Allocation`, `Journal` | `codec.rs:10-180` | Job identity and one-use journal (mirrors `Kernel.PrivateSuccessorCustody`) |
| `Anchor`, `Pool`, `Cut` | `custody.rs:71,230,320` | Physical monotonic journal, plaintext row store, crash hooks |
| `AllocationReceipt`, `VerifiedAnchorReceipt`, `SourceAllocationReceipt` | `allocation_receipt.rs:10,54,166` | Receipt claim, verified token, bounded source projection |
| `Plan`, `Network`, `Op`, `CompletedBatch` | `circuit_batch.rs:14-33,189` | Public circuit plus row manifest |
| `Journal<M: Machine>` | `transition_journal.rs:23-32` | Generic deterministic WAL |
| `Store` (ASKS) | `protocol_store.rs:114` | Second WAL format (dead) |
| `Initial` | `private_initial.rs:14` | Immutable creation file |
| `Asks`, `Bracha`, `SharingOutput` | `asks.rs:39,124,130` | ASKS plus RBC |
| `PrivateSend`, `DeliveryMachine` | `private_send.rs:40`, `private_send_store.rs:148` | Recipient-private delivery |
| `Protocol`, `Context`, `CommitteeParty`, `Envelope`, `Receiver`, `AuthenticatedMachine`, `ProgressClaim` | `authenticated_ingress.rs:19-388,482` | Enrolled-party packet layer, replay, quota |
| `RecipientSpec`, `SealedIngress`, `DecryptedEnvelope`, `HidingDraft`, `RecipientKeyCustody` | `recipient_seal.rs` | Recipient capsules and key custody |
| sealed `State`/`Entry`, `DraftReceipt`, `SealedBatchReceipt`, `ProgressDigestClaim` | `sealed_outbox.rs` | Sender draft/capsule store (dead) |
| `RequestClaim`, `InnerCredentialRequest`, `InnerCredentialOutcome`, `OutcomeClaim` | `source_endpoint.rs` | Joint request/outcome codecs |
| `DispatchClaim`, `Config`, `NativeAuthority`, `SealedNative` | `native_worker.rs` | Worker |
| `PrivateOutput`, `RecipientResult`, `OutputMachine` | `private_output.rs`, `private_output_store.rs` | Recipient-only output |

State machines (all deterministic, all replayed from WAL):

- **Anchor:** journal → reserve/reserve_batch → journal'. Allocations are never consumed and spent ids never leave. Terminal at 16 MiB.
- **Pool release:** BeforeAnchor → anchored → snapshotted → readback → secret. Any failure after anchoring leaves the row burnt.
- **ASKS:** commit RBC ∧ valid share → RA echo; RA output → sharing frozen; reconstruct → valid points > f → coherent key or `[0;32]`.
- **PrivateSend:** dispersed (key and cipher RBC done) → request RBCs > f → authorized → transfer → recipient reconstructs and unmasks.
- **AuthenticatedMachine:** (party, seq) unseen and under quota → inner apply; seen and same → replay; seen and different → refuse.
- **Sealed draft:** draft → sealed(inner) → final(outer); refinements up to 8, each with its own outer.
- **PrivateOutput:** reserved/burnt → started → requested → (recipient) result or invalid.
- **Worker:** dispatch → open capsule → native verify → bootstrap pin → receiver append → pending receipt.

### 1.27 Wire-format catalogue (every domain string the shard emits)

| Domain / frame | Producer | Lean decoder | Notes |
| --- | --- | --- | --- |
| `bytes("DREGG.PRIVATE.CORRELATIONS\x01")` journal | `codec.rs:182` | `Compiler.PrivateSuccessorCustodyCodec.framedJournalStream` (`:66-77`) | Bytes agree (2.2) |
| request (unframed Correlation‖Generation‖Purpose) | `codec.rs:305` | `Compiler.PrivateBackendBoundary.requestStream` (`:16-21`) | ResearchWip only |
| `DREGG.PRIVATE.RESERVE.BATCH\x01` (raw prefix) | `codec.rs:349` | none | |
| `bytes("DREGG.PRIVATE.ALLOCATION\x01")` | `allocation_receipt.rs:18` | `Compiler.PrivateAllocationReceipt.receiptStream` (`:17-25`) | ResearchWip only |
| `bytes("DREGG.PRIVATE.ALLOCATION.SOURCE\x01")` | `allocation_receipt.rs:175` | `...sourceReceiptStream` (`:92-104`) | ResearchWip only |
| `bytes("DREGG.PRIVATE.CIRCUIT.ALLOCATION\x01")` Plan | `circuit_batch.rs:99` | `Compiler.PrivateCircuitAllocation.framedPlanStream` (`:124-136`) | ResearchWip only |
| `DREGG.PRIVATE.IMMUTABLE.POOL\x01` manifest | `custody.rs:242` | none | Local file |
| anchor RPC `len u32 ‖ tag ‖ body` | `custody.rs:39-57,173-229` | none | Unix socket |
| `DREGG.TRANSITION.WAL\x01` header + records | `transition_journal.rs:60` | none | Local file |
| `DREGG.ASKS.TRANSCRIPT\x02` | `protocol_store.rs:143` | none | Dead |
| `DREGG.VABA.WIRE\x01`, `DREGG.ACS.WIRE\x01`, outbox | `consensus_wire.rs:129-258` | none | Committee-internal |
| `DREGG.ASKS.WIRE\x02` | `asks.rs:579` | none | Committee-internal |
| `DREGG.PRIVATE.SEND.WIRE\x01` | `private_send_store.rs:37` | none | Committee-internal |
| `DREGG.PRIVATE.COMMITTEE.PARTY\x01` | `authenticated_ingress.rs:47` | `Compiler.JointBackendPartyCodec.partyWire` (`:49-56`) | Encode-only function in Lean; ResearchWip only; protocol-tag mismatch |
| `DREGG.PRIVATE.AUTH\x01`, `...AUTH.SIGN\x01`, `...INGRESS\x01` | `authenticated_ingress.rs:141-262` | `JointBackendPartyCodec.decodeCarrier` (`:114-138`) | Bound 131,100 agrees |
| `DREGG.PRIVATE.PROTOCOL.PROGRESS\x01` | `authenticated_ingress.rs:339` | none | |
| `DREGG.PRIVATE.PROTOCOL.PROGRESS\x02` | `sealed_outbox.rs:595` | none | Dead |
| `DREGG.JOINT.PRIVATE.REQUEST\x01` | `source_endpoint.rs:9` | `JointBackendPartyCodec.decodeRequest` (`:152-157`) | **Bound mismatch** 262,144 vs 262,078 |
| `DREGG.JOINT.PRIVATE.OUTCOME\x01` | `source_endpoint.rs:10` | `JointBackendPartyCodec.decodeOutcome` (`:178-196`) | Tags and bound agree |
| `DREGG.JOINT.PRIVATE.INNER.REQUEST\x01` / `.INNER.OUTCOME\x01` | `source_endpoint.rs:87,159` | none ("Host.JointBackendPartyInner" does not exist) | |
| `DREGG.PRIVATE.SEALED.INGRESS\x03`, `.SEALED.DRAFT\x01`, `.SEALED.SOURCE.SIGN\x03`, `.SEALED.SEMANTIC\x02`, `.RECIPIENT.PAD\x02`, `.RECIPIENT.KEY.ID\x03`, `.OPAQUE.MESSAGE\x01` | `recipient_seal.rs` | none | |
| `DREGG.PRIVATE.SEALED.NULLIFIER\x02`, `.SEALED.OUTBOX.WAL\x02`, `.SEALED.OUTBOX.COMMIT\x02` | `sealed_outbox.rs` | none | Dead |
| `DREGG.PRIVATE.RECIPIENT.KEY.WAL\x02` | `recipient_seal.rs:536` | none | |
| `DREGG.PRIVATE.AUTH.RECEIVER\x02`, `.RECEIVER.ORIGINAL.BINDING\x01` | `authenticated_ingress.rs:515,526` | none | |
| `DREGG.PRIVATE.WORKER.DISPATCH\x01`, `.WORKER.CONFIG\x01`, `.WORKER.ORIGINAL.BINDING\x01`, `.WORKER.PENDING\x01`, `.WORKER.PENDING.OUTBOX\x01`, `.WORKER.PENDING.KEY\x01` | `native_worker.rs` | none | |
| `DREGG.PRIVATE.OUTPUT\x01`, `.OUTPUT.ONE.USE\x01`, `.OUTPUT.BURN\x01`, `.OUTPUT.INITIAL\x01`, `.OUTPUT.WIRE\x01`, `.OUTPUT.INIT.FILE\x01`, `.OUTPUT.PARTY.WAL\x01` | `private_output*.rs` | none | |
| `DREGG.PRIVATE.SEND.V1`, `.SEND.PAD.V1`, `DREGG.ASKS.V2`, `DREGG.ASKS.H.V2`, `DREGG.PRIVATE.ENTROPY.*.V1`, `DREGG.PRIVATE.DELIVERY.PARTY.V1` | various | none | Hash domains |

### 1.28 Processes, sockets, files, directories, environment

| Kind | What | Where |
| --- | --- | --- |
| Process | `mini-private-backend anchor ROOT SOCKET` (long-lived, single-threaded) | `main.rs:49`, `custody.rs:191` |
| Process | `mini-private-backend worker CONFIG` (one-shot per dispatch; stdin to stdout) | `main.rs:42-48` |
| Child process | `/usr/bin/timeout 45s /proc/self/fd/N ARGV...` (legacy) | `native_worker.rs:318-325` |
| Child process | `/usr/bin/timeout --kill-after=2s Ns /proc/PID/fd/IMG /proc/PID/fd/SETTINGS ARGV...` (sealed, dead) | `pinned_execution.rs:134-143` |
| Socket | Unix stream at operator path; bind then chmod 0600; no `SO_PEERCRED` | `custody.rs:193-194` |
| Directory | anchor root (forced to 0700): `authority.lock`, `authority.log` | `custody.rs:78-89` |
| Directory | pool root (0700): `row-<i>` (plaintext secrets, 0600), `manifest` | `custody.rs:236-256` |
| File | local snapshot plus `.reservation.lock`, `.pending-<pid>-<nonce>` temps (never cleaned after a crash) | `custody.rs:31-38,342` |
| Files | each transition WAL `P`, `P.lock` (the stem's `.lock`), and for output stores `P.initial`, `P.initial.lock` | `transition_journal.rs:44,54`, `private_initial.rs:18-23` |
| Files | ASKS `root/protocol.lock`, `root/transcript` | `protocol_store.rs:139,149` |
| File | output burn receipt `local` (snapshot) plus `.output.lock` | `private_output.rs:122,142` |
| File | worker config (mode must be `& 0o077 == 0`) | `native_worker.rs:183-188` |
| Device | `/dev/urandom` (entropy, nonces, coefficients, hiding nonce, keys) | `entropy.rs:27`, `custody.rs:28`, `protocol_store.rs:258`, `private_send_store.rs:220`, `recipient_seal.rs:379`, `native_worker.rs:506`, `asks.rs:221`, `hybrid_kem.rs:66`, `crypto_transit.rs:116` |
| procfs | `/proc/self/fd/N`, `/proc/<pid>/fd/N` | `native_worker.rs:320`, `pinned_execution.rs:133` |
| Env (tests only) | `MINI_PRIVATE_TEST_ENTROPY` | `entropy.rs:63` |
| Env (tests only, bootstrap export) | `MINI_PRIVATE_SOURCE_GENERATION`, `MINI_PRIVATE_BOOTSTRAP_DEST`, `MINI_PRIVATE_SOURCE_DESCRIPTOR` | `private_output_store.rs:323-325` |
| Exit codes | 1 = refused; **70 = injected crash cut** | `main.rs:14`, `custody.rs:330` |

---

## 2. What it assumes of its surroundings

### 2.1 Host protocol operations used

**None.** No file in the shard opens a Host socket, frames a Host request byte, or links `native/host-operations.rs`. `protocol/host-operations.json` allocates 186 operations; the codes around the ones the prose names are `[201, 202, 206, ..., 215]`. **203, 204 and 205 are unallocated**, and no operation's symbol or owner contains "private" or "joint" (checked with a JSON scan). The doc comments and `CONSTRUCTION.txt` speak of "native205", "network203", "source event63 Applied", "event60" and "Host.JointBackendPartyInner" as if they were Host routes:

- "native205" and "network203" are not Host operations;
- "event60" is a Kernel event kind used by `Kernel/JointReserveIngress.lean` (the "retained event60 reservation ingress", `:1-4`), which decodes the `PrivateSuccessorCustody.Descriptor` codec, not any frame this crate emits;
- `Host.JointBackendPartyInner` exists in no file except this crate's `source_endpoint.rs:76` and `CONSTRUCTION.txt`.

So the Rust-encoding-versus-Lean-decoding check the brief asks for has no Host arm to compare against. What exists is codec-level agreement with research Lean modules, covered next.

### 2.2 Lean cross-check, frame by frame (question 2)

Primitive codecs agree:

- Lean `StreamCodec.nat` (`Compiler/Tower256ConcreteBackend.lean:880-912`) is little-endian base-255 digits terminated by 255, refusing a zero most-significant digit (`if byte = 0 ∧ higher = 0 then none`). Rust `codec.rs:16-23,40-43,67-81` matches.
- `digestStream` is `nat` over `Digest.value` (`:1029-1031`), matching Rust storing digests as `Nat::from_be`.
- `bytesStream` is a Nat length followed by the bytes (`:1418-1420`), matching `codec.rs:52-55`.
- `framed` is the literal frame followed by the value (`:679-684`); `retract` accepts only canonical spellings (`:733-738`).

| Frame | Rust | Lean | Agreement | Checked how |
| --- | --- | --- | --- | --- |
| Journal | `codec.rs:182-234` | `PrivateSuccessorCustodyCodec.lean:12-77`: Generation = digest, bytes, nat, nat, digest; Allocation = correlation, generation, purpose, consumption; purpose and consumption by `retract`, so codes ≥4 and ≥2 are refused by canonicity | **Bytes agree.** Rust's decoder is stricter: it refuses duplicate ids and requires set(spent) = set(allocated) (`codec.rs:224-231`). Lean's `decodeJournal` accepts any canonical encoding; only `restoreJournal` (`:89-96`) checks allocations ⊆ spent. Every journal reachable through Lean `reserve`/`burn` (`Kernel/PrivateSuccessorCustody.lean:77-89`) satisfies Rust's extra rule, so the difference only bites on hand-crafted journals | `main.rs:20-41` against `PrivateBackendBoundaryFixture.lean:23-28` (hand-run; output not in repo); `codec.rs:333-339` literal |
| Reservation request | `codec.rs:305-319` | `PrivateBackendBoundary.lean:16-21` | Agree | Same fixture, frame 1 |
| Allocation receipt | `allocation_receipt.rs:18-53` | `PrivateAllocationReceipt.lean:17-25` (five bytesStreams, first = frame) | Agree. Rust additionally refuses an empty descriptor and a commitment that is not 32 bytes at decode; Lean puts the length in `ReceiptBinding.rowCommitmentLength` (`:34`) | Same fixture, frame 3 |
| Source allocation receipt | `allocation_receipt.rs:166-191` | `PrivateAllocationReceipt.lean:85-104` | Agree on layout | None (no fixture) |
| Circuit Plan | `circuit_batch.rs:99-187` | `PrivateCircuitAllocation.lean:87-136` (`opStream` retract: tags 0..3 with zero operands for constants, as in Rust `circuit_batch.rs:144-150`) | Agree on bytes. Rust `decode` also enforces `validate` (bounds of 65,536 gates/inputs/rows and 4,096 ticks, non-empty binding, forward operands, row count, no aliases); Lean `decode` is canonical-only and `Plan.valid` (`:38-40`) has no numeric bounds | `circuit_batch.rs:367-420` embeds bytes printed once by `Host/PrivateCircuitPlanFixture.lean`; that Lean file is in no lake root and imported by nothing |
| Committee party record | `authenticated_ingress.rs:47-117` | `JointBackendPartyCodec.lean:42-56` `partyWire` (encode-only function; no Lean decoder) | Layout agrees: protocol byte, bytes(Generation), nat epoch, bytes(session), u16le party then u16le recipient, bytes(role), bytes(subject), nat key epoch, bytes(binding), bytes(purpose). Differences: Lean's subject field is `bytes(subjectIdStream.encode subject)` where Rust's is opaque bytes; **Lean `Party.bounded` requires protocol < 4 (`:44`) where Rust defines tags 4 and 5 and the worker requires 5 (`native_worker.rs:229`)**; Rust requires non-empty session, subject and binding where Lean `bounded` checks only role and purpose | None |
| Auth envelope and ingress carrier | `authenticated_ingress.rs:141-262` | `JointBackendPartyCodec.lean:108-138` | Agree (frames; 8-byte sequence; carrier ≤131,100; trailing refused). Rust additionally decodes the party record and refuses an empty message or credential | None |
| Joint request | `source_endpoint.rs:19-75` | `JointBackendPartyCodec.lean:140-157` | Layout agrees (bytes, nat, bytes, digest, bytes). **Bound mismatch: Rust `MAX_REQUEST` = 262,144 (`source_endpoint.rs:11,41`); Lean refuses above 262,078 (`:155`).** Rust's `admit_complete_transport_frame` has 262,078 but is called only by tests | None |
| Joint outcome | `source_endpoint.rs:255-334` | `JointBackendPartyCodec.lean:159-196` | Agree: tags 0/1/2, refused = nat, unknown = two bytes, progress = five bytes, bound 262,070 | None |
| Inner request and outcome, sealed ingress, draft, progress v1/v2, worker dispatch and config, batch reserve, output frames | various | **none** | n/a | n/a |

Where the Lean decoders live:

- `Compiler.PrivateSuccessorCustodyCodec` is compiled into the Host build because `Kernel/JointReserveIngress.lean:8` imports it and `Kernel/NativeHostReplay.lean:69` imports that. But `encodeJournal`, `decodeJournal`, `restoreJournal` and `reserveEncoded` are called only from `Compiler/PrivateAllocationReceipt.lean:33` and `Compiler/PrivateBackendBoundaryFixture.lean:24-26` (grep).
- `Compiler.JointBackendPartyCodec`, `PrivateAllocationReceipt`, `PrivateBackendBoundary`, `PrivateCircuitAllocation` and `PrivateCircuitAllocationFast` are imported **only by `ResearchWip.lean:50,86-89`**, an opt-in lake root (`lakefile.toml:196`).
- `Compiler/PrivateWorldIR.lean` (named in the brief) has no relation to this crate's bytes: it lowers native world methods to `ObliviousEvaluator` with no codec.

**Conclusion for question 2:** nothing on the Lean side that the native Host runs parses any frame this crate produces. The research Lean codecs agree byte-for-byte on four frames, with the two party-codec mismatches above. The proof of agreement is four hand-run fixture frames plus one embedded Plan.

### 2.3 OS facilities

- **Unix-only throughout:** `std::os::unix` (`OpenOptionsExt`, `PermissionsExt`, `UnixListener`), `libc::flock` (`transition_journal.rs:51`, `custody.rs:66`, `protocol_store.rs:140`), and mode bits.
- **Linux-only for the worker:**
  - `/proc/self/fd` exec and `fcntl(F_SETFD)` (`native_worker.rs:313-320`); non-Linux refuses (`native_worker.rs:290-296`);
  - `memfd_create` with `MFD_ALLOW_SEALING` and the exec/noexec intent bits 0x10/0x08 with an EINVAL fallback, plus `F_ADD_SEALS` (`pinned_execution.rs:27-50`);
  - `/usr/bin/timeout` from GNU coreutils at that exact path (`native_worker.rs:318`, `pinned_execution.rs:134`). On a minimal image it must exist; on macOS the worker always refuses.
- No bwrap, seccomp, cgroups, systemd, `SO_PEERCRED`, setuid, SQLite or Cap'n Proto.
- Filesystem assumptions: honest crash-prefix semantics; `fsync` of files and directories is meaningful; `rename` is atomic (`custody.rs:31-38`).

### 2.4 Network services

None. No TCP, no HTTP, no Solana, no Discord, no LLM provider, no fn/NNTP. The only IPC is the anchor's Unix socket and the worker's stdin/stdout. The "authenticated confidential reliable party channels" that every protocol module assumes (`CONSTRUCTION.txt:35-36`, `asks.rs:2-5`) are **not implemented in this crate**; tests deliver messages in-process through queues.

### 2.5 File layouts and config

The operator must provide: an anchor root and socket path; pool directories (only the dead raw-row path needs them); one worker `Config` frame (binary, mode 0600) with absolute paths for the key WAL, output bootstrap base, receiver WAL, anchor socket and native program; the pinned native image; and the output bootstrap from the test exporter (`private_output_store.rs:403-463`). No tool in the repository writes a `Config` (`Config::encode` is called only in tests, `native_worker.rs:615`) or generates recipient keys (`generate_epoch` has no non-test caller).

### 2.6 Other crates

No path dependencies. Shared source by `#[path]`: `native/hybrid_kem.rs`, `native/crypto_transit.rs` (also mounted by `native/resource-client/src/main.rs:88-92`) and `native/pinned_execution.rs` (mounted only here). There are no binaries of other crates on its path, and no other crate depends on this one.

---

## 3. Does it decide anything semantic?

The law: "rust/ -- interpreter + node + FFI marshalling ONLY. Authors nothing. Every decision point is a Lean export or a Lean-emitted artifact" (ATLAS section 7). This crate is research MPC whose README row is "executed (research)". It decides a great deal, but almost all of it is cryptographic-protocol state among committee parties (Bracha thresholds, ASKS coherence, reconstruction quorums). Those are not kernel admissions and have no Lean owner. The table separates protocol-internal mechanics (legitimately Rust under the "sandboxes/hosted-service adapters" carve, or properly shard B's concern) from decisions that ATLAS assigns to Lean admission.

### 3.1 Decisions that a Lean admission should own (violations)

| # | path:line | What Rust decides | Lean counterpart | Blast radius if wrong |
| --- | --- | --- | --- | --- |
| D1 | `codec.rs:245-289`, `custody.rs:143-189` | **Whether a one-use correlation row is spent.** A Rust reimplementation of `reserve` (prepend to spent and allocations, refuse if spent) held by a Rust process. No Lean export is called; the Rust bytes are compared with Lean output only by a hand-run 4-frame fixture | `Kernel.PrivateSuccessorCustody.reserve` (`Kernel/PrivateSuccessorCustody.lean:77-82`) with `reserve_never_reassigns` (`:104-109`), and the codec `reserveEncoded` (`Compiler/PrivateSuccessorCustodyCodec.lean:118-123`) | A Rust bug that re-reserves a row re-issues a Beaver triple or pad. Reusing a multiplication triple across two openings reveals x−x' and y−y' to every holder: a privacy break. The proved Lean `reserve` covers nothing the binary runs |
| D2 | `custody.rs:121-124` | The anchor **refuses any record containing a consumed allocation**, so Lean's `burn` is unrepresentable on the physical side. Every `!a.consumed` check (`custody.rs:364`, `private_output.rs:134,446`, `field_network.rs:442`) is vacuous | `Kernel.PrivateSuccessorCustody.burn` (`:86-89`) and `burn_extends` (`:194-195`) | Low today. The two models diverge silently: a Lean-produced journal with a consumed entry would be refused by the Rust anchor's replay |
| D3 | `codec.rs:283-285` | **Lifetime cap of the whole private backend**: when the encoded journal would exceed 16 MiB, every reservation is refused "source retirement proof required". No retirement or pruning exists in Rust or Lean | none. "Retirement proof" is not a Lean declaration (grep) | Permanent halt of all reservations once about 16 MiB of history accumulates. The objective-identity diagnostic alone reserves 13,563 rows, each repeating the full Generation (command = the 102-byte source) |
| D4 | `authenticated_ingress.rs:284-313` | **Replay identity and quota for committee packets**: dedup by (party, sequence), a conflicting duplicate is refused, and accepted ids per party are capped at `capacity_per_party`, a number from the operator config (`native_worker.rs:75,234-235`). The doc comment calls it the party's "funded quota" (291) and says "Source funding must admit this full public bound" (486-489) | none. No Lean declaration funds or bounds backend ingress (`JointBackendPartyCodec.EndpointPin.dispatchCapacity`, `:91-106`, is a research codec field with no receiver) | A wrong capacity starves honest parties or lets a Byzantine party grow WAL state. "Funded" is a label: no funding check exists |
| D5 | `private_output.rs:113-121` | **Release policy: one release per (parent output context, recipient)**, deliberately excluding the descriptor so a changed descriptor cannot re-release | none (the CONSTRUCTION prose names "ReleaseAdmission" and "allAppliedReady", which exist in no Lean file) | A wrong identity re-releases an output to the same recipient under a new descriptor, or wrongly refuses |
| D6 | `private_output.rs:282-296` (`request_delivery`), `private_send.rs:146-160,229-237` | **Who is authorized to receive an output**: more than f request-RBC outputs naming the receiver. `request_delivery` itself is an ungated "environment" call | none ("fresh current source ReleaseAdmission", `private_output.rs:3-5`, is prose) | In production the worker never calls `request_delivery` (`native_worker.rs:4-6`), so this is unreachable. In tests it is called freely |
| D7 | `native_worker.rs:268-281,437-453` | **Packet admission (credential acceptance) is delegated to an operator-pinned external image** whose success is trusted when its claim matches the opened envelope and the dispatch's enrollment and receipt bytes (Rust checks only equality and non-emptiness, `source_endpoint.rs:241-247`). Rust itself verifies nothing cryptographic about the credential | Named but absent: "CredentialSignatureAdmission.verifyNative" (`authenticated_ingress.rs:185`). `verifyNative` exists for other receivers (e.g. `Kernel/PayClaimCommand.lean`) but not for this frame; "Host.JointBackendPartyInner" does not exist | The admission of private-output protocol messages equals whatever binary the operator config hashes. A config pointing at a script that echoes a CredentialCheckedClaim with the expected bytes would admit any decryptable capsule |
| D8 | `native_worker.rs:425-430` | **Which recipient key epoch and spec are acceptable** comes from the capsule itself (`&capsule.recipient`, `&capsule.party`, `capsule.sequence`), against the documented contract "Expected role/context/key are selected by the actual native source receipt and endpoint-owned key custody, never by trusting this claim" (`recipient_seal.rs:243-244`) | Should be the source enrollment's current recipient record (a research codec exists: `Compiler/CurrentRecipientRecord.lean`, not joined) | A sender may target any retained, rotated-away key epoch of this recipient. Rotation does not fence old keys for new traffic (F6) |
| D9 | `circuit_batch.rs:59-98`, `allocation_receipt.rs:185-191` | Public capacity bounds (65,536 gates/inputs/rows, 4,096 ticks; source-receipt byte envelope) decided only in Rust | Lean `Plan.valid` (`PrivateCircuitAllocation.lean:38-40`) has no numeric bounds; `fitsSourceEnvelope` (`PrivateAllocationReceipt.lean:129-130`) exists in research only | Low: shape limits, no value |
| D10 | `arithmetic_reference.rs:5-30` | A **hand-written circuit** (2-bit adder plus counted qualification) in a "derived path is the only path" repository | The Lean compiler emits the same program: `fixtures/addition-network-2-plan.bin` ("Actual Lean compiler Nat2 fixture", `CONSTRUCTION.txt:329-336`) | Test-only today (section 5). It is a twin of an emitted artifact |

### 3.2 Places that correctly defer or stay physical

- Recipient decryption is integrity and confidentiality only and grants no authority. The comments say so, and `DecryptedEnvelope` has no Debug or Clone (`recipient_seal.rs:311-318`).
- All `*Claim` decoders produce claims only: `allocation_receipt.rs:1-3`, `source_endpoint.rs:1-3,142-144`, `authenticated_ingress.rs:327-330`. None constructs `VerifiedPacket` or `VerifiedAnchorReceipt` publicly; both have private fields and constructors (`authenticated_ingress.rs:197-208`, `allocation_receipt.rs:54-61`).
- `Receiver::receive` re-validates current authority even for exact duplicates, so a cached accept cannot bypass revocation (`authenticated_ingress.rs:551-553`).
- The worker never initiates delivery or exports plaintext (`native_worker.rs:1-6`).
- The ASKS, Bracha, PrivateSend and reconstruction thresholds are protocol mechanics with paper references. They are not kernel semantics; shard B and the synthesis will judge them.
- **Balances, prices, tariffs, allocations of value:** none anywhere in the shard (question 4).

---

## 4. Flaws noticed

Severity is relative to this crate's purpose (research, unreachable from production). If any of it were deployed, F1-F8 are the ones that would matter.

**F1. A crash mid-append bricks the anchor permanently.**
- Where: `custody.rs:95-111` uses `read_exact` with no torn-tail repair; the test `torn_anchor_refuses` (`custody.rs:499-512`) asserts the refusal.
- Scenario: power loss after `write_all(len)` and part of the body, before `sync_all` returns (`custody.rs:160-165`). On restart `Anchor::open` fails with UnexpectedEof forever, and every `reserve_release`, `PrivateOutput::reserve` and `field_network` reservation (each calls `custody::rpc`) fails.
- The only repair is an operator truncating `authority.log`, which is exactly the rollback the anchor exists to prevent.
- Contrast `transition_journal.rs:85-115`, which repairs the same tear. The policies are inconsistent across one crate.

**F2. `transition_journal` silently truncates published history under non-crash corruption.**
- Where: `transition_journal.rs:102-105` truncates at the first record whose length points past EOF; `:108-114` truncates a final record with a bad checksum.
- Scenario A: a bit flip in an **interior** record's 8-byte length field makes `end > all.len()`. Every later record, including ones whose outboxes were already published, is truncated and fsynced away with no error.
- Scenario B: bit rot in the **last** record after it was published. The module's premise that such a record "was never published" (doc lines 4-7) is false.
- Either way the machine resumes at an earlier state. The next `append` for that step can emit different messages, for example a new `dealer` event with fresh `/dev/urandom` coefficients in `private_send_store.rs:216-223` or `Entropy::os()` in `private_output_store.rs:154-156`. That is dealer equivocation, which breaks the ASKS and PrivSend guarantees.
- The doc's "arbitrary disk corruption is not repaired" undersells it: the corruption is not refused either, it is converted into lost history.

**F3. Torn `.initial` and torn `protocol_store` headers brick their stores.**
- `private_initial.rs:39-44` writes in place (no temp and rename). A crash before `sync_all` leaves a short or garbled file. `create` then fails with EEXIST (`:34-38`) and `load` with "initial checksum" or "initial incomplete" (`:58-64`), forever.
- `protocol_store.rs:150-162`: if the process dies between creating `transcript` and writing its header, `existed` is true on the next open and `read_exact` fails (`:165-171`) permanently.

**F4. The legacy native pin has a time-of-check/time-of-use race (the only pin the CLI uses).**
- Where: `native_worker.rs:300-320`.
- The image is hashed through an open fd and then executed as `/proc/self/fd/N`. Same inode, but an in-place write between the hash loop and `execve` succeeds (ETXTBSY applies only once the file is executing), so the executed bytes can differ from the hashed bytes.
- The fix exists in `pinned_execution.rs:57-99` (copy, seal, then hash) and in `resource-client/src/transport.rs:1394-1409`, but `SealedNative` is never constructed outside tests (section 5).
- Also, `/usr/bin/timeout` itself and the dynamic loader are trusted and unpinned (`pinned_execution.rs:3` admits this).

**F5. The worker child can hang or deadlock.**
- No kill-after: the legacy path runs `timeout 45s` without `--kill-after` (`native_worker.rs:318-320`). A pinned image that ignores SIGTERM keeps the worker blocked in `read_to_end` forever. `pinned_execution.rs:135` has `--kill-after=2s`.
- Pipe deadlock: both paths write the whole request to the child's stdin before reading stdout (`native_worker.rs:326-338`, `pinned_execution.rs:146-157`). The request can be 16 MiB (`MAX_LOCAL_INNER`, `source_endpoint.rs:18`), far above a 64 KiB pipe buffer. A child that writes progress or output before draining stdin blocks on its stdout while the parent blocks on stdin. That ends in a 45 s timeout and a refusal (fail-closed, but a liveness bug for large certified histories, the very case `native_worker.rs:649-659` advertises).

**F6. The capsule selects its own recipient key epoch.**
- Where: `native_worker.rs:425-430` passes `&capsule.recipient` as `expected`. `RecipientKeyCustody::open_capsule` (`recipient_seal.rs:572-589`) only checks that the epoch exists in custody and that `key_id` matches the retained public key.
- Scenario: the recipient rotates from epoch 7 to 8 because epoch 7 may be exposed. A sender, or anyone holding epoch-7 material who also holds a valid inner credential, keeps sealing to epoch 7 and the worker keeps opening it. The native claim match (`source_endpoint.rs:241-247`) does not compare the spec or epoch either.
- The doc comment at `recipient_seal.rs:243-244` promises the opposite.

**F7. The anchor has no peer authentication and a socket-permission race.**
- `custody.rs:193-194` binds first and chmods second. Between the two, the socket has umask-derived permissions and any local user may connect.
- There is no `SO_PEERCRED` check, so any process with connect permission can request byte 1 or 2 reservations with an arbitrary Generation and Purpose for any pool id (`custody.rs:173-189`). The anchor does not know the pools.
- Effects:
  - burn arbitrary rows (stock denial of service);
  - inflate the journal toward the 16 MiB cliff (D3), bricking all future reservations;
  - read the whole journal (byte 0): every generation including command bytes.
- `run_anchor` serves one connection at a time with a 10 s read timeout (`custody.rs:195-198`). A client that connects and sends nothing stalls every other client for 10 s, repeatably.

**F8. Secrets at rest are plaintext, and "one-use" does not erase.**
- Pool rows stay on disk forever after release (`custody.rs:278-291`). There is no unlink, shred or overwrite, so the journal is the only thing making them "one-use". Anyone who can read the pool directory has every past and future correlation.
- Recipient key seeds are journalled in clear (`recipient_seal.rs:562-568`), and `KeyState` derives `Clone` (`recipient_seal.rs:485-489`), duplicating every seed on each `append` (`transition_journal.rs:147`).
- Shares, dealing coefficients and hiding nonces are in `.initial` and WAL files (`private_output.rs:370-372`, `private_send_store.rs:216-223`, `sealed_outbox.rs:327-334`).
- `docs/MPC-PROFILE-P2.md` ("What leaks") says the same.

**F9. Secret copies are not zeroized.**
- `crypto_transit::generate_keypair` copies `HybridSecret::to_bytes()` (a `Zeroizing<Vec<u8>>`) into a plain `Vec` with `.to_vec()` (`crypto_transit.rs:71-74`). `KeyPair.secret` is a `pub Vec<u8>` with no `Drop`.
- `Entropy.key` (`entropy.rs:19-22`), `PreparedMaterial.secret` (`allocation_receipt.rs:63-66`), the `reserve` CLI's secret buffer (`main.rs:63-65`), `PrivateOutput.local_shares` and `RecipientResult.bits` are all plain heap data.
- `hybrid_kem.rs` does use `Zeroizing` internally; the protection is lost at the `crypto_transit` boundary.

**F10. Crash injection and secret egress ship in the production binary and library.**
- `custody::Cut` and `cut()` call `std::process::exit(70)` from inside the `pub fn reserve_release` (`custody.rs:320-332,355-379`), selectable from argv (`main.rs:62`). Any library consumer passing a non-`None` cut kills its own process.
- The `reserve` arm uses a hard-coded test Generation (`main.rs:61`) and writes released secret bytes to a file (`main.rs:65`).

**F11. The worker mutates the frozen bootstrap before verifying its pin.**
- `native_worker.rs:463-470` calls `private_output_store::Store::reopen`, which runs `Journal::open` on `output_initial_base` and can truncate a torn tail or write a header (`transition_journal.rs:63-67,87-114`). The SHA-256 comparison against `output_bootstrap_sha256` happens afterwards (`native_worker.rs:471-481`).
- The result fails closed (the hash then mismatches), but a pinned artifact is modified by the check. The open also takes the bootstrap's exclusive lock for the whole call.

**F12. Unbounded whole-file reads at open.**
- `transition_journal.rs:68-70` reads the entire WAL into memory with no bound; with many records it is a memory spike per open, and the worker reopens three WALs per dispatch.
- `Anchor::open` replays all records (`custody.rs:95-135`), and each record is the whole journal. Replay is O(records × journal size) in time and peak memory per record is up to 16 MiB.
- `Pool::row` uses `fs::read` with no size bound (`custody.rs:286`).
- `main.rs:21` reads the fixture file fully before checking `MAX`.

**F13. The anchor log grows quadratically.**
- Every `reserve` call appends the **entire** journal (`custody.rs:158-164`).
- For N single reservations the log holds about N²/2 allocation records. At roughly 100 bytes per allocation plus command bytes, 10,000 single reservations need about 5 GB. Batching reduces the number of records but does not remove the quadratic shape.

**F14. Lost-reply semantics burn rather than retry.**
- In `reserve_release` (`custody.rs:356-367`) and `PrivateOutput::reserve` (`private_output.rs:125-138`), if the anchor appends and fsyncs but the reply is lost, the client errors. A retry of the same request gets `AlreadyExists` ("spent/aliased physical row", `codec.rs:257-260`), and the secret or output is never released.
- This is intentional and fail-closed (`crash-probes.py:24-31` exercises it), so a retry cannot become a second release. But the operation is not idempotent: there is no "the allocation that is already mine, return my receipt" path, although `verify_anchor_receipt` (`allocation_receipt.rs:75-123`) is exactly the shape that could serve it.
- Under the repository law ("a lost reply keeps the original operation and its exact retry rather than licensing a second one"), the burn half of the law holds and the exact-retry half does not.

**F15. Codec agreement mismatches with Lean** (section 2.2):
- `MAX_REQUEST` 262,144 vs 262,078 (`source_endpoint.rs:11` vs `JointBackendPartyCodec.lean:155`);
- protocol tags 4 and 5 vs `Party.bounded` protocol < 4 (`authenticated_ingress.rs:24-26` vs `JointBackendPartyCodec.lean:44`);
- empty-field rules (`authenticated_ingress.rs:107-113` vs `JointBackendPartyCodec.lean:43-45`);
- the Rust journal's extra set equality (`codec.rs:224-231`).
- `original_prefix` (`allocation_receipt.rs:193-211`) slices `spent` at the index found in `allocations`, assuming they are aligned. `Journal::decode` checks set equality but not order, so a crafted journal can decode with misaligned lists, and the prefix digest then mixes ids from different positions.

**F16. Two allocation-receipt paths verify differently.**
- `allocation_receipt::verify_anchor_receipt` re-reads the live anchor through `recover_snapshot`, which overwrites the local snapshot (`custody.rs:392`).
- `PrivateOutput::restore_initial` (`private_output.rs:435-449`) and `field_network` read the anchor directly.
- Same intent, three implementations. Not a bug in itself, but the "receipt" concept has no single verifier.

**F17. Error swallowing is limited and intended.**
- `run_anchor` ignores reply write errors (`custody.rs:214`).
- `main.rs:9-11` hides the worker's refusal reason, deliberately so private details do not leak. The cost is that operators debugging a worker see only "REFUSED native worker".

**F18. Panics on untrusted input: none found in production paths.**
- Every `try_into().unwrap()` follows a fixed-length `take` (`consensus_wire.rs:34-41`, `recipient_seal.rs:114,215-218`, `source_endpoint.rs:211`).
- Slice indexing is guarded: `protocol_store.rs:80-81` requires `b.len() >= 3`; `transition_journal.rs:87-92` checks the remaining length before slicing 8 bytes; `recipient_seal.rs:281-286` checks `plaintext_bound >= PAD.len() + 37` through `validate`.
- Other unwraps are logically guarded: `private_send.rs:240,286` (`dispersed`), `asks.rs:385` (sharing checked), `private_output.rs:150` (checked at 94).
- Tests use `unwrap` freely, which is fine.

**F19. Single-instance locks with no queueing.**
- Every store takes `LOCK_NB` and errors with EWOULDBLOCK if another instance holds it (`transition_journal.rs:51-53`, `custody.rs:66-68`).
- Two concurrent `worker` dispatches for the same recipient: the second refuses outright (key WAL, bootstrap and receiver locks). The source would have to serialize dispatches. Fail-closed, but undocumented at the CLI.

**F20. Config custody checks are partial.**
- `Config::load` checks mode bits but not the owner uid (`native_worker.rs:184-188`). A 0600 file owned by another user passes if readable, so in practice it requires root or the same uid.
- `validate_paths` runs before the opens, and the opens do not use `O_NOFOLLOW`, so a parent-directory writer could swap a role path for a symlink in the window. That attacker can already write the directory.

---

## 5. Unwired / undone

### 5.1 Reachability from `fn main` (this shard)

| Module | Reached by CLI arm | Reached by journey, unit, deploy | Verdict |
| --- | --- | --- | --- |
| `codec` | all arms | none | Live in the binary |
| `custody` | `anchor`, `provision-test`, `reserve`, `recover` (Pool path); `worker` (via `private_output::restore_initial` → `rpc`) | `crash-probes.py` (root orphan) | Binary-live; `Pool`/`reserve_release`/`Cut` are harness-only |
| `allocation_receipt` | `check-wire-fixtures` (`AllocationReceipt::{encode,decode}` only) | none | `reserve_material`, `verify_anchor_receipt`, `source_projection`, `SourceAllocationReceipt`: **test-only** |
| `circuit_batch` | none: the worker reaches `PrivateOutput::restore_initial`, which never touches `LayerEngine` or `Plan` (`private_output.rs:375-458`); only `PrivateOutput::reserve` (test-only callers) takes a `LayerEngine` | none | Whole module **test-only** in this shard; `Plan`/`Network`/`Op` are live types for shard-B engines, `reserve_plan_release`/`CompletedBatch` are used by nothing but their own tests |
| `transition_journal`, `private_initial`, `consensus_wire` | `worker` | none | Binary-live |
| `protocol_store` | none | none | **Dead** (declared only, `lib.rs:11`) |
| `authenticated_ingress` | `worker` (`Receiver`, `Envelope`, `CommitteeParty`) | none | Live; `verify_packet` callers are `Receiver` plus tests |
| `recipient_seal` | `worker` (`SealedIngress::{decode,open}`, `RecipientKeyCustody::{open,open_capsule}`) | none | `HidingDraft`, `DraftPublic`, `generate_epoch`, `KeyRecord::recipient_spec`: **test-only or dead-chain** |
| `sealed_outbox` | none | none | **Dead** (only its own tests) |
| `source_endpoint` | `worker` (`RequestClaim::decode`, `InnerCredential*`) | none | `OutcomeClaim`, `ProgressOutcomeClaim`, `matches_request`, `admit_complete_transport_frame`: **test-only** |
| `native_worker` | `worker` (`Config::load`, `DispatchClaim::decode`, `receive`/legacy) | none | `SealedNative`, `receive_sealed`, `NativeInvocation::Sealed`: **dead**; hence `pinned_execution.rs` is dead in the binary |
| `private_output`, `private_output_store` | `worker` (`Store::reopen`, `OutputMachine`) | none | `start`, `request_delivery`, `create`: called only by tests |
| `private_send`, `private_send_store`, `asks` | `worker` transitively (PrivateOutput uses PrivateSend, which uses ASKS; the output wire uses `private_send_store::{encode,decode}_message`) | none | Live through the worker; `Asks::dealer_start` and `private_send_store::Store` (the durable delivery driver) are **test-only**; the wire functions are shared with the ACSS/dZK/Sh2t stores (shard B) |
| `entropy` | `worker`? No: `Entropy::os` is reached only by `Store::start`, which only tests call | none | Test-only in practice |
| `arithmetic_reference` | none (`two_bit_addition` used only by `tests::completed`) | none | **Test-only** |
| `transcript`, `private_view` | `#[cfg(test)]` | n/a | Test instruments |

But the `worker` arm itself is **unprovisionable**: no tool generates recipient keys (`generate_epoch`), writes a `Config`, or produces the bootstrap except a `#[test]` run with three environment variables. And the native verifier image it must pin has no Lean source (`Host.JointBackendPartyInner` is absent). So in practice **every module in the shard is reachable only from tests**. `CONSTRUCTION.txt:357-365` concedes "no end-to-end native authority claim", "no positive205 channel run follows".

### 5.2 TODO, FIXME, `unimplemented!`, `todo!`, `#[allow(dead_code)]`

None in the shard (grep). There are two `unreachable!()` calls, both in test `let ... else` destructuring (`source_endpoint.rs:473,557`). "Undone" work is recorded in prose instead: `CONSTRUCTION.txt` says "OPEN", "WIP", "pending" and "peer-owned" dozens of times (for example lines 48, 191, 242, 286, 309, 336, 357, 375), and the doc comments say "remains a source obligation" and "native join". There is no `#[allow(dead_code)]` because everything is `pub` in a library crate, so dead code is invisible to rustc.

### 5.3 Twins (two implementations of one thing)

| Twin | Site A | Site B | Reachable | Delete |
| --- | --- | --- | --- | --- |
| WAL format | `transition_journal.rs` (truncate torn tail) | `protocol_store.rs` (refuse torn tail; u32 lengths; own header) | A | **B** |
| WAL format, third | `transition_journal.rs` | `custody::Anchor` log (`custody.rs:95-172`: whole-journal records, refuse torn tail) | Both (anchor is binary-live) | Unify: the anchor could be a `transition_journal` `Machine` whose events are batch requests; that fixes F1 and F13 |
| One-use reserve semantics | `Kernel.PrivateSuccessorCustody.reserve` (Lean, proved) | `codec::Journal::reserve_batch` (Rust) | Rust only | Emit, don't imitate: the Rust anchor should call a Lean export or run a Lean-emitted checker |
| Physical material release | `custody::reserve_release` + `circuit_batch::reserve_plan_release` + `allocation_receipt::reserve_material` (plaintext Pool rows) | `field_network::Engine::reserve*` + `triple_king::burn_preparation` (King-checked stocks; shard B, `field_network.rs:433-447`) | B is the executed MPC path; A is CLI and crash-probe only | **A** (with `Pool`, `Cut`, the `provision-test`/`reserve`/`recover` arms and `crash-probes.py`) |
| Anchor receipt verification | `allocation_receipt::verify_anchor_receipt` | `private_output.rs:435-449`, `field_network.rs:434-447` | B | A, or make A the single verifier |
| Pinned execution | `native_worker::invoke_native` (legacy, racy, `native_worker.rs:282-345`) | `pinned_execution::SealedInvocation` (sealed, `pinned_execution.rs`) | A (CLI) | **A**, wiring B |
| Pinned execution, cross-crate | `native/pinned_execution.rs:22-55` `snapshot` | `native/resource-client/src/transport.rs:1368-1392` `sealed_snapshot` (near-verbatim: same flags, intent bits, fchmod, seals) | resource-client's is live | Make `pinned_execution.rs` the one copy and include it from resource-client too, or move it into a small shared crate |
| Dealer randomness | `entropy::Entropy` (forkable seeded streams) | `asks::Asks::dealer_start` (`asks.rs:216-230`), `protocol_store::Store::dealer_start` (`protocol_store.rs:254-268`), `private_send_store::Store::dealer` (`private_send_store.rs:216-223`), each reading `/dev/urandom` itself | All test-only except Entropy (via Store::start) | Route all through `Entropy` |
| Cursor | `codec::Reader` (Nat-native) | `consensus_wire::Cursor` (fixed-width, re-parses Nats by scanning to 255) | Both | Merge |
| Nat-from-cursor helper | `recipient_seal::cursor_nat` (345-358) | `authenticated_ingress::get_nat` (119-132), `sealed_outbox::nat` (26-39), `private_output_store::nat` (15-28), `private_output::restore_initial::nat` (398-411), inline loops in `source_endpoint.rs:196-206`, `private_send_store.rs:116-123`, `consensus_wire.rs:235-238` | All | One `Cursor::nat` |
| Adder circuit | `arithmetic_reference::two_bit_addition` (hand-written) | `fixtures/addition-network-2-plan.bin` (Lean-emitted) | Both test-only | **A** |
| Progress frame | `DREGG.PRIVATE.PROTOCOL.PROGRESS\x01` (`authenticated_ingress.rs:327-388`; repeats the clear SIGN preimage, which `CONSTRUCTION.txt:51` says "can expose the body") | `...PROGRESS\x02` (`sealed_outbox.rs:582-620`, digest-only) | v1 via `Outcome::progress_claim`, used by v2 internally; v2 dead | Pick v2 and wire it, or delete both until a consumer exists |
| Release/output receipts | `SourceAllocationReceipt` (Rust) | `PrivateAllocationReceipt.SourceAllocationReceipt` (Lean research) | Neither has a receiver | Delete together, or join |

### 5.4 The `#[path]` shared-source pattern, judged

- **What it buys:** one source file for the hybrid KEM and transit suite, used by two crates that sit in different Cargo workspaces, without publishing a crate.
- **Costs found here:**
  1. **An implicit module contract.** `crypto_transit.rs:9` writes `use crate::hybrid_kem::...`, so every includer must mount `hybrid_kem` at exactly `crate::hybrid_kem`, and the compiler states no such requirement.
  2. **Duplicated dependency pins.** Both crates must pin `aws-lc-sys =0.45.0`, because `hybrid_kem.rs:241` links a version-mangled symbol. Today both locks agree (0.45.0), kept in step by hand.
  3. **Dead code per includer.** `resource-client` compiles `crypto_transit::{seal, open, recipient_context}` and never calls them (it uses `seal_raw_context`/`open_raw_context` only, `pq_mailbox.rs:71,88`). `private-backend` compiles `hybrid_kem::cshake_xof` and the like and never calls `hybrid_kem` directly.
  4. **Tests run twice.** Every gate row runs the shared tests once per includer (`check-rust-tests.sh:433-437` lists `crypto_transit::tests` under private-backend).
  5. **A misleading location.** `pinned_execution.rs` sits at `native/` root as if shared but has one includer, while resource-client keeps its own twin.
- **Verdict:** acceptable as a stop-gap. The better shape is a tiny path-dependency crate, for example `native/mini-crypto`, holding `hybrid_kem` + `crypto_transit` (+ `pinned_execution`). Both workspaces can depend on it by path; that makes the module contract and the pins explicit and removes the procfs/memfd twin.

### 5.5 Tests that do not test, or test only their own fixture

- `authenticated_ingress` tests authenticate with an HMAC `Fixture` and an `OpaqueFixture` (`authenticated_ingress.rs:602-635`, `sealed_outbox.rs:1026-1057`). These are honest fixtures (documented as such). But no test anywhere exercises the production `NativeAuthority` positively, because no native image exists. The only `NativeAuthority` coverage is negative (`/usr/bin/false`, `native_worker.rs:632-647`).
- `codec::tests::lean_empty_fixture` (`codec.rs:332-339`) compares against a hand-typed literal, not Lean output. The "native fixture" claims rest on `main.rs:20-41`, which no gate runs, and on bytes embedded once in `circuit_batch.rs:372-377`.
- `source_endpoint::tests::actual_complete_frame_capacity_includes_all_native_wrapping` (`source_endpoint.rs:575-588`) tests a constant comparison function that no production code calls.
- `allocation_receipt::tests::decoded_claim_is_not_verified_and_codec_preserves_large_digests` (240-261) is a roundtrip only; its comment says so.
- The bootstrap exporter is a test with side effects outside the temp directory when its environment variables are set (`private_output_store.rs:403-463`). Tests used as production tools blur what a green test means.
- The rest (WAL cut sweeps, quota restart, capsule tamper sweeps, the curious-holder view with falsifier) are genuine tests with both poles, and `private_view.rs` has an explicit red falsifier.

### 5.6 Versioned siblings still present

- `PROGRESS\x01` and `\x02` (above).
- `SEALED.INGRESS\x02` and algorithm 1 are kept only to refuse them by name (`recipient_seal.rs:15-20,33-38,199-204`). That is a deliberate tombstone and fine.
- `NativeInvocation::Legacy` and `Sealed` (`native_worker.rs:386`).
- `DREGG.PRIVATE.AUTH.RECEIVER\x02` keeps "old receiver bytes when binding is empty" (`authenticated_ingress.rs:499-501`), a compatibility branch with no deployed v1 data to be compatible with.
- `ASKS.TRANSCRIPT\x02` (dead).

---

## 6. Size and shape

Per-file table: see the header. Totals: shard crate files **11,195** lines (**4,508 test, 6,687 code**, so tests are 40%); shared files 1,096 (345 test, 751 code).

Code by purpose, approximate, from section 1:

| Purpose | Files | Code lines |
| --- | --- | ---: |
| Codecs and wire | `codec`, `consensus_wire`, `source_endpoint`, half of `authenticated_ingress` | ~1,250 |
| Storage and custody | `transition_journal`, `protocol_store`, `private_initial`, `custody`, `allocation_receipt`, `circuit_batch` | ~1,420 |
| Crypto envelopes and keys | `recipient_seal`, `sealed_outbox` | ~1,250 |
| MPC sub-protocols in this shard | `asks`, `private_send`(+`_store`), `private_output`(+`_store`), `entropy` | ~1,760 |
| Worker and entry | `native_worker`, `main`, `lib` | ~660 |
| Ingress, replay, quota | other half of `authenticated_ingress` | ~290 |

**Minimal version for the demo-critical path.** Nothing in this shard is on the Hetzner demo's critical path (sections 1.2 and 7). The minimal version is **the empty set**: drop the crate (11,195 lines here; about 24.7K with shard B and `vaba/`), drop `native/pinned_execution.rs` (245; single consumer), drop root `crash-probes.py` (62) and `check-boundary.sh` (16). Keep `native/hybrid_kem.rs` and `native/crypto_transit.rs`, which resource-client needs. Also move the README "MPC / FHE" row to "authored/executed in tests, not built for deploy".

**If the crate stays as research, a trim that keeps every executed MPC test** (the curious-holder view, King store, objective identity, adders) and removes only dead or twin code:

| Drop | Lines |
| --- | ---: |
| `src/protocol_store.rs` (dead twin WAL) | 341 |
| `src/allocation_receipt.rs` (test-only; move the 4-frame encode/decode check into `codec` tests if wanted) | 404 |
| `src/sealed_outbox.rs` (dead) | 1,269 |
| `native/pinned_execution.rs` (dead in the binary) or, better, keep it and delete the legacy path instead | 245 |
| `circuit_batch::reserve_plan_release` + `CompletedBatch` (189-280) and its four anchor tests (446-628) | ~275 |
| `custody::Pool`, `Cut`, `cut`, `reserve_release`, `recover_snapshot` (230-397) and Pool tests | ~180 |
| `recipient_seal::{DraftPublic, HidingDraft}` (74-138, 359-480), used only by `sealed_outbox` and one `source_endpoint` test | ~187 |
| `source_endpoint::{OutcomeClaim, ProgressOutcomeClaim, matches_request, admit_complete_transport_frame}` (255-378) plus tests | ~270 |
| `native_worker::{SealedNative, NativeInvocation, receive_sealed}` (346-400), or the legacy `invoke_native` if wiring the sealed path | ~55 |
| `asks::Asks::dealer_start` (213-230) | 18 |
| `main.rs` arms `provision-test`, `reserve`, `recover`, `journal-empty` (49-68) + root `crash-probes.py` | ~80 |
| `arithmetic_reference::two_bit_addition` (5-35); switch `tests::completed` to the Lean fixture | 31 |
| **Total** | **~3,355** |

That leaves about 7.8K lines in this shard, of which about 4K are tests. A deeper cut, merging the three WAL formats and five Nat-cursor helpers, would remove roughly another 200-300 lines and fix F1, F3 and F13 at the same time.

---

## 7. Deployability on a small public Linux VM

- **What must exist to run anything here:** the `mini-private-backend` binary (cargo build of a separate workspace that pulls the AWS-LC C build: `cc`, `cmake`, a C compiler); a Unix-socket anchor process; and for the worker, Linux with procfs, memfd, `/usr/bin/timeout`, a protected config, a recipient key WAL, a bootstrap exported by the test harness, and a pinned "native original-prefix verifier" image that **does not exist**. No user, unit, socket activation or directory layout exists in `deploy/` for any of it.
- **Operator-configured:** everything (section 2.5). There are no defaults.
- **Dangerous to expose:**
  - the anchor socket (no peer authentication; burn or bloat to the 16 MiB cliff; journal disclosure; F7);
  - the pool directory (plaintext correlation secrets, never erased; F8);
  - the recipient key WAL (plaintext hybrid seeds; F8);
  - the `reserve` CLI arm (writes released secrets to a file);
  - and `cut` exits.
  None of these is network-facing, but all of them assume a single-tenant box.
- **What a stranger on the internet could exercise:** nothing. The crate opens no TCP port, no Host operation routes to it, and no resource-client verb invokes it.
- **What a malicious enrolled member could exercise:** nothing through the Host or the client. If the worker were somehow wired, a sender who can produce a decryptable capsule could pick a rotated-away key epoch (F6), and anyone able to drive the worker with large requests could cause the stdin/stdout deadlock (F5).
- **Recommendation:** do not build or ship this crate on the demo VM. Treat the README "MPC / FHE: executed (research)" row as "in tests only; not built for any box".

---

## 8. Questions for the Lean side

1. Is there, or will there be, a Lean declaration that produces or verifies `DREGG.JOINT.PRIVATE.INNER.REQUEST\x01` / `INNER.OUTCOME\x01` (the "Host.JointBackendPartyInner" of `source_endpoint.rs:76`)? If not, point at the declaration that is meant to replace the worker's pinned "native original-prefix verifier" (`native_worker.rs:282-345`). The grep finds none.
2. `Compiler.JointBackendPartyCodec.Party.bounded` requires `protocol < 4` (`JointBackendPartyCodec.lean:44`). Rust defines tags 4 (FieldNetwork) and 5 (PrivateOutput), and the worker requires 5 (`native_worker.rs:229`). Which is authoritative: should Lean admit 4 and 5, or should Rust drop them?
3. `JointBackendPartyCodec.decodeRequest` refuses requests above 262,078 bytes (`:155`); Rust accepts up to 262,144 (`source_endpoint.rs:11`). Is 262,078 the canonical bound for the raw request, or only for the complete wrapped frame?
4. Is any Host receiver meant to decode the custody journal (`decodeJournal` / `restoreJournal` / `reserveEncoded`, `PrivateSuccessorCustodyCodec.lean:73-123`)? Today only `PrivateAllocationReceipt` (ResearchWip) and the fixture printer call them. If yes, which receiver, and under which Host operation code (203-205 are unallocated)?
5. `Kernel.PrivateSuccessorCustody.burn` (`:86-89`) marks allocations consumed, but the Rust anchor refuses consumed allocations (`custody.rs:121-124`). Is `burn` meant to be a physical anchor transition (then Rust must accept it), or is it a Lean-only marker (then should `Consumption.consumed` be removed from the wire)?
6. Is there a Lean declaration for retiring or pruning the custody journal (the "source retirement proof" of `codec.rs:284`)? Without one, the physical journal has a hard 16 MiB lifetime.
7. Should Lean `decodeJournal` require set(spent) = set(allocation ids) and positional alignment, as Rust `Journal::decode` effectively does (`codec.rs:224-231`) and `allocation_receipt::original_prefix` assumes (`allocation_receipt.rs:193-211`)? Or is a journal with extra spent tombstones meant to be legal?
8. Where is "fresh current source ReleaseAdmission and allAppliedReady" (`private_output.rs:3-5`, `CONSTRUCTION.txt:292-295`) declared? The grep finds neither name. Which declaration is meant to gate `PrivateOutput::request_delivery`?
9. Is `Compiler.CurrentRecipientRecord` (imports `PrivateSuccessorCustodyCodec`; used by `Kernel/NativeCurrentMemberKey.lean` and `Compiler/RoomKeyReleaseCodec.lean`) the intended source of a recipient's current key epoch for private-backend capsules? That is what F6 needs instead of trusting `capsule.recipient`.
10. `Host/PrivateCircuitPlanFixture.lean` and `Compiler/PrivateBackendBoundaryFixture.lean` define `main` but are in no lake root and imported by nothing (the second only by an hbox-pathed script). Should they become `lean_exe` targets wired into a gate that compares against Rust (`main.rs check-wire-fixtures`, `circuit_batch.rs:367-420`), or be deleted along with the Rust side?
11. `Kernel/JointReserveIngress.lean` ("event60 reservation ingress") decodes `PrivateSuccessorCustody.Descriptor`. Does any Rust producer exist for those Descriptor bytes, or is that ingress also unproduced?
12. `JointBackendPartyCodec.EndpointPin.dispatchCapacity` (`:91-106`): is this meant to be the funded bound that `authenticated_ingress::Receiver` enforces as `capacity_per_party` (D4)? If so, which Lean receiver checks that the operator config's capacity equals the pinned charge?
