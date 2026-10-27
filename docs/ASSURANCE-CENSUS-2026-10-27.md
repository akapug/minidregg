# Assurance census, 2026-10-27

Present state of `Assurance/` against the `Host.Main` import closure and the `Deployed.lean` umbrella closure, measured at `lane/un-assurance` (from origin/main 5dafe0f3). Input to plan C2 ("census-only Assurance module by module", `docs/DEMO-PREFIX-2026-10-26.md:281`). Scout context: `docs/review/2026-10-27-untouched-areas/LEAN.md`.

## Method and rerun

    scripts/assurance-census.py > assurance.tsv      # TSV on stdout; counts and the closure check on stderr

Closures use `git ls-files` and `scripts/lean_imports.py`, with the roots `scripts/check-host-closure.sh` uses (`Host.Main` for the Host; `Deployed` for the deployed umbrella). On demand, not wired into any gate. Rerun it before C2 moves anything.

- Theorem count is an approximation: lines beginning (after indentation, `private`/`protected`, one attribute) with `theorem` or `lemma`. Column-0-only counting gives 1,748; this counting gives the totals below.
- Poles are per-file case-insensitive word counts of `satisfiab*` (sat), `teeth`, `inhabit*` (premise-inhabitation), prose and names alike: presence of the vocabulary, not a checked witness. The census does not audit that a pole is real (see `ATLAS.md` law 2).
- Class: DEPLOYED = in the `Deployed` closure. DEPLOYED-SUBJECT = outside it, but every non-Assurance module reached through Assurance-only imports is in the Host closure. RESEARCH = otherwise (at least one subject module outside the Host closure). The subject is read through Assurance-to-Assurance imports, so a module that only imports another Assurance module inherits that module's subject.

## Closure agreement (the check that refutes the script)

- Script: Host.Main reaches 776 modules. `scripts/gates/host-closure.max` ceiling: 776. `scripts/check-host-closure.sh` prints "OK: 776 modules, ceiling 776". Agreement, exactly.
- Assurance modules in the Host closure: 0 (of 145 including the `Assurance` umbrella; 144 modules censused).
- Deployed closure: 932 modules.
- Hand spot-checks (`rg '^import'`): `Assurance/StoryLaw.lean` imports `Kernel.LawHistory`, `Kernel.PolicyInstallController` only (DEPLOYED, kernel subject); `Assurance/EvaluatorAudit.lean` imports `Compiler.RefusalReason`, `Compiler.Evaluator` only (DEPLOYED); `Assurance/AirSumcheck.lean` imports `Compiler.AirFlatten` and `Selvage.SumcheckReduction` (RESEARCH, Selvage).

## Counts per class

| class | modules | theorems (approx) |
|---|---|---|
| DEPLOYED | 2 | 46 |
| DEPLOYED-SUBJECT | 15 | 171 |
| RESEARCH | 127 | 2133 |
| total | 144 | 2350 |

Of the 127 RESEARCH modules: 100 touch Selvage; 7 touch no Selvage but a Host-unreached Theory module (zkML/BFV/NTT programme); 20 touch only Host-unreached Kernel/Compiler modules (e.g. `Compiler.DeployedCellRegistry`, `Kernel.CanonicalEscrowMarket`). These last 20 are not proof-system research: they are about unreached kernel code and are the first candidates for a decision (wire the subject, or park with it), not for the research repo.

Other libraries from the same graph (numbers only):

- Theory: 109 reached, 74 unreached, 183 total.
- Selvage: 0 reached, 153 unreached, 153 total.
- Assurance: 0 reached, 145 unreached, 145 total.

## What deployed assurance may claim

Only the two modules the `Deployed.lean` umbrella imports from Assurance carry deployed assurance: `Assurance.EvaluatorAudit` (3 theorems) and `Assurance.StoryLaw` (43 theorems), 46 approximate theorems in 726 lines, neither with a satisfiable/teeth/inhabitation marker by this grep, and neither in the `Host.Main` closure. Subject reach differs: `EvaluatorAudit` is about `Compiler.Evaluator`/`RefusalReason`, both Host-reached; `StoryLaw` is about `Kernel.LawView` and `Kernel.PolicyInstallController` (Host-reached) AND `Kernel.LawHistory` (its accepted-history contract, NOT Host-reached; see the next section), so the story-room theorem `sealed_story_scene_monotone` is partly about code the Host does not run. Claimable sentence:

> Of 2,350 theorems (approximate, by line count) in 144 Assurance modules, 46 in 2 modules are carried by the deployed umbrella, which proves properties of the Host-reached evaluator and of the story law over an accepted-history module (`Kernel.LawHistory`) the Host does not yet import; none of the 144 modules is imported by the Host binary, and the remaining 2,304 theorems are research-umbrella results not part of the deployed claim.

