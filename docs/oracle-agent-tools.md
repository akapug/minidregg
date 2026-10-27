# Oracle operations for Mini agents

An agent can discover operations in an Oracle appliance and call one with the
inputs its live descriptor declares. The two tools are `mini_oracle_discover`
and `mini_oracle_call`. They use Mini's existing application lifetime API: every
request still needs current admission and purse settlement. A tool profile does
not create an application, session, grant, or permission.

## Enable an existing route

After provisioning and qualifying the appliance, bind the existing named
lifetime route in the agent controller's `toolTask` configuration:

```json
{
  "applicationServices": [
    {"application": "oracle-app", "protocol": "oracle-operations-v1"}
  ]
}
```

This is an addition to the controller's existing configuration, not a complete
configuration. `oracle-app` must already name an entry in
`allowedApplicationLifetimeRoutes`, with its established Host pin, registered or
locally born application, dispatch purse and private custody. Configuration
refuses unknown protocols, duplicate applications and profiles without a matching
lifetime route. At most sixteen profiles are accepted. The same operations
protocol can expose component-qualified Workbench or sibling operations when the
appliance actually supports them; each calculator needs no new Mini tool.

The MCP catalog exposes only the configured application names, never sockets,
resource IDs, custody keys or grant contents. Older configurations default to no
service profiles and do not advertise Oracle tools. Naming the profile does not
prove that the deployed package implements this protocol; discovery itself goes
through the live API and can fail visibly.

## Discover and call

Start with:

```json
{
  "application": "oracle-app",
  "query": "astronomy",
  "availability": "live_direct",
  "limit": 10
}
```

Call `mini_oracle_discover` with those arguments. The appliance returns its
operation descriptors, including input schemas, units, sources, examples and
availability, plus `next_offset` for further pages. Send that number as `offset`.
`limit` is 1–50; the default is 10. Search text is at most 256 UTF-8 bytes.
To retrieve one descriptor, supply only `application` and `operationId`.

Use the returned operation ID and its declared argument schema with
`mini_oracle_call`:

```json
{
  "application": "oracle-app",
  "requestId": "research-001",
  "conversationId": "research",
  "operationId": "specialist.astronomy-v3.answer",
  "arguments": {"text": "3 Mars years in Earth years, using 687 Earth days per Mars year and 365.25 Earth days per Earth year"}
}
```

This example is valid only if that operation appears as `live_direct` in the
selected runtime. Some underlying operations accept a text string; their
schema says so. Others can expose structured quantities. Mini does not invent a
calculator, rewrite its argument schema, or turn a text-only catalog declaration
into an executable operation. The live appliance decides unknown IDs, argument
validity and refusal. Discovery can include `text_only` and `unavailable` entries
when requested, so users can see their limitations without mistaking them for
callable operations.

Request and conversation IDs contain 1–80 ASCII letters, digits, `_` or `-`.
Operation IDs contain 1–160 ASCII letters, digits, `.`, `_` or `-`, starting with
a letter or digit. The encoded invocation body is limited to 65,536 bytes,
including IDs, field names, JSON escaping and operation arguments. The appliance
must also report a sufficient `limits.request_bytes`; the v5 packaging selects
65,536, while older standalone services default to 16,384. Calls cannot
select a host URL, filesystem path, HTTP header, arbitrary method, socket or grant
for transport; operation-specific inputs still follow the live input schema.
The controller constructs `GET operations`, `GET operations/ID`, or
`POST invoke` relative to the route's signed prefix. It percent-encodes search
text and serializes invocation JSON deterministically. The existing HTTP parser
and lifetime-dispatch code then consume those exact bytes.

Input limits apply at each layer:

- MCP accepts a complete JSON request line of at most 65,536 bytes, including
  its tool envelope and newline. Compact Oracle arguments avoid HTTP-body hex
  expansion, but must still leave room for that envelope. The generic
  `mini_application_api` tool carries a hex body, so its practical MCP body
  limit is below 32 KiB after envelope and other HTTP fields.
- The model-free foreground interface accepts a 262,144-byte request frame,
  and can carry the full 65,536-byte invocation body with its tool envelope.
- The controller's canonical HTTP-input object is capped at 196,608 bytes,
  allowing the hex-encoded 65,536-byte body plus bounded metadata. The actual
  serialized native forward frame remains capped at 262,144 bytes and is
  checked before socket I/O. Current grant and schema checks remain unchanged.

The controller wires these tools through both MCP and the existing model-free
foreground tool interface. Foreground calls retain the original tool name and
arguments in their request journal before using the same application dispatch.

## Replies and recovery

The tools retain the existing application API reply envelope. Its `bodyText`
contains the appliance's JSON when the bounded HTTP body is UTF-8; the native
response and its evidence remain in controller custody. Read the transport
outcome, HTTP status, and complete application reply. A completed operation may
refuse; completion does not establish an answer or a formal proof. Unknown
operations, invalid arguments, busy responses and runtime faults keep their
original application status and body rather than being converted into answers.

There are two request identities. The Mini foreground/controller operation
identifies an admitted delivery and settlement. The appliance `requestId`
identifies an invocation in that appliance's persistent journal. A lost or
uncertain Mini result requires exact inspection before any new dispatch; neither
Oracle tool automatically retries. When a later dispatch is justified, keeping
the appliance request ID and arguments unchanged permits its recorded response
to replay. Changing the invocation under an existing appliance ID conflicts.

## Verification scope

The scoped Rust tests exercise operator profile selection, MCP discovery,
path/query injection boundaries, input bounds, deterministic invocation bytes,
and composition with Mini's existing HTTP parser and lifetime dispatch encoder.
They do not establish an actual Lean admission, a running appliance, restart
recovery, or new specialist-panel scores. The receiving journey must exercise
these tools with the newly packaged operations service before claiming that
agent-facing deployment is qualified.

```sh
cargo test -p minidregg-grain-runtime --bin grain-runtime oracle_ -j 2
```

The 27 October source checks passed on macOS: seven `oracle_` tests, twenty `application_api_tools::tests`, ten
`mcp::tests` (including the Oracle catalog test), and three `journal_io::tests`.
The journal's private subprocess helper is intentionally ignored as a standalone
test and is invoked by its process-death test. The full grain-runtime test binary
compiled; no full test suite was run. A pre-existing macOS type mismatch in
`journal_io.rs` was repaired by a checked conversion of `stat.st_dev` to `u64`
before comparing the held file's device identity; negative values refuse.
No theorem statements changed and no specialist panels were run.
