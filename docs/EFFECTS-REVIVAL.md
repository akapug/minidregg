# Effects revival: the derivation engine, made able to state the deployed write path

Lane `lane/effects-revival`, 2026-10-27.  Starting point: the deputy's decision,
`docs/review/2026-10-27-untouched-areas/EFFECTS.md` ("Phase-3 design").  This document makes
that design concrete; `Effects/Revival/Statements.lean` states it.  Statements only: no
proof, no migration, no change under `Kernel/` in this lane.

The owner's ruling this answers: hand-written kernel effects are not acceptable.  A new kernel
effect comes out of a declaration, and the hand arm it replaces is deleted in the same commit.

## 1. What one effect costs by hand today (counted from the tree at `02ee34e8a`)

### 1a. One more declared-resource payload kind

The deployed write path is `Kernel.DeclaredResourceController` over
`Kernel/ResourceTransaction.lean`.  Its effect vocabulary is the `Payload` inductive
(`ResourceTransaction.lean:61`, nine constructors: `scalar`, `content`, `append`, `world`,
`kindDefinition`, `read`, `kindRead`, `computeFunding`, `moneyConsent`).  Each constructor is
handled by a hand-written case split in every function below.  These are the functions that
name a payload constructor, counted with a script over the source:

| file | case-split sites | functions |
|---|---|---|
| `Kernel/ResourceTransaction.lean` | 22 | `Payload`, its `Repr`, `payloadStream` (encode, decode, round-trip proof), `Target.observeOnly`, `Command.targetsWellFormed`, `payloadVerb`, `requestCost`, `Target.layout`, `Target.materializer`, `packTarget`, `selectTarget`, `computeTarget`, `targetPatch`, `appendedEntry`, `Target.contentStore?`, `targetProjection`, `targetWrites`, `moneyEntries`, `prepareOn`, `prepareCompute`, `funding_unvalidated`, `Reject` |
| `Kernel/DeclaredResourceController.lean` | 12 | `targetField`, `targetAmount`, `targetRatchet`, `targetFullFootprint`, `targetFootprint`, `targetProjection_unjoint`, `Target.isRead`, `moneyPolicySlots`, `moneyReadCovered`, `monetaryFootprint?`, `monetaryDebitFootprint?`, `monetaryVerbs?` |
| `Kernel/NativeThinConsent.lean` | 5 | `computeTarget_root`, `memberPatch`, `memberPatch_money_refused`, `Supported`, `targetPatch_split` |
| `Compiler/ObjectiveInvocationLayout.lean` | 3 | `inert`, `step`, `verbatim` |
| `Host/Json.lean` | 2 | `targetPayload`, `moneyConsentJson` |
| `Kernel/NativeObservationController.lean`, `Host/SourceAgreementJson.lean`, `Host/InspectRender.lean`, `Host/GrainOriginSource.lean`, `Host/FnInboxView.lean`, `Compiler/BendWorldPlan.lean` | 1 each | `streamPayload_sound`, `targetPayload`, `draftLines`, `render`, `targetJson`, `effectsOf` |

That is 49 hand-written arms in 11 Lean files for each kind, plus the Rust client's JSON
builders (`native/resource-client/src/workspace.rs`, `world_kind.rs`, `world_prototype.rs`;
`native/mini-sdk/src/contracts.rs`, `explain.rs`).  The most recent kind, `kindRead`
(`73d123885`), touched 20 files (+774/−26, together with the feature it served).  Two of
those arms are twins of each other: `computeTarget` computes a post store and `targetPatch`
recomputes the patch whose replay is that post.  `PreparedTarget`'s `postExact` and the
`Postcondition` of `targetFamily` exist to tie them back together.

### 1b. The activity effect (transfer, commit), the most recent hand-written kernel effect

