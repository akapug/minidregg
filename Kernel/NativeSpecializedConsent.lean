/- Same-source consent for operator-proposed specialized native plans.
A caller retains its request locally and admits a warm source prefix independently.
This module uses the actual loaded native planners and their canonical whole-plan
codecs. It has no operator Bool, sparse state defaults, or planner semantic twin.
-/
import Kernel.NativeClientConsent
import Kernel.NativeHostPayClaims
import Kernel.NativeHostHeld

namespace Minidregg.Kernel.NativeSpecializedConsent
open Minidregg.Compiler Minidregg.Kernel
open Minidregg.Compiler.Tower256ConcreteBackend
set_option autoImplicit false

/-- A byte-level gate is useful only after the same native planner produced the
expected whole plan from the retained request and independently verified source. -/
structure ExactPlan (expected candidate : List UInt8) : Type where
  private mk ::
  exact : expected = candidate

def checkExact (expected candidate : List UInt8) : Except String (ExactPlan expected candidate) :=
  if h : expected = candidate then .ok ⟨h⟩
  else .error "operator plan differs from complete local native preparation"

theorem changed_plan_refused (expected candidate : List UInt8) (changed : expected ≠ candidate) :
    checkExact expected candidate = .error "operator plan differs from complete local native preparation" := by
  simp [checkExact, changed]

/-- Consent to the re-derived plan, or to its height pin when the operation has one
(today op 86, `pinnedExpectedBytes`): nothing else. -/
structure ExactOrPinned (expected : List UInt8) (pinned : Option (List UInt8))
    (candidate : List UInt8) : Type where
  private mk ::
  exact : expected = candidate ∨ pinned = some candidate

def checkExactOrPinned (expected : List UInt8) (pinned : Option (List UInt8))
    (candidate : List UInt8) : Except String (ExactOrPinned expected pinned candidate) :=
  if h : expected = candidate then .ok ⟨.inl h⟩
  else if p : pinned = some candidate then .ok ⟨.inr p⟩
  else .error "operator plan differs from complete local native preparation"

/-- Teeth: a candidate that is neither the re-derived plan nor its pin is refused. -/
theorem changed_or_pinned_refused (expected : List UInt8) (pinned : Option (List UInt8))
    (candidate : List UInt8) (changed : expected ≠ candidate) (notPinned : pinned ≠ some candidate) :
    checkExactOrPinned expected pinned candidate =
      .error "operator plan differs from complete local native preparation" := by
  simp [checkExactOrPinned, changed, notPinned]

/-- Satisfiable: the re-derived plan is accepted. -/
theorem rederived_plan_accepted (expected : List UInt8) (pinned : Option (List UInt8)) :
    ∃ consent, checkExactOrPinned expected pinned expected = .ok consent := by
  unfold checkExactOrPinned
  rw [dif_pos rfl]
  exact ⟨_, rfl⟩

/-- Satisfiable, across ticks: the provider re-derives the enrollment plan at a LATER height
than the one the signer saw; pinned at the observed height it is the plan authored there,
so the client's candidate (authored at the observed height) is accepted. -/
theorem pinned_plan_accepted (seen later : Nat) (le : seen ≤ later)
    (plan : ParticipantKeyEnrollment.SigningPlan)
    (header : CredentialSignedEnvelopeController.SignedHeader)
    (decoded : CredentialSignedEnvelopeController.headerCodec.decode plan.sponsorHeader = some header)
    (derived : header.validUntil = NativePlanHeight.authoredDeadline later) :
    ∃ consent, checkExactOrPinned (ParticipantKeyEnrollment.signingPlanCodec.encode plan)
      ((NativePlanHeight.pinEnrollment seen plan).toOption.map
        ParticipantKeyEnrollment.signingPlanCodec.encode)
      (ParticipantKeyEnrollment.signingPlanCodec.encode { plan with sponsorHeader :=
        (CredentialSignedEnvelopeController.headerCodec.encode
          { header with validUntil := NativePlanHeight.authoredDeadline seen }) }) = .ok consent := by
  rw [NativePlanHeight.pinEnrollment_rederived_later seen later le plan header decoded derived]
  simp only [Except.toOption, Option.map]
  unfold checkExactOrPinned
  split
  · exact ⟨_, rfl⟩
  · rw [dif_pos rfl]
    exact ⟨_, rfl⟩

