# Review shard: tiny crates and shared root files

- **Shard:** "tiny crates + shared root files" (native-crate fan-out review, 2026-10-26)
- **Reader:** Opus reader, read-only. No build was run. The only commands run were `cargo metadata --no-deps --offline`, `python3 scripts/host-operations.py check` (it changes no files) and an in-memory regeneration of `native/host-operations.rs` written to scratch.
- **Date:** 2026-10-26, against the working tree at `a0db11f8` (main).

## Files covered (every file read in full)

| # | Crate / file | Rust lines | Other files read |
|---|---|---:|---|
| 1 | `native/joint-agreement-crypto/src/main.rs` | 88 | `Cargo.toml` (14), `Cargo.lock` (357, versions only) |
| 1 | `native/joint-agreement-crypto/src/session.rs` | 621 | |
| 2 | `native/compatible-upgrade-custody/src/lib.rs` | 352 | `Cargo.toml` (17) |
| 3 | `native/portable-archive/src/main.rs` | 52 | `Cargo.toml` (15), `Cargo.lock` (343, names only) |
| 3 | `native/portable-archive/src/lib.rs` | 175 | |
| 3 | `native/portable-archive/src/durable_file.rs` | 111 | |
| 4 | `native/signed-api-path/src/lib.rs` | 152 | `Cargo.toml` (6), `.gitignore` |
| 5 | `lib.rs [deleted 4f563ac5]` | 92 | `Cargo.toml` (11), `Cargo.lock` (111) |
| 6 | `native/launch-gate/` | 0 | `Cargo.toml` (18), `Cargo.lock` (7); its only source is `deploy/grain-host/launch-gate.rs` (450 lines), read in full |
| 7 | `main.rs [deleted 4f563ac5]` | 96 | `Cargo.toml` (31), `.config/nextest.toml` (6), `README.md` (36), `OBJECTIVE-ONLY-MIGRATION.txt` (57), `QUALIFICATION-R32.txt` (101), `QUALIFICATION-R33.txt` (71), `provision.py` (46), `dependencies.lock.json` (380, summarised), `test_provision.py [not in tree]` (30) |
| 7 | `config.rs [deleted 4f563ac5]` | 104 | |
| 7 | `legacy_config.rs [deleted 4f563ac5]` | 64 | |
| 7 | `full_degree_challenger.rs [deleted 4f563ac5]` | 146 | |
| 7 | `masking_budget.rs [deleted 4f563ac5]` | 32 | (the brief left this file out; it is a `mod` of `main.rs`) |
| 7 | `artifact_binding.rs [deleted 4f563ac5]` | 36 | |
| 7 | `bounded_commitment.rs [deleted 4f563ac5]` | 55 | |
| 7 | `masking_observations.rs [deleted 4f563ac5]` | 88 | |
| 7 | `quotient_masking.rs [deleted 4f563ac5]` | 46 | |
| 7 | `short_trace_disclosure.rs [deleted 4f563ac5]` | 115 | |
| 8 | `lib.rs [deleted 52c252e3]` | 222 | `Cargo.toml` (20), `Cargo.lock` (7), `README.md` (31), `fixtures/hyperdocument-link-recovery-v1.bin` (14 bytes) |
| 8 | `main.rs [deleted 52c252e3]` | 71 | |
| 8 | `forward_link_e2e_bench.rs [deleted 52c252e3]` | 314 | |
| 8 | `lifecycle.rs [deleted 52c252e3]` | 106 | |
| 9 | `native/crypto_transit.rs` | 380 | |
| 9 | `native/host-operations.rs` | 376 | `scripts/host-operations.py` (318) |
| 9 | `native/hybrid_kem.rs` | 471 | |
| 9 | `native/pinned_execution.rs` | 245 | |
| | **Total Rust in the shard** | **4,610** | plus 450 lines of `deploy/grain-host/launch-gate.rs`, read as the source of crate 6 |

Lean and cross-reference reading done to judge the seams: `Compiler/GenericSimplexNative.lean` (334, in full), the headers of `Kernel/NativeJointAgreement.lean` and `Kernel/JointReservation.lean`, `Verify/GenericSimplexNativeHarness.lean` lines 1-60, `Verify/NativeJointSourceFixture.lean` (helper call sites), `Compiler/PortableContinuationArchiveIO.lean` lines 1-140, `Compiler/PortableParticipantPinIO.lean` lines 30-70, `Kernel/ApplicationSpkPackageIdentity.lean` lines 60-245, `Host/BendTraceIR2Emit.lean` header, the headers of `Assurance/HyperdocumentLinkSqliteTransactionalStore.lean` and `Assurance/HyperdocumentLinkClientLocalFileCutover.lean`, `native/hyperdocument-link-sqlite-store/README.md` and the header of its `src/lib.rs`, `native/resource-client/src/private.rs:1185-1245` (the ML-KEM known-answer tests), `native/resource-client/src/transport.rs:1340-1460` (a sealed-execution twin), `native/private-backend/src/native_worker.rs:340-420`, `deploy/candidate/package.py:55-100`, `protocol/HOST-OPERATIONS.md`, `Host/ClientConsentCore.lean:369-590` (grep).

## Executive summary (15 lines)

1. Of the eight crates, only three ship in a candidate. `compatible-upgrade-custody` and `signed-api-path` are linked into `mini`, `grain-runtime` and `spk-host`. `launch-gate` is a test-fixture role (`deploy/candidate/package.py:78,90`). The shared root files `hybrid_kem.rs`, `crypto_transit.rs` and `host-operations.rs` are compiled into `mini`.
2. `native/hyperdocument-link-store` **does not build in this tree**. Its manifest has no `[workspace]` table and the root workspace (added `295cab11`, 2026-10-08) does not list it, so `cargo metadata` refuses it. Both scripts that drive it (`test-hyperdocument-link-local-store.sh [deleted 52c252e3]:15`, `run-forward-link-e2e-benchmark.sh [deleted 52c252e3]:49`) are therefore broken. It is the superseded twin of the workspace member `hyperdocument-link-sqlite-store`.
3. `native/bend-ir2-proof` cannot build in a clean checkout either. `dregg-circuit` is a path dependency on `../bend-proof-deps/bread/circuit`, which does not exist; it is a symlink that `provision.py:34-40` would create to an external breadstuffs slice of 374 pinned files. It survives the 2026-10-04 upstream-Bend deletion only as an offline conformance harness fed by synthetic Lean fixtures. No Objective Bend producer feeds it (`README.md:36`, `OBJECTIVE-ONLY-MIGRATION.txt:53-55`).
4. `native/pinned_execution.rs` is unwired. Its one includer, `private-backend`, uses it only in `SealedNative::new` (`native_worker.rs:356`) and `receive_sealed` (`:398`), and neither has a caller anywhere in the tree. Its live twin is `resource-client/src/transport.rs:1368-1393` (`sealed_snapshot`), the same memfd-seal mechanism without the size bound.
5. `native/portable-archive` is reached only from Lean modules imported by `ResearchWip.lean:77-85`. It has no `lean_exe`, no systemd unit and no journey. It is research.
6. `native/joint-agreement-crypto` is the real stdio helper of the Lean Simplex replica (`Compiler/GenericSimplexNative.lean:16-88`), reached through the `minidregg-four-source-fixture` `lean_exe` (`lakefile.toml:209-213` (`name` at `:212`)). No unit for it exists under `deploy/` (`docs/agreement/CUTOVER.md:64-67`: "units not written here"). I checked every one of the ten ops of its wire, byte for byte: Rust and Lean agree.
7. Its TCP listener is unauthenticated and unbounded. It runs one thread per connection with no cap (`session.rs:288-291`). It allocates up to 16 MiB per frame from a peer-supplied length (`:268-272`). Its queue is bounded at 16,384 frames, not bytes (`:34`, `:298`), and a full queue silently drops (`:296-300`). A stranger who can reach the port can exhaust memory or starve honest frames.
8. Silent loss in the same helper: a hostname in `--peer` never connects (`session.rs:317` parses only a `SocketAddr`), yet `OP_SEND` still answers success (`:433-434`). A checkpoint `replace` keeps no segment when `<journal>.upto-N` already exists (`:224-226`), so retained history can silently lose a segment.
9. `hybrid_kem.rs` claims "Every key exchange in `native/` goes through here … There is no pure-X25519 … path" (`:3-15`). `resource-client/src/channel.rs:22-24,207,236` is a pure-X25519 sealing path. The claim is false.
10. `hybrid_kem.rs` pins the AWS-LC symbol `aws_lc_0_45_0_EVP_PKEY_keygen_deterministic` (`:241`). Both includers pin `aws-lc-sys =0.45.0`, so they agree; `sha3` differs (0.10.9 in the workspace vs 0.10.8 in private-backend). The FIPS 203 seed-layout known-answer test lives only in `resource-client/src/private.rs:1220-1235`, so the private-backend copy is never checked against it.
11. `host-operations.rs` is current: an in-memory regeneration is byte-identical, and `check` passes (184 active, 2 reserved, 113 public, 69 operator-only, 20 client constants). Consumers still mostly bypass it: 159 `invoke(...)` call sites in 39 files pass a literal request number, and the generated constants are used in one file only (`member_app.rs:8-11`). The registry check does not scan those literals (`protocol/HOST-OPERATIONS.md:57-59`).
12. Rust semantic decisions in this shard are few. `compatible-upgrade-custody` decides, with no Lean counterpart, which config fields a "compatible" image upgrade may change (`lib.rs:185-248`), and it trusts recorded audit exit codes (`:269-270`). This is operator custody policy, not member authority, but nothing in Lean refuses it. `signed-api-path` mirrors a Lean gate (`Kernel/ApplicationSpkPackageIdentity.lean:165-221`): its prefix grammar is a hand-written twin of `validApiPrefix`.
13. `launch-gate` (`native/launch-gate/Cargo.toml:1-3`) is a deliberate build manifest, not an abandoned crate. It builds the unmoved `deploy/grain-host/launch-gate.rs`. That file hard-codes `O_NOFOLLOW = 0o400000` (`:13`), which is `O_LARGEFILE` on aarch64 Linux. A build for an ARM VM (such as Hetzner CAX) would silently lose no-follow on gate files.
14. A minimal demo keeps about 1,370 Rust lines: `compatible-upgrade-custody` 352, `signed-api-path` 152, `host-operations.rs` 376, `hybrid_kem.rs` 471, plus the 18-line `launch-gate` manifest. It drops 2,879 Rust lines outright: joint-agreement 709, portable-archive 338, bend-proof-entropy 92, bend-ir2-proof 782, hyperdocument-link-store 713, `pinned_execution.rs` 245. A further 380 (`crypto_transit.rs`) go if traffic privacy leaves the demo.
15. The `#[path]` shared-source pattern should become a crate. The obvious home is the existing workspace member `native/mini-sdk`. Then the known-answer tests travel with the code, both trees compile one feature set, and the sealed-execution twin collapses into one implementation.

---

# Chapter 1. `native/joint-agreement-crypto` (709 Rust lines)

Package `mini-joint-agreement-crypto` (`Cargo.toml:2`). It is not a workspace member: it has its own `[workspace]` table (`Cargo.toml:5`) and its own `Cargo.lock`.

## 1.1 What it is and does

**`src/main.rs` (88 lines).** This is the CLI entry. Its module doc (`main.rs:1-2`) says it "does not parse application candidates, grant authority, or count quorums". Shared items:
- `CTX = b"MiniJointAgreementV1"` (`:15`). It is the ML-DSA context string and the HMAC prefix.
- `MAX_FRAME = 16 MiB` (`:16`).
- `fresh()` (`:17-26`) creates a key file with `create_new` and mode 0600, then `write_all` and `sync_all`. It does not fsync the parent directory.
- `mac()` / `verify_mac()` (`:27-44`) compute HMAC-SHA256 over `CTX || body` with a 32-byte key. Verification is constant-time through `verify_slice`.

`run()` (`:45-64`) has three subcommands:
- `keygen PK SK` makes an ML-DSA-65 pair through `fips204::ml_dsa_65::try_keygen` (`:48-52`).
- `mac-keygen KEY` writes 32 bytes from `getrandom` (`:53-57`).
- `session ...` delegates to `session::run` (`:60`).

The tests (`:71-88`) cover only a signature tamper and a MAC sender/recipient tamper.

**`src/session.rs` (621 lines).** A long-lived per-replica helper (`:1-14`). The Lean participant is its only client. It speaks a strict request/response protocol on stdin/stdout:
- request = `op:u8, len:u32be, body` (`:6`; the reader is at `:493-504`)
- response = `status:u8, len:u32be, body`, where status is 0 ok, 1 negative, 2 error (`:7`; written at `:509-512`)
- `MAX_REQUEST = 1 GiB` (`:48`)

The ten ops (`:37-46`):

| op | name | body (Rust parse) | reply |
|---|---|---|---|
| 1 | `OP_SIGN` | `blob frame` (`:363-364`) | status 0 + raw ML-DSA-65 signature (`:366-368`) |
| 2 | `OP_VERIFY` | `blob pk, blob frame, blob sig` (`:371-372`) | 0 valid / 1 invalid; a malformed pk or signature also gives 1 (`:373-379`) |
| 3 | `OP_MAC` | `u32 peer, blob frame` (`:382-384`) | 0 + 32-byte tag; status 2 if the peer has no key (`:354-356`) |
| 4 | `OP_VERIFY_MAC` | `u32 peer, blob frame, blob tag` (`:389-391`) | 0 / 1; an unknown peer gives 1 (`:392-396`) |
| 5 | `OP_OPEN` | `u64 observed, u64 valid` (`:404-406`) | 0; status 2 if the journal is already open or not configured (`:399-402`) |
| 6 | `OP_APPEND` | `u64 expected, blob frame` (`:422-426`) | 0 appended / 1 length conflict |
| 7 | `OP_SEND` | `u32 peer, blob packet` (`:429-436`) | 0 even when the outbound queue is full (`:434`) |
| 8 | `OP_RECV` | `u32 max` (`:439-447`) | 0 + `u32 count` + count blobs |
| 9 | `OP_CREATE` | `blob bytes` (`:408-410`) | 0 |
| 10 | `OP_REPLACE` | `u64 expected` + the rest as the image (`:416-419`) | 0 replaced / 1 conflict |

