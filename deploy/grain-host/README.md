# Linux grain worker host

This directory supplies a Linux launcher for `native/grain-runtime`. The
runtime remains the Mini authority and budget controller. Its worker process
uses this `bwrap` executable and its sibling `launch-gate` executable. The
launcher creates a distinct transient **user** systemd service for each
reserved operation. The gate is that service's `ExecStart` and executes the fixed command
inside a bubblewrap mount, user, PID, IPC and cgroup namespace. The name is
`mini-grain-t<TASK>-o<OPERATION_ID>` and comes from the runtime's durable child
marker as `MINI_GRAIN_UNIT`. The runtime also supplies
`MINI_GRAIN_STATE_DIR`, `MINI_GRAIN_CUSTODY_KEY`, and, when configured,
`MINI_GRAIN_TOOL_CUSTODY_KEY`, `MINI_GRAIN_PROVIDER_CUSTODY_KEY`, and the
key broker's socket `MINI_GRAIN_CREDENTIAL_BROKER` (native/mini-keys: the
controller holds no provider key; the broker does), plus `MINI_GRAIN_TASK_CONFIG` and
`MINI_GRAIN_HOST_CONFIG`. The launcher refuses any mount (including `/usr`
and the optional network certificate mounts) that contains these paths, and
refuses a unit name that already exists. If the controller sets
`MINI_GRAIN_BROKER_SOCKET`, the launcher binds exactly that Unix socket at
`/run/mini-grain.sock` for the MCP broker client in `/agent/grain-runtime`;
the state directory itself stays hidden.

Example fixed runtime command (the operator chooses paths and amounts):

```json
{"name":"hermes-acp", "program":"/opt/mini/deploy/grain-host/bwrap",
 "args":["--workspace","/srv/mini/grains/7001/work",
         "--runtime-root","/opt/hermes/runtime",
         "--network","none","--","/agent/hermes-acp"],
"systemdScope":true,"reserve":"10000","charge":"10000"}
```

The hosted Hermes preview keeps the worker network isolated. Model requests
use the mounted provider bridge, whose controller checks the signed Mini
provider task and budget; the worker does not receive the provider credential.
The example above describes worker launch only, not a complete provider
configuration. On hbox, the [qualified upstream startup](../../docs/evidence/2026-09-27-hermes-upstream-hbox/README.md)
uses a dedicated root-owned bubblewrap executable and AppArmor profile because
the generic executable cannot create the required namespaces under that
host's policy. That evidence covers confined ACP startup, not a model prompt.

`launch-gate` is the candidate's `bin/launch-gate` (role `launchGate`,
`deploy/candidate/package.py` `ROLES`), built only by `cargo build -p launch-gate`
from `native/launch-gate`, whose binary target is `launch-gate.rs` in this
directory (`native/launch-gate/Cargo.toml`, `libc` pinned there). Journeys take
that binary as `LAUNCH_GATE` (`native/grain-runtime/hermes-journey.sh`); only
`probe.sh` compiles its small socket helper (`probe_socket.rs`) with a bare `rustc`. Install it beside `bwrap`; both must be executable. The launcher verifies the sibling gate's
exact protocol response before advertising its own protocol to the runtime.
Before spawning, the controller durably arms
the operation gate and records the exact unit name in its private state. The
service's `ExecStart` runs `launch-gate run STATE_DIR UNIT -- /usr/bin/bwrap …`.
After a hard disconnect or crash, the controller durably fences the gate before
killing **all** processes in that unit with
`systemctl --user kill --signal=SIGKILL --kill-whom=all NAME.service`. This
also blocks a start request that reached systemd but has not executed yet. The
controller must audit the unit stopped before clearing the child marker or
reconciling the Mini reservation; a failed fence or audit leaves it unresolved.
The wrapper also kills the unit when it receives TERM, INT or HUP. Gate
tombstones must remain while an operation ID might be reused. An old journal
entry alone must never trigger an automatic kill of a possibly reused unit.

## Controller unit installation

`install-controller` writes the one unit shape grain-runtime's own checks
accept: `mini-grain-controller@TASK.service`, running a persistent
`grain-runtime serve`, with the exact task, executable and config paths. It
has two modes (`native/grain-runtime/src/systemd_manager.rs` `load` is the contract);
there is no template unit to edit (the cross-manager launch gate a SYSTEM controller
needs for USER workers is in [CONTROLLER-LIFETIME.md](CONTROLLER-LIFETIME.md)):

- **user** (default, run as the task account): a user unit under that
  account's user manager with all three of `MINI_GRAIN_CONTROLLER_MANAGER=user`,
  `MINI_GRAIN_WORKER_MANAGER=user` and `MINI_GRAIN_CONTROLLER_UNIT=<unit>`.
  Setting only some of them is a hard error at open; setting none opens the
  controller unscoped, and its first sandboxed prompt then fails.
