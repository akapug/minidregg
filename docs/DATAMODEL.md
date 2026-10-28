# DATAMODEL: kernel state as one sparse store over a fold of patches

This is the present-state description of the kernel's data model. The Lean modules are the
authority; this document says what they do and where they are. Section numbers, theorem numbers
(§4.N) and step names (A2, B1, B2, C1, C2, …) are kept from the design of 2026-09-29, so the
`DATAMODEL §N` citations in `Theory/`, `Kernel/`, `Compiler/` and `native/resource-client` resolve
here. Only the sections the code cites are kept.

Each section is marked **shipped** (in `main`, with the module named), **changed** (shipped, but
not as first designed: the difference is stated) or **design** (not built).

## 0. Summary

State is one typed sparse store per cell (`Theory.Store`): a finitely-supported partial map from
addresses to values. The only mutation is a patch, a list of guarded operations. A cell's bytes are
one canonical sorted encoding with no capacity (`Compiler.StoreCodec`). The world is a map of cells
plus a system cell that holds the journal, the head (height and log chain), the retired ids and the
other indexes (`Kernel.World`). History is a fold of turns over the world; a checkpoint is a world at
a height. The world root is an authenticated compressed trie over the slot roots
(`Kernel.WorldRoot`). Receipts and observation challenges bind `(worldRoot, height)`.

## 1. What is trusted

| party | what it can do if it lies | what bounds it |
|---|---|---|
| the host's MAC key (§6 Q1) | forge a checkpoint or a log tag, so a reopen resumes from a state the host never reached | the same key's holder can already forge the host's receipts; `mini store audit` re-derives the Store from the seed and re-admits every signed ingress |
| cSHAKE256 | a collision makes two worlds share a root | `Kernel.WorldRoot.deployedRoot_binds` and `Theory.AuthMap.forgery_exhibits_collision` reduce every forgery to an exhibited collision |

## 3. The model

### 3.1 Objects and value. **Shipped.**

`Theory.Store` defines `Layout` (namespaces, a key and value type per namespace, a discipline
`rom | ram | appendOnly`), `Address L := Σ n, Key n`, `Store L := Π₀ a, Option (Value a.1)`, and
`Op := read | write | allocate | free`. Every mutation names the value it replaces; allocation
requires absence. `Patch L := List (Op L)`; `Patch.run` is the monoid action (`run_append`),
`Patch.ValidFrom` checks each guard at the store its prefix produced, and the frame law is
`run_frame`. There is one guarded-write type. `Kernel.SparseAuthenticatedState` keeps only the
lowering seam: one timestamped bus row per operation of a validated patch.

Value: `Theory.Conservation` states conservation as kernel membership. For a group-valued namespace
the delta of a transition is `post − pre` with absence read as `0` (`delta`); a transition conserves
iff the per-asset sum of its delta is zero (`assetSum`, `Conserves`, `conserves_iff_mem_ker`). A
posting lies in the kernel (`posting_mem_ker`) and the postings generate it
(`postings_generate_kernel`). `Theory.ConservationBridge` re-derives the Book's and the declared
lowering's conservation results from this (`accepted_conserves`, `declaration_postingSum_zero`) and
refutes a raw balance write (`rawBalanceWrite_not_conserves`). Changed from the design: the Book's
total sums over its registered accounts, so account registration still needs
`registerAccounts_conserves` beside the homomorphism.

### 3.2 Roots. **Changed.**

Cell ids are the `Nat`s `create` names (`Kernel.World.CellId`).

A cell's root is a function of its logical store (`Theory.CellState.Materializer.rootOf`). Today it
is cSHAKE over the cell's canonical `StoreCodec` bytes (`Compiler.StoreCodec.rootBytes`): O(size)
per write, no per-address openings. The per-cell sparse Merkle root of the design (step D1) is not
deployed.

`Theory.AuthMap` is the fixed-depth sparse Merkle map of the design: root a function of the logical
map (`root_logical`), completeness (`verify_opening`), the incremental root (`root_update`), and
soundness as an exhibited collision (`forgery_exhibits_collision`; `verify_sound` under the
pair-scoped `PathBinding`, refuted at a length hash by `lengthHash_binding_fails`). Its two-level
section (`worldRoot_write`, `world_sound`, `two_level_sound`) and `Theory.AuthMapCellRoot` state the
world-over-cell-roots form.

