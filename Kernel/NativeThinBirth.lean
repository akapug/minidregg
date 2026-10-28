/-
# Kernel.NativeThinBirth — the thin consent birth arm (statement first)

Design: `docs/THIN-BIRTH-2026-10-28.md`. Thin consent (`Kernel.NativeThinConsent`) reads no
Store. A birth passes through two Host steps, and this arm checks both:

* **authoring** (`Host.CurrentResourceBirthAuthoring`, op 91): the member's `source.json`
  becomes the intent's draft descriptor. The Host's authoring reads three things from the
  Store: the height (grant window), the authority epochs, and a room birth's placement lineage.
  This arm re-runs the deployed authoring of the member's own source (`author`, instantiated
  once in `Host`) at the **coordinates** read off the draft (`coordinatesOf`), and compares the
  bytes exactly. The coordinates are shown, and each is an admission gate
  (`RootGrantShape`, `BirthWindow`, `AuthorityGrant.NativeForBirth`, `BornLineage`).
* **planning** (`NativeHost.prepareLoaded`, `.birth`): the planner fills only the kernel-owned
  `auxiliaryCreates` (`PreparedDraft.sourceExact`; forced at admission by
  `PreparedBirth.auxiliaryExact`) and signs one header per branch (`policyBranches`). Every
  member-derived field of every branch request is a function of the deployment's public pins
  and the finalized descriptor (`birthValues`). `checkHeader` takes only the three authority
  coordinates from the proposal, and the plan frame zeroes height and pre-root.