A `blob` is `len:u32be bytes`, capped at `MAX_FRAME` (`:110-116`). Trailing bytes are refused (`:120-126`), except in `OP_REPLACE`, which takes `rest()` (`:117-119`, `:417`).

Data model:
- `Config` (`:50-56`) holds the paths and addresses from the flags `--sk`, `--journal`, `--listen`, `--peer I=ADDR` and `--pair I=KEYFILE`. Duplicates are refused (`:58-90`).
- `Session` (`:344-351`) holds the loaded `dsa::PrivateKey`, the pair keys (`HashMap<u32, Vec<u8>>`), the optional `Journal`, outbound `SyncSender`s and the inbound queue.

The journal state machine, `struct Journal` (`:135-141`):
- **Locking.** `lock_for` (`:143-154`) takes a non-blocking exclusive `flock` on `path.with_extension("lock")` and holds it for the session's life.
- **`open(observed, valid)`** (`:166-181`): locks, then checks that the file length still equals the length the Lean reader observed. It truncates a torn tail down to `valid`, the prefix Lean decoded.
- **`create(bytes)`** (`:183-195`): `create_new`, mode 0600, write, fsync, parent-directory fsync.
- **`append(expected, frame)`** (`:243-262`): compare-length-and-append with `sync_data`. Any I/O failure sets `poisoned`, and every later write refuses with "reopen" (`:244-246`).
- **`replace(expected, image)`** (`:203-239`), the checkpoint: write `path.with_extension("checkpoint")` and fsync it, hard-link the old image to `<journal>.upto-<length>` if that name does not already exist, rename the staged file over the journal, fsync the directory. A failure after the link poisons the session.

Transport:
- `listen()` (`:285-306`) binds a `TcpListener` and spawns one thread per accepted connection. Each thread reads frames of `len:u64be bytes` (`:265-275`) into a shared `VecDeque`, up to `INBOUND_LIMIT = 16384` frames, and drops beyond that (`:296-300`).
- `sender()` (`:311-342`) keeps one thread per peer with one persistent connection. Each frame gets two attempts; reconnects use a 2 s connect timeout and a 10 s write timeout; a frame that fails both attempts is dropped.
- The outbound channel is a `sync_channel(OUTBOUND_LIMIT = 4096)` (`:35`, `:476`).

Processes, files and env: stdin/stdout; the `--journal` file plus `.lock`, `.checkpoint` and `.upto-N` siblings; key files; TCP sockets. It reads no environment variables.

## 1.2 What it assumes of its surroundings

- **No Host protocol operations.** It is not a Host client. Its counterpart is `Compiler/GenericSimplexNative.lean`: `spawnHelper` at `:72-88`, the op constants at `:22-31`, encoders at `:33-41`.
- **Seam cross-check, op by op.** Lean encodes exactly what Rust parses:
  - SIGN: `blob frame` (`GenericSimplexNative.lean:122`).
  - VERIFY: `blob pk ++ blob frame ++ blob signature` (`:119`). An exception maps to `false` (`:119-120`).
  - MAC: `u32 peer ++ blob frame`, with a tag-size check of 32 (`:94-97`).
  - VERIFY_MAC: `u32 peer ++ blob frame ++ blob tag` (`:99-100`).
  - SEND: `u32 peer ++ blob packet`, throwing on a nonzero status (`:102-104`).
  - RECV: `u32 max`, then the reply parsed as a count and blobs (`:107-116`).
  - OPEN: `u64 bytes.length ++ u64 valid` (`:182`).
  - APPEND: `u64 expected ++ blob frame`, where status 0 means `.durable`, otherwise `.conflict`, and an exception means `.uncertain` (`:146-151`).
  - REPLACE: `u64 expected ++ image`, with no blob prefix, matching Rust's `c.rest()` (`:152-157`).
  - CREATE: `blob (Log.encode ...)` (`:160-165`).
  - Status 2 makes Lean throw with the helper's text (`:81-83`).
  - **Verdict: the two sides agree on bytes, fields and status codes.**
- **Lean-side robustness gap.** `Helper.receive` parses the reply with `readBE`, which uses `ByteArray.get!` and defaults to 0, and never checks bounds (`:107-116`). Rust always writes a well-formed reply (`session.rs:443-446`), so this is safe only while the helper is honest.
- **OS.** Unix only (`std::os::unix::fs::OpenOptionsExt`, `main.rs:6`). It needs `flock` (fs2), hard links and rename on one filesystem. It does not use SO_PEERCRED, seccomp or cgroups.
- **Network.** Plain TCP between replicas, with no TLS. Authentication is by pairwise HMAC inside Lean (`GenericSimplexNative.lean:228-252`). Confidentiality is none.
- **Who runs it.** Only Lean code. `Verify/NativeJointSourceFixture.lean:63` sets `binary := helpers.agreement` and calls `keygen` and `mac-keygen` at `:142-149`. That module is the root of the `lean_exe` `minidregg-four-source-fixture` (`lakefile.toml:209-213` (`name` at `:212`)). `Verify/GenericSimplexNativeHarness.lean:33-38` is the test harness. No script or unit under `deploy/` or `scripts/` names the binary: `git grep` finds only `.spw` maps, docs and the Lean file. `docs/agreement/CUTOVER.md:64-67` describes the supervision units and says they are "units not written here".
- **The Kernel modules are abstract.** `Kernel/NativeJointAgreement.lean` declares a `compareAppend`/`read`/`emit` IO interface (`:151-168`) and never spawns this helper. `Kernel/JointReservation.lean` has no IO.

## 1.3 Does it decide anything semantic?

Essentially no, and it defers correctly:
- **Quorum, delivery and authentication** are all in Lean. Inbound frames are queued verbatim (`session.rs:13-14`); `authenticate` in Lean checks the MAC, the sender index and the COMMIT signature (`GenericSimplexNative.lean:228-252`).
- **Journal validity** is Lean's. Lean decides the valid prefix (`scanLog`, `GenericSimplexNative.lean:175-177`). Rust truncates only to the length Lean names, and only if the file did not move between Lean's read and Rust's lock (`session.rs:172-179`).
- **Ordering and retry.** The compare-length CAS is physical. A conflict is status 1, and Lean maps it to `.conflict` (`:150`).

One judgement call is made in Rust: dropping inbound frames when the queue is full (`session.rs:296-300`) and dropping outbound frames on a full channel (`:434`) or after two failed attempts (`:315-339`). The comments justify this as "the sender's retry rounds resend every retained obligation". That is a liveness decision, not a safety one; Lean still never admits an unauthenticated frame.

## 1.4 Flaws noticed

1. **Unauthenticated memory and thread DoS on the listener.**
   - `listen` spawns one OS thread per TCP connection with no cap (`session.rs:288-291`).
   - `read_frame` trusts the 8-byte length prefix up to 16 MiB and allocates `vec![0; n]` before any data arrives (`:268-272`).
   - The queue is bounded by count (16,384), not bytes (`:34`, `:298`).
   - Scenario: anyone who can reach `--listen` sends 16,384 frames of 16 MiB of junk, and the helper holds 256 GiB. On a 4 GB VM it dies after roughly 4 GB of attacker upload.
   - A cheaper attack keeps the queue full of junk. Honest frames are then dropped at `:298-300`; Lean drains a budget per poll (`GenericSimplexServe.lean:171`) and the attacker refills it. Safety holds, liveness is lost.
   - Thousands of idle connections each pin a thread. There is no read timeout on accepted sockets.
2. **A hostname peer silently never connects.** `sender` does `address.parse().ok()` as a `SocketAddr` (`session.rs:317`). For `replica1:9000` this is `None`, so the thread sleeps 200 ms and retries twice per frame, then drops the frame (`:327-330`). Meanwhile `OP_SEND` returns status 0 for every packet (`:433-434`). `Verify/NativeJointSourceFixture.lean:249-259` documents PEERS as "host:port". A DNS name yields a mesh that never talks, with no error anywhere. This is a fail-open of liveness: the refusal is not loud.
3. **A checkpoint segment can be silently lost.** `replace` hard-links the old image to `<journal>.upto-<length>` only `if !segment.exists()` (`session.rs:221-226`). The image length can repeat. Example: replace at 8 gives image `snap` (4), then an append of 4 gives length 8 again, and the next replace finds `.upto-8` already present (from the first segment), so the second pre-checkpoint image is not preserved. The test `replace_is_length_checked_atomic_and_keeps_the_segment` (`:540-558`) never replaces twice at the same length. Lean's `audit-journal` "replays the retained segment chain" (`docs/GENERIC-SIMPLEX-NATIVE.md:165`) and would then see a gap or a stale segment. The fix is to name segments by digest or generation, or to refuse when the name exists with different bytes.
4. **Staging and lock naming by `with_extension`.** The lock is `path.with_extension("lock")` (`:150`) and the staging file is `path.with_extension("checkpoint")` (`:211`). Two journals in one directory that differ only by extension (`journal.a`, `journal.b`) share a lock file, and the second writer gets a false "held by another writer". The staging file is opened with `create(true).truncate(true)` and without `O_NOFOLLOW` (`:212-218`): a same-user symlink planted at `agreement.checkpoint` redirects the write. The fixture uses `agreement.log` (`NativeJointSourceFixture.lean:57`), so neither bites today.
5. **Key handling.**
   - Key files are read with `fs::read` and no permission or owner check (`session.rs:457-468`); a world-readable key is accepted silently.
   - The `fs::read` buffers for the signing key and the pair keys are not zeroized. Pair keys live in plain `Vec<u8>` (`:346`, `:468`).
   - `keygen` writes `sk.into_bytes()` from a stack array that is not zeroized (`main.rs:49-51`). `fips204` 0.4.6 itself derives `ZeroizeOnDrop` for its key types (checked in the registry source, `types.rs:19,35,52`).
   - `fresh()` does not fsync the parent directory (`main.rs:17-26`), so a crash right after keygen can lose the key file's directory entry.
6. **`OP_REPLACE` reads up to 1 GiB per request** (`:48`, `:499-504`). This is bounded and intended, but the helper allocates `vec![0; n]` from the header before reading (`:503`).
7. **The Lean `close` is `child.kill`** (`GenericSimplexNative.lean:85-87`). This is a handle-based kill, which is fine. A kill mid-`append` leaves a torn tail that the next `open` truncates by Lean's classification (`session.rs:176-179`), which is the intended recovery.
8. **Mutex poisoning panics.** `inbound.lock().unwrap()` (`:295`, `:441`) panics if a reader thread ever panicked while holding the lock. Today nothing inside the critical section panics.

## 1.5 Unwired / undone

- No unit, journey or candidate role ships this binary (`deploy/candidate/package.py:55-90` has no agreement role). README's Honest state says "Agreement mesh … executed; four replicas on one host, one failure domain".
- No TODO, FIXME, `unimplemented!` or `#[allow(dead_code)]` markers.
- **Durable-byte CAS family.** This journal is a fourth, independent durable-byte compare-and-set implementation in the tree. The others are `portable-archive/src/durable_file.rs:42-73`, `hyperdocument-link-store/src/lib.rs:142-213` and the workspace `hyperdocument-link-sqlite-store`. `docs/PORTABLE-CONTINUATION.md:28-31` says "Agreement's owner is adding a storage-only helper selector"; that never happened, and the helper journals itself.
- **Tests that test.** The four session tests exercise real files and real TCP (`session.rs:520-620`). `persistent_transport_delivers_verbatim_frames` (`:560-580`) binds an ephemeral port after dropping a probe listener, which is a small race but acceptable.

## 1.6 Size and shape

| File | Lines | Tests | Code |
|---|---:|---:|---:|
| `src/main.rs` | 88 | 18 (`:71-88`) | 70 |
| `src/session.rs` | 621 | 106 (`:516-621`) | 515 |
| **Total** | **709** | **124** | **585** |

Minimal for the demo: drop the whole crate (709 Rust lines and a 357-line `Cargo.lock`) unless the agreement mesh is part of the Hetzner demo. If the mesh is kept, all of it is needed; nothing here is dead.

## 1.7 Deployability on a small public Linux VM

- **On the box:** the `mini-joint-agreement-crypto` binary, built separately because it is outside the workspace; one replica directory per replica, mode 0700 (`NativeJointSourceFixture.lean:46`); the committee and pair keys; one TCP port per replica; and the four `serve-replica` units, which do not exist yet (`docs/agreement/CUTOVER.md:64-67`).
- **Dangerous to expose:** the `--listen` port. Bind it to loopback or a private network and firewall it from the internet (flaw 1).
- **A stranger** can fill memory and starve delivery, but cannot forge admitted traffic: Lean checks the HMAC (`GenericSimplexNative.lean:241-243`).
- **A malicious enrolled member** has no route to this helper; it serves replicas only.

## 1.8 Questions for the Lean side

