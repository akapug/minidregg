# Profile migration and private-object integration review

Read-only snapshot inspection, 2026-10-02; no compilation/native qualification. Status documents are leads; findings below follow actual source. Shared files may continue changing.

## Decision

**Use an explicit authorized profile activation boundary with immutable old/new semantics and versioned historical dispatch.** Exact legacy policy/command bytes preserve identity; they do not preserve the admission function, profile hash, operation marker or native replay behavior. Do not activate this candidate against an existing history using the current single-profile replay configuration.

A short-term fresh-domain fixture can qualify the new construction without rewriting history. It must be called new-domain qualification, not upgrade qualification. The destination remains cross-domain autonomous invocation with attenuation and durable receipts; current same-domain typed intents are a construction stage toward it.

## Concrete falsifiers found

1. `Compiler/CanonicalRuntimeProfile.lean:170` computes one global sourceComponents list. It includes PolicyRecordCodec.wireFrame/customization, evaluator manifest and all registry kinds. The new default policy frame and typed registry additions can change the semantics digest even when an individual legacy record still encodes byte-for-byte identically. Merely keeping a legacy codec branch does not retain the old profile's semantics.

2. `Kernel/NativeHostReplay.lean:1817` rejects signed historical invocations with semantics unequal to config.profile.semantics, then calls current DeclaredResourceController.prepare with config.profile. Other receiver event branches likewise use that one profile. Therefore an old recorded signature/profile cannot replay under the newly compiled profile. Keeping only an old digest constant would still execute new receiving semantics, and is insufficient.

3. `Kernel.ObjectMessage [not in tree]:64` also requires an accepted origin's semantics to equal config.profile.semantics. Thus profile activation can strand a valid old origin even if history replay becomes multi-profile elsewhere. Its immutable Origin identity correctly retains domain, semantics, transaction and effect index; preserve these across activation instead of relabeling the origin.

4. `Kernel/ResourceTransaction.lean:558` rejects every invocation intent whose destinationDomain differs from snapshot.domain. It checks a full capability preimage, holder equal to command.subject, stored equality, lineage and current admissibility for same-domain invocation. This is useful attenuation work, but cross-domain authority cannot be checked by looking up destination capability IDs in the origin's authority cell. Add a destination evidence/controller boundary; never simply delete the domain check.

5. Typed origins exist and derive from verified accepted history plus exact command effects. They require checked run, retained typed program and a bounded pinned source target. Scalar compatibility consumption modules exist; no typed ObjectMessageConsumption module appears in this snapshot. Durable typed origin selection alone is not native release, autonomous execution or retained result recovery. Notifications bypass intentCeilingCheck; their later release must still enforce origin observation/disclosure authority. Calling the field “ceiling” is not a release check.

6. Audience source metadata and ResourceTransaction preparation enforce current active exact epoch. ObjectAudienceController forbids metadata drop and binds actual authority/object-device snapshots on enrollment/resume. This controls accepted writes, not secret-key distribution: changed nonzero manifest cannot prove fresh keys or removal exclusion. The safe staged phase remains freeze → revoke → fresh package preparation → authorized resume. Exact release recovery after freeze/revoke is a separate branch; fresh release must check current source phase and epoch. Historical replay must use the original transition rules, not retroactively apply this new phase discipline to old accepted records.

## Preferred construction: bounded profile epochs

Retain an immutable Legacy implementation capsule: original profile components/template, signature verification rules, registry/materializer/codec identities and receiving semantics. Freeze the exact baseline source and executable/artifact identity. Parameterize receiving by a **closed SemanticsVersion**, dispatching actual functions/registry behavior, not just hashing a configurable label. New private-object functions belong only to the new capsule. Share unchanged codecs and proofs where equivalence is established.

Add one source-owned activation transition admitted under the old active profile. It binds old profile, new profile, old finalized history cut/world root, registry/codec migration manifest and authorized controller. The old rules must explicitly support this transition, or an external authorized domain handoff/checkpoint construction must bootstrap it; a new binary cannot retroactively invent an old permitted upgrade event. There is no generic operator override.

