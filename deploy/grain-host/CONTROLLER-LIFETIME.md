# Cross-manager controller lifetime

Canonical deployment can place the controller in SYSTEM systemd with its fixed
service UID while sandbox workers remain in that UID's USER manager. USER
`BindsTo` cannot name a SYSTEM unit. The launcher therefore requires an
incarnation-bound launch gate for that topology.

At `init`, the source runtime supplies the explicitly selected manager, canonical
controller unit, active MainPID and InvocationID. The gate checks the manager
observation, process UID and Linux process start time and persists the tuple with
the armed operation. At `run`, it verifies the tuple before and after opening a
pidfd. A replacement controller cannot adopt the old operation. Missing or changed
identity refuses before sandbox launch. An old gate binary refuses the extended
armed record rather than silently dropping the lifetime requirement.

The gate remains the worker unit MainPID and supervises the existing bubblewrap
sandbox. Controller pidfd readiness immediately kills/reaps bubblewrap, then persists a
fence. The existing `started` record already blocks replay; a contended gate lock
or slow fsync must not extend sandbox lifetime.
The monitor's child has a parent-death signal, and bubblewrap retains its existing
`--die-with-parent` and PID namespace, so monitor death also kills sandbox
children, including processes that create new sessions. The worker cgroup remains
the exact operation's cgroup; ordinary source recovery fences before killing and
requires inactive/MainPID-zero/empty descendants as before. A stop is asynchronous
and must still be physically observed before releasing/reusing a slot. This adds
no native settlement or completed-effect claim.

Same-manager legacy USER controllers retain `BindsTo`; tuple-bearing USER gates
can also use the monitor. The `--controller-manager-protocol` handshake returns
`mini-controller-manager-v1`. Runtime manager selection comes from the root-owned
controller registration, not probe-and-fallback. The gate's tuple is durable;
worker execution does not trust a fresh environment to replace it.

## Checking it

On a Linux host with a SYSTEM manager, `probe-controller-lifetime.py SOURCE_DIR NEW_PRIVATE_SCRATCH`
starts a transient SYSTEM controller (`Type=exec`, service UID = caller), actual USER worker units and
the production bubblewrap launcher, with a compiled `launch-gate` beside `bwrap`. It retains every
command's output in `commands.jsonl`, writes `result.json`, and cleans only its own units. Its eight
checks: wrong PID and wrong invocation refuse before arming; gate lock contention cannot extend sandbox
lifetime (the gate flock is held through the controller SIGKILL until every sandbox descendant is gone);
a controller crash fences the gate and kills sandbox descendants; a queued old launch refuses after
controller restart; a new controller cannot adopt an armed prior incarnation; restart cannot rearm a
fenced operation; a monitor crash kills the sandbox and its setsid descendants; an ordinary controller
stop kills the current worker. Each held sandbox includes a child and a setsid grandchild.

The canonical template must use `Type=exec`: under systemd's default `Type=simple` the reported
MainPID may not yet have dropped to the configured UID, and the gate correctly refuses it.

`scripts/overnight-tests/launch-gate-probe.sh` covers the single-manager cases: a late queued launch
after fence, fence before init, and exact running-unit kill with retry refusal.

This is lifecycle and confinement evidence, not a native grain budget or provider-effect journey.
