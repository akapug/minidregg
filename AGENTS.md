# Working on Mini

Read [HANDOFF.md](HANDOFF.md) first, then the plan
[docs/DEMO-PREFIX-2026-10-26.md](docs/DEMO-PREFIX-2026-10-26.md) and
[docs/COORDINATION-2026-10-27.md](docs/COORDINATION-2026-10-27.md), which describes how this
project is developed (what we optimise, the gates and their verdicts, how a lane and the
orchestrator work, the boxes, the cadence). Read the source before trusting older
architecture or status text.

- Lean owns semantics and admission; Rust provides the physical client and custody
  boundary. Do not introduce a Python platform or reimplement semantic decisions in a
  transport wrapper.
- Existing grants face current rules; policy revision is distinct from revocation.
  Deliberate management lockout is permitted; do not add an owner recovery bypass.
- One worktree per lane on a `lane/<name>` branch; the integrator merges in
  dependency order and builds the whole tree once on `dregg-build`. Never the main
  worktree, never `git stash`, never blanket staging; inspect full-file diffs before
  committing named paths.
- Linux checks run on `dregg-build` (`ssh dregg-build`, `/build/lanes/<lane>`,
  `swarm-build` around every build). `scripts/build-native-host.sh` is the recorded
  native route (its seats bound Lean fan-out: `MINIDREGG_LEAN_SEATS`, default 2;
  `LEAN_NUM_THREADS` alone does not); the journey (`native/resource-client/journey.sh`)
  is acceptance. Read their help first.
- Preserve admitted-history, current-authority, exact-preimage and uncertain-reply
  semantics when optimizing. General proofs and actual receiving-path evidence
  are separate obligations; a source check does not establish deployment.
- Reds are named in a run's output, never kept in a ledger, and no lane runs a "was it
  red before me" baseline. Performance is published, never a gate. The gate is the tour
  (`jtour` plus the composed scenario); standing rows are the nightly's (COORDINATION §6).
- Per-lane `CARGO_TARGET_DIR`, scratch subdirectory and PID file for every started
  process; no foreground waits (`box-wait` in one background call); REPL-first Lean;
  no whole-file `Read` over 2,000 lines (COORDINATION §3).
- Report in ≤ 20 lines: branch tip, what was verified and where, reds by name, one
  BATCH FOR THE PARENT for what could not run where you are. Decisions by default,
  recorded; only money, dates and credentials go to ember.
- Unsigned commits are fine when 1Password is unavailable; do not change global
  signing settings. Keep recipient-specific team communications outside Git.
