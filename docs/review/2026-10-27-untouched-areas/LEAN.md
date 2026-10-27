# The Lean tree the sprint never touched

Scout report, 2026-10-27, against `origin/main` 7151d2bf (worktree `lane/glm-lean-scout`). Companions: `docs/review/2026-10-27-blind-spots/BLIND-SPOTS.md` (Sweep 1 supplied the untouched list and line counts). "Deployed reach" is the `Host.Main` import closure, recomputed here with `scripts/lean_imports.py` over `git ls-files` (the ceiling artifact `scripts/gates/host-closure.max`, measured at eb78e6be, agrees: Host 88, Kernel 415/567, Compiler 160, Theory 108/180, Pred 7/11, Selvage 12/153, Effects 0, Assurance 0, Verify 0/12, Fixtures 0/5, TokenCensus 0/5). "Keystones" counts the ATLAS law-2 pole discipline: files declaring `satisfiable` / `teeth` / premise-inhabitation. All work read-only; nothing was built.

## world/ — the Objective Bend authoring corpus (46,096 lines, 56 files)

Not Lean: sixteen domains of `.obend` authoring (`world/dues/StandingDues.obend`, bounty, ballot, market, station, story, workshop, …), each with a README naming its laws and a `preview-cohort.json` of expected rows. It is the product's application content, and it is gated: the `world-cohorts` gate runs every cohort through the Lean front end with a self-test that must go red (`scripts/check-world-cohorts.sh:8-14`). But its evidence class is stamped on every README: "executed in the effect-free preview (`tests/objective-bend-source/check-preview.ts`); **not native**" (`world/dues/README.md:2`). Last substantive commit dcab86da 2026-10-08 ("compare nine compact semantics capsules"); nothing since. Theorems: none here — the named laws (`DuesCatchUpStopsAtDue`, `DuesActivityCatchUpPaysThreeNotFour`) are preview-executed, not proved. Its Lean shadow (`Kernel/World*` 7/11 reached, the `world-sim` exe gated in `scripts/pipeline/merge-gate-checks.sh:82`) runs, but no `.obend` domain ever reached a native admission.

**Verdict: RESCUE.** Surface: the app market on demo.dregg.online. Smallest wiring step: admit ONE domain (dues is the best-told) through `Kernel.ObjectiveBendNativeAdmission`'s native path — the same prepare/admit the Fixtures replay proves works — so a stranger meets a world app, not a test artifact.

## Verify/ — named verification gates and diagnostic exes (1,690 lines, 11 files)

`Verify.lean:1`: "Named verification gates; diagnostic programs have separate targets." Four `lean_exe` roots live here (`lakefile.toml:210-226`: `GenericSimplexHarness`, `GenericSimplexLogReopen`, `GenericSimplexLoad`, `NativeJointSourceFixture`); `JointDecisionRecovery.lean` is an `#assert_axioms` audit ("no closed-case #guard replaces a theorem", line 4). Zero theorems by design; zero pole-bearing files. Deployed reach: none from `Host.Main`; the research umbrella (`Minidregg.lean`) elaborates it, so the axiom audits run in census builds. Last substantive commit 3b2aa109 2026-10-27 — the sprint's only touch deleted bookkeeping. Named defect: **no gate executes the four exe programs.** The python simplex tests drive `testing/generic-simplex-operator.py`, not these binaries; grep across `scripts/`, `testing/`, `pipeline/` finds no runner for any of the four names.

**Verdict: REPAIR.** The harnesses that exercise Generic Simplex views and the joint-source fixture compile and then are never run — ATLAS law 8 (a gate that cannot go red is not a gate) and law 6 (wire-first) both name this. Smallest step: one `merge-gate-checks.sh` row per exe, running it and checking a pass marker, the way `check-world-sim` already does.

## Effects/ — the open handler registry, carved and parked (436 lines, 2 files)

`Effects/EffectSpec.lean:1-10` is "the DERIVATION ENGINE's first declaration (ATLAS §7 keystone)": one `EffectSpec` declaration from which the IR term, the executor and the descriptor are all derived by initiality, agreement and faithfulness free. `Effects/Placeholder.lean:3-10` names what remains: the full declaration vocabulary, the open registry + dispatch executor, the weld to the emit path, frame/reject teeth, the witness generator — `[EFFECT-registry]`. Nine theorems, two pole-bearing files — this IS keystone-shaped work. Deployed reach: `Deployed.lean` imports `Effects` (so the deployed umbrella builds it), but zero modules of it sit in the `Host.Main` runtime closure: the host dispatches effects without the registry. Last substantive commit 423efed1 2026-08-13 — the Selvage rename; two and a half months quiet.

