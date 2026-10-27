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

## 2026-10-27, second pass: the restatement at cc5ebd26

Deltas only.

| statement | verdict |
|---|---|
| `Authorized`, `Admits` | WEAK: right shape, but `Context.auth` and `Context.encode` are free |
| `StaysSorted`, `VersionMonotone`, `RecordsValid`, `Reachable` | SOUND, except `Reachable.genesis` accepts any valid record, not the deployment's |
| `ReceiverAuthenticated`, `forged_refused`, `trustsSubjectField_not_decides` | SOUND relative to `auth`; teeth real |
| `CustodianStep` / `CustodianNeverDropped` | Drop branch SOUND. Rotation branch has NO POLES |
| `premises_inhabited`, `sorted_load_bearing`, `stale_version_refused`, `invalid_refused`, `zero_lifetime_invalid` | SOUND (poles over `toyAuth`) |
| `BirthsReadCurrent`, `BirthQuoteCurrent` | WEAK: `platformAt = none` is an escape; `BirthQuoteCurrent` has no poles |
| M2 exemption (`RefillChargeExempt`, both poles) | TRUE of `preflight` |
| `RefillLawful` raise | A HOPE: `install` cannot raise `available` |
| `replay_refused`, `forgetful_not_lawful`, `anySigner_not_lawful` | SOUND |
| registry | SOUND |

**The exemption is true; the refill is not realisable.** `DurableCommitProtocol.preflight` refuses
`noCells` only when `rootWrites = [] ∧ nullifiers = []` (line 300), so a nullifier-only intent passes,
and a zero `exactCharge` passes `fundedCheck` (line 310). But `install` (line 162) sets
`available := before.available - intent.exactCharge`, and `Intent` (lines 55-61) has no credit field.
A nullifier-only, zero-charge intent leaves the meter exactly where it was. No intent the protocol can
express produces `raised m.remaining r.amount`. `Meter` is a parallel model of `Snapshot` with no theorem
linking them (law 5). Fix, stated here first: add `Intent.credit`, set `available := before.available - exactCharge + credit`, and
state who may set a nonzero credit: only the refill family, via `RefillAdmits`. Without that, any family
could mint meter. The conservation theorem at lines 227-228 then has to carry the credit term. Add a teeth pole refusing an overflowing credit (the `Theory.ResourceCost` width
boundary).

**Rotation hole: closed on paper, untested.** Naming a first key (`none → _`), drop refused, rotation
only with `verifiesKey old bytes s`: the rule is right. But `toyAuth.verifiesKey` is constantly
`false`, so no pole exhibits a cosigned rotation being admitted. No pole shows an uncosigned rotation
(`some a → some b`, `a ≠ b`, no cosign) refused either; `custodian_drop_refused` covers only the drop.
Add both. `CustodianNeverDropped` is a corollary of `custodian_drop_refused`, not a keystone.

**Realizer slots are still prose (law 1).** `Context` is any `(config, auth, encode)`.
`verifies := fun _ _ _ => true` makes `forged_refused` vacuous (its premise never holds) and every
statement accept forgeries. `verifiesKey := true` reopens rotation. Worse, `encode` need not cover
the record: `toyContext.encode` signs only `[version]`, so a relay could swap the tariff or the new
custodian key under a valid controller signature and custodian cosign. The fix: define
`Context.deployed snapshot config`, with `verifyNative`, `capabilityEvidenceChecked` and the family
codec, quantify the keystones over that alone, and state `encode` injective on `(next, nonce)`.
The same applies to `RefillContext.encode` (the toy signs only the nonce, so the amount goes unsigned).

**Births.** `BirthsReadCurrent` and `BirthQuoteCurrent` constrain only stores where `platformAt` returns
`some`. A store whose platform cell is missing or undecodable may be priced arbitrarily. Add the
conjunct `platformAt store = none → terms store = none` (and `quote … = none`). `BirthView` is free in
the same way `Authority` is, so `currentReader_reads_current` holds by definition. Its teeth
(`genesisReader_stale`) are real. `BirthQuoteCurrent` needs a satisfiable pole and a stale-tariff teeth
pole.

**Small.** `Install.nonce` is never read by `Admits`; install replay is refused by the version clause,
so either drop the nonce or say it is codec-only. `Reachable.genesis` should be
`g = genesisRecord ctx.config`. Refill nullifiers `(subject, nonce)` share the durable nullifier space
with every other family, so they need a family tag.

**Before proof work:** the `Intent.credit` statement, deployed-context quantification with injective
`encode`, and the two rotation poles.

## 2026-10-27, third pass: the restatement at 89dc0e17



| delta | verdict |
|---|---|
| deployed `Deployment`, transcript boundary, `Reachable.genesis = genesisRecord host` | SOUND (boundary stated) |
| `covers` / `wireEncode_covers` / `relay_swap_refused` | SOUND |
| rotation poles `cosigned_rotation_admitted`, `uncosigned_rotation_refused` | SOUND |
| births: absent-cell refusal, `currentQuote_current`, `genesisQuote_stale` | SOUND |
| `Install` nonce dropped | SOUND: an old signed install is below the current version |
| `install_conserves_with_credit`, `installToday_loses_credit`, `overflow_refused` | SOUND as targets, but about a local mirror |
| `CreditConfined` | WEAK: confines by a self-declared tag |
| `family_tag_separates` | SOUND but constructor-trivial; same mirror |

