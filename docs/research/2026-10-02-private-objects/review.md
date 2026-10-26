# Adversarial cross-contract review

2026-10-02. Research only; no implementation, builds, tests, Git writes or new runtime evidence. I read BRIEF, all four reports, Mini AGENTS/HANDOFF and verified the decisive source claims below with remote immutable `git show` at **b57acedaaae02edf2b2cfd8e33675b3cbf40daa8**. The reports' bibliographies are leads, not authority; this review relies on directly inspected source and counterexample traces. **READ** denotes source evidence, **DERIVED** analysis, **PROPOSED** missing construction conditions. These six issues qualify the preferred ordinary single-domain starting point; none demands a second platform. This reviews the original lane drafts. The synthesis and final companion wording incorporate the release/freeze and signed-root corrections; all proposed enforcement mechanisms remain unimplemented.

## 1. Freeze must distinguish authorization from physical arrival and application execution

**READ:** `Kernel/FnSelectiveReleaseSourceReceiver.lean`, `Accepted.intent` (78–88), records source authorization with source/authority read guards and a nullifier; its comment explicitly excludes the external fn POST. `receiveLoaded` (105–120) selects exact historical replay before fresh admission. `FnSelectiveReleaseReceiver.receiveLoaded` (86–101) similarly distinguishes already accepted ingress from fresh receiving admission.

**DERIVED counterexample:** release X commits at epoch 7; freeze F commits; revoke R commits; only then transport delivers X. Rejecting every “emitted confidential message while frozen” would invalidate historical completion or require cancellation semantics absent from these receivers. Conversely, treating X's old release receipt as permission to invoke a recipient method after F/R would bypass current application authorization.

**PROPOSED actionable correction:** freeze blocks *fresh release admissions and fresh confidential invocations*. An exact release committed before the cut may finish afterward, preserving destination, audience and bytes. Label that outcome historical completion. A delivered invocation still needs a fresh recipient admission against its current epoch/freeze/law unless its application effect was already committed. The promise is no new authorization after the ordered cut, with grandfathered exact releases; it cannot promise no newly arriving old plaintext. Resume cannot automatically publish old-epoch pending intents: every new release binds the current audience and law, even when its origin intent is historical.

## 2. Historical custody export is an additional disclosure surface

**READ:** `Host/Main.lean:4540–4581`, `runFnOriginOutboxExportSession`, takes a transaction selector and returns the historical carrier without requiring a since-revoked grant. It obtains carrier/verifier context from accepted history, which protects integrity but does not establish a new private audience authorization.

**DERIVED counterexample:** member B loses observation/release rights; B retains an outbox transaction identifier and requests export after freeze. If a private adaptation exposes this surface to B, exactness ensures it returns the *correct forbidden carrier*. Encryption only helps if that carrier contains no still-decryptable material unauthorized for B.

**PROPOSED:** classify private custody recovery as either internal privileged recovery, an authorized current observation, or completion of a specifically committed release. Do not import the fn historical export exemption as a generic room read capability. This is distinct from item 1: exact late transport may be grandfathered, while arbitrary new callers querying retained history need a disclosure contract. Scope the exemption by audience and principal, not just transaction identity.

## 3. “Checked intent” needs provenance, not merely an authentic field

**READ:** `ResourceTransaction.targetWrites/checkClaim` (615–697) requires field-representable writes and re-executes the program. Ordinary commands with no run claim remain supported. `DeclaredResourceController.admit` (942–962) checks exact signed command bytes and authorization; it does not make every authorized scalar write program-produced.

**DERIVED counterexample:** Mallory has ordinary write access to intent field q. She writes a canonical noun saying “send secret p to Mallory,” marks it checked, and asks a powerful adapter to deliver it. The noun is authenticated data and may satisfy the descriptor's format; it lacks the claimed computational provenance. A second attack keeps the genuine q but substitutes destination, payload or capability in the adapter request.

