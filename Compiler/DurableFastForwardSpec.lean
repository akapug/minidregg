import Compiler.DurableReceiverCore

/-!
# The fast-forward open: statements (HOT-PATH §2(h), checkpoint v4)

A cold open restores the newest checkpoint and fast-forwards the entries after it; the genesis
replay is `store audit`. These are the statements the v4 change proves, entered before any proof
(the statements auditor's fifth pass folded in). The v4 pieces that do not exist yet are the
parameters of each statement: `open4` (the v4 checkpoint open), `step` (one append on a session),
`bodyOf` (the ONE body every sealer seals), `ff` (the fast-forward open) and `audit`. They are the
fields of ONE `Impl`, and every law is a field of ONE `Spec impl` over those shared fields: an
instance that satisfies one law by a degenerate field (an `open4` that never decodes) fails
`sealOpens` and `inhabited`.

`Derived` is the derived state a session serves from: the six indexes, the journal and history
the snapshot's model reads, and the fold's World. Option A (coordinator, 2026-10-27): the v4 body
carries the fold's World and its `semantics`; the open reads the prefix RECORD BYTES (no tags),
authenticates them by recomputing the chain to the MAC'd `body.chain`, and rebuilds the indexes,
journal and history from them without executing any (`ffState` below holds the World and the
state and has no prefix in its type). The open stays linear in log bytes with no execution; the
journal read at use (no prefix read at all) is the next unit. `Body4` moves into
`DurableCheckpointCodec` with its codec when v4 lands (a move: this module then imports it).

What changes, said once: the open trusts the MAC'd checkpoint for the prefix's World as v3 already
trusts it for the prefix's state. A fold that diverges from the genesis replay under the same key
and semantics is caught by `store audit` (item 5), never at open.
-/

namespace Minidregg.Compiler.DurableFastForwardSpec

open Minidregg.Theory.TypedAuthorization
open Minidregg.Kernel
open Minidregg.Kernel.DurableCommitProtocol
open Minidregg.Kernel.DurableDataIntent
open Minidregg.Kernel.DurableReceiver
open Minidregg.Kernel.DurableCheckpoint
open Minidregg.Compiler.DurableReceiverCodec
open Minidregg.Compiler.DurableCheckpointCodec
open Minidregg.Compiler.DurableReceiverIO
open Minidregg.Compiler.DurableLogTags (chainPrefixesStored verifyTags)
open Minidregg.Compiler.Sp800185Cshake256 (kmac256Bytes)

set_option autoImplicit false

/-! ## What a checkpoint carries beyond v3, and what makes it the replay's -/

/-- The derived state at a height, as a session serves from it. -/
structure Derived where
  presence : PresenceIndex.Index
  links : LinkIndex.Index
  ids : SessionIndex.CellIds
  txs : SessionIndex.TxIndex
  spentAt : SessionIndex.KeyIndex StableNullifier
  writesAt : SessionIndex.KeyIndex CellId
  /-- Newest first, as `State.snapshot` builds it from the prefix. -/
  journal : List (TransactionId × Intent TransactionId CellId StableNullifier ReplayEnvelope)
  /-- Newest first, as `State.snapshot` builds it from the prefix. -/
  history : List ReplayEnvelope
  /-- The fold's World: cells and the whole system store (journal, head, retired, parent,
  spent, allowance), not a `representsCheck` verdict. `none` when the fold is lost. -/
  world : Option HostRefinesWorld.DWorld

