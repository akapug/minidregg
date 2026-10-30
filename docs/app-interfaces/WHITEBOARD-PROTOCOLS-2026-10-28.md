# Source contracts for native whiteboard conversations

These are package-source contracts for the common conversation grammar, not
live/native qualification claims. No per-app executable protocol branch is
introduced. WBO, EtherDraw, Scrumblr and HedgeDoc need the exact Socket.IO codec,
ordered typed sends/receives, fixed bounds and current authority on every send.

| Package | Bundled Socket.IO / Engine.IO | Planned wire |
|---|---|---|
| WBO `ac72e0d103d7f5c21e79dc74fc616b33` | 4.7.2 / 6.5.3 | `socket.io-eio4` |
| EtherDraw `71ebb1517a10002e8f5a631009743235` | 1.0.6 / 1.3.1 | `socket.io-eio3` |
| Scrumblr `cf6ae092f937e7000b875cbb97d17907` | 1.4.8 / 1.6.11 | `socket.io-eio3` |
| HedgeDoc `ff642cdb65178a6a2dff96ca15dd7028` | 2.5.0 / 3.6.1 | `socket.io-eio3` |

Versions above were extracted from each package's actual `socket.io/package.json`
and `engine.io/package.json`; bundled `engine.io-parser` exports protocol 3 for
the first three legacy packages and 4 for WBO. No dependency-version assumption
or version probing is used.
The transport vocabulary is the runtime owner's
`CONVERSATION-GRAMMAR-2026-10-28.md`: event args are arrays; each awaited event has
a capture ID and structural predicates; `result` references earlier captures.
`jsonStringify` covers EtherDraw's JSON-string event argument. Browser paths,
member identity and grain are protected attachment state, never model arguments.

## WBO

`opt/app/whitebophir/server/sockets.js` accepts `getboard(BOARD)`, awaits board
loading, joins that board, then emits `broadcast({_children: board.getAll()})`.
`boardData.getAll` returns an array, including an empty array. It has no cursor;
return a complete bounded snapshot or refuse oversized output.

A rectangle write sends `broadcast({board: BOARD, data: {tool:'Rectangle',
type:'rect',id:ID,color:COLOR,size:WIDTH,x:X,y:Y,x2:X2,y2:Y2}})`. The server calls
`saveHistory` then broadcasts to other clients; there is **no sender ack**.
A tool may report exact send delivery but cannot manufacture app acceptance.
A separate fresh `getboard` must observe the ID and geometry. IDs belong to the
board; an existing ID can be replaced, so do not call this create-only.

`boardData` saves after two seconds of inactivity or sixty seconds of continuing
activity. Disconnect also calls `unloadBoard`/`save`, but `save()` does not await
the returned mutex promise, and write errors are logged inside `_unsafe_save`.
GET `/download/BOARD` is a JSON object keyed by element ID, served directly from
the history file; missing/unreadable history returns an error. Memory readback
is distinct from saved-file/read-after-restart evidence. The prior run's saved
file failure is a real persistence question, not permission to relax the row.

## EtherDraw

`server.js` accepts `subscribe({room: ROOM})`. A loaded in-memory project emits
`loading:start`, `project:load({project: PAPER_JSON})`, `settings`, `loading:end`.
A new project invokes asynchronous `db.load`. Its implementation emits
`loading:end` immediately **and again from the database callback**; an absent
stored project never emits `project:load`. Thus a single `loading:end` is not a
reliable load-completion ack, and an empty board cannot be assumed to emit an
empty project snapshot. Named limitation: `etherdraw-empty-project-load-omitted`;
source-backed default read/write declarations must not conceal it with sleeps.

`draw:progress(ROOM, ARTIST, JSON_STRING)` and `draw:end` take pencil coordinates.
The server emits `draw:end` to the room before `draw.endExternalPath` and
`db.storeProject`. The database helper calls `db.set` without a completion
callback. A draw echo is neither database-write completion nor restart evidence.
Independent `project:load` readback may establish the in-memory stroke only.
A repaired package readiness/snapshot response is the clean replacement for the
old recipe's timing sleeps; that repair is not claimed here.

## Scrumblr

`server.js` accepts `message({action:'joinRoom',data:ROOM})`, then responds with
`message({action:'roomAccept',data:''})`. `message({action:'initializeMe'})`
reads Redis and sends `message({action:'initCards',data:CARDS})` plus independent
columns/theme messages. Await only the matching action; count other frames
against the same fixed channel budget. Empty cards is an empty array.

A card write sends `message({action:'createCard',data:{id,text,x,y,rot,colour}})`.
The server sanitizes fields, queues Redis persistence and broadcasts only to
roommates. No explicit sender ack exists. An exact send result needs a separate
fresh-client `initializeMe` readback. IDs belong to rooms; replacing an ID must
not be described as a globally unique create. The sanitizer may coerce numeric
fields, so do not claim exact numeric output types without observing them.

## HedgeDoc

Open the declared socket path with `noteId=NOTE`, receive `doc` containing current
`revision` and `str`, then emit `operation(REVISION, TEXT_OPERATION_JSON, null)`.
The OT server emits `ack`; the periodic dirty-note writer persists afterwards.
The old recipe builds insertion plus a positive retain of the old document;
that prepends text rather than replacing it. A replacement would require a
negative deletion count. It also relies on current revision; no blind replay or
revision-zero assumption is permitted. The native generic engine must not invent
arithmetic/text-length expressions merely in an app branch. Public tool input
can instead require a caller-provided revision and complete bounded OT operation,
with declared read preflight. Full Markdown replacement needs shared text/OT
vocabulary and conflict semantics. Existing HTTP body-parser defect remains as
recorded in the knowledge adapter document.

The new WBO qualification separately asserts fresh memory snapshot and saved
history JSON geometry, with bounded read-only observation of the package's
asynchronous save. A 500 can mean missing history but also a real save defect,
so it fails immediately rather than being retried as readiness.
It never retransmits the rectangle. Scrumblr similarly observes only fresh
read snapshots after its single card send. A read that remains empty or a saved
file that remains unavailable fails at the bound; neither means successful
persistence. EtherDraw's read-only declaration refuses write qualification.
Native fixture frames are source-derived, not recorded live captures.

The old WBO/EtherDraw/Scrumblr Python operation branches are removed with these
declarations. Existing batch rows name `native-conversation-receiver-not-attached`
for WBO/Scrumblr until the native receiving entrypoint is attached, and
`etherdraw-empty-project-readiness-defect` for EtherDraw. They do not dispatch a
parallel app interpreter or count read-only export as a write PASS. The remaining
shared legacy socket helpers are retained only for unmigrated callers.
