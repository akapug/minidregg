# spk-host, shard B: grain lifecycle CLI, sandbox and seccomp, broker, resident service, materialize, volumes, descriptors

| field | value |
|---|---|
| Shard | spk-host B: "grain lifecycle CLI, sandbox + seccomp, broker, resident service, materialize, volumes, descriptors" |
| Crate | `native/spk-host` (package `minidregg-spk-host`, workspace member). Shard A covers entry points, hostd, HTTP and routes (`docs/review/2026-10-26-native-crates/spk-host--A-hostd-http-routes.md`). Shard C covers the `lifecycle_v3_*`, `lifecycle_v4_*`, `dispatch_*` and `agent_api_*` modules |
| Date | 2026-10-26 |
| Reviewer | Opus reader, fan-out review of the native crates |
| Method | Every file below was read in full with line numbers. Cross-references were found by grep. The Lean receivers were opened for ops 206-209 and for the inspection types this shard compares. Sandstorm's upstream `src/sandstorm/supervisor.c++` (master, fetched to scratch `spk-B/sandstorm/supervisor.c++`) was read for the sandbox comparison. No build or test was run |

## Files covered

All paths are under `native/spk-host/src/`. The test region is the trailing `#[cfg(test)] mod tests` block, counted from its attribute line to the module's closing brace.

| file | lines | test | code | reached from |
|---|---:|---:|---:|---|
| `grain.rs` (`#[path]` includes `grain_profile_upgrade.rs`, `grain_management.rs` at `:35-38`) | 1,702 | 136 | 1,566 | `spk-host grain ...` (`main.rs:94-111`); supervisor units |
| `grain_export.rs` | 858 | 226 | 632 | `grain export`, `grain install --import`, `grain supervise` (failed-START recovery) |
| `grain_management.rs` | 147 | 92 | 55 | `grain install --management-selector` |
| `grain_profile_upgrade.rs` | 640 | 82 | 558 | every `Host::load`; `grain rebind-profile/adopt-runtime/current-profile/runtime-status/session-intents` |
| `sandbox.rs` | 539 | 140 | 399 | `resident_launch::PreparedResident::prepare`; smoke binaries (`spawn_sandbox`) |
| `seccomp.rs` (compiles `seccomp/resident-web.policy`, 110 lines) | 561 | 164 | 397 | `sandbox.rs:369`, `resident_launch.rs:421` |
| `setid_bound.rs` | 353 | 97 | 256 | only `clear_capabilities` (`os.rs:143,169`); the filter itself is dead |
| `spawn_gate.rs` | 824 | 270 | 554 | `hostd::Journal::enter_and_spawn` (`hostd.rs:1662`), `resident_privilege::worker_inner` |
| `resident_launch.rs` | 683 | 191 | 492 | `resident_service::run`, lifecycle modules (shard C), `install_v3` |
| `resident_privilege.rs` | 689 | 172 | 517 | `spk-host resident-bootstrap` (`main.rs:112-117`), the broker-rendered resident unit's ExecStart |
| `resident_service.rs` | 2,665 | 458 | 2,207 | `resident_privilege::run` (`:509`), `spk-host resident-validate`, `grain start` (`validate_config`) |
| `materialize.rs` | 478 | 21 | 457 | `spk-host materialize/qualify/inspect-installed`, `deploy/spk-host/spk-ingest`, every START |
| `volume_helper.rs` (runs `deploy/spk-host/spk-var-volume` via `include_str!` and `/bin/bash -c`) | 364 | 24 | 340 | `mini-spk-volume-helper` (root, via sudo); broker |
| `volume_custody.rs` | 382 | 45 | 337 | `resident_service.rs:1559`, STOP service and reports (shard C) |
| `broker.rs` (`#[path]` submodules at `:18-28`, `:1381-1382`) | 1,434 | 127 | 1,307 | `mini-spk-broker serve/backup`, `spk-host broker-serve`, `checkpoint-*`, every `grain` verb as a client |
| `broker_endpoint.rs` | 311 | 161 | 150 | broker client and server |
| `broker_runtime_adoption.rs` | 693 | 152 | 541 | broker verbs `adopt-runtime`, `runtime-status`; `runtime_for` on Ingest and InstallUnit |
| `broker_home.rs` | 267 | 44 | 223 | broker `InstallUnit` (validation only; renders nothing) |
| `broker_volume_custody.rs` | 455 | 128 | 327 | root helper Freeze verb, startup recovery |
| `broker_checkpoint.rs` | 222 | 0 | 222 | `spk-host checkpoint-pause-check`, `checkpoint-backup` |
| `checkpoint_control.rs` | 470 | 162 | 308 | resident (`resident_service.rs:1918-1928`), volume helper, broker checkpoint |
| `export_receipt.rs` | 276 | 147 | 129 | `dispatch_delivery.rs:79,304`, `http_entrance.rs:537` |
| `completion_custodian.rs` | 78 | 0 | 78 | resident START, STOP, install, reports |
| `descriptor_native.rs` | 227 | 0 | 227 | `launch_descriptor_native::author_signed_launch` |
| `launch_descriptor_native.rs` | 621 | 177 | 444 | `spk-host qualify-launch`, `grain install` (`grain.rs:522`), `SourceBoundLaunch::author` |
| `claim_descriptor.rs` | 310 | 53 | 257 | **nothing** (dead module) |
| **total** | **16,249** | **3,269 (20.1%)** | **12,980** | |

Context read but not owned: `seccomp/resident-web.policy`; `tests/fixture-os/spk-ingest` and `spk-var-volume`; `os.rs`, `namespace_identity.rs` (shard A); `deploy/spk-host/README.md`, `USER-TENANCY.md`, `SAME-STORE-AND-CHECKPOINT.md`, `PROFILE-UPGRADE.md`, `BROKER-RUNTIME-UPGRADE.md`, `install-user-world`, `spk-var-volume`, `spk-ingest`, `mini-spk-broker.example.json`, `mini-spk-broker@.service`; `scripts/spk-platform/jspk1.sh`, `journey.sh`, `two-world-journey.sh`, `sandbox-floor-audit.sh`; `docs/evidence/2026-10-01-spk-apps/jspk1/rows.tsv`, `docs/evidence/2026-09-30-sandbox-floor/README.md`; `Kernel/ApplicationFailedStartRecoveryReceiver.lean`, `Kernel/ApplicationFailedStartRecoveryIngress.lean`, `Host/ApplicationFailedStartRecoveryTools.lean`, `Host/ApplicationFailedStartEndpoint.lean`, `Host/Main.lean:1405-1425` and `:7621-7646`, `Kernel/ApplicationSpkPackageIdentity.lean:165-195`, `native/signed-api-path/src/lib.rs`, `native/pinned_execution.rs`.

## Executive summary

1. **A compromised resident is the whole world operator.** The resident runs as the operator UID (inside a user namespace whose only privilege is dropped) on the host mount namespace. It has no `ProtectSystem` or `ProtectHome`, because `broker_home::render` always returns an empty drop-in (`broker_home.rs:202-208`). It parses app-controlled Cap'n Proto on fd 3. The broker trusts any peer whose UID is the operator's (`broker.rs:1218`). The management seed, the completion-custodian seed and every participant seed are operator 0600 files. So one fd-3 parser bug in one grain gives an attacker every grain's lifecycle, every participant's signing key and the Mini operator socket. `deploy/spk-host/README.md:89-90` concedes "it is the operator". Nothing narrower exists.
2. **The sandbox is a solid allowlist floor, and it is hand-written.** bwrap runs with `--unshare-{user,pid,ipc,uts,cgroup,net} --disable-userns --cap-drop ALL --seccomp 6 --clearenv`, a read-only image fd at `/`, an ext4 loop volume fd at `/var` and a 128 MiB tmpfs `/tmp` (`sandbox.rs:41-52`). The seccomp policy is default-ENOSYS, with an architecture kill, x32 refusal, refusal of clone namespace flags, and a socket family allowlist. It is a hand-written text file compiled by a hand-written BPF compiler (`seccomp.rs:194-322`). Nothing derives it. Sandstorm's legacy filter blocks things this one allows: AIO (`io_*`), `seccomp`/`PR_SET_SECCOMP`, `vmsplice`, `mbind`/`*_mempolicy`, `set/get_robust_list`, `rseq`, `pkey_mprotect`, DCCP. Sandstorm also sets a dummy hostname, a read-only 4-node `/dev`, `/proc` only on request and `RLIMIT_NOFILE` 1024/4096. spk-host has none of these: the app sees the host's hostname, gets bwrap's writable `/dev` with tty and devpts, and always gets a fresh `/proc`.
3. **The sandbox-floor audit no longer measures the production path and cannot pass.** `resident_launch.rs:578-625` calls `spawn_gate::spawn_bounded`, which now refuses without the bootstrap channel (`spawn_gate.rs:550-553`, `resident_privilege.rs:296-298`). `scripts/spk-platform/sandbox-floor-audit.sh` is unchanged since 2026-09-30. The only floor evidence (`docs/evidence/2026-09-30-sandbox-floor`) measured the earlier root-gate design.
4. **`setid_bound.rs` is dead except one helper.** The filter (`program` and `install`, `:71-214`) is never installed. The resident uses a userns join (`namespace_identity::enter`) and a separate raw-opcode filter (`resident_privilege.rs:51-110`). Including `seccomp.rs`, the crate has **three hand-written BPF assemblers**. README `:78-96` still describes the dead design.
5. **The broker is a per-world user service run as the operator.** It speaks one JSON line per connection, strictly sequentially, with 12 typed verbs (`broker.rs:296-367`). Root is reached only through `sudo mini-spk-volume-helper JSON`, whose root registry `/etc/mini-spk-volumes/<store>.json` pins every path, UID range and helper SHA (`volume_helper.rs:31-56`). The sudoers rule allows any arguments (`install-user-world:159`), but the helper accepts exactly one strictly typed JSON argument (`bin/mini-spk-volume-helper.rs:4-6`) and authenticates `SUDO_UID` against the registry (`volume_helper.rs:121-129`). Running a bash script as root through `/bin/bash -c include_str!(...)` (`volume_helper.rs:219-221`) works, but it is the weakest part of the root boundary: path-based `stat`-then-act on root-owned trees, plus one root `cp` into an app-owned directory (`spk-var-volume:206-211`).
6. **`broker::CLASSES` is quota policy decided in Rust** (`broker.rs:37-90`): memory, CPU, tasks, IO weight, `/var` size, WebSocket concurrency and bytes per minute. The promised K-SPK Lean pin does not exist. Size classes are chosen by the operator's `--class` flag (`grain.rs:1394`, default S) and retained only in operator files.
7. **Failed-START recovery (ops 206-209) agrees with Lean byte for byte and is lookup-first.** The audit JSON, report-source JSON, selector framing, plan and ingress frames, outcome tag v6, "absent" lookup and confirmation labels all match (section 2.1). Resubmitting the same ingress after an "absent" lookup is safe: the Lean nullifier is keyed on (domain, semantics, original claim transactionId) (`Kernel/ApplicationFailedStartRecoveryIngress.lean:51-63`). **But it is v3-only on both sides**: `grain_export.rs:455-480` and `Host/ApplicationFailedStartRecoveryTools.lean:96-101` decode only v3. A failed START on the v4 retry lane cannot be reconciled.
8. **The supervisor loop works but is slow.** A crashed generation goes through OnFailure, `grain supervise-instance`, Mini STOP, then a continue-START of generation N+2. The 10-01 run measured 2,529 s from SIGKILL to the new generation active, and STOP alone took 3,062 s (`rows.tsv`, `s1-kill-a`, `s1-stop-a`). That run predates the store-keyed unit names (10-04), ops 206-209 (10-04), the user-tenancy broker (10-08) and the bwrap-made resident namespace (10-15). **None of the current broker, resident-privilege or recovery code has a recorded run.**
9. **Export and import are signed by the completion custodian key with no domain separation** (`grain_export.rs:113-114`). Import verifies the signature, image hash, package and class, but **never checks `stopReceiptSha256` against the receipt** (`grain_export.rs:171-178`). The Lean `ApplicationGrainExport` (K-SPK) is absent. Whether an archive is a legitimate prior grain state is therefore decided in Rust by an operator-supplied key.
10. **Package identity (SPK signature means app id) is decided by Rust.** The decision is made by `sandstorm-package`, a git dependency on the repository Mini replaces (`Cargo.toml:31`). Lean receives `signedAppId`/`manifestSha256` as opaque fields of the descriptor source and cannot re-verify them.
11. **Resource exhaustion paths.** App UIDs are allocated from a pool of at most 64 per world (`install-user-world:89`) and are never reclaimed: no verb deletes a placement, and the helper's Destroy is unreachable from the broker. Every import is a new resource and consumes a UID. Every ext4 `/var` is fully preallocated (`spk-var-volume:192`). The resident re-parses the full signed SPK (up to 768 MiB decompressed, about 2.2x RSS) on every START inside the app's own class slice (S = 512 MiB) (`resident_service.rs:1419`, `broker.rs:1039`, `materialize.rs:26`). Repeated broker `Backup {}` freezes every running app and writes fresh full copies into `exports/` with no retention.
12. **Exit-on-any-error.** In the resident, any auxiliary-fd error ends the generation: route-control, checkpoint, an agent listener, an accept error, or a client hanging up on the checkpoint socket (`http_entrance.rs:1080-1085`, `checkpoint_control.rs:299-301`). App exit also ends it (`resident_service.rs:1972-1973`). Each generation end costs a STOP plus a START, measured in tens of minutes, and `StartLimitBurst=3` per 1,800 s then leaves the app down. Any member who can crash the app can drive this.
13. **Dead code and twins.**
    - `claim_descriptor.rs` (310 lines) is unreferenced.
    - `BackupTarget`/`Copy` (`broker_volume_custody.rs:276-315`), `start_attested`/`compare_attested_volume`/`compare_open_mount`, the static supervisor template (`broker.rs:705-720`, never instanced) and the visibility drop-in path (`broker.rs:1071-1076`) are dead.
    - The `#![allow(dead_code)]` headers in `spawn_gate`, `resident_launch`, `resident_service`, `descriptor_native`, `launch_descriptor_native` and `volume_custody` are stale.
    - Twins: 8 decimal validators, 9 hex encoders, about 10 bounded private-file readers, 3 interface-comparison blocks, 4 bridge-profile refusals, 3 memfd sealing sites across crates, 2 broker entry points and 3 backup entry points.
14. **The docs are stale in load-bearing places.** `deploy/spk-host/README.md` still describes a root broker on `/run/mini-spk-broker.sock`, `AmbientCapabilities`, `setid_bound`, a oneshot supervisor, a root `mini-spk-broker backup` and `/etc/minidregg/spk/host-identity`. `BROKER-RUNTIME-UPGRADE.md:76` claims socket fallback to `/run/mini-spk-broker.sock` and "root peer credentials". The code is store-scoped, operator-owned and fallback-free.
15. **A demo-minimal cut.** About 2,950 lines can go with no rewire (dead modules, dead blocks, export/import, checkpoint, profile upgrade, runtime adoption). Several hundred more go with small rewires (the v4 retry lane, v2 agents and the export receipt). Section 6 lists them.

---

# 1. What this code is and does

## 1.1 Process and trust topology (as the code builds it today)

```
root (one-shot, sudo)                         operator UID (user systemd manager, linger)
---------------------                         ----------------------------------------------
install-user-world (root setup, once)          mini-spk-broker@STORE.service (Type=exec, NoNewPrivileges=no)
  /etc/mini-spk-volumes/STORE.json (0644)        socket WORLD/runtime-STORE/broker.sock (0600)
  /etc/sudoers.d/mini-spk-STORE                  renders runtime user units under /run/user/UID/systemd/user
  /var/lib/mini-spk-worlds/STORE (root 0755)     spawns spk-ingest (as operator, systemd-run --user)
                                                 calls: sudo -n -- mini-spk-volume-helper '<json>'
mini-spk-volume-helper (root via sudo)  <------  (create/mount/unmount/freeze=export, volumes-status)
  /bin/bash -c "<spk-var-volume>" ...            
  mkfs.ext4, mount -o loop,nosuid,nodev,noatime  spk-host grain ... (operator CLI; client of broker)
  FIFREEZE/FITHAW, e2fsck, debugfs               
                                               mini-spk-s<store>-a<app>-g<gen>.service (resident unit)
                                                 ExecStart=spk-host resident-bootstrap resident.json
                                                 resident_privilege::run:
                                                   bwrap --unshare-user --userns-block-fd -> newuidmap/newgidmap
                                                   setns(userns {operator, app}) -> fork
                                                   parent: drop to operator (0 caps) -> resident_service::run
                                                   child:  drop to app uid (0 caps) -> worker (one launch)
                                                     worker: spawn_gate -> execveat(bwrap, FIXED_ARGS...) -> app
                                                 OnFailure=<prefix>-spk-supervisor@<store>-<app>.service
                                                   ExecStart=spk-host grain supervise-instance ROOT STORE-APP
```

Every box on the right side is the same Unix identity. The root boundary is only the left column.

## 1.2 `broker.rs` and its `#[path]` submodules (3,382 lines in total)

### 1.2.1 Data model

- **`SizeClass` and `CLASSES`** (`broker.rs:40-90`): `S` = `512M`, CPU 50, tasks 256, IO 50, 512 MiB, 32 WebSockets, 4 MiB/min. `M` = `1G`, 100, 512, 100, 1 GiB, 64, 8 MiB/min. `L` = `2G`, 200, 1024, 200, 2 GiB, 128, 16 MiB/min. `class(name)` refuses anything else (`:92-98`).
- **Name and coordinate validators**: `store_key` is 16 lowercase hex (`:100-105`). `decimal` is a canonical non-zero decimal of **at most 18 digits** (`:107-113`). `hex64` is at `:115-120`.
- **`StoreId`, `ResidentUnit`, `resident_unit`, `parse_resident_unit`** (`:127-162`): the unit name `mini-spk-s{store}-a{app}-g{gen}.service`, guarded by an independent inverse parse (`:144-147`).
- **`volume_name`** = `{store}-{app}`, **`app_slice`** = `s{store}-{prefix}-grains-a{app}.slice` and **`supervisor_unit`** = `{prefix}-spk-supervisor@{store}-{app}.service` (`:166-176`).
- **`BrokerConfig`** (`:178-202`), protocol `mini-spk-broker-config-v3` (`:604`), with fields `store`, `grainsRoot`, `spkRoot`, `brokerSocket`, `operatorUser`, `unitPrefix`, `spkHost` and `spkHostSha256`, `bwrap` and `bwrapSha256`, `ingestHelper`, `volumeHelper`, `appUids` and `residentHomeReadOnlyPaths`. The example is `deploy/spk-host/mini-spk-broker.example.json`.
- **`Placement`** (`:574-583`), `mini-spk-broker-placement-v1`: `{store, app, appUid, appGid (== appUid), class}`, stored at `GRAINS/broker/placements/<store>-<app>.json`.
- **`Request`** (`:296-367`): a serde tag `verb`, kebab-case, `deny_unknown_fields`. The verbs are `identify`, `init-store`, `place`, `set-cgroup`, `ingest`, `mount-volume` (with `volumeId` and optional `importSha256`), `unmount`, `adopt-runtime`, `runtime-status`, `install-unit` (with optional `runtimeSha256`), `start`, `stop`, `export-volume` and `backup`.

