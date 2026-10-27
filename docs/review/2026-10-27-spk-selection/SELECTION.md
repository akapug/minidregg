# The SPK selection: what the demo installs beyond Etherpad

2026-10-27, from the live index (`https://app-index.sandstorm.io/apps/index.json`, 98 apps, fetched today).
52 packages (every candidate under ~70 MB) were downloaded and read structurally — the SPK's signed
`Archive` was parsed with our own pinned `package.capnp` schemas (`native/spk-rpc/schema/`), never
installed; runtime, storage and the launch command come from the package's own manifest, file tree and
`sandstorm-http-bridge-config`. The rest are judged from index metadata and upstream source. Scores
**H/E/D/B** = agent-hackability / ease-of-extension / demo-value-for-a-stranger / bridge-safety,
each 1–5, 5 best; B=5 means it should run on today's bridge.

## The structural finding that sets the scores

~40 of the 52 inspected packages — including all three qualified apps — run the bundled
`sandstorm-http-bridge` executable as the grain's root process: it spawns the app's inner command
(`launcher.sh`, php-fpm, nginx, node…) on a loopback port and itself *serves* `UiView`/`WebSession`
over fd 3 to our supervisor, *using* our `SandstormApi`, `SessionContext` (cast to
`HackSessionContext.getPublicId`), identity save and `AppHooks` — exactly the surfaces
`native/spk-rpc/src/protocol.rs` (on `lane/app-market`) already serves. So "does it use the bridge
pattern" is not a differentiator: Hacker Slides already proves the binary. The real per-app risk is
(a) the WebSession **verbs** our `dispatch_web_input.rs::call_for` will forward (today
GET/HEAD/POST/PUT/PATCH/DELETE + WebSocket — **not** PROPFIND/REPORT/MKCOL/MOVE/COPY/LOCK), (b)
**streaming bodies** (fail closed in `spk-rpc/src/protocol.rs`), and (c) inner daemons
(nginx/php-fpm/mongod/mysql/redis) — processes, which the sandbox runs fine (Simple Todos already
runs a bundled mongod). No inspected app sets `bridgeConfig.apiPath`; Etherpad is the only
`saveIdentityCaps`, TT-RSS the only `expectAppHooks` — both served.

## The full index, scored

