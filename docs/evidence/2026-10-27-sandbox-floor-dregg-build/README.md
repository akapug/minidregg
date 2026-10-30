# Sandbox floor audit on dregg-build (Debian 13), 2026-10-27: PASS

The first operator-path floor verdict on Debian 13: `scripts/spk-platform/sandbox-floor-audit.sh` at
lane/fence `408296cb`, run as the operator `lanes` on `dregg-build` (Hetzner ccx33, Debian 13.7, kernel
6.12.107+deb13-cloud-amd64, bubblewrap 0.12.0-1~deb13u1), under `swarm-build`, from a detached worktree
`/build/lanes/floor-408296cb` with its own `CARGO_TARGET_DIR`:

```
SPK_AUDIT_ROOT=/var/lib/spk-floor-audit swarm-build bash scripts/spk-platform/sandbox-floor-audit.sh \
  /build/lanes/floor-target/debug/deps/minidregg_spk_host-f471fc569abd33d8 \
  /build/lanes/floor-target/debug/spk-sandbox-probe /usr/bin/bwrap /build/lanes/floor-logs/floor-evidence
```

Verdict (`results.txt`): the floor test `operator_probe_holds_inside_production_resident_sandbox` exit 0
(32 checks `held: true`, none false) and the pre-floor test `operator_probe_breaches_under_pre_floor_arguments`
exit 0 (21 checks report the expected breaches). Hashes of the test ELF, the probe and the image's four
files are in `environment.txt`; the two transient units' transcripts and the probe's app output logs are
beside it.

Two facts about the root, for the script and the box:

- `SPK_AUDIT_ROOT` must be exec-capable AND not world-writable. `/run` is tmpfs `noexec` on Debian 13
  (the lane's finding); `/var/tmp`, which the script's hint suggests, is refused by spk-host's
  image-ancestor check: `image or ancestor is task-owned or group/world writable`
  (`resident_launch.rs:618`, both tests exit 101; that run's stamp was `20261027T065431Z`). The box uses
  `/var/lib/spk-floor-audit` (root:root 0755 on the ext4 root), and its sudoers rule for `lanes` is
  anchored there (dregg-infra `edge/tofu-build/sudoers-lanes-floor-audit`).
- The script's line "bwrap hit ENOSYS under the unit's hardening (openat2 filtered?)" printed for BOTH
  tests on this PASSING run. Its detector greps the transcript and app log for "Function not implemented",
  and that string is exactly what the probe's own held checks report when seccomp refuses an unlisted
  syscall (`unlisted-syscall-refused`, `io_setup-refused`, `vmsplice-refused`, `set_mempolicy-refused`:
  errno 38, `held: true`). So the note is the floor holding, misread as bwrap failing: the detector needs
  to look at bwrap's stderr (the unit's own lines), not the probe's JSON. A finding about the script, not
  about the sandbox.
