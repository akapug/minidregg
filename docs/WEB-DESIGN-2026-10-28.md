# Mini's web face — 28 October 2026

Mini should feel like a small, inhabited place: readable documents, useful tools,
conversations and clear decisions. The visual system uses warm paper, forest green,
quiet borders and generous space. The public entrance explains what is here and
invites exploration before joining.

## One rendering path

`native/mini-web/assets/app.css` is the shared stylesheet. The gateway loads its
content-addressed URL synchronously in the head; the join door and direct document
reader inline those same bytes. Their old independent styles are removed. System
fonts and a small CSS brand mark require no asset provider or network font request.

The front page composes `Site::doc`, the existing operations `tail`, and the same
`apps search --json` gallery as the market. It does not copy a welcome document or
invent activity. Failed reads keep their explanations; a failed front-document
read is logged for the operator and falls back to the published-reference index.
The command grammar still provides the field types, names, alternatives, confirmations and outcome classes;
this change groups each label with its control and improves their shared presentation.
Stories and programs continue to fill the real grammar forms. Authority, admission,
exact retry and the distinction between refusal and uncertainty stay in their
existing paths.

## Visual system

| Element | Choice |
| --- | --- |
| Text | System sans, 16 px / 1.6; metadata about 13.6 px; monospace only for identifiers, code and transcripts |
| Reading | System serif, 18.4 px / 1.85, maximum 48 rem; line identities, marks, annotations and quotations remain visible |
| Hierarchy | Section titles 22.4 px; page titles up to 38.4 px; serif landing headline 44.8–80 px |
| Light | Paper `#faf9f5`, surface `#fffefa`, ink `#242e2b`, secondary ink `#58645e`, accent `#246356` |
| Dark | Paper `#171e1b`, surface `#1d2721`, ink `#e7ece3`, secondary ink `#afbcaf`, accent `#a1d4bb` |
| Decisions | Admitted green, refused red, undecided amber; always named in text and accompanied by the existing explanation and next actions |
| Spacing | 16 px phone gutters, fluid desktop gutters up to 40 px; 16–32 px component gaps; 12 px card corners |
| Controls | Visible labels, distinct control borders, 44 px primary controls, 3 px keyboard focus outlines; native details for reference material |
| Layout | A single pane uses the available width. Multiple panes retain the workspace behavior. At phone width the rail scrolls horizontally and content becomes one column. |

Across the three neutral backgrounds, the text tokens measure at least 5.28:1 in
light mode and 7.30:1 in dark; control borders measure at least 3.09:1 and 4.61:1.
These are token contrast measurements, not a claim of a complete accessibility audit.

Dark mode follows `prefers-color-scheme`. The server emits the pane header geometry;
the head script selects enhanced layout before the body paints. No font loading or
animation is required. Without JavaScript, navigation and forms remain ordinary
links and server requests. With it, activity refreshes independently of the landing
page, and edited form values pause refresh even after focus leaves the field.

## Places

| Place | What a visitor finds |
| --- | --- |
| `/` | What Mini is; Join and Tour; the published welcome document (or published-reference index); observed operations; the complete featured catalogue grouped by primary category; links to rooms, stories, receipts and laws |
| `/doc`, `/doc/NAME` | Published references and a quiet reading page; history, source and authored context stay available |
| `/room`, `/room/NAME` | Reference cards, room resources and members, conversation and its labelled composer; resident access remains attached to the room |
| `/story` | Invitations before ongoing stories, then the real join/enter/invite actions; an explicit empty state |
| `/apps`, `/apps/ID`, `/grain` | Featured apps followed by the rest of the index; text search and category filtering; human descriptions and package-bound agent declarations; full package details, install and the member's installed apps |
| `/bend` | Running programs, the decisions they await, and a form to read another activity |
| `/room/NAME/resident` | Room-granted tools, founder controls, assignment and signed replies; Oracle refusals still explain the missing grant or configuration |
| `/join` | The same visual language around the existing hosted-account, funding, key, consent and enrolment choices |
| Receipts/refusals | A prominent named outcome, highlighted clause, readable explanation, and the existing receipt/retry/next links |

