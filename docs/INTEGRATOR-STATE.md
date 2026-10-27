# Integrator state

Present-state record of the integration lane, rewritten whole when its shape changes. A successor reads
this first, then `/build/lanes/integ8/COMMANDS.log` on dregg-build.

## The shape (COORDINATION §4, 54feb532e)

There are no numbered cuts after cut 13. A lane's pushed branch is merged into main as it lands (fast-forward
where possible, dependency order only when two land together; a branch that conflicts semantically with
another lane's design is named to the coordinator, not resolved by the integrator). dregg-build builds MAIN
continuously in one warm tree, `/build/lanes/integ8/src` (packages seeded once, never a fresh worktree):
when a build finishes, the next starts from whatever main is then. The gate runs on the newest built main;
reds go to the coordinator within minutes (file:line, owning lane) and are fixed forward. A "candidate" is
the newest built main that passed the gate; each is reported in one line, and infra ships the one ember names.

## Where things are

- Branch `integration/2026-10-26` (GitHub). Local worktree `/Users/ember/dev/minidregg-lanes/integration-r2`
  on branch `integration/r2-staging`; push with `git push origin integration/r2-staging:integration/2026-10-26`.
- Mac: `scratchpad/integration/maccheck.sh` (workspace check minus Linux-only crates; spk-host lib excluded),
  `python3 scripts/host-operations.py check`, `WORKSPACE_GATE_MEMBERSHIP_ONLY=1 scripts/check-workspace.sh`,
  `scripts/build-mini-kernels.sh && lake build Host.Main Host.ClientConsentSession` in
  `/Users/ember/dev/minidregg-lanes/integration` (the warm Mac tree; fast-forward it to the cut first).
  The Mac's open-file ceiling fails large Lean builds at random: rerun once.
- dregg-build (`lanes@178.105.4.114`, `~/.ssh/id_portable`): one lane dir per cut under `/build/lanes/integN`;
  the build script is `/build/lanes/integration-build.sh` (env `LANE`, `TIP`, `LAKE_FROM`), stages
  tests → host → consent → rust → pack → candidate `/build/candidates/<sha>/READY`.
  Gate: `/build/lanes/integ4/gate-cut*.sh` (tour = JWF via `tour-run*.sh` incl. tour-chromium with the box
  Playwright; composed = `composed-full*.sh`, which runs `composed-inputs.sh` from a source tree under
  `/build/lanes/cs-<run>/src` because the lanes sudo rule anchors there), writes `gate-<sha>/jdeploy3-gate-v2.json`
  via dregg-infra `gate-from-runs.py`. enrol-resume from custody-drivers' `enrol-resume-acceptance.sh`.
- Chain per cut: `/build/lanes/integ4/cutN.sh` launches build, then gate and enrol-resume; every child
  writes its PID file at spawn (`build.pid`, `gate.pid`, `enrol-resume-cN.pid` under the cut's lane dir,
  the chain itself `integ4/cutN.pid`). Stop only by those files.

## Cuts

| cut | integration sha | candidate | gate |
|---|---|---|---|
| r1 | 55e483e0 | hbox `/tank/dregg-build/claude-integration-20261026/C` | rows 118/23/4 (pre-gate-v2) |
| r2 | 45f45d15 | `/build/candidates/45f45d15…` | rows 112/25/8/3; JWF 24/24 |
| r3 | 6236826f | `/build/candidates/6236826f…` | rows 131/5/9/3 |
| 4 | a94bed71 (main 6b824270) | `/build/candidates/a94bed71…` | FAIL: J0 completion key; composed seal |
| 6 | 23861533 | `/build/candidates/23861533…` | FAIL: tour-chromium timeout; composed apps/connector/residents blocked |
| 7 | 3315a908 | `/build/candidates/3315a908…` | FAIL: tour-chromium (old jtour); composed at ROOT SETUP (old runner) |
| 8 | 26418b6b | none (host build killed by memory) | skipped |
| 9 | 5fdfa393 | none: consent stage red (below) | no gate |
| 10 | 006cd214 (merged to main by the coordinator) | not built | — |
| 11 | af84d8cf | folded into 12 | — |
| 12 | f1ce1626 (main) | stopped by PID for cut 13 (integ8/stop-c12.list) | — |
| 13 | a75d89d6 (main) | building in integ8 (cut13.sh) | first ship on green |

Cut 11 took: main f392e9bb, hermes e11eef11, custody-drivers e471d6f2, app-market 2a7d092f, hot-path-codec
acad2eb7, un-assurance e6eac995, un-bend 91f8a83c, un-deputy 3bf7d7be, un-fixtures a6a32103, un-pb-codec
470f41e7, un-pb-exec 64211340, un-pb-seal 31e65265, un-seats ccb34bc5, un-verify 9f5a7cf4, un-world (newest),
plus web-frontend 33c13554, lean-l13-laws d8251be0, un-native-rows, un-moves e9d0f2c1, un-pred-census
already in at cut 10. Held out: lane/lean-critical and lane/un-effects (one flag-day cut, scheduled by the
coordinator).

## Cut 9's red, and its cause

`lane-build.sh consent` failed at `Compiler/PersistedCodecTagCensus.lean:300` ("registry-only
native_host_genesis_source_v6"): the source says v7, but the lane's `.lake/build/.../PersistedCodecTags.olean`
was the 04:31 v6 olean while its `.trace` (14:23) claimed v7 inputs. Cause: integration-build.sh seeded each
cut's `.lake` with `cp -al` of a whole previous tree, `build/` included, so oleans and traces are hard links
shared with other trees (link count 8-11), and Lake rewrites a trace in place. Fixed in integration-build.sh: seed
only `.lake/packages`; Lake's artifact cache restores the build dir as fresh inodes.

## Named reds outstanding

- un-pb-twins d8cc7d72: not merged; redoes un-pb-wal's dealer commit/emit in native/private-backend (dzk_store.rs,
  sh2t_id_store.rs, scripts/check-rust-tests.sh). Waits for the lane to merge main and keep one design.
- Cut 13 carries three flag days (lean-critical, un-effects, hot-path-v4): codec-shapes-regen.py runs once on the
  box if the census reds on moved fingerprints.

## Conventions

- Merge each cut's integration tip into main (fast-forward where possible, never reset) and push.
- install-user-world's companion pin is recomputed from the merged controller-world.py whenever both sides moved.
- Named-file commits, `git commit -F` from `scratchpad/integration/<unique>.txt`; never git stash.
- Filtered tests only (the tests stage of integration-build.sh lists the per-lane filters).
