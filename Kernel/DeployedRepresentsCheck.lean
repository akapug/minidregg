/-
# Kernel.DeployedRepresentsCheck -- the open decides that its snapshot represents its World

FD-1 4a: a `Loaded` carries the World it represents.  An append keeps the
representation by theorem (`ofIntent_run`); an open has a World it folded and a
snapshot it resumed, and DECIDES the representation instead of trusting it:
`representsCheck` reads the finitely many rows either side holds and
`representsCheck_sound` turns `true` into `SnapRepresents bridge snap h w`.
No premise: a false answer refuses the open by name.

Every field is read from what the resumed snapshot is (`resume_model`: its
journal and consumed set are the log's; `resume_outside_support`: a cell id the
image never names holds the absent bytes) and from the World's finite supports.
-/
import Kernel.SnapRepresents
import Kernel.DeployedBridge
import Theory.AssertAxioms

namespace Minidregg.Kernel.HostRefinesWorld

open Minidregg.Theory.Store
open Minidregg.Kernel.World
open Minidregg.Kernel.TurnOfIntent
open Minidregg.Theory.ResourceCost (Lane Charge)
open Minidregg.Kernel.DurableCommitProtocol (Snapshot)
open Minidregg.Kernel.DurableDataIntent (DataSnapshot StableNullifier TransactionId)
open Minidregg.Kernel.DeployedBridge (deployedR bridge encodeCell retiresCell)
open Minidregg.Kernel.DurableReceiver (Image IntentRecord)
open Minidregg.Kernel.DurableEngine (resume_model)

set_option autoImplicit false

/-- `none` is the zero of a sparse slot; whether a slot is present is decidable
without comparing what it holds. -/
local instance optionNeZeroDecidable {α : Type} (x : Option α) : Decidable (x ≠ 0) :=
  decidable_of_iff (x.isSome = true) (by cases x <;> simp [Option.isSome] <;> rfl)

/-- The deployed World. -/
abbrev DWorld := World deployedR TransactionId Theory.TypedAuthorization.Digest

/-- Every meter lane, by constructor. -/
def allLanes : List Lane :=
  [.incidences, .turnBytes, .memoryTouches, .witnessBytes, .proofWork, .storageBytes,
    .networkBytes, .sideEffectCount, .feeDebit, .leaseByteBlocks]

theorem mem_allLanes (l : Lane) : l ∈ allLanes := by cases l <;> simp [allLanes]

/-- One cell id's bytes against the World's slot and retired mark: the
canonical encoding of the slot (or the retired image over an absent one), and
retired exactly when the bytes are the retirement. -/
def cellOk (w : DWorld) (bytes : List UInt8) (c : Nat) : Bool :=
  (bytes == encodeCell (w.cells c) || ((w.cells c).isNone && retiresCell bytes)) &&
    ((w.retired c).isSome == retiresCell bytes)

/-- A system row the snapshot side accounts for: a spent row is a key of one of
the log's nullifiers, a journal row one of its transaction ids, a retired row a
cell id the image names; there are no parent rows (G-PARENT). -/
def rowOk (keys : List Theory.TypedAuthorization.Digest) (txs : List TransactionId) (ids : List Nat) :
    Address (sysLayout TransactionId Theory.TypedAuthorization.Digest) → Bool
  | ⟨.spent, d⟩ => decide (d ∈ keys)
  | ⟨.journal, x⟩ => decide (x ∈ txs)
  | ⟨.retired, c⟩ => decide (c ∈ ids)
  | ⟨.parent, _⟩ => false
  | ⟨.head, _⟩ => true
  | ⟨.allowance, _⟩ => true

