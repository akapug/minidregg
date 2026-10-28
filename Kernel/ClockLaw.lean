/-
# Kernel.ClockLaw -- the clock cell's law, and the step every clock writer projects for it

The deployment's one clock (`Kernel.ClockCell`) is `lawBearing` in the registry
(`CanonicalCellRegistry.Kind.lawClass`): its committed law judges EVERY write,
whoever proposes it.  Three families write it besides the tick: a payment
observation (`PayObservationReceiver`) and the two self-enrollments
(`PayEnrolReceiver`, `PayEnrolV2Receiver`) advance it to their verified chain
tip.  Until 2026-10-05 only `ClockTickReceiver` judged the clock's law; the
other three advanced the clock under the pay or factory law alone (cv task
01a1087d-8a58, the LIVE LAW BYPASS).

This module holds, once:

* **the genesis clock law** (`clockPredicate`): the clock never goes back
  (`monotone clock/now`, `monotone clock/slot`), and it advances only by a
  ticker's `tickClock` (`tickClause`, unchanged from the CLOCK-SUBJECT law) or,
  when the deployment has a payment observer, by a payment observation
  (`observePayment` under operation `pay-observe`) or a self-enrollment
  (`installPolicy` under operation `pay-self-enrol`) (`payClauses`).  The pay
  clauses name no subject: who may observe or enrol is the pay and factory laws'
  to say (`NativeHostGenesis.payPredicate`, `confinedFactoryLaw`), which those
  families judge on their own cells, and which the controller re-installs when
  it replaces the observer (`observer_replaceable`) -- a clock law naming the
  observer could not follow that replacement, since no one holds `installPolicy`
  on the clock.  Values: unix seconds and chain slots, inside the compiler's
  input range.
* **the clock write's law step** (`step`): the writer's own signed request,
  the operation marker it was admitted under, and the clock before and after,
  as a `PolicyStepContext` built from a validated patch of the clock cell (the
  one constructor discipline: `PolicyStepContext.ofCandidate` over a semantic
  family whose patch IS the validated clock patch).

The judgement itself is not here: every writer calls
`Kernel.ReceivingLaw.judgeWrite` with the deployed `Laws.physical`, the same
function `Kernel.Receiving.Family` runs for a migrated family, so a pay family's
clock write is judged exactly as it will be after the migration.
-/
module

public import Kernel.ClockCell
public import Compiler.CanonicalPolicyAdmission
public import Compiler.CanonicalRuntimeProfileCore
public import Compiler.CredentialAuthorityEntryCodec
public import Theory.CredentialAuthorityEffects
public import Theory.PolicyInstall
public import Theory.AxiomPin

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

@[expose] public section

namespace Minidregg.Kernel.ClockLaw

open Minidregg.Compiler
open Minidregg.Compiler.CanonicalPolicyAdmission (PolicyStepContext)
open Minidregg.Theory
open Minidregg.Theory.CellState
open Minidregg.Theory.CredentialAuthorityEffects (unitCodec sealedOnly)
open Minidregg.Theory.Store (Patch)
open Minidregg.Theory.TypedAuthorization

set_option autoImplicit false

/-! ## The operations that advance the clock beside a tick -/

/-- The operation slot a payment observation projects (`= 1`). -/
def payObserveSlot : String := "authority/operation/pay-observe"

/-- The operation slot a self-enrollment projects (`= 1`); the same slot the
confined factory law reads (`NativeHostGenesis.selfEnrolSlot`). -/
def paySelfEnrolSlot : String := "authority/operation/pay-self-enrol"

def tickVerbTag : Nat := CredentialAuthorityEntryCodec.verbTag (Verb.tickClock : Verb .program)
def observeVerbTag : Nat := CredentialAuthorityEntryCodec.verbTag (Verb.observePayment : Verb .program)
def installVerbTag : Nat := CredentialAuthorityEntryCodec.verbTag (Verb.installPolicy : Verb .program)

theorem tickVerbTag_eq : tickVerbTag = 11 := rfl
theorem observeVerbTag_eq : observeVerbTag = 6 := rfl
theorem installVerbTag_eq : installVerbTag = 4 := rfl

/-! ## The law -/

/-- A ticker's tick: the verb is `tickClock` and the subject is one of the
genesis tickers (the CLOCK-SUBJECT law, unchanged). -/
def tickClause (tickers : List SubjectId) : Minidregg.Pred.Pred :=
  .all [.eq "request/verb" (Int.ofNat tickVerbTag),
    .any (tickers.map fun subject => .eq "request/subject" (Int.ofNat subject.value))]

