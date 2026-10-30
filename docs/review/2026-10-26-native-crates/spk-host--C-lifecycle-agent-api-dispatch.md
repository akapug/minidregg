# spk-host, shard C: lifecycle v3/v4 natives, agent API (v1 and lifetime v3), dispatch

| field | value |
|---|---|
| Shard | spk-host C: "lifecycle v3/v4 natives, agent API v3, dispatch" |
| Crate | `native/spk-host` (package `minidregg-spk-host`, workspace member) |
| Date | 2026-10-26 |
| Reviewer | Opus reader, fan-out review of native crates |
| Method | every file below read in full with line numbers (`cat -n`); cross-references by grep; Lean receivers opened for every operation byte this shard sends (`Host/Main.lean:2075-2270`, `:2340-2470`, `:2550-2700`, `:6140-6262`; `Kernel/ApplicationDispatchReceiver.lean:195-420`; `Kernel/ApplicationDispatchAdmission.lean:100-190`; `Host/ApplicationLifecycleLaunchClaimAuthoring.lean:27-218`); the operator-socket receiver opened in `native/resource-client/src/transport.rs:170-217`; no build or test was run |
| Prior shard read first | `spk-host--A-hostd-http-routes.md` executive summary, 1.3, 2.1, 3 (its D1 custodial signing, D2 issue-index inference, D8 header allowlist copies, two ID allocators) |

## Files covered

"test" is the count from the last top-level `#[cfg(test)]` to end of file. `dispatch_native.rs` also carries a
318-line `#[cfg(feature = "integration-qualification")]` module (`:1311-1631`) with its own 226-line test module
(`:1632-1857`); those are inside "code" below.

| file | lines | test | code |
|---|---:|---:|---:|
| `src/dispatch_native.rs` | 2,386 | 527 | 1,859 |
| `src/dispatch_author.rs` | 450 | 167 | 283 |
| `src/dispatch_inspection.rs` | 594 | 249 | 345 |
| `src/dispatch_delivery.rs` | 439 | 39 | 400 |
| `src/lifecycle_selector.rs` | 190 | 29 | 161 |
| `src/lifecycle_receipt_lookup.rs` | 159 | 0 | 159 |
| `src/lifecycle_v3_native.rs` (BEGIN) | 824 | 274 | 550 |
| `src/lifecycle_v3_claim_native.rs` | 903 | 360 | 543 |
| `src/lifecycle_v3_report_native.rs` | 378 | 68 | 310 |
| `src/lifecycle_v3_completion_native.rs` | 659 | 169 | 490 |
| `src/lifecycle_v3_stop_begin_native.rs` | 247 | 0 | 247 |
| `src/lifecycle_v3_stop_assembly_native.rs` | 259 | 12 | 247 |
| `src/lifecycle_v3_stop_claim_native.rs` | 357 | 43 | 314 |
| `src/lifecycle_v3_stop_native.rs` | 796 | 226 | 570 |
| `src/lifecycle_v3_stop_service.rs` | 1,495 | 130 | 1,365 |
| `src/lifecycle_v4_retry_native.rs` | 923 | 201 | 722 |
| `src/lifecycle_v4_retry_claim_native.rs` | 550 | 27 | 523 |
| `src/lifecycle_v4_retry_completion_native.rs` | 782 | 46 | 736 |
| `src/agent_api_wire.rs` | 443 | 93 | 350 |
| `src/agent_api_custody.rs` | 379 | 37 | 342 |
| `src/agent_api_native.rs` | 1,094 | 240 | 854 |
| `src/agent_api_server.rs` | 1,470 | 379 | 1,091 |
| `src/agent_api_lifetime_v3.rs` | 764 | 220 | 544 |
| `src/agent_api_lifetime_reverse_v3.rs` | 990 | 374 | 616 |
| `src/agent_api_lifetime_custody_v3.rs` | 561 | 170 | 391 |
| `src/agent_api_lifetime_paid_native_v3.rs` | 231 | 27 | 204 |
| `src/agent_api_lifetime_dispatch_native_v3.rs` | 268 | 27 | 241 |
| `src/agent_api_lifetime_server_v3.rs` | 1,057 | 189 | 868 |
| `src/agent_api_lifetime_wire_v3.rs` | 300 | 47 | 253 |
| **total (29 files)** | **19,948** | **4,370** (21.9%) | **15,578** |

Context read, not owned: `protocol/host-operations.json` (every op this shard sends, plus 23, 27, 35, 44-53, 58, 59,
72-81); `Host/Main.lean` arms listed above; `Kernel/ApplicationDispatchReceiver.lean`;
`Kernel/ApplicationDispatchAdmission.lean:100-190`; `Host/ApplicationLifecycleLaunchClaimAuthoring.lean`;
`native/spk-host/src/{native_dispatch.rs,resident_service.rs (selected spans),grain.rs (selected spans),hostd.rs:1340-1395}`;
`native/resource-client/src/transport.rs:170-217`; `native/grain-runtime/src/main.rs` (grep only, for the controller
side); `docs/evidence/2026-10-01-spk-apps/jspk1/rows.tsv`; `docs/evidence/2026-09-27-spk-lifetime-resident-v3/README.md`;
`docs/evidence/2026-09-27-spk-resident-mixed-route/README.md`; `docs/evidence/2026-09-27-spk-agent-api-wire/README.md`;
`docs/evidence/2026-09-27-wind-down-wip/README.md`; `docs/SPK-LIFECYCLE.md`; `scripts/spk-platform/fixture-v4.sh`
(header); `deploy/spk-host/{MINI-CLAIM-DISPATCH-CONTRACT.md,HOT-ROUTE-ENROLLMENT.md,HTTP-CUSTODIAN-CONTRACT.md}`;
README.md "Honest state".

Scratch notes (file-by-file line index) are at
`/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/spk-C/notes.md`.

## Executive summary

1. **The Host wire.** `PrivateOperator::invoke_until` (`dispatch_native.rs:508-579`) sends one LE32-framed envelope
   `[0x02][LE32 cfg_len][cfg bytes][32 raw bytes = SHA-256 of the Host ELF][op][payload]` on an owner-private
   Unix socket served by `resource-client` (`transport.rs:173-217` compares config bytes and the image pin). The Host
   is pinned by path, inode fingerprint and a SHA-256 of an opened descriptor; helper CLIs (`author`, `inspect`,
   `signatures`, `profile`) run that verified descriptor as `/proc/self/fd/N` (`:255-264`, `:449`). Three
   `inspect-stop-claim` calls bypass this and exec the Host by **path**, with no deadline (F4).
2. **op 34 vs 164** is chosen only by whether the route carries a sealed binding (`dispatch_native.rs:1068-1074`).
   The only reply that clears the generation-wide submit marker is the exact frame
   `LE32(len) || 0xA4 || "DREGG/APPLICATION/DISPATCH-NO-RECORD-REFUSAL/v1"` (`:1051-1060`). Lean emits it for every
   admission refusal (`Kernel/ApplicationDispatchReceiver.lean:322-341`), but returns op-34 outcome frames for
   `rejected`, `contention`, `unavailable` and `uncertain` (`Host/Main.lean:2353-2397`). Every one of those leaves
   `native-dispatch-active.json` in the **generation journal**; nothing in the crate removes it except a definite
   success, so the whole grain refuses every member until STOP plus a new generation (F1).
3. **No path resends a Host mutation.** Every submit (22, 26, 34/164, 38, 46, 76) writes a create-new marker first. Lookups
   (23, 27, 39 and the controller's `inspect-v2`/`inspect-v3`/`inspect-settlement-v3`) are the only retries. The one
   deliberate double send is the feature-gated race fixture (`dispatch_native.rs:1523-1546`). One gap: a lost op 22
   or op 26 reply during **STOP** has no lookup path and wedges the app Running (F5).
4. **v3 vs v4.** v3 is the lifecycle lane for INSTALL, START (create or continue) and STOP. v4 "retry" is used only for
   the governed repeat CREATE after a failed first create that failed-START recovery reconciled
   (`resident_service.rs:585-597`, `lifecycle_v4_retry_native.rs:270-316`). Both use the same opcodes; Lean routes by
   codec tag. jspk1 ran v3 only (44/44 rows). v4 has no recorded run in `docs/evidence` (`fixture-v4.sh` is
   authored). v4 also **re-implements Lean's StreamCodec in Rust** for cross-checks (`lifecycle_v4_retry_native.rs:80-119`,
   `v4_retry_claim:57-62`, `v4_retry_completion:217-251,385-391`), which law 13 forbids.
5. **Duplication.** The lifecycle family is one skeleton (selector-framed plan, then inspect, then sign pinned slots, then the
   `signatures` tool, then the LE32 pair, then assemble, then a marker, then submit, then inspect the outcome) written out 9 times
   (BEGIN, CLAIM and COMPLETION, each for v3, STOP and v4), plus 3 copies of the physical report, 7 retained-file
   readers, 5 copies of the "index = acceptedCount - 1" relation and 3 `inspect-stop-claim` execs. About **1.5K of
   its 6.9K code lines** can be removed by one parameterised engine (6.2).
6. **The agent API is two generations side by side.** v1 (`agent_api_{wire,custody,native,server}`, protocol
   `mini-spk-agent-api-v1`, paid ops 48/49/46) and lifetime v3 (`agent_api_lifetime_*`, `mini-spk-agent-api-v3`,
   ops 78/79/76, with the reserve op 80/81 run by the controller). Both are selectable in a resident config
   (`resident_service.rs:132-135,1476-1497`). v3 reuses v1's listener, ACL, frames and reverse transport. The
   `grain` CLI always writes `"agents":[]` (`grain.rs:1116`). **No agent request has ever reached fd 3**
   (evidence `2026-09-27-spk-lifetime-resident-v3/README.md`: "no real op76/fd3 GitWeb request was executed").
7. **Agent trust model.** Peer UID equals the configured `controllerUid` via SO_PEERCRED, plus an exact POSIX ACL checked by
   running `/usr/bin/getfacl` on **every accept** (`agent_api_server.rs:98-137,365-402`). The controller (grain-runtime,
   another UID) holds the purse and payer key. The resident holds the app and grant seeds and signs whatever HTTP the
   controller sends, within the Lean grants (S7). The resident event loop is single-threaded: a controller can stall
   all human routes for 30 s per connection, and one `getfacl` failure ends the generation (F3).
8. **Price.** `reserveAmount`/`maximumCharge` come from operator custody JSON, but the Lean Host config pins the same
   selectors (`Host/Main.lean:2134-2190`, `matchesFixed approved`), so the price is operator policy enforced by Lean.
   Rust only mirrors `max <= reserve`. Settlement charge is chosen by the controller (`grain-runtime/src/main.rs:6470`).
9. **Receipt confirmation.** "Confirmed" always means `type == "confirmed"` in JSON produced by the pinned Lean Host's
   own `inspect outcome`, run locally on retained bytes. That is a Lean decision read through a pinned binary, not an
   unsigned trust. Controller-supplied reserve receipts are accepted from JSON, then echoed back by Lean's committed
   inspection before delivery (`agent_api_server.rs:975-978`).
10. **Rust-owned policy found** (none grants authority): the generation-wide fence scope (S1); the op 34 vs 164 choice
    (S3); five acceptedCount-1 index inferences (S4, mirrors); v4 lane selection from local files (S5); controller-chosen
    agent operation IDs (S10); `volume_resource == app` (S13).
11. **Disk and memory.** Every HTTP request leaves a permanent `dispatch-op-N/` directory holding the request body as hex,
    the plan, the ingress, the committed payload and an inspection of up to 96.8 MB (`dispatch_native.rs:27,868-930,1132-1140`).
    Nothing garbage-collects it, and each request does about 10 fsyncs and spawns 4-5 Host helper processes. On a small VM
    this alone bounds uptime (F2b, F12).
12. **Stale `#![allow(dead_code)]`** sits on 23 of the 29 files with comments like "not enabled yet". Most are wired
    through `resident-run`, `grain install|start|stop|supervise` or `resident-stop`. Real dead items: `number()`
    (`lifecycle_v3_completion_native.rs:31-41`), six unused `FreshStopClaim` accessors (`lifecycle_v3_stop_claim_native.rs:115-135`),
    the v4 test-only encoders, and the whole v1 agent path in practice.
13. **Header allowlist.** Two more copies of Lean's `ordinaryHeaderName` live in this shard (`agent_api_wire.rs:77-99`,
    `agent_api_lifetime_wire_v3.rs:43-65`), making five Rust copies crate-wide. The v1 and v3 `control_free` disagree on TAB.
14. **Demo cut.** Drop all 11 agent files (7,557 lines) and the qualification module (544): **8,101 lines (41%)**.
    Dropping v4 too (2,255) brings it to 10,356 (52%), at the price that a failed first CREATE needs a new app birth.
    Deduplicating what remains saves about 1.3K more.
15. **Questions for Lean (section 8)** concern contention and 255 semantics on op 34, reserve expiry after an agent
    fence, whether op 49/79 re-verify payer signatures, `volume == app` resources, the 600 s operator deadline against
    measured lifecycle steps of 400-3,000 s, and the unused opcodes 44/45/50-53.

---

# 1. What this code is and does

## 1.0 Map of the shard

The 29 files fall into four families. Every one of them talks to Mini only through `dispatch_native::PrivateOperator`:

| family | files | entry points that reach it | Host ops |
|---|---|---|---|
| **Human dispatch** (one HTTP request or WebSocket open per Mini event) | `dispatch_native`, `dispatch_author`, `dispatch_inspection`, `dispatch_delivery` | `spk-host resident-run` → `resident_service::run` → `PrivateHttpEntrance::serve_dynamic_with_aux` closure → `deliver_request` → `ResidentHuman::deliver_once` (`resident_service.rs:1936-1965,2154-2175`); route registration `admit_resident_route` (`resident_service.rs`, shard B); WebSocket renewal `renew_stream` | 36, 37, 34 or 164, 152, 154 |
| **Lifecycle START/INSTALL, v3** | `lifecycle_selector`, `lifecycle_receipt_lookup`, `lifecycle_v3_native`, `lifecycle_v3_claim_native`, `lifecycle_v3_report_native`, `lifecycle_v3_completion_native` | `grain install` → `install_v3` (shard A); `grain start` / resident unit `resident-bootstrap`→`resident-run` → `resident_service` START (shard B) | 66, 67, 22, 23; 68, 69, 26, 27; 70, 71, 38, 39 |
| **Lifecycle STOP, v3** | `lifecycle_v3_stop_begin_native`, `lifecycle_v3_stop_assembly_native`, `lifecycle_v3_stop_claim_native`, `lifecycle_v3_stop_native`, `lifecycle_v3_stop_service` | `spk-host resident-stop CONFIG` (`main.rs:133-134`); `grain stop` (`grain.rs:1189-1209`); `grain supervise` (`grain.rs:1261-1306`) | 66, 67, 22; 68, 69, 26; 70, 71, 38, 39; Host CLI `inspect-stop-claim` |
| **Lifecycle governed repeat CREATE, v4** | `lifecycle_v4_retry_native`, `lifecycle_v4_retry_claim_native`, `lifecycle_v4_retry_completion_native` | `resident_service` START when `start_retry` selects it (`resident_service.rs:587-597,1409-1416,1572-1601`) | same opcodes as v3, v4 codec tags |
| **Agent API v1** ("v2 custody") | `agent_api_wire`, `agent_api_custody`, `agent_api_native`, `agent_api_server` | resident config `agents[]` entry with `protocol` absent (`resident_service.rs:1476-1486,2104-2117`) | 48, 49, 46 (controller runs 58/59) |
| **Agent API lifetime v3** | `agent_api_lifetime_v3`, `_reverse_v3`, `_custody_v3`, `_paid_native_v3`, `_dispatch_native_v3`, `_server_v3`, `_wire_v3` | resident config `agents[]` entry with `protocol: "mini-spk-agent-api-v3"` (`resident_service.rs:1487-1496,2118-2138`) | 78, 79, 76 (controller runs 80/81) |

Module coupling worth knowing before deleting anything: every lifecycle file imports helpers from
`lifecycle_v3_native` (`hex`, `decimal`, `text`, `framed_payload`, `sign_pinned_slots`, `unhex`, `lowercase_hex`).
Every family imports `dispatch_native::{PrivateOperator, private_dir, write_new}`. `dispatch_author::{SignerPin,
private_signing_key}` is the seed reader for all signing in the crate (11 call sites in 7 shard files plus
`export_receipt.rs`, `grain_export.rs`, `completion_custodian.rs`, `grain_profile_upgrade.rs`, `grain_route.rs`,
`resident_route_control.rs` outside it). The lifetime v3 agent set depends on the v1 set for its listener
(`agent_api_server::{AgentApiListener, CallerWatch, read_private_recovery, write_agent_delivery_marker, digest_nat,
unhex32}`), its frames (`agent_api_wire::{read_frame, write_frame}`) and its reverse transport
(`agent_api_native::ReverseCustodyClient`). `hostd.rs:8` imports `agent_api_lifetime_reverse_v3::VerifiedSettlementV3`
for `Journal::finish_dispatch_recovered` (`hostd.rs:1440-1549`). Deleting the agent API therefore also touches hostd.

## 1.1 `dispatch_native.rs` (2,386 lines): THE Host wire for this crate

Module doc (`:1-3`): "One private, no-retry Mini author/submit operation for the resident SPK supervisor." Line 4
carries `#![allow(dead_code)] // Resident authorized supervisor is not enabled yet.` That is stale: the resident is
enabled, and jspk1 ran GET/POST through it (`rows.tsv` s1-get-a, s1-post-a, s3-get-b).

### Constants (`:23-29`)

| name | value | meaning |
|---|---|---|
| `HOST_MAX_FRAME` | 12,102,760 | Host frame bound; counts the opcode byte |
| `ROUTE_BOUND_DISPATCH_OPCODE` | 164 | |
| `NO_RECORD_REFUSAL` | `b"DREGG/APPLICATION/DISPATCH-NO-RECORD-REFUSAL/v1"` | matches `Compiler/PersistedCodecTags.lean:113` |
| `MAX_CONFIG` | 65,536 | Host config file bound |
| `MAX_INSPECTION` | 96,822,080 | read bound for any `inspect` output (8 × frame, `Host/Main.lean:2320-2322` `maxDispatchInspectionJsonBytes`) |
| `MAX_AUTHOR_JSON` | 22 MiB | equals `maxDispatchAuthorJsonBytes` (`Host/Main.lean:2324-2326`) |
| `RESPONSE_DEADLINE` | 600 s | default deadline of every `tool()` and `invoke()` |

### Host image pinning (`:223-332`)

- `ImageFingerprint` (`:224-246`) holds dev, ino, size, mode, uid, mtime (s, ns) and ctime (s, ns).
- `image_path_metadata` (`:268-274`) requires an absolute path to a regular file that is not group- or world-writable.
  It does **not** check the owner.
- `verified_image_hashing` (`:282-332`) keeps a process-wide `static VERIFIED_IMAGES: Mutex<Vec<VerifiedImage>>`
  (`:266`). On a cache hit with an unchanged fingerprint on both the named path and the retained descriptor, it returns
  the retained `Arc<File>` without hashing. Otherwise it opens with `O_NOFOLLOW|O_CLOEXEC`, requires the opened
  fingerprint to equal the named one, SHA-256s the descriptor in 1 MiB chunks, re-checks the fingerprint, compares the
  hex digest with the pin, and caches. The test comment calls the Host image "159 MB" (`:1915`).
- `VerifiedExecutable::path` (`:259-264`) yields `/proc/self/fd/N`. Helpers execute exactly the hashed inode.

### `PrivateOperator` (`:337-343`)

Fields: `host`, `config`, `socket` (`PathBuf`), `host_sha256`, `config_sha256` (lowercase hex). It is built from the
resident config (`resident_service.rs:1371`), the STOP pins (`lifecycle_v3_stop_service.rs:1170-1176`), the grain host
profile (`grain.rs:318-319`), `install_service.rs:176-177` and `grain_export.rs:697`.

`check_pin` (`:371-390`) verifies the Host image, reads the config (64 KiB bound, non-empty) and compares its SHA-256,
then requires the socket's parent to pass `private_dir` (absolute, directory, euid-owned, mode exactly 0700,
`:72-82`) and the socket itself to be a socket, euid-owned, with no group or other bits. `pinned_config()` (`:367-369`)
exposes the verified bytes. `lifecycle_selector::pinned_management` uses them.

### Helper subprocess: `tool` / `tool_until` (`:401-502`)

- Allowed commands and output caps (`:427-433`): `author` (22 MiB), `inspect` (HOST_MAX_FRAME-1 input; output read
  bound `MAX_INSPECTION`), `signatures` (1 MiB), `profile` (1 KiB). Any other command is refused.
- Input file checks (`:434-448`): its parent passes `private_dir`; it is a regular file with nlink 1, euid-owned, mode
  0600, non-empty and at most the cap.
- argv: `/proc/self/fd/N <config-path> <command> [kind] <input> <output>`. For `profile` it is
  `/proc/self/fd/N <config-path> profile`, with stdout redirected into a `create_new` 0600 output file (`:449-464`).
  This matches Lean's `| "profile", [] => IO.println …` (`Host/Main.lean:6387-6390`). stdin and stderr are `/dev/null`
  (`:465`): **Lean's refusal text is discarded** (F6).