/-- The v4 checkpoint body: v3's body, the fold's semantics identity, the fold's World. -/
structure Body4 where
  body : Body
  /-- The identity of the fold that produced `world` (the Host's semantics digest): a body sealed
  by a different fold under the same Store key is refused by name. -/
  semantics : Digest
  /-- The fold's World at the body's height (system store via `WorldSystemCodec.systemStream`). -/
  world : Option HostRefinesWorld.DWorld

structure Sealed4 where
  body : Body4
  root : Digest
  mac : List UInt8

inductive OpenRefusal where
  | malformed
  | foreignKey
  | foreignSemantics
  | rootMismatch
  | badMac

variable (rootBytes : List UInt8 → Digest) (logStart : Seed → Digest) (semanticsId : Digest)

/-- The genesis replay's World after an image's records. -/
def worldAt (image : Image) : Option HostRefinesWorld.DWorld :=
  match TurnLog.genesisOfSeed image.seed with
  | .error _ => none
  | .ok genesis => (foldRecords rootBytes genesis 0 image.accepted).toOption

/-- The genesis replay's snapshot after an image's records. -/
def replaySnapshot (image : Image) : Option (DataSnapshot rootBytes) :=
  resume rootBytes image 0 (State.ofSeed image.seed)

/-- `derived` is the replay's value at `image`. Every field is pinned: equality where the
open's `Loaded` states equality, the index's own `Exact` where it states that. -/
structure Derived.Honest (image : Image) (derived : Derived) : Prop where
  presence : derived.presence = PresenceIndex.ofRecords image.accepted
  links : derived.links = LinkIndex.ofRecords image.accepted
  ids : derived.ids.Exact (SessionIndex.rawIds image)
  txs : derived.txs.Exact image.accepted
  spentAt : derived.spentAt.Exact IntentRecord.nullifiers image.accepted
  writesAt : derived.writesAt.Exact (fun record => record.writes.map DataWrite.cellId) image.accepted
  journal : derived.journal =
    (image.accepted.map fun record => (record.transactionId, IntentRecord.erase record)).reverse
  history : derived.history = (image.accepted.map fun record => (IntentRecord.erase record).event).reverse
  world : derived.world = worldAt rootBytes image

/-- A v4 body is the replay's value at `image`: height, chain, state, semantics, World. -/
structure Body4.Honest (image : Image) (body : Body4) : Prop where
  height : body.body.height = image.accepted.length
  chain : body.body.chain = chainAfter (logStart image.seed) image.accepted
  state : replaySnapshot rootBytes image = some (body.body.state.snapshot rootBytes image.accepted)
  semantics : body.semantics = semanticsId
  world : body.world = worldAt rootBytes image

/-- What an open serves from: the checkpoint-relative `Loaded`'s observable part. -/
structure View where
  height : Nat
  chain : Digest
  derived : Derived
  snapshot : DataSnapshot rootBytes

structure View.Honest (image : Image) (view : View rootBytes) : Prop where
  height : view.height = image.accepted.length
  chain : view.chain = chainAfter (logStart image.seed) image.accepted
  snapshot : replaySnapshot rootBytes image = some view.snapshot
  derived : Derived.Honest rootBytes image view.derived

/-! ## The implementation's v4 pieces, shared by every law -/

/-- A fast-forward open: from the checkpoint's bytes, the stored record bytes below its height (no
tags), the stored entries after it and the Store's head height. -/
abbrev FastForward (α : Type) := MacKey → Seed → Option (List UInt8) → List (List UInt8) → List Entry →
  Nat → Except String α

/-- The executing part of an open: the World and the state at the head, from the checkpoint and the
suffix. It has no prefix in its type, so it cannot execute a prefix record. -/
abbrev FastForwardState (σ : Type) := MacKey → Seed → Option (List UInt8) → List Entry → Nat →
  Except String σ

