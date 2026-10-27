# mini-sdk (Rust) and mini-sdk-ts (TypeScript): reader report, 2026-10-26

Scope: every file of `native/mini-sdk` (Cargo.toml, 24 `src/*.rs`, 4 Rust tests plus 3 shell
drivers, the `lean-codec/` shim and build script, `examples/`, `golden/`, `tests/fixtures/`) and of
`native/mini-sdk-ts` (package.json, 8 `src/*.ts`, 6 tests, 1 example). Nothing was built or run.
Every claim cites `path:line`. Unprefixed paths are under `native/mini-sdk/`, and `ts/` stands
for `native/mini-sdk-ts/`.

## EXECUTIVE SUMMARY

`minidregg-mini-sdk` is a workspace member (`Cargo.toml:3`). It does two jobs, and they have
very different health.

**(A) A shared native utility layer that production really uses.** `resource-client` and
`discord-entrance` both depend on it (`native/resource-client/Cargo.toml:16`,
`native/discord-entrance/Cargo.toml:29`), and about 80 call sites use it. The utilities are:
decimal/hex canonical spellings, durable publication (`durable.rs`), flock leases (`lock.rs`),
owner-private checks (`private.rs`), the secret loader (`secret.rs`), `/dev/urandom` (`random.rs`),
the ssh operator route (`operator.rs` `Ssh`/`SshPool`/`open_stream`), attempt-directory reading
(`store.rs` `AttemptDir`, `Record`), and `custody::{Standing, Delivery}`. This part is careful,
crash-tested code (fork-and-`_exit` crash tests at `durable.rs:330-398`).

**(B) The "Mini client SDK" proper, which nothing in production calls.** This covers
`flow::Client`, `consent`, `host::LocalHost`, `confirm`/`sign` (the Confirmation gate), `explain`,
`contracts` (typed Intent, InvocationId, lowering), `profile`, `lean_codec` and `wasm`. No crate
outside mini-sdk imports any of them (§5). Resource-client carries its own working twins of this
part (`submit_once` at `native/resource-client/src/main.rs:1888`, `client_consent.rs`,
`transport.rs:1154`). Part B has also drifted from the Lean side:

- **The local Host is launched in the wrong mode.** It is started as `SETTINGS stdio` (`frame.rs:73-75`). Lean's storeless codec authority is `SETTINGS codec` (`Host/Main.lean:6652`, doc at `:1955`), and resource-client already uses `codec` (`client_consent.rs:1015`).
- **The plan-op allowlist lags Lean.** It has 29 opcodes; Lean/resource-client have 31, adding 210 ACTIVITY_PLAN and 215 SEAT_PLAN.
- **The hybrid PQ signer cannot pass consent.** Lean consent requires a 32-byte key (`Host/ClientConsentCore.lean:366`).
- **The admitted-intent fixture is stale.** It still has content schemaVersion 9, which the Host now refuses (commit `eff01705` message). The TS example was moved to 10 but the shared `intent.expected` was not, so `ts/test/examples.test.ts` is red by construction.
- **A charged failure reads as success.** The Host's charged-failure outcome (`type:"confirmed", disposition:"charged"`, `Host/Json.lean:4794-4806`) is classified as a plain `Confirmed` receipt.

`Kernel.Contracts.Intents` (the frame the SDK encodes) has **no Lean receiver**: only the vector
emitter imports it.

`mini-sdk-ts` is **a thin port plus partial twin**, not a separate protocol. It defers the encoder,
canonical JSON, lowering and the hybrid scheme to the Rust core via wasm. It re-implements
derivation, Ed25519, `explain`, the digests and the Attempt state machine natively. Nothing in the
repo imports it, no gate runs its tests, and the native-messaging bridge its docs assume does not
exist.

Demo-minimal: keep part A, about 2.3K non-test lines. Part B (`flow`, `consent`, `host`, `frame`,
`confirm`, `sign`, `explain`, `contracts`, `profile`, `lean_codec`, `wasm`, about 1.5K non-test
lines plus the TS package) can be deleted, or re-wired, without breaking any binary.

---

## 1. What it is and does

### 1.1 Crate shape

- **Features** (`Cargo.toml:20-28`): the default is the offline core (builds for wasm32). `native` adds `libc` and the process/socket/filesystem modules. `lean-codec` (implies `native`) adds the dlopen check. `wasm` adds the wasm-bindgen exports.
- **Library only.** It is `rlib` only, and the reason is documented: cargo artifact-name collisions in a shared target dir (`Cargo.toml:12-17`).
- **No binaries.** There is one example (`examples/intent.rs`).
- **Dependencies are pinned exactly** (`Cargo.toml:32-41`): `blake3 =1.8.4`, `ed25519-dalek =2.2.0`, `fips204 =0.4.6` (ML-DSA-65, pure Rust, seeded), `serde_json =1.0.151` with **`arbitrary_precision`**, `sha2`, `zeroize`, optional `libc`, optional `wasm-bindgen =0.2.127`.
- `lib.rs:68-111` defines a string `Error`, `sha256()`, and re-exports.

### 1.2 Offline core (always compiled)

- **`contracts.rs` (601):** the typed `Intent {actor, request_salt[16], cut}` over six cuts (Observe, Invoke, Reserve, Install, Release, Retire; `:105-112`).
  - `canonical_bytes()` (`:316-385`) hand-encodes Lean's `StreamCodec`: base-255 nat ending in 0xFF; strings as a scalar count plus a nat per scalar; nested-sum tags; frame `DREGG/CONTRACT/INTENT/v1` (`:43`).
  - `InvocationId = SHA-256("DREGG/CONTRACT/INTENT-ID/v1" ‖ bytes)` (`:394-396`).
  - `canonical_json` (`:273-312`) sorts keys, no whitespace, integers ≤2^53 only. `integer_value` (`:226-267`) is the "twin" of Lean `integerValue?`.
  - `Intent::lower` (`:401-431`) turns an Invoke into the Host op-7 authoring JSON. Every other cut refuses (`:402-406`).
  - `spelling` (`:438-517`) is the strict JSON reader used by wasm and the tests.
