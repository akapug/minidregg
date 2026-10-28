# Route latency: state (lane/un-route-latency)

Red: a request through the grain route takes 6 to 15 s (TextEditor `POST /.sandstorm-login`
11 s alone, 18 s with a DDP websocket open; the app waits 10 s for the login rendezvous).

## Per-request Host call map (native/spk-host/src, tip b3c2b0578 + origin/main)

Dispatch is serial: `http_entrance.rs serve_dynamic_with_aux` runs one `deliver_request` at a
time (a reader thread parses; the dispatch loop dispatches). Per request,
`dispatch_delivery.rs deliver_once` -> `dispatch_native.rs author_and_submit`:

1. helper tool `author application-dispatch-request` (one-shot Host spawn, `tool_until`)
2. Host call `APPLICATION_DISPATCH_PLAN` via the operator socket (`invoke_until`, author_signed_ingress)
3. helper tool `inspect application-dispatch-plan`
4. helper tool `signatures`
5. Host call `APPLICATION_DISPATCH_ASSEMBLE` (invoke)
6. route-bound grains: helper tool `author application-route-bound-dispatch`
7. `submit_once`: Host call with the route-bound opcode (the chain write)
8. helper tool `inspect application-dispatch-committed`
Then `record_delivery_requested`, `prepare_cancellable`, the app call, `finish` (journal only).

## Timings (hbox, SandMD, e89fe7b8b + instrumented spk-host, one run, no other grain traffic)

Lines in the resident journal: `dispatch-timing`, `http-timing`, `author-timing`, `tool-timing`.
- queue 20 ms; preflight, fence, admit, allocate, record, project each < 25 ms
- helper tools 50 to 270 ms each (spawn is not the cost)
- app call 11 to 123 ms
- author_and_submit: GET 6.1 s and 11.6 s, POST 15.3 s, WebSocket open 13.0 s
- op1: author 424 ms (plan and assemble fast), submit 5.6 s; op2: author 5.2 s, submit 5.8 to 9.9 s;
  op3: author 5.5 to 5.8 s, submit 5.8 s. Each slow Host call is 5.2 to 6.0 s.
- Install of the 24 MB TextEditor package timed out twice (spk-ingest 132 s, 1.75 s CPU): load.

## Ruled out

Queue wait, journal fsyncs (allocate-operation 9 ms), helper spawn, the app, lock holders (a 0.3 s
`lslocks` sample during the slow calls showed none on the world's store), the SQLite 5 s busy timeout
as a visible lock wait.

## Not known / next

What the serving Host does in each 5 s call. Method (decided by the coordinator): on candidate
349e59ef1, SandMD world on hbox (`flock -o /tank/lanes/world-up.lock`), run the serving Host under
`strace -f -tt -T -e trace=%file,%desc,%process,fsync,fdatasync,futex,connect,sendmsg,recvmsg,poll,ppoll`
through a wrapper in the world's own bin, and split each call into exec/startup, Store open/read,
consent round trips, fsync, world-root derivation (long CPU with no syscalls), waits on another process.
Startup -> a resident Host for the dispatch path. Per-turn Store or world-root work -> a read-only
request through an enrolled route should not make 2 to 3 chain turns: a design change, written as one
paragraph for the coordinator and the statements auditor before any Lean.

## Wanted after the split

Head-of-line: a WebSocket open (13 s) blocks the next request because dispatch is serial.

## Hygiene notes

hbox umask is 0002: staged trees must be `chmod -R go-w` or world-up refuses ("companion custody
refused", "writable ancestor"); world-up needs a fresh run root; the world-up lock queue was 40 to 66 min.
