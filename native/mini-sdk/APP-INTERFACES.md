# Typed hosted application calls

`mini_sdk::app_interface::Declaration` loads the same pinned JSON used by qualification.
`tools()` emits semantic input/output schemas. `execute()` performs readonly preparation,
relation checks and the requested HTTP call. `qualify()` runs declaration scenarios through
that same executor. Neither decides Mini authority or bypasses native dispatch.

The controller obtains `SessionBinding` from its authenticated attachment. Each executor
callback receives that exact binding plus `PreparedCall` and must invoke the existing native
application API path under fresh current admission, including purse settlement. A
`NativeReply` contains the verified native response and exact receipt; `Execution.receipts`
retains every such receipt, including when later response interpretation fails. These are
private custody records: preparation responses can contain credentials. Model presentation
contains only the final typed value and sanitized receipt references.

`Refusal.uncertain` means the mutation may have happened. Never automatically replay it.
Callback transport errors retain their existing no-send/uncertain distinction. A malformed
successful mutation response is uncertain too. App cookies require `auth.appCookies: "retain"` (default: omit) and live only for one execution's
preparations/request and its exact member/session; no global or cross-member jar exists.
`{"cookie":"name"}` resolves solely from this jar, never caller context.
Path/default-path and Max-Age are enforced; ambiguous duplicate names refuse.
Domain attributes and Expires without Max-Age explicitly refuse as unsupported.
The custody-owned `__Host-mini_spk_session` cookie is never accepted from apps.

DDP emits exact `CONVERSATION` descriptors through that same admission callback,
including one jointly admitted login-frame/HTTP rendezvous. It requires trusted
controller context `operationId`, `nowMs` and fresh cryptographic `rendezvousSeed`
(32-byte lowercase hex). The app's login result alone supplies `userId`.
Result and updated are both required; no reconnect/replay recovers a mutation.
Declared `credential-resume` auth reads its credential endpoint through the same
private admitted callback and sends `login([{resume: token}])` on that channel.
The token and credential reply never enter the final typed result. One absolute
`limits.seconds` deadline covers all DDP calls, including auth and cleanup.

The shell uses the controller's existing foreground tool IPC, preserving its same admission,
attachment checks, exact request custody and recovery ID:

```
mini app-interface --action tools --declaration apps/interfaces/gogs.json
mini app-interface --action call --declaration /abs/gogs.json \
  --attachment my_gogs --operation issue.create --tool mini_app_my_gogs_issue_create \
  --args /abs/arguments.json --runtime /abs/grain-runtime \
  --controller-socket /abs/controller.sock --dir /abs/new-attempt
```

The controller must already have that package-pinned attachment and generated tool installed.
A declaration or socket pathname confers no grant. `prepare` is an offline encoding diagnostic;
`call` invokes the semantic controller tool and returns its native result.
It sends `_miniInterfaceDigest`, which the controller must verify against the
attachment and strip before argument validation. `qualify` invokes the hidden
`mini_app_<alias>_qualify` tool with `{context: ARGS, _miniInterfaceDigest: DIGEST}`;
this runs the same native executor. Qualification refuses before dispatch unless
the scenario declares a write followed by a read with a nonempty assertion.
Only explicitly bounded readonly readiness steps can retry declared transient
statuses or failed readback assertions. Lost calls retain
`request.json` and recover with `grain-runtime tool-result SOCKET REQUEST_ID`, never a fresh
call. Exact arguments and replies are stored in the new private attempt directory.

HTTP REST/DAV, form, multipart, strict UTF-8 text, JSON-lines, base64 and namespace-aware DAV
multistatus are supported. Unimplemented transports and validating schema keywords refuse
by name; listing a schema is not a claim of deployed receiving-path qualification.