## Screenshots and evidence

Captures use Chromium through Playwright on `dregg-build`, serving HTML from the
actual renderers with fixture observations. They are design previews, not evidence
that this branch is deployed at `demo.dregg.online`. The document and resident
captures exercise the shared reading and permissions components. The join capture
is the real door renderer with a free-seat fixture. Desktop is 1440 × 1050 in light
and dark; phone is 390 × 844 **with JavaScript disabled**.

Before captures preserve the interrupted run's renderer output at `337011981`.
Its front fixture uses the reference index; the after fixture also supplies a welcome
page through the real document renderer and the new composition. All other paired
screens show their corresponding renderer surface; no screenshot is a hand-drawn UI.

| Surface | Before | After | Dark / phone |
| --- | --- | --- | --- |
| Entrance | [before](web-shots/before-front-light.png) | [after](web-shots/after-front-light.png) | [dark](web-shots/after-front-dark.png) · [phone](web-shots/after-front-phone.png) |
| Apps | [before](web-shots/before-apps-light.png) | [after](web-shots/after-apps-light.png) | [dark](web-shots/after-apps-dark.png) · [phone](web-shots/after-apps-phone.png) |
| Filtered app | — | [after](web-shots/after-apps-filtered-light.png) | [dark](web-shots/after-apps-filtered-dark.png) · [phone](web-shots/after-apps-filtered-phone.png) |
| Agent interface | — | [after](web-shots/after-apps-interface-light.png) | [dark](web-shots/after-apps-interface-dark.png) · [phone](web-shots/after-apps-interface-phone.png) |
| Reader | [before](web-shots/before-reader-light.png) | [after](web-shots/after-reader-light.png) | [dark](web-shots/after-reader-dark.png) · [phone](web-shots/after-reader-phone.png) |
| Rooms | [before](web-shots/before-rooms-light.png) | [after](web-shots/after-rooms-light.png) | [dark](web-shots/after-rooms-dark.png) · [phone](web-shots/after-rooms-phone.png) |
| Stories | [before](web-shots/before-stories-light.png) | [after](web-shots/after-stories-light.png) | [dark](web-shots/after-stories-dark.png) · [phone](web-shots/after-stories-phone.png) |
| Programs | [before](web-shots/before-programs-light.png) | [after](web-shots/after-programs-light.png) | [dark](web-shots/after-programs-dark.png) · [phone](web-shots/after-programs-phone.png) |
| Resident | [before](web-shots/before-resident-light.png) | [after](web-shots/after-resident-light.png) | [dark](web-shots/after-resident-dark.png) · [phone](web-shots/after-resident-phone.png) |
| Refusal | [before](web-shots/before-refusal-light.png) | [after](web-shots/after-refusal-light.png) | [dark](web-shots/after-refusal-dark.png) · [phone](web-shots/after-refusal-phone.png) |
| Command form | [before](web-shots/before-command-light.png) | [after](web-shots/after-command-light.png) | [dark](web-shots/after-command-dark.png) · [phone](web-shots/after-command-phone.png) |
| Join | — | [after](web-shots/after-join-light.png) | [dark](web-shots/after-join-dark.png) · [phone](web-shots/after-join-phone.png) |

Reproduce the after fixtures with the opt-in `design_preview` tests, in order:
resource-client, mini-door, mini-web, with `MINI_WEB_PREVIEW` pointing to one scratch
directory and `MINI_WEB_CATALOGUE` pointing to a captured market index JSON. The preview uses the production index parser, featured ordering and JSON projection. Then run `node scripts/web-design-shots.mjs FIXTURE_DIR after`.
`PLAYWRIGHT_PATH` overrides the default Mac tool path on Linux.

