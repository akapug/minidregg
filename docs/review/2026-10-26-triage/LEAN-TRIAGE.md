# Lean-side scar census, 2026-10-26

Read-only census of the Lean tree at `a0db11f8` plus the working tree (5 untracked `.lean` files).
Nothing was built: no `lake build`, no `lake env lean`. Every number comes from a script in
`/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/triage-lean/`:
`graph.py`, `reach.py`, `use.py`, `nsref2.py`, `twins.py`, `closedthm.py`, `split.py`, `thmobj.py`; the
helper outputs are under `guard/` and `scripts/` there. Tags: **measured** means a script printed the
number; **read** means I read the source; **estimate** means my inference.

## 0. Corrections to the briefing (measured)

1. **There are zero `#guard` lines.** The "4,258 `#guard` lines in 519 files" came from a prefix grep
   (also quoted in `docs/review/2026-10-26-history/HISTORY.md:479`). It matched `#guard_msgs`.
   - There are 4,257 `#guard_msgs` lines in 520 files, and every one is
     `#guard_msgs (whitespace := lax) in #print axioms <thm>`, an axiom pin.
   - Law 9's wound has moved to closed theorems instead: `theorem x : f c = v := by decide`.
     There are **2,501** closed, concretely decided theorems out of 20,875 theorem/lemma/example
     headers; 1,085 of them are in the Host.Main closure (§1.4).
2. **No `sorry` appears in code.** The 53 word occurrences, in 46 files, are all in comments or
   docstrings (the census strips both). The briefing's 84 count included docs.
3. **The Host closure equals the census: 787 modules / 330,505 lines** (measured; it matches the
   orchestrator census).
4. **Family count.** My tokenizer (directory plus the first two CamelCase tokens) gives 816 families,
   not 827. Every big-family number below uses my tokenizer.

## 1. Method and measurements

### 1.1 Reach classes (measured, `reach.py`)

- I built the import graph from `^import` lines over 1,556 modules. Excluded: `.lake`, `scripts`,
  `tests`, `docs`, `scratch`, `native`, `prover`.
- Closures come from every `lakefile.toml` root: 19 `lean_exe` roots and 20 `lean_lib` roots.
- Each module is classified as one of:
  - **HOST**: in the `Host.Main` closure;
  - **EXE**: in another executable's closure only;
  - **QUAL**: in a qualification library only (Verify, SimplexQualification, ObjectiveProofs, Fixtures);
  - **CENSUS**: in an umbrella or census root only (Minidregg, AxiomCensus\*, TokenCensus,
    CensusChecks, ResearchWip, Deployed, or the namespace umbrellas);
  - **NONE**: in no root.

| dir | HOST n / lines | EXE | QUAL | CENSUS-only | NONE |
|---|---|---|---|---|---|
| Kernel | 415 / 163,811 | 11 / 2,865 | 35 / 11,476 | 104 / 33,051 | 5 / 374 |
| Compiler | 159 / 62,025 | 10 / 3,500 | 3 / 679 | 155 / 39,233 | 2 / 144 |
| Theory | 107 / 58,671 | 2 / 395 | 5 / 3,767 | 65 / 23,820 | 0 |
| Selvage | 12 / 7,488 | 0 | 0 | 140 / 70,642 | 0 |
| Assurance | 0 | 0 | 1 / 84 | 149 / 59,757 | 0 |
| Host | 87 / 34,655 | 15 / 2,394 | 0 | 14 / 1,090 | 8 / 816 |
| Pred | 7 / 3,855 | 0 | 0 | 3 / 653 | 0 |
| Verify, Fixtures, TokenCensus, Effects, root | 0 | 6 / 1,105 | 12 / 1,202 | 23 / 2,629 | 2 / 425 |
| **total** | **787 / 330,505** | 44 / 10,259 | 56 / 17,208 | 652 / 230,875 | 17 / 1,759 |

**Being in the import closure is not the same as being executed.** Two finer measures:

- **Name reach** (`use.py`, an upper bound). A module counts as used when one of its declared names
  appears in a used importer. By this measure 758 of 787 Host modules are used. It is noisy, because
  generic names such as `receiveVerified` collide.
- **Namespace reach** (`nsref2.py`, the sharper one). Of the 679 Host-closure modules that declare a
  namespace named after the module, **10 modules / 2,753 lines are referenced by no other Host-closure
  module** (§2.1).

The import closure reaches nearly everything because Host.Main imports almost every receiver directly;
the scar tissue is **live strata and twins**, not dead files.

### 1.2 The large families (≥8 modules or ≥5K lines; measured)

