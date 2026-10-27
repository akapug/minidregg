# Formal status and next-proof inventory

Status snapshot: `bf45a611ec8f2bf401012376ea14b45827910b6f`, inspected
2026-08-18. This is a dated snapshot, not the present state: the 2026-10-01
decision to admit by re-execution demoted proof-based admission (see
`Deployed.lean`), so the BaseFold-first ordering of the work below no longer
steers anything, and `Kernel.Gate [deleted e5e66049]` (cited by the first row at the time) has
since been deleted. Read the Lean sources and `ATLAS.md` for current status.

This is a source audit and work-order map, not a release, build certificate,
security audit, deployment claim, or legal conclusion. The inspected worktree
also contained separately owned uncommitted Projection-V2 work and licensing
changes. No current umbrella build was run for this inventory. Exact build
claims remain those recorded in `GOAL.md`, `QUIESCELOG.md`, and
`REORIENTATION.md` at their stated commits.

## Claim vocabulary

The maturity letters follow `PROJECT.md` and `docs/PROVER-PLAN.md`:

- **S — semantic/formal:** a Lean definition or theorem about the modeled
  object. This does not imply cryptographic security or physical execution.
- **A — admission/control:** a Lean-owned executable decision or controller
  binds an exact request, statement, artifact, or refusal condition.
- **P — proof/security:** a concrete reduction or probability game closes the
  named security event at stated parameters. A carrier or uninstantiated
  premise is not P.
- **D — deployment:** an exact artifact, byte path, physical handler, and
  consumer are joined. Tests and logical device models alone are not D.
- **B — benchmark:** reproducible, matched measurements cover the admitted
  path. Operation counts and microbenchmarks do not imply end-to-end B.

“Proved” below means proved in the Lean source at this snapshot, subject to the
axiom footprint pinned beside each headline theorem. It never silently includes
signature unforgeability, collision resistance, random-oracle realization,
stable-media behavior, availability, confidentiality, or liveness.

## Current formal surface