- **`explain.rs` (238):** renders a human reading of the authoring JSON plus the Host's `inspect plan` JSON, with lines starting `UNKNOWN … do not sign blind` for anything it can't read. The reading ends with a `bound to [intent][plan][headers]` digest line (`:187-197`).
- **`confirm.rs` (96):**
  - headers digest: `"MINI/SDK/HEADERS/v1" ‖ u32 n ‖ (u32 len ‖ h)…` (`:18-28`).
  - confirm digest over invocation, attempt, sha(intent), sha(plan), headers digest, sha(explanation), nonce16 (`:70-80`).
  - `Presented` and `Confirmation` (`:32-96`).
- **`sign.rs` (118):** `ConsentedIntent` exists only if the consent reply equals the request (`:17-22`). `sign_transaction` checks the Confirmation (`:39-45`). `signatures_json` produces the hex list for Host op 9 (`:48-51`).
- **`signer.rs` (250):**
  - The `Signer` trait (`:78-84`), with Ed25519 (code 1) and `HybridSigner` (Ed25519 ‖ ML-DSA-65, code 2; `:115-146`).
  - The ML-DSA context `MINI/SDK/HYBRID/ML-DSA-65/v1` (`:35`), with the deterministic variant (`rnd=0`, `:141`).
  - `verify` (`:150-171`).
- **`profile.rs` (204):** a 64-byte master seed. The key is `blake3::derive_key(path, seed)` with paths `dregg/0` (Bread) and `mini/<gen>`, and `mini/<gen>/ml-dsa-65` for the hybrid (`:20-36`, `:54-64`).
  - `store` (native): `$DREGG_HOME/profiles/<name>.json`, defaulting to `~/.dregg`. Env vars `DREGG_HOME`, `HOME`, `DREGG_PROFILE`, and the file `ACTIVE` (`:93-129`).
  - `create` writes a fresh profile (`:132-150`).
- **`custody.rs` (373):**
  - `Receipt` and `CONFIRMATIONS = installed|replayed|recoveredAfterUncertainResponse` (`:24-35`).
  - `outcome_of` / `classify` / `standing` (`:47-97`).
  - The `Attempt` state machine Drafted→Prepared→Sealed→{Confirmed, Refused, Uncertain, NeverSent} plus `successor` (`:110-206`).
  - `Delivery` for external webhook custody (`:209-268`).
- **`decimal.rs` (204), `hex.rs` (76):** canonical spellings and arbitrary-width arithmetic.
- **`wasm.rs` (115, feature `wasm`):** 13 string-in/string-out exports for the TS SDK (`:24-115`).

### 1.3 Native (feature `native`)

- **`frame.rs` (177):** the local stdio framing `u32 len ‖ op ‖ payload`, with reply op = op or 255 (`:1-5`, `:87-114`). `pair` uses u32 LE framing, `kind` uses u16 LE (`:16-34`).
  - It starts `EXECUTABLE SETTINGS stdio` from absolute paths (`:68-84`) and re-reads the settings file on every call, refusing if it changed (`:88-90`).
  - The cap is 12,102,760 bytes (`:13`).
- **`consent.rs` (101):** client of `minidregg-client-consent`. Ops 220/221/222/224 (`:39-68`) and the `OPERATOR_PLAN_OPS` list of 29 (`:20-21`).
- **`host.rs` (37):** `LocalHost` sends ops 7–11 (author, inspect, signatures, observe-assemble, assemble) over `frame::Process`.
- **`operator.rs` (810):** the operator-socket client.
  - Request frame: `u32 len ‖ ver(1|2) ‖ u32 cfglen ‖ config ‖ [hostSha256] ‖ op ‖ payload` (`:356-373`).
  - Reply frame: op, 255 (Host refusal), or 254 (never forwarded) (`:557-571`).
  - Routes (`:82-85`, `:152-158`):
    - `Unix(path)`: one connection per request, 10 s write timeout, 600 s read deadline (`:399`, `:412-432`).
    - `ssh:DEST`: a hardened `ssh -T -v -o BatchMode=yes -o StrictHostKeyChecking=yes …` (`:129-147`).
  - Requests are written only after ssh's stderr says `Entering interactive session` (`:256-299`). Earlier failures are named and certainly-unsent (`:181-195`); later ones are uncertain and never resent (`:458-506`).
  - `SshPool` caps distinct destinations at 32 (`:520-548`). `open_stream` hands over the raw pipes for the credential relay (`:342-345`). Env var `MINI_SSH` (`:123`).
- **`flow.rs` (100):** `Client{host, consent, operator, key}`.
  - `prepare` runs steps 1–5: author, consent 220, sign, challenge op 4, consent 221, ops 9+10, prepare op 1, inspect plan, consent 222, `Presented` (`:53-75`).
  - `seal` signs under the Confirmation, runs ops 9+11, and retains `call.bin` (`:78-85`).
  - `transmit` runs submit op 2 or lookup op 3, decoding via inspect outcome (`:88-99`).
- **`store.rs` (273):**
  - `atomic_json`, `write_once`, `read_json` (bounded at 16 MiB; corruption is an error, not absence; `:17-45`).
  - `Record` is a JSON record under a non-blocking flock (`:49-76`).
  - `AttemptDir` uses the layout `call.bin`, `outcome.json`, `retry-NNNN.{bin,json,transport.json}`. It provides `seal_call` (create_new plus fsync of every ancestor), numeric-order history, `next_retry`, `standing` and `outcome` (`:79-167`).
