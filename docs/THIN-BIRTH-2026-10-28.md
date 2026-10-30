# Thin birth: a birth (create) arm for thin consent

Status: **design, statement-first** (2026-10-28, lane/thin-birth). The keystones are stated in
`Kernel/NativeThinBirth.lean` as Props with their ATLAS fields. Proofs and the implementation wait
for the auditor's verdict on the statements. This is a Phase-3 item: the demo runs full consent and
does not wait on it.

## 1. The problem

Thin consent (`Kernel/NativeThinConsent.lean`, frames 230 to 232, `MINI_THIN_CONSENT=1`) is how a
member whose key never touches the box (the remote laptop of `jpriv2.sh`) signs. It reads no Store.
It accepts a Host-proposed signing plan only when everything the plan commits is either signed by
the member, served under the member's grants and bound by a signed root, or kernel-owned and gated.
Today it has arms for invocations and delegations. A birth is refused by name, on the client
(`native/resource-client/src/workspace.rs`, the `create` path, bef3b452c) and in the provider
(`checkPlanThin`: `notInvocation`). `jpriv2.sh` row 19 pins that refusal (d79843207).

Two Host steps stand between what the member wants and what a birth signs. The thin client checks
neither of them today.

1. **Authoring (op 91, `Host/CurrentResourceBirthAuthoring.lean`).** The member writes `source.json`
   (genesis description, template, creator, nonce, resources, funding, fee payer). The Host turns it
   into the intent's draft descriptor with `Host.Json.birthCurrent`, reading three things from the
   Store: the current height (each grant's `notBefore`/`notAfter`), the authority's epochs (each
   grant's `issuerEpoch`/`policyEpoch`) and the placement lineage (a room birth's grant
   `ancestors`). Thin consent's frame 230 signs whatever intent comes back.
2. **Planning (`NativeHost.prepareLoaded`, `.birth` arm).** The planner runs
   `ResourceBirthController.Concrete.prepareDraft` over the Store. It fills the draft's
   `auxiliaryCreates` (the authority's initial-source cells, `PreparedGrantBatch.auxiliaryCreates`)
   and signs one header per branch: factory (role 0), authority (role 1), one allocation per create
   (role 2), one source per Book operation (role 3).

A remote friend must not get delegated full consent: that service is box-local and
SO_PEERCRED-pinned (`consent_proxy.rs:196-233`), and its config pin names the operator's Store
(deploy/shell/README.md:92-107). So the thin arm has to check both steps itself, with no Store.

## 2. Why no Store is needed

The fields of a birth fall into four classes (checked in the tree):

| field of the signed descriptor / request | who decides it | how thin consent covers it |
|---|---|---|
| births (cell ids, kinds, owners, rooms, initial cells), grants' member fields (holder, verbs, scope, ids), initial policies, funding, fee payer, creator, nonce | the member's `source.json`, through the deployed authoring function | **re-derived**: the provider runs the same authoring (`Json.birth`, its own pinned image) and compares bytes |
| `transactionId`, `authorityNullifier`, fee amount, factory id, policy addresses | pure functions of the source and the deployment config (`sourceIdentity`, `quotedFee`, `NativeHostGenesis.policy`) | re-derived by the same authoring |
| height (grant window), issuer epoch, policy epoch, placement lineage | read by the Host from the Store at authoring | **coordinates**: taken from the proposal, **shown**, and gated at admission: issuer epoch exact and window within `birthSlack` (`RootGrantShape`, `BirthWindow`), born policy epoch exactly 0 (`AuthorityGrant.NativeForBirth`), lineage exactly the placement's (`BornLineage`). A wrong coordinate is refused at admission; the member's display names every one it signed |
| `auxiliaryCreates` | the kernel's lowering of the grant batch over the actual authority cell | **kernel-owned**: signed (inside the descriptor bytes), not member-checked, and forced at admission (`PreparedBirth.auxiliaryExact`: equal to the batch's own recomputation) |

Every branch request of a birth (`branchRequest`) is built from the deployment's public pins
(domain, semantics, federation, factory id, factory policy id: all from the config,
`NativeHostContext.validateChecks`) and the finalized descriptor, except five fields: the three
authority coordinates (`subjectKeyEpoch`, `policyEpoch`, `policyRevision`), which thin consent
already takes from the proposal (`checkHeader`), and height and pre-state root, which the plan frame
zeroes (`TypedAuthorizationRequestCodec.planOf`). Every branch's `effectsDigest` is
`sourceEncoding.effectsDigest` of the whole finalized descriptor (`factoryRequest`,
`allocationRequest`, `batchSourceRequest`).

## 3. What the thin client is shown and checks

The new arm (`NativeThinBirth.checkBirthThin`) gets the retained intent, the Host's plan and the
member's own `source.json`. In order:

1. The intent's draft is `.birth draftBytes caps`, an ordinary resource birth. Grain-backed birth
   sources (`GrainResourceBirthHostCodec`), application and session births, and reserve births are
   refused by name (`birthRoute`). They carry peer task pre-states (tool and parent roots) or other
   inputs this arm does not check yet; each is a later arm of the same shape.
2. `draftBytes` decodes to a descriptor with no auxiliary creates (`birthMalformed`).
3. **Authoring check.** The coordinates are read off the draft (`coordinatesOf`). The provider runs
   the deployed authoring of the member's own source at those coordinates and requires exactly the
   retained intent: subject, nonce, observe grants, the draft's descriptor bytes and its source
   capabilities (`draftNotAuthored`). So the intent is the member's source, authored by the
   member's own image, at the shown coordinates.
4. **Plan check.** The plan is this deployment's (`planCoordinates`): its finalized draft is
   `.birth finalBytes caps` with the same capabilities, and `finalBytes` decodes. Its user part
   (`{F with auxiliaryCreates := []}`) re-encodes to exactly `draftBytes` (`birthSourceChanged`).
5. **Slot check.** The slots are factory (0,0), authority (1,0), allocation (2,i) for every create,
   and source (3,j) for every Book operation, in that order (`slotShape`). Every header passes
   `checkHeader` against the member's derivation `birthValues` of that branch from the config's
   public pins and `F` (`headerMismatch`).

What it shows (`BirthDisplay`): the user-part bytes (born cells, grants, policies, funding, fee,
which the client renders) and source capabilities, the coordinates, and the finalized bytes the
headers sign (which add only the kernel-owned auxiliary creates).

## 4. What it signs

The checked headers, as in the other arms: no new signed object. Each header's message is
`signedRequestBytes` of the member's own derivation, with the three authority coordinates from the
proposal. The intent signature (frame 230) also moves behind the authoring check (§6), so the
member no longer signs a Host-authored birth intent unchecked.

## 5. How the Host proves it executes the consented plan

The Host proves nothing new. The binding is in what the member signed and what admission checks:

* the receiver admits a branch only with a signature whose header message is exactly
  `requestBytes` of the receiver's own request (`CredentialSignatureAdmission.Prepared.headerExact`);
* `signedRequestBytes` determines the request up to height and pre-root
  (`signedRequestBytes_eq_iff`), so it fixes `effectsDigest`;
* every branch's `effectsDigest` is the effects digest of the executed descriptor.

So a signed header admitted for a birth of descriptor `d` gives
`effectsDigest(d) = effectsDigest(F)`, so either `d = F` or the two are an `EffectsCollision`
(different descriptors, equal digest: a collision of the deployment's cSHAKE source digest at
exactly those two canonical encodings). The theorems conclude the claim or that named collision;
no hash premise is taken (the PinCollision pattern the auditor accepted for the platform cell). A
Host that swaps the plan after consent, in any field including the auxiliary creates, has no
member signature for any branch of the swapped birth, unless it exhibits that collision.

## 6. How a refusal is named, and the consent wire

New `Refusal` constructors: `birthRoute (what)`, `birthMalformed`, `draftNotAuthored`,
`birthSourceChanged`. The existing `planCoordinates`, `slotShape`, `headerMalformed` and
`headerMismatch` are reused. Each reaches the client as `thin consent refused: ...`, before anything
is signed.

The wire (`protocol/host-operations.json`; the frames are answered by `Host.ClientConsentCore.thin`):

| frame | payload | answer |
|---|---|---|
| **234** thin birth intent (new) | intent, signer, member's source JSON | the intent bytes, after the authoring check |
| **235** thin birth plan (new) | intent, signer, plan, member's source JSON | `{headers, display}` with `display = {birth: {draft, coordinates, finalized}}` |
| 230 / 232 | unchanged for invocations and delegations | a birth the thin birth arm covers (`NativeThinBirth.thinBirthIntent`: not grain-backed) is refused by name ("a thin birth is consented with the member's source: frames 234/235"). This is the law, not a gap: without the source, the authored draft cannot be checked. A grain-backed birth (a provider purse's) has no thin birth path and keeps its intent consent, the provider-route check; `thinBirthIntent_of_checked` proves every birth the arm accepts is one these frames refuse. JPAY6's discriminator row plants both sides |

Client (`workspace.rs` `birth`): under `MINI_THIN_CONSENT=1` the by-name refusal goes. The client
passes its retained `source.json` (the authoring directory's own copy, already pinned by
`sourceSha256`) to the thin birth frames, writes `thin-display.json` beside the plan, and submits as
before. Full and delegated full consent (220 to 222 and the delegated socket) are not touched.

## 7. Keystones (Lean, `Kernel/NativeThinBirth.lean`)

| pole | statement | what it says |
|---|---|---|
| **keystone** | `DisplayIsCommitStatement` | For the executor's own `PreparedBirth` of descriptor `d`, if thin consent accepted `(headers, shown)` and admission matched one accepted header to one of the executor's branch requests, then either `EffectsCollision signed d` or: the authoring at the shown coordinates gives the intent, whose draft is the shown draft and capabilities; `userPart d` is the shown draft; the auxiliary creates are the grant batch's (kernel-owned); the prepared writes are exactly the allocations, the factory's (unchanged), the Book's and the authority's; the newborn writes are the shown creates followed by the kernel's; the authority post is the shown entries over the pre-state; the Book's logical post is the shown batch applied to the pre-Book |
| **teeth** (after consent) | `SwapAfterConsentRefusedStatement` | For an executor birth of any `d'` whose bytes differ from the consented `finalized`: either `EffectsCollision` or no signature the receiver admits for any branch of `d'` carries a header the member consented to |
| **teeth** (before consent) | `SwappedPlanRefusedStatement` | A plan whose finalized user part differs from the intent's draft is refused `birthSourceChanged`; an intent draft that is not the authoring of the member's source at its coordinates is refused `draftNotAuthored` |
| **satisfiable** | `HonestPlanAcceptedStatement` | Completeness: for an ordinary canonical draft the member authored (`author (coordinatesOf draft) = some draftBytes`), the plan the honest planner builds (`NativeHost.prepareLoaded … (.birth draftBytes caps) = .ok plan`) is accepted |
| **premise inhabitation** | `OpenedPinsPublicStatement` | Every opened image's pins carry the config's federation and factory policy id (built from `validateChecks`), so the satisfiable pole has no pins premise. The keystone and teeth take no hash premise: a cSHAKE collision at the two descriptors is a named disjunct (`EffectsCollision`) |

The authoring function is a parameter of the Kernel check (`author : BirthCoordinates → Option
Intent`), since the Kernel cannot import `Host.Json`. The Host instantiates it exactly once, at
the deployed authoring of the member's source (`Host/ThinBirthConsent.lean`: `Json.birthIntentFrom`
over `Json.birth` with the coordinates as its height, epochs and lineage), and the frames call only
that instance. The Host-side completeness (an intent the Store-reading authoring produced
re-authors to itself at its own coordinates) runs through the JSON parser. It is witnessed by the
journey's successful thin birth (row 19), and I do not claim it as a theorem.

The satisfiable pole's pins premises (opened pins equal to the config's) are discharged by
`OpenedPinsPublicStatement`, which needs an invariant on `NativeHost.Opened` (built only by
`validateLoaded`, `validateLoadedFrom` and `restorage`, all from `validateChecks`' pins).

## 8. Relation to DEMO-PREFIX:190 (the "O(1) provider" switch)

DEMO-PREFIX §2 says the O(1) provider "switches on when thin consent's JP2 is green". JP2 has been
green since d79843207 only because row 19 pins the refusal, which is not the condition that
sentence meant. The condition is that a member can live entirely on thin consent: enrol, create,
write, read back, delegate. After this arm, the honest reading of the switch is **JP2 green with
row 19 asserting a successful thin birth (and the lifecycle rows below it restored) and the new
swapped-plan row refused**. The "Consent mode, decided" section still holds for the demo box:
`ConsentAnchor.recheckHeld` already made full-consent propose flat, so turning thin mode on for the
box's own hosted members buys nothing the demo needs. Thin birth matters for remote members, whom
the demo does not serve. This doc does not change that plan text; the integrator updates the plan
when the arm lands.

## 9. Debt and scope

* **The authoring twin.** The box authors births with `Host.Json` (op 91, `Host.Main`), and the
  consent provider, which links `Host.SourceAgreementJson`, re-authors with that module's
  identical `birth`/`birthParts` (`Host.ThinBirthConsent`). The two are a pre-existing twin; if
  they ever diverge, an honest thin birth is refused `draftNotAuthored` (completeness fails,
  soundness does not). The loaded authoring now takes its two epoch projections as data
  (`SourceAgreementJson.BirthEpochs`, `birthAt`); `birthCurrent` is `birthAt` at the loaded image.

* **Restored images.** `NativeHost.Opened.restorage` (dry runs, `Host.DryRun`) copies the pins
  and changes only the Store paths, so a restored image's pins are the original's; the satisfiable
  pole is stated over the Host's own open (`validateLoaded`, which `validateLoadedFrom` equals).
* **No new kernel effect.** The arm is consent-side only. The receiver, planner and authoring are
  unchanged (the authoring may gain one pure entry that takes coordinates as data instead of an
  `AuthState`; it is definitionally the same function).
* Covered scope: ordinary resource births (workspace `create`, op 91). Grain, application, session
  and reserve births stay refused by name in thin mode until their own arms exist.
* The coordinates are shown, not judged: the client does not know the current height or epochs.
  Admission bounds each one (§2), so a lying Host gets a refusal, or, for the height, a grant window
  shifted within `birthSlack` that the member's display names.

## 10. Journey (`native/resource-client/journey.d/jpriv2.sh`)

* Row 19: `create notes declared all[]` under thin consent **succeeds**, and `thin-display.json`
  shows the born cell. The lifecycle rows d79843207 removed (write, read back, delegate, export,
  sponsor import, the tampered/exact `call.bin` pair) come back.
* New row: a swapped plan is refused. The friend's provider gets a plan whose finalized descriptor
  differs from the intent's draft in one born cell (built with the laptop's own Host image), and
  answers `birthSourceChanged`, with no headers.

