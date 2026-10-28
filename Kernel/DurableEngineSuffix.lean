/-
# Kernel.DurableEngineSuffix — the suffix replayed without the prefix (HOT-PATH §2(h))

A checkpoint's engine (`Engine.ofState state prefix`) knows the prefix's consumed nullifiers and
transaction ids. The fast-forward open replays the suffix from `Engine.ofState state []`, which
knows none, so its executing part needs nothing of the prefix. Preflight reads the consumed set
only at the intent's own nullifiers (`nullifiersFreshCheck`) and the journal guard only at the
intent's transaction id, so the two replays make the same decisions exactly when no suffix record
carries a prefix nullifier or transaction id (`Disjoint`); the protocol's replay refuses otherwise.
`resume_suffix` is the result: under admissibility and disjointness the prefix-free replay's head
state, over every record, is `resume`'s snapshot; `resume_disjoint` is the converse.
-/
module

public import Kernel.DurableEngine

-- Bodies this file reduces or derives through, not exposed by their modules (module system).
import all Init.Data.Repr
import all Init.Data.ToString.Basic
import all Init.Data.ToString.Extra
import all Init.Data.Array.Basic
import all Init.Data.ByteArray.Basic
import all Init.Data.String.Decode
import all Init.Data.String.Defs
import all Init.Control.Except
import all Init.Data.List.Basic
import all Init.Data.Nat.Bitwise.Basic
import all Init.Data.String.Bootstrap
import all Init.Data.Format.Basic
import all Init.Data.List.Scan.Basic

@[expose] public section

namespace Minidregg.Kernel.DurableEngine

open Minidregg.Theory
open Minidregg.Theory.TypedAuthorization
open Minidregg.Theory.ResourceCost
open Minidregg.Kernel.DurableCommitProtocol
open Minidregg.Kernel.DurableDataIntent
open Minidregg.Kernel.DurableReceiver
open Minidregg.Kernel.DurableCheckpoint

set_option autoImplicit false

/-- No suffix record carries a prefix nullifier or a prefix transaction id. -/
def Disjoint (pre suf : List IntentRecord) : Prop :=
  ∀ record ∈ suf, (∀ nullifier ∈ record.nullifiers, nullifier ∉ pre.flatMap IntentRecord.nullifiers) ∧
    record.transactionId ∉ pre.map IntentRecord.transactionId

/-- `Disjoint`, decided with the prefix's nullifiers and transaction ids in hash sets. -/
def disjointFast (pre suf : List IntentRecord) : Bool :=
  let spent : Std.HashSet StableNullifier := Std.HashSet.ofList (pre.flatMap IntentRecord.nullifiers)
  let recorded : Std.HashSet TransactionId := Std.HashSet.ofList (pre.map IntentRecord.transactionId)
  suf.all fun record =>
    record.nullifiers.all (fun nullifier => !spent.contains nullifier) &&
      !recorded.contains record.transactionId

theorem disjointFast_iff (pre suf : List IntentRecord) : disjointFast pre suf = true ↔ Disjoint pre suf := by
  unfold disjointFast Disjoint
  simp [List.all_eq_true, Std.HashSet.contains_ofList]

namespace Engine

variable (rootBytes : List UInt8 → Digest)

/-- The engine's state as a checkpoint state: its cells in ascending order (`CellTable.entries`). -/
def headState (engine : Engine) : State :=
  ⟨engine.absent, engine.cells.entries, engine.available⟩

/-- `left` is `right` with the prefix `pre` beneath it: the same cells, fresh bytes and allowance;
the prefix's nullifiers, transaction ids, journal and history added. -/
structure Beneath (pre : List IntentRecord) (left right : Engine) : Prop where
  absent : left.absent = right.absent
  cells : left.cells = right.cells
  available : left.available = right.available
  consumed : ∀ nullifier, left.consumed nullifier =
    (right.consumed nullifier || decide (nullifier ∈ pre.flatMap IntentRecord.nullifiers))
  recorded : ∀ transactionId, left.isRecorded transactionId =
    (right.isRecorded transactionId || decide (transactionId ∈ pre.map IntentRecord.transactionId))
  journal : left.journal.get = right.journal.get ++
    (pre.map fun record => (record.transactionId, IntentRecord.erase record)).reverse
  history : left.historyRev.get = right.historyRev.get ++
    (pre.map fun record => (IntentRecord.erase record).event).reverse

