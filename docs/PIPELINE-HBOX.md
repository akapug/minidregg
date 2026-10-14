# The landing pipeline on hbox

Goal: a lane can **land by the rule** on hbox without a rented burst box (PROTOCOL-20261009 §6–7). "Landed" means
the commit is on GitHub main AND a full static gate is red=0 at that sha AND the standing journey run at that sha has
every required row PASS. A required row may also be UNCONFIGURED, but only when the missing input is one the box
declares absent. Tools never run from an installed copy. RETRO-20261008 §d counted four stale-installed-copy
incidents in one day. On hbox that class has no file to go stale: nothing in the pipeline executes from a
copied script.

## Layout (everything under /tank/dregg-build; no /srv)

| path | what |
|---|---|
| `/tank/dregg-build/pipeline/box.env` | the ONE env file. Written by `scripts/pipeline/box-env --layout /tank/dregg-build/pipeline ...`. Every pipeline script reads it through `lib.sh` once `PIPELINE_ROOT=/tank/dregg-build/pipeline` is exported |
| `.../pipeline/warm-base/{src,FROZEN,logs}` | the built, read-only base (umbrella replays 0 modules). Lanes are made by `warm-base/src/scripts/pipeline/mk-lane.sh`, the base tree's own copy |
| `.../pipeline/lanes/<lane>/{src,logs}` | mk-lane clones (`cp -al` .lake, allow-listed shared inodes) |
| `.../pipeline/artifacts/<tip>/` | READY sets (publish-artifacts), labels `next`/`green`/`main` |
| `.../pipeline/journeys/<tip>/` | standing-run results (`results.tsv`, `table.txt`, `rows/`, `DONE` or `REFUSED`). `journeys/.trees/<tip>/` holds the set's source tree, read-only, which the run executes |
| `.../pipeline/slots/build-slot-{1,2,mk}` | lane slots and the gate slot (flock files). swarm-build's cgroup caps memory |
| `.../pipeline/absent-inputs.tsv` | the box's DECLARED absent product inputs (below) |
| `.../pipeline/pylib/` | PyNaCl 1.6.2 wheel, unpacked after a sha256 check. hbox's python3 has no nacl and no pip; `PYTHONPATH` in box.env lets JPAY1–4 run |
| `~/.config/systemd/user/pipeline-journeys.{service,timer}` | the standing run (below) |

The shared git remote is the bundles mirror `/tank/dregg-build/claude-lanes/bundles/burst3-minidregg.git`
(`PIPELINE_SHARED_GIT`).

### box.env (as written 2026-10-14)

```
scripts/pipeline/box-env --layout /tank/dregg-build/pipeline \
  --slots "/tank/dregg-build/pipeline/slots/build-slot-1 /tank/dregg-build/pipeline/slots/build-slot-2" \
  --gate-slots /tank/dregg-build/pipeline/slots/build-slot-mk --lean-threads 8 \
  --shared-git /tank/dregg-build/claude-lanes/bundles/burst3-minidregg.git --no-lake-shim \
  --set "PIPELINE_LEANENV_WAIT_S=0 PIPELINE_JOURNEY_JOBS=8 PYTHONPATH=/tank/dregg-build/pipeline/pylib"
```

- `--no-lake-shim`: hbox has no `$PIPELINE_ROOT/scripts/lake-shim`. A PATH entry pointing there would be an
  installed-copy path waiting for someone to plant a file in it.
- `PIPELINE_LEANENV_WAIT_S=0`: hbox has no lean envs, so `objective` is UNCONFIGURED. It was UNCONFIGURED on
  burst3 too, and it is not a required row.

### What was generalized, not forked

The /srv paths were defaults. Each edit makes a default come from box.env:

- `box-env --layout DIR` sets `PIPELINE_ROOT` and the roots `ARTIFACT_ROOT`, `JOURNEY_ROOT`, `PIPELINE_LANES`,
  `PIPELINE_WARM_BASE`, `PIPELINE_NEXT_BASE` and `PIPELINE_GATE_SLOT`, all under DIR. It also gains
  `--shared-git`, `--set` and `--no-lake-shim`.
- `lib.sh` `pipeline_find_tree`: the next base comes from `PIPELINE_NEXT_BASE`.
- `mk-lane.sh`: the `shared` remote comes from `PIPELINE_SHARED_GIT`.
- `advance-base-burst.sh`: the probe lane goes under `$LANES`. `$W/mk-lane.sh` is now a **relative symlink**
  into the base tree, not a copy.
- `journey-rows` hostupgrade: the EF set is looked up under `$ARTIFACT_ROOT`; `HOSTUPGRADE_EF_SET` overrides it.

## The standing run: the set's own tree, never a copy

`scripts/pipeline/install-journey-units` writes the units; re-run it after changing the generator. The service is a
oneshot, kicked every 5 min by the timer and immediately by `landing.sh`. Its **only** logic is an inline
dispatch:

1. Take the first label among `next`, `green`, `main` whose READY set has no `DONE` or `REFUSED` run.
2. Check the set's `SHA256SUMS`; `source.tar` is listed there.
3. Extract `source.tar` once into `journeys/.trees/<tip>` and make it read-only.
4. Log `dispatch: tip T (label) runs <tree>/scripts/pipeline/journey-runner sha256:<…>`.
5. `exec` that runner with `--tip T`.

