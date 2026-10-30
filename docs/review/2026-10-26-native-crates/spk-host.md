# spk-host: crate synthesis

| field | value |
|---|---|
| Crate | `native/spk-host` (package `minidregg-spk-host`): "Physical Linux custody and sandbox launch for Sandstorm SPK grains" (`Cargo.toml:7`) |
| Date | 2026-10-26 |
| Inputs | shard A `spk-host--A-hostd-http-routes.md` (entry points, hostd, HTTP entrance, routes, RPC adapter, install); shard B `spk-host--B-grain-sandbox-broker.md` (grain CLI, sandbox, seccomp, broker, resident service, materialize, volumes, descriptors); shard C `spk-host--C-lifecycle-agent-api-dispatch.md` (lifecycle v3/v4, agent API v1 and lifetime v3, dispatch) |
| Spot checks by this synthesizer | `wc -l` of `src/**/*.rs` = 54,698 (equals A+B+C); `dispatch_delivery.rs:105-124` (the fence); every `native-dispatch-active` reference in `src/`; `dispatch_web_input.rs:330-381` against `Kernel/ApplicationDispatchAdmission.lean:112-124`; op 35 in `protocol/host-operations.json:411-420`. Nothing was built or run |
| Stance | rescue and repair first. DELETE is used only for true twins whose better twin is kept, dead code with no surface, and routes the sibling lane disowned |

## Executive summary

spk-host is 54,698 lines of Rust (about 24% tests) in 9 binaries that install, launch, sandbox, route, stop and recover Sandstorm SPK apps under Mini authority. It is the physical half of the week-1 EtherCalc grain on `calc.demo.dregg.online`.

The authority boundary is mostly right. Every HTTP request and WebSocket open is admitted by Lean (ops 36, 37, then 34 or 164) before any byte reaches the app. Every lifecycle step is authored, admitted and confirmed by Lean. Every lost reply becomes a lookup, never a resend. All 27 operation bytes checked agree with `protocol/host-operations.json` and the Lean receivers.

These are the findings that matter for the demo:

1. **Custodial signing.** The host holds the participant's seed and signs as that participant whenever the static cookie authenticates. With edge cookie injection, every stranger signs as `guest`. No Lean declaration records the delegation.
2. **The dispatch fence.** One non-definite op 34/164 outcome fences every participant of the grain. No code clears the fence, so recovery is STOP plus a new generation, measured at 19 to 51 minutes. Lean does not require this scope.
3. **A compromised resident is the operator of the whole world.** It holds every seed and every grain's broker. The resident unit has no filesystem hardening.
4. **The sandbox floor is unmeasured.** The audit cannot run against the production spawn path.
5. **Availability collapses on any crash.** Any accept, poll or auxiliary-fd error, an app exit, or one missing fd-3 ACK ends or poisons the generation. After three supervisor failures in 30 minutes the grain stays down.
6. **Throughput and disk.** jspk1 measured 35-47 s per GET, with 4-5 Host processes per request. Per-request journal directories are never collected. All strangers share one subject, capped at 2 pending and 16 waiting requests.
7. **Twins.** There are four hand-written Rust copies of Lean's header allowlist and nine copies of one lifecycle skeleton. The agent API is a dead-in-practice v1 beside a never-run v3.

DELETE today: about 4.9K lines, plus `spk-browser-proxy` (840) once Caddy terminates. REPAIR by merging: about 2K. The rest is RESCUE or PARK (section 5).

---

## 1. What it is and does

### 1.1 Module map (line counts from the shards' tables; total 54,698)

| family | modules (lines) | shard |
|---|---|---|
| Binaries | `main.rs` spk-host 276; `mini-spk-broker` 35; `mini-spk-volume-helper` 9; `spk-hostd` 42; `spk-browser-proxy` 840; `spk-sandbox-probe` 417; `spk-smoke` 146; `gitweb-smoke` 590; `gitweb-session-smoke` 312; `gitweb-human-journey` 912 | A §1.2 |
| Physical journal | `hostd.rs` 3,268 (1,352 test): per-generation durable record, phases Armed→LaunchRequested→Entered→Running→Fenced→Stopped, dispatch tombstones. It is a library, not a daemon (A §1.3) | A |
| HTTP entrance | `http_entrance.rs` 2,249 (+208 gitweb probe); `http_response.rs` 606; `web_socket.rs` 906; `stream_continuity.rs` 375; `dispatch_web_input.rs` 742; `native_dispatch.rs` 100 | A §1.4-1.11 |
| Routes | `grain_route.rs` 582; `resident_route_control.rs` 1,056; `route_admission.rs` 236 | A §1.9 |
| fd 3 driver | `rpc_adapter.rs` 1,673 | A §1.10 |
| Install | `install_service.rs` 317 + `install_v3.rs` 914 (one feature in two files) | A §1.12 |
| OS seam | `os.rs` 176; `fixture_os.rs` 713 (feature `fixture-os`); `namespace_identity.rs` 175; `operation_ledger.rs` 171; `endpoint.rs` 314 | A §1.13 |
| Grain CLI | `grain.rs` 1,702; `grain_export.rs` 858; `grain_management.rs` 147; `grain_profile_upgrade.rs` 640 | B §1.11-1.12 |
| Sandbox | `sandbox.rs` 539; `seccomp.rs` 561 (+ `seccomp/resident-web.policy` 110); `setid_bound.rs` 353; `spawn_gate.rs` 824; `resident_launch.rs` 683; `resident_privilege.rs` 689 | B §1.7 |
| Resident | `resident_service.rs` 2,665; `checkpoint_control.rs` 470; `export_receipt.rs` 276 | B §1.8-1.10 |
| Broker and root | `broker.rs` 1,434 + `broker_endpoint` 311, `broker_runtime_adoption` 693, `broker_home` 267, `broker_volume_custody` 455, `broker_checkpoint` 222; `volume_helper.rs` 364 (+ bash `spk-var-volume` 325); `volume_custody.rs` 382 | B §1.2-1.4 |
| Descriptors | `materialize.rs` 478; `descriptor_native.rs` 227; `launch_descriptor_native.rs` 621; `claim_descriptor.rs` 310 (dead); `completion_custodian.rs` 78 | B §1.5-1.6 |
| Human dispatch | `dispatch_native.rs` 2,386 (of which 544 is the feature-only race fixture); `dispatch_author.rs` 450; `dispatch_inspection.rs` 594; `dispatch_delivery.rs` 439 | C §1.1-1.4 |
| Lifecycle v3 | selector 190; receipt lookup 159; BEGIN 824; CLAIM 903; report 378; COMPLETION 659; STOP: begin 247, assembly 259, claim 357, native 796, service 1,495 | C §1.5-1.7 |
| Lifecycle v4 retry | 923 + 550 + 782 | C §1.8 |
| Agent API | v1: wire 443, custody 379, native 1,094, server 1,470; lifetime v3: 7 files, 4,171 | C §1.10-1.11 |

### 1.2 Binaries, and what runs them (A §2.6)

