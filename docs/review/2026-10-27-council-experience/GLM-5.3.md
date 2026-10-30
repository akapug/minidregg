
---

# Council review: docs/DEMO-EXPERIENCE-2026-10-27.md

**What I verified vs. not.** Read in full: DEMO-EXPERIENCE, DEMO-PREFIX §0–§2 + Phase 1 table, AFFORDANCES §0/§1.2/§3/§4, WEB-FRONTEND §1–§5 (from `origin/lane/web-frontend`), ATLAS §6, README:1-60, `shell.rs:40-124`, and confirmed the `VERBS` tables in `chat.rs:67` / `hermes.rs:54` / `story.rs:70`. I ran no journeys and inspected no lane branches other than web-frontend; "landing" statuses are taken on the documents' word, cross-checked against DEMO-PREFIX §2 where possible.

## A. Is the thesis right?

Yes, and it is better evidenced than most product theses: the judgement triad is not prose, it is the client's own exit discipline (`shell.rs:40-44`: EXIT_REFUSED=3, EXIT_UNDECIDED=4) which WEB-FRONTEND §2 already maps to the outcome partial (exit 0/3/4 → admitted/refused/undecided). The datamodel backs "one set of rules": every write is a `Turn` through `World.admit` (`World.lean:647`), capabilities carry scope/expiry/ancestors (`Theory/TypedAuthorization.lean:872`), laws are `Pred`s judged by the old law (AFFORDANCES §4). Hermes backs "agents are members": fixed catalogue, no keys, no summon tool, `no-grant` refusal with J14 evidence (`edit-refusal.json`) (AFFORDANCES §3). So §0 names something real and demonstrable.

One sharpening: what a stranger will actually be struck by is that **a refusal is actionable**. `why` returns "the request value that passes it" (`shell.rs:69`) and `can --any` returns "one write REF's law admits from its current values, **as a line to paste**" (`shell.rs:67`). Every other system on earth tells you *no*; Mini hands you the exact request that would have been *yes*. That is the sentence I would put in §0's success criterion alongside the no-grant receipt — it is more alien, in the good sense, than "admitted, refused, or undecided."

## B. The tour, step by step

Overall: the status column is honest — I found no claim outrunning DEMO-PREFIX §2 and AFFORDANCES §1.2 (e.g. step 4/5 verbs marked "main only" there are marked "exists… landing in the browser" here, which is consistent). Two exceptions and one structural problem:

- **Step 7 overshoots**: "Etherpad or EtherCalc or any other SPK" — DEMO-PREFIX §2 says Etherpad/TT-RSS are *refused today* by the bridge vocabulary (L13 increment 2 is the fix) and the journey installs Hacker Slides and Simple Todos; EtherCalc is a settled origin, not an evidenced install. The "…and sees" column promises what the status column doesn't cover.
- **Step 6 is the centrepiece resting on the one runtime with zero evidence**: AFFORDANCES §3's table shows runtime C (room resident, the purse/broker path) has journey "none"; only runtime A is journeyed, and A bypasses gateway, purse and keys. The doc says this in its "needs" cell — honest — but the tour's emotional peak is also its largest unknown. If A2 slips, step 6 should degrade to runtime A against the loopback provider *labelled as such*, not vanish.
- **Structure**: twelve steps in fifteen minutes is not a stranger's pace. Join (A1) + an SPK download/quarantine/ingest + provider round-trips is 25–40 minutes of real time. Make steps 1–6 the fifteen-minute spine and 7–12 further doors; `/tour` (A4) should encode exactly that split.

Per-step, briefly — all demonstrable within the spine/doors split except as noted: **1** honest; lands harder when the receipts stream is already alive with the fleet's own land-receipts (§2's `m8`) — a cold-open with real traffic beats any laws page. **2** honest, the `needs` (ssh-optional) is the tour's gating dependency, see E. **3** honest; the transclusion rendering inline is the wow, don't bury it. **4** honest (`can`/`why` main-only per AFFORDANCES §1.2); would land much harder using `can --any`'s paste-able line: refuse, then paste the passing request and watch it admit. **5** honest; the revoke-then-refused replay is the teeth — keep it. **6** honest but highest-risk (above). **7** fix the sentence (F). **8** merge into 7 as "one of the apps is the oracle" — it is the same admitted-grain path plus a claim; as a standalone step it is the weakest. **9** honest (gateway mode in progress; the endpoint saga is documented in DEMO-PREFIX §2). **10** honest; "live (closed until opening)" is awkward but truthful. **11** honest; keep as a wing — the Lean theorem as the game's rule is a unique sentence, but it serves §3.3 more than the spine. **12** honest (`needs`), and it is what makes step 1's front page non-empty — see D.

**Add one step**: nothing in the tour produces an *undecided*. §3.4 claims "a lost reply is undecided, never a second attempt; the exact retry is a link on the receipt" — understanding #4 has no step. Kill a reply mid-flight (operator can do this deliberately), show the amber outcome, click the exact retry. For anyone who has debugged a double-charge, that is the never-seen-before moment.

## C. The parity law (§1a)

