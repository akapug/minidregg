# HOT-PATH state — 2026-10-29, codex

Law 17: a fixed-size operation may cost at most O(log n) in accumulated history
and state, or O(changed · log n) for a multi-entry change. Full exports must be
charged for their output; silently making every append a full export is a
violation. Ember explicitly made flatness a gate for this task. K-HIDE-ROTATE
stays. Operator-MAC sealed walk snapshots on our own filesystem are approved.

**This batch is partial. Cold certificate restore is not implemented. The
whole-cell write path remains linear.** Implemented: persistent receipt history
with unchanged admission propositions; a checked exact root-preimage size
lemma; submit/propose and real SandMD GET flatness instruments and gate wiring.
Do not describe those as completion of the persistent-state layer.

## Tree, integration and checks

- Local tree: `/Users/ember/dev/minidregg-lanes/hot-path`, `lane/hot-path`, Git HEAD
  `a523d87b1e359f47610593dca50979564bd8a164`. The sandbox refuses `.git/ORIG_HEAD.lock`.
  Main at task start was `636b1baebb7d0b94a330cab6d5e6109f0c961f6b`. It merged cleanly
  in an independent scratch clone. Its binary diff is applied to the local files;
  Git metadata still names the old tip. Incoming main changes are not lane work.
  `target/hp-commit.sh` checks hashes, removes that exact overlay, performs the real
  merge, commits named lane paths in themes with the required attribution, and pushes.
- Warm Lean tree: hbox `/home/hbox/lanes/hot-path/src` (not `/home/hbox/lanes/hp`).
  Only the receipt changes were overlaid there on its `1e207e402` base. The exact
  modified StoreCodec file was checked separately as `target/hp-codex/StoreCodecUpdated.lean`.
  This is scoped checking, not a whole merged-tree candidate build.
- Own hbox scratch: `/home/hbox/lanes/hp-codex/scratch`. Processes have individual
  `.pid` files there. Builds use non-root hbox, `swarm-build`, `SWARM_MEM_MAX=28G`,
  `XDG_RUNTIME_DIR=/run/user/1000`, `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus`.
  Native builds use two Lean seats and two C jobs. No outer closure-lock on lane-check.
- `check-root-cost.log`: REPL and lane-check of the exact modified StoreCodec, EXIT=0.
- `check-history.log`: REPL-first PersistentHistory, then lane-check of NativeHostReplay,
  the initial 12 changed receipt selectors, CarriedApplicationDispatchReceiver and NativeHostSession,
  EXIT=0. The list-specified `AdmittedReplay`/`AdmittedSuffix` propositions are unchanged.
- `build-receipts.log`: native Host + consent both built, EXIT=0. Host sha256
  `4f1f2d88f3e007d890ac16d0540ea1a05cab6d6720a3b93160d2a37738e15c65`;
  consent sha256 `9b77510fc2ce528d74aa53d53321a560e8b8b10261f49f159cf0f1b1d4f31fc7`.
  A final review converted the legacy ApplicationDispatchLookup selector too:
  `check-final-receipts.log` checks that and final Host.Main/ClientConsentSession,
  EXIT=0. That last selector and formatting cleanup postdate these native binaries.
  No claim of an exact final merged-tree candidate is made by these development builds.
- Benchmark verdict unit tests: 11 pass. Linear growth, missing/duplicate samples,
  non-growing history, invalid/under-resolution costs and incomplete passes are rejected.
  Shell syntax checks pass. No Lean was run on the Mac; no sorry/admit/new axiom was added.

## Receiving and opening paths traced

`NativeHostSession.start` calls `openExisting`, which reaches
`DurableReceiverIO.loadChained`. Despite its checkpoint fold, this function still
calls `transport.read 1 true`, decodes the whole journal, verifies the prefix
chain and rebuilds history indexes. `openState` folds only the suffix;
`openLoaded` still consumes the entire prefix. The separate light path,
`DurableServed.openHead`, really does read from the checkpoint. Optimizing only
`walkPhysical` does not make the full session's startup suffix-only.

The first walk-family request calls `walkPhysical` and `NativeHostReplay.verifyLoaded`
from genesis. Retained exact readback uses `extendExact`; recovery/refresh may use
`extendVerified` and its whole-prefix comparisons before the suffix walk. Current
validation uses `validateLoadedFrom`/`validateServedFrom` to limit which cells are
checked, but still decodes each changed cell in full.

