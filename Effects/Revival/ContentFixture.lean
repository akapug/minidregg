/-
# `Effects/Revival/ContentFixture.lean` — the accepted-branch witnesses, on the member's doc write

The live keystones' accepted branches and the halves of their teeth that need a real cell
(`Effects/Revival/Statements.lean`, audited), inhabited by the native doc-write fixture
(`Fixtures.NativeDocWriteFixture`): the second `doc append` a native Host admitted, its Store
prefix, decoded directory and authority, and the content target of its signed command.  The
witness is read from the same inputs the controller's `prepareTarget` reads (the ground's
directory slot, `selectTarget`, the ground's authority snapshot, the profile's semantics, the
Host's ambient at that image), so the cell is the one the Host loaded and its blinding is
present (the rotation is non-empty).

* `contentAccepted : ContentAccepted`, `hostAccepted : HostAccepted`;
* `contentTeeth : ContentTeeth` (its ghost half here; its narrowed half is
  `contentNarrowed_incomplete`);
* `hostTeeth : HostTeeth` (its ghost half here; the twin half is `noTwin` at code 1).

The concrete facts about the fixture are one compiled evaluation (`docWrite_checks`); every
step from those facts to a statement is a kernel proof over an arbitrary witness
(`contentAccepted_of`, `contentGhost_refuted_of`, `hostAccepted_of`, `hostGhost_refuted_of`).
-/
import Effects.Revival.ContentProofs
import Fixtures.NativeDocWriteFixture
import Theory.AssertAxioms
import Theory.AssertCompiled

namespace Minidregg.Effects.Revival

open Minidregg.Compiler
open Minidregg.Compiler.Tower256ConcreteBackend
open Minidregg.Theory
open Minidregg.Theory.CellState
open Minidregg.Theory.Store
open Minidregg.Theory.TypedAuthorization
open Minidregg.Kernel

set_option autoImplicit false

/-! ## A content target's witness, read the way `prepareTarget` reads it. -/

/-- One content target of a transaction, with the cell its slot holds and the selection. -/
structure ContentWitness where
  deployment : DeclaredResourceController.Deployment
  ctx : LiveCtx
  content : ContentResource.Command
  pre : ContentResource.ContentCell
  observe : Option CapabilityId
  epoch : Option Nat
  roster : Option ObjectAudienceRoster.Roster
  before : HostCell

/-- The witness's target with the declared version and the loaded root. -/
abbrev ContentWitness.liveTarget (w : ContentWitness) : DeclaredResourceController.Target :=
  contentTarget w.ctx contentSpec.version w.pre.root w.content w.observe w.epoch w.roster

/-- The witness's host context. -/
abbrev ContentWitness.hostCtx (w : ContentWitness) : HostCtx :=
  hostCtxOf w.ctx w.deployment contentSpec.version w.pre.root w.observe w.epoch w.roster

/-- The first content target of `targets`: its slot's cell (`directory.slots`), selected by
`selectTarget` as `prepareTarget` selects it. -/
def contentWitnessOf (deployment : DeclaredResourceController.Deployment)
    (directory : CellRegistry.Directory Nat DeclaredResourceController.Registry)
    (snapshot : DeclaredResourceController.AuthoritySnapshot) (semantics : Digest)
    (ambient : DeclaredResourceController.Ambient) (command : DeclaredResourceController.Command) :
    List DeclaredResourceController.Target → Option ContentWitness
  | [] => none
  | ⟨kind, id, capability, version, root, .content content, observe, epoch, roster⟩ :: _ =>
    match directory.slots id with
    | .present before =>
      let ctx : LiveCtx := ⟨snapshot, semantics, ambient, command, kind, id, capability⟩
      (DeclaredResourceController.selectTarget deployment
          (contentTarget ctx version root content observe epoch roster) before).map
        fun (pre : ContentResource.ContentCell) =>
          ⟨deployment, ctx, content, pre, observe, epoch, roster, before⟩
    | .absent => none
  | _ :: rest => contentWitnessOf deployment directory snapshot semantics ambient command rest

