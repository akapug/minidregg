# Mini: architecture study for private objects and messaging

2026-10-01. **Status: source-grounded design study, not an accepted architecture or implementation assignment.** This supersedes treating the previous literature shortlist as a build plan. Mini is the construction home. Bread is optional reference material, not a prerequisite or migration target.

The purpose is to decide what the existing Mini should mean and where new responsibilities belong before choosing protocols or changing code. This is one bounded source trace, not an exhaustive audit of Mini or fresh deployment qualification.

## 1. Pin the system we are discussing

The Mac checkout is `175e111424ba977738bf2bc4d19478497dcaaeb3`, with unrelated untracked work. The remote integration ref `final`, directly checked during this study, is `0543ec47103803cf0d1e2ae47a20548f17a8cd4b`. The integration record describes further work mid-merge. A planned integration is not the source baseline.

Sources were read from immutable Git objects in `persvati:/home/ember/build/mini-datamodel-20260930/src`, without modifying that repository:

| Label | Commit | Use in this study |
|---|---|---|
| S1 | `0543ec47103803cf0d1e2ae47a20548f17a8cd4b` | Last committed integration baseline: resource transactions, durable settlement, CHANNELS, observation, private-turn model |
| S2 | `755b69d6` (full identity in manifest) | Room feature composition: chat, room-key operations, birth gate; not presented as S1 behavior |
| S3 | `1e57ee3c` (full identity in manifest) | Later identity/key-rotation correction; inspect whether the room transition structure changed |

[Source manifest](PRIVACY-OBJECT-ARCHITECTURE-2026-10-01-sources.json) records the full commits and Git blob identities. For reproduction, use `git show COMMIT:PATH` in the named remote repository. File paths and line numbers below refer to those Git objects, not the older Mac checkout. Only selected sections of these files were read.

Relevant retained records: `/Users/ember/dev/claudesplosion/planning/final/integration-2.md`, `/Users/ember/dev/claudesplosion/planning/privacy/private-rooms.md`, `/Users/ember/dev/claudesplosion/planning/place/k-room-3c.md`, and `/Users/ember/dev/claudesplosion/planning/privacy/k-hide-rotate.md`. Their runtime results belong to their own source/binary manifests. No build or journey was rerun here.

## 2. The capability we want to design

**Proposed acceptance scenario, not a commitment to build another board application:** two people share a persistent private object. They invoke its behavior, receive durable messages about accepted changes, change its rules and audience, lose a reply, reconnect, and recover from a client or host crash. The object has a stable identity and explicitly versioned meaning. A person may extend its specification without accidentally widening authority or silently reinterpreting existing state.

Before implementation, its contract must answer:

* What does a successful invocation promise: accepted state, persisted message, remote delivery, or remote execution?
* At which committed point does revocation take effect for invocation, observation and future decryption? These are distinct rights.
* What can the operator, another member, a recipient and a network observer learn?
* Which history can a new or recovering member read? What does deletion or forgetting promise?
* Which operations really require shared order, and which failure/partition behavior is acceptable?

These answers determine the protocol requirements. “Use a DAG,” “add MLS,” and “make objects actors” do not answer them.

## 3. Trace the existing paths before inventing new abstractions

### A. Ordinary object invocation already has a substantial semantic boundary

**READ S1, `Kernel/ResourceTransaction.lean`:** a command contains multiple targets. `computeTarget` (393–424) handles scalar operations, content operations and stream appends; it checks target role/version/pre-root and invokes the corresponding source operation. The channel-specific stream law is checked in the append arm. `prepareTarget` (483–511) validates the patch and final post law and loads the target's current policy source. `prepareFrom` (708–723) loads one directory, authority snapshot and clock, prepares every target, prepares the replay marker and checks any program run claim.

**READ S1, `Kernel/DeclaredResourceController.lean`:** `admit` (870–894) checks exact command bytes and envelope counts, verifies required observations, constructs the tuple and verifies/authorizes every target and the authority incidence. `writes`, `sourceGuards`, `domainGuards` and `readGuards` (938–955) derive the physical target writes and policy/authority/clock read guards.

**Architectural consequence:** Mini already has a multi-object transaction and effect construction. A new “effect bundle” should first be expressed through it. An alternative executor must preserve exact source computation, current authority, field coverage, read guards and replay identity; a generic callback returning replacement bytes would discard those guarantees.

**Specific constraint:** checked Nock execution currently names own-object field writes. `targetWrites` and `commandWrites` (S1 `ResourceTransaction.lean:615–638`) reject content/append effects in a run claim. Thus a regular transaction can contain an append, while a checked program's output cannot simply claim that append. A method that computes a change and emits a message needs a deliberate program-effect contract or checked adapter. This is a concrete design question, not evidence that Mini lacks atomic transactions.

