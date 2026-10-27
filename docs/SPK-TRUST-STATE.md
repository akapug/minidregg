# spk-host trust lane (L3, lane/fence): present state

Written 2026-10-27 by the L3 veteran for its successor. Branch `lane/fence`
(worktree `/Users/ember/dev/minidregg-lanes/fence`, merged from `origin/main`
1a20368b). Every Linux check ran on dregg-build (178.105.4.114) as `lanes`,
worktree `/build/lanes/fence`, under `swarm-build`; the demo box was never touched.
spk-host does not compile on macOS (`resident_launch.rs` imports the
`cfg(target_os = "linux")` modules unconditionally): the box is the only gate.

## Landed on lane/fence (all unsigned, 1Password refused)

| sha | what |
|---|---|
| `408296cb` | setns(CLONE_NEWUSER) EINVAL: the audit forks a single-threaded child; `enter` names the thread rule |
| `5aaf1a32` | floor-audit root must be exec-capable and nowhere group/world writable (`/var/lib/spk-floor-audit`); ENOSYS detector reads bwrap lines only |
| `fe1d90f0` (on main as 1a20368b) | resident reads marker 253 as decided no-record, 255 undecided, generated constants |
| `6e0a3c64` | O29: `resident_service::run` starts every resident through `start_attested`; tampered-mount refusals tested by name |
| `3ea8f80c` | O64/O65: `Config.storeIdentity` = cSHAKE(seed bytes; label ‖ Store root) feeds the nine resident-profile sites; `storeTag` now separates worlds by root |
| `020bebe2` | R7: bwrap runs from the hashed descriptor (`verified_image`), duplicated above fd 9; `pinned_bwrap`'s hash loop deleted |

## Mid-flight, by file:line

- **O64/O65 Lean gate.** `Kernel/NativeHostStoreIdentity.lean` (new; `Config.storeIdentity`,
  `storeIdentityCustomization_separates_roots`, `storeTag_separates_two_roots_of_one_seed` by
  `native_decide`). Consumers: `Host/Main.lean` (claim inspection, profile `storeTag`, retry/claim/BEGIN
  assembly: six sites), `Host/Json.lean` `residentStore`, `Host/ApplicationLifecycleClaimOperator.lean:96`,
  `Host/ApplicationLifecycleLaunchCompletionAuthoring.lean:96`. Box gate: `lake build
  Kernel.NativeHostStoreIdentity` then `lake env lean` of those four files against a real copy of the
  integration `.lake` at 45f45d15 (`/build/lanes/fence/.lake`, 11 GB). Verdict at `3ea8f80c`: module
  build green (22 s); `lake env lean` green for Main (60 s), ClaimOperator, LaunchCompletionAuthoring;
  `lake build Host.Json` green (175 s; `lake env lean Host/Json.lean` cannot run Json's own pre-existing
  cSHAKE `native_decide`s without the kernels dynlib, so use `lake build` for it). The Host binary link
  is the integrator's full build; the grain two-world journey has not run on the new tag yet. **Migration:** every existing world's tag changes; `Host::load` refuses the
  old grain world by name ("grain host profile state root is not this Mini Store's"); re-init the grain
  world (demo re-genesis is planned). L2's world template needs only its `storageRoot` rewrite.
- **O30.** Code items already landed: `binding-v3` decode at
  `native/grain-runtime/src/application_api_tools.rs:441-443` (d4d18d0a), `operationId` read at `:190-198`,
  `agents[]` filled by `agent_route::configs` at `native/spk-host/src/grain.rs:1122/1165` (78fb4bcc). Open:
  the one fd-3 journey row (a Hermes resident reading EtherCalc through fd 3) — no such row exists
  (`scripts/pipeline/journey-rows` is empty; `/build/lanes/integration-journeys.sh` lists none) and it needs
  a live Hermes + EtherCalc world: batched for the parent.
- **R7.** `native/pinned_execution.rs` was not adopted, on evidence: 128 MiB memfd cap vs the 178 MB Host
  binary (`/build/lanes/integration/artifacts/minidregg-host`); API shape fits neither helper nor holder.
  It stays private-backend's.

## Next three steps per item

- O29: (1) integrator's full `lake`/cargo build with `start_attested` live; (2) a floor-audit-style
  start on the box with a deliberately replaced `/var` to see the refusal end to end; (3) retire the
  `VerifiedBegin` comment that still says "caller must also compare" if the claim check covers it.
- O65/O64: (1) make the Lean gate green and have the integrator build the Host; (2) `grain init-store`
  on the box for two Stores at two roots and show two tags/two worlds (`two-world-journey.sh`); (3) write
  the tag migration note into `deploy/shell/OPERATOR.md`.
- O30: (1) parent provides a Hermes+EtherCalc world; (2) write the fd-3 row; (3) run it on the box.
- R7: (1) integrator build; (2) a tenancy-style test that starts `enter` with fds 3/4 free (the bug's
  shape) — the existing `tenancy_bootstrap_actual_*` test does this today; (3) nothing else.

## Verify

```
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_portable lanes@178.105.4.114
cd /build/lanes/fence   # detached at the integration tip + lane/fence's delta (git apply)
CARGO_TARGET_DIR=/build/lanes/fence-target swarm-build cargo nextest run -p minidregg-spk-host \
  -E 'test(volume_custody) | test(resident_launch) | test(namespace_identity) | test(tenancy) | test(dispatch_fence)'
swarm-build lake build Kernel.NativeHostStoreIdentity && swarm-build lake env lean Host/Main.lean
bash scripts/spk-platform/sandbox-floor-audit.sh TEST_ELF /build/lanes/fence-target/debug/spk-sandbox-probe /usr/bin/bwrap OUT
```
Last green: Rust filters (dispatch 16/16, O29 12/12, R7 namespace+tenancy 9/9 at the integration tip),
floor audit 32 held / 21 breached with the R7 code. Logs and evidence: `/build/lanes/fence-logs/`
(`nextest-*.log`, `lean-*.log`, `r7-floor-evidence/`, `floor-evidence/`, `final-evidence/`). PID files
there: `run.pid`, `run253.pid`, `run-o29.pid`, `run-lean*.pid` (all finished). Box worktrees: `/build/lanes/fence`
(mine), `/build/lanes/fence-target`, `/build/lanes/fence/.lake` (a real copy, safe to rebuild in).