`Host.ClientConsentCore.verifyInitial` also opens the full log. Its retained-anchor
route, `ConsentAnchor.resume`, deliberately uses `Loaded.prefixOwn` to fold from
genesis: the old rule rejects the operator checkpoint as a client base. Failed
resume, and an upgrade requiring full lifecycle context, use `verifyLoaded`.
The newly approved same-filesystem snapshot trust must be connected to this
provider as well as the Host; leaving it unchanged preserves the cold replay.

`workspace.rs::propose_summary_once` reads full signed resource views.
`document_actions` then calls `host_document` even for a fixed append, renders the
whole document and scans `runs_at_tail`; guard refresh scans page entries too.
The growing client work is therefore identified, not an unexplained timing residual.
Lean must provide a current authorized append context (root, tail, covering runs,
required guards); Rust must not reconstruct semantic permission decisions.

## Design: one persistent-state layer

The process-resident Host already holds a validated opening and a lazily admitted
walk. The missing layer is persistent indexed data shared by open, receiving,
projection, certificates and checkpoint publication, with exact list/codec specs.

The receipt part now uses `Kernel.PersistentHistory`: a newest-first immutable
list plus `Std.ExtTreeMap Nat α`. Push shares the list tail and changes a tree
path; lookup follows a tree path. `get?_eq`, `toList_push`, `toList_append`,
`get?_push_last` and `get?_push_before` connect it to the old chronological list.
`Verified` and `SuffixVerified` retain this structure. Operational selectors use
`receiptAt`; proof/full-export `receipts` still materializes the list. Suffix
extension counts by retained height plus suffix length, without concatenating
or counting the old receipts. This fixes receipt storage and selection only.

### Cold snapshots: implementation still required

Use a versioned certificate-data codec, bound to checkpoint height, log start,
chain, world root, configuration/semantics identity and operator key id, with a
separate MAC domain. Store it beside that checkpoint, never as an unbound latest
file. Write data first and publish the manifest last; an interrupted publication
leaves the previous complete checkpoint/snapshot pair usable. Wrong MAC, schema,
configuration, root or chain must refuse reuse; rollback must still refuse.

Restoring ids alone is insufficient. Replay retains issue/reserve/begin/claim/
created/running/grant/retry families, Fn frontier audit and selected releases.
`IssuedEvidence.sourceExact` contains original native admission, with record,
ingress and descriptor equalities. `RawEvidence.sourceExact` is destructured by
`RawEvidence.bindContext` (and lifetime dispatch). `PriorLifetimeGrant.finalRoot`
also derives its exact root from original admission. These are proof-erased
existentials, not serializable witnesses that a MAC check can synthesize.

Decision: keep the existing pure admitted-history types/theorems for the audit
path. The restore path needs explicit sealed provenance, paired with independently
checked data equalities (receipt/record, ingress, descriptor, root, context).
A theorem turning sealed provenance into original admission must name the
operator's custody/writer premise; do not silently redefine original admission
as “admitted or sealed”, add an axiom, or unsafe-cast a decoded record into Verified.
Current authority, policy revision vs revocation, exact preimages and uncertain
reply recovery continue to be checked by the same receiving rules after restore.

A complete implementation must also avoid serializing all certificate lists at
every checkpoint: persistent keyed certificate pages, a sealed root manifest,
and changed pages only. Restore the manifest/index and load selected pages; walk
the suffix while extending the same indexes. Reuse the checkpoint/suffix physical
open rather than the current `read 1 true` path. Genesis audit remains available.
Missing snapshots may rebuild once and publish, but a good snapshot must not
silently trigger genesis admission. Required receiving tests: restart after
pre-checkpoint issue/reserve/grant, consume each afterward, repeat with consent,
tamper each binding, rollback, partial publication, and unknown reply readback.

## Remaining accumulated-size costs (source inventory)

Here `H` = history length, `E` = entries in a changed cell, `B` = its encoded bytes,
`C` = cell count, `K` = retained certificates, and `Δ` = changed entries. These
are outstanding work, not benchmark verdicts or a proof that no other path grows.

