# Hosted app interfaces: one declaration for agent tools and qualification

Runs 1–2, `lane/cx-app-interface`, 2026-10-28. Approved design: **typed,
package-pinned adapter declarations projected into tools and interpreted by the
same native executor for calls and qualification** (option c). The product is
an agent working on the member's live app data while a human uses that same
grain in the browser. Qualification establishes that behavior; it is not the
product. The 36-app selection below remains the candidate suite, not a claim
of 36 completed integrations.

The Rust SDK now supplies declaration loading, schemas, HTTP/DAV encodings,
preparations, relation checks, bounded DDP state, generic conversations and
receipt-preserving execution. All 33 current declarations load in the native
executor, generate bound tools and match the Python canonical digest. This
checks the declaration/runtime contract, not live app acceptance. The shell calls
the controller's existing foreground tool interface. The derived Effects receiving
extension passes nine focused Rust receiving checks, including physical idle
socket expiry, and awaits integration. **Hermes attachment/catalogue wiring, the
composed real-agent turn,
and Lean validation of the receiving extension remain open.** A browser-route
PASS does not establish native agent admission or a real Hermes turn.

### Current product boundary

[`native/mini-sdk/APP-INTERFACES.md`](../native/mini-sdk/APP-INTERFACES.md) documents
`Declaration::execute` and `Declaration::qualify`. Both use one interpreter and
an injected native admission callback. The callback receives the exact prepared
request and protected `SessionBinding`; it returns the verified response and
native receipt. Every preparation, relation read and physical conversation send
uses current authority. The SDK encodes app data; it cannot grant access.

The controller attaches a declaration to an installed package and member session.
Its immutable alias selects the namespace `mini_app_<alias>_<operation>`; dots
in operation IDs become underscores. Aliases and resulting names must be unique.
Model arguments contain application data, never a host, member identity, package
selection or route credential. The shell pins `_miniInterfaceDigest`; the
controller compares it to the attachment and strips it before input validation.
The hidden foreground `mini_app_<alias>_qualify` entry point exercises the same
executor and is excluded from the resident's advertised tools.

**A stranger summons a Hermes resident into a shared house room. There is no
per-room resident allocation.** The room is a collaboration surface, not an
ambient grant to every participant's grains. Each attachment must remain bound
to its member, task, package, session and serving generation. Switching task or
member must not carry cookies, channel state or attachment authority forward.
The current room/task grants and the package's member permissions are separate
checks. The resident may act only through the admitted attachment available on
that turn; a room message naming another member's grain confers no authority.

The composed receiving row will ask the summoned resident to create a Gogs
repository and issue, store a Davros file containing the issue reference, then
read both back. An independent human browser session must display the issue and
file on those same grains. The evidence must join the real model tool trace,
package/declaration identities, native dispatch receipts and browser observation.
A negative turn must actually attempt an unauthorized attachment and receive a
named refusal; model reluctance is not a refusal row. L4c owns the Hermes
controller integration; this lane supplies the SDK and declarations.

### What the expanded suite establishes so far

The detailed source contracts and limitations are in
[knowledge interfaces](APP-INTERFACE-KNOWLEDGE-2026-10-28.md),
[data interfaces](app-interfaces/DATA-2026-10-28.md) and
[realtime interfaces](app-interfaces/REALTIME-2026-10-28.md).
They correct discovery assumptions without rewriting historical run evidence:

- Etherpad's packaged `/api` is disabled; declared text replacement uses its
  multipart import and reads plain export. EtherCalc operates on the human's
  same sheet, with full CSV replacement explicitly described.
- Datasette includes signed-package upload and write plugins. The declaration
  imports a database, writes records and queries them; it is not read-only.
- MediaWiki uses token preparations and revision checks; WordPress drafts use
  the package's Sandstorm role mapping, with application cookies omitted.
- OrgTodo uses its sync endpoint and content hash precondition. Prioritize uses
  a whole-state versioned replacement; duplicate task keys are refused before
  dispatch. These are explicit concurrency contracts, not implicit transactions.
- DokuWiki remote editing is disabled in this package; Permanote lacks a semantic
  note read endpoint; SandCal lacks a semantic CSRF endpoint. Export-only tools
  remain useful but cannot pass write qualification. YATA has a reviewed source
  repair awaiting a newly signed package. A root-only synthetic Mercurial bundle
  is not a general parent-aware commit interface.
- Notebook execution needs both correlated `execute_reply` and idle. Groove
  Basin's server token must stay attached to an open socket during HTTP file
  access. Hummingbird events are transient: readback must occur on the socket
  held across the tracking write. These requirements shape the shared native
  conversation interpreter rather than per-app scripts.

The old scripts are removed as their declared operations replace them. Python
remains a bounded protocol conformance harness, never a platform service. New
conversation features execute in the Rust interpreter; there is no second
Python conversation implementation. Qualification rejects empty/read-only
scenarios and unasserted writes. An asserted correlated event returned after a
compound write is valid readback for a transient protocol; reconnecting to read
an unrelated count would not be.

Run 2's hbox work uses candidate `b26630168b63024c9c46311745fa0b25fa09c13f`.
Etherpad, EtherCalc and FileDrop have passed live declared write/readback on
member browser routes; FileDrop includes exact binary content and listing. Wekan lifecycle passed, but authentication still fails before mutation:
payload-free physical-send timing shows the HTTP half arrives 11.56 seconds
after the DDP login, beyond the app's ten-second deadline; the app then answers
in about 18 ms. The compound native descriptor must admit both exact preimages
before releasing the login and HTTP sends. Increasing recipe timeouts cannot
repair this ordering. Earlier op26/op82 frame refusals did not reproduce on this
candidate and have not been attributed to Wekan.

Radicale passed lifecycle but its first calendar creation used `MKCALENDAR`,
which the current native HTTP method surface cannot carry. The corrected
declaration uses the package's supported extended `MKCOL` with an explicit calendar
resource type; it does not promise timezone support. Datasette performed upload,
insert and upsert, then failed output validation because the declaration expected
a bare query array instead of the packaged version's `{ok, rows, ...}` envelope.
The corrected projection passes focused fixtures; fresh live requalification
is pending for both apps. Neither original failure counts as typed qualification.
The batch stopped starting further phases when shared hbox Store processes
blocked in ZFS writeback. A subsequent data-world stop also exposed the old
op26 tag diagnostic; exact reply bytes were lost during teardown, so its
underlying outcome remains unknown. Source review shows that opcode may carry
a legitimate refusal or uncertain outcome instead of a fresh committed callback.
The corrected clients decode those outcomes through the pinned Host and retain
them, preserving the fresh-commit requirement and no-replay behavior. Enrollment
authoring now also distinguishes NO_RECORD (253) from an undecided outcome (255).
Two lifecycle and five enrollment checks pass, including the existing lost-submit
no-reinvoke check. The original lost reply's specific outcome remains unknown.

