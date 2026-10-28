# The performance workload

`scripts/perf/workload.sh` is the one fixed workload we optimize the Store against. It runs a
small, complete life of a Mini world on a fresh scratch Store, times every operation, and holds its
default size to a 180 s budget (`PERF_BUDGET_S`). Wall time is quoted only from a quiet SSD box
(`dregg-build` or the demo box), never from hbox (`/tank` is an HDD mirror; COORDINATION §5). Its parameters (N births, M updates, K reads) scale it
up without changing what it does, so the same script measures a later, larger bar.

## The operation it serves

**births/create: an Objective object born** (a native resource plus its `create` turn). That is the
named slow user operation; its p50/p99/max is the first line of every table (`HEADLINE`). Every other
phase is context: it puts the Store in a realistic state around the creates (packages published,
history past a checkpoint, a certify, the judgment layer run, a cold reopen) and shows whether a
change moved something else. This is a measurement to take when a Store change claims a speedup, not
a check on every commit.

## What it exercises

One fresh native world through `native/resource-client/activity_world.py`, the client path every
Objective journey drives (`newparticipant-acceptance.sh` genesis with the Objective invocation policy,
every turn a signed `mini activity` command through the serving Host). The phases, in order:

| phase | operations | what runs |
|---|---|---|
| genesis | `bring-up` ×1 | keygen, policy authoring, genesis params (`params.sh fill-genesis`) and `genesis.sh`, Store bootstrap, Host serving, one signed limits view |
| setup | `resource` ×4, `publication` ×2, `publish` ×2, `create` ×4 | the Calls and Sends packages captured and lowered by the Host's front end and published; the four fixed objects of the judgment phase (relayA, vault, poster, sink) |
| births | `resource` ×N, `create` ×N | N Objective objects: a native resource (`mini workspace --action create`) and its `create` turn (pin = Calls, seed `{total}` from the seed) |
| updates | `invoke` ×M | `deposit` on the born objects, round robin in seeded order; each invoke is a plan quote of its front end and a submit |
| reads | `read-current` ×K, `read-at` ×K | K public views (op 214) of seeded objects; K signed past-state reads (`mini query --view at`) at seeded heights spread over the history, below and above height 64 |
| checkpoint | `certify` ≥1 | `mini checkpoint --action certify`: the cadence certifies that keep the uncertified tail under L = 256 (one every 192 records), and the phase's own; the history has crossed the 64-record checkpoint boundary by then (checked) |
| judgment | `call-granted`, `send`, `deliver` | relayA.forward(vault) under a scoped grant (the vault's law admits only the sponsor as `request/subject`); poster.post(sink) queues an inbox message; the second subject delivers it. Each result is read back and checked |
| reopen | `stop`, `to-first-read`, `read-current` | SIGTERM the Host by its PID file, wait for it and its children; `mini serve` on the same Store; time until a view answers; one more read |

Every turn is judged as `activity_world` judges it (installed, not a charged failure); a phase
completes only when every turn and check in it passed.

## What it does not exercise

- Large cell counts: the default world holds ~N+4 objects and a few hundred records. Growth
  behaviour past that is the growth row's (`row_growth`, 1000 records) — run this script with a
  bigger N/M to probe it here.
- Refusal paths, plants of the judgment layer, laws other than permit-all and subject-equals,
  domains, upgrades, awaits/deliveries of activities, concurrency (one client, sequential turns),
  the private/encrypted paths, any network transport other than the local Unix socket.
- Proof generation (there is none in Mini admission).
- Determinism of bytes: keys and op ids are fresh per run, so roots differ run to run. Inputs that
  shape the work (object order, amounts, read heights) are fixed by `PERF_SEED`.

## How to run

    scripts/perf/workload.sh CANDIDATE/bin /short/new/root [N M K]

Defaults N=20 M=16 K=8; `PERF_SEED` (default 20261013), `PERF_BUDGET_S` (default 180),
`PERF_UNDER_LOAD=1` (run on a busy box anyway; recorded as `underLoad`), `PERF_INSTRUCTIONS=0`
(skip `perf stat`). The root
must not exist and must be short (the Store socket `ROOT/w/public/mini.sock` has to fit 107 bytes).
It measures wall time, so it first samples the box for 3 s (`scripts/perf/box.py quiet`): any
systemd unit (a swarm-build scope, another session) using half a core or more makes it refuse with
exit 3, `workload REFUSED: box not quiet: <unit> <cores> (<command>)`. Exit 0 when every
phase completed and the run took under the budget; otherwise 1, with the reason as the last stderr
line (`workload FAIL: phases not completed: ...` or `workload FAIL: wall Xs not under the Bs bound`).

The standing journey row `row_perf` (scripts/pipeline/journey-rows) runs it at its smallest
parameters (N=20 M=16 K=8: the smallest that still crosses height 64 before the checkpoint phase;
the Store holds 10 + 2N + M records by then, each birth being two)
and records the table; on a busy box it is UNCONFIGURED (98) with the busy job named, never a
verdict taken under someone else's load. Plant: `JOURNEY_PLANT_PERF=budget-1s` judges the same run against a 1 s bound;
the row must go red with `workload FAIL: wall ...s not under the 1s bound`. All failure reasons are
listed in that one line (phases not completed, then the bound).

Smaller parameters would fit the 180 s budget sooner but never reach the checkpoint boundary, so
the default keeps every phase. The budget is a target for the Store hot path, not a measured
figure; measured figures are published in the row's table.

## How to read the table

`ROOT/table.txt` (and `ROOT/results.tsv`, tab-separated, same columns):

    phase      op              count   p50_ms   p99_ms   max_ms  total_s

One line per (phase, operation): how many, nearest-rank p50 / p99, the worst, and the summed seconds
of those operations. Each phase ends with a `TOTAL` line: the phase's wall time (which includes the
client work between operations, e.g. reading results back and the checks). The last line gives
N/M/K/seed, the Host's record count at the end, the object count, the Store's size on disk
(`du -sb ROOT/w/store`) and the whole run's wall time. `ROOT/summary.json` is the same in JSON;
`ROOT/transcript/` holds every command's exact output.

When `perf stat` works on the box, the whole process tree (the Host and every client command) runs
under `perf stat -I 250 -e instructions:u`, and each phase's `TOTAL` line in `results.tsv` carries an
`instructions_u` column (intervals attributed to the phase they end in; the last table line lists them).
Instruction counts are the figure to compare between candidates on a shared box; wall time only from
quiet runs.

`ROOT/settings.json` records the inputs and settings: N/M/K/seed, the sha256 of the workload scripts,
`activity_world.py`, the genesis scripts and both packages, host, CPU model, the Store's filesystem,
the budget, the binaries' sha256s and the candidate's source commit. Its `inputKey` (also in
`summary.json`) hashes everything two runs must share to be compared (not the binaries, not the time);
a comparison must refuse two results whose `inputKey` differs.

What to compare across runs: per-operation p50 for the hot path (`births/create`, `updates/invoke`,
`reads/read-current`), `reads/read-at` (a cold open of the Store per query), `checkpoint/certify`,
and `reopen/to-first-read`. A rise of `create`/`invoke` p99 against p50 within one run is the
signature of per-record cost that grows with the Store. Two runs on the same candidate differ by a
few percent on a quiet box; quote both.