The binding: every branch's `effectsDigest` is the source effects digest of the whole executed
descriptor, and admission matches a signature only to `requestBytes` of its own request
(`CredentialSignatureAdmission.Prepared.headerExact`). So an admitted consented header fixes the
executed descriptor, up to a named collision scoped to two descriptors (it occurs exactly
at a collision of the deployment's cSHAKE source digest on two different encodings). The keystone
and the teeth conclude their claim or that collision (`EffectsCollision`), taking no hash premise.

## The poles (ATLAS fields), stated below; proofs follow the auditor's verdict

* **Keystone** `DisplayIsCommitStatement`: what a thin birth shows is what commits.
* **Teeth, after consent** `SwapAfterConsentRefusedStatement`: a Host that executes any other
  descriptor has no consented signature on any branch.
* **Teeth, before consent** `SwappedPlanRefusedStatement`: a swapped plan is refused
  `birthSourceChanged`; a swapped draft is refused `draftNotAuthored`.
* **Satisfiable** `HonestPlanAcceptedStatement`: the honest planner's plan is accepted.
* **Premise inhabitation**: the keystone and teeth take no carrier (they conclude
  `EffectsCollision` as a disjunct); `HonestPlanAcceptedStatement`'s premises are those of every
  successful birth preparation, its pins discharged by `OpenedPinsPublicStatement`. The Host-side
  re-authoring fixed point (an intent the Store-reading authoring produced re-authors to itself at
  its own coordinates) is a JOURNEY ROW (jpriv2 row 19), not a theorem.
-/
import Kernel.NativeThinConsent
import Kernel.NativeHost

namespace Minidregg.Kernel.NativeThinBirth

open Minidregg.Compiler
open Minidregg.Theory
open Minidregg.Theory.ResourceBirth
open Minidregg.Theory.TypedAuthorization
open Minidregg.Kernel.NativeThinConsent (Refusal checkHeader)
open Minidregg.Kernel.ResourceBirthPolicyController.Concrete (Branch PolicyBranch policyBranches branchRequest creation)

set_option autoImplicit false

abbrev Registry := CanonicalCellRegistry.registry

/-- The member-authored part of a birth descriptor: everything but the kernel's auxiliary
allocations (`ResourceBirthPolicyController.Concrete.userCommandBytes`). -/
def userPart (descriptor : Descriptor Registry) : Descriptor Registry :=
  { descriptor with auxiliaryCreates := [] }

/-! ## What the proposal contributes: the coordinates -/

/-- What the Host's authoring read from the Store, as data: the authoring height (every
grant's `notBefore`), the issuer epoch, each newborn's policy epoch, and each room placement's
ancestor set (as sorted capability ids). -/
structure BirthCoordinates where
  height : Nat
  issuerEpoch : Nat
  policyEpochs : List (Nat × Nat)
  lineage : List (Nat × List Nat)
  deriving DecidableEq, Repr

/-- The coordinates a draft carries, read off its grants: the first grant's window start and
issuer epoch, every grant's (policy id, policy epoch), and for every room birth the owner
grant's ancestors (grants are `[owner, control]` per birth, in birth order). A draft whose
grants disagree with each other on a coordinate re-authors to different bytes and is refused. -/
def coordinatesOf (descriptor : Descriptor Registry) : BirthCoordinates where
  height := (descriptor.grants.head?.map fun grant => grant.capability.head.notBefore).getD 0
  issuerEpoch := (descriptor.grants.head?.map fun grant => grant.capability.head.issuerEpoch).getD 0
  policyEpochs := descriptor.grants.map fun grant =>
    (grant.capability.head.policyId.value, grant.capability.head.policyEpoch)
  lineage := (List.range descriptor.births.length).filterMap fun position => do
    let item ← descriptor.births[position]?
    let placement ← item.placement
    let owner ← descriptor.grants[2 * position]?
    pure (placement.value, (owner.capability.head.ancestors.image CapabilityId.value).sort (· ≤ ·))

/-! ## The member's derivation of every branch request -/

/-- The deployment pins a birth request reads, all from the config
(`NativeHostContext.validateChecks`): domain, semantics, federation and the factory id, which
is also the factory policy id. -/
structure PublicPins where
  domain : Digest
  semantics : Digest
  federation : FederationId
  factory : Nat
  deriving DecidableEq, Repr

def publicPins (config : NativeHost.Config) : PublicPins :=
  ⟨config.deployment.domain, config.profile.semantics, config.federation, config.deployment.factoryId⟩

/-- The factory and authority legs (`factoryRequest`, `ResourceBirthAuthority.request`). The
three authority coordinates, height and pre-root are placeholders `checkHeader` and the plan
frame never compare. -/
def factoryValues (pins : PublicPins) (descriptor : Descriptor Registry) : Request .object where
  domain := pins.domain
  semantics := pins.semantics
  federation := pins.federation
  subject := descriptor.creator
  subjectKeyEpoch := 0
  target := ⟨pins.factory⟩
  verb := .mutateObject
  argsDigest := CanonicalCellRegistry.sourceEncoding.argsDigest descriptor
  effectsDigest := CanonicalCellRegistry.sourceEncoding.effectsDigest descriptor
  nonce := descriptor.nonce
  height := 0
  preStateRoot := ⟨0⟩
  policyId := ⟨pins.factory⟩
  policyEpoch := 0
  policyRevision := 0
  cost := descriptor.fee.amount

/-- An allocation leg (`ResourceBirthController.allocationRequest`). -/
def allocationValues (pins : PublicPins) (descriptor : Descriptor Registry) (cell : Nat) :
    Request .object :=
  { factoryValues pins descriptor with
    argsDigest := CanonicalCellRegistry.sourceEncoding.hashBytes
      ("DREGG.RESOURCE.BIRTH.ALLOCATION.ARGS/v2".toUTF8.toList ++
        Tower256ConcreteBackend.StreamCodec.nat.encode cell ++
        CanonicalCellRegistry.sourceEncoding.codec.encode descriptor) }

/-- A Book source leg (`CanonicalResourceEffect.batchSourceRequest` over
`resourceContexts`). -/
def sourceValues (pins : PublicPins) (descriptor : Descriptor Registry)
    (position : Fin descriptor.resourceBatch.operations.length) : Request .account :=
  let operation := descriptor.resourceBatch.operations.get position
  { domain := pins.domain
    semantics := pins.semantics
    federation := pins.federation
    subject := descriptor.creator
    subjectKeyEpoch := 0
    target := ⟨operation.posting.source⟩
    verb := .transfer
    argsDigest := CanonicalResourceEffect.sourceArgsDigest CanonicalCellRegistry.sourceEncoding
      descriptor position
    effectsDigest := CanonicalCellRegistry.sourceEncoding.effectsDigest descriptor
    nonce := descriptor.nonce
    height := 0
    preStateRoot := ⟨0⟩
    policyId := ⟨operation.posting.source⟩
    policyEpoch := 0
    policyRevision := 0
    cost := operation.feeDebit }

/-- The member's derivation of one branch request of a birth. -/
def birthValues (pins : PublicPins) (descriptor : Descriptor Registry) :
    Branch descriptor → AuthorizationDeclaration.SomeRequest
  | .factory => ⟨.object, factoryValues pins descriptor⟩
  | .authority => ⟨.object, factoryValues pins descriptor⟩
  | .allocation index => ⟨.object, allocationValues pins descriptor (creation descriptor index).cellId⟩
  | .source index => ⟨.account, sourceValues pins descriptor index⟩

/-- A branch's signing role and index in the plan (`NativeHost.prepareLoaded`'s `forBranch`). -/
def branchSlot {allocations sources : Nat} : PolicyBranch allocations sources → Nat × Nat
  | .factory => (0, 0)
  | .authority => (1, 0)
  | .allocation index => (2, index.val)
  | .source index => (3, index.val)