- **`durable.rs` (475):**
  - `replace` = temp, fsync, rename, fsync dir.
  - `create_new` = temp, fsync, `hard_link`, fsync dir, unlink temp.
  - `retain_exact` is idempotent create-or-compare.
  - `sync_ancestors` skips traverse-only parents (`:79-90`).
  - Every step has a crash-boundary observer (`:46-60`).
- **`lock.rs` (224):** a `flock(LOCK_EX|LOCK_NB)` lease on an owner-private single-link file. Only the PID that took the lease may unlock it (`:61-114`).
- **`private.rs` (200):** owner-private predicates for dirs, files and sockets, plus `ensure_dir*` (`:20-98`).
- **`secret.rs` (173):** the secret loader. O_NOFOLLOW; checks owner and `0o077` on the open descriptor; returns a `Zeroizing` buffer (`:69-114`).
- **`fsread.rs` (119):** bounded regular-file reader that refuses a file that changes during the read (`:52-73`).
- **`random.rs` (63):** `/dev/urandom` with `read_exact`, and a u128 decimal nonce (`:10-28`).
- **`lean_codec.rs` (100, feature `lean-codec`):** dlopens `libminidregg-intents.so` and binds `mdi_*` from `lean-codec/shim.c` plus `minidregg_intent_encode` / `minidregg_intent_id_preimage` (`:50-73`).
  - `lean-codec/build.sh` links it from `lake build Kernel.Contracts.Intents:o.export` objects, reusing `native/mini-sdk/lean-codec/closure.lean` (`build.sh:21`).

### 1.4 Tests and evidence files

- **`native/mini-sdk/tests/golden.rs`:** `golden/vectors.json` (`MINI_SDK_REGEN=1` rewrites it, `:83-86`) and `golden/lean-intents.json` (56 rows, 27 admitted, printed by `Kernel/Contracts/IntentVectors.lean`). The test requires byte equality and at least 25 admitted and 25 refused rows (`:115-145`).
- **`native/mini-sdk/tests/lean_codec.rs`:** the live check against the Lean export, with a planted one-bit failure (`:81-87`).
- **`native/mini-sdk/tests/examples.rs`:** pins the example output.
- **`native/mini-sdk/tests/ssh.rs`, `native/mini-sdk/tests/ssh_e2e.rs` (`#[ignore]`):** use a real sshd, driven by `native/mini-sdk/tests/ssh-e2e.sh` (starts the Store via `run.sh` and an unprivileged loopback sshd forcing `deploy/shell/mini-socket-proxy`). `ssh-e2e-plant.sh` proves the gate can go red.
- Gate rows are in `scripts/check-rust-tests.sh:204,225,238,246,254,537`.

### 1.5 mini-sdk-ts

- **Package:** `@minidregg/sdk`, private, ESM, requires `node >=23.6` (it runs `.ts` directly), dependencies `@noble/ed25519 2.3.0` and `@noble/hashes 1.8.0` (`ts/package.json`).
- **Build:** `build:core` compiles the Rust crate to wasm32 with `--features wasm` and runs `wasm-bindgen` into `ts/wasm/`, which is gitignored and not present on disk.
- **`ts/src/core.ts`:** loads the core and throws if it is missing, with no fallback (`core.ts:1-5`, `:36-46`).
- **`ts/src/contracts.ts`:** pure wasm calls.
- **`ts/src/profile.ts`:** derives with noble blake3, signs Ed25519 with noble, and does hybrid sign/verify and all verification via wasm (`profile.ts:43`, `:84-95`).
- **`ts/src/explain.ts`:** a full native re-implementation (132 lines). It uses wasm `canonicalJson` for `strOf` and `same`.
- **`ts/src/confirm.ts`:** native digests and gate.
- **`ts/src/custody.ts`:** the Attempt state machine, `outcomeOf`, `classify`.
- **`ts/src/bytes.ts`:** helpers (`u64le` and `isDecimal` are exported but unused by any TS module).

---

## 2. What it assumes of its surroundings (wire cross-check)

### 2.1 Operator socket ops (`protocol/host-operations.json`)

| SDK constant | Code | Lean registry | Status |
|---|---|---|---|
| `op::PREPARE` (`operator.rs:57`) | 1 | AUTHORIZED_PREPARE, public+operator | matched |
| `op::SUBMIT` | 2 | SUBMIT, receiver fnDispatch | matched |
| `op::LOOKUP` | 3 | LOOKUP | matched |
| `op::CHALLENGE` | 4 | OBSERVATION_CHALLENGE | matched |
| `op::QUERY` | 5 | AUTHORIZED_QUERY | matched; **no SDK caller** |
| ssh_e2e DESCRIBE | 0 | DESCRIBE | matched (test only) |
| ssh_e2e op 22 | 22 | APPLICATION_LIFECYCLE_BEGIN_SUBMIT, operator-only | used as the "refused on public socket" probe (`native/mini-sdk/tests/ssh_e2e.rs:117-119`) |
| reply markers 254/255 | | `response_markers` 254 "never forwarded", 255 "Host refusal/outcome envelope" | matched (`operator.rs:557-571`) |

The registry also defines marker 164 ("private ordinary dispatch definitive no-record refusal").
The SDK has no handling for it, so it falls to "unexpected operation" → `Uncertain`
(`operator.rs:568`). That is conservative but unnamed.

### 2.2 Local Host codec ops 7–11 (`host.rs`)

