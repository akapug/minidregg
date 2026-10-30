# native/private-backend: crate synthesis

| Field | Value |
| --- | --- |
| Crate | `native/private-backend` (package `mini-private-backend` 0.1.0; lib + bin `mini-private-backend`) |
| Date | 2026-10-26 |
| Sources | Shard A, entry/wire/custody/stores/outputs/worker: `private-backend--A-wire-custody-stores.md` ("A"). Shard B, MPC protocol modules: `private-backend--B-mpc-protocols.md` ("B") |
| Spot checks by the synthesizer | `Cargo.toml` workspace members; `sha3` pins in both manifests and both locks; `native_worker.rs:354-358,396-400`; `resource-client/src/private.rs:1215-1240`; `hybrid_kem.rs` test names; `dzk_store.rs:335-346` against `transition_journal.rs:85-92`; `wc -l` of the crate. Nothing was built or run. |
| Stance | Rescue and repair first. Deletion is limited to true twins (the better copy is kept) and to dead code that serves no surface. |

## Executive summary

`private-backend` is a 26,139-line research crate (41 files; I verified this with `wc`, see the shard disagreement in §1). About 43% of it is test code. It implements an asynchronous, Byzantine-tolerant MPC stack over GF(2^128): Bracha/ASKS, IndexGather/VABA/ACS (ePrint 2024/677), ACSS-Id with a hash-based dZK, Sh2t-Id zero sharings, TripleKingDN preprocessing, and a layered Beaver evaluator. Around the stack it has a one-use correlation anchor, a generic crash WAL, recipient-sealed hybrid (X25519 + ML-KEM-768) capsules, and a Linux "recipient worker".

**It is not in the root Cargo workspace.** Its `Cargo.toml` ends with an empty `[workspace]`, and it has its own `Cargo.lock`. The root `members` list (`Cargo.toml:3`) does not name it. Only four `scripts/check-rust-tests.sh` rows `cd` into it. It pins `sha3 =0.10.8`, while the workspace locks 0.10.9. It compiles the shared `hybrid_kem.rs` without ever running the FIPS 203 seeded-ML-KEM known-answer test, which lives only in `resource-client/src/private.rs:1220-1235`. `pinned_execution.rs` is `#[path]`-included only here, and its only users, `SealedNative::new` (`native_worker.rs:356`) and `receive_sealed` (`:398`), have no caller.

**No surface of the public demo exercises this crate.** Private rooms (`resource-client` `private.rs`/`roomkey.rs`) and selected exchange (`selected_exchange.rs`) have no dependency on it. Neither does any other crate, Host operation, unit or journey. The crate sends zero Host operations, and the "native205/network203" routes it names are unallocated. The README's "MPC executed" claim rests on one in-process test (`private_view.rs:323-379`). ACS/VABA, the anchor service, the worker, every durable store except the King store, and any network transport have never run outside tests. No transport exists at all.

What is worth rescuing:
- the executed MPC path, as an honest in-process demo;
- the crash-swept WAL;
- the capsule plus key-epoch custody, as substrate for private rooms and traffic privacy;
- PrivSend/PrivateOutput, as the cryptographic core of a real *selected* release.

The urgent repairs:
- the anchor bricks on a torn tail;
- the WAL silently truncates published history, and one test enshrines the resulting dealer re-deal;
- a red dZK test runs in no gate;
- the capsule chooses its own key epoch;
- a "retryable" error is returned after the material is already burned.

The true twins to delete total about 3.4K lines.

---

## 1. What it is and does

### 1.1 Frame

The crate has its own workspace and lock (A §1.0). The lock has 61 packages, including the AWS-LC C build (`cc`, `cmake`). The `aws-lc-sys =0.45.0` pin is load-bearing: `hybrid_kem.rs:241` links the version-mangled symbol `aws_lc_0_45_0_EVP_PKEY_keygen_deterministic`, so this lock and the root lock must be bumped together.

The separate workspace is deliberate, but nothing enforces lockstep. I verified the following myself:
- the root `Cargo.toml:3` `members` omits the crate;
- `native/private-backend/Cargo.toml:13` has `sha3 = "=0.10.8"` and `:19` has `[workspace]`;
- the private-backend lock has `sha3 0.10.8` (`Cargo.lock:363-364`), the root lock has 0.10.9 (`Cargo.lock:1217-1218`), and `resource-client/Cargo.toml:28` pins `=0.10.9`.

`hybrid_kem.rs:26-27` uses `sha3::CShake256Core` for the seed combiner, so the two trees compile the same KEM seed path against different `sha3` patch versions. `hybrid_kem.rs:236-238` claims a known-answer test against an independent FIPS 203 implementation. That test, `the_seeded_ml_kem_key_matches_an_independent_fips_203_implementation`, is in `resource-client/src/private.rs` around lines 1220-1236 (verified). `hybrid_kem.rs`'s own four tests (`:404-460`) have no known answer.

The private-backend gate row `private-backend-hybrid` (`check-rust-tests.sh:433-437`) runs `crypto_transit::tests::the_transit_combiner_matches_an_independent_known_answer`. That checks the transit combiner, not the seeded ML-KEM layout. So the seeded ML-KEM path is never checked by a known answer in this tree. The cross-crate review reached the same finding (`tiny-crates-and-shared-root.md:53,899`).

`CONSTRUCTION.txt` (406 lines) is an appended run diary (r13-r42). It names Lean declarations and Host routes that do not exist (A §1.0).

### 1.2 Module map (lines; test = `#[cfg(test)]` regions)

Shard A modules (A header table; 11,195 lines, of which 4,508 are test):