## 11. Continuation

(Kept current by the lane; read this first after a restart.)

* Worktree `/Users/ember/dev/minidregg-lanes/thin-birth` (lane/thin-birth). Box tree:
  `dregg-ref:/build/lanes/thin-birth` (as user `lanes`: `ssh lanes@dregg-ref`; `runuser` lacks the
  user bus `swarm-build` needs). Scratch and scripts: `/build/lanes/thin-birth-scratch/`
  (`run-scratch.sh FILE` is the seconds-long per-file check against built imports; `build.sh` is
  the closure-locked module build).
* Audit: af7a93e7b8ba729d4, AUDIT.md section 22 on lane/audit-platform: statements ACCEPTED after
  two revisions (named collision instead of a carrier; opened pins from `validateLoaded`), and the
  `validateLoaded`-scoped pins realisation ACKed (no `Opened` field; restored images: §9).
* Proved, `#assert_axioms` clean, per-file on dregg-ref: `display_is_commit`,
  `swap_after_consent_refused`, `swapped_plan_refused`, `honest_plan_accepted`,
  `opened_pins_public` and their lemmas (`Kernel/NativeThinBirth.lean`).
* Wire and client: frames 234/235 (`Host.ClientConsentCore`, `Host.ThinBirthConsent`,
  `protocol/host-operations.json`), mini-sdk `thin_birth_intent`/`thin_birth_plan`, the workspace
  birth path. JP2 rows: row 19 thin birth, lifecycle restored, swapped-plan row.
