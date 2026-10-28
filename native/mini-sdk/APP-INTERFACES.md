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
successful mutation response is uncertain too. App cookies live only for one execution's
preparations/request and its exact member/session; no global or cross-member jar exists.
`{"cookie":"name"}` resolves solely from this jar, never caller context.

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
`call` invokes the semantic controller tool and returns its native result. Lost calls retain
`request.json` and recover with `grain-runtime tool-result SOCKET REQUEST_ID`, never a fresh
call. Exact arguments and replies are stored in the new private attempt directory.

HTTP REST/DAV, form, multipart, strict UTF-8 text, JSON-lines, base64 and namespace-aware DAV
multistatus are supported. Unimplemented transports and validating schema keywords refuse
by name; listing a schema is not a claim of deployed receiving-path qualification.
