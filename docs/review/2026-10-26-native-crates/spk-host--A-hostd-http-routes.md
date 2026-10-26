# spk-host, shard A: entry points, hostd, HTTP entrance, routes, RPC adapter, install

| field | value |
|---|---|
| Shard | spk-host A: "entry points, hostd, HTTP entrance, routes, RPC adapter, install" |
| Crate | `native/spk-host` (package `minidregg-spk-host`, workspace member), "Physical Linux custody and sandbox launch for Sandstorm SPK grains" (`native/spk-host/Cargo.toml:7`) |
| Date | 2026-10-26 |
| Reviewer | Opus reader, fan-out review of native crates |
| Method | every file below read in full with line numbers; cross-references by grep; Lean receivers opened for every JSON or byte format this shard emits; no build or test was run |

## Files covered

| file | lines | of which test (`mod tests` to EOF) |
|---|---:|---:|
| `native/spk-host/Cargo.toml` | 38 | 0 |
| `src/lib.rs` | 141 | 0 |
| `src/main.rs` | 276 | 0 |
| `src/bin/mini-spk-volume-helper.rs` | 9 | 0 |
| `src/bin/mini-spk-broker.rs` | 35 | 0 |
| `src/bin/spk-hostd.rs` | 42 | 0 |
| `src/bin/spk-smoke.rs` | 146 | 0 |
| `src/bin/gitweb-session-smoke.rs` | 312 | 0 |
| `src/bin/spk-sandbox-probe.rs` | 417 | 48 |
| `src/bin/gitweb-smoke.rs` | 590 | 0 |
| `src/bin/spk-browser-proxy.rs` | 840 | 320 |
| `src/bin/gitweb-human-journey.rs` | 912 | 0 |
| `src/hostd.rs` | 3,268 | 1,352 |
| `src/http_entrance.rs` | 2,249 | 808 |
| `src/http_response.rs` | 606 | 231 |
| `src/http_entrance_gitweb_probe.rs` | 208 | 208 (included into `http_entrance` tests) |
| `src/web_socket.rs` | 906 | 293 |
| `src/stream_continuity.rs` | 375 | 153 |
| `src/route_admission.rs` | 236 | 84 |
| `src/grain_route.rs` | 582 | 181 |
| `src/resident_route_control.rs` | 1,056 | 409 |
| `src/endpoint.rs` | 314 | 61 |
| `src/os.rs` | 176 | 0 |
| `src/fixture_os.rs` | 713 | 0 (whole file is a fixture-only feature) |
| `src/namespace_identity.rs` | 175 | 0 |
| `src/install_service.rs` | 317 | 60 |
| `src/install_v3.rs` | 914 | 216 |
| `src/rpc_adapter.rs` | 1,673 | 610 |
| `src/native_dispatch.rs` | 100 | 48 |
| `src/operation_ledger.rs` | 171 | 61 |
| `src/dispatch_web_input.rs` | 742 | 314 |
| `seccomp/resident-web.policy` | 110 | n/a |
| `tests/fixture-os/spk-ingest` (bash) | 34 | fixture |
| `tests/fixture-os/spk-var-volume` (bash) | 68 | fixture |
| `tests/fixtures/browser-proxy-test.{crt,key}` | PEM | public test fixture (a committed private key) |
| **total** | **18,751** (18,501 Rust) | **5,457** Rust test lines (29.5% of the Rust) |

Context read, not owned: `deploy/spk-host/README.md`, `mini-spk-broker@.service`,
`mini-spk-broker.example.json`, `HTTP-CUSTODIAN-CONTRACT.md`, `WS-AUTHORITY-LEASES.md`,
`USER-TENANCY.md`, `BROWSER-WEBSOCKETS.md`, `native/spk-rpc/README.md`, the relevant parts of
`resident_service.rs`, `dispatch_delivery.rs`, `dispatch_native.rs`, `grain.rs`, `grain_export.rs`,
`lifecycle_v3_claim_native.rs`, `protocol/host-operations.json`,
`Host/ApplicationFailedStartRecoveryTools.lean`, `Kernel/ApplicationFailedStartRecoveryReport.lean`,
`Kernel/ApplicationLifecycleCompletionReport.lean`, `Host/Json.lean:2985-3025`,
`Kernel/ApplicationDispatchAdmission.lean:100-160`.

The binary -> module -> Host-operation -> unit table built while reading is at
`/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/spk-A/binary-table.md`
and is reproduced in section 2.6.

## Executive summary

1. The HTTP entrance is **not internet-facing in any shipped configuration**. `http_entrance` serves only a
   same-UID Unix socket (`http.sock`, mode 0600, `SO_PEERCRED` uid == euid, `http_entrance.rs:1100`,
   `1234`), and the only TCP listener in the crate's production binaries is `spk-browser-proxy`, bound to
   `127.0.0.1` (`spk-browser-proxy.rs:496`) and meant to be reached through an owner's `ssh -L`.
2. Authentication is **three static 256-bit per-route tokens** made by `initialize_custodian`
   (`http_entrance.rs:306-377`): a one-time bootstrap token exchanged for a permanent
   `__Host-mini_spk_session` cookie, and a separate API bearer token. Tokens do not expire and cannot be
   rotated without a new route. They authenticate the transport only.
3. **Every request that reaches the app is gated by a Lean admission** (op 36 plan, 37 assemble, 34 or
   164 submit) before fd 3 delivery (`dispatch_delivery.rs:145-186`). The one route served without Mini is
   `/__mini/bootstrap` (`http_entrance.rs:1409-1421`), which only swaps a token for a cookie.
4. **The custodian signs as the participant.** A route stores the participant's signing seed path
   (`grain_route.rs:198-222`), and the resident signs Mini dispatches with it. Whoever holds the cookie can
   make the host sign any Lean-admissible request as that participant. Lean cannot tell host-signed from
   member-signed. This is the trust fact that matters most for a public demo.
5. `hostd.rs` is **not a daemon**. It is the per-generation durable physical journal (`Journal`) with
   phases Armed, LaunchRequested, Entered, Running, Fenced, Stopped, and one-shot dispatch tombstones. It
   sends no Host frames. It cannot launch twice: a second ExecStart is refused (`hostd.rs:1679-1681`), and
   a lost Host reply leaves a terminal Uncertain tombstone, never a resend.
6. The `spk-hostd` binary (status endpoint, "serve-http-unavailable" stub, a duplicate
   `init-custodian`) is **shipped by the candidate but run by no unit, script or journey**. With
   `endpoint.rs` it is about 356 lines of dead code.
7. Ops 200-209: 200 and 203-205 are unallocated. 201 and 202 belong to resource birth. 206-209
   (failed-START recovery) are driven by `grain_export.rs`. `hostd::Journal::audit_failed_start` supplies
   the physical audit JSON. Its 18 fields, and the 10 fields of `source_stop_audit`, **agree exactly** with
   the Lean parsers (`Host/ApplicationFailedStartRecoveryTools.lean:54-72`, `Host/Json.lean:2992-3013`).
8. `rpc_adapter` maps only `getViewInfo`, `newSession` (Web/Api), `WebSession` request methods and
   `openWebSocket`. Powerbox, persistence and SandstormApi callbacks are unimplemented and fail closed in
   `spk-rpc`. WebSocket frames are **opaque bytes**: they are not parsed, and the only limits are a
   per-socket bytes/minute budget and an authority lease (default 60 s).
9. Route authority comes from Lean. Rust keeps immutable route identity, the 64-route cap, seals and the
   op-34-vs-164 choice. Registration requires a fresh op 154 inspection that `route_admission` compares
   field for field (`resident_service.rs:2024-2050`).
10. `fixture_os` vs `os` is a **compile-time seam** (`os.rs:8-21`, feature `fixture-os`), not a runtime
    twin. `install_service` vs `install_v3` is **one implementation split in two files**, not a twin.
    Both are reachable from `grain install`.
11. Real twins exist. Rust keeps three hand-written copies of Lean's ordinary-header allowlist
    (`http_entrance.rs:415-436`, `dispatch_web_input.rs:332-381`, versus
    `Kernel/ApplicationDispatchAdmission.lean:116-120`). There are two monotonic ID allocators
    (`hostd.rs:1067-1157` and `operation_ledger.rs:25-109`). There are two `init-custodian` entry points
    (`main.rs:142-161` and `spk-hostd.rs:19-22`) and two broker entry points (`main.rs:62-70` and
    `mini-spk-broker.rs:8-10`). Three smoke binaries carry the same signed-manifest checker.
12. Five module-level `#![allow(dead_code)]` comments are **stale**. `http_response`, `rpc_adapter`,
    `dispatch_web_input`, `native_dispatch` and `install_service` are all reachable from `resident-run` or
    `grain install`. The "unreachable mutators" comment on `impl Journal` (`hostd.rs:810-813`) is also
    stale. `HTTP-CUSTODIAN-CONTRACT.md` still says the signer and native delivery are "unimplemented" and
    that the TLS proxy serves "one connection at a time". Both claims are now false.
13. Availability hazards: one uncertain dispatch fences **every** participant of the grain until operator
    recovery (`dispatch_delivery.rs:113-124`). A missing worker ACK permanently poisons the RPC driver for
    the generation (`rpc_adapter.rs:714-737`). A sealed route makes the resident refuse to restart without
    a lifecycle STOP and a new generation (`resident_route_control.rs:335-349`). Any accept or poll error
    ends the generation (`http_entrance.rs:1099`, `1080-1094`). Measured STOP/START costs are minutes
    (evidence 2026-10-02).
14. A demo needs **3 or 4 of the 9 binaries**: `spk-host`, `mini-spk-broker`, `mini-spk-volume-helper`, and
    `spk-browser-proxy` if browsers connect. The other five can leave the release (about 2.9K lines from
    this shard, plus `fixture_os` at 713 lines if fixture journeys go too).
15. Lean-side questions (section 8) concern the issue index the route derives
    (`grain_route.rs:184`), the byte order of decimal digests (`stream_continuity.rs:22-39`), whether
    `matched` binds the HTTP header list that `dispatch_web_input` projects, and where size classes and
    the WebSocket caps should become Lean data.

---

# 1. What this code is and does

## 1.1 Crate shape and the module list

`lib.rs` declares 66 Linux-only modules (`lib.rs:6-141`). Every `mod` sits behind
`#[cfg(target_os = "linux")]`. `completion_custodian` carries the attribute twice
(`lib.rs:32-33`, a harmless duplicate). Nine files under `src/` are not in `lib.rs` and are pulled in
some other way:

| file | how it is compiled |
|---|---|
| `install_v3.rs` | `#[path = "install_v3.rs"] mod install_v3;` inside `install_service.rs:6-7` |
| `http_entrance_gitweb_probe.rs` | `include!` inside the test module, `http_entrance.rs:1448` |
| `broker_endpoint.rs`, `broker_runtime_adoption.rs`, `broker_home.rs`, `broker_volume_custody.rs` | `#[path]` submodules of `broker.rs:18-28` (shard B) |
| `broker_checkpoint.rs` | `#[path]` at `broker.rs:1381-1382` (shard B) |
| `grain_profile_upgrade.rs`, `grain_management.rs` | `#[path]` at `grain.rs:35-38` (shard B) |

`fixture_os` compiles only with feature `fixture-os` (`lib.rs:134-135`, `Cargo.toml:16-18`). Its doc
comment says it is "Never in a release", and the candidate builder passes no features (checked: no
`--features` in `deploy/candidate/build.sh` or `package.py`). The feature `integration-qualification`
(`Cargo.toml:14-15`) gates `hostd::qualification_refuse_spawn` (`hostd.rs:742-766`).

Dependencies (`Cargo.toml:20-38`) are all exact-pinned: `libc 0.2.189`, `serde`, `serde_json`, `sha2`,
`sha1` (WebSocket accept only), `base64`, `ed25519-dalek`, `rustls 0.23.45` with `aws_lc_rs` only,
`rustls-pemfile`, and `tokio 1.48.0` (net, rt, time, io-util, process, sync). `sandstorm-package` is a git
dependency pinned to rev `5819115352bd...` of `github.com/emberian/dregg`. There are path dependencies on
`compatible-upgrade-custody`, `spk-rpc` and `signed-api-path`. `capnp`/`capnp-rpc` are dev-dependencies
(test servers). The `[[bin]]` table names only `spk-host` (`Cargo.toml:9-11`). The other eight binaries
are auto-discovered under `src/bin/`.

## 1.2 Entry points (the nine binaries)

### `spk-host` (`src/main.rs`, 276 lines)

The process sets `umask(0o077)` first (`main.rs:21-23`). Arguments are matched by count and verb in a
fixed order. Every failure prints to stderr and exits 1, except as noted:

| verb (argc) | line | calls | notes |
|---|---|---|---|
| `fixture-systemctl ...`, `fixture-unit-run ...` | 26-35 | `fixture_os::systemctl_main`, `unit_run_main` | only with feature `fixture-os` |
| `qualify-launch PRIVATE_CONFIG` (3) | 36-47 | `launch_descriptor_native::qualify_launch` | prints result JSON |
| `install-prepare` / `install-complete PRIVATE_CONFIG` (3) | 48-61 | `install_service::prepare` / `complete` | section 1.12 |
| `broker-serve CONFIG` (3) | 62-70 | `broker::serve` | twin of `mini-spk-broker serve` |
| `checkpoint-pause-check CONFIG INPUT` (4), `checkpoint-backup CONFIG OUT INPUT` (5) | 71-93 | `broker::checkpoint_*` | documented in `deploy/spk-host/SAME-STORE-AND-CHECKPOINT.md:121-122` |
| `grain VERB ...` (>=4) | 94-111 | `grain::run` | exits 3 when the error starts `UNRESOLVED:` (the supervisor template's `RestartPreventExitStatus=3`) |
| `resident-bootstrap CONFIG` | 112-117 | `resident_privilege::run` | shard B |
| `resident-validate CONFIG` | 118-123 | `resident_service::validate_config` | shard B |
| `resident-run CONFIG` | 124-132 | `resident_service::run` | the long-lived resident, which hosts `http_entrance` |
| `resident-stop CONFIG` | 133-141 | `lifecycle_v3_stop_service::run` | shard C |
| `human-custodian-init DIR HOST APP SUBJECT SESSION TICKET web\|api` (9) | 142-161 | `http_entrance::initialize_custodian` | also in `spk-hostd init-custodian` |
| `qualify VERIFIED_SPK` | 162-192 | `materialize::qualify_bridge_spk` | `.expect` at 167 and 170 assumes a qualified bridge always carries a signed member |
| `inspect-installed IMAGE_DIR APP_UID` | 193-236 | `materialize::verify_installed_spk` | refuses uid 0 and relative paths, exit 2 |
| `materialize SPK STORE APP_UID` | 237-264 | `materialize::materialize_spk` | called by `deploy/spk-host/spk-ingest` |

The usage text (`main.rs:265-267`) lists neither the `checkpoint-*`, `resident-bootstrap` and
`resident-validate` verbs nor the fixture verbs. Unknown input exits 2 (`main.rs:269`).

### `mini-spk-broker` (`src/bin/mini-spk-broker.rs`, 35 lines)

`serve CONFIG` calls `broker::serve` (`:8-10`). `backup CONFIG OUT_DIR` calls `broker::backup` and prints
the result (`:11-15`). The deploy unit is `deploy/spk-host/mini-spk-broker@.service`: a **user** unit
(`%h`, `WantedBy=default.target`) with `NoNewPrivileges=no` because sudo and the uid-mapping helpers are
one-shot trusted boundaries. `deploy/spk-host/README.md` still describes a root broker on
`/run/mini-spk-broker.sock`. `USER-TENANCY.md` says the v1 root broker config and the global socket are
now refused. The README is stale on this point.

### `mini-spk-volume-helper` (`src/bin/mini-spk-volume-helper.rs`, 9 lines)

A one-shot exec that takes exactly one JSON argument and calls `volume_helper::execute`
(`:4-7`). It is installed through sudoers by `deploy/spk-host/install-user-world`. Shard B owns
`volume_helper`.

### `spk-hostd` (`src/bin/spk-hostd.rs`, 42 lines)

Three verbs (`:11-31`):

- `serve-status ABS_DIR` opens `hostd::Journal` and binds `endpoint::PrivateEndpoint`, a same-UID status
  socket `hostd.sock` (section 1.7).
- `serve-http-unavailable ABS_DIR` calls `http_entrance::PrivateHttpEntrance::bind` then
  `serve_unavailable`. That loop authenticates transport and then always answers 503 "Mini dispatch
  admission unavailable" (`http_entrance.rs:1221-1223`, `1394-1400`).
- `init-custodian ...` duplicates `spk-host human-custodian-init`.

The module doc (`:1-2`) says "BEGIN and dispatch stay unavailable until Mini's native checked receivers can
issue sealed authority values". That is no longer true of the crate: `resident-run` does both. This binary
is the pre-resident stub. No unit, script or journey launches it. `deploy/candidate/build.sh:12` says
"shipped, not installed by default", and `package.py:69` lists role `spkHostd`. The only other mentions are
in 2026-09-27 evidence logs.

### `spk-browser-proxy` (`src/bin/spk-browser-proxy.rs`, 840 lines)

This is the loopback TLS 1.3 entrance for one custodian socket. Details are in section 1.5. It is launched
as a transient service by `scripts/spk-platform/ws-continuity-launch.py:274` and recorded in
`docs/evidence/2026-10-02-spk-browser-tls/README.md`.

### `spk-smoke` (146 lines), `gitweb-smoke` (590), `gitweb-session-smoke` (312)

These are private qualification harnesses from 2026-09-27. Each verifies a stored signed SPK by SHA-256
and `sandstorm_package` parse (`spk-smoke.rs:48-66`, `gitweb-smoke.rs:67-94`,
`gitweb-session-smoke.rs:63-87`; the same checker three times). Each spawns the app with
`sandbox::spawn_sandbox` and drives Cap'n Proto over fd 3 with no Mini admission ("grants no Mini
authority", `spk-smoke.rs:1-2`).

`gitweb-smoke` runs a loopback-only HTTP/1.1 adapter (`gitweb-smoke.rs:149-218`) so the real
`/usr/bin/git` can push and clone through the packaged bridge. It refuses a second receive-pack POST
(`:240-245`).

`gitweb-session-smoke` compiles `rpc_adapter.rs`, `web_socket.rs` and `stream_continuity.rs` a **second
time** into the binary through `#[path]` (`:4-11`). It re-exports `dispatch_native`, `broker` and `hostd`
from the library at the binary root (`:12-15`) so that the copied modules' `crate::` paths resolve. It
exercises session-cache reuse, attenuation, a 33-session LRU eviction and the poisoned-driver refusal of a
resend (`:189-303`).

None of the three is run by any current script. Their evidence is `deploy/spk-host/SMOKE-2026-09-27.md`,
`GITWEB-SMOKE-2026-09-27.md`, `GITWEB-SESSION-PROBE-2026-09-27.md` and `GITWEB-CACHE-CAPACITY-2026-09-27.md`.

### `gitweb-human-journey` (912 lines)

An operator-private Git smart-HTTP bridge with three verbs. `seed-api` clones, commits one file and pushes
once (`:565-716`). `lookup-api` reads the remote ref read-only after a lost reply (`:718-850`). `view-web`
fetches one blob through the browser cookie (`:852-895`). It speaks HTTP to the custodian's `http.sock`
with `Authorization: Bearer <api.token>` (`:420-421`) or `Cookie: __Host-mini_spk_session=<browser.token>`
(`:884`). It writes `receive-pack-forwarded.marker` before forwarding the POST (`:410-419`) so a retry
becomes a read-only lookup.

Its only caller is the `#[ignore]` component test `http_entrance_gitweb_probe.rs:3-5`, which needs the
`MINI_GITWEB_HUMAN_HELPER` environment variable. Evidence: `docs/evidence/2026-09-27-gitweb-human-journey/`.

### `spk-sandbox-probe` (417 lines)

A program placed **inside** a test SPK image and launched as the app. It measures the sandbox floor: an
fd census of exactly {0,1,2,3}; `openat(fd, "..")` refused for fds 3..64; public connect gives
ENETUNREACH and loopback gives ECONNREFUSED; netlink, packet and vsock give EAFNOSUPPORT; nine denied
syscall families give the exact errno, each run in a forked child; a positive web-app control; nested
user namespaces refused (`:149-334`). It prints one JSON object per check and a final verdict. The
`refused_with` rule requires the exact errno (`:83-85`). Caller:
`scripts/spk-platform/sandbox-floor-audit.sh:8,38`.

## 1.3 `hostd.rs` (3,268 lines; 1,916 code and 1,352 tests)

The module doc (`:1-6`) calls this "Durable physical custody for one Mini-authorized application
generation. This is not an admission path." It is **a library of durable state machines used by the
resident**, not a daemon.

### Data model

- `VerifiedBegin` (`:70-103`) holds `app: u64`, `generation: u64`, `operation_id` (canonical decimal
  string, deserializer also accepts historical JSON numbers, `:41-59`), `transaction_id`, `event_id`,
  `package_sha256` (hex64), `image_identity` and `process_identity` (each 1..512 bytes), and `unit`.
  `validate` requires generation >= 1, canonical decimals, hex64, and a unit name parsed by
  `broker::parse_resident_unit` that names the same app and generation (`:85-102`). The doc says there is
  no public constructor. In practice it is built from Lean inspections in `lifecycle_v3_claim_native.rs`
  (shard C; for example `process_identity: unit.clone()` at `:515`, where the unit is the UTF-8 of
  `processIdentityHex`).
- `Phase` (`:107-114`): `Armed`, `LaunchRequested`, `Entered`, `Running`, `Fenced`, `Stopped`.
- `Record` (`:117-130`) holds `version` (1), `identity`, `phase`, `child_pid`, `invocation_id` and
  `control_group` (systemd InvocationID and unified cgroup path), and `dispatch_in_flight:
  Option<DispatchIdentity>`. `validate` (`:196-242`) enforces cross-field invariants: no PID or unit
  instance before launch; both or neither of invocation and cgroup; Entered and Running need an instance;
  Running needs a PID; any in-flight dispatch must match app, generation and invocation and be in
  Running, Fenced or Stopped.
- `DispatchIdentity` (`:251-314`) holds `permit_sha256` (SHA-256 of the captured Lean op 34 committed
  permit), `request_digest`, `dispatch_transaction` and `dispatch_event` (canonical decimals at or below
  2^256-1, `:271-276`), `app`, `app_generation`, `invocation_id` (32 hex), `operation_id`,
  `session_resource` and `session_generation`. `operation_key` (`:299-313`) is SHA-256 over a domain tag
  plus (app, generation, session_resource, session_generation, operation_id). It deliberately excludes
  the HTTP digest: "one session may not reuse an operation ID with changed bytes".
- `DispatchTombstone` (`:335-339`) carries a `DispatchPhase` of `DeliveryRequested`, `Delivered` or
  `Uncertain` (`:328-332`).
- `UnitInstance` (`:344-347`, `425-475`) reads `INVOCATION_ID` from the environment and `/proc/self/cgroup`
  `0::` line. It must agree with `systemctl --user show` on Id, LoadState, InvocationID, ControlGroup and
  MainPID == own pid (`:440-453`).
- `UnitStopAudit` (`:482-491`) and `StopIdentity` (`:505-512`) cover the post-stop manager and cgroup
  observation.

### The launch state machine (journal `record.json` in one per-generation directory)

| transition | function | guard |
|---|---|---|
| (none) -> Armed | `arm` `:1609-1630` | idempotent for an identical `VerifiedBegin`; a conflicting one is refused |
| Armed -> LaunchRequested | `request_launch` `:1632-1643` | identity equal and phase Armed; a second call is refused |
| LaunchRequested -> Entered (fsync) -> spawn -> Running (fsync) | `enter_and_spawn` / `_with` `:1650-1701` | runs as the exact unit ExecStart under the journal flock; a spawn error leaves Entered with no child; a Running fsync failure kills and reaps the child before unlock (`:1695-1698`) |
| Running or Fenced -> Fenced -> stop -> audit -> Stopped | `fence_and_stop` `:1705-1745`, `fence_and_stop_manager` `:1749-1769`, `fence_and_stop_manager_checked` `:1775-1789`, `_with_mode` `:1866-1914` | Fenced is fsynced before any manager command; Stopped only after `UnitStopAudit::prove` (`:674-687`) |
| read-only audits | `audit_failed_start` `:818-837`, `audit_prior_running` `:843-890`, `audit_stopped_manager_checked` `:1813-1846` | read the manager before and after; refuse on change (`:829-834`) |

Lost replies are handled here (question 2 of the brief). A second launch of one generation is impossible.
`enter_and_spawn_with` refuses any phase but LaunchRequested ("late or duplicate unit ExecStart refused",
`:1679-1681`). A systemd restart of the same unit therefore cannot fork a second child, and a crash after
Entered leaves the generation unlaunchable. Recovery is the Lean failed-START path (ops 206-209 via
`grain_export.rs`, shard B). README states the next START is generation N+2. The record file is never
removed (`:782-783`).

### The dispatch state machine (per generation, shared by every participant route)

1. `allocate_dispatch_operation` (`:1067-1157`) keeps a monotonic counter in `dispatch-next-id`. It
   writes a per-ID marker `dispatch-id-N` with `create_new` and fsync **before** the counter rename. A
   missing counter after any use fails closed (`:1097-1110`).
2. `request_dispatch` (`:1347-1390`) runs under the lock. The phase must be Running with no dispatch in
   flight, and the identity must match app, generation and invocation. `dispatch-active.json` must be
   absent and `dispatch-op-<key>.json` must not exist. It creates the active marker (fsync), captures the
   exact permit bytes to `dispatch-permit-<key>.bin` (fsync, SHA-256 checked against the identity,
   `:316-324`), writes the DeliveryRequested tombstone, and sets `record.dispatch_in_flight`.
3. `finish_dispatch` (`:1395-1434`) re-verifies the captured permit hash. It records Delivered only if
   `delivered && phase == Running`. Otherwise it records Uncertain and returns an error.
4. `finish_dispatch_uncertain_released` (`:1556-1603`) releases the shared slot only with an
   `rpc_adapter::DispatchFence` for the exact identity (`:1562`). The tombstone stays Uncertain forever,
   and the record is cleared before the active marker.
5. `finish_dispatch_recovered` (`:1440-1549`) promotes DeliveryRequested or Uncertain to Delivered only
   when given a `VerifiedSettlementV3` whose receipt transaction and event equal the identity
   (`:1446-1451`).
6. `verify_dispatch_idle` (`:1032-1062`) is used by checkpoint. It requires Running with nothing in
   flight, no `dispatch-active.json` or `native-dispatch-active.json`, and every historical tombstone
   Delivered.

Tombstone transitions allowed: DeliveryRequested to Delivered, DeliveryRequested to Uncertain, and
Uncertain to Delivered (`:1310-1317`). An exact operation coordinate can never be requested twice
(`:1372-1376`).

### Wire formats emitted by hostd

The **failed-START audit** (`failed_start_projection`, `:693-733`) is a JSON object with protocol
`mini-spk-failed-start-audit-v1` and 18 fields. Section 2.1.4 cross-checks it against the Lean parser.

The **STOP audit** (`source_stop_audit`, `:538-606`) carries hex-encoded unit, invocation and cgroup,
manager booleans, and `observationDigest`. The digest is SHA-256 over a domain tag plus a JSON (serde_json
`Map` is a BTreeMap, so sorted keys and deterministic). It is rendered as a decimal by a hand-written
base-256 to base-10 loop that reads the digest **little-endian** (`:585-602`).

### Processes, files and environment touched

- `/usr/bin/systemctl --user show|stop` through `os::systemctl` (`os.rs:46-48`), bounded at 5 s or 10 s
  (`:383-411`). The stdout pipe is read only after exit; output is under 8 KiB, so the pipe never fills.
- Production `stop_unit` without a broker endpoint refuses (`:368-371`). With `with_broker_endpoint`
  (`:935-939`) it calls `broker::call_at(.., Request::Stop{unit})` (`:940-947`).
- Files under the journal directory: `.lock`, `record.json`, `dispatch-next-id`, `dispatch-id-N`,
  `dispatch-active.json`, `dispatch-op-<key>.json`, `dispatch-permit-<key>.bin`, `.record-*.tmp`,
  `.dispatch-*.tmp`, `qualification-fail-spawn-v1` (feature only).
- `/proc/self/cgroup`, `/proc/<pid>/cgroup`, `/sys/fs/cgroup/<group>/cgroup.events` (`os.rs:51-67`).
- Environment: `INVOCATION_ID` (`:428`). Tests use `XDG_RUNTIME_DIR` and the probe gates
  `MINI_SPK_SYSTEMD_AUDIT_PROBE` and `MINI_SPK_UNIT_INSTANCE_PROBE`.

`Journal::open` (`:897-931`) requires an absolute path whose every ancestor is a directory, not a symlink,
owned by root (or by root through retained namespace provenance, `namespace_identity::root_owned`) or by
the euid, and not group- or world-writable. The leaf must be 0700 and owned by the euid. It is pinned
through `sandbox::open_protected_directory` and a dev/ino comparison. `atomic_write_locked` (`:770-780`)
does create_new temp, fsync, rename, then fsync the parent.

## 1.4 `http_entrance.rs` (2,249 lines; 1,441 code)

The module doc (`:1-5`) says "Bounded Unix-only HTTP entrance for one participant credential
custodian. Transport tokens authenticate use of that custodian; they are not Mini resource authority."
The sentence "the current public binary serves an unavailable response" is stale: `resident-run` serves
real dispatches.

### Custodian directory (`initialize_custodian`, `:306-377`)

It creates a new 0700 directory whose parent must pass `Journal::open`. It reads three 32-byte tokens from
`/dev/urandom` and hex-encodes them (`:282-291`). It writes `browser.token`, `bootstrap.token` and
`api.token` (0600, `create_new`, `O_NOFOLLOW`, fsync), then `custodian.json`. The policy file
(`PolicyFile`, `:128-145`, `deny_unknown_fields`) has these fields:

```json
{"protocol":"mini-spk-custodian-v1","expectedHost":"host[:port]","fixedApp":"N","fixedSubject":"N",
 "fixedSession":"N","fixedSessionKind":"web|api","exportCapture":false,"exportCapturePath":null,
 "fixedTicket":"N","browserTokenSha256":"hex","bootstrapTokenSha256":"hex","apiTokenSha256":"hex"}
```

`CustodianPolicy::load_with_bytes` (`:218-239`) reads with `O_NOFOLLOW` and requires nlink 1, euid owner,
mode 0600 and at most 4096 bytes. `from_bytes` (`:248-279`) checks canonical decimals, the host grammar
(`valid_expected_host`, `:159-190`: lowercase labels, an optional canonical port, at most 255 characters)
and the export-path grammar (`_/<sheet>/csv`, `:154-157`). `initialize_connector_custodian` (`:319-324`)
is the export-capture variant used by `grain_route`.

### The request parser (`parse_head`, `:446-603`; `read_request_until`, `:636-661`)

- One request per connection with an absolute 10 s deadline (`DEADLINE`, `:24`). Head limit 64 KiB
  (`:20`). Body limit 8 MiB (`:21`). Request target at most 8,192 + 1 bytes (`:22`). At most 128 headers
  (`:23`). Header values at most 8,192 bytes (`:493`).
- The request line must be exactly `METHOD SP target SP HTTP/1.1`. Methods: GET, HEAD, POST, PUT, PATCH,
  DELETE (`:59-69`). The target must begin with `/`, contain no `#` and no control bytes, and have at
  most one `?` (`:458-465`).
- Header names are RFC 7230 tokens (`:438-444`). Values may contain no controls except tab and no DEL.
  The whole head must be UTF-8 (`:447`). **Every duplicate header name is refused** (`:500-503`).
- `content-length` must be canonical with no leading zeros (`:518-530`). `transfer-encoding`, `expect`
  and `content-encoding` are refused (`:531-533`). Any `x-sandstorm-*` header is refused (`:534-536`).
  `x-mini-export-capture` is kept out of the signed headers (`:537`). Headers on the allowlist
  `allowed_ordinary_header` (`:415-436`) are kept. **All other headers are silently discarded** (`:539`).
- A WebSocket upgrade must be a bodyless GET. `web_socket::client_handshake` validates it, and the method
  becomes `Method::WebSocket` (`:547-573`). Stray WebSocket headers without `Upgrade` are refused
  (`:549-554`).
- Bootstrap bodies are at most 128 bytes (`:577-579`). GET, HEAD and DELETE with a body are refused
  (`:580-582`). Pipelined extra bytes are refused (`:656-658`).
- `read_until` (`:605-634`) puts the socket in nonblocking mode and **busy-polls with
  `sleep(2ms)`** (`:623-625`). CPU use is bounded but wasteful.

### Transport authentication (`authenticate`, `:670-738`)

1. The `Host` header lowercased must equal `expected_host` (`:671-674`).
2. An `Origin` header, if present, must equal `https://<expected_host>` (`:675-682`).
3. `Sec-Fetch-Site` may be absent or `same-origin`. `none` is allowed only for GET or HEAD whose
   `Sec-Fetch-Mode` is absent or `navigate` and whose `Sec-Fetch-Dest` is absent or `document`
   (`:683-696`).
4. Exactly one credential:
   - `Authorization: Bearer <token>`: the route kind must be Api (`:698-709`).
   - `Cookie` containing exactly one `__Host-mini_spk_session=<token>`: the route kind must be Browser.
     Unsafe methods (WebSocket counts as unsafe, `:71-73`) require an exact `Origin` (`:721-725`). The
     other cookies are forwarded as one `cookie` header (`:726-733`).
5. `token_matches` (`:379-391`) refuses lengths outside 32..256 and non-ASCII. It compares SHA-256
   digests by XOR-accumulate, which is constant time over the digest.

### Bootstrap (`:1311-1381`)

`GET /__mini/bootstrap` (exact path, `:1409`) on a Browser route returns a static form. The headers set
`Cache-Control: no-store`, `Referrer-Policy: no-referrer`,
`Content-Security-Policy: default-src 'none'; form-action 'self'; frame-ancestors 'none'` and nosniff
(`:1329-1334`). The form contains no token.

`POST /__mini/bootstrap` requires an exact `Origin`, `Sec-Fetch-Site` absent or `same-origin`, no
Authorization and no Cookie, `Content-Type: application/x-www-form-urlencoded`, and a body exactly
`token=<64 hex>` matching `bootstrap_token_sha256` (`:1336-1364`). It refuses if `bootstrap.used` exists.
Otherwise it creates `bootstrap.used` with `create_new` and fsyncs the directory **before** answering
`303 Location: /` with `Set-Cookie: __Host-mini_spk_session=<browser.token>; Secure; HttpOnly;
SameSite=Strict; Path=/` (`:1370-1377`). `InvalidData` and `AlreadyExists` become a bodyless 403
(`:1415-1418`). An Api route answers 404 for the bootstrap path (`:1410-1413`). The `exists()` then
`create_new` race resolves safely because a second writer gets `AlreadyExists` and therefore 403.

### Two serving loops

- `serve_resident` (`:1228-1239`) is serial. It is used only by `serve_unavailable`, which only
  `spk-hostd` calls.
- `serve_dynamic_with_aux` (`:960-1145`) is what `resident_service::run` uses
  (`resident_service.rs:1936`). It polls N route listeners plus up to 10 auxiliary fds (agent sockets,
  the app-exit pidfd, checkpoint control, route control, `resident_service.rs:1912-1930`). Accepted
  connections pass `peer_uid == euid` (`:1100`). Admission is bounded by
  `MAX_PENDING_REQUESTS = 16` overall and `MAX_PENDING_PER_SUBJECT = 2` (`:741-742`). Up to
  `MAX_WAITING_CONNECTIONS = 64` overall and `MAX_WAITING_PER_SUBJECT = 16` wait in FIFO order
  (`:749-750`). `QUEUE_DEADLINE = 30 s` (`:743`). A `mini-spk-http-reader` thread parses and
  authenticates each admitted connection and hands the `ParsedRequest` over a `sync_channel(16)`
  (`:977-1022`). The main loop picks the pending request whose subject was served longest ago
  (`fair_pending_index`, `:868-882`). It calls the `dispatch` closure **synchronously on the poll thread**
  (`:1128-1133`). A `mini-spk-http-response` thread writes the reply with a 10 s bound
  (`write_response_bounded`, `:898-933`).
- Typed error replies (`admission_response`, `:883-897`; `dispatch_error_response`, `:934-942`): an
  `io::ErrorKind::WouldBlock` gives 503 with `{"status":"busy","retry":"new-request"}`. `Interrupted`
  gives 503 with `{"status":"uncertain","retry":"exact-recovery-only"}`. Any other error gives the plain
  503 "Mini dispatch admission unavailable".

### Socket custody (`bind_fixed`, `:1153-1219`)

The function takes `.http.lock` (flock, LOCK_NB). A stale `http.sock` is removed only if it is an
euid-owned 0600 socket with nlink 1 whose `connect` returns ConnectionRefused and whose dev and ino did not
change. It binds, chmods to 0600 and records dev and ino. `Drop` removes the socket only if its identity is
unchanged (`:1274-1282`).

## 1.5 `spk-browser-proxy` in depth (`src/bin/spk-browser-proxy.rs`)

- Startup (`main`, `:463-519`) takes `ABS_PRIVATE_CUSTODIAN_DIR LOOPBACK_PORT`. The directory must pass
  `Journal::open` (`:471`). The port must be nonzero and canonical and must match the `:port` suffix of
  `custodian.json` `expectedHost` (`:480-486`). `tls.crt` and `tls.key` must be euid-owned 0600 regular
  files with nlink 1 (`private_file`, `:39-50`). The chain holds 1..8 certificates (`:64-66`). `http.sock`
  must be an euid-owned 0600 socket (`:488-495`). The listener binds `127.0.0.1:port` only (`:496`).
- TLS: TLS 1.3 only, with the single key-exchange group X25519MLKEM768 and no classical fallback
  (`:52-59`, `73-84`). The tests prove that a classical-only client fails the handshake (`:818-824`).
- Concurrency: one thread per connection, at most `MAX_CONNECTIONS = 136` (`:29`, `378-393`). Excess
  connections are accepted and dropped silently (`:501-503`).
- Per connection (`handle`, `:395-461`): the handshake has 10 s. One frame is read within 10 s, with a
  64 KiB head and an 8 MiB body (`read_frame`, `:143-184`). `frame_length` (`:98-141`) checks that the
  request line ends with ` HTTP/1.1` and validates Content-Length. It refuses Transfer-Encoding,
  duplicate lengths and pipelining. The proxy then connects to `http.sock`, writes the frame verbatim, and
  half-closes unless the request is an upgrade.
  - Ordinary replies are buffered up to `MAX_RESPONSE` (8 MiB + 64 KiB) within 30 s, then written
    (`:439-460`).
  - A `101` passes only if the request asked for an upgrade and the response carries matching
    Connection and Upgrade tokens (`:425-433`). It switches to `splice` (`:225-376`), a nonblocking
    two-direction pump with a 64 KiB plaintext queue and a 64 KiB rustls buffer. The pump has **no idle
    deadline** and a 5 s close-drain after client EOF (`:31`, `257-259`, `324-336`).
- The proxy does no authentication of its own and does not parse the HTTP Host. The custodian does both.

## 1.6 `http_response.rs` (606 lines; 375 code)

`serialize_for_origin` (`:197-374`) projects a completed `minidregg_spk_rpc::WebResponse` onto HTTP/1.1.

- Content statuses allowed are 200, 201, 202, 204, 206, 207 and 304; 204 and 304 carry no body
  (`:216-221`). `NoContent` maps to 204 or 205 (`:260-268`). `PreconditionFailed` maps to 412. A
  `Redirect` maps to 301, 303, 307 or 308 through `relative_location` (`:104-124`). `ClientError` must be
  400-499 (`:294-296`). `ServerError` maps to 500.
- App-supplied extra headers: **only `x-oc-mtime` is allowed** (`:318-324`). Set-Cookie may not use the
  reserved `__Host-mini_spk_session` name (`:327-329`). A `__Host-` cookie needs `Path=/` (`:332-334`).
  Every cookie is forced `Secure; SameSite=Strict`. A wrapped "negative" relative expiry renders as
  `Max-Age=0` (`:344-354`). An absolute expiry is formatted with `gmtime_r` (`:158-186`).
- The response always carries `Cache-Control: no-store`, `X-Content-Type-Options: nosniff` and
  `Connection: close`. The head is at most 64 KiB and the body at most 8 MiB (`:315-317`, `366-369`). HEAD
  suppresses the body.
- The `#![allow(dead_code)] // Staged behind Mini's committed dispatch permit route.` at `:6` is stale.
  `serialize_for_origin` is called by `dispatch_delivery.rs:302`, and `serialize` by
  `agent_api_server.rs:705` and `agent_api_lifetime_server_v3.rs:378`.

## 1.7 `endpoint.rs` (314 lines)

This is `spk-hostd serve-status`. Frames are a 4-byte LE length plus JSON (`:157-172`). The length is at
most 12,102,760 + 4096 (`:21`), and the payload is allocated with `vec![0; size]` up front (`:163`). The
request is `{"protocol":"mini-spk-hostd-v1","request_id":"<64 hex>","app":N,"generation":N,"op":"status|begin|dispatch"}`
(`:28-36`, `deny_unknown_fields`). `status` returns phase, unit, transaction and event when the journal
identity matches. `begin` and `dispatch` always return `"outcome":"unavailable"` (`:58-96`). The server
handles one connection at a time with a 10 s deadline and the same nonblocking busy-poll (`:98-134`). It
requires `SO_PEERCRED` uid == euid (`:137-155`). An existing `hostd.sock` is never removed automatically
(`:215-218`), so after a crash an operator must delete it by hand. This is **not** the Host wire: no
operation byte, unrelated to `minidregg-host`.

## 1.8 `web_socket.rs` and `stream_continuity.rs`

### `web_socket.rs` (906 lines; 613 code)

- **The stream authority lease** (`:25-292`). `StreamLease::begin(lifetime)` anchors a deadline before
  Mini authoring. The default is `DEFAULT_LEASE_SECONDS = 60` (`:29`), and the operator can override it
  with `wsAuthorityLeaseSeconds`. `revoke`, `check`, `bind_continuity` (once, with validated
  binding and tip, `:189-203`) and `renewal_delay` (half the lifetime) follow.
  `begin_renewal` (`:217-240`) anchors a new deadline before the probe, picks a fresh nonce and increments
  the attempt counter. `renew(VerifiedContinuity)` (`:244-270`) accepts only the current attempt and
  nonce for the same lease and binding, with a strictly later deadline and a tip that `follows` the old
  tip. `ended()` is a watch plus a timer (`:272-291`).
- **The handshake** (`client_handshake`, `:312-341`): `Upgrade: websocket`, `upgrade` among the
  Connection tokens, version 13, and a key that is 24 base64 characters decoding to 16 bytes. The accept
  value is SHA-1 over key plus GUID (`:343-348`). `protocols` (`:351-371`) allows at most 32 tokens of at
  most 256 bytes each. `switching_protocols` (`:376-388`) never accepts extensions. `cap_refusal`
  (`:391-398`) answers 429 with an `X-Mini-Refusal` header.
- **Limits** (`:401-416`) come from `broker::SizeClass` (`ws_max_open`, `ws_bytes_per_minute`, a Rust
  table in shard B). `OpenSockets` (`:420-452`) is an atomic CAS counter per generation. `ByteBudget`
  (`:456-488`) is a token bucket scaled by nanoseconds per minute.
- **`pump`** (`:512-612`) carries **opaque bytes** both ways in 64 KiB chunks. Each direction calls
  `budget.take` and then `lease.check` before every forward. A biased `select!` on `lease.ended()`
  cancels stalled I/O. When the pump ends it revokes the lease through `CloseLeaseOnDrop` (`:500-505`).
  It writes nothing to Mini. **RFC 6455 frames are not parsed, masked or bounded per frame**; the app
  (`sandstorm-http-bridge`) receives the raw client byte stream through `sendBytes`.

### `stream_continuity.rs` (375 lines)

- `ContinuityBinding` (`:48-80`) holds domain, semantics, app, app_generation, session,
  session_generation, subject, ticket_resource (all canonical decimals at most 4096 digits) and
  `session_fingerprint: [u8;32]`. `ContinuityTip` (`:82-121`) holds height, an optional chain and
  world_root. `follows` (`:99-120`) refuses a lower height, and at equal height refuses a different world
  root or a different chain.
- `digest` (`:22-39`) parses a decimal of at most 2^256-1 into **little-endian** 32 bytes (`bytes[0]` is
  least significant).
- `verify_reply` and `verify_bytes` (`:168-221`) take a `PrivateContinuityReply` that only
  `dispatch_native` constructs from pinned op 152 I/O plus the Lean inspector. The inspection must have
  type `application-stream-continuity-inspection-v1`. Its `frameHex` and `challengeHex` must equal the
  exact payload and challenge bytes. The stream and attempt nonces must match. The binding must equal the
  challenge's binding. The tip must follow the minimum. The challenge is re-checked last.

## 1.9 `route_admission.rs`, `resident_route_control.rs`, `grain_route.rs`

### `route_admission.rs` (236 lines)

`verify_reply` and `verify_bytes` (`:88-151`) take a `PrivateRouteAdmissionReply`, which `dispatch_native`
builds from op 154 plus the inspector (`dispatch_native.rs:1187-1300`, shard C). The inspection must have
type `application-route-admission-inspection-v1`, exact frame and challenge hex, the expected registration
nonce and session kind, and a binding whose selector fields all equal the expectation. The fingerprint is
excluded from that comparison ("The source resolves the fingerprint", `:131-138`). The tip is only
syntax-checked (`:144`).

### `resident_route_control.rs` (1,056 lines; 647 code)

This is an operator-only Unix control socket, `route-control.sock`, inside the journal directory.

- Frames are a 4-byte LE length plus JSON, each at most 16 KiB (`MAX_COMMAND`, `:20`), with an absolute
  2 s read deadline (`:283-315`, `566-569`). `SO_PEERCRED` uid must equal euid (`:563`).
- `RouteRegistration` (`:40-85`) carries protocol `mini-spk-route-register-v1`, a 64-hex registration
  nonce, the expected app, app generation and session generation, absolute clean `directory` and
  `dispatch_custody` paths, SHA-256 of the custody file and of `custodian.json`, a display name and a
  handle.
- `registration_action` (`:152-179`) returns `Seal(i)` for an existing unsealed route with an identical
  immutable identity, `Append(n)` below `MAX_ROUTES = 64` (`:19`), and refuses everything else.
- `prepare` (`:229-263`) reads each file once (`private_bytes`, `:198-226`), compares hashes, runs
  `CustodianPolicy::verify_tokens`, and cross-checks custody against policy (app, session, subject,
  ticket, kind).
- `RouteControl::apply` (`:501-552`) answers a retry with the same nonce and request from memory. A
  reused nonce with a different request is refused. Durable publication (`RegistrationPublisher::publish`,
  `:360-416`: a `.pending-<nonce>.json` written `create_new`, hard-linked to `<nonce>.json`, then the
  pending name removed) must precede the memory update. An interrupted publication poisons the control
  and ends the resident (`:541-550`, `573-577`).
- `refuse_retained_registrations` (`:335-349`) refuses to bind when `route-seals/` holds any entry. So
  **once any route has been sealed or appended, that generation's resident cannot be restarted**; the
  error text says "retained route seal requires lifecycle STOP and a new generation".
- `register` and `register_file` (`:613-646`) are the client. They are reached through
  `spk-host grain register-route --socket S --request R` (`grain.rs:1490-1497`).

### `grain_route.rs` (582 lines; 401 code)

`spk-host grain route PROFILE APP ROUTE_REQUEST.json` (`grain.rs:1532-1534`) builds a participant
route directory under `<state_root>/apps/<app>/routes/<name>`.

- `RouteRequest` (`:103-124`) carries name (1..32 characters of `[a-z0-9-]`), expected_host,
  display_name, preferred_handle, three evidence paths, an optional `manifest_observe_capability`, export
  opt-in, and `participant_key {key_id, key_epoch, public_key_hex, seed_path}`.
- `derive` (`:138-196`) reads retained Mini evidence as JSON:
  - the session birth at `/applicationSessionGrainBirth/applicationSessionBirth/session` (participant,
    session, descriptor, kind, app, sessionOwnerCapability, descriptorOwnerCapability);
  - a receipt that must have `type == "confirmed"` and `confirmation` in installed or replayed
    (`confirmed`, `:86-92`);
  - the ticket issue `request.json` and `receipt-anchor.json`.
  
  It cross-checks app, session, descriptor, subject and kind, and sets
  **`issue_index = acceptedCount - 1`** (`:184`).
- `route` (`:242-365`) creates `routes/` (0700). If the route directory is absent, it builds a
  `.<name>.staging` directory: any old staging is **removed with `remove_dir_all`** (`:288-291`), the
  custodian is initialized, `dispatch-custody.json` (protocol `mini-spk-human-dispatch-custody-v1`, with
  signers `DISPATCH_SLOTS` (4,0), (1,0), (9,0)..(9,3) all pointing at the participant `seedPath`,
  `:28-35`, `198-222`) and `route.json` are written, and the staging directory is renamed into place.
  The function then re-reads and re-checks custody and policy (`:346-349`) and prints the route JSON,
  including `tokenFile` (`api.token` or `bootstrap.token`).

## 1.10 `rpc_adapter.rs` (1,673 lines; 1,063 code), the physical fd 3 driver

- `RpcDriver::from_connected_stream(app, generation, UnixStream)` (`:508-704`) spawns the
  `mini-spk-rpc` thread. It owns a current-thread tokio runtime and a `LocalSet` that drives
  `SupervisorConnection` (spk-rpc) for the whole generation. Commands arrive over `mpsc::channel(8)`:
  `View`, `Dispatch`, `OpenWebSocket` and `Stats` (`:278-307`). Callers wait on a
  `sync_mpsc::sync_channel(1)` reply. **The worker handles commands one at a time**, so one 30 s app call
  blocks every participant's next call.
- The session cache (`session_for`, `:190-253`) is keyed by (app, generation, session, subject, kind)
  (`:79-98`). Reuse requires an equal `projection_fingerprint` and equal `SessionParameters`
  (`same_params`, `:151-160`). At most `MAX_CACHED_SESSIONS = 32`; the least recently used is evicted. A
  failed dispatch evicts its session (`:609-616`).
- Bounds: `MAX_RESPONSE_BYTES = 8 MiB`, `MAX_CALL_TIME = 30 s`, `CANCEL_ACK_GRACE = 2 s` (`:29-32`).
- The fence protocol: `prepare_cancellable` returns a `PrequeueGuard` (`:494-506`). Its
  `abort_no_enqueue` mints a "never enqueued" fence (`:366-371`). `dispatch` and `open_web_socket` return
  a fence only when the worker's reply came back (`CancellableFailure::released`, `:436-444`). A missing
  ACK (deadline or worker exit) returns no fence **and sets `uncertain = true` permanently**
  (`:714-737`, `763-805`, `1017-1040`). After that, `check_bound` and `prepare_cancellable` refuse every
  future call (`:498-501`, `742-747`).
- `StreamLeases` (`:103-149`) holds weak references to live leases. `observe` revokes a lease whose
  binding key and ticket are equal but whose projection changed. `invalidate` revokes leases matching
  (app, subject, session, ticket), optionally restricted to an exact continuity binding.
- `OpenWebSocket` handling (`:619-679`) checks the lease, gets the session, calls `open_web_socket`
  (spk-rpc), checks the lease again, writes the 101 (`write_upgrade`, `:256-272`, asynchronous and bounded
  by the lease), then spawns `pump` and the renewal future on the LocalSet.
- **Sandstorm methods mapped:** `getViewInfo`, `newWebSession`/`newApiSession`, `WebSession` request
  methods through `dispatch_web` (GET, HEAD, POST, PUT, PATCH, DELETE), and `openWebSocket`. Not mapped,
  according to `native/spk-rpc/README.md:28-30,60-61` and `spk-rpc/src/protocol.rs:360,376`: Powerbox
  (and `decode_bridge_config` refuses packages that declare powerbox APIs, `spk-rpc/src/bridge_config.rs:61-66`),
  persistence and SturdyRefs, SandstormApi callbacks other than the identity `getProfile` echo (which
  answers from the supplied `SessionParameters`, README `:64-65`), WebDAV methods and streaming request
  bodies. These fail closed with `capnp::Error::unimplemented`. The spk-rpc README line saying
  "WebSocket ... not connected" is stale, because `spk-rpc/src/web.rs:685` (`open_web_socket`) and `:748`
  (`send_to_app`) exist and are used here.
- `#![allow(dead_code)] // Staged until Mini exposes a checked current-session projection.` (`:6`) is
  stale. The driver is built in `resident_launch.rs:480`. The non-cancellable `dispatch` (`:825-839`) and
  `stats` (`:1053-1061`) are reachable only from `gitweb-session-smoke` and tests.

## 1.11 `dispatch_web_input.rs` (742 lines) and `native_dispatch.rs` (100 lines)

`dispatch_web_input` maps "an already matched Mini request to packaged WebSession values"
(`:1-3`). `project` (`:265-312`) takes the identity from Lean's `matched.principal`
(`identity_id`, `:297`) and the permission bits from `matched.effective_bits` (`:300`). The path comes from
`matched.app_path_and_query` (`:216`, `180`) and the method from `matched.method` (`:272`).

`project_http` (`:314-427`) maps request headers: accept and accept-encoding become weighted lists
(`quality_list`, `:43-81`, RFC 9110 grammar with media parameters kept); cookie becomes `Cookie` structs
(`:83-107`); `if-match` and `if-none-match` become ETag preconditions (`:109-145`); `x-requested-with`,
`x-csrftoken`, `x-csrf-token` and the `oc-*` family become additional headers; `sec-websocket-protocol`
becomes the protocol list for an open only. **Any other header refuses** (`:375-379`). The body is only
for POST, PUT and PATCH. A browser base path must be `https://<valid_expected_host>` (`:405-416`); an API
session has an empty base path.

`preflight_web_input` (`:241-253`) runs the same projection before any Mini authoring
(`dispatch_delivery.rs:97-103`), so an unprojectable request leaves no evidence.

The `#![allow(dead_code)] // No HTTP delivery until native op34/claim join is complete.` at `:4` is stale.

`native_dispatch::parse_op34_response` (`:30-51`) splits one Host stdio frame (LE32 length, opcode 34,
payload) into `CommittedBytes` when the payload starts with `DREGG/APPLICATION/DISPATCH-COMMITTED-PERMIT/v1`
or `OutcomeBytes` when it starts with `DREGG/NATIVE-HOST/OUTCOME/v6`. It does no semantic decoding. It is
used at `dispatch_native.rs:1008`, `:1449`. The `#![allow(dead_code)]` at `:8` is stale.

## 1.12 Install: `install_service.rs` (317 lines) and `install_v3.rs` (914 lines)

These are **one feature in two files**. `install_service` holds the config struct and entry points.
`install_v3` holds the implementation and is a private `#[path]` submodule (`install_service.rs:6-7`)
reading its parent's private items (`install_v3.rs:4`, `super::{invalid, InstallConfig, MAX_CONFIG, MAX_SPK}`).

- `InstallConfig` (`install_service.rs:88-110`, `deny_unknown_fields`) uses protocol
  `mini-spk-resident-install-v2` only (`:115-124`, `129`). Its fields are journal_dir (it must be the
  config's parent, `:130`), source_spk, image_dir (`sha256-<expected>`), expected_raw_sha256, app_uid
  (nonzero and not the euid), deployment_id and host_id (hex64), launch_qualification, mini_host plus its
  SHA, mini_config plus its SHA, mini_operator_socket, begin, claim and completion management custody
  files, completion custodian seed, and completion semantics. No path may be under `/tmp` or `/var/tmp`
  (`:43-45`, `155-167`).
- `prepare` (`:247-249`) calls `install_v3::preflight_prepare` (`install_v3.rs:271-371`). That function
  refuses any existing attempt artifact in either namespace (`:257-269`). It reads the launch
  qualification (`QualifiedLaunch`, `:39-87`), re-hashes the source SPK, calls `qualify_bridge_spk`, and
  preflights the custodian and signers. It authors the launch descriptor through Mini
  (`SourceBoundLaunch::author`), then **reopens the qualifier to detect in-place replacement** (`:93-106`).
  It submits BEGIN once (ops 66, 67, 22 via `lifecycle_v3_native`) and assembles and submits the claim
  (ops 68, 69, 26). It then writes `install-prepared-v2.json`.
- `complete` (`:254-256`) calls `preflight_complete` (`install_v3.rs:373-697`). That function takes a
  flock on the journal directory and re-verifies the installed image. It re-hashes the retained BEGIN,
  claim and committed bytes, rebuilds `AcceptedLaunchBegin` and `CommittedLaunchClaim` from the retained
  JSON, and compares them field by field with the Lean claim inspection `committed-v3.json` (`:493-530`).
  If `install-completed-v2.json` already exists it only checks it and retires markers (`:531-564`).
  Otherwise it archives pure attempts that never reached op 38 (`:589-609`) and either recovers the
  receipt only (op 39) or submits completion (ops 70, 71, 38, `:610-677`).
- `install_service`'s `#![allow(dead_code)] // Enabled only with the matching native descriptor route.`
  (`:4`) is stale. It is reachable from `grain install` (`grain.rs:753`, `758`) and
  `scripts/spk-platform/journey.sh install-prepare|install-complete` (`:222-276`).

## 1.13 `os.rs`, `fixture_os.rs`, `namespace_identity.rs`, `operation_ledger.rs`

### `os.rs` (176 lines)

This is the physical boundary function set: `app_owner`, `runtime_units` (`/run/user/<euid>/systemd/user`),
`systemctl`, `self_cgroup`, `pid_cgroup`, `cgroup_events`, `var_filesystem` (fstat dev comparison plus
fstatvfs), `holds_exactly_identity` (resuid, resgid, no groups, no_new_privs, every capability set zero),
`drop_to_identity` (drop the bounding set, set no_new_privs, setgroups(0), setresgid, setresuid, clear
ambient, clear capabilities, not dumpable) and `child_assume_app_identity` (async-signal-safe,
`:151-175`). It re-exports either `real::*` or `fixture_os::*` (`:8-21`). `root_owner` comes from
`compatible-upgrade-custody` (`:6`).

### `fixture_os.rs` (713 lines, feature only)

This is a modeled operating system rooted at `$MINI_FIXTURE_OS`. It provides a unit manager
(`systemctl_main`, `:490-548`: daemon-reload, show, start, stop, reset-failed), a detached unit runner
(`unit_run_main`, `:551-713`, which records InvocationID and cgroup, kills the session at exit, keeps a
failed InvocationID and starts `OnFailure=`), cgroups modeled as sessions (`:115-163`), mounts from a
registry (`:165-193`), and an identity switch that is a no-op (`drop_to_identity` sets only no_new_privs
and not-dumpable, `:198-205`; `child_assume_app_identity` returns `true`, `:211-213`; `privileged()`
returns `true`, `:67-69`). It is used by `scripts/spk-platform/fixture-v4.sh`. `tests/fixture-os/spk-ingest`
and `spk-var-volume` are bash models of the root helpers (`spk-var-volume:44` writes the mount registry
this file reads).

### `namespace_identity.rs` (175 lines)

`enter` (`:103-175`) runs as the unprivileged operator. It starts the **pinned** bwrap (a path in
`PHYSICAL_BWRAPS` and a matching SHA-256, `:50-73`) with
`--unshare-user --userns-block-fd 4 --info-fd 3`. It reads the child PID and checks its PPid. It opens
`/proc/<pid>/ns/user`, runs `/usr/bin/newuidmap` and `newgidmap` to map exactly {operator, app}
(`:74-84`), releases bwrap, calls `setns(CLONE_NEWUSER)` and `setgroups(0)`, and verifies the maps
(`exact_map`, `:92-95`). `prepare_root_handles` and `root_owned` (`:20-46`) keep `O_PATH` handles to
root-owned ancestors, because inside the namespace root appears as the overflow UID. Callers are in
`resident_privilege` (shard B).

### `operation_ledger.rs` (171 lines)

`allocate_operation_id` (`:25-109`) keeps an append-only decimal log with an flock. The first ID is 1 and
the file then holds `2\n`. It rereads the **whole history on every allocation** to check the exact
sequence (`:90-103`) and refuses once the file exceeds 1 MiB (`:83`). It is used by
`lifecycle_v3_native.rs:428`, `lifecycle_v3_claim_native.rs:224`, `lifecycle_v4_retry_native.rs:569`,
`lifecycle_v3_stop_begin_native.rs:148`, `lifecycle_v3_stop_assembly_native.rs:165` and
`lifecycle_v4_retry_claim_native.rs:216`.

## 1.14 `seccomp/resident-web.policy` (110 lines)

This is the source text compiled by `seccomp.rs:11` (`include_str!`) and passed to bwrap as `--seccomp 6`.

- `default ENOSYS` (`:27`).
- `clone` is allowed only with namespace flags clear (mask `0x7e020000`, `:38`). `clone3` returns ENOSYS
  so glibc falls back to `clone` (`:40`).
- `personality` accepts only 0 and query (`:54`). `ioctl` refuses TIOCSTI and TIOCLINUX (`:86`).
  `socket` accepts only AF_UNIX, AF_INET and AF_INET6 (`:90`).
- Explicit EPERM for unshare, setns, mounts, ptrace and process_vm, bpf, perf, userfaultfd, keyctl,
  io_uring, handle syscalls, fanotify, landlock, modules, kexec, reboot, clock setting, iopl, ldt,
  memfd_secret and page migration (`:99-110`).
- Allowed and worth knowing: `execve` and `execveat`, `setuid`/`setgid`/`setgroups` (harmless with no
  capabilities in a user namespace), unrestricted `prctl`, `seccomp` (a process can only add filters),
  `io_setup`/`io_submit` (legacy AIO), and `mknod` (FIFOs only without CAP_MKNOD).

`spk-sandbox-probe` measures the refusals (section 1.2).

---

# 2. What it assumes of its surroundings

## 2.1 Host protocol operations used, with the Lean cross-check

None of the files in this shard opens a Host socket itself. They reach `minidregg-host` through
`dispatch_native::PrivateOperator::invoke` (`dispatch_native.rs:504-560`, shard C). That function builds an
envelope (version byte `2`, LE32 config length, config, 32-byte Host SHA pin, operation byte, payload) and
sends it framed with LE32 on the owner-private operator socket. Lean inspections are produced by running
the pinned Host binary's `inspect` command (`dispatch_native.rs:494-500`).

### 2.1.1 Operations reached through the code in this shard

| byte | symbol (`protocol/host-operations.json`) | receiver | reached from (this shard) | via |
|---:|---|---|---|---|
| 22 | APPLICATION_LIFECYCLE_BEGIN_SUBMIT | dispatchSession | `install_v3::preflight_prepare` `:315-323` | `lifecycle_v3_native.rs:493` |
| 26 | APPLICATION_LIFECYCLE_CLAIM_SUBMIT | serveFrame | `install_v3.rs:333` | `lifecycle_v3_claim_native.rs:450` |
| 38 | APPLICATION_LIFECYCLE_COMPLETION_SUBMIT | dispatchSession | `install_v3.rs:626`, `669-676` | `lifecycle_v3_completion_native.rs:424` |
| 39 | APPLICATION_LIFECYCLE_COMPLETION_LOOKUP | dispatchSession | `install_v3.rs:623` (`recover_receipt_only`) | `lifecycle_v3_completion_native.rs:470` |
| 66, 67 | APPLICATION_LAUNCH_BEGIN_PLAN / ASSEMBLE | fnDispatch | `install_v3.rs:315` | `lifecycle_v3_native.rs:448,477` |
| 68, 69 | APPLICATION_LAUNCH_CLAIM_PLAN / ASSEMBLE | fnDispatch | `install_v3.rs:324-332` | `lifecycle_v3_claim_native.rs:242,281` |
| 70, 71 | APPLICATION_LAUNCH_COMPLETION_PLAN / ASSEMBLE | fnDispatch | `install_v3.rs:657-668` | `lifecycle_v3_completion_native.rs:237,277` |
| 36, 37 | APPLICATION_DISPATCH_PLAN / ASSEMBLE | fnDispatch / dispatchSession | every HTTP request (`dispatch_delivery.rs:152`) | `dispatch_native.rs:891,923` |
| 34 | APPLICATION_DISPATCH_SUBMIT | serveFrame | unsealed route (`dispatch_native.rs:1068-1074`) | `dispatch_native.rs:1129`, response split by `native_dispatch.rs:30-51` |
| 164 | APPLICATION_ROUTE_BOUND_DISPATCH | serveFrame | sealed route (`resident_route_control.rs:785-805`) | `dispatch_native.rs:24,1129` |
| 152 | APPLICATION_STREAM_RENEW | serveFrame | WebSocket lease renewal | `dispatch_native.rs:698` -> `stream_continuity::verify_reply` |
| 154 | APPLICATION_ROUTE_INSPECT | serveFrame | route registration (`resident_service.rs:2024`) | `dispatch_native.rs:1277` -> `route_admission::verify_reply` |
| 206-209 | APPLICATION_FAILED_START_RECOVERY_{PREPARE,ASSEMBLE,SUBMIT,LOOKUP} | fnDispatch | `hostd::Journal::audit_failed_start` supplies the audit | `grain_export.rs:215-223,490` (shard B) |

Every entry above has `status: active` and `routes: ["operator"]` in the registry. None is public. The
spk-host side therefore needs the owner-private operator socket, never the public ingress.

### 2.1.2 What "200-209" means here

In `protocol/host-operations.json`, codes 200, 203, 204 and 205 are **unallocated**. 201 and 202 are
`RESERVE_RESOURCE_BIRTH_PLAN/ASSEMBLE` (owner `resource-reserve-birth`, public plus operator) and are not
used by spk-host. 206-209 are the failed-START recovery family. `hostd.rs` itself sends **none** of
them. Its link to 206-209 is the physical audit object (2.1.4). `spk-hostd` sends no Host operation at all.

### 2.1.3 Can a lost Host reply cause a second launch?

No, as far as the code in this shard is concerned.

- **BEGIN** (66, 67, 22) and the **claim** (68, 69, 26) are authored once per INSTALL journal. A retry
  after a lost reply finds the attempt artifacts. `install_v3::preflight_prepare_artifacts` refuses
  (`install_v3.rs:257-269`), and `grain install` turns that into an `UNRESOLVED:` error, exit 3
  (`grain.rs:743-752`). Recovery is a manual reconciliation, not a resend.
- **Completion** distinguishes "op 38 requested" (`completion-v2-author/op38-requested.json`). If the
  marker is present, the retry is a receipt-only lookup (op 39). If it is absent, the retry is a fresh
  submit of the same assembled bytes (`install_v3.rs:621-629`). Attempts that never reached op 38 are
  archived, not deleted (`:203-255`, `589-609`).
- **The physical launch** is at most once per generation (section 1.3): the second ExecStart is refused.
- **HTTP dispatch**: the operation ID is allocated and fsynced before authoring
  (`dispatch_delivery.rs:145`). The permit is captured and DeliveryRequested is recorded before fd 3
  (`hostd.rs:1347-1390`). Uncertainty is terminal per operation coordinate (`hostd.rs:1372-1376`). The
  entrance answers `uncertain`/`exact-recovery-only` when any generation-wide marker exists
  (`dispatch_delivery.rs:113-124`).

### 2.1.4 Failed-START audit: Rust encoding against the Lean decoding

| field | Rust (`hostd.rs:722-731`) | Lean (`ApplicationFailedStartRecoveryTools.lean:54-72`) | agree? |
|---|---|---|---|
| protocol | `"mini-spk-failed-start-audit-v1"` | must equal the same string | yes |
| app, generation, operationId, transactionId, eventId | decimal strings | `nat` / `integer`: string, canonical round-trip | yes |
| imageIdentity | `record.image_identity()` (the hex string from the claim, `install_v3.rs:517`) | `bytes` = unhex | yes |
| unit | `record.unit()` | `text` (UTF-8); `validFor` requires `unit = source.processIdentity` | yes in production: `process_identity == unit` (`lifecycle_v3_claim_native.rs:500-515`). The hostd test fixture violates this (`hostd.rs:1963-1975`, `process_identity: "unit-generation-2"`), which only makes that test unrepresentative |
| recordedInvocationId, recordedControlGroup | raw strings | `text` | yes |
| recordPhase | `"entered"` | must equal "entered" | yes |
| childPid | `null` | must be `Json.null` | yes |
| managerLoaded, managerJobEmpty, recordedCgroupUnpopulated | `true` (Rust refuses otherwise, `:708-721`) | `bool`; `validFor` requires true | yes |
| managerActiveState | "failed" or "inactive" | `validFor`: failed or inactive | yes |
| managerMainPid | `"0"` | `nat`; `validFor` requires 0 | yes |
| managerInvocationId, managerControlGroup | the current manager values (empty, or equal to the recorded value) | `validFor`: empty or equal to the recorded value (`ApplicationFailedStartRecoveryReport.lean:62-63`) | yes |

The Lean side additionally requires `reportSource r == j`, an exact JSON round-trip
(`ApplicationFailedStartRecoveryTools.lean:103`). Lean `Json.mkObj` builds an RB map, so key order does not
matter.

### 2.1.5 STOP audit: Rust encoding against the Lean decoding

`hostd.rs:563-604` emits unit, recordedInvocationId and recordedControlGroup (hex), managerLoaded,
managerInactive, managerMainPid (`"0"`), managerJobEmpty, managerInvocationCleared, cgroupUnpopulated and
observationDigest (decimal). `Host/Json.lean:2992-3013` (`launchStopAudit`) requires exactly those 10
keys (`exactObject`) with `decodeHex` for the three byte fields. `Kernel/ApplicationLifecycleCompletionReport.lean:91-99`
(`stopAuditValid`) requires MainPID 0 and every boolean true. They **agree**. The observation digest is
opaque to Lean: Lean stores it but cannot recompute it (question 8.2).

## 2.2 OS facilities

The crate is Linux-only. Every module is cfg-gated and the non-Linux `main` exits 2.

- **systemd user manager**: `systemctl --user show/stop` (`hostd.rs:349-381`); `INVOCATION_ID` and the
  unified cgroup v2 path (`hostd.rs:425-475`). The resident and its units are **user** units of the
  operator (`os.rs:41-43`, `USER-TENANCY.md`), which needs linger.
- **cgroup v2** files `cgroup.events` (`os.rs:61-67`).
- **SO_PEERCRED** on every Unix socket (`http_entrance.rs:1254-1272`, `endpoint.rs:137-155`,
  `resident_route_control.rs:265-282`).
- **flock** for every lock file. **pidfd_open** (`resident_service.rs:1904-1910`). `poll(2)`
  (`http_entrance.rs:1242-1252`, `spk-browser-proxy.rs:337`).
- **bubblewrap** with `--unshare-user --userns-block-fd --info-fd`, `--disable-userns` and `--seccomp`,
  at a pinned path and SHA (`namespace_identity.rs:50-73`).
- **newuidmap/newgidmap** (the `uidmap` package) and an `/etc/subuid` grant (`namespace_identity.rs:149-150`).
- **setresuid/setresgid, prctl capability bounding, no_new_privs, ambient clearing** (`os.rs:126-175`).
- `/dev/urandom` for tokens and nonces (`http_entrance.rs:282-291`, `web_socket.rs:114-118`).
- **git** at `/usr/bin/git` for the gitweb binaries.
- `XDG_RUNTIME_DIR` for tests only.
- No SQLite, no Solana, no Discord, no OpenAI-compatible endpoint, no NNTP. Cap'n Proto through spk-rpc
  only.

## 2.3 Network services

There are none outbound. The only listeners: route Unix sockets (`http.sock`), `route-control.sock`,
`hostd.sock` (spk-hostd only), `spk-browser-proxy` on `127.0.0.1:<port>`, and ephemeral `127.0.0.1:0`
listeners inside `gitweb-smoke.rs:322` and `gitweb-human-journey.rs:608,811`.

## 2.4 File layouts and configuration

- Per-route directory `<state_root>/apps/<app>/routes/<name>/` holds `custodian.json`, `browser.token`,
  `bootstrap.token`, `api.token`, `bootstrap.used`, `.http.lock`, `http.sock`, `dispatch-custody.json`,
  `route.json`, and for the proxy `tls.crt` and `tls.key` (`ws-continuity-launch.py:264-272` creates
  them with openssl).
- Per-generation journal directory (section 1.3 lists its files) plus `route-seals/`,
  `route-control.sock` and `.resident-route-control.lock`.
- The INSTALL journal holds the config JSON, `install-prepared-v2.json`, `install-completed-v2.json`,
  `begin-v3/`, `claim-v3-author/`, `completion-v2-author/`, `materialized-*-v2/`,
  `launch-descriptor/`, and the ledgers `begin-v3-operation-ledger`, `claim-v3-nonce-ledger`.
- Broker config `mini-spk-broker-config-v3` (`deploy/spk-host/mini-spk-broker.example.json`) and the
  host identity `/etc/minidregg/spk/host-identity` (README).

## 2.5 Other crates

- `minidregg-spk-rpc` (path dependency): `SupervisorConnection`, `dispatch_web`, `open_web_socket`,
  `send_to_app`, `WebRequest`, `WebResponse` and `decode_bridge_config`.
- `minidregg-compatible-upgrade-custody` (path dependency; `root_owner`, plus its `fixture-os` feature).
- `minidregg-signed-api-path` (path dependency; not used by this shard's files).
- `sandstorm-package` (git, pinned rev) for SPK parsing in the smoke binaries and in `materialize`.
- Binaries invoked: the pinned `minidregg-host` (operator socket and `inspect`), and `/usr/bin/git`
  (gitweb tools).

## 2.6 Binary -> modules -> Host operations -> unit or journey

| binary | modules reached | Host operations | shipped by candidate? | what runs it |
|---|---|---|---|---|
| `spk-host` | every module, through the verbs in 1.2 | 22, 26, 34, 35, 36, 37, 38, 39, 66-71, 152, 154, 164, 206-209, plus agent-lifetime operations (shard C) | yes, role `spkHost` (`deploy/candidate/package.py:66`) | resident units rendered by the broker; supervisor template; `scripts/spk-platform/jspk1.sh`, `journey.sh`, `prepare-human-entrance.sh:209`, `fixture-v4.sh`; `scripts/pipeline/journey-rows:488`; `deploy/spk-host/spk-ingest` |
| `mini-spk-broker` | broker (and its `#[path]` submodules) | none | yes, `spkBroker` | `deploy/spk-host/mini-spk-broker@.service`; `two-world-journey.sh:46`; journey-rows |
| `mini-spk-volume-helper` | volume_helper | none | yes, `spkVolumeHelper` | `install-user-world` (sudoers), broker |
| `spk-hostd` | endpoint, hostd (open/read), http_entrance (bind, serve_unavailable, initialize_custodian) | none | yes, `spkHostd`, "shipped, not installed by default" | **nothing** |
| `spk-browser-proxy` | rustls; `hostd::Journal::open` as a directory check | none | yes, `spkBrowserProxy` | `ws-continuity-launch.py:274`; evidence `2026-10-02-spk-browser-tls` |
| `spk-smoke` | sandbox, spk-rpc | none | no | nothing now (evidence `deploy/spk-host/SMOKE-2026-09-27.md`) |
| `gitweb-smoke` | sandbox, spk-rpc | none | no | nothing now (`GITWEB-SMOKE-2026-09-27.md`) |
| `gitweb-session-smoke` | its own copy of rpc_adapter, web_socket, stream_continuity; sandbox | none | no | nothing now (`GITWEB-SESSION-PROBE-2026-09-27.md`) |
| `gitweb-human-journey` | none from the library | none (HTTP to `http.sock`) | no | `#[ignore]` test `http_entrance_gitweb_probe.rs`; evidence `2026-09-27-gitweb-human-journey` |
| `spk-sandbox-probe` | none from the library | none | no | `scripts/spk-platform/sandbox-floor-audit.sh` |

---

# 3. Does it decide anything semantic?

Section 3.1 lists places that are, or come close to being, a Rust-owned decision. Section 3.2 lists places
that correctly defer to Lean.

## 3.1 Decisions Rust makes, or nearly makes

| # | where | what Rust decides | Lean counterpart | blast radius if wrong | verdict |
|---|---|---|---|---|---|
| D1 | `grain_route.rs:198-222`, `28-35`; signer seed in custody | The host **holds the participant's signing seed** and signs dispatches as that participant whenever the static cookie or bearer authenticates. Lean receives participant-signed bytes and cannot know a custodian signed them | Lean has no notion of custodial signing. Any declaration distinguishing "member-signed" from "host-on-behalf" would have to be new | Cookie theft means acting as that participant within all of that participant's Lean grants on this app session, permanently (no expiry or rotation, section 4) | **design-level authority delegation decided in Rust.** It is the documented intent (`HTTP-CUSTODIAN-CONTRACT.md`), but no Lean declaration records the delegation |
| D2 | `grain_route.rs:184` | `issue_index = acceptedCount - 1`: the ticket's admitted issue index is inferred from the receipt anchor's accepted count | the ticket issue receipt in Lean (event22). The dispatch plan presumably re-checks the index | Wrong index: Lean refuses every dispatch of that route (fail closed), assuming the plan checks it. Question 8.1 | mirror, if Lean checks the index |
| D3 | `grain_route.rs:86-92`, `155-157` | "is this receipt confirmed": a JSON `type == "confirmed"` and a `confirmation` value of installed or replayed, read from operator files with no signature check | Lean receipts are verifiable by the Host. Route creation does not ask the Host | Operator-only input; per-request admission still runs, so this is UX pre-checking | mirror (fail closed later) |
| D4 | `web_socket.rs:401-416` with `broker::CLASSES` (shard B) | WebSocket concurrency cap and bytes/minute, from a Rust size-class table. README: "the kernel will pin the class in the app birth descriptor, K-SPK" | none yet. K-SPK names the intended Lean pin | Quota policy without a Lean pin. A member can use up to the class cap; the operator can change classes without any Lean record | **violation: quota decided in Rust** (physical enforcement is fine, but the number is policy) |
| D5 | `http_entrance.rs:741-750`, `868-882` | Fairness and admission bounds per subject (2 pending, 16 waiting, 16 total, 30 s queue) | none needed | scheduling only | physical; fine |
| D6 | `resident_route_control.rs:19`, `152-179` | At most 64 routes per generation; a route's identity is immutable once loaded; a seal cannot be replaced | none; Lean admits each route by op 154 | capacity only | physical; fine |
| D7 | `resident_service.rs:2018-2023` | One session or ticket may not be both an agent route and a human route | Lean admits both kinds separately | local refusal only | physical policy; mirrors at worst |
| D8 | `http_entrance.rs:415-436`; `dispatch_web_input.rs:332-381` | Which client headers may reach the app | `Kernel/ApplicationDispatchAdmission.lean:116-120` (`ordinaryHeaderName`) | Dropped headers never reach Lean or the app. An extra Rust header would be refused by Lean's `requestSafeFor` | mirror, but a **hand-copied twin** (law 13) |
| D9 | `http_response.rs:216-221`, `318-334` | Which app response statuses, headers and cookies may reach the browser | none; output sanitizing | over-strict means an app answers 503 (SPK-APPS evidence has examples) | physical safety filter; fine |
| D10 | `stream_continuity.rs:99-120` | The renewal tip must follow the old one (height monotone, equal height means same root and chain) | `ApplicationStreamContinuity` (Lean) produces the inspection. Whether Lean also enforces monotonicity is unknown | A wrong rule refuses a renewal and the stream ends at its lease (fail closed) | mirror, fail closed |
| D11 | `route_admission.rs:144` | The admitted tip is accepted without comparison to anything | Lean op 154 inspection | none locally; it seeds the continuity minimum | defers |
| D12 | `hostd.rs:299-313` | Physical one-shot key = (app, generation, session, session generation, local operation_id). The operation ID is a **local** counter (`hostd.rs:1067-1157`) | the op 34 permit binds the operation ID (`DispatchIdentity.operation_id`) | Replay prevention at the physical layer. Lean's CAS is the authority | physical; fine |
| D13 | `install_v3.rs:554-556` | A completed marker is accepted when the completion acceptedCount is `later_decimal` than the claim's | the Lean receipt | operator file only | mirror |
| D14 | `hostd.rs:708-721`, `674-687` | The physical audit facts: manager state, cgroup emptiness, MainPID | Lean `Audit.validFor` and `stopAuditValid` require them but **cannot check them**; it trusts the custodian signature | These are attestations, and physical observation belongs in Rust by design. A lying operator could get a dead-START recovery for a running app | correct boundary; note that Lean trusts the attester |

## 3.2 Places that correctly defer to Lean

- **Per-request authority.** Every HTTP request and every WebSocket open goes through
  `author_and_submit` (op 36, 37, then 34 or 164) before any fd 3 call (`dispatch_delivery.rs:152-181`).
  Session identity and permission bits come only from Lean's matched inspection
  (`dispatch_web_input.rs:297`, `300`). The path and method come from `matched` (`:216`, `272`).
- **Route registration** needs a fresh op 154 inspection that matches custody
  (`resident_service.rs:2024-2050`, `route_admission.rs:100-151`).
- **Stream renewal** needs an op 152 inspection that matches challenge and nonce
  (`stream_continuity.rs:179-221`).
- **Install and launch identities** are taken from Lean inspections and compared, never invented
  (`install_v3.rs:493-530`). `VerifiedBegin` is built from them.
- **Failed-START and STOP** decisions are Lean receivers (206-209; the completion report). Rust supplies
  only physical audits.
- **`spk-rpc` `SessionParameters`** are "protocol fields, not evidence of authorization"
  (`spk-rpc/README.md:22-27`).

---

# 4. Flaws noticed

## 4.1 Security and trust

1. **Permanent, unrotatable browser credential** (`http_entrance.rs:306-377`, `1365-1377`). The cookie
   value is the browser token written at initialization. Nothing expires it, the cookie has no
   `Max-Age`, there is no logout, and `bootstrap.used` forbids a second bootstrap. Rotating means
   rewriting `custodian.json`, whose SHA-256 is pinned in the route registration
   (`resident_route_control.rs:241-245`), so in practice it means a new route. A leaked cookie or
   `api.token` grants that participant's Lean-admissible powers until Lean revokes the grant. Combined
   with D1, a cookie is equivalent to a signing key.
2. **Bootstrap Host comparison is case-sensitive; authenticate is not.** `bootstrap` compares
   `request.host != policy.expected_host` (`:1317`), while `authenticate` lowercases (`:671`). A browser
   sending `Host: Friend.Example` is refused at bootstrap but accepted afterwards. This is benign (fail
   closed at bootstrap) but inconsistent.
3. **`relative_location` can be bypassed with a tab** (`http_response.rs:104-124`). `field` allows `\t`
   (`:26`). The checks reject a leading `//`, `\`, a colon in the first segment, and leading or trailing
   whitespace, but not an interior tab. Browsers' URL parsers strip ASCII tab and newline, so an app
   redirect to `"/\t/evil.example/"` passes every check and is followed as `//evil.example/`, an open
   redirect off the grain's origin. The comment claims "no open redirect off the grain's origin"
   (`:102-103`). Only the packaged app controls `location`, so the attacker is a malicious app. Fix:
   refuse any control byte, tab included, in `Location`.
4. **A committed TLS private key** (`tests/fixtures/browser-proxy-test.key`). It is documented as a
   public fixture (`BROWSER-WEBSOCKETS.md:35-37`). It is used only by tests, but repository hygiene
   scanners will flag it.
5. **The participant seed path sits in plaintext in route custody** (`grain_route.rs:218-220`). The seed
   is operator-readable by construction: the resident must sign. Deployment must keep the state root
   operator-private. The code checks 0700 and 0600 everywhere.
6. **`spk-browser-proxy` sends no response to unauthenticated requests.** When `authenticate` fails,
   `handle_stream_with` returns `Err` without writing (`http_entrance.rs:1422`), so the client sees a
   closed connection. That violates "refusal must be loud" at the transport level only (the 403 case is
   handled for bootstrap). Operators lose the reason too, because no log line is written on this path
   (the dispatch path logs at `:1436`).

## 4.2 Lost reply, retry and availability

7. **One uncertain dispatch fences the whole grain.** `deliver_once` refuses every new request from any
   participant while `native-dispatch-active.json` or `dispatch-active.json` exists
   (`dispatch_delivery.rs:113-124`), until operator recovery or a matching fence. A single member whose
   requests trigger Mini timeouts can make the app unavailable to everyone. This is intentional fail-closed
   behavior with a large blast radius on a shared demo.
8. **The RPC driver poisons permanently.** One missing worker ACK (a 30 s app stall plus the 2 s grace)
   sets `uncertain = true` forever (`rpc_adapter.rs:763-805`), and every later dispatch of that
   generation fails at `prepare_cancellable` (`:498-501`). The only exit is a generation STOP and START,
   which take 381-453 s in `docs/evidence/2026-10-02-spk-browser-tls/README.md:52-62`. A slow or
   malicious app can cause it.
9. **A sealed or registered route prevents resident restart.** `refuse_retained_registrations`
   (`resident_route_control.rs:335-349`) refuses `RouteControl::bind` when any seal file exists, and
   seals are never removed. Every resident crash after any route registration therefore requires STOP
   plus a new generation. The idempotent-retry cache is in memory only (`:513-525`), so after a crash the
   client cannot learn the outcome of its registration from this socket.
10. **The resident ends on any accept or poll error.** `entrance.listener.accept()?`
    (`http_entrance.rs:1099`), POLLERR, POLLHUP or POLLNVAL on a listener (`:1092-1094`), the same on an
    auxiliary fd (`:1080-1082`), and every thread spawn error (`:1062`, `1065`, `1111`, `1113`, `1142`)
    return `Err` from `serve_dynamic_with_aux`. The resident exits, the unit fails, and the supervisor
    begins a multi-minute STOP and continue-START. EMFILE under load is the realistic trigger.
11. **The dispatch loop is synchronous.** The `dispatch` closure runs on the poll thread
    (`http_entrance.rs:1128-1133`). During one Mini authoring plus an app call (tens of seconds) the loop
    neither accepts, promotes waiters nor expires queued connections. Waiters past 30 s get `busy` only
    after the loop resumes. Throughput is one request at a time per grain (and the fd 3 worker is serial
    too, `rpc_adapter.rs:544-686`).
12. **An interrupted INSTALL prepare is stuck.** If the process dies between `submit_begin_once` and
    writing `install-prepared-v2.json` (`install_v3.rs:315-369`), the next run refuses on the existing
    artifacts (`:257-269`, `grain.rs:743-752`, `UNRESOLVED`). There is no automated recovery
    (receipt-only lookup) for BEGIN or claim in this path, unlike completion. This fails closed but needs
    manual work.
13. **The operation ledger is O(n) and capped at 1 MiB** (`operation_ledger.rs:83`, `90-103`). Every
    allocation rereads the full history. At about 7 bytes a line, about 150K lifecycle operations per
    ledger, after which allocation refuses forever. Lifecycle operations are rare, so this is a latent
    ceiling, not a near-term problem.

## 4.3 Bounds and denial of service

14. **The proxy has no idle deadline after upgrade, and 136 slots.** An authenticated participant can hold
    up to 136 TLS connections forever (`spk-browser-proxy.rs:29`, `224`). Unauthenticated clients can
    occupy a slot for up to 10 s of handshake plus 10 s of frame reading (`:396-407`) in a loop: a cheap
    exhaustion of the 136 slots, after which excess connections are silently dropped (`:501-503`). This
    matters only if the port is exposed.
15. **Proxy memory.** Each ordinary response is buffered whole, up to 8 MiB + 64 KiB (`:439-450`), and each
    request whole, up to 8 MiB (`:143-184`). Worst case is 136 times about 16 MiB, about 2.2 GB, more than
    a small VM has.
16. **Entrance memory.** Up to 16 reader slots buffering 8 MiB bodies (`http_entrance.rs:629`), plus up to
    16 queued `ParsedRequest`s holding bodies, about 256 MiB. That is bounded, but large for a 2-4 GB VM.
17. **`endpoint.rs` allocates the full frame up front** (`endpoint.rs:163`: up to about 12 MB per
    connection on a same-UID socket). It sits in a dead binary.
18. **Busy polling.** `read_until` (`http_entrance.rs:619-625`) and `endpoint::transfer`
    (`endpoint.rs:126-128`) spin with a 2 ms sleep in nonblocking mode instead of using `poll`. The cost
    is CPU only.
19. **WebSocket frames are unbounded per frame.** Only the bytes/minute bucket bounds a socket
    (`web_socket.rs:456-488`). One minute's worth can arrive in a single burst, which the app's bridge must
    handle.

## 4.4 Correctness and code quality

20. **A tautological condition in `finish_dispatch_recovered`** (`hostd.rs:1466-1471`). The check
    "phase is not DeliveryRequested and not Delivered and not Uncertain" can never be true, because the
    enum has exactly those three variants (`:328-332`). It is dead code that suggests a missing state
    check.
21. **`DispatchFence::matches_and_consume` ignores `worker_released`** (`rpc_adapter.rs:326-328`).
    `finish_dispatch_uncertain_released` therefore accepts a "never enqueued" fence and a "worker
    released" fence alike (`hostd.rs:1562`). Both leave the tombstone Uncertain, so this is safe, but the
    type distinction is unused there.
22. **`main.rs:167,170` `.expect`.** A panic would follow if `qualify_bridge_spk` ever returned `Ok`
    without a signed bridge member. That depends on materialize's contract (shard B). Panics in a CLI are
    loud, so this is a minor robustness point.
23. **The route staging directory is removed recursively** (`grain_route.rs:288-291`). A leftover
    `.<name>.staging` is deleted, tokens included, without checking that a previous run created it. The
    path is operator-owned, so the risk is accidental loss, not an attack.
24. **`check_retained_custody` compares only 5 fields** (`grain_route.rs:224-240`: subject, session,
    ticketResource, issueIndex, manifestObserveCapability). It does not compare app, kind or signers.
    `check_retained_policy` covers app and kind, but a changed `participant_key` in a re-run request is
    silently ignored and the old signer kept. That is safe, but the request is not echoed as a refusal.
25. **Stale comments and allow attributes** (section 5.2).
26. **Test fixture inconsistency** (`hostd.rs:1963-1975`): `process_identity` differs from `unit`, which
    Lean would refuse (2.1.4). Tests remain Rust-internal.

## 4.5 Keys, logs and arguments

- Tokens are never printed. `main.rs:153` prints only the directory. `grain route` prints token **file
  paths** (`grain_route.rs:362`).
- `gitweb-human-journey` places the API bearer in an HTTP header on a Unix socket (`:420-421`). The
  per-run proxy token goes into a gitconfig file (`:607`). Neither travels in argv.
- `namespace_identity::map` logs the UIDs (`:75`), which is fine.
- No zeroization of tokens in memory (`String`). Tokens are compared by digest.

---

# 5. Unwired and undone

## 5.1 Unreachable or effectively dead

| item | lines | evidence |
|---|---:|---|
| `spk-hostd` binary | 42 | No unit, script or journey launches it (grep of `deploy/`, `scripts/`, `native/resource-client` finds only the candidate role list `package.py:69` and 2026-09-27 logs). It is shipped all the same |
| `endpoint.rs` | 314 | reachable only from `spk-hostd serve-status` |
| `PrivateHttpEntrance::serve_unavailable` and `serve_resident` | about 20 (`http_entrance.rs:1221-1239`) | reachable only from `spk-hostd` |
| `hostd::Journal::fence_and_stop_manager` (unchecked) | about 21 (`hostd.rs:1749-1769`) | used only by the env-gated test at `hostd.rs:3252` |
| `RpcDriver::dispatch`, `dispatch_inner`, `stats` | about 60 (`rpc_adapter.rs:825-839`, `899-934`, `1053-1061`) | production uses only the cancellable path; these serve `gitweb-session-smoke` and tests |
| `spk-smoke`, `gitweb-smoke`, `gitweb-session-smoke` | 1,048 | no current caller; 2026-09-27 evidence only |
| `gitweb-human-journey` plus `http_entrance_gitweb_probe.rs` | 912 + 208 | `#[ignore]` manual test only |
| `spk-sandbox-probe` | 417 | audit tool (`sandbox-floor-audit.sh`); keep as a measurement, not in a release |
| `fixture_os.rs` plus `tests/fixture-os/*` | 713 + 102 | feature-gated, `fixture-v4.sh` only |

## 5.2 Stale `#![allow(dead_code)]` and stale comments

| site | the text | the reality |
|---|---|---|
| `http_response.rs:6` | "Staged behind Mini's committed dispatch permit route." | used at `dispatch_delivery.rs:302` |
| `rpc_adapter.rs:6` | "Staged until Mini exposes a checked current-session projection." | used at `resident_launch.rs:480`, `dispatch_delivery.rs:188` |
| `dispatch_web_input.rs:4` | "No HTTP delivery until native op34/claim join is complete." | used by `dispatch_delivery` |
| `native_dispatch.rs:8` | "Staged behind Mini's source-owned op34 inspector route." | used at `dispatch_native.rs:1008`, `1449` |
| `install_service.rs:4` | "Enabled only with the matching native descriptor route." | used at `grain.rs:753`, `758` |
| `hostd.rs:810-813` | "mutators are intentionally unreachable from the public binary" | `arm`, `request_launch`, `request_dispatch` and the others are called from `resident_service`, `dispatch_native` and `lifecycle_v3_stop_*` |
| `http_entrance.rs:47`, `80`, `111-122` | "Consumed by the reviewed resident Mini HTTP caller", "Becomes Mini authoring input only after..." | all consumed (`resident_service.rs:2198`, `dispatch_delivery.rs:84-88`) |
| `http_entrance.rs:4-5` | "The current public binary serves an unavailable response" | only `spk-hostd` does; `resident-run` serves real dispatches |
| `spk-hostd.rs:1-2` | "BEGIN and dispatch stay unavailable" | false for the crate |
| `HTTP-CUSTODIAN-CONTRACT.md` | "participant signer and native checked delivery remain unimplemented"; "TLS proxy handles one connection at a time"; "one custodian per participant under a separate Unix account" | the signer and delivery are implemented; the proxy is threaded with 136 slots; all routes live in the resident under the operator UID (`peer_uid == euid`, `http_entrance.rs:1100`) |
| `deploy/spk-host/README.md` | root broker on `/run/mini-spk-broker.sock` | the user-unit broker on `WORLD/runtime-STORE/broker.sock` (`USER-TENANCY.md`, `mini-spk-broker@.service`) |
| `native/spk-rpc/README.md:60` | "WebSocket ... not connected" | `open_web_socket` exists (`spk-rpc/src/web.rs:685`) |

## 5.3 Tests that do not test what they claim

- `hostd.rs:3200-3203` and `3258-3261` **return early and pass** when `MINI_SPK_SYSTEMD_AUDIT_PROBE` or
  `MINI_SPK_UNIT_INSTANCE_PROBE` is unset. They should be `#[ignore]` so that a skip is visible.
- `hostd.rs:2476-2516` (`completed_worker_invalid_http_response_retains_uncertainty...`) asserts that
  `http_response::serialize` refuses a forged header, already covered at `http_response.rs:405-428`, and
  then calls the release with a synthetic fence. The two halves are not connected, so it does not show that
  delivery refuses invalid responses.
- `endpoint.rs:267-278` decodes a request with `app: 0, generation: 0` and asserts only that the decoding
  succeeds. It shows nothing about refusal.
- `rpc_adapter.rs:1457-1483` deliberately shows that zero coordinates are not refused locally. It is
  documented as intentional.
- Every `http_entrance` test is a unit test against fixed byte strings. There is no test of the TLS proxy
  with the real entrance. The integration evidence is `2026-10-02-spk-browser-tls`.

## 5.4 Twins (law 13: delete the twin)

| twin | site A | site B | which is reachable | delete |
|---|---|---|---|---|
| ordinary-header allowlist | `http_entrance.rs:415-436` | `dispatch_web_input.rs:359-361` (plus `332-358`); Lean `ApplicationDispatchAdmission.lean:116-120` | all reachable | generate both Rust lists from the Lean declaration, or have the entrance keep every header and let `requestSafeFor` decide |
| custodian init | `main.rs:142-161` (`spk-host human-custodian-init`) | `spk-hostd.rs:19-22` (`init-custodian`) | A (`prepare-human-entrance.sh:209`) | B, together with all of `spk-hostd` |
| broker entry point | `main.rs:62-70` (`spk-host broker-serve`) | `mini-spk-broker.rs:8-10` | both (`journey-rows`, the user unit) | pick one; the unit uses `mini-spk-broker` |
| monotonic operation IDs | `hostd.rs:1067-1157` (counter plus per-ID marker) | `operation_ledger.rs:25-109` (append log) | both, different call sites | merge into one allocator |
| signed-SPK checker in smokes | `spk-smoke.rs:48-66` | `gitweb-smoke.rs:67-94`, `gitweb-session-smoke.rs:63-87` | none in production | delete with the smokes |
| peer credential helper | `http_entrance.rs:1254-1272` | `endpoint.rs:136-155`, `resident_route_control.rs:265-282` | A and the third | one helper |
| HTTP/1.1 head parsers | `http_entrance.rs:446-603` | `spk-browser-proxy.rs:98-141`, `gitweb-smoke.rs:149-218`, `gitweb-human-journey.rs:300-405`, `203-255` | the proxy plus the entrance in production | the proxy legitimately parses only framing; the gitweb copies go with the harness |
| decimal digest renderers | `hostd.rs:585-602` (SHA-256 to decimal LE) | `stream_continuity.rs:22-39` (decimal to LE bytes) and `canonical_decimal` duplicated in `hostd.rs:264-269`, `34-39`, `http_entrance.rs:147-152`, `resident_route_control.rs:27-32`, `operation_ledger.rs:16-21` | all | one shared codec module, ideally generated from the Lean codec |

## 5.5 Versioned siblings

`install_v3.rs` keeps v1 and v2 artifact namespaces for refusal (`install_service.rs:192-210`,
`install_v3.rs:108-121`; "Historical v1 attempts stay in their own namespace"). Config protocol v1 is
refused (`install_service.rs:115-124`). The `_v3` name now has no living v1 or v2 code beside it, so the
version suffix is residue: `install_v3.rs` could be folded into `install_service.rs`.

---

# 6. Size and shape

## 6.1 Lines per file

The table in the header block gives per-file totals and test counts. Summary:

- Rust files in this shard: 18,501 lines. Tests (`mod tests` to end of file, plus the included gitweb
  probe): about 5,457 (29.5%). Production Rust: about 13,044.
- The largest production files are `hostd.rs` (1,916), `http_entrance.rs` (1,441), `rpc_adapter.rs`
  (1,063), `gitweb-human-journey.rs` (912), `fixture_os.rs` (713), `install_v3.rs` (698), and
  `resident_route_control.rs` (647).

## 6.2 A minimal version that keeps only the demo path

The demo path is: an operator installs an SPK, a participant route is created, the resident serves it, and
a browser reaches it through the TLS proxy.

| drop | lines | reason |
|---|---:|---|
| `src/bin/spk-hostd.rs` | 42 | unwired twin |
| `src/endpoint.rs` | 314 | spk-hostd only |
| `http_entrance::serve_unavailable` and `serve_resident` | about 20 | spk-hostd only |
| `src/bin/spk-smoke.rs` | 146 | historical harness |
| `src/bin/gitweb-smoke.rs` | 590 | historical harness |
| `src/bin/gitweb-session-smoke.rs` | 312 | historical harness (duplicate compilation) |
| `src/bin/gitweb-human-journey.rs` | 912 | manual component tool |
| `src/http_entrance_gitweb_probe.rs` | 208 | ignored test for the above |
| `RpcDriver::dispatch`, `dispatch_inner`, `stats` | about 60 | smoke-only |
| `hostd::fence_and_stop_manager` (unchecked) | about 21 | test-only |
| `main.rs` `broker-serve` arm | 9 | twin of `mini-spk-broker` |
| **subtotal (unconditional)** | **about 2,634** | |
| `src/bin/spk-sandbox-probe.rs` (move to an audit crate) | 417 | measurement tool |
| `src/fixture_os.rs` plus `tests/fixture-os/*` (if fixture journeys are retired) | 713 + 102 | fixture-only |
| **total possible** | **about 3,866** (21% of the shard) | |

Folding `install_v3.rs` into `install_service.rs` and replacing the duplicated decimal, peer-credential and
header helpers with shared modules would save a further estimated 200-300 lines (an estimate, not counted).

---

# 7. Deployability on a small public Linux VM

## 7.1 What must exist on the box

- **Binaries:** `spk-host`, `mini-spk-broker`, `mini-spk-volume-helper`, and `spk-browser-proxy` if
  browsers connect, plus `minidregg-host` pinned by SHA in every config.
- **Users:** an operator account with a systemd user manager and **linger**. An app-UID pool of nologin
  accounts covered by the operator's `/etc/subuid` and `/etc/subgid` grant (`USER-TENANCY.md`).
- **Kernel and system:** cgroup v2 with memory, pids and cpu delegated to the user manager; unprivileged
  user namespaces, or the AppArmor-profiled `mini-grain-bwrap` (`namespace_identity.rs:50`); bubblewrap
  with `--disable-userns` and `--userns-block-fd`; `uidmap`; loop devices and ext4 tools for `/var`
  volumes; seccomp.
- **Root setup:** `install-user-world` (registry and sudoers for the volume helper), the
  `/etc/minidregg/spk/host-identity` file, and the root-owned bwrap.
- **Directories:** the grains root and Store directories with root or operator ancestry and no group or
  world write anywhere on the path (`hostd.rs:904-915`, `http_entrance.rs:219` via `Journal::open`).

## 7.2 What the operator configures

- `mini-spk-broker-config-v3` (store, roots, socket, binary SHAs, bwrap SHA, app UIDs).
- The grain profile, including `wsAuthorityLeaseSeconds` (`WS-AUTHORITY-LEASES.md`).
- Per route: a `ROUTE_REQUEST.json` with the participant **seed path**, `expectedHost`, and TLS
  certificate and key in the route directory (`spk-browser-proxy.rs:61-71`). The certificate must be
  trusted by the participant's browser; there is no ACME support.
- The token handover: the bootstrap token file has to reach the participant out of band.

## 7.3 What is dangerous to expose

- **`spk-browser-proxy` binds 127.0.0.1 only** (`:496`). Making it public needs code changes or a front
  proxy. If someone does that, findings 14 and 15 (slot exhaustion, about 2 GB of buffering) and the
  absence of any per-IP limit apply, and the X25519MLKEM768-only policy excludes clients on OpenSSL older
  than 3.5 (`BROWSER-WEBSOCKETS.md`).
- The operator socket of `minidregg-host`, `route-control.sock`, `broker.sock` and `http.sock` are all
  same-UID Unix sockets. Any process running as the operator UID can use every route's `http.sock`, but
  still needs a token. **It can also read every token file** (they are operator-owned). The operator UID is
  therefore fully trusted. Running Hermes, a Discord entrance or other tenants as that same UID would
  collapse the route boundary.

## 7.4 What a stranger can exercise (port exposed through the proxy)

- The TLS handshake (TLS 1.3 hybrid only) and up to 136 concurrent slots of 10-20 s each.
- `GET /__mini/bootstrap`, which returns the static form, and `POST /__mini/bootstrap` with token
  guesses. The token has 256 bits, so this is not brute-forceable, and a wrong token gets a 403.
- Any other path without a credential gets a closed connection (finding 6). Malformed HTTP is refused at
  parse with the connection closed. No Mini call is made before authentication.
- **Nothing reaches Lean or the app without a valid token.**

## 7.5 What a malicious enrolled member (cookie holder) can exercise

- Any request that Lean admits for that participant's grants, signed by the host as the participant (D1).
- **Availability attacks on the shared grain:**
  - requests that make Mini or the app time out, which leave a generation-wide uncertain marker and fence
    every participant (finding 7), or poison the RPC driver (finding 8), forcing a multi-minute STOP and
    START;
  - up to the class cap of WebSockets (32 for class S, `web_socket.rs:873-887`), each consuming up to the
    class bytes/minute rate, with no idle timeout at the proxy;
  - 16 waiting connections per subject (`http_entrance.rs:750`), queued ahead of that member's own later
    requests (fair across subjects, so other members are not starved by the queue itself, but they are by
    the serial dispatch loop, finding 11).
- The app sees `identity_id = principal` and Lean's permission bits. The member cannot choose either
  (`dispatch_web_input.rs:297-300`).

---

# 8. Questions for the Lean side

1. **Issue index.** `grain_route.rs:184` sets the participant ticket's issue index to
   `receipt.acceptedCount - 1` read from the retained event22 `receipt-anchor.json`. Which Lean
   declaration defines the "issue index" that dispatch authoring and admission check for a ticket, and
   does the op 36 plan or the op 34 admission refuse a dispatch whose custody names the wrong index? (Name
   the field in `ApplicationDispatchAuthority.Ticket` or the plan.)
2. **Opaque observation digest.** `hostd.rs:574-604` computes `observationDigest` as SHA-256 over a JSON
   projection, rendered as a little-endian decimal. Does any Lean declaration recompute or bind this
   digest to the report fields (in `ApplicationLifecycleCompletionReport` or the STOP receiver), or is it
   stored as an uninterpreted attestation? If it is bound, which byte order does Lean's `Digest` <-> Nat
   use?
3. **Byte order of the session fingerprint.** `stream_continuity::digest` (`:22-39`) converts the
   inspection's decimal `sessionFingerprint` into 32 bytes little-endian, and
   `resident_route_control.rs:371-375` hex-renders those bytes for the seal. Which Lean declaration
   renders `sessionFingerprint` in the op 152 and op 154 inspections, and with what Nat <-> bytes order?
   Rust only compares within itself, so a mismatch would show as seals that disagree with Lean's own
   bytes.
4. **Header list bound into the permit?** `dispatch_web_input::project` (`:265-312`) takes method and path
   from `matched` but header values and body from the HTTP request (`http.ordered_headers`, `http.body`).
   Does the Lean `MatchedInspection` (its `physical_request_digest`) commit to the exact ordered header
   list and body that `project_http` maps, so that the projected request is the one Lean admitted? Name
   the declaration that defines `physical_request_digest`.
5. **Header allowlist as generated data.** `Kernel/ApplicationDispatchAdmission.lean:116-120`
   (`ordinaryHeaderName`) is copied by hand into `http_entrance.rs:415-436` and
   `dispatch_web_input.rs:359-361`. Is there, or should there be, a Lean-emitted artifact for this list (a
   JSON emitted at build), so that Rust consumes it rather than imitating it?
6. **Size-class pin (K-SPK).** Which Lean declaration will carry the grain size class (memory, tasks,
   `/var` size, `ws_max_open`, `ws_bytes_per_minute`) so that the Rust `broker::CLASSES` table and
   `web_socket::Limits` become a projection of a Lean-admitted value rather than a Rust policy?
7. **Continuity monotonicity.** `ContinuityTip::follows` (`stream_continuity.rs:99-120`) enforces height
   monotonicity and same-root-at-equal-height in Rust. Does `ApplicationStreamContinuity` (Lean) already
   refuse a renewal inspection whose tip precedes the open's tip, making the Rust check a mirror?
8. **Custodial signing.** Is there a Lean notion that a participant's dispatch was signed by a host
   custodian rather than by the participant's own device (such as a declared custody mode in the session
   birth or ticket)? If not, should the session-birth or ticket schema carry it, so that Lean's audit
   trail does not attribute host-signed dispatches to the member's own key?
9. **Failed-START trust.** `Audit.validFor` (`Kernel/ApplicationFailedStartRecoveryReport.lean:40-63`)
   accepts the physical audit facts on the custodian's signature alone. Which declaration names the
   custodian key that must sign the failed-START report, and is it distinct from the management key that
   authors the recovery (so one compromised operator key cannot do both)?
10. **Route seal recovery.** `resident_route_control::refuse_retained_registrations` forbids restarting a
    resident once any route was registered. Does Lean require a new generation for a re-registration
    (that is, is the op 154 admission or the op 164 binding generation-scoped in a way that makes the
    restart refusal necessary), or could a restarted resident re-admit its sealed routes by op 154 within
    the same generation?

---

*End of shard A report.*
