# Platform cell: state (2026-10-27, third handoff)

`lane/lean-critical` = the commit adding this file (worktree
`/Users/ember/dev/minidregg-lanes/lean-critical`). Lanes do not build or validate
(COORDINATION §4, c44b7d5be): reason each change through, push, and fix forward the reds
the integrator sends with file:line. Merge origin/main before each push.

## Done (L1)

| sha | what |
|---|---|
| c385eed0, 835617b4 | `Kind.platform` (tag 21, schema 91020), the install receiver |
| 7e39fe90 | audit pass 4 (a): `Context.encode` = the signed frame (`Moment.frame`); `source`/`pins`/`sourceCovers`, `Context.binds` with `PinCollision`; `PlatformCellLayout.Reachable` + `controller_stays`; `platform_written_only_by_install`; `receiverDecides` on any reachable loaded cell; `signed_command_admitted` (real codecs + recorded verdict); the custodian cosigns the frame. Pass 12 closed coverage and the real-signature pole |
| c0b2d6ab | pass 12 (2): `Context.height`, `height ≤ validUntil` in `Admits`, `expired_refused`, `Observed.unexpired` |
| ccc11961 | replay arm `NativeAdmission.platformInstall`, TurnCensus row (census kind `platform`, `Ctor.all_length` 52), Host ops 240–243 (routes empty = Host stdio; the operator socket route is L2's in transport.rs), 240 in `consent_exempt` |
| bc88a5ab | genesis frame v8: the platform cell seeded (`genesisRecord`, `platformCell`, `platform_seeded` = pass 12 (1) genesis half); O61: `clockControlCapability`, `ClockLaw.controlClause` in the clock law (ruled), `clock_control_present`, `clock_control_cannot_tick`, poles; genesis JSON `clockControlCapability` + `platform {ownerBudget, lifetime, grainBirthTariff, completionCustodianKey}`; writers updated (genesis.sh, example params, jpay-e2/e3/e4/v2/3/4, workroom/provision.sh) |
| 2b521b2b | audit pass 15: the clock law is `.any [clock writes (monotone ∧ tick/pay), controlClause]`, `controlClause` = controller ∧ management verb ∧ no `clock/now`/`clock/slot` slot (`absent s = .not (.eqSlots s s)`); `controlClause_clock_false` (management is never a clock write); `pole_controller_advance_refused`, `pole_stranger_install_refused`. bc88a5ab's clause sat under `.monotone`, which fails closed on an install step (no clock slots), so it would have refused the controller's install |

## Open

- The auditor (af7a93e7b8ba729d4) reads 2b521b2b (ClockLaw.lean :110 `controlClause`, :118
  `clockPredicate`, :147 `controlClause_clock_false`, :157 `clockPredicate_eval`, poles :334ff).
  Premise put to it, fail-safe: install, revoke and delegate steps carry no `clock/*` slots (if
  one did, management would be refused, never widened).
- Integrator: codec-shapes regen (the `GENESIS-SOURCE/v8` pin carries the v7 fingerprint;
  `DREGG/PLATFORM/PLAN/v1` may want a pin). Genesis writers that lacked `payControlCapability`
  since v7 also lack the v8 fields (acceptance.sh, application-, authority-, selected-release-
  acceptance.sh, grain-runtime/acceptance.sh, jpay2.sh, jpay6.sh, scripts/fn-e1e2/setup-mini.sh).
  dregg-infra's demo genesis-params needs `clockControlCapability`.
- Nothing of 7e39fe90..bc88a5ab was built by this lane; expect reds from the cut and fix them
  forward. Likely spots: `Moment.frame_effectsDigest` (`simpa [planOf]`),
  `signed_command_admitted`, `Config.ofWire_toWire` (22 fields, grain case split),
  `ClockLaw.clockPredicate_eval`, `controlClause_clock_false`, the regress proofs (simp over the
  new `.any` shape), `clock_ticks_only`.
- Pass 12 (1), the install half: a theorem over the durable history that every platform cell
  the Host loads came from genesis and install patches (the writers are proved; the induction
  over the replayed log is not stated yet).

## L1c (lane/lean-audit-c) owns

Audit (c) (design below), then births priced from the cell (read `recordOf` of the loaded cell
in place of `config.tariff`, `grainBirthTariff`, `completionCustodianKey`, template budget and
lifetime; the cell in the birth's read guards; `BirthsReadCurrent`, `BirthQuoteCurrent`), then
`Intent.credit` in `DurableCommitProtocol` with ops 244–247.

## Audit (c) design (for lane/lean-audit-c, L1c)

Today `law.admit … = none` in `Pending.admitBranch` (Kernel/ResourceBirthPolicyController.lean,
the `| none => .error .policyRejected` arm at about line 1630) also covers the address,
membership and request-binding failures of `ComposedPolicyAdmission.admitWithCheck`, and the
compiled-law range and cast checks. So `.policyRejected` does not mean the law refused, and
`PlanPassNotLawRefused` is false as stated. The design:

1. `admitBranch` runs `ComposedPolicyAdmission.bind config wanted.2 evidence law membership
   epoch revision` first (Compiler/ComposedPolicyAdmission.lean, `bind`, `Bound`). On `none`
   it refuses with a new `Reject.policyBinding`. It then checks the compiled law's verdicts
   on the branch step, each refusal named by a new constructor: `supported` →
   `.policyUnsupported`, `inputsInRange` → `.policyInputRange`, `castInjOn` →
   `.policyCastAlias`. Only then does `law.admit` run, and its `none` (`.policyRejected`)
   is the law's verdict alone. The authorization term is unchanged (still `law.admit`).
2. `Pending.factoryVerdict` becomes supported ∧ inputsInRange ∧ castInjOn ∧ eval, read off
   `(pending.branchConfig .factory).resolve?` on `pending.branchStep .factory`. Note
   `(branchConfig b).step = branchStep b` holds by definition (`PhysicalLawResolution.config`).
3. `PlanRefusalSound`: a verdict of `some false` makes `BranchAccepted pending .factory`
   empty. This follows from `BranchAccepted.law_admits_step` (about line 1658) and the uniqueness of
   `loadTarget`'s `.ok` graph against `PreparedLaw.graphExact`. For the range and cast cases,
   acceptance implies `compiledLawAccepts`, hence both checks.
4. `PlanPassNotLawRefused`: a verdict of `some true` means `admitBranch .factory` never answers
   `.policyRejected`. Past `bind`, `Bound.verifies_iff_eval` (ComposedPolicyAdmission.lean,
   with `PreparedLaw.verifies_iff_eval`, `lower_complete`) turns the verdict into
   `config.verifies … law.witness = true`, and `Bound.admit_of_verifies` gives `some`.
   State the converse too: `.policyRejected` implies a plan verdict of `some false`.
5. `NativeHost.birthRefusal` (Kernel/NativeHost.lean, about line 839) names the range and cast
   refusals as `invokeRefusal` does (`PreparedPolicyLeg.rangeRefusal`/`castRefusal` in
   Kernel/PreparedInvocationDiagnostics.lean, through `ComposedLawDiagnostics.publicRefusal`).
   It also surfaces a `prepareDraft`/`preparePending` error as a named refusal instead of
   `.toOption` passing silently.
6. The keystones and `factoryVerdict_congr` sit at the end of ResourceBirthPolicyController.lean
   (`Pending.factoryVerdict`, `PlanRefusalSound`, `PlanPassNotLawRefused`); extend them there.
   Refusals reach the Host as `repr reason` text, and the new constructors only change that
   text. The birth Reject has no exhaustive match outside its file (GrainResourceBirthAdmission
   wraps it as `metadata reason`).

## L1c state (lane/lean-audit-c)

Audit (c) is pushed, not built. Under ember's no-build rule the integrator elaborates it and
routes any reds here.
- `Kernel/ResourceBirthPolicyController.lean`:
  - New `Reject` constructors: `policyBinding`, `policyUnsupported`, `policyInputRange`,
    `policyCastAlias`. They are not admission constructors, so the census and
    host-operations.json are unaffected.
  - `planVerdict` (supported, range, cast, eval) and `Pending.judgeBranch`: epoch and
    revision, resolve, `bind` (refused as `policyBinding`), the three compiler verdicts, then
    `law.admit` (refused as `policyRejected`, the law's verdict alone).
    `Pending.admitBranch` now calls `judgeBranch`, and its refusal order is otherwise unchanged.
  - Proved: `admit_some_of_bind`, `planVerdict_of_verifies`, `BranchAccepted.planVerdict_true`,
    `Pending.judgeBranch_policyRejected`, `Pending.admitBranch_policyRejected`, and the
    keystones `planRefusalSound`, `planPassNotLawRefused`, plus the new converse
    `lawRefusalDisclosed` (`policyRejected` → verdict `some false`).
  - Also new: `Pending.factoryRefusal` with `factoryRefusal_eq_none_iff`. `factoryVerdict`
    is now `resolve?.map planVerdict`. `factoryVerdict_congr` was re-proved.
- `Kernel/NativeHost.lean` `birthRefusal` (body only):
  - It names a noncanonical draft, a `prepareDraft` error and a `preparePending` error, and
    an unresolved factory law.
  - It judges through `Pending.factoryRefusal`, so range, cast and unsupported refusals are
    disclosed like a law refusal (`publicRefusal`, as `invokeRefusal` does).
- Audit pass 16 (lane/audit-platform 90ec46ab), two items owed:
  - **Poles: owed as Lean witnesses.** A concrete `Pending` with an accepted factory branch
    needs a signed, loaded image, and the `WindowExample` descriptor is template-level only.
    For now `scripts/kn2/neutral-birth.lean` checks both poles on the deployed path: the
    control and the `birth/<id> = root` law have a plan that passes and they commit; the
    `root + 1` law has a plan that refuses and is refused `Reject.policyRejected`.
  - **Disclosure: checked.** The `preparePending` refusals carry no payload. Of the
    `PreparationReject` refusals, only `room` does: the requester's own room id and the
    room gate's refusal, which is already grant-filtered (`birthRefusedOutsideGrant`,
    FIX-DISCLOSE). `NativeHost.prepareLoaded` already printed `birth preparation: {repr
    reason}` on the same authorized plan channel, so nothing new is disclosed.
- Not touched: `GrainResourceBirthAdmission.Pending.admitBranch` has the same conflation
  (`law.admit = none` → `policyRejected`). It is outside audit (c) and is a follow-up.
- **Owed (pass 16 addendum): the keystone poles at declaration level.** The keystones are
  not done until these exist:
  - satisfiable: a concrete loaded, signed `Pending` with `factoryVerdict = some true` and
    an inhabited `BranchAccepted … .factory`;
  - teeth: a law that evaluates false, giving `some false` and admission
    `.error .policyRejected`.
  They wait for elaboration. Until then the executed witness is
  `scripts/kn2/neutral-birth.lean`.
- **Owed: the Grain `admitBranch` binding gap** (see above).

### Births priced from the cell: design and statement (sent to the auditor, nothing coded)

Main already carries the genesis seed (147d3861 / bc88a5ab: `platformCell` in `baseCells`,
`platform_seeded`).

**The surface is wider than the ordinary birth.** The cell's fields are read today from
`NativeHost.Config` or the profile at these sites:
- `FactoryPins.tariff` (`NativeHostContext.validateChecks`, `tariff := config.tariff`) is
  read by `Checked.feeBound`.
- `profile.template.{ownerBudget, lifetime}` is read by `RootGrantShape`/`checkTemplateAt`
  (RBPC :384, :520, `Pending.templateBound`), by
  `GrainResourceBirthAdmission.preparePending`, `ApplicationGrainBirth` (:90–132),
  `ApplicationShareIssueSource` (:189–194), `ApplicationAgentLifetimeGrantSource`
  (:250–255), `ParticipantFactoryProvisioning`, and `PayEnrolV2Receiver` (:77).
- `config.grainBirthTariffValue` is read by `NativeHostGrainBirth` :48,
  `ApplicationShareIssueGrainAdmission` :99, `ApplicationShareIssueGrainReceiver` :178,
  and `NativeHost` :3214.
- `config.completionCustodianKey` is read by the four `Application*Completion*Admission`
  `keyPinned` fields. These are not births.

**The template cannot be swapped inside the profile.** `Profile.compilerProfile` and so
`Profile.semantics` hash `profile.template` (`CanonicalRuntimeProfileCore` :133). So the
cell's owner budget and lifetime must enter as an explicit template beside the profile:
`templateAt profile.template p := { profile.template with ownerBudget := p.ownerBudget,
lifetime := p.lifetime }`. This changes the type of `Pending.templateBound`, and through it
`AcceptedBirth.indexed` and the TokenCensus row text.

**Design (ordinary birth first, in one commit; the rest follow by family).**
1. New `Kernel/PlatformBirthTerms.lean` (L1c's file):
   - `platformAt deployment durable := (PlatformCellDomain.load deployment
     durable.snapshot).bind (recordOf ·.cell.logical)`;
   - `pinsAt pins p := { pins with tariff := p.creation }`;
   - `templateAt`;
   - `deployedView deployment : PlatformCell.BirthView (Durable × Height)`.
2. `ResourceBirthReceiver.receiveLoaded` loads the platform from the durable image it
   commits against. A missing or undecodable cell refuses with a new `platformUnavailable`.
   It admits with `pinsAt pins p` and `templateAt profile.template p`, and adds
   `Loaded.readGuard` to the commit's read guards.
3. `preparePending` takes the template explicitly (ordinary and reserve), and `Pending`
   records it. The Host plan (`prepareLoaded`, `birthRefusal`) reads the same
   `platformAt` on `opened.durable`.

**Keystone statement (deployed, owed):** `ReceiverReadsCurrent deployment profile pins`.
For every `durable height bytes` with `receiveLoaded … durable height bytes` admitting
`accepted`, there is `p` with
`platformAt deployment durable = some p`,
`accepted.pins.tariff = p.creation`,
`accepted.template = templateAt profile.template p`,
and `(cellIdOf deployment, durable.snapshot.model.roots (cellIdOf deployment))` among the
commit's read guards. And `platformAt deployment durable = none` → refused
`platformUnavailable`. With `deployedView`, this instantiates `PlatformCell.BirthsReadCurrent`
(terms = `termsAt p height`, guards ∋ the cell) and `BirthQuoteCurrent` (fee bound by
`quotedFee p.creation`). Teeth: a reader of `opened.pins` (`config.tariff`) after an install
that changed `creation` fails it (the shape of `genesisReader_stale`).

**Auditor pass 17 (lane/audit-platform): the ordinary birth is accepted as the first
scope, on two conditions.**
1. The claim's label says "ordinary births". The owed families stay listed above with
   file:line.
2. **No silent twin at the re-genesis.** `profile.template` stays in the semantics, so an
   owed site that still reads `profile.template.ownerBudget`/`lifetime` or `config.tariff`
   would serve the genesis value after an install, without any error. Before the one
   digest change ships, every owed site must read the cell, or be shown to read only
   `issuer`/`birthSlack`. A census row gates this: it refuses readers of those fields
   outside the cell path. The census row is part of the ordinary-birth commit.

**Landed (ordinary births, creation tariff; pushed unbuilt):**
- `Kernel/ResourceBirthReceiver.lean`:
  - `pricedAt deployment pins durable` checks that the platform record loads from the
    image the birth commits against and that `pins.tariff = record.creation`. Otherwise it
    refuses with new `Reject.platformUnavailable` or `Reject.platformStale`.
    `receiveLoaded` runs it before admission.
  - `platformGuards` puts the platform cell's root into every ordinary birth's
    `readGuards`. The replay recomputes the same `intent`, so it agrees.
  - Theorems: `pricedAt_ok`, `pricedAt_stale` (teeth), `platformGuards_exact`,
    `readGuards_platform`.
- `scripts/check-platform-field-readers.py` with `scripts/platform-field-readers.json`:
  - It refuses any new reader of `template.ownerBudget`/`lifetime`, `config.tariff`,
    `grainBirthTariffValue` or `config.completionCustodianKey` outside the cell path.
  - `--ship` refuses while any `owed` row remains (73 today). The seed is `genesis` and the
    template encoding is `encoding`.
  - It is wired into `scripts/pipeline/merge-gate-checks.sh`.
- **Liveness until the next step:** `opened.pins` still carries `config.tariff`. That equals
  the genesis record's creation tariff (`NativeHostGenesis.genesisRecord`), so births pass
  until the first install that changes it, then refuse `platformStale`. Loud, never stale.

**Next, in order (the ordinary-birth claim is incomplete until 1–3 land):**
1. `opened.pins.tariff` from the cell: `NativeHostContext.validateChecks` reads the record
   through `PlatformCellDomain.load` on the opened image, in both the full and the served
   shape (`validateCore_map` in NativeHostServed must keep agreeing). Then `pricedAt`
   passes after installs.
2. The template's owner budget and lifetime from the record:
   - `templateAt profile.template record` replaces `profile.template` in
     `checkTemplate`/`preparePending`/`Pending.templateBound` (RBPC :520–533, :1328–1341);
   - the `AcceptedBirth.indexed` text and the TokenCensus row change with it;
   - the Host plan (`prepareLoaded`) and the client quote (`Host/Json.lean`) read the same
     record.
3. The deployed keystone `ReceiverReadsCurrent` for ordinary births, from `pricedAt_ok` and
   `readGuards_platform` plus item 2, instantiating `PlatformCell.BirthsReadCurrent`
   and `BirthQuoteCurrent`.
4. The owed families, one per commit, each deleting its census rows.
5. `Intent.credit` with ops 244–247.
6. (Pass 17 addendum) Make `readGuards_platform` unconditional: discharge its `unwritten`
   premise from `PlatformInstallReceiver.platform_written_only_by_install`. The `.platform`
   kind is kernelOnly to `.platformInstall`, and the ordinary birth family is not that
   family. This needs a bridge from the birth's `prepared.writes` cell ids to the family
   write discipline, and the bridge is not stated yet.
7. Audit (c)'s Lean poles (satisfiable and teeth on a concrete loaded, signed `Pending`).
