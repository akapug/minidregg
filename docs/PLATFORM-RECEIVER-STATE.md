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

## L1e (lane/lean-audit-c, lane/lean-audit-c-m2): state

L1e (successor to L1d) prices every birth family and the completion custodian key from the
platform cell (lane/lean-audit-c), and carries M2, `Intent.credit` and the refill family
(lane/lean-audit-c-m2, worktree /Users/ember/dev/minidregg-lanes/lean-audit-c-m2). Neither is
on main. The integrator (a34bdb948f1cf4796) lands one green sha after the module conversion.
The auditor is af7a93e7b8ba729d4; passes 16–23 are on lane/audit-platform.

### Green: the one landing sha

**lane/lean-audit-c 18ade1e4a** is sent to the integrator for landing. It is the module conversion
(main b26630168) merged with lean-audit-c and M2 (lane/lean-audit-c-m2 31b3db1c8).
- Built cold on hbox (/othersys/lanes/lean-audit-c/src, build-umb.sh, SWARM_MEM_MAX=64G; 40G
  OOMed): `Minidregg Fixtures ObjectiveProofs CensusChecks +Host.Main:leanArts
  +Host.ClientConsentSession:leanArts`.
- Everything elaborates except four reds, none of them this lane's to fix:
  - **the codec shape pins:** the integrator's regen, which is the single epoch move;
  - **NativeAcceptedFixture and NativeDocWriteFixture:** re-record from the candidate at this sha;
  - **Assurance.StoryLaw:486:** a namespace pin, in files this lane does not touch; reported.
- Merge decisions:
  - **Headers:** rebuilt from the lane's plain imports and re-converted by
    lean-modularize.py. Against main, each differs by exactly the lane's import.
  - **SourceAgreementJson:** thin-birth's `BirthEpochs`/`birthAt` combined with `BirthTerms`
    (owner budget, lifetime, fee quote). Thin consent re-authors at the terms the draft carries
    (`BirthCoordinates.ownerBudget/lifetime/fee`). The auditor accepted this, on condition the
    consent display renders the terms: 42fb35d29 `birthJson` "terms", asserted by jpriv2 row 20.
  - **DURABLE.LOG frame byte 4:** A11 had used byte 3 for the subject-only record.
    `v3_record_refused` was added.
  - **NativeThinBirth's pins lemmas** take the platform record.

### Item 7's plan poles (audit pass 24): landed on the branch

- cdda94d42 Fixtures/BirthPlanPoles.lean: `plan_passes_inhabited` (verdict `some true`) and
  `plan_refuses_inhabited` (`some false`), over a source-built genesis opened purely and the real
  `prepareDraft`/`preparePending`.
- Decided by `native_decide`, confessed. The pin names the two auxiliary native axioms. It is in
  `Fixtures`, which the umbrella target list builds. It elaborates in about 6 s.
- Still owed, by the pass-24 ruling: the signed poles over a recorded transcript
  (`CheckedSignature` with Oracle `.recorded`, CredentialSignatureAdmission.lean:287-296).
  - `BranchAccepted … .factory` inhabited, and admission `.error .policyRejected` on the
    refusing law;
  - the `ReceiverReadsCurrent` satisfiable `AcceptedBirth`;
  - the completion `Candidate` passing `platformReadOnly`;
  - the Host-level refill at an exhausted meter.
- Gate cost: kernel cSHAKE runs about 0.13 s per hashed byte. If a kernel version's total passes a
  few minutes, the native module gates merges and the kernel one runs nightly.
- scripts/kn2/neutral-birth.lean is stale. Its genesis Config lacks `payControlCapabilityId`,
  `clockControlCapabilityId` and the four `platform*` fields, so the interim executed witness
  does not elaborate. Fix it alongside the signed poles (Fixtures/BirthPlanPoles.lean has the
  right Config).

### Audit record (lane/audit-platform AUDIT.md)

- Pass 20 accepted the completion custodian key from the platform cell.
- Pass 21 accepted the M2 design; the overflow finding was withdrawn, since the meter is an
  unbounded Nat. Its addendum accepted the deployed K1/K2/K3 and retired the spec twin.
- Pass 23, option A: the World carries credit, with three conditions (the regression pole,
  `step_meter` with the 0→5 pole, the K3 docstring). Addenda accepted the exact text plus the
  tooth `encodeTurn_credit_ne`, the strengthened `SnapRepresents.meter`, and
  `charge_le_allowance` with `+ credit`. `Reserved.uncredited` was accepted in a reply, with no
  section.
- Pass 24: item 7 witnesses. Signed poles go over a recorded transcript; a native_decide
  module is the fallback, thresholded on the module's total gate time.

### Queued after landing

