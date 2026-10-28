/-
# `Effects/Revival/Statements.lean` — the widened declaration and the dispatch keystone, STATED

The statement half of `docs/EFFECTS-REVIVAL.md` (the deputy's Phase-3 design,
`docs/review/2026-10-27-untouched-areas/EFFECTS.md`, made concrete).  Every keystone below
enters as a `Prop` with its ATLAS fields (satisfiable, teeth, premise inhabitation).  This
file proves nothing; the witnesses' DATA is built here, their proofs follow the auditor's
verdict.

## What is stated

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

/-! ## §1. `Substrate` — the guarded primitive algebra a declaration emits into. -/

/-- A state with guarded primitives: `step` is `none` exactly when the primitive's guard
fails at the state it meets.  `writes` is the syntactic footprint of one primitive and
`read` the observation at one location; `Framed` (below) is the substrate's frame law. -/
structure Substrate : Type 1 where
  State : Type
  Prim : Type
  step : Prim → State → Option State
  Loc : Type
  [locDecEq : DecidableEq Loc]
  Obs : Loc → Type
  read : State → (loc : Loc) → Obs loc
  writes : Prim → Finset Loc

attribute [instance] Substrate.locDecEq

namespace Substrate

variable (S : Substrate)

/-- A descriptor's replay: every primitive in order, each guard checked at the state its
prefix produced (`Patch.ValidFrom` + `Patch.run` for the store substrate). -/
def run : S.State → List S.Prim → Option S.State
  | s, [] => some s
  | s, p :: ps => match S.step p s with
    | none => none
    | some s' => run s' ps

/-- The syntactic write footprint of a descriptor. -/
def footprint (ps : List S.Prim) : Finset S.Loc :=
  ps.foldr (fun p acc => S.writes p ∪ acc) ∅

/-- The substrate's frame law: a primitive changes nothing outside its own footprint. -/
def Framed : Prop :=
  ∀ p s s', S.step p s = some s' → ∀ loc, loc ∉ S.writes p → S.read s' loc = S.read s loc

end Substrate

/-- The deployed substrate: `Theory.Store`'s guarded operations over a layout.  A primitive
runs only when `Op.Enabled` holds at the store it meets; its footprint is
`Op.writeAddress?`. -/
def storeSubstrate (L : Layout.{0, 0, 0}) : Substrate where
  State := Store L
  Prim := Store.Op L
  step op s := if op.Enabled s then some (op.apply s) else none
  Loc := Address L
  Obs a := Option (L.Value a.1)
  read s a := s a
  writes op := op.writeAddress?.toFinset

/-! ## §2. `EffectSpec` — the widened declaration. -/

/-- **One effect, one declaration.**  `Ctx` is what the effect consumes of its
transaction (for the live controller: author, operation id, height, source reads);
`O` is the operation payload, syntactic by construction because it carries a canonical
codec; `R` the refusals it may name.

* `sem` emits the descriptor (the guarded patch) or refuses by name.  The post state is the
  descriptor's replay, never a second authored computation.
* `rotate` is the kernel's own per-cell step appended to every admitted descriptor (the
  blinding ratchet, K-HIDE-ROTATE); `rotated` marks the locations it writes.
* `field` classifies locations into capability fields, `amount` their numeric weight (the
  footprint `fieldsCheck` judges); `frame` is the DECLARED set of fields an operation may
  write.
* `accepts`/`version` are the role and schema version the live header checks.
* `verb` is the authority demand (the verb a capability must allow); `view` is what the
  cell's committed law reads (`targetProjection`).  The law itself is the cell's, not the
  effect's. -/
structure EffectSpec (Ctx : Type) (S : Substrate) (O R : Type) where
  opStream : StreamCodec O
  refusalName : R → String
  accepts : ResourceKind → Bool
  version : Nat
  sem : Ctx → O → S.State → Except R (List S.Prim)
  rotate : Ctx → S.State → List S.Prim
  rotated : S.Loc → Bool
  field : S.Loc → CellField
  amount : (loc : S.Loc) → S.Obs loc → Int
  frame : O → Finset CellField
  verb : (kind : ResourceKind) → O → Verb kind
  view : O → S.State → S.State → List (String × Int)

