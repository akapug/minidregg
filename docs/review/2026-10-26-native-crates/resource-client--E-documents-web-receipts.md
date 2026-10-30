# resource-client, shard E: documents, protected fragments, rendering, web front end, world kinds, receipts

| field | value |
|---|---|
| Shard | resource-client E ("documents, protected fragments, rendering, web front end, world kinds, receipts") |
| Crate | `/Users/ember/dev/minidregg/native/resource-client` (package `minidregg-resource-client`, binary `mini`, `Cargo.toml:9-11`) |
| Files covered | 46 Rust files plus 3 non-Rust files in `src/` (listed with line counts in section 6) |
| Total lines read | 19,133 Rust lines (`wc -l`), of which about 5,077 are `#[cfg(test)]`/`#[test]` regions (about 26.5%) |
| Date | 2026-10-26 |
| Reader | Opus reader, fan-out code review (read-only; no build or test was run) |
| Repo state | `main` at `a0db11f8` per the session's git snapshot |

## Executive summary (15 lines)

1. `mini web` (`web.rs:52-104`, reached from `main.rs:3211-3212`) is a thread-per-connection HTTP/1.1 server with no TLS. It binds only `127.0.0.1` (`web.rs:60-70,107-117`), puts every page under a 128-bit per-launch path secret (`web.rs:119-121,226-229`), and checks the Host, Origin and Sec-Fetch-Site headers (`web.rs:187-248`). A stranger on the internet cannot reach it. Anyone who holds the printed URL acts with the member's full authority.
2. The web front end is no longer read-only. The POST routes for editing, creating and the studio (`web.rs:243,599-608`) submit signed proposals through the workspace (`web/editor.rs:117`, `web/create.rs:45`). The Lean kernel admits every Host-touching mutation. Studio POSTs change only local custody, or spawn a local Lean front-end process (`web/studio.rs:206-340`). The `jweb` journey still calls the face "read-only" (`journey.d/jweb.sh:2`) and never exercises those forms.
3. Every member-authored string reaches HTML through an escaping helper. A strict CSP is also sent: `default-src 'none'`, no script (`web.rs:1003`). I found no XSS path. `web.rs:293-306` and `render/html.rs:9-22` are byte-identical escape twins.
4. Rendering (`render/*`) does not recompute visibility, backlinks or freshness. Those come from the Host's `view-document` and link-index views. Rust numbers lines, groups annotations and decorates marks. Protected-fragment "redaction" is purely cryptographic: Rust shows a fragment only if it can open it with keys the reader holds (`protected_document.rs:259-309`). Rust makes no policy decision about what to hide.
5. Concrete flaw: any co-editor can make a document unrenderable for every reader (`doc show`, web, search). They write one malformed `mini-name` link: `render/mod.rs:431-435` propagates the error that `shared_names.rs:49-93` returns. Lean admits the link, because its `sharedNameAt` checks only the scheme and uniqueness (`Kernel/ContentResource.lean:1779-1812`).
6. Concrete flaw: `doc-history` and `doc-diff` text output prints member-authored payload bytes raw to the terminal (`render/history.rs:11-92`, printed at `workspace.rs:2459-2468`). `doc show` neutralises control characters (`render/text.rs:21-40`). This is terminal-escape injection, for example an OSC 52 clipboard write.
7. Protected documents: Rust seals text and comments under epoch keys (XChaCha20-Poly1305 records signed with Ed25519; `object_messages.rs:37-95`). It wraps epoch keys per device with the shared X25519+ML-KEM-768 combiner (`object_keys_hybrid.rs:61-110`). The owner's client chooses the recipient roster. Lean authors the roster bytes, checks the roster against the catalog, and admits the freeze/resume phases (`protected_document.rs:226-248`, `object_epoch_cli.rs:196-258`). `object_keys` (custody journal) and `object_keys_hybrid` (wrap primitive) are layers, not twins.
8. The legacy whole-atom envelope `open_atom` (`protected_document.rs:762-786`) survives as a read-only twin of the authored-fragment path (`protected_atoms.rs:93-99`).
9. Receipts: Rust carries receipt state across sessions as a durable anchor `(acceptedCount, worldRoot, chain, siblings)`. A pinned local Lean verifier (`continuity-point`, `continuity-verify`) checks every hop that Host op 151 returns (`receipt_continuity.rs:494-599`). Rust adds only monotonicity checks (`receipt_continuity.rs:626-689`). Op 153, the carried exact lookup (`carry.rs:1416-1542`), agrees byte for byte with its Lean receiver (`Host/Main.lean:6735-6741`, `Host/RetainedSegmentInspection.lean:257-330`).
10. Gap: a "confirmed" outcome is anchored only as a point on the chain. Nothing proves that this call's transaction is the record at that point (`receipt_continuity.rs:843-876`). A lying Host could confirm a call it never admitted, and the client would then never retry it. `append_proof.rs:274-287` and `historical_call_receipt.rs:111-141` bypass continuity custody entirely.
11. World kinds: Rust never evaluates method bodies. The Host does, through ops 131, 132 and 134 (`world_kind.rs:415-423,516,530`). But Rust prices compute itself and hard-codes the tariff (`freeSteps == 1000000`, `creditsPerStep == 1`; `world_kind.rs:460-487`). Whether Lean recomputes the credits is an open question for the Lean side (section 8).
12. Rust alone decides several semantic conventions. Shared-name grammar and resolution: `shared_names.rs` (Lean owns only uniqueness). The room field layout: `room_schema.rs:27-55`, the roster and tariff field numbers. Formatting "carry": `protected_format.rs:119-200`; the verb `carryFormatting` does not exist in Lean. None of these grants authority, and all are law-13 candidates.
13. Dead code: `web/surface.rs` (130 lines; `surface::body` is never called) and `world_surface.rs` (200 lines; only its own tests use it) form a matched dead pair. There is also an orphaned `protected_object/source-snapshot.json` that leaks a local path.
14. No journey evidence exists under `docs/evidence` for the WEB, JDV, protected-document, continuity or world rows. The only recorded run that touches this shard is the J12 shell-docs run (`docs/evidence/2026-09-30-shell-docs`), which renders through `render/text.rs`. RECEIPT-CONTINUITY.md names a 38/38 run whose evidence lives outside the repo.
15. Minimal demo cut: about 5.4K lines are drop-only candidates: connector, lifecycle, carry, append proof, historical lookup, context, studio, and both surface modules. The protected-document stack (about 4.9K) and the web face (about 3.1K) can go for a hosted shell-only demo, with the dependency caveats in section 6.

---

## 1. What this code is and does

### 1.0 Module wiring (how each file is reached)

Every file in the shard reaches the binary through one of these declarations (verified with grep on the module tree):

| file | declared at | reachable from |
|---|---|---|
| `web.rs` | `main.rs:154` `mod web;` | `main.rs:3211-3212` `"web" => web::run(args)` (`#[cfg(unix)]`) |
| `web_admission.rs` | `web.rs:17-18` `#[path = "web_admission.rs"] mod admission;` | web only |
| `web/editor.rs`, `create.rs`, `inspect.rs`, `resident.rs`, `surface.rs`, `studio.rs` | `web.rs:16,19-21,24-25` | web routes (`surface` is unused, see 5.1) |
| `web/world.rs`, `web/search.rs` | `web.rs:22-23,26-27` via `#[path]` | web routes |
| `web_actions.rs` | `workspace/web_author.rs:8-9` `#[path = "../web_actions.rs"] pub(crate) mod actions;` | web editor action form |
| `render/mod.rs`, `html.rs`, `text.rs`, `history.rs`, `tests.rs` | `main.rs:106` `mod render;`, `render/mod.rs:16-18,546-547` | `workspace.rs` doc-show/history/diff (`workspace.rs:2413-2488,6931-6947`), web, `doc_search.rs:69` |
| `protected_document.rs` | `workspace.rs:53-54` | `workspace --action doc-protect*`, `doc-share`, `doc-revoke`, `doc-accept`, `doc-epoch-*` (`workspace.rs:6948-7006`), the shell verb `doc protect`/`share`/... (`shell.rs:90,1287-1312`) |
| `protected_document_members.rs`, `protected_rewrite.rs`, `protected_annotations.rs`, `protected_fragments.rs`, `protected_atoms.rs`, `protected_document_conversion.rs` | `protected_document.rs:12-23` (submodules `members`, `rewriting`, `annotations`, `fragments`, `atoms`, `conversion`) | protected_document only |
| `protected_format.rs` | `workspace.rs:51-52` | `workspace.rs:3143-3144` (lowering of `carryFormatting`) |
| `protected_object/object_*.rs` | `main.rs:161-177` (crate-level `object_keys`, `object_keys_hybrid`, `object_messages`, `object_cli`, `object_epoch_cli`, `object_epoch_packages`) | protected_document and members only (grep) |
| `doc_search.rs` | `workspace.rs:31-32` | `workspace.rs:6641,6649`, web search, the shell verb `doc search` |
| `app_document.rs` | `workspace.rs:9-10` | `workspace.rs:6208` (`--action app-document`), `member.rs:120` (status projection) |
| `app_lifecycle.rs` | `workspace.rs:78-79` | `workspace.rs:6268` (`--action app-lifecycle`), `member.rs:192` |
| `inspect_views.rs` | `workspace.rs:63-64` | `workspace.rs:6761` |
| `context_projection.rs` | `workspace.rs:33-34` | `workspace.rs:6656,6663` |
| `world_kind.rs`, `world_prototype.rs` | `workspace.rs:69-70,73-74` | `workspace.rs:6818-6851` and payload lowering at `workspace.rs:3119-3141,4643` |
| `world_surface.rs` | `workspace.rs:71-72` | nothing outside its own tests (dead) |
| `room_schema.rs` | `main.rs:133` | `chat.rs:848-865,2052-2191`, `credit.rs:22-24`, `member.rs:335,696`, `hermes_handoff.rs:13`, `shared_names.rs:12`, `web/resident.rs:17` |
| `shared_names.rs` | `workspace.rs:725-726` | `workspace.rs:730,922,3034,6265`; `render/mod.rs:432` |
| `append_proof.rs` | `main.rs:39` | `main.rs:3214-3215` `"operation-proof"` |
| `historical_call_receipt.rs` | `main.rs:51` | `main.rs:4199-4229` `"historical-call-receipt-lookup"`; `hermes_handoff.rs:349` |
| `receipt_continuity.rs` | `main.rs:156` | `main.rs:1900,2007,2459,2469,2527`; `workspace.rs:15,478-720,996-1023,1332-1492,4038-4045,6218-6256`; `key_rotation.rs`, `key_adoption.rs`, `participant_enrollment.rs` |
| `receipt_continuity/carry.rs` | `receipt_continuity.rs:3` | `receipt_continuity.rs:454,700,729,737`; `main.rs:2459`; `workspace.rs:6232-6245` |
| `receipt_continuity/carry/verifier.rs` | `carry.rs:4,6` | `carry.rs:267,328`; `workspace.rs:6232` |

### 1.1 Web front end

#### `web.rs` (1,292 lines; tests from line 1017)

**Process and socket.** `run` (`web.rs:52-104`) takes `--listen ADDRESS:PORT`, `--dir WORKSPACE` and an optional `--home`. `loopback_address` (`web.rs:107-117`) refuses any address other than IPv4 `127.0.0.1`: `0.0.0.0`, `[::1]`, `127.0.0.2` and the name `localhost` are all refused (tested at `web.rs:1224-1230`). After binding, `run` re-checks the address it actually got (`web.rs:68-70`). It generates a 16-byte random path secret (`web.rs:119-121`, via `fsio::random`) and prints `http://127.0.0.1:PORT/SECRET/` to stdout (`web.rs:80-83`). The secret therefore lands in any captured stdout log. Accepting is synchronous. Each connection is handed to `admission::Pool::dispatch`, which spawns a detached thread under a cap of 16 (`web.rs:92-102`, `web_admission.rs:7,30-48`). There is no TLS, no keep-alive (`Connection: close`, `web.rs:1004`) and no HTTP/2.

**Request parsing.** `serve` (`web.rs:558-623`) reads with an absolute 10-second ingress deadline (`web_admission.rs:8,54-60`) until it sees `\r\n\r\n`. The head is capped at 16 KiB (`web.rs:40,570-572`). `parse_request` (`web.rs:142-168`) requires UTF-8 and a three-token request line with an `HTTP/1.` version, and lowercases header names. Because the buffer handed to `parse_request` is the whole read and can include the first body bytes, a POST whose body arrives in the same read must also be UTF-8. That holds for urlencoded forms (flaw F12).

**The gate** (`gate`, `web.rs:187-248`, a pure function that is tested):

- The method must be GET, HEAD or POST (405 otherwise).
- There must be exactly one `Host` header, equal to `127.0.0.1:PORT` or `localhost:PORT`. Anything else gets 421. This is the DNS-rebinding guard.
- An `Origin` header, if present, must be `http://127.0.0.1:PORT` or `http://localhost:PORT` (403 otherwise). `Sec-Fetch-Site: cross-site` gets 403.
- The first path segment must equal the secret. The comparison is constant-time on equal lengths (`token_equal`, `web.rs:177-184`). A mismatch gets 404.
- Every remaining segment must be `[A-Za-z0-9-]+` (404 otherwise). This kills `..`, `%2f` and similar.
- A POST is accepted only for the routes `doc/_/edit/_`, `doc/_/edit/_/lookup`, `doc/_/edit/_/action`, `new-document/_`, `new-document/_/lookup`, `new-document/_/finish`, `studio/new` and `studio/_/{manifest,snapshot,compose,fork,preview}` (`web.rs:241-246`).

**POST handling** (`web.rs:583-609`). `editor::body_length` (`web/editor.rs:12-45`) imposes five requirements:

1. Exactly one each of `host`, `origin`, `content-type` and `content-length`.
2. No `transfer-encoding`.
3. `Origin == "http://" + Host`.
4. Content-Type exactly `application/x-www-form-urlencoded`.
5. A decimal length of at most `MAX_FORM = 196,672` (`web/editor.rs:8`).