The deployed world root is not `AuthMap`. It is `Theory.AuthTrie`'s compressed binary trie
(`Kernel.WorldRoot.rootOf`): one slot per cell plus the system slot, each holding its root, keys at
a 256-bit cSHAKE index, a lone key a leaf at the highest level where it is alone. Openings cost about
`log₂ n` hashes instead of 257. `deployedRoot` frames nodes and hashes them under cSHAKE256;
`deployedRoot_binds` makes root equality world equality up to a cSHAKE collision. The cached root
the host keeps is `Kernel.WorldRootCache`.

### 3.3 History: the fold, checkpoints, indexes. **Shipped.**

`Kernel.World`: a `World` is the cells plus a system cell, itself a `Store` over `sysLayout` with
namespaces `journal` (txId ↦ height and turn digest, append-only), `head` (height and log root),
`retired`, `parent` (the room a cell was born in), `spent` (consumed nullifiers) and `allowance`
(the meter). A `Turn` carries its txId, its creates (each with a ROM-only image), one guarded patch
per written cell, its retires, an event, its nullifiers, its charge, its signer and capability, and
its height window. It carries no post bytes and no signatures. `World.admit` is the one fail-closed
transition (`step` is its `Option` form); `fold` is `List.foldlM step`. The system half of every
turn is `sysPatch`, written by the same guarded primitive as every cell. `Checkpoint` is a world at a
height with its root; `check`, `resume`, `checkpoint_suffix` and `resume_sound` are in the same file.

The host's checkpoint body is a `World` (`Kernel.WorldSystemCodec` encodes the system cell; checkpoint
and log frames are in `Compiler.DurableCheckpointCodec`). The spent set, transaction index and keyed
families the host serves are also kept in `Theory.AuthTrie` indexes (`Compiler.DurableIndex`).

### 3.4 Receipts and challenges. **Changed.**

A receipt is `{transactionId, eventId, acceptedCount, worldRoot}` (`Compiler.NativeHostCodec.Receipt`):
`acceptedCount` is the height. `Kernel.NativeHost.historicalReceipt_bound` proves a sealed receipt
carries exactly its accepted prefix's world root and height. An observation challenge carries the
world root and height of the one image it was computed from
(`Kernel.NativeObservationController.challengeAt_bound`). The system slot holds the height and the
log root, which chains every accepted record from a genesis root that binds the deployment and the
seed (`Compiler.NativeHostCodec.logRoot0`, `logRoot`).

Design (not built): the joint-turn apex derived from the post world root. `MultiCellHyperedge`
still takes its apex from the declaration header.

### 3.5 Laws and scopes over addresses. **Changed.**

Scopes (`Theory.TypedAuthorization.Scope`) have `fields : Option (Finset CellField)` (`none` = every
field) and `maxDelta : Finset (CellField × Nat)`, per-field bounds on the absolute net change of one
admitted write. `Narrows` adds `SetNarrows` on fields and `BoundsNarrow` on bounds. A write over a
bound is refused `maxDeltaExceeded` (`Kernel.DeclaredResourceController`). Changed from the design:
the bound is per field, not one ℓ¹ number and not per asset; it is per write, not cumulative.

A signed plan binds the values at the addresses it read, not a whole cell root
(`Theory.PlanBinding`): `admit` checks a footprint of `(address, observed value)` reads and refuses
`footprintStale a`, naming the first moved address. A write outside the footprint does not
invalidate the plan (`unrelated_write_admits`); at the whole cell, footprint admission is root
admission under `RootBinds` (`whole_footprint_iff_root`). The footprint's bytes are
`Compiler.PlanFootprintCodec`.

### 3.9 Lean signatures. **Changed.**

The sketch landed as `Theory.Store` (§3.1), `Theory.AuthMap` and `Theory.AuthTrie` (§3.2),
`Kernel.World` (§3.3) and `Theory.Conservation` (§3.1), under those names. `Registry`, `Cell`,
`World`, `Turn`, `fold`, `fold_append` and `Checkpoint` are in `Kernel.World`. The world root is a
parameter of `Checkpoint` there and is supplied by `Kernel.WorldRoot`.

## 4. Theorems carried

Each is a named theorem with built satisfiable and refuting poles in the same file.

- **4.1 Conservation as a homomorphism. Shipped.** `Theory.Conservation` (§3.1); poles
  `transfer_conserves` and `mint_not_conserves`.
- **4.3 Replay exactness. Shipped.** `Kernel.World`: `fold_append`, `fold_eq_some_iff`; a stale
  guard is refused `guardFailed` (`reject_guardFailed`), a repeated txId `replayedTransaction`
  (`reject_replayedTransaction`). A law's stale-read guard is this refusal: a CAS write whose
  expected value moved is refused.
