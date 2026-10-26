# Private programmable objects and messages in Mini

This is the preserved research-stage account. Construction decisions, actual build/runtime results and remaining integration work are tracked in [Private programmable objects construction](../../PRIVATE-OBJECTS-WORK.md); claims below retain their original research scope.

Research synthesis, October 2, 2026. **Proposed architecture, not an accepted implementation plan.** The strongest direction from this pass is to make a private object's invocation, durable message intent, disclosure authorization, audience transition and versioned meaning explicit at Mini's existing admission boundary. A consensus or keying protocol can then implement a stated contract. Neither protocol supplies that contract on its own.

This pass used four GPT-6.1 Sol research lanes, Kagi and Scry discovery, primary papers, selected Faré sources and immutable Mini source. A fifth Sol reviewed their composition. READ denotes inspected source or literature; DERIVED denotes analysis; PROPOSED denotes new semantics. No semantic code, tests, builds or services were changed or run. Source reading is not deployment qualification.

## Evidence and scope

**READ:** the integration baseline checked for this study is `b57acedaaae02edf2b2cfd8e33675b3cbf40daa8`, from `persvati:/home/ember/build/mini-datamodel-20260930/src`. Compute is merged there. The inspected integration record still separates the unmerged room feature `755b69d6b263cae46905098d937bf83736d9b89c` and identity correction `1e57ee3cc581fb4cb4c81ef7674ead0405007888`. References to those features below are not claims about the integrated baseline. The older Mac checkout is not the authority for these findings.

The [source manifest](sources.json) records immutable objects; source locations in the reports refer to those objects. [Search provenance](search-provenance.md) records discovery and coverage limits. The [October 1 architecture study](../../PRIVACY-OBJECT-ARCHITECTURE-2026-10-01.md) remains the historical path trace. Bread was not revisited in this pass.

| Decision | Detailed study | Preferred hypothesis |
|---|---|---|
| What an object message promises | [Messaging](messaging.md) | Atomic local state plus message intent; separately admitted exact release; receiver effect plus deduplication |
| When audience removal takes effect | [Audience transitions](audience.md) | Specify freeze before revoke, rekey and resume; compare one atomic cutover against the same contract |
| How persistent behavior can extend and change | [Object semantics](semantics.md) | Ordered immutable program composition, separate current security laws, explicit request migration |
| Where agreement is necessary | [Agreement scope](agreement.md) | Preserve one ordered domain first; prove actual dependency independence before distributing it |

The [cross-contract review](review.md) found six concrete failure modes; its corrections are incorporated below. These are compatible hypotheses with outstanding proof and physical-recovery obligations. They are not four independent features ready to assign to implementers.

## What the source changes about the design

**READ:** `ResourceTransaction.targetWrites` at 616–621 still rejects content and append effects in a checked program's output. Ordinary transactions support those effects. The compute merge therefore leaves a specific design gap: a checked method cannot yet claim an atomic stream emission alongside its calculated field writes. Two honest alternatives are an explicit typed-effect ABI extension, or a checked durable intent followed by a separately admitted adapter operation. The latter must report publication as pending.

**READ:** `FnOriginOutbox` already binds exact origin/carrier/receipt identity and supplies historical recovery. `Host.runFnOriginOutboxExportSession` deliberately permits historical export without a subsequently revoked grant. Separately, the selective-release source receiver checks current authority and guards it during its authorization commit. Its present preparation requires a `publicPeerable` release profile; a `recipientOnly` label is not encryption. Reuse these distinctions and exact-history mechanisms, but do not claim the existing route is already a private release protocol.

**READ:** ordinary invocation reads authority; capability revocation writes authority through a separate receiver while guarding the unchanged resource. Multi-target transactions do not automatically compose the revocation and key-publication operations. The room feature's revoke-then-rotate sequence exposes an intermediate state. A combined atomic transition needs deliberate admission work; a staged transition needs a mandatory freeze/epoch dependency at every affected entry point.

**READ:** SystemCell certification and the default 256-record tail bound are now present. The inspected certifier is an authorized operator, not a Byzantine quorum. Exact log-head CAS also serializes otherwise commuting writes. Neither cell ordering nor an epoch inclusion receipt means an enclosed application method was accepted, disclosed with permission, or executed remotely.

## One proposed end to end contract

Consider a shared persistent object whose method updates a document and requests delivery of an event or an invocation to another object. **PROPOSED:** explicitly distinguish those two message kinds. A historical notification reports an already admitted fact. A remote invocation asks for a new effect and must face current receiving authority and laws.

