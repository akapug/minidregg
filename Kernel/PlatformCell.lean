/-
# Kernel.PlatformCell -- STATEMENTS FIRST: the platform cell (GENESIS-COUPLING L1) and the
meter refill (M2)

Every one of `grainBirthTariff`, `completionCustodianKey`, the `CreationTariff` and the
factory template's `{ownerBudget, lifetime}` sits in `Config.runtimeParameters`
(`Kernel/NativeHostContext.lean:97-127`) or in `encode template`, hence in the semantics
digest every signed request pins: a world born without one of them cannot acquire it and is
reborn (`docs/review/2026-10-27-genesis-coupling/GENESIS-COUPLING.md` §A, §C L1). The
genesis `meterAllowance` is a lifetime meter every family's record debits
(`DurableCommitProtocol` refuses `insufficientBudget` at install; `Receiving.Family.charge`);
with the demo's 10^7 per lane and a measured ~1,000 `turnBytes` per signed record the world
holds about 10^4 records, which the minute clock alone spends in about seven days (§C M2).

This module holds the STATEMENTS of both repairs and nothing else, per ATLAS §6 law 2: each
keystone is a `Prop` with its satisfiable pole, its teeth and its premise-inhabitation
written beside it. No receiver, codec, cell kind or proof lives here yet; the registry
reserves the operation bytes (`PLATFORM_INSTALL_*` 240-243, `METER_REFILL_*` 244-247,
status `reserved`). The audit of these statements precedes any proof work; the proof
phase adds `CanonicalCellRegistry.Kind.platform` (law class `lawBearing`), the receivers
(the shape of `PayBookReceiver`: `tariff_version_monotone`, `genesis_change_accepted`,
`same_version_refused`), the Host arms and the client verbs.

What these statements deliberately do NOT claim: that two nodes replaying one log agree on
the platform (that is the durable-replay theorem of every cell, inherited once the
platform is a cell); that the current platform is "correct" (it is whatever the controller
installed, at the version it installed).
-/
import Theory.ResourceBirth
import Kernel.NativeHostContext
import Theory.ResourceCost
import Theory.AxiomPin

namespace Minidregg.Kernel.PlatformCell

open Minidregg.Theory.ResourceBirth (CreationTariff)
open Minidregg.Theory.TypedAuthorization (SubjectId)
open Minidregg.Theory

set_option autoImplicit false

/-! ## L1: the platform record and its three keystones -/

/-- The platform record: what today's genesis digest freezes, as one version-monotone
law-bearing cell's content. `window` is the template's `{ownerBudget, lifetime}`; the
issuer and the birth slack stay with the template (they name the authority, not a price). -/
structure Platform where
  version : Nat
  creation : CreationTariff
  grainBirth : Option NativeHost.GrainBirthTariffPin
  completionCustodianKey : Option (List UInt8)
  ownerBudget : Nat
  lifetime : Nat
  deriving DecidableEq, Repr

/-- A zero creation tariff, for the poles' witnesses. -/
def freeTariff : CreationTariff := ⟨0, 0, 0, 0, 0, 0⟩

/-- The controller-signed install request: the new record, signed by `subject`. -/
structure Install where
  subject : SubjectId
  next : Platform
  deriving DecidableEq, Repr

/-- The platform history a world carries: genesis's record first, then every admitted
install. `current` is the last one. This is the STATE the keystones quantify over; the
proof phase realises it as a cell's accepted records. -/
abbrev History := List Platform

def History.current (history : History) : Option Platform := history.getLast?

/-- The admission predicate the proof phase must realise: an install is admitted on a
history by the factory controller alone, with a version strictly above the current one and
a positive lifetime. Stated as a `def : Prop` so the three keystones below are about ONE
admission, and the receiver is proved to decide exactly it. -/
def Admits (controller : SubjectId) (history : History) (install : Install) : Prop :=
  install.subject = controller ∧
    (∀ current, history.current = some current → current.version < install.next.version) ∧
    0 < install.next.lifetime

/-- An admitted history is version-sorted: each install was admitted above the record
before it. This is the invariant the proof phase carries through every install. -/
def Sorted (history : History) : Prop := history.Chain' (fun a b => a.version < b.version)

