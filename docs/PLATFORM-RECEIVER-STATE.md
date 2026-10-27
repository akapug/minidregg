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

L1c owns audit (c), births priced from the platform cell, then `Intent.credit` with ops
244–247. Everything below was pushed before the build rule changed and none of it has been
elaborated: the first warm build on dregg-ref covers all of it.

### Audit (c): landed, poles owed

`.policyRejected` now means the law refused, and nothing else.
- `Kernel/ResourceBirthPolicyController.lean`:
  - `Pending.judgeBranch` refuses, in order: binding (`policyBinding`), the three compiler
    verdicts (`policyUnsupported`, `policyInputRange`, `policyCastAlias`), then `law.admit`
    (`policyRejected`). `admitBranch` calls it.
  - The keystones are `planRefusalSound`, `planPassNotLawRefused` and the converse
    `lawRefusalDisclosed` (`policyRejected` → verdict `some false`). Also `planVerdict`,
    `Pending.factoryRefusal` with `factoryRefusal_eq_none_iff`, and `factoryVerdict_congr`.
- `Kernel/NativeHost.lean` `birthRefusal` names a noncanonical draft, a `prepareDraft` or
  `preparePending` error, and an unresolved law. It judges through `factoryRefusal`.
- Pass 16 accepted the disclosure. The poles stay owed (item 7 below); until then the
  executed witness is `scripts/kn2/neutral-birth.lean`.
- `GrainResourceBirthAdmission.Pending.admitBranch` still conflates binding with refusal
  (`law.admit = none` → `policyRejected`). It is outside audit (c) and owed as a follow-up.

### Births priced from the cell: landed

Pass 17 accepted ordinary births as the first scope, on two conditions: the label says
"ordinary births", and there is no silent twin at the re-genesis.

| sha | what |
|---|---|
| f2010f574 | `ResourceBirthReceiver.pricedAt` (refuses `platformUnavailable` / `platformStale`), `platformGuards` in `readGuards`, `pricedAt_ok`, `pricedAt_stale`, `readGuards_platform` (still carries an `unwritten` premise; item 6). The census `scripts/check-platform-field-readers.py` is wired into merge-gate-checks; `--ship` refuses while any row is `owed` |
| 87bdba019 (item 1) | `NativeHostContext.validateChecks` pins the record's creation tariff (`platformRecordIn`, `pinnedTariff`) in both the full and the served shape; `validateCore_map` takes one shared platform argument; `platformRecordIn_load`. Without a record the config tariff stands in, and `pricedAt` refuses every birth on that image |
| 3d78d5a5a (item 2) | `templateAt`, `platformRecordAt`, `birthTemplate`. `Pending` records `template` with `templateExact`, and `templateBound` checks against it for all three methods. `preparePending` refuses `platformUnavailable` (birth `Reject`). `checkTemplate` is deleted. The `AcceptedBirth.indexed` / `reserve_shape` statements and the TokenCensus row change with it |
| a9b916cbf | `Json.birthCurrent` and `CurrentResourceBirthAuthoring` quote the fee and the root grants' budget and window from the opened image's record. Offline authoring keeps genesis |

The census has 87 rows owed. The owed families are the share issue, the agent lifetime
grant, the grain births, participant provisioning, PayEnrolV2, and the four completion
`keyPinned` fields. The share issue and the lifetime grant still check
`pins.tariff = config.tariff`, so after a tariff-changing install they refuse. They never
stay silently stale.

### Item 3: the deployed keystone (statement for the auditor; nothing coded)

**One change makes the statement unconditional: pricing moves into `Pending`.** Today
`pricedAt` runs in `receiveLoaded` (IO) before admission. A theorem over `AcceptedBirth`
therefore cannot see it, and a keystone over the IO receiver would have to assume it. The
design:
- `Pending` carries `record : PlatformCellLayout.Platform`,
  `recordExact : platformRecordAt deployment durable = some record` and
  `priced : pins.tariff = record.creation`.
- `Pending.template` becomes `templateAt profile.template pending.record` (a def, not a
  field). `templateExact` follows from it.
- `preparePending` refuses a missing record with `platformUnavailable` (as today) and a
  different tariff with a new birth `Reject.platformStale`.
- `ResourceBirthReceiver.pricedAt` and the receiver's `platformUnavailable`/`platformStale`
  constructors are deleted. They are the twin; the birth `Reject` reaches the Host as
  `.admission reason`.

**Keystone (`Kernel/ResourceBirthReceiver.lean`).**

