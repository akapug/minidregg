/-
STATEMENT (stream continuity, hot route registration).

A hot route registration on a running grain is admitted exactly when the serving
session holds a fresh opening read of the Store's head at or above the grain's
birth height. The opening read is either the tag its image was read with (cold
open, extension of a physical suffix) or a MAC-verified re-read of the head
entry made at the handoff itself. An image the session advanced by its own
exact append carries no tag (`Loaded.extend` sets `headTag := none`), so the
second case is what a serving Host needs; it is the same verifier the cold
open uses (`DurableHistory.Head.verify`), never a participant's say-so.

`decide` is the pure core of `ApplicationStreamContinuity.withOpenedFreshTip`:
the IO reads the Store, builds a `Held` and a physical `Option Physical`, and
asks `decide`. Each refusal has its own name.
-/
import Compiler.DurableReceiverCore

namespace Minidregg.Kernel.ApplicationStreamContinuityFresh

open Minidregg.Compiler.DurableReceiverIO (Entry)

set_option autoImplicit false

/-- What the serving session holds at its image's head. -/
structure Held where
  /-- Height of the held image. -/
  height : Nat
  /-- The frame of the head record (`none`: the history is empty). -/
  headRecord : Option (List UInt8)
  /-- The tag the image was read with (`Loaded.headTag`); `none` after the
  session's own append, whose image was extended in memory. -/
  headTag : Option (List UInt8)
  /-- The tag of a MAC-verified re-read of the head entry made at the handoff;
  `none` when no such read was made or it did not verify. -/
  verifiedRead : Option (List UInt8)

/-- What the Store's tip is when read at the handoff. -/
structure Physical where
  head : Nat
  entries : List Entry

inductive Verdict where
  | admitted
  | emptyHistory
  /-- No tag the session holds or verified: the opening read is missing. -/
  | noOpeningRead
  /-- The session's image is below the grain's birth height. -/
  | belowBirth
  /-- The Store's tip is not exactly the session's head entry. -/
  | tipChanged
  | tipUnavailable
  deriving DecidableEq, Repr

/-- The opening read: the held tag, else the verified re-read. -/
def Held.openingTag (held : Held) : Option (List UInt8) :=
  held.headTag.or held.verifiedRead

def decide (birthHeight : Nat) (held : Held) (physical : Option Physical) : Verdict :=
  match held.headRecord with
  | none => .emptyHistory
  | some record =>
    match held.openingTag with
    | none => .noOpeningRead
    | some tag =>
      if held.height < birthHeight then .belowBirth
      else match physical with
        | none => .tipUnavailable
        | some tip =>
            if tip.head = held.height ∧ tip.entries = [⟨record, tag⟩] then .admitted
            else .tipChanged

/-- The statement. A hot registration is admitted iff the serving session holds
an opening read, is at or above the grain's birth height, and the Store's tip
is exactly the head entry that read authenticates. -/
def HotRegistrationAdmitted (birthHeight : Nat) (held : Held) (physical : Option Physical) : Prop :=
  decide birthHeight held physical = .admitted

theorem hotRegistration_iff (birthHeight : Nat) (held : Held) (physical : Option Physical) :
    HotRegistrationAdmitted birthHeight held physical ↔
      ∃ record tag, held.headRecord = some record ∧ held.openingTag = some tag ∧
        birthHeight ≤ held.height ∧
        physical = some ⟨held.height, [⟨record, tag⟩]⟩ := by
  unfold HotRegistrationAdmitted decide
  rcases hr : held.headRecord with _ | record
  · simp
  rcases ht : held.openingTag with _ | tag
  · simp
  by_cases below : held.height < birthHeight
  · simp only [below, if_true]
    constructor
    · intro h; cases h
    · rintro ⟨_, _, hr', ht', le, _⟩; omega
  · rcases physical with _ | tip
    · simp [below]
    · simp only [below, if_false]
      by_cases ok : tip.head = held.height ∧ tip.entries = [⟨record, tag⟩]
      · simp only [ok, and_self, if_true, true_iff]
        refine ⟨record, tag, rfl, rfl, by omega, ?_⟩
        obtain ⟨a, b⟩ := ok
        cases tip; simp_all
      · simp only [ok, if_false]
        constructor
        · intro h; cases h
        · rintro ⟨r, t, hr', ht', _, hp⟩
          cases hr'; cases ht'
          simp at hp
          subst hp
          exact absurd ⟨rfl, rfl⟩ ok