- **Birth-authoring twin, ordered by the coordinator under law 1.** The box authors births with
  Host.Json, and the thin-consent provider re-authors with `Host.SourceAgreementJson.birthAt`.
  They are identical copies (lane/thin-birth 1e0f741d3, docs/THIN-BIRTH-2026-10-28.md); if they
  ever diverge, honest thin births are refused `draftNotAuthored`. Collapse them into one
  function both call, keep the better copy, and prove agreement with rfl or a filtered test. Do
  this after lean-audit-c and thin-birth are both on main.
- thin-birth is on main (eda65ced8); the DurableFastForwardProofs fix is on main (455f59d57, the same
  edit as cdda94d42). Expect overlap with this lane in
  Host/SourceAgreementJson.lean (`birthCurrent`) and Host/HostOperations.lean when merging the
  converted main.

### Box trees

- dregg-ref /build/lanes/lean-audit-c is a worktree of /build/minidregg. `git fetch` fails there
  on the other user's object dirs, so sync it with `git archive HEAD <files> | ssh dregg-ref tar
  -x` and chown the files to lanes. Scripts export
  `PATH=/build/home-lanes/.cargo/bin:/build/home-lanes/.elan/bin:$PATH`. PID file
  /build/lanes/lean-audit-c-build.pid; run as `sudo -u lanes`.
- hbox /othersys/lanes/lean-audit-c/src: git archive plus overlays (82c17c448 + the M2 tip now).
  build.sh / build-m2.sh, build.pid, SWARM_MEM_MAX=40G. Remove /othersys/lanes/lean-audit-c when
  the lane ends.

### M2 as built (pass 21, pass 23 and addenda, all accepted)

- Protocol: `Intent.credit`, install `available - exactCharge + credit`, sameCheck compares
  credit, IntentRecord.credit (v3), `IntentRecord.erase` carries it.
- The World carries credit (pass 23, option A):
  - `World.Turn.credit`, documented as turn data that `admit` does not decide; minting is
    confined only by K3.
  - `meteredLanes`/`meterPatch`; regression poles `meteredLanes_uncredited`,
    `meterPatch_uncredited` and `sysPatch_uncredited`.
  - `sysPost_allowance` and `step_meter` on every lane; `charge_le_allowance` with
    `+ t.credit l`.
  - `turnOf_credit`/`ofIntent_credit`; `SnapRepresents.meter` strengthened to
    `allowanceOf l = some (available l)`, with `meter_eq` keeping the old reading. The four
    HostRefinesWorld statements are unchanged.
  - The tooth `encodeTurn_credit_ne`, and the pole `toy_refill_at_exhausted_meter` (0 → 5).
- K1 `protocol_install_matches`, K2 `AcceptedRefill.sound` (deployed), K3
  `NativeAdmission.credit_confined`: proved per arm. `Reserved.uncredited` was added and
  accepted: the one construction site fills it by rfl. The other per-arm lemmas are
  `AdmittedTurn.finalIntent_credit` and the ClaimV3 `Conditional.intent` unfold.

### Done since L1c (all in 82c17c448)

| sha | what |
|---|---|
| f07166482 | Completion custodian key from the platform cell (pass 20): `Kernel/CompletionCustodianKey.lean`, `PlatformCellDomain.recordOn` the one record reader, the four completion Candidates carry `custodian` and checked `platformReadOnly` |
| b9d5fbd7e | Application grain births read `record.creation`/`record.lifetime`; the loaded author checks `record.grainBirth` |
| aad599082 | Pay quotes, reserve birth authoring, SourceAgreementJson.birthCurrent and `descriptionLoaded` price from the record |
| b7412f32a | Grain births guard the platform cell (`platformGuard`, checked `Pending.platformUnwritten`, `Accepted.platformGuarded`) |
| d95bf65ea, bd199e0e9, 82c17c448 | build reds: enrolObserve call sites, provisioning import, `recordOn_congr`, `select_pinned`, provisioning `recordOf` (Lean 4.30 generalizes a match discriminant inside the returned subtype; a local `go` carries the equation) |

The census (`scripts/check-platform-field-readers.py`) has 0 owed rows, and `--ship` passes.

### Owed

- The theorem form of the two checked refusals, `platformReadOnly` (completions) and
  `platformUnwritten` (grain births). Pass 20 (a) accepted the checked form as fail-safe.
- `GrainResourceBirthAdmission.Pending.admitBranch` still lets `law.admit`'s `none` cover a
  binding failure (pass 16).
- Item 7, the concrete witnesses (none done until it exists):
  - audit (c)'s poles and `ReceiverReadsCurrent`'s satisfiable pole: one concrete loaded,
    signed `AcceptedBirth` or `Pending`, one with a passing verdict and one refused;
  - the completion `Candidate` that passes `platformReadOnly`;
  - the Host-level admitted refill at an exhausted meter (the World half is
    `toy_refill_at_exhausted_meter`).
  - `scripts/kn2/neutral-birth.lean` is the accepted interim executed witness for births only.