| Term and source | Present cost | Required change |
|---|---|---|
| `DataWrite.canonicalPostBytes`, record encoding/hash/fsync/replay | O(B) each append, O(n²) bytes for n fixed document appends | Canonical patch + resulting root; same executor and exact-readback semantics |
| `Materialized` replacement encode, StoreCodec decode/root, DeployedBridge pin, storage charge | At least Ω(E+B); canonical sorting adds work | Persistent keyed entries, changed-path encoding/commitment, maintained charge; caches alone do not change the bound |
| K-HIDE-ROTATE and current root | O(E) even when Δ=1 | Exact constraint below; do not substitute root-only privacy |
| ContentLaw/EventHistoryLaw | At least Ω(E), now one pass | Incremental checker equal to the full law under the held pre-law witness |
| `ResourceObservationAdmission.projectWith`, resourceSlots, bytesSlots, balances | Whole resource/byte projection | Demand-driven lookup proved equal to list `State.get`, per predicate atom |
| `Pred.indexState` | O(projected slots) per law check | Share persistent state index; do not rebuild from the projection per request |
| Full signed views + document append preparation in workspace.rs | O(E+B) transfers/scans, multiple observations | Authorized bounded append-context query from Lean; full exports explicitly output-sensitive |
| `Verified` certificate lists: `find?`, `present`, retry and Fn/frontier histories | O(K), sometimes plus list indexing into H | Keyed indexes with exact first-match semantics, including duplicate/ambiguity refusal |
| Receipt append/selection | **Fixed here:** O(log H) push/get | Keep operational users on receiptAt; full list export is still O(H) |
| `Image.accepted` reverses acceptedRev; list take/drop/map/index in refresh/history consumers | O(H) when materialized | Persistent history index/cursor with list specification, authenticate a suffix against a held head |
| `Loaded.rootLog` / chainLog flat Array pushes | Potential O(H) COW when old openings share arrays | Persistent tree sequence; prove/select original-prefix roots, not current recomputations |
| `SessionIndex.TxIndex`, KeyIndex and cell-id HashMaps/HashSets | Shared flat hash-array updates can copy accumulated state; hash collisions also lack a strict logarithmic bound | Persistent ordered indexes with the same first-index/membership specifications |
| Direct transaction `findIdx?` in dispatch/lifecycle receiving and lookups | O(H) even though Loaded.firstIndex already exists | Use the exact cached lookup; also fix its persistent representation as above |
| `extendVerified` prefix/seed comparisons, Fn selected-poll historical zip | O(H) / seed size | Retained authenticated prefix identity and keyed selected evidence |
| `storeCheckpoint` -> State.ofSnapshot -> image.cellIds/map, full body codec/MAC | O(C + total cell bytes) every 64 records | Immutable addressed pages and O(Δ log n) manifest updates, not periodic full traversal |
| Full opening `loadChained` -> openLoaded | At least all journal bytes + state, even with checkpoint | Checkpoint+suffix open with persistent index roots, no prefix read/decode/rebuild |
| Cold walk and consent prefixOwn / verifyLoaded | O(H) admissions plus state work | Bound sealed certificate context to the same checkpoint; resume both clients |
| Directory/authority row enumeration and whole-cell account/member/index payloads | O(C), members or ledger entries on affected paths | Persistent typed indexes, touched-key validation and projection; distinguish fixed queries from full enumeration |

### What the kept privacy ratchet actually forces

The deployed commitment is **not a Merkle tree**. `StoreCodec.rootPreimage_length`
proves that its preimage has exactly `44 + 32 * (entries W store).length` bytes.
`rootBytesFast` removes allocations but still feeds those bytes to the flat hash.
A cached root of an unchanged cell helps reads; every new cell version still pays
this amount. A Merkle tree over the present leaves alone does not solve blinding.

`StoreHiding.view` sends one Item per entry: opened salt+entry or hidden 32-byte
leaf. `change_detection_only_via_root` says no hidden leaf survives an in-place
hidden write, except by a KMAC cross-key coincidence or cSHAKE leaf collision.
Fresh blinding changes every salt preimage, including unchanged entries. Thus,
for **this KMAC/cSHAKE leaf scheme and flat authenticated-view format**, producing
the new root/view performs Ω(E) leaf/preimage work and a full view has Ω(E) output.
Lazily computing leaves can defer work, but the flat root immediately demands all
of them. Per-entry epochs or a fresh wrapper around a stable Merkle root expose
stable hidden sibling commitments across views and do not preserve that theorem.