The mechanism as written is half-mirage. I read the table: each `Verb` is `{name, usage, operation}` (`shell.rs:48-52`); `operation` is one prose line, and `usage` packs *several alternative grammars* into one string (`doc` ≈ 40 subverbs, `room` ≈ 30, separated by `|`). There is no per-argument structure, no types, and nothing marking which placeholders are references. "Argument → field, reference arguments → pickers over `refs`" describes a parser and a convention table that do not exist; without them every derived form is a row of unlabeled text boxes — honest, but not "visual means visual."

What *is* genuinely derivable today: the verb × subcommand enumeration. `subcommands_after` (`shell.rs:116-124`) already splits the usage strings on `|` for completion, and `command_catalog()` chains all four tables. So:

- **Smallest honest `jwebparity`**: enumerate `command_catalog()` verb × subcommand via that existing splitter, diff against the body's route/form registry, red by name, terminal pane excluded. This needs no new shell vocabulary and cannot lie about coverage.
- **Forms**: generate per subcommand with plain text fields (placeholder names from the usage string), and add *one* small typed-placeholder convention (REF/NAME/TARGET/ID → picker over `refs`; @FILE → textarea) — a few lines, but it is a hand-maintained seam and should be labelled as such rather than claimed as derivation.
- **Note the doc conflict**: WEB-FRONTEND §1 names nine bespoke places covering perhaps a third of the verbs; no generated-forms layer appears anywhere in that design. A0 is in DEMO-EXPERIENCE but not in the front-end design that is supposed to land it — one of the two must grow the other's scope.
- **Bespoke faces that genuinely deserve them**: documents (page/history/diff), rooms (live stream), receipts/outcome, the grants graph, the purse meter (`pay`/`credit`/`topup`), Hermes (`summon`/`ask`/`dismiss`/`status`), apps, boards, story, keys/sessions. Everything else — `enroll`, `market`/`bid`/`reveal`, `job`, `kind`/`program`/`instance`, `import`/`export`, `law check` — can live honestly as derived forms.

## D. "The box is a member"

Sound, not theatre, *if* three invariants hold: every line in the room is a signed turn of `mini-s-box` (nothing hand-written — the doc already says this); every drill post is produced by an actual drill run, not a "drill ok" sentence; and the performance numbers are measured on the box, per the plan's "measured on the demo box itself" clause. The ingredients exist: `ship.sh --rehearsal` already posts notices with reds named (DEMO-PREFIX §2), and the backup restore check is green.

Leaks to guard: (1) **the room must never become an instruction channel** — our own fleet agents read rooms; if land-receipts flow into a world-readable room that residents can also read, a stranger's post becomes fleet context. Post-only for `mini-s-box`, and fleet agents treat the room as output, never input. (2) No credentials material ever — the mini-keys precedent (digests only) is the right shape; the DNS-token exception and operator paths stay out of turn payloads. (3) No tenant-uid/roster internals beyond what members already see. (4) The clock's per-minute tick must not become the room's content — the room should carry events, or strangers will read it as noise and the §2 claim as padding.

## E. The ambitions, re-ranked (tour bought per day of work)

1. **A1** browser-only join (S) — the tour's premise ("nothing installed") fails without it; nothing else matters if the stranger needs ssh.
2. **A0** parity, re-scoped per C to verb × subcommand (M) — ember's ruling made checkable; but reconcile it with WEB-FRONTEND first.
3. **A3** operations room (S–M) — cheapest credibility: feeds steps 1 and 12, publishes the numbers in-world.
4. **A2** Hermes live (M) — highest value, highest variance (runtime C unjourneyed; L1(c) dependency); keep its lane order, don't let it cannibalize A1/A0 days.
5. **A4** `/tour` (M) — onboarding, acceptance and the README honest table in one artifact.
6. **A7** story row (S) — cheap, unique sentence; the markets row is the cuttable half.
7. **A5** any-app (in flight) — step 7's "any" is its product.
8. **A8** member kinds (M, ownerless) — the "programmable world" proof, but it can land after opening.

**Drop A9** (second node): buys one story sentence about re-genesis; nothing in the fifteen minutes touches it. **Drop A6** (oracle grain): step 8 is the least differentiated surface — "another SPK, plus a claim" — and the plan already permits it to miss a redeploy cycle. **Missing**: the undecided → exact-retry live step (B), and the refusal-you-can-act-on (`can --any` paste) folded into step 4. Those two are what make a stranger say "I have never used anything like this," and both are S-sized against machinery that already exists.

## F. Three sentences to change

1. *"The shell already holds each verb's arguments and help text; the web body renders a form from that table (argument → field, reference arguments → pickers over `refs`, outcomes → the one outcome partial)"* → "The shell's table holds, per verb, a name, one prose `operation` line and a `usage` string packing several alternative grammars (`shell.rs:48-52`); the derivable catalog is verb × subcommand — the split `subcommands()` already makes for completion (`shell.rs:116-124`) — so a face is a generated form per subcommand with plain fields, upgraded to pickers only where a one-line convention marks a placeholder a reference."
2. *"they install Etherpad or EtherCalc or any other SPK"* → "they install an app today's bridge vocabulary admits (Hacker Slides, Simple Todos; EtherCalc is the settled second origin); 'any SPK' is A5's bar, not today's."
3. *"## 1. The tour (fifteen minutes, from a browser, nothing installed)"* → "## 1. The tour: a fifteen-minute spine (steps 1–6) from a browser, nothing installed; six further doors (7–12)" — with step 8 folded into 7 and the undecided/exact-retry step added to the spine.

---




