# Integration 1 (2026-10-26/27): six lanes onto `integration/2026-10-26` at `55e483e0`

The first integration of the demo prefix (docs/DEMO-PREFIX-2026-10-26.md). Base: main `1f180a75`.
Branch: `integration/2026-10-26` (GitHub). Round 2, which moved the branch further, is
[INTEGRATION-2.md](INTEGRATION-2.md). This file records round 1 only: the tip `55e483e0`, its checks,
and its candidate and rows on hbox.

## Merge order (each a real merge commit with a prose message)

| # | merge | lane tip | one line |
|---|---|---|---|
| 1 | `74a6b7f7` | lane/build `d74947d2` (contains lane/web `15456188`) | L9 workspace gate, journey split, `--capsule` and 9,348 dead lines deleted; L7 render repairs, `--read-only`, `--render-static`, deploy/web, templates in the crate |
| 2 | `f2d5e66f` | lane/custody `03977b8f` | L2 refusal semantics, `mini_sdk::flow` as the one signing path, registry consent plans + markers, deletions |
| 3 | `7cd7f423` | lane/fn-fleet `3e2cd5ab` | L8 fn ACK ops 13/15 operator-only, deploy/fn unit, repost rule; fn-e path, publisher, drain deleted |
| 4 | `9f36ebea` | lane/custody `68e721ad` (final) | L2 dead branches, custody.ts alignment |
| 5 | `5909de55` | lane/door `be1921a2` | L5 self-serve door, PAY and Discord repairs, docs, join page |
| 6 | `b21e48b2` | lane/keys-store `00d68477` | L6 mini-keys public shape, SQ repairs, verify-mldsa/fips204/default_box deleted |
| 7 | `55e483e0` | lane/fence `f12cb942` | L3 per-call dispatch fence, STOP by lookup, sandbox floor, deletions |

Custody went in twice, because L2 kept pushing after the first merge (03977b8f, then 68e721ad). The second
merge applied cleanly on top of fn-fleet.

## Conflicts and how they were resolved

The rule throughout: read both lanes' intent and keep both when they do not contradict; when two lanes
deleted different parts of one region, the result is the union of the deletions.

- **native/resource-client/journey.sh** (L9 x L2): L9 moved STEPS into the demo/kernel partition; L2
  deleted the KCHR/KCHC steps (traffic stack 3). Kept L9's partition and dropped KCHR/KCHC from STEPS and
  KERNEL_STEPS (`--list-set demo` checks the partition and passes).
- **native/resource-client/src/main.rs** (L2 x L8): L2 deleted relay/channel and the host-command and
  selected-release-retry arms; L8 deleted publisher, the fn-e consumer/origin-outbox/fn-namespace/frontier
  arms, and folded `retry_with_upgrade` into `retry` (drain.rs gone). Union of the deletions; L8's `retry`
  is the one retry. The base-to-ours diff of every hunk was checked to contain deletions only.
- **native/resource-client/README.md** (L2 x L8): L2's `selected_release::recover` paragraph and L8's fn
  transport paragraph; the fn-e documentation that only L2's side still carried is dropped.
- **native/resource-client/src/key_service.rs** (L2, L8, L5): three lanes each gated the same Linux-only
  test. One `cfg` attribute kept.
- **protocol/host-operations.json / native/host-operations.rs**: auto-merged. L2's `consent_plans` (31)
  and response markers survive beside L8's `routes: ["operator"]` for ops 13 and 15. `generate` is a
  no-op; `check` and `test-host-operations.py` pass after every merge.
- **deploy/candidate/package.py** (L9, L5, L3): L9's FIXTURES split (testProvider is a fixture, not a
  role) + L5's door/doorProcess/discordMirror roles − spkHostd (L3 deleted the binary). INTERFACES.md's
  output table loses spk-hostd too.
- **deploy/candidate/lib.sh** (L9 x L3): L9's six required roles (L3 had edited the old list of fifteen).
- **website/join.html** (L7 x L5): L5's lede with the door link and its world-readable note (the D8
  sentence), L5's steps and "What to expect"; L7's reading-needs-no-account paragraph and its
  publish-to-the-public-reader step kept beside them. **website/SOURCES.md** likewise, with the D8 citation.