| Durable stage | Promise | What remains pending |
|---|---|---|
| Origin admission | Exact local effects and immutable message intent accepted together | Authorization to export and transport |
| Release admission | Exact selected bytes, destination, audience and epoch authorized for release | Physical delivery |
| Receiver custody | Exact message durably retained | Application execution, if not part of this transition |
| Receiver effect | Application effects and consumption identity committed together | Sender learning the result |
| Receipt recovery | Original result recovered for the same operation | Nothing is executed again merely to recover a reply |

**PROPOSED:** the origin intent identifies its source domain, admission semantics, operation and effect index; payload commitment; target and method meaning; dependency/version closure; and an authority ceiling. A release identifies exact ciphertext and audience/key epoch while retaining that origin. Changing audience or re-encrypting creates a distinct release, not a different meaning under an old release signature. Alternative releases of one invocation still share one receiver consumption lineage.

The source-owned adapter must establish that the intent came from the claimed checked admission, not merely that a writable field contains plausible bytes. It must bind the decoded recipient, method, payload and authority ceiling to that origin and recheck current release permission. Its own broader transport or management capability cannot substitute for the originator's semantic authorization. A typed-effect ABI could express this directly; a scalar encoding needs canonical bounds and an explicit provenance check. Both require construction.

**PROPOSED:** keep two bindings distinct. The signer binds stable command identity, target preconditions, program/descriptor selection and authorized footprint. The receiver resolves current authority, law sources, epoch/device state and mutable dependency heads, guards them through commit, and records their admitted relationship. Do not reintroduce a signed whole-authority-root requirement: `ResourceTransaction.Command` explicitly avoids that coupling because unrelated authority changes otherwise invalidate signed work.

## Revocation and freeze need the same linearization rule

The release-authorization commit is the proposed disclosure decision point. If revoke commits first, a fresh release must fail. If an exact release commits first, it may finish transmission or retry after revoke. This does not authorize another audience or new bytes. Revocation cannot retrieve plaintext or keys already held by a recipient. A new caller querying historical custody is a separate disclosure surface: require current observation permission, privileged internal recovery, or completion of a specifically authorized release. A transaction identifier alone is not a private-history read capability.

**PROPOSED:** freeze blocks fresh confidential writes and fresh release admissions for the affected object. It does not pretend previously committed releases can be unsent. A late historical notification may still arrive. A late invocation request is evaluated as fresh receiving work unless its receiver effect was already admitted; the release's earlier authorization does not confer perpetual authority to execute it. Historical receipt recovery selects the earlier result.

The distinguishing failure is concrete: Alice revokes Bob, crashes before rekeying, and Carol writes with the old room key. Bob can decrypt Carol's new ciphertext even though Bob can no longer invoke the object. Freeze-before-revoke prevents that honest-client write only if every relevant receiver enforces the freeze and epoch. A UI flag is insufficient. Atomic cutover avoids the intermediate durable state but must bind the audience and recipient-device generations used during key preparation.

After a freeze, another currently authorized manager may resume the recorded transition. A policy that locks out every manager may leave it frozen; there is no implicit owner bypass. Resumption needs fresh material, a bound manifest and an admitted active epoch, not merely a repaired local cache. Previously delegated history remains a separate access policy.

## Privacy and extensibility impose additional contracts

**PROPOSED:** choose the confidential execution contract per object. An opaque client-encrypted object lets the Host enforce exposed authority, epoch and structural constraints; it does not let the Host validate an arbitrary hidden application predicate by re-execution. A privately enforced hidden law needs a separately specified executor or verification construction. The existing PrivateTurn model is not that deployed service. Transport anonymity, endpoint confidentiality, hidden membership and private dependency access are separate claims.

Persistent keys and erasable transport ratchets likewise serve different purposes. The [earlier PQ alternatives study](../../../../claudesplosion/planning/channels/research-gpt6-2026-10-01/pq-alternatives.md) compares PQ pairwise ratchets plus sender keys with administered symmetric multicast. This pass adds the audience state machine those candidates must implement. MLS remains a comparator; no suite is selected. PQ confidentiality, writer authentication, key privacy and certification each need their own assumptions and byte accounting.

**PROPOSED:** keep immutable layout/program/composition identities and authorized mutable heads distinct from current security laws. Faré's ordered partial-specification composition can produce a closed program that Mini evaluates. Conjoining restrictive predicates is a useful safety envelope but does not implement open-recursive method extension. Preserving only a replacement program loses that distinction.

Migration must translate meaning and retain origin identity. If field 3 changes from public title to membership, a pending title operation must not acquire membership power merely because its numeric field scope survived. Translation needs an authorized migration relation, current authority checks and one consumption lineage shared by original and translated forms. A new signature can authenticate the translation; it cannot pretend the old signature covered new bytes.

## Agreement follows the semantic dependency boundary

