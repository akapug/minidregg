# SPK host

`native/spk-host` is the physical half of a Sandstorm SPK grain under Mini:
it installs, launches, sandboxes, routes, stops and recovers one app per Mini
application resource. It decides no authority. Install, START, every HTTP
request and WebSocket open, and STOP are authored, signed and admitted by the
Lean Host; Rust holds the processes, the files and the evidence.

Deployment steps (root install, operator user units, subuid ranges) are in
[USER-TENANCY.md](USER-TENANCY.md). At runtime nothing here runs as root except
the one-shot `mini-spk-volume-helper`, which the root-run `install-user-world`
admits through sudoers; the broker's own endpoint is described in
[BROKER-RUNTIME-UPGRADE.md](BROKER-RUNTIME-UPGRADE.md).

## Who runs what

| process | identity | what it does |
|---|---|---|
| `mini-spk-broker@STORE.service` | operator, systemd **user** unit | one JSON line per connection on `WORLD/runtime-STORE/broker.sock` (operator-owned 0600, peer uid = operator); the verbs are the `Request` enum (`native/spk-host/src/broker.rs:308`); renders the per-generation resident unit (`broker.rs:1062-1075`), its class slice (`broker.rs:922`) and its hardening drop-in (`broker_home.rs:211-230`) |
| `mini-spk-s<store>-a<app>-g<gen>.service` | operator, user unit | `spk-host resident-bootstrap`: bwrap creates a user namespace, `newuidmap`/`newgidmap` map exactly {operator, app} into it, the resident joins it, forks the launch worker as the app, drops every capability, and serves the app's routes |
| the app | the broker-placed app uid inside that namespace | bubblewrap with the floor below; fd 3 is its Cap'n Proto bridge |
| `mini-spk-volume-helper` | root, via sudoers | creates, attests and mounts the app's preallocated ext4 `/var` |

The resident unit keeps `NoNewPrivileges=no` because the setuid mapping
helpers must run; for the same reason it cannot take `ProtectSystem`,
`ProtectHome`, `PrivateTmp` or a `SystemCallFilter` (in a user manager each
implies `PrivateUsers=yes` or no-new-privileges). Its drop-in carries
`LimitCORE=0`, `LimitNOFILE=8192` and `KeyringMode=private`. A compromised
resident is the operator of the world (it holds every participant seed); the
resident's own filesystem confinement is still owed.

Names carry the Store: `<store>` is the pinned Host's `profile.storeTag`
(16 hex digits), so two Stores on one host never share a unit, slice or
volume.

## The app's sandbox floor

`sandbox::FIXED_ARGS` (`native/spk-host/src/sandbox.rs:43-64`) and `native/spk-host/seccomp/resident-web.policy`:

- new user, PID, IPC, UTS, cgroup and network namespaces (loopback only),
  `--disable-userns`, `--cap-drop ALL`, hostname `sandbox`;
- the package root read-only from an open fd, the bounded ext4 `/var`, a
  128 MiB `/tmp`, `/proc`, and a read-only 64 KiB `/dev` holding only null,
  zero, full, random, urandom and the /dev/fd link;
- RLIMIT_NOFILE 1024 (hard), set at spawn (`spawn_gate.rs:25`);
- a default-ENOSYS seccomp allowlist: AF_UNIX/INET/INET6 sockets only, no
  namespaces, mounts, ptrace, bpf, io_uring, keyrings or module calls; and,
  as Sandstorm's supervisor refuses them, no `seccomp`/`PR_SET_SECCOMP`,
  legacy AIO, `vmsplice` or memory-policy calls;
- fds 0-3 only: `/dev/null`, the private output pipe (16 MiB kept per
  generation) and fd 3.

`scripts/spk-platform/sandbox-floor-audit.sh` measures this floor through
the production bootstrap and spawn path, run as the operator on Linux, inside
a transient user unit carrying the resident unit's hardening properties
(`RESIDENT_PROPS` in the script), and names the openat2 class if bwrap's own
stderr reports `Function not implemented`. One recorded run: Debian 13.7,
bubblewrap 0.12.0, audit root `/var/lib/spk-floor-audit`, both audit tests
exit 0 (32 floor checks held, 21 expected pre-floor breaches), at lane/fence
`408296cb` on `dregg-build`
(`docs/evidence/2026-10-27-sandbox-floor-dregg-build/README.md`). The
script's detector matches only bwrap's own `bwrap: ...` lines; the run above
used an earlier detector that also matched the probe's JSON, so its
`results.txt` carries an openat2 line on a passing run.