**The meter is still a mirror (law 5).** `installAvailable`, `MeterIntent`, `Meter` and the tagged
`Nullifier` are local to this file. `DurableCommitProtocol` is unchanged, so "the refill's post-state is
the install of its own intent" holds of `installAvailable`, not of `install`. The keystone that makes M2
about the deployed meter is missing. State it now as a Prop: once `Intent.credit` exists,
`(install before intent).available = installAvailable before.available (meterView intent)`, and
`Meter` is `⟨snapshot.available, snapshot.consumed⟩`.

**`CreditConfined` checks the tag, not the source.** Its clause is `family ≠ .meterRefill → credit = 0`.
Any producer that labels its intent `.meterRefill` can mint credit, and the teeth only refute an honestly
mislabelled intent. The confinement that matters is: `committed intent → intent.credit ≠ 0 →
∃ m r, RefillAdmits ctx m r ∧ intent = r.intent`. Its teeth: a `.meterRefill`-tagged intent with credit
and no admitted refill.

**Residuals:**
- The custodian's first key is the controller's choice, and nothing stops the controller naming its own
  enrolled key. `verifiesKey` and `verifies` read the same transcript triples, so the controller's own
  signature would then count as the custodian's cosign. Add `key ≠ keyOf controller` to the
  naming step, or state the trust-on-first-name boundary next to the transcript boundary.
- `Deployment.host` and `Deployment.genesis` have no coherence premise: the controller comes from one,
  the genesis record from the other.
- `wireEncode` has no deployment or domain tag. Across worlds, replay protection relies on the
  envelope pinning `expectedSemantics` (`Host/Json.lean:2322`); cite that in the boundary note.
- `holdsInstall`, `holdsRefill`, `keyOf` and `layout` are still free functions, which is the declared
  realizer boundary.

**May proof work start?** L1 (platform cell, births, custodian): yes. M2: after two statement-level
additions, the install-link Prop and the source-confined `CreditConfined`; proving against the mirror
would reproduce the integration gap ATLAS law 5 names.

## 2026-10-27, fourth pass: the receiver, the holder law, the plan-time birth verdict (6fffa0de)

| item | verdict |
|---|---|
| `admitsObserved_decides` | SOUND as "gate = spec", relative to the oracles |
| `receiverDecides`, `receiverContext` | WEAK: synthetic store, and the signed bytes are not `encode` |
| `installPatch_record_only` (controller fixed) | WEAK: installs only; genesis and other writers not covered |
| custodian rotation by raw cosign | SOUND |
| `unsigned_refused`, `delegate_refused`, `controller_install_admitted` | real gate poles; they do not touch the codec or the signature path |
| `holderPolicy` and its five theorems | SOUND for mutations; "nothing else" overstated |
| capability check before the law | SOUND |
| `grainPolicy_member_witness_refused` | motivating closed instance, not teeth of `holderPolicy` |
| `birthRefusal` | no agreement theorem; three divergences |

