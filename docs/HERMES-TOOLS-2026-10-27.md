# Hermes sandbox tools: files, a terminal and Python inside the worker

ember, 2026-10-27: "we should give these guys file tools! and other tools! we
should figure out how to contain them, and integrate that with minidregg."

Until now a room resident with `restrictTools` (the default) saw only Mini's
verbs: nine room tools, plus workspace, publish, gitweb and application-API
for a task. Upstream Hermes's own file, terminal, browser and Python tools were
switched off, and the worker had no network except the provider bridge. This
document sets out how a resident gets the file, terminal and Python tools back
inside the worker it already runs in, what contains them, how what they make
leaves through Mini, and who pays for the CPU they use.

## 1. The shape in one paragraph

A room's founder sets room field `hermes/tools`, a bitmask: 1 for the file
tools, 2 for the terminal, 4 for Python. The operator's `controller.json` sets
the most it allows (`sandbox.tools`). For a resident prompt the controller
grants the intersection. It launches the worker with a fresh `/scratch` tmpfs
sized by the grain class, under the class's memory and task limits, with no
network, and asks Hermes for exactly those upstream toolsets. Before admitting
the session it checks that Hermes's reported tool names equal the Mini
catalogue plus exactly those names. Everything the agent makes in `/scratch`
disappears when the worker exits. Anything meant to last leaves through a Mini
tool (`mini_doc_append`, `mini_say`, `mini_publish`, `mini_application_api`),
each one an admitted, paid, receipted turn under Hermes's grants. A gate
outside the sandbox measures the worker's CPU, and the resident pays one
`hermes/turn` for every `hermes/compute` seconds of it.

## 2. Containment