### 1.2.2 Load (`Broker::load`, `:601-679`)

1. Read the config: operator 0600 and at most 64 KiB (`read_private_operator`, `:376-388`).
2. Require protocol v3, the store key, `grainsRoot` basename equal to the store, `spkRoot` present, a non-empty pool of UIDs that are all at least 100, and a `unitPrefix` of `[a-z0-9-]` with no leading or trailing dash (`:604-620`).
3. Check `grainsRoot == /var/lib/mini-spk-worlds/<store>` and `spkRoot == grainsRoot/spk` (`validate_world_package_namespace`, `:237-245`). Check SPK namespace custody: canonical path, ancestors root- or operator-owned and not group or world writable, `packages` 0755, `inbox` 0700 (`:216-235`).
4. Pin `spk_host` by SHA through `pinned_root_executable` (`:403-420`). That function accepts root **or operator** ownership (`:405`). Pin bwrap through `namespace_identity::pinned_bwrap`, which requires root ownership. `ingest_helper` is checked for ownership only, with no SHA (`:625`).
5. Require equality with the root registry: `grains_root`, `app_uids`, `helper` (`:626-629`).
6. The operator user must match the effective UID and GID, must not be root, must match the registry, and must not be in the pool (`:630-640`). `home_visibility::validate` and `validate_subids` (`:1407-1420`; every pool UID inside `/etc/subuid` and `/etc/subgid` ranges) follow.
7. Every grains-root ancestor must be root- or operator-owned and not group or world writable. The root itself must be root-owned 0755 (`:643-660`).
8. Create the operator 0700 directories `broker/{placements,units,runtimes,unit-runtimes}` and open `broker/broker.log` for append (`:661-672`).

### 1.2.3 Serve loop (`serve`, `:1191-1251`)

The broker refuses root (`:1192`) and sets umask 077. It binds the endpoint through `endpoint::bind`: a lifetime flock on `broker.sock.lock`, refusal to unlink a live socket, then bind, an owner and group check, and chmod 0600 (`broker_endpoint.rs:108-149`). It then renders the static units and runs `daemon-reload` (`:1200`), logs `listening` and loops over `listener.incoming()`.

For each connection, the loop:

1. sets a 10 s read timeout (`:1209`);
2. reads `SO_PEERCRED` (`:1210-1213`);
3. reads up to 16 KiB plus one byte until `\n` (`:1215`);
4. refuses if the peer UID is not the operator (`:1218-1223`);
5. refuses bad framing (`:1224-1226`);
6. decodes the `Request` (`:1227-1228`) and dispatches it with `handle` (`:1230`);
7. writes `{"ok":true,"result":...}` or `{"ok":false,"error":"..."}` (`:1237-1240`) and logs the request, the peer pid/uid/gid and the outcome (`:1241-1247`).

There is one request per connection and no concurrency. Accept errors and `SO_PEERCRED` errors are silently `continue`d (`:1205-1213`). Log write errors are ignored (`:684-685`), and so is the reply write error (`:1248`).

### 1.2.4 Client side (`broker_endpoint.rs`)

- `resolve` (`:6-27`): the only accepted socket is `GRAINS/runtime-<store>/broker.sock`. A configured path must equal it, may contain only `[A-Za-z0-9/_.-]`, and must be shorter than 108 bytes. There is no environment or legacy fallback.
- `call_at` (`:86-94`):
  1. Run `protected_chain` on the root and the runtime directory. Every ancestor must be a directory, not a symlink and not group or world writable, owned by root (`namespace_identity::root_owned`, which also accepts retained root handles) or by the effective UID.
  2. Require the runtime directory to be euid-owned 0700.
  3. Call `selected_call`: open two connections, require the same server pid on both (`:65-74`), exchange `Identify` on the first, require `grainsRoot` and `brokerSocket` to equal the pinned values (`:75-83`), then send the action on the second.
- `exchange` (`:43-64`): a 600 s read timeout, a 10 s write timeout, one newline-terminated request, a write shutdown, then a read of up to 1 MiB and a JSON parse.

### 1.2.5 Verbs (`handle`, `:796-1129`)

Every verb first checks that the store named in the request (or in the unit name) is the broker's own store (`:797-806`).

| verb | lines | what it does | idempotent on retry? |
|---|---|---|---|
| `identify` | 808-810 | returns `{protocol: mini-spk-broker-identity-v1, grainsRoot, brokerSocket, store, packageStore}` | yes |
| `init-store` | 811-842 | creates `GRAINS/<store>` operator 0700 (chown), re-checks it, and returns `stateRoot`, `deploymentId`, `hostId` from the **root registry** | yes |
| `place` | 843-883 | refused while adoption is pending (`require_not_pending`); returns the existing placement, or the first pool UID not bound by any placement file, with `gid = uid`; writes the placement | yes (but never frees UIDs) |
| `set-cgroup` | 884-919 | renders the slice unit (MemoryMax, MemorySwapMax=0, CPUWeight, TasksMax, IOWeight); refuses a class change while units are active; `daemon-reload`; saves the class | yes |
| `ingest` | 920-960 | `runtime_for(store)`; if `packages/sha256-<sha>` is absent, copies `GRAINS/<store>/host/packages/sha256-<sha>/package.spk` (O_NOFOLLOW walk, operator-owned, at most 256 MiB) to `spk/inbox/.grain-<sha>.broker`, re-hashes it, renames it into the inbox, and runs `ingest_helper --root SPK_ROOT spkHost spkHostSha256 INBOX appUid` **as the operator** (`helper`, `:517-535`) | yes (skips when the image exists) |
| `mount-volume` | 961-970 | needs a class; builds the helper request (`Verb::Create`, size from the class, path `GRAINS/vars/<store>-<app>`); `sudo` the helper; writes `broker/volume-<app>.json` (`replace=false`) | yes (Create on an existing registration means mount and attest) |
| `unmount` | 971-975 | refused if any unit of the app is active; helper `Unmount` using the saved `volume-<app>.json` | yes |
| `adopt-runtime` | 976, `broker_runtime_adoption.rs:299-365` | see 1.2.7 | yes for the same admission |
| `runtime-status` | 977, `:103-119` | baseline, pending or ready, plus pins | yes |
| `install-unit` | 978-1082 | see below | yes for the same text |
| `start` | 1083-1096 | the unit must be recorded for its store and its runtime record must match the current runtime; `reset-failed` if failed; `systemctl --user start` | yes |
| `stop` | 1097-1107 | `systemctl --user stop`; then `reset-failed` if failed | yes |
| `backup` | 1108-1115 | `backup_into(GRAINS/broker/backups/<unix-seconds>)` | **no**: a new directory and new export copies on every call |
| `export-volume` | 1116-1127 | refused if active; helper `Freeze` (which copies the image to `GRAINS/<store>/exports/<app>-<nanos>.ext4`) | **no**: a new copy on every call |

`install-unit` in detail (`:978-1082`):

1. `runtime_for` and `check_install_pin` (an adopted store must name its runtime SHA).
2. The placement must have a class.
3. The unit name is computed. The unit is refused if its tag names another store, or if it is unknown to the broker but present on disk or not `inactive` (`:999-1013`).
4. `resident.json` must exist at the fixed path and be operator-owned. Its bytes are read only for `home_visibility::render`, which validates and then **always returns ""** (`broker_home.rs:202-208`).
5. The unit text is rendered (`:1035-1059`):
   - `OnFailure=<supervisor>` and `Type=exec`;
   - `Slice=<app slice>`;
   - `Environment=` with `MINI_SPK_APP_UID/GID`, `MINI_SPK_OPERATOR_UID/GID`, `MINI_SPK_GRAINS_ROOT`, `MINI_SPK_STORE`, `MINI_SPK_UNIT`, `MINI_SPK_BROKER_SOCKET`, `MINI_SPK_BWRAP`, `MINI_SPK_BWRAP_SHA256`;
   - `ExecStart=<spk-host> resident-bootstrap <config>`;
   - `AmbientCapabilities=` (empty), `NoNewPrivileges=no`, `KillMode=control-group`, `UMask=0077`.
   - There is **no** `ProtectSystem`, `ProtectHome`, `PrivateTmp`, `ReadOnlyPaths`, `InaccessiblePaths`, `RestrictAddressFamilies` or `SystemCallFilter`.
6. The store supervisor instance is rendered. The unit tag is written (`replace=false`), then the unit file (`replace=false`). A drop-in would be written if visibility were non-empty, but it never is (`:1071-1076`). Then `daemon-reload` runs and the unit's runtime pin is saved.

### 1.2.6 Static units (`render_static`, `:694-724`)

`render_static` writes `s<store>-<prefix>-grains.slice` (CPU and IO weight 50). It also writes a **template** `<prefix>-spk-supervisor-s<store>@.service`, whose `ExecStart=... grain supervise-instance ROOT %i`.

Nothing instances that template. `OnFailure` names `supervisor_unit()` = `<prefix>-spk-supervisor@<store>-<app>.service`, a concrete file written per app by `render_store_supervisor` (`broker_runtime_adoption.rs:253-281`, text at `:447-461`). Only `scripts/spk-platform/two-world-journey.sh:74` mentions the template name, and only to clean it up. The template is a dead twin of `supervisor_text`.

### 1.2.7 Runtime adoption (`broker_runtime_adoption.rs`)

The per-store record `GRAINS/broker/runtimes/<store>.json` (`mini-spk-broker-runtime-v1`, `:8-27`) holds `{state: pending|ready, admission path and SHA, source profile path and SHA, runtime {spkHost, spkHostSha256}, apps}`.

- **`adoption`** (`:35-71`) re-validates the record against the root `compatible-admission.json`, using `minidregg_compatible_upgrade_custody::{root_bytes, load_evidence, image}`.
- **`runtime_for`** (`:86-102`) returns the adopted runtime pin when the record is ready, refuses while pending, and otherwise returns the baseline from the config.
- **`adopt_runtime`** (`:299-365`) runs these steps:
  1. Load the admission and require the source profile to be uniquely root-admitted and bound to `host-identity.json` (`source_pin`, `:165-201`).
  2. Pin the target spk-host.
  3. `classify_adoption` (`:400-435`): one of new, pending, already-ready, or a refusal.
  4. Require the frozen app set and store quiescence (`store_quiescent`, `:202-252`). Every `g<N>` must have `start-completed-v3.json` (**the v3 name only**; a v4-lane generation has `start-completed-retry-v4.json`) and a STOP `receipt-anchor.json`. Every unit and supervisor must be inactive or failed with no job, MainPID 0 and ControlPID 0, and an unpopulated cgroup.
  5. `complete_adoption` (`:528-540`): persist pending, render supervisors, `daemon-reload`, persist ready.
- **`require_unit_runtime`** (`:375-391`) prevents an older generation's unit from starting under a new runtime.

### 1.2.8 Volume custody running as root (`broker_volume_custody.rs`)

This code runs inside the root helper.

- **`Dir`** (`:10-100`): an fd-relative walk with `O_NOFOLLOW|O_DIRECTORY` and an owner allowlist; `create_dir`, `create` (O_EXCL), `read_root`, `same_leaf` (dev/ino check against the name) and `lock` (`.freeze.lock`, `LOCK_EX|LOCK_NB`).
- **`Frozen::begin`** (`:130-156`): open `GRAINS/vars/<name>` (owner root or the registered UID), require a distinct filesystem, take the freeze lock, recover stale intents, write the intent `{protocol mini-spk-freeze-pending-v1, name, mount_dev, mount_ino}` with fsync, then `FIFREEZE`. EBUSY or EINVAL unlinks the intent. Other errors keep it.
- **`finish` and `Drop`** thaw and clear the intent (`:157-168`). `recover_locked` (`:179-200`) thaws only an intent whose mount dev/ino still match.
- **`export`** (`:235-274`):
  1. Create or open `GRAINS/<store>/exports` (owner = caller UID, mode 0700).
  2. `read_root` the image `volumes/<name>.ext4` and create `exports/<app>-<nanos>.ext4`.
  3. Freeze, `sparse_copy` (SEEK_DATA/SEEK_HOLE, `:207-234`), fsync, hash, thaw.
  4. Run **`e2fsck -fn` and `debugfs -R "ls -l /"` as root** on the copy (`:266-267`, `inspect_copy` at `:316-325`).
  5. `fchown` the copy to the operator. Return `{image, sha256, bytes, frozenMs, e2fsck, rootListing}`.
- **`BackupTarget` and `Copy`** (`:276-315`): **no caller anywhere**.

### 1.2.9 Checkpoint (`broker_checkpoint.rs`)

- `checked` (`:29-180`): read a pause inventory (`mini-spk-checkpoint-pause-inventory-v1`, at most 256 apps). For each app:
  - take the app's `.checkpoint.lock` with `LOCK_EX|LOCK_NB`;
  - require `checkpoint-pause.json` to equal the request, and the `g<N>/checkpoint-<nonce>-pause.json` receipt to equal the pause bytes;
  - require the resident config and `record.json` hashes to be bound;
  - require the journal `Phase::Running` (`hostd::Record::verify_running_instance`) and the active units to be exactly this unit.
  
  Every running registered volume must be covered.
- `backup` (`:189-222`): run the check, then `backup_into` while holding the locks, relabel running grains `paused-frozen-crash-consistent`, and write `checkpoint-grains-backup.json`.

### 1.2.10 The root-only helpers in broker.rs

These are `volume_import`, `volume_pause_bytes`, `volume_recover` and `volume_export` (`:1390-1405`). `volume_request` and `volume_action` are at `:1421-1434`.

## 1.3 `volume_helper.rs` (364) and `deploy/spk-host/spk-var-volume` (325 bash)

### 1.3.1 `volume_helper.rs`

- **`Registry`** (`:17-56`) is read from `/etc/mini-spk-volumes/<store>.json`. The file must be root-owned 0644 with one link and at most 64 KiB, and its ancestors must be root (`custody::root_ancestors`). Required: protocol `mini-spk-volume-registry-v1`, hex deployment and host ids, non-zero operator UID and GID, a non-empty set of distinct app UIDs, **each at least 65536** and not the operator, `grains_root == /var/lib/mini-spk-worlds/<store>`, a root 0755 world root, and the helper pinned by `root_pin(helper, helperSha256)`.
- **`coordinates`** (`:57-68`): request store and deployment equal to the registry, decimal grain, `volume_path == grains_root/vars/<store>-<grain>`, app UID in the pool, hex `volume_id`, and size between 64 and 16384 MiB.
- **`Verb`** (`:76-78`): Create, Mount, Unmount, Freeze, Thaw and Destroy, plus the status verb `volumes-status` (`:93-103`).
- **`authenticate_root`** (`:121-129`): euid 0, `current_exe() == registry.helper`, and `SUDO_UID == registry.operator_uid`.
- **`verb_lock`** (`:130-139`): `volume-custody/verbs.lock`, root 0600, LOCK_EX (LOCK_SH for status), non-blocking.
- **`execute`** (`:248-318`):
  1. At most 16 KiB of input. The JSON selector routes status requests to `execute_status`.
  2. `Registry::load`, `coordinates`, `authenticate_root`, `verb_lock`, then `volume_recover` before any verb (`:263`).
  3. Create: if a registration exists, call `mount_registered` (registration bytes must match exactly, `findmnt`, `mount -o loop,nosuid,nodev,noatime`, script `verify` then `attest`). Otherwise, with an optional import, copy `GRAINS/<store>/imports/<sha>.ext4` (operator walk) to root's `volumes/.import-<name>` (create_new), require the size to be exactly the class size, and re-hash it. Then run script `create` or `create-from`, then `attest`.
  4. Mount re-runs `mount_registered`. Unmount runs `verify` then `umount`. **Freeze runs `verify` then `broker::volume_export`** (Freeze means export). Thaw runs `volume_recover`. Destroy requires an unmounted volume with no attached loop, then deletes the image, conf, witness and mountpoint.
- **`call` and `invoke`** (`:319-331`): `sudo -n -- HELPER '<json>'`, env-cleared, the helper's stderr echoed, stdout parsed as JSON.
- **`volumes_status`** (`:332-340`): the reply re-validates every request against the registry.

### 1.3.2 `script` (`:214-224`)

```rust
Command::new("/bin/bash").arg("-c").arg(include_str!("../../../deploy/spk-host/spk-var-volume"))
    .arg("mini-spk-volume-helper").args(args).env_clear().env("PATH","/usr/sbin:/usr/bin:/sbin:/bin")
```

The script is the compile-time text of `deploy/spk-host/spk-var-volume`. It runs as root with argv validated in Rust and validated again by bash regexes (`spk-var-volume:27-37`).

### 1.3.3 `spk-var-volume`

- **Actions** (`:16-37`): `create`, `create-from`, `verify`, `attest`.
- **Directory checks**: `safe_dir` for root/volumes/vars/attest with exact modes 755/700/711/755 (`:76-103`), plus an ancestor walk (`:92-99`).
- **Locking**: a per-name flock on `attest/<name>.lock` (`:104-108`).
- **Host identity**: read from **`$root/host-identity`** (root 0600, two lines, stat before and after) (`:109-125`).
- **create** (`:157-226`):
  1. `mktemp` an image under `volumes/`, chmod and chown it, `fallocate -l bytes` (**full preallocation**), `mkfs.ext4`.
  2. Hard-link it to the final name, sync, `install -d` the mountpoint 0700, `mount -o loop,nosuid,nodev,noatime`, chown it to the app UID.
  3. For `create-from`, make a stage dir `vars/.import-<name>` owned by the app UID, `cp --reflink=auto` the untrusted image into it **as root**, chown it, then run `blkid -p`, `e2fsck -fn` and `debugfs -R "rdump / $dest"` **as the app UID via `setpriv --reuid --regid --clear-groups --no-new-privs --inh-caps=-all --bounding-set=-all`** (`:49-58`, `:214-216`), then `find -xdev ... -exec chown -h` on residue (`:221`).
