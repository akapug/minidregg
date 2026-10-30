/- Actual source-prepared event27 descriptor with synthetic local inputs.
   No Store access, signatures, receiver admission, or deployed authority. -/
import Kernel.ApplicationAgentLifetimeGrantSource

namespace LifetimeGrantSourceAdversary
open Minidregg.Compiler
open Minidregg.Compiler.ResourceBirthCodec
open Minidregg.Theory
open Minidregg.Theory.ResourceBirth
open Minidregg.Theory.TypedAuthorization
open Minidregg.Kernel
open Minidregg.Kernel.ApplicationAgentLifetimeGrantSource
open Minidregg.Kernel.ResourceBirthPolicyController.Concrete

set_option maxRecDepth 8192
set_option maxHeartbeats 0

def config : NativeHost.Config := {
  deployment := ⟨⟨8500⟩, 10, 11, 12⟩
  federation := ⟨9⟩
  template := {issuer := ⟨5⟩, ownerBudget := 100000, lifetime := 10000}
  tariff := ⟨3, 2, 1, 0, 99, 0⟩
  genesisHeight := 10
  expectedSeed := ⟨0⟩
  storage := {binary := "/fixture/store", root := "/fixture/root", key := "/fixture/key"}
  signature := ⟨"/fixture/signature"⟩
}

/-- A platform record whose owner budget and lifetime differ from the genesis template: the
source must follow the record, never the template the profile carries. -/
def record : PlatformCellLayout.Platform := {
  version := 1
  creation := config.tariff
  grainBirth := none
  completionCustodianKey := none
  ownerBudget := 50000
  lifetime := 5000
}

/-- The factory template under `record`: the template the receiver binds the birth by. -/
def template : CanonicalRuntimeProfile.FactoryTemplate := templateAt config.template record

def authority : AuthState := {
  capabilityRoot := ⟨0⟩, revocationRoot := ⟨0⟩, policyRoot := ⟨0⟩
  policyAddress := fun _ _ => ⟨0⟩
  revoked := ∅
  issuerEpoch := fun _ => 0
  policyEpoch := fun _ => 0
  policyRevision := fun _ => 0
  subjectKeyEpoch := fun _ => 0
  parent := Parentage.empty
}

def spec : Spec := {
  grant := {
    source := ⟨29530, 1, ⟨⟨1⟩, ⟨2⟩, 1, ⟨3⟩⟩, 29520, ⟨4⟩⟩
    participant := ⟨9101, 6209, ⟨20010⟩, 6000, 1, ⟨20283⟩⟩
    approval := ⟨⟨8⟩, ⟨20284⟩, ⟨.allAccess, [], [], ⟨0⟩, 0⟩, 5⟩
  }
  grantOwnerCapability := ⟨20281⟩
  grantControlCapability := ⟨20282⟩
}

def prepared : Option (Descriptor CanonicalCellRegistry.registry) :=
  match ApplicationAgentLifetimeGrantSource.prepare config.profile config spec with
  | .ok ready => some (ready.expectedDescriptor config.profile config record authority 10 7 [])
  | .error _ => none

/- Positive witness is produced by the real source, then checked by the
special method. It makes no claim that native signatures/laws admit it. -/
#guard match prepared with
  | none => false
  | some descriptor => decide (LifetimeGrantTemplateBound template authority 10 descriptor)

/- Teeth: the same descriptor is refused under the genesis template, so a reader that kept
the profile's owner budget or lifetime after an install would refuse the current birth. -/
#guard match prepared with
  | none => false
  | some descriptor => decide (¬ LifetimeGrantTemplateBound config.template authority 10 descriptor)

#guard match prepared with
  | none => false
  | some descriptor => decide (¬ TemplateBound template authority 10 descriptor)

/- Mutations are made to the real source descriptor.  Subject and capability
identity are bound by the event27 source equality; target and verb also fail
its factory template. -/
#guard match prepared with
  | none => false
  | some descriptor =>
    match descriptor.grants with
    | [owner, control, ⟨.object, cap⟩] =>
      let target := {cap with head := {cap.head with scope := {cap.head.scope with targets := .explicit {⟨29531⟩}}}}
      let verb := {cap with head := {cap.head with scope := {cap.head.scope with verbs := {.delegateObject}}}}
      let subject := {cap with head := {cap.head with holder := .subject ⟨20011⟩}}
      let identifier := {cap with head := {cap.head with id := ⟨20285⟩, root := ⟨20285⟩}}
      let dTarget := {descriptor with grants := [owner, control, ⟨.object, target⟩]}
      let dVerb := {descriptor with grants := [owner, control, ⟨.object, verb⟩]}
      let dSubject := {descriptor with grants := [owner, control, ⟨.object, subject⟩]}
      let dId := {descriptor with grants := [owner, control, ⟨.object, identifier⟩]}
      let dExtra := {descriptor with grants := [owner, control, ⟨.object, cap⟩, owner]}
      let encoding := CanonicalCellRegistry.sourceEncoding.codec.encode
      decide (¬ LifetimeGrantTemplateBound template authority 10 dTarget) &&
      decide (¬ LifetimeGrantTemplateBound template authority 10 dVerb) &&
      decide (¬ LifetimeGrantTemplateBound template authority 10 dExtra) &&
      decide (LifetimeGrantTemplateBound template authority 10 dSubject) &&
      decide (LifetimeGrantTemplateBound template authority 10 dId) &&
      decide (encoding dSubject ≠ encoding descriptor) &&
      decide (encoding dId ≠ encoding descriptor)
    | _ => false

/- The real source-produced descriptor survives the special inner decoder;
the generic decoder and the special decoder reject each other's frame. Empty
credentials make this a codec boundary test, not signed admission. -/
#guard match prepared with
  | none => false
  | some descriptor =>
    let c : BranchCredential := ⟨none, []⟩
    let ingress : ResourceBirthPolicyController.Concrete.Ingress := ⟨CanonicalCellRegistry.sourceEncoding.codec.encode descriptor,
      ⟨c, c, [], []⟩⟩
    let special := lifetimeGrantIngressCodec.encode ingress
    let ordinary := ingressCodec.encode ingress
    (match decodeLifetimeGrantIngress special with
     | none => false
     | some decoded => decide (decoded.method = .lifetimeGrant) &&
       decide (CanonicalCellRegistry.sourceEncoding.codec.encode decoded.descriptor =
         CanonicalCellRegistry.sourceEncoding.codec.encode descriptor)) &&
    (decodeIngress special).isNone &&
    (decodeLifetimeGrantIngress ordinary).isNone

end LifetimeGrantSourceAdversary