/-- **Keystone L1-a: platform versions are strictly monotone.** On a sorted history every
admitted install's version is above EVERY record before it, not only the current one (the
shape of `PayBookReceiver.tariff_version_monotone`). PROOF PHASE: from `Sorted` and
`Admits` (every record's version is at most the last record's). -/
def VersionMonotone (controller : SubjectId) : Prop :=
  ∀ (history : History) (install : Install), Sorted history →
    Admits controller history install → ∀ p ∈ history, p.version < install.next.version

/-- **Keystone L1-b: only the controller installs.** -/
def ControllerOnly (controller : SubjectId) : Prop :=
  ∀ (history : History) (install : Install), Admits controller history install →
    install.subject = controller

/-- **Keystone L1-c: births read the current platform at their height.** `priceAt` is the
proof phase's function from a history to the creation tariff a birth is quoted; the
statement is that it reads the current record and nothing older. -/
def BirthsReadCurrent (priceAt : History → Option CreationTariff) : Prop :=
  ∀ history current, history.current = some current → priceAt history = some current.creation

/-! ### Poles (ATLAS law 2): satisfiable, teeth, premise-inhabitation -/

/-- Satisfiable: on a history of one genesis record, the controller's install at version
1 is admitted (`genesis_change_accepted`'s shape). -/
def InstallSatisfiable (controller : SubjectId) : Prop :=
  ∃ (genesis next : Platform), genesis.version = 0 ∧ next.version = 1 ∧ 0 < next.lifetime ∧
    Admits controller [genesis] ⟨controller, next⟩

/-- Teeth: the same version again is refused (`same_version_refused`'s shape), and a
non-controller's install is refused whatever its version. -/
def InstallTeeth (controller : SubjectId) : Prop :=
  (∀ (history : History) (current : Platform) (next : Platform),
      history.current = some current → next.version ≤ current.version →
      ¬ Admits controller history ⟨controller, next⟩) ∧
  (∀ (history : History) (other : SubjectId) (next : Platform), other ≠ controller →
      ¬ Admits controller history ⟨other, next⟩)

/-- Premise-inhabitation: a history with a current record exists, so `VersionMonotone` and
`BirthsReadCurrent` are not vacuous over empty histories. -/
def HistoryInhabited : Prop := ∃ (history : History) (current : Platform), history.current = some current

/-- What follows from the admission STATEMENT alone (not from a receiver): the controller
pole, both teeth, the satisfiable pole and the inhabited premise. `VersionMonotone` is the
proof phase's (it needs the sorted-history invariant). The receiver's theorem, then, is
`decide … = .ok ↔ Admits …`. -/
theorem keystones_of_admits (controller : SubjectId) :
    ControllerOnly controller ∧
      InstallSatisfiable controller ∧ InstallTeeth controller ∧ HistoryInhabited := by
  refine ⟨?_, ?_, ⟨?_, ?_⟩, ?_⟩
  · intro history install admitted
    exact admitted.1
  · refine ⟨⟨0, freeTariff, none, none, 0, 1⟩, ⟨1, freeTariff, none, none, 0, 1⟩,
      rfl, rfl, Nat.one_pos, rfl, ?_, Nat.one_pos⟩
    intro current present
    simp [History.current] at present
    subst present
    exact Nat.one_pos
  · intro history current next present stale admitted
    exact absurd (admitted.2.1 current present) (Nat.not_lt.mpr stale)
  · intro history other next differs admitted
    exact differs admitted.1
  · exact ⟨[⟨0, freeTariff, none, none, 0, 1⟩], _, rfl⟩

/-! ### The receiver obligation (what the proof phase proves of the real receiver)

`Decides decide` says a receiver's admission function is exactly `Admits`. Its teeth: a
receiver that ignores the signer (admits any subject) does not satisfy it. -/

def Decides (controller : SubjectId) (decide : History → Install → Bool) : Prop :=
  ∀ history install, decide history install = true ↔ Admits controller history install

/-- A wrong receiver: version and lifetime checked, signer ignored. -/
def ignoresSigner (history : History) (install : Install) : Bool :=
  (match history.current with
   | some current => decide (current.version < install.next.version)
   | none => true) && decide (0 < install.next.lifetime)

theorem ignoresSigner_not_decides (controller other : SubjectId) (differs : other ≠ controller) :
    ¬ Decides controller ignoresSigner := by
  intro decides
  have admitted := (decides [] ⟨other, ⟨1, freeTariff, none, none, 0, 1⟩⟩).mp
    (by simp [ignoresSigner, History.current])
  exact differs admitted.1

/-! ## M2: the meter refill

The seed meter is a `ResourceCost.Charge` (ten lanes) every admitted record debits
(`DurableCommitProtocol.preflight` refuses `insufficientBudget`). A refill is a
controller-signed posting that ADDS to the remaining allowance lane by lane; lowering a
lane is not this family. -/

structure Refill where
  subject : SubjectId
  amount : ResourceCost.Charge

/-- The post-state a refill must produce. -/
def raised (remaining : ResourceCost.Charge) (refill : Refill) : ResourceCost.Charge :=
  fun lane => remaining lane + refill.amount lane

/-- **Keystone M2.** A receiver `post` (remaining allowance, refill ↦ new remaining, or
refused) is lawful when it admits exactly the controller's refills and then yields
`raised`: never a lower lane, never another lane moved, never a non-controller. -/
def RefillLawful (controller : SubjectId)
    (post : ResourceCost.Charge → Refill → Option ResourceCost.Charge) : Prop :=
  ∀ remaining refill,
    (refill.subject = controller → post remaining refill = some (raised remaining refill)) ∧
    (refill.subject ≠ controller → post remaining refill = none)

/-- The reference receiver the proof phase realises. -/
def refillReference (controller : SubjectId)
    (remaining : ResourceCost.Charge) (refill : Refill) : Option ResourceCost.Charge :=
  if refill.subject = controller then some (raised remaining refill) else none

/-- Satisfiable: the reference receiver is lawful. -/
theorem refillReference_lawful (controller : SubjectId) :
    RefillLawful controller (refillReference controller) := by
  intro remaining refill
  constructor
  · intro signed; simp [refillReference, signed]
  · intro other; simp [refillReference, other]

/-- Monotone consequence: under a lawful receiver no lane ever drops. -/
theorem lawful_monotone (controller : SubjectId)
    (post : ResourceCost.Charge → Refill → Option ResourceCost.Charge)
    (lawful : RefillLawful controller post) (remaining next : ResourceCost.Charge) (refill : Refill)
    (admitted : post remaining refill = some next) : ∀ lane, remaining lane ≤ next lane := by
  intro lane
  by_cases signed : refill.subject = controller
  · rw [(lawful remaining refill).1 signed] at admitted
    cases admitted
    exact Nat.le_add_right _ _
  · rw [(lawful remaining refill).2 signed] at admitted
    cases admitted

/-- Teeth: a receiver that REPLACES the meter by the posting (instead of adding) is not
lawful whenever something remains, and one that admits any signer is not lawful. -/
def replaces (remaining : ResourceCost.Charge) (refill : Refill) : Option ResourceCost.Charge :=
  some refill.amount

theorem replaces_not_lawful (controller : SubjectId) : ¬ RefillLawful controller replaces := by
  intro lawful
  have h := (lawful (fun _ => 1) ⟨controller, fun _ => 0⟩).1 rfl
  have := congrFun (Option.some.inj h) .turnBytes
  simp [raised] at this

def anySigner (remaining : ResourceCost.Charge) (refill : Refill) : Option ResourceCost.Charge :=
  some (raised remaining refill)

theorem anySigner_not_lawful (controller other : SubjectId) (differs : other ≠ controller) :
    ¬ RefillLawful controller anySigner := by
  intro lawful
  have := (lawful (fun _ => 0) ⟨other, fun _ => 0⟩).2 differs
  simp [anySigner] at this

#assert_axioms keystones_of_admits ignoresSigner_not_decides refillReference_lawful lawful_monotone replaces_not_lawful anySigner_not_lawful

end Minidregg.Kernel.PlatformCell