Do not say "1,851" (the scout's older, column-0 figure) beside these numbers. `Deployed.lean`'s Residual comment still names `NockDoorAudit` among the kept audits; that module no longer exists (only two Assurance imports remain), a stale comment to fix when the file is next touched.

## C2 move list (input)

127 RESEARCH modules, 2133 theorems, below. The 15 DEPLOYED-SUBJECT modules (171 theorems) are the other decision: bring into `Deployed` (their subject is Host-reached code) or leave as research about deployed code.

### RESEARCH

| module | theorems | sat | teeth | inhab | subject |
|---|---|---|---|---|---|
| Assurance.AcceptedCellEffectHistory | 11 | 0 | 0 | 0 | Selvage x2, Kernel/Compiler-unreached x2 |
| Assurance.AirSumcheck | 21 | 1 | 6 | 4 | Selvage x1 |
| Assurance.AirSumcheckCubic | 32 | 0 | 7 | 1 | Selvage x3 |
| Assurance.AirSumcheckCubicConformance | 10 | 0 | 2 | 0 | Selvage x3, Kernel/Compiler-unreached x1 |
| Assurance.AirSumcheckQuadratic | 25 | 1 | 5 | 1 | Selvage x2 |
| Assurance.AuthenticatedColumnHistoryBridge | 4 | 0 | 0 | 1 | Selvage x5, Kernel/Compiler-unreached x4 |
| Assurance.AuthenticatedSettlementFinalityWitness | 35 | 0 | 4 | 1 | Theory-unreached x1, Kernel/Compiler-unreached x1 |
| Assurance.BendArithmeticQualification | 0 | 0 | 0 | 0 | Kernel/Compiler-unreached x6 |
| Assurance.BfvAcceptedCellEffect | 3 | 0 | 0 | 0 | Selvage x2, Kernel/Compiler-unreached x3 |
| Assurance.BfvConcreteBatchAdmission | 19 | 0 | 3 | 0 | Selvage x1, Kernel/Compiler-unreached x1 |
| Assurance.BfvConcreteBatchCell | 7 | 0 | 0 | 0 | Selvage x3, Kernel/Compiler-unreached x6 |
| Assurance.BfvNativeBufferAdmission | 16 | 0 | 0 | 2 | Selvage x1, Kernel/Compiler-unreached x1 |
| Assurance.BfvPrivateComputationJoin | 8 | 0 | 0 | 1 | Selvage x1, Kernel/Compiler-unreached x1 |
| Assurance.BfvProofControllerAdmission | 14 | 0 | 0 | 1 | Selvage x2, Kernel/Compiler-unreached x4 |
| Assurance.BfvSuiteMigrationBoundary | 14 | 0 | 0 | 1 | Selvage x2, Kernel/Compiler-unreached x5 |
| Assurance.BinaryTowerHeaderCodec | 7 | 0 | 0 | 0 | Selvage x2, Kernel/Compiler-unreached x2 |
| Assurance.BoundedNockRefinement | 5 | 0 | 0 | 0 | Kernel/Compiler-unreached x1 |
| Assurance.CanonicalResourceBookInvariantAudit | 0 | 0 | 0 | 0 | Kernel/Compiler-unreached x1 |
| Assurance.CredentialSignedEnvelopeEndpoint | 29 | 0 | 1 | 0 | Kernel/Compiler-unreached x1 |
| Assurance.CredentialTokenLocalEndpoint | 39 | 0 | 2 | 2 | Kernel/Compiler-unreached x1 |
| Assurance.DeclaredTurnReceipt | 8 | 0 | 0 | 1 | Selvage x2, Kernel/Compiler-unreached x2 |
| Assurance.DeployedCredentialLifecycle | 52 | 0 | 1 | 5 | Kernel/Compiler-unreached x1 |
| Assurance.DreggNetProviderConsumer | 36 | 0 | 1 | 0 | Kernel/Compiler-unreached x3 |
| Assurance.ErrorBudget | 14 | 7 | 4 | 6 | Selvage x5 |
| Assurance.ErrorBudget120 | 13 | 0 | 1 | 0 | Selvage x5 |
| Assurance.Ext6GateProofControllerAdmission | 6 | 0 | 0 | 0 | Selvage x1, Kernel/Compiler-unreached x3 |
| Assurance.Ext6GateProofDeploymentAdmission | 8 | 0 | 0 | 1 | Selvage x1, Kernel/Compiler-unreached x4 |
| Assurance.Ext6GateProofNonzeroSuiteClosure | 10 | 0 | 1 | 1 | Selvage x1, Kernel/Compiler-unreached x5 |
| Assurance.Ext6GateProofPositiveExecution | 15 | 0 | 1 | 0 | Selvage x1, Kernel/Compiler-unreached x5 |
| Assurance.ExtensibleProofCompositionGame | 29 | 0 | 0 | 2 | Selvage x1, Kernel/Compiler-unreached x3 |
| Assurance.GrainForkScopedSettlement | 26 | 0 | 0 | 0 | Selvage x1, Kernel/Compiler-unreached x1 |
| Assurance.GrainForkSettlement | 13 | 0 | 0 | 0 | Selvage x1, Kernel/Compiler-unreached x1 |
| Assurance.GrainHyperdocumentSettlementWitness | 22 | 0 | 1 | 0 | Selvage x1, Theory-unreached x1, Kernel/Compiler-unreached x3 |
| Assurance.HistoryHeadInhabitation | 12 | 0 | 0 | 13 | Selvage x2, Kernel/Compiler-unreached x2 |
| Assurance.HistoryProjectionCardinalityTooth | 1 | 0 | 0 | 0 | Selvage x2, Kernel/Compiler-unreached x2 |
| Assurance.HyperdocumentAgentOperation | 10 | 0 | 0 | 1 | Selvage x2, Theory-unreached x1, Kernel/Compiler-unreached x3 |
| Assurance.HyperdocumentAgentRuntimeScheduler | 24 | 0 | 0 | 1 | Selvage x2, Theory-unreached x3, Kernel/Compiler-unreached x10 |
| Assurance.HyperdocumentDurableInstallation | 5 | 0 | 0 | 2 | Selvage x2, Theory-unreached x1, Kernel/Compiler-unreached x4 |
| Assurance.HyperdocumentGuardedDurable | 13 | 0 | 2 | 0 | Selvage x2, Theory-unreached x1, Kernel/Compiler-unreached x4 |
| Assurance.HyperdocumentHistoryAdmission | 23 | 0 | 0 | 0 | Selvage x2, Kernel/Compiler-unreached x2 |
| Assurance.HyperdocumentIndexSyncEndpoint | 41 | 0 | 1 | 2 | Theory-unreached x1, Kernel/Compiler-unreached x2 |
| Assurance.HyperdocumentLinkClientCutover | 24 | 0 | 1 | 1 | Selvage x2, Theory-unreached x2, Kernel/Compiler-unreached x7 |
| Assurance.HyperdocumentLinkClientLocalFileCutover | 12 | 0 | 1 | 1 | Selvage x2, Theory-unreached x2, Kernel/Compiler-unreached x7 |
| Assurance.HyperdocumentLinkEndpointController | 27 | 0 | 1 | 1 | Selvage x2, Theory-unreached x2, Kernel/Compiler-unreached x7 |
| Assurance.HyperdocumentLinkFramedRecovery | 33 | 0 | 0 | 0 | Selvage x2, Theory-unreached x2, Kernel/Compiler-unreached x7 |
| Assurance.HyperdocumentLinkLocalFileStore | 19 | 0 | 1 | 0 | Selvage x2, Theory-unreached x2, Kernel/Compiler-unreached x7 |
| Assurance.HyperdocumentLinkPageDurableWeld | 38 | 0 | 1 | 0 | Theory-unreached x1, Kernel/Compiler-unreached x2 |
| Assurance.HyperdocumentLinkPublicationWitness | 37 | 1 | 1 | 1 | Theory-unreached x1, Kernel/Compiler-unreached x2 |
| Assurance.HyperdocumentLinkReopenWitness | 22 | 0 | 0 | 1 | Selvage x2, Theory-unreached x2, Kernel/Compiler-unreached x4 |
| Assurance.HyperdocumentLinkSqliteTransactionalStore | 18 | 0 | 0 | 1 | Selvage x2, Theory-unreached x2, Kernel/Compiler-unreached x7 |
| Assurance.HyperdocumentMergeDurableFinalityWitness | 29 | 0 | 0 | 1 | Selvage x2, Kernel/Compiler-unreached x6 |
| Assurance.HyperdocumentQueryDeployment | 19 | 0 | 5 | 0 | Selvage x2, Theory-unreached x2, Kernel/Compiler-unreached x4 |
| Assurance.HyperdocumentReactiveCarrierWitness | 36 | 0 | 1 | 3 | Selvage x2, Theory-unreached x3, Kernel/Compiler-unreached x5 |
| Assurance.HyperdocumentTransclusionReferenceDeployment | 18 | 0 | 0 | 1 | Selvage x2, Theory-unreached x2, Kernel/Compiler-unreached x7 |
| Assurance.HyperdocumentTwoParentHistoryWitness | 25 | 0 | 1 | 4 | Selvage x2, Kernel/Compiler-unreached x3 |
| Assurance.ItemLaw | 14 | 1 | 0 | 0 | Kernel/Compiler-unreached x1 |
| Assurance.JointPostconditionWitness | 12 | 0 | 0 | 1 | Theory-unreached x1 |
| Assurance.MixedFieldBudget | 7 | 0 | 0 | 0 | Selvage x5 |
| Assurance.MpcSealedCellExecution | 27 | 0 | 2 | 2 | Theory-unreached x2 |
| Assurance.NoteSpendConcreteCellAdapter | 24 | 0 | 1 | 1 | Selvage x1, Theory-unreached x1, Kernel/Compiler-unreached x3 |
| Assurance.NoteSpendProofControllerAdmission | 19 | 0 | 0 | 0 | Selvage x1, Kernel/Compiler-unreached x3 |
| Assurance.ObjectiveBendCommittedSource | 2 | 0 | 0 | 0 | Kernel/Compiler-unreached x2 |
| Assurance.ObjectiveBendProofSource | 4 | 0 | 0 | 0 | Kernel/Compiler-unreached x1 |
| Assurance.ObjectiveBendZkClaims | 0 | 0 | 0 | 0 | Theory-unreached x2, Kernel/Compiler-unreached x4 |
| Assurance.ObjectiveDemandPhysicalChecks | 6 | 0 | 0 | 0 | Kernel/Compiler-unreached x1 |
| Assurance.ObjectiveZkLiteralArithmetic | 4 | 0 | 0 | 0 | Kernel/Compiler-unreached x4 |
| Assurance.ObjectiveZkLiteralInstance | 45 | 0 | 0 | 0 | Kernel/Compiler-unreached x3 |
| Assurance.ObjectiveZkRefinementAudit | 7 | 0 | 1 | 5 | Kernel/Compiler-unreached x1 |
| Assurance.ObjectiveZkStepTariff | 19 | 0 | 0 | 3 | Kernel/Compiler-unreached x4 |
| Assurance.PowGrinding | 9 | 0 | 2 | 2 | Selvage x5 |
| Assurance.PrivateComputationReceiptClause | 9 | 0 | 0 | 1 | Selvage x1 |
| Assurance.PrivateEscrowSettlementJoin | 19 | 0 | 0 | 3 | Selvage x2, Theory-unreached x2, Kernel/Compiler-unreached x6 |
| Assurance.PrivateEvaluatorCustodyJoin | 4 | 0 | 0 | 0 | Kernel/Compiler-unreached x1 |
| Assurance.PrivateReceipt | 6 | 1 | 3 | 1 | Selvage x4, Kernel/Compiler-unreached x1 |
| Assurance.PrivateTurn | 4 | 0 | 1 | 1 | Selvage x4, Kernel/Compiler-unreached x1 |
| Assurance.ProofCompositionGame | 12 | 0 | 0 | 0 | Selvage x1, Kernel/Compiler-unreached x2 |
| Assurance.QuotaGcSettlementWitness | 9 | 0 | 1 | 0 | Kernel/Compiler-unreached x1 |
| Assurance.RawHistoryBcsOpenings | 13 | 3 | 1 | 2 | Selvage x6, Kernel/Compiler-unreached x4 |
| Assurance.RawHistoryCollisionBridge | 12 | 0 | 2 | 1 | Selvage x6, Kernel/Compiler-unreached x5 |
| Assurance.RawHistorySecurityPrices | 24 | 0 | 2 | 0 | Selvage x7, Kernel/Compiler-unreached x11 |
| Assurance.RawSemanticHistoryCheckpointGame | 9 | 0 | 0 | 1 | Selvage x6, Kernel/Compiler-unreached x6 |
| Assurance.ReactiveDurableSettlement | 13 | 0 | 0 | 1 | Selvage x2, Kernel/Compiler-unreached x4 |
| Assurance.ReactiveLifecycleHistory | 8 | 0 | 0 | 1 | Selvage x2, Kernel/Compiler-unreached x2 |
| Assurance.ReactiveOutboxDelivery | 18 | 0 | 1 | 2 | Selvage x2, Theory-unreached x3, Kernel/Compiler-unreached x11 |
| Assurance.ReceiptClaim | 37 | 12 | 13 | 5 | Selvage x3, Kernel/Compiler-unreached x1 |
| Assurance.ReleaseGateRouting | 35 | 4 | 3 | 7 | Kernel/Compiler-unreached x2 |
| Assurance.SameCoinGameProduct | 12 | 0 | 0 | 1 | Selvage x2, Kernel/Compiler-unreached x7 |
| Assurance.ScopedAcceptedCellEffectHistory | 25 | 0 | 0 | 0 | Selvage x1 |
| Assurance.SelvageV0 | 44 | 2 | 2 | 6 | Selvage x5, Kernel/Compiler-unreached x1 |
| Assurance.SelvageV0Manifest | 78 | 2 | 1 | 5 | Selvage x23, Kernel/Compiler-unreached x4 |
| Assurance.SemanticAdditiveFriCheckpoint | 13 | 0 | 0 | 0 | Selvage x4, Kernel/Compiler-unreached x3 |
| Assurance.SemanticHistoryAccumulator | 15 | 0 | 0 | 0 | Selvage x2, Kernel/Compiler-unreached x2 |
| Assurance.SemanticHistoryBcsClaimProjection | 21 | 0 | 0 | 0 | Selvage x5, Kernel/Compiler-unreached x3 |
| Assurance.SemanticHistoryBcsGame | 28 | 0 | 0 | 3 | Selvage x6, Kernel/Compiler-unreached x4 |
| Assurance.SemanticHistoryFamily | 11 | 0 | 0 | 0 | Selvage x2, Kernel/Compiler-unreached x2 |
| Assurance.SemanticHistoryFamilyInstances | 0 | 0 | 0 | 0 | Selvage x2, Kernel/Compiler-unreached x2 |
| Assurance.SemanticHistoryRecursiveAir | 8 | 0 | 0 | 0 | Selvage x2, Kernel/Compiler-unreached x3 |
| Assurance.SemanticHistoryStraightlinePcs | 9 | 0 | 0 | 0 | Selvage x4, Kernel/Compiler-unreached x2 |
| Assurance.SemanticHistoryWARPAdditiveJoin | 11 | 0 | 0 | 0 | Selvage x5, Kernel/Compiler-unreached x3 |
| Assurance.SemanticReceiptRelation | 14 | 0 | 2 | 0 | Selvage x1 |
| Assurance.SemanticReceiptRuntimeCodec | 20 | 0 | 0 | 0 | Selvage x1, Kernel/Compiler-unreached x1 |
| Assurance.SemanticTurnReceipt | 8 | 0 | 1 | 0 | Selvage x1 |
| Assurance.SheetLaw | 36 | 2 | 0 | 1 | Kernel/Compiler-unreached x1 |
| Assurance.SpartanR1CS | 32 | 2 | 10 | 8 | Selvage x7, Theory-unreached x1 |
| Assurance.Tower256AdditiveFriCanonicalExecutionGame | 8 | 0 | 0 | 0 | Selvage x1, Kernel/Compiler-unreached x4 |
| Assurance.Tower256AdditiveFriRawAdmission | 5 | 0 | 0 | 0 | Selvage x1, Kernel/Compiler-unreached x3 |
| Assurance.Tower256LogupControllerAdmission | 5 | 0 | 0 | 0 | Selvage x1, Kernel/Compiler-unreached x3 |
| Assurance.Tower256LogupExtensionDeploymentAdmission | 6 | 0 | 0 | 0 | Selvage x1, Kernel/Compiler-unreached x4 |
| Assurance.Tower256MerkleCardinalityCore | 8 | 0 | 0 | 0 | Kernel/Compiler-unreached x1 |
| Assurance.Tower256RawHistoryCshakeTrace | 11 | 0 | 0 | 0 | Selvage x9, Kernel/Compiler-unreached x11 |
| Assurance.Tower256RawHistoryFsController | 7 | 0 | 0 | 0 | Selvage x8, Kernel/Compiler-unreached x6 |
| Assurance.Tower256RawHistoryFsExecution | 4 | 0 | 0 | 0 | Selvage x9, Kernel/Compiler-unreached x11 |
| Assurance.Tower256RawSemanticHistoryCanonicalGame | 6 | 0 | 0 | 2 | Selvage x6, Kernel/Compiler-unreached x7 |
| Assurance.TransclusionBacklinkHistory | 28 | 0 | 0 | 0 | Selvage x2, Kernel/Compiler-unreached x2 |
| Assurance.TwistMemoryFingerprintJoin | 9 | 0 | 7 | 3 | Selvage x1, Kernel/Compiler-unreached x1 |
| Assurance.TypedCellHyperedgeHistoryBinding | 5 | 0 | 0 | 0 | Selvage x2, Kernel/Compiler-unreached x2 |
| Assurance.TypedCellHyperedgeReceipt | 6 | 0 | 0 | 0 | Selvage x2, Kernel/Compiler-unreached x2 |
| Assurance.ZkmlLowRankUpdate | 45 | 0 | 7 | 0 | Selvage x5, Theory-unreached x1 |
| Assurance.ZkmlMatmulAuditTurn | 19 | 0 | 0 | 0 | Selvage x8, Theory-unreached x1 |
| Assurance.ZkmlMatmulBaseFold | 4 | 0 | 0 | 0 | Selvage x7, Theory-unreached x1 |
| Assurance.ZkmlMatmulChecker | 7 | 0 | 0 | 0 | Selvage x4, Theory-unreached x1 |
| Assurance.ZkmlMatmulCommitment | 6 | 0 | 0 | 1 | Selvage x6, Theory-unreached x1 |
| Assurance.ZkmlMatmulConformance | 13 | 0 | 3 | 0 | Selvage x4, Theory-unreached x1, Kernel/Compiler-unreached x1 |
| Assurance.ZkmlMatmulFramedWal | 17 | 0 | 1 | 0 | Selvage x8, Theory-unreached x1, Kernel/Compiler-unreached x1 |
| Assurance.ZkmlMatmulSuccinctChecker | 38 | 0 | 2 | 0 | Selvage x7, Theory-unreached x1 |
| Assurance.ZkmlMatmulSuiteRegistry | 3 | 0 | 0 | 0 | Selvage x4, Theory-unreached x1 |
| Assurance.ZkmlMatmulSumcheck | 20 | 0 | 1 | 0 | Selvage x4, Theory-unreached x1 |

### DEPLOYED-SUBJECT

| module | theorems | sat | teeth | inhab | subject |
|---|---|---|---|---|---|
| Assurance.CapabilityRevocationAudit | 12 | 0 | 2 | 1 | Host-reached x1 |
| Assurance.CredentialDelegationLineageAudit | 0 | 0 | 0 | 0 | Host-reached x2 |
| Assurance.CredentialDelegationLineageWitness | 17 | 0 | 0 | 0 | Host-reached x2 |
| Assurance.CredentialFoundationMigrationAudit | 0 | 0 | 0 | 0 | Host-reached x1 |
| Assurance.CredentialSourceAdmissionAudit | 0 | 0 | 0 | 0 | Host-reached x1 |
| Assurance.HyperdocumentFinalizedDomainCrawler | 40 | 0 | 1 | 1 | Host-reached x1 |
| Assurance.KeyPreRotationAudit | 5 | 0 | 1 | 0 | Host-reached x1 |
| Assurance.NativeObservationAudit | 0 | 0 | 0 | 0 | Host-reached x1 |
| Assurance.NativeProviderHistoryAdmission | 28 | 0 | 0 | 0 | Host-reached x2 |
| Assurance.NoteSpendCoreAcceptedCellEffect | 4 | 0 | 0 | 1 | Host-reached x2 |
| Assurance.ObjectiveZkTraceDisclosure | 7 | 5 | 0 | 0 | Host-reached x1 |
| Assurance.RenounceAudit | 10 | 0 | 0 | 0 | Host-reached x1 |
| Assurance.ResourceMoneyOperationDomainAudit | 4 | 0 | 0 | 0 | Host-reached x2 |
| Assurance.TwoRegimeQueryBudget | 40 | 0 | 1 | 4 | Host-reached x0 |
| Assurance.WorldPrototypeConstructionChecks | 4 | 0 | 0 | 0 | Host-reached x3 |

### DEPLOYED

| module | theorems | sat | teeth | inhab | subject |
|---|---|---|---|---|---|
| Assurance.EvaluatorAudit | 3 | 0 | 0 | 0 | Kernel/Compiler (Host-reached) |
| Assurance.StoryLaw | 43 | 0 | 0 | 0 | Kernel/Compiler (Host-reached) |

## Kernel-subject research modules

The 20 RESEARCH modules whose Assurance subject is Host-unreached Kernel/Compiler code only (no direct Selvage or Theory-unreached subject). One row per SUBJECT module. "Importers" are non-Assurance modules importing it; `Kernel`/`Compiler` are the research umbrella roots; `ResearchWip` is the research scratch root. No plan names any of these (greps of `DEMO-PREFIX-2026-10-26.md`, `BACKLOG-2026-10-27.md`, `DEMO-EXPERIENCE-2026-10-27.md` over the module names find none; surfaces below are named by what they serve). Verdicts: RESCUE (one wiring step), TWIN (duplicates a live module), DEAD (no named surface, no live importer; delete is a decision for ember, not taken here), ZK-CARGO (a fourth class the evidence forced: the zkML/MPC/FRI tower C2 already moves; not dead, not a Host surface).

| subject | Assurance files about it | importers outside Assurance | verdict |
|---|---|---|---|
| `Compiler.DeployedCellRegistry` | CredentialSignedEnvelopeEndpoint, DeployedCredentialLifecycle, CredentialTokenLocalEndpoint | `Compiler`, `Kernel.ConsentAnchor` | TWIN of `Compiler.CanonicalCellRegistry` (Host-reached): its own docstring says "The unified receiving path uses `Compiler.CanonicalCellRegistry`; it does not select this witness as a production registry configuration." The three credential-lifecycle Assurance files are about the exhibit, not the registry the Host runs. |
| `Kernel.LawHistory` | ItemLaw, SheetLaw (and StoryLaw, in Deployed) | `Kernel` | RESCUE. Surface: the story room (DEMO-EXPERIENCE row 11, which cites `sealed_story_scene_monotone`); item and sheet laws share it ("Sheet, item and story laws use this one kernel-level contract"). Step: have the Host's story-room admission path import `Kernel.LawHistory` (it already imports its dependencies `LawView`, `MultiCellHyperedge`, `DeclaredResourceController`), so the demo's cited theorem is about run code. |
| `Kernel.NativeHostBookInvariant` | CanonicalResourceBookInvariantAudit | `Kernel` | RESCUE. It extends `Kernel.NativeHostGenesis` (Host-reached) with "genesis and actual resource patches preserve account support". Step: import it from the Host genesis path (`Host/SourceAgreementBirth`, which imports NativeHostGenesis). |
| `Kernel.ReplicatedSettlementFinality` | DreggNetProviderConsumer | `Kernel`, `Kernel.AuthenticatedSettlementFinality`, `Kernel.FinalityGate`, `Kernel.FinalityLiveness` (all Host-unreached) | RESCUE. Surface: the second node (DEMO-EXPERIENCE A9; `docs/DISTRIBUTED-DESIGN.md` consumes it: "consumed, not replaced"). Step: the second-node lane imports `Kernel.FinalityGate` (the `@[export]` fail-closed finality decider built on it) into the Host. |
| `Kernel.CanonicalEscrowMarket` | DreggNetProviderConsumer | `Kernel`, `Kernel.PrivateEscrowSettlement` | DEAD (unplanned). Public order escrow over `Kernel.AuthorizedResourceCharge` (also Host-unreached). Overlaps conceptually with the live compute-market path (`Kernel.Job`, Pay*/purse) but declares itself a consumer of the canonical resource kernel, so TWIN is not established without a code read. |
| `Kernel.ProviderExecutionLease` | DreggNetProviderConsumer | `Kernel` | DEAD (unplanned); same family and same TWIN-suspect note against `Kernel.Job`. |
| `Kernel.PrivateEscrowSettlement` | ReleaseGateRouting | `Kernel` | DEAD (unplanned); private market order, parameterized by an Assurance-supplied proof `Source`; belongs with the `private-backend` move if kept. |
| `Kernel.QuotaGcSettlement` | QuotaGcSettlementWitness | `Kernel` | DEAD (unplanned). Quota admission and reachability-safe reclamation; no live quota path imports it. |
| `Compiler.BendCommittedUnroll` | ObjectiveZkStepTariff, BendArithmeticQualification, ObjectiveBendCommittedSource, ObjectiveZkLiteralArithmetic | `ResearchWip` | ZK-CARGO (`docs/ZK.md:169`, committed Bend run soundness) |
| `Compiler.BendTraceSound` | BendArithmeticQualification | `BendCommittedNetwork`, `BendUnrolledDirect`, `BendUnrolledIR2`, `ResearchWip` | ZK-CARGO |
| `Compiler.BendUnrolledIR2` | BendArithmeticQualification | `ResearchWip` | ZK-CARGO |
| `Compiler.ObliviousUnrollSemantics` | BendArithmeticQualification, ObjectiveBendCommittedSource, ObjectiveZkStepTariff, ObjectiveZkLiteralInstance, ObjectiveZkLiteralArithmetic, ObjectiveZkRefinementAudit, ObjectiveBendProofSource | `BendCommittedRun`, `BendUnrolledDirect`, `BendUnrolledIR2`, `ObliviousUnrollChecks`, `ResearchWip` | ZK-CARGO |
| `Compiler.ObliviousUnrollChecks` | BendArithmeticQualification | `ResearchWip` | ZK-CARGO |
| `Compiler.ObjectiveDemandPhysical` | ObjectiveZkStepTariff, ObjectiveZkLiteralInstance, ObjectiveZkLiteralArithmetic, ObjectiveDemandPhysicalChecks | `ResearchWip` | ZK-CARGO (`docs/ZK.md:205`) |
| `Compiler.ObjectiveDemandStateEquality` | ObjectiveZkStepTariff, ObjectiveZkLiteralInstance, ObjectiveZkLiteralArithmetic | `ObjectiveDemandPhysical`, `ResearchWip` | ZK-CARGO |
| `Compiler.ObjectiveProofContext` | BendArithmeticQualification | `BendCommitmentFrame`, `ResearchWip` | ZK-CARGO |
| `Compiler.BoundedNockNetwork` | BoundedNockRefinement | `ResearchWip` | ZK-CARGO (bounded Nock circuit for the MPC programme; "does not yet lower the full Nock controller") |
| `Compiler.ObliviousEvaluator` | PrivateEvaluatorCustodyJoin | `Compiler`, `BoundedNockEntry`, `PrivateWorldIR` | ZK-CARGO (private-backend MPC programme, `docs/review/2026-10-26-native-crates/private-backend--B-mpc-protocols.md`) |
| `Compiler.CommittedTerminalFiatShamir` | ReleaseGateRouting | `Compiler` | ZK-CARGO: its import closure contains 17 Selvage modules, so C2's "+ importers" rule moves it |
| `Compiler.Tower256AdditiveFriController` | Tower256MerkleCardinalityCore | `Compiler`, `Tower256AdditiveFriRawController` | ZK-CARGO: closure contains 49 Selvage modules; `docs/SELVAGE-COMPLETE.md` places it in the proof system |

Counts per verdict over the 20 subjects: RESCUE 3, TWIN 1, DEAD 4, ZK-CARGO 12. Two of the 20 DEAD-or-twin rows carry no certainty beyond docstrings and importers: the escrow/lease family should get a code read against `Kernel.Job` and the Pay* path before anything is deleted.

Why the 12 ZK-CARGO rows are classed RESEARCH-by-Kernel/Compiler-subject and not Selvage-subject: the first census read Assurance-only imports; these subjects reach Selvage (or the Bend/MPC tower) only one hop below, through Compiler modules. A transitive reading would put them with the 100 Selvage-touching modules.

## Door 11

Door 11 of the tour (`docs/DEMO-EXPERIENCE-2026-10-27.md`, "a story room ... one impossible move refused beside the theorem `sealed_story_scene_monotone`"). Read-only trace, nothing built; every claim below is from source text at this commit.

**(1) What admits a story move today.** `native/resource-client/src/story.rs` (`player_clauses`, `player_law`, `table_sealed_law`) generates one `Pred` law per sealed table and the client installs it on each player's cell; a write is then admitted by the Host's generic declared-resource controller: `Kernel.DeclaredResourceController.step` builds the `PolicyStepContext` (old/new states from `projectWithCommon` over the physical stores) and `Compiler.ComposedPolicyAdmission` evaluates the authenticated effective law on it. There is no story-specific Host code. All of that is in the `Host.Main` closure.

**(2) What the theorems are about.** Two layers in `Assurance/StoryLaw.lean`:
- Per step, `kernel_story_step` (and `law_step`) is about the Host's own objects: a `CheckedLeg` of the controller and `(step prepared tuple incidence).newState`; conclusion `Step t S newState` (player is the subject, turn delta 1, scene stays or follows a table edge). It reaches the Host function through `Kernel.LawHistory.checked_leg_component_eval`.
- Over histories, `sealed_story_scene_monotone` and `no_rewind` are about `Kernel.LawHistory.Accepted (law t S) v ts`: a list of `LawView.Turn`s each judged by `LawView.admits`, which evaluates the law on `LawView.view` (slots built from `Values` by `DeclaredResourceProjection.scalarSlots`). That is a parallel model of a cell's write history. No theorem in the tree identifies `LawView.view t pre post` with the controller's `step.oldState/newState` (the Host builds those from physical stores, not from `Values`), and `Accepted` is not constructed from `CheckedLeg`s or the CAS chain. The `LawHistory` comment states the chaining assumption in prose ("the durable CAS is what makes each step's pre the previous post").
- Two further gaps: nothing in the Host calls `checkInstalled`/`checkActiveComponent` (the `StoryInstalled` premise of `kernel_story_step` is never discharged by Host code), and the client-generated law equals the Lean `law taleTable` only through the embedded text checked by `scripts/gen-storylaw.py --check`, which no gate script runs (grep: no reference in `scripts/*.sh` or `scripts/pipeline`).

So the history theorem is a twin-model result, not a statement about the run function; the per-step theorem is about the run function but is conditional on `StoryInstalled`.

**(3) The repair.**
- (b) is not the repair. `Kernel.LawHistory` imports only `LawView`, `MultiCellHyperedge`, `DeclaredResourceController`, all already Host-reached, so importing it grows the closure by exactly one module (ceiling 776 to 777) and changes no receiver; `Accepted` is a `Prop`, there is no admission function in it to route through. It would turn the label green without touching the gap.
- (a) is the honest repair and is more than a few hundred lines of uncertain proof work, so it is stated here, not started: a new theorem `story_history_monotone` over a list of `CheckedLeg`s, with the chain premise stated on the controller's states (leg i+1's old-state `before` slots equal leg i's new-state `after` slots; i.e. the CAS chain, as a hypothesis the receiver discharges), concluding the whole-history monotone/no-skip/no-rewind property directly from `kernel_story_step` per leg. Statement-first: the premise must be satisfiable (a two-leg witness on `taleTable` built by `decide`/`rfl` over the embedded law) and have teeth (a skipped-scene or repeated-turn chain refuted). Independent of that, the `StoryInstalled` premise needs the receiver to run `checkInstalled` (or a derived-path lemma that the Host's resolved graph contains the sealed law), and `gen-storylaw.py --check` needs a gate row.
- (c), what door 11 may say now: "Each write the Host admits on a sealed player's cell is the player's, advances the turn by exactly one, and leaves the scene or follows one table edge (`kernel_story_step`, about the controller's checked leg, given that the cell carries the sealed law). That no sequence of such writes can skip a scene or rewind (`sealed_story_scene_monotone`) is proved over a model of cell history that is not yet connected to the controller's step by a theorem." Do not put `sealed_story_scene_monotone` beside the refusal as "the theorem the Host runs".

