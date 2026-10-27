# A separate controller account for one test world

The normal world installer can provision one controller per registered Store.
This is explicit operator setup, not Mini admission. A controller gets its own
named UID, private group, home and four role keys. The UID and GID come from
the intersection of the operator's existing subordinate delegations. It does not receive Store
files, the Store operator's keys, or the primary private operator socket.

Run these verbs through the same authorized `install-user-world` entrypoint:

```text
controller-create STORE HELPER
controller-stage STORE HELPER BUNDLE BIN_DIR UPSTREAM_PRIVATE_SOCKET PUBLIC_SOCKET
controller-start STORE HELPER
controller-stop STORE HELPER
controller-config STORE HELPER NEW_CONFIG_OR_BUNDLE
controller-tool STORE HELPER REQUEST_ID TOOL ARGUMENTS_JSON
controller-tool-result STORE HELPER REQUEST_ID
controller-tool-ack STORE HELPER REQUEST_ID
controller-journal STORE HELPER
controller-export STORE HELPER
controller-reserve-export STORE HELPER DISPATCH_ATTEMPT_ID
controller-remove STORE HELPER
```

`controller-create` returns `controllerHome`, `controllerUid`, `listenerSocket`,
`reverseSocket`, `operatorSocket` and `operatorPeerUid`, along with the allocated
account, group, unit names and home inode. Account names are fixed to
`mini-c-STORE`. The installer selects one unused UID/GID from the operator's
existing `/etc/subuid` and `/etc/subgid` intersection; it grants no new range.
It creates the private group with that exact GID before creating the named
account with both explicit IDs. Existing accounts/groups, app ranges,
controller reservations, other principals' overlapping delegations and a
different calling operator refuse. Numeric subid-owner aliases are supported.
A controller name or numeric UID with its own stale subordinate grants also
refuses: the new controller must not inherit authority to map the operator.

A permanent root-owned reservation is written under
`/etc/mini-spk-controller-reservations/STORE.json` **before** either account or
group creation. Pending setup, failure, controller removal and world removal
never release that identity. Both future app allocation and controller
allocation enforce these reservations and retained removal receipts under the
same global installation lock. Malformed or unsafe registry data fails closed.
The installer bounds registry counts, delegation input, candidate enumeration
and NSS snapshots rather than silently truncating a range.

The provisioning operator is explicitly trusted: it generates the controller's
keys, supplies its code/configuration and already owns the delegated ID range.
It can create a separate user namespace and assume this subordinate controller
identity. This design protects Store/operator resources **from** the controller
and app; it does not protect controller custody from its provisioning operator.
Other users' overlapping subordinate ranges are excluded. The controller gets
no subordinate grants of its own.

The home is `WORLD/controller/home`, mode 0700. The forward app listener lives
outside it, in an operator-owned 0700 directory. The reverse custody listener
also lives outside the home, in a controller-owned 0711 directory: the current
runtime requires searchable ancestors and installs an operator-specific ACL on
the socket itself. Neither directory grants another account write access.

Stage only this explicit bundle, with no additional files or symlinks:

- `controller.json`, `host-config.json`;
- `custody/controller.key`, `tool.key`, `dispatch.key`, `provider.key` (32 bytes each);
- `state/shared-app-refs/app-birth.bin` and `bootstrap-ticket.bin`;
- optionally `state/shared-app-refs/agent-ticket.bin` and the four files
  `state/oracle-grant/{seal.json,call.bin,submit-marker.json,receipt.json}`.

`BIN_DIR` supplies `grain-runtime`, `mini`, `minidregg-host` and the source-matched
`minidregg-client-consent` for new version-2 allocations. All source files
must belong to the registered operator, be regular single-link files under
protected, non-symlink ancestors, and have no set-ID bits, writable group/other
bits or file capabilities. Each binary is bounded to 256 MiB. Configurations are
bounded to 512 KiB/1 MiB and each accepted-source file to 1 MiB. The installer
records exact hashes and copies binaries under root custody. Supplied binaries
never run as root. Empty `workspace` and the named state/custody directories are
allowed; arbitrary bundle directories are not.