1. After `journalStorage` returns `.uncertain` (`GenericSimplexNative.lean:151`, `:157`), the Rust session is poisoned (`session.rs:256-258`). Which declaration calls `Runtime.reopen` (`GenericSimplexNative.lean:274-276`) so the replica does not keep failing? Is `GenericSimplexIO` lines 652-684 ("the owner must …") the whole contract?
2. Does `audit-journal` in `Verify/NativeJointSourceFixture.lean` verify that each `.upto-N` segment is a prefix-consistent predecessor, so that the segment collision in flaw 3 is detected rather than silently accepted?
3. Is the `GenericSimplexServe` inbound budget (`Compiler/GenericSimplexServe.lean:171`) sized with a hostile flooder in mind, or does Lean assume a private network?

---

# Chapter 2. `native/compatible-upgrade-custody` (352 Rust lines)

Package `minidregg-compatible-upgrade-custody`, a workspace member (root `Cargo.toml:3`). It has one feature, `fixture-os` (`Cargo.toml:8-11`).

## 2.1 What it is and does

`src/lib.rs` (352 lines) is a library for "trusted local root admission for a compatible Mini image transition", which "authenticates operator custody and exact pins, not a portable history proof" (`lib.rs:1-2`).

Data model, all serde:
- `Admission` (`:23-39`): `protocol`, optional `managementSocket`/`publicSocket`, `transaction` directory, `phase`, `identity {domain, semantics, seed}`, `source`/`target: Candidate`, `audit {source.exit, target.exit}`, `configTransition {changedFields}` (`deny_unknown_fields`), and `spkProfiles: Vec<ProfilePin>` (`deny_unknown_fields`).
- `Candidate` (`:46-54`): a free-form `manifest`, `configPath`, `configSha256`, `profile` and `config` as JSON values.

Functions:
- `root_owner(uid)` (`:80-86`): true for uid 0. Under `fixture-os` it is also true for the current euid.
- `canonical(path)` (`:87-95`): absolute, components only `RootDir` or `Normal`, no `//`, no trailing `/`, no `/./`.
- `root_ancestors(path)` (`:97-118`): every ancestor directory must be a real directory owned by root, with neither group- nor other-write.
- `root_bytes(path, max)` (`:120-144`): opens with `O_NOFOLLOW`, then requires (via fstat) a regular file owned by root, `nlink == 1`, no group/other write, and a length between 1 and `max`. It reads at most `max + 1` bytes and detects a size change.
- `root_pin(path, digest)` (`:148-168`): ancestors are root custody, `symlink_metadata` is a root-owned regular file, then it hashes the file in 64 KiB chunks.
- `image(manifest, role)` (`:169-184`): reads `manifest[role]` (a path) and `manifest.sha256[role]`, both canonical.
- `validate_config_transition` (`:185-248`):
  - `changedFields`, sorted, must equal exactly `["signatureBinary", "storageBinary"]`.
  - The target's `storageBinary`/`signatureBinary` must equal the manifest's `store`/`verifier` paths.
  - With those two keys removed, the source and target configs must be equal as JSON, compared with `arbitrary_precision` so large naturals do not collapse (test at `:326-333`).
  - Both profiles' `domain`, `semantics` and `expectedSeed` must equal the admission identity, as decimal strings.
  - The target config's `domain` and `expectedSeed` must equal the identity.
- `validate_topology` (`:250-262`): either both sockets are absent, or both are present, canonical and distinct.
- `load_evidence(path)` (`:265-278`): `root_bytes` capped at 4 MiB; `protocol == "mini-compatible-admission-v1"`; `phase == "kernel-serving-service-stopped"`; both audit exit codes 0; and the file must sit at `transaction/compatible-admission.json`.
- `load(path)` (`:281-294`): `load_evidence`, then re-read the current target config under root custody, compare its hash and its JSON, and `root_pin` the host, store and verifier images.

Files touched: the root-owned admission JSON, the target config and the three image files. It reads no environment variables.

## 2.2 What it assumes of its surroundings

- **Linux/Unix ownership semantics:** uid 0 owns `/`, `/var`, … and nothing on the path is group-writable. The macOS `/tmp` symlink makes the test at `:335-338` pass for a different reason (not a directory) than on Linux (mode 1777).
- **Dependents.** `git grep`:
  - `native/resource-client/Cargo.toml:18`; used in `src/session_reenroll.rs:172-313`.
  - `native/grain-runtime/Cargo.toml:26`; used in `config_migration.rs:6`, `controller_write_scopes.rs:9,19`, `quiescence_transport.rs:7`, `systemd_manager.rs:5`.
  - `native/spk-host/Cargo.toml:18,21`; used in `broker_endpoint.rs:3`, `broker_runtime_adoption.rs:5`, `grain_profile_upgrade.rs:10`, `os.rs:6` (re-exports `root_owner`), `volume_helper.rs:13`.
  - Docs: `deploy/spk-host/PROFILE-UPGRADE.md:5,46`, `deploy/spk-host/BROKER-RUNTIME-UPGRADE.md:36`.
- **Who writes the admission JSON?** Some operator upgrade tool. No Lean writer exists: `git grep mini-compatible-admission-v1` finds only this crate.
- **No Host protocol operations.**

## 2.3 Does it decide anything semantic?

- **It IS a decision with no Lean counterpart: which config changes count as "compatible"** (`lib.rs:185-248`). Rust alone decides that only the two helper paths may change and that identity, domain, semantics and seed must be preserved. The blast radius is that a looser rule would let an operator restart the Host image against a changed world identity, and Rust would vouch for it. This is operator-custody policy, not member authority; the operator controls root anyway. Still, under ATLAS law 13 a Lean `CompatibleTransition` predicate exported to Rust is where it belongs. No such Lean module exists (grep for `compatible-admission` finds no `.lean` file).
- **It trusts recorded audit results** (`:269-270`). `audit.source.exit == 0 && audit.target.exit == 0` is accepted from the root-owned JSON. The audit itself is not re-run. Trust is anchored in root custody of the file, not in a Lean verdict.
- **It correctly defers or doesn't claim:** the module doc disclaims any portable history proof (`:2`), and `spk_profiles` is parsed but not interpreted here (`:38`). Callers such as `spk-host/src/grain_profile_upgrade.rs` own that.

## 2.4 Flaws noticed

1. **`fixture-os` feature unification hazard.** `root_owner` accepts the current euid as root when `fixture-os` is on (`lib.rs:81-84`). The feature is enabled through `spk-host`'s `fixture-os` (`native/spk-host/Cargo.toml:18`). Cargo unifies features per package across one build. A workspace build such as `cargo build --workspace --features minidregg-spk-host/fixture-os`, or `--all-features`, compiles the custody crate once with `fixture-os` on, and `mini` (`resource-client`) and `grain-runtime` then link a root check that accepts the invoking user. Nothing refuses this at compile time or at run time: there is no `compile_error!` and no marker in the binary. Today the fixture build is described only in a comment (`scripts/spk-platform/fixture-v4.sh:47`), with no cargo line shown. **Concrete hazard:** a candidate built with `--all-features` ships custody that treats the service account as root.
2. **`root_pin` has a TOCTOU between the `symlink_metadata` check and `File::open`, which follows symlinks** (`:150-154`). Only root can swap a file under root-custody ancestors, so this is not exploitable by non-root users. It also does not check `nlink`, unlike `root_bytes` (`:129`).
3. **`validate_config_transition` never checks the source helper paths against the source manifest.** `image()` is only called on `target.manifest` (`:202`). `source.manifest` is parsed and unused (`:49`). This is harmless for upgrade direction but inconsistent.
4. **`load_evidence` requires `path == transaction.join("compatible-admission.json")` by byte equality of `PathBuf`s** (`:271`). A path given with a different but equivalent spelling is refused, which is fail-closed and fine.
5. **Tests.** Four tests (`:309-351`) exercise only the pure validators. `root_bytes`, `root_pin` and `load` have no positive test, since they need root-owned paths; they are tested indirectly, if at all, by consumers.

## 2.5 Unwired / undone

It is reachable from deployed binaries: `mini` (`session_reenroll.rs:242,285`), `grain-runtime` and `spk-host`. `spkProfiles` validation lives in consumers. No markers, no twins inside this crate. `canonical()` is reused as a general path predicate (`grain-runtime/src/controller_write_scopes.rs:9,19`, `session_reenroll.rs:218-219`), which makes this crate a de facto "path custody" utility beyond upgrades.

## 2.6 Size and shape

| File | Lines | Tests | Code |
|---|---:|---:|---:|
| `src/lib.rs` | 352 | 57 (`:296-352`) | 295 |

Minimal for the demo: keep it all; three shipped binaries link it. Possible later simplification: move `canonical`, `root_ancestors` and `root_bytes` into `mini-sdk` (a general custody crate already exists, `resource-client/Cargo.toml:15-16`) and leave only the upgrade predicate here, ideally Lean-emitted.

## 2.7 Deployability on a small public Linux VM

- **On the box:** a root-owned `/var/lib/mini/upgrades/<tx>/compatible-admission.json` (the path shape from `spk-host/src/broker_runtime_adoption.rs:551`), root-owned images at canonical paths, and a non-group-writable path chain.
- **Operator-configured:** everything in the admission.
- **Exposure:** none to strangers or members. This is local root custody only.
- **Danger:** a `fixture-os` build reaching the box (flaw 1).

## 2.8 Questions for the Lean side

1. Does the Lean Host refuse at startup a config whose `domain` or `expectedSeed` differs from the world it opens (which declaration in `Host/Main.lean`)? If yes, Rust's identity check (`lib.rs:218-246`) is a mirror; if not, it is the only gate.
2. Should "compatible transition" be a Lean predicate over (source config, target config, manifest), so the field allowlist is emitted rather than hand-written?

---

# Chapter 3. `native/portable-archive` (338 Rust lines)

Package `minidregg-portable-archive` (`Cargo.toml:2`). It is not a workspace member: `[workspace]` table at `Cargo.toml:5`, own `Cargo.lock`.

## 3.1 What it is and does

**`src/durable_file.rs` (111 lines)**
- `private_file(path)` (`:10-17`): opens with `O_NOFOLLOW`; requires a regular file owned by the euid, `nlink == 1`, no group or other bits.
- `equal_files` (`:19-37`): compares two files byte for byte from offset 0 over a common length using `read_exact`, then rechecks both lengths at the end.
- `compare_replace(path, expected, next)` (`:42-73`), the CAS:
  1. Take an exclusive `flock` on `path.with_extension("lock")`; the lock file itself must pass the custody checks.
  2. Compare the current file with `expected`; unequal returns `Ok(false)`.
  3. Copy `next` into `.portable-<16 random bytes hex>`, fsync it, and re-compare the copy with `next`.
  4. Rename the copy over `path` and fsync the directory.
  - `compare_replace_inner(..., lose_reply=true)` (`:46`, `:71`) returns an error after the durable rename, for tests.

**`src/lib.rs` (175 lines)**
- `CHUNK_BYTES = 65536` (`:14`).
- `Chunk {sha256, bytes}` and `FileManifest {protocol, coordinate, bytes, sha256, chunks}` (`:16-28`), both `deny_unknown_fields`.
- `owned_directory` (`:32-36`): a real directory owned by the euid with no group/other bits. `initialize` creates it 0700 and fsyncs the parent (`:37-41`).
- `exact_chunk(root, chunk)` (`:42-51`): reads `root/<sha256>` through `private_file`, checks length and hash. The hash must be 64 lowercase hex characters, which also prevents path traversal.
- `repair_chunk` (`:54-63`): accepts an incoming file only if its hash and length match the selected chunk.
- `retain_chunk` (`:64-82`): a per-chunk lock file `<sha>.lock`. If the chunk is already exact, done. Otherwise it checks the custody of any existing corrupt file, then stages to `.chunk-<nonce>`, renames and fsyncs.
- `capture(root, coordinate, source)` (`:85-102`): reads the source in 64 KiB chunks, retains each chunk, computes the aggregate SHA-256, re-reads the whole file to detect change, builds the manifest and verifies it.
- `check_manifest` (`:103-111`): protocol `mini-portable-artifact-chunks-v1`; coordinate of 1 to 4096 bytes; every chunk full except the last; total equals `bytes`.
- `verify` (`:112-116`).
- `read_range` (`:119-133`): at most one chunk's worth of bytes per call, possibly spanning two chunks.
- `restore_new(root, manifest, target)` (`:136-146`): `create_new` target, writes the chunks, checks the aggregate, fsyncs file and parent, then reads the file back.

**`src/main.rs` (52 lines).** CLI subcommands: `cas`, `cas-lose-reply`, `capture`, `verify`, `restore-new`, `read-range`, `repair-chunk` (`:25-51`). `write_exact` (`:8-21`) makes the output idempotent: if the output exists it must be byte-identical and pass custody checks. Errors print `portable custody refused: …` and exit 1 (`:52`). Stdout carries `durable`/`conflict`/`retained`/`retrieved` (`:27,35,37,38,41,46`).

## 3.2 What it assumes of its surroundings

- **Unix:** `geteuid`, `flock`, `O_NOFOLLOW` taken from `libc`, so correct on every architecture.
- **Callers (Lean only):**
  - `Compiler/PortableContinuationArchiveIO.lean:39-55`: copies the helper executable into a temp dir, `chmod 0500`, checks its SHA-256 against a pin, runs it, and requires an exact stdout line (`"retained\n"`) and empty stderr.
  - `Compiler/PortableParticipantPinIO.lean:46-50`: uses `cas` and requires `"durable\n"`.
  - Both shell out to `/usr/bin/chmod`. `PortableParticipantPinIO.lean:62-66` also uses `/usr/bin/stat -c`, which is GNU-only.
- **Reachability.** Those Lean modules are imported only by `ResearchWip.lean:77-85`; `Kernel/PortableHomeTransferReceiver.lean:10-11` imports them but is itself not imported by `Kernel.lean`, `Deployed` or `Host/Main.lean`. No `lean_exe` (`lakefile.toml:72-218`), no unit, no journey.
- **Evidence.** `docs/PORTABLE-CONTINUATION.md:68-75` records one remote run: "five release nextest tests … helper build on Persvati". No `docs/evidence/` directory.