The worker is the existing launch-gated transient unit
`mini-grain-tTASK-oOP.service`, running `bwrap` with `--unshare-net`, a user,
pid, ipc, uts and cgroup namespace, `--clearenv`, read-only `/usr` and
`/agent`, and `/workspace` (Hermes's own home). The changes:

| Bound | Before | With sandbox tools |
|---|---|---|
| Scratch | none | `--size N --tmpfs /scratch`, N = `sandbox.scratchMib` (S 512, M 1024, L 2048: the class `volume_mib`); gone when the unit exits |
| `/tmp` | unbounded tmpfs | 64 MiB tmpfs |
| Memory | `MemoryMax=2G` fixed | `MINI_GRAIN_MEMORY_MAX` = class `memory_max` (S 512M, M 1G, L 2G); tmpfs pages count against it |
| Tasks | `TasksMax=128` fixed | `MINI_GRAIN_TASKS_MAX` = class `tasks_max`, capped at 1024 |
| CPU | none | `CPUWeight` = class `cpu_weight`; `CPUQuota` = `sandbox.cpuQuotaPercent` (default 100: one core) |
| One file | unbounded | `LimitFSIZE` = the scratch size: no single file can exceed the volume, including under `/workspace` |
| Wall time | `RuntimeMaxSec` ≤ 1800 per worker | unchanged; each tool call is also bounded by Hermes's own `terminal.timeout` / `code_execution.timeout` (`sandbox.toolCallSeconds`, default 120), and the unit's bound is the hard one |
| Network | none (`--unshare-net`), the provider bridge only | unchanged |
| Host paths | `/usr`, `/agent` read-only, `/workspace` read-write | unchanged plus `/scratch`; no `/etc`, `/home`, `/var`, `/run` except the two Mini sockets |
| Secrets | the launcher refuses any mount that exposes controller state, custody keys, the task or Host config or the key broker | unchanged |

**Why a shell inside the sandbox sees no host path.** DreggNet shipped a
hosted raw shell and withdrew it after a red-team CRITICAL: `bash -c` on the
operator's box could `cat` the operator's key files and a co-tenant's home by
absolute path, then `curl` them out
(`~/dev/DreggNet/docs/HOSTED-ISOLATION.md:7-41`). Scrubbing the environment
and re-rooting `$HOME` stopped `~`-relative reads only. Its per-tenant bwrap
redesign was never deployed. Here the confinement is the mount namespace
itself, not anything inside the process. The worker's entire filesystem is what
`deploy/grain-host/bwrap` builds (the exact arguments, in order):

```
/usr/bin/bwrap --die-with-parent --unshare-user --unshare-pid --unshare-ipc
  --unshare-uts --unshare-cgroup --clearenv
  --ro-bind /usr /usr --symlink usr/bin /bin --symlink usr/lib /lib
  --symlink usr/lib64 /lib64 --dev /dev --proc /proc
  --ro-bind RUNTIME_ROOT /agent --bind WORKSPACE /workspace
  --chdir /workspace --setenv HOME /workspace --setenv PATH /usr/bin:/bin
  --disable-userns --cap-drop ALL --new-session              # sandbox tools only
  --size 67108864 --tmpfs /tmp --size SCRATCH --tmpfs /scratch   # sandbox tools only
  --dir /run --ro-bind PROVIDER_GATEWAY_SOCKET /run/mini-provider.sock
  --ro-bind MCP_BROKER_SOCKET /run/mini-grain.sock
  --unshare-net
  -- /agent/grain-provider-bridge --socket /run/mini-provider.sock --port P
     --seconds S -- /agent/hermes-acp --mini-sandbox-tools=…
```

So:
- **There is no host root.** The new root is an empty tmpfs that bwrap
  populates. Outside the listed binds nothing exists: no `/etc` (no `passwd`,
  `shadow`, `ssl`, `resolv.conf`), no `/home`, `/root`, `/var`, `/srv`, `/opt`,
  `/sys` and no host `/run`. `cat /etc/passwd` or `cat
  /var/lib/mini/hermes/homes/hermes/keys/mini.key` fails with "No such file or
  directory". The path is not refused; it does not exist.
- **The binds.**
  - `/usr` is the host's, read-only: system binaries and libraries, the same
    world-readable files every user of the box can read, holding no secret.
  - `/agent` is the operator-built runtime root (Hermes, its venv, the keyless
    `grain-runtime` MCP server and the bridge), read-only.
  - `/workspace` is this resident's own home and nobody else's.
  - `/scratch` and `/tmp` are fresh tmpfs instances in this mount namespace.
  - The launcher refuses to start (exit 77) if any bind contains the controller
    state directory, a custody key, the task or Host config, or the key-broker
    socket.
- **Other residents stay invisible.** Another resident's workspace is never
  bound. Its `/scratch` is a tmpfs inside another mount namespace, with no path
  to it from here. `--unshare-pid` with a fresh `/proc` shows only this
  sandbox's processes, so neither `/proc/PID/root` nor `/proc/PID/environ` of a
  host or co-tenant process exists.
- **No network.** `--unshare-net` leaves only loopback. A connect to any
  address fails with `ENETUNREACH`. The only listener is the provider bridge on
  loopback, which forwards to the gateway's Unix socket.
- **No privilege inside.** `--cap-drop ALL` clears the namespace
  capabilities. `--disable-userns` forbids nested user namespaces, so the
  kernel's unprivileged-namespace surface is closed to the sandbox.
  `--new-session` detaches it from any controlling terminal (no `TIOCSTI`).
  `--die-with-parent` and the gate's `PR_SET_PDEATHSIG` mean nothing survives
  the worker.
- **Bounded by the class slice.** The unit's `MemoryMax`, `TasksMax`,
  `CPUWeight`, `CPUQuota`, `LimitFSIZE` and `RuntimeMaxSec` are set by
  systemd on the transient unit that holds the whole sandbox (table above).
  tmpfs pages count against `MemoryMax`.
- **What is not here:** no Landlock and no seccomp filter. The mount, pid, net,
  ipc and user namespaces are the confinement, and an in-process rule would
  only duplicate them. A kernel bug in a namespace primitive is the residual
  risk, narrowed by `--disable-userns` and `--cap-drop ALL`. The planted-escape
  rows in §6 are the regression check.

**What a shell inside the sandbox can reach.** It can reach the same two
sockets Hermes already reaches: `/run/mini-grain.sock` (the MCP broker, which
forwards to the controller) and the provider bridge on loopback. The controller
is still the only policy point. A Mini tool called from a shell goes through
`Runtime::tool_call` and its `restrictTools` catalogue, the room grants, the
payment and the Host, exactly as one called by Hermes would. A model call made
from a shell with the prompt's lease token (in `/workspace/.hermes/config.yaml`,
rotated every launch) goes through the gateway's per-call caps, the key broker's
per-member caps and the purse. A shell gains no authority Hermes lacked; it only
gains a way to burn the same budget faster, and the class slice and the compute
metering bound that.

