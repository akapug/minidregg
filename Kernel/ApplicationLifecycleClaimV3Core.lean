/-
Conditional current claim for an exact launch-bound BEGIN. The original v3
BEGIN is re-admitted at its prefix and matched in full; current management,
app/package policy and signed observations are checked on the same tip. A
first-create claim atomically consumes the stable first-attempt marker. This
lower module does not certify the original BEGIN's membership in Verified or
the successful prior-create completion required for `continue`.
-/
module

public import Kernel.ApplicationLifecycleClaimV3Ingress
public import Kernel.ApplicationLifecycleBeginV3Admission
public import Kernel.ApplicationLifecycleClaimCore

-- Bodies this file reduces or derives through, not exposed by their modules (module system).
import all Init.Data.Repr
import all Init.Data.ToString.Basic
import all Init.Data.ToString.Extra
import all Init.Data.Array.Basic
import all Init.Data.ByteArray.Basic
import all Init.Data.String.Decode
import all Init.Data.String.Defs
import all Init.Control.Except
import all Init.Data.List.Basic
import all Init.Data.Nat.Bitwise.Basic
import all Init.Data.String.Bootstrap
import all Init.Data.Format.Basic
import all Init.Data.List.Scan.Basic
import all Init.System.ST
import all Init.System.IO

@[expose] public section

namespace Minidregg.Kernel.ApplicationLifecycleClaimV3Core

open Minidregg.Compiler
open Minidregg.Compiler.ResourceBirthCodec
open Minidregg.Theory
open Minidregg.Theory.IndexedProgram
open Minidregg.Kernel.DurableDataIntent
open Minidregg.Kernel.NativeHost
open Minidregg.Kernel.ApplicationLifecycleClaimV3Ingress

set_option autoImplicit false

open Minidregg.Compiler.ServedBasis (Ground Grounded)
open Minidregg.Compiler.DurableHistory (Head StoreIdentity)
open Minidregg.Compiler.DurableHistoryReader (Reader)

/-- The nullifiers the claim reads from the spent map on the current ground. -/
def markerNullifiers (ingress : Ingress) : List StableNullifier :=
  ApplicationLifecycleBeginV3Admission.markerNullifiersOf ingress.base.domain
    ingress.originalBegin.start

/-- Every key the current part of a v3 claim reads. -/
def keys (ingress : Ingress) : DurableView.Keys :=
  let current := ApplicationLifecycleClaimCurrent.keys ingress.base
  ⟨current.transactions, current.nullifiers ++ markerNullifiers ingress⟩

/-- The ground answers every marker the claim reads. -/
def markersDeclared {deployment : CanonicalCellRegistry.Deployment} (ground : Ground deployment)
    (ingress : Ingress) : Bool :=
  ApplicationLifecycleBeginV3Admission.markersDeclaredOf ground ingress.base.domain
    ingress.originalBegin.start

/-- The claim's markers are the launch binding's: a first create must find neither
consumed, a continue must find the created marker. -/
def markersCurrent {deployment : CanonicalCellRegistry.Deployment} (ground : Ground deployment)
    (ingress : Ingress) : Bool :=
  ApplicationLifecycleBeginV3Admission.markersCurrentOf ground ingress.base.domain
    ingress.originalBegin.start

theorem consumed_first_attempt_refuses_create {deployment : CanonicalCellRegistry.Deployment}
    (ground : Ground deployment) (ingress : Ingress)
    (binding : ApplicationLifecycleLaunchBinding.Binding) (index : Nat)
    (selected : ingress.originalBegin.start = some binding)
    (choice : binding.choice = .create index)
    (consumed : ground.view.model.consumed
      (ApplicationLifecycleClaimV3Ingress.firstAttemptNullifier
        ingress.base.domain binding) = true) :
    markersCurrent ground ingress = false := by
  simp [markersCurrent, ApplicationLifecycleBeginV3Admission.markersCurrentOf, selected, choice, consumed]

