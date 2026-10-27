/-
Local consent for a client which independently holds a verified source prefix.
The remote endpoint proposes bytes; it never chooses what custody signs. Every
header is reconstructed by the SAME observation/planning implementation used by
the native Host, under the caller's pinned configuration and retained intent.

This is the full-peer producer. It is not a permission to copy protected source
state to a client, and not a new admission bypass. The thin producer
(`Kernel.NativeThinConsent`) does not re-derive the plan: it checks what is
signed against the member's own command and the served target views, and
proves that what it shows is what commits. Signature validity remains the native verifier's
existing assumption. Keeping a verified prefix warm is a caller responsibility;
this module does not replay history for each signature. The prefix is a
`ConsentAnchor.Basis`: the full re-admission from genesis, or native admission
of every record after the client's own retained anchor.
-/
import Kernel.NativeHost
import Kernel.ConsentAnchor
import Kernel.NativePlanHeight

namespace Minidregg.Kernel.NativeClientConsent

open Minidregg.Compiler
open Minidregg.Compiler.NativeHostCodec
open Minidregg.Compiler.NativeObservationCodec
open Minidregg.Kernel.NativeHost

set_option autoImplicit false

/-- Only this module constructs consent. `wanted` and `intentSignature` are
locally retained inputs, not values parsed from the proposed challenge. -/
structure ObservationConsent (config : Config) {target : Durable}
    (basis : ConsentAnchor.Basis config target) (wanted : Intent)
    (intentSignature candidate : List UInt8) where
  private mk ::
  challenge : Challenge
  derived : NativeObservationController.challenge
    (observationContext config basis.opened) config.profile config.federation
    config.genesisHeight wanted intentSignature = .ok challenge
  exactBytes : challengeCodec.encode challenge = candidate

/-- Why a proposed observation challenge received no consent. Every refusal
releases nothing; the reason only tells custody what to do next. -/
inductive ObservationRefusal where
  /-- The local observation planner refused the retained intent on the admitted source. -/
  | localPreparation
  /-- The proposal answers this exact retained intent and intent signature,
  under the same domain, semantics and federation, at another source height than
  the one custody admitted: the source moved between the Host's challenge and
  this check. Custody observes again on the new source and consents afresh. -/
  | staleObservation (remoteHeight localHeight : Nat)
  /-- Anything else: the proposal is not this custody's intent on its source. -/
  | differs
  deriving DecidableEq, Repr

/-- The prefix every stale-observation refusal carries on the consent wire; the
Rust client re-observes on it and on nothing else from this check. -/
def staleObservationTag : String := "stale observation:"

def ObservationRefusal.message : ObservationRefusal → String
  | .localPreparation => "local observation preparation refused"
  | .staleObservation remote here =>
      s!"{staleObservationTag} the remote challenge answers this intent at source height {remote}; " ++
        s!"the locally admitted source is at height {here}"
  | .differs => "remote challenge differs from locally prepared intent"

/-- The reason for a candidate that is not the local derivation's bytes. Stale
only when the decoded proposal carries the retained intent and signature, the
local domain, semantics and federation, and a different height; a proposal at
the SAME height that differs anywhere is the operator proposing other bytes. -/
def classifyMismatch (here : Challenge) (wanted : Intent)
    (intentSignature candidate : List UInt8) : ObservationRefusal :=
  match challengeCodec.decode candidate with
  | some remote =>
      if remote.intent = wanted ∧ remote.intentSignature = intentSignature ∧
          remote.domain = here.domain ∧ remote.semantics = here.semantics ∧
          remote.federation = here.federation ∧ remote.height ≠ here.height then
        .staleObservation remote.height here.height
      else .differs
  | none => .differs

/-- The entire challenge is compared: intent, ordered headers, signature,
profile, world/authority coordinates and clock. A remotely rendered JSON view
is neither read nor trusted. No header escapes on mismatch. A mismatch is only
classified (`classifyMismatch`); acceptance is exactly byte equality. -/
def checkObservation (config : Config) {target : Durable}
    (basis : ConsentAnchor.Basis config target) (wanted : Intent)
    (intentSignature candidate : List UInt8) :
    Except ObservationRefusal (ObservationConsent config basis wanted intentSignature candidate) :=
  match derived : NativeObservationController.challenge
      (observationContext config basis.opened) config.profile config.federation
      config.genesisHeight wanted intentSignature with
  | .error _ => .error .localPreparation
  | .ok challenge =>
      if exactBytes : challengeCodec.encode challenge = candidate then
        .ok ⟨challenge, derived, exactBytes⟩
      else .error (classifyMismatch challenge wanted intentSignature candidate)

