/-
# Kernel.SnapRepresents -- what it means for a deployed snapshot to represent a World

Below `Compiler.DurableReceiverCore`, so a `Loaded` can carry its World and the
proof that its snapshot represents it (FD-1 4a).  `SnapRepresents`, the
executor's shapes, `ofIntent_run` (a represented snapshot's admitted intent is a
`World.step` of its derived turn) and `replay_model`/`resume_model` moved here
unchanged from `Kernel.HostRefinesWorldCore` (same namespace, same statements).
-/
import Kernel.TurnOfIntent
import Kernel.DurableCheckpoint
import Theory.AssertAxioms

namespace Minidregg.Kernel.HostRefinesWorld

open Minidregg.Theory.Store
open Minidregg.Kernel.World
open Minidregg.Kernel.TurnOfIntent
open Minidregg.Theory.ResourceCost (Lane Charge)
open Minidregg.Kernel.DurableCommitProtocol (Snapshot Schedule CrashPoint)
open Minidregg.Kernel.DurableDataIntent
  (DataIntent DataSnapshot StableEvent StableNullifier TransactionId Outcome execute)

set_option autoImplicit false

section Represent

variable {R : Registry} {D : Type} [DecidableEq D]
variable {rootBytes : List UInt8 → Theory.TypedAuthorization.Digest}

/-- The held cells a deployed snapshot decodes to. -/
def cellsOf (B : Bridge R D) (snap : DataSnapshot rootBytes) (c : CellId) : Option (Cell R) :=
  (B.codec.decode (snap.canonicalBytes ⟨c⟩)).getD none

/-- **What it means for a deployed snapshot at a height to represent a world.** -/
structure SnapRepresents (B : Bridge R D) (snap : DataSnapshot rootBytes) (height : Nat)
    (w : World R TransactionId D) : Prop where
  /-- Every cell's canonical bytes decode to exactly the world's cell. -/
  cells : ∀ c : CellId, B.codec.decode (snap.canonicalBytes ⟨c⟩) = some (w.cells c)
  /-- The spent set is the consumed set, under the injective key. -/
  spent : ∀ d, (w.spent d).isSome = true ↔ ∃ n, B.key n = d ∧ snap.model.consumed n = true
  /-- The journal holds exactly the journaled transaction ids. -/
  journal : ∀ x, (w.journal x).isSome = (Snapshot.lookupRecorded x snap.model.journal).isSome
  /-- The clock: the head height is the deployed height. -/
  head : ∃ r, w.head = some (height, r)
  /-- Every meter lane but storage is the deployed allowance. -/
  meter : ∀ l, l ≠ .storageBytes → w.meter l = snap.model.available l
  /-- Storage: the model charges the patch, the present Host the image (G-CHARGE). -/
  storage : snap.model.available .storageBytes ≤ w.meter .storageBytes
  /-- A cell is retired exactly when its deployed bytes are the retirement. -/
  retired : ∀ c, (w.retired c).isSome = B.codec.retires (snap.canonicalBytes ⟨c⟩)
  /-- No parent rows: the present Host keeps parentage in the authority
  cell's plane 13, inside a cell's bytes (G-PARENT, T7). -/
  parent : ∀ c, w.parent c = none

theorem cellsOf_eq {B : Bridge R D} {snap : DataSnapshot rootBytes} {height : Nat}
    {w : World R TransactionId D} (rep : SnapRepresents B snap height w) (c : CellId) :
    w.cells c = cellsOf B snap c := by
  simp [cellsOf, rep.cells c]

/-! ### The executor's outcomes -/

/-- Whether an outcome installed the intent. -/
def Installs : Outcome rootBytes → Bool
  | .accepted _ => true
  | .crashed .afterAtomicInstall _ => true
  | _ => false

/-- **The executor's two shapes**: it installed (the id was fresh and the
preflight passed), or it left the snapshot as it was. -/
theorem execute_cases (schedule : Schedule) (before : DataSnapshot rootBytes)
    (intent : DataIntent rootBytes) :
    (Installs (execute schedule before intent) = true ∧
        Snapshot.lookupRecorded intent.transactionId before.model.journal = none ∧
        intent.preflight before = .ok () ∧
        (execute schedule before intent).storeAfter before = DataSnapshot.install before intent) ∨
      (Installs (execute schedule before intent) = false ∧
        (execute schedule before intent).storeAfter before = before) := by
  unfold execute
  split
  · split <;> exact .inr ⟨rfl, rfl⟩
  · rename_i hl
    split
    · exact .inr ⟨rfl, rfl⟩
    · rename_i hp
      cases schedule with
      | complete => exact .inl ⟨rfl, hl, hp, rfl⟩
      | crash pt =>
          cases pt
          · exact .inr ⟨rfl, rfl⟩
          · exact .inl ⟨rfl, hl, hp, rfl⟩

