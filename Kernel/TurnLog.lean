/-
# Kernel.TurnLog -- a log of Turns, folded by `World.admit` (FD-1, R4a)

The deployed genesis World of a `Seed`, the Turn log's framing, and the
follower: decode each entry (`DeployedTurnCodec.decodeTurn`), admit it
(`World.admit` at `DeployedHistory.history`), stop by height on the first entry
that does not decode or does not take.  `follow_ok_iff` says the follower IS
`World.fold` over the decoded log.  No persisted byte changes: the Host still
appends `IntentRecord`s; `Host/TurnLogFollower` derives this log from them.

The root a follower reports (`turnLogRoot`) is the deployed root's shape: the
system slot `systemLeaf height logRoot` with the World's own head (the chain
over turn digests), and each listed cell's `rootBytes` of the bytes the World
holds for it (`bytesOf`: the canonical encoding, or the retired image).
-/
import Kernel.DeployedTurnCodec
import Compiler.DurableCheckpointCodec
import Theory.AssertAxioms

namespace Minidregg.Kernel.TurnLog

open Minidregg.Theory.Store
open Minidregg.Theory.TypedAuthorization (Digest)
open Minidregg.Theory.ResourceCost (Lane Charge)
open Minidregg.Kernel.World
open Minidregg.Kernel.DeployedBridge
open Minidregg.Kernel.DeployedHistory
open Minidregg.Kernel.DeployedTurnCodec
open Minidregg.Kernel.TurnOfIntent
open Minidregg.Compiler
open Minidregg.Compiler.Tower256ConcreteBackend
open Minidregg.Kernel.DurableDataIntent (TransactionId StableEvent)

set_option autoImplicit false

/-- The deployed World. -/
abbrev DWorld := World deployedR TransactionId Digest

/-! ## Genesis -/

/-- Why a seed has no genesis World. -/
inductive GenesisRefusal
  /-- The bytes an unlisted cell holds do not read as the absent slot. -/
  | absentNotAbsent
  /-- A seed cell's bytes do not decode at any registry kind. -/
  | undecodable (cell : CellId)
  /-- A seed lists one cell id twice. -/
  | duplicateCell (cell : CellId)
  deriving DecidableEq, Repr

/-- The genesis system cell with the seed's allowance: the head `(0, logRoot0)`
and one `allowance` row per meter lane. -/
def genesisSystem (available : Charge) : Store (sysLayout TransactionId Digest) :=
  meterLanes.foldl (fun s lane => Store.set s ⟨SysSpace.allowance, lane⟩ (some (available lane)))
    (World.genesisSystem history)

/-- Mark retired seed cells. -/
def retireRows (s : Store (sysLayout TransactionId Digest)) (ids : List CellId) :
    Store (sysLayout TransactionId Digest) :=
  ids.foldl (fun s c => Store.set s ⟨SysSpace.retired, c⟩ (some ())) s

/-- **The deployed genesis World of a seed**: every seed cell decoded at its
registry kind (a retired image is an absent cell with a `retired` row), the
seed's allowance in the meter, the head at height 0. -/
def genesisOfSeed (seed : DurableReceiver.Seed) : Except GenesisRefusal DWorld := do
  match decodeCell seed.absentBytes with
  | some none => if retiresCell seed.absentBytes then throw .absentNotAbsent
  | _ => throw .absentNotAbsent
  let ids := seed.cells.map fun c => c.1.value
  unless ids.Nodup do
    throw (.duplicateCell ((ids.find? fun c => ids.count c > 1).getD 0))
  let mut cells : Cells deployedR := 0
  let mut retired : List CellId := []
  for entry in seed.cells do
    let id := entry.1
    let bytes := entry.2
    match decodeCell bytes with
    | none => throw (.undecodable id.value)
    | some slot =>
      cells := DFinsupp.update cells id.value slot
      if retiresCell bytes then retired := id.value :: retired
  return ⟨cells, retireRows (genesisSystem seed.available) retired.reverse⟩

/-! ## The follower -/

/-- Why a follower stopped, and at which height (0-based entry index). -/
inductive FollowStop
  | undecodable (height : Nat)
  | refused (height : Nat) (reason : Reject)
  deriving DecidableEq, Repr

/-- Fold a list of entries' bytes from `w`, numbering from `height`. -/
def followFrom (w : DWorld) (height : Nat) : List (List UInt8) → Except FollowStop DWorld
  | [] => .ok w
  | entry :: rest =>
    match decodeTurn entry with
    | none => .error (.undecodable height)
    | some t =>
      match World.admit history w t with
      | .error reason => .error (.refused height reason)
      | .ok w' => followFrom w' (height + 1) rest