/-- A stale label is given only to a proposal that decodes to THIS retained
intent and intent signature at another height. An intent changed anywhere
between custody's preparation and the Host's challenge is never stale. -/
theorem classify_stale {here : Challenge} {wanted : Intent}
    {intentSignature candidate : List UInt8} {remoteHeight localHeight : Nat}
    (stale : classifyMismatch here wanted intentSignature candidate =
      .staleObservation remoteHeight localHeight) :
    ∃ remote, challengeCodec.decode candidate = some remote ∧ remote.intent = wanted ∧
      remote.intentSignature = intentSignature ∧ remote.height = remoteHeight ∧
      localHeight = here.height ∧ remoteHeight ≠ localHeight := by
  unfold classifyMismatch at stale
  split at stale
  next remote decoded =>
    split at stale
    next same =>
      injection stale with remoteExact localExact
      subst remoteExact
      subst localExact
      exact ⟨remote, decoded, same.1, same.2.1, rfl, rfl, same.2.2.2.2.2⟩
    next => cases stale
  next => cases stale

theorem stale_observation_is_this_intent {config : Config} {target : Durable}
    {basis : ConsentAnchor.Basis config target} {wanted : Intent}
    {intentSignature candidate : List UInt8} {remoteHeight localHeight : Nat}
    (refused : checkObservation config basis wanted intentSignature candidate =
      .error (.staleObservation remoteHeight localHeight)) :
    ∃ remote, challengeCodec.decode candidate = some remote ∧ remote.intent = wanted ∧
      remote.intentSignature = intentSignature ∧ remote.height = remoteHeight ∧
      remoteHeight ≠ localHeight := by
  unfold checkObservation at refused
  split at refused
  next => cases refused
  next =>
    split at refused
    next => cases refused
    next =>
      obtain ⟨remote, decoded, intentExact, signatureExact, heightExact, _, apart⟩ :=
        classify_stale (Except.error.inj refused)
      exact ⟨remote, decoded, intentExact, signatureExact, heightExact, apart⟩

/-- A proposal whose decoded intent is not the retained one is refused as
`differs` (when it is not the local bytes at all), never as stale. -/
theorem changed_intent_not_stale {config : Config} {target : Durable}
    {basis : ConsentAnchor.Basis config target} {wanted : Intent}
    {intentSignature candidate : List UInt8} {remote : Challenge}
    (decoded : challengeCodec.decode candidate = some remote)
    (changed : remote.intent ≠ wanted) (remoteHeight localHeight : Nat) :
    checkObservation config basis wanted intentSignature candidate ≠
      .error (.staleObservation remoteHeight localHeight) := by
  intro refused
  obtain ⟨other, decodedOther, intentExact, _⟩ := stale_observation_is_this_intent refused
  rw [decoded] at decodedOther
  cases decodedOther
  exact changed intentExact

def ObservationConsent.headers {config : Config} {target : Durable}
    {basis : ConsentAnchor.Basis config target} {wanted : Intent}
    {intentSignature candidate : List UInt8}
    (consent : ObservationConsent config basis wanted intentSignature candidate) :
    List (List UInt8) := consent.challenge.headers