/-- **The decision.** -/
def representsCheck {rootBytes : List UInt8 → Theory.TypedAuthorization.Digest}
    (image : Image) (snap : DataSnapshot rootBytes) (w : DWorld) : Bool :=
  let ids := image.cellIds.map (·.value)
  let keys := (image.accepted.flatMap IntentRecord.nullifiers).map digestKey
  let txs := image.accepted.map IntentRecord.transactionId
  -- the absent slot reads as the World's absent, unretired cell
  (image.seed.absentBytes == encodeCell none) && !retiresCell image.seed.absentBytes &&
  -- every named cell, and the World holds no cell the image does not name
  image.cellIds.all (fun c => cellOk w (snap.canonicalBytes c) c.value) &&
  decide (∀ c ∈ w.cells.support, c ∈ ids) &&
  -- every row of the system cell is accounted for, and every nullifier and id is in it
  decide (∀ a ∈ w.system.support, rowOk keys txs ids a = true) &&
  keys.all (fun d => (w.spent d).isSome) &&
  txs.all (fun x => (w.journal x).isSome) &&
  -- the clock and the meter
  (match w.head with | some (h, _) => h == image.accepted.length | none => false) &&
  allLanes.all (fun l => w.allowanceOf l == some (snap.model.available l))

theorem lookupRecorded_isSome {C N E : Type} (x : TransactionId) :
    ∀ (l : List (TransactionId × DurableCommitProtocol.Intent TransactionId C N E)),
      (Snapshot.lookupRecorded x l).isSome = decide (x ∈ l.map Prod.fst)
  | [] => rfl
  | (y, a) :: rest => by
      unfold Snapshot.lookupRecorded
      by_cases e : y = x
      · subst e; simp
      · rw [if_neg e, lookupRecorded_isSome x rest]
        simp [Ne.symm e]

/-- A present system row is in the support. -/
private theorem mem_support_of_isSome {a : Address (sysLayout TransactionId Theory.TypedAuthorization.Digest)}
    {w : DWorld} (h : (w.system a).isSome = true) : a ∈ w.system.support :=
  DFinsupp.mem_support_iff.mpr (by intro z; rw [show w.system a = none from z] at h; cases h)