MediaWiki initially timed out during ingestion, before an API call. Its package
has 23,540 files and 1,691 directories; serial per-file durability barriers
amplified shared HDD latency. The materializer change retains a filesystem error
cursor before staging writes, flushes the sealed stage before atomic publication,
and persists the rename separately. The original package then passed an
**importer-only** check in 86 seconds under the unchanged 273-second cap. This
is not a MediaWiki lifecycle or agent-tool acceptance claim. The Linux durability
contract is documented by [syncfs(2)](https://man7.org/linux/man-pages/man2/sync.2.html).

The remaining sections preserve Run 1's design, curation and precisely scoped
historical evidence. Present implementation details above supersede statements
below that describe the initial three-app harness.

## 1. Curation and evidence

The [public index](https://app-index.sandstorm.io/apps/index.json), fetched again
on 2026-10-28, contains 98 entries; SHA-256
`b321865fa74ec921c0d53ad54e6fc02d66af32d051c074910e6fef32af350038`.
[`apps/interfaces/catalogue.json`](../apps/interfaces/catalogue.json) retains
all 36 selected entries, links and normalized-document hashes for each separately
fetched `/apps/<appId>.json` metadata document, license metadata, upstream source
links, package IDs, raw byte counts, bridge evidence,
protocol confidence and prior qualification evidence. Metadata is the publisher's
claim, not signature verification. Selection favors inspectable data, complementary
agent work and explicit protocols; age alone is not proof that a package is dead.

The table below is the candidate suite, **not 36 working integrations**. `cfg N`
means a root `sandstorm-http-bridge-config` of N bytes was inspected; the JSON
records its digest and source. Some configs are canonical empty configs (16
bytes). A config's presence does not prove its signature, permission mapping or
lifecycle; the installed package's verified identity and `spk-host` verdict do.
Nine packages were inspected directly in the interrupted run (SHA-256 prefix
checked, signature not independently reverified); the other config hashes come
from the 2026-10-27 scout's extracted bytes. No scout success claim is promoted
to a new live run here.

Profiles: **S** = `standard-v1` (256 MiB raw, 768 MiB decoded); **L** =
`market-large-v1` (512 MiB raw, 2 GiB decoded). These are import limits, not the
runtime S/M/L grain classes. Unknown decoded size still requires bounded ingest.
Wekan is 173.2 MiB raw / 846.9 MiB decoded and needs L. IPython is 177.9 / 636.7
MiB and fits S even though the old batch conservatively uses L. WordPress's batch
uses L; its decoded size has not been measured here. Others are S candidates.

Prior results below are scoped to [ROWS-OWED §0](ROWS-OWED.md#0-candidates-2d8b7ed54-76758dba6-e89fe7b8b-validator-run-2026-10-28-0600-0830z)
and the market handoff, not inferred from a `.tsv` entry. A batch name means a
recipe exists; it is not proof that it passed. The table names each candidate separately (76758dba6 or e89fe7b8b);
ROWS-OWED was reconciled from main at d41798c65. Current prototype results are recorded in §4.

| app / version / appId | category and agent work | data protocol / caveat | package / import / bridge | previous evidence |
|---|---|---|---|---|
| [Etherpad](https://app-index.sandstorm.io/apps/h37dm17aa89yrd8zuqpdn36p6zntumtv08fjpu8a8zrte7q1cn60.json) 1.8.18-1<br>`h37dm17aa89yrd8zuqpdn36p6zntumtv08fjpu8a8zrte7q1cn60` | documents: Compose and revise collaborative documents | HTTP API/socket.io; API credentials and package API exposure must be qualified | `aee0806c9547d1f53c1ccef38ac195ba`<br>61.0 MiB; S; cfg 896 B | Historical japps write PASS; 76758dba6 japps co-edit/lifecycle PASS |
| [EtherCalc](https://app-index.sandstorm.io/apps/a0n6hwm32zjsrzes8gnjg734dh6jwt7x83xdgytspe761pe2asw0.json) 2020.12.28.1+sandstorm1<br>`a0n6hwm32zjsrzes8gnjg734dh6jwt7x83xdgytspe761pe2asw0` | spreadsheets: Read ranges, compute and update tabular data | HTTP SocialCalc/CSV; Snapshot commands need revision discipline | `9b3b76152e7d8db9f54dba7455ea9239`<br>35.2 MiB; S; cfg 456 B | 76758dba6: lifecycle + write PASS |
| [HedgeDoc](https://app-index.sandstorm.io/apps/4uda6a9yfxk4v3x2mpxjdn2md9y54tj104091480qjr8h758u4dh.json) 1.9.8<br>`4uda6a9yfxk4v3x2mpxjdn2md9y54tj104091480qjr8h758u4dh` | notes: Edit markdown with collaborative revisions | socket.io OT + HTTP download; Broken HTTP body parser: missing iconv-lite/encodings; socket close in newest row | `ff642cdb65178a6a2dff96ca15dd7028`<br>69.5 MiB; S; cfg 16 B | 76758dba6 featured and e89fe7b8b RT: lifecycle PASS; socket.io close frame on write; recipes rt.tsv |
| [Permanote](https://app-index.sandstorm.io/apps/svwrpwnd3c380d1f99ge7g0qnjdq6y785c36s7qtqryxwkmn20qh.json) 0.1.4<br>`svwrpwnd3c380d1f99ge7g0qnjdq6y785c36s7qtqryxwkmn20qh` | notes: Store and retrieve markdown notebooks | HTTP file API; Old 2016 package; qualify paths | `4ecae843006080d7e5191c498a062fa1`<br>8.0 MiB; S; cfg 16 B | 76758dba6 B1: lifecycle + recipe write PASS; recipes b1.tsv |
| [DokuWiki](https://app-index.sandstorm.io/apps/nx3dqcmz2sjjz939vkg4847vvxrzqsatqfjrt3ea50z3jac5kv7h.json) 2020-07-29~2020-08-31<br>`nx3dqcmz2sjjz939vkg4847vvxrzqsatqfjrt3ea50z3jac5kv7h` | wiki: Write linked pages and inspect revisions | HTTP raw export/form save; optional XML-RPC; Form recipe proven; XML-RPC enablement unproven | `dda6d7e22e8e2566bdc804d8e3f9165f`<br>29.8 MiB; S; cfg 1160 B | 76758dba6: lifecycle + write PASS |
| [MediaWiki](https://app-index.sandstorm.io/apps/p04q48xd2kgkystkrda5n77kdns6u569wnactgh904tf7s3vev70.json) 1.37.4<br>`p04q48xd2kgkystkrda5n77kdns6u569wnactgh904tf7s3vev70` | wiki/search: Query pages, categories and edit with revision tokens | Action API HTTP JSON; Use 1.37.4 port, not the older duplicate | `16bcca05d59606b908681c07b202752a`<br>70.9 MiB; S; cfg 400 B | No live row recorded in ROWS-OWED section 0; recipes are not proof; recipes b8.tsv |
| [Wekan](https://app-index.sandstorm.io/apps/m86q05rdvj14yvn78ghaxynqz7u2svw6rnttptxx49g1785cdv1h.json) 12.65~2026-10-25<br>`m86q05rdvj14yvn78ghaxynqz7u2svw6rnttptxx49g1785cdv1h` | tasks/project management: Manage related boards, lists, swimlanes, cards and members | Meteor DDP + Sandstorm rendezvous; REST enablement not assumed; large decoded package; old recipe has wrong login | `2a2c05041cb4285da884d114e4820298`<br>173.2 MiB; L; cfg 2400 B | e89fe7b8b RT: lifecycle PASS; old DDP loginRefused (Unrecognized options for login request); recipes rt.tsv |
| [Yet Another TODO](https://app-index.sandstorm.io/apps/6ee9j59rp4mepat8pz2pt1sq97xmname4kvhzh4m3uzwrvf1hu10.json) 0.1.2<br>`6ee9j59rp4mepat8pz2pt1sq97xmname4kvhzh4m3uzwrvf1hu10` | tasks: Create and complete ordered tasks | HTTP form POST /todos/new; HTML read-back today; No JSON read API proven; needs packaged-source extraction or upstream data endpoint before a semantic adapter can qualify | `346bff4bc867afd54320af244dc64e9c`<br>10.8 MiB; S; cfg 16 B | e89fe7b8b B2: lifecycle + form write/read-back PASS (not a native adapter); recipes b2.tsv |
| [OrgTodo](https://app-index.sandstorm.io/apps/sfs5m16cjy4rxeqe3vfvqef4397szm5k6yxkmrj391u4sprpk6fh.json) 0.1.7<br>`sfs5m16cjy4rxeqe3vfvqef4397szm5k6yxkmrj391u4sprpk6fh` | project management: Edit structured Org projects and task dependencies | HTTP text JSON /tasks/:id, GET /tasks; Org payload; Old manifest >1 MiB refusal fixed by 16 MiB importer bound, rerun owed; POST /tasks uses missing DB columns; use sync upsert /tasks/:id | `727e6323ee98810826f91b15530e74f4`<br>54.1 MiB; S; cfg 16 B | e89fe7b8b B2/fixups: install timeout; not a typed-operation verdict; recipes b2.tsv |
| [Prioritize](https://app-index.sandstorm.io/apps/nut9xv0zcc4x92udcu9mwrp661xps9ecdtjaffnev34yn2ussvz0.json) 0.5<br>`nut9xv0zcc4x92udcu9mwrp661xps9ecdtjaffnev34yn2ussvz0` | planning: Schedule periodic tasks and list overdue work | HTTP application data (endpoint contract unqualified); Old 0.5 port; period/last-completed data model; inspect before choosing JSON or forms | `345bcc7b66577c64b514b56fd7731455`<br>12.4 MiB; S; cfg 16 B | No live row recorded in ROWS-OWED section 0; recipes are not proof |
| [Davros](https://app-index.sandstorm.io/apps/8aspz4sfjnp8u89000mh2v1xrdyx97ytn8hq71mdzv4p4d8n0n3h.json) 0.33.4<br>`8aspz4sfjnp8u89000mh2v1xrdyx97ytn8hq71mdzv4p4d8n0n3h` | files: Upload bytes, enumerate and move directories | WebDAV + HTTP API; Newest lifecycle passes, PUT read-back fails without detail | `15bf92664a1b14a784bf737e502e13b7`<br>60.2 MiB; S; cfg 424 B | 76758dba6: lifecycle PASS; write FAIL (see risk) |
| [FileDrop](https://app-index.sandstorm.io/apps/nn7axgy3y8kvd0m1mtk3cwca34t916p5d7m4j1j2e874nuz3t8y0.json) 1.0.6<br>`nn7axgy3y8kvd0m1mtk3cwca34t916p5d7m4j1j2e874nuz3t8y0` | files/inbox: Receive and enumerate uploaded artifacts | HTTP PUT/GET /file/<name>; JSON GET /file/; Raw binary API with signed write permission; no multipart needed | `d13f67230d0a4f9a63fc2c0bba87fc52`<br>4.2 MiB; S; cfg 512 B | No live row recorded in ROWS-OWED section 0; recipes are not proof; recipes b5.tsv |
| [Radicale](https://app-index.sandstorm.io/apps/8kr4rvyrggvzfvc160htzdt4u5rfvjc2dgdn27n5pt66mxa40m1h.json) 1.1.1+v14<br>`8kr4rvyrggvzfvc160htzdt4u5rfvjc2dgdn27n5pt66mxa40m1h` | calendar/contacts: Query and edit events and address books | CalDAV/CardDAV XML + iCalendar/vCard; Old 1.1.1 port; REPORT and member auth qualification owed | `4b137047cf1bdf5832397c3abc75efd6`<br>20.7 MiB; S; cfg 640 B | No live row recorded in ROWS-OWED section 0; recipes are not proof |
| [SandCal](https://app-index.sandstorm.io/apps/f5z8uwz7ynf89c286f9d5tse5dwjknv32nyd78qzsyema3zf9m8h.json) 0.9.3<br>`f5z8uwz7ynf89c286f9d5tse5dwjknv32nyd78qzsyema3zf9m8h` | calendar: Import events and export calendars | HTTP ICS import/export; No CalDAV endpoint: previous catalogue claim was wrong | `a84130b27030f06f981e78b06c499030`<br>15.6 MiB; S; cfg 584 B | e89fe7b8b B2: install refused: SPK staging remains after unit success; recipes b2.tsv |
| [Gogs](https://app-index.sandstorm.io/apps/d9ygf47xrtnw12j92cyt6cu8ut75esx01u4q3kcrn8415w9qzzgh.json) 0.11.34-fix1<br>`d9ygf47xrtnw12j92cyt6cu8ut75esx01u4q3kcrn8415w9qzzgh` | code/git: Create repositories, query issues, post comments, exchange commits | REST /api/v1 + git smart HTTP; 0.11.34 port; REST authentication must be qualified; old HTML row passed | `aede44cf19129337aae68b6993324574`<br>14.5 MiB; S; cfg 16 B | e89fe7b8b RT: lifecycle + HTML/form recipe write PASS; native REST row not implied; recipes rt.tsv |
| [Mercurial](https://app-index.sandstorm.io/apps/61gh7gnns305cknp20v2ekvdex48g4d3rv6wghuzk6huzx5qmp7h.json) 3.8.4<br>`61gh7gnns305cknp20v2ekvdex48g4d3rv6wghuzk6huzx5qmp7h` | code/versioning: Push source changes and inspect revision files | hg wire HTTP; Lifecycle and push/read-back pass on 76758dba6 | `5a34f1e1e3c9daff67ce2a04b1d96d26`<br>39.4 MiB; S; cfg 1184 B | 76758dba6: lifecycle + hg write/read-back PASS; recipes b8.tsv |
| [sntfy](https://app-index.sandstorm.io/apps/c6rk81r4qk6dm3k04x1kxmyccqewhh4npuxeyg1xrpfypn2ddy0h.json) v2.28.0-sandstorm-18<br>`c6rk81r4qk6dm3k04x1kxmyccqewhh4npuxeyg1xrpfypn2ddy0h` | notifications: Publish and poll job/event notifications | HTTP JSON + streaming; Newest lifecycle page GET fails; API role needs separate test | `bc424d5fd3cf60977cacdac328adfbee`<br>16.6 MiB; S; cfg 648 B | 76758dba6: lifecycle FAIL at page GET |
| [Rocket.Chat](https://app-index.sandstorm.io/apps/vfnwptfn02ty21w715snyyczw0nqxkv3jvawcah10c6z7hj1hnu0.json) 0.53.0-develop<br>`vfnwptfn02ty21w715snyyczw0nqxkv3jvawcah10c6z7hj1hnu0` | chat/messaging: Read channels, send messages and follow discussions | REST + Meteor DDP; Stale 0.53-dev port; auth and modern API assumptions need audit | `5198a2ec87bcc4b29e787b77079ba590`<br>71.9 MiB; S; cfg 280 B | No live row recorded in ROWS-OWED section 0; recipes are not proof |
| [Simple Chat](https://app-index.sandstorm.io/apps/yp9xt15y8s0rsuntnhgnr510qpcvm2tatd9mn1gzwr2au8h2n4p0.json) 0.6.1<br>`yp9xt15y8s0rsuntnhgnr510qpcvm2tatd9mn1gzwr2au8h2n4p0` | chat/messaging: Append messages and read a room log | Direct Capnp WebSession; text HTTP /chats and /topic; Small append-only conversation model; no modern channel/search API | `91ae6a99735aabe28fe283995b6f5173`<br>0.3 MiB; S; direct WebSession; no HTTP bridge | 76758dba6 B7: lifecycle + POST /chats, PUT /topic, text GET read-back PASS (d6243efa8 row report); recipes b7.tsv |
| [SandForms](https://app-index.sandstorm.io/apps/ztxnreej8a0pqn97ccfhuckswjkrmsaavn85n5sgzk30tv2k4y9h.json) 0.4.0<br>`ztxnreej8a0pqn97ccfhuckswjkrmsaavn85n5sgzk30tv2k4y9h` | forms/surveys: Declare questions, submit responses, query answers | Meteor DDP; Rendezvous login; write recipe exists, latest table queued | `f53e839658cba5d1783670890eeb8352`<br>23.8 MiB; S; cfg 152 B | e89fe7b8b B6: lifecycle + DDP recipe write PASS; recipes b6.tsv |
| [Datasette](https://app-index.sandstorm.io/apps/uawacvvx9f9ncex1sqj8njwpujf8s9fkmg7wmp55hg6xetrd45w0.json) 0.63<br>`uawacvvx9f9ncex1sqj8njwpujf8s9fkmg7wmp55hg6xetrd45w0` | SQL/data/search: Query SQLite tables and export result rows | HTTP SQL-to-JSON; 0.63 has no HTTP write API; recorded read is not typed-write acceptance | `547714ee1f01bae653fe9276d6d30ce9`<br>69.2 MiB; S; cfg 872 B | 76758dba6: lifecycle + recorded READ PASS; no write |
| [IPython Notebook](https://app-index.sandstorm.io/apps/rprqf3t2h3vd3swfkhwk076qrennh9msreyjv70g7sgw5hkdxjph.json) 4.2.2<br>`rprqf3t2h3vd3swfkhwk076qrennh9msreyjv70g7sgw5hkdxjph` | notebooks/compute: Create notebooks, execute cells and inspect outputs | Jupyter REST + kernel WebSocket; Large import; lifecycle passes, execution websocket closes | `57dedad4b0275606c24bdb13d995b218`<br>177.9 MiB; S; cfg 16 B | 76758dba6: lifecycle PASS; kernel WebSocket write FAIL; recipes b8.tsv |
| [Linksholder](https://app-index.sandstorm.io/apps/upcmp5j10r4x8j7kdfram8xx41ujvqjw0hq8ed2y72hky552znk0.json) 2017.03.10.0<br>`upcmp5j10r4x8j7kdfram8xx41ujvqjw0hq8ed2y72hky552znk0` | bookmarks: Maintain a structured bookmark catalogue | EtherCalc-derived HTTP data; Old port; confirm schema from package | `d11845a484a0a03767676c3c31c032e6`<br>15.1 MiB; S; cfg 456 B | No live row recorded in ROWS-OWED section 0; recipes are not proof |
| [Tiny Tiny RSS](https://app-index.sandstorm.io/apps/zj20q6pwy456cmq0k57n1mtqqtky664dfqnhsmf3t36khch5geph.json) 2021-12-31.2<br>`zj20q6pwy456cmq0k57n1mtqqtky664dfqnhsmf3t36khch5geph` | feeds/RSS: Query feeds, mark read and import subscriptions | HTTP JSON /api; External fetch needs powerbox/network grant; no ambient egress | `ac6dfded255f6ea86172fb62064772fc`<br>64.8 MiB; S; cfg 48 B | No live row recorded in ROWS-OWED section 0; recipes are not proof |
| [WBO](https://app-index.sandstorm.io/apps/rhtntjye2n7p71vrcq0ae4f6n9nr139fdk4n884tw55k40vy4uph.json) 1.20<br>`rhtntjye2n7p71vrcq0ae4f6n9nr139fdk4n884tw55k40vy4uph` | diagrams/whiteboard: Create shapes and inspect saved boards | socket.io events + HTTP board JSON; Lifecycle passed historically; write not proven in latest rows | `ac72e0d103d7f5c21e79dc74fc616b33`<br>32.0 MiB; S; cfg 16 B | e89fe7b8b RT: lifecycle PASS; recipe write FAIL without detail; recipes rt.tsv |
| [EtherDraw](https://app-index.sandstorm.io/apps/1gda5n8p8zsc0r9pcana2yjgtvsq169068k4ve8mk68z4x9fvzuh.json) 0.2<br>`1gda5n8p8zsc0r9pcana2yjgtvsq169068k4ve8mk68z4x9fvzuh` | diagrams: Draw structured strokes in shared rooms | socket.io; Old 0.2 package; recipe exists | `71ebb1517a10002e8f5a631009743235`<br>8.5 MiB; S; cfg 16 B | No live row recorded in ROWS-OWED section 0; recipes are not proof; recipes b3.tsv |
| [Scrumblr](https://app-index.sandstorm.io/apps/w544a46cjwtje73rfearjvszwa3nhjtxjanu5s83qkdutx6k0nz0.json) 0.5<br>`w544a46cjwtje73rfearjvszwa3nhjtxjanu5s83qkdutx6k0nz0` | kanban/whiteboard: Arrange sticky cards on a spatial board | socket.io + Redis; Old package; recipe exists | `cf6ae092f937e7000b875cbb97d17907`<br>6.3 MiB; S; cfg 16 B | No live row recorded in ROWS-OWED section 0; recipes are not proof; recipes b3.tsv |
| [Tube](https://app-index.sandstorm.io/apps/70xjeuj6t85v3s9a3up583q97wu044mnt8aekf3pqs41e3ct2v70.json) 1.1.13<br>`70xjeuj6t85v3s9a3up583q97wu044mnt8aekf3pqs41e3ct2v70` | media/video: Upload, index and retrieve video artifacts | HTTP multipart + media GET; Binary size bounds; streaming required beyond prototype limit | `cbba85a45618c184f304d90ccce303a9`<br>75.6 MiB; S; cfg 888 B | No live row recorded in ROWS-OWED section 0; recipes are not proof; recipes b5.tsv |
| [Groove Basin](https://app-index.sandstorm.io/apps/wfg1r0qra2ewyvns05r0rddqttt57qxurz3nz5z95rjnm63et7e0.json) 2016.06.25 (1.5.1+)<br>`wfg1r0qra2ewyvns05r0rddqttt57qxurz3nz5z95rjnm63et7e0` | media/audio: Upload audio and manage queues/playlists | HTTP + WebSocket JSON; Bundled media processes; recipe exists | `209d45cd3983bbab7ea52695c723fffe`<br>16.8 MiB; S; cfg 1312 B | No live row recorded in ROWS-OWED section 0; recipes are not proof; recipes b5.tsv |
| [Kiwix](https://app-index.sandstorm.io/apps/5uh349d0kky2zp5whrh2znahn27gwha876xze3864n0fu9e5220h.json) 0.1.0<br>`5uh349d0kky2zp5whrh2znahn27gwha876xze3864n0fu9e5220h` | knowledge/search: Import ZIM collections and query offline reference material | HTTP upload + search/read; No document-level write; acceptance must use archive import | `eace6915b227131cf0ed2b1a0db2e86b`<br>38.8 MiB; S; cfg 600 B | No live row recorded in ROWS-OWED section 0; recipes are not proof; recipes b5.tsv |
| [WordPress](https://app-index.sandstorm.io/apps/aax9j672p6z8n7nyupzvj2nmumeqd4upa0f7mgu8gprwmy53x04h.json) v2023.03.02 (4.9.8)<br>`aax9j672p6z8n7nyupzvj2nmumeqd4upa0f7mgu8gprwmy53x04h` | publishing: Draft posts, query taxonomies and publish content | HTTP REST /wp-json + form fallback; Packaged API/auth version must be audited; historical lifecycle only | `d6955e8f377ac431db17fd01855b3ce5`<br>44.7 MiB; L; cfg 1536 B | e89fe7b8b B4: lifecycle PASS; post-new.php 303, no REST nonce; recipes b4.tsv |
| [Hugo](https://app-index.sandstorm.io/apps/ksyud8q9h7rx9u001jn38216xe75a200avh7tg267wss6pq9zfkh.json) 0.104.2~2022-10-04<br>`ksyud8q9h7rx9u001jn38216xe75a200avh7tg267wss6pq9zfkh` | publishing: Write source pages and build a static knowledge site | HTTP file edit + publishing socket; Recipe exists; write not proven | `7df1f202df51679cc84ed85e03d6d6c7`<br>57.2 MiB; S; cfg 16 B | e89fe7b8b B4: lifecycle + recipe write PASS; recipes b4.tsv |
| [Hledger Web](https://app-index.sandstorm.io/apps/8x12h6p0x0nrzk73hfq6zh2jxtgyzzcty7qsatkg7jfg2mzw5n90.json) 1.31<br>`8x12h6p0x0nrzk73hfq6zh2jxtgyzzcty7qsatkg7jfg2mzw5n90` | finance/data: Post balanced journal transactions and query accounts | HTTP JSON PUT /add; Newest lifecycle passes; write lacks detail | `23321185cf7dd1ae7a74e5b7deb6caba`<br>18.5 MiB; S; cfg 1112 B | 76758dba6: lifecycle PASS; write FAIL (see risk) |
| [ExpenseOwl](https://app-index.sandstorm.io/apps/vfdve0w8ms2fh5te77evwh9nk1w1jj4thfsuspszzx9kaakrz5ch.json) 3.15<br>`vfdve0w8ms2fh5te77evwh9nk1w1jj4thfsuspszzx9kaakrz5ch` | finance: Record categorized expenses and query reports | HTTP JSON; Small Go model; historical lifecycle, write recipe | `07a8207b2d04738817b842953a84790e`<br>13.5 MiB; S; cfg 56 B | e89fe7b8b B2: lifecycle PASS; POST /expense 405; recipes b2.tsv |
| [Hummingbird](https://app-index.sandstorm.io/apps/4mfserfc04wtcevvgn0jw27hvwfntmt8j468y3ma55kj8d5tj9kh.json) 0.4.1<br>`4mfserfc04wtcevvgn0jw27hvwfntmt8j468y3ma55kj8d5tj9kh` | analytics: Record site visits and query audience metrics | HTTP tracking beacon + metrics endpoint (read endpoint unverified); Not an uptime monitor; read-back endpoint unverified; signed permissions tracker and view-data | `9365130605f1998f3d4aea205d8768ae`<br>78.7 MiB; S; cfg 768 B | e89fe7b8b B6: lifecycle page GET failed; allAccess owner role rerun owed; recipes b6.tsv |
| [Swagger Editor](https://app-index.sandstorm.io/apps/1d3umpx9ug1jv5stepvqfrucx3yr8n2a4gd7y5cud2vsq6mmj8uh.json) 2.10.4<br>`1d3umpx9ug1jv5stepvqfrucx3yr8n2a4gd7y5cud2vsq6mmj8uh` | API design: Edit OpenAPI documents as typed artifacts | HTTP PUT/GET /editor/spec; Recipe is server file write, not browser localStorage | `c6dbeddce8a6269990e832675cf8753d`<br>18.7 MiB; S; cfg 16 B | No live row recorded in ROWS-OWED section 0; recipes are not proof; recipes b3.tsv |

**Coverage and priorities.** First implement Gogs, Wekan and Davros, then
MediaWiki/DokuWiki, Radicale, FileDrop, EtherCalc, Etherpad, SandForms, ExpenseOwl,
Mercurial and Swagger Editor. These give code/issues, project relations, files,
knowledge, contacts/events, tabular data, collaborative text, forms and structured
records. Follow with notebooks, feeds, bookmarks, drawing, publishing and media.
Rocket.Chat, the HTTP-body-broken HedgeDoc, OrgTodo's broken add route and apps
without a structured read API belong in repair/discovery batches; never advertise
them as native tools on the strength of a recipe. The old package dates are
maintenance risks, not a claim that their upstream projects are dead.

**Explicit exclusions and gaps.** `diagrams.net`, package
`e7f8ac92c7823a4127601e95685ca4d2`, is refused as
`declares permissions without a signed bridge schema` (B3 and ROWS-OWED); its
runtime editor/viewer permissions cannot substitute for a signed config. Keep
WBO/EtherDraw as diagram candidates. A direct-capnp package such as Simple Chat
is a different case: it serves WebSession itself; absence of an HTTP bridge is
not evidence of unsigned permissions. Gitea is not in this index; select its
actual Gogs port rather than inventing a package. Prefer the 1.37.4 MediaWiki
entry to the two older duplicate entries. SandCal is not the contacts solution:
Radicale supplies CalDAV/CardDAV. Datasette covers SQL reads, not mutable SQL;
its eventual write row must import a database, or an upstream-supported write
extension must be separately packaged. Email (Roundcube) and Internet feeds need
an explicit egress/service capability; no adapter gets ambient network access.

## 2. Decision and architecture

| option | strengths | limitation against this task | decision |
|---|---|---|---|
| a. obend app modules | typed records/sums, compositions and activities; one Lean frontend, locked source and front-end identity | `perform` yields a declared Plan; it does not mean arbitrary HTTP or an authorized DDP socket. No hosted-grain conversation lowering exists today. Rewriting REST, XML and DDP in obend would confuse physical codecs with authority. | Target composition language after transport effects are derived; not pretend support now. |
| b. manifest → `mini_application_api` | reuses event21/lifetime API admission, exact request custody and settlement; enough for bounded Gogs HTTP | current parser exposes six HTTP methods, excludes DAV headers, and has no WebSocket/DDP channel. A manifest alone cannot widen that receiver. | Use this route where expressible; cannot honestly cover all three by itself. |
| c. typed declaration → tool schemas + bindings + row program | one package-versioned source owns names, types, relation checks, encodings and read-back; fits REST, DAV and DDP explicitly | needs a small closed binding vocabulary and a native interpreter; schema validation is not proof of app semantics or Mini authority | **Recommended.** This prototype tests the vocabulary; integrate its native receiving path as one replacement, not a parallel set of recipes. |

Relevant live code: `native/grain-runtime/src/mcp.rs` builds the tool catalogue;
`Runtime::application_tool_arguments` and `application_api_tools::parse_input`
handle bounded calls; `oracle_tools.rs` already maps semantic Oracle tools to
the same application request. The Oracle endpoint is unrelated to an SPK adapter:
do not wrap every app in an Oracle service. `docs/HERMES-TOOLS-2026-10-27.md`
describes the worker's confinement: no route token, host path or network socket
is to be mounted into Hermes. A model supplies operation arguments, not a URL,
member identity, capability, cookie, permission list or package version.

`world/activity/Tally.obend` demonstrates the real Plan/perform/resume shape;
`Compiler/ObjectiveBendFrontEnd.lean` is the one frontend. An obend workflow may
later compose `create issue → attach file → create linked card`, receiving
`completed | refused | uncertain` outcomes. It cannot assert that three different
apps commit atomically. No new `.obend` syntax or hand executor arm is invented
by this prototype.

### The declaration and session binding

`apps/interfaces/{gogs,wekan,davros}.json` contains:

* format + interface version, exact appId/packageId and human version;
* bounded input/output JSON Schemas, entity IDs, operation descriptions and write intent;
* closed HTTP or DDP bindings, authentication profile, bounded response decoding;
* visible-relation preconditions and bounded collection projections;
* qualification steps referring to the **same operation IDs**, with result references
  and assertions. They contain no HTTP endpoints or duplicate protocol scripts.

The source digest is SHA-256 over sorted compact JSON, including the qualification
program. This is the harness's version identity, not a Mini-signed declaration or
an RFC 8785 identity claim. Production must lock canonical declaration bytes and
the compiler/interpreter identity in a Lean-owned admitted interface descriptor.
An app upgrade invalidates the binding until its package version is requalified;
no matching by display name or automatic cross-version fallback.

Production route binding is `(world, app resource, package digest, interface digest,
member subject, session, serving generation)`. Discovery reads the installed
package identity from custody, not from model arguments. The row's `--package-id`
is an operator-supplied cross-check against lifecycle evidence, **not** that
production proof. Bind one tool namespace per grain; in a multi-grain catalogue
use a controller-selected short namespace or an application enum, never a model
supplied route. Schemas are descriptions; Lean's current-authority check and the
app's member authorization are enforced independently on every physical dispatch.
Past qualification or an admitted history entry cannot authorize a later call.

### What the Effects/kernel lane must supply

[Effects revival](EFFECTS-REVIVAL.md) currently states a guarded store-patch
engine. It is not already an external-I/O engine. A hosted call therefore needs
an admitted **intent and completion protocol**, not `sem` performing a network
side effect. Extend the engine's declaration vocabulary and derive codecs,
dispatch/verdict handling and receiver arms. Delete the hand twin for every
migrated code, following its `noTwin` obligation.

1. Bind the installed interface and exact ordinary-request preimage to the current
   member/session/generation and existing dispatch permit. Reads cost and require
   authority too. Include body identity and response bounds; keep permits out of
   the model. Existing bounded HTTP calls need no new effect merely for a new app.
2. Derive the missing DAV vocabulary all the way through the agent tool and receiver,
   reusing the existing browser WebSession DAV support and generated verb registry.
   Do not merely add `MOVE` to the MCP schema. `Destination`, `Depth`, `Overwrite`
   and ETag headers have method-specific meaning and same-grain constraints.
3. Add a bounded hosted conversation: open/upgrade, authenticated rendezvous,
   send, receive-to-condition, close. Bind frames, IDs, byte/count/time budgets
   and allowed protocol to the same subject/session/generation. Specify when a
   long-lived channel must recheck current authority, including before each write
   and after policy revision/revocation. Connection admission alone is insufficient.
4. Durable exact preimages precede physical sends. Separate app rejection, transport
   refusal and uncertain completion; never automatically replay an uncertain
   mutation. DDP IDs identify a method on a connection, not an exactly-once token
   across reconnections. Reconciliation reads must recover or report the original
   intent, not silently create a replacement operation.
5. For large files, use custody-owned content handles/digests and bounded streaming
   rather than pushing base64 through a model context. Prove the handle resolves to
   the admitted bytes. A file path is not an arbitrary local-host filename.

Required keystones: successful delivery corresponds to the admitted exact request;
no dispatch on missing/currently revoked authority; frame/subject/generation
isolation; uncertain sends never cause implicit duplicate sends. Exhibit inhabited
success and adversarial refusal poles before proofs. App response validation and
relation preflight are diagnostics, not proofs that an untrusted upstream app
honors its own database invariants. General proofs and deployed receiving-path
rows remain separate obligations.

## 3. The three prototypes

### Gogs: REST relations, queries and source bytes

The actual upstream port is 0.11.34-fix1, not modern Gitea. Nine declared operations:
`user.read`, `repo.create`, `repo.list`, `issue.create`, `issue.read`, `issue.list`,
`comment.create`, `comment.list`, `file.read`. Issue identity is
`(owner, repo, issue number)`, not a globally interchangeable integer. Comment
paths retain that parent. Listing carries page and, for issues, open/closed state. `all` is refused:
v0.11.34 silently treats every state other than `closed` as `open`.
File read selects a commit and a segmented relative path; binary results use base64.
The row creates a private initialized repository, an issue and comment, then reads
back both title and comment. JSON types and path/query encoding are validated
before dispatch; no CSRF scraping or form replay remains in Gogs's market row.

Upstream v0.11.34 `routes/api/v1/api.go` calls `reqToken`, but that function checks
`IsLogged`; `pkg/auth/auth.go` also supports reverse-proxy authentication. The
Sandstorm member route supplies identity. The live serial row confirmed this
against the pinned port without injecting `X-Sandstorm-*` headers: `user.read`
returned the routed owner, then the REST mutations succeeded. It remains the
qualification's authentication preflight. A 401 is `app-auth-required`,
not a fallback to HTML/passwords. The declaration does not invent a Gitea
contents-write endpoint absent from this package.

Git itself remains Git: bounded clone/fetch/ref inspection and commit/push need
a native git client over member-authorized smart HTTP. Integrate with the existing
Git transport pattern in the runtime; do not turn a pack stream into JSON fields
or bypass dispatch using SSH. Push has an uncertain-effect boundary and requires
ref read-back. REST issue/comment qualification does not claim a git push passed.

### Wekan: a real-time protocol with related collections

`board.create/read/status`, `list.create`, `swimlane.create`, `card.create/list` declare
board → list/swimlane → card relationships. `board.read` exposes typed members
(`userId`, `isActive`, `isAdmin`) as well as the related collections. `card.list`
filters the visible snapshot by board and list. Mutation preflight requires the
referenced list/swimlane to be visible under that board; the app must still enforce
invariants against races between the read and insert. Membership mutation is not
part of Run 1: Mini sharing and Wekan's internal roles are different authorities.
A later member-change declaration must not bypass either.

The original `rt-sio.py` Wekan branch sent `login({sandstorm:true})`;
main independently fixed that login while this run was in progress. This lane
replaces the entire per-app branch with the declaration and shared DDP state
machine; main's new helper still serves the not-yet-migrated TextEditor recipe. The package
instead uses `loginWithSandstorm(token)` **concurrently with** an HTTP POST to
`/.sandstorm-login`, content type `application/x-sandstorm-login-token`, with the
same fresh token. Waiting for the DDP result before posting deadlocks the rendezvous.
The POST carries the same member route cookie and the host supplies the identity.
The bounded retry is only the rendezvous POST when it beats DDP registration,
following the packaged client; no mutating method is retried. The app's own rendezvous deadline is ten
seconds: native conversation admission must account for that, rather than
spending the entire window admitting its HTTP half after sending the method. Returned `userId`
comes from the server, never the agent. The bundled server source was inspected
inside package `2a2c05041cb4285da884d114e4820298`; declaration source links pin
upstream context too.

DDP waits for both `result` and `updated`, in either order; responds to ping;
applies `added/changed/cleared/removed`; waits for publication `ready`, and refuses
`nosub` or oversized snapshots. Each operation has a fresh connection and login:
no projection is shared across members. The prototype takes a bounded snapshot,
not an immortal subscription. The package's `boardStatus` read reports lazy loading; the declaration refuses
`precondition-failed: board.status` rather than returning an empty list from a
lazy publication. Large/lazy boards need declared paginated card publications.
The preflight and subscription are separate reads: concurrent threshold changes
remain a consistency limitation, not a claim of an atomic database snapshot. A successful method result without `updated` is uncertain.
Wekan fits the declaration; it **does not fit today's agent API transport**.

### Davros: binary WebDAV and tree operations

Five operations cover MKCOL, PUT, GET, MOVE and PROPFIND depth 1, at the pinned
port's canonical `/dav/` path (the live run showed that a MOVE destination
using its legacy `/remote.php/webdav/` alias is refused as outside that base). The scenario creates a unique directory, uploads
bytes containing NUL and `0xff`, moves the file without overwriting another,
reads back exact bytes and checks that the directory listing contains the new
href. XML decoding is namespace-aware, checks per-property status, rejects
DTD/entity declarations and produces typed entries instead of handing XML to
Hermes. Relative paths reject traversal/aliases, CRLF and URI delimiters before
percent encoding. MOVE's destination is constrained to the same DAV tree.

Run 1 supports 16 KiB write bodies and 1 MiB replies, intentionally exercising
binary encoding without pretending to deliver large-file streaming. PUT is an
explicit replacement; production update operations should expose ETag/If-Match
preconditions. There is no multi-request transaction: if MOVE is uncertain, do
not rerun mkdir/put/move as a sequence. Read the original and destination paths
under fresh authority. The browser route already supports DAV; the agent path
still needs the derived extension above.

## 4. Executable surface and verification

Install the two pinned **test-harness** dependencies in a venv. No Lean build or
platform daemon is needed for these prototype rows:

```sh
python3 -m venv scratch/cx-app-interface/venv
scratch/cx-app-interface/venv/bin/pip install -r scripts/spk-platform/app-interface/requirements.txt
PY=scratch/cx-app-interface/venv/bin/python
$PY scripts/spk-platform/app-interface/row.py tools gogs
$PY scripts/spk-platform/app-interface/row.py tools wekan
$PY scripts/spk-platform/app-interface/row.py tools davros
$PY -m unittest discover -s scripts/spk-platform/app-interface -p test_binding.py
$PY scripts/spk-platform/app-interface/row.py qualify gogs \
  --route /ABS/MEMBER/ROUTE --package-id aede44cf19129337aae68b6993324574 \
  --out /ABS/NEW/RESULT-DIR
```

`call APP --operation OP --args JSON` takes the same route/package/out arguments
and invokes a single generated tool. `tools APP` emits the exact input schema,
object-wrapped output schema, operation ID, package ID and interface digest.
For example, `mini_wekan_card_create` takes board/list/swimlane IDs and title;
`mini_gogs_issue_list` takes owner/repo/state/page; `mini_davros_file_put` takes a
relative path and canonical base64. `["value"]` holds the typed output in MCP
`structuredContent`, also serialized as a text content block, following the
[MCP structured-result contract](https://modelcontextprotocol.io/specification/2025-06-18/server/tools#structured-content).
No checked-in generated tool list can drift: it is emitted from the declaration.
The normal restricted resident currently accepts only room tools and explicitly
granted Oracle calls (`restricted_application_call`); enabling app adapters
there requires an explicit room/tool grant and controller catalogue wiring,
not just adding names to `tools/list`.

`binding.py` validates declarations and arguments, rejects cyclic/mutating relation
preconditions, evaluates the closed binding vocabulary and projects MCP results.
`ddp.py` is the test transport state machine; `row.py` drives a custodian Unix
route with its member browser token. It does not grant identity, inspect the app's
database, invent permits, or install into the Hermes sandbox. Private run artifacts
include an exact request journal (without route cookies/login rendezvous secrets),
bounded HTTP response captures, typed responses and a result carrying package/interface identities. Those artifacts
are diagnostic evidence, not the production durable permit/completion journal.

The market's `write_Gogs`, `write_Wekan`, `write_Davros` and `write_DavrosTree`
now call that same declaration path through `market-writes/interface.sh`.
Their old protocol/form implementations are removed. Other apps retain their
old recipes until their declarations replace them; moving all of them without
qualification would hide failures. Set `APP_INTERFACE_PYTHON` to the venv Python
when running `featured-qualify.sh`. A missing dependency is a failed typed row,
never a fallback to the removed recipe.

**Offline:** 25 focused Python tests on the Mac, including full Gogs/Wekan/Davros
scenario execution against independent fake receivers, schema emission, query/path
encoding, binary round-trip, foreign-parent rejection, DDP result/updated order,
rendezvous ordering, snapshot changes/removals, bounded buffers, lazy-board refusal
and no automatic replay after loss. The Gogs 500 and Davros legacy-MOVE 403 fixtures are actual live recorded
responses; Wekan's frames and the small DAV XML fixture are constructed from the
package protocol, not mislabelled live captures. Shell syntax checks pass. No
Rust or Lean code changed, and no broad build/suite was run.

New regression checks were observed red before fixing: write-500 uncertainty;
binary read/write-bound confusion (including the declared base64 length);
MCP object result shape; incomplete DDP binding; malformed DDP errors and
unbounded unrelated results; lazy-board empty-result misreporting; Gogs's missing
README template; the unsupported `state=all` query; and Davros's legacy/canonical destination mismatch.

**Live hbox:** candidate `e89fe7b8ba8c477d1538ed6ee1f0e7aeac70c97f`, a fresh
`market-large-v1` world, store `864332d6da9caa3e`. Candidate binaries were reused,
with this lane's declarations/runner and current grain-journey/composed-inputs
scripts overlaid in a separate tree. Startup used `flock -o`; the box's already
allowlisted, byte-identical installer was used instead of widening sudo rules.
The initial setup attempt `dea495714cc81cd1` stopped at the installer allowlist;
its three named codec/consent residents were stopped using their PID files.

| run | observed result | scope |
|---|---|---|
| Gogs lifecycle | PASS: birth/install/share/start/enroll/page, 639 s on shared hbox | Real hosted package, browser member route |
| Gogs `user.read` | PASS, 200 JSON authenticated as `owner` | Confirms REST accepts routed Sandstorm identity without scraping or an extra API secret |
| Gogs first `repo.create` | UNCERTAIN, HTTP 500: `getRepoInitFile[]: Asset conf/readme not found` | Captured in `fixtures/gogs-repo-init-500.json`; no retry of this mutation |
| Gogs correction | Declared `readme: Default`; encoding regression green | First-world restart succeeded, then op82 enrollment-plan failed before reconciliation; the clean serial rerun below tests a distinct intent in a fresh world |
| Wekan lifecycle | Install claim refused: op26 answered with an unexpected 66-byte frame | DDP prototype not reached; this does not diagnose a Wekan protocol failure |
| Davros first run | MKCOL and PUT 201; MOVE 403, destination outside canonical `/dav/` base | Actual response retained in `fixtures/davros-legacy-move-403.json`; declaration now uses `/dav/` throughout |
| Hermes | NOT_RUN for all three | Tool schemas and scripted browser-route calls are not a live agent row |

The lifecycle/renewal refusals occurred while the Gogs renewal and table's next
app shared the test world. This run does not establish whether that concurrency,
the older candidate, or another host issue caused the reply-shape failures.
Don't label them package defects. No grant/check was weakened to make them pass.

**Serial rerun:** fresh store `7ad196bf297244ab`, same candidate and import profile,
new grain intents, all lifecycle and typed rows serial. Gogs lifecycle passed
(207 s) and its entire declared REST write/read-back scenario passed. Wekan
lifecycle also passed (783 s), including the install that previously refused.
Its typed row stopped with `auth-rendezvous-refused` / HTTP 500 on all four
bounded rendezvous POST attempts; no board mutation was dispatched. The
package deliberately returns only `Sandstorm login failed` from that endpoint;
its app log contains startup messages without a login cause. The ten-second
rendezvous deadline and admission timing are a hypothesis to instrument, not
an established diagnosis. Davros lifecycle passed (371 s), followed by its entire
declared binary/file scenario: MKCOL 201, PUT 201, MOVE 201, GET 200 with exact
binary equality, and PROPFIND 207 containing the moved file. This is a fresh test
world, not a retry of the first world's uncertain repository creation.

The serial run's package/declaration digests and row results are retained in
[`run-2026-10-28.json`](../apps/interfaces/run-2026-10-28.json).

Both installed worlds were torn down with `world-down.sh` (`removal_assertions=0`).
The remaining codec/consent residents were stopped by their verified exact PIDs;
no lane process or world registry remained. The lane staging directory was removed.
Detailed diagnostic outputs are preserved locally in
`scratch/cx-app-interface/live-evidence.tar.gz` (42 files; SHA-256
`3b8a257aca1a802bd2746fa41de07425c6988e35283f2f43c1837b23caf7477b`),
not committed as private transcripts or world state. Candidate directories and
shared caches were untouched.

**Batch for the parent:** carry the first-world op26/op82 evidence to the native
lifecycle receiver owner, with the successful serial Gogs/Wekan lifecycle
counterexample. Diagnose Wekan's rendezvous HTTP 500 with correlated admission/app
timing and rerun its declared scenario; do not restore the old login recipe.
The shared native work is the derived DAV/conversation interface
and explicit Hermes app-tool grant/catalogue. Run 1 has not supplied those kernel
effects or claimed any app is production-qualified. No private owner preference
is needed for these engineering decisions.

## 5. Fan-out after Run 1

Use about **five concurrent workers**, one app per work unit, with a protocol
owner available to fix shared obstructions. Plan seven or eight waves for this
36-candidate suite; don't count repair-only candidates as accepted apps. Workers
can overlap source inspection/implementation; world creation remains serialized
by `flock -o /tank/lanes/world-up.lock`. No cold per-worker builds or duplicated
closures. Reuse warm targets and candidate binaries under the lane rules.

Inputs per worker: exact index entry and metadata URL; verified SPK/package hash;
bridge config and role schema; import profile; source/tag or extracted versioned
routes; existing recipe and actual row outputs; this interface format and shared
protocol machinery; a named candidate and member/grain fixtures; the intended
agent task. A recipe is a lead, not a specification. A worker owns upstream
investigation when the API is absent; it must not silently scrape HTML to meet
the gate.

Output per worker: one versioned declaration with entity/parent identities,
query limits and cursor behavior, authentication and uncertain-write behavior;
scenarios for typed write/read-back and refusals; transport fixtures only where
needed; the deleted superseded recipe; curation/evidence updates. Add missing
protocol vocabulary once to the common engine, not app-specific executable arms.
An upstream package defect gets a named finding and a pinned repaired package
if feasible; it cannot be waved through as a qualified adapter.

Acceptance per app (all required to advertise a working native interface):

1. Signed intake with matching appId/packageId and signed bridge permissions,
   bounded import; create/install/start/enroll/open/share/stop/restart/export
   lifecycle, with renewed session authority after restart.
2. One typed mutation and independently observed read-back **through its
   declaration**, checking data, parent relations and exact binary bytes where
   relevant. Include filtered listing, empty result and pagination boundaries
   for query-rich apps. A Datasette versions read is not a write.
3. Same declaration through the **native agent receiver** under current authority;
   swapped package/session/member, foreign parent, expired/revoked capability,
   changed policy and reply loss must have named results. No automatic replay of
   uncertain writes, and no historical-grant bypass.
4. A real Hermes row with only generated semantic tools: the agent chooses the
   write and reads its result, and a separate observer confirms it in the app.
   Record declaration/package digests, tool trace and native receipts. A fake
   provider, schema listing or scripted call is not this row.
5. Delete the old executable recipe at acceptance; both qualification and Hermes
   use one declaration and one native binding implementation. Source checks,
   fixture tests, live browser rows and live agent rows are reported separately.

Recommended waves: (1) the three prototypes plus Radicale and MediaWiki;
(2) FileDrop, DokuWiki, EtherCalc, Etherpad, Swagger Editor;
(3) SandForms, ExpenseOwl, OrgTodo, Mercurial, Hledger;
(4) IPython, Datasette import, Kiwix, Linksholder, TT-RSS;
(5) WBO, EtherDraw, Scrumblr, Hugo, WordPress;
(6) Tube, Groove Basin, sntfy, Rocket.Chat, Simple Chat;
(7) Permanote, HedgeDoc, Prioritize, Yet Another TODO, Hummingbird;
(8) SandCal and any unresolved package repairs.
Don't wait for all waves to integrate a completed app; keep acceptance honest.

The next shared work unit is the derived native conversation/DAV receiving path,
not five workers each inventing their own Wekan socket tunnel. The Effects lane
owns the intent/authority/uncertainty contract; the native custody lane owns bounded
physical HTTP/WebSocket/file execution; app workers own package declarations.
