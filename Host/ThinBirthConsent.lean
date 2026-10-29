/-
# Host.ThinBirthConsent — the deployed authoring, at a draft's coordinates

`Kernel.NativeThinBirth.checkBirthThin` takes the authoring function as a parameter, since the
Kernel cannot import the JSON authoring. This module instantiates it exactly once: the deployed
ordinary-birth authoring of the member's own `source.json` (`SourceAgreementJson.birthIntentFrom`
over `SourceAgreementJson.birthAt`, the same `birth` the Host's op 91 runs through
`birthCurrent`), with the Store-read inputs replaced by the coordinates the proposed draft
carries. Thin consent frames 234 and 235 (`Host.ClientConsentCore.thin`) call only these.

Completeness (an intent the Store-reading authoring produced re-authors to itself at its own
coordinates) runs through the JSON parser and is not a theorem here. It is witnessed by the
journey's successful thin birth (`native/resource-client/journey.d/jpriv2.sh`, row 19).
-/
module

public import Kernel.NativeThinBirth
public import Host.SourceAgreementJson

@[expose] public section

namespace Minidregg.Host.ThinBirthConsent

open Minidregg.Compiler
open Minidregg.Theory
open Minidregg.Theory.TypedAuthorization
open Minidregg.Kernel
open Minidregg.Kernel.NativeThinBirth

set_option autoImplicit false

/-- The two epoch projections at a draft's coordinates: the one issuer epoch, and each policy's
epoch as the draft's grants name it (a policy no grant names reads 0, as a fresh one does). -/
def epochsOf (coordinates : BirthCoordinates) : SourceAgreementJson.BirthEpochs :=
  ⟨fun _ => coordinates.issuerEpoch,
    fun policy => (coordinates.policyEpochs.lookup policy.value).getD 0⟩

/-- The placement lineage at a draft's coordinates: a placement's ancestor set as its room
birth's owner grant carries it. -/
def lineageOf (coordinates : BirthCoordinates) : CapabilityId → Option (Finset CapabilityId) :=
  fun placement => (coordinates.lineage.lookup placement.value).map fun ids =>
    (ids.map CapabilityId.mk).toFinset

/-- The platform terms at a draft's coordinates: the owner budget, lifetime and fee its grants
and fee carry. -/
def termsOf (coordinates : BirthCoordinates) : SourceAgreementJson.BirthTerms :=
  ⟨coordinates.ownerBudget, coordinates.lifetime, fun _ =>
    (coordinates.fee.collector, coordinates.fee.asset, coordinates.fee.amount)⟩

/-- **The deployed authoring of the member's source at given coordinates**: the whole intent
(subject, nonce, observe grants, draft descriptor bytes and source capabilities). -/
def author (config : NativeHost.Config) (source : Lean.Json)
    (coordinates : BirthCoordinates) : Option NativeObservationCodec.Intent :=
  (SourceAgreementJson.birthIntentFrom "$" source fun path birth =>
    SourceAgreementJson.birthAt path birth config coordinates.height (epochsOf coordinates)
      (lineageOf coordinates) (termsOf coordinates)).toOption

/-- Thin birth intent consent (frame 234): the authoring check alone. -/
def checkIntent (config : NativeHost.Config) (source : Lean.Json)
    (wanted : NativeObservationCodec.Intent) :
    Except NativeThinConsent.Refusal (List UInt8 × List CapabilityId × ResourceBirth.Descriptor Registry) :=
  checkBirthIntentThin (author config source) wanted

/-- Thin birth plan consent (frame 235). -/
def checkPlan (config : NativeHost.Config) (source : Lean.Json)
    (wanted : NativeObservationCodec.Intent) (planBytes : List UInt8) :
    Except NativeThinConsent.Refusal (List (List UInt8) × BirthDisplay) :=
  checkBirthThin (publicPins config) (author config source) wanted planBytes

end Minidregg.Host.ThinBirthConsent
