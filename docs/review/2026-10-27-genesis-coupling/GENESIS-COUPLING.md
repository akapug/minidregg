# Genesis coupling: what is pinned, what it costs, how to unpin it

Review, 2026-10-27, against `origin/main` 551adf92 (plus `origin/lane/app-market` c8c059ce..06239e29 and
`origin/integration/2026-10-26` for the integration reports; `~/dev/dregg-infra` for the box scripts).
Every claim cites `path:line`; what I could not verify is marked **unverified**. No code was changed.

The question asked: three separate needs in one day each forced a re-genesis of the demo world. Does the
tree make them necessary, or is it the shell that pins them? Short answer: of the three, **one is a
shell gap** (the pay observer; Lean already proves it replaceable), **one is a digest decision** (the grain
platform block is hashed into the runtime semantics, so a running world cannot acquire it), and **one is
a mixed case** (`issuanceCap` is a Book floor whose amendment receiver was never written; capability
`lifetime` is a template field inside the same digest). Separately, the standing rows do not pay for
genesis itself (3 s) but for standing up member sets and grain worlds per row with nothing reused.

## A. What is pinned at genesis, and why

Two things are "genesis": the Lean `NativeHostGenesis.Config` that becomes the Store's seed
(`Kernel/NativeHostGenesis.lean:88-115`, wire `DREGG/NATIVE-HOST/GENESIS-SOURCE/v6` :250) and the operator
config `operator.json` → `pinned-config.json` the Host reads at open (`Host/Main.lean:579-640` `Settings`;
`Kernel/NativeHostContext.lean:50-85` `NativeHost.Config`). They are bound together by the **semantics
digest**: `Config.Valid` requires `config.expectedSemantics = profile.semantics` (`NativeHostGenesis.lean:323`),
and `profile.semantics = receiverSemantics template runtimeParameters disabledEvaluators`
(`Compiler/CanonicalRuntimeProfile.lean:273-281`). Anything in those three inputs is frozen for the life of the
world, because every signed request pins `expectedSemantics` (`Host/Json.lean:2322-2323` refuses a mismatch)
and birth authoring checks the supplied genesis against the pinned seed (`Host/Json.lean:2355-2359`).

The inputs to the digest (`Kernel/NativeHostContext.lean:97-127`): deployment ids (domain, factoryId,
resourceBookId, authorityCellId), federation, genesisHeight, the six `CreationTariff` fields,
**grainBirthTariff** (:105-110), **completionCustodianKey** (:111-114), jointControl, activityControl,
jointConsensus; plus the whole `FactoryTemplate` {issuer, ownerBudget, **lifetime**, birthSlack} via
`encode template` (`CanonicalRuntimeProfile.lean:255-256`, `encode_injective` :259); plus
`disabledEvaluators` (`NativeHostContext.lean:70-72`, K-EVAL, by ruling). Explicitly *not* in the digest:
`nockFSync` (:64-69), `activityTickLimit` (:78-79), `checkpointEvery`, storage paths, `lifecycleManagement`
(a `Settings` field at `Host/Main.lean:623` with no counterpart in `NativeHost.Config`; consumed by
`native/spk-host/src/lifecycle_selector.rs:102` and the lifecycle authoring ops, `Host/Main.lean:382-389`).