- **system** (`--system --service-user NAME`, run as root): a system unit with
  `User=NAME`, controller manager `system`, worker manager `user`, and the
  root-owned registration `/etc/mini/controllers/TASK.json`
  (`mini-controller-registration-v1`: task, config, managers, service uid,
  optional `residentConfig`). Workers are still user units, so the account
  needs linger, and the scoped launcher must answer
  `--controller-manager-protocol` (the shipped `bwrap` does).

The runtime JSON must configure
`controlSocket` directly inside its durable private `stateDir` (for example,
`/var/lib/mini/grains/task-7001/control.sock`). The task account must own
that directory and keep it at mode 0700. The launcher reads
`MINI_GRAIN_CONTROLLER_UNIT` and adds a `BindsTo=` dependency: stopping the
controller service also stops its worker units.

Run the installer as the task account after placing the runtime JSON and
executables. The pins file is JSON with one entry per executable, including
the runtime, `mini`, Mini host, every scoped `bwrap` command, and each
`bwrap` sibling `launch-gate`:

```json
{"artifacts":[
  {"path":"/opt/mini/bin/grain-runtime","sha256":"REPLACE_WITH_64_LOWERCASE_HEX"},
  {"path":"/opt/mini/bin/mini","sha256":"REPLACE_WITH_64_LOWERCASE_HEX"},
  {"path":"/opt/mini/bin/minidregg-host","sha256":"REPLACE_WITH_64_LOWERCASE_HEX"},
  {"path":"/opt/mini/bin/bwrap","sha256":"REPLACE_WITH_64_LOWERCASE_HEX"},
  {"path":"/opt/mini/bin/launch-gate","sha256":"REPLACE_WITH_64_LOWERCASE_HEX"}
]}
```

```sh
install-controller --config /opt/mini/grains/7001.json \
  --runtime /opt/mini/bin/grain-runtime \
  --pins /opt/mini/grains/7001-pins.json \
  --unit-dir "$HOME/.config/systemd/user" --render-only
install-controller --config /opt/mini/grains/7001.json \
  --runtime /opt/mini/bin/grain-runtime \
  --pins /opt/mini/grains/7001-pins.json \
  --unit-dir "$HOME/.config/systemd/user"
systemd-analyze --user verify "$HOME/.config/systemd/user/mini-grain-controller@7001.service"
# After inspecting the unit and signed Mini task state:
systemctl --user enable --now mini-grain-controller@7001.service
# Or, as root, the system shape with its registration:
install-controller --system --service-user grain-7001 \
  --config /opt/mini/grains/7001.json --runtime /opt/mini/bin/grain-runtime \
  --pins /opt/mini/grains/7001-pins.json --render-only
```

The installer never enables or starts a unit. The unit directory must already
exist, be owned by the task account, and be in its user systemd load path.
Installation is atomic and refuses an active unit, a conflicting unit file,
a journal bound to another task, unpinned or changed executable bytes, or
paths requiring systemd escaping (spaces, `%`, quotes, backslashes). The
private JSON, keys and state remain outside worker mounts. Pins identify
operator-selected artifact bytes **at installer time**; an artifact writable
by the same Unix account can change later. Their provenance and compatibility
still need the separately retained source/build evidence. Deploy executable
artifacts in immutable, administrator-owned locations before starting a
friend's controller.

### Creating an agent that can call applications

`grain-runtime create SPEC.json` accepts an optional `dispatch` purse alongside
its parent, tool and provider tasks. This births a separate funded task and
delegates its parent witness through ordinary Mini operations. It does not
install an application or issue an application grant.

The `dispatch` object contains `key` (the enrolled subject, private key path and
`noPrerotation`, as for `provider`), `task`, `observeCapability`,
`controlCapability`, `budget`, and `transport`. The transport supplies
`reserve`, `charge`, `socketPath`, `hostUid`, `operatorSocket`,
`operatorPeerUid` when needed, and `reserveSigner` using the controller's
existing dispatch format. `create` derives the identity and witness fields;
transport cannot override them. Task IDs, subjects, keys and capability IDs
must not collide with the other configured roles.

The application operator and controller run as separate Unix accounts. The
controller's ordinary Host socket and private dispatch operator socket are
separate endpoints. Create the transport directories and operator route before
running the controller's part of `create`; its normal validation checks the
socket ownership and peer restrictions. The existing `--birth-socket` phase
lets the operator fund the grains before the resident takes custody.

The resulting `controller.json` includes `dispatchTask`. Application attachment
then adds the routes and service catalogue backed by that same world's accepted
grants. A route copied from another controller or Store is not an attachment.

