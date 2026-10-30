/-
# The effect class of a Host outcome (SYNTHESIS §B row 4; resource-client §5.4 contract 2)

A client that has one signed request and one reply must decide ONE of three
things, and nothing else: author a fresh attempt (the request provably left no
record), consume the admitted result, or look up the exact call again (the
reply decided nothing). Until now that decision was read off the response BYTE
(255 = "refused, retry with a fresh nonce"), and the Host answered 255 for
`unavailable`, `uncertain`, `contention` and every thrown handler as well, so
four client sites authored second operations after undecided replies.

`Outcome.effectClass` is the decided field. It is a function of the outcome's
constructor and of nothing else: no byte, no phase string, no `repr`.

* `noRecord`  — `refused`: the receiver decided against the request before any
  append (`DurableReceiverIO.receiveCandidateWithFresh_rejected_*`), or a
  decoder refused the client's own bytes before any receiver ran. A fresh
  attempt is safe.
* `admitted`  — `confirmed` or `charged`: a durable receipt exists.
* `undecided` — `contention`, `unavailable`, `uncertain`, and `absent`: nothing
  here says the request can never be admitted; the client retries the EXACT
  call or looks it up. (`absent` is "not at this verified tip", not "never";
  a never-admissible witness is Phase 3 work.)
-/
module

public import Compiler.NativeHostCodec
public import Theory.AssertAxioms

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

namespace Minidregg.Compiler.NativeHostCodec

inductive EffectClass where
  /-- A proven no-append refusal: a fresh attempt is safe. -/
  | noRecord
  /-- A durable receipt: consume it. -/
  | admitted
  /-- Nothing was decided: retry the exact call or look it up; never author anew. -/
  | undecided
  deriving DecidableEq, Repr

def EffectClass.name : EffectClass → String
  | .noRecord => "no-record"
  | .admitted => "admitted"
  | .undecided => "undecided"

def Outcome.effectClass : Outcome → EffectClass
  | .confirmed .. => .admitted
  | .charged .. => .admitted
  | .refused .. => .noRecord
  | .contention => .undecided
  | .unavailable _ => .undecided
  | .uncertain _ => .undecided
  | .absent => .undecided

/-- Only a `refused` outcome is in the no-record class. -/
theorem effectClass_noRecord_iff (outcome : Outcome) :
    outcome.effectClass = .noRecord ↔
      ∃ reason phase detail leaf, outcome = .refused reason phase detail leaf := by
  cases outcome <;> simp [Outcome.effectClass]

/-- Only a confirmed or charged receipt is admitted. -/
theorem effectClass_admitted_iff (outcome : Outcome) :
    outcome.effectClass = .admitted ↔
      (∃ kind receipt, outcome = .confirmed kind receipt) ∨
      (∃ kind receipt cause, outcome = .charged kind receipt cause) := by
  cases outcome <;> simp [Outcome.effectClass]

/-- `unavailable`, `uncertain`, `contention` and `absent` decide nothing. -/
theorem effectClass_undecided_iff (outcome : Outcome) :
    outcome.effectClass = .undecided ↔
      outcome = .contention ∨ outcome = .absent ∨
      (∃ detail, outcome = .unavailable detail) ∨ (∃ detail, outcome = .uncertain detail) := by
  cases outcome <;> simp [Outcome.effectClass]

/-- The class survives the wire: decoding the encoded outcome yields the same class. -/
theorem effectClass_decode_encode (outcome : Outcome) :
    (outcomeCodec.decode (outcomeCodec.encode outcome)).map Outcome.effectClass =
      some outcome.effectClass := by
  rw [outcomeCodec.decode_encode]; rfl

/-- Teeth: the three classes are inhabited by distinct outcomes, so a client that
collapses two of them is refuted by a concrete frame. -/
theorem effectClass_poles :
    (Outcome.refused .operationRejected [] []).effectClass = .noRecord ∧
    (Outcome.uncertain []).effectClass = .undecided ∧
    (Outcome.unavailable []).effectClass = .undecided ∧
    Outcome.contention.effectClass = .undecided ∧
    Outcome.absent.effectClass = .undecided := by
  exact ⟨rfl, rfl, rfl, rfl, rfl⟩

#assert_axioms effectClass_noRecord_iff
#assert_axioms effectClass_admitted_iff
#assert_axioms effectClass_undecided_iff
#assert_axioms effectClass_decode_encode
#assert_axioms effectClass_poles

end Minidregg.Compiler.NativeHostCodec