| parameter | where pinned | why it is fixed today | class |
|---|---|---|---|
| domain, factoryId, resourceBookId, authorityCellId, federation | genesis Config :89-90; digest :100-104 | physical cell ids derive from the domain (`PayCell.physicalId config.deployment.domain` :623-624, `clockTarget` :555); the identity of the world | NECESSARY |
| expectedSemantics, expectedSeed, genesisHeight, issuerEpoch | :92-94; `Config.Valid` :323 | the digest itself; the seed identity; epoch 0 of the authority (`initialAuthorityRevision` :318) | NECESSARY |
| sponsor enrollment + factoryController | :95-97; `Valid` :325, :338 | someone must hold the first `installPolicy` on the factory (`controlCapability` :590-593) | NECESSARY (one enrollment; the rest enrol at runtime, `Kernel/ParticipantKeyEnrollmentReceiver.lean`) |
| factoryPredicate | :94; wrapped by `factoryLaw` :541-542 | already replaceable: the controller holds `installPolicy` on the factory (:590-593). Hazard: the genesis wrapper (ticker + observer confinement, `genesis_confines_observer` :1241-1247) is a genesis theorem; I found no theorem that a runtime `policyInstall` on the factory keeps it (`Kernel/PolicyInstallReceiver.lean`: no mention) | CONVENIENT, done; confinement-on-reinstall **unverified** |
| payObserver (Option) | :100-104; `payPolicy` only when present :677-681 | when present, **proven replaceable at runtime**: `observer_replaceable` :1095-1120 (controller holds revoke/delegate/installPolicy on the pay cell, `payControlCapability` :654-662) and J-PAY-E2 Part B exercises it (`native/resource-client/journey.d/jpay-e2.sh:19-25`). When absent: no pay law, no controller capability on the pay cell, no path to add one. `deploy/candidate/run.sh init` never sets `GENESIS_PAY_OBSERVER` (zero mentions in `run.sh`; only `newparticipant-acceptance.sh:84-132` and `scripts/workroom/provision.sh:162-166` do), so the shipped demo genesis could not carry an observer; dregg-infra recorded the consequence (`edge/mini/deploy-3.md:211` "so a further re-genesis"). Mainnet itself is runtime: mint/tokenProgram live in the versioned tariff (`deploy/pay/README.md:107-118`; `Kernel/PayBookReceiver.lean:173` `tariff_version_monotone`), RPC endpoints in `rpc.env` (:125-129) | ACCIDENTAL (shell) + CONVENIENT (law and control cap should be unconditional) |
| clockTickers | :103-104; baked into `clockPredicate` (`Kernel/ClockLaw.lean:80-94`) | the clock cell is law-bearing (`Compiler/CanonicalCellRegistry.lean:221`) so its law is installable, but genesis grants nobody `installPolicy` on it (`tickCapability` :671-675 carries `tickClock` only) | CONVENIENT |
| clockGenesisNow, clockMaxStepSeconds | :110-111; `ClockCell` "immutable maxStepSeconds" (`Kernel/ClockCell.lean:28`, `.ram` :73); bound enforced `Kernel/ClockTickReceiver.lean:79-82` | `now` only matters until the first tick (monotone :135-153). The step bound has no amendment receiver | genesisNow NECESSARY (initial value); maxStep CONVENIENT |
| tailBound `L` | :109; system cell `kernelOnly [.certify]` (`CanonicalCellRegistry.lean:228`); `certified_monotone` keeps `post.tailBound = pre.tailBound` (`Kernel/TailBound.lean:158-162`) | the operator's tariff line; `tail_bounded` (:125-128) holds for whatever `L` is current, so fixing it is not needed by the theorem | CONVENIENT |
| issuanceCap | :112-115; the issuer well's floor in the genesis Book (`unfundedBook` :407-409); `initialBook_withinFloors` :476-477 | floors are amendable in general (`Kernel/RealmWellReceiver.lean:21-24`, `pole_raise_cap_then_mint` :342) but the deployment's credit asset is refused by name: `creditWell` (:111-112, :392 "never a realm well") | CONVENIENT (receiver never written) |
| meterAllowance | :98; the seed's meter (:879) | a **lifetime meter, never replenished** (`Kernel/NativeHost.lean:712-715`): a busy world exhausts it and must re-genesis | CONVENIENT (refill receiver missing) |
| CreationTariff (6 fields) | digest :100-104; fee quoted at authoring `Host/Json.lean:2341` | in the digest by construction; PAY's tariff shows the alternative (a versioned record the controller installs) | CONVENIENT |
| template {issuer, ownerBudget, lifetime} | digest via `encode template`; every root grant's window is `genesisHeight + lifetime` (:575-576) and a birth's `height + lifetime` (`Host/Json.lean:2070-2074`) | two nodes deriving a grant from the same request must agree on its window, hence in the digest. The lifetime belongs in the request, not the deployment | ACCIDENTAL (design), M to move |
| grainBirthTariff, completionCustodianKey | operator config; digest :105-114 | in the digest, so a world born without them cannot acquire them: this is the re-genesis the composed gate hit (`composed-inputs.sh:19-24` refuses `operatorPolicyRequired`) | CONVENIENT at the digest level; the custodian key must be *some* pinned key, but not a genesis one |
| lifecycleManagement | `Host/Main.lean:623` only; `genesis.sh` forces it to the sponsor (`managementNotSponsor`, app-market `native/resource-client/genesis.sh` check block) | not in `NativeHost.Config`, not in the digest; pinned only because `genesis.sh` writes it into `operator.json`. INSTALL.md §0 calls it "pinned at genesis"; the tree does not | ACCIDENTAL |
| disabledEvaluators | digest :70-72 | ruled (K-EVAL) | NECESSARY by ruling |
| consent mode, roster | `/etc/mini/session-consent` thin/full (dregg-infra `edge/mini/shell/mini-shell-ssh:33-37`); friends dir | box files, not chain | not genesis at all |

