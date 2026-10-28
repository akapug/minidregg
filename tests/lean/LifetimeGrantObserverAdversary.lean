/- Independent boundary probes for event27's lifetime-grant birth frame.
   These are source/decoder properties, not a claim of live Mini admission. -/
import Kernel.ResourceBirthPolicyController

namespace LifetimeGrantObserverAdversary
open Minidregg.Compiler
open Minidregg.Compiler.ResourceBirthCodec
open Minidregg.Theory
open Minidregg.Theory.ResourceBirth
open Minidregg.Theory.CredentialAuthorityState
open Minidregg.Theory.TypedAuthorization
open Minidregg.Kernel
open Minidregg.Kernel.ResourceBirthPolicyController.Concrete

/-- An extra fourth authority cannot pass the actual lifetime template. -/
theorem fourth_grant_refused
    (template : CanonicalRuntimeProfile.FactoryTemplate) (authority : AuthState)
    (height : Height) (descriptor : Descriptor Registry)
    (item : BirthItem Registry) (owner control observer extra : AuthorityGrant) :
    ¬ LifetimeGrantTemplateBound template authority height
      { descriptor with births := [item], grants := [owner, control, observer, extra] } := by
  simp [LifetimeGrantTemplateBound]

/-- Two or more births cannot use the one-grant event27 template. -/
theorem second_birth_refused
    (template : CanonicalRuntimeProfile.FactoryTemplate) (authority : AuthState)
    (height : Height) (descriptor : Descriptor Registry)
    (first second : BirthItem Registry) (owner control observer : AuthorityGrant) :
    ¬ LifetimeGrantTemplateBound template authority height
      { descriptor with births := [first, second], grants := [owner, control, observer] } := by
  simp [LifetimeGrantTemplateBound]

/-- The event27 observer for an object has exactly one allowed verb and target. -/
theorem observer_exact (capability : StoredCapability .object) (item : BirthItem Registry)
    (accepted : LifetimeObserverGrant ⟨.object, capability⟩ item) :
    capability.head.scope.verbs = {.observeObject} ∧
    capability.head.scope.targets = .explicit {⟨item.create.cellId⟩} := by
  exact ⟨accepted.2.2.1, accepted.2.1⟩

/-- Frame separation is checked on the actual canonical inner codec, even for
an otherwise well-formed ingress object. -/
def emptyCredential : BranchCredential := ⟨none, []⟩
def wireProbe : Ingress := ⟨[], ⟨emptyCredential, emptyCredential, [], []⟩⟩
#guard (ingressCodec.decode (lifetimeGrantIngressCodec.encode wireProbe)).isNone
#guard (reserveIngressCodec.decode (lifetimeGrantIngressCodec.encode wireProbe)).isNone
#guard (lifetimeGrantIngressCodec.decode (ingressCodec.encode wireProbe)).isNone
#guard (lifetimeGrantIngressCodec.decode (reserveIngressCodec.encode (wireProbe, []))).isNone
#guard (lifetimeGrantIngressCodec.decode (lifetimeGrantIngressCodec.encode wireProbe)).isSome

end LifetimeGrantObserverAdversary
