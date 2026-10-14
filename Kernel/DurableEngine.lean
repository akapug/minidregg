/-
# Kernel.DurableEngine — the durable snapshot as data, and `resume` compiled over it

`DataSnapshot` is the protocol's semantic snapshot: roots and canonical bytes
as functions, consumed nullifiers as a predicate, history and journal as lists.
Every theorem in the receiver is stated over it, and stays so. Built the way
the spec reads, it costs Θ(h) per record replayed at height h:

* `Snapshot.install` layers one closure per record over the cell lookups, and
  the checkpoint's cells are a list walked per lookup (`tableLookup`);
* the journal lookup that guards every replayed record walks the whole
  journal (`Snapshot.lookupRecorded`);
* the consumed check walks every spent nullifier of the prefix (`∈ spent`);
* (until history went newest first, the history append copied the whole history);
* admissibility enumerates the image's ids with an `eraseDups` (Θ(h·cells)).

`Engine` holds the same snapshot as data: the cells as a `CellTable`, the
spent nullifiers as a hash set, the journal with a hash-set index of its
transaction ids. `view` is the
snapshot it represents, field for field; `replay_view` says the engine's replay
IS the protocol replay (`DurableReceiver.replay`) under `view`, and
`resume_eq_resumeFast` (`@[csimp]`) makes every compiled `resume` run it. No
statement changes: the spec is what the theorems name; this is what runs.
-/
import Kernel.DurableCheckpoint
import Kernel.CellTable
import Kernel.SessionIndex
import Std.Data.HashSet.Lemmas

namespace Minidregg.Kernel.DurableEngine

open Minidregg.Theory
open Minidregg.Theory.TypedAuthorization
open Minidregg.Theory.ResourceCost
open Minidregg.Kernel.DurableCommitProtocol
open Minidregg.Kernel.DurableDataIntent
open Minidregg.Kernel.DurableReceiver
open Minidregg.Kernel.DurableCheckpoint

set_option autoImplicit false

/-- Nullifiers hash by every field (equal nullifiers hash equal). -/
instance : Hashable StableNullifier :=
  ⟨fun nullifier => mixHash (hash nullifier.codecVersion) (mixHash (hash nullifier.domain.value)
    (mixHash (hash nullifier.nullifierId.value) (hash nullifier.canonicalBytes)))⟩

instance : LawfulHashable StableNullifier where
  hash_eq a b same := by
    cases eq_of_beq same
    rfl

/-- A journal lookup hits exactly the recorded transaction ids. -/
theorem lookupRecorded_isSome (transactionId : TransactionId) :
    ∀ (journal : List (TransactionId × Intent TransactionId CellId StableNullifier ReplayEnvelope)),
      (Snapshot.lookupRecorded transactionId journal).isSome =
        (journal.map Prod.fst).contains transactionId
  | [] => rfl
  | (recordedId, _) :: rest => by
      simp only [Snapshot.lookupRecorded, List.map_cons, List.contains_cons]
      by_cases same : recordedId = transactionId
      · simp [same]
      · simp only [same, ↓reduceIte, lookupRecorded_isSome transactionId rest]
        have : (transactionId == recordedId) = false := by simp [Ne.symm same]
        simp [this]

/-- The durable snapshot as data. -/
structure Engine where
  absent : List UInt8
  cells : CellTable
  available : Charge
  spent : Std.HashSet StableNullifier
  /-- Newest first, as `Snapshot.install` conses it. -/
  journal : List (TransactionId × Intent TransactionId CellId StableNullifier ReplayEnvelope)
  /-- The journal's transaction ids, indexed. -/
  recorded : Std.HashSet TransactionId
  recordedExact : ∀ transactionId,
    recorded.contains transactionId = (journal.map Prod.fst).contains transactionId
  /-- Newest first, as `Snapshot.install` conses it. -/
  historyRev : List ReplayEnvelope

namespace Engine

variable (rootBytes : List UInt8 → Digest)