/-- A payment observation and a self-enrollment advance the clock to their
verified tip. -/
def payClauses : List Minidregg.Pred.Pred :=
  [.all [.eq "request/verb" (Int.ofNat observeVerbTag), .eq payObserveSlot 1],
   .all [.eq "request/verb" (Int.ofNat installVerbTag), .eq paySelfEnrolSlot 1]]

/-- The verb tags the clock's controller may exercise (O61), as on the pay cell:
`observeProgram` (1, to read the cell's root, which every management plan pins),
`delegateProgram` (3), `installPolicy` (4, to name new tickers in the law) and
`revokeCapability` (5). Never `tickClock`. -/
def controlVerbTags : List Int :=
  [Int.ofNat (CredentialAuthorityEntryCodec.verbTag (Verb.observeProgram : Verb .program)),
   Int.ofNat (CredentialAuthorityEntryCodec.verbTag (Verb.delegateProgram : Verb .program)),
   Int.ofNat installVerbTag,
   Int.ofNat (CredentialAuthorityEntryCodec.verbTag (Verb.revokeCapability : Verb .program))]

/-- The step carries no clock: `slot` is absent (`eqSlots s s` holds exactly when `s` is
present, the atoms failing closed). -/
def absent (slot : String) : Minidregg.Pred.Pred := .not (.eqSlots slot slot)

/-- **The controller's management of the clock** (O61): the factory controller, a management
verb, and a step that carries no clock. A management request (an install, revocation or
delegation projected over the authority cell) has no clock slots, while every clock write
projects them (`project`), so management is never a clock write and never moves the clock:
the law says so itself, with no premise about which families write the cell
(`controlClause_clock_false`). Fail-safe premise: a management step that ever carried a
`clock/*` slot would be refused here, so the premise can only narrow management, never widen
it. -/
def controlClause (controller : SubjectId) : Minidregg.Pred.Pred :=
  .all [.eq "request/subject" (Int.ofNat controller.value),
    .memberOf "request/verb" controlVerbTags, absent "clock/now", absent "clock/slot"]

/-- **The clock cell's genesis law.**  A clock write never goes back and is a ticker's tick
or, with a payment observer, a payment observation or a self-enrollment; besides clock
writes, the factory controller may manage the clock (install the law, delegate, revoke) on
a step that carries no clock, never tick. -/
def clockPredicate (controller : SubjectId) (tickers : List SubjectId) (payWriters : Bool) :
    Minidregg.Pred.Pred :=
  .any [.all [.monotone "clock/now", .monotone "clock/slot",
      .any (tickClause tickers :: if payWriters then payClauses else [])],
    controlClause controller]

/-! ## Its meaning -/

/-- The tick clause, decided: the verb is `tickClock` and the subject a ticker. -/
theorem tickClause_eval (tickers : List SubjectId) (old new : Minidregg.Pred.State)
    (subject verb : Nat)
    (named : new.get "request/subject" = some (Int.ofNat subject))
    (verbed : new.get "request/verb" = some (Int.ofNat verb)) :
    Minidregg.Pred.eval (tickClause tickers) old new = true ↔
      verb = tickVerbTag ∧ subject ∈ tickers.map (·.value) := by
  unfold Minidregg.Pred.eval tickClause
  rw [Minidregg.Pred.evalWith_all]
  simp only [List.all_cons, List.all_nil, Bool.and_true, Bool.and_eq_true]
  rw [Minidregg.Pred.evalWith_any]
  simp only [List.any_map, List.any_eq_true, Function.comp_apply, Minidregg.Pred.evalWith,
    named, verbed, decide_eq_true_eq, Option.some.injEq, Int.ofNat.injEq, List.mem_map]
  constructor
  · rintro ⟨verbExact, ticker, member, subjectExact⟩
    exact ⟨verbExact, ticker, member, subjectExact.symm⟩
  · rintro ⟨verbExact, ticker, member, subjectExact⟩
    exact ⟨verbExact, ticker, member, subjectExact.symm⟩

/-- **Management is never a clock write**: on a step whose new state carries the clock,
the controller's management clause is false. -/
theorem controlClause_clock_false (controller : SubjectId) (old new : Minidregg.Pred.State)
    (newNow : Int) (nowNew : new.get "clock/now" = some newNow) :
    Minidregg.Pred.eval (controlClause controller) old new = false := by
  unfold Minidregg.Pred.eval controlClause absent
  simp [Minidregg.Pred.evalWith, nowNew]

/-- **The clock law, decided** on a step whose old and new states carry the
clock (`now`, `slot`): it admits exactly a step that moves neither back and
is a tick by a ticker or (with pay writers) a pay operation. The controller's management
never admits a clock write (`controlClause_clock_false`). -/
theorem clockPredicate_eval (controller : SubjectId) (tickers : List SubjectId) (payWriters : Bool)
    (old new : Minidregg.Pred.State) (oldNow newNow oldSlot newSlot : Int)
    (nowOld : old.get "clock/now" = some oldNow) (nowNew : new.get "clock/now" = some newNow)
    (slotOld : old.get "clock/slot" = some oldSlot) (slotNew : new.get "clock/slot" = some newSlot) :
    Minidregg.Pred.eval (clockPredicate controller tickers payWriters) old new = true ↔
      oldNow ≤ newNow ∧ oldSlot ≤ newSlot ∧
        (Minidregg.Pred.eval (tickClause tickers) old new = true ∨
          (payWriters = true ∧ ∃ clause ∈ payClauses, Minidregg.Pred.eval clause old new = true)) := by
  unfold Minidregg.Pred.eval clockPredicate controlClause absent
  cases payWriters <;>
    simp [Minidregg.Pred.evalWith, nowOld, nowNew, slotOld, slotNew, List.any_eq_true]

/-- **The clock never goes back**, whoever writes it: a step that lowers the
slot is refused, by every writer. -/
theorem clock_refuses_slot_regress (controller : SubjectId) (tickers : List SubjectId) (payWriters : Bool)
    (old new : Minidregg.Pred.State) (oldSlot newSlot : Int)
    (slotOld : old.get "clock/slot" = some oldSlot) (slotNew : new.get "clock/slot" = some newSlot)
    (back : newSlot < oldSlot) :
    Minidregg.Pred.eval (clockPredicate controller tickers payWriters) old new = false := by
  unfold Minidregg.Pred.eval clockPredicate controlClause absent
  simp [Minidregg.Pred.evalWith, slotOld, slotNew, Int.not_le.mpr back]

/-- The same for `now`. -/
theorem clock_refuses_now_regress (controller : SubjectId) (tickers : List SubjectId) (payWriters : Bool)
    (old new : Minidregg.Pred.State) (oldNow newNow : Int)
    (nowOld : old.get "clock/now" = some oldNow) (nowNew : new.get "clock/now" = some newNow)
    (back : newNow < oldNow) :
    Minidregg.Pred.eval (clockPredicate controller tickers payWriters) old new = false := by
  unfold Minidregg.Pred.eval clockPredicate controlClause absent
  simp [Minidregg.Pred.evalWith, nowOld, nowNew, Int.not_le.mpr back]

/-- **A non-ticker cannot tick**: a `tickClock` request by a subject that is no
ticker is refused (no pay clause and no management verb is `tickClock`), the controller
included. -/
theorem clock_refuses_nonticker_tick (controller : SubjectId) (tickers : List SubjectId)
    (payWriters : Bool)
    (old new : Minidregg.Pred.State) (subject : Nat)
    (named : new.get "request/subject" = some (Int.ofNat subject))
    (ticking : new.get "request/verb" = some (Int.ofNat tickVerbTag))
    (other : subject ∉ tickers.map (·.value)) :
    Minidregg.Pred.eval (clockPredicate controller tickers payWriters) old new = false := by
  have tick : Minidregg.Pred.eval (tickClause tickers) old new = false := by
    cases h : Minidregg.Pred.eval (tickClause tickers) old new
    · rfl
    · exact absurd ((tickClause_eval tickers old new subject tickVerbTag named ticking).1 h).2 other
  unfold Minidregg.Pred.eval at tick
  unfold Minidregg.Pred.eval clockPredicate
  cases payWriters <;>
    simp [tick, payClauses, controlClause, controlVerbTags, Minidregg.Pred.evalWith, ticking,
      tickVerbTag, observeVerbTag, installVerbTag, CredentialAuthorityEntryCodec.verbTag]

/-- **Without a payment observer only ticks and the controller's management pass**: a
request that is neither a ticker's tick nor the controller's management is refused. -/
theorem clock_ticks_only (controller : SubjectId) (tickers : List SubjectId)
    (old new : Minidregg.Pred.State)
    (notTick : Minidregg.Pred.eval (tickClause tickers) old new = false)
    (notControl : Minidregg.Pred.eval (controlClause controller) old new = false) :
    Minidregg.Pred.eval (clockPredicate controller tickers false) old new = false := by
  unfold Minidregg.Pred.eval at notTick notControl
  unfold Minidregg.Pred.eval clockPredicate
  simp [notTick, notControl]

/-! ## The clock write's law step -/

/-- The clock write of a family that advances the clock beside its own effect,
as a semantic effect over the clock cell: the writer's own request, the turn's
effect digest, and exactly the validated clock patch. -/
def family (pre : ClockCell.Cell) (request : PackedEffectRequest) (effect : Digest)
    (patch : Patch ClockCell.layout) :
    SemanticEffectFamily ClockCell.layout ClockCell.materializer Nat where
  Declaration := Unit
  declarationCodec := unitCodec
  pre := pre
  request := fun _ => request
  Outcome := fun _ => Unit
  outcomeCodec := fun _ => unitCodec
  ModeEvidence := fun _ _ => Unit
  Postcondition := fun _ _ post => patch.ResultAt pre.logical post
  effectDigest := fun _ => effect
  patch := fun _ _ => patch
  nullifier := fun _ _ => none
  Release := fun _ _ => Unit
  DeclassificationAuthority := fun _ _ => Unit
  ReleaseAuthorization := fun _ _ _ => Unit
  DisclosureAllowed := fun _ _ => sealedOnly

def candidate {pre : ClockCell.Cell} {request : PackedEffectRequest} {effect : Digest}
    {patch : Patch ClockCell.layout} (validated : ValidatedPatch ClockCell.materializer pre pre.root patch) :
    PolicyInstall.Candidate (family pre request effect patch) pre () () where
  preStateBound := rfl
  modeEvidence := ()
  validated := validated
  postcondition := validated.resultAt

/-- The clock projected for its law: the target's structural selector slots,
the writer's request, the operation marker, then the clock (the loaded clock
when the store holds none). -/
def project (selectors : List (String × Int)) {kind : ResourceKind} (request : Request kind)
    (operation : String) (fallback : ClockCell.Clock) (logical : ClockCell.ClockStore) :
    Minidregg.Pred.State :=
  ⟨selectors ++ CanonicalRuntimeProfile.requestSlots request ++ [(operation, 1)] ++
    ClockCell.slots ((ClockCell.clockOf logical).getD fallback)⟩