### Door 11, option (a) landed (statement, poles and proof)

`Assurance/StoryHistory.lean` (rooted by `Assurance.lean` only; not in `Deployed`, not in the Host closure; no `sorry`; elaborated with `lake env lean` on a cloned warm tree, axioms pinned). `story_history_monotone` is proved over a list of states each `Realized` (the `newState` of the controller's `step` for a `CheckedLeg` that is a write with `StoryInstalled`), via `kernel_story_step`: every leg is the player's, moves the scene along a table edge or not at all, raises the turn by one, and the last leg ends at turn `k + length`. Poles on the tale, all proved: `history_satisfiable` (a four-leg play-through meets every premise), `skip_not_step`, `repeat_not_step`, `rewind_not_chained`, and `unchained_breaks_conclusion` (dropping `Chained` is load-bearing).

Premises that remain named residuals (docstring R1-R3), so the sentence for door 11 gains the theorem only with these stated: R1 `Coherent` (the projection fills `delta` as `after - before`, true of `scalarSlots`, not yet connected through `projectWithCommon`); R2 `Chained` for the receiver's real sequence of accepted writes, and the Host discharging `StoryInstalled`; R3 a concrete `CheckedLeg` on the tale inhabiting `Realized` (the satisfiable pole inhabits every premise except that one, using `Step`, which `Realized` implies). The `gen-storylaw` merge-gate row now holds the Rust-generated law to the embed.

### Door 11, R1 discharged; R2a stated

R1 is proved (`Assurance/StoryHistory.lean`, `realized_scalar`, `coherent_of_step`): `story_history_monotone` no longer takes `Coherent` as a premise. `Realized` gained one premise, that the primary target's payload is scalar, and the controller's own `newState` is shown to answer each `resource/field/N/{before,after,delta}` key from `scalarSlots` of the cell's before and after stores (`local_field_exact`, `participant_field`, `scalar_before/after/delta`; the common, byte and joint blocks hold no such key, by the tenth-character test). Elaborated on the Mac warm tree, no `sorry`, axioms unchanged.

R2a, the Host discharging `StoryInstalled`: no Host-reached code runs `Kernel.LawHistory.checkActiveComponent` or `StoryLaw.checkInstalled` (grep over Host, Kernel, Compiler: only the definitions). The call the receiver must make is `checkActiveComponent resolved (law t S)` on the `ComposedPolicyAdmission.PreparedLaw` it already builds (`Compiler/ComposedPolicyAdmission.lean:137,148`), refusing when it returns `none`. It cannot be written today: `law`, `Table` and `StoryInstalled` live in `Assurance/StoryLaw.lean`, and `scripts/check-import-boundary.sh` forbids the Host from importing Assurance. So the one structural step is to move the table-to-law generator (`Table`, `law`, `clauses`, section 1 and 2 of `StoryLaw.lean`, no other dependencies) down into `Kernel` (for example `Kernel/StoryLaw.lean`), leaving the theorems in Assurance; the receiver then calls `checkActiveComponent` with `law t S` for the table it loaded. That is the platform lane's receiver change.

**Door 11's sentence as it stands:** "Every write the Host admits on a sealed story cell is the player's, advances the turn by exactly one, and leaves the scene or follows one table edge (`kernel_story_step`); and for any chain of such writes that link scene to scene and turn to turn (the durable compare-and-swap order), the scene never skips an edge and the turn never rewinds, ending at the starting turn plus the number of writes (`story_history_monotone`, proved over the controller's own step state). Both hold of cells that carry the sealed law; that the Host checks the sealed law is installed before relying on them is not yet wired."

**Moved (Kernel/StoryLaw.lean).** The table-to-law generator (`Edge`, `Table`, `law` and its clauses, the generated tale embed with its `rfl`, `StoryInstalled`, `checkInstalled`) now lives in `Kernel/StoryLaw.lean`, rooted by `Kernel.lean`, importing `Kernel.LawHistory` only; `Assurance/StoryLaw.lean` and `StoryHistory.lean` import it with every theorem statement and axiom pin unchanged. `scripts/gen-storylaw.py` and the `gen-storylaw` gate row point at the new file (red on a one-character edit of the embed, green after reverting). The module is in no Host import yet.

**Note for the platform lane (the one-call receiver change).** In the receiver that already builds the `ComposedPolicyAdmission.PreparedLaw` for a story player's write (`resolved`), import `Kernel.StoryLaw` and, before admitting, call

    Minidregg.Kernel.LawHistory.checkActiveComponent resolved (Minidregg.Kernel.StoryLaw.law t S)

(equivalently `Kernel.StoryLaw.checkInstalled t S tuple incidence resolved`), where `t` is the sealed table the receiver loaded and `S` the player's subject; refuse the write on `none`. A `some` is exactly the `StoryInstalled` premise of `kernel_story_step` and of `Realized`. Expected Host closure growth: `Kernel.StoryLaw` (+1 module, ceiling 776 to 777 plus whatever else main has added; at this branch's rebase onto origin/main the closure already measures 777 independent of this move, so reconcile the ceiling with `scripts/check-host-closure.sh --update`).
