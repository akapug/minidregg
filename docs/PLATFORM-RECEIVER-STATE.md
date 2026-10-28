# Platform cell: state (2026-10-27, third handoff)

`lane/lean-critical` = the commit adding this file (worktree
`/Users/ember/dev/minidregg-lanes/lean-critical`). Lanes build and elaborate in a warm,
incremental tree on a box (baef327e4): dregg-ref, never the Mac, never a cold build. Fix
forward the reds the integrator sends with file:line. Merge origin/main before each push.

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

## L1d (lane/lean-audit-c): state

L1d (successor to L1c) prices every birth family and the completion custodian key from the
platform cell. Next it does `Intent.credit` with ops 244–247, then audit (c)'s Lean witnesses.
lane/lean-audit-c is held off main until one of its shas is green in a warm tree. The
integrator (a34bdb948f1cf4796) lands exactly that sha. The auditor is af7a93e7b8ba729d4, with
passes 16–21 on lane/audit-platform.

### Build status (read this first)

Nothing on this lane has gone green yet.
- dregg-ref: build 3 of e2dae30ee is queued on closure-lock behind the nightly's m7_reference.
  - PID file /build/lanes/lean-audit-c-build.pid, log /build/lanes/lean-audit-c-build3.log.
  - The box tree is 138320fbe with the diff to e2dae30ee applied uncommitted. `git fetch` fails
    there because of object dirs owned by another user; don't chown them.
- hbox: a build of b7412f32a, the tip, is running. On the coordinator's instruction it was
  seeded with the warm base's `.lake/packages` only, so our modules build cold.
  - Tree: /othersys/lanes/lean-audit-c/src (`git archive`, `LANE_SHA`).
  - Script build.sh, PID file build.pid, log build.log, `SWARM_MEM_MAX=40G`.
  - Targets: build 3's list plus every module L1d touched.
  - Fix reds forward there with `lake env lean FILE`, then send the integrator the green sha.
  - Remove /othersys/lanes/lean-audit-c when the lane ends (the README there says so).
- Not covered by the targets, so `lake env lean` them after a green:
  - tests/lean/LifetimeGrantSourceAdversary.lean;
  - the share-issue and lifetime-grant Host/*Authoring files.
- Likely reds:
  - L1c's list: PayEnrolReceiver.ambientCurrent_iff's `cases`; the anonymous constructors of the
    grain Pending, the pay Planned structures and provisioning; the provisioning
    `let ⟨record, recordExact⟩ ←`; `_root_` payEnrolAmbient.
  - L1d's: `CompletionCustodianKey.select_pinned`'s split chain; the four Cores' `rcases … split at`;
    `Read.current`'s split.

### Done since L1c (all unbuilt)

| sha | what |
|---|---|
| f07166482 | Completion custodian key from the platform cell, accepted in pass 20. `Kernel/CompletionCustodianKey.lean` (`Read`, `select`, `Read.current`, `Read.stale`, `select_unavailable`, `select_pinned`, `recordOn_light_keys`). `PlatformCellDomain.recordOn` is the one record reader (`platformRecordAt` = `recordOn … durable.snapshot`). Each of the four completion Candidates carries `custodian` and the checked `platformReadOnly`. Each Core guards the platform root and proves `keyCurrent`. Host pre-checks read the record. `provisionPlanLoaded` signs over `prepared.template` |
| b9d5fbd7e | Application grain births: builders take the record (`record.creation`, `record.lifetime`). The loaded author reads `recordOn` and checks `record.grainBirth`. The pure Json author passes `genesisRecord` |
| aad599082 | Pay quotes price from the receiver's ambient. Reserve birth authoring prices from the record. SourceAgreementJson.birthCurrent takes the record (port of a9b916cbf). `descriptionLoaded` offers grain-birth per the record. BirthRuntimeProfile.select no longer compares the grain tariff |
| b7412f32a | Grain births guard the platform cell: `platformGuard` in `Accepted.readGuards`, checked `Pending.platformUnwritten` (`.platformWritten`), `Accepted.platformGuarded` |

Census (`scripts/check-platform-field-readers.py`): 0 owed rows, 0 refusals, and `--ship` passes.
`config.grainBirthTariff` is now a counted pattern. Every non-owed row carries a `reason`
(`--write` keeps it). `templateAt config.profile.template` counts as the cell path.

### Owed

- The theorem form of the two checked refusals, `platformReadOnly` (completions) and
  `platformUnwritten` (grain births): that no DRC or grain write lands at the platform id. Pass
  20 (a) accepted the checked form as fail-safe.
- `GrainResourceBirthAdmission.Pending.admitBranch` still lets `law.admit`'s `none` cover a
  binding failure (pass 16).
- Item 5, `Intent.credit` and refill ops 244–247. The design is accepted in pass 21 with one
  finding: the overflow fit belongs in the protocol's preflight (`creditOverflow` at commit),
  not at plan time.
  - Take the controller from the platform cell's `controllerOf`.
  - Guard the authority cell.
  - State the replay link: a record whose credit differs from its arm's re-admitted intent is
    refused (the sameCheck credit clause).
  - The coordinator's ruling: credit persists in `IntentRecord`, with durable log v3 and image
    v3. It ships with the module conversion's re-genesis so the StoreEpoch moves once. Order
    it with the integrator and the iter-speed successor (a0fd127abfb9aac75).
  - Keystones: K1 `protocol_install_matches`, K2 `refill_lawful` (deployed), K3
    `credit_confined` over the `NativeAdmission` arms.
- Item 7: the concrete witnesses. Each is not done until it exists.
  - Audit (c)'s poles and `ReceiverReadsCurrent`'s satisfiable pole: one concrete loaded,
    signed `AcceptedBirth` or `Pending`, one with a passing verdict and one refused.
  - The completion `Candidate` that passes `platformReadOnly`.
  - The admitted refill at an exhausted meter.
  - `scripts/kn2/neutral-birth.lean` is the accepted interim executed witness for births only.
