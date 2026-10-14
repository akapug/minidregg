/-
# TokenCensus.Table — the census of private constructors

The table `TokenCensus` checks (see `TokenCensus.lean` for the four checks). It is a
Lean module, not a loose text file, so that Lake rebuilds the census whenever a row
changes. One row per private constructor of a package type:

    constructor | home module | kind | layer | note
-/

namespace Minidregg.TokenCensus

/-- The census table, one row per line; `#` starts a comment line. -/
def table : String := "
# Token census: every private constructor of a package type (TokenCensus.lean checks this table).
# Columns:  constructor | home module | kind | layer | note
#   kind   evidence       a theorem`s `only X mints this` story relies on the constructor's privacy
#          encapsulation  the privacy hides a representation; no guarantee rests on who builds it
#   layer  L1 <theorem>   the type carries the proposition it asserts: <theorem> states the guarantee
#                         for EVERY inhabitant, so a forgery must prove it (unforgeable as a theorem)
#          L2             opaque: the guarantee rests on a runtime fact no proof can express (an oracle
#                         or IO verdict) or is not yet stated as a proposition; protected only by
#                         TokenCensus check 1 (no foreign mint) and its per-row plant
# The note records the field census at classification (P proof fields / D data fields) and, where
# reviewed, why the row has its kind and layer.
Minidregg.Assurance.ReactiveLifecycleHistory.Broken.mk | Assurance.ReactiveLifecycleHistory | evidence | L1 Minidregg.Assurance.ReactiveLifecycleHistory.Broken.authorizedBreak | rules.Breaks spec.cancelRequest reason entry.context entry.claim: the retained authenticated history entry is recognized by the Lean rules as a break under the promise's exact eager cancellation request
Minidregg.Assurance.ReactiveLifecycleHistory.Expired.mk | Assurance.ReactiveLifecycleHistory | evidence | L1 Minidregg.Assurance.ReactiveLifecycleHistory.Expired.afterDeadline | spec.deadline < rules.observedHeight entry.context: the canonically projected height of the retained authenticated entry is strictly after the promise's deadline
Minidregg.Assurance.ReactiveLifecycleHistory.Finalized.mk | Assurance.ReactiveLifecycleHistory | evidence | L1 Minidregg.Assurance.ReactiveLifecycleHistory.Finalized.sound | 0-proof composite of Reaction rules spec and AcceptedCellEffect family spec.request spec.pre spec.declaration (interpretAdvice advice); the new theorem states the woken entry matches spec.condition, the late advice is allowed by rules for that entry, and the accepted effect's post satisfies the family postcondition at spec.declaration and the interpreted advice
Minidregg.Assurance.ReactiveLifecycleHistory.Notification.mk | Assurance.ReactiveLifecycleHistory | evidence | L1 Minidregg.Assurance.ReactiveLifecycleHistory.Notification.conditionHolds | rules.Matches spec.condition entry.context entry.claim: the retained authenticated committed entry satisfies the promise's declared condition (siblings withinDeadline and stateReady tie it to spec.deadline and spec.pre.root)
Minidregg.Assurance.ReactiveLifecycleHistory.Reaction.mk | Assurance.ReactiveLifecycleHistory | evidence | L1 Minidregg.Assurance.ReactiveLifecycleHistory.Reaction.adviceAllowed | rules.AdviceAllowed spec.condition notification.entry.context notification.entry.claim (spec.encodeAdvice advice): the canonical bytes of the late advice are admitted by the rules for the same authenticated entry that woke the promise under spec.condition
Minidregg.Assurance.SemanticHistoryAccumulator.VerifiedHistoryHead.mk | Assurance.SemanticHistoryAccumulator | evidence | L1 Minidregg.Assurance.SemanticHistoryAccumulator.VerifiedHistoryHead.linked | HistoryChain (under the section indices manifest registry clauseEvidence errorId headerCells C S) holds of entries: genesis has sequence 0 and no predecessor, each successor names the S-receipt root of the previous entry, same history domain, and pre-root = previous post-root. Caveat: no field ties accumulator/foldedWord to entries (only satisfies C and rootBound S), so the fold over the entries is guaranteed only by start/append, not carried
Minidregg.Assurance.SemanticHistoryBcsGame.HistoryBcsGameSecurity.mk | Assurance.SemanticHistoryBcsGame | evidence | L1 Minidregg.Assurance.SemanticHistoryBcsGame.HistoryBcsGameSecurity.goodEvents | the shared coin omega lies in ledger's good event for historyPcs, commitmentBinding and oracleTransport (the type's three common-coin good events, previously three separate fields). Note: head/openings/domain are phantom in every field; the instance is tied only by the type, by design (math is separate)
Minidregg.Assurance.SemanticHistoryFamily.VerifiedHistoryHead.mk | Assurance.SemanticHistoryFamily | evidence | L1 Minidregg.Assurance.SemanticHistoryFamily.VerifiedHistoryHead.linked | HistoryChain holds of entries under the family/S indices: genesis sequence 0 with no predecessor, each successor names the S-receipt root of its predecessor, same history domain, state continuity; the Type-valued foldTrace (not a Prop, so not the witness) additionally ties accumulator/foldedWord to exactly these entries
Minidregg.Assurance.TransclusionBacklinkHistory.AppliedEffect.mk | Assurance.TransclusionBacklinkHistory | evidence | L1 Minidregg.Assurance.TransclusionBacklinkHistory.AppliedEffect.referenceArgumentExact | request.argsDigest = ref.referenceRoot: the accepted effect's exact request (the AcceptedCellEffect index) commits the durable reference root of the ref index whose source the retained Observation ref authenticates
Minidregg.Assurance.TransclusionBacklinkHistory.LinkEvent.mk | Assurance.TransclusionBacklinkHistory | evidence | L1 Minidregg.Assurance.TransclusionBacklinkHistory.LinkEvent.sound | the retained entry is committed with semantic relation id = linkRelationId, the event opening is an exact opening of that entry's word, and its cells are encoding.cells target (both indices named; previously spread over four fields). Inserted inside namespace LinkEvent after its Event notation, so the declared short name is sound. Note forwardLink is a public mk-equivalent taking every proof
Minidregg.Assurance.TransclusionBacklinkHistory.Observation.mk | Assurance.TransclusionBacklinkHistory | evidence | L1 Minidregg.Assurance.TransclusionBacklinkHistory.Observation.historyEntryExact | ref.source.historyEntryRoot = entry.receiptRoot SCommit: the retained committed entry is exactly the history entry the ref names (siblings bind domain, object, post-root and ref.opening.Exact entry.word; disclosure_allowed only restates a fact about ref alone)
Minidregg.Compiler.CanonicalPolicyAdmission.PolicyStepContext.mk | Compiler.CanonicalPolicyAdmission | evidence | L2 | defect cv 01a13c42-48cc: no proof field and no index: preStateRoot, effectsDigest, semantics, oldState, newState are bare data; the public PolicyStepContext.ofCandidate takes caller-chosen (project : Store L → State) and (semantics : Digest), so oldState := project pre.logical, newState := project candidate.post.logical and semantics are free (a constant project forges any states); the 'only from a source-derived candidate' story is not carried; mints: PolicyStepContext.ofPreparedTuple (projects a real prepared tuple; review pending: the tuple is not itself a census token)
Minidregg.Compiler.CarriedApplicationProvenance.CarriedIssue.mk | Compiler.CarriedApplicationProvenance | evidence | L1 Minidregg.Compiler.CarriedApplicationProvenance.CarriedIssue.current_record_exact | current.image.accepted[issue.index]? = some issue.record: the carried issue record is present at its index in the current durable image (siblings: sourcePresent in custody's audited source, beforeCut < cut height, eventExact decoding, originalExact vs the MAC-bound source head)
Minidregg.Compiler.CarriedDispatchProvenance.CarriedDispatchIssue.mk | Compiler.CarriedDispatchProvenance | evidence | L1 Minidregg.Compiler.CarriedDispatchProvenance.CarriedDispatchIssue.carried | the wrapped CarriedIssue config current's record is at its index in the current image and raw is exactly the decode of that issue's grain ingress (own proof fields rawExact/sourceCanonical name no index; the existing theorem descriptor_bytes_opaque is rfl on a def)
Minidregg.Compiler.CarriedSegmentIO.AuditedSource.mk | Compiler.CarriedSegmentIO | evidence | L2 | defect cv 01a13c42-48fe: no index and no proof field: capsule, durable, auditTranscript : String are bare data; every check in auditSource (profile output equal, audit exit code, audited head line, seed identity = capsule genesis) is an IO/Bool test whose result is discarded, so nothing ties durable to capsule
Minidregg.Compiler.CarriedSegmentIO.Authorized.mk | Compiler.CarriedSegmentIO | evidence | L2 | defect cv 01a13c42-493e: 0 proof fields: prepared : Prepared config and edge : EdgeSeal; the operator signature verdict (CredentialSignatureIO.verify ... = .ok true) and checkPublic in authorizePrepared are discarded, and no field relates edge to prepared (edge.body, roots) or to config
Minidregg.Compiler.CarriedSegmentIO.Prepared.mk | Compiler.CarriedSegmentIO | evidence | L2 | defect cv 01a13c42-498e: 0 proof fields: source, body, changes, target : NativeHost.Opened config; prepareDerived's checks (body.sourceCapsule != source.capsule.pins, identity != body.target, target = buildTarget ... source.durable body changes) are Bool tests discarded; only the nested Opened token mentions config, nothing binds body/changes/source to target
Minidregg.Compiler.CarriedSegmentIO.PreservedPrefix.mk | Compiler.CarriedSegmentIO | evidence | L1 Minidregg.Compiler.CarriedSegmentIO.PreservedPrefix.prefixExact | current.prefixImage start.durable.height = start.durable.image: the current durable image (index) extends exactly the image of the config-indexed Opened carry start. Caveat: source and edge (the audited origin and authorizing signature) are not bound by any field
Minidregg.Compiler.CredentialAuthorityDomainReceiver.Loaded.mk | Compiler.CredentialAuthorityDomainReceiver | evidence | L1 Minidregg.Compiler.CredentialAuthorityDomainReceiver.Loaded.observed | physical.canonicalBytes (cellIdOf deployment) = cellBytes snapshot.cell: the loaded authority cell is exactly the bytes at the deployment's pinned cell id in the physical snapshot (siblings pin domain to deployment.domain, revision to clockOf physical, spent to spentOf deployment.domain physical)
Minidregg.Compiler.CredentialAuthorityDomainReceiver.LoadedDirectory.mk | Compiler.CredentialAuthorityDomainReceiver | evidence | L1 Minidregg.Compiler.CredentialAuthorityDomainReceiver.LoadedDirectory.bytes_exact | for every identifier, the lifecycle bytes of directory's view equal durable.snapshot.canonicalBytes at that id (from decoded : DirectoryImage.decode registry (directoryRows durable) = some directory): the directory is the complete decode of the durable index
Minidregg.Compiler.CredentialAuthorityDomainReceiver.PreparedGrantBatch.mk | Compiler.CredentialAuthorityDomainReceiver | evidence | L1 Minidregg.Compiler.CredentialAuthorityDomainReceiver.PreparedGrantBatch.batchFresh | 0-proof composite whose mode : BatchEvidence loaded.snapshot.cell descriptor is indexed by the type's loaded/descriptor; the theorem states the descriptor's slots and grant ids are distinct and every parent row is absent in the loaded authority cell
Minidregg.Compiler.CredentialAuthorityServed.ServedAuthority.mk | Compiler.CredentialAuthorityServed | evidence | L1 Minidregg.Compiler.CredentialAuthorityServed.ServedAuthority.observed | served.canonicalBytes (cellIdOf deployment) = cellBytes cell: the served authority cell is exactly the bytes the served state holds at the deployment's pinned authority cell id
Minidregg.Compiler.CredentialAuthorityServed.ServedDirectory.mk | Compiler.CredentialAuthorityServed | evidence | L1 Minidregg.Compiler.CredentialAuthorityServed.ServedDirectory.bytes_exact | for every identifier, the lifecycle bytes of directory's view equal served.canonicalBytes at that id (from decoded : DirectoryImage.decode registry (servedRows served) = some directory): the directory is the complete decode of the served state
Minidregg.Compiler.CredentialSignatureAdmission.CheckedSignature.mk | Compiler.CredentialSignatureAdmission | evidence | L1 Minidregg.Compiler.CredentialSignatureAdmission.CheckedSignature.admittedFrom | prepared is prepare snapshot nullifier request envelopeBytes and admission is the controller's finish of it with verdict true. Caveat: the oracle verdict itself is a runtime fact; `Except.ok true` is a literal, so no Lean statement says the signature verified (no field records the voucher either)
Minidregg.Compiler.CredentialSignatureAdmission.ReceiverSignature.mk | Compiler.CredentialSignatureAdmission | evidence | L2 | defect cv 01a13c42-49c1: no index and no proof field: source and claim are bare data; that claim is in a Receiver's vouchers is stated only about the producers (Received.find?_some/signed?_some), never retained in the value, so a holder learns nothing from the type
Minidregg.Compiler.DurableHistory.Head.mk | Compiler.DurableHistory | evidence | L1 Minidregg.Compiler.DurableHistory.Head.bound | either the empty-log head of store (height 0, chain = store.logStart, frontier [], empty index root) or some tag verifies under store.key for (height, chain, frontierDigest, indexRoot) with result root. Caveat: in the genesis disjunct root is free, and the public def Head.genesis store root mints a height-0 head for any store and root with no check (the replay-bypass the note warns of rests on Layer-2 audit only); mints: Head.genesis
Minidregg.Compiler.DurableServed.Served.mk | Compiler.DurableServed | evidence | L2 | defect cv 01a13c42-49fa: no field mentions the store index: the only proofs are outsideAbsent (cells outside cellIds hold absentBytes) and cellIdsNodup, internal enumeration consistency; height, chain and worldRoot are free data, and the public ofLoaded mints Served rootBytes store for any store from any Loaded given store.logStart = loaded.logStart (not retained)
Minidregg.Compiler.GenericSimplexIO.VerifiedCommit.mk | Compiler.GenericSimplexIO | evidence | L1 Minidregg.Compiler.GenericSimplexIO.VerifiedCommit.quorum_size | expected.config.quorum ≤ v.signerIds.length: the certificate carries at least the expected context's quorum of signers (siblings: certificate.context = expected, distinct signers < expected.config.parties). Caveat: the ML-DSA signature checks themselves (verifyCertificate) are IO-only and not retained
Minidregg.Compiler.GrainResourceBirthAuthority.Prepared.mk | Compiler.GrainResourceBirthAuthority | evidence | L1 Minidregg.Compiler.GrainResourceBirthAuthority.Prepared.birthReady | BatchReady loaded.snapshot descriptor: slots and grant ids distinct, initial policies fresh, descriptor.authorityNullifier unspent, every grant ready and parent rows absent at the loaded authority snapshot (sibling operationMarkerFresh: loaded.snapshot.spent operationMarker = false)
Minidregg.Compiler.GrainResourceBirthController.PreparedSourceAuthority.mk | Compiler.GrainResourceBirthController | evidence | L1 Minidregg.Compiler.GrainResourceBirthController.PreparedSourceAuthority.shape | SourceShape loaded.snapshot.domain semantics tariff source: tool and parent tasks distinct and not born by source.birth, both reserved/running, reserved ≥ tariff.charge source.birth, and source.birth.authorityNullifier ≠ operationMarker domain semantics (grainCommand tariff); the nested combined token carries the authority readiness
Minidregg.Compiler.GrainResourceBirthController.PreparedSourceBirth.mk | Compiler.GrainResourceBirthController | evidence | L1 Minidregg.Compiler.GrainResourceBirthController.PreparedSourceBirth.shape | SourceShape deployment.domain semantics tariff source: the same source shape (distinct unborn tasks, statuses, reserved ≥ charge, authority nullifier ≠ the source-derived operation marker) at the deployment's domain; the nested prepared token is indexed by that same marker
Minidregg.Compiler.NeutralPolicyCarry.Plan.mk | Compiler.NeutralPolicyCarry | evidence | L2 | defect cv 01a13c42-4a2e: no index and no proof field: deployment, bindings, authority, otherChanges, transformation are bare data; derive/finishPlan's checks (deployment.Valid, current authority heads have exact sources, target ids fresh, (plan.changes.map Prod.fst).Nodup) are Bool tests discarded; Plan.authority_other/absent hold of any data
Minidregg.Compiler.ObjectiveBendCombinedResult.Prepared.mk | Compiler.ObjectiveBendCombinedResult | evidence | L1 Minidregg.Compiler.ObjectiveBendCombinedResult.Prepared.sound | execution is executeWith (allows capacity) limits budget source.term, its value is the {plan, result} record, the return slot is returnSlot profile resultType bytes, plan = effects ++ [returnEffect profile slot] with reads, and plan matches command (indices source/limits/budget/capacity/profile/command; deployment/loaded enter via the Type-valued ordered/orderedReads)
Minidregg.Compiler.ObjectiveBendFrontEnd.Accepted.mk | Compiler.ObjectiveBendFrontEnd | evidence | L1 Minidregg.Compiler.ObjectiveBendFrontEnd.Accepted.sound | erased is l.term's erasure, packet is the decode of l.packet, the packet's term is that erasure, and the checker's check source [] fuel returned typed (existing Accepted.source_eq_packet names no index)
Minidregg.Compiler.ObjectiveBendGenericResult.Prepared.mk | Compiler.ObjectiveBendGenericResult | evidence | L1 Minidregg.Compiler.ObjectiveBendGenericResult.Prepared.sound | execution is executeWith (allows capacity) limits budget source.term, its value is the {plan, result} record, slot = returnSlot profile resultType bytes, augmented = augment profile command slot native.effects, plan = ⟨effects, [slot], reads⟩ and plan matches command (deployment/loaded enter via the Type-valued ordered/orderedReads)
Minidregg.Compiler.ObjectiveBendNativePlanData.BoundEffect.mk | Compiler.ObjectiveBendNativePlanData | evidence | L1 Minidregg.Compiler.ObjectiveBendNativePlanData.BoundEffect.sound | index is command's target index for source.ref.resourceID, that target's expected root and payload are source's, and selectTarget deployment selects pre from the BoundRead loaded source.ref's cell (guarantee spread over indexExact/rootExact/payloadExact/selected)
Minidregg.Compiler.ObjectiveBendPublication.Replayed.mk | Compiler.ObjectiveBendPublication | evidence | L1 Minidregg.Compiler.ObjectiveBendPublication.Replayed.core_replayed | ObjectiveBendPublication.replayedCore p = some typedCore: the offered typed core index is exactly the front end's replay rendering of package p (sibling theorems laws_replayed: publishedLaws p = .ok laws; field fuelWithin: fuel ≤ maxFuel)
Minidregg.Compiler.ObjectiveBendResultAdapter.PreparedResult.mk | Compiler.ObjectiveBendResultAdapter | evidence | L1 Minidregg.Compiler.ObjectiveBendResultAdapter.PreparedResult.sound | execution is executeWith (allows capacity) limits budget source.term, bytes is the budget encoding of its value, slot = returnSlot profile checked.type bytes, plan is the single return effect of that slot, and plan matches command
Minidregg.Compiler.ObjectiveBendSourceArtifact.Checked.mk | Compiler.ObjectiveBendSourceArtifact | evidence | L1 Minidregg.Compiler.ObjectiveBendSourceArtifact.Checked.jsonExact | parsePacket maxBytes artifact.typedCore = .ok packetJson: the checked packet JSON is the bounded parse of the artifact's own typed core (siblings: packetExact decodes it to packet, closed context, typed : Checked packet.source []); existing selected_core_exact names no index
Minidregg.Compiler.ObjectiveNativeScalarBinding.BoundPlan.mk | Compiler.ObjectiveNativeScalarBinding | evidence | L1 Minidregg.Compiler.ObjectiveNativeScalarBinding.BoundPlan.sound | each source effect corresponds pointwise to a plan effect produced from a BoundScalar deployment loaded command scalar, and the plan's effects are BendWorldPlan.effectsOf command (ordered is Type-valued so no field states it; existing exact_native_effects names only command). Inserted after ordered_correspondence (L275), which it uses, not after the struct
Minidregg.Compiler.ObjectiveNativeScalarBinding.BoundRead.mk | Compiler.ObjectiveNativeScalarBinding | evidence | L1 Minidregg.Compiler.ObjectiveNativeScalarBinding.BoundRead.sound | packed is the present cell of loaded at ref.resourceID and its logical payload root is ref.root (the two halves of the docstring's same-cell claim, previously split across present/logicalRoot)
Minidregg.Compiler.ObjectiveNativeScalarBinding.BoundScalar.mk | Compiler.ObjectiveNativeScalarBinding | evidence | L1 Minidregg.Compiler.ObjectiveNativeScalarBinding.BoundScalar.sound | index is command's target for scalar.ref.resourceID, packed is loaded's present cell there, selectDeclared deployment yields pre, pre.root = scalar.ref.root, and the scalar's source patch is valid from pre (existing theorems source_before_at_prefix/stale_root_impossible each cover one leg)
Minidregg.Host.FnSelectiveReleaseFnAck.Selected.mk | Host.FnSelectiveReleaseFnAck | evidence | L2 | defect cv 01a13c42-4a60: no index and no proof field: ingressBytes and receipt are bare data; selectFrom's checks (codecVersion 13, canonical decode, transactionId/event match, receiver replay receipt, article packet/messageId match) are Bool tests discarded, and nothing ties receipt to ingressBytes
Minidregg.Host.GrainOriginPreparation.Prepared.mk | Host.GrainOriginPreparation | evidence | L2 | defect cv 01a13c42-4aa7: no index and no proof field: disclosureIntent, scope, rendered are bare data; prepareForDisclosure's checks (intent.valid context, package length bound, FnEvidence.verify originConfig packageBytes, decodeChecked) are IO/Bool tests discarded, and no field ties scope (receipt, digests, origin config) to rendered
Minidregg.Host.GrainOriginSource.Rendered.mk | Host.GrainOriginSource | evidence | L2 | defect cv 01a13c42-4b0c: no index; the only proofs are self-consistency of the rendered bytes (Rendered.strict_source: extract source = .ok extracted, extracted.package = packageBytes, messageId, groups = context.group); render's provenance checks (verifiedReceipt == package.originalReceipt, selection.valid, the grain reserved-to-settled and parent-witness transitions) are discarded, and receipt, selection, signedTargets are unconstrained
Minidregg.Kernel.ActivitySeatEnd.Joined.mk | Kernel.ActivitySeatEnd | evidence | L1 Minidregg.Kernel.ActivitySeatEnd.Joined.closes | every seat held open at (height, record) on the loaded world after posted's batch is gone from the written seats, the sequenced batch posted.batch then held.batch Posts on logicalBook pre.logical, and the accepted post's book is the closing's next book
Minidregg.Kernel.ApplicationAgentLifetimeDispatchCore.Checked.mk | Kernel.ApplicationAgentLifetimeDispatchCore | evidence | L1 Minidregg.Kernel.ApplicationAgentLifetimeDispatchCore.Checked.reserveBound | the reserved-evidence index's context equals ingress.reserveContext and the payer's current state is AgentGrain.reserve of reserved.beforeState by the ingress reserve amount (ties the reserved and ingress indices; existing readGuards_current only states guard freshness at opened)
Minidregg.Kernel.ApplicationAgentLifetimeDispatchCurrent.Checked.mk | Kernel.ApplicationAgentLifetimeDispatchCurrent | evidence | L1 Minidregg.Kernel.ApplicationAgentLifetimeDispatchCurrent.Checked.sound | grant matches the issued ticket (spec, ticketIssueIndex, ticketIssueReceipt), ingress's issue bytes are issuedIngressBytes, the read grant cell's physical root is certifiedGrantRoot and decodes to grant at deployment.domain, and the signed command is the one derived from ingress (no existing theorem; 20 proof fields)
Minidregg.Kernel.ApplicationAgentLifetimeDispatchPayer.Checked.mk | Kernel.ApplicationAgentLifetimeDispatchPayer | evidence | L1 Minidregg.Kernel.ApplicationAgentLifetimeDispatchPayer.Checked.sound | state is the purse state of cell at context's purse task, cell's physical root is opened's current root at that task, and the state has context's generation and reserved = context reserve amount (spread across four fields)
Minidregg.Kernel.ApplicationAgentLifetimeDispatchReceiver.Permit.mk | Kernel.ApplicationAgentLifetimeDispatchReceiver | evidence | L1 Minidregg.Kernel.ApplicationAgentLifetimeDispatchReceiver.Permit.derivedExact | readback.derived.intent = admitted.intent: the exact post-CAS readback of the old verified config image installs the intent of the dispatch admitted at old.opened for ingress. Caveats: freshInstalled : freshCas = true only pins a stored Bool (vacuous); projection, confirmation, store and reader are unconstrained (reader's store not tied to target)
Minidregg.Kernel.ApplicationAgentLifetimeDispatchReserveCore.ReservedEvidence.mk | Kernel.ApplicationAgentLifetimeDispatchReserveCore | evidence | L1 Minidregg.Kernel.ApplicationAgentLifetimeDispatchReserveCore.ReservedEvidence.sourceExact | there is a ground of config.deployment and an accepted, shaped invocation under config.deployment/config.profile/config.federation whose command reserves context's amount on the purse task with beforeRoot/beforeState, the before state is idle with enough remaining, and record is exactly that invocation's data intent
Minidregg.Kernel.ApplicationAgentLifetimeGrantAdmission.Accepted.mk | Kernel.ApplicationAgentLifetimeGrantAdmission | evidence | L1 Minidregg.Kernel.ApplicationAgentLifetimeGrantAdmission.Accepted.named | 5 proof / 4 data fields; the proof field `named` carries the claim: every birth write of finalWrites is named by the admitted factory step
Minidregg.Kernel.ApplicationAgentLifetimeGrantDelegation.Checked.mk | Kernel.ApplicationAgentLifetimeGrantDelegation | evidence | L1 Minidregg.Kernel.ApplicationAgentLifetimeGrantDelegation.Checked.sound | the checked signature's envelope bytes are the envelope index and authorization is exactly authorize prepared signature (ties the prepared and envelope indices, previously in two fields; the signature verdict itself is CheckedSignature's runtime fact)
Minidregg.Kernel.ApplicationAgentLifetimeGrantDelegation.Prepared.mk | Kernel.ApplicationAgentLifetimeGrantDelegation | evidence | L1 Minidregg.Kernel.ApplicationAgentLifetimeGrantDelegation.Prepared.physicalCurrent | ResourceBirthCodec.physicalRoot (.live observed.before) = context.view.model.roots ⟨spec.grant.participant.app⟩: the observed app cell is the context view's current cell at the spec's app id (siblings epochCurrent/revisionCurrent pin the app request's policy epoch/revision to context.authority.authState)
Minidregg.Kernel.ApplicationAgentLifetimeGrantSource.Ready.mk | Kernel.ApplicationAgentLifetimeGrantSource | evidence | L1 Minidregg.Kernel.ApplicationAgentLifetimeGrantSource.Ready.pageExact | grantPage domain spec operation = .ok page: the ready page is exactly the grant page computed from the domain, spec and operation indices (sibling valid : spec.valid)
Minidregg.Kernel.ApplicationDispatchAdmission.CheckedCurrentForSourceBytes.mk | Kernel.ApplicationDispatchAdmission | evidence | L1 Minidregg.Kernel.ApplicationDispatchAdmission.CheckedCurrentForSourceBytes.sound | ingress names deployment's domain and profile's semantics, the signed command matches it, the spec's installed ticket is read and live at ambient.height, and issuer lineage is current from originalSourceBytes over ground (no existing theorem; 15 proof fields)
Minidregg.Kernel.ApplicationDispatchAdmission.CheckedRead.mk | Kernel.ApplicationDispatchAdmission | evidence | L1 Minidregg.Kernel.ApplicationDispatchAdmission.CheckedRead.sound | the root index is the observed cell's payload root, that cell's physical root is ground's current root at the resource index, and its read guard is outside the prepared invocation's writes (inserted after CheckedRead.signedInnerRoot at L357, which it uses)
Minidregg.Kernel.ApplicationDispatchAgentCore.Checked.mk | Kernel.ApplicationDispatchAgentCore | evidence | L2 | 6 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationDispatchAgentPayer.Checked.mk | Kernel.ApplicationDispatchAgentPayer | evidence | L2 | 8 proof / 8 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationDispatchAgentReceiver.Committed.mk | Kernel.ApplicationDispatchAgentReceiver | evidence | L2 | 1 proof / 8 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationDispatchAgentReceiver.Permit.mk | Kernel.ApplicationDispatchAgentReceiver | evidence | L2 | 2 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationDispatchAgentReserveCore.RawEvidence.mk | Kernel.ApplicationDispatchAgentReserveCore | evidence | L2 | 3 proof / 8 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationDispatchAgentReserveCore.ReservedEvidence.mk | Kernel.ApplicationDispatchAgentReserveCore | evidence | L2 | 3 proof / 7 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationDispatchHistoricalCore.CheckedCandidate.mk | Kernel.ApplicationDispatchHistoricalCore | evidence | L2 | 1 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationDispatchHistoricalCore.IssuedEvidence.mk | Kernel.ApplicationDispatchHistoricalCore | evidence | L2 | 1 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationDispatchReceiver.Committed.mk | Kernel.ApplicationDispatchReceiver | evidence | L2 | 1 proof / 7 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationDispatchReceiver.Permit.mk | Kernel.ApplicationDispatchReceiver | evidence | L2 | 2 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationDispatchReceiver.RefusalAtTip.mk | Kernel.ApplicationDispatchReceiver | evidence | L2 | 2 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationFailedCreateRetryEvidence.Conditional.mk | Kernel.ApplicationFailedCreateRetryEvidence | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationFailedStartRecoveryAdmission.Candidate.mk | Kernel.ApplicationFailedStartRecoveryAdmission | evidence | L2 | 12 proof / 8 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationFailedStartRecoveryAdmission.PackageRead.mk | Kernel.ApplicationFailedStartRecoveryAdmission | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationFailedStartRecoveryHistory.Candidate.mk | Kernel.ApplicationFailedStartRecoveryHistory | evidence | L2 | 4 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationFailedStartRecoveryPolicy.Accepted.mk | Kernel.ApplicationFailedStartRecoveryPolicy | evidence | L2 | 3 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationFailedStartRecoveryPolicy.CheckedLeg.mk | Kernel.ApplicationFailedStartRecoveryPolicy | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationFailedStartRecoveryReceiver.Confirmed.mk | Kernel.ApplicationFailedStartRecoveryReceiver | evidence | L2 | 1 proof / 6 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationFailedStartRecoveryReport.Checked.mk | Kernel.ApplicationFailedStartRecoveryReport | evidence | L2 | 3 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationGrainBirth.Ready.mk | Kernel.ApplicationGrainBirth | evidence | L2 | 1 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationGrainSessionBirth.Ready.mk | Kernel.ApplicationGrainSessionBirth | evidence | L2 | 1 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationGrainSessionEnrollmentAdmission.Checked.mk | Kernel.ApplicationGrainSessionEnrollmentAdmission | evidence | L2 | 1 proof / 8 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationGrainSessionEnrollmentAdmission.CheckedRead.mk | Kernel.ApplicationGrainSessionEnrollmentAdmission | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationGrainSessionEnrollmentReceiver.Confirmed.mk | Kernel.ApplicationGrainSessionEnrollmentReceiver | evidence | L2 | 1 proof / 6 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleBeginV2Admission.Accepted.mk | Kernel.ApplicationLifecycleBeginV2Admission | evidence | L2 | 2 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleBeginV2Receiver.Confirmed.mk | Kernel.ApplicationLifecycleBeginV2Receiver | evidence | L2 | 1 proof / 6 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleBeginV3Admission.Accepted.mk | Kernel.ApplicationLifecycleBeginV3Admission | evidence | L2 | 3 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleBeginV3Receiver.Confirmed.mk | Kernel.ApplicationLifecycleBeginV3Receiver | evidence | L2 | 1 proof / 5 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleClaimCore.Conditional.mk | Kernel.ApplicationLifecycleClaimCore | evidence | L2 | 0 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleClaimCurrent.CheckedRead.mk | Kernel.ApplicationLifecycleClaimCurrent | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleClaimHistory.Conditional.mk | Kernel.ApplicationLifecycleClaimHistory | evidence | L2 | 0 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleClaimReceiver.Reservation.mk | Kernel.ApplicationLifecycleClaimReceiver | evidence | L2 | 1 proof / 6 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleClaimV2Core.Conditional.mk | Kernel.ApplicationLifecycleClaimV2Core | evidence | L2 | 2 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleClaimV2Receiver.Reservation.mk | Kernel.ApplicationLifecycleClaimV2Receiver | evidence | L2 | 1 proof / 6 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleClaimV3Core.Conditional.mk | Kernel.ApplicationLifecycleClaimV3Core | evidence | L2 | 3 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleClaimV3Receiver.Reservation.mk | Kernel.ApplicationLifecycleClaimV3Receiver | evidence | L2 | 1 proof / 7 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleClaimVerified.Admitted.mk | Kernel.ApplicationLifecycleClaimVerified | evidence | L2 | 4 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleCompletionAdmission.Candidate.mk | Kernel.ApplicationLifecycleCompletionAdmission | evidence | L2 | 11 proof / 8 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleCompletionAdmission.PackageRead.mk | Kernel.ApplicationLifecycleCompletionAdmission | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleCompletionHistory.Candidate.mk | Kernel.ApplicationLifecycleCompletionHistory | evidence | L2 | 4 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleCompletionPolicy.Accepted.mk | Kernel.ApplicationLifecycleCompletionPolicy | evidence | L2 | 3 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleCompletionPolicy.CheckedLeg.mk | Kernel.ApplicationLifecycleCompletionPolicy | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleCompletionReceiver.Confirmed.mk | Kernel.ApplicationLifecycleCompletionReceiver | evidence | L2 | 1 proof / 6 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleCompletionReport.Checked.mk | Kernel.ApplicationLifecycleCompletionReport | evidence | L2 | 3 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleCompletionV2Admission.Candidate.mk | Kernel.ApplicationLifecycleCompletionV2Admission | evidence | L2 | 12 proof / 8 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleCompletionV2Admission.PackageRead.mk | Kernel.ApplicationLifecycleCompletionV2Admission | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleCompletionV2History.Candidate.mk | Kernel.ApplicationLifecycleCompletionV2History | evidence | L2 | 4 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleCompletionV2Policy.Accepted.mk | Kernel.ApplicationLifecycleCompletionV2Policy | evidence | L2 | 3 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleCompletionV2Policy.CheckedLeg.mk | Kernel.ApplicationLifecycleCompletionV2Policy | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleCompletionV2Receiver.Confirmed.mk | Kernel.ApplicationLifecycleCompletionV2Receiver | evidence | L2 | 1 proof / 6 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleCompletionV2Report.Checked.mk | Kernel.ApplicationLifecycleCompletionV2Report | evidence | L2 | 3 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleCreatedHistory.Candidate.mk | Kernel.ApplicationLifecycleCreatedHistory | evidence | L2 | 13 proof / 7 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleRetryBeginV4Admission.Accepted.mk | Kernel.ApplicationLifecycleRetryBeginV4Admission | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleRetryBeginV4Receiver.Confirmed.mk | Kernel.ApplicationLifecycleRetryBeginV4Receiver | evidence | L2 | 1 proof / 6 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleRetryClaimV4Core.Conditional.mk | Kernel.ApplicationLifecycleRetryClaimV4Core | evidence | L2 | 3 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleRetryClaimV4Receiver.Reservation.mk | Kernel.ApplicationLifecycleRetryClaimV4Receiver | evidence | L2 | 1 proof / 7 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleRetryCompletionV4Admission.Candidate.mk | Kernel.ApplicationLifecycleRetryCompletionV4Admission | evidence | L2 | 12 proof / 8 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleRetryCompletionV4Admission.PackageRead.mk | Kernel.ApplicationLifecycleRetryCompletionV4Admission | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleRetryCompletionV4CreatedHistory.Candidate.mk | Kernel.ApplicationLifecycleRetryCompletionV4CreatedHistory | evidence | L2 | 13 proof / 7 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleRetryCompletionV4History.Candidate.mk | Kernel.ApplicationLifecycleRetryCompletionV4History | evidence | L2 | 4 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleRetryCompletionV4Policy.Accepted.mk | Kernel.ApplicationLifecycleRetryCompletionV4Policy | evidence | L2 | 3 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleRetryCompletionV4Policy.CheckedLeg.mk | Kernel.ApplicationLifecycleRetryCompletionV4Policy | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleRetryCompletionV4Receiver.Confirmed.mk | Kernel.ApplicationLifecycleRetryCompletionV4Receiver | evidence | L2 | 1 proof / 6 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationLifecycleRetryCompletionV4Report.Checked.mk | Kernel.ApplicationLifecycleRetryCompletionV4Report | evidence | L2 | 3 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationRouteAdmission.Attestation.mk | Kernel.ApplicationRouteAdmission | evidence | L2 | 5 proof / 5 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationShareIssueAdmission.Accepted.mk | Kernel.ApplicationShareIssueAdmission | evidence | L1 Minidregg.Kernel.ApplicationShareIssueAdmission.Accepted.named | 5 proof / 4 data fields; the proof field `named` carries the claim: every birth write of finalWrites is named by the admitted factory step
Minidregg.Kernel.ApplicationShareIssueDelegation.Checked.mk | Kernel.ApplicationShareIssueDelegation | evidence | L2 | 4 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationShareIssueDelegation.Prepared.mk | Kernel.ApplicationShareIssueDelegation | evidence | L2 | 4 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationShareIssueGrainAdmission.Accepted.mk | Kernel.ApplicationShareIssueGrainAdmission | evidence | L2 | 4 proof / 8 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationShareIssueHistorical.Issued.mk | Kernel.ApplicationShareIssueHistorical | evidence | L2 | 3 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationShareIssueSource.Ready.mk | Kernel.ApplicationShareIssueSource | evidence | L2 | 2 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.ApplicationStreamContinuity.Attestation.mk | Kernel.ApplicationStreamContinuity | evidence | L2 | 6 proof / 5 data fields; layer-1 review pending
Minidregg.Kernel.AudienceRosterBinding.Checked.mk | Kernel.AudienceRosterBinding | evidence | L2 | 6 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.AudienceRosterBinding.CheckedBytes.mk | Kernel.AudienceRosterBinding | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.BirthCandidateAdmission.Checked.mk | Kernel.BirthCandidateAdmission | evidence | L2 | 4 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.BirthExportAdmission.Evaluated.mk | Kernel.BirthExportAdmission | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.BirthExportAdmission.ItemChecked.mk | Kernel.BirthExportAdmission | evidence | L2 | 5 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.BirthExportAdmission.Checked.mk | Kernel.BirthExportAdmission | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.BirthExportAdmission.NeutralItem.mk | Kernel.BirthExportAdmission | evidence | L2 | 2 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.CapabilityDelegationController.Accepted.mk | Kernel.CapabilityDelegationController | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.CapabilityDelegationController.PreparedOn.mk | Kernel.CapabilityDelegationController | evidence | L2 | 4 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.CapabilityDelegationReceiver.AcceptedDelegation.mk | Kernel.CapabilityDelegationReceiver | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.CapabilityDelegationReceiver.DecodedIngress.mk | Kernel.CapabilityDelegationReceiver | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.CapabilityRenounce.Accepted.mk | Kernel.CapabilityRenounce | evidence | L2 | 4 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.CapabilityRenounce.AcceptedRenounce.mk | Kernel.CapabilityRenounce | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.CapabilityRenounce.DecodedIngress.mk | Kernel.CapabilityRenounce | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.CapabilityRenounce.HolderRefusal.mk | Kernel.CapabilityRenounce | evidence | L2 | 3 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.CapabilityRenounce.PreparedOn.mk | Kernel.CapabilityRenounce | evidence | L2 | 1 proof / 0 data fields; layer-1 review pending
Minidregg.Kernel.CapabilityRevocationController.Accepted.mk | Kernel.CapabilityRevocationController | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.CapabilityRevocationController.PreparedOn.mk | Kernel.CapabilityRevocationController | evidence | L2 | a prepared revocation over the directory and authority it read (renamed from Prepared on next); victim/identity/policy exactness are proof fields; layer-1 review pending
Minidregg.Kernel.CapabilityRevocationReceiver.AcceptedRevocation.mk | Kernel.CapabilityRevocationReceiver | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.CapabilityRevocationReceiver.DecodedIngress.mk | Kernel.CapabilityRevocationReceiver | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.CarriedApplicationDispatchReceiver.Committed.mk | Kernel.CarriedApplicationDispatchReceiver | evidence | L2 | 1 proof / 8 data fields; layer-1 review pending
Minidregg.Kernel.CarriedApplicationDispatchReceiver.Permit.mk | Kernel.CarriedApplicationDispatchReceiver | evidence | L2 | 2 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.CarriedApplicationDispatchReceiver.RefusalAtTip.mk | Kernel.CarriedApplicationDispatchReceiver | evidence | L2 | 1 proof / 0 data fields; layer-1 review pending
Minidregg.Kernel.CarriedDispatchAdmission.Admitted.mk | Kernel.CarriedDispatchAdmission | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.CarriedSessionEnrollmentAdmission.Admitted.mk | Kernel.CarriedSessionEnrollmentAdmission | evidence | L2 | 3 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.CarriedSessionEnrollmentReceiver.Confirmed.mk | Kernel.CarriedSessionEnrollmentReceiver | evidence | L2 | 2 proof / 8 data fields; layer-1 review pending
Minidregg.Kernel.CertifyReceiver.Accepted.mk | Kernel.CertifyReceiver | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.CertifyReceiver.AcceptedCertify.mk | Kernel.CertifyReceiver | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.CertifyReceiver.DecodedIngress.mk | Kernel.CertifyReceiver | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.CertifyReceiver.Prepared.mk | Kernel.CertifyReceiver | evidence | L2 | 1 proof / 7 data fields; layer-1 review pending
Minidregg.Kernel.ClockCellDomain.Loaded.mk | Kernel.ClockCellDomain | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ClockTickReceiver.Accepted.mk | Kernel.ClockTickReceiver | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ClockTickReceiver.AcceptedTick.mk | Kernel.ClockTickReceiver | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ClockTickReceiver.DecodedIngress.mk | Kernel.ClockTickReceiver | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.ClockTickReceiver.Prepared.mk | Kernel.ClockTickReceiver | evidence | L2 | 1 proof / 6 data fields; layer-1 review pending
Minidregg.Kernel.ConfidentialAudienceAdmission.Checked.mk | Kernel.ConfidentialAudienceAdmission | evidence | L2 | 6 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.ConsentAnchor.Anchored.mk | Kernel.ConsentAnchor | evidence | L2 | 1 proof / 3 data fields; minted only by ConsentAnchor.resume (anchor opening + native suffix replay, an IO verdict); entered the census when Compiler.lean began importing Kernel.ConsentAnchor (it was reachable before only from the consent exe root); layer-1 review pending
Minidregg.Kernel.ContentResource.PreparedCell.mk | Kernel.ContentResource | evidence | L2 | 3 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.DeclaredResourceController.AcceptedInvocation.mk | Kernel.DeclaredResourceController | evidence | L2 | 4 proof / 6 data fields; layer-1 review pending
Minidregg.Kernel.DeclaredResourceController.AuthorityInvocation.mk | Kernel.DeclaredResourceController | evidence | L2 | 3 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.DeclaredResourceController.PreparedOn.mk | Kernel.ResourceTransaction | evidence | L2 | 7 proof / 8 data fields; layer-1 review pending
Minidregg.Kernel.DeclaredResourceController.PreparedPolicyLeg.mk | Kernel.PreparedInvocationDiagnostics | evidence | L2 | 4 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.DeclaredResourceController.PreparedTarget.mk | Kernel.ResourceTransaction | evidence | L2 | 5 proof / 5 data fields; layer-1 review pending
Minidregg.Kernel.DeclaredResourceScalar.PreparedCell.mk | Kernel.DeclaredResourceScalar | evidence | L2 | 0 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.FleetTurn.Accepted.mk | Kernel.FleetTurn | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.FleetTurn.DecodedIngress.mk | Kernel.FleetTurn | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.FleetTurn.Prepared.mk | Kernel.FleetTurn | evidence | L2 | 3 proof / 6 data fields; layer-1 review pending
Minidregg.Kernel.FleetTurnReceiver.AcceptedTurn.mk | Kernel.FleetTurnReceiver | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.FnConsumerFrontierGateway.Checked.mk | Kernel.FnConsumerFrontierGateway | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.FnConsumerFrontierGateway.CheckedOpened.mk | Kernel.FnConsumerFrontierGateway | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.FnConsumerFrontierGateway.Prepared.mk | Kernel.FnConsumerFrontierGateway | evidence | L2 | 5 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.FnConsumerNamespaceAdmission.AcceptedVerified.mk | Kernel.FnConsumerNamespaceAdmission | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.FnConsumerNamespaceAdmissionAt.Conditional.mk | Kernel.FnConsumerNamespaceAdmissionAt | evidence | L2 | 1 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.FnConsumerNamespaceHistory.Original.mk | Kernel.FnConsumerNamespaceHistory | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.FnEmptyPollAdmissionAtV2.Accepted.mk | Kernel.FnEmptyPollAdmissionAtV2 | evidence | L2 | 4 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.FnEmptyPollAdmissionV2.AcceptedVerified.mk | Kernel.FnEmptyPollAdmissionV2 | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.FnEmptyPollAdmissionV2.Checked.mk | Kernel.FnEmptyPollAdmissionV2 | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.FnSelectedPollAdmission.AcceptedVerified.mk | Kernel.FnSelectedPollAdmission | evidence | L2 | 3 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.FnSelectedPollAdmission.Checked.mk | Kernel.FnSelectedPollAdmission | evidence | L2 | 4 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.FnSelectedPollAdmissionAt.Accepted.mk | Kernel.FnSelectedPollAdmissionAt | evidence | L2 | 8 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.FnSelectiveReleaseAdmission.Accepted.mk | Kernel.FnSelectiveReleaseAdmission | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.FnSelectiveReleaseSignature.Checked.mk | Kernel.FnSelectiveReleaseSignature | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.FnSelectiveReleaseSourceAuthority.Checked.mk | Kernel.FnSelectiveReleaseSourceAuthority | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.FnSelectiveReleaseSourceAuthority.Prepared.mk | Kernel.FnSelectiveReleaseSourceAuthority | evidence | L2 | 6 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.FnSelectiveReleaseSourceReceiver.Accepted.mk | Kernel.FnSelectiveReleaseSourceReceiver | evidence | L2 | 0 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.GrainResourceBirthAdmission.Accepted.mk | Kernel.GrainResourceBirthAdmission | evidence | L2 | 3 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.GrainResourceBirthAdmission.Pending.mk | Kernel.GrainResourceBirthAdmission | evidence | L2 | 5 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.GrainResourceBirthPolicyController.DecodedIngress.mk | Kernel.GrainResourceBirthPolicyController | evidence | L2 | 6 proof / 5 data fields; layer-1 review pending
Minidregg.Kernel.GrainResourceBirthTransaction.PreparedTargets.mk | Kernel.GrainResourceBirthTransaction | evidence | L2 | 0 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.JobMoneyReceiver.Accepted.mk | Kernel.JobMoneyReceiver | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.JobMoneyReceiver.AcceptedMoney.mk | Kernel.JobMoneyReceiver | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.JobMoneyReceiver.DecodedIngress.mk | Kernel.JobMoneyReceiver | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.JobMoneyReceiver.Prepared.mk | Kernel.JobMoneyReceiver | evidence | L2 | 7 proof / 11 data fields; layer-1 review pending
Minidregg.Kernel.JointControlBootstrap.Admission.mk | Kernel.JointControlBootstrap | evidence | L2 | 3 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.JointControlBootstrapBundle.Accepted.mk | Kernel.JointControlBootstrapBundle | evidence | L2 | 7 proof / 5 data fields; layer-1 review pending
Minidregg.Kernel.JointControlBootstrapBundle.Initialization.mk | Kernel.JointControlBootstrapBundle | evidence | L2 | 2 proof / 6 data fields; layer-1 review pending
Minidregg.Kernel.JointPromiseAuthorization.Accepted.mk | Kernel.JointPromiseAuthorization | evidence | L2 | 5 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.JointReceiver.Ordered.mk | Kernel.JointReceiver | evidence | L2 | 1 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.JointReceiver.Pending.mk | Kernel.JointReceiver | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.JointReceiverAdmission.Reserved.mk | Kernel.JointReceiverAdmission | evidence | L2 | 12 proof / 8 data fields; layer-1 review pending
Minidregg.Kernel.NativeHistorySelection.After.mk | Kernel.NativeHistorySelection | evidence | L2 | 2 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.NativeHistorySelection.Candidate.mk | Kernel.NativeHistorySelection | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.NativeHistorySelection.Matched.mk | Kernel.NativeHistorySelection | evidence | L2 | 2 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.NativeHost.Opened.mk | Kernel.NativeHostContext | evidence | L2 | 1 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostGenesis.Built.mk | Kernel.NativeHostGenesis | evidence | L2 | 3 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.AgentDispatchAt.mk | Kernel.NativeHostReplay | evidence | L2 | 6 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.BeginAtV3.mk | Kernel.NativeHostReplay | evidence | L2 | 0 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.BeginAtV4.mk | Kernel.NativeHostReplay | evidence | L2 | 4 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.ClaimAt.mk | Kernel.NativeHostReplay | evidence | L2 | 4 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.ClaimAtV2.mk | Kernel.NativeHostReplay | evidence | L2 | 4 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.ClaimAtV3.mk | Kernel.NativeHostReplay | evidence | L2 | 4 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.ClaimAtV4.mk | Kernel.NativeHostReplay | evidence | L2 | 4 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.CompletionAt.mk | Kernel.NativeHostReplay | evidence | L2 | 4 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.CompletionAtV2.mk | Kernel.NativeHostReplay | evidence | L2 | 4 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.CompletionAtV4.mk | Kernel.NativeHostReplay | evidence | L2 | 4 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.CreatedAt.mk | Kernel.NativeHostReplay | evidence | L2 | 5 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.Derived.mk | Kernel.NativeHostReplay | evidence | L2 | 1 proof / 18 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.DispatchAt.mk | Kernel.NativeHostReplay | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.FailedStartRecoveryAt.mk | Kernel.NativeHostReplay | evidence | L2 | 4 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.LifetimeDispatchAt.mk | Kernel.NativeHostReplay | evidence | L2 | 10 proof / 5 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.LifetimeGrantIssueAt.mk | Kernel.NativeHostReplay | evidence | L2 | 5 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.PriorBegin.mk | Kernel.NativeHostReplay | evidence | L2 | 1 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.PriorBeginV2.mk | Kernel.NativeHostReplay | evidence | L2 | 1 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.PriorBeginV3.mk | Kernel.NativeHostReplay | evidence | L2 | 1 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.PriorBeginV4.mk | Kernel.NativeHostReplay | evidence | L2 | 1 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.PriorClaimV2.mk | Kernel.NativeHostReplay | evidence | L2 | 1 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.PriorClaimV3.mk | Kernel.NativeHostReplay | evidence | L2 | 1 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.PriorClaimV4.mk | Kernel.NativeHostReplay | evidence | L2 | 1 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.PriorCreatedV3.mk | Kernel.NativeHostReplay | evidence | L2 | 2 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.PriorDispatchReserve.mk | Kernel.NativeHostReplay | evidence | L2 | 0 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.PriorIssue.mk | Kernel.NativeHostReplay | evidence | L2 | 0 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.PriorLifetimeGrant.mk | Kernel.NativeHostReplay | evidence | L2 | 1 proof / 6 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.PriorRecovery.mk | Kernel.NativeHostReplay | evidence | L2 | 1 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.PriorRunningV3.mk | Kernel.NativeHostReplay | evidence | L2 | 3 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.PriorSelectedRelease.mk | Kernel.NativeHostReplay | evidence | L2 | 0 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.RunningAt.mk | Kernel.NativeHostReplay | evidence | L2 | 5 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.SessionEnrollmentAt.mk | Kernel.NativeHostReplay | evidence | L2 | 5 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.SuffixVerified.mk | Kernel.NativeHostReplay | evidence | L2 | 8 proof / 16 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.SuffixWalked.mk | Kernel.NativeHostReplay | evidence | L2 | 1 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.Verified.mk | Kernel.NativeHostReplay | evidence | L2 | 3 proof / 16 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.VerifiedSelection.mk | Kernel.NativeHostReplay | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostReplay.Walked.mk | Kernel.NativeHostReplay | evidence | L2 | 1 proof / 16 data fields; layer-1 review pending
Minidregg.Kernel.NativeHostServed.OpenedServed.mk | Kernel.NativeHostServed | evidence | L2 | the Host's served open (kn2-store-open ii); layer-1 review pending
Minidregg.Kernel.NativeObservationController.AuthorizedIntent.mk | Kernel.NativeObservationController | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.NativeObservationController.CheckedGrant.mk | Kernel.NativeObservationController | evidence | L2 | 2 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.NativeObservationController.Selected.mk | Kernel.NativeObservationController | evidence | L2 | 5 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ObjectAudienceInstall.Prepared.mk | Kernel.ObjectAudienceInstall | evidence | L2 | 5 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveActivity.Abandonment.mk | Kernel.ObjectiveActivity | evidence | L2 | 10 proof / 8 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveActivity.Abort.mk | Kernel.ObjectiveActivityUpgrade | evidence | L2 | upgrade-turns (DEPUTY-OB-ENG): proof fields mirror the admitting checks per its audit; L1 theorem pending from OB-ENG
Minidregg.Kernel.ObjectiveActivity.Adoption.mk | Kernel.ObjectiveActivityUpgrade | evidence | L2 | upgrade-turns (DEPUTY-OB-ENG): proof fields mirror the admitting checks per its audit; L1 theorem pending from OB-ENG
Minidregg.Kernel.ObjectiveActivity.Birth.mk | Kernel.ObjectiveActivity | evidence | L2 | 15 proof / 11 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveActivity.BirthPrefix.mk | Kernel.ObjectiveActivity | evidence | L2 | DEPUTY-OB-ENG type; layer-1 review pending (OB-ENG)
Minidregg.Kernel.ObjectiveActivity.Creation.mk | Kernel.ObjectiveActivity | evidence | L2 | 3 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveActivity.ChargedFailure.mk | Kernel.ObjectiveActivity | evidence | L2 | 2 proof / 2 data fields; GPT-6 row E charged failure (minted only by chargeFailure); layer-1 review pending
Minidregg.Kernel.ObjectiveActivity.Delivery.mk | Kernel.ObjectiveActivity | evidence | L2 | 23 proof / 20 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveActivity.Exhaustion.mk | Kernel.ObjectiveActivity | evidence | L2 | 20 proof / 15 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveActivity.Instantiated.mk | Kernel.ObjectiveActivity | evidence | L2 | 1 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveActivity.Migrated.mk | Kernel.ObjectiveActivityUpgrade | evidence | L2 | upgrade-turns (DEPUTY-OB-ENG): proof fields mirror the admitting checks per its audit; L1 theorem pending from OB-ENG
Minidregg.Kernel.ObjectiveActivity.Migration.mk | Kernel.ObjectiveActivity | evidence | L2 | upgrade-turns ObjectRecord migration (DEPUTY-OB-ENG); L1 theorem pending from OB-ENG
Minidregg.Kernel.ObjectiveActivity.Postings.mk | Kernel.ObjectiveActivity | evidence | L2 | 1 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveActivity.Program.mk | Kernel.ObjectiveActivity | evidence | L2 | 3 proof / 8 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveActivity.Publication.mk | Kernel.ObjectiveActivity | evidence | L2 | 5 proof / 5 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveActivity.Rebirth.mk | Kernel.ObjectiveActivityUpgrade | evidence | L2 | upgrade-turns (DEPUTY-OB-ENG): proof fields mirror the admitting checks per its audit; L1 theorem pending from OB-ENG
Minidregg.Kernel.ObjectiveActivity.Registration.mk | Kernel.ObjectiveDomain | evidence | L2 | 7 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveActivity.Replay.mk | Kernel.ObjectiveActivity | evidence | L2 | 4 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveActivity.Resolution.mk | Kernel.ObjectiveActivity | evidence | L2 | 5 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveActivity.ResumeHead.mk | Kernel.ObjectiveActivity | evidence | L2 | DEPUTY-OB-ENG type; layer-1 review pending (OB-ENG)
Minidregg.Kernel.ObjectiveActivity.ResumeTail.mk | Kernel.ObjectiveActivity | evidence | L2 | DEPUTY-OB-ENG type; layer-1 review pending (OB-ENG)
Minidregg.Kernel.ObjectiveActivity.TopUp.mk | Kernel.ObjectiveActivity | evidence | L2 | 3 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveActivity.TypedData.mk | Kernel.ObjectiveActivity | evidence | L2 | 1 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveActivityReceiver.Accepted.mk | Kernel.ObjectiveActivityReceiverCore | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveActivityReceiver.DecodedIngress.mk | Kernel.ObjectiveActivityReceiverCore | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveActivityReceiver.Failed.mk | Kernel.ObjectiveActivityReceiverCore | evidence | L2 | 7 proof / 8 data fields; GPT-6 row E charged failure after gate + signature (minted only by admitDecodedNative); layer-1 review pending
Minidregg.Kernel.ObjectiveActivityReceiver.Gated.mk | Kernel.ObjectiveActivityReceiverCore | evidence | L2 | 4 proof / 4 data fields; GPT-6 row E gate: authority, capability over the claimed outcome, funds (minted only by gate); layer-1 review pending
Minidregg.Kernel.ObjectiveActivityReceiver.Prepared.mk | Kernel.ObjectiveActivityReceiverCore | evidence | L2 | 6 proof / 7 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveBendArtifactSource.Current.mk | Kernel.ObjectiveBendArtifactSource | evidence | L2 | 3 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveBendArtifactSource.Loaded.mk | Kernel.ObjectiveBendArtifactSource | evidence | L2 | 5 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveBendNativeAdmission.Admitted.mk | Kernel.ObjectiveBendNativeAdmission | evidence | L2 | 7 proof / 5 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveBendNativeAdmission.Core.mk | Kernel.ObjectiveBendNativeAdmission | evidence | L2 | 11 proof / 7 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveBendNativeAdmission.Selection.mk | Kernel.ObjectiveBendNativeAdmission | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveBendNativeAdmission.SourceSelection.mk | Kernel.ObjectiveBendNativeAdmission | evidence | L2 | 9 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveBendNativeInput.AdmittedRead.mk | Kernel.ObjectiveBendNativeInput | evidence | L2 | 1 proof / 9 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveBendNativeInput.Bound.mk | Kernel.ObjectiveBendNativeInput | evidence | L2 | 1 proof / 1 data fields; layer-1 review pending; mints: ObjectiveBendNativeInput.bind (review pending: binds by data, no proposition argument)
Minidregg.Kernel.ObjectiveBendPreparedOutput.Prepared.mk | Kernel.ObjectiveBendPreparedOutput | evidence | L2 | 2 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveBendPublishedPackage.Loaded.mk | Kernel.ObjectiveBendPublishedPackage | evidence | L2 | 7 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveCall.Deliverable.mk | Kernel.ObjectiveCall | evidence | L2 | a method a message can be delivered to, decided at the send (record, view, args, method each with its Exact proof field); new on next (OB-ENG); layer-1 review pending
Minidregg.Kernel.ObjectiveCall.Invocation.mk | Kernel.ObjectiveCall | evidence | L2 | 7 proof / 7 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveCall.Method.mk | Kernel.ObjectiveCall | evidence | L2 | 5 proof / 8 data fields; layer-1 review pending
Minidregg.Kernel.ObjectiveSend.MessageDelivery.mk | Kernel.ObjectiveSend | evidence | L2 | 14 proof / 12 data fields; layer-1 review pending
Minidregg.Kernel.ParticipantFactoryProvisioning.Accepted.mk | Kernel.ParticipantFactoryProvisioning | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ParticipantFactoryProvisioning.DecodedIngress.mk | Kernel.ParticipantFactoryProvisioning | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.ParticipantFactoryProvisioning.Prepared.mk | Kernel.ParticipantFactoryProvisioning | evidence | L2 | 1 proof / 5 data fields; layer-1 review pending
Minidregg.Kernel.ParticipantFactoryProvisioningReceiver.AcceptedProvisioning.mk | Kernel.ParticipantFactoryProvisioningReceiver | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ParticipantKeyEnrollment.Accepted.mk | Kernel.ParticipantKeyEnrollment | evidence | L2 | 3 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.ParticipantKeyEnrollment.DecodedIngress.mk | Kernel.ParticipantKeyEnrollment | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.ParticipantKeyEnrollment.Prepared.mk | Kernel.ParticipantKeyEnrollment | evidence | L2 | 4 proof / 5 data fields; layer-1 review pending
Minidregg.Kernel.ParticipantKeyEnrollmentReceiver.AcceptedEnrollment.mk | Kernel.ParticipantKeyEnrollmentReceiver | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.PayAssignmentReceiver.Accepted.mk | Kernel.PayAssignmentReceiver | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.PayAssignmentReceiver.AcceptedAssignment.mk | Kernel.PayAssignmentReceiver | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.PayAssignmentReceiver.DecodedIngress.mk | Kernel.PayAssignmentReceiver | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.PayAssignmentReceiver.Prepared.mk | Kernel.PayAssignmentReceiver | evidence | L2 | 1 proof / 5 data fields; layer-1 review pending
Minidregg.Kernel.PayBookReceiver.Accepted.mk | Kernel.PayBookReceiver | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.PayBookReceiver.AcceptedChange.mk | Kernel.PayBookReceiver | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.PayBookReceiver.DecodedIngress.mk | Kernel.PayBookReceiver | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.PayBookReceiver.Prepared.mk | Kernel.PayBookReceiver | evidence | L2 | 1 proof / 7 data fields; layer-1 review pending
Minidregg.Kernel.PayCellDomain.Loaded.mk | Kernel.PayCellDomain | evidence | L2 | 1 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.PayClaimCommand.Checked.mk | Kernel.PayClaimCommand | evidence | L2 | 0 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.PayClaimCommand.DecodedIngress.mk | Kernel.PayClaimCommand | evidence | L2 | 3 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.PayClaimReceiver.AcceptedClaim.mk | Kernel.PayClaimReceiver | evidence | L2 | 1 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.PayClaimReceiver.Prepared.mk | Kernel.PayClaimReceiver | evidence | L2 | 4 proof / 13 data fields; layer-1 review pending
Minidregg.Kernel.PayClaimReceiver.SourceWitness.mk | Kernel.PayClaimReceiver | evidence | L2 | 1 proof / 0 data fields; layer-1 review pending
Minidregg.Kernel.PayEnrolReceiver.DecodedIngress.mk | Kernel.PayEnrolReceiver | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.PayEnrolReceiver.EnrolLegs.mk | Kernel.PayEnrolReceiver | evidence | L2 | 10 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.PayEnrolReceiver.Planned.mk | Kernel.PayEnrolReceiver | evidence | L1 Minidregg.Kernel.PayEnrolReceiver.Planned.sound | decideEnrol under exactly the bits it is indexed by, tip ahead of the clock, chain tip advances, factory dependencies loaded
Minidregg.Kernel.PayEnrolReceiver.Prepared.mk | Kernel.PayEnrolReceiver | evidence | L1 Minidregg.Kernel.PayEnrolReceiver.Prepared.sound | receiver-sourced receipt for the carried envelope, request bound to the factory head; the receipt verdict and the bits are the Receiver's (L2 Vouchers; committed_verified)
Minidregg.Kernel.PayEnrolV2Legs.EnrolLegs.mk | Kernel.PayEnrolV2Legs | evidence | L2 | 15 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.PayEnrolV2Legs.RenewLegs.mk | Kernel.PayEnrolV2Legs | evidence | L2 | 5 proof / 0 data fields; layer-1 review pending
Minidregg.Kernel.PayEnrolV2Receiver.Planned.mk | Kernel.PayEnrolV2Receiver | evidence | L1 Minidregg.Kernel.PayEnrolV2Receiver.Planned.sound | PayEnrolV2Decision.decide under exactly the bits it is indexed by, economic input, fresh tip, factory dependencies loaded
Minidregg.Kernel.PayEnrolV2Receiver.Prepared.mk | Kernel.PayEnrolV2Receiver | evidence | L1 Minidregg.Kernel.PayEnrolV2Receiver.Prepared.sound | parsed v2 memo, receiver-sourced receipt for the carried envelope, request bound to the factory head; the bits are the Receiver's (committed_verified)
Minidregg.Kernel.PayObservationReceiver.DecodedIngress.mk | Kernel.PayObservationReceiver | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.PayObservationReceiver.Planned.mk | Kernel.PayObservationReceiver | evidence | L1 Minidregg.Kernel.PayObservationReceiver.Planned.sound | loaded cells exact, tip retained, clock at the tip slot, Book = batch applied
Minidregg.Kernel.PayObservationReceiver.Prepared.mk | Kernel.PayObservationReceiver | evidence | L1 Minidregg.Kernel.PayObservationReceiver.Prepared.sound | receiver-sourced receipt for the carried envelope, request bound to the pay head; the receipt verdict is L2
Minidregg.Kernel.PolicyInstallReceiver.AcceptedInstall.mk | Kernel.PolicyInstallReceiver | evidence | L2 | 5 proof / 5 data fields; layer-1 review pending
Minidregg.Kernel.PolicyInstallReceiver.DecodedIngress.mk | Kernel.PolicyInstallReceiver | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.PolicyInstallReceiver.Prepared.mk | Kernel.PolicyInstallReceiver | evidence | L2 | 9 proof / 8 data fields; layer-1 review pending
Minidregg.Kernel.PurseRefillReceiver.Accepted.mk | Kernel.PurseRefillReceiver | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.PurseRefillReceiver.AcceptedRefill.mk | Kernel.PurseRefillReceiver | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.PurseRefillReceiver.DecodedIngress.mk | Kernel.PurseRefillReceiver | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.PurseRefillReceiver.Prepared.mk | Kernel.PurseRefillReceiver | evidence | L2 | 5 proof / 10 data fields; layer-1 review pending
Minidregg.Kernel.RealmWellReceiver.Accepted.mk | Kernel.RealmWellReceiver | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.RealmWellReceiver.AcceptedWell.mk | Kernel.RealmWellReceiver | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.RealmWellReceiver.DecodedIngress.mk | Kernel.RealmWellReceiver | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.RealmWellReceiver.Prepared.mk | Kernel.RealmWellReceiver | evidence | L2 | 1 proof / 6 data fields; layer-1 review pending
Minidregg.Kernel.RecipientReadEntitlement.CheckedView.mk | Kernel.RecipientReadEntitlement | evidence | L2 | 8 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.ResourceBirthController.Concrete.PreparedBirth.mk | Kernel.ResourceBirthController | evidence | L2 | 14 proof / 10 data fields; layer-1 review pending
Minidregg.Kernel.ResourceBirthController.Concrete.PreparedDraft.mk | Kernel.ResourceBirthController | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ResourceBirthController.Concrete.PreparedGrainBirth.mk | Kernel.ResourceBirthController | evidence | L2 | 1 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.ResourceBirthController.Concrete.PreparedGrainDraft.mk | Kernel.ResourceBirthController | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ResourceBirthController.Concrete.PreparedPostAuthority.mk | Kernel.ResourceBirthController | evidence | L2 | 4 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.ResourceBirthController.Concrete.PreparedPreAuthority.mk | Kernel.ResourceBirthController | evidence | L2 | 11 proof / 8 data fields; layer-1 review pending
Minidregg.Kernel.ResourceBirthPolicyController.Concrete.AcceptedBirth.mk | Kernel.ResourceBirthPolicyController | evidence | L2 | 2 proof / 5 data fields; layer-1 review pending
Minidregg.Kernel.ResourceBirthPolicyController.Concrete.DecodedIngress.mk | Kernel.ResourceBirthPolicyController | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.ResourceMoneyOperationDomain.CheckedSamples.mk | Kernel.ResourceMoneyOperationDomain | evidence | L2 | 2 proof / 0 data fields; layer-1 review pending
Minidregg.Kernel.ResourceMoneyOperationDomain.Prepared.mk | Kernel.ResourceMoneyOperationDomain | evidence | L2 | 5 proof / 0 data fields; layer-1 review pending
Minidregg.Kernel.ResourceMoneyOperationDomain.SampledFunding.mk | Kernel.ResourceMoneyOperationDomain | evidence | L2 | 4 proof / 0 data fields; layer-1 review pending
Minidregg.Kernel.ResourceMoneyReceiver.Prepared.mk | Kernel.ResourceMoneyReceiver | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.ResourceObservationAdmission.Checked.mk | Kernel.ResourceObservationAdmission | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.ResourceObservationAdmission.Prepared.mk | Kernel.ResourceObservationAdmission | evidence | L2 | 9 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.RunComputeBudget.CheckedSteps.mk | Kernel.RunComputeBudget | evidence | L2 | 1 proof / 0 data fields; layer-1 review pending
Minidregg.Kernel.RunComputeBudget.Prepared.mk | Kernel.RunComputeBudget | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.RunComputeBudget.PreparedBook.mk | Kernel.RunComputeBudget | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.RunComputeBudget.PreparedQuota.mk | Kernel.RunComputeBudget | evidence | L2 | 1 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.RunComputeBudgetDomain.LoadedBook.mk | Kernel.RunComputeBudgetDomain | evidence | L2 | 1 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.RunComputeBudgetDomain.Prepared.mk | Kernel.RunComputeBudgetDomain | evidence | L2 | 0 proof / 4 data fields; layer-1 review pending
Minidregg.Kernel.SeatReceiver.Accepted.mk | Kernel.SeatReceiverCore | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.SeatReceiver.DecodedIngress.mk | Kernel.SeatReceiverCore | evidence | L2 | 2 proof / 3 data fields; layer-1 review pending
Minidregg.Kernel.SeatReceiver.Prepared.mk | Kernel.SeatReceiverCore | evidence | L2 | 5 proof / 6 data fields; layer-1 review pending
Minidregg.Kernel.SeatStore.Decided.mk | Kernel.SeatStore | evidence | L2 | 9 proof / 11 data fields; layer-1 review pending
Minidregg.Kernel.SeatStore.HeldEnd.mk | Kernel.SeatStore | evidence | L2 | 4 proof / 5 data fields; layer-1 review pending
Minidregg.Kernel.SubjectKeyCommitmentAdoption.Accepted.mk | Kernel.SubjectKeyCommitmentAdoption | evidence | L2 | 3 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.SubjectKeyCommitmentAdoption.AcceptedAdoption.mk | Kernel.SubjectKeyCommitmentAdoption | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.SubjectKeyCommitmentAdoption.DecodedIngress.mk | Kernel.SubjectKeyCommitmentAdoption | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.SubjectKeyCommitmentAdoption.Prepared.mk | Kernel.SubjectKeyCommitmentAdoption | evidence | L2 | 4 proof / 1 data fields; layer-1 review pending
Minidregg.Kernel.SubjectKeyRotation.Checked.mk | Kernel.Receivers.SubjectKeyRotation | evidence | L1 Minidregg.Kernel.SubjectKeyRotation.Checked.sound | every gate check is a proof field; sound derives the commitment, succession and freshness via gate_ok_iff
Minidregg.Kernel.SubjectKeyRotation.DecodedIngress.mk | Kernel.Receivers.SubjectKeyRotation | evidence | L2 | 1 proof / 2 data fields; layer-1 review pending
Minidregg.Kernel.SubjectKeyRotation.Prepared.mk | Kernel.Receivers.SubjectKeyRotation | evidence | L1 Minidregg.Kernel.SubjectKeyRotation.Prepared.gated_by_possession | the gate ran under the key of the possession signature it holds; that ReceiverSignature is L2
Minidregg.Kernel.SystemCellDomain.Loaded.mk | Kernel.SystemCellDomain | evidence | L2 | 2 proof / 2 data fields; layer-1 review pending
Minidregg.TokenCensus.ProjectionWitness.mk | TokenCensus | evidence | L1 Minidregg.TokenCensus.ProjectionWitness.sound' | positive control: the request/result-indexed statement is carried by every inhabitant and the theorem proof is exactly the `sound` field projection
Minidregg.Theory.CanonicalReactiveView.PreparedReaction.mk | Theory.CanonicalReactiveView | evidence | L2 | 3 proof / 2 data fields; layer-1 review pending
Minidregg.Theory.CellState.Materialized.mk | Theory.CellState | evidence | L2 | 0 proof / 1 data fields; layer-1 review pending; mints: materialize (the root is computed from the logical store by the materializer, not asserted)
Minidregg.Theory.CellState.ValidatedPatch.mk | Theory.CellState | evidence | L2 | 2 proof / 0 data fields; layer-1 review pending
Minidregg.Theory.GuardedAdvice.VerifiedFill.mk | Theory.GuardedAdvice | evidence | L2 | 8 proof / 1 data fields; layer-1 review pending
Minidregg.Theory.ObjectiveBendDemandData.ExecutionWith.mk | Theory.ObjectiveBendDemandData | evidence | L2 | 1 proof / 4 data fields; layer-1 review pending
Minidregg.Theory.ObjectiveBendDemandData.ExtractionWith.mk | Theory.ObjectiveBendDemandData | evidence | L2 | 1 proof / 1 data fields; layer-1 review pending
Minidregg.Theory.ReactiveCellTransition.Accepted.mk | Theory.ReactiveCellTransition | evidence | L2 | 2 proof / 1 data fields; layer-1 review pending
Minidregg.Theory.ReceiptEvent.mk | Theory.AcceptedCellEffect | evidence | L2 | 5 proof / 10 data fields; layer-1 review pending
Minidregg.Theory.Receiving.Receiver.Accepted.mk | Theory.Receiving | evidence | L1 Minidregg.Theory.Receiving.Receiver.Accepted.admits | carries `admits`: prepared under covering vouchers, shape and laws passed; the vouchers are L2
Minidregg.Theory.Receiving.Vouchers.mk | Theory.Receiving | evidence | L2 | the claims the Receiver's verifier answered true on, and its true/false answers on the receiver's OBSERVED signatures (admitVia_observed); an oracle (IO) verdict no proof expresses; minted only by Receiver.admitVia; mints: Vouchers.empty (vouches for nothing)
restrict | Minidregg.Compiler.DurableHistory.Head.genesis | Compiler.DurableHistoryStore, Compiler.DurableReceiverIO, Compiler.DurableServed, Compiler.DurableHistoryStoreCore | a genesis head for a non-empty Store is a replay bypass: only the open mints one
restrict | Minidregg.Compiler.DurableHistory.StoreIdentity.ofOpen | Compiler.DurableHistoryStore, Compiler.DurableReceiverIO, Compiler.DurableServed, Compiler.DurableHistoryStoreCore, Compiler.DurableReceiverCore | a Store identity comes only from the open
restrict | Minidregg.Compiler.DurableHistory.StoreIdentity.ofScratch | Compiler.DurableHistoryStore, Compiler.DurableHistoryStoreCore | a scratch Store identity comes only from scratchReader, after the image is checked against its carried commitment
"

end Minidregg.TokenCensus
