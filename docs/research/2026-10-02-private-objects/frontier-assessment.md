# Private persistent objects: constructive frontier assessment

2026-10-02. Design assessment, not a deployment security claim. Read October 2 README and October 1 private-kernel, pq-alternatives, kernel-recomposition and dag studies. No semantic source edits or builds.

## Judgment and recommendation

**We have not locked down a design we should call Pareto-optimal or state of the art end to end. We have identified a strong construction family.** Make the shared representation a typed transition/effect contract with versioned meaning, authority and disclosure cuts. Default to client-confidential persistent objects; admit a separately declared private-relation realization where clients cannot be trusted to enforce the law or cannot possess its joint witness. Do not turn every object into MPC. Do not permanently encode message effects in scalar fields to avoid an ABI change.

That is a substantive architectural choice: separate semantic assurance from agreement, key distribution, storage and transport, while requiring their evidence to bind the same transition. Its advantage is simpler ordinary objects and room to implement the stronger contract without changing object/message identity later. Its danger is an overly generic plugin boundary. Start with a closed sum of explicitly supported realizations, not arbitrary “trusted adapters.”

No global frontier exists without fixing workload and observer: a plaintext-visible executor and a threshold-private executor are not substitutes under the same secrecy guarantee. For this comparison, price bytes, authenticated-finality latency, durable storage, CPU, operational independence and proof burden; require stable effect identity, current revocation, crash recovery and specified leakage.

## Common semantics, before choosing crypto

Every realization must bind object identity, immutable layout, ordered program composition and interpreter/relation digest; target method meaning; input versions; read/write footprint including shared law/authority/quota dependencies; operation/effect identity; authority ceiling; and output commitments. Mutable law heads select a versioned dependency closure at admission. Ordered method extension is generally noncommutative; conjunction of restrictive laws is not open-recursive extension.

A local accepted transition publishes all its state changes and typed outbox intents atomically. Transport later admits an exact release: destination, ciphertext, audience/device/key generation and source effect identity. Receiver effects and consumption identity commit together. Alternative encryptions or migrated encodings retain one consumption lineage. A notification reports an admitted historical fact; a remote invocation requests fresh receiving work under current authority. Receipt recovery returns the earlier result.

Migration is an authorized semantic translation, not an index remap: an old title-field request cannot acquire membership power after that index changes meaning. Preserve the original signature over original bytes, record translation evidence separately, and guard current laws and authority. Compaction needs consumption tombstones or an enforced retirement floor; deletion cannot make an ancient retry fresh.

Release authorization is the disclosure cut. Revoke first means reject new release; exact release first permits completing that already authorized release. It does not permit another audience or payload. Historical read access is a separate capability. Freeze-before-revoke/rekey/resume must gate every confidential-write and release entry point. Prefer atomic audience cutover where feasible, binding the recipient-device generations used in preparation; staged freeze is a recoverable alternative with a real unavailable state. Neither can retract keys or plaintext already learned.

## A. Typed clear admission with PQ client-confidential values

Clients evaluate private content and encrypt it. Lean's clear executor validates exposed capability/law/epoch/structural relations and typed effects, not arbitrary predicates over hidden plaintext. Persistent ciphertext/snapshots use an explicit history capability; transient addressed traffic uses PQ ratchets and an anonymity wrapper. Shared object content uses sender chains or owner-admin multicast according to governance, not one universal group protocol.

Use the existing single ordered domain initially. An operator certifies its order; this is not Byzantine agreement. A later replicated certifier must reproduce the same authority/effect cuts. Do not shard by object name while quota, parent law or revocation still crosses the proposed boundary.

**Guarantees:** storage/operator cannot read encrypted contents assuming uncompromised clients and correct crypto. Malicious authorized writers can submit privately illegal state; neither agreement nor client signatures refutes it. Host-visible laws, identifiers, access patterns, outcome/length and dependencies remain leakage unless separately hidden. An authorized reader can leak content. Cover transport can hide application activity from a specified network observer only when control, rekey, ACK and repair also obey its schedule; it does not hide the operator's public dependency graph.

