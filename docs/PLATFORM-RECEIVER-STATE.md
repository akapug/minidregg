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
- Next: merge lane/lean-critical 147d3861 (genesis seed), then births priced from the cell
  (statement first), then `Intent.credit` with ops 244–247.