| family | mods | lines | Host.Main | other exe | qual | census-only | none | Host but uncalled | versioned (V2+/Legacy/Retry) | twin pairs ≥0.8 |
|---|---|---|---|---|---|---|---|---|---|---|
| Theory.ObjectiveBend | 46 | 26,790 | 37/22,426 | 0 | 5/3,767 | 4/597 | 0 | 1/174 | 0 | 0 |
| Selvage.BaseFold | 23 | 11,891 | 0 | 0 | 0 | 23/11,891 | 0 | 0 | 0 | 0 |
| Kernel.ObjectiveActivity | 8 | 11,692 | 7/11,627 | 0 | 1/65 | 0 | 0 | 0 | 0 | 0 |
| Kernel.NativeHost | 14 | 11,607 | 13/11,517 | 0 | 0 | 1/90 | 0 | 0 | 0 | 0 |
| **Kernel.ApplicationLifecycle** | **66** | 9,743 | 62/9,396 | 0 | 0 | 4/347 | 0 | **3/383** | **41/5,842** | **18** |
| Compiler.ObjectiveBend | 24 | 8,213 | 18/5,996 | 3/1,607 | 2/412 | 1/198 | 0 | 0 | 0 | 0 |
| Kernel.PayEnrol | 12 | 7,467 | 10/6,753 | 0 | 0 | 2/714 | 0 | 0 | 4/2,514 | 0 |
| Kernel.GenericSimplex | 33 | 7,282 | 6/1,408 | 0 | 26/5,532 | 1/342 | 0 | 0 | 0 | 0 |
| Selvage.OracleLog | 13 | 7,095 | 0 | 0 | 0 | 13/7,095 | 0 | 0 | 0 | 0 |
| Selvage.SpongeIndiff | 21 | 6,505 | 0 | 0 | 0 | 21/6,505 | 0 | 0 | 0 | 0 |
| Selvage.AccRbr | 7 | 5,776 | 0 | 0 | 0 | 7/5,776 | 0 | 0 | 0 | 0 |
| Kernel.ApplicationDispatch | 26 | 5,251 | 24/5,016 | 0 | 0 | 0 | 2/235 (untracked) | 0 | 0 | 0 |
| Assurance.HyperdocumentLink | 9 | 4,686 | 0 | 0 | 0 | 9/4,686 | 0 | 0 | 0 | 0 |
| Assurance.SemanticHistory | 8 | 4,091 | 0 | 0 | 0 | 8/4,091 | 0 | 0 | 0 | 0 |
| Host.ApplicationLifecycle | 22 | 3,980 | 22/3,980 | 0 | 0 | 0 | 0 | 0 | 9/1,453 | 1 |
| Kernel.ApplicationAgent | 17 | 3,014 | 17/3,014 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Assurance.ZkmlMatmul | 9 | 3,012 | 0 | 0 | 0 | 9/3,012 | 0 | 0 | 0 | 0 |
| Kernel.FnConsumer | 16 | 2,629 | 13/2,287 | 0 | 0 | 1/260 | 2/82 (untracked) | 0 | 0 | 0 |
| Compiler.GenericSimplex | 9 | 2,503 | 3/1,116 | 5/1,180 | 0 | 1/207 | 0 | 0 | 0 | 0 |
| Kernel.ApplicationGrain / Share / Failed / FnSelective / Compiler.ObjectiveDemand | 11/11/10/10/9 | 2,315/1,916/1,702/1,615/1,250 | mostly Host | | | ObjectiveDemand 9/1,250 census-only | | | Failed 1/222 | Failed 2 |

The families split into four kinds:

- **One design in N files** (read): Theory.ObjectiveBend, Kernel.ObjectiveActivity, Kernel.NativeHost,
  Compiler.ObjectiveBend, Kernel.ApplicationAgent, Kernel.ApplicationDispatch.
  - These are role splits, not strata. The roles are Core / Ingress / Receiver / Lookup / Projection /
    Payer / ReserveCore / ReserveContext / PaidAuthoring.
  - Every role module is called. The cost is the per-family role scaffold that
    `docs/design/RECEIVER.md:14-26` measured: 53 copies of `inductive Reject`, 38 of
    `structure Accepted`, 40 of `structure Prepared` and 23 of `requireSome` remain on main, against
    58 / 53 / 52 / 22 on 10-04.
  - Only step 0 of that plan landed: `Kernel/Receivers/SubjectKeyRotation.lean` is the one module in
    `Kernel/Receivers/`.
- **N strata of one design**: Kernel.ApplicationLifecycle and Host.ApplicationLifecycle (V1, V2, V3,
  RetryV4, all born 2026-09-27..10-04), and Kernel.PayEnrol (V1 and V2, 09-30 and 10-02).
- **Proofs about a separately executed engine**: Kernel.GenericSimplex. Its 26 QUAL modules prove
  safety of the Lean engine that the `generic-simplex-*` executables run. That is legitimate; keep it.
- **Research, nothing in Host**: Selvage.\*, Assurance.\*, Compiler.ObjectiveDemand.

### 1.3 Where the ApplicationLifecycle strata go (read, `Host/Main.lean`)

- **Begin submit** dispatches only RetryV4 or V3 (`Host/Main.lean:1316`, `:1331-1337`).
- **Begin lookup** accepts RetryV4 / V3 / V2 / legacy (`:1353-1365`).
- **Claim submit** dispatches RetryV4 or V3 (`:2511`, `:2553-2562`); claim lookup accepts four
  versions (`:1382-1394`).
- **Completion submit** dispatches RetryV4 or V2 (`:1430`, `:1448-1454`).
- **Not dispatched to by anything:**
  - `Kernel.ApplicationLifecycleBeginV2Receiver`, `ClaimV2Receiver` and `CompletionReceiver` (V1).
    `Host/Main.lean:137,139,143` imports them, and no Host-closure module references their
    namespaces (`nsref2.py`).
  - Four census-only V1 modules: `BeginCheck`, `ClaimPolicyCheck`, `ClaimReceiver` and
    `ClaimVerified`.