| binary | shipped by candidate | run by |
|---|---|---|
| `spk-host` | yes | resident units rendered by the broker, the supervisor unit, `jspk1.sh`, `journey.sh`, `spk-ingest` |
| `mini-spk-broker` | yes | `mini-spk-broker@.service` (a **user** unit, `NoNewPrivileges=no`) |
| `mini-spk-volume-helper` | yes | root, via sudoers from `install-user-world` |
| `spk-browser-proxy` | yes | `ws-continuity-launch.py:274` only |
| `spk-hostd` | yes ("shipped, not installed by default", `deploy/candidate/build.sh:12`) | **nothing** |
| `spk-sandbox-probe` | no | `sandbox-floor-audit.sh` (broken, B F2) |
| the three smokes and `gitweb-human-journey` | no | nothing since 2026-09-27, apart from one `#[ignore]` test |

### 1.3 Wire formats

- **Host operator wire** (C §1.1): an LE32-framed envelope `[0x02][LE32 cfg_len][cfg][SHA-256 of Host ELF, 32 raw][op][payload]` on an owner-private Unix socket served by `resource-client` (`dispatch_native.rs:508-579`; `transport.rs:173-217`).
  - Helper CLIs (`author`, `inspect`, `signatures`, `profile`) execute the hashed inode as `/proc/self/fd/N` (`dispatch_native.rs:255-264`, `:449`).
  - Three `inspect-stop-claim` calls exec the Host **by path with no deadline** (C F4).
- **HTTP/1.1 entrance** on per-route Unix `http.sock` (mode 0600, `SO_PEERCRED` uid == euid at `http_entrance.rs:1100`). One request per connection, `Connection: close`, 64 KiB head, 8 MiB body, 10 s deadline.
  - Transfer-Encoding, Expect, Content-Encoding, every duplicate header and every `x-sandstorm-*` header are refused.
  - Headers off the allowlist are silently dropped (A §1.4).
- **Custodian files.** `custodian.json` (`mini-spk-custodian-v1`) plus three 256-bit tokens: bootstrap, browser cookie `__Host-mini_spk_session`, and API bearer (`http_entrance.rs:306-377`).
- **Operator-private control sockets.** Route control is LE32 + JSON with a 16 KiB cap. Checkpoint control is LE32 + JSON with a 4 KiB cap. The broker speaks one JSON line per connection with a 16 KiB cap and 12 verbs (A §1.9, B §1.2, §1.9).
- **Agent sockets.** BE32 + JSON: v1 snake_case, v3 camelCase. The reverse controller socket also uses BE32 (C §1.12). The Host wire is LE, so the crate uses both endiannesses.
- **Volume witness.** The 13-line `DREGG/SPK-VAR-CUSTODY/v1`, written by root bash and read by the resident (B §1.3.3, §1.4).
- **Audits for Lean.** `mini-spk-failed-start-audit-v1` (18 fields) and the STOP audit (10 fields). Both agree exactly with `Host/ApplicationFailedStartRecoveryTools.lean:54-72` and `Host/Json.lean:2992-3013` (A §2.1.4-2.1.5).

### 1.4 Sockets, files, environment, ports

- **TCP.** The only listener is `spk-browser-proxy` on `127.0.0.1:<port>`: TLS 1.3, X25519MLKEM768 only, 136 threads (A §1.5). Nothing makes outbound network calls.
- **Root state.** `/etc/mini-spk-volumes/<store>.json`, `/etc/sudoers.d/mini-spk-<store>`, and `/var/lib/mini-spk-worlds/<store>/` (root 0755) holding volumes, vars, attest and `host-identity` (B §1.13).
- **Operator state.** `<store>/host/apps/<app>/{routes,g<N>,custody,...}` and `broker/`. Each generation journal accumulates `dispatch-op-N/` directories without bound (C F2b).
- **Environment.** `MINI_SPK_{APP,OPERATOR}_{UID,GID}`, `MINI_SPK_GRAINS_ROOT|STORE|UNIT|BROKER_SOCKET|BWRAP{,_SHA256}` (resident), `SUDO_UID` (helper) and `INVOCATION_ID`.
- **External binaries.** The pinned bwrap, newuidmap/newgidmap, systemctl, systemd-run, sudo, bash, mkfs.ext4, e2fsck, debugfs, setpriv, fallocate, setfacl/getfacl (agent only) and the Lean Host (B §1.13, C §1.13).

---

## 2. What it assumes of its surroundings

### 2.1 Matched vocabulary

Every operation byte the crate sends is `status: active, routes: ["operator"]` in the registry, and the reply each side expects agrees with the Lean arm (A §2.1.1, B §2.1, C §2.1). None is public, so spk-host needs the operator socket and never public ingress.

| family | ops | evidence |
|---|---|---|
| human dispatch | 36, 37, 34, 164, 152, 154 | C §2.1-2.2: the 34/164 opcode crossing and the NO_RECORD frame (`Compiler/PersistedCodecTags.lean:113`) match `Host/Main.lean:2353-2397` |
| lifecycle | 22/23, 26/27, 38/39, 66-71 (v3, v4 and STOP share opcodes; Lean routes by codec tag) | C §2.1; `framed_payload` matches `splitPair` |
| failed-START recovery | 206-209 | B §2.1.2: framing, tags, outcome v6, "absent" lookup and confirmation labels agree. The same-bytes resubmit after "absent" is safe through Lean's `stableNullifier` (`Kernel/ApplicationFailedStartRecoveryIngress.lean:51-63`) |
| agent | 46, 48, 49 (v1); 76, 78, 79 (v3) | C §2.1. The controller runs 58/59 and 80/81 |
| Host tools | about 70 `author`/`inspect` kind strings, all present in `Host/*.lean` (C §2.1) | |

### 2.2 Mismatched or one-sided vocabulary

- **Active in Lean, never sent by Rust**:
  - **op 35 `APPLICATION_DISPATCH_LOOKUP`** (`host-operations.json:411-420`). No `invoke(35` exists in `native/` (C §2.1). This is the missing piece for repairing the fence (section 4.2).
  - ops 47 and 77 (agent lookups);
  - ops 44, 45 and 50-53 (older lifecycle). `lifecycle_selector.rs:5` still lists 44/50/52 (C §2.1, Q8.11).
  - 200 and 203-205 are unallocated. 201 and 202 belong to resource birth (A §2.1.2).
- **v3-only on both sides.** Failed-START recovery decodes only v3 ingress, in Rust (`grain_export.rs:455-480`) and in Lean (`Tools.lean:96-101`). A failed v4 START cannot be reconciled (B F4).
- **Byte order to confirm with Lean.** Rust renders the 32-byte `sessionFingerprint` and digests as decimals read **little-endian** in several places: `stream_continuity.rs:22-39`, `dispatch_native.rs:955-974`, `dispatch_inspection.rs:81-98` and `hostd.rs:585-602`. Rust round-trips them only against itself (A Q3, C Q8.4).