private def splitPair? (payload : List UInt8) : Option (List UInt8 × List UInt8) :=
  if payload.length < 4 then none else
  let length := (payload.take 4).foldr (fun b rest => b.toNat + 256 * rest) 0
  if length ≤ payload.length - 4 then some ((payload.drop 4).take length, payload.drop (4 + length))
  else none

/-- The height-pinned form of the re-derived plan, for the operations whose plan a signer
pins before signing. Op 86 (enrollment): the sponsor header's deadline pinned
(`NativePlanHeight.pinHeaderAt`: the deadline a plan authored there carries) to the height
of the authorizing observation in the retained request (`Challenge.height`), the height the
signer saw and the client passes to `pin-enrollment-plan-height`; a pin to any other height
differs and is refused. Every other operation: none (op 1's invocation pin is accepted by
`NativeClientConsent.checkPlan`). -/
def pinnedExpectedBytes (operation : UInt8) (request expected : List UInt8) : Option (List UInt8) :=
  match operation with
  | 86 => do
      let (observation, _) ← splitPair? request
      let signed ← NativeObservationCodec.signedCodec.decode observation
      let plan ← ParticipantKeyEnrollment.signingPlanCodec.decode expected
      let pinned ← (NativePlanHeight.pinEnrollment signed.challenge.height plan).toOption
      pure (ParticipantKeyEnrollment.signingPlanCodec.encode pinned)
  | _ => none

/-- Only the enrollment plan has a pinned form here. -/
theorem pinnedExpectedBytes_only_enrollment (operation : UInt8) (request expected : List UInt8)
    (other : operation ≠ 86) : pinnedExpectedBytes operation request expected = none := by
  unfold pinnedExpectedBytes
  split
  · exact absurd rfl other
  · rfl

#assert_axioms changed_or_pinned_refused
#assert_axioms rederived_plan_accepted
#assert_axioms pinned_plan_accepted
#assert_axioms pinnedExpectedBytes_only_enrollment

def supported (operation : UInt8) : Bool :=
  [86, 92, 96, 103, 108, 113, 117, 123, 126, 140, 160, 170, 183, 210, 215].contains operation

private def splitPair (payload : List UInt8) : IO (List UInt8 × List UInt8) := do
  unless payload.length ≥ 4 do throw (IO.userError "truncated specialized request pair")
  let length := (payload.take 4).foldr (fun b rest => b.toNat + 256 * rest) 0
  unless length ≤ payload.length - 4 do throw (IO.userError "specialized request pair exceeds payload")
  pure ((payload.drop 4).take length, payload.drop (4 + length))

private def admitted {α ε : Type} (result : Except ε α) : IO α :=
  match result with
  | .ok value => pure value
  | .error _ => throw (IO.userError "local authenticated specialized preparation refused")

/-- The consent provider's op-86 re-derivation. An observation at the provider's current
height is authorized in full (`enrollmentPlanAuthorizedLoaded`). One at an EARLIER height
`seen`, with the provider's height still within the plan's deadline
(`NativePlanHeight.authoredDeadline seen`), is re-derived from the command at the
provider's image, whose store extends the store the signer saw (the consent anchor's
exact-prefix guarantee); `pinnedExpectedBytes` then pins it at `seen`, so a tick between
plan and seal no longer refuses consent. The observation's byte checks are kept. A height
above the provider's, or past the deadline, refuses. Safety does not rest on the
observation's height: the pin only ever lowers the provider's own deadline
(`pinHeaderAt_never_extends`). -/
def enrollmentPlanAtObservation (config : NativeHost.Config) (opened : NativeHost.Opened config)
    (observation commandBytes : List UInt8) : IO ParticipantKeyEnrollment.SigningPlan := do
  let some command := ParticipantKeyEnrollment.commandCodec.decode commandBytes
    | throw (IO.userError "noncanonical participant enrollment command")
  let some signed := NativeObservationCodec.signedCodec.decode observation
    | throw (IO.userError "noncanonical enrollment observation")
  if signed.challenge.intent.subject != command.sponsor then
    throw (IO.userError "enrollment observation subject differs from the sponsor")
  match signed.challenge.intent.purpose with
  | .query query =>
      if query.kind != .object || query.target != config.deployment.factoryId ||
          query.view != .resource then
        throw (IO.userError "enrollment observation is not the factory resource query")
  | .prepare _ => throw (IO.userError "enrollment observation is not a query")
  let now := NativeHost.logicalHeight config opened.durable
  let seen := signed.challenge.height
  if seen = now then
    admitted (← NativeHost.enrollmentPlanAuthorizedLoaded config opened observation commandBytes)
  else if seen < now ∧ now ≤ NativePlanHeight.authoredDeadline seen then
    IO.ofExcept (NativeHost.enrollmentPlanLoaded config opened commandBytes)
  else
    throw (IO.userError "enrollment observation height is not an admitted height within the plan deadline")