/-- The slots a birth's plan must carry, in order, with the member's derivation of each. -/
def birthSlotPlan (pins : PublicPins) (descriptor : Descriptor Registry) :
    List (Nat × Nat × AuthorizationDeclaration.SomeRequest) :=
  (policyBranches descriptor.createRequests.length descriptor.resourceBatch.operations.length).map
    fun branch => ((branchSlot branch).1, (branchSlot branch).2, birthValues pins descriptor branch)

/-- Every slot is the expected branch, in order, and its header signs the member's derivation. -/
def checkSlots (marker : Nat) :
    Nat → List NativeHostCodec.SigningSlot → List (Nat × Nat × AuthorizationDeclaration.SomeRequest) →
      Except Refusal Unit
  | _, [], [] => .ok ()
  | position, slot :: slots, (role, index, values) :: expected =>
      if slot.role = role ∧ slot.index = index then
        match checkHeader position marker values.2 slot.header with
        | .error refusal => .error refusal
        | .ok () => checkSlots marker (position + 1) slots expected
      else .error .slotShape
  | _, _, _ => .error .slotShape

/-! ## The arm -/

/-- What thin consent shows for a birth: the member-authored descriptor bytes and source
capabilities, the coordinates the Host's authoring read, and the finalized bytes the headers sign
(the authored bytes plus the kernel-owned auxiliary creates). -/
structure BirthDisplay where
  draft : List UInt8
  capabilities : List CapabilityId
  coordinates : BirthCoordinates
  finalized : List UInt8
  deriving DecidableEq, Repr