**(a) Receiver.** `admitNative` is the real path (`verifyNative`, `authorize`, `cosignAnswer` under the `old`
key `decideRecord` read from the same loaded cell, then the gate). The cosign covers `commandCodec.encode command`, which includes `expectedPlatformRoot`,
so it cannot be replayed onto another pre-state. Rotation is closed. Two gaps:
1. *The sponsor does not sign `encode i`.* The envelope is over the `signingHeader` of `request …`,
   which commits to the command only through `argsDigestBytes` (a cSHAKE of the command bytes and the
   declaration). `receiverContext.encode` is `commandCodec.encode`. So the real verifier's transcript has no entry over
   `encode i`, and the `sponsor` hypothesis of `admitsObserved_decides` cannot be discharged from a real
   receipt. `receiverContext` is never used. Fix: make the context's `encode` the signed header bytes, and state `covers` through the
   header (with hash collision-resistance named as a boundary beside the verifier's).
2. *`receiverDecides` runs the gate on `genesisStore controller h.current`,* a store built from the
   spec, and feeds it the spec's own `oracle`. It is a corollary, not a theorem about the loaded
   cell. Missing: for every durable snapshot reached from genesis,
   `PlatformCellDomain.load` yields `recordOf = some h.current` and `controllerOf = some
   genesis.factoryController`. `installPatch_record_only` is the install half; the genesis
   half and "no other family writes the cell" are missing.

The poles posit `Observed` booleans; add one pure pole through `prepare` on a concrete snapshot.

**(b) Holder law.** For verb-2 mutations outside the refill slot, `holderPolicy_nonowner_only_witness`
forces `witnessCaveat`, which zeroes all four `State` deltas: settlement and management are
unreachable through the witness form. But the outer `.any` also admits verbs 1 and 3 (observe, delegate) and the refill edge
for every non-owner. A holder may re-delegate its parent grant, so witness authority spreads at
holders' discretion, bounded only by the grant carrier's attenuation. Restate it as "nothing else among mutations", or keep delegate out of member grants. Ordering holds: `DeclaredResourceController.authorizeLeg` (lines 706-717) obtains capability evidence
per leg before the law is judged, and `law.admit` consumes it by type.

**(c) Plan versus submit.** `birthRefusal` evaluates `Pred.eval law.predicate step.oldState
step.newState`. `admitBranch` runs `law.admit wanted evidence law.witness …` after the epoch and
revision checks. Divergences: (1) unlike `invokeRefusal`, it skips the range and cast verdicts, so a
`policyInputRange`/`policyCastAlias` refusal at submission stays undisclosed;
(2) a `prepareDraft`/`preparePending` failure at plan returns `none`, so the plan is silent;
(3) plan and submit prepare at different heights and snapshots. The statement owed, on one snapshot
and height:
`birthRefusal … (.birth b c) = some _ → ∀ cred r, (pending.admitBranch .factory cred r) is .error`
(a plan refusal is never one submission would admit), and
`admitBranch … = .error .policyRejected → birthRefusal … = some _` (every law refusal is disclosed).
Both need `law.admit … ≠ none ↔ eval ∧ ranges ∧ casts`.
Across time, claim only that drift makes the submission stale.

**Before proofs:** (a) signed-bytes `encode` and the loaded-cell controller invariant; (b) the
"nothing else" scope fixed; (c) the agreement statement, with range and cast in `birthRefusal`.

## 2026-10-27, fifth pass: fast-forward open statements (lane/hot-path-codec acad2eb7, HOT-PATH §2(h))

| statement | verdict |
|---|---|
| 1 MAC gate over v4 | SOUND (about the deployed `openSealed`) |
| 2 suffix extends snapshot | SOUND, with one unstated scope (truncation) |
| 3 exactness over snapshot + suffix | NOT WELL-TYPED against today's `Loaded`; `representsCheck` cannot run |
| 4 keystone | WEAK: premise is provenance the open cannot decide, no teeth; must be an induction; needs World equality |
| 5 audit | SOUND; needs a refusal pole |

**1.** `openSealed` (`DurableCheckpointCodec.lean:693`) is the deployed gate; its check order matches
the named poles, and the MAC hashes `bodyStream.encode body`, so the new fields are covered.

**2.** Real, but a tail-truncated suffix (rollback to any height above the checkpoint) is accepted,
as replay accepts a truncated log: state it, or bind the open to the head anchor (`headTag`).

**3. The blocking finding.** `Loaded` carries `image : Image` with
`chainExact : chain = chainAfter logStart image.accepted` and
`indexExact : index = PresenceIndex.ofRecords image.accepted` (`DurableReceiverCore.lean:981-1009`).
`representsCheck` (`DeployedRepresentsCheck.lean:68`) reads `image.accepted` for the nullifier keys,
the transaction ids and `w.head = image.accepted.length`. An open that "reads no entry below the
checkpoint" has no `image.accepted` for the prefix. Statement 3 either re-reads the prefix or cannot be built. Before elaboration, `Loaded` needs a
checkpoint-relative shape: `prefix : Body` with
`chainExact : chain = chainAfter prefix.chain suffix`, indexes `= prefix.ix.extendFrom prefix.height
suffix`, and `representsCheck` restated over the six indexes (keys from `spentAt`, txs from `txs`,
head from `height`) instead of `image.accepted`.

**4. Keystone.** (i) *Circularity.* An ff-opened `L` inherits `B`'s World, so its next seal is the replay's value only if `B` was. State it inductively: define `HostWritten key fold : Store → Prop` (genesis; append; a seal by
`storeCheckpoint` of a `Loaded` from either open of a `HostWritten` store). Then prove
`HostWritten s → ∀ checkpoint at h, body = replayBody fold (s.prefix h)`. Inhabitant: the genesis Store plus appends. (ii) *No teeth at the open.* `Body` has no semantics or World-fold identity, and the key is the Store's. A Host binary with a different World
fold that opens the same Store seals under the same key and passes gate 1. "A Store this Host wrote"
is a provenance premise the open cannot decide (law 1). Fix: put `profile.semantics` and a
`worldFoldVersion` in the v4 body (under the MAC) and refuse a mismatch by name (`.foreignFold`). The
teeth pole is then expressible: a body sealed with another fold identity is refused. A same-version fold divergence stays audit-only; say so.
(iii) *`representsCheck` is not enough.* It checks consistency, not equality: `rowOk` is `true`
for every `.head`/`.allowance` row, and spent/journal rows are checked for membership, not value. A `system` that differs from the fold in those rows passes. The keystone
must state `B.system = (foldWorld (prefix h)).system` (and `decodeCells B.state` equal to its cells).
`representsCheck` stays a guard, not the trust argument.

**Light session** (`DurableServed.lean:1059`). It must hold `track` and state, per append,
`track' = WorldTrack.advance track record` (the `ofIntent_run` step). At a seal it must state
`lightSeal L = storeCheckpoint transport rootBytes L indexRoot` byte for byte, so the light sealer is
one more constructor case of `HostWritten`, not a third body producer. `checkpointDifferential` (`:2080`) and the audit
(`DurableStoreAudit.lean:213`) likewise: all three call one `bodyOf L`.

**5.** Add a pole: a Store whose checkpoint at `h` differs from `replayBody` in any field (system
included) is refused naming `h`. A fold divergence is caught nightly, never at open.

**Before `DurableFastForwardSpec.lean`:** the checkpoint-relative `Loaded` and an index-based
`representsCheck`; the fold identity in the v4 body with its refusal; the keystone as `HostWritten`
induction concluding World equality; one shared `bodyOf` for the three sealers.

## 2026-10-27, sixth pass: `Compiler/DurableFastForwardSpec.lean` (lane/hot-path-world-checkpoint 93e94fa2)

| statement | verdict |
|---|---|
| `Derived`, `Body4`, the three `Honest` | SOUND: every field pinned to the genesis replay; World by equality |
| `MacGate`, `MacGateRefusals` | SOUND, but vacuous in isolation (below) |
| `SuffixGate` | SOUND; the anchor closes the foreign-checkpoint hole at the open |
| `TailCutAsReplay` | WEAK: existence only; cuts below the checkpoint uncovered |
| `Exact`, `Wrote`, `Keystone` | SOUND in shape; one `step` for two sessions |
| `AuditSound`, `AuditRefuses` | SOUND |
| `HeadSealZero` | SOUND; the only pole forcing `seal4`/`open4` to round-trip |

**Trivial instantiations.** `ff` cannot replay: its type receives only the checkpoint, the anchor and
the suffix. `bodyOf` cannot carry nothing: `Body4.Honest` pins every `Derived` field. But each `def`
takes its own parameters. With `decode4 := fun _ => none`, `MacGate` holds, and then the checkpoint
branch of `Exact`, `reopenCheckpoint` and `SuffixGate` all hold vacuously (their premises need
`open4 … = .ok`). Only `HeadSealZero` forces `ff` (hence, through `SuffixGate`, `open4`) to accept
`seal4`'s output. **Bundle them:**
one structure `Spec rootBytes logStart semanticsId open4 step bodyOf seal4 ff audit` holding all
eleven, plus `SealOpens : open4 key (seal4 key b) = .ok b` (for this key and semantics), plus an
inhabitation pole: a `Wrote` derivation through `append`, `seal` at a positive height, and
`reopenCheckpoint`.

**Foreign checkpoint versus backup.** `Wrote` reopens only from `(height, body) ∈ store.checkpoints`.
At the open itself the hole is closed by `SuffixGate`'s anchor clause: the stored entry at the body's
height must carry this key's trailer over `body.chain` and its world root, so a different Store's body
fails unless its chain is this one's. An atomic backup is an earlier `Written`, so restore is covered. A non-atomic backup (a checkpoint newer than the copied entries)
leaves the anchor missing. State the Host's selection: the newest checkpoint whose height is at most
the head, falling back to genesis.

**`TailCutAsReplay`.** It needs no named refusal. Rollback detection rests on the signer's `headTag` (ruling (f)). But "as the genesis
replay opens it" is not what it says. It asserts only that some `view'` exists, and only for cuts
inside the suffix. Strengthen it: the cut opens to `View.Honest` of `⟨seed, records.take n⟩`, for
every `n`, including cuts below the newest checkpoint, through the selection rule.

**Light session.** Whole-World equality (`world = worldAt image`) is the right strength. Per append it is the `foldRecords` append step. But `Wrote`
has one `step` and one `genesisView`, while the light session (`DurableServed`) is a separate code
path. Add a `lightAppend` constructor or a theorem `lightStep = step` on `View`; otherwise the light
session is outside the keystone.

**`Loaded` reshape.** Yes, state it now. `View` fixes the observable part, but `representsCheck`,
`chainExact` and `indexExact` still read `image.accepted`. Add `LoadedView : Loaded → View` with
`View.Honest image (LoadedView L)` as the invariant, and `representsCheck` restated over `Derived`.

**Verdict:** proofs may start once there is the bundled `Spec` with `SealOpens` and the inhabitation
pole, plus the light-session clause in `Wrote`. Strengthen `TailCutAsReplay` and add the `Loaded`
Prop in the same commit.

## 2026-10-27, seventh pass: Option A spec (lane/hot-path-v4 41099e07)

**Verdict: unsatisfiable as stated; one change before proofs.**

**`executesNoPrefix` against `exact`.** `exact` requires `view.snapshot = replaySnapshot ⟨seed, pre ++ suf⟩`.
That snapshot is `State.snapshot state (image.accepted.take height)` replayed (`DurableCheckpoint.lean:101-115, 151-156`).
Its model's `journal`, `history` and `consumed` are built from the prefix records. `executesNoPrefix` sets
`view.snapshot = stateSnapshot state` with `state` from `ffState`, whose inputs are the checkpoint and suffix only. Option A
takes the journal out of the checkpoint, so `ffState` has no source for the prefix journal. Two prefixes giving the same body
(a chain collision, which exists by counting) would demand two snapshots from one input. Fix: split the snapshot.
`executesNoPrefix` should speak of the executed part only (`roots`, `available`, the World). Add a clause that `journal`,
`history` and `consumed` are a pure function of the decoded `below ++ suffix` (the same non-executing rebuild as the indexes).

**Does it forbid execution?** Only extensionally. An `ff` that replays the prefix as a check and then returns the
checkpoint's World satisfies it. A fold divergence does break it: a replaying `ff`'s World differs from `ffState`'s, which
reads `body.world`. Non-execution is a cost claim, so make it structural. Define `ff` in `Impl` as
`ffState` ∘ `rebuild (decode below)` rather than a free field, and the type then proves it. That is ATLAS law 5: one
executable path, no twin.

**Dropping the anchor.** Safe, and stronger. The recomputed prefix chain must equal the MAC'd `body.chain`, which binds every
prefix byte, not one tag.

**Tamper guarantee.** The same as the sixth pass for the reader, but it now rests on the chain hash's collision resistance
rather than on per-entry KMAC tags. Name that boundary in the spec's header beside the MAC's.

## 2026-10-27, eighth pass: `Theory/ReceivingVerifier.lean` (lane/un-pred-census 726e1c09)

State of the tree: the module is imported by nothing, `Theory/Receiving.lean:105` still has the old
`Vouchers verify`, and `Ran` does not exist yet in `Compiler/CredentialSignatureAdmission.lean`. So this
pass judges the shape.

| statement | verdict |
|---|---|
| `Verifier`, `pureVerifier` | SOUND |
| `Vouchers` (private `mk`) | WEAK: `ofAnswered` is public, so the privacy is cosmetic; the docstring's "only use is `admitVia`" is false |
| `not_verified_of_not_answered`, `pure_false_not_verified`, `pure_observed_eq` | SOUND teeth, relative to `V` |
| `exists_for_true`, `pureVerifier_poles`, `Verifier.exists_refuting` | SOUND, but all at `Id` |

**(a) Index.** The deputy's worry is right. `Verifier IO` is an open structure:
`⟨fun _ _ => True, fun _ => pure (.ok ⟨true, trivial⟩)⟩` builds without the shim, and `Vouchers` over it
carry nothing. `Theory/` cannot name `receiverVerifier` (import boundary), so the index belongs one layer up.
Every deployed receiver's `prepare`, and every top-level receiver theorem, must be stated at
`Vouchers receiverVerifier`, never `∀ V`. Generic `∀ V` lemmas stay in Theory as tools. Add a census row:
no `Verifier IO` value besides `receiverVerifier`, and no deployed receiver whose type is polymorphic in `V`.
Either drop `ofAnswered` and mint only in `admitVia` (keeping `mk` private), or correct the docstring. The
proofs, not the privacy, carry layer 1.

**(b) `Ran` outside the shim.** A private constructor is unreachable from other files, but `Ran` leaks
through anything its own file exports. Before the conversion lands, check: no lemma or def in that file
returns `Ran q b` for caller-chosen `b` other than the shim; no derived or explicit `Inhabited`/`Nonempty`/
`Decidable` instance for `Ran`; no `unsafe` or `@[implemented_by]` near it (`#assert_axioms` does not see
`unsafe`). Then the only inhabitant is the shim's post-`verify` mint, which is the named layer-2 trust.

**(c) Pilot.** Enough to prove the shape, on three conditions. The pilot must use both `verified` and
`observed` (a `false` answer the family decides on), not only `verified`. Its top-level theorem must be
stated at `receiverVerifier`. And it must carry an IO-level teeth pole: an ingress whose signature the
shim answered `false` yields no voucher for it, which is `not_verified_of_not_answered` instantiated at
`Ran`. Today every satisfiable and inhabitation pole is at `Id`; the pilot must give one at `IO`.

## 2026-10-27, ninth pass: lane/hot-path-v4 571f9981

**Verdict: proofs may start.**

`Impl.ff` (:210) is now a definition: `ffState` (whose type has no prefix), then the chain gate (prefix count
equals `stateBase.1`, the recomputed chain equals `stateBase.2`, and `suffixGate` pins that pair to the MAC'd
body), then decoding. A replaying `ff` cannot be written. `Opened.view` (:224) pairs the executed part
(`stateHead`, `stateWorld`) with `rebuildDerived` and `State.snapshot head records`, so the prefix journal,
history and consumed set come from decoding, and the pass-7 contradiction is gone. `exact` (:346) pins the
executed head's snapshot over `pre ++ suf` to the replay's, and the World to the fold's. It is satisfiable:
a v3 `resume` at `height = length` is exactly `State.snapshot st records`, and a head state exists because
`storeCheckpoint` seals at any height. The laws are bundled: an `ffState` that always errors fails `exact`,
`inhabited` and `headSealZero`. `viewOpened` ties `ofOpened` to the open's view.

One note for the prover. The first lemma `exact` needs is that replaying the suffix from
`State.snapshot base pre` equals `State.snapshot head (pre ++ suf)` for the head state the executing part
builds (roots by `rootTable`, consumed, journal, history). If that equation fails at some corner (a
retired cell, absent bytes), suspect the `State.snapshot` shape before the prover. The `representsCheck` of
earlier passes is replaced by `representsFromDerived`; no change is needed.

## 2026-10-27, tenth pass: `Kernel/ApplicationStreamContinuityFresh.lean` (lane/un-stream-continuity 351dab72)

**Verdict: not yet; two changes before proofs.**

**The left side is weaker than "a fresh opening read".** `Held.verifiedRead : Option (List UInt8)` is a bare
option, and `decide` verifies no MAC. Admission reduces to "some tag equals the tip's tag, and the record and
height equal the tip's". A re-read that copies the tip entry's tag into `verifiedRead` without running
`DurableHistory.Head.verify` satisfies the iff, so the authentication the docstring promises is absent from
the statement. Fix: make `verifiedRead : Option {tag // Head.verify key height record tag = true}` (the
verifier `readerWith` uses), or add that conjunct to the iff. `headTag`'s authentication is `Loaded`'s
invariant; name it as a hypothesis in the same shape.

**Deployed path.** `decide` is called "the pure core of `withOpenedFreshTip`"
(`ApplicationStreamContinuity.lean:208`), but nothing ties them, and today's `withOpenedFreshTip` does not
call it. Add `withOpenedFreshTip_refuses : … = .ok _ → decide … = .admitted`, or define the IO by `decide`,
in the same commit.

**Teeth.** These are named refusals, but as closed `decide +kernel` instances (law 9). The general content
is the iff plus `noRead_noAdmission`, which is adequate. Stale and forked tips share `.tipChanged`; that is
acceptable.

**`Loaded.extend` dropping the tag.** It is a defect against `Loaded.headTag`'s own docstring ("read from
(or appended to) the Store"). `extend` (`DurableReceiverCore.lean:1434-1480`) is pure and cannot know the
tag, but the IO append that wrote the entry computed it under the key. The cleaner fix is
`Loaded.withHeadTag` set by the append path, with
`appended_headTag : (append …).headTag = some (DurableHistory.trailer key height …)`. That makes the
re-read unnecessary on the Host's own path. Keep (a) for robustness only. Pin the append lemma in this
statement module too, so the fix cannot regress to `none` silently.

## 2026-10-27, eleventh pass: `Kernel/ObjectiveActivityEffect.lean` (lane/un-effects 60cd8f64)

**Verdict: proofs may start on Performed, Refused, Verdict, TransferMoves and Resumed. Three
statement additions come before the Delivery\* and CommitJudged proofs.**

**On the deployed path.** Yes. `commitYield`, `transferVerdict` and `settle` are the kernel's own
functions, and the Delivery\* statements quantify over `Delivery`, whose `batchExact` (`ObjectiveActivity.lean:3296`)
is the deployed batch. The ordering is right: `settlePurse` checks `pair + deposit` on the purse after the
delivery's charges AND the effect transfer (`:2456-2461`), so a transfer can never leave the purse
underfunded. Safety holds even where the verdict errs.

**`VerdictStatement` is complete over `transferVerdict`'s four outcomes** (reserved, closed, unfunded, settled).
But it judges against `funds.book`, which for a delivery is `applyOperations book (purseCharges …)`
(`deliveryFunds`, `:3119-3123`). The batch applies `deliveryCharges …`, and nothing states that these
agree on the purse balance and the open-account set. If they disagree, a transfer judged `settled` is
refused at `settlePurse` as `awaitsFunding`, which refuses the whole turn under the wrong name, or a
covered one is recorded `unfunded`. **Add `FundsAgree`:** the purse balance and the `accounts` of
`funds.book written` equal those after `deliveryCharges` (and likewise for the birth's funds, `:2722`).

**Storage-deposit independence is asserted, not stated.** The verdict is judged with the reserve of a
`settled` await (`commitYield`), while `settlePurse` charges the deposit of the record actually committed,
whose await may be `refused r`. They agree only because `VerdictWire` is two octets for every verdict (a
comment at `:255`). **Add** `storageDeposit config (nextRecord … ⟨…, .performed v, …⟩)` independent of `v`.

**`CommitJudgedStatement` binds to the same `admitWrite`** that `Delivery.judged` (`:3318`) uses, with the same
`factsOf payer height object 2 (some pin)`, so a commit and an await are judged by one law. But (i) it is an
instance of the existing `judgeWritten_ok delivery.judged` (`:5207`), so it adds no content beyond the
`Delivery` field. (ii) Births (`:2781`, other facts) are not covered, though a first segment can yield
`commit`. (iii) Its "a law-refused commit admits no turn" has no pole. **Add** a birth clause and a teeth
pole: an object whose law refuses the write makes `deliver` return `.error (.objectWrite _)`. Also
inhabit the premise `committed.written = some _`: `SatisfiablePole`'s `commit {write: {}}` may build
`none`.

**Deputy's additions.** (a) *Issuer well as `config.asset`:* this is the kernel's convention, not invented
here. `CanonicalResourceKernel.lean:63` says "an asset is named by its issuer-well account", and `:150`
says "the asset identifier is its issuer-well identifier". `AccountId` and `AssetId` are both `Nat` (`:64-65`), and
`ObjectiveActivity.lean:3721` already refuses `request.account = config.asset` as the issuer well.
(b) *`TeethPole`* is quantified over the context but fixed in its numbers (purse 10, reserve 3, amounts 8
and 1). It is a non-vacuity witness, which law 9 permits, not the general teeth. The general shape is
`RefusedStatement` with `VerdictStatement`'s refusal clauses, so that is adequate. Its docstring's
"purse, recipient and state untouched" is not in the Prop; that claim belongs to
`DeliveryRefusedStatement`, so the docstring should point there.
(c) *Changed conclusions.* `Delivery.yield_reserves_deposit` now reads the purse after the effect transfer
too. That is **stronger**: a transfer only lowers the purse, so the old conclusion follows. Justified.
`commitYield_spec`'s write clause went from `stateWrite … = .ok committed.written` to
"∃ built, stateWrite = .ok built ∧ committed.written = some w → built = some w". That is **weaker than
needed**: it is justified only for a refused transfer, which drops the built write, but it gives up equality
for every other plan, and for `none`. Restate it as `committed.written = built ∨
(committed.await.source = .performed (.refused _) ∧ committed.written = none)` so consumers of the
equality keep it.

## 2026-10-27, twelfth pass: L1 restatement 7e39fe90 (pass-4 (a) gaps)

**Verdict: two of the three gaps are closed. Proofs may continue. Two statement items are owed before
the receiver is called "decided on the deployed cell".**

**Gap 1, signature coverage: CLOSED.** `receiverContext.encode current i = m.frame current (commandAt roots i)
i.validUntil`, the signed header's frame that `verifyNative` receives. `CredentialSignatureAdmission.prepare`
refuses unless `controller.envelope.header = header snapshot … validUntil` (`sourceBinding`), so the frame
is the receiver's own. The custodian cosigns the same frame.

**`PinCollision`: a real collision, not the old vacuity.** Its two fields are `source p i ≠ source p j`
and equal `pinDigest customization` of exactly those two strings. It is inhabited only by an actual
cSHAKE collision on compared inputs, which matches the `ArgumentCollision` pattern. `Context.binds` derives
it from `pins` (realised through `frame_effectsDigest`) and `sourceCovers` (the injective codecs). No
statement takes it as a free escape.

**Gap 3, a pole through the real path: CLOSED.** `signed_command_admitted` builds the ingress with
`ingressCodec`/`commandCodec`/`canonicalEnvelopeCodec`, decodes it back, shows the envelope frame is
`encode`, and admits through the gate and `Admits` with the verdict recorded under the enrolled key. That
is the transcript boundary, as agreed.

**Gap 2, decided on the loaded cell: HALF.** `Reachable.controller_stays` and
`platform_written_only_by_install` (from `kernelOnly [.platformInstall]`) are proved. `receiverDecides`
now quantifies over any loader satisfying `Reachable` and `holds`. Two things are still owed. (i) The bridge
from the deployed loader: for every durable snapshot the Host reaches, `PlatformCellDomain.load d snap =
some L → Reachable d.controller L.cell.logical`. This is the conjunction of the writer theorem and a
genesis clause. (ii) The genesis clause has no producer. `NativeHostGenesis` seeds no platform cell
(no `PlatformCellLayout.genesisStore` in the seed), so on today's genesis `load` is `none` and every
install is `platformUnavailable`. That is expected until L1's re-genesis, but state it as the owed
keystone, not leave it as a hypothesis.

**`validUntil`: checked, but by the verifier, not the spec.** The deployed path refuses an expired
header: `CredentialSignedEnvelopeController.prepare` tests `envelope.header.validUntil < state.height`
(`:293`) against the request's admission height (the Host's logical height, not a wall clock), and it
surfaces as `CredentialSignatureAdmission.Reject.expired`. But `PlatformCell.Admits` never mentions
`validUntil`, so the spec admits an expired install that the receiver refuses. Soundness holds (the
receiver refuses more), but `receiverDecides` covers only the gate. Add `height ≤ i.validUntil` to
`Admits`, with a teeth pole `expired_refused`, so the spec and the full receiver agree.

## 2026-10-27, thirteenth pass: prefix entries with tags (hot-path-v4; judged on the described amendment)

The pushed tip (`107f040d`) still passes record bytes, so this pass judges the amendment as described.
**Verdict: nothing from passes 7 and 9 breaks, on one condition.** `ffState` still has no prefix in its
type, so execution stays impossible. The added prefix `verifyTags` from the seed's chain is a further
refusal, and an honest Store passes it because `exact`'s `OwnEntries` already verifies every entry's
tag, so `exact` stays satisfiable. Reading receipt roots from the tags is decoding, not execution. The
reader's prefix guarantee moves back from chain-hash collision resistance to KMAC; update the header.
**The condition:** the root log read from the tags is new served state. `Opened.view`/`View` must carry it,
and `View.Honest` must pin it (each entry's receipt root equals the replay's root at that height), or `exact`
and `keystone` leave it unstated.

## 2026-10-27, fourteenth pass: partial `ofOpened` and `reopens` (hot-path-v4 aa025c8d)

**`reopens` is the right form.** It is stated under `exact`'s hypotheses, not over `Wrote`, and that is
the stronger and more reusable choice. A `Wrote` reopen already carries `ofOpened opened = .ok loaded`
as a premise, and every `Wrote` checkpoint is honest by the keystone, so a per-`Wrote` restatement would
only be a corollary. `inhabited` now includes a successful build.

`reopens` is true only if the build refuses nothing the replay accepts. Both of its checks meet that bar:
- *Nullifiers:* a suffix record carrying a prefix nullifier fails `preflight`'s `nullifiersFreshCheck`
  (`.alreadyConsumed`).
- *Transaction ids:* `DurableCommitProtocol.execute` (`:427`) answers a recorded transaction id with
  `.replayed`/`.transactionConflict`, never `.accepted`.

So the proof rests on `replay` demanding `.accepted` for every record; cite that lemma. Admissibility for
`pre ++ suf` from admissibility for `pre` should follow from `mem_cellIds_append`.

**Missing teeth: the build's soundness.** `viewOpened` and the keystone constrain builds only on Stores
this Host wrote. Nothing states what a successful build guarantees on a MAC-valid Store whose suffix
reuses a prefix nullifier. Either instantiate `Loaded4 := Loaded`, so the real resume proof makes it hold
by type (say so in the spec), or add `buildSound : ofOpened opened = .ok loaded → (impl.view
loaded).snapshot = (protocol resume of the image)`, with a teeth pole: a suffix record carrying a prefix
nullifier makes `ofOpened` refuse.

**Addendum, fce764f7.** `buildSound` (`:391`) has the right shape, but `Impl.stateCheckpoint` (`:214`)
appears in no gate. Nothing ties it to the MAC'd body's `state` (or to `State.ofSeed seed` from genesis),
so the law is relative to whatever starting state `ffState` reports. Add `stateCheckpoint state =
body.body.state` to `suffixGate` and `stateCheckpoint state = State.ofSeed seed` to `genesisGate`.
Then `buildSound` is about the checkpoint the reader authenticated.

**Addendum, un-effects 2aaf5ec9: the pass-11 additions are stated. Proofs may proceed.**
- `FundsAgreeStatement` states agreement on purse balance and open accounts for every `written`. Its
  birth clause holds by definition. The disagreement it found (the submitter or the collector is the
  purse) is now refused before the verdict (`Delivery.purseApart`). That is a new refusal, which is right,
  though `payerInvalid` is a loose name for "the collector is the purse".
- `DepositIndependentStatement` quantifies over both verdicts and every other yield field, so it is the
  general form.
- `BirthCommitJudgedStatement` covers births.
- `DeliverLawRefusesStatement` follows `deliver`'s order and names `.objectWrite reason`.
- `commitYield_spec` keeps equality except for a refused transfer, as asked.

One remaining weakness: `CommitLawRefusedPole` exhibits only the `judgeWritten` refusal. No witness
satisfies `DeliverLawRefusesStatement`'s twelve premises jointly. Add one through a concrete delivery
when the fixtures allow; until then, that statement's premises are not shown inhabited.

**Addendum, un-stream-continuity-wip e0916a53 (not yet elaborated): the pass-10 gaps are closed.**
`decide` = `decideWith held.authentic`, where `authentic` is `Head.verify` at the held height, chain
and frontier. `hotRegistration_iff` names `Head.verify … = .ok head` for whichever tag is the
candidate, so copying the tip's tag is refused (`teeth_copiedTagUnverified`, `openingUnverified`).
`withOpenedFreshTip` builds `Held` from the session's own `durable` (height, `headTag`, chain,
frontier; `ApplicationStreamContinuity.lean:236-237`), not from the physical read, and runs the
handoff exactly when `gate (decide …) = none` (`handoff_runs_iff`).