- The child is waited on by polling `try_wait` every 10 ms and killed at the deadline (`:466-490`). A non-zero exit
  becomes `"pinned Mini Host helper refused"` (`:491-493`). Output is read back with `read_bounded`, which rejects an
  empty file or one over the bound (`:44-53`, `:494-501`).
- The child re-reads the config **by path** after the parent hashed it (`:450`). See F14.

### Envelope: `invoke` / `invoke_until` (`:504-579`)

1. `check_pin()` returns the hashed config bytes (`:514`).
2. Payload length must be in 1..HOST_MAX_FRAME (`:518-520`).
3. The 64-char hex pin is decoded to 32 raw bytes (`:521-529`).
4. The envelope is `[2] ++ LE32(config.len()) ++ config ++ sha[32] ++ [operation] ++ payload` (`:530-536`).
5. `connect_deadline` (`:88-194`) is a non-blocking `AF_UNIX` connect that sleeps 10 ms on `EAGAIN` (full backlog)
   and polls `POLLOUT` on `EINPROGRESS`. It never sends a byte before the connection is established.
6. Write `LE32(envelope.len()) ++ envelope` with a separate 10 s write deadline (`:538-561`). A timeout or short write is
   `"uncertain Mini Host request write"`.
7. Read a 4-byte LE length. It must be in 2..=HOST_MAX_FRAME. Then read the body with the overall deadline
   (`:562-570`).
