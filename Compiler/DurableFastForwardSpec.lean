import Compiler.DurableReceiverCore

/-!
# The fast-forward open: statements (HOT-PATH §2(h), checkpoint v4)

A cold open restores the newest checkpoint and fast-forwards the entries after it; the genesis
replay is `store audit`. These are the statements the v4 change proves, entered before any proof
(the statements auditor's fifth pass folded in). The v4 pieces that do not exist yet are the
parameters of each statement: `open4` (the v4 checkpoint open), `step` (one append on a session),
`bodyOf` (the ONE body every sealer seals), `ff` (the fast-forward open) and `audit`.

`Derived` is what the v3 open rebuilt from every entry below the checkpoint and the v4 body
carries instead: the six indexes, the journal and history the snapshot's model reads, and the
fold's World. It moves into `DurableCheckpointCodec` with its codec when v4 lands (a move: this
module then imports it).

What changes, said once: the open trusts the MAC'd checkpoint for the prefix's indexes, journal
and World as v3 already trusts it for the prefix's state. A fold that diverges from the genesis
replay under the same key and semantics is caught by `store audit` (item 5), never at open.
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

/-- The derived state at a height: what the open no longer rebuilds from the prefix. -/
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

/-- The v4 checkpoint body: v3's body, the fold's semantics identity, the derived state. -/
structure Body4 where
  body : Body
  /-- The identity of the fold that produced `derived.world` (the Host's semantics digest):
  a body sealed by a different fold under the same Store key is refused by name. -/
  semantics : Digest
  derived : Derived

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

/-- A v4 body is the replay's value at `image`: height, chain, state, semantics, derived. -/
structure Body4.Honest (image : Image) (body : Body4) : Prop where
  height : body.body.height = image.accepted.length
  chain : body.body.chain = chainAfter (logStart image.seed) image.accepted
  state : replaySnapshot rootBytes image = some (body.body.state.snapshot rootBytes image.accepted)
  semantics : body.semantics = semanticsId
  derived : Derived.Honest rootBytes image body.derived

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

/-! ## 1. The MAC gate -/

/-- The v4 open accepts exactly a decoded frame under this key, this semantics, the recomputed
world root and the MAC over an injective encoding of everything the body carries (no field
outside the MAC). -/
def MacGate (decode4 : List UInt8 → Option Sealed4)
    (macInput : Body4 × Digest → List UInt8) (macInputDecode : List UInt8 → Option (Body4 × Digest))
    (macDomain : List UInt8) (open4 : MacKey → List UInt8 → Except OpenRefusal Body4) : Prop :=
  (∀ carried, macInputDecode (macInput carried) = some carried) ∧
  ∀ key bytes body, open4 key bytes = .ok body ↔
    ∃ sealed, decode4 bytes = some sealed ∧ sealed.body = body ∧ body.body.keyId = key.id ∧
      body.semantics = semanticsId ∧ sealed.root = worldRoot rootBytes body.body ∧
      sealed.mac = kmac256Bytes key.bytes macDomain (macInput (body, sealed.root))

/-- Teeth, by name: another fold's body under this key is `foreignSemantics`; a wrong MAC over
an otherwise acceptable frame is `badMac`. -/
def MacGateRefusals (decode4 : List UInt8 → Option Sealed4)
    (macInput : Body4 × Digest → List UInt8) (macDomain : List UInt8)
    (open4 : MacKey → List UInt8 → Except OpenRefusal Body4) : Prop :=
  ∀ key bytes sealed, decode4 bytes = some sealed → sealed.body.body.keyId = key.id →
    (sealed.body.semantics ≠ semanticsId → open4 key bytes = .error .foreignSemantics) ∧
    (sealed.body.semantics = semanticsId → sealed.root = worldRoot rootBytes sealed.body.body →
      sealed.mac ≠ kmac256Bytes key.bytes macDomain (macInput (sealed.body, sealed.root)) →
      open4 key bytes = .error .badMac)

/-! ## 2. The suffix extends the snapshot

`ff key seed checkpoint suffix head`: `checkpoint` is the stored checkpoint's bytes and the
stored entry AT its height (the anchor; it binds the body to the log when the suffix is empty);
`suffix` the stored entries after it; `head` the Store's head height. The open receives nothing
below the anchor: that it reads no prefix is its type. -/
abbrev FastForward := MacKey → Seed → Option (List UInt8 × Entry) → List Entry → Nat →
  Except String (View rootBytes)

/-- Every acceptance is authenticated over exactly what it read: the checkpoint opens, the anchor's
tag is this key's trailer at the body's height carrying its chain and world root, the suffix's
tags verify chained from the body's chain, every suffix record decodes, and the suffix reaches the
Store's head. -/
def SuffixGate (open4 : MacKey → List UInt8 → Except OpenRefusal Body4) (ff : FastForward rootBytes) :
    Prop :=
  ∀ key seed bytes anchor suffix head view,
    ff key seed (some (bytes, anchor)) suffix head = .ok view →
    ∃ body carried, open4 key bytes = .ok body ∧
      anchor.tag = DurableHistory.trailer key body.body.height carried ∧
      carried.chain = body.body.chain ∧ carried.root = worldRoot rootBytes body.body ∧
      verifyTags key body.body.height
        (chainPrefixesStored body.body.chain (suffix.map (·.record))) (suffix.map (·.tag)) = .ok () ∧
      (∀ entry ∈ suffix, (recordFrame.decode entry.record).isSome) ∧
      body.body.height + suffix.length = head ∧ view.height = head

/-- Disclosed, not a gap: a log cut short at its tail, with the head lowered to match, is opened as
the genesis replay opens it (a rollback of the tail is outside what the MAC chain binds; neither
open is worse than the other). -/
def TailCutAsReplay (ff : FastForward rootBytes) : Prop :=
  ∀ key seed checkpoint suffix head view k, k ≤ suffix.length →
    ff key seed checkpoint suffix head = .ok view →
    ∃ view', ff key seed checkpoint (suffix.take k) (head - (suffix.length - k)) = .ok view'

/-! ## 3. Exactness over snapshot plus suffix, against a Store this Host wrote -/

/-- On stored entries whose records decode to `pre ++ suf` and whose tags all verify from the
seed's chain, a checkpoint honest for `pre` (or none, `pre = []`) fast-forwards to the replay's
value at `pre ++ suf`. -/
def Exact (open4 : MacKey → List UInt8 → Except OpenRefusal Body4) (ff : FastForward rootBytes) : Prop :=
  ∀ key seed (entries : List Entry) (pre suf : List IntentRecord) checkpoint snapshot,
    List.Forall₂ (fun entry record => recordFrame.decode entry.record = some record)
      entries (pre ++ suf) →
    verifyTags key 0 (chainPrefixesStored (logStart seed) (entries.map (·.record)))
      (entries.map (·.tag)) = .ok () →
    replaySnapshot rootBytes ⟨seed, pre ++ suf⟩ = some snapshot →
    (match checkpoint with
      | none => pre = []
      | some (bytes, anchor) => ∃ body, open4 key bytes = .ok body ∧
          Body4.Honest rootBytes logStart semanticsId ⟨seed, pre⟩ body ∧
          entries[pre.length - 1]? = some anchor ∧ pre ≠ []) →
    ∃ view, ff key seed checkpoint (entries.drop pre.length) entries.length = .ok view ∧
      View.Honest rootBytes logStart ⟨seed, pre ++ suf⟩ view ∧ view.snapshot = snapshot

/-! ## 4. The keystone: every checkpoint of a Store this Host wrote is the replay's -/

/-- A Store as the Host leaves it: the seed, the accepted records, the sealed checkpoints. -/
structure Written where
  seed : Seed
  records : List IntentRecord
  checkpoints : List (Nat × Body4)

def Written.image (store : Written) : Image := ⟨store.seed, store.records⟩

/-- The Stores this Host writes, with the session that wrote them: genesis; an append the Host
accepted (`step`, the session's per-append advance of chain, indexes, journal and World:
`ofIntent_run`'s step on the light session too); a seal at ANY height through the one `bodyOf`
(the due cadence, the on-demand head seal, the clean-shutdown seal: item 6); a reopen through
`ff` of THIS Store's own entries (records decoding to its records, tags verifying from the seed's
chain) from genesis or from one of its own sealed checkpoints. Its inhabitant is every Store a
Host run produced. -/
inductive Wrote (key : MacKey) (genesisView : Seed → View rootBytes)
    (step : View rootBytes → IntentRecord → Option (View rootBytes))
    (bodyOf : MacKey → View rootBytes → Body4) (seal4 : MacKey → Body4 → List UInt8)
    (ff : FastForward rootBytes) : Written → View rootBytes → Prop
  | genesis (seed : Seed) : Wrote key genesisView step bodyOf seal4 ff ⟨seed, [], []⟩ (genesisView seed)
  | append {store view view'} (record : IntentRecord) :
      Wrote key genesisView step bodyOf seal4 ff store view → step view record = some view' →
      Wrote key genesisView step bodyOf seal4 ff { store with records := store.records ++ [record] } view'
  | seal {store view} :
      Wrote key genesisView step bodyOf seal4 ff store view →
      Wrote key genesisView step bodyOf seal4 ff
        { store with checkpoints := (store.records.length, bodyOf key view) :: store.checkpoints } view
  | reopenGenesis {store view view'} (entries : List Entry) :
      Wrote key genesisView step bodyOf seal4 ff store view →
      List.Forall₂ (fun entry record => recordFrame.decode entry.record = some record)
        entries store.records →
      verifyTags key 0 (chainPrefixesStored (logStart store.seed) (entries.map (·.record)))
        (entries.map (·.tag)) = .ok () →
      ff key store.seed none entries entries.length = .ok view' →
      Wrote key genesisView step bodyOf seal4 ff store view'
  | reopenCheckpoint {store view view'} (entries : List Entry) (height : Nat) (body : Body4)
      (anchor : Entry) :
      Wrote key genesisView step bodyOf seal4 ff store view →
      List.Forall₂ (fun entry record => recordFrame.decode entry.record = some record)
        entries store.records →
      verifyTags key 0 (chainPrefixesStored (logStart store.seed) (entries.map (·.record)))
        (entries.map (·.tag)) = .ok () →
      (height, body) ∈ store.checkpoints → height ≠ 0 → entries[height - 1]? = some anchor →
      ff key store.seed (some (seal4 key body, anchor)) (entries.drop height) entries.length = .ok view' →
      Wrote key genesisView step bodyOf seal4 ff store view'

/-- The keystone: in every Store this Host wrote, the session is the replay's value at the head
and every checkpoint is the replay's value at its height, World included (the v4 `world`, hence
its system store, IS the fold's World: every row, not `representsCheck`'s membership checks). -/
def Keystone (key : MacKey) (genesisView : Seed → View rootBytes)
    (step : View rootBytes → IntentRecord → Option (View rootBytes))
    (bodyOf : MacKey → View rootBytes → Body4) (seal4 : MacKey → Body4 → List UInt8)
    (ff : FastForward rootBytes) : Prop :=
  ∀ store view, Wrote rootBytes logStart key genesisView step bodyOf seal4 ff store view →
    View.Honest rootBytes logStart store.image view ∧
    ∀ height body, (height, body) ∈ store.checkpoints →
      Body4.Honest rootBytes logStart semanticsId ⟨store.seed, store.records.take height⟩ body

/-! ## 5. `store audit` is the genesis replay, and refuses by height -/

/-- `audit key seed entries checkpoints`: the genesis replay over every entry, compared with every
stored checkpoint. Acceptance means every checkpoint is the replay's value at its height. -/
def AuditSound (open4 : MacKey → List UInt8 → Except OpenRefusal Body4)
    (audit : MacKey → Seed → List IntentRecord → List (Nat × List UInt8) → Except (Nat × String) Unit) :
    Prop :=
  ∀ key seed records checkpoints, audit key seed records checkpoints = .ok () →
    ∀ height bytes, (height, bytes) ∈ checkpoints →
      ∃ body, open4 key bytes = .ok body ∧
        Body4.Honest rootBytes logStart semanticsId ⟨seed, records.take height⟩ body

/-- The refusal pole: a checkpoint that is not the replay's value at its height (a fold
divergence included) makes the audit refuse, naming a height whose checkpoint is not. -/
def AuditRefuses (open4 : MacKey → List UInt8 → Except OpenRefusal Body4)
    (audit : MacKey → Seed → List IntentRecord → List (Nat × List UInt8) → Except (Nat × String) Unit) :
    Prop :=
  ∀ key seed records checkpoints,
    (∃ height bytes, (height, bytes) ∈ checkpoints ∧ ∀ body, open4 key bytes = .ok body →
      ¬ Body4.Honest rootBytes logStart semanticsId ⟨seed, records.take height⟩ body) →
    ∃ height message, audit key seed records checkpoints = .error (height, message) ∧
      ∃ bytes, (height, bytes) ∈ checkpoints ∧ ∀ body, open4 key bytes = .ok body →
        ¬ Body4.Honest rootBytes logStart semanticsId ⟨seed, records.take height⟩ body

/-! ## 6. A head seal makes a restored Store fast-forward zero records -/

/-- After a seal at the head (the on-demand verb before a template is saved, or the clean
shutdown), opening the Store reads an empty suffix and serves the session it sealed. -/
def HeadSealZero (key : MacKey) (bodyOf : MacKey → View rootBytes → Body4)
    (seal4 : MacKey → Body4 → List UInt8) (ff : FastForward rootBytes) : Prop :=
  ∀ seed (entries : List Entry) (records : List IntentRecord) (view : View rootBytes) anchor,
    List.Forall₂ (fun entry record => recordFrame.decode entry.record = some record) entries records →
    View.Honest rootBytes logStart ⟨seed, records⟩ view → records ≠ [] →
    entries.getLast? = some anchor →
    ∃ view', ff key seed (some (seal4 key (bodyOf key view), anchor)) [] entries.length = .ok view' ∧
      view'.height = view.height ∧ view'.chain = view.chain ∧ view'.derived = view.derived

end Minidregg.Compiler.DurableFastForwardSpec
