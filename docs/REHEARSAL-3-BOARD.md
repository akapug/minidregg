# Rehearsal #3: go/no-go board

Present state, rewritten whole by the qualification lead (lane/qualify) each time it changes. Never
appended. Rehearsal #3 ships only when every row in sections 1 to 3 is green on ONE candidate.

**As of 2026-10-28 17:10 UTC.** The newest READY candidate is 68cf4ba7a. 9bd52317c is building; it
carries the share-issue stage names (9c4db6a19), apps:sheet issuer = creator (b332e565c) and the
Hermes genesis read (18a3dcb26). Builds after it reach READY before umbrellas.
**Verdict: NO-GO.**

## How the board is fed

- **Gate**: the integrator's `gate-cut6.sh` (tour plus composed) on each READY candidate; enrol-resume
  beside it.
- **Composed, keep-going**: lane/qualify's composed-scenario.py. A red phase no longer stops the run.
  Only the phases that REQUIRE it are blocked. Each phase has its own ledger. `preflight` checks every
  input it can without the world, in seconds, before any effect. `store-restart` restarts the Store
  independently of the app chain.
- **Inputs, keep-going**: composed-inputs.sh names what the world lacks as `CONNECTOR UNAVAILABLE` /
  `RESIDENTS UNAVAILABLE` lines and exits 0.
- **Test-ahead runs** on dregg-build: `/build/lanes/qualify/qrun.sh NAME CAND PORT` runs one standing
  world per cycle, about 15 min. It uses the newest candidate, or an **overlay**: the Host and
  consent from a READY candidate, every Rust role at main's tip (`qoverlay.sh`; Rust built on hbox by
  `lane-build.sh rust` in about 10 min cold). An overlay never ships and is never placed under
  /build/candidates. Its QUALIFY-OVERLAY.json names the Host commit.
