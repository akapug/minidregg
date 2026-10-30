# Integration 2 (2026-10-27): round 2 onto `integration/2026-10-26`, `55e483e0` → `45f45d15`

Round 1 (six lanes, tip `55e483e0`, hbox candidate and rows) is [INTEGRATION-1.md](INTEGRATION-1.md). Round 2
merged every lane's next tip as it was pushed, in the order the coordinator sent them, on a staging worktree
(`integration/r2-staging`, pushed as `integration/2026-10-26`). The Linux half ran on **dregg-build**
(Debian 13, 8 vCPU, SSD), not hbox. The candidate is built at `45f45d15`.

## Merge list (first-parent, in order)

```
cee879ae Merge lane/custody (L2) at its rebased final 554667d9: 253/255 by name, the attempt's seal record, afe95592 and the perf barrier beneath
19bd4f20 Merge lane/lean-critical (L1) at d21123eb: NO_RECORD in the Host, the four-class provider settle, Lean-emitted default laws, JPAY6
5f7be962 Merge lane/perf (L11) at bef88d32: the write-seconds review
d2421a18 Merge lane/web (L7) at ae070b95: the stale-target re-plan for concurrent appends
cbae0853 Merge lane/keys-store (L6) at 43ede087: SQLite WAL with synchronous=FULL
77712a3b Merge lane/fn-fleet (L8) at 6e9ea3bb: the quoted fn unit environment line
9f1fedec Merge lane/fence (L3) at 1db6f7f7: the floor audit under the unit hardening, the bwrap 0.12 openat2 guard
5923a5c7 Merge lane/coordination at 34460623: the gate bookkeeping that measured itself deleted; one coordination description
ae057e2a replan: a stale-target re-plan only under NO_RECORD, through the same decided() as the other classes
46293eff Merge lane/hermes (L4) at d4c9a018: units that open, grain-runtime create, the typed outcome record, provider classes, deletions
e7a405f5 Merge lane/hot-path at dd8fa1ac: the hashing kernels behind @[extern], the O(1) consent re-check; codec-resident deferred
2ba0bda8 Merge lane/web (L7) at 717148c9: summon births the program document with its document
b36f2a4e Merge lane/hot-path again at its final 58bfb7e3: the spk-host image hashed once, the kernel build before every lake build
83928088 Lean: repair two proofs from lane/lean-critical d21123eb that do not elaborate; statements unchanged
acbe5f1c Merge lane/hermes (L4) at a9e0dd70: the provider tests ask for tickets the way the controller does
3ff0a408 Merge lane/fence (L3) at 1fe14837: the namespace bootstrap names what is missing
1a140242 Merge lane/door (L5) at bce88a74: Discord gateway mode
00c9683b Merge lane/app-market (L13) at 6ceadaca: the app catalogue verbs, the grain front, identity custody
68092f8a Merge lane/coordination at its final 179a21c2: the measured cold Lean build, the Lean RSS table
011eb2db Merge lane/app-market (L13) at 1c7a7f30: the apps worker, the Lean request law
b5182357 Merge lane/web-frontend at 7992d156: one web application through a gateway; the static faces composted
36b9458a Merge lane/app-market (L13) at 0eec937a: the front on 8799, the worker socket groups
24cb5b5b Merge lane/lean-critical (L1) at 556346d3: checkPlan accepts the pinned plan, the four-class settle, emitted default laws
7774af04 Merge lane/fence (L3) at 7f10e93b: the floor audit from a single-threaded child; Debian 13 floor PASS
a8102309 Merge lane/app-market (L13) at dfc696de: INSTALL.md
130b885b Merge lane/fence (L3) at its final 5aaf1a32: the audit root is exec-capable and not group/world writable
3479cca1 Merge lane/web-frontend at 48e2701d: the public front page, /tour, browser-only join, the apps seam, outcome truth
dda6dd9b Merge lane/lean-critical (L1) at 960d7a83: every signing-plan operation consent-checked or recorded exempt by name
20d15063 Merge lane/lean-critical (L1) at its final 181e44e6: ops 187 and 194 consent-checked by re-derivation
003ddf06 Merge lane/web-frontend at db7f3171: the shell grammar as data (35 verbs, 123 leaves)
1bbb7b8d Merge lane/app-market (L13) at fc4e2c7d: the member's own birth and the metered grants inside apps install
45f45d15 Merge lane/m7 at c851d8c4: package.py derives the source tree from the archive itself
```