| Area | Exact current status | Honest ceiling | Next proof or join |
|---|---|---|---|
| Typed turns, authority, and effects | **S/A.** `Theory/DeclaredTurn.lean`, `Theory/CanonicalTransition.lean`, `Kernel/MultiCellHyperedge.lean`, and their witnesses bind typed requests, exact footprints, canonical logical pre/post states, conservation, fail-closed admission, and no-TOCTOU use of the checked pre-state. | Authorization portals and cryptographic origins remain modeled interfaces at several crossings. A logical accepted turn is not a signature, key-custody, transport, consensus, or persistence theorem. | Instantiate a production authority path with exact signature bytes, directory membership, rotation/revocation, an EUF reduction, and a custody/erasure ceiling; join it to one physical committed turn. |
| Guarded advice and reactive turns | **S/A.** `Theory/GuardedAdvice.lean` fixes type/codec, turn, pre-root, abstract authority demand, finite footprint, guard/effect commitments, deadline, continuation, and replay domain before typed advice arrives. `Theory/ReactiveController.lean` derives the guard/effect checks and finite writes; accepted intents have exact shape and frame theorems. `Theory/ReactiveCellTransition.lean` binds the logical cell transition. | `CommitIntent` explicitly is not evidence of physical CAS. Authority is an abstract demand; commitment-opening soundness is not derived. The closed guard language is currently byte equality/length plus Boolean composition, not a market policy language. | Refine one real atomic CAS/nullifier handler to `HandlerPremise`; bind guard/effect commitment bytes to their Lean declarations; instantiate nontrivial authority and guard vocabularies at a consumer. |
| Durable state and Hyperdocuments | **S/A with narrow exercised adapters.** Canonical payloads, framed WAL recovery, retry/conflict behavior, content/event publication, link reopening, and SQLite lifecycle adapters exist across `Kernel/FramedWalRefinement.lean`, `Kernel/DurableDataIntent.lean`, and `Assurance/Hyperdocument*`. | The formal device is a model. SQLite/process tests do not prove FFI, POSIX, filesystem, `fsync`, torn-sector, page-cache, power-loss, scheduler, replication, or eventual-outbox behavior. The concrete reactive carrier itself lists commitment-opening soundness, authenticated finality, durable refinement, fairness, and outbox delivery as deployment obligations. | Prove one I/O refinement from an actual bounded SQLite or append-only-file protocol to the existing device steps, including crash points, atomic root/nullifier install, corruption refusal, and exact reopen/retry behavior. |
| Private turns, sealed escrow, BFV, and note spend | **S/A scaffolding.** `Kernel/PrivateTurn.lean` models private execution modes (the sealed-escrow settlement seam, `Kernel/PrivateEscrowSettlement`, was deleted 2026-10-27 as dead research; it is in git history). The BFV path has an exact 384-row relation and controller framing; note spend has a statement-specific relation and conditional controller. | There is no FHE executor in this repository, no BFV native-correctness refinement, no FHE confidentiality theorem, no vFHE construction, and no deployed succinct verifier. BFV and note-spend suite pins correctly block deployment. Current artifacts support at most a Shielded prototype with an explicit executor, not a true Dark system. | First close versioned BFV/note codecs, statement digests, patch adapters, and an assigned proof suite. Then prove PCS/CR/ROM/PoK and hiding at one exact ring/parameter set. Treat threshold release as a distinct authorized effect. A Dark claim additionally needs an implementation-level leakage theorem, malicious-executor verifiability, and distributed liveness/security. |
| Tower256 additive FRI and retained history | **S/A with conditional P legs.** The tower codec, additive proximity, exact controller schedule, raw Merkle openings, retained equivocation, history folding, and same-coin event ledgers are explicit. The unconditional UD proximity gap is proved in its stated regime. | Concrete cSHAKE-to-uniform-ROM transport, a priced collision event, production proof/container codecs, common-coin realization, MCA/code exactness, and hiding remain open. A green controller is not proof-system security. | Instantiate the exact cSHAKE query trace and same-coin ROM coupling, price the extracted collision event, close production codecs/IDs, and run one executable Lean-owned checkpoint checker. |
| BaseFold, BCS, and Poseidon2 | **S and substantial pre-deployment P structure.** `Selvage/BaseFold*` gives the IOR, coherent sampled bounds, exact unbiased query construction, accepted-query joint uniformity, binary-Merkle equivocation extraction, source-owned Poseidon2 field semantics, a fully framed BCS alphabet, injective padding, lawful BabyBear/rate-block bytes, a fixed work ledger, and an eager/deferred transcript equality under the exact replay-compatible good event. | The current coupling is conditional on `PaddedEagerLastRateRun`. It is not yet a probability bound, random-permutation/random-function switch, deployed Poseidon2 theorem, whole receipt/path codec, or native checker refinement. The latest full umbrella evidence predates the current HEAD. | **Immediate next proof:** split work coins into rate/capacity coordinates, define the exact capacity-bad event, transport `capBad_le`, and prove absence of that event implies `PaddedEagerTerminalFreshRun` through the reachable-table/consumed-coordinate invariant. Then charge it in the existing ledger, perform RP/RF and deployed-Poseidon switches, and bind whole receipt, Ext4, root, and path bytes. |
| Accumulation and heterogeneous composition | **S.** `Selvage/AccRbr*` proves abstract accumulation/RBR/BCS structure. `Selvage/AccRbrFold.lean` states the additive-commitment fold, proves derived commitment folding and norm-growth bounds, and exhibits wraparound loss of binding. `Selvage/HeteroComposition.lean` proves the correct verifier-embedding rung and shows why the older intra-system `Reduction` cannot type the heterogeneous seam. | Production MSIS is a computational assumption, not proved. `ComposeErrorBound` and `ComposeFixedPoint` are named obligations. No deployed self-embedding or unbounded IVC system is instantiated. Merkle roots do not become an additive commitment alphabet by abstraction. | Instantiate one concrete additive commitment and its short-opening security game; close the fold round bound; embed one actual verifier relation with the load-bearing backward direction; state and prove the composed error ledger before claiming recursion. |
| Ring switching and characteristic-two work | **S.** `Theory/ExtensionBasis.lean`, `Selvage/RingSwitching.lean`, `Selvage/AdditiveBaseFold.lean`, and `Selvage/CharTwoWall.lean` locate the characteristic-two boundary precisely: packing/unpacking and ring switching use an actual basis; the original multiplicative fold is refuted in characteristic two; the additive descent is a distinct construction. The batching and degree-two sumcheck legs of the ring-switch compiler are proved. | The tensor-algebra row/column identity used by the paper's actual verifier remains uninstantiated, as does the `RingSwitchTarget` connection to a large-field PCS. This is not yet a binary-tower deployment. | Instantiate equation (30)'s tensor row function, discharge the target interface with the intended additive BaseFold scheme, bind extension-basis order into commitments and transcript bytes, and compose the exact security loss. |
| Matmul, low-rank updates, Spartan, and zkML | **S/A with modeled durability witnesses.** Exact contraction semantics, three root-bound MLE claims, quadratic/cubic sumcheck reductions, a tiny runnable F7 checker, a framed logical audit turn, low-rank update identities and costs, and Spartan's two-phase adaptive soundness bound are proved. `Assurance/SpartanR1CS.lean` composes its real outer predicate with the inner phase rather than assuming honest terminal values. | The tiny checker is exact recomputation, not succinct proof verification. Spartan still has named PCS, sparse-oracle, and Fiat–Shamir obligations. Low-rank checks certify the supplied product, not that factors are the correct projection of a gradient. Fixture codecs, local registries, and logical durability are not production. | Build the runnable BaseFold checker that binds the C/A/B openings, contraction transcript, suite registry, and complete failure budget; then bind neutral Preoscript/native bytes to the exact authorized request. For Spartan, close terminal PCS openings, sparse evaluation, and one transcript. |
| Sparse memory and multiset arguments | **S.** `Compiler/TwistMultisetInvariant.lean`, `Selvage/MultisetFingerprint.lean`, and `Assurance/TwistMemoryFingerprintJoin.lean` prove both the honest sequential-consistency pole and the adversarial fingerprint bound. | The join explicitly does not supply committed-column binding, roots-before-challenge scheduling, tuple range injectivity, row-shape constraints, the framed state domain, or positional write-stamp derivation. | Discharge the six named `[TWIST-FP-BIND]` legs against `AcceptedLogupRun` and the sparse authenticated state bus; retain the stale-read and post-challenge-forgery teeth. |
| Hash functions and hash relations | **S research interfaces.** `Selvage/HashFamily.lean` joins Merkle and transcript roles and proves their obligations are not free. `Selvage/HashRelation*.lean` gives complete and graph-sound low-degree relation shapes for power, inverse, and root S-boxes, with refutations for slack/empty relations. | Per-gate graph soundness is not a full-round permutation relation, collision resistance, indifferentiability, algebraic security, or a recommendation to deploy a new hash. The relation is equally visible to the adversary. | Compose an actual candidate's S-box, linear layer, and round schedule into a witnessed permutation relation; prove byte/field refinement; then keep collision, transcript, and cryptanalytic assumptions separate and benchmark the resulting checker. |
| EVM Stage 0 | **S and generated A data.** `Theory/EvmFragment.lean` defines the five-opcode fragment, `Theory/EvmResidual.lean` uses an untrusted refusing decompiler plus per-output translation validation, and `Compiler/EvmAddAir.lean` proves the emitted 16-limb BabyBear descriptor means the validated `u256` addition semantics. Five named vectors match anvil/revm observations. | The semantics is gas-free and fragmentary; the external EVM comparison is differential evidence, not a machine-checked refinement. No proof-system soundness follows from descriptor meaning. | Add gas as an explicit premise or model, machine-check a refinement to a maintained EVM semantics before broadening materially, then add opcodes only with decompilation, translation validation, emitted constraints, refusal teeth, and proof-controller joins together. |
| Native code, artifacts, and measurements | **A with narrow adapter and measurement evidence.** Lean-authored artifacts and registries bind exact DTO/work identities; Rust returns candidate bytes or errors. Clause 406 has typed Lean controller/artifact control but no current emitted native work profile. Selected Hyperdocument adapters exercise narrow byte/storage crossings, and generated-dispatch and low-rank cost measurements exist. | Rust arithmetic, hashing, transform, prover, and I/O code generally lack semantic refinement. A catalog entry is transport identity, not compute correctness. Cost counters and microbenchmarks are not admitted end-to-end D or B evidence. | Refine one native candidate/proof implementation to the exact Lean relation and byte codec, preserve fail-closed errors, then measure proof size, prover/verifier time, memory, storage, and tail latency on the admitted consumer path. |

