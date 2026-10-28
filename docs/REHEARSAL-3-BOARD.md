# Rehearsal #3: go/no-go board

Present state, rewritten whole by the qualification lead (lane/qualify) each time it changes. Never
appended. Rehearsal #3 ships only when every row in sections 1 to 3 is green on ONE candidate.

**As of 2026-10-28 17:40 UTC.** The newest READY candidate is 68cf4ba7a. 9bd52317c is in its gate
(enrol-resume green); it is the first build to name the refusing share-issue stage. 327096423 is
building: it carries keep-going composed b4653448e, the refusal logging 4241cf11a, the door/story
fixes and perf-rake. Later builds reach READY before umbrellas. **Verdict: NO-GO.**

## How the board is fed

- **Gate**: the integrator's gate (tour plus composed) on each READY candidate; enrol-resume beside it.
  Main's composed has kept going since bbadd8e11:
  - a red phase blocks only the phases that REQUIRE it, and each phase has its own ledger;
  - adapter reds carry their retained refusal line;
  - `preflight` fails a phase in seconds when its inputs can't work;
  - `store-restart` restarts the Store independently of the app chain.
- **Inputs, keep-going**: composed-inputs.sh names what a world lacks (`CONNECTOR UNAVAILABLE`,
  `RESIDENTS UNAVAILABLE`) and still writes every other input.
- **Test-ahead** on dregg-build: `/build/lanes/qualify/qrun.sh NAME CAND PORT` runs one standing world
  per cycle, about 15-25 min, under `/build/lanes/qualify/world.lock`.
  - `AGE=N` ticks the clock N times before apps bootstrap (the aged-world row).
  - CAND is the newest candidate, or an **overlay** from `qoverlay.sh`: Host and consent from a READY
    candidate, every Rust role at main's tip (built on hbox by `lane-build.sh rust`, about 10 min).
  - An overlay is never shipped and never placed under /build/candidates. Its QUALIFY-OVERLAY.json
    names the Host commit.
- **Demo-dry**: infra successor 4 (ac204a2887d583805) is writing `edge/demo/demo-dry-walk CP`. It
  keeps going and writes a TSV of item, status (GREEN/RED/BLOCKED/SEEN), evidence and first_refusal,
  headed by the candidate and infra revision. Section 2 below is the hand walk on 349e59ef1 until then.

## 1. Gate (tour + composed + enrol-resume)