| app | appId | ver | MB | last | runtime / storage | beneath-HTML surface | H/E/D/B | note |
|---|---|---|---|---|---|---|---|---|
| HedgeDoc | 4uda6a | 1.9.8 | 70 | 2023-08 | node; sqlite (sequelize) | full REST /api; markdown | 5/4/4/4 | RECOMMENDED |
| Davros | 8aspz4 | 0.33.4 | 60 | 2026-10 | node; files + sqlite meta | WebDAV (PROPFIND…) + /api | 5/5/4/3 | RECOMMENDED; needs DAV verbs |
| Hledger Web | 8x12h6 | 1.31 | 18 | 2023-10 | static Haskell; journal file (plain text) | JSON API + CSV | 4/3/3/5 | RECOMMENDED |
| EtherCalc | a0n6hw | 2020.12.28 | 35 | 2026-10 | node socialcalc; in-memory + snapshots | REST + websocket JSON | 5/4/5/4 | RECOMMENDED; shipped 2026-10-09 |
| sntfy | c6rk81 | v2.28.0-sa | 17 | 2026-09 | go ntfy; files/cache | POST /topic = notify; JSON | 5/4/4/5 | RECOMMENDED; shipped 2026-09-11 |
| Gogs | d9ygf4 | 0.11.34-fi | 14 | 2018-03 | go; sqlite + git repos | git smart-HTTP + REST /api/v1 | 5/4/4/3 | RECOMMENDED; streams needed |
| SandCal | f5z8uw | 0.9.3 | 16 | 2022-11 | go static; sqlite (/var/sandcal.db) | JSON API + CalDAV | 4/4/3/4 | RECOMMENDED |
| Wekan | m86q05 | 12.65~2026 | 173 | 2026-10 | meteor; mongo (bundled) | REST + DDP | 4/2/5/3 | RECOMMENDED; L-class flagship |
| DokuWiki | nx3dqc | 2020-07-29 | 30 | 2020-09 | php-fpm+nginx; flat .txt pages | do=export_raw GET; POST edit | 4/4/5/4 | RECOMMENDED |
| WBO | rhtntj | 1.20 | 32 | 2023-10 | node; board JSON events | websocket JSON + REST | 4/3/5/4 | RECOMMENDED |
| Datasette | uawacv | 0.63 | 69 | 2022-10 | python3.9; sqlite files | SQL→JSON over HTTP | 5/5/4/4 | RECOMMENDED |
| Simple Todos | 0dp7n6 | 2015-10-30 | 23 | 2015-10 | meteor/node; mongo (bundled) | meteor DDP; no clean HTTP API | 2/2/3/5 | QUALIFIED today |
| Hacker Slides | 7qvcjh | 0.4.0 | 16 | 2016-04 | node; slides.md markdown | slides.md GET/PUT | 4/4/4/5 | QUALIFIED today |
| Roundcube | 0qhha1 | 1.1.2-3 | 95 | 2016-10 | php + IMAP; mysql/imap | none — needs external mail | 1/1/3/1 | egress-free demo cannot fetch mail |
| Swagger Editor | 1d3ump | 2.10.4 | 19 | 2016-10 | static SPA; browser localStorage | OpenAPI spec JSON files | 3/2/4/5 | pure static; spec hand-editable |
| EtherDraw | 1gda5n | 0.2 | 9 | 2016-09 | node; socket.io memory | drawing JSON over socket.io | 3/3/4/4 | WBO covers the niche fresher |
| Apache Wave | 2m8rty | v0.4 | 84 | 2015-08 | java; own store | dead protocol | 1/1/2/1 | dead upstream |
| Laverna | 4dgxs5 | 0.6.3-git | 2 | 2016-08 | node; markdown+json files | note JSON API | 3/3/3/4 | older markdown notes |
| Hummingbird | 4mfser | 0.4.1 | 79 | 2026-02 | node; files/sqlite | Hive check scripts + REST | 5/4/3/3 | mnutt's monitor; strong second wave |
| Telescope Nova | 5h13ka | 0.26.4 | 36 | 2016-07 | meteor; mongo | DDP | 2/1/3/3 | dead 2016 |
| Kiwix | 5uh349 | 0.1.0 | 39 | 2019-11 | static+server; ZIM files | read-only ZIM | 1/3/4/4 | wow factor, no writes |
| ShareLaTeX | 5vuv7v | 2020.08.31 | 174 | 2020-09 | node; mongo+redis | LaTeX API | 3/3/3/2 | 174 MB, stale port |
| Mercurial | 61gh7g | 3.8.4 | 39 | 2016-07 | python hgweb; hg repo files | hg web + JSON | 4/3/3/3 | git via Gogs covers VCS |
| Yet Another TODO | 6ee9j5 | 0.1.2 | 11 | 2020-07 | node; JSON files | REST | 4/3/2/5 | zenhack; small good |
| GitWeb | 6va4cj | 0.0.10 | 13 | 2020-01 | nginx+perl; git repos | git web | 3/2/3/3 | composted on lane/app-market |
| MediaGoblin | 70awyq | 0.7.1 | 114 | 2015-08 | python; own store | REST-ish | 2/2/3/2 | dead 2015 port |
| Tube | 70xjeu | 1.1.13 | 76 | 2022-10 | go; files | JSON API | 3/3/3/4 | video; heavy media |
| Meteor Blocks | 7kszn2 | 1.0.2 | 38 | 2018-05 | meteor; mongo | DDP | 1/1/2/3 | toy |
| Acronymy | 7m2fcf | 2015.10.31 | 3 | 2015-11 | C++ capnp direct; text files | direct WebSession | 2/2/2/5 | dwrensha; direct-capnp path |
| Baby Buddy | 7yu31z | 1.11.0 | 124 | 2022-05 | django; sqlite | Django admin/REST | 3/2/3/3 | 124 MB for a niche tracker |
| Legends Browser | 8cqz32 | 0.1.5 | 42 | 2017-10 | static+server; files | game saves | 2/2/2/3 | niche |
| Radicale | 8kr4rv | 1.1.1+v14 | 21 | 2016-08 | python; .ics/.vcf files | CalDAV/CardDAV only | 4/3/2/2 | pure DAV verbs — blocked today |
| XRF Billing | 9a9pwx | 0.0.7 | 42 | 2025-03 | php-fpm+nginx; sql | web UI | 2/2/2/4 | fresh 2025 but billing niche |
| SandMD | 9afdqy | 0.2.0 | 29 | 2018-12 | node; markdown docs | markdown GET/PUT | 3/3/3/4 | commodity editor |
| WordPress | aax9j6 | v2023.03.0 | 45 | 2023-04 | php-fpm; sqlite (pdo_sqlite) | full WP REST /wp-json | 4/3/5/4 | near-miss: 4.9.8 port, 2023 |
| Game of Y | ap9cdc | 0 | 11 | 2015-08 | C++ capnp direct; board state | direct WebSession | 1/1/3/5 | two-player door |
| Annotate | c6zfft | 1.3.1 | 23 | 2016-04 | meteor; mongo (bundled mongod) | DDP | 2/2/3/3 | image annotation |
| Biandang | c70m9m | 2017.09.05 | 12 | 2017-09 | php; ethercalc-fork store | ethercalc API | 2/2/2/4 | PDIS lunch orders; niche |
| OwnTracks | cjv3p2 | 0.0.5 | 6 | 2017-01 | node; JSON files | location recorder REST | 3/3/2/4 | niche |
| dieStorm | cnrwn4 | 1.0.0 | 24 | 2017-09 | node | websockets | 1/1/2/3 | game |
| Angr Binary Reverse-Engineering | cxp85a | 4.2.2 | 205 | 2016-11 | python; files | REPL | 3/1/1/2 | 205 MB; specialist |
| Idea Otter | du1nkm | 1.5.0 | 20 | 2016-07 | node; mongo? | web UI | 1/1/2/3 | dead |
| Desert Atlas | e5eaqn | 0.1.0 | 96 | 2023-12 | ?; files | web UI | 1/1/2/2 | niche game |
| BrowserQuest | fj5ehf | 2015.10.31 | 19 | 2015-11 | node | websocket JSON | 2/1/3/3 | dead MMO demo; fun door |
| Dillinger | fq057t | 3.2.0-sand | 18 | 2015-11 | node; markdown files | markdown import/export | 2/2/3/4 | commodity editor |
| Etherpad | h37dm1 | 1.8.18-1 | 61 | 2023-12 | node; dirty-db file + revisions | HTTP /api + socket.io | 5/4/5/5 | QUALIFIED; the opening app |
| Hugo | ksyud8 | 0.104.2~20 | 57 | 2022-10 | go + helper; markdown in, static out | file writes | 4/4/4/4 | near-miss: static site gen |
| Badgepack | kzyafw | 0.0.2 | 21 | 2026-08 | python3.11 flask; files/sqlite | web UI | 3/3/2/4 | fresh 2026-08; badge niche |
| CrypTag | mkq3a9 | 0.8.2 | 4 | 2016-07 | go; encrypted tags | CLI-ish web | 2/1/1/3 | niche crypto |
| Ghost | mkqyz7 | 0.5.8 | 37 | 2015-08 | node; sqlite | Ghost API | 3/3/3/3 | 0.5.8 port, 2015 |
| Simple Rich Text Editor | n0y5gf | 0.2.0 | 27 | 2016-10 | node; doc store | web UI | 1/2/2/4 | commodity |
| TextEditor | n4n49d | 0.0.5 | 23 | 2016-03 | node; files | plain text files | 3/3/2/4 | commodity |
| CodiMD | n6ceuu | 2.3.3 | 182 | 2021-04 | node; postgres | REST | 3/3/3/2 | superseded by HedgeDoc |
| diagrams.net | nfqhx8 | 20.5.2 | 64 | 2022-11 | static server; drawio XML | XML diagram files | 4/3/5/4 | near-miss: agent-drawable XML |
| FileDrop | nn7axg | 1.0.6 | 4 | 2016-06 | go static; files /var/files | upload/download POST/GET | 4/3/3/5 | near-miss; tiny clean files |
| Hacker CMS | nqmcqs | 2015-06-29 | 9 | 2015-08 | ruby jekyll); markdown in, static out | file writes | 3/3/3/4 | Hugo covers it |
| Prioritize | nut9xv | 0.5 | 12 | 2022-10 | static binary; JSON files | REST | 4/3/2/5 | zenhack; small good |
| MediaWiki | p04q48 | 1.37.4 | 71 | 2022-08 | php; wiki db (bundled) | Action API (JSON) | 4/2/4/3 | two stale ports (2016/2022) |
| SandChat | q95sez | 0.1.0 | 21 | 2016-10 | C++?; chat log | websockets | 1/1/2/3 | dead |
| Let's Chat | qkgkax | 0.4.2 | 19 | 2015-08 | node; mongo | REST | 2/2/3/2 | dead 2015 |
| Go | r75g5c | 0.2.0 | 15 | 2015-09 | node; board state | websockets | 1/1/3/4 | game door |
| Perplexity Sudoku | r8y55a | 0.0.1 | 20 | 2025-10 | python3.11; JSON state | solver API? | 2/1/4/5 | fresh 2025-10-26; game door |
| Hacker Resume | rnyps5 | 0 | 30 | 2016-10 | node static; HTML files | file writes | 2/2/2/4 | static builder |
| XRF Books | rp7kx4 | 0.0.8 | 56 | 2026-08 | php-fpm+nginx; ebook files | calibre-ish web | 3/2/3/4 | fresh 2026-08; ebook niche |
| IPython Notebook | rprqf3 | 4.2.2 | 178 | 2016-08 | python; .ipynb files | Jupyter REST | 4/3/3/2 | 178 MB; heavy but agent-gold |
| Sandpass | rq41p1 | 1.1.0 | 13 | 2019-07 | go; keepass .kdb | kdb file ops | 2/2/2/5 | passwords; wrong demo fit |
| Framadate | s244pu | 0.8 | 18 | 2015-09 | php; mysql | web UI | 2/1/3/2 | needs mysql; dead |
| Collections | s3u2xg | 1.2.0 | 2 | 2017-01 | static capnp; in-app DB | powerbox sharing | 2/3/2/2 | powerbox-heavy; second wave |
| Contact Otter | sd6d1q | 0.0.4 | 24 | 2016-03 | node; mongo? | web UI | 2/2/2/3 | dead |
| OrgTodo | sfs5m1 | 0.1.7 | 54 | 2026-08 | node; org-mode text | org files | 4/3/3/4 | fresh 2026-08; near-miss |
| Brainstorm | sptx6z | 1.0.2 | 14 | 2015-08 | node; idea list | web UI | 2/2/2/4 | dead |
| Permanote | svwrpw | 0.1.4 | 8 | 2016-02 | python; markdown files | file GET/PUT | 3/3/2/5 | small python notes |
| Giftr | tr3w5p | 1.0.2 | 22 | 2016-09 | meteor; mongo | web UI | 1/1/2/3 | dead |
| XRF Sync | txfm99 | 1.0.21 | 49 | 2026-08 | php-fpm+nginx; device sync store | web UI | 2/2/2/4 | fresh but device-bound |
| 2048 | u0yh8x | 0.0.2 | 26 | 2022-02 | php-fpm; JSON state | page JSON | 2/1/4/4 | fun door; trivial data |
| Neuron Catalog | u1pa41 | 0.6.1 | 25 | 2016-05 | meteor; mongo | DDP | 2/2/2/3 | lab niche |
| Linksholder | upcmp5 | 2017.03.10 | 15 | 2017-03 | php; ethercalc-fork store | ethercalc API | 2/2/2/4 | PDIS; niche |
| Sum | uw6vkw | 1.0.0 | 26 | 2022-11 | php-fpm+nginx; history | web form | 2/2/2/4 | calculator; unclear |
| Firefly III | uws252 | 4.7.9 | 42 | 2018-12 | php; sqlite/mysql | REST API | 3/3/3/3 | finance; 2018 port |
| ExpenseOwl | vfdve0 | 3.15 | 13 | 2025-03 | go static; JSON file | REST | 4/4/2/5 | near-miss; dead-simple ledger |
| Rocket.Chat | vfnwpt | 0.53.0-dev | 72 | 2017-02 | meteor; mongo | REST + realtime | 3/2/4/3 | 0.53-dev, 2017; helm covers chat |
| Paperwork | vxe8aw | 2017.09.01 | 28 | 2017-09 | php laravel; mysql | web UI | 2/2/3/2 | needs mysql |
| Scrumblr | w544a4 | 0.5 | 6 | 2017-01 | node + redis); sticky JSON | websocket JSON | 3/3/4/3 | near-miss; redis bundled |
| Sandstorm Error Collector | wa8sgz | 1.1 | 28 | 2025-05 | node; files | JSON ingest | 2/2/1/4 | internal devtools |
| Groove Basin | wfg1r0 | 2016.06.25 | 17 | 2016-06 | node; music files + db | REST + websocket (mpd-ish) | 4/3/3/4 | music; media-heavy |
| Quick Survey | wupmzq | 2.3.1 | 29 | 2016-11 | meteor; mongo | DDP | 2/1/2/3 | dead |
| Monica | xrm87u | v3.0.1 | 66 | 2021-05 | php laravel; mysql | REST | 3/2/3/2 | needs mysql |
| Piwik Web Analytics | xuajus | 2.15.0-san | 85 | 2016-09 | php; mysql | REST/report API | 2/2/3/2 | needs mysql; 2016 |
| MediaWiki | y88wav | 1.25.2-1 | 32 | 2016-11 | php; wiki db (bundled) | Action API (JSON) | 4/2/4/3 | two stale ports (2016/2022) |
| Simple Chat | yp9xt1 | 0.6.1 | 0 | 2018-10 | static capnp; chat log JSON | direct WebSession | 3/2/3/5 | 0.3 MB; direct-capnp exhibit |
| Duoludo | yx8a62 | 2015.08.29 | 25 | 2015-08 | OCaml | websockets | 1/1/2/3 | game |
| Lychee | z6rj6j | 3.0.9 | 26 | 2016-03 | php; mysql | REST | 2/2/3/2 | needs mysql |
| Hakyll CMS | z7za0n | 1.1.0 | 13 | 2016-09 | haskell static); markdown in, static out | file writes | 3/3/2/4 | Hugo covers it |
| Tiny Tiny RSS | zj20q6 | 2021-12-31 | 65 | 2022-12 | php + mysql5.5(nix); mysql | REST /api | 4/2/3/2 | powerbox proxy + old mysql |
| NodeBB | zt4j87 | 0.8.2 | 9 | 2015-11 | node; bundled db | REST | 2/2/3/2 | 0.8.2, 2015 |
| SandForms | ztxnre | 0.4.0 | 24 | 2016-12 | node; form JSON | JSON | 3/3/3/4 | jack singleton; forms |
| GitLab | zx9d3p | 2016.07.18 | 89 | 2016-07 | ruby; postgres | REST | 2/2/4/1 | 8.7.9, 2016; enormous |
| 3D Blockstack | zxent0 | 0.0.2 | 33 | 2025-12 | php-fpm; JSON state | page JSON | 2/1/4/4 | fresh 2025-12; game door |