- **Common checks**: image mode and size, mountpoint owner and mode, mount options nosuid/nodev/noatime, a loop source whose backing file is this image, ext4 (`:228-246`).
- **create**: write `volumes/<name>.conf` (`app_uid, size_mib, deployment_id, host_id, volume_id`) by temp file plus hard link (`:248-262`).
- **attest** (`:264-324`): `collect_witness` builds the 13-line `DREGG/SPK-VAR-CUSTODY/v1` record: deployment_id, host_id, resource, volume_id, app_uid, quota_bytes, backing, backing_fs (ext4/btrfs UUID or zfs GUID), backing_inode, backing_size, image_ext4_uuid, mount. The script writes it 0644 and re-collects the witness before and after publication (`mv -fT`), and deletes it on drift.

## 1.4 `volume_custody.rs` (382): reading the root witness in the resident and STOP

- `VolumeSite` (`:71-112`) gives the backing, mount and witness paths for `(grains_root, store, resource)`.
- `VolumeWitness::parse` (`:133-200`) parses the exact 13 lines in order. It requires lowercase hex, the resource to be greater than 0, `quota_bytes` between 64 MiB and 16 GiB, `backing_size == quota_bytes`, a stable `backing_fs`, a UUID, and `backing` and `mount` paths equal to the site's paths.
- `read_root_witness` (`:250-310`) walks a root chain, opens the witness O_NOFOLLOW, and requires root ownership (or a retained root handle via `namespace_identity::root_owned`), mode 0644, one link and at most 4 KiB. When `require_recent` is set it also requires an mtime within **120 s** and at most 5 s in the future. It re-stats after the read.
- `read_attested_volume` (`:315-336`) compares app UID, quota, deployment and host ids and source volume id to the caller's pins. `recheck_handoff` (`:220-229`) requires the same file dev/ino and bytes.
- `compare_open_mount` (`:202-218`) has **no production caller** (section 5).

## 1.5 `materialize.rs` (478): signed SPK parse and image publication

