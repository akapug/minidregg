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

Realizer slots (law 1):
* Signatures are read exactly as the deployed verifier answers them: a verdict recorded in
  the deployment's `CredentialSignatureIO.Transcript` (the native verifier's answers, each
  re-verified by `scripts/NativeTranscripts.lean`) under the subject's current enrolled key
  (`Deployment.keyOf`, the authority snapshot). Unforgeability itself is the verifier's, not
  a Lean theorem: the statements are relative to the transcript, and no transcript entry is
  ever invented here.
* `Deployment.holdsInstall` / `holdsRefill` are `capabilityEvidenceChecked` in capability mode
  under the factory's current law (PayBookReceiver's authority).
* The controller is the deployment's `factoryController`; the genesis record is
  `genesisRecord` of the deployment's `NativeHost.Config`, not any valid record.
* `Context.encode` is the family's command codec, required to cover the whole record
  (`Context.covers`), so a relay cannot swap a field under a valid signature.
* `BirthView.platformAt` decodes the platform cell in the store the birth commits against
  (`none`: missing or undecodable, and the birth is refused); the quote is
  `ResourceBirth.Descriptor.quotedFee` (`Host/Json.lean:2341`).
* The meter is `DurableCommitProtocol.Snapshot.available` under the EXTENDED install
  (`installAvailable`: the proof phase adds `Intent.credit`, default zero, which only the
  refill family sets); `Meter.consumed` is `Snapshot.consumed`, and every nullifier carries
  its family tag.

Known boundaries (recorded by the third audit pass, not closed here):
* the controller may name its OWN key as the first custodian (`CustodianStep none _`), so
  custodian separation begins with the first key a separate party holds;
* `Deployment.host` and `Deployment.genesis` carry no consistency premise between them;
* the install encoding carries no deployment or domain tag: cross-world replay rests on
  `expectedSemantics` in the signed request (`Host/Json.lean:2322`).

Out of this lane: the issuance-cap half of M2 (`wellFloorAmend` on the credit asset's issuer
well, `RealmWellReceiver`): a law-judged cell family, not the commit protocol's meter.
-/
import Kernel.NativeHostGenesis
import Kernel.NativeHostContext
import Kernel.DurableCommitProtocol
import Theory.AxiomPin

namespace Minidregg.Kernel.PlatformCell

open Minidregg.Theory
open Minidregg.Theory.TypedAuthorization
open Minidregg.Theory.ResourceBirth
open Minidregg.Theory.CellRegistry
open Minidregg.Theory.IndexedProgram (LawfulCodec)
open Minidregg.Compiler
open Minidregg.Compiler.Tower256ConcreteBackend
open Minidregg.Kernel.NativeHostGenesis (Config FactoryController)
open Minidregg.Kernel.PlatformCellLayout (Platform.valid)

set_option autoImplicit false

theorem lawful_injective {α : Type} (codec : LawfulCodec α) {a b : α}
    (same : codec.encode a = codec.encode b) : a = b := by
  have := congrArg codec.decode same
  rw [codec.decode_encode, codec.decode_encode] at this
  exact Option.some.inj this

/-! ## The deployment -/

structure Deployment where
  host : NativeHost.Config
  genesis : Config
  keyOf : SubjectId → Option (List UInt8)
  holdsInstall : SubjectId → CapabilityId → Bool
  holdsRefill : SubjectId → CapabilityId → Bool
  transcript : CredentialSignatureIO.Transcript

def Deployment.controller (d : Deployment) : SubjectId := d.genesis.factoryController.subject

/-- The envelope verifies under `subject`'s current enrolled key over `bytes`: the deployed
verifier recorded that verdict. -/
def Deployment.verifies (d : Deployment) (subject : SubjectId) (bytes envelope : List UInt8) : Bool :=
  match d.keyOf subject with
  | some key => decide ((key, bytes, envelope) ∈ d.transcript.verified)
  | none => false

/-- A raw signature under a public key (the custodian is a key, not an enrolled subject). -/
def Deployment.verifiesKey (d : Deployment) (key bytes signature : List UInt8) : Bool :=
  decide ((key, bytes, signature) ∈ d.transcript.verified)

/-! ## L1: the platform record -/

/-- The record is the platform cell's (`Kernel.PlatformCellLayout.Platform`, with its
`valid`): the spec and the cell carry one type. -/
abbrev Platform := PlatformCellLayout.Platform

/-- The deployment's genesis record: what today's runtime parameters pin. -/
def genesisRecord (host : NativeHost.Config) : Platform :=
  ⟨0, host.tariff, host.grainBirthTariff, host.completionCustodianKey,
    host.template.ownerBudget, host.template.lifetime⟩

structure History where
  genesis : Platform
  installs : List Platform

def History.records (h : History) : List Platform := h.genesis :: h.installs

def History.current (h : History) : Platform := h.records.getLast (List.cons_ne_nil _ _)

def History.push (h : History) (p : Platform) : History := ⟨h.genesis, h.installs ++ [p]⟩

def Sorted (h : History) : Prop := h.records.IsChain (fun a b => a.version < b.version)

/-- An install carries no nonce: replay is refused by the version clause. -/
structure Install where
  next : Platform
  subject : SubjectId
  capability : CapabilityId
  envelope : List UInt8
  /-- The current custodian's signature over the same bytes, when the key rotates. -/
  custodianCosign : Option (List UInt8)

/-- A context: a deployment and a command codec that covers the whole record. -/
structure Context where
  deployment : Deployment
  encode : Install → List UInt8
  covers : ∀ i j, encode i = encode j →
    i.next = j.next ∧ i.subject = j.subject ∧ i.capability = j.capability