structure Impl where
  /-- The checkpoint-relative `Loaded` (the reshape: seed, base height, base `Derived` and state,
  the suffix, the head's `Derived` as base extended by the suffix, the engine over them). -/
  Loaded4 : Type
  /-- The light session's state. -/
  Light : Type
  /-- The `LoadedView` projection: what a session serves from. -/
  view : Loaded4 → View rootBytes
  lightView : Light → View rootBytes
  /-- `representsCheck` on the reshaped `Loaded`: decided from `Derived` and the snapshot, no log. -/
  representsCheck4 : Loaded4 → Bool
  decode4 : List UInt8 → Option Sealed4
  macInput : Body4 × Digest → List UInt8
  macInputDecode : List UInt8 → Option (Body4 × Digest)
  macDomain : List UInt8
  open4 : MacKey → List UInt8 → Except OpenRefusal Body4
  seal4 : MacKey → Body4 → List UInt8
  /-- The ONE body every sealer seals (`storeCheckpoint`, the light session, `checkpointDifferential`,
  the head seal, the clean-shutdown seal), from the session's view. -/
  bodyOf : MacKey → View rootBytes → Body4
  genesis : Seed → Loaded4
  /-- One accepted append on a full session (chain, indexes, journal, World: `ofIntent_run`'s step). -/
  step : Loaded4 → IntentRecord → Option Loaded4
  /-- One accepted append on the light session (the same advance, its own representation). -/
  lightStep : Light → IntentRecord → Option Light
  /-- A full session handing over to the light one. -/
  toLight : Loaded4 → Light
  ff : FastForward Loaded4
  /-- The state part a full open is built on (the World, the state at the head). -/
  State4 : Type
  ffState : FastForwardState State4
  /-- The World and snapshot of a state part. -/
  stateWorld : State4 → Option HostRefinesWorld.DWorld
  stateSnapshot : State4 → DataSnapshot rootBytes
  audit : MacKey → Seed → List IntentRecord → List (Nat × List UInt8) → Except (Nat × String) Unit

variable {rootBytes} in
/-- A session of either kind. -/
abbrev Session (impl : Impl rootBytes) := impl.Loaded4 ⊕ impl.Light

variable {rootBytes} in
def Impl.sessionView (impl : Impl rootBytes) : Session impl → View rootBytes
  | .inl loaded => impl.view loaded
  | .inr light => impl.lightView light

/-- A Store as the Host leaves it: the seed, the accepted records, the sealed checkpoints. -/
structure Written where
  seed : Seed
  records : List IntentRecord
  checkpoints : List (Nat × Body4)

def Written.image (store : Written) : Image := ⟨store.seed, store.records⟩

/-- The stored entries of a Store's records, as an open reads them: each record decodes from its
entry and every tag verifies chained from the seed's chain. -/
def OwnEntries (key : MacKey) (seed : Seed) (entries : List Entry) (records : List IntentRecord) : Prop :=
  List.Forall₂ (fun entry record => recordFrame.decode entry.record = some record) entries records ∧
  verifyTags key 0 (chainPrefixesStored (logStart seed) (entries.map (·.record)))
    (entries.map (·.tag)) = .ok ()

/-- The backup rule: open from the newest checkpoint at a positive height at or below the head,
else from genesis. A non-atomic restore that left the prefix short fails the chain gate. -/
def newestAtOrBelow (checkpoints : List (Nat × Body4)) (head : Nat) : Option (Nat × Body4) :=
  (checkpoints.filter fun checkpoint => 0 < checkpoint.1 ∧ checkpoint.1 ≤ head).foldl
    (fun best checkpoint => match best with
      | some held => if held.1 < checkpoint.1 then some checkpoint else some held
      | none => some checkpoint) none

variable {rootBytes} in
/-- What `ff` is handed for a Store cut at `head` under the backup rule: the checkpoint, the record
bytes below it, the entries from it to the cut. -/
def openInputs (impl : Impl rootBytes) (key : MacKey) (checkpoints : List (Nat × Body4))
    (entries : List Entry) (head : Nat) : Option (List UInt8) × List (List UInt8) × List Entry :=
  match newestAtOrBelow checkpoints head with
  | none => (none, [], entries.take head)
  | some (height, body) =>
      (some (impl.seal4 key body), (entries.take height).map (·.record), (entries.take head).drop height)

/-- The Stores this Host writes, with the session that wrote them: genesis; an append a full
session accepted (`step`); an append the light session accepted (`lightStep`); a hand-over to the
light session; a seal at ANY height through the one `bodyOf` of the session's view (the due
cadence, the on-demand head seal, the clean-shutdown seal: item 6); a reopen through `ff` of THIS
Store's own entries from genesis or from one of its own sealed checkpoints. Its inhabitant is
every Store a Host run produced (`Spec.inhabited`). -/
inductive Wrote (impl : Impl rootBytes) (key : MacKey) : Written → Session impl → Prop
  | genesis (seed : Seed) : Wrote impl key ⟨seed, [], []⟩ (.inl (impl.genesis seed))
  | append {store loaded loaded'} (record : IntentRecord) :
      Wrote impl key store (.inl loaded) → impl.step loaded record = some loaded' →
      Wrote impl key { store with records := store.records ++ [record] } (.inl loaded')
  | lightAppend {store light light'} (record : IntentRecord) :
      Wrote impl key store (.inr light) → impl.lightStep light record = some light' →
      Wrote impl key { store with records := store.records ++ [record] } (.inr light')
  | goLight {store loaded} :
      Wrote impl key store (.inl loaded) → Wrote impl key store (.inr (impl.toLight loaded))
  | seal {store session} :
      Wrote impl key store session →
      Wrote impl key
        { store with checkpoints :=
            (store.records.length, impl.bodyOf key (impl.sessionView session)) :: store.checkpoints }
        session
  | reopenGenesis {store session loaded'} (entries : List Entry) :
      Wrote impl key store session → OwnEntries logStart key store.seed entries store.records →
      impl.ff key store.seed none [] entries entries.length = .ok loaded' →
      Wrote impl key store (.inl loaded')
  | reopenCheckpoint {store session loaded'} (entries : List Entry) (height : Nat) (body : Body4) :
      Wrote impl key store session → OwnEntries logStart key store.seed entries store.records →
      (height, body) ∈ store.checkpoints → height ≠ 0 →
      impl.ff key store.seed (some (impl.seal4 key body)) ((entries.take height).map (·.record))
        (entries.drop height) entries.length = .ok loaded' →
      Wrote impl key store (.inl loaded')

/-! ## The laws -/

structure Spec (impl : Impl rootBytes) : Prop where
  -- ### 1. The MAC gate
  /-- The MAC input is an injective encoding of everything the body carries (no field outside it). -/
  macInjective : ∀ carried, impl.macInputDecode (impl.macInput carried) = some carried
  /-- Accept IFF decode, this key, this semantics, the recomputed root, the MAC. -/
  macGate : ∀ key bytes body, impl.open4 key bytes = .ok body ↔
    ∃ sealed, impl.decode4 bytes = some sealed ∧ sealed.body = body ∧ body.body.keyId = key.id ∧
      body.semantics = semanticsId ∧ sealed.root = worldRoot rootBytes body.body ∧
      sealed.mac = kmac256Bytes key.bytes impl.macDomain (impl.macInput (body, sealed.root))
  /-- Teeth by name: another fold's body under this key; a wrong MAC. -/
  macRefusals : ∀ key bytes sealed, impl.decode4 bytes = some sealed → sealed.body.body.keyId = key.id →
    (sealed.body.semantics ≠ semanticsId → impl.open4 key bytes = .error .foreignSemantics) ∧
    (sealed.body.semantics = semanticsId → sealed.root = worldRoot rootBytes sealed.body.body →
      sealed.mac ≠ kmac256Bytes key.bytes impl.macDomain (impl.macInput (sealed.body, sealed.root)) →
      impl.open4 key bytes = .error .badMac)
  /-- What is sealed opens, as itself: the gate is not vacuous. -/
  sealOpens : ∀ key view, impl.open4 key (impl.seal4 key (impl.bodyOf key view)) = .ok (impl.bodyOf key view)
  -- ### 2. The suffix gate
  /-- Every acceptance is authenticated over exactly what it read: the checkpoint opens; the prefix
  record bytes are as many as its height, each decodes, and their chain recomputed from the seed's
  start IS the MAC'd `body.chain` (the prefix is authenticated by the chain, no tags); the suffix's
  tags verify chained from that chain; every suffix record decodes; the head is reached. -/
  suffixGate : ∀ key seed bytes (below : List (List UInt8)) suffix head loaded,
    impl.ff key seed (some bytes) below suffix head = .ok loaded →
    ∃ body, impl.open4 key bytes = .ok body ∧
      below.length = body.body.height ∧
      (∀ record ∈ below, (recordFrame.decode record).isSome) ∧
      (chainPrefixesStored (logStart seed) below).getLastD (logStart seed) = body.body.chain ∧
      verifyTags key body.body.height
        (chainPrefixesStored body.body.chain (suffix.map (·.record))) (suffix.map (·.tag)) = .ok () ∧
      (∀ entry ∈ suffix, (recordFrame.decode entry.record).isSome) ∧
      body.body.height + suffix.length = head ∧ (impl.view loaded).height = head
  /-- From genesis the open is handed no prefix and verifies every entry's tag. -/
  genesisGate : ∀ key seed (below : List (List UInt8)) suffix head loaded,
    impl.ff key seed none below suffix head = .ok loaded →
    below = [] ∧ verifyTags key 0 (chainPrefixesStored (logStart seed) (suffix.map (·.record)))
      (suffix.map (·.tag)) = .ok () ∧ suffix.length = head
  /-- `ff` executes no prefix record: the World and the snapshot of every open are those of
  `ffState` on the same checkpoint and suffix, which has no prefix in its type. The prefix bytes
  reach the result only through the non-executing rebuilds `Derived.Honest` pins (the indexes,
  journal and history as functions of the records). -/
  executesNoPrefix : ∀ key seed checkpoint below suffix head loaded,
    impl.ff key seed checkpoint below suffix head = .ok loaded →
    ∃ state, impl.ffState key seed checkpoint suffix head = .ok state ∧
      (impl.view loaded).derived.world = impl.stateWorld state ∧
      (impl.view loaded).snapshot = impl.stateSnapshot state
  -- ### 3. Exactness, and the reshaped `Loaded`
  /-- On a Store's own entries, a checkpoint honest for `pre` (or none, `pre = []`) fast-forwards
  to the replay's value at `pre ++ suf`. -/
  exact : ∀ key seed (entries : List Entry) (pre suf : List IntentRecord) checkpoint snapshot,
    OwnEntries logStart key seed entries (pre ++ suf) →
    replaySnapshot rootBytes ⟨seed, pre ++ suf⟩ = some snapshot →
    (match checkpoint with
      | none => pre = []
      | some bytes => ∃ body, impl.open4 key bytes = .ok body ∧
          Body4.Honest rootBytes logStart semanticsId ⟨seed, pre⟩ body ∧ pre ≠ []) →
    ∃ loaded, impl.ff key seed checkpoint ((entries.take pre.length).map (·.record))
        (entries.drop pre.length) entries.length = .ok loaded ∧
      View.Honest rootBytes logStart ⟨seed, pre ++ suf⟩ (impl.view loaded) ∧
      (impl.view loaded).snapshot = snapshot
  /-- `representsCheck` from `Derived`: the reshaped check decides the snapshot's representation
  by the carried World, with no log. -/
  representsFromDerived : ∀ loaded, impl.representsCheck4 loaded = true ↔
    ∃ world, (impl.view loaded).derived.world = some world ∧
      HostRefinesWorld.SnapRepresents DeployedBridge.bridge (impl.view loaded).snapshot
        (impl.view loaded).height world
  -- ### 4. The keystone
  /-- In every Store this Host wrote, the session (full or light) is the replay's value at the
  head and every checkpoint is the replay's value at its height, World included (whole-World
  equality: every system row). -/
  keystone : ∀ key store session, Wrote rootBytes logStart impl key store session →
    View.Honest rootBytes logStart store.image (impl.sessionView session) ∧
    ∀ height body, (height, body) ∈ store.checkpoints →
      Body4.Honest rootBytes logStart semanticsId ⟨store.seed, store.records.take height⟩ body
  /-- Inhabitation: a Store reached by an append, a seal at a positive height and a reopen from
  that checkpoint. -/
  inhabited : ∃ (key : MacKey) (seed : Seed) (record : IntentRecord) (loaded1 : impl.Loaded4)
      (entries : List Entry) (loaded2 : impl.Loaded4),
    impl.step (impl.genesis seed) record = some loaded1 ∧
    OwnEntries logStart key seed entries [record] ∧
    impl.ff key seed (some (impl.seal4 key (impl.bodyOf key (impl.view loaded1))))
      (entries.map (·.record)) [] 1 = .ok loaded2
  -- ### 2'. Every cut height, under the backup rule
  /-- A Store this Host wrote, cut at ANY height (below the newest checkpoint included), opens by
  the backup rule to the replay's value at the cut: a tail rollback opens as the genesis replay
  opens it; detecting one rests on the signer's `headTag`, not on this open. -/
  cutHonest : ∀ key store session (entries : List Entry) head,
    Wrote rootBytes logStart impl key store session →
    OwnEntries logStart key store.seed entries store.records → head ≤ entries.length →
    ∃ loaded,
      impl.ff key store.seed (openInputs impl key store.checkpoints entries head).1
        (openInputs impl key store.checkpoints entries head).2.1
        (openInputs impl key store.checkpoints entries head).2.2 head = .ok loaded ∧
      View.Honest rootBytes logStart ⟨store.seed, store.records.take head⟩ (impl.view loaded)
  -- ### 5. `store audit`
  auditSound : ∀ key seed records checkpoints, impl.audit key seed records checkpoints = .ok () →
    ∀ height bytes, (height, bytes) ∈ checkpoints →
      ∃ body, impl.open4 key bytes = .ok body ∧
        Body4.Honest rootBytes logStart semanticsId ⟨seed, records.take height⟩ body
  /-- A dishonest checkpoint (a fold divergence included: caught here, never at open) makes the
  audit refuse, naming a height whose checkpoint is dishonest. -/
  auditRefuses : ∀ key seed records checkpoints,
    (∃ height bytes, (height, bytes) ∈ checkpoints ∧ ∀ body, impl.open4 key bytes = .ok body →
      ¬ Body4.Honest rootBytes logStart semanticsId ⟨seed, records.take height⟩ body) →
    ∃ height message, impl.audit key seed records checkpoints = .error (height, message) ∧
      ∃ bytes, (height, bytes) ∈ checkpoints ∧ ∀ body, impl.open4 key bytes = .ok body →
        ¬ Body4.Honest rootBytes logStart semanticsId ⟨seed, records.take height⟩ body
  -- ### 6. A head seal fast-forwards zero records
  headSealZero : ∀ key seed (entries : List Entry) (records : List IntentRecord) (view : View rootBytes),
    OwnEntries logStart key seed entries records →
    View.Honest rootBytes logStart ⟨seed, records⟩ view → records ≠ [] →
    ∃ loaded, impl.ff key seed (some (impl.seal4 key (impl.bodyOf key view)))
        (entries.map (·.record)) [] entries.length = .ok loaded ∧
      (impl.view loaded).height = view.height ∧ (impl.view loaded).chain = view.chain ∧
      (impl.view loaded).derived.world = view.derived.world

end Minidregg.Compiler.DurableFastForwardSpec