/-- What a passing preflight establishes about the nullifiers and the meter. -/
theorem preflight_facts {before : DataSnapshot rootBytes} {intent : DataIntent rootBytes}
    (ok : intent.preflight before = .ok ()) :
    intent.nullifiers.Nodup ∧ (∀ n ∈ intent.nullifiers, before.model.consumed n = false) ∧
      intent.exactCharge ≤ before.model.available := by
  have lower : intent.erase.preflight before.model = .ok () := by
    unfold DataIntent.preflight at ok
    split at ok
    · cases ok
    split at ok
    · cases ok
    split at ok
    · cases ok
    · assumption
  have fresh := DurableCommitProtocol.Intent.preflight_ok_fresh _ _ lower
  unfold DurableCommitProtocol.Intent.preflight at lower
  split_ifs at lower with h1 h2 h3 h4 h5 h6
  refine ⟨?_, ?_, ?_⟩
  · simpa using h3
  · intro n m
    exact (DurableCommitProtocol.Intent.nullifiersFreshCheck_eq_true_iff _ _).mp fresh n
      (by simpa using m)
  · exact (Theory.ResourceCost.Charge.fundedCheck_eq_true_iff _ _).mp (by simpa using h6)

/-! ### `ofIntent_run` -/

theorem lookupPostBytes_some {c : DurableDataIntent.CellId} :
    ∀ {ws : List DurableDataIntent.DataWrite} {b : List UInt8},
      DataSnapshot.lookupPostBytes c ws = some b →
        ∃ w0 ∈ ws, w0.cellId = c ∧ w0.canonicalPostBytes = b
  | [], _, h => by cases h
  | w0 :: rest, b, h => by
      unfold DataSnapshot.lookupPostBytes at h
      split at h
      · rename_i e
        exact ⟨w0, by simp, e, Option.some.inj h⟩
      · obtain ⟨w1, m, e, eb⟩ := lookupPostBytes_some h
        exact ⟨w1, by simp [m], e, eb⟩

omit [DecidableEq D] in
theorem decodes_of_derived {B : Bridge R D} {H : History R TransactionId StableEvent D}
    {cells : CellId → Option (Cell R)} {retired : CellId → Bool} {intent : DataIntent rootBytes}
    {t : DTurn R D}
    (d : Derived B H cells retired intent t) {w0 : DurableDataIntent.DataWrite} (hw : w0 ∈ intent.writes) :
    ∃ v, B.codec.decode w0.canonicalPostBytes = some v := by
  obtain ⟨δ, hδ, -, -⟩ := delta_of_write d hw
  have spec := deltaOf_spec hδ
  cases δ with
  | absent => exact ⟨_, spec.2.1⟩
  | burn => exact ⟨_, spec.2.1⟩
  | create => exact ⟨_, spec.2⟩
  | change => exact ⟨_, spec.2⟩
  | retire => exact ⟨_, spec.2.1⟩

theorem lookupPostBytes_none_unwritten {c : CellId} :
    ∀ {ws : List DurableDataIntent.DataWrite}, DataSnapshot.lookupPostBytes ⟨c⟩ ws = none →
      c ∉ writeIds ws
  | [], _ => by simp [writeIds]
  | w0 :: rest, h => by
      unfold DataSnapshot.lookupPostBytes at h
      split at h
      · cases h
      · rename_i ne
        intro m
        simp only [writeIds, List.map_cons, List.mem_cons] at m
        rcases m with e | m
        · exact ne (by rw [e])
        · exact lookupPostBytes_none_unwritten h m

