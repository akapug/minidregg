# Rows owed

Every journey, acceptance and qualification row any file in the tree tracks, with the command, the
world it needs, its owner and its last known result. Present state, rewritten whole (built from
main `efd65a3a8`, 2026-10-27 night). The gate's own rows (jtour/JWF and the composed scenario) and
every build and unit test belong to the integrator; everything else here is the rows validator's,
run against the candidate the integrator names, on hbox (`/tank`, `swarm-build`) or dregg-ref, never
on dregg-build's integrator slots and never on the demo box.

Notation used in the commands:

- `SHA` the candidate; `C=/build/candidates/$SHA` (its `bin/`, `run.sh`, manifest); `T` a detached
  worktree of the tree the candidate was cut from; `R` a fresh results root.
- `JR NAME` = `bash $T/scripts/pipeline/journey-runner --tip $SHA --source-tree $T --results-root $R --row NAME`
  (after `. box.env`, `export XDG_RUNTIME_DIR=/run/user/$(id -u)`). One row per call; all rows: drop `--row`.
- `JS STEPS` = `JOURNEY_STEPS="STEPS" bash $T/native/resource-client/journey.sh $C/manifest.json $RUN`
  (or `--only STEP` for the step plus its dependencies; `JOURNEY_KEEP_GOING=1` for one run that names every red).
- `WORLD` = a standing grain world: `bash $T/scripts/spk-platform/world-up.sh $C/bin OWN_BIN $RUN`
  (`$RUN/WORLD.env`; `chmod go-w deploy/spk-host/*` after each checkout; torn down by `world-down.sh $RUN`).
- "template" = the fixture's per-candidate world restored (`NEWPARTICIPANT_TEMPLATE_DIR`, on by default);
  "genesis" = the row writes its own genesis.

## 0. Candidates 2d8b7ed54, 76758dba6, e89fe7b8b (validator run, 2026-10-28 06:00-08:30Z)

Three candidates landed during one run. Each row is quoted on the newest candidate it ran on.
- 2d8b7ed54 (cut 14+, `2d8b7ed544100acfaeb9ff2f9b597c31b8cb81e6`): the grain-install fix (25cfb86bd),
  prepare-refusal clients (f73893fce), split-tenancy consent (52c0eae22), frame v8.