/-- **The follower IS the fold**: it reaches `W` exactly when every entry
decodes and `World.fold` of the decoded turns reaches `W`. -/
theorem followFrom_ok_iff (w W : DWorld) (height : Nat) (entries : List (List UInt8)) :
    followFrom w height entries = .ok W ↔
      ∃ turns, entries.mapM decodeTurn = some turns ∧ World.fold history w turns = some W := by
  induction entries generalizing w height with
  | nil =>
    constructor
    · intro h
      cases h
      exact ⟨[], rfl, rfl⟩
    · rintro ⟨turns, hm, hf⟩
      have : turns = [] := by simpa using hm.symm
      subst this
      simp only [World.fold_nil, Option.some.injEq] at hf
      subst hf
      rfl
  | cons entry rest ih =>
    cases hd : decodeTurn entry with
    | none =>
      simp [followFrom, hd, List.mapM_cons]
    | some t =>
      have hmap : (entry :: rest).mapM decodeTurn = (rest.mapM decodeTurn).map (t :: ·) := by
        simp only [List.mapM_cons, hd]
        cases rest.mapM decodeTurn <;> rfl
      rw [hmap]
      cases ha : World.admit history w t with
      | error r =>
        have hs : World.step history w t = none := by
          simp [World.step, ha, Except.toOption]
        simp only [followFrom, hd, ha]
        constructor
        · intro h
          cases h
        · rintro ⟨turns, hm, hf⟩
          cases hr : rest.mapM decodeTurn with
          | none => simp [hr] at hm
          | some ts =>
            simp only [hr, Option.map_some, Option.some.injEq] at hm
            subst hm
            simp [World.fold_cons, hs] at hf
      | ok w' =>
        have hs : World.step history w t = some w' := by
          simp [World.step, ha, Except.toOption]
        simp only [followFrom, hd, ha]
        rw [ih]
        constructor
        · rintro ⟨ts, hm, hf⟩
          exact ⟨t :: ts, by simp [hm], by simp [World.fold_cons, hs, hf]⟩
        · rintro ⟨turns, hm, hf⟩
          cases hr : rest.mapM decodeTurn with
          | none => simp [hr] at hm
          | some ts =>
            simp only [hr, Option.map_some, Option.some.injEq] at hm
            subst hm
            exact ⟨ts, rfl, by simpa [World.fold_cons, hs] using hf⟩

/-- A log entry's frame: its length, then its bytes. -/
def frameEntries (entries : List (List UInt8)) : List UInt8 :=
  (StreamCodec.list bytesStream).encode entries

/-- Unframe a whole log. -/
def unframeEntries (bytes : List UInt8) : Option (List (List UInt8)) :=
  full (StreamCodec.list bytesStream) bytes

theorem unframe_frame (entries : List (List UInt8)) :
    unframeEntries (frameEntries entries) = some entries := full_encode _ _

/-! ## The root a follower reports -/

/-- The bytes the World holds for a cell id: its canonical encoding, or the
retired image. -/
def bytesOf (w : DWorld) (c : CellId) : List UInt8 :=
  if (w.retired c).isSome then
    ResourceBirthCodec.LifecycleImage.bytes CanonicalCellRegistry.registry .retired
  else encodeCell (w.cells c)

/-- The root over the system slot (the World's head) and the listed cells. -/
def turnLogRoot (w : DWorld) (ids : List CellId) : Digest :=
  let (height, logRoot) := w.head.getD (0, history.logRoot0)
  WorldRoot.deployedRoot
    ((WorldRoot.Key.system, DurableCheckpointCodec.systemLeaf height logRoot) ::
      ids.map fun c => (WorldRoot.Key.cell c, ResourceBirthCodec.rootBytes (bytesOf w c)))

/-- The cell ids a log names: the seed's, then each create's, without repeats. -/
def idsOf (seed : DurableReceiver.Seed) (turns : List (DTurn deployedR Digest)) : List CellId :=
  ((seed.cells.map fun c => c.1.value) ++ turns.flatMap fun t => t.creates.map Prod.fst).eraseDups

#assert_axioms decodeTurn_encodeTurn
#assert_axioms followFrom_ok_iff
#assert_axioms unframe_frame

end Minidregg.Kernel.TurnLog