**What it can change.** The agent can rewrite its own Hermes config in
`/workspace/.hermes`. A wider toolset written there fails at the next session:
the catalogue check compares reported names exactly. A changed model or token
limit is refused by the gateway, which pins `max_tokens` and the row's caps.
The ACP final text is still checked against the provider's settled final, so
editing `state.db` cannot forge a reply.

**The one honest gap: `/workspace` has no total quota.** It must persist,
because Hermes's retained session lives there. `LimitFSIZE` bounds each file,
and the class memory, task and wall bounds limit the write rate, but there is
no total bound. The controller measures `/workspace` (allocated blocks) before
every launch and refuses the prompt by name (`workspace-over-class-volume`)
when it exceeds the class volume, so one run can overshoot by at most what it
writes inside its own bounds and never compounds. A hard quota is an
installation fact: on the demo box, `/var/lib/mini/hermes` on a filesystem with
project quotas and one project per task directory (an infra item). The code
needs nothing more.

## 3. The grant: who decides which tools

- **Operator ceiling:** `controller.json` → `"sandbox": {"tools": ["file",
  "terminal", "code_execution"], "scratchMib": 1024, "memoryMax": "1G",
  "tasksMax": 512, "cpuWeight": 100, "cpuQuotaPercent": 100,
  "toolCallSeconds": 120, "computeSecondsPerTurn": 10}`. It is absent by
  default, which means no sandbox tools. `grain-runtime create` fills it from
  `--class S|M|L` (the `spk-host` classes) when the spec asks for `sandbox`.
- **Room grant:** room field 1014 `hermes/tools` (bitmask: 1 = `file`, 2 =
  `terminal`, 4 = `code_execution`; 0 or absent = none), set by the founder
  with `tariff ROOM set hermes/tools N`. Like every room field write, the Host
  admits it under the founder's grant (closed schema, K-FIELD-CLOSURE); a
  member cannot set it. A room born before 1014 existed cannot declare it, so
  it gets no sandbox tools.
- **Per prompt:** the resident reads the room's signed view when it prepares
  an assignment (`hermes_room::prepare_resident`) and carries
  `sandboxTools` in the prepared assignment. The controller already binds that
  assignment by digest at `resident prepare`. At launch it grants
  `ceiling ∩ room grant`. A non-resident prompt gets none.
- **The catalogue check** (`room_task::require_acp_catalogue`) now takes the
  granted set: expected names = the Mini room catalogue (`mcp__mini_grain__*`)
  ∪ exactly the upstream names of the granted toolsets, with nothing more and
  nothing less:
  - `file`: `read_file`, `write_file`, `patch`, `search_files`
  - `terminal`: `terminal`, `process_manage`
  - `code_execution`: `execute_code`

  These are upstream Hermes Agent 6d8a8beb's `toolsets.py` names. A different
  pin means re-checking the names; the check refuses and does not guess.