The completed root setup also writes a small 0644 `WORLD/controller/namespace.json`.
Before parsing resident JSON, native bootstrap checks its root custody, exact
world/deployment/host/operator binding and named passwd/private-group identity.
It maps exactly the registered operator, app and controller single IDs through
`newuidmap`/`newgidmap`. A world without a controller keeps its original two-ID
map. A partial allocation without its completed receipt refuses; caller-supplied
controller numbers do not select namespace mappings. The app and resident still
drop all capabilities, supplementary groups and identity-switch privileges.
Forward and reverse peer checks compare the real mapped controller UID; root
ancestors use retained inode provenance, never a numeric overflow UID.

An already validated immutable receipt is a namespace snapshot. Removal racing
that read need not prevent the reader finishing its map, and running residents
retain their existing mappings. Permanent nonreuse prevents those mappings from
aliasing a later app/controller. This is not linearizable START-versus-remove,
not a controller-liveness check and not source-grant revocation. A later fresh
START with agent routes but no registered controller refuses before BEGIN.

The runtime system unit runs as the controller, with no supplemental groups,
no new privileges, a private temporary directory, a read-only system view and
writes limited to its home and reverse-socket directory. The operator proxy
runs as the Store operator. Both have a 2 GiB memory ceiling, no swap, one CPU,
128 tasks and a three-hour lifetime. Unit names and executable arguments are
fixed by the installer; substituted or already-loaded units refuse.

The activated operator socket is inside `HOME/operator`, controller-owned
0700/0600. Systemd creates the listener as root, so its measured connection peer
is **UID 0**, even though the proxy service runs as the Store operator.
`dispatchTask.operatorPeerUid` pins 0 separately from the application host UID.
See [the proxy contract](../../docs/oracle-controller-operator-proxy.md).
The public Host socket gets only a dedicated controller connect ACL and the
necessary ancestor traversal ACLs. Existing extended ACLs refuse rather than
having their masks widened. The primary private listener and Store files stay
unchanged. ACL intent and completion receipts retain exact inode identities.

New allocations also have a separate full consent service. Its activated socket
is `HOME/consent/peer.sock`, under a controller-owned 0700 directory with mode
0600. The service runs as the Store operator; the systemd-created listener's
peer UID remains 0. It runs only the root-copied `mini serve-controller-consent`
with a fixed provider, exact provider/configuration SHA-256 pins, controller UID
and `WORLD/controller/consent/anchors`. The service configuration is an
operator-owned 0600 copy of the exact `HOME/host-config.json` bytes. The
controller gets no Store/verifier/key access through this setup.

The runtime and fixed helper children select that service explicitly using
`MINI_CONSENT_SOCKET`, `MINI_CONSENT_PEER_UID`, `MINI_CONSENT_SHA256` and
`MINI_CONSENT_CONFIG_SHA256`, alongside the existing fixed `MINI_LOCAL_HOST`,
`MINI_CONSENT_HOST` and `MINI_CONSENT_CONFIG` selections. The ordinary runtime's
mini subprocesses inherit these values. Native consent retains this selection
in its per-attempt pins; the transport checks the exact config/provider binding
and controller peer, with no local or thin fallback. A controller config update
keeps the fixed host-config path; it does not change the service settings.

Only the operator-private anchor directory is writable through the consent
service's systemd filesystem view; the Store stays read-only. The verifier may
use its private temporary directory. Stop/start and controller configuration
updates preserve the `binding`, `frontier` and `lock` files. Missing/corrupt
retained state is a native refusal, not permission to replay from an empty
frontier. Removal first copies these exact bounded files, including an
incomplete initialization, to a root-private
`/var/lib/mini-spk-controller-history/STORE-consent` archive and records their
hashes. A changed archive refuses removal.