/-- A cell's bytes: the table's, else the fresh-identifier bytes. -/
def bytes (engine : Engine) (cellId : CellId) : List UInt8 :=
  (engine.cells.get cellId).getD engine.absent

/-- **The snapshot this engine is**, field for field. -/
@[inline] def view (engine : Engine) : DataSnapshot rootBytes where
  model :=
    { roots := fun cellId => rootBytes (engine.bytes cellId)
      consumed := fun nullifier => engine.spent.contains nullifier
      available := engine.available
      history := engine.historyRev
      journal := engine.journal }
  canonicalBytes := engine.bytes
  coherent := fun _ => rfl

/-- The same snapshot without history and journal: all that preflight reads. -/
@[inline] def light (engine : Engine) : DataSnapshot rootBytes where
  model :=
    { roots := fun cellId => rootBytes (engine.bytes cellId)
      consumed := fun nullifier => engine.spent.contains nullifier
      available := engine.available
      history := []
      journal := [] }
  canonicalBytes := engine.bytes
  coherent := fun _ => rfl

/-- Preflight never reads history or journal. -/
theorem preflight_light (engine : Engine) (intent : DataIntent rootBytes) :
    intent.preflight (engine.light rootBytes) = intent.preflight (engine.view rootBytes) := rfl

/-- One accepted record, installed as data: each write replaces its cell (the
first write of a cell wins, as `lookupPostBytes` reads), each nullifier joins
the set, the journal and history gain one cons each. -/
def install (engine : Engine) (intent : DataIntent rootBytes) : Engine where
  absent := engine.absent
  cells := intent.writes.foldr (fun write table => table.insert write.cellId write.canonicalPostBytes)
    engine.cells
  available := fun lane => engine.available lane - intent.exactCharge lane
  spent := intent.nullifiers.foldl (fun spent nullifier => spent.insert nullifier) engine.spent
  journal := (intent.transactionId, intent.erase) :: engine.journal
  recorded := engine.recorded.insert intent.transactionId
  recordedExact := by
    intro transactionId
    rw [Std.HashSet.contains_insert, engine.recordedExact]
    by_cases same : intent.transactionId = transactionId
    · subst same; simp
    · have differs : (transactionId == intent.transactionId) = false := by simp [Ne.symm same]
      simp [same, differs]
  historyRev := intent.erase.event :: engine.historyRev

theorem get_foldr (writes : List DataWrite) (table : CellTable) (cellId : CellId) :
    (writes.foldr (fun write table => table.insert write.cellId write.canonicalPostBytes) table).get
        cellId = (DataSnapshot.lookupPostBytes cellId writes).or (table.get cellId) := by
  induction writes with
  | nil => rfl
  | cons write rest ih =>
      rw [List.foldr_cons, CellTable.get_insert, ih]
      simp only [DataSnapshot.lookupPostBytes]
      split <;> rfl

theorem contains_foldl (nullifiers : List StableNullifier) (spent : Std.HashSet StableNullifier)
    (nullifier : StableNullifier) :
    (nullifiers.foldl (fun spent nullifier => spent.insert nullifier) spent).contains nullifier =
      (nullifiers.contains nullifier || spent.contains nullifier) := by
  induction nullifiers generalizing spent with
  | nil => simp
  | cons head rest ih =>
      rw [List.foldl_cons, ih, Std.HashSet.contains_insert]
      by_cases same : head = nullifier
      · subst same; simp
      · have differs : (head == nullifier) = false := by simp [same]
        rw [differs]
        simp [Ne.symm same]

/-- Two snapshots with the same model and bytes are equal (coherence is a proof). -/
theorem DataSnapshot.ext' {left right : DataSnapshot rootBytes} (model : left.model = right.model)
    (bytes : left.canonicalBytes = right.canonicalBytes) : left = right := by
  cases left
  cases right
  simp only at model bytes
  subst model bytes
  rfl

