/-
# Kernel.DefaultLaw -- the default policies of a member's cells, emitted from Lean

Every member account the fleet joins, every shell-provisioned member account, the
Hermes till and budget account and the private room cell were installed under
`{"type":"all","predicates":[]}` -- permit-all -- written as a Rust literal
(`fleet.rs`, `hermes.rs`, `roomkey.rs`, `genesis.sh`; resource-client §3 rows 2, 4;
SYNTHESIS §B rows 6-7). Under it any holder of any capability on the cell may do
anything the capability's verb allows, and strangers enrol under it on the demo node
(ruling R11, moved into Phase 1 by the council on 2026-10-26).

This module is the ONE source of those defaults, as `Pred` ASTs (ATLAS §7: the one
predicate algebra), with the theorems that say what they refuse. The JSON the client
installs is emitted from these definitions by `scripts/gen-default-laws.sh` into
`deploy/shell/templates/defaults/` (the client substitutes the owner's subject for
`@OWNER` / `@FOUNDER`, as `roomkey.rs` already does for `law.keys.json`'s `@FOUNDER`);
`scripts/gen-default-laws.sh --check` refuses a drift between this module and the
templates.

## What a law sees

A law is evaluated on the projected request state (`Compiler.CanonicalRuntimeProfile.requestSlots`,
inhabited for EVERY request: `request_verb_exact`, `request_subject_exact` below):
`request/verb` is the verb tag (`CredentialAuthorityEntryCodec.verbTag`: observe 1,
transfer/mutate 2, delegate 3, append 7, mint 8, burn 9, place 10, reserve 12;
installPolicy 4 and revokeCapability 5 are program-kind verbs and reach a cell's law
through its policy program, not through the cell) and `request/subject` the signer. The account law is judged on the account the request
TARGETS (`ResourceBirthPolicyController.policyResourceSlots`): a transfer targets the
payer's account, so a deposit into a till needs nothing from the till's law and the
till's law governs only what leaves it.

## The two defaults

* `accountLaw owner` -- a member account, a till, a budget account: anyone may observe
  (D8: everything on the demo box is world-readable); every other verb on the account --
  transfer, delegate, mint, burn, reserve -- only the owner's subject.
* `roomLaw founder` -- a private room cell: observe and append by any capability holder
  (the founder's invitations say who; `chat invite` grants `observe`+`append`);
  mutate, delegate, place and reserve by the founder alone, so no member can rewrite
  the room's state or re-delegate it.

The genesis `factoryPredicate` and the sponsor/clock `accountPredicate` in
`genesis.sh` are a different default (who may birth) and stay with the genesis author
(resource-client Q24); the two `accountPredicate`s can take `accountLaw` with the
sponsor's and the clock subject's ids.
-/
import Pred.Core
import Compiler.CanonicalRuntimeProfileCore
import Theory.AssertAxioms

namespace Minidregg.Kernel.DefaultLaw

open Minidregg.Pred
open Minidregg.Theory.TypedAuthorization (Verb ResourceKind Request)

set_option autoImplicit false

/-- The signer of the request, as the projected request state spells it. -/
def subjectSlot : Slot := "request/subject"

/-- The verb of the request, as the projected request state spells it. -/
def verbSlot : Slot := "request/verb"

/-- The tags of the verbs the defaults name (`CredentialAuthorityEntryCodec.verbTag`). -/
def observeTag : Int := 1
def appendTag : Int := 7

theorem observeTag_is_observeAccount :
    (Compiler.CredentialAuthorityEntryCodec.verbTag (Verb.observeAccount : Verb .account) : Int) = observeTag := rfl
theorem observeTag_is_observeObject :
    (Compiler.CredentialAuthorityEntryCodec.verbTag (Verb.observeObject : Verb .object) : Int) = observeTag := rfl
theorem appendTag_is_appendObject :
    (Compiler.CredentialAuthorityEntryCodec.verbTag (Verb.appendObject : Verb .object) : Int) = appendTag := rfl
theorem transfer_is_not_observe :
    (Compiler.CredentialAuthorityEntryCodec.verbTag (Verb.transfer : Verb .account) : Int) ≠ observeTag := by decide
theorem mutateObject_is_governing :
    (Compiler.CredentialAuthorityEntryCodec.verbTag (Verb.mutateObject : Verb .object) : Int) ≠ observeTag ∧
    (Compiler.CredentialAuthorityEntryCodec.verbTag (Verb.mutateObject : Verb .object) : Int) ≠ appendTag := by
  decide
theorem delegateObject_is_governing :
    (Compiler.CredentialAuthorityEntryCodec.verbTag (Verb.delegateObject : Verb .object) : Int) ≠ observeTag ∧
    (Compiler.CredentialAuthorityEntryCodec.verbTag (Verb.delegateObject : Verb .object) : Int) ≠ appendTag := by
  decide

/-- Every projected request state carries the signer. -/
theorem request_subject_exact {kind : ResourceKind} (request : Request kind) :
    (⟨Compiler.CanonicalRuntimeProfile.requestSlots request⟩ : State).get subjectSlot =
      some (Int.ofNat request.subject.value) := by
  simp [State.get, Compiler.CanonicalRuntimeProfile.requestSlots, subjectSlot]

/-- Every projected request state carries the verb. -/
theorem request_verb_exact {kind : ResourceKind} (request : Request kind) :
    (⟨Compiler.CanonicalRuntimeProfile.requestSlots request⟩ : State).get verbSlot =
      some (Int.ofNat (Compiler.CredentialAuthorityEntryCodec.verbTag request.verb)) := by
  simp [State.get, Compiler.CanonicalRuntimeProfile.requestSlots, verbSlot]

/-- The default law of a member account, a till and a budget account: observation by
anyone, every other verb by the owner alone. -/
def accountLaw (owner : Nat) : Pred :=
  Pred.any [.eq verbSlot observeTag, .eq subjectSlot (Int.ofNat owner)]

/-- The default law of a private room cell: observe and append by any capability
holder, every other verb by the founder alone. -/
def roomLaw (founder : Nat) : Pred :=
  Pred.any [.memberOf verbSlot [observeTag, appendTag], .eq subjectSlot (Int.ofNat founder)]

/-- What the shell installs today: every step admitted. -/
def permitAll : Pred := Pred.all []

theorem accountLaw_eval (owner : Nat) (old new : State) :
    eval (accountLaw owner) old new = true ↔
      new.get verbSlot = some observeTag ∨ new.get subjectSlot = some (Int.ofNat owner) := by
  unfold eval accountLaw
  simp [evalWith]

theorem roomLaw_eval (founder : Nat) (old new : State) (verb : Int)
    (step : new.get verbSlot = some verb) :
    eval (roomLaw founder) old new = true ↔
      (verb = observeTag ∨ verb = appendTag) ∨ new.get subjectSlot = some (Int.ofNat founder) := by
  unfold eval roomLaw
  simp [evalWith, step, List.contains_iff_mem]

theorem permitAll_eval (old new : State) : eval permitAll old new = true := by
  unfold eval permitAll
  simp

/-- **Under the default account law, a step that is not an observation is the owner's.**
A member under the default cannot transfer from, delegate, mint on, burn from or reserve
another member's account, till or budget account. -/
theorem account_step_needs_owner (owner : Nat) (old new : State) (verb : Int)
    (admitted : eval (accountLaw owner) old new = true)
    (step : new.get verbSlot = some verb) (acting : verb ≠ observeTag) :
    new.get subjectSlot = some (Int.ofNat owner) := by
  rcases (accountLaw_eval owner old new).mp admitted with observe | own
  · rw [step] at observe
    exact absurd (Option.some.inj observe) acting
  · exact own

/-- **Under the default room law, a step that neither observes nor appends is the
founder's.** A member cannot mutate the room cell's state, re-delegate it, place into
it or reserve it. -/
theorem room_governance_needs_founder (founder : Nat) (old new : State) (verb : Int)
    (admitted : eval (roomLaw founder) old new = true)
    (step : new.get verbSlot = some verb)
    (governing : verb ≠ observeTag ∧ verb ≠ appendTag) :
    new.get subjectSlot = some (Int.ofNat founder) := by
  rcases (roomLaw_eval founder old new verb step).mp admitted with free | own
  · rcases free with observe | append
    · exact absurd observe governing.1
    · exact absurd append governing.2
  · exact own

/-! ## Poles: satisfiable, and teeth against permit-all -/

/-- Subject 7 transfers (verb 2) on a cell owned by 5. -/
def strangerTransfer : State := ⟨[(verbSlot, 2), (subjectSlot, 7), ("request/target", 500)]⟩
/-- Subject 5 transfers on its own cell. -/
def ownerTransfer : State := ⟨[(verbSlot, 2), (subjectSlot, 5), ("request/target", 500)]⟩
/-- Subject 7 observes 5's cell. -/
def strangerObserve : State := ⟨[(verbSlot, 1), (subjectSlot, 7), ("request/target", 500)]⟩
/-- Subject 7 appends to a room founded by 5. -/
def memberAppend : State := ⟨[(verbSlot, 7), (subjectSlot, 7), ("request/target", 900)]⟩
/-- Subject 7 mutates (verb 2) the state of a room founded by 5. -/
def memberMutate : State := ⟨[(verbSlot, 2), (subjectSlot, 7), ("request/target", 900)]⟩

/-- Teeth: permit-all admits the stranger's transfer; the default refuses it. -/
theorem permitAll_admits_stranger_transfer : eval permitAll ⟨[]⟩ strangerTransfer = true := by decide
theorem accountLaw_refuses_stranger_transfer : eval (accountLaw 5) ⟨[]⟩ strangerTransfer = false := by
  decide
/-- Satisfiable: the owner's transfer and the stranger's observation are admitted. -/
theorem accountLaw_admits_owner_transfer : eval (accountLaw 5) ⟨[]⟩ ownerTransfer = true := by decide
theorem accountLaw_admits_stranger_observe : eval (accountLaw 5) ⟨[]⟩ strangerObserve = true := by
  decide
/-- The room: a member may append, may not mutate; permit-all lets the member mutate. -/
theorem roomLaw_admits_member_append : eval (roomLaw 5) ⟨[]⟩ memberAppend = true := by decide
theorem roomLaw_refuses_member_mutate : eval (roomLaw 5) ⟨[]⟩ memberMutate = false := by decide
theorem permitAll_admits_member_mutate : eval permitAll ⟨[]⟩ memberMutate = true := by decide

#assert_axioms observeTag_is_observeAccount
#assert_axioms appendTag_is_appendObject
#assert_axioms transfer_is_not_observe
#assert_axioms mutateObject_is_governing
#assert_axioms delegateObject_is_governing
#assert_axioms request_subject_exact
#assert_axioms request_verb_exact
#assert_axioms accountLaw_eval
#assert_axioms roomLaw_eval
#assert_axioms account_step_needs_owner
#assert_axioms room_governance_needs_founder
#assert_axioms permitAll_admits_stranger_transfer
#assert_axioms accountLaw_refuses_stranger_transfer
#assert_axioms accountLaw_admits_owner_transfer
#assert_axioms roomLaw_admits_member_append
#assert_axioms roomLaw_refuses_member_mutate
#assert_axioms permitAll_admits_member_mutate

end Minidregg.Kernel.DefaultLaw