- **The worker's side:** `/agent/hermes-acp --mini-sandbox-tools
  file,terminal,code_execution` exports `HERMES_MINI_SANDBOX_TOOLSETS`. The
  catalogue patch adds exactly those built-in toolsets to the MCP-only set and
  reports every loaded name, with `valid` true only when every name is Mini's
  or in the granted set. The generated `config.yaml` pins `terminal.backend:
  local`, `terminal.cwd: /scratch`, the per-call timeouts and
  `code_execution.timeout`.

No grant shape here touches admission: the room field write is an existing
founder write, and the intersection and catalogue are controller policy, like
`restrictTools`. So there is no Prop for the auditor in this piece.

## 4. Integration: the scratch area is not a store of record

`/scratch` is a tmpfs that lives exactly as long as the worker unit, which is
one prompt. Nothing in it is part of the world. What the agent made counts for
the world only once it leaves through a Mini write:

| Leaves as | Tool | Admitted as |
|---|---|---|
| a doc line | `mini_doc_append` | Hermes's paid turn; a doc mutate under its doc grant |
| a room message | `mini_say` | Hermes's paid turn; a room say |
| a published file (resource) | `mini_publish` (task catalogue) | a paid publication under `allowedPublications` |
| an app grain write | `mini_application_api` | an app dispatch under the app grant |

Each export is one admitted, paid and receipted turn under Hermes's grants, so
the world records what the agent produced and not every keystroke. A file
written in `/scratch` and never exported is gone after the prompt. After
dismissal, no worker of that task runs, so no scratch exists.

## 5. Metering compute

- **Measurement:** `launch-gate run --meter` keeps supervising its child and
  does not `exec` into it. When the child exits it reads `usage_usec` from its
  own cgroup's `cpu.stat`; under cgroup v2 that covers every descendant,
  including exited ones. It writes `STATE_DIR/UNIT.cpu`, which contains
  `mini-grain-cpu-v1 USEC`, as a private file. The sandbox cannot write
  `STATE_DIR`, because the launcher refuses a mount that exposes it.
- **Price:** room field 1015 `hermes/compute` = sandbox CPU seconds per paid
  turn (0 or absent means the operator ceiling's `computeSecondsPerTurn`). A
  turn costs the room's `hermes/turn`, like every Hermes write. The operator's
  ceiling is a floor on the block size, not a cap: a founder can make compute
  cheaper per second only up to what the operator allows.
- **Payment:** after a prompt that ran with sandbox tools, whether it ended
  completed, refused or failed, the resident reads `UNIT.cpu` and pays `k =
  ceil(usec / (seconds × 10⁶))` turns through `RoomTools::pay`. The memo is
  `op cOP-I compute` and each payment has its own exact operation record, so a
  rerun looks it up and never pays twice. A record the gate did not write (it
  died) is charged as `RuntimeMaxSec` of CPU at the quota: pessimistic, never
  an undercharge. When the account cannot pay, the payment is refused
  `bookRefused` like any turn and the resident stops with `out of budget`;
  the room sees it in Hermes's balance.
- **Why turns and not a purse quote:** a purse settle needs a Host-quoted
  amount, and the Host cannot observe CPU. Paying ordinary turns keeps
  admission unchanged: the Host admits a turn payment as it always has, and the
  count is the operator gate's measurement, the same trust the gateway's usage
  relay already carries. An operator-paid compute purse would need a Host basis
  for the amount, a new `ProviderMetering` leg, and its statement first. That
  is not built here.

## 6. Code execution: in-sandbox Python or a Jupyter grain

The other way to give an agent Python is the IPython Notebook SPK, which is
being qualified as an app. It would be a Jupyter grain that a resident drives
through `mini_application_api`.

| | In-sandbox `execute_code` / `terminal` | Jupyter grain via `mini_application_api` |
|---|---|---|
| State | none past the prompt (scratch dies with the worker) | a kernel and `.ipynb` that persist in the grain's volume |
| Record | only what the agent exports through Mini | every cell execution is an app dispatch: admitted, paid, receipted |
| Containment | the worker sandbox above, under the resident's class | the SPK grain's own sandbox and class slice (spk-host), separate from the resident |
| Cost | compute turns from the gate's CPU record | the app's dispatch tariff; frames unmetered by design |
| Sharing | none (one resident, one prompt) | members open the same notebook; the work survives the resident |
| Readiness | built here; needs only the runtime-root rebuild | the SPK is from 2016 and 178 MB, and stays unopened until its ceilings and a restart row pass (DREGGCLOUD.md:32) |
| Fit | files and quick scripts: compute a number, transform a file, check a claim | long or shared analyses, results a room should keep |

Both are wanted, and they compose: a resident uses the sandbox for quick
scripts and files, and `mini_application_api` against a room's Jupyter grain
when the work should persist or be shared. That needs no change here, because
`mini_application_api` is already in the task catalogue. Only the Jupyter grain
itself is still to be qualified.

## 7. The journey row (J14_TOOLS=1)

On top of J14's room: the founder sets `hermes/tools 7` and `hermes/compute
10`; the controller ceiling allows all three toolsets; the scripted librarian
(`--room-librarian-tools`) drives real upstream Hermes through:
1. `write_file /scratch/sum.py` (sum of squares 1..100), `terminal python3
   /scratch/sum.py`; the tool result must read `338350`;
2. `mini_doc_append` of `sum of squares 1..100 = 338350` to paper (one paid
   turn, receipted);
3. planted escapes, each run through the terminal and each required to fail
   inside the sandbox:
   - `cat /etc/passwd /etc/shadow` → no such file (no `/etc`);
   - `ls -la HOST_KEYS_DIR` (the run's real controller keys directory, an
     absolute host path) → no such file;
   - `ls HOST_STATE_DIR` (the controller state with `admin.sock` and the
     custody keys) → no such file;
   - `ls /proc` → only the sandbox's own PIDs; `cat /proc/1/environ` holds no
     `MINI_` variable;
   - another resident's scratch: `ls OTHER_TASK_STATE/../workspace` and a
     marker file planted in a second, concurrently running worker's `/scratch`
     → neither path exists here;
   - `python3 -c "import socket; socket.create_connection(('1.1.1.1',443),3)"`
     → `Network is unreachable`; the same to the host's operator socket path →
     no such file;
   - `unshare -U true` → refused (`--disable-userns`).

Rows: the session catalogue equals Mini ∪ the seven names; paper gains exactly
the one line, authored by Hermes; the three planted results are refusals inside
the sandbox (from the provider's request log of tool results); Hermes's balance
fell by the doc turn plus `k ≥ 1` compute turns, whose count equals the gate's
`.cpu` record; after dismissal, no `mini-grain-t9870001-*` unit is active and
neither `sum.py` nor any `/scratch` path exists under the task's state or
workspace on the host.

## 8. Files

- `deploy/grain-host/bwrap`: `MINI_GRAIN_SCRATCH_MIB`, the class limits,
  bounded `/tmp`, `LimitFSIZE`, `--meter` to the gate.
- `deploy/grain-host/launch-gate.rs`: `run --meter`, `UNIT.cpu`.
- `native/grain-runtime`: `Config.sandbox`, `grain_create` `--class`, the
  worker environment, the catalogue check over the granted set, the prepared
  assignment's `sandboxTools`, the workspace volume check, and the resident's
  compute payment.
- `native/resource-client`: room fields 1014 `hermes/tools` and 1015
  `hermes/compute`.
- `deploy/hermes/hermes-agent/mini-tool-catalogue.patch` and
  `build-runtime-root`'s `hermes-acp` entry.
- `native/hermes-test-provider`: `--room-librarian-tools`.
- `native/resource-client/journey.d/j14.sh`: `J14_TOOLS=1`.
