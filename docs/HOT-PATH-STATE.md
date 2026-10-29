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
  history (5), index (6+7), verifier (in-process Ed25519 via mini-kernels), contentlaw (quadratic ContentLaw), effects
  (Effects/Revival reds from the Materialized change). hbox clones: `/othersys/lanes/hot-path/mkclone.sh ITEM`. Relaunch a
  stopped worker: `hp-tools/hp-resume ITEM [note]` (Kimi runs out of context on big files; COMMON.md has a narrow-reading rule).
- Bench: `/othersys/lanes/hot-path/bench-perf.py` (doc-submit-bench + `--perf-at N,M` perf record with DWARF stacks);
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
- Lane Host binary: `/othersys/lanes/hot-path/artifacts/minidregg-host` (`hostbuild.sh`), bench set
  `/othersys/lanes/hot-path/cand-hp1` (2b8f75dcb with that Host). Packages are now a real copy on the SSD (the native
  builder refuses a symlinked `.lake/packages`).

## Landed on lane/hot-path (not yet on main)

| sha | what |
|---|---|
| fd54bb732 | merge of lane/perf-batch1 (codec writer, cell roots/bytes cached per cell value, decodeFast) |
| 703d0c0af | perf-batch1's red fixed (Theory/CellSlot `decode_eq_decodeFast`) |
| 8db6db77e | DeployedBridge `packOf_unpack` via `Materialized.ext` |
| 023a13096 | merge of main (Host.Main String.take fix; census deleted). Host.Main + ClientConsentSession green on hbox |

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
