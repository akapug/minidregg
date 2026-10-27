/-
# Kernel.PlatformCell -- STATEMENTS FIRST: the platform cell (GENESIS-COUPLING L1) and the
seed-meter refill (M2), restated after the adversarial audit
(`docs/review/2026-10-27-platform-cell-statements/AUDIT.md`).

Every one of `grainBirthTariff`, `completionCustodianKey`, the `CreationTariff` and the
factory template's `{ownerBudget, lifetime}` sits in `Config.runtimeParameters` or in
`encode template`, hence in the semantics digest every signed request pins: a world born
without one of them cannot acquire it (GENESIS-COUPLING §A, §C L1). The genesis
`meterAllowance` is a lifetime meter every admitted record debits
(`DurableCommitProtocol.preflight`, `insufficientBudget`) and nothing replenishes.

This module holds the statements of both repairs (ATLAS §6 law 2): each keystone is a
`def … : Prop`; beside it stand its satisfiable pole, its teeth and the inhabitation of
its premises, and those poles are proved here because they test the statement, not the
receiver. The keystones themselves are the proof phase's.

Realizer slots (law 1), named once:
* `Authority.verifies` is `CredentialSignatureAdmission.verifyNative` against the authority
  snapshot (the envelope verifies under the subject's current enrolled key over the exact
  command bytes); `Authority.holdsInstall` / `holdsRefill` are `capabilityEvidenceChecked`
  in capability mode under the factory's current law (PayBookReceiver's authority);
  `Authority.verifiesKey` is the raw Ed25519 verifier over a 32-byte public key.
* `Context.encode` is the family's command codec (the signed bytes, envelopes excluded).
* `BirthView.platformAt` decodes the platform cell in the store the birth commits against;
  the birth's quote is `ResourceBirth.Descriptor.quotedFee` (`Host/Json.lean:2341`).
* `Meter.remaining` is `DurableCommitProtocol.Snapshot.available`; `Meter.consumed` is the
  durable nullifier set.

Out of this lane: the issuance-cap half of M2 (`wellFloorAmend` on the credit asset's issuer
well, `RealmWellReceiver`): a law-judged cell family, not the commit protocol's meter.
-/
import Kernel.NativeHostGenesis
import Kernel.NativeHostContext
import Theory.AxiomPin

namespace Minidregg.Kernel.PlatformCell

open Minidregg.Theory
open Minidregg.Theory.TypedAuthorization
open Minidregg.Theory.ResourceBirth
open Minidregg.Theory.CellRegistry
open Minidregg.Kernel.NativeHostGenesis (Config FactoryController)

set_option autoImplicit false

/-! ## The deployed authority -/

structure Authority where
  verifies : SubjectId → List UInt8 → List UInt8 → Bool
  holdsInstall : SubjectId → CapabilityId → Bool
  holdsRefill : SubjectId → CapabilityId → Bool
  verifiesKey : List UInt8 → List UInt8 → List UInt8 → Bool

/-- The request is the deployment's factory controller's: the claimed subject IS the
controller of `config` (not a free parameter), the envelope verifies under the controller's
enrolled key over the exact bytes, and the presented capability is held. A subject field
alone authorises nothing. -/
def Authorized (auth : Authority) (holds : SubjectId → CapabilityId → Bool)
    (controller : FactoryController) (bytes : List UInt8) (subject : SubjectId)
    (capability : CapabilityId) (envelope : List UInt8) : Prop :=
  subject = controller.subject ∧ auth.verifies controller.subject bytes envelope = true ∧
    holds controller.subject capability = true

/-! ## L1: the platform record -/

structure Platform where
  version : Nat
  creation : CreationTariff
  grainBirth : Option NativeHost.GrainBirthTariffPin
  completionCustodianKey : Option (List UInt8)
  ownerBudget : Nat
  lifetime : Nat
  deriving DecidableEq, Repr

