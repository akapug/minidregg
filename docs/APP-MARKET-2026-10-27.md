# The app market: any Sandstorm app, installed by a member, on its own origin

Present-state design, 2026-10-27 (lane L13). Ember: "we should let people grab anything from the
main sandstorm store ... raise our ambitions." One bar: a member of the demo picks any app from the
Sandstorm app market, installs it, opens it in their browser on its own origin, with Mini's
authority, confinement and receipts around it. Companion files: `deploy/market/` (the units, the
fetcher, `INSTALL.md` with the exact Caddy and nftables rows), `native/resource-client/src/apps.rs`
(`mini apps …` and `mini apps-front`), `native/resource-client/journey.d/japps.sh`.

## 0. Status, said plainly

| piece | state |
|---|---|
| Catalogue: `mini apps search/show`, the recorded index fixture, the verdict table | **built**, tests pass on the Mac (`cargo nextest -p minidregg-resource-client -E 'test(apps_)'`) |
| Market fetcher `mini-market-fetch` + `mini-market.{service,timer}` (uid `mini-market`, the one egress path) | **built** (bash + curl, the shape `fetch-test-spk.sh` already has); not yet run on a box |
| The grain front `mini apps-front` (Host-dispatching entrance behind Caddy, replaces `spk-browser-proxy`) | **built** with loopback tests; not yet run against a live route socket |
| `japps.sh --dry` (Mac) and `--box` (`dregg-build`, 2026-10-27) | **green**: `--dry` 18/18 (catalogue, the two real packages verified, a tampered copy and an unknown appId refused by name, the front over real sockets); `--box` 22/22 with the four `spk-host qualify` exhibits proven on Linux (Hacker Slides, Simple Todos, Etherpad and TT-RSS all accepted once §3a landed); the scratch-world lifecycle rows are UNCONFIGURED on the build box until a broker world (`two-world-journey.sh`'s setup) exists there |
| Member verbs `mini apps install/list/open/stop/start/share/export/delete` over the worker socket | verbs **built** against the socket protocol of §4; the worker itself is the next increment |
| `mini apps-worker` (the operator-side custodian that drives `spk-host grain`) | **designed** (§4); the `--box` journey drives the same steps through `grain-journey.sh` meanwhile |
| The request law `law.apps` rendered from Lean (`scripts.AppsLawTemplate [not in tree]`) | **designed** (§3); until it lands, the member's package choice is carried by the worker socket and the signed state is the birth + delegation |
| Per-grain origin via the wildcard certificate and `*.demo.dregg.online` | infra lane applies DNS (live) and Caddy; the routing rule is §5 and `deploy/market/INSTALL.md` |
| `saveIdentityCaps` and `expectAppHooks` served (§3a): `spk-rpc` identity save/restore/drop with the dual Identity+AppPersistent object, `spk-host/identity_custody.rs`, the three refusal sites widened | **built**; spk-rpc tests on the Mac; spk-host builds and its custody tests run on dregg-build; the four exhibits accepted by `qualify` in `--box` |
| Compost (§7) | the GitWeb chain deleted in this lane; `spk-browser-proxy` deleted once the front has served one grain over the real edge |

## State at hand-off (2026-10-27 night)

**Rule now (COORDINATION §4):** lanes and faeries run no builds and no validation, including
qualification rows and standing worlds. The integrator's rows validator runs every table below
against each new candidate and routes reds back to this lane. This lane writes recipes and code.

**Qualified with a write (lifecycle rows plus one beneath-HTML write, proven by a run): 4.**
Etherpad, Hacker Slides and Simple Todos (`japps --box` on w6), and EtherCalc (featured, w11).
Lifecycle passes whose write has not yet run with its recipe:
- from the featured table: HedgeDoc, DokuWiki;
- from b1: SandMD, Permanote, TextEditor, Dillinger;
- from b4: WordPress;
- from b2: Yet Another TODO, ExpenseOwl, SandCal;
- from b6: SandForms, Badgepack;
- from rt: WBO, Gogs.

**Recipes ready for the rows validator.** Each table is
`scripts/spk-platform/market-batches/<t>.tsv` (letters j..m or j..p, so give each table its own
world). Its writes are in `scripts/spk-platform/market-writes/<t>.sh`, with helpers
`<t>-*.py`. Run:

    QUALIFY_STOP=1 QUALIFY_TABLE=<table> bash scripts/spk-platform/featured-qualify.sh WORLD.env OUT

The featured table is built in and needs no `QUALIFY_TABLE`. Every recipe is reasoned from
the app's docs, its package and the rows; a comment above each names its source.

| table | apps | notes |
|---|---|---|
| featured (built in) | EtherCalc (proven), HedgeDoc, Davros, sntfy, DokuWiki, Hledger Web, Datasette | Datasette 0.63 has no HTTP write: its row records a read and stays red by design. HedgeDoc's own write cannot work, because its package lacks `iconv-lite/encodings` and every HTTP body it parses throws; rt's HedgeDocRT writes over socket.io instead. |
| b1 | SandMD, Permanote, TextEditor (DDP), Dillinger | SandMD is a HackMD fork and may share HedgeDoc's package defect. |
| b2 | Yet Another TODO, ExpenseOwl, OrgTodo, SandCal | OrgTodo is refused at install: `invalid or oversized sandstorm-manifest` (owed: read the manifest against MAX_MANIFEST and the decoder) |
| b4 | Hugo, WordPress, Hacker CMS, Hakyll CMS | read-back through the publishing socket `www.sock` (§5a) |
| b6 | SandForms (DDP), Badgepack, OwnTracks, Hummingbird | |
| rt | WBO (socket.io), HedgeDocRT (socket.io), Wekan (DDP), Gogs (forms with `_csrf`) | Wekan needs a world with `MINI_IMPORT_PROFILE=market-large-v1` |
| dav.sh | DavrosTree (MKCOL, PUT, MOVE, PROPFIND depth 1), SandCalDAV (probe) | needs a Host with the DAV calls: main since cut 13 |

**What the validator's worlds need:** a candidate built from main at or after this tip. It
carries the DAV calls, the provenance fix, the bridge compatibility fixes, the profiles and the
broker wait. Use `world-up.sh` from the same tree. Run one table per world, and run Wekan's world
with `MINI_IMPORT_PROFILE=market-large-v1`. Before running Davros and sntfy again, check they got
past start: both failed there on w11 because of the provenance bug, which is now fixed.

**Done in code this session (all on main via continuous integration):**
- **DAV calls and body shapes** (`dfdecbba`, §2b). The design: `davMethod` and per-method body
  rules in Lean, with `dav_header_needs_dav_method`, the witnesses and `dav_poles`. On the Rust
  side, the DAV lists are generated from the registry, the entrance takes chunked bodies,
  100-continue and content-encoding, and spk-rpc makes the typed WebSession DAV calls and
  OPTIONS. 58 of 58 filtered tests passed on dregg-build.
- **Provenance** (`4d933739`): a pinned root-owned directory stays trusted when entries are
  added. Every world registration had been breaking any grain starting at that moment
  ("hostd journal ancestor…", "attestation directory custody refused").
- **Bridge compatibility with Sandstorm** (`365aaad7`): apiPath as concatenation (OwnTracks),
  permission names with `_`, `-` and `.` (Hummingbird), and the canonical empty bridge config for
  pre-bridgeConfig packages (Hacker CMS). Each commit says why the stricter rule protected
  nothing, with tests both ways.
- **Import profiles** (`91429251`): `market-large-v1` (512 MiB raw, 2 GiB decoded, same
  decoder memory) and an intake wall clock of 60 s plus 3 s per raw MiB, capped per profile.
  `spk-host import-limits` is the one table, which spk-ingest, spk-qualify and spk-install-phase
  read.
- **world-up:** it waits for the broker socket's final mode, up to two minutes (`579696af`).
- **The harness:** `QUALIFY_TABLE`, `QUALIFY_WRITES`, `QUALIFY_STOP`. HedgeDoc's defect is named,
  and DokuWiki's failed save says why.

**Owed by this lane (code, no runs):**
1. When the validator's rows come back: fix each red recipe from its row evidence, and add each
   green app's agent hook to `FEATURED` (or a second tier) in `apps.rs`. The catalogue then
   lists the qualified market.
2. **The member's own install, rerun** with the holder-form parent (`72e6a1a8`, L1's law on main).
   This is now the validator's run: `apps-e2e.sh WORLD.env OUT <appIds>` with
   `MEMBER_FUNDING=10000 APPS_MAX=50000`. This lane then replaces the ~1,500 estimate in
   INSTALL.md §4 with the measured figure.
