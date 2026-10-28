# NOCK: Nock programs, refereed by re-execution

This is the present-state description of how a friend's Nock program runs on the kernel. The Lean
modules are the authority; this document says what they do and where they are. Section numbers
are kept from the design of 2026-09-30 so that the `NOCK §N` citations in `Kernel/Run.lean`,
`Kernel/NockDoor.lean`, `Kernel/NockProgramCell/Sample.lean`, `Compiler/NockProgramCodec.lean`,
`Kernel/ResourceTransaction.lean`, `Pred/Core.lean`, `Theory/Nock.lean` and
`native/resource-client` resolve here. Lane names in those comments (K-NOCK-CELL, K-RAN, N11,
N16, NOCK-THEORY, NOCK-RUNNER, K-RUN-PIN) are listed in §6. The evaluator-generic layer that
K-EVAL put around this (the registry, the generic sample record, generic doors) is `docs/EVAL.md`.

Each section is marked **shipped** (in `main`, with the module named), **changed** (shipped, but
not as first designed: the difference is stated) or **design** (not built).

## 0. Summary

A program is a jammed Nock noun in an immutable program cell, together with an ABI that says
which projected slots the program reads and which fields its output may write. A run is the
program slammed on a sample the kernel builds itself. A runner submits field writes with a
`RunClaim` (program id, sample bytes, output bytes, step count). The kernel runs the program
again on its own interpreter (`Theory.Nock`, proved against the Nock 4K rules) and admits the
writes only when the sample, the step count, the output and the writes all agree. A law reads
the accepted run through the atom `ran P`. A NockApp kernel (poke, peek, state at axis 6) runs
the same way, its state stored in a field of an ordinary object.

What is not built: proof-carried runs, bonded attestations, proven jets, the fn distribution of
run claims, and any use of Nockchain's zkVM or token.

## What is trusted

- **The interpreter.** `Theory.Nock` (`Step`, `Crash`, the fueled `exec`/`run`) with
  `run_sound`, `run_complete`, `step_deterministic`, `run_crash_iff`, `run_fuel_monotone`,
  `steps_stable` and `exhausted_says_nothing`. The rules follow `nockvm` at nockchain
  `cbd9298f`. That they match `nockvm` on real programs is the differential harness's claim
  (`Host/NockEval.lean`, `nock-eval`), not a theorem.
- **The runner is untrusted.** Whatever it claims is re-executed. It is not in this tree: the
  journeys take it as `NOCK_RUN`.
- **The compiled kernel.** The Host runs the compiled Lean (`@[export minidregg_nock_run_jammed]`
  `Nock.runJammedBytes`), so the Lean compiler is in the trusted base, as for every kernel check.

## 1. The construct

### 1.2 The run, the atom and the oracle. **Changed.**

A run is `*[subject formula]` where the subject is the program and the kernel's sample, and the
formula is NockApp's slam at the arm the record's params name (`Theory.Nock.slam`,
`Kernel.NockEntry.subjectFormula`). The kernel admits the run's writes by re-executing it
(`Kernel.Run.checkRun`, §2.4).

Changed from the design:

- The law atom is a first-party AST node, `Pred.ran program` (`Pred/Core.lean`), which reads the
  controller-projected slot `run/program/<id> = 1` (`Pred.ranSlot`). The design used
  `witnessed ⟨"nock:" ‖ hex H(P)⟩` and an oracle argument. `witnessed` is still fail-closed:
  `Pred.eval` is `evalWith failClosed`, and the compiler lowers `witnessed` to the false
  indicator (`Compiler/PredCompile.lean`). A law clause written with `witnessed` refuses every
  write.
- Only oracle (a), re-execution, exists. Oracle (b), a proof, and oracle (c), a bonded runner's
  signature, are **design**. There is no value cap and no bond.

## 2. The constructs on the kernel

### 2.1 The program cell. **Changed.**

