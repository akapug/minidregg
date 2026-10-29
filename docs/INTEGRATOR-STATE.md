# Integrator state

Present-state record of the integration lane, rewritten whole when its shape changes. A successor reads this,
then `hbox:/othersys/lanes/integ/COMMANDS.log` (every build stage and gate verdict, one line each).
dregg-build and dregg-ref were deleted 2026-10-28; their history is in this file's git history.

## Shape

One integrator (Opus). Kimi (`claude-kimi -p`, read-only, from the repo) reviews a batch of landings every few,
plus anything big or risky (oracle7: one review). Lanes push branches and send shas; the integrator merges into
`integration/staging` on the Mac, builds staging's tip on hbox, fast-forwards main to it once its host stage is
green, gates the candidate, reports. No codec pins/census/regen (no-pins landed). Statements may be rephrased,
never weakened. Main moves only by fast-forward from staging.

## Where things are

- Mac landing worktree `/Users/ember/dev/minidregg-lanes/integration-r2`, branch `integ/main`, pushed to
  `origin/integration/staging`. Mac checks: `CARGO_TARGET_DIR=/Users/ember/dev/minidregg-lanes/target-integ`,
  filtered `cargo test --bin mini -- apps::` etc. (apps_front connector test fails only inside the group; passes alone).
- hbox warm tree `/othersys/lanes/integ/src` (rpool SSD). Build `integ-build.sh SHA` (pid file integ/build.pid):
  rust-check, host, consent, umbrellas (non-fatal, beside rust), rust, pack -> `integ/candidates/<sha>/READY`.
  Env SEATS/JOBS/MEM; **use SEATS=4 MEM=40G**: hbox has ~42 GB available (20 GB /dev/shm not ours, other lanes),
  and earlyoom SIGTERMs Pay modules at 8 seats. Incremental build ~6 min; a host change touching Pay ~35 min.
  Launch: `ssh hbox 'cd /othersys/lanes/integ && (SEATS=4 MEM=40G setsid nohup ./integ-build.sh SHA > build.out 2>&1 < /dev/null & echo $! > build.pid)'`
- Gate: newest script `integ/gate7.sh SHA` (scripts are never edited in place; a change gets the next number).
  Env: PHASES (default "tour composed enrol"), SUF (run-dir suffix), HARNESS (overlay scripts/ +
  native/resource-client scripts + journey.d from that sha), EDGE_REV (dregg-infra tree integ/dregg-infra-<rev>;
  use 69c17a3), PORT / JWORLD_ROUTE_FRONT_PORT (unique per concurrent run), JWORLD_MANAGEMENT (`sponsor` for the
  gate; `distinct` breaks app births, see below), JWORLD_ROOT_HANDOFFS=1 (default), TOUR_FROM (reuse a TOUR.tsv).
  Results: integ/gate-<sha8><SUF>/ (TOUR.tsv, composed-result.json, gate.json), runs under /ci (t-*, c-*, e-*).
  Playwright: /tank/dregg-build/rows-0ce31391/pw/node_modules, browsers ~/.cache/ms-playwright (chromium 1234).
  EtherCalc SPK cached at integ/spk-cache. World-ups hold `flock -o /tank/lanes/world-up.lock` (the tour holds it
  for its whole J0-J8 journey).

## Main and candidates

| sha | state |
|---|---|
| 2b8f75dcb | candidate; tour 64/73, composed apps pass (628a9aa, no route front), enrol-resume PASS |
| c7a632f7b | candidate; tour 65/73 (8 story reds, demo-path), enrol-resume PASS; composed sponsor+route front: rooms/churn/documents/apps/store-restart PASS, connector red (below) |
| 86f8d3e79 | MAIN, candidate READY 04:46 (effects-proofs, spk-fresh 5 apps); not gated (Rust/apps delta over c7a632f7b) |
| staging cd29b864a | FEATURED -> repackaged appIds; rides the next build |

Landed today: cx-web, no-pins, cx-app-interface batch (one declarations loader), apps-agents eca26cc6c + 4420cebd4,
iter-speed ad2a19c10, qualify docs, un-japps-rows note, certify-prefix re-land (revert 80ec420e5 + 9d00fba59; its
Kernel.Tip renamed ChainHistory.Tip), effects-proofs 6905653b2, spk-fresh a3cf3d16d + 105833c38, host-op literal
names, Host/Main.lean:7258 Slice fix, harness: workroom-ready management custody, composed-inputs owner custody.
Kimi batch 1 (cx-web/no-pins/app-interface): one real finding fixed (57ccdbf6e), one rejected (EIO heartbeat).

## Reds

- Product, connector: `spk-host grain register-route` op36 refused "current app/session/ticket policy linkage
  refused" (Kernel/ApplicationDispatchAdmission.lean:1078); /ci/c-c7a632-s2/inputs/evidence/connector-930001-connector.
- Product, tour: tour-can-any + 7 story-* rows "this session has no room operations" (demo-path ad899edab1627208d).
- Umbrellas: Effects/Revival/ContentProofs.lean:589 rfl (effects-proofs); Fixtures NativeAcceptedFixture:173 /
  NativeDocWriteFixture:149 stale recordings (effects, ruling (c)).
- Harness owed: residents root hand-offs (provider-custody-copy v2 + controller register under sudo -n) in the
  composed residents phase; distinct-management app births must be signed by the owner 7 (factory controller) with
  8 as owner/manager (scripts/workroom/provision.sh:151-154,292 is the deployed shape).

## Not landed

perf-batch1 (hot-path owns it), statement-fixes (WIP, no branch), qualify-doc-contention (WIP proofs),
cx-oracle dd80466a1 and codex/oracle-v7-qualification b32f15604 (conflict with main; wait for the oracle7 batch,
merge main into it, one Kimi review).

## Senders

hot path (deep Lean), apps-agents a299a90746a7b2975, demo-path ad899edab1627208d, spk-fresh (Kimi workers;
their landing step updates FEATURED), effects-proofs, oracle7 (codex). Infra a21547c57335a2932: tell it each
READY sha; rehearsal 3 runs in its demo container on dregg-forge (fresh genesis).

## Rules in force

Named-file commits with `git commit -F`; never `git add -A`, never `git stash`; unsigned commits fine. Filtered
tests only. PID files for every detached job; stop only by PID file. Lake/git on hbox as hbox, never root.
Disk pressure: stop and tell ember. Sum of swarm-build caps on hbox under ~100 GB.
