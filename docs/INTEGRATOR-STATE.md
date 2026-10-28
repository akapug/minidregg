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
| next | 76758dba6 | un-ns-owner 507d6ce78 (launch report controlGroup bound 4096 in three Kernel/ApplicationLifecycle*Report.lean; no pin move, no re-genesis). Armed: `integ4/next-after-7027.sh` (pid file integ4/next-after-7027.pid) waits for the 7027e0ace build and enrol-resume, moves integ8 outputs aside, launches `main-full.sh` at 76758dba6 (main-full.pid). Name its candidate to the coordinator, the deputy (market batches, japps, the validator's app worlds wait for it), L4b and infra ae95a4eac63b0715e; then the conversion window opens (tell a0fd127abfb9aac75) |

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
sends a green sha; all of it rides one codec regen. The uncommitted `ownerless` census check merges 3-way onto
iter-speed's PersistedCodecTagCensus.lean, never overwriting it. lane/thin-birth 1e0f741d3 is released (auditor ACCEPT, proved): it merges onto main right after the 7027e0ace candidate is reported and before iter-speed re-derives the conversion, so land.py converts its Lean (Kernel/NativeThinBirth, NativeThinConsent, Host/ThinBirthConsent, ClientConsentCore, SourceAgreementJson, HostOperations) and it rides the one regen; told a0fd127abfb9aac75 and L1e. On the first built main carrying it, run `journey.sh --only JP2` (row 19 thin birth succeeds; the swapped-plan row refused birthSourceChanged). After it lands, delete dregg-ref:/build/lanes/thin-birth-scratch/ and /build/lanes/thin-birth (finished session lane), listed in COMMANDS.log first.

Red routing: lean-audit-c and lean-audit-c-m2 are L1e's (a58f907aef8926430; L1d ad6d6eff243f32816 has stopped): its green sha comes from and its reds go to L1e directly; when the module conversion lands on main, tell L1e (it merges the conversion into lean-audit-c and sends a green sha) and L1d's old address; Hermes to L4b (ad81db6d6fd317d3a); L13 a1618140607ac439b; un-stream-continuity reds
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

- Intent.credit (L1d item 5, ops 244-247) persists in IntentRecord: durable log frame v3 and
  `DREGG.DURABLE.IMAGE` v3, shipped with the module conversion's re-genesis so the StoreEpoch moves once. Pending
  the auditor's acceptance; L1d (ad6d6eff243f32816) coordinates the order with the integrator and the iter-speed
  successor (a0fd127abfb9aac75).
- closure.pid on dregg-ref (empty for jobs started before lanes joined group `closure`) is infra's
  (ae95a4eac63b0715e), not the integrator's.
- Transitive bumps through registry constants: closed, no. Nesting already propagates through the regen's round
  loop; both stops were spelling forms, now handled.
- Owner-less pins: the census refuses a registered DREGG identity no definition spells or names, landed once
  A9/A10's pins show none left (the Mac worktree's uncommitted `ownerless` check; through a box build only).
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

- Uncommitted in the Mac worktree: Compiler/PersistedCodecTagCensus.lean `ownerless` (the census refuses a registered DREGG identity no definition spells or names). Unelaborated; land it only through a box build after the candidate.

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