### B. Durable settlement already handles retry identity and read dependencies

**READ S1, `Kernel/DurableCommitProtocol.lean:407–432`:** execution first looks for the transaction identity in the journal. An identical recorded intent is a replay; a different intent under that identity is a conflict. Only a fresh intent proceeds through preflight and installation. The logical model distinguishes crashes before and after atomic installation; `execute_no_partial_commit` states the all-or-nothing property.

**READ S1, `Kernel/GuardedDurableCommit.lean`:** the existing publication adapter specifically includes authority as a read guard, avoiding a content/event write that commits against obsolete authority. The file explicitly separates the logical settlement result from physical implementation refinement.

**READ receiving path:** `DeclaredResourceController.withAcceptedLoadedFrom` checks the recorded invocation before preparing a new one, then hands the exact accepted intent to the continuation. `NativeHost.lean:1487–1522` calls it in the invoke arm and settles through `DurableReceiverIO.receiveLoaded`, preserving contention and uncertainty as distinct results. `Compiler/DurableReceiverIO.lean:632–680` appends against the loaded log height and confirms by exact entry readback; an unavailable readback remains uncertain. In the client, `main.rs:1432–1502` retains and syncs `call.bin` before submission, and `retry_with_upgrade` (1744 onward) reuses that call with pinned configuration/upgrade evidence. This is a source trace, not a new physical crash test. `DurableWalHandler` separately supplies a WAL **model** and explicitly does not model fsync or torn records.

**Architectural consequence:** transport retry must preserve the existing operation identity and reconcile uncertainty with the receipt/journal. It must not re-sign a semantically new operation merely because the first reply was lost. A cross-machine inbox needs its own stable message identity and deduplication contract; the existence of the local durable model is not proof of that receiving path.

### C. Room chat and CHANNELS currently mean different things

**READ S2, `native/resource-client/src/chat.rs:1349` onward:** room chat prepares a stream append through the workspace proposal/submission path. Private-room selection seals the payload and removes the clear topic; stale-target handling reparses the current position and retries under bounded client behavior.

**READ S1, `native/resource-client/src/channel.rs:711–779`:** `channel say` queues a local outbox file. The member loop moves it into its transport queue, fragments/seals it and receives completed messages into `inbox.jsonl`. It separately compares observed tick roots with published epoch records. `Kernel/DomainEpochStream.lean` connects the special epoch append to the stream receiving law.

**Architectural consequence:** delivery of a channel message is not yet an admitted object invocation or a durable room-stream append. The architectural work is the bridge between these paths: which signed command travels, what an epoch record certifies, who submits the semantic operation, when the sender may forget it, and which receipt the recipient can rely on. Giving both surfaces a `say` verb does not establish that bridge.

This source trace does not qualify crash recovery of the transport queue. In particular, retaining files under `taken/` is not by itself a durable resend protocol. That needs a dedicated recovery trace before making a delivery guarantee.

**Existing messaging infrastructure that must be considered:** S1 already contains `Kernel/FnOriginOutbox.lean`. It records the exact prepared R carrier, message/source identities, package/call digests and original Mini receipt in a content-cell operation. Its `checkReport` binds this to the pinned gateway and independently re-admitted origin; its header explicitly distinguishes local custody from fn posting or remote receipt. `FnSelectedPollReleaseLink.select` selects an original owner release from a native-verified recipient history. `FnConsumerProgress` records scoped, gateway-observed empty-page progress; that is not a generic application-effect receipt. The Rust client has corresponding origin-outbox preparation/export operations.

**Architectural consequence:** a new generic outbox is not the default. First identify which semantics in these existing paths can be reused or generalized for object messages and CHANNELS. The fn carrier/evidence format, gateway trust boundary and disclosure permissions cannot simply be copied into a private padded channel. Local custody of a carrier is also not an atomic state-change-plus-send theorem.

### D. Private rooms already exist, with a client-managed transition boundary

**READ S2, `native/resource-client/src/roomkey.rs:513–537,668–711`:** room keys are wrapped to members and stored in a content cell. `turn` proposes and submits an operation. `kick` first submits a capability revoke, then calls `rotate`, which writes new wraps and updates the client's cache. These are separate operations. **READ S3, same file:905–940,1055–1061:** the later encryption-key-record correction changes rewrapping, but the inspected kick still has the revoke-then-rotate structure.

**Architectural consequence:** a failure between revoke and rotation is a real state-machine boundary that needs specified behavior. This does not establish a new exploit or say revocation itself fails. The question is what remaining writers and recipients may do before rekey completes, and how a different client resumes the transition safely.

The private-room report already states that coupling revocation to key-epoch progression is not provided by this construction. Its claim is about this route; it should not be promoted to “Mini cannot support such a transition.” The kernel has relevant atomicity machinery, but not every authority operation is automatically composable as an ordinary resource target.