/-- Every refusal the dispatcher can return.  `refused` carries the declaration's own
name for its refusal; the rest are the dispatcher's, each naming the code. -/
inductive DispatchRefusal where
  | unregistered (code : Nat)
  | malformed (code : Nat)
  | wrongRole (code : Nat)
  | refused (code : Nat) (name : String)
  | outOfFrame (code : Nat)
  | guardFailed (code : Nat)
  | unsupportedVersion (code : Nat)
  | staleTarget (code : Nat)
  /-- Any other refusal of the live controller, by its `Reject` name. -/
  | host (code : Nat) (name : String)
  deriving DecidableEq, Repr

namespace EffectSpec

variable {Ctx : Type} {S : Substrate} {O R : Type} (E : EffectSpec Ctx S O R)

/-- The full emitted descriptor: the operation's patch, then the kernel's rotate. -/
def emitted (ctx : Ctx) (op : O) (s : S.State) : Except R (List S.Prim) :=
  (E.sem ctx op s).map fun ps => ps ++ E.rotate ctx s

/-- Every unsealed location a descriptor writes lies in a declared field of `op`. -/
def InFrame (op : O) (ps : List S.Prim) : Prop :=
  ∀ loc ∈ S.footprint ps, E.rotated loc = false → E.field loc ∈ E.frame op

instance (op : O) (ps : List S.Prim) : Decidable (E.InFrame op ps) := by
  unfold InFrame; infer_instance

/-- **The derived, checked executor.**  The declaration's semantics, then the frame check
(loud: `outOfFrame`), then the replay with every guard (loud: `guardFailed`).  For a
`Complete` declaration both checks are unreachable (§5 completeness), as `invalidPatch` is
for the live content arm (`ContentResource.prepareCell_ok_of_run`). -/
def exec (code : Nat) (ctx : Ctx) (op : O) (s : S.State) : Except DispatchRefusal S.State :=
  match E.sem ctx op s with
  | .error r => .error (.refused code (E.refusalName r))
  | .ok ps =>
    if E.InFrame op (ps ++ E.rotate ctx s) then
      match S.run s (ps ++ E.rotate ctx s) with
      | none => .error (.guardFailed code)
      | some s' => .ok s'
    else .error (.outOfFrame code)