theorem beneath_ofState (state : State) (pre : List IntentRecord) :
    Beneath pre (ofState state pre) (ofState state []) := by
  refine ⟨rfl, rfl, rfl, ?_, ?_, ?_, ?_⟩
  · intro nullifier
    simp [consumed, ofState, Std.HashSet.contains_ofList]
  · intro transactionId
    simp [isRecorded, ofState, Std.HashSet.contains_ofList]
  · show List.reverse _ = [] ++ _
    rw [List.nil_append]
  · show List.reverse _ = [] ++ _
    rw [List.nil_append]

theorem consumed_install (engine : Engine) (intent : DataIntent rootBytes) (nullifier : StableNullifier) :
    (engine.install rootBytes intent).consumed nullifier =
      (decide (nullifier ∈ intent.nullifiers) || engine.consumed nullifier) := by
  simp only [consumed, install, contains_foldl, Bool.or_assoc]
  simp

theorem isRecorded_install (engine : Engine) (intent : DataIntent rootBytes) (transactionId : TransactionId) :
    (engine.install rootBytes intent).isRecorded transactionId =
      (decide (intent.transactionId = transactionId) || engine.isRecorded transactionId) := by
  show ((engine.recorded.insert intent.transactionId).contains transactionId ||
      engine.recordedBefore transactionId) = _
  rw [Std.HashSet.contains_insert, Bool.or_assoc, beq_eq_decide]
  rfl

theorem Beneath.install {pre : List IntentRecord} {left right : Engine} (below : Beneath pre left right)
    (intent : DataIntent rootBytes) :
    Beneath pre (left.install rootBytes intent) (right.install rootBytes intent) := by
  refine ⟨below.absent, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · show intent.writes.foldr _ left.cells = intent.writes.foldr _ right.cells
    rw [below.cells]
  · rw [Engine.available_install, Engine.available_install, below.available]
  · intro nullifier
    rw [consumed_install, consumed_install, below.consumed, Bool.or_assoc]
  · intro transactionId
    rw [isRecorded_install, isRecorded_install, below.recorded, Bool.or_assoc]
  · show (intent.transactionId, intent.erase) :: left.journal.get =
      ((intent.transactionId, intent.erase) :: right.journal.get) ++ _
    rw [below.journal, List.cons_append]
  · show intent.erase.event :: left.historyRev.get = (intent.erase.event :: right.historyRev.get) ++ _
    rw [below.history, List.cons_append]

/-- A passing data preflight passed the protocol's preflight on the erased intent. -/
theorem preflight_ok_erase (before : DataSnapshot rootBytes) (intent : DataIntent rootBytes)
    (ok : intent.preflight before = .ok ()) : intent.erase.preflight before.model = .ok () := by
  unfold DataIntent.preflight at ok
  split at ok
  · cases ok
  split at ok
  · cases ok
  split at ok
  · cases ok
  · assumption