/-- **Thin birth consent.** `author` is the deployed authoring of the member's own source at
given coordinates (instantiated once, in `Host`): the whole intent (subject, nonce, observe
grants, the draft's descriptor bytes and source capabilities) must be the authored one. Returns
the headers to sign and the display. -/
def checkBirthThin (pins : PublicPins) (author : BirthCoordinates → Option NativeObservationCodec.Intent)
    (wanted : NativeObservationCodec.Intent) (planBytes : List UInt8) :
    Except Refusal (List (List UInt8) × BirthDisplay) :=
  match wanted.purpose with
  | .prepare (.birth draftBytes capabilities) =>
    if (GrainResourceBirthHostCodec.sourceCodec.decode draftBytes).isSome then
      .error (.birthRoute "grain-backed birth source")
    else
    match CanonicalCellRegistry.sourceEncoding.codec.decode draftBytes with
    | none => .error .birthMalformed
    | some draft =>
      if draft.auxiliaryCreates.isEmpty then
        if author (coordinatesOf draft) = some wanted then
          match NativeHostCodec.signingPlanCodec.decode planBytes with
          | none => .error .planMalformed
          | some plan =>
            match plan.finalizedDraft with
            | .birth finalBytes finalCapabilities =>
              if plan.domain = pins.domain ∧ plan.semantics = pins.semantics ∧
                  finalCapabilities = capabilities then
                match CanonicalCellRegistry.sourceEncoding.codec.decode finalBytes with
                | none => .error .planMalformed
                | some finalized =>
                  if CanonicalCellRegistry.sourceEncoding.codec.encode finalized = finalBytes then
                    if CanonicalCellRegistry.sourceEncoding.codec.encode (userPart finalized) =
                        draftBytes then
                      match checkSlots finalized.authorityNullifier 0 plan.slots
                          (birthSlotPlan pins finalized) with
                      | .error refusal => .error refusal
                      | .ok () => .ok (plan.slots.map NativeHostCodec.SigningSlot.header,
                          ⟨draftBytes, capabilities, coordinatesOf draft, finalBytes⟩)
                    else .error .birthSourceChanged
                  else .error .planMalformed
              else .error .planCoordinates
            | _ => .error .planCoordinates
        else .error .draftNotAuthored
      else .error .birthMalformed
  | _ => .error (.birthRoute "not a birth intent")

/-! ## The named collision -/

/-- Two different descriptors with the same source effects digest: a collision of the
deployment's cSHAKE source digest at exactly these two (canonical) encodings. The keystone and
the teeth conclude their claim **or** this event, so neither takes a hash premise. -/
def EffectsCollision (signed executed : Descriptor Registry) : Prop :=
  signed ≠ executed ∧
    CanonicalCellRegistry.sourceEncoding.effectsDigest signed =
      CanonicalCellRegistry.sourceEncoding.effectsDigest executed

/-! ## The poles -/

/-- **Keystone: what a thin birth shows is what commits.** Take the executor's own preparation
of a birth of descriptor `d` (`PreparedBirth`, built from the loaded image at admission) and a
signature the receiver admitted for one of its branches
(`CredentialSignatureAdmission.Prepared`) whose header is one thin consent accepted. Under the
collision at the two descriptors, at the descriptor the headers sign:

* the deployed authoring of the member's source at the shown coordinates is the intent, whose
  draft is the shown draft and capabilities;
* the executed descriptor's member-authored part is exactly the shown draft;
* its auxiliary creates are the kernel's (the grant batch's recomputation);
* the prepared writes are the newborn allocations, the factory's (unchanged) and the Book's, and
  the authority's, and nothing else;
