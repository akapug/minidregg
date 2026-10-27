# Platform cell statements: adversarial audit

Object: `Kernel/PlatformCell.lean` at `lane/lean-critical` 984fb241 (statements commit af8832d1), against
GENESIS-COUPLING §C L1/M2, `Kernel/PayBookReceiver.lean:150-260`, and registry codes 240-247. Read, not elaborated (no warm `.lake`).

## Verdicts

| statement | verdict |
|---|---|
| `Admits` (the spec all keystones share) | WEAK: unauthenticated signer, no record validity, empty history admits anything |
| `VersionMonotone` | WEAK: true list lemma; the inductive invariant (admission preserves `Sorted`) is missing |
| `ControllerOnly` | VACUOUS: `P ∧ Q → P` |
| `BirthsReadCurrent` | WEAK, close to a proxy: no height, no tie to the birth receiver, creation tariff only |
| `InstallSatisfiable` | SOUND (as a pole of `Admits`) |
| `InstallTeeth` | SOUND as stated; incomplete (no zero-lifetime or invalid-record teeth) |
| `HistoryInhabited` | WEAK: a singleton list; does not inhabit the premises of `VersionMonotone` |
| `Decides` / `ignoresSigner_not_decides` | SOUND shape; inherits every `Admits` weakness |
| `RefillLawful` | WEAK, and unrealisable by the deployed path: ignores the refill record's own meter debit |
| `refillReference_lawful` | SOUND |
| `lawful_monotone` | SOUND (pointwise per lane, stronger than the sum); one-step scope only |
| `replaces_not_lawful`, `anySigner_not_lawful` | SOUND |

## Per statement

**`Admits controller history install`** says: `install.subject = controller`, and for every `current`
with `history.getLast? = some current`, `current.version < install.next.version`, and
`0 < install.next.lifetime`. (1) `install.subject` is a field the requester writes; "controller-signed" is not modelled. The
deployed authority is the controller's `installPolicy` capability on the cell and a verified Ed25519
signature (`PolicyInstallReceiver` carries subject, capability id and signature; `NativeHostGenesis`
`controlCapability`). This is law 12 and law 4: the statement binds a claimed name, it does not force
the signer. (2) On `history = []` the version conjunct is vacuous, so any install at any version
(including 0) is admitted; the design says genesis's record is always first, so `History` should be
`Platform × List Platform` (genesis, installs), making the empty case unrepresentable. (3) No record
validity. PayBook's monotone theorem carries `next.valid`; here an install with `grainBirth = some ⟨0, _⟩`
is admitted although `Config.grainBirthTariffValue` refuses base 0, so every grain birth after it fails.
A custodian key not 32 bytes is admitted too, and `some key → none` silently turns checked completion
off. Separately, `controller : SubjectId` is a free parameter: every theorem holds for every subject, so
nothing pins the deployment's `factoryController` (law 3: instantiate the deployed value).

**`VersionMonotone controller`**: for every history and install, if the history is `Chain'` strictly
increasing in version and `Admits` holds, every record in the history has version below the install's.
True and non-vacuous, but a fact about lists: nothing states that the cell's history IS sorted. The missing
keystone is the invariant: `Sorted h → Admits c h i → Sorted (h ++ [i.next])`, or better, an inductive
`Reachable genesis : History → Prop` (genesis, then admitted installs) with `Reachable h → Sorted h`.
Without it the `Sorted` premise is never inhabited by any deployed object (law 5). No teeth pole shows
`Sorted` is load-bearing (`[v5, v1]` with an install at v2 is admitted and not above 5).

**`ControllerOnly controller`**: for every history and install, `Admits controller history install`
implies `install.subject = controller`. That is the first conjunct of `Admits`; the proof is
`admitted.1`. Restate over the receiver and the signature:
for the deployed receiver `post`, `post store req = .ok _ → SignatureVerifies controllerKey req ∧
holds store controller installPolicy platformCell`, with teeth a forged-subject request (subject field
equal to the controller, signature by another key) refused.

**`BirthsReadCurrent priceAt`**: for every history and every `current` that is its last element,
`priceAt history = some current.creation`. (a) There is no height. Whoever calls `priceAt` chooses the
list, so a birth receiver that reads a stale prefix satisfies it. "At their height" needs the birth's
pre-state: `priceAt (platformAt store) = ...` where `platformAt` reads the platform cell in the store
the birth commits against, with the cell itself under `rootsMatchCheck`. (b) `priceAt` is arbitrary; nothing names the deployed quote (`Host/Json.lean:2341`): a carrier
without a realizer slot (law 1). (c) Only `creation` is constrained; the grain
birth tariff, custodian key and `{ownerBudget, lifetime}` are not, and the design's "grants carry an
explicit window" (window = birth height + current lifetime) is absent. (d) No poles: no satisfiable
reader exhibited and no teeth (a reader of `history.head?`, the genesis record, after one install).

