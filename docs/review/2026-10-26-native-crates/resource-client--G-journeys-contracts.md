# resource-client shard G: journeys, acceptance scripts and prose contracts

| | |
|---|---|
| Shard | `native/resource-client` (the `mini` client crate), the non-Rust half: every `.sh`, `.py`, `.jq`, `.hoon`, `.c`, `.lean`, golden/expected text and loose file at the crate root and in `journey.d/`, `journey.d/lib/`, `journey-timers/`, `cohort-two-host/`, `channel-lib/`, `scripts/`, plus the 25 prose files at the crate root |
| Files covered | 227 files: 202 scripts and script data (45,250 lines) and 25 prose files (3,170 lines), plus the two loose files `crypto-transit-main.patch` (8) and `selected-release-drop-reply.rs` (95). Per-family counts are in section 6; per-file counts are in the section 1 tables |
| Total | 48,420 lines (scratch: `/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/rc-G/wc-all.txt`, `fam.json`) |
| Read in full | `README.md` (982), every root `*.md` and `*.txt`, `journey.sh` (1,180), `acceptance.sh` (474), `journey.d/bind.sh`, every file in `journey.d/lib/`, `docs/JOURNEY.md`, `genesis.sh`, `scripts/pipeline/journey-rows` (822), `scripts/local-gates.sh` (166), `scripts/check-journey.sh` (117) |
| Read as header + invocation lines | every other script. Each script's `mini` subcommands, Host CLI verbs, Host op numbers and referenced files were extracted by `tools/inv.py` and `tools/scan.py` in the scratch dir, then spot-read |
| External evidence used | `docs/evidence/` (339 entries); three GitHub Actions `gate-logs` artifacts of `.github/workflows/build.yml` on main, downloaded read-only to scratch `ci-39905192725/` (rev `307b13e`, 2026-10-23), `ci-39056305841/` (rev `334316d`, 2026-10-17) and `ci-38977292707/` (2026-10-16) |
| Date | 2026-10-26 |

## Executive summary

1. The journey corpus is 45.2K lines of scripts. That is larger than most Rust modules it tests. 87 `journey.sh` steps run 76 `journey.d` hooks; 30 runner rows in `scripts/pipeline/journey-rows` run 18 more drivers. 18 `journey.d` files and about 40 root scripts are wired to neither.
2. Only J0–J8 has repeatable PASS evidence on main: three CI runs (2026-10-16, 10-17, 10-23) pass J0–J8, J12X, JSERVE, G (write max 4.354 s, cold reopen 15.391 s at 1,000 records), K4, KT, JJ and K10. None of these results is in `docs/evidence/`.
3. The CI `journey` gate never finishes. `check-journey.sh:70` gives the journey a 14,400 s budget but `local-gates.sh:136` kills the gate at 10,800 s, so no `journey-result.json` is written. Every step after JMKT/K10C in run order (about 55 steps) has no recorded result on main.
4. KBW and KC fail in all three CI runs. KCHR and KCHC always fail because `check-journey.sh` never builds `libminidregg-channel.so`. JMKT fails because `jmarket.sh:177` uses a stale shell grammar, `enroll plan NAME KEY` with no next key. `j12w.sh:121` and `jdisclose.sh:48` carry the same line, so J12W and JDISCLOSE are broken the same way.
5. K12I is broken. `j12i-links.sh:222,233` calls the Host CLI verb `link-index`, which a merge dropped from `Host/Main.lean` (`a26328e9`); `presence-index` survives at `Host/Main.lean:7917`.
6. In the 10-23 run, K11 hung for 3,600 s and left the world service dead. The next 17 hooks then failed with "Connection refused", because `journey.sh` checks service liveness only after a hook succeeds (`journey.sh:995-997`).
7. `acceptance.sh` is broken: it sends content targets with `"schemaVersion": "1"` (`:222`, `:337`), while `Kernel/ContentResource.lean:432` is `commandVersion := 10`. `TRAFFIC-PRIVACY.md:206-208` records `selected-release-acceptance.sh` failing for this reason. `journey-timers/ticker.sh` waits forever for `$W/public/mini.sock`, which `journey.sh:158` no longer creates. `native/resource-client/scripts/cohort-native-tcp.py` passes `--key` where `mix-live` now requires `--roster`.
8. M6 is permanently UNBUILT (no `journey.d/m6.sh`, pinned in `scripts/gates/journey-unbuilt.tsv`). JJOB1, JJOB, J14 and J17 need environment variables that `check-journey.sh` never supplies, and their step functions do not call `needs_env`, so they record FAIL instead of UNCONFIGURED.
9. JPD (`jprotected-docs.sh`) runs `scripts/protected-document-journey.sh`. That script's own header says it "has only had bash syntax checking; it does not claim a completed journey".
10. The prose is mostly construction diary, not present-state contract. Six `.txt` files and the dated tails of COHORT-TCP, PQ-MAILBOX, TRAFFIC-PRIVACY, PAID-COLD-ENTRY, MEMBER-WORKSPACE and APPEND-PROOF are appended run logs. Several contradict code or each other: PQ-MAILBOX says the handshake is "MCE2", the code is MCE4 (`cohort_tcp.rs:425,691-694`); TRAFFIC-ENROLLMENT says "pure ML-KEM768", the code is hybrid; `qualification/pq-native-pipeline.py` does not exist.
11. The root README "Honest state" rows are stale against current wiring. Row 85 says no journey row runs the call/send drivers, but `journey-rows:105-133` has run them since `f5897dd8` (2026-10-07). Row 79 says main fails J5 and J8, but every CI run since 10-16 passes both.
12. Twins are everywhere:
    - lost-reply proxies (`hostraw.py proxy`, `selected-release-drop-reply.rs`, `selected-source-drop-reply.sh`, the generated `drop-first-submit.sh` in `acceptance.sh`, the `proxy.py` heredoc in `welcome-continuity-journey.sh`, the fault relay in `jpay-v2.sh`)
    - about 15 inline copies of the Host socket frame encoder
    - two `cohort-native-tcp.py`
    - `jprivate-docs.sh` and `scripts/protected-document-journey.sh`
    - four continuity journeys with an identical 30-line preamble
    - three legacy acceptance scripts that `docs/JOURNEY.md:26-29` already deprecates as gates
13. `genesis.sh` and `genesis-params.example.json` are not test scripts. `deploy/candidate/package.py:106-107` ships them as the production genesis template. `genesis.sh` hand-writes the genesis JSON in jq with a hard-coded permit-all `factoryPredicate` and `accountPredicate` (`genesis.sh:125,136,146`): an imitation of a Lean-owned structure, and a semantic default chosen in shell.
14. A demo-only kept set (J0–J8, M3/M4 shell, J12/J12W documents, J12X/JSERVE/JRLANE/JDISCLOSE/JAUDIT hardening) is about 4.5K lines, about 10% of the corpus. Everything else can be deleted or moved to its owning lane. Section 6 lists it by file.
15. The loose files are wired: `crypto-transit-main.patch` is already applied (`src/main.rs:90-92`) and should be deleted; `selected-release-drop-reply.rs` is compiled at run time by `selected-release-acceptance.sh:381` and goes when that script goes.

---

## 1. What this code is and does

### 1.1 The framework: `journey.sh`, its hook contract, the runner and the CI gate

**`journey.sh` (1,180 lines)** is the self-declared "definition of done" (`journey.sh:2`, `docs/JOURNEY.md:1-4`). It is called as `journey.sh MANIFEST.json NEW_RUN_ROOT`.

- **Manifest.** It reads paths for `host`, `mini`, `store` and `verifier`, plus optional `shell`, `hermes`, `spkHost` and `candidate` (`:122-124`), and refuses any binary whose sha256 differs from the pins (`:131-137`). It requires `jq sha256sum setsid timeout pgrep xxd` (`:115-117`), GNU `date +%s.%N` (`:174`) and reads `/proc/loadavg` (`:165`, `:389`).
- **Socket placement.** It never binds a socket under the run root. The world socket is `$JOURNEY_RT/world.sock` (`:158`), in a short directory allocated by `journey.d/lib/shortdir.sh`. Every declared socket is checked against `sun_path` before anything is created (`:143-150`).
- **Steps.** The step list is the `STEPS` array at `:192`: 86 ids, each with a `TITLE` (`:204-290`). `TITLE[JJOBM]` is defined twice (`:249`, `:274`). Execution order is the `run_step` list at `:1078-1163`, and it is **not** the `STEPS` order. P7KR and THIN sit between J4 and J5 in `STEPS`, but run at `:1136-1137` near the end. Because `frontier()` walks `STEPS` (`:399-405`), a red P7KR would be named as the frontier ahead of J5 although it ran last.
- **The `call` wrapper.** Every command runs under the 600 s per-operation rule (`:294-309`), capped by the optional whole-run `JOURNEY_BUDGET_S` (`:179-190`).
- **What counts as a refusal.** Only a client exit code 3, the line `client: host refused <stage>: refused: <reason>` and an encoded refusal carrying the `DREGG/NATIVE-HOST/OUTCOME/v6` tag count (`:313-322`). A second kind, `consent_refused` (`:332-335`), counts the client's own local consent refusal, matched on an exact sentence.
- **Two decoder generations.** `decode()` strips a `v4` tag (`:339`), but `REFUSAL_TAG` is `v6` (`:317`). The textual decoding shown in rows therefore keeps a stray tag prefix; the refusal predicate itself is unaffected.
- **Exact acceptedCount accounting.** `accept()` (`:357-368`) demands each installed record to be exactly `LAST_COUNT + 1 + (timer records between)`. Timer counts come from a `JOURNEY_TIMER_COUNTS` file written by `journey-timers/*.sh`. Nothing in the tree starts those timers (section 4.3).
- **Built-in certify.** `journey_certify` (`:413-432`) runs `mini checkpoint --action certify` before every step when the uncertified tail is at least 64, and moves `LAST_COUNT` past the certify record. It is the in-script replacement for `journey-timers/ticker.sh`.
- **Service lifecycle.** `start_server`/`stop_server`/`reopen` (`:489-541`) use a PID file `$W/public/server.pid` and check, before signalling, that the PID's argv is `serve ... --socket $SOCKET` (`ours`, `:490-494`). `pgrep -P` is used only to list the server's children.
- **Inline steps.** J0–J8, G and K4 are written inline:
  - J0: `newparticipant-acceptance.sh` (`:570-581`).
  - J1: `mini enroll --action plan|seal|submit|lookup` (`:583-601`).
  - J2: `workspace --action create` (`:603-612`).
  - J3: `workspace --action propose|submit|publish-delegation` (`:614-632`).
  - J4: `workspace --action init|import|read|propose|submit|read` (`:634-656`).
  - J5: eight stranger attempts (`:658-739`). The last two go through `journey-stranger.py`, which signs op 4 observation challenges directly over the socket.
  - J6: stop/reopen, enrollment lookup, exact `mini retry --mode submit` replays the original receipt (`:741-766`).
  - G: growth (`:768-867`).
  - J7: law change (`:869-894`).
  - J8: deny-all, five refusals, historical lookup/resubmit (`:896-925`).
  - K4: 32 fields (`:929-957`).
- **Hooks.** Every other step is `hook ID TEXT [MANIFEST-KEY]` (`:970-998`). A hook runs `journey.d/<id>.sh` under `HOOK_TIMEOUT_S` (3,600 s), with the exported variables listed at `:979-980`. It is UNBUILT when the file is absent (`:973-975`) and UNCONFIGURED when a named manifest key is missing (`:976-978`). `needs_env` (`:963-968`) marks external inputs UNCONFIGURED. Only `JN2`, `JN3`, `JN3P`, `JN5` and `JPAY6` use it (`:1043-1046`, `:1052`).
- **Liveness check gap.** After a hook, the service-liveness check `ours "$(server_pid)"` runs **only when the hook exited 0** (`:995-997`). A failing hook that killed the service is not detected, and every later hook inherits a dead socket. The 2026-10-23 CI run shows exactly this (section 4.1).

**Hook contract.** Exit 0 means PASS. The last stdout line is the deciding artifact, and the last stderr line is the detail (`:63-81`). Hooks that bind sockets run under `journey_shortdir NAME` with a row in `journey_socket_table` (`shortdir.sh:34-50`). The table has 13 rows. JN3P, JNOCK3P, JEVAL, JSYNC and others bootstrap their own Stores without declaring rows, which works only because their sockets happen to fit.

**`journey.d/lib/` (6 files, 610 lines).**
- `shortdir.sh` (145): the short-socket allocator, its copy-back into `rt/`, and an exit-66 tripwire when a bound socket outgrows its declared row (`:127-145`).
- `genesis-params.sh` (29): picks the candidate's `params.sh`, or `deploy/candidate/params.sh` in a dev run.
- `hostraw.py` (231): "the Host session wire, spoken directly". It implements `frame` (v2 envelope `0x02 ++ u32 len config ++ config ++ sha256(host) ++ op ++ payload`, `:47-50`) and the verbs `call`, `repeat`, `proxy` (lose-reply and never-forward modes, `:109-144`), `refusals` (an operator-log scraper keyed on the literal `host: submission refused (operator log):`, `:147-173`), `debt` and `flip` (signature byte inversion, `:209-225`).
- `thin-proxy.py` (191): a lying consent provider that rewrites frame 232. It **re-implements a Lean codec in Python**: base-255 stream nats (`:46-61`), byte lists (`:64-78`) and the slot list (`:81-107`). It locates the slot list by `difflib` longest-match against the intent (`:96-107`).
- `m7-compiled.sh` (7): the compiled-input line filter shared with `journey-runner`.
- `run-growth.sh` (7): `JOURNEY_STEPS="J0 J1 J2 J3 J4 G"`. It has no caller in the tree (`git grep run-growth` finds only the file itself).

**`journey.d/bind.sh` (100).** This is step BD, lane BIND. It creates `bind-solo` and `bind-n` (`:28-36`), delegates `bind-n` to the newcomer (`:37-50`), and prepares and signs two writes before either is submitted (`workspace submit --prepare-only true`, `:53-65`). It then sends them with `mini retry --mode submit` in both orders (`:77-87`), and requires the second of two same-cell plans to be refused (`:91-97`).
- Weakness: the overlap pole accepts *any* non-empty stderr as "the refusal reason" (`:97`).
- `send()` treats every non-`installed` result as "refused" (`:67-75`), so a client crash or a timeout passes the overlap pole. This is weaker than `journey.sh`'s own `refused()`.

**`acceptance.sh` (474).** This is the oldest acceptance script.
- It generates `operator.json` and `genesis.json` by heredoc (`:54-133`), runs `genesis-params.sh fill-source` (`:135`) and `mini bootstrap` (`:136-138`).
- It births a content object 600 and a declared object 601 with `mini submit --intent-kind birth-intent` (`:141-187`).
- It loses the first content submit with a generated host wrapper `drop-first-submit.sh`, which rewrites the 4th argument of the direct Host CLI `submit` to a nonexistent path (`:240-259`). It then recovers with `mini retry --mode submit|lookup` and requires both to be `replayed` with equal four-field receipts (`:265-279`).
- Finally it performs a mixed content/scalar joint write (`:320-381`) and exact retry (`:403-413`).
- It hard-codes heights 12 and 13 and acceptedCount 3 (`:299`, `:379`, `:399`). It uses `shasum`, not `sha256sum` (`:264`).
- It is **broken today** (section 4.2).