## Conflicts and decisions

- **Rebased lanes merged with their old tips as the merge base.** L2 rebased custody onto L1 afe95592 and L11
  ed73009c, rewriting every L2 commit already on this branch. The default base re-conflicted 18 files on
  identical changes. `git merge-tree --merge-base=68e721ad` (the old custody tip) left three: main.rs (the fn-e
  consumer functions L8 deleted and L2 had renamed inside: kept deleted), drain.rs (deleted by L8, kept
  deleted), and the generated host-operations.rs (regenerated). perf was merged with ed73009c as its base for
  the same reason.
- **The registry** (protocol/host-operations.json; L1, L2, L8 met there): after every merge, `generate` is a
  no-op and `check` + `test-host-operations.py` pass. HOST_REFUSAL is renamed HOST_OUTCOME, NO_RECORD=253,
  every op carries `effect`, consent_plans + consent_exempt, ops 13/15 are operator-only.
- **replan.rs** (L7 x L2 x L1; integration commit ae057e2a): L7's stale-target re-plan matched
  `HostDecision::RefusedFrame`, which L2 renamed `Frame`. With L1 landed, a NEW call is legitimate only under
  NO_RECORD (253); the same decoded refusal under 255 is undecided and is looked up. It uses L2's `decided()`
  like the other re-plan classes, and the test asserts 253 re-plans and 255 does not.
- **hot-path's `mini codec-resident` (2a) deferred.** It edited client_consent.rs as on main, but L2 moved the
  client's local processes into mini-sdk. The kernels, seams, recheckHeld and builder wiring are in; 2a is the
  hot-path lane's to re-apply on mini-sdk.
- **L1's two Lean reds** (Host/RequestRefusal.lean, Kernel/NativePlanHeight.lean) were repaired at 83928088,
  tactics only, statements and `#assert_axioms` unchanged. L1 cherry-picked the repair as 67b66541.
- **L4 x L6 provider tests** (10 of 69): L4's test broker minted pool tickets with maxTokens 1 for bodies with
  no max_tokens, and L6's body-vs-grant check rightly refused them. L4 fixed the fixture (a9e0dd70).
- **hermes**: grain-runtime main.rs keeps L6's `use mini_keys::credentials` without the deleted
  controller_write_scopes; credit.rs keeps L2's `money_record` (it already does L4's bound-record recovery);
  jpay6.sh/shortdir.sh keep L1's driver fixes (L4 fixed the same reds); the grain-host README has L4's two
  unit modes with L9's note. Merged after fence/coordination rather than before; it touches no spk-host file.
- **coordination**: local-gates GATES is the union (coordination's list + L9's `workspace`); required-rows
  keeps L9's demo/kernel split with no known-red lines; mk-lane keeps coordination's reds-named-from-the-run
  with hot-path's build-mini-kernels prefix.
- **web-frontend**: Cargo members gain mini-web and mini-web-spawn beside mini-kernels; discord-entrance gets
  L5's gateway deps plus sha2; the valueless-switch list is `web --body/--anonymous` plus L13's
  `apps --json`. **package.py gains the roles `web` (mini-web) and `webSpawn` (mini-web-spawn)**, so the
  candidate ships both binaries INSTALL.md names. In shell.rs, the grammar-as-data rows keep L13's `apps` row
  and dispatch arm.
- Cargo.lock was refreshed after each new crate; every package version equals one in a lane's own lock.