- 76758dba6 (`76758dba687cde9447bc45d77931bb7d57527e56`): adds the resident-start fixes (un-ns-owner
  125927331 + 29d3152d3, and 507d6ce78's controlGroup bound) and the JDISCLOSE row fix cd79cdaa3.
- e89fe7b8b (`e89fe7b8ba8c477d1538ed6ee1f0e7aeac70c97f`): adds the story-GM fix (a8376ce8f) and
  thin-birth (a5343b507). Same genesis.

Rows ran against each candidate's binaries:
- hbox: journey rows, demo `--only`, app worlds, m6grain.
- dregg-ref: the genesis writers and effects.
Drivers come from the candidate's own source.tar, except for the overlays named in the result rows.
On 76758dba6 and e89fe7b8b, main's `scripts/spk-platform/{grain-journey.sh,composed-inputs.sh}` were
overlaid (50ec8de76's importProfile, 789b9b478's repeat suffix). Every harness fix from the previous
run is on these trees. The gate and enrol-resume are the integrator's.

Row-harness fix this run: lane/rows-ledger 49c70a937. JP2's thin birth now declares field 2, the field
its later rows write. Since K-FIELD-CLOSURE, a declared cell born without a field list holds none.

| group | row | result | owner of the red |
|---|---|---|---|
| journey rows (2d8b7ed54) | journey, rooms, activity, seats, call, send, bounty, domain, upgrade, objectrecord, welcomecontinuity, m3, m4, sshe2e, hermes, m8, fleetsign, chargedfailure, jbend, jserve (the candidate's own driver), jprivate, rate | PASS | |
| journey rows (2d8b7ed54) | jpay | PASS: JPAY1 15/15, JPAY2 18/18, JPAY3 24/24, JPAY4 26/26, JPAY6 41/41 (red on 0ce31391) | |
| journey rows | m6grain | PASS on 76758dba6 with 789b9b478's grain-journey.sh, 1062 s. evidence-a has 25/25 phases, including stop, start-a2, enroll-a2 and poll-a2; world b and the cross-world refusal also pass. On 2d8b7ed54 it was the resident-start red. On bare 76758dba6 enroll-a2 failed: a trailing `2` had come to mean "second session" (closed by 789b9b478, now on main) | |
| journey rows | objective, hostupgrade, m7, exchange, births, perf | UNCONFIGURED, as before | |
| journey rows | jbend (deputy) | 33/0 on 76758dba6 (un-bend-seed 14adcc13a) | |
| demo row (2d8b7ed54) | the row itself | 22/45 in its 5,000 s budget (KTPL 1756 s, J17 1265 s on a loaded hbox). Every later step was run with `--only` | |
| demo steps | J0-J8, J12X, KC, KT, K10, KIX, K10C, K12C/I/T/M/R/H, WEB 38/38 | PASS (2d8b7ed54 demo row) | |
| demo steps | THIN, JLI, KTPL 196/196, JPRIV1 229, J17 204, J12W 81, JFEEDBACK 19, JSLK 23/23 | PASS on e89fe7b8b (JLI, KTPL and J17 were red or starved on 2d8b7ed54) | |
| demo steps | J12 139/139 (row 87 fixed), JNAMES, JDV 143, JPD 82, M3, M4, M5, M8, JPAYE1 14/14, JPAYE2 38/38, JPAYE3 27/27, JROT 34/34, JROTL 10/10, JRLANE 14/14, JGATE 12/12, JESC 13/13, JFLEETIN 12/12, JAUDIT 11/11 | PASS (2d8b7ed54 `--only`) | |
| demo steps | JP2 | On e89fe7b8b the remote thin birth (row 19) and its display pass. With 49c70a937, row 22 `submit first-write` is refused before signing: `thin consent refused: NativeThinConsent.Refusal.servedRootMismatch`. 11 of 66 rows, including the swapped-plan refusal, are not reached | thin-birth owner (a5343b507), via the coordinator |
| demo steps | JDISCLOSE | FAIL 7/20 on 76758dba6, with cd79cdaa3 in it; the run dies at `submit da1`. narrow-observe-only, narrow-mutate and narrow-owner refused `DeclaredResourceScalar.Reject.guardRejected 0` where law-denied is expected. unenrolled-1..3 give one frame but not "refused at challenge, bad-signature". d8-descent-hint has no hint line. `chat invite` now needs the full v3 recipient declaration, and `doc append` needs protected-document audience enrollment | JDISCLOSE owner a8a584cfddb80cad4 (lane red-jdisclose-scalar) |
| demo steps | JCHAT | 3/69 differ: the set has no `fake-discord` beside `mini-discord-mirror` | input |
| demo steps | M6, M7, JR17 | UNCONFIGURED: M6 needs the operator uid, M7 a reference build, JR17 /etc/mini/keys-client.json | |
| demo steps | J14 | L4b's | L4b |
| genesis writers (dregg-ref) | acceptance, application, selected-release, grain plain, grain PROVIDER_BOOTSTRAP, JPAY2 18/18 | PASS on 2d8b7ed54 and on 76758dba6 | |
| genesis writers | authority-acceptance | The prepare refusal now passes: exit 3, NO_RECORD 253, decoded law-denied naming subject 8's write clause. Then FAIL at :247-253 on both candidates: the post-denial view of resource 600 has `.cell.entries` [] where one entry, field 1 = "0", is expected. The world root, height and cell root match | a GLM, via the coordinator (not L1e) |
| effects (dregg-ref, 2d8b7ed54) | effect 19, dues 17, bounty 21, play 27, ballot 27, story 25, commons 20 | PASS 7/7 (failed [] each), the candidate's own `world/` | |
| apps | every app start on 2d8b7ed54 | the resident-start red (ns-owner pin, then op 7 controlGroup). Install itself passes: b1 SandMD birth/install/share exit 0 (25cfb86bd clears the install red) | un-ns-owner (fixed in 76758dba6) |
| apps | concurrent world-ups | 5 of 6 worlds started together died in the store phase with `consent refused: native durable read failed: sqlite-store error: opaque SQLite failure 15: locking protocol`. The failed worlds left orphaned codec/consent residents with no PID file | un-ns-owner (f02507d22: close-on-exec fds, residents get PID files) |
| apps | shared hbox world-up lock | Plain `flock /tank/lanes/world-up.lock CMD` hands its fd to world-up's long-lived servers, so a world holds the lock until it is torn down, and past world-down while residents survive. Every user switched to `flock -o` | |
| apps | featured (76758dba6) | 9 PASS of 13. PASS: EtherCalc lifecycle and write, DokuWiki lifecycle and write, Datasette lifecycle and recorded read, and the HedgeDoc, Davros and HledgerWeb lifecycles. FAIL: HedgeDoc write (socket.io `close frame`), Davros write and HledgerWeb write (no detail line), sntfy lifecycle (`get-m exit=22` on page /). Evidence: hbox:/tank/rows-76758dba-apps/q-featured/ | deputy |
| apps | b1 (76758dba6) | 7 PASS of 8. SandMD, Permanote and Dillinger PASS lifecycle and write; TextEditor lifecycle PASS, write FAIL (`Client did not complete authentication handshake.`, Meteor DDP) | deputy |
| apps | b2 (e89fe7b8b) | 3/6. YetAnotherTODO PASS lifecycle and write; ExpenseOwl lifecycle PASS, write FAIL (`POST /expense 405`); OrgTodo install FAIL (spk-ingest timeout); SandCal install FAIL (`SPK staging remains after unit success`) | deputy |
| apps | b4 (e89fe7b8b, market-large-v1) | 6/8. Hugo and HakyllCMS PASS lifecycle and write; WordPress and HackerCMS lifecycle PASS. WordPress write FAIL (`post-new.php 303, no REST nonce`); HackerCMS write FAIL (`www.sock GET /featured.html 404 after publish 200`) | deputy |
| apps | b6 (e89fe7b8b) | 4/6. SandForms and Badgepack PASS lifecycle and write. OwnTracks install FAIL (`pinned offline Mini Host author/inspect refused`); Hummingbird lifecycle FAIL (`get-m exit=22` on page /) | deputy |
| apps | rt (e89fe7b8b, market-large-v1) | 5/8. Gogs PASS lifecycle and write; WBO, HedgeDocRT and Wekan lifecycle PASS. WBO write FAIL (no detail line); HedgeDocRT write FAIL (socket.io `close frame`); Wekan write FAIL (DDP `loginRefused`: `Unrecognized options for login request`) | deputy |
| apps | fixups (e89fe7b8b, market-large-v1) | 0/3: OrgTodo install timeout; HackerCMS and HakyllCMS `SPK staging remains after unit success` (as SandCal in b2). The same two installed in the b4 world at the same moment. Suspected cause: concurrent worlds share one grains root (GRAINS_ROOT /var/lib/mini-spk-worlds/0000000000000000 on the 2d8b7ed54 genesis); not a recipe red | un-ns-owner (a6603277e4ffe2d70) |
| apps | totals | 34 PASS of 52 rows across seven tables. Owners of the reds: Hummingbird, WBO and Wekan go to B7 (abf203f357754001b); WordPress, HackerCMS write and ExpenseOwl go to B3 (a85d12892ea6de3ca); HedgeDoc/HedgeDocRT/IPython close frame goes to B8 (a13f0bc9626b1320a); OwnTracks goes to B5 (a0ef59eabda7075b4). These trees predate main's featured-qualify.sh 6b5f87872 (the owner gets allAccess, not role 0), which explained Davros, sntfy and HledgerWeb and may explain Hummingbird and WordPress. The open families are: socket.io/websocket `close frame` (HedgeDoc, HedgeDocRT, IPython), DDP login/handshake (TextEditor, Wekan), ingest timeout and staging under load, and per-recipe writes | deputy |
| apps (deputy) | japps --box | 28/29 on 76758dba6: co-edit and lifecycle PASS. Hacker Slides `PUT /slides.md 403` is the restart-renew gap | un-stale-enrollment (a4e312352a7091f59) |
| apps (deputy) | B8 | 0/4 on 2d8b7ed54 (resident start, plus IPython's importProfile harness bug, 50ec8de76). On 76758dba6: Mercurial lifecycle PASS and write PASS; IPython lifecycle PASS, write FAIL (kernel websocket `close frame`); MediaWiki and Firefly III rerunning | deputy |
| apps (deputy) | DiagramsNet | unsupported: declares permissions without a signed bridge schema (refused by name, 0870373ae); out of FEATURED | |
| apps (deputy) | B3, B5, B7 | running on 76758dba6 under `flock -o`; verdicts come from the deputy | deputy |
| oracle | joracle, Oracle v7 fresh world | not run: needs an app world after the lock queue drains | codex |

## 0a. Validator continuation (for the next validator)

**Boxes.**
- hbox (user `hbox`, full sudo, umask 002, operator account `mini-operator` uid 1001 with linger): journey
  rows, demo `--only`, app worlds, m6grain.
- dregg-ref (`lanes@2.31.71.194`, `~/.ssh/id_portable`, no `shasum`, no bun): the genesis writers and effects.
Neither box is the integrator's.

**Getting a candidate onto a box.** Stream it directly from dregg-build; the Mac's uplink is too slow.
- hbox reaches dregg-build as `ssh -i ~/.ssh/id_portable -o UserKnownHostsFile=<dir>/kh lanes@178.105.4.114`.
  Pull with `ssh ... "tar -C /build/candidates -cf - SHA" | tar -C <dir>/artifacts -xf -`, then
  `sha256sum -c SHA256SUMS` (about 5 min).
- Then push hbox → dregg-ref the same way: about 80 s.
- On hbox, also `cp -a` the set to `/build/candidates/SHA`. That is the manifest's absolute path and it is
  SHARED with the deputy's faeries: copy it in full only if it is missing, and never remove it. A faerie
  once deleted a partial copy mid-run.

**Per-candidate layout** (SHORT is the sha's first 8 characters):

| path | what it holds |
|---|---|
| hbox:/tank/dregg-build/rows-SHORT/ | `artifacts/SHA`; `box.env`; `rerun-row.sh ROW` (journey-runner --row from the covered tree); `run-journeys.sh` (all rows, results under `journeys-all/`); `demo-only.sh TAG STEP...` (one keep-going `journey.sh --only` run, steps copied to `demo-TAG-steps/`); `app-job2.sh NAME TABLE PROFILE` and `apps-all2.sh` (world-up under `flock -o`, then qualify, then world-down); `wait-pid.sh PIDFILE MARKER` (a cross-uid waiter: `kill -0` on a mini-operator PID fails EPERM as hbox and reads as dead); `mo/` (mini-operator-owned logs and PID files); `logs/`; `*.pid` |
| hbox:/tank/dregg-build/claude-lanes/rows-SHORT/src | the candidate's source.tar plus main's `scripts/spk-platform` overlay. This location is covered by /etc/sudoers.d/mini-operator. `deploy/spk-host/{controller-world.py,install-user-world}` are chowned root |
| hbox:/tank/rows-SHORT-apps | worlds and qualify output, mini-operator 0755 directly under root-owned /tank (`sudo install -d -o mini-operator`) |
| dregg-ref:/build/lanes/rows-SHORT/ | `cand/SHA`, `src` (its source.tar), `accept-job.sh` (the six writers, grain rows serial, then JPAY2 with `/build/lanes/custody-b/venv/bin` first in PATH), `effects-job.sh` (the seven effects with `--method` for dues and commons), `accept/`, `logs/` |

Live roots: rows-2d8b7ed5, rows-76758dba, rows-e89fe7b8. The 0ce31391 roots are kept for evidence.

**App worlds: the rules this run paid for.**
- Start worlds one at a time.
  - Concurrent world-ups hit `sqlite-store error: opaque SQLite failure 15: locking protocol` in the store
    phase.
  - Every hbox world-up, the deputy's included, takes `flock -o /tank/lanes/world-up.lock`. Plain `flock`
    without `-o` passes the lock fd to world-up's long-lived servers, so a world holds the lock until it
    is torn down.
  - Until e44a4a75c / 3a8109059 is in a candidate, the codec and consent residents also survive
    world-down, so the lock stays held. The coordinator stops those survivors by exact PID. Check with
    `sudo lsof /tank/lanes/world-up.lock`.
- Run the qualify phases one at a time as well, not only the world-ups: concurrent worlds are suspected of
  sharing one grains root. Overlay ALL of main's `scripts/spk-platform` (featured-qualify.sh included).
- The fixups (OrgTodo, HackerCMS, HakyllCMS) live in b2/b4. A separate `fixups.tsv`, relettered j/k/l,
  runs them on their own world.
- `QUALIFY_STOP=1` does not stop the table at the first red; featured ran all 13 rows in about 68 min.
- Class L tables (b4, rt, b8, fixups) need 50ec8de76's importProfile. It is in e89fe7b8b; overlay it on
  older candidates.

**Demo row.** Its 5,000 s budget reaches about 22 of 45 steps on a loaded hbox, so run every later step with
`--only`, two or three keep-going runs in parallel.

**Acceptance scripts.** Use the env in docs/ONE-WIRE-STATE.md. On dregg-ref, authority-acceptance uses
evidence.sh's `sha256`, so it runs there too.

**Open at hand-off.**
- The app tables have run (section 0). Plain-flock waiters were stopped with ember's approval.
- Rerun JDISCLOSE once its owner pushes.
- Rerun JP2 once thin consent's servedRootMismatch is fixed.
- Rerun authority once the zero-field view is fixed.
- Run joracle and the Oracle v7 fresh world on an operator-appliance-v1 world once the lock queue drains.
- Run japps restart/renew on the candidate carrying un-enroll-renew.

## 1. The gate (integrator's; listed so nothing is lost)

| row | proves | command | world | owner | last known |
|---|---|---|---|---|---|
| jtour / JWF (`jweb-frontend.sh`, incl. `tour-chromium` = `jtour.mjs`) | the web tour a stranger walks: login, /tour, step 4 `can DOC`, the terminal pane, lose-reply, exact retry, `can --any` | integrator's `/build/lanes/integ4/gate-cut*.sh` (`tour-run*.sh`); by hand `JS "WEB JWF"` | template (J0) | integrator; web lane | cut 7 `3315a908` 2026-10-27 16:03Z: 38 PASS / 1 FAIL (`tour-chromium`: `page.waitForSelector: Timeout 60000ms exceeded`) |
| composed scenario (`composed-full*.sh` -> `composed-inputs.sh`, `composed-scenario.py`) | rooms, churn, documents, apps, connector, residents, restart in one world | integrator's gate script; `composed-inputs.sh WORLD-IDENTITY.json CANDIDATE OUT` | genesis carrying `grainPlatform` (re-genesis) | integrator; L13 for apps | cut 7: FAIL. rooms/churn/restart pass; documents:protected and :ordinary blocked; apps "no apps input supplied"; connector, residents blocked |
| enrol-resume acceptance | five members enrol back to back; a pinned plan admitted across two ticks (step 7) | `bash $T/native/resource-client/enrol-resume-acceptance.sh $C/bin/minidregg-host $C/bin/mini $C/bin/minidregg-link-sqlite-store VERIFIER NEW_DIR` | genesis | custody-drivers; integrator chains it | PASS on cut 7 (`182e5494`, `f7e4c032`) |

## 2. Demo journey rows (`scripts/pipeline/journey-rows`)

| row | proves | command | world | owner | last known (a94bed71, 2026-10-27 unless noted) |
|---|---|---|---|---|---|
| journey | J0-J8 + rotation/audit steps, one fresh Store | `JR journey` | template | L2 shell / custody-drivers | FAIL 622 s, frontier J1 (seal) |
| demo | `JOURNEY_SET=demo` (SPINE + 51 demo steps incl. JPRIV1, JCHAT, JFEEDBACK, J14, WEB, JWF, M3-M8, JPAY*) | `JR demo` | template | L9 / per step | FAIL 1088 s, 6/40, frontier J1 |
| rooms | J1-J5 + JPRIV1 room lifecycle (K10C, JPRIV1 229 rows) | `JR rooms` | template | custody-drivers | FAIL (J1 shadow); K10C and JPRIV1 229/229 PASS by hand on cut 7 |
| activity | objective activity native acceptance (314 rows) | `JR activity` | template | un-effects | PASS 147 s |
| seats | 92 seat rows | `JR seats` | template | un-seats | PASS 50 s |
| bounty | 190 bounty rows | `JR bounty` | template | un-effects | PASS 229 s |
| call | 63 rows | `JR call` | template | world lane | PASS 41 s |
| send | 192 rows | `JR send` | template | world lane | PASS 91 s |
| domain | 58 rows | `JR domain` | template | world lane | PASS 66 s |
| upgrade | 38 rows | `JR upgrade` | template | world lane | PASS 24 s |
| objectrecord | 39 rows | `JR objectrecord` | template | world lane | PASS 25 s |
| chargedfailure | charged-failure rows | `JR chargedfailure` | template | L2 successor | PASS 22 s |
| objective | world-kind mutations (needs the tip's lean env) | `JR objective` with `LEANENV=1` | template | world lane | UNCONFIGURED: no lean env for this tip |
| hostupgrade | a world born by the PREVIOUS candidate opened by this one | `JR hostupgrade` (needs the previous candidate's set under `$ARTIFACT_ROOT`) | genesis (previous binaries) | L1 platform | UNCONFIGURED: missing previous candidate input |
| welcomecontinuity | enrolment by welcome from the sponsor's genesis | `JR welcomecontinuity` | genesis | custody-drivers | FAIL 6 s at enrollment-seal |
| sshe2e | four publickey logins through sshd | `JR sshe2e` | genesis, owed a template | infra / L2 | PASS 11 s |
| m3 | provisioning and cold reopen (`reopen-create`) | `JR m3` | template | L2 | FAIL (seal) |
| m4 | shell J0-J8 over ssh, nine PASS verdicts | `JR m4` | template | L2 | FAIL J1 (seal) |
| hermes | Hermes room rows, subjects 8/9 | `JR hermes` | template | L4 Hermes | FAIL 14 s (`services stopped`) |
| m6grain | grain world keyed by storeTag | `JR m6grain` (sudoers rule for the run's src, operator uid 1001) | genesis, owed a template | L13 / infra | FAIL on 23861533 (`o50/results-m6d`, 15:55Z: `cannot read key file`); UNCONFIGURED on a94bed71 (operator account) |
| m7 | reproducible build against a reference | `JR m7` with `M7_REFERENCE` | genesis | M7 lane | UNCONFIGURED here; PASS on dregg-ref round 2 (26 outputs) |
| m8 | fleet journey | `JR m8` | template | fleet lane | FAIL (seal) |
| fleetsign | fleet signing journey | `JR fleetsign` | template | fleet lane | FAIL (seal) |
| jserve | serve timing step | `JR jserve` | template | L2 | FAIL (blocked by J4) |
| jbend | Objective Bend frontend row | `JR jbend` | template | un-bend | not run on any candidate (row newer than a94bed71) |
| exchange | fn exchange, two domains | `JR exchange` (`MINI_FN_LAUNCHER`) | template | fn | UNCONFIGURED by name: fn is out of this demo |
| kernel (nightly) | `JOURNEY_SET=kernel` | `PIPELINE_NIGHTLY=1 JR kernel` | template | L9 | nightly only; no run on record |
| growth (nightly) | 1000 records, judged on updates | `PIPELINE_NIGHTLY=1 JR growth` (dregg-build SSD only) | template | hot-path | last: FAIL write p99 10 s at 1000 (PIPELINE-HBOX) |

## 3. App qualification

`featured-qualify.sh WORLD.env OUT [LETTER...]` on a `WORLD`; a batch adds
`QUALIFY_TABLE=scripts/spk-platform/market-batches/<b>.tsv` (its writes are sourced from
`market-writes/*.sh`). Class L apps need the world brought up with `MINI_IMPORT_PROFILE=market-large-v1`
(Wekan, WordPress), the oracle with `operator-appliance-v1`. Each app is two rows: lifecycle (create,
install, share, start, enrol, page) and one write beneath the HTML. All recipes are reasoned, none
proven live (lane/app-recipes rewrote the 2026-10-27 reds: HedgeDoc over socket.io, DokuWiki with the session cookie and every hidden form field, Hledger over `PUT /add`, Datasette a recorded read that PASSES, Hugo/Hakyll/OrgTodo/YetAnotherTODO/SandCal from their package sources; HakyllCMS's START exit and HackerCMS's missing bridge config are named in `market-writes/b4.sh`). Owner: L13 app market (successor of lane/app-market; batch lanes app-batch-*). Last runs:
dregg-build 2026-10-27 20:36-21:13Z on w11 / `app-batch-*-runs`.

| row (app) | table, letter | command extra | lifecycle | write |
|---|---|---|---|---|
| japps `--dry` | (a..c) | `bash $T/native/resource-client/journey.d/japps.sh --dry $C/bin` (Mac ok) | 18/18 PASS | n/a |
| japps `--box` incl. the co-edit row (tour step 7; un-stream-continuity) | Simple Todos second browser | `JAPPS_WORLD_ENV=$RUN/WORLD.env japps.sh --box $C/bin` | 26/27 on w6 | co-edit FAIL: `authority handoff requires an opening read from the Store` (`ApplicationStreamContinuity.lean:216`) |
| Etherpad, Hacker Slides, Simple Todos | japps a..c | (above) | PASS on w3/w5/w6 | Hacker Slides publishing socket PASS |
| EtherCalc | featured j | | PASS 741 s | PASS (`PUT /_/featured` 201, CSV 200) |
| HedgeDoc | featured k | | PASS 938 s | FAIL `POST /new` 400 (package defect named) |
| Davros | featured l | | FAIL 1053 s | not reached; DAV tree in `dav.sh` |
| sntfy | featured m | | FAIL 1181 s | not reached |
| DokuWiki | featured n | | PASS 1766 s | FAIL (save failed) |
| Hledger Web | featured o | | not reached | not reached |
| Datasette | featured p | | not reached | read-only by design (records the read) |
| SandMD, Permanote, TextEditor, Dillinger | b1 j..m | recipes on `lane/app-batch-1` (unmerged) | PASS 931/1015/1335/1198 s | FAIL "recipe not yet probed" (recipes now written) |
| YetAnotherTODO, ExpenseOwl, OrgTodo, SandCal | b2 j..m | | PASS 794 s, PASS 1059 s, FAIL 257 s, PASS 1547 s | FAIL x3 (OrgTodo not reached) |
| Hugo, WordPress, HackerCMS, HakyllCMS | b4 j..m | WordPress: `MINI_IMPORT_PROFILE=market-large-v1` | FAIL (ingest timeout 436 s), PASS 1009 s, FAIL (`bridge-only SPK lacks signed config`), FAIL (resident exited before START) | WordPress FAIL "recipe pending" |
| SandForms, OwnTracks, Badgepack, Hummingbird | b6 j..m | | PASS 850 s, FAIL (bridge, install), PASS 1045 s, FAIL (bridge, install) | FAIL "recipe pending" x2 |
| WBO, HedgeDocRT, Wekan, Gogs | rt j..m | Wekan: `MINI_IMPORT_PROFILE=market-large-v1` (refused `SPK exceeds decoded bound` under standard) | PASS 936 s, FAIL 525 s, FAIL 167 s, PASS 999 s | FAIL "recipe pending" x2 |
| IPython Notebook | b8 j | `QUALIFY_TABLE=scripts/spk-platform/market-batches/b8.tsv`; world with `MINI_IMPORT_PROFILE=market-large-v1` (186 MB spk, 668 MB unpacked); write = kernel started over REST, one cell executed over the kernel websocket (`jupyter-exec.py`), `featured.ipynb` saved and read back | not run | not run (recipe written, lane/app-recipes) |
| DAV rows (Davros WebDAV tree, SandCal CalDAV probe) | `market-writes/dav.sh` | a candidate carrying `dfdecbbac` (on main) | not run | not run |
| member install debit (`apps-e2e.sh`) | | `MEMBER_FUNDING=10000 APPS_MAX=50000 apps-e2e.sh $RUN/WORLD.env OUT <appIds>` after `mini apps bootstrap` | not run (needs lean-l13-laws in the candidate) | debit into INSTALL.md §4 |

### Generic whole-store sweep (cx-store-sweep, 2026-10-28)

`store-sweep.sh` now covers the entire public index through the real grain lifecycle, with
seven apps per world, no app-specific writes, candidate/package-scoped resume, and checked
serial teardown. On hbox, candidate `aae3e2e372b045dd43493183144db08212d51659` (carrying the
76758dba6 install/start fixes) judged **22 of 98 apps: 20 PASS, 2 FAIL**. This is three full
worlds plus the earlier one-app smoke; a targeted retry selected the native large import
profile for a package exceeding the standard segment limit. The run's stages, refusals and
evidence paths are in [the TSV](evidence/2026-10-28-store-sweep/verdicts.tsv), with
[run details and continuation](evidence/2026-10-28-store-sweep/README.md).

The candidate-shipped `deploy/market/store-qualification.json` supplies `mini apps search`
and `show` with package-specific lifecycle evidence. It does not change local ingest authority
or certify app writes. **76 apps remain unswept**; the same output root resumes them in 11
worlds. Owner: cx-store-sweep; [runner instructions](../scripts/spk-platform/STORE-SWEEP.md).

## 4. World-native effects rows (un-effects; `docs/evidence/2026-10-27-world-native/EFFECTS-STATE.md`)

Run on a worktree at the candidate's commit, one `swarm-build`, PID file. Evidence under
`docs/evidence/2026-10-27-world-native/<domain>/`. Owner: un-effects (via the untouched-areas deputy).

| row | command | last known |
|---|---|---|
| cohort gate | `bash scripts/check-world-cohorts.sh` (`WORLD_COHORTS_ONLY="world/dues world/bounty world/play world/ballot world/story world/commons"`) | not run since the protocol rewrite (four rows renamed) |
| effect (satisfiable, teeth, purse-as-submitter, law-refused) | `scripts/world-native-admit.sh activity --route activity --scenario effect --method world/activity/Effects.obend --entry effects --deposit 100000000` | not run |
| dues | `scripts/world-native-admit.sh dues --route activity --scenario dues --method world/dues/StandingDues.obend --entry dues --deposit 300000000` | earlier dues evidence exists (`dues/`, pre-protocol); not run on the kernel protocol |
| bounty | `scripts/world-native-admit.sh bounty --route activity --scenario bounty --method world/bounty/BountyBoard.obend --entry bounty --deposit 300000000` | not run (scenario still to write) |
| play | `scripts/world-native-admit.sh play --route activity --scenario play --entry play --deposit 300000000` | not run (scenario still to write) |
| ballot | `scripts/world-native-admit.sh ballot --route activity --scenario ballot --entry ballot --deposit 100000000` | not run (scenario still to write) |
| story | `scripts/world-native-admit.sh story --route activity --scenario story --entry tell --deposit 100000000` | not run (scenario still to write) |
| commons | `scripts/world-native-admit.sh commons --route activity --scenario commons --method world/commons/ResidentServiceCommons.obend --entry lifecycle --deposit 100000000` | not run (scenario still to write) |

## 5. Hermes (L4; `deploy/hermes/README.md` "State"; dregg-build sudo rule binds run dirs to `/build/lanes/hermes-live-run/`)

| row | proves | command | world | owner | last known |
|---|---|---|---|---|---|
| J14 pool route | Hermes as librarian on the ACP resident: summon, grain create, asks, no-grant, topup, dismiss | `J14_ROUTE=pool J14_TIER= /build/lanes/hermes-tier-run/run-j14-tip.sh /build/lanes/hermes-live-run/NAME` (candidate: set manifest, binaries and the manifest's `shell` in the script header) | J14's own (unit `mini-grain-controller@9870001`, one at a time) | L4 | PASS 153/153, run 24, lane/hermes |
| J14 subscriber tier | subscribe, pay, concierge window, join, summon on `glm-5.3-flash`; over-cap refused `member-day-ceiling` | `J14_ROUTE=zai J14_TIER=1 .../run-j14-tip.sh ...` (hook bound now 5400 s) with lane/hermes `2dfefa66` + `bcd78780` | as above | L4 | tier-7 (0b35fbac): 167 rows before the 3600 s timeout; rerun expected to clear rows 134/135, 148/150, 167/168; expiry rows never reached |
| redteam (J14 block) | stranger injection: planted calls refused, grants unchanged, turn bound | J14 with the redteam binaries (`lane/redteam-q2`, b7b1a87c) | as above | redteam lane | FAIL 7/173 (`redteam-j14-2`): planted calls 0-3 leave no controller result; call 7 not performed; `created-by` grep; 8 paid turns against a bound of 4 |
| grain-runtime `a_failed_prompt` | a failed prompt refused by its typed record is closed, not left pending | integrator: `cargo nextest run -p minidregg-grain-runtime -E 'test(a_failed_prompt)'` (lane/hermes `2dfefa66`, unmerged) | none | L4 | not run |

## 6. Payment and acceptance

| row | proves | command | world | owner | last known |
|---|---|---|---|---|---|
| jpay (JPAY1-4, JPAY6) | pay family on devnet | `JR jpay` | genesis, owed a template | L1 / pay lane | a94bed71: JPAY1-4 PASS, JPAY6 UNCONFIGURED; JPAY6 a known red on main |
| JPAY2, JPAY6 on `scenario-genesis.sh` (frame v8) | genesis via the shared writer | `JS "JPAY2"`, `JS "JPAY6"` (or `--only`) | genesis | custody-drivers | not run since `0153d8ae8`+`95214d02c` |
| acceptance.sh, application-acceptance.sh, authority-acceptance.sh, selected-release-acceptance.sh | the four scenario acceptances through `scenario-genesis.sh` | `bash $T/native/resource-client/<name>.sh` with the candidate's binaries | genesis | custody-drivers | not run since the conversion |
| grain-runtime acceptance (plain, `PROVIDER_BOOTSTRAP=1`, profiled) | grain runtime through the shared genesis | `bash $T/native/grain-runtime/acceptance.sh` x3 | genesis | custody-drivers | not run |
| jpay6 extractors: bootstrap-native-controller, journeys/byok-native (+`--ssh`), inference-scheduler native-journey and native-two-member | jpay6's genesis seam | each driver with the candidate's binaries | genesis | custody-drivers | not run |
| fn-e1e2 setup-mini | fn setup through the shared writer | `bash $T/scripts/fn-e1e2/setup-mini.sh` | genesis | custody-drivers | not run (fn out of the demo: low priority) |
| per-subject request rate | `requestRate.limit 3`: the 4th signed read in the window refused `rate-limited` with its retry; another subject and the exempt sponsor admitted at that moment; after the window admitted | `JR rate` (driver `native/resource-client/rate-journey.sh`) | genesis with `requestRate` | product deputy | row written (lane/snipe-rate-row); never run |
| mainnet pay-to-enrol | one real 50 DREGG enrolment | demo box only | the demo | ember / infra | not the validator's (never the demo box) |

## 7. Oracle (codex; `docs/ORACLE-GRAIN-2026-10-27.md`, `docs/evidence/oracle-*-2026-10-27.md`)

| row | proves | command | world | owner | last known |
|---|---|---|---|---|---|
| focused harness checks | generated operator/genesis JSON; allocation guard | `python3 -B scripts/test-oracle-agent-lifetime-journey.py HarnessTests.test_complete_grain_store_configuration_before_bootstrap HarnessTests.test_actual_factory_allocation_guard` | none | codex | 5 focused checks PASS on dregg-ref at ce27ff402 (5.422 s); native qualification remains below |
| lifetime-grant fixtures | the three-capability grant; ordinary template refuses it | `lake env lean tests/lean/LifetimeGrantObserverAdversary.lean`, `...LifetimeGrantSourceAdversary.lean`, `Host/NativeLifecycleConsent.lean`, then `scripts/codec-shapes-regen.py` (integrator's, central build) | none | codex / integrator | per-file exit0 on c77ef2f9 epoch; source adversary not rerun |
| joracle | the oracle lands as a grain via the market; one bounded question answered on its origin; stopped | `MINI_IMPORT_PROFILE=operator-appliance-v1` WORLD, then `joracle.sh --box WORLD.env OUT RUNTIME.spk DATA_SOURCE_DIR INVENTORY.json` (dataset 14.01 GiB, inventory `32bb3cf1...`) | WORLD | oracle-grain lane | result in the lane report only; not on record here |
| Oracle v7 fresh world | a fresh Store qualified through agent calls (grant issue, dispatch, answer), authority refusals, browser use, restart and exact retry; old stopped Stores preserved | `scripts/oracle-shared-data-journey.sh BASE_BIN OWN_BIN NEW_RUN_ROOT SIGNED_RUNTIME_SPK DATA_SOURCE INVENTORY_JSON` with the inputs below; candidate includes oracle-grant-factory + oracle-lifetime-grant (genesis v8, outcome v7) | genesis | codex | 28 Oct: Store `a64d135a102a1951` passed both installs, data publication/share, native session birth (acceptedCount 43), lifetime grant (50), and START (53). Stopped enrollment exposed a v3 reply decoder mismatch; fixed in `b81a38663`. Same-Store recovery underway; downstream agent/browser/restart checks remain open. |
| Hermes Oracle composition | the room's own Hermes task discovers and invokes Oracle, obeys its grant, and answers after restart | `J14_ORACLE=1` with the inputs in `deploy/hermes/README.md` | J14's own Store and tasks | codex | 28 Oct: existing world continuing after a transport endpoint config-pin failure. Native resident initialization/enrollment repair `733cc4649` passed 10 enrollment tests and 1 initialization test; composed native result remains open. |

### Oracle appliance

Owner: `lane/oracle-grant-factory` (provisioning), with the integrated
`lane/oracle-lifetime-grant` repair. Native session birth and lifetime grant now pass;
the complete hosted qualification remains open. The active run is retained at
`/build/lanes/oracle-v7-q3-20261028/oracle-run`, using coherent candidate
`aae3e2e372b045dd43493183144db08212d51659` with recorded runtime overlays.
The exact-Host STOP prerequisite passed all 11 lifecycle phases and all four
negative controls; its copied-Store benchmark is
`/build/lanes/oracle-v7-q-20261028/stop-copy3/probe/benchmark.json`.
Use a coherent build and its resource wrapper for a new run. Preserve failed
runs and their admission receipts when continuing an existing Store.

- Elaborate `tests/lean/LifetimeGrantObserverAdversary.lean`,
  `tests/lean/LifetimeGrantSourceAdversary.lean`, and direct importer
  `Host/NativeLifecycleConsent.lean` after the coherent dependency build.
  Run `python3 scripts/codec-shapes-regen.py` through the normal codec workflow.
  Build matching Host and consent binaries. See
  [grant evidence](evidence/oracle-lifetime-grant-2026-10-27.md); the earlier
  scoped results are not qualification of this main.
- The focused provisioning checks below passed at `ce27ff402` on dregg-ref
  (5 tests, 5.422 s). They cover emitted configuration and fixed phases; their
  mock transport does not admit a native birth. Repeat only if integration
  changes those inputs.
- Run a **fresh** `scripts/oracle-shared-data-journey.sh` with signed Oracle v7,
  its matching published data inventory, matching Host/consent/native helpers
  (genesis-source v8 / outcome v7), and current SPK host/runtime/broker/helpers.
  Obtain `ORACLE_STOP_BENCHMARK_JSON` for the **new exact Host binary**: the
  previous receipt cannot be reused after rebuilding Host. Preflight now
  rejects a stale or failed receipt before any Store/data work. Set
  `ORACLE_POOLED_TENANT_PROBE=1` and `ORACLE_BROWSER_B=1`, and supply the qualified
  `ORACLE_CADDY_BIN`, `ORACLE_CADDY_SHA256` and private `ORACLE_BROWSER_PORT`.
  The script takes `BASE_BIN OWN_BIN NEW_RUN_ROOT SIGNED_RUNTIME_SPK DATA_SOURCE
  INVENTORY_JSON`; use retained immutable inputs, a new run root and the normal
  bounded operator unit. Preserve both old stopped Stores and their evidence.
  Arrange the real browser driver before launch: at `RUN/browser/ready.json`
  the journey waits for bootstrap, rendered UI, catalog/query and origin/auth
  controls, then a retained result. See
  [browser instructions](../deploy/oracle/acceptance/BROWSER.md). Setting
  `ORACLE_BROWSER_B=1` alone does not drive a browser.
  Acceptance includes grant issue, actual agent discovery/invocation, authority
  refusals, private tenant state, the browser path, restart, exact retry,
  stale-context refusal, STOP/data boundaries and cleanup. Report performance
  separately; the 32-tenant adapter receipt is not hosted authentication evidence.

```sh
python3 -B scripts/test-oracle-agent-lifetime-journey.py \
  HarnessTests.test_complete_grain_store_configuration_before_bootstrap \
  HarnessTests.test_actual_factory_allocation_guard \
  HarnessTests.test_fixed_allocation_guard \
  HarnessTests.test_allocation_old_and_oracle_validate_without_native_work \
  HarnessTests.test_fixed_agent_birth_phase_preserves_existing_resources
```

The actual shell preflight regression also passed on dregg-ref (one test,
three receipt cases, 0.171 s): `python3 -B scripts/test-oracle-journey-preflight.py`.
Logs: `/build/lanes/oracle-enrollment-ce27ff402/{focused,preflight}.log`.

For the shared template, exercise matching duplicate policy
values and conflicting `grainPlatform`/`operatorPolicy` settings, and the ordinary
scenario-genesis callers. No second genesis writer should be restored to make
a fixture pass.

Also exercise `spk-platform/prepare.sh` / `run-base.sh` with the existing signed
GitWeb fixture and coherent binaries: they now use structured policy and current
lifecycle settings, with full qualified/generated config equality before
bootstrap. The composition fixture includes matching and mismatched expected
configs. Separate application-session source generation remains unchanged;
the Oracle journey uses `grain-store.sh`.

## 8. Private compute

| row | proves | command | world | owner | last known |
|---|---|---|---|---|---|
| jprivate | the private-computation door; plants `JPRIVATE_PLANT=leak` and `drop-label` go red | `JR jprivate` (or `jprivate.sh BIN-DIR` with `mini` and `mini-private-compute`) | none (local computation) | product deputy (pd-private-compute) | not run on any candidate |
| JPRIV1 + jprivate-docs | private room keyed and rotated on kick; private documents on the same Store | `JS "JPRIV1"` then `jprivate-docs.sh` | template | custody-drivers | JPRIV1 229/229 on cut 7; jprivate-docs not run |

## 9. Feedback

| row | proves | command | world | owner | last known |
|---|---|---|---|---|---|
| JFEEDBACK | a member reports into its own `feedback-NAME` room; the operator reads it; no member reads another's | `JS "JFEEDBACK"` (`--only JFEEDBACK`) | template (J0) | product deputy (pd-feedback) | not run on any candidate; day limit (10/day) not built; `--via discord` not in the row (header corrected against the code, lane/snipe-rate-row) |

## 10. FOUC

| row | proves | command | world | owner | last known |
|---|---|---|---|---|---|
| check-fouc app | no light flash, settled chrome on the first frame, CLS < 0.02, no-JS chrome equal | `node scripts/check-fouc.mjs --only app --bin-dir <dir with mini-web, mini-web-spawn>` (Playwright, CPU x4) | none (fixtures) | no-fouc lane | not run on a candidate |
| check-fouc site | the same for `website/` | `node scripts/check-fouc.mjs --only site` | none | no-fouc lane | not run on a candidate |

## 11. Measurements (published, never a gate)

| row | measures | command | box | owner | last known |
|---|---|---|---|---|---|
| world templates on/off | journey wall with and without restored worlds | ONE-WIRE-STATE "The world template's before/after": `JOURNEY_WORLD_TEMPLATES=1` then `=0` over `journey-runner --tip`; publish `WALL_S(0) - WALL_S(1)` with both loads | dregg-build (timing) | custody-drivers | a94bed71: 1119 s off, 1089 s on, both cut short by J1's seal red |
| hot-path BEFORE/AFTER | cold open at ~500 and ~1.7k records; `checkpoint` verb then an open | `HOST CONFIG describe` paired cold opens on a world born under the candidate (HOT-PATH-STATE "Next" 3-4, lane/hot-path-v4) | dregg-build | hot-path | compaction: 189.4/193.7 s -> 69.1/64.1 s at 483 records (2026-10-27 20:11Z); v4 and 1.7k owed |
| generic-simplex load 200 | per-op timings over a 200-op busy run | `GENERIC_SIMPLEX_LOAD_OPS=200 scripts/gates/check-generic-simplex` (or `generic-simplex-load 200 10` from the Verify exe) | dregg-build (timing) | un-verify | 20-op run only (Mac, load ~240); 200 not run |
| births / perf | births bar; fresh-genesis perf | `JR births`, `JR perf` (quiet box) | dregg-build | L9 / hot-path | UNCONFIGURED on a94bed71: box not quiet |

## Unit-test registry notes (integrator's)

`scripts/gates/unit-tests.tsv`: `@known-red` `test_native_input_successor.py`, `test_ticket_preflight.py`;
`@elsewhere` `test_build_gate_boundaries.py`, `test_lean_build_surfaces.py`. Written-not-run Rust tests
from custody-drivers (ONE-WIRE-STATE "For the integrator"): `platform_install_is_the_operators_alone...`,
`one_export_per_cooldown...`, `pending_inbox_joins...`, `python3 scripts/test-host-operations.py`.