**DERIVED:** a revoke and use of the revoked capability conflict even when they write different cells. Two apparently separate objects may also share a quota, policy source, disclosure condition or clock dependency. To classify operations as independent, swapping them must preserve enabledness, effects, allowed replies and disclosures, not just final values.

**PROPOSED:** first state this dependency contract while preserving Mini's current ordered atomic domain. Selective guards might avoid unnecessary invalidation, but cannot remove today's global head CAS. Independent domains would also change receipt/frontier semantics, cross-domain atomicity and partition behavior. Immediate completed revocation and irrevocable disconnected use cannot both be promised; leases or escrow deliberately weaken or specialize that contract.

Public dependency identifiers can reveal private relationships. Constant-rate transport does not hide a public conflict graph, receipt contents or key-distribution graph. Agreement experiments must compare equal-public workloads at each declared observer, including retries, certification, fanout and membership changes.

## What newer literature contributed

The September 29 preprint [Byzantine Causal Reliable Broadcast with Constant Metadata Overhead](https://arxiv.org/html/2609.37913v1) moves dependency bookkeeping into local state and protocol history. It does not supply private conflict ordering or a PQ instantiation. The June 9 preprint [Dynamic Software Updates using CRDTs](https://arxiv.org/html/2606.10920v1) makes in-flight message versioning explicit, but excludes Byzantine faults and leaves migration invariants to developers.

The May 2026 revision of [Grappa](https://eprint.iacr.org/2025/1028.pdf) gives persistent interval-access vocabulary; its integrity/authentication limits prevent treating it as a complete Mini membership service. Older [Reliable State Machines](https://drops.dagstuhl.de/storage/00lipics/lipics-vol134-ecoop2019/LIPIcs.ECOOP.2019.18/LIPIcs.ECOOP.2019.18.pdf) remains a closer guide to atomic state-plus-message intent than the newer actor papers found. The linked reports specify versions, inspected sections and the limits of each comparison.

## The next architecture experiment

**PROPOSED, before coding:** write one executable-sized transition specification for two private objects, one method, one audience change and one schema upgrade. Compare typed atomic effects against a provenance-checked scalar intent adapter; compare atomic audience cutover against staged freeze; use the same receipts and disclosure rules in every alternative.

Its distinguishing traces must include lost origin reply, revoke before and after release admission, crash between each rekey phase, stale recipient-device keys, lost effect ACK, duplicate old and migrated requests, ordinary-write forgery of an intent, and delayed retry after compaction. Each state needs a visible result, a recovery action and an explicit progress assumption. Compaction must retain authenticated consumption tombstones or an enforced retirement floor; a forgotten request must never become a fresh request merely because its old deduplication record was deleted. Budget fields, retention and backpressure belong in the contract before promising eventual delivery.

Only after that comparison should construction choose the smallest source-owned change. Existing Mini abstractions are the starting point, not a ban on redesigning an effect ABI or admission controller when the contract requires it.


## Construction review, October 2

Subsequent source construction and adversarial review sharpen the earlier proposals:

- [Frontier comparison](frontier-assessment.md): typed atomic state/message effects are the common contract; client-confidential values, bounded private proofs and independently operated private evaluation offer different guarantees and costs. No global Pareto claim is established.
- [Audience counterexamples and repair](audience-adversarial-review.md): active epoch plus freeze before direct revoke does not cover ancestor/channel invalidation, expiry or changed read laws. A complete retained key-holder roster and current semantic entitlement at the exact disclosure cut are required for the stronger current-reader contract. Snapshot equality alone is insufficient. These are implementation obligations, not already qualified features.
- [Historical profile migration](profile-migration-review.md): preserving old canonical bytes does not preserve old admission semantics. Current native replay uses one profile. Explicit historical dispatch or an authorized checkpoint handoff is needed; changing a digest constant is not a migration.

The authored hybrid transport uses ML-KEM-768 plus X25519, HKDF-SHA256, XChaCha20Poly1305 and Ed25519. Its binary message envelope adds294 bytes; each device's wrapped epoch key costs1192 binary bytes before manifest metadata, with JSON hex currently doubling that wrap representation. These are source-derived component sizes, not complete wire, throughput or latency measurements. Authentication remains classical; static recipient key transport is not a ratchet or a PCS construction. Narrow component tests have passed; combined native receiving, disclosure, restart and migration qualification is still pending.


## Measured construction checkpoint

The [component cost report](component-costs.md) now records230 source-linked crypto samples using a corrected single-catalog fixture and actual source-owned roster commitments. It includes raw evidence and conditional cover-channel costs; it does not establish an admitted native epoch or whole-path throughput. Typed transaction checks compile; full native acceptance remains pending in the [construction tracker](../../PRIVATE-OBJECTS-WORK.md). The opening sections remain the historical research proposal, not a claim that no construction has since occurred.