/-- **Custodian separation.** The controller alone may name a first key; rotating a key
needs the CURRENT custodian's signature over the install bytes; dropping a key is refused. -/
def CustodianStep (verifiesKey : List UInt8 → List UInt8 → List UInt8 → Bool)
    (bytes : List UInt8) (cosign : Option (List UInt8)) :
    Option (List UInt8) → Option (List UInt8) → Prop
  | none, _ => True
  | some _, none => False
  | some old, some new => old = new ∨ ∃ s, cosign = some s ∧ verifiesKey old bytes s = true

/-- The admission the platform receiver must decide. -/
def Admits (ctx : Context) (h : History) (i : Install) : Prop :=
  i.subject = ctx.deployment.controller ∧
    ctx.deployment.verifies ctx.deployment.controller (ctx.encode i) i.envelope = true ∧
    ctx.deployment.holdsInstall ctx.deployment.controller i.capability = true ∧
    h.current.version < i.next.version ∧
    i.next.valid = true ∧
    CustodianStep ctx.deployment.verifiesKey (ctx.encode i) i.custodianCosign
      h.current.completionCustodianKey i.next.completionCustodianKey

/-- The cell's reachable histories: the deployment's genesis record, then admitted installs. -/
inductive Reachable (ctx : Context) : History → Prop
  | genesis (valid : (genesisRecord ctx.deployment.host).valid = true) :
      Reachable ctx ⟨genesisRecord ctx.deployment.host, []⟩
  | install (h : History) (i : Install) (prior : Reachable ctx h) (admitted : Admits ctx h i) :
      Reachable ctx (h.push i.next)

/-! ### Keystones (proof phase) -/

/-- **L1-a, the invariant:** admitting an install keeps the history sorted. -/
def StaysSorted (ctx : Context) : Prop :=
  ∀ h i, Sorted h → Admits ctx h i → Sorted (h.push i.next)

/-- **L1-a, the consequence:** every reachable history is sorted, and an admitted install is
above EVERY earlier record (so a replayed install is refused). -/
def VersionMonotone (ctx : Context) : Prop :=
  (∀ h, Reachable ctx h → Sorted h) ∧
    ∀ h i, Reachable ctx h → Admits ctx h i → ∀ p ∈ h.records, p.version < i.next.version

/-- **L1-b:** every record of a reachable history is valid. -/
def RecordsValid (ctx : Context) : Prop :=
  ∀ h, Reachable ctx h → ∀ p ∈ h.records, p.valid = true

/-- **L1-c, at the receiver:** `decide` decides exactly `Admits`; whatever it admits was
signed by the controller's key and presented the held capability. -/
def Decides (ctx : Context) (decide : History → Install → Bool) : Prop :=
  ∀ h i, decide h i = true ↔ Admits ctx h i

def ReceiverAuthenticated (ctx : Context) (decide : History → Install → Bool) : Prop :=
  ∀ h i, decide h i = true →
    ctx.deployment.verifies ctx.deployment.controller (ctx.encode i) i.envelope = true ∧
      ctx.deployment.holdsInstall ctx.deployment.controller i.capability = true

/-! ### Proofs of L1-a, L1-b, L1-c -/

theorem records_push (h : History) (p : Platform) : (h.push p).records = h.records ++ [p] := by
  simp [History.push, History.records]

theorem current_push (h : History) (p : Platform) : (h.push p).current = p := by
  simp [History.current, records_push]

/-- Every record of a sorted list is at or below its last. -/
theorem chain_le_last : ∀ (l : List Platform) (ne : l ≠ []),
    l.IsChain (fun a b => a.version < b.version) → ∀ p ∈ l, p.version ≤ (l.getLast ne).version
  | [], ne, _, _, _ => absurd rfl ne
  | [a], _, _, p, mem => by
      simp at mem
      subst mem
      simp
  | a :: b :: t, _, chain, p, mem => by
      have ih := chain_le_last (b :: t) (List.cons_ne_nil _ _) (List.isChain_of_isChain_cons chain)
      rw [List.getLast_cons_cons]
      rcases List.mem_cons.mp mem with same | rest
      · subst same
        exact Nat.le_of_lt (Nat.lt_of_lt_of_le (List.rel_of_isChain_cons_cons (R := fun a b : Platform => a.version < b.version) chain) (ih b (by simp)))
      · exact ih p rest

theorem staysSorted (ctx : Context) : StaysSorted ctx := by
  intro h i sorted admitted
  unfold Sorted at *
  rw [records_push, List.isChain_append]
  refine ⟨sorted, List.isChain_singleton _, ?_⟩
  intro x last y first
  simp only [List.head?_cons, Option.mem_def, Option.some.injEq] at first
  subst first
  rw [show h.records.getLast? = some h.current from
    List.getLast?_eq_getLast_of_ne_nil (List.cons_ne_nil _ _)] at last
  simp only [Option.mem_def, Option.some.injEq] at last
  subst last
  exact admitted.2.2.2.1

theorem reachable_sorted (ctx : Context) (h : History) (reachable : Reachable ctx h) : Sorted h := by
  induction reachable with
  | genesis _ => exact List.isChain_singleton _
  | install h i _ admitted ih => exact staysSorted ctx h i ih admitted

theorem versionMonotone (ctx : Context) : VersionMonotone ctx := by
  refine ⟨reachable_sorted ctx, ?_⟩
  intro h i reachable admitted p member
  exact Nat.lt_of_le_of_lt (chain_le_last h.records (List.cons_ne_nil _ _)
    (reachable_sorted ctx h reachable) p member) admitted.2.2.2.1

theorem recordsValid (ctx : Context) : RecordsValid ctx := by
  intro h reachable
  induction reachable with
  | genesis valid =>
      intro p member
      simp [History.records] at member
      subst member
      exact valid
  | install h i _ admitted ih =>
      intro p member
      rw [records_push, List.mem_append] at member
      rcases member with old | new
      · exact ih p old
      · simp at new
        subst new
        exact admitted.2.2.2.2.1

