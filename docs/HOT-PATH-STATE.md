# HOT-PATH lane state (2026-10-29, wound down for ember's flight)

**Frame (law 17, ember 10-29): the system never gets slower over time, except by at most a logarithmic factor.**
Per-operation cost must be O(log n) in history and state size; anything scaling with document length, cell size, cell
count, history length or member count violates it. Performance is a gate for this one property (the flatness bench).

Present state; rewritten whole. Branch `lane/hot-path` (= main 1baf18816 + lane/perf-batch1 + fixes). Owner: the
hot-path Opus agent. Brief ground: docs/STATE-OF-MINIDREGG-2026-10-28.md (lane/root-state). Goal: a turn costs
what it changes; rehearsal 3 ships with turns in milliseconds. Scope added by the root: one persistent-state layer
(cold start from snapshot, per-document state, in-process verifier, O(changed) seals, helper ops on the operator
socket) and the perf rake's verified backlog (docs/PERF-BACKLOG-2026-10-28.md, "Ranked backlog").

## Where things are

- Mac worktree `/Users/ember/dev/minidregg-lanes/hot-path` (edit + git only; no Lean on the Mac).
- hbox base tree (SSD): `/home/hbox/lanes/hot-path/src` (clone of lane/hot-path; `.lake/packages` -> `/tank/lanes/hot-path/packages`).
  `/home/hbox/lanes/hot-path/build.sh LOG TARGET...` (lake build under swarm-build, 16 threads, 28G; log `LOG.log`, EXIT= line);
  PID file `/home/hbox/lanes/hot-path/build.pid`. Single-file check: `lake lean F.lean` in that tree.
- Workers (claude-kimi, one item each): Mac worktrees `/Users/ember/dev/minidregg-lanes/hp-<item>` on `lane/hp-<item>`,
  hbox clones `/othersys/lanes/hp-<item>/src` (clone-warm of the base), checks via
  `/Users/ember/dev/minidregg-lanes/hp-tools/hp-check <item> start|wait|log|stop`. Briefs:
  `/Users/ember/dev/minidregg-lanes/hp-tools/briefs/` (COMMON.md + one per item). Logs and PID files:
  `/Users/ember/dev/minidregg-lanes/hp-tools/logs/<item>.{out,pid}`. Items: seed (backlog 1), profile (2), pred (4),
  history (5), index (6+7), verifier (in-process Ed25519 via mini-kernels), contentlaw (quadratic ContentLaw), effects
  (Effects/Revival reds from the Materialized change). hbox clones: `/home/hbox/lanes/hot-path/mkclone.sh ITEM`. Relaunch a
  stopped worker: `hp-tools/hp-resume ITEM [note]` (Kimi runs out of context on big files; COMMON.md has a narrow-reading rule).
- Bench: `/home/hbox/lanes/hot-path/bench-perf.py` (doc-submit-bench + `--perf-at N,M` perf record with DWARF stacks);
  symbols of the memfd-exec'd Host resolve with `perf report --symfs=DIR` where DIR holds the host binary under the
  names `memfd:mini-pinned-image (deleted)` and `memfd:mini-pinned-image`. Folding script: scratchpad `hotpath/fold.py`.

## Measured (hbox)

- GET / via the SandMD route, fresh world on candidate 2b8f75dcb (`/tank/lanes/hot-path/w-2b8f`, standing;
  `route-up.sh TAG LEAN_BIN RUST_BIN`, probe `python3 /tank/lanes/hot-path/worldcpu.py w-2b8f ROUTE_DIR N`, ROUTE_DIR
  `/var/lib/mini-spk-worlds/521505e109919c5c/521505e109919c5c/host/apps/6101/routes/owner-web`): 1.3-1.5 s wall quiet,
  1.1-1.2 s CPU, all in the serving Host. Host profile (`/tank/lanes/hot-path/prof-2b8f/get.script`): 45% policy law
  check on the read path (`checkRead` -> `PreparedLaw.verifies` -> `PredCompile.wit`/`intOf`), nearly all
  `Pred.State.get` (`List.find?`); `receiverSemanticsFrom` 9.5%; `StoreCodec.encode` 9.5%; roots 8%; share-issue and
  birth `charge` 6% each; keccak 2%. POST /new (qualify write): 4.6 s.
