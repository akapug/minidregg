# The demo, as a stranger meets it

Present-state product definition, 2026-10-27. This is what `https://demo.dregg.online` is *for*:
the fifteen minutes a stranger spends in Mini and what they understand at the end. The join page,
the front page, the README's honest-state table and the demo journey are derived from this file,
in that order of authority; when the product changes, this file is rewritten whole. The plan
(`docs/DEMO-PREFIX-2026-10-26.md`) says how we get there; this file says what "there" is.

## 0. The thesis the demo has to make visible

Mini is **one shared world in which people, applications and agents act under one set of
machine-checked rules, and every act leaves a receipt that explains itself.** Nothing else a
stranger has used does that. Every ordinary hosting platform shows them a result; Mini shows them
the *judgement*: admitted, refused with the clause, or undecided with the exact retry. The demo
succeeds when a stranger can say, unprompted, "the agent couldn't do that because it only held a
grant for my one document, and I can see the receipt where it tried."

So the demo is not a list of surfaces. It is one tour in which the kernel's judgement is visible at
every step, and every surface (browser, ssh, Discord, an app on its own origin, a resident, the
oracle, the box's own operations) is a different door into the *same* world with the *same* rules.

## 1. The tour (fifteen minutes, from a browser, nothing installed)

Each step names the verbs behind it and the lane that lands it. Status words: **live** (on the
demo box now), **landing** (on a lane branch, in integration round 2), **needs** (named work not
yet in a lane).

| # | the stranger… | …and sees | verbs | status |
|---|---|---|---|---|
| 1 | **lands** on `demo.dregg.online` | the world as the `public` subject may observe it: published documents, the laws page (the operation registry, the consent plans, the theorems by name), the receipts stream, the box's own operations room (§2), the shutdown date (11 Nov 2026), the world-readable sentence; nano's testground linked as the sibling rebuild | public reader through the gateway (`mini web --body` as `mini-pubread`) | landing (L12 `lane/web-frontend`) |
| 2 | **joins** in one minute | the door: a name, optionally an ssh public key, optionally "link Discord", optionally pay-to-enrol (Solana; devnet default). Without an ssh key the box makes a hosted key and the door answers a one-time **Open your session** link. The free route says how many seats remain and closes visibly when the sponsor's cap is hit | door front + root processor; hosted `keygen`; `mini-reenroll`; `mini-web-spawn login CODE` | landing (L5 `lane/door` + L12); **needs**: the ssh key made optional in the door form so a browser-only stranger can join |
| 3 | **writes** | a new document, an append, a link to another member's published document, a transclusion that renders inline; after every action the **outcome partial**: admitted, at height *h*, world root, the receipt link | `doc new/append/link/transclude`, `history` | landing (L12 over L7's render fixes) |
| 4 | **is refused, and reads why** | they try to edit a document they do not own: **refused**, with the clause of the law that refused it; `can` shows which verbs would pass on that reference; `why` explains the last refusal in the kernel's words | `can`, `why`, `inspect law` | exists (J12A, K10C); landing in the browser (L12 Grants & laws, Receipts) |
| 5 | **delegates, bounded** | a narrower grant on one document, append only, expiring at a height, to another member; they revoke it; both are receipts; the other member's attempt after revocation is refused with that clause | `delegate`, `revoke`, `renounce` | exists (J12); landing in the browser (L12) |
| 6 | **summons an agent** (the centrepiece) | a Hermes resident into their room with a budget; they ask it to read their document and post a summary; its turns land as **paid, admitted writes** with receipts; the purse drains visibly; they ask it to edit a document it has no grant for and watch the **`no-grant` refusal** land as a receipt too; `dismiss` refunds the remainder, as a receipt | `summon`, `ask`, `tail`, `dismiss`; the resident's `mini_say`, `mini_doc_append` through the key broker and the OpenRouter pool row (BYOK rows for the operator) | landing (L4 `lane/hermes`: units that open, one creation path; L7's summon fix; hot-path); **needs**: the room resident (runtime C) run once against the real pool route (`HERMES-LIVE`), and L1(c)'s four-class settle before the pool route is public (R4) |
| 7 | **installs an application** | `Apps`: the Sandstorm store index; they install Etherpad or EtherCalc or any other SPK; the grain opens on its own origin `<grain>.demo.dregg.online` in a pane beside their documents; its grants are Mini capabilities they can read on the Grants page; a second browser co-edits | `mini apps search/show/install`, lifecycle v3, L3's per-call fence | landing (L13 `lane/app-market` increment 2: the bridge vocabulary so Etherpad/TT-RSS admit; L3 `lane/fence`) |
| 8 | **asks the oracle** | the veri7vn grain: a question, an answer with its evidence and the machine-checked function it rests on | the oracle SPK on the same admitted grain path | needs (ember's codex session: shared-data contract, signed package, acceptance journey) |
| 9 | **links Discord** | `/mini link CODE` in Wyrmware; `/mini say` from Discord lands as their turn and appears in the web room; refusals come back as the clause, never as a retry | the entrance in gateway mode, the roster rendered by the door's root processor | landing (L5: gateway mode in progress; infra egress ready) |
| 10 | **opens the terminal** | `mini shell` in the page (xterm.js, vendored), or over ssh with the key they gave; the same verbs, the same receipts | `mini-web-spawn shell`, sshd | landing (L12); ssh live (closed until opening) |
| 11 | **plays** | a story room: collective fiction under a law the author sealed; the Lean theorem (`sealed_story_scene_monotone`) is the rule of the game | `story`, `look`, `go`, `take`, `act`, `narrate` | exists (J15 lane evidence); needs a row in the demo journey |
| 12 | **reads the operations room** (§2) | the box's own ships, drills, certifier ticks and backup receipts as signed turns of the box's member; the published performance numbers read from the same world | the fleet/turn path; `ship.sh` posting | needs (S) |

Everything a stranger can do, they can do from the browser with no JavaScript (whole-page forms),
with JavaScript as panes on one stage, over ssh, and (rooms and documents) from Discord. One world,
one set of rules, one design language (`docs/WEB-FRONTEND-2026-10-27.md` on `lane/web-frontend`).

## 1a. Parity: everything the shell can do, the browser can do, visually

Ember's ruling (2026-10-27): "everything that can be done over ssh and commands can also be done
visually and via the web interface." The terminal pane is a convenience for people who like
terminals, never the mechanism by which a verb reaches the browser. The rule, stated so it can be
checked rather than remembered:

- **Every `mini shell` verb has a visual face**: the verb table in `native/resource-client/src/shell.rs:54-107`
  plus `chat.rs`, `hermes.rs`, `story.rs` is the authority, so about 54 verbs, the ~40 `doc` subverbs,
  rooms and chat, Hermes (`summon`/`ask`/`dismiss`/`hermes status`), story, member kinds and programs
  (`kind`/`program`/`instance`), markets and jobs (`market`/`bid`/`reveal`/`bids`/`job`/`jobs`),
  keys (`key-status`/`rotate-key`/`adopt-next-key`), the attempt lifecycle (`propose`/`submit`/
  `lookup`/`retry`/`publish`/`history`), `can`/`inspect`/`why`/`renounce`, `refs`/`describe`/
  `import`/`export`/`inbox`, `pay`/`credit`/`tariff`/`topup`, `app`/`home`/`key`/`channel`.
- **The faces are derived, not hand-written per verb** (ATLAS: the derived path is the only path). The
  shell already holds each verb's arguments and help text; the web body renders a form from that
  table (argument → field, reference arguments → pickers over `refs`, outcomes → the one outcome
  partial), and only the places that deserve a bespoke view (a document page, a board, a room, a
  receipt, the grants graph) get one. A new verb is visual the day it exists.
- **A parity row in the demo journey** (`jwebparity`): the shell's verb table against the body's
  routes; a verb with no face is red by name. The terminal pane does not count as a face.
- **Visual means visual**: the grants a member holds are drawn as a graph (capability, scope,
  expiry, ancestors) and delegation is done on it; a document's history and diff are pages, not
  escape codes; a room is a live stream; a purse is a meter; a refusal is the clause, highlighted.

## 2. The box is a member

The demo box holds a key of its own (`mini-s-box`, a hosted member like any other) and posts its
operations as signed turns into a public **operations room**: each rehearsal ship (candidate hash,
the reds named in the notice), each restart and certifier drill, each backup archive's digest and
restore check, the clock's tick, the performance numbers measured on the box. The join page and the
front page render that room; nothing on them is written by hand. A stranger who doubts the system
reads its own operations log as receipts in the same world they are standing in. Our own fleet's
land-receipts post to the same room once the fleet row is on the box (`m8`): the fleet that builds
Mini coordinates in Mini, which is the north star in `CLAUDE.md`.

## 3. What the stranger understands at the end

1. **Authority is explicit and inspectable.** Every grant is a capability with a scope and an
   expiry; `can` answers before an attempt; `why` answers after a refusal; delegation narrows.
2. **Agents are members, not administrators.** A resident acts under the same laws, pays for every
   write from a visible purse, holds no key, and is refused like anyone else.
3. **Applications are tenants of the world.** An app from the Sandstorm store runs on its own origin
   with grants it cannot widen; the world's rules sit between it and everything else.
4. **Nothing is lost in the gap.** A lost reply is undecided, never a second attempt; the exact retry
   is a link on the receipt.
5. **The system runs under its own rules.** The box's operations are receipts in the world.

## 4. The ambitions beyond the plan's lanes, ranked by what they buy the tour

| # | ambition | buys | size | owner |
|---|---|---|---|---|
| A1 | **Browser-only join** (ssh key optional; hosted key; one-time session link) | step 2 for everyone with a browser | S on L5's door + L12's login code | L5 |
| A2 | **The agent-under-law moment live**: runtime C resident through the broker and the pool route, `HERMES-LIVE` green on the demo box | step 6, the centrepiece | M; depends on L4 landing + L1(c) | L4 (veteran) |
| A3 | **The operations room** (§2): `mini-s-box`, `ship.sh` posts, drills post, the front page reads it | steps 1 and 12; the "published, never a gate" numbers published *in the world* | S–M | infra lane + a `mini` verb call per ship phase |
| A0 | **Verb parity in the browser** (§1a): forms derived from the shell's verb table; the grants graph, history and diff pages, room stream, purse meter; the `jwebparity` row | every step of the tour, visually, and ember's ruling made checkable | M | L12 |
| A4 | **`/tour`**: the twelve steps as one guided page whose forms are the real forms; the demo journey's `jtour` row is the same tour driven headless (Playwright) and asserting each outcome partial | one artifact that is onboarding, acceptance and the README's honest table at once | M | L12 after its first landing |
| A5 | **Any app, really**: Etherpad, TT-RSS, Wekan, Rocket.Chat from the store index; the bridge vocabulary complete | step 7's "any" | in flight | L13 |
| A6 | **The oracle grain** on the admitted grain path | step 8 | M–L | codex session |
| A7 | **Story and markets rows** in the demo journey (`story`, `market/bid/reveal`, `job`) | steps 11 and the "programmable" claim | S each | L9 |
| A8 | **Member-defined kinds** (`kind`, `program`, `instance`) shown once in the tour: a member authors a kind and a law and instantiates it | "programmable shared world" demonstrated, not claimed | M | needs an owner after opening |
| A9 | **The second node**: fn exchange from the demo box to nano's or pug's node across machines | the "re-genesis on the homelab" story begins before shutdown | M | L8 after opening |

The order of landing is the plan's (Lean first, the integration build, rehearsal #2); A1–A3 are
small enough to ride rehearsal #2 or #3, and A4 is the acceptance of the whole.

## 5. What this file is not

It does not claim any step has run for a stranger. The status column is the claim; the demo
journey's rows on the candidate that ships, and the box's own operations room, say the rest.
