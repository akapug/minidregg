# Session state, 2026-10-27 (root 698fc87d; written before a /compact; lanes keep running)

Present state of the orchestration that the plan and the experience document do not carry: which agent
holds which lane, what each is doing, the decisions taken today, and where background jobs write. The
plan (`docs/DEMO-PREFIX-2026-10-26.md` §2) and `docs/BACKLOG-2026-10-27.md` are the work; this is the map.

## Lanes (agent id → quest; branch; state file). Resume with SendMessage to the id.

| agent id | lane | branch (tip when written) | state file / brief | doing now |
|---|---|---|---|---|
| a67de9cf3f217c50e | integrator (Opus) | integration/2026-10-26; merges to main every cut | its cut reports | cut 7 (3315a908) gate v2 FAIL (tour 38/1: tour-chromium, predates the web fix; composed inputs died on the old runner's sudo path; enrol-resume tick-timing red); cut 8 (26418b6b) host build killed by memory and skipped; **cut 9 = 5fdfa393 (/build/lanes/integ7, chain cut9b.sh, every child PID-filed) is rehearsal #3's candidate**: main 8fdd15e9, fence 0276e76d storeIdentity, app-market f8243aba (companion re-pinned 3131a60a), web-frontend 37f23dfc, hermes 54a43e15 (caps + GLM tier), glm-hex 54d7730d; order build → gate (tour with real tour-chromium + composed) + enrol-resume → standing runs tpl0/tpl1 with m6grain. Cut 7's chain and standing run stopped by PID file (box was at 0 GB available) |
| ae6499559bb424054 (live successor; a221a2ea8cf1d4104 and a8850c5b2ebab4f7c stopped) | infra (Opus, distilled twice; state in CHECKLIST) | dregg-infra demo-vm (20c91a3+), main (40fdb60+) | `~/dev/dregg-infra-demo-vm/edge/demo/CHECKLIST.md` (12-step run sheet) | ships rehearsal #3 from the 12-step run sheet when cut 9's path arrives (told: cut 8 skipped; per-member caps may land a cut later); mini-alert drill; invite reserve; Z.AI key seal staged; door funding 10000 and mainnet rpc.env already on the box; nightly exports JOURNEY_BUDGET_S=10800 but has no demo-journey step yet |
| a436f5b0c02ab4364 | L1 Lean (Opus, distilled) | lane/lean-critical 6fffa0de | `docs/PLATFORM-RECEIVER-STATE.md` | landed: the platform cell kind (tag 21; FLAG DAY STORE-CELLS v17, every Store re-genesis: lands once with the whole cell, not in cut 9), the install receiver (sponsor must be the cell's controller; cosigned custodian rotation; `admitsObserved_decides`), holderPolicy (L13 Option A) and birthRefusal (named factory refusal at plan time). Next: replay + Host arms 240–243 (240 consent_exempt), genesis seed v8, births priced from the cell, Intent.credit + 244–247; splitting the two L13 laws onto `lane/lean-l13-laws` from main for the next cut; auditor pass 4 running |
| ac9c91cf0c2b14469 | L2 successor (Opus, distilled) | lane/custody-drivers 6490b0d4 | `docs/ONE-WIRE-STATE.md` | idle until cut 8's path: enrol-resume step 7 (pinned plan across two ticks) and the world template's before/after |
| a7b20155b645d44ac | L13 app market (Opus, distilled) | lane/app-market f8243aba+ | `docs/APP-MARKET-2026-10-27.md` "State at hand-off" | japps --box on w5 (Etherpad, the -www origin, second-browser co-edit); the member's own install after L1's parent-task law lands |
| a6d30cc8441574ed3 | L4 Hermes (Opus, distilled) | lane/hermes 54a43e15 | its reports; deploy/hermes/README | J14 on the real upstream Hermes over the POOL route 150/151 (run 19; confirmation run 20 running); per-member pool caps done (39d802f5: default 1/40 ceiling/day, 1/10 total); GLM serves OpenAI Chat Completions at api.z.ai/api/coding/paas/v4 (no adapter needed; finish_reason quoter fix 56f85933); subscriber tier as existing machinery (`subscribers` room, concierge, period 43200, tariff week 4000; a second house Hermes on a `zai-glm` pool row); ruling A: the concierge also issues the roster invite, subscriber runs `chat join subscribers @FILE` once |
| a48135e75ea354199 | web lane (Fable, distilled) | lane/web-frontend 37f23dfc (pay-page audit fixes 1–7 done: 861fe953, b4a1a9d6, 3710db83, 37f23dfc) | `docs/WEB-FRONTEND-2026-10-27.md` §6 | "Export my world"; then the seven pay-page fixes from docs/review/2026-10-27-web3-audit (POST result ignored, signature shown before POST, stale quote, 3-POST budget, amountTokens, post-signing re-decode assert, chain from quote.network); door invite fields; Subscribe form after L4's verbs and ember's copy |
| acf3cf506863a4b5f | hot-path successor (Opus, distilled) | lane/hot-path-codec d50306c1+ | `docs/HOT-PATH-STATE.md`, design §2(h) | the cold-reopen fix (checkpoint carries indexes/World/chain; suffix-only open); then `mini shell` 51 s start and one-reference `can` 6 min on an aged world |
| ab723ead68b824ed6 | oracle lane (Fable) | lane/oracle-grain 9f5ef889+ | `docs/ORACLE-GRAIN-2026-10-27.md` | the `joracle` row once the 15 GB dataset finishes syncing to dregg-build; reports once |
| a4bcc94fc6ae28bd9 | Lean coherence (Opus; PARKED until after the opening per the converge rule) | lane/fae-4 6c9c3a22 (merged) | `docs/LEAN-COHERENCE-STATE.md` | landed FB4 deletions, O20 Selvage split, O18 parts 1–3; O61's statement handed to L1 (frame v8); remainder (O18 DomainEpoch etc., O19) resumes from the state file after the opening |
| af881a4c39e5eb784 | fixture faerie (Sonnet) | lane/faerie-fixtures db3e9b78+ | — | regeneration against cut 7 (3315a908) runs through (generator fixes 1557a44f: replay.lean imports Sp800185Cshake256Native; generate.sh passes --load-dynlib) but refuses to write: `first.charge.storageBytes` authority 2,000,000 vs run 3,969; told to decide from the tree's history (Authority-Change trailer if the implementation's change was reviewed; else a Lean-lane red) |
| a2fb82cd3bdc9e6ef | hex-split faerie (Sonnet, done) | lane/glm-hex 54d7730d | — | done: strict decoder for Host-produced values across 55+ files, two sites reversed to strict, lenient kept for typed input; 387/389 filtered on the Mac (2 macOS-environment fails); for the next cut |
| a24f1d9df00f78954 | redteam (Opus) | lane/redteam | — | XSS/prompt-injection through the tour's forms and the three security questions → docs/review/2026-10-27-redteam/REDTEAM.md |
| a976e3756ffd0e155 | blind-spots scout (Sonnet) | lane/review-blind-spots | — | `docs/review/2026-10-27-blind-spots/BLIND-SPOTS.md` |
| a8b0399aa4e6c93ec | L3 (done) | lane/fence 0276e76d (merged) | `docs/SPK-TRUST-STATE.md` | complete; open: the fd-3 agent-API row needs a live Hermes+EtherCalc world |

Done and merged today (on main): L10 docs, fae-2/3/5/6/7/8/9/10, README, fence 0276e76d, the reviews
(genesis coupling, process, platform-cell statements ×3, untracked triage, blind spots, the two web3 audits),
the backlog, the audits, the thin website (lane/fae-website 53b4c8ee, merged 53b2ea6f).

## Background GLM jobs (claude-glm -p, outside the Agent tool) — all three have exited

- hex-decoder split faerie: died on "Prompt is too long" after editing 55 files; edits committed as found
  (lane/glm-hex 1fb9eda0) and handed to the Sonnet hex-split faerie above. Lesson: a 200-site mechanical
  sweep exceeds one GLM context; brief it per module or give it a script.
- web3.js integrity audit → `docs/review/2026-10-27-web3-audit/INTEGRITY.md` (bundle byte-identical to the
  attested 1.99.0 publish; keep the pin; two gaps are ours).
- pay-page correctness audit → `docs/review/2026-10-27-web3-audit/CORRECTNESS.md` (five ranked fixes, routed
  to the web lane). The recommendation to replace the 484 KB SDK with a one-shape serializer (~300 lines,
  deletes the whole blob) is the root's call; not taken yet.

## Decisions taken today (engineering, recorded in the plan unless noted)

Gate = tour + composed; standing rows nightly. Opening target 2026-10-29 from rehearsal #3. Mainnet pay-to-enrol
(observer at genesis: rehearsal #3). Main advances every cut; other sessions' edits committed as found on sight;
never `git reset` in the shared worktree (incident: 84 s of codex edits lost, recovered by codex and on
lane/oracle-codex-recovery). Consent stays full (flat with recheckHeld; thin-birth arm Phase 3). The member's own
account pays for app creation; MINI_REENROLL_APPS_MAX 50000; apps bootstrap budget 1,000,000; sponsor genesis
2,000,000; door funding 10000; meterAllowance 10^10; payControlCapability 4031; pay observer subject 30 / 4030–4032.
Parent-task law admits the birth touch for any delegated-grant holder (Option A, L1). storeIdentity replaces
expectedSeed (every grain world's tag changes at the next candidate). Lanes' umask 0022 on the build boxes.
Subscriber tier 4000 DREGG/month on GLM via the Z.AI plan key (terms question flagged to ember). Distill at 400k;
fixed cuts; no foreground waits; lanes run their own rows.

## Owner items outstanding (ember)

The subscriber tier's policy sentence for the join page; the 1-DREGG dry run before the paid route opens;
the earlier batch (refund liveness; install-operator-stack repoint/delete; lane/oracle-codex-recovery
cherry-pick or close; orphan `mini` PIDs on dregg-build 709807/722346/868724 and the three on hbox;
~/.openrouter-devkey expired on disk; 1Password tofu bundle re-save, deferred by ember).

## Boxes

dregg-demo 167.233.199.225 (rehearsal #2 serving 45f45d15; Discord gateway READY; front page 502 until the
`public` member enrols at rehearsal #3); dregg-build 178.105.4.114 (/build 400 GB; Playwright; umask 022; sudo rules
for lanes); dregg-ref 2.31.71.194 (M7 reference box); hbox (standing run; nanodregg co-tenant). All die 2026-11-11.
