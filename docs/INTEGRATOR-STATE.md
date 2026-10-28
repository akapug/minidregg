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
| full | da4a7645e | `integ4/main-full.sh da4a7645e` (pid file integ4/main-full.pid; build.pid, then gate.pid + enrol-resume.pid under integ8) started 23:53: host clean 00:24:47 (1670 s); consent rc=1 at 00:28 (PersistedCodecTagCensus: the platform install receiver's six identities unregistered). Fixed fbb66b069 |
| A8 | fbb66b069 | host clean 01:02 (1842 s); regen rc=0 (644 pins, six additions, integ8/regen-A8.patch) → main 1e976af0f; consent rc=65 only because the host artifacts predate the new pins (companion check: PersistedCodecShapes.lean) |
| full | 1e976af0f | `integ4/main-full.sh` started 01:07 (tests stage green 01:09; host stage from 01:09:25) (main-full.pid 3307367; build.pid, then gate.pid + enrol-resume.pid under integ8). Before relaunching any build, move integ8/{native-out,consent-out,artifacts,fixtures} aside (the host stage refuses existing outputs, rc=73) |
| 1e976af0f result | — | host clean 01:36 (1635 s), consent clean 01:42 (330 s), rust rc=1 01:45: mini-private-compute (`--features demo`) 19× E0425 `custody::AnchorHandle` (un-pb-twins a078ee6b4 gated it `cfg(test)`; its users are `cfg(any(test, feature = "demo"))`). Fixed 0ce313917 |
| full | 0ce313917 | CANDIDATE `/build/candidates/0ce31391790a7e2ed9f83eb1b8bb85d6556a0de3` 01:56 (host 231 s, consent 90 s, rust 61 s, pack 9 s; tests green; 23 binaries incl. mini-private-compute). enrol-resume PASS. Gate: tour 51/51 PASS; composed FAIL, a dregg-infra red (render-authorized-keys.sh called `mini enrollment-view` without the v2 Host pin; fixed by infra at dregg-infra 026d132). Composed rerun against that edge: `integ4/composed-rerun.sh TIP EDGE_REV` (pid file integ4/composed-rerun.pid; verdict line in integ8/COMMANDS.log; keep the run root short: a long one overflows the resident codec socket's SUN_LEN) |
| 0ce31391 composed rerun | edge 026d132 | FAIL 02:22: world up, rooms/churn/documents pass; apps input refused at scripts/spk-platform/same-store-profile.py:29 "broker must belong to selected grains root" (the Python harness still allowed only the global /run socket or <grains>/broker.sock; spk-host has required <grains>/runtime-<store>/broker.sock since 5d23a2394). Fixed bea8928a5 (ws-continuity-fixture.broker_endpoint, the one spelling). The composed run takes its scripts from the candidate's source.tar, so the fix is proven only by the next candidate's gate |
| full | 1af366fe9 | `integ4/main-full.sh` started 02:25 (main-full.pid 3433976; the launcher subshell 3433959 is its parent; build.pid, then gate.pid + enrol-resume.pid under integ8); tests stage green 02:26; host stage from 02:26:38. Carries the regen tool, rust-check, effects-revival, hermes-b b740e6f0, grain-bare-prepare 746b182d, abuse-caps, snipe-unconfigured, red-jserve-envelope ffe1623f, rows-ledger 0a05ab6b and the broker fix |
| 1af366fe9 result | — | host clean 02:59 (1995 s); consent rc=1 03:04: census, 37 structural moves plus DREGG/CLOCK/v5 owner-less (430e3fe96's twin deletion; the census counted owners by literal only, nine more pins were already fingerprint 7). Fixed f8c17f0f5 (a registry-constant reference is ownership) |
| bd37686c0 | — | follow-on host stage rc=1 in 3 s: registry check, literal op 68 at native/spk-host/src/lifecycle_v3_native.rs:728 (7b3564733's test). Fixed f1ecba539 |
| A9 | f8c17f0f5 | host clean 03:14 (397 s); regen rc=2 03:18: the bare prefixes DREGG/NATIVE-HOST/LOG-TAG and DREGG/OBJECTIVE-BEND/ADMITTED-INPUT-CONTEXT moved in the same round their children were bumped (the tool judged them before the build that births the new name; LOG-TAG was also not declared `prefix_`). Fixed a62cab510 (deferred to the next round; selftest case) |
| A10 | a62cab510 | host clean 03:54 (1984 s); regen rc=1 04:01: Compiler/DurableCheckpointCodec.lean:530 `native_decide` false, seedEpoch_spentMap_refused spelled "this Host DREGG/NATIVE-HOST/LOG-TAG/v4" beside logTagLabel and the regen bumped the tag to v5. Fixed on main a5f0e8c89 (the theorems interpolate logTagLabel and StoreEpoch.current.accumulator). Partial diff integ8/regen-A10.patch |
| A11 | c99af001d | host clean 04:31 (1663 s); regen rc=0 05:27 (3328 s, two rounds, 644 pins; SEAT/TX, SEAT/TX/PUBLISH, SYSTEM to v5); consent rc=65 only the companion check on host artifacts older than the pins. Diff is main 2d8b7ed54 |
| full | 2d8b7ed54 | `integ4/main-full.sh` started 05:29 (main-full.pid 3664533; build.pid, then gate.pid + enrol-resume.pid under integ8). Carries everything in the A11 next-steps list below |
| housekeeping | — | 05:3x: the integ8 `*.prev-*` output dirs from tonight's reruns deleted (listed with sizes in COMMANDS.log, ~2.3 GB); the newest of each kind kept |
| 2d8b7ed54 gate | — | CANDIDATE /build/candidates/2d8b7ed544100acfaeb9ff2f9b597c31b8cb81e6 05:48 (host 632 s, consent 128 s, rust 141 s); enrol-resume PASS; tour 51/51 PASS; composed FAIL (first run without inputs; rerun edge 026d132 06:07: documents:protected "owner Host differs", scripts/protected-document-same-store.py:46: bindings named /build/candidates/<sha>, workspaces the world-installed copy, same bytes). Fixed 7027e0ace (composed-inputs uses the installed manifest after a digest check) |
| full | 7027e0ace | started 06:10 after stopping 296e4c1c0 by main-full.pid/build.pid in its tests stage. Carries un-ns-owner 125927331 + 29d3152d3 (f0afc5ae7), un-stream-continuity a971a649d and the fix. No Lean since 2d8b7ed54: the next candidate keeps the 2d8b7ed54 genesis |
| 7027e0ace progress | — | tests green 06:12, host 06:12-06:18 (no Lean change), consent from 06:18; on READY its chain runs gate + enrol-resume (proves the composed fix) |
| 7027e0ace | — | CANDIDATE /build/candidates/7027e0ace4bf5763dd1d78b47380dfe4ceb15b57 06:21; enrol-resume PASS; gate (gate.pid, gate-7027e0ac/{tour,composed}.log) running from 06:22. 2d8b7ed54's verdict sent to the coordinator 06:2x |
| 7027e0ace gate | — | FAIL 06:39: tour 51/51 PASS, enrol-resume PASS; composed rooms/churn/documents pass (the manifest fix holds), apps stopped "[Errno 2] ... '<run>/inputs/evidence'" (composed-inputs.sh named the selection's evidence dir, never made it; same-store-inputs.py:122 protected_parent lstat()s it). Fixed 129c04e38 |
| 76758dba6 | — | CANDIDATE /build/candidates/76758dba687cde9447bc45d77931bb7d57527e56 06:41 (host 741 s, consent 346 s; no pin move, keeps the 2d8b7ed54 genesis; un-ns-owner 507d6ce78). Gate: gate-cut3 (candidate harness; its composed will red on the evidence dir) plus `integ4/composed-harness.sh TIP 455f59d57` (pid file integ4/composed-harness.pid; main's harness; writes gate-76758dba/jdeploy3-gate-v2-h455f59d57.json with harnessCommit). Named to the deputy, L4b and infra; verdict pending |
| next | — | `integ4/next-main.sh` (pid file integ4/next-main.pid) waits for the 76758dba6 chain (main-full.pid), moves outputs aside, launches main-full.sh at main's tip then (it carries thin-birth eda65ced8, so a Lean build; pins may move: run the regen if the census reds). main-full.sh now gates with gate-cut4.sh |
| 76758dba6 gate | — | VOID: gate-cut3's tour died (tour-run2.sh/composed-full2.sh edited at 06:44 while that gate read them; never edit a script a running job uses: write a new name). composed with harness 455f59d57 FAIL at apps: refs/jd3-r0.json absent (same-store-inputs.py:239; the rooms phase makes "<op>-room"); fixed da4da558e. Rerun: `LANE=/build/lanes/integ8 TOUR_SUFFIX=-g2 HARNESS=da4da558e NO_NIGHTLY=1 gate-cut4.sh 76758dba…` (pid file integ4/gate-76758dba-g2.pid; results integ8/gate-76758dba-g2/) |
| full | e89fe7b8b | `main-full.sh` (main-full.pid) from next-main.sh at 06:58; tests green 07:03; host stage from 07:03 (thin-birth Lean; run the regen if the census reds). Main since: un-journey-repeat-suffix 1adf59543, the room fix da4da558e, web-parity 0d7af4da9 |
| e89fe7b8b progress | — | host clean 07:15:41 (725 s), consent from 07:15:41; main since: un-bend-seed 98409f5ff (deputy; seed.sh makes lobby-tally first). 07:18 housekeeping: 16 older integ8 *.prev-* dirs removed (listed with sizes in COMMANDS.log), newest of each kind kept |
| e89fe7b8b | — | CANDIDATE /build/candidates/e89fe7b8ba8c477d1538ed6ee1f0e7aeac70c97f 07:22 (consent 209 s, rust 212 s; no pin move, keeps the 2d8b7ed54 genesis; carries thin-birth, 25cfb86bd, 507d6ce78, a8376ce8f). Named to the coordinator, deputy, L4b, infra. Gate (gate-cut4, harness 5da1711bc; integ8/gate.pid) running beside gate-76758dba-g2. Owed on it: `journey.sh --only JP2` (thin birth) |
| next | — | `integ4/next-main2.sh` (pid file integ4/next-main2.pid) waits for the e89fe7b8b chain (main-full.pid), moves outputs aside, launches main-full2.sh (gate-cut5, private runner) at main tip then (carries un-bend-seed, web-parity) |

| aae3e2e37 | — | CANDIDATE /build/candidates/aae3e2e372b045dd43493183144db08212d51659 07:49 (from next-main2.sh; host 392 s, consent 117 s, rust 68 s; keeps the 2d8b7ed54 genesis). Gate gate-cut5, harness 3deedcb6f (integ8/gate.pid), no row-requires: the five 588855a71 JWF rows may red, expected. Named to coordinator, deputy, L4b, infra 08:0x |
| e89fe7b8b composed iteration | — | coordinator 10-28: iterate composed against e89fe7b8b's binaries with main's harness, fix each harness red in place, rerun only the failing phase, until rooms/churn/documents/apps/connector/residents/restart pass; then record the verdict as candidate + final harness sha; a product red is named, not fixed. Driver `integ4/citer.sh` (pid file integ4/citer.pid; standing world /build/ci-e89, log/citer.log, composed/gate-<n>.json; `citer.sh gate RUN HARNESS` resumes from composed's retained ledger) |
| e89fe7b8b composed iteration result | — | rooms/churn/documents pass on /build/ci-e89; apps:sheet harness reds fixed on main: 385ce0a1a (management seed alias), 81d0b3f44 (profile in evidence/profile), d1dc4153e (spkHost custody = broker.rs pinned_root_executable), 4b37017fd (broker runs the manifest's spkHost), 5874ceee6 (scripts/spk-platform/workroom-ready.sh: parent attach+reserve, tool attach), db3f58d94 (factory capabilities from refs/factory.json). /build/ci-e89 is down (its residents 4089401/02/08/09/18 lacked PID files: named to the coordinator). Fresh run `integ4/citer-b.sh` (pid file citer-b.pid) on /build/ci-e89b port 22610, harness db3f58d94. Resuming a citer gate after an input fix: a failed step that recorded no ledger step may have its source pins cleared (keep state.json.before-*); an adapter source change needs `same-store-app.py adopt-adapter INPUT REASON`; a world whose attach already admitted ops cannot take a changed grant: bring up a fresh world |
| full | 7e8a09b7e | 08:24 on the coordinator's go: `integ4/main-full2.sh` (main-full.pid; build.pid, then gate.pid + enrol-resume.pid under integ8; gates with gate-cut6.sh). Carries bf5ead3fa and 11 Lean files since aae3e2e37 (Kernel/ResourceTransaction among them): run the regen if the census reds. /build had 60 GB free; hard stop for new builds below 50 GB. On READY name it to the coordinator, the deputy, L4b and infra (ae95a4eac63b0715e). citer-b (citer-b.pid) keeps running on /build/ci-e89b. Disk table sent; deletion waits for ember |
| citer-b result | — | 08:41, harness db3f58d94, world /build/ci-e89b: rooms/churn/documents pass; apps:sheet stopped at `spk-host grain install` ("grain refused: No such file or directory"). The scratch world (dregg-infra jworld-scratch.sh 026d132) runs one public `mini serve`; NODE/operator/mini.sock (serve-operator, production's store-entry.sh) never exists. Infra's red; named to the coordinator. Harness now refuses it by name: ef71955a2. ci-e89b taken down by `citer.sh down`; 11 resident/broker processes survived without PID files (4151500, 4151510, 4155671, 4155704 families; broker 4151838), named to the coordinator, not stopped |
| 7e8a09b7e result | — | host stage OOM-killed 08:57 (1735 s; Kernel.PayEnrolReceiver 882 s at 15.5 GB, rc 137; Kernel.PayObservationReceiver 15.6 GB; box 29/30 GB under the old 28G cap). The seat table already weights both at 19.4 GB, so the table was not low; the cap was. No candidate |
| citer-b cause | — | apps:sheet "grain refused: No such file or directory": grain-host.json `.miniOperatorSocket` (node/operator/mini.sock) absent in jworld-scratch 026d132; infra's dregg-infra 7d2c765 serves it. gate-cut6.sh now defaults EDGE_REV=7d2c765 (copy at integ4/dregg-infra-7d2c765); citer2.sh = citer.sh on 7d2c765 |
| full | 7280f9db8 | 09:0x `integ4/main-full2.sh` (main-full.pid) with SWARM_MEM_MAX=24G; = 7e8a09b7e + un-deputy 9994a748e + un-spk-ioctx 5cb33bbdf (spk-host io errors name operation and path). Tidy-up `integ4/tidy-10-28.sh` (pid file tidy-10-28.pid) ran beside it, each item logged with its size in COMMANDS.log; ci-e89b kept |
| 7280f9db8 result | — | host stage OOM-killed 09:09:25 (502 s) at the swarm.slice level (scope peak 14.8G; slice oom_kill 15; ~3.5G of the slice is reparented tmpfs of dead scopes: /tmp/japps.*, /run/user/1000/jwf-m-*). Relaunched `main-full2.sh` at 0032ea0f0 with SWARM_MEM_MAX=18G (integration-build.sh now honours the env, default 24G); tests green 09:14:39, host from 09:14:39 (main-full.pid = launcher subshell 212608) |
| 0032ea0f0 result | — | host stage rc=1 09:17 (163 s at 18G): everything compiled except Kernel.PayEnrolReceiver, refused by name as over the cap (table weight 19.3 GB). Coordinator cleared ~5 GB of stale tmpfs (/tmp/japps.*, /run/user/1000/jwf-m-*), the un-ns-owner w1/w2 worlds and 13 leaked fake-body.py servers. Relaunched `main-full2.sh` at f1b7add21 with SWARM_MEM_MAX=22G 09:19 (main-full.pid 228063, build.pid 228077); the host stage compiles only the Pay modules |
| leak fix | de3b67abe | dev_flow's Procs kills each server's process group and removes scratch; JWF removes its jwf-m-* member dir on every exit (JWF_KEEP_MEMBER=1 keeps it) |
| full | f1b7add21 | 09:14 relaunch of main-full2.sh at 22G (main-full.pid 228063; build.pid 228077); tests green 09:19; host stage from 09:19:13 (must compile Kernel.PayEnrolReceiver) |
| f1b7add21 host | — | host stage CLEAN 09:32:38 (805 s at 22G; Kernel.PayEnrolReceiver compiled); consent from 09:32:38 |
| main since f1b7add21 | b7e16c951 | app-market-b8 3b9280829 (Mercurial in FEATURED, 13→14; `apps_search_shows_the_featured_set_first` passes on the Mac) |
| main since f1b7add21 | c3dcaf00f | app-market-b3 63ff068c2 (EtherDraw, Scrumblr, SwaggerEditor in FEATURED, 17; filtered apps_search 2/2 on the Mac) |
| f1b7add21 result | — | consent rc=1 09:37 (270 s), census only (PersistedCodecTagCensus.lean:322): structure moved under DREGG/APPLICATION/DISPATCH-OBSERVATION/v6 (ApplicationDispatchAdmission.observationContext) and DREGG/GRAIN-RESOURCE-BIRTH/JOINT/v5 (GrainResourceBirthTransaction.plan), from Lean already in iter-speed's frozen 694415d5d. No candidate; default: no regen inside the conversion freeze, the conversion landing re-pins both with the epoch move. Asked the coordinator (a) wait vs (b) regen now |
| main since f1b7add21 | 1d5902832 | rows-ledger c6cc9b4a3 and 45fc4d30a (ROWS-OWED §0 app tables); umbrellas stage 842d8fb75 |
| umbrellas stage | 842d8fb75 | coordinator 10-28: no stage elaborated Fixtures/ObjectiveProofs/CensusChecks, so NativeDocWriteFixture sat red unseen. `lane-build.sh umbrellas` (after host, seated, `--umbrella --umbrella-only`, targets from `umbrella-targets --unshipped`) reds the candidate; integration-build.sh runs host, consent, umbrellas, rust (backup .bak-umbrellas). One-off run on integ8 at f1b7add21: `integ4/umbrellas-now.sh` (pid file integ4/umbrellas-now.pid; builder copy src/scripts/bnh-umbrella-oneoff.sh, untracked; log integ8/logs/umbrellas.log) started 09:5x |
| f1b7add21 decision | — | no regen inside the conversion freeze: the conversion landing re-pins DISPATCH-OBSERVATION/v6 and GRAIN-RESOURCE-BIRTH/JOINT/v5 with the epoch move; the next build is the conversion candidate. Recorded fixtures (NativeDocWriteFixture, NativeAcceptedFixture) are regenerated once, from the first READY candidate carrying the conversion AND lean-audit-c + M2 (L1e: M2 moves the turn digest and the v3 frames, so a conversion-only fixture goes stale again); until then the umbrellas stage is expected red on Fixtures only |
| conversion | b26630168 | 10:1x main fast-forwarded to lane/iter-speed b26630168 (module conversion, landing 186dd02e8, pins 73ab0797... byte-identical hbox/dregg-ref; StoreEpoch moves: FRESH GENESIS). Umbrellas one-off at f1b7add21 stopped by its PID tree (integ8/stop-umbrellas.list). `main-full2.sh b26630168` at SWARM_MEM_MAX=22G started 10:13 (main-full.pid 293722, build.pid 293739; gate-cut6 + enrol-resume after READY). Main since: thin-birth fb0acbfbe (6fd993d43, merged onto the converted main), app-market-b5 84938f78c + 0aff6334e (3a943f85e), hermes-b 20a7abafc (6b5528b20; install-hermes preflight as root). The build after this candidate carries them; name it to L4b |
| main since b26630168 | 550073827 | thin-birth fb0acbfbe, app-market-b5 84938f78c + b5-featured 0aff6334e, hermes-b 20a7abafc + cb638b87d (per-account consent anchors) + 1c0cc645d, un-deputy 05890da80, un-pb-helpers 9be4a7da3 (private-backend checks with --features demo on the Mac). Conversion build b26630168 in its host stage from 10:17 |
| main since b26630168 | 643b4c6ba | hermes-b 627f91c96 (0cfb09864: umask 077 around pin-enrollment-plan-height; filtered participant_enrollment 14/14 on the Mac), un-deputy c7ac7819c (state). Name the build carrying them to L4b |
| main since b26630168 | b71898658 | un-consent-reconnect 0b88b837f (c64a50a28; rehearsal blocker 1 of 3) and b71898658 (POLLRDHUP gated to Linux: 0b88b837f broke the mini on macOS; consent_proxy 10/10 on the Mac). Name the first candidate carrying it to infra a298031c78e86d651 (checks 200 -> idle -> 200) |
| main since b26630168 | d0256656e | app-market-b7 d6243efa8 (2048, Perplexity Sudoku, 3D Blockstack, Simple Chat in FEATURED, 25; harness 119f29700/53cb4abda/376472418; filtered apps_search 1/1 on the Mac), un-deputy 347a223dd (state). lane/un-consent-reconnect 02a03960f NOT merged: superseded by b71898658 (deputy 10-28) |
| main since b26630168 | d871cb4dd | un-pb-helpers ee908664b (private-backend P6 lost-reply recovery; `cargo check --all-targets --features demo` clean on the Mac). Deputy note: never run custody torn_anchor_tail/lost_reply_and_relabel in one process with king_store's kill-9 test (flock WouldBlock flake) |
| main since b26630168 | 994dcf17b | effects-revival ae0c78a01 (ac4247487; Effects/Revival/HostTeethProofs.lean imported by Effects.lean, HostTeeth by `decide +kernel`; `lake build Effects` green on hbox per the owner; first elaborated here by the umbrellas stage of the build after b26630168), un-deputy ada83a1b4 (state) |
| b26630168 progress | — | 10:30 host stage cold (788 modules, seats 4, 22G) from 10:17; on READY: gate-cut6 + enrol-resume; name `/build/candidates/b26630168b63024c9c46311745fa0b25fa09c13f` with its verdict to the coordinator and infra a298031c78e86d651 |
| main since b26630168 | 5f9bc1b7b | effects-revival 60ddb1150 (f46beaa46 PrepareFactors; 43296e483); lean-audit-c 18ade1e4a + 755970f57 (L1e's landing: conversion + lane + M2; 0af55d21c): the next build runs the codec regen once, the StoreEpoch moves, fresh genesis, and the fixtures are re-recorded from that candidate; 049c34570 restores the two reply-marker scans in scripts/host-operations.py that the conversion landing 186dd02e8 reverted from a stale copy (test-host-operations OK); un-story-install 523163eee (the Assurance.StoryLaw:486 pin; 5f9bc1b7b). b26630168 closure PASS 2907 s, host native build running at 11:08 |
| rehearsal plan | — | coordinator 10-28: b26630168 is NOT the rehearsal cut; run its gate fully (conversion proof, fresh-genesis baseline; the validator and market run on it). The rehearsal candidate is the NEXT build, launched the moment all three blockers are on main: consent reconnect (landed), public-reader 403 (deputy's faerie), Hermes birthStale (L4c), plus the held Lean branches merged and converted by their owners (lean-audit-c/-m2 L1e, thin-birth, effects-revival a26c13b24522dee35, OwnTracks). Keep the coordinator and infra posted |
| b26630168 host | — | host stage CLEAN 11:11 (3243 s, cold under modules); consent from 11:11, then umbrellas (non-fatal for this candidate), rust, pack, gate-cut6 + enrol-resume |
| main since b26630168 | 222cb1c2d | app-market-b5 efdb8563d (recipe fixes; spk-host resident_privilege: HackerCMS /var/www, one safe sibling hop under O_NOFOLLOW) and app-market-b7 9a905de6e (HledgerWeb, TextEditor recipes); scripts pass bash -n / py_compile. Held, owners report first: cx-oracle, cx-store-sweep, un-route-latency (codex workers), oracle-grant-factory b81a38663 (codex's own; coordinator asks ember) |
| A12c | — | 11:29: A12b stopped by its PID file (it waited for the whole chain incl. the gate). `integ4/regen-A12c.sh` (pid file regen-A12c.pid 424092; launcher subshell in regen-A12c.parent.pid) starts when the b26630168 BUILD (integ8/build.pid) and its enrol-resume end (the gate reads only integ8/src's object store via harness-overlay; NO_NIGHTLY), moves outputs aside, then at main's tip (>= 9bed7b1e0): host (seats 3, SWARM_MEM_MAX=18G beside the gate), codec-shapes-regen.py, consent. Patch: integ8/regen-A12.patch → commit to main; re-record Fixtures.NativeAcceptedFixture and NativeDocWriteFixture from that build (tell a26c13b24522dee35 and L1e); then the full build (fresh genesis). Report the incremental rebuild time of the follow-up build to the coordinator |
| main since b26630168 | 9bed7b1e0 | lean-audit-c 0f1a7ac4b (L1e green 53d66406f: Host.Json's birth-authoring copy deleted, birthCurrent_eq_birthAt) as e9bca48bd; the ownerless census check (9bed7b1e0; main's only fingerprint-7 pin is the exempt version constant "6"); codex's oracle-grant-factory b81a38663 + 7d6d659be pushed to main directly (no Lean) |
Gate harness rule (coordinator, 10-28): the tour and composed harness (scripts/, native/resource-client/*.sh|*.py, journey.d/) come from main at gate time over the candidate's source.tar and binaries (`integ4/harness-overlay.sh DEST SHA`; `HARNESS=<sha>` in tour-run2.sh and composed-full2.sh; gate-cut4.sh resolves main's tip, adds `harnessCommit` to the gate file after gate-from-runs.py, which binds only the candidate's SHA256SUMS). Infra was asked to copy harnessCommit in gate-from-runs.py itself (optional).
Runner rule (coordinator, 10-28): launch builds with `integ4/main-full2.sh`, which gates with `gate-cut5.sh`: it copies tour-run2.sh, composed-full2.sh and harness-overlay.sh into `$G/runner` at gate start, runs only from that copy and writes `runnerSha256sums` beside `harnessCommit` in the gate file. Never edit a script a running job reads; change it under a new name.
Merge-subject slip: 8e7940fea and 1a3240483 name the un-deputy sha in their subjects; their parents are un-story-install 733dd948f and red-authority-zero-field 108083a35. 733dd948f was a red-first test (shared_names.rs:1144), cleared by a8376ce8f (d2b639068).

A3's tree (main 8103b29a4) holds everything since aa9366f8: pd-host-rate, oracle-lifetime-grant, oracle-grant-factory,
lean-audit-c, un-effects 2acd8acf (effect Plan; its codec pins re-emit with this regen), un-pb-twins 134535c2,
demo-seed, app-recipes (the rows validator runs them on the candidate; Wekan/WordPress/IPython need
MINI_IMPORT_PROFILE=market-large-v1), snipe-rate-row (its report at docs/evidence/snipe-rate-row-2026-10-27.md) and
un-web-front 0da04999 (front-page document; infra's step 9c depends on it). Also since: app-market db312c6f (30e24095f; b2.sh resolved per function against app-recipes, L13 agreed). Correction to that commit message: ExpenseOwl's positive-amount POST is reasoned from upstream, not row-proven (B2's run left GET /expenses empty); unproven until the rows validator runs it.
After A3's tip (Rust only, in the full build): hermes 68394077 (6f4251c21; contained tools, room fields 1014/1015,
J14_TOOLS row) and fb15f121b (redteam test initializer for un-web-front's Shell.front_doc; the mini bin's tests did
not compile). The first candidate carrying both bc88a5ab (frame v8)
and hermes ea8a991e (e2374f120, the await bridge; any full build from main >= d3a0c41f3): send its sha and path to L4b (ad81db6d6fd317d3a) and
the coordinator at once; L4b runs J14_TOOLS and J14_AWAIT as one run against it (3315a908 refuses the v8 genesis). Unit
mini-grain-controller@9870001 is free (it was L4's orphan). Also after A3's tip: e7958d3b9 (NativeHost.birthRejection/birthReason arms for
f2010f574's platformUnavailable/platformStale; A3 is expected to red at Kernel.NativeHost and its dependents,
elaboration of the fix pending NativeHostReplay.olean). L1d (formerly L1c; lean-audit-c a281e53b8, e59846239; deletes those two
constructors with pricedAt, drops e7958d3b9's arms on merge; unbuilt, not to merge until its warm-tree build
elaborates) seeds its dregg-ref tree from the integ8 copy; tell it when the copy lands.

Next steps: the full build at 2d8b7ed54 (it carries 25cfb86bd, custody-b's
delegated consent, f79044d79 and c11b235ee (grain-runtime NO_RECORD refusals; a0d58aaef), hermes-b 5422506f, custody-b 97aab6054 (55e8a05d9; the profiled grain bootstrap twin deleted), un-tale-welcome bc6c837ba (docs), the world/ pack 1b870fbdd, red-jli-refname 81349cec2 (JLI reruns on it), un-tale-welcome 19bb968e0 (f5602a8cd; the door joins members to door.json's story), and since A11 started: un-shared-names 179494a88, app-market-b3 6f2bfd3bc, app-market-b7 d8ee43cdb (spk-rpc empty ViewInfo), un-deputy, audit-platform (main 2a15c1839), the six red-* snipers (main 7265c5fc6), app-market-b5 e1458689a, app-market-b8 bec955336, un-deputy bc0267a8e (main 3e045b32d), app-market-w11 d5b8b7ac6 (main 1b2764235), un-deputy 7a0aca783 and red-jdisclose-scalar cd79cdaa3 (main 0b1f42daa)). un-shared-names landed at e4acc9df0 (main 18f44f8db; 9eeda6092 never merged). The birth-acceptance twin is collapsed (78fe8e63d). The regen tool's literal-survivor check after A10 is on main (9e3d67e43). On READY the chain runs gate + enrol-resume;
report "candidate <sha> at <path>: gate <verdict>, reds by name" to the coordinator (who starts a fresh rows
validator from docs/ROWS-OWED.md section 0a with it: the old one, aeee8349c191e8506, stopped at its ceiling; never send
it a candidate), and the sha + path to infra (ae95a4eac63b0715e; reruns the seed in the demo-dry container on the first candidate carrying 25cfb86bd, f73893fce, 52c0eae22 and 19bb968e0), L4b (ad81db6d6fd317d3a) and the deputy
(a308118209b4a48ea, owns the app market; wants the first candidate carrying 25cfb86bd). Pending lands:
lean-audit-c is green at 82c17c448 (L1e, tip de1375846 doc-only) but lands after the module conversion: order agreed
between L1e and iter-speed (a0fd127abfb9aac75): (1) this candidate reported; (2) iter-speed re-derives the conversion on
main's tip with land.py and sends its sha (one planned StoreEpoch move; the next candidate needs a fresh genesis);
(3) L1e merges the conversion into lean-audit-c and lean-audit-c-m2 (M2 adds World.Turn.credit and the v3 frames) and
sends a green sha; all of it rides one codec regen. The `ownerless` census check is on main (9bed7b1e0), merged onto
iter-speed's PersistedCodecTagCensus.lean. lane/thin-birth 1e0f741d3 LANDED on main eda65ced8 (after the 7027e0ace report, before the conversion; so land.py converts its Lean (Kernel/NativeThinBirth, NativeThinConsent, Host/ThinBirthConsent, ClientConsentCore, SourceAgreementJson, HostOperations) and it rides the one regen; told a0fd127abfb9aac75 and L1e. On the first built main carrying it, run `journey.sh --only JP2` (row 19 thin birth succeeds; the swapped-plan row refused birthSourceChanged). After it lands, delete dregg-ref:/build/lanes/thin-birth-scratch/ and /build/lanes/thin-birth (finished session lane), listed in COMMANDS.log first.

Infra is a298031c78e86d651 (10-28; older mentions of ae95a4eac63b0715e/aed5ecf506cf840af in the table are history). Red routing: lean-audit-c and lean-audit-c-m2 are L1e's (a58f907aef8926430; L1d ad6d6eff243f32816 has stopped): its green sha comes from and its reds go to L1e directly; when the module conversion lands on main, tell L1e (it merges the conversion into lean-audit-c and sends a green sha) and L1d's old address; Hermes to L4c (a6c2f758a0dac46fe; L4b ad81db6d6fd317d3a has stopped); L13 a1618140607ac439b; un-stream-continuity reds
(ApplicationStreamContinuityFresh pole proofs, NativeHostReplay.lean:3816) to the deputy a308118209b4a48ea; all
others through the coordinator. Expected reds, not new: the eight hand-rolled genesis writers (acceptance.sh,
application-acceptance.sh, authority-acceptance.sh, selected-release-acceptance.sh, grain-runtime/acceptance.sh,
jpay2.sh, jpay6.sh, scripts/fn-e1e2/setup-mini.sh) until L2 converts them; rows refusing an older world as
noncanonical/epoch after the re-genesis.

Rules now in force: the Mac runs cargo check and filtered Rust tests only, never Lean (the regen script runs lake
itself: box only). Lanes may build and run again (ember, baef327e4), but only in warm, incremental trees on
dregg-ref or hbox, never a fresh tree and never a search from / or ~. The integrator still merges, builds and
gates main and fixes reds itself.

## Rulings (do not re-ask)

- thin-birth: landed after the conversion at fb0acbfbe (main 6fd993d43); its lane-check on dregg-ref was still running at landing, reds come back to ad0906325ab57d1c3. lane/thin-birth Phase-3 work lands only on a sha its owner sends after the auditor accepts.
- effects-revival LANDED 10-28 at 65b813888 (main 4d059a29b) and ae0c78a01 (main ac4247487, HostTeeth proved; converted, `lake build Effects` green on hbox);
  Its reds from the next build go to a26c13b24522dee35.
- Fixtures (coordinator 10-28): the integrator re-records BOTH Fixtures.NativeAcceptedFixture and
  NativeDocWriteFixture from the A12c build, then sends that sha to effects (a26c13b24522dee35) and L1e
  (a58f907aef8926430). After that, the umbrellas stage blocks again (reds the candidate) from the next build on.
- Held until their owners report (codex workers, shas via the coordinator): cx-oracle, cx-store-sweep,
  un-route-latency. oracle-grant-factory b81a38663 came in by codex's own push to main (9bed7b1e0 row).
- Held for the build after the conversion candidate (one .lean file): lane/app-market-b5 84938f78c
  (Kernel/ApplicationSpkPackageIdentity.lean, safeApiTail admits a final segment with no trailing slash; OwnTracks
  re-qualifies on the candidate carrying it; deputy a308118209b4a48ea). Land after the conversion, re-converted if
  its header conflicts.
- Rehearsal (ember, 10-28): the conversion candidate ships from its gate (tour + composed on EDGE_REV 7d2c765);
  build at 22G; candidate line and verdict to the coordinator and infra a298031c78e86d651 (infra handed off from ae95a4eac63b0715e, 10-28). un-ingest-stale-stage
  1f9a757de is in (256a98cbd).
- Not held, nothing coming: lane/un-ns-owner 587c5acbd is the superseded work-in-progress branch; its clean
  form lane/un-ns-owner-clean (3a8109059, box-elaborated, plus e80f56422 and cf3c5d433) is on main (coordinator 10-28).
- Module-conversion window: CLOSED 10-28 10:1x (b26630168 on main); .lean lands again. Held lanes told: L1e, thin-birth, effects (a26c13b24522dee35).
- Row requirements: a row asserting behaviour newer than the oldest candidate a harness may judge gets a line in scripts/gates/row-requires.tsv in the same commit (5 JWF rows → 588855a71, 9b36d6d37).
- Pay weights stay at 19.3 GB in the seat table (coordinator 10-28: never lower a weight to a kill-time peak); a
  host stage that must compile a Pay module runs at SWARM_MEM_MAX=22G on a slice cleared of leftovers.
- Memory on dregg-build (coordinator 10-28): every build runs with SWARM_MEM_MAX=24G (exported in
  /build/lanes/integration-build.sh; swarm-build's default and swarm.slice MemoryMax are 24G too, infra 08:58), so
  the OS and sshd keep ~6 GB. Kernel.PayEnrolReceiver and PayObservationReceiver (15.5-19.4 GB) take all four seats;
  iter-speed (a0fd127abfb9aac75) splits them after the codec seam.
- Disk (ember, 10-28): plenty free; the 60 GB pause line is dropped. The only rule is the hard stop: if /build on
  dregg-build falls under 50 GB free, pause new builds and tell the coordinator. Never delete others' files.
- Tidy-up (ember approved 10-28): delete exactly the "can go" rows of the disk table, each logged with its size in
  integ8/COMMANDS.log first, after checking no live process uses it: integ4's src, test-target, rust-target and two
  artifacts.prev (keep its scripts, logs, PID files; citer-b's PID file intact); /build/lanes/integration;
  integ-ref-target, integ-ref-fence, integ-ref-hermes, integ4r, integ-9f14, integ-drivers; /build/ci-e89 (ci-e89b
  stays until citer-b is gone); /build/er-*; candidates 0ce31391, 7027e0ace, 3315a908, 23861533, 203ed84c, a94bed71,
  a972c742, 6236826f, 45f45d15 and its -reference-dregg-ref copy. Keep integ8, candidates 2d8b7ed54, 76758dba6,
  e89fe7b8b, aae3e2e37, and red-jdisclose-scalar.
- Context: write the continuation (this file, rewritten whole) by about 580k tokens; distill or hand off at about 600k (COORDINATION 3a6aafdca).
- Intent.credit (L1d item 5, ops 244-247) persists in IntentRecord: durable log frame v3 and
  `DREGG.DURABLE.IMAGE` v3, shipped with the module conversion's re-genesis so the StoreEpoch moves once. Pending
  the auditor's acceptance; L1d (ad6d6eff243f32816) coordinates the order with the integrator and the iter-speed
  successor (a0fd127abfb9aac75).
- closure.pid on dregg-ref (empty for jobs started before lanes joined group `closure`) is infra's
  (a298031c78e86d651), not the integrator's.
- Transitive bumps through registry constants: closed, no. Nesting already propagates through the regen's round
  loop; both stops were spelling forms, now handled.
- Owner-less pins: the census refuses a registered DREGG identity no definition spells or names, on main 9bed7b1e0;
  first elaborated by A12c.
- The module conversion's census change (option A, structure-not-name for compiler auxiliaries) is the one planned
  re-pin; it lands from a0fd127abfb9aac75 after the next candidate is reported.

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

- Umbrellas stage (coordinator 10-28): non-fatal for the conversion candidate (b26630168) ONLY. A red writes
  integ8/UMBRELLAS-RED and is named in the candidate report (integration-build.sh; backup .bak-umbrella-nonfatal).
  It becomes BLOCKING again (restore exit 10 for umbrellas) in the first build after NativeDocWriteFixture and
  NativeAcceptedFixture are regenerated from the conversion(+M2) candidate by the effects lane (a26c13b24522dee35)
  and L1e (a58f907aef8926430).
- Mac shared target: four codex astra workers build on /Users/ember/dev/minidregg-lanes/target-integ (and hbox);
  if their cargo runs contend with the integrator's Mac checks, tell the coordinator.