/-- The original draft remains an index of the capability. Birth finalization
is performed by the real planner, not a client rule permitting arbitrary changes
under a 'birth' tag. Every ordered role, index and header is compared as bytes. -/
structure PlanConsent (config : Config) {target : Durable}
    (basis : ConsentAnchor.Basis config target) (draft : Draft)
    (candidate : List UInt8) where
  private mk ::
  plan : SigningPlan
  derived : prepareLoaded config basis.opened draft = .ok plan
  /-- The plan whose canonical bytes the remote offered and the signer signs: the
  local plan itself, or the local plan with every slot deadline pinned to its height
  (`NativePlanHeight.pin`, the Host's `pin-plan-height`), which `provider_continuity`
  applies before signing a provider settle. The pin changes nothing else
  (`NativePlanHeight.pin_only_slots`) and never extends a deadline
  (`NativePlanHeight.pinHeader_never_extends`), so consenting to it consents to less. -/
  accepted : SigningPlan
  pinned : accepted = plan ∨ NativePlanHeight.pin plan = .ok accepted
  exactBytes : signingPlanCodec.encode accepted = candidate

/-- Consent to a signing plan: the candidate bytes are the LOCAL preparation's, exactly,
or the local preparation's with its slot deadlines pinned to the height the signer
saw. Anything else, in any field, is refused (`changed_plan_refused`). Until
lane/lean-critical only the first form was accepted, so every height-pinned provider
settle was refused as "remote signing plan differs" and no Hermes provider call could
settle (HERMES-LIVE). -/
def checkPlan (config : Config) {target : Durable}
    (basis : ConsentAnchor.Basis config target) (draft : Draft)
    (candidate : List UInt8) : Except String (PlanConsent config basis draft candidate) :=
  match derived : prepareLoaded config basis.opened draft with
  | .error _ => .error "local transaction preparation refused"
  | .ok plan =>
      if exactBytes : signingPlanCodec.encode plan = candidate then
        .ok ⟨plan, derived, plan, .inl rfl, exactBytes⟩
      else
        match pinnedPlan : NativePlanHeight.pin plan with
        | .ok pinned =>
            if pinnedBytes : signingPlanCodec.encode pinned = candidate then
              .ok ⟨plan, derived, pinned, .inr pinnedPlan, pinnedBytes⟩
            else .error "remote signing plan differs from locally prepared intent"
        | .error _ => .error "remote signing plan differs from locally prepared intent"

/-- The headers the signer signs: the accepted plan's (pinned when the remote pinned). -/
def PlanConsent.headers {config : Config} {target : Durable}
    {basis : ConsentAnchor.Basis config target} {draft : Draft}
    {candidate : List UInt8}
    (consent : PlanConsent config basis draft candidate) : List (List UInt8) :=
  consent.accepted.slots.map SigningSlot.header

/-- Connect preparation to the locally retained observation intent. Query-only
intents have no transaction consent path. This checks consent, not admission:
the ordinary native receiver must still authenticate and authorize submission. -/
def checkIntentPlan (config : Config) {target : Durable}
    (basis : ConsentAnchor.Basis config target) (wanted : Intent)
    (candidate : List UInt8) : Except String (List (List UInt8)) :=
  match wanted.purpose with
  | .query _ => .error "query intent cannot authorize transaction signing"
  | .prepare draft => (checkPlan config basis draft candidate).map PlanConsent.headers

/-- An accepting observation has an actual native derivation from the LOCAL
intent and prefix, and its complete canonical bytes equal the proposal. This
states the exact consent boundary; it does not claim cryptographic security. -/
theorem observation_origin {config : Config} {target : Durable}
    {basis : ConsentAnchor.Basis config target} {wanted : Intent}
    {intentSignature candidate : List UInt8}
    (consent : ObservationConsent config basis wanted intentSignature candidate) :
    ∃ challenge, NativeObservationController.challenge
      (observationContext config basis.opened) config.profile config.federation
      config.genesisHeight wanted intentSignature = .ok challenge ∧
      challengeCodec.encode challenge = candidate ∧
      consent.headers = challenge.headers :=
  ⟨consent.challenge, consent.derived, consent.exactBytes, rfl⟩

/-- In particular this covers all planner branches, not just invocation or a
fixed fixture. It inherits the planner's meaning, including its unresolved
semantic/proof boundaries, rather than asserting that meaning is correct. -/
theorem plan_origin {config : Config} {target : Durable}
    {basis : ConsentAnchor.Basis config target} {draft : Draft}
    {candidate : List UInt8}
    (consent : PlanConsent config basis draft candidate) :
    ∃ plan accepted, prepareLoaded config basis.opened draft = .ok plan ∧
      (accepted = plan ∨ NativePlanHeight.pin plan = .ok accepted) ∧
      signingPlanCodec.encode accepted = candidate ∧
      consent.headers = accepted.slots.map SigningSlot.header :=
  ⟨consent.plan, consent.accepted, consent.derived, consent.pinned, consent.exactBytes, rfl⟩

/-- Satisfiable: the height-pinned local plan is accepted, and what the signer signs is
the pinned plan's headers. -/
theorem pinned_plan_accepted {config : Config} {target : Durable}
    (basis : ConsentAnchor.Basis config target) (draft : Draft) (plan pinned : SigningPlan)
    (derived : prepareLoaded config basis.opened draft = .ok plan)
    (pinnedPlan : NativePlanHeight.pin plan = .ok pinned) :
    ∃ consent, checkPlan config basis draft (signingPlanCodec.encode pinned) = .ok consent ∧
      consent.accepted = pinned := by
  unfold checkPlan
  split
  next error actual => simp [derived] at actual
  next expected actual =>
    have same : plan = expected := Except.ok.inj (derived.symm.trans actual)
    subst expected
    by_cases exact : signingPlanCodec.encode plan = signingPlanCodec.encode pinned
    · rw [dif_pos exact]
      refine ⟨_, rfl, ?_⟩
      have decoded := congrArg signingPlanCodec.decode exact
      rw [signingPlanCodec.decode_encode, signingPlanCodec.decode_encode] at decoded
      exact Option.some.inj decoded
    · rw [dif_neg exact]
      split
      next other otherPlan =>
        have same : other = pinned := Except.ok.inj (otherPlan.symm.trans pinnedPlan)
        subst other
        rw [dif_pos rfl]
        exact ⟨_, rfl, rfl⟩
      next otherPlan =>
        rw [pinnedPlan] at otherPlan
        cases otherPlan

/-- No modified frame can receive consent against the same local prefix/draft, even when
its separate server-authored presentation claims identical metadata. Teeth: a candidate
that is neither the local plan nor its height pin is refused, whatever else it claims: a
different effect, amount, subject, key or any header byte other than the deadline. -/
theorem changed_plan_refused {config : Config} {target : Durable}
    (basis : ConsentAnchor.Basis config target) (draft : Draft)
    (plan : SigningPlan) (candidate : List UInt8)
    (derived : prepareLoaded config basis.opened draft = .ok plan)
    (different : signingPlanCodec.encode plan ≠ candidate)
    (differentPinned : ∀ pinned, NativePlanHeight.pin plan = .ok pinned →
      signingPlanCodec.encode pinned ≠ candidate) :
    checkPlan config basis draft candidate =
      .error "remote signing plan differs from locally prepared intent" := by
  unfold checkPlan
  split
  next error actual => simp [derived] at actual
  next expected actual =>
    have same : plan = expected := Except.ok.inj (derived.symm.trans actual)
    subst expected
    rw [dif_neg different]
    split
    next pinned pinnedPlan => rw [dif_neg (differentPinned pinned pinnedPlan)]
    next => rfl

/-- What consent accepts is the local plan or its pin and nothing else: the accepted
plan's non-slot fields are the local plan's, and each accepted slot is the local slot
with at most its header's deadline pinned. -/
theorem accepted_is_plan_or_pin {config : Config} {target : Durable}
    {basis : ConsentAnchor.Basis config target} {draft : Draft} {candidate : List UInt8}
    (consent : PlanConsent config basis draft candidate) :
    consent.accepted = consent.plan ∨
      (consent.accepted = { consent.plan with slots := consent.accepted.slots } ∧
        consent.accepted.slots.length = consent.plan.slots.length ∧
        ∀ i (hi : i < consent.plan.slots.length) (hi' : i < consent.accepted.slots.length),
          NativePlanHeight.pinSlot consent.plan.height consent.plan.slots[i] =
            .ok consent.accepted.slots[i]) := by
  rcases consent.pinned with same | pinned
  · exact .inl same
  · exact .inr (NativePlanHeight.pin_only_slots _ _ pinned)

#assert_axioms plan_origin
#assert_axioms pinned_plan_accepted
#assert_axioms changed_plan_refused
#assert_axioms accepted_is_plan_or_pin

#assert_axioms classify_stale
#assert_axioms stale_observation_is_this_intent
#assert_axioms changed_intent_not_stale

end Minidregg.Kernel.NativeClientConsent