## Checks

Mac (each merge): the workspace check minus the Linux-only targets is green; the registry check and test pass;
the membership gate passes (24 packages, 23 members, 1 excluded). `lake build Host.Main
Host.ClientConsentSession` after build-mini-kernels.sh: **Build completed successfully (3,755 jobs)** at a8102309
(Lean is unchanged through 45f45d15 except L1's registry-generated HostOperations.lean, rebuilt on dregg-build).

dregg-build (`/build/lanes/integration`, COMMANDS.log has every command and wall time):

- `scripts/check-workspace.sh` phase 2 on Linux: **every member compiles (all targets)**, 24 packages. (The
  first run failed only because the box's offline registry lacked `fs2`; `cargo fetch --locked` fixed that.)
- Filtered tests at dda6dd9b (45f45d15 adds no Rust test change under these filters): L2 wire 2/2, L2 97/97, L7
  124/124, L8 92/92, L5 69/69, L5 session/door/endpoint 18/18 (the box-only red L12 reported passes), L6 41/41 +
  37/37 + broker fixtures 6/6, L4 69/69, L3 spk-host set 29/29, mini-kernels 5/5, L12 mini-web/spawn 17/17, L13
  `apps_` 18/18, custody.ts 4/4 (node 24).
- **Sandbox floor audit on Debian 13: rc=0** (L3 408296cb/5aaf1a32: the audit enters the user namespace from a
  single-threaded child, because libtest's thread made setns(CLONE_NEWUSER) answer EINVAL; root
  /var/lib/spk-floor-audit).
- Named reds found and resolved during the round: L1 RequestRefusal/NativePlanHeight (repaired, 83928088); L4 x
  L6 provider tests (fixed by L4, a9e0dd70); L3 resident_privilege (box inputs; fixed by L3's checks plus uidmap).

## Candidate

- `/build/candidates/45f45d1517389a907cd34e18663ec62925d8aa2d` (492M), commit 45f45d15, SHA256SUMS sha256
  `fc1111ed3a098d4b9ea7f62fea8ab79770576aa44f92d24cbcc44dcaa4292cf9`; 21 roles (consent discord discordMirror door
  doorProcess grainProviderBridge grainRuntime host inferenceScheduler keys launchGate mini payWatcher spkBroker
  spkBrowserProxy spkHost spkVolumeHelper store verifier web webSpawn).
- `lane-build.sh` host 1,598 s (MINIDREGG_LEAN_SEATS=4, the whole Host closure after the kernels' Core
  change), consent 323 s, rust 220 s, pack 9 s. The host-closure ceiling was not exceeded.
- `/build/CANDIDATE-ROUND2.md`: the path, and why no broker world exists for `lanes` (root installer; batch).

## Rows (dregg-build, 45f45d15)

Run: the tree's own `journey-runner --tip 45f45d15 --source-tree /build/lanes/integration/src` against a
private pipeline root (`/build/lanes/integration/pipeline`), `PIPELINE_JOURNEY_JOBS=4`, row scratch on the SSD
(`XDG_RUNTIME_DIR=/build/t`, with the user bus and systemd linked; /run/user here is 3.1 G). The first run was
void, because the box lacked `xxd`, `bc` and `python3-nacl` (installed with the lanes apt-get rule). The table
below is the second run, `journeys-r2b/` (wall 6,482 s).

**Counts (148 lines): PASS 112 / FAIL 25 / UNCONFIGURED 8 / UNJUDGED 3.** m7 PASSED separately against the
reference built cold on dregg-ref (coordinator, evidence dregg-build:/build/cand-m7r2/), so with it:
113 / 24 / 7 / 3.

| red | cause | owner / state |
|---|---|---|
| journey (J5) | journey-stranger.py counted only 255 as a refusal; L1's Host answers "not enrolled" under NO_RECORD 253 | fixed at 9f144c2b (driver); rerun against this candidate: **journey PASS 15/15** (`journeys-j5fix/`) |
| rooms, demo K10..JPD (+ WEB, JWF not run) | "blocked: J5 did not pass" | clears with 9f144c2b |
| demo J12X (16/20 malformed op 7/10/11 rows), THIN, JCHAT, JPAYE2, JP2, JDISCLOSE | not yet classified; probably the same 253/255 driver class | L2 successor / L1 |
| activity, seats | timed out at 5,400 s (unbounded pass-height loops in the drivers) | custody-drivers 2c15e48c: seats 92/92 PASS; activity still red, needs 2c15e48c's activity.rs (round 3) |
| bounty, send/S2, domain/D2, objectrecord/OR2, upgrade U1-U5 | drivers did not pass `--again` for intentional duplicates / read the old attempt shape | **all PASS** with 2c15e48c's drivers on these binaries (`journeys-drv/`) |
| chargedfailure/cost | KeyError 'ingress' with both driver sets | L2 successor (evidence `journeys-drv/chargedfailure/…/rows/chargedfailure/`) |
| jpay/JPAY4 | 24/25 on the old fixture's tariff (no enrolIndex) | 26/26 with 2c15e48c |
| m3 | "workspace read attempt: …/attempts/a-…" | unclassified |
| jserve | 6/12 serve rows ((b), (b2)) at load ~7 on 8 CPUs | the known timing-sensitive row |

UNCONFIGURED: objective (no lean env), hostupgrade (no EF set), m6grain and jpay/JPAY6 (their probes demand
`sudo -n true`; the box grants only the installer and two-world journey), exchange (no fn image), births (load:
create p99 3.9 s, resource p99 6.2 s, reopen 6.8 s), perf (load).

Also on this candidate:
- **Composed scenario** (`composed-only.sh` with dregg-infra edge/mini at main 1bd0aa8, 5 members, run /build/c46):
  rooms **pass**, churn **pass**, documents **pass** (its protected/ordinary rows blocked: no binding), apps
  **blocked** (no apps input), connector **blocked** (needs apps), residents **blocked** (no residents.binding),
  restart **pass**; gate verdict FAIL. No script in minidregg or dregg-infra produces a jworld-scratch world's
  apps.worldInputs.platformInputs, residents.binding or documents binding. Producing them, by bringing a grain
  world up on the composed scenario's own Store, is construction work for a lane (L13 or an L4 successor), not
  an integration step. The run needed a local fix to dregg-infra's edge/mini/shell/mini-shell-ssh:30: the input
  redirect preceded `2>/dev/null`, so an absent /etc/mini/session-consent printed into whoami's JSON. That is
  routed to the infra lane.
- **JWF** (web-frontend d14ca3c8's row script, L12's client and gateway) against this Host: **J-WEB-FRONTEND
  PASS 24/24** (tour-chromium UNCONFIGURED: no Playwright). tour-refused is green on the round-2 Host.
- **JPAY1-4** PASS with 2c15e48c.

<details><summary>table.txt (journeys-r2b, verbatim, cut at 200 columns)</summary>

```
tip 45f45d1517389a907cd34e18663ec62925d8aa2d  labels: 
journey wall 6482 s on dregg-build (8 CPUs), finished 2026-10-27T10:36:30Z; set built 

ROW                                          STATUS        WALL_S   OWNER        DETAIL
journey/J0                                   PASS          2.943    unknown      service up and a signed read answered in 2.906s
journey/J1                                   PASS          4.567    unknown      subject 14595153737629792880, record 1; key absent from genesis/config; lookup = same receipt
journey/J2                                   PASS          1.626    unknown      object 15794302366601397468 under all[], record 2
journey/J3                                   PASS          2.164    unknown      child 16663885539203792068 verbs observe,mutate, record 3
journey/J4                                   PASS          2.684    unknown      read 0.745s, write 1.122s, readback field 2 = 1, record 4
journey/J5                                   FAIL          7.404    unknown      2 of 8 stranger attempts were refused by neither the Host nor the local consent component, or by the Host for another r
journey/J6                                   PASS          2.432    unknown      reopen to first signed read 0.805s; J1 receipt and field 2 = 1 recovered; retry replayed tx with its original (root, he
journey/J7                                   PASS          5.197    unknown      law v1 not(any[]) installed (submit 0.784s); J3 grant wrote 1->7 (submit 0.806s). The new law is still permit-all
journey/J8                                   PASS          4.162    unknown      deny-all installed (submit 0.776s); 5/5 refused: newcomer read/propose/crafted, sponsor read, sponsor repair propose; p
journey/JROT                                 PASS          78.908   unknown      JROT: 34/34 checks; friend subject 11130264212430827195 rotated 1->2->3; thief refused (?); plain subject notPrerotated
journey/JROTL                                PASS          15.755   unknown      JROTL: 10/10 checks; a lost op-142 reply recovered by op-143 lookup (epoch 2, one submit); a never-seen rotation looks 
journey/JRLANE                               PASS          157.712  unknown      JRLANE: 14/14 checks; A=12398167598116880173 closed after 277 authenticated refusals; 1500 wrongly signed cost nothing;
journey/JGATE                                PASS          24.147   unknown      JGATE 12/12 (24 s)
journey/JAUDIT                               PASS          56.080   unknown      JAUDIT: 5/5 checks; store audit: 38 records; chain, tags, accumulator (73 nodes), index (76 keys, 18; planted height 19
journey                                      FAIL          369      unknown      frontier J5
demo                                         FAIL          3042     unknown      demo journey: 14/40 PASS, frontier J12X
objective                                    UNCONFIGURED  0        unknown      no lean env for this tip (its mutations run lake env lean)
rooms                                        FAIL          56       unknown      J5      FAIL;JPRIV1  FAIL 0 rows, 0 red, 0/93 expected rows present and ok
activity                                     FAIL          6423     unknown      timed out after 5400 s
seats                                        FAIL          6426     unknown      timed out after 5400 s
bounty                                       FAIL          61       unknown      objective-bounty-native-acceptance.py: reject-claim-seat-40                         installed confirmed  
call/C1-leaf                                 PASS          0        unknown      4 rows ok
call/C2-chain                                PASS          0        unknown      4 rows ok
call/C3-sequence                             PASS          0        unknown      3 rows ok
call/C11-front-end-meter                     PASS          3        unknown      5 rows ok
call/C4-reentry                              PASS          0        unknown      4 rows ok
call/C5-dao                                  PASS          1        unknown      4 rows ok
call/C6-authority                            PASS          4        unknown      8 rows ok
call/C7-facet                                PASS          1        unknown      3 rows ok
call/C9-grant-args                           PASS          3        unknown      8 rows ok
call/C10-grant-who                           PASS          2        unknown      5 rows ok
call/C8-shape                                PASS          2        unknown      5 rows ok
call                                         PASS          53       unknown      {"rows": 63, "failed": []}
send/S1-send                                 PASS          1        unknown      6 rows ok
send/S2-deliver                              FAIL          0        unknown      1 of 8 rows red: s2-again
send/S3-full                                 PASS          8        unknown      11 rows ok
send/S4-failed                               PASS          2        unknown      6 rows ok
send/S5-forward                              PASS          2        unknown      10 rows ok
send/S6-broken                               PASS          3        unknown      10 rows ok
send/S7-shape                                PASS          2        unknown      4 rows ok
send/S8-interface                            PASS          4        unknown      7 rows ok
send/S9-resolved                             PASS          1        unknown      8 rows ok
send/S10-cancel                              PASS          8        unknown      20 rows ok
send/S11-pole                                PASS          2        unknown      8 rows ok
send/S12-stop                                PASS          3        unknown      13 rows ok
send/S13-who                                 PASS          6        unknown      10 rows ok
send/S14-continue                            PASS          3        unknown      8 rows ok
send/S15-exceed                              PASS          2        unknown      9 rows ok
send/S16-fanout                              PASS          2        unknown      6 rows ok
send/S17-depth                               PASS          3        unknown      8 rows ok
send/S18-cancel                              PASS          1        unknown      5 rows ok
send/S19-retry                               PASS          1        unknown      9 rows ok
send/S20-same-op-other-call                  PASS          1        unknown      5 rows ok
send/S21-forged-retry                        PASS          0        unknown      5 rows ok
send/S22-retry-outcome-altered               PASS          0        unknown      5 rows ok
send                                         FAIL          99       unknown      {"rows": 192, "failed": ["s2-again"]}
domain/D1-joint                              PASS          3        unknown      10 rows ok
domain/D2-register                           FAIL          1        unknown      1 of 7 rows red: d2-exists
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
upgrade                                      FAIL          13       unknown      {"rows": 22, "failed": ["birth-a2", "birth-a3", "U1-adopt-raised", "birth-while-draining-refused", "a1-deliver-200-refu
hostupgrade                                  UNCONFIGURED  1        prod-hostup  missing hostupgrade candidate input: /build/lanes/integration/pipeline/artifacts/e0a8ba21a39d92b470cc331fd16ea0408f608b
objectrecord/OR1-no-record                   PASS          0        unknown      2 rows ok
objectrecord/OR2-create                      FAIL          1        unknown      1 of 7 rows red: create-ledger-again-conflicts
objectrecord/OR3-write-law                   PASS          1        unknown      3 rows ok
objectrecord/OR4-birth-law                   PASS          1        unknown      6 rows ok
objectrecord/OR5-resume-view-law             PASS          2        unknown      7 rows ok
objectrecord/OR6-delivery-principal          PASS          4        unknown      11 rows ok
objectrecord/OR7-conservation                PASS          0        unknown      1 rows ok
objectrecord                                 FAIL          27       unknown      {"rows": 39, "failed": ["create-ledger-again-conflicts"]}
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
welcomecontinuity                            PASS          22       unknown      genesis-params: params.sh from the candidate: /build/lanes/integration/pipeline/artifacts/45f45d1517389a907cd34e18663ec
sshe2e                                       PASS          7        unknown      ssh-e2e: PASS (4 publickey logins accepted by sshd; evidence in /build/t/pj.KspcEq/ssh/log)
m3                                           FAIL          27       unknown      m3 driver exit 1: workspace read attempt: /build/t/pj.xqGl3v/p/sponsor/attempts/a-3150402780864814876980821573406995292
m4                                           PASS          73       unknown      shell J0-J8 over ssh completed
hermes                                       PASS          212      unknown      deterministic Hermes restart, recovery and delegation completed
m6grain                                      UNCONFIGURED  0        prod-spk     missing input: operator account ember with uid 1001 (MINI_OPERATOR_UID/MINI_OPERATOR_NAME)
m7                                           UNCONFIGURED  0        unknown      missing input: M7_REFERENCE (file)
m8                                           PASS          43       unknown      m8 completed with verified summary
fleetsign                                    PASS          180      unknown      fleetsign completed with verified summary
jpay/JPAY1                                   PASS          2        unknown      J-PAY-1 PASS 15/15 
jpay/JPAY2                                   PASS          225      unknown      J-PAY-2 PASS 18/18 (223.4 s) 
jpay/JPAY3                                   PASS          13       unknown      J-PAY-3 PASS 24/24 (12.0 s) 
jpay/JPAY4                                   FAIL          46       unknown      JPAY4 driver exit 1: J-PAY-4 FAIL 24/25 (46.0 s) 
jpay/JPAY6                                   UNCONFIGURED  1        unknown      no sudo: sudo -n probe failed 
jpay                                         FAIL          287      unknown      JPAY1-4 and JPAY6: JPAY1 PASS;JPAY2 PASS;JPAY3 PASS;JPAY4 FAIL;JPAY6 UNCONFIGURED;
exchange                                     UNCONFIGURED  0        unknown      missing input: MINI_FN_LAUNCHER (value)
chargedfailure/fees                          PASS          1        unknown      3 rows ok
chargedfailure/charged                       PASS          0        unknown      3 rows ok
chargedfailure/charged-replay                PASS          1        unknown      5 rows ok
chargedfailure/outcome-moved                 PASS          0        unknown      4 rows ok
chargedfailure/malformed                     PASS          0        unknown      2 rows ok
chargedfailure/forged                        PASS          0        unknown      3 rows ok
chargedfailure/unfunded                      PASS          0        unknown      2 rows ok
chargedfailure/cost                          FAIL          0        unknown      2 of 4 rows red: cost-plan-1, cost-raised
chargedfailure                               FAIL          27       unknown      chargedfailure driver exit 1: KeyError: 'ingress'
births/create                                UNJUDGED      379.79   unknown      births/create n=64 p50 1991 p99 3873 max 3873 ms; bar p99 <= 5000 ms
births/resource                              UNJUDGED      379.79   unknown      births/resource n=64 p50 3836 p99 6202 max 6202 ms; bar p99 <= 5000 ms
births/reopen                                UNJUDGED      7.02     unknown      reopen/to-first-read n=1 p50 6785 p99 6785 max 6785 ms; bar max <= 60000 ms
births                                       UNCONFIGURED  409      unknown      births UNCONFIGURED: bar not judged: loadavg 7.18->6.58 (quiet: no other unit >= 0.5 cores; busy) | verdict it would ha
jserve                                       FAIL          72       unknown      jserve driver exit 1: STEP JSERVE FAIL 54.270s hook exit 1: 6/12 serve rows; FAIL: (b) a long Host request while an hon
perf/perf-genesis                            PASS          3.26     unknown      bring-up n=1 p50=3260ms max=3260ms
perf/perf-setup                              PASS          11.34    unknown      resource n=4 p50=1763ms max=1941ms; publication n=2 p50=79ms max=116ms; publish n=2 p50=985ms max=1050ms; create n=4 p5
perf/perf-births                             PASS          72.48    unknown      resource n=20 p50=2445ms max=2900ms; create n=20 p50=1309ms max=1638ms
perf/perf-updates                            PASS          12.85    unknown      invoke n=16 p50=803ms max=980ms
perf/perf-reads                              PASS          5.21     unknown      read-current n=8 p50=13ms max=15ms; read-at n=8 p50=516ms max=747ms
perf/perf-checkpoint                         PASS          0.77     unknown      certify n=1 p50=767ms max=767ms
perf/perf-judgment                           PASS          3.76     unknown      call-granted n=1 p50=1527ms max=1527ms; send n=1 p50=1214ms max=1214ms; deliver n=1 p50=991ms max=991ms
perf/perf-reopen                             PASS          1.64     unknown      stop n=1 p50=100ms max=100ms; to-first-read n=1 p50=1514ms max=1514ms; read-current n=1 p50=12ms max=12ms
perf                                         UNCONFIGURED  115      unknown      perf UNCONFIGURED: bar not judged: loadavg 6.55->7.04 (box not quiet: pj-demo-pjI3EbwD.scope 1.0 cores (/build/candidat
```
</details>

## Not in round 2

Round 3 is in progress: integration `6236826f` (custody-drivers 2c15e48c, m7 f5ed535b, web-frontend d14ca3c8
with app-market fc4e2c7d inside, and the journey-stranger fix 9f144c2b; lean-critical 181e44e6 was already in),
building in /build/lanes/integ3. Not merged anywhere yet: hot-path's `mini codec-resident` (2a, to be re-applied
on mini-sdk by its lane). Owed by lanes: the composed apps/residents/documents input producer; the box sudo
probe for m6grain/JPAY6; L12's doc_render malformed-lines test red (it fails on the lane tip too).