/-- **An undeclared claim marker refuses** (the pole of a silent "unconsumed"). -/
theorem undeclared_marker_refuses {deployment : CanonicalCellRegistry.Deployment}
    (ground : Ground deployment) (ingress : Ingress)
    (marker : StableNullifier) (member : marker ∈ markerNullifiers ingress)
    (undeclared : ground.declaresNullifier marker = false) :
    markersCurrent ground ingress = false := by
  have : markersDeclared ground ingress = false := by
    unfold markersDeclared ApplicationLifecycleBeginV3Admission.markersDeclaredOf
    exact List.all_eq_false.mpr ⟨marker, member, by simp [undeclared]⟩
  simp [markersDeclared, ApplicationLifecycleBeginV3Admission.markersDeclaredOf] at this
  simp [markersCurrent, ApplicationLifecycleBeginV3Admission.markersCurrentOf,
    ApplicationLifecycleBeginV3Admission.markersDeclaredOf, this]

structure Conditional (config : Config) {store : StoreIdentity} (head : Head store)
    (ground : Ground config.deployment) (ingress : Ingress) where
  private mk ::
  sourceExact : ingress.originalExact = true
  original : NativeHistorySelection.Candidate config head
    ingress.base.source.originalIndex
  originalAccepted : ApplicationLifecycleBeginV3Admission.Accepted
    config.deployment config.profile
    ⟨config.federation, config.genesisHeight + original.ground.height⟩
    original.ground ingress.originalBegin
  originalMatch : NativeHistorySelection.Matched original originalAccepted.intent
  current : ApplicationLifecycleClaimCurrent.Accepted config.deployment config.profile
    ⟨config.federation, config.genesisHeight + ground.height⟩
    ground ingress.base
  currentInstalled : ApplicationLifecycleBeginV3Admission.installedExact
    config.deployment ingress.originalBegin
    current.packageRead.selected.observed.before = true
  markers : markersCurrent ground ingress = true

theorem Conditional.original_record_exact {config : Config} {store : StoreIdentity}
    {head : Head store} {ground : Ground config.deployment}
    {ingress : Ingress} (conditional : Conditional config head ground ingress) :
    conditional.original.record =
      DurableReceiver.IntentRecord.ofIntent conditional.originalAccepted.intent := by
  exact conditional.originalMatch.selected.symm.trans conditional.originalMatch.exact

/-- The original record is the one verified under `head` at height
`ingress.base.source.originalIndex + 1` and decodes to exactly the record of the
re-admitted `ingress.originalBegin`; the ingress's original BEGIN is its claim's
source BEGIN, the claim's current world root is `ground`'s, and the package cell the
current claim observed holds `ingress.originalBegin`'s installed descriptor under
`config`, and the retry/first-attempt markers are current at `ground`. -/
theorem Conditional.original_under_head {config : Config} {store : StoreIdentity}
    {head : Head store} {ground : Ground config.deployment}
    {ingress : Ingress} (conditional : Conditional config head ground ingress) :
    (∃ bytes chain root,
      DurableHistory.Included head.frontier head.height (ingress.base.source.originalIndex + 1) bytes chain root ∧
        DurableCheckpointCodec.recordFrame.decode bytes =
          some (DurableReceiver.IntentRecord.ofIntent conditional.originalAccepted.intent)) ∧
      ingress.originalExact = true ∧
      ingress.base.source.currentWorldRoot = ground.worldRoot ∧
      ApplicationLifecycleBeginV3Admission.installedExact config.deployment ingress.originalBegin
        conditional.current.packageRead.selected.observed.before = true ∧
      markersCurrent ground ingress = true :=
  ⟨⟨conditional.original.read.verified.record, conditional.original.read.verified.chain,
      conditional.original.read.verified.root, conditional.original.read.verified.included,
      conditional.original.read.decoded.trans (congrArg some (conditional.original.recordExact.trans
        (NativeHistorySelection.Matched.candidateRecord conditional.originalMatch)))⟩,
    conditional.sourceExact, conditional.current.boundary, conditional.currentInstalled, conditional.markers⟩