The body is read to exactly that length under the same deadline (`web.rs:588-596`). The handler then takes `Site::mutations`, a process-wide `Mutex<()>` (`web.rs:126,597`), and dispatches. GET routes that open drafts (`new-document...`, `doc/_/edit...`, `studio/_/module/...`) also take this lock (`web.rs:612-618`), because they create custody.

**GET routes** (`route`, `web.rs:625-662`): `/` (the workspace index), `studio`, `studio/new`, `studio/ID`, `studio/ID/module/N[/fresh]`, `studio/ID/draft/S`, `studio/ID/snapshot/S[/preview/R]`, `studio/ID/history/R`, `new-document[/ID]`, `room/NAME/new-document`, `doc/NAME/inspect`, `search-hit/NAMEHEX/TARGET/ATOM/REV`, `doc/NAME`, `doc/NAME/edit[/ID]`, `doc/NAME/history`, `doc/NAME/diff/H1/H2`, `at/H/doc/NAME`, `object/NAME[/behavior]`, `board/NAME`, `room/NAME`, `room/NAME/resident`, and `stream/_`, which returns 501. `search` is routed separately at `web.rs:610`.

**Pages.** Each page is a `Page{status,title,stamp,body}` (`web.rs:251-256`). `wrap` (`web.rs:316-356`) builds the HTML shell and a "read context" header from the `Stamp` (`web.rs:259-271`): the signed read's height, authority root and cell root, or "refused", or "no signed read". `respond` (`web.rs:997-1015`) sends:

- `Cache-Control: no-store`
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Referrer-Policy: same-origin`
- `Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'; form-action 'self'; base-uri 'none'`

**Signed reads behind pages.**

