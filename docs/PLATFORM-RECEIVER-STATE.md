# Platform receiver: state for the successor (2026-10-27, second handoff)

The Mac worktree `/Users/ember/dev/minidregg-lanes/lean-critical` is on `lane/lean-critical`,
merged with origin/main (fae-4 aaf73ce1 included). Statements, poles and the third audit pass
are in `Kernel/PlatformCell.lean` (the spec). The fourth audit pass is
`docs/review/2026-10-27-platform-cell-statements/AUDIT.md` (lane/audit-platform 6bb1787c).

## Rulings in force (coordinator, 2026-10-27)

- The flag day (`STORE-CELLS/v17`, 43 bumped identities, every Store re-genesis) lands ONCE,
  with the whole platform cell: kind, receiver, replay, Host arms, genesis seed (frame v8),
  and births priced from the cell. Tell the coordinator when the seed is in; the integrator
  takes the branch at that cut. Rehearsal #3 (cut 9) ships without it.
- Op 240 goes in `consent_exempt`, with the reason recorded the way FN_NAMESPACE_PLAN's is:
  it is the controller's operator-route plan.
- O61 (clock control for the controller) joins the genesis seed commit. That means a
  `clockControlCapability` mirroring `payControlCapability` on the clock cell, the theorem
  `clock_control_cannot_tick` from `ClockLaw.clock_refuses_nonticker_tick` (:156), and poles
  per GENESIS-COUPLING §C S2. The statement is in docs/LEAN-COHERENCE-STATE.md on lane/fae-4.
- Delegation of the parent task is the owner's: holders get observation and the witness
  no-op, never delegation. This is done in `AgentGrain.holderPolicy` on lane/lean-l13-laws;
  bring it here when you merge that branch (see below).

## Landed on lane/lean-critical

| sha | what |
|---|---|
| c385eed0 | registry!: `Kind.platform` (tag 21, schema 91020), `Kernel/PlatformCellLayout.lean` (record and genesis-fixed controller), every exhaustive site, the codec cascade (43 mechanical bumps; seed, clock and admitted-input-context raw versions to 4; `seedEpoch_v3_refusedFor`) |
| 835617b4 | `Kernel/PlatformCellDomain.lean`, `Kernel/PlatformInstallReceiver.lean`: `admitsObserved` gate, `admitsObserved_decides`, `receiverDecides`, poles |
| 40599807, 6fffa0de | L13 items (holder law; `birthRefusal`), also on lane/lean-l13-laws |
| 3de3c348, c18c3012 | from lane/lean-l13-laws: the plan/admission keystone (stated) and the holder law without delegation |
| merges of origin/main | built green after the last merge: kernels, Host.Main, ClientConsentSession, census; regen found no move; registry check green |

The unbuilt draft of step 3 is on branch `lane/lean-critical-step3-wip` (8dfbed7a, pushed):
- `PlatformCellDomain.SigningPlan` (frame `DREGG/PLATFORM/PLAN/v1`; tag registered);
- `NativeHost.platform{Plan,Assemble,Submit,Lookup}Loaded`;
- `NativeHostReplay.NativeAdmission.platformInstall` and its dispatch arm;
- the Host/Main arms for 240-243 (241's payload is plan, signature, cosignature; an empty
  cosignature means none).
Cherry-pick it, then:
1. Activate 240-243 in protocol/host-operations.json: receivers named, effect `append` on
   242, 240 in `consent_exempt`.
2. Run `python3 scripts/host-operations.py generate`.
3. Run the codec regen.
4. Build.

## The seed cut also takes lane/un-effects

The deputy's lane/un-effects changes persisted wire and stays off cuts until the seed is in;
the integrator cuts it together with this branch, regenerating codec shapes ONCE over the
merged tree. What it changes:
- `DREGG/OBJECTIVE/ACTIVITY-RECORD/v8 -> /v9` (`Kernel/ObjectiveActivity.lean` `recordFrame`;
  `PersistedCodecTags` `objective_activity_record_v8 -> _v9`).
- Its pin is re-emitted.
- `SourceWire` becomes `(Digest256 × SubjectId) ⊕ (Height64 ⊕ VerdictWire)`.
- Host JSON only besides that; no registry ops, kinds or refusal constructors.
When the seed is green, tell the coordinator so both branches go in one cut.

## Fourth audit pass: statement changes owed before more proof work

(a) **Receiver.**
- The sponsor signs the request's `signingHeader`, not the plain command bytes. Make
  `receiverContext.encode` the bytes the signature actually covers (the signing header with
  the command inside it), and state `covers` over that.
- `receiverDecides` runs on a `genesisStore` built from the spec. Restate it on the LOADED
  cell, with an invariant over every writer of the cell that the controller stays genesis's.
  The writers are genesis and install only; the kernelOnly kind `.platform` is written only by
  `.platformInstall`, and `installPatch_record_only` covers the install.
- Add one pole that decodes a real signed command through the real codec and signature path,
  not assumed oracle answers.

(b) **Holder law.** Done on lane/lean-l13-laws: `holderPolicy` drops verb 3 for non-owners,
with `holderPolicy_nonowner_delegate_refused`. Still to do: the infra delegation line (the
frame's mini-reenroll) grants members `observe` and `mutate` on the parent, never `delegate`.
This goes through the coordinator.

(c) **Plan against submit.** On one snapshot and height, state both directions: a plan-time
refusal implies `admitBranch .factory` errors, and `.policyRejected` implies a plan-time
refusal. This needs `law.admit` shown equal to eval plus the range and cast checks
(`inputsInRange`, `castInjOn`).
- `birthRefusal` must include the range and cast checks (as `invokeRefusal` does with
  `firstRangeRefusal`/`firstCastRefusal`).
- It must surface a `preparePending` failure instead of passing silently.
- `ResourceBirthPolicyController.Concrete` already states `Pending.factoryVerdict`,
  `PlanRefusalSound` and `PlanPassNotLawRefused` (unproved), plus `factoryVerdict_congr`
  (proved), on lane/lean-l13-laws. Extend those.

## Then, in order

1. **Genesis seed (frame v8), with O61.** Seed the cell in `NativeHostGenesis.baseCells` with
   `PlatformCellLayout.genesisStore config.factoryController.subject (genesisRecord ...)`.
   The genesis config lacks `grainBirthTariff` and `completionCustodianKey` (they are runtime
   parameters today): add them to the genesis config, or seed from the pinned
   `NativeHost.Config`.
2. **Births priced from the cell.** Read `recordOf` of the loaded platform cell in place of
   `config.tariff`, `grainBirthTariff`, `completionCustodianKey` and `template` budget and
   lifetime; add the cell to the birth's read guards; prove `BirthsReadCurrent` and
   `BirthQuoteCurrent` of that reader.
3. **One mechanical commit:** `Intent.credit` in `DurableCommitProtocol` (:55, :162, :227),
   `ProtocolInstallMatches` proved, and ops 244-247.

## Verify (from the worktree)

```
sh scripts/build-mini-kernels.sh
lake build Kernel.NativeHostReplay Compiler.PersistedCodecTags   # retry on "Too many open files"
python3 scripts/codec-shapes-regen.py                            # to a fixed point; rc 2 = hand bump
lake build Host.Main Host.ClientConsentSession Compiler.PersistedCodecTagCensus
python3 -I scripts/host-operations.py check
```

The Mac's system file table fills when several agents build at once ("Too many open files in
system"). Retry; do not lower anything. Commit named files with
`git -c commit.gpgsign=false commit -F <file>`, never `git stash`.