`Compiler/NockProgramCodec.lean`. The cell is one ROM address (`layout`, `program_immutable`)
holding a `Program` record: the evaluator id, the minimal jam, the `Abi` and the evaluator's
params bytes (Nock's are the arm, `DREGG/NOCK/PARAMS/v1`). The jam must be canonical
(`Noun.canonical`): hoonc's word-padded file is refused `nonCanonical` (`padded_refused`), so a
noun has one byte string (`admissible_jam_unique`). `codeDigest` is cSHAKE256 over the jam;
`programId` is cSHAKE256 over the whole `DREGG/PROGRAM/v1` record; the cell id is
`physicalId domain programId`. Registry kind `nockProgram`, tag 13. Birth checks are
`Compiler.Evaluator.Machine.admit` and `admitRecord`; library presence is checked against the
store at birth. Host ops 131 (check), 132 (show) and 133 (sample) read the cell.

Changed from the design: the design's cell had four namespaces (`code`, `abi`, `source`, `meta`)
and `programId` over the jam alone. The shipped id covers the ABI and the evaluator too, so the
same jam under another ABI is another program. There is no `source` link or `meta` namespace. A
door's state does not live in the program cell (§2.7). The ABI (`DREGG/ABI/v5`) holds the sample
slots, output slots, libraries, fuel, an optional door and the context mode; the arm moved to
the params in E3. `Abi.libraries` (N16) lets a program run over library cells; the forge fixture
is still compiled with the stdlib inside it (about 566 KB).

### 2.3 The sample. **Changed.**

`Kernel/NockProgramCell/Sample.lean`. `sampleOf` builds the sample from the command's projected
slots and the ABI, never from anything the runner chose:

    [[height caller room] ~[['target/0' id0] … ['target/n' idn] [key0 v0] … [keym vm]]]

The target entries are the command's target cell ids in signed order. The slot entries follow
`Abi.sample` in order; each reads one participant slot of one target. A missing slot, or a
negative value in a `nat` slot, refuses rather than defaulting. Under `ContextMode.live` the
context is the admission height, the signer and the room; under `pinned` (K-RUN-PIN) it is
`[0 0 0]`, so one claim stays admissible while the named slots hold their values
(`sampleOf_pinned_of_fields`). A slot may declare a maximum (`SampleSlot.max`); a value above
it is refused `fieldOverMax` before the sample is built.

Changed from the design: the design sorted every observed `[address value]` pair by address
bytes. The shipped sample names its slots in the ABI and carries the target ids, so two
different target sets yield different samples (`sampleOf_targets_injective`). The sample is the
generic `Sample` record encoded by Nock (`docs/EVAL.md` §1.1).

### 2.4 The run check: K-RAN. **Changed.**

`Kernel/Run.lean`, `Kernel/ResourceTransaction.lean`, `Kernel/DeclaredResourceController.lean`.
`Command.run : Option RunClaim` carries the claim, signed with the command (codec
`DREGG/NOCK/RUN/v1`, `runClaimStream`). `RunClaim` is `programId`, `sampleJam`, `outputJam` and
`steps`: bytes, not digests, so the comparison needs no hash assumption. `checkRun`, in order:

1. the claimed sample bytes equal the kernel's sample (else `sampleStale`, naming the moved slot
   under `pinned`);
2. the claimed steps are within `abi.fuel` (else `fuelExceeded`);
3. the code, params and libraries decode (`programMalformed`, `paramsMalformed`,
   `libraryNested`);
4. the oracle, given exactly the claimed steps as fuel, finishes (else `crash k` or
   `exhausted k`) in exactly that many steps (else `stepsMismatch k`);
5. the output bytes equal the claimed bytes (else `outputMismatch`);
6. the output decodes as writes against `abi.outputs` (else `outputMalformed`), and the
   command's writes are exactly those writes (else `writeNotInOutput` or `outputNotWritten`).

