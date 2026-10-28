# Session state, 2026-10-28 (root 698fc87d; rewritten 03:55 UTC after cut 14's first candidate)

Present state of the orchestration that the plan and the experience document do not carry: which agent
holds which lane, what each is doing, the rulings, and where background jobs write. After a compaction, read
this, then `docs/INTEGRATOR-STATE.md` ("Rulings (do not re-ask)"), then reorient with `cv show 698fc87d
--pre-compaction <N>` rather than the summary.

## Where the demo stands

Cut 14 candidate `0ce31391` (dregg-build:/build/candidates/0ce31391…): build green, enrol-resume PASS,
gate FAIL on one composed red (the SPK harness's broker path, fixed on main bea8928a5). Rows on it (validator):
journeys J0–J8, J12X, K-series, JPRIV1, JFEEDBACK, FOUC, jserve, the seven world apps, the genesis writers and
JPAY1–4/JPAY2 green. Blocking: every grain install refused (fixed on main 25cfb86bd, storeIdentity), and
hosted members could not sign under split tenancy (delegated consent: main 51e9ca5a9/52c0eae22 plus demo-vm
742446c). The next candidate (A10 regen, then the full build at main's tip) carries both; it reruns the app
tables, the Hermes journeys and infra's seed dry run in the private demo-dry container on dregg-ref. No
rehearsal ships without ember's word. The module conversion plus census option A (one StoreEpoch move, with
Intent.credit's v3 frames) lands after that candidate.

## Lanes (agent id → quest; branch; state file). Resume with SendMessage to the id.

| agent id | lane | branch | state file | doing now |
|---|---|---|---|---|
| a34bdb948f1cf4796 | integrator (Opus; loses context on resume, so its state file carries everything) | main | `docs/INTEGRATOR-STATE.md` (Rulings section) | A10 regen at a62cab510, then the full build at main's tip; names candidates to validator, L4b, deputy, infra |
| aeee8349c191e8506 | rows validator | lane/rows-ledger | `docs/ROWS-OWED.md` | runs owed rows per candidate on hbox and dregg-ref; harness fixes only |
| ad81db6d6fd317d3a | L4b Hermes (about 450k tokens) | lane/hermes-b (= main) | `deploy/hermes/README.md` State | J14_TOOLS/AWAIT on the next candidate; operator-proxy allowlist; footprint measurement, then one batch to infra |
| a308118209b4a48ea | untouched deputy, now also the app market | lane/un-deputy, app-market-b3/b7/fixups, un-tale-welcome | `docs/UNTOUCHED-DEPUTY-STATE.md`; `docs/APP-MARKET-2026-10-27.md` | market reds on the next candidate (2–3 dozen FEATURED); story-template split-tenancy red; japps co-edit |
| a76aafe192878160e | custody-b (L2 successor) | lane/custody-b | `docs/ONE-WIRE-STATE.md` | genesis writers plus JPAY2 rerun on the next candidate; profiled bootstrap: ask L4b, else delete |
| a58f907aef8926430 | L1e births-from-platform-cell (after L1c, L1d) | lane/lean-audit-c, lean-audit-c-m2 | `docs/PLATFORM-RECEIVER-STATE.md` L1d continuation | two builds of d95bf65ea; merge the conversion when it lands; green sha to the integrator; then M2 (Intent.credit) |
| a0fd127abfb9aac75 | iter-speed successor (module conversion) | wip/iter-speed-land then lane/iter-speed | `docs/ITER-SPEED-STATE.md` | landing builds on hbox and dregg-ref; converted timings; one landing commit after the next candidate |
| a83b7949ba401cca5 | Effects revival (statement-first) | lane/effects-revival (design on main) | `docs/EFFECTS-REVIVAL.md` §8 | auditor accepted (passes 19 and addendum); waiting for the Lean check of Effects/Revival/Statements.lean; proofs after |
| ae95a4eac63b0715e | infra (successor; demo-vm) | ~/dev/dregg-infra-demo-vm | `edge/demo/CHECKLIST.md` hand-off (b273035) | demo-dry seed rerun on the next candidate; Hermes per-uid batch; rehearsal sheet on paper |
| af7a93e7b8ba729d4 | auditor (statements) | lane/audit-platform | `AUDIT.md` | on request |

Stopped: L1c, L1d, L4, L13 and iter-speed's first agent (their state files above are the hand-offs).

## Alt-model workers (claude-glm / claude-kimi -p, outside the Agent tool)

Briefs, PID files and output are under the session scratchpad, `glm-*` and `kimi-*`. The shared brief is
`alt-common.md` plus `kimi-context-rules.md`: no beacons, notes files, push per item. `claude-kimi`'s built-in
model `k3.1` is rejected, so pass `--model k3.1-pro`. Running now: glm-red-j17 (pay retry after a decided
refusal), glm-red-web (placeholders, board fields), glm-red-ktpl (template script, link index), glm-red-jpay6
(relaunched from its NOTES.md). Their branches go to the integrator when they push.

## Rulings since the last rewrite (also in INTEGRATOR-STATE)

Re-genesis is free, so flag days aren't held. Lanes build and run only warm and incremental on a box, never
the Mac, never cold. Intent.credit persists in IntentRecord (v3 frames) with the conversion's re-genesis.
Census option A (structure, not name, for compiler auxiliaries), with teeth tests. No transitive bumps.
Owner-less pins refused. Hermes residents get their own uid (mini-h-INSTANCE), a least-privilege operator
proxy, journal retention, sandbox /scratch at S16/M64/L128 MiB and a quota of about 32 MiB. Members sign
through delegated full consent (mini-consent@NAME), never by loosening Store permissions. Prepare-time
refusals are the contract, and every client names them and exits 3. Commons is split; the publish bound is
not raised.

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
continuous integration onto main (no cut cadence); no foreground waits; lanes run their own rows.

## Owner items outstanding (ember)

The subscriber tier's policy sentence for the join page; the 1-DREGG dry run before the paid route opens;
the earlier batch (refund liveness; install-operator-stack repoint/delete; lane/oracle-codex-recovery
cherry-pick or close; orphan `mini` PIDs on dregg-build 709807/722346/868724 and the three on hbox;
~/.openrouter-devkey expired on disk; 1Password tofu bundle re-save, deferred by ember).

## Boxes

dregg-demo 167.233.199.225 (rehearsal #2 serving 45f45d15; Discord gateway READY; front page 502 until the
`public` member enrols at rehearsal #3); dregg-build 178.105.4.114 (/build 400 GB; Playwright; umask 022; sudo rules
for lanes); dregg-ref 2.31.71.194 (M7 reference box); hbox (standing run; nanodregg co-tenant). All die 2026-11-11.
