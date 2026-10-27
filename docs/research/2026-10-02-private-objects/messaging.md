# Mini object messages: retain existing custody, separate release from effect

2026-10-02; bounded architecture research, no implementation or runtime qualification. **READ** means selected immutable source or primary text inspected; **DERIVED** is a consequence of that reading; **PROPOSED** is a design choice. Source baseline throughout is `b57acedaaae02edf2b2cfd8e33675b3cbf40daa8` in `persvati:/home/ember/build/mini-datamodel-20260930/src`. Read Mini's AGENTS, HANDOFF, October 1 privacy-object study, and the relevant FAREOO audit persistence/transaction discussion (§§7.8–8.1); its earlier Mini claims were not treated as HEAD evidence.

## 1. Compute has changed; message effects have not entered its checked ABI

**READ:** `Theory/Eval.lean`, `Eval.FieldWrite`, contains target index, field index and integer value. `Kernel/ResourceTransaction.lean:616–638`, `targetWrites`/`commandWrites`, still returns `none` for `.content` and `.append`. `checkRunClaim` requires `commandWrites` at line 695 before executing `checkProgram`. The compute merge introduces evaluator abstraction, libraries, sample/context behavior and cost work; it does not make checked output name message appends. This conclusion is about the admitted program-effect contract, not whether byte evaluators can produce arbitrary bytes.

**READ:** ordinary `computeTarget` handles scalar/content/stream appends; `prepareFrom` loads directory, authority and clock and checks all targets. DRC `admit` and its derived writes/guards still own semantic admission and durable intent construction. **DERIVED:** an ordinary invocation can atomically change state and append a message, subject to source laws and authorization. A checked program invocation cannot currently mix that append into its claimed output. A checked scalar intent plus separately authorized adapter is feasible, but its later publication is a second transition, not an atomic checked state-plus-message effect.

## 2. Existing five-stage path, with actual reusable mechanisms

### Origin acceptance

An exact signed resource command is admitted and its intent settled. Historical retry selects the original accepted record; fresh work uses current authority and roots. This already supplies identity, source computation, guards and uncertainty reconciliation. Transport must carry the original invocation or an explicit selected release, not interpret a delivered text string as permission to invoke an arbitrary object.

### Local publication custody

**READ:** `Kernel/FnOriginOutbox.lean`, `Prepared` (25), `checkReport` (102), `outboxCommand` (148), `originalPrepared` (165), `decide` (195). `Prepared` retains application, operation, Message-ID, source identity, exact R carrier, package/call digests, original receipt and verified signer/key context. `checkReport` joins independently re-admitted package identity and signed call to the pinned local gateway. Its verification Booleans are trusted Host observations, not portable attestations an untrusted sender can supply.

The custody operation is a normal content-cell atom creation with a stable domain/semantics/application/Message-ID-derived nonce. Same identity plus changed exact content is refused. `originalPrepared` selects the complete historical signed command, including target, capability and original root. `selectUniqueParent` joins Q's verified In-Reply-To to exactly one admitted prepared R. These are useful identity, retention and retry patterns for CHANNELS; fn article syntax, megabyte package disclosure and gateway trust are not requirements of private messaging.

**READ:** `publisher.rs [deleted 61449290]`, `accepted_outbox` (101–150), retains `call.bin`, looks up uncertain results, and resubmits the same call only following an explicit absent result. `publish` retains exact carrier bytes, requests historical export, and records transport attempt/results. This avoids reconstructing a different carrier on restart. It is source evidence, not a fresh fsync/crash demonstration.

**DERIVED:** this outbox is a later accepted custody transaction after origin acceptance. A crash between origin commit and custody creation needs recovery from origin history or retained input. It is not already a theorem that origin state and its custody atom commit together.

### Export authorization

**READ:** `Host/Main.lean:4540–4581`, `runFnOriginOutboxExportSession`, explicitly exports an accepted custody record without requiring a grant that may since have been revoked. The request selects a transaction; the carrier comes from accepted history. That is a deliberate historical recovery contract.

