/-
# `Effects/Revival/Statements.lean` — the widened declaration and the dispatch keystone, STATED

The statement half of `docs/EFFECTS-REVIVAL.md` (the deputy's Phase-3 design,
`docs/review/2026-10-27-untouched-areas/EFFECTS.md`, made concrete).  Every keystone below
enters as a `Prop` with its ATLAS fields (satisfiable, teeth, premise inhabitation).  This
file proves nothing; the witnesses' DATA is built here, their proofs follow the auditor's
verdict.

## What is stated

* §1-§5 live in `Effects/Revival/Engine.lean` (kernel-free, small closure); this file
  imports it and holds §6-§7.
* §1 `Substrate`: the guarded primitive algebra an effect emits into.  `storeSubstrate L` is
  the deployed one (`Theory.Store`'s guarded `Op`s); the Book's posting algebra is the second
  (transfer, migration step 2).
* §2 `EffectSpec`: ONE effect as ONE declaration.  Its semantics emits a first-order
  descriptor (a list of primitives) or refuses BY NAME; the kernel's rotate (the blinding
  ratchet), the field classification, the declared frame, the verb and the law's view are
  declaration data.  The checked executor `exec` is derived; nothing about it is authored.
* §3 `Handler`, `Registry`, `dispatch`, `LawfulRegistry`: the open registry and the one
  dispatcher.
* §4 `Dispatches R legacy d`: what it means for a dispatcher `d` to dispatch through `R`
  (agreement, unregistered refuses by name, frame law, no twin), a predicate on ANY candidate
  `d`, so a fail-open or misreading dispatcher is refuted, not assumed away.
* §5 Engine keystone and completeness keystone, with the two-entry pole.
* §6 The LIVE keystone: `contentSpec`, the declaration of the deployed content-cell write
  (`Payload.content`, wire code 1, what `doc append` signs), and `ContentAgreement`: the
  hand-written arm of `DeclaredResourceController.computeTarget`/`targetPatch` and its
  authority classification (`targetField`, `targetRatchet`, `targetAmount`, `payloadVerb`,
  `targetProjection`) agree with the declaration.  This is the gate of the commit that
  deletes that hand arm.

## Vacuity, said out loud

`Dispatches R [] (dispatch R)` is the engine's generic theorem (the analogue of
`EffectSpec.derived_agrees`): its content is that `Dispatches` DISCRIMINATES (§5 teeth: a
misreading, a fail-open and an unframed dispatcher are each refuted), not that `dispatch`
satisfies it.  The deployed content lives in `ContentAgreement`, stated against today's hand
arm (a real refinement, not an `rfl` through a reader this lane wrote), and in
`contentSpec.Complete`, the declared frame of the fifteen content actions (a claim that can
be false, with its own teeth).
-/
import Effects.Revival.Engine
import Kernel.DeclaredResourceController

namespace Minidregg.Effects.Revival

open Minidregg.Compiler
open Minidregg.Compiler.Tower256ConcreteBackend
open Minidregg.Theory
open Minidregg.Theory.CellState
open Minidregg.Theory.Store
open Minidregg.Theory.TypedAuthorization
open Minidregg.Kernel

set_option autoImplicit false

/-! ## §6. The LIVE keystone: the content-cell write behind `doc append`. -/

/-- What a declared-resource target's computation consumes of its transaction (the
arguments of `DeclaredResourceController.computeTarget`, and the target's header fields a
semantics reads). -/
structure LiveCtx where
  snapshot : DeclaredResourceController.AuthoritySnapshot
  semantics : Digest
  ambient : DeclaredResourceController.Ambient
  command : DeclaredResourceController.Command
  kind : ResourceKind
  target : Nat
  capability : CapabilityId

abbrev ContentSubstrate := storeSubstrate Hyperdocument.layout

abbrev ContentSpec :=
  EffectSpec LiveCtx ContentSubstrate ContentResource.Command ContentResource.Reject

