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

## Pushed, not yet sent to the integrator

`lane/perf-rake` (on main 6bc302387): 9d64ce7d6 (store comparisons one pass, directory row
table, identity-first list and Image equality, `Compiler/CompiledListOps.lean`), 84d8710b2
(refusalAtTip? first-index table, validateCore once, ObjectiveActivity readOnly and charge),
d9ab3b028 (FastKeyOrder default instance; fixes the WorldCompact red lane-check found),
cd96cdb97 (scripts/perf/doc-submit-bench.py). Check in flight: dregg-ref
`/srv/lanes/perf-rake`, unit `perf-rake-lc3` (as lanes, `XDG_RUNTIME_DIR=/run/user/1000`),
log `/srv/lanes/perf-rake-lc3.log` (EXIT= line at the end), running `scripts/pipeline/lane-check`
on the 12 changed files. Green: send the tip sha to the integrator with the file list. Red:
fix forward in /Users/ember/dev/minidregg-lanes/perf-rake-fix and rerun the same lane-check
(sync files with `tar cf - FILES | ssh dregg-ref 'runuser -u lanes -- tar xf - -C /srv/lanes/perf-rake'`).

## Sub-lanes (winding down 2026-10-28 on usage)

- lane/perf-codec-writer 00580de11 (+ maybe a continuation note): StreamCodec `encodeInto`
  writer and StoreCodec written-buffer hashing. 16 modules green; closure (DurableReceiverCore,
  NativeHostReplay, Host.Main) was running under closure-lock on dregg-ref. Next: cursor-native
  decode for leaf tag codecs (backlog item 8).
- lane/perf-roots 523bba473 or later: cell roots once per image (Engine root table, Materialized
  bytes/root cache, CredentialAuthorityDomain snapshot root). Closure on dregg-ref /srv/lanes/perf-roots.
- lane/perf-rust follow-on (helper spawns onto the operator socket, backlog item 3): design in
  the sub-lane's report; maybe PERF-RUST-STATE.md on lane/perf-rust-ops.

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