Activation closes fresh old-profile admissions but preserves exact historical retries/receipts and old origin lookup. Replay selects the profile from authenticated activation intervals and checks signed semantics agrees with that selection. Do not let an ingress choose any historical profile to evade new laws. Typed wrappers around Verified/Accepted will need existential profile evidence or an epoch-indexed VerifiedHistory structure; a boolean bypass loses the property origins currently obtain from native verification.

Old in-flight commands do not automatically become new-profile signed commands. Choose reject-and-resign or an explicitly authorized translation recording original signed bytes, original profile, current migration authorization and translated signed command. Preserve one execution lineage across profiles. Current operationMarker depends on semantics: equal subject/nonce/targets is not sufficient if profile changed. Introduce a domain-separated stable lineage alias/consumption key with a theorem linking authorized migration to exactly one original operation. Keep old transaction receipts untouched.

Retained origin lookup dispatches through the origin's authenticated historical profile and immutable program record. Fresh release rechecks current authority/audience under the active profile while binding exact old intent bytes and old identity. Existing exact release completion returns the original release. This deliberately distinguishes historical validity from current disclosure authority.

## Implementation sequence and meaningful checks

1. Capture legacy source components, profile/template digest, registry manifest and native executable. Create a native replay fixture from an actual accepted legacy journal containing invocation, policy install, revocation and retry; retain expected complete record bytes/receipts/world root. A new-only genesis fixture cannot refute replay breakage.
2. Implement profile-version dispatch and an activation/handoff record with authorization/monotone boundary. Prove profile interval uniqueness, immutable old prefix and refusal of fresh old-profile ingress after activation. Native replay must match every historical intent exactly, not only final state.
3. Complete typed durable origin → release → receiver execution → retained result adapters. Bind semantic principal/authority ceiling independently of the transport signer: an adapter's broad capability may move bytes but cannot authorize a destination method for the origin. Add notification disclosure checks and a concrete signed release codec.
4. Keep same-domain invocation as the first fixture; add the actual cross-domain path with authenticated destination semantics/controller evidence, current destination capability/epoch/law checks and stable origin lineage. Different domains remain separate commits. Sender local effect plus intent is atomic; remote effect is conditionally eventual, not cross-domain all-or-nothing. Autonomous worker discovers durable outbox, authorizes exact release, retries stable identity and reconciles ACK loss without human CLI steps.
5. Test activation between origin/release/receipt, revoke before/after exact release, delayed legacy retry after activation, changed-profile migration, duplicate translated/original arrival, notification forged through ordinary write, intermediary privilege substitution, audience freeze/resume crash and recipient-device change. Restore after compaction must preserve origin evidence and consumption retirement.

## Alternatives and costs

| Choice | Honest benefit | Cost/limit |
|---|---|---|
| Closed in-process legacy/new capsules and authenticated activation | Exact historical replay plus forward semantics; strongest long-term choice | Receiver/registry parameterization and dependent proof plumbing; retain each supported capsule |
| Sidecar legacy verifier plus signed checkpoint/handoff | Avoid invasive immediate dual semantics; reuse old executable | Two executable lifecycles, explicit checkpoint trust/authorization and cross-process evidence; new host cannot call this full replay unless it actually verifies the legacy prefix |
| Fresh new domain with authorized object import | Fastest useful native qualification; no mixed-profile replay | New identities/domain and explicit migrated rights/history/lineage; does not upgrade the old domain |
| New compiler with old digest constant or legacy wire preservation only | Cheap to implement | Unsound historical-compatibility claim; new global preparation rules re-execute old events |

The first option best serves persistent autonomous objects. The sidecar is a credible bridge if complete dependent-profile refactoring stalls. Fresh-domain testing can proceed alongside either, but cannot replace the upgrade/handoff work.