## Ranked next-proof queue

The order below follows dependency and claim risk, not novelty.

1. **Close the exact BaseFold work-capacity event.** Prove the deterministic
   bridge from no capacity collision to the replay-compatible terminal-fresh
   run, then price it on the existing fixed work ledger. Do not substitute
   pairwise capacity distinctness for rooted-path uniqueness.
2. **Complete the BaseFold cryptographic crossings.** Add RP/RF and deployed
   Poseidon2 boundaries with every term visible; bind Ext4, root, path, and
   whole-receipt codecs to the proved field/Merkle semantics.
3. **Build one succinct, runnable zkML checker.** Bind all three matmul
   openings, the contraction sumcheck, the registered suite, exact statement,
   and the complete failure budget. Keep native output neutral until this
   checker accepts.
4. **Finish one physical durability refinement.** Connect a bounded real
   SQLite or file protocol to the existing device/CAS/nullifier semantics and
   its crash/retry teeth.
5. **Finish one production authority path.** Join canonical signed bytes,
   directory membership, rotation/revocation, EUF assumptions, and key-custody
   claims to the same durable consumer.
6. **Close one private-computation proof suite before claiming privacy.** Start
   with versioned BFV/note statements and a deployed verifier; then add hiding,
   knowledge, native correctness, and separately authorized release. A Dark
   system is a later, strictly stronger deliverable than this Shielded slice.