- Doc submit, paired, quiet-ish (`pair.sh p2`: `b-p2-base.log` 2b8f vs `b-p2-hp.log` lane 023a13096): submit CPU
  a1 280 -> 170 ms, a10 490 -> 320, a20 780 -> 790 (growth ~30 ms/append both: ContentLaw pair loop + State.get).
  Propose wall ~300 ms with 30 ms Host CPU: the client side (unexplained; an strace wrapper on `mini` hung genesis).
- Earlier (349e59ef1, append 20): DeclaredResourceController legs 18%, `contentLawDecidable`/`documentAt` 15%,
  `DTreeMap.getD` 17%, `rootBytes` 13.5%, `encode` 10.8%, `State.get` 12%, `authState` 11%.
- Lane Host binary: `/home/hbox/lanes/hot-path/artifacts/minidregg-host` (`hostbuild.sh`), bench set
  `/home/hbox/lanes/hot-path/cand-hp1` (2b8f75dcb with that Host). Packages are now a real copy on the SSD (the native
  builder refuses a symlinked `.lake/packages`).

## Batch 1 (sent to the integrator as lane/hot-path 1e207e402)

Contents: perf-batch1 (codec writer, cell bytes/root cached per cell value, decodeFast) + its two reds fixed (CellSlot,
DeployedBridge); contentlaw d81cb88ce (one-pass document laws); index 8c78cc96a (packBits single pass, deployedRoot one-pass
canonicalization); charge e403b95bf (historical records identity-first, charges materialized once); pred f463d78f2 + owner fix
0bcf19b71 (policy-state index built once per law check: the first version rebuilt it per wire read, a 15x regression, caught
by the bench); profile 346136236 + owner 2009a6eb8 (profile and receiver-semantics digest cached per config); seed 95ab8cc3b
(genesis evidence reused on session advance); history a6e414ce8 + owner fixes (journal newest-first, `Loaded.height` =
`rootLog.size`); verifier 172d90188 + owner c733612ec (Ed25519/SSHSIG in-process through mini-kernels; opaque externs);
merge of main 64fa47015 + owner fixes 6e11bed52, 1e207e402 (journal x chainLog proofs). Host.Main + ClientConsentSession green
on hbox; umbrella build running (`b-umb.log`).

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
Propose wall grows 254 -> 555 ms over 20 appends with 10-60 ms Host CPU: client side (mini), unexplained yet.

## Design: one persistent-state layer (what exists, what changes)

The Host already has a process-resident session (`Kernel/NativeHostSession.lean`): the validated full opening
(`Opened`: directory and authority decoded), the light opening (`NativeHostLight.Light`: served state, decoded
directory/authority, revalidated per new suffix only over changed cells, `validateServedFrom_eq`), and the lazily
built genesis walk (`Walked`/`NativeHostReplay.Verified`, extended per record by `extendVerified`/`extendExact`). The
measured per-turn cost is NOT the absence of that layer; it is derived values computed per request beside it:

1. Per cell value (in hand): bytes and root cached in `Materialized` (perf-batch1, `bytes_eq_bytesCached`,
   `root_eq_rootCached`); decoded cells keep their accepted bytes (`decodeFast`). A cell value persists in the
   session until a write replaces it, so its root is hashed once per cell version, not per turn.
2. Per configuration: runtime profile and its semantics digest (worker `profile`); seed identity and log start
   (worker `seed`).
3. Per evaluation: the policy state indexed once (worker `pred`); document law decided in one pass (`contentlaw`).
4. Per historical certificate: the record a `PriorIssue` names is compared by identity first, and record charges
   are materialized once (worker `charge`), so a request never re-derives a historical intent.
