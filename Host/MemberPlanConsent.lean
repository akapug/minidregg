/-
# Host.MemberPlanConsent -- consent re-derives the two member-signed plans outside the families

A member's hosted key signs what the Host prints. The local consent provider exists so
that it signs only what it re-derived itself from the member's own retained request
(`Kernel.NativeSpecializedConsent` for the plan families it holds, `NativeLifecycleConsent`
for the lifecycle families). Two public, member-signed plans were outside both until
lane/lean-critical, so a Host that printed a different plan was signed unchecked:

* op 187 `NEXT_KEY_ADOPTION_PLAN`: the plan a member signs with its current key and its next
  key to adopt a next-key commitment (`KeyCommitmentAdoptionInspection.planLoaded`). Unchecked,
  a Host could print an attacker's key as the member's next key and the member would sign it.
* op 194 `APPLICATION_DISPATCH_AUTHENTICATED_PLAN`: the member-authenticated app dispatch plan
  every grain request takes (`ApplicationDispatchReady.authenticatedPlanVerified`). Unchecked,
  a Host could print a dispatch against another cell or with other effects.

Both are re-derived here from the retained request bytes the client sent the Host, on the
provider's own full re-admission (`ClientConsentCore.FullSession`), and compared byte for byte
(`NativeSpecializedConsent.checkExact`); `ClientConsentSession` routes them through this
module because `specializedNeedsFull` sends every operation the kernel-level list does not
hold to the full-session adapter. The registry lists both in `consent_plans`, so the client's
generated `CONSENT_PLANS` routes their replies through frame 224 before any signing consumer
sees them.

Op 193 `APPLICATION_DISPATCH_READY` is NOT a plan: `assembledReadyVerified` takes an already
signed plan and its signatures and returns a `Json` record (`Host/ApplicationDispatchReady.lean`,
`IO Json`); nothing is signed after it. The registry records it exempt with that type.
-/
import Host.KeyCommitmentAdoptionInspection
import Host.ApplicationDispatchReady
import Kernel.NativeSpecializedConsent
import Theory.AssertAxioms

namespace Minidregg.Host.MemberPlanConsent

open Minidregg.Compiler Minidregg.Compiler.NativeHostCodec
open Minidregg.Kernel Minidregg.Host

set_option autoImplicit false

/-- The member-signed plan operations this adapter re-derives. -/
def supported (operation : UInt8) : Bool := [187, 194].contains operation

private def splitPair (payload : List UInt8) : IO (List UInt8 × List UInt8) := do
  unless payload.length ≥ 4 do throw (IO.userError "truncated member plan request pair")
  let length := (payload.take 4).foldr (fun b rest => b.toNat + 256 * rest) 0
  unless length ≤ payload.length - 4 do throw (IO.userError "member plan request pair exceeds payload")
  pure ((payload.drop 4).take length, payload.drop (4 + length))

/-- The exact production functions Host.Main runs for ops 187 and 194, on the provider's own
re-admission, over the exact request bytes the client retained. No signature is created here. -/
def expectedPlanBytes (config : NativeHost.Config) {target : NativeHost.Durable}
    (verified : NativeHostReplay.Verified config target) (operation : UInt8)
    (request : List UInt8) : IO (List UInt8) := do
  unless request.length ≤ FnEvidenceCodec.maxHostFrameBytes do
    throw (IO.userError "local member plan request exceeds native frame bound")
  match operation with
  | 187 => IO.ofExcept (KeyCommitmentAdoptionInspection.planLoaded config verified.opened request)
  | 194 =>
      let (dispatchRequest, authenticated) ← splitPair request
      let (signature, observations) ← splitPair authenticated
      let (appRead, rest) ← splitPair observations
      let (packageRead, rest) ← splitPair rest
      let (sessionRead, rest) ← splitPair rest
      let (enrollmentRead, ticketRead) ← splitPair rest
      match ← ApplicationDispatchReady.authenticatedPlanVerified verified dispatchRequest signature
          [appRead, packageRead, sessionRead, enrollmentRead, ticketRead] with
      | .ok plan => pure (ApplicationDispatchAuthoring.planCodec.encode plan)
      | .error _ => throw (IO.userError "local member dispatch plan preparation refused")
  | _ => throw (IO.userError "member plan consent operation is unsupported")

/-- Op 187: a candidate adoption plan that is not the locally re-derived one is refused,
whatever it claims (another next key, another subject, another deadline). -/
theorem adoption_changed_refused (config : NativeHost.Config)
    {target : NativeHost.Durable} (verified : NativeHostReplay.Verified config target)
    (request expected candidate : List UInt8)
    (derived : KeyCommitmentAdoptionInspection.planLoaded config verified.opened request = .ok expected)
    (changed : expected ≠ candidate) :
    NativeSpecializedConsent.checkExact expected candidate =
      .error "operator plan differs from complete local native preparation" :=
  NativeSpecializedConsent.changed_plan_refused expected candidate changed

/-- Op 194: a candidate dispatch plan whose bytes are not the encoding of the locally
re-derived plan is refused: a different target cell, effect, amount or header. -/
theorem member_dispatch_changed_refused (plan : ApplicationDispatchAuthoring.Plan)
    (candidate : List UInt8)
    (changed : ApplicationDispatchAuthoring.planCodec.encode plan ≠ candidate) :
    NativeSpecializedConsent.checkExact (ApplicationDispatchAuthoring.planCodec.encode plan) candidate =
      .error "operator plan differs from complete local native preparation" :=
  NativeSpecializedConsent.changed_plan_refused _ candidate changed

/-- The exact re-derivation is accepted (satisfiable pole). -/
theorem rederived_plan_accepted (expected : List UInt8) :
    ∃ exact, NativeSpecializedConsent.checkExact expected expected = .ok exact := by
  unfold NativeSpecializedConsent.checkExact
  rw [dif_pos rfl]
  exact ⟨_, rfl⟩

#assert_axioms adoption_changed_refused
#assert_axioms member_dispatch_changed_refused
#assert_axioms rederived_plan_accepted

end Minidregg.Host.MemberPlanConsent