The runner, rows, `lib.sh` and `journey-red-lines` are therefore always the tip's own. Logs:
`journalctl --user -u pipeline-journeys`.

The runner also guards itself. `journey-runner --version` prints its path and sha. In `run_tip`, its
`journey-runner`, `lib.sh` and `journey-red-lines` must be byte-identical to the copies in the tree the rows come
from: the lean env or source.tar, or the `--source-tree` override if given. If they differ, it prints both
sha256s, writes `TIP/REFUSED` and exits 3. The loop does not retry a refused tip.

## landing.sh TIP

`scripts/pipeline/landing.sh` runs on hbox with `PIPELINE_ROOT=/tank/dregg-build/pipeline`:

```
cd /tank/dregg-build/pipeline && PIPELINE_ROOT=$PWD setsid nohup bash <tree>/scripts/pipeline/landing.sh TIP \
  > logs/landing-TIP.log 2>&1 < /dev/null & echo $! > logs/landing-TIP.pid
```

1. Create a lane with the **base tree's** mk-lane. Fetch TIP from the shared repo and check it out (`main`).
   If TIP carries a different `landing.sh`, hand off to it (`exec … --in-lane`). If TIP predates landing.sh,
   the log says so and names the copy that continued.
2. Run TIP's own `run-gate-burst.sh`: the umbrella in the gate slot under swarm-build, then
   `merge-gate-checks.sh`. It waits while the 1-min load is above 20. It needs `umbrella PASS` and
   `TOTAL red=0 HEAD=TIP`; otherwise exit 10.
3. Run TIP's own `publish-artifacts TIP next LANE/src`. This is the gated tree, so nothing compiles. It smokes
   the set, writes READY and sets the `next` label. Failure exits 11.
4. Kick `pipeline-journeys.service` and wait for `journeys/TIP/DONE`. A refusal or a timeout exits 12.
5. Print the verdict. It opens with two greppable lines from the service's dispatch record
   (`journeys/.trees/TIP.dispatch`). `RUN-TREE` gives the tree, the runner path and sha256, and the
   source.tar sha256. `SELF-CHECK PASS|FAIL` says whether the executed runner is byte-identical to
   `git show TIP:scripts/pipeline/journey-runner` from the shared repo; FAIL exits 12. If the plant marker
   exists, a `STALE-COPY EXECUTED` line follows. Then the verdict body: `awk -F'\t' '$2!="PASS"' results.tsv` and the row count. Then check every id in
   `required-rows`, read from the **main base's** tree so a lane cannot drop its own required rows. Each must be
   PASS, or UNCONFIGURED with a detail that matches that row's declaration in `absent-inputs.tsv`. A required id
   with no line in results.tsv is MISSING. Exit 0 only if every required id passes this check; otherwise exit 13.
   The verdict is also written to `LANE/logs/landing-TIP.txt`.

`landing.sh --check TIP` runs only step 5, against a finished run. landing.sh never pushes; the root pushes main
from the results.tsv it has read.

### required-rows

The ids come from MATURATION-MAP-20261009 §3. A row id covers its sub-rows. A parent that is UNCONFIGURED only
because of declared sub-rows is accepted. Three rows on the map do not exist yet: BIRTHS (the bar; `growth`
measures updates), HERMES-LIVE and jcertify. They are `pending` lines: printed on every landing, not counted. The first time a row of that name appears in
results.tsv, it is required automatically (ROOT, 2026-10-14).

### absent-inputs.tsv (hbox, measured 2026-10-14)

| row | detail regex | why absent |
|---|---|---|
| m6grain | `^missing input: operator uid 1001 ` | the pipeline runs as uid 1000 (`hbox`). There is no uid-1001 operator account or subuid range |
| m7 | `^missing input: M7_REFERENCE ` | no M7 reference exists on any box yet |
| jpay/JPAY6 | `^missing input: TEST_PROVIDER=` | the set ships no mini-hermes-test-provider |
| exchange | `^missing input: MINI_FN_LAUNCHER ` | no fn launcher/core outside /tank/fn |
| hostupgrade | `^missing hostupgrade candidate input: .*/e0a8ba21…$` | the pinned old-epoch EF set existed only on burst3 |
| hostupgrade/HOST-UPGRADE-PREVIOUS | `^no previous READY main set with the tip Store epoch$` | no same-epoch main set has been published on hbox yet |

`sudo -n true` succeeds, `Linger=yes` is set for `hbox`, and sshd, bwrap and jq are present.

Verdict check tested on main 7dea0626's burst3 results.tsv: 40 ids, 0 not met. Planted variant (m3 FAIL, m8
UNCONFIGURED undeclared, sshe2e removed): 3 not met, exit 1.

## Warm base

`clone-warm /tank/dregg-build/claude-lanes/warm-7dea0626/src`, then checkout 7dea0626. That tree had built only the
Host closure, so the first `mk-lane --verify` probe compiled 533 umbrella modules. The probe tree was then swapped
in as `warm-base/src`, and a second probe confirmed a warm replay with 0 modules compiled. To advance the base:
`advance-base-burst.sh TIP [GATED_LANE_DIR]`, with PIPELINE_ROOT set.
