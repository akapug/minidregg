# Session state, 2026-10-28 evening

Root orchestrator state for a restart. Read this, then `cv show 698fc87d --kind prompt,answer` for ember's words.
Supersedes SESSION-STATE-2026-10-27.md.

## Goal
Rehearsal #3 on dregg-demo (still serving rehearsal #2, 45f45d15). Ship only a candidate that is fully green on
docs/REHEARSAL-3-BOARD.md (lane/qualify), through ship.sh on ember's word.

## Agents (Claude subagents unless noted) and their state files
| Agent | Role | State |
|---|---|---|
| a34bdb948f1cf4796 | integrator: builds main on dregg-build, gates, merges | docs/INTEGRATOR-STATE.md (main) |
| ab292a1cd5ddfbbe5 | qualification lead: keep-going composed, overlay test-ahead, the board | docs/QUALIFY-STATE.md, REHEARSAL-3-BOARD.md (lane/qualify) |
| a308118209b4a48ea | deputy: market, spk, japps, route latency, faeries | docs/UNTOUCHED-DEPUTY-STATE.md (lane/un-deputy), STANDING RULINGS FROM ROOT at top |
| ac204a2887d583805 | infra 4: demo-dry keep-going walk, ship.sh | edge/demo/CHECKLIST.md hand-off (dregg-infra demo-vm) |
| a450fc35eb510f987 | L4d Hermes | docs/HERMES-STATE.md (lane/hermes-b) |
| ae523f43aa7bfc923 | perf rake (GLM flash readers on Z.AI + fix lanes) | docs/PERF-RAKE-STATE.md, docs/PERF-BACKLOG-2026-10-28.md (lane/perf-rake) |
| a72f5baf44e547b4d | statement fixes (Pred.witnessed, hyperedge apex, writeOnceNonzero, LC-fs PARTIAL) | lane/statement-fixes |
| a02d2eb16d960f057 | docs lane (README done; ~230 out-of-repo design citations next) | lane/docs |
| af7a93e7b8ba729d4 | statements auditor | AUDIT.md (lane/audit-platform) |
| codex astra (not Claude) | cx-web (gallery + merge), cx-app-interface (36-app fan-out, Hermes tools), cx-store-sweep (76 apps left), cx-oracle | scratchpad cx-*/ out*.md, session ids in err files |

## Where things stand
- Candidates: 9bd52317c gate FAIL only on composed apps:sheet (refused at "app delegation check"; fix lane/un-japps-rows
  266b12b65/b65465c72, on overlay test) and connector preflight (route front missing; residents/restart behind it).
  Build 327096423 runs with the new order (READY before umbrellas). Next build carries most of today's fixes.
- Latent defect being fixed: share-issue plan-height window (ApplicationShareIssueSource.lean:215-216), a4edd94c21caeaa24.
- Route latency: charge cut + readback cut on main; before/after CPU pending a candidate.

## Ember's rulings today (beyond memory files)
Statements may change (no equality-proof rule). No netlink for IPython (ifaddrs shim instead, on main). App-interface
design approved, fan out. Strangers summon Hermes into the shared lobby (founder `house`). Hot enrol key on dregg-demo
is a deliberate bounty; /flag.txt from ~/.dregg-flag.txt installed by ship, never committed. FS quota stays 48/56 MiB,
10K/12K inodes. Demo tariff 6/2, member grant = 10 Tally runs. Don't skip the chain turn; fix the per-turn cost.