## 3.3 Does it decide anything semantic?

No. It explicitly decides nothing: "No generation, spent-anchor, source-obligation or native admission is decided here" (`lib.rs:3-4`). Coordinates are never used as paths (`lib.rs:23`). Repair requires exact content addresses (`:52-53`). Lean binds the manifest bytes (`PortableContinuationArchiveIO.lean:96-108`). This is a clean physical boundary.

## 3.4 Flaws noticed

1. **Staging files leak on error paths.**
   - `compare_replace` leaves `.portable-<nonce>` behind if `equal_files` fails or the rename fails (`durable_file.rs:61-67`).
   - `retain_chunk` leaves `.chunk-<nonce>` if the rename fails (`lib.rs:77-80`).
   - Nothing ever sweeps them.
2. **`capture` retains chunks before it knows the source was stable.** It retains each chunk at `lib.rs:94` and detects source change only afterwards at `:97-99`. On refusal the chunks stay. Content-addressed chunks with no garbage collection mean unbounded growth under repeated failed captures. No GC exists in the crate.
3. **`restore_new` is not idempotent under a lost reply.** It uses `create_new` (`:138`), so a retry after a successful but unacknowledged restore fails with `AlreadyExists`, unlike `write_exact`, which compares. It also leaves a partial target file on any mid-write error (`:140-142`). The Lean callers always restore into a fresh `withTempDir` (`PortableContinuationArchiveIO.lean:121-129`, `:138-145`), so today this is mitigated by the caller.
4. **The CAS cannot tell "my write already landed" from a conflict.** After a lost reply, re-running `cas` with the same `expected` returns `conflict`, and the test asserts exactly that (`durable_file.rs:94-101`). The caller must re-read and compare with `next` itself. See question 3.8.1.
5. **Lock name by `with_extension`** (`durable_file.rs:49`): the same collision class as chapter 1, flaw 4.
6. **`exact_chunk` allocates `Vec::with_capacity(CHUNK_BYTES)`** (`lib.rs:47`). This is bounded and fine. `read_range` indexes `bytes[from..until]` (`:128`) after `exact_chunk` guaranteed the length, which is safe.

## 3.5 Unwired / undone

- Research-only reachability (3.2). The whole crate is unwired from any deployed or journey path.
- It is a member of the four-way durable-CAS family (chapter 1.5).
- Its doc says it is "shared by portable continuation and agreement repair" (`lib.rs:1`), but `joint-agreement-crypto` does not use it. The agreement journal has its own `replace` (`session.rs:203-239`), so "agreement repair" is aspirational.
- Tests: five real filesystem tests (`lib.rs:152-174`, `durable_file.rs:82-110`), including a 17 MiB last-byte comparison.

## 3.6 Size and shape

| File | Lines | Tests | Code |
|---|---:|---:|---:|
| `src/main.rs` | 52 | 0 | 52 |
| `src/lib.rs` | 175 | 28 (`:148-175`) | 147 |
| `src/durable_file.rs` | 111 | 37 (`:75-111`) | 74 |
| **Total** | **338** | **65** | **273** |

Minimal for the demo: drop the whole crate (338 Rust lines and a 343-line `Cargo.lock`). The portable-continuation work is ResearchWip.

## 3.7 Deployability on a small public Linux VM

Not needed. If ever deployed it needs GNU `stat`, `/usr/bin/chmod`, a private 0700 archive directory and the pinned helper SHA. It has no network surface.

## 3.8 Questions for the Lean side

1. `PortableParticipantPinIO.hold` says "Exact lost-reply retry performs a new SAME-BYTES CAS/readback instead of inferring durability from file equality" (`Compiler/PortableParticipantPinIO.lean:56-61`). After a lost `durable` reply, the retry's `cas` with the old `expected` returns `conflict`, and Lean throws "participant pin CAS conflict or uncertain" (`:49-50`). Which declaration then recognises that the present file already equals `next` (`:67-70` reads `present`)?
2. Is the portable-continuation tree (`ResearchWip.lean:77-95`) slated for deletion or for promotion? This crate's fate follows it.

---

# Chapter 4. `native/signed-api-path` (152 Rust lines)

Package `minidregg-signed-api-path`, a workspace member (root `Cargo.toml:3`). It has no dependencies.

## 4.1 What it is and does

`src/lib.rs` provides exact routing under an SPK's signed legacy HTTP API prefix. It "neither supplies authority nor decodes URL escapes" (`:1-3`).
- `safe_segment` (`:8-15`): non-empty, not `.` or `..`, bytes in `[A-Za-z0-9-_.~]`.
- `checked_prefix` (`:19-31`): 1 to 256 bytes, starts and ends with `/`; `/` alone is the root profile; every interior segment is safe.
- `descriptor_inspection_type(prefix)` (`:35-43`): `None` or `"/repo.git/"` gives `"application-spk-package-identity-v1"`; any other checked prefix gives `"…-v2"`.
- `launch_inspection_type` (`:45-50`): v1 maps to `"application-spk-launch-descriptor-v2"`, otherwise `"…-v3"`.
- `route(prefix, relative)` (`:54-70`): the relative path must be at most 8192 bytes, not absolute, not trailing-slash unless empty, with every segment safe. It returns `prefix[1..] + relative`, at most 8192 bytes.
- `is_under(prefix, app_relative)` (`:73-78`).

## 4.2 What it assumes of its surroundings

- **Dependents:**
  - `native/grain-runtime/Cargo.toml:24` (`src/application_api_tools.rs`)
  - `native/spk-host/Cargo.toml:33`: `agent_api_lifetime_custody_v3.rs`, `claim_descriptor.rs`, `launch_descriptor_native.rs`, `agent_api_wire.rs`, `resident_launch.rs`, `dispatch_inspection.rs`, `descriptor_native.rs`, `agent_api_lifetime_v3.rs`, `agent_api_server.rs`
- **The Lean twin grammar:** `Kernel/ApplicationSpkPackageIdentity.lean:142-170` (`safeApiByte`, `safeApiSegment`, `safeApiTail`, `validApiPrefix`), described as "The exact byte grammar shared with `native/signed-api-path`" (`:142`).
- **Build note:** `deploy/candidate/lib.sh:142` mentions that grain-runtime builds `../signed-api-path`, the reason candidate builds use a fixed build root.

## 4.3 Does it decide anything semantic?

- **Prefix grammar: a mirror.** Lean admits a descriptor only if `validBridgeMapping` holds, and V2 requires `validApiPrefix descriptor.bridgeApiPath` (`Kernel/ApplicationSpkPackageIdentity.lean:213-228`). The legacy profile choice is `bridgeApiPath.isEmpty || == "/repo.git/"` (`:72-74`), mirrored at `lib.rs:37`.
  - Equivalence checked by hand: length cap 256, leading `/`, trailing `/`, non-empty segments, the byte class, refusal of `.` and `..`, and `//`. All agree.
  - One divergence: Rust `Some("")` refuses (`checked_prefix` returns an error), whereas Lean treats the empty path as legacy/no-API. Rust is stricter here, which is fail-closed.
- **Per-request relative routing `route`/`is_under` (`:54-78`): physical enforcement of a Lean-admitted scope, with no Lean counterpart.** Rust decides which HTTP request paths reach an app's API under the admitted prefix. That is scope enforcement at the boundary, which is acceptable, but it is the only gate on request paths. Blast radius if wrong: a path outside the signed prefix reaches the app API. The function refuses `%`, `?`, `#`, `\` and `:` (tests `:131-147`), so it is conservative.

## 4.4 Flaws noticed

- `route("/", "")` returns `""` (`:92`). Callers must treat the empty app-relative path as the API root deliberately.
- No other bugs. No allocation hazards (bounded), no panics (string slicing at `:27`, `:64`, `:76` is on ASCII-checked positions after `starts_with('/')`/`ends_with('/')` succeeded).

## 4.5 Unwired / undone

Reachable from shipped `spk-host` and `grain-runtime`. **Twin:** the prefix grammar is hand-written in both Rust (`lib.rs:8-31`) and Lean (`ApplicationSpkPackageIdentity.lean:146-170`). Law 13 says emit one from the other, or export the Lean `validApiPrefix` over FFI. The Rust tests (`:84-151`) replicate the Lean `decide` witnesses (`:172-189`) by hand.

## 4.6 Size and shape

| File | Lines | Tests | Code |
|---|---:|---:|---:|
| `src/lib.rs` | 152 | 73 (`:80-152`) | 79 |

Minimal: keep it (79 code lines), and eventually replace `checked_prefix` with a Lean export.

## 4.7 Deployability on a small public Linux VM

It is pure logic and needs nothing on the box. Through `spk-host`'s agent API server it is on a request path a member's app traffic reaches. Its conservative refusals are the right default.

## 4.8 Questions for the Lean side

1. Is there a Lean statement for how a request path relates to the signed prefix (an analogue of `route`/`is_under`), or is per-request path scoping intentionally physical?
2. Could `validApiPrefix` be `@[export]`ed so `spk-host` calls it instead of the Rust twin?

---

# Chapter 5. `native/bend-proof-entropy` (92 Rust lines)

Package `bend-proof-entropy`, edition 2024 (`Cargo.toml:4`). It is not a workspace member: `[workspace]` at `Cargo.toml:11`, own `Cargo.lock`. Dependencies are `rand =0.10.3` and `getrandom =0.3.4`; every other crate in this shard uses `getrandom =0.2.17`.

## 5.1 What it is and does

`src/lib.rs` provides `ProofRng {state: Arc<Mutex<StdRng>>, process: u32}` (`:10-14`). Clones share one advancing stream (`:1-5`), which meets Plonky3's `Clone` bound without duplicating PRNG state.
- `from_os()` (`:19-23`) seeds 32 bytes from `getrandom::fill` and returns an error on failure, never a fallback.
- `state()` (`:29-34`) asserts that the current PID equals the constructing PID ("proof RNG inherited across fork"), then locks.
- It implements `TryRng` and `TryCryptoRng` (`:37-45`).

The tests (`:47-92`) check the shared stream across clones and threads and the fork refusal.

## 5.2 What it assumes of its surroundings

`StdRng` in rand 0.10 is ChaCha-based (Cargo.lock lists `chacha20 0.10.2`). Its only user is `native/bend-ir2-proof` (`Cargo.toml:10`; `src/config.rs:5`, `src/legacy_config.rs:6`). It has no OS or network needs beyond the OS RNG.

## 5.3 Does it decide anything semantic?

No.

## 5.4 Flaws noticed

- **It panics in library code** on fork inheritance or mutex poisoning (`:32-33`). The trait is infallible (`type Error = Infallible`, `:38`), so a panic is the only way to refuse. That is acceptable for an offline harness and would be wrong inside a service.
- **The PID check is weak in PID namespaces.** A child created with `CLONE_NEWPID` can coincide with the parent's PID only if both are 1. That is an edge case, noted and not a real hazard.
- **The seed array is not zeroized** after `from_seed` (`:20-22`).

## 5.5 Unwired / undone

Reachable only through `bend-ir2-proof`, itself offline and unbuildable here (chapter 7). No markers.

## 5.6 Size and shape

| File | Lines | Tests | Code |
|---|---:|---:|---:|
| `src/lib.rs` | 92 | 46 (`:47-92`) | 46 |

Minimal: drop with `bend-ir2-proof` (92 Rust lines and a 111-line `Cargo.lock`).

## 5.7 Deployability

Not deployed.

## 5.8 Questions for the Lean side

None.

---

# Chapter 6. `native/launch-gate` (0 Rust lines; source is `deploy/grain-host/launch-gate.rs`, 450 lines)

## 6.1 What it is and does

**This is not an abandoned crate. It is a deliberate build manifest.** `native/launch-gate/Cargo.toml:1-3` explains: "The candidate builders build the grain launch gate through this manifest (deploy/candidate/package.py RUST_ROLES: launchGate). The source stays the deployed one, deploy/grain-host/launch-gate.rs (std only), which the hermes journeys and the grain-host docs also compile directly with rustc." The `[[bin]]` path is `../../deploy/grain-host/launch-gate.rs` (`:13-15`), with an empty `[workspace]` (`:11`) and a dependency-free `Cargo.lock`. It was introduced by `c607ef20` (2026-10-15): "a manifest whose [[bin]] is the deployed source … unmoved". `cargo metadata` confirms `src_path` resolves to the deploy file.

**`deploy/grain-host/launch-gate.rs`** is a durable per-operation systemd `ExecStart` gate for grain workers (`:1-3`).

Gate files and helpers:
- `private_dir(dir)` (`:29-41`): the state directory must be absolute, owned by the euid, and have no group/other bits.
- `gate_path` (`:43-58`): the unit name must match `mini-grain-t<digits>-o<digits>`; the gate file is `<unit>.gate`.
- `open_gate` (`:60-79`): opened with the hand-coded `O_NOFOLLOW = 0o400000` (`:13`), mode 0600, then checked for owner and mode.
- `read_state`/`write_state` (`:81-96`): truncate, write, fsync.

Gate states (stored text): empty, then `armed\n[controller identity]\n`, then `started…` or `fenced\n`.

Commands (`:338-439`):
- `--launch-gate-protocol` prints `mini-grain-launch-gate-v1` (`:344-347`); `--controller-manager-protocol` prints `mini-controller-manager-v1` (`:340-343`).
- `init`: `create_new` the gate, take the lock, read controller identity from env, write `armed`, fsync the directory (`:357-380`).
- `check-lifetime`: requires a system-manager controller identity and opens a pidfd for it (`:381-395`). This mode is missing from the usage text at `:349`.
- `fence`: writes `fenced` (`:396-405`).
- `run STATE UNIT -- ABS_CMD …` (`:406-436`): requires `armed`; rewrites it to `started` (single use); then either `exec`s the worker (user manager, legacy path) or `supervise`s it with a controller pidfd (system manager).