- **Op semantics match.** Lean `pureCodec` serves 7/8/9/10/11 (`Host/Main.lean:1951-1960`, session dispatch `:2043`).
- **Kind framing matches.** `kind()` writes u16 LE width (`frame.rs:28-34`), and Lean `splitKind` reads u16 LE and requires width > 0 (`Host/Main.lean:1862-1869`). Rust does not refuse an empty kind; Lean does.
- **Pair framing matches** (`frame.rs:16-25` vs `Host/Main.lean:1871-1876`).
- **Process mode does not match.** `Process::start` always passes `stdio` (`frame.rs:73-75`). The Host's `stdio` mode starts a full `NativeHostSession` with the pinned signature and fn poll services (`Host/Main.lean:6655-6660`), which needs a Store. The documented storeless "every client's local codec authority" is `codec` (`Host/Main.lean:1951-1955`, `:6652`). Resource-client launches `codec` (`native/resource-client/src/client_consent.rs:1015`). `host.rs:1` says "as a pure codec", but it does not ask for one.

### 2.3 Consent process (`consent.rs` vs `Host/ClientConsentCore.lean`)

- **Ops 220/221/222 match** (`ClientConsentCore.lean:369-380`). Request shape: `pair(intent, pair(key, …))` (`consent.rs:40,47,53`), read via `splitPair` (`ClientConsentCore.lean:356-360`).
- **Key width does not match for the hybrid scheme.** Lean requires `signer.length == 32 && key == signer` (`:366`). The SDK sends `self.key.public_key()` (`flow.rs:61`), which is 1984 bytes for `HybridEd25519MlDsa65` (`signer.rs:63-68`). Every hybrid flow is refused at step 2.
- **Op 224 matches** (`ClientConsentCore.lean:599-606`). The SDK refuses opcodes outside its own list before asking Lean (`consent.rs:59-61`). That list has 29 entries (`:20-21`). Resource-client's list has 31 and adds 210 and 215 (`native/resource-client/src/client_consent.rs:1093-1094`). The registry has both as active plans (`ACTIVITY_PLAN`, `SEAT_PLAN`).
- **Not wrapped by the SDK:** possession 226, Objective 227 (acknowledged at `consent.rs:6-7`), thin consent 230–232, and anchor frames 228/229/233 (`ClientConsentCore.lean:552-597`).
- **Refusal envelope matches.** Lean writes `255 ‖ reason` (`:557`, `:609`), and `frame.rs:109-111` maps a non-matching op to an error carrying the text.

### 2.4 Host JSON keys

- **Lowering output keys are all present in `Host/Json.lean`** (grep counts above zero): `grants`, `nonce`, `purpose{type:"prepare", draft{type:"invoke", command{nonce, subject, targets[], family{route, contextBytes}}}}`, `subject`, and per-target `capability`, `expectedTargetRoot`, `kind`, `observeCapability`, `payload`, `schemaVersion`, `target` (`contracts.rs:416-430`).
- **Explain's `PAYLOAD_TYPES` and `CONTENT_ACTIONS`** (`explain.rs:18-23`) equal Lean `targetPayload` (scalar, content, append, world, kindDefinition, computeFunding, read) and `contentAction` (15 verbs) in `Host/SourceAgreementJson.lean:799-880,1071-1100`. They match today, but they are hand-copied, with no generation and no gate.
- **Outcome JSON:** `type` / `confirmation` / `transactionId` / `eventId` / `acceptedCount` / `worldRoot` match `Host/Json.lean:4785-4793`. The SDK **does not know** the `.charged` variant (`Host/Json.lean:4794-4806`: same `type:"confirmed"`, plus `disposition:"charged"`, `cause`, `causeCanonical`), nor `{"type":"contention"}` (`:4815`). See §4, F3.
- **Plan presentation keys:** `finalizedDraft`, `slots[].signing.{decoded,keyId,keyEpoch,validUntil,footprint}`, `height`, `worldRoot`, `domain` (`explain.rs:164-183`). These exist in `Host/InspectRender.lean:462-463` and siblings.

### 2.5 Rust-only vocabulary with no Lean receiver

- **`DREGG/CONTRACT/INTENT/v1` bytes and the `InvocationId`.** These are defined in Lean (`Kernel/Contracts/Intents.lean:214-228`) and are in the build (`Kernel.lean:189`), but they are imported only by `Kernel/Contracts/IntentVectors.lean:17`. No Host or Kernel receiver decodes them. The Host's own `Kernel.Contracts.InvocationId` is a different thing, `(source, transaction, event)` (`Kernel/Contracts/Identities.lean:76-80`). The SDK's InvocationId and salt never reach the Host: `lower` drops the salt (`contracts.rs:421-430`). This is law-6 territory: a Lean codec whose only consumers are a client-local name and a test.
- **`MINI/SDK/HEADERS/v1`, `MINI/SDK/CONFIRM/v1`** (`confirm.rs:15-16`). These are client-local by design.
- **`MINI/SDK/HYBRID/ML-DSA-65/v1` and algorithm code 2** (`signer.rs:35`, `:48-55`). Lean has only `ed25519Algorithm := 1` (`Compiler/CredentialSignatureAdmission.lean:44`). `native/credential-signature-verifier/src/main.rs:45` says the context is "chosen by Lean", but no Lean definition exists. Only its test pins the string (`mldsa.rs [not in tree]:11`).
- **The `retry-NNNN.*` layout and the standing rule** (`store.rs:81-167`, `custody.rs:73-97`). Lean has an `AttemptId {invocation, ordinal}` type (`Kernel/Contracts/Identities.lean:84-87`) but no classifier.

### 2.6 Environment and filesystem

