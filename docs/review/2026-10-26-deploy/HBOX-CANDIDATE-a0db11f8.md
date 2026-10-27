# hbox candidate a0db11f8: build, journey rows, jdeploy3

2026-10-26, hbox, by a Claude build lane. Nothing shipped; dregg-workhorse, dregg-anchor and persvati were not contacted.
Workspace: `/tank/dregg-build/claude-candidate-20261026/`, with every command and its wall time in `COMMANDS.log`.

## What was built

- **Commit:** `a0db11f8a8bcbc99b5a35ced44f46ab9717ee51d` (GitHub main). Fetched into the shared git
  `/tank/dregg-build/claude-lanes/bundles/burst3-minidregg.git` as `refs/remotes/github/main`.
- **Warm base:** `334316df5653a846ed5d6069bbfb282bc4d5fcf6` (FROZEN 2026-10-17, READY). It is 4 commits behind main.
  The only `.lean` change between them is `docs/evidence/2026-09-27-r3-completion-diagnostic/ProbeCompletionAdmission.lean`,
  which is outside the umbrella. The base was not advanced.
- **Lane:** `/tank/dregg-build/pipeline/lanes/cand-20261026`, made by `warm-base/src/scripts/pipeline/mk-lane.sh cand-20261026`
  (260 s). Then `git fetch shared` and `git checkout -B main a0db11f8`.
- **Umbrella replay at a0db11f8:** `with-lean-slot swarm-build lake build Minidregg Fixtures ObjectiveProofs +Host.Main:leanArts +Host.ClientConsentSession:leanArts`
  with SWARM_MEM_MAX=48G. It took **870 s**, all of it trace replay: 9817 jobs, **0 modules compiled**, no slot wait, scope memory peak 2.1G.
  rc=1, and the only failure was `Fixtures.NativeAcceptedFixture`. `known-red-verdict` says
  `READY (1 known-red carried)` (cv 01a146dd-4f9d).

### Stage wall times (each stage ran under swarm-build, detached, with a PID file)

| stage | command | wall | scope memory peak | notes |
|---|---|---|---|---|
| host | `with-lean-slot swarm-build lane-build.sh host` (48G, MINIDREGG_NATIVE_JOBS=6, Lean seats 2 x threads 2) | **454 s** (builder elapsed 448 s) | 1.3G | closure **787 source modules** + 2937 package modules, 3724 objects. `lean-closure 787 modules PASS 2s`: **0 Lean modules compiled** (warm replay), so lean-rss is empty (p95 = max = 0). The ~446 s is the C compile of all 787 project objects at 6 jobs, plus the link. binary sha256 `e2f5da1e…` |
| consent | `lane-build.sh consent` (48G) | **130 s** (elapsed 123 s) | 1.2G | companion: reused 679 modules, compiled 13 here (Lean replay, 5 s); 692 source modules. sha256 `1ce33842…` |
| rust | `lane-build.sh rust` (24G, cargo -j4, --offline --locked) | **364 s** | 2.2G | 16 binaries; resource-client/mini was the longest at 163 s |
| pack | `lane-build.sh pack C` (16G) | **12 s** | 153M | clean tree; compiled inputs identical to both build commits; no refusal |
| **total build** | host + consent + rust + pack | **960 s (16 min)** | | + 260 s mk-lane + 870 s umbrella replay = **35 min from fetch to candidate** |

**What these numbers measure.** The Lean half was warm in every stage. No Lean module of the 787-module closure was
compiled, so this is **not** the cold Lean number the brief asked about. That number still has no measurement. It needs
a build with no warm base, or a base whose Host-closure oleans are stale. The 454 s host figure is the cost of the
**C object compile + link of the full 787-module closure at 6 C jobs**, with the Lean half free.

## The candidate (`/tank/dregg-build/claude-candidate-20261026/C`, 228M)

- `provenance.json .source.commit` = a0db11f8…, origin `lane-build`. `SHA256SUMS` sha256 `adfbfe56428f997bd89de2d142ce7ed5a6c688e1ca2d640f70a74b5c322913d0`.
- `manifest.json .type` = `minidregg-candidate-manifest-v2`.
- `jq '.binaries|keys' provenance.json`: consent, discord, grainProviderBridge, grainRuntime, host, inferenceScheduler,
  keys, launchGate, mini, payWatcher, spkBroker, spkBrowserProxy, spkHost, spkHostd, spkVolumeHelper, store, testProvider, verifier (18).
