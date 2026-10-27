# Shard s2: credential-signature-verifier, mini-keys, hermes-test-provider

| field | value |
|---|---|
| shard | s2, "verifier / key broker / test provider" (three small crates) |
| reviewer | Opus reader, fan-out review of the minidregg Rust crates |
| date | 2026-10-26 |
| method | Every file below read in full with line numbers. Every claim cites `path:line` (paths from the repo root `/Users/ember/dev/minidregg`). No build and no test run (operator rule). `cargo tree --offline -e features -i serde_json` was run once to check feature unification. |
| scratch | `/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/s2/` (empty; nothing needed persisting) |

## Files covered

| crate | file | lines | of which tests |
|---|---|---:|---:|
| credential-signature-verifier | `Cargo.toml` | 18 | 0 |
| | `src/main.rs` | 231 | 0 |
| | `examples/sign-probe.rs` | 41 | 41 (test helper) |
| | `native/credential-signature-verifier/tests/protocol.rs` | 237 | 237 |
| | `native/credential-signature-verifier/tests/sshsig.rs` | 226 | 226 |
| | `native/credential-signature-verifier/tests/serve.rs` | 82 | 82 |
| | `mldsa.rs [not in tree]` | 81 | 81 |
| | `README.md` (context) | 93 | n/a |
| | **Rust total** | **898** | **667 (74%)** |
| mini-keys | `Cargo.toml` | 30 | 0 |
| | `src/lib.rs` | 34 | 0 |
| | `src/main.rs` | 201 | 0 |
| | `src/peer.rs` | 74 | 16 (59-74) |
| | `src/wire.rs` | 191 | 34 (158-191) |
| | `src/client.rs` | 296 | 74 (223-296) |
| | `src/server/mod.rs` | 543 | 0 |
| | `src/server/member.rs` | 323 | 31 (293-323) |
| | `src/server/native.rs` | 112 | 25 (88-112) |
| | `src/server/provider.rs` | 433 | 0 |
| | `src/server/discord.rs` | 171 | 0 |
| | `native/mini-keys/tests/broker.rs` | 485 | 485 |
| | `journey_broker.py` (Python, journey helper) | 78 | 78 (fixture) |
| | **Rust total** | **2,863** | **665 (23%)** |
| hermes-test-provider | `Cargo.toml` | 13 | 0 |
| | `Cargo.lock` | 189 | n/a |
| | `src/main.rs` | 1,777 | 479 (1299-1777) |
| | `README.md`, `.gitignore`, `evidence/2026-09-26/**` (context) | 22 / 1 / ~800 | n/a |
| | **Rust total** | **1,777** | **479 (27%)**; the remaining 1,298 lines are themselves a test fixture |
| **shard** | | **5,538 Rust lines** | |

Context read, not owned: `Compiler/CredentialSignatureIO.lean` (248, whole), `Compiler/NativeCoprocess.lean` (205, whole), `Compiler/CredentialSignatureAdmission.lean:300-380`, `Kernel/PayEnrolReceiver.lean:1205-1222, 1660-1672`, `Host/Main.lean:600-610, 660-668, 2610-2680, 3140-3215, 3575-3610, 7015-7041`, `Host/Json.lean:205-216, 275, 4333-4350`, `protocol/host-operations.json` entry 144, `scripts/check-native-transcripts.sh:1-60`, `scripts/check-rust-tests.sh:125-175, 540-552`, `native/mini-keys/src/credentials/store.rs:1-115, 200-240, 370-800, 985-1200` (the `#[path]` module mini-keys compiles), `native/resource-client/src/keys.rs:25-60`, `native/resource-client/src/key_service.rs:136-160`, `native/resource-client/src/transport.rs:173-239`, `native/mini-sdk/src/signer.rs:155-172`, `deploy/candidate/package.py:50-110, 370-400`, `deploy/candidate/INTERFACES.md:350-362`, `deploy/shell/mini-shell-ssh-credentials` (whole), `deploy/shell/mini-socket-proxy` (grep), `deploy/hermes/README.md:20-75`, `deploy/hermes/mini-hermes.service:1-40`, `deploy/grain-host/install-operator-stack:185-230`, `README.md:87`, the gr-B report (executive summary; credentials and mini-keys paragraphs) and rc-D report sections 1.1, 1.2, S-5, F-8.

## Executive summary (15 lines)

1. **The verifier is in the TCB by design, and Lean says so.** Lean accepts exactly `exit 0`, empty stderr, stdout `verified\n` as "signature valid" (`Compiler/CredentialSignatureIO.lean:42-51`, theorem `positive_response_exact` :221-235); nothing at runtime can detect a binary that lies. Soundness of `verify-sshsig` is a *stated, uninhabited* hypothesis (`Kernel/PayEnrolReceiver.lean:1209-1219`). The only cross-check is an offline gate that replays recorded transcripts (`scripts/check-native-transcripts.sh:1-21`). The binary is pinned by SHA-256 only in deploy scripts (`deploy/candidate/package.py:379-380`), not by the Host.
2. The verifier is small and correct: `verify` = ed25519-dalek 2.2.0 `verify_strict` over opaque bytes (`native/credential-signature-verifier/src/main.rs:28-43`); `verify-sshsig` adds the one SHA-512 Lean lacks (`:85-118`); `serve` is a framed coprocess whose wire agrees byte-for-byte with `Compiler/NativeCoprocess.lean:19-20, 107-145`.
3. **`verify-mldsa` is unwired, and its comment cites a Lean declaration that does not exist.** `main.rs:45-71` and `mldsa.rs [not in tree]` name `CredentialSignatureIO.combineHalves`; no such name exists anywhere in the tree, and no Lean code invokes `verify-mldsa`. The real hybrid conjunction is done in Rust (`native/mini-sdk/src/signer.rs:155-172`). Delete the verb (27 lines plus the `fips204` dependency plus 81 test lines) or wire it.
4. Lean calls `verify` through the long-lived `serve` helper but calls `verify-sshsig` with a fresh `IO.Process.output` fork per check (`Compiler/CredentialSignatureIO.lean:114-115` vs `:137-140`), the exact cost `NativeCoprocess` was written to remove (`Compiler/NativeCoprocess.lean:4-11`).
5. **mini-keys is a second, Rust-only authority domain** (rc-D S-5, confirmed): it verifies member Ed25519 signatures itself (`native/mini-keys/src/server/member.rs:59-82`), keeps per-runner per-UTC-day call counters, per-call token caps and until-height grants (`native/mini-keys/src/credentials/store.rs:1024-1190`), and mints single-use bearer tickets (`server/provider.rs:100-149`). Lean is consulted only for "is this key the subject's current, unrevoked key" via op 144 (`server/native.rs:53-86`).
6. **The grant caps are enforced against the controller's claims, not the request.** `provider-authorize` checks `maxTokens`, `model` and `height` as supplied by the provider-role caller (`server/provider.rs:105-136`), while the ticket binds only the body digest (`:147, 337`); the broker never parses the body, so a buggy or compromised controller can exceed a member's per-call cap, change the model, and ignore `notAfter`.
7. Op 144 is answered by whatever process sits at the configured public socket path; the broker checks no peer uid there (`server/native.rs:60`, contrast `client.rs:116-131`) and the reply is unsigned. Its bytes agree with the Lean arm (`Host/Main.lean:7027-7039`, `Host/Json.lean:4333-4350`), but the Lean reply carries no `publicKey`, so the broker's key-equality check (`native.rs:78`) never fires against the real Host.
8. Member signing bytes are `"mini/member-provider-action/v1\0" ‖ serde_json::to_vec(request)` on both sides (`member.rs:34-38`; `native/resource-client/src/key_service.rs:141-147`). Today's workspace unifies serde_json with `arbitrary_precision` only (no `preserve_order`, checked with `cargo tree`), so keys are sorted and it works; it remains a Rust-to-Rust canonicalization twin (rc-D F-8).
9. DoS surface for any account holding a broker role: 32 global connection slots with no per-uid cap (`server/mod.rs:31, 419-423`); any role holder can make the broker allocate a 20 MiB frame (`mod.rs:473`, `wire.rs:15`); each member action re-hashes the whole Host image up to six times (`member.rs:169-185, 234, 261-276`; the local Host build is 116 MB).
10. Lost-reply: `provider-authorize` counts the day's call before minting the ticket, and tickets live only in memory (`credentials.rs:1069`; `provider.rs:144-147`). A lost reply or a broker restart burns `perDay` calls; a forward whose reply is lost has already spent the member's provider credit, and a retry needs a fresh authorize, so it becomes a second call.
11. Split tenancy is not deployable from this repo alone: `mini-keys.service`, the broker config, the sudoers rule and namespace helper, and the pre-created `_pool`/`_service` namespaces live outside it. The `deploy/hermes/README.md:51-56` install snippet creates a root-owned 0711 credential root, so `mini-keys pool --action set` then fails unless `_pool` is pre-provisioned (`credentials.rs:733-746`). No `docs/evidence` run of the broker exists; README "Honest state" says "compiled; run on no box" (`README.md:87`).
12. Dead and drifted code in mini-keys: `Broker::default_box` (owner 0) is never called; every client loads its config with owner = its own euid (`client.rs:111-113`; `main.rs:66`; five callers in other crates). The comment "Only a root-owned config can say so" (`mod.rs:108-109`) is contradicted by `load_for_broker` (`mod.rs:240-246`). `lib.rs:19` names the provider account `mini-core`; the unit runs as `mini` (`deploy/hermes/mini-hermes.service:27`).
13. `credentials.rs` (1,888 lines, in grain-runtime) is compiled into mini-keys by `#[path]` with `#[allow(dead_code)]` (`server/mod.rs:17-22`). I confirm gr-B: `CredentialStore` executes only in mini-keys (no `CredentialStore` reference outside credentials.rs and mini-keys). It belongs in mini-keys.
14. **hermes-test-provider is a deterministic OpenAI chat-completions *scripted agent*, not a model fake.** It has 12 modes, each a hard-coded plan over Mini MCP tools and fixed resource ids (7003, 8001, 9303) (`native/hermes-test-provider/src/main.rs:34-50, 1264-1278`). Two live journeys use it (J14 `--room-librarian`, JPAY6 `--metered-usage`), plus an optional operator-stack fixture unit. It ships in every candidate only so the journey runner can find it at `$set/bin` (`deploy/candidate/package.py:74-78`; `scripts/pipeline/journey-runner:50` already accepts an override).
15. Minimal demo cut: verifier 898 to about 790 lines (drop mldsa); mini-keys 2,863 to about 2,000 lines if Discord custody and the namespace-helper path are deferred (or keep it whole if BYOK ships); hermes-test-provider out of the shipping set entirely (1,777 lines, plus about 800 lines of in-crate evidence).

---

# Chapter A: `native/credential-signature-verifier`

## A1. What this code is and does

### A1.1 `Cargo.toml` (18)
Package `minidregg-credential-signature-verifier`, one binary of the same name at `src/main.rs` (`Cargo.toml:1-11`). Three exact-pinned dependencies (`Cargo.toml:13-18`):
* `ed25519-dalek = "=2.2.0"`, `default-features = false`, features `std`, `fast`, `zeroize`. The `legacy_compatibility` and `hazmat`/batch features are off, as `README.md:3-6` states.
* `sha2 = "=0.10.9"`, used only for the SSHSIG digest (`Cargo.toml:15`).
* `fips204 = "=0.4.6"` with `ml-dsa-65` only, "the same pin as mini-sdk's signer" (`Cargo.toml:17-18`).

It is a workspace member (root `Cargo.toml` `members`), so its lock file is the root `Cargo.lock`. `README.md:5` says "`Cargo.lock` records the transitive versions", which is true of the root lock. The crate has no lock of its own. A crate-local `target/` directory exists on disk and is git-ignored.

### A1.2 `src/main.rs` (231)

**Data model.** `struct Reply { code: u32, stdout: Vec<u8>, stderr: Vec<u8> }` (`main.rs:11-15`) is used only by `serve` to frame a reply.

**`read_fixed::<N>` (`main.rs:17-26`).** Reads at most `N+1` bytes (`take((N + 1) as u64)`, `:20`) and requires exactly `N` (`try_into`, `:23-25`). It is the bounded reader for keys and signatures; a longer file is refused without being read whole.