## B. The coupling's cost, measured from the tree

**Genesis is cheap.** On dregg-build (candidate 45f45d15, `INTEGRATION-2.md` table): `perf/perf-genesis`
bring-up p50 **3,260 ms**; `journey/J0` (three keygens, `genesis.sh`, `mini bootstrap`, `mini serve`, the
newcomer fixture: `newparticipant-acceptance.sh:50-144`) **2.9 s**; `perf-setup` 11.3 s; `perf-reopen` 1.6 s;
`perf-checkpoint` 0.8 s. One hosted enrolment with the consent provider through all 31 welcome steps
(`welcomecontinuity`) **22 s**.

**The rows are not cheap, and none reuses a world.** `journey-runner` gives every row "a fresh SHORT scratch
directory that is deleted after it (worlds, Stores, sockets, test keys)" (`scripts/pipeline/journey-runner:72-73`,
`:138`). 28 rows (`scripts/pipeline/journey-rows:15`), 148 lines, wall **6,482 s at 4 jobs** on dregg-build;
5,019 s on hbox at load 88–118 where the same steps inflate (K12T 1,127 s, KC 651 s; JPAY2 225 s → 385 s:
`INTEGRATION-1.md:112,246`). The long rows are driver work on their own Stores: JPAY2 225 s, hermes 212 s,
fleetsign 180 s, JRLANE 158 s, JROT 79 s, m4 (shell J0–J8 over ssh) 73 s.

**Where the minutes go** is not Store creation or genesis admission: it is (1) member sets, each enrolment a
sponsor `enroll plan/seal/submit` plus `workspace --action provision` plus a hosted `init`, each verb a forced-ssh
session (dregg-infra `edge/mini/mini-reenroll:60-94`, `journey/jworld-scratch.sh:119-135`); (2) grain worlds:
ROOT SETUP through the sudo installer, a broker unit, then `store`, `services`, `workroom`, `profile` phases
(`scripts/spk-platform/two-world-journey.sh:131-150`, app-market `world-up.sh:48-72`), twice for the two-world
row; (3) the clock: a fixture that needs "a week later" must tick ≤ `maxStepSeconds` per record
(`ClockTickReceiver.lean:79-82`), so at the deployed 300 s that is 2,016 records. **Unverified:** I found no
measured wall time for a `jworld-scratch` or `two-world` standup in either repo (m6grain was UNCONFIGURED on
dregg-build: `sudo -n true`; the composed run at `/build/c46` logged no wall).

**World shapes the rows need** (eight, by constructor): (1) one sponsor + clock + pay observer
(`newparticipant-acceptance.sh`; J*, jpay, demo, rooms, bounty, call, send, domain, upgrade, objectrecord,
chargedfailure, m3, m4, hermes, jserve); (2) a fresh `L=8` Store (KT); (3) the fleet's own Store (m8,
fleetsign); (4) a fresh native Store whose genesis is the thing measured (perf, births); (5) a workroom grain
world with `WORKROOM_OPERATOR_POLICY` (`scripts/workroom/provision.sh:31-38,126-127`; two-world, world-up,
m6grain); (6) a candidate world via `run.sh init` with N forced-ssh members (jworld-scratch; the composed gate);
(7) two Stores with distinct domains (exchange, `NEWPARTICIPANT_DOMAIN`); (8) two scratch worlds (objective).
The composed gate needs (6) ∪ (5), a jworld-scratch carrying the grain platform, which no script produced
before c8c059ce and which `composed-inputs.sh` refuses by name without it.

## C. The decoupling, ranked by Lean effort

Each item: the admitted transition, the receiver and theorem (statement first, both poles), the registry op,
the client verb, size. "Demo" = needed before the 2026-10-29 opening; otherwise Phase 3.

**S1. Pay law and pay control unconditional at genesis; the observer optional.** Change `policies`/`entries`
(`NativeHostGenesis.lean:677-730`) so `payPolicy` and `payControlCapability` are installed whether or not an
observer is named; `payPredicate` with no observer admits only the controller's management clause (:622-632
minus the first two disjuncts). Theorem `pay_control_present : capabilityEntry (payControlCapability …) ∈ entries`
with no `present` hypothesis; satisfiable pole: the existing `observer_replaceable` sequence installs a first
observer on a world born without one (J-PAY-E2 Part B is the probe); teeth: `controller_cannot_report`
(:1121) unchanged, and a report with no observer named is refused (`pole_observe_without_observer_refused`,
`ClockLaw.lean:273`). Registry: none new (`payObservation`, `policyInstall`, `capabilityDelegation` exist,
`CanonicalCellRegistry.lean:143-156`). Client: none new (`mini delegate`, policy-install intent). Shell: `run.sh
init` gains `--pay-observer FILE` → `GENESIS_PAY_OBSERVER`. **Size S. Demo:** rehearsal #3 is a re-genesis
anyway and will carry the observer; S1 is what prevents the fourth. Do it now.

