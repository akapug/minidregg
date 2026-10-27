# Resident privilege and process custody

The resident consumes app-controlled Cap’n Proto bytes. Identity-switching
capabilities therefore cannot remain with its parser, even when a syscall
filter restricts their nominal target. A new user namespace can change the
meaning of credentials and capabilities. The boundary must establish the
host identity before app input, rather than rely on every parser remaining
uncompromised.

## Fixed bootstrap, two unprivileged parsers

The broker renders a fixed generation unit in the operator's user manager. The
unit runs as the operator UID with `AmbientCapabilities=` empty and
`NoNewPrivileges=no`: the setuid `newuidmap`/`newgidmap` must still work, and the
bootstrap sets no_new_privs itself before any parser runs. Its trusted
environment selects separate operator and app UID/GID pairs and the physical
bubblewrap, by path and SHA-256 (broker config v3 `bwrap`/`bwrapSha256`, rendered
as `MINI_SPK_BWRAP`/`MINI_SPK_BWRAP_SHA256`). App packets can select none of
them. Its executable enters `resident-bootstrap`, which parses only those
broker-selected values and the root-owned world registry before reading resident
configuration or app bytes.

The bootstrap never creates a namespace itself. bubblewrap creates the user
namespace. It is the one sandboxing binary the host provides for grains:
`deploy/grain-host/resolve-bwrap` picks the AppArmor-profiled
`/usr/local/libexec/mini-grain-bwrap` when present and usable, else
`/usr/bin/bwrap`. newuidmap/newgidmap map exactly the two identities into it.
The bootstrap then joins it by `setns` and stays the unit MainPID (`hostd`
compares MainPID with its own PID). Running the resident *inside* bwrap would
make bwrap's monitor the MainPID and hide the resident's exit status from
systemd, so the namespace is joined, not wrapped.

The parent retains the unit's MainPID, switches to the operator identity, clears
supplementary groups and all five capability sets (including bounding and
ambient), and verifies real/effective/saved UID and GID plus no_new_privs.
It denies unshare, setns, namespace-bearing clone and clone3 before the
configuration/SPK/Cap’n Proto consumers begin; ordinary threads still work.

The worker independently switches to the fixed app identity and performs the
same credential/capability checks before parsing its bounded launch JSON. It
closes inherited non-channel descriptors and clears its environment. It keeps
no identity-switching capability. Its private channel accepts one launch with
five inherited descriptors, then only bounded wait/stop commands. UID/GID are
absent from that packet schema.

The worker intentionally does not inherit the operator namespace-denial filter:
the pinned bubblewrap executable must create the app sandbox. It is the same
bwrap build that created the resident namespace: the resident refuses a
`resident.json` whose `bwrapSha256` differs from the broker-rendered one. Its
path may differ (a per-app-identity copy, `sandbox-launcher-stage.py`); the spawn
gate refuses one the app identity cannot execute after the drop, deciding by the
mode bits or, when the file has one, its POSIX access ACL, and names which of its
conditions failed. On a host shipping the profiled copy `root:hbox 0750`,
`install-user-world` grants the operator and the world's app identities named
`r-x` ACL entries and revokes the ones it added at removal.
Its host identity is already the separate app UID, with no host capability or
supplementary group that can map another host UID or reach operator custody.
This is a distinct physical boundary from the operator parser. The sandbox’s own
namespace and seccomp floor remains necessary and unchanged.

### Each claim, and what establishes it

bwrap flags establish the namespace and nothing else. Its capability flags
(`--cap-add`/`--cap-drop`) govern bwrap's own child, which here is a namespace
holder that runs `/usr/bin/true` and exits. They cannot reach a process that
joins afterwards, so the credential floor stays in the bootstrap's code.