- **deploy/discord/README.md**: L5's rewrite whole (L9's one edit is already its text).
- **native/hyperdocument-link-sqlite-store/tests/lifecycle.rs** (L9 x L6): both additions.
- **deploy/spk-host/README.md** (L9 x L3): L3's rewrite. Its ingest sentence said "no network"; the
  committed spk-ingest (`systemd-run --user`, NoNewPrivileges and resource caps only) is not network- or
  filesystem-confined, as L9's edit had said. The sentence was corrected to the code.

The codex session's oracle crates (`native/oracle-appliance`, `native/spk-package-stream`) are on main
(19c1c63f) and are workspace members here. None of the main worktree's uncommitted files are on this branch.

## Checks, Mac (55e483e0)

- `cargo check --workspace` excluding the Linux-only targets (launch-gate: libc pidfd/prctl; spk-host
  bins: cfg(linux) modules; grain-runtime bin: journal_io's i32/u64 on Darwin), plus the spk-host and
  grain-runtime libs: green after every merge.
- `scripts/host-operations.py check`, `scripts/test-host-operations.py`: OK after every merge.
- `scripts/check-workspace.sh` with `WORKSPACE_GATE_MEMBERSHIP_ONLY=1`: 7 planted faults refused; 21
  packages, 20 members, 1 excluded with a reason; root lock current.
- Filtered tests on the four client crates: L2 wire-byte control 2/2; L7 `web|render|shared_name` 93/93; L5
  `door|pay|discord` 68/68; L6 mini-keys 41/41, SQ 36/36. L2 `custody|flow|retry` 53/58: the 5 reds
  are `async_dispatch` x2, `receipt_continuity` x2 and `workspace::legacy_carry...`, all on L2's list of
  pre-existing Mac failures. L8 `fn|selected|transport` 83/88: the 2 `async_dispatch` reds above, and 3
  `transport::tests` that fail only on Darwin (`path must be shorter than SUN_LEN`, and `setsockopt`
  EINVAL); on Linux all 92 pass.
- `jdoor.sh --dry`: J-DOOR PASS 8/8. `deploy/candidate/test-package.py` (llvm-readelf as readelf): 2
  FAILED, consentHost pin and consent output resolution, the same 2 L9 reported failing identically on main.

## Checks, hbox (Linux; lane `integ-20261026` from the warm base 334316df)

Workspace `/tank/dregg-build/claude-integration-20261026/`, every command and its wall time in its
`COMMANDS.log`; every build under `swarm-build`, every detached job with a PID file.

- mk-lane: 1,111 s (260 s at the previous candidate; load 35, other lanes unsharing hardlinks on /tank).
- Umbrella replay (`with-lean-slot swarm-build lake build Minidregg Fixtures ObjectiveProofs
  +Host.Main:leanArts +Host.ClientConsentSession:leanArts`, 48G): 4,582 s at load 60-75. rc=1;
  `known-red-verdict`: **READY (1 known-red carried: Fixtures.NativeAcceptedFixture)**. The Lean closure builds.
- `lane-build.sh host` 1,128 s (0 Lean modules compiled: warm), `consent` 175 s, `rust` 1,151 s, `pack` 26 s.
- `scripts/check-workspace.sh` (phase 2, per-member `cargo check --all-targets`, Linux): **all 20 members compile**.
- Filtered tests, Linux: L2 wire 2/2, L2 59/59, L7 93/93, L8 92/92, L5 68/68, L6 41/41 + 36/36 + broker
  fixtures 5/5, L3 spk-host set 29/29 (`dispatch_fence|lifecycle_v3_stop_recovery|grain_export|spawn_gate|broker::home|resident_privilege`).
- Floor audit (`scripts/spk-platform/sandbox-floor-audit.sh`): **box red, unexercised**. Both the floor
  and the pre-floor control fail at `namespace setns(CLONE_NEWUSER) refused: EINVAL` before the probe
  runs: hbox's AppArmor unprivileged-userns restriction, the same class as m6grain's and hermes's.

## Candidate and rows

- **Candidate:** `/tank/dregg-build/claude-integration-20261026/C` (230M), built at `55e483e0`;
  `SHA256SUMS` sha256 `dada5844df1c3e2582ae5291c516974fd6e46bf5298107a76288a638d092b912`.
- **Rows:** the standing-run row set, run by the tree's own `journey-runner --tip 55e483e0 --source-tree
  /tank/dregg-build/claude-lanes/integ-20261026/src` (an extract of `C/source.tar`, placed under the sudoers
  glob `claude-lanes/*/src` so m6grain can run) against a private PIPELINE_ROOT on the SSD
  (`/othersys/lanes/integration/{proot,artifacts,journeys}`); `PIPELINE_JOURNEY_JOBS=4` from box.env.
  Results: `/othersys/lanes/integration/journeys/55e483e0…/`. Journey wall 5,019 s at load 88-118.

**Counts (145 lines): PASS 118 / FAIL 23 / UNCONFIGURED 4**, against today's baseline at a0db11f8
(PASS 136 / FAIL 2 / UNCONFIGURED 6 / UNJUDGED 3).

| row(s) | a0db11f8 -> 55e483e0 | cause | lane |
|---|---|---|---|
| activity, seats, bounty; send + send/S2-deliver (`s2-again`); domain + domain/D2-register (`d2-exists`); objectrecord + objectrecord/OR2-create (`create-ledger-again-conflicts`) | PASS -> FAIL | each driver resubmits an intentional duplicate and expects the Host's refusal or conflict; the client now refuses locally first: "this turn was already submitted (confirmed …); a second one is your decision: --again true". L2's no-rerun-pays-twice rule, applied to drivers that predate it | L2 (drivers owe `--again`) |
| upgrade + U1-U5 | PASS -> FAIL | `KeyError: 'record'` (objective-upgrade-native-journey.py:99, :130): the attempt JSON shape the driver reads moved | L2 |
| chargedfailure + chargedfailure/cost | PASS -> FAIL | `KeyError: 'ingress'` (objective-charged-failure-journey.py:208 via activity_world.py:490): same class | L2 |
| jpay/JPAY4 | PASS -> FAIL | 24/25: "enrollment dust … --enrol: the signed tariff has no enrolIndex": journalFloor now comes from the signed tariff and the fixture's tariff has no enrolment row | L5 |
| births (+ 3 sub-rows) | UNCONFIGURED/UNJUDGED -> FAIL/missing | `OSError: [Errno 28] No space left on device` on /run/user/1000 (13 G tmpfs, 8 rows at once) during the run; 951 M in use afterwards | environment (hbox) |
| demo | missing -> FAIL | new row (L9's split): 18/39, frontier THIN: "journey wall budget spent (5,000 s)"; K12T 1,127 s, K12M 976 s, KC 651 s at load ~88 | environment (load); unjudged as product |
| m6grain | UNCONFIGURED -> FAIL | now RUNS (the tree is under the sudoers glob) and fails at the known resident unit failure before START completion (AppArmor userns on hbox, PIPELINE-HBOX.md) | known, box |
| jpay/JPAY6, jpay | FAIL -> FAIL | the 70-byte socket row; L1's fix is not in round 1 | known |
| m7, hostupgrade, objective, perf | UNCONFIGURED -> UNCONFIGURED | no reference / no EF set / no lean env / load | unchanged |

No delta is unexplained. The L2 and L5 rows are real reds and were routed to those lanes. Their fixes go
in through round 2 (L1's JPAY6) or later rounds.

<details><summary>table.txt (verbatim, cut at 200 columns)</summary>

```
tip 55e483e024d7760b0e1b61fcc88950eb8a4425e2  labels: 
journey wall 5019 s on hbox (24 CPUs), finished 2026-10-27T07:30:57Z; set built 

ROW                                          STATUS        WALL_S   OWNER        DETAIL
journey/J0                                   PASS          3.585    unknown      service up and a signed read answered in 3.459s
journey/J1                                   PASS          2.256    unknown      subject 9775578220641092609, record 1; key absent from genesis/config; lookup = same receipt
journey/J2                                   PASS          1.396    unknown      object 12360968133951721769 under all[], record 2
journey/J3                                   PASS          1.949    unknown      child 12616724315576321433 verbs observe,mutate, record 3
journey/J4                                   PASS          3.000    unknown      read 0.958s, write 1.175s, readback field 2 = 1, record 4
journey/J5                                   PASS          6.520    unknown      8/8 refused: 4 by the Host (enrolled no-grant read x2, propose, crafted submit), 2 by local consent before signing (une
journey/J6                                   PASS          3.049    unknown      reopen to first signed read 1.259s; J1 receipt and field 2 = 1 recovered; retry replayed tx with its original (root, he
journey/J7                                   PASS          4.906    unknown      law v1 not(any[]) installed (submit 0.828s); J3 grant wrote 1->7 (submit 1.067s). The new law is still permit-all
journey/J8                                   PASS          4.768    unknown      deny-all installed (submit 1.121s); 5/5 refused: newcomer read/propose/crafted, sponsor read, sponsor repair propose; p
journey/JROT                                 PASS          81.031   unknown      JROT: 34/34 checks; friend subject 10529659880630815081 rotated 1->2->3; thief refused (?); plain subject notPrerotated
journey/JROTL                                PASS          16.633   unknown      JROTL: 10/10 checks; a lost op-142 reply recovered by op-143 lookup (epoch 2, one submit); a never-seen rotation looks 
journey/JRLANE                               PASS          193.485  unknown      JRLANE: 14/14 checks; A=12921403912716662481 closed after 179 authenticated refusals; 1500 wrongly signed cost nothing;
journey/JGATE                                PASS          27.017   unknown      JGATE 12/12 (27 s)
journey/JAUDIT                               PASS          77.080   unknown      JAUDIT: 5/5 checks; store audit: 38 records; chain, tags, accumulator (73 nodes), index (76 keys, 18; planted height 19
journey                                      PASS          434      unknown      frontier END
demo                                         FAIL          5018     unknown      demo journey: 18/39 PASS, frontier THIN
objective                                    UNCONFIGURED  2        unknown      no lean env for this tip (its mutations run lake env lean)
rooms                                        PASS          725      unknown       229 rows, 0 red, 93/93 expected rows present and ok
activity                                     FAIL          3110     unknown      objective-activity-native-acceptance.py: pass-height-190449                           installed None  dy submitted (con
seats                                        FAIL          2675     unknown      objective-seat-native-acceptance.py: E8-pass-height-166543                        installed None  is turn was already s
bounty                                       FAIL          60       unknown      objective-bounty-native-acceptance.py: reject-claim-seat-40                         installed confirmed  
call/C1-leaf                                 PASS          0        unknown      4 rows ok
call/C2-chain                                PASS          1        unknown      4 rows ok
call/C3-sequence                             PASS          0        unknown      3 rows ok
call/C11-front-end-meter                     PASS          3        unknown      5 rows ok
call/C4-reentry                              PASS          0        unknown      4 rows ok
call/C5-dao                                  PASS          1        unknown      4 rows ok
call/C6-authority                            PASS          3        unknown      8 rows ok
call/C7-facet                                PASS          1        unknown      3 rows ok
call/C9-grant-args                           PASS          2        unknown      8 rows ok
call/C10-grant-who                           PASS          2        unknown      5 rows ok
call/C8-shape                                PASS          2        unknown      5 rows ok
call                                         PASS          48       unknown      {"rows": 63, "failed": []}
send/S1-send                                 PASS          2        unknown      6 rows ok
send/S2-deliver                              FAIL          0        unknown      1 of 8 rows red: s2-again
send/S3-full                                 PASS          10       unknown      11 rows ok
send/S4-failed                               PASS          2        unknown      6 rows ok
send/S5-forward                              PASS          3        unknown      10 rows ok
send/S6-broken                               PASS          4        unknown      10 rows ok
send/S7-shape                                PASS          2        unknown      4 rows ok
send/S8-interface                            PASS          4        unknown      7 rows ok
send/S9-resolved                             PASS          2        unknown      8 rows ok
send/S10-cancel                              PASS          8        unknown      20 rows ok
send/S11-pole                                PASS          3        unknown      8 rows ok
send/S12-stop                                PASS          3        unknown      13 rows ok
send/S13-who                                 PASS          6        unknown      10 rows ok
send/S14-continue                            PASS          3        unknown      8 rows ok
send/S15-exceed                              PASS          3        unknown      9 rows ok
send/S16-fanout                              PASS          2        unknown      6 rows ok
send/S17-depth                               PASS          5        unknown      8 rows ok
send/S18-cancel                              PASS          2        unknown      5 rows ok
send/S19-retry                               PASS          2        unknown      9 rows ok
send/S20-same-op-other-call                  PASS          1        unknown      5 rows ok
send/S21-forged-retry                        PASS          1        unknown      5 rows ok
send/S22-retry-outcome-altered               PASS          0        unknown      5 rows ok
send                                         FAIL          110      unknown      {"rows": 192, "failed": ["s2-again"]}
domain/D1-joint                              PASS          3        unknown      10 rows ok
domain/D2-register                           FAIL          2        unknown      1 of 7 rows red: d2-exists
domain/D3-stale                              PASS          2        unknown      6 rows ok
domain/D4-bank                               PASS          4        unknown      8 rows ok
domain/D5-keep                               PASS          1        unknown      4 rows ok
domain/D6-priced                             PASS          3        unknown      8 rows ok
domain                                       FAIL          61       unknown      {"rows": 58, "failed": ["d2-exists"]}
upgrade/U1-adopt                             FAIL          0        unknown      1 of 1 rows red: U1-adopt-raised
upgrade/U2-drain                             FAIL          3        unknown      4 of 8 rows red: birth-while-draining-refused, a1-deliver-200-refused, u2-new-law-judged-the-drained-write, migrate-whi
upgrade/U3-abort                             FAIL          0        unknown      1 of 1 rows red: U3-abort-raised
upgrade/U4-migrate                           FAIL          0        unknown      3 of 3 rows red: migrate, u4-migrated-state, u4-record-on-v2-steady
upgrade/U5-rebirth                           FAIL          0        unknown      1 of 1 rows red: U5-rebirth-raised
upgrade                                      FAIL          14       unknown      {"rows": 22, "failed": ["birth-a2", "birth-a3", "U1-adopt-raised", "birth-while-draining-refused", "a1-deliver-200-refu
hostupgrade                                  UNCONFIGURED  1        prod-hostup  missing hostupgrade candidate input: /othersys/lanes/integration/artifacts/e0a8ba21a39d92b470cc331fd16ea0408f608b1f
objectrecord/OR1-no-record                   PASS          0        unknown      2 rows ok
objectrecord/OR2-create                      FAIL          0        unknown      1 of 7 rows red: create-ledger-again-conflicts
objectrecord/OR3-write-law                   PASS          1        unknown      3 rows ok
objectrecord/OR4-birth-law                   PASS          1        unknown      6 rows ok
objectrecord/OR5-resume-view-law             PASS          2        unknown      7 rows ok
objectrecord/OR6-delivery-principal          PASS          4        unknown      11 rows ok
objectrecord/OR7-conservation                PASS          0        unknown      1 rows ok
objectrecord                                 FAIL          25       unknown      {"rows": 39, "failed": ["create-ledger-again-conflicts"]}
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
welcomecontinuity                            PASS          25       unknown      genesis-params: params.sh from the candidate: /othersys/lanes/integration/artifacts/55e483e024d7760b0e1b61fcc88950eb8a4
sshe2e                                       PASS          97       unknown      ssh-e2e: PASS (4 publickey logins accepted by sshd; evidence in /run/user/1000/pj.Vx77ko/ssh/log)
m3                                           PASS          23       unknown      provisioning and cold reopen completed
m4                                           PASS          82       unknown      shell J0-J8 over ssh completed
hermes                                       PASS          246      unknown      deterministic Hermes restart, recovery and delegation completed
m6grain                                      FAIL          380      prod-spk     m6grain evidence-a/start-a exit 1: spk-host: grain refused: resident unit mini-spk-s4a787a1e070a9f42-a9101-g2.service i
m7                                           UNCONFIGURED  1        unknown      missing input: M7_REFERENCE (file)
m8                                           PASS          35       unknown      m8 completed with verified summary
fleetsign                                    PASS          182      unknown      fleetsign completed with verified summary
jpay/JPAY1                                   PASS          1        unknown      J-PAY-1 PASS 15/15 
jpay/JPAY2                                   PASS          385      unknown      J-PAY-2 PASS 18/18 (381.0 s) 
jpay/JPAY3                                   PASS          38       unknown      J-PAY-3 PASS 24/24 (24.2 s) 
jpay/JPAY4                                   FAIL          74       unknown      JPAY4 driver exit 1: J-PAY-4 FAIL 24/25 (70.4 s) 
jpay/JPAY6                                   FAIL          12       unknown      JPAY6 driver exit 66: journey: a socket outgrew its declared row in journey.d/lib/shortdir.sh (70 bytes): /run/user/100
jpay                                         FAIL          511      unknown      JPAY1-4 and JPAY6: JPAY1 PASS;JPAY2 PASS;JPAY3 PASS;JPAY4 FAIL;JPAY6 FAIL;
exchange                                     PASS          58       unknown      exchange PASS: local fn stopped; exact selected packet admitted, replayed by the fn consumer unit, signed readback veri
chargedfailure/fees                          PASS          1        unknown      3 rows ok
chargedfailure/charged                       PASS          0        unknown      3 rows ok
chargedfailure/charged-replay                PASS          1        unknown      5 rows ok
chargedfailure/outcome-moved                 PASS          1        unknown      4 rows ok
chargedfailure/malformed                     PASS          0        unknown      2 rows ok
chargedfailure/forged                        PASS          0        unknown      3 rows ok
chargedfailure/unfunded                      PASS          0        unknown      2 rows ok
chargedfailure/cost                          FAIL          0        unknown      2 of 4 rows red: cost-plan-1, cost-raised
chargedfailure                               FAIL          32       unknown      chargedfailure driver exit 1: KeyError: 'ingress'
births                                       FAIL          386      unknown      births FAIL: workload exited 1 with no summary (N=64; load 118.53->97.24): OSError: [Errno 28] No space left on device:
jserve                                       PASS          90       unknown      JSERVE completed: 12/12 serve rows: no hostile client stalled the honest read or stopped the service
perf/perf-genesis                            PASS          5.94     unknown      bring-up n=1 p50=5938ms max=5938ms
perf/perf-setup                              PASS          11.95    unknown      resource n=4 p50=1385ms max=2083ms; publication n=2 p50=208ms max=355ms; publish n=2 p50=1288ms max=1398ms; create n=4 
perf/perf-births                             PASS          78.65    unknown      resource n=20 p50=2383ms max=3033ms; create n=20 p50=1543ms max=2344ms
perf/perf-updates                            PASS          14.69    unknown      invoke n=16 p50=839ms max=1394ms
perf/perf-reads                              PASS          6.00     unknown      read-current n=8 p50=19ms max=21ms; read-at n=8 p50=564ms max=763ms
perf/perf-checkpoint                         PASS          0.77     unknown      certify n=1 p50=765ms max=765ms
perf/perf-judgment                           PASS          3.79     unknown      call-granted n=1 p50=1184ms max=1184ms; send n=1 p50=1597ms max=1597ms; deliver n=1 p50=966ms max=966ms
perf/perf-reopen                             PASS          2.57     unknown      stop n=1 p50=101ms max=101ms; to-first-read n=1 p50=2367ms max=2367ms; read-current n=1 p50=19ms max=19ms
perf                                         UNCONFIGURED  131      unknown      perf UNCONFIGURED: bar not judged: loadavg 99.64->109.56 (box not quiet: run-u62333.scope 1.43 cores (/home/hbox/.elan/
```
</details>

## Not in this integration (round 1)

lane/lean-critical (L1), lane/hermes (L4), lane/perf (L11), lane/hot-path, lane/coordination, and the
later tips of web, keys-store, fn-fleet, fence and custody: all in round 2 ([INTEGRATION-2.md](INTEGRATION-2.md)).