**S2. Clock control for the controller.** Mirror `payControlCapability` on the clock cell (installPolicy,
revoke, delegate; never `tickClock`). Theorem `clock_control_cannot_tick` from
`clock_refuses_nonticker_tick` (`ClockLaw.lean:156`); satisfiable: an installed law naming a new ticker admits
its tick (`pole_tick_admitted` :253 shape); teeth: the controller's own tick refused. Registry/client: none new.
**S. Phase 3** (a chain-time observer joining later).

**S3. Unpin `lifecycleManagement` from genesis.** It is a Host setting; drop `managementNotSponsor` and the
"pinned at genesis" sentence (`deploy/market/INSTALL.md` §0), let a `run.sh platform` verb rewrite
`pinned-config.json` and restart. No Lean, no theorem. Per-app laws already bind `request/subject ==
managementSubject` at birth (`Host/Main.lean:382-389`), so old apps keep their manager. **S. Phase 3**, but it
removes one false reason for re-genesis from the docs.

**M1. `tailBoundAmend` and `clockBoundAmend`.** `L` as a field of the certify record: relax
`certified_monotone` (`TailBound.lean:158-162`) to "tailBound changes only by a certify naming it"; teeth:
`certified_written_only_by_checkpoint` (:142) still refuses every other writer. `maxStepSeconds` moves from
`.ram` to a guarded write under the clock law by the S2 holder; teeth: a tick above the *current* bound refused
(`tick_step_exceeded_refused` :84). Registry: `certify` extended; `clockTick` sibling `clockBound`. Client:
`mini checkpoint --tail-bound N`, `mini clock --action bound`. **M. Phase 3.**

**M2. Issuance-cap and meter amendments.** A `wellFloorAmend` on the credit asset's issuer well by the factory
controller: today `decideWell` refuses `creditWell` (`RealmWellReceiver.lean:111`). Statement: a raise keeps
`Book.withinFloors` (the floor only loosens); a lowering is admitted only to a value the well's current
negation still satisfies, else refused — the teeth pole. A `meterRefill` posting against the seed meter with the
same shape (`NativeHost.lean:712-715`). Registry: `realmWell` extended or `purseRefill` sibling. Client: `mini
well --op floor` on asset 0. **M. Phase 3**, unless the demo's mainnet sales approach 10^15 atomic units or the
meter (10^7 proofWork, `genesis-params.example.json`) — **unverified** whether the demo's meter survives three
weeks of residents.

**L1. A platform cell instead of digest parameters.** Move `grainBirthTariff`, `completionCustodianKey`, the
`CreationTariff` and the template's `{ownerBudget, lifetime}` out of `Config.runtimeParameters`
(`NativeHostContext.lean:97-127`) and `encode template` into one law-bearing `platform` cell written by a
`platformPolicyInstall` the factory controller signs, versioned like `payBook` (`tariff_version_monotone`,
`PayBookReceiver.lean:173`; `genesis_change_accepted` :244 is the satisfiable pole, `same_version_refused` :250
the teeth). Births read the current platform record at their height; grants carry an explicit window.
Statement: two nodes admitting the same log reach the same platform state (it is a cell, so this is the
existing durable-replay theorem, not a new one); teeth: a non-controller install refused, a stale version
refused. Registry: `platformInstall` family, `platform` kind `.lawBearing`. Client: `mini platform install`.
Changes the digest once: the last re-genesis of this class. **L. Phase 3.** It is the only item that ends
"a world without X must be reborn" as a category.