- **4.4 Checkpoint soundness. Shipped.** `Kernel.World.checkpoint_suffix` and `resume_sound`;
  poles `honest_resumes`, `tampered_check_fails`, `nonbinding_root_accepts_tamper`. For the host's
  record type, `Kernel.DurableCheckpoint.resume_sound` and `dishonest_checkpoint_diverges`;
  `Kernel.WorldRoot.resume_sound_rootOf` discharges the binding premise.
- **4.8 No TOCTOU. Shipped.** `Theory.PlanBinding.no_toctou`: a patch whose accesses lie in an
  admitted footprint is valid at the current store iff it was valid at the authored one, and writes
  the same values.
- **4.9 Index exactness. Shipped.** `Kernel.World.journal_exact` and `journal_height_iff`: the
  journal's height for a txId is the log position carrying it; `fold_txId_unique` is replay
  detection. `Kernel.PresenceIndex.lastSeen_exact` has the same shape.
- **4.12 Unbounded capacity. Shipped.** `Compiler.StoreCodec.capacity_unbounded`: for every `n` a
  store with `n` present addresses round-trips through the framed codec; `capacity_32` and
  `capacity_1000` are its instances.

## 5. Steps

- **A2 the unbounded cell codec. Shipped.** `Compiler.StoreCodec`: support sorted by address bytes,
  length-prefixed, no capacity, slot or shard; canonical decoding refuses out-of-order, duplicate and
  non-minimal entries; the frame binds a layout digest.
- **A3 the authenticated map. Shipped** as `Theory.AuthMap` (§3.2); the deployed world root uses
  `Theory.AuthTrie` instead.
- **B1 delete the pages. Shipped.** Every deployed cell role is a `StoreCodec` cell at its layout
  (`Compiler.CanonicalCellRegistry`): hyperdocument content, event log and link index
  (`Compiler.HyperdocumentCell`; the link index keeps the semantic model's bounded capacity,
  committed by its layout, not a wire page), the one credential-authority cell over typed planes
  (`Compiler.CredentialAuthorityCell`), and declared object, program and account-metadata cells
  (`Compiler.DeclaredEffectCell`). The four-slot pages, the bounded-page catalogue, registry and
  upgrade are deleted. A declared cell admits a fifth and later field (journey row J12).
- **B2 the turn record and the fold. Shipped.** `Kernel.World` (§3.3); `Kernel.TurnRecord` puts an
  accepted effect into a leg and states physical atomicity as a simulation of `step`. The exit
  bench is `Kernel.WorldBench`: a compiled 1000-turn fold over the real `step` with toy parameters
  (`bench_fold_1000`, `native_decide`), timed by `Host/WorldFoldBench.lean`.
- **B3 scopes over addresses. Shipped** as K-FIELDS (§3.5; journey `jfields.sh`).
- **C1 world root, receipts, challenges. Changed** (§3.2, §3.4): the world root is the compressed
  trie, not a sorted hash then an SMT.
- **C2 checkpoint and suffix. Shipped.** `Compiler.DurableCheckpointCodec`: a seed, a log whose
  entries are chained by C1's log root and tagged `KMAC256(key, (keyId, h, chain_h))`, and
  checkpoints MAC'd over height, root and body hash. The receiver seals a checkpoint every
  `checkpointEvery` records (default 64, `Compiler.DurableReceiverCore`).
  `Kernel.NativeHost.openExisting` resumes from the latest checkpoint and replays only the suffix;
  it re-admits no signed ingress. A mismatched chain value, tag or root refuses the open.
- **D1–D4, E1. Design.** Per-cell SMT roots, observation by opening, lowering of openings to
  circuit rows, and the hyperdocument cutover by opening are not built.

## 6. Open choices

- **Q1. The host trusts its own checkpoint. Shipped as option (ii).** Checkpoints and log entries
  are authenticated with a host-held 32-byte MAC key generated at `mini bootstrap`, stored mode 0600
  beside the operator configuration, one per Store (`Compiler.DurableCheckpointCodec`). Rotation is
  a new checkpoint at the head under the new key. The roots the host keeps for historical receipts
  are trusted the same way (`Kernel.NativeHost.RootLogHonest`). `mini store audit` re-derives the
  Store from the seed (`Compiler.DurableStoreAudit.audit`: log chain, tags, index trie, every
  retained checkpoint against the genesis replay) and then re-admits every signed ingress at its
  original prefix (`NativeHost.audit`).
- **Q3. Two levels. Shipped.** A cell root is a function of the cell's logical store; the world
  root is a function of the map from slots to cell roots (`Theory.AuthMapCellRoot`,
  `Kernel.WorldRoot`). The cell root function can change without touching the world theorems.