/-- **Preflight reads the consumed set only at the intent's nullifiers**: two engines with the same
cells, fresh bytes and allowance that agree on those nullifiers preflight alike. -/
theorem preflight_light_congr (left right : Engine) (intent : DataIntent rootBytes)
    (absent : left.absent = right.absent) (cells : left.cells = right.cells)
    (available : left.available = right.available)
    (fresh : ∀ nullifier ∈ intent.nullifiers, left.consumed nullifier = right.consumed nullifier) :
    intent.preflight (left.light rootBytes) = intent.preflight (right.light rootBytes) := by
  have bytes : left.bytes = right.bytes := by
    funext cellId
    show (left.cells.get cellId).getD left.absent = (right.cells.get cellId).getD right.absent
    rw [absent, cells]
  have roots : (left.light rootBytes).model.roots = (right.light rootBytes).model.roots := by
    funext cellId
    show rootBytes (left.bytes cellId) = rootBytes (right.bytes cellId)
    rw [bytes]
  have funds : (left.light rootBytes).model.available = (right.light rootBytes).model.available :=
    available
  have check : intent.erase.nullifiersFreshCheck (left.light rootBytes).model =
      intent.erase.nullifiersFreshCheck (right.light rootBytes).model := by
    apply Bool.eq_iff_iff.mpr
    simp only [Intent.nullifiersFreshCheck_eq_true_iff]
    show (∀ nullifier ∈ intent.nullifiers, left.consumed nullifier = false) ↔
      (∀ nullifier ∈ intent.nullifiers, right.consumed nullifier = false)
    exact ⟨fun held nullifier member => (fresh nullifier member) ▸ held nullifier member,
      fun held nullifier member => (fresh nullifier member).symm ▸ held nullifier member⟩
  have guards : intent.readGuardsMatchCheck (left.light rootBytes) =
      intent.readGuardsMatchCheck (right.light rootBytes) := by
    unfold DataIntent.readGuardsMatchCheck
    rw [roots]
  have rootsCheck : intent.erase.rootsMatchCheck (left.light rootBytes).model =
      intent.erase.rootsMatchCheck (right.light rootBytes).model := by
    unfold Intent.rootsMatchCheck
    rw [roots]
  unfold DataIntent.preflight Intent.preflight
  rw [guards, rootsCheck, check, funds]

/-- The bound intent of a record carries the record's nullifiers and transaction id. -/
theorem bind_fields {record : IntentRecord} {intent : DataIntent rootBytes}
    (bound : record.bind? rootBytes = some intent) :
    intent.nullifiers = record.nullifiers ∧ intent.transactionId = record.transactionId := by
  have exact := IntentRecord.bind_exact bound
  subst exact
  exact ⟨rfl, rfl⟩