Controller identity (`Controller`, `:101-244`):
- Read from the env vars `MINI_GRAIN_CONTROLLER_MANAGER`, `_PID`, `_UNIT`, `_INVOCATION_ID` (`:110-150`).
- Verified by `/usr/bin/systemctl --<manager> show -p MainPID -p InvocationID -p ActiveState <unit>`, the process start time from `/proc/<pid>/stat` field 22 (`:245-251`), and a matching `/proc/<pid>` uid (`:188-221`).
- A pidfd comes from the raw syscall `syscall(434, pid, 0)`, which is `pidfd_open` (`:224-230`).

`supervise` (`:280-336`):
- Sets `PR_SET_PDEATHSIG = SIGKILL` and checks `getppid() == monitor` in `pre_exec`.
- Polls the child every 100 ms. If the controller's pidfd becomes readable (the controller died), it kills the worker and writes `fenced`.

## 6.2 What it assumes of its surroundings

- **Linux only:** `prctl`, `pidfd_open`, `/proc`, `flock`, `/usr/bin/systemctl`, systemd user and system managers, `bwrap` (the sibling `deploy/grain-host/bwrap:7-18` checks the gate protocol).
- **Built by** `deploy/candidate/package.py:78,90` (role `launchGate`, not in `REQUIRED`, `:95`). The target is `x86_64-unknown-linux-gnu` (`:99`).
- **Also compiled with plain rustc** per `deploy/grain-host/README.md:41-42`, and by `scripts/overnight-tests/launch-gate-probe.sh` (per `deploy/grain-host/GATE-INTEGRATION-2026-09-26.md:11`).
- **No Host protocol operations.**

## 6.3 Does it decide anything semantic?

It enforces single-use launch (`armed`, then `started`; a `fenced` gate refuses, `:414-424`) and controller-incarnation binding. This is physical fencing of an operation whose admission Lean owns. It is the right layer for it, provided a Lean receiver decides when to `init` and when to `fence`; that lives in grain-runtime or spk-host, outside this shard. It does not decide authority, balances or identity of members.

## 6.4 Flaws noticed

1. **`O_NOFOLLOW` is hard-coded as `0o400000`** (`launch-gate.rs:13`). That is correct on x86-64 and on asm-generic architectures. On aarch64 Linux, `arch/arm64/include/uapi/asm/fcntl.h` defines `O_NOFOLLOW` as `0100000`, and `0400000` is `O_LARGEFILE`. An ARM build (for example a Hetzner CAX VM) silently opens gate files following symlinks. The owner and mode checks on the opened file (`:71-77`) still run, so a symlink to another file the same user owns at mode 0600 would be accepted as the gate. Use `libc::O_NOFOLLOW` (which `portable-archive` does, `durable_file.rs:11`) or `std::os::unix::fs::OpenOptionsExt` with the libc constant. Today's candidate target is x86-64 (`package.py:99`), so this is latent.
2. **`write_state` truncates, then writes, then fsyncs** (`:90-96`). A crash between truncate and write leaves an empty gate. `run` then refuses ("fenced or already started", `:422`), and `init` refuses (`create_new`), so this fails closed, but the operation cannot be resumed without an operator.
3. **A failed `exec` leaves the gate `started`** (`:424`, `:434-435`): fail-closed, not retryable. That is the intended no-replay semantics.
4. **`ready()` treats `EINTR` as "not ready"** (`:270-275`). This is fine.
5. **Two build recipes for one source.** Cargo through `native/launch-gate`, and bare `rustc` through `README.md:41-42`. The binaries differ in flags; the SHA pins in `deploy/grain-host/README.md:82` must say which.

## 6.5 Unwired / undone

The `check-lifetime` mode is undocumented in the usage text (`:349`). No tests in the file; the probes are `deploy/grain-host/probe-controller-lifetime.py` and `scripts/overnight-tests/launch-gate-probe.sh`. `native/launch-gate` has no source of its own by design.

## 6.6 Size and shape

| File | Lines |
|---|---:|
| `native/launch-gate/Cargo.toml` | 18 |
| `native/launch-gate/Cargo.lock` | 7 |
| `deploy/grain-host/launch-gate.rs` (the source) | 450 (0 test lines) |

Minimal: keep the manifest if grains are in the demo; otherwise the role is optional (not `REQUIRED`).

## 6.7 Deployability on a small public Linux VM

- **On the box:** the binary beside `bwrap`, a private state directory, systemd user or system managers, `/usr/bin/systemctl`.
- **Exposure:** none to strangers. A member's grain controller account can call `init`, `fence` and `run` on gates in its own state directory only (`private_dir`, owner checks).

## 6.8 Questions for the Lean side

1. Which Lean receiver's admission precedes `launch-gate init`, and which uncertain outcome triggers `fence`? (The `failstart` path per README: `Kernel/ApplicationFailedStartRecoveryReceiver.lean`, ops 206-209.)

---

# Chapter 7. `native/bend-ir2-proof` (782 Rust lines)

Package `bend-ir2-proof`, edition 2024. It is not a workspace member: `[workspace]` at `Cargo.toml:7`, own 1,178-line `Cargo.lock`.

## 7.1 What it is and does

`README.md:1-3` calls it an "Experimental Objective Bend proof backend … offline harness consumes Lean-emitted local-row IR2 using the pinned Bread parser, prover and verifier. It is not a world proof-admission endpoint."

**`src/main.rs` (96 lines).**
- CLI forms: `prove descriptor.json public.csv trace.csv proof.bin` and `verify descriptor.json public.csv proof.bin` (`:66-68`).
- `read_fields` (`:14-25`): canonical BabyBear decimals, comma-separated, with a mandatory trailing newline.
- `require_subset` (`:35-53`) accepts only:
  - no challenges, no hash sites, no ranges;
  - exactly one `TableSem::Main` table;
  - only non-transition local `WindowGate`s;
  - first-row `PiBinding`s, with exactly one per public input.
- A fixed capacity of `MIN_TRACE_ROWS = 32` (`:75`).
- `config::for_artifact(capacity, descriptor_bytes)` (`:76`).
- **Prove:** builds the trace as `vec![row; 32]`, one row replicated (`:78-80`); proves, checks the shape, verifies, then writes the postcard proof (`:81-85`).
- **Verify:** postcard decode with no trailing bytes, shape check, verify (`:86-92`).
- Prints `PASS profile=… mode=…` (`:93`).

**`src/config.rs` (104 lines).** The hiding STARK config over Plonky3 rev `82cfad73`:
- Poseidon2 BabyBear-16; `MerkleTreeHidingMmcs` with `ProofRng` salts; `HidingFriPcs`.
- The `FullDegreeChallenger` wrapper over `DuplexChallenger` (`:20-30`).
- `artifact_digest` (`:37-45`): cSHAKE256 with N=`DREGG`, S=`BEND.IR2.DESCRIPTOR-BYTES/v1`, over `u64le(len) || descriptor`.
- `fresh_checked` (`:47-90`) observes, in order: the profile string (V4 `PROFILE` or V5 `ARTIFACT_PROFILE`, `:31-33`), every FRI parameter plus 4, 8, the masking constants and the capacity rows; then, for V5, the length bytes and 32 digest bytes, one field element per byte.
- `for_capacity` is V4 (`:94-96`); `for_artifact` is V5 (`:100-103`).

**`src/legacy_config.rs` (64 lines).** The "Retained v2 profile for raw negative regression only; not selected by the CLI" (`:1`). It uses the plain `DuplexChallenger`, no transcript binding, and `raw_for_regression` under `#[cfg(test)]` (`:63-64`). **It is not a `mod` of `main.rs`** (`main.rs:3-5` declares `config`, `masking_budget`, `full_degree_challenger` only). It is compiled only by `short_trace_disclosure.rs [not in tree]:7-8` through `#[path]`.

**`src/full_degree_challenger.rs` (146 lines).**
- `powers_span_extension` (`:14-34`): Gaussian rank of `{1, x, x², x³}` over BabyBear.
- `FullDegreeChallenger` (`:36-77`): resamples degree-4 challenges until their powers span the extension, at most 128 attempts, then panics (`:61-69`).
- Tests at `:79-146`.

**`src/masking_budget.rs` (32 lines).**
- `REQUIRED_TRACE_MASKS = IR2_EXT_DEGREE*2 + IR2_FRI_NUM_QUERIES`, which is 27 per the test at `short_trace_disclosure.rs:84`.
- `MIN_TRACE_ROWS = 32`.
- `TraceCapacity::checked` (`:17-29`) enforces a power of two, at least 27 rows, the two-adicity limit and no overflow.

**Tests:**
- `artifact_binding.rs [not in tree]` (36): V5 rejects a whitespace-changed descriptor under the recomputed seed and rejects a V4 config. Needs `BEND_IR2_FIXTURE`.
- `bounded_commitment.rs [not in tree]` (55): runs the binary against `BEND_COMMITMENT_FIXTURE`; checks correct and wrong publics, and an inconsistent private wire. Heavy; excluded by `.config/nextest.toml:3`.
- `masking_observations.rs [not in tree]` (88): linear-algebra falsifiers of the mask budget.
- `quotient_masking.rs [not in tree]` (46): calls the real `get_quotient_ldes` and recomposition.
- `short_trace_disclosure.rs [not in tree]` (115): the raw one-row proof leaks the private trace (an adversarial regression), the capacity refusals, and the relation preserved at 32 and 256 rows.

**Non-Rust files:**
- `provision.py` (46): verifies 374 pinned file hashes of an external breadstuffs slice (`dependencies.lock.json` covers 341 files under `circuit/`, 16 under `vendor/`, 10 under `dregg-dsl/`, 6 under `dregg-codec/` and the root `Cargo.toml`), then symlinks it at `native/bend-proof-deps/bread` (`:34-40`).
- `test_provision.py [not in tree]` (30) tests the pin checker only.
- `OBJECTIVE-ONLY-MIGRATION.txt` (57) lists retired paths.
- `QUALIFICATION-R32.txt` (101) and `QUALIFICATION-R33.txt` (71) are dated qualification narratives.
- `README.md` (36).

## 7.2 What it assumes of its surroundings

- **An external source tree.** `dregg-circuit = { path = "../bend-proof-deps/bread/circuit" }` (`Cargo.toml:14`). `native/bend-proof-deps` does not exist in this checkout (`ls` fails), and `cargo metadata` fails with "failed to read …/bend-proof-deps/bread/circuit/Cargo.toml".
- **GitHub git dependencies** on Plonky3 (`Cargo.toml:15-24`, `:31`), plus two vendored patches pulled from the external slice (`:26-28`).
- **A pinned toolchain host:** "leased, capped, warm build host" (`README.md:23`).
- **Lean emitters.** `Host/BendTraceIR2Emit.lean` (91 lines, a range gadget plus one private Boolean, "not a Bend-program demo", `:3-8`), `Host/BendCommitmentIR2Emit.lean` (44), `Verify/BendCommittedIR2Emit.lean` (47). The `ir2` grep across `Compiler/`, `Verify/` and `Host/` also finds `Compiler/BendTraceIR2.lean`, `BendUnrolledIR2.lean`, `BendTraceConstraints.lean`, `BendTraceDirect.lean`, `BendTracePublicPins.lean`, `BendTraceSound.lean` and `BendUnrolledDirect.lean`. `Compiler.BendTraceIR2` is imported by `Assurance/BendArithmeticQualification.lean` and `ResearchWip.lean`, among others.

## 7.3 Does it decide anything semantic?

No world decision. `require_subset` (`main.rs:35-53`) is a grammar gate for the harness. README says outright that "Existing reexecution admission remains in force" (`:36`). Nothing in Host calls it.

## 7.4 Flaws noticed

1. **It is unbuildable in-tree** (7.2). The README's reproduction commands (`:25-32`) fail on a clean checkout without the external slice. This is a hidden dependency on breadstuffs, the very repo minidregg replaces.
2. **The verify path needs OS entropy.** `config::for_artifact` builds `ProofRng::from_os()` even for `verify` (`main.rs:76`, `config.rs:51,67`), so a verifier fails when `getrandom` fails, although verification needs no randomness.
3. **`fs::write(&args[5], …)` writes the proof non-atomically over any existing file** (`main.rs:85`). The test that expects "failed proof was released" to be false (`bounded_commitment.rs:54`) relies on the earlier `?` returns, which hold.
4. **Tests panic instead of skipping when fixtures are absent.** `BEND_IR2_FIXTURE` is `unwrap`ped (`artifact_binding.rs:12`, `short_trace_disclosure.rs:94`) or `expect`ed (`short_trace_disclosure.rs:28-29`). The nextest default filter excludes only the two heavy tests (`.config/nextest.toml:3`), so a default run fails three tests for a missing env var rather than skipping them.
5. **`masking_observations.rs` hard-codes the LDE blowup `6` and the query count `19`** (`:53-60`) instead of using `IR2_FRI_LOG_BLOWUP` and `IR2_FRI_NUM_QUERIES` (the budget module uses the constants, `masking_budget.rs:6,10-11`). If the pinned parameters change, this falsifier silently tests a stale map.
6. **Trace replication.** `vec![row; capacity.rows()]` (`main.rs:80`) proves 32 copies of one row. That suits the "local-row" grammar, but the CLI can never prove a multi-row trace.
7. **A challenger panic** after 128 failed draws (`full_degree_challenger.rs:69`) is documented as fail-closed for offline use only.

## 7.5 Unwired / undone

