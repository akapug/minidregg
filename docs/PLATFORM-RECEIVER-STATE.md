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
- Not touched: `GrainResourceBirthAdmission.Pending.admitBranch` has the same conflation
  (`law.admit = none` → `policyRejected`). It is outside audit (c) and is a follow-up.
- Next: merge lane/lean-critical 147d3861 (genesis seed), then births priced from the cell
  (statement first), then `Intent.credit` with ops 244–247.