`appended_headTag` pins `Appended.next.headTag = some entry.tag`. The stale, forked and below-birth teeth
quantify over every verifier `v` through `decideWith`, which is stronger than a closed instance, not
weaker. Proofs may start once the file elaborates green.

**Addendum, un-pred-census 0d7156f19 (reasoned, not built).** The shape requested in the eighth pass is
in place:
- `Ran` is the live `Answered`, minted once, after `verify`/`verifySshsig` returned `.ok`.
- `live_voucher_has_ran` is the IO-level tooth over the type.
- `admitted_live_ran` (`Kernel/Receiving.lean:512`) is the top-level theorem at
  `receiverVerifier (.live config)`, and it covers both verified and observed.
- `receiverVerifier` is restricted to the receiving modules, and `ofAnswered` is honest in its docstring.

Two gaps remain:
1. **`Ran` has no fields, so `by constructor` or `⟨⟩` in any other file mints one without writing
   `Ran.mk`.** The module's own comment says it: private `mk` "stops names but not `by constructor`".
   `check-receiver-verifier.sh` counts the text `Ran\.mk`, so it misses that. The guarantee therefore
   rests entirely on `TokenCensus` checking, at the term level, which compiled constants reference
   `Ran.mk`. Confirm the restricted row is checked over the environment (not by grep), and add a plant
   (`⟨⟩ : Ran c q a` in another module) that the gate must catch.