/-- The custodian rule as the receiver checks it. -/
def custodianCheck (verifiesKey : List UInt8 → List UInt8 → List UInt8 → Bool)
    (bytes : List UInt8) (cosign : Option (List UInt8)) :
    Option (List UInt8) → Option (List UInt8) → Bool
  | none, _ => true
  | some _, none => false
  | some old, some new => decide (old = new) ||
      (match cosign with | some s => verifiesKey old bytes s | none => false)

theorem custodianCheck_iff (verifiesKey : List UInt8 → List UInt8 → List UInt8 → Bool)
    (bytes : List UInt8) (cosign : Option (List UInt8)) (old new : Option (List UInt8)) :
    custodianCheck verifiesKey bytes cosign old new = true ↔
      CustodianStep verifiesKey bytes cosign old new := by
  rcases old with _ | o <;> rcases new with _ | n <;>
    simp only [custodianCheck, CustodianStep, Bool.or_eq_true, decide_eq_true_eq] <;>
    try simp
  rcases cosign with _ | c <;> simp

/-- The reference admission the platform receiver runs. -/
def decideInstall (ctx : Context) (h : History) (i : Install) : Bool :=
  decide (i.subject = ctx.deployment.controller) &&
    ctx.deployment.verifies ctx.deployment.controller (ctx.encode i) i.envelope &&
    ctx.deployment.holdsInstall ctx.deployment.controller i.capability &&
    decide (h.current.version < i.next.version) &&
    i.next.valid &&
    custodianCheck ctx.deployment.verifiesKey (ctx.encode i) i.custodianCosign
      h.current.completionCustodianKey i.next.completionCustodianKey

/-- **L1-c proved for the reference receiver.** -/
theorem decideInstall_decides (ctx : Context) : Decides ctx (decideInstall ctx) := by
  intro h i
  simp only [decideInstall, Bool.and_eq_true, decide_eq_true_eq, custodianCheck_iff, Admits,
    and_assoc]

theorem decides_authenticated (ctx : Context) (decide : History → Install → Bool)
    (decides : Decides ctx decide) : ReceiverAuthenticated ctx decide := by
  intro h i admitted
  have := (decides h i).mp admitted
  exact ⟨this.2.1, this.2.2.1⟩

/-! ### L1-d: births read the platform of the store they commit against -/

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

structure BirthView (Store : Type) where
  platformAt : Store → Option Platform
  heightOf : Store → Nat
  platformCell : Nat

/-- **L1-d.** A birth reads the platform of the very store it commits against, at that
store's height, every field and the window; it read-guards the platform cell; and a store
whose platform cell is missing or undecodable yields no terms (the birth is refused). -/
def BirthsReadCurrent {Store : Type} (view : BirthView Store) (terms : Store → Option Terms)
    (guards : Store → List Nat) : Prop :=
  ∀ store, match view.platformAt store with
    | some p => terms store = some (termsAt p (view.heightOf store)) ∧ view.platformCell ∈ guards store
    | none => terms store = none

/-- **L1-e.** The birth fee is the deployed quote over the current creation tariff; no
platform, no quote. -/
def BirthQuoteCurrent {Store : Type} {registry : TypeRegistry Digest} (view : BirthView Store)
    (quote : Store → Descriptor registry → Option Nat) : Prop :=
  ∀ store d, quote store d = (view.platformAt store).map fun p => d.quotedFee p.creation

/-! ### Poles of L1 -/

abbrev InstallWire :=
  Nat × (Nat × Nat × Nat × Nat × Nat × Nat) × Option (Nat × Nat) × Option (List UInt8) ×
    Nat × Nat × Nat × Nat

def installStream : StreamCodec InstallWire :=
  StreamCodec.product StreamCodec.nat
    (StreamCodec.product
      (StreamCodec.product StreamCodec.nat (StreamCodec.product StreamCodec.nat
        (StreamCodec.product StreamCodec.nat (StreamCodec.product StreamCodec.nat
          (StreamCodec.product StreamCodec.nat StreamCodec.nat)))))
      (StreamCodec.product (StreamCodec.option (StreamCodec.product StreamCodec.nat StreamCodec.nat))
        (StreamCodec.product (StreamCodec.option bytesStream)
          (StreamCodec.product StreamCodec.nat (StreamCodec.product StreamCodec.nat
            (StreamCodec.product StreamCodec.nat StreamCodec.nat))))))

def installWire (i : Install) : InstallWire :=
  (i.next.version, (i.next.creation.base, i.next.creation.perBirth, i.next.creation.perGrant,
    i.next.creation.perInitialPayloadByte, i.next.creation.collector, i.next.creation.asset),
    i.next.grainBirth.map (fun g => (g.base, g.perBirth)), i.next.completionCustodianKey,
    i.next.ownerBudget, i.next.lifetime, i.subject.value, i.capability.value)

theorem installWire_covers (i j : Install) (same : installWire i = installWire j) :
    i.next = j.next ∧ i.subject = j.subject ∧ i.capability = j.capability := by
  rcases i with ⟨⟨v, ⟨a, b, c, d, e, f⟩, g, k, o, l⟩, ⟨s⟩, ⟨cap⟩, _, _⟩
  rcases j with ⟨⟨v', ⟨a', b', c', d', e', f'⟩, g', k', o', l'⟩, ⟨s'⟩, ⟨cap'⟩, _, _⟩
  rcases g with _ | ⟨gb, gp⟩ <;> rcases g' with _ | ⟨gb', gp'⟩ <;>
    simp_all [installWire]

/-- A codec that covers the whole record: the canonical stream of every field. -/
def wireEncode (i : Install) : List UInt8 := (StreamCodec.toLawful installStream).encode (installWire i)

theorem wireEncode_covers (i j : Install) (same : wireEncode i = wireEncode j) :
    i.next = j.next ∧ i.subject = j.subject ∧ i.capability = j.capability :=
  installWire_covers i j (lawful_injective _ same)