/-- **`representsCheck_sound`.**  A resumed snapshot the check accepts against
a World represents it at the image's height. -/
theorem representsCheck_sound {rootBytes : List UInt8 → Theory.TypedAuthorization.Digest}
    {image : Image} {bh : Nat} {st : DurableCheckpoint.State} {snap : DataSnapshot rootBytes}
    (resumed : DurableCheckpoint.resume rootBytes image bh st = some snap) {w : DWorld}
    (ok : representsCheck image snap w = true) :
    SnapRepresents bridge snap image.accepted.length w := by
  unfold representsCheck at ok
  simp only [Bool.and_eq_true, beq_iff_eq, Bool.not_eq_true', decide_eq_true_eq, List.all_eq_true] at ok
  obtain ⟨⟨⟨⟨⟨⟨⟨⟨absentEnc, absentNotRetired⟩, named⟩, cellsNamed⟩, rows⟩, spentAll⟩, journalAll⟩,
    head⟩, meter⟩ := ok
  obtain ⟨journalEq, consumedEq⟩ := resume_model resumed
  have consumedAll : ∀ n, snap.model.consumed n =
      decide (n ∈ image.accepted.flatMap IntentRecord.nullifiers) := by
    intro n
    rw [consumedEq n]
    conv => rhs; rw [← List.take_append_drop bh image.accepted]
    rw [List.flatMap_append]
    by_cases h1 : n ∈ (image.accepted.drop bh).flatMap IntentRecord.nullifiers
    · simp only [h1, decide_true, Bool.true_or, List.mem_append, or_true]
    · simp only [h1, decide_false, Bool.false_or, List.mem_append, or_false]
  -- one cell id, named or not
  have cell : ∀ c : Nat, cellOk w (snap.canonicalBytes ⟨c⟩) c = true := by
    intro c
    by_cases m : (⟨c⟩ : DurableDataIntent.CellId) ∈ image.cellIds
    · exact named _ m
    · rw [DurableCheckpoint.resume_outside_support rootBytes image bh st snap resumed _ m]
      have none : w.cells c = none := by
        by_contra present
        have := cellsNamed c (DFinsupp.mem_support_iff.mpr present)
        obtain ⟨c', m', e⟩ := List.mem_map.mp this
        exact m (by cases c'; simp at e; subst e; exact m')
      have unretired : (w.retired c).isSome = false := by
        cases hr : w.retired c with
        | none => rfl
        | some u =>
            have := rows _ (mem_support_of_isSome (a := ⟨SysSpace.retired, c⟩) (by
              show (w.retired c).isSome = true; rw [hr]; rfl))
            simp only [rowOk, decide_eq_true_eq] at this
            obtain ⟨c', m', e⟩ := List.mem_map.mp this
            exact absurd (by cases c'; simp at e; subst e; exact m') m
      simp [cellOk, none, unretired, ← absentEnc, absentNotRetired]
  refine ⟨fun c => ?_, fun d => ?_, fun x => ?_, ?_, fun l => ?_, fun c => ?_, fun c => ?_⟩
  · -- cells
    have h := cell c
    simp only [cellOk, Bool.and_eq_true, Bool.or_eq_true, beq_iff_eq] at h
    have := (Minidregg.Kernel.DeployedBridge.deployed_cells_iff (fun _ => snap.canonicalBytes ⟨c⟩)
      (fun _ => w.cells c)).mpr (fun _ => by
        rcases h.1 with enc | ⟨absent, ret⟩
        · exact .inl enc
        · exact .inr ⟨by simpa using absent, ret⟩) c
    exact this
  · -- spent
    constructor
    · intro present
      have := rows _ (mem_support_of_isSome (a := ⟨SysSpace.spent, d⟩) present)
      simp only [rowOk, decide_eq_true_eq] at this
      obtain ⟨n, hn, hk⟩ := List.mem_map.mp this
      exact ⟨n, hk, by rw [consumedAll]; simpa using hn⟩
    · rintro ⟨n, rfl, hc⟩
      rw [consumedAll] at hc
      exact spentAll _ (List.mem_map.mpr ⟨n, by simpa using hc, rfl⟩)
  · -- journal
    rw [journalEq, lookupRecorded_isSome]
    simp only [List.map_reverse, List.mem_reverse, List.map_map]
    have txsEq : (Prod.fst ∘ fun r : IntentRecord => (r.transactionId, DurableCheckpoint.IntentRecord.erase r)) =
        IntentRecord.transactionId := rfl
    rw [txsEq]
    cases hj : w.journal x with
    | none =>
        by_cases m : x ∈ image.accepted.map IntentRecord.transactionId
        · have := journalAll x m; rw [hj] at this; cases this
        · simp [m]
    | some v =>
        have := rows _ (mem_support_of_isSome (a := ⟨SysSpace.journal, x⟩) (by
          show (w.journal x).isSome = true; rw [hj]; rfl))
        simp only [rowOk, decide_eq_true_eq] at this
        rw [Option.isSome_some]
        exact (decide_eq_true_iff.mpr this).symm
  · -- head
    revert head
    cases hh : w.head with
    | none => intro h; cases h
    | some p =>
        obtain ⟨h, r⟩ := p
        intro e
        simp only [beq_iff_eq] at e
        exact ⟨r, by rw [e]⟩
  · -- meter
    simpa using meter l (mem_allLanes l)
  · -- retired
    have h := cell c
    simp only [cellOk, Bool.and_eq_true, beq_iff_eq] at h
    exact h.2
  · -- parent
    cases hp : w.parent c with
    | none => rfl
    | some p =>
        have := rows _ (mem_support_of_isSome (a := ⟨SysSpace.parent, c⟩) (by
          show (w.parent c).isSome = true; rw [hp]; rfl))
        simp [rowOk] at this

#assert_axioms representsCheck_sound

end Minidregg.Kernel.HostRefinesWorld