/-- The exact production functions and production encoders used by Host.Main.
No source mutation or signature creation occurs here. -/
def expectedPlanBytes (config : NativeHost.Config) {target : NativeHost.Durable}
    (basis : ConsentAnchor.Basis config target) (operation : UInt8)
    (request : List UInt8) : IO (List UInt8) := do
  let opened := basis.opened
  match operation with
  | 86 =>
      let (observation, command) ← splitPair request
      let plan ← enrollmentPlanAtObservation config opened observation command
      pure (ParticipantKeyEnrollment.signingPlanCodec.encode plan)
  | 92 =>
      let (observation, command) ← splitPair request
      let plan ← admitted (← NativeHost.provisionPlanAuthorizedLoaded config opened observation command)
      pure (ParticipantFactoryProvisioning.signingPlanCodec.encode plan)
  | 96 =>
      let (observation, draft) ← splitPair request
      let plan ← admitted (← NativeHost.fleetPlanAuthorizedLoaded config opened observation draft)
      pure (FleetTurn.signingPlanCodec.encode plan)
  | 103 =>
      pure (PayCellDomain.signingPlanCodec.encode (← IO.ofExcept (NativeHost.payPlanLoaded config opened request)))
  | 108 =>
      pure (PayCellDomain.signingPlanCodec.encode (← IO.ofExcept (NativeHost.payObservationPlanLoaded config opened request)))
  | 113 =>
      pure (PayCellDomain.signingPlanCodec.encode (← IO.ofExcept (NativeHost.payRefillPlanLoaded config opened request)))
  | 117 =>
      pure (PayCellDomain.signingPlanCodec.encode (← IO.ofExcept (← NativeHost.payEnrolPlanCurrentLoaded config opened request)))
  | 123 =>
      pure (RealmWellCodec.signingPlanCodec.encode (← IO.ofExcept (NativeHost.wellPlanLoaded config opened request)))
  | 126 =>
      pure (ClockTickReceiver.signingPlanCodec.encode (← IO.ofExcept (NativeHost.clockPlanLoaded config opened request)))
  | 140 =>
      pure (SubjectKeyRotation.signingPlanCodec.encode (← IO.ofExcept (NativeHost.rotationPlanLoaded config opened request)))
  | 160 =>
      pure (PayCellDomain.signingPlanCodec.encode (← IO.ofExcept (NativeHost.jobMoneyPlanLoaded config opened request)))
  | 170 =>
      pure (CertifyReceiver.signingPlanCodec.encode (← IO.ofExcept (NativeHost.certifyPlanLoaded config opened request)))
  | 183 =>
      pure (NativeHost.claimSigningPlanCodec.encode (← IO.ofExcept (NativeHost.payClaimPlanLoaded config opened request)))
  | 210 =>
      pure (ObjectiveActivityReceiver.signingPlanCodec.encode
        (← IO.ofExcept (NativeHost.activityPlanLoaded config opened
          (← NativeHostHeld.heldFor config opened) request)))
  | 215 =>
      pure (SeatReceiver.signingPlanCodec.encode
        (← IO.ofExcept (NativeHost.seatPlanLoaded config opened request)))
  | _ => throw (IO.userError "specialized consent operation is unsupported")

end Minidregg.Kernel.NativeSpecializedConsent