Stage returns the consent service/socket/provider/config/identity pins. Start
adds its observed systemd invocation, MainPID, process start ticks, exact
executable inode and socket owner/mode. This is labeled **process and socket
readiness only**; independent source admission is established by the actual
native request, not by systemctl or an invented health response. Version-1
allocations retain their original three units and three binaries for supported
stop/export/removal; setup does not silently retrofit an old failed attempt.

Stage the initial configuration, start the controller, and earn the session
birth through `mini_create_application_session`. After the real event22/event27
receipts exist, prepare and register the source-bound app route, and obtain the
actual host unit from `grain start`. Stop the controller before installing its
final configuration with that unit. `controller-config` accepts either one
configuration file or a bundle containing `controller.json` and the optional
final grant files above. Existing grant bytes are immutable; only byte-equal
copies are accepted. Every configuration revision is retained by hash. Restart
uses the existing native journal, not a fabricated birth record.

Tool IDs are exactly 32 lowercase hexadecimal characters. The four supported
tools are `mini_create_application_session`, `mini_oracle_discover`,
`mini_oracle_call` and `mini_grain_status`. Arguments are bounded to 256 KiB and
copied to a new controller-owned 0600 regular file **after dropping privilege**.
An existing request ID refuses. A per-controller shared lock spans the command
and its exact reap; stop, configuration replacement and removal need the
exclusive lock, so cleanup cannot race a new command after a process census. Tool-result and acknowledgement use the same
fixed runtime and native control socket. A call has a 20-minute deadline and
16 MiB combined output bound; failure after sending still requires exact
request recovery, never an automatic resend. No general command runner exists.

`controller-journal` returns only the native controller journal. `controller-export`
returns bounded state evidence (at most 512 regular files / 32 MiB, with hashes
and base64 bytes), excluding the separate custody directory and its keys.
For a successful call's authority probe, prefer `controller-reserve-export`:
a canonical decimal u64 selects exactly
`state/agent-lifetime-reserve-{ID padded to 16 decimal digits}/` and its eight
`source.json`, `pin.json`, `request.bin`, `plan.bin`, `plan.frame`, `call.bin`,
`receipt.json`, `submit-marker.json` files. It keeps the same evidence protocol,
hashes and base64 encoding, with 32 MiB total and 12,102,760 bytes per file.
It cannot select another directory or export keys. This avoids making an
increasingly large full-state export a prerequisite for a later successful call.
These exports contain controller activity and should remain private evidence.

Stop/remove validate the recorded account, home inode, unit files, binaries and
manager unit identity. Removal refuses unrelated live processes, mounted
subtrees, replaced ACL objects or changed ACLs. It removes only this account and
its recorded units, then retains a cleanup receipt under
`/var/lib/mini-spk-controller-history`. Ordinary world removal refuses while a
controller allocation remains. Interrupted setup retains its pending records;
an incomplete ACL mutation or account allocation without a completed identity
receipt needs operator repair, not an ownership guess or destructive retry.

The unprivileged tests are:

```sh
python3 -B deploy/spk-host/tests/test_controller_world.py
```

They exercise source-file custody, links, bounds, capability refusal, private
immutable copying, fixed unit users, request-ID reuse, actual Linux ACL grant/
restore, delegated-range intersection, foreign/NSS/stale-grant exclusions,
permanent and pending reservations, failure before account creation, and the
exact reserve evidence export, full-consent service pins, both configuration
copies, legacy layout compatibility, and retained partial anchor state. Actual account/systemd setup and the complete source-admitted tool
journey remain separate receiving tests.

The entrypoint executes only its SHA-256-pinned Python companion bytes, read once
through a bounded no-follow descriptor. Deploy both files together. The existing
operator-writable source entrypoint remains explicitly trusted root setup; this
pin prevents ambient sibling substitution and read/execute races, rather than
pretending to isolate root from an operator authorized to replace that entrypoint.