**Stays NECESSARY**, with the theorem: deployment ids and federation (`physicalId` derivations, :555,
:623-624), `expectedSemantics` (`Config.Valid` :323), `expectedSeed` (`openExisting` validates it,
`Kernel/NativeHost.lean:40-43`), `genesisHeight`/`issuerEpoch` (`initialAuthorityRevision` :318, every root
grant's `issuerEpoch` :577), the sponsor+controller enrollment (`Valid` :325,:338), `disabledEvaluators`
(by ruling), `clockGenesisNow` (only the first value).

## D. Fluid testing without touching genesis

What the Store and Host already allow:

- **Checkpoints at every height are kept.** `durable_checkpoint(height, bytes)` upserts by height with no
  delete (`native/hyperdocument-link-sqlite-store/src/lib.rs:1277-1292`), and `durable_checkpoint_at(h)` reads the
  newest at or below `h` (:1305-1316). `docs/DURABLE-STORE.md:15` says "the latest two are kept"; I found no
  rotation in the helper — **unverified** which sentence is current.
- **Open is checkpoint + suffix**, verified against the MAC'd tags (`Compiler/DurableReceiverCore.lean:1207-1293`);
  `Loaded.prefixAt` cuts a loaded image at any past height from the chain prefixes with nothing re-hashed
  (:1585-1593), and `prefixOwn` folds from genesis for a client that trusts no operator checkpoint (:1870-1885).
  The Session's `start` is `openExisting` + the light opening (`Kernel/NativeHostSession.lean:154-161`).
- **Restore is file copy.** A Store is `forward-link.sqlite3` + `checkpoint.key` + `pinned-config.json` and the
  sibling anchor (`DURABLE-STORE.md:11-15,174`); the helper has "row truncation above a checkpoint" tests
  (:186). Reopen measured 1.6 s, checkpoint seal 0.8 s.
- **A stopped or stepped clock.** `clockTickers := []` freezes the clock at genesis for the life of the world
  (`NativeHostGenesis.lean:103-104`); a fixture that sets `MAX_STEP_SECONDS` to 10^9 (`params.sh:35`) jumps a week
  in one tick (`decideTick`, `ClockTickReceiver.lean:79-82`). Both are genesis-time choices a *template* can make
  once.
- **Enrolment without the consent replay.** The consent provider independently admits the prefix before every
  signature (`docs/CLIENT-SIGNING-CONSENT.md:12-16`); a fixture avoids it entirely by enrolling its members **at
  genesis**: `EXTRA_GENESIS_ENROLLMENTS` takes up to 8 (`genesis.sh:28-31`), as the workroom provisioner does for
  subjects 8/9 (`scripts/workroom/provision.sh:139`; `apps-e2e.sh` opens workspaces over `tool.key`/`member.key`
  with no enrolment verb at all).

What is missing, and the smallest change: a **world template** per candidate — one sponsor, one clock, the
pay observer, eight pre-enrolled members, a frozen clock, one checkpoint at the head — built once by the
existing `genesis.sh` + `mini bootstrap` (≈3 s) and tarred; `row_*` restores it by copying the Store
directory, rewriting the three absolute paths in `pinned-config.json`, and `mini serve` (≈2 s). That is a
shell helper in `scripts/pipeline/journey-rows` beside `product_inputs` (:48-57); no Lean. A **`mini world
fork --from STORE --at H --to DIR`** is the same copy plus log truncation above `H` and a `prefixAt`-checked
open; its one real obstacle is identity: a fork shares the parent's domain and `storeTag`, and the grain
platform keys its world by `storeTag` (`composed-inputs.sh` refuses an existing `/var/lib/mini-spk-worlds/$store`),
so forks serve Host rows, not grain rows, until the tag includes the path or the registry allows two roots.

Rows that collapse onto the one template (shape 1 in §B): journey's J1–JAUDIT, rooms, demo, bounty, call,
send, domain, upgrade, objectrecord, chargedfailure, jpay (JPAY2/E2 keep their own Store today for no reason
the scripts state), hermes, m3, m4, jserve — fifteen of twenty-eight. Not: KT (`L=8`), exchange (two domains),
perf/births (the genesis is the measurement), the grain worlds (storeTag), objective (two worlds; could take two
templates).

## E. Three recommendations

1. Install the pay law and the controller's pay-control capability unconditionally and plumb the observer
   through `run.sh init`, so an observer is an admitted transition on any world (first file:
   `Kernel/NativeHostGenesis.lean:677`).
2. Build the per-candidate world template with eight genesis-enrolled members and a frozen clock, and make the
   fifteen shape-1 rows restore it instead of standing up their own (first file: `scripts/pipeline/journey-rows:48`).
3. Move `grainBirthTariff`, `completionCustodianKey`, the creation tariff and the template window out of
   `Config.runtimeParameters` into a controller-installed, version-monotone platform cell, ending the
   re-genesis class after one last digest change (first file: `Kernel/NativeHostContext.lean:97`).