/-- A deployment for the poles: the controller's key is `key`, it holds every capability,
and the transcript records exactly the listed verdicts. -/
def toyDeployment (host : NativeHost.Config) (genesis : Config) (key : List UInt8)
    (verified : List (List UInt8 × List UInt8 × List UInt8)) : Deployment where
  host := host
  genesis := genesis
  keyOf s := if s = genesis.factoryController.subject then some key else none
  holdsInstall s _ := decide (s = genesis.factoryController.subject)
  holdsRefill s _ := decide (s = genesis.factoryController.subject)
  transcript := ⟨verified⟩

def toyContext (d : Deployment) : Context := ⟨d, wireEncode, wireEncode_covers⟩

/-- The controller's install of `next`, with envelope `env`. -/
def installOf (genesis : Config) (next : Platform) (env : List UInt8) : Install :=
  ⟨next, genesis.factoryController.subject, ⟨0⟩, env, none⟩

/-- The verdict a signed install needs in the transcript. -/
def verdictFor (key : List UInt8) (genesis : Config) (next : Platform) (env : List UInt8) :
    List UInt8 × List UInt8 × List UInt8 := (key, wireEncode (installOf genesis next env), env)

theorem toy_admits (host : NativeHost.Config) (genesis : Config) (key env : List UInt8)
    (verified : List (List UInt8 × List UInt8 × List UInt8)) (h : History)
    (recorded : verdictFor key genesis { h.current with version := h.current.version + 1 } env ∈ verified)
    (valid : h.current.valid = true) :
    Admits (toyContext (toyDeployment host genesis key verified)) h
      (installOf genesis { h.current with version := h.current.version + 1 } env) := by
  refine ⟨rfl, ?_, ?_, by simp [installOf], ?_, ?_⟩
  · simp only [toyContext, Deployment.verifies, Deployment.controller, toyDeployment, if_pos rfl]
    exact decide_eq_true recorded
  · simp [toyContext, toyDeployment, Deployment.controller]
  · simpa [installOf, Platform.valid] using valid
  · simp only [installOf]
    cases h.current.completionCustodianKey with
    | none => trivial
    | some k => exact Or.inl rfl

/-- Premise inhabitation: for every deployment whose genesis record is valid, a reachable
two-record history with an admitted install on it exists. -/
theorem premises_inhabited (host : NativeHost.Config) (genesis : Config) (key : List UInt8)
    (valid : (genesisRecord host).valid = true) :
    ∃ verified h i, Reachable (toyContext (toyDeployment host genesis key verified)) h ∧
      2 ≤ h.records.length ∧ Admits (toyContext (toyDeployment host genesis key verified)) h i := by
  let g := genesisRecord host
  let r1 : Platform := { g with version := g.version + 1 }
  let h1 : History := ⟨g, [r1]⟩
  have cur1 : h1.current = r1 := rfl
  let r2 : Platform := { h1.current with version := h1.current.version + 1 }
  let verified := [verdictFor key genesis r1 [1], verdictFor key genesis r2 [2]]
  have g0 : Reachable (toyContext (toyDeployment host genesis key verified)) ⟨g, []⟩ :=
    .genesis valid
  have first := toy_admits host genesis key [1] verified ⟨g, []⟩ (by simp [verified, r1, History.current, History.records]) valid
  refine ⟨verified, h1, installOf genesis r2 [2], .install _ _ g0 first, by simp [h1, History.records], ?_⟩
  exact toy_admits host genesis key [2] verified h1 (by simp [verified, r2])
    (by rw [cur1]; simpa [r1, Platform.valid] using valid)

/-- Teeth: a request whose envelope the verifier did not record under the controller's key
is refused, whatever its subject field says. -/
theorem forged_refused (ctx : Context) (h : History) (i : Install)
    (forged : ctx.deployment.verifies ctx.deployment.controller (ctx.encode i) i.envelope = false) :
    ¬ Admits ctx h i := by
  rintro ⟨-, verified, -⟩
  simp [forged] at verified

/-- Teeth (relay swap): with the codec covering the record, a relay that keeps the
controller's envelope and changes any field of the record is refused, because the verdict
was recorded for the original bytes only. -/
theorem relay_swap_refused (host : NativeHost.Config) (genesis : Config) (key env : List UInt8)
    (h : History) (next swapped : Platform) (differs : swapped ≠ next) :
    ¬ Admits (toyContext (toyDeployment host genesis key [verdictFor key genesis next env])) h
      (installOf genesis swapped env) := by
  apply forged_refused
  have ne : wireEncode (installOf genesis swapped env) ≠ wireEncode (installOf genesis next env) :=
    fun same => differs (wireEncode_covers _ _ same).1
  simp [toyContext, Deployment.verifies, Deployment.controller, toyDeployment, verdictFor, ne]

/-- Teeth: a receiver that trusts the subject field (no signature check) does not decide
`Admits`. -/
def trustsSubjectField (ctx : Context) (h : History) (i : Install) : Bool :=
  decide (i.subject = ctx.deployment.controller) &&
    decide (h.current.version < i.next.version) && i.next.valid

theorem trustsSubjectField_not_decides (host : NativeHost.Config) (genesis : Config)
    (key : List UInt8) (valid : (genesisRecord host).valid = true) :
    ¬ Decides (toyContext (toyDeployment host genesis key []))
      (trustsSubjectField (toyContext (toyDeployment host genesis key []))) := by
  intro decides
  let h : History := ⟨genesisRecord host, []⟩
  let i := installOf genesis { h.current with version := h.current.version + 1 } []
  have admitted := (decides h i).mp (by
    simp only [trustsSubjectField, i, installOf, toyContext, Deployment.controller,
      Bool.and_eq_true, decide_eq_true_eq]
    exact ⟨⟨rfl, Nat.lt_succ_self _⟩, by
      simpa [Platform.valid, h, History.current, History.records] using valid⟩)
  exact forged_refused _ _ _ (by
    simp [toyContext, Deployment.verifies, Deployment.controller, toyDeployment]) admitted