- `Site::doc` (`web.rs:755-842`) calls `workspace::read_rendered`, which runs the Host `view-document` inspection over the reader's own signed reads (see `workspace.rs:1880-1990`). It adds the `links` and `backlinks` index views through `workspace::signed_view` (`web.rs:792-808`) and embeds `rendered.html(name)`, "byte for byte what `doc show --format html` prints" (`web.rs:832-834`).
- `history` (`web.rs:844-858`) and `diff` (`web.rs:860-877`) call `workspace::doc_history` and `workspace::doc_diff`.
- `board` (`web.rs:879-907`) reads the `resource` view and renders scalar fields with the board layout `render_fields` (`web.rs:500-551`: task n's state is field 2n+2 and its owner is field 2n+3).
- `room` (`web.rs:912-979`) reads `resource` and `who`. It lists the children this workspace created in the room, using the retained birth sources `sources/create-NAME.json` (`web.rs:703-709`).

**Refusal display.** `refusal_text` (`web.rs:362-369`) shows only the Host-decoded reason after `host refused ` and never prints raw frame bytes. `failure_page` (`web.rs:371-393`) maps a decoded refusal to 403 and any other failure to 502.

**Tests** (`web.rs:1017-1292`): sparse board fields, render order, links and backlinks, the refused-snapshot placeholder, history rows, scalar fields, refusal mapping, an escape and `<script>` test, loopback-only binding, the gate matrix, a "router has no submit word" grep test (`web.rs:1268-1275`, see 5.4), the creation POST allowlist and a request parse.

#### `web_admission.rs` (118 lines)

Despite the name, this file contains no Lean admission. It implements physical ingress bounds:

- `Pool` caps live connections at 16 and writes a raw `503 busy` on overflow (`web_admission.rs:12-49`). A detached thread owns a `Permit` that decrements on drop, including on panic.
- `read_ingress` (`web_admission.rs:54-60`) sets a per-read timeout equal to the time remaining before an absolute deadline, so a trickling client cannot extend its slot.

There are two tests (`web_admission.rs:74-117`).

#### `web/editor.rs` (510 lines)

This file renders the server-side editor and its POST handlers. Each handler calls into `workspace::web_author`, which lives outside this shard:

- `open` (`web/editor.rs:86-95`) calls `web_author::open` or `load`. **Every GET of `/doc/NAME/edit` creates a new `web-edits/<random>` session** (see `workspace/web_author.rs:40-70`).
- `post` (`web/editor.rs:97-139`) accepts exactly one field, `text`. It normalises CRLF to LF (`web/editor.rs:116`) and calls `web_author::submit`, which runs the pinned diff and the durable attempt. With `lookup` set, it calls `web_author::lookup`, an exact retry lookup.
- `action` (`web/editor.rs:221-245`) converts every form field to a string `Value` and calls `web_author::submit_action`. That function validates the action through `web_actions::validate` and plans it.
- `render` (`web/editor.rs:366-440`) shows the textarea (read-only once the status is `saved`, `unchanged` or `uncertain`), the receipt fields `confirmation`, `transactionId`, `eventId`, `height` and `acceptedCount` from `edit.outcome`, and four "connect knowledge" forms (`connections`, `web/editor.rs:247-268`): annotate, publish a range, transclude, link. It also shows a law and grants inspector (`inspector`, `web/editor.rs:270-364`), which issues signed `policy` and `capability` reads per grant slot and renders the predicate tree through `predicate_html` (`web/editor.rs:148-218`, nesting capped at 32). It injects `edit.structure` and `edit.preview` without escaping (`web/editor.rs:426-427`). Those strings come from `web_actions::structure`, which escapes (`web_actions.rs:207-238`), and from `rendered.html`, which escapes and is retained in the private session file (`workspace/web_author.rs:69,112-117`).
- `form` (`web/editor.rs:47-84`) is a strict urlencoded decoder. It refuses duplicates and bad escapes, and requires UTF-8. It is one of two such decoders in the shard; the other is `web/search.rs:6-24` (twin; see 5.3).

#### `web/create.rs` (114 lines)

This file creates documents through `workspace::web_create`. `GET /new-document` with no ID calls `web_create::open`, which writes a new creation session (`web/create.rs:25-34`, `workspace/web_create.rs:33-49`). `post` (`web/create.rs:35-65`) handles `create` (fields `name` and `law`), `lookup` and `finish`, the last two taking no fields. `render` (`web/create.rs:66-114`) shows the status, the room, a form while the session is `editing`, or the receipts (`birthReceipt`, `receipt`) as escaped pretty JSON. The browser form offers the laws `draft` and `note` (`web/create.rs:80`).

#### `web/inspect.rs` (158 lines)

`/doc/NAME/inspect` (`web/inspect.rs:6-125`) issues one `read_rendered` and builds a table of lines. Each row gives the atom, its "current revision" taken from the signed raw entries, transclusion source state and annotations. It also lists published ranges (`runs`) and quote bindings (`transclusions`). From each `opening` it filters the fields `source`, `run`, `from`, `to`, `pins`, `root` and `height`, and deliberately never shows payload bytes or key material (`web/inspect.rs:88-108`). Annotations are escaped (`annotation_html`, `web/inspect.rs:126-139`).

#### `web/resident.rs` (179 lines)

`/room/NAME/resident` (`web/resident.rs:6-99`) reads the room's `resource` view. It finds the Hermes assignment fields by name through `room_schema::TARIFF_FIELDS` (`web/resident.rs:16-27`). With `--home`, it constructs a `shell::Session` and calls `chat::room_feed`. It then renders the member's own requests and the resident's replies through `hermes::request_rows` (`web/resident.rs:100-135`). Only entries whose author is the assigned resident and that reply to the exact `(cell, sequence)` are shown, so forged status from other authors is excluded (tested at `web/resident.rs:139-178`). It can show a resident account's `balances` when the reader holds a reference to that account (`web/resident.rs:75-88`).

#### `web/world.rs` (191 lines)

`/object/NAME[/behavior]` (`web/world.rs:4-38`) renders the `worldInstance` or `worldKind` projection from the signed `resource` view: descriptor kind and revision, pinned `kindRoot`, field values (bytes are decoded to text only if they contain no control characters), method tables, field meanings, `sampleSlots`, `definitionBytes`, `construction`, `trace` and the full record as escaped JSON. The behavior face also reads `policy` (`web/world.rs:12-18`). `board` uses `world::body` first (`web.rs:887`).

#### `web/search.rs` (256 lines)

`GET /search?query=&scope=&offset=&cursor=` (`web/search.rs:84-198`) accepts only those four fields, each at most once, with the query string capped at 8,192 bytes (`web/search.rs:25-42`). It calls `doc_search::search` and renders hits, coverage notes, locked-text notes and the next-page form with `cursor = collectionFingerprint`. `search-hit` (`web/search.rs:199-237`) hex-decodes the name and calls `doc_search::follow`. `unavailable_hit` (`web/search.rs:70-82`) classifies errors by substring.

#### `web/studio.rs` (359 lines)

This file is the browser face of `workspace::studio`, which lives outside this shard:

- package index, new, render, composition controls, history, module editor, captured snapshot, retained drafts (`web/studio.rs:10-205`);
- POST `new`, `preview`, `fork`, `compose`, `snapshot` and `manifest` (`web/studio.rs:206-340`).

Studio state is local custody. Publish, instantiate and evolve are permanently rendered disabled (`web/studio.rs:52`). `snapshot` performs signed reads of the module documents (`workspace/studio_preview.rs:55-63`). `preview` spawns `timeout --kill-after=2s 45s HOST /dev/null objective-front ...`, the Host's Lean Objective Bend front end, only when `MINIDREGG_STUDIO_PREVIEW_CONFIG` is set (`workspace/studio_preview.rs:10,27-30,65-75`; `web/studio.rs:89-91,249-255,342-345`).

#### `web/surface.rs` (130 lines)

This is a renderer for "authored Objective Bend surfaces" (`web/surface.rs:12-93`): bounded traversal (4,096 expansions, depth 64, 2 MiB of HTML) with operation links supplied by the server only. **Nothing calls `surface::body`.** The only reference is the declaration `mod surface;` at `web.rs:24` (grep `surface` across `web.rs` and `web/*.rs`). It is dead, apart from its two tests (5.1).

#### `web_actions.rs` (302 lines)

This file holds the authored connections over the editor's retained base. `validate` (`web_actions.rs:14-63`) enforces exact key sets for the four actions:

| action | keys |
|---|---|
| `annotate` | `type, line, text` |
| `range` | `type, from, to` |
| `link` | `type, to, relation` |
| `transclude` | `type, source, from, to, mode, death` |

`plan` (`web_actions.rs:131-204`) lowers each action to a `minidregg-workspace-proposal-v1` invoke:

- **annotate** (`annotated`, `web_actions.rs:69-87`) uses the line's atom and the revision of the raw signed entry, with a random annotation ID.
- **range** produces `createRun` over `line_atoms`.
- **link** issues a signed `resource` read of the target to choose the target type. If the target is content, it adds a `read` target to the same turn.
- **transclude** (`transclusion`, `web_actions.rs:89-129`) finds a published `run` containing both endpoints and pins every live atom of the run slice with its revision. It adds a `read` target on the source.

All IDs (`annotation`, `run`, `link`, `transclusion`) are client-generated random nonces (`web_actions.rs:84,125,152,170`). `structure` (`web_actions.rs:207-238`) renders the base's lines and runs as escaped HTML.

### 1.2 Rendering (`render/`)

#### `render/mod.rs` (555 lines)

This is the "one document renderer" (`render/mod.rs:1-14`). Its input `View` (`render/mod.rs:25-38`) has five parts:

- `document`: the Host `view-document` output, already patched by `workspace::rendered_document` for snapshot `at` re-reads; see the seam note below.
- `entries`: the signed cell entries, already decorated by `opened_entries` with a `private` field when a protected fragment opened.
- `names`: the reader's reference names.
- `sources`: per-source line numbers from the reader's own source reads.
- `me`: the reader's own subject.

The data model is `Deco` (Code, Italic, Bold, Link, Heading, each with a `stale` flag), `Body` (Text, Object, Transclusion, Section), `Transcluded`, `Annotation`, `RenderedLine`, `OutlineEntry`, `Backlink` and `Rendered` (`render/mod.rs:40-122`).

`render` (`render/mod.rs:315-446`) does five things:

- Walks `document.order` and computes depth from parent depth.
- Numbers live lines locally: struck atoms and sections get no number (`render/mod.rs:347-361`).
- Picks each atom's body. In order: an opened private text or binary; a locked or unsupported private kind; an `inlineObject` label; non-UTF-8 as `[binary N]`; otherwise text (`render/mod.rs:362-393`).
- Attaches annotations by `anchor.atom`, with document and legacy-mark annotations kept separately (`render/mod.rs:325-341`).
- Renders transclusions through `transcluded` (`render/mod.rs:226-312`). That function derives the header text from the Host's `render.view` (`snapshot`, `live`, `unavailable`, `moved`, ...) and from `atRefused`. Lines are kept only when the view is `snapshot` or `live`.

`decos` (`render/mod.rs:143-167`) collapses marks per kind: a kind is stale only when every mark of that kind is stale, using the Host's `fresh` flag. The outline is the non-stale heading lines (`render/mod.rs:419-429`). Shared-name bindings are collected from the entries through `shared_names::binding(entry)?` (`render/mod.rs:430-436`). **The `?` makes one malformed binding fail the whole render** (F2). The formats are `raw` (`render/mod.rs:472-484`), `json` (`render/mod.rs:488-515`), `text` and `html`.

`decode_hex` (`render/mod.rs:169-171`) returns empty bytes on malformed hex, so a bad Host payload renders as an empty line (F11). `history.rs` handles the same case with a diagnostic instead.

**Seam note (outside this shard, but the renderer consumes it).** `workspace.rs:1926-1972` rewrites a snapshot transclusion's `render` to `{"view":"moved",...}`, with `atRefused`, when the Host refused the `at`-height source read. It also replaces transclusion lines with text the reader can open locally (`project_transclusion_source`, `workspace.rs:1744-1790`). Both are presentation of a Host decision (the refusal) and of cryptographic openability; neither is a policy choice.

#### `render/html.rs` (301 lines)

This is the semantic HTML backend. `escape` (`render/html.rs:9-22`) escapes `& < > " '` and is identical to `web::escape` (`web.rs:293-306`). Every body, name, ID, author and annotation passes through `escape`. Link marks carry only `data-target` (the reader's name) and no URL (`render/html.rs:38-51`). Row attributes include `data-element/kind/line/atom/creator/revision/struck/marks` (`render/html.rs:100-131`). Empty section rows are skipped so they do not consume list numbers (`render/html.rs:166-174`).

#### `render/text.rs` (191 lines)

This is the text notation for `doc show` and `doc outline`. `one_line` (`render/text.rs:24-40`) maps `\n` to `␤`, `\r` to `␍`, ASCII controls to Control Pictures (U+2400+), DEL to `␡`, and other Unicode controls to `\u{..}`. It is applied to bodies, link targets and annotations, and once more over every output line (`render/text.rs:116-120`). An exhaustive test runs every Unicode control through it (`render/text.rs:143-153`).

#### `render/history.rs` (160 lines)

This file renders history and diff in text and HTML over the Host's `view-history` and `view-diff`. `payload_text` (`render/history.rs:11-17`) decodes lossily; on malformed hex it returns a `<payload ..>` diagnostic. `diff_text` and `history_text` (`render/history.rs:52-92`) **do not apply `one_line`** (F1). The HTML forms escape (`render/history.rs:96-151`). `null` changes mean "your grant did not cover this document at that height", and the text says so (`render/history.rs:49,64,88,112`).

#### `render/tests.rs` (286 lines, all test)

These tests run on real `inspect view-document` fixtures from journey runs. The fixture files are `tests/fixtures/render/k12m-fifty-marks...`, `k12t-*`, `k12e-sections...` and `j12r-rpaper.json`, plus the golden file `journey.d/j12r.golden.txt` (`render/tests.rs:9-18,181-207`).

### 1.3 Protected documents

#### `protected_document.rs` (1,214 lines; tests from line 802)

These are the owner and member client operations for documents whose current text is sealed to an object audience, also called an epoch.

- **Constants and binding.** The frames are `MINI/PROTECTED-DOCUMENT-ATOM/v1`, `MINI/OBJECT-MESSAGE/v1` and `MINI/PROTECTED-DOCUMENT-ATOM-OP/v1` (`protected_document.rs:25-27`). Two kinds are recognised: the legacy inline object schema `decimal(SHA256(FRAME))`, and the authored-text sealed kind (`is_kind`, `protected_document.rs:39-43`).
- **`Audience`** (`protected_document.rs:53-134`). It is built only by `from_checked`, which joins two values. The first is a Host `object-audience` view (`type == minidregg-object-audience-v1`, `active == true`). The second is a Host `object-audience-roster` result (`minidregg-checked-object-roster-v1`) whose `audienceState`, object, epoch and transition match. `bind_target` stamps `audienceEpoch` and `audienceRoster` into the signed target and refuses a mismatch in target, root or world (`protected_document.rs:86-97`). `seal_actions` (`protected_document.rs:100-133`) classifies each content action with `content_privacy::classify`, which is outside this shard. Text creates and edits are sealed through `atoms::seal`, comments through `annotations::seal`, and rewrap maintenance through the same helpers. Tombstones must preserve the old ciphertext exactly (`protected_document.rs:117-122`), and unsupported exposures are refused (`protected_document.rs:108`).
- **`observe`** (`protected_document.rs:226-248`) runs `host_files object-audience` (Host op 8, the session kind) and `object-audience-roster` (op 8 with four nested pairs) and returns an `Audience`.
- **Custody.** The files are `protected-documents/keys.json` (an encrypted journal) and `storage.key` (`protected_document.rs:162-169`). `ensure_custody` refuses to re-create a lost key or journal (`protected_document.rs:170-195`). It writes `custody.json` describing backup scope.
- **`opened_entries`** (`protected_document.rs:259-309`) never mutates the signed view. It adds `private: {text|hex}` or a locked string to each sealed annotation or atom. It enforces the atom-version monotonicity history in `protected-documents/atom-versions-OBJECT.json` (`protected_document.rs:263-307`; see `protected_atoms.rs:79-92`).
- **Enrollment.** `protect_empty` and `protect_current` lead to `protect` (`protected_document.rs:386-425`), then `continue_enrollment` (`protected_document.rs:429-512`), then `recover`/`recover_phase` (`protected_document.rs:516-581`), then `finish_enrollment` (`protected_document.rs:595-675`). The sequence is:
  1. Retain an immutable stage containing a random transition, operation and catalog nonces, plus the device publication.
  2. Create a catalog content cell (`super::create`).
  3. Have the Host author the roster and catalog bytes (`retain_authored`, which calls Host op 7 with the kinds `object-audience-roster` and `object-device-catalog`).
  4. Write the catalog atom 0 through a prepared intent (`protected_document.rs:472-485`).
  5. Run the `enroll` phase through `object_epoch_cli::run`.
  6. Confirm `audienceState.manifest == decimal(SHA256(epoch-manifest.bin))` (`protected_document.rs:605-608`).
  7. Publish either a "readiness" `createContainer` turn (empty mode, `protected_document.rs:645-664`) or the conversion (`conversion::finish`).
- **Epoch bundles.** `export_epoch` (`protected_document.rs:680-707`) and `import_epoch` (`protected_document.rs:712-752`) move the signed manifest, the operation, the writer and the roster bytes. The importer re-checks the roster through the Host (`protected_document.rs:730-732`), then `object_cli::receive_epoch`.
- **Legacy reader.** `open_atom` (`protected_document.rs:762-786`) reads the old v1 whole-atom envelope. `reject_fresh_legacy` (`protected_document.rs:790-800`) refuses new plaintext into legacy (room-key) private documents.

#### `protected_document_members.rs` (572 lines; tests from line 500)

These are recoverable membership changes, `doc-share` and `doc-revoke` (`change`, `protected_document_members.rs:70-126`). They are owner-only: the owner cannot target itself, and a control capability is required. Each change is staged in `membership/CHANGE/change.json`.

- **Roster check before freezing.** Local custody must equal the admitted roster (`protected_document_members.rs:109-111`). Share requires a validated device; `validate_device` checks the commitment and that a wrap works (`protected_document_members.rs:54-69`). The cap is 4,096 devices (`protected_document_members.rs:106-108`).
- **`recover_locked`** (`protected_document_members.rs:286-380`):
  1. Share: delegate document and catalog grants to the recipient (`delegate`, `protected_document_members.rs:153-168`). Revoke: revoke every standing grant of the subject on the document and catalog, enumerated by `standing_grants` (`protected_document_members.rs:328-336`).
  2. Freeze phase.
  3. Epoch plus one; author the roster and catalog; edit catalog atom 0.
  4. Resume phase with the new recipients.
  5. Switch `current-epoch.json`.
  6. `publish_current`, which rekeys current text and comments through `rewriting::current`, then posts a `createContainer` publication turn.
- **Retry discipline.** `action` (`protected_document_members.rs:130-152`) derives a deterministic proposal ID per `(namespace, label, generation)`. It retries the exact retained call if `call.bin` exists. It moves to the next generation only after `attempt_definitely_unadmitted`, or when a proposal directory exists with neither an intent nor a call. `phase` (`protected_document_members.rs:187-279`) settles rejected generations in custody and retires unemitted phases whose authority CAS moved (`protected_document_members.rs:211-229`). `drain_posts`, `post_unadmitted` and `next_post` scan retained label files (`protected_document_members.rs:384-423`).
- **Invitations.** `export_share` and `accept` (`protected_document_members.rs:465-498`) build an invitation bundle and accept it.

#### `protected_rewrite.rs` (310 lines)

This is the durable re-encryption of current text and comments to a target epoch (`current`, `protected_rewrite.rs:201-252`). It runs up to 4,096 rounds. Each round re-reads the rendered document, plans up to 64 atom or annotation rewraps, retains `rewrite-plan-N.json`, and submits through `members::action`. Before the first round it replays retained plans (`protected_rewrite.rs:205-215`). `restore` (`protected_rewrite.rs:140-199`) repairs mark and link "carry" after each accepted rekey. It runs up to 128 rounds of 64 `carryFormatting` requests and writes conflict evidence `format-conflict-*.json` when competing edits invalidate a plan (`protected_rewrite.rs:102-106`). Plaintext appears in a plan only for previously public text atoms that are being converted (`planned_atom`, `protected_rewrite.rs:27-35`).

#### `protected_format.rs` (333 lines)

`lower` (`protected_format.rs:119-200`) turns client `carryFormatting` rows `{sourceMark, mark, atom, revision, link?}` into ordinary content `mark` actions. It copies the kind or link target from the signed source mark, after checking the following:

- the atom and the source mark are live and in the same document;
- the anchor is exact;
- `fresh` agrees with the revision;
- the old link record is live and has a canonical witness;
- the new IDs are unoccupied;
- the batch has 1 to 64 rows.

The module comment says it "establishes no authority and encrypts no text" (`protected_format.rs:3-8`). It is called at `workspace.rs:3143-3144`. Lean has no `carryFormatting` verb (grep of `Host/` and `Kernel/` returns nothing).

#### `protected_fragments.rs` (68 lines)

This is the shared immutable authored-fragment custody. The ciphertext is `FRAGMENT ‖ binding ‖ nonce ‖ object-message`, sealed under a fresh content key (`seal`, `protected_fragments.rs:32-41`, through `Store::prepare_fragment`). The wrapping is `WRAP ‖ nonce ‖ object-message(content key)` under the epoch key (`wrap`, `protected_fragments.rs:26-31`, through `Store::prepare`). `key` and `open` (`protected_fragments.rs:15-25,57-63`) recompute the operation digest from the binding and nonce and check the context. Author and operation placeholders (`subject "0"`) are normalised by the receiving actor at the source (`protected_fragments.rs:37-40`).

#### `protected_atoms.rs` (100 lines)

The protected text kind uses schema `decimal(SHA256("MINI/PROTECTED-AUTHORED-TEXT/v1"))` (`protected_atoms.rs:14-18`). The binding is `tag 2 ‖ atom(32) ‖ seq(8) ‖ prev(32)` (`protected_atoms.rs:3-12,23-34`). Its version rules are:

- `next_version` gives seq 0 at create; otherwise prev is the before-revision, and seq is the predecessor's seq plus one, or 1 for a converted public atom (`protected_atoms.rs:40-49`).
- `check_current`: a live record is "edited" when `revision != createdAt`, and that must agree with `seq != 0` (`protected_atoms.rs:67-74`).
- `advance` keeps the reader's last-seen version from moving backwards. It refuses rollback, equivocation and a predecessor skip (`protected_atoms.rs:79-92`).

#### `protected_annotations.rs` (20 lines)

The comment binding is `tag 2 ‖ annotation ‖ atom ‖ revision` (`protected_annotations.rs:3-5`). This file provides seal and rewrap for `annotate`/`rewrapAnnotation` and an `open` (`protected_annotations.rs:6-20`).

#### `protected_document_conversion.rs` (74 lines)

This file handles prospective conversion of a document that already has public text. `snapshot` retains a `mini-current-text-conversion-basis-v1` containing the signed observation bytes and an exposure statement (`protected_document_conversion.rs:8-22`). `preflight` keeps the first basis (`protected_document_conversion.rs:24-34`). `finish` publishes the current-text rekey under a derived namespace (`protected_document_conversion.rs:36-52`).

### 1.4 Protected object custody (`protected_object/`)

#### `object_messages.rs` (123 lines)

This is the record format `FRAME ‖ object(32) ‖ epoch(8) ‖ transition(32) ‖ operation(32) ‖ law(32) ‖ writerPub(32) ‖ nonce(24) ‖ XChaCha20-Poly1305(plain, aad = header) ‖ Ed25519(writer, everything before)` (`object_messages.rs:13-35,37-64`). `open` checks the length bound (1 MiB of plaintext), the exact context bytes, the expected writer, `verify_strict`, and the AEAD (`object_messages.rs:65-95`).

#### `object_keys_hybrid.rs` (201 lines)

This is versioned hybrid key transport, the "wrap" primitive. It calls `hybrid_kem::encapsulate` and `decapsulate` (`native/hybrid_kem.rs`, included at `main.rs:88-89`) under suite `DREGG.OBJECT-KEYS.KEK/x25519+ml-kem-768/v2` and frame `MINI/OBJECT-KEYS.WRAP/v2`, with transcript parts `(context bytes, device generation)`. It boxes the 32-byte epoch key with XChaCha20-Poly1305 (`object_keys_hybrid.rs:16-21,61-110`). `key_commitment = SHA256("MINI/OBJECT-DEVICE/v2" ‖ 1216-byte public)` (`object_keys_hybrid.rs:116-122`). Pre-hybrid `kemPublic/dhPublic` shapes are refused by name (`object_keys_hybrid.rs:32-39`). **This is a layer below `object_keys`, not a twin**: `object_keys::Store` keeps custody and calls this module for wrapping (`object_keys.rs:187-188`).

#### `object_keys.rs` (757 lines; tests from line 523)

`Store` is an encrypted JSON journal at `protected-documents/keys.json`, protected by `XChaCha20-Poly1305(storage.key)` with frame `MINI/OBJECT-STATE/v1` and a 32 MiB cap (`object_keys.rs:20-21,60-121`). It holds an advisory `service_lock` on `keys.object-lock` (`object_keys.rs:61-62`). The state contains:

- `keys`: `object:epoch:transition` → epoch key (hex);
- `pending`: operation → staged epoch, control phase, or exact emitted message wire;
- `fragments`: operation → `{context, wire, plainHash, writer, key}`;
- `anchors`: the audience high-water mark per object;
- `devices`: generation → `{hybridSecret, hybridPublic}`.

`Drop` zeroises every JSON string (`object_keys.rs:38-50`). Exact retry is enforced by `prepare` (`object_keys.rs:234-272`) and `prepare_fragment` (`object_keys.rs:276-303`). Both return the retained wire for the same operation, plaintext hash, writer and context, and refuse anything else. `reconcile_anchor` refuses epoch regression, reactivation of a frozen epoch, and a conflicting transition (`object_keys.rs:126-155`). `settle` installs an accepted epoch key and advances the anchor without rewinding (`object_keys.rs:448-520`).

#### `object_epoch_packages.rs` (416 lines; tests from line 236)

`prepare` (`object_epoch_packages.rs:33-95`):

- requires the dealer to be one of the recipients;
- accepts 1 to 4,096 recipients and a roster of at most 4 MiB, with no duplicate `(subject, deviceSource, generation)`;
- requires `key_commitment(public) == key_commitment` for every recipient.

It then generates a fresh epoch key, wraps it for each device, and signs the canonical JSON manifest. The manifest is `codec MINI/OBJECT-EPOCH/v2, context, audience, devices, history, authoritySnapshot, deviceSnapshot, dealer, dealerGeneration, writer, packages[], rosterBytes`, framed as `u64be length ‖ unsigned ‖ Ed25519 sig`; the commitment is SHA-256 of the whole. `receive` (`object_epoch_packages.rs:100-234`) checks four things:

- the admitted commitment;
- the framing, the signature and canonical re-serialisation;
- that every context field equals the source except the law, which is recovered from the signed manifest;
- the 12 keys, the package fields, and the dealer's presence.

It then picks this device's package, checks its key commitment, and unwraps it. v1 manifests are refused by name.

#### `object_epoch_cli.rs` (528 lines; tests from line 427)

`run` (`object_epoch_cli.rs:100-365`) authors an `enroll`, `freeze` or `resume` audience phase. It builds the next audience state from the authenticated `view.sourceRecord`:

- enroll: epoch 0, mode active;
- freeze: parent becomes transition, mode frozen;
- resume: epoch + 1, mode active, new audience, devices and history (`object_epoch_cli.rs:159-191`).

For every phase except freeze it then:

- has the Host inspect the roster (`object-roster-inspect`);
- authorises a catalog observation;
- has the Host check `object-audience-roster` against the source observation and the catalog (`object_epoch_cli.rs:196-258`);
- has the Host author and inspect the planned `policy` (`inspect_policy`, `object_epoch_cli.rs:35-42`);
- builds the context with the policy's `semanticLawDigest`;
- checks that the package list equals the authenticated roster (`object_epoch_cli.rs:284-313`);
- runs `prepare`.

It then stages the key, the manifest and the intent JSON in the journal before any authoring or publication (`object_epoch_cli.rs:352-360`), materialises `phase-intent.json`, `phase-intent.bin` and `epoch-manifest.bin` (`materialize_phase`, `object_epoch_cli.rs:54-71`), and calls `retry`. `retry` (`object_epoch_cli.rs:368-412`) either re-sends the retained exact call (`crate::retry`) or submits `phase-intent.bin` as a binary intent, then calls `settle(op, true)`. `device` (`object_epoch_cli.rs:416-425`) provisions a hybrid device and publishes only public material.

#### `object_cli.rs` (230 lines)

`receive_epoch` (`object_cli.rs:68-116`) parses the source Nats losslessly (`source_bytes`, `object_cli.rs:13-34`). It loads the device from custody. If the request JSON carries `hybridSecret`, it takes the secret from the request instead (`object_cli.rs:75-79`, flaw F10). It derives the epoch view (a frozen view uses the parent transition), calls `object_epoch_packages::receive`, reconciles the anchor, and retains the key.

#### `protected_object/source-snapshot.json` (1,460 bytes, not Rust)

This is a provenance record of a port from `/Users/ember/workbox/mini-private-objects-20261002/...`, giving SHA-256 hashes of six files. Nothing reads it (grep across `native/` and `scripts/`). It is an orphan, and it contains an absolute local path (5.1).

### 1.5 Receipts

#### `receipt_continuity.rs` (1,470 lines; tests from line 1017)

This is durable custody of a verified world point under `WORKSPACE/receipt-continuity/`, containing `enabled.json`, `anchor.json`, `lock` and, after a carry, `carry-*.json`, `capsules/` and `lineages/` (`receipt_continuity.rs:19-22`).

- **Settings and anchor.** Settings hold the identity `{algorithm minidregg-continuity-v1, domain, semantics, expectedSeed}`, the verifier path, and the verifier's SHA-256 (`receipt_continuity.rs:209-255`). `Settings::check` re-hashes the verifier image and re-profiles the identity (`receipt_continuity.rs:246-254`). Profiles are cached per `(path, sha, config bytes)` (`receipt_continuity.rs:262-286`). The anchor is `{identity, point{height, worldRoot}, chain, siblings}` (`receipt_continuity.rs:305-331`). Every custody file must be owner-private, opened with NOFOLLOW, regular, and not hard-linked (`receipt_continuity.rs:109-161`). Writes use `mini_sdk::durable::replace_with` with a check that the directory inode has not changed (`receipt_continuity.rs:182-207`).
- **`begin`** (`receipt_continuity.rs:422-474`) reads the durable manifest. It refuses if enablement disappeared, recovers a pending carry, checks the host/config pins, loads settings, and captures a baseline anchor. A legacy workspace prints a one-time notice and returns `None`.
- **`HostProof`** (`receipt_continuity.rs:479-615`) sends Host op 151 over the pinned socket (`session_invoke(..., 151, query)`, `receipt_continuity.rs:602-614`). It verifies each response with the pinned local Lean verifier, `continuity-verify REQUEST RESPONSE VERIFIED` (`receipt_continuity.rs:560-599`). `challenge_point` converts a signed read's challenge into a point through `continuity-point` (`receipt_continuity.rs:494-517`).
- **`walk`** (`receipt_continuity.rs:626-653`) paginates up to 4,096 hops with monotonicity checks. `finish_locked` (`receipt_continuity.rs:654-689`) behaves as follows:
  - refuses an ordinary read below the baseline;
  - refuses a same-height fork;
  - proves older targets as a prefix of the current anchor;
  - advances the anchor hop by hop toward newer targets (persisting each verified hop);
  - refuses a historical target newer than the anchor.
- **Attempts.** `begin_attempt` and `finish_attempt` (`receipt_continuity.rs:778-876`) bracket every workspace submit and retry (`main.rs:1900,2007,2469,2527`). A confirmed outcome's `(acceptedCount, worldRoot)` is the target. `receipt_mode` decides between Ordinary and ReceiptReplay from the outcome's `confirmation` (`receipt_continuity.rs:830-841`). Failure after a mutation yields "receipt acknowledgment refused, but mutation may already be accepted; retain the exact attempt and recover by lookup" (`receipt_continuity.rs:875`).
- **Other entry points.** `initialize` (`receipt_continuity.rs:878-934`) is the only first trust: it bootstraps from one complete verified hop over a signed read. `replace_verifier` (`receipt_continuity.rs:936-979`) re-pins an upgraded verifier that must accept the retained anchor. `check_retained` (`receipt_continuity.rs:980-1015`) checks a retained read. `key_source` (`receipt_continuity.rs:363-419`) runs a closed set of five verifier `inspect`/`author` kinds for key adoption and rotation, all under the custody lock.

#### `receipt_continuity/carry.rs` (1,542 lines; tests from line 647)

This file migrates a workspace from one deployment identity to the next, with the operator's authorisation:

- **`pin_authority`** (`carry.rs:146-166`) records an operator Ed25519 public key (64 lowercase hex characters) and snapshots a "capsule". `register_capsule` (`carry.rs:391-435`) copies the current verifier, the `signatureBinary` named in the config, the config itself, and the verifier's profile.
- **`migrate`** (`carry.rs:219-364`):
  1. Runs the selected carry verifier: the installed portable verifier, or the old Host. The call is `carry-edge-verify request.json verified-edge.json` (`carry.rs:285-296`).
  2. Binds the result to the locally chosen target: identity, the same domain and seed, the operator key, the target binary digest, and `cut ≥ retained` with `start = cut + 1` (`check_result`, `carry.rs:167-197`).
  3. Proves `pinned → retained → cut` with op 151 through `CarryProof` (`carry.rs:318-325,605-645`).
  4. Writes the transition and a WAL, then calls `recover_locked`, which applies settings, anchor, manifest and authority in order and is crash-safe (`carry.rs:58-115`).
- **History.** `history` (`carry.rs:483-524`) follows the committed lineage chain backwards. `historical_challenge` and `finish_historical_locked` (`carry.rs:550-601`) verify old-segment reads and receipts with the archived verifier.
- **Op 153.** `retry_lookup` (`carry.rs:1416-1542`) intercepts lookups of old-lineage attempts only, and allows only a lookup. It sends op 153 with `u32le(len) ‖ {"algorithm":"minidregg-carried-call-lookup-v1","originIdentity":...} ‖ raw call.bin`, after bounding the call with `retained_call` and `lookup_payload` (`carry.rs:1268-1322`). It retains the frame before parsing it (`carry.rs:1503-1518`). `lookup_outcome` validates the response (`carry.rs:1323-1413`): exactly four top-level fields; outcome `confirmed` with exactly six fields and `confirmation == replayed`, or `absent`, or `refused` with one of five reasons; and an accepted count inside the origin segment `[lower, cut]`. It then calls `finish_attempt(..., replay=true)`.

#### `receipt_continuity/carry/verifier.rs` (402 lines; tests from line 173)

`install` (`verifier.rs:50-125`) handles explicit installation of a portable carry verifier. It checks a caller-supplied SHA-256, executes `carry-verifier-profile` and requires a description that exactly equals `{algorithm minidregg-carry-verifier-v1, identity, sourceCapsulePins, edgeAlgorithm}`. It writes the marker into `workspace.json` before `carry-verifier.json`. `select` (`verifier.rs:128-171`) refuses a missing pin once the marker exists, refuses a pin without the marker, and re-hashes the executable.

#### `historical_call_receipt.rs` (214 lines)

`lookup_verified` (`historical_call_receipt.rs:72-142`) is a recipient-side exact lookup. It takes `call.bin` and four expected fields. It retains the call and a marker, sends op 3 over the pinned socket, and retains the reply frame. It re-checks the host image, the config and the call, inspects the outcome by running the Host process directly (`inspect_direct`, `historical_call_receipt.rs:38-57`), and requires a `confirmed/replayed` outcome whose four fields equal the expected ones (`exact_receipt`, `historical_call_receipt.rs:14-32`). It is used by `mini historical-call-receipt-lookup` (`main.rs:4199-4229`) and by Hermes handoff (`hermes_handoff.rs:349`).

#### `append_proof.rs` (451 lines)

`mini operation-proof` (`main.rs:3214-3215`, `append_proof.rs:372-377`) produces "proof that one retained ordinary room say was accepted" (`append_proof.rs:1-4`). `prove` (`append_proof.rs:161-370`):

1. Loads the private operation record, which must be canonical and private.
2. Checks the workspace identity and config hash (`identity`, `append_proof.rs:38-48`).
3. Requires the attempt to sit directly under `attempts/` with the name `a-NONCE`.
4. Checks the transport binding (`append_proof.rs:115-129`).
5. Checks that the recorded request matches the retained intent: same subject, stream, capability, reply ref and topic, with the hex payload equal to the say text (`statement`, `append_proof.rs:52-113`).
6. Re-authors the command through the Host (op 7, kind `resource`) and compares it with the retained plan's `finalizedDraft.command` (`append_proof.rs:236-257`).
7. Re-assembles the retained signatures into the same call through op 11 (`append_proof.rs:258-273`).
8. Looks up through op 3 (`append_proof.rs:274-287`).
9. Re-checks that no input changed, hashes every artifact, and writes `proof.json`. Failures write `failure.json`.

### 1.6 World kinds, applications and inspection

#### `world_kind.rs` (630 lines)

- **Definitions.** `definition` (`world_kind.rs:43-116`) checks the kind source: exact keys; `revision`; fields with unique IDs and names, a non-empty meaning, codec `nat`/`int`/`bytes`, and discipline `rom`/`ram`/`append`; defaults typed by codec; a method table only at key 0 of a `dregg/world/method-table/v1` ROM bytes field. `method_table` (`world_kind.rs:383-413`) requires unique names and programs, and outputs only to writable numeric fields.
- **Named edits.** `show` (`world_kind.rs:137-151`) retains the signed view in `seen/world-NAME.json`. `named_actions` and `lower_named` (`world_kind.rs:155-225`) turn field-name set/erase into `world` actions, with the exact old value taken from the seen view.
- **Revisions.** `revise` (`world_kind.rs:227-237`) requires a strictly increasing revision.
- **Birth.** `create` (`world_kind.rs:239-309`) births a kind or an instance. A retained request keeps the originally selected kind under exact retry.
- **Methods.** `call` (`world_kind.rs:491-551`):
  1. Reads the instance and finds the method in its table.
  2. Asks the Host for the program ABI (op 132, `NOCK_PROGRAM_SHOW`).
  3. Builds sample values from the signed `sampleSlots`.
  4. Asks the Host to evaluate (op 134, `NOCK_DRY_RUN`).
  5. Maps output writes through the table (`method_actions`, `world_kind.rs:427-447`).
  6. Optionally prices compute (`compute_consent`, `world_kind.rs:460-487`).
  7. Proposes a turn carrying `run{programId, sample, output, steps}`.
- **Programs.** `program_create` (`world_kind.rs:603-630`) has the program checked with op 131 and births a `nock` cell.

#### `world_prototype.rs` (126 lines)

`construct` (`world_prototype.rs:31-106`) builds a kind definition from 1 to 15 parent kinds through a constructor program:

1. Reads every participant at one world root (`world_prototype.rs:63-75`).
2. Asks the Host for the ABI (op 132).
3. Selects the sample slots; the destination never sees the parent-only `kind/definition/noun` slot (`world_prototype.rs:6-16`).
4. Dry-runs the program (op 134).
5. Asks the Host to decode the output (op 8, kind `world-prototype-output`).
6. Proposes `kindDefinition` with `kindRead` guards on the parents.

#### `world_surface.rs` (200 lines)

This module parses an Objective Bend `Surface` and an `Intent` (`world_surface.rs:83-133`) and projects admitted observations and prepared intents into nodes (`world_surface.rs:138-159`). **Nothing outside its own tests uses it** (grep for `Surface::parse`, `AdmittedObservation` and `PreparedIntent`). It is dead, and it pairs with the dead `web/surface.rs`.

#### `app_document.rs` (1,072 lines; tests from line 806)

This is the "connector": it pulls an EtherCalc sheet export into a Mini document. The shell form is `doc app-export capture|publish|status|recover|rebase` (`shell.rs:90`); the workspace form is `--action app-document` (`workspace.rs:6208`).

- **Binding.** `validate` (`app_document.rs:35-130`) checks a 21-key binding: the subject must be the member; there are app, package, task and document references; the endpoint must be `https://.../`; there are two session/credential shapes; and the API token must be 32 to 256 characters of `[A-Za-z0-9-_]`.
- **Capture.** `capture` (`app_document.rs:491-552`):
  1. Issues signed reads of the app (the generation lives in field 0), the package, the task and the document.
  2. Retains a `fetch.json` Delivery "started" record (`mini_sdk::custody::Delivery`).
  3. Makes exactly one curl fetch (`fetch`, `app_document.rs:353-465`): `/usr/bin/curl` with an empty environment, the config sent on stdin (the token is never in argv), HTTPS only, no redirects or proxy, a 90 s limit and a 128 KiB file cap.
  4. Checks the `X-Mini-Export-Receipt` header for self-consistency (`checked_receipt`, `app_document.rs:290-349`).
  5. Seals the capture with ChaCha20-Poly1305 under `app-documents/storage.key` (`app_document.rs:135-219`).
- **Publish and recovery.** `publish` (`app_document.rs:577-619`) appends the sheet to the document through a normal proposal. `recover_exact` (`app_document.rs:672-693`) and `rebase` (`app_document.rs:698-758`) handle retries. `rebase` is permitted only after `failed` or `refused`.

#### `app_lifecycle.rs` (650 lines; tests from line 468)

This is owner-signed delegation of app lifecycle management to a manager subject, in six phases (`app_lifecycle.rs:15-22`):

1. app policy;
2. package policy;
3. snapshot policy (phases 1 to 3 install `application-managed-policy` predicates that the Host authors, op 7, `app_lifecycle.rs:159-179`);
4. app grant;
5. package grant;
6. snapshot grant (phases 4 to 6 delegate observe and mutate to the manager, `app_lifecycle.rs:180-186`).

`run` (`app_lifecycle.rs:336-466`) offers prepare, submit, recover and status. Recover is lookup-only. The module publishes delegations and writes a `management-selector.json`. `retained_status` (`app_lifecycle.rs:301-334`) is a read-only projection used by `member.rs:192`.

#### `inspect_views.rs` (436 lines)

These are the inspection views `caps`, `law`, `receipt`, `turn` and `why` (`inspect_views.rs:419-436`). Each gathers held bytes and signed views into `inspect/NONCE-VIEW.json` and asks the Host's `inspect VIEW` to render them (`render`, `inspect_views.rs:30-58`). `turn` and `why` run the op 130 dry run (`inspect_views.rs:216-274,354-399`). `refusals` scans retained refusal frames (`inspect_views.rs:278-347`).

#### `context_projection.rs` (270 lines)

`document` (`context_projection.rs:10-88`):

1. Issues a signed `resource` read.
2. Asks the Host for `inspect context-document`.
3. Checks that the projection's source and root equal the signed read.
4. Attaches the opened text of each pinned row.
5. Checks summaries through `context-support` (`summary_text`, `context_projection.rs:175-220`).

`review` (`context_projection.rs:97-173`) turns a model-authored invoke into a guarded native proposal. Every cited source becomes an `expectedTargetRoot` plus `expectedObserveCapability` guard, and the targets are capped at 16.

### 1.7 Names, rooms, search

#### `shared_names.rs` (1,063 lines; tests from line 715)

Room names are content links in a room's index document, using the target form `{"type":"external","scheme":hex("mini-name"),"authority":hex(NAME),"path":hex("KIND/ID")}` (`target`, `shared_names.rs:34-45`).

- **Decoding.** `binding` (`shared_names.rs:49-93`) decodes live bindings strictly: canonical hex, a decimal tombstone, relation 0, no source range, KIND in `{object, account, program}`, and a canonical round-trip. Malformed records in the namespace are errors, not absences. `bindings` (`shared_names.rs:95-116`) refuses duplicate live names.
- **Resolution.** `resolve`, `resolve_many` and `resolve_with` (`shared_names.rs:153-183,365-415`) resolve `ROOM/NAME`:
  1. Read the room's `NAMES_FIELD` (1010) pointer, as a `resource-scope` view whose capability field coverage must include the field. Only then can the reader conclude a name is absent (`shared_names.rs:285-321`).
  2. Read the index document at the same world root (`coherent_pair`, `shared_names.rs:238-263`).
  3. Look up the binding.
  4. Return a target-pinned reference carrying `sharedName` discovery metadata.
- **Guards.** `check_opened_views` (`shared_names.rs:474-507`) re-validates a resolution against discovery guards read in the same native batch as the target.
- **Writes.** `command` (`shared_names.rs:595-713`) implements attach, bind, rename and unbind as ordinary proposals with exact retry, under the law `index_law` (`shared_names.rs:512-516`: content writes require the Lean slot `content/names/unique == 1`).

#### `room_schema.rs` (191 lines)

This is the ROOM-SCHEMA v2 field layout:

| field(s) | meaning |
|---|---|
| 1001-1009 | tariff and Hermes fields |
| 1010 | names index |
| 1011 | open flag |
| 1012 | Hermes assignment |
| 2000 | founder |
| 2000+2k-1, 2000+2k | member k's subject and stream |

The constants are at `room_schema.rs:27-55`. `declared_fields` builds the room's birth `--fields` (`room_schema.rs:58-70`). `check_room_view` refuses v1 rooms by name (`room_schema.rs:88-121`).

#### `doc_search.rs` (368 lines)

This is client-side bounded search over the member's own signed current reads. The scope is a comma list or `@held` (all local refs), capped at 4,096 (`doc_search.rs:14-43`). Pages hold 4 references (`doc_search.rs:8`). Each reference gets one signed `resource` read, a Host `view-document`, `opened_entries` and `render` (`direct`, `doc_search.rs:47-78`). Matching is a lower-cased substring test on live UTF-8 text lines, with at most 100 hits per document and a 200-character snippet (`doc_search.rs:104-180`). There is no index, no Host search operation and no cache. A collection fingerprint makes the pagination cursor (`doc_search.rs:193-206`). `follow` re-reads a hit (`doc_search.rs:248-282`).

---

## 2. What it assumes of its surroundings

### 2.1 Host protocol operations, with the Lean cross-check

These are the operations this shard sends, directly or through `crate::host_files`, `crate::author` and `crate::inspect` in `main.rs:1290-1345`. Byte numbers come from `protocol/host-operations.json`.

| op | symbol (json) | receiver (json) | sent by (this shard) | Rust encoding | Lean receiver arm | agreement |
|---|---|---|---|---|---|---|
| 1 | AUTHORIZED_PREPARE | dispatchSession | indirectly through `workspace::submit_intent`/`propose` (main) | (main) | (shard A) | not re-checked here |
| 2 | SUBMIT | fnDispatch | `object_epoch_cli.rs:401-409` (`crate::submit`), `crate::retry` | (main) | (shard A) | not re-checked here |
| 3 | LOOKUP | fnDispatch | `historical_call_receipt.rs:34-36` (`session_invoke(...,3,call)`); `append_proof.rs:275-279` (`host_files lookup`) | raw signed call bytes | fnDispatch op 3 (shard A) | reply byte 3 checked (`historical_call_receipt.rs:120-122`) |
| 7 | AUTHOR | dispatchSession → `pureCodec` (`Host/Main.lean:1960-1968`) | `protected_document.rs:333-341` (kinds `object-audience-roster`, `object-device-catalog`); `object_epoch_cli.rs:35-42` (`policy`), `:362,381` (`intent`); `app_lifecycle.rs:168-174` (`application-managed-policy`); `append_proof.rs:236-242` (`resource`) | `u16le(len kind) ‖ kind ‖ JSON` (`main.rs:1302-1309,1319-1321`) | `splitKind` then `authorHost` (`Host/Main.lean:1960-1968`); the kinds exist at `Host/Json.lean:3757-3758,3777` | agree |
| 8 | INSPECT | dispatchSession (`Host/Main.lean:2044-2063`) | `object-audience` (`protected_document.rs:236,591-593`), `object-audience-roster` (`protected_document.rs:245-246,730-731`; `object_epoch_cli.rs:233-244`), `object-roster-inspect` (`object_epoch_cli.rs:201-209`), `world-prototype-output` (`world_prototype.rs:87-91`, through `method_operation`); plus `view-document`, `view-policy`, `plan`, `outcome`, `predicate`, `context-document`, `context-support` and the inspect views `cap-tree`/`law`/`receipt`/`turn`/`why` | `object-audience`: `kind ‖ signed observation`; `object-audience-roster`: `kind ‖ pair(src, pair(catalog, pair(planned, roster)))` (`main.rs:1326-1332`) | `object-audience` → `NativeHost.objectAudienceLoaded` (session, walked); `object-audience-roster` → three `splitPair`s, then `objectAudienceRosterLoaded` (`Host/Main.lean:2046-2062`); `object-roster-inspect` is a pure codec (`Host/Main.lean:1973-1975`); `world-prototype-output` at `Host/Json.lean:5541`; `context-*` and `view-document` at `Host/Json.lean:5939-5941` | agree on nesting and kinds. `object-audience` refusals come back as byte 255 frames (`Host/Main.lean:2050`), which Rust's `host_files` handles in main |
| 11 | CALL_ASSEMBLE | dispatchSession → pureCodec | `append_proof.rs:259-268` (`host_files assemble`) | `pair(plan, signatures)` (`main.rs:1337`) | pureCodec 11 | agree (shard A owns the codec) |
| 130 | AFFORDANCE_DRY_RUN | dispatchSession (`Host/Main.lean:2064-2072`) | `inspect_views.rs:226-233,380-387` (`crate::dry_run`) | `pair(observation, signatures)` | `DryRun.dryRunLoaded`: `.admitted` → 130 plus plan, `.stopped` → 255 plus outcome | agree |
| 131 | NOCK_PROGRAM_CHECK | fnDispatch | `world_kind.rs:613` | `u32le(len jam) ‖ jam ‖ ABI JSON` (`world_kind.rs:608-612`) | fnDispatch (not opened in detail) | Q8.9 |
| 132 | NOCK_PROGRAM_SHOW | fnDispatch | `world_kind.rs:516`, `world_prototype.rs:76` | the program ID as decimal ASCII | fnDispatch | Q8.9 |
| 134 | NOCK_DRY_RUN | fnDispatch | `world_kind.rs:530`, `world_prototype.rs:83-85` | JSON `{programId, caller, room, targets, values}` | fnDispatch | Q8.9 |
| 151 | RECEIPT_CONTINUITY | fnDispatch (`Host/Main.lean:2077`; session arm `Host/Main.lean:6730-6734`) | `receipt_continuity.rs:602-614`; `carry.rs:612-643` (also `transport::invoke_pinned` with the signed target digest) | JSON `{identity, from, target, fromChain?, fromSiblings?}` | `carriedContinuitySession` (`Host/Main.lean:3987-4007`): a foreign identity is served from the carry registry (`RetainedSegmentInspection.serveContinuity`); for the current identity it refuses historical targets below the carried anchor; errors become `(255, "receipt continuity request refused")` | agree. Rust refuses `frame[0] != 151` (`receipt_continuity.rs:610`). The 255 detail is discarded (F7) |
| 153 | CARRY_RECEIPT_LOOKUP | fnDispatch (session arm `Host/Main.lean:6735-6741`) | `carry.rs:1504` | `u32le(header len) ‖ {"algorithm":"minidregg-carried-call-lookup-v1","originIdentity":...} ‖ raw call` (`carry.rs:1297-1322`) | `RetainedSegmentInspection.serveLookup` (`Host/RetainedSegmentInspection.lean:315-330`): `parseLookup` requires a header width ≤ 1024 (`:257-260`), matching Rust's `header.len() > 1024` refusal (`carry.rs:1307`); the response has exactly `algorithm, originIdentity, callDigest, outcome` (`:324-326`), matching `carry.rs:1333-1347`; the refusal reasons `origin-mismatch`, `malformed-call`, `lookup-refused`, `capsule-unavailable` and `receipt-invalid` (`:281-311`) match exactly the list at `carry.rs:1392-1398`; confirmed requires `confirmation == replayed` and `0 < count ≤ cut.height` (`:284-292`), matching `carry.rs:1372-1387` (Rust also enforces the lower bound) | agree |

The pinned local verifier subcommands (local process, not wire) are:

- `profile` (`receipt_continuity.rs:298`, `carry.rs:409-413`)
- `continuity-point` (`receipt_continuity.rs:510-511`; Lean dispatch `Host/Main.lean:6376`)
- `continuity-verify` (`receipt_continuity.rs:579-580`; `Host/Main.lean:6381`)
- `carry-edge-verify` (`carry.rs:285-291`)
- `carry-verifier-profile` (`verifier.rs:92-98`)
- `inspect`/`author` with the kinds `subject-key-adoption-plan`, `subject-key-adoption-ingress`, `subject-key-rotation-plan`, `subject-key-rotation` and `signing-key-next-digest` (`receipt_continuity.rs:387-393`)

`studio_preview` (outside this shard) runs the `objective-front` subcommand.

### 2.2 OS facilities

- **Unix only.** `web`, `operation-proof` and `historical-call-receipt-lookup` are `#[cfg(unix)]` (`main.rs:3210-3215,4199`). `receipt_continuity.rs:11` uses `std::os::unix`. The NOFOLLOW and O_DIRECTORY flag values are hard-coded for macOS and for other platforms, which assumes Linux (`receipt_continuity.rs:23-30`).
- **Advisory locks.** `transport::service_lock` (flock-style) is used by `object_keys.rs:61-62`, `protected_document_members.rs:76,283`, `app_document.rs:141,523`, and `mini_sdk::lock::Lease` (`receipt_continuity.rs:168-181`, `app_lifecycle.rs:42-48`).
- **External binaries:**
  - `/usr/bin/curl`, absolute path, for the connector (`app_document.rs:385`);
  - `timeout` from coreutils for the studio preview (`workspace/studio_preview.rs:71`; macOS lacks it by default);
  - the minidregg Host binary as a local verifier and codec (`receipt_continuity.rs:294-304`, `historical_call_receipt.rs:38-49`).
- **fork.** Only the `#[cfg(target_os = "linux")]` test uses it (`object_keys.rs:713-755`).
- **Network.** The web listener is TCP on 127.0.0.1 (`web.rs:63-64`). The Host is reached over a Unix socket (`SOCKET`, `crate::session_invoke`). The connector makes HTTPS calls to an app endpoint through curl. This shard uses no Solana, Discord or provider endpoint.

### 2.3 Files, directories and environment variables

Workspace subtrees this shard touches:

| directory | contents | written at |
|---|---|---|
| `refs/` | references, including rewrites for protected custody hints | `protected_document.rs:320-323` |
| `sources/` | retained requests | `shared_names.rs:546-555,611-616`; `world_prototype.rs:47-48`; `protected_document_members.rs:491-497` |
| `proposals/`, `attempts/` | proposal and attempt directories | (various) |
| `protected-documents/` | `keys.json`, `storage.key`, `custody.json`, `device.json`, `enrollment-T.json`, `atom-versions-T.json`, and per object `T/{roster.*, catalog.*, enrollment*.json, membership/CHANGE/..., current-epoch.json, epoch-*/, conversion/}` | (various) |
| `app-documents/` | `storage.key`, `ID/{capture.enc, fetch.json, submit-started.json, result.json, rebase.json}` | (various) |
| `app-lifecycle/ID/` | lifecycle phases | (various) |
| `receipt-continuity/` | continuity custody (see 1.5) | (various) |
| `web-edits/` | editor sessions | through `web_author` |
| `discovery/ROOM.index` | an index hint | `shared_names.rs:189-214` |
| `seen/world-NAME.json` | retained world views | `world_kind.rs:130-151` |
| `programs/` | program verdicts | `world_kind.rs:617-628` |
| `inspect/` | inspect inputs and outputs, created with default permissions | `inspect_views.rs:31-34` |

Environment variables: `MINIDREGG_STUDIO_PREVIEW_CONFIG` (`workspace/studio_preview.rs:10`). Test-only: `MINI_OBJECT_LOCK_TEST_CHILD`, `MINI_CONTINUITY_*`, `MINI_CARRY_*`.

Other crates: `mini-sdk` (`decimal`, `hex`, `durable`, `lock`, `custody`, `store`, `private`); `minidregg-pay-watcher` (`transport::validate_endpoint`, `app_document.rs:97`); `hybrid_kem` (path include, `main.rs:88-89`); `ed25519-dalek`, `chacha20poly1305`, `ring`, `sha2` and `zeroize` (`Cargo.toml:17-34`).

---

## 3. Does it decide anything semantic?

**IS** means nothing on the Lean side would refuse if Rust got it wrong. **Mirror** means Rust pre-checks something Lean decides again.

| # | site | what Rust decides | class | Lean counterpart | blast radius if wrong |
|---|---|---|---|---|---|
| S1 | `shared_names.rs:34-93` (grammar), `:153-415` (resolution), `:337-363` (`existing_authority` borrows capabilities from any local ref with the same target) | What a room name means (`KIND/ID` path, canonical form, absence semantics), and which local capability IDs to attach | **IS** (a naming convention). Authority is still Lean's | `Kernel/ContentResource.lean:1779-1812` knows only the scheme bytes and live-name uniqueness (`sharedNamesUnique`), and only under `index_law` (`shared_names.rs:512-516`) | A wrong resolution points a member at the wrong cell. Writes still need a Lean-admitted grant on that cell. An index writer can rebind a name to a cell the victim's room grant also covers, redirecting the victim's next write (section 7). Lean should own a `SharedName` decoder so the grammar is not Rust-only |
| S2 | `room_schema.rs:27-55,58-70` | Room field layout: which field is the names index, the open flag, the tariff, the roster founder and members | **IS** (layout semantics), consumed by `chat.rs:848-865`, `credit.rs:22-24`, `web/resident.rs:16-27` | Lean knows only the generic `fieldsFrom` tail (`Compiler/DeclaredEffectCell.lean:109`, `Compiler/CanonicalCellRegistry.lean:330`) | Roster membership listing and tariff reading are client conventions; grants remain Lean's. Two clients with different constants read different rooms |
| S3 | `world_kind.rs:460-487` | Compute credits = admitted steps minus remaining free steps. It refuses unless `freeSteps == "1000000"` and `creditsPerStep == "1"`, then builds a `computeFunding` payload with `credits`, `expectedPayerBalance` and `expectedBookRoot` | **Mirror or IS: undetermined** | `Kernel/RunComputeView.lean:16-25` (`ComputeQuote`); `Kernel/ResourceTransaction.lean:1406-1421` checks `compute.steps = run.verdict.steps`, but I could not find where Lean recomputes `credits` from the quote (Q8.1) | If Lean takes `credits` as given, a member's client can underfund compute. The hard-coded tariff is a twin of the Lean deployment constants: if the tariff changes, every call refuses |
| S4 | `world_kind.rs:227-237` (`revise`) | Kind revision must strictly increase | Mirror, if the law enforces it | Lean projects `kind/revision/before/after` slots (`Kernel/WorldKindProjection.lean:118-126`); enforcement is up to each kind's law (Q8.2) | Without a law clause, a non-increasing revise is admitted when the client check is bypassed |
| S5 | `protected_format.rs:119-200` | The semantics of "carrying" formatting across protected conversion: copy the exact kind or link target from the live source mark, check freshness agreement, check the link's canonical witness | **IS for the carry invariant**; ordinary for authority | Lean has no `carryFormatting` verb (grep); it admits ordinary `mark` actions (`workspace.rs:3143-3144` lowers before submission) | No authority impact, since the writer could add any mark. "Formatting preserved faithfully" is guaranteed only by Rust |
| S6 | `object_epoch_cli.rs:159-191` | Next audience state machine: enroll is epoch 0; freeze sets parent = transition and mode frozen; resume increments the epoch and sets mode active | Mirror (the module comment says "the source controller validates transition semantics", `object_epoch_cli.rs:1-3`) | The Host authors the policy (op 7 `policy`) and checks the roster (op 8 `object-audience-roster`); the Lean controller admits `install-source` (Q8.3) | If Lean does not validate the state transition, a malicious owner client could install a bad audience state. Only the owner can do this, since the control capability is required |
| S7 | `protected_document_members.rs:328-336` | Revocation completeness: which standing grants to revoke when removing a member (from `standing_grants`) | Mirror (each revoke is admitted by Lean) | Lean's `who` view and revoke admission | A missed grant lets the removed member keep reading ciphertext. They do not receive the new epoch key (the roster excludes them), but they could still observe structure |
| S8 | `protected_atoms.rs:67-92`, `protected_document.rs:263-307` | Whether a served sealed atom is a rollback or an equivocation (version chain seq/prev against the revision and the reader's retained history) | **IS, as client verification of the server** (fail closed: the atom shows locked with a reason) | The binding is in the clear prefix of the ciphertext; Lean could check `seq` and `prev` against the record but I found no such check (Q8.4) | Wrong rule: a false "rollback" shows a locked line (DoS), or a real rollback is shown. The rule lives only in Rust |
| S9 | `receipt_continuity.rs:626-689` (`walk`, `finish_locked`) | Whether a verified hop makes valid progress (monotonic heights, same-height equality, completion semantics); whether a read is "older than baseline" | Rust custody policy around a Lean proof (each hop is verified by `continuity-verify`) | `Kernel.ReceiptContinuity.opens_sound` (per `docs/RECEIPT-CONTINUITY.md:24-29`) | Wrong: accept a Host fork, or refuse honest progress |
| S10 | `receipt_continuity.rs:843-876` (`finish_attempt`) | That a "confirmed" outcome's `(acceptedCount, worldRoot)` anchors this call. Only the point is proved to be on the chain | **IS (an implicit trust)**: no inclusion proof of the call's transaction at that height | `RECEIPT-CONTINUITY.md:31-35`: "An accepted record commits its transaction ... Its digest extends the log chain"; the client never checks that the record digest at `acceptedCount` is this transaction (Q8.5) | A Host that lies about a confirmation at a real point is believed. The client stops retrying, and the operation is lost (a lost-reply failure) |
| S11 | `receipt_continuity.rs:830-841` (`receipt_mode`) | The allowlist of confirmation kinds (`installed`, `recoveredAfterUncertainResponse`, `replayed`) and which of them are replay-like | Mirror of the Lean outcome codec | `NativeHostCodec.Outcome` (shard A) | A new Lean kind is refused (fail closed) |
| S12 | `carry.rs:1323-1413` | Field allowlist for op 153 and the segment bounds `[lower, cut]` | Mirror plus an extra check (the lower bound) | `Host/RetainedSegmentInspection.lean:281-292` checks `count ≤ cut` only | Extra strictness refuses valid answers (fail closed) |
| S13 | `historical_call_receipt.rs:14-32`; `append_proof.rs:131-140` | "This receipt equals the expected one" as string equality on four fields of a Host op 3 answer | Mirror (the Host decides confirmation) | fnDispatch op 3 | No continuity anchor (F6), so a rolled-back Host is believed |
| S14 | `append_proof.rs:52-113` (`statement`) and `:340-357` | Links the human-level request (`record.binding.request`) to the native command, and authors a `minidregg-append-operation-proof-v1` statement exposing `text`, `to`, `reply` and `stream` | **IS (a Rust-authored evidence document)**: the Host re-authors and compares the command bytes (`append_proof.rs:236-257`), but the statement JSON is signed by nobody | none | A consumer that trusts `proof.json` trusts Rust's linkage. Mitigated by the hashes inside it |
| S15 | `render/mod.rs:347-361,419-429`; `web.rs:500-551` | Line numbering, outline membership, board layout (task n: field 2n+2 is state, 2n+3 is owner) | Presentation | The Host supplies order, freshness and readability; the board layout is P-SHELL-DOCS convention | Cosmetic. Line numbers are also what `doc edit LINE` takes in the shell (outside this shard), so a numbering bug edits the wrong line, but Lean then refuses on revision guards |
| S16 | `web_actions.rs:131-204` | Which atoms a line range maps to; which run contains the endpoints; which pins go into a transclusion | Mirror (Lean refuses wrong pins, roots or authority, per `web_actions.rs:108-109`) | Hyperdocument controller | Refused turn |
| S17 | `doc_search.rs:140-180` | Search matching and coverage counts | Presentation over signed reads | none needed | Cosmetic |
| S18 | `context_projection.rs:57-75,193-218` | Whether a summary's text is included (Rust adds "unavailable" when any dependency read fails) | Stricter than Lean (Lean's `context-support` decides `current`) | `Host/Json.lean:5940` | Fail closed |
| S19 | `app_document.rs:290-349` | Whether an app's export receipt "matches" the request and body; the receipt's operation, transaction and event IDs are **not** verified against Mini | Labelled as non-kernel provenance (`app_document.rs:1-3`) | none | The receipt IDs are embedded as text in the document (`app_document.rs:554-566`). A malicious app could claim false provenance there |
| S20 | `protected_document_members.rs:73,106-116` | The owner chooses the roster; share requires a validated device | Owner discretion under a Lean-checked control capability | `object-audience-roster` check (Lean) | none beyond the owner's own choice |

Places where Rust correctly defers:

- Every document mutation from the web is an ordinary proposal through workspace admission (`web/editor.rs:117`, `web/create.rs:45`).
- Visibility and backlinks come from Host views (`web.rs:792-808`).
- Transclusion readability comes from the Host's `render.view` and Host `at`-read refusals (`render/mod.rs:226-298`).
- Policy authoring is the Host's job (`object_epoch_cli.rs:35-42`, `app_lifecycle.rs:168-178`).
- Roster checking is the Host's job (`protected_document.rs:236-247`).
- Method evaluation runs on the Host, ops 132 and 134 (`world_kind.rs:516,530`).
- Context selection is the Host's job (`context_projection.rs:24-29`).
- Proof verification is done by the local Lean verifier (`receipt_continuity.rs:579-585`).
- Old-segment receipts are selected by the retained Lean executable (`Host/RetainedSegmentInspection.lean:294-311`).

**Protected-fragment redaction (the brief's question 2).** Rust never decides to redact on policy grounds. It shows a fragment exactly when the fragment opens with keys the reader holds, together with a Host-authorised signed read (`protected_document.rs:259-309`, `render/mod.rs:362-393`). A locked or unsupported fragment renders as a placeholder (`render/mod.rs:370-377`, test `render/tests.rs:278-286`). The roster that decides who holds keys is checked by Lean. Who may write is checked by Lean ("the enclosing resource controller still checks the actual entire post against all current keyholders", `docs/contracts/protected-authored-fragments.md:13-15`). This boundary is correct.

---

## 4. Flaws noticed

Severity labels: **H** has a concrete cross-member impact; **M** has a local or self impact, or a liveness impact; **L** is hygiene.

**F1 (H) Terminal-escape injection through `doc-history` and `doc-diff`.** `history_text` and `diff_text` (`render/history.rs:52-92`) build lines from `payload_text` (`render/history.rs:11-17`, `String::from_utf8_lossy`). `print_changes` prints them unfiltered (`workspace.rs:2459-2468`, reached from `workspace.rs:6931-6947` and the shell verbs `doc history` and `doc diff`). `doc show` filters exactly this through `one_line` (`render/text.rs:21-40`, with a test at `render/text.rs:141-190`).

Scenario: a co-editor writes a line `\x1b]52;c;<base64>\x07`, then edits it. Every reader who runs `doc history paper` gets their terminal clipboard overwritten, or screen and cursor control sequences, or worse on vulnerable terminals. Fix: apply `text::one_line` per line in both functions.

**F2 (H) One malformed shared-name link makes a document unrenderable for everyone.** `render` calls `crate::workspace::shared_names::binding(entry)?` for every entry (`render/mod.rs:430-435`). `binding` returns `Err` for any `external` link whose scheme decodes to `mini-name` but whose fields are non-canonical. Examples: a path that is not `KIND/ID`, an `ID` with a leading zero, an unknown kind, a missing `tombstonedAt`, a non-decimal tombstone, a relation other than 0 (`shared_names.rs:57-92`; the tests at `shared_names.rs:911-919` assert that malformed means error).

Lean admits such a link in any content document. `sharedNameAt` keys only on scheme and liveness (`Kernel/ContentResource.lean:1782-1788`), and uniqueness is enforced only under `index_law`. The test `render/tests.rs:209-219` covers only a well-formed binding.

Scenario: a member with edit rights on `paper` adds a link `{type: external, scheme: hex("mini-name"), authority: hex("x"), path: hex("bogus")}`. Every subsequent `doc show paper`, `/doc/paper` page, `doc search` over `paper` and editor open fails with "shared-name path is KIND/ID", until someone unlinks it, and unlinking needs the same document rendered in the editor. Fix: render must treat malformed bindings as shown-but-invalid, not as fatal; or Lean must refuse non-canonical `mini-name` links.

**F3 (M) A confirmed receipt is not bound to inclusion** (see S10). `finish_attempt` builds the target from `outcome["acceptedCount"]` and `outcome["worldRoot"]` only (`receipt_continuity.rs:863-866`). `walk` then proves that point is on the chain. Nothing checks that the accepted record at that height is the call's transaction. A Host that answers `confirmed` at a real past point for a call it never applied is believed. The client treats the operation as done and never re-sends it, which loses the operation. This cannot be fixed in Rust alone; it needs a Lean-side inclusion opening (Q8.5).

**F4 (M) Unbounded growth of protected custody leads to permanent refusal.** `Store` keeps every `pending` emission wire and every `fragments` entry (each up to 1 MiB of plaintext, encrypted and then hex-encoded) forever (`object_keys.rs:255-303,328-363`). `settle` marks entries but never prunes them (`object_keys.rs:448-520`). `save` rewrites the whole journal on every operation (`object_keys.rs:98-121`). At 32 MiB it refuses all new emission ("retained object state capacity reached; new emission refused", `object_keys.rs:101-103`). A busy protected document therefore eventually becomes un-editable for its writer, and the work per write grows with history.

**F5 (M) A web GET mutates custody without bound.** Every `GET /doc/NAME/edit` creates `web-edits/<random>/session.json` (`web/editor.rs:86-95`, which calls `workspace/web_author.rs:55-70`). Every `GET /new-document` creates a creation session (`web/create.rs:25-29`, which calls `workspace/web_create.rs:33-49`). Repeated reloads or browser prefetch grow disk usage. The comment at `web.rs:124-125` acknowledges that draft-opening GETs mutate. GET is not safe or idempotent here.

**F6 (M) Exact-lookup proofs bypass continuity custody.** `append_proof::prove` looks up through `host_files lookup` (`append_proof.rs:274-286`). `historical_call_receipt::lookup_verified` uses op 3 directly (`historical_call_receipt.rs:111`). Neither calls `receipt_continuity::begin_attempt` or `finish_attempt`, so in a continuity-enabled workspace (`receipt_continuity.rs:422-474`) a rolled-back or forked Host can mint "proofs". Contrast `crate::retry`, which brackets with continuity (`main.rs:2469,2527`).

**F7 (L) Refusal detail discarded on op 151 and op 153.** Rust maps any reply byte other than 151 or 153 to a generic error (`receipt_continuity.rs:610-612`, `carry.rs:640-642,1519-1523`). The Lean 255 frames carry a reason (`Host/Main.lean:6734,6740-6741`). The refusal is loud (law 10 is met), but the reason is lost. Op 153 does retain the frame bytes first (`carry.rs:1506`).

**F8 (L) Hash-then-exec TOCTOU and no timeout on carry and verifier executables.** `verifier::install` hashes `executable` (`verifier.rs:77`), then runs `Command::new(executable)` by path (`verifier.rs:92-98`), then hashes again (`verifier.rs:109`). A swap-and-swap-back between the checks would execute a different binary. The same pattern appears in `select` (`verifier.rs:163`), followed by execution at `carry.rs:285-291`, and in `register_capsule`, which executes a copy at `carry.rs:409-413`. None of these has a timeout, so a hung verifier blocks while holding the custody lock (`carry.rs:228`). The ordinary continuity path uses `transport::PinnedLocalInvocation` (`receipt_continuity.rs:287-304`), which is the right primitive here too.

**F9 (L) Secret key accepted from a request file.** `receive_epoch` takes a device secret from `r["hybridSecret"]` when present (`object_cli.rs:75-79`). The only production caller never sets it (`protected_document.rs:736-740`), so the branch is dead in production but invites secret material in plain JSON. Remove it.

**F10 (L) The studio preview holds the global mutation lock for up to about 47 s.** POST `/studio/ID/preview` runs under `Site::mutations` (`web.rs:597`), and `studio_preview::child` waits up to `timeout --kill-after=2s 45s` (`workspace/studio_preview.rs:71-72`). Every other save, creation and draft open blocks behind it. It needs coreutils `timeout`, so on macOS the spawn fails, which is reported (`workspace/studio_preview.rs:75`).

**F11 (L) Malformed payload hex renders as empty.** `render::decode_hex` returns `unwrap_or_default()` (`render/mod.rs:169-171`), and the test asserts it (`render/mod.rs:549-555`). A corrupt Host payload therefore shows as a blank line rather than an error. `history.rs` shows a diagnostic instead (`render/history.rs:11-17`). This is an inconsistent twin rule.

**F12 (L) The POST head parse requires UTF-8 over body bytes too.** `parse_request` runs `from_utf8` on the whole first read, including any body bytes (`web.rs:142-143`, called at `web.rs:574`). This is harmless for urlencoded forms, but it is the wrong layering.

**F13 (L) `short()` byte-slices.** `&id[..12]` (`web.rs:308-314`) panics when byte 12 is not a character boundary. The inputs are reference targets from local `refs/*.json` (`web.rs:726,735`) and Host decimal IDs. A non-ASCII target in a local reference crashes that worker thread. The permit is released (`web_admission.rs:17-20,43-46`), and the client sees the connection drop.

**F14 (L) Swallowed error in connector recovery.** `let _ = recover(root, &attempt);` (`app_document.rs:684`). `status` is then re-read, so the outcome is still reported, but the recovery error itself (for example, an unavailable socket) is lost.

**F15 (L) The connector stores the app API token in a user-supplied JSON binding.** The token is validated at `app_document.rs:117-125` and read from `--binding FILE` at `app_document.rs:780`. It is protected only once it has been sealed in `capture.enc`. The file permissions on the input binding are not checked (contrast `crate::read_secret`).

**F16 (L) `inspect/` is created with default permissions.** `fs::create_dir_all` (`inspect_views.rs:31-34,403-406`). The files inside are `create_private`, but the directory listing is umask-governed. Every other custody directory in this shard uses `make_private_dir`.

**F17 (L) Refusal frames printed with lossy UTF-8.** `method_operation` formats a refused frame with `String::from_utf8_lossy(&frame)` (`world_kind.rs:421`). That contradicts the shard's own rule, "the frame is never read for printable runs" (`web.rs:358-361`), and can print binary or control bytes.

**F18 (L) Heavy loops.** `rewriting::current` runs up to 4,096 rounds. Each round makes a full `rendered_document` read, a proposal and a submit, and runs `restore` with up to 128 more full reads (`protected_rewrite.rs:146-149,217-251`). On a large document, a membership change can issue thousands of Host reads.

**F19 (L) Quadratic render.** `view.entries.iter().find(...)` per order row (`render/mod.rs:364`) and per-line lookups in `web/inspect.rs:31-34` make rendering O(rows × entries). This is bounded by Host view size.

**F20 (L) Stale doc comment.** `object_epoch_cli.rs:97` still documents `recipients[{...,kemPublic,dhPublic}]`, which `public_from_record` refuses by name (`object_keys_hybrid.rs:32-46`).

**Retry and replay review (no second-operation hazard found):**

- protected members: `protected_document_members.rs:130-152,384-423`
- enrollment: `protected_document.rs:368-382` (`retained_attempt` always prefers an emitted `call.bin`)
- epoch phases: `object_epoch_cli.rs:368-412` (no new key on retry)
- connector: `app_document.rs:526-535` (a started fetch is never repeated, through `Delivery`)
- lifecycle: `app_lifecycle.rs:400-441` (recover is lookup-only)
- names: `shared_names.rs:545-591`
- method calls: `world_kind.rs:497-507` (a reused ID returns the retained intent)
- carry lookups: `carry.rs:1476-1478` ("never direct execution or resubmission")

The one caveat is F3, where a false confirmation ends retries.

**Panics on untrusted input:** `web.rs:588` `unwrap()` is safe, since the loop condition guarantees it. `protected_fragments.rs:12,19,60` `try_into().unwrap()` follow length checks. `carry.rs:1511-1514` `file_name().unwrap().to_str().unwrap()` applies to a locally generated retry path. `web/studio.rs:225-229` `unwrap()` follows key-presence checks. F13 is the only reachable panic I found.

---

## 5. Unwired and undone

### 5.1 Dead or orphaned

| item | evidence | lines |
|---|---|---|
| `web/surface.rs` (`surface::body`, `Renderer`) | Declared at `web.rs:24`; no caller (grep `surface` in `web.rs` and `web/*.rs` returns only the `mod` line). There is no `allow(dead_code)`, so rustc should warn | 130 |
| `world_surface.rs` (`Surface`, `Intent`, `AdmittedObservation`, `PreparedIntent`, `AcceptedOrigin`) | Declared at `workspace.rs:71-72`; only its own tests reference the types (grep) | 200 |
| `protected_object/source-snapshot.json` | No reader anywhere in `native/` or `scripts/`; contains the absolute path `/Users/ember/workbox/mini-private-objects-20261002/...` (line 2) | 1,460 bytes |
| `protected_document_members::visible_atoms` | Used only by the test at `protected_document_members.rs:565-570` | 4 |
| The `object_cli::receive_epoch` `hybridSecret` branch | No production caller sets it (F9) | 5 |
| The parameter `drain_posts(..., workspace, ...)` | `let _=workspace;` (`protected_document_members.rs:396`) | 1 |

### 5.2 Reachable but not exercised by any journey or evidence

- **Web POST routes** (editor save, action, lookup; create; studio). `journey.d/jweb.sh` describes the face as "read-only" (`jweb.sh:1-3`) and checks only that `POST /TOKEN/doc/paper` returns 405 (`jweb.sh:45,223-224`). FRIENDS.md knows forms exist (`deploy/shell/FRIENDS.md:275-281`).
- **Studio routes.** README "Honest state" says "no member-reachable route" for Studio. On main, the routes are reachable in the member's own loopback `mini web` (`web.rs:629-637,603-604`). No public route exists, and publication stays disabled (`web/studio.rs:52`).
- **`mini operation-proof`, `historical-call-receipt-lookup`.** Grep of `journey.sh`, `journey.d/` and the top-level `*.sh`/`*.py` finds no caller. APPEND-PROOF.md records a single manual qualification (`APPEND-PROOF.md:18-22`).
- **Evidence.** No `docs/evidence/*/journey-result.json` contains the rows WEB, JDV, JPD, JWORLD, JKIND, JNAMES or JDOCUVERSE (python scan of all result files). The only run touching this shard is `docs/evidence/2026-09-30-shell-docs` (J12 134/134, text rendering). Continuity's 38/38 run is evidenced outside the repo (`docs/RECEIPT-CONTINUITY.md:107-118`).
- **Journey hooks that exist but are unrecorded:**
  - `jweb.sh` (`journey.sh:1041`)
  - `jdocuverse.sh` (`journey.sh:1013`)
  - `jprotected-docs.sh`, which runs `scripts/protected-document-journey.sh`
  - `continuity-journey.sh`, `carry-source-journey.sh`, `fresh-onboarding-journey.sh`
  - `jworld-kind.sh`, `jworld-method.sh`, `jworld-board.sh`, `jworld-prototype.sh` (`WORLD-PROGRAMMER.md:5-10`)
  - `jnames.sh`, `doc-search-journey.py`, `doc-search-protected-check.py`

### 5.3 Twins

| twin | site A | site B | keep / delete |
|---|---|---|---|
| HTML escape | `web.rs:293-306` | `render/html.rs:9-22` (byte-identical) | Keep `render::html::escape`; make `web::escape` re-export it (`web_actions.rs:208` already uses `crate::web::escape`) |
| urlencoded decoder | `web/editor.rs:47-84` (`form`) | `web/search.rs:6-24` (`decode`) and `fields` | Keep one decoder. Both accept `u8::from_str_radix` with a leading `+` (e.g. `%+f` decodes as 0x0f), so whichever is kept should be tightened |
| malformed-payload rule | `render/mod.rs:169-171` (empty) | `render/history.rs:11-17` (diagnostic) | Keep the diagnostic (F11) |
| protected atom envelope | `protected_document.rs:762-786` (`open_atom`, legacy `MINI/PROTECTED-DOCUMENT-ATOM/v1` inlineObject) | `protected_atoms.rs:93-99` (authored fragment v1) | A versioned sibling. The legacy path is read-only for history (`is_kind` accepts both, `protected_document.rs:40-43`); delete it once no legacy-sealed atoms are retained |
| surface renderer | `web/surface.rs` | `world_surface.rs::project` | Both dead; delete both |
| tariff constants | `world_kind.rs:465` (`1000000`, `1`) | Lean deployment quote (`Kernel/RunComputeView.lean:16-25`) | Rust should read the quote, not pin it (S3) |
| name scheme | `shared_names.rs:13` (`"mini-name"`) | `Kernel/ContentResource.lean:1779` | Lean should own decoding (S1, F2) |
| `object_keys` vs `object_keys_hybrid` | custody journal | wrap primitive | **Not twins**: layers. Keep both |
| `web/studio.rs` vs `workspace/studio.rs` | UI | custody | Not twins |

### 5.4 Tests that do not test what they say

- `web.rs:1268-1275` `get_router_calls_no_submit_path` greps the source text of `fn route(` for the words POST, PUT, DELETE, PATCH, propose and submit. This is a prose-scanning gate. It passes even though GET routes call `editor::open`, `create::open` and `studio::module`, which mutate custody (F5). It cannot detect a submit reached through a helper.
- `carry.rs:1034-1035` states, correctly, that the receiving fixture "injects verifier verdicts; it tests physical routing and durable acknowledgment, not EdgeSeal cryptography". `receipt_continuity.rs:1063-1090` likewise uses a scripted `ProofSource`. These are honest about their scope, but no Rust test exercises a real `continuity-verify` verdict.
- `render/tests.rs` uses real journey fixtures, which is good.

### 5.5 TODO, FIXME, `unimplemented!`, `todo!`, `#[allow(dead_code)]`

A grep of the shard files finds none of these markers. The dead code above therefore builds with warnings rather than allowances.

---

## 6. Size and shape

| file | lines | test lines (approx.) | role |
|---|---:|---:|---|
| protected_annotations.rs | 20 | 0 | protected comments |
| protected_fragments.rs | 68 | 0 | authored fragment custody |
| protected_document_conversion.rs | 74 | 14 | conversion of public text |
| protected_atoms.rs | 100 | 0 | protected text binding |
| protected_rewrite.rs | 310 | 57 | rekey and format repair |
| protected_format.rs | 333 | 132 | carryFormatting lowering |
| protected_document_members.rs | 572 | 73 | share/revoke |
| protected_document.rs | 1,214 | 413 | enrollment, open, export/import |
| protected_object/object_messages.rs | 123 | 28 | record AEAD + signature |
| protected_object/object_keys_hybrid.rs | 201 | 78 | hybrid wrap |
| protected_object/object_cli.rs | 230 | 114 | receive epoch |
| protected_object/object_epoch_packages.rs | 416 | 181 | manifest prepare/receive |
| protected_object/object_epoch_cli.rs | 528 | 102 | phase authoring |
| protected_object/object_keys.rs | 757 | 235 | custody journal |
| render/mod.rs | 555 | 10 | renderer core |
| render/html.rs | 301 | 61 | HTML |
| render/text.rs | 191 | 55 | text |
| render/history.rs | 160 | 8 | history/diff |
| render/tests.rs | 286 | 286 | tests |
| web.rs | 1,292 | 276 | server, gate, pages |
| web/create.rs | 114 | 0 | create form |
| web/editor.rs | 510 | 69 | editor |
| web/inspect.rs | 158 | 19 | inspect page |
| web/resident.rs | 179 | 44 | resident page |
| web/search.rs | 256 | 19 | search page |
| web/studio.rs | 359 | 0 | studio |
| web/surface.rs | 130 | 36 | **dead** |
| web/world.rs | 191 | 31 | object page |
| web_admission.rs | 118 | 57 | ingress bounds |
| web_actions.rs | 302 | 63 | editor actions |
| doc_search.rs | 368 | 85 | search |
| app_document.rs | 1,072 | 267 | connector |
| app_lifecycle.rs | 650 | 183 | lifecycle delegation |
| inspect_views.rs | 436 | 0 | inspect views |
| context_projection.rs | 270 | 48 | context/review |
| world_prototype.rs | 126 | 19 | constructors |
| world_surface.rs | 200 | 39 | **dead** |
| world_kind.rs | 630 | 117 | kinds/methods |
| room_schema.rs | 191 | 61 | room layout |
| append_proof.rs | 451 | 73 | operation proof |
| receipt_continuity.rs | 1,470 | 454 | continuity |
| receipt_continuity/carry.rs | 1,542 | 620 | carry |
| receipt_continuity/carry/verifier.rs | 402 | 230 | portable verifier |
| historical_call_receipt.rs | 214 | 71 | recipient lookup |
| shared_names.rs | 1,063 | 349 | names |
| **total** | **19,133** | **~5,077** | |

Test lines were counted with a brace-balancing awk scan from each `#[cfg(test)]`/`#[test]` (scratch file `/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/rc-E/testcounts.txt`). The counts are approximate, ±5%. Non-Rust files: `web/fixtures/refused-read.err` (271 bytes), `web/fixtures/scalar-read.json` (338 bytes), `protected_object/source-snapshot.json` (1,460 bytes).

**Minimal version for the near demo.** Per README "Honest state", the public node serves the shell, documents (new, show, append, edit, link, backlinks) and boards, with no rooms, chat or proxy. `mini web` is "main only", and a hosted friend cannot run it (`deploy/shell/FRIENDS.md:26,275-278`).

- **Tier 1, drop with no demo impact.** About 5,416 lines; each file needs its `mod` line and dispatch arm removed:
  - `web/surface.rs` (130), `world_surface.rs` (200), both dead;
  - `web/studio.rs` (359; also drop `workspace/studio*.rs`, outside this shard);
  - `world_prototype.rs` (126), `app_document.rs` (1,072), `app_lifecycle.rs` (650);
  - `receipt_continuity/carry.rs` (1,542) and `carry/verifier.rs` (402): no lineage migration in a single-world demo. `receipt_continuity.rs:3,454,700,729,737` and `main.rs:2459` must lose their carry hooks;
  - `historical_call_receipt.rs` (214): `hermes_handoff.rs:349` depends on it, and Hermes is off on the public node;
  - `append_proof.rs` (451), `context_projection.rs` (270).
- **Tier 2, drop if the demo has no private documents.** `protected_*` (2,691) plus `protected_object/*` (2,255), about 4,946 lines. `workspace.rs:51-54,3052-3165` and `render/mod.rs:365-377` (via `workspace::private`) need small edits. `doc_search.rs:346` references `protected_document::schema` only in a test.
- **Tier 3, drop if the demo stays hosted shell-only.** The web face: `web.rs`, `web/*` except surface and studio, `web_admission.rs` and `web_actions.rs`, about 3,120 lines, plus `workspace/web_author.rs` and `web_create.rs`.
- **Keep:** `render/*` (1,493, of which the deployed shell's `doc show/history/diff` uses text and html), `shared_names.rs` (`render/mod.rs:432` depends on it; with rooms off it could shrink to `binding`), `room_schema.rs` (used by `credit.rs`/`chat.rs`/`member.rs`), `receipt_continuity.rs` (if continuity is wanted on the client), `doc_search.rs` (if `doc search` is in the demo), `inspect_views.rs` (`why`/`inspect` are "main only"), `world_kind.rs` (if boards use world instances, see `web.rs:887`).

Tiers 1 to 3 together remove about 13.5K of the 19.1K lines.

---

## 7. Deployability on a small public Linux VM

**On the box.** Nothing in this shard is a daemon. Everything runs inside the member's `mini` invocations: the shell's forced command, or a member's own laptop. The prerequisites are:

- the `mini` binary (Unix);
- a reachable Host Unix socket (`SOCKET`);
- the minidregg Host binary present locally when continuity is enabled. A remote workspace needs `--verifier LOCAL-HOST` (`receipt_continuity.rs:895-900`), and the verifier's SHA-256 is pinned in `enabled.json`;
- `/usr/bin/curl` only for the connector;
- coreutils `timeout` only for the studio preview.

No setuid, seccomp, bwrap, cgroups or systemd unit is needed by this shard, and none of the units under `deploy/` launches `mini web` (grep shows only documentation mentions, `deploy/shell/DOC-VERBS.md:19`, `deploy/shell/FRIENDS.md:26,275`).

**Operator-configured.** `MINIDREGG_STUDIO_PREVIEW_CONFIG` (optional), the workspace `config` and `host` pins, and the continuity `--verifier` pin. Per-workspace secrets are created on first use and must be backed up with the workspace. Losing them is refused, never silently regenerated (`protected_document.rs:176-178`, `app_document.rs:144-149`):

- `protected-documents/storage.key` plus `keys.json` (device private keys and epoch keys);
- `app-documents/storage.key`;
- the workspace signing key;
- `receipt-continuity/*`.

**Dangerous to expose.**

- `mini web`'s port. It is loopback-only by construction. If an operator forwards it, say with `socat` or a reverse proxy, the gate refuses foreign `Host` headers (421), which blocks naive proxying. Anyone holding the per-launch URL gets the member's full read authority and the POST forms. The forms submit signed document edits, creations and annotations under the member's key (`web/editor.rs:117`, `web/create.rs:45`, `web/editor.rs:232`). There is no per-form CSRF token. Protection rests on the path secret, the exact `Origin` (`web/editor.rs:28-30`) and `Sec-Fetch-Site`. Recommended practice is `ssh -L` only, as the code itself says (`web.rs:114`).
- The secret is printed to stdout (`web.rs:80-83`). Do not run `mini web` under a log collector.

**What a stranger can exercise.** Nothing in this shard listens on a public interface. A stranger reaches only the Host operations that the Host itself exposes, which are shard A's and the Lean receivers' concern.

**What a malicious enrolled member can exercise against others:**

1. **Render DoS on shared documents** (F2): one malformed `mini-name` link breaks every reader's `doc show`, web page and search for that document.
2. **Terminal injection** (F1) against readers of `doc history` and `doc diff`.
3. **Name rebinding.** A member with write access to a room's index can rebind `ROOM/NAME` to another cell. A victim who resolves the name gets a target-pinned reference with the room grant attached as candidate authority (`shared_names.rs:400-414`) and with any local direct grant to that target borrowed (`shared_names.rs:337-363`). If the room grant covers the substituted cell, which holds for cells born in the room, the victim's next write lands there. That cell's law may expose it more widely. `check_opened_views` guards consistency (`shared_names.rs:474-507`), not intent. Mitigation: display the resolved target and its law before writes (outside this shard).
4. **False provenance through the connector.** A malicious app server can claim arbitrary Mini operation, transaction and event IDs in the receipt header. They are embedded as document text (`app_document.rs:554-566`) and never checked.
5. **XSS against the web face.** I found no path. Every member-authored string is escaped (`render/html.rs:32-206`, `web.rs:293-306` and its use sites). Search snippets are escaped (`web/search.rs:154-159`). The CSP forbids script outright (`web.rs:1003`). Unescaped injections (`web/editor.rs:426-427`) carry only Rust-generated, escaped HTML retained in private custody.
6. **Protected documents.** A removed member keeps everything already disclosed. The doc says so (`docs/contracts/protected-authored-fragments.md:41-43`). A malicious owner can withhold keys from anyone; that is owner discretion. A member who is a keyholder can publish wraps that make comments unreadable but cannot substitute bodies (`docs/contracts/protected-authored-fragments.md:22-26`; enforced by `protected_fragments.rs:57-63`).

---

## 8. Questions for the Lean side

Each question is phrased so it can be answered by pointing at a declaration.

- **Q8.1 (S3).** Where does the kernel compute the `credits` that a `computeFunding` payload must carry for a non-objective method run? Does `RunComputeBudgetDomain.prepare`, or the `DeclaredResourceController` arm for `computeFunding` (`Kernel/DeclaredResourceController.lean:1140`), refuse a payload whose `credits` is not `max(0, steps − (freeSteps − usedSteps)) × creditsPerStep` against the signed `ComputeQuote` (`Kernel/RunComputeView.lean:16-25`)? If yes, name the declaration. If no, `world_kind.rs:460-487` is the decision.
- **Q8.2 (S4).** Is "kind revision strictly increases" an intrinsic check in the kind-definition receiver (which declaration?), or only expressible by a law over `kind/kind/revision/before` and `kind/kind/revision/after` (`Kernel/WorldKindProjection.lean:118-126`)?
- **Q8.3 (S6).** Which declaration validates an audience phase transition (enroll: epoch 0, parent 0, mode active; freeze: parent := transition, mode frozen; resume: epoch + 1, mode active, manifest commitment non-zero) when `install-source` carries a new `audience` extension? Does it check that the resume's roster, devices and audience digests equal the roster checked by `objectAudienceRosterLoaded`?
- **Q8.4 (S8).** Does the content receiver check a sealed text atom's clear-prefix binding (`tag ‖ atom ‖ seq ‖ prev`, `protected_atoms.rs:3-12`)? Specifically: `seq = 0` exactly at create, and on an edit `prev =` the before-record revision. Or are rollback and equivocation detected only by clients (`protected_atoms.rs:67-92`)?
- **Q8.5 (S10, F3).** Can op 151 (or a sibling) return an inclusion opening proving that the accepted record at `acceptedCount` carries a given `transactionId`/`eventId`? If such a declaration exists in `Kernel.ReceiptContinuity` or `Host.ReceiptContinuity`, name it, so that `finish_attempt` can bind a confirmation to its call rather than to a point.
- **Q8.6 (F2).** Should `Kernel/ContentResource.lean` refuse non-canonical `mini-name` external links in every content document? That is, should `sharedNameAt` (`:1782-1788`) validate the `KIND/ID` path, the canonical decimal and the kind set, so that the Rust renderer's strictness (`shared_names.rs:49-93`) cannot be weaponised? Or is there a declaration that already does this?
- **Q8.7 (S5).** Is there a Lean `carryFormatting` semantics planned? Otherwise, which declaration owns "a carried mark is an exact copy of a live source mark on the same atom" (`protected_format.rs:119-200`)?
- **Q8.8 (S2).** Is the ROOM-SCHEMA v2 field assignment (1001-1012 fixed fields, roster tail from 2000) declared anywhere in Lean, such as a room template or a `Compiler/*` registry? Or is `room_schema.rs:27-55` its only definition?
- **Q8.9.** For ops 131, 132 and 134 (fnDispatch), what are the exact request and response encodings and the refusal byte? Rust sends `u32le(len) ‖ jam ‖ ABI JSON` for 131 (`world_kind.rs:608-612`), ASCII decimal for 132, and JSON for 134. It treats any first byte other than the opcode as a refusal (`world_kind.rs:418-422`).
- **Q8.10.** Does the receiver for `computeFunding` re-read `expectedPayerBalance` and `expectedBookRoot` as CAS guards (`world_kind.rs:449-456,483-485`)? Which declaration?
- **Q8.11.** Does `object-audience-roster` (`NativeHost.objectAudienceRosterLoaded`) also verify that every package in the later resume manifest wraps to a roster device? Or does the source bind only the manifest commitment and roster digests, leaving "no extra packages" to an honest dealer (`object_epoch_packages.rs:1-3`)?
- **Q8.12.** Op 151 refusals return `(255, "receipt continuity request refused")` without the inner reason (`Host/Main.lean:6734`). Is that deliberate, to avoid disclosure? If not, which reasons could be safely returned?
- **Q8.13.** For `inspect view-document` (`Host/Json.lean:5941`, `documentJson`): is a transclusion's `render.view = "moved"` produced only by the Host, or is the client's rewrite at `workspace.rs:1952-1955` (after a refused `at` read) the sole producer of `moved` together with `atRefused`? If the latter, it should become a Host view over the refusal frame.