| Module | Lines | Code | Role |
| --- | ---: | ---: | --- |
| `main.rs` / `lib.rs` | 71 / 65 | 71 / 61 | 7 CLI arms / 37 `pub mod`s, 3 `#[path]` mounts |
| `codec.rs` | 380 | 352 | base-255 Nat, Generation, Correlation, custody Journal, `reserve_batch` |
| `consensus_wire.rs` | 288 | 258 | VABA/ACS/Gather wire + outbox |
| `transition_journal.rs` | 331 | 167 | generic `Machine` WAL (header, len‖body‖SHA-256, replay-and-compare) |
| `protocol_store.rs` | 341 | 281 | second WAL format (ASKS); **no consumer** |
| `private_initial.rs` | 73 | 73 | immutable `.initial` creation file |
| `custody.rs` | 528 | 397 | Unix-socket one-use `Anchor`, plaintext `Pool`, `Cut` crash hooks |
| `allocation_receipt.rs` | 404 | 226 | allocation receipt frames; verifier test-only |
| `circuit_batch.rs` | 629 | 280 | `Plan`/`Network`/`Op` + raw-row `reserve_plan_release` |
| `entropy.rs` | 95 | 58 | forkable SHA-256 PRG |
| `asks.rs` | 698 | 487 | Bracha RBC/RA + ASKS (2024/677 Alg. 1-2), not an order book |
| `private_send.rs` / `_store.rs` | 478 / 297 | 305 / 242 | recipient-private delivery (2024/1666 App. C) + WAL |
| `authenticated_ingress.rs` | 1,031 | 575 | enrolled-party envelope, replay + per-party quota, `Receiver` |
| `recipient_seal.rs` | 590 | 590 | hybrid sealed capsules + `RecipientKeyCustody` |
| `sealed_outbox.rs` | 1,269 | 658 | sender-side draft/capsule store; **no consumer** |
| `source_endpoint.rs` | 589 | 378 | joint request/outcome/inner-credential codecs |
| `native_worker.rs` | 681 | 526 | the `worker` arm: open capsule → pinned image → output receiver |
| `private_output.rs` / `_store.rs` | 483 / 909 | 483 / 184 | fixed-recipient output reconstruction + WAL |
| `arithmetic_reference.rs` | 512 | 35 | hand-written 2-bit adder + test builders |
| `transcript.rs`, `private_view.rs` | 48, 405 | 0 | test-only taps; the curious-holder check |

Shard B modules (B header table; 14,944 lines, of which 6,452 are test):

| Group | Files | Lines | Code |
| --- | --- | ---: | ---: |
| Agreement (2024/677) | `gather` 415, `vaba` 847, `acs` 335, `acs_store` 166 | 1,763 | 1,125 |
| Byzantine harness (test-only) | `vaba/byz` 2,268, `vaba/byz_targeted` 273 | 2,541 | 0 |
| Field + dead recovery | `reconstruction` 301 | 301 | 212 |
| Sharing | `dzk` 1,134, `dzk_store` 387, `acss_id` 1,111, `acss_id_store` 370 | 3,002 | 2,299 |
| Zero sharing | `sh2t_id` 1,425, `sh2t_id_store` 498 | 1,923 | 1,408 |
| Preprocessing | `triple_king` 1,813, `king_store` 1,204 | 3,017 | 1,837 |
| Online evaluation | `field_network` 1,267, `field_network_store` 428, `field_network_layers` 702 | 2,397 | 1,611 |

The `#[path]` shared files add 1,096 lines (A §1.25): `hybrid_kem.rs` 471, `crypto_transit.rs` 380, `pinned_execution.rs` 245.

**Shard disagreement on size.** A puts the crate at "about 24.7K" (A header note). B counts 26,139 (B "Crate total correction"). I verified 26,139 with `wc -l src/*.rs src/vaba/*.rs`. B is right: A had not seen `vaba/` in full when it estimated.

### 1.3 The binary

`main.rs:17-70` has seven arms (A §1.2):

| Arm | What it is |
| --- | --- |
| `check-wire-fixtures` | A 4-frame Rust/Lean byte check. Its input comes from `check-boundary.sh`, which has hbox-only paths. No gate runs it. |
| `worker CONFIG` | stdin `DispatchClaim` → stdout pending receipt; Linux only. |
| `anchor ROOT SOCKET` | Single-threaded Unix-socket server. |
| `provision-test` / `reserve` / `recover` / `journal-empty` | Harnesses. `reserve` uses a hard-coded test Generation (`main.rs:61`) and writes the released secret to a file. |

The only callers are two root orphans from one commit: `crash-probes.py` (62 lines) and `check-boundary.sh` (16 lines) (A §1.2). Neither is in a gate.

### 1.4 Wire formats, sockets, files, environment

- **Frames.** More than 60 domain strings are catalogued in A §1.27 and B §1.20. All use base-255 Nat, `bytes` = Nat length + raw bytes, u16 LE party ids, and are canonical by re-encode. The externally meaningful ones:
  - the custody journal (`DREGG.PRIVATE.CORRELATIONS\x01`, `codec.rs:182`);
  - allocation receipts (`allocation_receipt.rs:18,175`);
  - the circuit Plan (`circuit_batch.rs:99`);
  - the committee party / AUTH / INGRESS envelopes (`authenticated_ingress.rs:47-262`);
  - the joint request/outcome (`source_endpoint.rs:9-10`);
  - the sealed ingress capsule (`recipient_seal.rs`, `\x03`, algorithm 2 = hybrid).
  
  Everything else (VABA, ACS, ASKS, PrivSend, dZK, ACSS, Sh2t, King, FIELD wires; the worker frames) is committee-internal or local.
- **Processes.** The `anchor` arm (long-lived) and the `worker` arm (one-shot). The worker's child is `/usr/bin/timeout 45s /proc/self/fd/N` (legacy, `native_worker.rs:318-325`). The sealed `/proc/<pid>/fd` child path is dead (A §1.28).
- **Socket.** One Unix stream at an operator-chosen path. It is bound first and chmodded 0600 second. There is no `SO_PEERCRED` (`custody.rs:193-194`).
- **Files.** Every store is a WAL `P` plus `P.lock`; output and field stores add `P.initial` and `P.initial.lock`. The anchor root holds `authority.lock` and `authority.log`. Pools are `row-<i>` plus `manifest` (plaintext). Receipts are snapshots plus `.pending-<pid>-<nonce>` temp files, which are never cleaned up (A §1.28, B §1.21).
- **Environment** (tests only): `MINI_PRIVATE_TEST_ENTROPY`, `MINI_PRIVATE_SOURCE_GENERATION/BOOTSTRAP_DEST/SOURCE_DESCRIPTOR` (the "production" bootstrap exporter is a `#[test]`, `private_output_store.rs:319-465`), `BYZ_SEEDS/BYZ_FROM`, `MINI_KING_STORE_DIR`.
- **Ports.** None. There is no TCP or HTTP anywhere in the crate.
- **Exit codes.** 1 = refused. 70 = injected crash cut, from library code (`custody.rs:330`).