## Recommended set (13, ordered)

1. **Davros** `15bf9266` 60 MB, node; files+sqlite; WebDAV + `/api`. The agent's filing cabinet, and
   the freshest app in the whole index (2026-10-25, mnutt). A stranger drags a file in, makes a
   folder, plays an mp4 from the browser. An agent PROPFINDs the tree, PUTs documents, moves and
   renames — a grain that *is* a directory. Bridge must grow the DAV verb set for the full value;
   plain GET/PUT of file paths works the day it lands.
2. **EtherCalc** `9b3b7615` 35 MB, node/socialcalc; shipped 2026-10-09. Stranger types into cells
   beside a second browser and both cursors move. Agent drives the SocialCalc REST/socket API:
   set cells, read the sheet as JSON, post a computed row. Needs nothing new — REST over GET/POST.
3. **HedgeDoc** `ff642cdb` 70 MB, node+sqlite; 2023. Stranger writes markdown, gets a rendered pad
   and a share link. Agent creates/edits/exports notes over `/api` — the cleanest document API in
   the set. Nothing new needed.
4. **Datasette** `547714ee` 69 MB, python; sqlite files. Stranger uploads a SQLite db and browses it
   as clickable tables. Agent runs SQL and gets JSON — the entire app is one query surface, the
   ideal "easy but powerful datamodel". Nothing new needed beyond upload (POST).