* the newborn writes are the shown creates, then the kernel's;
* the authority post is the shown authority entries over the pre-state;
* the Book's logical post is the shown resource batch applied to the pre-Book. -/
def DisplayIsCommitStatement : Prop :=
  ∀ {F : Type} [Field F] {profile : CanonicalRuntimeProfile.Profile F}
    {deployment : CanonicalCellRegistry.Deployment} {pins : FactoryPins}
    {durable : ResourceBirthController.Concrete.Durable} {d : Descriptor Registry}
    (prepared : ResourceBirthController.Concrete.PreparedBirth profile.compilerProfile deployment
      pins durable d)
    (height : Height) (deployed : PublicPins) (author : BirthCoordinates → Option NativeObservationCodec.Intent)
    (wanted : NativeObservationCodec.Intent) (planBytes : List UInt8)
    (headers : List (List UInt8)) (shown : BirthDisplay) (signed : Descriptor Registry)
    (branch : Branch d) (snapshot : CredentialAuthorityDomain.Snapshot) (nullifier : Nat)
    (admitted : CredentialSignatureAdmission.Prepared snapshot nullifier
      (branchRequest prepared height branch))
    (bytes : List UInt8),
    checkBirthThin deployed author wanted planBytes = .ok (headers, shown) →
    bytes ∈ headers →
    CredentialSignedEnvelopeController.headerCodec.decode bytes =
      some admitted.controller.envelope.header →
    CanonicalCellRegistry.sourceEncoding.codec.decode shown.finalized = some signed →
    EffectsCollision signed d ∨
    (author shown.coordinates = some wanted ∧
    wanted.purpose = .prepare (.birth shown.draft shown.capabilities) ∧
    CanonicalCellRegistry.sourceEncoding.codec.encode (userPart d) = shown.draft ∧
    d.auxiliaryCreates = prepared.grants.auxiliaryCreates ∧
    prepared.writes = ResourceBirthController.Concrete.planWrites deployment d
      prepared.factory.payload prepared.book.payload prepared.resources.post prepared.grants.writes ∧
    ResourceBirthController.allocationWrites d =
      (userPart d).createRequests.map ResourceBirthController.birthWrite ++
        prepared.grants.auxiliaryCreates.map ResourceBirthController.birthWrite ∧
    prepared.grants.post.logical =
      CredentialAuthorityEffects.setAll prepared.authority.snapshot.logical
        (ResourceBirthAuthority.entries (userPart d)) ∧
    CanonicalResourceKernel.logicalBook prepared.resources.post.logical =
      (userPart d).resourceBatch.apply
        (CanonicalResourceKernel.logicalBook prepared.book.payload.logical))