theorem stale_version_refused (ctx : Context) (h : History) (i : Install)
    (stale : i.next.version ≤ h.current.version) : ¬ Admits ctx h i :=
  fun admitted => absurd admitted.2.2.2.1 (Nat.not_lt.mpr stale)

theorem invalid_refused (ctx : Context) (h : History) (i : Install) (invalid : i.next.valid = false) :
    ¬ Admits ctx h i := by
  rintro ⟨-, -, -, -, valid, -⟩
  simp [invalid] at valid

theorem zero_lifetime_invalid (p : Platform) (zero : p.lifetime = 0) : p.valid = false := by
  simp [Platform.valid, zero]

/-- Teeth: a named custodian key is never dropped. -/
theorem custodian_drop_refused (ctx : Context) (h : History) (i : Install) (key : List UInt8)
    (named : h.current.completionCustodianKey = some key)
    (dropped : i.next.completionCustodianKey = none) : ¬ Admits ctx h i := by
  rintro ⟨-, -, -, -, -, step⟩
  rw [named, dropped] at step
  exact step

/-- Teeth: a rotation (`some a → some b`, `a ≠ b`) without the custodian's cosignature is
refused. -/
theorem uncosigned_rotation_refused (ctx : Context) (h : History) (i : Install) (a b : List UInt8)
    (named : h.current.completionCustodianKey = some a)
    (rotated : i.next.completionCustodianKey = some b) (differs : a ≠ b)
    (uncosigned : i.custodianCosign = none) : ¬ Admits ctx h i := by
  rintro ⟨-, -, -, -, -, step⟩
  rw [named, rotated] at step
  rcases step with same | ⟨s, cosigned, -⟩
  · exact differs same
  · rw [uncosigned] at cosigned; cases cosigned

/-- Satisfiable: a rotation cosigned by the current custodian is admitted. -/
theorem cosigned_rotation_admitted (host : NativeHost.Config) (genesis : Config)
    (key env old new cosig : List UInt8) (h : History) (next : Platform)
    (named : h.current.completionCustodianKey = some old)
    (nextKey : next.completionCustodianKey = some new)
    (above : h.current.version < next.version) (valid : next.valid = true) :
    Admits (toyContext (toyDeployment host genesis key
      [(key, wireEncode ⟨next, genesis.factoryController.subject, ⟨0⟩, env, some cosig⟩, env),
       (old, wireEncode ⟨next, genesis.factoryController.subject, ⟨0⟩, env, some cosig⟩, cosig)]))
      h ⟨next, genesis.factoryController.subject, ⟨0⟩, env, some cosig⟩ := by
  refine ⟨rfl, ?_, ?_, above, valid, ?_⟩
  · simp [toyContext, Deployment.verifies, Deployment.controller, toyDeployment]
  · simp [toyContext, toyDeployment, Deployment.controller]
  · simp only [toyContext, named, nextKey]
    exact Or.inr ⟨cosig, rfl, by simp [Deployment.verifiesKey, toyDeployment]⟩

/-- Teeth: `Sorted` is load-bearing. On the unsorted record list `[5, 1]` an install at 2
is admitted although it is not above 5, so `VersionMonotone` needs reachability. -/
theorem sorted_load_bearing (host : NativeHost.Config) (genesis : Config) (key : List UInt8)
    (base : Platform) (valid : base.valid = true) :
    let h : History := ⟨{ base with version := 5 }, [{ base with version := 1 }]⟩
    let next : Platform := { h.current with version := h.current.version + 1 }
    Admits (toyContext (toyDeployment host genesis key [verdictFor key genesis next []])) h
        (installOf genesis next []) ∧
      ¬ ∀ p ∈ h.records, p.version < next.version := by
  intro h next
  refine ⟨toy_admits host genesis key [] _ h (by simp [next]) (by simpa [h, History.current,
    History.records, Platform.valid] using valid), ?_⟩
  intro above
  have := above { base with version := 5 } (by simp [h, History.records])
  simp [next, h, History.current, History.records] at this

/-- Births, satisfiable: the reader of the store's own platform reads current. -/
def currentReader {Store : Type} (view : BirthView Store) (store : Store) : Option Terms :=
  (view.platformAt store).map (termsAt · (view.heightOf store))

theorem currentReader_reads_current {Store : Type} (view : BirthView Store) :
    BirthsReadCurrent view (currentReader view) (fun _ => [view.platformCell]) := by
  intro store
  unfold currentReader
  cases view.platformAt store <;> simp

def historyView : BirthView (History × Nat) := ⟨fun s => some s.1.current, (·.2), 0⟩

def paidRecord : Platform := ⟨1, ⟨1, 0, 0, 0, 0, 0⟩, none, none, 0, 1⟩
def freeRecord : Platform := ⟨0, ⟨0, 0, 0, 0, 0, 0⟩, none, none, 0, 1⟩

/-- Births, teeth: a reader of the GENESIS record does not read current once an install
changed the creation tariff. -/
def genesisReader (s : History × Nat) : Option Terms := some (termsAt s.1.genesis s.2)

theorem genesisReader_stale :
    ¬ BirthsReadCurrent historyView genesisReader (fun _ => [0]) := by
  intro reads
  have := (reads (⟨freeRecord, [paidRecord]⟩, 0)).1
  simp [genesisReader, historyView, termsAt, History.current, History.records, paidRecord,
    freeRecord] at this

/-- Births, teeth: a reader that prices without a platform cell is refused by the statement. -/
theorem pricing_without_platform_refused {Store : Type} (view : BirthView Store) (store : Store)
    (missing : view.platformAt store = none) (t : Terms)
    (guards : Store → List Nat) (terms : Store → Option Terms) (priced : terms store = some t) :
    ¬ BirthsReadCurrent view terms guards := by
  intro reads
  have := reads store
  rw [missing] at this
  rw [priced] at this
  cases this

