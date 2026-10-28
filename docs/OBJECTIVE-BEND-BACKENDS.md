# Objective Bend backends — map, evidence class, refinement status to `stepRaw`

One semantics: `Theory/ObjectiveBendDemandMachine.lean` `stepRaw` / `step` /
`runBounded` (Core4 with sums). The Core4 soundness theorems (`runBounded_*_sound`,
`checked_reachable_no_refusal`) are about `runBounded`. Every backend below is
classified by **what it executes** and **how it is related to that function**.

Evidence classes: authored / compiled / executed / integrated / deployed.
Every number below is copied from the artifact it cites; a number with no artifact
is not stated.

| Backend | What runs | Evidence class | Refinement to `stepRaw` |
|---|---|---|---|
| **Preview interpreter** (`Host/ObjectiveBendPreview.lean`) | `runBounded` itself, under `lean --run` (Lean IR interpreter) | executed (`Host/ObjectiveBendFrontEnd` capture then preview, run over `tests/objective-bend-source/preview-cohort.json` by `tests/objective-bend-source/check-preview.ts` from `scripts/check-objective-frontend.sh` and `scripts/check-objective-examples.sh`) | **identity**: it IS the function the theorems are about. Trust added: the Lean IR interpreter. |
| **Lean-native** (`runBounded` built with `leanc`) | `runBounded` compiled by Lean's own compiler to C | executed once, 2026-10-04 (final State bytes identical to the interpreter's on StressWork and StressCount); its build script and log were removed 2026-10-26 (no callers; the log is in git at `21876dfb259b:native/objective-emit/evidence/bench-01.log`) | **identity modulo the Lean compiler** (the trust `#assert_compiled` already takes). |
| **C machine** (`Compiler/ObjectiveBendEmitC.lean` + `native/objective-emit/runtime.c`) | a hand-defunctionalized `stepRaw` over a per-program code ROM; unbounded naturals; exact `Limits`/tick accounting; canonical State codec; Lean→C resume | executed (differential harness), not integrated: no Mini path invokes it | **differential only, no theorem.** Per packet and case: outcome, tick count, per-tick fingerprint, resume count and State bytes equal `runBounded`'s turn chain (the 2026-10-04 run, before runtime commits `0afaf7f2` and `606e4e17`; its logs left the tree on 2026-10-26 and are in git at `21876dfb259b:native/objective-emit/evidence/`: 340/340 cases PASS over 43 packets — the 37 preview-cohort items incl. `SumsTotal` and the 10 activity items (EventCounter x4, DocumentWatcher, TimerResident, DeosCounter x4), the 5 stress items in `native/objective-emit/extra-cohort.json`, and one hand-built core fixture `fixtures/SharedEffect` (a perform forced under an update frame: `refused sharedEffect`; the front end refuses every source that reaches it) — each with full run, tick cuts at T/3 and 2T/3, heap at half, stack 3, Lean→C resume at T/2, Lean→C resume of a capacity suspension, and for activities: the first yield with no response, and per resumed yield a C start from the Lean yielded State and from the preview's Plan-extracted checkpoint. A turn chain resumes each yield with the item's next response (the preview's wire, decoded once by `Compiler/ObjectiveBendDataWire`) under one tick budget. That run's compile-time controls (`-DOB_MUTATE_*`) went with their ifdefs on 2026-10-26; the current controls are the two planted miscompiles of `cdiff-mutants.py` the local gate `objective-cgen` runs every time, and the current differential is the gates `objective-c` and `objective-cgen`). The ROM's derived code is read off `stepRaw` (`fixBody_exact`, `mixTarget_exact`, pinned). Theorem path: a Lean model of the defunctionalized machine + simulation `R s r → R (stepRaw s) (stepRef r)`, then either generating the C switch from the model or compiling the model with Lean. |
| **Compiled Lean, fast** (`Theory/ObjectiveBendDemandMachineFast.lean`) | every compiled call of `stepRaw`/`step`/`runBounded`/`forceWith` (admission re-execution, preview, EmitC driver) runs `stepRawFast`/`stepFast`/`runBoundedFast`/`forceWithFast` | executed (lane FASTMACHINE: `native/objective-emit/fastmachine/differential.py`, specification code vs csimp code, every packet, byte-identical checkpoint tokens) | **equality by theorem**: `stepRaw_eq_fast`, `step_eq_fast`, `runBounded_eq_fast` (ObjectiveBendDemandMachineFast) and `forceWith_eq_fast` (ObjectiveBendDemandData), all `@[csimp]`, axioms `[propext, Quot.sound]`. Trust added: the csimp mechanism (the compiler substitutes the proven-equal constant). |
| **Re-execution at admission** | the Lean machine (re-execution is the admission check; proofs are an empty carrier slot) | integrated on scratch worlds: a native Host admits signed Objective invocations (`native/resource-client/objective-native-acceptance.py`, journey row `objective` in `scripts/pipeline/journey-rows`); not deployed | identity (it is the Lean function, compiled through the `@[csimp]` fast replacements). |
| **Oblivious fixed-access network** (`Compiler/ObjectiveThunkNetwork.lean`, `Compiler/ObjectiveDemandLiteralNetwork.lean`, `Compiler/ObjectiveDemandLayout.lean`, `Compiler/ObjectiveDemandRegions.lean`; on main since the cut) | a Boolean DAG that scans every heap/stack row per tick at a public `Shape` | compiled (the layout and its regions; `Assurance/ObjectiveZk*` in the opt-in `ResearchWip` library); a codec instance for five programs of the literal tranche | **open.** `PackedRefinement` as stated is inhabited by administrative stutter (`packedRefinement_always_inhabited`, `Assurance/ObjectiveZkRefinementAudit.lean`); the corrected `PackedCodec` is instantiated only per run and only for those programs. [ZK.md](ZK.md) Part 2 gives the links by name. |
| **zk trace** (`BendTraceIR2`, IR2 descriptors) | proof of a network run | research; Selvage/IR2 not an admitted proof system | inherits the network's open refinement; public tariff, never measured ticks (`Assurance/ObjectiveZkStepTariff.lean`, compiled, opt-in `ResearchWip`). |
| **Interaction nets / HVM** | — | none | none; outside the sound fragment (open recursion), eager CUDA runtime. |

