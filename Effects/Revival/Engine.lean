/-
# `Effects/Revival/Engine.lean` — the widened declaration, the registry, the dispatcher, the
engine and completeness keystones, STATED

§1-§5 of the statements (`docs/EFFECTS-REVIVAL.md`).  Candidate-side but kernel-free: it
imports only `Theory.Store`, `Theory.TypedAuthorization` and the stream codecs, so it and its
proofs build on a small closure.  The live keystones over the deployed controller are in
`Effects.Revival.Statements`, which imports this file.
-/
import Theory.Store
import Theory.TypedAuthorization
import Compiler.Tower256ConcreteBackend

namespace Minidregg.Effects.Revival

open Minidregg.Compiler.Tower256ConcreteBackend
open Minidregg.Theory
open Minidregg.Theory.Store
open Minidregg.Theory.TypedAuthorization

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

/-- The toy entries' verb: each kind's ordinary write verb. -/
def toyVerb : (kind : ResourceKind) → Verb kind
  | .object => .mutateObject
  | .account => .transfer
  | .program => .installProgram

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
  verb := fun kind _ => toyVerb kind
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
  verb := fun kind _ => toyVerb kind
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

end Minidregg.Effects.Revival