5. **sntfy** `bc424d5f` 17 MB, go (ntfy v2.28); shipped 2026-09-11. Stranger sees a live feed, posts
   to it from a form. Agent's simplest possible write: `POST /topic` with a body — a notification
   primitive for the fleet itself (job done, row red, budget low). Runs today.
6. **DokuWiki** `dda6d7e2` 30 MB, php-fpm+nginx; flat `.txt` pages. Stranger edits a wiki page in
   DokuWiki syntax, watches history/diff. Agent fetches raw pages (`do=export_raw`) and saves by
   POST — the whole wiki is literally a directory of text files. Same bridge shape as any php app;
   verified php-fpm+nginx inside, no DB.
7. **Etherpad** `aee0806c` 61 MB — **qualified today**, the opening's app. Stranger co-writes a pad.
   Agent uses the `/api` (create pad, append, get HTML/markdown) and revisions. saveIdentityCaps
   already served.
8. **WBO** `ac72e0d1` 32 MB, node; 2023. Stranger draws on a whiteboard with someone else, live.
   Agent strokes shapes over the board's websocket JSON. WebSockets are served (`web.rs
   open_web_socket`, `dispatch_delivery` prequeue).
9. **SandCal** `a84130b2` 16 MB, go+sqlite (`/var/sandcal.db`); zenhack 2022. Stranger adds an event
   on a calendar grid. Agent reads/writes events as JSON over its web API; full CalDAV
   interop waits for the DAV verbs (REPORT/PROPFIND).
10. **Gogs** `aede44cf` 15 MB, go+sqlite; 2018 but complete. Stranger creates a repo, edits a file
    in the web UI. Agent `git clone`s the grain over HTTP, branches, pushes, and reads
    `/api/v1` (issues, PRs) — a real forge under member authority. Needs streaming bodies for
    git's pack protocol.
11. **Hledger Web** `23321185` 19 MB, static Haskell binary; 2023. Stranger records a transaction,
    sees balances. Agent appends to the plain-text journal and queries balances/JSON — accounting
    as files, memorable for a finance-curious visitor. Single static binary, no daemons.
12. **Hacker Slides** `f0277a5d` 16 MB — **qualified today**. Stranger writes markdown, presents
    reveal.js slides (`getPublicId` link). Agent rewrites `slides.md` and the deck changes.
13. **Wekan** `2a2c0504` 173 MB, meteor+mongo — the index's flagship, still shipping (2026-10-25),
    the one app a stranger may already know. Same runtime shape as Simple Todos (bundled mongod),
    REST API beneath. L-class: the only reservation is size and mongo memory, not the bridge.

Second wave (each a paragraph deferred): **diagrams.net** (drawio XML is agent-writable — an agent
that *draws*), **Hugo** (markdown in, a whole site out), **WordPress** (4.9.8/sqlite port, full
`/wp-json`; the name everyone knows), **Scrumblr** (6 MB sticky notes + redis), **FileDrop** (4 MB
file exchange), **ExpenseOwl** (one JSON ledger file), **Simple Chat** (0.3 MB, direct-capnp — the
non-http-bridge exhibit), **OrgTodo** (org-mode text, fresh 2026-08), **Hummingbird** (agent-written
Hive monitor scripts, 2026-02), **Badgepack** (2026-08), **Kiwix** (offline-wikipedia wow), **IPython
Notebook** (REST, 178 MB), **Simple Todos** (qualified; keep as the meteor exhibit).

## Excluded, one line each

- Roundcube (needs external IMAP; egress-free demo), GitLab 8.7/Rocket.Chat 0.53/Apache Wave/MediaGoblin/Ghost 0.5/NodeBB 0.8/Let's Chat/SandChat/Telescope/Brainstorm/Giftr/Quick Survey/Idea Otter/Contact Otter/Meteor Blocks/Paperwork/Lychee/Framadate/Piwik/Monica/Firefly III/ShareLaTeX/CodiMD/Laverna/Dillinger/SandMD/TextEditor/Simple Rich Text/Hacker Resume/Hakyll CMS/Hacker CMS/dieStorm/CrypTag/OwnTracks/Biandang/Linksholder/Neuron Catalog/Desert Atlas/Legends Browser/Sum (stale ports, mysql-bound, or superseded by a pick above).
- TT-RSS: works-hard set (bundled MySQL 5.5 + powerbox proxy ports) — return after powerbox.
- Radicale: pure CalDAV verbs, nothing without them; SandCal covers calendars meanwhile.
- Collections: sandstorm's own powerbox showcase — blocked on powerbox, not forgotten.
- Mercurial/GitWeb: VCS covered by Gogs; GitWeb already composted on the lane.
- Games (2048, 3D Blockstack, Perplexity Sudoku, Game of Y, Go, BrowserQuest, Duoludo, Acronymy): fine doors — 3D Blockstack and Sudoku are fresh (2025) — but zero agent surface; pick at most one for the tour's play door.
- Sandpass (passwords — wrong surface for a public demo), Sandstorm Error Collector (internal), XRF Sync/Billing/Books (device/niche, though freshly maintained), Baby Buddy (124 MB niche), Angr (205 MB specialist), Tube/Groove Basin (media-heavy), Swagger Editor (nice but static-only).

## What the bridge must grow

Nothing below blocks the 13; three items unlock them fully, in priority order:

1. **The WebDAV/CalDAV verb set** — map PROPFIND, PROPPATCH, MKCOL, COPY, MOVE, LOCK, UNLOCK,
   REPORT in `native/spk-host/src/dispatch_web_input.rs::call_for` and drive the matching
   `WebSession` calls in `native/spk-rpc/src/web.rs`. The in-app bridge binary already serves them
   (`WebSessionImpl` carries Propfind/Proppatch/Mkcol/Copy/Move/Lock/Unlock/Report — verified in its
   strings). Unlocks: Davros fully, SandCal CalDAV, Radicale, DAV-style file apps.
2. **Streaming request/response bodies** — `ByteStream`/`RequestStream` fail closed today
   (`spk-rpc/src/protocol.rs`). Unlocks: Gogs git smart-HTTP packs, big file move in Davros,
   Datasette CSV/JSON exports.
3. **Powerbox request/offer** (`getSessionRequest`/`getSessionOffer` + descriptor routes, noted in
   `spk-rpc/src/bridge_config.rs`) — not needed by the 13; the door back in for TT-RSS,
   Collections, and OAuth-style apps.

Served today and confirmed enough for the set: `SandstormApi` save/restore/drop,
`SessionContext`+`HackSessionContext.getPublicId`, `EmailSendPort`, identity (`saveIdentityCaps`),
`AppHooks` (`expectAppHooks`), `WebSession` GET/HEAD/POST/PUT/PATCH/DELETE, WebSocket streams,
ApiSession bootstrap. No recommended app needs an `apiPath`.

*Sources: live index (98 apps; sizes via HTTP HEAD of each package), 52 packages read with the
pinned `package.capnp` (SPK = magic + XZ of a signed capnp `Archive`, per
`native/spk-package-stream/src/lib.rs`); upstream repos per `codeLink`. Scratch:
`~/dev/minidregg-lanes/glm-spk-scout/` (app-list.json, sizes.json, extracted/ per-package trees,
tokens, manifests, bridge configs).*
