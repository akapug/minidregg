# HOT-PATH lane state (2026-10-29)

Present state; rewritten whole. Branch `lane/hot-path` (= main 1baf18816 + lane/perf-batch1 + fixes). Owner: the
hot-path Opus agent. Brief ground: docs/STATE-OF-MINIDREGG-2026-10-28.md (lane/root-state). Goal: a turn costs
what it changes; rehearsal 3 ships with turns in milliseconds. Scope added by the root: one persistent-state layer
(cold start from snapshot, per-document state, in-process verifier, O(changed) seals, helper ops on the operator
socket) and the perf rake's verified backlog (docs/PERF-BACKLOG-2026-10-28.md, "Ranked backlog").

## Where things are

- Mac worktree `/Users/ember/dev/minidregg-lanes/hot-path` (edit + git only; no Lean on the Mac).
- hbox base tree (SSD): `/othersys/lanes/hot-path/src` (clone of lane/hot-path; `.lake/packages` -> `/tank/lanes/hot-path/packages`).
  `/othersys/lanes/hot-path/build.sh LOG TARGET...` (lake build under swarm-build, 16 threads, 28G; log `LOG.log`, EXIT= line);
  PID file `/othersys/lanes/hot-path/build.pid`. Single-file check: `lake lean F.lean` in that tree.
- Workers (claude-kimi, one item each): Mac worktrees `/Users/ember/dev/minidregg-lanes/hp-<item>` on `lane/hp-<item>`,
  hbox clones `/othersys/lanes/hp-<item>/src` (clone-warm of the base), checks via
  `/Users/ember/dev/minidregg-lanes/hp-tools/hp-check <item> start|wait|log|stop`. Briefs:
  `/Users/ember/dev/minidregg-lanes/hp-tools/briefs/` (COMMON.md + one per item). Logs and PID files:
  `/Users/ember/dev/minidregg-lanes/hp-tools/logs/<item>.{out,pid}`. Items: seed (backlog 1), profile (2), pred (4),
  history (5), index (6+7), verifier (in-process Ed25519 via mini-kernels), contentlaw (quadratic ContentLaw).
- Bench: `/othersys/lanes/hot-path/bench-perf.py` (doc-submit-bench + `--perf-at N,M` perf record with DWARF stacks);
  symbols of the memfd-exec'd Host resolve with `perf report --symfs=DIR` where DIR holds the host binary under the
  names `memfd:mini-pinned-image (deleted)` and `memfd:mini-pinned-image`. Folding script: scratchpad `hotpath/fold.py`.

## Measured

Doc-submit bench, candidate 349e59ef1 binaries, hbox SSD (`/othersys/lanes/hot-path/b349-1`): submit wall/CPU
301/240 ms at append 1, 557/470 at 12, 745/640 at 19 (CPU +~22 ms per append); propose 224 -> 664 ms. (The earlier
9-30 s walls were /tank HDD fsyncs.) Profile of append 20 (perf, 702 samples, inclusive): DeclaredResourceController
admit/legs 18%; `contentLawDecidable`/`documentAt` 15% (ContentLaw decided as a support x support pair loop: the
per-append growth); `DTreeMap.getD` 17% (store lookups under it); `StoreCodec.rootBytes` 13.5% and `encode` 10.8%;
`Pred.State.get` + `List.find?` 12%; `CredentialAuthorityDomain.Snapshot.ofCell`/`authState` 11%;
`ServedBasis.authoritySnapshot` 10.7%; `receiverSemanticsFrom` 4%; op1 prepare (`prepareAuthorizedLoaded`) 22%.
Route GET (earlier, docs/review/2026-10-27-untouched-areas/ROUTE-LATENCY-STATE.md on main): ~5.3 s single-thread
CPU per Host call, 2-3 calls per GET; whole-image codec/root work and receiverSemanticsFrom.

## Landed on lane/hot-path (not yet on main)

| sha | what |
|---|---|
| fd54bb732 | merge of lane/perf-batch1 (codec writer, cell roots/bytes cached per cell value, decodeFast) |
| 703d0c0af | perf-batch1's red fixed (Theory/CellSlot `decode_eq_decodeFast`) |

## Running

- hbox: base build `build.sh b-host Host.Main Host.ClientConsentSession` (PID file build.pid, log b-host.log).
- Mac: seven claude-kimi workers (PID files above).

## Next

1. Base green -> clone-warm worker clones; harvest worker shas; merge into lane/hot-path; full build; doc bench on
   the built Host (needs a candidate-shaped bin dir: build the host exe from the base tree); profile again.
2. Persistent-state layer (owner): decoded cells and per-cell derived views held by the session across turns
   (Engine cells with decoded/law-view thunks + exactness), the authority snapshot built once per cell image,
   seals over changed cells only, cold start from a derived-state snapshot. Design note in this file before code.
3. Batch landing to the integrator (agent aca7a1fd39def735a) with before/after numbers.