/-! ## The poles -/

private def tagBytes : List UInt8 := [7]
private def recordBytes : List UInt8 := [1, 2, 3]

/-- The defect case: the session advanced by its own append (`headTag := none`);
the verified re-read supplies the opening read. -/
def ownAppendHeld : Held :=
  ⟨5, some recordBytes, none, some tagBytes⟩

def currentTip : Option Physical := some ⟨5, [⟨recordBytes, tagBytes⟩]⟩

/-- Satisfiable: a registration after a fresh opening read is admitted, both
with a held tag and with only a verified re-read. -/
theorem satisfiable_verified_reread : HotRegistrationAdmitted 3 ownAppendHeld currentTip := by
  unfold HotRegistrationAdmitted; decide +kernel

theorem satisfiable_held_tag :
    HotRegistrationAdmitted 3 ⟨5, some recordBytes, some tagBytes, none⟩ currentTip := by
  unfold HotRegistrationAdmitted; decide +kernel

/-- Teeth, by name: no opening read at all. -/
theorem teeth_noOpeningRead :
    decide 3 ⟨5, some recordBytes, none, none⟩ currentTip = .noOpeningRead := by
  decide +kernel

/-- Teeth: a stale tip (the Store moved on past the session's head). -/
theorem teeth_staleTip :
    decide 3 ownAppendHeld (some ⟨6, [⟨[9], [9]⟩]⟩) = .tipChanged := by
  decide +kernel

/-- Teeth: a tip whose head entry is another tag at the same height. -/
theorem teeth_forkedTip :
    decide 3 ownAppendHeld (some ⟨5, [⟨recordBytes, [8]⟩]⟩) = .tipChanged := by
  decide +kernel

/-- Teeth: the session image is below the grain's birth height. -/
theorem teeth_belowBirth : decide 6 ownAppendHeld currentTip = .belowBirth := by
  decide +kernel

/-- Teeth: an empty history has no head to read. -/
theorem teeth_emptyHistory :
    decide 0 ⟨0, none, none, none⟩ (some ⟨0, []⟩) = .emptyHistory := by
  decide +kernel

/-- The refusals are pairwise distinct by name (law 10: loud, and not one message). -/
theorem refusals_distinct :
    Verdict.noOpeningRead ≠ Verdict.tipChanged ∧ Verdict.noOpeningRead ≠ Verdict.belowBirth ∧
    Verdict.tipChanged ≠ Verdict.belowBirth ∧ Verdict.noOpeningRead ≠ Verdict.admitted := by
  decide

/-- Premise inhabitation: the statement's premise is met by some session. -/
theorem premise_inhabited :
    ∃ (birth : Nat) (held : Held) (physical : Option Physical),
      HotRegistrationAdmitted birth held physical :=
  ⟨3, ownAppendHeld, currentTip, satisfiable_verified_reread⟩

/-- A held tag alone also suffices only when it matches the tip: the defect's
cause is the absence of both, not a missing field. -/
theorem noRead_noAdmission (birth : Nat) (h : Held) (p : Option Physical)
    (none_ : h.headTag = none) (nov : h.verifiedRead = none) :
    ¬ HotRegistrationAdmitted birth h p := by
  rw [hotRegistration_iff]
  rintro ⟨r, t, _, ht, _⟩
  simp [Held.openingTag, none_, nov] at ht

#assert_axioms hotRegistration_iff
#assert_axioms satisfiable_verified_reread
#assert_axioms satisfiable_held_tag
#assert_axioms teeth_noOpeningRead
#assert_axioms teeth_staleTip
#assert_axioms teeth_forkedTip
#assert_axioms teeth_belowBirth
#assert_axioms teeth_emptyHistory
#assert_axioms refusals_distinct
#assert_axioms premise_inhabited
#assert_axioms noRead_noAdmission

end Minidregg.Kernel.ApplicationStreamContinuityFresh
