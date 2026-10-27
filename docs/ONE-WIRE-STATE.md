# lane/custody-drivers: state for the successor (2026-10-27)

Branch `lane/custody-drivers` (main merged at `859ad3ce`). Mac worktree
`/Users/ember/dev/minidregg-lanes/custody-drivers`; box worktree `dregg-build:/build/lanes/custody-drivers`
(detached; `git fetch` in `/build/minidregg`, then `git checkout --detach origin/lane/custody-drivers`).

## One wire (C5: BACKLOG O39, O40; SYNTHESIS §E.7; RUST-TRIAGE row 20): done

- O40 literals: every literal Host operation byte, consent frame and response marker in the wire
  crates names `host_operations::*` (`969b5709`, `4346ef15`, `31c4065f`, `64b15a34`, `316cfef2`,
  `cce04212`). `scripts/host-operations.py check` refuses, by symbol: op-typed call arguments,
  `*_OP` constants, `x.first()` against `Some(N | ..)`, `[253..255, ..]` slice arms, and literal
  arms of a `match` on an operation-named variable (`9cc655c5`, `316cfef2`, `cce04212`); each form
  red-proofed with a planted literal. Exemption marker `not-a-host-op`.
- O40 header list: the registry's `ordinary_headers` (checked equal to Lean's `ordinaryHeaderName`)
  generates the one Rust list spk-host's four former copies call (`fa8cb4b7`, `31c4065f`).
- O40 validators and readers: spk-host `canonical.rs` (decimal at named bounds, lowercase hex,
  hex64, encode/decode) replaces ~20 decimal, 24 encoder, 11 hex64, ~30 inline hex and 9 decoder
  copies; `private_file.rs` replaces 12 private-file readers (`6aa5dde3`). resource-client's nine
  `pair` framings are `mini_sdk::local::pair`/`pair_nonempty` (`d2041a21`).
- O39: every sender is v2 (`446505cc`); the socket refuses v1 by name and the pin is mandatory
  (`cbae4c4a`, `44f9b9a0`).
- Linux reds fixed at the cause (`44f9b9a0`, `6aa5dde3`, `6c30899b`):
  tests building v1 by hand; unit tests trying to start `mini consent-resident` from the test
  binary (resident off under cfg(test)); the join mock's 8 s reaper; the ACL fixture under a 0700
  TMPDIR; codec stand-ins asserting the consent verb `stdio` instead of `codec`; two timing races.
  No constant rename changed a value.

Verified on dregg-build: at `6aa5dde3` spk-host filtered 276/276; at `d2041a21` check green,
build green, resource-client filtered 241/241, mini-sdk 33/33, and again at `cce04212` (241/241, 33/33; script: `/build/lanes/custody-drivers-logs/run-wire-5.sh`).

- resource-client's own decimal and hex copies take mini_sdk's rule (`94b6ac5f`, 36 copies: 20 hex,
  16 decimal; mini_sdk gains `decimal::parse`, `is_canonical_ascii_max`, `hex::decode_fixed`). pay.rs's
  unsigned reader had accepted `+5`. Linux at `94b6ac5f`: check and build green, mini-sdk 34/34,
  resource-client filtered 401/403; the two reds are cohort_tcp's wall-clock slot tests ("missed
  public link slot"), a different pair failing on a serial rerun (20/22), untouched by this change
  (its one edit there is a test-local hex closure): the traffic-privacy stack's, not this lane's.

Not done here, by decision: grain-runtime's ~13 bounded readers (another crate's lane; the
`private_file` shape is the template); the three BPF assemblers (RT 30, `setid_bound.rs` deletion,
the sandbox lane's); `crate::decode_hex` stays any-case (`hex::decode_any_case`): it reads typed
input as well as Host values, and splitting its ~200 call sites is its own pass.

## Enrol / world template

1. `native/resource-client/enrol-resume-acceptance.sh` PASSES on cut 7 (3315a908, which carries L1's
   `92341df2`) with this lane's `mini` at `182e5494`: every step, five members under the 15 s ticker
   in 5 seals, and step 7's pinned plan admitted across two ticks (two confirmed ticks, rising
   count and second, two world roots). Every tick waits for a wall-clock second later than the last
   tick's (the Host refuses a non-advancing tick, `clockNotAdvancing`). Template:
   `/build/lanes/custody-drivers-logs/run-enrol-12.sh`.
2. On cut 9 (28235a17) or later, the standing run with `JOURNEY_WORLD_TEMPLATES=0` then `=1`
   (`/build/lanes/custody-drivers-logs/run-measure.sh`; re-add the frozen tree
   `/build/lanes/custody-drivers-measure` at the tip). Last numbers (a94bed71 binaries, which lack
   this lane's mini fixes): 1119 s off, 1089 s on, both cut short by J1's seal red.
3. row_exchange's anchored systemd-analyze pattern and self-check: in `9cc655c5`.

## Verify commands
- `python3 scripts/host-operations.py check` (3 s).
- Mac: `cargo build -p minidregg-resource-client -p minidregg-mini-sdk --all-targets`; spk-host builds
  only on Linux. Mac-only reds: tests binding sockets under macOS temp paths (SUN_LEN).
- Filtered tests only; the wire filters are in `run-wire-4.sh` (resource-client, mini-sdk) and
  `run-wire-3.sh` (spk-host).

## Box state I hold (dregg-build, user lanes)
- Worktrees: `/build/lanes/custody-drivers`, `/build/lanes/custody-drivers-measure` (at `5b4b6ad6`).
- Target dirs: `/build/lanes/custody-drivers-target2`, `/build/lanes/custody-drivers/target`.
- Logs, scripts, PID files: `/build/lanes/custody-drivers-logs/`. Every PID file names an exited
  process once the last wire run ends.
- Not mine, left alone: `mini` PIDs 709807, 722346, 868724 (no PID files).
