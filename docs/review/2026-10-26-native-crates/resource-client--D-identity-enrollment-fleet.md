# resource-client shard D: identity, keys, enrollment, sessions, fleet, consent, shares, laws

| | |
| --- | --- |
| Shard | resource-client D, "identity, keys, enrollment, sessions, fleet, consent, shares, laws" |
| Crate | `native/resource-client` (package `minidregg-resource-client`, binary `mini`, `native/resource-client/Cargo.toml:1-13`) |
| Date | 2026-10-26 |
| Reader | Opus reader, read-only. No build or test was run. Line numbers are from the working tree at `a0db11f8`. |
| Files | 25 Rust sources plus the generated `native/host-operations.rs` (table below) |
| Total lines | 19,300 Rust lines in the shard, plus 376 generated lines, 19,676 in all. About 5,060 are `#[cfg(test)]`. |

Files covered, all under `native/resource-client/src/`: `keys.rs` (511), `key_service.rs` (396), `key_rotation.rs` (903), `key_rotation_custody.rs` (135), `key_adoption.rs` (1,361), `participant_enrollment.rs` (2,044), `participant_namespace.rs` (947), `participant_provisioning.rs` (544), `session_enrollment.rs` (600), `session_reenroll.rs` (1,150), `enrollment_bootstrap.rs` (1,553), `fresh_onboarding.rs` (706), `fleet.rs` (1,476), `fleet_sign.rs` (947), `client_consent.rs` (1,130), `member.rs` (730), `member_app.rs` (415), `seat.rs` (234), `share_issue.rs` (711), `share_issue_receipt.rs` (352), `grain_share_issue.rs` (738), `current_birth.rs` (364), `can.rs` (479), `law_export.rs` (189), `lawsat.rs` (685). Also `native/host-operations.rs` (376, generated, pulled into `member_app.rs:8`).

Context I read: `README.md` (Honest state), `ATLAS.md` §1, `protocol/HOST-OPERATIONS.md`, `protocol/host-operations.json`, `native/resource-client/{README.md, KEY-ADOPTION.md, SESSION-REENROLL.md, JOINED-MEMBER-JOURNEY.md, FRESH-CONTINUITY.md, WELCOME-CONTINUITY.md, PLATFORM-PROVISION.md, dregg-client-sign}`, and the headers of `fleet-*.sh`, `journey-key-adoption.py`, `newparticipant-*.sh`, `provisioning-acceptance.sh` and `authority-acceptance.sh`. Also `deploy/shell/OPERATOR.md:20-105`, the Lean receivers in `Host/Main.lean`, `Host/ClientConsentCore.lean`, `Host/ApplicationDispatchReady.lean`, `Host/Json.lean:4333-4350`, `Kernel/NativeHost.lean:494-519,1455-1515`, `Kernel/FleetTurnReceiver.lean:180-199`, `Kernel/ParticipantKeyEnrollment.lean:55-70` and `Kernel/NativeSpecializedConsent.lean:29-30`. For twin comparisons: `native/mini-sdk/src/{consent,signer,custody,secret}.rs` (headers), `native/mini-keys/src/{wire.rs, server/member.rs}` and `native/credential-signature-verifier/src/main.rs`.

## Executive summary

1. **What it is.** This is the custody half of every "who am I, how do I join, how do I sign" flow:
   - key generation helpers (keygen itself is in `main.rs`, shard A);
   - pre-rotation (`rotate-key`) and next-key adoption (`adopt-next-key`, ops 187-190);
   - sponsor-backed key enrollment (ops 86-89), factory-observation provisioning (ops 92-95) and local candidate-ID allocation;
   - first-trust continuity (`fresh_onboarding.rs`);
   - the local Lean consent provider client (`client_consent.rs`, frames 220-233 to a separate Lean executable);
   - the fleet turn surface (ops 96-102 and 180) and its helm/Bread adapter `mini fleet-sign`;
   - SPK session enrollment and reenrollment (ops 82-85), application share issue (28-33, 54-57) and current birth authoring (30, 31, 91);
   - the public paid-entry HTTP front (`enrollment-bootstrap`, ops 6, 8, 112, 121, 181-186);
   - the provider-key broker client (`mini key`);
   - the member "home" projection, seats (215-219), and the `can` and `law` helpers (op 130 dry run, op 150 law-sat).
2. **The design mostly holds.** Lean authors almost every signed byte. Rust retains frames, signs Host-chosen headers after a local Lean consent check, and uses lookup for recovery. I verified wire agreement on bytes and pair framing for ops 140-144, 187-190, 86-89, 92-95, 96-99, 226 and 224 against the Lean arms (§2).
3. **Rust does not evaluate laws.** `lawsat.rs` and `can.rs` only build queries and word the Host's answers (op 150, op 130). There is no `Pred.eval` twin.
4. **Violation: Rust authors a session state transition.** `session_reenroll.rs:630` builds a raw scalar `invoke` that writes session field 2 to generation+1 and field 3 to status+1, as the "close". The meaning of those numbers (1 = web active, 5 = api active, app field 1 = 4 = serving; `:416-430`, `:621-625`) is Rust's own copy of a Lean encoding. Lean gates this only as a generic capability write.
5. **Violation: a refused key rotation wedges the workspace.** `key_rotation.rs` marks an attempt "refused" only for 254/255 frames (`:679-684`, `:748-751`). But op 142 returns refusals as a typed outcome inside a 142 frame (`Host/Main.lean:7015-7020`). A Host refusal at submit therefore leaves the phase "submitted" forever: every later run is lookup-only (`:754-757`), and `--new-attempt` is refused while the old attempt is unresolved (`:471-480`). A never-forwarded op 142 wedges the same way. `journey.d/jrot-lookup.sh:107-116` tests exactly that state and offers no exit.
6. **Pre-rotation is undercut by custody copies.** `rotate-key` copies the original daily key, the original next key and the new after-next key into `attempts/rotate-ID/` and never deletes them (`key_rotation.rs:526-539`, `key_rotation_custody.rs:24-26`). So `--next-to OTHER-MEDIA` still leaves a copy of the new next key on the box. The deployed operator onboarding also copies the newcomer's daily secret into the sponsor's directory (`deploy/shell/OPERATOR.md:44-49`).
7. **Lost-reply hazard in `mini fleet-sign`.** `fleet_sign.rs:510-511` treats any non-confirmed outcome of an exact resubmission as "never admitted", including `uncertain` and `unavailable`. It then deletes the operation record (`:545`) and lets the caller commit a fresh turn: a possible double commit. The operation record itself is written with `fs::write` and umask permissions and no directory fsync (`:514-520`).
8. **Two retry philosophies coexist.**
   - Fleet, seat and fleet-sign resubmit the exact ingress (`fleet.rs:706-728`, `seat.rs:188-192`).
   - Rotation, adoption, enrollment, provisioning, session enrollment and share issue forbid resubmission and allow lookup only.

   Both rely on Lean replaying by operation identity first (true for fleet: `Kernel/FleetTurnReceiver.lean:186-188`). Nine modules each hand-roll their own submit-marker state machine, while `mini_sdk::custody` claims to be "ONE state machine" (`native/mini-sdk/src/custody.rs:1-7`).
9. **Rust-side copies of Lean frames, kept in step only by tests or runtime checks.**
   - `NEXT_POSSESSION_TAG` (`key_rotation.rs:156-160`; Lean `Kernel/ParticipantKeyEnrollment.lean:64-68`). The runtime check is `host_next_possession_frame` (`:191-209`), but keygen co-signs offline from the Rust copy.
   - `authentication_bytes` (`member_app.rs:96-102`; Lean `Host/ApplicationDispatchReady.lean:27-30`).
   - The broker signing frame `mini/member-provider-action/v1\0 ‖ serde_json::to_vec(request)` (`key_service.rs:141-147`). It is a Rust-to-Rust twin of `mini-keys/src/server/member.rs:34-38` and canonicalizes JSON by `serde_json` key order.
10. **Consent namespace and opcode lists.** Consent frames 220-233 are a second, unregistered byte namespace served by `minidregg-client-consent` (`Host/ClientConsentCore.lean:369-432,552-610`). This confirms the tiny-crates reader. The list of which plan ops get consent-checked exists three times and the copies disagree:
    - `client_consent.rs:1093-1095`: 31 ops;
    - `mini-sdk/src/consent.rs:19-20`: 29 ops, without 210 and 215;
    - Lean `NativeSpecializedConsent.supported`: 15 ops (`Kernel/NativeSpecializedConsent.lean:29-30`).

    Grain share plan op 56 and app-dispatch plan op 194 are in none of them.
11. **`enrollment-bootstrap` is the only internet-facing code in the shard.** It is a bounded HTTP/1.1 server that must sit behind a TLS proxy (`enrollment_bootstrap.rs:754-787`). It is well bounded: 4 workers, an 8-slot queue, per-/64 rate keys, closed routes. But it has no deploy unit, and if the operator omits `--trusted-proxy` every client shares one rate bucket (`:604-614`).
12. **Wired versus run.**
    - Run on scratch worlds: `enroll`, `join`, `workspace provision`, `rotate-key`, `key-status`, `fleet`, `fleet-sign`, `enrollment-bootstrap` and `law check`/`can` (journey rows M3, M8, JROT, JROTL, JLS, jpay-e4; evidence `docs/evidence/2026-09-30-fleet-surface/`, `2026-10-06-fleet-migration/`, `2026-09-30-newcomer-provisioning/`).
    - `adopt-next-key`: its own doc says it has never passed on a matched Host (`KEY-ADOPTION.md:119-124`).
    - `session-reenroll`, share issue and current birth: driven only by `scripts/spk-platform/*` and `scripts/application-current-birth/*`.
13. **Smallest demo build.** A minimal demo build could drop about 9.5K of the shard's 19.3K lines: SPK sessions and shares, paid bootstrap, fleet-sign, seats, adoption, the rotation executor, member app readiness and provider-key custody (§6).
14. **Interpreting state that belongs to the Host.**
    - `member.rs` and `can.rs` read capability and room-schema facts locally. This is presentation only.
    - `enrollment_bootstrap.rs:455-471` publishes "enrolled" or "expired" to strangers from a Rust comparison `hour < expiresAt`.
15. **Sixteen questions for Lean are in §8.** They include: is op 142 replay-first, so that an exact resubmit would be safe? Can lookups ever answer `contention`? Op 55 is registered operator-only but used by a recipient route. Where is the session status encoding declared?

---

## 1. What this code is and does

### 1.0 Reachability map (who calls each module)

| Module | `mini` arm(s) (`src/main.rs`) | Other in-crate callers | Journeys and scripts | Recorded runs |
| --- | --- | --- | --- | --- |
| `keys.rs` (+ `key_service.rs` via `#[path]` at `keys.rs:38-39`) | `key` (except `export-blinding`/`cell-blinding`/`derive-salt`), `main.rs:3226-3232`; shell verb `key …` via `keys::shell_plan` | `shell.rs`; `grain-runtime/src/provider_owner.rs:45` spawns `mini key --action owner-status` | `journey.d/jhide.sh`, `journey.d/jweb.sh` | split tenancy "run on no box" (README.md Honest state) |
| `key_rotation.rs` (+ `key_rotation_custody.rs` via `#[path]` at `:14-15`) | `rotate-key` `main.rs:3258`, `key-status` `:3260`; shell verbs `rotate-key`, `key-status` (`shell.rs:59,61`) | `participant_enrollment.rs` (cosign, digest, frame), `workspace.rs:334,410-419,607,690` (`check_commitment`), `member_app.rs:264,300` (`call`), `join_solana_v2.rs:581`, `roomkey.rs`, `main.rs:333,1120-1186` | `journey.d/jrot.sh`, `journey.d/jrot-lookup.sh`, `journey.d/jpriv1.sh`, `journey-key-adoption.py` | JROT failed 3 of 30 checks at main `4795b657` and JROTL passed (README.md Honest state, runner table outside the repo) |
| `key_adoption.rs` | `adopt-next-key` `main.rs:3256`; shell verb (`shell.rs:60`) | none | `journey-key-adoption.py` | none: "Until this harness passes on an actual matched Host, native adoption-to-rotation remains unverified" (`KEY-ADOPTION.md:122-124`) |
| `participant_enrollment.rs` | `enroll` `main.rs:3217`; `join` (default arm) `:3202`; shell `enroll …` (`shell.rs:63,1647-1740`) | `fleet.rs:1017-1080` (fleet join), `key_service.rs:214` (`key`), `participant_provisioning.rs` (helpers), `key_adoption.rs`, `key_rotation.rs` | `newparticipant-acceptance.sh`, `provisioning-acceptance.sh`, `fleet-journey.sh`, `welcome-continuity-journey.sh`, many `journey.d/j*.sh` | operator path in `deploy/shell/OPERATOR.md:44-66`; Lean probe `docs/evidence/2026-09-28-participant-key-enrollment/`; no outside member on the public node (README.md Honest state) |
| `participant_namespace.rs` | none directly | `participant_enrollment.rs:445,837`, `participant_provisioning.rs:62-78`, `workspace.rs` | via enrollment and provisioning | via M3 |
| `participant_provisioning.rs` | none directly; `workspace --action provision` reaches `workspace.rs:4998-5085` | `workspace.rs:5023,5098` | `provisioning-acceptance.sh` (M3), shell provisioning (`OPERATOR.md:66-77`) | `docs/evidence/2026-09-30-newcomer-provisioning/` |
| `fresh_onboarding.rs` (as `receipt_continuity::fresh`, `receipt_continuity.rs:16`) | `workspace --action onboard` via `workspace.rs:660,6211` | `participant_enrollment.rs:1414,1423,1490`, `paid_onboarding.rs:151`, `join_solana.rs:856` | `fresh-onboarding-journey.sh`, `welcome-continuity-journey.sh` | none recorded in `docs/evidence` under that name |
| `client_consent.rs` | `consent-resident` `main.rs:3305-3311`; every pure codec verb via `main.rs:604,1235` | essentially every signing path (`participant_enrollment`, `participant_provisioning`, `agent_reserve`, `agent_lifetime_grant`, `pay_claim`, `transport.rs:904-976,1148,3777-3791`) | all | `docs/evidence/2026-10-04-consent-anchor/` |
| `fleet.rs` | `fleet` `main.rs:3238` | `fleet_sign.rs`, `credit.rs:706-712`, `chat.rs`, `append_proof.rs:43,132,311-334` | `fleet-journey.sh` (M8), `fleet-contention.sh`, `journey.d/j17.sh` | `docs/evidence/2026-09-30-fleet-surface/` |
| `fleet_sign.rs` | `fleet-sign` (pre-parse fast path) `main.rs:4514-4516`; `dregg-client-sign` shell wrapper | none | `fleet-sign-journey.sh`, `fleet-sign-growth.sh`, `fleet-migration-replay.sh`, `fleet-migration-helm-probe.py` | `docs/evidence/2026-10-06-fleet-migration/` (101 files, no README) |
| `member.rs` (+ `member_app.rs` via `#[path]` at `member.rs:4-5`) | `member` `main.rs:3211`; shell `home` (`shell.rs:56`) | none | `joined-member-journey.py`, `composed-scenario.py`, `latency-same-store.py` | not found in `docs/evidence` |
| `seat.rs` | `seat` `main.rs:3223` | none | `objective-seat-native-acceptance.py`, `objective-bounty-native-acceptance.py` | journey row `seats` on scratch worlds (README.md Honest state) |
| `share_issue.rs` | `share-issue-prepare/-submit/-lookup` `main.rs:4073-4097` | `grain_share_issue.rs` (helpers) | `scripts/application-current-birth/*`, `scripts/spk-platform/issue-*.sh` | `docs/evidence/2026-09-27-application-share-issue-*` |
| `share_issue_receipt.rs` | `share-issue-receipt-lookup` `:4099-4128`, `grain-share-issue-receipt-lookup` `:4168-4197` | none | `scripts/spk-platform/*` | `docs/evidence/2026-09-27-shared-app-recipient-refs` |
| `grain_share_issue.rs` | `grain-share-issue-plan/-prepare/-submit/-lookup` `:4129-4166` | none | `scripts/spk-platform/grain-journey.sh` | `docs/evidence/2026-09-27-application-share-issue-grain*`, `2026-09-27-grain-share-plan-preview` |
| `session_enrollment.rs` | `session-enrollment-plan/-seal/-submit/-lookup` `main.rs:4026-4050` | `session_reenroll.rs` | `scripts/session-enrollment/native-acceptance.sh`, `scripts/spk-platform/*` | `docs/evidence/2026-09-27-session-enrollment`, `-client` |
| `session_reenroll.rs` | `session-reenroll` `main.rs:4005-4022` | none | `scripts/spk-platform/ws-continuity-fixture.py`; documented in `deploy/spk-host/SAME-STORE-AND-CHECKPOINT.md` | none found |
| `enrollment_bootstrap.rs` | `enrollment-bootstrap` `main.rs:3271` | none | `journey.d/jpay-e4.sh:655-690`, `journey.d/jpay-bootstrap-budget.py` | pay journeys on fixtures (`deploy/pay/README.md`); no deploy unit (the `grep` of `deploy/` for `enrollment-bootstrap` finds only a Caddyfile template, per `docs/review/2026-10-26-deploy/HCLOUD-GAP.md:126,172`) |
| `current_birth.rs` | `current-application-intent`, `current-session-intent`, `current-resource-intent` `main.rs:3841-3866` | `workspace.rs:12,4742-4755` (resource birth) | `scripts/application-current-birth/native-acceptance.sh`, M3 via workspace | `docs/evidence/2026-09-30-newcomer-provisioning/` |
| `can.rs` | `workspace --action can` (`workspace.rs:58-59`); shell `can` (`shell.rs:67`) | none | `affordances-journey.sh`, `journey.d/jdisclose.sh`, `lawsat-journey.sh` (`can --any`) | JLS row |
| `law_export.rs` | `workspace` law show and law export (`workspace.rs:76-77,2974,3206,6810`) | `world_prototype.rs:55`, `world_kind.rs:504` | `journey.d/jdisclose.sh` | — |
| `lawsat.rs` | `workspace` `law check`, install check, `can --any` (`workspace.rs:66-67,6744,6766,6795`) | none | `lawsat-journey.sh` (JLS), `journey.d/jlawsat.sh` | JLS row |

