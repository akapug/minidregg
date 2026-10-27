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

## Cuts and builds

| cut | sha | outcome |
|---|---|---|
| r1/r2/r3 | 55e483e0 / 45f45d15 / 6236826f | candidates; rows (INTEGRATION-1/2.md) |
| 4, 6, 7 | a94bed71, 23861533, 3315a908 | candidates `/build/candidates/<sha>`; gate FAIL (named in reports) |
| 8, 9 | 26418b6b, 5fdfa393 | no candidate (OOM; stale hard-linked olean) |
| 12 | f1ce1626 | stopped by PID for cut 13 (integ8/stop-c12.list) |
| 13 | a75d89d6 | host stage OOM-killed by co-tenant memory on swarm.slice |
| main a7b5afec | — | stopped by PID on the coordinator's word (integ8/stop-main.list) |
| 14 | aa9366f8 | phase A running: `integ4/cut14-regen.sh` (pid file cut14-regen.pid): seated host closure, then `codec-shapes-regen.py` once; its diff lands in `integ8/regen.patch` |

Main since aa9366f8 (also to build): pd-host-rate 9f9bac79 (its test-host-operations reds fixed), oracle-lifetime-grant
44d55995, oracle-grant-factory 671e614f, lean-audit-c 86f15d3c (main = bca2cc59). The oracle branches add Lean
fixtures, so the census may want the regen again over the newer tree.

Next steps: commit regen.patch onto main (from the Mac: scp the patch, `git apply`, commit, push); start the full
build at that sha in integ8 (a copy of main-next.sh with the tip fixed; seats 4 on a clear slice; check swarm.slice
for co-tenants first); if the census still reds (oracle fixtures), rerun the regen there once more. When a host
stage ends cleanly, tell infra (aed5ecf506cf840af) and the coordinator the tree `/build/lanes/integ8/src` for the
dregg-ref copy. Report each candidate in one line; the coordinator spawns a rows validator for it (featured-qualify,
batch tables, Hermes/tier, japps co-edit, codex's Oracle v7 world).

Red routing: lean-audit-c reds go to L1c (a855b4edb693e03ae) directly; un-stream-continuity reds
(ApplicationStreamContinuityFresh pole proofs, NativeHostReplay.lean:3816) to the deputy a308118209b4a48ea; all
others through the coordinator. Expected reds, not new: the eight hand-rolled genesis writers (acceptance.sh,
application-acceptance.sh, authority-acceptance.sh, selected-release-acceptance.sh, grain-runtime/acceptance.sh,
jpay2.sh, jpay6.sh, scripts/fn-e1e2/setup-mini.sh) until L2 converts them; rows refusing an older world as
noncanonical/epoch after the re-genesis.

Rules now in force: the Mac runs cargo check and filtered Rust tests only, never Lean (the regen script runs lake
itself: box only). Lanes do not build; the integrator is the one validator.

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