5. Across processes (cold start). RULED (ember 10-29): trust walk snapshots on our own filesystem, sealed under the
   operator checkpoint MAC. Design, from the code (Kernel/NativeHostReplay.lean):
   - The walk families need `Verified config target`: the genesis `AdmittedReplay` plus 13 certificate lists
     (`PriorIssue`, `PriorDispatchReserve`, `PriorBegin*`, `PriorClaim*`, `PriorCreatedV3`, `PriorRunningV3`,
     `PriorLifetimeGrant`, `RetryHistory`, `FnConsumerFrontierReplay.Audit`, `PriorSelectedRelease`). Each certificate is
     data (index, ingress, record, receipt) plus `admitted : ∃ original : Opened, ∃ accepted, record = ofIntent
     accepted.intent` (or `ingress.Admitted config record`); consumers use the data, `present` (re-checked against the
     current image) and occasionally the proof (`ApplicationDispatchAgentReserveCore` destructures `raw.sourceExact`).
   - `SuffixVerified config anchor target` (+ `walkSuffix`, `SuffixContext`) already admits natively from an anchor,
     but starts from an empty context: a dispatch naming a pre-anchor issue refuses.
   - Plan: (a) a derived codec for the certificate data (`WalkSnapshot`), sealed beside each stored checkpoint under
     the checkpoint key with its own domain tag (height, chain, world root bind it to the prefix); (b) each
     certificate's proof field becomes `Provenance P` = `walked (h : P)` or `sealed (s : SealedAt config index)`, where
     `SealedAt` carries the MAC check and membership of this certificate in the verified snapshot; consumers take the
     disjunction, so statements gain the explicit premise "or present in a snapshot this operator sealed" (the ruled
     trust), never a silent one; (c) `NativeHostSession.walkPhysical` starts from the newest sealed snapshot at or below
     the head: fast-forward open at its height, restore the context, `walkSuffix` over the records after it; the
     genesis walk remains for `audit`/`store-audit` and when no snapshot verifies; (d) `Verified` and `SuffixVerified`
     unify behind one interface the walk families read (they read only the lists and `opened`).
   - Order: land the per-turn batch first; then (a)+(c) with an interface over the two verified kinds; then (b).
6. Seals: `storeCheckpoint` encodes every cell each `checkpointEvery` (64) records. Amortized O(state)/64; with
   cached cell bytes the encode copies cached bytes. Delta checkpoints only if a measurement shows seals matter.
7. Cell codecs: after 1-4 the remaining doc-submit cost is codec work on the written cell (encode ~27%, decode with
   per-lookup key encoding and `List.Lex` compares ~15-30%). Next owner work: a decoded-store lookup keyed by the
   wire's ordering bytes compared as ByteArray, and encode from the cached entry bytes of unchanged entries.
   RULED (ember 10-29): keep the ratchet; make it fast in constant factors. Blinded cells (Hyperdocument, DeclaredEffect, LegacyContentCarry; StoreCodec
   K-HIDE-ROTATE) re-key EVERY entry's salt on every write, by design, so their root is O(entries) per append however
   it is cached. O(changed) for documents needs per-entry salt epochs, which reveals to a holder of two views which
   entries changed between them; ember keeps the ratchet.

## Running / left on hbox (harmless, PID files)

- Flatness bench on the batch-1 Host: `/home/hbox/lanes/hot-path/flatness-bench.py` (copy of
  `scripts/perf/flatness-bench.py`), PID file `/home/hbox/lanes/hot-path/flat-b2c.pid`, log `flat-b2c.log`, root
  `flat-b2c/` (N=300, lo=10). It stops its own world at the end. No Lean.
- SandMD world on the batch-1 Host, standing: `/tank/lanes/hot-path/w-b2c` (aged ~170 GETs). Tear down with
  `cd /tank/lanes/hot-path/src-run && MINI_OPERATOR_UID=1000 MINI_OPERATOR_NAME=hbox XDG_RUNTIME_DIR=/run/user/1000
  bash scripts/spk-platform/world-down.sh /tank/lanes/hot-path/w-b2c/world`.
- Nothing Lean-heavy: the integrator's host stage of batch 1 (staging f34b03095) has the box; combined Lean caps ~60 GB.

## Next (successor: start here)

Measured violations of law 17 (flatness bench, batch-1 Host, one document): submit CPU 60 / 250 / 620 / 1,140 / 1,740 ms at
appends 2 / 21 / 51 / 101 / 141 (wall 148 -> 3,287 ms); propose wall 261 -> 7,937 ms with Host CPU 20 -> 450 ms (the client
side dominates propose). Cold walk (`audit`, ~200 records): 302 s on 2b8f75dcb, 39 s on batch 1, still O(history).