- **Bounds**: `MAX_SPK_BYTES` 256 MiB (`:18`). `MAX_DECOMPRESSED_PACKAGE_BYTES` 768 MiB (`:26`, raised from Bread's 256 MiB after 4 of 10 market packages failed). Image modes 0644/0755/0755 (`:30-32`). `MAX_FILES` 100,000. `MAX_DEPTH` 64.
- **`verified_identity`** (`:236-283`):
  1. SHA-256 of the raw bytes.
  2. `sandstorm_package::Spk::parse_with_limit` (signature, archive hash and decompression, all inside the git dependency).
  3. `SpkManifest::from_spk`.
  4. SHA of the signed `sandstorm-manifest` member, and the `sandstorm-http-bridge-config` member if present (at most 64 KiB) with its SHA.
  5. `validate_tree`: names, duplicates, symlink lexical escapes, reserved `var/tmp/proc/dev` must be directories (`:93-132`).
- **`qualify_bridge_spk`** (`:289-317`) refuses `saveIdentityCaps`, `expectAppHooks` and an API path that fails `signed_api_path::checked_prefix`.
- **`materialize_spk`** (`:339-411`):
  1. Parse.
  2. `open_protected_directory(store)`.
  3. Refuse if `sha256-<sha>` exists.
  4. Make the private stage `.spk-stage-<pid>-<nanos>` and `write_tree` (directories 0700, files 0644 or 0755, symlinks last).
  5. Create missing mountpoints, write `package.spk` (0444) and `manifest.json` (0444), chmod directories to 0755, set the stage to 0555.
  6. `renameat2(RENAME_NOREPLACE)`. On error, `cleanup_staging`.
  
  It runs as the operator under `spk-ingest`'s `systemd-run --user` unit (MemoryMax=2G, RuntimeMaxSec=120, LimitFSIZE=256M; `deploy/spk-host/spk-ingest:29-32`).
- **`verify_installed_spk`** (`:417-456`):
  1. `open_protected_directory(image)`.
  2. Require `package.spk` and `manifest.json` to be root- or operator-owned 0444 with one link.
  3. **Re-parse the whole SPK.**
  4. Require the directory name to equal the SHA and `manifest.json` to equal the parsed manifest, then open `root` as protected.
  
  It runs at **every** `grain install` (`ensure_image`, `grain.rs:624`), at every resident START (`resident_service.rs:1419`), and in STOP (`lifecycle_v3_stop_service`, shard C).

## 1.6 Descriptors: `descriptor_native.rs`, `launch_descriptor_native.rs`, `claim_descriptor.rs`, `completion_custodian.rs`

The pattern is the same throughout. Rust writes a JSON *source* built from one signature-verified parse. The pinned Lean Host `author`s canonical bytes. Lean `inspect`s those bytes back to JSON. Rust compares every inspected field to its own parse, and keeps the canonical bytes (never Rust-encoded ones).

- **`descriptor_native::author_signed_package`** (`:91-227`):
  1. `schema-source.json` (from `materialize::signed_schema_source`).
  2. Author and inspect `application-permission-schema`; require the type `minidregg-application-permission-schema-v1`, the canonical echo, and `version`, `permissions`, `roles` and `denied` equal to the source; the root must be decimal.
  3. `descriptor-source.json` (`rawSha256`, `rawLength`, `signedAppId`, `signedAppVersion`, `manifestSha256`, `bridgeConfigSha256`, `bridgeApiPath`, `signedSchema`).
  4. Author and inspect `application-spk-package-identity`. The type must be `signed_api_path::descriptor_inspection_type(api_path)`: `...-v1` for no API or `/repo.git/`, `...-v2` otherwise. Every field must echo. `imageIdentity == "DREGG/SPK-IMAGE/v1" || raw_sha256_bytes` is **recomputed in Rust** (`:177-178`, `:183`). The interfaces must be exactly `[("1","web")]` or `[("1","web"),("2","api")]` with schema and schemaRoot equal (`:199-220`).
- **`launch_descriptor_native`**:
  - `OfflineSourceHost::run_step` (`:126-221`): check the Host and config SHA pins, read the input (at most 22 MiB for author, about 12.1 MB for inspect), require the output to be absent, **exec the Host by path** with the args `config command kind input output` and stdio nulled, poll with a 600 s deadline (kill and reap on timeout), bound-check the output, then re-check the pins and the input bytes.
  - `qualify_launch` (`:246-292`) runs `spk-host qualify-launch` and `grain install`. It writes `qualification.json` (`mini-spk-launch-qualified-v2`).
  - `signed_launch_source` (`:320-338`): create commands (1 to 64 actions) and the continue command, as `argvHex`/`environHex`, validated by `sandbox::validate_command`.
  - `author_signed_launch` (`:379-443`): the v1 package, then author and inspect `application-spk-launch-descriptor`. The type must be `launch_inspection_type`: `...-v2` for package v1, `...-v3` for package v2. The command echoes are checked and the digests collected.
- **`claim_descriptor.rs`** compares `application-lifecycle-claim-committed-v2` inspections. **No caller** (section 5).
- **`completion_custodian::preflight_custodian`** (`:30-78`) requires the seed's public key to equal the pinned Host config's `completionCustodianKey`, and requires canonical `domain` and semantics.

## 1.7 Sandbox: `sandbox.rs`, `seccomp.rs`, `spawn_gate.rs`, `resident_privilege.rs`, `resident_launch.rs`, `setid_bound.rs`

### 1.7.1 The full profile of an SPK app as launched in production

The path is `resident_service::run` → `PreparedResident::prepare` (`resident_launch.rs:389-448`) → `Journal::enter_and_spawn` (`hostd.rs:1650-1662`) → `spawn_gate::spawn_bounded` → `resident_privilege::launch` → the worker → `spawn_gate::spawn_as_self` → `spawn_inner` → `child_exec`.

**Identity layer** (`resident_privilege::run`, `:466-516`, and `namespace_identity::enter`):

1. The unit environment names the operator and app UID/GID, each at least 100, distinct, with `app.gid == app.uid` (`:467-479`).
2. The root registry must agree (operator UID and GID, app UID in the pool, grains root). The config path must equal `grains_root/store/host/apps/<grain>/g<gen>/resident.json` (`:476-481`).
3. `namespace_identity::prepare_root_handles` retains O_PATH handles for root-owned ancestors (they appear as overflow UIDs inside the userns).
4. `namespace_identity::enter` (`namespace_identity.rs:103-175`) runs the pinned bwrap with `--unshare-user --die-with-parent --info-fd 3 --userns-block-fd 4 --ro-bind / / -- /usr/bin/true`. It reads the child pid, checks the child's PPid and that its user namespace is new, then runs `newuidmap PID op op 1 app app 1` and `newgidmap ...` (env cleared), releases bwrap, requires exit 0, calls `setns(CLONE_NEWUSER)` and `setgroups(0)`, and requires `/proc/self/{uid,gid}_map` to be exactly the two rows.
5. `fork()` (`:487`):
   - **Child (worker)**: `drop_to_identity(app)` (`os.rs:126-149`: drop every bounding cap, no_new_privs, setgroups(0), setresgid, setresuid, clear ambient caps, capset to zero, non-dumpable), then `holds_exactly_identity` (`os.rs:112-122`). It closes every fd except the channel (`close_range`), clears the environment, and waits for exactly one launch frame: tag 1 plus 5 fds plus `Launch{program, sha256, args}` with deny_unknown_fields and at most 1 MiB (`:336-359`). It spawns, installs `install_parser_namespace_filter`, replies `{pid, start}` (the start time from `/proc/<pid>/stat` field 22), then serves only tag 2 (try_wait) or tag 3 (kill and reap) until reaped (`:424-451`).
   - **Parent (resident)**: `drop_to_identity(operator)` and `install_parser_namespace_filter` (`:497-498`), stores `LAUNCH = Client{...}` (`:501-508`), then calls `resident_service::run` (`:509`).

**The spawn gate in the worker** (`spawn_gate.rs`):

- `validate` (`:54-97`): an absolute program whose file name is `bwrap` or `mini-grain-bwrap`, a 64-hex SHA, non-zero UID and GID, args within the derived bounds (`MAX_BWRAP_ARGS`/`MAX_BWRAP_ARG_BYTES`, `sandbox.rs:65-68`), no NUL, and five distinct source fds, each at least 10 and open.
- `pinned_executable` (`:165-225`): a protected parent, O_NOFOLLOW, a regular file not owned by the app, not group or world writable, at most 64 MiB, executable by the exact post-drop UID/GID with no supplementary groups (the mode bits or the POSIX access ACL, `acl_execute_permits`, `:114-140`), and the SHA must match. The result is an fd duplicated to 16 or higher.
- `spawn_inner` (`:423-537`): `fork()`. The child calls `child_exec` (`:266-330`): dup2 to fds 3/4/5/6, clear CLOEXEC on them, stdin `/dev/null`, stdout and stderr to the app output pipe, close everything else, `PR_SET_NO_NEW_PRIVS`, `child_assume_app_identity` (a no-op when already the app identity), and **`execveat(executable_fd, "", argv, environ=[], AT_EMPTY_PATH)`**. The parent waits for the CLOEXEC status pipe with a 10 s deadline and kills and reaps on any failure.

**bwrap arguments** (`sandbox.rs:41-52`, built by `bwrap_args` at `:330-344`):

```
--die-with-parent --new-session
--unshare-user --disable-userns --unshare-pid --unshare-ipc --unshare-uts --unshare-cgroup --unshare-net
--cap-drop ALL
--seccomp 6
--clearenv --ro-bind-fd 4 / --bind-fd 5 /var
--size 134217728 --tmpfs /tmp --proc /proc --dev /dev --chdir /
--setenv HOME /var --setenv TMPDIR /tmp --setenv PATH /usr/bin:/bin
[--setenv K V]...   (package environ, in order, duplicates kept)
-- argv...          (the signed create or continue command)
```

| property | value | where |
|---|---|---|
| UID inside | the host app UID (no `--uid`); the nested userns maps only that UID | `sandbox.rs:41-52` |
| capabilities | none (`--cap-drop ALL`); no_new_privs (set by the gate before exec) | `sandbox.rs:45`, `spawn_gate.rs:314` |
| user namespaces | nested ones refused (`--disable-userns`, plus seccomp `unshare`/`setns` EPERM and clone flags) | `sandbox.rs:43`, policy `:38`, `:99` |
| filesystem | image read-only at `/` via fd 4 (operator- or root-owned tree; ancestors not app-owned or writable, `open_protected_directory`, `sandbox.rs:175-219`); `/var` read-write via fd 5 (a separate filesystem, at most the configured cap and 16 GiB, app-owned 0700, `verify_var_volume`, `:245-259`); `/tmp` tmpfs 128 MiB; fresh `/proc`; bwrap `/dev` | `sandbox.rs:41-52` |
| network | a private netns with only loopback (`--unshare-net`); socket families limited to AF_UNIX, AF_INET, AF_INET6 | policy `:90` |
| fds | 0 `/dev/null`, 1 and 2 the output pipe, 3 the Cap'n Proto socket; bwrap consumes 4/5/6 | `sandbox.rs:30-36` |
| output | `journal/app-output-r<res>-g<gen>.log`, new 0600, 16 MiB kept, the rest counted | `sandbox.rs:70-72`, `:125-170` |
| resources | no cgroup of its own; the resident unit's cgroup inside `Slice=<app class slice>` (MemoryMax, TasksMax, CPU and IO weight, MemorySwapMax=0), **shared with the resident** | `sandbox.rs:90-93`, `broker.rs:1039`, `:899-903` |
| hostname | **the host's** (no `--hostname`) | `sandbox.rs:41-52` |
| rlimits | inherited (systemd defaults); none set | none |

### 1.7.2 The seccomp policy (`seccomp/resident-web.policy`, compiled by `seccomp.rs`)

The grammar is `default/allow/deny/allow-arg ... in|notin|clear ... else ERRNO` (policy `:13-24`; parser `seccomp.rs:194-259`). Only the errnos EPERM, ENOSYS and EAFNOSUPPORT are accepted (`:176-183`). A name may appear at most once. Names absent on aarch64 are skipped; unknown names are errors (`:138-148`).

The program (`compile`, `:263-322`):

1. Load the architecture; kill if it is not `AUDIT_ARCH`.
2. Load nr; on x86_64, refuse nr ≥ 0x40000000 with EPERM.
3. One JEQ per rule in file order. The allow-arg blocks load the low 32 bits of an argument and test `in`, `notin` or `clear`.
4. A final `RET ERRNO|default`. The program is bounded by BPF_MAXINSNS (4096).

It is delivered through `resident_filter_fd` (`:361-396`): a memfd, a write loop, `F_SEAL_SEAL|SHRINK|GROW|WRITE`, then lseek to 0.

Policy semantics:

- `default ENOSYS` (`:27`).
- **Allowed without restriction**:
  - memory: brk, mmap, munmap, mremap, mprotect, madvise, msync, mincore, mlock family, `get_mempolicy`, `set_mempolicy`, `mbind`, membarrier, `rseq`;
  - threads and futex: set_tid_address, `set/get_robust_list`, futex, futex_waitv, `arch_prctl`, **`prctl` (every option)**;
  - processes: exit, execve, **execveat**, fork, vfork, wait4, waitid, the getters, `setsid`/`setpgid`, **all `set*id`**, capget, capset, rlimits (**`setrlimit`/`prlimit64`**), scheduler calls, ioprio, `pkey_*`, uname, sysinfo, umask, times, **`seccomp`**;
  - signals and timers: all `rt_sig*`, kill, tkill, tgkill, pause, `pidfd_open`, `pidfd_send_signal`, every timer and clock read;
  - files: the whole read, write and metadata set, including `mknod(at)`, `chown`, xattrs, `sendfile`/`copy_file_range`/`splice`/`tee`/**`vmsplice`**, `memfd_create`, inotify, poll/select/epoll, **`io_setup`/`io_submit`/`io_cancel`/`io_getevents`/`io_destroy`** (legacy AIO), getrandom;
  - sockets: socketpair, bind, listen, accept, connect, send and recv families, sockopts;
  - IPC: SysV shm, sem and msg, and POSIX mq.
- **Argument-restricted**:
  - `clone` arg0 must have none of `0x7e020000` set (NEWNS, NEWCGROUP, NEWUTS, NEWIPC, NEWUSER, NEWPID, NEWNET), else EPERM (`:38`).
  - `personality` arg0 must be 0 or 0xffffffff (`:54`).
  - `ioctl` arg1 must not be 0x5412 (TIOCSTI) or 0x541c (TIOCLINUX); the low 32 bits only (`:86`).
  - `socket` arg0 must be 1, 2 or 10, else EAFNOSUPPORT (`:90`).
- **ENOSYS**: `clone3` (so glibc falls back to clone) (`:40`).
- **EPERM**: unshare, setns; the mount family; ptrace, process_vm_*, pidfd_getfd, kcmp, process_madvise; bpf, perf_event_open, userfaultfd; keyctl, add_key, request_key; io_uring_*; *_by_handle_at; fanotify_*; landlock_*; module and kexec calls, reboot; swapon/off, acct, quotactl, syslog, vhangup; clock and time setting, sethostname, setdomainname; iopl, ioperm, modify_ldt, uselib, memfd_secret, migrate_pages, move_pages (`:99-110`).

### 1.7.3 The resident's and worker's own filter (`install_parser_namespace_filter`, `resident_privilege.rs:51-110`)

It is written as raw opcodes:

- a foreign architecture is killed, and so are x32 numbers;
- `unshare` and `setns` get EPERM;
- `clone3` gets ENOSYS;
- `clone` with `NEWCGROUP|NEWIPC|NEWNET|NEWNS|NEWPID|NEWUSER|NEWUTS|0x80` gets EPERM;
- everything else is allowed.

It is installed with TSYNC. This is the only syscall restriction on the process that parses app Cap'n Proto.

### 1.7.4 `setid_bound.rs`

It assembles a label-based filter: `setresuid`/`setresgid` only when all three ids equal the app ids, `setgroups` only with an empty list, other set*id calls EPERM (`:71-123`). It installs that filter with TSYNC (`:187-214`) and provides `holds_setid_capabilities` (`:247-255`).

**None of these three is called.** Only `clear_capabilities` (`:232-244`) is used (`os.rs:143`, `:169`). The module doc (`:1-11`) describes the superseded design in which the resident held ambient CAP_SETUID and CAP_SETGID.

### 1.7.5 Comparison with Sandstorm's grain sandbox

Source: upstream `src/sandstorm/supervisor.c++`, read from the scratch copy. Line numbers are those of that file.

| aspect | Sandstorm | spk-host | gap |
|---|---|---|---|
| seccomp model | default-allow denylist with libseccomp (`setupSeccompLegacy`, `:1088-1245`); BADARCH and x32 give ENOSYS | default-ENOSYS allowlist, architecture kill, x32 EPERM | spk-host is stricter by construction |
| AIO | `io_setup/destroy/getevents/submit/cancel` ENOSYS ("AIO is scary", `:1197-1201`) | allowed (policy `:82`) | **gap** |
| filter installation by the app | `prctl(PR_SET_SECCOMP)` EINVAL and `seccomp` ENOSYS (`:1221-1223`) | `prctl` and `seccomp` both allowed (`:33`, `:55`) | **gap** (in-kernel BPF attack surface) |
| scary VM calls | `remap_file_pages`, `mbind`, `get/set_mempolicy`, `migrate_pages`, `move_pages`, `vmsplice` ENOSYS (`:1204-1210`) | migrate_pages and move_pages EPERM; **mbind, mempolicy and vmsplice allowed**; remap_file_pages default-ENOSYS (not listed) | **partial gap** |
| robust futex | `set/get_robust_list` ENOSYS (`:1213-1214`) | allowed | gap (minor; glibc uses them) |
| new calls | `userfaultfd`, `io_pgetevents`, `rseq`, `pkey_mprotect` ENOSYS (`:1229-1232`) | userfaultfd EPERM; io_pgetevents default ENOSYS; **rseq and pkey_* allowed** | minor |
| socket types | DCCP refused (`:1169`) | type unchecked | minor (DCCP absent from modern kernels) |
| socket families | denylist of exotic families (`:1133-1157`) | allowlist {1, 2, 10} | spk-host is stricter |
| user namespaces | `unshare` ENOSYS; clone NEWUSER EPERM | unshare and setns EPERM, every clone namespace flag EPERM, `--disable-userns` | spk-host is stricter |
| ptrace | EPERM | EPERM | same |
| hostname | dummy set after UTS unshare (`:932`) | **the host's is visible** | **gap** (information leak) |
| `/dev` | read-only tmpfs (size 1m, 16 inodes) with null, zero, random→urandom, urandom, plus a separate tmpfs `/dev/shm` (`:986-1007`) | bwrap `--dev` (null, zero, full, random, urandom, tty, devpts/ptmx, shm), writable | **gap** (tty and pty, unbounded writable tmpfs) |
| `/proc` | only when requested (`mountProc`, `:1023-1033`, `:1278-1294`) | always a fresh procfs | gap |
| `/tmp` | per-run tmpfs (`mountTmpFs`) | 128 MiB tmpfs | same, with a size cap |
| rlimits | `RLIMIT_NOFILE` 1024/4096 (`:840-846`) | none | gap (TasksMax only) |
| network | a new netns with loopback configured (`unshareNetwork`, `:1249-1275`) | bwrap `--unshare-net` | same |
| storage quota | none at the grain level (accounting only) | ext4 loop volume of the class size | spk-host is stricter |
| memory and CPU | none per grain | systemd slice per class | spk-host is stricter |
| supervisor isolation | the supervisor chroots to the grain dir, drops superuser, installs the same filter (`runSupervisor`, `:2415-2420`) | the resident is the operator on the host filesystem with namespace-only seccomp | **major gap** (section 4 F1) |
| uid inside | `sandboxUid` (1000 in practice) | host subordinate UID (≥ 65536) | cosmetic |

### 1.7.6 `resident_launch.rs` (683)

- **`SourceBoundLaunch`** (`:89-352`) pairs an `InstalledPackage` with its `SourceLaunchDescriptor`. `author` delegates to `author_signed_launch`. `load_retained` (`:121-305`) rebuilds the descriptor after a restart without authoring: it reads the retained `schema.bin`, `descriptor.bin`, `launch-source.json` and `launch-descriptor.bin` and re-inspects each through the live operator tool, with the same comparisons as `descriptor_native`, copied. `source_selected_create` and `source_selected_continue` (`:317-351`) select the signed command only by the exact Lean digest.
- **`PreparedResident::prepare`** (`:389-448`) repeats the `spawn_sandbox` checks (open protected image and `/var`, no overlap, mountpoints, `verify_var_volume`, `verify_executable`), makes the socketpair, the seccomp memfd and the output pipe, and builds the `SpawnSpec`. `start` (`:474-482`) runs `journal.enter_and_spawn`, then `RpcDriver::from_connected_stream`. `start_attested` and `compare_attested_volume` (`:453-469`) have no caller.
- The root audit tests (`:521-625`) are `#[ignore]` and are run by `sandbox-floor-audit.sh`.

## 1.8 `resident_service.rs` (2,665): the long-lived resident

### 1.8.1 Config

`ResidentConfig` (`:160-212`), protocol `mini-spk-resident-start-v3`. It is at most 16 KiB × 65 (`:66-69`) and is checked by `ResidentConfig::load` (`:1118-1246`):

- every attempt directory and ledger is a child of `journalDir`;
- the hex pins are valid, the store key is valid and the unit carries the store;
- there are 1 to 64 entrances and at most 8 agents;
- the size class is valid and the WebSocket lease is in range;
- the paths are absolute;
- entrances are unique and agents are disjoint (`agent_socket_parent_overlap`, `:463-473`).

`ResidentBound::from_unit_environment` and `validate` (`:1255-1310`) require the config's app UID/GID, grains root, store, bwrap SHA and broker socket to equal the broker-rendered environment.

### 1.8.2 START (`run`, `:1362-1899`)

1. `require_parser` (bootstrap done, operator identity exact). Bound and config validation. `refuse_retained_pause` (a checkpoint pause fences every generation). `refuse_retained_registrations` (shard A). `Journal::open(...).with_broker_endpoint`.
2. **If the journal record exists**, run `reconcile_prior_start` (`:999-1116`): load the retained admitted START (lane v3 or v4, `StartLane::of_journal`, `:288-307`), require the journal to equal the claim, and if op 38 was requested without completion, look up op 39 and retain the receipt. Retire the active markers, audit the physical state, write `start-reconciliation-<rand>.json`, and **return Err** ("source STOP is required"). The unit fails and the supervisor takes over.
3. Otherwise run `reconcile_uncertain_submit` (`:897-997`). If an op 22 or op 26 marker has no outcome, look up op 23 or op 27, write `start-submit-reconciliation-<rand>.json` and return Err. Then `Journal::preflight_current_unit`, and refuse if any attempt artifact exists (`:1385-1418`).
4. `verify_installed_spk` (a full SPK re-parse) (`:1419`). Protected parents for the Mini host, config, socket and seed (`:1422-1434`). The raw SHA pin. `preflight_custodian`. Completion signers.
5. `load_fixed_entrances` (`:1320-1360`): each custody and policy pair must agree. Agent preflights for V2 or V3 custody (`:1456-1511`).
6. `SourceBoundLaunch::author` (a fresh Lean author and inspect of three descriptors) (`:1512`). `QualifiedLaunch::matches` against `qualification.json` (`:416-436`). The bridge API path must equal the descriptor's.
7. BEGIN, claim and completion signer custody (`:1533-1555`). `read_attested_volume`, which must be fresh (120 s) and match the pins (`:1559-1571`).
8. `submit_v3_begin` or `submit_v4_begin` (shard C) (`:1572-1602`). The volume id must equal the witness. Select the command by the Lean digest (`:1606-1620`). Build the `SandboxSpec` and run `PreparedResident::prepare` (`:1625-1639`).
9. Assemble and submit the claim, v3 or v4 (`:1640-1668`). The claim's unit, app and image identity must equal the config (`:1669-1677`).
10. **Write `start-admitted-{v3|retry-v4}.json`** (`:1757-1758`). Then `journal.arm` and `journal.request_launch`, and `prepared.start` (**the app launches**) (`:1759-1761`).
11. `get_view_info` with a 30 s timeout must equal the signed bridge `view_info` (`:1764-1769`). Prepare the running report, assemble and submit the completion (op 70 then op 38) (`:1770-1855`). Write `start-completed-*.json` and retire the markers (`:1856-1881`).
12. Bind the HTTP entrances and agent listeners. Open a pidfd on the bwrap child (`:1903-1910`). Bind route control and the checkpoint control socket (`:1911-1930`). Read the WebSocket limits from `broker::class(size_class)` (`:1933`).

### 1.8.3 Event loop (`serve_dynamic_with_aux` callback, `:1936-2142`)

- **HTTP**: return `busy` if checkpoint-paused. Otherwise `deliver_request`, then `ResidentHuman::deliver_once` (`dispatch_delivery`, shard C). Errors become an HTTP error response (`http_entrance.rs:1128-1133`).
- **The app-exit pidfd**: return `Err("app process exited; this generation ends")` (`:1972-1974`).
- **The checkpoint socket**: `poll_once` with a drain closure that runs `rpc.checkpoint_drain_streams` and then waits up to 2 s for WebSockets to close, using `thread::sleep` on the event loop (`:1975-1990`).
- **While paused**: route control refuses every mutation, and agents are accepted and dropped unread (`:1991-2001`).
- **Route control** (`:2002-2096`):
  1. `registration_action`, `prepare`, the API path check, a protected directory, no agent overlap.
  2. **`operator.admit_resident_route`** (op 154; `dispatch_native`, shard C) (`:2024-2030`).
  3. The binding fields must equal the custody (`:2040-2050`).
  4. Bind the entrance and **publish before updating memory** (`:2074`). Then append or seal.
- **Agents**: `poll_once` for V2 or V3 (`:2097-2141`).

Any `Err` from the callback for an auxiliary fd ends `serve_dynamic_with_aux` (`http_entrance.rs:1084`), and therefore ends the resident and the unit.

### 1.8.4 Projection (`project_request`, `:2180-2204`)

The method, the canonical relative path (no leading slash) and the ordinary headers become an `HttpProjection` with `Route::Browser` or `Route::Api{signed_path}`.

## 1.9 `checkpoint_control.rs` (470)

- The wire is LE32 length plus JSON of at most 4096 bytes. The reply is LE32 plus JSON. Peer UID must equal euid (non-matching peers are silently dropped, `:273-275`). The timeouts are 2 s (`:267-302`).
- **`Request`** = `{protocol mini-spk-checkpoint-control-v1, action pause|resume, nonceHex, binding{app, generation, journalDir, residentConfig, residentConfigSha256, miniConfigSha256}}` (`:24-41`).
- **`process`** (`:160-266`):
  - **pause**: `publish(app_dir/checkpoint-pause.json, intent)`, then drain, then verify, then `publish(g<N>/checkpoint-<nonce>-pause.json)`.
  - **resume**: `publish(g<N>/checkpoint-<nonce>-resume.json)`, then unlink the pause marker. A completed resume replays idempotently.
  - **verify** is `journal.verify_dispatch_idle`.
  - Publication reuses `hostd::atomic_write_locked`.
- **`refuse_retained_pause`** (`:112-123`) refuses startup of every generation while a pause marker exists.

## 1.10 `export_receipt.rs` (276)

- `requested` (`:24-66`) applies only when the policy enables export capture. It requires GET, an empty body, no Upgrade header, the exact `export_capture_path` with no query, and a 32-hex capture id. The capture header must never appear in the Mini-signed header list.
- `prepare` (`:70-128`) parses the app response header (at most 64 KiB, HTTP/1.1 200), refuses an app-supplied `X-Mini-Export-Receipt`, and injects `X-Mini-Export-Receipt: hex(JSON)`. The JSON (`type mini-spk-export-custody-v1`) holds the app, generation, subject, session, operation, transaction, event, request digest, permit SHA, path, query and body SHA. **It is not signed.** It says so itself ("host/TLS custody; kernel admits request, not response body", `:115`).

## 1.11 `grain.rs` (1,702) with `grain_management.rs` and `grain_profile_upgrade.rs`

### 1.11.1 CLI (`grain::run`, `:1463-1554`; `main.rs:94-111` exits 3 on `UNRESOLVED:`)

| verb | args | function | lines | Host ops / broker verbs | run by |
|---|---|---|---|---|---|
| `unit-name` | STORE APP GEN | `broker::resident_unit` | 1464-1466 | none | `two-world-journey.sh:156`, `ws-continuity-launch.py:223`, `same-store-app.py:264` |
| `init-store` | ROOT HOST CONFIG [--broker-socket S] | `init_store` | 1425-1461, 1467-1476, 1505-1509 | **runs `HOST CONFIG profile` unpinned**; broker `init-store` | same-store-profile.py, journeys |
| `current-profile` | BASELINE | `profile_upgrade::current_profile` | 476-488 | none | none found |
| `runtime-status` | PROFILE | `profile_upgrade::runtime_status` | 490-497 | broker `runtime-status` | none found |
| `adopt-runtime` | PROFILE ADMISSION | `profile_upgrade::adopt_runtime` | 520-557 | broker `adopt-runtime` | none found |
| `register-route` | --socket S --request R | `resident_route_control::register_file` (shard A) | 1490-1499 | the resident's route control, then op 154 | `app-document-provision.py:155`, `ws-continuity-*.py` |
| `rebind-profile` | OLD ADMISSION | `profile_upgrade::rebind` | 371-422 | none | none found |
| `supervise-instance` | ROOT STORE-APP | `supervise` via the selected profile | 1510-1521 | as `supervise` | supervisor unit ExecStart |
| `install` | PROFILE SOURCE RECEIPT SPK [--class] [--import D --exporter-key K] [--management-selector P] | `install` | 674-785 | INSTALL ops through `install_service` (shard A/C: 22, 26, 38, 39, 66-71); broker `place`, `set-cgroup`, `ingest`, `mount-volume` | jspk1.sh, same-store-app.py |
| `route` | PROFILE APP REQUEST | `grain_route::route` (shard A) | 1538-1540 | none | journeys |
| `start` | PROFILE APP | `start_inner(false)` | 974-1170 | broker `runtime-status`, `mount-volume`, `install-unit`, `start`; the resident does the ops | jspk1.sh |
| `prepare-resident` | PROFILE APP | `start_inner(true)` | 1125, 1542 | broker `runtime-status`, `mount-volume` | `prepare-resident-config.sh:6` |
| `stop` | PROFILE APP | `stop` | 1174-1218 | broker `install-unit`, `mount-volume`; `lifecycle_v3_stop_service::run` (shard C) | jspk1.sh |
| `status` | PROFILE APP | `status` | 1220-1253 | systemctl show | jspk1.sh |
| `session-intents` | PROFILE APP | `profile_upgrade::session_intents` | 424-473 | none | none found |
| `supervise` | PROFILE APP | `supervise` | 1261-1310 | STOP and START, or ops 206-209 | jspk1.sh:322 |
| `export` | PROFILE APP OUT | `export` | 1315-1358 | broker `export-volume` | jspk1.sh |
| `backup` | PROFILE | broker `backup` | 1548 | broker `backup` | jspk1.sh |

`usage()` (`:1376-1386`) omits `unit-name` and `prepare-resident`.

### 1.11.2 `Host::load` (`:242-304`)

1. Refuse root. Read the profile (`mini-spk-grain-host-v2`, operator 0600).
2. Take a shared lock on `.profile-selection.lock` and run `validate_selected`: the path must be the active selection, and the lineage is validated back to the root-admitted original (`grain_profile_upgrade.rs:128-302`).
3. Pin bwrap and spk-host by SHA. Root or operator ownership is accepted (`:178-193`).
4. Read `host-identity.json`. Run `PrivateOperator::store_tag`; the state root must be `grains_root/<storeTag>/host`.
5. Run `lifecycle_selector::pinned_management`; the subject must equal the profile's.

### 1.11.3 `install` (`:674-785`)

1. `admitted_application` (`:351-384`) reads the birth source and receipt, which must be `type == confirmed` and `installed|replayed`. The selector is taken from the birth. `app_observe_capability` is set to `appOwnerCapability`, and the package observe capability likewise.
2. An optional delegation runs `grain_management::select` (`grain_management.rs:20-54`). A member-owned app without a delegation is refused.
3. `stage_package` (`:474-531`): copy the SPK into `packages/sha256-<sha>/package.spk` and run `qualify_launch`. An interrupted qualification is renamed aside and repeated.
4. An optional import runs `grain_export::verify_import`.
5. `place` (`:422-469`): broker `place`, `set-cgroup` and `package_image_at`, written once to `placement.json` (`mini-spk-grain-placement-v2`).
6. `write_custody` (`:562-598`): three custody files with fixed slot tables (`:54-63`) and the single management key.
7. `install.json` (`mini-spk-resident-install-v2`). Run `install_service::prepare` unless prepared; an attempt artifact without a prepared record gives `UNRESOLVED` (`:742-754`).
8. `ensure_image` (broker `ingest` plus `verify_installed_spk`). `install_service::complete`. `mount_volume` with the Lean `volumeIdHex` and the optional import SHA.

### 1.11.4 Run state (`scan_runs`, `:817-897`)

Each `g<N>` directory is classified:

| state | condition |
|---|---|
| **Stopped** | `failed-start-recovered-v1.json` is present and valid (`:838-857`); or completed with a STOP `receipt-anchor.json` (following at most 8 `replan` levels, `stop_receipt`, `:1361-1374`) |
| **Uncertain("STOP...")** | completed and `stop.json` present without a receipt |
| **Running** | completed with no STOP |
| **Uncertain("START...")** | admitted, `begin-attempt`, the v3 active marker, `begin-attempt-retry-v4` or the v4 active marker present without completion |
| **NeverBegun** | none of the above |

### 1.11.5 `start_inner` (`:974-1170`)

1. Require a ready runtime (broker).
2. Load the placement, the install record and the prepared/completed records.
3. Any Running generation returns `already running`. Any Uncertain one returns `UNRESOLVED`. A Stopped one without `stop_generation` returns `UNRESOLVED`.
4. Reuse a NeverBegun generation (its descriptor attempt is renamed aside). Otherwise the generation is `max(observed generations, stop generations, install generation) + 1` (`:1040-1048`).
5. The start action is `create{index:0}` if no created generation exists. Otherwise it is `continue{createdIndex: acceptedCount - 1}`, taken from the prior create's completion receipt (`:1049-1062`).
6. At least one route is required. Call `mount_volume`.
7. Write `resident.json` once (`derived_file`) and run `validate_config`.
8. `install_unit` and broker `start`. Poll every 500 ms until the completed marker and every route's `http.sock` exist; error out if the unit is neither active nor activating; `UNRESOLVED` after **1,800 s** (`START_WAIT`, `:42-50`).

### 1.11.6 `stop` (`:1174-1218`)

The target is the latest Running generation, or one in Uncertain("STOP"). The verb writes `stop.json`, runs `install_unit` (idempotent) and `mount_volume` (a fresh witness), then runs `lifecycle_v3_stop_service::run` (shard C).

### 1.11.7 `supervise` (`:1261-1310`)

| latest state | action |
|---|---|
| Stopped | none |
| Uncertain("START") | `grain_export::reconcile_failed_start` (ops 206-209) |
| Uncertain("STOP") | `stop`, then `start` |
| another Uncertain | `UNRESOLVED` (exit 3; the unit has `RestartPreventExitStatus=3`) |
| Running and the unit active | none |
| Running and the unit not active | `stop`, then `start` |

The supervisor unit has `Restart=on-failure`, `RestartSec=30`, `StartLimitIntervalSec=1800` and `StartLimitBurst=3` (`broker_runtime_adoption.rs:457-460`).

### 1.11.8 `export` (`:1315-1358`)

The latest generation must be Stopped with a STOP receipt. The verb calls broker `export-volume`, then `grain_export::write_export`.

### 1.11.9 `grain_profile_upgrade.rs`

- `derive` (`:174-248`) computes the successor profile from a root `compatible-admission.json`. Only the Mini Host, spk-host and config path/hash pairs and the genesis config SHA change, and the management socket changes only if the admission adopts it.
- `rebind` (`:371-422`) takes an exclusive lock and requires every generation Stopped with quiescent units (`stopped`, `:304-369`). It writes `upgrades/<tx>/grain-host.json`, then the immutable selection record, then atomically replaces `active-profile.json`.
- `validate_lineage` (`:253-302`) walks at most 32 levels.
- `require_ready_runtime` (`:499-518`) and `adopt_runtime` (`:520-557`) pin the broker reply fields.

### 1.11.10 `grain_management.rs`

`select` (`:20-54`) checks a `mini-spk-grain-lifecycle-delegation-v1` document:

- owner and manager must equal the birth and the profile;
- app and manifests must equal the birth;
- the delegated app and package capabilities must differ from the birth owner's capabilities, from each other and from the snapshot capability;
- the snapshot capabilities must be non-zero decimals.

The two snapshot capabilities are validated and stored but never consumed (`:15-17`; grep finds no other use).

## 1.12 `grain_export.rs` (858)

- **`write_export`** (`:80-130`):
  1. Move or copy the broker's export copy to `OUT/var.ext4` and re-hash it.
  2. Build the manifest: the base fields (store, app, `volumeIdHex`, `packageRawSha256`, class, `volumeMib`, `stopGeneration`), plus `protocol mini-spk-grain-export-v1`, `image{file, sha256, bytes}`, `stopReceipt` (the parsed receipt) and `stopReceiptSha256` (the SHA of the original bytes).
  3. **Sign the pretty JSON bytes with the completion custodian key** (`private_signing_key(custodian_seed)`, `:113-114`).
  4. Write `manifest.json`, `manifest.sig` (hex) and `exporter.pub`.
- **`verify_import`** (`:138-207`):
  1. Manifest at most 64 KiB. Signature (hex, 64 bytes) checked with `verify_strict` against the **CLI-supplied** exporter key.
  2. Protocol, package and class must match. `stopReceipt` must exist and `stopReceiptSha256` must be 64 characters (**the value is not compared to anything**).
  3. The image SHA must match. Stage `GRAINS/<store>/imports/<sha>.ext4` and re-hash it.
- **`reconcile_failed_start`** (`:315-631`), the host side of Mini's `reconcileFailedStart`. Its steps are in section 2.1.2.

## 1.13 State, files and environment touched (shard-wide)

| item | who | notes |
|---|---|---|
| `/etc/mini-spk-volumes/<store>.json` | root installer writes; helper, broker, resident read | registry |
| `/etc/sudoers.d/mini-spk-<store>` | root installer | `#UID ALL=(root) NOPASSWD: HELPER` (`install-user-world:159`) |
| `/var/lib/mini-spk-worlds/<store>/` | root 0755 | world root = grains root |
| `.../host-identity` | root 0600 | read by the bash script and the registry (installer `:151`) |
| `.../volumes/` (root 0700), `.../vars/` (root 0711), `.../attest/` (root 0755), `.../volume-custody/{verbs.lock,freezes/}` (root 0700) | root helper | images, registrations, mounts, witnesses, freeze intents |
| `.../broker/` (operator 0700): `placements/`, `units/`, `runtimes/`, `unit-runtimes/`, `backups/`, `volume-<app>.json`, `broker.log` | broker | |
| `.../runtime-<store>/broker.sock{,.lock}` | broker | 0600 |
| `.../spk/{packages,inbox}` | operator | images (0755 dirs) |
| `.../<store>/host/` | operator 0700 | state root: `grain-host.json`, `active-profile.json`, `host-identity.json`, `upgrades/`, `packages/`, `apps/<app>/{placement.json, custody/, install/, routes/, g<N>/, lifecycle-delegation.json, import.json, checkpoint-pause.json, .checkpoint.lock}` |
| `.../<store>/exports/`, `.../<store>/imports/` | root writes exports (chowned to operator); operator writes imports | |
| `/run/user/<uid>/systemd/user/` | broker | runtime units: slices, supervisor instances, resident units |
| env `MINI_SPK_{APP,OPERATOR}_{UID,GID}`, `MINI_SPK_GRAINS_ROOT`, `MINI_SPK_STORE`, `MINI_SPK_UNIT`, `MINI_SPK_BROKER_SOCKET`, `MINI_SPK_BWRAP{,_SHA256}` | resident unit | `resident_privilege.rs:25-37`, `:472-483`; `resident_service.rs:1283-1309` |
| env `SUDO_UID` | helper | authentication |
| `/proc/self/{cgroup,status,uid_map,gid_map}`, `/proc/<pid>/{stat,status,ns/user}`, `/sys/fs/cgroup/.../cgroup.events` | several | |
| external binaries | bwrap (pinned), newuidmap, newgidmap, systemctl, systemd-run, sudo, bash, mkfs.ext4, e2fsck, debugfs, blkid, findmnt, losetup, mount, umount, setpriv, fallocate, the Mini Host (pinned, except at `init-store`) | |


---

# 2. What it assumes of its surroundings

## 2.1 Host protocol operations used, with the Lean cross-check

Like shard A, this shard opens no Host socket itself. Every frame goes through `dispatch_native::PrivateOperator::invoke` (shard C), and every author and inspect step goes through `PrivateOperator::tool` (the pinned Host `author`/`inspect`/`signatures` subcommands) or `OfflineSourceHost::run_step` (the same subcommands, run offline).

### 2.1.1 Operations reached from this shard's code

| byte | symbol | reached from (this shard) | via (module) |
|---:|---|---|---|
| 22, 23 (lookup) | APPLICATION_LIFECYCLE_BEGIN_SUBMIT/LOOKUP | `resident_service.rs:1592-1600` (v3 BEGIN), `:961` (lookup on restart) | `lifecycle_v3_native` (shard C) |
| 26, 27 (lookup) | APPLICATION_LIFECYCLE_CLAIM_SUBMIT/LOOKUP | `resident_service.rs:1657-1666`, `:952` | `lifecycle_v3_claim_native` |
| 38, 39 | APPLICATION_LIFECYCLE_COMPLETION_SUBMIT/LOOKUP | `resident_service.rs:1841-1848`, `:1054` | `lifecycle_v3_completion_native` |
| 66-71 | APPLICATION_LAUNCH_{BEGIN,CLAIM,COMPLETION}_{PLAN,ASSEMBLE} | `resident_service.rs` START (the v3 path) | shard C |
| v4 retry family | per `lifecycle_v4_retry_*` | `resident_service.rs:1579-1590`, `:1642-1654`, `:1772-1810` | shard C |
| 154 | APPLICATION_ROUTE_INSPECT | `resident_service.rs:2024-2030` | `dispatch_native::admit_resident_route` |
| 34/36/37/164/152 | dispatch, route-bound dispatch, stream renew | `resident_service.rs:1958-1966` | `dispatch_delivery` (shard C) |
| **206** | APPLICATION_FAILED_START_RECOVERY_PREPARE | `grain_export.rs:570` | direct `operator.invoke(routes.prepare, selector.framed(request))` |
| **207** | ..._ASSEMBLE | `grain_export.rs:620` | direct |
| **208** | ..._SUBMIT | `grain_export.rs:452`, `:629` | direct |
| **209** | ..._LOOKUP | `grain_export.rs:442` | direct |
| tools | `author/inspect application-permission-schema`, `application-spk-package-identity`, `application-spk-launch-descriptor`, `application-failed-start-report`, `application-failed-start-signed-report`, `application-failed-start-recovery-request`, `application-failed-start-recovery-plan`, `outcome`, `signatures` | `descriptor_native.rs:29-38`, `resident_launch.rs:151-242`, `grain_export.rs:373`, `:499-610` | `PrivateOperator::tool`, `OfflineSourceHost` |
| `HOST CONFIG profile` | Store tag | `grain.rs:1426-1431` (`init-store`, **no hash pin**) and `PrivateOperator::store_tag` (`grain.rs:285`) | |

The registry (`protocol/host-operations.json:1998-2040`) marks 206-209 `status: active`, `routes: [operator]`, `receiver: fnDispatch`, owner `spk-recovery`.

### 2.1.2 Ops 206-209: the Rust encoding against the Lean decoding

`reconcile_failed_start` (`grain_export.rs:315-631`) runs these steps in order:

1. Read `resident.json` (`recovery_read`: private file, before and after stat, at most 32 MiB). Require the journal parent.
2. Create `g<N>/failed-start-recovery-v1/` and take the exclusive lock `.recovery.lock`.
3. **If `submit-requested.json` exists** (`:426-454`): the marker must name the same app, generation and SHA of `ingress.bin`. Send **op 209 with the exact ingress**. If the outcome type is not `absent`, `finish`. If it is `absent`, send **op 208 with the same bytes**, then `finish`.
4. Otherwise read **`start-admitted-v3.json`** (protocol `mini-spk-resident-start-admitted-v3`). Deserialize `physicalBegin` (`hostd::VerifiedBegin`) and require the app and generation to match. Read `begin-v3.bin`, `claim-v3.bin` and `committed-v3.bin` and require their digests to equal the admitted stage (`:455-489`).
5. `audit = Journal::open(journal).audit_failed_start(physical)` (hostd, shard A). `report_source = {originalBeginHex, originalClaimHex, committedClaimHex, audit, semantics}`, retained exactly (`:490-497`).
6. Author and inspect `application-failed-start-report`. The type must be `application-failed-start-report-v1`, the canonical hex must echo, and `source` must equal `report_source` (`:498-521`).
7. Sign `signingHeaderHex` with the completion custodian key. Author `application-failed-start-signed-report` from `{reportHex, publicKeyHex, signatureHex}` (`:522-539`).
8. Load the completion management custody (`mini-spk-completion-management-v1`, the selector app must equal the target) and run `lifecycle_selector::validate_custody` (`:540-557`).
9. Author `application-failed-start-recovery-request` from `{originalBeginHex, originalClaimHex, signedReportHex}` (`:558-569`).
10. **op 206**: payload `LE32(len(selector JSON)) ‖ selector JSON ‖ request` (`lifecycle_selector.rs:63-75`). The reply goes through `framed_payload(reply, 206, "DREGG/APPLICATION/FAILED-START-RECOVERY-PLAN/v1")` (`lifecycle_v3_native.rs:102-116`: LE32 length, opcode byte, tag prefix). Retain `plan.bin`, then inspect the plan. Every echoed field must match: plan, request, begin, claim, signed report, app and generation (`:570-592`).
11. Sign the pinned slots (`sign_pinned_slots` over `view.slots` with the custody signers) and encode them through the Host tool `signatures` (`:593-610`).
12. **op 207**: payload `LE32(len(plan)) ‖ plan ‖ signatures`. The reply is framed with the tag `"DREGG/APPLICATION/FAILED-START-RECOVERY-INGRESS/v1"`. Retain `assemble-request.bin` and `ingress.bin`, **then** `submit-requested.json`, **then op 208** (`:611-630`).
13. `finish` (`:375-425`):
    - The outcome must be framed `"DREGG/NATIVE-HOST/OUTCOME/v6"` and inspected (`observe`, `:361-374`).
    - For 208, `type == confirmed` and `confirmation ∈ {installed, recoveredAfterUncertainResponse}`. For 209, `confirmation == replayed`.
    - `transactionId`, `eventId`, `acceptedCount` and `worldRoot` must be canonical decimals.
    - Retain `confirmed.json` once (a later lookup must name the same four fields), then `g<N>/failed-start-recovered-v1.json` (`reconciledGeneration = N+1`).

The Lean side:

| item | Rust | Lean | agree? |
|---|---|---|---|
| op 206 framing | `LE32 ‖ selector JSON ‖ request` (`lifecycle_selector.rs:71-74`) | `splitPair payload` (`Host/Main.lean:1871-1876`: LE32 width, `take width`, remainder), then `LifecycleSelector.parse selectorBytes`, then `ApplicationFailedStartEndpoint.prepare ... (selector.completionPin management) payload` (`Host/Main.lean:7621-7633`) | yes |
| op 206 reply | expects opcode 206 and the PLAN tag | `return ((206 : UInt8), planCodec.encode plan)`. The tag `"DREGG/APPLICATION/FAILED-START-RECOVERY-PLAN/v1"` is at `Host/ApplicationFailedStartRecoveryAuthoring.lean:61` | yes |
| op 207 framing | `LE32(plan) ‖ plan ‖ signatures-bytes` | `splitPair`, then `planCodec.decode`, then `decodeSignatures` (a `StreamCodec.list bytesStream`, `Host/Main.lean:1878-1882`), then `assemble` (`:7634-7641`) | yes, provided the `signatures` tool emits `StreamCodec.list bytesStream` (it is the Host's own encoder) |
| op 207 reply | INGRESS tag | `frame = "DREGG/APPLICATION/FAILED-START-RECOVERY-INGRESS/v1"` (`Kernel/ApplicationFailedStartRecoveryIngress.lean:38-39`) | yes |
| op 208/209 reply | outcome tag v6 | `outcomeCodec.encode`. The current tag is `"DREGG/NATIVE-HOST/OUTCOME/v6"` (`Compiler/PersistedCodecTags.lean:607`) | yes |
| lookup "absent" | `text(view, "type") == "absent"` triggers a same-bytes resubmit | `ApplicationFailedStartEndpoint.lookup`: `.ok none => .absent` (`Host/ApplicationFailedStartEndpoint.lean:22`); JSON `{"type":"absent"}` (`Host/Json.lean:4818`) | yes. `uncertain`, `refused` (malformed or conflict, flattened to the uniform refusal by `publicSubmissionOutcome`, `Kernel/NativeHost.lean:3142-3145`) and history-unavailable never cause a resubmit |
| confirmation labels | installed, recoveredAfterUncertainResponse, replayed | `Host/Json.lean:4788-4798` | yes |
| same-bytes resubmit safety | Rust comment `grain_export.rs:446-451` | `stableNullifier` keyed on (domain, semantics, `source.physical.report.claim.core.claimReceipt.transactionId`) (`Kernel/ApplicationFailedStartRecoveryIngress.lean:51-63`); `same_claim_same_recovery_nullifier` (`:83-89`). The receiver also refuses an already-used transaction id (`Kernel/ApplicationFailedStartRecoveryReceiver.lean:81-83`) | yes. A second copy cannot admit a second recovery |
| report source | `{originalBeginHex, originalClaimHex, committedClaimHex, audit, semantics}`, with `semantics` the config's `completionSemantics` string | `reportSource` (`Host/ApplicationFailedStartRecoveryTools.lean:87-92`) and `authorReport` requiring `reportSource r == j` (`:103`) | yes, provided `completionSemantics` is the canonical decimal of `begin.base.semantics` (otherwise `authorReport` refuses, which fails closed) |
| audit JSON | `hostd::Journal::audit_failed_start` | `auditJson` (`:74-85`) | yes. Shard A section 2.1.4 checked all 18 fields |
| lane | **v3 only**: `start-admitted-v3.json`, `begin-v3.bin`, `claim-v3.bin`, `committed-v3.bin` (`grain_export.rs:455-480`) | `authorReport` decodes `ApplicationLifecycleBeginV3Ingress` and `ApplicationLifecycleClaimV3Ingress` and `ClaimV3Projection` (`Tools.lean:96-101`) | **agree, and both lack the v4 retry lane** (section 4 F4) |
| signed report | Rust signs `signingHeaderHex` with the custodian seed | `authorSignedReport` checks only the key and signature *lengths* (`Tools.lean:113-119`). Whether the receiver verifies the signature against `completionCustodianKey` is question 8.3 | not settled here |

### 2.1.3 Inspections compared in this shard (Rust versus Lean types)

| inspector kind | type strings expected by Rust | chosen by | file:line |
|---|---|---|---|
| `application-permission-schema` | `minidregg-application-permission-schema-v1` | fixed | `descriptor_native.rs:134`, `resident_launch.rs:157`, `claim_descriptor.rs:179` |
| `application-spk-package-identity` | `application-spk-package-identity-v1` (no API path or `/repo.git/`) / `-v2` (any other valid prefix) | `signed_api_path::descriptor_inspection_type` (`native/signed-api-path/src/lib.rs:35-43`) | `descriptor_native.rs:179-181`, `resident_launch.rs:178-180` |
| `application-spk-launch-descriptor` | `-v2` (package v1) / `-v3` (package v2) | `signed_api_path::launch_inspection_type` (`lib.rs:45-49`) | `launch_descriptor_native.rs:408-410`, `resident_launch.rs:243-245` |
| claim committed | `application-lifecycle-claim-committed-v3` / v4 constant | `StartLane::committed_view_type` (`resident_service.rs:384-389`) | `:709` |
| claim committed (dead) | `application-lifecycle-claim-committed-v2` | none | `claim_descriptor.rs:148` |

The API-path rule (`signed_api_path::checked_prefix`) is a Rust twin of `Kernel/ApplicationSpkPackageIdentity.validApiPrefix` (`:165-195`). In this shard it gates qualification and descriptor authoring (`materialize.rs:309-315`, `descriptor_native.rs:107-115`, `resident_launch.rs:140-148`). Lean re-checks the prefix in `validFor` (`ApplicationSpkPackageIdentity.lean:221`). So this is a mirror, not the decision.

## 2.2 OS facilities

The code is Linux-only. `seccomp.rs` and `setid_bound.rs` support only x86_64 and aarch64, and `seccomp.rs:34-37` fails the build on any other architecture.

- **systemd user manager with linger**, plus `systemctl --user` (show, start, stop, reset-failed, daemon-reload) and `systemd-run --user --wait --pipe` (`spk-ingest`).
- **cgroup v2** with delegation of memory, pids, cpu and io to the user manager. The slices use `MemoryMax`, `MemorySwapMax=0`, `TasksMax`, `CPUWeight` and `IOWeight` (`broker.rs:899-903`). `USER-TENANCY.md:3-4` states this.
- **Unprivileged user namespaces**, either directly or through an AppArmor-profiled bwrap (`/usr/local/libexec/mini-grain-bwrap`) with named ACL execute grants (`install-user-world:138-150`).
- **bubblewrap**, at a pinned path and SHA, supporting `--disable-userns`, `--userns-block-fd`, `--info-fd`, `--size`, `--seccomp`, `--ro-bind-fd` and `--bind-fd`. The comments cite 0.10 and 0.11.
- **newuidmap/newgidmap** (uidmap) plus `/etc/subuid` and `/etc/subgid` grants covering the app pool (`broker.rs:1407-1420`).
- **sudo** with a NOPASSWD rule for the helper.
- **Loop devices and ext4**: `mount -o loop`, `losetup`, `findmnt`, `mkfs.ext4`, `e2fsck`, `debugfs`, `blkid`, `fallocate`, `setpriv`, `FIFREEZE`/`FITHAW` ioctls (`broker_volume_custody.rs:8-9`). The backing filesystem must be ext4, btrfs or zfs, so that the witness has a stable id (`spk-var-volume:280-295`).
- **Syscalls and features**: `memfd_create` with sealing, `pidfd_open`, `close_range`, `execveat(AT_EMPTY_PATH)`, `renameat2(RENAME_NOREPLACE)`, `SEEK_DATA`/`SEEK_HOLE`, `fgetxattr(system.posix_acl_access)`, `SO_PEERCRED`, `SCM_RIGHTS`, flock, `prctl` (capability bounding, ambient, no_new_privs, dumpable).
- **jq and getfacl/setfacl** at install time (`install-user-world`).

## 2.3 Network services

There are none outbound and no TCP listeners in this shard. The Unix sockets are `runtime-<store>/broker.sock`, `g<N>/checkpoint-control.sock`, plus shard A's route sockets and `route-control.sock`.

## 2.4 Config files

- `broker/config.json` (`mini-spk-broker-config-v3`).
- `/etc/mini-spk-volumes/<store>.json` (`mini-spk-volume-registry-v1`).
- `<state>/grain-host.json` and successors (`mini-spk-grain-host-v2`).
- `active-profile.json` (`mini-spk-active-profile-v1`).
- `placement.json`.
- `install.json` (`mini-spk-resident-install-v2`).
- `resident.json` (`mini-spk-resident-start-v3`).
- `qualify.json` (`mini-spk-launch-qualification-v1`) and `qualification.json` (`mini-spk-launch-qualified-v2`).
- The custody files (`mini-spk-resident-{begin,claim}-management-v1`, `mini-spk-completion-management-v1`).
- `lifecycle-delegation.json`.
- Root `compatible-admission.json` (the upgrade custody crate).
- The pause inventory (`mini-spk-checkpoint-pause-inventory-v1`).

## 2.5 Other crates

- `minidregg-spk-rpc` (`decode_bridge_config`, `BridgeConfig`, `RpcDriver` through `rpc_adapter`).
- `minidregg-compatible-upgrade-custody` (`root_owner`, `canonical`, `root_bytes`, `load`, `load_evidence`, `image`, `root_pin`, `root_ancestors`, `sha`).
- `minidregg-signed-api-path`.
- **`sandstorm-package`**, a git dependency on `github.com/emberian/dregg` at rev `5819115...` (`Cargo.toml:31`): `Spk`, `SpkManifest`, `File`, `FileContent`, `manifest::{Command, Action}`. A cargo git checkout exists at `~/.cargo/git/checkouts/dregg-e74254a57dc0e06d/5819115`. Minidregg's SPK identity and signature verification therefore live in the repository it was written to replace.
- `ed25519-dalek` (export signing and verification), `sha2`, `serde_json`, `libc`.

---

# 3. Does it decide anything semantic?

## 3.1 Decisions made in Rust that a Lean admission should own

| # | where | what Rust decides | Lean counterpart | blast radius if wrong | verdict |
|---|---|---|---|---|---|
| S1 | `broker.rs:37-90`, `:884-919`; `web_socket::Limits::from(broker::class(...))` at `resident_service.rs:1933`; `grain.rs:1394` (default `"S"`) | The quota of every grain: memory, CPU and IO weight, task cap, `/var` bytes, WebSocket concurrency and bytes per minute. The operator picks the class with a CLI flag, and the class is retained only in operator JSON (`placement.json`, broker placement, `resident.json`) | **None.** The comment at `broker.rs:37-39` and README `:126-127` promise "the kernel will pin the class in the app birth descriptor (K-SPK)". No Lean declaration exists (grep for `K-SPK` in `*.lean` returns nothing) | A member's share of the box, and a Store's ability to grow a grain without any recorded authority. A class change needs only an operator CLI call and a stopped app (`broker.rs:893-897`) | **violation: quota policy decided in Rust**. Physical enforcement in Rust is right, but the numbers and their assignment should be Lean data |
| S2 | `materialize.rs:236-283` (`Spk::parse_with_limit`, `SpkManifest::from_spk`) | **SPK signature validity and app identity** (Sandstorm's app id is the signing key). Lean receives `signedAppId`, `manifestSha256`, `bridgeConfigSha256`, `rawSha256` and `rawLength` as fields of the descriptor source (`descriptor_native.rs:150-159`) and re-encodes them | `Kernel/ApplicationSpkPackageIdentity` records them as opaque bytes. No Lean verifier of the SPK signature exists | A bug in the external parser lets a forged package carry another app's id into the descriptor root. Mini laws or members that key on app id would be fooled | **identity decided in Rust**, in a dependency from the replaced repo. The correct boundary is to verify the signature in Rust (it is physical I/O) but to have Lean check the Ed25519 signature over the manifest hash, which it can do |
| S3 | `grain_export.rs:138-207`; `grain.rs:696-705` | Whether an archive is a legitimate prior state of a grain: the exporter key is supplied on the command line, and the STOP receipt is carried but **not verified**, nor is its SHA (`:176`) | `ApplicationGrainExport` / `import_binds_stop_receipt` (K-SPK) is promised (`grain_export.rs:10-12`) and absent | The imported `/var` seeds a brand-new resource with any bytes signed by any key the operator names. Data provenance claims ("restored from STOP receipt X") are unchecked | **violation, documented as pending** |
| S4 | `grain.rs:1049-1062` | `continue.createdIndex = acceptedCount - 1` of the prior create's completion receipt | the Lean v3 BEGIN (continue requires a created witness; `resident_service.rs:654-660` requires a prior-create witness shape) | A wrong index makes the BEGIN refuse (fails closed), provided Lean checks it (question 8.4) | mirror if Lean checks |
| S5 | `grain.rs:1040-1048` | The next generation number (`max + 1`, or reuse of a never-begun one) | Lean's BEGIN authors `processGeneration`. `scan_runs` refuses a `g<N>` whose admitted generation differs (`:876-886`) | A mismatch refuses on the next scan, after a BEGIN was spent (question 8.5) | mirror, but a Rust-chosen directory name must equal a Lean-chosen number |
| S6 | `grain.rs:1261-1310`; supervisor unit (`broker_runtime_adoption.rs:457-460`) | **Restart policy**: after a crash, automatically STOP and continue-START under the management subject, at most 3 times per 1,800 s | Every STOP and BEGIN is still admitted by Lean under current law. The *decision* to restart and its rate is Rust and systemd | Unbounded Mini writes are prevented only by `StartLimitBurst`. The policy is not a recorded law | operational. Acceptable, but should be named in law if restarts cost funds |
| S7 | `grain.rs:351-384` | "The birth is confirmed": JSON `type == confirmed` from an operator file | Lean re-checks on every BEGIN | operator-only input | mirror |
| S8 | `grain_management.rs:20-54` | Which delegation selectors are acceptable (they must differ from the owner caps, and so on) | Lean admits each lifecycle op against delegated capabilities | over-strict at worst | mirror (pre-check) |
| S9 | `descriptor_native.rs:177-183`, `claim_descriptor.rs:78-84` | Recompute `imageIdentity = "DREGG/SPK-IMAGE/v1" ‖ sha256` and compare it to Lean | Lean authors it | a mismatch refuses | mirror |
| S10 | `broker.rs:107-113` | App ids, generations and resource ids must be **at most 18 decimal digits** | Lean ids are unbounded naturals (`volume_custody.rs:255` caps at 999,999,999,999,999,999 as well) | An app id ≥ 10^18 can never be placed or started. This fails closed but narrows Lean's id space | physical narrowing; should come from the Lean resource-id bound |
| S11 | `sandbox.rs:22-28`, `:298-326`; `launch_descriptor_native.rs:324-326` | The launch profile: 64 argv, 4 KiB per argument, 128 env entries, 128 KiB total, 1-64 create actions | none (qualification refuses before BEGIN) | packages over the bounds are unusable | physical policy, fine |
| S12 | `volume_custody.rs:15` | Witness freshness of 120 s | Lean trusts the custodian-signed report | physical | fine |
| S13 | `export_receipt.rs:104-115` | An unsigned "export receipt" header in the app response | none ("kernel admits request, not response body") | Only harmful if a consumer treats it as evidence | fine as labeled, but the name "receipt" is misleading (it is not signed) |

## 3.2 Places that correctly defer

- **Every lifecycle transition** (INSTALL, BEGIN, claim, completion, STOP, failed-START recovery) is authored by Lean tools, admitted by a Lean receiver, and confirmed by a Lean receipt. Rust only compares the inspected echo with its physical facts (`resident_service.rs:599-738`, `grain_export.rs:513-592`).
- **The launch command** is selected by Lean digest, never by Rust choice (`resident_launch.rs:317-351`, `resident_service.rs:1606-1620`).
- **Route admission** goes through op 154, and its binding must equal custody (`resident_service.rs:2024-2050`).
- **Lost replies** produce lookups (ops 23, 27, 39, 209) before anything else, and START never re-arms (`resident_service.rs:887-1116`, `grain_export.rs:426-454`).
- **The volume witness and the failed-START audit** are physical observations signed by the custodian. Lean trusts the custodian, by design. This is the same boundary as shard A D14.
- **The completion custodian key** must equal the Host config's genesis-bound key (`completion_custodian.rs:55-64`).

---

# 4. Flaws noticed

## 4.1 Security and trust

**F1. A compromised resident is the operator of the whole world.** This is the central security finding.

- The resident unit runs as the operator UID (`broker.rs:1035-1046`). It joins a user namespace that maps exactly {operator, app} and then drops every capability inside it (`resident_privilege.rs:485-498`). It stays in the **host mount namespace**: `setns(CLONE_NEWUSER)` only (`namespace_identity.rs:155`).
- The unit has no filesystem restriction. `broker_home::render` validates the declared paths and then returns `String::new()` in both branches (`broker_home.rs:202-208`), so the drop-in at `broker.rs:1071-1076` is never written. The resident's only syscall filter is namespace denial (`resident_privilege.rs:51-110`).
- The resident parses app-controlled bytes: Cap'n Proto from fd 3 (`rpc_adapter`, the `capnp` crate), plus HTTP from route clients.
- What an attacker who achieves code execution in that parser can do:
  - Read every operator 0600 file: the management seed (`HostProfile.management_seed`, `grain.rs:212`), the completion custodian seed (`:213`) and every participant's dispatch-custody seed path (`broker_home.rs:210-222` enumerates them; shard A D1).
  - Connect to the broker (peer UID equals the operator; `broker.rs:1218`) and Stop, Start, InstallUnit, Unmount, ExportVolume or **Backup** any grain of the world.
  - Connect to the Mini operator socket and author lifecycle operations as the management subject.
  - Write any operator file, including other grains' `resident.json` and the custody files.
- `deploy/spk-host/README.md:89-90` acknowledges "it is the operator", but the same README section (`:78-90`) still promises `ProtectSystem=strict` and `setid_bound`, neither of which exists.
- **Blast radius**: one malicious or exploited SPK app equals every app, key and member of that Mini world.
- **Fix direction**: a per-grain resident UID, with the operator socket reached through a narrow broker. The README notes that this needs K-SPK key splitting. Short of that, render real `ProtectSystem=strict`, `ProtectHome=tmpfs`, `BindReadOnlyPaths=` and `InaccessiblePaths=`, and a `SystemCallFilter=` for the resident.

**F2. The sandbox-floor audit cannot run against the production path.**

- `root_probe_holds_inside_resident_sandbox` and `root_probe_breaches_under_pre_floor_arguments` (`resident_launch.rs:578-625`) call `PreparedResident::spawn_for_audit`, which calls `spawn_gate::spawn_bounded` (`:486-490`).
- `spawn_bounded` returns `Err("production SPK gate requires trusted bootstrap channel")` unless `resident_privilege::LAUNCH` is set (`spawn_gate.rs:550-553`, `resident_privilege.rs:295-298`). Only `resident_privilege::run` sets it.
- `scripts/spk-platform/sandbox-floor-audit.sh:81-82` still runs both tests and has not changed since `a28cf6b0` (2026-09-30).
- Both tests panic at `.unwrap()` before the probe runs. The positive gate goes red for the wrong reason, and the negative control cannot demonstrate a breach.
- The recorded evidence (`docs/evidence/2026-09-30-sandbox-floor/README.md:12-18`) describes "The gate runs as root, ... drops to UID/GID 65534". That is not the shipping path (a userns-joined operator, then an app-UID worker, then bwrap).
- **The current floor (seccomp, `--disable-userns`, the fd census inside bwrap launched by the app-UID worker in a mapped namespace) has no measurement.**

**F3. Seccomp policy gaps against Sandstorm** (table in 1.7.5). The ones worth closing are legacy AIO, `seccomp`/`prctl(PR_SET_SECCOMP)`, `vmsplice`, `mbind`/`set_mempolicy`, and setting a hostname (`--hostname`). A minimal read-only `/dev` (bwrap `--dev` gives `tty` and `/dev/pts`) and `RLIMIT_NOFILE` are also worth having. `ioctl` is open apart from two terminal requests. With devpts present the app can open a pty and issue every tty ioctl. TIOCSTI is closed, and `--new-session` also defends.

**F4. A failed START on the v4 retry lane is unrecoverable.**

- `scan_runs` classifies a v4 START without completion as `Uncertain("START ...")` (`grain.rs:866-872`), and `supervise` calls `reconcile_failed_start` (`:1273-1279`).
- That function reads `journal/start-admitted-v3.json` (`grain_export.rs:455-461`) and the v3 attempt files. For a v4 generation these are absent, so `recovery_read` fails with NotFound.
- The error is not `UNRESOLVED`, so the process exits 1. The supervisor retries every 30 s until `StartLimitBurst=3`, then stops.
- The Lean tool also decodes only v3 (`Host/ApplicationFailedStartRecoveryTools.lean:96-101`). This needs a Lean v4 recovery source, or a statement that v4 failures are impossible (question 8.1).

**F5. Failed-START recovery wedges if any pre-marker input changes between attempts.** Every artifact before `submit-requested.json` is `retain_exact`: a rerun must re-derive byte-identical content or refuse "recovery retained artifact differs from exact rederivation" (`grain_export.rs:269-284`).

- `report-source.json` embeds the physical audit (`:490-497`): `managerActiveState`, `managerInvocationId`, `managerControlGroup`. If anything changes the unit between the first attempt and a crash-and-rerun (for example a broker `start`/`stop`, which runs `reset-failed`, `broker.rs:1091-1093`, `:1103-1105`), the audit differs and recovery refuses forever.
- `plan.bin` comes from op 206 against the *current* verified tip. If the plan binds the tip or current law, a rerun after another Store write differs (question 8.2).
- The scenario: the process crashes after op 206 and before op 207. Every later supervisor run refuses, and the operator must delete the attempt directory by hand. The code offers no command for that.

**F6. Import never checks the STOP receipt binding.**

- `verify_import` requires `stopReceiptSha256` to be any 64 characters (`grain_export.rs:176-178`). The receipt itself is re-serialized compactly (`:171-175`), so even a comparison would not reproduce the exporter's hash of the original bytes (`:111`).
- The signature covers both fields, so this is an internal inconsistency rather than a forgery path. But the manifest's "bound to the STOP receipt that fenced them" claim (`:1-5`) is not checked by anyone (S3).

**F7. One key signs Lean reports and raw export JSON.** The completion custodian key signs Lean-framed `signingHeaderHex` for reports (`grain_export.rs:527`, and shard C reports). It also signs raw `serde_json::to_vec_pretty(manifest)` for exports (`:113-114`), with no domain-separation prefix.

A collision would require a Lean signing header that parses as the export JSON. The headers start with a fixed frame, so this looks impossible in practice. Still, reusing one key for an unframed message type breaks the repo's own framing discipline. The cheap fix is to prefix the export message with a tag.

**F8. The volume helper root surface, judged.** Running a compile-time bash script as root from Rust is defensible only because:

- the inputs are validated twice (Rust registry and coordinates at `volume_helper.rs:57-68`, bash regexes at `spk-var-volume:27-37`, `:151-153`);
- every path is under a root-owned 0755/0700/0711 tree;
- the environment is cleared and PATH is fixed (`volume_helper.rs:219-221`).

The weaknesses are:

- **A root `cp` into an app-owned directory.** `install -d -o "$app_uid" ... "$stage"`, then `cp --reflink=auto -- "$untrusted" "$stage/untrusted.ext4"`, then `chown ... "$stage/untrusted.ext4"` (`spk-var-volume:208-210`). If any process with the app UID is alive, it can plant a symlink at `$stage/untrusted.ext4` between the `install` and the `cp`, and root's `cp` then writes the 512 MiB-2 GiB import through it (for example over `/etc/shadow`). This is safe today only because UIDs are never recycled (F13) and the grain is not running at create time. The script never asserts that no process holds the UID.
- **Root parses app-written bytes on export and backup.** `e2fsck -fn` and `debugfs -R "ls -l /"` run as root on every export and backup copy (`broker_volume_custody.rs:266-267`), whereas import parses as the app UID (`spk-var-volume:49-58`, `:214-216`). The exported image is kernel-written ext4, so the risk is low, but the discipline is inconsistent.
- **Path-based `stat`-then-act** throughout the bash (`stat -c` checks followed by `chmod`/`chown`/`mount` on names). These names are root-owned, so this is acceptable.
- **The sudoers rule** `#UID ALL=(root) NOPASSWD: HELPER` allows any arguments (`install-user-world:159`). The binary accepts exactly one argument (`bin/mini-spk-volume-helper.rs:4-6`), the decode is typed with `deny_unknown_fields`, and the caller is authenticated by `SUDO_UID` against the registry (`volume_helper.rs:121-129`). It is acceptable. Note that sudo logs the JSON argv.
- **Verbs reachable through sudo but not through the broker**: `Mount`, `Thaw` and **`Destroy`** (`volume_helper.rs:288-315`). Anything running as the operator, including a compromised resident (F1), can `sudo` the helper directly to destroy any volume of the world: it unlinks the image, the registration, the witness and the mountpoint.

**F9. Pins checked by hash, then executed by path.**

- `OfflineSourceHost::run_step` hashes the Host, then `Command::new(&self.host)` (`launch_descriptor_native.rs:133`, `:149`), then hashes again. A swap between the hash and the exec runs other bytes for that step.
- `grain init-store` runs `HOST CONFIG profile` with **no pin at all** (`grain.rs:1426-1431`) to derive the Store key.
- Contrast `native/pinned_execution.rs:21-55` (private-backend), which copies the image into a sealed memfd and executes the snapshot.
- The Host paths are operator- or root-owned, so only the operator can race this. It is a law-13 twin (two "pinned execution" designs) more than a live threat.

**F10. `pinned_root_executable` accepts operator ownership** (`broker.rs:405`, `grain.rs:182`). `spk_host` is meant to live in `~/.local/libexec` (`mini-spk-broker.example.json:10`), and the SHA pin sits in an operator-writable config. So the pin defends against nothing the operator cannot do. That is consistent with "the operator is trusted", but the function name and error text ("must be a root-owned executable") are wrong.

## 4.2 Lost reply, retry and availability

**F11. Exit-on-any-error in the resident.** These events end the resident, and therefore end the generation:

- a callback error for any auxiliary fd (`http_entrance.rs:1084`);
- `POLLERR`, `POLLHUP` or `POLLNVAL` on an auxiliary fd or an entrance (`:1080-1082`, `:1091-1093`);
- `listener.accept()` failing (`:1098`);
- reader-thread spawn failure;
- a poisoned admission lock.

Concrete triggers from this shard:

- A same-UID client of `checkpoint-control.sock` that disconnects before the reply makes `stream.write_all(...)` return Err (`checkpoint_control.rs:299-301`), and the generation ends.
- Route control: any error during publication "poisons control and ends the resident" (`resident_service.rs:2071-2074`, by design).
- While paused, an agent client that is accepted and dropped can fail in `accept_authenticated()?` (`:1998`).
- The app exiting (`:1972-1974`), by design.

Each generation end costs a Mini STOP plus a START. The 10-01 numbers are STOP 3,062 s and kill-to-new-generation 2,529 s, measured on persvati at load 20-45 under the old architecture. After 3 supervisor failures in 1,800 s the app stays down. **Any member who can make the app process exit (one crashing request) can take a grain offline for most of an hour per crash.** After three crashes it is down until an operator acts.

**F12. The broker is a single sequential loop with long operations and a 600 s client timeout.**

- `serve` handles one connection at a time (`broker.rs:1204-1249`). `backup` and `export-volume` copy gigabytes (with FIFREEZE held during the copy), and `ingest` waits up to 120 s.
- While one of these runs, every other grain's `start`/`stop`/`install-unit` (including supervisors recovering crashed grains) waits.
- The client gives up after 600 s (`broker_endpoint.rs:44`) and reports an error while the broker continues.
- For `export-volume` and `backup` that lost reply leaves a full image copy in `GRAINS/<store>/exports/` that no one will ever rename or delete. A retry makes another. `volume_helper.rs:300-301` says "A lost exec reply never licenses resubmitting an export", but `grain export` (`grain.rs:1339-1342`) and `grain backup` simply call again.

**F13. Resources that never come back.**

- App UIDs are allocated by `Place` from `app_uids` (`broker.rs:852-868`) and never freed. No verb deletes a placement, and `install-user-world:89` caps the pool at 64 per world. Every grain install, including every **import** (always a new resource, `grain_export.rs:4-5`), consumes one permanently. A public demo world can have at most 64 grains in its lifetime.
- The ext4 images are fully preallocated (`fallocate -l "$bytes"`, `spk-var-volume:192`): S 512 MiB, M 1 GiB, L 2 GiB of disk per grain, used or not.
- Backups and exports accumulate without retention.
- The `volumes/.import-<name>` staging file is created with `create_new` (`volume_helper.rs:275-276`). A crash between the copy and the script leaves it, and every later import Create for that name refuses until root removes it.

**F14. The resident re-parses the full signed SPK on every START, inside the app's memory cgroup.**

- `verify_installed_spk` (`resident_service.rs:1419`) runs `Spk::parse_with_limit` up to 768 MiB decompressed. `materialize.rs:19-26` states the parse holds "about 2.2x the decompressed size (Wekan: 1.17 GB RSS)".
- The resident unit's `Slice=` is the app's class slice (`broker.rs:1039`): class S is `MemoryMax=512M`, M is `1G`.
- *Inference, not measured*: the larger market packages (TT-RSS 298 MiB, Etherpad 341 MiB, Davros 477 MiB, Wekan 525 MiB decompressed, `materialize.rs:21-23`) will OOM-kill the resident at START in class S, and some in class M. The kill lands after BEGIN if it happens during later steps, but this parse happens before BEGIN, so it fails closed and repeats under the supervisor.
- The same re-parse runs in `grain install` (`grain.rs:624`) as the operator CLI, and in STOP.

**F15. Backup freezes running apps.** `Backup {}` (any operator-UID caller, F1) runs `FIFREEZE` on every registered running volume in turn for the duration of a full sparse copy (`broker_volume_custody.rs:257-262`, `broker.rs:1149-1160`). App writes block while frozen. If the helper is SIGKILLed mid-copy, the filesystem stays frozen until the next helper invocation of any verb runs `volume_recover` (`volume_helper.rs:263`). Meanwhile the app hangs and its HTTP requests time out.

**F16. Retry semantics of `grain` verbs.**

- `install` is resumable (artifacts are checked, `grain.rs:742-759`).
- `start` refuses uncertain records and reuses never-begun generations.
- `stop` resumes STOP's own journal.
- `export` is not idempotent (F12).
- `stage_package` renames an interrupted qualification aside and repeats it (`grain.rs:498-507`). That is correct because qualification is pure, but every interrupted attempt leaves a `qualification-interrupted-*` directory.
- No verb can turn a lost reply into a second Mini *operation*. The only resubmission path is ops 206-209's same-bytes rule, and the Lean nullifier makes it safe (2.1.2).

## 4.3 Bounds, parsing and panics

- **Every untrusted read is bounded.** Broker request 16 KiB (`broker.rs:30`, `:1215`); broker reply 1 MiB (`broker_endpoint.rs:51`); launch frames 1 MiB (`resident_privilege.rs:13`); checkpoint 4 KiB (`checkpoint_control.rs:282`); witness 4 KiB; custody and config 16-64 KiB; SPK 256 MiB raw and 768 MiB decompressed; export manifest 64 KiB; inspection outputs at most about 97 MB (`launch_descriptor_native.rs:41`).
- **No panics on untrusted input were found.** The non-test `expect`/`unwrap`/`unreachable` calls are all invariants:
  - `sandbox.rs:183`, `:226` (constant CStrings);
  - `seccomp.rs:287` (block at most 19);
  - `resident_launch.rs:78` and other hex writers into `String`;
  - `resident_service.rs:1970`, `:2090`;
  - `grain.rs:1293`;
  - `grain_profile_upgrade.rs:402` (`next_path.parent().unwrap()`; derived paths always have a parent);
  - `broker_endpoint.rs:91` (`path.parent().unwrap()` after `resolve` guarantees a parent).
- **`receive_rights`** (`resident_privilege.rs:177-226`) bounds the control buffer to 8 fds and refuses `MSG_CTRUNC`. It takes ownership of every received fd before validating counts, so extra fds are closed on drop.
- **The `/proc/<pid>/stat` parse** (`resident_privilege.rs:227-233`) uses `rsplit_once(')')`, which is correct for process names containing parentheses.

## 4.4 Error swallowing and fail-open

- **The broker silently ignores accept errors and peer-credential failures** (`broker.rs:1205-1213`). Nothing is logged for a connection it could not identify. **It also ignores audit-log write failures** (`:684-685`) and reply write failures (`:1248`). The broker log is the only record of root-reaching requests. Losing it silently is a law-10 issue (refusal and recording should be loud).
- **Ordering in the broker serve loop.** It reads the full request (up to 16 KiB, 10 s) *before* checking the peer UID (`:1215` then `:1218`). Socket mode 0600 makes this moot today.
- **`checkpoint_control::poll_once`** silently drops connections from other UIDs (`:273-275`). This is fine because the socket is 0600.
- **`grain::unit_property`** (`:899-905`) ignores the `systemctl` exit status. An absent unit gives `""`, which callers interpret as "not active" (`:1129-1131`, `:1146-1151`). In `start_inner` that interpretation only shapes error text. In `supervise` an empty state means "not active", so the supervisor STOPs. That is a deliberate fail-safe toward Mini audit.
- **`Client::drop`** (`resident_privilege.rs:241-264`) waits at most 5 s for the worker and then gives up silently. The comment says "A lost channel still needs independent unit audit". It is fine because `KillMode=control-group` cleans up.
- **No fail-open authority path was found in this shard.** Every refusal returns Err, and every Mini-affecting step requires a Lean receipt.

## 4.5 Keys, logs and argv

- Seeds are read by path through `dispatch_author::private_signing_key` (shard C). They are not zeroized in this shard's code (`grain_export.rs:113`, `:522-525`), and the key lives on the stack for the process lifetime.
- No key bytes appear in argv, env or logs. `session_intents` emits seed *paths* only (`grain_profile_upgrade.rs:424-473`, `PROFILE-UPGRADE.md:39-41`).
- The volume helper JSON is in argv (sudo logs it). It carries no secrets.
- `namespace_identity::map` prints the helper invocation to stderr (`namespace_identity.rs:75`). It contains UIDs only.

## 4.6 Correctness details

- **`resident_privilege::Identity::unit`** accepts any UID of 100 or more (`:30`). The registry check that follows (`:477-481`) is what binds it.
- **`spawn_gate::close_unlisted`** (`:242-251`) assumes `keep` is sorted, which it is (`:449-450`), and computes `fd - 1` only when `fd > first`. This is correct.
- **`child_exec`** calls `execveat` on an fd opened `O_CLOEXEC`. For an ELF that is fine. If the pinned "bwrap" were ever a script, execveat would fail with ENOENT after exec. That fails closed.
- **`seccomp` clone mask** `0x7e020000` omits `CLONE_NEWTIME` (0x80). With `clone()`, bit 0x80 lies inside the exit-signal byte (CSIGNAL), so time namespaces are reachable only through `clone3` (ENOSYS) or `unshare` (EPERM). This is correct. `resident_privilege.rs:89` adds `0x80` to its mask, which is harmless.
- **`broker::app_units_active`** (`:773-794`) issues one `systemctl show` per installed unit name for each call. `Backup` calls it per volume. That is O(units × volumes) process spawns: slow but bounded.
- **`render_static`** rewrites the slice and the (dead) template and runs `daemon-reload` on every broker start (`broker.rs:694-724`).
- **`grain::start_inner`** waits for `http.sock` existence as a readiness signal (`:1137-1142`). A stale socket file from a prior generation in the same route directory satisfies it, so readiness then depends only on the completed marker, which is also required. This is acceptable.
- **`materialize_spk`** stage name `.spk-stage-<pid>-<nanos>`: `spk-ingest:41-43` refuses if any stage remains after unit success. A crashed unit (SIGKILL at RuntimeMaxSec) leaves a stage, and every later ingest refuses until it is cleaned. `cleanup_staging` runs only on in-process errors.

---

# 5. Unwired, undone, twins, versioned siblings

## 5.1 Dead or unreachable code in this shard

| item | lines | evidence | delete? |
|---|---:|---|---|
| `claim_descriptor.rs` (all) | 310 | no `claim_descriptor::`, `compare_claim` or `compare_install_claim` caller in `src/` (grep); compares `...claim-committed-v2`, superseded by v3/v4 | **yes** |
| `setid_bound::{program, assemble, install, holds_setid_capabilities}` and its tests | about 300 of 353 | only `clear_capabilities` is used (`os.rs:143`, `:169`) | yes; move `clear_capabilities` into `os.rs` |
| `broker_volume_custody::{BackupTarget, Copy}` | 40 (`:276-315`) | no caller | yes |
| `resident_launch::{start_attested, compare_attested_volume}` and `volume_custody::VolumeWitness::compare_open_mount` | about 35 | no caller; production uses `prepared.start` (`resident_service.rs:1761`) | yes, or wire them in (they are the "last physical boundary" check their comments promise) |
| static supervisor template `<prefix>-spk-supervisor-s<store>@.service` | `broker.rs:705-720` (16) | never instanced; `OnFailure` names the per-app concrete unit (`broker.rs:174-176`) | yes |
| visibility drop-in | `broker.rs:1071-1076`; `broker_home::render` returns `""` (`:202-208`) | `render` always returns empty | delete `render`'s empty branches and the drop-in path, or implement real visibility |
| helper verbs `Mount`, `Thaw`, `Destroy` | `volume_helper.rs:288-315` | no broker verb sends them; they are reachable only by direct sudo | Destroy is a hazard (F8); either expose it with an authority story or delete it |
| `grain_management` snapshot capabilities | `grain_management.rs:15-17` | validated, never consumed | drop the fields or wire snapshotting |
| `spawn_gate::spawn_sandbox` callers | `sandbox.rs:349-398` | used only by the smoke binaries (shard A: unrun since 09-27) | goes with those binaries |
| `grain prepare-resident`, `grain unit-name` | `grain.rs:1464-1466`, `:1542` | wired to scripts but absent from `usage()` (`:1376-1386`) | document |
| `grain current-profile`, `runtime-status`, `adopt-runtime`, `rebind-profile`, `session-intents` | profile upgrade (640) + runtime adoption (693) | no script in `scripts/`, `deploy/` or `native/` calls them, except `native-input-successor.py` and the same-store inputs mentioning profiles; no evidence directory | candidate cut for the demo |
| `spk-host checkpoint-pause-check`, `checkpoint-backup`; `checkpoint-control.sock` | `broker_checkpoint.rs` (222), `checkpoint_control.rs` (470) | client `scripts/spk-platform/checkpoint-app.py` exists; no evidence of a run; `SAME-STORE-AND-CHECKPOINT.md:268-270` says "Actual root receiving and failure-cut rehearsal are required before scheduling this path" | candidate cut |

## 5.2 Stale `#![allow(dead_code)]` headers and stale comments

| file:line | text | reality |
|---|---|---|
| `spawn_gate.rs:7` | "Staged until the native BEGIN adapter can call it; no public launch path." | called from `hostd.rs:1662` (production START) and `resident_privilege.rs:390` |
| `resident_launch.rs:4` | "Native lifecycle-v2 Host route is not linked yet." | used by `resident_service.rs:1512`, `:1639`, `:1761` |
| `resident_service.rs:5` | "Enabled only after root reviews the exact native cut." | it is the resident |
| `descriptor_native.rs:6` | "Joined INSTALL/START resident caller follows native link." | called through `author_signed_launch` |
| `launch_descriptor_native.rs:7` | "Resident v3 START caller follows the source-qualified route." | called from `grain.rs:522`, `main.rs:36-47`, `resident_launch.rs:111` |
| `volume_custody.rs:4` | "Connected only after source-qualified v3 START routes." | called from `resident_service.rs:1559` and STOP |
| `claim_descriptor.rs:4` | "Resident lifecycle-v2 route is not linked yet." | accurate: the module is dead |
| `setid_bound.rs:1-11` | "the resident installs this filter on every thread" | it never does |
| `broker.rs:422-423`, `:444-446`, `:537-538` | "root directory", "Root reads operator files", "Write a root file" | the broker runs as the operator |
| `broker.rs:494-495` | orphan doc comment "`/etc/minidregg/spk/host-identity`: root 0600..." attached to `fn systemctl` | the identity is `$GRAINS/host-identity` (`install-user-world:151`) |
| `grain.rs:328-330` | "(`/etc/minidregg/spk/host-identity`, root 0600)" | same |
| `resident_service.rs:1251` | "Its unit (rendered by the root broker)" | operator broker |
| `deploy/spk-host/spk-var-volume:14` | "Invoked by mini-spk-broker (root)" | invoked by the root helper, called by the operator broker |
| `broker_runtime_adoption.rs:1` | "Per-Store root runtime adoption" | operator |
| `deploy/spk-host/README.md:7`, `:36-56`, `:78-96`, `:103-106`, `:132`, `:147-150`, `:189-197` | root broker on `/run/mini-spk-broker.sock`; "no run CLI"; `AmbientCapabilities`, `ProtectSystem=strict`, `setid_bound`; `Type=oneshot` supervisor; root `mini-spk-broker backup`; `/etc/mini/spk-broker.json`; `/etc/minidregg/spk/host-identity` | all superseded (USER-TENANCY, 10-08; bwrap namespace, 10-15) |
| `deploy/spk-host/BROKER-RUNTIME-UPGRADE.md:5-9`, `:75-80`, `:109-113` | "root broker"; "Omission means the existing `/run/mini-spk-broker.sock`"; "production always requires root socket ownership and root peer credentials" | `broker_endpoint.rs:6-27` refuses every path except `runtime-<store>/broker.sock`; the peer is the operator |
| `scripts/spk-platform/jspk1.sh:105-118` | connects to `/run/mini-spk-broker.sock` and asserts root 0660 | the journey cannot run against the current broker without edits |

## 5.3 Tests that do not test what they claim

- **The sandbox-floor root tests** (`resident_launch.rs:578-625`) cannot pass with the current `spawn_bounded` (F2).
- **`tenancy_bootstrap_actual_zero_capabilities_namespace_refusal_and_eof_reap`** (`resident_privilege.rs:564-688`) runs the worker with `_audit = true`, which selects `spawn_privilege_audit`, which calls `spawn_inner(spec, true)` with `test_mode` set (`spawn_gate.rs:544-548`). Test mode skips the bwrap file-name check and the fd requirement, and the test launches `/usr/bin/sleep` with five copies of `/dev/null`. It validates the identity, capability and EOF-reap mechanics. It validates nothing about the sandbox floor. That is honest in its doc comment ("This qualifies physical isolation/reaping, not native app admission"), but it is the only test of the production identity path.
- **The seccomp tests** (`seccomp.rs:398-561`) check the compiler against an in-file BPF interpreter (`run`, `:403-440`) written by the same hand. The interpreter is small and the opcodes are standard. The real-kernel check was the floor probe, which is now unrunnable (F2).
- **`broker_volume_custody` physical tests** (`:416-453`) are `#[ignore]` and need root and a disposable loop root. They are good tests, with no recorded run in `docs/evidence`.
- **`grain_export` recovery tests** (`:633-858`) use a `FakeHost` that returns canned replies. They test the lookup-first ordering, not the Lean receiver.

## 5.4 Twins (law 13: delete the twin)

| what | sites | reachable | keep / delete |
|---|---|---|---|
| broker entry point | `mini-spk-broker serve` (`bin/mini-spk-broker.rs:8-10`); `spk-host broker-serve` (`main.rs:62-70`) | the unit uses the first; `BROKER-RUNTIME-UPGRADE.md:7` documents the second | keep one (the unit's) |
| backup entry point | `mini-spk-broker backup CONFIG OUT` (`broker.rs:1139-1141`, a standalone `Broker::load` outside the serving process); broker verb `backup` (`:1108-1115`, via `grain backup`); `spk-host checkpoint-backup` (`broker_checkpoint.rs:189-222`, also standalone) | all three | keep the broker verb; the standalone loads race the serving broker (serialized only by the helper's verb lock) |
| BPF assembler | `seccomp.rs:263-357` (policy compiler); `setid_bound.rs:57-183` (label assembler, dead); `resident_privilege.rs:51-110` (raw opcodes) | first and third | express the resident filter as a second policy file through `seccomp.rs`; delete `setid_bound`'s |
| memfd seal | `seccomp.rs:361-396`; `native/pinned_execution.rs:21-55` (private-backend); `native/resource-client/src/transport.rs:1377-1390` | all | one helper crate |
| pinned execution | hash then exec by path (`launch_descriptor_native.rs:88-221`, `PrivateOperator::tool`); sealed memfd exec (`pinned_execution.rs`) | both | adopt the sealed version |
| supervisor unit text | `broker.rs:705-720` (template, dead) and `broker_runtime_adoption.rs:447-461` (live) | second | delete the first |
| SPK descriptor field comparison | `descriptor_native.rs:179-220`; `resident_launch.rs:178-222`; `claim_descriptor.rs:155-214` | the first two (the third is dead) | one function `check_package_view(view, package, bridge, schema)` |
| bridge-profile refusal (saveIdentityCaps, expectAppHooks, checked_prefix) | `materialize.rs:299-315`; `descriptor_native.rs:107-115`; `resident_launch.rs:140-148`; `claim_descriptor.rs:135-146` | the first three | one `BridgeConfig::supported()` |
| canonical-decimal validators | `broker::decimal` (`:107`, non-zero, at most 18 digits); `volume_custody::decimal` (`:22`, returns `u64`); `descriptor_native::decimal` (`:72`); `launch_descriptor_native::decimal` (`:356`); `claim_descriptor::canonical_decimal` (`:32`); `completion_custodian::canonical_decimal` (`:23`); plus the used `lifecycle_selector::decimal` and `lifecycle_v3_native::decimal` (shard C) | all | **eight definitions with three different rules** (zero allowed or not, 18 versus 128 digits). Unify, and take the rule from Lean |
| lowercase-hex encoders | `resident_launch::hex_bytes` (`:74`), `resident_service::hex_bytes` (`:2145`), `completion_custodian::hex` (`:14`), `descriptor_native::hex` (`:56`), `launch_descriptor_native::hex` (`:31`), `claim_descriptor::hex` (`:16`), `export_receipt::hex` (`:16`), `grain_export::hex` (`:28`), `lifecycle_v3_native::hex` (shard C) | all | one |
| 64-hex validators | `broker::hex64`, `grain::hex64`, `resident_service::hex64`, `volume_helper::hex`, `volume_custody::hex32`, `checkpoint_control::digest`, `launch_descriptor_native::lowercase_sha256` | all | one |
| bounded private-file readers | `grain::read_private` (`:89`), `resident_service::private_file` (`:76`), `launch_descriptor_native::read_private` (`:57`), `resident_launch::retained_descriptor_file` (`:32`), `grain_export::recovery_read` (`:226`), `checkpoint_control::retained` (`:49`), `broker::read_private_operator` (`:376`), `broker_runtime_adoption::operator_bytes` (`:133`), `broker_checkpoint::op_bytes` (`:20`), `broker::volume_pause_bytes` (`:1394`) | all | one `custody::read_private(path, max, Owner)` with options |
| atomic writers | `grain::derived_file` (`:123`), `broker::write_operator_text` (`:539`), `grain_export::{write_new, retain_exact}` (`:68`, `:269`), `dispatch_native::write_new` (shard C), `hostd::atomic_write_locked` (reused by checkpoint), the inline pointer write in `grain_profile_upgrade.rs:405-416` | all | one |
| file SHA-256 | `broker::file_sha256` (`:390`), `grain::file_sha256` (`:164`), `grain_export::sha256_file` (`:45`), inline in `spawn_gate.rs:207-219` and `namespace_identity.rs:67-71` | all | one |
| "is this unit quiescent" | `broker_runtime_adoption::unit_quiescent` (`:486-505`); `grain_profile_upgrade::stopped` (`:304-369`, the same property parse); `hostd` audits (shard A) | all | one |
| volume naming | `broker::volume_name` (`:166`); `volume_custody::VolumeSite::name` (`:93`); `spk-var-volume:62`; `grain::persistent_var` (`:656`) | all | one Rust source and one bash source; keep the bash pinned by a test |
| SPK size bound | `grain::MAX_SPK` (`:41`), `materialize::MAX_SPK_BYTES` (`:18`), broker ingest `256*1024*1024` (`:936`), `spk-ingest:19` | all | one constant |
| peer credentials | `broker::peer_credentials` (`:1167`), `http_entrance::peer_uid` (shard A, used by `checkpoint_control.rs:273`), `endpoint.rs` (shard A) | all | one |

## 5.5 Versioned siblings still present

| family | versions present | live? |
|---|---|---|
| START lifecycle lane | v3 (`start-admitted-v3`) and governed repeat v4 (`start-admitted-retry-v4`) (`resident_service.rs:277-400`) | both live; failed-START recovery handles only v3 (F4) |
| committed claim inspection | v2 (`claim_descriptor.rs`, dead), v3, v4 | v2 dead |
| package identity inspection | v1 (no API or `/repo.git/`), v2 (other API prefixes) | both live, selected by the API path |
| launch descriptor inspection | v2, v3 (follows the package version) | both live |
| agent API | V2 (`AgentCustody`) and V3 (`LifetimeCustodyV3`) (`resident_service.rs:132-154`, `:1476-1498`, `:2103-2139`) | both live |
| broker config | v3 only (v1/v2 refused, `USER-TENANCY.md:26-28`) | ok |
| grain host profile | `mini-spk-grain-host-v2` plus `genesisConfigSha256` lineage | live |
| placement | broker `-v1`; grain `-v2` (`grain.rs:404`) | live, two different records |
| failed-start recovery | `-v1` | live |
| resident config | `mini-spk-resident-start-v3` | live |

---

# 6. Size and shape

## 6.1 Lines per file

The per-file table is in "Files covered" at the top. Totals: **16,249 lines; 3,269 test (20.1%); 12,980 code.** The largest are `resident_service.rs` (2,665), `grain.rs` (1,702) and `broker.rs` (1,434). The broker family together is 3,382 lines and the grain family 3,347.

Root-only or `#[ignore]` physical tests inside those regions: `resident_launch.rs:578-625`, `broker_volume_custody.rs:416-453`, the root branch of `spawn_gate`'s tests, and `resident_privilege.rs:564-688` (non-root but needs `/etc/subuid`).

## 6.2 A minimal version that keeps only the demo path

The demo path is: install one host-owned SPK, route it, start it, keep it running under the supervisor, stop it, recover a failed START on the v3 lane, and keep the per-world broker and root helper.

**Drop outright (no rewire needed beyond deleting call sites that are themselves dead):**

| file or block | lines |
|---|---:|
| `claim_descriptor.rs` | 310 |
| `setid_bound.rs`, except `clear_capabilities` (about 15 lines, moved to `os.rs`) | 338 |
| `broker_volume_custody.rs` `BackupTarget`/`Copy` | 40 |
| `resident_launch.rs` `start_attested`/`compare_attested_volume` + `volume_custody.rs` `compare_open_mount` | 35 |
| `broker.rs` static supervisor template | 16 |
| `broker_home.rs` (renders nothing; replace with real unit hardening or nothing) | 267 |
| **subtotal** | **1,006** |

**Drop with a small rewire (features a demo does not need):**

| feature | files and blocks | lines | rewire |
|---|---|---:|---|
| checkpoint pause and backup | `broker_checkpoint.rs` (222), `checkpoint_control.rs` (470), the checkpoint arms in `resident_service.rs:1918-1930`, `:1937-1942`, `:1975-2001` (about 40), `volume_helper.rs::paused` (`:140-168`, 29) | about 761 | delete `refuse_retained_pause` and the aux fd |
| compatible profile upgrade and runtime adoption | `grain_profile_upgrade.rs` (640), `broker_runtime_adoption.rs` (693) | 1,333 | `Host::load` keeps only a direct profile read; the broker's `runtime_for` returns the config pin; drop the `adopt-runtime`/`runtime-status` verbs and `require_unit_runtime` |
| grain export and import | `grain_export.rs:1-207` plus tests (about 330 incl. tests), `grain.rs:1312-1358` (47), the import branches in `install` (about 20), helper `create-from` (Rust about 15; bash about 60) | about 470 | keep `reconcile_failed_start` (move it to its own module) |
| member-owned app delegation | `grain_management.rs` | 147 | refuse member-owned apps (the current default already does without a selector) |
| export capture receipt | `export_receipt.rs` | 276 | delete two call sites in `dispatch_delivery` and the header capture in `http_entrance` |
| v4 retry lane (resident side) | `StartLane` RetryV4 branches and `retry_v4_paths`/`retire_retry_v4_markers`/`start_retry` in `resident_service.rs` (about 250) | about 250 | plus shard C's `lifecycle_v4_retry_*`; keeps failed-START recovery coherent (F4) |
| agent API V2/V3 in the resident | `resident_service.rs:113-154`, `:1456-1511`, `:1891-1899`, `:2097-2141` (about 200) | about 200 | plus shard C's `agent_api_*` |
| **subtotal** | | **about 3,437** | |

A demo-minimal shard B would therefore weigh about 16,249 − 1,006 − 3,437 ≈ **11,800 lines**, of which about 2,600 are tests. That is a 27% cut.

The shard-C modules unlocked by dropping v4 and the agents are not counted here. Collapsing the twins in 5.4 (decimal, hex and reader helpers, the descriptor comparisons) would save roughly another 400-600 lines across the shard.

---

# 7. Deployability on a small public Linux VM

## 7.1 What must exist on the box

- A Linux kernel with unprivileged user namespaces enabled (Hetzner's Ubuntu restricts them through AppArmor, which then needs the profiled `/usr/local/libexec/mini-grain-bwrap` plus ACLs, `install-user-world:138-150`), cgroup v2, and the loop and ext4 modules. `FIFREEZE` must be supported by the backing filesystem.
- Packages: bubblewrap (with `--disable-userns`, so 0.10 or later), uidmap, sudo, e2fsprogs, util-linux (`setpriv`, `losetup`, `findmnt`), acl, jq, and systemd with the user manager.
- The operator user with linger, plus `/etc/subuid` and `/etc/subgid` ranges of at least `count` UIDs starting at 65536 or above.
- Root setup: run `install-user-world install ...` once per world (registry, sudoers, `/var/lib/mini-spk-worlds/<store>`, `host-identity`).
- Binaries: `spk-host`, `mini-spk-broker` and `spk-ingest` in `~/.local/libexec`; `mini-spk-volume-helper` root-owned in `/usr/local/libexec`; the Mini Host binary and config; the operator socket (Host).
- Disk: the full class size per grain, preallocated (S 512 MiB, M 1 GiB, L 2 GiB), plus image trees, plus exports. Backups go to `GRAINS/<store>/exports` and are never pruned.
- Memory: each grain's slice cap covers **both the app and its resident**, and the resident re-parses the SPK at START (F14). The ingest unit needs 2 GiB transiently, and a START or STOP drives the Host through history replay. On the 10-01 numbers (persvati, load 20-45, old architecture) a START took 452-1,128 s, a STOP 3,062 s, and an install 412-751 s. A 4 GB VM fits two S grains, or one M, per `README.md:130-131`.

## 7.2 What the operator configures

`broker/config.json`, `grain-host.json` (the Host, config, socket and management keys, completion custodian seed, bwrap pin, spk-host pin), the class per install, routes (shard A), and the `deploy/spk-host/mini-spk-broker@.service` user unit.

## 7.3 What is dangerous to expose

Nothing in this shard listens on TCP. The dangerous surfaces are indirect:

1. **The app's HTTP surface** (through shard A's entrance, then Mini admission, then fd 3) reaches the app inside the sandbox. An app exploit then faces the seccomp/userns floor (good, but unmeasured in its current form, F2) and the kernel.
2. **The fd-3 Cap'n Proto stream from the app to the resident.** A sandboxed app that exploits the resident's parser becomes the operator (F1). This is the boundary that decides whether hosting third-party SPKs for strangers is safe. Today it is a single Rust parser with no secondary containment.
3. **Root-reaching verbs** (sudo helper: Create, Mount, Unmount, Freeze/export, Thaw, **Destroy**, status) are reachable by anything running as the operator UID, which includes every resident (F1, F8).

## 7.4 What a stranger on the internet can exercise

A stranger can reach only what shard A's entrance exposes, and only with a route token (bootstrap, cookie or bearer). Without a token, nothing in this shard is reachable.

## 7.5 What a malicious enrolled member can exercise

- Anything the app allows over Mini-admitted requests. Disk is quota-bounded by the ext4 volume (`spk-var-volume:192`), memory and tasks by the class slice, and WebSockets by the class caps (S1).
- **Crash the app** with any request the app mishandles. The generation then ends, followed by STOP and continue-START (about 40 minutes each on 10-01 numbers), and after 3 crashes in 30 minutes the supervisor gives up and the grain stays down (F11).
- **Trigger an uncertain dispatch**, which fences every participant of the grain until operator recovery (shard A/C, `dispatch_delivery.rs:113-124`, hosted by this resident).
- Read the host's hostname from inside the app if the app reflects it (F3, low).
- Nothing in this shard lets a member choose a class, a UID, a path or a command. Those come from operator files and Lean receipts.

---

# 8. Questions for the Lean side

Each question should be answerable by pointing at a declaration.

1. **v4 retry lane recovery.** Is there a Lean recovery path for a governed repeat CREATE (v4) whose START failed after its claim? `Host/ApplicationFailedStartRecoveryTools.authorReport` decodes `ApplicationLifecycleBeginV3Ingress` and `ApplicationLifecycleClaimV3Ingress` only (`:96-101`). Is there a v4 analogue of `ApplicationFailedStartRecoverySource`, or a theorem that a v4 claim cannot reach the failed-START phase (9)?
2. **Plan determinism for op 206.** Does `ApplicationFailedStartEndpoint.prepare` (`Host/ApplicationFailedStartEndpoint.lean`) produce byte-identical plan bytes for the same request at two different verified tips, or under unchanged law? Rust retains `plan.bin` exactly and refuses a different re-derivation (`grain_export.rs:572`). If the plan binds the tip, a crash between ops 206 and 208 wedges recovery (F5).
3. **Custodian signature on the failed-START report.** `authorSignedReport` checks only `publicKey.length == 32 && signature.length == 64` (`Tools.lean:116-118`). Which declaration in the 208 receiver path verifies the Ed25519 signature against the genesis `completionCustodianKey`, and that the public key in the signed report equals it?
4. **`createdIndex` check.** In the v3 BEGIN for `Continue{createdIndex}`, which declaration checks `createdIndex` against the prior create's completion receipt? Rust derives it as `acceptedCount - 1` (`grain.rs:1057-1060`). Is that the same quantity Lean expects (a history index, or something else)?
5. **Generation ownership.** Is `processGeneration` in the v3 BEGIN authored by Lean from the application's current state (so Rust's `g<N>` must simply match), or does Lean accept a Rust-proposed generation? Rust picks `max + 1` (`grain.rs:1040-1048`) and only later compares (`:876-886`).
6. **K-SPK size class.** Where will the size class (`broker::CLASSES`: memory, tasks, CPU and IO weight, `/var` MiB, WebSocket caps) be pinned in Lean (the app birth descriptor?), and is there an existing field for it in `ApplicationGrainBirth` or `ApplicationSpkPackageIdentity`?
7. **K-SPK export binding.** Is there, or will there be, an `ApplicationGrainExport` / `import_binds_stop_receipt` declaration? Until then, does any Lean law or receipt record that an application resource's `/var` was seeded from an import (`grain.rs:710-715` writes `import.json` locally only)?
8. **SPK signature in Lean.** `ApplicationSpkPackageIdentity` carries `signedAppId` and `manifestSha256` supplied by Rust. Does any declaration verify the Sandstorm package signature (the Ed25519 key that *is* the app id) over the signed manifest bytes, or is the app id a Rust attestation?
9. **Resource id bound.** What is the largest application resource id Lean can allocate? Rust refuses ids of 19 or more digits (`broker.rs:107-113`, `volume_custody.rs:255`).
10. **Witness trust.** `DREGG/SPK-VAR-CUSTODY/v1` (`spk-var-volume:298`) is produced by root bash and read by the operator resident. Which Lean declaration consumes the witness bytes (the report or claim source), and does Lean check anything beyond the custodian signature (the field layout, `volume_id` equal to the BEGIN's)?
11. **Restart cost.** Does each supervisor STOP plus continue-START cost funding or tariff in Lean? If it does, the Rust restart policy (`StartLimitBurst=3` per 1,800 s) is a spending policy and should be a law (S6).

---

*Scratch for this shard: `/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/spk-B/` (`wc.txt`, `sizes.txt`, `sandstorm/supervisor.c++`).*
