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

## Main and candidates

Main 6eb281668 = candidate d9661be99 (built green 06:55) + demo-path-web 0be1e5b4b (Rust, Mac-tested, not yet in a
candidate) + root-state law 17 and SESSION-STATE-2026-10-29 (docs).

| candidate | verdict |
|---|---|
| c7a632f7b | tour 65/73 (8 story reds), enrol-resume PASS; composed rooms/churn/documents/apps/store-restart PASS, connector red at register-route |
| b39563f17 | composed: linkage fix holds (register-route PASS); connector red at journey capture |
| 7001c0a9f | composed: same capture red; capture stderr now retained: `mini: export did not complete` (app_document.rs:457, curl --fail through the https route front) |
| d9661be99 | MAIN's built base. Composed rerun with KEEP_WORLD at /ci/c-d9661b-k for infra to curl the front by hand (take it down after infra says done: world-down.sh /ci/c-d9661b-k/inputs, then jworld-scratch.sh down /ci/c-d9661b-k/w with dregg-infra-69c17a3) |

## Staging only (not on main)

- hot-path batch 1 (lane/hot-path 1e207e402, merged as f34b03095): deep build running on hbox since 07:37
  (integ/build.pid; COMMANDS.log "BUILD f34b03095"). Kimi review of its in-process Ed25519/SSHSIG shim and theorem-line
  diff running (scratchpad integ2/kimi-hp.md). Lands on main when the host stage is green and the review is clear;
  expect Fixtures.NativeAcceptedFixture `#assert_compiled` re-record. Its numbers: SandMD GET serving CPU 1.1 s -> 160 ms.
- Kimi review of route v4 (apps-agents e6c5d4da4, already on main via d9661be99) is pending (integ2/kimi-route3.md):
  fix forward on main if it finds something real.

## Reds

- Connector: export through the route front fails (curl --fail: front leaf/CA, late attach, or grain 4xx/5xx); infra
  a21547c57335a2932 is checking on the kept-up world.
- Tour: tour-can-any + 7 story-* rows; demo-path's fix 0be1e5b4b is on main, re-run owed in a world window.
- Umbrellas: two stale Fixtures (NativeAcceptedFixture:173, NativeDocWriteFixture:149; effects, ruling (c)).
- Harness owed (mine): residents root hand-offs (provider-custody-copy v2 + controller register under sudo -n) in the
  composed residents phase; distinct-management births signed by owner 7 with 8 as owner/manager (deployed shape:
  scripts/workroom/provision.sh:151-154,292).

## Not landed / held

demo-path-market 27db3d1b7 (its featured test is red until four packages are built and the fixture regenerated);
cx-oracle dd80466a1 and codex/oracle-v7-qualification b32f15604 (conflict with main; wait for the oracle7 batch);
statement-fixes (WIP, no branch); qualify-doc-contention (WIP proofs). FEATURED: Etherpad/WBO/Wekan keep their declared
appIds until their repackaging lands with its declarations; repackaged apps may be missing from the 10-27 index fixture.

## Next steps

1. When f34b03095 is READY and Kimi is clear: merge staging into main, push, gate it (tour + composed sponsor/route
   front), send the READY path to hot-path, infra and demo-path; tell demo-path its world window is open.
2. Take down /ci/c-d9661b-k when infra is done.
3. Wire hot-path's flatness bench into the gate.
4. Harness: residents root hand-offs; distinct-mode birth signing.
5. Hand infra (a21547c57335a2932) the rehearsal-3 candidate once hot-path, demo-path and oracle7 are in.

## Hygiene done 2026-10-29

/var/lib/mini-spk-worlds emptied through install-user-world remove (each logged in COMMANDS.log); my old rpool tree
/othersys/lanes/integ removed. Rules: named-file commits with `git commit -F`; never `git add -A` or `git stash`;
filtered tests; PID files; stop only by PID file; lake/git on hbox as hbox; disk pressure = stop and tell ember.