Growth terms found by reading the turn path (each must become O(log n) or O(changed)):
1. **Records carry whole post-state bytes** (`DataWrite.canonicalPostBytes`, 72 files): every append writes, hashes,
   fsyncs and replays the whole document; the log is O(n^2). Fix: writes carry patches plus the post root; the executor
   applies the patch to the held cell (re-genesis is free). The largest single item.
2. **Whole-cell work on the written cell**: encode (`Materialized.bytes`), root (`rootBytesFast` decodes the bytes just
   encoded), re-decode in `validateLoadedFrom`/`validateServedFrom`, `World.admit` -> `pinFails` -> `DeployedBridge.cellRoot`,
   `DeployedCharge.storageCharge`. Fix: cells as persistent sorted maps with per-entry cached bytes and a Merkle root updated
   along the changed path; bytes produced from the map (rope), never re-decoded.
3. **Privacy ratchet (K-HIDE-ROTATE, kept by ember)**: re-keys every entry salt per write, O(n). What it forces: unlinkability
   against holders of OPENINGS (sibling hashes) requires every leaf to change per write, so O(n) is forced for them.
   Unlinkability against holders of ROOTS and receipts only is achievable at O(log n): stable per-entry salts in a Merkle tree
   and a published root H(fresh secret epoch key, Merkle root). Needs ember's choice between the two guarantees.
4. **Document laws** (`ContentLaw`/`EventHistoryLaw`, now one pass but O(n)): check incrementally (the pre-store held the law;
   check only the new entries against the held document id), proved equal to the full law under the pre-state's validity.
5. **Policy state = whole resource projection**: `ResourceObservationAdmission.resourceSlots` projects the entire observed
   store into string-keyed slots (`DeclaredResourceProjection.project`, `ContentResource.project`, `bytesSlots` one slot per
   byte) before every law check; then `indexState` hashes them all. Fix: a demand-driven state whose `get` computes a slot from
   the store (O(log n) per atom), proved to agree with the list state on every slot (`State.get` congruence lemmas exist).
6. **Certificate lists in the session** (`Verified.issues/reserves/...`): `priorIssueFor` etc. are `find?` with byte
   comparisons over lists that grow with shares and dispatches. Fix: keyed maps with exactness to the first-match `find?`.
7. **Checkpoint seals** encode every cell every 64 records: O(state). Fix: incremental checkpoints (only changed cells, the
   cell store content-addressed), so a seal is O(changed).
8. **Cold start** O(history): sealed walk-certificate snapshots (ruled; design above), then O(suffix).
9. **Client (mini) propose**: wall grows ~50 ms per append with little Host CPU. Unread; likely whole-document work client
   side (reading/rendering the proposal context).
10. GET: per-GET Host CPU looked like it grew 160 -> 500 ms over ~30 GETs, but that window overlapped a build; rerun the GET
    flatness (route world on NVMe: `WORLD_PARENT=/home/hbox/lanes/worlds route-up.sh ...`) before concluding.

The flatness bench (`scripts/perf/flatness-bench.py`, doc submit at append lo vs n, bound max(1.5, log2 n / log2 lo)) is
written for the integrator's gate; a GET twin (`flatness-route.sh`: route world, GET 10 vs 1,000) is not written yet. Order of
work: (1)+(2) together (write patches into persistent cells; this also kills most of 4 and 7), then 5, 6, 8, 9, 3 after ember's
choice. Kimi only for mechanical edits (ember 10-29); proofs and design are the owner's.

Batch 1 umbrella status (my tree): Host.Main + consent green; reds only in Fixtures (NativeAcceptedFixture,
NativeDocWriteFixture, BirthPlanPoles: recorded pins/transcripts to re-record after the codec writer and the in-process
verifier) and Effects/Revival/EngineProofs.lean:45 `materialize_logical` (needs `CellState.Materialized.ext rfl`; the root's
effects worker on lane/effects-proofs owns that file).
