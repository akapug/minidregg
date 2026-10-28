# Stream continuity and the japps row: state

Present state, rewritten whole. Lane `lane/un-stream-continuity` (Sonnet faerie for the untouched-areas deputy).

## Landed

- Stream continuity (hot route registration on a running grain): the append path keeps the head tag,
  `withOpenedFreshTip` decides through `ApplicationStreamContinuityFresh.verdict`. On main
  (6544ea37e and the Fresh statement). japps co-edit row green on candidate 76758dba6 (w3 and again
  on stale-script runs w5/w6).
- Repeat-suffix (`789b9b478`) and anchor label (`391311929`) in grain-journey.sh: a trailing digit is a
  repeat after a restart, the second browser session is suffix `s`; the enroll anchor uses the label as given.
  On main.
- `lane/un-enroll-renew` (tip bf5ead3fa; elaborated Authoring on dregg-ref at 50d814f8e, 13 filtered Rust
  tests green on dregg-build): `World::enroll` after install/share/START, `mini apps renew --grain G`
  (grammar leaf, derived web form), stale-enrollment refusal names it, `--dir` fix for every apps verb,
  CLI positionals, bootstrap activates the tool and parent tasks. Main 7280f9db8 carries 391311929 and bf5ead3fa.

## Rows still owed

1. Hacker Slides write after restart -> renew: `japps --box` with the japps.sh step `start-a enroll-a2`
   then the write (the write is `PUT /slides.md`; red before: 403 "enrollment ... meaning differs",
   cause = enrollment names the old serving generation, grain_route.rs:1-12). w5/w6 did not test it:
   the box worktree was on a stale overlay (55510fca2).
2. A fresh-world `apps bootstrap` -> `apps install`: the bootstrap now attaches the tool, attaches the
   parent, reserves 1 on the parent (mirroring grain-journey.sh workroom_ready). The parent's
   `reserve 1` was copied from the fixture and is NOT checked against the parent birth law: if an install
   expects another parent state, demo-dry names it.
3. japps `--dry` on the Mac still uses inspect; `--box` uses `spk-host qualify` (8ef4c65a9).

## Run recipe (hbox; dregg-build is the integrator's alone)

- Clean checkout under `/tank/lanes/un-stream-continuity/src`, then VERIFY ancestry before running:
  `git merge-base --is-ancestor 391311929 HEAD && git merge-base --is-ancestor bf5ead3fa HEAD`
  (the w5/w6 runs were wasted on a checkout that silently did not move). `chmod go-w deploy/spk-host/*`.
- World: `flock -o /tank/lanes/world-up.lock MINI_OPERATOR_UID=<uid> MINI_OPERATOR_NAME=<name> bash scripts/spk-platform/world-up.sh CAND/bin CAND/bin /tank/lanes/un-stream-continuity/runs/wN`
  (the `-o` matters: without it residents inherit the lock fd).
- Row: `JAPPS_WORLD_ENV=.../wN/WORLD.env bash native/resource-client/journey.d/japps.sh --box CAND/bin`
  under `swarm-build`, PID file written as its own statement, one `scripts/pipeline/box-wait`.
- If japps --box needs the lanes sudoers rules (`install-user-world`) that exist only on dregg-build, say so:
  do not work around it.
- Tear down with `world-down.sh` and delete the run dirs afterwards.

## Evidence

- dregg-build `/build/lanes/un-stream-continuity-evidence/w*.japps*.{out,err}` (w1..w6 verdicts).
- hbox `/tank/dregg-build/rows-76758dba/rerun-m6grain/.../evidence-a/` (the enroll-a2 suffix collision).
- dregg-ref `/build/lanes/un-enroll-renew/lean.log` (Authoring elaboration), dregg-build `/build/lanes/un-enroll-renew-job/` (test logs).