The shard has no `fn main` of its own. Everything enters through `mini`'s argument dispatcher (`main.rs:3196-3330` and `:3830-4200`), its pre-parse arms (`main.rs:4505-4520`), or `mini shell` plans (`shell.rs`).

### 1.1 `keys.rs` (511 lines; tests from line 415): `mini key`, provider-key custody client

**What it is.** The member client of the key broker `mini-keys`. Despite the name it does **not** handle participant signing keys. It handles **provider API keys** (OpenRouter and similar) that the broker seals, grants to Hermes runners, revokes and lists (module doc `keys.rs:1-25`).

**Actions.** `set`, `grant`, `revoke`, `ls`, `providers`, `choose`, `owner-status`, and `--pool true` for the operator pool key (`:132-260`, `:48`).

**The old in-process verbs refuse by name.** `--credentials`, `--credentials-key` and `--providers` give "mini key --{gone} is gone" (`:137-144`).

**Identity binding (`owner`, `:57-71`).** The owner is the workspace manifest's `subject` together with the hex public key of the workspace's own seed. The seed is read with `fsio::read_secret_in_private_dir`. So "a workspace that only claims someone else's subject lands in its own directory" (doc `:17-19`).

**Secret intake (`read_secret`, `:73-91`).**
- Source is stdin (`-`, limited to 4100 bytes) or a private regular file read without following symlinks (`mini_sdk::secret::Custody::FileNoFollow`).
- The buffer is zeroed after conversion (`:89`).
- After the exchange the secret string is removed from the request JSON and its bytes are zeroed with `unsafe { as_bytes_mut().fill(0) }` (`scrub_request`, `:262-270`, called at `:226` and `:258`).

**Transport.**
- A hosted workspace uses the broker socket (`service::local`, `:224`).
- A workspace whose `socket` is `ssh:DEST` uses ssh to the forced command `mini-provider-credentials-v1` (`service::client`, `:214-223`).
- The broker client config defaults to `mini_keys::client::CLIENT_CONFIG`, documented as `/etc/mini/keys-client.json` (`:10`). It is loaded with `Broker::load(path, euid)` (`:127-130`).

**`owner-status` (`:107-123`, `owner_view` `:93-106`).** It sends Host op 144 with JSON `{"subject","publicKey"}`, checks the 144 reply with `service::verify_current`, and adds `publicKey` to the view. Its caller is `grain-runtime/src/provider_owner.rs:36-62`, which spawns `mini key --action owner-status --host … --socket … --config … --subject … --public-key …`.

**`sign_choice` (`:271-296`).** For `action == "choose"` it signs a `credentials::choice::Choice` (code from `grain-runtime/src/credentials.rs`, included by `#[path]` at `:35-37`) with the workspace seed over the broker's `tableSha256`. The seed is zeroed after use (`:293`).

**`shell_plan` (`:331-413`).** It maps shell lines `key set PROVIDER -|@FILE`, `key grant …`, `key revoke …`, `key ls|providers` and `key choose …` to one `mini key` call.
- `@FILE` is confined to `HOME/keys/` by `plain_file` (`:316-327`).
- A secret on the command line is refused: "key set takes the key from - (stdin) or @FILE, never on the line" (`:357-360`).
- `-` is allowed only in the one-verb `--line` form (`STDIN_FREE`, `:46`, `:349-353`).

**Tests (`:415-511`).** Shell-plan mapping and refusals only.

### 1.2 `key_service.rs` (396 lines; tests from 266): the member side of the broker's signed exchange

**Framing.** The frame is a little-endian u32 length and then the body, bounded by `mini_keys::wire::MEMBER_FRAME` (32,768; `mini-keys/src/wire.rs:16-18`). Reads and writes are nonblocking with a 30-second deadline (`:31-137`). The write buffer is zeroed after send (`:135`).

**Exchange (`:180-232`):**
1. Read the broker's first frame. It is either a refusal (`{"refused":CODE}` or `mini-member-provider-refused-v1`, `refusal_of` `:162-178`) or a challenge with exactly the fields `{type, nonce, hostSha256, configSha256, tableSha256}` (`:193-196`).
2. Pin the challenge to the workspace's Host image digest and to the SHA-256 of the pinned config (`:197-205`).
3. Check that the nonce and table digest are 32-byte canonical hex (`:206-207`).
4. Rewrite a `choose` action into a signed choice (`:208-213`).
5. Read the workspace seed (`participant_enrollment::key`, which is `fsio::read_secret_in_private_dir`, `:214`).
6. Build `{"challenge", "owner": {subject, publicKey}, "action"}`.
7. Sign `b"mini/member-provider-action/v1\0" ‖ serde_json::to_vec(request)` (`signing_bytes` `:141-147`) with Ed25519.
8. Add `signature` (hex) and send.
9. Zero the serialized bytes and scrub the action (`:216-225`).
10. The reply must be `mini-member-provider-result-v1` (`:226-231`).

**`verify_current` (`:148-158`).** It requires `type == "subject-key-status-v1"`, the same subject, `isCurrent == true`, `currentRevoked == false`, and `keyEpoch` present.

**Two transports.**
- `local` (`:234-248`): `Broker::connect`, then a `{"op":"member-action"}` preamble, then the exchange.
- `client` (`:250-265`): `mini_sdk::operator::Ssh` with remote command `mini-provider-credentials-v1`.

**Tests.** Frame bounds, the stalled-reader deadline (Linux `F_SETPIPE_SZ`, `:304`), and an in-process end-to-end test against the real `mini_keys::server::Broker` with a stub Store answering op 144 (`:316-380`). The test spawns threads that `unwrap()` and binds sockets under `temp_dir`.

### 1.3 `key_rotation.rs` (903 lines; tests from 839): pre-rotation (K-PREROTATE)

**Doc (`:1-9`).** "The client never hashes and never encodes a Lean value: the digest, the command bytes and the possession frame all come from the Host." That is true for the rotation command, but see the next-possession twin below.

**Generic helpers.**
- `call` (`:31-53`) wraps `session_invoke`. On 254/255 it decodes the outcome through op 8 `inspect outcome`, records `HostDecision::RefusedFrame`, and returns the exact string `"host refused rotate-key op{n}"`.
- `kind_payload` (`:55-61`) is the u16-LE kind-label framing used by ops 7 and 8.
- `author` (`:63-66`) is op 7 and `inspect_bytes` (`:68-77`) is op 8.

**Status.**
- `next_key_digest` (`:80-98`) calls op 7 `signing-key-next-digest` and requires a canonical decimal reply.
- `status` (`:100-111`) calls op 144.
- `status_if_enrolled` (`:116-147`) returns `None` exactly when the Host refusal's decoded `detail` text equals `"subject has no current signing key"` (`:139`). That text is `Kernel/NativeHost.lean:498`.

**Next-key co-signature.**
- `NEXT_POSSESSION_TAG = b"DREGG/PARTICIPANT/KEY-ENROLL/NEXT-POSSESSION/v1"` and `next_possession_frame = tag ‖ public ‖ next` (`:156-160`). This is a Rust copy of `Kernel/ParticipantKeyEnrollment.lean:64-68`.
- `cosign` and `verify_cosign` (`:170-188`, `verify_strict`).
- `host_next_possession_frame` (`:191-209`) asks the Host for its frame and refuses if it differs from the Rust copy. It is called only from `enroll plan` (`participant_enrollment.rs:873-878`), not from keygen (`main.rs:1173-1179`), which co-signs offline using the Rust copy.

**`check_commitment` (`:226-265`).** This is the client's self-protection (FIX-IDENTITY). It refuses to build on a subject whose recorded commitment is not this workspace's next key (`Commitment::Mine`) or "none" (`Commitment::Without`). The facts come from op 144 (`prerotated`, `isCommittedNext`). Callers: `workspace.rs:334,410-419,607,690` and `join_solana_v2.rs:581`.

**`key_status` (`:370-405`).** The CLI `mini key-status`. It optionally adds `nextKeyMatchesCommitment` by a second op-144 query using the next public key.

**`rotate_key` (`:432-837`): the rotation executor.** The phase machine is persisted in `attempts/rotate-ID/custody.json` (format `minidregg-retained-rotation-v2`, `:556`), with the active pointer at `rotation-active.json` (`:562-563`).

Phases: `preparing → prepared → submitted → confirmed → installing → installed → completed`, plus a terminal `refused`.

1. Lock `key-transition.lock` (`:452`).
2. Bind the attempt to {operation id, subject, daily path, next path, destination, named public, host, socket, config hex} (`:500-502`). A changed binding refuses (`:505-508`).
3. On first preparation, query op 144 for the named key to get `keyEpoch` and `keyId`. **Rust computes `newEpoch = epoch + 1`** (`:518-525`).
4. Copy the original next and daily secrets into the attempt (`custody::immutable`, `:526-533`) and generate the after-next seed into `after-next.key` (`:534-539`).
5. Record prior destination and public files, and check derived public files against their secrets (`derived_public_priors` `:290-314`).
6. Before the Host advances: the private-room founder gate (`workspace::roomkey::founder_rotation_gate`, `:607-611`) and remembering the old key's encryption ring (`:612-615`).
7. Author the digest of the after-next public key: op 7 `signing-key-next-digest`, or the protected local verifier `receipt_continuity::key_source` (`:624-640`).
8. Author the rotation command from JSON `{subject, nonce, key:{keyId, keyEpoch:new, algorithm:"1", subject, publicKey, activeFrom:"0", activeUntil:u64::MAX, nextKeyDigest}}` (`:653-656`) via op 7 `subject-key-rotation` or `key_source` (`:657-674`).
9. Plan via op 140 (`:685-688`), inspect it (op 8 or the local verifier), and run `check_rotation_plan` (`:409-425`). That check requires command-byte equality and, when continuity protection is enabled, the same domain and semantics and `possessionFrameValidated == true`.
10. Sign `possessionHeader` with the **next** key (`:715`), assemble via op 141 (`:716-725`), and retain `ingress.bin` (`:726`).
11. Publish phase `submitted` before op 142 (`:745`). On transport error, call op 143 (`:752`). On any later run, call op 143 only (`:754-757`).
12. If the outcome is not `confirmed`, return the error "retained rotation remains unconfirmed; original lookup only, no resubmission" (`:759-765`).
13. Install the old next key as the daily key, the after-next key at the destination, `KEY.next.pub`, `KEY.pub` and `KEY.next.cosign`, and update `workspace.json` with `prerotation:true` and `nextPublicKey` (`:773-817`). Each file is installed only against its retained prior (`custody::install`).
14. Publish the room rotation (`workspace::roomkey::publish_rotation`, `:821-825`), write `result.json`, set phase `completed`, and print `PREROTATION_NOTICE` (`:826-836`).

**`--to-public-key`.** This exists only so a journey can show the Host refusing a mismatched rotation (`:427-431`).

**Tests.** `check_rotation_plan` field mutations and derived public priors.

### 1.4 `key_rotation_custody.rs` (135 lines; tests from 77)

Physical helpers for the rotation:
- `directory` creates or verifies a private directory plus a parent fsync.
- `publish` and `phase` are compare-and-swap JSON (`workspace::publish_retained_json(path, value, expected)`).
- `immutable` is `fsio::retain_exact` with 0600 permissions; it refuses differing bytes.
- `install` (`:48-69`) accepts only "absent with no prior", "equals the successor", or "equals the retained prior", then `replace_private_file`.
- `stable_id` validates `--new-attempt` (`:27-37`).

Nothing here deletes the retained secret copies.

### 1.5 `key_adoption.rs` (1,361 lines; tests from 566, 58% tests)

**Purpose.** Explicit `None → Some(nextDigest)` commitment adoption for a legacy current key, ops 187-190 (doc `:1-4`; `KEY-ADOPTION.md`).

**Source abstraction.** A `trait Source` (`:15-18`) abstracts the Host so tests can inject a fake. `Connection::inspect_signed` (`:25-44`) routes the plan and ingress inspection through `receipt_continuity::key_source` (the checksum-pinned local verifier), never through the remote op 8.