/-- **Teeth, after consent.** A Host that executes a birth of any descriptor `d'` other than the
one the consented headers sign gets no consented signature admitted on any branch of it: every
signature the receiver admits for a branch of `d'` has a header thin consent did not accept. -/
def SwapAfterConsentRefusedStatement : Prop :=
  ∀ {F : Type} [Field F] {profile : CanonicalRuntimeProfile.Profile F}
    {deployment : CanonicalCellRegistry.Deployment} {pins : FactoryPins}
    {durable : ResourceBirthController.Concrete.Durable} {d' : Descriptor Registry}
    (prepared : ResourceBirthController.Concrete.PreparedBirth profile.compilerProfile deployment
      pins durable d')
    (height : Height) (deployed : PublicPins) (author : BirthCoordinates → Option NativeObservationCodec.Intent)
    (wanted : NativeObservationCodec.Intent) (planBytes : List UInt8)
    (headers : List (List UInt8)) (shown : BirthDisplay) (signed : Descriptor Registry),
    checkBirthThin deployed author wanted planBytes = .ok (headers, shown) →
    CanonicalCellRegistry.sourceEncoding.codec.decode shown.finalized = some signed →
    signed ≠ d' →
    EffectsCollision signed d' ∨
    ∀ (branch : Branch d') (snapshot : CredentialAuthorityDomain.Snapshot) (nullifier : Nat)
      (admitted : CredentialSignatureAdmission.Prepared snapshot nullifier
        (branchRequest prepared height branch)),
      ∀ bytes ∈ headers,
        CredentialSignedEnvelopeController.headerCodec.decode bytes ≠
          some admitted.controller.envelope.header

/-- **Teeth, before consent.** (1) A plan whose finalized descriptor's member part is not the
intent's draft is refused `birthSourceChanged`, before anything is signed. (2) An intent draft
that is not the deployed authoring of the member's source at its own coordinates is refused
`draftNotAuthored`. -/
def SwappedPlanRefusedStatement : Prop :=
  (∀ (deployed : PublicPins) (author : BirthCoordinates → Option NativeObservationCodec.Intent)
      (wanted : NativeObservationCodec.Intent) (planBytes draftBytes finalBytes : List UInt8)
      (capabilities : List CapabilityId) (draft finalized : Descriptor Registry)
      (plan : NativeHostCodec.SigningPlan),
    wanted.purpose = .prepare (.birth draftBytes capabilities) →
    GrainResourceBirthHostCodec.sourceCodec.decode draftBytes = none →
    CanonicalCellRegistry.sourceEncoding.codec.decode draftBytes = some draft →
    draft.auxiliaryCreates = [] →
    author (coordinatesOf draft) = some wanted →
    NativeHostCodec.signingPlanCodec.decode planBytes = some plan →
    plan.finalizedDraft = .birth finalBytes capabilities →
    plan.domain = deployed.domain → plan.semantics = deployed.semantics →
    CanonicalCellRegistry.sourceEncoding.codec.decode finalBytes = some finalized →
    CanonicalCellRegistry.sourceEncoding.codec.encode finalized = finalBytes →
    CanonicalCellRegistry.sourceEncoding.codec.encode (userPart finalized) ≠ draftBytes →
    checkBirthThin deployed author wanted planBytes = .error .birthSourceChanged) ∧
  (∀ (deployed : PublicPins) (author : BirthCoordinates → Option NativeObservationCodec.Intent)
      (wanted : NativeObservationCodec.Intent) (planBytes draftBytes : List UInt8)
      (capabilities : List CapabilityId) (draft : Descriptor Registry),
    wanted.purpose = .prepare (.birth draftBytes capabilities) →
    GrainResourceBirthHostCodec.sourceCodec.decode draftBytes = none →
    CanonicalCellRegistry.sourceEncoding.codec.decode draftBytes = some draft →
    draft.auxiliaryCreates = [] →
    author (coordinatesOf draft) ≠ some wanted →
    checkBirthThin deployed author wanted planBytes = .error .draftNotAuthored)

/-- **Satisfiable: the honest Host passes.** For a canonical ordinary birth draft that is the
member's authoring at its own coordinates, the plan the deployed planner builds on any opened
image (`NativeHost.prepareLoaded`, the served path's birth arm) is accepted, and the headers to
sign are exactly the plan's. No premise on the opened image: its pins are the config's
(`OpenedPinsPublicStatement`). -/
def HonestPlanAcceptedStatement : Prop :=
  ∀ (config : NativeHost.Config) (opened : NativeHost.Opened config)
    (author : BirthCoordinates → Option NativeObservationCodec.Intent) (wanted : NativeObservationCodec.Intent)
    (draftBytes : List UInt8) (capabilities : List CapabilityId) (draft : Descriptor Registry)
    (plan : NativeHostCodec.SigningPlan),
    wanted.purpose = .prepare (.birth draftBytes capabilities) →
    GrainResourceBirthHostCodec.sourceCodec.decode draftBytes = none →
    CanonicalCellRegistry.sourceEncoding.codec.decode draftBytes = some draft →
    CanonicalCellRegistry.sourceEncoding.codec.encode draft = draftBytes →
    author (coordinatesOf draft) = some wanted →
    NativeHost.prepareLoaded config opened (.birth draftBytes capabilities) = .ok plan →
    ∃ shown, checkBirthThin (publicPins config) author wanted
        (NativeHostCodec.signingPlanCodec.encode plan) =
      .ok (plan.slots.map NativeHostCodec.SigningSlot.header, shown)

/-- **Every opened image's public pins are the config's** (`validateLoaded` and
`validateLoadedFrom` build `Opened` from `validateChecks`' pins; `restorage` copies them). The
lemma that discharges what was the satisfiable pole's pins premise. -/
def OpenedPinsPublicStatement : Prop :=
  ∀ (config : NativeHost.Config) (opened : NativeHost.Opened config),
    opened.pins.federation = config.federation ∧
      opened.pins.policyId = ⟨config.deployment.factoryId⟩

end Minidregg.Kernel.NativeThinBirth