| check | status | evidence | owner | fix |
|---|---|---|---|---|
| jtour (69 rows) | GREEN on 68cf4ba7a, 349e59ef1, b26630168 | integ8/gate-68cf4ba7/TOUR.tsv | integrator | — |
| enrol-resume | GREEN (also 9bd52317c) | integ8/enrol-resume-*.log | integrator | — |
| composed rooms | GREEN (q2, q3; room owner member-1) | /build/q3/composed/state | — | — |
| composed churn | GREEN | same | — | — |
| composed documents | GREEN at load 7-15; RED at load 45 (5 re-plans exhausted, `stale-target`) | q1 (quoted in e907f47e3) | qualify | client: time-bounded jittered re-plan, e907f47e3 on main f8cbcd5d3. Kernel commuting append: statement drafted, ruling owed (below) |
| composed apps:sheet | RED: `mini share issue outcome did not confirm` | /build/q2/inputs/evidence/app-930001/hooks/*/117-command.stderr | B3 a85d12892ea6de3ca | Ruled out: the plan/submit window (no turn between them in ci-349d) and the issuer (b332e565c). Remaining suspects: the app-delegation leg, or grain-birth admission. 9bd52317c's stage line decides |
| composed apps: EtherCalc as the app | in q3 (overlay c8d0e2341) | /build/q3 | qualify | lane/qualify 41581198b (held at the integrator until q3 passes apps install) |
| composed connector | RED: `routeFrontRequired` (no https front) | /build/q3/inputs/result.log | qualify sub-agent on dregg-infra qualify/jworld-composed | qj-2 printed no CONNECTOR UNAVAILABLE line; verifying |
| composed residents | BLOCKED (connector); also needs distinct owner/management principals, root-owned keys-client.json, bwrap beside launch-gate, root hand-offs | same | same sub-agent | in progress |
| composed restart (resident) | BLOCKED (residents) | — | — | — |
| composed store-restart | GREEN (q2: same cells, every marker once, owner write after) | /build/q2 (torn down) | — | b4653448e |
| umbrellas (non-fatal) | named red until NativeDocWriteFixture / NativeAcceptedFixture are re-recorded | integ8/UMBRELLAS-RED | effects a26c13b24522dee35, L1e successor | — |

## 2. Demo-dry (infra's hand walk on 349e59ef1, fresh genesis)

| item | status | evidence (demo-dry) | owner | fix |
|---|---|---|---|---|
| preship-check | GREEN | dregg-build /build/lanes/infra/check-349e59ef1647 | infra | — |
| ship --regenesis, post-init pins, mini-health | GREEN | /root/ship-349e.log | infra | — |
| apps bootstrap + reenroll | GREEN, except old door members (dryguest1 provision refused) | — | story faerie acf88647b53657831 | — |
| grain world | GREEN | /root/grain-world-349e.log | — | — |
| Hermes create | RED: resident reads genesis.json | /root/hermes-349e.log | L4d a450fc35eb510f987 | 18a3dcb26 (in 9bd52317c) |
| seed: summon | RED: lobby never had a resident | /root/seed-349e*.log | L4d | house room: lane/hermes-b 29af88045. Infra runs install-hermes FOUNDER_MEMBER=box ROOM=lobby before seed.sh; door.json `room` |
| seed: bend | RED: unfunded | same | infra | ruled figures at the next genesis |
| seed: apps install x3 | RED: broker refuses real app ids | same | acec1de6f1c53a04c | bd9318540 (Lean elaboration pending) |
| story seed (tale, GM, narrate) | GREEN | — | — | — |
| public reader warm | GREEN | — | — | — |
| public reader first visit | RED: 504 at 120 s (cold body 8 s; body and worker cold 23 s idle, more under load); idle-out recurs after 25 quiet min | cold-trace(-2).txt | qualify | lane/qualify-cold-read 18dc7c645 (warm at start and every sweep; consent lifeline 89c213734) with the integrator. Infra qualify/cold-read ab1d416 (public worker permanently warm, about 280 MB) with infra 4. J-COLD-READ rows |
| consent 200 → idle → 200 | GREEN | — | — | — |
| door new stranger | RED: provisioning `signature wrongMessage`, retries loop | dg4-*.txt | story faerie acf88647b53657831 | — |
| door story invite (re-enrolled) | RED: empty proposal | same | story faerie | — |
| grain starts and writes | NOT REACHED (installs red) | — | — | — |
| mini-certify SIGTERM each minute under load | FIXED, unmerged | qualify | infra qualify/unowned-trio 8ba1c27 (skip while running); minidregg 3030fc4a4 (re-plan raced refusals); jcertify rows |
| clock-tick staleAuthority | FIXED, unmerged | qualify | lane/qualify-unowned 3030fc4a4 (exact stale refusals re-plan, listed); jclock row |

## 3. Demo-path rows (forecast and found; planted rows named)

| row | status | owner | fix |
|---|---|---|---|
| apps worker hard-codes the workroom shape (apps_worker.rs:1068-1072); every worker session birth refused on the demo genesis | RED (forecast) | acec1de6f1c53a04c | — |
| a refused worker reserve is never released (apps_worker.rs:1063/1188) | RED (forecast) | acec1de6f1c53a04c | — |
| real app ids above 2^63 (manifest+1, `app_n*100` wrap, grain.rs:1634, grain_agent_route.rs:262, controlGroupBound) | mostly fixed | acec1de6f1c53a04c | bd9318540 |
| apps worker served one member at a time; install inline | FIXED, on main | ab368e520ce312b3c | dd7de9faf |
| apps bootstrap birthStale on a world older than 64 ticks | push asked (coordinator: now) | acec1de6f1c53a04c | 6566216c8 / da5a51424. Row: `AGE=70 qrun.sh` |
| share-issue plan/submit window (a tick between plan and submit refuses) | hazard for busy rooms (not today's red) | B3 | statement on lane/un-share-window-statement |
| JPAY6 thin-birth | with the integrator | integrator / ad0906325ab57d1c3 | 98064edba |
| Hermes: resident route allowlist lacks ops 210-214 (await bridge, `bend deliver`) | FIXED, unmerged (after J14 run 5) | L4d | 6895a5dbe |
| Hermes: `bend deliver` heapUncovered on a resumed segment | FIXED, unmerged | L4d | e7475d739 |
| Hermes: strangers summon (ember ruled a house room) | FIXED, unmerged; J14 row `house` | L4d | 29af88045 |
| Hermes: provider purse refill; summon after dismiss | FIXED, unmerged; J14 row `resummon` | L4d | e376736a2 (refill payer to be confirmed on the demo genesis) |
| Hermes → Oracle | OFF for rehearsal #3, by ruling: tour step 8 uses the grain directly; Hermes says `oracle-not-configured` | L4d, after the rehearsal | — |
| door: world id across upgrade; a create the Host never took; failed story seal | FIXED, in build 327096423 | acf88647b53657831 | 6884e6043 |
| public "operations"/"welcome" squatting (first import wins) | FIXED, unmerged; row public-house-name-reserved | qualify | ed974a822 + infra f625792 (`welcome house` run-sheet line) |
| local-check seed-writable check silently passes on GNU find (`-perm +222`) | FIXED | qualify | lane/qualify c54f43c9c |
| docuverse cold audit in supplied-store mode | honest `not-run` marker (its test asserts not-run); the Store restart is covered by composed store-restart | — | — |
| grain-route latency about 5 s Host CPU per turn: TextEditor, Wekan, WBO writes red; 503 busy for multi-request apps | RED | perf lane / perf-rake ae523f43aa7bfc923 | 41d87f720, 430e0fe81 (partial; in 327096423) |
| demo market installs EtherCalc 2020.12.28.1 (index 9b3b7615…, 36.9 MB); composed and qualification use 93bd2c29… (11.98 MB) | DIVERGENCE | deputy a308118209b4a48ea | — |
| /var/lib/mini-spk-worlds holds 123 GB of root-owned grain worlds from past composed and lane runs (28 stores; composed-inputs' root setup is never removed at world down) | LEAK (root fs 71 GB free) | integrator / infra | `install-user-world remove` at world down |

## 4. Every refusal names its clause

- Rust and harness: done and on main (4241cf11a, merged with the worker-concurrency change). The
  operator log now gets the reason on every demo-path refusal.
- Lean (Host/Main.lean, the f2deb6ede pattern): ops 46/76 and the lifetime grant are on lane/hermes-b
  38c456653 (L4d). op34, op22/26, op84, op105, op242, op246 and op189 are on lane/qualify-lean-refusals
  (in progress; elaboration on dregg-ref).

## Rulings owed (statement-first; no proof started)

- **CommutingAppend** (kernel): a `.content` command whose actions are all `createAtom` admits at
  any signed root if it admits at `pre.root`. Teeth: any other action with `root ≠ pre.root` still
  refuses `staleTarget`; a replayed atom id is refused by `allocate`. It conflicts with
  `ContentAgreement` clause 3 (Effects revival lane). Closes appender starvation in a busy room.
- **decideCertifyPrefix** (kernel): certify any height `h` with `certified < h ≤ head` and
  `chainAt h = some d`. Needs a durable chain-at-height lookup. Closes certify starvation under
  writes.

## Open items of the qualification lane

- Composed rerun on a warm or snapshot world (composed-inputs refuses an existing grain world and
  reuses ids 930001/960001).
- `scripts/pipeline/lane-check` should refuse to run when its caller already holds closure-lock.