/-- **The clock write's law step**: the projection above over the clock cell
before and after exactly the validated patch. -/
def step (selectors : List (String × Int)) {kind : ResourceKind} (request : Request kind)
    (operation : String) (fallback : ClockCell.Clock) (semantics effect : Digest)
    {pre : ClockCell.Cell} {patch : Patch ClockCell.layout}
    (validated : ValidatedPatch ClockCell.materializer pre pre.root patch) : PolicyStepContext :=
  PolicyStepContext.ofCandidate (project selectors request operation fallback) semantics
    (candidate (request := ⟨kind, request⟩) (effect := effect) validated)

/-- The step's old state is the clock before, its new state the clock after
the validated patch. -/
theorem step_states (selectors : List (String × Int)) {kind : ResourceKind} (request : Request kind)
    (operation : String) (fallback : ClockCell.Clock) (semantics effect : Digest)
    {pre : ClockCell.Cell} {patch : Patch ClockCell.layout}
    (validated : ValidatedPatch ClockCell.materializer pre pre.root patch) :
    (step selectors request operation fallback semantics effect validated).oldState =
        project selectors request operation fallback pre.logical ∧
      (step selectors request operation fallback semantics effect validated).newState =
        project selectors request operation fallback validated.apply.logical := ⟨rfl, rfl⟩