| Variable or path | Where | Meaning |
|---|---|---|
| `DREGG_HOME`, `HOME`, `DREGG_PROFILE`, `~/.dregg/profiles/{<name>.json,ACTIVE}` | `profile.rs:93-129` | profile store, shared with Bread |
| `MINI_SSH` | `operator.rs:123` | alternate ssh program |
| `MINI_LOCAL_HOST` | named in `host.rs:2` | **not read anywhere in mini-sdk** (resource-client reads it) |
| `MINI_SDK_REGEN`, `MINI_SDK_LEAN_CODEC_LIB`, `MINI_SDK_SSH_TEST_*`, `MINI_SDK_E2E_*` | tests | test configuration |
| `/dev/urandom` | `random.rs:11` | randomness |
| `/bin/sh`, `std::env::temp_dir()` | test fakes | |

No ports are bound and no listeners are created.

---

## 3. Does it decide anything semantic?

1. **What counts as success: `CONFIRMATIONS` and `outcome_of`** (`custody.rs:35`, `:47-58`). Rust decides that `type == "confirmed"` with one of three words plus five string fields is "the exact call is admitted". The Lean counterpart is the `Outcome` constructors behind `Host/Json.lean:4785-4815`, but Lean does not export a "final/admitted" predicate. The rule is rendered in Rust and **already wrong for `.charged`** (F3).
2. **The retry and successor policy** (`custody.rs:188-201`). A new attempt with fresh nonces is permitted from Drafted, Prepared, NeverSent and **Refused**. A lookup is mandated from Sealed and Uncertain. That is exactly README's "a lost reply keeps the original operation and its exact retry". **No Lean counterpart was found** (grep: no attempt classifier in Kernel/ or Host/). This is the most important semantic rule in the crate, and it is Rust-authored, with a TS twin (`ts/src/custody.ts:96-103`).
3. **Retained-history adjudication: `standing`** (`custody.rs:73-85`). "Any known confirmation word anywhere wins; else the newest refusal is terminal; else pending." This is what `resource-client` uses to decide whether a call is admitted (`native/resource-client/src/workspace.rs:4025-4031`). Lean counterpart: none found. Note that it contradicts rule 2 (see F4).
4. **Sent or unsent classification** (`operator.rs:242-299`, `:412-432`, `:458-506`). Rust decides "certainly never reached the Host" from ssh's stderr text (`name_refusal`, `:181-195`) and from the presence of the stderr marker. This is a physical-boundary judgement, so it fits the README carve. But it directly licenses a successor attempt (`NeverSent`→`successor`), so a misclassification is a double-submit risk. The direction is conservative: anything ambiguous becomes `Uncertain`.
5. **Which operator plans are checkable: `OPERATOR_PLAN_OPS`** (`consent.rs:20-21`, `:59-61`). This is a Rust allowlist in front of the Lean check. It should be derived from `protocol/host-operations.json`, and it has already drifted (210, 215).
6. **Domain admission in lowering** (`contracts.rs:412-415`). The client refuses targets "governed by" a domain other than the deployment's. This is an admission-shaped decision. The Host checks domain itself, so it is redundant here and should not be a second authority.
7. **The payload number rule** (`contracts.rs:226-267`). It duplicates Lean `integerValue?` (`Kernel/Contracts/Intents.lean:306`). The vectors hold the two together (`payload-number-*` rows). It is acceptable only because the live Lean check exists (`native/mini-sdk/tests/lean_codec.rs`). It is still a twin by construction, against ATLAS law 13.
8. **Identity binding.** The profile path family (`mini/<gen>`) and the derivation function are Rust/TS-authored (`profile.rs:20-36`). The Host binds keys via consent op 220 (`ClientConsentCore.lean:363-367`), so the authority stays in Lean. This is fine.
9. **Not semantic:**
   - `explain` renders only (it does not decide).
   - The Confirmation gate is a UI discipline, not authority (F7).
   - `durable`, `lock`, `private`, `secret` are physical-boundary concerns.

---

## 4. Flaws, each with a failure scenario

- **F1 — the SDK flow cannot run on a member device.**
  - Scenario: `LocalHost::start(host, settings)` (`host.rs:11-13`) execs `host SETTINGS stdio` (`frame.rs:73-75`).
  - `stdio` opens a Store-backed `NativeHostSession` (`Host/Main.lean:6655-6660`). On a device with no Store it fails at start; with a Store it runs a full session where a codec was meant.
  - Harmed: any third party who adopts `flow::Client`. Resource-client works only because it does not use this (`client_consent.rs:1015` passes `codec`).
- **F2 — the hybrid scheme is refused end to end.**
  - Scenario: `Profile::mini_signer(0, HybridEd25519MlDsa65)` into `Client::prepare`. Consent op 220 receives a 1984-byte key, and Lean refuses with "local intent subject differs from custody signer" (`ClientConsentCore.lean:366-367`).
  - Advertised (`signer.rs:7-13`, `examples/intent.rs`) but undeployable until `docs/SDK-PQ.md`'s Host changes land.
- **F3 — a charged failure is reported as success.**
  - Scenario: an Objective dispatch commits as `.charged` ("the price … was posted, nothing else was written", `Kernel/ObjectiveActivityReceiverCore.lean:2751-2753`). The Host presents it as `{"type":"confirmed","confirmation":"installed","disposition":"charged",…}` (`Host/Json.lean:4803-4806`).
  - `outcome_of` builds `Outcome::Confirmed(Receipt)` (`custody.rs:50-52`), and `Receipt` has no disposition field, so the cause is dropped (`:25-32`).
  - The member's client shows "confirmed" for an effect that did not happen. `standing` (`:73-85`) and resource-client's `retained_attempt_outcome` inherit this. Terminality is correct (no resend), but the success claim is false.