/-- **The prefix-free replay is the checkpoint's replay, under disjointness** (weak to real). -/
theorem replay_beneath (pre : List IntentRecord) :
    ∀ (suf : List IntentRecord) (left right right' : Engine), Beneath pre left right → Disjoint pre suf →
      right.replay rootBytes suf = some right' →
      ∃ left', left.replay rootBytes suf = some left' ∧ Beneath pre left' right'
  | [], left, right, right', below, _, weak => by
      simp only [replay, Option.some.injEq] at weak
      subst weak
      exact ⟨left, rfl, below⟩
  | record :: rest, left, right, right', below, disjoint, weak => by
      simp only [replay] at weak ⊢
      cases bound : record.bind? rootBytes with
      | none => simp [bound] at weak
      | some intent =>
          simp only [bound] at weak ⊢
          obtain ⟨fresh, notRecorded⟩ := disjoint record (List.mem_cons_self ..)
          obtain ⟨nullifiersEq, transactionEq⟩ := bind_fields rootBytes bound
          have recorded : left.isRecorded intent.transactionId = right.isRecorded intent.transactionId := by
            rw [below.recorded, transactionEq]
            simp [notRecorded]
          have preflightEq : intent.preflight (left.light rootBytes) = intent.preflight (right.light rootBytes) :=
            preflight_light_congr rootBytes left right intent below.absent below.cells below.available
              (fun nullifier member => by
                rw [below.consumed]
                have : nullifier ∉ pre.flatMap IntentRecord.nullifiers := fresh nullifier (nullifiersEq ▸ member)
                simp [this])
          rw [recorded, preflightEq]
          split at weak
          · cases weak
          · rw [if_neg (by assumption)]
            split at weak
            · exact replay_beneath pre rest _ _ right' (below.install rootBytes intent)
                (fun record' member => disjoint record' (List.mem_cons_of_mem _ member)) weak
            · cases weak

/-- **The checkpoint's replay is the prefix-free replay, and its success decides disjointness**
(real to weak): a suffix the protocol replays from the checkpoint carries no prefix nullifier or
transaction id. -/
theorem replay_beneath_of_left (pre : List IntentRecord) :
    ∀ (suf : List IntentRecord) (left right left' : Engine), Beneath pre left right →
      left.replay rootBytes suf = some left' →
      Disjoint pre suf ∧ ∃ right', right.replay rootBytes suf = some right' ∧ Beneath pre left' right'
  | [], left, right, left', below, real => by
      simp only [replay, Option.some.injEq] at real
      subst real
      exact ⟨(fun _ member => nomatch member), right, rfl, below⟩
  | record :: rest, left, right, left', below, real => by
      simp only [replay] at real ⊢
      cases bound : record.bind? rootBytes with
      | none => simp [bound] at real
      | some intent =>
          simp only [bound] at real ⊢
          obtain ⟨nullifiersEq, transactionEq⟩ := bind_fields rootBytes bound
          split at real
          · cases real
          · rename_i notRecorded
            have leftFalse : left.isRecorded intent.transactionId = false := by simpa using notRecorded
            have both := leftFalse
            rw [below.recorded, Bool.or_eq_false_iff] at both
            have txFresh : record.transactionId ∉ pre.map IntentRecord.transactionId := by
              have := both.2; rw [transactionEq] at this; simpa using this
            split at real
            · rename_i passed
              have freshCheck := Intent.preflight_ok_fresh _ _ (preflight_ok_erase rootBytes _ _ passed)
              rw [Intent.nullifiersFreshCheck_eq_true_iff] at freshCheck
              have consumedFalse : ∀ nullifier ∈ intent.nullifiers, left.consumed nullifier = false :=
                fun nullifier member => freshCheck nullifier member
              have nullFresh : ∀ nullifier ∈ record.nullifiers,
                  nullifier ∉ pre.flatMap IntentRecord.nullifiers := by
                intro nullifier member
                have held := consumedFalse nullifier (nullifiersEq ▸ member)
                rw [below.consumed, Bool.or_eq_false_iff] at held
                simpa using held.2
              have preflightEq : intent.preflight (left.light rootBytes) =
                  intent.preflight (right.light rootBytes) :=
                preflight_light_congr rootBytes left right intent below.absent below.cells below.available
                  (fun nullifier member => by
                    rw [below.consumed]
                    have : nullifier ∉ pre.flatMap IntentRecord.nullifiers :=
                      nullFresh nullifier (nullifiersEq ▸ member)
                    simp [this])
              obtain ⟨restDisjoint, right', weak, below'⟩ :=
                replay_beneath_of_left pre rest _ _ left' (below.install rootBytes intent) real
              refine ⟨?_, right', ?_, below'⟩
              · intro record' member
                rcases List.mem_cons.mp member with same | later
                · subst same; exact ⟨nullFresh, txFresh⟩
                · exact restDisjoint record' later
              · rw [if_neg (by rw [both.1]; simp), ← preflightEq, passed]
                exact weak
            · cases real

end Engine

/-- Two checkpoint states with the same bytes at every identifier and the same allowance have the
same snapshot over any records (journal, history and consumed set are the records'). -/
theorem State.snapshot_congr (rootBytes : List UInt8 → Digest) {left right : State} (records : List IntentRecord)
    (bytes : ∀ cellId, (Seed.lookup left.cells cellId).getD left.absentBytes =
      (Seed.lookup right.cells cellId).getD right.absentBytes)
    (available : left.available = right.available) :
    left.snapshot rootBytes records = right.snapshot rootBytes records := by
  have bytesEq : (left.snapshot rootBytes records).canonicalBytes =
      (right.snapshot rootBytes records).canonicalBytes := funext bytes
  apply Engine.DataSnapshot.ext' rootBytes _ bytesEq
  show Snapshot.mk _ _ _ _ _ = Snapshot.mk _ _ _ _ _
  congr 1
  all_goals first
    | exact available
    | (funext cellId
       show (left.snapshot rootBytes records).model.roots cellId =
         (right.snapshot rootBytes records).model.roots cellId
       rw [← (left.snapshot rootBytes records).coherent cellId,
         ← (right.snapshot rootBytes records).coherent cellId, bytesEq])

/-- **The prefix-free replay is the resume** (HOT-PATH §2(h)): a checkpoint state admissible for
the whole log, a suffix carrying no prefix nullifier or transaction id, and the suffix replayed from
the checkpoint with no prefix known: the head state, over every record, is `resume`'s snapshot. -/
theorem resume_suffix (rootBytes : List UInt8 → Digest) {seed : Seed} {pre suf : List IntentRecord}
    {state : State} {right' : Engine}
    (admissible : state.Admissible ⟨seed, pre ++ suf⟩) (disjoint : Disjoint pre suf)
    (weak : (Engine.ofState state []).replay rootBytes suf = some right') :
    resume rootBytes ⟨seed, pre ++ suf⟩ pre.length state =
      some ((Engine.headState right').snapshot rootBytes (pre ++ suf)) := by
  obtain ⟨left', real, below⟩ := Engine.replay_beneath rootBytes pre suf _ _ right'
    (Engine.beneath_ofState state pre) disjoint weak
  have found : resumeEngine rootBytes ⟨seed, pre ++ suf⟩ pre.length state = some left' := by
    unfold resumeEngine
    rw [if_pos ((admissibleFast_iff _ _).mpr admissible)]
    simpa using real
  have resumed := resume_of_resumeEngine found
  rw [resumed]
  congr 1
  have rebased := resume_rebase resumed
  unfold resume at rebased
  rw [if_pos (ofSnapshot_admissible _ _), List.drop_length, List.take_length] at rebased
  simp only [DurableReceiver.replay, Option.some.injEq] at rebased
  rw [← rebased]
  apply State.snapshot_congr
  · intro cellId
    refine (congrArg (fun snapshot : DataSnapshot rootBytes => snapshot.canonicalBytes cellId) rebased).trans ?_
    show (left'.cells.get cellId).getD left'.absent = (Seed.lookup right'.cells.entries cellId).getD right'.absent
    rw [CellTable.get_entries, below.cells, below.absent]
  · exact below.available

/-- **The converse**: a resume over the suffix decides admissibility and disjointness, and is the
prefix-free replay's head state over every record. -/
theorem resume_disjoint (rootBytes : List UInt8 → Digest) {seed : Seed} {pre suf : List IntentRecord}
    {state : State} {snapshot : DataSnapshot rootBytes}
    (resumed : resume rootBytes ⟨seed, pre ++ suf⟩ pre.length state = some snapshot) :
    state.Admissible ⟨seed, pre ++ suf⟩ ∧ Disjoint pre suf ∧ ∃ right',
      (Engine.ofState state []).replay rootBytes suf = some right' ∧
      snapshot = (Engine.headState right').snapshot rootBytes (pre ++ suf) := by
  have admissible : state.Admissible ⟨seed, pre ++ suf⟩ := by
    unfold resume at resumed
    split at resumed
    · assumption
    · cases resumed
  rw [resume_eq_resumeEngine] at resumed
  cases found : resumeEngine rootBytes ⟨seed, pre ++ suf⟩ pre.length state with
  | none => simp [found] at resumed
  | some left' =>
      have real : (Engine.ofState state pre).replay rootBytes suf = some left' := by
        unfold resumeEngine at found
        rw [if_pos ((admissibleFast_iff _ _).mpr admissible)] at found
        simpa using found
      obtain ⟨disjoint, right', weak, _⟩ := Engine.replay_beneath_of_left rootBytes pre suf _ _ left'
        (Engine.beneath_ofState state pre) real
      refine ⟨admissible, disjoint, right', weak, ?_⟩
      have := resume_suffix rootBytes admissible disjoint weak
      rw [resume_eq_resumeEngine, found] at this
      rw [found] at resumed
      exact (Option.some.inj resumed).symm.trans (Option.some.inj this)

#assert_axioms resume_suffix
#assert_axioms resume_disjoint

end Minidregg.Kernel.DurableEngine
