# lane/custody-b (successor of custody-drivers, L2): state (2026-10-28)

Branch `lane/custody-b`, Mac worktree `/Users/ember/dev/minidregg-lanes/custody-b`. Rows run on dregg-ref
(`lanes@2.31.71.194`, key `~/.ssh/id_portable`) from `/build/lanes/custody-b/src`: cut 14's source.tar
(0ce31391) with this lane's changed scripts copied over, and the binaries in
`/build/lanes/rows-0ce31391/cand/0ce31391…/bin`. Runners: `/build/lanes/custody-b/job1.sh N` (all six rows)
and `trace.sh RUN NAME…` (sh -x). PID files sit beside each runner and every one names an exited process.
Linux cargo runs on dregg-build in worktree `/build/lanes/custody-b`, with target
`/build/lanes/custody-drivers-target2`.

## Now

Genesis writers on cut 14 (dregg-ref):
- **green**: `acceptance.sh`, `selected-release-acceptance.sh`, `application-acceptance.sh`, and grain-runtime
  `PROVIDER_BOOTSTRAP=1 BOOTSTRAP_ONLY=1`.
- **authority-acceptance.sh**: asserts the prepare-refusal contract (exit 3, pre-submit-refusal.json, a
  NO_RECORD frame decoded as law-denied), so it needs lane/prepare-refusal-clients f73893fce (now on main).
  It is green on the first candidate that carries that commit.
- **grain-runtime plain**: in progress. Fixed so far: the controller unit's user fixture selection, the
  worker launcher materialized with the candidate's launch gate, the runtime's automatic post-breaker
  settlement, and the worker Hermes MCP-timeout profile. Run `x5` is checking the last of these.
- **fn-e1e2 setup-mini**: out of scope (fn).
- **jserve**: PASS on cut 14 with beb108d5f (validator, hbox).

Causes found (each fixed at the cause; no assertion weakened):
- content targets carried schemaVersion "1"; `journey.d/lib/wire.sh` reads `ContentResource.commandVersion`
  from the Lean.