Initial redesign verification on `dregg-build`, in `/build/lanes/cx-web`, with its own target copied from
the warm web-parity target and all Rust builds under `swarm-build`:

- 49 filtered renderer/web tests passed; after the final gallery edits, all 6
  affected app/escaping tests passed again. Gateway: 6 passed, including the real
  helper's login, terminal, CSRF/logout and inert-body flow. Door: 7 passed.
- 57 screenshots: 27 before and 30 after. All 30 after layouts have no page overflow
  or unlabelled fields and request no external resources. Keyboard skip, pane
  navigation/close, independent activity refresh and an edited form after blur pass.
- The layout checker rejects an injected oversized, unlabelled input. The keyboard
  check first caught the skip anchor opening an extra pane; restricting workspace
  restoration to actual paths fixed it.
- **FOUC: 12/12 app and 12/12 site cases pass**, light and dark, with CPU throttling
  and slow networking ([results](web-shots/fouc-checks.json)). The terminal first
  failed: its independent xterm color and startup row height changed its paint.
  Reading the CSS token and defining its container height fixed both causes.

No JWF or `check-fouc` assertions were changed or weakened; form field names,
action URLs, outcome classes and story/tool data attributes retain their existing
meanings and matching shapes.

**JWF: 62/62 PASS**, including the Chromium tour, on a fresh J0–J8 world using
candidate `76758dba687cde9447bc45d77931bb7d57527e56`'s Host and this lane's Rust
binaries. Parity covered **74 verbs / 216 leaves**,
with zero usage or world refusals. The scratch world has no market index; its public
page displayed that explained read error. Catalogue visuals use the renderer fixtures;
this run does not establish catalogue deployment. The full evidence remains under
`/build/lanes/cx-web/scratch/tour-1793183232`.

The initial redesign was committed and pushed as `7c4ecd454` by the parent after the Mac sandbox refused the Git index lock. Checks ran on the build box.


## Catalogue breadth follow-up

The landing page renders every entry marked featured by `apps search --json`, grouped
by its first catalogue category. `/apps` places featured entries in their declared
rank order, followed by the rest of the index. Category choices come from the real
catalogue; submitted text and category go through `apps search TERM --category C`.
Both controls and typed-operation disclosures work without JavaScript.

The resource client's build discovers `apps/interfaces/*.json`; `apps search` and
`apps show` include operation names, descriptions and input/output types from matching
`mini-app-interface-v1` declarations. Matching requires **both app ID and package ID**.
Missing declarations are omitted. Cards show the declaration's status, including
`prototype-unqualified`, separately from the package verdict. This is a description
of the interface, not a claim that its qualification succeeded. The initial Davros,
Gogs and Wekan files are the exact declarations from `origin/lane/cx-app-interface` at
`74a964e9fbbb7f86cae1e52169ea4240a7c5c594`;
there is no second app-name or operation list in the renderer.

New regression checks first failed on the three-card cap and the missing category
argument. The breadth check supplies 36 featured entries and one ordinary entry,
so growth of the featured set cannot reintroduce a sampler silently.

Follow-up verification on the existing `7c4ecd454` lane base: nine filtered Rust
checks pass; 33 base page/viewport layouts pass, plus three expanded agent-interface
captures. Text/category submission and disclosures pass in light, dark and no-JS
phone contexts. Adding the landing search exposed startup focus stealing the skip
link; startup and quiet refresh now preserve focus, and the unchanged keyboard check
passes. The final script passes all 12 app FOUC cases; the unchanged site passes 12.

The initial catalogue captures used a 36-entry observation and 17 featured ranks.
The merged previews now use main's recorded 98-entry index through the production
parser and JSON projection, including all **27** featured apps. No count is built
into the UI. These are renderer previews, not evidence of deployment.

