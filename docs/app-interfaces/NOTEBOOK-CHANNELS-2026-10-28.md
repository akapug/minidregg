# Notebook 4.2.2 kernel channels

Package `57dedad4b0275606c24bdb13d995b218` contains the Python 2.7 Notebook
Contents and kernel handlers hashed in `data-package-sources.json`. A kernel is
started through POST `/api/kernels` with `{name:<kernelspec>}`, and stopped through
DELETE `/api/kernels/<id>`. Opening `/api/kernels/<id>/channels` creates the text-JSON
WebSocket used by the browser. This is separate from saving an `.ipynb` document.

The [Jupyter 5.0 execute protocol](https://github.com/jupyter/jupyter_client/blob/5.0.0/docs/messaging.rst#execute)
is the source contract for an exact request frame:

```json
{
  "header": {
    "msg_id": "<fresh operation ID>",
    "username": "member",
    "session": "<fresh operation ID>",
    "date": "<fresh UTC ISO-8601 timestamp>",
    "msg_type": "execute_request",
    "version": "5.0"
  },
  "parent_header": {},
  "metadata": {},
  "channel": "shell",
  "content": {
    "code": "<bounded code argument>",
    "silent": false,
    "store_history": true,
    "user_expressions": {"answer": "6 * 7"},
    "allow_stdin": false,
    "stop_on_error": true
  }
}
```

Every accepted output and terminal must have `parent_header.msg_id` equal to this
request's ID. Two independent terminals are required in either order:

1. `header.msg_type == "execute_reply"`, whose content has `status`,
   `execution_count` and `user_expressions` (or a kernel error).
2. `header.msg_type == "status"` and `content.execution_state == "idle"`.

A request cannot claim completed execution from an unrelated idle message, a send
receipt, or either terminal alone. Both receive conditions consume one fixed
channel deadline. Missing a terminal after dispatch is uncertain; code must not
be rerun automatically. `stream`, `execute_result`, `display_data` and `error`
frames are ordered outputs before the matching idle. Returning only the execute
reply can expose `user_expressions` results but does not expose every printed or
rich output; the shared conversation collector must preserve these frames for a
full cell-output tool.

The old recipe's helper stops at idle alone and is not a completion specification.
Its historical WebSocket close is an observed failure to investigate, not proof
that persistence or execution is intrinsically unsupported. The declaration now includes a separate kernel scenario with a real arithmetic
user-expression result; no execution acceptance is claimed until that scenario
passes through the native receiving path. File save/read alone remains insufficient.