---

## 2. What it assumes of its surroundings

### 2.1 Host protocol operations

**None are used** (A §2.1, B §2.1). No file frames a Host request or links `native/host-operations.rs`. `protocol/host-operations.json` allocates 186 operations, and **203, 204 and 205 are unallocated**. No operation's symbol or owner contains "private" or "joint". The vocabulary that `CONSTRUCTION.txt` and the doc comments use as though they were Host routes is Rust-only:

| Name | Status (A §2.1) |
| --- | --- |
| "native205", "network203" | not Host operations |
| "event60" | a Kernel event kind decoded by `Kernel/JointReserveIngress.lean`, which reads `PrivateSuccessorCustody.Descriptor`, not any frame this crate emits |
| `Host.JointBackendPartyInner` (`source_endpoint.rs:76`) | exists nowhere in Lean |
| `Host.PrivatePartyReserveAuthor` (`CONSTRUCTION.txt:379`) | exists nowhere |
| "ReleaseAdmission", "allAppliedReady" (`private_output.rs:3-5`, `CONSTRUCTION.txt:292-295`) | exist nowhere (A D5, B B-S4) |
| "CredentialSignatureAdmission.verifyNative" for this frame (`authenticated_ingress.rs:185`) | `verifyNative` exists for other receivers only (A D7) |

### 2.2 Lean codecs: matched / mismatched / Rust-only

The primitive codecs match `StreamCodec.nat`/`bytesStream`/`framed` (`Compiler/Tower256ConcreteBackend.lean:679-684,880-912,1418-1420`) (A §2.2).

**Matched, byte for byte.** Every decoder below except the journal lives only in the opt-in `ResearchWip` root (`ResearchWip.lean:50,86-89`, `lakefile.toml:196`). No Host receiver calls any of them.

| Frame | Rust | Lean | Checked how |
| --- | --- | --- | --- |
| Custody journal | `codec.rs:182-234` | `PrivateSuccessorCustodyCodec.lean:12-77` (compiled into Host via `JointReserveIngress.lean:8`, but its decode is called only by research/fixture files) | hand-run `check-wire-fixtures`, output not in repo |
| Reservation request | `codec.rs:305-319` | `PrivateBackendBoundary.lean:16-21` | same fixture |
| Allocation receipt | `allocation_receipt.rs:18-53` | `PrivateAllocationReceipt.lean:17-25` | same fixture |
| Source allocation receipt | `allocation_receipt.rs:166-191` | `PrivateAllocationReceipt.lean:85-104` | none |
| Circuit Plan | `circuit_batch.rs:99-187` | `PrivateCircuitAllocation.lean:87-136` | bytes embedded once from `Host/PrivateCircuitPlanFixture.lean`, which is in no lake root |
| AUTH envelope / INGRESS carrier | `authenticated_ingress.rs:141-262` | `JointBackendPartyCodec.lean:108-138` (bound 131,100 agrees) | none |
| Joint outcome | `source_endpoint.rs:255-334` | `JointBackendPartyCodec.lean:159-196` | none |

**Mismatched** (A §2.2, F15):
1. Joint request bound: Rust `MAX_REQUEST` = 262,144 (`source_endpoint.rs:11`), Lean refuses above 262,078 (`JointBackendPartyCodec.lean:155`).
2. Protocol tags: Rust has tags 4 (FieldNetwork) and 5 (PrivateOutput), and the worker *requires* 5 (`native_worker.rs:229`). Lean `Party.bounded` admits protocol < 4 only (`JointBackendPartyCodec.lean:44`). B adds that Sh2t-Id and King frames have no tag on either side (B §2.1, §5.2).
3. Empty-field rules differ (`authenticated_ingress.rs:107-113` vs `JointBackendPartyCodec.lean:43-45`). Lean's subject field is a `subjectIdStream`; Rust's is opaque bytes.
4. Rust `Journal::decode` additionally requires no duplicates and set(spent) = set(allocated) (`codec.rs:224-231`). Lean `decodeJournal` accepts any canonical encoding. `allocation_receipt::original_prefix` (`:193-211`) assumes positional alignment, which neither side checks.
5. Rust `Plan` decode enforces numeric bounds. Lean `Plan.valid` has none (A D9, B B-S7).

**Rust-only, with no Lean decoder:** inner credential request/outcome, sealed ingress, draft, progress v1/v2, worker dispatch/config/pending, batch reserve, output frames (A §2.2). Every MPC wire and domain string in B §1.20 also has no Lean decoder; none of those strings occurs in any `.lean` file (B §1.20).

**No Lean specification of any protocol** exists: none for Bracha, VABA, ACS, ACSS, dZK, Sh2t, King or Beaver (B §2.2). The nearest neighbours are:
- `Assurance/MpcSealedCellExecution.lean`: n = 3, t = 2, and it disclaims malicious-MPC security (`:1-25`);
- `Kernel/PrivateSuccessorCustody.lean`: the one-use journal model, "not MPC" (`:1-5`).

### 2.3 OS and fixtures

- Unix throughout: flock, mode bits, `UnixListener`. The worker is Linux-only (procfs exec, memfd seals, GNU `/usr/bin/timeout` at that path; A §2.3).
- It assumes honest crash-prefix storage and meaningful `fsync`.
- It assumes "authenticated confidential reliable party channels" that **are not implemented**. Every test moves frames through in-process `VecDeque`s (A §2.4, B §2.4).
- **The fixtures are frozen artifacts with no in-tree producer.** The width-8 adder's Lean producer (`emitPairs` in `Compiler.ObliviousNatRipple [deleted 212c79af]`, `Host.ObliviousNatAddEmit [deleted 212c79af]`) was deleted in `212c79af` on 2026-10-04 (B §2.5).

---

## 3. Does it decide anything semantic?