/-! ## The checks a witness is put to. -/

/-- The live arm admits the witness: an object, a non-empty command, `computeTarget`
computes, and the target's patch validates at the loaded store. -/
def acceptedCheck (w : ContentWitness) : Bool :=
  contentSpec.accepts w.ctx.kind && !w.content.actions.isEmpty &&
  (DeclaredResourceController.computeTarget w.ctx.snapshot w.ctx.semantics w.ctx.ambient
      w.ctx.command w.liveTarget w.pre).toBool &&
  decide (Patch.ValidFrom w.pre.logical (DeclaredResourceController.targetPatch w.ctx.snapshot
      w.ctx.semantics w.ctx.ambient w.ctx.command w.liveTarget w.pre))

/-- The declaration emits a descriptor and the live patch is strictly longer than it (the
rotation is not empty). -/
def ghostCheck (w : ContentWitness) : Bool :=
  match contentSpec.sem w.ctx w.content w.pre.logical with
  | .ok ps => decide ((DeclaredResourceController.targetPatch w.ctx.snapshot w.ctx.semantics
      w.ctx.ambient w.ctx.command w.liveTarget w.pre).length ≠ ps.length)
  | .error _ => false

/-- The packed bytes of an admitted cell. -/
def cellBytes : Except DispatchRefusal HostCell → Option (List UInt8)
  | .ok cell => some cell.bytes
  | .error _ => none

/-- The host dispatch admits the witness's command, encoded, at its cell. -/
def hostAcceptedCheck (w : ContentWitness) : Bool :=
  (hostTargetDispatch 1 (ContentResource.commandStream.encode w.content) w.hostCtx w.before).toBool

/-- The host dispatch and the ghost handler's firing differ at the witness. -/
def hostGhostCheck (w : ContentWitness) : Bool :=
  decide (cellBytes (hostTargetDispatch 1 (ContentResource.commandStream.encode w.content)
      w.hostCtx w.before) ≠
    cellBytes ((contentHandlerOf contentGhost).fire 1 w.hostCtx w.content w.before))

def allChecks (w : ContentWitness) : Bool :=
  acceptedCheck w && ghostCheck w && hostAcceptedCheck w && hostGhostCheck w

/-! ## From the checks to the statements (kernel proofs, any witness). -/

theorem except_toBool_ok {ε α : Type} {x : Except ε α} (h : x.toBool = true) :
    ∃ a, x = .ok a := by
  cases x with
  | error e => simp [Except.toBool] at h
  | ok a => exact ⟨a, rfl⟩