**`verify` (`main.rs:28-43`).** Reads a 32-byte key (`PUBLIC_KEY_LENGTH`) and a 64-byte signature, then decodes the key point. A decoding failure is an *input error* (`:31-32`), not `invalid`. It reads the frame unbounded (`fs::read`, `:33`), builds a `Signature` from bytes (`:34`, infallible in dalek 2.x), and answers `b"verified\n"` iff `verify_strict` succeeds, else `b"invalid\n"` (`:38-42`). The comment at `:36-37` states the boundary: "Domain separation, key selection, request binding, revocation, and authority are the Lean caller's responsibility."

**`verify_mldsa` (`main.rs:45-71`).** FIPS 204 ML-DSA-65 over `(public key 1952 bytes, context ≤255 bytes, frame, signature 3309 bytes)` using `fips204::ml_dsa_65::PublicKey::try_from_bytes` and `Verifier::verify(&frame, &signature, &context)` (`:55-70`). The doc comment (`:45-48`) claims "the conjunction is decided by the Lean caller (`CredentialSignatureIO.combineHalves`)". **That declaration does not exist** (grep over the tree finds `combineHalves` only in this file and `mldsa.rs [not in tree]:2`), and no Lean code passes `verify-mldsa`. See A5.

**`ssh_string` / `sshsig_signed_data` (`main.rs:73-93`).** Builds OpenSSH PROTOCOL.sshsig signed data: `"SSHSIG" ‖ string(namespace) ‖ string("") ‖ string("sha512") ‖ string(SHA-512(message))`, with big-endian u32 length prefixes (`:74-78, 85-92`). The hash algorithm is hard-wired to `sha512`. A signature made with `-O hashalg=sha256` therefore verifies `invalid` (fail-closed). The doc says "Lean fixes every other byte (`Kernel.PayEnrolMemo.sshsigSignedData`)" (`:83-84`).

**`verify_sshsig` (`main.rs:95-118`).** Takes a 32-byte key, a non-empty namespace (empty is an input error, `:107-109`), the message (unbounded read, `:110`) and a 64-byte signature, then runs `verify_strict` over the signed data (`:113`).

**`USAGE` and `invoke` (`main.rs:120-148`).** Exact-arity dispatch on `verify` (4 args), `verify-mldsa` (5), `verify-sshsig` (5). Anything else gives exit 2 with the usage text on stderr (`:142`). `Ok` gives exit 0 with the verdict on stdout and empty stderr; `Err` gives exit 1 with empty stdout and `credential signature verifier: {error}` on stderr (`:144-147`).

**`main` (`main.rs:150-163`).** `serve` when argv is exactly `["serve"]` (`:152-154`); otherwise a one-shot `invoke`, write stdout and stderr, and return the code. A stdout write failure turns into `ExitCode::FAILURE` (exit 1, `:158-161`).

**`serve` (`main.rs:165-231`).** The coprocess loop:
* Request: `u32 argc` (1..=64, `MAX_ARGS`, `:178, 191`), then `argc` × (`u32 len` ≤ 64 KiB, `MAX_ARG_BYTES`, `:180, 200`; bytes). All integers are big-endian (`:190, 199`).
* Clean EOF on the argc read means exit 0 (`:187`). Any other framing error means exit 1 *without a reply* (`:188, 192, 197, 201, 205`).
* A request whose argv[0] is `serve` ends the process (`:209-212`).
* `invoke` runs in-process under `catch_unwind`; a panic is reported as code 101 with `credential signature verifier: panicked\n` (`:213-217`).
* Reply: `MDCOPRC1` (8 bytes), `u32 code`, `u64 len`, stdout, `u64 len`, stderr, then flush (`:179, 219-226`). A write failure means exit 1 (`:227-229`).

**State machine.** None beyond the serve loop. The process holds no keys and no database. It reads three or four files per request, all paths chosen by the caller.

**Processes, files, env.** No env vars are read. Files are only those named in argv. stdin, stdout and stderr are used in serve mode.

### A1.3 `examples/sign-probe.rs` (41)
A test-only signer: `SigningKey::from_bytes(&[seed_byte; 32])` (`sign-probe.rs:24`) signs a frame and writes the public key and signature files (`:26-29`). It announces on stderr that the key is public (`:22`). Reachability: no current script calls it. It is referenced only by `README.md:83-93` and by historical evidence manifests (`docs/evidence/2026-09-27-application-birth/...`, `docs/evidence/2026-09-28-participant-key-enrollment/README.md`). It is an example target, so it is never shipped.

### A1.4 `native/credential-signature-verifier/tests/protocol.rs` (237)
The CLI contract for `verify`, run against the built binary (`env!("CARGO_BIN_EXE_...")`, `:8`):
* RFC 8032 §7.1 TEST 1 and TEST 2 (`:90-116`).
* An opaque binary frame, and the same frame with one bit flipped (`:118-127`).
* A wrong key (`:129-136`) and a modified signature (`:138-146`).
* Wrong key and signature lengths give exit 1 (`:148-161`).
* A malformed key point, chosen by asking dalek which repeated-byte pattern fails to decompress, gives exit 1 (`:163-177`).
* A malformed R and a non-canonical S give `invalid` (`:179-191`).
* **The weak-key universal forgery** (identity key, R = identity, S = 0) *is accepted by dalek's non-strict `verify`* and refused by the binary (`:193-211`). This test is the reason `verify_strict` is used.
* I/O failures give exit 1 (`:213-222`), and wrong arity gives exit 2 (`:224-237`).

These are real tests: they exercise the shipped binary and include a control (the non-strict path accepting the forgery).

### A1.5 `native/credential-signature-verifier/tests/sshsig.rs` (226)
A real vector produced by `ssh-keygen` on persvati (`:1-7`):
* It parses the armoured body independently (`:43-70`) and recomputes the signed data, which must equal `SIGNED_DATA`, the same bytes `Kernel.PayEnrolMemo.sshsig_signed_data_fixture` pins (`:25-26, 117-134`).
* Positive case (`:136-140`). Other message, other namespace, other signature and other key are all `invalid` (`:142-168`).
* The plain verb refuses the SSHSIG signature as a raw Ed25519 signature over the message (`:170-177`).
* An empty namespace and a short signature are input errors; wrong arity is usage (`:179-199`).
* The memo's companion "possession" signature verifies under `verify` (`:201-226`).

Note that `:133` uses non-strict `verify` as a fixture cross-check only; the binary path is strict.

### A1.6 `native/credential-signature-verifier/tests/serve.rs` (82)
Runs five requests through one `serve` process and asserts each reply equals the one-shot run's `(code, stdout, stderr)` (`:41-76`). A `["serve"]` request ends the server non-zero (`:77-80`). The fixture directory name uses only the pid (`:43`), so two concurrent runs of this test in one process would collide (cosmetic).

### A1.7 `mldsa.rs [not in tree]` (81)
A good signature verifies. A changed frame, changed context, flipped bit or other key gives `invalid` (`:49-66`). Wrong widths and a context over 255 bytes are input errors (`:68-81`). These tests test the verb, but the verb has no caller (A5).

## A2. What it assumes of its surroundings

**Host protocol.** The verifier speaks no Host operation. Its caller is Lean, through two paths:

| Lean caller | transport | argv | file |
|---|---|---|---|
| `CredentialSignatureIO.verify` | `NativeCoprocess.output` (the `serve` helper) | `verify KEY FRAME SIG` | `Compiler/CredentialSignatureIO.lean:100-117`, call at `:114-115` |
| `CredentialSignatureIO.verifySshsig` | `IO.Process.output` (a fork per call) | `verify-sshsig KEY NS MSG SIG` | `Compiler/CredentialSignatureIO.lean:122-142`, call at `:137-140` |
| (none) | n/a | `verify-mldsa` | no Lean caller |

**Wire agreement (serve).**
* Lean `requestFrame` writes `beBytes 4 args.size` then `beBytes 4 len ‖ utf8` per arg (`Compiler/NativeCoprocess.lean:107-110`). Rust reads `u32 BE argc` then `u32 BE len ‖ bytes` (`main.rs:185-208`). They agree.
* Lean `readReply` expects the 8-byte `MDCOPRC1` tag, `u32` code, `u64` stdout length (≤ 64 MiB `maxField`), stdout, `u64` stderr length, stderr, read in 64 KiB chunks (`NativeCoprocess.lean:61-73, 117-145`). Rust writes exactly this (`main.rs:219-226`). They agree.
* Lean bounds nothing on the request side, but Rust caps argc at 64 and each arg at 64 KiB; the Lean paths are temp-file paths, far below either cap.
* Lean starts the helper as `/bin/sh -c 'exec "$0" serve' BINARY` (`NativeCoprocess.lean:75-80, 147-156`). A failed exchange kills and forgets the helper (`:177-196`), so a Rust framing exit-without-reply becomes `Failure.closed`. The Lean caller's `catch` turns that into `.unavailable` (`CredentialSignatureIO.lean:117`), which is a refusal.
* Doc drift: `NativeCoprocess.lean:12-14` says the helper "runs `<binary> args` as its own child". The Rust helper runs `invoke` in-process, without a fork (`main.rs:213-216`). The observable output is the same; the documentation is wrong.

**Verdict parsing.** `parseOutput` (`CredentialSignatureIO.lean:42-51`): non-zero exit gives `processFailed`, non-empty stderr gives `malformedResponse`, and stdout must be exactly `verified\n` (true) or `invalid\n` (false); anything else gives `malformedResponse`. This matches the README table (`README.md:19-33`) and the Rust (`main.rs:144-147`). Theorems `positive_response_exact`, `parse_ambiguous_refuses` and `parse_stderr_refuses` (`CredentialSignatureIO.lean:221-246`) pin the parse.

