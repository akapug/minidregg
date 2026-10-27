/-
# Kernel.PlatformInstallReceiver — the controller installs a new platform record

One receiver over the platform cell (`Kernel.PlatformCellLayout`): the deployment's factory
controller replaces the current record with a valid record of a higher version. It is the
receiver of `Kernel.PlatformCell.Admits`.

Authorization, exactly as `PayBookReceiver`: the sponsor presents the control (program)
capability on the factory, verb `installPolicy`, admitted in capability mode under the
factory's current law with the operation slot `authority/operation/platform-install`, the
signature verified by the deployment's native verifier over the request. Beyond that the
sponsor must BE the controller the cell names (`PlatformCellLayout.controllerOf`, written at
genesis): holding the control capability is not enough, so a delegate cannot install.

A custodian-key rotation also carries the CURRENT custodian's raw signature over the same
command bytes (`Ingress.custodianCosign`, checked by `CredentialSignatureIO.verify`); a
dropped key is refused.

The single-use marker is a function of (domain, semantics, sponsor, version): replaying an
install hits a spent marker, and its version is not above the current one anyway.

The commit gate is the pure `admitsObserved` over the oracles' answers (signature,
capability, cosignature); `admitsObserved_decides` proves it is exactly `PlatformCell.Admits`
of a deployment whose oracles answered so, and `receiverDecides` is `PlatformCell.Decides`.
-/
import Compiler.DurableReceiverIO
import Kernel.CapabilityRevocationController
import Kernel.PlatformCellDomain
import Kernel.PlatformCell
import Kernel.PayTariff

namespace Minidregg.Kernel.PlatformInstallReceiver

open Minidregg.Compiler
open Minidregg.Compiler.CanonicalPolicyAdmission
open Minidregg.Compiler.CredentialAuthorityDomainReceiver
open Minidregg.Compiler.CredentialAuthorityPolicyRegistry
open Minidregg.Compiler.CredentialAuthorityEntryCodec
open Minidregg.Compiler.ResourceBirthCodec
open Minidregg.Compiler.Tower256ConcreteBackend
open Minidregg.Kernel
open Minidregg.Kernel.DurableDataIntent
open Minidregg.Kernel.PlatformCellLayout (Platform PlatformStore recordOf controllerOf installPatch)
open Minidregg.Kernel.PayTariff (framed framed_canonical)
open Minidregg.Theory
open Minidregg.Theory.CellState
open Minidregg.Theory.CellRegistry
open Minidregg.Theory.CredentialAuthorityState
open Minidregg.Theory.CredentialAuthorityEffects
open Minidregg.Theory.IndexedProgram
open Minidregg.Theory.PolicyInstall
open Minidregg.Theory.Store (Store Patch Op Address)
open Minidregg.Theory.TypedAuthorization

set_option autoImplicit false

abbrev Registry := CanonicalCellRegistry.registry
abbrev Deployment := CanonicalCellRegistry.Deployment
abbrev Durable := DurableReceiverIO.Loaded ResourceBirthCodec.rootBytes
abbrev Snapshot := CredentialAuthorityDomain.Snapshot

/-! ## Command and ingress -/

structure Command where
  sponsor : SubjectId
  control : CapabilityId
  expectedFactoryRoot : Digest
  expectedAuthorityRoot : Digest
  expectedPlatformRoot : Digest
  next : Platform
  deriving DecidableEq, Repr

def commandStream : StreamCodec Command :=
  StreamCodec.xmap
    (StreamCodec.product TypedAuthorizationRequestCodec.subjectIdStream
      (StreamCodec.product capabilityIdStream
        (StreamCodec.product digestStream
          (StreamCodec.product digestStream
            (StreamCodec.product digestStream PlatformCellLayout.platformStream)))))
    (fun c => (c.sponsor, c.control, c.expectedFactoryRoot, c.expectedAuthorityRoot,
      c.expectedPlatformRoot, c.next))
    (fun (sponsor, control, factoryRoot, authorityRoot, platformRoot, next) =>
      ⟨sponsor, control, factoryRoot, authorityRoot, platformRoot, next⟩)
    (by intro c; cases c; rfl)

def commandFrame : List UInt8 := "DREGG/PLATFORM/INSTALL/v1".toUTF8.toList

def commandCodec : LawfulCodec Command := framed commandFrame commandStream

theorem command_roundtrip (command : Command) :
    commandCodec.decode (commandCodec.encode command) = some command :=
  commandCodec.decode_encode command

theorem commandCodec_injective {a b : Command} (same : commandCodec.encode a = commandCodec.encode b) :
    a = b :=
  PlatformCell.lawful_injective commandCodec same

/-- The signed ingress: the command bytes, the sponsor's envelope over the request, and, when
the custodian key rotates, the current custodian's raw signature over the command bytes. -/
structure Ingress where
  commandBytes : List UInt8
  sponsorEnvelope : List UInt8
  custodianCosign : Option (List UInt8)
  deriving DecidableEq, Repr

def ingressStream : StreamCodec Ingress :=
  StreamCodec.xmap (StreamCodec.product bytesStream
      (StreamCodec.product bytesStream (StreamCodec.option bytesStream)))
    (fun ingress => (ingress.commandBytes, ingress.sponsorEnvelope, ingress.custodianCosign))
    (fun (command, sponsor, cosign) => ⟨command, sponsor, cosign⟩)
    (by intro ingress; cases ingress; rfl)