- **V1/V2 Ingress, Core and Lookup stay live** only because old records are still looked up.

### 1.4 Case-test census (law 9; measured, `closedthm.py`)

- A closed concrete theorem has no binders, no ∀/∃/→ in its statement, and is proved by `decide`,
  `native_decide`, `rfl`, `simp` or `norm_num`. There are **2,501** of them, 1,085 in the Host
  closure. There are 334 `native_decide` uses in 61 files.
- Many closed theorems are legitimate constant facts, for example `Compiler/FnWirePinned.lean:44`
  `pinned_digest` and `Theory/Sp800185Cshake256Fast.lean:361` rotation offsets.
- **Case batteries** are files with ≥5 theorems of which ≥60% are closed cases: **40 files /
  9,378 lines**. Of these, **22 files / 3,224 lines are leaf files outside Host that no
  non-umbrella module imports**.
- Example (read): `Kernel/AgentGrainAudit.lean:13-30` is 35 `accepts <state> <state> = true/false :=
  by decide` lines over two fixed states, beside no general theorem about `accepts`. That is law 9's
  "848 case-tests = zero theorems" shape, carried into `theorem` syntax.

## 2. DELETE (scars)

Each item gives its lines and the test it fails.

### 2.1 Strata no dispatcher reaches (measured)

| module | lines | test failed |
|---|---|---|
| `Kernel/ApplicationLifecycleBeginV2Receiver.lean` | 106 | imported at `Host/Main.lean:137`; namespace referenced by no Host module; submit routes V4/V3 only (`Host/Main.lean:1331-1337`) |
| `Kernel/ApplicationLifecycleClaimV2Receiver.lean` | 168 | imported `:139`; claim submit routes V4/V3 (`:2553-2562`) |
| `Kernel/ApplicationLifecycleCompletionReceiver.lean` | 109 | imported `:143`; completion submit routes V4/V2 (`:1448-1454`) |
| `Kernel/ApplicationLifecycleBeginCheck.lean`, `ClaimPolicyCheck`, `ClaimReceiver`, `ClaimVerified` | 51+36+157+103 = 347 | census-only V1 strata; nothing in any exe closure; `ClaimReceiver` is a 0.75-Jaccard twin of the live `ClaimV3Receiver` |
| `Host/WorldPrototypeDefinitionAuthor.lean` | 49 | in no lakefile root; referenced by no file in the repository |

- **Deleting the receivers also means editing** the `Host/Main.lean` import lines and their
  `TokenCensus/Table.lean` rows.
- **Host-closure modules nothing calls, but not deletable as scars:**
  - `Theory.DeclaredTurn` (457): see §3.3.
  - `Theory.PrivateComputationDeclaration` (521), `Compiler.TranscriptController` (316) and
    `Theory.DisclosureDeclaration` (281): imported by `Compiler/SemanticArtifactBundle.lean` for
    nothing in Host. They belong to the research move (§5): cut the import.
  - `Kernel.PayObservationProofs` (583), `Theory.ObjectiveBendInteraction` (174) and
    `Kernel.PhysicalResourceReadGuard` (38): proof or helper modules used only outside Host.
    Narrow the import.

### 2.2 Twins beside a kept twin (measured, `twins.py`)

Line-set Jaccard after normalizing version and family tokens. There are 70 pairs ≥0.6 and 21 pairs
≥0.8, all in ApplicationLifecycle / FailedStartRecovery / Fn polls. The top pairs:

| pair | Jaccard | lines |
|---|---|---|
| `ApplicationLifecycleCompletionHistory` / `…CompletionV2History` | 0.98 | 101/101 |
| `FnEmptyPollReceiverV2` / `FnSelectedPollReceiver` | 0.97 | 74/77 |
| `ApplicationLifecycleCompletionV2Policy` / `ApplicationFailedStartRecoveryPolicy` | 0.95 | 319/313 |
| `ApplicationLifecycleCompletionReceiver` / `…CompletionV2Receiver` | 0.94 | 109/110 |
| `…CompletionV2Policy` / `…CompletionPolicy` | 0.93 | 319/300 |
| `…CompletionSource` / `…CompletionV2Source` | 0.91 | 155/152 |
| `…CompletionV2Admission` / `…CompletionAdmission` | 0.90 | 377/336 |
| `…RetryCompletionV4Admission` / `…CompletionV2Admission` | 0.88 | 380/377 |
| `ParticipantKeyEnrollmentReceiver` / `ParticipantFactoryProvisioningReceiver` | 0.79 | 190/192 |
| `CapabilityDelegationReceiver` / `CapabilityRevocationReceiver` | 0.76 | 309/303 |

- Every pair above is in the Host closure, and both members are live. They are not deletable as
  files; they collapse into the one-`Family` receiver (§3.2).
- The 10-04 twin pair `ApplicationAgentLifetimeGrantAtomicBirth` / `ApplicationShareIssueAtomicBirth`
  has already been deleted.

### 2.3 Theorems whose object is not the running path, with nobody planning to wire them

See the §3 table. Candidates:

- **`Kernel/TurnCensus.lean:653-690`.** `every_admission_is_turn`, `theList_empty`,
  `theListWithoutRomBirth_eq`: `decide +kernel` over 48 hand-built representative turns at `w0` in a
  coarsened census registry. Its own docstring (`:22-25`) says it is not built from the `Accepted`
  objects.
  - Once `host_submit_is_step` lands (§3.1) it is redundant. Until then, rename it as a census and
    stop quoting it as "every admission".
- **FORMAL_STATUS rows whose objects are census-only.** Delete them from `docs/`, or move them with
  the research (§5): `Theory/ReactiveCellTransition.lean`, `Kernel/FramedWalRefinement.lean`,
  `Kernel/PrivateTurn.lean`, `Kernel/PrivateEscrowSettlement.lean`, and the EVM stage 0 modules
  (`Theory/EvmFragment.lean`, `Theory/EvmResidual.lean`, `Compiler/EvmAddAir.lean`).

### 2.4 Case-test batteries (measured; list in `closedcase.tsv`)

The 22 leaf batteries outside Host total **3,224 lines**:

| batteries | lines |
|---|---|
| `Kernel/AgentGrainAudit.lean`, `Kernel/ContentResourceAudit.lean` | 129, 419 |
| `Assurance/BoundedNockChecks.lean`, `Assurance/BoundedNockNetworkChecks.lean` | 121, 52 |
| `Compiler/NativeOrderPoles.lean` | 214 |
| `Compiler/ObjectiveBendSpecificationClosure.lean` (QUAL) | 306 |
| `Kernel/ApplicationManagedPolicyCheck.lean` | 80 |
| `Assurance/HyperdocumentLinkSqliteTransactionalStore.lean` | 362 |
| `Assurance/NockDoorAudit.lean`, `ObliviousNetworkChecks`, `PrivateEvaluatorCustodyChecks`, `ResourceMoneyReceiverAudit` | 160, 63, 74, 81 |
| `Compiler/ZkmlTraceCheck.lean` | 580 |
| `Assurance/ZkmlMatmulConformance.lean`, `MixedFieldBudget`, `AirSumcheckCubicConformance` | 252, 185, 209 |
| `Compiler/CarryConfigurationChecks.lean`, `LegacyStoreCarryChecks`, `CanonicalAccountViewAudit` | 48, 60, 64 |
| `Kernel/ApplicationLifecycleClaimPolicyCheck.lean` | 36 |
| `Theory/ObjectiveBendDigestChecks.lean` | 76 |
| `Compiler/BendProofCshakeBoundedChecks.lean` | 34 |
| `Host/ApplicationManagedPolicyAuthoringCheck.lean` | 38 |

**What they fail:** law 9. There is no general theorem about the subject in the file. Where a battery
is the only accept/refuse evidence for a receiver, replace it with the satisfiable/teeth pair the
ATLAS asks for rather than just deleting it. `ContentResourceAudit` and `HyperdocumentLinkSqlite…`
are the two where a general theorem plausibly exists elsewhere; check them before deleting.

The other 18 batteries (6,154 lines) are in Host or have importers. They need folding, not deleting.
`Kernel/Job.lean` (57 of 91 theorems are closed cases) and `Kernel/PayCell.lean` (14/18) are the
largest.

### 2.5 Scripts that point at nothing (helper census, `summary.md [not in tree]`)

- **5 files / 718 lines have every repo path they reference dead:**
  - `scripts/spk-platform/two-world-journey.sh` (221);
  - `scripts/fn-e1e2/two_store_join_{dynamic_r,socket_b,per_side}.patch` (211, 152, 74);
  - `scripts/test_lean_warm_preflight.py` (60).
- **6 files cite a missing `.lean` path:** `scripts/test_lean_build_surfaces.py`,
  `scripts/test_build_gate_boundaries.py`, `scripts/pipeline/fixture-authorities.txt`,
  `scripts/ports/KN2-PORT-PARTITION.txt`, `scripts/ports/kn2-census.tsv`, and
  `scripts/test_lean_warm_preflight.py` (also in the list above).
- **Lean module references in `lake build`, `lake env lean` and `import` lines: 150, with 0
  missing.**
- On this measure, scripts/ is clean. Its size is gate data: `scripts/gates/` is 623 files, including
  `objective-manifest/constants.content` at 58K lines.
- 676 script files (48,342 lines) are referenced by no other file. Most of them are gate inputs read
  by directory, so this is **not** a deletion list.
- Count by class: GATE-reachable 879 files / 149,268 lines; PIPELINE 11 / 326; PROBE 20 / 1,905;
  OTHER 128 / 14,723.

### 2.6 Docs contradicted by code (read)