* Owed: the Host consent modules' build on the box, then JP2 on a candidate world.

### Continuation: the thin write path (JP2 row 22, candidate e89fe7b8b), 2026-10-28

* **Cause.** `NativeThinConsent.checkServed` re-encodes the served store and compares its root
  with the signed root. The Host never serves a cell's blinding entry
  (`narrowPacked_erases_blinding`), and the salts derive from it, so every thin write to a blinded
  cell (every declared cell the friend creates) is refused `servedRootMismatch`. Thin birth is
  fine; the invocation arm's law was wrong.
* **Audited.** AUDIT.md §26 on lane/audit-platform: ACCEPT with the strengthening applied. The
  statements are in `Kernel/NativeThinConsent.lean`, "Served views over salted openings":
  `checkOpened`, `OpeningCollision`, `SealedIn`, `OpenedDisplayIsCommitStatement` (with
  sealed ⇒ post = pre), `OpenedViewRefusedStatement`, `HonestScalarViewAcceptedStatement`
  (declared-object scalar scope; the other kinds are owed, a pole or row each).
* **Proved (per file on dregg-ref, `#assert_axioms` clean):** `opened_display_is_commit`
  and `target_rootOf`, `run_congr_at`, `untouched_of_both_valid`, `checkOpened_ok`,
  `shown_agrees`, `memberPatch_pre_independent`. One tightening after the audit:
  `checkOpened` refuses a pre-reading payload (world, kind definition: `patchReadsPre`) over an
  opening that seals anything (`unsupportedPayload`). The keystone needs it because those member
  patches read the pre-state. Tell the auditor.
