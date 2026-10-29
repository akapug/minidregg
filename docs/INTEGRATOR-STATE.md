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

Main 636b1baeb. Staging (`integration/staging`) = main + hot-path batch 1 f34b03095 (built green 08:18, Kimi review
clear: no findings) + lane/spk-fresh bf49ce23a (Etherpad 3.3.12 r6, FEATURED rank 1 repointed to ksyn7qa4..., commit
on staging) + lane/demo-path-market 27db3d1b7 (merge 8cb74aba5; its tests carried into main's appId-list FEATURED shape).

| candidate | verdict |
|---|---|
| d9661be99 | main's last built base; composed apps:sheet and store-restart red (08:02) |
| f34b03095 | hot-path batch 1: READY 08:18; umbrellas rc=1 (expected Fixtures re-records); not gated |
| 8cb74aba5 | BUILDING 13:17 (integ-build2.sh, SEATS=4 MEM=40G, pid in integ/build.pid); gate with gate10.sh (adds law-17 flatness) |

## In flight

- Fixture regen for the market's installable test: the 8 qualified SPKs (packageIds = apps/interfaces/*.json) are
  streamed from hbox:/tank/lanes/spk-fresh-*/cache to dregg-forge:/var/lib/spk-fresh/qualified-2026-10-29/in
  (Mac script scratchpad integ2/xfer-spk.sh, pid xfer-spk.pid). Next: lay out in/<app>/out/<app>.spk, run
  `fresh-index.py --apps ... --recipes repo/apps/packages --spk-tool /var/lib/spk-fresh/tools/spk --out .../out`
  (adopt mode), copy out/local.json over native/resource-client/tests/fixtures/fresh-local-index-2026-10-29.json,
  set BUILT_AT in apps_search_shows_the_featured_set_first_with_its_typed_tools to Etherpad's packageBuiltAt, run
  `cargo test --bin mini -- apps::tests` (24 tests). Expect green: every FEATURED appId is then pinned or upstream.
- WBO: qualified per landings.md but its repack declaration has not landed (wbo.json still upstream ac72e0d1);
  FEATURED keeps the upstream WBO until spk-fresh sends the sha. Wekan, MediaWiki, Forgejo blocked (landings.md).
- Codex workers (apps-agents, demo-path, hot-path) still running; each leaves target/*-commit.sh and
  scratchpad cx-*/out.md. Land on finish: read report + diff, run its script, merge to staging, rebuild.
- Infra (add189844d158e3a7) told the candidate is building and where the SPKs/local.json are.
- Peers: SPK-fresh a58fcf100f4438710 sends shas.

## Reds

- apps::tests installable + featured-search: red on staging until the fixture regen above lands (red by design).
- Flatness (law 17): fails on main's code (60 ms at append 2, 1.7 s at append 141); hot-path codex is on it. Bench scripts/perf/flatness-bench.py (lane/hot-path); gate10.sh runs the candidate's scripts/perf/flatness-gate.sh and records FAIL when it is absent.
- Composed: apps:sheet same-Store app and store-restart:shared:resolve (d9661be99); connector capture (7001c0a9f).
- Umbrellas: Fixtures NativeAcceptedFixture, NativeDocWriteFixture, BirthPlanPoles re-records; Effects/Revival
  EngineProofs.lean:45 materialize_logical.
- Harness owed: composed residents root hand-offs; distinct-management birth signing.

## Not landed / held

cx-oracle dd80466a1 and codex/oracle-v7-qualification b32f15604 (conflict with main; wait for the oracle7 batch);
statement-fixes (WIP); qualify-doc-contention (WIP).

## Next steps

1. 8cb74aba5 READY -> merge staging into main, push, gate10 (tour + composed + flatness), hand READY + verdict to infra.
2. Fixture regen (above) as a fix-forward commit; codex landings as they finish; rebuild once per batch.
3. Wire residents/distinct-mode harness; take hot-path's Fixtures re-records.

## Hygiene done 2026-10-29

/var/lib/mini-spk-worlds emptied through install-user-world remove (each logged in COMMANDS.log); my old rpool tree
/othersys/lanes/integ removed. Rules: named-file commits with `git commit -F`; never `git add -A` or `git stash`;
filtered tests; PID files; stop only by PID file; lake/git on hbox as hbox; disk pressure = stop and tell ember.