/-- **Completeness (the declaration's proof obligation).**  Every admitted operation stays
in its declared frame and its emitted descriptor replays: the dispatcher's two own
refusals never fire, so every refusal of a complete declaration is one of its own names. -/
def Complete : Prop :=
  ∀ ctx op s ps, E.sem ctx op s = .ok ps →
    E.InFrame op (ps ++ E.rotate ctx s) ∧ (S.run s (ps ++ E.rotate ctx s)).isSome

end EffectSpec

/-! ## §3. The registry and the one dispatcher. -/

/-- A registered declaration over a common cell universe `Cell`: its substrate, its
declaration, the role/version/freshness header it checks against the cell (generic per
controller: for the live controller, `selectTarget`'s role and cell law and
`computeTarget`'s version and root, in that order), and how its typed state is read from
and written back to a cell. -/
structure Handler (Ctx Cell : Type) : Type 1 where
  S : Substrate
  O : Type
  R : Type
  spec : EffectSpec Ctx S O R
  header : Ctx → Cell → Except DispatchRefusal Unit
  select : Cell → Option S.State
  pack : S.State → Cell

/-- Sound: `select` and `pack` are inverse both ways (a selected cell IS the packing of
its selection, so nothing outside the selection can be rewritten unseen), and the
substrate is framed. -/
def Handler.Sound {Ctx Cell : Type} (e : Handler Ctx Cell) : Prop :=
  (∀ s, e.select (e.pack s) = some s) ∧
  (∀ cell s, e.select cell = some s → e.pack s = cell) ∧
  e.S.Framed

/-- One registered handler fired on a decoded operation and a cell: header, selection,
the derived executor, the packed post. -/
def Handler.fire {Ctx Cell : Type} (e : Handler Ctx Cell) (code : Nat) (ctx : Ctx) (op : e.O)
    (cell : Cell) : Except DispatchRefusal Cell :=
  match e.header ctx cell with
  | .error r => .error r
  | .ok () =>
    match e.select cell with
    | none => .error (.wrongRole code)
    | some s => (e.spec.exec code ctx op s).map e.pack

/-- Lawful: sound and complete. -/
def Handler.Lawful {Ctx Cell : Type} (e : Handler Ctx Cell) : Prop :=
  e.Sound ∧ e.spec.Complete

/-- The open registry: wire code ↦ entry. -/
abbrev Registry (Ctx Cell : Type) : Type 1 := List (Nat × Handler Ctx Cell)

/-- **The dispatcher** — the only path from a wire code to an effect.  An unregistered
code refuses by name; a registered one decodes its operation with the entry's own codec,
selects its typed state, and runs the derived executor. -/
def dispatch {Ctx Cell : Type} (R : Registry Ctx Cell) (code : Nat) (bytes : List UInt8)
    (ctx : Ctx) (cell : Cell) : Except DispatchRefusal Cell :=
  match R.lookup code with
  | none => .error (.unregistered code)
  | some e =>
    match e.spec.opStream.toLawful.decode bytes with
    | none => .error (.malformed code)
    | some op => e.fire code ctx op cell

/-- The registry the Host dispatches through: codes unique (a shadowed duplicate would be
a silent twin), every entry lawful — the floor obligations as proof FIELDS. -/
structure LawfulRegistry (Ctx Cell : Type) : Type 1 where
  entries : Registry Ctx Cell
  nodup : (entries.map Prod.fst).Nodup
  lawful : ∀ code e, entries.lookup code = some e → e.Lawful

/-! ## §4. `Dispatches` — a predicate on ANY candidate dispatcher. -/

/-- **What it means for `d` to dispatch through `R`**, while the codes in `legacy` are
still hand arms (the migration window; the end state is `legacy = []`).

* `noTwin` — no code is both registered and hand-armed (law 13 as a clause);
* `agreement` — on a registered code and EVERY cell, `d` IS the handler fired;
* `unregistered` — any other code refuses by name;
* `frame` — an admitted registered dispatch leaves every unsealed location outside the
  operation's declared fields unchanged. -/
structure Dispatches {Ctx Cell : Type} (R : Registry Ctx Cell) (legacy : List Nat)
    (d : Nat → List UInt8 → Ctx → Cell → Except DispatchRefusal Cell) : Prop where
  noTwin : ∀ code ∈ legacy, R.lookup code = none
  agreement : ∀ code e, R.lookup code = some e → ∀ (op : e.O) (ctx : Ctx) (cell : Cell),
    d code (e.spec.opStream.encode op) ctx cell = e.fire code ctx op cell
  unregistered : ∀ code, R.lookup code = none → code ∉ legacy →
    ∀ bytes ctx cell, d code bytes ctx cell = .error (.unregistered code)
  frame : ∀ code e, R.lookup code = some e → ∀ bytes ctx cell cell',
    d code bytes ctx cell = .ok cell' →
      ∃ (op : e.O) (s s' : e.S.State), e.spec.opStream.toLawful.decode bytes = some op ∧
        e.select cell = some s ∧ e.select cell' = some s' ∧
        ∀ loc, e.spec.rotated loc = false → e.spec.field loc ∉ e.spec.frame op →
          e.S.read s' loc = e.S.read s loc

/-! ## §5. The engine keystone, the completeness keystone, and their poles. -/

/-- **ENGINE KEYSTONE.**  Over sound entries, the one dispatcher dispatches through its
registry with no hand arms. -/
def EngineKeystone (Ctx Cell : Type) : Prop :=
  ∀ R : Registry Ctx Cell, (∀ code e, R.lookup code = some e → e.Sound) →
    Dispatches R [] (dispatch R)

/-- **COMPLETENESS KEYSTONE.**  Through a lawful registry, every refusal of a well-encoded
operation on a packed state whose header passes is one of the entry's own declared names. -/
def CompletenessKeystone (Ctx Cell : Type) : Prop :=
  ∀ (L : LawfulRegistry Ctx Cell) code e, L.entries.lookup code = some e →
    ∀ (op : e.O) (ctx : Ctx) (s : e.S.State) (r : DispatchRefusal),
      e.header ctx (e.pack s) = .ok () →
      dispatch L.entries code (e.spec.opStream.encode op) ctx (e.pack s) = .error r →
        ∃ x : e.R, r = .refused code (e.spec.refusalName x)

/-! ### The pole data: a two-field toy cell and two entries. -/

/-- Two RAM fields, `false` and `true`, each holding a number. -/
@[reducible] def toyLayout : Layout.{0, 0, 0} where
  Namespace := Bool
  Key := fun _ => Unit
  Value := fun _ => Nat
  discipline := fun _ => .ram

abbrev ToyStore := Store toyLayout
abbrev ToySubstrate := storeSubstrate toyLayout

def toyEmpty : ToyStore := 0

/-- Field `b` set to `n`: an allocation where it is absent, a guarded write where present. -/
def toyWrite (b : Bool) (n : Nat) (s : ToyStore) : List (Store.Op toyLayout) :=
  match s ⟨b, ()⟩ with
  | none => [.allocate b () n]
  | some v => [.write b () v n]

inductive ToyRefusal where
  | tooLarge
  deriving DecidableEq, Repr

def toyRefusalName : ToyRefusal → String
  | .tooLarge => "tooLarge"

/-- Field `false` is `slot 0`, field `true` is `slot 1`. -/
def toyField (loc : Address toyLayout) : CellField := if loc.1 then .slot 1 else .slot 0

/-- Entry A (code 0): set field `false` to `n`, refusing `tooLarge` above 9.  Declared
frame `{slot 0}`; it never leaves it. -/
def entryASpec : EffectSpec Unit ToySubstrate Nat ToyRefusal where
  opStream := StreamCodec.nat
  refusalName := toyRefusalName
  accepts := fun _ => true
  version := 1
  sem := fun _ n s => if 9 < n then .error .tooLarge else .ok (toyWrite false n s)
  rotate := fun _ _ => []
  rotated := fun _ => false
  field := toyField
  amount := fun _ _ => 0
  frame := fun _ => {.slot 0}
  verb := fun kind _ => DeclaredResourceScalar.ordinaryVerb kind
  view := fun _ _ _ => []

/-- Entry B (code 1): `true` writes field `true` (in its declared frame `{slot 1}`),
`false` writes field `false` — OUT of its frame.  The dispatcher must refuse the latter. -/
def entryBSpec : EffectSpec Unit ToySubstrate Bool ToyRefusal where
  opStream := StreamCodec.bool
  refusalName := toyRefusalName
  accepts := fun _ => true
  version := 1
  sem := fun _ b s => .ok (toyWrite b 1 s)
  rotate := fun _ _ => []
  rotated := fun _ => false
  field := toyField
  amount := fun _ _ => 0
  frame := fun _ => {.slot 1}
  verb := fun kind _ => DeclaredResourceScalar.ordinaryVerb kind
  view := fun _ _ _ => []

/-- The ghost of entry A: it reads the same operation as `n + 1`. -/
def ghostASpec : EffectSpec Unit ToySubstrate Nat ToyRefusal :=
  { entryASpec with sem := fun _ n s => if 9 < n then .error .tooLarge else .ok (toyWrite false (n + 1) s) }

def toyEntry {O R : Type} (spec : EffectSpec Unit ToySubstrate O R) : Handler Unit ToyStore where
  S := ToySubstrate
  O := O
  R := R
  spec := spec
  header := fun _ _ => .ok ()
  select c := some c
  pack s := s

/-- **The two-entry pole.** -/
def toyPole : Registry Unit ToyStore := [(0, toyEntry entryASpec), (1, toyEntry entryBSpec)]

/-- The pole with entry A's reading replaced by its ghost. -/
def toyGhostPole : Registry Unit ToyStore := [(0, toyEntry ghostASpec), (1, toyEntry entryBSpec)]

/-- A fail-open dispatcher: an unregistered code falls through to entry A. -/
def toyFailOpen (code : Nat) (bytes : List UInt8) (ctx : Unit) (cell : ToyStore) :
    Except DispatchRefusal ToyStore :=
  match toyPole.lookup code with
  | none => dispatch toyPole 0 bytes ctx cell
  | some _ => dispatch toyPole code bytes ctx cell

/-- An unframed dispatcher: the derived executor without its frame check (a witness, never
shipped — the house pattern of `execHand`). -/
def dispatchUnframed {Ctx Cell : Type} (R : Registry Ctx Cell) (code : Nat)
    (bytes : List UInt8) (ctx : Ctx) (cell : Cell) : Except DispatchRefusal Cell :=
  match R.lookup code with
  | none => .error (.unregistered code)
  | some e =>
    match e.spec.opStream.toLawful.decode bytes with
    | none => .error (.malformed code)
    | some op =>
      match e.header ctx cell with
      | .error r => .error r
      | .ok () =>
      match e.select cell with
      | none => .error (.wrongRole code)
      | some s =>
        match e.spec.sem ctx op s with
        | .error r => .error (.refused code (e.spec.refusalName r))
        | .ok ps =>
          match e.S.run s (ps ++ e.spec.rotate ctx s) with
          | none => .error (.guardFailed code)
          | some s' => .ok (e.pack s')

/-! ### The engine keystone's ATLAS fields. -/

/-- **Satisfiable.**  The pole dispatches through itself, admits entry A's `5` (field
`false` becomes 5), and refuses entry B's out-of-frame `false` by name. -/
def EngineSatisfiable : Prop :=
  Dispatches toyPole [] (dispatch toyPole) ∧
  dispatch toyPole 0 (StreamCodec.nat.encode 5) () toyEmpty =
    .ok (Store.set toyEmpty ⟨false, ()⟩ (some (5 : Nat))) ∧
  dispatch toyPole 1 (StreamCodec.bool.encode false) () toyEmpty = .error (.outOfFrame 1)

/-- **Teeth.**  `Dispatches toyPole` refutes: a dispatcher whose reading of code 0 differs
(agreement bites), a fail-open dispatcher (unregistered bites), a dispatcher without the
frame check (frame bites on entry B), and a code both registered and hand-armed (noTwin
bites). -/
def EngineTeeth : Prop :=
  ¬ Dispatches toyPole [] (dispatch toyGhostPole) ∧
  ¬ Dispatches toyPole [] toyFailOpen ∧
  ¬ Dispatches toyPole [] (dispatchUnframed toyPole) ∧
  ¬ Dispatches toyPole [1] (dispatch toyPole)

/-- **Premise inhabitation.**  The keystone's premise holds of the pole. -/
def EnginePremise : Prop :=
  ∀ code e, toyPole.lookup code = some e → e.Sound

/-! ### The completeness keystone's ATLAS fields. -/

/-- **Satisfiable.**  Entry A is lawful, and through the registry of entry A alone its
refusal surfaces under its own name. -/
def CompletenessSatisfiable : Prop :=
  (toyEntry entryASpec).Lawful ∧
  dispatch [(0, toyEntry entryASpec)] 0 (StreamCodec.nat.encode 12) () toyEmpty =
    .error (.refused 0 "tooLarge")

/-- **Teeth.**  Entry B is not lawful: its out-of-frame operation (refused `outOfFrame`
in `EngineSatisfiable`) keeps it out of every `LawfulRegistry`. -/
def CompletenessTeeth : Prop := ¬ (toyEntry entryBSpec).Lawful

/-- **Premise inhabitation.**  A lawful registry exists: entry A's. -/
def CompletenessPremise : Prop :=
  ∃ L : LawfulRegistry Unit ToyStore, L.entries = [(0, toyEntry entryASpec)]

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

end Minidregg.Effects.Revival