def ingressCodec : LawfulCodec Ingress :=
  framed "DREGG/PLATFORM/INSTALL/SIGNED/v1".toUTF8.toList ingressStream

structure DecodedIngress where
  private mk ::
  ingress : Ingress
  command : Command
  canonical : commandCodec.encode command = ingress.commandBytes
  envelope : CredentialSignedEnvelopeController.SignedEnvelope
  envelopeExact : CredentialSignatureAdmission.canonicalEnvelopeCodec.decode ingress.sponsorEnvelope =
    some envelope

theorem DecodedIngress.sound (decoded : DecodedIngress) :
    commandCodec.encode decoded.command = decoded.ingress.commandBytes ∧
      CredentialSignatureAdmission.canonicalEnvelopeCodec.decode decoded.ingress.sponsorEnvelope =
        some decoded.envelope :=
  ⟨decoded.canonical, decoded.envelopeExact⟩

def decodeIngress (bytes : List UInt8) : Option DecodedIngress := do
  let ingress ← ingressCodec.decode bytes
  match commandExact : commandCodec.decode ingress.commandBytes with
  | none => none
  | some command =>
    match envelopeExact : CredentialSignatureAdmission.canonicalEnvelopeCodec.decode
        ingress.sponsorEnvelope with
    | none => none
    | some envelope =>
      some ⟨ingress, command, framed_canonical commandFrame commandStream commandExact,
        envelope, envelopeExact⟩

def DecodedIngress.bytes (ingress : DecodedIngress) : List UInt8 :=
  ingressCodec.encode ingress.ingress

/-- The single-use marker: one per (sponsor, version) in a deployment and semantics. -/
def marker (domain semantics : Digest) (command : Command) : Nat :=
  (Sp800185Cshake256.hash "DREGG.PLATFORM.INSTALL.IDENTITY/v1".toUTF8.toList
    ((StreamCodec.product digestStream (StreamCodec.product digestStream
      (StreamCodec.product TypedAuthorizationRequestCodec.subjectIdStream
        StreamCodec.nat))).encode
      (domain, semantics, command.sponsor, command.next.version))).digest.value

/-! ## The decision -/

inductive Reject where
  | malformedIngress | directoryUnavailable | authorityUnavailable | factoryUnavailable
  | platformUnavailable | staleAuthority | stalePlatform
  | notController | versionNotIncreasing | recordInvalid | custodianDropped
  | custodianNotCosigned | custodianCosignRejected
  | replayedMarker | validation | physicalPreparation
  | policyUnavailable | capabilityRejected | policyRejected | policyInputRange | policyCastAlias
  | signature (reason : CredentialSignatureAdmission.Reject)
  deriving DecidableEq, Repr

/-- What the custodian rule needs from IO: nothing, or a check of `cosign` under `old`. -/
inductive CustodianNeed where
  | none
  | check (old cosign : List UInt8)
  deriving DecidableEq, Repr

/-- The oracle-free half, run before any signature is checked: the cell holds a record and
its controller, the sponsor is that controller, the version rises, the record is valid, and
the custodian step is shaped (no drop; a rotation carries a cosignature). -/
def decideRecord (store : PlatformStore) (command : Command) (cosign : Option (List UInt8)) :
    Except Reject (Platform × CustodianNeed) :=
  match recordOf store, controllerOf store with
  | some current, some controller =>
      if command.sponsor ≠ controller then .error .notController
      else if ¬ current.version < command.next.version then .error .versionNotIncreasing
      else if command.next.valid = false then .error .recordInvalid
      else
        match current.completionCustodianKey, command.next.completionCustodianKey with
        | none, _ => .ok (current, .none)
        | some _, none => .error .custodianDropped
        | some old, some new =>
            if old = new then .ok (current, .none)
            else match cosign with
              | some s => .ok (current, .check old s)
              | none => .error .custodianNotCosigned
  | _, _ => .error .platformUnavailable

/-- What the oracles answered for one install: the sponsor's signature over the request,
the control capability under the factory's law, and the custodian's cosignature. -/
structure Observed where
  sponsorVerified : Bool
  capabilityHeld : Bool
  cosignVerified : Bool
  deriving DecidableEq, Repr

/-- **The commit gate.** The receiver commits an install only when this holds of the loaded
cell, the command, the presented cosignature and the oracles' answers. -/
def admitsObserved (store : PlatformStore) (command : Command) (cosign : Option (List UInt8))
    (o : Observed) : Bool :=
  match recordOf store, controllerOf store with
  | some current, some controller =>
      decide (command.sponsor = controller) && o.sponsorVerified && o.capabilityHeld &&
        decide (current.version < command.next.version) && command.next.valid &&
        PlatformCell.custodianCheck (fun _ _ _ => o.cosignVerified) [] cosign
          current.completionCustodianKey command.next.completionCustodianKey
  | _, _ => false

/-! ### The gate is the spec's admission -/

/-- The install the spec reads off a command and its signatures. -/
def installOf (command : Command) (envelope : List UInt8) (cosign : Option (List UInt8)) :
    PlatformCell.Install :=
  ⟨command.next, command.sponsor, command.control, envelope, cosign⟩

/-- The command an install stands for, at the pinned roots `roots`. -/
def commandAt (roots : Digest × Digest × Digest) (i : PlatformCell.Install) : Command :=
  ⟨i.subject, i.capability, roots.1, roots.2.1, roots.2.2, i.next⟩