| doc claim | code | test failed |
|---|---|---|
| `Deployed.lean:6-10`: Deployed leaves out Selvage; "Mini admits by re-execution, not by proof (decision 10-01), so no deployed module needs them" | Host.Main closure holds **12 Selvage modules / 7,488 lines** via `Host.Main → Kernel.ObjectiveBendNativeAdmission → Compiler.Evaluator → Compiler.Sp800185Cshake256 (:19) → Compiler.Tower256CshakeMerkleController (:24-25) → Selvage.BinaryLookup / Compiler.AuthenticatedColumnPlan → Selvage.Commitment` | closure measurement |
| `Kernel/HostRefinesWorldCore.lean:41`: `every_admission_is_turn` "decides it for all 37 shapes" | `Kernel/TurnCensus.lean:4,45`: 48 constructors | stale count |
| `Kernel/HostRefinesWorldCore.lean:79`: a `theorem host_submit_is_step` line at column 0 | it is inside the module docstring and not proved; grep-based theorem censuses count it | statement exists only in prose |
| `docs/design/RECEIVER.md:256` cites `Kernel/HostRefinesWorld.lean:1006` | that file is 128 lines; the content moved to `HostRefinesWorldCore.lean` | dead line reference |
| `docs/FORMAL_STATUS_AND_NEXT_PROOFS.md` (snapshot `bf45a611`, 2026-08-18) cites `Kernel.Gate [deleted e5e66049]`; its "immediate next proof" is BaseFold | `Kernel.Gate [deleted e5e66049]` does not exist; per `Deployed.lean`, the 10-01 decision demoted proof-based admission | stale document; rewrite or retire |
| `HISTORY.md:479` / NANO-VS-MINI: "4,258 `#guard` lines" | 0 `#guard`; 4,257 `#guard_msgs` axiom pins | §0 |
| 58 docs `.md` files with ≥1 dead path; worst `docs/KERNEL-TWIN-AUDIT.md` (18 of 124 dead), `docs/research/2026-10-02-private-objects/typed-effects-design.md` (8 of 9), `docs/HP-DESIGN.md` (5 of 34), `docs/objective-bend/evidence/STATUS.md` (5 of 7), `docs/WORLD-RUNBOOK.md` (4 of 6) | | dead path refs |

### 2.7 Untracked work-in-progress in the tree (measured)

These 5 untracked Lean files are NONE-class: in no root, imported by nothing.

- `Kernel/ApplicationDispatchAgentPurse.lean` (59)
- `Kernel/ApplicationDispatchAgentReserve.lean` (176)
- `Kernel/FnConsumerFrontierProofs.lean` (34)
- `Kernel/FnConsumerFrontierScenario.lean` (48)
- `Compiler/UwueavePreoProjectionV2.lean` (113)

They are more `Purse/Reserve/V2` strata. The owner decides whether to land or drop them; they are not
counted below.

## 3. RESCUE

### 3.1 Headline: make the running writer the object of the World theorems

**What is true today (read):**

- `World.admit` (`Kernel/World.lean:647`) has ~160 theorems in its file. It executes in the
  `turn-log-follower`, `world-sim` and `objective-turn-totality` executables: `Host/TurnLogFollower.lean:6-8`,
  `Host/WorldSim.lean:110`, `Host/ObjectiveTurnTotalityRunner.lean`.
- The writer runs `DurableDataIntent.execute` through `DurableCheckpoint.prepare` /
  `DurableReceiverIO` (`Kernel/HostRefinesWorldCore.lean:4-7`).
- **A refinement already exists:** `deployed_refines_step` (`Kernel/HostRefinesWorldCore.lean:432`),
  `host_trace_represents_fold` (`:454`) and `confirmed_represents` (`:576`). They prove that today's
  executor is an `ImplementationRefinement` of `World.step`.
  - The object is the running path, so World.admit is not wholly disconnected from the writer, and
    the sibling scout's "no caller" finding is only half the story.
  - Its scope is limited. `HostStep.derived : Turn.ofLoaded B H p intent = .ok t` (`:421`) is a field
    of the step, so **every deployed step whose derived turn fails is outside the theorem**. The
    docstring (`:131-135`) says the durable layer today *would install* an append-only rewrite that
    `World.admit` refuses.
  - The gaps G-JOURNAL, G-PARENT and G-AUTH are open (`:52-71`), and `host_submit_is_step` exists
    only as prose (`:79`).

**The plan exists twice, and neither landed:**

- `docs/HP-DESIGN.md:16-24`, HP-3 LOOP: one resident Host holds the World and admits each request
  with `World.admit`. HISTORY.md:484 records that HP-3 was never restarted. HP-1 BOUNDS
  (`Kernel/Bounds.lean`) and HP-6 SIM (`Host/WorldSim.lean`, `Kernel/TurnGen.lean`) did land.
- `docs/design/RECEIVER.md:244-325`: a total `Turn.ofAccepted`, one `NativeAdmission.receiver`
  constructor, and `host_submit_is_step` proved once over `Family` (step 8).

**Estimate.**

| path | what it takes | cost | what it buys |
|---|---|---|---|
| (a) gate mode | Call `Turn.ofLoaded` + `World.admit` in the receive path after `prepare` succeeds and refuse on error. `Host/WorldSim.lean` already composes receiver → `Turn.ofIntent` → `World.admit` in one process. | ~300–800 Lean lines across `Compiler/DurableReceiverIO`, `Kernel/NativeHostSession`, `Host/Main`, plus a held `World` per session | Closes the refusing pole (the writer can no longer install what World refuses) and makes `confirmed_represents` cover every confirmed step |
| (b) the real cutover | RECEIVER steps 1-8, or HP-3 | ~10 files per range by HP-DESIGN's own sizing; re-genesis at steps 5-6 | Proves `host_submit_is_step`; Represents becomes equality |

Both rows are my estimates.

**Cost risk:**