/-- The keys the historical (original) BEGIN reads on its prior state. -/
def originalKeys (ingress : Ingress) : DurableView.Keys :=
  ApplicationLifecycleBeginV3Admission.keys ingress.originalBegin

def prepare (config : Config) {store : StoreIdentity}
    (reader : Reader ResourceBirthCodec.rootBytes store)
    (grounded : Grounded config.deployment reader.head)
    (ingress : Ingress) :
    IO (Except String (Conditional config reader.head grounded.ground ingress)) := do
  let ground := grounded.ground
  if sourceExact : ingress.originalExact = true then
    let original ← match ← NativeHistorySelection.select config reader ground.height
        ingress.base.source.originalIndex (originalKeys ingress) with
      | .error detail => return .error detail
      | .ok original => pure original
    let originalAmbient : DeclaredResourceController.Ambient :=
      ⟨config.federation, config.genesisHeight + original.ground.height⟩
    let originalAccepted ← match ← ApplicationLifecycleBeginV3Admission.admitNative
        config.deployment config.profile originalAmbient config.signature
        original.ground ingress.originalBegin with
      | .error detail => return .error s!"original v3 lifecycle begin refused: {detail}"
      | .ok accepted => pure accepted
    let originalMatch ← match NativeHistorySelection.matchIntent original
        originalAccepted.intent with
      | .error detail => return .error detail
      | .ok matched => pure matched
    let ambient : DeclaredResourceController.Ambient :=
      ⟨config.federation, config.genesisHeight + ground.height⟩
    let current ← match ← ApplicationLifecycleClaimCurrent.admitLoaded
        config.deployment config.profile ambient config.signature ground
        ingress.base with
      | .error detail => return .error detail
      | .ok current => pure current
    if installed : ApplicationLifecycleBeginV3Admission.installedExact
        config.deployment ingress.originalBegin
        current.packageRead.selected.observed.before = true then
      if _declared : markersDeclared ground ingress = true then
        if markerReady : markersCurrent ground ingress = true then
          return .ok ⟨sourceExact, original, originalAccepted,
            originalMatch, current, installed, markerReady⟩
        else return .error "v3 claim first-attempt/created marker state refused"
      else return .error "v3 claim launch marker undeclared"
    else return .error "current package differs from original signed launch descriptor"
  else return .error "v3 claim original BEGIN projection differs"

def Conditional.intent {config : Config} {store : StoreIdentity} {head : Head store} {ground : Ground config.deployment}
    {ingress : Ingress} (conditional : Conditional config head ground ingress) :
    DataIntent ResourceBirthCodec.rootBytes :=
  let ordinary := ApplicationLifecycleClaimCore.intentFromCurrent conditional.current
    (event ingress) ingress.canonicalBytes.length
  match ingress.createAttempt with
  | none => ordinary
  | some marker =>
      -- One more nullifier of the same writes, guards and event: the World's
      -- storage of the turn is the ordinary intent's (no marker term).
      { ordinary with
        nullifiers := ordinary.nullifiers ++ [marker] }

theorem Conditional.intent_event {config : Config} {store : StoreIdentity} {head : Head store} {ground : Ground config.deployment}
    {ingress : Ingress} (conditional : Conditional config head ground ingress) :
    conditional.intent.event = event ingress := by
  unfold Conditional.intent
  split <;> rfl

theorem Conditional.create_intent_has_attempt {config : Config} {store : StoreIdentity} {head : Head store} {ground : Ground config.deployment}
    {ingress : Ingress} (conditional : Conditional config head ground ingress)
    (marker : StableNullifier) (selected : ingress.createAttempt = some marker) :
    marker ∈ conditional.intent.nullifiers := by
  simp [Conditional.intent, selected]

end Minidregg.Kernel.ApplicationLifecycleClaimV3Core