For two controllers sharing one Mini content page, run
`check-hosted-pair ABS_CONFIG_A ABS_CONFIG_B` after both JSON files and worker
directories are staged, before installing either unit. This read-only check
requires separate parent/tool identities, state, custody files, working
directories, workspaces and runtime roots, and checks that neither worker
mount exposes either controller's keys, config or state. It accepts a shared
Mini host socket and host config. This is a path preflight for a reviewed,
artifact-pinned `bwrap` launcher; the positional arguments alone do not prove
what the executable will mount. Run `install-controller` separately for each
config to check private keys, mode-0700 state, executable pins and live unit
ownership. Distinct paths do not prove distinct key contents or inode identity,
and this single-account test is not production account isolation. Native
content grants, policy generations and source provenance require signed Mini
readback and retained build/acceptance evidence. The
[hosted pair recipe](HOSTED-PAIR.md) uses `render-hosted-pair` to produce two
private command overlays and pin manifests from already-provisioned base
configs; it does not start either service.
Offering one already-provisioned grain to a friend over SSH (`render-friend-key`,
`grain-ssh`) is [FRIEND-GRAINS.md](FRIEND-GRAINS.md).

`grain-ssh` is an SSH
forced-command front end for the runtime's `connect ABS_CONTROL_SOCKET
hard|soft` mode. A per-task `authorized_keys` entry fixes the absolute
runtime and socket paths and uses OpenSSH's `restrict` option. For example,
after installing the persistent service and task configuration:

```text
restrict,command="/opt/mini/deploy/grain-host/grain-ssh /opt/mini/bin/grain-runtime /var/lib/mini/grains/task-7001/control.sock" ssh-ed25519 AAAA... hard-key
restrict,command="/opt/mini/deploy/grain-host/grain-ssh /opt/mini/bin/grain-runtime /var/lib/mini/grains/task-7001/control.sock soft" ssh-ed25519 AAAA... soft-key
```

The two-argument entry defaults to **hard**: SSH EOF interrupts an active
worker and the persistent controller fences its Mini generation. **Soft** is
an explicit third argument in a separate fixed entry: SSH EOF detaches while
the already reserved task may finish; a later connection can reattach. The
wrapper ignores `SSH_ORIGINAL_COMMAND`, sends exactly one attach line, and
forwards only the controller's line interface. Wait for its `attached ...`
or reconnect message before entering `hermes PROMPT`, an allowlisted
`run NAME`, `status`, `conversation new`, `recover`, or `disconnect`.
Attachment can take seconds while Mini confirms the transition; a refusal is
printed and closes the SSH connection. A reconnect resumes the task's
controller and retained Hermes conversation when its state permits; it does
not claim to resume an interrupted provider call or settle unresolved effects.

The persistent controller process is required for hard SSH EOF to signal the
worker before Mini fencing and for a deliberate soft attachment to continue
after SSH disconnect. A direct SSH forced command invoking `serve` is unsafe
for those semantics. The controller socket must be accessible only to the
intended Unix account; separate users need separate account/socket policy.

The caller must run under a working `systemd --user` manager with `bwrap` and
unprivileged user namespaces. The runtime root should contain only the fixed
worker executable and its nonsecret assets. The workspace is the worker's
sole host writable mount. The launcher clears inherited environment variables
and does not mount the controller's key, configuration or state directory.
`--network none` has no network access; the Hermes room resident uses it
(`worker.network` in `deploy/hermes/demo/install-hermes`; `grain-runtime grain-create`
refuses sandbox tools on any other network, `check_values` in `native/grain-runtime/src/grain_create.rs`).
`--network host` permits the worker to
reach the host network, including loopback services, and is suitable only
when those services have their own authorization boundary. Provider credentials
and network policy still need a dedicated deployment decision.

The unit's runtime ceiling is the command's `wallTimeSeconds`, which the
runtime passes as `MINI_GRAIN_RUNTIME_MAX_SEC` (`worker_env` in `native/grain-runtime/src/main.rs`);
without it the launcher uses 600 seconds and accepts 1 to 1800 (`runtime_max_sec` in `bwrap`).
The memory ceiling defaults to 2 GiB and the task ceiling to 128 (`memory_max` and `tasks_max` in
`bwrap`, overridable by `MINI_GRAIN_MEMORY_MAX` and `MINI_GRAIN_TASKS_MAX`). Those are physical backstops, not Mini allowance units or provider
usage measurements. A `--network host` worker cannot be treated as having
network egress containment. Do not use this script to start a task until its
Mini host, custody key, task IDs, budget and reconciliation records are
independently bootstrapped.
