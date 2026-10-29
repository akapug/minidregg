# Integrator state

Present-state record of the integration lane, rewritten whole when its shape changes. A successor reads this,
then `hbox:/home/hbox/lanes/integ/COMMANDS.log` (every build stage, gate verdict and tidy act, one line each).
dregg-build and dregg-ref were deleted 2026-10-28; their history is in this file's git history.

## Shape

One integrator (Opus). Kimi (`claude-kimi -p`, read-only) reviews a batch of landings every few plus anything big or
risky. Kimi cannot read the session scratchpad: put a patch inline in the prompt (keep it under ~60 KB) or ask it to
read repo paths. Lanes push branches and send shas; the integrator merges into `integration/staging` on the Mac,
builds staging's tip on hbox, moves main to it once its host stage is green, gates, reports. No codec pins/census.
Statements may be rephrased, never weakened. ATLAS law 17: never slower over time (flatness bench = the one perf
gate; hot-path sends it, wire it into the gate).

## Where things are

- Mac landing worktree `/Users/ember/dev/minidregg-lanes/integration-r2` (branch `integ/main` = staging, pushed to
  `origin/integration/staging`); a scratch worktree of main at the session scratchpad `integ2/wt-main`.
  Mac checks: `CARGO_TARGET_DIR=/Users/ember/dev/minidregg-lanes/target-integ`, filtered `cargo test --bin mini -- apps::`
  etc. (the apps_front connector test fails only inside the group).
- hbox tree `/home/hbox/lanes/integ/src` (NVMe `/`; rpool/othersys is not ours). Build `integ-build2.sh SHA`
  (pid file integ/build.pid): rust-check, host, consent, umbrellas (non-fatal), rust, pack -> `integ/candidates/<sha>/READY`.
  Run with `SEATS=4 MEM=40G`; keep combined Lean caps on hbox near 60 GB so ~30 GB stays for test worlds, and stagger
  host stages with the hot-path lane (a9bba0bc5f114fc06). Incremental build 6-10 min; a deep StoreCodec change ~40-60 min.
- Gate `integ/gate9.sh SHA` (newest; never edit a script in place, number the next one). Env: PHASES ("tour composed
  enrol"), SUF, HARNESS (overlay scripts/ + resource-client scripts + journey.d from a sha), EDGE_REV=69c17a3 (dregg-infra
  tree integ/dregg-infra-<rev>), PORT and JWORLD_ROUTE_FRONT_PORT unique per concurrent run, JWORLD_MANAGEMENT=sponsor
  (distinct breaks app births; see reds), JWORLD_ROOT_HANDOFFS=1 default, TOUR_FROM, KEEP_WORLD=1 (leave the composed world
  up; the log line says how to take it down). Results integ/gate-<sha8><SUF>/; runs under /ci. Playwright
  /tank/dregg-build/rows-0ce31391/pw/node_modules (browsers ~/.cache/ms-playwright). Infra also offers `ssh composed-box`
  (a container on dregg-forge) for composed if hbox root setup gets crowded; not used yet.

## Main and candidates (2026-10-29 afternoon session)

Main c4264f9cb = staging = 636b1baeb + hot-path batch 1 f34b03095 (Kimi review clear) + lane/spk-fresh bf49ce23a
(Etherpad 3.3.12 r6; FEATURED rank 1 = ksyn7qa4...) + lane/demo-path-market 27db3d1b7 (operator-pinned index; tests
carried into main's appId-list FEATURED shape) + 8611c8708 (fixture = fresh-index output over the 8 qualified
packages; apps::tests 24/24) + demo-path codex 5d30c5f9c (standing-world certifier, rate default 1200/min, stricter
story-refused row, OwnTracks exact readback).

| candidate | verdict |
|---|---|
| d9661be99 | composed apps:sheet and store-restart red (08:02) |
| 8cb74aba5 | READY 13:23; gate10 running (integ/gate-8cb74aba, pid gate-8cb.pid; ports 22740/22743); enrol-resume PASS |
| c4264f9cb | READY 13:32 (= main); gate10 running (integ/gate-c4264f9c, pid gate-c42.pid; ports 22840/22843). The rehearsal-3 candidate if green |

Both gates: `EDGE_REV=69c17a3 JWORLD_MANAGEMENT=sponsor bash gate10.sh SHA` (gate10.sh is mode 644; run with bash).
Umbrellas rc=1 on both: Fixtures.NativeAcceptedFixture, NativeDocWriteFixture, BirthPlanPoles, Effects.Revival.EngineProofs.

## Market packages for the demo box

dregg-forge:/var/lib/spk-fresh/qualified-2026-10-29/: in/ (bytes from hbox:/tank/lanes/spk-fresh-*/cache),
apps/<app>/out/<app>.spk (hard links), out/local.json + adopt.tsv (fresh-index.py adopt mode, spk tool
/var/lib/spk-fresh/tools/spk). Datasette, Davros, DokuWiki, EtherCalc, Etherpad e6d71fa0, HedgeDoc, Hledger, ntfy;
packageIds = apps/interfaces/*.json. Infra (add189844d158e3a7) has the paths.
WBO qualified per landings.md, but its repack declaration has not landed (wbo.json still upstream ac72e0d1); FEATURED
keeps upstream WBO until spk-fresh (a58fcf100f4438710) sends the sha. Wekan, MediaWiki, Forgejo blocked (landings.md).

## In flight

- Codex apps-agents (cx-aa) and hot-path (cx-hp) still running; each leaves target/*-commit.sh in its worktree and
  scratchpad cx-*/out.md. On finish: read report + patch, run the script, merge to staging, build, gate.
- Infra told: c4264f9cb READY, verdict to follow; forge ship from the green candidate.

## Reds

- Flatness (law 17): fails on main's code (60 ms at append 2, 1.7 s at append 141); hot-path codex owns. Bench
  scripts/perf/flatness-bench.py (lane/hot-path); gate10 runs the candidate's scripts/perf/flatness-gate.sh and
  records FAIL when absent.
- Composed: apps:sheet same-Store app and store-restart:shared:resolve (d9661be99); connector capture (7001c0a9f).
- Umbrellas as above (re-records; effects worker for EngineProofs:45 materialize_logical).
- OwnTracks package: username normalization differs at write and lookup (repack owed); Hummingbird needs native
  conversation qualification.
- apps_front connector unit test fails only inside the apps:: group on the Mac (known).
- Harness owed: composed residents root hand-offs; distinct-management birth signing.

## Not landed / held

cx-oracle dd80466a1 and codex/oracle-v7-qualification b32f15604 (conflict with main; wait for the oracle7 batch);
statement-fixes (WIP); qualify-doc-contention (WIP).

## Next steps

1. Read both gate verdicts (COMMANDS.log "GATE ... verdict"); send infra the green one (c4264f9cb preferred) and
   name each red to its owner in one line.
2. Land cx-aa and cx-hp when they finish; rebuild once for both; gate.
3. Take hot-path's Fixtures re-records; residents/distinct-mode harness.

## Hygiene done 2026-10-29

/var/lib/mini-spk-worlds emptied through install-user-world remove (each logged in COMMANDS.log); my old rpool tree
/othersys/lanes/integ removed. Rules: named-file commits with `git commit -F`; never `git add -A` or `git stash`;
filtered tests; PID files; stop only by PID file; lake/git on hbox as hbox; disk pressure = stop and tell ember.