- The World is a functional map of all cells. No world-fold or world-root benchmark result is
  recorded under `docs/` (I searched for one), so the per-turn cost of a held World is unmeasured.
- The two "receiver-only stale classes" that WorldSim counts but does not assert
  (`Host/WorldSim.lean:21-23`) must be decided first.

### 3.2 Families where one stratum should become the only path

- **ApplicationLifecycle.** Keep RetryV4 plus the current V3 claim/begin.
  - First delete the 3 uncalled submit receivers and the 4 census-only V1 modules (§2.1).
  - Then RECEIVER.md step 5 ("keep only the newest version", re-genesis) retires **41 versioned
    Kernel modules (5,842 lines) and 9 Host modules (1,453 lines)**, minus whatever stratum survives.
  - FailedStartRecovery has ≥0.83 twins of CompletionV2 Policy / Admission / History; it is the same
    module with a different marker.
- **PayEnrol.** V1 (`PayEnrolReceiver` 1,678, `PayEnrolDecision` 589, `PayEnrolMemo` 711) and V2
  (`PayEnrolV2Receiver` 876, `V2Decision` 619, `V2Legs` 458, `MemoV2` 561) are both dispatched.
  RECEIVER.md step 6 plans "v2 only; v1 deleted". That is about 3K lines (estimate).
- **Fn polls.** `FnEmptyPollReceiverV2` and `FnSelectedPollReceiver` are 0.97 twins. Make them one
  receiver parameterized by poll kind.
- **Receiver scaffold.** Collapse the receiver families onto `Kernel/Receiving.lean`'s `Family`, as
  steps 1-4 in RECEIVER.md propose. Only SubjectKeyRotation (step 0) has migrated.

### 3.3 Proven but unwired

- `Theory/DeclaredTurn.lean` (457) is quoted by FORMAL_STATUS as the "typed turns" keystone.
  - It is in the Host closure, but no Host module references its namespace; only
    `Assurance/DeclaredTurnReceipt.lean` does.
  - Either it becomes the shape `Turn.ofAccepted` produces, or it moves out of the Host closure.
- `Kernel/HostRefinesWorld.lean` (128, `Turn.ofAdmission`) is reached only by
  `objective-turn-totality`. RECEIVER step 8 moves it into the Host closure.

## 4. REPAIR (statement-level defects, read from statements)

1. **The vacuous outer-`∨ Collision` class (measured: 33 theorems in 13 files, 28 of them in 9
   Host-closure files).**
   - `Theory/HashBytes.lean:91` defines `Collision H := ∃ a b : List UInt8, a ≠ b ∧ ofBE (H a) = ofBE (H b)`
     over an infinite domain. At any fixed-width hash, including `cshake256Bytes`, pigeonhole makes it
     **true**, so `P ∨ Collision H` holds for every P.
   - `Theory/AuthTrie.lean:81` (`Collision dig` over `NodeIn`) has the same shape.
   - The repo knows this: `Compiler/DurableIndex.lean:691` says "Unlike the global `Collision dig`,
     this is not supplied by pigeonhole alone", and `Kernel/Contracts/Snapshot.lean:194` proves
     `untagged_store_collision_exists`.
   - Affected theorems:
     - `Kernel/DomainEpoch.lean:382,392,503,509,515,549,610,747,780,963,992` (13 theorems);
     - `Theory/AuthTrie.lean:135,166,265` (`verify_sound` among them);
     - `Theory/AuthTrieRange.lean:114,182`;
     - `Pred/HashEq.lean` (3) and `Pred/HashEqDigest.lean` (1);
     - `Theory/LogAccumulator.lean:177,223`;
     - `Theory/AuthTrieCache.lean:992`;
     - `Compiler/DurableHistory.lean:257`;
     - `Compiler/StoreHiding.lean`;
     - census-only: `Theory/ObjectiveBendDigest.lean:195,205`, `Kernel/SealedMarket.lean:257`,
       `Compiler/Tower256CshakeMerkleBinding.lean:254`, `Selvage/BinaryMerkle.lean:200`.
   - The fix shape is already in the tree: restrict the collision to the observed finite node set
     (`RowsCollision`, `Compiler/DurableIndex.lean:692`), or return the colliding pair as named
     transcript inputs.
   - The CX-MINI-COLL series (7 patches, 61 files, per HISTORY.md:477) is unlanded. My regex count is
     a lower bound; it misses multi-line statements.
2. **`HostStep.derived` premise** (`Kernel/HostRefinesWorldCore.lean:418-428`). The refinement
   quantifies only over steps whose derived turn exists. Add the refusing pole the docstring names
   (`Turn.ofAdmission … = .error r → ∀ ready, prepare … ≠ .inl ready`) or make `Turn.ofAccepted`
   total (RECEIVER.md §3).
3. **`TurnCensus.every_admission_is_turn`** (`Kernel/TurnCensus.lean:658`). The name is universal;
   the statement covers 48 representative constructions at `w0`. Rename it, or restate it over
   `Turn.ofAccepted`.
4. **`Theory/ObjectiveBendTyping.lean:637` `def TotalProof (law : Prop) := law`.** This is naming as
   faking (law 1). `docs/OBJECTIVE-BEND.md:806` already confesses it. Delete the alias: a theorem is
   its statement.