/-- The deployed context: the spec's deployment with the receiver's own command codec, which
covers the whole record (the audit's `covers`). -/
def receiverContext (d : PlatformCell.Deployment) (roots : Digest × Digest × Digest) :
    PlatformCell.Context where
  deployment := d
  encode i := commandCodec.encode (commandAt roots i)
  covers i j same := by
    have := commandCodec_injective same
    simp only [commandAt, Command.mk.injEq] at this
    exact ⟨this.2.2.2.2.2, this.1, this.2.1⟩

theorem custodianCheck_congr (v w : List UInt8 → List UInt8 → List UInt8 → Bool)
    (b c : List UInt8) (cosign : Option (List UInt8)) (old new : Option (List UInt8))
    (agree : ∀ k s, old = some k → cosign = some s → v k b s = w k c s) :
    PlatformCell.custodianCheck v b cosign old new = PlatformCell.custodianCheck w c cosign old new := by
  rcases old with _ | k <;> rcases new with _ | n <;> simp only [PlatformCell.custodianCheck]
  rcases cosign with _ | s
  · rfl
  · simp [agree k s rfl rfl]

/-- **`admitsObserved` is exactly `PlatformCell.Admits`** of any deployment whose oracles
answered `o` and whose controller is the one the cell names, over a history whose current
record the cell holds. -/
theorem admitsObserved_decides (ctx : PlatformCell.Context) (h : PlatformCell.History)
    (store : PlatformStore) (command : Command) (envelope : List UInt8)
    (cosign : Option (List UInt8)) (o : Observed)
    (cellHolds : recordOf store = some h.current)
    (controllerHolds : controllerOf store = some ctx.deployment.controller)
    (sponsor : ctx.deployment.verifies ctx.deployment.controller
      (ctx.encode (installOf command envelope cosign)) envelope = o.sponsorVerified)
    (held : ctx.deployment.holdsInstall ctx.deployment.controller command.control = o.capabilityHeld)
    (cosigned : ∀ old s, h.current.completionCustodianKey = some old → cosign = some s →
      ctx.deployment.verifiesKey old (ctx.encode (installOf command envelope cosign)) s =
        o.cosignVerified) :
    admitsObserved store command cosign o = true ↔
      PlatformCell.Admits ctx h (installOf command envelope cosign) := by
  rw [← PlatformCell.decideInstall_decides]
  have custodian := custodianCheck_congr (fun _ _ _ => o.cosignVerified) ctx.deployment.verifiesKey
    [] (ctx.encode (installOf command envelope cosign)) cosign h.current.completionCustodianKey
    command.next.completionCustodianKey (fun k s hk hs => (cosigned k s hk hs).symm)
  simp only [installOf] at sponsor custodian
  simp only [admitsObserved, cellHolds, controllerHolds, PlatformCell.decideInstall, installOf,
    sponsor, held, custodian]
  exact Iff.rfl

/-- The oracle answers a deployment gives for an install over a history. -/
def oracle (ctx : PlatformCell.Context) (h : PlatformCell.History) (i : PlatformCell.Install) :
    Observed :=
  ⟨ctx.deployment.verifies ctx.deployment.controller (ctx.encode i) i.envelope,
    ctx.deployment.holdsInstall ctx.deployment.controller i.capability,
    match h.current.completionCustodianKey, i.custodianCosign with
    | some old, some s => ctx.deployment.verifiesKey old (ctx.encode i) s
    | _, _ => false⟩

/-- **L1-c at the receiver: `PlatformCell.Decides`.** The receiver's gate, run on the cell a
deployment holds (its current record and its controller) with the deployment's own oracle
answers, decides exactly `Admits`. -/
theorem receiverDecides (ctx : PlatformCell.Context) (roots : Digest × Digest × Digest) :
    PlatformCell.Decides ctx (fun h i =>
      admitsObserved (PlatformCellLayout.genesisStore ctx.deployment.controller h.current)
        (commandAt roots i) i.custodianCosign (oracle ctx h i)) := by
  intro h i
  have same : installOf (commandAt roots i) i.envelope i.custodianCosign = i := by
    cases i; rfl
  have := admitsObserved_decides ctx h
    (PlatformCellLayout.genesisStore ctx.deployment.controller h.current) (commandAt roots i)
    i.envelope i.custodianCosign (oracle ctx h i) (by simp) (by simp)
    (by rw [same]; rfl) rfl
    (by intro old s hk hs; rw [same]; simp [oracle, hk, hs])
  rwa [same] at this

/-- Teeth: an unverified sponsor signature is refused whatever else holds. -/
theorem unsigned_refused (store : PlatformStore) (command : Command) (cosign : Option (List UInt8))
    (held cosigned : Bool) :
    admitsObserved store command cosign ⟨false, held, cosigned⟩ = false := by
  unfold admitsObserved; split <;> simp

/-- Teeth: a sponsor other than the cell's controller is refused, every oracle answering yes. -/
theorem delegate_refused (controller : SubjectId) (current : Platform) (command : Command)
    (cosign : Option (List UInt8)) (other : command.sponsor ≠ controller) :
    admitsObserved (PlatformCellLayout.genesisStore controller current) command cosign
      ⟨true, true, true⟩ = false := by
  simp [admitsObserved, other]

/-- Satisfiable pole: the controller's signed install of its valid record one version up,
with no custodian key involved, is admitted. -/
theorem controller_install_admitted (controller : SubjectId) (current : Platform)
    (control : CapabilityId) (roots : Digest × Digest × Digest)
    (valid : current.valid = true) (noKey : current.completionCustodianKey = none) :
    admitsObserved (PlatformCellLayout.genesisStore controller current)
      ⟨controller, control, roots.1, roots.2.1, roots.2.2,
        { current with version := current.version + 1 }⟩ none
      ⟨true, true, false⟩ = true := by
  rcases current with ⟨v, c, g, k, o, l⟩
  simp only at noKey
  subst noKey
  simp only [PlatformCellLayout.Platform.valid, Bool.and_eq_true] at valid
  simp [admitsObserved, PlatformCell.custodianCheck, PlatformCellLayout.Platform.valid, valid]

/-! ## The effect family over the platform cell -/

structure Plan where
  current : Platform
  next : Platform
  deriving DecidableEq, Repr

def Plan.patch (plan : Plan) : Patch PlatformCellLayout.layout := installPatch plan.current plan.next

def planStream : StreamCodec Plan :=
  StreamCodec.xmap (StreamCodec.product PlatformCellLayout.platformStream PlatformCellLayout.platformStream)
    (fun plan => (plan.current, plan.next))
    (fun (current, next) => ⟨current, next⟩)
    (by intro plan; cases plan; rfl)

structure Declaration where
  plan : Plan
  expectedPreRoot : Digest
  operationNullifier : Nat

def declarationStream : StreamCodec Declaration :=
  StreamCodec.xmap (StreamCodec.product planStream (StreamCodec.product digestStream StreamCodec.nat))
    (fun d => (d.plan, d.expectedPreRoot, d.operationNullifier))
    (fun (plan, root, nullifier) => ⟨plan, root, nullifier⟩)
    (by intro d; cases d; rfl)

def declarationCodec : LawfulCodec Declaration :=
  declarationStream.toLawful

def declaration (domain semantics : Digest) (command : Command) (plan : Plan) : Declaration :=
  ⟨plan, command.expectedPlatformRoot, marker domain semantics command⟩

structure Mode {M : Materializer PlatformCellLayout.layout Digest} (pre : Materialized M)
    (d : Declaration) : Type where
  rootExact : d.expectedPreRoot = pre.root

def effectDigest (domain semantics : Digest) (command : Command) (d : Declaration) : Digest :=
  (Sp800185Cshake256.hash "DREGG.PLATFORM.INSTALL.EFFECT/v1".toUTF8.toList
    ((StreamCodec.product digestStream (StreamCodec.product digestStream
      (StreamCodec.product bytesStream bytesStream))).encode
      (domain, semantics, commandCodec.encode command, declarationCodec.encode d))).digest

structure Ambient where
  federation : FederationId
  height : Height

def context (deployment : Deployment) (snapshot : Snapshot) (semantics : Digest)
    (ambient : Ambient) (command : Command) : RequestContext where
  authority :=
    { kind := .program
      domain := snapshot.domain
      semantics := semantics
      federation := ambient.federation
      subject := command.sponsor
      subjectKeyEpoch := snapshot.authState.subjectKeyEpoch command.sponsor
      target := ⟨deployment.factoryId⟩
      verb := .installPolicy
      nonce := marker snapshot.domain semantics command
      height := ambient.height
      policyId := ⟨deployment.factoryId⟩
      policyEpoch := snapshot.authState.policyEpoch ⟨deployment.factoryId⟩
      policyRevision := snapshot.authState.policyRevision ⟨deployment.factoryId⟩
      cost := (commandCodec.encode command).length }
  argsDigestBytes := fun bytes =>
    (Sp800185Cshake256.hash "DREGG.PLATFORM.INSTALL.ARGS/v1".toUTF8.toList
      (commandCodec.encode command ++ bytes)).digest

def request (deployment : Deployment) (snapshot : Snapshot) (platform : PlatformCellDomain.Cell)
    (semantics : Digest) (ambient : Ambient) (command : Command) (plan : Plan) : Request .program :=
  ((context deployment snapshot semantics ambient command).request declarationCodec
    (effectDigest snapshot.domain semantics command) platform.root
    (marker snapshot.domain semantics command)
    (declaration snapshot.domain semantics command plan)).2

def family (deployment : Deployment) (snapshot : Snapshot) (platform : PlatformCellDomain.Cell)
    (semantics : Digest) (ambient : Ambient) (command : Command) :
    SemanticEffectFamily PlatformCellLayout.layout PlatformCellLayout.materializer Nat where
  Declaration := Declaration
  declarationCodec := declarationCodec
  pre := platform
  request := fun d => (context deployment snapshot semantics ambient command).request
    declarationCodec (effectDigest snapshot.domain semantics command) platform.root
    d.operationNullifier d
  Outcome := fun _ => Unit
  outcomeCodec := fun _ => unitCodec
  ModeEvidence := fun d _ => Mode platform d
  Postcondition := fun d _ post => d.plan.patch.ResultAt platform.logical post
  effectDigest := effectDigest snapshot.domain semantics command
  patch := fun d _ => d.plan.patch
  nullifier := fun d _ => some d.operationNullifier
  Release := fun _ _ => Unit
  DeclassificationAuthority := fun _ _ => Unit
  ReleaseAuthorization := fun _ _ _ => Unit
  DisclosureAllowed := fun _ _ => sealedOnly

def requireSome {A : Type} (reason : Reject) : Option A → Except Reject A
  | none => .error reason
  | some value => .ok value

/-! ## Preparation -/

structure Prepared {F : Type} [Field F] (deployment : Deployment)
    (profile : CanonicalRuntimeProfile.Profile F) (ambient : Ambient) (durable : Durable)
    (command : Command) (cosign : Option (List UInt8)) where
  private mk ::
  directory : LoadedDirectory durable
  authority : CredentialAuthorityDomainReceiver.Loaded deployment durable.snapshot
  factory : ResourceTargetAdmission.Observed deployment directory.directory .object
    deployment.factoryId command.expectedFactoryRoot
  platform : PlatformCellDomain.Loaded deployment durable.snapshot
  current : Platform
  need : CustodianNeed
  decided : decideRecord platform.cell.logical command cosign = .ok (current, need)
  candidate : Candidate (family deployment authority.snapshot platform.cell profile.semantics ambient command)
    platform.cell (declaration authority.snapshot.domain profile.semantics command ⟨current, command.next⟩) ()
  source : CanonicalCellRegistry.LoadedPolicySource authority.snapshot.domain directory.directory
    (authority.snapshot.authState.policyAddress ⟨deployment.factoryId⟩
      (authority.snapshot.authState.policyRevision ⟨deployment.factoryId⟩))

def prepare {F : Type} [Field F] (deployment : Deployment)
    (profile : CanonicalRuntimeProfile.Profile F) (ambient : Ambient) (durable : Durable)
    (command : Command) (cosign : Option (List UInt8)) :
    Except Reject (Prepared deployment profile ambient durable command cosign) := do
  let directory ← requireSome .directoryUnavailable (loadDirectory durable)
  let authority ← requireSome .authorityUnavailable (loadDeployment deployment durable.snapshot)
  let factory ← requireSome .factoryUnavailable
    (ResourceTargetAdmission.observe deployment directory.directory .object
      deployment.factoryId command.expectedFactoryRoot)
  let platform ← requireSome .platformUnavailable (PlatformCellDomain.load deployment durable.snapshot)
  let snapshot := authority.snapshot
  if command.expectedAuthorityRoot = snapshot.cell.root then
    if rootExact : command.expectedPlatformRoot = platform.cell.root then
      match decided : decideRecord platform.cell.logical command cosign with
      | .error reason => throw reason
      | .ok (current, need) =>
        let d := declaration snapshot.domain profile.semantics command ⟨current, command.next⟩
        if snapshot.spent d.operationNullifier = false then
          match validate PlatformCellLayout.materializer platform.cell platform.cell.root d.plan.patch with
          | .rejected _ => throw .validation
          | .accepted validated =>
              let source ← requireSome .policyUnavailable (CanonicalCellRegistry.loadPolicySource
                snapshot.domain directory.directory
                (snapshot.authState.policyAddress ⟨deployment.factoryId⟩
                  (snapshot.authState.policyRevision ⟨deployment.factoryId⟩)))
              let candidate : Candidate
                  (family deployment snapshot platform.cell profile.semantics ambient command)
                  platform.cell d () :=
                { preStateBound := rfl
                  modeEvidence := ⟨rootExact⟩
                  validated := validated
                  postcondition := validated.resultAt }
              pure ⟨directory, authority, factory, platform, current, need, decided, candidate, source⟩
        else throw .replayedMarker
    else throw .stalePlatform
  else throw .staleAuthority

variable {F : Type} [Field F] {deployment : Deployment}
  {profile : CanonicalRuntimeProfile.Profile F} {ambient : Ambient} {durable : Durable}
  {command : Command} {cosign : Option (List UInt8)}

def Prepared.plan (prepared : Prepared deployment profile ambient durable command cosign) : Plan :=
  ⟨prepared.current, command.next⟩

/-- The platform cell after the install: the validated patch applied to the loaded cell. -/
def Prepared.platformPost (prepared : Prepared deployment profile ambient durable command cosign) :
    PlatformCellDomain.Cell :=
  prepared.candidate.validated.apply

def project (prepared : Prepared deployment profile ambient durable command cosign)
    (logical : PlatformStore) : Minidregg.Pred.State :=
  ⟨WorldKindLawDependencies.targetSelectorSlots prepared.directory.directory deployment.factoryId ++
    CanonicalRuntimeProfile.requestSlots
      (request deployment prepared.authority.snapshot prepared.platform.cell profile.semantics ambient
        command prepared.plan) ++
    [("authority/operation/platform-install", 1),
     ("platform/version", Int.ofNat ((recordOf logical).map Platform.version |>.getD 0))] ++
    DeclaredResourceController.bytesSlots "command/bytes" 0 (commandCodec.encode command) ++
    DeclaredResourceController.bytesSlots "resource/bytes" 0
      (PackedCell.bytes Registry prepared.factory.before) ++
    ResourceAuthorityProjection.grantSlots "authority/control" .program command.control
      prepared.authority.snapshot.logical⟩

def step (prepared : Prepared deployment profile ambient durable command cosign) : PolicyStepContext :=
  PolicyStepContext.ofCandidate (project prepared) profile.semantics prepared.candidate

def kindDependencies (prepared : Prepared deployment profile ambient durable command cosign) :
    Option WorldKindLawDependencies.Dependencies :=
  WorldKindLawDependencies.loadTarget deployment prepared.directory.directory deployment.factoryId

def policyConfig [DecidableEq F]
    (prepared : Prepared deployment profile ambient durable command cosign) :
    ComposedPolicyAdmission.Config F :=
  PhysicalLawResolution.config profile.compilerProfile prepared.authority.snapshot
    prepared.directory.directory
    (sourceCapabilityPortal prepared.authority.snapshot
      (marker prepared.authority.snapshot.domain profile.semantics command))
    (step prepared) deployment.factoryId
    ((kindDependencies prepared).map (·.additional) |>.getD [])

def lawReadGuards (prepared : Prepared deployment profile ambient durable command cosign) :
    Option (List (Nat × Digest)) := do
  let structural ← kindDependencies prepared
  let sources ← PhysicalLawResolution.readGuards prepared.authority.snapshot
    prepared.directory.directory profile.semantics deployment.factoryId structural.additional
  pure (sources ++ structural.readGuards)

abbrev Prepared.SemanticAccepted [DecidableEq F]
    (prepared : Prepared deployment profile ambient durable command cosign) :=
  AcceptedCellEffect (portal := (policyConfig prepared).portal)
    (authState := prepared.authority.snapshot.authState)
    (family deployment prepared.authority.snapshot prepared.platform.cell profile.semantics ambient command)
    (request deployment prepared.authority.snapshot prepared.platform.cell profile.semantics ambient
      command prepared.plan)
    prepared.platform.cell
    (declaration prepared.authority.snapshot.domain profile.semantics command prepared.plan) ()

def authorize [DecidableEq F]
    (prepared : Prepared deployment profile ambient durable command cosign)
    (receipt : CredentialSignatureAdmission.CheckedSignature prepared.authority.snapshot) :
    Except Reject prepared.SemanticAccepted := do
  let wanted := request deployment prepared.authority.snapshot prepared.platform.cell profile.semantics
    ambient command prepared.plan
  let config := policyConfig prepared
  let _ ← requireSome .policyUnavailable (kindDependencies prepared)
  let evidence ← requireSome .capabilityRejected
    (config.capabilityEvidenceChecked wanted command.control () receipt () (fun _ => ())).toOption
  let law ← requireSome .policyUnavailable config.resolve?
  let witness := law.witness
  if inputsInRange profile.compilerProfile.compiler law.predicate
      (step prepared).oldState (step prepared).newState != true then
    throw .policyInputRange
  if !decide (castInjOn F
      (intsOf law.predicate (step prepared).oldState (step prepared).newState)) then
    throw .policyCastAlias
  match ComposedPolicyAdmission.admit config wanted
      evidence witness (.policy wanted.policyId wanted.policyRevision) rfl rfl with
  | none => .error .policyRejected
  | some authorization =>
      .ok (prepared.candidate.accept authorization rfl rfl rfl .sealed trivial)

/-- The custodian's answer: `true` exactly when the native verifier verified the cosignature
under the current key over the command bytes; no check needed answers `false`, which the gate
never consults (`custodianCheck` reads it only for a rotation). -/
def cosignAnswer (native : CredentialSignatureIO.NativeConfig) (commandBytes : List UInt8) :
    CustodianNeed → IO Bool
  | .none => pure false
  | .check old s => do
      match ← CredentialSignatureIO.verify native old commandBytes s with
      | .ok true => pure true
      | _ => pure false

structure Accepted [DecidableEq F]
    (prepared : Prepared deployment profile ambient durable command cosign)
    (ingress : DecodedIngress) where
  private mk ::
  receipt : CredentialSignatureAdmission.CheckedSignature prepared.authority.snapshot
  envelopeExact : receipt.envelopeBytes = ingress.ingress.sponsorEnvelope
  semantic : prepared.SemanticAccepted
  cosignVerified : Bool
  gate : admitsObserved prepared.platform.cell.logical command cosign ⟨true, true, cosignVerified⟩ = true

theorem Accepted.sound [DecidableEq F]
    {prepared : Prepared deployment profile ambient durable command cosign} {ingress : DecodedIngress}
    (accepted : Accepted prepared ingress) :
    accepted.receipt.envelopeBytes = ingress.ingress.sponsorEnvelope ∧
      Nonempty (Authorized (policyConfig prepared).portal prepared.authority.snapshot.authState
        (request deployment prepared.authority.snapshot prepared.platform.cell profile.semantics ambient
          command prepared.plan)) ∧
      admitsObserved prepared.platform.cell.logical command cosign
        ⟨true, true, accepted.cosignVerified⟩ = true :=
  ⟨accepted.envelopeExact, ⟨accepted.semantic.authorization⟩, accepted.gate⟩

def admitNative [DecidableEq F] (native : CredentialSignatureIO.NativeConfig)
    (prepared : Prepared deployment profile ambient durable command cosign)
    (ingress : DecodedIngress) : IO (Except Reject (Accepted prepared ingress)) := do
  match ← CredentialSignatureAdmission.verifyNative native prepared.authority.snapshot
      (marker prepared.authority.snapshot.domain profile.semantics command)
      (request deployment prepared.authority.snapshot prepared.platform.cell profile.semantics ambient
        command prepared.plan)
      ingress.ingress.sponsorEnvelope with
  | .error reason => return .error (.signature reason)
  | .ok receipt =>
      if same : receipt.envelopeBytes = ingress.ingress.sponsorEnvelope then
        match authorize prepared receipt with
        | .error reason => return .error reason
        | .ok semantic =>
            let cosigned ← cosignAnswer native (commandCodec.encode command) prepared.need
            if gate : admitsObserved prepared.platform.cell.logical command cosign
                ⟨true, true, cosigned⟩ = true then
              return .ok ⟨receipt, same, semantic, cosigned, gate⟩
            else return .error .custodianCosignRejected
      else return .error .capabilityRejected

/-- The exact header the sponsor signs, derived from the current platform cell and authority. -/
def signingHeader (deployment : Deployment) (profile : CanonicalRuntimeProfile.Profile F)
    (ambient : Ambient) (durable : Durable) (command : Command) :
    Except String CredentialSignedEnvelopeController.SignedHeader := do
  let some authority := loadDeployment deployment durable.snapshot
    | .error "authority unavailable"
  let some platform := PlatformCellDomain.load deployment durable.snapshot
    | .error "platform cell unavailable"
  let some current := recordOf platform.cell.logical
    | .error "platform cell holds no record"
  (CredentialSignatureAdmission.signingHeader authority.snapshot
    (marker deployment.domain profile.semantics command)
    ⟨.program, request deployment authority.snapshot platform.cell profile.semantics ambient command
      ⟨current, command.next⟩⟩).mapError
      (fun reason => s!"platform-install signer key: {repr reason}")

/-! ## The receiver -/

def transactionId (domain semantics : Digest) (ingress : DecodedIngress) : Digest :=
  ⟨marker domain semantics ingress.command⟩

def event (domain _semantics : Digest) (ingress : DecodedIngress) : StableEvent where
  codecVersion := 1
  domain := domain
  eventId := (Sp800185Cshake256.hash "DREGG.PLATFORM.INSTALL.EVENT/v1".toUTF8.toList ingress.bytes).digest
  canonicalBytes := ingress.bytes

def nullifier (domain semantics : Digest) (ingress : DecodedIngress) : StableNullifier :=
  CredentialAuthorityReplay.nullifier domain (marker domain semantics ingress.command)

def writes (prepared : Prepared deployment profile ambient durable command cosign) : List DataWrite :=
  [prepared.platform.write prepared.platformPost]

def resourceGuard (prepared : Prepared deployment profile ambient durable command cosign) : ReadGuard :=
  ⟨⟨deployment.factoryId⟩,
    rootBytes (LifecycleImage.bytes Registry (.live prepared.factory.before))⟩

def policyGuard (prepared : Prepared deployment profile ambient durable command cosign) : ReadGuard :=
  ⟨⟨prepared.source.readGuard.1⟩, prepared.source.readGuard.2⟩

def readGuards (prepared : Prepared deployment profile ambient durable command cosign) :
    List ReadGuard :=
  resourceGuard prepared :: policyGuard prepared ::
    (prepared.authority.readGuards ++
      ((lawReadGuards prepared).getD []).map (fun (cellIdValue, root) =>
        (⟨⟨cellIdValue⟩, root⟩ : Minidregg.Kernel.DurableDataIntent.ReadGuard))).filter
      fun guard => guard.cellId ∉ (writes prepared).map DataWrite.cellId

def PhysicalShape (prepared : Prepared deployment profile ambient durable command cosign) : Prop :=
  ((writes prepared).map DataWrite.cellId).Nodup ∧
    (∀ write ∈ writes prepared, write.expectedPre = durable.snapshot.model.roots write.cellId) ∧
    (∀ write ∈ writes prepared, ResourceBirthController.Concrete.PhysicalPostLaw deployment write) ∧
    (resourceGuard prepared).cellId ∉ (writes prepared).map DataWrite.cellId ∧
    (policyGuard prepared).cellId ∉ (writes prepared).map DataWrite.cellId ∧
    (∀ guard ∈ readGuards prepared, guard.expectedRoot = durable.snapshot.model.roots guard.cellId) ∧
    (lawReadGuards prepared).isSome = true

instance physicalShapeDecidable (prepared : Prepared deployment profile ambient durable command cosign) :
    Decidable (PhysicalShape prepared) := by
  unfold PhysicalShape
  infer_instance

theorem writes_roots_bound (prepared : Prepared deployment profile ambient durable command cosign)
    (write : DataWrite) (member : write ∈ writes prepared) :
    rootBytes write.canonicalPostBytes = write.exactPost := by
  simp only [writes, List.mem_singleton] at member
  subst write
  exact prepared.platform.write_root_bound _

theorem readGuards_readonly (prepared : Prepared deployment profile ambient durable command cosign)
    (shape : PhysicalShape prepared) (guard : ReadGuard) (member : guard ∈ readGuards prepared) :
    guard.cellId ∉ (writes prepared).map DataWrite.cellId := by
  rcases List.mem_cons.mp member with rfl | rest
  · exact shape.2.2.2.1
  · rcases List.mem_cons.mp rest with rfl | authority
    · exact shape.2.2.2.2.1
    · simpa using (List.mem_filter.mp authority).2

structure AcceptedInstall [DecidableEq F] (deployment : Deployment)
    (profile : CanonicalRuntimeProfile.Profile F) (ambient : Ambient) (durable : Durable)
    (ingress : DecodedIngress) where
  private mk ::
  prepared : Prepared deployment profile ambient durable ingress.command ingress.ingress.custodianCosign
  accepted : PlatformInstallReceiver.Accepted prepared ingress
  physical : PhysicalShape prepared

theorem AcceptedInstall.sound [DecidableEq F] {ingress : DecodedIngress}
    (accepted : AcceptedInstall deployment profile ambient durable ingress) :
    accepted.accepted.receipt.envelopeBytes = ingress.ingress.sponsorEnvelope ∧
      admitsObserved accepted.prepared.platform.cell.logical ingress.command
        ingress.ingress.custodianCosign ⟨true, true, accepted.accepted.cosignVerified⟩ = true ∧
      Nonempty (Authorized (policyConfig accepted.prepared).portal
        accepted.prepared.authority.snapshot.authState
        (request deployment accepted.prepared.authority.snapshot accepted.prepared.platform.cell
          profile.semantics ambient ingress.command accepted.prepared.plan)) ∧
      PhysicalShape accepted.prepared :=
  ⟨accepted.accepted.envelopeExact, accepted.accepted.gate,
    ⟨accepted.accepted.semantic.authorization⟩, accepted.physical⟩

def admitDecodedNative [DecidableEq F] (deployment : Deployment)
    (profile : CanonicalRuntimeProfile.Profile F) (ambient : Ambient) (durable : Durable)
    (native : CredentialSignatureIO.NativeConfig) (ingress : DecodedIngress) :
    IO (Except Reject (AcceptedInstall deployment profile ambient durable ingress)) := do
  match prepare deployment profile ambient durable ingress.command ingress.ingress.custodianCosign with
  | .error reason => return .error reason
  | .ok prepared =>
    if physical : PhysicalShape prepared then
      match ← admitNative native prepared ingress with
      | .error reason => return .error reason
      | .ok accepted => return .ok ⟨prepared, accepted, physical⟩
    else return .error .physicalPreparation

variable [DecidableEq F] {ingress : DecodedIngress}

def charge (accepted : AcceptedInstall deployment profile ambient durable ingress) :
    ResourceCost.Charge
  | .incidences => 1
  | .turnBytes => ingress.bytes.length
  | .memoryTouches => (writes accepted.prepared).length + (readGuards accepted.prepared).length
  | .storageBytes => DeployedCharge.storageCharge durable.snapshot
      (writes accepted.prepared)
      (event deployment.domain profile.semantics ingress)
  | .witnessBytes => ingress.ingress.sponsorEnvelope.length +
      (ingress.ingress.custodianCosign.map List.length).getD 0
  | .proofWork => 2
  | .feeDebit | .networkBytes | .sideEffectCount | .leaseByteBlocks => 0

def intent (accepted : AcceptedInstall deployment profile ambient durable ingress) :
    DataIntent rootBytes where
  transactionId := transactionId deployment.domain profile.semantics ingress
  subject := some ingress.command.sponsor
  writes := writes accepted.prepared
  readGuards := readGuards accepted.prepared
  nullifiers := [nullifier deployment.domain profile.semantics ingress]
  exactCharge := charge accepted
  event := event deployment.domain profile.semantics ingress
  postRootsBound := writes_roots_bound accepted.prepared
  guardsReadOnly := readGuards_readonly accepted.prepared accepted.physical

/-- The one cell an accepted install writes is the platform cell. -/
theorem intent_writes_platform_cell (accepted : AcceptedInstall deployment profile ambient durable ingress) :
    (intent accepted).writes.map DataWrite.cellId = [PlatformCellDomain.cellIdOf deployment] := rfl

structure Receipt where
  transactionId : Digest
  eventId : Digest
  deriving DecidableEq, Repr

def receipt (domain semantics : Digest) (ingress : DecodedIngress) : Receipt :=
  ⟨transactionId domain semantics ingress, (event domain semantics ingress).eventId⟩

def replay (domain semantics : Digest) (durable : Durable) (ingress : DecodedIngress) :
    Option (Except Unit Receipt) :=
  match DurableCommitProtocol.Snapshot.lookupRecorded
      (transactionId domain semantics ingress) durable.snapshot.model.journal with
  | none => none
  | some recorded =>
    if recorded.transactionId = transactionId domain semantics ingress ∧
        recorded.event.event = event domain semantics ingress ∧
        recorded.nullifiers = [nullifier domain semantics ingress] then
      some (.ok (receipt domain semantics ingress))
    else some (.error ())

inductive Result where
  | confirmed (kind : DurableReceiverIO.Confirmation) (receipt : Receipt)
  | rejected (reason : Reject)
  | transactionConflict
  | durableRejected (reason : DurableDataIntent.RejectReason)
  | contention
  | unavailable (detail : String)
  | uncertain (detail : String)

def receiveLoaded (deployment : Deployment) (profile : CanonicalRuntimeProfile.Profile F)
    (ambient : Ambient) (native : CredentialSignatureIO.NativeConfig)
    (transport : DurableReceiverIO.Transport) (durable : Durable)
    (bytes : List UInt8) : IO Result := do
  let some ingress := decodeIngress bytes
    | return .rejected .malformedIngress
  match replay deployment.domain profile.semantics durable ingress with
  | some (.ok prior) => return .confirmed .replayed prior
  | some (.error _) => return .transactionConflict
  | none =>
    match ← admitDecodedNative deployment profile ambient durable native ingress with
    | .error reason => return .rejected reason
    | .ok accepted =>
      match ← DurableReceiverIO.receiveLoaded transport rootBytes durable (intent accepted) with
      | .confirmed kind _ =>
          return .confirmed kind (receipt deployment.domain profile.semantics ingress)
      | .rejected reason => return .durableRejected reason
      | .contention => return .contention
      | .unavailable detail => return .unavailable detail
      | .uncertain detail => return .uncertain detail

#assert_axioms command_roundtrip
#assert_axioms commandCodec_injective
#assert_axioms custodianCheck_congr
#assert_axioms admitsObserved_decides
#assert_axioms receiverDecides
#assert_axioms unsigned_refused
#assert_axioms delegate_refused
#assert_axioms controller_install_admitted

end Minidregg.Kernel.PlatformInstallReceiver