2. **`.recorded`:** `receiverVerifier (.recorded t)` vouches for whatever a constructible transcript
   says. That is fine for fixtures, but the Host's receivers must be shown to run at `.live`. Add a census
   row or check that `.recorded` is named only in fixture or assurance modules.

**Addendum, un-pred-census f013827d6.** Gap 2 is closed: `.recorded` is refused outside fixtures,
assurance and tests, and is never allowed in `Host/`, with a plant. Gap 1 is narrowed but **not closed**.
The gate refuses files that *name* `Ran`, but a forged proof need not name it. Each of these elaborates to
`Ran.mk` by unfolding:
- `theorem x : oracleAnswered (.live c) q a := ⟨⟩`
- `(receiverVerifier (.live c)).Answered q a := ⟨⟩`
- `Vouchers.ofAnswered … (fun _ _ => ⟨⟩)` at the live verifier

`oracleAnswered` and `Vouchers.ofAnswered` are not restricted. The only spelling-independent guard is
term-level. Every forged proof's value contains the constant `Ran.mk`, so add one environment scan,
theorems included, that admits `Ran.mk` only inside `receiverVerifier`. This is a small Lean check over
`env.constants` for one constant, not the whole census. Add a plant for the `oracleAnswered` spelling.

## 2026-10-27, fifteenth pass: clock law controller clause (lane/lean-critical bc88a5ab, not built)