**`run` (`:370-564`):**
1. Load the workspace under `key-transition.lock`.
2. Require receipt-continuity identity (`key_transition_identity`, not "if enabled", `:386`).
3. Fetch the profile via op 6 and require domain, semantics and expectedSeed to equal the local identity (`:403-415`).
4. The attempt name defaults to `adopt-next-{keyId}-{keyEpoch}` from an op-144 status (`:417-434`).
5. Retain the pin `attempt.json` with context {subject, key path, host, hostSha256, config, configSha256, socket}, the profile, the request `{subject, nonce, currentPublicKey, nextPublicKey}` and the initial status (`:514-518`).
6. Refuse if the manifest already records a next key (`:492-494`) or the source shows `prerotated != false` (`:508-510`).

**`seal` (`:188-255`).**
- Retained op 187 plan (`stored_call` retains `plan.frame` and `plan.bin`).
- Local inspection, then `check_plan` (`:104-148`): plan type, domain and semantics equal the profile, command subject, nonce and next key equal the request, the full `expectedCurrent` record equals the initial status with `algorithm == "1"` and `nextKeyDigest == null`, and the two headers differ.
- Sign the current header with the daily key and the next header with the next key. Each signature is retained once; "submitted adoption lost a retained signature; refusing to sign again" (`:220-224`).
- `verify_strict` each signature (`:160-168`).
- Op 188 with `pair(plan, pair(cur, next))`, inspection, `check_ingress` (`:149-159`) and `sealed.json`.

**`resolve` (`:281-306`).**
- `submit-marker.json` is written before the single op 189.
- If op 189 returns `confirmed`, done. Otherwise, or on error, op 190 lookups, each under a fresh `lookup-<nonce>` stem.

**`finalize` (`:311-369`).**
- If the receipt is not `confirmed`, refuse.
- If a retained `result.json` exists, compare it and return without reinstalling.
- Otherwise op 144 must show the same keyId and epoch with `prerotated`, and a second op 144 for the next key must show `isCommittedNext`.
- The manifest must be unchanged or already updated.
- Then `workspace::record_next_public` and `result.json`.

**Tests (`:566-1361`).** Injected fakes plus subprocess children of the test binary that drive `run` and `rotate_key` against Python stand-ins for the local codec and consent provider (`LOCAL_CODEC_SERVE` `:576-590`, the consent stand-in `:1188-1210`). The tests say so themselves: "These fixtures do not establish native semantic admission" (`KEY-ADOPTION.md:105-106`).

### 1.6 `participant_enrollment.rs` (2,044 lines; tests from 1779): sponsor-backed key enrollment and `mini join`

**Three variants** (doc `:1-20`; `enrollment_roles` `:322-335`; `plan` `:646-657`):

| Variant | Flags | Who holds the new secret | Who signs possession | Subject number |
| --- | --- | --- | --- | --- |
| local key | `--new-key KEY` | the sponsor's process (the deployed operator path copies it there: `deploy/shell/OPERATOR.md:44-49`) | the sponsor's process, `seal` `:1537` | reserved locally (`participant_namespace`) |
| public key | `--new-public-key PUB` | the participant's own machine | participant: `mini join --sponsor-plan` → `possess_at` (`:1185-1271`) | reserved locally |
| home identity | `--new-public-key PUB --home-subject N` | the principal's process | principal: `--action possess` (`:999-1057`) | the principal's home subject N; only keyId is reserved |

**Pre-rotation default (`:658-715`).**
- The enrolled record commits to the digest of `KEY.next.pub` unless `--no-prerotation` is given.
- The next key's co-signature (`KEY.next.cosign`, or `--next-cosign`) is required and checked with `key_rotation::verify_cosign` (`:822-833`).
- `cosign_action` (`:348-378`) recreates the co-signature.

**`plan` (`:620-970`).**
1. Read the sponsor workspace (`workspace.json`, `refs/<factory>.json`) and check the factory target equals the config's `factoryId` (`:757-777`).
2. Create the attempt directory (0700) and take `enrollment.lock`.
3. Refuse if it is already submitted or sealed (`:796-805`).
4. Nonce: retain the existing one or draw a fresh one (`:806-810`).
5. Build the expected request `minidregg-participant-enrollment-request-v1` with name, sponsor, control, factory, observeCapability, newPublicKey, nonce, hostSha256 and configSha256 (`:811-821`), plus `homeSubject`, `nextPublicKey` and `nextCosign`. `retained_request` (`:149-182`) pins every field and refuses orphan artifacts.
6. **Reserve the subject and keyId locally:** `participant_namespace::reserve(namespace_root, deployment_domain, sponsor, name, request_bytes, roles)` (`:837-848`).
7. Inside `replan::replan` (`:855-942`): run the signed factory observation (`signed_factory_observation`, `:508-618`, ops 4, 7, 9, 10, 5 with consent frames 220 and 221 in between). Check the Host's next-possession frame (`:873-878`) and get the next-key digest (`:879-884`).
8. Author the command source `{sponsor, control, nonce, expectedFactoryRoot, expectedAuthorityRoot, key:{keyId: reserved, keyEpoch:"1", algorithm:"1", subject, publicKey, activeFrom:"0", activeUntil: u64::MAX, nextKeyDigest}}` (`:885-891`). Then op 7 `participant-key-enrollment` (via the local codec, `transform` `:184-225`), op 8 inspection, and an equality check (`:911-916`).
9. Op 86 plan with `pair(signed observation, command)` (`staged_invoke` `:252-292`), op 8 inspection, then `validate_plan` (`:972-993`).
10. Bind the attempt to the reservation (`participant_namespace::bind_attempt`) and write `pin.json` (`:950-964`). The plan is printed with `"authority":"candidate-only"` (`:965-969`).

**`seal` (`:1493-1605`).**
- `load_pin` (`:387-492`) re-verifies the host and config digests, the request, command and plan digests, and the namespace reservation.
- A fresh op 8 inspection must equal the retained one (`:1518-1528`).
- **Consent:** `client_consent::operator_plan(host, config, 86, pair(observation, command), plan)`, consent frame 224 (`:1530-1531`).
- The sponsor signs `sponsorHeader.canonical`. Possession is either signed locally by the new key or supplied as a detached file and checked with `VerifyingKey::verify`, the non-strict call (`:1538-1552`).
- Signatures are laid out as `pair(sponsor_sig, possession_sig ‖ next_public(32) ‖ next_cosign(64))` (`:1561-1566`), then op 87 assembly and inspection with field equality (`:1585-1594`), then `seal.json`.

**`submit` (`:1701-1729`).** Write `submit-marker.json`, then op 88. If the outcome is `confirmed`, call `result`. Otherwise, or on transport error, `lookup_exact` (op 89), which must be `confirmed` with confirmation `replayed` (`:1653-1659`). `result` (`:1661-1681`) writes `enrollment.json` with `"authority":"admitted-key-only"`. A later `submit` with the marker present is lookup-only (`:1709-1713`).

**`offer` and `welcome` (`:1064-1105`).** The sponsor exports the offer (config hex, host digest, plan and command views) and later the welcome (enrollment result, `ingressHex`, `ingressSha256`, optional birth context).

**`join` (`:1125-1162`), run on the participant's machine with `--remote`.**
- `--key` alone generates the key with the next key beside it. It calls `keygen(&key_path, &key_path.with_extension("pub"), …)` (`:1142`), which writes `me.pub` rather than the `me.key.pub` that `key_rotation::conventional_public` expects (`key_rotation.rs:280-284`).
- `--sponsor-plan` → `join_possess` (`:1185-1271`):
  1. Pin the remote host digest.
  2. Re-inspect the plan and command through the remote Host and require equality with the offer (`:1218-1229`).
  3. Require the offered `nextKeyDigest` to equal the Host-computed digest of the participant's own `KEY.next.pub` (`:1235-1253`).
  4. Sign possession only after the consent frame 226 check and after retaining `possession-acceptance.json` (`:1036-1050`). `possess_at` requires `client_consent::configured_record()` (`:1040-1041`).
- `--welcome` → `join_welcome` (`:1360-1491`):
  1. Require the pinned portable `--verifier`.
  2. Inspect the plan and ingress locally via the verifier binary (`local_join_inspect` `:1284-1297`) and run `match_join_ingress` and `match_join_prerotation`.
  3. Op 89 read-only lookup only, never submit (`:1456-1470`).
  4. Write `authenticated-receipt.json`, initialize the workspace with `init_fresh_receipt` (`:1484-1486`), and set the external marker `workspace-created.json` (`:1346-1358`).
  5. Call `complete_fresh_onboarding`.

**Tests.** Join-marker durability, welcome and prerotation matching, request nonce retention, frame-only crash recovery, `pair` layout and receipt classification.

### 1.7 `participant_namespace.rs` (947 lines; tests from 484)

**Purpose.** "Physical candidate IDs shared by controllers of one deployment. A reservation is neither a grant nor evidence of birth" (`:1-3`).

**Storage.** One file per request `request-<sha256([deployment, participant, request])>.json` under an owner-private root, guarded by `namespace.lock` (`mini_sdk::lock::Lease`, 500 tries at 10 ms, `:62-74`).

**ID allocation (`fresh_id`, `:178-188`).** A random u64 with the top bit forced (`number |= 1 << 63`), so every ID lies in [2^63, 2^64). It is retried 16 times against every ID used by records of the same deployment (`used_ids`, `:139-175`, a full directory scan per call).

**Reservation (`reserve`, `:212-286`).** It is idempotent for the same (deployment, participant, request, fingerprint, roles) and refuses a changed fingerprint or roles (`:249-266`).