The follow-up JWF tour passed **62/62** on a fresh world against the same candidate
Host, with the new catalogue code and unchanged JWF assertions; full output is in
`/build/lanes/cx-web/scratch/catalogue-tour-1793205820`. A subsequent receiving-path
check found the real catalogue JSON is 68,929 bytes, above the body's old 64 KiB
transcript cap. The shared capture now retains grammar-declared JSON read replies
whole up to 8 MiB, explains larger replies, and bounds pipe-buffer retention. Text
diagnostics retain their 64 KiB cap, now on a UTF-8 boundary. Both JSON-limit checks
failed with the old capture and pass with the fix. The gallery's fake-shell tests
now use the same capture function as real shell completion, including a catalogue
over 64 KiB, rather than bypassing it.

Final capture verification: **13/13** filtered client checks and the release build
pass. A real HTTP request through `mini web --body` → `mini shell` → `apps search`
renders all **36** index entries and **three** package-bound interfaces; a combined
`q=Gogs&category=DevTools` request returns one card. The test uses a private mount
namespace to supply `/var/lib/mini-market/index.json`, leaving the host catalogue
untouched. The body still clears its child environment. The pre-merge JWF run
above predates the final capture fix; merged-tree evidence is recorded below.
Its test services were stopped.

## Main integration

The parent committed the catalogue work as `28792cd4e` and initiated the merge of
`a134d13da2b3c200f29ed74b81a105bf0175d276`. The front-document conflict preserves
main's failure logging, reference-index fallback and navigation, composed inside
the redesigned entrance. Main's public-read cost bound, grant refresh imports,
market verdict identity and expanded featured set remain intact. The JWF source
is unchanged from the merge input; no assertions were edited during resolution.

The Mac sandbox permits source edits but not Git metadata writes. The parent
will stage the named files and finish this already-started merge; this lane does
not run Git mutations.

Merged-tree validation runs in `/build/lanes/cx-web`, reusing its warm Rust target,
with every build under `swarm-build`. The filtered client checks pass **83/83**;
gateway checks pass **6/6**, including login and terminal flow; door checks pass
**7/7**. Logs are `scratch/merge-{web-final-tests,page-tests,door-tests}.log`.

The release build and all three preview generators pass. Refreshed captures show
**27 featured landing cards**, **98 market cards**, and three package-bound agent
interfaces; the combined Gogs/DevTools query renders one card. All **33** base
layouts and three expanded-interface captures pass, including category submission,
keyboard navigation, independent activity refresh and dirty-form retention. Phone
captures disable JavaScript. All **24/24 FOUC cases** pass (12 app, 12 site), with
no flash or first-paint problems; the updated measurements are in
[the FOUC results](web-shots/fouc-checks.json).

A real HTTP receiving-path check also passes with the merged client and the full
recorded index: **27** landing cards, **98** market cards, **three** matching
interfaces and **one** Gogs/DevTools result. Its private mount supplies the default
index path without altering the host catalogue ([result](web-shots/catalogue-receiving.txt)).

The first merged JWF run exposed a verification-command error: `--bin mini`
restricted a multi-package build and left an older `mini-web-spawn` binary in use.
Its `public-republish` row failed, correctly detecting the old publication handoff.
Building `mini-web-spawn` explicitly picked up main's newest-publication selection;
the app/site FOUC rerun with that helper passes **24/24**. Main's current JWF script
has **69 rows**, including seven added since the original 62-row run. No JWF
assertions were changed during this integration.

The final merged JWF run passes **69/69**, including public republishing and the
Chromium tour, against candidate `9bd52317c34252028d62db31708516d396716281`'s Host
and the merged Rust binaries ([rows](web-shots/jwf-results.tsv)). Parity covers
**74 verbs / 216 leaves**, with no missing faces or usage/world refusals. The final
public entrance returns **200**; this scratch world's absent market index is
explained on the page. The separate receiving-path check above supplies the full
index and verifies the complete gallery. Full JWF evidence is retained in
`/build/lanes/cx-web/scratch/merge-tour-final-1793210027`. All test services and
retained residents were stopped by recorded, command-checked PIDs; no lane
executables remain running. There are no outstanding verification failures.