/-- The fields one content action may write (`ResourceObservationAdmission.contentField`:
links, marks and annotations are `annotations`, every other namespace `body`; an atom is
also named by `atomsOf` of its low half). -/
def contentActionFrame : ContentResource.Action → Finset CellField
  | .createDocument _ _ => {.body}
  | .createAtom atom _ _ => {ResourceObservationAdmission.atomField atom.digest.value, .body}
  | .editAtom edit => {ResourceObservationAdmission.atomField edit.atomId.digest.value}
  | .rewrapAtom atom _ _ => {ResourceObservationAdmission.atomField atom.digest.value}
  | .link .. => {.annotations}
  | .createRun .. => {.body}
  | .annotate .. => {.annotations}
  | .rewrapAnnotation .. => {.annotations}
  | .transclude .. => {.body, .annotations}
  | .editElement _ => {.body}
  | .createContainer _ => {.body}
  | .unlink _ => {.annotations}
  | .mark .. => {.annotations}
  | .unmark _ => {.annotations}
  | .insertRun .. => {.body}

/-- The declared frame of a content command: the union of its actions' frames. -/
def contentFrame (command : ContentResource.Command) : Finset CellField :=
  command.actions.foldr (fun action acc => contentActionFrame action ∪ acc) ∅

/-- The content semantics: the source-owned lowering `ContentResource.run` (REUSED), its
patch the descriptor; an empty command refuses `emptyActions` as `prepareCell` does. -/
def contentSem (ctx : LiveCtx) (command : ContentResource.Command)
    (s : Store Hyperdocument.layout) : Except ContentResource.Reject (Patch Hyperdocument.layout) :=
  if command.actions.isEmpty then .error .emptyActions
  else (ContentResource.run ⟨ctx.command.subject, ctx.kind, ctx.capability⟩
      (DeclaredResourceController.contentOperation ctx.snapshot ctx.semantics ctx.command)
      (ContentResource.documentOf ctx.target)
      (DeclaredResourceController.contentContext ctx.snapshot ctx.ambient ctx.command)
      s command).map Prod.snd