| Claim | Established by |
|---|---|
| A new user namespace, made by the host's permitted creator | `bwrap --unshare-user`, with the bwrap resolved and pinned by path and SHA-256. On a host with `kernel.apparmor_restrict_unprivileged_userns=1`, the profiled copy's `userns` rule is what permits creating it with capabilities |
| Exactly two identities, operator and app, mapped | `--userns-block-fd 4` with the required `--info-fd 3`: bwrap writes no uid/gid map, reports `child-pid` and waits. Then `newuidmap`/`newgidmap PID op op 1 app app 1` run under the operator's `/etc/subuid`/`/etc/subgid` grant, and `/proc/self/{uid,gid}_map` must be exactly those two rows. A non-setuid bwrap can map only its caller's own UID, so a second identity needs this hook |
| The namespace is the one bwrap made, held before bwrap is released | `child-pid`'s `PPid` is the bwrap process, and `/proc/PID/ns/user` is opened (and differs from the caller's) before the block fd is written |
| bwrap leaves nothing running | `--die-with-parent`. Its child runs `/usr/bin/true` under `--ro-bind / /`, and the bootstrap requires bwrap to exit 0 before it joins |
| The resident is the unit MainPID | `setns(CLONE_NEWUSER)` by the single-threaded bootstrap itself, not an exec under bwrap |
| No supplementary groups | `setgroups(0)` right after joining (newgidmap leaves `setgroups` allowed), re-checked by `holds_exactly_identity` |
| Bounding, ambient and all five capability sets empty; real/effective/saved UID/GID exact; no_new_privs | `os::drop_to_identity` and `os::holds_exactly_identity` in both parent and worker. This is bootstrap code, because no bwrap flag reaches a joining process |
| No unit-level ambient capabilities | `AmbientCapabilities=` in the rendered unit |
| The operator parser cannot create or enter namespaces | the parser seccomp filter (unshare, setns, namespace clone flags, clone3) |
| One launch over the private channel; no identity selector in packets | the bootstrap channel wire (`deny_unknown_fields`, bounded frames, tags 1/2/3/4, and 6 after the launch) |
| The operator reads only what the app published | tag 6 carries no descriptor and no path: the worker opens `www` under the grain's own `/var` as the app (`O_DIRECTORY | O_NOFOLLOW`) and returns that one descriptor; the resident opens every file beneath it as the operator (`www_publish.rs`, `O_NOFOLLOW` per component), so the kernel admits only world-readable files and directories; nothing is written |
| The app sandbox runs the same bwrap build | `ResidentBound::validate` (resident config `bwrapSha256` must equal the broker-rendered one) and the spawn gate's name/inode/SHA pin and its mode/ACL execute decision for the app identity |

## Source admission still selects the work

This split creates no launch authority. The existing source-bound preparation,
current native lifecycle claim, journal lock, executable SHA/inode checks and
fd3/image/volume/seccomp/output gate precede the channel send. The worker repeats
the executable and descriptor shape checks. It cannot choose a different app
identity. A partial send or lost reply consumes the one channel; it does not
create permission for a second START.

Package origin and physical custody do not imply a current user grant. The native
source admission and each operation’s current authority remain independent of
the installed package and the resident’s process credentials.

## Reaping is physical evidence, not a receipt

The worker is the actual parent of the app child and owns its waitpid. The
operator receives the retained PID/start identity over the private channel. It
never fabricates a successful app waitpid because it cannot reap a grandchild.
Channel EOF causes the worker to kill/reap its actual direct child; the operator
can then reap its own worker. A channel error does not confirm child death.

All processes remain in the original generation unit and cgroup. KillMode is
control-group. If the worker dies, a direct-child result alone cannot prove that
a descendant is gone. STOP or failed-START reconciliation must independently
audit the exact retained Unit, InvocationID and cgroup and refuse a current job,
new incarnation or populated cgroup before native completion. Pause-for-backup
is not this fence, and a portable archive acknowledgment cannot replace it.

## Qualification and limits

The focused wire checks reject packet identity selectors, unbounded frames and
false reap success after channel loss, and check descriptor close-on-exec. The
unprivileged fixture (`tenancy_bootstrap_actual_zero_capabilities_namespace_refusal_and_eof_reap`)
changes credentials only in disposable forked children: it enters through the
resolved bwrap (MINI_BWRAP selects) with the first identity of the caller's
`/etc/subuid` grant as the app. On a host that restricts unprivileged user
namespaces it fails with `/usr/bin/bwrap` ("Failed to make / slave") and passes
with the profiled copy. It checks all capability sets, groups and no_new_privs,
namespace refusal and ordinary threading, then launches a harmless inode/SHA-pinned executable and
verifies actual EOF-driven app/worker reaping with an independent root observation.
This fixture does not author a native launch receipt or qualify hosted app
readiness, real browser interaction or provider completion.

A production role still needs its ordinary binary build, source/role seal and
current admitted profile transition. An already claimed failed generation must
first reconcile its exact original operation under the original configuration.
Changing the launcher or role is not permission to reset that retained claim.