/-- Record validity, the checks `NativeHost.Config.factoryPins` makes of the same fields
today: a grain-birth base is positive (`grainBirthTariffValue`), a custodian key is 32
bytes, and the window is positive. The creation tariff carries no validity today (base 0 is
a lawful free world) and gains none here. -/
def Platform.valid (p : Platform) : Bool :=
  (match p.grainBirth with | some g => decide (0 < g.base) | none => true) &&
  (match p.completionCustodianKey with | some k => decide (k.length = 32) | none => true) &&
  decide (0 < p.lifetime)

/-- The cell's own history: genesis's record, then every admitted install. The empty
history is unrepresentable. -/
structure History where
  genesis : Platform
  installs : List Platform

def History.records (h : History) : List Platform := h.genesis :: h.installs

def History.current (h : History) : Platform := h.records.getLast (List.cons_ne_nil _ _)

def History.push (h : History) (p : Platform) : History := ⟨h.genesis, h.installs ++ [p]⟩

def Sorted (h : History) : Prop := h.records.IsChain (fun a b => a.version < b.version)

structure Install where
  next : Platform
  subject : SubjectId
  capability : CapabilityId
  nonce : Nat
  envelope : List UInt8
  /-- The current custodian's signature over the same bytes, when the key rotates. -/
  custodianCosign : Option (List UInt8)

structure Context where
  config : Config
  auth : Authority
  encode : Install → List UInt8