5. **`ObjectiveBendExtensions` `mix_append` / `composition_associative`.** These are proved on a
   separate list model with "no theorem ties it to `Term.mix`" (`docs/OBJECTIVE-BEND.md:786`). This is
   a law 5 parallel tower. Tie it to `Term.mix` or delete it (103 lines, census-only).

## 5. Research vs demo split

**What Host.Main takes from Selvage, and why (measured).**

- It takes 12 modules / 7,488 lines: Accumulator, BinaryLookup, Commitment, ConstrainedCode,
  CorrelatedAgreement, Decider, Depth, MultilinearExtension, Rbr, ReedSolomon, Sumcheck and
  SumcheckReduction.
- **No Host-path code calls any of them.** They arrive because
  `Compiler/Sp800185Cshake256.lean:19` imports `Compiler/Tower256CshakeMerkleController.lean`.
  - Its consumers use only `Cshake256`, `XofRequest`, `checkedXofCall` and
    `checkedXofCall_reply_exact` (lines 43-60 and 376-424).
  - The controller in turn imports `Selvage.BinaryLookup` and `Compiler.AuthenticatedColumnPlan`
    for the adapter theorem `bindingMerkle_toSelvage_commit_exact` (`:238`).
- **Graph surgery** (`split.py`, upper bound). Cutting the controller's Selvage and
  AuthenticatedColumnPlan imports removes **25 modules / 13,830 lines** from the Host closure:
  - all 12 Selvage modules;
  - `Compiler.Emit`, `EmitSerialize`, `AirBignum`, `AirFlatten`, `AirHash`, `AirMembership`,
    `AirModularView`, `BabyBear`, `BignumKernelABI`, `NativeKernelPlan`, `NoteSpend`,
    `AuthenticatedColumnPlan`;
  - `Theory.CrossModulus`.
- **Caveat (read).** `Compiler/Tower256ConcreteBackend.lean` is in the Host closure via
  `Compiler/GrainResourceBirthController.lean:17`. It opens `AuthenticatedColumnPlan` and
  `NativeKernelPlan`, and it is the codec hub. The cut therefore needs a split there too: the XOF and
  codec half versus the PCS-backend half. I did not verify that the codec half is separable. Quote
  the 13.8K as an upper bound.

**What moves to a research repository (measured, `research-closed.json`).**

- **Clean upward-closed set:** the 140 census-only Selvage modules plus everything that transitively
  imports them. That is **227 modules / 109,639 lines**: Selvage 140 / 70,642, Assurance 57 / 24,529,
  Compiler 29 / 14,452, and TokenCensus 1 (`TokenCensus.SelfTest`, 16 lines).
  - **No executable and no qualification library touches it.**
  - The 29 Compiler modules are CommittedTerminal\*, Ext6GateProof\*, Gate{Factored,Mle,TraceRelation}Ext6,
    Tower256AdditiveFri\*, Tower256Logup\*, ArithmeticNativeDeployment, EvmStage0NativeDeployment,
    TwistMultisetInvariant, AuthenticatedColumnLogupBridge, SparseAuthenticatedStateLogupBridge,
    AdditiveFriReceiptClause, Logup256ReceiptClause, ComposableDeploymentManifest and
    FramedWalRecoveryDeployment.
- **Plus, decided module by module:** **93 census-only Assurance modules / 35,312 lines** outside that
  set. They are about Kernel/Compiler objects: Hyperdocument\*, Credential\*, Bfv\*, ObjectiveZk\*,
  ZkmlMatmul\*. 40 of the 150 Assurance modules have all their direct imports inside the Host closure
  (`thmobj.json`, ABOUT_HOST). Those are the candidates to *stay* as running-path assurance.
- **How the move works:**
  1. The research repository `require`s minidregg at a pinned revision. Selvage's tier rule is
     unchanged (`scripts/check-import-boundary.sh:10`: Mathlib, Theory, Selvage), and removing files
     adds no imports, so the boundary check stays green.
  2. Remove the moved modules' import lines from `Selvage.lean`, `Assurance.lean`, `Compiler.lean`,
     `Minidregg.lean`, `AxiomCensusResearch.lean` and `TokenCensus/Table.lean`.
  3. Repoint `TokenCensus/SelfTest.lean`.
  4. **Blocker:** `scripts/check-prover-glue.sh` gates `Compiler/ArithmeticNativeDeployment.lean` and
     `Compiler/EvmStage0NativeDeployment.lean`. That gate and its `prover/generated` outputs move with
     them, or those two stay.
  5. The hyp-ledger gate runs over AxiomCensusResearch, so its allowlist rows for the moved modules
     move too.

## 6. The five numbers

