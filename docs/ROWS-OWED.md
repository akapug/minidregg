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

## 0. Candidate 0ce31391 (validator run, 2026-10-28 02:00-03:40Z)

Run against `/build/candidates/0ce31391790a7e2ed9f83eb1b8bb85d6556a0de3`'s binaries on hbox
(journey rows, app worlds, FOUC, authority) and dregg-ref (effects, acceptance, oracle checks). Drivers
from the candidate's tree, with the row-harness fixes below and, where the coordinator asked, main's
scripts (effects: main bd37686c0's `world/` and drivers; jserve: lane/custody-b beb108d5f; grain-birth:
L1c 746b182d2). The gate (tour, composed) and enrol-resume are the integrator's: build green,
enrol-resume PASS.

Row-harness fixes this run produced (lane/rows-ledger, all merged or routed to the integrator):
7dfe4a3c4 (m4 provision folder 0700), b627478ec (native-share-member.sh worker-bare refused at prepare),
0a05ab6ba (journey classifiers match OUTCOME/v8), 709cd12d0 (acceptance.sh consent provider beside the
wrapper Host), 6ee5acb4c (check-fouc site pages), 96fc2701d (demo/kernel rows pass GRAIN_RUNTIME), the jnames.sh missing-reference pattern.

| group | row | result on 0ce31391 | owner of the red |
|---|---|---|---|
| journey rows | journey (J0-J8, rotation) | PASS 15/15 | |
| journey rows | activity seats bounty call send domain upgrade objectrecord welcomecontinuity m3 m8 fleetsign chargedfailure jbend jprivate rate hermes sshe2e m4 | PASS | |
| journey rows | jserve | PASS with custody-b beb108d5f (253 refusals named); red on the candidate's own driver (envelope v1) | custody-b |
| journey rows | jpay | JPAY1-4 PASS; JPAY6 FAIL `query parent-witness-tool-pre: request refused ... (phase observation)` | L1 / pay |
| journey rows | rooms | J5 red was the v7 classifier; J5 8/8 and JPRIV1 229 PASS on the fixed tree | |
| journey rows | m6grain | FAIL: with b627478ec the store phase passes; then `install-a` hits the grain-install red | L1c (25cfb86bd) |
| journey rows | objective, hostupgrade, m7, exchange | UNCONFIGURED: no lean env; no previous candidate set; no M7 reference; fn is out | |
| journey rows | births, perf | UNCONFIGURED (box not quiet; timing rows belong on dregg-build) | |
| demo steps | J0-J8, J12X, KC, KT, K10, KIX, K10C, K12C/T/M/R/I/H, JPRIV1, JFEEDBACK, J12W, THIN, JDV (143), M5, JNAMES, JPAYE1 (14/14), JPAYE2 (38/38), JPAYE3 (27/27), JRLANE, JGATE, JESC, JFLEETIN, JSLK, JAUDIT (11/11) | PASS (the 5000 s demo budget starves the tail; tail steps run with `--only`) | |
| demo steps | JP2 | thin birth arm (lane/thin-birth, Kernel.NativeThinBirth): row 19 asserts a successful remote create under thin consent, the lifecycle rows are restored, and a swapped birth plan is refused birthSourceChanged; not yet run against a candidate | L2 shell / thin consent |
| demo steps | JPD | FAIL row 3 `doc protect pd-paper`: `inspect object-audience ... is a session frame, not a codec frame (phase op 8)` | L2 shell |
| demo steps | JDISCLOSE | FAIL: invocation refused `DeclaredResourceController.Reject.scalar (undeclaredField 2)` | declared-resource owner (same family as acceptance.sh `unsupportedVersion`) |
| demo steps | JCHAT | 3/69 differ: the Discord mirror rows need `mini-discord-mirror` and `fake-discord` in one dir (the set has no fake-discord) | input |
| demo steps | M6, JR17 | UNCONFIGURED: M6 runs as the operator uid; JR17's key rows need /etc/mini/keys-client.json | |
| demo steps | J17 | FAIL: after a decided `bookRefused` pay, the next `pay lab week` says "a previous pay of this request was recorded but never submitted" | L1c prepare-refusal clients / pay |
| demo steps | WEB | FAIL 4/38: extra `unavailable` in transclusion placeholders (3 rows); `board-fields` 403 | L12 web |
| demo steps | JLI | FAIL: `law export show jli-room/notes` refused as a malformed reference name | L2 shell |
| demo steps | KTPL | FAIL 12/163: `room new lab --template workroom` runs no template lines; index links missing | L2 shell |
| demo steps | J12 | FAIL 1/139: row 87, index links to paper | L2 shell |
| demo steps | J14 | L4b's (J14_TOOLS/AWAIT on this candidate) | L4b |
| app tables | every world (b1, b2, b4, b6, rt, featured; standard and market-large) | BLOCKED: every install refused (`v3 BEGIN native reply ...`; in fact op69 claim assemble: "claim plan differs from original BEGIN", storeIdentity vs expectedSeed) | L1c, fix lane/prepare-refusal-clients 25cfb86bd |
| app tables | b8 IPython | refused `Too many or too few segments 583` | L13 |
| effects | effect dues bounty play ballot story commons | PASS 7/7 (19, 17, 21, 27, 27, 25, 20 rows) with main's world/ and drivers | |
| acceptance | acceptance.sh, selected-release-acceptance.sh | FAIL `invocation preparation: DeclaredResourceController.Reject.unsupportedVersion` | custody-b |
| acceptance | application-acceptance.sh | FAIL `sqlite-store error: published byte record is missing` | custody-b |
| acceptance | grain-runtime acceptance (plain, PROVIDER_BOOTSTRAP) | FAIL `authorityBatch` at prepare (custody-b reports PROVIDER_BOOTSTRAP fixed in dabf7afdd) | custody-b |
| acceptance | authority-acceptance.sh | FAIL :223, the denied write is refused at prepare (no call.bin); on the direct-binary route mini said "request status uncertain" (fixed in f73893fce) | L1c / custody-b |
| acceptance | fn-e1e2 setup-mini | UNCONFIGURED: no fn fixture tree (fn is out) | |
| oracle | focused harness checks | PASS 2/2 (test renamed `..._configuration_before_bootstrap`) | |
| oracle | joracle, Oracle v7 fresh world | BLOCKED on the grain-install red | codex |
| FOUC | check-fouc app, site | PASS 12/12, 12/12 | |
| demo seed | deploy/demo-seed/seed.sh | not run here: needs the demo-vm frame; infra runs it on a dregg-ref scratch root | infra |

