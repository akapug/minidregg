# The demo, as a stranger meets it

Present-state product definition, 2026-10-27, rewritten whole after a three-model council (GLM-5.3,
Kimi k3.1-pro, Astra/codex; `docs/review/2026-10-27-council-experience/`) read the first draft against
the affordance inventory, the web front end design, the shell's verb table and the ATLAS laws. This is
what `https://demo.dregg.online` is *for*: the minutes a stranger spends in Mini and what they
understand at the end. The join page, the front page, the status table (`docs/STATUS.md`) and the demo
journey derive from this file, in that order of authority; when the product changes, this file is
rewritten whole. The plan (`docs/DEMO-PREFIX-2026-10-26.md`) says how we get there.

## 0. The thesis the demo has to make visible

Mini is **one shared world in which people, applications and agents submit writes to the same
Lean-owned admission path**: an admitted write yields a durable world root, a refusal is explained
by the clause that refused it (and by the request that would have passed), and an attempt whose reply
was lost stays undecided and retains its exact retry, so nothing is ever done twice. Documents,
authority, money, programs and applications share that one path; a computation can propose a change
without acquiring permission to make it (README: "computation proposes; authority admits").

In the literature's terms (SYNTHESIS §E): an object-capability world (a reference is not ownership;
authority only by designation; revocation by interposition) whose reference monitor is a Lean function
with theorems, where every effect a computation may propose is a typed request the authority admits,
over an authenticated append-only log. What a stranger has not met before is the *composition*, and
three moments make it tangible:

1. **A refusal is actionable.** `why` names the clause and the slot values; `can --any` answers with
   the one request the law would admit from the current values, as a line to paste. Every other system
   says no; Mini hands back the yes.
2. **An agent is a member.** A resident acts under the grants it was given, pays for every write from
   a visible purse, holds no key, and when it oversteps the refusal lands as a receipt like anyone's.
3. **A lost reply is not a second attempt.** Lose the reply to a write on purpose; the outcome is
   undecided, amber; the exact retry is one link; the world shows one effect and one charge.

The demo succeeds when a stranger can say, unprompted, "the agent couldn't do that because it only
held a grant for my one document, and I can see the receipt where it tried." It is honest about its
own scope: "machine-checked" names the admission path's theorems, not every deployed behaviour (plan C1
still names the receive-path gap).

## 1. The tour: a spine and six doors

Everything below is from a browser with nothing installed. The **spine** (steps 1–7) is the
fifteen-minute script and the acceptance row (`jtour`); the **doors** (8–13) are reached from it and
are not required of any visitor. Status words: **live** (on the demo box now), **landing** (on a lane
branch, in integration round 2), **needs** (named work not yet in a lane).

### The spine

