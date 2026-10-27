# SPK host

`native/spk-host` is the physical half of a Sandstorm SPK grain under Mini:
it installs, launches, sandboxes, routes, stops and recovers one app per Mini
application resource. It decides no authority. Install, START, every HTTP
request and WebSocket open, and STOP are authored, signed and admitted by the
Lean Host; Rust holds the processes, the files and the evidence.

Deployment steps (root install, operator user units, subuid ranges) are in
[USER-TENANCY.md](USER-TENANCY.md). Nothing here runs as root except the
one-shot `mini-spk-volume-helper` that `install-user-world` admits through
sudoers.

## Who runs what

| process | identity | what it does |
|---|---|---|
| `mini-spk-broker@STORE.service` | operator, systemd **user** unit | one JSON line per connection on `WORLD/runtime-STORE/broker.sock` (operator-owned 0600, peer uid = operator); verbs `identify`, `init-store`, `place`, `set-cgroup`, `ingest`, `mount-volume`, `unmount`, `adopt-runtime`, `runtime-status`, `install-unit`, `start`, `stop`, `export-volume`, `backup`; renders the per-generation resident unit, its class slice and its hardening drop-in |
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

`sandbox::FIXED_ARGS` and `seccomp/resident-web.policy`:

- new user, PID, IPC, UTS, cgroup and network namespaces (loopback only),
  `--disable-userns`, `--cap-drop ALL`, hostname `sandbox`;
- the package root read-only from an open fd, the bounded ext4 `/var`, a
  128 MiB `/tmp`, `/proc`, and a read-only 64 KiB `/dev` holding only null,
  zero, full, random, urandom and the /dev/fd link;
- RLIMIT_NOFILE 1024 (hard), set at spawn;
- a default-ENOSYS seccomp allowlist: AF_UNIX/INET/INET6 sockets only, no
  namespaces, mounts, ptrace, bpf, io_uring, keyrings or module calls; and,
  as Sandstorm's supervisor refuses them, no `seccomp`/`PR_SET_SECCOMP`,
  legacy AIO, `vmsplice` or memory-policy calls;
- fds 0-3 only: `/dev/null`, the private output pipe (16 MiB kept per
  generation) and fd 3.

`scripts/spk-platform/sandbox-floor-audit.sh` measures this floor through
the production bootstrap and spawn path, run as the operator on Linux, inside
a transient unit carrying the resident unit's own properties, and fails by
name if bwrap does not start under them.

**bwrap version dependence.** bubblewrap 0.11 and later (Debian 13 ships
0.12.0) resolve every new-root path with `openat2(RESOLVE_IN_ROOT)` and have no
fallback; 0.10 (hbox) does not use `openat2`. Any unit setting that installs a
systemd seccomp layer returning ENOSYS for `openat2` kills bwrap at its first
mount (`bwrap: Can't mkdir parents for /dev: Function not implemented`).
systemd 257's `RestrictSUIDSGID=yes` does; so the resident and every
bwrap-launching unit must not carry it (the resident cannot take
`NoNewPrivileges=yes` or `NoExecPaths=` either, see above; the app's `/var` is
mounted `nosuid,nodev` and bwrap's own mounts are nosuid). The pinned bwrap
(`MINI_SPK_BWRAP_SHA256`, or a profiled copy such as
`/usr/local/libexec/mini-grain-bwrap`) is therefore qualified per version:
re-run the floor audit on the target host whenever the pinned binary changes.
The app's own seccomp policy allows `openat2`.

## Requests, lifecycle, recovery

- Routes and the HTTP entrance: [HTTP-CUSTODIAN-CONTRACT.md](HTTP-CUSTODIAN-CONTRACT.md).
- The dispatch fence and outcomes: [MINI-CLAIM-DISPATCH-CONTRACT.md](MINI-CLAIM-DISPATCH-CONTRACT.md).
- WebSockets and their authority leases: [BROWSER-WEBSOCKETS.md](BROWSER-WEBSOCKETS.md),
  [WS-AUTHORITY-LEASES.md](WS-AUTHORITY-LEASES.md), [STREAM-CONTINUITY.md](STREAM-CONTINUITY.md).
- START and STOP are lifecycle v3 (BEGIN op 22, CLAIM op 26, COMPLETION op 38;
  lookups 23, 27, 39); a governed repeat CREATE uses the v4 lane on the same
  opcodes. A lost submit reply is answered by the lookup, never a resend.
- A crashed generation fails its unit; `OnFailure=` runs `spk-host grain
  supervise`, which STOPs the dead generation through Mini and continues on the
  same `/var`. A START that failed after its claim is reconciled through
  `reconcileFailedStart` (ops 206-209), on either lane's retained artifacts.

## Ingest and volumes

`spk-ingest` (its usage line names the arguments) parses and materializes a
signed SPK in a short-lived unit with a 2 GiB memory cap, no network and a
SHA-pinned host executable; a killed unit is not an installed package. The
parser verifies the signature, archive hash and manifest, refuses escaping
names, and publishes a read-only image by no-replace rename. `spk-var-volume`
(called only through the helper) creates a class-sized ext4 image, mounts it,
and publishes the `DREGG/SPK-VAR-CUSTODY/v1` witness the resident checks
against the Mini-selected volume before launch. Imported images are parsed in
userspace by e2fsprogs as the app uid and never mounted from operator bytes.

Size classes are `broker::CLASSES` (S/M/L memory, CPU, tasks, IO weight,
`/var` size, WebSocket caps); they are operator policy until a Lean
declaration pins them.