```lean
/-- Births admitted by the resource-birth receiver (ordinary, reserve and lifetime-grant
methods) read the platform record of the image they commit against. -/
def ReceiverReadsCurrent (profile) (deployment) : Prop :=
  ∀ pins durable height (accepted : AcceptedBirth profile deployment pins durable height),
    ∃ record, platformRecordAt deployment durable = some record ∧
      pins.tariff = record.creation ∧
      accepted.descriptor.FeeBound record.creation ∧
      accepted.pending.template = templateAt profile.template record ∧
      (⟨⟨PlatformCellDomain.cellIdOf deployment⟩,
        durable.snapshot.model.roots ⟨PlatformCellDomain.cellIdOf deployment⟩⟩ : ReadGuard)
        ∈ (intent accepted).readGuards

theorem receiverReadsCurrent : ReceiverReadsCurrent profile deployment
theorem unpriced_empty (missing : platformRecordAt deployment durable = none) :
    IsEmpty (AcceptedBirth profile deployment pins durable height)
```

- The guard conjunct is unconditional. Its proof is item 6.
- `receiveLoaded` commits exactly `intent accepted` for the `accepted` that
  `admitDecodedNative` returns. That is code structure in IO; the theorem covers every value
  the receiver can commit.

**Relation to `PlatformCell.BirthsReadCurrent` / `BirthQuoteCurrent`.** A literal
instantiation over `Store := Durable × Height` would be vacuous: the only `terms` function
of the store alone is `currentReader`, which is proved by `rfl`. The deployed content is
per admitted birth instead:
- `some p` branch: `p.creation` through `priced` and `FeeBound`. `p.ownerBudget` and the
  window `[height, height + p.lifetime]` come through `template` and `RootGrantShape`
  (`maxCost = ownerBudget`, `notAfter = notBefore + lifetime`, `BirthWindow`). The guard
  is the platform cell.
- `none` branch: `unpriced_empty`.
- `grainBirth` and `completionCustodianKey` are not read by this family. They belong to the
  owed census rows and are not claimed here.

**Satisfiable.** It needs a concrete loaded, signed `AcceptedBirth`, which is the same
missing object as item 7. The interim executed witness is `scripts/kn2/neutral-birth.lean`,
whose control birth commits at the record's tariff. The premise `platformRecordAt = some`
is inhabited on the deployed genesis by `platform_seeded`.

**Teeth.**
- `preparePending_stale`: a record with `pins.tariff ≠ record.creation` gives
  `.error .platformStale`. Hence `IsEmpty (AcceptedBirth …)` for pins built from
  `config.tariff` after an install that changed `creation`; that is the deployed
  `genesisReader_stale`.
- A guard list without the platform cell (the pre-f2010f574 `readGuards`) fails the last
  conjunct on any image whose record loads.

**Label.** "Births through the resource-birth receiver read the current platform record:
creation tariff, owner budget, lifetime, and the cell's read guard. Owed: share issue,
lifetime-grant source, grain births, provisioning, PayEnrolV2, completion keys (87 census
rows)."

### Item 6: `readGuards_platform` unconditional (in progress)

`readGuards_platform`'s `unwritten` premise is discharged from the birth's own write list
rather than from `platform_written_only_by_install`. The birth receiver never forms
`ReceivingLaw.LawfulBy`, so a bridge to the family discipline would first have to make the
receiver judge its writes that way. `prepared.writes = planWrites …` consists of:
- `allocationWrites`: fresh, `expectedPre = freshRoot`, at ids that `ResourceBirth.allocate`
  requires absent;
- the factory cell (`.declaredObject`);
- the resource book (`.resourceBook`);
- the authority writes (the credential-authority cell).

The platform cell is present (`load = some`) and of kind `.platform`. So each write differs
from it, either by absence in the loaded directory or by its observed kind. The lemma is
`platform_unwritten (prepared) (found : PlatformCellDomain.load … = some loaded) :
cellIdOf deployment ∉ prepared.writes.map DataWrite.cellId`.

### Next, in order

3. Pricing into `Pending`, then `receiverReadsCurrent`, `unpriced_empty` and
   `preparePending_stale`, once the auditor answers the statement above.
4. The owed families, one per commit, each deleting its census rows.
5. `Intent.credit` with ops 244–247.
6. `platform_unwritten` (above), then `readGuards_platform` without its premise.
7. Audit (c)'s Lean poles and item 3's satisfiable pole: one concrete loaded, signed
   `Pending`/`AcceptedBirth`.