The controller then projects `run/program/<id>`, `run/evaluator/<id>`, `run/steps` and
`run/fuel` (`runSlots`) for the law. Op 134 is the runner's dry run (`Kernel.Run.dryRun`).

Changed from the design: the claim carries no fuel field and no evidence variant; the step count
is both the fuel and the fee the signer consents to. The refusal names differ (`crash`,
`exhausted`, `stepsMismatch` for the design's `nockCrash`, `fuelExhausted`,
`outputDigestMismatch`). The design's `ran_iff_run`, `stale_program_refused` and
`reexecute_deterministic` became `checkRun_sound`, `checkRun_deterministic` and
`steps_equal_oracle` (§3.3).

### 2.5 Metering. **Changed.**

The count is `Theory.Nock.steps`: one unit per rule application of `exec`. An accepted run's
steps are the oracle's (`steps_equal_oracle`) and are projected as `run/steps`, so a law can
bound them (`le "run/steps" N`). The charge is `Kernel/RunComputeBudget.lean`: each subject has
`freeStepsPerDay` (1,000,000, `Compiler/WorldExecutionContract.lean`) per clock day; paid steps
above it (`paidSteps`) burn the pay tariff's credit asset in the Book, one credit per step, in
the same durable intent as the run (`prepareBook`, `PreparedBook.funding_credits`). The quote
must be over the checked run's steps (`confirmCheckedSteps`).

Changed from the design: no `nock/*` tariff lines; a daily free allowance instead of a fee on
every run. A refused run (crash, exhaustion, mismatch) is a refused command and is not charged;
the design charged a crashing run for its steps. Proven jets and their charge model are
**design**.

### 2.7 The runner and the NockApp door. **Changed.**

The untrusted runner is outside this tree (§What is trusted). The kernel side is
`Kernel/NockDoor.lean`, Nock's instance of the generic `Kernel/Door.lean` (`docs/EVAL.md` §4).
A program whose ABI names a `door` is a NockApp kernel, run as NockApp runs it at nockchain
`cbd9298f`: the jam is the kernel trap, booted with `[9 2 0 1]`; the state is core axis 6; a
poke slams the params' arm (NockApp: 23) on `[core job]`, with the job
`[event [%poke wire] 0 0 0 cause]`; a peek slams the ABI's peek arm (NockApp: 22) on a path. The
poke must keep the battery and context (`core' = #[6 state' core]`, else `doorShape`). Every
effect must be `[key value]` against an ABI output slot (else `effectNotWrite`). Theorems:
`door_poke_sound`, `door_state_stale_refused`, `door_effects_are_writes`,
`door_effect_not_write_refused`, `door_poke_deterministic`, `door_peek_pure`,
`door_load_deterministic`. Host ops: 135 (poke dry run), 136 (peek), 137 (state now).