**bwrap version dependence.** bubblewrap 0.11 and later (Debian 13 ships
0.12.0) need `openat2` (`broker_home.rs:265`). Any unit setting that installs a
systemd seccomp layer returning ENOSYS for `openat2` kills bwrap at its first
mount (`bwrap: Can't mkdir parents for /dev: Function not implemented`).
systemd 257's `RestrictSUIDSGID=yes` does; so the resident and every
bwrap-launching unit must not carry it (the resident cannot take
`NoNewPrivileges=yes` or `NoExecPaths=` either, see above; the app's `/var` is
mounted `nosuid,nodev` and bwrap's own mounts are nosuid). The pinned bwrap
(`MINI_SPK_BWRAP_SHA256`, or a profiled copy such as
`/usr/local/libexec/mini-grain-bwrap`) is therefore qualified per version:
re-run the floor audit on the target host whenever the pinned binary changes.
The app's own seccomp policy allows `openat2` (`seccomp/resident-web.policy:72`).

## Requests, lifecycle, recovery

- Routes and the HTTP entrance: [HTTP-CUSTODIAN-CONTRACT.md](HTTP-CUSTODIAN-CONTRACT.md).
- The dispatch fence and outcomes: [MINI-CLAIM-DISPATCH-CONTRACT.md](MINI-CLAIM-DISPATCH-CONTRACT.md).
- WebSockets and their authority leases: [BROWSER-WEBSOCKETS.md](BROWSER-WEBSOCKETS.md),
  [WS-AUTHORITY-LEASES.md](WS-AUTHORITY-LEASES.md), [STREAM-CONTINUITY.md](STREAM-CONTINUITY.md).
- START and STOP are lifecycle v3 (`lifecycle_v3_*_native.rs`); a governed
  repeat CREATE uses the v4 lane (`lifecycle_v4_retry_*_native.rs`). The
  opcodes live in the Lean kernel (`Kernel/ApplicationGrain.lean`), not here.
  A lost submit reply is answered by the lookup, never a resend.
- A crashed generation fails its unit; `OnFailure=` starts the broker-rendered
  supervisor instance (`broker_runtime_adoption.rs:447-461`, `Restart=on-failure`),
  which runs `spk-host grain supervise-instance GRAINS_ROOT STORE-APP`
  (`grain.rs:1564`). It STOPs the dead generation through Mini and continues on
  the same `/var`; an uncertain record is reported, never retried (exit 3,
  `grain.rs:1307-1312`). A START that failed after its claim is reconciled
  through `reconcileFailedStart` (`grain_export.rs:315`), on either lane's
  retained artifacts.

## Ingest and volumes

`deploy/spk-host/spk-ingest` (its usage line names the arguments: `--root SPK_ROOT [--import-profile PROFILE] HOST HOST_SHA256 INBOX_SPK APP_UID`) parses and materializes a
signed SPK as the Store operator (never root) in a short-lived **user** unit
with a 2 GiB memory cap (no swap), one CPU, a 16-task cap (`spk-ingest:44-48`), the import
profile's runtime cap (`standard-v1`: 120 s; `operator-appliance-v1`, selected
only by the operator broker's config: 1800 s) and a SHA-pinned host
executable. The unit sets `NoNewPrivileges` and those caps only: it is not
network- or filesystem-confined. A killed unit is not an installed package. The
parser verifies the signature, archive hash and manifest, refuses escaping
names, and publishes a read-only image by no-replace rename. `spk-var-volume`
(called only through the helper) creates a class-sized ext4 image, mounts it,
and publishes the `DREGG/SPK-VAR-CUSTODY/v1` witness the resident checks
against the Mini-selected volume before launch. Imported images are parsed in
userspace by e2fsprogs as the app uid and never mounted from operator bytes.

Size classes are `broker::CLASSES` (`broker.rs:59`) (S/M/L memory, CPU, tasks, IO weight,
`/var` size, WebSocket caps); they are operator policy until a Lean
declaration pins them.

### Slice tree (the class is in the name)

The broker renders, and only `broker::{grains_slice, class_slice, app_slice}` name:

```text
s{STORE}-{PREFIX}-grains.slice                      supervisors (no class)
  s{STORE}-{PREFIX}-grains-{S|M|L}.slice            one size class (rendered at broker start)
    s{STORE}-{PREFIX}-grains-{S|M|L}-a{APP}.slice   one app: its limits, its resident unit
```

The class is the one `set-cgroup` recorded (`grain.rs` `place`, from the app's declared
size class); `install-unit` refuses an app with no class, so no grain lands outside a class
slice, and a class change is refused once a unit is installed (the unit names its slice).
Resident units are `mini-spk-s{STORE}-a{APP}-g{GEN}.service` (a pinned grammar; the class
is in the slice, not the unit name). Per-grain CPU ceilings are drop-ins on the class
prefix, one per class, bounding each app of that class and not the class together:

```ini
# ~/.config/systemd/user/s{STORE}-{PREFIX}-grains-S-.slice.d/60-cpu.conf   (M: 50%, L: 100%)
[Slice]
CPUQuota=25%
```

A drop-in on `s{STORE}-{PREFIX}-grains-S.slice.d/` instead would cap every S app together.
The Hermes `mini-grain-controller@` / `mini-grain-resident@` units are not SPK grains and
are not in this tree.
