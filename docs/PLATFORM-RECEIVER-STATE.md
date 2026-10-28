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

L1e (successor to L1d) holds the lane. **82c17c448 is green** in a warm tree on dregg-ref
(build 6, closure-lock, peak 23.7 GB) and cold on hbox (build 3). Both box trees match the
lane's HEAD byte for byte. The targets were the twenty modules in
/build/lanes/lean-audit-c-build.sh, plus Host.ApplicationAgentLifetimeGrantAuthoring,
-Inspection, Host.ApplicationShareIssueGrainInspection and
tests/lean/LifetimeGrantSourceAdversary.lean (lane-check).
- Reds fixed on the way (statements unchanged):
  - bd199e0e9 `recordOn_congr`;
  - 82c17c448 `select_pinned`'s split chain, and provisioning `recordOf`. Lean 4.30
    generalizes a match discriminant inside the subtype it returns, so the equation is
    carried by a local `go` instead.
- dregg-ref box tree /build/lanes/lean-audit-c (a worktree of /build/minidregg; `git fetch`
  there fails on the other user's object dirs). Sync it with `git archive HEAD <files> | ssh
  dregg-ref tar -x` and chown the files to lanes. Build scripts must export
  `PATH=/build/home-lanes/.cargo/bin:/build/home-lanes/.elan/bin:$PATH`; build 4 died with
  `lake` not found. PID file /build/lanes/lean-audit-c-build.pid.
- hbox tree /othersys/lanes/lean-audit-c/src (git archive, build.sh, build.pid, SWARM_MEM_MAX=40G).
  Remove /othersys/lanes/lean-audit-c when the lane ends.

### Item 5 ruling

The coordinator ruled: `Intent.credit` persists in `IntentRecord` (durable log frame v3,
`DREGG.DURABLE.IMAGE` v3). It ships with the module conversion's re-genesis, so the
StoreEpoch moves once, and the codec-shape pins move only through the integrator's regen.
The auditor accepted the design (pass 21) and the deployed keystones (pass 21 addendum).
M2 is on lane/lean-audit-c-m2, unbuilt.

### Order with the module conversion (agreed with iter-speed, a0fd127abfb9aac75)

1. The module conversion lands on main first.
2. L1d merges iter-speed's landing sha into lane/lean-audit-c.
   - Header conflicts are expected in the 7 files whose imports L1d changed: the four
     completion admissions, ParticipantFactoryProvisioning, NativeHostContext and
     ResourceBirthPolicyController.
   - Take L1d's side of the HEADER hunks only and merge body hunks normally.
   - Then run `python3 scripts/lean-modularize.py <those files> Kernel/CompletionCustodianKey.lean`.
     Never hand-edit a converted header.
3. Check each changed file and its direct importers with `scripts/pipeline/lane-check FILE`
   on a box tree, never with `lake env lean`.
   - A hidden-body failure: run `scripts/module-hidden-bodies.sh FILE` and add its lines to
     PER_FILE in lean-modularize.py, then re-convert.
4. Re-prove green on the merged tree and send that sha to the integrator.
5. Then put the M2 commits on top and run the same modularize step for
   Kernel/MeterRefillReceiver.lean and NativeHostReplay.
   - In the converted NativeHostReplay every `Derived` literal names each defaulted field
     (`… := none`). That works around Lean 4.30's private-ctor-plus-defaults bug. Rewrite
     M2's `meterRefill` Derived literal the same way.
6. M2 lands in one integration build with the integrator's codec-shapes regen, so the
   StoreEpoch moves once.

The M2 commits, on lane/lean-audit-c-m2 (pushed, unbuilt):
- f21407b2e: the protocol.
- a7f17b12d and ab030d544: the refill family, the registry and K3.
- e870fd03e: the spec twin retired and the deployed teeth.

The auditor accepted the deployed K1/K2/K3 (pass 21 and its addendum). K3's proof needs
per-arm work on a box: about 25 arms carry the intent as a structure field with an
`intentExact`.

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
