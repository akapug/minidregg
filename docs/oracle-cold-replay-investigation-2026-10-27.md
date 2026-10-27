# Cold replay: investigation checkpoint

The completed copied-Store qualification measured cold STOP inspection at
425.061 seconds, first resident inspection at 421.513 seconds, and a warm repeat
at 0.414 seconds. The saved cold and resident JSON matched exactly. The separate
continuation receipt, including wrong-claim and routing controls, has SHA-256
`8b8551dececa57f1797939be7d94d7b67169e55fc8d004a71632fb87781c12ff`.
These measurements concern the frozen qualification build, not current main.

This investigation is isolated on `codex/oracle-cold-replay`, based on
`77b604e0e921b14e0986bc21e845dfbe32e097cc`. No executable source changed and no
additional replay, build or profiling experiment ran before the convergence
checkpoint. The qualified binaries, retained Stores and active appliance run
were untouched. No cold-replay improvement is claimed.

## What the source establishes

`Kernel/NativeHostReplay.lean` is unchanged between frozen `339abf3e` and this
base. Its cold walk derives each historical ingress at its original prefix,
compares the complete intended record, advances through the durable executor,
and validates the resulting image. It already uses `validateLoadedFrom` with
an equality theorem to avoid redoing unchanged directory validation. A new
cache cannot be justified merely by the total elapsed time.

Current main already contains the native cSHAKE/KMAC kernel changes from
`26f894dd`, absent in the qualification source. The changed modules include
`Theory/Sp800185Cshake256Native.lean` and
`Compiler/Sp800185Kmac256.lean`. Their effect on this particular cold walk has
not been measured. Do not attribute an eventual current-main improvement to
new replay work without separating this existing change.

`Kernel/AuditTiming.lean` and `Kernel/NativeHost.lean` already provide opt-in
phase attribution for `audit`. `MINI_AUDIT_TIMING=1` reports load, genesis,
admission by event family, record comparison, advance, and post-validation.
The timed pure wrappers carry the same value equality; timing does not change
admission. `inspect-stop-claim` does not enable these audit counters itself.
The existing 2026-09-27 syscall profile in the repository is a different
workload, dominated by waits for child processes, and cannot identify the
dominant computation in this CPU-bound Oracle walk.

## Next bounded experiment

First inspect any already retained per-phase logs from the frozen run. If none
exist, use the existing timed audit against an isolated copy on `dregg-build`,
under its resource wrapper, with a recorded PID and exact Host/config/Store
hashes. `HOST CONFIG audit --receipts FILE` emits the original-ingress receipts;
with `MINI_AUDIT_TIMING=1` the existing stderr counters identify the dominant
phase without source instrumentation. Keep this audit's scope distinct from
STOP inspection. Preserve Store and anchor hashes before and after.

Choose one concrete implementation only after those counters identify a
cost, and compare exact receipt bytes and relevant refusal behavior. Reuse
current native hash kernels rather than rebuilding that work. Any later
same-history performance comparison must use the same hardware and record
the source and binary identities. No serialized proof cache, omitted authority
check, synthetic latency claim, or repeated full suite is part of this plan.