/-- **Install commutes with `view`**: the engine's install is the protocol's. -/
theorem view_install (engine : Engine) (intent : DataIntent rootBytes) :
    (engine.install rootBytes intent).view rootBytes =
      DataSnapshot.install (engine.view rootBytes) intent := by
  have bytesEq : (engine.install rootBytes intent).bytes =
      (DataSnapshot.install (engine.view rootBytes) intent).canonicalBytes := by
    funext cellId
    show ((intent.writes.foldr _ engine.cells).get cellId).getD engine.absent =
      (DataSnapshot.lookupPostBytes cellId intent.writes).getD (engine.bytes cellId)
    rw [get_foldr]
    cases DataSnapshot.lookupPostBytes cellId intent.writes <;> rfl
  apply DataSnapshot.ext' rootBytes
  · have rootsEq : (fun cellId => rootBytes ((engine.install rootBytes intent).bytes cellId)) =
        (DataSnapshot.install (engine.view rootBytes) intent).model.roots := by
      funext cellId
      rw [← (DataSnapshot.install (engine.view rootBytes) intent).coherent cellId, bytesEq]
    show Snapshot.mk _ _ _ _ _ = Snapshot.install (engine.view rootBytes).model intent.erase
    unfold Snapshot.install
    congr 1
    all_goals first
      | exact rootsEq
      | (funext nullifier
         show (intent.nullifiers.foldl _ engine.spent).contains nullifier = _
         rw [contains_foldl]
         by_cases member : nullifier ∈ intent.nullifiers <;> simp [member, view])
      | rfl
  · exact bytesEq

/-- The engine at a checkpoint: the state's cells as a table, the prefix's
nullifiers and transaction ids as sets, its journal and history as `State.snapshot`
builds them (history kept newest first). -/
def ofState (state : State) (prefixRecords : List IntentRecord) : Engine where
  absent := state.absentBytes
  cells := CellTable.ofList state.cells
  available := state.available
  spent := Std.HashSet.ofList (prefixRecords.flatMap IntentRecord.nullifiers)
  journal := (prefixRecords.map fun record => (record.transactionId, IntentRecord.erase record)).reverse
  recorded := Std.HashSet.ofList (prefixRecords.map IntentRecord.transactionId)
  recordedExact := by
    intro transactionId
    rw [Std.HashSet.contains_ofList, List.map_reverse, List.map_map]
    simp [Function.comp_def, IntentRecord.erase]
  historyRev := (prefixRecords.map fun record => (IntentRecord.erase record).event).reverse

/-- **The engine at a checkpoint is the checkpoint's snapshot.** -/
theorem view_ofState (state : State) (prefixRecords : List IntentRecord) :
    (ofState state prefixRecords).view rootBytes = state.snapshot rootBytes prefixRecords := by
  have bytesEq : (ofState state prefixRecords).bytes =
      (state.snapshot rootBytes prefixRecords).canonicalBytes := by
    funext cellId
    show ((CellTable.ofList state.cells).get cellId).getD state.absentBytes = _
    rw [CellTable.get_ofList]
    rfl
  apply DataSnapshot.ext' rootBytes
  · show Snapshot.mk _ _ _ _ _ = Snapshot.mk _ _ _ _ _
    congr 1
    all_goals first
      | (funext cellId
         rw [congrFun bytesEq cellId]
         exact (state.snapshot rootBytes prefixRecords).coherent cellId)
      | (funext nullifier
         show (Std.HashSet.ofList _).contains nullifier = _
         rw [Std.HashSet.contains_ofList]
         exact List.elem_eq_mem _ _)
      | simp [ofState]
  · exact bytesEq

/-- Replay over the engine: the protocol's `replay`, with the journal guard
read off the index and preflight read off the light snapshot. -/
def replay (engine : Engine) : List IntentRecord → Option Engine
  | [] => some engine
  | record :: records =>
      match record.bind? rootBytes with
      | none => none
      | some intent =>
          if engine.recorded.contains intent.transactionId then none
          else
            match intent.preflight (engine.light rootBytes) with
            | .ok () => replay (engine.install rootBytes intent) records
            | .error _ => none

