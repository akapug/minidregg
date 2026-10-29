# Perf rake: state for a restart (2026-10-28)

Present state; rewrite whole. The backlog itself is `docs/PERF-BACKLOG-2026-10-28.md`.

## Done (on main)

- d7cbd3712: decimal Nat literal parse per `encodeNat` / per decoded 7-byte chunk.
- 65a355243: StoreCodec `rootBytes` roots the decoded entry list; blinding key once per cell.
- 41d87f720: spk-host dispatch loop wakes on a handed-over request (no 20 ms tick).
- 327ba9ac1 (lane/perf-rust 3de71b986): Rust request path (pinned inputs verified once per
  file identity, one systemctl per check, no getfacl fork, poll-based waits, hex compares).
  Linux filtered tests green on dregg-ref.
- Not mine but landed: 94b8de93c charge cut, f90726140 ExactReadback via `Loaded.prepare`
  (lane/un-route-latency, owner ac1e69b).

## Merged after this file was first written

lane/perf-rake 53cb1e212 is on main as 02358d518 (ordering one pass, directory row table,
identity-first list and Image equality, refusalAtTip? first-index, validateCore once,
ObjectiveActivity readOnly/charge, the bench, the backlog); lane-check of all 12 files was
green on dregg-ref. Its full closure is the main build after 327096423.

## In flight: one batched landing (root's rule: deep Lean changes land together)

`lane/perf-batch1` (c97273985 code, ad9486660 docs) = main + lane/perf-codec-writer a9d0bb995
+ lane/perf-roots 5cebf6301. Closure on dregg-ref: unit `perf-batch1-closure` (lanes,
`XDG_RUNTIME_DIR=/run/user/1000`), script `/srv/lanes/perf-batch1-closure.sh`, log
`/srv/lanes/perf-batch1-closure.log` (EXIT= line), tree `/srv/lanes/perf-rake` checked out at
c97273985, `LEAN_NUM_THREADS=4`, `SWARM_MEM_MAX=24G` (lake has no -j). RESULT (18:51Z): red at
`Theory/CellSlot.lean:287` and `:289` (two `rw` patterns not found; the roots lane's
Materialized/PackedCell change), 3061 of 3101 modules built before it. Fix those, rerun the script. Green: send the
integrator the batch sha as ONE landing. Red: fix forward on lane/perf-batch1 (the sub-lane
notes in docs/PERF-CODEC-WRITER-STATE.md and docs/PERF-ROOTS-STATE.md name the likely reds:
`Materialized.ext rfl` where a proof relied on `materialize M c.logical` being `c`; the
`one_octet_tag` tactic on inline structures and `rfl` in `StreamCodec.fin`), rerun the script.

Rust: lane/perf-rust 3de71b986 is on main (327ba9ac1). Its follow-on 40392d4dc + c169a712
(author/inspect/signatures as operator ops 195-197, Lean arms in Host/Main.lean) is NOT merged:
`lane-check Host/Main.lean` queued on dregg-ref, unit `perf-rust-lean-lc`, log
`/srv/lanes/perf-rust-lean-lc.log`, tree `/srv/lanes/perf-rust-lean`. Green: send
c169a712 to the integrator (it touches Host/Main and the generated op tables, not deep modules).

## Measurement

- Benchmark: `scripts/perf/doc-submit-bench.py`. Baseline logs on dregg-build:
  `/build/lanes/perf-rake-bench/bench-349.log` (N=10) and `bench-349-n40.log` (N=40): submit CPU
  420 ms to 2,890 ms, about 60 ms per prior record. Rerun with the first candidate carrying the
  fixes (the integrator sends the sha; 327096423 is the first with 41d87f720):
  `python3 scripts/perf/doc-submit-bench.py --bin /build/candidates/SHA/bin --root NEW --src SRC --n 40`
  (SRC: the candidate's source.tar extracted, native/resource-client and scripts).
- gdb samples of submits 36-40 on hbox: `/tank/lanes/perf-rake-bench/w1/samples/*.txt` (run
  log `gdb-run.log`; script `doc-submit-bench-sample.py`, binaries `c349/`). Aggregate the
  frames to name the O(history) per-submit loop: that is the next fix, and probably the biggest.
- The route probe for the app route: `scripts/spk-platform/route-cpu-probe.sh` (lane/un-route-latency).

## The rake

GLM readers (Z.AI, not Claude) driven by
`/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/perf-rake/driver.sh`
(PID file `driver-main2.pid`; per-shard `run-one.sh` retries on 429). Findings in `findings/`;
`gen-backlog.py` regenerates the unverified tables; `collect.py` the JSON. When it ends, rerun
`./driver.sh 4 $(seq -f %03g 0 173)` once to fill shards that failed (it skips finished ones),
then regenerate the backlog's generated half.

## Boxes

dregg-build is the integrator's (no lane Lean builds; swarm.slice 24G shared). dregg-ref /build
is at 96% (disk pressure: never write there); lane trees live on /srv (root fs). hbox has gdb
and perf; its HDD makes copies and fsync-heavy runs slow.
