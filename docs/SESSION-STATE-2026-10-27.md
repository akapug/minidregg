# Session state, 2026-10-27 (root 698fc87d; written before a /compact; lanes keep running)

Present state of the orchestration that the plan and the experience document do not carry: which agent
holds which lane, what each is doing, the decisions taken today, and where background jobs write. The
plan (`docs/DEMO-PREFIX-2026-10-26.md` §2) and `docs/BACKLOG-2026-10-27.md` are the work; this is the map.

## Lanes (agent id → quest; branch; state file). Resume with SendMessage to the id.

| agent id | lane | branch (tip when written) | state file / brief | doing now |
|---|---|---|---|---|
| a67de9cf3f217c50e | integrator (Opus) | integration/2026-10-26; merges to main every cut | its cut reports | cut 7 (3315a908) built; cut 8 (70796aa4) = rehearsal #3's candidate: gate v2 (tour + composed with inputs), enrol acceptance, standing runs ×2; then custody-drivers 26ea288c, hot-path-codec d50306c1, fence 0276e76d, app-market f8243aba (re-pin install-user-world's companion sha; main carries codex's controller-world.py edits) |
| a221a2ea8cf1d4104 | infra (Opus, distilled) | dregg-infra demo-vm (ef26f02+), main (40fdb60+) | `~/dev/dregg-infra-demo-vm/edge/demo/CHECKLIST.md` (12-step run sheet) | ships rehearsal #3 from the run sheet when cut 8's path arrives; m6grain rerun (cut-6 binaries + f8243aba scripts); Z.AI key seal staged |
| a436f5b0c02ab4364 | L1 Lean (Opus, distilled) | lane/lean-critical 38bfc427+ | `docs/PLATFORM-RECEIVER-STATE.md` | the platform cell kind → install receiver → Host arms 240–243 → genesis seed v8 → births priced from the cell → Intent.credit + refill ops; then the parent-task law (Option A) and the named factory refusal for ordinary births |
| ac9c91cf0c2b14469 | L2 successor (Opus, distilled) | lane/custody-drivers 6490b0d4 | `docs/ONE-WIRE-STATE.md` | idle until cut 8's path: enrol-resume step 7 (pinned plan across two ticks) and the world template's before/after |
| a7b20155b645d44ac | L13 app market (Opus, distilled) | lane/app-market f8243aba+ | `docs/APP-MARKET-2026-10-27.md` "State at hand-off" | japps --box on w5 (Etherpad, the -www origin, second-browser co-edit); the member's own install after L1's parent-task law lands |
| a6d30cc8441574ed3 | L4 Hermes (Opus, distilled) | lane/hermes 0b8cc8bb+ | its reports; deploy/hermes/README "The demo box" | J14's librarian fixture (ask/no-grant passes); then the GLM provider route (Anthropic-messages adapter on api.z.ai/api/anthropic) and the subscriber tier (`subscribers` room concierge granting the GLM route for 30 days on `pay subscribers 4000`) |
| a48135e75ea354199 | web lane (Opus, distilled) | lane/web-frontend 43533e6d | `docs/WEB-FRONTEND-2026-10-27.md` §6 | idle until L4's tier verbs and ember's copy (daily cap, policy sentence); then the Subscribe form and page copy |
| acf3cf506863a4b5f | hot-path successor (Opus, distilled) | lane/hot-path-codec d50306c1+ | `docs/HOT-PATH-STATE.md`, design §2(h) | the cold-reopen fix (checkpoint carries indexes/World/chain; suffix-only open); then `mini shell` 51 s start and one-reference `can` 6 min on an aged world |
| ab723ead68b824ed6 | oracle lane (Fable) | lane/oracle-grain 9f5ef889+ | `docs/ORACLE-GRAIN-2026-10-27.md` | the `joracle` row once the 15 GB dataset finishes syncing to dregg-build; reports once |
| a4bcc94fc6ae28bd9 | FB4 Lean deletions (Opus) | lane/fae-4 | — | the eight modules + orphan batteries + TotalProof/mix_append; then O20 (Selvage split), O18 (33 ∨ Collision), O61 (clock control), O19 (World.admit gate mode) |
| af881a4c39e5eb784 | fixture faerie (Sonnet) | lane/faerie-fixtures db3e9b78+ | — | regenerating NativeAcceptedFixtureData against cut 7 (3315a908) on dregg-build |
| a976e3756ffd0e155 | blind-spots scout (Sonnet) | lane/review-blind-spots | — | `docs/review/2026-10-27-blind-spots/BLIND-SPOTS.md` |
| a8b0399aa4e6c93ec | L3 (done) | lane/fence 0276e76d (merged) | `docs/SPK-TRUST-STATE.md` | complete; open: the fd-3 agent-API row needs a live Hermes+EtherCalc world |

Done and merged today (on main): L10 docs, fae-2/3/5/6/7/8/9/10, README, fence 0276e76d, the reviews
(genesis coupling, process, platform-cell statements ×3, untracked triage), the backlog, the audits.

## Background GLM jobs (claude-glm -p, outside the Agent tool; PID files; reports in this session's scratchpad)

- hex-decoder split faerie: `/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/glm-faerie/{pid,out.md,REPORT.md}`, branch lane/glm-hex (pushes itself).
- web3.js malice/integrity audit: `/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/glm-web3audit/{pid,REPORT.md}` (read-only).
- payment-page correctness audit: `/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/glm-web3correct/{pid,REPORT.md}` (read-only).
When each REPORT.md exists: commit it under docs/review/2026-10-27-web3-audit/ and act on its ranked fixes
(web lane for the page; the recommendation on replacing the SDK with a one-shape serializer is the root's call).

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