**PROPOSED:** adapter admission must select the exact source admission, verify its required run claim/program/descriptor and complete intent-producing write, then derive the entire append envelope from that retained result. A protected intent layout/controller can enforce this; trusting a status bit cannot. Bind canonical decoding, operation identity, destination, payload digest, authority ceiling, causal parents and consumption transition. The adapter's own capability authorizes delivery machinery; it cannot amplify the original semantic ceiling. Current authority, epoch/freeze and law remain mandatory for each new publication. If current rules require extra power, remain pending or request an explicit new authorization.

## 4. Migration needs one execution lineage and separately identified releases

**DERIVED counterexample:** original m and translated m2 reach different entry points concurrently. Each computes a version-specific nullifier and both effects commit. Keeping an origin ID as metadata does not prevent this. Conversely, using one nullifier for every re-encryption can reject an authorized new audience release or confuse its receipt with the old ciphertext.

**PROPOSED:** define distinct identifiers for originating request, application consumption lineage, migration steps, and release attempts. Original and every executable translation consume one shared application lineage atomically with effects and result. A translation retains original signed bytes as evidence, but authenticates its changed bytes through a separate authorized migration record. Releases have distinct exact identities bound to current audience/ciphertext; retries preserve those identities. Target remapping must maintain global consumption ownership or execute a guarded ownership transfer. Semantic simulation and current authorization are both required: preserving title-only meaning does not revive a revoked title grant. Numeric field containment is insufficient.

## 5. Retirement and GC can silently destroy exactly-once semantics

**READ:** `FnSelectiveReleaseReceiver.replay` (40–50) selects the original by transaction/event/nullifier agreement in retained journal state. `Compiler/DurableReceiverIO.receiveLoadedDetailedWithFresh` (663–700) confirms an exact appended entry against the loaded head. These mechanisms depend on retained identity evidence; inspected source does not establish a generic safe retirement theorem.

**DERIVED counterexample:** m executes; upgrade compacts the old journal/outbox and deletes its dedup marker; a delayed exact retry arrives after retirement. Absence is mistaken for “never admitted,” so m or a translated m2 executes again. Keeping a receipt at the sender does not protect a restarted receiver that forgot consumption.

**PROPOSED:** retain an authenticated consumption tombstone or provable compact accumulator across descriptor retirement and restart. If finite retention is desired, use admission-enforced expiration and authenticated retirement floors so old requests are refused, never reclassified fresh. GC requires both execution-lineage preservation and release custody obligations; receiver acknowledgement alone cannot prove every delayed copy vanished. Unknown after compaction must remain distinguishable from confirmed absence.

## 6. Guard reduction is compatible only with semantic dependency completeness

**READ:** `ResourceTransaction.Command` (64–78) deliberately omits the whole authority root from signed intent; `prepareFrom` (730–745) resolves current authority/clock. DRC `domainGuards/readGuards` (1015–1030) physically guard them. Signing a whole root again, as the semantics report's snapshot list suggests, would restore avoidable unrelated-authority coupling. Receiver-resolved guarded roots can instead be bound into the accepted receipt while the client signs stable intent and necessary authorization footprint.

**DERIVED counterexample:** remove the broad authority guard because X/Y targets differ; a revoke or inherited law changes between preparation and settlement. X commits under stale permission. Causal broadcast does not order concurrent revoke/invoke; a BFT ordering certificate does not authenticate a complete semantic footprint or private audience.

**PROPOSED:** retain ordinary ordered admission initially. Reduce guards only with source-owned projection validation and proofs that omitted reads cannot alter enabledness, observations, charges or effects. Freeze/epoch dependencies belong in that closure. If later domains or causal protocols are introduced, conflict ordering, current-authority fencing and confidential release admission remain separate obligations. This preserves room for deliberate kernel redesign while avoiding an unsupported claim that agreement alone supplies authorization.