| # | number | value |
|---|---|---|
| 1 | Lines deletable now | **3,967 Lean + 718 script = 4,685** (§2.1: 383 + 347 + 49; §2.4: 3,188 net of overlap; §2.5: 718). Consolidation, not rm, is where the size is: ApplicationLifecycle strata 7,295 (§3.2), PayEnrol V1 ~3K, needing re-genesis |
| 2 | Lines movable to research repos | **109,639** clean (227 modules, no exe or qual-lib dependency); up to **144,951** with the 93 census-only Assurance modules (35,312) |
| 3 | Host.Main closure after both | **330,122 lines / 784 modules**: the move touches no Host module, and deletion removes 3 receivers. **≤316.3K** if the cSHAKE/Merkle controller split (§5) also lands (upper bound, unverified) |
| 4 | Modules in the biggest family that nothing dispatches to | **Kernel.ApplicationLifecycle (66 modules): 7 / 730 lines** dispatched to by nothing, plus 41 versioned modules (5,842) alive only for old-record lookups. Theory.ObjectiveBend (biggest by lines): 1 Host-uncalled (174) + 4 census-only (597); its 5 QUAL modules are legitimate proofs |
| 5 | Theorems that gate the running path vs theorems that do not | **Headline table below: 4 gate (1 partially) vs 10 that do not.** Coarse: 10,621 of 20,720 theorem/lemma declarations are compiled into the Host closure and 10,099 are outside it. Of those outside, 2,731 sit in modules whose direct imports are all Host-closure code. Inside the closure, 28 are vacuous collision disjuncts and about 160 are about `World.admit`, which the writer does not execute |

### Headline theorems versus the running path (read)

| theorem | object | does Host.Main run the object? |
|---|---|---|
| Core4 `runBounded_*_sound`, `checked_reachable_no_refusal`, `machine_evaluation_complete` (Theory/ObjectiveBend\*, ObjectiveProofs) | `runBounded` | **yes**: `Kernel/ObjectiveActivity.lean:127`, via the `@[csimp]` equalities |
| `accepted_typed` / `accepted_never_refused` (`Compiler/ObjectiveBendFrontEndAdequacy.lean`) | the front end's packet | **yes**: the receiver re-runs the front end (README:84) |
| `admitted_front_end` / `admitted_source_semantics` (`Kernel/ObjectiveBendAdmissionSemantics.lean:26,97`) | `Admitted` from `Kernel.ObjectiveBendNativeAdmission` | **yes** |
| `deployed_refines_step` / `confirmed_represents` (`Kernel/HostRefinesWorldCore.lean:432,576`) | `execute` + `Loaded.extend` | **partly**: only steps whose derived turn exists (§4.2) |
| `host_submit_is_step` | — | **not proved** (docstring, `:79`) |
| `World.admit` lemmas (`Kernel/World.lean:783-1143`) | `World.admit` | **no** for the writer; yes for follower, world-sim and totality |
| `TurnCensus.every_admission_is_turn` | 48 representative turns | **no** |
| AuthTrie / DomainEpoch / HashEq `…_sound` with `∨ Collision` | the right functions | object yes, **content null** (§4.1) |
| `Theory/DeclaredTurn.lean` | typed turns | **no**: imported, namespace uncalled |
| ReactiveCellTransition, FramedWalRefinement, PrivateTurn / Escrow (FORMAL_STATUS) | models | **no**: census-only |
| BaseFold / BCS / AccRbr / RingSwitching / CharTwoWall / HashFamily (FORMAL_STATUS) | Selvage | **no**: census-only |
| Spartan / zkML matmul / Twist (FORMAL_STATUS) | research checkers | **no**: census-only |
| EVM stage 0 (`Theory/EvmFragment`, `EvmResidual`, `Compiler/EvmAddAir`) | EVM fragment | **no**: census-only |
| `mix_append` / `composition_associative` | separate list model | **no** (§4.5) |

## 7. What I could not verify

- **Compilation.** Nothing was compiled. No deletion, cut or move was test-built. The Host-closure
  surgery (§5) and the deletions (§2.1) are import-graph arithmetic. The `TokenCensus`, `host-closure.pin`
  and objective-manifest gates will each need their rows edited.
- **Call reach is textual.** `nsref2.py` keys on module-named namespaces, and 107 Host modules
  declare none. Modules reached only through `open` of a parent namespace, or through instances,
  could be miscounted as called; the error direction is toward "called". Real constant-level reach
  from `main` needs Lean (`#print` closure or an environment walk).
- **Twin similarity is normalized line-set Jaccard.** The normalization folds family words, so it
  overstates similarity inside ApplicationLifecycle. The ≥0.9 pairs I spot-checked are real.
- **Which closed decided theorems are case tests** versus legitimate constant facts is a heuristic.
  I read two files: `AgentGrainAudit` is a battery; the `Job.lean` samples are constant facts.
- **The `∨ Collision` count is a single-line regex** and misses multi-line statements. I did not
  check each `Collision` instance's domain for pigeonhole truth beyond `HashBytes.Collision`,
  `AuthTrie.Collision` and the repository's own comment.
- **The World-on-the-writer estimate (§3.1) is inference**, from HP-DESIGN's own sizing and WorldSim's
  existing composition. No World-fold or world-root benchmark result is recorded in `docs/`.
- **Whether `Tower256ConcreteBackend`'s codec half separates from its PCS half** is unverified, and
  the 13.8K Host reduction depends on it.
- **Birth dates** are `git log --diff-filter=A`. Many families show 2026-09-27 because a single
  commit added a family's modules; that is a real date, not a migration artifact.
- **The docs census only checks path existence.** I read 6 docs for contradictions (README Honest
  state, FORMAL_STATUS, OBJECTIVE-BEND §What is proved, RECEIVER.md, HP-DESIGN, Deployed.lean
  header), not the 532 `.md` files.
