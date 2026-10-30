# Controller access to operator planning

An agent controller and its application host use different operating-system
accounts. The controller needs source-authored reserve and payer plans, but it
must not receive the Store operator's private socket or credentials.

`mini serve-agent-operator-proxy` consumes one systemd-activated Unix listener
from fd3. `LISTEN_PID` must name the service process, `LISTEN_FDS` must be one,
and the bound socket pathname must equal the configured `--socket`. The service
runs as the Store operator, connects to the existing private operator, checks its
mode/config pins and connected peer UID, and never starts a second Host.

The socket's directory and node belong to the controller with modes 0700 and
0600. A root-owned socket unit creates that endpoint with `SocketUser` set to
the controller; the corresponding service uses the Store operator's `User`.
The parent directory must already have the controller's ownership. The service
receives the listener descriptor without needing pathname access through that
private directory. Systemd owns the endpoint's lifecycle; the proxy does not
unlink another account's socket.

The fixed service invocation is:

```text
mini serve-agent-operator-proxy --socket CONTROLLER-PRIVATE/mini.sock \
  --upstream STORE-OPERATOR-PRIVATE/mini.sock --config PINNED-CONFIG.json \
  --controller-uid CONTROLLER-UID
```

Every incoming connection must have that exact controller UID. Only operations
48, 58, 59, 78, 80 and 81 pass: current payer/paid-plan inspection and reserve
planning/assembly. Requests require a version-2 Host-image/config envelope and
retain their exact bytes. Submit, grant issuance, lifecycle management and other
operator operations refuse before the upstream connection. The existing frame,
connection and deadline bounds apply; a failure after forwarding stays uncertain.
The source Host still validates every plan and signature. This endpoint is a
physical route, not a new source permission.

Linux reports a Unix listener's creator credentials through `SO_PEERCRED`.
Changing the socket node's owner does not change those credentials. Thus the
controller configuration additionally pins `dispatchTask.operatorPeerUid` to the
measured listener peer, often 0 for systemd activation. This is distinct from
`dispatchTask.hostUid`, which names the application host. Path ownership and
0700/0600 checks remain controller-private. Before each actual private request,
`mini` checks both path custody and the connected endpoint peer, then rechecks
custody before writing any request bytes.

The controller passes `--operator-peer-uid` only to reserve/payer commands.
Reserve custody retains `operatorPeerUid`; seal, paid-plan and lookup workflows
restore it and refuse an explicit conflicting selection. Older custody without
the field retains its original same-UID interpretation. The public socket does
not inherit this peer selection, and the primary PrivateOperator remains
unchanged and owner-private.

Focused source tests cover exact forwarding, the six-operation allowlist, missing
Host pins, substituted config, malformed assembly frames, wrong incoming UID,
wrong connected endpoint UID with zero request bytes, retained pin drift,
private path replacement, permissions, symlinks and activation pathname mismatch.
Their Linux execution and the actual systemd peer-credential measurement belong
in the U3 native qualification receipt. This source description does not claim
that the full agent lifetime journey has passed.