3. **Bodies above 8 MiB:** designed in §2b (a body digest in the record, a spooled file, then
   RequestStream), to land as its own cut when a market app needs it.
4. **Direct-capnp apps** (Simple Chat, B7) serve WebSession themselves. With the default bridge
   config they now pass install. Whether they launch is for the validator to show.
5. **The rest of the 42:** B3 boards, B5 files and media (streaming), B7 doors and B8
   second-wave are not started. Each is a recipe-writing faerie brief now (hand-off
   batch-table shape, minus the runs).

**Not this lane's:** the co-edit red (`authority handoff requires an opening read from the
Store`, `withOpenedFreshTip`) is with the deputy's faerie. When it is fixed, the validator
reruns `register-Xs` and `ddp-coedit.py`.

**Box notes (for the validator):**
- After each checkout on dregg-build, run `chmod go-w deploy/spk-host/*`.
- Worlds made from an older candidate need the scripts of their own era. `lane/app-market-w11`
  pairs with `/build/lanes/app-market-frozen/w11-bin`.
- A failed `world-up` that left no WORLD.env is cleaned up by stopping its
  `mini-spk-broker@<store>` unit, then running `install-user-world remove <store> <helper>`.

## 1. The pieces, who runs what

Everything below is on the demo box (`dregg-demo`, Debian 13, split tenancy, loopback behind
Caddy, nftables default-deny egress per uid; `dregg-infra` `edge/demo/CONFINEMENT.md`). The grain
world is `mini-core`'s (its user manager runs the SPK broker and residents; the worker is a system unit as mini-core), exactly as
the one-grain EtherCalc design (WEB-SPK-PUBLIC §4) already has it.

| who | uid | does | reaches |
|---|---|---|---|
| **market fetcher** `mini-market-fetch` (`mini-market.timer`, every 6 h and on demand) | `mini-market` | refreshes `/var/lib/mini-market/index.json` from `https://app-index.sandstorm.io/apps/index.json` (bounded 4 MiB, parsed and re-serialised by `mini apps index-check`: unknown shape refused, the file replaced atomically); fetches packages named in `/var/lib/mini-market/wanted/` into the quarantine `/var/lib/mini-market/quarantine/<packageId>.spk` (0640 `mini-market:mini-apps`), refusing a download whose SHA-256 does not start with its `packageId` or exceeds the standard profile's 256 MiB; writes `meta/<packageId>.json` (sha256, bytes, fetchedAt) | **the only uid with egress to `app-index.sandstorm.io:443`** (nftables `cg_market`/`dst_market`, resolved from `/etc/mini/market.json` like every other egress row); nothing else, no Mini socket, no key |
| **member verbs** `mini apps …` | `mini-s-NAME` | read the index and the verdict table (world-readable data); author the member's own Mini turns (§3); talk to the worker over `/run/mini-apps/worker.sock` | the public socket, as every member verb does; the worker socket |
| **worker** `mini apps-worker` | `mini-core` (system unit; reaches the broker in mini-core's user manager) | acts on admitted install requests through `spk-host grain` (install, share, start, enroll, route, stop, export); writes receipts, verdicts and the origin table; serves the worker socket | the operator socket (it is the operator), the broker, the quarantine (read), `/var/lib/mini-apps` (write) |
| **front** `mini apps-front` | `mini-apps-edge` (group `mini-edge`) | one loopback listener `127.0.0.1:8799` that Caddy proxies every `*.demo.dregg.online` request to; selects the grain by `Host`, the participant route by the token presented, and pumps the request (and a WebSocket after 101) to that route's `http.sock` | the route sockets (0660, group `mini-edge`, the W6 `edgeGid`), the origin table (read); no key, no Mini socket, no network but loopback |
| **Caddy** | `caddy` | terminates TLS for `*.demo.dregg.online` with the one wildcard certificate (ember's ruling 2026-10-27; hybrid X25519MLKEM768 then X25519), proxies to the front | loopback; `/var/lib/mini` stays hidden from it |
| **residents / apps** | `mini-core` → app uid in bwrap | unchanged (`deploy/spk-host/README.md`) | fd 3, loopback in their own netns; no egress ever |

The index is data, never instructions: titles, descriptions and links are shown as the index's
claims; identity is the signed package's (appId from the signing key, packageId = the first 16
bytes of the SPK's SHA-256, title and version from the signed manifest), verified by the same
`sandstorm-package` + `spk-package-stream` parse the broker's ingest runs. The catalogue says which
it is showing.

## 2. Catalogue: `mini apps search`, `mini apps show`

- Whole-store lifecycle evidence is now a separate `qualification` field beside the local
  ingest verdict. `scripts/spk-platform/store-sweep.sh` runs the public index without
  per-app recipes; the candidate embeds `deploy/market/store-qualification.json` and
  `--qualification FILE` (or `MINI_APPS_QUALIFICATION`) selects a newer recorded sweep.
  Search says **known working (lifecycle; candidate SHA)** only for an exact appId/packageId
  PASS through install/share/start/enrol/GET `/`. Unswept entries remain unswept; this does
  not assert that the app's writes or external services work. See
  [`STORE-SWEEP.md`](../scripts/spk-platform/STORE-SWEEP.md) for running, resuming and publishing it.
- `mini apps search [TERM] [--category C] [--json]` lists matching apps: name, version, appId (the
  publisher's key hash), publisher, package size when known, and **Mini's verdict** from
  `/var/lib/mini-apps/verdicts/<packageId>.json`, written by the worker's real ingest: `verified`
  (signature and appId checked, bridge profile supported, within the standard profile),
  `refused: <reason>` (an unchecked `apiPath`, `sizeOverProfile`), `running N` (grains on this box),
  or `unverified` (never fetched here; install verifies). Nothing in the index can produce
  `verified`.
- `mini apps show <appId|packageId>` shows one entry whole, with the package URL the fetcher would
  use, the size class the worker would pick from the fetched size (S under 64 MiB raw, M up to the
  profile's 256 MiB; L is the operator's explicit choice), and the refusals an install could meet.
- Both read `MINI_MARKET_INDEX` (default `/var/lib/mini-market/index.json`); the recorded fixture
  `native/resource-client/tests/fixtures/sandstorm-index-2026-10-27.json` (98 apps) pins the shape
  the tests and `--dry` use. In the shell they are `apps search` / `apps show` (one row of the verb
  table, §5a); L12's market pane renders the same JSON (`--json`).

## 2a. The featured set: apps an agent can drive beneath the HTML

Ember's ruling (2026-10-27): the market ships a curated set chosen for an easy but powerful data
model and a scriptable surface beneath the human-visible page, because agents work there. The set
is the GLM scout's recommendation (`docs/review/2026-10-27-spk-selection/SELECTION.md` on
`lane/glm-spk-selection`, 98 apps scored, 52 packages read) kept whole: every pick runs the
bundled `sandstorm-http-bridge` the qualified apps already prove. `mini apps search` lists these
first, each with its agent hook (`apps.rs` `FEATURED`), then the rest of the store; L12's pane
reads the same JSON (`featured {rank, agentHook}`).

**How a resident reaches the hook.** The hook is plain HTTP on the grain's own origin. A member's
resident (Hermes) holds an api route the member issued (`mini apps share`, bearer token,
`kind api`) or an agent route on the grain (`grain_agent_route.rs`, served by `agent_api_server.rs` on the resident's own socket); either way each request is a Mini turn checked by the custodian under the resident's
delegated capability, exactly as a browser's, and lands in the app as the same HTTP the page
would send. Nothing beneath the HTML bypasses the grain's authority or its receipts.

| # | app | the two-minute stranger story | the agent hook beneath the HTML | bridge needs |
|---|---|---|---|---|
| 1 | Etherpad | write together in a pad; watch a friend's cursor | `/api`: create pads, append, read text/HTML, revisions | served (`saveIdentityCaps`); **qualified on w3 and w5** |
| 2 | EtherCalc | type into a sheet beside a second browser | `PUT /_/<sheet>` CSV, `POST` SocialCalc commands, `GET …/csv` | served |
| 3 | HedgeDoc | markdown on the left, the rendered note on the right, a share link | `POST /new` with markdown makes a note; `GET /<note>/download` | served |
| 4 | Davros | drop files and folders in, play an mp4 in the browser | a file tree over HTTP: `PUT`/`GET` by path under `/remote.php/webdav/` | served for GET/PUT; PROPFIND/MKCOL/MOVE/COPY/LOCK need the DAV verbs (§2b) |
| 5 | Datasette | upload a SQLite file, click through its tables | `/<db>.json?sql=…` answers JSON (0.63 has no HTTP write; the upload is the page's) | served |
| 6 | sntfy | a live feed you can post to | `POST /<topic>` publishes, `GET /<topic>/json?poll=1` reads: the fleet's notification primitive | served |
| 7 | DokuWiki | edit a page, see history and diffs | flat-text pages: `GET doku.php?id=…&do=export_raw`, `POST do=save` with the form's `sectok` | served |
| 8 | WBO | draw on a whiteboard with someone else, live | board events as JSON over its WebSocket; `GET /boards/<name>.json` | served (WebSockets) |
| 9 | SandCal | add an event on a calendar grid | events as forms and iCalendar over HTTP | served; CalDAV clients need REPORT/PROPFIND (§2b) |
| 10 | Gogs | make a repo, edit a file in the web UI | `REST /api/v1` (repos, issues) | served for REST; `git clone`/`push` needs streamed bodies (§2b) |
| 11 | Hledger Web | record a transaction, see balances | a plain-text journal: `POST /add`, `GET /journal`, the JSON API | served |
| 12 | Hacker Slides | write markdown, present the deck at its publishing origin | the deck is `slides.md`; published at `https://<grain>-www.demo.dregg.online` (§5a) | served (`HackSessionContext`); **qualified on w3 and w5** |
| 13 | Wekan | a kanban board the visitor may already know | `REST /api` (boards, lists, cards) and DDP | served; class L (bundled mongod) |

Simple Todos stays qualified as the Meteor exhibit and the co-edit row's app; it is not featured.
Qualification is `scripts/spk-platform/featured-qualify.sh` on a standing world: every app through
create, install, share, start, enrol and page load, then ONE write beneath the HTML by a script
standing in for a resident; its rows are recorded in §0.

## 2b. The bridge's surface beyond GET/POST: DAV calls and bodies

**DAV calls** (`dfdecbba` on `lane/app-market-dav`, landing with a cut, because the Host changes).
PROPFIND, PROPPATCH, MKCOL, COPY, MOVE, LOCK, UNLOCK, REPORT and OPTIONS are ordinary exchanges
(`web-session.capnp` @7..@16; `acl` is not served). Each is one request, one response and one Mini
write. The method token is part of the signed record, so the rule is Lean's:
- `Kernel/ApplicationDispatchAdmission.lean`: `davMethod` is part of `exchangeMethod`.
- `requestSafeFor` gives each method its body rule: COPY, MOVE, UNLOCK and OPTIONS carry none;
  PROPFIND, PROPPATCH and LOCK carry UTF-8 `xmlContent`.
- The four parameter headers (`depth`, `destination`, `overwrite`, `lock-token`, `davHeaderName`)
  are signed on a DAV call and refused on any other.
- Theorems: `dav_header_needs_dav_method`, `dav_bodyless_body_empty`, the witnesses
  `dav_propfind_admitted` and `dav_write_calls_admitted`, and the poles `dav_poles`.
- The lists reach Rust through `protocol/host-operations.json` (`dav_methods`, `dav_headers`),
  which is checked against the Lean definitions.

On the Rust side:
- The entrance parses the methods.
- `dispatch_web_input` projects the headers into spk-rpc's `DavArgs`. The destination is taken
  from an https URL on this grain's origin, or an absolute path, and becomes the relative
  Sandstorm path.
- `dispatch_web` makes the typed WebSession call. 207 Multi-Status is a mapped success code.
- OPTIONS answers `DAV: 1, 2, …` from the app's typed `Options`.
- The agent wires admit the same calls, so a resident can drive Davros over WebDAV exactly as a
  desktop client would.

**Bodies.** A request body is part of the signed record and is bounded at 8 MiB by Lean and by the
transport. Within that bound, the entrance now takes the shapes git and DAV clients send:
- `transfer-encoding: chunked` (git uses it above 1 MiB), decoded into the bounded body. Trailers
  are refused, and so is a length beside chunked.
- `Expect: 100-continue`.
- `content-encoding`, signed as an ordinary header and carried as PostContent's `encoding`. git
  gzips the bodies it sends on fetch.

Response bodies already stream from the app over `ByteStream` into the 8 MiB response bound
(`web.rs` `ResponseStream`). So Gogs' git pushes and fetches, and Davros' file moves, work up to
8 MiB per request.

**Above 8 MiB (designed, not built).** The record cannot carry such a body, so it would commit to
one instead:
- The record holds `bodyDigest` and `bodyLength` in place of the bytes. That is a codec kind in
  `ApplicationDispatchCodec`: a new `Request` field, with `requestSafeFor` bounding the length by
  the import profile rather than by 8 MiB.
- The entrance spools the body to a per-request file under the resident's private directory
  while it hashes it.
- Mini admits the digest.
- The resident streams the file into `putStreaming`/`postStreaming`'s `RequestStream`
  (`web-session.capnp` @5/@6), and refuses at `done` if the bytes it sent do not hash to the
  admitted digest.
- Responses above 8 MiB stream to the client as `ByteStream` writes, with the digest in the
  completion record.

This is a codec flag day for every dispatch record, so it lands as its own cut once an app in the
market needs it: Groove Basin and Tube media, or large Davros uploads.

**Powerbox request/offer**: none of the featured set needs it. It is the way back in for TT-RSS
and Collections.

## 3. Install: the member turn, and what admits it

`mini apps install <appId|packageId> [--class S|M|L] --dir WORKSPACE` is a member verb. Admission
is Mini's, through receivers that already exist; this lane registers **no new operation byte**,
because every statement the install needs is already a kernel-admitted record:

1. **The application birth** (op 30 `APPLICATION_CURRENT_BIRTH`, public route): `mini apps install`
   births the app, package-manifest and snapshot-manifest resources as the member's own turn, the way
   `workspace create` births a resource: nine ids reserved in the member's namespace, the exact source
   retained, authored through the Host, submitted once with exact recovery, three references
   registered (`app-<id>`, `-package`, `-snapshot`). The admitted shape is the metered composite
   (`Host/Json.lean` `grainBirthIntentFrom "applicationGrainBirth"`): the member is creator, owner and
   fee payer (`applicationBirthContext` from the member's own birth context, `applicationSpec` with the
   six capabilities), and the composite names the world's metered **parent** (7901) and **tool**
   (7902) tasks as peers with their current state. So the member needs references to those two tasks
   (`/etc/mini/apps.json` names them, default `tool`/`parent`), which the operator delegates: the
   refusal `meteredGrantRequired` names the missing one. This is "the member's app-install capability
   and the funding": L1b's `grainBirthTariff` attaches here, and who pays for the metered reserve is
   L1b's ruling. Retained: `WORKSPACE/apps/<appId>/birth/{source,outcome}.json`.
2. **The hosting delegation** (the shell's `app delegate-lifecycle`, `app_lifecycle.rs`: six
   ordinary current proposals, policy + grant for app, package and snapshot, admitted by the
   capability-delegation receivers), which `mini apps install` runs to completion against the three
   references, the manager being `/etc/mini/apps.json`'s `managementSubject`: the member delegates
   lifecycle hosting of *this* app to the operator's management subject. `spk-host grain install --management-selector` consumes exactly this
   (`grain_management.rs`, protocol `mini-spk-grain-lifecycle-delegation-v1`), and the share
   authority the worker later exercises is the delegated app capability
   (`Kernel/ApplicationShareIssueDelegation.lean` records it; the custodian never holds the
   member's key: custody contract L2).
3. **The package choice** is the third statement: a write to the member's `apps-<id>` cell under
   the law `law.apps`, rendered from Lean by `scripts/AppsRequestTemplate.lean` from
   `Kernel/AppsRequest.lean` the way `law.market` is rendered from `Kernel/SealedMarket.lean`
   (`native/resource-client/templates/apps/request/{law.apps,fields.json}`): fields packageId (two
   u64), appId (four u64), class, state, grain, generation; the requester writes the choice once and
   it is frozen (`choice_frozen_after_setup`, pole `package_change_refused`); the manager (the
   delegation's `managementSubject`) writes the outcome once, 0 → 1 running with a nonzero grain or
   0 → 2 refused (`outcome_once_by_manager`, pole `requester_cannot_decide`); the law admits no
   install and no revoke (`no_install_no_revoke`). `mini apps install` births the cell and writes
   the setup before it asks the worker (an `auto` class is sized by the worker first, then recorded);
   the worker records the cell with the grain and writes the outcome as the manager (its own
   workspace; the write is the next increment, named in the batch).

The verb then hands the worker, over the authenticated socket, the three pointers (birth source and
receipt, the delegation file) and the choice. **Refusals by name** before any effect:
`unknownApp` (not in the index), `sizeOverProfile` (the fetcher's recorded size or the index's
declared size above 256 MiB raw / 768 MiB decoded), `unverifiedSignature` (the ingest's verdict),
`appIdMismatch` (signed appId differs from the catalogue's), `unsupportedBridge` (an unchecked
`apiPath`; `saveIdentityCaps` and `expectAppHooks` are served, §3a), `funding` (the kernel's),
`classRefused`. A lost reply is answered by the **exact retry** of the
same request id (`mini apps install --retry ID`); the worker's idempotency is per request id and
per the lifecycle's own one-shot markers (SPK-LIFECYCLE); a second install is never issued.

**Receipt.** `WORKSPACE/apps/<app>/receipt.json`: the request id, the app resource, the package's
raw SHA-256 and signed appId, the class, the grain id `a<app>`, the origin
`https://a<app>.demo.dregg.online`, the INSTALL and START receipts' accepted counts, and the
bootstrap hand-off (`mini apps open`).

### 3a. The two bridge facilities "any app" needs: saved identities, app hooks

Sandstorm apps people know (Etherpad, Tiny Tiny RSS, Wekan) declare one or both of
`BridgeConfig.saveIdentityCaps` and `expectAppHooks`; until 2026-10-27 the custodian refused each by
name. Both are served now, modelled as what they are:

- **`saveIdentityCaps`**: the first time a participant opens the grain, the bridge calls
  `SandstormApi.save(identity)` and keeps the token in the grain's `/var`; later `restore(token)`
  gives the identity back (`getSavedIdentity`), `drop(token)` lets it go. In Mini this is **a
  grain-held capability the member granted by opening the grain**: `spk-rpc`'s supervisor serves
  `save` only for an identity object this connection minted (the object describes itself through
  `AppPersistent.save` with a tag bound to the connection's secret and that identity: a forged
  object or any other capability is refused by name, `identityTagRefused` /
  `unsupportedPersistentCap`), and `spk-host`'s `identity_custody` keeps the record outside the
  sandbox in `apps/<app>/identities/<token>.json` (0600, the operator's), across generations. The
  record is listed in the member's receipts (`mini apps list/status` show "identities held by this
  grain") and **revocable** from outside (`FileIdentityCustody::revoke`, the worker's
  `share --revoke`): a revoked or dropped token answers `identityRevoked` for every later generation,
  an unknown one `unknownToken`. The identity carries the display name and handle the custodian
  presented, no permission bits.
- **`expectAppHooks`**: the app connects back to the bridge and offers `AppHooks`; the bridge then
  answers `getViewInfo` through the app and would delegate app-object `restore`. The custodian's
  bound is explicit: `getViewInfo` through the hooks under the adapter's existing view-info
  deadline; `SandstormApi.save` of an app object is refused (`unsupportedPersistentCap`), so no
  app-object token is ever minted and `restore` of one is `unknownToken`; every other `SandstormApi`
  method (powerbox, sharing, scheduling, activity) stays unimplemented by name.

`spk-host qualify` reports both flags under `bridgeFacilities` with the sentence of what is served.
What still refuses by name: an `apiPath` outside the checked prefix.

## 4. The worker: one custodian, the existing lifecycle

`mini apps-worker --state /var/lib/mini-apps --profile GRAIN-HOST.json --socket /run/mini-apps/worker.sock`
runs as `mini-core` as a system unit (User=mini-core; drives `mini-spk-broker@` in mini-core's user manager). Per admitted
request, in order, each step idempotent on its retained artifact, as `grain-journey.sh` does today:

1. **Package**: the quarantine copy with the exact SHA-256 (or `wanted/<packageId>` for the
   fetcher, and the request waits `fetching`); never a path from the member.
2. **`spk-host grain install PROFILE source receipt SPK --class C --management-selector DELEG`**:
   stage, broker `place`/`set-cgroup`/`ingest` (the bounded no-network unit; `standard-v1`), INSTALL
   BEGIN/CLAIM/COMPLETION through Mini. The verdict file is written from this parse.
3. **Guest participant and route** (ruling 2026-10-27, v1): the grain has **one hosted guest
   subject** (the grain world's management subject, exactly the shape the one-grain EtherCalc route
   and `grain-journey.sh` use) and **one route per (grain, member)**: its own session birth (op 31),
   its own ticket under the delegated share capability (`grain-share-issue-*`), its own
   `spk-host grain route` with `expectedHost = a<app>.demo.dregg.online`, `edgeGid = mini-edge`, its
   own three tokens and identity record, in `/var/lib/mini-apps/routes/a<app>/<member>/` (0750
   `mini-core:mini-edge`). Signing is custodial over that guest subject, never over the member's key.
   **Consequence, stated in the receipt and on the Grants page**: members of a shared grain look like
   one user to the app in v1 (one `identity_id`); Mini tells them apart by route, token and receipt,
   the app does not. Per-member guest *subjects* (one provisioned, funded subject per (grain,
   member)) are v2, scheduled when L1b's tariff says who pays for a guest's births and dispatches.
4. **START** (`grain start`), then **enroll** the guest session against the serving generation.
5. **Origin table**: `/var/lib/mini-apps/origins/a<app>.json` (0644): the grain's routes, each with
   its socket path and the SHA-256 of its three tokens. Token *hashes* are not secrets; the tokens
   stay 0600 in the route directory.
6. **Receipt** written; the request's state file (`requests/<id>.json`) moves to `running`.

**Route sockets and the front.** `spk-host grain route` places a route under the operator's 0700
state chain (`<state>/apps/<app>/routes/<name>/http.sock`) and never sets `edgeGid`, so the front
cannot reach a socket directly without widening that custody. The worker therefore serves an **edge
connector** (`STATE/edge.sock`, 0660 `mini-core:mini-edge`): the front asks `connect {grain, route}`
and receives the connected custodian socket over `SCM_RIGHTS`; the worker adds no authority (the
custodian still checks the token the browser presents) and the front still parses HTTP as
`mini-apps-edge` with `/var/lib/mini` hidden. The origin table names the connector. Groups (ruling
2026-10-27): `mini-core` is not a member of `mini-edge`; the worker's system unit carries
`SupplementaryGroups=mini-edge` (membership inside that process only, never the account) and the
worker itself creates `edge.sock` 0660 with that group and `worker.sock` 0660 with
`mini-sessions`; a group it cannot resolve is a refusal at start, never a silently private socket.

**The worker socket** (`/run/mini-apps/worker.sock`, 0660 `mini-core:mini-sessions`, peer named by
`SO_PEERCRED` exactly as `mini-keys`'s broker does): one JSON line per request, bounded 64 KiB,
verbs `install`, `retry`, `list`, `status`, `open`, `stop`, `start`, `share`, `export`, `delete`.
The uid names the member; a grain is acted on only by its owner (the birth's subject, re-read from
the Store) or a member it was shared with (for `open`). Private material flows only here: `open`
returns the member's unused bootstrap token (one use, `bootstrap.used` is the custodian's marker)
or registers a fresh route when it is consumed; `export` passes the export's file descriptor with
`SCM_RIGHTS` so no chown and no shared directory is needed.

**Decoded outcomes, never a spinner.** Every verb returns `{decided: true|false, state, exactRetry}`.
STOP is BEGIN, claim, fence, report and completion through the serial Host, minutes long
(WEB-SPK-PUBLIC §4.5; L3/hot-path shrink it): `mini apps stop` returns `undecided: stop in
progress since <t>; retry: mini apps status a<app>` and the UI shows exactly that. A failed first
START is recovered through `grain supervise` (failed-START recovery) and reported as such.

## 5. Per-grain origin and the front

Every grain gets **one fixed origin for its life**: `https://a<app>.demo.dregg.online`, `<app>`
the app resource's decimal id (DNS-safe, unique per world). Stable links, share tickets and
`__Host-` cookies are scoped per origin, so two grains, or a grain and the docuverse, never share
a browser origin (EtherCalc and the oracle appliance ride the same rule). DNS: `*.demo.dregg.online`
A/AAAA are live (infra). TLS: the one wildcard certificate (ember's ruling; hybrid then classical),
so hostnames are unbounded and there is no per-name issuance and no `ask` endpoint.

**Routing rule for Caddy: one entrance that dispatches by `Host`**, `reverse_proxy 127.0.0.1:8799`
for the whole `*.demo.dregg.online` block (`deploy/market/INSTALL.md` has the filled block). Why
not one upstream per grain: a custodian socket is per *participant* (one fixed subject, session,
ticket and token set per `custodian.json`), so a grain with two members has two sockets and the
choice between them is made by the token the browser presents, which Caddy cannot look up without
putting token hashes in its config and restarting it per share. Why not Caddy to the sockets
directly: `/var/lib/mini` is hidden from `caddy` by design and must stay so. The front:

- reads `Host` → `a<app>` → `origins/a<app>.json` (missing → 404 `no such grain`);
- selects the route whose `browserTokenSha256` matches the `__Host-mini_spk_session` cookie, whose
  `apiTokenSha256` matches a `Bearer`, or, for `POST /__mini/bootstrap` (the custodian's 128-byte
  form), whose `bootstrapTokenSha256` matches the form token; a request with none answers the
  custodian's tokenless bootstrap form for `GET /__mini/bootstrap` and a plain 403 ("private
  grain; open it with `mini apps open a<app>`") otherwise, with no Mini call and no record;
- forwards the request unchanged to `http.sock` (the custodian keeps doing every check: Host,
  Origin, cookie, `Sec-Fetch-*`, Mini admission op36/37/34), and after a 101 pumps bytes both ways
  with the 64 KiB queues and the half-close rules `spk-browser-proxy` had, which it replaces;
- bounds: 64 KiB head, the custodian's 8 MiB body, 10 s head deadline, 136 connections per grain
  (class L's 128 WebSocket slots plus eight), one thread per connection.

Opening a grain from the browser: `mini apps open a<app>` prints the origin and the one-time
bootstrap token; the member visits `/__mini/bootstrap`, pastes it, and the custodian sets the
`__Host-` cookie for that origin. L12's market pane does the same with a self-submitting form (its
session cookie on `demo.dregg.online` cannot cross to the grain origin, by design). `mini apps share
a<app> --to NAME` gives NAME their own guest participant, ticket and route (hot registration on the
running generation, 64 routes per generation); NAME then runs `mini apps open a<app>`.

### 5a. The seam with L12's browser (`/apps`, `/apps/install`, `/grain/N`)

Ember's ruling (DEMO-EXPERIENCE §1a): every shell verb has a visual face derived from the shell's
verb table. The apps verbs are one row of that table (`shell.rs` `VERBS`, name `apps`: `apps search
| show | install | retry | list | status | open | stop | start | share | export | delete |
identities | revoke-identity`), each with its arguments spelled in `usage` and its outcome shape in
`operation`, so L12's form derivation picks them up like any other verb. The seam, named:

| L12 route | the body runs (as the member's own uid, through `mini-web-spawn`, exactly a shell line) | what comes back |
|---|---|---|
| `GET /apps` | `apps search [TERM] --json` | the catalogue JSON (`{apps:[{appId, packageId, name, version, publisher, verdict:{state, reason, rawBytes, running}, suggestedClass, packageUrl}], total}`); the pane renders claims beside verdicts |
| `GET /apps/<appId>` | `apps show APP-ID --json` | one entry whole, the refusals an install can meet |
| `POST /apps/install` (fields `app`, `class`) | `apps install APP-ID [--class C]` | the decoded outcome: `request <id>` then performed (`receipt: {grain, origin, class, rawSha256, signedAppId, identityNotice}`), refused by name (`unknownApp`, `sizeOverProfile`, `unsupportedBridge`, `funding`, `birthRequired`, ...), or undecided with `exact retry: apps retry <id>` |
| `GET /grain/N` | `apps status aN --json` | state (generation, phase decoded, `running`/`stopped`/`stopping since`), the origin, the routes this member holds, **identities held by this grain** (the §3a records: who, since, revoked), the v1 notice |
| `POST /grain/N/open` | `apps open aN --json` | `{origin, bootstrapPath:"/__mini/bootstrap", bootstrapToken}` once; the body renders a self-submitting POST form to `https://aN.demo.dregg.online/__mini/bootstrap` (its own session cookie cannot cross origins, by design) and then the grain in a pane |
| `POST /grain/N/stop`, `/start`, `/delete`, `/share` (field `member`), `/export`, `/revoke-identity` (field `token`) | the matching verb | the decoded outcome; STOP is `undecided` with `exact retry: apps status aN` while the lifecycle runs |

Which uid: the member's (`mini-s-NAME`), never the gateway's; the worker names the member from the
socket peer. The receipt a form shows is the verb's `--json` reply, rendered by L12's one `outcome`
partial; the `identityNotice` field carries the v1 sentence of §4 step 3 so the Grants page says it
honestly. Nothing on these routes reaches the worker or the grain without the member's uid.

## 6. Journey row `japps.sh`

`--dry` (the Mac, no Store): the catalogue over the recorded fixture (search, show, an unknown
appId refused `unknownApp`); the two real packages fetched into a scratch quarantine by the real
fetcher, their SHA-256 prefixes equal to their packageIds, their signatures and signed appIds
verified by the stream reader's `inspect`; a tampered copy refused by name; the front started on a
loopback port against a fake route socket: cookie, bearer and bootstrap dispatch, 404 for an unknown
grain, 403 without a credential, a 101 pumped both ways.

`--box` (`dregg-build`, Debian 13, as the `lanes` user): everything `--dry` does, plus `spk-host
qualify` on four exhibits, and, when a grain world is at hand (`GRAINS_ROOT`, `BROKER_SOCKET` as
`grain-journey.sh` wants them), a scratch world through `scripts/spk-platform/grain-journey.sh`
with `SPK_A`/`SPK_B` the two market packages (birth, install, share, start, enroll, GET 200 over the
edge phase, stop one, export it). The two installs: **Hacker Slides 0.4.0**
(`7qvcjh7gk0rzdx1s3c8gufd288sesf6vvdt297756xcv4q8xxvhh`, package `f0277a5d…`, 16.8 MB) and
**Simple Todos** (`0dp7n6ehj8r5ttfc0fj0au6gxkuy1nhw2kx70wussfa1mqj8tf80`, package `5830d701…`,
23.6 MB). The two bridge-facility exhibits: **Etherpad** (`saveIdentityCaps=true`) and **Tiny Tiny
RSS** (`expectAppHooks=true`, it ships `ttrss-apphooks`); both were refused by name before
2026-10-27 and are accepted now that the facilities are served (§3a), which the row checks from
`qualify`'s `bridgeFacilities` field.

### 6a. The lane box's tooling and what it found

- `scripts/spk-platform/world-up.sh BASE_BIN OWN_BIN RUN` / `world-down.sh RUN`: one standing grain
  world on a lane box (the same ROOT SETUP, operator broker and Store phases `two-world-journey.sh`
  performs, without its teardown trap), `RUN/WORLD.env` for `japps.sh --box` (`JAPPS_WORLD_ENV`) and
  for `scripts/spk-platform/apps-e2e.sh WORLD.env OUT APP-ID…`, the first real `mini apps install`
  end to end: the workroom's subject 8 as manager, subject 9 as member, the metered references
  delegated and left in `HOME/inbox` as the frame does, the worker on its PID file, the install with
  exact retries, the origin check through the route socket.
- `scripts/spk-platform/composed-inputs.sh WORLD-IDENTITY.json CANDIDATE OUT`: the composed
  scenario's apps, connector and resident inputs derived from a jworld-scratch world through the real
  installers; it refuses `operatorPolicyRequired` while the world's genesis lacks the grain
  platform's operator policy, which is now a genesis field (`grainPlatform`, `deploy/market/INSTALL.md`
  §0; `params.sh require-platform`): rehearsal #3 is the re-genesis that carries it.
- Found on the first START on Debian 13 (2026-10-27): the stream reader's scratch-parent custody walk,
  run by the resident inside its user namespace, saw the world's root-owned ancestors as the unmapped
  overflow uid and refused every START (`resident bootstrap refused: scratch parent custody refused`).
  The wake verification now relies on the image store's own descriptor-walked custody
  (`open_protected_directory`) and calls the reader without the ancestor walk (`materialize.rs`); the
  ingest path, which runs outside the namespace, keeps the walk.

## 7. Compost

Lands as the market path lands, in this lane's commits:

- **GitWeb chain, deleted now**: the three dated probe notes `deploy/spk-host/GITWEB-*.md` (187)
  and `scripts/gitweb-content-export/` (run by nothing since 2026-09-27). The three GitWeb
  binaries and the entrance probe were already deleted by L3 on `lane/fence`; the GitWeb selection
  record and the share-issue fixtures named `gitweb-*` stay (evidence and test inputs).
- **`spk-browser-proxy`** (840 + the test certificate fixtures): deleted when `japps.sh --box` has
  served one grain through Caddy → `mini apps-front` → route socket (the W9/E1 precondition the
  review named). The front is its successor.
- **"The operator copies an .spk into the inbox by hand"**: `deploy/spk-host/README.md`'s inbox
  paragraph is rewritten to the market path; `fetch-test-spk.sh`'s pin becomes
  `mini-market-fetch --pin <packageId> <sha256>` so the M6 gate's sntfy comes through the one
  fetcher (the pin stays: the gate package is sntfy, the public apps are the market's).

## 8. What this file is not

It is not a claim that a stranger has installed an app: `japps.sh --box` on `dregg-build` and the
rehearsal ship's `apps` row say that, in that order. Performance is measured and published, not
gated (DEMO-PREFIX §1.4): the first GET through a fresh grain pays the full Mini transaction.