| # | the stranger… | …and sees | verbs | status |
|---|---|---|---|---|
| 1 | **lands** | one live admitted/refused pair with its world root on the front page, not an inventory: the public world (what members published), the laws page (the operation registry, Lean's emitted default laws, the theorems by name), the receipts stream as the `public` subject observes it, the operations room (§2) linked, the shutdown date (11 Nov 2026), the world-readable sentence; nano's testground linked as the sibling rebuild | public reader (`mini web --body` as `mini-pubread`) | landing (L12; the receipts stream and the operations-room render are L12's next batch) |
| 2 | **joins in a minute** (unmeasured until `jtour` measures it) | the door: a name; nothing else required. The box makes a hosted key and shows one **Open your session** link. ssh key, Discord link and pay-to-enrol (devnet by default; a mainnet row is the opening contract's, not the tour's) are offered after, never as introductory decisions. The free route says how many seats remain and closes visibly at the sponsor's cap | door front + root processor; hosted `keygen`; `mini-reenroll`; `mini-web-spawn login` | landing (L5 door + L12 login); **needs**: the ssh key made optional in the form (L12 owns it) |
| 3 | **writes, and watches a transclusion move** | a new document, an append, a link; they transclude a live range from a published document, then (as the publisher, pre-provisioned on the tour world) edit the source and watch the transclusion change at a new height; each action ends in the one **outcome partial** (admitted, height, root, receipt link). The terminal pane shows the same attempt in `history`: one world, two faces | `doc new/append/link/transclude/edit`, `history` | landing (L12 over L7's render fixes) |
| 4 | **is refused, and gets the yes** | they try to edit a document they do not own: refused, the clause highlighted beside the attempted change; `can` shows which verbs their grants cover on that reference; `can --any` prints the one request the law admits; they paste it and it is admitted | `can`, `can --any`, `why`, `inspect law` | exists in the shell (J12A, K10C); landing in the browser (L12 Receipts, Grants & laws) |
| 5 | **delegates, bounded, to an agent** | a narrower grant on one document (verbs, max cost, and an expiry height: `delegate` must gain `--until H`; the proposal already carries `notAfter`) to a Hermes resident they then summon into their room with a budget. They ask it to read the document and post a summary: its turns land as **paid, admitted writes** with receipts, the purse meter drains. They ask it to edit a document outside its grant and watch an **attempted** write refused `no-grant` as a receipt (a tool call that was made and refused, never a model declining). They revoke the grant; the resident's next attempt is refused with that clause. `dismiss` shows pending until the refund is admitted, then the refund receipt | `delegate`, `revoke`, `summon`, `ask`, `tail`, `dismiss`; the resident's `mini_say`, `mini_doc_append` through the controller's per-task key, the key broker and the pool route | landing (L4 units and one creation path; L7's summon fix; hot-path; L1's `checkPlan` and four-class settle); **needs**: runtime C through the real pool route once (`HERMES-LIVE`) before the pool route is public (R4); `delegate --until` (S) |
| 6 | **loses a reply on purpose** | a "lose this reply" switch on the tour's write form (a client-side fault, `--lose-reply-once`, affecting only the stranger's own client): the Host admits, the client never reads the answer; the outcome is **undecided**, amber; the receipt shows the retained attempt and one link, the exact retry; they click it; the Host answers the same decided outcome; the document shows one append and the purse one charge | the custody record (L2), `lookup`, `retry` | exists in the custody machine and its crash tests (L2 554667d9); **needs**: the client flag and the tour form (S, L12 with L2's record as the mechanism) |
| 7 | **installs an application** | one named, measured app (today: Hacker Slides or Simple Todos from the real index; Etherpad qualifies on `lane/app-market` and is the target for the opening) installed by a member turn under the Lean request law, opened on its own origin `<grain>.demo.dregg.online` in a pane; its grant boundary shown on the Grants page (v1: one guest subject per grain, said on the receipt); a second browser co-edits; the store stays whole ("any SPK" is A5's bar, said as such) | `mini apps search/show/install/open`, lifecycle v3, L3's fence | landing (L13 dfc696de; L3) |

### The doors

| # | door | what it shows | status |
|---|---|---|---|
| 8 | **the oracle** | one bounded question to the veri7vn grain; the answer with its evidence and the machine-checked function it rests on, and exactly what was checked (never "the answer is proved") | needs (codex session: shared-data contract, signed package, acceptance) |
| 9 | **Discord** | for a visitor who has Discord: `/mini link CODE` in Wyrmware, `/mini say` lands as the same subject's turn in the web room; the payoff is one identity in two places | landing (L5 gateway mode; box staged) |
| 10 | **the terminal and ssh** | `mini shell` in the page or over ssh with a key they add; the same verbs, the same receipts | landing (L12); ssh live, closed until opening |
| 11 | **a story room** | the built-in tale under its sealed law; one legal move, one impossible move refused beside the theorem `sealed_story_scene_monotone` (proved for the built-in tale's generator, said as such) | exists (J15 lane evidence); needs a demo-journey row |
| 12 | **change the rules** | the stranger installs a law on their own document that refuses even them; their next attempt is refused; the resident's too; `law check` before installing says whether any write could ever pass. Then (A8) a member-defined kind with its own law and an instance of it | `law`, `law check`, `kind`, `program`, `instance` | exists (J12, P7KR); needs the browser faces (L12) and a journey row |
| 13 | **the operations room** (§2) | the box's own ships, drills, backup digests and measured numbers as its member's signed turns, with the honesty label of §2 | needs (infra, rehearsal #3) |

### Parity: everything the shell can do, the browser can do, visually

Ember's ruling (2026-10-27): "everything that can be done over ssh and commands can also be done
visually and via the web interface." The terminal pane is a convenience, never the mechanism by which
a verb reaches the browser. Stated so it can be checked:

- **The authority is a structured command registry, not the help text.** Today `Verb` is three strings
  (`shell.rs:48-52`: name, one `usage` line packing many alternatives, one prose `operation`), and
  subcommands are scraped from the usage prose. Deriving forms from that is a mirage the council named
  (three reviews, independently). The honest artifact, per ATLAS law 13 (emit, never imitate): one
  structured grammar per verb (subcommands, typed arguments, reference kinds, `@FILE` uploads,
  dangerous-confirmation flags, outcome schema) that shell parsing, `help`, completion AND the web body
  all consume. Generic forms derived from it are the default face; bespoke views (documents with
  history, diff and transclusion; grants and law editing; `can`/`why`; rooms and residents with the
  purse meter; receipts and exact retry; apps; boards; story) are built on top. Until the registry
  exists, L12's forms generated from the usage strings are the interim, labelled as such.
- **The check** (`jwebparity`): enumerate verb × subcommand across all four tables (shell, chat,
  hermes, story), require a registered route and a renderable no-JavaScript form for each, red by
  name, red-proofed by removing one route; separately, drive each spine flow and assert its decoded
  outcome. Its result is called **face coverage** until every leaf has an executed outcome test.
- **Outcomes are told truthfully.** Exit 0 is not "admitted": `whoami`, `help`, `history`, `can`,
  `inspect` are local or read answers and are shown as such; admitted / refused / undecided name
  world transitions only.
- **Visual means visual**: grants drawn as a graph with delegation and revocation done on it;
  history and diff as pages; a room as a live stream; a purse as a meter; a refusal as the clause
  highlighted beside the attempted change.

## 2. The box is a member, told honestly

The demo box holds a key of its own (`mini-s-box`, a hosted member whose private half nobody but its
own uid ever holds) with **one append-only capability to a public operations topic** and no other
reach. Each rehearsal ship (candidate hash, reds by category), each restart, certifier and backup drill
(archive digest, restore-check verdict), and each performance measurement (with its conditions) is
posted as a signed turn from an allowlisted event schema. The front page renders that room. Its label
says what it is: **the box's receipts prove the box reported these events under Mini's own admission;
they are not independent evidence the events occurred.** The reporter, its key and the system reported
on share one trust domain; the linked artifacts (backup digests in the locked bucket, the candidate's
`SHA256SUMS`) are the evidence.

What the room never contains: raw journals or notices, command lines, environment, tokens, DNS or
provider credentials, backup decryption material, session or login links, cookies, member documents or
rosters, member or agent identities from fleet receipts, unredacted failure logs, the clock's tick.
Missing ticks stay missing. The room is **output only**: fleet agents never read it as input.

## 3. What the stranger understands at the end

1. **Authority is explicit and actionable.** Every grant is a capability with scope and expiry;
   `can` answers before an attempt, `why` after a refusal, `can --any` hands back the request that
   would pass; delegation narrows and revocation is immediate.
2. **Agents are members, not administrators.** A resident acts under the same laws, pays for every
   write from a visible purse, holds no key, and is refused like anyone else.
3. **Applications are tenants of the world.** An app from the Sandstorm store runs on its own origin
   with grants it cannot widen.
4. **Nothing is done twice.** A lost reply is undecided, never a second attempt; the exact retry is
   a link on the receipt.
5. **The rules are theirs to change.** A member installs a law, and the world, including their own
   agent, obeys it from the next height.

## 4. The ambitions, ranked by what they buy the tour per day of work

| # | ambition | buys | size | owner |
|---|---|---|---|---|
| A1 | **Browser-only join** (ssh key optional; hosted key; one-time session link) | the premise "nothing installed" | S | L12 (owns the door form now) |
| A0 | **Parity through the structured command registry** (§1): the grammar as data consumed by shell and web; `jwebparity` as face coverage; truthful outcome classes | every step, visually, and the ruling made checkable | M–L (a resource-client refactor; the interim usage-string forms stand meanwhile) | L12 |
| A2 | **The agent under law, live**: runtime C through the broker and the pool route, `HERMES-LIVE` green on the demo box | step 5, the centrepiece | M; after L4 + L1(c) | L4 veteran / integrator |
| A11 | **The lost-reply switch**: `--lose-reply-once` on the client, the tour form, the undecided receipt with its one retry link | step 6; the moment every reviewer named as the one nobody has used before | S | L12 over L2's custody record |
| A4 | **`/tour`**: the spine as one guided page whose forms are the real forms, driven headless as the `jtour` row, which also measures the tour's real elapsed time (published, never a gate) | onboarding, acceptance and the README table as one artifact | M | L12 |
| A12 | **`delegate --until H`** (the proposal already carries `notAfter`) and `renounce` out of the tour | step 5's bounded grant | S | L12 (resource-client) |
| A5 | **Any app, really** (bridge vocabulary complete; Etherpad as the opening's app) | step 7's "any" | in flight | L13 |
| A7 | **Story and change-the-rules rows** in the demo journey (`story`, `law`, `kind/program/instance`) | doors 11 and 12 | S each | L9 / L12 |
| A8 | **Member-defined kinds** shown once in door 12 | "programmable", demonstrated | M | needs an owner after opening |
| A10 | **Receipts a stranger can verify**: op 151's inclusion opening on every receipt (SYNTHESIS E.10, plan C7), shown on `/receipts/ID`, with a one-line offline check against the published world root | the receipt stops being a claim the box makes about itself | M (Lean) + S | L1 after (a)–(c) |
| A3 | **The operations room** (§2) with its allowlisted schema and honesty label | door 13; the numbers published in-world | S–M | infra, rehearsal #3 |
| A6 | **The oracle grain** | door 8 | M–L | codex session; misses a redeploy cycle, not the date |
| A9 | **The second node** (fn exchange to nano's or pug's node; The fn transport is not on this demo; the exchange row runs in the nightly against a loopback peer when its image exists.) | the re-genesis story | M | L8 after opening |

A6 and A9 are off the tour's critical path (the council, three of three); the surfaces stay, as the
opening contract says, and ride the redeploy cycle they are green in.

## 5. What this file is not

It does not claim any step has run for a stranger. The status column is the claim; the `jtour` row on
the candidate that ships, and the box's own operations room, say the rest.
