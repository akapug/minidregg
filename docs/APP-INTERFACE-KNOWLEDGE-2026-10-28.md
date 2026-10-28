# Wiki, document and calendar interfaces

These package-pinned declarations are unqualified prototypes. They describe tools
for the same live grain a human browses. Source inspection, synthetic protocol
fixtures, live browser-route calls, native admission and real Hermes use are
separate evidence; none substitutes for the others.

## First batch

| Declaration | Typed scope | Remaining limitation |
|---|---|---|
| `mediawiki.json`, 1.37.4, `16bcca05d59606b908681c07b202752a` | Create only, read wikitext/revision, update with `baserevid`; internal member/token preparation | Requires session cookie retention; app errors must fail output validation; no automatic mutation replay |
| `etherpad.json`, 1.8.18-1, `aee0806c9547d1f53c1ccef38ac195ba` | Plain-text import and export by grain/pad identity | Full replacement can overwrite concurrent changes; no OT/revision claim, no formatting preservation |
| `ethercalc.json`, 2020.12.28.1+sandstorm1, `9b3b76152e7d8db9f54dba7455ea9239` | Replace named sheet with CSV; read CSV or typed display-value rows | No revision precondition; strings are computed CSV display values, not formula ASTs; complete bounded export, no pagination |
| `radicale.json`, 1.1.1+v14, `4b137047cf1bdf5832397c3abc75efd6` | Create calendar; create/update restricted UTC event; GET iCalendar; bounded VEVENT listing with ETags | Restricted ASCII summaries; no recurrence, timezone, occurrence expansion, date-window query or general iCalendar codec |
| `dokuwiki.json`, 2020-07-29~2020-08-31, `dda6d7e22e8e2566bdc804d8e3f9165f` | Raw page export by namespace-qualified ID | Default package disables remote interfaces; typed write is not advertised |

MediaWiki titles and revisions belong to a particular grain. `createonly` refuses
existing pages; `nocreate` plus `baserevid` prevents accidentally creating or
replacing a changed page. The CSRF token never belongs in public tool arguments;
internal read preparation obtains it after member identity initialization.
Output schemas require edit `Success`; an HTTP 200 API error is not success.

Etherpad's packaged `APIHandler.js` explicitly disables `/api`. Its import route
accepts a multipart `.txt` file, calls `pad.setText`, and responds with numeric
`code=0`; export provides independently observed text. The declaration therefore
uses the package's supported import/export surface, not guessed API credentials.

EtherCalc's packaged `dist/app.js` implements PUT `/_/:room` gated by signed
`modify` permission; it stores the snapshot, clears the operation log and emits
the new snapshot to connected clients, then returns 201. GET `/_/:room/csv.json`
exports CSV and parses it to string rows. The qualification checks cell values,
so harmless CSV quoting/line-ending normalization is not mistaken for data loss.

Radicale's packaged nginx maps signed `owner` permission to literal backend
principal `owner`; the agent cannot choose another principal. Calendar/event
identities include their parent calendar. PUT checks `If-None-Match: *` for
creation and `If-Match` for update. Event listing supplies the ETag for the exact
resource; a changed resource refuses the old ETag. The restricted writer emits
one UTC VEVENT and rejects summary characters requiring iCalendar escaping or
folding. This narrow writer does not replace a full calendar library.

## Named unsupported behavior

`radicale-calendar-time-range-filter-ignored`: package `xmlutils.report` only
applies component-name filters and explicitly leaves other/nested filters TODO.
A requested date window would silently return unrelated events. The declaration
exposes `event.list` without time-window arguments, never a misleading filtered
query. A future date query needs a repaired package or a generic parsed iCalendar
query projection with defined recurrence semantics.

`dokuwiki-remote-interface-disabled-by-package-default`: packaged
`conf.orig/dokuwiki.php` sets `remote=0` and `remoteuser='!!not set!!'`.
Neither packaged `local.php` nor `local.protected.php` enables it. The old recipe
extracts an HTML form token and hidden fields; it is not a semantic API adapter.
The read-only declaration makes no write claim. This is a package configuration
limitation, not evidence that DokuWiki crashes or can never support XML-RPC.
A manager may change configuration; that needs separately observed configuration
and XML-RPC qualification. Existing recipes remain until a qualified replacement
can remove them in the same commit.

## Source evidence

The signed package SHA-256 prefixes were checked before decoding. This inspection
does not independently verify publisher signatures; live intake supplies that
verdict. Relevant bytes were extracted from each exact package, rather than
assuming current upstream branches describe old ports. Full extracted sources
remain private scratch; these hashes identify the inspected files:

| Package/file | SHA-256 |
|---|---|
| MediaWiki `includes/api/ApiEditPage.php` | `50193fd590e4d2b43041c6a5a260a313a77558d9186f8062e11675fe62ca1ac1` |
| MediaWiki `includes/api/ApiParse.php` | `3b947055bb86dfbb540124887be14a874d69f6ea0803c2ae8faf52790e09ef9c` |
| DokuWiki `conf.orig/dokuwiki.php` | `037d9c8de7e05f956a16ae90206c1f318f346bd6ecec199825244d6f11282ec9` |
| Radicale `radicale/xmlutils.py` | `9a602646776316cd047ba0de264d97c4d2c954d889d26bd52f79d89b8ceccf0d` |
| EtherCalc `opt/app/dist/app.js` | `cb756d13098bf95e4cdeb8bb347d56fc75d373268c6c15772b711f43b6da9cd7` |
| Etherpad `src/node/handler/ImportHandler.js` | `811eb215259f9ab0168dc337d74e23d3bad6997b116cf197e3686967dbf85e58` |

## Receiving evidence

Three synthetic tests passed on the Mac after the shared registry/composition
commit `a628507fd` replaced the initial `interface-unknown` refusals. They exercise the declaration itself against independent protocol receivers,
including stale MediaWiki revision refusal, response-bound token escaping,
Etherpad multipart bytes and EtherCalc sheet identity. This is not live evidence.
An isolated hbox world is starting with candidate `b26630168b63024c9c46311745fa0b25fa09c13f`
under the shared creation lock. Live browser route, native agent receiver and
Hermes results remain NOT_RUN until recorded explicitly here.

## Second batch source findings

`hugo.json` declares source-file replacement/readback and explicit `site.publish`.
The package's `/commit` route mutates despite using GET: it commits the entire
working tree and runs the publishing build. The declaration labels it a write.
Source qualification does not automatically publish and does not assert public
site bytes; a public-origin observer remains a separate receiving row.
Pinned `opt/app/server.js` SHA-256:
`c92c9e6887428b5b983da6d5443e40aaa9e00078781fb46506859039b53c6328`.

`wordpress.json` declares explicit initialization, routed member identity, and
draft post create/edit/readback. Package 4.9.8 has no modern `rest-nonce` AJAX
action. The old recipe's HTML `wpApiSettings` extraction is not reused.
The package's Sandstorm `auto_login` authenticates from signed routed identity
and maps its current permissions only when no WordPress user is already logged
in. Core `rest_cookie_check_errors` accepts an authenticated noncookie method
without a REST nonce; valid app auth cookies instead require a nonce. Therefore
this declaration requires route-only cookies (`auth.appCookies=omit`) on every
request. This is a source-backed hypothesis awaiting live qualification, not a
claim of successful REST auth. It also avoids a retained app cookie skipping
current signed role mapping. Post IDs belong to the grain; edits have no atomic
revision precondition in this declaration and may overwrite concurrent edits.

`sandcal.json` exports iCalendar only. Version 0.9.3 is upstream tag commit
`c449c3261bde9c9f0b1361b5ffa0ba3812af69c9`; `LibMain.hs` checks editor permission
and a member/route-bound HMAC before every mutation. `View.Import` and UI
renderers expose that MAC through rendered UI; no semantic token endpoint is
present in the route algebra. Named blocker: `sandcal-semantic-csrf-endpoint-absent`.
The old recipe guesses POST `/import`; tagged source actually uses `/import.ics`.
No HTML token extraction or invented CalDAV endpoint is added.

`hedgedoc.json` exposes persisted Markdown downloads only. Named package defect:
`hedgedoc-iconv-encodings-absent`. In exact package
`ff642cdb65178a6a2dff96ca15dd7028`, all bundled iconv-lite copies contain library
files but no `encodings` subtree. `iconv-lite/lib/index.js` line 65 calls
`require('../encodings')` when decoding HTTP bodies. This independently supports
the prior live missing-module finding. Socket OT avoids HTTP body parsing, but
prior close-frame evidence is not a diagnosis that OT cannot work. A bounded
socket.io/OT binding, persisted readback and actual native admission are still
outstanding for that alternative; no unsupported-global-write claim is made.

Permanote 0.1.4 has no declaration claiming note integration. Exact packaged
`opt/app/views.py` renders notes, edit forms, archives, tag lists and search as
HTML. Its sole JSON data response is an image-upload filename; `app.py` only
allows jpg/jpeg/png/gif/webp attachments. Substituting image upload for notebook
editing would miss the intended task. Named blocker:
`permanote-semantic-note-read-endpoint-absent`. A repaired package exposing
structured note reads is required before note write/readback can qualify under
the no-scraping contract. Source SHA-256 for `views.py`:
`644c01b90e77ee5f9f15ffe78f08d258924085a43419937efd485c210350714c`;
`app.py`: `9c1bf130700b72dcdaaeb0b4aed7e2ae936e79d3d318a8e6b9cf829ce159f7d7`.

Six focused wiki/document/site/calendar fixtures pass on the Mac after shared
contract `c84d4f305`. The calendar fixture tests ETag refusal without retry and
checks that ignored time filters are absent from the declaration. All
second-batch live browser/native/Hermes rows remain NOT_RUN.