7. **Instantiate accumulation/ring switching only into a consuming checker.**
   Close the additive commitment, norm, tensor-row, verifier-embedding, and
   composed-error obligations together rather than adding another generic
   carrier.

## Global claim limits to preserve

- A theorem over a carrier does not show that carrier is inhabited at deployed
  parameters; cite the witness or name the obligation.
- A commitment field or root equality is not commitment binding.
- A signature-verifier result is not EUF security, key custody, or authenticated
  transport.
- Acceptance of an FHE relation is not FHE correctness, confidentiality,
  access-pattern privacy, or vFHE.
- A logical CAS/WAL theorem or restart test is not physical stable-media
  refinement.
- Uniform marginals are not a joint same-coin ROM game.
- Exact semantic soundness is not proof-system soundness; proof-system
  soundness is not deployment; deployment is not performance.
- Clear, Shielded, and Dark are leakage/access contracts. They must be claimed
  only with an explicit implementation, adversary model, and failure ledger.

## Evidence refresh required before release

Before treating this inventory as a release snapshot:

1. freeze a clean commit and identify every generated output included;
2. run the import-boundary and trust-gate checks;
3. run a clean full `lake build Minidregg` on an isolated worker;
4. run the carrier census and its self-test;
5. preserve command, source-integrity, dependency-integrity, and axiom-footprint
   results; and
6. update this snapshot hash without promoting any unclosed S/A/P/D/B column.