/-- **Custodian separation** (the Host's "distinct" completion custodian key). The
controller alone may name a first key; rotating a key needs the CURRENT custodian's
signature over the install bytes; dropping a key (`some → none`, which turns checked
completion off) is refused outright. -/
def CustodianStep (verifiesKey : List UInt8 → List UInt8 → List UInt8 → Bool)
    (bytes : List UInt8) (cosign : Option (List UInt8)) :
    Option (List UInt8) → Option (List UInt8) → Prop
  | none, _ => True
  | some _, none => False
  | some old, some new => old = new ∨ ∃ s, cosign = some s ∧ verifiesKey old bytes s = true

/-- The admission the platform receiver must decide. -/
def Admits (ctx : Context) (h : History) (i : Install) : Prop :=
  Authorized ctx.auth ctx.auth.holdsInstall ctx.config.factoryController (ctx.encode i)
      i.subject i.capability i.envelope ∧
    h.current.version < i.next.version ∧
    i.next.valid = true ∧
    CustodianStep ctx.auth.verifiesKey (ctx.encode i) i.custodianCosign
      h.current.completionCustodianKey i.next.completionCustodianKey

/-- The cell's reachable histories: a valid genesis record, then admitted installs. -/
inductive Reachable (ctx : Context) : History → Prop
  | genesis (g : Platform) (valid : g.valid = true) : Reachable ctx ⟨g, []⟩
  | install (h : History) (i : Install) (prior : Reachable ctx h) (admitted : Admits ctx h i) :
      Reachable ctx (h.push i.next)

/-! ### Keystones (proof phase) -/

/-- **L1-a, the invariant:** admitting an install keeps the history sorted. -/
def StaysSorted (ctx : Context) : Prop :=
  ∀ h i, Sorted h → Admits ctx h i → Sorted (h.push i.next)

/-- **L1-a, the consequence:** every reachable history is sorted, so an admitted install is
above EVERY earlier record (replay of an install is refused by the same clause). -/
def VersionMonotone (ctx : Context) : Prop :=
  (∀ h, Reachable ctx h → Sorted h) ∧
    ∀ h i, Reachable ctx h → Admits ctx h i → ∀ p ∈ h.records, p.version < i.next.version

/-- **L1-b:** every record of a reachable history is valid. -/
def RecordsValid (ctx : Context) : Prop :=
  ∀ h, Reachable ctx h → ∀ p ∈ h.records, p.valid = true

/-- **L1-c, at the receiver:** a receiver `decide` decides exactly `Admits`; then whatever
it admits was signed by the deployment's controller's key and presented the held
capability (the receiver-level replacement of the audited `ControllerOnly`). -/
def Decides (ctx : Context) (decide : History → Install → Bool) : Prop :=
  ∀ h i, decide h i = true ↔ Admits ctx h i

def ReceiverAuthenticated (ctx : Context) (decide : History → Install → Bool) : Prop :=
  ∀ h i, decide h i = true →
    ctx.auth.verifies ctx.config.factoryController.subject (ctx.encode i) i.envelope = true ∧
      ctx.auth.holdsInstall ctx.config.factoryController.subject i.capability = true

/-- **L1-d:** a key once named is never dropped, along any reachable history. -/
def CustodianNeverDropped (ctx : Context) : Prop :=
  ∀ h i, Admits ctx h i → h.current.completionCustodianKey.isSome →
    i.next.completionCustodianKey.isSome

/-! ### L1-e: births read the platform of the store they commit against

`Terms` is everything a birth reads from the platform: every field, and the explicit grant
window `[height, height + lifetime)`. -/

structure Terms where
  creation : CreationTariff
  grainBirth : Option NativeHost.GrainBirthTariffPin
  completionCustodianKey : Option (List UInt8)
  ownerBudget : Nat
  windowFrom : Nat
  windowUntil : Nat
  deriving DecidableEq, Repr

def termsAt (p : Platform) (height : Nat) : Terms :=
  ⟨p.creation, p.grainBirth, p.completionCustodianKey, p.ownerBudget, height, height + p.lifetime⟩

/-- The birth's pre-state: the store it commits against, the platform cell decoded in it,
the store's height, and the cell id of the platform cell. -/
structure BirthView (Store : Type) where
  platformAt : Store → Option Platform
  heightOf : Store → Nat
  platformCell : Nat

/-- **L1-e.** A birth receiver reading `terms` and read-guarding `guards` reads the
platform of the very store it commits against, at that store's height, every field; and it
read-guards the platform cell, so a concurrent install makes the birth stale
(`rootsMatchCheck`), never priced at the old record. -/
def BirthsReadCurrent {Store : Type} (view : BirthView Store) (terms : Store → Option Terms)
    (guards : Store → List Nat) : Prop :=
  ∀ store p, view.platformAt store = some p →
    terms store = some (termsAt p (view.heightOf store)) ∧ view.platformCell ∈ guards store

/-- **L1-f.** The birth fee is the deployed quote over the current creation tariff. -/
def BirthQuoteCurrent {Store : Type} {registry : TypeRegistry Digest} (view : BirthView Store)
    (quote : Store → Descriptor registry → Option Nat) : Prop :=
  ∀ store p d, view.platformAt store = some p → quote store d = some (d.quotedFee p.creation)

/-! ### Poles of L1 -/

/-- A concrete authority for the poles: the controller holds every capability, and an
envelope verifies exactly when it is `toySign` of the subject and the bytes. -/
def toySign (s : SubjectId) (bytes : List UInt8) : List UInt8 := UInt8.ofNat s.value :: bytes

def toyAuth (controller : SubjectId) : Authority where
  verifies s bytes env := decide (env = toySign s bytes)
  holdsInstall s _ := decide (s = controller)
  holdsRefill s _ := decide (s = controller)
  verifiesKey _ _ _ := false

def toyContext (config : Config) : Context :=
  ⟨config, toyAuth config.factoryController.subject, fun i => [UInt8.ofNat i.next.version]⟩

def freeTariff : CreationTariff := ⟨0, 0, 0, 0, 0, 0⟩

def record (version : Nat) : Platform := ⟨version, freeTariff, none, none, 0, 1⟩

def toyInstall (config : Config) (version : Nat) : Install :=
  ⟨record version, config.factoryController.subject, ⟨0⟩, 0,
    toySign config.factoryController.subject [UInt8.ofNat version], none⟩

theorem toy_admits (config : Config) (h : History) (version : Nat)
    (above : h.current.version < version) (keyless : h.current.completionCustodianKey = none) :
    Admits (toyContext config) h (toyInstall config version) := by
  refine ⟨⟨rfl, ?_, ?_⟩, above, by simp [toyInstall, record, Platform.valid], ?_⟩
  · simp [toyContext, toyAuth, toyInstall, record]
  · simp [toyContext, toyAuth, toyInstall]
  · simp only [keyless]; trivial

/-- Premise inhabitation (replaces the audited `HistoryInhabited`): a reachable history of
two records with an admitted install on it exists, for every deployment's controller. -/
theorem premises_inhabited (config : Config) :
    ∃ h i, Reachable (toyContext config) h ∧ 2 ≤ h.records.length ∧
      Admits (toyContext config) h i := by
  have g : Reachable (toyContext config) ⟨record 0, []⟩ := .genesis _ (by decide)
  have one := toy_admits config ⟨record 0, []⟩ 1 (by decide) rfl
  refine ⟨⟨record 0, [record 1]⟩, toyInstall config 2, .install _ _ g one, by decide, ?_⟩
  exact toy_admits config _ 2 (by decide) rfl

/-- Teeth: a forged request (the subject field names the controller, the envelope does not
verify under the controller's key) is refused, for every authority. -/
theorem forged_refused (ctx : Context) (h : History) (i : Install)
    (forged : ctx.auth.verifies ctx.config.factoryController.subject (ctx.encode i) i.envelope = false) :
    ¬ Admits ctx h i := by
  rintro ⟨⟨-, verified, -⟩, -⟩
  simp [forged] at verified

/-- Teeth: a receiver that trusts the subject field (no signature check) does not decide
`Admits`. -/
def trustsSubjectField (ctx : Context) (h : History) (i : Install) : Bool :=
  decide (i.subject = ctx.config.factoryController.subject) &&
    decide (h.current.version < i.next.version) && i.next.valid

theorem trustsSubjectField_not_decides (config : Config) :
    ¬ Decides (toyContext config) (trustsSubjectField (toyContext config)) := by
  intro decides
  let unsigned : Install := { toyInstall config 1 with envelope := [] }
  have admitted := (decides ⟨record 0, []⟩ unsigned).mp (by
    simp [trustsSubjectField, unsigned, toyInstall, toyContext, History.current, History.records,
      record, Platform.valid])
  exact forged_refused _ _ _ (by simp [toyContext, toyAuth, unsigned, toySign]) admitted

/-- Teeth: the same version again, an invalid record (zero lifetime), and a dropped
custodian key are each refused. -/
theorem stale_version_refused (ctx : Context) (h : History) (i : Install)
    (stale : i.next.version ≤ h.current.version) : ¬ Admits ctx h i :=
  fun admitted => absurd admitted.2.1 (Nat.not_lt.mpr stale)

theorem invalid_refused (ctx : Context) (h : History) (i : Install) (invalid : i.next.valid = false) :
    ¬ Admits ctx h i := by
  rintro ⟨-, -, valid, -⟩
  simp [invalid] at valid

theorem zero_lifetime_invalid (p : Platform) (zero : p.lifetime = 0) : p.valid = false := by
  simp [Platform.valid, zero]

theorem custodian_drop_refused (ctx : Context) (h : History) (i : Install) (key : List UInt8)
    (named : h.current.completionCustodianKey = some key)
    (dropped : i.next.completionCustodianKey = none) : ¬ Admits ctx h i := by
  rintro ⟨-, -, -, step⟩
  rw [named, dropped] at step
  exact step

/-- Teeth: `Sorted` is load-bearing. On the unsorted record list `[5, 1]` an install at 2
is admitted although it is not above 5, so `VersionMonotone` needs reachability. -/
theorem sorted_load_bearing (config : Config) :
    Admits (toyContext config) ⟨record 5, [record 1]⟩ (toyInstall config 2) ∧
      ¬ ∀ p ∈ (History.records ⟨record 5, [record 1]⟩), p.version < (toyInstall config 2).next.version := by
  refine ⟨toy_admits config _ 2 (by decide) rfl, ?_⟩
  intro above
  have := above (record 5) (by simp [History.records])
  simp [record, toyInstall] at this

/-- Births, satisfiable: the reader of the store's own platform at its height, guarding the
platform cell, reads current. -/
def currentReader {Store : Type} (view : BirthView Store) (store : Store) : Option Terms :=
  (view.platformAt store).map (termsAt · (view.heightOf store))

theorem currentReader_reads_current {Store : Type} (view : BirthView Store) :
    BirthsReadCurrent view (currentReader view) (fun _ => [view.platformCell]) := by
  intro store p present
  simp [currentReader, present]

/-- Births, teeth: a reader of the GENESIS record does not read current once an install
changed the creation tariff. -/
def historyView : BirthView (History × Nat) := ⟨fun s => some s.1.current, (·.2), 0⟩

def genesisReader (s : History × Nat) : Option Terms := some (termsAt s.1.genesis s.2)

theorem genesisReader_stale :
    ¬ BirthsReadCurrent historyView genesisReader (fun _ => [0]) := by
  intro reads
  let paid : Platform := { record 1 with creation := ⟨1, 0, 0, 0, 0, 0⟩ }
  have := (reads (⟨record 0, [paid]⟩, 0) paid rfl).1
  simp [genesisReader, historyView, termsAt, paid, record, freeTariff] at this

/-! ## M2: the seed-meter refill

The meter is the commit protocol's (`Snapshot.available`), not a cell, so the refill is its
own family (registry `METER_REFILL_*`, owner `durable-meter`) and not `realmWell` (a
law-judged cell on the credit asset's issuer well). Its intent writes no root and carries
one nullifier, which `preflight` admits (`noCells` needs both empty), and its exact charge
is ZERO: a refill is charge-exempt, so it is admitted at an exhausted meter, the moment the
family exists for. -/

structure Refill where
  subject : SubjectId
  capability : CapabilityId
  nonce : Nat
  envelope : List UInt8
  amount : ResourceCost.Charge

structure Meter where
  remaining : ResourceCost.Charge
  consumed : List (SubjectId × Nat)

def Refill.nullifier (r : Refill) : SubjectId × Nat := (r.subject, r.nonce)

def raised (remaining amount : ResourceCost.Charge) : ResourceCost.Charge :=
  fun lane => remaining lane + amount lane

structure RefillContext where
  config : Config
  auth : Authority
  encode : Refill → List UInt8

def RefillAdmits (ctx : RefillContext) (m : Meter) (r : Refill) : Prop :=
  Authorized ctx.auth ctx.auth.holdsRefill ctx.config.factoryController (ctx.encode r)
      r.subject r.capability r.envelope ∧ r.nullifier ∉ m.consumed

/-- **M2-a.** A lawful refill receiver admits exactly `RefillAdmits`; the post-state raises
every lane by the posting (the charge is zero, so nothing is debited) and consumes the
refill's nullifier. -/
def RefillLawful (ctx : RefillContext) (post : Meter → Refill → Option Meter) : Prop :=
  ∀ m r, (RefillAdmits ctx m r → post m r = some ⟨raised m.remaining r.amount, r.nullifier :: m.consumed⟩) ∧
    (¬ RefillAdmits ctx m r → post m r = none)

/-- **M2-b, charge exemption:** the refill family's exact charge is zero. -/
def RefillChargeExempt (chargeOf : Refill → ResourceCost.Charge) : Prop := ∀ r, chargeOf r = 0

/-- Liveness pole: a zero charge is funded by any meter, the exhausted one included. -/
theorem exempt_funded_at_exhaustion (chargeOf : Refill → ResourceCost.Charge)
    (exempt : RefillChargeExempt chargeOf) (r : Refill) :
    ResourceCost.Charge.fundedCheck (chargeOf r) 0 = true := by
  simp [exempt r, ResourceCost.Charge.le_iff]

/-- Teeth of the exemption: charged like an ordinary record (one turn byte), a refill is
refused at the exhausted meter. -/
theorem charged_refill_refused_at_exhaustion (c : ResourceCost.Charge)
    (positive : 0 < c .turnBytes) : ResourceCost.Charge.fundedCheck c 0 = false := by
  cases h : ResourceCost.Charge.fundedCheck c 0 with
  | false => rfl
  | true =>
      have := ((ResourceCost.Charge.fundedCheck_eq_true_iff c 0).mp h) .turnBytes
      simp at this; omega

def refillReference (ctx : RefillContext) (m : Meter) (r : Refill) : Option Meter :=
  if r.subject = ctx.config.factoryController.subject ∧
      ctx.auth.verifies ctx.config.factoryController.subject (ctx.encode r) r.envelope = true ∧
      ctx.auth.holdsRefill ctx.config.factoryController.subject r.capability = true ∧
      r.nullifier ∉ m.consumed then
    some ⟨raised m.remaining r.amount, r.nullifier :: m.consumed⟩
  else none

/-- Satisfiable: the reference receiver is lawful. -/
theorem refillReference_lawful (ctx : RefillContext) : RefillLawful ctx (refillReference ctx) := by
  intro m r
  constructor
  · rintro ⟨⟨s, v, c⟩, fresh⟩
    simp [refillReference, s, v, c, fresh]
  · intro refused
    unfold refillReference
    rw [if_neg]
    rintro ⟨s, v, c, fresh⟩
    exact refused ⟨⟨s, v, c⟩, fresh⟩

/-- One refill transition never lowers a lane (pointwise). -/
theorem lawful_monotone (ctx : RefillContext) (post : Meter → Refill → Option Meter)
    (lawful : RefillLawful ctx post) (m next : Meter) (r : Refill)
    (admitted : post m r = some next) : ∀ lane, m.remaining lane ≤ next.remaining lane := by
  intro lane
  by_cases ok : RefillAdmits ctx m r
  · rw [(lawful m r).1 ok] at admitted
    cases admitted
    exact Nat.le_add_right _ _
  · rw [(lawful m r).2 ok] at admitted
    cases admitted

/-- **M2-c, replay:** a refill whose nullifier is consumed is refused by a lawful receiver;
and a receiver that forgets nullifiers is not lawful. -/
theorem replay_refused (ctx : RefillContext) (post : Meter → Refill → Option Meter)
    (lawful : RefillLawful ctx post) (m : Meter) (r : Refill) (spent : r.nullifier ∈ m.consumed) :
    post m r = none :=
  (lawful m r).2 fun admitted => admitted.2 spent

def forgetful (ctx : RefillContext) (m : Meter) (r : Refill) : Option Meter :=
  refillReference ctx ⟨m.remaining, []⟩ r |>.map fun n => { n with consumed := r.nullifier :: m.consumed }

def toyRefillContext (config : Config) : RefillContext :=
  ⟨config, toyAuth config.factoryController.subject, fun r => [UInt8.ofNat r.nonce]⟩

theorem forgetful_not_lawful (config : Config) :
    ¬ RefillLawful (toyRefillContext config) (forgetful (toyRefillContext config)) := by
  intro lawful
  let r : Refill := ⟨config.factoryController.subject, ⟨0⟩, 0,
    toySign config.factoryController.subject [UInt8.ofNat 0], 0⟩
  have := replay_refused _ _ lawful ⟨0, [r.nullifier]⟩ r (by simp)
  simp [forgetful, refillReference, toyRefillContext, toyAuth, r, Refill.nullifier] at this

theorem anySigner_not_lawful (config : Config) (other : SubjectId)
    (differs : other ≠ config.factoryController.subject) :
    ¬ RefillLawful (toyRefillContext config)
      (fun m r => some ⟨raised m.remaining r.amount, r.nullifier :: m.consumed⟩) := by
  intro lawful
  have := (lawful ⟨0, []⟩ ⟨other, ⟨0⟩, 0, [], 0⟩).2 (fun admitted => differs admitted.1.1)
  simp at this

#assert_axioms toy_admits premises_inhabited forged_refused trustsSubjectField_not_decides
  stale_version_refused invalid_refused zero_lifetime_invalid custodian_drop_refused
  sorted_load_bearing currentReader_reads_current genesisReader_stale
  exempt_funded_at_exhaustion charged_refill_refused_at_exhaustion refillReference_lawful
  lawful_monotone replay_refused forgetful_not_lawful anySigner_not_lawful

end Minidregg.Kernel.PlatformCell
