# Integrator state

Present-state record of the integration lane, rewritten whole when its shape changes. A successor reads this,
then `hbox:/othersys/lanes/integ/COMMANDS.log`. dregg-build and dregg-ref were deleted on 2026-10-28; their
history (cuts 4-14, A7-A13, candidates up to 349e59ef1/68cf4ba7a/9bd52317c) is in git history of this file.

## Shape

One integrator (Opus), Kimi (`claude-kimi -p`, read-only, from the repo) for batched reviews: a batch of
landing diffs every few landings, plus anything risky or big (oracle7: one review). Lanes push branches and send
shas; the integrator merges main into them where needed, lands, builds main's tip on hbox, gates, reports.
No codec pins, no census, no regen (lane/no-pins landed). Statements may be rephrased, never weakened.

## Where things are

- Mac landing worktree: `/Users/ember/dev/minidregg-lanes/integration-r2`, branch `integ/main`; the staging
  tip is pushed to `origin/integration/staging` and fast-forwarded onto `main` once its host stage elaborates.
  Mac checks: `CARGO_TARGET_DIR=/Users/ember/dev/minidregg-lanes/target-integ cargo check/test` (filtered).
- hbox warm tree: `/othersys/lanes/integ/src` (rpool SSD; clone of GitHub, packages copied from
  /othersys/lanes/lean-audit-c, same manifest). No Lean on the Mac.
- Build: `/othersys/lanes/integ/integ-build.sh SHA` (pid file integ/build.pid): rust-check, host, consent,
  then umbrellas (non-fatal, beside rust; umbrellas.pid), rust, pack -> `integ/candidates/<sha>/READY`.
  Seats 8, SWARM_MEM_MAX 56G (env SEATS/JOBS/MEM), seat root integ/seats. Stage logs integ/logs/<stage>.log.
  Outputs from the previous build move to integ/old/ at start. Launch:
  `ssh hbox 'cd /othersys/lanes/integ && setsid nohup ./integ-build.sh SHA > build.out 2>&1 < /dev/null & echo $! > build.pid'`
- Gate: `/othersys/lanes/integ/gate.sh SHA` (pid files in integ/gate-<sha8>/{tour,composed,enrol}.pid):
  tour (J0-J8 journey world + JWF --dry, Playwright /tank/dregg-build/rows-0ce31391/pw/node_modules),
  composed (dregg-infra 628a9aa edge exported at integ/dregg-infra-628a9aa, run dirs /ci/c-*, port 22640,
  world-ups under `flock -o /tank/lanes/world-up.lock`), enrol-resume, then gate-from-runs.py ->
  gate-<sha8>/gate.json. Harness = the candidate's own source.tar (built at the gated tip).
  The old "tests" stage of integration-build.sh did not survive dregg-build; filtered tests run per landing.
- Mac scripts from the predecessor: scratchpad `integration/` (gate-cut*.sh, tour-run2.sh, composed-full2.sh).

## Now (2026-10-29)

| item | state |
|---|---|
| lane/cx-web cdec5b8dd | LANDED main 1baf18816 (cargo check clean) |
| cx-app-interface batch | worker scripts committed in order; tips merged into lane/cx-app-interface d78d02191; merged in staging 1b7f57104 (build.rs/apps.rs twin with cx-web unified into one declarations loader); op literals named 0f62537e1. Lean (Effects/Revival/Hosted*, ApplicationReceivingDomain, ApplicationDispatchAdmission) elaborates in the hbox build of 35f75c4d2 |
| lane/no-pins 977dce2e3 | committed from codex's tree; merged in staging f6b52f3b8 (census modify/delete -> deleted); closure ceiling + surfaces 0f3c5b556 |
| iter-speed ad2a19c10, un-japps-rows, qualify, qualify-lean-refusals | merged in staging (scripts/docs) |
| build 35f75c4d2 | cold host stage running on hbox from 01:01 EDT (793 modules) |
| perf-batch1 | NOT landed: lane/hot-path merged it (fd54bb732); hot-path sends the sha (CellSlot 287/289 red is theirs) |
| statement-fixes | NOT landed: WIP, uncommitted in hbox /tank/lanes/statement-fixes/src, no branch |
| qualify-certify-prefix 9d00fba59, qualify-doc-contention a0b45fe8e | NOT landed: Lean, unchecked; next build after 35f75c4d2 |
| hermes-b | nothing new (ad38ebda4 on main) |
| cx-oracle dd80466a1, codex/oracle-v7-qualification b32f15604 | NOT landed: conflict with main in 9 / 3 files (deploy/oracle/acceptance/agent.py, j14.sh, broker.rs, grain-runtime main.rs, apps_worker.rs, world-up.sh ...); waiting for the oracle7 codex batch, then merge main into it, one Kimi review |
| lane-tree acquire bug | `ls -tr -d $(trees)` with no trees lists `.`; not used here |

## Expected senders

hot path (deep Lean, batched), apps-for-agents (Hermes app tools), demo-path ad899edab1627208d (story invite,
app writes, IPython, japps rows, public reader; wants the candidate path), oracle7 (codex). Rehearsal 3 on a
fresh genesis in infra's container on workhorse: hand the candidate to a21547c57335a2932.

## Rules in force

Named-file commits with `git commit -F`; never `git add -A`, never `git stash`; unsigned commits fine. Filtered
tests only. PID files for every detached job; stop only by PID file. Lake/git on hbox as hbox, never root.
Disk pressure: stop and tell ember. Sum of swarm-build caps on hbox under ~100 GB.
