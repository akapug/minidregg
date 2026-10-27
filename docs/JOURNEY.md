# The journey is the definition of done

`native/resource-client/journey.sh MANIFEST.json NEW_RUN_ROOT` is the one definition of done. It starts a
fresh private Store from the binaries the manifest pins (sha256-checked), walks its steps in order, prints one
row per step (PASS / FAIL / UNBUILT / UNMEASURED / UNCONFIGURED, wall seconds, the artifact that decided it),
writes `journey-result.json`, and exits 0 only when every step passes. The frontier is the first step that did
not pass; it is read from a run, never written by hand. The `STEPS` array in `journey.sh` is the list; each
step's header comment names its hook in `journey.d/`; a hook's presence turns an UNBUILT stub into a real step,
and its contract (exported variables; exit 0 PASS, 5 UNCONFIGURED, anything else FAIL; last-line artifact) is in
the script's header.

## Two journeys

Since 2026-10-26 the steps are partitioned (`SPINE`, `DEMO_STEPS`, `KERNEL_STEPS` beside `STEPS` in
`journey.sh`; a step in no set or in two refuses every run, so a new step must be placed):

| journey | steps | where it runs |
|---|---|---|
| spine | J0–J8, the tree-neutral journey below | in both journeys |
| **demo** (`JOURNEY_SET=demo`) | what the public demo's surfaces need: malformed and hostile requests (J12X, JSERVE), thin consent, the clock and the tail bound (KC, KT), rooms and their exports, templates, private rooms, chat with the Discord bridge, Hermes as librarian, a week of credit (J17), documents through the shell and the web (K12C/T/M/H/R/I, WEB, J12, J12W, JNAMES, JDV, JPD), M3–M8, PAY (JPAY1–4, JPAYE1–3, JPAY6), keys over the proxy, rotation, the refusal lane, the fn gateway, disclosure, the Store audit | `scripts/check-journey.sh` (local gate `journey`, 2.5 h budget inside the gate's 3 h); the pipeline rows `journey` + `demo` + the per-item rows |
| **kernel** (`JOURNEY_SET=kernel`) | kernel semantics no public surface exercises directly: kind revision (P7KR), G, 32 fields, concurrent births, joint index, per-author streams, channels, fields and narrowed reads, the sealed market, element trees and run edits, wells, the story, Nock (JN2, JN3, JN3P, JN5, JSYNC), plan binding, law clauses, jobs, field closure, affordances, inspect, law-sat | the nightly: pipeline rows `kernel` and `growth` (`PIPELINE_NIGHTLY=1`, docs/PIPELINE-HBOX.md) |

`journey.sh --list-set demo|kernel|all` prints a journey's steps. `JOURNEY_STEPS` still runs any subset.

The continuous runner (`scripts/pipeline/journey-rows`) runs, per landing, `journey` (J0–J8, JROT, JROTL, and
JRLANE, JGATE, JAUDIT and any seat step), `demo` (the demo journey minus the steps another row runs), the
per-item rows (`m3`, `m4`, `hermes`, `m6grain`, `m7`, `m8`, `jpay`, `jserve`), and the Objective and platform
rows (`objective`, `rooms`, `activity`, `seats`, `bounty`, `call`, `send`, `domain`, `upgrade`, `hostupgrade`,
`objectrecord`, `welcomecontinuity`, `sshe2e`, `fleetsign`, `exchange`, `chargedfailure`, `births`, `perf`);
`scripts/pipeline/required-rows` says which a landing requires.

**M6** (`journey.d/m6.sh`, ruling D9) is a thin delegate to the `m6grain` row's scenario,
`scripts/spk-platform/two-world-journey.sh full`, with its edge phase required: a Caddy on loopback in front of
each world's route socket, through which the authenticated GET answers 200, the anonymous one is refused and a
WebSocket opens with 101 (`grain-journey.sh` phase `edge`). It needs the journey to run as the operator uid with
linger, a subuid range, uidmap, `sudo -n` for this tree's `install-user-world`, a Caddy, openssl and the pinned
sntfy; without one it is UNCONFIGURED naming it. Its first run is on a Debian 13 grain host.

The older acceptance scripts are not gates; a behaviour of theirs that still matters is a journey step:

| script | what it checks | where that lives in the journey |
|---|---|---|
| `newparticipant-acceptance.sh` | fresh one-sponsor genesis, service, sponsor workspace | **kept as J0's body**; `journey.sh` calls it |
| `acceptance.sh` | one-signer birth, content write, lost outcome recovered by exact retry, joint write | J2, J4, J6 (the joint write has no step yet) |
| `authority-acceptance.sh` | policy install, delegation, policy-refused owner mutation, child cannot manage, revocation, historical retry | J3, J5, J7, J8, J6 (revocation has no step yet) |
| `application-acceptance.sh` | two-participant app birth and observe, cross-session read refusal, restart replay | J5, J6; the running grain is M6 |
| `selected-release-acceptance.sh` | two Stores, owner-signed selected release, conflict / wrong signer / lost reply | none yet: list item 9 (second node over fn) |
| `selected-source-publisher-acceptance.sh` | source-side authorization and protected fn POST | none yet: list item 9 |
| `selected-source-drop-reply.sh` | test-only Host shim for the publisher gate | not a gate; goes when item 9 becomes a step |

## The steps J0–J8 and growth

The journey was fixed on 2026-09-29, before any tree ran it, as a tree-neutral
bake-off between Mini and Bread for the October 13 shellserver: the criteria and
the decision rule were written first so the result could not choose its own
yardstick. Each step is pass, fail, or not expressible.

| step | what happens |
|---|---|
| J0 | From clean state, start a private single-authority service with one sponsor identity. |
| J1 | Enroll an independently generated newcomer key. No operator edit to genesis or config on the newcomer's behalf. |
| J2 | The sponsor creates an ordinary resource under a law that permits ordinary use. |
| J3 | The sponsor delegates a narrower right to the newcomer: observe and mutate, without control or further delegation. |
| J4 | The newcomer signs a read, writes a field to 1, reads back 1. |
| J5 | A third key holding no grant attempts a read and a write. Both must be refused. |
| J6 | Stop the service and reopen the same Store. J1's receipt and J4's value are recovered. An exact retry of J4's call returns the original receipt and causes no second effect. |
| J7 | The sponsor replaces the law with one that still permits the newcomer's operation. The newcomer's EXISTING grant still works. |
| J8 | The sponsor installs deny-all. The newcomer's read and write are refused. The sponsor's own attempt to repair is refused too. |

J5, J7 and J8 encode decisions already made: observation needs authority, grants
survive a change of law, and a resource may lock its own management with no
owner bypass.

**Growth (G)** runs after J6 and before J7, on the same Store. At cumulative
accepted-record counts of 10, 100, 500 and 1000: the latency of one signed write
and one signed read (five samples each, median and worst), and cold reopen (stop
the service, start it, time until the first signed read returns). A level is
aborted, and that is recorded, if any single operation exceeds 600 seconds.

**Thresholds** for "a friend would call this interactive", at 1000 accepted
records: a signed write in at most 5 seconds, a cold reopen in at most 60
seconds. A tree that fails J5, J7 or J8 needs kernel changes to match the settled
semantics; one that fails the growth thresholds needs storage and recovery work;
one that cannot reach J0 in its time box has a build problem, and the time it
consumed is the measurement.

## The simulation gate (HP-6 SIM)

`scripts/gates/check-world-sim` is a merge-gate row (`world-sim` in
`scripts/pipeline/merge-gate-checks.sh`). It runs `world-sim` (`Host/WorldSim.lean`), a
seeded, deterministic, one-process simulation. The Host side is today's admission path:
the receiver (`DurableDataIntent.execute`), then `Turn.ofIntent`, then `World.admit`, with
the record and the Turn entry persisted. The follower side folds only the entries
(`TurnLog.followFrom`). Both are fed intents and presented turns from `Kernel/TurnGen.lean`,
valid and invalid. On every step the sim asserts that the roots are equal, that the follower
re-admits each admitted entry, that it refuses each refused turn by the same name, and that the
receiver's cell bytes, meter, spent set and height equal the World's (`Represents` on the
touched cells). Every K steps the Host crashes at a seeded point and reopens from its persisted
bytes, and the reopened Host must equal the one that ran without interruption. Two plants
must each go red at their recorded seed and step: the follower skipping a failed leg-0 guard
(seed 1, step 29) and a reopen that loses the last Turn entry (seed 1, step 49). Default: seeds
1–3 × 300 steps, K = 50. Nightly: `WORLD_SIM_SEEDS=64 WORLD_SIM_STEPS=10000 WORLD_SIM_K=500`.
`WORLD_SIM_STORES=stores.json` adds the retained Stores' own records as a corpus.