/-- **The first live declaration: the content-cell write.**  Wire code 1 of the target
payload (`payloadStream`'s tag for `Payload.content`), the action grammar's codec
(`ContentResource.commandStream`), version `ContentResource.commandVersion`. -/
def contentSpec : ContentSpec where
  opStream := ContentResource.commandStream
  refusalName r := reprStr r
  accepts kind := kind == .object
  version := ContentResource.commandVersion
  sem := contentSem
  rotate ctx s := HyperdocumentCell.contentBlinding.patch s ctx.ambient.height
  rotated := fun (loc : Address Hyperdocument.layout) => match loc.1 with
    | .blinding => true
    | _ => false
  field := ResourceObservationAdmission.contentFieldAt
  amount := fun _ _ => 0
  frame := contentFrame
  verb := fun kind _ => DeclaredResourceScalar.ordinaryVerb kind
  view command before after := ContentResource.project before after command

/-- A content target with the given header. -/
abbrev contentTarget (ctx : LiveCtx) (version : Nat) (root : Digest)
    (command : ContentResource.Command) (observe : Option CapabilityId)
    (epoch : Option Nat) (roster : Option ObjectAudienceRoster.Roster) :
    DeclaredResourceController.Target :=
  ⟨ctx.kind, ctx.target, ctx.capability, version, root, .content command, observe, epoch, roster⟩

/-- **LIVE KEYSTONE: the deployed content arm agrees with the declaration.**  For every
transaction context, content command and loaded content cell:

1. header — the live arm's three header refusals are the generic ones the declaration's
   `accepts`/`version` determine (`wrongRole`, `unsupportedVersion`, `staleTarget`);
2. acceptance — with the header passing, the derived executor admits with post `p`
   exactly when the live arm computes `p` AND the live patch validates at the loaded
   store (what `prepareTarget` requires before it builds a candidate);
3. refusal — a content refusal of the live arm is the declaration's, by name;
4. descriptor — the live patch IS the declaration's descriptor followed by its rotate
   (`computeTarget`/`targetPatch` stop being twins);
5. authority — `targetField`, `targetRatchet`, `targetAmount`, `payloadVerb` and
   `targetProjection` are the declaration's `field`, `rotated`, `amount`, `verb`, `view`.

Clause 2 also tests the declared frame: a live-admitted command that wrote outside
`contentFrame` would be refused `outOfFrame` by `exec`. -/
def ContentAgreement (E : ContentSpec) : Prop :=
  ∀ (ctx : LiveCtx) (command : ContentResource.Command) (pre : ContentResource.ContentCell)
    (observe : Option CapabilityId) (epoch : Option Nat) (roster : Option ObjectAudienceRoster.Roster),
  (∀ version root, E.accepts ctx.kind = false →
    DeclaredResourceController.computeTarget ctx.snapshot ctx.semantics ctx.ambient ctx.command
      (contentTarget ctx version root command observe epoch roster) pre = .error .wrongRole) ∧
  (∀ version root, E.accepts ctx.kind = true → version ≠ E.version →
    DeclaredResourceController.computeTarget ctx.snapshot ctx.semantics ctx.ambient ctx.command
      (contentTarget ctx version root command observe epoch roster) pre = .error .unsupportedVersion) ∧
  (∀ root, E.accepts ctx.kind = true → root ≠ pre.root →
    DeclaredResourceController.computeTarget ctx.snapshot ctx.semantics ctx.ambient ctx.command
      (contentTarget ctx E.version root command observe epoch roster) pre = .error .staleTarget) ∧
  (E.accepts ctx.kind = true →
    (∀ post : Store Hyperdocument.layout,
      E.exec 1 ctx command pre.logical = .ok post ↔
        (DeclaredResourceController.computeTarget ctx.snapshot ctx.semantics ctx.ambient ctx.command
            (contentTarget ctx E.version pre.root command observe epoch roster) pre = .ok post ∧
          Patch.ValidFrom pre.logical
            (DeclaredResourceController.targetPatch ctx.snapshot ctx.semantics ctx.ambient ctx.command
              (contentTarget ctx E.version pre.root command observe epoch roster) pre))) ∧
    (∀ r : ContentResource.Reject,
      DeclaredResourceController.computeTarget ctx.snapshot ctx.semantics ctx.ambient ctx.command
          (contentTarget ctx E.version pre.root command observe epoch roster) pre = .error (.content r) →
        E.exec 1 ctx command pre.logical = .error (.refused 1 (E.refusalName r))) ∧
    (∀ ps, E.sem ctx command pre.logical = .ok ps →
      DeclaredResourceController.targetPatch ctx.snapshot ctx.semantics ctx.ambient ctx.command
          (contentTarget ctx E.version pre.root command observe epoch roster) pre =
        ps ++ E.rotate ctx pre.logical)) ∧
  (∀ version root,
    (∀ a : Address Hyperdocument.layout,
      DeclaredResourceController.targetField
        (contentTarget ctx version root command observe epoch roster) a = E.field a) ∧
    (∀ a : Address Hyperdocument.layout,
      DeclaredResourceController.targetRatchet
        (contentTarget ctx version root command observe epoch roster) a = E.rotated a) ∧
    (∀ (a : Address Hyperdocument.layout) (v : Hyperdocument.layout.Value a.1),
      DeclaredResourceController.targetAmount
        (contentTarget ctx version root command observe epoch roster) a v = E.amount a (some v)) ∧
    DeclaredResourceController.payloadVerb ctx.kind (.content command) = E.verb ctx.kind command ∧
    (∀ before after : Store Hyperdocument.layout,
      DeclaredResourceController.targetProjection ctx.command.subject
        (contentTarget ctx version root command observe epoch roster) before after =
          E.view command before after))

/-- The content declaration's own obligation: every admitted content command writes only
its declared fields and its descriptor (with the rotate) replays. -/
def ContentComplete : Prop := contentSpec.Complete

/-! ### The live keystone's ATLAS fields. -/

/-- **Satisfiable / premise inhabitation (the accepted branch).**  The live arm admits some
content command (the native doc-write fixture, `Fixtures/NativeDocWriteFixture*`, is the
intended inhabitant): clause 2 is not vacuously about refusals only. -/
def ContentAccepted : Prop :=
  ∃ (ctx : LiveCtx) (command : ContentResource.Command) (pre : ContentResource.ContentCell)
    (observe : Option CapabilityId) (epoch : Option Nat) (roster : Option ObjectAudienceRoster.Roster)
    (post : Store Hyperdocument.layout),
    contentSpec.accepts ctx.kind = true ∧ command.actions ≠ [] ∧
    DeclaredResourceController.computeTarget ctx.snapshot ctx.semantics ctx.ambient ctx.command
      (contentTarget ctx contentSpec.version pre.root command observe epoch roster) pre = .ok post ∧
    Patch.ValidFrom pre.logical
      (DeclaredResourceController.targetPatch ctx.snapshot ctx.semantics ctx.ambient ctx.command
        (contentTarget ctx contentSpec.version pre.root command observe epoch roster) pre)

/-- The ghost declaration: the same lowering without the kernel's blinding ratchet. -/
def contentGhost : ContentSpec := { contentSpec with rotate := fun _ _ => [] }

/-- The narrowed declaration: the same lowering, its frame without `annotations`. -/
def contentNarrowed : ContentSpec :=
  { contentSpec with frame := fun command => (contentFrame command).erase .annotations }

/-- **Teeth.**  The agreement refutes a declaration that drops the rotate; completeness
refutes a frame that omits a field an action writes (`annotate`). -/
def ContentTeeth : Prop :=
  ¬ ContentAgreement contentGhost ∧ ¬ contentNarrowed.Complete

/-- **The live keystone, whole.** -/
def LiveKeystone : Prop := ContentAgreement contentSpec ∧ ContentComplete

/-! ## §7. The DEPLOYED keystone: the Host's target dispatch dispatches through the registry.

`ContentAgreement` alone would license keeping the hand arm beside the declaration (the
law-13 twin).  `HostKeystone` is the statement that closes it: today's target dispatch,
`hostTargetDispatch` (the payload decode, `selectTarget`, `computeTarget`, the
`targetPatch` validation and `packTarget` the controller runs per target), dispatches
through the one-entry registry `[(1, contentHandler)]` with every other payload code in
`hostLegacy`.  `noTwin` puts code 1 out of the hand arms.

**Known false today, by clause:** `unregistered`: an unknown payload tag (9-255, or a code
of 256 and up) is refused `malformed`, not by name, and code 1 is still served by the hand
arm, which `agreement` only matches if the arm is the declaration (`ContentAgreement` plus
`ContentComplete`).  The migration commit makes it true by rewiring the payload decoder
through the registry and deleting the content arms; this statement is that commit's gate.

Scope: the target dispatch, not the whole of `prepareTarget` (the post law, the policy
source, the audience freshness and the authority legs stay the controller's). -/

/-- Reindex a declaration's context (the content declaration reads a `LiveCtx`; the host
dispatch carries more). -/
def EffectSpec.comap {C C' : Type} {S : Substrate} {O R : Type} (f : C' → C)
    (E : EffectSpec C S O R) : EffectSpec C' S O R :=
  { E with sem := fun c => E.sem (f c), rotate := fun c => E.rotate (f c) }

/-- The host dispatch's context: the target computation's, plus the deployment and the
target header (`selectTarget`'s cell law, the schema version, the expected root, the
observe capability and audience fields). -/
structure HostCtx extends LiveCtx where
  deployment : DeclaredResourceController.Deployment
  version : Nat
  root : Digest
  observe : Option CapabilityId
  epoch : Option Nat
  roster : Option ObjectAudienceRoster.Roster

/-- The cell universe of the live controller. -/
abbrev HostCell := CellRegistry.PackedCell DeclaredResourceController.Registry

/-- The live controller's target for a payload, under a host context. -/
abbrev hostTarget (ctx : HostCtx) (payload : DeclaredResourceController.Payload) :
    DeclaredResourceController.Target :=
  ⟨ctx.kind, ctx.target, ctx.capability, ctx.version, ctx.root, payload, ctx.observe, ctx.epoch, ctx.roster⟩

/-- A live refusal, named. -/
def ofReject (code : Nat) : DeclaredResourceController.Reject → DispatchRefusal
  | .wrongRole => .wrongRole code
  | .unsupportedVersion => .unsupportedVersion code
  | .staleTarget => .staleTarget code
  | .content r => .refused code (reprStr r)
  | r => .host code (reprStr r)

/-- **Today's target dispatch**, as the controller runs it per target: decode the payload
(`payloadStream`, the code its tag octet), select the cell (`selectTarget`), compute
(`computeTarget`), validate the target's patch at the loaded store, pack the post
(`packTarget`). -/
def hostTargetDispatch (code : Nat) (bytes : List UInt8) (ctx : HostCtx) (cell : HostCell) :
    Except DispatchRefusal HostCell :=
  if 256 ≤ code then .error (.malformed code) else
  match DeclaredResourceController.payloadStream.toLawful.decode (UInt8.ofNat code :: bytes) with
  | none => .error (.malformed code)
  | some payload =>
    match DeclaredResourceController.selectTarget ctx.deployment (hostTarget ctx payload) cell with
    | none => .error (.wrongRole code)
    | some pre =>
      match DeclaredResourceController.computeTarget ctx.snapshot ctx.semantics ctx.ambient
          ctx.command (hostTarget ctx payload) pre with
      | .error r => .error (ofReject code r)
      | .ok post =>
        if Patch.ValidFrom pre.logical (DeclaredResourceController.targetPatch ctx.snapshot
            ctx.semantics ctx.ambient ctx.command (hostTarget ctx payload) pre) then
          .ok (DeclaredResourceController.packTarget (hostTarget ctx payload)
            (CellState.materialize (hostTarget ctx payload).materializer post))
        else .error (.guardFailed code)

/-- The content cell's header, in the live order: role and cell law and shape
(`wrongRole`), then the schema version, then the expected root. -/
def contentHeader (ctx : HostCtx) (cell : HostCell) : Except DispatchRefusal Unit :=
  if contentSpec.accepts ctx.kind = false ∨
      ¬ CanonicalCellRegistry.CellLaw ctx.deployment ctx.target cell then .error (.wrongRole 1)
  else match cell with
    | ⟨.content, value⟩ =>
      if ctx.version ≠ contentSpec.version then .error (.unsupportedVersion 1)
      else if ctx.root ≠ value.root then .error (.staleTarget 1)
      else .ok ()
    | _ => .error (.wrongRole 1)

/-- **The content handler**: `contentSpec` over the host context, the content header, the
content cell selected and packed. -/
def contentHandlerOf (E : ContentSpec) : Handler HostCtx HostCell where
  S := ContentSubstrate
  O := ContentResource.Command
  R := ContentResource.Reject
  spec := E.comap HostCtx.toLiveCtx
  header := contentHeader
  select cell := match cell with
    | ⟨.content, value⟩ => some value.logical
    | _ => none
  pack s := ⟨.content, CellState.materialize HyperdocumentCell.contentMaterializer s⟩

def contentHandler : Handler HostCtx HostCell := contentHandlerOf contentSpec

/-- Every payload code but content's is still a hand arm. -/
def hostLegacy : List Nat := [0, 2, 3, 4, 5, 6, 7, 8]

/-- **THE DEPLOYED KEYSTONE.** -/
def HostKeystone : Prop :=
  Dispatches [(1, contentHandler)] hostLegacy hostTargetDispatch

/-- **Teeth.**  The host dispatch does not dispatch through a registry whose content
handler drops the rotate, nor through one that also keeps code 1 as a hand arm. -/
def HostTeeth : Prop :=
  ¬ Dispatches [(1, contentHandlerOf contentGhost)] hostLegacy hostTargetDispatch ∧
  ¬ Dispatches [(1, contentHandler)] (1 :: hostLegacy) hostTargetDispatch

/-- **Premise inhabitation.**  The content handler is sound (its `select`/`pack` are
inverse both ways, the store substrate is framed) and lawful. -/
def HostPremise : Prop := contentHandler.Lawful

/-- **Satisfiable (the accepted branch).**  Some content cell and well-encoded content
command are admitted by the host dispatch (the doc-write fixture is the intended
inhabitant, owed). -/
def HostAccepted : Prop :=
  ∃ (op : ContentResource.Command) (ctx : HostCtx) (cell cell' : HostCell),
    hostTargetDispatch 1 (ContentResource.commandStream.encode op) ctx cell = .ok cell'

/-! ## §8. The bridge to the deployed receiver: `prepareTarget`.

`HostKeystone` is about `hostTargetDispatch`, a wrapper this file writes; its contract alone
is not the receiver's.  `PrepareBridge` ties the content handler to the controller's own
per-target preparation, `ResourceTransaction.prepareTarget` (slot read, `selectTarget`,
`computeTarget`, patch validation, the final-post law, the policy source, audience
freshness): an accepted preparation's post IS the handler's dispatched post; an accepted
dispatch is refused by the receiver only by one of its controller-generic checks; and every
dispatch refusal is the receiver's refusal, by name.  At the migration commit,
`prepareTarget`'s registered branch calls the dispatcher and this bridge is its gate. -/

/-- The host context of a content target. -/
def hostCtxOf (ctx : LiveCtx) (deployment : DeclaredResourceController.Deployment)
    (version : Nat) (root : Digest) (observe : Option CapabilityId) (epoch : Option Nat)
    (roster : Option ObjectAudienceRoster.Roster) : HostCtx :=
  { ctx with deployment, version, root, observe, epoch, roster }

/-- The receiver's checks after the target computation that are not the effect's: the
final-post law, the policy source, audience freshness. -/
def ControllerGeneric : DeclaredResourceController.Reject → Prop
  | .invalidPost => True
  | .policyUnavailable => True
  | .audience _ => True
  | _ => False

/-- **THE RECEIVER BRIDGE.** -/
def PrepareBridge (E : ContentSpec) : Prop :=
  ∀ (deployment : DeclaredResourceController.Deployment)
    (directory : CellRegistry.Directory Nat DeclaredResourceController.Registry)
    (ctx : LiveCtx) (command : ContentResource.Command) (version : Nat) (root : Digest)
    (observe : Option CapabilityId) (epoch : Option Nat)
    (roster : Option ObjectAudienceRoster.Roster) (before : HostCell),
    directory.slots ctx.target = .present before →
    let T := contentTarget ctx version root command observe epoch roster
    let hctx := hostCtxOf ctx deployment version root observe epoch roster
    let routed := dispatch [(1, contentHandlerOf E)] 1 (ContentResource.commandStream.encode command)
      hctx before
    (∀ prepared, DeclaredResourceController.prepareTarget deployment directory ctx.snapshot
        ctx.semantics ctx.ambient ctx.command T = .ok prepared →
      routed = .ok (DeclaredResourceController.packTarget T prepared.candidate.post)) ∧
    (∀ cell', routed = .ok cell' →
      (∃ prepared, DeclaredResourceController.prepareTarget deployment directory ctx.snapshot
          ctx.semantics ctx.ambient ctx.command T = .ok prepared ∧
        DeclaredResourceController.packTarget T prepared.candidate.post = cell') ∨
      (∃ r, DeclaredResourceController.prepareTarget deployment directory ctx.snapshot
          ctx.semantics ctx.ambient ctx.command T = .error r ∧ ControllerGeneric r)) ∧
    (∀ d, routed = .error d →
      ∃ r, DeclaredResourceController.prepareTarget deployment directory ctx.snapshot
          ctx.semantics ctx.ambient ctx.command T = .error r ∧ ofReject 1 r = d)

end Minidregg.Effects.Revival