- `.abi.glibcRequired` = **2.39**. Per binary: host and consent need 2.17; inferenceScheduler, spkHostd, testProvider and verifier 2.34;
  spkBrowserProxy 2.38; all others 2.39.
- No cross-compiled darwin client: lane-build does not build `MINI_CLIENT_TARGETS`.
- I added `C/READY` (a timestamp; it is not in SHA256SUMS) so that the journey runner accepts C as a set. jdeploy3 wrote `C/gate/`.

## Journey rows (standing-run set, PIPELINE_JOURNEY_JOBS=4)

**How it was run.** The run used the lane tree's own `journey-runner --tip a0db11f8`, against a **private**
PIPELINE_ROOT `/tank/dregg-build/claude-candidate-20261026/proot`. Its box.env is a copy of the real one with
`ARTIFACT_ROOT`/`JOURNEY_ROOT` set to `…/claude-candidate-20261026/{artifacts,journeys}`. The private artifact root
holds C as `a0db11f8…` and read-only symlinks to the box's six real READY sets, plus a `main` label pointing at
334316df, so the m7 and hostupgrade lookups behave as they would in the standing run. Nothing was written to the
shared `artifacts/` or `journeys/`. The runner's self-check passed (it was the tree's own runner). The rows ran from
an extract of `C/source.tar` at `/run/user/1000/pjs.*`, because there is no `.trees` dispatch record. Wall: **904 s**,
against main 334316df's 1819 s on 2026-10-17.