| commit | what | lines (hand, excl. generated) |
|---|---|---|
| `a913a98c8` | `Effect` (`transfer`, `commit`), `PlanSource.performed`, `decodePlan`'s two arms, `transferVerdict`, `effectOps`, `withEffect`, `commitYield`/`settle` arms, the two-octet verdict wire, ACTIVITY-RECORD v8→v9 (`PersistedCodecTags`), a `funds` binder threaded through six downstream proof files, keystone stated | +716/−133, 10 files |
| `903642a83`, `e6c52a537` | audit pass 11 on the statements | +33 |
| `5e116ec9c` | keystone proved (`Kernel/ObjectiveActivityEffect.lean`) | +244 |
| `2aaf5ec9d` | the audit's four additions (`FundsAgree`, deposit independence, the law's teeth, the write clause) and a new refusal case (`Delivery.purseApart`) | +259/−12, 3 files |
| `2b9de2487` | build fixes | +7/−3 |
| `e6c7ed429` | six world apps re-expressed on the Plan; `check-preview.ts`; native scenarios | +885/−247, 9 files; plus +30,062/−16,881 of regenerated preview cohorts |
| `0fa0eb98c` | native rows, README, DOMAINS | +43/−16 |

That totals about +2,190/−410 hand-written lines over 7 commits and 2 audit passes, plus a
regenerated pins module.  No receiver arm was added: the effect rides the existing session
operations 210–214 (`Host/Main.lean:6228-6261`, `Kernel/NativeHost.lean:2500`).  The
keystone file is 717 lines, all hand-written for this one effect.

### 1c. The codec census

`Compiler/PersistedCodecTags.lean` registers 640 persisted identities and
`Compiler/PersistedCodecShapes.lean` pins 637 fingerprints.  The activity alone owns 28
identities.  §6 describes what a new payload kind does to this census.

## 2. What of the deployed contract a declaration must say