**`docs/JOURNEY.md` (93).** It states the journey as the definition of done and lists J0–J8 and the growth thresholds (`:41-75`). It deprecates seven acceptance scripts as gates "kept in this lane and not deleted" (`:26-39`) and describes the world-sim gate (`:77-93`). It has drifted from the tree:
- It says the STEPS array is at `journey.sh:189`; it is at `:192`.
- It lists six runner rows (`:10-19`); `journey-rows:15` now lists 30.
- It says "the call and send drivers ... are not rows" (`:17-19`), which is false since `journey-rows:105-133`.

**`scripts/pipeline/journey-rows` (822, outside the crate but the runner table for it).**
- `JOURNEY_ROWS=(journey objective rooms activity seats bounty call send domain upgrade hostupgrade objectrecord welcomecontinuity sshe2e m3 m4 hermes m6grain m7 m8 fleetsign jpay exchange chargedfailure births jserve perf)` (`:15`), plus `growth` when `PIPELINE_NIGHTLY=1` (`:18`).
- `row_journey` runs `journey.sh` with `JOURNEY_STEPS="J0..J8 JROT JROTL [JRLANE JGATE JAUDIT *SEAT*]"` and `JOURNEY_GROWTH_LEVELS=10` (`:22-40`).
- `product_journey` runs single steps with their dependencies, used for M7, growth and JSERVE (`:572-588`).
- `row_jpay` runs `jpay1/2/3/4/6.sh` directly (`:730-781`).
- Row results live under `$JOURNEY_ROOT/TIP/` on the journey box (`journey-runner:15-21`), **not in this repository**. The only runner job recorded in `docs/evidence` is `2026-10-08-selected-exchange-local-fn` (row `exchange`, PASS twice and one planted FAIL, on READY set `0ea31db5`, an ancestor of main).

**`scripts/local-gates.sh` / `scripts/check-journey.sh`.**
- The 27th gate `journey` (`local-gates.sh:84`, `:129`) runs `check-journey.sh`.
- That script builds the Host and six Rust crates (`check-journey.sh:40-44`), writes a manifest with `shell=mini`, `hermes=grain-runtime` and `spkHost`, and **no** `candidate` unless `LOCAL_GATES_CANDIDATE` is set (`:53-61`). It runs the full `STEPS` with `JOURNEY_BUDGET_S=14400` (`:70`).
- It turns UNBUILT into red unless the step is pinned in `scripts/gates/journey-unbuilt.tsv`; only M6 is pinned.
- `local-gates.sh:136` kills any gate at 10,800 s. That is smaller than the 14,400 s journey budget, so the budget mechanism `journey.sh:91-96` describes ("goes red in bounded time and says why") never fires. The gate is cut as TIMEOUT with no `journey-result.json`, which is exactly what CI shows (section 4.1).
- Both `journey.sh:86` and `check-journey.sh:2` still call it "gate 5".

### 1.2 The script table (every journey/acceptance script)

Legend for the **verdict** column:
- **LG**: live-gated and *reached* on main. Either a `journey.sh` step reached in the recorded CI runs, or a runner row.
- **LG-red**: gated, and recorded red on main.
- **GU**: gated but unreached. It is registered as a `journey.sh` step, but the CI gate times out before it, and no runner row covers it.
- **LU**: live-ungated. It runs as written, but no gate or row runs it.
- **EO**: evidence-only. It ran at least once, as recorded in `docs/evidence`, and is not gated.
- **NR**: never run. No record anywhere in the repo.
- **BR**: broken. It references a deleted command, file or grammar, or fails on current code for a named reason.

Host ops are the registry codes the script itself sends or names (`protocol/host-operations.json`). "CLI" lists direct `minidregg-host CONFIG <verb>` calls. "Runner" means a `journey-rows` row, whose results are outside the repo. "CI" refers to the GitHub runs of 10-16, 10-17 and 10-23.

#### A. Framework and fixtures

| Script | Lines | Claims to test | `mini` subcommands | Host ops / CLI | journey.sh step | Runner row | Last recorded run | Verdict |
|---|---|---|---|---|---|---|---|---|
| `journey.sh` | 1180 | J0–J8, G, K4 inline; 76 hooks | enroll/plan,seal,submit,lookup; workspace/create,describe,import,init,propose,publish-delegation,read,submit; retry; keygen; serve; checkpoint/certify | op 4 (via journey-stranger) | (the driver) | journey, growth, jserve, m7, rooms | CI 10-23 rev 307b13e: J0–J8 PASS (gate TIMEOUT); docs/evidence 2026-09-30-candidate (lane, frontier G) | LG (partly LG-red: see 4.1) |
| `journey.d/lib/shortdir.sh` | 145 | sockets fit `sun_path` | — | — | (lib) | (via journey) | CI margins table | LG |
| `journey.d/lib/genesis-params.sh` | 29 | the candidate's params.sh is used | — | — | (lib) | — | — | LG |
| `journey.d/lib/hostraw.py` | 231 | raw wire: resend, flip, lose reply | — | any op (call/repeat/proxy/debt) | (lib for JGATE, JRLANE, JROTL) | journey (JRLANE, JGATE, JROTL) | — | LG (runner) |
| `journey.d/lib/thin-proxy.py` | 191 | lying consent provider, frame 232 | — | consent frames 230–232 (not Host ops) | (lib for THIN) | — | — | GU |
| `journey.d/lib/m7-compiled.sh` | 7 | M7 compiled-input filter | — | — | (lib) | m7 / journey-runner | 2026-09-30-candidate | LG (runner) |
| `journey.d/lib/run-growth.sh` | 7 | J0–J4 + G | (journey.sh) | — | — | none (no caller) | — | LU |
| `journey-private.sh` | 9 | `install_private` helper | — | — | (lib for J12, JDISCLOSE) | — | — | LG |
| `journey-stranger.py` | 58 | J5 hostile leg: unenrolled key signs op 4 | author (via host pure codec) | op 4, **v1 envelope** (`:34`) | J5 | journey | CI J5 PASS 10-23 | LG |
| `journey-timers/ticker.sh` | 29 | the clock ticks and certifies beside a journey | clock/tick; checkpoint/certify | — | — | — | — | BR (waits for `$W/public/mini.sock`, 4.3) |
| `journey-timers/hostile.sh` | 48 | a hostile writer beside the timers | workspace/create,import,propose,submit | — | — | — | — | NR (no launcher) |
| `newparticipant-acceptance.sh` | 206 | fresh one-sponsor Store, clock subject, sponsor workspace, `mini serve` | keygen; bootstrap; clock/init; workspace/init,import,read; serve | — | J0 body (and own-Store hooks) | (all) | CI 10-23 J0 PASS; 2026-09-28-newparticipant-runtime, 2026-09-30-shell-journey | LG |
| `newparticipant-from-manifest.sh` | 23 | the same, from a candidate manifest | (delegates) | — | — | — | 2026-09-30-candidate | EO |
| `genesis.sh` | 220 | the one genesis template (operator.json, genesis.json, birth contexts) | (none; `host profile`) | CLI profile | via J0 | (all) and **deploy/candidate** (`package.py:106`) | every J0 | LG + deployed |
| `genesis-params.example.json` | 61 | the qualified example params | — | — | via J0 | deploy/candidate | — | LG + deployed |

#### B. World-Store hooks (documents, law, kernel, hardening)

All of these run on the journey's live Store unless noted.