Both shards treat protocol thresholds as legitimate Rust protocol mechanics with paper references, not violations: Bracha n-f/f+1, ICG quorums, robust-decoding support, ASKS coherence (A §3, B §3). I agree. The table below merges both shards' violation lists and ranks them by blast radius. Under ATLAS §7 each of these is a decision that should be a Lean export or a Lean-emitted artifact.

| Rank | path:line | What Rust decides | Lean counterpart | Blast radius |
| --- | --- | --- | --- | --- |
| 1 | `codec.rs:245-289`, `custody.rs:143-189`; `triple_king.rs:367-407` reused at `field_network.rs:433` (A D1, B B-S1) | **Whether a one-use row (triple, pad, plan row) is spent.** A Rust copy of `reserve`, held by a Rust anchor. Rust and Lean agree only through a hand-run 4-frame fixture. | `Kernel.PrivateSuccessorCustody.reserve` + `reserve_never_reassigns` (`Kernel/PrivateSuccessorCustody.lean:77-82,104-109`); `reserveEncoded` (`Compiler/PrivateSuccessorCustodyCodec.lean:118-123`). None is called. | Re-issuing a Beaver triple reveals the difference of the masked operands to every holder: a privacy break |
| 2 | `triple_king.rs:216-238`; `field_network.rs:78-99` (B B-S2) | **What counts as "the same material"**: row ids are SHA-256 over (domain, source generation, context), and consumer attempts are deliberately excluded. | none; `CorrelationId` is abstract | A derivation that maps one stock to two ids defeats rank 1 |
| 3 | `native_worker.rs:268-281,437-453`; `source_endpoint.rs:241-247` (A D7) | **Packet admission is delegated to an operator-pinned external image.** Rust checks only equality and non-emptiness of its claim. | named but absent (`Host.JointBackendPartyInner`; `verifyNative` not wired for this frame) | Admission = "whatever binary the config hashes"; a script that echoes the expected bytes admits any decryptable capsule |
| 4 | `native_worker.rs:425-430` (A D8, F6) | **Which recipient key epoch is acceptable** is taken from the capsule itself, contrary to the contract at `recipient_seal.rs:243-244`. | `Compiler/CurrentRecipientRecord.lean` exists (research; not joined) | Key rotation does not fence retired epochs |
| 5 | `acss_id.rs:524-533,589-595,662-704`; `sh2t_id.rs:719-725,788-803`; `dzk.rs:697-705,852-896`; `private_output.rs:282-296`; `private_send.rs:146-160` (B B-S4, A D6) | **Declassification gates**: f+1 "environment requests" open rows, publicly reconstruct secrets, or authorize a receiver. They are plain `pub fn`s. | none ("ReleaseAdmission" does not exist) | Any holder of f+1 store handles can reconstruct dealt inputs (test-only today; the worker never calls `request_delivery`) |
| 6 | `codec.rs:283-285` (A D3) | **Lifetime cap**: once the encoded journal reaches 16 MiB, every reservation is refused forever ("source retirement proof required"). | none | Permanent halt. One Objective run reserves 13,563 plan rows plus 6×429 preparation rows per holder (B Q10) |
| 7 | `authenticated_ingress.rs:284-313`; `native_worker.rs:75,234-235` (A D4) | **Replay identity and "funded quota"** per party, set from operator config | `JointBackendPartyCodec.EndpointPin.dispatchCapacity` (research, no receiver) | Honest parties starve, or a Byzantine party grows WAL state; "funded" is only a label |
| 8 | `private_output.rs:113-121` (A D5) | **Release identity**: one release per (parent context, recipient), descriptor excluded | none | Re-release or wrongful refusal |
| 9 | `field_network.rs:104-120,154-182` (B B-S3) | **Plan binding format**: which inventories, rows and inputs a plan consumes | `Plan.bindingBytes` is opaque (`PrivateCircuitAllocation.lean:20-23`) | A wrong binding burns the wrong stock, permanently |
| 10 | `custody.rs:121-124` (A D2) | The anchor refuses any consumed allocation, so Lean `burn` is unrepresentable on the physical side | `PrivateSuccessorCustody.burn` (`:86-89`) | Silent model divergence; every `!a.consumed` check is vacuous |
| 11 | `triple_king.rs:1008-1133` (B B-S5) | **Blame** (`Dispute`/`Accusation`) | none | Nothing consumes it yet |
| 12 | `field_network.rs:637-678` (B B-S6) | A non-Boolean input publicly opens x·(x+1) | none (documented) | Leaks a function of a mistaken honest input |
| 13 | `circuit_batch.rs:59-98`, `triple_king.rs:28`, `field_network.rs:126,133,189-200`, etc. (A D9, B B-S7) | Public capacity bounds | `Plan.valid` has no bounds | Shape only |
| 14 | `arithmetic_reference.rs:5-30` (A D10) | **A hand-written circuit** in a "derived path only" repository | twin of the Lean-emitted `fixtures/addition-network-2-plan.bin` | Test-only |

**What correctly stays physical** (A §3.2, B §3.2):
- Decryption grants no authority, and `DecryptedEnvelope` has no Debug or Clone.
- Every `*Claim` decoder yields only a claim; the verified types have private constructors.
- `Receiver::receive` re-checks current authority even for duplicates.
- Outputs are "recipient-local shares only", and nothing mints a release token.
- There are no balances, prices or tariffs anywhere in the crate: `asks.rs` is ASKS (secret sharing), and "allocation" means a row assignment.

---

## 4. Flaws, with concrete failure scenarios, ranked

Severity assumes the crate is wired as designed. Today nothing reaches it, so nothing below can hurt the demo.

1. **WAL silently truncates published history; one test enshrines the re-deal** (A F2, B F-B2).
   - Cause: `transition_journal.rs:102-114` truncates at the first record whose length points past EOF, and truncates a final record with a bad checksum.
   - Scenario: bit rot hits an interior length field, or a published last record. The store loses every later record without an error. The next `dealer` call draws fresh `/dev/urandom` coefficients, so parties that already received the first sharing see a second one: dealer equivocation.
   - The test `sh2t_id_store.rs:403-436` deliberately cuts a byte from a returned dealer record and asserts a fresh re-deal. That makes equivocation a regression-protected behaviour.