### E. Private observations and private execution are different existing boundaries

S1 has narrowed/blinded observation machinery. It should be extended from its actual receiving contract, not described as absent. The separate blinding-ratchet work is source-scoped to its feature branch and does not hide values from the Host holding the blinding.

**READ S1, `Kernel/PrivateTurn.lean:1–31`:** the private-witness hyperedge is explicitly a model, without a deployed executor/admission arm. Its public-view equality is not a cryptographic implementation theorem.

**Architectural consequence:** decide whether the first private object is an opaque client-interpreted value with public authorization, or whether the service must enforce a hidden application predicate. The latter creates a substantially different evaluator/proof/custody problem. Encryption alone must not silently change the meaning of an admitted operation.

## 4. Three design decisions to make before implementation

### Decision A: define the object-message effect boundary

Specify one invocation's input identity, selected law/version, authorized dependencies, state effects and emitted messages. Begin with the existing transaction representation. Determine how a checked program is allowed to emit a stream/outbox effect; retain source-owned Lean interpretation.

Start by comparing the existing fn origin-custody/release path with the desired object-message effect. Determine whether to generalize its content-cell representation, export already committed effects from the journal, or introduce a different representation only where neither fits. A cell committed alongside state adds storage/schema/GC obligations; journal export requires complete, unambiguous event decoding and durable delivery cursors. Both need receiver deduplication and retry progress. Neither gives atomic execution at a remote recipient merely by queuing a message. In particular, audit which historical evidence may be disclosed to each recipient before reusing an fn carrier.

**Design acceptance:** draw the crash states for before commit, after commit/before send, after receive/before effect, and after effect/before acknowledgement. Each state must have a recovery action and a defined user-visible result. Show how CHANNELS transports this contract without redefining admission.

### Decision B: define audience transitions independently of the cryptographic suite

Specify what binds object identity, current audience, authority generation, encryption generation and pending rekey state. Compare one atomic published transition with a staged transition that deliberately blocks affected writes until fresh keys are ready. A staged protocol may be simpler when clients hold secrets; atomicity is not achieved by wishing secret generation into the Host.

Readers and writers must be able to identify the authoritative epoch from durable state and recover from uncertain publication. Key possession, write authority, current read authority and historical access remain separate. A kernel-visible envelope/version check cannot prove that an authorized writer never deliberately disclosed plaintext; state the honest-client encryption obligation precisely.

**Design acceptance:** revoke, fail before wrap publication, restart another authorized client, rotate an identity key concurrently, then try old and new writes. Define which are accepted and which members can decrypt at every step. Only then compare PQ ratchets, sender-key designs and administered multicast on the resulting operations and costs.

### Decision C: define extensibility and ordering from semantic dependencies

Start with application descriptors, current policy sources and existing programs. Specify which aspects are immutable per instance, which follow an authorized head, and which require migration. A layout change and a rule change need not have the same lifecycle. Restrictive policy conjunction and general ordered method extension are different languages.

Resolve dependency versions at an authenticated snapshot. Include authority and clock dependencies already present in the receiving path. For any proposed independent execution, demonstrate that swapping the operations preserves enabledness, state, replies and authorized effects. Shared clock or authority guards may cause contention even where content writes differ; removing those guards requires a replacement argument.

**Design acceptance:** a law update races an invocation; two apparent independent writes share a revoked grant; a pending message crosses a descriptor migration. Establish the intended outcomes before selecting per-object consensus, a DAG or a new execution schedule.

## 5. Architecture review output and research discipline

The next design review should produce: (1) the current and proposed end-to-end paths, (2) the three transition contracts above, (3) a responsibility map showing which existing Lean/Rust module owns each decision, (4) rejected alternatives and their costs, and (5) a bounded construction/acceptance plan. Every proposed module must justify why an existing abstraction cannot carry the responsibility.

Use the earlier literature as a question-indexed library: key-evolution papers for Decision B; persistence/OO foundations for effects, versioning and migration; agreement papers after Decision C identifies an actual shared-order requirement. Confidential computation research becomes central only if the selected object law requires the service to validate hidden state. Bread need not be revisited to settle these contracts.

The evidence gap remaining after this pass is explicit: this is selected immutable-source reading through the transaction receiver, Host/IO adapter and client retry path plus retained reports, not a complete physical storage/crash audit. The fn origin/export/consumer pipeline also needs an end-to-end comparison with the proposed private-message contract. Reconcile the now-in-flight integration and room fixes before coding. The architecture must name its exact source baseline again at that point.

Only this design note and its source manifest were added to Mini. No semantic, transport, cryptographic, build, service, branch or index changes were made.