/-! ## Poles (closed states, decided by the kernel) -/

def poleState (subject verb : Nat) (operation : String) (now slot : Nat) : Minidregg.Pred.State :=
  ⟨[("request/subject", Int.ofNat subject), ("request/verb", Int.ofNat verb), (operation, 1),
    ("clock/now", Int.ofNat now), ("clock/slot", Int.ofNat slot)]⟩

def poleTickers : List SubjectId := [⟨70⟩]

/-- The poles' factory controller (the sponsor, subject 7). -/
def poleController : SubjectId := ⟨7⟩

/-- A management step's state: the request, no clock (an install projects the authority
cell, not the clock). -/
def manageState (subject verb : Nat) : Minidregg.Pred.State :=
  ⟨[("request/subject", Int.ofNat subject), ("request/verb", Int.ofNat verb)]⟩

/-- A ticker's tick forward is admitted. -/
theorem pole_tick_admitted :
    Minidregg.Pred.eval (clockPredicate poleController poleTickers true) (poleState 70 11 "tick" 100 5)
      (poleState 70 11 "tick" 200 6) = true := by decide +kernel

/-- A payment observation forward is admitted. -/
theorem pole_observe_admitted :
    Minidregg.Pred.eval (clockPredicate poleController poleTickers true) (poleState 30 6 payObserveSlot 100 5)
      (poleState 30 6 payObserveSlot 100 9) = true := by decide +kernel