**Where the configured binary comes from.** `signatureBinary : String` in the Host deployment settings (`Host/Main.lean:605`) becomes `signature := ⟨settings.signatureBinary⟩` (`Host/Main.lean:665`). The same field exists in `Host/ClientConsentCore.lean:95,145` and `Host/SourceAgreementReader.lean:57,90`. The Host does not hash the binary. Pinning is done by the deploy layer:
* `deploy/candidate/package.py:62` (role `verifier`) and `:379-380` (friend-bundle pin with `sha256`);
* `deploy/candidate/lib.sh:122` (the config's `signatureBinary` must equal the manifest path);
* `deploy/candidate/run.sh:136` (upgrade rewrites `.signatureBinary`);
* `deploy/grain-host/install-operator-stack:100-106` (path and sha256 from the manifest);
* `deploy/spk-host/PROFILE-UPGRADE.md:14`.
`deploy/candidate/INTERFACES.md:358-362` documents only `verify`. `verify-sshsig`, `verify-mldsa` and `serve` are undocumented there.

**Who consumes the verdict.** 87 Lean files reference `CredentialSignatureIO` (grep count). The central path is `CredentialSignatureAdmission.verifyNative`, which runs `config.check` on `prepared.controller.key.publicKey`, `frame` and `signature`; `.ok true` proceeds to `finish` (`Compiler/CredentialSignatureAdmission.lean:310-326`). `receiverVerify` dispatches `.ed25519` to `verify` and `.sshsig ns` to `verifySshsig` (`:341-361`). Direct callers include `Kernel/PayClaimCommand.lean:140`, `Kernel/ParticipantKeyEnrollment.lean:498,515`, `Kernel/SubjectKeyCommitmentAdoption.lean:157,162`, `Kernel/NativeCurrentSigningKey.lean:59`, `Host/ApplicationDispatchReady.lean:46`, `Compiler/CarriedSegmentIO.lean:160` and others listed in the scratch grep.

**OS facilities.** Portable Unix: `std::os::unix::ffi::OsStringExt` in serve (`main.rs:177`). There is no Linux-only code.

**Other crates.** None. The binary also ships in the Linux friend bundle (`deploy/candidate/package.py:99-101, 379-380`), so friends' local Hosts use it too.

## A3. Does it decide anything semantic?

**It decides one thing that Lean trusts without check: "is this Ed25519 (or SSHSIG) signature valid over these bytes under this key".** By design this is the cryptographic oracle, and Lean admits it explicitly:
* `CredentialSignatureIO.lean:19-22`: "This IO boundary does not prove the crypto implementation, process/OS byte transport, or EUF-CMA/key custody."
* `Oracle.io_process` (`CredentialSignatureIO.lean:194-207`) proves only that at `IO` the oracle *is the process*. It does not prove the process correct.
* `Kernel/PayEnrolReceiver.lean:1209-1219` (`SshsigRefinement`) states the soundness of `verify-sshsig` as a parameter: "Stated, not inhabited: Lean has no SHA-512, so it is a parameter." The poles at `:1665-1672` show that a never-accepting verifier refines any relation and that an accept-all one is refused.

This is the correct allocation under ATLAS §7 (Rust owns signing and verification primitives; Lean owns key selection, domain separation and authority). The binary chooses no key, no frame and no domain (`main.rs:36-37`; `README.md:12-17`). **Is a wrong answer detectable?** Not at runtime. A binary that answers `verified\n` to everything would be accepted by every receiver. Defenses:
* (a) The deploy pin (sha256 of the shipped binary, A2). The Host itself does not re-check it.
* (b) `scripts/check-native-transcripts.sh`, an offline gate that re-submits every recorded transcript triple and requires `verified`, plus `invalid` for a one-byte-flipped control, with a self-test that must go red (`check-native-transcripts.sh:1-21`).
* (c) The Rust tests above.

**`verify_strict` vs non-strict.** dalek's `verify` is RFC 8032 verification that tolerates small-order ("weak") public keys and small-order R. `native/credential-signature-verifier/tests/protocol.rs:193-211` shows a universal forgery under the identity key that `verify` accepts. `verify_strict` additionally refuses weak public keys and small-order R and requires canonical encodings, as the README summarises (`README.md:26-30`). So the Host refuses signatures some clients would accept. rc-D F-10 notes that client pre-checks use non-strict `verify`, which is fail-closed but inconsistent.

**The SHA-512 in `verify-sshsig`** is a computation, not a decision: Lean fixes every other byte of the signed data (`main.rs:81-84`; `Compiler/CredentialSignatureIO.lean:10-17`). The hard-wired `"sha512"` is a protocol restriction, and its failure mode is `invalid`.

**ML-DSA.** If `verify-mldsa` were wired, the "both halves" rule would be Lean's. It is not wired. The Rust conjunction that *is* used lives in `native/mini-sdk/src/signer.rs:155-172` (Ed25519 `verify_strict` AND ML-DSA-65), outside this shard, and the Host's fn path trusts `resource-client --fn hybrid-verify-source` for its hybrid check (`Host/Main.lean:3586-3610`). Those are Rust decisions, recorded for the readers of those crates.

## A4. Flaws noticed

* **A-F1 (low, doc and code mismatch): `verify-mldsa` claims a Lean caller that does not exist** (`main.rs:45-48`; `mldsa.rs [not in tree]:1-2`). A reader auditing the hybrid scheme would conclude Lean decides the conjunction. It does not.
* **A-F2 (low, performance and DoS): `verify-sshsig` forks per call** (`Compiler/CredentialSignatureIO.lean:137-140`) while `verify` uses the coprocess. `NativeCoprocess.lean:4-9` measured one fork of a loaded Host at 6.4 ms plus a 7.4 ms exec, growing with Host memory. Whether a stranger can drive this depends on PayEnrol's routes (question Q-A3).
* **A-F3 (informational): unbounded frame and message reads** (`main.rs:33, 65, 110`). The caller owns the size, as `README.md:37-39` says. Through the Host the frame is already bounded by the Host's request bound. Not a problem as deployed.
* **A-F4 (informational): serve exits without a reply on malformed framing** (`main.rs:188-206`). Lean handles that as `Failure.closed` and restarts the helper (`NativeCoprocess.lean:189-196`). This fails closed.
* **A-F5 (informational): panics in serve** are caught and reported as 101 (`main.rs:216-217`). The default panic hook still prints to the helper's stderr, which the Host inherits (`NativeCoprocess.lean:56`). Nothing in `invoke` can panic on input, since every slice width is checked.
* **A-F6 (doc drift):** `deploy/candidate/INTERFACES.md:358-362` documents only `verify`; `NativeCoprocess.lean:12-14` misdescribes the in-process execution.
* There is no key handling (the binary holds public material only), no env, no logging of inputs, and no retry semantics.

## A5. Unwired / undone

| item | evidence | verdict |
|---|---|---|
| `verify-mldsa` verb (`main.rs:45-71`, `invoke` arm `:129-131`) and `mldsa.rs [not in tree]` (81) | no Lean caller; `combineHalves` absent tree-wide; `scripts/check-rust-tests.sh:135` runs only `--test protocol` | **unwired**: delete it, with the `fips204` dependency (`Cargo.toml:17-18`), or wire it with a real Lean `combineHalves` |
| `examples/sign-probe.rs` | no current script references it; only old evidence manifests | dead test helper; keep it only if the transcript-recording workflow needs it |
| `native/credential-signature-verifier/tests/sshsig.rs`, `native/credential-signature-verifier/tests/serve.rs` | not in `scripts/check-rust-tests.sh` (only `verifier-protocol`, `:135`) | real tests, but never run by the gate; add rows |
| TODO/FIXME/`unimplemented!`/`allow(dead_code)` | none in `src/main.rs` | clean |

No twins inside the crate. The Ed25519-verify twins elsewhere (mini-keys `member.rs:73-75`, mini-sdk `signer.rs:161`, resource-client) are recorded in B5.

## A6. Size and shape

| file | lines | role |
|---|---:|---|
| src/main.rs | 231 | the whole product: verify 16, mldsa 27, sshsig 46, usage and invoke 29, main 14, serve 67 |
| examples/sign-probe.rs | 41 | test helper |
| tests (4 files) | 626 | protocol 237, sshsig 226, serve 82, mldsa 81 |
| **total** | **898** | code 231 (26%), tests and helpers 667 (74%) |

Minimal demo version: keep `verify`, `verify-sshsig` (only if PayEnrol self-enrollment is in the demo) and `serve`. Drop `verify_mldsa` and its `invoke` arm (about 31 lines), `mldsa.rs [not in tree]` (81) and the `fips204` dependency. Optionally drop `examples/sign-probe.rs` (41). **About 112 to 153 lines removed, leaving 745 to 786.** If PayEnrol is not in the demo, `verify-sshsig` (about 46 lines) and `native/credential-signature-verifier/tests/sshsig.rs` (226) can also go, but Lean's `receiverVerify` `.sshsig` arm would then need deleting too.

## A7. Deployability on a small public Linux VM

* **Must exist:** `bin/minidregg-credential-signature-verifier` at the path the pinned config's `signatureBinary` names, executable by the Host's account, plus `/bin/sh` (the `NativeCoprocess` launcher, `NativeCoprocess.lean:76`). It needs no user, socket, directory, network or kernel feature. It needs a writable temp dir for the Host's `IO.FS.withTempDir` (`CredentialSignatureIO.lean:106, 128`).
* **Operator-configured:** only the path in the Host config, plus the deploy pin.
* **Dangerous to expose:** nothing. It is not network-facing.
* **Stranger on the internet:** can make the Host run one Ed25519 verify per request that reaches a signature check, serialized under one mutex (`NativeCoprocess.lean:178`). That costs microseconds per verify. `verify-sshsig` costs a fork and exec per call (A-F2).
* **Malicious enrolled member:** same as a stranger. The member chooses the bytes but not the key, which comes from Lean state.

## A8. Questions for the Lean side

* **Q-A1.** Is there, or should there be, a Lean declaration that combines the Ed25519 and ML-DSA halves (the `combineHalves` the Rust cites)? If none is planned, can `verify-mldsa` be deleted?
* **Q-A2.** Why does `CredentialSignatureIO.verifySshsig` (`Compiler/CredentialSignatureIO.lean:137`) use `IO.Process.output` rather than `NativeCoprocess.output` like `verify` (`:114`)? Is it oversight or deliberate?
* **Q-A3.** Which Host receivers reach `receiverVerify`'s `.sshsig` arm, and are they on a public route (`protocol/host-operations.json` `routes`)? That answer bounds A-F2.
* **Q-A4.** Does any Lean code check the SHA-256 of `signatureBinary` at Host start, or is the deploy-script pin the only binding between the configured path and reviewed bytes?
* **Q-A5.** `Transcript` evidence (`CredentialSignatureIO.lean:53-63`) covers only Ed25519 (`receiverVerify .recorded` refuses `.sshsig`, `CredentialSignatureAdmission.lean:353-355`). Is an SSHSIG transcript gate wanted?

---

# Chapter B: `native/mini-keys`

## B1. What this code is and does

`mini-keys` is the key broker. It is one process, running under its own account (`mini-keys`) in "split tenancy", that holds the credential seal key, the sealed per-member provider keys, the operator's pool key and the Discord mirror's webhook URL and bot token. It performs the operations that need those secrets for peers that the kernel names by uid and gid (`src/lib.rs:1-27`). It never returns a secret to a caller (`lib.rs:9`).

### B1.1 `Cargo.toml` (30)
* Package `minidregg-mini-keys`, library `mini_keys` (`Cargo.toml:12-14`).
* Binary `mini-keys` with `required-features = ["server"]` (`:16-19`).
* Feature `server`, the default, enables `ring`, `sha2` and `ed25519-dalek` (`:21-23`).
* Clients take `default-features = false`, giving wire, peer and client with no crypto (`:9-11`). Client crates: resource-client (`Cargo.toml:37`, and `:43` for the full broker in dev-dependencies), grain-runtime (`:28`, `:32`) and discord-entrance (`:32`, `:36`).
* `serde_json = "=1.0.151"` with `arbitrary_precision` (`:27`).

### B1.2 `src/lib.rs` (34)
Module doc with the role table (`lib.rs:16-21`):

| role | who | operations |
|---|---|---|
| `member` | session accounts (group mini-sessions) | `member-action` |
| `provider` | "the Hermes controller (`mini-core`)" | `provider-authorize`, `provider-forward`, `provider-verify-grant`, `provider-selected-choice` |
| `discord` | the Discord mirror's session account | `discord-post`, `discord-read` |
| `operator` | root | `pool` |

It exports `client`, `peer` and `wire`, and `server` under `cfg(feature = "server")` (`lib.rs:29-34`). The `mini-core` name disagrees with `deploy/hermes/mini-hermes.service:27-28` (`User=mini`).

### B1.3 `src/main.rs` (201): the CLI
Verbs (`main.rs:1-13, 131-200`):
* **`serve --config FILE`** runs `server::serve_box` (`:139-143`).
* **`relay [--client-config FILE | --socket S --uid U]`** is the ssh forced command for `mini-provider-credentials-v1`. It opens a broker connection, sends `{"op":"member-action"}` (`:77`) and then splices stdin to the broker and the broker to stdout. Each direction is capped at `4 * MEMBER_FRAME` = 128 KiB and the whole exchange at 35 s (`:74-116`). Upstream buffers are zeroed (`:97`). `drop(up)` does not join the stdin thread; the process exits when `main` returns.
* **`hello`** prints the broker's view of this account (`:149-156`).
* **`pool --action set|revoke|ls [--provider] [--secret FILE|-] [--runner]`** is the operator pool key. The secret is read through `credentials::secret_from_input` (≤ 4100 bytes) (`:118-129`), put into the JSON request, and scrubbed after the call with `unsafe as_bytes_mut().fill(0)` (`:157-182`).
* **`namespace --config BROKER_CONFIG --subject N --public-key HEX`** prints `mini-credential-namespace-v1` metadata for the root namespace helper, reading no key (`:183-198`).

`broker()` (`:51-70`) builds a `Broker` from `--socket` and `--uid`, or loads the client config with owner = **this process's euid** (`:66`), not root, although the comment says "Root's file on a box (the default)" (`:65`).

### B1.4 `src/peer.rs` (74)
`Peer { uid, gid, pid }` (`peer.rs:5-11`). On Linux, `getsockopt(SOL_SOCKET, SO_PEERCRED)` into `libc::ucred` with a length check (`:14-31`). On macOS and the BSDs, `getpeereid` with `pid = -1` (`:33-49`). `euid()` and `egid()` wrap libc (`:51-57`). One test, a socketpair naming this process (`:59-74`). SO_PEERCRED reports the credentials *of the process that called `connect`*, captured at connect time, and **only the primary gid**. Supplementary groups are invisible, which matters for the member rule (B7).

### B1.5 `src/wire.rs` (191)
* **Frame:** little-endian `u32` length, then the body (`wire.rs:1-4, 52-58`). This is **little-endian, unlike the verifier coprocess's big-endian frames**. Two framings in one deployment is a cost but not a bug.
* **Bounds:** `MAX_FRAME = 20 MiB` (`:15`), `MEMBER_FRAME = 32 KiB` (`:18`), `MAX_PROVIDER_RESPONSE = 8 MiB` (`:20`), `MAX_PROVIDER_REQUEST = 1 MiB` (`:22`). An empty frame or one over the bound is refused before the body is read (`:53-55, 94-97`).
* **Timing:** every read and write step re-arms the socket timeouts to the remaining deadline (`:31-40`).
* **Zeroing:** frame buffers are zeroed with volatile writes after write and after parse (`:24-29, 72, 99-101, 110, 117-119`).
* **Responses:** `{"ok":true,...}` or `{"refused":CODE,"detail":TEXT}` (`:6-7, 127-129`).
* **Hex:** `hex` and lowercase-only `unhex` (`:131-156`).
* Three tests (`:158-191`).

### B1.6 `src/client.rs` (296)
* **Client config:** `CLIENT_CONFIG = /etc/mini/keys-client.json`, type `mini-keys-client-v1`, fields exactly `type`, `socket` and `uid`, at most 4096 bytes (`client.rs:17-19, 85-108`).
* **`custody_file`** (`:54-76`): every ancestor and the file itself must be owned by `owner` or root and must not be group- or world-writable. Sticky directories are allowed as ancestors (`:66`). `symlink_metadata` is used, so any symlink in the chain is refused.
* **`Broker::connect`** (`:116-131`): connect with a deadline, then refuse unless the answering peer's uid equals the configured broker uid (`broker-identity`).
* **`Broker::call`** (`:134-140`): one JSON request, one JSON response, through `answer` (`:144-152`).
* **`connect`** (`:161-221`): a non-blocking `AF_UNIX` connect with `poll`, `CLOEXEC`, and retry on `EAGAIN` until the deadline. This keeps a full listener backlog from blocking a caller.
* **`default_box()`** (`:111-113`) loads with owner 0 but is **never called** (B5).
* Four tests (`:223-296`).

### B1.7 `src/server/mod.rs` (543): config, custody, accept loop, roles, audit, dispatch

**`#[path = "../../../grain-runtime/src/credentials.rs"] #[allow(dead_code)] pub mod credentials;`** (`mod.rs:17-22`). The provider table, the sealed per-member store and its seal key: "one source shared with grain-runtime's tests and the `mini key` client's catalogue, executed for custody only here."

**Config `mini-keys-broker-v1`** (`mod.rs:29, 102-234`), at most 16 KiB (`:30`). Fields:
* `socket`, `socketGroup?`, `audit`, `spool`, `singleAccount?`.
* `peers: [{role, uids?, gids?}]`. A rule must name someone (`:179-181`), and only `member` may be admitted by gid (`:182-184`).
* `credentials?: {host, hostConfig, publicSocket, providers, root, key, namespaceHelper?, namespaceHelperSha256?}`. The key must live outside the root (`:193-195`), and the helper is pinned together with its sha (`:196-203`).
* `discord?: {mirror}`.
* Unknown fields are refused (`:160, 175, 190, 218`). Paths must be absolute and free of `/../` (`:129-136`). `sha256` is computed over the raw bytes (`:232`).

**`load_for_broker`** (`mod.rs:240-246`): the config owner must be root or the broker's own euid, and that owner becomes `trust_owner` for every "root-custody" input.

**`roles_of`** (`mod.rs:248-256`): a uid match or a primary-gid match.

**`provider_table`** (`mod.rs:261-267`): owned by root or `trust_owner`, then `credentials::ProviderTable::load`.

**`steady_dir` / `secret_file`** (`mod.rs:271-288`).

**`Ticket { peer, provider, endpoint, body_sha256, secret, expires }`** (`mod.rs:290-297`). `Broker { config, tickets: Mutex<HashMap<String, Ticket>>, audit: Mutex<File>, active: AtomicUsize }` (`:299-304`).

**`Broker::start`** (`mod.rs:342-408`):
* Unless `singleAccount`, it refuses to run as root, refuses a peer rule that names its own uid, and refuses a member rule naming its own primary gid (`:344-354`).
* Seal key: a broker-owned 0600 file of at most 32 bytes in a steady directory (`:356`); `CredentialStore::open` (`:357`); provider table (`:358`); Discord secrets (`:361`).
* Spool: parent must be steady (`:363-364`); the spool directory is created 0700 and must be broker-owned (`:365-373`).
* Audit file: opened append, 0600, `O_NOFOLLOW`, must be broker-owned (`:374-385`).
* Socket: a stale socket of its own is removed (`:388-394`); bind; mode 0600, or 0660 with `chown(-1, socketGroup)` (`:395-404`).
* A `start` audit line records the config sha and `singleAccount` (`:406`).

**`serve`** (`mod.rs:412-431`): one thread per connection. Over 32 active connections, it sends `busy` with a 1 s deadline **on the accept thread** and moves on (`:419-423`).

**`record`** (`mod.rs:434-458`): one JSON line per request with time, peer uid/gid/pid, roles, op and outcome, plus the refusal code and detail clipped to 300 characters. **Audit write errors are swallowed** (`:455-457`).

**`connection`** (`mod.rs:460-535`), step by step:
1. Read the peer; drop silently if unavailable (`:462-465`).
2. If the peer has no roles, answer `peer-not-allowed` (`:466-472`).
3. Read the first JSON frame, up to **20 MiB for any role** (`:473`).
4. Look up the op. An unknown op gives `op-unknown`; an op outside the peer's roles gives `op-not-granted` (`:482-498`).
5. `member-action` owns the stream (`:501-505`).
6. Otherwise dispatch (`:506-527`), audit, and reply with a 10 s deadline (`:532-534`).

`hello` reveals `discordChannel` only to the discord role (`:510-517`).

### B1.8 `src/server/member.rs` (323): the signed key-service exchange

**Protocol** (`member.rs:1-17`; message types `:30-32`):
1. broker → `{"type":"mini-member-provider-challenge-v1","nonce","hostSha256","configSha256","tableSha256"}` (`:242-244`). The nonce is 32 bytes from `ring::rand::SystemRandom` (`:238-241`).
2. member → `{"challenge","owner":{"subject","publicKey"},"action","signature"}`, at most 32 KiB (`:245`).
3. broker → `{"type":"mini-member-provider-result-v1","result","authentication":{requestSha256,keyEpoch,subject,publicKey}}` (`:277-278`), or `{"type":"mini-member-provider-refused-v1","error"}` (`:227-230`).

**`signing_bytes`** (`member.rs:34-38`): `b"mini/member-provider-action/v1\0" ‖ serde_json::to_vec(request_without_signature)`.

**`authenticate`** (`member.rs:59-82`):
* Exact fields (`:60`). The echoed challenge must equal the broker's (Value equality, `:61-63`).
* Owner via `Owner::new`, a canonical decimal subject and 64 lowercase hex (`credentials.rs:474-490`).
* The signature must be exactly 64 bytes of lowercase hex (`:67`). The key point is decoded (`:68-69`).
* **Ed25519 `verify_strict` in Rust** (`:73-75`).
* The request digest is SHA-256 of the signing bytes (`:76`). Scrub (`:77-78`). Then `action` must be an object (`:80`).

**`member_action`** (`member.rs:96-158`):
* `providers` gives the catalogue (`:84-93`).
* `ls` lists the member's namespace.
* `set` requires a `user` row and `Secret::new`, then `store.set` (sealed).
* `grant` takes `runner`, `perCall`, `perDay`, `notAfter` and an optional `model`, adds `ownerEpoch` from the Store, then `Grant::from_json` (perCall 1..1e6, perDay 1..1e5, `credentials.rs:390-408`) and `store.grant`.
* `revoke` takes a provider and an optional runner.
* `choose` takes a signed `Choice` owned by the same owner, then `store.choose`.

**`Binding` / `still`** (`member.rs:160-185`): host image sha, pinned host config bytes, provider table sha and seal-key sha. They are captured at challenge time and **re-checked five times** during the exchange (`:261, 263, 267, 274, 276`).

**`helper_pinned` / `provision`** (`member.rs:187-222`): the namespace helper must pass custody checks and have its pinned sha256 and an exec bit. It is then run via `/usr/bin/sudo -n -- HELPER SUBJECT PUBKEY` with a cleared environment and null stdio, polled until the deadline.

**`exchange`** (`member.rs:224-291`) in order: binding, then challenge, then request, then authenticate.
* Open the store; the table sha must equal the captured one.
* Take the member service lock (`credentials.rs:687-704`).
* `still`, then op 144 for the epoch (`native.rs`), then `still`.
* Optional provision, then `still`.
* Op 144 again; the epoch must be unchanged (`:270-273`). Then `still`.
* `member_action`, then `still`, then reply.

Error codes are `owner-not-current`, `provider-refused` and `member-action` (`:282`). **`_peer` is unused** (`:225`): the acting identity is the signing key, never the uid. That is deliberate, since remote members all arrive through one ssh relay account.

One test, which checks that the signature binds secret, provider, action, nonce and owner (`:293-323`).

### B1.9 `src/server/native.rs` (112): operation 144 client
* `host_sha256` streams the selected Host image, at most 2 GiB (`native.rs:13, 21-37`).
* `host_config` reads the pinned config, at most 64 KiB (`:12, 40-50`).
* **`key_status`** (`:53-67`) builds the public-socket envelope `[2] ‖ u32le(config.len) ‖ config ‖ host_sha(32) ‖ 144 ‖ {"subject","publicKey"}`. It connects to `public_socket` with **no peer-identity check**, writes one LE frame, reads one frame of at most 64 KiB, and requires first byte 144, then parses the JSON.
* `current_epoch` (`:69-86`) requires `type == "subject-key-status-v1"`, `subject` equal, `publicKey` equal *if present*, `isCurrent == true`, `currentRevoked == false`, and `keyEpoch` a canonical decimal string of at most 40 digits.
* One test (`:88-112`), including a `publicKey` mismatch case that the real Host never produces (B2).

### B1.10 `src/server/provider.rs` (433): the provider role and the pool

**`authorize`** (`provider.rs:100-149`), for `kind ∈ {pool, user}`:
* Exact fields (`:105-108`). `maxTokens` is optional; `bodySha256` must be 64 hex (`:111-112`).
* The row is looked up by name and its kind must match (`:118-121`).
* **pool:** `store.pool(provider, runner, maxTokens, caps, utc_day())`, which checks per-call, unseals and counts the call (`credentials.rs:1108-1133`).
* **user:** `owner`, `model` and `height` come from the request. `observed_epoch` hashes the Host image, reads the config and runs op 144 (`:85-92`). Then `authorize_model_epoch(owner, provider, runner, Some(model), Some(epoch), height, maxTokens, utc_day())` (`:133-136`) checks the grant's runner, epoch, model, `height ≤ notAfter`, `maxTokens ≤ perCall`, unseals, and counts the call (`credentials.rs:1024-1071`).
* Mint a 32-byte random ticket id (`:94-98`). Purge expired tickets and insert `Ticket { peer: uid, provider, endpoint, body_sha256, secret, expires: now + 600 s }` (`:141-147`).
* Reply `{ok, ticket, provider, endpoint, route, ownerEpoch, expiresInS}` (`:148`).

**`forward`** (`provider.rs:310-367`): the body is hex, 1 byte to 1 MiB; timeout 1..600 s; max response ≤ 8 MiB (`:311-317`).
* **Ticket path:** remove the ticket (single use) and refuse if it was minted for another uid, has expired, or carries a different body sha (`:320-341`).
* **Homelab path:** the row must be `homelab`, with no bearer (`:342-351`).
* `validate_endpoint` (https, or loopback http, path `v1/chat/completions`, `credentials.rs:207-228`), then `send` (`:354-366`).

**`send`** (`provider.rs:197-306`):
* Spool files `forward-{pid}-{seq}.request|.response|.headers`, created `create_new`, 0600, `O_NOFOLLOW`, with fsync (`:198-211, 157-160`).
* `curl` from the fixed path `/usr/bin/curl` (`mod.rs:34`) with `env_clear`, `--disable`, `--http1.1`, `--proto =https|=http`, `--noproxy * --proxy ""`, `--max-redirs 0`, `--connect-timeout 10`, `--max-time`, `--max-filesize`, a JSON content type, `Accept-Encoding: identity`, `--data-binary @request`, `--dump-header`, `--output`, `--url`, and `--config -` (`:212-236`). `pre_exec` sets `RLIMIT_FSIZE` and `RLIMIT_CORE = 0` (`:237-248`).
* **The bearer reaches curl as a config line on stdin, never in argv or a file** (`:256-265`; `header_config` escapes `\` and `"`, `:171-174`; `Secret` forbids spaces and control bytes, `credentials.rs:79-90`).
* Poll every 20 ms for exit, oversize, `caller_gone` (POLLHUP or a zero-byte `MSG_PEEK`, `:178-189`) or timeout, killing curl if needed (`:269-287`). Read back bounded; clean the spool (`:288-290`).
* If either the headers or the body contains the bearer, return `Withheld` (`:298-303`). `complete = written && curl exit success` (`:304`).
* Reply `{ok, complete, headers: hex, body: hex}`, or `{ok, withheld: true}`, or the refusal `caller-gone` (`:355-366`).

**`verify_grant`** (`provider.rs:369-385`): the grant at the broker-observed epoch, which must equal the caller's `epoch`. No call is counted.

**`selected_choice`** (`provider.rs:387-395`): the member's stored signed choice for a runner and task.

**`pool`** (`provider.rs:397-433`): `set`, which must be a `pool` row; `revoke`; `ls`.

### B1.11 `src/server/discord.rs` (171)
* **Secrets file** `mini-discord-mirror-secrets-v1`, exactly `{type, webhookUrl, channelUrl, botToken}`: a broker-owned 0600 file of at most 8 KiB, re-read on every call (`discord.rs:15, 43-67`). URLs must be `https://` or loopback http, printable, with no `"` or `\` (`:38-41`). The bot token is `[A-Za-z0-9._-]{1,256}` (`:63-65`). `Drop` zeroes the webhook URL and token (`:27-34`).
* **`curl`** helper (`:77-122`): `--config -` on stdin carries the URL and any auth header; output goes to the spool; status comes from `--write-out %{http_code}`.
* **`post {"body": OBJECT}`** (≤ 16 KiB) POSTs to the webhook with `wait=true` (`:125-141`).
* **`read {"before": snowflake|null, "limit": 1..50}`** GETs the channel with `Authorization: Bot TOKEN` (`:149-171`).
* Responses that echo the bot token are withheld (`:137-139, 166-168`).

### B1.12 `native/mini-keys/tests/broker.rs` (485)
A real broker on real Unix sockets with a single uid and `singleAccount` (`:1-8`). Fixtures: a fake HTTP upstream (`:58-75`), a fake Store answering op 144 (`:77-92`) and a full broker config (`:165-176`). Tests:
* `start_refuses_every_unsafe_custody_by_name` (`:229-261`)
* `a_peer_without_a_role_and_an_op_outside_its_role_are_refused_by_name` (`:263-284`)
* `member_keys_are_sealed_by_the_broker_and_never_come_back` (`:286-316`)
* `a_ticket_forwards_one_exact_body_with_the_bearer_the_caller_never_sees` (`:335-377`), including per-day exhaustion, grant expiry and revoked key
* `an_upstream_that_echoes_the_bearer_is_withheld_and_a_kind_mismatch_refuses` (`:379-401`)
* `a_caller_that_hangs_up_stops_the_provider_call` (`:403-422`)
* `the_mirror_posts_and_reads_its_one_channel_without_holding_the_token` (`:424-443`)
* `two_uid_...` (`#[ignore]`, sudo, `:445-485`)

All seven non-ignored tests are rows in `scripts/check-rust-tests.sh:165-175`. The two-uid test is a `sudo_exact` row (`:547-548`). These tests exercise the real server code. The Store, upstream and Discord are fakes, but the broker's decisions are real.

### B1.13 `journey_broker.py` (78)
Starts a single-account broker for journeys. It writes the seal key as 32 random bytes (`:42-45`). The config has `singleAccount: True` and names this uid or gid in all four roles (`:47-53`). It writes a client config and launches `mini-keys serve` (`:56-72`). `pool_set` helper (`:75-78`). Users: `native/grain-runtime/journeys/byok-native.py:139-142`, `native/resource-client/journey.d/jpay6.sh:518-519, 625`, `native/inference-scheduler/native-journey.py:188-190`, `native/inference-scheduler/native-two-member.py:288`. It does not check that the socket appears with the right owner; it only polls for existence (`:65-71`).

### B1.14 Files, sockets, processes, env
* Reads: the broker config, provider table, seal key, the credential root tree, the Host image, the pinned Host config, the Discord secrets, and the namespace helper.
* Writes: the spool (request, response and header files, plus Discord `.in` and `.out`), the audit log, and credential records through `credentials.rs` (`.key`, `.grants.json`, `.usage.json`, `.authority.lock`, `.usage.lock`, `choice-*.json`).
* Sockets: listens on the broker socket; connects to the public socket.
* Children: `/usr/bin/curl` and `/usr/bin/sudo -n`.
* Env: none read by the server. Children get `env_clear` (`provider.rs:215`; `discord.rs:87`; `member.rs:204`).

## B2. What it assumes of its surroundings

**Host protocol op 144 (`KEY_ROTATION_STATUS`).** The registry entry is `code 144`, `routes: ["public","operator"]`, receiver `fnDispatch` (`protocol/host-operations.json:1617`). Lean arm: `Host/Main.lean:7027-7039`.
* Payload: a UTF-8 JSON object, exactly `{subject, publicKey}` via `subjectKeyStatusQuery` (`Host/Json.lean:4344-4350`). `subject` must be a canonical decimal *string* (`nat`, `Host/Json.lean:210-216`), and `publicKey` 32 bytes of hex. Rust sends `{"subject": owner.subject /* String */, "publicKey": HEX}` (`native.rs:59`). **They agree.**
* Reply: `144 ‖ compress(JSON)` with fields `type`, `subject` (decimal string), `keyEpoch` (decimal string, `decimal` = `.str (toString n)`, `Host/Json.lean:275`), `keyId`, `prerotated`, `isCurrent`, `isCommittedNext`, `currentRevoked` (`Host/Json.lean:4333-4342`). On error the reply is `255 ‖ failure` (`Host/Main.lean:7035-7036`). Rust requires first byte 144, else "refused" (`native.rs:63-66`). It reads `keyEpoch.as_str()`, compares `subject` as a string, and requires `isCurrent == true` and `currentRevoked == false` (`native.rs:74-86`). **They agree.**
* **There is no `publicKey` field in the Lean reply.** `native.rs:78`'s check is skipped against the real Host, and the unit test at `native.rs:105-107` tests a shape only the fixture produces. The binding of the answer to the key rests on the query alone (the Host evaluates `keyStatusLoaded ... ⟨subject⟩ publicKey`, `Host/Main.lean:7034`). That is sound if the socket's answerer is the real Host.
* **Envelope:** the broker writes the v2 public-socket envelope `[2] ‖ u32le(len) ‖ config ‖ sha(32) ‖ request` (`native.rs:54-58`). The receiver is resource-client's public socket proxy, `split_envelope` (`native/resource-client/src/transport.rs:173-199`, version 1 or 2, exact config pin, 32-byte sha) and `public_envelope` (`:223-239`). The proxy forwards `[op ‖ payload]` to the Host session (`Host/Main.lean:2660-2680` reads `[u32 len][op][payload]`). The outer framing is the same LE `u32` length frame (`wire.rs:52-58`). The Host-image sha check against the real Host is the proxy's job, which I did not verify (Q-B4).

**OS facilities.**
* Unix sockets, `SO_PEERCRED` (Linux) or `getpeereid` (BSD/macOS) (`peer.rs`).
* `fcntl`, `poll`, `MSG_PEEK` (`client.rs:185-205`; `provider.rs:178-189`).
* `setrlimit` in `pre_exec` (`provider.rs:237-248`); `chown` of the socket (`mod.rs:398-404`).
* `flock` (credentials.rs).
* `/usr/bin/curl` (hard-coded, `mod.rs:34`); `/usr/bin/sudo -n` plus a sudoers rule for the namespace helper (`member.rs:199`).

The crate builds on macOS, but the deployment shape (split tenancy, sudo helper) is Linux.

**Network.** OpenAI-compatible Chat Completions endpoints from the provider table (`validate_endpoint`: https, or loopback http). Discord webhook and channel API URLs from the secrets file. Both are reached through curl only.

**File layouts and configs.**

| path (box defaults) | owner and mode required | checked at |
|---|---|---|
| `/etc/mini/keys/broker.json` (`mini-keys-broker-v1`) | root (or the broker's own uid); no group/other write; ancestors trusted | `mod.rs:240-246`; `client.rs:54-76` |
| `/etc/mini/keys-client.json` (`mini-keys-client-v1`) | **the client's euid** or root (B4 B-F9) | `client.rs:85-108`; `main.rs:66` |
| `/etc/mini/credentials.key` | broker-owned 0600, ≤ 32 bytes, parent steady | `mod.rs:281-288, 356`; `credentials.rs:723-731` |
| `/var/lib/mini/credentials` | root-owned, not group/other writable, whole ancestry (the "rooted" mode), with `_service/`, `_pool/` and per-subject leaves pre-provisioned broker-owned 0700 | `credentials.rs:536-547, 687-704, 733-746` |
| `/etc/mini/providers.json` (`mini-provider-table-v2`) | root (or the config owner) | `mod.rs:261-267` |
| Discord mirror secrets | broker-owned 0600 | `discord.rs:45-46` |
| spool directory, audit file, socket directory | broker-owned; parents steady | `mod.rs:363-387` |

**Other crates.** `credentials.rs` (and `provider_choice.rs`) from grain-runtime, compiled in by `#[path]` (`mod.rs:20-22`; `credentials.rs:32-33`). Clients: resource-client `keys.rs:35-42` (which also compiles `credentials.rs` by `#[path]`), `key_service.rs`, and grain-runtime provider routing (`main.rs:9566-9607`), plus `provider_owner.rs:106` and `provider_provision.rs:106`. The Discord mirror (`discord-entrance/src/bin/mini-discord-mirror.rs:380`).

**Confirming gr-B on custody.** `CredentialStore` appears in no Rust file outside `credentials.rs` and mini-keys (grep over `native/`). grain-runtime uses only the table, owner, grant parser and choice. resource-client uses `Owner`, `Secret`/`secret_from_input`, `provider_name` and `choice` (`keys.rs:41, 73-88, 245, 284`). The sealed store therefore **only ever executes inside mini-keys** and belongs there.

## B3. Does it decide anything semantic?

This crate *is* an authority domain without a Lean counterpart. Each row below is a decision Lean does not make and would not refuse if Rust got it wrong.

| # | where | what Rust decides | Lean counterpart today | blast radius if wrong |
|---|---|---|---|---|
| K-1 | `member.rs:59-82` (`verify_strict`, `:73-75`) | **"This member signature is acceptable"** over a Rust-canonicalized JSON frame (`:34-38`) | none; Lean answers only key currency (op 144) | an acceptance bug lets anyone holding a current key's *public* identity act as that member on provider credentials (set, grant, revoke, choose) |
| K-2 | `native.rs:69-86`; `member.rs:262-273`; `provider.rs:85-92, 377-380` | **"This key is the current owner, so proceed"** from Lean status facts (rc-D S-5). Three copies of the predicate: `native.rs:74-86`, `resource-client/src/key_service.rs:148-158` (not canonical-epoch checked), `key_adoption.rs:91-103` | `SubjectKeyRotation.Status` (via `keyStatusLoaded`, `Host/Main.lean:7034`) supplies facts; the *rule* is Rust | a lax copy (resource-client's accepts any string epoch) diverges from the broker's |
| K-3 | `credentials.rs:1024-1071` via `provider.rs:133-136` | **Grant authorization:** runner equality, owner epoch equality, model equality, `height ≤ notAfter`, `maxTokens ≤ perCall` | none (gr-B BV3) | spend of a member's provider key beyond what they granted |
| K-4 | `credentials.rs:1135-1190` (`count_call`) | **Per-runner per-UTC-day call quota**, against the broker's wall clock (`utc_day`, `:677-683`) | none | quota bypass or exhaustion; a clock step resets the counters |
| K-5 | `credentials.rs:1108-1133` via `provider.rs:124-127` | **Pool spend caps** (per call, per day) on the operator's money | Lean's provider purse meters the route afterwards (gr-B: `Kernel/ProviderRoute.lean`), but the cap itself is Rust | operator overspend before the purse sees it |
| K-6 | `provider.rs:118-121` + table | **Which bearer pays** (the row's `credential` kind) | `Kernel/ProviderRoute.lean:30-35` admits it cannot see the bearer (gr-B BV1) | a member's key used for a pool route, or the reverse |
| K-7 | `provider.rs:331-339` | ticket ownership by uid, expiry and body binding | none | low; this is mechanism, not policy |
| K-8 | `discord.rs:125-171` | which channel the bot token may read and the webhook may post (one configured channel) | none (the mirror is outside Lean) | low |
| K-9 | `mod.rs:248-256, 482-498` | **role by uid or gid** | none; this is OS identity | correct for a broker; Lean has no notion of local uids |

**Where it correctly defers.** Key currency and epoch come from the Host via op 144 and are re-asked before mutation (`member.rs:262-273`). The provider *price* and settlement are not computed here at all; there is no usage parsing anywhere in the crate. The broker never decides whether a Hermes turn is admitted.

**The design test, judged.** Under ATLAS §7 ("Every decision point is a Lean export"), K-1, K-3, K-4 and K-5 are violations. The code is careful, but the authority lives in Rust and in JSON files on a disk Lean does not see. The defensible part is custody: holding secrets and attaching a bearer to an exact body. The policy part (grants, quotas and their expiry against chain height) should be a Lean-admitted resource: a member-signed grant cell whose `notAfter`, `perCall` and `perDay` Lean checks at provider reserve. The broker would then only check a Lean receipt before unsealing. Today `height` is not even observed by the broker (K-3 row; B4 B-F1).

## B4. Flaws noticed

**B-F1 (high for the stated guarantee): grant caps are checked against the caller's claims, not against the request.**
* Where: `provider.rs:105-112, 129-136, 147`. `authorize` takes `maxTokens`, `model` and `height` from the provider-role caller. The ticket binds `body_sha256` only, and `forward` checks only that digest (`:337-339`). The broker never parses the body.
* Consequence: a controller bug, or a compromised `mini` account, can mint a ticket with `maxTokens: 1, model: "m1", height: 0` and forward a body with `max_tokens: 1000000` and `model: "expensive"`. That passes per-call, model scoping and `notAfter`.
* Contradiction: `deploy/hermes/README.md:31-33` says "Hermes asks the broker, which checks your grant". The grant is only as strong as the controller's honesty.
* Fix: parse the body in `forward`, or better, have Lean's provider reserve bind `(model, max_tokens, height)` and let the broker verify a Lean receipt.

**B-F2 (medium): lost replies burn quota, and lost forwards double-spend provider credit.**
* `count_call` runs before the ticket is minted (`credentials.rs:1069, 1131`), and the reply is written with a 10 s deadline whose failure is ignored (`mod.rs:534`). A controller that crashes, or times out reading the reply, consumes a `perDay` call with no ticket.
* Tickets are only in memory (`mod.rs:301`), so a broker restart strands every live ticket (`provider.rs:329` says so) after their calls were counted.
* A `forward` whose reply is lost after curl ran has spent the member's or operator's provider credit. The ticket is consumed (`:328`), so the only retry is a new `authorize` plus `forward`: a second provider call. grain-runtime's send gate prevents re-sending the same permit (gr-B summary item 7), but at the broker level a retry is a second operation.

**B-F3 (medium, DoS by any role holder).**
* (a) The 32-connection cap is global with no per-uid share (`mod.rs:31, 419-423`). Any session account in the member group can hold 32 connections, each up to the 30 s exchange deadline (`mod.rs:461`, `member.rs:226`). That starves the Hermes controller, which gets `busy`.
* (b) The first frame is read with `wire::MAX_FRAME` = 20 MiB before the op is known (`mod.rs:473`), so up to 640 MiB of allocations on a small VM.
* (c) The `busy` refusal is written on the accept thread with a 1 s deadline (`mod.rs:421`), so a non-reading client stalls the accept loop.
* (d) Each member action hashes the Host image once in `binding` and five more times in `still` (`member.rs:169-185, 234, 261, 263, 267, 274, 276`). Each `provider-authorize` for a `user` row hashes it once more (`provider.rs:88`). The local Host build is 116 MB (`.lake/build/bin/minidregg-host`), so about 700 MB of SHA-256 per member action, triggerable in a loop by any member.

**B-F4 (medium): op 144 trusts whoever answers at `publicSocket`.**
* `key_status` uses `crate::client::connect` with no uid check (`native.rs:60`), unlike `Broker::connect` (`client.rs:116-131`). The reply is unsigned.
* An account able to bind or replace the public socket path, depending on its directory's ownership (not checked by the broker; `steady_dir` is not applied to it), can answer `isCurrent: true` with any epoch.
* Impact: revoked keys regain provider authority, including `ownerEpoch`-scoped grants (`credentials.rs:1050-1052`). Mitigation: pin the answering uid (the Host or proxy account) as `Broker` does, or require a Host-signed status.

**B-F5 (medium, deploy): the 0600 socket default locks out every peer under split tenancy.**
* Without `socketGroup` the socket is 0600 broker-only (`mod.rs:396`), so member, provider and discord accounts cannot connect at all. With `socketGroup`, every peer account must be in that group.
* The member rule matches the *primary* gid only (`peer.rs:30`; `mod.rs:80-82, 251`). A session account whose primary group is not the member gid but which has it as a supplementary group can connect and is then refused `peer-not-allowed`.
* Nothing in this repo documents the required group layout (it lives in dregg-infra).

**B-F6 (low to medium): spool residue and plaintext prompts.**
* Request bodies (members' prompts) and responses are written to the spool in plaintext (`provider.rs:200-211`). They are deleted after the call (`:290`), but a broker crash or kill mid-call leaves them forever.
* `Broker::start` creates the spool but never sweeps it (`mod.rs:363-373`). After a crash and pid reuse, `create_new` on `forward-{pid}-{seq}` collides (`provider.rs:199, 158`) and refuses `not-sent` until someone cleans up.
* Discord spool files are created without `O_NOFOLLOW` (`discord.rs:82`), which is harmless in a 0700 broker-owned spool but inconsistent with `provider.rs:158`.

**B-F7 (low): fail-open audit.** A failed audit write is ignored (`mod.rs:455-457`), and so is a serialization failure (`unwrap_or_default`, `:453`). If the audit disk fills, the broker keeps unsealing keys and calling providers with no record. The repo law says refusal must be loud. The broker should refuse operations that cannot be audited.

**B-F8 (low): zeroization gaps.**
* `CredentialStore.key: [u8; 32]` has no `Drop` zeroization (`credentials.rs:520-524`; only `Secret` has `Drop`, `:103-108`). A store is opened per request (`provider.rs:78-81`; `member.rs:255`).
* `binding` reads the whole seal key into a `Vec` to hash it and never zeroes it (`member.rs:175`), up to six times per member action.
* The Discord `read` config string containing the bot token (`discord.rs:163`) is not zeroed; `curl()` zeroes only its own copy (`:105-107`).
* serde_json parse scratch buffers for escaped strings are not zeroed (inherent).

These matter only against memory disclosure of the broker process.

**B-F9 (low, doc and code mismatch): client config custody is "root or me", not "root".**
* Every caller loads the client config with owner = its own euid (`main.rs:66`; `resource-client/src/keys.rs:129`; `grain-runtime/src/main.rs:3474, 9568`; `provider_owner.rs:106`; `provider_provision.rs:106`; `discord-entrance/src/bin/mini-discord-mirror.rs:380`). `Broker::default_box` (owner 0, `client.rs:111-113`) is never called.
* The module doc's claim that an account that could replace the socket still cannot impersonate the broker (`client.rs:6-8`) holds only if the account cannot rewrite its own client config. The code does not enforce that.
* Impact: self-harm only (an account can misdirect itself).

**B-F10 (low): `singleAccount` provenance.** The comment says "Only a root-owned config can say so" (`mod.rs:108-109`), but `load_for_broker` accepts a config owned by the broker's euid (`mod.rs:240-246`), and `singleAccount` disables the never-root and own-uid checks (`mod.rs:344-354`). An account that owns its own config can therefore declare single tenancy. Since only root or the broker can write that config, the risk is misconfiguration, not escalation. The comment is wrong.

**B-F11 (low): latent connection-slot leak.** `active` is decremented after `connection()` returns (`mod.rs:425-428`). A panic in a handler thread never decrements it, and after 32 panics the broker answers `busy` forever. I found no reachable panic: the production `unwrap`s at `member.rs:71, 130-131` follow object checks, and `provider.rs:139` is a guarded `unreachable!`. The pattern is still fragile; a drop guard would fix it.

**B-F12 (low): canonicalization twin (rc-D F-8).** The member signing bytes depend on serde_json map ordering and number formatting on both sides (`member.rs:34-38`; `resource-client/src/key_service.rs:141-147`). `cargo tree --offline -e features -i serde_json` today shows the features `default`, `std` and `arbitrary_precision`, and no `preserve_order`. A future feature unification would silently break every member action (fail-closed).

**B-F13 (informational): the relay.** `relay` does not verify the 35 s total if the broker stalls mid-write, but socket timeouts are set to the remaining time (`main.rs:79-81`), and the byte caps bound it (`:91, 108`).

**B-F14 (informational): Discord post content is unfiltered.** `discord-post` forwards any JSON object (`discord.rs:125-133`), including `@everyone` and `allowed_mentions` overrides. Filtering is the mirror's job (discord-entrance), not the broker's; recorded so that reader can confirm.

## B5. Unwired / undone

| item | evidence | verdict |
|---|---|---|
| `client::Broker::default_box` | defined `client.rs:111-113`; zero callers (grep) | dead; delete it, or make every client use owner 0 on a box |
| `#[allow(dead_code)]` on the `credentials` module | `mod.rs:21` | symptom of the three-way `#[path]` share; move the store into mini-keys |
| split tenancy on a box | `README.md:87`: "compiled; run on no box"; `deploy/hermes/mini-hermes.service:5-6` references `mini-keys.service`, which is not in this repo (grep: only docs mention it) | built, not deployed |
| namespace helper (`namespaceHelper`, `provision`) | `member.rs:187-222`; the helper `mini-credential-namespace` is staged by `native/resource-client/platform-stage-root.py:120, 186-211`; no sudoers file in the repo | built; deploy pieces out of tree |
| `discord` role | used by `discord-entrance/src/bin/mini-discord-mirror.rs:380`; no recorded run | built, unproven on a box |
| broker evidence | `docs/evidence` contains only `traffic-v13/build-mini.log` mentioning mini-keys (grep); `2026-09-30-hermes-keys` predates the broker (controller curl at `9e706986`) | **no recorded end-to-end broker run**; journeys that would exercise it single-account: byok-native.py, jpay6, inference-scheduler native journeys |
| `native.rs` test `other_key` (`:105-107`) | the Host never sends `publicKey` (`Host/Json.lean:4333-4342`) | tests a fixture-only shape |
| two-uid test | `#[ignore]` (`native/mini-keys/tests/broker.rs:447-448`), armed only with sudo (`scripts/check-rust-tests.sh:540-548`) | the split-tenancy property is tested only where sudo exists |

**Twins.**
* **Member signing frame:** `member.rs:34-38` and `resource-client/src/key_service.rs:141-147`. Both are reachable (broker and `mini key`). Move one copy into `mini_keys::wire` and use it from both.
* **Current-key predicate:** `native.rs:74-86`, `resource-client/src/key_service.rs:148-158` (weaker: any string epoch, no `publicKey` check) and `resource-client/src/key_adoption.rs:91-103` (per rc-D). Keep the broker's and export it.
* **Hex:** `wire.rs:131-156` and `credentials.rs:657-675` (non-canonical `unhex` accepts uppercase, `:667-669`). This is gr-B T2.
* **curl transport:** `provider.rs:197-306` and `discord.rs:77-122`. Two differently hardened curl wrappers: Discord has no `--proto`, no `--noproxy` (env is cleared anyway), no `RLIMIT_FSIZE` and no `O_NOFOLLOW`. Merge them into one hardened helper.
* **Ed25519 verify:** `member.rs:73-75`, the verifier binary (`credential-signature-verifier/src/main.rs:38`) and `mini-sdk/src/signer.rs:161`. All three are strict. The broker could call the pinned verifier, but in-process is defensible for a custody process.

No TODO, FIXME, `todo!` or `unimplemented!` in the crate.

## B6. Size and shape

| file | lines | test lines | code |
|---|---:|---:|---:|
| src/lib.rs | 34 | 0 | 34 |
| src/main.rs | 201 | 0 | 201 |
| src/peer.rs | 74 | 16 | 58 |
| src/wire.rs | 191 | 34 | 157 |
| src/client.rs | 296 | 74 | 222 |
| src/server/mod.rs | 543 | 0 | 543 |
| src/server/member.rs | 323 | 31 | 292 |
| src/server/native.rs | 112 | 25 | 87 |
| src/server/provider.rs | 433 | 0 | 433 |
| src/server/discord.rs | 171 | 0 | 171 |
| native/mini-keys/tests/broker.rs | 485 | 485 | 0 |
| **total** | **2,863** | **665 (23%)** | **2,198** |

Plus about 1,206 code lines and 682 test lines of `credentials.rs` (gr-B's count) compiled in by `#[path]`. The broker's real compile surface is about 3,400 code lines.

**Minimal version for the demo.** It depends on whether BYOK ships.
* **No BYOK, pool key only, no Discord mirror:** keep wire, peer, client, `server/mod.rs`, `provider.rs` (authorize pool plus forward) and the `pool`, `serve` and `hello` verbs. Drop `server/member.rs` (323), `server/native.rs` (112), `server/discord.rs` (171), the `relay` and `namespace` verbs (about 70 lines of `main.rs`) and the corresponding broker tests (about 200). **About 875 lines removed, leaving about 1,990**, plus the member half of `credentials.rs`.
* **With BYOK:** keep everything except `discord.rs` (171) and the namespace-helper path (`member.rs:187-222`, about 36 lines), if hosted single-box custody can pre-provision namespaces. **About 210 lines removed.** Alternatively, run single-account and drop nothing.
* Either way, move `CredentialStore` out of grain-runtime into this crate (gr-B: about 1,300 lines leave the controller's compile surface). That shrinks nothing in total but removes three-way `#[path]` compilation and two `#[allow(dead_code)]`.

## B7. Deployability on a small public Linux VM

**What must exist (split tenancy, as designed).**
* Accounts: `mini-keys` (broker), `mini` (Hermes controller, provider role; note `lib.rs:19` says `mini-core`), per-friend session accounts whose **primary** group is the member gid, the Discord mirror's account, and root (operator).
* `mini-keys.service`: **not in this repo**. `deploy/hermes/mini-hermes.service:5-6` assumes it, as does "dregg-infra install.sh does this" (`deploy/hermes/README.md:51`).
* `/etc/mini/keys/broker.json` owned by root with a trusted ancestry; `/etc/mini/keys-client.json`; `/etc/mini/providers.json` owned by root (`mini-hermes.service:21-22` conditions).
* `/etc/mini/credentials.key`: 32 raw random bytes, owned by `mini-keys`, 0600.
* `/var/lib/mini/credentials` root 0711 (`deploy/hermes/README.md:52`) **plus** pre-created `_service/` and `_pool/` leaves (broker-owned 0700), because in rooted mode `directory(..., create=true)` requires an existing broker-owned 0700 leaf and creates nothing (`credentials.rs:733-746`; `member_service_lock_until` requires `_service`, `:687-697`). The README snippet creates neither, so `mini-keys pool --action set` would fail on that box unless dregg-infra's installer does more than the snippet shows (Q-B5).
* For each new friend: the namespace helper via `sudo -n` (`member.rs:198-209`), meaning a sudoers rule for `mini-keys` and the helper's pinned sha in the broker config.
* `/usr/bin/curl` and `/usr/bin/sudo`. A broker-owned socket directory (for example `/run/mini-keys`), with `socketGroup` set and every peer account in it (B-F5). A broker-owned spool and audit directory.
* The public socket the broker queries (`publicSocket`) must be the Host's public proxy (resource-client), reachable by the `mini-keys` account.

**Simplest demo shape.** On one VM, run single-account (`singleAccount: true`) under the `mini` account, the way `journey_broker.py:47-53` does. Every check except the "never root / not my uid" ones still runs, and `hello` and the audit log say `singleAccount` (`mod.rs:450-452, 514-515`). The custody claim degenerates to "the service account can read the keys", which the README already admits for root. The alternative is to defer BYOK entirely and keep only the pool key.

**Operator-configured.** The broker config (paths, peers, socket group), provider table rows and caps, the seal key, the pool key (`mini-keys pool --action set`), the Discord secrets file, and the namespace helper and its sha.

**Dangerous to expose.** The broker socket must never be mounted into a sandbox. Today only bwrap's mount refusal separates the agent from the controller's provider role (gr-B: `deploy/grain-host/bwrap:55-71`; `deploy/hermes/mini-hermes.service:10-11`). The seal key file. The spool (plaintext prompts in flight). The audit log (subjects, providers, body digests; no secrets).

**What a stranger on the internet can exercise.** Nothing directly: the broker is Unix-socket-only. Indirectly:
* Through Hermes, a stranger who can prompt a Hermes grain causes `provider-authorize` and `provider-forward` *by the controller*, bounded by the grant and pool caps.
* Through ssh `mini-provider-credentials-v1`, only accounts with an ssh key on the box (`deploy/shell/mini-shell-ssh-credentials:18-22`), which means friends.

**What a malicious enrolled member can exercise.**
* Their own namespace: set, grant, revoke, choose. A grant can name any runner id (`member.rs:125-138`), which affects only their own key.
* The DoS of B-F3: 32 slots, 20 MiB frames, and about 700 MB of hashing per action.
* Probing: `hello` reveals roles, the config sha and whether credentials and Discord are configured (`mod.rs:514-517`).
* A member cannot read any secret, cannot act for another owner without that owner's signing key (K-1), and cannot reach provider or pool operations (`op-not-granted`, test `native/mini-keys/tests/broker.rs:275-279`).
* A member who also controls the public socket path (B-F4) could resurrect revoked keys.

## B8. Questions for the Lean side

* **Q-B1.** Is there a Lean resource, or a plan for one, for provider-credential grants (per-call tokens, per-day calls, `notAfter` height, model scope, runner), so that the broker could check a Lean receipt instead of `credentials.rs` JSON? If not, should `Kernel/ProviderRoute.lean` state that the grant domain is out of Lean's scope, as it does for the bearer (`:30-35`)?
* **Q-B2.** At provider reserve, does Lean bind the request's `max_tokens` and `model` (the values the broker's per-call and model checks rely on), so that B-F1 is caught upstream? Which declaration?
* **Q-B3.** `SubjectKeyRotation.Status.isCurrent` in the op-144 reply: is it "the *queried* `publicKey` is the subject's current key", or "the subject has a current key"? `Host/Main.lean:7034` passes `publicKey`; please confirm in `NativeHost.keyStatusLoaded`. The broker relies on the former, since the reply has no `publicKey` field.
* **Q-B4.** Does the public socket proxy verify the envelope's 32-byte Host-image sha against the running Host (`resource-client/src/transport.rs:187-195` extracts `pin`), or only parse it? The broker's binding (`member.rs:242-243`) assumes the former.
* **Q-B5.** Out-of-repo (dregg-infra) question: does the installer create `/var/lib/mini/credentials/_service` and `_pool` as `mini-keys` 0700, and install a sudoers rule for the namespace helper? Without these, rooted-mode `pool set` and member `set` fail.
* **Q-B6.** Should op 144 replies be Host-signed, or carry the query's `publicKey`, so that a substituted socket cannot forge currency (B-F4)?

---

# Chapter C: `native/hermes-test-provider`

## C1. What this code is and does

**Not a workspace member.** It has its own `[workspace]` table (`Cargo.toml:9`) and its own `Cargo.lock` (189 lines). Package `mini-hermes-test-provider`, deps `serde_json = "=1.0.151"` and `sha2 = "=0.10.9"` (`Cargo.toml:11-13`), the same pins as the workspace. The separation is deliberate in the sense that the README tells you to `cargo build --release` in the crate (`README.md:5`) and the candidate builder uses `--manifest-path` per crate (`deploy/candidate/build.sh:189`). Nothing would break by making it a member. The separate lock is an unforced second lock file.

**What it fakes.** A loopback-only (`main.rs:1258-1262`) HTTP/1.1 OpenAI-compatible server, single-threaded, one connection at a time (`:1286-1295`), with 15 s read and write timeouts (`:1107-1108`).
* **Routes:** `GET /v1/models` and `/models` list one model, `mini-hermes-protocol-fixture` (`:15, 1144-1149`). `POST /v1/chat/completions` runs a mode-specific planner (`:1150-1246`). Anything else is a 404 JSON error (`:1150-1154`).
* **Request parsing:** a bounded line reader (8 KiB per line, 32 KiB of headers, `:31, 1085-1104, 1119-1125`); `Content-Length` required (`:1155`); `Transfer-Encoding` refused (`:1133-1135`); duplicate `Authorization` refused (`:1136-1141`); body ≤ 8 MiB (`:30, 1156-1158`); then JSON.
* **Responses:**
  * Non-streaming: `chat.completion` JSON with synthetic usage, 1/1/2 or 1/2/3 tokens in the metered modes, or no usage in missing-usage mode (`:1223-1238`).
  * Streaming (`"stream": true`): SSE with one delta chunk (content or tool_calls), one finish chunk, an optional usage chunk with empty `choices`, then `[DONE]` (`:1054-1078`).
  * Errors: a planner refusal gives **409 Conflict** `invalid_request_error` (`:1206-1212`); `--metered-http-422` gives **422** for every completion (`:1183-1190`).
* **Modes** (`enum Mode`, `:34-50`; argv `:1264-1278`):

| mode flag | planner | what it scripts | current consumer |
|---|---|---|---|
| (none) `Scalar` | `reply_for` `:542-581` | read `publication` (object 7003), then publish scalar field 0=1 (or 2=2 if field 0 exists) at the observed root, then stop on a signed receipt | default; old evidence |
| `--metered-usage` | `reply_for` + usage chunk | as Scalar, with synthetic usage, logging `auth=sha256(Authorization)` | **`native/resource-client/journey.d/jpay6.sh:628`** |
| `--metered-missing-usage` | `reply_for`, no usage | metering negative case | README only |
| `--metered-http-422` | none | 422 on every completion | README only |
| `--route-probe` | none | fixed reply; logs the digest of the bearer | `docs/evidence/2026-09-30-hermes-keys/run.sh` |
| `--content-workroom` | `content_reply_for` `:583-654` | read `workroom` (object 8001); create atom 7401, then edit with the exact `before`, then verify | `docs/evidence/2026-09-26-workroom-hermes`, `-terminal-*` |
| `--content-peer-a` / `-b` | `peer_reply_for` `:703-783` | two-peer workroom stages, including a deliberate stale-root attempt that must be refused | **`deploy/grain-host/install-operator-stack:204`** (optional fixture unit), `HOSTED-PAIR.md` |
| `--content-receipt-8801` | `receipt_8801_reply_for` `:371-402` | create, then persist a "model-visible receipt projection" file (`:518-536`) | `docs/evidence/2026-09-26-hermes-provider-strict-8801-linux` |
| `--content-stale-8901` | `stale_8901_reply_for` `:425-516` | capture, stale attempt and fresh retry | none found |
| `--content-birth-9301` | `birth_reply_for` `:221-284` | `mini_create_resource` (family note), then read `note-0` (9303), publish atom 9304, with recovery-receipt resume | none found |
| `--room-librarian` | `room_reply_for` `:852-1046` | four rounds over room tools: `mini_room_ls`, `mini_doc_show`, `mini_stream_tail`, history, `mini_doc_link`, `mini_doc_append`, `mini_say`, and refusal reports | **`native/resource-client/journey.d/j14.sh:295`** |

**Helpers.** Recursive JSON searchers with depth 12 that also parse JSON nested inside strings and Hermes's `<untrusted_tool_result ...>` wrapper (`:80-93, 95-205, 286-369, 404-423`). Recovery-receipt line grammars (`:207-219, 678-701`). `call()` builds an OpenAI tool call (`:538-540`). The log is append-only, one line per event: `models`, `received`, `completion ... stage=...`, `reject ... reason=...`, `route-probe ... auth=...`, `transport-error ...` (`:1080-1083, 1147, 1172, 1180, 1210, 1244, 1290`).

**State.** None across requests except the `RESPONSE_ID` counter (`:32`). Each reply is a pure function of the request's message history ("no memory between attaches", `:845-851`), plus the optional receipt-projection file in 8801 mode (`:1214-1217`).

**Tests** (`:1299-1777`, 18 `#[test]`s). They test the planners against hand-built message histories: the stream framing, each mode's read-then-publish sequence, refusal of bad receipts and stale-root envelopes, and the librarian's four rounds. They exercise the fixture's own logic, which is appropriate for a fixture. They prove nothing about Mini. One row is in the gate: `scripts/check-rust-tests.sh:134` (`hermes-test-provider -- tests::`).

**Other files.** `README.md` (22) documents the modes but has drifted: it says the root is extracted from `view.page.root` (`README.md:18`), while the code reads `/view/cell/root` (`main.rs:102`). `evidence/2026-09-26/**` (about 800 lines, several zero-byte files) is evidence stored **inside the crate** rather than under `docs/evidence`. `native/grain-runtime/README.md:380` links to it.

## C2. What it assumes of its surroundings
* No Host operations. It speaks only OpenAI Chat Completions to an "actual upstream Hermes" ACP agent (`README.md:3`) or to the grain-runtime gateway and broker in tests.
* It assumes Mini's MCP tool names (`mcp__mini_grain__*`, `:65-71`), Mini's JSON result shapes (`kind`, `target`, `view.cell.root`, `entries`, `publicationReceipt`, `confirmed-mini-*-v1`), the controller's recovery-header text (`RECOVERY_HEADER`, `:29`), the Lean refusal string `DeclaredResourceController.Reject.staleTarget` (hex-encoded at `:24`, matched at `:728`), and fixed resource ids from the journey fixtures (7003, 8001, 8802, 7802, 7804, 9302, 9303).
* OS: TCP on loopback, and append-only log files (no `O_NOFOLLOW`, default umask, `:1081`).
* Consumers: J14 and JPAY6 journeys, the optional operator-stack unit, and historical evidence runs. **`native/grain-runtime/journeys/byok-native.py:75` sets `TEST_PROVIDER='UNUSED'`** and runs its own Python fake upstream (`:102-113`). So do `bootstrap-native-controller.py:79` and the inference-scheduler journeys (`native-journey.py:71`, `native-two-member.py:92`). `grain-runtime/hermes-journey.sh` does not reference it.

## C3. Does it decide anything semantic?
Nothing in Mini's sense. It is a scripted stand-in for a model. Its "decisions" (which tool to call, which root to publish against) are inputs that Mini's Lean receivers then admit or refuse; the stale-root modes exist precisely to show Lean refusing (`:724-732, 450-457`). The README is explicit that it "never substitutes for Mini's authority, native receiver, or the unmodified Hermes agent" (`main.rs:1-3`; `README.md:3, 20`). The one place it could mislead is evidence: a journey that only checks the fixture's log line `stage=complete` would be trusting the fixture's parse of a receipt. The README requires the native receipt and readback as well (`README.md:20`).

## C4. Flaws noticed
* **C-F1 (deploy, medium): a test fixture ships in every production candidate.** `ROLES["testProvider"] = "mini-hermes-test-provider"` and it is in `RUST_ROLES` (`deploy/candidate/package.py:74-78, 90`), so it is built, pinned in `SHA256SUMS` and installed under `bin/`. It is not in `REQUIRED` (`:95`). Its reason is journey convenience: "journey-runner product_inputs defaults to $set/bin/<name>" (`package.py:74-76`; `scripts/pipeline/journey-runner:50`, which already honours `MINI_TEST_PROVIDER_BIN`). On a public box it is a dormant loopback HTTP server binary. It is harmless unless started, but it is surface and confusion.
* **C-F2 (low): single-threaded accept with 15 s timeouts** (`:1107-1108, 1286-1295`). One stalled client blocks all others for 15 s. Fine for a fixture; wrong if the operator-stack unit ever serves two controllers on one port.
* **C-F3 (low): log injection.** `reject ... reason={reason}` includes request-controlled text such as the model name (`:545, 1210`), and a newline in it forges log lines. Journeys read these logs (J14 counts `received id=` lines; the hermes-keys evidence reads `auth=`). Only processes that can reach loopback can do this.
* **C-F4 (low): `vec![0; size]` up to 8 MiB per request** (`:1159`). Bounded.
* **C-F5 (doc drift):** `README.md:18` says `view.page.root`; the code uses `view.cell.root` (`:102`). The README does not mention `--content-peer-*`, `--content-receipt-8801`, `--content-stale-8901`, `--content-birth-9301` or `--room-librarian`.
* **C-F6 (hygiene):** evidence lives inside the crate (`native/hermes-test-provider/evidence/2026-09-26/`), with zero-byte files (`publication-before.json`, `publication-after.json`, `tool-settle-outcome.json` and others, per `wc`).

## C5. Unwired / undone
* Modes with no current consumer: `--metered-missing-usage`, `--metered-http-422` (README only), `--content-stale-8901` and `--content-birth-9301` (no reference outside the crate). `--content-receipt-8801`, `--content-workroom` and `--route-probe` appear only in historical evidence. Live consumers: `--room-librarian` (J14), `--metered-usage` (JPAY6), `--content-peer-a/-b` (operator-stack fixture). **About 400 lines of planner code serve no current journey**: birth 64 (`:221-284`), stale 92 (`:425-516`), 8801 69 (`:334-402`), plus their tests.
* No TODOs. `unreachable!` at `:1194` is guarded by the early returns at `:1174-1190`.
* Twin: its JSON-inside-string search (`nested_json` plus the recursive finders) is a private reimplementation of how Hermes wraps MCP results. That is acceptable for a fixture.

## C6. Size and shape

| region | lines |
|---|---:|
| constants, Mode, helpers and searchers (`1-219`) | 219 |
| birth planner (`221-284`) | 64 |
| receipt and ack predicates (`286-369`) | 84 |
| 8801 planner (`371-402`) | 32 |
| stale 8901 (`404-516`) | 113 |
| receipt persistence and call (`518-540`) | 23 |
| scalar planner (`542-581`) | 40 |
| content workroom (`583-654`) | 72 |
| peer planner (`656-783`) | 128 |
| room librarian (`785-1046`) | 262 |
| HTTP, stream, log and line reader (`1048-1104`) | 57 |
| `serve_one` and `main` (`1106-1297`) | 192 |
| tests (`1299-1777`) | 479 |
| **total** | **1,777** |

**Minimal version.** For the demo, **remove it from the shipping set entirely** (`package.py` `ROLES` and `RUST_ROLES`: drop `testProvider`). Build it in the journey runner (or as a `[[bin]]` of a workspace `fixtures` crate, or a workspace `[[example]]`), and set `MINI_TEST_PROVIDER_BIN`. If journeys keep it, drop the four orphan modes (about 400 lines with their tests), leaving about 1,350.

**Could it be a dev-dependency?** Not as a library: J14 and JPAY6 are shell and Python journeys that need a *process* listening on a port in front of a real Hermes or grain-runtime gateway. A Cargo dev-dependency only helps `cargo test`. It could become a workspace member, so there is one lock file (no reason found for the separate `[workspace]`), and be built by the journey tooling rather than the candidate. grain-runtime's own tests already use in-process fake upstreams (gr-B), and byok-native.py uses a Python one, so the Rust fixture is needed only for the scripted Hermes-agent journeys.

## C7. Deployability on a small public Linux VM
* **Must exist:** nothing for the demo. If the operator-stack peer fixture is used, there is a systemd unit with `NoNewPrivileges`, `MemoryMax=128M` and `TasksMax=16`, bound to `127.0.0.1:PORT` (`deploy/grain-host/install-operator-stack:202-226`), and its log directory must be private 0700 (`:205-207`).
* **Dangerous to expose:** it accepts no credentials and makes no outbound calls (`README.md:3`). It refuses non-loopback binds (`main.rs:1258-1262`). Exposing it would at most let someone drive a scripted "model" for a grain whose controller points at it, which on a real box would be a misconfiguration.
* **Stranger or member:** nothing unless a controller is configured to use it as its upstream. The provider table's `validate_endpoint` permits loopback http (`credentials.rs:220-225`), so a table row could point at it.

## C8. Questions for the Lean side
* **Q-C1.** Do any Lean fixtures or acceptance theorems name the fixture's resource ids (7003, 8001, 9303) or the recovery-header text (`RECOVERY_HEADER`, `main.rs:29`)? If the header text changes in the controller, this fixture silently stops matching.
* **Q-C2.** The stale-root modes hard-code the hex of `Minidregg.Kernel.DeclaredResourceController.Reject.staleTarget` (`main.rs:24`) and match on the lower-cased name (`:728`). Is that constructor name a stable wire string, or an incidental `repr`?

---

# Chapter D: the bundle

**What the three crates are.** One TCB oracle (the verifier), one Rust authority domain with custody (the broker), and one test fixture shipped as production (the test provider). Measured against ATLAS §7 and README's "Rust decides nothing semantic":
* **The verifier passes.** It is the narrowest possible oracle, Lean names it as an assumption, and the wire is cross-checked. Remove the unwired ML-DSA verb, and route `verify-sshsig` through the coprocess.
* **The broker fails the test as designed, not by accident.** Grants, quotas, expiry and the payer choice are decided in Rust from JSON files Lean never sees (K-1 to K-6). On top of that, the caps are checked against the controller's word rather than the request (B-F1). For a small public demo, the honest options are:
  * (a) Run the broker single-account with the pool key only, and say "no BYOK on the demo".
  * (b) Keep BYOK but move the grant into a Lean resource that the provider reserve admits, with the broker verifying a Lean receipt before it unseals.
  Option (b) is the coherent end state. Option (a) is the finite-prefix step.
* **The test provider** should leave the candidate and live with the journeys.

**Deletion and rewire list from this shard (lines removed in parentheses):**
1. Verifier: delete `verify-mldsa` and `mldsa.rs [not in tree]`, and drop `fips204` (about 112). Add gate rows for `native/credential-signature-verifier/tests/sshsig.rs` and `native/credential-signature-verifier/tests/serve.rs`. Lean: `verifySshsig` via `NativeCoprocess.output`. Fix the `NativeCoprocess.lean:12-14` and `INTERFACES.md:358` docs.
2. Broker: delete `Broker::default_box` (3) or use it. Fix the comments at `mod.rs:108-109`, `lib.rs:19` and `main.rs:65`. Add a uid pin for `publicSocket`. Add per-uid connection caps and read the first frame at a small bound before the op is known. Hash the Host image once per exchange and compare by (dev, inode, mtime, size) for the `still` re-checks. Make audit failure a refusal. Sweep the spool at start. Add a drop guard for `active`. Merge the two curl wrappers. Move `signing_bytes` and `current_epoch` into `mini_keys::wire` for resource-client to share.
3. Move `CredentialStore` from `grain-runtime/src/credentials.rs` into mini-keys (gr-B §6.3), and keep the table, owner, grant and choice parsers in a shared non-crypto module.
4. Test provider: drop `testProvider` from `deploy/candidate/package.py:74-78, 90`; build it in `scripts/pipeline/journey-runner`; move `evidence/2026-09-26` under `docs/evidence`; drop the four orphan modes (about 400).

**Combined weight.** The three crates are 5,538 Rust lines. After the cuts above and the demo-shape choices: about 790 (verifier) + about 2,000 to 2,650 (broker, depending on BYOK and Discord) + 0 shipped (test provider; about 1,350 retained as a journey fixture). That is **about 2,800 to 3,450 lines on the box, from 5,538**.

**What a stranger can do to these three on a public VM:** nothing directly. All three are local: an argv and stdin helper, a Unix-socket broker, and a loopback fixture. Every exposure is through the Host (signature checks, cheap except the SSHSIG fork) and through Hermes prompts (provider spend bounded by grant and pool caps, which the controller states and the broker trusts).

**Summary of questions for Lean:** Q-A1 to Q-A5, Q-B1 to Q-B6, Q-C1 to Q-C2, above. The most consequential are Q-B1 and Q-B2 (where provider-credential authority should live, and whether Lean binds `max_tokens` and `model` at reserve) and Q-A4 (whether anything but deploy scripts binds `signatureBinary` to reviewed bytes).