This is not a universal lower bound for every hiding commitment. A rerandomizable
commitment with updateable authenticated selective openings would require a new
construction and corresponding binding/hiding/cross-view statements. No such
construction is implemented or proved here. Keep the current ratchet and expose
its remaining linear cost; no further privacy choice is being deferred to Ember.

## Flatness gate and measurements

`scripts/perf/flatness-gate.sh CANDIDATE NEW_ROOT [N=1000] [LO=10]` runs submit/propose
and GET, then writes `flatness-submit` and `flatness-get` rows. Both run even when
submit fails. It records the candidate SHA256SUMS hash. A fresh root is mandatory;
missing results, missing metrics, failed operations and interrupted runs fail.

Each sample records actual accepted history size. Compare mean costs at operations
6–10 with the final 10 by default, bounding the ratio by
`max(1.5, mean(log2 late_history) / mean(log2 early_history))`. CPU is the explicitly
selected service process tree, including waited-for child CPU; wall is end-to-end.
Do not interpret a passing finite comparison as an asymptotic proof. Submit can
fail at a completed 100/200/400/800-operation prefix; it cannot pass before N.
GET runs the full N. Certification is normal admitted work every 96 appends or
32 GETs, outside measured requests, to preserve the deployed 256-record tail law.
Certification cost is therefore not certified flat by these two metrics.
The fixture explicitly allocates 10¹² units in each physical meter lane at
GENESIS, through NEWPARTICIPANT_METER_ALLOWANCE / WORKROOM_METER_ALLOWANCE.
Defaults for other workloads are unchanged; the participant template digest
includes the selected allocation. Account funds and physical meter allowance
are separate. This does not remove a bound, top up a running world or relax admission.

On hbox, use a private NVMe root under `/ci/<lane>` for the route world: the standard
resident custody inventory cannot execute its copied runtime under `/home`.
All services use their own PID files and world-down/stop-residents cleanup.

The integrator's new `/home/hbox/lanes/integ/gate10.sh` extends gate9: after tour,
composed and enrol finish, it runs this candidate's flatness harness serially and
feeds its TSV to `gate-from-runs.py --tour`. Missing harness or failed fresh-root
creation yields FAIL, never an old green result. gate9 is unchanged. The reviewed
copy is `target/hp-scratch/gate10.sh`; the integrator must select gate10 for the next
cut. A production candidate has not run this combined gate yet. The real
`gate-from-runs.py` was exercised with synthetic verdict inputs: all-pass PASS;
failed-flatness and incomplete-flatness FAIL despite otherwise passing inputs
(`/home/hbox/lanes/hp-codex/scratch/gate-aggregation`).

Runs on the existing batch-1 candidate `cand-b2c` (not the new receipt binary):

| Run | Samples | CPU early → late | Wall early → late | Verdict |
|---|---:|---|---|---|
| `scratch/fs2`, submit | 100 | 104 → 863 ms (8.30×) | 241 → 1577 ms (6.53×) | FAIL, bound 2.00× |
| same, propose | 100 | 26 → 242 ms (9.31×) | 582 → 4113 ms (7.07×) | FAIL, bound 2.00× |
| `/ci/hp-codex/fg5`, GET | 40 | 144 → 158 ms (1.10×) | 260 → 349 ms (1.34×) | PASS smoke, bound 1.50× |

`fs2` certified successfully at operation 96 (installed at acceptedCount 98).
`fg5` reached head 68 and world-down recorded removal_assertions=0.
`fg6` stopped at GET 894 with HTTP 403, head 947; it has no passing flatness result.
The fixture exhausted its 10⁷-unit storage allocation: Lean decoded the final
checkpoint and previous record (`meter-diagnosis2.log`): available.storageBytes
= 10,674, previous GET exactCharge.storageBytes = 10,895, fundedCheck = false.
The receiver hid the precise durable reason behind “durable dispatch refused”;
this is the metering diagnosis, not an observed detailed refusal code. The
new explicit genesis allocation above fixes the instrument's capacity. Some
fg6 timing overlaps builds; none of its partial samples are a passing result.

`/ci/hp-codex/receipt-smoke2` ran the combined gate on the development assembly
`hp-codex/dev-receipts` (the two native binaries above plus cand-b2c Rust roles).
All 40 appends installed. Submit CPU 150→361 ms, wall 341→568 ms; propose CPU
34→89 ms, wall 620→981 ms: all FAIL (bound 1.580). GET CPU 154→219 ms and wall
734→964 ms: PASS (bound 1.5). Overall gate FAIL, as required; GET ran after the
submit failure. Both worlds stopped; route removal_assertions=0. The first
smoke assembly lacked candidate params.sh and failed setup; smoke2 supplied
that fixture helper. Neither is a packaged candidate or a tour result.