### 2.3 Rust-only vocabulary, and hand copies of Lean data

- **The header allowlist** has four Rust copies of `ordinaryHeaderName` (`Kernel/ApplicationDispatchAdmission.lean:115-120`, 18 names):
  - `http_entrance.rs:415-436` (filter; others silently dropped);
  - `dispatch_web_input.rs:332-381` (projection match arms; others refused);
  - `agent_api_wire.rs:77-99`;
  - `agent_api_lifetime_wire_v3.rs:43-65`.

  A counts "three" (Lean plus the two human-path copies, A §5.4) and C counts "five" (C exec. summary item 13). I verified four Rust sites. The sibling's "three hand copies" is the human path: Lean plus two Rust copies. The agent cut removes the other two. On control characters: v1 allows TAB, v3 refuses it, and Lean's `cleanTransportText` refuses only NUL, LF and CR (C F12).
- **Rust StreamCodec.** v4 re-encodes Lean's `StreamCodec.nat` and `bytesStream` to cross-check Host frames (`lifecycle_v4_retry_native.rs:80-119` and claim/completion siblings; C §1.8, Q8.12).
- **API-path rule.** `signed_api_path::checked_prefix` is a twin of `ApplicationSpkPackageIdentity.validApiPrefix`. Lean re-checks it, so it is a mirror (B §2.1.3).
- **About 21 retained-marker protocols** `mini-spk-*-requested-v{1,3,4}` (C §1.12), plus the broker, custodian, route, checkpoint, placement, profile and agent JSON protocols. All are operator-local evidence, not Lean data.
- **Size classes.** `broker::CLASSES` (`broker.rs:37-90`): memory, CPU, tasks, IO, `/var` size, WebSocket caps. No Lean declaration exists. K-SPK is promised and grep finds nothing (B S1).

---

## 3. Does it decide anything semantic?

Ranked by blast radius. Physical enforcement in Rust is correct throughout; the question is who chooses.