2. **The anchor bricks on a torn tail** (A F1). `custody.rs:95-111` uses `read_exact` with no repair, and `torn_anchor_refuses` (`:499-512`) asserts it. One power loss mid-append and every King burn, plan burn and output reserve fails forever, unless an operator truncates the log. That truncation is the very rollback the anchor exists to prevent. The crate has three WAL formats with three torn-tail policies (`transition_journal` truncates; `protocol_store` and the anchor refuse). `.initial` files are written in place, so a torn one bricks too (A F3; B F-B18, which adds that the plan rows are already burned when `field_network_store::create` bricks).
3. **"WouldBlock after burn"** (B F-B3). `Engine::reserve_inner` burns the whole plan (`field_network.rs:433`), then returns `ErrorKind::WouldBlock` if one input sharing is merely slow (`:458-461`). The retry is refused because every row is spent, and unlike the King, the Engine has no `from_burned` rebuild. The error kind invites exactly the retry that cannot succeed.
4. **Lost reply = lost material** (A F14, B F-B22). The anchor commits, the reply is lost, the client errors, and the retry gets `AlreadyExists`. `burn_preparation` never writes its receipt, so not even the King can recover. The burn half of the repository's lost-reply law holds; the exact-retry half does not. `verify_anchor_receipt` (`allocation_receipt.rs:75-123`) and `open_burn_receipt` (`triple_king.rs:418-444`) already have the shape of the missing "return my allocation" path.
5. **The capsule picks its own key epoch** (A F6). A sender with a valid inner credential keeps sealing to a retired epoch 7, and the worker keeps opening it (`native_worker.rs:425-430`).
6. **Anchor: no peer authentication, bind/chmod race, one connection at a time** (A F7). Any local process that can connect can do three things: burn arbitrary rows, inflate the journal to the 16 MiB cliff, or read every Generation. An idle connection stalls all other clients for 10 s, repeatably.
7. **Pinned execution TOCTOU and deadlock** (A F4, F5). The legacy pin, which is the only path the CLI uses, hashes an fd and then execs `/proc/self/fd/N`. An in-place write in between runs different bytes. It also has no `--kill-after`, so a child that ignores SIGTERM hangs the worker forever. Both legacy and sealed paths write up to 16 MiB of stdin before reading stdout, which deadlocks against a chatty child (the sealed twin has the same defect, `tiny-crates-and-shared-root.md:908`). The sealed memfd path fixes the race, but nothing calls it.
8. **One malicious member stalls preprocessing forever** (B F-B4). The King interpolates the *first* 2f+1 z points with no error correction (`triple_king.rs:765-779`). One bad point fails the check, burns 6 rows per holder, and yields a `Dispute` that nothing consumes. The docs admit "no GOD". Localization buys detection, not progress. ACS exists but selects nothing (B F-B5).
9. **A test is red by reading and runs in no gate** (B F-B1). I verified this: `dzk_store.rs:340-346` appends one byte and asserts that `open` errs, but `transition_journal.rs:87-90` truncates any tail shorter than 8 bytes and opens. No `check-rust-tests.sh` row names `dzk_store::tests`.
10. **Quadratic anchor log and unbounded reads** (A F12, F13). Each record is the whole journal, so 10,000 single reserves come to about 5 GB. `transition_journal` reads the entire WAL with no bound. B adds a whole-machine clone on every append, consistent with the 902 MB King-store RSS measured at n = 4 (B F-B8), and one fsync per received frame, about 8,067 per holder per run, unmeasured (B F-B17).
11. **Committee-internal resource attacks** (B F-B6, F-B7, F-B16):
    - unbounded retention of future-view VABA frames is pushed onto a transport that does not exist;
    - `correct_polynomials` runs an exhaustive C(n, f+1) search on every frame (about 2×10^9 `Field::mul` per frame at n = 16 with a full batch);
    - the sequential Engine allocates a Bracha per (gate, holder) on first sight.
12. **Secrets at rest, no zeroize, `Debug` on secrets** (A F8, F9; B F-B9, F-B10):
    - plaintext pool rows that are never erased;
    - recipient key seeds journalled in clear;
    - dealer seeds and input polynomials in WALs, i.e. the dealer's inputs in clear;
    - `crypto_transit::generate_keypair` drops `Zeroizing` (`crypto_transit.rs:71-74`);
    - Sh2t and dZK secret structs derive `Debug` (`sh2t_id.rs:66,168,204,296`; `dzk.rs:235,474,525`).
13. **Variable-time GF(2^128)** (`reconstruction.rs:18-32`; B F-B11). Admitted in the code.
14. **Crash injection and secret egress ship in the library and binary** (A F10). `Cut` calls `exit(70)` from `pub fn reserve_release`. The `reserve` arm writes released secrets to a file.
15. **The worker mutates the pinned bootstrap before checking its hash** (A F11). It fails closed, but the pinned artifact is modified by the check.
16. **Test anchor twin** (B F-B12, F-B13). Every MPC test uses `AnchorFixture` (`triple_king.rs:1231-1294`), never `run_anchor`. Flaws 2, 6 and 10 are therefore never exercised on the MPC path. No test puts preparation and plan rows on one anchor, so the 16 MiB cliff is never approached.
17. **Smaller items:**
    - `AgreedAccusation` makes a group outcome schedule-dependent (B F-B14);
    - f = 0 is accepted by some constructors (B F-B15);
    - single-instance `LOCK_NB` stores give unqueued refusals (A F19);
    - config custody checks mode but not owner (A F20);
    - doc references point at things that do not exist: `vaba_store`, the deleted `emitPairs` (B F-B19).
    
    Neither shard found a panic on untrusted bytes in non-test code (A F18, B F-B20).

---

## 5. Rescue / Repair / Delete

### 5.0 What never ran, and which demo surfaces touch it

**Demo surfaces.** None of the public demo's surfaces exercises this crate:
- *Private rooms* are `resource-client` `private.rs`/`roomkey.rs`: pure client cryptography with no dependency on this crate and no socket (`resource-client--F...md:48,85`).
- *Selected exchange* is `resource-client` `selected_exchange.rs` over fn/NNTP, with no dependency either.
- *Traffic privacy* (`pq_mailbox`, `cohort_tcp`) shares only the `#[path]` file `crypto_transit.rs` (`seal_raw_context`/`open_raw_context`, A §1.25). It never touches a private-backend module.
- The WEB-SPK-PUBLIC week-1 list (Caddy, ssh shell, static docuverse, EtherCalc grain, Hermes pool rows, PAY door, Discord) names nothing in this crate.