**Attempt binding.**
- `bind_attempt` (`:303-381`) writes `binding-<digest>.json`, binding one attempt path and source digest.
- `release_attempt` (`:391-442`) renames it to `released-<digest>-NNNN.json`.
- `probe_id` (`:196-206`) draws a candidate without writing (used by `can`'s dry runs).

**Status.** Every record says `"status":"candidate-only"` (`:275`).

**Tests.** Multi-process concurrency and crash recovery with the test binary as child.

### 1.8 `participant_provisioning.rs` (544 lines; tests from 486)

**Purpose.** A library for `mini workspace --action provision` (`workspace.rs:4998-5085`). The sponsor grants the factory-observe capability to an enrolled subject: ops 92 plan, 93 assemble, 94 submit, 95 lookup (constants `:20-23`, registered as client constants in `protocol/host-operations.json`).

**Flow.**
- `record` (`:83-118`): fresh nonce, then `participant_namespace::reserve` with one `capability` role and the name `observe-<name>` (`:62-78`), then `bind_attempt`.
- `plan` (`:122-193`) runs per generation `gNNNN`: signed factory observation, command source `{sponsor, control, nonce, expectedFactoryRoot, expectedAuthorityRoot, holder, capability}`, op 7, op 8, op 92.
- `seal` (`:195-239`): consent `operator_plan(92)`, sponsor signs the header, op 93.
- `observe_grant` (`:360-440`): marker, then op 94, then lookup op 95.

**Generations.** A retained plan from an earlier run that the Host no longer derives is superseded once (`:391-411`). A `stale-root` refusal is superseded by `replan` (`:403-409`).

**`observe_lookup` (`:443-484`).** It compares transactionId, eventId and acceptedCount, but **not worldRoot**, against the retained result (`:477-481`).

### 1.9 `fresh_onboarding.rs` (706 lines; tests from 353): `receipt_continuity::fresh`

**Purpose.** First authenticated continuity baseline for a newly created workspace. It is a submodule of `receipt_continuity` (`receipt_continuity.rs:16`).

**Baseline sources (`FreshBaseline`, `:11-14`).**
- `Reference`: an imported first readable reference. A signed read gives a challenge point.
- `AdmittedReceipt`: the authenticated enrollment receipt from `join --welcome` (`receipt_point` `:15-33`).

**`prepare` (`:96-151`).** Called only on a newly created, unpublished workspace (`:107-115`). It pins the verifier (path, image SHA, identity derived from `profile`), config bytes and workspace binding, writes `receipt-continuity.pending.json` in state `awaiting-first-read`, and sets `workspace["freshContinuity"]` to a random enrollment id.

**`complete_with` (`:218-344`).** State machine `awaiting-first-read → verified-candidate → (custody directory → anchor.json → enabled.json → manifest receiptContinuity → complete)`, with stages `Stage::{Candidate, Directory, Anchor, Enabled, Manifest, Complete}` (`:205-213`).
- The first proof is `source.response` and `verify_response`, through `HostProof` (op 151, receipt continuity, in `receipt_continuity.rs`). Its target is either the challenge point or the receipt point (`:254-263`).
- The candidate is saved before custody exists, so a crash resumes the exact candidate (`:264-271`).
- Each later stage refuses on any mismatch with existing custody.

**`guard` (`:178-194`).** Ordinary requests refuse an incomplete fresh onboarding.

**Tests.** A Python protocol stand-in verifier plus crash-at-every-stage child processes (`:640-705`).

### 1.10 `client_consent.rs` (1,130 lines; tests 567-979 and 1059-1092, about 447 lines)

**Purpose.** The client of the **local** Lean consent provider `minidregg-client-consent` (`lakefile.toml:93-94`, root `Host.ClientConsentSession`; core `Host/ClientConsentCore.lean`). It also owns the process-wide **storeless codec child** for pure frames 7-11 (`local_frame`, `:1002-1050`), which runs `HOST SETTINGS codec` (`Host.Main.serveCodec`).

**Provider selection (`invoke`, `:104-129`).**
- Executable: `PINS.consent`, else `MINI_CONSENT_HOST`, else `<host dir>/minidregg-client-consent`.
- Settings: `PINS.config`, else `MINI_CONSENT_CONFIG`, else the caller's config.
- Both must be absolute.
- One provider per process (`SESSION`). A change of executable or settings bytes within the session refuses (`:113-116`).

**Frame protocol (`exchange` `:78-91`, `round_trip` `:66-76`).** A u32 LE length, then `[op] ‖ payload`, bounded by `CAP = 12,102,760`. A reply op different from the request is a refusal. A 221 refusal whose detail starts with `"stale observation:"` sets `STALE_OBSERVATION` (`:93-103`).

**Frames sent (confirmed against `Host/ClientConsentCore.lean:330-610`):**

| Frame | Rust site | Payload | Lean arm |
| --- | --- | --- | --- |
| 220 intent (230 thin) | `intent` `:247-252` | `pair(intent, pair(pubkey32, []))`; the reply must equal the intent | `consent` `:369-371` (`thin` `:420-422`) |
| 221 observation (231 thin) | `observation` `:253-256` | `pair(intent, pair(pub, pair(signature, challenge)))` → headers JSON | `:372-376` (`:423-428`) |
| 222 plan (232 thin) | `plan` `:257-260`, `thin_plan` `:291-307` | `pair(intent, pair(pub, plan))`; thin adds a `StreamCodec.list bytesStream` of served views (`stream_nat`/`stream_byte_list` `:278-289`) | `:377-380` (`:429-440`) |
| 224 specialized/operator plan | `operator_plan` `:1099-1104` | `pair([op] ‖ request, candidate)`; the reply must equal the candidate | `specialized` `:458-469` |
| 226 possession | `possession` `:1109-1114` | `pair(command, pair(json{subject, publicKey}, candidate))` | `possession` `:471-489` |
| 227 Objective headers | `objective_headers` `:1121-1130` | `pair(intent, pair(json{publicKey, role}, candidate))` | `:606` |
| 228 offer anchor, 229 get anchor, 233 recheck | `start_in` `:148-151`, `retain_anchor_with` `:221-241`, `serve_resident` `:543-549` | anchor bytes, empty, empty | `:560-592` |

**Anchors (`:155-241`).**
- Path: `~/.mini/consent-anchors/<hex binding>.anchor`, or under `$MINI_CONSENT_ANCHOR_DIR`.
- Binding: SHA-256 over a tag, the executable path and its (dev, ino, size, mtime, ctime) and the settings digest (`:172-186`).
- File format: `MINI-CONSENT-ANCHOR-CUSTODY/v1\n ‖ binding ‖ anchor`, owner-private, read with `O_NOFOLLOW` and a 4096-byte cap (`:190-210`).
- Retained after every frame with `mini_sdk::durable::replace_with` (`:236-240`). A failure only prints a warning (`:232`, `:239`).

**Resident provider (`:354-565`), on by default unless `MINI_CONSENT_RESIDENT=0`.**
- `connect_resident` spawns `mini consent-resident --consent EXE --settings S` as a `setsid` daemon (`:418-424`) with stderr to `r-<binding>.log`, and waits up to 300 s for its socket.
- `resident_in` (`:467-516`):
  - one provider per binding, guarded by a `flock` lock file (`:475-480`);
  - a Unix socket set to 0600 and a PID file;
  - idle exit after `MINI_CONSENT_IDLE_S` (default 600);
  - one thread per client connection, serialized on one provider mutex.
- `serve_resident` (`:520-565`) checks `peer_uid == euid`. It sends 233 once per connection before the first frame, and refuses 228, 229 and 233 from clients.

**Pins (`:309-329`).** `pin_record` and `configured_record` fix `{semanticHost, consentHost, config}` once per process, from the workspace or attempt record or from the three `MINI_*` env vars together.

**`plan_operation` (`:1093-1095`).** The list of Host plan ops whose operator replies `transport.rs:904-907` routes through consent frame 224: `32 36 44 48 50 52 58 66 68 70 74 78 80 82 86 92 96 103 108 113 117 123 126 140 160 170 183 201 206 210 215`.

### 1.11 `fleet.rs` (1,476 lines; tests 1265-1476)

**Purpose (doc `:1-7`).** "One participant workspace is one agent". The account reference names a paying account and a spend grant.

**Verbs (`run`, `:1139` and on).** `join`, `send` and `publish` (topic payload plus optional transfer), `transfer`, `lookup`, `receipt` (`--transaction` op 102 or `--head-of` op 101), `poll` (op 100), `incoming` (op 180), and `feed` (merge of several accounts' topic streams).

**`attempt` (`:479-604`).**
1. Allocate a new attempt via `workspace::new_attempt`, or use the record's pinned attempt and nonce.
2. Draft `{subject, payer, spend, nonce, fee:"0", transfer, publication}` and author it with op 7 `fleet-turn` via `crate::author`, then inspect.
3. Signed observation of the account (`workspace::signed_view`).
4. Op 96 plan with `pair(observation, draft)`.
5. `validate_plan` (`:194-237`): only the fee and the topic sequence may differ from the draft, and **the fee must equal the pinned config's `tariffBase`** (`:208-210`; `tariff` `:174-189` reads `tariffBase` and `asset` from the local config file).
6. Sign the header with the workspace key (`read_secret`, `:549-550`), then op 97 assembly, ingress inspection and `submit-marker.json`.
7. Optionally append to the journal (`journal_attempt` `:616-627`), then op 98 submit.
8. On transport error, op 99 lookup (`:567-573`).
9. `contention` is recorded as `superseded.json` "decided-nothing-moved" and the caller replans (`:574-581`).
10. `uncertain` or `unavailable` leads to a lookup (`:584-586`).
11. A non-confirmed outcome is an error with the exact outcome retained.

**Replanning.**
- `turn_journaled` (`:630-654`) replans up to `MAX_REPLANS = 8` times after contention or `stale-root`.
- `plan_refusal` (`:303-316`) and `observation_stale` (`:323-336`) classify `stale-root` from the Host's own decoding.

**Exact operation records (`:344-471`).**
- `operation_record` is an immutable pointer file `minidregg-exact-operation-v1` binding the workspace, participant snapshot, config digest and caller binding. It is created with `create_private` (O_EXCL) and parent fsync.
- `recover_operation` does lookup-only recovery for `fleet` (submit marker) and `workspace` (`call.bin`) kinds.
- `exact_status` (`:392-396`): a lookup refusal is "uncertain", not "refused" (`:466-469`).

**`resubmit` (`:710-728`).** Sends the same retained ingress to op 98 again. It is used by `fleet_sign` `resolve` and `retry`.

**`join` (`:1017-1137`).** Composes `participant_enrollment::run` (plan, seal, submit/lookup) for a local key, then `workspace::init` from `enrollment.json`, then `workspace::create_funded_account` with the account law **`{"type":"all","predicates":[]}`** (`:1084-1091`), then import and observation. It writes `join-<account>.json` with `"authority":"admitted-key-and-owned-funded-account"`.

**`feed` (`:793-836`) and `incoming` (`:978-1012`).** These order events client-side by `(height, sequence)` and refuse duplicate heights or non-ascending heights.

### 1.12 `fleet_sign.rs` (947 lines; tests from 825): `mini fleet-sign`, the helm/Bread `dregg-client-sign` compatibility signer

**Doc (`:1-20`).** It explains why it signs Mini headers rather than forwarding Bread turn hashes. The `dregg-client-sign` script is a 7-line `exec "${MINI_BIN:-mini}" fleet-sign "$@"` (`native/resource-client/dregg-client-sign:1-7`).

**Profiles.** `HOME/profiles/NAME/{key, key.pub, enroll/, workspace/}`. HOME comes from `--home`, else `MINI_FLEET_HOME`, else `$HOME/.mini-fleet` (`:16-20`, `:78-84`). The profile name comes from `--profile`, else `MINI_PROFILE`, else `HOME/profiles/ACTIVE` (`:177-191`).

**Verbs (`:52`).** `join`, `send`, `transfer`, `receipt`, `retry`. Bread-only flags (`--token`, `--token-file`, `--accept-tentative`) refuse by name (`:151-163`). Bread environment variables are named on stderr as unread (`:774-793`).

**`join` (`:262-328`).**
- On first use it generates the profile key with the next key beside it and `hosted=true` (`:295-300`), then calls `fleet::join` with a default fund of 5000 (`:267`).
- An already joined profile only reports its balance and refuses if the balance is below `--fund` (`:269-289`).

**Identifiers.**
- `turn_hash` (`:381-383`) is the transaction id as 32 big-endian bytes, in hex.
- `receipt_hash` (`:405-412`) is SHA-256 of `MINI.FLEET-SIGN.RECEIPT-HASH/v1\0` followed by the four receipt fields, each 32 bytes big-endian.

These are Rust-minted identifiers for harness compatibility.

**At-most-once operation (`:437-567`).**
- `operation_id` is SHA-256 over the verb and length-prefixed arguments (`:455-463`).
- `once` (`:525-555`) first resolves a pending `operation.json` and the journal `operation-attempts`, by exact resubmission of the last attempt (`resolve` `:493-512`). It then writes a new record and runs the turn with the journal.
- `finish` deletes both files after the answer is printed (`run` `:817-821`).
- `StdoutToStderr` dups fd 2 onto fd 1 while the verbs run (`:744-767`), so exactly one JSON object reaches stdout.

### 1.13 `member.rs` (730 lines; tests from 529): `mini member` / shell `home`

**Purpose.** A read-only projection of a member workspace.
- `resources` come from `refs/*.json` (`Resource::from_reference`, `:30-71`) with suggested shell commands.
- `recovery` lists attempts with `call.bin` whose retained outcome is not terminal (`pending_attempts` `:85-112`).
- `documentExports` (`:116-175`) and `appLifecycles` (`:179-209`) delegate status to `workspace::app_document` and `workspace::app_lifecycle`.

**Optional signed read of one selected reference (`projection_with` `:260-330`).** It shows the observation coordinates and balances, a programmable object (`worldKind`/`worldInstance`, `:213-224`), and the room resident from `room_schema::TARIFF_FIELDS` (`resident` `:333-354`).

**Output.** Text rendering (`render` `:356-482`) or `--json true`. `--action app-status` goes to `member_app::status`.

### 1.14 `member_app.rs` (415 lines; tests from 315), plus `native/host-operations.rs`

**Purpose.** App readiness check for a member's app session reference. It uses the generated constants `APPLICATION_DISPATCH_AUTHENTICATED_PLAN` (194) and `APPLICATION_DISPATCH_READY` (193) (`:8-11`).

**Flow (`status`, `:193-313`).**
1. `selectors` (`:28-85`) checks the `provenance.memberApp` selectors exactly.
2. `workspace::signed_views` gets five signed observations (app, package, session, enrollment, ticket) that must share one challenge (`:209-226`).
3. Author `application-dispatch-request` with a fixed request `http: {operationId: nonce, method GET, path "/"}` (`:228-232`).
4. **Sign `authentication_bytes(domain, semantics, request)`** = `"MINI/APPLICATION/AUTHENTICATED-PLAN/v1\n{domain}\n{semantics}\n" ‖ request` (`:96-102`, `:252-258`).
5. Op 194 with `pair(request, pair(auth, observations…))` via `key_rotation::call` (`:264`), then inspection.
6. `check_plan` (`:103-167`): every slot is signed by this member's current key id and epoch.
7. Sign the headers (`crate::sign_headers`), build the signatures with op 9, then op 193 READY. `check_ready` (`:168-191`) requires `status == "admitted"` and `physicalDispatch == false`.

**The generated file.** `native/host-operations.rs` (376 lines) holds 186 `pub const` request bytes under `#![allow(dead_code)]`, "Request byte allocations only". In this shard only `member_app.rs` imports it. Every other module uses numeric literals (§5).

### 1.15 `seat.rs` (234 lines; tests from 214): `mini seat`, ops 215-219

**Actions.** `submit` (op 7 `seat`, op 215 plan, op 8 `seat-plan`, sign `header.canonical`, op 216, op 217), `resubmit` (op 217 again with the same ingress), `lookup` (op 218) and `view` (op 219) (`:171-212`).

**Authoring.** Rust fills `{subject, nonce, expectedAuthorityRoot, turn}` from the op-219 view and a 16-byte `/dev/urandom` nonce (`:94-100`, `:114-121`).

**`donation_gate` (`:155-165`).** It refuses to sign an offer whose proposal has `donate: true` unless the command file says `"confirmDonation": true`. This is client consent.

### 1.16 `share_issue.rs` (711 lines; tests from 588): event-15 application share ticket, operator custody

**`prepare` (`:449-586`).**
1. Operator approval `minidregg-application-share-issue-approval-v1` binding `requestSha256` and `canonicalSpec`.
2. Author the request with a **one-shot Host process** (`source_process` runs `HOST CONFIG author …`, `:17-32`), then `source_inspect`.
3. Op 32 plan on the operator socket, then inspection, `check_approval` and `check_intended_selectors` (`:118-136`).
4. Per signing slot, `approved_header` (`:71-102`): decoded, canonical, keyId and keyEpoch equal the approved signer, role and index equal, and `headerSha256` equals the approval. Sign with the key at `keyPath`.
5. Signatures via the Host one-shot, then op 33 assembly, then `pin.json`.

**`submit` (`:371-397`).** Marker, then op 28. The marker forbids a second submit.

**`lookup` (`:400-444`).** Op 29.

**`historical_anchor` (`:326-367`).** The first confirmed outcome becomes `receipt-anchor.json`. A later different receipt refuses.

### 1.17 `share_issue_receipt.rs` (352 lines; tests from 240): recipient-side historical lookup

**Profiles.** `IssueProfile::BareEvent15` (op 29) and `IssueProfile::GrainBackedEvent22` (op 55) (`:13-33`).

**`lookup_profile` (`:141-238`).**
- Requires a fresh destination directory.
- Retains the ingress and a marker, then sends op 29 or 55 with the exact ingress.
- Inspects locally via the pinned Host one-shot `inspect outcome`, with stdio nulled (`:80-101`).
- `exact_receipt` (`:43-62`) requires `confirmed` and `replayed` and all four expected fields.

### 1.18 `grain_share_issue.rs` (738 lines; tests from 597): event-22 grain-backed share ticket

**Siblings.**
- `plan` (`:302-383`): op 56 preview, no approval, no key.
- `prepare` (`:388-519`): approval pins the request plus `payer`, `funding`, `sourceCapabilities`, `tool` and `parent` (`approved_request` `:217-259`). `ordered_slots` (`:261-281`) enforces birth slots then the app slot. Op 56, sign, op 57.
- `submit` (op 54) and `lookup` (op 55).

**Duplication with `share_issue.rs`.** It reuses `share_issue`'s helpers through `use super::share_issue as custody;` (`:4`). It re-implements `retained`, `reinspect` and `historical_anchor` (`:19-215`), which are near-copies of `share_issue.rs:159-367` (§5).

### 1.19 `session_enrollment.rs` (600 lines; tests from 521): event-28 application session enrollment

**Not participant joining.** It enrolls an app session (role, ticket, issue receipt) and talks to the operator socket only (`private_socket` checks at `:125`, `:214`, `:417`, `:441`). Ops 82-85, registered as client constants.

**Flow.**
- `plan` (`:114-187`): author `application-session-enrollment-request` via `agent_reserve::source` (the Host one-shot), inspection, op 82 plan, inspection, `exact_plan` (4 to 16 slots, `:42-56`), `pin.json`.
- `seal` (`:211-313`): approval `minidregg-session-enrollment-approval-v1` binding the request, plan and plan-inspection digests. Signers per slot via `agent_reserve::approve_slot`. Signatures, then op 83, then `exact_ingress` (`:189-209`).
- `submit` (`:414-436`): `send_once` refuses a second submit (`:399-412`), then op 84.
- `lookup` (`:438-487`): op 85, which must be `replayed`.
- `authenticated_anchor` (`:507-519`): exact lookup plus fresh inspection by a separately pinned inspector.

### 1.20 `session_reenroll.rs` (1,150 lines; tests from 927)

**Contract.** A participant-supplied JSON contract with exactly 17 fields (`contract` `:31-109`) carries an event-28 enrollment across a compatible app upgrade.

**`capture` (`:434-488`).**
- `authenticated_anchor` of the prior enrollment, `validate_enrollment` (`:390-406`).
- Signed reads of the app and session resources (`query` `:343-369`, nonces `nonce + 100 + index`).
- `active_snapshot` (`:407-433`) checks that app field 0 equals the generation, app field 1 equals `"4"`, session fields 0, 1 and 2 match, and session field 3 equals `"1"` (web) or `"5"` (api).

**`resume` (`:668-804`).**
- `bind_execution` (`:278-333`) pins the `compatible_upgrade_custody` admission: the target host image digest, config and management socket.
- The app must now serve the new generation.
- `ensure_closed` (`:601-667`) **authors a raw scalar invoke** (`:630`) with nonce + 1. It writes session field 2 from `generation` to `generation+1` and field 3 from `status` to `status+1`. It submits through `submit(… true)` and `host_files submit`, then looks up.
- The closed state is checked against those numbers (`:702-719`).
- `request_from_prior` (`:489-528`) rebuilds the request, decoding the hex role permission lists back to UTF-8.
- Then `session_enrollment::plan`, approval and seal, `submit`, and `authenticated_anchor` with a final `active_snapshot`.

**Output.** `run` (`:905-925`) always prints a verdict JSON and **returns `Ok(())` even on refusal** (§4).

### 1.21 `enrollment_bootstrap.rs` (1,553 lines; tests from 875): public paid-entry HTTP server

**Server.**
- HTTP/1.1 only, one request per connection, no chunked encoding, no `Expect`, duplicate headers refused, at most 32 headers, head at most 8 KiB, body at most 4 KiB, a 5-second whole-request deadline, and pipelined bytes refused (`:80-212`).
- 4 worker threads and an 8-slot `sync_channel` queue. A full queue gets a 503 written by the accept loop with a 100 ms deadline (`:832-866`).

**Routes (closed table; no op number comes from HTTP, `paid_route` `:281-291`):**

| Route | Method | Host op | Rate policy |
| --- | --- | --- | --- |
| `/mini/v2/metadata` | GET | none (static) | — |
| `/mini/v2/status` | POST JSON | 181 PAY_CLAIM_VIEW | status (12/min, burst 2/5 s) + status permit |
| `/mini/v2/quote` | POST JSON | 182 PAY_CLAIM_QUOTE | quote (6/min, burst 4/10 s) |
| `/mini/v2/claim/plan` | POST octet | 183 | quote |
| `/mini/v2/claim/assemble` | POST octet | 184 | quote |
| `/mini/v2/claim/submit` | POST octet | 185 | quote |
| `/mini/v2/claim/lookup` | POST octet | 186 | status |
| `/mini/v1/metadata` | GET | none (computed at start from op 6) | — |
| `/mini/v1/quote` | POST JSON | 121 PAY_ENROLLMENT_QUOTE | quote |
| `/mini/v1/enrollment/<key>[?signature=]` | GET | 112 + 8 (`pay-enrolment-view`) | status |

**Rate limiting.**
- Keys are per IPv4 address or per IPv6 /64 (`rate_key` `:520-528`), with a 1,024-entry table and LRU eviction (`:530-573`).
- Global Host concurrency is 2 (`HOST_WORK`) with 1 for status (`STATUS_WORK`).
- `X-Real-IP` is honoured only from `--trusted-proxy` (`:604-614`).

**Startup checks (`run` `:760-873`).**
- The listen address must be loopback, RFC1918 or IPv6 ULA (`private_listener` `:754-759`).
- `--socket` must be absolute, with a sibling `.mode` file containing exactly `public-v1` and a sibling `.config` byte-identical to `--config` (`:785-795`).
- Metadata JSON is limited to the whitelisted keys `sshLogin`, `clientBundleUrl`, `clientBundleSha256` and `birthContextUrl`, and must use HTTPS (`metadata` `:310-353`).

**v1 status (`enrollment` `:415-493`).** Op 112 dumps the whole enrollment view (at most 2 MiB). Op 8 decodes it (at most 4 MiB). Rust then filters one key, and derives **state `enrolled`/`expired`/`noLease`/`notObserved` from `hour < expiresAt`** (`:455-471`).

### 1.22 `current_birth.rs` (364 lines; tests from 219)

**Purpose.** Retain-then-call authoring for "loaded-current" births: op 30 (application), op 31 (session) and op 91 (resource, which needs a signed factory observation).

**Flow (`author`, `:79-175`).**
- Copy the source and config into the attempt directory, write the `author.json` manifest, and send `pair(observation, source)` or `source`.
- Retain `reply.frame` before extracting `intent.bin`.
- `retained_intent` (`:179-217`) finishes after a crash without contacting the Host.

**Limits.** At most 4 MiB of source and intent.

### 1.23 `can.rs` (479 lines; no tests)

**Purpose.** `can [NAME] [--all]`.
1. For each capability id in a reference (observe, operation, control), read the Host's signed `capability` view and decide `mine` (bearer, or holder subject equals me) and `covers` (`targets` contains the target, or a `room` scope) (`:233-277`).
2. Map shell verbs to kernel verbs (`KERNEL_VERB` `:22-33`, `shell_verbs` `:43-50`, `slot_verbs` `:57-63`).
3. For each covered verb, build a representative proposal and run it through `propose_probe` and `dry_run` (op 130, never submitted). A shell verb no grant covers is skipped unless `--all`, in which case "noGrant BUT THE HOST ADMITTED THE PROBE" flags disagreement (`:297-319`).

**Leftovers.** Probes create attempts with `new_attempt` (`:110`) that are never removed. Proposals and sources are removed (`:122-123`).

### 1.24 `law_export.rs` (189 lines; tests from 100)

**`source` (`:30-66`).** Builds a policy record source from the signed policy view.
- It copies all five v6 facets (`localSelector`, `parents`, `descendants`, `audience`, `objectDescriptor`), or none.
- It computes **`version = previous + 1` in decimal-string arithmetic** (`next_revision` `:14-26`) and sets `previous` to the policy address.
- It replaces either `predicate` or `descendants`.

**`retained` (`:70-89`).** Reissuing a proposal id reuses the original source.

**`show` (`:91-98`).** Prints the signed policy.

### 1.25 `lawsat.rs` (685 lines; tests from 620)

**The Host decides every verdict.** Requests `minidregg-law-sat-v1 {predicate, extra?, fromHere?}` go to `crate::law_sat` (`main.rs:1516-1526`), which runs `process(host, config, ["law-sat", in, out])`, op 150. The `dispatchSession` arm is at `Host/Main.lean:2074`.

**Checks.**
- `check` (`:243-258`) asks: any step; any write (`extra` = `request/verb == "2"`); and, for a satisfiable law, the installer's own subject pin and the re-law pin (`request/verb == "4"`).
- `install_check` (`:353-399`) refuses locally to propose an unsatisfiable law (unless `--allow-unsatisfiable`) or a self-lockout (unless `--i-lock-myself-out`).

**`can_any` (`:511-618`).** Constructs `write_pins` (`:461-492`) with before, after and delta slot constraints for one free field and prints a paste line `invoke ID {name} write {field} {value} {now}`.

**Rust walks predicate JSON but does not evaluate it.** `slots` (`:404-424`) and `law_fields` (`:435-455`) collect slot names only.

---

## 2. What it assumes of its surroundings

### 2.1 Host protocol operations used, with the Lean cross-check

The envelope (seen in tests and shared by every `session_invoke`): `[2][u32 LE config length][config bytes][32-byte host image SHA-256][op][payload]` (`share_issue_receipt.rs:286-293`, `key_adoption.rs:949-953`).

**Registered Host operations sent by this shard:**

| Op | Symbol (registry) | Routes | Rust site(s) | Payload Rust sends | Lean receiver | Agreement |
| --- | --- | --- | --- | --- | --- | --- |
| 4 | OBSERVATION_CHALLENGE | public, operator | `participant_enrollment.rs:540-552` | `u32 len ‖ intent ‖ sig64` | `dispatchSession` | agrees per the comment at `:535-536`; not independently traced |
| 5 | AUTHORIZED_QUERY | public, operator | `participant_enrollment.rs:588-596` | signed observation | `dispatchSession` | the view is decoded as `view-resource` |
| 6 | PROFILE | public, operator | `key_adoption.rs:404`, `enrollment_bootstrap.rs:802-808` | empty | `dispatchSession` | the JSON fields `domain`, `semantics`, `expectedSeed` are used |
| 7, 8, 9, 10, 11 | AUTHOR, INSPECT, SIGNATURES, OBS/CALL_ASSEMBLE | public, operator | everywhere (`kind_payload` u16-LE label) | label ‖ body | `dispatchSession`, but locally via `serveCodec` (`client_consent.rs:1001-1050`) | `staged_invoke` sends 7-11 to the local codec (`participant_enrollment.rs:262,285-289`); `key_rotation`, `seat` and `share_issue` still send 7 and 8 over the socket or a one-shot Host |
| 28, 29 | APPLICATION_SHARE_ISSUE_SUBMIT/LOOKUP | public, operator | `share_issue.rs:383-390,431-437`, `share_issue_receipt.rs:22` | exact ingress | `fnDispatch` `Host/Main.lean:6755,6759` | outcome codec |
| 30, 31 | APPLICATION_(SESSION_)CURRENT_BIRTH | public, operator | `current_birth.rs:45-51,167` | source JSON bytes | `Host/Main.lean:7317,7321` | reply `[op] ‖ intent` |
| 32, 33 | APPLICATION_SHARE_ISSUE_PLAN/ASSEMBLE | operator | `share_issue.rs:508,571` | request; `u32 ‖ plan ‖ signatures` | `:7454,7463` | — |
| 54, 55 | GRAIN_SHARE_ISSUE_SUBMIT/LOOKUP | **operator only** | `grain_share_issue.rs:534-541,579-585`, `share_issue_receipt.rs:23` (recipient) | exact ingress | `:6763,6767` | see §4 F-14 and Q4 |
| 56, 57 | GRAIN_SHARE_ISSUE_PLAN/ASSEMBLE | operator | `grain_share_issue.rs:357,445,503` | — | `:7473,7482` | — |
| 82-85 | APPLICATION_SESSION_ENROLLMENT_* | operator | `session_enrollment.rs:20-23` | request; pair; ingress | `:7689,7702,6779,6784` | registered client constants |
| 86-89 | PARTICIPANT_KEY_ENROLLMENT_* | public, operator | `participant_enrollment.rs:917-925,1568-1576,1719,1695` | `pair(signedObs, command)`; `pair(plan, pair(sponsorSig, poss ‖ next32 ‖ cosign64))`; ingress | `:7719,7731,6789-6798` (88: `NativeHost.enrollmentSubmitLoaded`; 89: `enrollmentLookupLoaded`) | 88 and 89 return `(op, outcomeCodec)`; the assembly layout of the 64- or 160-byte second half is from the Rust comment (`:1561-1566`), see Q15 |
| 91 | CURRENT_RESOURCE_BIRTH | public, operator | `current_birth.rs:49` | `pair(observation, source)` | `:7440` | — |
| 92-95 | PARTICIPANT_PROVISIONING_* | public, operator | `participant_provisioning.rs:20-23` | same shape as enrollment with one signature | `:7749,7761,6799-6808` | `provisionLookupLoaded` (`Kernel/NativeHost.lean:1484-1497`) |
| 96-102, 180 | FLEET_* | public, operator | `fleet.rs:525,552,567,289,845,762,744,1000` | 96 `pair(obs, draft)`; 97 `pair(plan, sig)`; 98 and 99 ingress; 100 and 180 `pair(obs, json{topic, cursor, limit})`; 101 signed observation; 102 decimal transaction id | `Host/Main.lean:6809-6870,6857` | 96 splits the pair (`:6809-6811`); 97 splits `(planBytes, signature)` (`:6821-6823`); 98 `fleetSubmitLoaded` replays first (`Kernel/FleetTurnReceiver.lean:186-188`); 99 never answers contention (`Kernel/NativeHost.lean:1500-1511`) |
| 112 | PAY_ENROLLMENT_VIEW | public, operator | `enrollment_bootstrap.rs:421` | empty | `fnDispatch` | view type `DREGG/PAY/ENROLMENT-VIEW/v3` |
| 121 | PAY_ENROLLMENT_QUOTE | public, operator | `enrollment_bootstrap.rs:691` | strict 4-key JSON, reserialized by serde (`quote_body` `:264-279`) | `fnDispatch` | "public quote 121 has its bounded JSON-object guard" (`protocol/HOST-OPERATIONS.md:70-71`) |
| 130 | dry run | — | `can.rs:111-120` via `main::dry_run` | — | (shard A) | — |
| 140-144 | KEY_ROTATION_* | public, operator | `key_rotation.rs:685,716-725,746,752-756,109,125` | 140 command bytes; 141 `pair(plan, sig)`; 142 and 143 ingress; 144 JSON `{subject, publicKey}` | `Host/Main.lean:6997-7027` | 141 `splitPair` (`:7008`) ✓; 142 and 143 always answer `(op, outcomeCodec)` (`:7015-7026`), see §4 F-1; 144 `subjectKeyStatusQuery` uses `exactObject ["subject", "publicKey"]` (`Host/Json.lean:4344-4350`) ✓ |
| 150 | LAW_SAT | public, operator | `lawsat.rs:60-65` via `main.rs:1516` (process verb `law-sat`) | request JSON file | `dispatchSession` `Host/Main.lean:2074` | — |
| 181-186 | PAY_CLAIM_* | public, operator | `enrollment_bootstrap.rs:357-362,649` | raw body after `transport::allowed_operation` (`:292-297`) | `fnDispatch` | — |
| 187-190 | NEXT_KEY_ADOPTION_* | public, operator | `key_adoption.rs:197,239-245,298,305` | 187 JSON `{subject, nonce, currentPublicKey, nextPublicKey}`; 188 `pair(plan, pair(cur, next))`; 189 and 190 ingress | `Host/Main.lean:6967-6995` | 188 `splitPair` twice (`:6973-6974`) ✓; 189 and 190 share one arm, with optional carried receipt substitution (`:6980-6995`) |
| 193, 194 | APPLICATION_DISPATCH_READY / AUTHENTICATED_PLAN | public, operator | `member_app.rs:10-11,264,300` | 194 `pair(request, pair(auth64, obs chain))`; 193 `pair(plan, signatures)` | `Host/Main.lean:6935,6945`; `Host/ApplicationDispatchReady.lean:27-30` | `authenticationBytes` matches the Rust bytes exactly |
| 215-219 | SEAT_* | public, operator | `seat.rs:125,133,142,191,196,103` | command; `pair(plan, sig)`; ingress; ingress; JSON | `Host/Main.lean:6003-6026` | — |

**Local consent provider frames.** These form a separate executable and an **unregistered** namespace. 220-233 are absent from `protocol/host-operations.json`, whose highest code is 219 (checked by enumerating all 186 entries). They are listed in §1.10. Lean: `Host/ClientConsentCore.lean:369-380` (220-222), `:420-440` (230-232), `:458-489` (224, 226), `:552-610` (226, 228, 229, 233, 224, 227).

**Registry gate coverage.** `protocol/HOST-OPERATIONS.md:55-58` says the gate "scans only the request selector in these named dispatch structures and explicitly registered client constants. It does not scan … arbitrary invoke arguments". Only `participant_provisioning` (92-95), `session_enrollment` (82-85) and `member_app` (193, 194) in this shard are registered client constants (`protocol/host-operations.json` `client_constants`). Every other byte in the table above is an unscanned literal.

### 2.2 OS facilities

**Unix-only paths.** Most arms are `#[cfg(unix)]` (`main.rs:3197-3330`). The shard uses:
- `libc::poll`, `fcntl` and `O_NONBLOCK` (`key_service.rs:31-74`);
- `F_SETPIPE_SZ` (Linux-only, in a test, `key_service.rs:304`);
- `flock` (`client_consent.rs:478`);
- `setsid` via `pre_exec` (`client_consent.rs:423`);
- `geteuid` and `SO_PEERCRED`/`getpeereid` through `transport::peer_uid` (`client_consent.rs:400,523`);
- `umask` via an `extern "C"` declaration (`session_reenroll.rs:821-833`, process-global);
- raw `dup`/`dup2` on fds 1 and 2 (`fleet_sign.rs:734-767`);
- `/dev/urandom` read directly (`seat.rs:94-100`).

**Not used in this shard.** bwrap, seccomp, cgroups, systemd and setuid.

**Files and modes.**
- Secrets are raw 32-byte Ed25519 seeds, created with `create_private` (0600, O_EXCL via `mini_sdk::durable`, `fsio.rs:16-18`). Public halves use `create_public` (umask).
- Retained custody uses `fsio::retain_exact` with `Perm::Private` (`fsio.rs:54-59`).
- Secret reads require an owner-private regular file and, for `*_in_private_dir`, an owner-private parent (`mini_sdk::secret::Custody::FileAndDirectory`; `fsio.rs:140-152`).

**Environment variables read in this shard:**
- `MINI_CONSENT_HOST`, `MINI_CONSENT_CONFIG`, `MINI_LOCAL_HOST`, `MINI_CONSENT_RESIDENT`, `MINI_CONSENT_IDLE_S`, `MINI_CONSENT_ANCHOR_DIR`, `MINI_THIN_CONSENT`, `HOME` (`client_consent.rs:51,105-108,157-163,267,324,377,463`);
- `MINI_FLEET_HOME`, `MINI_PROFILE`, `MINI_FLEET_SPONSOR`, `MINI_FLEET_FACTORY_REF` and the six `DREGG_*` variables, which are only reported as unread (`fleet_sign.rs:74-84,122-129,774-793`).

### 2.3 Network services

- **`enrollment_bootstrap.rs`.** The only TCP listener. Plain HTTP on a private address behind an operator TLS proxy (Caddy template, per `docs/review/2026-10-26-deploy/HCLOUD-GAP.md:126,172`).
- **ssh.** Used by `key_service::client` (forced command `mini-provider-credentials-v1`) and by every `--remote ssh:DEST` session through `transport` (shard A).
- **Not in this shard.** No Solana, Discord or provider HTTP calls. Payment observation happens elsewhere, and the bootstrap only relays Host ops 181-186 and 121.

### 2.4 Other crates and binaries

**Path dependencies.**
- `mini-sdk` (`decimal`, `hex`, `private`, `durable`, `lock`, `operator`, `secret`, `random`, `custody`, `signer`; counted by grep in §5).
- `mini-keys` (client and wire; with the server in dev-dependencies only, `Cargo.toml:41-48`).
- `compatible-upgrade-custody` (`session_reenroll.rs:170-333`).
- `grain-runtime/src/credentials.rs`, compiled in by `#[path]` (`keys.rs:35-37`).

**Executables invoked.**
- The Host image: for socket sessions, the codec loop (`HOST SETTINGS codec`), and one-shots `HOST CONFIG author|inspect|signatures|lookup|submit|law-sat`. One-shots appear in `share_issue.rs:17-32`, `share_issue_receipt.rs:83-92`, `grain_share_issue.rs:78-98`, `session_reenroll.rs:584-588,654-662`, `main.rs:1516-1526` and `participant_enrollment.rs:1291-1292`, the last being the portable verifier.
- `minidregg-client-consent` and its resident wrapper (`mini consent-resident`).
- `native/credential-signature-verifier` is **not** invoked by this shard. The Lean Host uses it (its `verify_strict` is at `credential-signature-verifier/src/main.rs:38,113`).

---

## 3. Does it decide anything semantic?

### 3.1 Places where Rust IS the decision (violations or near-violations)

| # | Site | What Rust decides | Lean counterpart that should own it | Blast radius if wrong |
| --- | --- | --- | --- | --- |
| S-1 | `session_reenroll.rs:601-667` (intent at `:630`); encodings at `:416-430`, `:615-626`, `:702-719` | **Authors the session-close state transition.** A raw scalar `invoke` writes field 2 to `generation+1` and field 3 to `status+1`, guarded only by `expected` values. It also asserts that app field 1 equal to `"4"` means serving and that session status `"1"` (web) or `"5"` (api) means active (`:420-424`, `:624`). | A Lean session lifecycle command (close/supersede) or a Lean-emitted state view. The registry has none for closing an event-28 session; the closest is the general `invoke` path. See Q5. | If the Lean encoding changes, or `status+1` is not "closed" for some kind, Rust writes a well-typed but meaningless state that Lean admits as an authorized scalar write. Reenrollment then builds on it (`request_from_prior`, `session_enrollment::plan`). The scope is SPK app sessions. |
| S-2 | `participant_namespace.rs:178-188,212-286`; used by `participant_enrollment.rs:837-848,885-891` and `participant_provisioning.rs:62-78,144-147` | **Chooses subject numbers, keyIds and capability ids** for new principals (random in [2^63, 2^64)). | The receiver refuses collisions. Per the probe README, "Existing subject, duplicate key ID … refuse" (`docs/evidence/2026-09-28-participant-key-enrollment/README.md:22-25`). This is mirrored allocation with Lean as the uniqueness gate; the choice itself is Rust's. Q1. | Low. A collision is refused at plan or submit. Identity numbers are client-chosen and permanent. |
| S-3 | `participant_enrollment.rs:885-891`, `key_rotation.rs:518-525,653-656` | **Authors KeyRecord content:** `keyEpoch "1"` (enrollment) or `epoch+1` (rotation, computed from op 144), `algorithm "1"`, `activeFrom "0"`, `activeUntil u64::MAX`. A key never expires. | The receiver presumably checks epoch continuity. Whether `activeUntil = MAX` is policy or default is a Lean question (Q6). | If Lean accepts any activeUntil, every enrolled key is permanently valid by client choice. If the epoch rule differs, the plan is refused (fail-closed). |
| S-4 | `fleet.rs:1084-1091` | **Default law of a fleet agent's new funded account** is `{"type":"all","predicates":[]}` (permit-all). The deployed shell provisioning also writes `permit-all.json` (`deploy/shell/OPERATOR.md:66-70`). | A Lean-emitted default policy for agent or member accounts. | Every fleet-joined account (and every shell-provisioned account) runs under a law that admits any step its capabilities allow. |
| S-5 | `key_service.rs:148-158` (also `key_adoption.rs:91-103`, `mini-keys/src/server/native.rs:79`) | **"This key is the current owner, so the provider-credential action may proceed"** is decided by Rust from Lean status facts. `grain-runtime/src/provider_owner.rs:45-62` spawns `mini key --action owner-status` and trusts this check. The grant table itself (per-call tokens, per-day calls, until-height) lives in the broker, not in Lean. | None. Provider-key grants are a Rust-side authority domain. | Who may spend a pooled or member provider key and how much. The broker reader owns the server half; the client half mirrors it. |
| S-6 | `fleet.rs:174-189,208-210` | **The fee a fleet turn may carry** must equal `tariffBase` read from the local pinned config file. | `config.tariff` inside Lean (`Kernel/NativeHost.lean:1468`). Rust enforces equality as consent. | Fail-closed: a non-flat Lean tariff would make every fleet turn refuse. It is still a price rule written into the client. |
| S-7 | `enrollment_bootstrap.rs:453-471` | **Public lease state `enrolled` or `expired`** shown to strangers, from `hour < expiresAt`. The code calls it "Presentation … not a new admission rule". | The Lean lease predicate (inclusive or exclusive bound, clock source). Q14. | The public status page can say "enrolled" when Lean says expired, or the reverse, at the boundary hour. |
| S-8 | `fleet_sign.rs:381-412` | **Mints `turn_hash` and `receipt_hash`** (a Rust-defined SHA-256 domain `MINI.FLEET-SIGN.RECEIPT-HASH/v1\0`) that a harness treats as receipt identity. | None: a harness compatibility layer. Receipts are Lean's four fields. | If helm stores `receipt_hash` as proof, it is a Rust-defined digest that no Lean component verifies. |
| S-9 | `law_export.rs:14-26,30-66` | **The next policy revision number** (`previous+1`, decimal string) and which facets carry over. | The Lean policy installer must check `version` and `previous` (Q12). | Fail-closed if Lean checks. If it does not, Rust picks revisions. |
| S-10 | `session_reenroll.rs:353,629,721`; `seat.rs:94-100` | **Nonce allocation arithmetic**: `nonce+100+index`, `nonce+1`, `nonce+2` from a user-chosen base; seats use `/dev/urandom` u128. | Lean replay identity. | Reusing a contract in a new directory reuses nonces, which Lean refuses as conflicts. |

### 3.2 Places where Rust mirrors a Lean decision for UX (Lean is still the gate)

- **`check_commitment`** (`key_rotation.rs:226-265`) refuses to build on a subject whose next-key commitment is not the client's own. This is participant self-protection from op-144 facts; Lean still gates rotation itself (`notPrecommitted`, journey JROT title `journey.sh:1067`).
- **`join_possess`** (`participant_enrollment.rs:1235-1253`) refuses a sponsor plan committing to someone else's next key. Same self-protection.
- **`validate_plan`, `check_plan`, `exact_plan`, `approved_header`, `check_ready`** throughout compare Host-inspected views to the drafted request before signing. That is consent. Lean re-decides at submit.
- **`client_consent::operator_plan`** and frames 220/221/222/226: the local **Lean** provider reconstructs the plan. Rust only compares bytes (`client_consent.rs:1099-1104`, `:1109-1114`).
- **`can.rs`** decides which probes to run from its reading of capability records (`mine`, `covers`, `:239-251`) and a shell-to-kernel verb table (`:22-33`). Every printed verdict is the Host's dry run. A skipped probe is UX only. `--all` reports Host disagreement.
- **`lawsat::install_check`** refuses to propose unsatisfiable or self-locking laws (`:362-391`). This is stricter than Lean (Lean accepts `sealed`). It is the user's own consent, with an override flag.
- **`seat::donation_gate`** (`seat.rs:155-165`) refuses to sign a donation without confirmation. Consent.
- **`member.rs`** room resident rendering reads `room_schema::TARIFF_FIELDS` keys (`member.rs:333-354`). Presentation, labelled `currentness` (`:350-353`).
- **`fleet::feed`/`incoming`** ordering and strict-ascending checks (`fleet.rs:818-828`, `:998-1003`) assert Lean invariants client-side and refuse when they are violated. Fail-closed presentation.
- **`status_if_enrolled`** classifies one Host refusal by its English detail text (`key_rotation.rs:139`). It maps to a proceed/refuse UX choice in `workspace.rs:607`. It is fragile but fails closed.

### 3.3 Places that correctly defer

- No module hashes or encodes a Lean value for the rotation command, enrollment command, provisioning command, fleet draft or seat command. Every one goes through op 7 (local codec or Host) and op 8. The adoption and protected rotation paths use only the pinned local verifier (`key_adoption.rs:25-44`, `key_rotation.rs:624-707`).
- Every outcome is decoded by the Host or local codec `inspect outcome`, never parsed from bytes in Rust (`fleet.rs:65-84`, `client_consent.rs:1036-1049`).
- Admission results are written only after `confirmed` outcomes: `participant_enrollment.rs:1661-1681`, `participant_provisioning.rs:264-283`, `key_adoption.rs:318-369`, `key_rotation.rs:759-771`.

---

## 4. Flaws noticed

### F-1 (high): a refused key rotation wedges the workspace's rotation forever

**Where.** `key_rotation.rs`:
- `:679-684`: the `refuse` closure marks the attempt refused only if the error string starts with `"host refused"`.
- `:31-53`: that string comes only from 254 or 255 frames.
- `:745-757`: op 142 is called after phase `submitted`. A typed refusal comes back inside a 142 frame (`Host/Main.lean:7015-7020` always answers `(142, outcomeCodec.encode outcome)`).
- `:758-765`: the outcome is decoded as `refused` and the function returns Err without changing phase.

**Scenario.** The subject's epoch moved, or the signature is wrong.
1. `mini rotate-key` → op 142 → `{"type":"refused",…}` → error, phase still `submitted`.
2. Re-run → `recovered=true` → op 143 → `absent` (a refused submission is not recorded) → error.
3. `--new-attempt X` → `:471-480` "retained rotation is unresolved; recover its original attempt before a new succession".

There is no exit short of hand-deleting `rotation-active.json`. The same happens when op 142 is never forwarded (transport failure before the Host). `journey.d/jrot-lookup.sh:107-116` asserts that state ("rotate-key refuses to claim it") but nothing resolves it.

**Fix shape (not applied).** Record a typed `refused` outcome as phase `refused`. For `absent`, either allow exact resubmission (only if op 142 is replay-first, Q2) or let `--new-attempt` supersede an `absent` lookup after a fresh status check.

### F-2 (high): retained secret copies defeat pre-rotation and "move it off the box"

**Where.**
- `key_rotation.rs:526-533` copies `original-next.key` and `original-daily.key` into `attempts/rotate-ID/`.
- `:534-539` creates `after-next.key` there.
- `:783` installs it at `--next-to` (other media).

Nothing deletes the attempt copies (`key_rotation_custody.rs` has no removal). After a rotation, the box holds the new daily key and also the **new next key**, in the workspace attempts directory. This holds even when the user followed `HOSTED_PREROTATION_NOTICE` (`:24-27`) and put the next key on other media. A thief who takes the workspace can rotate the subject to themselves.

**Related custody facts.**
- The deployed operator onboarding copies the newcomer's daily secret into the sponsor's keys directory (`deploy/shell/OPERATOR.md:44-49`) and removes it afterwards by a manual `rm` (`:65`).
- `fleet-sign join` generates key and next key side by side under `~/.mini-fleet/profiles/NAME/` (`fleet_sign.rs:295-300`).

### F-3 (high): `fleet-sign` can commit twice after an `uncertain` resubmission

**Where.**
- `fleet_sign.rs:510-511`: `Ok(fleet::confirmed(&outcome).then(...))`. Any outcome other than confirmed, including `uncertain` and `unavailable` from op 98 (`Kernel/NativeHost.lean:1481-1482`), is treated as "never admitted".
- `once` then calls `finish(profile)` (`:545`), deleting `operation.json` and the journal.
- It writes a new record and runs a fresh turn with a new attempt and nonce (`:547-554`).

**Scenario.** Call 1 loses its reply. Call 2 resolves by resubmitting the same ingress. The Host's durable write is uncertain, so the answer is `uncertain`. The resubmitted turn may have been admitted. Call 2 nevertheless submits the payment again.

**Contrast.** `fleet::recover_operation` treats exactly these outcomes as "uncertain" (`fleet.rs:392-396`).

### F-4 (medium): the `fleet-sign` operation record is neither private nor durable

**Where.** `write_private` (`fleet_sign.rs:514-520`) uses `fs::write` (umask permissions, despite the name), syncs the file, and renames without a directory fsync.

**Scenario.** A power loss after the turn's submit marker but before the directory entry is durable loses `operation.json`. The next call sees no pending operation, so the at-most-once guarantee in the module doc (`:437-449`) fails. The journal line is appended with `sync_all` but no directory fsync either (`fleet.rs:616-627`). Its file exists from `once`'s `write_private(…, b"")`.

### F-5 (medium): `session-reenroll` exits 0 on refusal

**Where.** `session_reenroll.rs:905-925`. On `Err`, `run` prints `{"status":"refused"|"uncertain",…}` and returns `print_json(...)`, which is `Ok`. `run_inner` also converts inner errors to a verdict JSON and returns `Ok` (`:878-902`).

**Effect.** Any shell caller that checks the exit status sees success. This breaks law 10 (refusal must be loud).

### F-6 (medium): Rust-authored session close

**Where.** S-1 above.

**Further problem.** `ensure_closed` ignores the `send_close_once` result (`let _ = …`, `:650-664`) and relies on the following lookup. `resume` ignores `session_enrollment::submit` errors (`:768`) and relies on `authenticated_anchor`. These are deliberate (lookup decides), but a refused close leaves `close/submit-marker.json`, and every later resume is lookup-only on a refused call.

### F-7 (medium): consent coverage is defined by three disagreeing lists

**The lists.**
- `client_consent::plan_operation` (`client_consent.rs:1093-1095`): 31 ops.
- `mini_sdk::consent::OPERATOR_PLAN_OPS` (`mini-sdk/src/consent.rs:19-20`): 29 ops. Its own comment says "29 opcodes" and points at the Rust list, but it lacks 210 and 215.
- Lean `NativeSpecializedConsent.supported` (`Kernel/NativeSpecializedConsent.lean:29-30`): 15 ops. The rest must go through `extraExpected` with full re-admission (`Host/ClientConsentCore.lean:463-467`).

**Gaps in all three.**
- Grain share plan op 56 (`grain_share_issue.rs:357,445`).
- App plan op 194 (`member_app.rs:264`).
- Rotation plan op 140 is in the list but is also locally inspected.
- Adoption plan op 187 relies on the local verifier instead.

**Why it matters.** A plan op missing from the transport list is signed without a local consent reconstruction. `grain_share_issue::prepare` signs headers after only approval-hash equality (`:474-484`).

### F-8 (medium): the key broker's signed bytes depend on serde_json key order on both sides

**Where.** `key_service.rs:141-147` signs `serde_json::to_vec(request)`. The broker re-serializes its parsed JSON (`mini-keys/src/server/member.rs:34-38`).

**Why it works today.** Both use `serde_json` without `preserve_order` (resource-client enables `arbitrary_precision` only, `Cargo.toml:21`), so keys are BTreeMap-sorted.

**Fragility.** A feature unification change (`preserve_order` enabled anywhere in the broker's dependency graph) would break every member action. It fails closed with bad signatures. The canonicalization is a Rust-to-Rust convention, not a Lean codec.

### F-9 (low to medium): a definitive refusal wedges enrollment, adoption and provisioning on lookup

**Where.**
- `participant_enrollment.rs:1719-1728`: a typed `refused` from op 88 falls through to `lookup_exact`, which needs `replayed` and errors. A second `submit` is lookup-only (`:1709-1713`).
- `key_adoption.rs:294-305`: a refused op 189 falls to op 190 lookups forever, under the default attempt name.
- `participant_provisioning.rs:431-438`: the same pattern.

**Exits.** These can be escaped: a new `--name` label and directory for enrollment, a new `--attempt` for adoption. Unlike F-1, an exit exists, but nothing tells the user that the attempt was refused rather than uncertain. The error says "did not confirm historical acceptance".

### F-10 (low): Rust checks possession signatures less strictly than the Host

**Where.** `participant_enrollment.rs:1260,1435,1547` use `VerifyingKey::verify` (non-strict). The Host's verifier uses `verify_strict` (`credential-signature-verifier/src/main.rs:38,113`). Rotation and adoption use `verify_strict` (`key_rotation.rs:186`, `key_adoption.rs:166`).

**Effect.** A malleable or small-order signature would pass the sponsor's pre-check, then be refused at submit after a submit marker was written (feeding F-9).

### F-11 (low): `join --key` writes `KEY.pub` under a different name from rotation's convention

**Where.** `participant_enrollment.rs:1142` calls `keygen(&key_path, &key_path.with_extension("pub"), …)`. That produces `me.pub` for `me.key`. `key_rotation::conventional_public` (`:280-284`) and the rotation installer (`:798-802`) use `me.key.pub`.

**Effect.** After a rotation, `me.pub` still names the rotated-away key and a fresh `me.key.pub` is created.

### F-12 (low): every refusal of a provisioning lookup becomes "historical differs" without worldRoot

**Where.** `participant_provisioning.rs:477-481` compares three receipt fields but not `worldRoot`. Every other module compares four (e.g. `participant_enrollment.rs:1273-1280`).

### F-13 (low): `can --all` leaves attempts behind

**Where.** `can.rs:110` creates a `workspace::new_attempt` per probe and never removes it. In a hosted shell, every `can` run grows `WS/attempts/` permanently.

**Theoretical panic.** `random_nonce()?[..8]` (`can.rs:198`) panics if the decimal nonce is shorter than 8 characters. With `mini_sdk::random::decimal_nonce` that is astronomically unlikely, but it is unchecked slicing.

### F-14 (low): the recipient grain receipt route uses an operator-only op

**Where.** `share_issue_receipt.rs:23` sends op 55 for `GrainBackedEvent22`. The registry lists op 55 as `operator` only. The recipient profile's doc (`:1-4`) and tests (`public.sock`, `:316-318`) imply a public route. On a public socket this is refused by transport. Q4.

### F-15 (low): unbounded or unchecked reads of local files

- `current_birth.rs:114-115`: `fs::read(supplied)` reads the whole signed observation and checks the size afterwards.
- `seat.rs:39-45`: `fs::read(workspace.json)` reads it and only then checks 64 KiB. It follows symlinks with no ownership check, unlike `workspace::load` elsewhere.
- `seat.rs:167-169`: `read_ingress` is unbounded.
- `fleet_sign.rs:180`: `ACTIVE` is read with `read_to_string`, unbounded.

All are local-user inputs, so the severity is low.

### F-16 (low): the bootstrap's accept loop does blocking 503 writes

**Where.** `enrollment_bootstrap.rs:855-859` writes the 503 for a full queue on the accept thread with a 100 ms deadline. A client that opens many connections while the queue is full costs the accept loop up to 100 ms each, stalling admission of new connections.

**Configuration footgun.** Without `--trusted-proxy`, all clients behind the TLS proxy share the proxy's IP budget: 6 quotes per minute and 12 status calls per minute for the whole internet (`:604-614`; the test `:1210-1232` confirms spoofed `X-Real-IP` is ignored).

### F-17 (low): consent anchor retention fails silently

**Where.** `client_consent.rs:222-241`. A failure to fetch or save the anchor only prints a warning.

**Effect.** It costs only performance (the next provider admits from an older anchor or from genesis), but on a large Store each `mini` process may silently re-admit from genesis. The resident provider mitigates this.

**Resident daemon details.**
- The daemon is started with `setsid` and outlives the shell session (`:418-424`).
- One provider per (executable inode, settings bytes). In a hosted shell with N members each pinning their own settings, N providers each hold a fully admitted Store.

### F-18 (info): zeroization is best effort

**What is done.**
- Seeds are `Zeroizing` (`fsio.rs:140-152`), `SigningKey` zeroizes on drop (ed25519-dalek `zeroize` feature, `Cargo.toml:19`), and the explicit fills in `keys.rs:89,293` and `key_service.rs:106,135,218,223` work.

**What is missed.** The provider secret passes through `json!` and `serde_json` allocations (`keys.rs:210`, `key_service.rs:215-221`) whose intermediate buffers are freed without zeroing.

**Argv and logs.** No secret appears in argv, env or logs in this shard. Key paths do appear in argv, and `keys.rs:357-360` forbids secrets on the line.

### F-19 (info): seat submit has no submit marker

**Where.** `seat.rs:111-150`. `ingress.bin` is retained before op 217, but no may-have-submitted marker exists and `outcome.json` is written only on success.

**Recovery.** `resubmit` and `lookup` exist (`:188-197`). Exact resubmission is safe only if op 217 replays first (Q3).

### F-20 (info): two recovery philosophies in one crate

**Exact resubmission (relying on Lean replay-first):**
- `fleet::resubmit` (`fleet.rs:706-728`);
- `seat --action resubmit` (`seat.rs:188-192`);
- `fleet-sign retry` (`fleet_sign.rs:716-732`).

**Lookup only, never resubmit:**
- key rotation (`:754-757`);
- adoption (`key_adoption.rs:279-306`);
- enrollment (`participant_enrollment.rs:1709-1713`);
- provisioning (`:377-383`);
- session enrollment (`:399-412`);
- share and grain share (`share_issue.rs:375-377`, `grain_share_issue.rs:526-528`);
- session reenroll close (`:562-574`).

The README's founding statement, "a lost reply keeps the original operation and its exact retry", suggests the first. F-1 shows the second can wedge.

---

## 5. Unwired, undone, twins and dead code

### 5.1 Twins

| Twin | Site A | Site B | Reachable | Verdict |
| --- | --- | --- | --- | --- |
| Next-possession frame | `key_rotation.rs:156-160` (Rust copy, used offline by keygen `main.rs:1176-1178` and checked at runtime only in `enroll plan` `participant_enrollment.rs:873-878`) | `Kernel/ParticipantKeyEnrollment.lean:64-68`; also `Compiler/PersistedCodecTags.lean:172` | both | Law 13 imitation, deliberate so keygen can run offline. At least add a persisted-tag test tying the Rust bytes to `PersistedCodecShapes.lean:536`. |
| App authentication frame | `member_app.rs:96-102` | `Host/ApplicationDispatchReady.lean:27-30` | both | Imitation. Replace with a Host op-7 `author` kind. |
| Broker member signing frame | `key_service.rs:141-147` | `mini-keys/src/server/member.rs:34-38` | both | Rust-to-Rust twin. Move it into `mini_keys::wire` and use it from both sides. |
| Current-key check | `key_service.rs:148-158` | `key_adoption.rs:91-103` and `mini-keys/src/server/native.rs:79` | all | Three copies of one predicate. |
| Consent framer | `client_consent.rs` (in use) | `mini-sdk/src/consent.rs` (used only by `mini-sdk/src/flow.rs`) | A by `mini`; B by SDK users | Opcode lists already drifted (F-7). Delete one. |
| Exact-call custody state machine | about 9 hand-rolled copies: `key_rotation.rs`, `key_adoption.rs`, `participant_enrollment.rs`, `participant_provisioning.rs`, `session_enrollment.rs`, `share_issue.rs`, `grain_share_issue.rs`, `fleet.rs`, `seat.rs` | `mini-sdk/src/custody.rs` ("ONE state machine … bugs D2/D5/D7 were divergences between copies", `:1-7`), used in resource-client only by `workspace.rs:4028-4030` and `app_document.rs:12` | all | Delete the twins in favour of `mini_sdk::custody`. F-1, F-9 and F-20 are the divergence the SDK comment warns of. |
| Share-issue custody | `share_issue.rs:159-367` (`retained`, `reinspect`/`retained_outcome_bytes`, `historical_anchor`) | `grain_share_issue.rs:19-215` (near copies) | both via `main` | Merge, parameterized by op pair and format string. |
| Host one-shot inspection | `share_issue::source_process`/`source_inspect` (`:17-55`), `share_issue_receipt::inspect_direct` (`:80-101`), `grain_share_issue::inspect_bounded` (`:78-98`), `session_enrollment` via `agent_reserve::source_inspect` | `client_consent::local_frame` codec child. Its doc says "no client path runs a one-shot `HOST CONFIG inspect` any more" (`client_consent.rs:1053-1055`), which these sites contradict. | both | Route these through the codec child. |
| Joining flows | `fleet::join` (`fleet.rs:1017-1137`): enroll local key, init, funded account with permit-all | shell operator path `deploy/shell/OPERATOR.md:44-77` (enroll, then `workspace --action provision`: observe grant plus funded account); `platform-provision.py`; paid onboarding (`join_solana*`, `paid_onboarding.rs`, outside this shard) | all | Four compositions of the same stages (§5.3). |
| `mini join` | `participant_enrollment::join` | `join_solana::run` and `join_solana_v2::run` selected by flags (`main.rs:3197-3202`) | all | One verb name dispatching to three programs. |
| Nonce helpers | `seat.rs:94-100` (`/dev/urandom` u128) | `fsio::random_nonce` (`mini_sdk::random::decimal_nonce`) | both | Delete the seat copy. |
| Pair framing | `participant_enrollment::pair` (refuses empty components), `fleet::pair` (the same), `client_consent::pair` (allows empty), `member_app::pair`, `seat::pair` (unbounded, no checks, `seat.rs:87-92`), inline in `share_issue.rs:567-570`, `grain_share_issue.rs:499-502`, `session_enrollment.rs:277-284` | `mini_sdk::frame::pair` (SDK) | all | Eight copies of a four-line codec with different bounds. |

### 5.2 Unwired or undone

- **`key_adoption.rs`.** Wired (`adopt-next-key`, shell verb), but its only native journey has never passed: "Until this harness passes on an actual matched Host, native adoption-to-rotation remains unverified" (`KEY-ADOPTION.md:122-124`). Its 796 test lines run against fakes.
- **`client_consent::objective_headers`** (frame 227). The doc calls it "Objective-only source WIP … An older provider refuses this endpoint" (`client_consent.rs:1116-1120`).
- **Thin consent** (`MINI_THIN_CONSENT=1`, frames 230-232). Opt-in by env and not used by any journey I found.
- **`enrollment_bootstrap.rs`.** Wired as a `mini` arm and run by `journey.d/jpay-e4.sh`, but no deploy unit exists. Pay is "not deployed" (README Honest state).
- **`session_reenroll.rs`.** No journey row. Only a fixture script references it (`scripts/spk-platform/ws-continuity-fixture.py`) along with a deploy doc.
- **`#[allow(dead_code)]`.** `keys.rs:36` on the shared `credentials` module and `native/host-operations.rs:3`. No `todo!`, `unimplemented!`, `TODO` or `FIXME` appears in the shard (grep).
- **`key_rotation.rs:427-431` `--to-public-key`.** A journey-only switch ("an honest rotation never uses it") left in the production verb.
- **Dead statement.** `seat.rs:209` `let _ = &ws.root;` exists only to silence an unused field.
- **Tests that test little.**
  - `participant_enrollment.rs:1967-1984` `raw_possession_and_sponsor_headers_remain_distinct` asserts that two different keys signing different bytes give different signatures, and checks `pair`'s length prefix.
  - `fleet_sign.rs:872-878` checks a const array against a literal list.
  - `enrollment_bootstrap` tests are strong (real framing, rate limits, permits).

### 5.3 The enrollment state machine: six modules, which are stages and which are not

```
participant identity (key-only):
  keygen (main.rs:1098)  ──►  enroll plan (P-E, ops 4/5/7/8/9/10 + 86, namespace reserve)
     │                          │  [public-key variant: enroll offer → participant `join --sponsor-plan` → possess (226)]
     │                          ▼
     │                        enroll seal (224 consent, sponsor sig, possession sig, op 87)
     │                          ▼
     │                        enroll submit (marker → op 88 → op 89 lookup)  ──► enrollment.json "admitted-key-only"
     │                          ▼
     │                        enroll welcome ──► participant `join --welcome` (op 89 lookup only, local verifier)
     ▼                          ▼
  workspace init (--enrollment)  /  init_fresh_receipt
                                ▼
  fresh_onboarding::complete (op 151 via HostProof; awaiting-first-read → verified-candidate → complete)
                                ▼
  sponsor: workspace --action provision
     ├─ participant_provisioning::observe_grant (ops 92-95: factory-observe capability for the holder)
     └─ workspace::create_funded_account (ordinary birth funded by sponsor; law from operator file)
                                ▼
  participant: workspace create via current_birth (op 91, signed factory observation)
```

**Stages.** `participant_enrollment`, then `fresh_onboarding`, then `participant_provisioning`, then `current_birth`. `participant_namespace` is a shared helper for the first and third.

**Not participant joining at all.**
- `session_enrollment` (event-28 app session enrollment, operator-only).
- `session_reenroll` (its upgrade-time successor).
- `enrollment_bootstrap` (the public HTTP relay for pay-to-enrol quotes and claims, ops 112, 121, 181-186). The actual pay-to-enrol client is `join_solana*`, outside this shard.

**Twin compositions of the stages.** `fleet::join`, the shell operator path, `platform-provision.py` and paid onboarding.

**Deployment status (README Honest state).**
- No outside member is enrolled on the public node.
- Observer-signed enrollment 117-120 is operator-only and **not sent by this shard**. It appears only as consent-list entry 117 (`client_consent.rs:1094`).
- Public quote 121 is sent by `enrollment_bootstrap` v1.

### 5.4 Versioned siblings

- **`enrollment_bootstrap` v1 and v2 routes coexist.** v1: metadata, quote (121), enrollment status (112 full-view scan, documented as a legacy scan to replace, `:23-26`). v2: ops 181-186. Both are live.
- **Share issue event-15 and event-22.** `share_issue.rs` and `grain_share_issue.rs` are siblings for two Lean profiles, not versions.
- **Rotation.** `minidregg-retained-rotation-v2` with legacy v1 attempts refused (`key_rotation.rs:483-495`, `:316-322`).

---

## 6. Size and shape

| File | Lines | First `#[cfg(test)]` | Test lines (approx.) | `#[test]` count | Code lines (approx.) |
| --- | ---: | ---: | ---: | ---: | ---: |
| `keys.rs` | 511 | 415 | 97 | 2 | 414 |
| `key_service.rs` | 396 | 266 | 131 | 5 | 265 |
| `key_rotation.rs` | 903 | 839 | 65 | 2 | 838 |
| `key_rotation_custody.rs` | 135 | 77 | 59 | 2 | 76 |
| `key_adoption.rs` | 1,361 | 566 | 796 | 16 | 565 |
| `participant_enrollment.rs` | 2,044 | 1,779 | 266 | 13 | 1,778 |
| `participant_namespace.rs` | 947 | 484 | 464 | 12 | 483 |
| `participant_provisioning.rs` | 544 | 486 | 59 | 2 | 485 |
| `session_enrollment.rs` | 600 | 521 | 80 | 3 | 520 |
| `session_reenroll.rs` | 1,150 | 927 | 224 | 8 | 926 |
| `enrollment_bootstrap.rs` | 1,553 | 875 | 679 | 20 | 874 |
| `fresh_onboarding.rs` | 706 | 353 | 354 | 9 | 352 |
| `fleet.rs` | 1,476 | 1,265 | 212 | 10 | 1,264 |
| `fleet_sign.rs` | 947 | 825 | 123 | 10 | 824 |
| `client_consent.rs` | 1,130 | 567 (and 1059, 1085) | ~447 | 15 | ~683 |
| `member.rs` | 730 | 529 | 202 | 9 | 528 |
| `member_app.rs` | 415 | 315 | 101 | 3 | 314 |
| `seat.rs` | 234 | 214 | 21 | 2 | 213 |
| `share_issue.rs` | 711 | 588 | 124 | 5 | 587 |
| `share_issue_receipt.rs` | 352 | 240 | 113 | 4 | 239 |
| `grain_share_issue.rs` | 738 | 597 | 142 | 5 | 596 |
| `current_birth.rs` | 364 | 219 | 146 | 3 | 218 |
| `can.rs` | 479 | — | 0 | 0 | 479 |
| `law_export.rs` | 189 | 100 | 90 | 3 | 99 |
| `lawsat.rs` | 685 | 620 | 66 | 5 | 619 |
| **Shard Rust total** | **19,300** | | **~5,061** | **168** | **~14,240** |
| `native/host-operations.rs` (generated) | 376 | — | — | — | 376 |

**Method.** Test lines run from the first `#[cfg(test)]` to the end of the file. `client_consent.rs` (non-test code after its test module) and `fleet.rs` (two test modules, `:1265` and `:1312`) were measured by hand.

**Minimal demo version.** The demo is the public node: shell, documents, boards, operator-run onboarding. No pay, no SPK, no rotation, no Hermes. Droppable from this shard:

| Drop | Lines | Why it is not on the demo path |
| --- | ---: | --- |
| `key_adoption.rs` | 1,361 | the node has no key rotation (README Honest state); never passed natively |
| `key_rotation_custody.rs` + `rotate_key` and `key_status` in `key_rotation.rs` (`:331-837`, ~500) | ~640 | same; keep `key_rotation.rs:1-330` (status, digest, cosign, `check_commitment`), which enrollment and workspace use |
| `session_enrollment.rs`, `session_reenroll.rs` | 1,750 | SPK app sessions |
| `share_issue.rs`, `share_issue_receipt.rs`, `grain_share_issue.rs` | 1,801 | SPK app shares |
| `enrollment_bootstrap.rs` | 1,553 | pay-to-enrol not deployed |
| `fleet_sign.rs` | 947 | helm/Bread adapter (north star, not the near demo) |
| `seat.rs` | 234 | Objective seats |
| `member_app.rs` | 415 | "Browser entry is not configured" (`member.rs:522`) |
| `keys.rs`, `key_service.rs` | 907 | provider-key broker client; split tenancy "run on no box", Hermes off on the node |
| **Total removed** | **~9,600** | **about 50% of the shard** |

`fleet.rs` must stay: `credit.rs`, `chat.rs` and `append_proof.rs` import `operation_record`, `recover_operation`, `account_balance`, `digest` and `confirmed`. Its `join` and `feed` (~200 lines) could go. `current_birth.rs` must stay because `workspace.rs:4742-4755` uses it. `can.rs` (479) is optional, a shell nicety.

---

## 7. Deployability on a small public Linux VM

### 7.1 What must exist on the box for this shard's demo path

**Binaries.**
- `mini` (this crate).
- `minidregg-host` (Lean): socket sessions, plus the storeless `codec` loop child spawned by every `mini` process (`client_consent.rs:1015-1017`).
- `minidregg-client-consent`, selected beside the Host or by `MINI_CONSENT_HOST`. Every signing flow refuses without it: `participant_enrollment.rs:1036-1041`, `client_consent.rs:104-111`.
- The SQLite store helper and the Ed25519 verifier used by the Host (not invoked from this shard).

**Directories.**
- Per member: an owner-private workspace (`workspace.json`, `refs/`, `attempts/`, `sources/`, `proposals/`).
- `HOME/keys/` with 0600 seeds.
- `~/.mini/consent-anchors/` (0700), which holds the resident provider sockets `r-<binding>.sock`, logs and PID files (`client_consent.rs:380-391,475-491`).
- The sponsor's `namespaceRoot` (owner-private, `participant_namespace.rs:55-60`) and enrollment attempt directories `HOME/enroll/NAME` (`shell.rs:1700`).

**Long-running processes started implicitly.** `mini consent-resident` daemons (`setsid`, 600 s idle exit). On a shared `mini` uid, one exists per distinct (consent executable inode, settings bytes) binding. Each holds an admitted Store image in memory.

**Kernel features.** Nothing beyond Unix sockets, `flock` and `SO_PEERCRED`. The `F_SETPIPE_SZ` test is Linux-only.

### 7.2 What is operator-configured

- Pinned `config.json` (domain, factoryId, `tariffBase`, `asset`) read by `participant_enrollment.rs:754-777` and `fleet.rs:174-189`.
- The `MINI_CONSENT_*` and `MINI_LOCAL_HOST` env vars, or per-workspace pins (`client_consent.rs:309-329`).
- The broker client config `/etc/mini/keys-client.json` (`keys.rs:10`, if `key` is offered).
- For bootstrap: `--listen` (private IP), `--trusted-proxy`, the metadata JSON (ssh login, bundle URL and SHA), and the public socket with `.mode` = `public-v1` and a matching `.config`.
- The sponsor key and factory capability references (`refs/factory.json`).

### 7.3 What is dangerous to expose

- **`enrollment-bootstrap`.** The only listener. It must sit behind TLS with `--trusted-proxy` set (F-16). It relays ops 181-186, including the public submit op 185 (`/mini/v2/claim/submit`) and the full enrollment view scan (op 112).
- **Resident consent sockets.** Peer-uid-checked (`client_consent.rs:393-404,523`). On today's single shared `mini` account (`docs/review/2026-10-26-deploy/HCLOUD-GAP.md:124,174`) every hosted member is the same uid, so one member's session can connect to another member's resident provider for the same binding. The provider only re-derives plans, so this is a confidentiality question rather than an authority one.
- **Retained secrets** in `attempts/rotate-*/` (F-2) and the sponsor-side custody copy (`OPERATOR.md:44-49`). On a shared uid, any member can read them.

### 7.4 What a stranger on the internet can exercise

Through the bootstrap only:
- metadata;
- quotes (121, 182);
- status (112 scan, 181);
- the claim plan, assemble, submit and lookup relay (183-186).

The rate limits are 6 quote-class and 12 status-class requests per minute per IPv4 address or IPv6 /64, a burst limit, global Host concurrency 2, and responses capped at 16 KiB (`enrollment_bootstrap.rs:17-31,502-511`). A stranger can **observe whether a mini key is enrolled and its lease state** (`/mini/v1/enrollment/<key>`), including the matching `sshBlob` and `subject` fields (`:444-448`). That links an SSH key to a subject publicly, which is by design per HCLOUD-GAP row 126.

### 7.5 What a malicious enrolled member can exercise (via `mini shell` verbs)

- **`can` and `can --all`.** These create unbounded attempts (F-13) and run up to about 8×2 dry runs per resource (`can.rs:133,345-356`), which costs Host work per probe. Unauthenticated or refused calls cost the sender nothing (HCLOUD-GAP row 178).
- **`law check`.** Up to 4 op-150 queries per call (`lawsat.rs:243-258`); `can --any` adds one per field.
- **`fleet` turns.** These pay the tariff, so they self-limit.
- **`enroll`.** Requires a control capability on the factory, so in practice only the sponsor can.
- **`key …`.** If offered, reaches the broker, which re-checks current-key status via op 144.
- **Reading other members' files on the shared uid.** That includes keys, `rotate-*` copies and enrollment custody copies (F-2). This is the largest real risk until split tenancy runs.

---

## 8. Questions for the Lean side

Each is phrased so it can be answered by pointing at a declaration.

1. **Subject and keyId uniqueness on enrollment.** Which declaration in `Kernel/ParticipantKeyEnrollmentReceiver.lean` refuses a client-chosen `subject` or `keyId` that already exists, and does it also refuse a keyId already used by a *revoked* or rotated-away key of another subject? (Rust picks both: `participant_namespace.rs:178-188`.)
2. **Is op 142 replay-first?** Does `NativeHost.receivingSubmitLoaded … SubjectKeyRotation.family` (`Host/Main.lean:7015-7020`) look up the ingress's operation identity before admission, as `FleetTurnReceiver.receiveLoaded` does (`Kernel/FleetTurnReceiver.lean:186-188`)? If yes, `rotate-key` could resubmit the retained ingress instead of wedging (F-1). The same question applies to op 88 (`NativeHost.enrollmentSubmitLoaded`), op 94, op 189 (`NativeHostKeyCommitmentAdoption.submitLoaded`), op 84, op 28 and op 54.
3. **Is op 217 (seat submit) replay-first**, so that `mini seat --action resubmit` (`seat.rs:188-192`) can never be a second operation?
4. **Op 55 on the public route.** The registry marks op 55 operator-only, but `share_issue_receipt.rs` uses it for a recipient. Is a public grain-share recipient lookup intended (and should op 55 list `public`), or should the recipient use a different op?
5. **Event-28 session lifecycle encoding.** Which declaration defines app resource field 0 as generation and field 1 = 4 as "serving", and session fields 0-3 (app, appGeneration, sessionGeneration, status 1 = web active, 5 = api active, status+1 = closed)? Is there a Lean command for closing a session that `session_reenroll.rs:630` should use instead of a raw scalar write?
6. **KeyRecord defaults.** Does the enrollment receiver require `keyEpoch = 1`, `activeFrom = 0`, `activeUntil = 2^64-1` and `algorithm = 1`, or accept any? Does the rotation receiver require `keyEpoch = current + 1`? (`participant_enrollment.rs:885-891`, `key_rotation.rs:653-656`.)
7. **Lookup outcomes.** Can ops 89, 95, 143, 190, 85, 29 or 55 ever return `contention`, or `refused` for an admitted original? (Op 99 cannot: `Kernel/NativeHost.lean:1500-1511`.) The fleet resolver treats `contention` as "nothing moved".
8. **Consent coverage list.** What is the authoritative list of Host plan ops that require local consent reconstruction: `NativeSpecializedConsent.supported` (15 ops) plus whatever `extraExpected` in `Host.ClientConsentSpecializedSession` covers? Specifically, are ops 32, 36, 44, 48, 50, 52, 58, 66, 68, 70, 74, 78, 80, 82, 201, 206 covered there, and should 56 (grain share plan) and 194 (app authenticated plan) be?
9. **Registry for frames 220-233.** Should the consent-provider frame namespace (`Host/ClientConsentCore.lean:369-610`) get its own allocation record, given that frames 228, 229 and 233 are reserved to the resident provider and must never be accepted from clients?
10. **Fleet fee.** Is the fleet-turn fee always exactly `config.tariff`'s base (`FleetTurnReceiver.receiveLoaded … config.tariff`)? Rust refuses to sign otherwise (`fleet.rs:208-210`).
11. **Default account law.** Is `{"type":"all","predicates":[]}` the intended law for a sponsor-funded agent or member account (`fleet.rs:1088`, `deploy/shell/OPERATOR.md:66-70`), or should there be a Lean-emitted default?
12. **Policy revision.** Does the install-policy receiver require `version = previous.version + 1` and `previous = address of the current head`, which `law_export.rs:14-66` computes client-side?
13. **Key-status refusal reason.** Is there a typed refusal reason for "subject has no current signing key" (`Kernel/NativeHost.lean:498`), so that `key_rotation.rs:139` need not match English text?
14. **Lease predicate.** What is the lease predicate behind `DREGG/PAY/ENROLMENT-VIEW/v3` `lease.expiresAt` and `clock.hour`: is a lease live iff `hour < expiresAt`, as `enrollment_bootstrap.rs:465` publishes?
15. **Enrollment assembly layout.** Confirm the op-87 assembly layout `pair(plan, pair(sponsorSig64, possessionSig64 ‖ [nextPublic32 ‖ nextCosign64]))`, i.e. 64 or 160 bytes for the second half (`participant_enrollment.rs:1561-1567`). Which decoder in `NativeHost` accepts it?
16. **Verification strictness.** The Host verifies with `verify_strict` (`credential-signature-verifier/src/main.rs:38`). Is this intended to refuse every small-order or non-canonical signature that ed25519-dalek's non-strict `verify` accepts, so that client pre-checks should be strict too (F-10)?