- **F4 — Refused is treated as final in one rule and as overridable in the other.**
  - `standing` says a confirmation after a refusal wins (`custody.rs:78-80`; test at `:348`: `[refused, confirmed, refused]` → Confirmed). That concedes a Host refusal is not always definitive for the exact call.
  - `Attempt::successor` treats Refused as "definite non-admission" and issues fresh nonces (`:188-191`).
  - Scenario: a lookup returns a refusal (for example a transient `tailBound`, `Host/Json.lean:4807-4809`, "certify to resume"). The client takes a successor. The original call later confirms on certification, and the successor is admitted too: two admissions of one intent.
  - Whether this can happen depends on Lean's semantics of `refused` for a retained call (Q2).
- **F5 — a crash after `seal` leaves no recovery path in the SDK.**
  - `Attempt` lives in memory only. `flow::seal` persists `call.bin` (`flow.rs:82`), and `transmit` persists nothing (`flow.rs:88-99`).
  - Nothing reconstructs an `Attempt` from an `AttemptDir`, and nothing writes `outcome.json`/`retry-N.json`. Those are written by resource-client.
  - Scenario: the process dies between submit and reply. On restart the SDK user has `call.bin` but no supported way back to "Uncertain, look up". A naive caller makes `Attempt::first` again: the same InvocationId, but fresh nonces and a new call. That is the double-submit the crate exists to prevent.
- **F6 — profile key material bypasses the crate's own custody rules.**
  - `store::load` uses an unbounded `std::fs::read` that follows symlinks and checks no owner or mode (`profile.rs:104`). The seed then sits in a non-zeroized `Vec` and in a `serde_json::Value` string (`:105-110`). This contradicts `secret.rs:1` ("the ONE loader of secret key material").
  - `store::create` writes directly to the final name (`profile.rs:145-148`). That is exactly the failure `durable.rs:400-417` demonstrates, and against `durable.rs:13` ("Key material goes through these and nowhere else").
  - Scenario: a crash mid-write leaves a truncated `<name>.json`. `create` then refuses the name forever (create_new), and `load` fails "profile seed must be 64 bytes". The identity is wedged until hand-deleted.
- **F7 — the Confirmation gate is not a boundary.**
  - `Presented` fields are public and `confirm(nonce)` is a public method (`confirm.rs:65-67`). Any code holding a `Presented` can mint a valid `Confirmation` without a human. `Signer::sign` is public too.
  - So the gate is a typestate convention. Docs (`lib.rs:1-6`) read like a consent boundary. The wasm and TS export `confirmDigest` and `signRaw` with the seed (`wasm.rs:30-36`, `ts/src/profile.ts:43-45`).
- **F8 — `has_unknown` misses embedded UNKNOWN markers.**
  - `has_unknown` checks only line prefixes (`explain.rs:193`; TS `ts/src/explain.ts:131`). But `hex_field` emits `UNKNOWN non-hex … — do not sign blind` *inside* a `fields()` line (`explain.rs:67`, `:78`, `:106`) and in the family line (`:160`).
  - Scenario: `createAtom payload=XYZ` renders "createAtom … payload=UNKNOWN non-hex "XYZ" — do not sign blind" with `has_unknown == false`. A UI keyed on the flag shows no warning.
- **F9 — the TS example test is red, and the admitted-intent pin is stale.**
  - Commit `eff01705` moved `ts/examples/intent.ts:29` to `schemaVersion: "10"`. `examples/intent.rs:37`, `examples/intent.expected` (bytes `…09ff…`) and the `example-invoke` vector all stay at 9.
  - So `ts/test/examples.test.ts:15-25` cannot pass. No gate runs it (§5).
  - Separately, `native/mini-sdk/tests/golden.rs:98-107` claims to reproduce "a REAL retained intent.json that the native Host … admitted" with schemaVersion 9. Per the same commit message, the current Host refuses v9 content commands (`unsupportedVersion`). The pin proves agreement with a wire that is no longer admitted.
- **F10 — durable leftovers.**
  - A crash leaves `.name.durable-PID-N-NANOS` staging files (`durable.rs:118`), and nothing sweeps them.
  - A crash after `hard_link` and before `remove_file` (`:228-235`) leaves a **second link to a secret** (0600, but a duplicate secret copy). `private::file_ok` would then refuse it as nlink=2 (`private.rs:32`) if it were later checked by name.
  - `create_new` depends on `link(2)`, so on filesystems without hard links every seal and secret write fails.
- **F11 — a dead ssh session can be reported as Uncertain.**
  - `SshChannel::exchange` treats a session as reusable when `try_recv` is `Empty` (`operator.rs:462-467`). If the remote ended but the reader thread has not yet delivered EOF, the write goes to a dead pipe and is reported `Uncertain` (`:484-488`), not `Unsent`. The test sleeps 300 ms to dodge this (`:805`).
  - The direction is safe but costly: it forces a lookup, and in the SDK flow it blocks a successor.
- **F12 — the frame bound is checked on the payload only.**
  - `request` checks `payload.len() < HOST_MAX_FRAME` (`operator.rs:360`), but the frame adds config (≤64 KiB) plus 38 bytes. A near-cap payload is sent and then refused by the server.
  - `Operator::new` reads the config unbounded (`:394`).
- **F13 — workspace feature leakage.**
  - Mini-sdk turns on `serde_json/arbitrary_precision` (`Cargo.toml:37`). Feature unification forces it onto `discord-entrance`, which did not ask for it (`native/discord-entrance/Cargo.toml:30`).
  - `canonical_json` depends on serde_json's Map being a BTreeMap, which requires that `preserve_order` is never enabled anywhere in the build graph (`contracts.rs:294`). Nothing guards this; one future crate enabling it silently reorders every intent's payload JSON.

---

## 5. Unwired, undone, dead, twins

