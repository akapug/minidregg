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

## Open

- The auditor (af7a93e7b8ba729d4) reads the O61 clock-law statements (ClockLaw.lean :101–:333,
  NativeHostGenesis.lean :1057, :1241). Open question put to it: should `controlClause` also
  require the clock unchanged?
- Integrator: codec-shapes regen (the `GENESIS-SOURCE/v8` pin carries the v7 fingerprint;
  `DREGG/PLATFORM/PLAN/v1` may want a pin). Genesis writers that lacked `payControlCapability`
  since v7 also lack the v8 fields (acceptance.sh, application-, authority-, selected-release-
  acceptance.sh, grain-runtime/acceptance.sh, jpay2.sh, jpay6.sh, scripts/fn-e1e2/setup-mini.sh).
  dregg-infra's demo genesis-params needs `clockControlCapability`.
- Nothing of 7e39fe90..bc88a5ab was built by this lane; expect reds from the cut and fix them
  forward. Likely spots: `Moment.frame_effectsDigest` (`simpa [planOf]`),
  `signed_command_admitted`, `Config.ofWire_toWire` (22 fields, grain case split),
  `ClockLaw.clockPredicate_eval` (the simp shape of the new disjunct), `clock_ticks_only`.
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