**The clause must require the clock unchanged.** `clockPredicate`'s `.monotone` conjuncts forbid only
regress. Under `controlClause`, a step whose subject is the controller with a management verb may move
`clock/now` and `clock/slot` *forward* by any amount. A forward jump is not harmless. Every `validUntil`
(`CredentialSignedEnvelopeController.lean:293`), every deadline and every expiry reads that clock, so a
jump expires all of them at once, and that is controller authority the ruling did not grant ("manage,
never tick").

Relying on the clock cell's writers never projecting a management request onto a clock write is a
premise outside the law (law 1). It holds for today's writers, but no theorem pins it, and any future
family or a generic receiver path breaks it silently. Legitimate management (install, revoke, delegate)
changes the cell's policy and grants, not its `now`/`slot`, so requiring them unchanged costs nothing.

**Change:** `controlClause controller := .all [subject = controller, verb ∈ controlVerbTags,
.eq "clock/now/delta" 0, .eq "clock/slot/delta" 0]` (or whatever the clock's projected delta slots are
named). Add the teeth pole `pole_controller_advance_refused`: a controller management step that moves
`now` forward is refused.

The remaining statements read correctly:
- `clock_refuses_nonticker_tick` now covers the controller, because no management tag is tick tag 11.
- `clock_control_present` and `clock_control_cannot_tick` mirror the pay pair.
- `platform_seeded` (`NativeHostGenesis.lean:893`) answers the twelfth pass's owed genesis clause: the
  platform cell is in `baseCells`, and its store is `Reachable` under the controller. The loader bridge
  (`load d snap = some L → Reachable …`) for snapshots after genesis is still to be composed from it and
  `platform_written_only_by_install`.