* **Done (successor lane, 2026-10-28):** the auditor ACCEPTED the `patchReadsPre` tightening
  (world/kindDefinition payloads require an opening that seals nothing, a full-scope view) and
  asked for its named teeth: `PreReadingSealedRefusedStatement`, proved. Proved per file on
  dregg-ref (lean-ask, `#assert_axioms` clean): `opened_view_refused`,
  `pre_reading_sealed_refused`, `honest_scalar_view_accepted` (with `entries_filter`,
  `openedBytes_items`). `displayTarget` calls `checkOpened`; `checkServed`, `servedBytes`,
  `RootBinds`, `honest_binds`, `mismatch_refused`, `thin_display_is_commit` and the
  `servedMalformed` refusal are deleted. `Display.post` is `Option (bytes × Option root)`: the
  root only when the opening seals nothing (`sealsNothing`); `displayJson` prints `postRoot` only
  then. jthin-consent N1 (narrowed grant on a declared cell) now commits with an opened display
  and no `postRoot`; S2 seals its own write over N1's post.
* **Poles (statements ACCEPTED by the auditor before proof, proved, one per payload):**
  `honest_account_scalar_view_accepted`, `honest_world_view_accepted` and
  `honest_kind_definition_view_accepted` (full scope: the opening seals nothing, so the display
  carries the post root), `honest_content_read_view_accepted`, `honest_kind_read_view_accepted`,
  and `honest_content_stream_write_named` (the honest view passes every opening check and is
  refused `unsupportedPayload` by name; the full-peer provider covers those writes). Helpers:
  `checkOpened_of` (the converse of `checkOpened_ok`), `servedOpening_honest`, `decode_narrowed`,
  `items_none_sealed`, `visible_full`.