8. Opcode acceptance (`:571-577`): `reply[4] == operation`, or `reply[4] == 255` (refusal), or one of two defined
   crossings: op 164 answered with opcode 34 (Lean's route-bound permit, `Host/Main.lean:2363-2365` writes 34 for both),
   or op 34 answered with opcode 164 whose payload is exactly `NO_RECORD_REFUSAL`. Anything else is
   `"Mini operator reply opcode mismatch"`.
9. Returns the **whole frame including the 4-byte length prefix**. Every caller indexes `reply[4]` and `reply[5..]`.

The receiving side is `native/resource-client/src/transport.rs:173-217`. `split_envelope` accepts versions 1 and 2,
requires `config_length == config.len()` and identical bytes, and in version 2 compares the 32-byte image pin with the
socket's own `host_sha256` (`request_from_envelope`, `:205-217`). The socket process then frames `[op ++ payload]`
into the Lean Host's stdio loop `serveSession`/`serveFrame` (`Host/Main.lean:2616-2700`).

### Continuity probe and route admission (`:582-722`, `:1159-1309`)

- `ContinuityAttemptDir` (`:585-600`) is a fresh `continuity-<32 random bytes hex>` 0700 directory under the
  resident's journal, `remove_dir_all` on drop.
- `store_tag` (`:608-619`) and `continuity_namespace` (`:622-635`) run `profile` and read `storeTag` (filtered by
  `broker::store_key`) or `domain`/`semantics`.
- `probe_continuity` (`:639-721`, op 152):
  1. Author `application-stream-continuity-challenge` from the binding JSON.
  2. Run `author_signed_ingress` with method `WEBSOCKET`, path `?<challenge hex>`, the single header
     `sec-websocket-protocol: dregg.authority.continuity.v1`, operation ID `"0"`. This calls op 36 and op 37 but never
     op 34.
  3. Author `application-stream-continuity-request` and invoke op 152. Require opcode 152 and the prefix
     `DREGG/APPLICATION/STREAM-CONTINUITY-ATTESTATION/v1`, then inspect the attestation.
  Lean rejects such a probe if submitted to op 34 (`continuity_probe_never_submits`,
  `Kernel/ApplicationDispatchReceiver.lean:406-421`).
- `renew_stream` (`:733-769`) is async. It sleeps until `lease.renewal_delay()`, begins a renewal, runs the probe in
  `spawn_blocking` and calls `stream_continuity::verify_reply`. Any failure calls `lease.revoke()` and prints one line
  to stderr.
- `admit_resident_route` (`:1180-1308`, op 154) has a 60 s deadline. It reads `profile`, builds the
  `RouteAdmissionExpectation` (zero fingerprint placeholder), authors `application-route-admission-challenge`, and runs
  `author_signed_ingress` as `WEBSOCKET` with header `dregg.authority.route-admission.v1`. The route is `Browser` for
  `session_kind == "web"`, else `Api { signed_path: "/" }` (`:1248-1252`). Then it authors the request, invokes 154,
  requires the prefix `DREGG/APPLICATION/ROUTE-ADMISSION-ATTESTATION/v1`, inspects, and hands the result to
  `route_admission::verify_reply` (shard A).

### Authoring one dispatch: `author_signed_ingress` (`:868-930`)

1. `attempt_dir` is created with `DirBuilder::create` (fails if it exists) under a `private_dir` parent (`:876-880`).
2. `custody.request_json(operation_id, http)` → `request.json` → `author application-dispatch-request` → `request.bin`.
3. `invoke_until(36, request_bytes)`. Anything but opcode 36 is `"Mini dispatch authoring refused"` (`:891-894`). The
   refusal frame is **not written** to the attempt directory and its reason is lost.
4. `plan.bin` → `inspect application-dispatch-plan` → `plan.json`.
5. `custody.sign_plan(plan, plan_json, request_bytes, request)` (`dispatch_author.rs:176-254`) → `signatures.json` →
   `signatures` tool → `signatures.bin`.
6. Pair `LE32(plan.len()) ++ plan ++ signatures.bin` → `invoke_until(37, pair)`. Anything but opcode 37 is
   `"Mini dispatch assembly refused"`. `ingress.bin` is retained.

Lean side: op 36 is `fnDispatch` (`Host/Main.lean:2106`). Op 37 splits the pair, decodes
`ApplicationDispatchAuthoring.planCodec`, decodes signatures and returns `(37, ingress)` (`Host/Main.lean:2107-2113`).
The two sides agree on the pair layout (`splitPair` is LE32-prefixed, `lifecycle_selector.rs:62` documents the same
`splitPair`).

### The one submit: `submit_once` (`:1020-1066`) and `author_and_submit` (`:1076-1157`)

`author_and_submit`:
1. `validate_route_binding` (`:932-952`) requires a supplied `ContinuityBinding` to match custody (app, session,
   subject, ticket) and the pinned namespace, **before** any directory or Host call. Tested at `:2048-2096`.
2. (Feature `integration-qualification` only: `qualification::claim`, `:1357-1402`.)
3. `author_signed_ingress` (above), with one deadline of now + 600 s.
4. `opcode = dispatch_opcode(route_binding)`, i.e. 164 if a binding is present, else 34 (`:1068-1074`). For 164 the
   submission is the Host-authored `application-route-bound-dispatch` envelope over
   `route_bound_dispatch_json(binding, ingress)` (`:976-982`). The `sessionFingerprint` there is a decimal rendering of
   the 32 bytes read **little-endian** (`digest_decimal`, `:955-974`). That is the same byte-order question shard A
   raised for `stream_continuity.rs:22-39` (question 8.4).
5. `submit_once`:
   - writes `submit-requested.json` (protocol `mini-spk-dispatch-submit-requested-v1`, operationId, ingressSha256,
     submitOpcode, submissionSha256) into the attempt directory with `create_new`;
   - creates `<attempt_parent>/native-dispatch-active.json` with the same bytes, `create_new` + `O_NOFOLLOW` + 0600,
     and fsyncs the file and the parent (`:1034-1048`);
   - invokes once. A transport error returns through `?` with both markers retained;
   - writes `op{34|164}-frame.bin`;
   - if and only if the frame is byte-identical to `LE32(len(tag)+1) ++ [164] ++ tag`, retires the global marker
     (`retire_active_marker` re-reads it and requires identical bytes, `:984-996`) and returns
     `"Mini dispatch refused before any Store record"` (`:1051-1060`);
   - otherwise returns the frame with the global marker still present.
6. `committed_payload` (`:1007-1014`) → `native_dispatch::parse_op34_response` (shard A, `native_dispatch.rs:30-51`).
   It requires opcode 34 and either the `DISPATCH-COMMITTED-PERMIT/v1` tag (permit) or the `NATIVE-HOST/OUTCOME/v6` tag.
   An outcome (historical receipt, refusal, contention, unavailable, uncertain) is `"Mini op34 did not commit a
   delivery permit"`, and **the global marker stays**.
7. `committed-payload.bin` → `inspect application-dispatch-committed` → `inspection.json` →
   `dispatch_inspection::match_inspection`. The operation ID must equal the allocated one (`:1148-1150`).
8. Returns `CommittedDispatch { payload, matched, active_marker, active_bytes }` (`:771-776`).

`CommittedDispatch::record_delivery_requested` (`:829-861`) re-reads the marker. It builds `hostd::DispatchIdentity`
from `matched` plus the journal's current invocation ID, with `permit_sha256` = SHA-256 of the committed payload, and
calls `Journal::request_dispatch` (`hostd.rs:1347-1390`). `RecordedDispatch::finish` (`:804-807`) and
`release_uncertain` (`:815-822`) call the matching journal method, then retire the global marker.

**Answer to item (1) of the prompt.** A lost reply leaves two things. The per-attempt
`dispatch-op-N/submit-requested.json` (never removed) prevents reusing that attempt directory, and N is never
reallocated (`hostd.rs:1067-1157`). The generation-wide `native-dispatch-active.json` prevents every later request from
authoring (`dispatch_delivery.rs:113-124`). After `request_dispatch`, the hostd tombstone (`dispatch-op-<key>.json`) is
DeliveryRequested and becomes Uncertain on any non-definite outcome. **No path resends**: op 34/164 is invoked exactly
once per attempt (`:1049`). There is no op 35 lookup caller anywhere in the crate (`grep invoke(35` finds nothing).
The only automated recovery is the definite NO_RECORD frame. Everything else waits for an operator. In practice,
because no command clears the generation marker, recovery means STOP and a new generation (F1).

### `qualification` module (`:1311-1631`, feature `integration-qualification` only)

This is a race fixture. A trigger file `dispatch-race-trigger.json` in the attempt parent (0600, nlink 1, euid,
at most 64 KiB, opened `O_NONBLOCK|O_NOFOLLOW` so a FIFO cannot block, `:1334-1356`) must match the exact request
(`:1378-1399`). It is claimed by writing `dispatch-race-claimed.json`. `run` (`:1492-1605`) writes
`dispatch-race-ready.json`, waits up to 60 s for `race-go.json` carrying the nonce and the submission hash, then **sends
the same submission twice concurrently** behind a `Barrier` (`:1522-1546`). `select_winner` (`:1436-1491`) requires
exactly one committed permit and one historical outcome whose `type == "confirmed"` and whose `confirmation` is
installed, replayed or recoveredAfterUncertainResponse, with transactionId, eventId, acceptedCount and worldRoot equal to
the permit's receipt. The evidence files report `physicalDeliveries` and `"recovery":"terminal-fixture-checked-stop-new-generation"`.
This is the only double send in the shard. Shard A found that the candidate builds without features
(`deploy/candidate/build.sh`, `package.py`). Per README, the jspk1 `failstart` rows that would use it are authored and
have not run.

### Tests (`:1860-2386`)

| test | what it really checks |
|---|---|
| `host_image_hashed_once_per_inode_and_rehashed_on_any_change` `:1918-1954` | cache hit and miss, rename to a new inode, in-place append refused, symlink and 0777 refused, an earlier `VerifiedExecutable` still runs |
| `bound_dispatch_private_transport_accepts_only_defined_cross_opcode_replies` `:1956-2025` | the five opcode-crossing cases against a fake socket server |
| `bound_dispatch_authoring_preserves_exact_binding_and_ingress` `:2027-2046` | JSON shape; little-endian decimal round trip with `stream_continuity::digest` |
| `bound_dispatch_wrong_local_custody_or_namespace_never_enters_native_pipeline` `:2047-2096` | no attempt directory and no marker on a binding mismatch |
| `bound_dispatch_definite_revoked_a_refusal_releases_b_without_replaying_a` `:2097-2145` | the NO_RECORD frame releases the global marker; the same attempt cannot rerun; B proceeds |
| `bound_dispatch_historical_confirmed_receipt_retains_marker_and_refuses_delivery` `:2146-2202` | an outcome frame keeps the marker and blocks B |
| `bound_dispatch_uncertain_or_malformed_refusal_preserves_global_marker` `:2204-2276` | wrong tag, trailing byte, truncated, flipped, generic outcome, EOF, marker drift: all keep the marker |
| `full_unix_backlog_obeys_connect_deadline_and_recovers` `:2278-2305` | connect deadline with listen(1) |
| `private_v2_operator_frame_pins_host_config_and_socket` `:2307-2369` | envelope bytes; oversize author input refused; config drift refused |
| `native_submit_marker_is_create_new_and_blocks_a_second_attempt` `:2371-2385` | **tests `write_new`, not `submit_once`**: create_new semantics of a helper |

Linux-only behaviour: the tests copy `/usr/bin/true` as a fake Host (`:1922`). They do not exercise any Lean Host.

## 1.2 `dispatch_author.rs` (450 lines)

Doc (`:1-4`): "compares every source slot to an operator-pinned key before signing exact header bytes. Neither an HTTP
request nor a Host plan chooses a new signer." The `allow(dead_code)` comment at `:5` ("Joined operator
broker/supervisor route is in progress") is stale.

- `SignerPin` (`:65-72`) holds role, index, key_id, key_epoch, public_key_hex and seed_path. It is the signer type
  used crate-wide.
- `FixedAuthoring` (`:76-91`) is the human dispatch custody JSON (`protocol == "mini-spk-human-dispatch-custody-v1"`):
  app, subject, session, `session_kind` (web or api), issue_index, ticket_resource, package_manifest,
  snapshot_manifest, three observe capabilities, and signers (1..64, unique role/index). `validate` (`:94-132`).
  `issue_index` is **the D2 value from shard A** (`grain_route.rs:184` writes acceptedCount-1).
- `request_json` (`:136-170`) requires `session_kind` to match the route kind and a canonical decimal operation ID,
  computes `(path, query) = app_route_path(http)`, and emits
  `{issueIndex, ticketResource, packageManifest, snapshotManifest, sessionObserveCapability, manifestObserveCapability,
  enrollmentObserveCapability, http:{operationId, methodHex, pathHex, queryHex, headers:[{nameHex, valueHex,
  generated:false}], bodyHex}}`.
- `sign_plan` (`:176-254`) bounds the plan below 12,102,760 and the inspection at 96,822,080. It requires the
  inspection to have `type == application-dispatch-author-plan-v1`, `canonicalPlan == hex(plan)`, a nested request of
  type `application-dispatch-author-request-v1` whose `canonicalRequest == hex(request_bytes)` and whose remaining
  fields equal the JSON Rust sent (`Value::Object(comparable_request) != *request`, `:202`), and app, session and subject
  equal custody. Slots must be exactly as many as pins and in order, each with role, index, decoded, keyId, keyEpoch,
  algorithm "1" and canonical == header. Headers are 1..64 KiB. Each seed is opened and its public key compared before
  signing.
- `private_signing_key` (`:257-282`): parent directory euid-owned with no group or other bits; file regular, nlink 1,
  euid-owned, 0600, dev/ino equal between path and descriptor, exactly 32 bytes. The seed array is a stack local and is
  not zeroized; `SigningKey` itself zeroizes (ed25519-dalek 2.2.0 default feature `zeroize`).
- Tests (`:284-449`): exact signed API path, drift refusals, 0644 seed refused.

## 1.3 `dispatch_inspection.rs` (594 lines)

Doc (`:1-3`): "Compare Mini's read-only op34 inspection to the exact private Host payload and the authenticated,
canonical HTTP request. This is not admission." The `allow(dead_code)` at `:4` is stale.

- `Route` (`:100-108`) is `Browser` or `Api { signed_path }`. `STREAMED_OPEN_METHOD = "WEBSOCKET"` (`:112`) mirrors
  `Kernel/ApplicationDispatchAdmission.streamedOpenMethod`.
- `HttpProjection` (`:114-120`), `FixedCustody` (`:124-129`), `MatchedInspection` (`:134-152`). The last is what hostd
  and `rpc_adapter` consume: app (u64), app_generation (u64), session_resource and session_generation (strings),
  subject, operation_id, physical_request_digest, dispatch_transaction, dispatch_event, session_fingerprint ([u8;32],
  little-endian), principal ([u8;32]), before and after world roots, accepted_count, effective_bits (at most 128),
  app_path_and_query, method.
- `app_route_path` (`:157-183`) refuses a leading `/`, any `#`, more than one `?`, or more than 8,192 bytes. For `Api` it
  delegates to `minidregg_signed_api_path::route(signed_path, path)`. For `Browser` it passes the path through
  **unchanged**, so `../admin` is accepted. The traversal test at `:568-580` only exercises `Api`. Lean's
  `requestSafeFor` does not refuse dot segments either (`Kernel/ApplicationDispatchAdmission.lean:154-180`); see 8.10.
- `match_inspection` (`:190-344`): exact echo (`type == application-dispatch-committed-inspection-v2`, frameByteCount,
  frameHex); app, subject, session and ticket equal custody; `session.origin.type == "human"` (`:231-236`, agent-origin
  refused with "agent-origin v1 dispatch lacks checked parent custody"); session kind matches the route; the `streamed`
  mark equals `method == WEBSOCKET` (`:250-252`); method, path, query and body hex equal the HTTP; ordered headers equal
  with `generated == false`; principal hex32; bits are booleans (at most 128); app generation is canonical and non-zero;
  session generation canonical; session.appResource and appGeneration agree; receipt transaction and event equal
  dispatchTransaction and dispatchEvent.
- `digest_nat_bytes` (`:81-98`) is the decimal-to-little-endian-32-byte conversion, refusing more than 256 bits. A twin
  is `agent_api_server::digest_nat` (`agent_api_server.rs:79-96`), which does **not** check canonical form.
- Tests (`:346-593`) are focused and real.

## 1.4 `dispatch_delivery.rs` (439 lines): `ResidentHuman::deliver_once`

Doc (`:1-3`): runs only in the process that owns fd 3. The `allow(dead_code)` at `:4` ("Lifecycle-v2/SPK binding and
resident service not enabled yet") is stale.

`ResidentHuman` (`:34-49`) holds operator, custody, journal, `&mut RpcDriver`, display name, preferred handle, open
sockets plus class `Limits`, stream lease lifetime, continuity namespace and an optional `route_binding`.

State machine of `deliver_once` (`:71-391`):

| step | lines | failure leaves |
|---|---|---|
| `export_receipt::requested` (capture intent, shard B) | 79 | nothing |
| policy fixed kind, app, subject, session and ticket must equal custody | 80-91 | nothing |
| `dispatch_web_input::preflight_web_input` (shard A) | 97-103 | nothing ("fences nobody") |
| journal `verify_running_instance` | 106-109 | nothing |
| **generation fence**: if `<journal>/native-dispatch-active.json` or `<journal>/dispatch-active.json` exists, return `Interrupted` "SPK dispatch uncertain; exact recovery required" | 113-124 | nothing new; every member is refused |
| WebSocket only: `sockets.reserve(&limits)`, else `cap_refusal(name)` HTTP response | 128-142 | nothing |
| `journal.allocate_dispatch_operation()` (fsynced counter, hostd) | 145 | a consumed number |
| `StreamLease::begin` for an upgrade | 148-151 | |
| `author_and_submit(...)` with `attempt_dir = <journal>/dispatch-op-N` | 152-160 | on error: `rpc.invalidate_custody(app, subject, session, ticket, binding)` (`:161-171`); if the global marker exists the error becomes `Interrupted` "SPK native outcome uncertain; exact recovery required" (`:172-181`) |
| `record_delivery_requested` → hostd DeliveryRequested | 186 | marker + tombstone |
| `rpc.prepare_cancellable(identity)` | 188-194 | on error: `finish(false)` → Uncertain |
| build `current_binding` from matched; `route_binding_matches` (`:394-399`, `None` matches all) | 195-217 | |
| project physical input; re-verify Running; mismatch → `abort_no_enqueue` fence → `release_uncertain` | 220-268 | Uncertain tombstone, slot released, global marker retired |
| exchange: `prequeue.dispatch(binding, request, 8 MiB, 30 s, cancel=false)` | 270-300 | typed fence → `release_uncertain`; no fence → `finish(false)` (marker kept) |
| serialize for origin (+ export capture) → `finish(true)` | 301-325 | serialization failure after delivery → `release_uncertain` |
| upgrade: bind continuity on the lease, spawn `renew_stream`, `prequeue.open_web_socket(...)` → `finish(true)` | 327-384 | as above |

Constants: `MAX_APP_RESPONSE` 8 MiB, `APP_CALL_TIME` 30 s (`:23-24`). The test module (`:401-439`) covers
`route_binding_matches` only.

**Item (4): is the generation-wide fence Lean's requirement?** No. Lean's exactly-once unit is the signed call:
`receiveVerifiedWith` looks up the exact ingress before anything else and returns its original receipt
(`Kernel/ApplicationDispatchReceiver.lean:327-331`). The durable transaction ID can be used only once (`:276-278`).
Nothing in the Lean receiver needs the other participants of a grain to stop. The global marker exists because the
crate keeps one shared physical slot per generation (`hostd` `dispatch-active.json`) and chose to report one member's
uncertainty to all members "without creating extra evidence" (comment `:110-112`). The agent paths show the scope is a
choice: they keep their own `native-agent-dispatch-active.json` per agent attempt directory and do not consult the human
marker (`agent_api_native.rs:801`, `agent_api_server.rs:765-787`). So an uncertain human op 34 fences every human but
no agent, and an uncertain agent op 46 fences only that agent route. The documented intent is
`deploy/spk-host/HOT-ROUTE-ENROLLMENT.md:100-111`, which describes releasing "the matching generation-wide submit
marker" only on the qualified refusal.

## 1.5 Shared lifecycle plumbing: `lifecycle_selector.rs` (190) and `lifecycle_receipt_lookup.rs` (159)

**`lifecycle_selector.rs`.** The doc (`:1-9`) says the Host pins one lifecycle management identity and no application;
every lifecycle authoring call is framed as `(selector JSON, request)`. It lists "ops 44/50/52/66/68/70", but this
crate sends only 66, 68 and 70. Opcodes 44, 45 and 50-53 are still `active` in `protocol/host-operations.json` and no
Rust caller sends them (question 8.11).

- `LifecycleSelector` (`:31-39`) holds app, package_manifest, snapshot_manifest, app_capability,
  app_observe_capability, package_capability and package_observe_capability, all canonical non-zero decimals of at
  most 78 digits. app, package and snapshot must be pairwise distinct (`:42-60`). `deny_unknown_fields`.
- `framed` (`:63-76`): `LE32(len) ++ selector JSON ++ request`, selector at most 4 KiB. It matches the Host's
  `splitPair` + `LifecycleSelector.parse` (`Host/Main.lean:6154-6155`).
- `pinned_management` (`:88-113`) reads the pinned config JSON and refuses legacy keys `completionManagement`,
  `residentBeginManagement` and `residentClaimManagement`. It returns `lifecycleManagement.managementSubject` and
  `.managementKeyId` (string or u64), which matches the Host's `lifecycleManagement : Option LifecycleManagementSettings`
  (`Host/Main.lean:6143-6152`).
- `validate_custody` (`:118-147`): the selector is valid, the management subject equals the pin, **every** signer's
  `key_id` equals the pinned key ID, and every seed parent passes `sandbox::open_protected_directory(parent, app_uid,
  false)` (shard B; the app UID cannot rewrite the chain).

**`lifecycle_receipt_lookup.rs`.** Doc (`:1-10`): one receipt-only lookup for op 23, 27 and 39 for both lanes; the
Host picks the lane by ingress tag.

- `OUTCOME_TAG = "DREGG/NATIVE-HOST/OUTCOME/v6"` (`:21`).
- `retained` (`:30-56`) is the canonical "retained private file" reader: regular, not a symlink, nlink 1, euid, 0600,
  non-empty, at most max, opened `O_NOFOLLOW`, same dev/ino, same length.
- `outcome_receipt` (`:61-78`) requires `type == "confirmed"` and the given confirmation, plus four canonical decimals.
- `retained_submitted_ingress` (`:93-119`) requires the parent active marker to be **byte-identical** to the attempt's
  prepare marker (the op66/op68/op70 `*-requested.json`), the submit marker's protocol, and its `ingressSha256` to
  equal the retained ingress.
- `lookup_retained` (`:124-159`) creates a fresh `op{N}-lookup-<16 random bytes>` directory (so it can repeat after
  another lost reply), invokes the lookup op with **the same ingress bytes**, checks frame and tag, inspects `outcome`,
  and requires `confirmation == "replayed"`. Callers: `lifecycle_v3_native.rs:548` (23), `lifecycle_v3_claim_native.rs:424`
  (27), `lifecycle_v4_retry_native.rs:720` (23), `lifecycle_v4_retry_claim_native.rs:521` (27),
  `lifecycle_v4_retry_completion_native.rs:712` (39). It has no tests.

## 1.6 START/INSTALL v3

Each step of a launch is three Mini events (BEGIN event23, CLAIM event24, COMPLETION event25;
`docs/SPK-LIFECYCLE.md:22-28`), each authored as plan + assemble + submit. The files below implement one step each.
The orchestration (which step runs when, with which attempt directory) lives in `install_v3.rs` (shard A) and
`resident_service.rs` (shard B).

### `lifecycle_v3_native.rs` (824): BEGIN (op 66 → 67 → 22, lookup 23)

The `allow(dead_code)` at `:4` ("The v3 lifecycle caller is still source-gated") is stale: `install_v3.rs` and
`resident_service.rs` call `submit_once`.

- Tags (`:20-21`): `PLAN_TAG = DREGG/APPLICATION/LAUNCH-BEGIN-OPERATOR-PLAN/v1`,
  `BEGIN_TAG = DREGG/APPLICATION/LIFECYCLE-BEGIN-INGRESS/v3`.
- Shared helpers exported to the whole family: `hex`, `decimal` (128-digit cap), `lowercase_hex`, `unhex`, `text`
  (`:27-71`), and `framed_payload` (`:102-116`), which requires `LE32 length + 4 == reply.len()`, the exact opcode, the
  tag prefix and a non-empty body after the tag.
- `checked_physical_identity` (`:73-100`): app non-zero; `processGeneration == beforeGeneration + 1`;
  `processIdentityHex` decodes to a unit that `broker::parse_resident_unit` accepts for the same app and generation;
  `imageIdentityHex == hex(descriptor.package.image_identity)`.
- `sign_pinned_slots` (`:133-177`) is the family's signer. Slots form a **set** that must match distinct pins by
  role/index ("a permitted set, not a sequence", test `:634-651`). Each slot needs decoded true, keyId and keyEpoch
  equal, algorithm "1", canonical decimal `validUntil` and `nullifier`, and lowercase-hex `domainHex`/`messageHex`. The
  signed bytes are `headerHex`, 1..64 KiB.
- `LaunchBeginAction` (`:180-188`): `Install`, `Create(usize)` (index into the signed descriptor's create digests),
  `Continue { created_index }` (resume a retained successful create; author kind
  `application-lifecycle-launch-continue-request`).
- `FixedLaunchBeginSigners` (`:272-277`): protocol `mini-spk-resident-begin-management-v1`, selector,
  management_subject, signers. `checked_plan_slots` (`:293-378`) compares more than 20 plan fields with the request and
  the signed launch descriptor, including `selectedCommandDigest` and `priorCreate` (a receipt/custody witness for
  Continue).
- `submit_once` (`:413-529`), artifacts under the INSTALL journal or resident journal:

| order | artifact | lines |
|---|---|---|
| 1 | `attempt_dir` created (fails if present) | 427 |
| 2 | `client_operation_id = allocate_operation_id(ledger)` (the begin operation ledger, `operation_ledger.rs` shard A) | 428 |
| 3 | `request.json` → `author <kind>` → `request.bin` | 429-436 |
| 4 | `op66-requested.json` {protocol `mini-spk-launch-begin-prepare-requested-v1`, clientOperationId, requestSha256} | 437-442 |
| 5 | **parent** `lifecycle-begin-v3-active.json` (same bytes, `create_new`) | 447 (`hold_begin_attempt`, `:121-124`) |
| 6 | invoke 66 with `selector.framed(request)` → `op66-frame.bin` → `plan.bin` → inspect `application-lifecycle-launch-begin-plan` → `plan.json` | 448-458 |
| 7 | signatures → `signatures.json` → `signatures.bin` | 459-471 |
| 8 | `op67-requested.bin` (the pair) → invoke 67 → `op67-frame.bin` → `begin-v3.bin` | 472-480 |
| 9 | `op22-requested.json` {protocol `mini-spk-launch-begin-submit-requested-v1`, clientOperationId, authorizationOperationId, volumeIdHex, ingressSha256} | 481-492 |
| 10 | invoke 22 → `op22-frame.bin` → `op22-outcome.bin` → inspect `outcome` → `op22-outcome.json`; require `confirmed`/`installed` | 493-506 |

  The result is `AcceptedLaunchBegin` (`:395-409`): ingress, action, prior_create, client and authorization
  operation IDs, volume ID, snapshot manifest, process generation and identity, and the receipt.
- `recover_begin_receipt_only` (`:533-549`): op 23 via `lookup_retained`. "The receipt is historical evidence and can
  never arm a CLAIM or a launch."
- Tests (`:551-824`) cover descriptor-bound request JSON, the slot set, tag aliasing, physical identity, plan pins, the
  Continue witness, and a test that only exercises `hold_begin_attempt` (create_new).

### `lifecycle_v3_claim_native.rs` (903): CLAIM (op 68 → 69 → 26, lookup 27)

The `allow(dead_code)` at `:4` is stale.

- Tags (`:23-25`): `LAUNCH-CLAIM-OPERATOR-PLAN/v1`, `LIFECYCLE-CLAIM-INGRESS/v3`, `LIFECYCLE-CLAIM-COMMITTED/v3`.
- `previous_index` (`:31-49`): the decimal string of `count - 1`, used to make `original_index` from the BEGIN
  receipt's `acceptedCount`. **This is the D2 inference pattern of shard A, again.** Lean selects the BEGIN by that
  index (`Host/ApplicationLifecycleLaunchClaimAuthoring.lean:81`) and checks
  `plan.originalBeginReceipt.acceptedCount == source.originalIndex + 1` (`:218`). Rust also compares the plan's
  `originalBeginHex` with its own retained ingress (`:107`). Mirror, fail closed.
- `later_decimal` (`:51-56`) compares decimals by length then bytes. It is exported to completion, report and the v4 files.
- `FixedLaunchClaimSigners` (`:60-65`), protocol `mini-spk-resident-claim-management-v1`. `checked_plan_slots`
  (`:90-181`) compares more than 25 fields against the retained BEGIN, plus the `binding` for Install (null),
  Create(index) and Continue (prior create witness).
- `assemble_once` (`:208-294`): `query_nonce = allocate_operation_id(nonce_ledger)` (the claim nonce ledger) (`:224`);
  `op68-requested.json` plus **parent** `lifecycle-claim-v3-active.json` (`:240-241`); op 68 → inspect plan → sign →
  op 69 → `claim-v3.bin`. It does not submit.
- `submit_fresh_once` (`:429-474`): `checked_assembled` (`:520-542`) re-reads the parent marker and `claim-v3.bin` and
  re-hashes BEGIN and descriptor; `op26-requested.json`; invoke 26; require `COMMITTED_TAG`; inspect
  `application-lifecycle-claim-committed-v3`; `checked_committed` (`:296-402`); `verified_physical_begin` (`:476-518`)
  builds `hostd::VerifiedBegin`, the type that arms the physical launch (shard A 1.3).
- `recover_claim_receipt_only` (`:409-425`): op 27.
- Lean op 26 (`Host/Main.lean:2550-2600`) writes the committed bytes with opcode 26 only for a fresh installed CAS
  winner; otherwise it writes an outcome `confirmed replayed`. The two sides agree.

### `lifecycle_v3_report_native.rs` (378): the custodian-signed physical report

The `allow(dead_code)` at `:3` is stale.

- `PhysicalMode` (`:27-33`): `Materialized` (INSTALL) or `Running { journal, volume }` (START).
- `checked_observation` (`:57-133`) joins the claim's `VerifiedBegin` to the launch. For Running it requires the
  journal to be Running with the same app, generation, operation, unit, transaction, event and image, the volume ID to
  equal BEGIN's, `volume.recheck_handoff()`, a non-empty invocation and cgroup, and pid > 0. It emits
  `{begin, committedClaim, nonce (random u128 decimal, :47-55), unit hex, materializedImage, outcome
  materialized|running, invocationId hex, controlGroup hex, pid, stopAudit:null, volumeWitness}`.
- `prepare_once` (`:189-309`): `completion_custodian::preflight_custodian` (shard B); author
  `application-lifecycle-launch-physical-report`; inspect and `checked_report` (`:135-185`); author the signing frame;
  for Running, **re-observe** and require the seven physical fields unchanged (`:246-263`); sign the frame with the
  custodian seed (`:264`); author the signed report; inspect it and compare type, frame and signature; re-check the
  nested report; check canonical hex.

### `lifecycle_v3_completion_native.rs` (659): COMPLETION (op 70 → 71 → 38, lookup 39)

The `allow(dead_code)` at `:4` is stale.

- Tags (`:23-25`): `LIFECYCLE-LAUNCH-COMPLETION-OPERATOR-PLAN/v1`, `LIFECYCLE-COMPLETION-INGRESS/v2`, outcome v6.
- `number` (`:31-41`) is **unused** (dead).
- `FixedLaunchCompletionSigners` (`:45-50`), protocol `mini-spk-completion-management-v1`.
- `checked_receipt` (`:142-169`) requires the confirmation and `acceptedCount` later than the claim's.
- `assemble_once` (`:173-289`): author the completion request; **inspect the request too** (`:207-227`); op70 marker
  plus parent `lifecycle-completion-v2-active.json` (`:235-236`); op 70 → plan → sign → op 71 → `completion-v2.bin`.
- `retained_file` (`:316-342`) is a byte-for-byte twin of `lifecycle_receipt_lookup::retained`.
- `load_retained` (`:347-382`) reopens an op71 result after restart.
- `submit_fresh_once` (`:386-443`): the BEGIN action decides the physical phase (Install needs no journal;
  Create/Continue need a Running journal equal to the claim). `op38-requested.json` is `create_new`, so a second call
  fails before sending. Invoke 38; `checked_receipt(installed)`; re-verify Running.
- `recover_receipt_only` (`:448-489`): op 39 on the exact ingress, a fresh `op39-lookup-<nonce>` directory,
  `replayed`. It is an inline twin of `lookup_retained`.
- The test at `:582-658` ends by asserting that a file it just wrote reads back identically (`:646-656`). It never
  calls `recover_receipt_only`.

## 1.7 STOP v3

STOP reuses the BEGIN/CLAIM/COMPLETION opcodes with a `kind: "stop"` request. The Host returns a v2 stop plan
(`LAUNCH-STOP-OPERATOR-PLAN/v2`, `Host/Main.lean:6162-6167`). Four component files and one service compose it.

### `lifecycle_v3_stop_begin_native.rs` (247)

`FixedStopBeginSigners` (`:29-34`) uses the same protocol string as the START BEGIN signers. `checked_plan` (`:85-124`)
checks a nested `basePlan` whose request kind is `stop`, with `selectedCommandDigest` and `priorCreate` null.
`submit_once` (`:130-247`) is the START BEGIN skeleton again: operation ID from the begin ledger (`:148`);
`op66-requested.json` (protocol `mini-spk-stop-begin-op66-requested-v1`) plus parent
`lifecycle-stop-begin-v3-active.json` (`:169-170`); 66 → `stop-plan-v2.bin` → inspect
`application-lifecycle-launch-stop-plan` → sign → 67 → `begin-v3.bin` → `op22-requested.json` (protocol
`mini-spk-stop-begin-op22-requested-v1`) → 22 → `confirmed`/`installed` → `ExactReceipt`. **There is no
`recover_*_receipt_only` for the STOP BEGIN marker names** (F5). The file has no tests.

### `lifecycle_v3_stop_assembly_native.rs` (259)

`previous_index` (`:29-47`) is a verbatim copy of the claim file's. `FixedStopClaimSigners` (`:51-56`).
`checked_plan` (`:97-141`) checks against the accepted STOP BEGIN, with `binding == null`. `assemble_once`
(`:146-229`): query nonce from the claim nonce ledger; `op68-requested.json` plus parent
`lifecycle-stop-claim-assembly-active.json` (`:182-183`); 68 → 69 → `claim-v3.bin`. `submit_fresh_once` (`:233-246`)
delegates to `lifecycle_v3_stop_claim_native::submit_once`.

### `lifecycle_v3_stop_claim_native.rs` (357)

- `ExactReceipt` (`:29-94`): four canonical decimals, `accepted_count != "0"`.
- `FreshStopClaim` (`:100-136`) has a private constructor. **Only `target()` is used**; the other six accessors
  (`:115-135`) have no callers.
- `submit_once` (`:192-313`):
  1. retain `stop-plan-v2.bin`, `original-begin-v3.bin` and `claim-ingress-v3.bin`;
  2. preflight-inspect the plan (must be a v2 stop plan);
  3. `op26-requested.json` (protocol `mini-spk-stop-claim-op26-requested-v1`, plan/begin/claim SHA-256s, the begin
     receipt) plus parent `lifecycle-stop-claim-v3-active.json` (`:248-259`);
  4. invoke 26 → `op26-frame.bin` → require the v3 committed tag → inspect → `committed_source_receipt` (`:158-186`);
  5. **run `<host path> <config> inspect-stop-claim plan committed out` with `Command::new(&operator.host)`**
     (`:279-293`). That is not the verified descriptor and has no deadline (F4);
  6. read the output with `read_inspection` (`:138-156`; `symlink_metadata`, then `File::open` without `O_NOFOLLOW`, no
     mode check);
  7. `StopTarget::from_verified_inspection`.

### `lifecycle_v3_stop_native.rs` (796)

- `StopTarget` (`:61-77`) is built only from the Host CLI's `application-lifecycle-stop-claim-verified-v1` view
  (`from_verified_inspection`, `:117-240`). It checks echoes of the retained plan and fresh frame, a nested v2 plan of
  kind stop, claim kind stop, the running witness, both receipts equal to the retained ones, running `acceptedCount ==
  index + 1`, `running_generation + 1 == operation_generation`, unit, image, invocation, cgroup, volume ID, custody and
  physical witness.
- `persist_marker`/`check_marker` (`:270-314`): `stop-fence-requested.json` (at most 8 KiB). `check_marker` re-reads
  with mtime/ctime and dev/ino stability.
- `compare_identity` (`:316-332`) requires `volume_resource == self.app` (`:323`), a Rust convention (S13).
- `fence_exact` (`:390-406`): compare the Running record and volume, persist and check the marker, then
  `journal.fence_and_stop_manager_checked` (hostd, shard A).
- `resume_fenced_exact` (`:463-569`): re-read the retained artifacts with `read_private_artifact` (`:408-438`, a
  twin), check the op26 frame, marker and committed view, then **exec `inspect-stop-claim` by path again**
  (`:523-533`), re-derive `StopTarget`, require the journal to be **Fenced**, compare, then
  `journal.resume_fenced_stop_manager_checked`.

### `lifecycle_v3_stop_service.rs` (1,495): `spk-host resident-stop` / `grain stop`

This file has no `allow(dead_code)`. `pub fn run` (`:1166-1364`) is reached from `main.rs:133-134` and `grain.rs:1209`.

- `acquire_run_lock` (`:55-92`): `.resident-stop.lock`, `flock(LOCK_EX|LOCK_NB)`; contention is `AlreadyExists`.
- `read_private` (`:94-132`) is a fifth retained reader. `ensure_artifact` (`:134-144`) writes the expected bytes if
  absent, else requires equality.
- `StopConfig` (`:148-156`, `deny_unknown_fields`): protocol `mini-spk-resident-stop-v3`, `resident_start_config`,
  and five attempt directories. `ResidentPins` (`:162-192`) is a lenient subset of the START config (no
  `deny_unknown_fields`, deliberately). `load_config` (`:201-256`) requires every directory to be a child of
  `journal_dir`, hex64 IDs, non-zero UIDs and resources, absolute paths, and no overlapping attempt directories.
- `match_qualification` (`:280-299`): `mini-spk-launch-qualified-v2` record versus the signed launch descriptor.
- `inspect_original` (`:312-414`) is the twin of `resume_fenced_exact`'s first half. It execs `inspect-stop-claim` by
  path (`:369-382`) and reads the output with an **unbounded `fs::read`**, checking size afterwards (`:384-387`).
- `prepare_report` (`:485-593`) is the third copy of the report flow, with outcome `stopped`, pid 0 and `stopAudit`
  set from `UnitStopAudit::source_stop_audit` (hostd). It re-audits before signing (`:553-557`).
  `signed_report_retained` (`:619-740`) re-derives every report artifact after a crash and re-signs (Ed25519 is
  deterministic, so `ensure_artifact` can compare).
- `report_needs_fresh` (`:742-759`) removes an empty report directory.
- `assemble_completion` (`:761-899`) is the third completion skeleton. `completion_dir` (`:949-976`) **replans** into a
  nested `replan/` child (at most 8 deep) whenever an attempt has no `op38-requested.json`. This is safe because ops
  70/71 write nothing: `Host/Main.lean:6229-6262` only plans and assembles.
- `retained_completion_anchor` (`:1007-1048`) recovers a complete op38 frame after a crash and ignores a truncated one.
- `complete_once_or_lookup` (`:1050-1113`): if the op38 marker is absent, re-audit Stopped, write the marker, send 38
  once, anchor the receipt. Otherwise lookup 39 with fresh probe directories and require equality with the anchor.
- `set_aside_pure_begin` (`:1122-1164`): if the only artifact is an op66 plan (no op67, op22 or `begin-v3.bin`, no
  later attempt directory, and the parent marker equal to the attempt's marker), rename it to
  `stop-begin-plan-only-<rand>` so a new STOP may start. **Rust decides this attempt changed nothing.** That is correct:
  op 66 has no Store effect (`Host/Main.lean:6148-6177` only plans). The operation ID allocated for it is never reused.
- `run` dispatches on the journal phase:

| journal phase | action | lines |
|---|---|---|
| Running | set aside a pure BEGIN; refuse if **any** attempt directory or STOP active marker exists ("requires audit"); load begin/claim signer custody; `stop_begin::submit_once` → volume check → `stop_assembly::assemble_once` → `submit_fresh_once` → `stop_native::fence_exact` | 1216-1270 |
| Fenced | `stop_native::resume_fenced_exact` | 1271-1277 |
| Stopped | `inspect_original` + `audit_stopped_manager_checked` | 1278-1287 |
| other | refuse | 1288-1292 |
| then, always | `inspect_original` again; re-audit, which must equal the audit; report (fresh or retained); completion (fresh or retained); `complete_once_or_lookup` | 1294-1363 |

- Tests (`:1366-1495`): lock exclusivity, a truncated op38 frame is not an anchor, all four receipt fields compared,
  report reopen, replan versus the op38 marker.

## 1.8 Governed repeat CREATE, v4

`lifecycle_v4_retry_native.rs` (923), `lifecycle_v4_retry_claim_native.rs` (550) and
`lifecycle_v4_retry_completion_native.rs` (782). The doc (`v4_retry_native.rs:1-12`) calls the module "Modeled line by
line on `lifecycle_v3_native`". A v3 create BEGIN refuses forever once its first-attempt nullifier is consumed. The
only lawful repeat names the accepted failed-START recovery (event66) by native index and canonical ingress.

- Tags (`v4_retry_native.rs:37-50`): `RETRY-CREATE-BEGIN-OPERATOR-REQUEST/v4`, `…-PLAN/v4`,
  `RETRY-CREATE-BEGIN-INGRESS/v4`, `FAILED-START-RECOVERY-INGRESS/v1`, `FAILED-CREATE-RETRY-SELECTOR/v1`. The claim and
  completion files add their own (`v4_retry_claim:29-36`, `v4_retry_completion:38-48`). Every tag cites a Lean file and
  line in a comment.
- **A Rust StreamCodec**: `encode_nat_decimal` (base-255 little-endian digits plus terminator 255, `:80-102`),
  `encode_nat_usize` (`:104-112`), `encode_bytes` (`:115-119`). They are used in production by
  `RetrySelection::selector_stream`/`selector_canonical` (`:239-256`), `checked_retry_fields` (`:347-355`, compares
  the Host view's `retrySelectorHex` with the Rust encoding), `checked_request_frame` (`:387-396`, requires the
  Host-authored request to end with the Rust-encoded selector), `v4_retry_claim::request_bytes` (`:57-62`, compared to
  the Host-authored request at `:225-227`), and `v4_retry_completion::{expected_report_prefix, checked_signing_frame,
  expected_signed, request_bytes}` (`:217-251`, `:385-391`, compared at `:282`, `:316`, `:347`, `:520`). v3 checks the
  same things through Host inspection only. These checks fail closed, but they are hand-written codec twins (law 13).
  The tests (`:745-801`, claim `:529-534`, completion `:742-773`) check the Rust encoder against hand-written byte
  vectors, not against Lean.
- Lane selection: `retry_generations(create, generation)` (`:275-285`) gives `failed = generation - 2` and
  `before = generation - 1` for a create. `select_retry` (`:291-316`) looks for
  `<apps>/g{failed}/failed-start-recovered-v1.json` (written by `grain_export`, shard B) and
  `g{failed}/failed-start-recovery-v1/ingress.bin`. If absent: v3. If present: `RetrySelection::from_retained`
  (`:186-233`) requires protocol `mini-spk-failed-start-recovered-v1`, app, generation, `outcome.type == "confirmed"`,
  confirmation installed or replayed, `reconciledGeneration == before`, the ingress SHA-256, and the frame tag.
  `recovery_index = acceptedCount - 1` (`decimal_predecessor`, `:122-139`, the third copy of `previous_index`).
- `submit_once` (`:553-702`) is the v3 BEGIN skeleton with v4 kinds: the request is inspected before any marker
  (`:579-603`); `ACTIVE_MARKER = lifecycle-begin-retry-v4-active.json`, `BEGIN_ATTEMPT_DIR = begin-attempt-retry-v4`
  (`:66-68`).
- `v4_retry_claim`: `assemble_once` (`:195-305`), `checked_committed` (`:308-376`, the v4 view type plus retry fields),
  `submit_fresh_once` (`:380-434`), `verified_physical_begin` (`:436-478`, **identical** to v3's `:476-518`),
  `checked_assembled` (`:480-502`, identical shape), `recover_claim_receipt_only` (`:506-522`).
- `v4_retry_completion`: the `allow(dead_code)` at `:7` claims "op39 arm is reached only by operator recovery", but
  `resident_service.rs:1056` calls `recover_receipt_only` on restart. Report: `prepare_report_once` (`:254-378`, Running
  only). Completion: `assemble_once` (`:482-607`), `submit_fresh_once` (`:635-689`), `recover_receipt_only`
  (`:693-735`, via `lookup_retained`).
- Lean routes v4 frames first by tag inside the same opcodes: `retryLifecycleBeginPlan`, `…Assemble`,
  `retryLifecycleClaimPlan`, … (`Host/Main.lean:6156-6158, 6182, 6205-6206, 6217-6218, 6236-6237, 6248`; definitions `:6061-6130`), and
  op 26 checks `ApplicationLifecycleRetryClaimV4Ingress.codec.decode` first (`Host/Main.lean:2553-2554`).

## 1.9 v3 versus v4: what differs, why both live, which runs

| aspect | v3 | v4 |
|---|---|---|
| purpose | INSTALL; START create(index) and continue; STOP | only a repeat create after a reconciled failed first create |
| BEGIN request | `{kind, clientOperationId, descriptor, createIndex}` or continue | plus `retry: {recoveryIndex, recoveryIngress}` (`v4_retry_native.rs:359-381`) |
| Mini events | event23/24/25 | event69/70/72 (`resident_service.rs:519-521`) |
| artifact names | `begin-attempt`, `claim-author-attempt`, `completion-*` in the resident config | fixed names `begin-attempt-retry-v4`, `claim-author-attempt-retry-v4`, `completion-attempt-retry-v4`, `completion-sign-attempt-retry-v4` |
| Rust checks | Host inspection only | Host inspection plus Rust-encoded expected bytes |
| who calls | `install_v3` (INSTALL), `resident_service` START (create/continue), stop service | `resident_service` START only when `start_retry` returns `Some` (`resident_service.rs:587-597,1409-1416`) |
| run evidence | jspk1 44/44 (`docs/evidence/2026-10-01-spk-apps/jspk1/rows.tsv`): INSTALL, START, supervisor STOP plus continue-START after SIGKILL, STOP, START | none in `docs/evidence`; `scripts/spk-platform/fixture-v4.sh` (fixture-os build) authored; `docs/SPK-LIFECYCLE.md:109-110` says "authored only" as of `87b6c9b5`; later commits `374549d4`, `dd97fcc6`, `81cecae5`, `304b976e` touched it |

Why both live: v4 is a separate **Lean** lane. Its BEGIN, CLAIM and COMPLETION are different kernel events with
their own receivers (`Kernel/ApplicationLifecycleRetry*V4*.lean`, 16 files). The resident chooses between lanes by
local evidence: `StartLane::of_journal` (`resident_service.rs:285-306`) refuses a journal that holds both admitted
markers. Lean would refuse the wrong lane (v3 create after a consumed first attempt), so the selection is a mirror (S5).

Which path each command takes:
- `grain install` → `install_v3` (shard A) → v3 BEGIN `Install`, v3 claim, report `Materialized`, v3 completion.
- `grain start` / unit `resident-bootstrap` → `resident_service` START → v3 create/continue, or v4 if `select_retry`
  finds a recovery record.
- `grain supervise` → `stop` (v3 STOP service) then `start` (continue; jspk1 row s1-kill-a: "supervisor STOP +
  continue -> generation 4").
- `grain stop` / `spk-host resident-stop` → v3 STOP service.

**Operation and nonce ledgers.** `operation_ledger::allocate_operation_id` (shard A, `operation_ledger.rs:25-109`) is
called for the BEGIN `clientOperationId` from the resident's `begin_operation_ledger` (v3 BEGIN `:428`, v4 BEGIN
`:569`, STOP BEGIN `:148`) and for the CLAIM `queryNonce` from `claim_nonce_ledger` (v3 claim `:224`, v4 claim `:216`,
STOP claim `:165`). Each allocation happens after the attempt directory exists and before any Host call, and is never
reused. A set-aside or abandoned attempt burns its number.

**Same-bytes resubmission.** None in this shard. The rule shard A found in `install_v3.rs:621-629` (re-send the retained
op38 ingress when `op38-requested.json` is absent) is not used by the STOP service, which **replans** ops 70/71
instead (`lifecycle_v3_stop_service.rs:949-976`). That is safe either way, since 70/71 have no effect, but the two
paths follow different rules for the same situation (twin behaviour, 5.4).

**Where Rust decides "definitely unadmitted" and where it looks up:**

| site | decision | basis | verdict |
|---|---|---|---|
| `dispatch_native.rs:1051-1060` | op34/164 attempt left no Store record | exact Lean NO_RECORD frame | defers to Lean |
| `lifecycle_v3_stop_service.rs:1122-1164` | an op66-only STOP BEGIN changed nothing | op 66 is a plan (`Host/Main.lean:6148-6177`) | correct |
| `lifecycle_v3_stop_service.rs:949-976` | an attempt without an op38 marker can be replanned | ops 70/71 are pure | correct |
| `lifecycle_v3_stop_service.rs:742-759` | an empty report directory can be removed | nothing signed yet | correct |
| `agent_api_native.rs:811-818` | cancelled before op 46: remove the agent marker | op 46 not invoked | correct |
| `agent_api_lifetime_dispatch_native_v3.rs:163-166` | cancelled before op 76: keep the marker | conservative | correct |
| every op22/26/38 lost reply | lookup 23/27/39 only, on the exact retained ingress | `lifecycle_receipt_lookup.rs:124-159` | correct |
| agent reserve lost reply | controller `inspect-v2`/`inspect-v3` (read-only) | `agent_api_native.rs:519-529`, `agent_api_lifetime_reverse_v3.rs:462-477` | correct |
| STOP op22 or op26 lost reply | **nothing**; Running branch refuses | `lifecycle_v3_stop_service.rs:1220-1234` | gap (F5) |

## 1.10 Agent API v1 (`mini-spk-agent-api-v1`, custody `mini-spk-agent-dispatch-custody-v2`)

Purpose: a resident (the process owning the app's fd 3) lets one **controller** (the Hermes agent runtime in
`native/grain-runtime`, under a distinct UID) dispatch paid API requests to the SPK app as an agent-origin session
(event21). The controller holds the purse and payer key. The resident holds the app-slot seeds and the physical
delivery. "Reverse" means the resident connects back to a controller-owned socket to ask for a reserve and payer
signatures.

### `agent_api_wire.rs` (443)

The `allow(dead_code)` at `:6` sits under a doc (`:1-5`) that says "The server remains disabled until event21's …
reserve, permit, and fd3 fence are available". Stale: the server is wired in `resident_service.rs:2104-2117`.

- Limits (`:14-17`): `MAX_FRAME` 262,144 (request), `MAX_REPLY_FRAME` 1,048,576, `MAX_BODY` 65,536, a 30 s absolute
  transfer deadline.
- Frames are **big-endian** u32 length + JSON (`read_frame` `:282-293`, `write_frame` `:322-349`). The Host wire is
  little-endian.
- `Request` (`:56-75`, serde tag `type`, kebab-case, `deny_unknown_fields`): `hello {protocol}`, `dispatch {protocol,
  operation_id, method, path, query, headers[{name,value}], body_hex}`, `inspect {protocol, operation_id,
  binding_sha256?}`. `parse` (`:102-171`) checks: protocol `mini-spk-agent-api-v1`; canonical decimal operation ID;
  method one of GET, HEAD, POST, PUT, PATCH, DELETE; `signed_api_path::route("/", path)` ok; query at most 8 KiB, no
  `#`, `control_free`; at most 128 headers; lowercase-hex body at most 64 KiB; no body for GET, HEAD or DELETE; each
  header in `allowed_header` (`:77-99`), name at most 128, value at most 8 KiB and `control_free` (`:37-45`: refuses
  NUL, CR, LF, any byte < 0x20 except TAB, and 0x7F).
- `allowed_header` (`:77-99`) is **a copy of Lean's `ordinaryHeaderName`** (`Kernel/ApplicationDispatchAdmission.lean:115-120`,
  18 names, identical).
- `FixedBinding` (`:176-191`, protocol `mini-spk-agent-binding-v1`): app, app_generation, session,
  session_generation, subject, ticket, parent_task, parent_generation, purse_task, purse_generation, signed_api_path,
  host_unit, host_invocation (32 hex). `fingerprint` (`:224-234`) is SHA-256 of
  `"DREGG/SPK-AGENT-API-BINDING/v1\0" ++ serde_json(self)`, a transport comparison key. The JSON is the serde field
  order, which is deterministic.
- `Reply` (`:239-277`): `binding`, `http {status, headers, body_hex}`, `refused {code}`, `uncertain {phase}`,
  `inspection {state, definite_reply_sha256?, definite_reply_json_hex?, retention_error?}`.

### `agent_api_custody.rs` (379)

- `AgentCustody` (`:60-87`): app, app_generation, session, session_generation, subject, ticket_resource,
  parent_task/generation, purse_task/generation, issue_index, package/snapshot manifests, session/manifest/enrollment
  observe capabilities, parent capability/observe, purse capability/observe, payer_subject, **reserve_amount,
  maximum_charge**, `app_signers: Vec<SignerPin>` (local seeds) and `payer_pins: Vec<PayerPin>` (public keys only).
  `validate` (`:100-175`): all canonical decimals, parent != purse, both amounts parse as u128, `maximum_charge <=
  reserve_amount` (the `unwrap()`s at `:132-133` are guarded by the earlier `is_none()` checks in the same `||`
  chain), signers at most 64, unique role/index.
- `fixed_selectors` (`:177-186`) and `reserve_request` (`:188-230`) build
  `{base:{issueIndex,…,http:{operationId,methodHex,pathHex,queryHex,headers,bodyHex}}, parentTask, …, payerSubject,
  reserveAmount, maximumCharge, reserveOperationId}`.
- `sign_slots` (`:232-280`): the inspection's `canonicalPlanHex == hex(plan)`, `fixedSelectors ==` custody, type
  `application-agent-paid-dispatch-plan-v2`, non-empty compact selector and HTTP hex; exact slot count; each slot's
  role, index, decoded, keyId, keyEpoch and algorithm "1"; then sign `headerHex` with the local seed after checking it
  against the pinned public key.
- `verify_payer_slots` (`:285-340`): the same plan checks, then **Rust verifies each controller-supplied Ed25519 payer
  signature** over the source header against the pinned public key before op 49 (S8).

### `agent_api_native.rs` (1,094)

The `allow(dead_code)` at `:3` is stale.

- `ReverseCustodyClient` (`:125-131`): socket, controller_uid, route_name (must end in `-app`, `:167-190`), and the
  attempt and forward operation IDs learned from the reserve.
- `exchange_until` (`:199-301`):
  1. check every socket ancestor (a directory, not group- or world-writable unless root-owned sticky, owned by root,
     the controller or the euid);
  2. the socket must be owned by `controller_uid`;
  3. `connect_cancelled` (`:349-462`, a twin of `dispatch_native::connect_deadline`; this one fails at once on
     `EAGAIN`);
  4. **SO_PEERCRED uid == controller_uid** (`:235-250`);
  5. inode unchanged;
  6. write BE32 + JSON (at most 22 MiB) with cancellation checks;
  7. read a BE32 length (at most 1 MiB) and the reply JSON.
  "never retries a request after writing any byte".
- `ReserveSubmit` trait (`:606-632`): `reserve_once`, `sign_payer_once`, `mark_send_once`. The implementation
  (`:502-604`) sends JSON messages `reserve-v2`, `inspect-v2` (only after a failed `reserve-v2`, `:519-529`),
  `sign-payer-v2`, `mark-send`. The expected replies are `dispatch-reserved-v2`, `payer-signatures-v2` and
  `dispatch-send-marked-v1`.
- `authorize_once` (`:669-853`), the event21 flow:

| step | lines | Host op |
|---|---|---|
| create the attempt directory (fails if present) | 682-686 | |
| `reserve_request(request, "0", app_path)` → controller `reserve-v2` (the controller runs ops 58/59 and the reserve submit) | 687-688 | (58/59 at the controller) |
| canonical receipt fields; `reserve_index == accepted_count - 1` as u128 | 692-718 | |
| re-author `application-agent-reserve-request` with the real reserve op ID; must equal the controller's `fixedRequestHex` | 719-731 | |
| `original-reserve.json` | 732-736 | |
| author `application-agent-paid-request` | 737-745 | |
| **op 48** → paid plan; inspect `application-agent-paid-dispatch-plan`; context and reserve index equal | 746-764 | 48 |
| canonical HTTP hex → `canonical_http_sha256` | 765-779 | |
| app signatures (local) + controller payer signatures + **Rust verify** | 780-785 | |
| `signatures` tool twice; **op 49** with `pair(plan, pair(app, payer))` → `paid-ingress.bin` | 786-794 | 49 |
| `submit-requested.json` + parent `native-agent-dispatch-active.json` (`create_new`, **no mode, no `O_NOFOLLOW`**) | 795-810 | |
| a cancellation now removes the marker (op 46 not sent) | 811-818 | |
| **op 46** → `op46-frame.bin`; must carry `AGENT-DISPATCH-COMMITTED-PERMIT/v2`; inspect `application-agent-dispatch-committed` | 819-842 | 46 |

  Lean side: ops 48/49 are `agentDispatchAuthorSession` (`Host/Main.lean:2166-2193`, which checks `matchesFixed
  approved` against the Host-config pin). Op 46 is `dispatchAgentSubmitSession` (`Host/Main.lean:2437-2472`): a permit
  is written as opcode 46 only for a fresh CAS winner, otherwise an outcome frame.
- `CommittedAgent::clear_committed_submit_marker` (`:646-661`) removes the route marker only if dev/ino and bytes are
  unchanged.

### `agent_api_server.rs` (1,470)

The `allow(dead_code)` at `:4` is stale.

- `exact_acl` (`:98-137`) runs **`/usr/bin/setfacl -m u:<uid>:…`** (install) and **`/usr/bin/getfacl -cpn`**
  (inspect), and requires the exact ACL lines {owner, group::---, other::---, user:<controller>:…, mask::…}.
- `protected_agent_socket_parent` (`:139-181`): ancestors protected; the leaf directory euid-owned with no "other"
  bits; a distinct controller must be able to traverse every ancestor.
- `CallerWatch` (`:183-232`) is **one thread per request** that `recv(MSG_PEEK|MSG_DONTWAIT)` polls every 10 ms. Any
  readable byte or EOF marks the request cancelled.
- `AgentApiListener::bind` (`:274-315`): bind, chmod 0600, install the ACL, non-blocking.
  `accept_authenticated` (`:365-402`): on **every** accept, re-check the socket inode and mode (0600, or 0660 with a
  distinct controller), **run `getfacl`** (`:384`), then check SO_PEERCRED uid. A mismatched peer is dropped silently
  (`Ok(None)`, `:399`). Any other error returns `Err` to the resident loop.
- `poll_once` (`:319-361`): accept; `read_frame` (blocking, with a 30 s deadline); parse; `CallerWatch`;
  `handle_once`. **Any** error after parse becomes `Uncertain { phase: "retained-attempt" }` when the request had an
  operation ID (`:342-355`).
- `ResidentAgent::binding` (`:418-450`) builds `FixedBinding` from custody and the live journal (invocation ID, unit).
- `handle_once` (`:452-504`): `hello` returns the binding; `inspect` returns the saved state; `dispatch` runs
  `dispatch_once`.
- `dispatch_once` (`:506-734`):
  1. decode the body;
  2. `HttpProjection` with route `Api { signed_path }`;
  3. create `agent-client-op-<operation_id>` (fails if present);
  4. write `received.json` and `source-operation.json`. **The operation ID is the controller's** ("The controller
     allocates and durably records this forward operation before calling the resident", `:568-571`);
  5. `authorize_once`; `submit-requested.json`; `match_committed` (`:906-1052`, which compares app, session, origin
     **agent** with parent task and generation, parent, purse task, generation, payer, **reserveAmount**,
     **maximumCharge**, reserve op and index, the original reserve receipt, ticket, request bytes and headers, receipt
     versus dispatch tx/event);
  6. `physical_web_input`;
  7. disconnect or trailing-byte fence via `MSG_PEEK` (`:625-643`);
  8. build `DispatchIdentity` with **operation_id = the controller's ID** (`:649-663`);
  9. **`mark_send_once` before** `prepare_cancellable` and `request_dispatch` (`:667-676`);
  10. `write_agent_delivery_marker` (`:740-763`);
  11. `prequeue.dispatch(…, 64 KiB, 30 s, cancelled)`;
  12. serialize; `http_reply`; `definite.json` + `definite.sha256`; `finish_dispatch(true)`; clear the route marker.
- `inspect_state` (`:765-787`) returns `definite`, `delivery-requested`, `uncertain`, `received` or `not-seen` from
  marker files. While the route-wide `native-agent-dispatch-active.json` exists, **every** operation ID, including ones
  never seen, reports `uncertain` (`:774-777`).
- `recover_definite` (`:867-904`) re-verifies the saved reply by SHA, operation and binding.
- Tests (`:1092-1470`): inspection ladder, definite recovery, listener inode drop, symlink preflight, ACL with a
  distinct UID (needs `setfacl`), binary git reply, event21 projection.

## 1.11 Agent API lifetime v3 (`mini-spk-agent-api-v3`, custody `mini-spk-agent-lifetime-custody-v3`)

Lifetime dispatch (event26) charges a long-lived **grant** (event27, lineage back to the event22 ticket issue)
instead of per-session v1 custody. The controller runs the reserve as op 80/81 plus submit.

### `agent_api_lifetime_wire_v3.rs` (300)

The `allow(dead_code)` at `:3` is stale. `Request` (`:76-102`): `hello-v3`, `dispatch-v3 {operationId,
bindingSha256, method, path, query, headers, bodyHex}`, `inspect-v3 {operationId, bindingSha256,
operationFingerprint?}`. The JSON keys are camelCase here and snake_case in v1. `allowed_header` (`:43-65`) is **another
copy** of Lean's list. `control_free` (`:37-41`) refuses TAB, while v1's allows it (5.4). `Reply` (`:180-252`) adds
`operationFingerprint`, `responseSha256` and `committedReceipt` to `http-v3`. The v3 server **reuses v1's BE32 framing**
(`agent_api_wire::read_frame` at `agent_api_lifetime_server_v3.rs:105`).

### `agent_api_lifetime_v3.rs` (764)

The `allow(dead_code)` at `:4` is stale. Comparison types only: `ReceiptPin` (`:76-99`); `LifetimeLineage` (`:106-153`:
app, session, participant, ticket, original parent task and generation, original issue index and receipt, original
descriptor SHA-256, grant resource, issue index, digest, initialized root, grant issue receipt, parent and purse
tasks; parent must equal original parent, purse must differ); `CurrentClaims` (`:162-193`: four generations and four
physical roots, **supplied by the controller per operation**); `LifetimeBinding` (`:200-237`, fingerprint domain
`DREGG/SPK-AGENT-LIFETIME-BINDING/v3\0`); `operation_fingerprint` (`:242-259`, binding fingerprint ++ claims ++ op ID
++ request SHA). `match_reserve_plan` (`:265-345`), `match_paid_plan` (`:350-410`) and `match_committed_inspection`
(`:428-543`) compare op 80/78/76 inspections field by field with the lineage and the current claims.

### `agent_api_lifetime_reverse_v3.rs` (990)

The `allow(dead_code)` at `:4` is stale. `LifetimeReverseClient` (`:214-216`) wraps the v1 `ReverseCustodyClient`.
Messages: `reserve-v3` (with `worker_wall_seconds`, `:433-492`, falling back to `inspect-v3` on error),
`sign-payer-v3` (`:384-429`), `mark-send-v3` (`:302-346`; it sends the full ingress and committed frame hex),
`settle-definite` (`:351-380`; the reply carries the controller's `charge`, only checked to be decimal),
`inspect-settlement-v3` (`:237-298`, read-only; `dispatch-settlement-uncertain-v3` or `settled-v3`).
`accept_reserved_reply` (`:494-614`): `index_precedes_count` (`:32-53`, a fourth copy of the count-1 relation);
inspects the controller's reserve request and plan with the pinned Host (`application-agent-lifetime-reserve-request`
and `-reserve-plan`); `match_reserve_plan`; recomputes the operation fingerprint; writes `reserve-verified-v3.json`.
`VerifiedSettlementV3` (`:158-191`) is what `hostd::finish_dispatch_recovered` consumes.

### `agent_api_lifetime_custody_v3.rs` (561)

The `allow(dead_code)` at `:3` is stale. `LifetimeCustodyV3` (`:72-91`) holds the lineage, the same selector fields as
v1 plus `grant_observe_capability`, **reserve_amount / maximum_charge** (both non-zero, max <= reserve, `:114-123`),
`app_signers`, a separate `grant_signer` (`:89`, must not collide with app pins, `:148-161`) and `payer_pins`.
`sign_app_slots` (`:178-217`) and `verify_payer_slots` (`:253-298`) are **near-verbatim twins** of v1's `sign_slots`
and `verify_payer_slots`; `PayerPin` (`:62-68`) is a twin struct. `sign_grant_slot` (`:219-251`) signs the 64-byte
grant observation. `binding` (`:300-322`). `fixed_reserve_request` (`:326-389`) builds the op 80 fixed request with
`reserveOperationId: "0"`.

### `agent_api_lifetime_paid_native_v3.rs` (231) and `agent_api_lifetime_dispatch_native_v3.rs` (268)

Both carry stale `allow(dead_code)`. `assemble_once` (paid, `:80-203`): re-inspect the retained reserve plan; author
and inspect `application-agent-lifetime-paid-request`; **op 78**; inspect the paid plan; controller payer signatures;
`match_paid_plan`; Rust-verify payer signatures; sign app and grant slots; **op 79** with the nested pair
`pair(app, pair(grant64, payer))` (`:182-183`). This matches Lean's op 79 (`Host/Main.lean:2254-2268`: `splitPair`
twice, 64-byte grant). `submit_fresh_once` (dispatch, `:127-240`): `op76-submit-requested-v3.json` + parent
`native-agent-lifetime-active.json` (0600, `:144-162`); **op 76**; require `AGENT-LIFETIME-DISPATCH-COMMITTED-PERMIT/v3`;
inspect; reserve op, index, receipt, context and canonical HTTP equal; dispatch receipt later than the reserve
(`later_count`, `:29-32`, a twin of `later_decimal`); `match_committed_inspection`.
`clear_retained_active_after_settlement` (`:89-125`).

### `agent_api_lifetime_server_v3.rs` (1,057), the only file in the family without `allow(dead_code)`

`poll_once` (`:98-128`) **never sends a reply on error** (it closes the socket) because "A fabricated RefusedV3 would be
unsafe". This is the opposite of the v1 server, which replies `Uncertain` for every error. `dispatch_once` (`:182-425`):

1. binding fingerprint equal;
2. `agent-lifetime-client-op-<id>` with `forward-request-v3.json` and `received-v3.json`;
3. `agent-lifetime-dispatch-op-<id>`;
4. `fixed_reserve_request`;
5. `reverse.reserve_once`;
6. `source-verified-v3.json`;
7. paid `assemble_once` (78/79);
8. `submit_fresh_once` (76);
9. `op76-fresh-v3.json`;
10. `matched_v3` (`:601-655`);
11. physical input;
12. `caller_still_present`;
13. `DispatchIdentity` (operation ID = the controller's);
14. `dispatch-identity-v3.json`;
15. prequeue;
16. `request_dispatch`;
17. delivery marker;
18. **`mark_send_once` after** the hostd record (`:343-356`), the reverse of v1's order;
19. dispatch;
20. `app-response-v3.bin` + SHA;
21. `settle_definite_once`;
22. `settle-confirmed-v3.json`;
23. `finish_dispatch(true)`;
24. clear the route marker;
25. `definite-v3.json`.

`recover_settlement` (`:427-561`) runs after a lost settlement ACK: verify the retained artifacts, then
`inspect_settlement`. If settled: `write_new_or_same`, `journal.finish_dispatch_recovered`, clear the marker, save the
definite reply. `inspect_saved` (`:704-867`).

**Item (3): is v1 a superseded sibling of v3?** In practice yes. Both are live code paths selected per `agents[]`
entry (`resident_service.rs:1476-1497`). But (a) the `grain` CLI writes `"agents":[]` (`grain.rs:1116`), so every
resident in the jspk journeys has no agent listener; (b) `docs/evidence/2026-09-27-spk-resident-mixed-route/README.md`
says the r3 journey admits only v3 agents or none, and keeps the "older v2 request shape … for historical use";
(c) no evidence directory records an agent request reaching fd 3 under either protocol, and the v3 gate states it
explicitly. v3 cannot be deleted without its v1 dependencies (listener, ACL, `CallerWatch`, frames, reverse
transport; about 800 code lines). v1's remaining about 1.8K code lines plus about 750 test lines are superseded.

## 1.12 Wire formats this shard speaks

| boundary | framing | body | where |
|---|---|---|---|
| resident → operator socket (`resource-client`) → Lean Host | LE32 length | `[2][LE32 cfg][cfg][sha256(Host) 32][op][payload]` | `dispatch_native.rs:530-541`; `transport.rs:173-217` |
| Host → resident | LE32 length | `[op or 255 or crossing][payload]`, payload starts with a versioned tag | `Host/Main.lean:2341-2347` `writeSessionFrame` |
| selector-framed lifecycle plan request | LE32 selector length | `selector JSON ++ request bytes` | `lifecycle_selector.rs:63-76` |
| plan + signatures pair (37, 67, 69, 71, 49, 79) | LE32 left length | `plan ++ signatures` (49: `plan ++ pair(app, payer)`; 79: `plan ++ pair(app, pair(grant64, payer))`) | `dispatch_native.rs:919-922`, `agent_api_native.rs:788-790`, `agent_api_lifetime_paid_native_v3.rs:182-183` |
| helper CLI | argv | `/proc/self/fd/N CONFIG {author\|inspect\|signatures} [KIND] IN OUT`; `profile` → stdout | `dispatch_native.rs:449-465` |
| STOP inspection CLI | argv (by path) | `HOST CONFIG inspect-stop-claim PLAN COMMITTED OUT` | `lifecycle_v3_stop_claim_native.rs:281-290` and two more |
| controller → resident agent socket | BE32 length | JSON `Request` v1 (snake_case) or v3 (camelCase) | `agent_api_wire.rs:282-349` |
| resident → controller reverse socket | BE32 length | JSON `reserve-v2/-v3`, `inspect-v2/-v3`, `sign-payer-v2/-v3`, `mark-send`, `mark-send-v3`, `settle-definite`, `inspect-settlement-v3` | `agent_api_native.rs:257-300`, `agent_api_lifetime_reverse_v3.rs` |
| retained markers | files | JSON protocols `mini-spk-*-requested-v{1,3,4}` (21 distinct protocol strings in this shard) | per file above |

## 1.13 Processes, sockets, files, environment

- **Processes spawned**: the pinned Host binary for each `author`, `inspect`, `signatures` and `profile` (via
  `/proc/self/fd/N`); `inspect-stop-claim` (via path); `/usr/bin/setfacl` and `/usr/bin/getfacl` (agent listener);
  one `CallerWatch` thread per agent request; `spawn_blocking` per WebSocket renewal.
- **Sockets**: the operator socket (connect); the agent listener (bind, one per `agents[]` entry); the controller
  reverse socket (connect).
- **Files**: per generation journal `<journal>/dispatch-op-N/` (request.json/bin, plan.bin/json, signatures.json/bin,
  ingress.bin, route-bound-dispatch.json/bin, submit-requested.json, op34|164-frame.bin, committed-payload.bin,
  inspection.json), `<journal>/native-dispatch-active.json`, `<journal>/continuity-<rand>/` (removed on drop), STOP
  and START attempt directories and their parent `lifecycle-*-active.json` markers (11 marker names: begin-v3,
  claim-v3, completion-v2, stop-begin-v3, stop-claim-assembly, stop-claim-v3, stop-completion-v2, begin-retry-v4,
  claim-retry-v4, completion-retry-v4, plus `stop-fence-requested.json`); `.resident-stop.lock`; agent attempt
  directories `agent-client-op-*`, `agent-dispatch-op-*`, `agent-lifetime-client-op-*`, `agent-lifetime-dispatch-op-*`,
  and route markers `native-agent-dispatch-active.json`, `native-agent-lifetime-active.json`.
- `/dev/urandom` for nonces (`dispatch_native.rs:590`, `lifecycle_receipt_lookup.rs:131`, report nonces).
- **Environment variables**: none read in this shard.

---

# 2. What it assumes of its surroundings

## 2.1 Host protocol operations, with the Lean cross-check

Every operation below is `status: active`, `routes: ["operator"]` in `protocol/host-operations.json`. None is public.

| byte | symbol | receiver (registry) | Lean arm read | Rust sender | reply Rust accepts | agree? |
|---:|---|---|---|---|---|---|
| 22 | APPLICATION_LIFECYCLE_BEGIN_SUBMIT | dispatchSession | `Host/Main.lean:2084-2086` → outcome codec | `lifecycle_v3_native.rs:493`, `stop_begin:218`, `v4_retry_native:674` | opcode 22 + `OUTCOME/v6`, `confirmed`/`installed` | yes |
| 23 | …BEGIN_LOOKUP | dispatchSession | `:2087-2089` | `lifecycle_receipt_lookup.rs:134` via v3 `:548`, v4 `:720` | 23 + outcome, `replayed` | yes |
| 26 | …CLAIM_SUBMIT | serveFrame | `:2637-2638` → `dispatchLifecycleClaimSubmitSession` `:2550-2600` (v4 tag first) | v3 claim `:450`, stop claim `:261`, v4 claim `:402` | 26 + `LIFECYCLE-CLAIM-COMMITTED/v3` or `RETRY-CREATE-CLAIM-COMMITTED/v4` | yes. Lean writes committed bytes only for a fresh installed winner, else `confirmed replayed` (`:2565-2585`), which Rust refuses by tag |
| 27 | …CLAIM_LOOKUP | dispatchSession | `:2090-2092` | lookup via v3 `:424`, v4 `:521` | 27 + outcome, `replayed` | yes |
| 34 | APPLICATION_DISPATCH_SUBMIT | serveFrame | `:2627-2628` → `dispatchApplicationSubmitSession` `:2353-2397` | `dispatch_native.rs:1129` | 34 + `DISPATCH-COMMITTED-PERMIT/v1`; or exact 164 NO_RECORD frame | yes (2.2) |
| 36 | APPLICATION_DISPATCH_PLAN | fnDispatch | `:2106` | `dispatch_native.rs:891` | opcode 36 | yes |
| 37 | APPLICATION_DISPATCH_ASSEMBLE | dispatchSession | `:2107-2113` | `dispatch_native.rs:923` | opcode 37 | yes (pair layout) |
| 38 | …COMPLETION_SUBMIT | dispatchSession | `:2114-2116` | v3 completion `:424`, stop service `:1070`, v4 completion `:672` | 38 + outcome `installed`, count later than claim | yes |
| 39 | …COMPLETION_LOOKUP | dispatchSession | `:2117-2119` | v3 completion `:470`, stop service `:1095`, v4 via lookup `:712` | 39 + outcome `replayed` | yes |
| 46 | AGENT_PAID_DISPATCH_SUBMIT | serveFrame | `:2633-2634` → `dispatchAgentSubmitSession` `:2437-2472` | `agent_api_native.rs:819` | 46 + `AGENT-DISPATCH-COMMITTED-PERMIT/v2` | yes |
| 48 | AGENT_PAID_DISPATCH_PLAN | fnDispatch → `agentDispatchAuthorSession` | `:2166-2178` (`matchesFixed approved`) | `agent_api_native.rs:746` | 48 | yes |
| 49 | AGENT_PAID_DISPATCH_ASSEMBLE | fnDispatch | `:2179-2193` (`splitPair` plan/sigs, then app/payer) | `agent_api_native.rs:789-793` | 49 | yes |
| 66 | APPLICATION_LAUNCH_BEGIN_PLAN | fnDispatch → `launchLifecycleOperatorOp` | `:6148-6177` (v4 tag first; stop and continue variants) | v3 `:448`, stop begin `:171`, v4 `:617` | 66 + plan tag | yes |
| 67 | …BEGIN_ASSEMBLE | fnDispatch | `:6179-6196` | v3 `:477`, stop `:200`, v4 `:656` | 67 + ingress tag | yes |
| 68 | …CLAIM_PLAN | fnDispatch | `:6198-6213` | v3 `:242`, stop asm `:184`, v4 `:253` | 68 | yes |
| 69 | …CLAIM_ASSEMBLE | fnDispatch | `:6215-6227` | v3 `:281`, stop asm `:224`, v4 `:292` | 69 | yes |
| 70 | …COMPLETION_PLAN | fnDispatch | `:6229-6244` | v3 `:237`, stop svc `:832`, v4 `:555` | 70 | yes |
| 71 | …COMPLETION_ASSEMBLE | fnDispatch | `:6246-6260` | v3 `:277`, stop svc `:894`, v4 `:595` | 71 | yes |
| 76 | AGENT_LIFETIME_DISPATCH_SUBMIT | serveFrame | `:2635-2636` → `dispatchAgentLifetimeSubmitSession` `:2474-` | `agent_api_lifetime_dispatch_native_v3.rs:167` | 76 + `AGENT-LIFETIME-DISPATCH-COMMITTED-PERMIT/v3` | yes |
| 78 | AGENT_LIFETIME_DISPATCH_PLAN | fnDispatch → `agentLifetimeDispatchAuthorSession` | `:2241-2253` (`requireOneLifetimeDispatchPin`) | `agent_api_lifetime_paid_native_v3.rs:147` | 78 | yes |
| 79 | AGENT_LIFETIME_DISPATCH_ASSEMBLE | fnDispatch | `:2254-2268` (nested pair, 64-byte grant) | `…paid_native_v3.rs:183` | 79 | yes |
| 152 | APPLICATION_STREAM_RENEW | serveFrame | `:2631-2632` → `:2399-2415` | `dispatch_native.rs:698` | 152 + `STREAM-CONTINUITY-ATTESTATION/v1` | yes |
| 154 | APPLICATION_ROUTE_INSPECT | serveFrame | `:2629-2630` → `:2417-2435` | `dispatch_native.rs:1277` | 154 + `ROUTE-ADMISSION-ATTESTATION/v1` | yes |
| 164 | APPLICATION_ROUTE_BOUND_DISPATCH | serveFrame | `:2627-2628` (routeBound = true) | `dispatch_native.rs:1129` | 34 + permit, or 164 + NO_RECORD | yes |

Not sent by this crate, although the shard's topic names them:

| byte | symbol | who sends it |
|---:|---|---|
| 35 | APPLICATION_DISPATCH_LOOKUP | nobody (no `invoke(35` in `native/`); historical op 35 is only mentioned in comments (`dispatch_native.rs:866-867`) |
| 47, 77 | AGENT_PAID/LIFETIME_DISPATCH_LOOKUP | nobody in spk-host (the doc at `agent_api_lifetime_v3.rs:2-3` mentions op 77 lookup) |
| 58, 59, 80, 81 | AGENT_RESERVE_PLAN/ASSEMBLE, AGENT_LIFETIME_RESERVE_PLAN/ASSEMBLE | the controller (`native/grain-runtime/src/main.rs`, comments at `:4081`, `:4176`, `:4649`) |
| 44, 45, 50-53 | older lifecycle plan/assemble ops | nobody in `native/`; `lifecycle_selector.rs:5` still lists 44/50/52 |
| 72-75 | AGENT_LIFETIME_GRANT_* | not this shard (grant issuance, `scripts/spk-platform/issue-agent-lifetime-grant.sh`) |

All 70 Host `inspect`/`author` kind strings used in the shard exist in `Host/*.lean` (checked with `grep -F` per string;
list in the scratch file `kinds.txt`). Lean's `profile` CLI matches Rust's stdout capture (`Host/Main.lean:6387-6390`).
`inspect-stop-claim` exists (`Host/Main.lean:6136`, `:6598`).

## 2.2 op 34/164 reply mapping, Lean against Rust

| Lean `ApplicationDispatchReceiver.Result` (`Kernel/ApplicationDispatchReceiver.lean:198-209`) | Host frame (`Host/Main.lean:2360-2397`) | Rust handling | marker |
|---|---|---|---|
| `permitted` (fresh CAS winner, installed) | 34 + committed permit, written inside `withFreshTip` | committed → inspection → delivery | kept until finish or release |
| `permitted` but the tip changed | 34 + outcome `uncertain` | `OutcomeBytes` → error | **kept** |
| `committed` (non-winner or recovered) | 34 + outcome `confirmed …` | `OutcomeBytes` → error | **kept** |
| `historical` (exact call already accepted) | 34 + outcome `confirmed replayed` | `OutcomeBytes` → error | **kept** |
| `noRecordRefused` (decode ok, lookup absent, admission failed, non-human origin, probe, or route mismatch; `:322-341,268-280`) | **164** + `NO_RECORD_REFUSAL` (fresh tip) | retire marker, error "refused before any Store record" | **retired** |
| `noRecordRefused` but the tip changed | 34 + outcome `uncertain` | error | **kept** |
| `rejected` (noncanonical ingress, conflicting lookup, refusal-at-tip unavailable, tx ID reused, durable `rejected`; `:276-278,299,326-334,385`) | 34 + outcome `refused operationRejected` | error | **kept** |
| `contention` | 34 + outcome `contention` | error | **kept** |
| `unavailable` | 34 + outcome `unavailable` | error | **kept** |
| `uncertain` | 34 + outcome `uncertain` | error | **kept** |
| handler threw before writing | 255 + `RequestRefusal.frame` (`Host/Main.lean:2645-2656`) | opcode 255 accepted by `invoke`, then `parse_op34_response` fails | **kept** |

Byte layout agrees: Lean's `lengthBytes` is little-endian 32-bit (`Host/Main.lean:2337-2339`), and the refusal payload
is the tag with no newline (`Compiler/PersistedCodecTags.lean:113`). The only difference is policy: Rust treats
`contention`, `unavailable` and pre-write 255 as possibly recorded (question 8.1).

## 2.3 OS facilities

- **Linux only.** Every module is `#[cfg(target_os = "linux")]` (`lib.rs`). `SO_PEERCRED` (`agent_api_native.rs:235-250`,
  `agent_api_server.rs:385-399`); `/proc/self/fd/N` exec (`dispatch_native.rs:262`); `flock`
  (`lifecycle_v3_stop_service.rs:76`); `MSG_PEEK|MSG_DONTWAIT` (`agent_api_server.rs:198-205`); non-blocking
  `AF_UNIX` connect.
- **POSIX ACL tools**: `/usr/bin/setfacl` and `/usr/bin/getfacl` (the `acl` package) for agent sockets
  (`agent_api_server.rs:104,112`). The filesystem must support ACLs.
- **systemd and cgroups**: indirectly, through hostd (`fence_and_stop_manager_checked`, `audit_stopped_manager_checked`)
  and `volume_custody` (shard B).
- **tokio**: `renew_stream` is async and uses `spawn_blocking` (`dispatch_native.rs:733-769`). Everything else is
  synchronous blocking IO.
- No SQLite, no Cap'n Proto in these files (fd 3 RPC is `rpc_adapter`, shard A), no network sockets.

## 2.4 Network services and peers

- **Operator socket** (the Unix socket of the `resource-client` socket process). It must be euid-owned, mode with no
  group or other bits, inside a 0700 euid directory (`dispatch_native.rs:377-388`).
- **Controller reverse socket** (grain-runtime). It must be owned by `controllerUid`, peer-checked by SO_PEERCRED, with
  protected ancestors (`agent_api_native.rs:212-256`).
- No outbound TCP, Solana, Discord or LLM provider from this shard.

## 2.5 File layouts and configuration (JSON protocols read)

| protocol string | struct | read from | lines |
|---|---|---|---|
| `mini-spk-human-dispatch-custody-v1` | `FixedAuthoring` | route `dispatch-custody.json` | `dispatch_author.rs:76-132` |
| `mini-spk-resident-begin-management-v1` | `FixedLaunchBeginSigners` / `FixedStopBeginSigners` / `FixedRetryBeginSigners` | `beginManagementCustody` | `lifecycle_v3_native.rs:272-292`, `stop_begin:29-49`, `v4_retry_native:436-465` |
| `mini-spk-resident-claim-management-v1` | three twins | `claimManagementCustody` | v3 claim `:60-88`, stop asm `:51-71`, v4 claim `:67-122` |
| `mini-spk-completion-management-v1` | three twins | `completionManagementCustody` | v3 completion `:45-64`, stop svc `:597-617`, v4 completion `:396-425` |
| `mini-spk-resident-stop-v3` | `StopConfig` | STOP config path | `lifecycle_v3_stop_service.rs:148-156` |
| `mini-spk-resident-start-v3` | `ResidentPins` (subset) | `residentStartConfig` | `:162-192` |
| `mini-spk-launch-qualified-v2` | `QualifiedLaunch` (twin of `resident_service.rs:398-411`) | `launchQualification` | `:269-299` |
| `mini-spk-failed-start-recovered-v1` | `RecoveredRecord` | `g{N}/failed-start-recovered-v1.json` | `v4_retry_native.rs:156-165` |
| `mini-spk-agent-dispatch-custody-v2` | `AgentCustody` | `agents[].custody` | `agent_api_custody.rs:60-175` |
| `mini-spk-agent-lifetime-custody-v3` | `LifetimeCustodyV3` | `agents[].custody` | `agent_api_lifetime_custody_v3.rs:72-176` |
| Host config `lifecycleManagement.{managementSubject, managementKeyId}` | n/a | `miniConfig` | `lifecycle_selector.rs:88-113` |

Keys and seeds: every `SignerPin.seed_path` is a 32-byte file, 0600, nlink 1, euid-owned, in an euid-owned directory with
no group or other bits (`dispatch_author.rs:257-282`). Lifecycle seeds must additionally sit below an ancestor chain the
app UID cannot rewrite (`lifecycle_selector.rs:137-144`). The completion custodian seed is checked by
`completion_custodian::preflight_custodian` (shard B).

## 2.6 Other crates

- `minidregg-signed-api-path` (`route`, `checked_prefix`, `is_under`): `dispatch_inspection.rs:179`,
  `agent_api_wire.rs:147,211`, `agent_api_lifetime_wire_v3.rs:151`, `agent_api_lifetime_v3.rs:212`,
  `agent_api_lifetime_custody_v3.rs:355`, `agent_api_server.rs:958`.
- `ed25519-dalek = "=2.2.0"`, `sha2`, `serde`, `serde_json`, `libc`, `tokio` (`Cargo.toml`).
- Peer binaries: the Lean Host (pinned) and grain-runtime (controller). The controller side of the reverse protocol is
  in `native/grain-runtime/src/main.rs` (`mark-send-v3` at `:6083-6389`, settlement at `:6470-6500`, v3 inspection at
  `:9122`) and `native/grain-runtime/src/application_api_tools.rs` (constants `PROTOCOL = "mini-spk-agent-api-v1"`,
  `LIFETIME_PROTOCOL = "mini-spk-agent-api-v3"` at `:30-31`). Both protocol generations are still present there too.

## 2.7 Reachability

| module set | reached from | run evidence |
|---|---|---|
| dispatch_* | `spk-host resident-run` (resident units: `ExecStart=… resident-bootstrap`, `broker.rs:1043`) | jspk1 rows s1-get-a, s1-post-a, s3-get-b, s1-poll-a2, s3-poll-e; `2026-10-02-spk-browser-tls` (older binaries) |
| lifecycle v3 START/INSTALL | `grain install`, `grain start`, resident START | jspk1 install, start, kill → supervise, start-a3 |
| lifecycle STOP | `spk-host resident-stop`, `grain stop`, `grain supervise` (`grain.rs:1189-1306`) | jspk1 s1-stop-a (3,062 s), s1-kill-a (2,529 s) |
| lifecycle v4 | resident START after a reconciled failed create | none recorded; `scripts/spk-platform/fixture-v4.sh` |
| agent v1 | resident config `agents[]` without `protocol` | none (wire-only gate `2026-09-27-spk-agent-api-wire`) |
| agent lifetime v3 | resident config `agents[]` with `protocol: mini-spk-agent-api-v3` | source gate only (`2026-09-27-spk-lifetime-resident-v3`: 27/27 focused tests, "no real op76/fd3 GitWeb request was executed") |
| `dispatch_native::qualification` | feature `integration-qualification` | not built by the candidate; `jspk1.sh failstart` authored, not run (README) |

---

# 3. Does it decide anything semantic?

Numbering continues from shard A's D1-D14 where the topic is the same; new items are S1-S15.

## 3.1 Decisions Rust makes, or nearly makes

| # | where | what Rust decides | Lean counterpart | blast radius if wrong | verdict |
|---|---|---|---|---|---|
| S1 | `dispatch_native.rs:1039-1048`, `:1051-1060`; `dispatch_delivery.rs:113-124`, `:172-181` | **Scope of uncertainty.** One possibly-recorded human op 34/164 fences **every** human participant of the grain generation until the generation journal's `native-dispatch-active.json` disappears, which no code does after a non-definite outcome | Lean's exactly-once unit is the signed call (`Kernel/ApplicationDispatchReceiver.lean:327-331`, `:276-278`). It requires no grain-wide pause. Agent paths use per-route markers (`agent_api_native.rs:801`) | Availability of the whole app for all members; recovery costs a STOP plus a new generation (jspk1: 3,062 s STOP, 1,128 s START) | **Rust availability policy**, not authority. Defensible as conservatism, but undocumented in Lean and inconsistent with the agent paths |
| S2 | same | Which replies prove "no Store record": only the exact NO_RECORD frame. `contention`, `unavailable` and pre-write 255 are treated as possibly recorded | `noRecordRefused` is Lean's only positive absence proof (`:203-206`). Whether `contention` or `unavailable` can follow a durable append is not stated (8.1) | Over-fencing (S1) | defers to Lean; conservative |
| S3 | `dispatch_native.rs:1068-1074`; `resident_route_control.rs:785-805` (shard A) | **op 34 vs 164**: Rust picks whether Lean checks the route constraint. A route without a seal is sent through op 34 and Lean checks no binding | `receiveRouteBoundVerified` / `routeMatches` (`Kernel/ApplicationDispatchReceiver.lean:381-386`, `:251-256`) | If Rust sent a sealed route's request as op 34, Lean would admit it under current authority (still a valid participant dispatch) and Rust's post-commit `route_binding_matches` (`dispatch_delivery.rs:207,221-225`) would refuse delivery **after** Mini recorded and billed it | Rust IS the decision about which restriction applies. The restriction is resident-local, so this grants no authority; the worst case is a recorded, undelivered dispatch |
| S4 | `lifecycle_v3_claim_native.rs:31-49,218`; `lifecycle_v3_stop_assembly_native.rs:29-47,159`; `lifecycle_v4_retry_native.rs:122-139,228`; `agent_api_native.rs:708-718`; `agent_api_lifetime_reverse_v3.rs:32-53,524` | **Native index = acceptedCount - 1** for the original BEGIN, the failed-START recovery and the agent reserve (shard A's D2 pattern in five more places) | claim: Lean selects by index and checks `acceptedCount == originalIndex + 1` (`Host/ApplicationLifecycleLaunchClaimAuthoring.lean:81,218`). v4 selector: Lean validates the selector against the recovery (`checked_retry_fields` compares the Host view). Agent reserve: Lean's op 48 plan echoes `reserveIndex`, and the committed inspection carries `purse.reserveIndex` (`agent_api_server.rs:974`) | A wrong index yields a plan refusal or a different BEGIN, then a Rust echo mismatch: fail closed | mirror, provided Lean checks (it does for the claim; see 8.3 for the reserve) |
| S5 | `lifecycle_v4_retry_native.rs:270-316`; `resident_service.rs:587-597` | **Lifecycle lane**: v4 if and only if a create, the generation is `failed + 2`, and the operator-written `failed-start-recovered-v1.json` exists and is well-formed (`type == "confirmed"` read from a local file, not re-inspected) | v3 create BEGIN refuses once the first-attempt nullifier is consumed; v4 BEGIN requires the exact accepted recovery (`Kernel/ApplicationLifecycleRetryBeginV4Admission.lean`) | Wrong lane: Lean refuses (fail closed). A forged record cannot pass Lean's selector check | mirror |
| S6 | `agent_api_custody.rs:83-84,130-133`; `agent_api_lifetime_custody_v3.rs:86-87,114-123` | **Price**: `reserveAmount` and `maximumCharge` come from operator custody JSON; Rust requires max <= reserve | The Lean Host config pins the approved fixed selectors (`agentDispatchAuthorSession … approved`, `Host/Main.lean:2134-2193`; `requireOneLifetimeDispatchPin`, `:2199-2203`). The payer (controller) must sign the payer slots | Price is operator policy enforced by Lean. Rust mismatch: Lean refuses | mirror. The settlement **charge** is the controller's `task.charge` (`grain-runtime/src/main.rs:6470,6482`), equal to `maximumCharge`. That is outside this shard; question 8.5 |
| S7 | `agent_api_server.rs:365-402`; `agent_api_custody.rs:232-280`; `agent_api_lifetime_custody_v3.rs:178-251` | **Who may drive the agent API, and custodial signing**: any process with `controllerUid` that can open the ACL'd socket makes the resident sign **app-slot** (and grant-slot) headers for any HTTP request that passes the wire parser. The controller adds payer signatures | Lean admits the event21/event26 dispatch against the agent session's grants, parent task, purse and the payer signature. It cannot tell that the resident, not the agent principal, signed the app slots | Controller UID compromise: arbitrary paid requests within the agent's grants, billed to the purse (which the controller holds anyway) | **design-level delegation decided in Rust**, the agent analogue of shard A's D1. No Lean declaration records "resident signs app slots on behalf of controller UID X" |
| S8 | `agent_api_custody.rs:285-340`; `agent_api_lifetime_custody_v3.rs:253-298` | **Is this payer signature acceptable**: Rust verifies Ed25519 against pinned public keys before op 49/79 | Op 49/79 assemble and op 46/76 admission should verify (8.6) | Rust too strict: refusal. Too lax: Lean refuses | mirror if Lean verifies |
| S9 | `lifecycle_receipt_lookup.rs:61-78`; `lifecycle_v3_native.rs:504`; `lifecycle_v3_completion_native.rs:142-169`; `lifecycle_v3_stop_service.rs:978-990`; `dispatch_native.rs:1463-1472` (feature) | **Is this receipt confirmed**: `type == "confirmed"` plus confirmation, read from JSON | The JSON is produced by the hash-pinned Lean Host's `inspect outcome` run locally on bytes Rust captured from its own invoke. It is Lean's decoding, not a peer's claim | Only if the Host image pin were bypassed (F4 is the one place it partly is) | defers (no signature is needed: Lean is the parser) |
| S9b | `agent_api_native.rs:313-346`; `agent_api_lifetime_reverse_v3.rs:494-614` | Controller-supplied reserve receipts accepted from JSON | v3: the reserve request and plan bytes are re-inspected by the pinned Host. v1: only the request bytes are re-authored and compared. Both: the final committed inspection's `purse.originalReceipt` / `reserveReceipt` must equal them (`agent_api_server.rs:975-978`; `…dispatch_native_v3.rs:187-190`) | A lying controller gets a Lean refusal at op 48/46 | mirror |
| S10 | `agent_api_server.rs:568-571,649-663`; `agent_api_lifetime_server_v3.rs:305-319` | **Operation identity for agent dispatch** is the controller's forward operation ID, used as Mini's HTTP operation ID and as hostd's `DispatchIdentity.operation_id`. Humans use the resident's fsynced allocator (`dispatch_delivery.rs:143-145`) | Lean's call identity is the signed ingress. hostd's one-shot key is (app, generation, session, session generation, operation ID) | A controller reusing an ID: `agent-client-op-<id>` already exists (create fails) and hostd refuses the same key. Fail closed | physical identity, third allocator (shard A found two) |
| S11 | `lifecycle_v3_stop_service.rs:1122-1164` | an op66-only STOP BEGIN is discarded | ops 66-71 are pure plans (`Host/Main.lean:6148-6262`) | none | correct |
| S12 | `dispatch_delivery.rs:128-142` with `web_socket::Limits` (shard A D4) | WebSocket open cap per size class | none (K-SPK intends a Lean pin) | quota without a Lean record | shard A D4, reached here |
| S13 | `lifecycle_v3_stop_native.rs:323`; `lifecycle_v3_stop_service.rs:1191-1202` | the root volume's resource ID must equal the Mini app resource | Lean's STOP running witness carries `volumeIdHex` and `physicalWitnessHex` but no volume resource (`:219-235`) | Wrong convention: STOP refuses (fail closed) | Rust convention (8.7) |
| S14 | `agent_api_server.rs:30`; `agent_api_lifetime_server_v3.rs:37`; `dispatch_delivery.rs:23-24` | Response caps (64 KiB agent, 8 MiB human) and a 30 s app call time | none | a large reply becomes an uncertain operation after delivery | physical policy |
| S15 | `agent_api_lifetime_reverse_v3.rs:459,512`; `resident_service.rs:1205-1212` | `controllerWorkerWallSeconds` pinned in resident config and echoed by the controller | unknown whether the Lean lifetime grant bounds wall time (8.8) | timeouts only | physical policy |

## 3.2 Places that correctly defer to Lean

- **Every lifecycle plan is Host-authored and Host-inspected before Rust signs.** Rust signs only slot headers whose
  role/index/key match an operator pin (`lifecycle_v3_native.rs:133-177`, `dispatch_author.rs:176-254`). The signer
  key ID must equal the Host-config `lifecycleManagement.managementKeyId` (`lifecycle_selector.rs:129-136`).
- **Physical launch authority** (`hostd::VerifiedBegin`) is built only from a fresh op26 committed callback
  (`lifecycle_v3_claim_native.rs:429-474`, `lifecycle_v4_retry_claim_native.rs:380-434`), never from a lookup.
- **STOP target** comes only from the Host's `inspect-stop-claim` verified view (`lifecycle_v3_stop_native.rs:117-240`).
- **Delivery authority** for humans is the fresh op 34/164 permit, inspected and matched to the HTTP bytes
  (`dispatch_inspection.rs:190-344`). For agents it is the fresh op 46/76 permit, inspected and matched
  (`agent_api_server.rs:906-1052`, `agent_api_lifetime_v3.rs:428-543`).
- **Physical attestations** (report, stop audit) are Rust observations signed by the custodian key and re-checked by
  Lean's report validators. That is the correct boundary (shard A D14).
- **Lookups never authorize**: `RecoveredReceipt`, `RecoveredLaunchCompletion` and `VerifiedSettlementV3` cannot
  construct a permit (doc comments `lifecycle_receipt_lookup.rs:80`, `lifecycle_v3_completion_native.rs:135`; types have
  no path to `VerifiedBegin` or `CommittedDispatch`).

---

# 4. Flaws noticed

Severity is for the near goal: a small public demo of one SPK app.

## 4.1 Lost reply, retry and availability

**F1 (high): any non-definite op 34/164 outcome bricks human dispatch for the whole generation until STOP.**
`submit_once` creates `<journal>/native-dispatch-active.json` (`dispatch_native.rs:1039-1048`). It retires it only on
the exact NO_RECORD frame (`:1055-1059`) or after `RecordedDispatch::finish` / `release_uncertain` (`:804-822`). A Lean
`contention`, `unavailable`, `rejected` (for example "dispatch transaction identity already used"), tip-changed
`uncertain`, a historical `confirmed replayed`, a 255 refusal, or a socket timeout leaves the marker, and
`deliver_once` refuses every member before authoring (`dispatch_delivery.rs:113-124`). No function anywhere in the
crate removes a retained marker: the only `remove_file` on it is `retire_active_marker` (`dispatch_native.rs:984-996`);
`grep native-dispatch-active` finds only `hostd.rs:1039` (which refuses checkpoint) and tests. The checkpoint/backup
path then also refuses (`hostd.rs:1032-1062`). The generation journal is replaced only by a STOP and a new START.

*Scenario:* the demo app is busy; another writer in the same Store advances the tip between admission and CAS. Lean
returns `contention`. Every visitor now gets "SPK dispatch uncertain; exact recovery required" until the operator
STOPs and STARTs (jspk1 measured 51 min for STOP and 19 min for START, rows s1-stop-a and s1-start-a3).

*Fix direction (not a quick fix):* ask Lean which outcomes are definite no-append (8.1) and narrow the global marker to
the shared physical slot, which hostd already guards with `dispatch-active.json`.

**F2 (high, agent paths): a fenced agent route still consumes a reserve on every new call.** v1 `authorize_once`
asks the controller to reserve (`agent_api_native.rs:687-688`, which leads to Mini writes by the controller) and runs
op 48 and op 49 (`:746`, `:789`) **before** trying to create the route marker with `create_new` (`:801-805`). If a
previous op 46 was uncertain, the marker exists, so this call fails only after the reserve. v3 does the same: reserve
(`agent_api_lifetime_server_v3.rs:253-265`), ops 78/79 (`:276-285`), then the marker in `submit_fresh_once`
(`agent_api_lifetime_dispatch_native_v3.rs:152-157`). Each retry by an agent locks more purse funds in reserves.
Whether reserves expire or refund is a Lean question (8.2). The fix is to check the route marker before the reserve.

**F2b (high on a small VM): attempt directories are never collected.** Every HTTP request creates
`<journal>/dispatch-op-N/` holding `request.json` (body as hex, about 2x body), `plan.bin`, `plan.json`,
`ingress.bin`, `committed-payload.bin` and `inspection.json` (whose own bound is 96.8 MB, `dispatch_native.rs:27`)
(`:868-930`, `:1132-1140`). Nothing in the shard removes them; only the continuity and route-admission probe
directories are removed (`ContinuityAttemptDir::drop`, `:596-600`). A 1 MiB upload leaves several MiB. The agent paths
keep `agent-client-op-*` and `agent-dispatch-op-*` the same way. The journal is the evidence store by design, but
there is no retention policy and no bound, so disk use is unbounded per generation.

**F3 (high, agent API enabled only): the resident event loop is single-threaded and agent handling blocks it.**
`resident_service.rs:1936-2140` handles human HTTP, route control, checkpoint, app-exit and agent sockets in one
closure. Agent `poll_once` (`agent_api_server.rs:319-361`, `agent_api_lifetime_server_v3.rs:98-128`):
- blocks in `read_frame` for up to 30 s (`agent_api_wire.rs:17,282-293`) on a connected controller that sends nothing;
- runs `getfacl` on every accept (`agent_api_server.rs:384`);
- then runs the full reserve, plan, assemble and submit chain. Every Host call has a 600 s deadline (`dispatch_native.rs:29`),
  and the lifetime `reverse_timeout` applies only to controller exchanges.

Meanwhile no human request, route registration or app-exit event is serviced. Worse, `accept_authenticated` returns
`Err` on socket mode or inode drift, a `getfacl` spawn failure, or an ACL mismatch (`:371-384`). `poll_once`
propagates it with `?` (`:320`, `agent_api_lifetime_server_v3.rs:102`), the closure propagates it with `?`
(`resident_service.rs:2116`, `:2138`), and the generation ends. *Scenario:* the controller's host runs out of PIDs for
a moment; `Command::new("/usr/bin/getfacl").output()` fails; the resident exits and the app is down until the
supervisor's STOP and continue.

**F4 (medium): `inspect-stop-claim` runs the Host by path, with no deadline.**
`lifecycle_v3_stop_claim_native.rs:279-293`, `lifecycle_v3_stop_native.rs:523-536` and
`lifecycle_v3_stop_service.rs:369-383` call `Command::new(&operator.host)…status()`. Unlike `tool_until`, this
(a) execs the path rather than the verified descriptor, so the hashed-inode guarantee of `dispatch_native.rs:392-396`
does not hold between `pinned_config()` and exec; (b) has no timeout, so a Host blocked on a Store lock hangs STOP
forever (and `grain supervise`, which calls STOP); (c) is outside the `tool_until` command allowlist (`:427-433`).
`inspect_original` also reads the output with an unbounded `fs::read` before checking the 2 MiB bound
(`lifecycle_v3_stop_service.rs:384-387`).

**F5 (medium): a lost op 22 or op 26 reply during STOP wedges the app Running with no tool path.**
The STOP BEGIN keeps `op22-requested.json` and `lifecycle-stop-begin-v3-active.json`
(`lifecycle_v3_stop_begin_native.rs:170,213-217`). The STOP claim keeps `op26-requested.json` and
`lifecycle-stop-claim-v3-active.json` (`lifecycle_v3_stop_claim_native.rs:248-259`). On the next `resident-stop` the
journal is still Running, `set_aside_pure_begin` does nothing (later markers exist), and `run` refuses with "STOP prior
attempt on Running journal requires audit" (`lifecycle_v3_stop_service.rs:1220-1234`). Unlike START (v3 and v4 have
`recover_begin_receipt_only` / `recover_claim_receipt_only`, wired at `resident_service.rs:1056` and nearby), STOP has
no op 23/27 lookup and no resume path short of Fenced. Mini may hold an admitted STOP BEGIN or claim (app phase 5 or
10), so a new STOP BEGIN would presumably also refuse. *Scenario:* on a small VM a single Host call exceeds the 600 s
`RESPONSE_DEADLINE`. jspk1's STOP took 3,062 s overall and we do not know the per-op split (8.9).
`invoke_until` returns `TimedOut`, the app keeps running, and neither `grain stop` nor `grain supervise` can proceed.

**F6 (medium, law 10 "refusal must be loud"): Lean's refusal reasons are dropped.**
`tool_until` sends the helper's stderr to `/dev/null` (`dispatch_native.rs:465`); the error is the constant "pinned Mini
Host helper refused". `author_signed_ingress` checks `plan_reply[4] != 36` and `ingress_reply[4] != 37` before writing
the frame (`:891-894`, `:923-926`), so a 255 refusal frame carrying `RequestRefusal.frame` text is neither retained nor
logged. `probe_continuity` and `admit_resident_route` reduce every op 152/154 refusal to one string (`:702-706`,
`:1281-1285`). The lifecycle files are better: they write `opNN-frame.bin` before parsing
(`lifecycle_v3_native.rs:449,478,494`).

**F7 (medium): the v1 agent server reports refusals as uncertainty.** `poll_once` turns every `handle_once` error,
including pre-attempt validation such as a bad path, a binding mismatch or a binding read failure, into
`Uncertain { phase: "retained-attempt" }` (`agent_api_server.rs:342-355`). `inspect_state` reports `uncertain` for
**every** operation ID, including unseen ones, while the route marker exists (`:774-777`). The controller cannot
distinguish "nothing happened" from "audit required". The v3 server closes the socket instead (`:117-127`). The two
generations disagree.

**F8 (low): one 600 s deadline per Host call, and per helper process.** `RESPONSE_DEADLINE` (`dispatch_native.rs:29`)
applies per `tool()` and per `invoke()`. Human dispatch shares one deadline for authoring (`:1089`) but uses a fresh
600 s for the committed inspection (`:1135-1140`). A single HTTP request can hold the resident for up to about 20 min in
the worst case while every other member waits (F3 applies to humans too: `deliver_once` is synchronous in the same loop).

## 4.2 Bounds, memory and performance

**F9 (medium): memory spikes from whole-JSON inspections.** `read_bounded(…, MAX_INSPECTION = 96.8 MB)`
(`dispatch_native.rs:494-501`) is parsed by `serde_json::from_slice` into a `Value` (`dispatch_inspection.rs:203`).
For an 8 MiB body the inspection holds `frameHex` and `bodyHex` (each more than 16 MB) plus headers, so a few hundred MB
RSS is plausible in the resident during one request. On a 2-4 GB VM, two concurrent large uploads to two apps could
OOM. Lean bounds the same JSON at `8 * maxFrame` (`Host/Main.lean:2320-2322`).

**F10 (medium): Host process churn.** Each HTTP request spawns at least 4 Host processes (`author` request, `inspect`
plan, `signatures`, `inspect` committed; plus `author` route-bound for sealed routes) and makes 3 socket calls
(36, 37, 34/164). Each WebSocket renewal (default lease 60 s, shard A) spawns 4 more and makes 3 calls (36, 37, 152)
per open socket. The Host image is 159 MB (`dispatch_native.rs:1915`). jspk1 GET took 35-47 s end to end (rows
s1-get-a, s3-get-b), most of it probably Host work. On a small VM this is the throughput ceiling.

**F11 (low): fsync volume.** `write_new` fsyncs the file and the directory for every artifact (`:55-70`): about 10-12
fsync pairs per HTTP request, plus hostd's.

## 4.3 Correctness and code quality

**F12 (low): v1/v3 header and control-character rules disagree.** `agent_api_wire::control_free` allows TAB
(`:37-45`); `agent_api_lifetime_wire_v3::control_free` refuses it (`:37-41`). Lean's `cleanTransportText` refuses only
NUL, LF and CR (`Kernel/ApplicationDispatchAdmission.lean:122-124`). Both are stricter than Lean (fail closed), but a
header valid on one route is refused on the other.

**F13 (low): `dispatch_inspection::app_route_path` does not reject dot segments on the Browser route**
(`:157-183`); only `Api` delegates to `signed_api_path::route`. `../admin` reaches the signed request and the app.
Lean does not refuse it either (`requestSafeFor`, `:154-180`). Authority does not depend on paths in Sandstorm (bits
do), so this is an app-namespace concern, not a Mini authority hole (8.10).

**F14 (low): the config TOCTOU between hash and helper.** `check_pin` hashes the config bytes (`:373-376`), but the
helper child receives the config **path** (`:450`) and re-reads it. A concurrent rewrite by the same UID would run
the helper under a different config than the one pinned. `invoke` sends the hashed bytes, so the socket path is safe.

**F15 (low): file-mode and symlink inconsistencies.**
- `native-agent-dispatch-active.json` is created without `.mode(0o600)` or `O_NOFOLLOW` (`agent_api_native.rs:802-805`;
  `create_new` still refuses an existing symlink). Its lifetime twin sets 0600 (`agent_api_lifetime_dispatch_native_v3.rs:153-157`).
- `read_inspection` (`lifecycle_v3_stop_claim_native.rs:138-156`) checks `symlink_metadata`, then `File::open`
  without `O_NOFOLLOW` and without a mode check.
- `image_path_metadata` checks mode but not owner (`dispatch_native.rs:268-274`).

**F16 (low): the seed copy is not zeroized.** `private_signing_key` reads into a stack `[u8; 32]`
(`dispatch_author.rs:279-281`) that is not cleared. `SigningKey` zeroizes on drop (ed25519-dalek 2.2 default
`zeroize`). Seeds are re-read from disk for every signature (11 call sites), which is fine for custody but costs IO.

**F17 (low): two STOP recovery readers diverge.** `resume_fenced_exact` (`lifecycle_v3_stop_native.rs:463-569`) and
`inspect_original` (`lifecycle_v3_stop_service.rs:312-414`) re-implement the same retained-artifact verification with
different readers (`read_private_artifact` versus `read_private`) and different output reads (bounded versus unbounded).

**F18 (info): panics on untrusted input.** None found. Every `unwrap()` on parsed data is guarded:
`agent_api_custody.rs:132-133` (by the preceding `is_none()` checks), `agent_api_native.rs:56` (length checked),
`:775` and `agent_api_server.rs:73,538` (hex validated first), `agent_api_lifetime_v3.rs:50` (validated),
`agent_api_lifetime_custody_v3.rs:123` (decimal checked earlier in the chain). `unreachable!()` at
`agent_api_server.rs:526,595` and `agent_api_lifetime_server_v3.rs:204` follow a matched variant.

## 4.4 Keys, logs and arguments

- No key material is put in argv or env. The helper argv carries only paths and kinds (`dispatch_native.rs:449-464`).
- The only stderr output in the shard is `"spk-host: websocket open refused: …"` (`dispatch_delivery.rs:132-137`) and
  `"spk-host: stream continuity refused or unavailable; lease ended"` (`dispatch_native.rs:765`). No secrets.
- Attempt directories retain full request bodies, cookies (as signed ordinary headers) and app responses
  (`definite.json`, `app-response-v3.bin`) indefinitely, in operator-private 0700/0600 files. On a public demo these are
  user data at rest with no retention policy (F2b).

---

# 5. Unwired and undone

## 5.1 `#![allow(dead_code)]`: 23 of 29 files, almost all stale

| file:line | comment | reality |
|---|---|---|
| `dispatch_native.rs:4` | "Resident authorized supervisor is not enabled yet." | wired via `resident-run`; ran in jspk1 |
| `dispatch_author.rs:5` | "Joined operator broker/supervisor route is in progress." | wired |
| `dispatch_inspection.rs:4` | "The private signer/op34 invocation is not linked yet." | wired |
| `dispatch_delivery.rs:4` | "Lifecycle-v2/SPK binding and resident service not enabled yet." | wired |
| `lifecycle_v3_native.rs:4` | "The v3 lifecycle caller is still source-gated." | wired (`install_v3`, `resident_service`) |
| `lifecycle_v3_claim_native.rs:4` | "Awaiting the physical v3 lifecycle caller." | wired |
| `lifecycle_v3_report_native.rs:3` | "Physical INSTALL/START caller awaits linked v3 Host and STOP." | wired |
| `lifecycle_v3_completion_native.rs:4` | "Awaiting v2 report Host route and physical caller." | wired; hides the dead `number()` (`:31-41`) |
| `lifecycle_v3_stop_begin_native.rs:2`, `_assembly:2` | "Awaiting the callable STOP supervisor cut." | wired via `lifecycle_v3_stop_service::run` |
| `lifecycle_v3_stop_claim_native.rs:6` | "The callable STOP supervisor is a later, separate cut." | wired; hides six unused accessors (`:115-135`) |
| `lifecycle_v3_stop_native.rs:4` | (none) | wired |
| `lifecycle_v4_retry_completion_native.rs:7` | "The op39 arm is reached only by operator recovery." | `recover_receipt_only` is called automatically on restart (`resident_service.rs:1056`) |
| `agent_api_wire.rs:6`, `agent_api_custody.rs:4`, `agent_api_native.rs:3`, `agent_api_server.rs:4` | "Resident listener is enabled only with the reverse v2 reserve client" / "server remains disabled" | wired behind `agents[]` with `protocol` absent; never configured by `grain` |
| `agent_api_lifetime_{v3,reverse_v3,custody_v3,paid_native_v3,dispatch_native_v3,wire_v3}.rs:3-4` | "enabled in a later cut" / "wired separately" | wired behind `agents[]` with protocol v3 (`resident_service.rs:2118-2138`); the server file itself has no allow |

Removing these attributes would surface the real dead items below at compile time.

## 5.2 Dead code inside wired files

| item | lines | evidence |
|---|---|---|
| `lifecycle_v3_completion_native::number` | `:31-41` | no caller (`grep 'number('` hits only other files' own `number`s) |
| `FreshStopClaim::{stop_plan, original_begin, claim_ingress, committed_frame, inspection, begin_receipt, claim_receipt}` | `lifecycle_v3_stop_claim_native.rs:115-135` | only `target()` is called (`lifecycle_v3_stop_native.rs:396`) |
| `CommittedAgent::{permit, attempt_dir}` reads | `agent_api_native.rs:634-643` | fields written, `permit` used; `attempt_dir` never read outside construction |
| `RecordedDispatch::test_new` | `dispatch_native.rs:786-799` | `#[cfg(test)]`, used by `hostd.rs` tests |
| `PrivateContinuityReply` being `pub` | `dispatch_native.rs:348-364` | public "only for the package's standalone fd3 smoke binary" (`gitweb-session-smoke`, run by nothing per shard A) |
| `V3_LAUNCH_REQUEST_TAG`, `retry_request_bytes` | `lifecycle_v4_retry_native.rs:37-39,321-339` | `#[cfg(test)]` expectation builders |
| `dispatch_native::qualification` | `:1311-1857` (544 lines) | feature-only; the candidate passes no features; journey rows authored, never run |
| whole agent v1 path | 4 files | reachable only by a hand-written resident config; never configured by tooling; never executed |

## 5.3 Tests that do not test what they claim

| test | problem |
|---|---|
| `dispatch_native.rs:2371-2385` `native_submit_marker_is_create_new_and_blocks_a_second_attempt` | exercises `write_new`'s `create_new`, not `submit_once` (that is covered elsewhere at `:2097-2276`) |
| `lifecycle_v3_completion_native.rs:582-658` `retained_completion_recovery_requires_exact_originals_and_submit_marker` | the last block writes `op38-requested.json` and asserts it reads back equal (`:646-656`); `recover_receipt_only` is never called |
| `lifecycle_v4_retry_completion_native.rs:776-781` `retry_v4_completion_ingress_tag_is_distinct_from_v2` | `assert_ne!` of two string constants: a tautology |
| `lifecycle_v4_retry_native.rs:745-801`, `v4_retry_claim:529-534`, `v4_retry_completion:742-773` | check the Rust StreamCodec encoder against byte vectors written by the same author; no test feeds a Lean-encoded frame. The Lean `StreamCodec` is the only authority, and nothing pins agreement except a live Host |
| `lifecycle_v3_native.rs:802-823` | tests `hold_begin_attempt` (`create_new`) only |
| `agent_api_native.rs:871-881` | `assert!(!OUTCOME.starts_with(COMMITTED))`: constants |
| all lifecycle and dispatch unit tests | use `/usr/bin/true` or JSON fixtures for the Host. No test in the shard runs a Lean Host. The only end-to-end evidence is the journey (jspk1) |

## 5.4 Twins (law 13: delete the twin)

| twin set | sites | reachable | keep / delete |
|---|---|---|---|
| retained private-file reader | `lifecycle_receipt_lookup.rs:30-56` (`retained`), `lifecycle_v3_completion_native.rs:316-342` (`retained_file`), `lifecycle_v3_stop_native.rs:408-438` (`read_private_artifact`), `lifecycle_v3_stop_claim_native.rs:138-156` (`read_inspection`), `lifecycle_v3_stop_service.rs:94-132` (`read_private`), `agent_api_server.rs:844-865` (`read_private_recovery`), `dispatch_native.rs:44-53` (`read_bounded`), `dispatch_native.rs:1334-1356` (qualification `private_read`) | all reachable | keep one (`read_private` is the strictest), delete 7 |
| receipt-only lookup | `lifecycle_receipt_lookup::lookup_retained` vs `lifecycle_v3_completion_native::recover_receipt_only` (`:448-489`) vs `lifecycle_v3_stop_service::complete_once_or_lookup` lookup half (`:1092-1112`) | all | keep `lookup_retained` |
| acceptedCount-1 | `lifecycle_v3_claim_native::previous_index` `:31-49`, `lifecycle_v3_stop_assembly_native::previous_index` `:29-47` (verbatim), `lifecycle_v4_retry_native::decimal_predecessor` `:122-139`, `agent_api_lifetime_reverse_v3::index_precedes_count` `:32-53`, `agent_api_native.rs:708-718` (u128) | all | one function |
| later-decimal | `lifecycle_v3_claim_native::later_decimal` `:51-56`, `agent_api_lifetime_dispatch_native_v3::later_count` `:29-32` | both | one |
| `verified_physical_begin` | `lifecycle_v3_claim_native.rs:476-518`, `lifecycle_v4_retry_claim_native.rs:436-478` (identical) | both | one |
| `checked_assembled` (claim) | v3 claim `:520-542`, v4 claim `:480-502` | both | one, parameterised by marker and file names |
| BEGIN author/assemble/submit | `lifecycle_v3_native::submit_once` `:413-529`, `lifecycle_v3_stop_begin_native::submit_once` `:130-247`, `lifecycle_v4_retry_native::submit_once` `:553-702` | all | one engine (6.2) |
| CLAIM plan/assemble | v3 `:208-294`, STOP `:146-229`, v4 `:195-305` | all | one engine |
| CLAIM submit | v3 `:429-474`, STOP `lifecycle_v3_stop_claim_native.rs:192-313`, v4 `:380-434` | all | one engine |
| physical report | v3 `lifecycle_v3_report_native.rs:189-309`, v4 `lifecycle_v4_retry_completion_native.rs:254-378`, STOP `lifecycle_v3_stop_service.rs:485-593` (+ retained `:619-740`) | all | one |
| COMPLETION assemble | v3 `:173-289`, v4 `:482-607`, STOP `:761-899` | all | one |
| management custody structs | `FixedLaunchBeginSigners`, `FixedStopBeginSigners`, `FixedRetryBeginSigners`; three claim; three completion. All have the same four fields and one `validate` | all | one struct + protocol tag |
| `inspect-stop-claim` exec | `lifecycle_v3_stop_claim_native.rs:281-290`, `lifecycle_v3_stop_native.rs:524-533`, `lifecycle_v3_stop_service.rs:370-379` | all | one `tool_until` command |
| STOP retained re-verification | `resume_fenced_exact` `:463-547` vs `inspect_original` `:312-414` | both | one |
| completion retry rule | `install_v3.rs:621-629` (re-send the same op38 bytes when unmarked) vs `lifecycle_v3_stop_service.rs:949-976` (replan when unmarked) | both | pick one rule |
| `QualifiedLaunch` | `lifecycle_v3_stop_service.rs:269-299` vs `resident_service.rs:398-436` | both | one |
| Unix connect with deadline | `dispatch_native::connect_deadline` `:88-194` vs `agent_api_native::connect_cancelled` `:349-462` | both | one (add a cancel flag) |
| frame-reply parsers | `lifecycle_v3_native::framed_payload` `:102-116`, `agent_api_native::reply` `:54-62`, `agent_api_lifetime_paid_native_v3::source_payload` `:24-32`, `agent_api_lifetime_dispatch_native_v3::source_payload` `:34-42`, `native_dispatch::parse_op34_response` (shard A) | all | one |
| `pair` | `agent_api_native.rs:64-71`, `agent_api_lifetime_paid_native_v3.rs:34-41`, inline pairs in 9 lifecycle sites and `dispatch_native.rs:919-922` | all | one |
| decimal-digest ↔ LE bytes | `dispatch_inspection::digest_nat_bytes` `:81-98` (canonical-checked), `agent_api_server::digest_nat` `:79-96` (not canonical-checked), `dispatch_native::digest_decimal` `:955-974` (reverse), `stream_continuity::digest` (shard A) | all | one pair of functions |
| hex/unhex/decimal/text/invalid helpers | `fn invalid`/`refused`/`refuse` in **29/29** files; `fn hex` in 13; `unhex`-family in 9; `decimal` in 11; `field`/`text`/`string` in 11; lower-hex in 6 | all | one module |
| header allowlist (Lean `ordinaryHeaderName`) | `agent_api_wire.rs:77-99`, `agent_api_lifetime_wire_v3.rs:43-65` here; shard A's `http_entrance.rs:415-436`, `dispatch_web_input.rs:332-381` | all | emit from Lean or keep one Rust copy generated from it |
| agent wire, custody, signing, reverse client, server | v1 (`agent_api_{wire,custody,native,server}`) vs lifetime v3 (`agent_api_lifetime_*`): `sign_slots` ≈ `sign_app_slots`, `verify_payer_slots` ×2, `PayerPin` ×2, `Request`/`Reply` ×2, `inspect_state` ≈ `inspect_saved`, `http_reply` ≈ `http_reply_v3`, `match_committed` ≈ `matched_v3` + `match_committed_inspection` | v1 not configured by tooling | delete v1 after hoisting the shared listener, frames and transport |
| Rust StreamCodec | `lifecycle_v4_retry_native.rs:80-119,239-256,347-355,387-396`; `v4_retry_claim:57-62`; `v4_retry_completion:217-251,385-391` versus Lean `Compiler/Tower256ConcreteBackend.lean` `StreamCodec.nat`/`bytesStream` | production checks | delete; compare Host inspections as v3 does |

## 5.5 Versioned siblings still present

- **Lifecycle v3 and v4** both live because Lean has two lanes (1.9). The Rust v4 files are line-by-line copies of v3
  with extra Rust codec checks.
- **Completion "v2"** names inside v3: `lifecycle-completion-v2-active.json`, `completion-v2.bin`,
  `LIFECYCLE-COMPLETION-INGRESS/v2`, physical report v2. The v3 lane consumes the v2 completion kernel
  (`Kernel/ApplicationLifecycleCompletionV2*.lean`).
- **Agent API v1 and lifetime v3** (1.11). The controller side keeps both constants too
  (`grain-runtime/src/application_api_tools.rs:30-31`).
- **Lean side**: `Kernel/ApplicationLifecycleClaim{,V2,V3}*`, `…Completion{,V2}*` and `…RetryV4*` all present. Opcodes
  44/45/50-53 (older lifecycle plan and assemble) are active in the registry with no Rust sender (question 8.11).

## 5.6 Stale documents

- `deploy/spk-host/MINI-CLAIM-DISPATCH-CONTRACT.md:1-7,101-105` says the "Rust parser and endpoint connection are
  therefore intentionally unavailable" and "Mini's Host opcodes or a production HTTP route [do not] already exist".
  False: ops 34/36/37/164 are wired and ran in jspk1.
- `HTTP-CUSTODIAN-CONTRACT.md` (shard A found the signer and native delivery described as "unimplemented").
- `docs/evidence/2026-09-27-spk-agent-api-wire/README.md` describes a frame "only" with no socket. The listener now
  exists.
- `lifecycle_selector.rs:5` lists ops 44/50/52.
- `docs/SPK-LIFECYCLE.md:109-110` ("authored only … no module has been compiled") is older than commits
  `374549d4`…`304b976e` that compiled and wired v4.
- `docs/evidence/2026-09-27-spk-resident-mixed-route/README.md` cites `journey.sh prepare-resident`. `journey.sh` no
  longer has that verb (`grep prepare-resident scripts/spk-platform/journey.sh` finds nothing).

---

# 6. Size and shape

## 6.1 Lines per file, grouped

| group | files | lines | test | code |
|---|---:|---:|---:|---:|
| human dispatch | 4 | 3,869 | 982 | 2,887 (of which 544 is the feature-only qualification module and its tests) |
| lifecycle shared + START/INSTALL v3 | 6 | 3,113 | 900 | 2,213 |
| lifecycle STOP v3 | 5 | 3,154 | 411 | 2,743 |
| lifecycle v4 retry | 3 | 2,255 | 274 | 1,981 |
| agent v1 | 4 | 3,386 | 749 | 2,637 |
| agent lifetime v3 | 7 | 4,171 | 1,054 | 3,117 |
| **total** | **29** | **19,948** | **4,370** | **15,578** |

Tests are 21.9% of the shard by the "last `#[cfg(test)]` to EOF" rule (per file in the header table). Four files have
no tests at all (`lifecycle_receipt_lookup.rs`, `lifecycle_v3_stop_begin_native.rs`, plus near-zero in
`lifecycle_v3_stop_assembly_native.rs` 12 lines and `lifecycle_v4_retry_claim_native.rs` 27 lines). The lifecycle
family's one-shot and lookup code is unit-tested mostly through marker and JSON fixtures, never against a Host (5.3).

## 6.2 Duplication inside the lifecycle family (item 2: count and estimate)

All 14 lifecycle files are one pattern:

```
[selector-framed] author request → (inspect request) → durable prepare marker (attempt + parent create_new)
→ invoke PLAN → retain frame → inspect plan → compare 15-30 fields → sign pinned slots → `signatures` tool
→ LE32 pair → invoke ASSEMBLE → retain ingress → durable submit marker → invoke SUBMIT → retain frame
→ inspect committed/outcome → compare → typed result;   lookup = same ingress, LOOKUP op, `replayed`
```

Near-duplicate instances:

| step | v3 | STOP | v4 | shared lines per instance (estimate) |
|---|---|---|---|---:|
| BEGIN author/plan/assemble/submit | `v3_native:413-529` (117) | `stop_begin:130-247` (118) | `v4_retry_native:553-702` (150) | ~70 |
| BEGIN plan checks | `v3_native:293-378` (86) | `stop_begin:85-124` (40) | `v4_retry_native:466-547` (82) | ~30 |
| CLAIM plan/assemble | `v3_claim:208-294` (87) | `stop_assembly:146-229` (84) | `v4_claim:195-305` (111) | ~65 |
| CLAIM plan checks | `v3_claim:90-181` (92) | `stop_assembly:97-141` (45) | `v4_claim:124-179` (56) | ~40 |
| CLAIM fresh submit + committed check | `v3_claim:296-474` (179) | `stop_claim:158-313` (156) | `v4_claim:308-434` (127) | ~70 |
| `verified_physical_begin` + `checked_assembled` | `v3_claim:476-542` (67) | – | `v4_claim:436-502` (67) | 67 |
| physical report | `v3_report:57-309` (253) | `stop_service:432-593` (162) + retained `:619-740` (122) | `v4_completion:96-378` (283) | ~120 |
| COMPLETION plan/assemble | `v3_completion:173-289` (117) | `stop_service:761-899` (139) | `v4_completion:482-607` (126) | ~90 |
| COMPLETION submit + lookup | `v3_completion:386-489` (104) | `stop_service:1050-1113` (64) | `v4_completion:635-735` (101) | ~45 |
| custody structs (begin/claim/completion) | 3 | 3 | 3 | ~20 each |
| retained readers | 1 | 3 | 0 (uses shared) | ~25 each |
| `inspect-stop-claim` exec + retained re-verify | – | 3 execs + 2 re-verifies | – | ~95 |
| helpers (`invalid`, `hex`, `unhex`, `decimal`, `text`, …) | | | | ~8 per file × 14 |

Removable by one parameterised engine: about 2 × (70 + 30 + 65 + 40 + 70 + 120 + 90 + 45) = 1,060 from the three
skeleton copies, plus 67 (identical v4 helpers), 160 (custody structs), 125 (readers), 95 (STOP exec and re-verify),
about 110 (helpers), and about 120 (the v4 Rust StreamCodec, deleted rather than shared). **About 1,700 of the
lifecycle family's 6,937 code lines (about 25%)**, plus about 200 test lines that test the copies. That is
**about 1.5K net** after the engine's own size (about 200).

Across families: the agent v1/v3 overlap is roughly 1,800 code lines (delete v1, 6.3). The dispatch family has small
twins only (`connect_cancelled`, `digest_nat`, `pair`, frame parsers: about 200).

## 6.3 A minimal version for the demo (item 6)

The demo needs: install, start, supervise (including STOP and continue), stop, and human browser and API dispatch of
**one** SPK app. It does not need the agent API (nothing configures it; README lists no agent-to-SPK row; Hermes is
off on the public node).

| cut | files dropped | lines removed (this shard) | other edits needed | consequence |
|---|---|---:|---|---|
| A. agent API, both generations | `agent_api_wire`, `agent_api_custody`, `agent_api_native`, `agent_api_server`, `agent_api_lifetime_v3`, `…_reverse_v3`, `…_custody_v3`, `…_paid_native_v3`, `…_dispatch_native_v3`, `…_server_v3`, `…_wire_v3` | **7,557** | `lib.rs` mods (11); `resident_service.rs` (`FixedAgentConfig`, `PreparedAgent`, `agents[]` validation `:1153-1241`, preflight `:1456-1510`, bind `:1891-1917`, poll `:2097-2138`); `hostd.rs:8` + `finish_dispatch_recovered` (`:1440-1549`) + test at `:1920`; grain-runtime's controller side (other shard) | no paid agent dispatch to SPK apps |
| B. integration-qualification race fixture | `dispatch_native.rs:1311-1857` | **544** | `cfg(feature)` hooks at `dispatch_native.rs:1087-1088,1117-1128`, `dispatch_delivery.rs:272-285`, Cargo feature | the authored `jspk1.sh failstart` rows lose their trigger |
| C. v4 retry (optional) | `lifecycle_v4_retry_native`, `…_claim_native`, `…_completion_native` | **2,255** | `resident_service.rs` `StartLane::RetryV4` and `retry_v4_*` (about 300 lines, shard B) | a failed **first** CREATE leaves the app un-recreatable (v3 refuses forever); recovery is a new app birth |
| D. dedupe the remaining lifecycle (6.2) | none (merge) | **≈1,300** (without v4: about 1,100) | | none |
| E. dead items (5.2) | | **≈60** | | none |

**Totals (this shard only).** A+B+E remove **8,161 lines (41%)**, leaving about 11.8K. Adding C: **10,416 (52%)**.
Adding D: about **11.5K removed (58%)**, leaving about 8.4K lines for dispatch + v3 lifecycle + STOP, of which
about 2.6K would be tests. The kept files are `dispatch_native.rs` (minus qualification), `dispatch_author.rs`,
`dispatch_inspection.rs`, `dispatch_delivery.rs`, `lifecycle_selector.rs`, `lifecycle_receipt_lookup.rs`,
`lifecycle_v3_native.rs`, `lifecycle_v3_claim_native.rs`, `lifecycle_v3_report_native.rs`,
`lifecycle_v3_completion_native.rs` and the five STOP files, collapsed by D into roughly four modules (author engine,
START steps, STOP steps, dispatch).

---

# 7. Deployability on a small public Linux VM

## 7.1 What must exist on the box for this shard's code to run

- The **pinned Lean Host binary** (about 159 MB) and its config, both hash-pinned in the resident config
  (`miniHost`, `miniHostSha256`, `miniConfig`, `miniConfigSha256`, `resident_service.rs` / `ResidentPins`
  `lifecycle_v3_stop_service.rs:179-183`). It is executed often (F10). Disk and RAM headroom for many concurrent Host
  processes is needed: each human request spawns 4-5.
- The **operator socket process** (`resource-client` socket) listening on `miniOperatorSocket`, in a 0700
  operator-owned directory, socket mode 0600 (`dispatch_native.rs:377-388`). It must serve version-2 envelopes with the
  same config bytes and Host SHA (`transport.rs:173-217`).
- **Key files** (32-byte, 0600, nlink 1, in 0700 operator directories): the participant/route signer seeds named by
  each route's `dispatch-custody.json` (`dispatch_author.rs:65-72`); the begin, claim and completion management seeds
  (`lifecycle_selector.rs:118-147`, whose key ID must equal the Host config's `lifecycleManagement.managementKeyId`);
  the completion custodian seed (`completionCustodianSeed`). Agent API, only if enabled: app seeds, the grant seed, payer
  public keys.
- **Ledgers and journals**: `begin-operation-ledger`, `claim-nonce-ledger` and the attempt directories under each
  generation journal (`grain.rs:1103-1112`). These grow without bound (F2b).
- **For the agent API only**: `/usr/bin/setfacl` and `/usr/bin/getfacl` (the `acl` package), a filesystem with POSIX
  ACLs, a distinct controller UID, and the controller's reverse socket.
- systemd user manager, cgroup v2, bubblewrap and the broker: shard A and B prerequisites. This shard uses them through
  hostd and volume custody.

## 7.2 What the operator configures

- Resident config (`grain start` writes it, `grain.rs:1060-1125`): Host pins, socket, custody paths, ledgers, attempt
  directories, `entrances[]` (human routes), `agents[]` (always `[]` from `grain`), `wsAuthorityLeaseSeconds`.
- STOP config `mini-spk-resident-stop-v3` (`grain.rs:1189-1209` writes it).
- Management custody JSONs (`mini-spk-resident-begin-management-v1`, `…-claim-…`, `mini-spk-completion-management-v1`)
  with selector and signer pins.
- Human route custody `mini-spk-human-dispatch-custody-v1` per route (shard A, `grain_route.rs`).
- Agent custody (v2 or v3), including **prices** (`reserveAmount`, `maximumCharge`), which must also be pinned in the
  Lean Host config (`Host/Main.lean:2129-2268`).
- The Host config itself: `lifecycleManagement`, agent fixed selectors.

## 7.3 What is dangerous to expose, and to whom

- **Nothing in this shard listens on a network.** The human path is reached only through shard A's `http.sock`
  (same-UID) and `spk-browser-proxy`. The agent socket is an ACL'd Unix socket for one UID.
- **A stranger on the internet** reaches this code only through an exposed browser proxy with a valid route cookie
  (shard A). Without a cookie, nothing in this shard runs.
- **A holder of a route cookie (a member, or anyone who stole one)** can:
  - make the host sign and submit arbitrary Lean-admissible requests as the participant (shard A D1). Every request
    costs Mini events, 4-5 Host processes, about 10 fsyncs, and permanent journal bytes, so **a member can fill the disk**
    (F2b) and **saturate the Host** (F10) with ordinary requests;
  - open WebSockets up to the class cap, each costing a full Host authoring round per lease renewal (F10);
  - with a large body (up to 8 MiB), push the resident to hundreds of MB of RSS per request (F9);
  - trigger F1 indirectly: any request whose op 34 yields `contention` or `unavailable` fences **all** members until the
    operator STOPs and STARTs. A member cannot force contention directly; the Store's other writers do. Concurrent
    lifecycle or other Mini traffic on the same Store raises the odds.
- **A compromised or buggy controller (agent API enabled)** can stall the whole resident for 30 s per connection
  (F3), crash the generation via an ACL or socket drift error path (F3), drive the resident to sign app and grant slots
  for any parseable request (S7), and drain the purse through reserves on a fenced route (F2).
- **The operator** is fully trusted: they hold every seed, can rewrite custody, and attest physical facts that Lean
  cannot check (shard A D14).

## 7.4 Recommendations specific to this shard, for the demo

1. Do not enable the agent API (keep `agents: []`); better, cut it (6.3 A).
2. Before exposing the app, settle F1 with the Lean side. At minimum, add an operator command that, after a Host lookup
   proves absence or presence, clears `native-dispatch-active.json`. Today the only remedy is STOP plus START.
3. Add a retention bound for `dispatch-op-N/` (for example, move proven-Delivered attempts to a compressed archive, or
   keep only markers, frames and receipts, and drop request.json and inspection.json bodies) before any public traffic.
4. Give `inspect-stop-claim` the same descriptor-pinned, deadline-bounded execution as `tool_until` (F4), and add a
   STOP op 23/27 lookup path (F5) so a slow VM cannot wedge STOP.
5. Measure per-op Host latency on the target VM size against `RESPONSE_DEADLINE = 600 s` (8.9).

---

# 8. Questions for the Lean side

Each is phrased to be answered by pointing at a declaration.

8.1 **op 34/164 definite outcomes.** In `Kernel/ApplicationDispatchReceiver.receiveAdmitted` (`:262-306`), can
`.contention` or `.unavailable` from `DurableReceiverIO.receiveLoadedDetailedWithFresh` be returned **after** a durable
append of this dispatch? If they are proven no-append, could the Host answer them with the positive
`noRecordRefused` frame, so that Rust can clear its generation marker instead of fencing all members? The same question
applies to `.rejected "dispatch transaction identity already used"` (`:276-278`) and to a handler exception answered
with 255 by `serveFrame` (`Host/Main.lean:2645-2656`): can a 255 follow a Store write?

8.2 **Agent reserves after a fenced route.** For event21 (`Kernel/ApplicationDispatchAgent*`, ops 58/59 at the
controller) and event26 (ops 80/81), does an unconsumed reserve expire, refund, or stay locked? Which declaration states
the reserve's lifetime? (F2: every retry on a fenced agent route creates a new reserve.)

8.3 **Agent reserve index.** Does `ApplicationDispatchAgentPaidAuthoring.preparePaidVerified` (op 48) check that
`request.reserveIndex` selects the record whose receipt `acceptedCount == reserveIndex + 1`, as
`ApplicationLifecycleLaunchClaimAuthoring` does for the claim (`:81`, `:218`)? Rust enforces this relation in
`agent_api_native.rs:708-718` and `agent_api_lifetime_reverse_v3.rs:524`.

8.4 **Digest byte order.** `dispatch_native::digest_decimal` (`:955-974`) renders a 32-byte session fingerprint as a
decimal Nat reading the bytes little-endian, and `dispatch_inspection::digest_nat_bytes` (`:81-98`) inverts it. Which
declaration fixes the byte order of `ApplicationStreamContinuity.Binding.sessionFingerprint` / the route constraint's
`Digest` when the Host authors `application-route-bound-dispatch` from JSON? (Shard A asked the same question for
`stream_continuity.rs:22-39`.)

8.5 **Settlement charge.** For lifetime dispatch, the controller settles with `charge = task.charge`
(`grain-runtime/src/main.rs:6470,6482`), equal to `maximumCharge`. Which Lean declaration decides the charged amount
for an event26 dispatch: is it always the pinned `maximumCharge`, or a metered amount? Does the settle receiver refuse a
charge above `maximumCharge`?

8.6 **Payer signatures.** Do `ApplicationDispatchAgentPaidAuthoring.assemblePaid` (op 49) and
`ApplicationAgentLifetimeDispatchPaidAuthoring.assemblePaid` (op 79), or the op 46/76 receivers, verify the payer
Ed25519 signatures against the purse's enrolled keys? Rust verifies them first (`agent_api_custody.rs:285-340`,
`agent_api_lifetime_custody_v3.rs:253-298`). If Lean verifies, these Rust checks are pure UX.

8.7 **Volume resource equals app resource.** `lifecycle_v3_stop_native.rs:323` requires the root volume's resource ID
to equal the Mini app resource, and the stop service requires `pins.volume_resource` to match. Is there a Lean
declaration that binds the app's volume resource to the app resource, or is this purely a Rust and broker naming
convention?

8.8 **Worker wall time.** Does the event27 lifetime grant or the event26 dispatch carry a wall-time bound that
`controllerWorkerWallSeconds` (`agent_api_lifetime_reverse_v3.rs:459,512`) should mirror, or is it controller-only
policy?

8.9 **Operator deadline against Host latency.** jspk1 measured STOP at 3,062 s and START at 452-1,128 s end to end
(rows s1-stop-a, s1-start-a, s1-start-a3). What is the expected per-operation latency of ops 22, 26, 38 and 66-71 on a
Store of jspk1's size? Rust times out each operation at 600 s (`dispatch_native.rs:29`) and treats a timeout as
uncertain, which for STOP has no lookup path (F5).

8.10 **Dot segments.** `Kernel/ApplicationDispatchAdmission.requestSafeFor` (`:154-180`) does not refuse `..` path
segments for human (Browser) dispatch. Is that intended, given that Sandstorm WebSession paths are app-relative?
Should the path normal form be a Lean predicate, so that Rust's `app_route_path` (`dispatch_inspection.rs:157-183`)
mirrors it?

8.11 **Unused lifecycle opcodes.** `protocol/host-operations.json` lists 44, 45, 50, 51, 52 and 53 (older lifecycle
plan/assemble, owner `spk-lifecycle`) as `active`. No Rust sender exists in `native/`. Are their `fnDispatch` arms
reachable for any client, or can they be retired with their Lean modules (`Kernel/ApplicationLifecycleClaim{,V2}*`,
`…Completion{,V2}*` if superseded)?

8.12 **Rust StreamCodec copies.** `lifecycle_v4_retry_native.rs:80-119` re-encodes `StreamCodec.nat` and
`bytesStream` (`Compiler/Tower256ConcreteBackend.lean:151-206,291-293`) to cross-check Host-authored v4 request,
selector, report and signed-report frames. Does every v4 `inspect` kind already echo the fields Rust compares
(`retrySelectorHex`, `canonicalRequestHex`, report and signing frame), so that these Rust encoders can be deleted in
favour of inspection comparisons, as the v3 lane does?

8.13 **Generation-wide fence.** Is there any Lean-side reason why one participant's uncertain op 34 should stop other
participants of the same app generation from dispatching? If not, the fence scope (S1) can be reduced to the shared
physical slot without a Lean change.

8.14 **STOP after a lost op 22/26.** If a STOP BEGIN (op 22) or STOP claim (op 26) was admitted but its reply was lost,
which Lean-admissible next step continues it? Is op 23/27 lookup on the retained ingress sufficient to recover the
receipt (as for START), and does `inspect-stop-claim` accept a plan whose claim was recovered by lookup rather than by a
fresh op 26 callback? (The Rust STOP path requires the fresh callback, `lifecycle_v3_stop_claim_native.rs:96-99`.)