**READ:** `Kernel/FnSelectiveRelease.lean`, `SourceRef`, `Audience`, `Destination`, `OwnerScope`, `Release`, signs selected bytes and separate source/destination/audience coordinates. Source coordinates do not prove source admission; routing group is not access control; `recipientOnly` does not encrypt. `Kernel/FnSelectiveReleaseSourceAuthority.lean`, `prepare`, `authorize`, `check`, `readGuard`, and `FnSelectiveReleaseSourceReceiver.Accepted.intent`, provide a source-side current-authority release authorization, with authority guarded during commit. The fn POST is explicitly outside that intent. The current source preparation also requires `publicPeerable`, exact current source atom bytes/root and a 64-byte packet signature; this is not an existing encrypted/private release profile.

**PROPOSED:** reuse this distinction. Custody/replay is evidence of what happened, while a release authorization is permission to disclose exact bytes to a specified audience. For private CHANNELS, encode object/source semantics, selected payload commitment, ciphertext format/digest, destination, audience/keyset root and epoch, release nonce, expiry and causal dependencies. A historical receipt must never silently become a fresh disclosure grant.

### Remote receipt

**READ:** `FnSelectiveReleaseReceiver.receiveLoaded` checks historical exact replay before today's keys/laws. Fresh work checks owner signature plus both current typed incidence authorizations. `FnSelectiveReleaseAdmission.Accepted.intent` (270) combines content/authority writes, guards, special event, ordinary marker and release-specific nullifier in one durable CAS. Exact event/nullifiers select original retry; a changed packet under that key conflicts.

`FnSelectedPollReleaseLink.select` pairs original accepted events with receipts from complete `NativeHostReplay.Verified` history. `Host/FnSelectiveReleaseFnAck.selectOriginal` requires that verified history, exact transaction/event, projected article Message-ID/packet and historical receipt. It selects evidence; it does not itself poll or ACK. An arbitrary claimed four-field receipt cannot mint the linkage.

### Remote effect and progress

**READ:** `FnConsumerOperation.bindingCommand` atomically records operation binding, reply and optional portable/store-poll input through ordinary DRC. `operationNonce` depends on application/operation, deliberately not source identity. `decide` distinguishes exact repeat, carrier variation and conflicting source/package; historical policy cannot silently move an already bound operation to another namespace. Store-poll evidence includes exact cursor/event and locally observed executable/control binding; it is not a portable Store attestation.

**DERIVED:** these content atoms are the effect of this particular consumer profile. They do not establish execution of an arbitrary application method. A generic receiver needs its application writes and dedup/reply record in the same admitted transition, or it has only durable receipt followed by a separately recoverable execution phase. `FnConsumerProgress` concerns scoped observed empty pages; it is neither delivery acknowledgement nor application success. Reuse its exact cursor/scope discipline for scan recovery, not its name as a universal receipt.

## 3. Three viable representations

**A — Extend existing custody into atomic message intent.** Express ordinary state and selected message intent as targets of one ResourceTransaction, reuse exact historical selectors and carrier custody. Publication remains a release transition under current authority. For checked compute, deliberately extend the effect ABI or initially admit a bounded scalar intent whose source-defined adapter constructs the release. The adapter must check intent identity/payload binding; it cannot merely trust callback bytes. Costs: effect codec/version and law changes, custody retention/GC, acknowledgment state and adapter liveness. An ABI extension must preserve full effect coverage rather than allow an unchecked append beside checked writes.

**B — Journal-derived export.** Source-owned decoding turns accepted events into immutable message intents; keep durable delivery cursors and recipient outcomes. This eliminates a second mandatory custody write and closes the origin-to-custody crash gap if every admitted event deterministically identifies all messages. Costs: event completeness/versioning, historical replay access, cursor compaction and disclosure minimization. The existing original-command selectors show the right approach, but not a generic complete event exporter. Exporting complete signed origin histories indiscriminately would expose unrelated private data.

**C — Keep fn origin custody as a separate post-acceptance stage.** This is closest to deployed-source patterns and needs the fewest semantic changes. Recover missing custody by selecting the original origin and reconstructing exactly the chosen carrier. Costs: explicit recovery work, no atomic origin-plus-send-intent guarantee, and inherited fn/gateway assumptions unless replaced with a narrower encrypted profile.

**Preferred hypothesis:** A for the intended object contract, using existing custody/release machinery rather than a second platform; B as an optimization only after demonstrating complete deterministic message extraction. A's scalar-adapter variant is an honest bounded first step, but callers must see “intent committed, publication pending,” not “message emitted.” C remains appropriate for selective export of an already accepted operation.

## 4. Revocation, lost reply and restart: discriminating trace

