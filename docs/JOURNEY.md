# The journey

`native/resource-client/journey.sh MANIFEST.json NEW_RUN_ROOT` is the end-to-end acceptance
test. It starts a fresh private Store from the binaries the manifest pins (sha256-checked), runs
its steps in order, and prints one row per step: PASS, FAIL, UNBUILT, UNMEASURED or
UNCONFIGURED, the wall time, and the artifact that decided it. It writes `journey-result.json`
and exits 0 only when every step passes. The first step that did not pass is the frontier; read
it from a run, never write it by hand.

The step list is the `STEPS` array in `journey.sh`. Each step's meaning is in the file's header
comment and in its `step_<ID>` function. A step with a hook at
`native/resource-client/journey.d/<id>.sh` runs it; a step without one is UNBUILT
(`scripts/gates/journey-unbuilt.tsv` pins which). The header also gives the hook contract
(exported variables; exit 0 is PASS, 5 is UNCONFIGURED, anything else FAIL; the last stdout line
names the deciding artifact) and the meaning of each status. This document does not copy the
step list, because it changes with every landed lane.

## Two journeys and the runner rows

Every step belongs to exactly one of `SPINE` (J0 to J8, run in both journeys), `DEMO_STEPS` or
`KERNEL_STEPS`. `journey_sets_check` refuses to run if a step is in no set or in two.

- **demo** (`JOURNEY_SET=demo`): what the public demo's surfaces need. `scripts/check-journey.sh`
  runs it as the local gate `journey`, with a wall budget of 2.5 hours
  (`LOCAL_GATES_JOURNEY_BUDGET_S`, default 9000 for demo).
- **kernel** (`JOURNEY_SET=kernel`): kernel semantics no public surface exercises directly,
  including G (growth). It runs only in the nightly, as the runner rows `kernel` and `growth`
  (`PIPELINE_NIGHTLY=1` in `scripts/pipeline/journey-rows`; see docs/PIPELINE-HBOX.md).

`journey.sh --list-set demo|kernel|all` prints a set's steps. `JOURNEY_STEPS` runs any subset
(`JOURNEY_SET` and `JOURNEY_STEPS` together are refused). `--only STEP` runs one step and exactly
the steps it depends on. `--keep-going` keeps running past a failed dependency, so one run
reports every failure.

The continuous runner runs the rows in `JOURNEY_ROWS` (`scripts/pipeline/journey-rows`):
`journey` (the spine plus the key-rotation, lane, gate and audit steps), `demo` (the demo journey
minus steps another row runs), and one row per item journey or platform scenario.
`scripts/pipeline/required-rows` says which rows a landing requires.

**M6** (`journey.d/m6.sh`) delegates to the `m6grain` row's scenario,
`scripts/spk-platform/two-world-journey.sh full`, with its edge phase required. Its inputs, and
the UNCONFIGURED exit when one is missing, are in the hook's header.

## Scripts that are not steps

`newparticipant-acceptance.sh` is J0's body and `provisioning-acceptance.sh` is M3's. No journey
step, runner row or gate calls `acceptance.sh`, `authority-acceptance.sh`,
`application-acceptance.sh`, `selected-release-acceptance.sh`,
`selected-source-publisher-acceptance.sh` or `selected-source-drop-reply.sh`; they are not gates.
`acceptance.sh` is known broken: it writes content targets with `"schemaVersion": "1"`, while
`Kernel/ContentResource.lean` has `commandVersion := 10`
(docs/review/2026-10-26-native-crates/resource-client.md, row `acceptance.sh`). A behaviour of
theirs that still matters belongs in a journey step.

## The spine (J0 to J8) and growth

Each step passes or fails.

| step | what happens |
|---|---|
| J0 | From a clean state, start a private single-authority service with one sponsor identity. |
| J1 | Enrol an independently generated newcomer key, with no operator edit to genesis or configuration on the newcomer's behalf (the step searches genesis, operator config and deployment for the key). |
| J2 | The sponsor creates an ordinary resource under a law that permits ordinary use. |
| J3 | The sponsor delegates a narrower right to the newcomer: observe and mutate, without control or further delegation. |
| J4 | The newcomer signs a read, writes a field to 1, and reads back 1. |
| J5 | A third key holding no grant tries a read and a write. Both must be refused. |
| J6 | Stop the service and reopen the same Store. J1's receipt and J4's value are recovered. An exact retry of J4's call returns the original receipt and causes no second effect. |
| J7 | The sponsor replaces the law with one that still permits the newcomer's operation. The newcomer's existing grant still works. |
| J8 | The sponsor installs deny-all. The newcomer's read, proposal and crafted submit, and the sponsor's own read and repair proposal, are all refused (5 of 5). A prior call still replays its original receipt. |

J5, J7 and J8 encode settled semantics: observing needs authority, grants survive a change of
law, and a resource may lock its own management with no owner bypass.

**Growth (G)** runs after J6 and before J7 on the same Store, at 10, 100, 500 and 1000
accepted records (`JOURNEY_GROWTH_LEVELS`, set in `journey.d/lib/run-growth.sh`). It measures
write latency (p50, p99, max), certify wall time and the cold reopen time. It fails when, at
1000 records, the slowest write takes over 5 s or the cold reopen over 60 s, and aborts when one
write takes over 600 s. A run whose levels leave out 1000 is UNMEASURED, not PASS.

## The simulation gate

`scripts/gates/check-world-sim` is the merge-gate row `world-sim`
(`scripts/pipeline/merge-gate-checks.sh`). It runs `world-sim` (`Host/WorldSim.lean`): a seeded,
deterministic, one-process simulation of the Host admission path against a follower that folds
only the Turn entries, with seeded crashes and reopens. Two planted divergences must each fail
at their recorded seed and step. Defaults, nightly settings and the optional Store corpus
(`WORLD_SIM_STORES`) are in the script's header.
