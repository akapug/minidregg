# Cold replay: budget materialization

The frozen Oracle qualification measured cold STOP inspection at 425.061 seconds,
first resident inspection at 421.513 seconds, and a warm repeat at 0.414 seconds.
The saved cold and resident JSON matched exactly. The continuation receipt,
including wrong-claim and routing controls, has SHA-256
`8b8551dececa57f1797939be7d94d7b67169e55fc8d004a71632fb87781c12ff`.
Those numbers describe the frozen qualification build, not current main.

## What the new measurement establishes

An independent copy of that stopped Store was audited on `dregg-build` with
already compiled candidate `23861533bfab425ccfcaf63777a563d11a64a400`.
Its Host SHA-256 is
`a12b4aea5ca628c4be7af8048be4e3f8b4e9da410ad4de33bd36c7b4fc3588c7`.
Old and candidate Host returned identical profile JSON with the same rewritten
physical paths. No active appliance Store, service, binary, or receiving plan
was changed.

The audit accepted all 58 records in 279.215 seconds wall time, 276.166 seconds
user CPU, and 1.019 seconds system CPU. Peak process RSS was 631,804 KiB.
Existing audit counters attributed 196.121 seconds to advance, 6.255 seconds
to record comparison, and 0.646 seconds to post-validation. Admission by event
family accounted for most of the rest. The command was bounded to 600 seconds
and a 6 GiB `swarm-build` scope.

This is not an attributable speedup over 425 seconds: binary, hardware, and
command differ. The candidate already includes native hash kernels absent
from the frozen build. Its audit is the baseline for the isolated change below.

A one-second stack sampler collected 215 samples, starting partway through
the audit. `Charge.fundedCheck` appeared in 138 samples, the `Engine.install`
closure in 125, and prior source-charge evaluation in 101. These are inclusive
stack appearances, not disjoint CPU percentages. Only five samples contained
the update chain suspected from a different workload. This Oracle fixture
therefore supports fixing the budget closure before changing World storage.

Evidence is under `/build/lanes/oracle-cold-replay/audit-new/`: `report.json`,
`stderr`, `receipts.bin`, and `cpu-samples.txt`. Store, anchor, configuration,
Host, and helper hashes matched before and after. The receipt stream SHA-256 is
`d9cc6d4b3b5f5dfbc0a9225deb91ecda2da6c93852974e948d2b37836a982965`.
The copied database SHA-256 is
`8780ec2c405566c767a2da7c6ac4d3c02fcdf59e70ddb0396090ce6d537f5ac6`;
its sibling anchor is
`6b044de9fa9adc47e8820ce4a67609aa19996672e12c4d8d352b3502e8ee0e27`.

## The bounded change

`Engine.install` previously retained a new function subtracting the accepted
intent's charge from the previous engine's available budget. Later funding
checks evaluated that chain again, including expensive earlier source-charge
functions. The change materializes all ten remaining allowances once at
installation using existing `Charge.materialize`. Its `materialize_eq` theorem
proves that converting the values back to a charge function returns exactly
the original function.

The new `Engine.available_install` theorem states equality with the old
subtraction for every engine, intent, and lane. Existing `view_install` still
identifies the entire installed snapshot with the protocol snapshot, including
its budget. Natural-number subtraction and zero budgets are unchanged. This
introduces no cache of authority or proof results.

`scripts/oracle-cold-replay-budget.lean` checks funding, exact exhaustion,
zero-charge acceptance, and insufficient-budget refusal independently in all
ten lanes. Both the modified Engine module and all executable controls passed
with the pinned Lean 4.30.0 compiler against the candidate's imports. The new
proof depends only on standard `propext`, `Classical.choice`, and `Quot.sound`.
The generated C calls `Charge.materialize` inside `Engine.install` and captures
its returned Values in the subsequent `Values.toCharge` closure (lines
1074–1076 of the retained `proof/Kernel/DurableEngine.c`). This verifies that
the intended eager boundary survives compilation. The candidate Host audit
is pending; no speedup from this change is claimed yet.

The source is isolated on `codex/oracle-cold-replay`. World compaction is
already being developed on the hot-path lanes and is outside this change.
After the focused proof check, the supported native build must recompile the
import-order suffix beginning at `Kernel.DurableEngine`; a manual replacement
of generated C would miss downstream specialization. The next comparison is
one audit against the same private fixture and exact configuration, requiring
identical receipt bytes and unchanged input hashes.