**Cost:** ordinary private work is client computation plus O(payload) encryption, clear admission and ciphertext persistence. Pairwise reseeding costs O(d) per endpoint with contact degree d; one writer redistributing roots costs O(m) cells for m readers. Simple all-writer refresh costs O(m²) domain deliveries. Sender chains require writer authenticity against malicious readers. Symmetric group MACs alone do not provide it.

**Failure/partition:** origin reply lost → recover exact admission, never invent a new operation. Revoke commits before release → release refuses. A disconnected writer can prepare locally, but cannot claim canonical accepted change until ordering resumes. Immediate revocation and irrevocable disconnected use cannot both hold. Client backup restoration needs a monotone epoch reference and new crypto state; restoring old nonces/ratchets is unsafe.

This is the lowest engineering burden and the right default for private documents/messages whose authorized clients own validity. It is unsuitable for a hidden conserved quota enforceable against those same clients.

## B. Shared private evaluator and independent quorum

Keep the same object semantics and outbox/release contract. Store private state in shares among n independently controlled custodians; malicious-secure MPC evaluates a bounded relation. `Begin` reserves a job identity and binds versions, but does not publish effects. `Finish` checks still-pending status, current authority/laws/epochs, dependency versions and bound evaluator evidence; atomically publishes new commitments, public effects and outbox. `Cancel` permanently excludes a later finish. Speculate initially rather than letting a pending job block its own revocation.

Service-held tentative results stay shared or encrypted with withheld release material until final authorization. A valid computation against an obsolete snapshot is not an authorized disclosure. After Finish, exact release is separately recoverable. Before certifying durability, establish actual recoverability of finalized shares; a root is not data availability.

**Guarantees:** hidden laws are enforced and joint witnesses need not be given to one client, conditional on evaluator correctness and corruption threshold. Operator confidentiality requires that ordering operator cannot accumulate threshold shares. Independent administration is an assumption, not four processes on Ember's machines. For asynchronous n=3t+1 components, fewer than a third corrupt; custody refresh adds epoch-overlap and erasure requirements. Visible footprint, method, circuit shape, outcome and committee/key graph remain leakage. Private access requires oblivious circuits/storage or deliberate bounded-domain padding.

**Components:** Velox supplies malicious asynchronous MPC with fairness with abort, not guaranteed output delivery. GoSSamer supplies dynamic proactive sharing, not a full evaluator. Their combination with Mini, crash persistence and post-Finish release is new and unproved. PQ requires the entire chain: secure channels, identity/delegation, agreement certificates, commitments, common coin, compiler and release/recovery—not merely ML-KEM on ciphertexts.

**Cost:** for M multiplication gates, n participants and field width w bytes, Velox's reported leading communication term is approximately 9.33 n M w bytes, plus depth/output-dependent quadratic and additive cubic terms, inputs, auth, release and resharing. This is protocol communication, not Mini throughput. Persistent refresh adds state-size-dependent costs even without user writes. Failed speculative jobs waste their full evaluation; a hot object can repeatedly invalidate Finish. Signature/quorum transport costs below apply in addition.

**Failure/partition:** minority cannot finalize contradictory state under the declared BFT protocol, but partitions stall progress. A malicious MPC participant can repeatedly abort a fair-with-abort evaluator. Removing it requires an authorized reconfiguration preserving finalized state and fault bounds. Crash recovery must never reuse preprocessing or mix sessions. Old/new committee overlap needs recoverability before erasure; retained old backup shares can violate mobile-corruption secrecy. A committee result signed before revoke cannot bypass current Finish checks.

This is necessary for some stronger objects, but making it universal would impose its largest costs and weakest availability on ordinary messages.

## C. Hybrid with bounded client-proof private relations

Default objects use A. A limited class accepts a client proof of the exact hidden old→new relation under public commitments, binding the same authority/versions/effect bundle. Lean verifies evidence at admission; the client knows the witness. Private conserved transfer between objects owned by that client is a useful target. A relation needing a joint unknown witness still requires B or a separate joint prover.