- Store images used the legacy `read-to`; `journey.d/lib/evidence.sh` holds the one `durable_image` (head
  plus log, read under `profile`'s storeAnchorIdentity; the checkpoint cache is excluded). It also holds a
  portable `sha256`. The four `durable_image` copies are deleted.
- grain's clock-subject capabilities 71-74 collided with the birth's 71/72/73 (`authorityBatch`).
- plan-time refusals (law 10, c5e268ebd NO_RECORD) replaced submitted ones in authority, application
  (`no-grant`) and jserve. Marker bytes come from protocol/host-operations.json (`response_marker`).

Split-tenancy signing (coordinator's top priority; working in infra's demo-dry on 0ce31391):
- Cause: full consent replays the Store; split-tenancy members (mini-s-NAME) cannot read mini-core's Store.
  R2's members ran as `mini`. No Mini commit introduced it.
- Fix: delegated full consent, one socket-activated `mini serve-controller-consent` per member running as
  mini-core. Mini side: 51e9ca5a9 (idle exit), 7c76b6ad8 (USAGE), 52c0eae22 (mini-web-spawn gives web
  bodies the selection). Frame side: dregg-infra demo-vm 742446c (this lane's member-consent e344a5e,
  merged by infra with fixes forward 66ed7fb and 1c4a79d); rows S2b-S2e are in jsplit-tenancy.sh.

Owed:
- A rerun of the six writers on the first candidate after 1af366fe9.
- grain plain to green.
- The web body fix confirmed in demo-dry (infra reruns the seed).

## Earlier work by custody-drivers (shas)


One wire (BACKLOG O39, O40; SYNTHESIS §E.7; RUST-TRIAGE row 20):
- Literal Host bytes name `host_operations::*` in every wire crate (`969b5709`, `4346ef15`, `31c4065f`,
  `64b15a34`, `316cfef2`, `cce04212`). `scripts/host-operations.py check` refuses, by symbol: op-typed
  call arguments, `*_OP` constants, `x.first()` against `Some(N | ..)`, `[253..255, ..]` slice arms,
  and literal arms of a `match` on an operation-named variable; each form red-proofed. Exemption
  marker `not-a-host-op`. Header allowlist generated from Lean (`fa8cb4b7`, `31c4065f`).
- O39: every sender v2 (`446505cc`); v1 refused by name, the pin mandatory (`cbae4c4a`, `44f9b9a0`).
- Validators and readers: spk-host `canonical.rs` + `private_file.rs` (`6aa5dde3`); resource-client
  `pair` -> `mini_sdk::local::pair`/`pair_nonempty` (`d2041a21`); resource-client's 36 decimal/hex
  copies -> mini_sdk's rule, plus `decimal::parse`, `is_canonical_ascii_max`, `hex::decode_fixed`
  (`94b6ac5f`; pay.rs had accepted `+5`).
- Linux reds fixed at the cause (`44f9b9a0`, `6aa5dde3`, `6c30899b`). Verified on dregg-build:
  spk-host 276/276 (`6aa5dde3`); resource-client 241/241 and mini-sdk 33/33 (`d2041a21`, `cce04212`);
  at `94b6ac5f` resource-client 401/403 (two cohort_tcp wall-clock slot tests, a different pair red on
  a serial rerun: the traffic-privacy stack's, untouched here), mini-sdk 34/34.

Enrol:
- `enrol-resume-acceptance.sh` PASSES on cut 7 (3315a908, carries L1's `92341df2`) with this lane's
  `mini`, step 7 included (pinned plan admitted across two ticks): `182e5494`, again at `f7e4c032`.
  Ticks wait for a later wall-clock second (`a6ade458`; the Host refuses `clockNotAdvancing`); step 7
  checks two confirmed commits (`182e5494`). The run uses the fixture's server and stops it by its
  PID file (`f7e4c032`; a second serve had orphaned the fixture's ten times, stopped by the
  coordinator, recorded in `/build/lanes/orphan-mini-serve.pid`).

Untouched-areas items:
- `compatible-upgrade-custody` dropped from resource-client (`ec81fd91`): its only user,
  `mini session-reenroll`, was deleted in 0c261e76.
- Rooms: `K10C` and `JPRIV1` are the room-lifecycle rows. The demo's wall budget had starved both
  on every candidate. The scout's "1/8 Room modules reached" is the Host.Main import closure:
  `RoomRelease*` has no Host receiver, so wiring one is a Lean lane's job. On cut 7 with this
  lane's mini: **K10C PASS (`73a2a542`), JPRIV1 229/229 PASS (`5da65342`)**.
- K10C rows 92-93 (`73a2a542`): RENOUNCE's by-number form now requires its kind. A bare number
  matched the reference form first, so carl's grant number was read as a ref name. The row now
  reaches the Host's `notHolder`.
- `wrapAtomId` twin (`5da65342`): JPRIV1's two inline Python formulas are replaced by
  `room-key --op wrap-atom`, which prints `roomkey::wrap_atom_id`. A test checks that the verb's
  output is byte-identical to the function's.

World template (ember: snapshots, not replays):
- `f45a6379`: the fixture's template is ON by default. When NEWPARTICIPANT_TEMPLATE_DIR is unset,
  templates go to `$TMPDIR/minidregg-world-templates-UID` (about 200 KB per variant). Setting it
  empty (the runner's JOURNEY_WORLD_TEMPLATES=0) builds fresh: that is the control run.
- Every row in journey-rows has a `# world:` header saying template or genesis. Genesis is the
  subject in four: hostupgrade, welcomecontinuity, births, perf. Four more are
  `genesis, OWED a template`, each with its reason: sshe2e, m6grain, m7, jpay.
- Owed elsewhere (Host, a Lean lane): a restored Store still replays its suffix on open. The Host
  checkpoints only when `height % checkpointEvery == 0` (Compiler/DurableReceiverCore.lean
  `checkpointDue`, default 64), so a template captured off that boundary replays up to 63 records.
  Two fixes are possible: a Host verb that seals a checkpoint at the head, which the fixture would
  call before taring, or checkpointing at a clean shutdown.

Abuse limits (infra's review):
- `3a050e77`: `deploy/shell/mini-shell-ssh` allows at most two calls per member at once (flock
  slots in HOME/.call-slots; the third exits 75, "two calls already running for this member"). The
  slot is the wrapper's descriptor, which `mini` and its residents never inherit. Tests in
  `test_shell_credential_launcher.py` (Linux: 7/7 on dregg-build).
- `b085895e`: export world, one per member per 10 minutes. The one file is HOME/exports/.last-export,
  claimed through `world_export::claim_export(home, now)`, which the web lane's /export calls too.
  A failed export costs nothing.
- OWED to a Lean lane: a per-subject request rate in the Host. The Store queue is shared, so the
  wrapper's slot pair only bounds what one member's ssh account can queue; the Host is where every
  face (ssh, web, socket) meets.

## Not yet run (custody-drivers wrote them; the central build or this lane runs them)

- `87768a8bb` platform install 240-243 on the operator socket: test
  `transport::tests::platform_install_is_the_operators_alone_and_meter_refill_stays_closed`, plus
  `python3 scripts/host-operations.py check` (the registry records routes ["operator"]).
- `b085895e` the export cooldown: `world_export::tests::one_export_per_cooldown_named_by_time_and_a_failed_one_costs_nothing`.
- `c59ab026` `python3 scripts/test-host-operations.py` (31 tests, about 72 s).
- `0153d8ae8` + `95214d02c` genesis frame v8: the writers' state is under "Now". Not yet run by anyone:
  the profiled grain bootstrap, journey JPAY2 and JPAY6, and the four jpay6 extractors (grain-runtime
  bootstrap-native-controller and journeys/byok-native including --ssh, inference-scheduler native-journey
  and native-two-member).
- `5e0d2cb7b` pending inbox joins on the first init: test
  `shell::tests::pending_inbox_joins_run_only_chat_join_and_a_refused_one_stays_for_the_member`.

The world template's before/after, on the newest candidate set `C=/build/candidates/<sha>`.
Templates ON is the run that matters (it is the default); OFF runs once, as the control for the
published number. Both use one frozen tree, so both runs judge the same scripts:

```sh
# on dregg-build as lanes, once per measurement
cd /build/minidregg && git fetch -q origin
T=/build/lanes/template-measure; TIP=<candidate sha>
git worktree add --detach "$T" origin/main     # or the tree the candidate was cut from
. /build/lanes/integration/pipeline/box.env; export XDG_RUNTIME_DIR=/run/user/$(id -u)
for mode in 1 0; do
  s=$(date +%s); uptime > /build/lanes/template-measure-$mode.load
  JOURNEY_WORLD_TEMPLATES=$mode bash "$T/scripts/pipeline/journey-runner" --tip "$TIP" --source-tree "$T" \
    --results-root /build/lanes/template-journeys-$mode > /build/lanes/template-measure-$mode.log 2>&1
  R=/build/lanes/template-journeys-$mode/$TIP
  echo "templates=$mode rc=$? wall=$(( $(date +%s) - s ))s WALL_S=$(cat $R/WALL_S) rows=$(wc -l < $R/results.tsv) fail=$(grep -c $'\tFAIL\t' $R/results.tsv) load=$(cat /build/lanes/template-measure-$mode.load)"
done
```

The published number is WALL_S(templates=0) - WALL_S(templates=1), with both loads beside it.
`journey-runner` exports NEWPARTICIPANT_TEMPLATE_DIR under the run (=1), or empty (=0, every world
fresh). Last figures, on a94bed71 binaries without this lane's mini fixes: 1119 s off, 1089 s on,
both cut short by J1's seal red (fixed since). Optional on the same candidate:
`native/resource-client/enrol-resume-acceptance.sh HOST MINI STORE VERIFIER NEW_DIR` with the set's
binaries (last PASS on cut 7, step 7 included).

## Verify commands
- `python3 scripts/host-operations.py check` (3 s).
- Mac: `cargo build -p minidregg-resource-client -p minidregg-mini-sdk --all-targets`; spk-host builds
  only on Linux. Mac-only reds: socket paths under the macOS temp dir (SUN_LEN).
- Linux filters: `/build/lanes/custody-drivers-logs/run-wire-6.sh` (resource-client, mini-sdk),
  `run-wire-3.sh` (spk-host). Filtered only.

## Box state (dregg-build, user lanes)
- Worktrees: `/build/lanes/custody-drivers`, `/build/lanes/custody-drivers-measure` (at `5b4b6ad6`).
- Target dirs: `/build/lanes/custody-drivers-target2`, `/build/lanes/custody-drivers/target`.
- Logs, runner scripts, PID files: `/build/lanes/custody-drivers-logs/`; every PID file there names an
  exited process (checked after the rooms run). Scratch roots under `/build/t/cd*`, `/build/t/tp*`.
- Not mine, left alone: `mini` PIDs 709807, 722346, 868724 (no PID files).