## One tariff, two physical costs

Every backend reports (or is shaped by) the same public resource vector:
`Limits` (heap cells, stack frames) and ticks (one tick = one `stepRaw`). The
C machine's tick/heap/stack numbers are checked equal to `runBounded`'s in
every differential case, so a tariff over that vector prices native execution
without conversion. Physical cost (C wall time, network gates) is never the
charge; a public fixed-capacity envelope is (zk-truth lane `tariffView`).
The C machine's timing and access pattern depend on data: it is a clear
backend only.

## Measurements

These figures are history: one run each on 2026-10-04, before later runtime commits
(`0afaf7f2`, `606e4e17`) changed `runtime.c`. Its log was removed with the rest of
`native/objective-emit/evidence/` on 2026-10-26 and stays in git at
`21876dfb259b:native/objective-emit/evidence/bench-01.log`. The current C differential is the
local gates `objective-c` and `objective-cgen`.

| Packet (ticks, final heap) | Lean IR interpreter: `runBounded`+encode, in process | Lean-native (Lean compiler) | hand C, process wall |
|---|---|---|---|
| `StressWork` work(14) (524,293 ticks, 49,163 cells) | 20,063 ms (process 21.42 s, maxrss 1.52 GB) | 21,243 ms (maxrss 73 MB) | 22.65 ms (maxrss ≈10 MB) |
| `StressCount` count(20000) (360,037 ticks, 40,014 cells, stack depth ≈20,000) | 39,263 ms | 37,515 ms | 13.44 ms |

On both packets all three produce byte-identical final States: sha256 prefix `ec53e4a356254e80` (StressWork) and `78bdd6f416b95afb` (StressCount).

**Lean-native is no faster than the interpreter.** So the Lean machine's cost is algorithmic, not interpretive. Lane FASTMACHINE measured why (`native/objective-emit/fastmachine/DIAGNOSIS.md`):

- `step` retains the pre-state, so the heap is shared inside `stepRaw`; on StressWork that copies 2.8·10⁹ cells.
- `step` walks the stack with `List.length` every tick; on StressCount that is 3.6·10⁹ nodes.
- Three `stepRaw` push sites, and `allocateFields`, read the old heap size after the push, so they copy even a unique heap.
- `forceWith` re-enters `runBounded` once per tick.

The fix leaves every definition alone. It adds the proven-equal implementations of `Theory/ObjectiveBendDemandMachineFast.lean` and installs them with `@[csimp]`.

| Packet | specification code (compiled) | csimp code (compiled) | hand C, process wall |
|---|---|---|---|
| `StressWork` `runBounded` / `forceWith` | 14,885 / 13,100 ms | 41–43 / 45–52 ms | 20 ms |
| `StressCount` `runBounded` / `forceWith` | 37,684 / 38,130 ms | 36–292 / 25–40 ms (box load 18–28) | 10 ms |

Source: `native/objective-emit/fastmachine/DIAGNOSIS.md:76-78`. `step` called alone, one tick per call, stays O(stack depth), because its signature carries no depth; no admission path calls it per tick.

### Regression rows

- No timing row guards the compiled machine; performance is published, never a gate. The table above is the published figure.
- `native/objective-emit/fastmachine/differential.py`: the specification code against the csimp code on every packet, 15–17 cases each. Its control: a mutant `allocateFieldsFast`, with the field address fixed at 0, gives 65 FAIL over 5 packets.

