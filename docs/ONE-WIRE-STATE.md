# lane/custody-drivers: state for the successor (2026-10-27)

Branch `lane/custody-drivers`, tip `cbae4c4a` (main merged at `3295dce4`). Mac worktree
`/Users/ember/dev/minidregg-lanes/custody-drivers`; box worktree `dregg-build:/build/lanes/custody-drivers`
(detached, checked out from `origin/lane/custody-drivers`; `git fetch` in `/build/minidregg` first).

## What landed (sha: what)

One wire (C5; BACKLOG §3 rows O39, O40; SYNTHESIS §E.7):
- `969b5709` mini-sdk: 52 literal op bytes name `host_operations::*`.
- `fa8cb4b7` registry gains `consent_frames` (220,221,222,224,226,227,228,229,230,231,232,233) and
  `ordinary_headers` (Lean `ordinaryHeaderName`, 18 names); generated into `native/host-operations.rs`
  (`CONSENT_*`, `CONSENT_FRAMES`, `ORDINARY_HEADER_NAMES`, `ordinary_header_name()`) and
  `Host/HostOperations.lean` (`consent*Frame`, `consentFrames`, `ordinaryHeaderNames`).
- `4346ef15` resource-client: 258 literal op/frame sites named. `31c4065f` spk-host: 136 sites named;
  the four header-allowlist copies (http_entrance.rs, dispatch_web_input.rs, agent_api_wire.rs,
  agent_api_lifetime_wire_v3.rs) call the generated `ordinary_header_name`. `64b15a34` mini-sdk consent
  frames named.
- `9cc655c5` `scripts/host-operations.py check`: Rust literal scan (5 wire crates; op-typed parameter
  positions and `*_OP|*_OPERATION|*_OPCODE` consts; `not-a-host-op` marks an exemption), unregistered
  consent-frame refusal, Lean `ClientConsentCore` frames == registry, Lean header list == registry;
  masker made positional (173 s -> 3 s). Red-proofs done (planted const 86; planted frame 225).
  Also journey-rows `row_exchange`: anchored `unit_verify_warns` + self-check.
- `446505cc` O39 step 1: every v1 sender moved to v2 (enrollment-view `--host|--host-sha256`; SDK
  `operator::request`/`Operator::new` pin mandatory; 12 journey scripts; j12x v1-refused row).