| Script | Lines | Claims to test | `mini` subcommands | Host ops / CLI | Step | Runner | Last recorded run | Verdict |
|---|---|---|---|---|---|---|---|---|
| `journey.d/bind.sh` | 100 | disjoint plans commute, overlap refused | workspace/create,propose,submit(--prepare-only),publish-delegation,import; retry | — | BD | — | — | GU (weak pole, 1.1) |
| `journey.d/j12x.sh` | 195 | malformed requests refused by name; same Host survives; a killed Host is restarted | author; serve | ops 0, 2, 6, 7, 10, 11; **v1 and v2 envelopes** (`:55`) | J12X | — | CI PASS 20/20 (10-16/17/23) | LG |
| `journey.d/jserve.sh` | 349 | trickle, long request, 50 silent and op 7 route mismatch stall no honest read | workspace/read; author | op 7 | JSERVE | jserve | CI PASS 12/12 | LG |
| `journey.d/jbirthwin.sh` | 152 | births under a concurrent writer; stale birth refused `birthStale` | workspace/create,propose,submit,import,publish-delegation; serve | CLI audit | KBW | — | CI FAIL "1 rows off" all 3 runs | LG-red |
| `journey.d/jclock.sh` | 395 | the one clock; `clock/now` in laws | clock/tick,view; workspace/* | — | KC | — | CI FAIL 21/32 all 3 runs | LG-red |
| `journey.d/jtail.sh` | 158 | C14 tail bound L=8 (own Store) | checkpoint/certify,view; workspace/*; serve | CLI audit | KT | — | CI PASS 12/12 | LG |
| `journey.d/jjoint.sh` | 90 | law reads participant by position | workspace/create,propose,submit | — | JJ | — | CI PASS | LG |
| `journey.d/j10-kernel.sh` | 131 | rooms: `--in`, under, outsiders refused | workspace/create,import,read,propose,submit,publish-delegation | — | K10 | — | CI PASS 8/8 | LG |
| `journey.d/j11-kernel.sh` | 246 | per-author streams, zero re-plans | workspace/create,import,tail,...; serve; audit | — | K11 | — | CI PASS 10-16/17 (2,566–3,409 s); hung 3,600 s 10-23 | LG (flaky; slowest) |
| `journey.d/j10-index.sh` | 189 | who/since/at-height index | query; workspace/* | CLI presence-index, audit | KIX | — | CI PASS 10-17 (1,857 s) | LG |
| `journey.d/jfields.sh` | 195 | maxDelta, field scopes | workspace/* | — | KF | — | CI PASS 10-17 | LG |
| `journey.d/jhide.sh` | 224 | salted roots, sealed leaves, ratchet | key/derive-salt,cell-blinding; verify-view; workspace/* | — | KH | — | CI FAIL "create 3 failed" 10-17 | LG-red |
| `journey.d/j12c-kernel.sh` | 193 | annotate, stale annotation | enroll/*; keygen; workspace/* | CLI audit | K12C | — | CI PASS 10-17 (1,544 s); cascade-FAIL 10-23 | LG |
| `journey.d/jmarket.sh` | 342 | sealed-bid market through the shell | shell lines; workspace/provision,market-open | — | JMKT | — | CI FAIL 19/28: `enroll plan NAME KEY` usage (10-17, 10-23) | BR |
| `journey.d/j12i-links.sh` | 246 | link index, backlinks cut to grants | enroll/*; workspace/*,transclude | **CLI `link-index` (absent from Host)**, audit | K12I | — | cascade-FAIL 10-23 | BR |
| `journey.d/j12t-kernel.sh` | 322 | range transclusion, disclosure | enroll/*; workspace/transclude,follow,transclusions | CLI audit | K12T | — | cascade-FAIL 10-23 | GU |
| `journey.d/j12n-runs.sh` | 128 | appended lines range-transcludable | workspace/transclude,transclusions | — | K12N | — | cascade-FAIL 10-23 | GU |
| `journey.d/j12e.sh` | 289 | element tree order, moves | enroll/*; workspace/doc-insert,doc-move,doc-remove,doc-show,transclude | CLI audit | K12E | — | cascade-FAIL 10-23 | GU |
| `journey.d/j12m.sh` | 239 | marks pinned by revision | workspace/mark,unmark,doc-backlinks,doc-show | CLI audit | K12M | — | cascade-FAIL 10-23 | GU |
| `journey.d/j12r.sh` (+ `j12r.golden.txt` 12) | 188 | one renderer, golden text | workspace/doc-show,doc-outline,doc-backlinks,mark,transclude | — | K12R | — | cascade-FAIL 10-23 | GU |
| `journey.d/j12h-history.sh` | 189 | history/show --at/diff | workspace/doc-history,doc-diff,doc-show | CLI audit | K12H | — | cascade-FAIL 10-23 | GU |
| `journey.d/jweb.sh` | 251 | loopback read-only `mini web` | web; workspace/doc-show,doc-history | — | WEB | — | blocked 10-23 | GU |
| `journey.d/jwell.sh` | 220 | realm wells mint/burn/conserve | well/new,mint,burn,floor; workspace/* | CLI audit, well-ledger | KW | — | cascade-FAIL 10-23 | GU |
| `journey.d/j10c.sh` | 424 | rooms through the shell, kick, realm | shell lines; well/new; workspace/provision; audit | — | K10C | — | started 10-23, gate killed | GU |
| `journey.d/jlawinherit.sh` | 138 | room exports constrain children | shell lines | — | JLI | — | — | GU |
| `journey.d/jtemplates.sh` | 441 | room templates (workroom/social/story) | shell lines; workspace/provision,tail | — | KTPL | — | — | GU |
| `journey.d/j12.sh` | 285 | two friends co-write a doc through the shell | shell lines; workspace/provision | — | J12 | — | 2026-09-30-shell-docs: J12 PASS 134/134 (lane `p-shell-docs`) | GU (EO on lane) |
| `journey.d/j12w.sh` | 279 | doc pull/push, stale by line | shell lines; workspace/provision | CLI audit | J12W | — | — | BR (`enroll plan $f $f.key`, `:121`) |
| `journey.d/jnames.sh` | 82 | shared room names, renames | shell; workspace/doc-new,index-law,import | — | JNAMES | — | — | GU |
| `journey.d/jkind-revise-consent.sh` | 108 | kind revision between consent and admission | workspace (shell) | — | P7KR | — | — | GU |
| `journey.d/jthin-consent.sh` | 262 | thin consent: shown post = committed; lying Host refused | workspace/*; retry | consent frames 230–232 | THIN | — | — | GU |
| `journey.d/jdocuverse.sh` (+ golden 11) | 388 | DEOS J19–J24 through the shell | shell lines; web; workspace/provision | CLI audit | JDV | — | — | GU |
| `journey.d/jprotected-docs.sh` | 11 | protected docs on the JDV Store; execs `scripts/protected-document-journey.sh` | (target script) | — | JPD | — | target says "only had bash syntax checking" | GU (unproven by own header) |
| `journey.d/jclosure.sh` | 147 | undeclared field refused by name | workspace/* | — | KCL | — | — | GU |
| `journey.d/jdisclose.sh` | 165 | narrowed refusals, auth before target, install guard | query; workspace/provision; shell | — | JDISCLOSE | — | — | BR (`enroll plan jd-$f jd-$f.key`, `:48`) |
| `journey.d/jrot.sh` | 361 | pre-rotation: thief cannot rotate | enroll/cosign,plan,seal,submit; rotate-key; key-status; workspace/* | op 140; CLI audit; `scripts/check-audit-corrupted-leaf.sh` | JROT | journey | README: 3/30 checks red at main `4795b657` (runner, outside repo) | LG (runner) |
| `journey.d/jrot-lookup.sh` | 125 | lost op-142 reply recovered by op 143 | enroll/*; rotate-key; key-status | ops 142, 143 (proxy via hostraw) | JROTL | journey | README: PASS at `4795b657` | LG (runner) |
| `journey.d/jrefusal-lane.sh` | 246 | authenticated refusals charged; wrong signatures free | enroll/*; keygen; workspace/* | via hostraw debt/flip; CLI inspect | JRLANE | journey | — | LG (runner) |
| `journey.d/jgateway.sh` | 195 | gateway content law refuses a direct call | workspace/* | CLI plan-ungated, signatures, assemble, inspect | JGATE | journey | — | LG (runner) |
| `journey.d/jstoreaudit.sh` | 101 | `mini store audit` re-derives Store; flipped byte refused | store | CLI store-audit | JAUDIT | journey | — | LG (runner) |

#### C. Stand-alone lane journeys (own Stores) and their one-line wrappers

| Script | Lines | Claims to test | `mini` subcommands | Host ops / CLI | Step | Runner | Last recorded run | Verdict |
|---|---|---|---|---|---|---|---|---|
| `shell-journey.sh` | 444 | J0–J8 typed into `mini shell` over ssh | shell lines (enroll, init, create, delegate, invoke, submit, law, retry...); serve; workspace/init,provision | — | via M4 | m4 | 2026-09-30-shell-journey: 89/89 (lane `m4-shell` `b105bd7`, persvati) | LG (runner) |
| `journey.d/m4.sh` | 20 | wraps shell-journey.sh | — | — | M4 | (m4 runs the script directly) | 2026-09-30-candidate: M4 UNBUILT then | GU via journey / LG via runner |
| `provisioning-acceptance.sh` | 244 | a newcomer provisions itself, stale observation, cold reopen | enroll/*; workspace/provision,provision-lookup,create,read,...; serve | op 91 | via M3 | m3 | 2026-09-30-newcomer-provisioning (lane `m3-provision`) | LG (runner) |
| `journey.d/m3.sh` | 20 | wraps provisioning-acceptance.sh | — | — | M3 | — | — | GU / LG via runner |
| `law-leaf-journey.sh` | 331 | refusal names its clause | shell lines; workspace/provision | — | via J13 | — | 2026-09-30-law-leaf: 45 rows 0 failed (lane `p-law`) | GU (EO on lane) |
| `journey.d/j13.sh` | 20 | wraps law-leaf | — | — | J13 | — | — | GU |
| `affordances-journey.sh` | 425 | `can NAME`, op 130 dry run commits nothing | shell; workspace/provision,read; serve | op 130; CLI audit | via J12A | — | — | GU |
| `journey.d/j12a.sh` | 18 | wraps affordances | — | — | J12A | — | — | GU |
| `inspect-journey.sh` | 482 | inspect caps/law/why/turn/receipt | shell; workspace/*; serve | CLI inspect, audit | via JINSPECT | — | — | GU |
| `journey.d/jinspect.sh` | 26 | wraps inspect (own `mktemp` short dir, not `shortdir.sh`) | — | — | JINSPECT | — | — | GU |
| `lawsat-journey.sh` | 458 | law-sat op 150; `can --any` admitted | shell; workspace/read; serve | op 150; CLI audit | via JLS | — | — | GU |
| `journey.d/jlawsat.sh` | 17 | wraps lawsat | — | — | JLS | — | — | GU |
| `journey.d/m5.sh` | 20 | wraps `native/grain-runtime/hermes-journey.sh` | — | — | M5 | hermes (runs it directly) | — | GU / LG via runner |
| `journey.d/m7.sh` | 108 | the candidate reproduces; run.sh init/serve | store | — | M7 | m7 | 2026-09-30-candidate: M7 PASS (lane `m7-candidate`) | LG (runner) |
| `journey.d/m8.sh` | 20 | wraps fleet-journey.sh | — | — | M8 | m8 | — | GU / LG via runner |

#### D. Rooms, chat, private, Hermes, channel

| Script | Lines | Claims to test | `mini` subcommands | Host ops / CLI | Step | Runner | Last recorded run | Verdict |
|---|---|---|---|---|---|---|---|---|
| `journey.d/jchan-epoch.sh` | 190 | channel epoch records under ChannelLaw | workspace/*,tail; audit; `lake env lean --run scripts/probe-channel-epoch.lean` | — | KCH | — | CI PASS 10-16/17 (1,339–1,754 s); cascade-FAIL 10-23 | LG |
| `journey.d/jchan-relay.sh` | 231 | `mini relay` ticks in real time | relay, relay-emit, relay-witness, relay-key; workspace/*; audit | needs `.lake/build/lib/libminidregg-channel.so` | KCHR | — | CI FAIL "no channel library" all 3 runs | LG-red (never built in gate) |
| `journey.d/jchan-client.sh` | 349 | sealed channel cells, wire trace equal | channel, relay, relay-witness, relay-key; workspace/create; audit | same library | KCHC | — | CI FAIL "no channel library" all 3 runs | LG-red |
| `channel-lib/build.sh` (+ `closure.lean` 27, `shim.c` 40, `initbench.c` 22) | 42 | links `libminidregg-channel.so` from Lean objects | — | `lake build ...:o.export` | (prereq of KCHR/KCHC) | — | — | LU (not called by any gate) |
| `journey.d/jchat.sh` | 354 | say/tail/topic/pin/react, Discord bridge | shell lines; workspace/provision; serve; audit | — (uses `discord-entrance` binary) | JCHAT | — | 10-01 p-* results: SKIPPED | GU |
| `journey.d/j14.sh` | 503 | Hermes as librarian, budgets, restart | shell; credit/balance,ledger,room; workspace/provision; serve; audit | op 140 | J14 | — | 2026-10-01-p-hermes-room: J14 PASS (lane) | GU (EO on lane; needs `GRAIN_RUNTIME`, `TEST_PROVIDER`, no `needs_env`) |
| `journey.d/j15.sh` | 291 | a story: sealed table as law | shell; workspace/provision; serve; audit | CLI inspect | J15 | — | 2026-10-01-p-story: J15 PASS (lane) | GU (EO on lane) |
| `journey.d/j17.sh` | 469 | a week in the place: credit, pay, concierge | shell; credit/*; fleet/poll,publish,send,transfer; workspace/provision; serve; audit | op 180 | J17 | — | 2026-10-01-p-credit: J17 PASS (lane) | GU (EO on lane; needs `GRAIN_RUNTIME`) |
| `journey.d/jpriv1.sh` | 656 | private room: operator holds ciphertext only | shell; key-status; keygen; workspace/room-key,tail,...; serve; audit | — | JPRIV1 | rooms | README: rooms row 0 of 88 rows at `4795b657` | LG-red (runner) |
| `journey.d/jpriv1.expected.tsv` | 102 | expected rows; "NOT FROM A RUN" (`:1-3`) | — | — | (rooms-e2e) | rooms | — | — |
| `rooms-e2e.sh` | 111 | J0..J5 + JPRIV1 vs expected table | (journey.sh) | — | — | rooms | `--self-check` "is all that can run today" (`:22-23`) | LG-red |
| `journey.d/jpriv2.sh` | 330 | a friend's key never touches the box: `mini --remote` over ssh | workspace (remote) | op 8; ssh, sshd | JP2 | — | — | GU |
| `journey.d/jprivate-docs.sh` | 171 | private docs on the JPRIV1 Store | shell; workspace; serve; audit | — | — (unhooked) | — | — | NR (twin of protected-document-journey.sh) |

#### E. Pay and job money

| Script | Lines | Claims to test | `mini` subcommands | Host ops / CLI | Step | Runner | Last recorded run | Verdict |
|---|---|---|---|---|---|---|---|---|
| `journey.d/jpay1.sh` | 113 | pay watcher on fixtures → observations | — (pay-watcher binary) | — | JPAY1 | jpay | — | LG (runner) |
| `journey.d/jpay2.sh` | 274 | pay cell: tariff, book, assignments (own Host) | bootstrap | ops 103–107 raw, PyNaCl signing; CLI stdio, audit | JPAY2 | jpay | — | LG (runner) |
| `journey.d/jpay3.sh` | 343 | observed payments → Book credit; clock | bootstrap | op 129; CLI stdio, audit | JPAY3 | jpay | 2026-10-05-clock-law (lane `kn-law-bypass`, three planted Hosts) | LG (runner) |
| `journey.d/jpay4.sh` | 480 | payment rail through the client | serve; pay | ops 103, 105, 107, 111 | JPAY4 | jpay | — | LG (runner) |
| `journey.d/jpay6.sh` | 894 | Book burn funds an AgentGrain purse | workspace/init; key; pay; profile; bootstrap; submit; query; serve | ops 105, 116, 144; systemd-run --user, sudo, bwrap | JPAY6 | jpay | — | LG (runner; UNCONFIGURED without GRAIN etc.) |
| `journey.d/jpay6-hermes-acp` | 62 | stand-in ACP worker, one provider call per prompt | — | — | (JPAY6) | jpay | — | LG (runner) |
| `journey.d/jpay-e1.sh` | 145 | watcher enrollment index vectors | — | — | JPAYE1 | — | — | GU |
| `journey.d/jpay-e2.sh` | 465 | self-enrollment decision, real ssh-keygen signatures | bootstrap; submit; query | op 112; CLI pay-enrol-probe, describe, stdio, audit | JPAYE2 | — | — | GU |
| `journey.d/jpay-e3.sh` | 457 | self-enrollment receiver | bootstrap; submit; query | ops 117–120; CLI describe, audit | JPAYE3 | — | — | GU |
| `journey.d/jpay-e4.sh` | 830 | `mini join --solana` end to end on fixtures | join; enrollment-bootstrap; serve-operator; serve-public-proxy | ops 117, 120; CLI inspect, pay-enrol-ids, pay-ledger | — (unhooked) | — | deploy/pay/README.md: `/tmp/pay-entry-a22-4/jpay-e4/rows.tsv` on persvati | EO (outside repo) |
| `journey.d/jpay-v2.sh` | 679 | v2 paid entry with synthetic RPC, fault relay | join; serve-operator; serve-public-proxy | CLI author, pay-enrol-ids, pay-ledger | — (unhooked) | — | header: "Runtime qualification remains pending until this hook actually passes" (`:10`) | NR |
| `journey.d/jpay-rail.sh` | 47 | direct JPAY1–4 rail with a rebuilt mini | (jpay1–4) | — | — | — (`:4`: "the standing train's product_pay_step remains the owner") | — | LU (twin of row_jpay) |
| `journey.d/jpay-bootstrap-budget.py` | 183 | cold HTTP entry budget on a stopped jpay-e4 fixture | enrollment-bootstrap; enrollment-view; serve-operator; serve-public-proxy | systemd-run | — | — | PAID-COLD-ENTRY.md:162-172: persvati `/home/ember/build/pay-bootstrap-budget-6075-{8,9}/` | EO (outside repo) |
| `jpay-claim-law.sh` | 111 | prepare a paid-claim law update by signed read | query; submit; retry | — | — | — | — | LU |
| `jpay-claim-law.jq` | 54 | jq authoring of the claim law | — | — | — | — | — | LU (authors a law, 3.1) |
| `jpay-claim-law-tests.sh` | 169 | offline control-flow fixtures with a fake mini | (fake) | — | — | — | — | LU (test of a test) |
| `paid-entry-adapter.py` | 362 | synthetic paid-v2 members on a supplied Store | (own frames) | v2 envelope frames | — | (platform-provision hook) | — | LU |
| `journey.d/job-refund-recovery.py` | 191 | native job refund + receipt recovery | (helper-driven) | — | — | — | — | NR |
| `journey.d/job-refund-legacy-recovery.py` | 193 | legacy job refund with corrected client | (helper-driven) | — | — | — | (`.spw/audits/horse-consistency` names it a fixture) | NR |

#### F. Nock, compute, world programmer

| Script | Lines | Claims to test | `mini` subcommands | Host ops / CLI | Step | Runner | Last recorded run | Verdict |
|---|---|---|---|---|---|---|---|---|
| `journey.d/jnock2.sh` | 215 | friend Nock program becomes a program cell | workspace/create | v1 frames (`:60`); hoonc | JN2 | — | — | GU (UNCONFIGURED without NOCK_*) |
| `journey.d/jnock3.sh` | 253 | kernel re-executes a run claim | workspace | op 134; v1 frames; nock-run | JN3 | — | — | GU (UNCONFIGURED) |
| `journey.d/jnock3p.sh` | 379 | pinned program claim at two heights | workspace | ops 131, 133, 134; v1 frames | JN3P | — | — | GU (UNCONFIGURED) |
| `journey.d/jnock5.sh` (+ two `.hoon`, 35 + 121) | 285 | NockApp door refereed by re-execution | workspace; serve | ops 135–137; v1 frames | JN5 | — | — | GU (UNCONFIGURED) |
| `journey.d/jsync.sh` | 183 | nockFSync budget poles | workspace | CLI describe, audit; `run/synth.py` (external) | JSYNC | — | — | GU |
| `journey.d/jjob1.sh` | 306 | job law edges by clause | clock/tick,view; job; pay; keygen; workspace/* | op 131; v1 frame (`:95`) | JJOB1 | — | — | GU (FAIL not UNCONFIGURED without JOB_PROGRAMS) |
| `journey.d/jjob.sh` | 493 | Nock job posted, run, adjudicated | clock; job; pay; workspace | op 134; CLI job-money-explain, pay-job, pay-ledger, author, audit; v1 frames | JJOB | — | — | GU (same) |
| `journey.d/jjob-money.sh` | 402 | job escrow/bond/payout as Book turns | clock; job/show; pay; workspace; serve | ops 160–163; same CLI | JJOBM (defined twice) | — | — | GU |
| `journey.d/jeval.sh` | 277 | evaluator registry, two Stores | workspace | op 134; v1 frames | — (unhooked) | — | — | NR |
| `journey.d/jworld-kind.sh` | 170 | member-defined poll kinds | workspace (shell) | — | — (WORLD-PROGRAMMER.md order 1) | — | — | NR |
| `journey.d/jworld-method.sh` | 318 | member method, free quota, funded compute | pay; workspace/import,provision,read | CLI inspect | — (order 2) | — | — | NR |
| `journey.d/jworld-board.sh` | 74 | task board reusing the poll program | shell | — | — (order 3) | — | — | NR |
| `journey.d/jworld-prototype.sh` | 91 | finite library bundle, self/super | shell | — | — (order 4) | — | — | NR |
| `journey.d/jworld-prototype.py` | 176 | noun/jam authoring, "NO evaluator" | — | — | — | — | — | NR |
| `journey.d/jworld-construction.sh` | 110 | "Source-matched v10 native receiving recipe" | shell; author | — | — | — | — | NR |
| `journey.d/jworld-construction.py` | 71 | constructor nock authoring; `exec`s jworld-prototype.py | — | — | — | — | — | NR |
| `journey.d/jworld-composed-source.py` | 40 | same, `exec`s jworld-prototype.py | — | — | — | — | — | NR |

#### G. Objective

| Script | Lines | Claims to test | `mini` subcommands | Host ops / CLI | Step | Runner | Last recorded run | Verdict |
|---|---|---|---|---|---|---|---|---|
| `activity_world.py` | 621 | shared scratch-world helper; every turn `mini activity` | keygen; workspace/create; activity/quote,resubmit,view | ops 7, 210–214 | (lib) | (all objective rows) | — | LG (runner) |
| `objective-native-acceptance.py` | 453 | native Objective Accepted receipt; refusals r01–r13 | objective-invoke; query; submit; workspace/create,propose,submit; serve; store; retry | `lake env lean --run tests/objective-native/Mutate.lean` | — | objective | README: 17 rows PASS at `4795b657` (runner) | LG (runner) |
| `objective-native-edit-core.py` | 5 | request edit: wrong artifact byte | — | consent endpoint 227 | (objective) | objective | — | LG (runner) |
| `objective-native-edit-core-short.py` | 5 | request edit: core one byte short (r15) | — | — | (objective) | objective | — | LG (runner) |
| `objective-native-edit-front-zero.py` | 5 | request edit: zero front-end work (r14) | — | — | (objective) | objective | — | LG (runner) |
| `objective-activity-native-acceptance.py` | 844 | the activity kernel end to end | activity/lookup,resubmit,view; keygen; serve; store; workspace/create | ops 7, 210–214; CLI objective-publication | — | activity | — | LG (runner) |
| `objective-activity-quote-submit-journey.py` | 62 | N quote→submit births, deposit fixed point | (AW) | — | — | none | — | LU |
| `objective-seat-native-acceptance.py` | 687 | seats and invitations | activity/*; seat/lookup,resubmit,view; well/*; workspace/create; serve; store | ops 7, 214–217, 219 | — | seats | — | LG (runner) |
| `objective-bounty-native-acceptance.py` | 625 | bounty on the seat kernel, plants | seat/view; well/*; workspace/create | op 219 | — | bounty | — | LG (runner) |
| `objective-call-native-journey.py` | 279 | synchronous call C1–C8, plants | activity (AW) | — | — | call | — | LG (runner) |
| `objective-send-native-journey.py` | 837 | async send S1–S13, plants | activity (AW) | op 19 named | — | send | — | LG (runner) |
| `objective-domain-native-journey.py` | 229 | invariant domains D1–D4 | activity (AW) | — | — | domain | — | LG (runner) |
| `objective-upgrade-native-journey.py` | 175 | governed upgrade U1–U5 | activity (AW) | — | — | upgrade | — | LG (runner) |
| `objective-charged-failure-journey.py` | 225 | signature before decision; charged failure | activity/resubmit | op 212 | — | chargedfailure | — | LG (runner) |
| `objective-work-account-journey.py` | 125 | front-end work account quote | (AW) | op 214 | — | none | — | LU |
| `objectrecord-native-journey.py` | 221 | object record OR1–OR7 | activity | — | — | objectrecord | — | LG (runner) |

#### H. Platform, joined, composed, latency (supplied-world orchestration)

| Script | Lines | Claims to test | `mini` subcommands | Host ops / CLI | Step | Runner | Last recorded run | Verdict |
|---|---|---|---|---|---|---|---|---|
| `platform-provision.py` | 663 | fresh joined platform: members, ssh, units | workspace; enroll; shell; keygen; serve-operator; serve-public-proxy | systemctl via sudo | — | — | — | LU (unit-tested only) |
| `platform-native-hooks.py` | 88 | native boundary checks on supplied inventory | workspace | — | — | — | — | LU |
| `platform-service-cut.py` | 264 | same-Store SYSTEM cut, drain-then-stop | (operator-status/drain) | — | — | — | — | LU (unit-tested only) |
| `platform-stage-root.py` | 229 | root-stage a candidate into a frame | — | — | — | — | — | LU |
| `platform-stage.py` | 374 | isolated service plans; starts nothing | workspace/import | — | — | — | — | LU |
| `platform-task-readiness.py` | 110 | parent/tool task readiness | submit; query | — | — | — | — | LU |
| `joined-member-journey.py` | 600 | joined platform receiving on a supplied world | (ssh into forced shell) | — | — | — | — | LU |
| `composed-scenario.py` | 1049 | composed scenario on a running world, step ledger | (ssh into forced shell) | — | — | — | — | LU |
| `step_ledger.py` | 133 | single-effect step ledger | — | — | (lib) | — | — | LU |
| `latency-same-store.py` | 177 | same-Store timings | operator-status | — | — | — | — | LU |
| `latency-prebaseline.py` | 79 | pre-room timing baseline ("hbox is shared") | (via latency-same-store) | — | — | — | — | LU |
| `doc-search-journey.py` | 153 | document search on a private fixture | web; shell | — | — | — | — | NR |
| `doc-search-protected-check.py` | 159 | read-only protected-doc phase check | workspace; web | — | — | — | — | NR |
| `public-ingress-process.py` | 247 | public relay process checks with an **echo** Host (`:1-3`) | serve; serve-public-proxy; serve-operator | — | — | — | PUBLIC-INGRESS.md:63-81 (persvati, not in docs/evidence) | EO (outside repo) |

#### I. Traffic and cohort

| Script | Lines | Claims to test | `mini` subcommands | Host ops / CLI | Step | Runner | Last recorded run | Verdict |
|---|---|---|---|---|---|---|---|---|
| `cohort-native-tcp.py` | 503 | roster-enrolled cohort over TCP, observers | mix; mix-live; keygen | — | — | — | docs/evidence/traffic-v13 (2026-10-04, lane W15) | EO |
| `native/resource-client/scripts/cohort-native-tcp.py` | 185 | the older pre-shared-key orchestrator | mix (key, registrar-key); mix-live `--key` | — | — | — | — | BR (`mix-live` needs `--roster`: `cohort_tcp.rs:1076`) |
| `cohort-scratch-world.py` | 179 | scratch Host world + fixtures for the carrier | workspace; serve; retry | ops 2, 3 (v2 frames) | — | — | traffic-v13 | EO |
| `cohort-secrecy-check.py` | 84 | plaintext absent off the endpoint side | — | scp/ssh to `--remote` | — | — | traffic-v13 | EO |
| `cohort-two-host/env.sh` | 19 | lane W15 paths (`/srv/lanes/W15-TRAFFIC-V13`, `w15b`) | — | — | — | — | traffic-v13 | EO |
| `cohort-two-host/run-baseline-v12.sh` | 10 | v12 control | (cohort script copy under `$L/baseline`) | — | — | — | traffic-v13 | EO |
| `cohort-two-host/run-new-effect.sh` | 19 | a new write carried once | — | — | — | — | traffic-v13/new-effect `RUN-EXIT-0` | EO |
| `cohort-two-host/run-planted-faults.sh` | 12 | plants must go red | — | — | — | — | traffic-v13/planted-faults.summary: both exit 1 | EO |
| `cohort-two-host/run-single-mce3.sh` | 9 | v12 schedule through roster enrollment | — | — | — | — | traffic-v13 | EO |
| `cohort-two-host/run-v13-two-host.sh` | 15 | relays on host B | — | — | — | — | traffic-v13 | EO |
| `native/resource-client/scripts/check-cohort-async.sh` | 14 | focused nextest + release (`df -B1`, 50 GB free) | cargo | — | — | — | — | LU (one-off build task) |
| `native/resource-client/scripts/check-traffic-adoption-consumer.sh` | 17 | same pattern | cargo | — | — | — | — | LU |
| `native/resource-client/scripts/check-traffic-emission-memory.sh` | 17 | same pattern | cargo | — | — | — | — | LU |
| `native/resource-client/scripts/check-traffic-pipeline.sh` | 17 | same pattern | cargo | — | — | — | — | LU |
| `check-traffic-crypto-alias.sh` | 14 | same pattern | cargo | — | — | — | — | LU |

#### J. Selected release and fn

| Script | Lines | Claims to test | `mini` subcommands | Host ops / CLI | Step | Runner | Last recorded run | Verdict |
|---|---|---|---|---|---|---|---|---|
| `selected-exchange-journey.sh` | 601 | two independently credentialed Stores exchange one atom through a real fn node | enroll/plan,possess,seal,submit; selected-exchange; selected-release-sign,submit; query; workspace/*; serve | (selected-exchange phases → ops 20/21 etc.) | — | exchange | 2026-10-08-selected-exchange-local-fn: PASS ×2 on main-lineage `0ea31db5`; 2026-09-30-...-two-credentials | LG (runner) |
| `selected-release-acceptance.sh` | 541 | owner-signed release, conflict, wrong signer, lost reply | keygen; bootstrap; submit; query; selected-release-sign,submit,lookup; serve | ops 20, 21; CLI selected-release-prepare,assemble,ingress, inspect | — | — | 2026-09-27-selected-recipient-candidate PASS (`776ba59`); TRAFFIC-PRIVACY.md:206-211 says it fails now | BR (schemaVersion / store read-to) |
| `selected-release-drop-reply.rs` | 95 | one-shot op-20 lost-reply proxy, compiled by rustc at run time | — | op 20 | — | — | (with the above) | BR (with its caller) |
| `selected-source-publisher-acceptance.sh` | 121 | source authorization + protected fn POST | selected-source-sign,publish | ops 24, 25; CLI inspect | — | — | 2026-09-27 checkpoint lists hashes only | NR |
| `selected-source-drop-reply.sh` | 23 | test-only Host shim returning truncated bytes | — | CLI selected-source-publication-submit | — | — | — | NR |

#### K. Continuity and keys

| Script | Lines | Claims to test | `mini` subcommands | Host ops / CLI | Step | Runner | Last recorded run | Verdict |
|---|---|---|---|---|---|---|---|---|
| `continuity-journey.sh` | 248 | durable client receipt continuity | workspace/continuity-init,continuity-check,continuity-verifier,recover,...; retry; serve | CLI continuity-point, continuity-verify | — | — | (docs/RECEIPT-CONTINUITY.md:100 names it) | NR |
| `fresh-onboarding-journey.sh` | 138 | automatic first continuity trust | workspace/init,onboard,continuity-check,... | CLI continuity-verify | — | — | — | NR |
| `welcome-continuity-journey.sh` | 276 | key-only welcome continuity; forged receipts refused | join; enroll/offer,welcome,plan,seal,submit; workspace/*; serve | op 89; CLI enroll-key-assemble; local `ssh-shim` + `proxy.py` | — | welcomecontinuity | — | LG (runner) |
| `carry-source-journey.sh` | 173 | retained old-profile source fixture | workspace/continuity-init,create,doc-show,...; serve | CLI audit, continuity-point, profile | — | — | — | NR |
| `carry-stage-journey.py` | 141 | stage an operator carry (cryptography lib signs) | — | CLI carry-plan, carry-receive, audit, profile | — | — | — | NR |
| `journey-key-adoption.py` | 240 | adopt-next-key → rotation on a disposable fixture | keygen (+ adopt-next-key) | ops 187, 188 (v2 frames, `:90`) | — | — | KEY-ADOPTION.md:122-123: "remains unverified" | NR |

#### L. Fleet

| Script | Lines | Claims to test | `mini` subcommands | Host ops / CLI | Step | Runner | Last recorded run | Verdict |
|---|---|---|---|---|---|---|---|---|
| `fleet-journey.sh` | 239 | agent fleet: join, send, transfer, receipts, publish, poll, restart | fleet/join,send,transfer,receipt,lookup,publish,poll,feed; workspace/*; serve | — | via M8 | m8 | 2026-09-30-fleet-surface (persvati, `mini-fa0a908`) | LG (runner) |
| `fleet-contention.sh` | 98 | K agents publish concurrently | fleet/join,publish; keygen; serve | — | — | — | 2026-09-30-fleet-surface | EO |
| `fleet-sign-journey.sh` | 239 | `mini fleet-sign` = dregg-client-sign verbs | fleet-sign; serve | — | — | fleetsign | — | LG (runner) |
| `fleet-sign-growth.sh` | 118 | fleet-turn cost as the Store grows | fleet-sign; audit; serve | — | — | — | — | NR |
| `fleet-migration-replay.sh` | 215 | replay helm's transcript through the shim | fleet-sign (via dregg-client-sign) | — | — | — | 2026-10-06-fleet-migration: `result: pass`, 31 calls | EO |
| `fleet-migration-helm-probe.py` | 36 | drive helm's real `_sign_send` | — | — | — | — | 2026-10-06-fleet-migration (helm-probe.json) | EO |
| `dregg-client-sign` | 7 | `exec mini fleet-sign "$@"` | fleet-sign | — | — | — | — | LU (installable shim) |

#### M. Legacy acceptance (deprecated as gates by `docs/JOURNEY.md:26-39`)

| Script | Lines | Claims to test | `mini` subcommands | Host ops / CLI | Step | Runner | Last recorded run | Verdict |
|---|---|---|---|---|---|---|---|---|
| `acceptance.sh` | 474 | birth, content write, lost outcome, joint write | keygen; bootstrap; submit; query; retry | CLI profile, direct `submit` (wrapped) | — | — | 2026-09-26 grain/workroom evidence names it | BR (content `schemaVersion "1"`, 4.2) |
| `authority-acceptance.sh` | 464 | policy, delegation, revocation, historical retry | keygen; bootstrap; author; submit; query; retry | — | — | — | 2026-09-28-workspace-old-host names it | LU (scalar targets still v1: plausible) |
| `application-acceptance.sh` | 312 | two-participant app birth, cross-session refusal | keygen; bootstrap; submit; query; retry; serve | — | — | — | 2026-09-27-application-birth PASS (`2e60a9c`, Mac) | EO |

#### O. Host upgrade

| Script | Lines | Claims to test | `mini` subcommands | Host ops / CLI | Step | Runner | Last recorded run | Verdict |
|---|---|---|---|---|---|---|---|---|
| `journey.d/jhostupgrade.sh` | 210 | candidate N's Store reopens or refuses its epoch | workspace/*; clock/init,tick,view; checkpoint/certify,view; store | `deploy/candidate/run.sh` | — (unhooked; usage differs) | hostupgrade | — | LG (runner) |

#### Test-of-test (`test_*.py`, gated by `scripts/gates/unit-tests.tsv:7-15`)

| Script | Lines | Tests (floor) | What it loads | Verdict |
|---|---|---|---|---|
| `test_composed_scenario.py` | 534 | 27 | `composed-scenario.py` with a scripted fake shell | LG (unit-tests gate; CI 10-23 "PASS (32 modules)") |
| `test_joined_member_journey.py` | 219 | 15 | `joined-member-journey.py`, "no service, SSH, provider, or native process" | LG |
| `test_latency_same_store.py` | 129 | 9 | `latency-same-store.py` | LG |
| `test_platform_provision.py` | 257 | 20 | `platform-provision.py`, `platform-native-hooks.py` | LG |
| `test_platform_service_cut.py` | 79 | 9 | `platform-service-cut.py` | LG |
| `test_platform_stage.py` | 140 | 14 | `platform-stage.py` | LG |
| `test_platform_stage_root.py` | 94 | 13 | `platform-stage-root.py` | LG |
| `test_platform_task_readiness.py` | 53 | 7 | `platform-task-readiness.py` | LG |
| `test_shell_credential_launcher.py` | 51 | 4 | `deploy/shell/mini-shell-ssh-credentials` (tests deploy/, not this crate, `:15`) | LG (misplaced) |

### 1.3 Prose contracts at the crate root

"Class" values:
- **contract**: present-state description.
- **diary**: an appended dated construction or run log.
- **mixed**: a contract head with a diary tail.

| File | Lines | Class | What it claims | Rust module(s) | Journey(s) | Matches current code? |
|---|---|---|---|---|---|---|
| `README.md` | 982 | mixed, mostly contract (a command manual) | Workspace, `serve`, operator share issue, agent reserve/payer, selected release, fn consumers, origin publish, continuity, meter, evidence export/verify, E1 consumer, keygen/bootstrap/submit/retry/query, author kinds, `acceptance.sh`/`authority-acceptance.sh` usage | `workspace.rs`, `transport.rs`, `share_issue.rs`, `agent_reserve*`, `agent_payer.rs`, `selected_release.rs`, `drain.rs`, `worker.rs`, `publisher.rs`, `provider_continuity.rs`, `meter.rs`, `main.rs` | `acceptance.sh`, `authority-acceptance.sh` (`:953-982`); nothing for the fn-consumer/publish/evidence sections | Commands exist (shard A §1.3), but shard A finds the fn-consumer family, `export-evidence`/`verify-evidence`, `operation-proof` and `traffic`/`mix` have no live caller. The `author --kind` list (`:913-917`) is a subset of what Lean accepts (`Host/Json.lean:3805`). The README recommends `acceptance.sh` (`:962`), which is broken (4.2). It has no "Honest state" section; that table is the root README's |
| `APPEND-PROOF.md` | 22 | mixed (`:18-22` is a run note) | `mini operation-proof` returns `minidregg-append-operation-proof-v1`; never signs or submits | `append_proof.rs` (type string present, 1 hit) | none | Command exists; no journey. "Qualification: ... operation396 in the isolated hrl room" is unreproducible prose with no evidence dir |
| `COHORT-TCP.md` | 223 | mixed (`:1-104` contract; `:105-223` five appended repair diaries) | MCE4 roster enrollment, hybrid X25519+ML-KEM-768, hybrid Ed25519+ML-DSA-65; `mix-live` actions; capacities | `cohort_tcp.rs` (`ENROLL_MAGIC = b"MCE4"`, `:425`; MCE2/MCE3 refused `:691-694`), `hybrid_kem.rs` | `cohort-native-tcp.py`, `cohort-two-host/*` | Head matches. The tail contradicts itself ("uncompiled at this shipment", `:173-174`; "PASS 9/9", `:178-182`; "uncompiled at publication", `:212`), and is superseded by `docs/evidence/traffic-v13` |
| `CRYPTO-TRANSIT-CONSTRUCTION.txt` | 5 | diary | ML-KEM-768 + XChaCha20Poly1305 in `native/crypto_transit.rs`; "2 focused primitive tests authored UNCOMPILED"; integration needs `mod crypto_transit` | `native/crypto_transit.rs`, `src/main.rs:90-92` | none | The integration is done (`main.rs:90-92`). "Pure ML-KEM" is superseded by hybrid (PQ-MAILBOX.md:27-33, commit `ec81de5d` "the pure-PQ path is deleted") |
| `CRYPTO-TRANSIT-RESTORATION.txt` | 4 | diary | `public_key_from_secret` removed; `validate_keypair(secret,public)` added | `native/crypto_transit.rs` (`fn validate_keypair` 1 hit; `public_key_from_secret` 0 hits) | none | Matches code; it is a log, not a contract |
| `crypto-transit-main.patch` | 8 | loose patch | adds `#[path = "../../crypto_transit.rs"] mod crypto_transit;` | `src/main.rs:90-92` | — | **Already applied**; nothing references the patch except `docs/construction/source-intake-20261003.json:3027` |
| `FRESH-CONTINUITY.md` | 67 | contract | `workspace::init_fresh`, `complete_fresh_onboarding`, `--continuity-ref`, `--verifier`, `--action onboard`, `receipt-continuity.pending.json`, states | `workspace.rs`, `fresh_onboarding.rs` (`fn init_fresh` ×2, `fn complete_fresh_onboarding` ×1, `"onboard"` ×1) | `fresh-onboarding-journey.sh` | Identifiers present; the journey has never run on record |
| `JOINED-MEMBER-JOURNEY.md` | 145 | contract | supplied-world spec, hook contract, sweeps | (Python only) | `joined-member-journey.py`, `test_joined_member_journey.py` | Unit-tested only; no recorded run |
| `KEY-ADOPTION.md` | 124 | contract (`:122-124` explicit "remains unverified") | `mini adopt-next-key`, ops 187–190, `possessionFrameValidated` | `key_adoption.rs`, `key_rotation.rs` (`"adopt-next-key"` ×8, `possessionFrameValidated` ×6); ops 187–190 registered as `NEXT_KEY_ADOPTION_*` | `journey-key-adoption.py` | Code matches; native composition never run |
| `MEMBER-WORKSPACE.md` | 141 | mixed (`:47-61` "Receiving evidence, October 2"; `:71-141` "successor" sections) | `home`, `mini-member-workspace-v1`, `app delegate-lifecycle`, `mini-member-app-v1`, ops 193/194 | `member.rs`, `member_app.rs`, `app_lifecycle.rs`, `shell.rs` (identifiers present; ops 193/194 registered) | none | Says "must not be treated as available in an older sealed Host" and "Native receiving remains pending" (`:139-141`); its Oct 2 evidence is not in `docs/evidence` |
| `PAID-COLD-ENTRY.md` | 177 | mixed (`:151-177` measured run on persvati) | `enrollment-bootstrap` HTTP routes v1/v2, `join --solana`, `pay-claim`, op 121, v2 memo of 485 bytes | `enrollment_bootstrap.rs`, `join_solana.rs`, `join_solana_v2.rs`, `pay_claim.rs`, `pay_memo_v2.rs` (`/mini/v1/metadata` ×7, `/mini/v2/claim/plan` ×3, `minidregg-enrol-pin-v2` ×3) | `jpay-e4.sh`, `jpay-v2.sh`, `jpay-bootstrap-budget.py`, `paid-entry-adapter.py` | Code matches. The measured run lives on persvati `/home/ember/build/...`; `jpay-v2.sh` says it has not passed |
| `PLATFORM-PROVISION.md` | 156 | contract | `platform-provision.py` check/start/units/stop; paid entries; `platform-task-readiness.py` | none (Python) | `platform-provision.py`, tests | Example plan hard-codes `/home/ember/build/...` (`:65-67`); "Actual receiving evidence must come from `start`" (`:116-118`): none recorded |
| `PLATFORM-SERVICE-CUT.md` | 31 | contract | `platform-service-cut.py prepare/stop` | none (Python) | `platform-service-cut.py`, tests | Unit-tested only |
| `PQ-MAILBOX.md` | 221 | mixed (`:171-221` review corrections and "Receiving results, 2026-10-03") | restricted PQ cascade, hybrid layers, `mix` CLI | `pq_mailbox.rs` (`MPB1`/`MPM1` refusal present), `hybrid_kem.rs`, `scheduled_transport.rs` | `cohort-*` | **Contradictions:** "Live enrollment is the roster MCE2 handshake" (`:184`) vs code MCE4 with MCE2 refused (`cohort_tcp.rs:691`). `qualification/pq-native-pipeline.py` (`:159`, `:214`) does not exist anywhere in the repo |
| `PUBLIC-INGRESS.md` | 163 | contract (`:61-81`, `:158-163` qualification notes) | `serve-public-proxy`, `serve-operator`, `operator-status`, `drain-operator`, `mini.control`, `mini-operator-drain-v1`, bounds | `public_proxy.rs`, `proxy.rs`, `transport.rs`, `operator_drain.rs` (`socket.with_extension("control")` at `:121`, `:214`; drain JSON type present) | `public-ingress-process.py` (echo Host) | Code matches. No deploy unit uses `serve-public-proxy`/`serve-operator` (`deploy/candidate/run.sh:157,182` and `deploy/grain-host/install-operator-stack:133` use monolithic `mini serve`) |
| `SELECTED-EXCHANGE.md` | 123 | contract | `mini selected-exchange` phases incl. `receive-transport`/`verify-transport`; home identities; known limit | `selected_exchange.rs` (`minidregg-selected-exchange-v1`, `public-peerable-v2`, `receive-transport` ×4, `cover-advance` ×7) | `selected-exchange-journey.sh` | Matches; journey PASS on main-lineage 10-08 |
| `SELECTED-SOURCE-PUBLISHER.md` | 62 | mixed (`:56-62` 2026-09-27 checkpoint) | `selected-source-sign`/`publish`; Host routes `selected-release-source-plan` / `-assemble` / `-check` | `selected_publisher.rs` | `selected-source-publisher-acceptance.sh` | "A native source event, exact lookup and protected POST fixture still require a Host image containing the new equality route" (`:60-62`): never run |
| `SESSION-REENROLL.md` | 158 | contract (`:151-158` "not yet qualified") | `mini session-reenroll --phase capture/resume`, ops 84/85 | `session_reenroll.rs` | none | Code present; no journey |
| `TRAFFIC-AUTH-CACHE-QUALIFICATION.txt` | 5 | diary | 8/8 focused tests, binary hardlinks, tcp-v8 "PENDING" | `cohort_tcp.rs`, `pq_mailbox.rs` | — | Superseded by traffic-v13 |
| `TRAFFIC-ENROLLMENT-CONSTRUCTION.txt` | 6 | diary | MCA1 handshake, PSK, "pure ML-KEM768/XChaCha, algorithm1, no classical hybrid" | — | — | **Contradicted by code:** no `MCA1` anywhere in `src/` (0 hits); the suite is hybrid |
| `TRAFFIC-MAILBOX-GROUPED-CONSTRUCTION.txt` | 4 | diary | tcp-v8 39/64 useful, grouped admission, "UNCOMPILED" | `cohort_tcp.rs` live mailbox | — | Log only |
| `TRAFFIC-PRIVACY.md` | 264 | mixed (`:186-264` measured runs and "Frozen second scheduled tranche") | `mini traffic` key/server/client fixed-cell duplex | `scheduled_transport.rs`, `transport.rs` | none in tree | `traffic` has no live caller (shard A). `:206-211` records that `selected-release-acceptance.sh` fails on current code |
| `TRAFFIC-READY-ALIAS-CONSTRUCTION.txt` | 4 | diary | ready.payload hardlink alias | `cohort_tcp.rs` (`ready.payload` ×1) | — | Log only |
| `WELCOME-CONTINUITY.md` | 61 | contract | `enroll --action welcome` with `ingressHex`, `join --welcome --verifier`, op 89 lookup only, `FreshBaseline::AdmittedReceipt` | `participant_enrollment.rs`, `fresh_onboarding.rs`, `workspace.rs` (`ingressHex` ×2, `AdmittedReceipt` ×5, `welcome-confirmed.frame` ×2) | `welcome-continuity-journey.sh` (runner `welcomecontinuity`) | Matches; runner results outside repo |
| `WORLD-PROGRAMMER.md` | 14 | contract | run `jworld-kind`, `-method`, `-board`, `-prototype` in order | `world_kind.rs`, `world_prototype.rs` | the four jworld hooks | None of the four is registered in `journey.sh`; never run on record |

### 1.4 The two loose files

- **`crypto-transit-main.patch`** (8 lines): a unified diff adding `#[path = "../../crypto_transit.rs"] mod crypto_transit;` beside `mod pq_mailbox`. `src/main.rs:90-92` already contains those lines, `native/crypto_transit.rs` exists, and nothing applies or reads the patch: `git grep` finds only `docs/construction/source-intake-20261003.json:3027`. **Delete.**
- **`selected-release-drop-reply.rs`** (95 lines): a stand-alone Rust program, a one-shot op-20 lost-reply proxy with `MAX_FRAME = 12_200_000` (`:11`). It is not a crate member and not compiled by Cargo. `selected-release-acceptance.sh:381` compiles it with bare `rustc --edition=2021 -D warnings` at run time, and `:44`, `:310`, `:513` and `:518` hash it into evidence. It is a twin of `hostraw.py proxy ... lose-reply` (`hostraw.py:109-144`). It lives or dies with `selected-release-acceptance.sh`, which is broken (4.2).

---

## 2. What it assumes of its surroundings

### 2.1 Binaries

- **Core four.** Every journey needs `minidregg-host`, `mini`, `minidregg-link-sqlite-store` and `minidregg-credential-signature-verifier`, as absolute, executable, pinned paths.
- **Per-hook extras:**
  - `grain-runtime`: J14, J17, M5, JPAY6.
  - `mini-hermes-test-provider`: J14, JPAY6.
  - `spk-host`: M6, unbuilt.
  - `pay-watcher`: JPAY1, JPAY4, JPAYE1, jpay-e4/v2.
  - `discord-entrance`: JCHAT.
  - `minidregg-client-consent`: the signing-consent provider, required by `welcome-continuity-journey.sh:15` and by the runner rows `welcomecontinuity` and `m6grain`.
  - `nock-run` and `hoonc`-built jams: JN2/3/3P/5, JJOB.
  - `launch-gate`: JPAY6.
  - An fn launcher and core image: `exchange`.
  - `rustc`: `selected-release-acceptance.sh`, and the `hermes` row's `product_tools rustc`.
  - `lake`: `jchan-epoch.sh` runs `lake env lean --run scripts/probe-channel-epoch.lean`; `objective-native-acceptance.py:342` runs `tests/objective-native/Mutate.lean`; `channel-lib/build.sh`.
  - An OpenSSH `sshd`: shell-journey, affordances, inspect, lawsat, law-leaf, jpriv2.
- **Default build paths.** `acceptance.sh:15-17` and its siblings default to `target/debug` paths inside the crate and the sibling crates.
- **Wrong default path.** jpay4/e4/v2 default `PAY_WATCHER_BIN` to `native/pay-watcher/target/release/pay-watcher`, which is not the workspace target directory (the workspace uses a root `target/`). It works only when `PAY_WATCHER_BIN` is set.

### 2.2 Host operations and Host CLI verbs the scripts exercise

- **Through `mini`.** The scripts reach Host ops through `mini` subcommands; the Rust side is shards A–F. Ops they name or send themselves: 0, 2, 3, 4, 6, 7, 8, 10, 11, 16–21, 24, 25, 89, 91, 103–107, 111, 112, 116–121, 129–137, 140, 142–144, 150, 160–163, 180, 187–190, 210–219. Each is present in `protocol/host-operations.json`; codes and receivers were checked by script in scratch.
- **Consent-provider frames.** Frames 220, 227 and 230–232 (`client_consent.rs:249,262,298,1116,1129`) belong to the local `minidregg-client-consent` provider, a second byte space that the registry does not cover. They are used by THIN and by the objective edit fixtures.
- **Direct Host CLI verbs.** Scripts call these on the Host executable, bypassing `mini`: `audit` (18 sites), `inspect`, `profile`, `describe`, `stdio`, `author`, `continuity-point`, `continuity-verify`, `carry-plan`, `carry-receive`, `presence-index`, `plan-ungated`, `signatures`, `assemble`, `job-money-explain`, `pay-job`, `pay-ledger`, `pay-enrol-probe`, `pay-enrol-ids`, `well-ledger`, `store-audit`, `selected-release-prepare`, `-assemble`, `-ingress`, `selected-release-fn-legacy-poll`, `enroll-key-assemble`, `objective-publication`, `store-epoch` (journey-rows:194). Every one was found in `Host/*.lean` **except `link-index`**, used at `j12i-links.sh:222,233`.
- **Raw socket frames.** About 15 scripts hand-build frames.
  - **v1 envelope** (version byte 1, no Host image pin): `jnock2.sh:60`, `jnock3.sh:58`, `jnock3p.sh:63`, `jnock5.sh:62`, `jjob.sh:116`, `jjob1.sh:95`, `jjob-money.sh:102`, `jeval.sh:72`, `journey-stranger.py:34`, and `j12x.sh:55` (both versions).
  - **v2 envelope**: `hostraw.py:47-50`, `jpay-v2.sh:233`, `journey-key-adoption.py:90`, `paid-entry-adapter.py:108`, `cohort-scratch-world.py:51`.
  - The server still accepts v1 (`transport.rs:177`, `matches!(envelope[0], 1 | 2)`, pin `None` for v1 at `:195-196`). Retiring v1 breaks nine journeys. Conversely the Host-image pin README:196-200 describes is client-optional.

### 2.3 OS facilities

- **GNU/Linux.** Assumed by `journey.sh:100` ("Requires: Linux"), GNU `date +%N`, `setsid`, `timeout`, `/proc/loadavg`, `du -sb` (`:851`), `pgrep -P`.
- **systemd.** `jpay6.sh` needs `systemd-run --user` and passwordless `sudo` (`journey.sh:1052`). `jpay-bootstrap-budget.py` needs `systemd-run` and user systemd. `platform-provision.py` uses `sudo -n systemctl` (PLATFORM-PROVISION.md:33-37).
- **bwrap and user namespaces.** `jpay6`, M5 and the hermes row; journey-rows:361-388 documents the Ubuntu 24.04 AppArmor restriction.
- **`/etc/subuid`, newuidmap, linger, sudoers rules.** The `m6grain` row.
- **sshd on loopback ports** 22422, 22423, 22433, 22434 and 22436. `jinspect.sh` and `jlawsat.sh` both default to **22436** (`journey.sh` hooks, `inspect-journey.sh:31`, `jinspect.sh:17`, `jlawsat.sh:9`, `lawsat-journey.sh:33`). They run sequentially, but a leftover sshd from one blocks the other.
- **macOS-only tools.** `acceptance.sh`, `authority-acceptance.sh`, `application-acceptance.sh`, `selected-release-acceptance.sh` and `selected-source-publisher-acceptance.sh` use `shasum -a 256`. On Linux `shasum` comes from Perl and may be absent on minimal images. Everything else uses `sha256sum`.
- **GNU `df -B1 --output=avail`** and a 50 GB free-space floor: the five traffic `check-*.sh` build scripts.

### 2.4 Network services

- Solana RPC is always synthetic or fixture-driven: `jpay*`, `paid-entry-adapter.py` (PAID-COLD-ENTRY.md:60-64).
- fn/NNTP: a real local fn node (`selected-exchange-journey.sh`, 127.0.0.1:11241 per the 10-08 evidence).
- Discord: a fake API (JCHAT; the evidence dir 2026-10-03-discord-world).
- ssh/scp to a remote host: `cohort-secrecy-check.py:70-72`, `cohort-native-tcp.py --remote`, `cohort-two-host/env.sh:16` (alias `w15b`).
- helm source: `fleet-migration-helm-probe.py` (`HELM_SRC_DIR`, a read-only copy of akapug/helm).

### 2.5 Other crates and repo files

Scripts depend on these repo files; all exist, checked by script:
- `deploy/shell/mini-shell-ssh`, `render-shell-key`, `mini-socket-proxy`, `mini-shell-ssh-credentials`
- `deploy/pay/mini-pay-watcher`
- `deploy/candidate/run.sh`, `params.sh`, `build.sh`
- `deploy/grain-host/launch-gate.rs`, `resolve-bwrap`
- `deploy/shell/templates/job/law.job.{json,shell}`, `deploy/shell/templates/room/workroom/template.shell`
- `scripts/check-audit-corrupted-leaf.sh`, `scripts/probe-channel-epoch.lean`, `scripts/workroom/provision.sh`, `scripts/spk-platform/*`, `scripts/protected-document-journey.sh`
- `tests/objective-native/Mutate.lean`
- `world/{call,send,activity,bounty,seats}/*.obend`
- `native/pay-watcher/fixtures`
- `native/grain-runtime/hermes-journey.sh`

Missing references:
- `qualification/pq-native-pipeline.py`, cited only by PQ-MAILBOX.md:159.
- `journey.d/jhasheq.sh`, cited by `jmarket.sh:3` as superseded and deleted. It is only a comment.
- `run/synth.py` (`jsync.sh:12`), assumed to be in an external jam directory.

---

## 3. Does it decide anything semantic?

These are scripts, so a "decision" here means one of three things: the test harness itself is the oracle; a script authors a semantic artifact that Lean should emit; or a deployed script chooses a semantic default. Most journeys correctly defer. Their refusal predicates require the Host's encoded refusal frame (`journey.sh:318-322`), or the Host's own `inspect outcome` decoding (`j12.sh:11-13`, `law-leaf-journey.sh:16-19`, `jrot-lookup.sh:14-15`). That is the right discipline. The exceptions:

1. **`genesis.sh` authors the genesis source by hand in jq, and is deployed.**
   - What it writes (`genesis.sh:115-219`): every genesis field, including `factoryPredicate: {type:"all",predicates:[]}` (`:125`), the sponsor's and the clock subject's `accountPredicate: all[]` (`:136`, `:146`), `algorithm: "1"`, the clock subject's `initialBalance: "0"`, and both birth contexts (`:200-219`).
   - Deployment: the file ships in the candidate (`deploy/candidate/package.py:106-107`; `deploy/candidate/run.sh:43-48`).
   - Lean does admit the result at `mini bootstrap`, so this is not an authority bypass. But the permit-all factory law is a semantic default chosen in shell with no parameter: any subject holding a factory observe grant may birth under it. It also imitates a Lean-owned structure, against ATLAS law 13 ("emit, never imitate").
   - Counterpart: a Lean genesis author taking `minidregg-candidate-genesis-params-v1`. `Host/Json.lean` already authors a `genesis` kind (`Host/Json.lean:3805` lists `genesis`). Blast radius: every deployed Store's factory law.
   - The `< 2^53` integer guard (`:51-54`) exists only because jq holds doubles. That is a tooling limit leaking into the deployment schema.
2. **`jpay-claim-law.jq` authors a policy predicate** (`:2-54`: the `eq`, `neg`, `allp`/`anyp`, `extend` and `widen` constructors over `authority/operation/pay-claim` and `pay/claim/authorized`), and `jpay-claim-law.sh` submits it. Its header says "Structural authoring only. Lean remains the sole policy/admission evaluator" (`jpay-claim-law.jq:1`). That is true for admission, but the *law text* is a jq artifact with no Lean emitter. It is the same pattern as the shell's hand-written `document_law`/`room_law`/`board_law` that shard A flagged.
3. **`journey.d/lib/thin-proxy.py` re-implements a Lean codec** (base-255 nat streams and the plan slot list, `:46-107`) to forge plans. It is test-only, but if the Lean codec changes, THIN can go green for the wrong reason: the proxy fails to splice and raises `SystemExit`, which the hook may read as a refusal. Section 8 asks for an emitted fixture instead.
4. **Harness oracles that decide on behalf of the kernel:**
   - `bind.sh:94-97`: "refused" means "not installed" plus any stderr.
   - `jpriv1.expected.tsv`: an expected transcript "authored from the script, not from a run" (`rooms-e2e.sh:19-20`).
   - `j12r.golden.txt` and `jdocuverse.golden.txt`: render goldens, legitimate as long as Lean owns the renderer, which `j12r.sh:305` says it does.
5. **`journey-timers/hostile.sh` and `ticker.sh` decide nothing** but would feed `accept()`'s count oracle. A timer whose reply was lost leaves its record uncounted and the step FAILS: "a lost receipt can make a step red, never green" (`journey.sh:349-352`). That is fail-closed and correct.
6. **`acceptance.sh`** constructs full intents with hard-coded capability IDs 41/51/53/54/61–64 (`:98-178`). It does not decide admission, but its hand-written intents are what went stale (4.2).

Correct deferrals worth naming:
- `journey.sh` J5 counts the client's local consent refusal separately and names the layer (`:716-727`).
- `selected-source-drop-reply.sh` and `selected-release-drop-reply.rs` retain the real native outcome and never synthesize one.
- `hostraw.py` "signs nothing, encodes no Lean value and decides nothing" (`:3-6`).
- The objective drivers require every refusal to be "the Host's, by name" (`objective-activity-native-acceptance.py:11-12`).

---

## 4. Flaws noticed

### 4.1 The definition of done does not finish, and one bad hook poisons the rest

**Evidence.** GitHub Actions `Build and gates` on main. `gate-logs` from runs 39905192725 (rev `307b13e`, 2026-10-23), 39056305841 (rev `334316d`, 2026-10-17) and 38977292707 (2026-10-16) were downloaded to scratch `ci-*/journey.log` and `summary.txt`.

- **Gate result.** `journey TIMEOUT 10960 killed after 10800s` (10-23) and `journey TIMEOUT 10925` (10-17). The 10-23 summary reads `gates: 6 red of 26 (rev 307b13e)`; the 10-17 summary is identical in form.
- **Root cause.** `check-journey.sh:70` sets `JOURNEY_BUDGET_S` to 14,400, while `local-gates.sh:136` kills at 10,800. The journey's own budget logic (`journey.sh:460-468`), meant to write FAIL rows naming the slowest steps, never gets the chance, and no `journey-result.json` is copied (`check-journey.sh:79-81`). Fix: budget at most gate timeout minus build time. The real fix is to stop running about 86 steps serially in one gate.
- **Hook cost.** K11 2,566–3,409 s, KIX 1,857 s, KCH 1,339–1,754 s, K12C 1,544 s, KBW 1,371–2,146 s, G 2,039 s (10-23). Four hooks alone exceed the gate.
- **Cascade (10-23).** K11 was killed at its 3,600 s hook limit, and KCH, KIX, KF, KH, K12C, K12I, K12T, K12N, K12E, K12M, K12R, K12H and KW all failed with `mini: cannot connect to /run/user/1001/jm.Nk5dhV/world.sock: Connection refused`. The world service died during K11, and `hook()` only verifies the service after a *successful* hook (`journey.sh:995-997`). One bad hook turns the next 17 rows into misleading reds. Fix: check `ours "$(server_pid)"` after every hook, and on loss mark the hook FAIL with "left the service down" and either restart or block dependents.
- **Persistent reds:**
  - **KBW** "1 rows off; births 20/20 installed under a writer" (all three runs).
  - **KC** `K-CLOCK FAIL 21/32` (all three).
  - **KCHR/KCHC** "no channel library at .../.lake/build/lib/libminidregg-channel.so" (all three). `check-journey.sh:40-44` builds the Host and six crates but never runs `channel-lib/build.sh`, so these two steps cannot pass in the gate as written.
  - **KH** "create 3 failed" (10-17).
  - **JMKT** "19 of 28 rows not as expected; first: row 3 (setup sponsor: enroll plan alice alice.key): usage: enroll plan NAME KEYFILE|PUBLIC-KEY-HEX NEXT-PUBLIC-KEY-HEX COSIGN-HEX" (10-17, 10-23).
- **Steps never reached on main in any recorded run** (run order after K10C): JLI KTPL J15 J17 J14 JPRIV1 JN2 JN3 JN3P JN5 JSYNC M3 M4 M5 M6 M7 M8 BD J12 J12W JNAMES P7KR THIN JDV JPD J13 JJOB1 JJOB JJOBM KCL J12A JCHAT JINSPECT JLS JPAY1 JPAY2 JPAY3 JPAYE1 JPAYE2 JPAYE3 JPAY4 JPAY6 JP2 JROT JROTL JRLANE JGATE JDISCLOSE JAUDIT. The runner rows cover some of these (M3, M4, M7, M8, JPAY1–4/6, JROT/JROTL/JRLANE/JGATE/JAUDIT via `row_journey`), but their results are not in this repository.

### 4.2 Scripts broken by current code (each path verified to exist or not)

| Script | Break | Evidence |
|---|---|---|
| `journey.d/j12i-links.sh` | calls Host CLI `link-index` (`:222`, `:233`); the arm was added in `28008e8a` (2026-10-01) and is absent now (lost in merge `a26328e9`, 2026-10-02; `git log -m -S'"link-index", [] =>'`) | `Host/Main.lean:7917` has only `presence-index` |
| `journey.d/jmarket.sh` | `enroll plan $f $f.key` (`:177`) without next key / cosign | CI 10-17 and 10-23 JMKT FAIL with the usage line |
| `journey.d/j12w.sh` | same grammar (`:121`) | inference from the identical line; never reached in CI |
| `journey.d/jdisclose.sh` | same grammar (`:48`) | same |
| `acceptance.sh` | content targets with `"schemaVersion": "1"` (`:222`, `:337`); the Host's content command version is 10 (`Kernel/ContentResource.lean:432`; client constant `workspace.rs:266` and the comment at `:262-263`, "v1–v8 are refused") | TRAFFIC-PRIVACY.md:206-208 records the same failure for `selected-release-acceptance.sh` ("content command schemaVersion1 differs from current commandVersion9") |
| `selected-release-acceptance.sh` | the same, plus "legacy logical-image `store read-to` failed (`published byte record is missing`)" | TRAFFIC-PRIVACY.md:209-211 |
| `selected-release-drop-reply.rs` | only meaningful inside the above | `selected-release-acceptance.sh:381` |
| `journey-timers/ticker.sh` | waits `while ... [ ! -S "$W/public/mini.sock" ]` (`ticker.sh:10`) and gates every tick and certify on it (`:16`, `:22`); `journey.sh:158` puts the world socket at `$JOURNEY_RT/world.sock` and passes it to J0 (`:573`), so `$W/public/mini.sock` never exists | `newparticipant-acceptance.sh:50` defaults to `ROOT/public/mini.sock` only when no socket is given |
| `native/resource-client/scripts/cohort-native-tcp.py` | passes `mix-live ... --key worker.key` (`:69-70`) without `--roster`; `cohort_tcp.rs:1073-1077` requires `--roster` for every non-cover action and `args.finish()` refuses unknown flags | COHORT-TCP.md:43-44: "a bare 32-byte Ed25519 roster key or key file ... refuse by name" |
| `journey.d/jprotected-docs.sh` (JPD) | execs `scripts/protected-document-journey.sh`, whose header says it "has only had bash syntax checking; it does not claim a completed journey" (`:2-4`) | — |
| `journey.d/jchan-relay.sh`, `jchan-client.sh` | default socket root `/home/ember/build/chr` and `/home/ember/build/chc` (`jchan-relay.sh:43`, `jchan-client.sh:53`) | breaks on any box without that path unless `CHR_SOCK_ROOT`/`CHC_SOCK_ROOT` is set |

### 4.3 Framework bugs and ordering hazards in `journey.sh`

1. **Steps that can only record FAIL.**
   - M6 is permanently UNBUILT: no `journey.d/m6.sh` (`journey.sh:1008`); pinned in `scripts/gates/journey-unbuilt.tsv`.
   - JJOB1 and JJOB need `JOB_PROGRAMS` (and JJOB also `NOCK_RUN`), checked at `jjob1.sh:29` and `jjob.sh:34`. J14 needs `GRAIN_RUNTIME` and `TEST_PROVIDER` (`j14.sh:53-54`); J17 needs `GRAIN_RUNTIME`.
   - Their step functions (`journey.sh:1058-1059`, `:1029`, `:1031`) do not call `needs_env`, unlike JN2/JN3/JN3P/JN5/JPAY6 (`:1043-1046`, `:1052`). In the gate, `check-journey.sh` exports none of these variables (`:66-74`), so these steps record FAIL instead of UNCONFIGURED.
2. **Duplicate step function.** `step_JJOBM` is defined twice (`:1053`, `:1060`), and the second silently replaces the first. `TITLE[JJOBM]` is also defined twice (`:249`, `:274`).
3. **Frontier order differs from run order.** `STEPS` places P7KR, THIN and JSERVE before J5 (`:192`), but P7KR and THIN run at `:1136-1137`.
4. **Two refusal-tag generations.** `REFUSAL_TAG` is v6 (`:317`) while `decode()` strips v4 (`:339`).
5. **The timer protocol is orphaned.**
   - `JOURNEY_TIMER_COUNTS` and the `accept()` wait loop (`:353-368`, 30 s of polling) exist, and `jmarket.sh:96-101` reproduces the logic. No in-tree launcher starts `journey-timers/*`: `git grep` finds only comments.
   - `ticker.sh` is broken (4.2), and `journey_certify` (`:413-432`) already does in-process what `ticker.sh` did.
6. **Stale cross-references.**
   - "scripts/local-gates.sh gate 5" (`journey.sh:86`; also `check-journey.sh:2`); `journey` is the last of 27 gates.
   - `docs/JOURNEY.md:8` points at `journey.sh:189`.
7. **Custody of other people's keys.** Every shell journey copies the newcomer's secret key into the sponsor's home ("CUSTODY: copy newcomer secret into sponsor home (enroll plan+seal sign with both keys in one process)": `shell-journey.sh:281`, `j12.sh:132`, `j10c.sh:193`, `j14.sh:213`, `j15.sh:147`, `j17.sh:182`, `jtemplates.sh:219`, `jdocuverse.sh:161`, `jpriv1.sh:191`). The 2026-09-30-shell-journey evidence lists it as operator row 2, a "current enrollment contract" owned by lane M3. The journey corpus still certifies a path where the operator holds the participant's secret. `selected-exchange-journey.sh`'s `--action possess` flow (SELECTED-EXCHANGE.md:101-112) shows the alternative exists.
8. **Weak poles.**
   - `bind.sh:97`: any stderr counts as a refusal reason.
   - `jpay-claim-law-tests.sh` tests control flow against a fake `mini` written into `/tmp` (`:7`, `:12-61`) and keeps the fixture dir after the run.
   - `rooms-e2e.sh --self-check` proves only that expected rows are literals of the script (`:22-23`).
9. **`jinspect.sh`** allocates its short dir with `mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/ji.XXXXXX"` (`:14`), not through `journey_shortdir`. Its socket is not in the margin table and is not measured on exit, and the directory is never removed. It is a second, weaker copy of `shortdir.sh`.

### 4.4 Lost-reply / retry hazards inside scripts

- **`acceptance.sh`'s `drop-first-submit.sh`** (`:241-250`) makes the real Host write its outcome to a nonexistent path. Whether the Host committed before failing to write depends on the Host CLI's order of operations. If the Host fails *before* committing, `retry --mode submit` installs instead of replaying, and the jq check at `:271-272` fails red (fail-closed). The fixture's meaning, though, depends on unstated Host CLI internals.
- **`jpay-claim-law.sh --apply/--lookup`** (`:14-16`) states exact-call reuse with no new nonce. Good.
- **`hostraw.py proxy`** keeps each reply and its decision log (`:133-138`). Correct for JROTL.
- **The `consent_refused` sentence match** (`journey.sh:332-335`) depends on one exact English string. A wording change in `client_consent.rs` turns J5's two local refusals into NOT-REFUSED (red). That is fail-closed but brittle.

### 4.5 Prose that is wrong now

- Root `README.md:85` ("the call (C1-C8) and send (S1-S7) drivers exist and no journey row runs them"; blame `4ef4e808`, 2026-10-05): `journey-rows:105-133` has run `call` and `send` since `f5897dd8` (2026-10-07), and also `domain`, `upgrade` and `chargedfailure`. S1–S13 now, not S1–S7 (`journey-rows:117-121`).
- Root `README.md:79` (blame `741cf714`, 2026-10-04) says main "fails J5 and J8 ... the fix is open". CI on main passes J5 and J8 on 10-16, 10-17 and 10-23 (J5 detail "8/8 refused", J8 "5/5 refused").
- `docs/JOURNEY.md:10-19`: six rows, "call and send ... are not rows"; actually 30 rows.
- `PQ-MAILBOX.md:184` says MCE2; the code is MCE4. `:159` cites a nonexistent script.
- `TRAFFIC-ENROLLMENT-CONSTRUCTION.txt:2-4`: MCA1 and "pure ML-KEM768 ... no classical hybrid"; the code is hybrid with no MCA1.
- `CRYPTO-TRANSIT-CONSTRUCTION.txt:4` still instructs integration that is done (`main.rs:90-92`).
- `COHORT-TCP.md:173-174` vs `:178-182`: "uncompiled" vs "compiled: nine focused tests PASS".
- `workspace.rs:262` comment "grammar v9" vs constant `"10"` (`:266`). This is drift in Rust, noted here because the journey scripts copied "1" from it.

---

## 5. Unwired / undone, twins, and what the corpus proves about the demo path

### 5.1 Scripts wired to nothing

Each item below is not a `journey.sh` step, not a runner row, not called by another wired script, and not in a gate.

- **`journey.d`:** `jeval.sh`, `jpay-e4.sh`, `jpay-rail.sh`, `jpay-v2.sh`, `jprivate-docs.sh`, `jworld-board.sh`, `jworld-construction.sh`, `jworld-kind.sh`, `jworld-method.sh`, `jworld-prototype.sh`, `jworld-composed-source.py`, `jworld-construction.py`, `jworld-prototype.py`, `job-refund-recovery.py`, `job-refund-legacy-recovery.py`, `jpay-bootstrap-budget.py`, `lib/run-growth.sh`. That is 17 files, 3,569 lines. `jpay6-hermes-acp` is used by JPAY6 and `jhostupgrade.sh` by the `hostupgrade` row, so they are wired.
- **Crate root:**
  - continuity/carry/key: `continuity-journey.sh`, `carry-source-journey.sh`, `carry-stage-journey.py`, `fresh-onboarding-journey.sh`, `journey-key-adoption.py`
  - fleet: `fleet-contention.sh`, `fleet-sign-growth.sh`, `fleet-migration-replay.sh`, `fleet-migration-helm-probe.py`
  - cohort/traffic: `cohort-*` (3), `cohort-two-host/*` (6), `scripts/*` (5), `check-traffic-crypto-alias.sh`
  - doc search: `doc-search-journey.py`, `doc-search-protected-check.py`
  - latency: `latency-prebaseline.py`, `latency-same-store.py`
  - platform: `platform-*.py` (6, unit-tested only), `joined-member-journey.py`, `composed-scenario.py` (unit-tested only), `public-ingress-process.py`, `paid-entry-adapter.py`
  - objective: `objective-activity-quote-submit-journey.py`, `objective-work-account-journey.py`
  - selected: `selected-release-acceptance.sh`, `selected-source-publisher-acceptance.sh`, `selected-source-drop-reply.sh`
  - legacy: `acceptance.sh`, `authority-acceptance.sh`, `application-acceptance.sh`
  - timers: `journey-timers/*`
  - other: `newparticipant-from-manifest.sh`, `jpay-claim-law*` (3)
- **Rust features documented in prose with no journey at all:** `session-reenroll` (SESSION-REENROLL.md), `operation-proof` (APPEND-PROOF.md), `traffic` (TRAFFIC-PRIVACY.md), `serve-public-proxy`/`serve-operator`/`drain-operator` beyond the echo-Host process check, `export-evidence`/`verify-evidence`, the fn consumer worker family, origin-publish (README). This agrees with shard A's 45 unreached commands.
- **Shard A's 127-command list** (`rc-A/arm-module.tsv`) **omits `fleet-sign`**. It is dispatched separately at `src/main.rs:4514` and documented at `:724`, and it is used by `fleet-sign-journey.sh:88`, `fleet-sign-growth.sh` and `dregg-client-sign:7`.

### 5.2 Twin and duplication census

| Twin set | Members | Reachable one | Delete |
|---|---|---|---|
| Lost-reply / fault proxies | `journey.d/lib/hostraw.py proxy` (lose-reply, never-forward; `:109-144`); `selected-release-drop-reply.rs` (95, rustc at run time); `selected-source-drop-reply.sh` (23, host shim); `acceptance.sh` generated `drop-first-submit.sh` (`:241-250`); `welcome-continuity-journey.sh` heredoc `proxy.py` + `ssh-shim` (`:102-127`); `jpay-v2.sh` transparent fault relay (`:416-530`); `cohort-native-tcp.py` 2 s delay relay (`:225-234`) | `hostraw.py` (JROTL, runner `journey`) | the rest. Fold the delay/drop modes into `hostraw.py proxy` |
| Raw Host frame encoders | `hostraw.py:47-50` vs inline encoders in `jnock2/3/3p/5.sh`, `jjob.sh`, `jjob1.sh`, `jjob-money.sh`, `jeval.sh`, `j12x.sh`, `journey-stranger.py`, `journey-key-adoption.py`, `paid-entry-adapter.py`, `cohort-scratch-world.py`, `jpay-v2.sh` (about 15 copies; nine use v1) | `hostraw.py` | the inline copies (`import hostraw`) |
| Consent/codec imitation | `thin-proxy.py` slot parser (`:46-107`) vs the Lean codec | — | replace with a Lean-emitted forged plan (section 8) |
| Cohort orchestrators | `cohort-native-tcp.py` (503, roster MCE4) vs `native/resource-client/scripts/cohort-native-tcp.py` (185, pre-shared key, broken) | root | `native/resource-client/scripts/cohort-native-tcp.py` |
| Traffic build gates | `native/resource-client/scripts/check-cohort-async.sh`, `check-traffic-adoption-consumer.sh`, `check-traffic-emission-memory.sh`, `check-traffic-pipeline.sh`, root `check-traffic-crypto-alias.sh`: five 14–17-line copies of "free-space floor, focused nextest, release build, copy binary" | none (one-off lane tasks) | all five |
| Protected docs | `journey.d/jprivate-docs.sh` (171, unhooked) vs `scripts/protected-document-journey.sh` (307, run by JPD via `jprotected-docs.sh`) | the scripts/ one (unproven) | `jprivate-docs.sh` |
| Continuity journeys | `continuity-journey.sh`, `fresh-onboarding-journey.sh`, `welcome-continuity-journey.sh`, `carry-source-journey.sh`: identical 30-line preamble (arg checks, `mktemp -d /tmp/mini-continuity.XXXXXX`, `rows.tsv`, `stop_server`; e.g. `continuity-journey.sh:1-30` vs `fresh-onboarding-journey.sh:1-30`) | welcome (runner) | merge into one driver with modes, or delete the three ungated ones |
| Short-dir allocators | `journey.d/lib/shortdir.sh` vs `jinspect.sh:14` mktemp vs the continuity family's `/tmp/mini-continuity.*` vs `jchan-*.sh` `SOCKROOT` defaults | `shortdir.sh` | the others |
| Legacy acceptance vs journey steps | `acceptance.sh` ≈ J2/J4/J6 + joint write; `authority-acceptance.sh` ≈ J3/J5/J7/J8 + revocation; `application-acceptance.sh` ≈ J5/J6 + app birth (`docs/JOURNEY.md:31-37`) | journey.sh | all three (the joint write and revocation become steps if wanted) |
| Shell J0–J8 vs workspace J0–J8 | `shell-journey.sh` (M4, 444) vs `journey.sh` J0–J8 inline | both gated (m4 row; journey row) | keep both: they test different entrances |
| Pay rails | `journey.d/jpay-rail.sh` vs `journey-rows` `product_pay_step`/`row_jpay` (`:730-781`) | runner | `jpay-rail.sh` |
| Pay entry | `jpay-e4.sh` (830) vs `jpay-v2.sh` (679) vs `paid-entry-adapter.py` (362) vs `jpay-bootstrap-budget.py` (183): four drivers of `enrollment-bootstrap`/`join --solana` | none gated | keep one if pay ships, else all |
| Job refund | `job-refund-recovery.py` vs `job-refund-legacy-recovery.py` (a legacy variant) | none | both |
| World-programmer Python | `jworld-construction.py` and `jworld-composed-source.py` both `exec` the head of `jworld-prototype.py` (`jworld-construction.py:9`, `jworld-composed-source.py:6`) | none | the family |
| Latency | `latency-prebaseline.py` (adapts `latency-same-store.py` by import) | none | both, or fold |
| Objective edit fixtures | three 5-line `objective-native-edit-*.py` request-edit snippets exec'd by `objective-native-acceptance.py` | objective row | fold into the driver as data |
| Test-of-test | `test_*.py` (9 files, 1,556 lines) test the orchestration scripts, not Mini | unit-tests gate | delete with the scripts they test (all are platform/composed tooling) |
| Fleet | `fleet-journey.sh` (M8) vs `fleet-sign-journey.sh` (fleetsign) vs `fleet-contention.sh`, `fleet-sign-growth.sh` (measurements) | m8, fleetsign | measurements |
| Python-vs-shell same journey | `joined-member-journey.py` (supplied-world shell sessions) vs the shell hooks J12/K10C/JCHAT (fresh world); `composed-scenario.py` vs `journey.sh` (composed phases on a supplied world, `composed-scenario.py:40-56`) | journey.sh | the supplied-world orchestrators belong in ops tooling, not the client crate |

### 5.3 What the corpus proves about the demo path

The demo node is the shell plus documents (`new`, `show`, `append`, `edit`, `link`, `backlinks`) and boards (root README:79).

| Capability | Steps / drivers | Best recorded result | On main? |
|---|---|---|---|
| Fresh Store, enroll, create, delegate, read/write, refusals, reopen/retry, law change, deny-all (J0–J8) | `journey.sh` inline | CI 10-16/17/23 all PASS; docs/evidence 2026-09-30-candidate J0–J8 PASS | **yes (CI, not in docs/evidence)** |
| Same through `mini shell` over ssh (M4) | `shell-journey.sh` | 2026-09-30-shell-journey 89/89 (lane `m4-shell` `b105bd7`, persvati) | lane only (runner m4 results outside repo) |
| Growth at 1,000 records (G) | `journey.sh` G | CI 10-23: write max 4.354 s, p99 2.973 s, cold reopen 15.391 s, PASS. docs/evidence: only 10-record runs (frontier G) | **yes (CI)** |
| Malformed input and hostile clients (J12X, JSERVE) | hooks | CI PASS 20/20 and 12/12 | **yes (CI)** |
| Documents through the shell (J12) | `j12.sh` | 2026-09-30-shell-docs 134/134 (lane `p-shell-docs` `ffcba4fe`) | **no**: unreached in CI |
| Doc pull/push (J12W) | `j12w.sh` | none | **broken** (stale `enroll plan`) |
| Document kernel rows (K12C/T/N/E/M/R/H, K12I, WEB) | hooks | K12C PASS CI 10-17; the rest cascade-failed 10-23 or are unreached | partly (K12C only); K12I broken |
| Boards / law clauses (J13, KCL, JLS, J12A) | lane journeys | J13 45/45 on lane `p-law` | **no** |
| Stranger refusals, disclosure (J5, JDISCLOSE) | inline + hook | J5 PASS CI; JDISCLOSE none | J5 yes; JDISCLOSE broken |
| Store audit (JAUDIT) | hook | runner only | no record in repo |
| Rotation (JROT, JROTL) | hooks | README: JROT 3/30 red, JROTL PASS at `4795b657` (runner, outside repo) | unverifiable here; the node has no rotation (README:79) |
| Rooms, invitations, templates (K10, K10C, KTPL, JLI, JNAMES) | hooks | K10 PASS CI; the others unreached | K10 only |
| Chat (JCHAT) | hook | SKIPPED in all three 10-01 results; never PASS | no (README:81 agrees) |
| Story / credit / Hermes (J15, J17, J14) | hooks | PASS on lane builds 2026-10-01 (frontier J6: J6–J8 SKIPPED in those runs) | **no**: lane only, and those runs did not run J6–J8 |
| Private rooms (JPRIV1) | hook + rooms-e2e | README: rooms row 0 of 88 rows; the expected file is "NOT FROM A RUN" | no |
| Pay (JPAY1–4, 6, E1–E3) | hooks + runner | runner only; 2026-10-05-clock-law (JPAY3 on lane) | no record of main in repo |
| SPK (M6) | none (`m6.sh` absent) | 2026-10-01-spk-apps 44/44 is `scripts/spk-platform/jspk1.sh`, not this shard | no |
| Objective (objective, activity, seats, bounty, call, send, domain, upgrade, objectrecord, chargedfailure) | runner | README: objective 17 rows PASS at `4795b657` | runner only |
| Selected exchange over fn | runner `exchange` | 2026-10-08 PASS ×2 on `0ea31db5` (main lineage) | **yes (runner, recorded)** |

Checking the root README "Honest state" rows 79–94 against this:
- **Row 79** cites the 89/89 shell journey correctly as a lane run. Its claim that main fails J5/J8 is stale: CI passes both.
- **Row 80** (J15/J17 lane only; rooms red): consistent.
- **Row 81** (JCHAT never PASS): consistent.
- **Row 84** (objective PASS at `4795b657`): the runner table is not in the repo, so unverifiable here.
- **Row 85** (no row runs call/send): stale.
- **Row 86** (44/44 SPK rows): its evidence is `scripts/spk-platform`, not `journey.d`; M6 is still UNBUILT.
- **Row 94** (pay journeys on fixtures): consistent; nothing in `docs/evidence` records a main run.

---

## 6. Size and shape

### 6.1 Lines by family

| Family | Files | Lines | Share of 45,250 script lines |
|---|---|---|---|
| A framework + fixture (`journey.sh`, `lib/`, timers, `newparticipant-*`, `genesis.*`, stranger) | 15 | 2,444 | 5.4% |
| B world-Store J/K hooks (docs, law, kernel, hardening) | 42 | 8,812 | 19.5% |
| C lane journeys (shell, provisioning, law-leaf, affordances, inspect, lawsat) + wrappers | 14 | 2,633 | 5.8% |
| D rooms / chat / private / Hermes / channel (+ `channel-lib`) | 16 | 3,888 | 8.6% |
| E pay + job money | 19 | 6,052 | 13.4% |
| F nock / compute / world programmer | 19 | 3,999 | 8.8% |
| G objective | 16 | 5,398 | 11.9% |
| H platform / joined / composed / latency | 14 | 4,325 | 9.6% |
| I traffic / cohort | 15 | 1,114 | 2.5% |
| J selected / fn | 5 | 1,381 | 3.1% |
| K continuity / keys | 6 | 1,216 | 2.7% |
| L fleet (incl. `m8.sh`) | 8 | 972 | 2.1% |
| M legacy acceptance | 3 | 1,250 | 2.8% |
| O host upgrade | 1 | 210 | 0.5% |
| Test-of-test (`test_*.py`) | 9 | 1,556 | 3.4% |
| **Scripts total** | **202** | **45,250** | |
| Prose (`*.md`, `*.txt`, patch) | 25 | 3,170 | |
| **Shard total** | **227** | **48,420** | |

Test-of-test: 1,556 lines (3.4%) test the platform and composed orchestrators. One more test-of-test lives inside the corpus: `jpay-claim-law-tests.sh` (169) runs against a fake `mini`. Test fixtures inside the corpus: `jpriv1.expected.tsv` (102), two goldens (23), two `.hoon` (156), `genesis-params.example.json` (61), `tests/fixtures/render` (88 KB, not counted).

### 6.2 A minimal demo subset

**Keep** (the demo is shell + documents + boards on one public node). Total about **4,487 lines** before trimming `journey.sh`. Cutting the 70 unused `TITLE`/`step_` lines and hook declarations brings `journey.sh` to roughly 900, and the set to about **4.2K lines, 9.3% of today's corpus**.

| File | Lines | Why |
|---|---|---|
| `journey.sh` | 1,180 → ~900 | J0–J8, G, K4 inline; hook framework (fix 4.1 and 4.3 items 1–4) |
| `journey.d/lib/shortdir.sh` | 145 | socket placement |
| `journey.d/lib/genesis-params.sh` | 29 | candidate params |
| `journey.d/lib/hostraw.py` | 231 | the one raw-wire tool (absorbs the twin encoders) |
| `newparticipant-acceptance.sh` | 206 | J0 fixture |
| `genesis.sh` + `genesis-params.example.json` | 281 | **deployed** (move to `deploy/candidate/`) |
| `journey-stranger.py`, `journey-private.sh` | 67 | J5 hostile leg; helper |
| `shell-journey.sh` + `journey.d/m4.sh` | 464 | J0–J8 through the shell (the demo entrance) |
| `provisioning-acceptance.sh` + `journey.d/m3.sh` | 264 | newcomer self-provisioning |
| `journey.d/j12.sh` | 285 | documents through the shell |
| `journey.d/j12w.sh` | 279 | doc pull/push (fix `:121`) |
| `journey.d/j12x.sh`, `jserve.sh` | 544 | internet-facing robustness |
| `journey.d/jrefusal-lane.sh` | 246 | refusal-lane DoS bound |
| `journey.d/jdisclose.sh` | 165 | what strangers learn (fix `:48`) |
| `journey.d/jstoreaudit.sh` | 101 | store integrity |

**Optional, if boards/law are in the demo:** `law-leaf-journey.sh` + `j13.sh` (351), `jclosure.sh` (147), `jtail.sh` (158; `checkpoint certify` runs on the node).

**Delete or move out of the client crate**, by group:
- **Legacy acceptance** (1,250): `acceptance.sh`, `authority-acceptance.sh`, `application-acceptance.sh`.
- **Traffic/cohort** (1,114): all of family I, plus the prose COHORT-TCP, PQ-MAILBOX, TRAFFIC-PRIVACY and the four TRAFFIC-*.txt. Research per root README:91.
- **Platform/joined/composed/latency + their tests** (4,325 + 1,556): ops tooling for a different deployment shape.
- **Pay** (6,052): `journey.d/jpay*`, `jpay-claim-law*`, `paid-entry-adapter.py`, `job-refund-*`. Not deployed (README:94); keep in a pay lane.
- **Nock/compute/world programmer** (3,999).
- **Objective** (5,398): runner rows belong to the Objective lane; move under `tests/objective-native/` or `world/`.
- **Rooms/chat/private/Hermes/channel** (3,888): not on the node (README:79-81).
- **Selected/fn** (1,381) and **continuity/keys** (1,216): fn second node not in demo; continuity journeys never run.
- **Fleet** (972): keep only if helm-on-Mini is the near goal.
- **Kernel K-rows not in the demo** (most of family B, about 6,700): K10*, K11, KCH/KCHR/KCHC, KIX, KF, KH, KW, KBW, KC, JJ, BD, K12C/T/N/E/M/R/H/I, WEB, JDV, JPD, JNAMES, JLI, KTPL, JMKT, THIN, P7KR, JGATE, JROT, JROTL. Several are the kernel's real regression suite and could stay as a separate nightly journey, but not as the definition of done of a demo.
- **Wrappers and lane journeys not in the demo** (about 1,900): affordances, inspect, lawsat and their wrappers, m5, m7, m8.
- **Loose files** (103): the patch and the drop-reply program.
- **Diaries** (about 1,000 of 3,170 prose lines): the six `.txt` files; the dated tails of COHORT-TCP, PQ-MAILBOX, TRAFFIC-PRIVACY, PAID-COLD-ENTRY, MEMBER-WORKSPACE and APPEND-PROOF. Repo law: state docs are present-state rewrites.

Removed: about **41,000 script lines** (91%) and about 2,500 prose lines, if the K-row nightly is moved out as well. Keeping the K-rows as a nightly in place keeps about 10.9K lines (24%).

---

## 7. Deployability on a small public Linux VM

### 7.1 What must exist to run the demo journey on the box (or in CI for it)

- **Binaries:** the four pinned (Host, mini, store, verifier); `jq`, `sha256sum`, `setsid`, `timeout`, `pgrep`, `xxd` (`journey.sh:115`); `python3` with `cryptography` (journey-stranger) and PyNaCl (pay rows only); an OpenSSH `sshd` binary on loopback for M4/J12/J12W.
- **Directories:** a writable `$XDG_RUNTIME_DIR` or `/run/user/UID`, else `/tmp` (`shortdir.sh:53-62`).
- **Not needed for the demo:** systemd user sessions, sudo, bwrap or subuid. Those are only for JPAY6, M5/hermes and m6grain.
- **Wall time:** J0–J8 + G at 1,000 records is about 2,100 s of the 10-23 CI run. The full STEPS list does not fit the 3 h gate (4.1).

### 7.2 Host-specific paths and identities baked into scripts

| Site | Assumption |
|---|---|
| `journey.d/jchan-relay.sh:31,43`; `jchan-client.sh:53` | default socket root `/home/ember/build/chr`, `/home/ember/build/chc` |
| `cohort-two-host/env.sh:3,16,19` | `/srv/lanes/W15-TRAFFIC-V13`, ssh alias `w15b`, burst-gate as host A |
| `journey.sh:1052`; `jpay6.sh:21,96`; `jpay6-hermes-acp:2-3` | hbox and persvati named as the boxes that have or lack Hermes; `mini-grain-controller@7001` "persvati keeps one" |
| `latency-prebaseline.py:10,71` | "hbox is shared and is not kept quiet" |
| `PLATFORM-PROVISION.md:65-67` | example plan paths under `/home/ember/build/...` |
| `PAID-COLD-ENTRY.md:171-172` | evidence on persvati `/home/ember/build/pay-bootstrap-budget-6075-{8,9}/` |
| `test_composed_scenario.py:30,191`; `test_platform_stage_root.py:50-56` | `unitUser: "hbox"`, `/var/lib/mini-r2` (fixtures, harmless) |
| `genesis.sh:18` | `/var/lib/mini/clock` (documented deploy layout) |
| `journey-rows:484` | operator default uid 1001 / name `ember` for m6grain |
| `journey-rows:787` | refuses fn inputs under `/tank/fn` (hbox) |

No script embeds `2.28.141.27` or `/Users/`.

### 7.3 macOS vs Linux

- `journey.sh` and most hooks are Linux-only: `setsid`, GNU `date`, `/proc`.
- The four legacy and selected acceptance scripts use `shasum`, a macOS-ism; 2026-09-27-application-birth ran "on one fresh private Mac Store".
- The fixture fleet therefore splits into Mac-era and Linux-era scripts, and the Mac-era ones are the broken ones.

### 7.4 What these scripts imply for exposure

- **Safe on the public box.** The journeys bind only loopback sshd ports and Unix sockets. `jweb.sh` asserts that `mini web --listen 0.0.0.0:PORT` is refused (`jweb.sh:16` row `bind-any-refused`, asserted at `:137`). That is the property a public demo wants, and it is unreached in CI.
- **What JSERVE checks.** Strangers on the internet would reach the public socket only through ssh forced commands. JSERVE checks hostile framing (trickle, 50 silent clients, queue bound 32) on the same socket.
- **No PID-file discipline in hooks.** `stop_server` is PID-file based with an argv check (`journey.sh:495-509`). The hooks that start their own `mini serve` use the same pattern, by local inspection of `jtail.sh` ("stops it (by its recorded pid)") and the continuity family's `stop_server`. `jchat.sh:243` uses `pkill -P`, by parent PID, not by pattern. No script kills by pattern.
- **Key custody.** A malicious enrolled member is the threat the shell journeys under-test. They run every participant's enrollment with the participant's secret copied to the sponsor (4.3 item 7). A deployment following those scripts would put friends' keys on the box. FRIENDS.md and `jpriv2.sh` (JP2, "a friend's key never touches the box") exist, but JP2 is unreached in CI and has no recorded run.

---

## 8. Questions for the Lean side (and for the crate owner)

For the Lean side:

1. **`link-index` Host CLI.** `j12i-links.sh:222,233` needs `minidregg-host CONFIG link-index`, printing "opened log height H from the checkpoint at B ..." and `links {...}`. `28008e8a` added it at `Host/Main.lean`; it is absent now (merge `a26328e9`), while `linkIndexJson` (`Host/Main.lean:1163`) and the audit's `links` line (`:6291`) remain. Was the verb dropped on purpose (and K12I's reopen row should move to `audit`), or lost in a merge?
2. **Content command version.** `Kernel/ContentResource.lean:432` sets `commandVersion := 10`. Which declaration refuses a content target whose `schemaVersion` is not 10, and with which `RefusalReason`? The scripts that still send `"1"` (`acceptance.sh:222,337`) would then fail with a named reason rather than silently.
3. **Genesis authoring.** Is there a Lean genesis author for `minidregg-candidate-genesis-params-v1` that `genesis.sh` could call (`Host/Json.lean:3805` lists a `genesis` kind)? And is a permit-all `factoryPredicate` (`genesis.sh:125`) the intended deployed factory law, or should genesis take the factory predicate as a parameter?
4. **Shell `enroll plan` grammar.** The current usage is `enroll plan NAME KEYFILE|PUBLIC-KEY-HEX NEXT-PUBLIC-KEY-HEX COSIGN-HEX ... or add --no-prerotation` (CI JMKT detail). Is pre-rotation mandatory for every newcomer enrolled through the shell (a Lean admission requirement), or a client default? JMKT, J12W and JDISCLOSE need one or the other.
5. **v1 socket envelope.** `transport.rs:177` still admits version 1 (no Host image pin), and nine journey scripts send it. Is there a Lean-side reason to keep v1 (an old operator config?), or can the broker refuse it?
6. **Consent-provider frames 220, 227, 230–232.** They are not in `protocol/host-operations.json`. Which Lean module owns their numbering (`Kernel.NativeThinConsent` per `jthin-consent.sh:4`)? Should they have a registry like the Host ops, so that `thin-proxy.py` could use an emitted forged-plan fixture instead of a Python codec?
7. **K-CLOCK 21/32 and KBW "1 rows off".** Both fail in every CI run on main. Which rows (`jclock.sh` rows 1–32; `jbirthwin.sh` `stale-birth`/`same-name-again`) disagree with the current clock law and birth-window declarations (`ClockLaw.clockPredicate`, `birthSlack`)? Is the script or the kernel wrong?
8. **KH "create 3 failed".** Does `jhide.sh`'s create of field 3 on a declared cell now need `--fields` (K-FIELD-CLOSURE, `undeclaredField`), i.e. is it a script lag behind `jclosure.sh`'s law?
9. **K11 runtime.** K11 takes 2,566–3,409 s for six appends and four tails on CI. Is per-author stream admission expected to cost this much, and what in the Host makes stream appends slow (the `staleTarget` re-plans, room `under` checks)?

For the crate owner:

10. Should the definition of done be split into a demo journey (J0–J8, G, M3, M4, J12, J12W, J12X, JSERVE, JRLANE, JDISCLOSE, JAUDIT) that finishes inside the gate, and a nightly kernel journey for the rest?
11. `genesis.sh` and `genesis-params.example.json` ship in the candidate. Move them to `deploy/candidate/`?
12. Is the operator-holds-the-newcomer's-secret enrollment (`shell-journey.sh:281` and eight hooks) still the contract, or should the journeys switch to the `--action possess` flow?
13. Which runner-row results (`$JOURNEY_ROOT/TIP/results.tsv` on the journey box) should be committed to `docs/evidence`, so that README "Honest state" rows can cite a main result in-repo rather than "runner table outside this repository"?

---

*Scratch artifacts (all under `/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/rc-G/`):*
- `wc-all.txt`, `fam.json`: line counts and families
- `scan.json`, `inv.json`, `inv.txt`: per-script `mini` commands, Host CLI verbs and ops
- `step-hook-status.txt`: the step to hook map
- `evidence-map.tsv`
- `ci-39905192725/`, `ci-39056305841/`, `ci-38977292707/`: the downloaded CI gate logs
- `tools/*.py`: the extractors