| rank | decision Rust makes | where | Lean counterpart | blast radius | verdict |
|---|---|---|---|---|---|
| 1 | **Custodial signing (identity binding).** The host holds the participant seed and signs every authenticated request as that participant. For agents, the resident signs app-slot and grant-slot headers for whatever the controller UID sends | `grain_route.rs:198-222`, `:28-35` (A D1); `agent_api_server.rs:365-402`, `agent_api_custody.rs:232-280` (C S7) | **none found.** Lean cannot tell host-signed from member-signed (A Q8, C S7) | The cookie *is* a signing key, permanent and unrotatable (A §4.1 #1). With week-1 edge cookie injection, every stranger acts as `guest` under all of guest's grants | design-level delegation decided in Rust. It needs a Lean "custody mode" field |
| 2 | **SPK package identity.** Signature validity and app id are decided by `sandstorm-package`, a git dependency on the repo being replaced (`Cargo.toml:31`) | `materialize.rs:236-283` (B S2) | `ApplicationSpkPackageIdentity` stores `signedAppId` and `manifestSha256` as opaque fields | A parser bug lets a forged package carry another app's id into the descriptor | identity decided in Rust. Lean could verify the Ed25519 signature over the manifest hash (B Q8) |
| 3 | **Quota.** Memory, CPU, tasks, IO weight, `/var` bytes, WebSocket count and bytes per minute come from the operator's `--class` flag, retained only in operator JSON | `broker.rs:37-90`, `:884-919`; `web_socket.rs:401-416`; `grain.rs:1394` (A D4, B S1, C S12) | none (K-SPK absent) | each member's share of the box | **violation**: the numbers are policy |
| 4 | **Uncertainty scope (availability).** One possibly-recorded human op 34/164 fences every participant until STOP | `dispatch_native.rs:1034-1060`; `dispatch_delivery.rs:113-124`, `:172-181` (C S1, S2) | Lean's exactly-once unit is the signed call (`Kernel/ApplicationDispatchReceiver.lean:327-331`, `:276-278`). Nothing needs a grain-wide pause | the whole grain, 19-51 minutes per incident | Rust availability policy, not authority. Section 4.2 |
| 5 | **Which restriction Lean checks.** op 34 (no route constraint) or op 164 (route-bound) is chosen by whether the route carries a seal | `dispatch_native.rs:1068-1074`; `resident_route_control.rs:785-805` (C S3) | `routeMatches` (`ApplicationDispatchReceiver.lean:251-256`, `:381-386`) | worst case: a dispatch that is recorded and billed but refused for delivery after commit | grants nothing, but Rust is the decision |
| 6 | **Archive provenance.** The import exporter key comes from the command line. `stopReceiptSha256` is never compared. One key signs raw export JSON and Lean frames with no domain separation | `grain_export.rs:113-114`, `:138-207` (B S3, F6, F7) | `ApplicationGrainExport` is promised and absent | an imported `/var` seeds a new resource with any bytes signed by any key the operator names | violation, documented as pending |
| 7 | **Restart policy.** Auto STOP plus continue-START, at most 3 per 1,800 s | `grain.rs:1261-1310`; `broker_runtime_adoption.rs:457-460` (B S6) | each STOP and BEGIN is admitted; the rate is not law | Mini writes and funds, if restarts cost (B Q11) | operational. Name it in law if restarts are funded |
| 8 | **Price.** `reserveAmount` and `maximumCharge` come from custody JSON | `agent_api_custody.rs:83-84` (C S6) | the Host config pins the same selectors (`Host/Main.lean:2134-2193`). The settlement charge is chosen by the controller (`grain-runtime/src/main.rs:6470`) | agent purse | mirror. Charge is Q8.5 |
| 9 | **Index inferences** `acceptedCount - 1`: route issue index, continue `createdIndex`, claim original index, v4 recovery index, agent reserve index | `grain_route.rs:184` (A D2); `grain.rs:1049-1062` (B S4); `lifecycle_v3_claim_native.rs:31-49` plus four copies (C S4) | the claim is checked by Lean (`ApplicationLifecycleLaunchClaimAuthoring.lean:81`, `:218`). Route issue index, `createdIndex` and reserve index are unknown (A Q1, B Q4, C Q8.3) | fails closed if Lean checks | mirror, conditional |
| 10 | Smaller items | next generation number `max+1` (B S5); lane choice v3/v4 from local files (C S5); `volume_resource == app` (C S13); ids capped at 18 digits (B S10); a third operation-ID allocator, controller-chosen for agents (C S10); physical audits trusted on the custodian signature (A D14) | mostly mirrors | fail closed | fine. Q9 asks for the id bound |

Places that correctly defer to Lean:

- Per-request authority: identity and permission bits come only from Lean's `matched` (`dispatch_web_input.rs:297-300`).
- Route registration requires a fresh op 154 (`resident_service.rs:2024-2050`).
- Stream renewal requires op 152 (`stream_continuity.rs:179-221`).
- `VerifiedBegin` is built only from a fresh op 26 callback (C §3.2).
- The launch command is selected by Lean digest (`resident_launch.rs:317-351`).
- Lookups never authorize (C §3.2).
- No fail-open authority path was found in any shard.

---

## 4. Flaws with concrete failure scenarios, ranked

### 4.1 A compromised resident is the world operator (critical for hosting strangers)

**The facts** (B F1):

- The resident runs as the operator UID in a user namespace on the **host mount namespace** (`namespace_identity.rs:155`).
- Its only syscall filter denies namespace calls (`resident_privilege.rs:51-110`).
- `broker_home::render` always returns `""`, so no `ProtectSystem` or `ProtectHome` drop-in is ever written (`broker_home.rs:202-208`, `broker.rs:1071-1076`).
- It parses app-controlled Cap'n Proto on fd 3.

**What follows.** A parser bug reached from a sandboxed app yields:

- every seed: management, completion custodian, every participant (`grain.rs:212-213`);
- the broker, which trusts peer uid == operator (`broker.rs:1218`), so Stop, Start, Unmount and Backup for every grain;
- the Mini operator socket;
- direct `sudo mini-spk-volume-helper` **Destroy** of any volume, a verb the broker never sends (`volume_helper.rs:288-315`, B F8).

A adds that every route's token files are operator-readable, so Hermes or Discord must never share that UID (A §7.3).

**Scenario.** A stranger finds an EtherCalc RCE, escapes nothing in the bwrap floor but hits a bug in the resident's fd-3 Cap'n Proto handling, and owns the world's keys.

**Repair.** Short term (S): render real hardening in `broker_home` (`ProtectSystem=strict`, `ProtectHome=tmpfs`, `BindReadOnlyPaths=`, `InaccessiblePaths=`, `SystemCallFilter=`). Long term (L): a per-grain resident UID, which needs K-SPK key splitting (B F1).

### 4.2 The dispatch fence: one uncertain dispatch fences the whole grain (high; named high-value repair)

**What the fence is.** It is a generation-wide marker file, `<journal>/native-dispatch-active.json`, plus hostd's physical slot `<journal>/dispatch-active.json`.

**Where it is set.** `dispatch_native::submit_once` writes the per-attempt `dispatch-op-N/submit-requested.json` (`create_new`). It then writes the same bytes to the generation journal's `native-dispatch-active.json` (`create_new`, `O_NOFOLLOW`, 0600, file and parent fsynced) **before** invoking op 34 or 164 once (`dispatch_native.rs:1034-1049`; C §1.1).

**Where it is checked.** `ResidentHuman::deliver_once` refuses **every** request from **every** participant before any authoring while either file exists (`dispatch_delivery.rs:113-124`, verified). The comment states the intent: "so all members see the fence without creating extra evidence".

- Errors after submit become `Interrupted` "SPK native outcome uncertain" (`:172-181`).
- The entrance maps `Interrupted` to 503 `{"status":"uncertain","retry":"exact-recovery-only"}` (`http_entrance.rs:883-897`).
- Checkpoint and backup also refuse (`hostd.rs:1032-1062`).

**Where it is cleared** (C §1.1, F1; verified by grep, the only `remove_file` is `retire_active_marker`, `dispatch_native.rs:984-996`):

- (a) the exact `NO_RECORD_REFUSAL` frame (`:1051-1060`);
- (b) `RecordedDispatch::finish` or `release_uncertain` after a committed permit (`:804-822`).

Every other Lean outcome leaves the marker forever: `contention`, `unavailable`, `rejected`, tip-changed `uncertain`, historical `confirmed replayed`, a 255 refusal or a socket timeout (C §2.2). No command clears it, and the generation journal is replaced only by STOP plus START.

*The shards disagree here.* A says the fence holds "until operator recovery or a matching fence" (A §4.2 #7). C shows that no operator recovery path exists for an uncommitted outcome. I pick C, because the grep confirms it. `hostd::finish_dispatch_recovered` exists but takes an agent-only `VerifiedSettlementV3` (`hostd.rs:1440-1549`), so no human recovery path exists.

**Two more generation-wide fences of the same kind:**

- `rpc_adapter` sets `uncertain = true` permanently on one missing worker ACK (30 s app stall plus 2 s grace), and every later call refuses (`rpc_adapter.rs:714-737`, `:498-501`; A #8).
- The fd-3 worker is serial (`rpc_adapter.rs:544-686`).

**Scenario** (C F1). A Store writer, such as Hermes, PAY or the door, advances the tip between admission and CAS. Lean returns `contention`. Every visitor to `calc.demo.dregg.online` gets 503 "uncertain" until an operator runs STOP (jspk1: 3,062 s) and START (1,128 s).

The agent paths prove the scope is a choice. Agents use per-route markers and do not consult the human marker (`agent_api_native.rs:801`; C §1.4).

**What a narrower fence needs.** Note first that in the week-1 shape every stranger is the same `guest` subject and session. A fence keyed by participant or session would therefore still fence everyone. The useful narrowing is **per signed call**:

1. **Rust (M), no Lean change** (C Q8.13 argues it needs none):
   - delete the generation-wide `native-dispatch-active.json`;
   - keep the per-attempt `submit-requested.json` and hostd's per-operation tombstone (`dispatch-op-<key>.json`, never re-requestable, `hostd.rs:1372-1376`);
   - keep the physical `dispatch-active.json` slot only for the fd-3 delivery window, which is already released by `finish` or `release_uncertain`;
   - bound the number of unresolved attempts (for example K per session) so that evidence cannot grow without limit.
   - The new operation gets a fresh fsynced ID (`hostd.rs:1067-1157`), so it can never collide with the uncertain one.
2. **From Lean:**
   - (a) **A definite-outcome classification** (Q1). Which of `contention`, `unavailable`, `rejected` ("transaction identity already used"), tip-changed `uncertain` and a pre-write 255 are proven no-append? Ideally the Host answers every no-append outcome with the positive `NO_RECORD` frame, as it already does for `noRecordRefused`.
   - (b) **A working op 35 lookup** on the exact retained ingress, returning the receipt or `absent`. It is active in the registry with no Rust caller. It would be the dispatch analogue of 23/27/39, so that an Uncertain attempt can be resolved and its evidence closed. Rust then needs a human `VerifiedDispatchLookup` in place of the agent-only `VerifiedSettlementV3` in `finish_dispatch_recovered`.
   - (c) **A stated independence property**, as a `Prop`: admission of call B depends on call A's unknown outcome only through the tip that B's plan reads fresh. It should be satisfiable with teeth, so that "one member's uncertainty need not stop another" is proven, not argued from reading the receiver.
3. **Physical twin (M).** Make the fd-3 worker per-call cancellable, so that a missing ACK fences that operation coordinate and evicts that session instead of poisoning the generation (`rpc_adapter.rs:763-805`).

### 4.3 Any crash ends the generation; three crashes end the grain (high)

**What ends the resident and therefore the generation:**

- an accept error, `POLLERR`, `POLLHUP` or `POLLNVAL` on any listener or auxiliary fd, or any thread-spawn failure (`http_entrance.rs:1062-1142`; A #10);
- a checkpoint client hanging up before the reply (`checkpoint_control.rs:299-301`);
- any route-control publication error;
- app exit (`resident_service.rs:1972-1974`);
- with agents enabled, one `getfacl` failure (`agent_api_server.rs:384`; C F3);
- a sealed route then forbids resident restart within the generation (`resident_route_control.rs:335-349`; A #9).

**Recovery cost.** Each end costs STOP plus continue-START. On 10-01 that was 2,529 s from kill to the new generation, on an older architecture. After 3 failures per 1,800 s the supervisor stops (B F11).

**Scenario.** EMFILE under load, or one request that crashes EtherCalc, takes the grain down for about 40 minutes. A third crash leaves it down until an operator acts. *None of the current broker, resident-privilege or recovery code has a recorded run* (B exec. summary item 8).

### 4.4 Throughput, disk and memory on a small VM (high)

- **Per request.** At least 4 Host processes (the image is 159 MB), 3 socket calls and about 10-12 fsync pairs. jspk1 GET took 35-47 s end to end (C F10, F11).
- **Per open WebSocket.** Each renewal, at half the 60 s lease, spawns 4 more processes and makes ops 36, 37 and 152.
  - The sibling lane says renewal writes no Store record (WEB-SPK-PUBLIC §7, D5). That is (unverified by shard): C confirms the probe never reaches op 34 but does not state op 152's Store effect.
- **Serial dispatch.** The dispatch closure runs on the poll thread (`http_entrance.rs:1128-1133`; A #11).
- **Shared-subject limits.** All strangers share one subject, so the whole public gets `MAX_PENDING_PER_SUBJECT = 2` and `MAX_WAITING_PER_SUBJECT = 16` (`http_entrance.rs:741-750`). This is a reviewer inference from A's constants and the sibling's one-guest design.
  - Under the jspk1 timings, a page with several static assets takes minutes, and the 17th concurrent visitor gets 503 `busy`.
- **Disk.** Every request leaves `dispatch-op-N/` holding the request body as hex, plan, ingress, committed payload and inspection (an inspection is bounded only at 96.8 MB). Nothing collects these directories, and they are cookies and user data at rest (C F2b, §4.4).
- **Memory.**
  - The entrance holds up to about 256 MiB of buffered bodies (A #16).
  - An inspection JSON for an 8 MiB body can push the resident to hundreds of MB (C F9).
  - The resident re-parses the whole SPK (up to 768 MiB decompressed, about 2.2x RSS) on every START, *inside the app's class slice* (S = 512 MiB). That is an OOM risk for large packages (inference, B F14). EtherCalc's size is not listed.

### 4.5 The sandbox floor is unmeasured and has gaps (high before strangers)

- **The audit cannot run.** `sandbox-floor-audit.sh` runs the root tests at `resident_launch.rs:578-625`. They call `spawn_gate::spawn_bounded`, which refuses without the bootstrap channel (`spawn_gate.rs:550-553`). They panic before the probe. The only evidence (2026-09-30) measured the superseded root-gate design (B F2).
- **Policy gaps against Sandstorm** (B F3, §1.7.5):
  - legacy AIO is allowed;
  - `seccomp` and `prctl(PR_SET_SECCOMP)` are allowed;
  - `vmsplice`, `mbind` and `set_mempolicy` are allowed;
  - the host hostname is visible (no `--hostname`);
  - bwrap's writable `/dev` includes tty and devpts;
  - no `RLIMIT_NOFILE` is set.
- **Stricter than Sandstorm:** a default-ENOSYS allowlist, a socket-family allowlist, all userns refused, and an ext4 quota.

### 4.6 STOP can wedge (medium)

- **A lost op 22 or 26 reply during STOP** leaves markers that make `run` refuse "requires audit" (`lifecycle_v3_stop_service.rs:1220-1234`). STOP has no op 23/27 lookup, unlike START (C F5).
- **The deadline is too short for the measurements.** The 600 s `RESPONSE_DEADLINE` (`dispatch_native.rs:29`) sits below measured whole-STOP times of 3,062 s, and the per-op split is unknown (C Q8.9).
- **`inspect-stop-claim` has no deadline.** It execs by path with no deadline (three sites), so a Host blocked on a Store lock hangs STOP and the supervisor forever (C F4).

### 4.7 Failed-START recovery gaps (medium)

- **v4 is unrecoverable.** A v4-lane failure is not `UNRESOLVED`, so it loops to `StartLimitBurst` (B F4).
- **Changed audits wedge recovery.** `retain_exact` on artifacts before the marker wedges recovery if the physical audit changes between attempts, for example through a broker `reset-failed`. The same happens if the op 206 plan binds the tip (B F5, Q2).

### 4.8 Security defects in the HTTP path (medium)

- **Open redirect through an interior tab.** `relative_location` lets `"/\t/evil.example/"` through, and browsers strip the tab (`http_response.rs:104-124`, `:26`; A #3). The attacker would be a malicious app. Fix: refuse every control byte in `Location`.
- **Permanent credentials.** Cookie and bearer have no expiry, rotation or logout (A #1). With edge injection the token lives in the Caddy config.
- **Silent refusals.** An unauthenticated request gets a silent close with no log line (`http_entrance.rs:1422`; A #6). Lean's refusal reasons are discarded: helper stderr goes to `/dev/null` (`dispatch_native.rs:465`) and 255 frames are not retained (C F6). Both breach law 10.

### 4.9 Root helper and broker (medium)

- **Root `cp` symlink race.** The root `cp` into an app-owned staging directory is a symlink race if any app-UID process is alive (`spk-var-volume:208-210`).
- **Root parses app bytes.** Root runs `e2fsck` and `debugfs` on exported app images (`broker_volume_custody.rs:266-267`; B F8).
- **Sequential broker.** The broker serves one connection at a time with a 600 s client timeout. A lost `export-volume` or `backup` reply leaves a full image copy, and a retry makes another (B F12).
- **UIDs never return.** UIDs are never reclaimed, with a pool of 64 per world, and every import consumes one. `/var` is fully preallocated (B F13).
- **Silent broker.** It ignores accept and peer-credential errors and audit-log write failures (B §4.4).

### 4.10 Agent API, only if enabled (medium)

- **Reserve before marker.** A fenced route still makes a reserve on every call (C F2).
- **The agent blocks humans.** Agent handling blocks the single resident loop for 30 s or more (C F3).
- **Refusals reported as uncertain.** v1 reports every refusal as `uncertain`, while v3 closes the socket (C F7).

### 4.11 Load-bearing stale docs (low code, high operational risk for W7)

- **The README describes a design that no longer exists.** `deploy/spk-host/README.md` describes a root broker on `/run/mini-spk-broker.sock`, `ProtectSystem=strict` and `setid_bound`, none of which exist.
- **`jspk1.sh` asserts the dead broker path.** `jspk1.sh:105-118` asserts that root 0660 broker path, so the journey cannot run against the current broker without edits (B §5.2).
- **`HTTP-CUSTODIAN-CONTRACT.md` is wrong** about the signer being unimplemented and about a one-connection proxy (A §5.2).
- **About 34 module headers lie.** 23 of the 29 shard-C files, 6 shard-B files and 5 shard-A files carry stale `#![allow(dead_code)]` "not enabled yet" headers that hide real dead items (C §5.1).

---

## 5. Unwired, undone, dead and twins: rescue, repair, delete

Sizes: S is under a day, M is 1-3 days, L is more than 3 days. "Surface" names the week-1 surface from WEB-SPK-PUBLIC §7.

### 5.1 The three-column ledger

| item (lines) | RESCUE: what it takes, size, surface | REPAIR: specific defects | DELETE: reason, better twin kept |
|---|---|---|---|
| **Generation dispatch fence** (`dispatch_native.rs:1034-1060`, `dispatch_delivery.rs:113-124`) | per-call fence plus an op 35 lookup recovery (section 4.2), **M Rust + S-M Lean**; surface: the EtherCalc grain's availability | the marker is cleared only by the NO_RECORD frame; there is no human recovery; `finish_dispatch_recovered` is agent-only | the generation-wide `native-dispatch-active.json` once per-call markers suffice |
| **op 35 dispatch lookup** (Lean active, no Rust caller) | wire it like `lifecycle_receipt_lookup::lookup_retained`, **S-M**; surface: grain availability | n/a | n/a |
| **`rpc_adapter` poison** (`:714-737`) | per-call cancellable worker, **M**; surface: grain | one missing ACK poisons the generation; serial worker | `RpcDriver::dispatch`, `dispatch_inner`, `stats` (about 60 lines, smoke-only; the cancellable path is kept) |
| **`spk-sandbox-probe`** (417) + `sandbox-floor-audit.sh` | re-point the audit at the production spawn path (worker inside the mapped userns), **S-M**; surface: required before strangers reach EtherCalc | the tests panic at `spawn_bounded` (B F2); the evidence is stale | n/a. Keep out of the release |
| **`broker_home.rs`** (267) | make `render` emit real resident hardening, **S**; surface: F1 mitigation | always returns `""` (`:202-208`) | n/a (B suggested deleting it; I disagree, because it is the natural home for the hardening drop-in) |
| **Seccomp policy** | close AIO, `seccomp`/`PR_SET_SECCOMP`, `vmsplice`, mempolicy; add `--hostname`, a minimal `/dev`, `RLIMIT_NOFILE`, **S** | B F3 gaps | n/a |
| **`export_receipt.rs`** (276) | keep: the EtherCalc CSV connector capture (`_/<sheet>/csv`, `http_entrance.rs:154-157`) serves the jdeploy3 "connector" phase, **S** | it is called a "receipt" but is unsigned (`:115`); rename it or sign it | n/a |
| **Grain export/import** (about 470) | serves the 4.2 re-genesis: export the EtherCalc `/var` before teardown, **S-M** | `stopReceiptSha256` is never checked (`grain_export.rs:176`); no domain tag on the export signature (F7); copies accumulate after a lost reply (F12) | n/a |
| **Failed-START recovery** (`grain_export.rs:315-631`) | keep (the crash-safety story), **M** to add v4 (needs Lean Q2) | v3-only (F4); `retain_exact` wedge on audit drift (F5) | n/a |
| **Lifecycle v4 retry** (2,255 + about 250 resident) | keep if a failed first CREATE must be recoverable without a new app birth, **M**; never run (C §1.9) | Rust StreamCodec twins (C Q8.12); identical `verified_physical_begin`/`checked_assembled` to v3 | the StreamCodec encoders (about 120) once Lean inspections echo the fields. Whole-lane delete only if ember accepts "failed first create means new app birth" |
| **STOP lost-reply** | add op 23/27 lookup to STOP and exec `inspect-stop-claim` through `tool_until` with a deadline, **S-M** | C F4, F5, F17 | the three ad hoc `inspect-stop-claim` execs and the divergent reader (merged) |
| **Agent API lifetime v3** (4,171 + about 200 resident) | "a Hermes resident edits the EtherCalc sheet through paid Mini dispatch": `grain` must write `agents[]` (`grain.rs:1116` writes `[]`), a grant issuance script, plus fixes. **L**; week 2+. No agent request has ever reached fd 3 | F2 (reserve before marker check), F3 (move off the resident loop; `getfacl` failure must not end the generation), F7 | n/a. PARK (feature-gate it out of the candidate) |
| **Agent API v1** (3,386) | n/a | n/a | **DELETE** as a superseded twin. Hoist the about 800 shared lines (listener, ACL, `CallerWatch`, BE32 frames, reverse client) into v3 first. Net about 2,550 (C §1.11) |
| **Checkpoint pause/backup** (about 761) | serves O1 grain backups, **M**, plus a root receiving rehearsal (`SAME-STORE-AND-CHECKPOINT.md:268-270`); never run | `Backup` freezes every running app (F15); a disconnecting client ends the generation | the standalone `mini-spk-broker backup` and `spk-host checkpoint-backup` loads (twins of the broker `backup` verb; they race the serving broker, B §5.4) |
| **Profile upgrade + runtime adoption** (1,333) | in-place spk-host upgrade, **L**, not week 1 (the demo re-geneses); never run | `store_quiescent` knows only the v3 marker names (B §1.2.7) | n/a. PARK |
| **`grain_management.rs`** (147) | member-owned grains, **S**, not week 1 | snapshot capabilities validated but never consumed | n/a. PARK |
| **`setid_bound.rs`** (353) | n/a | move `clear_capabilities` (about 15 lines) into `os.rs` | **DELETE** the rest (about 338): the filter is never installed, and its design is superseded by the userns join |
| **BPF assemblers** (3) | n/a | express the resident filter as a second policy through `seccomp.rs` | the raw-opcode filter at `resident_privilege.rs:51-110`, after the move |
| **`claim_descriptor.rs`** (310) | n/a | n/a | **DELETE**: unreferenced, v2 inspection superseded by v3/v4 |
| **`spk-hostd`** (42) + **`endpoint.rs`** (314) + **`serve_unavailable`/`serve_resident`** (about 20) | n/a | n/a | **DELETE** per the sibling ruling (WEB-SPK-PUBLIC W5): a pre-resident stub run by nothing. The better twin `resident-run` is kept. Also drop role `spkHostd` from `package.py:69` |
| **`spk-browser-proxy`** (840) + `tests/fixtures/browser-proxy-test.{crt,key}` | n/a | n/a | **DELETE after** W6, E1 and W9 green (sibling ruling): Caddy terminates TLS. Preconditions are in section 7 |
| **Smokes** `spk-smoke`, `gitweb-smoke`, `gitweb-session-smoke` (1,048) | n/a | n/a | **DELETE**: 2026-09-27 harnesses run by nothing; `gitweb-session-smoke` compiles three modules a second time. The better twin is the resident path plus jspk1 |
| **`gitweb-human-journey`** (912) + probe (208) | the only API-bearer end-to-end tool; move it to `tests/`, **S** | `#[ignore]` with an env gate | n/a |
| **`fixture_os.rs`** (713) + bash models (102) | only `fixture-v4.sh` uses it; keep while v4 lives | n/a | goes with v4 if v4 is deleted |
| **Qualification race fixture** (`dispatch_native.rs:1311-1857`, 544) | the only double-send test; already out of the release (no features in the candidate) | `jspk1.sh failstart` rows authored, never run | n/a. Keep as a test |
| **Dead blocks** | n/a | or wire `start_attested`/`compare_open_mount` as the promised last physical check | `BackupTarget`/`Copy` (40); `start_attested`/`compare_attested_volume`/`compare_open_mount` (about 35); the static supervisor template (16); unchecked `fence_and_stop_manager` (about 21); `number()`, six `FreshStopClaim` accessors and other C §5.2 items (about 60); the `main.rs broker-serve` arm (9, twin of `mini-spk-broker serve`) |
| **Volume helper `Destroy`/`Mount`/`Thaw`** | expose Destroy through the broker with an authority story (S), or | n/a | delete Destroy from the sudo surface (B F8) |

### 5.2 Twins to merge (REPAIR, about 2K lines)

- **Lifecycle skeleton.** One parameterised plan, assemble and submit engine instead of 9 copies (BEGIN, CLAIM and COMPLETION × v3, STOP, v4). C estimates about 1.5K net (C §6.2).
- **Helpers.** One module for decimals (8 definitions, 3 rules), hex (about 13 encoders), 64-hex validation, bounded private-file readers (about 18 across B and C), atomic writers, file SHA, peer credentials (3) and LE decimal digests (4). Estimate about 600-900 (A §5.4, B §5.4, C §5.4).
- **Operation-ID allocators.** Three: `hostd.rs:1067-1157`, `operation_ledger.rs:25-109`, and controller-chosen agent IDs (A §5.4, C S10).
- **Completion retry rule.** Re-send (`install_v3.rs:621-629`) versus replan (`lifecycle_v3_stop_service.rs:949-976`). Pick one (C §5.4).
- **Pinned execution.** Hash-then-exec-by-path (`launch_descriptor_native.rs:133`, `grain.rs:1426-1431` unpinned `init-store`) versus the sealed-memfd `native/pinned_execution.rs`. Adopt the sealed one (B F9).
- **Header allowlist.** Emit it from Lean, or have the entrance pass every header and let `requestSafeFor` decide (A Q5).
- **`install_v3.rs`.** Fold it into `install_service.rs`: one feature, residue suffix (A §5.5).

### 5.3 Against sibling crates

- **memfd sealing.** `seccomp.rs:361-396` against `native/pinned_execution.rs` and `resource-client/src/transport.rs:1377-1390` (B §5.4).
- **Agent protocols.** Both generations also live in `grain-runtime/src/application_api_tools.rs:30-31` (C §5.5).
- **Custodian cookie.** The sibling's R2 plans one `__Host-` cookie module shared with `mini web` (`http_entrance.rs:1311-1381`).

---

## 6. Size and shape

### 6.1 Per-family totals

| family | lines | tests |
|---|---:|---:|
| shard A files (entry points, hostd, entrance, routes, fd 3, install, OS) | 18,501 | about 5,457 |
| shard B files (grain, sandbox, broker, resident, volumes, descriptors) | 16,249 | 3,269 |
| shard C files (dispatch, lifecycle v3/v4, agent v1/v3) | 19,948 | 4,370 |
| **crate** | **54,698** | **about 13,100 (24%)** |

The largest files are `hostd.rs` 3,268, `resident_service.rs` 2,665, `dispatch_native.rs` 2,386, `http_entrance.rs` 2,249, `grain.rs` 1,702, `rpc_adapter.rs` 1,673 and `lifecycle_v3_stop_service.rs` 1,495.

### 6.2 Deletable today (section 5 DELETE, arithmetic from the shard counts)

| item | lines |
|---|---:|
| spk-hostd + endpoint + unavailable loops | about 376 |
| three smokes | 1,048 |
| RpcDriver smoke-only path, unchecked fence, broker-serve arm | about 90 |
| `claim_descriptor` | 310 |
| `setid_bound` (except `clear_capabilities`) | about 338 |
| dead blocks (B and C) | about 151 |
| agent v1 after hoisting shared code | about 2,550 |
| **today** | **about 4,860** |
| `spk-browser-proxy` after W9 | 840 |
| v4 StreamCodec after Lean Q8.12 | about 120 |

### 6.3 Demo-minimal cut (every week-1 surface on)

Week 1 needs: install one host-owned EtherCalc SPK; one guest route behind Caddy; resident dispatch including WebSocket; supervisor STOP and continue; v3 failed-START recovery; the connector export capture; and the broker plus root helper.

Starting from 54,698, the cut removes:

- the deletions above, 5,700 including the proxy;
- the PARK items, feature-gated out of the candidate:
  - agent v3 with its resident side, about 4,371;
  - profile upgrade and runtime adoption, 1,333;
  - checkpoint, about 761 (unless O1 adopts it);
  - `grain_management`, 147;
  - `gitweb-human-journey` with its probe, moved to tests, 1,120;
- v4 with `fixture_os`, about 3,320, only if ember accepts a new birth after a failed first CREATE.

The compiled demo path comes to **about 38K lines** with v4 and **about 35K** without it. Merging the twins (section 5.2) brings it to **about 33-36K**, of which roughly a quarter is tests. That is still large for "interpreter + node + FFI marshalling ONLY" (ATLAS §7). The two biggest remaining blocks are hostd's journals and the lifecycle engine, and both carry physical crash-safety that Lean cannot hold.

---

## 7. Deployability on a small public Linux VM

The target is the sibling's fresh **cx43, Debian 13** (WEB-SPK-PUBLIC 0.2).

### 7.1 What the box needs (A §7.1, B §7.1, C §7.1)

- **Operator account.** One operator with a systemd user manager and **linger**. `/etc/subuid` and `/etc/subgid` ranges at 65536 or above covering the 64-UID app pool.
- **Root setup.** `install-user-world` once per world: registry, sudoers, `/var/lib/mini-spk-worlds/<store>`, `host-identity`.
- **Kernel.** cgroup v2 with memory, pids, cpu and io delegated to the user manager; unprivileged user namespaces; loop devices; ext4.
  - Debian enables unprivileged userns by default, so the Ubuntu AppArmor `mini-grain-bwrap` path should be unnecessary. That is a reviewer inference; the sibling's H2/W7 probe decides it.
- **Packages.** bubblewrap with `--disable-userns` (≥0.10 per B §2.2; check trixie's version), uidmap, sudo, e2fsprogs, util-linux, acl and jq.
- **Binaries.** `spk-host`, `mini-spk-broker` and `spk-ingest` in `~/.local/libexec`; `mini-spk-volume-helper` root-owned; the pinned Lean Host (159 MB), its config, and the `resource-client` operator socket.
- **Disk.** The full class size per grain, preallocated, plus image trees, plus unbounded `dispatch-op-N/` growth (needs a retention bound before public traffic, C §7.4 rec. 3), plus never-pruned exports.
- **Memory.** Each class slice covers app **and** resident. The ingest unit needs 2 GiB transiently.

### 7.2 Preconditions for deleting `spk-browser-proxy` (sibling W6, E1, W9)

From the shards' constants, these are reviewer inferences where marked.

1. **Socket access for the edge.** The custodian accepts only `peer_uid == euid` (`http_entrance.rs:1100`). `http.sock` is chmod 0600 (`bind_fixed`, `:1153-1219`) inside a route directory that `Journal::open` requires to be 0700 (A §1.3).
   - W6 must widen the peer check to an edge gid, **and** the socket mode, **and** directory traversal, or bind the socket elsewhere.
   - Sibling W6 cites only `:1100`, `:1153-1219` and `:214-280`. The directory mode is an extra item.
2. **One request per connection.** The custodian refuses pipelined bytes and answers `Connection: close`, so Caddy must not reuse upstream connections (inference).
3. **Request framing.** The custodian refuses `Transfer-Encoding`, `Expect`, `Content-Encoding` and every duplicate header (`http_entrance.rs:500-536`).
   - Caddy must buffer request bodies so that HTTP/2 uploads without a length reach the upstream with `Content-Length`, not chunked.
   - Cookie fields must arrive merged. I believe Go's HTTP/2 server does this, but that is unverified.
   - Headers Caddy adds, such as `X-Forwarded-*`, are dropped silently, which is harmless.
4. **Host and Origin.** `Host` must equal `expectedHost` exactly, with no port (`:671-675`). `Origin` must equal `https://calc.demo.dregg.online` on unsafe methods and on the WebSocket open (`:675-682`, `:721-725`).
5. **TLS policy.** Caddy's hybrid-plus-X25519 policy (sibling D3) replaces the proxy's X25519MLKEM768-only policy, which excluded clients on OpenSSL older than 3.5 (A §7.3).
6. **EtherCalc transport.** It uses socket.io, which may start in long-polling, where each poll is a full Mini dispatch. That is unverified. W9's `jspk10-ws.py` run should confirm a direct WebSocket.

### 7.3 What strangers and members can do (A §7.4-7.5, B §7.5, C §7.3)

- **Without the cookie.** Nothing reaches Lean or the app.
- **Through the guest cookie** (everyone, with edge injection):
  - any request Lean admits for `guest`, signed by the host;
  - fill the disk (C F2b);
  - saturate the Host (C F10);
  - occupy the guest's 2 pending and 16 waiting slots;
  - open up to 32 WebSockets (class S);
  - crash the app, which costs about 40 minutes, and after three crashes leaves the grain down (section 4.3);
  - indirectly fence everyone through any non-definite op 34 (section 4.2).
- **Required before public.**
  - Fix the sandbox-floor audit and run it (section 4.5).
  - Render resident hardening (section 4.1).
  - Bound journal retention.
  - Settle Q1 for the fence.
  - Make STOP lookup-capable.

---

## 8. Questions for the Lean side (deduplicated)

1. **Definite op 34/164 outcomes.** In `Kernel/ApplicationDispatchReceiver.receiveAdmitted` (`:262-306`), can `.contention`, `.unavailable`, `.rejected "dispatch transaction identity already used"` (`:276-278`) or a `serveFrame` 255 (`Host/Main.lean:2645-2656`) follow a durable append of this dispatch? If they are proven no-append, will the Host answer them with the `NO_RECORD` frame? (C Q8.1)
2. **op 35.** Is `APPLICATION_DISPATCH_LOOKUP` (registry line 412, active, `fnDispatch`) a receipt-only lookup on the exact retained ingress, returning the receipt or `absent`, analogous to 23/27/39? Name the declaration. Rust has no caller (C §2.1).
3. **Fence independence, as a `Prop`.** Is there a declaration stating that admission of signed call B does not depend on the unknown outcome of call A beyond the tip B's plan reads? If not, can it be stated with satisfiable and teeth witnesses, so that the per-call fence rests on a theorem? (C Q8.13)
4. **Custodial signing.** Should the session birth or ticket carry a custody mode (member-held, host custodian, resident-for-controller), so that Lean's audit trail does not attribute host-signed dispatches to a member's key? (A Q8, C S7)
5. **SPK signature.** Does any declaration verify the Sandstorm Ed25519 signature (the app id) over the manifest bytes, or is `signedAppId` a Rust attestation? (B Q8)
6. **K-SPK size class.** Which declaration will pin memory, tasks, CPU and IO weight, `/var` MiB and the WebSocket caps in the birth descriptor, so that `broker::CLASSES` becomes a projection? Same question for `ApplicationGrainExport` / `import_binds_stop_receipt`. (A Q6, B Q6, Q7)
7. **Index relations.** Which declarations check the route ticket `issueIndex` (`grain_route.rs:184`), continue `createdIndex` (`grain.rs:1057-1060`) and the agent `reserveIndex` against `acceptedCount - 1`? Does Lean or Rust choose `processGeneration`? (A Q1, B Q4-Q5, C Q8.3)
8. **Digest byte order.** Which declaration fixes the Nat-to-bytes order of `sessionFingerprint` in the op 152/154 inspections and in `application-route-bound-dispatch`, and of the STOP `observationDigest`? Is the latter bound or opaque? (A Q2-Q3, C Q8.4)
9. **Headers into the permit.** Does `physical_request_digest` commit to the exact ordered header list and body that `project_http` maps? Can `ordinaryHeaderName` be emitted as a build artifact for Rust to consume? (A Q4-Q5)
10. **v4 recovery and plan determinism.** Is there a v4 failed-START recovery source, or a theorem that v4 cannot reach that phase? Is the op 206 plan byte-identical across tips? (B Q1-Q2)
11. **Custodian signatures.** Which declaration in the op 208 path verifies the failed-START report's Ed25519 signature against the genesis `completionCustodianKey`? `authorSignedReport` checks lengths only. Is that key distinct from the management key? (A Q9, B Q3)
12. **STOP after a lost op 22/26.** Is a 23/27 lookup sufficient, and does `inspect-stop-claim` accept a claim recovered by lookup? What per-op latency should the 600 s deadline expect? (C Q8.9, Q8.14)
13. **Route seals.** Is op 154/164 generation-scoped in a way that makes "no resident restart after a seal" necessary, or could a restarted resident re-admit its routes? (A Q10)
14. **Retirement.** Can ops 44, 45 and 50-53 and their `Kernel/ApplicationLifecycleClaim{,V2}*` modules be retired? Do the v4 inspections echo every field so that the Rust StreamCodec can go? (C Q8.11-8.12)
15. **Bounds.** What is the largest application resource id? Rust refuses 19 or more digits (B Q9). Does any agent reserve expire or refund after a fenced route? (C Q8.2)