/-- **`ofIntent_run`.**  `World.step H w (ofIntent w i)` is the deployed
post-state: from a represented snapshot, an intent the executor would install
(fresh id, passing preflight) and its derived turn, `World.step` accepts the
turn and its world represents `DataSnapshot.install` one height up. -/
theorem ofIntent_run (B : Bridge R D) (H : History R TransactionId StableEvent D)
    {snap : DataSnapshot rootBytes} {height : Nat} {w : World R TransactionId D}
    (rep : SnapRepresents B snap height w) {intent : DataIntent rootBytes} {t : DTurn R D}
    (derived : Turn.ofIntent B H w intent = .ok t)
    (fresh : Snapshot.lookupRecorded intent.transactionId snap.model.journal = none)
    (ready : intent.preflight snap = .ok ()) :
    ∃ w', World.step H w t = some w' ∧
      SnapRepresents B (DataSnapshot.install snap intent) (height + 1) w' := by
  obtain ⟨r, hh⟩ := rep.head
  obtain ⟨nodup, unconsumed, funded⟩ := preflight_facts ready
  have jfresh : w.journal intent.transactionId = none := by
    have := rep.journal intent.transactionId
    rw [fresh] at this
    simpa using this
  have unspent : ∀ n ∈ intent.nullifiers, w.spent (B.key n) = none := by
    intro n m
    cases hs : w.spent (B.key n) with
    | none => rfl
    | some u =>
        obtain ⟨n', hk, hc⟩ := (rep.spent (B.key n)).mp (by simp [hs])
        have e := B.key_injective hk
        subst e
        rw [unconsumed _ m] at hc
        cases hc
  have fundedL : ∀ l, l ≠ .storageBytes → intent.exactCharge l ≤ w.meter l := by
    intro l e
    rw [rep.meter l e]
    exact funded l
  have fundedS : intent.exactCharge .storageBytes ≤ w.meter .storageBytes :=
    le_trans (funded _) rep.storage
  obtain ⟨w', hs, hcells, hsys⟩ := ofIntent_step B H derived hh jfresh nodup unspent fundedL fundedS
  have derived' : ofCells B H (fun c => w.cells c) (fun c => (w.retired c).isSome) intent = .ok t := derived
  obtain ⟨htx, hret, hrows, hnull, hchg, hchgS⟩ := ofCells_fields derived
  have d := ofCells_ok derived
  refine ⟨w', hs, ⟨fun c => ?_, fun dd => ?_, fun x => ?_, ⟨H.chain r (H.turnDigest t), ?_⟩, fun l e => ?_, ?_,
    fun c => ?_, fun c => ?_⟩⟩
  · -- cells
    rw [DataSnapshot.install_canonicalBytes, hcells c]
    cases hl : DataSnapshot.lookupPostBytes ⟨c⟩ intent.writes with
    | none =>
        simp only [Option.getD_none]
        unfold postCell
        rw [hl]
        exact rep.cells c
    | some b =>
        simp only [Option.getD_some]
        obtain ⟨w0, hw, -, rfl⟩ := lookupPostBytes_some hl
        obtain ⟨v, hv⟩ := decodes_of_derived d hw
        unfold postCell
        rw [hl]
        show B.codec.decode w0.canonicalPostBytes =
          some ((B.codec.decode w0.canonicalPostBytes).getD (w.cells c))
        rw [hv]
        rfl
  · -- spent
    show (w'.system ⟨SysSpace.spent, dd⟩).isSome = true ↔ _
    rw [hsys, sysPost_spent, hnull]
    have inst : ∀ n, (DataSnapshot.install snap intent).model.consumed n =
        (if n ∈ intent.nullifiers then true else snap.model.consumed n) := fun _ => rfl
    simp only [inst]
    by_cases hm : dd ∈ intent.nullifiers.map B.key
    · rw [if_pos hm]
      obtain ⟨n, hn, rfl⟩ := List.mem_map.mp hm
      exact ⟨fun _ => ⟨n, rfl, by simp [hn]⟩, fun _ => rfl⟩
    · rw [if_neg hm]
      rw [show (w.system ⟨SysSpace.spent, dd⟩).isSome = (w.spent dd).isSome from rfl, rep.spent dd]
      constructor
      · rintro ⟨n, hk, hc⟩
        exact ⟨n, hk, by simp [hc]⟩
      · rintro ⟨n, hk, hc⟩
        refine ⟨n, hk, ?_⟩
        by_cases hn : n ∈ intent.nullifiers
        · exact absurd (List.mem_map.mpr ⟨n, hn, hk⟩) hm
        · simpa [hn] using hc
  · -- journal
    show (w'.system ⟨SysSpace.journal, x⟩).isSome = _
    rw [hsys, sysPost_journal, htx]
    have inst : Snapshot.lookupRecorded x (DataSnapshot.install snap intent).model.journal =
        if intent.transactionId = x then some intent.erase
        else Snapshot.lookupRecorded x snap.model.journal := rfl
    rw [inst]
    by_cases e : x = intent.transactionId
    · rw [if_pos e, if_pos e.symm]
      rfl
    · rw [if_neg e, if_neg (Ne.symm e)]
      exact rep.journal x
  · -- head
    show w'.system ⟨SysSpace.head, ()⟩ = _
    rw [hsys, sysPost_head]
  · -- meter
    rw [meter_system, hsys, sysPost_allowance]
    show _ = snap.model.available l - intent.exactCharge l
    rw [← hchg l e, ← rep.meter l e]
    split
    · rfl
    · rename_i z
      simp only [not_not] at z
      rw [z, Nat.sub_zero]
      rfl
  · -- storage
    rw [meter_system, hsys, sysPost_allowance]
    show snap.model.available .storageBytes - intent.exactCharge .storageBytes ≤ _
    have hm := rep.storage
    split
    · show _ ≤ w.meter .storageBytes - t.charge .storageBytes
      omega
    · show _ ≤ w.meter .storageBytes
      omega
  · -- retired
    show (w'.system ⟨SysSpace.retired, c⟩).isSome =
      B.codec.retires ((DataSnapshot.install snap intent).canonicalBytes ⟨c⟩)
    rw [hsys, sysPost_retired, DataSnapshot.install_canonicalBytes]
    cases hl : DataSnapshot.lookupPostBytes ⟨c⟩ intent.writes with
    | none =>
        have nr : c ∉ t.retires := fun m => lookupPostBytes_none_unwritten hl (retires_written derived' m)
        simp only [nr, if_false, Option.getD_none]
        exact rep.retired c
    | some b =>
        obtain ⟨w0, hw, e, rfl⟩ := lookupPostBytes_some hl
        have same : w0.cellId.value = c := by rw [e]
        have iff := retires_iff derived' w0 hw
        rw [same] at iff
        simp only [Option.getD_some]
        by_cases r : B.codec.retires w0.canonicalPostBytes = true
        · rw [if_pos (iff.mpr r), r]; rfl
        · rw [if_neg (fun m => r (iff.mp m))]
          have unretired := written_unretired (ofCells_ok derived') hw
          rw [same] at unretired
          have unretired' : (w.system ⟨SysSpace.retired, c⟩).isSome = false := unretired
          rw [unretired']
          cases hb : B.codec.retires w0.canonicalPostBytes
          · rfl
          · exact absurd hb r
  · -- parent
    show w'.system ⟨SysSpace.parent, c⟩ = none
    rw [hsys, run_sysPatch_core H _ _ _ _ _ _ (fun e => SysSpace.noConfusion e)
      (fun e => SysSpace.noConfusion e)]
    unfold sysCore
    rw [hrows]
    simp only [List.map_nil, List.append_nil, Patch.run_append, run_createReads, Patch.run_cons, Patch.run_nil,
      op_apply_write, op_apply_allocate]
    rw [Store.set_ne _ _ _ _ (sys_space_ne (fun e => SysSpace.noConfusion e)),
      run_retireAllocs_ne _ _ _ (fun e => SysSpace.noConfusion e),
      Store.set_ne _ _ _ _ (sys_space_ne (fun e => SysSpace.noConfusion e))]
    exact rep.parent c

/-- What a replay does to the journal and the consumed set. -/
theorem replay_model :
    ∀ (records : List DurableReceiver.IntentRecord) (before after : DataSnapshot rootBytes),
      DurableReceiver.replay rootBytes before records = some after →
        after.model.journal =
            (records.map fun r => (r.transactionId, DurableCheckpoint.IntentRecord.erase r)).reverse ++
              before.model.journal ∧
          ∀ n, after.model.consumed n =
            (decide (n ∈ records.flatMap DurableReceiver.IntentRecord.nullifiers) ||
              before.model.consumed n)
  | [], before, after, h => by
      simp only [DurableReceiver.replay, Option.some.injEq] at h
      subst h
      exact ⟨by simp, fun n => by simp⟩
  | r :: rs, before, after, h => by
      unfold DurableReceiver.replay at h
      cases hb : r.bind? rootBytes with
      | none => rw [hb] at h; cases h
      | some intent =>
          rw [hb] at h
          change (match DurableDataIntent.execute .complete before intent with
            | .accepted next => DurableReceiver.replay rootBytes next rs
            | _ => none) = some after at h
          split at h
          · rename_i next he
            have hn : next = DataSnapshot.install before intent := by
              rcases execute_cases .complete before intent with ⟨-, -, -, a⟩ | ⟨i, -⟩
              · rw [he] at a; exact a
              · rw [he] at i; cases i
            obtain ⟨hj, hc⟩ := replay_model rs next after h
            have he' := DurableCheckpoint.IntentRecord.erase_bind hb
            subst hn
            refine ⟨?_, fun n => ?_⟩
            · rw [hj]
              show _ ++ ((intent.erase.transactionId, intent.erase) :: before.model.journal) = _
              rw [he']
              simp [DurableCheckpoint.IntentRecord.erase]
            · rw [hc n]
              show (decide _ || (if n ∈ intent.erase.nullifiers then true else
                before.model.consumed n)) = _
              rw [he']
              by_cases hm : n ∈ r.nullifiers <;>
                simp [hm, DurableCheckpoint.IntentRecord.erase, List.flatMap_cons]
          · cases h

/-- What a resume is: the whole log's journal, and the prefix's nullifiers plus
the replayed suffix's. -/
theorem resume_model {image : DurableReceiver.Image} {bh : Nat} {st : DurableCheckpoint.State}
    {snap : DataSnapshot rootBytes} (h : DurableCheckpoint.resume rootBytes image bh st = some snap) :
    snap.model.journal =
        (image.accepted.map fun r => (r.transactionId, DurableCheckpoint.IntentRecord.erase r)).reverse ∧
      ∀ n, snap.model.consumed n =
        (decide (n ∈ (image.accepted.drop bh).flatMap DurableReceiver.IntentRecord.nullifiers) ||
          decide (n ∈ (image.accepted.take bh).flatMap DurableReceiver.IntentRecord.nullifiers)) := by
  unfold DurableCheckpoint.resume at h
  split at h
  · obtain ⟨hj, hc⟩ := replay_model _ _ _ h
    refine ⟨?_, fun n => hc n⟩
    rw [hj]
    show _ ++ ((image.accepted.take bh).map fun r =>
      (r.transactionId, DurableCheckpoint.IntentRecord.erase r)).reverse = _
    rw [← List.reverse_append, ← List.map_append, List.take_append_drop]
  · cases h
/-- **An accepted execution from a represented snapshot is an admitted turn**:
the executor's `.accepted next` and the derived turn give `World.admit = .ok w'`
with `next` representing `w'` one height up (`ofIntent_run`, read at `admit`). -/
theorem admit_of_accepted (B : Bridge R D) (H : History R TransactionId StableEvent D)
    {snap next : DataSnapshot rootBytes} {height : Nat} {w : World R TransactionId D}
    (rep : SnapRepresents B snap height w) {intent : DataIntent rootBytes} {t : DTurn R D}
    (derived : Turn.ofIntent B H w intent = .ok t)
    (executed : execute .complete snap intent = .accepted next) :
    ∃ w', World.admit H w t = .ok w' ∧ SnapRepresents B next (height + 1) w' := by
  rcases execute_cases .complete snap intent with ⟨-, fresh, ready, after⟩ | ⟨installs, -⟩
  · obtain ⟨w', hs, hrep⟩ := ofIntent_run B H rep derived fresh ready
    have hn : next = DataSnapshot.install snap intent := by
      rw [executed] at after; exact after
    refine ⟨w', ?_, hn ▸ hrep⟩
    unfold World.step at hs
    cases ha : World.admit H w t with
    | error r => rw [ha] at hs; cases hs
    | ok v => rw [ha] at hs; cases hs; rfl
  · rw [executed] at installs; simp [Installs] at installs

end Represent

#assert_axioms replay_model
#assert_axioms resume_model
#assert_axioms cellsOf_eq
#assert_axioms execute_cases
#assert_axioms preflight_facts
#assert_axioms lookupPostBytes_some
#assert_axioms decodes_of_derived
#assert_axioms ofIntent_run
#assert_axioms admit_of_accepted

end Minidregg.Kernel.HostRefinesWorld
