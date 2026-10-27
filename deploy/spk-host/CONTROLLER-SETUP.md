# A separate controller account for one test world

The normal world installer can provision one controller per registered Store.
This is explicit operator setup, not Mini admission. A controller gets its own
system UID, private group, home and four role keys. It does not receive Store
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
controller-remove STORE HELPER
```

`controller-create` returns `controllerHome`, `controllerUid`, `listenerSocket`,
`reverseSocket`, `operatorSocket` and `operatorPeerUid`, along with the allocated
account, group, unit names and home inode. Account names are fixed to
`mini-c-STORE`; the system allocator chooses an unused UID. Existing names,
operator/app UID collisions and a different calling operator refuse.

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

`BIN_DIR` supplies `grain-runtime`, `mini` and `minidregg-host`. All source files
must belong to the registered operator, be regular single-link files under
protected, non-symlink ancestors, and have no set-ID bits, writable group/other
bits or file capabilities. Each binary is bounded to 256 MiB. Configurations are
bounded to 512 KiB/1 MiB and each accepted-source file to 1 MiB. The installer
records exact hashes and copies binaries under root custody. Supplied binaries
never run as root. Empty `workspace` and the named state/custody directories are
allowed; arbitrary bundle directories are not.

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
An existing request ID refuses. Tool-result and acknowledgement use the same
fixed runtime and native control socket. A call has a 20-minute deadline and
16 MiB combined output bound; failure after sending still requires exact
request recovery, never an automatic resend. No general command runner exists.

`controller-journal` returns only the native controller journal. `controller-export`
returns bounded state evidence (at most 512 regular files / 32 MiB, with hashes
and base64 bytes), excluding the separate custody directory and its keys.
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
immutable copying, fixed unit users, request-ID reuse, and refusal to broaden an
existing ACL. Actual account/systemd setup and the complete source-admitted tool
journey remain separate receiving tests.