**PROPOSED concrete state:** origin object O at root r0, sender domain D/semantics S, invocation T, effect index i, destination B/object U. Message identity M = hash(D,S,T,i,U,payloadCommitment); immutable intent includes exact payload/ciphertext digest, descriptor version, audience root A7, keyset K7 and causal parent M0. State changes r0→r1 and M's intent commit together. There is not yet a release authorization.

1. Origin reply is lost; sender crashes. Restart reuses exact retained call T and retrieves its historical outcome. No second computation or fresh M is created. With separate custody C, this point lacks a custody record; C must recover it. With A or complete B, intent survives directly.
2. Owner revokes the release capability before publication. New release X for M is rejected against current authority. Custody survives and may be inspected through an authorized recovery surface. Source state r1 is not rolled back. Re-encrypting for a changed audience is a new release binding, not mutating M under its old identity.
3. Alternative interleaving: X commits first, with authority read guard and exact destination/bytes. Its commit is the authorization linearization point. A later revoke cannot retroactively invalidate that already authorized release. Retrying X must preserve its bytes; it must not authorize a new audience. A raw “check current authority then POST” without recording X has a hidden revoke race.
4. X reaches B; B commits application effect E, incoming M binding, dedup marker and result receipt R in one local transition. ACK/reply is lost and both endpoints restart. Sender retransmits X/M; B selects original E/R and returns R rather than executing again. Changed bytes under M conflict. If B only durably stores an inbox and crashes before E, its receipt must say “received”; a pending execution record drives E later. ACK may then permit transport cursor advancement without claiming E happened.
5. After revoke, recipient possessing K7/ciphertext or plaintext can retain/copy it. The promise is no new release authorization after the ordered revoke; it is not erasure of historical delivery or prevention of completion of X. A stronger cancellation promise needs receiver participation and an explicit race outcome, and still cannot retract already learned plaintext.

Adversary: duplicated/reordered traffic, malicious payload/receipt substitution, stale or revoked grants, operator-selected gateway trust, host/client crashes and lost replies. Trusted current code is not a confidential executor. CHANNELS' `channel.rs.take_outbox` moves local text files into transport queue; epoch-root agreement does not imply any of the semantic acceptances above. No new runtime evidence was gathered.

## 5. Literature that changes the decision

**READ:** Mukherjee et al., [Reliable State Machines](https://drops.dagstuhl.de/storage/00lipics/lipics-vol134-ecoop2019/LIPIcs.ECOOP.2019.18/LIPIcs.ECOOP.2019.18.pdf), ECOOP 2019, §2.2 runtime/atomicity, §3 failure transparency, §4 implementation. It couples consumed input, persistent state and outgoing messages; its network mechanism supplies a separate delivery guarantee. Mini should adopt that separation, not import the theorem without the queue/physical assumptions. This older work answers the state-plus-send gap more directly than newer actor nomenclature.

**READ:** Tardieu et al., [Reliable Actors with Retry Orchestration](https://arxiv.org/html/2111.11562), arXiv v3, 2022-11-11; §§2.2–2.3 and §3. KAR preserves call-stack ordering across retry; its external-store example requires settling or disconnecting old effects before retry. Durable receipts do not stop a delayed external write. Mini application side effects outside admission therefore need recipient idempotency/fencing or a reported unresolved outcome.

**READ:** [TC39 eventual-send proposal](https://github.com/tc39/proposal-eventual-send), inspected October 2, “Design Principles,” handler separation, modifiers and “Platform Support.” The asynchronous API separates powerless user proxies from privileged communication and shows forwarding can disrupt intended order. Use explicit causal prerequisites at receiver admission rather than assume arrival/FIFO preserves them. This is API design, not durable causal-delivery proof.

**READ:** [Collaborative State Machines](https://arxiv.org/html/2507.21685v1), v1 July 2025, §III actions/transitions and §IV runtime. Useful decomposition language; inspected sections do not establish atomic durable state-plus-network effects. It does not change the preferred architecture.

Kagi discovered the literature; Scry catalog independently resolved all three arXiv identities, with frozen observed coverage through September 26. Missing catalog full text for KAR did not prevent primary full-text inspection. Remaining obligations: generic effect admission/coverage, release linearization and cancellation law, exact receipt authentication, causal dependency availability without metadata disclosure, retention/GC, adapter recovery, and physical crash/ACK traces on exact builds. None follows merely from a module name or an epoch inclusion record.