Changed from the design: the state lives as the atom of its jam in object field `door.state` of
the command's target 0, with the event number in `door.event`, not in the program cell. Peek is
a kernel read (op 136), not the client's. `load` reads the state now; upgrading a door to a new
kernel (NockApp's `load` at axis 4) is **design**. The Hermes tool `mini_program_run` is
**design**.

### 2.10 Summary table

| construct | status | where |
|---|---|---|
| nouns, jam/cue | shipped | `Theory/Noun.lean`: `cue_jam`, `jam_injective`, `canonical_unique` |
| Nock 4K spec and fueled interpreter | shipped | `Theory/Nock.lean` (§What is trusted) |
| differential harness vs `nockvm` | shipped, runner outside the tree | `Host/NockEval.lean` |
| program cell and ABI | changed (§2.1) | `Compiler/NockProgramCodec.lean`, `Kernel/NockProgramCell.lean` |
| sample | changed (§2.3) | `Kernel/NockProgramCell/Sample.lean` |
| run claim, check, refusals, `ran` | changed (§2.4) | `Kernel/Run.lean`, `Pred/Core.lean` |
| metering | changed (§2.5) | `Kernel/RunComputeBudget.lean` |
| NockApp door | changed (§2.7) | `Kernel/NockDoor.lean`, `Kernel/Door.lean` |
| stdlib as library cells (N16) | mechanism shipped; programs still carry the stdlib | `Abi.libraries`, `Kernel.NockEntry.subjectFormula` |
| step bound read from a declared shape | shipped as a theorem; not consumed by admission | `Theory/NockCost.lean` (`docs/EVAL.md` §3) |
| fn payload, attestation, proven jets, Avon witness, Nockchain zkVM | design | none |

## 3. What is ours

### 3.3 The theorems. **Shipped.**

The deliverable is the statements, proved once over any evaluator in `Kernel/Run.lean` and
restated at Nock in `Kernel.Run.nock`:

- `checkRun_sound`: an accepted claim names the kernel's own sample; the command's writes are
  exactly the writes the product names; the product is a derivation (`Spec`) of the kernel's
  run; the steps are the oracle's and within the ABI fuel.
- `no_accepted_of_output_mismatch`: if the command's writes differ from the writes the
  program's actual product names, no claim is accepted, whatever it asserts. A successful
  evaluation authorizes nothing by itself.
- `checkRun_deterministic` and `steps_equal_oracle`: the charged count is a function of the
  program and the sample, never of the claim.
- `sampleOf_injective` (`Kernel/NockProgramCell/Sample.lean`): the sample determines the
  context the ABI exposes, the target ids and every named slot value.

The decided poles at the end of `Kernel/Run.lean` exercise each refusal on small programs.

## 5. The first program: forge. **Shipped as a fixture.**

`forge` is a gate over the §2.3 sample that reads `inv/iron`, `inv/wood` and `inv/sword` with a
linear lookup `get` (0 if absent), and, if iron ≥ 2 and wood ≥ 1, writes iron − 2, wood − 1 and
sword + 1; otherwise it writes nothing. Its compiled jam (pinned `hoonc` at nockchain
`cbd9298f`, the stdlib core with the gate as arm 2) is `Theory/NockCost/forge.jam.hex`; its
Hoon source is not in this tree. On the sample `(3, 2, 0)` it runs in 1,345 Lean steps
(`Theory.NockCost.pole_forge_steps`). The design estimated 400 to 900. The journeys
(J-NOCK-2b, J-NOCK-3, J-EVAL) birth and run it from `NOCK_TEMPLATES`.
`native/resource-client/templates/mud/programs/resolver.hoon` uses the same `get` over signed
values.

## 6. Lanes

| lane | what it built | where |
|---|---|---|
| NOCK-THEORY | nouns, the Nock spec and interpreter | `Theory/Noun.lean`, `Theory/Nock.lean` |
| N-MUG | compiled jam/cue with mug-keyed tables, proved equal to the spec | `Theory/Noun.lean` (`@[csimp]`) |
| NOCK-RUNNER | the differential harness against `nockvm` | `Host/NockEval.lean`; runner outside the tree |
| K-NOCK-CELL | the program cell, its codec and birth (§2.1) | `Compiler/NockProgramCodec.lean`, `Kernel/NockProgramCell.lean` |
| K-RAN | the run claim and its check, `ran` (§2.4) | `Kernel/Run.lean`, `Kernel/ResourceTransaction.lean` |
| K-RUN-PIN | `pinned` context, `staleField` (§2.3) | `Kernel/NockProgramCell/Sample.lean` |
| N11 | the NockApp door (§2.7) | `Kernel/NockDoor.lean` |
| N16 | library cells, `subjectFormula` (§2.1) | `Kernel/NockEntry.lean` |

Journeys: J-NOCK-2b (`journey.d/jnock2.sh`, the program cell), J-NOCK-3 (`jnock3.sh`, the run
check), J-NOCK-3P (`jnock3p.sh`, pinned claims), J-NOCK-5 (`jnock5.sh`, the door).
