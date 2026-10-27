# HOT-PATH lane state (lane/hot-path-codec, 2026-10-27 evening)

Branch `lane/hot-path-codec` (origin/main merged at 27502f54); Mac worktree
`/Users/ember/dev/minidregg-lanes/hot-path-codec`; box worktree `/build/lanes/hot-path-codec` (dregg-build, user
`lanes`). Design: `docs/HOT-PATH-2026-10-27.md` §2 (a), (f), (h).

## Landed (pushed)

| sha | what | verified |
|---|---|---|
| 3717320a | (a) the resident codec Host on mini-sdk (`ResidentKind::{Consent,Codec}`, `mini codec-resident`, `MINI_CODEC_RESIDENT=0`) | Mac + dregg-build filtered: mini-sdk 5/5, resource-client 10/10 incl. `tests/codec_resident.rs` |
| 40152929 | J12X asserts NO_RECORD 253 for malformed codec frames (L1 grammar verdict) | dregg-build J12X 20/20 on 6236826f |
| bef3b452 | thin-consent birth refused by name; THIN's per-row proxy is its own child | dregg-build THIN PASS; JP2 20/60 at row 19 (thin birth arm = Phase 3 design, not this lane) |
| 6e6e3a09 | `MINI_OPEN_TIMING=1` laps for the full open | elaborates; superseded as the attribution tool by the sampler below |
| d50306c1 | design §2(h) + first state file | doc |
| a20dad89 | the World's maps compacted every 32 heights (`Compiler/WorldCompact.lean`; `foldRecords`, `WorldTrack.advance`) | probe map 4000 writes: all reads 4405 ms chained vs 13 ms compacted |
| 6eb74814 | compaction reaches every cell's own store (`compactWith`, `compactCell`); the second sample put the chains inside cells | Mac `lake build minidregg-host` + `minidregg-client-consent` green (7472 jobs); Mac births workload: 49 births admitted across heights 32/64/96 (World held through compactions), b0050 refused by the Mac's file-table ceiling (ENFILE in the verifier spawn), not the change |
| 8f66d6cc | `lane/hot-path-compact-6236`: 6236826f + the two compaction commits (clean), so the box's standing worlds (6236826f epoch) can be opened | staged dregg-ref build `/build/lanes/hot-path-compact-build.sh` (candidate builder, 24 G, own PID `/build/lanes/hot-path-compact.pid`): waits for the coordinator's window |

## The cold reopen: cause, measured

One full open (`HOST CONFIG describe` = `NativeHost.openExisting`) of the 6236826f Host on a 483-record snapshot of the
births-only world: **175 s** (load 25). Sampled (`/build/lanes/hot-path-codec-sample.py`, ptrace, 345 samples):
**99% `trackOf` → `foldRecords`** (the genesis World fold), 86% inside `DFinsupp.update`/`Function.update` of
`Theory.Store.Store.set`. A `Store` is a `DFinsupp`; each `set` adds a closure layer and a support entry, so reads
are linear in the writes so far and the fold is quadratic (0.37 s/record at 483). Read, chain, tags, indexes and
validation are noise at this size. Fix a20dad89 changes representation only (`compactBy_eq`, `compact_eq`,
`compactEvery_eq`): no statement moves. The served session's `advance` reads the same World on every append, so the
propose slope should flatten too (to be measured).

§2(h) (checkpoint carries indexes + World; suffix-only open; genesis fold → `store audit`) remains the next step
for the O(n) that is left; its order is decided by the AFTER sample (what dominates once the fold is linear).

## After the compaction (Mac, 110-record Store born under this tree)

One full open 9.5 s; `MINI_OPEN_TIMING` laps (cumulative): read 53 ms, decode 158, chain 261, checkpoint 276, tags
490, frontier 514, resume 622, roots 913, indexes 916, **world fold 9032**, validate 9197. The fold is still 8.1 s
(74 ms/record). No same-machine BEFORE (macOS `sample` cannot attach without `get-task-allow`; this tree's epoch
cannot open the box snapshots). Expected remainder: per-turn whole-cell work (`TurnOfIntent` diffs whole touched
cells; the root hash re-encodes them), O(cell size) per turn for a cell that grows with births. The paired box
sample (8f66d6cc Host vs 6236826f on the 483 snapshot) decides; fixes then are rulings: diff only the intent's
written keys (a `TurnOfIntent` statement change) and/or §2(h)'s World checkpoint (a checkpoint epoch change).

## Box procedure that works (dregg-build, 30 G, co-tenants 10-15 G)

- `lake` has no job limit and `LEAN_NUM_THREADS` does not bound concurrent modules: heavy pairs met every cap.
  `Kernel.PayObservationReceiver` alone peaks 15.5 G, `Compiler.LegacyContentCarry` 8.7 G, `Host.Main` > 16 G.
  `/build/lanes/hot-path-codec-host-build-steps.sh SHA` builds `Kernel.NativeHost`, `Host.Main`, `minidregg-host` in
  turn, each after waiting for >= 18 G free, capped at free-2 (<= 24) G. It writes its own PID to
  `/build/lanes/hot-path-codec-host-build.pid`; log `/build/lanes/hot-path-codec-host-build.log`.
- Every box script writes `echo $$ > <pidfile>` itself (a `$!` of a `setsid` wrapper names the wrapper).
- Attribution without a rebuild: `/build/lanes/hot-path-codec-profile-open.sh LABEL SNAPDIR` runs one describe of a
  snapshot under the sampler (PID file `/build/lanes/hot-path-codec-profile.pid`); output in `/build/lanes/hpc-laps/LABEL/`.
  Snapshots: `/build/lanes/hot-path-codec-laps.sh LABEL HOST` (anchor copied first, then sqlite `.backup`).
  The 483-record snapshot is `/build/lanes/hpc-laps/cand-n1/snap`.
- BEFORE run (births to ~1.7k, then the workload's reopen): `/build/lanes/hot-path-codec-perf-before.sh`, PID file
  `/build/lanes/hot-path-codec-perf-before.pid`, output `/build/lanes/hot-path-codec-perf/`; ~250/840 births at 16:10Z
  (the World fold also makes every birth slower as the Store grows).

## Next

0. When the coordinator ends nanodregg's dregg-ref window: `uptime` (< 8), start
   `/build/lanes/hot-path-compact-build.sh` (one background wait on its PID file); copy `out/bin` to dregg-build;
   time + sample one describe of `/build/lanes/hpc-laps/cand-n1/snap` with it and with the candidate (paired).

1. Host at a20dad89 built → profile-open the same 483-record snapshot with it (AFTER), and the candidate again
   (paired control); push the numbers into §2(h).
2. When the BEFORE run is DONE: its reopen row (BEFORE at ~1.7k), then the a20dad89 Host on a snapshot of that Store
   (AFTER at ~1.7k); propose slope before/after from the births' `create` samples.
3. Coordinator's queue, measured on dregg-build's `wf-jrun3` world before/after: `mini shell` start (51 s) and
   `can jwf162708` (6 min first verdict, then ~10 s per verb; op 130 runs on `sessionCurrent`, the cost is inside
   `DryRun.dryRunLoaded`): sample each, fix at the cause, push per item.

Standing: never kill by pattern; stop only by PID files; filtered tests; never the demo box; named-file commits.
