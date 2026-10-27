# Oracle appliance app bridge

`native/oracle-appliance` exports a Sandstorm `MainView` on an inherited Unix
socket at fd 3. Mini's existing `SupervisorConnection` opens a `WebSession` or
`ApiSession` through it. The app connects to one operator-selected
`127.0.0.1:PORT` Oracle adapter. It opens no listener and accepts no caller-selected
URL, workspace, executable or source path.

This is the application's endpoint, not Mini's controller. Mini still owns
current grants, exact request admission, dispatch records and uncertain-delivery
handling. Giving a raw client this socket bypasses those controls. The operator
probe below is for integration testing only.

## Runtime contract

Run `minidregg-oracle-appliance --port 7070` with the connected Sandstorm app
socket on fd 3. The resident/supervisor uses the server side of two-party RPC;
the app uses the client side and exports its main view as bootstrap. A launcher
must start the Oracle adapter separately in the same network namespace, using
one fixed workspace per grain, and keep fd 3 out of the adapter process.

The app advertises title `Oracle7` and one permission:

| Field | Value |
| --- | --- |
| name | `query` |
| title | Ask questions |
| description | Use this appliance's shared conversation workspace |

Role zero is `Researcher`, verb phrase `can ask questions`, description
`Ask questions and inspect this appliance`, permissions `[true]`, default false.
A session requires exactly that one true permission. This check is application
attenuation, not proof of Mini admission. Package permission metadata must match.

All members granted access to a grain share its Oracle conversation workspace.
The bridge does not pretend that display names, caller conversation IDs or the
synthetic identity used by the probe establish isolated user identities. Use
separate grains/workspaces for separate tenants.

The signed API path is `/`. Sandstorm operation paths are relative and map only
as follows; query suffixes and alternative spellings are refused:

| Sandstorm operation | Private HTTP request |
| --- | --- |
| `GET health` | `GET /health` |
| `GET capabilities` | `GET /capabilities` |
| `POST query` | `POST /query` |

Query content must have MIME type `application/json`, empty content encoding,
and at most 16 KiB. The bridge forwards the exact JSON bytes, including the
adapter's `request_id`, `conversation_id` and `text`, without rewriting or
interpreting them. Request cookies, additional headers, Accept/Accept-Encoding
lists and ETag preconditions are refused: the narrow API does not implement
these semantics. HEAD is refused. Other WebSession methods use the schema's
unimplemented failure. The app is an API, with no browser UI at its root.

Eight HTTP exchanges may be in flight per app process, shared across sessions.
Excess calls return `bridge_busy` before contacting the adapter. The adapter's
own query serialization remains in force. Each exchange has a 130-second total
deadline, including connect, send, headers, body and close. The library constructor
can select a shorter deadline for tests, with a maximum of 300 seconds.

Replies require a JSON content type and one Content-Length, with at most 16 KiB
of headers and 2 MiB of body. Chunked transfer, ambiguous lengths, incomplete
bodies and trailing bytes are rejected. The entire body is returned unchanged;
the bridge never truncates evidence. The private adapter must close its HTTP
connection after each response, as the current Python adapter does.

## Status and uncertainty

Sandstorm's pinned response union cannot express HTTP 429 or distinct server
failure codes. Every accepted reply includes the whitelisted
`x-sandstorm-app-http-status` header with the exact original status:

| HTTP status | Sandstorm result |
| --- | --- |
| 200 | content with JSON bytes |
| Representable 4xx, including 409 | matching client error with JSON non-HTML body |
| 429 and other unrepresentable 4xx | client error 400 with JSON non-HTML body |
| 5xx, including 502/503/504/507 | server error with JSON non-HTML body |
| Other success/redirect status | explicit RPC failure |

Consumers must inspect the original status header when distinguishing busy,
backend failure, timeout or storage-full responses. A projected error never
becomes a successful content response. This header and the unchanged error body
are verified through the actual `SupervisorConnection`/`dispatch_web` response
parser, not just by inspecting raw schema fields.

A transport failure or deadline returns an RPC error warning that delivery may
be uncertain. The app never retries. Recovery must use the same request ID and
identical bytes under the adapter's idempotency contract; a lost reply does not
prove that the request had no effect. Local input/busy refusals are explicitly
marked `state_may_have_changed: false` because they occur before HTTP dispatch.

## Build and integration probe

Build the bridge and operator example using the workspace Cargo manifest, in an
independent source snapshot and target directory as required by the repository:

```sh
cargo build --offline -p minidregg-oracle-appliance --bin minidregg-oracle-appliance --example query
cargo test --offline -p minidregg-oracle-appliance --all-targets
```

With the real Oracle adapter already listening on 127.0.0.1:7070, create a JSON
request file containing a fresh request ID and run:

```sh
/path/to/target/debug/examples/query \
  /path/to/target/debug/minidregg-oracle-appliance \
  7070 /path/to/request.json
```

The example launches the actual binary with a Unix socket pair at fd 3, opens an
API session through `SupervisorConnection`, and forwards the request. It prints
full response JSON to stdout and app metadata/original status to stderr. It exits
nonzero on adapter errors and terminates only its own bridge child. It is not a
Mini admission test or a public user interface.

Six narrow tests cover exact payloads, permission and route refusal, context and
request bounds, malformed/oversized responses, all current adapter error statuses,
a full 2 MiB response, deadlines, the global connection bound, and the actual fd 3
executable. These are component tests; a signed package, resident launch and
current Mini admission require separate integration evidence. No specialist
accuracy or theorem coverage claim follows from these transport tests.

For a reusable real-engine smoke, `scripts/oracle-transport-smoke.py` starts the
candidate's own adapter with 120-second query and 180-second engine startup
bounds, invokes the probe, and terminates its recorded child processes. It
requires a new output directory outside the runtime:

```sh
python3 scripts/oracle-transport-smoke.py \
  --runtime /path/to/candidate \
  --python /path/to/oracle-venv/bin/python \
  --bridge /path/to/target/debug/minidregg-oracle-appliance \
  --probe /path/to/target/debug/examples/query \
  --output /path/to/new-smoke-directory
```

It asks about Leaves of Grass, ISA temperature at 3,000 metres, an invalid
metres-per-second altitude, Emma and a pronoun follow-up. It compares complete
bridge bytes with direct HTTP replay, repeats through the bridge, checks changed
request bytes return 409, restarts the adapter and repeats all five retained
replies and the conflict. A non-answer to the invalid unit can be an upstream
`clarification` or `withheld`; the smoke records the actual status.

The report retains complete replies and hashes, binary hashes and cleanup results.
It compares runtime path metadata and hashes files up to 1 MiB before and after;
this inventory check does not re-attest the large deployment stores. The script
uses Python only as an operator test harness and does not implement platform
semantics. These five examples are transport/conversation checks, not specialist
panel scores or evidence that Mini admission ran.

## Custody across the resident user namespace

The resident maps only its operator and app identities into its user namespace.
Host-root files and files belonging to unrelated unmapped users can therefore
show the same overflow UID there; unmapped groups have the same ambiguity. That
number is never accepted as evidence of root ownership.

Before entering the namespace, the existing bootstrap opens protected custody
paths without following symlinks and checks their real host owners. It retains
handles and original UID/GID metadata for root/operator-owned entries under the
fixed world's `spk` namespace: finalized packages contribute their retained SPK,
manifest, import policy and image-root metadata; finalized public datasets
contribute their complete metadata trees. Executable image contents and archive
bytes are not parsed at this stage. Foreign/app ownership, writable ancestry and
symlinks are refused.

After entry, the signature verifier uses that retained root provenance for its
scratch ancestors. Public-data receipt checks recover the original UID and GID
only when a captured handle and the observed inode still agree on device, inode,
mode, link count, length, modification time and change time, with the handle's
current namespace-visible ownership also matching the observation. Unknown or
replaced inodes do not inherit trust. The signed archive and public inventory
checks still run normally; this does not add a new admission route.

Current operator cost: bootstrap scans finalized package metadata and public
catalogs for that world, not just the requested revision, because selecting the
package would otherwise require parsing resident inputs before isolation. The
capture is bounded to 131,072 paths/handles, 32 MiB of retained path bytes and
32 levels of public-data traversal; the process's descriptor limit may be lower.
Exceeding a bound refuses startup. It does not hash the large public payloads
again. Future narrower selection should use a trusted bootstrap input, not an
app-supplied host pathname.

Normal publication adds a new hash-addressed revision and leaves existing ones
unchanged. Renaming an already-held catalog administratively can change its
ctime; a later in-process custody recheck then refuses. Once IDs are unmapped,
treating that change as harmless would also hide an ownership change. The
already-mounted data remains pinned, and a fresh START can capture a restored
publication again. No collector or update operation removes old revisions.