* **Verified.** dregg-ref: `Host.ClientConsentCore Host.ClientConsentSession Kernel.NativeThinBirth`
  built (closure-lock, rc 0, peak 3.4 GiB) and `minidregg-client-consent` linked (sha256
  e275bca9...); after merging main 1c789dc7b, `Kernel/NativeThinConsent.lean` checks clean per file.
  hbox, candidate e89fe7b8b with that consent provider substituted
  (`/tank/dregg-build/claude-lanes/thin-birth/cand`, `run-jp2.sh`), main's scripts plus this
  branch's jpriv2/jthin-consent: JP2 PASS (71 rows: row 22, swapped plan 33-37), THIN PASS.
* **JPAY6 rehearsal blocker (2026-10-28), on main as c286143e7.** The 230/232 birth refusal now
  fires only on `NativeThinBirth.thinBirthIntent` (not grain-backed); `thinBirthIntent_of_checked`
  shows it covers the arm. JPAY6 plants both sides (row "discriminator (plant)"). lane-check green on
  dregg-ref. Owed: read JPAY6 (row 23 and the plant) on the integrator's first candidate containing
  c286143e7; a consent binary from current main cannot be substituted into b26630168 (J0's full
  consent dies), so no earlier local run exists.
* **Commuting content appends (contention lane ed3f512f9):** they relax only computeTarget's
  content arm; thin consent refuses every `.content` payload (`unsupportedPayload`), so the keystone
  is unaffected. A future thin content arm owes a commuting variant (post = shown on the patch's
  writes, post = pre elsewhere) in the same commit.
* **dregg-ref closure-lock:** never wrap `lane-check` in `closure-lock`; it takes the lock itself for
  its import build, and the outer lock deadlocks it (twice on 10-28).
