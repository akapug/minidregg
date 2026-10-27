# lane/custody-drivers: state for the successor (2026-10-27)

Branch `lane/custody-drivers` (main merged at the tip). Mac worktree
`/Users/ember/dev/minidregg-lanes/custody-drivers`; box worktree `dregg-build:/build/lanes/custody-drivers`
(detached: `git fetch` in `/build/minidregg`, then `git checkout --detach origin/lane/custody-drivers`).

## Done (shas)

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

## Owed on cut 9 (28235a17)

- The world template's before/after (waiting for the coordinator's cut 9 path). The run that matters is
  `JOURNEY_WORLD_TEMPLATES=1` (the default). `=0` runs once, as the control for the published number,
  via `/build/lanes/custody-drivers-logs/run-measure.sh` (re-add the frozen tree
  `/build/lanes/custody-drivers-measure` at the tip first; point it at the cut 9 set). Last numbers
  (a94bed71 binaries, without this lane's mini fixes): 1119 s off, 1089 s on, both cut short.
- Optionally rerun `enrol-resume-acceptance.sh` there (`run-enrol-12.sh` pattern, `C=` the cut 9 set).

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