- `cbae4c4a` O39 step 2: `transport.rs split_envelope` refuses v1 by name ("socket envelope v1 is
  retired: send v2 with the Host image pin"); `transport::invoke` deleted; tests v2.

Earlier this session: `attempt-state` verb + 74 journey reads (`8c389e1e`..`8607f960`); enrol fixes
(`0e88483c`/`ed595f2c` seal reads pinned plan, `c3d59a0c`, `9add461a`, `e42b4f7e`), step 7 PASS
assertion `843e0a90`; genesis completion-custodian fill `5669559b`; journey `--only`/`--keep-going`,
`box-wait` `6396cace`; `JOURNEY_WORLD_TEMPLATES=0` `5b4b6ad6`.

## Verified, and where
- Mac: `python3 scripts/host-operations.py check` green (185 active, 12 consent frames, 18 headers).
- Mac: `cargo build -p minidregg-resource-client -p minidregg-mini-sdk --all-targets --all-features` green.
- dregg-build at `9cc655c5` (before O39): check green; build of spk-host+resource-client+mini-sdk green;
  spk-host filtered 134/135 (red `agent_api_server::tests::distinct_controller_uid_gets_exact_traverse_and_socket_acl`:
  "controller cannot traverse agent socket ancestor", a uid/ACL environment fact); resource-client
  filtered 160/162 (reds `join_solana_v2::tests::synthetic_http_and_local_host_purchase_retains_two_valid_possessions`
  and `a_box_held_key_with_a_detached_ssh_signature_retains_a_valid_memo`: "payment received; admission
  pending" assertion; join_solana_v2.rs's only change was STATUS_OP/QUOTE_OP naming 181/182); mini-sdk 32/32.

## Mid-flight (not yet verified)
- O39 (`446505cc`, `cbae4c4a`) has NOT run on Linux. Mac reds are SUN_LEN-only (macOS temp paths).
- No journey row has run against these changes; every converted row needs a candidate built from this tip.

## Next three steps, one wire
1. Linux check of O39: on dregg-build, `cd /build/lanes/custody-drivers && git checkout --detach origin/lane/custody-drivers`,
   then under swarm-build with `CARGO_TARGET_DIR=/build/lanes/custody-drivers-target2 TMPDIR=/build/t`:
   `cargo nextest run -p minidregg-resource-client -E 'test(/transport|envelope|client_consent|key_adoption|async_dispatch|pinned/)' --no-fail-fast`
   and `cargo nextest run -p minidregg-mini-sdk --features native -E 'test(/operator|ssh|request/) & !test(lean_codec) & !test(ssh_e2e)'`.
   (Template: `/build/lanes/custody-drivers-logs/run-wire.sh`; wait with `scripts/pipeline/box-wait --pid ...`.)
2. "One set of validators and readers" (O40's last clause, SYNTHESIS §E.7): not done. Candidates named by the
   reviews: `cleanTransportText` twins (v1 allows TAB, v3 refuses it; Lean refuses only NUL/LF/CR,
   spk-host.md §B), the v4 Rust StreamCodec re-encoders (`lifecycle_v4_retry_native.rs:80-119` and siblings),
   reply-frame readers matching `[112, body @ ..]`-style literal patterns (the scan does not see patterns:
   e.g. `native/resource-client/src/main.rs` enrollment_view `[112, ..]`, `[8, ..]`). Emit them from the
   registry or call one shared reader; extend the scan to `match`/slice-pattern literals.
3. Deletions last: the agent API v1 twin (`agent_api_wire.rs`) once the agent cut lands (another lane's);
   `scripts/` and docs that still describe v1 (`git grep -n "v1 envelope\|envelope v1"` outside this file).

## Next three steps, enrol / world template
1. When a candidate carries L1's `92341df2` (pin keeps the authored deadline): run
   `native/resource-client/enrol-resume-acceptance.sh HOST MINI STORE VERIFIER NEW_DIR` with this tip's `mini`
   beside the candidate's host/store/verifier and `CANDIDATE=<set>`; step 7 must print
   "pinned plan admitted across two ticks". Template: `/build/lanes/custody-drivers-logs/run-enrol-10.sh`.
2. Standing-run wall before/after on a candidate built from this tip:
   `JOURNEY_WORLD_TEMPLATES=0` then `=1` via `/build/lanes/custody-drivers-logs/run-measure.sh`
   (frozen tree `/build/lanes/custody-drivers-measure` is at `5b4b6ad6`; re-add it at the new tip).
   Last measurement (a94bed71 binaries, which lack this lane's mini fixes): 1119 s off / 1089 s on, both
   cut short by J1's seal red.
3. Run the converted rows (journey, demo, kernel, jpay; attempt-state readers) on that candidate.

## Verify commands
- `python3 scripts/host-operations.py check` (3 s; must print the JSON summary).
- `cargo build -p minidregg-resource-client -p minidregg-mini-sdk --all-targets --all-features` (Mac);
  spk-host builds only on Linux.
- Filtered tests as above; never an unfiltered `-p`.

## Box state I hold (dregg-build, user lanes)
- Worktrees: `/build/lanes/custody-drivers` (lane), `/build/lanes/custody-drivers-measure` (frozen at `5b4b6ad6`).
- Target dirs: `/build/lanes/custody-drivers-target2` (~1.3 GB), `/build/lanes/custody-drivers/target`.
- Logs and scripts: `/build/lanes/custody-drivers-logs/` (run-*.sh, *.pid). No job is running; every
  PID file there names an exited process.
- Results: `/build/lanes/custody-drivers-journeys-0`, `-1` (measurement); scratch under `/build/t/c*.*`, `tp*.*`.
- Not mine, left alone: `mini` PIDs 709807, 722346, 868724 (no PID files).
- `/build` was at 90% (20 GB free) at the last look.