- **Survivor status.** The repo README says the BFV and upstream-Bend consumers were deleted on 2026-10-04, and the Honest state row says "the generic oblivious/arithmetic circuit stack has no Objective producer yet". The crate's own README (`:36`) and the migration note (`:53-55`) confirm that no Objective controller producer exists and the old source-controller fixtures are retired. **Verdict: it is a survivor with only synthetic fixtures left to prove against** (the range gadget in `Host/BendTraceIR2Emit.lean` and the commitment fixtures). It has no consumer in Host, no journey and no unit.
- **Stale qualification text.** `QUALIFICATION-R32.txt:5-24,89-96` describes `Verify.BendControllerCommitmentEmit [deleted 008fd5e7]` and `controller_commitment.rs [not in tree]`; both are deleted (checked with `ls`). Several paths listed in `OBJECTIVE-ONLY-MIGRATION.txt:34-44` are gone (`Theory.BendExecutionTrace [deleted 212c79af]`, `Assurance.BendUnrolledSource [deleted 008fd5e7]`, `Compiler.BendProofProjection [deleted 008fd5e7]`), as is `Assurance.BendObliviousMinimal [deleted 212c79af]`, which R32 cites. The text documents a world that no longer exists.
- **Versioned siblings:** V2 (`legacy_config.rs`), V4 (`config::for_capacity`, `PROFILE`) and V5 (`for_artifact`, `ARTIFACT_PROFILE`) all coexist. V2 and V4 are reachable only from tests.
- **Test-only file under `src/`:** `legacy_config.rs` (7.1).

## 7.6 Size and shape

| File | Lines | Tests | Code |
|---|---:|---:|---:|
| `src/main.rs` | 96 | 0 | 96 |
| `src/config.rs` | 104 | 0 | 104 |
| `src/legacy_config.rs` | 64 | (test-only file) | 64 |
| `src/full_degree_challenger.rs` | 146 | 68 (`:79-146`) | 78 |
| `src/masking_budget.rs` | 32 | 0 | 32 |
| `tests/*.rs` (5 files) | 340 | 340 | 0 |
| **Rust total** | **782** | **472 (incl. legacy_config)** | **310** |
| Non-Rust: `Cargo.lock` 1178, `dependencies.lock.json` 380, txt/md 265, py 76, nextest 6 | 1,905 | | |

Minimal for the demo: drop the whole crate (782 Rust lines plus about 1,905 lines of lock and doc files). Keep its R32/R33 history in git.

## 7.7 Deployability

Not deployable and not needed. It would require the external breadstuffs slice and network access to GitHub.

## 7.8 Questions for the Lean side

1. Is any Lean theorem consumed that relates native PCS acceptance to `Compiler/BendCommittedRunSound`'s arithmetic premise? Both R33 (`:59`) and the README (`:17`) say no. If none is planned for the demo horizon, are `Host/BendTraceIR2Emit.lean`, `Host/BendCommitmentIR2Emit.lean` and `Verify/BendCommittedIR2Emit.lean` also deletion candidates?

---

# Chapter 8. `native/hyperdocument-link-store` (713 Rust lines)

Package `minidregg-hyperdocument-link-store`. It is **neither a workspace member nor a valid standalone package**: its `Cargo.toml` has no `[workspace]` table.

## 8.1 What it is and does

**`src/lib.rs` (222 lines).** `LocalLinkStore {root}` stores one opaque record of at most 4096 bytes (`:17`) under fixed names: `forward-link.recovery` (published) and `forward-link.recovery.staged` (`:18-19`).
- `StoreError`: `Missing`, `TooLarge`, `Conflict`, `NotRegular`, `Io` (`:21-28`).
- `open` (`:79-87`): `create_dir_all`, then the root must be a real directory.
- `read_bounded` (`:108-131`): `File::open` (which follows symlinks), regular file, at most 4096 bytes.
- `stage` (`:142-178`): if the published record equals the bytes, return `AlreadyPresent`; if it differs, `Conflict`. The same comparison then runs against the staged file. Otherwise it creates the staged file with `create_new`, writes and fsyncs.
- `install_staged` (`:180-206`): `hard_link(staged, published)`, which never overwrites; fsync the directory; remove the staged file; fsync again. On `AlreadyExists` it compares, then removes the staged file.
- `publish` = stage + install (`:208-213`). `discard_staged` (`:215-221`).

**`src/main.rs` (71 lines).** CLI `minidregg-link-store read|stage|install|publish|discard-stage ROOT [INPUT]` (`:22-27`).

**`src/bin/forward_link_e2e_bench.rs` (314 lines).** It runs the stage, install, read, retry and read lifecycle in a fresh child process per stage (`:186-216`), with 31 samples and 3 warmups by default (`:21-22`, env `MINIDREGG_LINK_BENCH_SAMPLES`/`_WARMUPS`). It prints nearest-rank p50, p95 and p99 (`:218-284`).

**`native/hyperdocument-link-sqlite-store/tests/lifecycle.rs` (106 lines).** In-process tests: fixture pin, staged crash not visible, lost response then exact retry, different retry conflicts, oversize.

**Fixture.** `fixtures/hyperdocument-link-recovery-v1.bin`, 14 bytes: `a24a1ed8 01 HYPERLNK n`. Lean (`scripts/EmitHyperdocumentLinkRecoveryFixture.lean`, `Assurance.HyperdocumentLinkLocalFileStore`) authors it.

## 8.2 What it assumes of its surroundings

- POSIX hard links and directory fsync.
- Drivers: `test-hyperdocument-link-local-store.sh [deleted 52c252e3]` (lake build, fixture regeneration with `cmp`, `cargo test`, process-level CLI checks) and `run-forward-link-e2e-benchmark.sh [deleted 52c252e3]:44-56`. Neither is wired into any gate (`git grep` finds no caller).
- Lean: `Assurance/HyperdocumentLinkLocalFileStore.lean` (imported by `Assurance.lean:69`), `Assurance/HyperdocumentLinkClientLocalFileCutover.lean:16-20`, and `Assurance/HyperdocumentLinkSqliteTransactionalStore.lean:16-21`, which builds on the local-file module.
- **Fixture dependency:** the workspace crate `native/hyperdocument-link-sqlite-store/tests/lifecycle.rs:12` does `include_bytes!("../../hyperdocument-link-store/fixtures/hyperdocument-link-recovery-v1.bin")`.

## 8.3 Does it decide anything semantic?

No. "This crate has no Hyperdocument, WAL, authorization, replay, or acceptance semantics" (`lib.rs:3-5`).

## 8.4 Flaws noticed

1. **It does not build in the tree.** `cargo metadata --manifest-path Cargo.toml [deleted 52c252e3]` fails with "current package believes it's in a workspace when it's not … add an empty `[workspace]` table". The root workspace was added in `295cab11` (2026-10-08); this crate was last touched 2026-08-11 (`2dfcf06f`). So `test-hyperdocument-link-local-store.sh [deleted 52c252e3]:15-16` and `run-forward-link-e2e-benchmark.sh [deleted 52c252e3]:49-50` have been broken since 2026-10-08, and nothing noticed: law 8, gate the gates.
2. **A crash mid-stage blocks the store until an operator acts** (`lib.rs:152-157`, `:175-176`). A crash inside `write_all` leaves a truncated staged file. The next `publish(bytes)` compares and finds a mismatch, so it returns `Conflict`, forever, until someone runs `discard-stage`. This fails closed, but liveness requires a manual step. The test `staged_crash_is_not_visible_and_can_be_discarded_after_restart` (`native/hyperdocument-link-sqlite-store/tests/lifecycle.rs:46-60`) only covers a complete stage.
3. **`read_bounded` follows symlinks** (`File::open`, `:109`). Only the root directory is checked for symlinks (`:82-85`). Same-user threat model only.
4. **README overstates the tests** (`README.md:15-17`). It claims "Tests exercise separate process invocations for stage/crash, publish/lost-response, restart/read, exact retry, conflict, corruption transport". `native/hyperdocument-link-sqlite-store/tests/lifecycle.rs` is in-process (it drops and reopens the struct). The process-level checks live in the unwired shell script, and the "corruption" case there (`test-hyperdocument-link-local-store.sh:42-52`) is a different-bytes retry, not corrupt-read transport.
5. **The bench's "lost response" is just an ignored stdout** (`forward_link_e2e_bench.rs:192-196`). It measures process spawn plus filesystem calls, not loss.
6. **License mismatch.** `MIT OR Apache-2.0` (`Cargo.toml:6`), against `AGPL-3.0-or-later` across the rest of `native/`.

## 8.5 Unwired / undone: TWIN verdict

**It is a twin, and it is the one to delete.** `native/hyperdocument-link-sqlite-store/README.md` lines 3-9 say the SQLite crate "is the shared opaque transport for Lean-owned durable images **and the existing Hyperdocument link byte record** … The old `publish` operation is a thin CAS-from-absent adapter, with the same compatibility type alias", and that "The database filename remains `forward-link.sqlite3` to preserve old clients" (`:27`). Its `src/lib.rs:1-11` header says the same thing for SQLite. That crate is the deployed `store` role (`deploy/candidate/package.py:61,83`).

| | `hyperdocument-link-store` (this crate) | `hyperdocument-link-sqlite-store` (workspace) |
|---|---|---|
| Backing | two fixed files and a hard link | SQLite rollback-journal BLOB |
| Operations | stage, install, publish, read, discard | `compare_exchange`, `publish` adapter, read, migration |
| Bound | 4096 B (`lib.rs:17`) | 64 MiB (`sqlite-store/src/lib.rs:25`) |
| Reachable | two broken, ungated scripts | candidate `store` role, Host `storageBinary` |
| Lean | `Assurance/HyperdocumentLinkLocalFileStore.lean` | `Assurance/HyperdocumentLinkSqliteTransactionalStore.lean`, which builds on the former |

Deleting this crate requires moving the 14-byte fixture (sqlite tests include it by relative path) and deciding whether `Assurance/HyperdocumentLinkLocalFileStore.lean` and `…ClientLocalFileCutover.lean` stay as a model that the SQLite module opens (`HyperdocumentLinkSqliteTransactionalStore.lean:21-23`).

## 8.6 Size and shape

| File | Lines | Tests | Code |
|---|---:|---:|---:|
| `src/lib.rs` | 222 | 0 | 222 |
| `src/main.rs` | 71 | 0 | 71 |
| `src/bin/forward_link_e2e_bench.rs` | 314 | 0 | 314 (benchmark) |
| `native/hyperdocument-link-sqlite-store/tests/lifecycle.rs` | 106 | 106 | 0 |
| **Total** | **713** | **106** | **607** |

Minimal: drop all 713 lines, plus `README.md` (31), `Cargo.lock` (7) and the two scripts. Move the fixture to the SQLite crate.

## 8.7 Deployability

Not deployed and not deployable (it does not build).

## 8.8 Questions for the Lean side

1. Is `Assurance.HyperdocumentLinkLocalFileStore` still load-bearing for any theorem the SQLite module exports, or only for the namespace it opens? If the latter, can both local-file Assurance modules go with the crate?

---

# Chapter 9. The four shared root files (1,472 Rust lines)

## 9.1 What they are and do

### 9.1.1 `native/hybrid_kem.rs` (471 lines)

The hybrid X25519 + ML-KEM-768 KEM, "the ONE implementation" (`:1-24`).

Constants (`:33-45`):
- `KEM_EK_LEN 1184`, `KEM_CT_LEN 1088`, `KEM_DK_LEN 2400`, `KEM_SEED_LEN 64`
- `PUBLIC_LEN = 32 + 1184`, `CIPHERTEXT_LEN = 32 + 1088`, `SECRET_LEN = 32 + 64`, `KEK_LEN 32`

Primitives:
- `cshake` / `cshake_xof` (`:49-62`): cSHAKE256 with function name empty and customization `label`, over a list of parts each prefixed with `u64be(len)`.
- `random::<N>()` (`:64-70`): reads `/dev/urandom` through `File::open`, not the getrandom syscall.

`HybridPublic {x25519, kem}` (`:84-148`):
- `from_bytes` refuses a bare 1184-byte key by name (`:120-124`) and validates the ML-KEM key through `EncapsulationKey::new` (`:132-133`). The X25519 half is not validated here; a low-order point is refused at encapsulation.
- `id()` = cSHAKE(`DREGG.CLIENT.ENC-KEY-ID/v1`, x25519, kem) (`:79`, `:145-147`).

`HybridSecret {x25519: StaticSecret, kem_seed: Zeroizing<[u8;64]>, kem: DecapsulationKey, public}` (`:152-225`):
- `from_parts` regenerates the ML-KEM key from the seed (`:162-167`).
- `generate` draws 32 + 64 random bytes and zeroizes its temporaries (`:171-178`).
- `from_bytes` refuses a 2400-byte `dk` by name (`:182-192`).
- `to_bytes`/`parts` return `Zeroizing` values (`:194-206`).
- `matches` compares the recomputed public key (`:210-212`).

`ml_kem_768_from_seed` (`:239-297`):
- Declares `EVP_PKEY_keygen_deterministic` against the versioned link name `aws_lc_0_45_0_EVP_PKEY_keygen_deterministic` (`:240-248`).
- Uses RAII guards for the ctx and pkey.
- Extracts the raw `dk` (2400 bytes, into `Zeroizing`) and `ek` (1184), then loads `DecapsulationKey::new`.

`transcript(frame, context, ephemeral, kem_ct, recipient)` (`:303-320`): `u64be(len) || bytes` for each of frame, every context part, ephemeral key, KEM ciphertext, recipient X25519 key and recipient ML-KEM key.

`combine(suite, ss_x, ss_k, transcript)` = cSHAKE256(S=suite, [ss_x, ss_k, transcript]) (`:325-327`).