**Guarantees:** dishonest clients cannot violate the proved relation under quantum soundness and correct relation compilation. No custody threshold is needed for proof validity, but ciphertext availability and client key recovery remain. Proof alone does not hide public dependencies or protect result information already known to its prover. Current authorization still gates admitted effects; it cannot unlearn a precomputed client reply.

**Cost:** one proof-generation cost P(relation, witness), proof size p bytes, public verification V and authenticated admission; no per-gate committee fanout. Batch/recursion may reduce p at additional assumptions/complexity. LaZer is credible for selected lattice relations, not an arbitrary Mini interpreter. Generic hash-based proof candidates require actual QROM/soundness/zero-knowledge parameters and compiler evidence before a PQ claim. Proof size, witness access and verification budget are currently unknown.

A closed supported relation set gives a useful stronger object class without importing general MPC or a universal private VM. Prematurely treating an unbuilt proof interface as existing admission would be misleading.

## Shared wire bill and agreement choices

Let B be useful fragment bytes/cell, r reserved cells/s, q quorum and s signature bytes. A transferable explicit certificate has at least `context + q*s` bytes and takes at least `ceil(bytes/B)/r` seconds of serialization, before dependent rounds/network/queues. With cached ML-DSA-44, s=2,420 B: a q=3 certificate already exceeds 7,260 B; at B=219 net fragment bytes it occupies at least 34 cells. Vertex parent references add 32q B. Pairwise authenticated votes can defer transferable signatures, but change when independently checkable finality exists. Batch signatures amortize bytes while delaying writer authenticity.

Corrected Mysticeti is a candidate replicated order service; it is not automatically best for tiny fixed-rate slots. Its 2026 liveness correction matters. Compare an actual encoded sequencer/view-change baseline and corrected DAG under identical n, PQ authentication, repair and availability guarantees. Fixed physical ticks continue during stalled logical rounds. Consensus repair, private-evaluation traffic and rekeying require reserved positive service shares; admissible arrival rates must stay below service. Larger/faster cells buy latency with larger fixed observer-visible bandwidth. Zero extra packets does not mean zero displaced payload.

## Dominance, unknowns and the lock decision

Within equal semantics and source ownership, a scalar message-envelope field is dominated by typed effects if typed effects provide provenance, canonical bounds and atomic publication directly with less adapter parsing/proof/storage overhead. A scalar bridge remains useful for compatibility; that constraint prevents an unconditional dominance claim. Universal MPC is dominated for objects whose stated validity trust is already their clients, assuming no extra threshold-private computation requirement. Classical-signature “PQ service,” MAC-authenticated malicious-reader groups, and commit-after-disclosure tokens fail the requested guarantees rather than occupying a performance frontier.

No winner is established between sender-chain and administered trees until governance, compromise targets, history access and workload are fixed. No claim of global Pareto optimality is justified. Lock only semantic identity/cuts and explicit realization guarantees now. Before freezing bytes, execute one discriminator: two private objects, conserved transfer, addressed notification/invocation, revoke, schema upgrade, client/custodian restart and partition; compare A's intentionally rejected guarantee with B/C enforcing it. Measure bytes through recovery and reconfiguration, not only success-path encryption.

## New-source check and scope limits

Kagi/Scry are unavailable in this agent's tool inventory; targeted web discovery was the fallback. A decisive new lead is [Li–Song, CRYPTO 2026 revision September 4](https://eprint.iacr.org/2026/1296.pdf). Read complete §§1–1.2 locally: constant-round GOD under broadcast/random-oracle assumptions, honest-majority n=2t+1, with `O(|C|nκ + Dn³κ³ + W_I poly(n,κ))` communication. Authors explicitly call concrete costs far from practical. It does not establish an asynchronous PQ persistent Mini evaluator and does not displace B's current engineering candidate. This corrects any inference that abort-free lightweight MPC is impossible, while declining an asymptotic substitution for a measured service. Discovery also surfaced Continuum 2026/2122; full source unavailable, so no architectural claim relies on it.

State-of-art components are credible inputs; typed private persistence, extensible semantics, scoped agreement, migration and padded transport remain our proposed composition, with safety/refinement and observer proofs outstanding.
