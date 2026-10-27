# TokenCensus: the 23 open `defect` rows, triaged

Measured 2026-10-27 at origin/main plus this lane. Every home module below is in the `Host.Main` closure
(`scripts/lean_imports.py`): all 23 forgeable tokens are in the deployed binary, none is research-only.
The wound (`TokenCensus/Core.lean:1-8`): `private mk` guards names, not terms, so `by constructor` mints the
token outside its home module. A row closes (batch 2, `d540d0b3`) when the type itself carries its guarantee,
so an L1 witness theorem names the indices; the census accepts: add proof fields that tie the checked data to the
indices (the fix class used here), drop a phantom index, or a `restricted` row with pinned callers.
"Local" means the fix adds fields to the type and its single minting function in the home module, with no
signature change another module sees. Use-site counts are files mentioning the type (`rg -l`).

| # | type (Minidregg.) | what a forger gains | fix shape | status |
|---|---|---|---|---|
| 1 | Kernel.PayClaimCommand.Checked | a "possession signature verified" verdict for any key/frame/domain: the pay-claim decision reads `checked.valid` on privacy alone, so a forged `valid := true` claims a payment | add key/frame/signature fields pinned to the ingress and domain/semantics | FIXED, local |
| 2 | Kernel.ApplicationFailedStartRecoveryReport.Checked | the custodian-signed failed-START certificate for any report, so a forged recovery of an application launch | add `frame` pinned to `signingFrame domain semantics report` | FIXED, local |
| 3 | Kernel.ApplicationLifecycleCompletionReport.Checked | the custodian-signed lifecycle completion (V1) | same | FIXED, local |
| 4 | Kernel.ApplicationLifecycleCompletionV2Report.Checked | the same (V2) | same | FIXED, local |
| 5 | Kernel.ApplicationLifecycleRetryCompletionV4Report.Checked | the same (retry V4) | same | FIXED, local |
| 6 | Compiler.CanonicalPolicyAdmission.PolicyStepContext | the old/new state and semantics a policy is judged against: any law admits any step (constant `project`); the root of policy admission. 47 files use it | tie states to a prepared tuple: needs a census token for the tuple and an `ofPreparedTuple`-only mint | cross-module, planned |
| 7 | Kernel.ResourceObservationAdmission.Prepared | a prepared observation for any marker/capability/context (phantom indices): the observation gate. 44 files | drop the three indices or add the intended field (the row's own note) | cross-module, planned |
| 8 | Kernel.CapabilityRenounce.PreparedOn | a prepared renounce for any deployment/ambient, i.e. a revocation of a capability without the marker spend. 13 files | drop `deployment`/`ambient` phantom indices from `PreparedOn` and its abbrev | cross-module, planned |
| 9 | Compiler.DurableServed.Served | a served store root for any height, chain and world root: a forged served head. 16 files | add a field retaining the `Loaded` it came from and `logStart` equality | cross-module, planned |
| 10 | Theory.Receiving.Vouchers | the evidence that the signature oracle said true, for any query list: the base of every receiver's admission (CheckedSignature, Receiver.Accepted rest on it). Worst by authority | record the oracle verdict in the type (an `observed`-all-true proof field from the only `admitVia`) | cross-module, planned (the receiving apex) |
| 11 | Kernel.ObjectiveCall.Method | an objective method call whose `applied` term is not tied to the lowering the frame's view and args name: runs an arbitrary typed term. 19 files | add the `applied = .app (.app source.term view.term) args.term` field | local in shape, not done: needs the `methodOf` proof under the Bend lowering |
| 12 | Kernel.SubjectKeyCommitmentAdoption.Accepted | acceptance of a key-commitment adoption without the two signature verdicts tied to the ingress frames: key rotation of a subject | tie verdict Bools to the verified frames (as CheckedSignature does) | local, not done: needs the Verified witnesses threaded through `accept` |
| 13 | Kernel.ApplicationGrainSessionEnrollmentAdmission.Checked | a joint enrolment command not tied to the ingress/spec/issueReceipt: a forged session enrolment | add the equalities `admitAt` tests as fields | local in shape, not done: 4 files, proofs through `admitAt` |
| 14 | Kernel.CarriedApplicationDispatchReceiver.Permit | the fresh-CAS-winner permit to dispatch an application with the carried fresh tip | tie `Committed.freshCasWinner` to the CAS outcome in `Committed` | local, not done: the proof lives in `DurableReceiverIO` |
| 15 | Kernel.NativeHostReplay.PriorSelectedRelease | a prior selected release the replay never admitted: a later event17 rechecks only shape. 1 file | retain history membership in the type | local, not done: the walk is 4,000 lines |
| 16 | Compiler.CarriedSegmentIO.Prepared | a prepared carried segment with no relation between source, body and target. 12 files | add the three Bool checks as propositions | local in shape, not done: IO/Bool checks need prop-valued rewrites |
| 17 | Compiler.CarriedSegmentIO.Authorized | an operator-authorised carried segment: the operator signature verdict is discarded | tie the edge seal to the prepared | local in shape, not done (with 16) |
| 18 | Compiler.CarriedSegmentIO.AuditedSource | an audited source whose `durable` is not the capsule's (2 files) | prop-valued audit results | local, not done (with 16) |
| 19 | Compiler.CredentialSignatureAdmission.ReceiverSignature | a receiver-signature claim for a claim not in the receiver's vouchers (2 files) | retain the membership proof | local, not done: depends on #10 |
| 20 | Compiler.NeutralPolicyCarry.Plan | a carry plan whose target ids are not fresh, authority heads not exact (2 files) | the four Bool checks as propositions | local in shape, not done |
| 21 | Host.FnSelectiveReleaseFnAck.Selected | a selected fn ack for bytes the receipt does not match | prop-valued checks | local, not done; fn is not on this demo |
| 22 | Host.GrainOriginPreparation.Prepared | a disclosure preparation where scope is not tied to the rendered package | prop-valued checks | local, not done |
| 23 | Host.GrainOriginSource.Rendered | rendered grain-origin bytes with unchecked provenance | prop-valued checks | local, not done (with 22) |

Counts: 5 fixed (the census counts 23 defects before, 18 after); 5 cross-module, planned (#6-#10); 13 left, each
local in shape but each needs its Bool/IO checks restated as propositions and re-proved at the mint, which is a
proof lane, not a field addition. #12-#15 and #19 are the next cheapest.

Worst forgeable token by authority: `Theory.Receiving.Vouchers` (#10): every receiver's admission rests on "the
signature oracle said true", and the type records nothing of it. Then `PolicyStepContext` (#6), which decides what
any law is judged against.
