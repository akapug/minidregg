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

## L1c (lane/lean-audit-c): state

L1c owns audit (c), pricing every birth family from the platform cell, then `Intent.credit`
with ops 244–247. lane/lean-audit-c is held off main until a warm dregg-ref build of it is
green. The integrator lands exactly that sha.

### Build status (read this first)

- The warm build has never gone green.
  - The first warm build failed in ResourceBirthReceiver; 23ad62668 fixed it.
  - The second failed in NativeHostReplay; 06eb865a2 fixed it.
- A third build is queued. PID file /build/lanes/lean-audit-c-build.pid (pid 411734), log
  /build/lanes/lean-audit-c-build3.log, script /build/lanes/lean-audit-c-build.sh.
  - It waits on closure-lock behind dregg-ref's nightly, and that wait is expected.
  - It builds Kernel.NativeHost, Kernel.PlatformCell, Kernel.NativeHostServed, Host.Json,
    Host.CurrentResourceBirthAuthoring and TokenCensus.Table.
- The box worktree /build/lanes/lean-audit-c is detached at 138320fbe, with the diff up to
  e2dae30ee applied on top, uncommitted.
  - `git fetch` there fails: some /build/minidregg/.git/objects subdirectories belong to
    another user. Don't chown them; apply diffs instead.
  - If the build passes, its content is e2dae30ee. Send the integrator e2dae30ee (or the tip,
    if only scripts or docs moved after it).
  - Files the targets don't cover need `lake env lean` after the build: Host/*Authoring
    (share issue, lifetime grant, the grain share issue), tests/lean/LifetimeGrantSourceAdversary.lean.
- The most likely reds:
  - the `cases` proof in PayEnrolReceiver.ambientCurrent_iff;
  - the anonymous-constructor orders in GrainResourceBirthAdmission.preparePending, the
    pay Planned structures and ParticipantFactoryProvisioning.prepare;
  - the `let ⟨record, recordExact⟩ ←` destructuring in provisioning;
  - NativeHostReplay's moved `payEnrolAmbient`, defined with `_root_`.

### Audit (c): landed, poles owed

`.policyRejected` now means only that the law refused.
- `Kernel/ResourceBirthPolicyController.lean`:
  - `Pending.judgeBranch` refuses binding (`policyBinding`), then the compiler verdicts
    (`policyUnsupported`, `policyInputRange`, `policyCastAlias`), then `law.admit`
    (`policyRejected`).
  - The keystones are `planRefusalSound`, `planPassNotLawRefused` and
    `lawRefusalDisclosed`.
- `NativeHost.birthRefusal` names draft, preparation and pending failures. It is on main.
- Owed:
  - the Lean poles on one concrete loaded, signed `Pending`/`AcceptedBirth` (item 7);
  - `GrainResourceBirthAdmission.Pending.admitBranch` still treats a binding failure as a
    refusal.

### Births and families priced from the cell

The ordinary birth carries the full keystone `ReceiverReadsCurrent`, accepted in pass 18,
with the unconditional `readGuards_platform`. Each family below reads the record of the
image it commits against. They are coded and unbuilt.

| sha | family | what |
|---|---|---|
| 87bdba019, 3d78d5a5a, a9b916cbf, a281e53b8, e59846239, 54c3f2c16 | ordinary birth | items 1–3 and 6 (see `ReceiverReadsCurrent`) |
| 24a373cf3 | grain birth | `Pending` carries `record`, `recordExact`, `priced` and `grainPriced`; template under the record; `grainTariffOf` and `grainTariffAt`. The Host, NativeHostGrainBirth and the replay read the grain tariff from the record |
| 13139a8f1 | share issue (ordinary and grain) | the source takes the record; `baseTariff` is deleted; `indexed` states the record |
| 7e13d8e28 | agent lifetime grant | the same; the adversary test prices from a record that differs from the genesis template |
| 7f8760bfe | participant provisioning | `Prepared.record` and `Prepared.template`; new `Reject.platformUnavailable` |
| 98af574d8, e2dae30ee | pay enrol v1/v2, claims | `Ambient.template`; `AmbientCurrent` is checked in every plan; `payEnrolAmbient` lives in NativeHostReplay |
| e2dae30ee | fleet turns, realm well, activity/seat ambients | asset, collector and fee read from `opened.pins.tariff`, both on submit and in replay |

Owed for grain births: the platform cell is not yet a read guard on them.

### Census (`scripts/check-platform-field-readers.py`, in merge-gate-checks)

34 rows owed, 0 refusals. Statuses: owed, genesis, encoding, cell, and `other` (the objective
work tariff, `ObjectiveTariff.Tariff`). Comments and `templateAt profile.template` are not
counted. The owed rows, by family:
- Completion custodian key: Kernel/ApplicationLifecycleCompletion{,V2}Admission,
  RetryCompletionV4Admission, FailedStartRecoveryAdmission (`keyPinned`), and their Host
  authoring.
  - Design needed first: these admissions run over a served `Ground`, not a Durable. Reading
    the record needs the platform cell in the basis (`PlatformCellDomain.load` over the
    ground's physical bytes, or a basis key).
  - State it, send it to the auditor, then code it.
- Application grain births: Kernel/ApplicationGrainBirth, ApplicationGrainSessionBirth
  (`NativeHostGenesis.Config`), and Host/ApplicationCurrentBirthAuthoring.
- Host quote and describe surfaces:
  - Host/Main describe (:1033) and SourceAgreementReader;
  - Json pay quote (:4326, :4332) and PayClaims;
  - NativeReserveBirthAuthoring and BirthRuntimeProfile;
  - ClientConsentSettingsScenario, a fixture-like check.
  Each should read `opened.pins.tariff` or `platformRecordAt`, or be classified genesis with a
  reason.
- NativeHost (`profile.template` ×3) and NativeHostContext. The runtimeParameters manifest
  and the pinnedTariff fallback are probably genesis; classify them with a reason.

### Client and lifecycle fixes (lane/prepare-refusal-clients, on main)

These are unbuilt; the next full build of main checks them, and its tests stage has a
named `L1c` set.
- f73893fce: every client path names a prepare refusal and exits 3, with
  pre-submit-refusal.* written on the direct-binary route.
- fced519cb: a grain install whose BEGIN was refused, with nothing appended, can be retried.
- 25cfb86bd: the grain-install red. Since 3ea8f80c8 the claim assemble checked the unit
  against `storeIdentity`, while the BEGIN plan derived it from `expectedSeed`. Every
  lifecycle site now uses `storeIdentity`.
- 7b3564733: `framed_payload` takes the step (61 sites), and the claim steps decode
  refusals.

### Next, in order

1. When build 411734 is green, send the sha to the integrator (a34bdb948f1cf4796). If it is
   red, fix it forward in the box tree with `lake env lean`.
2. The rest of item 4: the census rows above, one family per commit. The completion key
   family goes statement-first to the auditor (af7a93e7b8ba729d4).
3. Item 5: `Intent.credit` with ops 244–247.
4. Item 7: audit (c)'s Lean poles, and `ReceiverReadsCurrent`'s satisfiable witness, on one
   concrete loaded, signed `AcceptedBirth`.
