# The journey is the definition of done

`native/resource-client/journey.sh MANIFEST.json NEW_RUN_ROOT` is the one definition of done. It starts a
fresh private Store from the binaries the manifest pins (sha256-checked), walks its steps in order, prints one
row per step (PASS / FAIL / UNBUILT / UNMEASURED / UNCONFIGURED, wall seconds, the artifact that decided it),
writes `journey-result.json`, and exits 0 only when every step passes. The frontier is the first step that did
not pass; it is read from a run, never written by hand.

The step list is the `STEPS` array (`native/resource-client/journey.sh:109`); each step's one-line meaning is in
the header comment of that file and in its `step_<ID>` function. A step with a `native/resource-client/journey.d/<id>.sh`
hook runs it; a step without one is UNBUILT (`scripts/gates/journey-unbuilt.tsv` pins which). The hook contract
(exported variables, exit 0 PASS, 5 UNCONFIGURED, anything else FAIL, last stdout line the deciding artifact) and the
status words are in the `journey.sh` header (`:60-94`). This document does not copy the step list: it changes with
every landed lane.

## Two journeys and the runner rows

The steps are partitioned into `SPINE` (J0-J8, in both journeys), `DEMO_STEPS` and `KERNEL_STEPS`
(`journey.sh:119-121`). A step in no set or in two sets refuses every run before anything starts
(`journey_sets_check`, `journey.sh:122-135`), so a new step must be placed.

- **demo** (`JOURNEY_SET=demo`): what the public demo's surfaces need. `scripts/check-journey.sh` runs it as the
  local gate `journey` with a 2.5 h wall budget (`LOCAL_GATES_JOURNEY_BUDGET_S`, default 9000 for demo,
  `scripts/check-journey.sh:80`) inside the gate's 3 h.
- **kernel** (`JOURNEY_SET=kernel`): kernel semantics no public surface exercises directly, including G (growth).
  Nightly only: the runner rows `kernel` and `growth` (`PIPELINE_NIGHTLY=1`, `scripts/pipeline/journey-rows:17-19`;
  docs/PIPELINE-HBOX.md).

`journey.sh --list-set demo|kernel|all` prints a set's steps; `JOURNEY_STEPS` runs any subset; `JOURNEY_SET` and
`JOURNEY_STEPS` together refuse.

The continuous runner runs the rows listed in `JOURNEY_ROWS` (`scripts/pipeline/journey-rows:15`): `journey` (J0-J8,
JROT, JROTL and the JRLANE / JGATE / JAUDIT / seat steps), `demo` (the demo journey minus the steps another row runs),
and one row per item-journey or platform scenario (including `call` and `send`). `scripts/pipeline/required-rows` says
which rows a landing requires.

**M6** (`journey.d/m6.sh`) is a delegate to the `m6grain` row's scenario, `scripts/spk-platform/two-world-journey.sh
full`, with its edge phase required. Its inputs, and the UNCONFIGURED exits when one is missing, are listed in the
header of `native/resource-client/journey.d/m6.sh`.

## Scripts that are not steps

`newparticipant-acceptance.sh` is J0's body (`journey.sh:614`), and `provisioning-acceptance.sh` is M3's
(`journey.d/m3.sh`). No journey step, runner row or gate calls `acceptance.sh`, `authority-acceptance.sh`,
`application-acceptance.sh`, `selected-release-acceptance.sh`, `selected-source-publisher-acceptance.sh` or
`selected-source-drop-reply.sh` (`rg` over the tree, excluding docs/review and docs/evidence); they are not gates.
`acceptance.sh` writes content targets with `"schemaVersion": "1"` (`:222`, `:337`, `:354`) where
`Kernel/ContentResource.lean:432` has `commandVersion := 10`; the native-crates review recorded it as broken
(docs/review/2026-10-26-native-crates/resource-client.md, row `acceptance.sh`). A behaviour of theirs that still
matters belongs in a journey step.

## J0-J8 and growth

The tree-neutral spine. Each step is pass or fail.

| step | what happens |
|---|---|
| J0 | From clean state, start a private single-authority service with one sponsor identity. |
| J1 | Enroll an independently generated newcomer key. No operator edit to genesis or config on the newcomer's behalf (the step greps genesis, operator config and deployment for the key, `journey.sh:641`). |
| J2 | The sponsor creates an ordinary resource under a law that permits ordinary use. |
| J3 | The sponsor delegates a narrower right to the newcomer: observe and mutate, without control or further delegation. |
| J4 | The newcomer signs a read, writes a field to 1, reads back 1. |
| J5 | A third key holding no grant attempts a read and a write. Both must be refused. |
| J6 | Stop the service and reopen the same Store. J1's receipt and J4's value are recovered. An exact retry of J4's call returns the original receipt and causes no second effect. |
| J7 | The sponsor replaces the law with one that still permits the newcomer's operation. The newcomer's existing grant still works. |
| J8 | The sponsor installs deny-all. The newcomer's read, propose and crafted submit, and the sponsor's own read and repair proposal, are all refused (5 of 5). A prior call still replays its original receipt. |

J5, J7 and J8 encode settled semantics: observation needs authority, grants survive a change of law, and a
resource may lock its own management with no owner bypass.

**Growth (G)** runs after J6 and before J7 on the same Store, at cumulative accepted-record levels 10, 100, 500 and
1000 (`journey.d/lib/run-growth.sh:6`, `JOURNEY_GROWTH_LEVELS`): write latency (p50, p99, max), certify wall time and
the cold reopen time. It is red when, at 1000, the worst write exceeds 5 s or the cold reopen exceeds 60 s
(`journey.sh:905`), and aborts when one operation exceeds 600 s (`journey.sh:846`). A run whose levels omit 1000 is
UNMEASURED, not PASS (`journey.sh:908`).

## The simulation gate (HP-6 SIM)

`scripts/gates/check-world-sim` is a merge-gate row (`world-sim`, `scripts/pipeline/merge-gate-checks.sh:82`). It runs
`world-sim` (`Host/WorldSim.lean`), a seeded, deterministic, one-process simulation of the Host admission path
against a follower that folds only the Turn entries, with seeded crash and reopen. Two planted divergences must each
go red at their recorded seed and step (`scripts/gates/check-world-sim:36-37`). Defaults, nightly knobs and the
optional Store corpus (`WORLD_SIM_STORES`) are in that script's header.
