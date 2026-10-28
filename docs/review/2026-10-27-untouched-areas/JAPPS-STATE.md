# Stream continuity and the japps row: state

Present state, rewritten whole (2026-10-28). Lane `lane/un-stream-continuity`, finished; the two owed
japps.sh rows belong to the faerie on `lane/un-japps-rows`.

## Verdict

`japps.sh --box` on candidate b26630168 (fresh genesis, carries 6544ea37e, 391311929, bf5ead3fa, 507d6ce78,
125927331, 29d3152d3, 8ef4c65a9): **J-APPS PASS 29/29**, on hbox (operator uid 1000 `hbox`, world
`/tank/lanes/un-stream-continuity/runs/w1`, 12:45-14:13Z, rc=0). It includes the lifecycle row, the
co-edit row (a second browser session over DDP), the Hacker Slides publishing socket, **the Hacker Slides
write** (`PUT /slides.md 200`, anonymous `www.sock` read 200) and the Etherpad rows. Torn down
(`world-down`, removal_assertions=0); staging deleted.

## What this lane found and landed (all on main)

- Stream continuity: after the Host's own exact append the session image had no `headTag`, so a second
  session's hot route registration was refused ("requires an opening read from the Store"). The append path
  keeps the tag (`Appended.headTagExact`, `exactCandidate` takes it); `withOpenedFreshTip` decides through
  `ApplicationStreamContinuityFresh.verdict` (Head.verify authenticates the tag; named refusals).
- Repeat-suffix: in grain-journey.sh a trailing digit is a repeat after a restart; the second browser
  session is suffix `s`. The enroll anchor uses the enrolling label as given (391311929).
- Stale enrollment: a restart moves the app to a new serving generation (the lifecycle edge counter, law),
  and an enrollment names the generation it was made against. Nothing in the browser/gateway path
  re-enrolled (enrollment is participant-signed, grain_route.rs:1-12). `World::enroll` now enrols after
  install, share and every START; `mini apps renew --grain G` is the explicit form (grammar leaf, derived
  web form); the stale refusal names it. `apps` verbs read the shell's `--dir`; the CLI takes the
  grammar's positionals. `apps bootstrap` activates the tool and parent tasks (attach, attach, reserve 1).

## Facts for the next faerie (lane/un-japps-rows)

- `japps.sh` on main HAS an `enroll-a2` step, at line 238 (`start-a enroll-a2`) before the Hacker Slides
  write: that is the manual renew. The owed row is the same restart-then-write WITHOUT the manual
  `enroll-a2` (the product enrols on START), plus a separate `apps renew` / stale-refusal row. Do not call
  that step "missing"; it is the recipe's own renew.
- The parent's `reserve 1` (what `apps bootstrap` does after attaching the parent) fits its birth law as
  read, not yet run: the holder-form witness needs the parent at generation 1 and status 3
  (`Kernel/AgentGrain.lean` `witnessTouchState`, `holderPolicy`), bootstrap sets
  `holderWitnessGeneration` 1, and attach (generation 0 to 1, status 1) then reserve (status 3, generation
  unchanged) lands exactly there. The fresh-world bootstrap-then-first-install row is what confirms it.
- Rows still owed on main: (1) restart, then write, no manual enroll-a2; plus an `apps renew` /
  stale-refusal row; (2) fresh-world `apps bootstrap` then first `apps install` (reservation law-denied
  before the activation fix; red on the old code).

## Run recipe on hbox (worked 2026-10-28)

- `hbox` has `(ALL:ALL) NOPASSWD: ALL`; use the substitute operator `MINI_OPERATOR_UID=1000
  MINI_OPERATOR_NAME=hbox XDG_RUNTIME_DIR=/run/user/1000`. Stage under /tank/lanes/<lane>/{src,cand,runs};
  `chmod 755` every directory you create (a 775 ancestor is refused: "scratch custody refuses writable
  ancestor"); `chmod go-w deploy/spk-host/*`.
- Clean checkout, then VERIFY ancestry before running (two earlier runs were wasted on a checkout that
  silently did not move): `git merge-base --is-ancestor <sha> HEAD`.
- Candidate bin: `ssh dregg-build 'cd /build/candidates/<sha> && tar c bin' | ssh hbox 'tar x -C <cand>'`.
- World: `flock -o /tank/lanes/world-up.lock swarm-build bash scripts/spk-platform/world-up.sh CAND/bin CAND/bin RUN`
  (`-o` so residents do not inherit the lock fd). Row: `JAPPS_WORLD_ENV=RUN/WORLD.env swarm-build bash
  native/resource-client/journey.d/japps.sh --box CAND/bin`, PID file as its own statement, one
  `scripts/pipeline/box-wait --host hbox`. World start takes about an hour on a busy hbox; the row about 25 minutes.
- Tear down: `bash scripts/spk-platform/world-down.sh RUN`; stop survivors only by exact PID after checking
  the command line names your world.
- dregg-build is the integrator's alone; dregg-ref has no install-user-world rules.

## Evidence

- hbox `/tank/lanes/un-stream-continuity/runs/w1.japps.out` (deleted with the staging; the 29/29 text is
  above and with the rows validator). dregg-build `/build/lanes/un-stream-continuity-evidence/` (w1..w6).
- Branches: lane/un-enroll-renew (bf5ead3fa), lane/un-anchor-label (391311929), lane/un-journey-repeat-suffix
  (789b9b478), lane/un-stale-enrollment (43a6f023f). Lean elaboration of the Authoring refusal: dregg-ref
  at 50d814f8e (3549 jobs).
