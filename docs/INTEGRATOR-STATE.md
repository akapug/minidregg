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
| 4, 6, 7 | a94bed71, 23861533, 3315a908 | candidates `/build/candidates/<sha>`; gate FAIL (named in reports). Cut 7's six orphans (mini serve/web, link-sqlite-store, credential-verifier; cwd integ5/src) stopped by exact PID 2026-10-27 21:28 (integ8/stop-c7-orphans.list); `/build/lanes/integ5` deleted (24G) |
| 8, 9 | 26418b6b, 5fdfa393 | no candidate (OOM; stale hard-linked olean) |
| 12 | f1ce1626 | stopped by PID for cut 13 (integ8/stop-c12.list) |
| 13 | a75d89d6 | host stage OOM-killed by co-tenant memory on swarm.slice |
| main a7b5afec | — | stopped by PID on the coordinator's word (integ8/stop-main.list) |
| 14 | aa9366f8 | phase A: host stage rc=1 at 21:14 (integ8/COMMANDS.log) |
| 14 A2 | 36f719cc5 | host stage rc=1 at 21:37 (903 s, peak 16.1 GB): only Kernel.ResourceBirthPolicyController, lean-audit-c's three proofs that never elaborated; fixed on main 61bf01e1d (verified by `lake env lean` in integ8, seconds per try); no regen ran |
| 14 A3 | 8103b29a4 | host stage rc=1 at 21:53 (566 s, peak 16.2 GB): only Kernel.PlatformCell (c0b2d6ab1's seventh Admits conjunct unpropagated to four proofs); fixed 26fcdd889 |
| 14 A4 | 26fcdd889 | host rc=1 at 21:55 (38 s): only Kernel.PlatformInstallReceiver (admitsObserved_decides, decide instances after c0b2d6ab1); fixed cacefcba8 |
| 14 A5 | cacefcba8 | host rc=1 at 21:58 (41 s): only Kernel.NativeHostReplay:3823 (extendExact: exactCandidate sets headTag since e0916a53f, advance does not; #guard_msgs 4827/4829 follow). Fixed by the deputy, a8eb2c50e (post image = successor up to its head tag; FnSelectedHistoricalStep's admitted_record gains ∃ headTag; reds there go to the deputy) |
| 14 A6 | a8eb2c50e | host rc=1 at 22:09 (294 s): only Host.Main:2048 (claimOf: the intent subject is a SubjectId; the rate table is keyed by Nat); fixed 43023f83f |
| 14 A7 | 969929026 | host stage CLEAN at 22:22 (534 s). Regen: A7 rc=2 (seed v5), A7b rc=1 (seed proofs), A7c rc=2 (ADMITTED-INPUT-CONTEXT trailing byte, bumped by hand), A7d rc=2 (DREGG/CLOCK: literal twin in ClockCell vs the registry constant), A7e rc=0 at 23:50 (938 s, peak 20.2 GB, 638 pins). Its diff is main da4a7645e (integ8/regen-A7e.patch); the tool changes are held on local branch integration/regen-tool 21077e063 for after the candidate |
| full | da4a7645e | `integ4/main-full.sh da4a7645e` (pid file integ4/main-full.pid; build.pid, then gate.pid + enrol-resume.pid under integ8) started 23:53 |

A3's tree (main 8103b29a4) holds everything since aa9366f8: pd-host-rate, oracle-lifetime-grant, oracle-grant-factory,
lean-audit-c, un-effects 2acd8acf (effect Plan; its codec pins re-emit with this regen), un-pb-twins 134535c2,
demo-seed, app-recipes (rows validator aeee8349c191e8506 runs them on the candidate; Wekan/WordPress/IPython need
MINI_IMPORT_PROFILE=market-large-v1), snipe-rate-row (its report at docs/evidence/snipe-rate-row-2026-10-27.md) and
un-web-front 0da04999 (front-page document; infra's step 9c depends on it). Also since: app-market db312c6f (30e24095f; b2.sh resolved per function against app-recipes, L13 agreed). Correction to that commit message: ExpenseOwl's positive-amount POST is reasoned from upstream, not row-proven (B2's run left GET /expenses empty); unproven until the rows validator runs it.
After A3's tip (Rust only, in the full build): hermes 68394077 (6f4251c21; contained tools, room fields 1014/1015,
J14_TOOLS row) and fb15f121b (redteam test initializer for un-web-front's Shell.front_doc; the mini bin's tests did
not compile). The first candidate carrying both bc88a5ab (frame v8)
and hermes ea8a991e (e2374f120, the await bridge; any full build from main >= d3a0c41f3): send its sha and path to L4b (ad81db6d6fd317d3a) and
the coordinator at once; L4b runs J14_TOOLS and J14_AWAIT as one run against it (3315a908 refuses the v8 genesis). Unit
mini-grain-controller@9870001 is free (it was L4's orphan). Also after A3's tip: e7958d3b9 (NativeHost.birthRejection/birthReason arms for
f2010f574's platformUnavailable/platformStale; A3 is expected to red at Kernel.NativeHost and its dependents,
elaboration of the fix pending NativeHostReplay.olean). L1c (lean-audit-c a281e53b8, e59846239; deletes those two
constructors with pricedAt, drops e7958d3b9's arms on merge; unbuilt, not to merge until its warm-tree build
elaborates) seeds its dregg-ref tree from the integ8 copy; tell it when the copy lands.

Next steps: when the full build's host stage ends cleanly, name `/build/lanes/integ8/src` to infra (aed5ecf506cf840af),
the coordinator and L1c (acf52d65283ef4ebc), and run `swarm-build lake lean Effects/Revival/Statements.lean` there for the
effects-revival lane (a83b7949ba401cca5; `lake lean`, not `lake env lean`, applies the lakefile's options). When the
candidate exists: report "candidate <sha> at <path>: gate <verdict>, reds by name" to the coordinator and L4b
(ad81db6d6fd317d3a; J14_TOOLS + J14_AWAIT); then push integration/regen-tool 21077e063 to main (the next build checks
ClockCell's import). Every lane named to land so far is on main (hermes, hermes-b, abuse-caps, snipe-unconfigured,
redteam, effects-revival); welcome-hermes is still to come.

Red routing: lean-audit-c reds go to L1c (acf52d65283ef4ebc) directly; Hermes to L4b (ad81db6d6fd317d3a); L13 a1618140607ac439b; un-stream-continuity reds
(ApplicationStreamContinuityFresh pole proofs, NativeHostReplay.lean:3816) to the deputy a308118209b4a48ea; all
others through the coordinator. Expected reds, not new: the eight hand-rolled genesis writers (acceptance.sh,
application-acceptance.sh, authority-acceptance.sh, selected-release-acceptance.sh, grain-runtime/acceptance.sh,
jpay2.sh, jpay6.sh, scripts/fn-e1e2/setup-mini.sh) until L2 converts them; rows refusing an older world as
noncanonical/epoch after the re-genesis.

Rules now in force: the Mac runs cargo check and filtered Rust tests only, never Lean (the regen script runs lake
itself: box only). Lanes may build and run again (ember, baef327e4), but only in warm, incremental trees on
dregg-ref or hbox, never a fresh tree and never a search from / or ~. The integrator still merges, builds and
gates main and fixes reds itself.

## Cut 9's red, and its cause

`lane-build.sh consent` failed at `Compiler/PersistedCodecTagCensus.lean:300` ("registry-only
native_host_genesis_source_v6"): the source says v7, but the lane's `.lake/build/.../PersistedCodecTags.olean`
was the 04:31 v6 olean while its `.trace` (14:23) claimed v7 inputs. Cause: integration-build.sh seeded each
cut's `.lake` with `cp -al` of a whole previous tree, `build/` included, so oleans and traces are hard links
shared with other trees (link count 8-11), and Lake rewrites a trace in place. Fixed in integration-build.sh: seed
only `.lake/packages`; Lake's artifact cache restores the build dir as fresh inodes.

## Named reds outstanding

- None open on main beyond A3's outcome (un-pb-twins landed at 134535c2 via 36ce6bd3d).
- A lane's "proved" is a claim until the integrator's build elaborates it: lean-audit-c's three proofs never
  had (fixed 61bf01e1d).
- Cut 13 carries three flag days (lean-critical, un-effects, hot-path-v4): codec-shapes-regen.py runs once on the
  box if the census reds on moved fingerprints.

## Conventions

- Merge each cut's integration tip into main (fast-forward where possible, never reset) and push.
- install-user-world's companion pin is recomputed from the merged controller-world.py whenever both sides moved.
- Named-file commits, `git commit -F` from `scratchpad/integration/<unique>.txt`; never git stash.
- Filtered tests only (the tests stage of integration-build.sh lists the per-lane filters).
