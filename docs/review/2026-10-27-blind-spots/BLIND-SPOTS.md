# Blind spots of the 2026-10-26/27 sprint

Scout report, 2026-10-27, against `origin/main` 6500d46a. Limits: file counts are `git log --since='2026-10-26 16:00' --name-only` on main (542 commits, all committed
as one author, so main cannot attribute to lanes) plus the files unique to each non-archive
`origin/lane/*`, `codex/*` and `integration/*` branch. Lane names come from `cv lanes 698fc87d`
(131 agents). `cv search` does not take a session id and timed out, so term mentions were
grepped in the tree and in `~/dev/dregg-infra` branch `demo-vm` (a snapshot; its
`edge/demo/CHECKLIST.md` may be stale). Verdict: worked = a lane's stated scope; glanced = under 5% of files or
only deletions and prose; untouched = zero files.

## Sweep 1: the tree against the sprint

| area | lines | files in sprint (main / lane-only) | lanes | verdict |
|---|---:|---:|---|---|
| `Kernel/` | 212,527 | 15 / 29 | lean-critical L1, fence, hot-path-codec, fae-4 (docstrings) | glanced: 15 of 569 files, all platform cell, job money, consent, default law |
| `Compiler/` | 105,651 | 7 / 14 | lean-critical, fae-4, hot-path-codec | glanced (cSHAKE/KMAC, codec tags) |
| `Theory/` | 86,731 | 4 / 3 | fae-4 | glanced (cSHAKE kernels, AxiomPin) |
| `Host/` | 39,703 | 11 / 21 | fence, integration, lean-critical | worked at the seams (arms 240-243, genesis) |
| `Assurance/` | 59,842 | 4 / 8 | fae-4 | glanced |
| `Selvage/` | 78,130 | 0 / 1 | none | untouched (plan C2 moves it out in Phase 3) |
| `Verify/`, `Fixtures/`, `Effects/`, `Pred/`, `TokenCensus/` | 8,287 | 3 / 1 | none | untouched |
| `world/` | 46,096 | 0 | none | untouched |
| `prover/` | 33,082 | 1 / 2 | untracked-2026-10-27 | glanced |
| `protocol/` | 2,744 | 2 / 3 | lean-critical, custody-drivers | worked (op registry) |
| `website/` | 1,007 | 3 / 0 | door (join text) | glanced, see B3 |
| `isabelle`, `o7ir` | 0 | not in the tree | none | do not exist in this repo (`git ls-files` finds neither; 17 files mention `o7`/`veri7`, all the oracle) |
| `examples/`, `benchmarks/`, `testing/`, `tests/`, `coordination/` | 11,411 | 2 / 0 | none | untouched (coordination was rewritten as docs only) |
| `native/resource-client` | 169,500 | 299 / 229 | custody-drivers, web-frontend, app-market, hermes | worked (the sprint's centre) |
| `native/spk-host` | 56,662 | 75 / 140 | fence, app-market, oracle-codex | worked |
| `native/grain-runtime` | 55,096 | 49 / 10 | hermes | worked |
| `native/mini-sdk` / `mini-sdk-ts` | 8,937 / 1,121 | 18 / 5 | custody-drivers; FB8 | worked / glanced |
| `native/discord-entrance`, `mini-web`, `mini-web-spawn` | 6,717 / 2,710 / 1,431 | 23, 16, 5 | door, web-frontend | worked (new) |
| `native/mini-keys` | 6,220 | 15 / 0 | keys-store L6 | worked |
| `native/objective-emit` | 2,326 | 17 / 0 | deletions only | glanced |
| `native/private-backend`, `inference-scheduler`, `signed-api-path`, `compatible-upgrade-custody` | 28,993 / 5,305 / 159 / 369 | 0 | none | untouched |
| `native/pay-watcher` | 67,590 (741 files, mostly vendored) | 5 / 0 | hardening FB7 | glanced |
| other native crates (`credential-signature-verifier`, `hyperdocument-link-sqlite-store`, `joint-agreement-crypto`, `portable-archive`, `spk-rpc`, `spk-package-stream`, `oracle-appliance`, `hermes-test-provider`, `mini-kernels`, `launch-gate`) | ~25,000 | 2-9 each | oracle-codex, hermes | glanced |
| `deploy/oracle`, `spk-host`, `shell`, `door`, `web-frontend`, `candidate`, `hermes`, `market`, `pay` | ~22,000 | 6-47 each | door, oracle, hermes, app-market | worked |
| `deploy/grain-host`, `hermes-dispatch`, `clock`, `checkpoint`, `fn` | 4,582 | 1-13 | none | glanced |
| `scripts/` top level / `spk-platform` / `pipeline` | 16,478 / 16,156 / 6,688 | 46 / 16 / 21 | custody-drivers, app-market | worked |
| `scripts/kn2`, `fn-e1e2`, `fn-b3`, `burst`, `plants`, `ports`, `grain-birth`, `workroom`, `consent`, `terminal`, `provider-services`, `native-accepted-fixture` | ~13,000 | 0-2 | none | untouched |
| `docs/` top level / `review` / `evidence` / `objective-bend` / `tutorial` / `construction` / `research` | 21,079 / 28,787 / 349,776 / 1,075 / 523 / 6,412 / 1,249 | 49 / 51 / 138 / 1 / 0 / 1 / 18 | docs L10, faerie, review lanes | worked (docs), evidence is an archive |

Reading: a product sprint on `resource-client`, `spk-host`, `grain-runtime`, the door and the
web gateway. The Lean tree was touched at its platform seam only (15 of 569 Kernel files).
`world/`, `Selvage/`, `Verify/` and about 35,000 lines of native crates had no contact; plan C2
already schedules Selvage and `private-backend` for the research move.

## Sweep 2: the product against the sprint

Landed (from the plan, backlog and `docs/WEB-FRONTEND-2026-10-27.md`): tour steps 1-4 and 7
(front page, browser-only join, writes with the outcome partial, `can --any` with the paste,
Hacker Slides and Simple Todos on their own origins; JWF 40/40, parity 203/203, tour 38/0/1);
door 9 Discord gateway READY; door 10 ssh and `mini shell` in the page; opening-contract rows 2
and 3 as code (split tenancy, Lean default laws, custody record, restart and backup drills).

Planned, not finished (named owner): step 5 live Hermes under law (A2; the controller was not
up at ship #2; L4), step 6 lose-reply switch (A11; `lose_reply` exists in `shell.rs` and
`transport.rs`, the tour form is the web lane's), step 1's public reader (502 at ship #2, client
lane), door 8 oracle (codex session), door 13 operations room (a `body.rs` seam; infra
rehearsal #3), A10 receipt inclusion openings (L1 after the platform receiver), A5 Etherpad,
the pay-law genesis v7/v8, mainnet pay-to-enrol, the subscriber tier (no Subscribe form exists
under `native/resource-client/src/web`).

Planned, no owner: door 11's journey row, door 12's A8 member-defined kinds, A9 second node,
Phase 3 C1-C9 (all after opening), and any TS SDK consumer (none is listed anywhere).

By AFFORDANCES §1 surface: CLI, shell verbs, raw protocol (rendered at `/registry`), Discord,
ssh, web, SPK worked; Rust SDK custody only; TS SDK made honest and nothing more; fleet and fn
only lost code (`lane/fn-fleet` deleted the fn-e route; no second node); Hermes in flight;
Objective Bend authoring untouched, deliberately (§1.13: no shell verb, no SDK wrapper, nothing
deployed; `native/objective-emit` only lost dead code).

Never planned (0 grep hits in plan, experience doc and backlog): incident response, a terms or
privacy text, accessibility, member data export, prompt injection, XSS review.

## The blind spots, ranked (exposure to a stranger x cost to address)

**B1. No alert path, and no one looking.** `edge/demo/CHECKLIST.md` item 16: "There is no
alert path yet ... ember checks `systemctl --failed; df -h` daily." A full disk, a dead Store
or a drained sponsor goes unnoticed until a stranger says so. Smallest honest thing: one outbound-HTTPS unit pushing `mini-health`, `df`,
`systemctl --failed` and the sponsor floor to ember's phone, in its own `cg_*` nft set as the
checklist already specifies (infra lane, S).

**B2. The 11 Nov shutdown has no member-facing half.** The date is on the join page and in
`/etc/mini/announce.txt`, the teardown is an operator script, and the backup bucket is locked
for 22 days, but nothing lets a member take their documents, receipts or grants away, and the
join page says only that a re-genesis "erases everything you made". Smallest honest thing:
an export for one subject (documents, receipts, key) offered from 10 Nov, with one sentence on
what is erased (web plus client lane, S-M).

**B3. Two front pages, and the static one is stale and silent about risk.** `website/` is
GitHub Pages (`.github/workflows/pages.yml`), the real front page is the gateway at
`demo.dregg.online`. `website/join.html` (last substantive edit 10-26) says "redeployed every
few days" and omits the 11 Nov date, the 50-account free cap, the published performance table
and any terms; `website/status.html` still says "no application has yet served a browser
session", false since L13. No lane owns it. Smallest honest thing: regenerate from the README
after the opening, add the date and the cap from `door.json`, or point `website/join.html` at
`/join` and delete the copy (docs lane, S).

**B4. Strangers' words reach agents and browsers with no adversarial review.** Zero hits for
prompt injection in plan, backlog, experience doc, Hermes and grain-runtime READMEs. The tour
itself has a resident read a document and act under its owner's grants; every document is
world-readable, so a stranger can write text addressed to another member's resident. The same
goes for rendering: `mini-web` CSP is strict (`script-src 'self'`, `__Host-` cookie, grains on
separate origins), but `style-src` allows inline and I found no XSS pass over member-authored content. Smallest honest thing: one adversarial lane that plants an injection document and an XSS
payload through the tour's own forms and records the result (security reviewer, M).

**B5. Free-route exhaustion is one person's afternoon.** `deploy/door/README.md`: 3 POSTs per
IPv4 or IPv6 /64 per hour, `freeCap` 50, `dailyCap` 20, no captcha, no proof of work, sponsor
floor closes the free route. One person with a handful of addresses closes the door to every
real stranger on day one, and the shared pool key ($40, shared by all residents) has only
per-runner day caps. Smallest honest thing: decide and publish the policy (CHECKLIST #10 is
still "BLOCKED"): per-day free quota plus a reserved block for the ember-invited, and a
per-member pool-spend ceiling (door lane owner, S).

**B6. No incident runbook for the demo.** `edge/RUNBOOK.md` is for the AWS edge;
`CONFINEMENT.md` lists compromise scenarios but no steps. Nothing says what to do about a
reported abuse (Hetzner abuse is on our account), a leaked sponsor key (the sponsor and clock
secret keys sit in `mini-core`'s store; key rotation itself can wedge on a refused op 142,
backlog O36), a stuck grain, or a full disk. Smallest honest thing: one page, six headings,
each a command ember can paste, written by the infra lane and rehearsed once (S).

**B7. What the box records about strangers, undeclared.** Journald keeps 14 days (50-demo.conf),
Caddy and the door see IPs and X-Real-IP, the door keeps request tables, Discord custody is
"bounded" (its README), hosted keys are readable by the operator. The join page says the keys
are operator-readable but nothing about logs, IPs or retention, and no terms or acceptable-use
text exists, although the GLM subscriber tier carries an unresolved third-party-use question.
Smallest honest thing: a five-line "what we record" and a short terms paragraph on `/join`
(ember writes, web lane places).

**B8. Accessibility.** Five `aria-`/`role` hits in `mini-web`, one each in `render/html.rs`
and `web/apps.rs`; the terminal is xterm.js in a canvas with no text alternative; no
contrast or keyboard pass; the experience doc's "visual means visual" never mentions
non-visual. Smallest honest thing: one Chromium accessibility-tree pass over the tour's pages
and fix the findings (web lane, S-M).

**B9. The restore drill is a script, not a cadence.** `mini-restore-check` is green at ship
time and nothing schedules it again. Smallest honest thing: a daily timer feeding B1 (infra, S).

**B10. Oracle, Objective Bend, second node, fleet.** Honestly deferred and named in the plan;
only the front page must not imply them.

## Three security questions nobody asked

1. **What does the wildcard-DNS token let a compromised grain do?** The Gandi PAT is on the box
   as a written CONFINEMENT §2 exception, narrow but over `dregg.online`; the Caddy that holds it
   and the wildcard key serve arbitrary stranger-installed SPKs. A grain escape does not need
   Mini's keys to take the domain, issue certificates for any `*.demo` name, or serve a
   look-alike login. Has anyone measured the path grain -> Caddy's credential directory?
2. **Can one stranger spend another's budget or the shared pool through an agent?** The pool key
   ($40 shared) is drained by residents acting for anyone; a hostile document (B4) makes a
   resident spend its owner's purse on the attacker's text. Which cap is per stranger, and does
   the first limit hit before the pool is gone?
3. **Is the operator-readable hosted key a single point of impersonation?** All hosted member
   keys sit on one box under one root; the sponsor and clock keys beside them. A root compromise
   lets the attacker sign as
   every member and the receipts will be admitted and honest-looking. What detects it, and what
   does a member's offline check against the published world root say afterwards (A10 is still
   unlanded)?

## Evidence

`cv deferrals 698fc87d` (30 entries; none concern B1-B9, nearly all "queued" for infra). Infra
snapshot: `~/dev/dregg-infra` branch `demo-vm`, `edge/demo/CHECKLIST.md` items 16 and 18,
`host/journald.conf.d/50-demo.conf`, Teardown section.
