# Sandbox floor audit on dregg-build (Debian 13), 2026-10-27

Operator `lanes` (uid 1000, subuid grant 100000:65536), kernel 6.12.107+deb13-cloud-amd64,
bubblewrap 0.12.0-1~deb13u1, systemd 257.13, test ELF and probe built from lane/fence at
68092f8a plus the forked-child audit (see the lane commit). Run by
`scripts/spk-platform/sandbox-floor-audit.sh` through `systemd-run --user` with the
resident unit's hardening, as the integrator's `integration-build.sh` runs it.

Two reds, in order:

1. Cleared. `namespace setns(CLONE_NEWUSER) refused: Invalid argument` came from the
   libtest harness thread: the kernel refuses setns into a user namespace from a thread
   group of more than one (kernel/user_namespace.c `userns_install`). The transcripts
   here show the bootstrap past it: both `namespace-map helper=...` lines are printed and
   bwrap starts under the unit's hardening.
2. Open, named. `bwrap: execvp /spk-sandbox-probe: Permission denied`: `/run` is a
   `noexec` tmpfs on this host (`tmpfs /run tmpfs rw,nosuid,nodev,noexec,...`), so the
   audit image placed there cannot be executed, inside the sandbox or outside it (the
   same `install`ed `/bin/true` under `/run/spk-sandbox-floor-audit-*` is `Permission
   denied` for `lanes` on the host). The script now refuses this by name before building
   anything and takes `SPK_AUDIT_ROOT`; the host's sudoers rule for `lanes` must be
   re-anchored on the chosen root before the audit can run to a verdict here.

`results.txt` exit=101 on both tests is red 2; `environment.txt` records the host.