`encapsulate` (`:341-365`):
- A fresh ephemeral `StaticSecret` from `/dev/urandom`.
- Refuses a non-contributory (low-order) DH result (`:350-352`).
- Encapsulates to ML-KEM through AWS-LC.

`decapsulate` (`:370-395`):
- Checks the ciphertext length and refuses a low-order ephemeral key.
- ML-KEM implicit rejection yields an unrelated key (`:367-369`).

Tests (`:397-471`): round trip with context, frame and suite binding; both halves required; low-order refusal; serialization and refusal of the pre-hybrid shapes.

### 9.1.2 `native/crypto_transit.rs` (380 lines)

Suite v2 transit sealing (`:1-8`).

Constants:
- `FRAME = "DREGG/HYBRID-TRANSIT/v2"`, `SUITE = "DREGG.TRANSIT.KEK/x25519+ml-kem-768/v2"`
- Subkey labels `DREGG.TRANSIT.AEAD-KEY/v2` and `…COMMIT-KEY/v2` (`:28-34`)
- `MAX_PLAINTEXT = 256 KiB`, `MAX_LAYER_PLAINTEXT = MAX_PLAINTEXT + 4*OVERHEAD`, `MAX_CONTEXT = 72 KiB` (`:25-27`)
- `OVERHEAD_BYTES = 1120 + 24 + 32 + 16` (`:23-24`, test at `:261`)

**What it encrypts:** arbitrary plaintext up to the bounds (mix layers, party capsules, "test private share").

**Construction** (`seal_raw_context`, `:108-131`):
1. `hybrid_kem::encapsulate(SUITE, FRAME, [aad], recipient)`.
2. Two subkeys derived from the KEK: `aead_key = cSHAKE(AEAD_LABEL, kek)`, `commit_key = cSHAKE(COMMIT_LABEL, kek)` (`:90-95`).
3. A random 24-byte XChaCha nonce from `/dev/urandom` (`:115-118`).
4. **AEAD:** XChaCha20-Poly1305 with AAD = the full hybrid transcript (`:119-124`).
5. **Key commitment:** HMAC-SHA256(`commit_key`, transcript || SHA-256(ciphertext)) (`:96-103`).

`open_raw_context` (`:132-168`):
- Refuses a v1 capsule (1088-byte KEM ciphertext) by name (`:133-137`).
- Checks bounds, decapsulates, verifies the commitment in constant time (`ring::hmac::verify`, `:153-158`), then decrypts.

`seal`/`open` (`:183-201`) wrap with `recipient_context(epoch, binding)` = `RECIPIENT_DOMAIN || u64le(len)||epoch || u64le(len)||binding` (`:169-180`). Note little-endian here, against big-endian in `hybrid_kem`.

`generate_keypair`/`validate_keypair` (`:69-88`).

Tests (`:203-380`) include a **combiner known answer** for this suite (`:357-379`): the transcript SHA-256 `f331ca4f…` and the KEK `3f7b6f0e…`, computed with pycryptodome.

### 9.1.3 `native/host-operations.rs` (376 lines)

Generated (`:1-3`): the header lines, `#![allow(dead_code)]`, then 186 `pub const SYMBOL: u8 = CODE;` lines, each preceded by a `// status; routes; owner` comment.

Generator: `scripts/host-operations.py`.
- `load` (`:32-67`) validates the registry: unique codes and symbols, status/receiver consistency, routes from the three allowed shapes, response markers, client constant bindings.
- `host_receivers` (`:151-194`) parses `dispatchSession`, the local `fnDispatch` and the `serveFrame` interceptor chain out of `Host/Main.lean`, using a masked-source grammar that fails closed (`:69-113`).
- `rust_routes` (`:219-261`) parses `allowed_operation` and `allowed_operator_operation` in `native/resource-client/src/transport.rs`.
- `check` (`:272-296`) requires: active set = Host receivers; routes match; client constants match by value; generated file byte-identical.
- `generate` writes through a temp file and `replace` (`:303-309`).

**Currency, verified:** `python3 scripts/host-operations.py check` printed `{"active": 184, "clientConstants": 20, "hostOnly": [24, 25], "operatorOnly": 69, "public": 113, "reserved": 2}` (saved in scratch `host-ops-check.txt`). Regenerating `generated(load(...))` in memory to scratch is **byte-identical** to `native/host-operations.rs`. The reserved entries are `CARRY_PAY_CLAIM_LOOKUP = 191` and `LAW_DIAGNOSTIC = 192`. The Host-only entries are `SELECTED_SOURCE_PUBLISH_SUBMIT = 24` and `…_LOOKUP = 25`.

### 9.1.4 `native/pinned_execution.rs` (245 lines)

Linux sealed image and settings execution (`:1-3`).
- `snapshot` (`:21-55`): `memfd_create` with `MFD_CLOEXEC | MFD_ALLOW_SEALING`, plus `MFD_EXEC` (0x10) or `MFD_NOEXEC_SEAL` (0x08), falling back on `EINVAL`. Then `fchmod` 0700 or 0400, copy with a cap, and seal `WRITE | GROW | SHRINK | SEAL`.
- `SealedInvocation::new(program, expected_sha256, settings)` (`:60-99`): bounded image (128 MiB) and settings (16 MiB). It copies, seals, then hashes, so a racing writer cannot change admitted bytes.
- `output_with_input` (`:103-172`): runs `/usr/bin/timeout --kill-after=2s <N>s /proc/<pid>/fd/<image> /proc/<pid>/fd/<settings> args…`. It writes stdin, reads at most `max_output+1` bytes of stdout, requires a successful exit, and kills and reaps on any error.
- Tests use `/usr/bin/dash` and `/usr/bin/false` (`:174-245`, Linux only).

## 9.2 What they assume of their surroundings

**Includers.**

| File | Includer and line | Visibility | Condition |
|---|---|---|---|
| `hybrid_kem.rs` | `native/resource-client/src/main.rs:88-89` | `mod` (private) | unconditional |
| `hybrid_kem.rs` | `native/private-backend/src/lib.rs:41-42` | `pub mod` | unconditional |
| `crypto_transit.rs` | `native/resource-client/src/main.rs:90-92` | `mod` | `#[cfg(unix)]` |
| `crypto_transit.rs` | `native/private-backend/src/lib.rs:43-44` | `pub mod` | unconditional |
| `host-operations.rs` | `native/resource-client/src/member_app.rs:8-9` | `mod` | unconditional |
| `pinned_execution.rs` | `native/private-backend/src/lib.rs:64-65` | `pub mod` | unconditional |

`private-backend` is not a workspace member (own `[workspace]`, own `Cargo.lock`), so the same source compiles under **two dependency trees**.

**Dependency comparison** (manifests, then resolved locks):

| Crate | resource-client (`Cargo.toml`) → workspace `Cargo.lock` | private-backend (`Cargo.toml`) → own `Cargo.lock` |
|---|---|---|
| `aws-lc-rs` | `=1.18.1`, `non-fips`, no default features (`:31`) → 1.18.1 | same (`:10`) → 1.18.1 |
| `aws-lc-sys` | `=0.45.0`, no default features (`:34`) → 0.45.0 | same (`:17`) → 0.45.0 |
| `x25519-dalek` | `=2.0.1`, `static_secrets` + `zeroize` (`:26`) → 2.0.1 | same (`:14`) → 2.0.1 |
| `chacha20poly1305` | `=0.10.1`, `alloc` (`:27`) | same (`:11`) |
| `ring` | `=0.17.14` (`:24`) | same (`:12`) |
| `sha2` | `=0.10.9` (`:23`) | same (`:8`) |
| **`sha3`** | **`=0.10.9`** (`:28`) | **`=0.10.8`** (`:13`) |
| `zeroize` | `=1.9.0` (`:29`) | same (`:15`) |
| `curve25519-dalek` (transitive) | 4.1.3 | 4.1.3 |

Verdict: the trees agree on everything security-relevant except a `sha3` patch-version split. The AWS-LC symbol pin (`hybrid_kem.rs:241`) needs `aws-lc-sys 0.45.0` in both, and both pin it with a comment (`resource-client/Cargo.toml:32-34`, `private-backend/Cargo.toml:16-17`). Feature sets of the included module differ: `crypto_transit` is `cfg(unix)` in one tree and unconditional in the other, and the visibility differs (`mod` vs `pub mod`), which changes `dead_code` warnings.

**OS.**
- `/dev/urandom` must be openable (`hybrid_kem.rs:66`, `crypto_transit.rs:116`). It fails inside a sandbox without `/dev`.
- `pinned_execution` is Linux-only: memfd seals, `/proc/<pid>/fd`, `/usr/bin/timeout`.
- `host-operations.rs` assumes nothing.

**Host protocol (host-operations).** Consumers use the generated constants in exactly one file: `member_app.rs:10-11` (`PLAN_OP = APPLICATION_DISPATCH_AUTHENTICATED_PLAN`, `READY_OP = APPLICATION_DISPATCH_READY`). A scan of every `invoke(`/`session_invoke(` call site in `native/` (scratch `raw-op-literals.txt`) found:
- **159 call sites in 39 files pass a literal request number**, 88 distinct numbers.
- **0 call sites** use `host_operations::`.
- 6 pass a local constant.
- Top files: `transport.rs` 26, `job.rs` 10, `fleet.rs` 9, `activity.rs` 8, `seat.rs` 8, `clock.rs` 7, `pay_refill.rs` 7, `checkpoint.rs` 6, `main.rs` 6, and 11 `spk-host` lifecycle files with 1-4 each. Sample: `activity.rs:84,88,100,135,239,254` (`invoke(ws, 7|8|214|210|211|212, …)`), `checkpoint.rs:113,140,149,150` (173, 170, 171, 172), `clock.rs:147,205,283,292` (129, 128, 126, 127), `agent_reserve.rs:263,536,598,639` (58, 59, 2, 3), `agent_payer.rs:125` (48).

