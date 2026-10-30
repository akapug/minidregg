# Start here

For contributors and agents. The [README](README.md) says what Mini is and maps the tree.

## What to read, in order

1. [`docs/DEMO-EXPERIENCE-2026-10-27.md`](docs/DEMO-EXPERIENCE-2026-10-27.md): what the demo is
   for. The stranger's fifteen-minute tour, the rule that every shell verb has a web face, the
   box as a member, and the ranked ambitions.
2. [`docs/DEMO-PREFIX-2026-10-26.md`](docs/DEMO-PREFIX-2026-10-26.md): the plan. The work from
   main to a public demo with every surface on, and the conditions for opening it.
3. [`docs/COORDINATION-2026-10-27.md`](docs/COORDINATION-2026-10-27.md): how the project is
   developed. What we optimise, the gates, how a lane and the orchestrator work, the boxes,
   the cadence. [`AGENTS.md`](AGENTS.md) and [`CLAUDE.md`](CLAUDE.md) summarise its rules.
4. [`ATLAS.md`](ATLAS.md) §6: the sixteen design laws.

The plan and the experience document are present-state: they are rewritten whole when the
state changes. Nothing dated before the plan is current authority.

## Where the current state lives

- [`docs/STATUS.md`](docs/STATUS.md): what the next build carries, row by row, with evidence.
- [`docs/INTEGRATOR-STATE.md`](docs/INTEGRATOR-STATE.md): what is merged, building and gated.
- `docs/*-STATE.md`: each lane's own state file.

## The evidence behind the plan

The review corpus is under [`docs/review/`](docs/review/). The ones most often cited:

| File | What it answers |
|---|---|
| `2026-10-26-history/HISTORY.md` | what the August to October sessions did, decided and abandoned |
| `2026-10-26-deploy/HCLOUD-GAP.md` | the gap from main to a URL a stranger can use |
| `2026-10-26-deploy/AFFORDANCES.md` | what Mini exposes: CLI, shell verbs, SDKs, protocol, Hermes, data model, performance |
| `2026-10-26-deploy/WEB-SPK-PUBLIC.md` | the public web, the SPK application path, identity in the browser |
| `2026-10-26-native-crates/SYNTHESIS.md` | every Rust crate read whole: where Rust decides semantics, and the triage |
| `2026-10-26-triage/RUST-TRIAGE.md`, `LEAN-TRIAGE.md` | independent second opinions on what to delete, rescue or move out |

## The boxes

- `dregg-demo` (Hetzner, `demo.dregg.online`) serves the demo. Logins stay closed until the
  opening conditions hold.
- `dregg-build` is where Linux checks, Lean builds and the integration build run.
- Both are deleted on 2026-11-11. Their configuration lives in `~/dev/dregg-infra`, branch
  `demo-vm` (`edge/demo/CONFINEMENT.md`, `edge/demo/CHECKLIST.md`); the deploy frame, runbook
  and gate are in `edge/mini` there.

## Sibling repositories

- `~/dev/nanodregg`: the single-writer rebuild; its laws are the target shape for this tree.
- `~/dev/breadstuffs`: the whole first system.
- `~/dev/zkml-research`, `~/dev/degg-research`: where this tree's proof-system and MPC research
  moves.
- `~/dev/o7vn`: veri7vn, arriving here as the Oracle appliance.
- `~/dev/fn`: the NNTP transport; it has its own sessions and is not part of this demo.