**Counts (147 lines, the same ids as main's baseline): PASS=136, FAIL=2, UNCONFIGURED=6, UNJUDGED=3, UNBUILT=0 (no ABSENT).**

Compared with main 334316df's hbox baseline (PASS=137 FAIL=2 UNCONFIGURED=5 UNJUDGED=3), exactly one line differs:
`m6grain PASS → UNCONFIGURED`. **That line is an artifact of how I ran the rows, not a red in the candidate.** The
sudoers rule lets `mini-operator` run `install-user-world` only from
`/tank/dregg-build/pipeline/journeys/.trees/*/…` or `/tank/dregg-build/claude-lanes/*/src/…`. My run extracted to
`/run/user/1000/pjs.xZANcV`, so the row reported `missing input: sudoers rule … /run/user/1000/pjs.xZANcV/deploy/spk-host/install-user-world`
and never ran. m6grain is **unexercised** for this candidate. Exercising it means running from a tree on one of
those two paths, which this lane was not allowed to create.

### Landing-rule verdict

This is landing.sh's own judge (the python in `judge()`, extracted verbatim). It was run against the baseline tree's
required-rows (`journeys/.trees/334316df…`, byte-identical to a0db11f8's), the box's `absent-inputs.tsv` and main's
results.tsv. The `RUN-TREE`/`SELF-CHECK` preamble does not apply, because this was not a service dispatch.

```
new reds vs baseline: 1
NEW RED   m6grain UNCONFIGURED (PASS at main's baseline)
declared  hostupgrade UNCONFIGURED: the pinned old-epoch EF set e0a8ba21 existed only on burst3 (torn down 10-10); hbox has no READY copy. Supply: publish-artifacts e0a8ba21 on hbox (HOSTUPGRADE_EF_SET / ARTIFACT_ROOT).
pending   births (when green at main; main's baseline: births/create UNJUDGED, births/resource UNJUDGED, births/reopen UNJUDGED, births UNCONFIGURED; candidate: births/create UNJUDGED, births/resource UNJUDGED, births/reopen UNJUDGED, births UNCONFIGURED)
  not yet  births/create UNJUDGED: births/create n=64 p50 1629 p99 3647 max 3647 ms; bar p99 <= 5000 ms
  not yet  births/resource UNJUDGED: births/resource n=64 p50 2461 p99 5317 max 5317 ms; bar p99 <= 5000 ms
  not yet  births/reopen UNJUDGED: reopen/to-first-read n=1 p50 6381 p99 6381 max 6381 ms; bar max <= 60000 ms
  not yet  births UNCONFIGURED: births UNCONFIGURED: bar not judged: loadavg 20.35->16.02 (quiet: no other unit >= 0.5 cores; busy) | verdict it would have had: rc 1; 
pending   HERMES-LIVE real inference + BYOK; needs Ember's providers.json (MATURATION-MAP 2.6)
pending   jcertify certifier unit; 320 records PASS on dregg-infra edge/mini-certify (MATURATION-MAP 1)
NOT MET   m6grain UNCONFIGURED: missing input: sudoers rule mini-operator ALL=(root) NOPASSWD: /run/user/1000/pjs.xZANcV/deploy/spk-host/install-user-world
PRE-RED   m7 UNCONFIGURED (non-PASS at main's baseline too: UNCONFIGURED; cv 01a14736-31a4): missing input: M7_REFERENCE (file)
PRE-RED   jpay/JPAY6 FAIL (non-PASS at main's baseline too: FAIL; cv 01a13c42-dc55): JPAY6 driver exit 66: journey: a socket outgrew its declared row in journey.d/lib/shortdir.sh (70 bytes): /run/user/1000/jm.TI5c4r/jpay6/consent-anchors/r-ed4c31e28bd09e930381bd0cfed26a41.sock 
PRE-RED   jpay FAIL (non-PASS at main's baseline too: FAIL; cv 01a13c42-dc55): JPAY1-4 and JPAY6: JPAY1 PASS;JPAY2 PASS;JPAY3 PASS;JPAY4 PASS;JPAY6 FAIL;
required unmet: ['m6grain', 'm7', 'jpay/JPAY6', 'jpay'] (of which pre-existing at main: ['m7 (cv 01a14736-31a4)', 'jpay/JPAY6 (cv 01a13c42-dc55)', 'jpay (cv 01a13c42-dc55)'])
REQUIRED: 40 ids; new reds vs baseline: 1; blocking: 1 -> NOT landable
```

Reading it: the **known-red rows are unchanged**. jpay/JPAY6 and jpay fail as at main: the JPAY6 consent-anchor socket
path outgrows `shortdir.sh`'s 70-byte row (cv 01a13c42-dc55). m7 has no reference, because no other READY set has these
compiled inputs (cv 01a14736-31a4). hostupgrade is declared absent. With m6grain set aside as a harness artifact,
**there are no new reds vs main**. births is still pending: UNJUDGED under loadavg 20→16. The detail says the verdict it
*would* have had is rc 1, from births/resource p99 5317 ms > 5000 ms on a loaded box. Main's baseline had p99 2589 ms
at loadavg 4. perf is UNCONFIGURED (box not quiet), as at main. jserve PASS.

The Lean known-red verdict for the umbrella is `READY (1 known-red carried: Fixtures.NativeAcceptedFixture, cv 01a146dd-4f9d)`.

### Table (verbatim, `journeys/a0db11f8…/table.txt`, cut at 220 columns)

```
tip a0db11f8a8bcbc99b5a35ced44f46ab9717ee51d  labels: 
journey wall 904 s on hbox (24 CPUs), finished 2026-10-26T21:58:08Z; set built 

ROW                                          STATUS        WALL_S   OWNER        DETAIL
journey/J0                                   PASS          2.814    unknown      service up and a signed read answered in 2.765s
journey/J1                                   PASS          1.884    unknown      subject 15286043737346236665, record 1; key absent from genesis/config; lookup = same receipt
journey/J2                                   PASS          1.232    unknown      object 12482761887287595686 under all[], record 2
journey/J3                                   PASS          1.685    unknown      child 11396961033102926339 verbs observe,mutate, record 3
journey/J4                                   PASS          2.856    unknown      read 0.810s, write 1.185s, readback field 2 = 1, record 4
journey/J5                                   PASS          6.005    unknown      8/8 refused: 4 by the Host (enrolled no-grant read x2, propose, crafted submit), 2 by local consent before signing (unenrolled read, submit
journey/J6                                   PASS          2.271    unknown      reopen to first signed read 1.082s; J1 receipt and field 2 = 1 recovered; retry replayed tx with its original (root, height); read (root, h
journey/J7                                   PASS          4.311    unknown      law v1 not(any[]) installed (submit 0.800s); J3 grant wrote 1->7 (submit 0.798s). The new law is still permit-all
journey/J8                                   PASS          3.126    unknown      deny-all installed (submit 0.760s); 5/5 refused: newcomer read/propose/crafted, sponsor read, sponsor repair propose; prior call replays
journey/JROT                                 PASS          60.990   unknown      JROT: 34/34 checks; friend subject 10537333970510713073 rotated 1->2->3; thief refused (?); plain subject notPrerotated; audit: links []
journey/JROTL                                PASS          8.318    unknown      JROTL: 10/10 checks; a lost op-142 reply recovered by op-143 lookup (epoch 2, one submit); a never-seen rotation looks up absent and is nev
journey/JRLANE                               PASS          144.503  unknown      JRLANE: 14/14 checks; A=12459749145737526447 closed after 254 authenticated refusals; 1500 wrongly signed cost nothing; B=94061092248687463
journey/JGATE                                PASS          23.970   unknown      JGATE 12/12 (24 s)
journey/JAUDIT                               PASS          74.418   unknown      JAUDIT: 5/5 checks; store audit: 38 records; chain, tags, accumulator (73 nodes), index (76 keys, 18; planted height 19 refused: store audi
journey                                      PASS          344      unknown      frontier END
objective                                    UNCONFIGURED  1        unknown      no lean env for this tip (its mutations run lake env lean)
rooms                                        PASS          574      unknown       229 rows, 0 red, 93/93 expected rows present and ok
activity                                     PASS          164      unknown      objective-activity-native-acceptance.py: {"rows": 311, "failed": []}
seats                                        PASS          57       unknown      objective-seat-native-acceptance.py: 91/91 rows ok; results in /run/user/1000/pj.DxNSYL/s/results.json
bounty                                       PASS          178      unknown      objective-bounty-native-acceptance.py: 190/190 rows ok; results in /run/user/1000/pj.SEIsG2/b/results.json
call/C1-leaf                                 PASS          0        unknown      4 rows ok
call/C2-chain                                PASS          0        unknown      4 rows ok
call/C3-sequence                             PASS          0        unknown      3 rows ok
call/C11-front-end-meter                     PASS          2        unknown      5 rows ok
call/C4-reentry                              PASS          0        unknown      4 rows ok
call/C5-dao                                  PASS          0        unknown      4 rows ok
call/C6-authority                            PASS          1        unknown      8 rows ok
call/C7-facet                                PASS          0        unknown      3 rows ok
call/C9-grant-args                           PASS          1        unknown      8 rows ok
call/C10-grant-who                           PASS          1        unknown      5 rows ok
call/C8-shape                                PASS          1        unknown      5 rows ok
call                                         PASS          32       unknown      {"rows": 63, "failed": []}
send/S1-send                                 PASS          1        unknown      6 rows ok
send/S2-deliver                              PASS          1        unknown      8 rows ok
send/S3-full                                 PASS          6        unknown      11 rows ok
send/S4-failed                               PASS          1        unknown      6 rows ok
send/S5-forward                              PASS          2        unknown      10 rows ok
send/S6-broken                               PASS          2        unknown      10 rows ok
send/S7-shape                                PASS          1        unknown      4 rows ok
send/S8-interface                            PASS          3        unknown      7 rows ok
send/S9-resolved                             PASS          1        unknown      8 rows ok
send/S10-cancel                              PASS          5        unknown      20 rows ok
send/S11-pole                                PASS          2        unknown      8 rows ok
send/S12-stop                                PASS          2        unknown      13 rows ok
send/S13-who                                 PASS          4        unknown      10 rows ok
send/S14-continue                            PASS          2        unknown      8 rows ok
send/S15-exceed                              PASS          2        unknown      9 rows ok
send/S16-fanout                              PASS          2        unknown      6 rows ok
send/S17-depth                               PASS          4        unknown      8 rows ok
send/S18-cancel                              PASS          2        unknown      5 rows ok
send/S19-retry                               PASS          1        unknown      9 rows ok
send/S20-same-op-other-call                  PASS          1        unknown      5 rows ok
send/S21-forged-retry                        PASS          0        unknown      5 rows ok
send/S22-retry-outcome-altered               PASS          0        unknown      5 rows ok
send                                         PASS          77       unknown      {"rows": 192, "failed": []}
domain/D1-joint                              PASS          3        unknown      10 rows ok
domain/D2-register                           PASS          1        unknown      7 rows ok
domain/D3-stale                              PASS          2        unknown      6 rows ok
domain/D4-bank                               PASS          3        unknown      8 rows ok
domain/D5-keep                               PASS          1        unknown      4 rows ok
domain/D6-priced                             PASS          3        unknown      8 rows ok
domain                                       PASS          49       unknown      {"rows": 58, "failed": []}
upgrade/U1-adopt                             PASS          0        unknown      4 rows ok
upgrade/U2-drain                             PASS          2        unknown      8 rows ok
upgrade/U3-abort                             PASS          4        unknown      12 rows ok
upgrade/U4-migrate                           PASS          0        unknown      3 rows ok
upgrade/U5-rebirth                           PASS          1        unknown      3 rows ok
upgrade                                      PASS          22       unknown      {"rows": 38, "failed": []}
hostupgrade                                  UNCONFIGURED  1        prod-hostup  missing hostupgrade candidate input: /tank/dregg-build/claude-candidate-20261026/artifacts/e0a8ba21a39d92b470cc331fd16ea0408f608b1f
objectrecord/OR1-no-record                   PASS          0        unknown      2 rows ok
objectrecord/OR2-create                      PASS          1        unknown      7 rows ok
objectrecord/OR3-write-law                   PASS          0        unknown      3 rows ok
objectrecord/OR4-birth-law                   PASS          2        unknown      6 rows ok
objectrecord/OR5-resume-view-law             PASS          2        unknown      7 rows ok
objectrecord/OR6-delivery-principal          PASS          4        unknown      11 rows ok
objectrecord/OR7-conservation                PASS          0        unknown      1 rows ok
objectrecord                                 PASS          25       unknown      {"rows": 39, "failed": []}
welcomecontinuity/sponsor-key                PASS          0        unknown      PASS
welcomecontinuity/clock-key                  PASS          0        unknown      PASS
welcomecontinuity/genesis                    PASS          0        unknown      PASS
welcomecontinuity/bootstrap                  PASS          0        unknown      PASS
welcomecontinuity/sponsor-workspace          PASS          0        unknown      PASS
welcomecontinuity/factory-import             PASS          0        unknown      PASS
welcomecontinuity/participant-key            PASS          0        unknown      PASS
welcomecontinuity/enrollment-plan            PASS          0        unknown      PASS
welcomecontinuity/sponsor-offer              PASS          0        unknown      PASS
welcomecontinuity/participant-possession     PASS          0        unknown      PASS
welcomecontinuity/enrollment-seal            PASS          0        unknown      PASS
welcomecontinuity/absent-lookup              PASS          0        unknown      PASS(refused)
welcomecontinuity/enrollment-submit          PASS          0        unknown      PASS
welcomecontinuity/intervening-resource       PASS          0        unknown      PASS
welcomecontinuity/sponsor-welcome            PASS          0        unknown      PASS
welcomecontinuity/unresolved-lookup          PASS          0        unknown      PASS(refused)
welcomecontinuity/refused-lookup             PASS          0        unknown      PASS(refused)
welcomecontinuity/forged-receipt             PASS          0        unknown      PASS(refused)
welcomecontinuity/assemble-wrong-possession  PASS          0        unknown      PASS
welcomecontinuity/wrong-possession           PASS          0        unknown      PASS(refused)
welcomecontinuity/other-key                  PASS          0        unknown      PASS
welcomecontinuity/other-plan                 PASS          0        unknown      PASS
welcomecontinuity/assemble-wrong-command     PASS          0        unknown      PASS
welcomecontinuity/wrong-command              PASS          0        unknown      PASS(refused)
welcomecontinuity/interrupted-baseline       PASS          0        unknown      PASS(refused)
welcomecontinuity/resume-baseline            PASS          0        unknown      PASS
welcomecontinuity/missing-verifier           PASS          0        unknown      PASS(refused)
welcomecontinuity/authenticated-welcome      PASS          0        unknown      PASS
welcomecontinuity/repeated-welcome           PASS          0        unknown      PASS
welcomecontinuity/lost-custody               PASS          0        unknown      PASS(refused)
welcomecontinuity/lost-whole-workspace       PASS          0        unknown      PASS(refused)
welcomecontinuity                            PASS          23       unknown      genesis-params: params.sh from the candidate: /tank/dregg-build/claude-candidate-20261026/artifacts/a0db11f8a8bcbc99b5a35ced44f46ab9717ee51
sshe2e                                       PASS          71       unknown      ssh-e2e: PASS (4 publickey logins accepted by sshd; evidence in /run/user/1000/pj.SzTHLS/ssh/log)
m3                                           PASS          21       unknown      provisioning and cold reopen completed
m4                                           PASS          69       unknown      shell J0-J8 over ssh completed
hermes                                       PASS          213      unknown      deterministic Hermes restart, recovery and delegation completed
m6grain                                      UNCONFIGURED  2        prod-spk     missing input: sudoers rule mini-operator ALL=(root) NOPASSWD: /run/user/1000/pjs.xZANcV/deploy/spk-host/install-user-world
m7                                           UNCONFIGURED  1        unknown      missing input: M7_REFERENCE (file)
m8                                           PASS          24       unknown      m8 completed with verified summary
fleetsign                                    PASS          146      unknown      fleetsign completed with verified summary
jpay/JPAY1                                   PASS          1        unknown      J-PAY-1 PASS 15/15 
jpay/JPAY2                                   PASS          294      unknown      J-PAY-2 PASS 18/18 (291.4 s) 
jpay/JPAY3                                   PASS          16       unknown      J-PAY-3 PASS 24/24 (15.0 s) 
jpay/JPAY4                                   PASS          25       unknown      J-PAY-4 PASS 25/25 (25.2 s) 
jpay/JPAY6                                   FAIL          2        unknown      JPAY6 driver exit 66: journey: a socket outgrew its declared row in journey.d/lib/shortdir.sh (70 bytes): /run/user/1000/jm.TI5c4r/jpay6/co
jpay                                         FAIL          339      unknown      JPAY1-4 and JPAY6: JPAY1 PASS;JPAY2 PASS;JPAY3 PASS;JPAY4 PASS;JPAY6 FAIL;
exchange                                     PASS          50       unknown      exchange PASS: local fn stopped; exact selected packet admitted and signed readback verified
chargedfailure/fees                          PASS          1        unknown      3 rows ok
chargedfailure/charged                       PASS          0        unknown      3 rows ok
chargedfailure/charged-replay                PASS          1        unknown      5 rows ok
chargedfailure/outcome-moved                 PASS          0        unknown      4 rows ok
chargedfailure/malformed                     PASS          0        unknown      2 rows ok
chargedfailure/forged                        PASS          1        unknown      3 rows ok
chargedfailure/unfunded                      PASS          0        unknown      2 rows ok
chargedfailure/cost                          PASS          6        unknown      11 rows ok
chargedfailure                               PASS          33       unknown      
births/create                                UNJUDGED      301.28   unknown      births/create n=64 p50 1629 p99 3647 max 3647 ms; bar p99 <= 5000 ms
births/resource                              UNJUDGED      301.28   unknown      births/resource n=64 p50 2461 p99 5317 max 5317 ms; bar p99 <= 5000 ms
births/reopen                                UNJUDGED      6.63     unknown      reopen/to-first-read n=1 p50 6381 p99 6381 max 6381 ms; bar max <= 60000 ms
births                                       UNCONFIGURED  330      unknown      births UNCONFIGURED: bar not judged: loadavg 20.35->16.02 (quiet: no other unit >= 0.5 cores; busy) | verdict it would have had: rc 1; 
jserve                                       PASS          71       unknown      JSERVE completed: 12/12 serve rows: no hostile client stalled the honest read or stopped the service
perf/perf-genesis                            PASS          3.24     unknown      bring-up n=1 p50=3241ms max=3241ms
perf/perf-setup                              PASS          9.03     unknown      resource n=4 p50=1194ms max=1425ms; publication n=2 p50=137ms max=265ms; publish n=2 p50=921ms max=1087ms; create n=4 p50=381ms max=814ms
perf/perf-births                             PASS          50.90    unknown      resource n=20 p50=1541ms max=1916ms; create n=20 p50=909ms max=1335ms
perf/perf-updates                            PASS          8.30     unknown      invoke n=16 p50=488ms max=690ms
perf/perf-reads                              PASS          2.81     unknown      read-current n=8 p50=15ms max=16ms; read-at n=8 p50=261ms max=337ms
perf/perf-checkpoint                         PASS          0.61     unknown      certify n=1 p50=613ms max=613ms
perf/perf-judgment                           PASS          2.04     unknown      call-granted n=1 p50=723ms max=723ms; send n=1 p50=760ms max=760ms; deliver n=1 p50=531ms max=531ms
perf/perf-reopen                             PASS          1.32     unknown      stop n=1 p50=50ms max=50ms; to-first-read n=1 p50=1221ms max=1221ms; read-current n=1 p50=11ms max=11ms
perf                                         UNCONFIGURED  83       unknown      perf UNCONFIGURED: bar not judged: loadavg 21.00->15.95 (box not quiet: run-u59725.scope 4.45 cores (/home/hbox/.elan/toolchains/leanprover
```

## Deploy gate: jdeploy3 (dregg-infra 8d7d6c9)

`SWARM_MEM_MAX=16G swarm-build edge/mini/journey/jdeploy3.sh C …/gate 5` ran from a clone of `/srv/git/dregg-infra.git`
at `…/claude-candidate-20261026/dregg-infra`. Wall **4809 s (80 min)**; exit 1.
Result: `C/gate/jdeploy3-result.json` (copy at `gate/jdeploy3-result.json`), bound to SHA256SUMS `adfbfe56…`.

**Verdict: J-DEPLOY3 FAIL (journey FAIL, composed FAIL).**

| phase | verdict | reason |
|---|---|---|
| J0 | PASS | service up, signed read answered in 4.3 s |
| J1 | PASS | subject created, record 1; lookup returns the same receipt |
| J2 | PASS | object under all[], record 2 |
| J3 | PASS | child with observe,mutate, record 3 |
| J12X | PASS | 20/20 malformed rows refused by name; killed Host restarted under the same socket |
| J4 | PASS | read 0.68 s, write 1.14 s, readback field 2 = 1 |
| J5 | PASS | 8/8 refused (4 by the Host, 2 by local consent, …) |
| J6 | PASS | reopen to first signed read 0.83 s; receipts recovered; replay is idempotent |
| **G** | **FAIL** | over the bar (write **max** ≤ 5 s, reopen ≤ 60 s) at every level. At 10: max 6.08 s. At 100: p99 21.7 s, max 30.3 s. At 500: p99 10.6 s, max 30.3 s. At 1000: p50 4.27 s, p99 12.3 s, **max 57.3 s**; cold reopen 11.8 s (within the bar). Loadavg during the levels was 7 to 16 (co-tenant nanodregg lean + codex poly) |
| J7 | PASS | law v1 installed; the J3 grant still writes |
| J8 | PASS | deny-all installed; 5/5 refused; the prior call replays |
| **composed** | **FAIL (never ran)** | `scratch world: jworld FAIL init run.sh: manifest must be minidregg-candidate-manifest-v2; repackage the candidate` |

**The composed scenario did not start.** rooms, churn, documents, apps, connector, residents and restart all **went
unexercised**, so the deploy report's prediction (documents/apps/connector/residents red) is **neither confirmed nor
refuted**. The cause is an **interface break between the two repos**, not a defect in this candidate:

- `jworld-scratch.sh` publishes the candidate "as ship.sh --on-box does". It overwrites the published `manifest.json`
  with dregg-infra `edge/mini/lib.sh` `candidate_manifest()`, and that function emits a **typeless v1 role map**
  (`{candidate, consent, …, sha256}`, no `.type`, no `outputs`).
- Mini's `deploy/candidate/lib.sh:37` (since 295cab11, 2026-10-08, "M7: reproduce the complete candidate and refuse
  tampered executables") makes `run.sh init` refuse anything other than `minidregg-candidate-manifest-v2`.
- `ship.sh:185` calls the same `candidate_manifest`. **A real `ship.sh` of any v2 candidate would therefore fail at
  `run.sh init` the same way.** The fix belongs in dregg-infra: keep the candidate's own v2 manifest, or emit v2 with
  its `outputs`. The Mini side should stay as it is.

G is a real measurement on a loaded co-tenant box. The same updates bar flipped PASS/FAIL with box load in
FOLLIES-20261014 F1. Here it failed at the 10-record level, before any growth, and the worst single write at 1000 was 57 s.

## Disk

`/tank` free went from 261G at the start to 253G at the end. That 8G includes co-tenant writes. What this lane
wrote: `claude-candidate-20261026/` is 782M (C 228M, gate 684M apparent, dregg-infra 9M). The lane is 6.8G by du,
mostly `src/` at 6.2G, much of it hard links into the warm base's `.lake`. Its other parts are rust-target 335M,
artifacts 173M and logs 54M. The free-space floor (60G) was never approached.

## Not finished / open

1. **The cold Lean build time of the 787-module closure is still unmeasured.** Every stage replayed Lean from the warm base.
2. **m6grain is unexercised** for this candidate (the sudoers path, above).
3. **The composed scenario is unexercised.** It is blocked by the dregg-infra `candidate_manifest` v1/v2 break, which also blocks `ship.sh`.
4. **Processes left running from jdeploy3's journey world**, orphaned and **without a PID file**, so I did not stop them:
   pid 2762880 `C/bin/mini consent-resident …` (ppid 1), its child 2762881 `minidregg-client-consent` (~320M RSS), and
   2762890 `minidregg-link-sqlite-store serve`. They keep the swarm-build scope `run-u59970.scope` "active running".
   The world's `public/server.pid` (3209913) is already dead. They need the operator's decision: stop them by
   PID or by `systemctl --user stop run-u59970.scope`.
5. Nothing was deleted. The lane `pipeline/lanes/cand-20261026`, `C`, `gate`, `proot`, `artifacts` (symlinks) and `journeys` all remain.

## Follow-ups, 2026-10-27 (the coordinator's rulings)

- **m6grain: PASS (1998 s).** `/etc/sudoers.d/mini-operator` now admits `/tank/dregg-build/pipeline/lanes/cand-20261026/src`
  in both `MINI_TWO_WORLD` and `MINI_WORLD_INSTALL`. The new file was checked with `visudo -cf`, installed root:root 0440,
  and `visudo -c` passes for the whole config. The change and its undo are in `pipeline/box-changes.md`; the old file is at
  `claude-candidate-20261026/mini-operator.sudoers.before-cand-20261026`. The row was run from the lane tree
  (`journey-runner --row m6grain --source-tree <lane>/src`).
- **Composed scenario, re-run on dregg-infra 5501f4f** (journey/growth skipped; `composed-only.sh` = jdeploy3 steps 0, 2, 3;
  473 s, world up in 150 s). rooms=pass. churn=pass. documents=stopped:
  `documents:shared:member-2:submit: rc 3`. The Host refused with "target … moved since the plan was signed (phase stale-target)":
  concurrent appends to the shared doc are not retried or merged (ruled a real product red; repair assigned to the web/docs lane).
  apps, connector, residents: not reached; and the spec has none of their inputs (they come from lanes L3/L4/L9). restart: not reached.
- **jcertify, first real run on the merged frame.** One change to the script: its hard-coded `/tmp` scratch moved to `/tank`.
  320 records, certified advanced 4 times, certifiedHeight 323. Then `mini-clock-tick` printed nothing and was killed at its
  120 s timeout, at box load about 30. Write median 9.3 s, max 390 s (HDD, under load; published, not judged).
- **exchange on lane/fn-fleet 3e2cd5ab: PASS (23 s)** in the row's default 24 GiB scope. An 8 GiB scope fails with
  "native worker reservation is not held", because the fn node is sized at 8192 MiB. Under a transient root `systemd-run`
  with the unit's full hardening, the unit's `Environment=SBCL_USER_ARGS=--dynamic-space-size 2048` gets split by systemd
  and SBCL dies with "--dynamic-space-size argument is not a number". With the value quoted, SBCL starts. Fix: quote that line.
- **SSD lane space:** `rpool/lanes` at `/othersys/lanes` (lz4; rpool has altroot=/othersys), recorded in box-changes.md.
- **M7 reference, built cold on dregg-build** (`/build/reference/a0db11f8`). The hbox attempt was stopped at 309/787 modules
  because box load of 55-87 made its timing meaningless. **Cold build: mathlib 81 s, Lean closure 787 modules 4726 s,
  native Host 5212 s, consent 436 s, Rust 195 s, total 5926 s (98.8 min); peak 19.3 GiB; lean-rss max 18.5 GiB
  (Kernel.PayEnrolReceiver).** `package.py` had to be re-run from a repo containing the commit, because it runs
  `git rev-parse COMMIT^{tree}` in its cwd. **Reproduction vs C:** Lean host and consent are byte-identical across the two
  boxes. All 19 Rust binaries differ, because the distro GCC crt objects differ (Debian 14.2.0-19 vs Ubuntu 14.2.0-4ubuntu2).
  The rustc and rust-lld are identical. **M7 would FAIL** with 1 of 4 core hashes reproducing (host), so the row was not run.
