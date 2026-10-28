# Proposed shared native conversation binding

Runtime/effects coordination proposal, 2026-10-28. This is a grammar decision for
root/schema and app owners, not evidence that every codec is deployed.

The existing `http` and `ddp` bindings remain. A generic conversation uses:

```json
{
  "protocol": "conversation",
  "wire": "socket.io-eio4",
  "path": ["socket.io/"],
  "query": {"noteId": {"arg": "note"}},
  "steps": [
    {"emit": "getboard", "args": [{"arg": "board"}]},
    {"id": "snapshot", "receive": {"event": "broadcast", "where": [
      {"path": [0, "_children"], "exists": true}
    ]}}
  ],
  "result": {"result": ["snapshot", 0, "_children"]}
}
```

`wire` is an exact pinned codec, initially `json-v1`, `socket.io-eio3` or
`socket.io-eio4`. There is no version probing/fallback. A package that actually
uses SocketIO 0.9 needs its own explicit `socket.io-0.9` codec (including its
HTTP handshake); an EngineIO 3 implementation does not establish that codec.
Current `market-writes/rt-sio.py` probes EIO3 then EIO4; declarations replace
that probing with the packaged version established by source/client evidence.

Steps are a closed union:

* `{"emit": EVENT, "args": [EXPR...]}`: SocketIO event emission, encoded by
  the selected wire codec into one exact admitted text frame.
* `{"send": EXPR}`: JSON value serialized as one exact JSON WebSocket frame.
* `{"id": ID, "receive": {"event": EVENT?, "where": [CHECK...]}}`: wait for
  a matching payload. SocketIO payloads are the event's argument array; JSON
  payloads are the decoded whole message. `event` is required only for SocketIO.
* `{"receiveAll": [{"id": ID, "event": EVENT?, "where": [CHECK...]}...]}`:
  collect every named terminal in any order. A Jupyter execute requires both
  correlated `execute_reply` and `status` with `execution_state: idle`; one
  terminal is insufficient. All required conditions share one fixed deadline.
* `{"id": ID, "http": HTTP_BINDING}`: execute an ordinary declared HTTP
  binding while the same channel remains open. It uses the same native
  admission callback and exact receipt custody. This supports Groove Basin's
  server-issued WebSocket token authorizing an HTTP upload while that socket
  remains alive, without a per-app transport branch.

`CHECK` is `{"path":[KEY_OR_INDEX...],"equals":EXPR}` or
`{"path":[KEY_OR_INDEX...],"exists":true}`. Every check must hold; missing paths
fail the match. Capture IDs are unique and may be referenced only after their
step. A `receiveAll` captures each named payload separately. The existing
`arg/context/result/concat/path/sha256/cookie` expressions compose unchanged;
`{"jsonStringify":EXPR}` adds JSON-string data for protocols such as EtherDraw
whose event argument is a serialized stroke, rather than a nested object.

A bound is not a restartable timeout. Frame count, decoded bytes and absolute
channel deadline are fixed on open; all receive steps consume the same budget.
Unrelated messages count too. Ping/control frames return early; the SDK emits
any required pong as another freshly admitted exact send. A failed required
terminal after a mutating frame is uncertain; never reconnect/replay it.

All channels bind to the protected native attachment's member, grain, session,
generation and route (`api` signed prefix or hosted `web` origin). Model args
cannot choose any of those or an arbitrary socket/host. Close is attempted once
under fresh authority and channel custody also expires its fixed lifetime.

The native carrier is already agreed with effects:

```
CONVERSATION <fixed relative websocket path>?<declared query>
{"version":1,"op":"open|send|receive|rendezvous|close","channel":ID,...}
```

Every carrier request goes through the same native application admission and
private exact-preimage/completion path as HTTP. Replies preserve ordered exact
`frames:[STRING...]`, including intervening messages. SocketIO framing belongs
to the shared codec; app event names/conditions remain declaration data.

Wekan retains its narrower `ddp` binder. Its special `rendezvous` descriptor
admits the exact DDP login frame and matching HTTP token POST together, then
releases both concurrently on the same member WebSession. No authority round
trip may be inserted between those two physical sends.

A definitive send receipt describes delivery, not database persistence. Packages
without a sender acknowledgement need a separate declared readback to qualify
an app mutation; tools must state the scope of their returned result. No generic
engine may manufacture an acknowledgement or automatically rerun the mutation.
