# Session state, 2026-10-29 (ember travelling)

Root orchestrator state for a restart. Read docs/STATE-OF-MINIDREGG-2026-10-28.md, ATLAS §6 (17 laws; law 17:
never slower over time), then `cv show 698fc87d --kind prompt,answer`. Supersedes SESSION-STATE-2026-10-28.md.

## Goal
Rehearsal 3 with real meat, deployed fresh in the demo container on dregg-forge (cpx62, 178.105.4.114; nspawn
`demo` and `nano`; DNS demo/nano/calc/*.demo → forge; dregg-demo, dregg-build, dregg-ref deleted). Servers kept:
anchor, workhorse (live edge, untouched), forge.

## Lanes and state files (all wound down 2026-10-29 ~10:45 UTC)
| Lane | State |
|---|---|
| integrator (builds on hbox NVMe /home/hbox/lanes/integ; ~6 min incremental) | docs/INTEGRATOR-STATE.md |
| hot path (GET 1.2 s→160 ms CPU; submit 280→50 ms; next: cold-start snapshots, law-17 flatness) | docs/HOT-PATH-STATE.md, lane/hot-path |
| apps-for-agents (Davros api journey to first Hermes turn; v4 web route built) | docs/APPS-AGENTS-STATE.md CONTINUATION, lane/apps-agents |
| demo-path (story fix 0be1e5b4b; 206-GET budget; OwnTracks/Hummingbird; market index 27db3d1b7) | docs/DEMO-PATH-STATE.md |
| infra (forge containers, snapshots 2.5 s, walk on forge; composed-root container owed) | dregg-infra edge/demo/CHECKLIST.md hand-off |
| SPK freshening (Kimi/GLM per app; 9+ qualified) | docs/SPK-FRESH-2026-10-29.md, landings in scratchpad kimi-spk/landings.md, lane/spk-fresh |

## Rulings today
Trust sealed snapshots on our filesystem (cold start). Keep the privacy ratchet. Kimi/GLM never do hard proofs
(Opus). Perf by reading code; measure to confirm. Never slower over time (law 17, flatness bench gates). Repackage
all FEATURED SPKs fresh (6 dropped). Typed app tools = a hybrid obend world over web2 apps, toward web2/web3.
Gentle usage: ≤2 Opus (prefer 1), ≤3 Sonnet; claude-kimi for reviews and mechanical work. Stress-test with
Kimi/GLM when a tour goes green. hbox: lanes off /othersys (not ours), on the NVMe root.

## Unrevived
statement-fixes (Pred.witnessed deny-bypass first; Opus), commuting-append proofs, prefix certify, composed
residents/restart, no-pins part 2 (derived tags), ~230 out-of-repo design citations, oracle7 codex batch.