**`InstallSatisfiable controller`**: there exist genesis (version 0) and next (version 1, lifetime > 0)
with `Admits controller [genesis] ⟨controller, next⟩`. Exhibited concretely with `freeTariff`; a pole of the spec; the proof phase owes the receiver pole (`genesis_change_accepted`
shape, `decide +kernel` on the genesis store).

**`InstallTeeth controller`**: (i) for every history whose last record is `current` and every `next`
with `next.version ≤ current.version`, the controller's install is not admitted; (ii) for every
`other ≠ controller` and any next, `⟨other, next⟩` is not admitted. General refusals for the right reason; (ii) is only as strong as the unauthenticated subject field. Missing: zero lifetime refused, invalid record refused.

**`HistoryInhabited`**: some list has a last element. `[x]` proves it. It does not inhabit
`VersionMonotone`'s premises jointly (sorted, at least two records so `Chain'` fires, plus an admitted
install), and once `History` carries genesis by type it is redundant. Replace with `∃ h i, Reachable h ∧
h.length ≥ 2 ∧ Admits c h i`.

**`Decides controller decide`**: for every history and install, `decide h i = true ↔ Admits c h i`.
Right shape; `ignoresSigner_not_decides` refutes the signer-blind receiver for any
`other ≠ controller`, at `[]`, the corner that should not exist. Worth exactly what `Admits` is.

**`RefillLawful controller post`**: for every remaining meter and refill, a refill whose subject field
is the controller yields `some (raised remaining refill)` (lane-wise sum), any other yields `none`. Same
unauthenticated subject. Worse: the deployed path debits every record. `DurableCommitProtocol.preflight`
refuses `insufficientBudget` unless `exactCharge` is funded from `available`, and the post-state is
`available - charge`. So (a) a deployed refill's post-state is `raised (remaining - charge) refill`,
not `raised remaining refill`, and no receiver on the derived path satisfies the statement unless refills
are exempted from the meter, which nothing states; (b) at an exhausted meter, the moment M2 exists for,
preflight refuses the refill itself. The statement must decide this: either refills are charge-exempt
(and say so, with a pole at `remaining = 0`), or the post-state includes the debit and a liveness pole
shows a refill admitted when `remaining` is below an ordinary record's charge. Replay is also
unaddressed: a refill has no identity, so the same signed posting re-submitted adds twice unless the
nullifier/receipt path refuses it; state that refusal. The issuance-cap half of design M2
(`wellFloorAmend`, lowering refused below current negation) is not stated at all.

**`lawful_monotone`**: given a lawful `post` and `post remaining refill = some next`, every lane of
`next` is at least the same lane of `remaining`. Pointwise (implies the sum); one refill transition only, which the label should say.

**`replaces_not_lawful` / `anySigner_not_lawful`**: concrete hostile receivers (overwrite at
remaining 1, amount 0; any-signer at `other ≠ controller`) refuted. Real teeth.

## The three changes before proof work

1. **Model the signature and the deployed controller.** `Install` and `Refill` carry the capability
   id and signature (as `PolicyInstallReceiver` does); `Admits`/`RefillLawful` require verification
   under the controller's enrolled key and possession of `installPolicy` on the platform cell;
   `controller` is the Config's `factoryController`, not a free parameter. Replace `ControllerOnly`
   with the receiver-level statement plus a forged-signature teeth pole. Decide and state whether the
   completion custodian key may be rotated by the controller alone: Host calls it the "distinct"
   custodian key, and controller-only rotation collapses that separation; at minimum refuse
   `some → none` or require the custodian's co-signature.
2. **Make the history the cell's and give it a height.** `History := genesis × installs`; add
   `Reachable` and the `Sorted`-preservation keystone; add record validity to `Admits` (grain base
   positive, key length 32, positive lifetime, PayBook's `valid` shape). Restate `BirthsReadCurrent`
   over the birth's pre-state store, covering all platform fields and the explicit grant window
   `height + lifetime`, with a stale-reader teeth pole.
3. **Reconcile M2 with the meter debit.** State refill charge-exemption or the debited post-state,
   add the exhausted-meter liveness pole and the replay refusal, and either state the issuance-cap
   amendment or record that it is out of this lane.

## Registry 240-247

Well formed (`reserved`, no routes, no receiver; Rust mirror matches). Three issues. (a) `owner: "platform"` on the meter-refill family: the meter is the
durable commit protocol's seed meter, not a platform-cell field, so either the refill posts to the
platform cell (and the statement should say the meter lives there) or the owner is wrong. (b) The
design names a `platformInstall` family and a `platform` kind `.lawBearing`; the design's alternative
for M2 is extending `realmWell` or a `purseRefill` sibling, and reserving a separate `METER_REFILL_*`
family pre-empts that choice without recording it. (c) Every active SUBMIT in the registry is `effect: append`; these two must flip at activation, and the
registry check should refuse an active SUBMIT with `effect: none`.