Not this validator's (central or timing): templates on/off, births/perf, hot-path BEFORE/AFTER,
generic-simplex load 200 (needs the integrator's built Verify exe), lifetime-grant Lean fixtures,
cohort gate (needs a built Lean tree and bun).

## 0a. Validator continuation (for the next validator)

**Boxes and paths.** Journey rows, app worlds, FOUC and the authority acceptance run on hbox (user
`hbox`, full sudo, Ubuntu 24.10, umask 002, operator account `mini-operator` uid 1001 with linger).
Effects, the other acceptance scripts and the oracle checks run on dregg-ref (`lanes@2.31.71.194`,
`~/.ssh/id_portable`, no `shasum`, no bun, no grain-world sudo rules). Neither box is the integrator's.

| path | what it holds |
|---|---|
| hbox:/tank/dregg-build/rows-0ce31391/ | `box.env` (roots, `PIPELINE_JOURNEY_JOBS=3`, `PIPELINE_ROW_MEM_MAX=20G`, m6grain inputs: `MINI_OPERATOR_UID=1001`, `MINI_TEST_SPK`); `rerun-row.sh ROW` (one journey row from the covered tree, own results root `rerun-ROW/`); `app-job.sh NAME TABLE PROFILE` (world-up, featured-qualify, world-down) and `app-keep.sh` (the same without world-down); `demo-only*.sh` (journey.sh `--only` runs); `logs/`; every PID file; `pw/` (Playwright 1.62.1 and its Chromium under `pw/browsers`) |
| hbox:/tank/dregg-build/claude-lanes/rows-0ce31391/src | the candidate's source.tar, extracted where /etc/sudoers.d/mini-operator covers two-world-journey.sh and install-user-world; `deploy/spk-host/{controller-world.py,install-user-world}` are chowned root (install-user-world refuses a companion owned by neither root nor SUDO_UID) |
| hbox:/tank/rows-0ce31391-apps | worlds and qualify output, owned by mini-operator 0755 directly under root-owned /tank (world-up's scratch custody refuses any writable ancestor) |
| hbox:/tank/rows-0ce31391-hbox | an hbox-owned 0700 root for the acceptance scripts' evidence; run them under `umask 077` (hbox's umask 002 makes the Store's head-anchor directory group-writable and the store refuses it) |
| hbox:/build/candidates/SHA | a root-created, hbox-owned copy of the candidate at the manifest's absolute path (manifest.json and lib.sh name /build/candidates/SHA; a symlink fails "manifest .host does not name its candidate output"); box.env sets `ARTIFACT_ROOT=/build/candidates` |
| dregg-ref:/build/lanes/rows-0ce31391/ | `cand/SHA` (the set), `src` (its source.tar), `src-main` (src with main's tree overlaid), `effects-job.sh`, `effects-main-job.sh`, `accept-job.sh`, `logs/`, PID files |

Copy a candidate to a box by streaming it through the Mac:
`ssh dregg-build "tar -C /build/candidates -cf - SHA" | ssh BOX "tar -C DEST -xf -"`, then
`sha256sum -c SHA256SUMS`. On hbox also `sudo cp -a` it to /build/candidates/SHA.

**Main's scripts over a candidate.** When the coordinator says a harness fix is on main and the
candidate predates it, run the candidate's binaries with main's drivers. On dregg-ref:
`git archive <main> world scripts native/resource-client/... | tar -x` over a copy of the candidate's
tree (`src-main`), with `SRC=` set to that tree and the job cd'd into it. On hbox: copy the changed
files over the covered tree. Name every file taken from main in the report; anything in main's
scripts that disagrees with the candidate's binaries is reported, not mixed silently.

**Journey rows.** `rerun-row.sh ROW` runs
`journey-runner --tip SHA --row ROW --source-tree <covered tree> --results-root rerun-ROW` under
swarm-build. A full run is `run-journeys.sh` (about 6 min, 3 jobs). Each row runs in its own systemd
user scope, so its servers stop with it.

**The demo row's tail: run it with `--only`.** The demo row gives journey.sh a 5,000 s budget
(`PIPELINE_ROW_TIMEOUT_S` 5400 minus 400). On hbox JPRIV1 (1,146 s), KTPL (1,020 s) and J12W
(861 s) spend it, and every later step reports "journey wall budget spent". Take the demo row's
verdicts for the steps it reached, then run the rest in one fresh journey:
`JOURNEY_KEEP_GOING=1 GRAIN_RUNTIME=$C/bin/grain-runtime TEST_PROVIDER=$C/fixtures/mini-hermes-test-provider LAUNCH_GATE=$C/bin/launch-gate PAY_WATCHER_BIN=$C/bin/pay-watcher CANDIDATE=$C/provenance.json journey.sh --only STEP ... $C/manifest.json NEW_RUN`.
The flags come before the two positional arguments. journey.sh adds each step's dependencies itself.

**Effects.** `SRC=<tree> swarm-build bash scripts/world-native-admit.sh DOMAIN ... --candidate <set>`
(SRC is required: source.tar has no .git). dues needs `--method world/dues/StandingDues.obend` and
commons needs `--method world/commons/ResidentServiceCommons.obend`: each directory holds two .obend files.

**App worlds.** As mini-operator from the covered tree:
`MINI_IMPORT_PROFILE=P MINI_OPERATOR_UID=1001 MINI_OPERATOR_NAME=mini-operator world-up.sh BIN BIN RUN`,
then `QUALIFY_STOP=1 [QUALIFY_TABLE=market-batches/bN.tsv] featured-qualify.sh RUN/WORLD.env OUT`.
One world per table: featured (default table), b1, b2, b6 on standard-v1; b4, rt and b8 on
market-large-v1 (WordPress, Wekan, IPython). Seven worlds at once were fine on hbox (load about 20).
A world from a candidate whose install failed cannot retry the install (UNRESOLVED by design): use a
fresh world.

**Acceptance scripts.** env `CANDIDATE=$set/provenance.json MINI=$B/mini STORE_BINARY=$B/minidregg-link-sqlite-store SIGNATURE_BINARY=$B/minidregg-credential-signature-verifier GRAIN=$B/grain-runtime`.
Never set `MINI_CONSENT_HOST` alone (mini then demands `MINI_LOCAL_HOST` and `MINI_CONSENT_CONFIG` too).
authority-acceptance.sh needs `shasum`, so run it on hbox under `umask 077`.

**Next candidate (the first carrying 25cfb86bd and f73893fce): the plan.**
1. App tables on fresh worlds (all seven above) and `japps --box` including the co-edit row. Expected
   to clear the install red. Then the DAV rows, then joracle on an operator-appliance-v1 world, then
   the fresh Oracle v7 world (section 7).
2. The six genesis writers (acceptance, application, selected-release, authority, grain plain,
   grain `PROVIDER_BOOTSTRAP=1`) plus JPAY2. Use the commands and the PyNaCl venv note in
   docs/ONE-WIRE-STATE.md's state section (custody-b). The profiled grain mode is deleted (97aab6054).
3. Every red from section 0, by name:
   - journey rows: m6grain, JPAY6;
   - demo steps: J17, WEB, JLI, KTPL, J12 row 87, JP2, JPD, JDISCLOSE;
   - acceptance: authority-acceptance;
   - app worlds: b8's `Too many or too few segments`.
   Also check that the harness fixes listed in section 0 are on the candidate's tree.
4. The full journey-rows run and the demo `--only` tail, as above. JCHAT needs `fake-discord`
   beside `mini-discord-mirror`. M6 needs the operator uid. JR17 needs /etc/mini/keys-client.json.

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
| Oracle v7 fresh world | a fresh Store qualified through agent calls (grant issue, dispatch, answer), authority refusals, browser use, restart and exact retry; old stopped Stores preserved | `scripts/oracle-shared-data-journey.sh BASE_BIN OWN_BIN NEW_RUN_ROOT SIGNED_RUNTIME_SPK DATA_SOURCE INVENTORY_JSON` with the inputs below; candidate includes oracle-grant-factory + oracle-lifetime-grant (genesis v8, outcome v7) | genesis | codex | not run |

### Oracle appliance

Owner: `lane/oracle-grant-factory` (provisioning), with the integrated
`lane/oracle-lifetime-grant` repair. The five focused configuration checks now pass on
dregg-ref; native/grant and hosted qualification remain. Use the newest coherent main build and its
resource wrapper. Record actual outcomes here or link the validator run.

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