- **Demo-dry**: infra's walk on the demo-dry container. Today it is by hand; `edge/demo/demo-dry-walk
  CP` (keep-going, TSV) is the infra successor's first task.

## 1. Gate (tour + composed + enrol-resume)

| check | status | evidence | owner | fix |
|---|---|---|---|---|
| jtour (69 rows) | GREEN on 68cf4ba7a, 349e59ef1, b26630168 | integ8/gate-68cf4ba7/TOUR.tsv | integrator | — |
| enrol-resume | GREEN (same three) | integ8/enrol-resume-*.log | integrator | — |
| composed rooms | GREEN | /build/q2/composed/state | — | — |
| composed churn | GREEN | same | — | — |
| composed documents | FLAKY under load: q1 (load 45) member-1's concurrent append exhausted 5 re-plans, `stale-target`; q2 (load 7) green | q1 evidence 0089 (torn down; the line is quoted here) | coordinator (client re-plan under contention; unowned) | — |
| composed apps:sheet | RED: `mini share-issue` "outcome did not confirm" (Host: application-grain-share-issue refused) | /build/q2/inputs/evidence/app-930001/hooks/*/117-command.stderr | B3 faerie a85d12892ea6de3ca (via deputy) | hypothesis: plan-height notBefore/notAfter vs submit-height rebuild (ApplicationShareIssueSource.lean:215, ...GrainAdmission.lean:139-165) |
| composed connector | RED (preflight, seconds): main's composed-inputs.sh wrote no `connector` selection | q1 state.json | qualify | fixed on lane/qualify (80657f37f, 41581198b). Still RED until the route front and EtherCalc land (below) |
| connector: EtherCalc app | composed's app was sntfy; the connector captures EtherCalc csv | — | qualify (deputy's ruling) | lane/qualify 41581198b (untested in a world) |
| connector: https route front | RED: jworld-scratch serves none (`routeFrontRequired`) | /build/q2/inputs/result.log | infra; sub-agent on dregg-infra qualify/jworld-composed | in progress |
| composed residents | BLOCKED (connector), and RED on four world pieces: distinct owner/management principals, root-owned keys-client.json, bwrap beside launch-gate, root hand-offs (controller-entry) | /build/q2/inputs/result.log | infra (same sub-agent) | in progress |
| composed restart (resident) | BLOCKED (residents) | — | — | — |
| composed store-restart | first run pending: q1 was blocked by documents | — | qualify | — |
| umbrellas (non-fatal) | named red until NativeDocWriteFixture / NativeAcceptedFixture are re-recorded | integ8/UMBRELLAS-RED | effects a26c13b24522dee35, L1e successor | — |

## 2. Demo-dry (infra's walk on 349e59ef1, fresh genesis)

| item | status | evidence (demo-dry) | owner | fix |
|---|---|---|---|---|
| preship-check | GREEN | dregg-build /build/lanes/infra/check-349e59ef1647 | infra | — |
| ship --regenesis, post-init pins, mini-health | GREEN | /root/ship-349e.log | infra | — |
| apps bootstrap + reenroll | GREEN, except old door members (dryguest1 provision refused) | — | story faerie acf88647b53657831 | — |
| grain world | GREEN | /root/grain-world-349e.log | — | — |
| Hermes create | RED: resident reads genesis.json | /root/hermes-349e.log | L4d a450fc35eb510f987 | 18a3dcb26 (in 9bd52317c) |
| seed: summon | RED (no Hermes; lobby never registered, no hermes/turn tariff) | /root/seed-349e*.log | L4d | — |
| seed: bend | RED: unfunded | same | infra (next genesis figures) | ruled |
| seed: apps install x3 | RED: broker refuses real (20-digit) app ids | same | acec1de6f1c53a04c | bd9318540 (lane/un-japps-rows; Lean elaboration pending) |
| story seed (tale, GM, narrate) | GREEN | — | — | — |
| public reader warm | GREEN | — | — | — |
| public reader first visit | RED: 504 at 120 s (cold consent worker) | scratchpad cold-trace-2.txt | infra successor: ember's call between a warm public worker (about 1 GB) and a warm on start | — |
| consent 200 → idle → 200 | GREEN | — | — | — |
| door new stranger | RED: provisioning `signature wrongMessage`, retries loop | dg4-*.txt | story faerie acf88647b53657831 | — |
| door story invite (re-enrolled) | RED: empty proposal | same | story faerie | — |
| grain starts and writes | NOT REACHED (installs red) | — | — | — |
| mini-certify killed each minute under load | seen, unowned | — | coordinator | — |
| clock-tick intermittent staleAuthority | seen, unowned | — | coordinator | — |

## 3. Demo-path rows (static forecast, main 65309b427; planted rows owed)

| row | status | owner | fix |
|---|---|---|---|
| apps worker hard-codes the workroom shape (apps_worker.rs:1068-1072); every worker session birth is refused on the demo genesis | RED (forecast) | acec1de6f1c53a04c | — |
| a refused worker reserve is never released (apps_worker.rs:1063/1188) | RED (forecast) | acec1de6f1c53a04c | — |
| real app ids above 2^63: manifest+1, `app_n*100` wrap, bounds in grain.rs:1634, grain_agent_route.rs:262, controlGroupBound | mostly fixed | acec1de6f1c53a04c | bd9318540 |
| apps worker served one member at a time; install inline (CLI 120 s timeout) | FIXED, unmerged | ab368e520ce312b3c | lane/un-worker-concurrency dd7de9faf |
| apps bootstrap birthStale on an aged world (more than 64 ticks, about an hour) | fix on no remote branch | acec1de6f1c53a04c | 6566216c8 / da5a51424 (push asked) |
| JPAY6 thin-birth | with the integrator | integrator / ad0906325ab57d1c3 | 98064edba |
| Hermes: resident operator allowlist lacks Host ops 210-214 (await bridge, `bend deliver`) | FIXED, unmerged (waits for J14 run 5) | L4d a450fc35eb510f987 | lane/hermes-b 6895a5dbe |
| Hermes: seed lobby summon (needs install for an existing room) | in progress | L4d | — |
| Hermes: strangers can't summon into their own room (a resident is bound to one room by design) | DECISION: (a) the tour summons in a house room, or (b) a per-room install pump | root / ember | — |
| Hermes: provider purse 50000 never refilled | in progress (`install-hermes refill`, J14 row) | L4d | — |
| Hermes: summon after dismiss refused ("budget account differs") | in progress (`install-hermes resummon`) | L4d | — |
| Hermes: Oracle not bound into the tool task | queued after the two above | L4d | — |
| door: world id changes on `run.sh upgrade`; a create the Host never took wedges the name; failed story seal never retried | FIXED, merged after 9bd52317c | acf88647b53657831 | 6884e6043 |
| public "operations" name squatting (web body.rs:576-631, mini-web-spawn) | RED (forecast) | web front-end owner, via coordinator | — |
| grain-route latency about 5 s Host CPU per turn: TextEditor, Wekan and WBO writes red; 503 busy for multi-request apps (http_entrance.rs:861) | RED | perf lane / perf-rake | 41d87f720, 430e0fe81 (partial) |
| demo market installs EtherCalc 2020.12.28.1 (index package 9b3b7615…, 36.9 MB); qualification evidence and composed use 93bd2c29… (11.98 MB) | DIVERGENCE | deputy | — |

## 4. Every refusal names its clause

- Rust and harness: done on lane/qualify-refusals 4241cf11a. The operator log gets the reason on
  every demo-path refusal: transport, public proxy, apps worker/front, web body, mini-web(-spawn),
  door, agent API, broker, dispatch fence, Hermes dispatcher. Member-facing bytes are unchanged.
  Unmerged; with the integrator.
- Lean-only gaps (Host/Main.lean; the f2deb6ede pattern): op34 app submit (2784, 4544), op26/op22 lifecycle (2937/2988, 1626/1647), op84 carried enrol (4384),
  op105 pay (7477), op242 platform install (7507), op246 meter refill (7534), op189 key adoption
  (7600). Owner: unassigned (coordinator). Ops 46/76 and the lifetime grant are fixed on
  lane/hermes-b 38c456653 (L4d).

## Open items of the qualification lane

- Composed rerun on a warm or snapshot world: composed-inputs refuses an existing grain world and
  reuses ids 930001/960001.
- `scripts/pipeline/lane-check` should refuse to run when its caller already holds closure-lock (the
  dregg-ref self-deadlock).