**What has never run outside `cargo test`:**
- the `anchor` service against a real client;
- the `worker`, which cannot be provisioned: no tool writes a `Config`, calls `generate_epoch`, or produces the bootstrap except an env-driven `#[test]`, and the pinned verifier image has no source (A §5.1);
- ACS/VABA/Gather, which are tested by the harness but never on the MPC path (B §5.1);
- `field_network_store`, `acs_store`, and the `dzk_store`, `acss_id_store` and `sh2t_id_store` `Store`s;
- `sealed_outbox`, the sealed pinned-execution path, any inter-host channel, and any Host operation.

**What has run in tests:**
- The executed MPC path: `private_view.rs:323-379` plus its falsifier `:384-405`, a width-8 adder at n = 4, f = 1 with per-holder test anchors, in one process.
- `king_store`, with 5 tests gated, including a SIGKILL mid-King.
- The WAL crash-cut sweeps.
- The capsule tamper sweeps.
- The VABA harness. It has real oracles, but only one VABA unit test is gated (B §5.4).

### 5.1 RESCUE: what it would take, size, and the demo surface it serves

| # | What to rescue | Takes | Size | Serves |
| --- | --- | --- | --- | --- |
| R1 | **The executed MPC path as an honest, in-process demo**: ACSS-Id + dZK + Sh2t + King + `LayerEngine` + `private_output` (B §6.3 keeps about 9.7K) | A CLI arm (or a test-built static artifact) that runs the 4-party in-process adder and emits the curious-holder transcript summary, labelled "single process, n = 4, static f = 1, no simulator, no GOD". Re-home the fixture producer (B Q7) so the plan is Lean-emitted again. Fix flaw 3 (Engine `from_burned`). | S (demo artifact) / M (with producer) | **MPC** (a docuverse page, not a service) |
| R2 | **`transition_journal`** (331), the generic crash WAL, which has the best crash-cut tests in the tree | Repair flaw 1, then promote it to the one WAL used by the anchor (as a `Machine` whose events are batch requests, fixing flaws 2, 10 and 13 at once; A §5.3) and possibly to client custody elsewhere | M | All (substrate) |
| R3 | **`recipient_seal` + `RecipientKeyCustody`**: hybrid sealed capsules with epoch-indexed recipient keys | Fix flaw 5 (bind the epoch to `CurrentRecipientRecord`, A Q9); encrypt or wrap seeds at rest; zeroize. Then it is a candidate key-epoch custody for room-key rotation, and the receive side of sealed traffic. | M | **Private rooms**, **traffic privacy** |
| R4 | **`authenticated_ingress`** (enrolled-party envelope, replay, per-party quota), plus **`sealed_outbox`** (sender-side idempotent capsule store) | A transport (none exists). Lean-side funding of the quota (A Q12). Pick progress v2 and delete v1. Bounded id pruning. | L | **Traffic privacy** (receiver/sender of shuffled opaque packets) |
| R5 | **`private_send` / `private_output`**: release to exactly one requested recipient, dealer may vanish | A Lean `ReleaseAdmission` to gate `request_delivery` (A Q8, B Q5); a channel; an exactly-once lost-reply path (flaw 4) | L | **Selected exchange** (a cryptographic "only the selected recipient learns" core) |
| R6 | **ACS/VABA/Gather + `vaba/byz` harness** (4,304): the 2024/677 erratum and implemented-vs-printed predicate evidence | Wire ACS to select King sources and input dealers (B F-B5). Bound future views (B F-B6). Gate the harness sweeps. | L | **MPC** (liveness), research record |
| R7 | **`pinned_execution.rs`** (sealed memfd invocation) | Make it the one copy: include it from resource-client in place of the `transport.rs:1368-1393` twin, or move it into a tiny shared crate with `hybrid_kem`/`crypto_transit` (A §5.4). Add a reader thread (deadlock fix). | S | Substrate (traffic privacy's sealed exec) |
| R8 | **Lean codec agreement** for journal/receipt/Plan | Turn `PrivateBackendBoundaryFixture.lean` and `PrivateCircuitPlanFixture.lean` into gated `lean_exe`s compared against `check-wire-fixtures` / `circuit_batch.rs:367-420` (A Q10); drop the hbox paths | S | Rank 1 of §3 (makes "Rust mirrors Lean" checked rather than asserted) |

### 5.2 REPAIR: specific defects

| # | Defect | Site | Fix |
| --- | --- | --- | --- |
| P1 | Torn-tail brick | `custody.rs:95-111` | Run the anchor on `transition_journal` (R2), or truncate the final partial record |
| P2 | Silent interior truncation | `transition_journal.rs:102-105` | Refuse when a length points past EOF and later records exist. Only a final torn record may truncate. |
| P3 | Test enshrining re-deal | `sh2t_id_store.rs:403-436` | Invert it: a truncated published dealer record must refuse, or must re-derive the *same* deal from a journalled seed |
| P4 | Red test, ungated | `dzk_store.rs:340-346` | Update it to the post-`fa84160e` semantics (as `sh2t_id_store.rs:428-430` was); add `dzk_store::tests` to a gate row |
| P5 | WouldBlock after burn | `field_network.rs:449-462` | Check every input's completeness *before* the burn, and add an Engine `from_burned` analogue |
| P6 | Lost reply on reserve and burn | `custody.rs:356-367`, `triple_king.rs:379-398`, `private_output.rs:125-138` | An anchor request "return my existing allocation for (generation, ids)", verified by the existing receipt verifiers |
| P7 | Capsule chooses key epoch | `native_worker.rs:425-430` | Expected spec comes from custody's *current* epoch or the source enrollment |
| P8 | Anchor peer auth and bind race | `custody.rs:193-198` | Bind under a 0700 directory, or a umask; check `SO_PEERCRED`; serve concurrently or drop idle connections fast |
| P9 | Legacy pin TOCTOU, no kill-after, pipe deadlock | `native_worker.rs:300-338`; `pinned_execution.rs:146-157` | Wire `SealedNative` and delete the legacy path; `--kill-after`; reader thread |
| P10 | 16 MiB lifetime cliff, quadratic log | `codec.rs:283-285`, `custody.rs:158-164` | Append deltas instead of whole journals. A retirement rule needs a Lean owner (A Q6). |
| P11 | Codec mismatches | `source_endpoint.rs:11`; `authenticated_ingress.rs:20-27` | Align to 262,078; settle tags 4 and 5 with Lean (A Q2) |
| P12 | `sha3` split; FIPS 203 KAT does not travel | `private-backend/Cargo.toml:13`; `resource-client/src/private.rs:1220-1235` | Pin `=0.10.9`. Move the known-answer test into `hybrid_kem.rs`'s own tests so every includer runs it. |
| P13 | Secrets: zeroize, `Debug` | `crypto_transit.rs:71-74`; `entropy.rs:19-22`; `sh2t_id.rs:66,...`; `dzk.rs:235,...` | `Zeroizing` through the boundary; remove `Debug` from secret-bearing types |
| P14 | `.initial` written in place | `private_initial.rs:39-44`; `field_network_store.rs:224-242` | temp + fsync + rename |
| P15 | Crash hooks and secret egress in the library | `custody.rs:320-332`; `main.rs:57-66` | `#[cfg(test)]` the `Cut`; drop the `reserve` arm |
| P16 | Bootstrap mutated before its pin is checked | `native_worker.rs:463-481` | Hash the file before `Store::reopen` |
| P17 | Doc rot | `vaba.rs:17`; `CONSTRUCTION.txt:329-336,367-379`; `private_view.rs:27` | Rewrite `CONSTRUCTION.txt` as a present-state document |

### 5.3 DELETE: true twins (better copy kept) and dead code with no surface

| Delete | Lines | Kept twin / reason | Source |
| --- | ---: | --- | --- |
| `protocol_store.rs` | 341 | twin of `transition_journal` + `Machine`; zero consumers | A §1.6, §5.3 |
| `custody::Pool`, `Cut`, `reserve_release`, `recover_snapshot` + Pool tests; `circuit_batch::reserve_plan_release` + `CompletedBatch` + 4 tests; `allocation_receipt::reserve_material` | ~180 + ~275 + ~40 | twin of the executed `field_network::Engine::reserve*` + `triple_king::burn_preparation` path (both shards agree) | A §5.3, B §5.3 |
| CLI arms `provision-test`, `reserve`, `recover`, `journal-empty` + root `crash-probes.py` | ~80 | harnesses for the deleted Pool path | A §6 |
| `reconstruction.rs:50-301` (`recover`, `RecoveryBinding`, `dealer_shares`, …) | 252 | twin of `acss_id::correct_polynomials` (live); dead | B §5.2-5.3 |
| `native_worker::invoke_native` legacy path (`:282-345`), *after* P9 wires `SealedNative` | ~64 | twin of `pinned_execution` (better: sealed) | A §5.3 |
| `arithmetic_reference::two_bit_addition` | 31 | twin of Lean-emitted `addition-network-2-plan.bin` | A D10 |
| `triple_king::tests::AnchorFixture` | ~64 | twin of `custody::run_anchor`; tests should run the real one | B F-B12 |
| Sequential `Engine` runtime (start/receive/progress) + `field_network_store::Store` for it | ~155 + tests | twin of `LayerEngine` (executed); keep `Engine::reserve*` as the material container | B §5.3 |
| `binding` v1 (`field_network.rs:104-120`) | ~17 | `binding_many` v2 with one inventory | B §5.3 |
| Helper copies: 5+6 Nat-cursor copies, 4 Lagrange, 7 Horner, 3 seeded-PRG, 4 `/dev/urandom` readers, 5 outbox codecs, phase codecs, `consensus_wire::Cursor` | ~300-400 | one `Cursor::nat`, one `polynomial`/`eval`, `Entropy`, a generic `Outbox` | A §5.3, B §5.3 |
| `DREGG.PRIVATE.PROTOCOL.PROGRESS\x01` (`authenticated_ingress.rs:327-388`) | ~60 | v2 (digest-only; v1 repeats the clear signing preimage, `CONSTRUCTION.txt:51`) | A §5.3 |
| `source_endpoint::{OutcomeClaim, ProgressOutcomeClaim, matches_request, admit_complete_transport_frame}` | ~270 | Dead. Lean `decodeOutcome` is the canonical side; restore only when a Host receiver exists. | A §6 |
| `asks::Asks::dealer_start` | 18 | dead; `Entropy`-routed dealing replaces it | A §5.3 |
| `check-boundary.sh` (root, hbox paths) | 16 | superseded by R8's gated `lean_exe` | A §1.2 |
| **Total** | **≈ 2,150-2,250 now; ≈ 3,400 with the two dead `source_endpoint`/`dzk_store::Store` blocks and helper merges** | | |

**Deliberately not deleted, because each serves a named surface:**
- `sealed_outbox` (R4), `authenticated_ingress`'s unused `IngressMachine` impls (R4), ACS/VABA/Gather + harness (R6), King fault localization (R6), and `recipient_seal::HidingDraft` (R3/R4): all listed in A §6 and B §6.3 as droppable, but each is the half-built side of a surface above.
- If ember rules that traffic privacy and MPC liveness leave the roadmap, those move to DELETE: about 1,269 + 70 + 4,304 + 340 + 187 lines.

**Cross-crate twin.** `pinned_execution.rs:22-55` and `resource-client/src/transport.rs:1368-1393` are near-verbatim copies (A §5.3; `tiny-crates-and-shared-root.md:47`). Keep one, as R7.

---

## 6. Size and shape

- **Total:** 26,139 lines (shard A 11,195 + shard B 14,944), plus 1,096 shared via `#[path]`. Code is about 15.2K and tests about 11K (A header: 6,687/4,508; B header: 8,492/6,452).
- **Largest code files:** `triple_king` 1,195, `sh2t_id` 1,052, `dzk` 897, `field_network` 888, `acss_id` 813, `sealed_outbox` 658, `king_store` 642 (B §6.1, A header).
- **Shape:** one library where every module is `pub` and nothing is feature-gated, so rustc reports no dead code (A §1.1). One binary arm (`worker`) reaches a thin slice: `Field`, `vaba::Set`, `correct_polynomials`, `field_network::fields` and the PrivSend wire (B summary 1). Everything else is reachable only from tests.

**DEMO-MINIMAL cut (public Hetzner demo, every week-1 surface on): zero lines of this crate.** No week-1 surface reaches it (§5.0), and it is not in the root workspace, so a root `cargo build` already omits it. Shared files: `hybrid_kem.rs` stays for resource-client. `crypto_transit.rs` stays only if traffic privacy stays (`tiny-crates-and-shared-root.md:57`). `pinned_execution.rs` (245) does not ship on the box either way.

**Deletable today without losing any surface:** the §5.3 DELETE column. That is about 2.2K lines immediately, and about 3.4K once the sealed path is wired and the helpers are merged. This is less than either shard's trim (A §6 ~3,355 within shard A; B §6.3 ~5,249 within shard B), because I moved the agreement layer, `sealed_outbox` and the ingress impls from DELETE to RESCUE under ember's rescue-first stance.

**If the MPC stays research-only with R1 adopted**, the kept core is about 8.5-9.7K lines of shard B (B §6.3) plus about 4-5K of shard A substrate (codec, `transition_journal`, `custody::Anchor`, `asks`, `private_send`, `private_output`, `recipient_seal`).

---

## 7. Deployability on a small public Linux VM

- **Build:** `cd native/private-backend && cargo build --release --locked`, a separate workspace that pulls the AWS-LC C build (`cc`, `cmake`, a C compiler). Its own lock must keep `aws-lc-sys` at 0.45.0 in step with the root lock (A §1.0).
- **Run:** the `anchor` needs a root directory and a socket. The `worker` needs Linux procfs and memfd, GNU `/usr/bin/timeout`, a mode-0600 binary `Config` that no tool writes, a recipient key WAL that no tool creates, a bootstrap exported by a `#[test]`, and a pinned verifier image that does not exist (A §7). The MPC stores need a committee of n = 3f+1 ≥ 4 hosts and authenticated confidential channels, and there are none (B §7). `deploy/` has no unit, user or directory layout for any of it.
- **Dangerous to expose:**
  - the anchor socket (burn rows, bloat to the cliff, or read the journal; flaw 6);
  - pool directories and key WALs (plaintext secrets; flaw 12);
  - the `reserve` arm (secret to file);
  - the `Cut` exits;
  - the ungated declassification `pub fn`s (§3 rank 5).
  
  None of these is network-facing, and all assume a single-tenant box.
- **A stranger on the internet can reach:** nothing. No TCP, no Host operation, no client verb.
- **A malicious enrolled member can reach:** nothing via the Host or the client. If the worker were wired, such a member could exploit flaw 5 (retired key epoch) and flaw 7 (deadlock with large requests).
- **Recommendation:** do not build this crate on the demo VM, and say so in the README. Its "MPC / FHE: executed (research)" row should read "in-process tests only (n = 4); never deployed". If an MPC exhibit is wanted, ship R1's emitted transcript as a static docuverse page. That needs no new process on the box. It is consistent with WEB-SPK-PUBLIC §7, which adds no MPC surface.

---

## 8. Questions for the Lean side (deduplicated)

1. **Spent-ness owner.** Should the physical anchor call `PrivateSuccessorCustody.reserve` / `reserveEncoded` (a Lean export or an emitted checker) instead of Rust `reserve_batch`? Is `burn` a physical anchor transition, in which case Rust must accept consumed allocations, or a Lean-only marker, in which case `Consumption.consumed` should leave the wire? (A Q4, Q5; B Q8)
2. **Correlation identity.** Which Lean def should derive King preparation row ids and checked-inventory pool ids (`triple_king.rs:216-238`, `field_network.rs:78-99`)? Is "ids omit the consumer attempt" a Lean policy anywhere? (B Q3)
3. **Native inner credential.** Is there, or will there be, a declaration producing or verifying `DREGG.JOINT.PRIVATE.INNER.REQUEST/OUTCOME\x01` (the absent `Host.JointBackendPartyInner`), so that worker admission stops being "whatever image the config hashes"? (A Q1)
4. **Declassification admission.** Which declaration (CONSTRUCTION's "ReleaseAdmission"/"allAppliedReady", under any name) gates `PrivateOutput::request_delivery`, the ACSS/Sh2t opens and reconstructions, dZK `open_proof`, and King fault localization? (A Q8, B Q5)
5. **Protocol tags and bounds.** Should `JointBackendPartyCodec.Party.bounded` admit tags 4 and 5, and add tags for Sh2t and King, or should Rust drop them? Is 262,078 the canonical raw-request bound? (A Q2, Q3; B Q6)
6. **Recipient key epoch.** Is `Compiler.CurrentRecipientRecord` the intended source of a recipient's current epoch for capsules (repair P7)? (A Q9)
7. **Journal lifetime.** Is there a retirement or pruning rule for the custody journal? Without one, 16 MiB is a hard lifetime shared by King and plan burns. (A Q6, B Q10)
8. **Plan binding.** Should a Lean producer or approver exist for `DREGG.PRIVATE.FIELD.NETWORK.BINDING\x01/\x02`, given that `Plan.bindingBytes` is opaque? (B Q4)
9. **Fixture producers.** After `212c79af`, which declaration emits `addition-network-{2,8}-plan.bin`, `public-minimal-plan.bin` and `objective-identity-network.bin`? Should `PrivateBackendBoundaryFixture.lean` and `PrivateCircuitPlanFixture.lean` become gated `lean_exe`s? (A Q10, B Q7)
10. **Protocol specification.** Is any declaration meant to state agreement or secrecy for this stack? Is `MpcSealedCellExecution` (n = 3, t = 2) its counterpart, or does `privateTurn_public_indistinguishable` have a named refinement obligation matching `private_view.rs`? (B Q1, Q2, Q9)
11. **Funded quota.** Is `EndpointPin.dispatchCapacity` the funded bound that `Receiver`'s `capacity_per_party` should equal, and which receiver checks it? (A Q12)