/-- Quote, satisfiable: the deployed quote over the store's own platform. -/
def currentQuote {Store : Type} {registry : TypeRegistry Digest} (view : BirthView Store)
    (store : Store) (d : Descriptor registry) : Option Nat :=
  (view.platformAt store).map fun p => d.quotedFee p.creation

theorem currentQuote_current {Store : Type} {registry : TypeRegistry Digest}
    (view : BirthView Store) : BirthQuoteCurrent (registry := registry) view (currentQuote view) :=
  fun _ _ => rfl

/-- Quote, teeth: a quote over the genesis tariff is stale once an install raised the base. -/
def genesisQuote {registry : TypeRegistry Digest} (s : History × Nat) (d : Descriptor registry) :
    Option Nat := some (d.quotedFee s.1.genesis.creation)

theorem genesisQuote_stale {registry : TypeRegistry Digest} (d : Descriptor registry) :
    ¬ BirthQuoteCurrent historyView (genesisQuote (registry := registry)) := by
  intro current
  have := current (⟨freeRecord, [paidRecord]⟩, 0) d
  simp [genesisQuote, historyView, History.current, History.records, paidRecord, freeRecord,
    Descriptor.quotedFee] at this

/-! ## M2: the seed-meter refill

The meter is the commit protocol's `Snapshot.available`, not a cell. Today `install` sets
`available := available - exactCharge` and no intent can raise it; the proof phase adds
`Intent.credit` (default zero) and `installAvailable` below is the extended install's meter.
Only the refill family sets a nonzero credit; its exact charge is zero (a nullifier-only
intent, which `preflight` admits), so it is admitted at an exhausted meter. -/

inductive Family
  | meterRefill
  | platformInstall
  | other (tag : Nat)
  deriving DecidableEq, Repr

/-- Durable nullifiers carry their family, so families never collide. -/
structure Nullifier where
  family : Family
  subject : SubjectId
  nonce : Nat
  deriving DecidableEq, Repr

/-- What the meter reads of a commit-protocol intent, with the proof phase's credit. -/
structure MeterIntent where
  family : Family
  exactCharge : ResourceCost.Charge
  credit : ResourceCost.Charge
  nullifiers : List Nullifier

/-- The extended install's meter. -/
def installAvailable (available : ResourceCost.Charge) (intent : MeterIntent) : ResourceCost.Charge :=
  fun lane => available lane - intent.exactCharge lane + intent.credit lane

/-- **M2-a, conservation with credit** (the extended `install_exact_debit`): a funded
install debits the charge and adds the credit, exactly. -/
theorem install_conserves_with_credit (available : ResourceCost.Charge) (intent : MeterIntent)
    (funded : intent.exactCharge ≤ available) :
    intent.exactCharge + installAvailable available intent = available + intent.credit := by
  funext lane
  change intent.exactCharge lane + (available lane - intent.exactCharge lane + intent.credit lane) =
    available lane + intent.credit lane
  have := (ResourceCost.Charge.le_iff _ _).mp funded lane
  omega

/-- Teeth: today's install (credit ignored) does not conserve a positive credit. -/
def installToday (available : ResourceCost.Charge) (intent : MeterIntent) : ResourceCost.Charge :=
  fun lane => available lane - intent.exactCharge lane

theorem installToday_loses_credit (available : ResourceCost.Charge) (intent : MeterIntent)
    (funded : intent.exactCharge ≤ available)
    (lane : ResourceCost.Lane) (positive : 0 < intent.credit lane) :
    intent.exactCharge + installToday available intent ≠ available + intent.credit := by
  intro same
  have := congrFun same lane
  change intent.exactCharge lane + (available lane - intent.exactCharge lane) =
    available lane + intent.credit lane at this
  have := (ResourceCost.Charge.le_iff _ _).mp funded lane
  omega

structure Refill where
  subject : SubjectId
  capability : CapabilityId
  nonce : Nat
  envelope : List UInt8
  amount : ResourceCost.Charge

def Refill.nullifier (r : Refill) : Nullifier := ⟨.meterRefill, r.subject, r.nonce⟩

/-- The refill's intent: no charge, the posting as credit, one tagged nullifier. -/
def Refill.intent (r : Refill) : MeterIntent := ⟨.meterRefill, 0, r.amount, [r.nullifier]⟩

def raised (remaining amount : ResourceCost.Charge) : ResourceCost.Charge :=
  fun lane => remaining lane + amount lane

theorem installAvailable_refill (remaining : ResourceCost.Charge) (r : Refill) :
    installAvailable remaining r.intent = raised remaining r.amount := by
  funext lane
  simp [installAvailable, Refill.intent, raised]

/-- The meter as the commit protocol holds it. -/
structure Meter where
  remaining : ResourceCost.Charge
  consumed : Nullifier → Bool

structure RefillContext where
  deployment : Deployment
  encode : Refill → List UInt8
  covers : ∀ r s, encode r = encode s →
    r.subject = s.subject ∧ r.capability = s.capability ∧ r.nonce = s.nonce ∧ r.amount = s.amount
  /-- The meter's fixed-width artifact layout (`ResourceCost.WordLayout`). -/
  layout : ResourceCost.WordLayout

def RefillAdmits (ctx : RefillContext) (m : Meter) (r : Refill) : Prop :=
  r.subject = ctx.deployment.controller ∧
    ctx.deployment.verifies ctx.deployment.controller (ctx.encode r) r.envelope = true ∧
    ctx.deployment.holdsRefill ctx.deployment.controller r.capability = true ∧
    m.consumed r.nullifier = false ∧
    ctx.layout.fitsCheck (raised m.remaining r.amount) = true

instance (ctx : RefillContext) (m : Meter) (r : Refill) : Decidable (RefillAdmits ctx m r) := by
  unfold RefillAdmits; infer_instance