**Unused outside mini-sdk** (grep of `mini_sdk::` and `use mini_sdk` in all of `native/`): `flow`,
`consent`, `host`, `frame` (used only by consent/host), `confirm`, `sign`, `explain`, `contracts`,
`profile`, `lean_codec`, `wasm`, `operator::{Operator, Route, request, classify_reply, op::*}`, and
`custody::{Attempt, classify, outcome_of}` plus `store::AttemptDir::{outcome, call, seal_call}`.

Production uses:

- `decimal`, `hex`, `random`, `durable`, `lock`, `private`, `secret`, `fsread` (via store)
- `operator::{Ssh, SshPool, Failure, open_stream, check_destination}` (`native/resource-client/src/proxy.rs:22`, `transport.rs:128`)
- `store::{Record, atomic_json, read_json, AttemptDir::{standing, next_retry, outcome_files}}` (`workspace.rs:4027`, `main.rs:2441`, `publisher.rs:120`, `discord-entrance/src/server.rs:14`)
- `custody::{Delivery, DeliveryState, Standing}` (`app_document.rs:12`, `mini-discord-mirror.rs:46`)
- `signer` (`cohort_tcp.rs:9`, `main.rs:1671`)

**Twins in sibling crates** (ATLAS law 13):

- **The SDK flow vs resource-client:** `flow::Client` ↔ resource-client `submit_once` (`main.rs:1888`); `consent::Consent` ↔ `client_consent.rs` (`operator_plan` at `:1099`, `plan_operation` at `:1093`); `Operator::call_unix` ↔ `transport.rs::exchange_unix` (`:1154`), the same 254-after-failed-write logic copied (`operator.rs:420-429` vs `transport.rs:1160-1173`).
- **Durable/lock primitives re-done elsewhere, contrary to the "ONE implementation" doc headers** (`durable.rs:1`, `lock.rs:1`, `secret.rs:1`):
  - `pay-watcher/src/main.rs:71-83` (`write_atomic`), `:103-105` (flock)
  - `grain-runtime/src/journal_io.rs:23-50`, `grain-runtime/src/credentials.rs:593-635`
  - `hyperdocument-link-sqlite-store/src/anchor.rs:167-231`
  - O_NOFOLLOW handling in `mini-keys`, `inference-scheduler`, `compatible-upgrade-custody`
- **Inside mini-sdk itself:**
  - `frame.rs::bounded` (`:54-65`) is a second bounded reader beside `fsread::read_regular`, and it follows symlinks.
  - `AttemptDir::call` uses unbounded `fs::read` (`store.rs:107-113`).
  - `custody::classify` and `custody::standing` are two adjudications of one history (`:73-97`).
- **Rust vs TS:** `explain`, digests, the `Attempt` state machine and `classify` are each implemented twice. Only `explain` and the digests are differentially tested (`ts/test/differential.test.ts`). The TS `Attempt` has no differential, and the TS port has no `standing`.

**Stubs and undone items:**

- Only `Invoke` lowers. Observe, Reserve, Install, Release and Retire encode but "have no common native wire yet" (`contracts.rs:398-406`).
- Consent 226/227 are not wrapped (`consent.rs:6-7`). `op::QUERY` has no caller.
- `MINI_LOCAL_HOST` is documented (`host.rs:2`) but never read.
- The TS "native-messaging bridge" (`ts/src/index.ts:6`) exists only in docs.

**Test-only code in the shipped library:** none. Fakes are `#[cfg(test)]` (`frame.rs:117-151`). The `*_with` stage-observer APIs (`durable.rs:197`, `:215`) are public for tests, and resource-client uses them for its own crash tests (`receipt_continuity.rs:5`, `client_consent.rs:765`).

**mini-sdk-ts is an orphan:**

- No file in the repo imports `@minidregg/sdk`. Only docs mention it: `docs/SDK.md`, `docs/design/SDK-DESIGN.md`, `docs/review/2026-10-26-deploy/{WEB-SPK-PUBLIC,AFFORDANCES}.md`.
- No `node_modules` or `wasm/` are present.
- No gate script runs `node --test` (grep of `scripts/`, `.github/`).
- Its one example test is red (F9).

---

## 6. Size and shape