**Verdict: RESCUE.** The registry is the carve that makes "everything derived" true of the effect path, and it is the derivation engine's own flagship. Smallest wiring step: declare one real effect in `EffectSpec`'s vocabulary and dispatch it through the registry behind one existing shell verb, deleting that verb's hand path as it lands (the derived path is the only path).

## Pred/ — the ONE predicate algebra (4,508 lines, 10 files)

`Pred/Core.lean:1-6`: the foundational policy object, AST-only by design law, "no opaque functions anywhere in the policy path." This area is the healthiest of the nine: 246 theorems, the host reaches 7/11 modules (the deployed policy path runs `Pred`), and `Pred/Satisfiable.lean` is itself the pole instrument — "does a law admit ANY step? A witness or a certificate, never a bare claim" (lines 1-4), with `Pred/Placeholder.lean` and two views (`BoundedQuantifiedView`, `CoordinationDial`) the only unreached files. Last substantive commit c9c78525 2026-10-07 (`Pred.sumEq`, the bank tooth as journey D4). Four files carry satisfiable-pole declarations.

**Verdict: RESCUE (small).** Not broken — orphaned at the edges. Smallest wiring step: land `BoundedQuantifiedView` into the committed-policy reflection it was carved for (`Minidregg.lean` already roots `Compiler.BoundedQuantifiedPolicyAdmission`, which the host does not reach), or fold `Placeholder`'s remainder into a named residual the way `Effects/Placeholder` does.

## TokenCensus/ — the private-constructor census (1,000 lines, 4 files)

`TokenCensus/Core.lean:1-8` is an instrument built on a measured wound: in Lean 4.30 `private mk` is access control on names, not terms — `by constructor` forges the token (measured 2026-10-07, lane kn2-pay-family). The census runs `#assert_token_census` over the research umbrella against `TokenCensus/Table`, "every private constructor, minted only at home, every row reviewed" (`TokenCensus.lean:1-3`). Zero theorems by design; its teeth are per-row plants that "run inside `lake build TokenCensus`" (`scripts/pipeline/instruments.tsv:7`) — always on, self-red-proving. Last substantive commit d540d0b3 2026-10-17 ("green on its merits — the 70 faults of batch 2 closed row by row"). Alive and load-bearing; a stranger just never sees it.

**Verdict: RESCUE (visibility only).** Smallest wiring step: one row on the web `/registry` or status page quoting the census count and its date — the instrument that makes "proof-native" non-vacuous deserves a public number.

## Fixtures/ — recorded runs, replayed in Lean (653 lines, 4 files)

`Fixtures.lean:1-5`: a module here "re-runs something a native process DID … through this tree's code"; its data regenerates from a run, so it goes red whenever the implementation moves under the recording. `NativeAcceptedFixture.lean:1-10` replays the FIRST native Objective acceptance (`objective-first`) over its Store prefix. Gated: the `native-transcripts` gate re-submits the recorded verifier transcripts and the Fixtures replay, with a flipped-signature-byte control (`scripts/local-gates.sh:23-26`). Thirteen replay theorems; no pole files (the recording is the witness). Last substantive commit cda088d3 2026-10-17 (the move to its own library).

**Verdict: RESCUE (grow it).** The library replays exactly one moment of the system's life. Smallest wiring step: record a second admission from a surface the demo actually opened this week — a pay-law genesis or a Discord-joined member's first turn — so the replay corpus tracks what strangers actually did.

## Assurance/ — 1,851 apex theorems the Host never imports (59,842 lines, 150 files)

`Assurance.lean:1-6`: "the only lawful home for cross-boundary apex theorems" — kernel objects may meet proof-system objects here and nowhere else. Deployed reach: zero from `Host.Main`; the deployed umbrella keeps exactly three files (`Deployed.lean`: `EvaluatorAudit`, `NockDoorAudit`, `StoryLaw`). The gate's own preamble states the exposure: "A theorem in a module outside that closure is about something the Host never runs" (`scripts/check-host-closure.sh:5-7`). Of 1,851 theorems, 44 files carry teeth, 8 satisfiable, 10 keystone headers — the pole discipline is present but thin for the size. Last substantive commit cbae0853 2026-10-27 (keys-store merge; the sprint's four touches were law-file edits riding merges). Plan C2 already rules the future: "census-only Assurance module by module" (`docs/DEMO-PREFIX-2026-10-26.md:281`).

**Verdict: MOVE for the proof-system apexes (C2, per module, after the census), REPAIR the label meanwhile.** The repair is honesty about the split: the site and tour may claim only what the deployed umbrella (three audits) carries; the research umbrella's claims belong to the research repo. Smallest step: run the C2 census now and publish the deployed/research line.

## Selvage/ — the proof system (78,130 lines, 152 files) — confirmation only