/-- **M2-b, credit has an admitted refill behind it.** Over the intents a deployment commits
(`committed`: every `Receiving.Family.intent` with `credit := 0`, and the refill receiver's),
a nonzero credit IS the intent of a refill admitted on some meter. The family label alone
grants nothing. -/
def CreditConfined (ctx : RefillContext) (committed : MeterIntent → Prop) : Prop :=
  ∀ intent, committed intent → intent.credit ≠ 0 → ∃ m r, RefillAdmits ctx m r ∧ intent = r.intent

/-- Satisfiable: committing only admitted refills' intents is confined. -/
theorem admitted_refills_confined (ctx : RefillContext) :
    CreditConfined ctx (fun intent => ∃ m r, RefillAdmits ctx m r ∧ intent = r.intent) :=
  fun _ behind _ => behind

/-- Teeth: an intent tagged `.meterRefill` with a credit and no refill behind it (no
nullifier, which every refill intent carries) is not confined. -/
theorem tagged_mint_refused (ctx : RefillContext) (minted : MeterIntent)
    (noNullifier : minted.nullifiers = []) (lane : ResourceCost.Lane)
    (positive : 0 < minted.credit lane) :
    ¬ CreditConfined ctx (fun intent => intent = minted) := by
  intro confined
  obtain ⟨m, r, -, same⟩ := confined minted rfl (fun zero => by
    have := congrFun zero lane
    simp at this; omega)
  have := congrArg MeterIntent.nullifiers same
  rw [noNullifier] at this
  simp [Refill.intent] at this

/-- The post-state of an admitted refill: the extended install of its intent. -/
def refilled (m : Meter) (r : Refill) : Meter :=
  ⟨installAvailable m.remaining r.intent, fun n => decide (n = r.nullifier) || m.consumed n⟩

/-- **M2-c.** A lawful refill receiver admits exactly `RefillAdmits` and yields the extended
install of the refill's intent. -/
def RefillLawful (ctx : RefillContext) (post : Meter → Refill → Option Meter) : Prop :=
  ∀ m r, (RefillAdmits ctx m r → post m r = some (refilled m r)) ∧
    (¬ RefillAdmits ctx m r → post m r = none)

def refillReference (ctx : RefillContext) (m : Meter) (r : Refill) : Option Meter :=
  if RefillAdmits ctx m r then some (refilled m r) else none

theorem refillReference_lawful (ctx : RefillContext) : RefillLawful ctx (refillReference ctx) :=
  fun m r => ⟨fun ok => by simp [refillReference, ok], fun no => by simp [refillReference, no]⟩

/-- Liveness: the refill's zero charge is funded by an exhausted meter. -/
theorem refill_funded_at_exhaustion (r : Refill) :
    ResourceCost.Charge.fundedCheck r.intent.exactCharge 0 = true := by
  simp [Refill.intent]

/-- Teeth of the exemption: charged like an ordinary record, a refill is refused at the
exhausted meter. -/
theorem charged_refill_refused_at_exhaustion (c : ResourceCost.Charge)
    (positive : 0 < c .turnBytes) : ResourceCost.Charge.fundedCheck c 0 = false := by
  cases h : ResourceCost.Charge.fundedCheck c 0 with
  | false => rfl
  | true =>
      have := ((ResourceCost.Charge.fundedCheck_eq_true_iff c 0).mp h) .turnBytes
      simp at this; omega

/-- One refill never lowers a lane. -/
theorem lawful_monotone (ctx : RefillContext) (post : Meter → Refill → Option Meter)
    (lawful : RefillLawful ctx post) (m next : Meter) (r : Refill)
    (admitted : post m r = some next) : ∀ lane, m.remaining lane ≤ next.remaining lane := by
  intro lane
  by_cases ok : RefillAdmits ctx m r
  · rw [(lawful m r).1 ok] at admitted
    cases admitted
    simp [refilled, installAvailable, Refill.intent]
  · rw [(lawful m r).2 ok] at admitted
    cases admitted

/-- Replay: a consumed refill nullifier is refused. -/
theorem replay_refused (ctx : RefillContext) (post : Meter → Refill → Option Meter)
    (lawful : RefillLawful ctx post) (m : Meter) (r : Refill) (spent : m.consumed r.nullifier = true) :
    post m r = none :=
  (lawful m r).2 fun admitted => by
    have fresh := admitted.2.2.2.1
    rw [spent] at fresh
    cases fresh

/-- The family tag separates: another family's nullifier on the same subject and nonce is
not the refill's. -/
theorem family_tag_separates (r : Refill) (family : Family) (other : family ≠ .meterRefill) :
    r.nullifier ≠ ⟨family, r.subject, r.nonce⟩ := by
  intro same
  exact other (congrArg Nullifier.family same).symm

/-- Overflow: a refill whose raised meter does not fit the layout is refused. -/
theorem overflow_refused (ctx : RefillContext) (post : Meter → Refill → Option Meter)
    (lawful : RefillLawful ctx post) (m : Meter) (r : Refill) (lane : ResourceCost.Lane)
    (overflow : ctx.layout.capacity lane ≤ m.remaining lane + r.amount lane) :
    post m r = none := by
  apply (lawful m r).2
  rintro ⟨-, -, -, -, fits⟩
  have := ((ResourceCost.WordLayout.fitsCheck_eq_true_iff _ _).mp fits) lane
  simp [raised] at this
  omega

/-! ## M2: the copy is the protocol's install

`installAvailable`, `Meter` and the tagged `Nullifier` are the SPEC; the protocol is
`DurableCommitProtocol.Snapshot.install`, instantiated at the tagged `Nullifier`. Today's
install equals the spec at zero credit (proved); the proof phase's install, carrying
`Intent.credit`, must equal it at every credit (`ProtocolInstallMatches`), and then a
refill's meter IS the protocol's post-state (`refilled_is_protocol_install`). -/

def meterIntentOf {TxId CellId Event : Type} (family : Family) (credit : ResourceCost.Charge)
    (intent : DurableCommitProtocol.Intent TxId CellId Nullifier Event) : MeterIntent :=
  ⟨family, intent.exactCharge, credit, intent.nullifiers⟩

def meterOf {TxId CellId Event : Type}
    (snapshot : DurableCommitProtocol.Snapshot TxId CellId Nullifier Event) : Meter :=
  ⟨snapshot.available, snapshot.consumed⟩

theorem protocol_install_is_spec_at_zero_credit {TxId CellId Event : Type} [DecidableEq CellId]
    (before : DurableCommitProtocol.Snapshot TxId CellId Nullifier Event)
    (intent : DurableCommitProtocol.Intent TxId CellId Nullifier Event) (family : Family) :
    (DurableCommitProtocol.Snapshot.install before intent).available =
        installAvailable before.available (meterIntentOf family 0 intent) ∧
      (DurableCommitProtocol.Snapshot.install before intent).consumed =
        fun n => decide (n ∈ intent.nullifiers) || before.consumed n := by
  constructor
  · funext lane
    simp [DurableCommitProtocol.Snapshot.install, installAvailable, meterIntentOf]
  · funext n
    by_cases member : n ∈ intent.nullifiers <;>
      simp [DurableCommitProtocol.Snapshot.install, member]

/-- **M2-d, the proof phase's install is the spec.** `installed` is the extended protocol's
meter (`fun b i => (Snapshot.install b i).available` once `Intent` carries `credit`),
`creditOf` the new field. -/
def ProtocolInstallMatches {TxId CellId Event : Type}
    (installed : DurableCommitProtocol.Snapshot TxId CellId Nullifier Event →
      DurableCommitProtocol.Intent TxId CellId Nullifier Event → ResourceCost.Charge)
    (creditOf : DurableCommitProtocol.Intent TxId CellId Nullifier Event → ResourceCost.Charge) :
    Prop :=
  ∀ before intent family,
    installed before intent = installAvailable before.available (meterIntentOf family (creditOf intent) intent)

/-- Satisfiable: today's install matches the spec when no intent carries credit. -/
theorem today_install_matches_zero {TxId CellId Event : Type} [DecidableEq CellId] :
    ProtocolInstallMatches (TxId := TxId) (CellId := CellId) (Event := Event)
      (fun before intent => (DurableCommitProtocol.Snapshot.install before intent).available)
      (fun _ => 0) :=
  fun before intent family => (protocol_install_is_spec_at_zero_credit before intent family).1

/-- Teeth: today's install does not match once any funded intent carries a credit, so the
refill needs the protocol extension, not a second meter. -/
theorem today_install_mismatch_with_credit {TxId CellId Event : Type} [DecidableEq CellId]
    (creditOf : DurableCommitProtocol.Intent TxId CellId Nullifier Event → ResourceCost.Charge)
    (before : DurableCommitProtocol.Snapshot TxId CellId Nullifier Event)
    (intent : DurableCommitProtocol.Intent TxId CellId Nullifier Event)
    (lane : ResourceCost.Lane) (positive : 0 < creditOf intent lane)
    (funded : intent.exactCharge ≤ before.available) :
    ¬ ProtocolInstallMatches
      (fun before intent => (DurableCommitProtocol.Snapshot.install before intent).available) creditOf := by
  intro agrees
  have := congrFun (agrees before intent .meterRefill) lane
  have le := (ResourceCost.Charge.le_iff _ _).mp funded lane
  simp [DurableCommitProtocol.Snapshot.install, installAvailable, meterIntentOf] at this
  omega

/-- The link: under a matching extended install, a refill's protocol intent (no charge,
the posting as credit, its one tagged nullifier) leaves exactly `refilled`. -/
theorem refilled_is_protocol_install {TxId CellId Event : Type} [DecidableEq CellId]
    (installed : DurableCommitProtocol.Snapshot TxId CellId Nullifier Event →
      DurableCommitProtocol.Intent TxId CellId Nullifier Event → ResourceCost.Charge)
    (creditOf : DurableCommitProtocol.Intent TxId CellId Nullifier Event → ResourceCost.Charge)
    (agrees : ProtocolInstallMatches installed creditOf)
    (before : DurableCommitProtocol.Snapshot TxId CellId Nullifier Event)
    (intent : DurableCommitProtocol.Intent TxId CellId Nullifier Event) (r : Refill)
    (free : intent.exactCharge = 0) (credited : creditOf intent = r.amount)
    (single : intent.nullifiers = [r.nullifier]) :
    (⟨installed before intent, (DurableCommitProtocol.Snapshot.install before intent).consumed⟩ : Meter) =
      refilled (meterOf before) r := by
  have available := agrees before intent .meterRefill
  have consumed := (protocol_install_is_spec_at_zero_credit before intent .meterRefill).2
  simp only [refilled, meterOf, available, consumed, single]
  congr 1
  · funext lane
    simp [installAvailable, meterIntentOf, free, credited, Refill.intent]
  · funext n
    simp

#assert_axioms lawful_injective installWire_covers wireEncode_covers toy_admits premises_inhabited
  forged_refused relay_swap_refused trustsSubjectField_not_decides stale_version_refused
  invalid_refused zero_lifetime_invalid custodian_drop_refused uncosigned_rotation_refused
  cosigned_rotation_admitted sorted_load_bearing currentReader_reads_current genesisReader_stale
  pricing_without_platform_refused currentQuote_current genesisQuote_stale
  install_conserves_with_credit installToday_loses_credit admitted_refills_confined tagged_mint_refused
  installAvailable_refill refillReference_lawful refill_funded_at_exhaustion
  charged_refill_refused_at_exhaustion lawful_monotone replay_refused family_tag_separates
  overflow_refused protocol_install_is_spec_at_zero_credit today_install_matches_zero
  today_install_mismatch_with_credit refilled_is_protocol_install
  records_push current_push chain_le_last staysSorted reachable_sorted versionMonotone recordsValid
  custodianCheck_iff decideInstall_decides decides_authenticated

end Minidregg.Kernel.PlatformCell