**Line counts** (`wc -l`; "non-test" is the code before the file's first `#[cfg(test)]`):

| File | Total | Non-test | Used in production? |
|---|---|---|---|
| operator.rs | 810 | 572 | partly (ssh route, Failure) |
| contracts.rs | 601 | 526 | no |
| durable.rs | 475 | 287 | yes |
| custody.rs | 373 | 269 | partly (Delivery, Standing) |
| store.rs | 273 | 168 | yes |
| signer.rs | 250 | 172 | yes |
| explain.rs | 238 | 198 | no |
| lock.rs | 224 | 115 | yes |
| decimal.rs | 204 | 146 | yes |
| profile.rs | 204 | 152 | no |
| private.rs | 200 | 99 | yes |
| frame.rs | 177 | 116 | no |
| secret.rs | 173 | 115 | yes |
| fsread.rs | 119 | 74 | yes |
| sign.rs | 118 | 52 | no |
| wasm.rs | 115 | 115 | no (TS only) |
| lib.rs | 111 | 111 | yes |
| consent.rs | 101 | 70 | no |
| flow.rs | 100 | 100 | no |
| lean_codec.rs | 100 | 100 | no (test aid) |
| confirm.rs | 96 | 96 | no |
| hex.rs | 76 | 62 | yes |
| random.rs | 63 | 28 | yes |
| host.rs | 37 | 37 | no |
| **src total** | **5,238** | **~3,780** | |

- Rust tests: 471 lines. Shell: 198 lines. Golden JSON: 726 lines. 81 unit tests.
- TS: 588 lines of src, 335 of tests, 62 in the example.

**Dependency weight:** 34 unique crates in the default normal tree (`cargo tree --offline`). The
heaviest are `fips204` with `sha3`/`rand_core`, and `ed25519-dalek` with `curve25519-dalek`. The
`native` feature adds only `libc`.

**DEMO-MINIMAL cut** (public Hetzner demo: ssh shell, web docuverse, SPK grains, Hermes residents,
PAY, Discord). Every surface reaches mini-sdk only through resource-client and discord-entrance.

- **Keep** (about 2.3K non-test lines): `lib`, `hex`, `decimal`, `random`, `durable`, `lock`, `private`, `secret`, `fsread`, `store`, `custody` (Delivery and Standing only), `signer`, and `operator` (the ssh route; the `Operator`/`Route` struct can go if resource-client keeps its own unix exchange).
- **Delete today without breaking a build:** `flow.rs`, `consent.rs`, `host.rs`, `frame.rs`, `confirm.rs`, `sign.rs`, `explain.rs`, `contracts.rs`, `profile.rs`, `wasm.rs`, `lean_codec.rs`, `lean-codec/`, `examples/`, `golden/`, `tests/{golden,lean_codec,examples}.rs`, the `wasm`/`lean-codec` features, and all of `native/mini-sdk-ts`. That is about 1.5K non-test Rust lines, about 1K TS lines, and 726 lines of JSON. The dependency set does not shrink: `signer` (kept for `cohort_tcp`) still needs `fips204`.
  - The decision is the owner's. Part B is the only client-side home of `explain` and the Confirmation discipline. The alternative to deleting is wiring resource-client onto it and deleting resource-client's twins (law 13: one of the two must go).
- `Kernel/Contracts/Intents.lean` and `IntentVectors.lean` lose their only consumer if `contracts.rs` goes.

---

## 7. Deployability on a small public Linux VM

- **Build:** pure Rust, stable toolchain. `std::path::absolute` (`durable.rs:80`) needs Rust ≥1.79. No C toolchain is needed except for `lean-codec` (leanc plus the Lean toolchain; test only). `--offline --locked` is used by the tests (`native/mini-sdk/tests/examples.rs:12`).
- **System dependencies at runtime:**
  - Unix only (`libc`, `std::os::unix`).
  - `/dev/urandom` (`random.rs:11`).
  - OpenSSH client for the ssh route. It must print `Entering interactive session` under `-v` (`operator.rs:263`). The tests also need `sshd`, `ssh-keygen`, `python3`, `setsid`, and `timeout`.
  - The filesystem must support `link(2)` and directory fsync (`durable.rs:228`, `:63-65`).
- **Ports and privileges:** none. Runs as an unprivileged user. `sync_ancestors` handles root-owned 0711 parents such as `/var/lib/mini/sessions` (`durable.rs:72-90`).
- **Persistent state:** caller-chosen dirs (attempt dirs, custody records, leases), plus `~/.dregg/profiles` if `profile::store` is used.
- **Secrets:** profile seeds (64 bytes, hex JSON) and 32-byte seed files read via `secret.rs`. The rule is owner-private 0600, enforced only on the `secret.rs` path (F6).
- **systemd:** not applicable; it is a library. The consumers (resource-client, discord-entrance) are what get units.
- **Breaks on a fresh Debian box:**
  1. Nothing in part A.
  2. The TS package needs node ≥23.6 (Debian stable ships older), plus the wasm32 target and an exactly matching `wasm-bindgen-cli 0.2.127`.
  3. `lean-codec/build.sh` calls `sha256sum` and `lean --print-prefix` (`build.sh:18`, `:32`). Fine on Debian, irrelevant for the demo.
  4. The ssh-route tests need a known_hosts entry provisioned in advance. Host key checking is strict (`operator.rs:130`).

---

## 8. Questions for the Lean side

1. **Charged.** Should a `.charged` outcome (`Host/Json.lean:4794-4806`) be presented with a `type` other than `"confirmed"`? Or should Lean export the "admitted vs charged-failure vs refused-final vs retry-by-lookup" classification as one function, so that `custody::outcome_of`, `standing`, resource-client's `retained_attempt_outcome` and the TS port stop rendering it?
2. **Is a `refused` answer for a SUBMIT or LOOKUP of an exact retained call final for that call?** If yes, `standing`'s "a later confirmation wins over a refusal" (`custody.rs:78-80`) is dead policy. If no (for example `tailBound` resolving after certification), `Attempt::successor` from `Refused` (`custody.rs:190`) licenses a double admission. Which reasons are final?
3. **Contention.** `{"type":"contention"}` (`Host/Json.lean:4815`): is the exact call definitely not admitted (successor allowed), or must it be looked up?
4. **Host mode.** Is `minidregg-host SETTINGS codec` the only supported client codec mode? If so, can `stdio` refuse codec-only use, so that a client like `host.rs` fails loudly instead of opening a Store session?
5. **Generated allowlist.** Can `protocol/host-operations.json` grow a "consent-checkable plan" flag, so that `OPERATOR_PLAN_OPS` (mini-sdk) and `plan_operation` (resource-client) are generated? Today they disagree on 210 and 215.
6. **`Kernel.Contracts.Intents`.** Is there a planned Host receiver for the `DREGG/CONTRACT/INTENT/v1` frame and its `InvocationId` (for example charging or dedup keyed by it, as `Identities.lean:23` suggests for the coordinate id)? If not, should the codec and its 56 vectors be retired along with `contracts.rs`?
7. **Hybrid keys.** Will Lean define algorithm code 2 and the ML-DSA context string (`docs/SDK-PQ.md`)? If it will not, `HybridSigner` and the 1984-byte key path should not be advertised in the SDK.
8. **Generated vocabulary.** Should `PAYLOAD_TYPES` / `CONTENT_ACTIONS` (`explain.rs:18-23`) be emitted from `Host/SourceAgreementJson.lean` rather than hand-copied?
