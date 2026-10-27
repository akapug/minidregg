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
one private tenant-pool root per grain, and keep fd 3 out of the adapter process.
The new launcher selects `--tenant-pool --max-resident 1 --max-tenants 128`;
old packaged v5 binaries are unchanged. The new bridge requires the tenant-aware
adapter and does not silently fall back to a shared workspace.

The app advertises title `Oracle7` and one permission:

| Field | Value |
| --- | --- |
| name | `query` |
| title | Ask questions |
| description | Use a session-isolated workspace on a bounded shared Oracle runtime |

Role zero is `Researcher`, verb phrase `can ask questions`, description
`Ask questions and inspect this appliance`, permissions `[true]`, default false.
A session requires exactly that one true permission. This check is application
attenuation, not proof of Mini admission. Package permission metadata must match.

Each source session has its own Oracle workspace and request journal. Mini's
host projects the source-inspected principal into `UserInfo.identityId`, and
projects `mini-session-v1\0` followed by application, subject and session-resource
IDs (three unsigned 64-bit big-endian integers) into Sandstorm's `tabId`.
The app requires a 32-byte principal that is not all zero and this exact 40-byte tab
shape with nonzero resource IDs. Missing or malformed bindings refuse session
creation before contacting Oracle. Display names and request fields are not
identity evidence.

The bridge sends exactly one private `X-Mini-Oracle-Tenant` header containing
64 lowercase hexadecimal characters: SHA-256 of `mini-oracle-tenant-v1\0`, the
32 principal bytes and the 40 tab bytes, in that order. No caller HTTP header is
forwarded. The adapter must reject duplicate or malformed tenant headers and
scope every conversation, request ID and replay record under this key. Same
source session and principal intentionally share state across Web/API sessions
and grain restarts; different source sessions isolate agents even when their
principal is the same. Grain generation, display name and permission-fingerprint
changes do not rename the tenant. A newly issued source session is a new tenant;
this is session isolation, not automatic cross-session user history sharing.

This header is trustworthy only on the private bridge-to-adapter loopback
connection inside the grain network namespace. It is not public authentication.
An operator with raw fd3 or adapter access can fabricate test identities. The
bounded warm-engine pool is independent of tenant count; this transport does not
itself prove that the Python engine confines tenant state.

The signed API path is `/`. Sandstorm operation paths are relative and map only
as follows:

| Sandstorm operation | Private HTTP request |
| --- | --- |
| `GET health` | `GET /health` |
| `GET capabilities` | `GET /capabilities` |
| `POST query` | `POST /query` |
| `GET operations` | `GET /operations` |
| `GET operations/<id>` | `GET /operations/<id>` |
| `POST invoke` | `POST /invoke` |

Only the operation listing accepts a query string: `q` (at most 256 decoded
UTF-8 bytes), `availability` (`live_direct`, `text_only`, `unavailable`),
`offset` (0–999999999), and `limit` (1–50). Fields cannot repeat. Operation IDs
match `[A-Za-z0-9][A-Za-z0-9._-]{0,159}`; detail requests have no query string.
Malformed percent escapes, controls and alternative routes are refused before
HTTP delivery. Valid request targets are forwarded without rewriting.

Query and invoke content must have MIME type `application/json`, empty content encoding,
and at most 64 KiB. The v5 launcher selects the matching adapter request limit.
The bridge forwards the exact JSON bytes, including the
adapter's `request_id`, `conversation_id` and `text`, without rewriting or
interpreting them; `/invoke` uses the adapter's structured operation envelope.
Accept permits JSON through `application/json`,
`application/*` or `*/*`, using the most specific matching range and its quality.
An explicit JSON exclusion overrides a wildcard; no acceptable JSON range
returns 406 before HTTP delivery. An absent Accept list permits JSON. Identity response encoding is used; an explicit exclusion receives 406. Request
cookies, additional headers and ETag preconditions remain
refused: the narrow API does not implement these semantics. HEAD is refused. Other WebSession methods use the schema's
unimplemented failure. The empty Sandstorm path serves a small HTML interface using these same JSON
operations; it never accepts a tenant selector. The signed class-L package starts
one warm engine within its 2-GiB budget. The operator can raise the pool size
together with the resource budget after measuring engine memory. Concurrent
work beyond the configured pool is refused with 429 rather than queued without
a bound.

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

With the tenant-aware Oracle adapter already listening on 127.0.0.1:7070, create a JSON
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

The narrow tests cover tenant identity and restart boundaries, the browser root, exact payloads, permission and route refusal, context and
request bounds, malformed/oversized responses, all current adapter error statuses,
a full 2 MiB response, deadlines, the global connection bound, and the actual fd 3
executable. These are component tests; a signed package, resident launch and
current Mini admission require separate integration evidence. No specialist
accuracy or theorem coverage claim follows from these transport tests.

For a reusable real-engine smoke, `scripts/oracle-transport-smoke.py` starts the
candidate's tenant-aware adapter with one resident worker, eight allowed tenant
workspaces, 120-second query and 180-second engine startup
bounds, invokes the probe, and terminates its recorded child processes. It
requires a new output directory outside the runtime. `--adapter /path/to/serve.py`
can select a new tenant-aware adapter without editing an older runtime; its
neighboring `tenant_pool.py` must be present and both hashes enter the report.
The direct HTTP replay uses the same synthetic principal/source-session key as
the fd3 probe, while health remains unscoped:


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
replies and the conflict. It also submits the same request/conversation IDs under
a second synthetic source-session tenant and verifies the first tenant's exact
replay survives the switch. This is a private operator probe, not evidence that
a public caller may select a tenant. A non-answer to the invalid unit can be an upstream
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

The publisher explicitly sets a newly created public-data registry to `0755`,
even under a restrictive umask. It does not change an existing registry or any
ancestor. Bubblewrap resolves its passed directory FD through the backing
pathname, so that ancestry must be searchable by the app. Before BEGIN, the
existing worker checks that exact pinned FD under its actual app UID/GID and
zero capabilities, resolves its pathname and confirms the same device/inode.
This catches mode and ACL access failures without widening private directories.
The bounded check accepts no caller-selected pathname and does not launch an app;
the later one-shot launch still requires the admitted claim. Filesystem, LSM or
I/O failures after this check can still leave a launch uncertain; there is no
automatic resend.

After the one-shot spawn succeeds, the app worker closes both its received app
descriptors and their temporary duplicates before becoming the reaper. The
reaper therefore cannot keep the app's RPC endpoint or output writers alive;
once the app and its descendants close them, EOF can arrive while the reaper
control channel remains open. This makes a
failed startup observable promptly; it does not authorize replay or turn an
uncertain RPC result into permission to launch again.

The final native HTTP serializer preserves the original-status header as well
as the RPC decoder. It accepts exactly one canonical three-digit value from
200 through 599; the Sandstorm response union still determines the HTTP status
line. Other app-supplied authority and framing headers remain refused. The
bridge regression checks full response bytes and this header through both
receiving layers, including 429 and server errors that lack exact union variants.
Multiplexed entrances also retain dispatch failure details in the operator log,
while clients receive the existing bounded error response.

Launcher ACL reads are bounded by Linux's 64 KiB extended-attribute value limit,
so provisioning more than 64 app identities does not exhaust an artificial ACL
entry cap. The existing named-user, group and mask checks remain unchanged;
oversized attributes still refuse explicitly. Existing launcher ACLs and old
Store records are not rewritten by this reader.