`fs3` requested 1,000 appends with the new genesis allocation and stopped on a
completed failing prefix at 100: result.json records n=100, requested_n=1000,
stopped_early=true, FAIL. Submit CPU 106→1016 ms (9.585×), wall 299→1388 ms
(4.647×), propose CPU 30→282 ms (9.400×), all above the 2.000× bound.
Propose wall 1110→1766 ms (1.591×) passed in this run. It overlapped fg7 in
its middle, so keep the per-run verdicts instead of combining wall observations.
Both fixture genesis files were checked to contain the requested 10¹² allowance.

`/ci/hp-codex/fg7` completed all 1,000 GETs, head 1,058, with the larger meter
allocation and these receipt binaries: CPU 174→268 ms (1.540×), wall
491→607 ms (1.238×), bound 1.958×: PASS for both metrics. It certified through
operation 992 and then measured the final window. World-down recorded
removal_assertions=0; its runner stopped. The mid-run submit workload finished
before its final window. The complete result, earlier small results and the
smoke gate TSV are copied to local `target/hp-evidence/`.

All processes started for the completed fixtures have been stopped through
their own PID files/normal teardown. The lane's Lean REPL was stopped as well.
No other lane's processes, files or caches were removed.

## Batch 1 (integrated on main; historical comparison)

Contents: perf-batch1 (codec writer, cell bytes/root cached per cell value, decodeFast) + its two reds fixed (CellSlot,
DeployedBridge); contentlaw d81cb88ce (one-pass document laws); index 8c78cc96a (packBits single pass, deployedRoot one-pass
canonicalization); charge e403b95bf (historical records identity-first, charges materialized once); pred f463d78f2 + owner fix
0bcf19b71 (policy-state index built once per law check: the first version rebuilt it per wire read, a 15x regression, caught
by the bench); profile 346136236 + owner 2009a6eb8 (profile and receiver-semantics digest cached per config); seed 95ab8cc3b
(genesis evidence reused on session advance); history a6e414ce8 + owner fixes (journal newest-first, `Loaded.height` =
`rootLog.size`); verifier 172d90188 + owner c733612ec (Ed25519/SSHSIG in-process through mini-kernels; opaque externs);
merge of main 64fa47015 + owner fixes 6e11bed52, 1e207e402 (journal x chainLog proofs). Host.Main + ClientConsentSession were checked on hbox. This is the previous batch's record, not a claim about the current tree.

Numbers (hbox; baseline candidate 2b8f75dcb):
| measure | before | after |
|---|---|---|
| doc submit CPU, append 1 / 10 / 20 | 280 / 490 / 780 ms | 50 / 130 / 200 ms |
| doc submit wall, append 1 / 19 | 384 / 842 ms | 133 / 303 ms |
| per-append growth (submit CPU) | ~26 ms | ~8 ms |
| GET / via SandMD route, serving-Host CPU | 1,100-1,200 ms | 150-170 ms |
| GET / wall (fresh world, /tank Store) | 1.3-1.5 s | 0.53-1.1 s |
| POST /new (qualify write) | 4.6 s | 1.3 s |
| SandMD qualify (create..page) | 367 s | 136 s |
Left on the turn after batch 1 (append 20 profile): encoding ~16%, policy-state index ~13% (once per law check, several
checks per turn), store decode/lookup ~10%; GET wall is now mostly outside the Host (Store fsync on HDD, app, spk-host).
Propose wall grew 254 -> 555 ms over 20 appends with 10-60 ms Host CPU. The source of growing client work is now traced below.

## Next work, in order

1. Implement checkpoint-bound certificate restore and consent reuse, using the
   explicit provenance boundary above; make the physical full open suffix-only.
2. Change the actual receiving write representation to persistent patches/cells,
   then connect incremental laws, demand-driven policy state, keyed certificates
   and incremental checkpoint publication. The root/ratchet limitation remains
   explicit until a replacement hiding commitment is proved and integrated.
3. Build the whole merged tree once in the integrator lane and run gate10's tour,
   composed scenario and both flatness paths. No lane source check substitutes for it.