/-- A self-enrollment forward is admitted. -/
theorem pole_enrol_admitted :
    Minidregg.Pred.eval (clockPredicate poleController poleTickers true) (poleState 30 4 paySelfEnrolSlot 100 5)
      (poleState 30 4 paySelfEnrolSlot 150 9) = true := by decide +kernel

/-- A payment observation that moves the slot back is refused. -/
theorem pole_observe_back_refused :
    Minidregg.Pred.eval (clockPredicate poleController poleTickers true) (poleState 30 6 payObserveSlot 100 9)
      (poleState 30 6 payObserveSlot 100 5) = false := by decide +kernel

/-- Without a payment observer, a payment observation is refused. -/
theorem pole_observe_without_observer_refused :
    Minidregg.Pred.eval (clockPredicate poleController poleTickers false) (poleState 30 6 payObserveSlot 100 5)
      (poleState 30 6 payObserveSlot 100 9) = false := by decide +kernel

/-- An `observePayment` request without the operation marker is refused (the
verb alone does not advance the clock). -/
theorem pole_unmarked_observe_refused :
    Minidregg.Pred.eval (clockPredicate poleController poleTickers true) (poleState 30 6 "other" 100 5)
      (poleState 30 6 "other" 100 9) = false := by decide +kernel

/-- A sponsor's tick is refused. -/
theorem pole_sponsor_tick_refused :
    Minidregg.Pred.eval (clockPredicate poleController poleTickers true) (poleState 7 11 "tick" 100 5)
      (poleState 7 11 "tick" 200 6) = false := by decide +kernel

/-- Satisfiable (O61): the controller's `installPolicy` on the clock (a step that carries
no clock) is admitted, so a law naming a new ticker can be installed at runtime. -/
theorem pole_controller_install_admitted :
    Minidregg.Pred.eval (clockPredicate poleController poleTickers false)
      (manageState 7 4) (manageState 7 4) = true := by decide +kernel

/-- Teeth (O61, audit pass 15): management that moves the clock forward is refused; the
controller's verbs never advance the clock. -/
theorem pole_controller_advance_refused :
    Minidregg.Pred.eval (clockPredicate poleController poleTickers false)
      (poleState 7 4 "install" 100 5) (poleState 7 4 "install" 200 6) = false := by decide +kernel

/-- Teeth: a non-controller's management verb is refused. -/
theorem pole_stranger_install_refused :
    Minidregg.Pred.eval (clockPredicate poleController poleTickers false)
      (manageState 30 4) (manageState 30 4) = false := by decide +kernel

/-- Satisfiable (O61): under a law the controller installed naming a new ticker (80), that
ticker's tick forward is admitted. -/
theorem pole_new_ticker_admitted :
    Minidregg.Pred.eval (clockPredicate poleController [⟨70⟩, ⟨80⟩] false)
      (poleState 80 11 "tick" 100 5) (poleState 80 11 "tick" 200 6) = true := by decide +kernel

/-- Teeth (O61): the controller's own tick is refused, its management clause notwithstanding. -/
theorem pole_controller_tick_refused :
    Minidregg.Pred.eval (clockPredicate poleController poleTickers false)
      (poleState 7 11 "tick" 100 5) (poleState 7 11 "tick" 200 6) = false := by decide +kernel

/-- Teeth: the controller's management cannot move the clock back. -/
theorem pole_controller_regress_refused :
    Minidregg.Pred.eval (clockPredicate poleController poleTickers false)
      (poleState 7 4 "install" 100 5) (poleState 7 4 "install" 100 4) = false := by decide +kernel

#assert_axioms controlClause_clock_false
#assert_axioms pole_controller_install_admitted
#assert_axioms pole_controller_advance_refused
#assert_axioms pole_stranger_install_refused
#assert_axioms pole_new_ticker_admitted
#assert_axioms pole_controller_tick_refused
#assert_axioms pole_controller_regress_refused
#assert_axioms tickClause_eval
#assert_axioms clockPredicate_eval
#assert_axioms clock_refuses_slot_regress
#assert_axioms clock_refuses_now_regress
#assert_axioms clock_refuses_nonticker_tick
#assert_axioms clock_ticks_only
#assert_axioms step_states
#assert_axioms pole_tick_admitted
#assert_axioms pole_observe_admitted
#assert_axioms pole_enrol_admitted
#assert_axioms pole_observe_back_refused
#assert_axioms pole_observe_without_observer_refused
#assert_axioms pole_unmarked_observe_refused
#assert_axioms pole_sponsor_tick_refused

end Minidregg.Kernel.ClockLaw