Local `const NAME: u8 = N;` request constants:
- **Registered under `client_constants`, so checked by value:** `agent_lifetime_grant.rs:20-23`, `agent_reserve/lifetime_v3.rs:17-18`, `participant_provisioning.rs:20-23`, `pay.rs:55,57`, `session_enrollment.rs:20-23`, `join_solana_v2.rs:11-12`, and the two in `member_app.rs`.
- **Not registered, so unchecked:**
  - `join_solana.rs:42` `QUOTE_OP = 121` (`PAY_ENROLLMENT_QUOTE`)
  - `join_solana.rs:43` and `pay.rs:58` `ENROLMENT_VIEW_OP = 112` (`PAY_ENROLLMENT_VIEW`)
  - `spk-host/src/dispatch_native.rs:24` `ROUTE_BOUND_DISPATCH_OPCODE = 164` (`APPLICATION_ROUTE_BOUND_DISPATCH`)
  - `mini-sdk/src/operator.rs:57-61` `op::{PREPARE 1, SUBMIT 2, LOOKUP 3, CHALLENGE 4, QUERY 5}` (the registry's `AUTHORIZED_PREPARE`, `SUBMIT`, `LOOKUP`, `OBSERVATION_CHALLENGE`, `AUTHORIZED_QUERY`)
- All literal numbers found are valid registry codes, except **222, 224, 226, 227 and 232** at `client_consent.rs:259,1101,1112,1129,298`. These belong to a **second, unregistered byte namespace**: the local consent session, served by `Host/ClientConsentCore.lean:369-432` (arms `| 220`, `| 221`, `| 222`, `| 230`, `| 231`, `| 232`) and `:552-590` (226, 228, 229). That is a different Lean executable (`minidregg-client-consent`, `lakefile.toml:91-97`), so the codes do not collide in practice. But they sit outside the allocation record that `protocol/HOST-OPERATIONS.md` calls the authority.

## 9.3 Do they decide anything semantic?

- `hybrid_kem` and `crypto_transit` are pure cryptography. They decide "is this ciphertext acceptable" only in the cryptographic sense, and their module docs disclaim authority, custody and anonymity (`crypto_transit.rs:7-8`).
- `host-operations.rs` holds constants only (`:2`).
- `pinned_execution` is byte custody (`:1-3`).
- **None decides semantics.**

## 9.4 Flaws noticed

1. **A false architecture claim in `hybrid_kem.rs`.** Lines 3-6 and 14-15 say "Every key exchange in `native/` goes through here … There is no pure-X25519 and no pure-ML-KEM path". `channel.rs [deleted 17d61469]:22-24` documents "Sealing (X25519 mode; ML-KEM pairwise keys are lane CH-KEM-EPOCH)", and the code does pure X25519 at `channel.rs:207` (`esk.diffie_hellman`) and `:236`. Either channel goes through `hybrid_kem`, or the claim must name the exception (law 14: state covered scope).
2. **The seed-layout known-answer test does not travel with the code.** `hybrid_kem.rs:236-238` claims "The known-answer test checks the derived encapsulation key against an independent pure-Python FIPS 203 implementation". That test is `resource-client/src/private.rs:1220-1235` (`the_seeded_ml_kem_key_matches_an_independent_fips_203_implementation`), not in `hybrid_kem.rs`. It therefore never runs in the `private-backend` tree, which compiles the same FFI declaration against its own lock. Both locks pin 0.45.0 today, so they agree; the pattern is fragile. `crypto_transit` carries its own combiner known answer (`:357-379`); `hybrid_kem.rs` itself has none.
3. **Zeroization gaps.**
   - `crypto_transit::KeyPair.secret` is a plain `Vec<u8>` (`:41`): `key.to_bytes().to_vec()` turns a `Zeroizing<Vec>` into an unprotected copy (`:72`).
   - `subkeys` returns plain arrays (`:90-95`); `aead_key`/`commit_key` at `:114` and `:150` are not zeroized.
   - In `hybrid_kem`, `from_bytes` passes the secret halves through `fixed()` stack arrays that are not zeroized (`:191`), and `random::<32>()` at `:347` leaves a stack copy.
   - The main secrets (`StaticSecret` with the zeroize feature, the `Zeroizing` seed and `dk`) are handled well.
4. **Randomness by `File::open("/dev/urandom")`** (`hybrid_kem.rs:66`, `crypto_transit.rs:116`) rather than the `getrandom` syscall. It fails loudly (returns `Err`) when `/dev` is missing, which is fail-closed. It also opens one file descriptor per draw.
5. **Mixed endianness.** `hybrid_kem` length prefixes are big-endian (`:56`, `:316`); `crypto_transit::recipient_context` uses little-endian (`:176`). This is not a bug, because each is fixed by its known answer and domain string, but two conventions within 400 lines invite a future mismatch.
6. **Two crypto libraries in one construction:** AWS-LC for ML-KEM, `ring` for HMAC, RustCrypto for SHA-2, SHA-3 and XChaCha, and dalek for X25519 (`crypto_transit.rs:10-15`, `hybrid_kem.rs:25-30`). That is four implementations to audit and update.
7. **`pinned_execution::output_with_input` can deadlock until the timeout.** It writes all of stdin (up to 16 MiB, `:125-127`, `:146-150`) before reading stdout (`:151-157`). A child that emits more than a pipe buffer of output before it finishes reading input deadlocks until `timeout` kills it, which surfaces as "child refused". It is bounded (at most 300 s) and fails closed, but correct children are refused. A reader thread or `poll` would fix it.
8. **`pinned_execution` runs the image from `/proc/<self>/fd/N` of the parent** (`:133-138`). This requires the child to be allowed to open the parent's fds through `/proc`. That holds under the same uid without a hardened `ptrace_scope`/`hidepid` setup; Yama `ptrace_scope=3` or a different uid breaks it. `resource-client/src/transport.rs:1430-1440` has the same assumption.
9. **Raw request numbers bypass the registry** (9.2). A typo such as `invoke(ws, 212, …)` written where 213 was meant is invisible to `scripts/host-operations.py`, which by design does not scan `invoke` arguments (`protocol/HOST-OPERATIONS.md:57-59`). The generated file exists, is current and is ignored by 39 files.

## 9.5 Unwired / undone

- **`pinned_execution.rs` is unwired.** Its only use is `private-backend/src/native_worker.rs:352` (field) and `:365` (`SealedInvocation::new` inside `SealedNative::new`). `git grep` shows no caller of `SealedNative::new` or `receive_sealed` (`:398`) anywhere. The comment says it outright: "the existing CLI uses Legacy" (`:394-397`).
- **Twin:** `resource-client/src/transport.rs:1368-1393` (`HostProcess::sealed_snapshot`) is the same memfd, `fchmod` and seal routine, with the same flag fallback (`0x10`/`0x08`, then `EINVAL` retry), but **without** the size cap, used live by `start_pinned` (`:1348-1352`). A third memfd sealing site exists in `spk-host/src/seccomp.rs:365-390`. Delete one; the shared root file is the one with the bounds, so make `transport.rs` use it, or delete `pinned_execution.rs` together with the dead `SealedNative`.
- **`#![allow(dead_code)]`** in `host-operations.rs:3` is by design (constants for selective use).
- **No versioned siblings** among these files. The v1 suites are refused by name, not kept.

## 9.6 Size and shape

| File | Lines | Tests | Code |
|---|---:|---:|---:|
| `crypto_transit.rs` | 380 | 178 (`:203-380`) | 202 |
| `host-operations.rs` | 376 | 0 | 376 (generated) |
| `hybrid_kem.rs` | 471 | 75 (`:397-471`) | 396 |
| `pinned_execution.rs` | 245 | 72 (`:174-245`) | 173 |
| **Total** | **1,472** | **325** | **1,147** |

Minimal for the demo:
- Keep `host-operations.rs` (376) and `hybrid_kem.rs` (471); `mini` links it for private rooms and protected objects.
- Drop `pinned_execution.rs` (245, uncalled).
- `crypto_transit.rs` (380) is needed only for the traffic-privacy cohort (`pq_mailbox`, `cohort_tcp`, `scheduled_transport` in resource-client, `cfg(unix)`) and private-backend. Drop it if traffic privacy is out of the demo; README Honest state lists traffic privacy as "executed … one host", not deployed.

## 9.7 Deployability on a small public Linux VM

- **On the box:** `/dev/urandom` readable by `mini`, and the AWS-LC static library linked into `mini`, which needs cmake and a C compiler at build time. For `pinned_execution`: `/usr/bin/timeout` and a kernel with memfd seals (3.17+). `MFD_EXEC`/`NOEXEC_SEAL` needs 6.3+, with a fallback.
- **Exposure:** `crypto_transit::open` accepts attacker-supplied ciphertexts up to 256 KiB + 16 with a context up to 72 KiB (`:195-200`, `:138-147`). Each open costs one ML-KEM keygen from the seed (`open` calls `HybridSecret::from_bytes`, `:199`) plus one decapsulation. That is CPU-bounded but not free: a stranger able to submit capsules can force keygen-per-message work. Cache the `HybridSecret` per key.

## 9.8 Questions for the Lean side

1. Should the consent-session operations 220-232 (`Host/ClientConsentCore.lean:369-590`) get their own allocation record, or a section in `protocol/host-operations.json`, so the registry is the single byte authority?
2. Is there a Lean-side statement of the transit or capsule suite (the frame and suite strings, the transcript layout), or are `crypto_transit.rs`'s known answers the only pin?

---

# Chapter 10. The bundle as a whole

## 10.1 What this bundle is

These are eight small crates and four loose files that the larger crates never absorbed. They sort into four groups:

| Group | Members |
|---|---|
| **Shipped** | `compatible-upgrade-custody`, `signed-api-path`, the `launch-gate` manifest, `host-operations.rs`, `hybrid_kem.rs`, `crypto_transit.rs` |
| **Lean-research helpers** | `joint-agreement-crypto` (agreement fixture), `portable-archive` (ResearchWip only) |
| **Offline proof research** | `bend-proof-entropy`, `bend-ir2-proof` |
| **Dead or broken** | `hyperdocument-link-store` (unbuildable twin), `pinned_execution.rs` (uncalled) |

Membership:

| Crate | Workspace member? | Own `Cargo.lock`? | Deliberate? Evidence |
|---|---|---|---|
| joint-agreement-crypto | no (`[workspace]`, `Cargo.toml:5`) | yes (357) | Implicit: pinned `=` versions and a Lean-spawned helper; no comment states why |
| compatible-upgrade-custody | yes (root `Cargo.toml:3`) | no | Deliberate: shared by three members |
| portable-archive | no (`Cargo.toml:5`) | yes (343) | Implicit; `docs/PORTABLE-CONTINUATION.md:68-72` treats it as a separately built helper with a SHA pin |
| signed-api-path | yes | no | Deliberate: shared by spk-host and grain-runtime |
| bend-proof-entropy | no (`Cargo.toml:11`) | yes (111) | Deliberate in effect: edition 2024 and rand 0.10 differ from the workspace |
| launch-gate | no (`Cargo.toml:11`) | yes (7) | Deliberate: `Cargo.toml:1-3` comment and commit `c607ef20` |
| bend-ir2-proof | no (`Cargo.toml:7`) | yes (1178) | Deliberate: `README.md:23` "Avoid whole-workspace builds", external path dependencies |
| hyperdocument-link-store | **neither**: no `[workspace]` table and not a member | yes (7) | **Accidental**: predates the root workspace (`295cab11`, 2026-10-08) and breaks under it |

## 10.2 What the bundle assumes

Unix everywhere, Linux for `pinned_execution` and `launch-gate`. Two external worlds:
- AWS-LC and its versioned symbol, for `hybrid_kem`.
- **breadstuffs**, for `bend-ir2-proof`, through a provisioned symlink and GitHub Plonky3.

Note the irony: the minidregg tree still holds a hard build dependency on the repo it replaces.

## 10.3 Semantic decisions in the bundle

Only one place is a Rust-owned rule with no Lean counterpart: `compatible-upgrade-custody`'s compatibility allowlist and its trust of recorded audit exits (`lib.rs:185-248`, `:269-270`). It is operator-side. `signed-api-path` mirrors Lean (hand twin, `ApplicationSpkPackageIdentity.lean:142-221`). Everything else defers cleanly, and several files say so in their first lines.

## 10.4 Cross-cutting flaws

1. **Durable byte CAS is implemented four times.** `joint-agreement-crypto` `Journal` (`session.rs:135-263`), `portable-archive` `compare_replace` (`durable_file.rs:42-73`), `hyperdocument-link-store` (`lib.rs:142-213`) and `hyperdocument-link-sqlite-store`. Each has its own lock naming, fsync discipline and lost-reply story. Only the SQLite one is deployed.
2. **Memfd sealed execution is implemented three times:** `pinned_execution.rs:21-55`, `resource-client/src/transport.rs:1368-1393` and `spk-host/src/seccomp.rs:365-390`. Only the first is bounded, and it is the one that is unused.
3. **Hand-coded platform constants:** `launch-gate.rs:13` (`O_NOFOLLOW`), `:14-15` (flock), `:226` (syscall 434), `:287` (`prctl` 1/9). The libc crate is available elsewhere in the tree.
4. **Gates that silently stopped running:** `test-hyperdocument-link-local-store.sh [deleted 52c252e3]` and `run-forward-link-e2e-benchmark.sh [deleted 52c252e3]`, since 2026-10-08. The `bend-ir2-proof` README commands do not work on a clean checkout.
5. **Docs that outlived their code:** `QUALIFICATION-R32.txt`, the migration note's retired list, the hyperdocument-link-store README's test claims and the `hybrid_kem.rs` "ONE implementation" claim.

## 10.5 Unwired / twins summary

| Item | Status | Delete? |
|---|---|---|
| `hyperdocument-link-store` | twin of the SQLite store; unbuildable | yes (move the fixture first) |
| `pinned_execution.rs` + `SealedNative` | uncalled; twin of `transport.rs:1368` | delete, or make it the one implementation |
| `bend-ir2-proof` + `bend-proof-entropy` | research; synthetic fixtures; unbuildable without breadstuffs | yes for the demo; keep history in git |
| `portable-archive` | ResearchWip only | yes for the demo |
| `joint-agreement-crypto` | agreement fixture only; no units | keep only if the mesh is demoed |
| `legacy_config.rs` (V2), `for_capacity` (V4) | test-only versioned siblings | go with the crate |
| `signed-api-path::checked_prefix` vs Lean `validApiPrefix` | hand twin | replace with a Lean export later |
| 159 literal operation numbers vs `host-operations.rs` | registry bypass | migrate to constants |

## 10.6 Size and shape of the bundle

| Crate / file | Rust lines | Keep for the demo? |
|---|---:|---|
| joint-agreement-crypto | 709 | drop (unless mesh) |
| compatible-upgrade-custody | 352 | keep |
| portable-archive | 338 | drop |
| signed-api-path | 152 | keep |
| bend-proof-entropy | 92 | drop |
| launch-gate (manifest only) | 0 | keep (optional role) |
| bend-ir2-proof | 782 | drop |
| hyperdocument-link-store | 713 | drop |
| crypto_transit.rs | 380 | conditional (traffic privacy) |
| host-operations.rs | 376 | keep |
| hybrid_kem.rs | 471 | keep |
| pinned_execution.rs | 245 | drop |
| **Total** | **4,610** | **keep 1,351 (+380 conditional); drop 2,879 (62%)** |

Tests and fixtures are 1,198 of 4,610 Rust lines: 124 + 57 + 65 + 73 + 46 + 472 + 106 + 325 (bend-ir2-proof counting `legacy_config.rs` as test-only).

Non-Rust weight that leaves with the dropped crates:
- `Cargo.lock` files: 357 + 343 + 111 + 1,178 + 7 = 1,996 lines
- bend-ir2-proof text and Python: 380 + 265 + 76 + 6 = 727 lines
- hyperdocument-link-store `README.md`: 31 lines
- two scripts: `test-hyperdocument-link-local-store.sh [deleted 52c252e3]` (60) and `run-forward-link-e2e-benchmark.sh [deleted 52c252e3]`

## 10.7 Deployability of the bundle on the Hetzner VM

- **What ships:** custody (in `mini`, `grain-runtime` and `spk-host`), `signed-api-path` (in `spk-host` and `grain-runtime`), `launch-gate` (if grains), `hybrid_kem` and `crypto_transit` (in `mini`), `host-operations.rs` (in `mini`).
- **Build x86-64.** An ARM (CAX) build trips `launch-gate.rs:13`.
- **Never build with `--all-features`** (the `fixture-os` unification, chapter 2.4).
- **The agreement helper's TCP port** must not face the internet if the mesh is ever deployed.
- **No component in this bundle exposes an unauthenticated stranger-facing surface on the demo path,** apart from `crypto_transit::open`'s CPU cost if capsules are accepted from strangers.

## 10.8 Questions for the Lean side (bundle level)

1. Which single durable-CAS physical primitive should Lean's IO layer target? `GenericSimplexIO`, `PortableContinuationArchiveIO`, `DurableReceiverIO` and `HyperdocumentLink*` each assume a different helper.
2. Is there a plan to `@[export]` the small decidable Lean predicates that Rust now twins, such as `validApiPrefix` and a future compatible-transition predicate, so that the twins can be deleted instead of mirrored?
3. Should the allocation record cover every Lean stdio byte namespace (Host, the consent session at 220-232, the agreement helper ops 1-10), or only the Host frame?