/-- **The engine's replay is the protocol replay** under `view`. -/
theorem replay_view (engine : Engine) (records : List IntentRecord) :
    DurableReceiver.replay rootBytes (engine.view rootBytes) records =
      (engine.replay rootBytes records).map (view rootBytes) := by
  induction records generalizing engine with
  | nil => rfl
  | cons record records ih =>
      simp only [DurableReceiver.replay, replay]
      cases record.bind? rootBytes with
      | none => rfl
      | some intent =>
          dsimp only [bind, Option.bind]
          by_cases hit : engine.recorded.contains intent.transactionId = true
          · rw [if_pos hit]
            have found : (Snapshot.lookupRecorded intent.transactionId engine.journal).isSome := by
              rw [lookupRecorded_isSome, ← engine.recordedExact]; exact hit
            obtain ⟨recorded, isRecorded⟩ := Option.isSome_iff_exists.mp found
            unfold DurableDataIntent.execute
            rw [show (engine.view rootBytes).model.journal = engine.journal from rfl, isRecorded]
            dsimp only
            by_cases same : recorded.sameCheck intent.erase = true
            · rw [if_pos same]; rfl
            · rw [if_neg same]; rfl
          · rw [if_neg hit]
            have missing : Snapshot.lookupRecorded intent.transactionId engine.journal = none := by
              rw [← Option.not_isSome_iff_eq_none, lookupRecorded_isSome, ← engine.recordedExact]
              exact hit
            rw [preflight_light]
            cases checked : intent.preflight (engine.view rootBytes) with
            | error reason =>
                simp only [DurableDataIntent.execute]
                rw [show (engine.view rootBytes).model.journal = engine.journal from rfl, missing]
                simp only [checked]
                rfl
            | ok _ =>
                simp only [DurableDataIntent.execute]
                rw [show (engine.view rootBytes).model.journal = engine.journal from rfl, missing]
                simp only [checked]
                rw [← view_install, ih]

end Engine

/-- Admissibility with the image's identifiers in a hash set (no `eraseDups`). -/
def admissibleFast (image : Image) (state : State) : Bool :=
  let ids : Std.HashSet CellId := Std.HashSet.ofList
    (image.seed.cells.map Prod.fst ++
      image.accepted.flatMap fun record => record.writes.map DataWrite.cellId)
  decide (state.cells.map Prod.fst).Nodup && decide (state.absentBytes = image.seed.absentBytes) &&
    (state.cells.map Prod.fst).all fun cellId => ids.contains cellId

theorem admissibleFast_iff (image : Image) (state : State) :
    admissibleFast image state = true ↔ state.Admissible image := by
  unfold admissibleFast State.Admissible Image.cellIds
  simp only [Bool.and_eq_true, decide_eq_true_eq, List.all_eq_true, Std.HashSet.contains_ofList,
    List.contains_iff_mem, List.mem_eraseDups, and_assoc]

/-- `resume`, compiled: admissibility off a hash set, the replay over the engine. -/
def resumeFast (rootBytes : List UInt8 → Digest) (image : Image) (height : Nat)
    (state : State) : Option (DataSnapshot rootBytes) :=
  if admissibleFast image state then
    ((Engine.ofState state (image.accepted.take height)).replay rootBytes
      (image.accepted.drop height)).map (Engine.view rootBytes)
  else none

/-- **Refinement, compiled**: every `resume` the host runs is `resumeFast`;
the replacement is this theorem, not a trusted `implemented_by`. -/
@[csimp] theorem resume_eq_resumeFast : @resume = @resumeFast := by
  funext rootBytes image height state
  unfold resume resumeFast
  by_cases admissible : state.Admissible image
  · rw [if_pos admissible, if_pos ((admissibleFast_iff image state).mpr admissible),
      ← Engine.replay_view, Engine.view_ofState]
  · rw [if_neg admissible, if_neg (fun fast => admissible ((admissibleFast_iff image state).mp fast))]

#assert_axioms Engine.view_install
#assert_axioms Engine.view_ofState
#assert_axioms Engine.replay_view
#assert_axioms resume_eq_resumeFast

end Minidregg.Kernel.DurableEngine
