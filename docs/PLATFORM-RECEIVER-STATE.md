# Platform receiver: state for the successor (2026-10-27)

Branch `lane/lean-critical` at the commit that adds this file (worktree
`/Users/ember/dev/minidregg-lanes/lean-critical`, the Mac's warm `.lake`). The statements
were audited three times; the third pass (`docs/review/2026-10-27-platform-cell-statements/AUDIT.md`,
lane/audit-platform 90af8593) cleared them for proof work.

## Landed

| sha | what |
|---|---|
| 97205be6 | S1: the pay law and the controller's pay control at every genesis (`Kernel/NativeHostGenesis.lean`, frame `GENESIS-SOURCE/v7`) |
| cc5ebd26, 89dc0e17, de53563d | `Kernel/PlatformCell.lean`: every statement, pole and teeth (L1 platform, M2 refill, protocol link) |
| 92341df2 | enrollment pin survives ticks (`NativePlanHeight.pinHeaderAt`, consent `enrollmentPlanAtObservation`) |
| 5f86883e | proved: `staysSorted`, `reachable_sorted`, `versionMonotone`, `recordsValid`, `decideInstall_decides`, `decides_authenticated` |

`Kernel/PlatformCell.lean` is the spec. Its reference receiver is `decideInstall` (with
`custodianCheck`), and it is proved to decide `Admits`. The registry reserves 240-243
`PLATFORM_INSTALL_{PLAN,ASSEMBLE,SUBMIT,LOOKUP}` (owner `platform`) and 244-247
`METER_REFILL_*` (owner `durable-meter`). `check` refuses an active `*_SUBMIT` whose effect is
not `append`.

## Not started (nothing mid-flight; the tree is clean at this commit)

Order (coordinator, 2026-10-27): the cell kind and its layout, then the install receiver,
then replay, then the Host arms, then the genesis seed, then births priced from the cell,
then `Intent.credit` and the refill ops.

### Next three steps

1. **The `platform` cell kind.** Write `Kernel/PlatformCellLayout.lean`, a cell module on the
   shape of `Kernel/SeatCell.lean` / `Kernel/PayCell.lean`. It holds the `layout` (the
   `Platform` fields plus `version`), `materializer`, `schemaId`/`wireVersion`, a
   `registryTag` (next free tag after `.seat` = 20), `physicalId domain`, and `CellValid` =
   `Platform.valid` of the decoded record. Then add `| platform` to
   `CanonicalCellRegistry.Kind` and every exhaustive site in
   `Compiler/CanonicalCellRegistry.lean`:
   - `Kind.all` (:136), the `decide` list at :270, `Kind.lawClass` (:219; `.lawBearing`)
   - `Kind.tag` (:276) / `kindAtTag` (:296), `schemaRef` (:338), `layout` (:~370),
     `materializer` (:386), `wire?` (:425)
   - the `none` arm at :439, `blinded`/`isBlinding` (:448/:455), the law match at :751,
     `UserShape` (:852/:860)
   - a `FamilyId.platformInstall` (:144; the list at :216)

   Then run `lake build Compiler.CanonicalCellRegistry` and fix every downstream exhaustive
   match the build names (per-file green hides a red umbrella). Also
   `Compiler/PersistedCodecShapes` (`scripts/codec-shapes-regen.py`) and
   `Compiler/PersistedCodecTagCensus` for the new identity strings.
2. **The install receiver.** Write `Kernel/PlatformInstallReceiver.lean` on the
   `Kernel/PayBookReceiver.lean` shape. It needs:
   - `Command` (sponsor, control, the `Platform`, the expected platform root, an optional
     custodian cosignature) with a framed `commandCodec`; `wireEncode` in PlatformCell is
     the coverage model, and the real codec must satisfy `Context.covers`;
   - the ingress pair (command bytes plus sponsor envelope);
   - authority in capability mode with the operation slot `authority/operation/platform-install`;
   - the pure decision = `decideInstall` over the decoded cell's history;
   - the single write (the new record, version strictly increasing);
   - theorems `genesis_change_accepted`, `same_version_refused`, `invalid_record_refused`
     (decide on the genesis store, like PayBook :244-260), and `Decides` of its pure
     decision against `PlatformCell.Admits`.
3. **Replay and the Host arms.** Register the family in `Kernel/NativeHostReplay.lean` beside
   PayBook. In `Kernel/NativeHost.lean`, add `platformInstallPlanLoaded` / assemble / submit /
   lookup on PayBook's `payPlanLoaded` pattern, with `Host/Main.lean` arms for 240-243. Then in
   the registry, set the four ops `active` with their receivers, `effect: append` on the
   SUBMIT, and 240 in `consent_plans` with a `NativeSpecializedConsent.expectedPlanBytes` arm.

After those: the genesis seed (`NativeHostGenesis`: the cell born with `genesisRecord host`;
frame v8; re-genesis, carried by rehearsal #3 or #4). Then births: replace `source.tariff` /
`config.grainBirthTariff` / `completionCustodianKey` / `template` reads with the decoded
platform cell of the birth's pre-state, add the cell to the birth's read guards, and prove
`BirthsReadCurrent` / `BirthQuoteCurrent` of that reader. Last, as ONE mechanical commit,
`Intent.credit` (default 0) in `Kernel/DurableCommitProtocol.lean` (:55 Intent, :162
install, :227 `install_exact_debit` restated with credit = `install_conserves_with_credit`),
`ProtocolInstallMatches` proved of the real install, and the refill ops 244-247.

## Verify (exact commands, from the worktree)

```
sh scripts/build-mini-kernels.sh
LEAN_NUM_THREADS=6 lake build Kernel.PlatformCell Kernel.NativeHostGenesis \
  Compiler.PersistedCodecTagCensus Kernel.NativePlanHeight Kernel.NativeSpecializedConsent \
  Host.ClientConsentSession Host.Main
python3 -I scripts/host-operations.py generate && python3 -I scripts/host-operations.py check
timeout 600 python3 -I scripts/test-host-operations.py
```

All green at this commit. Commit with `git -c commit.gpgsign=false commit -F <scratch file>`,
named files only, never `git stash`, push `HEAD:refs/heads/lane/lean-critical`.

## Open for the parent

- The demo's `edge/demo/genesis-params.json` (dregg-infra) needs `payControlCapability`.
- The meter: turnBytes ~1,000 per record against 10^7, so the per-minute clock alone uses it up
  in about 6.9 days. Raise `meterAllowance` to at least 10^10 per lane in the v7 re-genesis until
  M2 lands.
- Known boundaries recorded in PlatformCell's header: the controller may name its own first
  custodian; `Deployment.host`/`.genesis` carry no consistency premise; the install encoding has
  no domain tag (replay across worlds rests on `expectedSemantics`).
