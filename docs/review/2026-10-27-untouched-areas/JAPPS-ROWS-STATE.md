# japps rows: state (lane/un-japps-rows, ship freeze)

Present state, rewritten whole.

## Landed on the lane (pushed)

- da5a51424: apps bootstrap authors its birth at the current height (birthStale on aged worlds).
- bd9318540: the broker coordinate bound is a positive canonical u64; the worker's share ids no longer
  derive from `app * 100` and the enrollment keeps the birth's real packageManifest.
- dc8d3a733 (with 24aa12cc1): Kernel `controlGroupBound` = 323 for a u64 app and generation, elaborated
  (lake build rc 0 on dregg-ref, own worktree). Statement at
  Kernel/ApplicationLifecycleCompletionReport.lean:128.
- e6d1f77f3: session births read the factory, grants, template and tariff from the genesis.
- 266b12b65 (52d15a6ce): at install the member delegates the manager a child of its app owner capability;
  the worker issues share tickets under it (`shareDelegation`).
- b65465c72 (f2185daf3): a refused worker birth or ticket settles its tool reservation for 0.
- 5c3e7360e: composed fixture `share-delegation` step (main took it as 1956d1a63).
- Rows in scripts/spk-platform/apps-e2e.sh, run from japps.sh --box: bootstrap-then-first-install,
  install spend within funding (member funded 20000; measured spend about 10,359), restart then write
  with no enroll step, apps renew current, stale-generation refusal by name, renew then write.
  Red-proofs recorded: bootstrap activation skipped (law-denied); unit tests for each Rust fix red on a
  planted fault and restored.

## Rows still owed (never run green end to end)

- Two-subject e2e (member 9, manager 8) through install, share, route: blocked until a candidate carries
  dc8d3a733 and b65465c72. Unverified there: the delegate verbs `append`/`place` on the app reference,
  maxCost from the template ownerBudget, observe queries still using the member-held owner capability.
- Restart then write with no manual enroll, apps renew current, the stale-generation refusal: written,
  behind the install. The skip-enroll-after-START plant (MINI_PLANT_SKIP_ENROLL) is not red-proofed.
- The w7 Etherpad red ("Etherpad on the same world", a grain-journey row) is unread.
- Composed apps:sheet against the new fixture step: the integrator's run.

## Recipe

hbox, MINI_OPERATOR_UID=1000 MINI_OPERATOR_NAME=hbox, `flock -o /tank/lanes/world-up.lock` around
world-up.sh, `JAPPS_WORLD_ENV=RUN/WORLD.env bash native/resource-client/journey.d/japps.sh --box BIN`
under swarm-build with a PID file; candidate bin copied to a lane directory, never written in place;
tear down with world-down.sh and stop survivors by exact PID after reading each command line.