`DeclaredResourceController.step` (`:627`) builds the policy step context from the
prepared tuple: `projectWithCommon` (the target's projection plus the controller's common
slots), the pre cells (`policyPreCell`) and the post state (`policyPostState`, the replay of
the validated patch).  Around it, `admit*` (`:1755-2095`) runs the authority legs:
signatures, `verifyAndAuthorizeLeg` (verb and capability), `fieldsCheck` over the leg's
footprint, `lawLeaf` (the cell's committed law over the projected view), audiences and the
route.  Each item below is either per effect, so it belongs in the declaration, or generic,
so it belongs to the controller once:

| live function | per effect? | in the declaration as |
|---|---|---|
| `computeTarget` arm | yes | `sem : Ctx → O → State → Except R (List Prim)` |
| `targetPatch` arm | yes, a twin of the above | nothing: the descriptor `sem` emits is the patch (`emitted`) |
| blinding ratchet appended in both | yes (content, scalar) | `seal`, `sealed` |
| `targetField`, `targetAmount`, `targetRatchet` | yes | `field`, `amount`, `sealed` |
| `targetFullFootprint`/`targetFootprint` | no: `footprintOf` over the three above | derived |
| `payloadVerb` | yes | `verb` (the authority demand) |
| `targetProjection` | yes | `view` (what the cell's law reads) |
| kind/version/root header checks (every arm) | data per effect, check generic | `accepts`, `version`; the check moves to the dispatcher |
| `payloadStream` arm | yes | `opStream` (its wire tag is the registry code) |
| `Target.layout`/`materializer`/`packTarget`/`selectTarget` | yes | the handler's substrate, `select`, `pack` |
| `targetWrites` (Nock run claim) | no for content and stream (the op's bytes) | derived from `opStream`; `scalar`/`world` need a `runWrites` field (step 4) |
| `appendedEntry` (a fresh cell) | stream only | a fresh-cell output, needed at step 4 (`append`), not for content |
| signatures, read legs, audiences, common slots, route, Objective admission | no | controller, untouched |
| the law itself | no: the cell's own data | not in the declaration (only its `view`) |

## 3. The widened declaration (`Effects/Revival/Statements.lean` §1-§3)

* `Substrate`: a state with guarded primitives (`step : Prim → State → Option State`), a
  syntactic footprint per primitive, an observation per location, and the frame law
  `Framed`.  `storeSubstrate L` is the deployed one (`Theory.Store.Op`, guard
  `Op.Enabled`, footprint `writeAddress?`).  The Book's posting algebra is the second one,
  for transfer.
* `EffectSpec Ctx S O R`: `opStream`, `refusalName`, `accepts`, `version`, `sem`, `seal`,
  `sealed`, `field`, `amount`, `frame`, `verb`, `view`.  Derived from it: `emitted` (the
  full descriptor) and `exec` (sem, then a loud frame check `outOfFrame`, then the replay
  with every guard, loud `guardFailed`).  `Complete` is its proof obligation: neither
  dispatcher refusal is reachable, so every refusal is one the declaration names.
* `Handler` (substrate, declaration, the controller's header check, `select`/`pack` into a
  common cell universe, inverse both ways, so a dispatch cannot rewrite a cell outside its
  selection unseen),
  `Registry := List (Nat × Handler)`, the one `dispatch`, and `LawfulRegistry` (codes
  unique, every handler `Sound ∧ Complete` as proof fields, ATLAS §4's packed-handler
  shape).

### Where this disagrees with the deputy, and why

1. **`sem` emits a patch, not a post state.**  The deputy wrote `sem : Op → State → Except
   Refusal State`.  The deployed path commits a guarded patch.  `computeTarget` and
   `targetPatch` are a twin pair today, held together by `postExact`.  If the declaration
   emits the descriptor and the post is its replay, the twin disappears (law 13), and the
   address-level frame comes free from `Patch.run_frame`.  The deputy's
   `Except Refusal State` is `exec`'s shape, derived.
2. **A context argument `Ctx`.**  The content arm reads the author (subject, kind,
   capability), the operation id (`contentOperation`), the document (`documentOf target`),
   the height and the transaction's source reads (`contentContext`).  None of these are
   the op's payload.  Putting them in `Op` would make `Op` carry a function
   (`Context.sourceRead`) and break the syntactic-payload law (N3).
3. **The frame is fields within one cell.**  The deputy wrote "the cells an op may touch".
   One target is one cell by typing: a declaration's `sem` sees only its own cell's state,
   so it cannot touch another cell.  The frame that has content is the one capability
   scopes bound: `CellField`s (K-FIELDS).  The dispatcher checks the declared frame at run
   time and refuses `outOfFrame` (law 10).  `Complete` proves that check unreachable for a
   lawful declaration, as `prepareCell_ok_of_run` does for `invalidPatch`.  Stream append's
   fresh entry cell is the one case of a second cell.  It needs a fresh-cell output and is
   deferred to step 4.
4. **The authority demand is a verb plus a view, not a `Pred`.**  The `Pred` a write must
   satisfy is the cell's committed law.  The cell's owner chose it and `lawLeaf` judges it.
   It is not the effect's.  The effect contributes the verb its capability must allow
   (`payloadVerb`) and the view the law reads (`targetProjection`).  Admission keeps
   checking the actual footprint against the scope (`fieldsCheck`).  A check of the
   declared frame against the scope before execution would be stricter than today, and
   could refuse commands that are admitted now.  It is left as a later decision, not
   slipped in.
5. **The keystone is a predicate on any dispatcher, with a `legacy` set.**
   `Dispatches R legacy d` takes the candidate `d` as an argument, so a misreading,
   fail-open or unframed dispatcher can be refuted (§4 below).  Defining agreement as
   "`dispatch` equals lookup" would hold by `rfl` through our own reader, which is the
   vacuity the auditor rejected in PlatformCell.  `legacy` names the codes that are still
   hand arms during the migration.  The `noTwin` clause forbids a code from being both
   registered and hand-armed.  The end state is `legacy = []`.
6. **The first declaration is the whole content code, not "append".**  `doc append` signs
   a `Payload.content` target holding `createAtom` plus one `insertRun` per tail run
   (`native/resource-client/src/workspace.rs:5373`, `document_actions`).  It is wire code
   1, and the `content` arm serves all fifteen content actions.  An arm can only be deleted
   for a whole wire code, so the first declaration covers the content action grammar.
   `doc append` is the verb that exercises it.

## 4. The dispatch keystone and its ATLAS fields (`Statements.lean` §4-§6)

| statement | claim | satisfiable | teeth | premise inhabitation |
|---|---|---|---|---|
| `EngineKeystone` | over sound handlers, `Dispatches R [] (dispatch R)` | `EngineSatisfiable`: the two-entry `toyPole` dispatches through itself, admits entry A's `5`, refuses entry B's out-of-frame `false` with `outOfFrame 1` | `EngineTeeth`: refutes the ghost reading (`toyGhostPole`), the fail-open dispatcher (`toyFailOpen`), the unframed dispatcher (`dispatchUnframed`), and a twin (`legacy = [1]`) | `EnginePremise`: every pole handler is sound |
| `CompletenessKeystone` | through a `LawfulRegistry`, every refusal is a declared name | `CompletenessSatisfiable`: entry A lawful, its `tooLarge` surfaces as `refused 0 "tooLarge"` | `CompletenessTeeth`: entry B is not lawful | `CompletenessPremise`: a lawful registry exists |
| `HostKeystone` = `Dispatches [(1, contentHandler)] hostLegacy hostTargetDispatch` | today's target dispatch (payload decode, `selectTarget`, `computeTarget`, patch validation, `packTarget`) dispatches through the one-entry registry, every other payload code in `hostLegacy`; `noTwin` puts code 1 out of the hand arms | `HostAccepted` (the doc-write fixture, owed) | `HostTeeth`: refutes the registry with the seal-less content handler, and code 1 kept as a hand arm too | `HostPremise`: `contentHandler.Lawful` |
| `LiveKeystone` = `ContentAgreement contentSpec ∧ ContentComplete` | the deployed content arm (`computeTarget`, `targetPatch`, `targetField`, `targetRatchet`, `targetAmount`, `payloadVerb`, `targetProjection`) agrees with `contentSpec`; `contentSpec` keeps its declared frame (`contentActionFrame`, per action) | `ContentAccepted`: the live arm admits some content command (intended inhabitant: `Fixtures/NativeDocWriteFixture*`) | `ContentTeeth`: refutes the declaration without the blinding seal (`contentGhost`) and the frame without `annotations` (`contentNarrowed`, `annotate` writes there) | `ContentAccepted` |

`Dispatches R [] (dispatch R)` is the engine's generic theorem, in the same role as the old
`derived_agrees`.  Its content is the discrimination its teeth show.  The deployed content
is `ContentAgreement`: a refinement of today's hand arm, which can be false.  Its clause 2
also tests `contentFrame`, because a live-admitted command that wrote outside the declared
frame would make `exec` refuse it.

`HostKeystone` is the deployed keystone, stated now (the auditor's pass 19): over the
controller's own cell universe (`PackedCell Registry`), against today's target dispatch.
It is **known false today**, by clause: an unknown payload tag is refused `malformed`, not
by name (`unregistered`), and code 1 is still the hand arm, which `agreement` matches only
if `ContentAgreement` and `ContentComplete` hold.  The migration commit makes it true by
rewiring the payload decoder through the registry and deleting the content arms; it is
that commit's gate.  `ContentAgreement` alone would license keeping both arm and
declaration; `HostKeystone`'s `noTwin` is what forbids it.

**The label, said exactly (pass 19):** what is derived after step 1 is the dispatcher, the
frame, the checks and the patch/post relation (one descriptor, its replay).  The content
semantics itself is still the source-owned lowering `ContentResource.run`, reused by
`contentSpec` as it is by `computeTarget`; that is why `ContentAgreement`'s clauses 2 and 5
are near-identities and its real content is clause 4 (refuted by `contentGhost`) plus
`ContentComplete`.  Deriving the lowering itself (its actions as a declared vocabulary
over the hyperdocument layout) is a later rung, not claimed.

## 5. Migration order (each step deletes its hand arm in the same commit)

The commits that follow the opening.  The Host arm belongs to the platform lane (L1,
`lane/lean-critical`).  Per the deputy's seam, one lane holds both sides of each step.

1. **Content (wire code 1, `doc append`).**  The target payload becomes a registered
   operation: an octet code plus that handler's op.  The outer target decoder reads the
   octet and decodes with the handler's `opStream` prefix decoder, exactly as
   `payloadStream`'s tag-1 arm does today, so no byte changes.  The same commit deletes
   the content arms of `computeTarget`, `targetPatch`, `targetField`, `targetAmount`,
   `targetRatchet`, `targetFullFootprint`, `targetProjection`, `Target.layout`,
   `Target.materializer`, `packTarget`, `selectTarget`, `Target.contentStore?`,
   `targetWrites`, `payloadStream` and the `Repr`, and with them `Effects/EffectSpec.lean`
   and `Effects/Placeholder.lean`.  The old engine's `moveEffect` is over the undeployed
   `KernelState`.  Its `derive` is superseded by `Substrate.run`, which is the descriptor
   replay, so keeping it would leave a twin.  The gate is `LiveKeystone` plus
   `HostDispatches` with `legacy` shrunk by 1.  The Host presentation arms
   (`Host/Json.targetPayload`, `SourceAgreementJson`, `InspectRender.draftLines`,
   `FnInboxView.targetJson`, `GrainOriginSource.render`) also need a face from the
   declaration.  **Open:** either a `json` codec field on the declaration, or a JSON layer
   over canonical op bytes.  If neither lands in step 1, those five arms stay as twins,
   and step 1 is not done.
2. **Transfer (activity `Effect.transfer`).**  The substrate is the Book: `Prim =
   CanonicalResourceKernel.Operation`, `step` the floor-guarded posting, `writes = {(source,
   asset), (destination, asset)}`, `field = balance asset`.  `sem` is `transferVerdict`
   over `(config, funds, reserve, written)` as `Ctx`, returning
   `Except EffectRefusal (List Operation)` with `unfunded`, `reserved`, `closed` by name.
   `commitYield`'s `performed` branch dispatches through an activity registry (the same
   `Handler` type, over the activity's turn cell).  Deleted in the same commit:
   `Effect.transfer`, `effectOps`, `withEffect`, the transfer branch of `commitYield`, and
   `ObjectiveActivityEffect.lean`'s Performed/Refused statements for transfer, which become
   instances of the generic agreement plus the activity's own agreement.
3. **Commit (activity `Effect.commit`).**  The substrate is the object's declared state.
   `sem` is `stateWrite`, and its refusal is the object's law (`objectWrite reason`).
   This is the one effect whose refusal is a law judgment inside `sem`.  The declaration
   names it as a refusal and does not move the law into the declaration.  Deleted in the
   same commit: `Effect.commit`, its `decodePlan` arm, and the commit branch of
   `commitYield`.
4. Then the remaining declared-resource codes, each with its arms deleted: `append` (2,
   needs the fresh-cell output), `world` (4) and `kindDefinition` (5) (need `runWrites`),
   `scalar` (0), `computeFunding` (6) and `moneyConsent` (8) (their footprint override,
   `monetaryFootprint?`, becomes a declared `amount`), and the observe-only reads (3, 7),
   which are declarations with an empty `sem` and the observe verb.

## 6. What the codec census and regen must learn

Today: adding a `Payload` constructor changes `payloadStream`.  That moves the fingerprint
of `NativeProtocolFrames.commandFrame` (`"DREGG/RESOURCE/TRANSACTION" ++ [14]`) and of
`familyCommandFrame` (`++ [15]`).  Both frames carry a raw version octet, and
`scripts/codec-shapes-regen.py` cannot bump a raw octet: it exits 2.  The bump is then a hand
edit across Lean and Rust, and every pin nesting the frame moves.  So adding an effect is a
flag day on the transaction frame.

To make adding a declaration a mechanical bump:

1. **Registry-derived identities.**  Each handler's `opStream` is its own persisted
   identity (`DREGG/EFFECT/<NAME>/vN`), declared by the registry entry, not by a hand
   `@[persisted_codec_tag]` line.  The census enumerates the registry as part of the
   reachable set, and `PersistedCodecTags` gains those entries from it.
2. **The table is not in the frame's fingerprint.**  The transaction frame's fingerprint
   hashes the dispatcher, not the registry list.  It is paired with a proved
   `Registry.Extends R R'` (every old code keeps its handler, so every old byte string
   decodes to the same value).  Adding a code is then a compatible extension: the frame
   does not move, a new identity and pin appear, and regen emits them.  Changing a
   handler's codec moves only that handler's `/vN` identity, which regen already bumps
   mechanically.
3. **Raw-octet bumps.**  For the frames that keep a raw octet, regen learns
   `"P".toUTF8.toList ++ [n]` → `[n+1]` in Lean and in the Rust spellings, instead of
   exiting 2.
4. **Wire neutrality of step 1** is a check, not an assumption.  The registry code is one
   octet, the same as `payloadStream`'s tag.  It is not `StreamCodec.nat`, which encodes
   digits plus a 255 terminator, so a `nat` code would change every target's bytes.

## 7. Checking

Nothing in this lane runs Lean on the Mac.  Check command in a warm tree on dregg-ref, from
the tree's root:

    swarm-build lake lean Effects/Revival/Statements.lean

(`lake lean`, not `lake env lean`: the lakefile's `leanOptions` and `moreLeanArgs` apply.)
`Effects/Revival/Statements.lean` is not yet imported by `Effects.lean`.  It joins the CI
closure (law 5) in the commit after it elaborates.

## 8. Continuation

State at the first push:

* Done: this document; the statements file; the auditor's pass 19 (lane/audit-platform
  `3fc181cae`): engine, completeness and `ContentComplete` cleared for proof; its two
  changes applied (`Handler.Sound` gains the converse `select cell = some s → pack s =
  cell`, agreement now holds on every cell through `Handler.fire`; `HostKeystone` stated).
  Unchecked: the integrator elaborates it in `/build/lanes/integ8/src` after its regen.
* Next: send the revision to the auditor; then prove: first the pole witnesses (decidable over
  `toyLayout`), then `EngineKeystone` and `CompletenessKeystone` (generic), then
  `ContentAgreement` (unfold `computeTarget`'s content arm, `prepareCell_ok_of_run`,
  `Patch.run_append`) and `ContentComplete` (per action, by the lowering's write sites);
  the fixture inhabitant of `ContentAccepted`/`HostAccepted` is owed.
* Auditor's addendum (accepted at `3dac92b91`), two proof notes:
  - `HostPremise`'s `pack (select cell) = cell` needs `CellState.materialize
    contentMaterializer value.logical = value`.  `Materialized` is a one-field structure
    (`mk :: logical`, `Theory/CellState.lean:47`), so this is structure eta.  Prove it
    first anyway.
  - `HostTeeth`'s ghost clause needs an admitted command whose seal is non-empty.  It rests
    on the same doc-write fixture `HostAccepted` owes.
* Risk to watch: `contentActionFrame` is a declared table.  If an action writes a field
  the table omits, `ContentComplete` is false, and the fix is to the table, after
  checking which addresses the lowering writes (`ContentResource.step`).