theorem contentAccepted_of (w : ContentWitness) (h : acceptedCheck w = true) :
    ContentAccepted := by
  simp only [acceptedCheck, Bool.and_eq_true, Bool.not_eq_true', decide_eq_true_eq] at h
  obtain ⟨⟨⟨accepts, nonempty⟩, computed⟩, valid⟩ := h
  obtain ⟨post, computed⟩ := except_toBool_ok computed
  exact ⟨w.ctx, w.content, w.pre, w.observe, w.epoch, w.roster, post, accepts,
    fun empty => by simp [empty] at nonempty, computed, valid⟩

theorem contentGhost_refuted_of (w : ContentWitness) (h : acceptedCheck w = true)
    (g : ghostCheck w = true) : ¬ ContentAgreement contentGhost := by
  intro agree
  simp only [acceptedCheck, Bool.and_eq_true] at h
  obtain ⟨⟨⟨accepts, -⟩, -⟩, -⟩ := h
  obtain ⟨-, -, -, live, -⟩ := agree w.ctx w.content w.pre w.observe w.epoch w.roster
  obtain ⟨-, -, descriptor⟩ := live accepts
  unfold ghostCheck at g
  split at g
  · rename_i ps emitted
    have patch := congrArg List.length (descriptor ps emitted)
    simp only [contentGhost, List.append_nil] at patch
    exact (of_decide_eq_true g) patch
  · exact absurd g Bool.false_ne_true

theorem hostAccepted_of (w : ContentWitness) (h : hostAcceptedCheck w = true) :
    HostAccepted := by
  obtain ⟨cell', admitted⟩ := except_toBool_ok h
  exact ⟨w.content, w.hostCtx, w.before, cell', admitted⟩

theorem hostGhost_refuted_of (w : ContentWitness) (g : hostGhostCheck w = true) :
    ¬ Dispatches [(1, contentHandlerOf contentGhost)] hostLegacy hostTargetDispatch := by
  intro dispatches
  have agree := dispatches.agreement 1 (contentHandlerOf contentGhost) (by simp)
    w.content w.hostCtx w.before
  exact (of_decide_eq_true g) (congrArg cellBytes agree)

/-- The twin half of `HostTeeth`: code 1 cannot be both registered and a hand arm. -/
theorem hostTwin_refuted :
    ¬ Dispatches [(1, contentHandler)] (1 :: hostLegacy) hostTargetDispatch := fun dispatches => by
  have := dispatches.noTwin 1 (by simp)
  simp at this

/-! ## The member's doc write. -/

open Minidregg.Fixtures in
/-- The content target of the fixture's signed write, at the Store prefix it was admitted
at: the ground's directory and authority, the profile's semantics, the Host's ambient. -/
@[irreducible] def docWriteWitness : Option ContentWitness := do
  let image ← NativeDocWriteFixture.image
  let durable ← NativeDocWriteFixture.loadAt image
  let signed ← NativeDocWriteFixture.signedWrite
  let command ← DeclaredResourceController.commandCodec.decode signed.commandBytes
  let ground ← NativeDocWriteFixture.groundAt durable
  contentWitnessOf NativeDocWriteFixture.config.deployment ground.directory ground.authority
    NativeDocWriteFixture.config.profile.semantics (NativeDocWriteFixture.ambientOf durable)
    command command.targets

/-- **The fixture's content target passes every check** (compiled evaluation). -/
theorem docWrite_checks : docWriteWitness.map allChecks = some true := by native_decide

theorem docWrite_witness : ∃ w, allChecks w = true := by
  cases found : docWriteWitness with
  | none => have := docWrite_checks; rw [found] at this; simp at this
  | some w =>
    have := docWrite_checks
    rw [found] at this
    exact ⟨w, by simpa using this⟩

/-! ## The witnesses. -/

theorem contentAccepted : ContentAccepted := by
  obtain ⟨w, checks⟩ := docWrite_witness
  simp only [allChecks, Bool.and_eq_true] at checks
  exact contentAccepted_of w checks.1.1.1

theorem contentTeeth : ContentTeeth := by
  obtain ⟨w, checks⟩ := docWrite_witness
  simp only [allChecks, Bool.and_eq_true] at checks
  exact ⟨contentGhost_refuted_of w checks.1.1.1 checks.1.1.2, contentNarrowed_incomplete⟩

theorem hostAccepted : HostAccepted := by
  obtain ⟨w, checks⟩ := docWrite_witness
  simp only [allChecks, Bool.and_eq_true] at checks
  exact hostAccepted_of w checks.1.2

theorem hostTeeth : HostTeeth := by
  obtain ⟨w, checks⟩ := docWrite_witness
  simp only [allChecks, Bool.and_eq_true] at checks
  exact ⟨hostGhost_refuted_of w checks.2, hostTwin_refuted⟩

/-! ## Pins. -/

#assert_axioms contentAccepted_of
#assert_axioms contentGhost_refuted_of
#assert_axioms hostAccepted_of
#assert_axioms hostGhost_refuted_of
#assert_axioms hostTwin_refuted

set_option maxHeartbeats 4000000 in
#assert_compiled docWrite_checks
set_option maxHeartbeats 4000000 in
#assert_compiled contentAccepted
set_option maxHeartbeats 4000000 in
#assert_compiled contentTeeth
set_option maxHeartbeats 4000000 in
#assert_compiled hostAccepted
set_option maxHeartbeats 4000000 in
#assert_compiled hostTeeth

end Minidregg.Effects.Revival