Plan C2 moves it: "140 Selvage modules outside the host + importers (109,639 lines, no exe depends on them) to zkml-research … split `Compiler/Tower256CshakeMerkleController` so the host needs no Selvage, as `Deployed.lean` claims" (`docs/DEMO-PREFIX-2026-10-26.md:281`). Confirmed against the tree: 12/153 modules in the host closure, exactly the cSHAKE→Tower256 chain `Deployed.lean`'s Residual names (7,488 lines, measured 10-26); 2,583 theorems, 63 files with satisfying poles, 97 keystone headers — the pole discipline's best-practiced area (357273ab, 2026-10-14, "26 families with named poles"). **Verdict: MOVE, per C2, unchanged.**

## Theory/ — candidate-independent core, split by the closure (86,731 lines, 180 files)

`Theory.lean:1-6`: the metatheory of any system built this way, Mathlib + Theory only, boundary-enforced and green. The host reaches 108/180. The 72 unreached files are one subject: the zkML/FHE research programme — `Bfv*` (nine files; `BfvRing.lean:1-5`: "the noise model on the ACTUAL ring R = ℤ[X]/(X^N+1)"), `BendMasking*`/`BendQuotient*`, `AdditiveNTT*`. The sprint's four touches were the deployed half (AxiomPin, the cSHAKE kernels behind `@[extern]`). Last substantive commit e7a405f5 2026-10-27. 3,572 theorems; 35 files with teeth, 16 satisfiable.

**Verdict: MOVE the unreached 72 with Selvage (they are C2's zkml-research cargo); keep the rest.** No defect named: the boundary gate holds and the reached half is under active, deployed work.

## Kernel/ — beyond the platform seam (569 files, 212,527 lines, 6,878 theorems)

The sprint's 15 files were all platform cell, job money, consent, default law: `Application*` 138/146 reached, `Fn*` 42/45, `Pay*` 31/34, plus `Grain`/`Seat`/`Carried`/`Capability` fully in. The untouched families, by reach:

- **`Generic*` 6/33 — Generic Simplex, an executable BFT consensus** after arXiv:2609.32985 (fixed n=3f+1 committee, past views active, exact block ancestry; `Kernel/GenericSimplex.lean:1-6`). Last commit 2e055e37 2026-10-06, green with named poles over a real committing run. This is the demo's promised second node (blind-spots A9, planned, no owner) sitting 27 files deep with no runtime wire.
- **`Contracts/` 0/7** (Cuts, Futures, Identities, IntentVectors, Intents, Refinements, Snapshot; canonical-codec work, e5cc0aa8 10-14) — entirely unreached.
- **`Room*` 1/8** — `RoomBirthGate`, `RoomKick`, `RoomRelease*` (admission/authority/lineage/current/intent). Rooms are the north-star cells for helm; release and kick never run (331107da 10-14).
- Partially reached: `Hyperdocument*` 2/8 (K-INDEX/K-HISTORY-READ, 888e837c 09-30 — the oldest family in the tree), `Content` 2/6, `Domain`/`Provider` 2/5, `Private` 1/5, `Turn` 4/8, `Joint` 11/16, `Native` 19/27, `Objective` 23/32, `World` 7/11.

Keystones: 18 files with satisfiable, 30 with teeth across 6,878 theorems — mostly plain settlement/conservation lemmas by design; the poles concentrate in lifecycle/admission files. Overall last substantive commit 2435eb59 2026-10-27 (FB2 docstrings).

**Verdict: RESCUE for `Generic*` and `Room*`; MOVE nothing here.** Simplex: smallest step is running `Verify.GenericSimplexHarness` on the build box and gating it (see Verify/) — the wire to a second node is A9's lane. Room: smallest step is one birth→kick→release journey row over the existing verbs.

## The five that matter

1. **Kernel/Generic\* (Generic Simplex)** — an executable consensus with no runtime wire and no gate that runs its harnesses; the second node a stranger is promised depends on it. Smallest honest thing: gate `Verify.GenericSimplexHarness`'s run (one merge-gate row) before any node work; lane class: protocol (lean-critical).
2. **world/'s native gap** — 46k lines of authored apps strangers can only meet in a preview; the market has no world app. Smallest honest thing: admit one domain (dues) natively and list it; lane class: app-market.
3. **Assurance's zero host-reach** — 1,851 apex theorems about a Host that imports none of them; the proof-native claim is currently unfalsifiable from the deployed set. Smallest honest thing: run the C2 census and publish the deployed/research split; lane class: census/docs (fae).
4. **Effects' parked registry** — the derivation engine's first declaration, 2.5 months quiet, host dispatching around it. Smallest honest thing: one effect through the registry behind a shell verb; lane class: lean-critical.
5. **Room release/kick (1/8 reached)** — the cell lifecycle of the north-star substrate never executes. Smallest honest thing: one room lifecycle journey row; lane class: journey/web.
