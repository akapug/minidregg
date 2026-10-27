# grain-runtime, shard A: the entry point (`src/main.rs` and the crate's drivers)

| field | value |
|---|---|
| shard | grain-runtime A, "the entry point" |
| crate | `/Users/ember/dev/minidregg/native/grain-runtime` (package `minidregg-grain-runtime`, bins `grain-runtime` and `grain-provider-bridge`) |
| reviewer | Opus reader, fan-out review 2026-10-26 |
| date | 2026-10-26 |
| method | every file below read in full with the Read tool; `path:line` cited for every claim; no build, no test run |

Files covered (line counts from `wc -l`):

| file | lines |
|---|---|
| native/grain-runtime/src/main.rs | 20,075 |
| native/grain-runtime/Cargo.toml | 32 |
| native/grain-runtime/README.md | 413 |
| native/grain-runtime/BYOK.md | 66 |
| CONFIG-MIGRATION.md [deleted eedb450a] | 182 |
| CONTROLLER-WRITE-SCOPES.md [deleted eedb450a] | 66 |
| native/grain-runtime/RESIDENT-DELIVERY.md | 62 |
| RESIDENT-OUTCOMES.md [deleted 2050a348] | 61 |
| native/grain-runtime/RESIDENT-REQUESTS.md | 104 |
| native/grain-runtime/RESOURCE-WORKSPACE-EVIDENCE-2026-09-28.md | 49 |
| native/grain-runtime/RESOURCE-WORKSPACE-MIGRATION.md | 9 |
| SESSION-FAILURE.md [deleted 2050a348] | 105 |
| native/grain-runtime/SYSTEMD-MANAGERS.md | 96 |
| native/grain-runtime/TERMINAL.md | 9 |
| native/grain-runtime/acceptance.sh | 872 |
| native/grain-runtime/agent-two-participant-foreground-journey.sh | 233 |
| native/grain-runtime/agent-two-participant-preflight.sh | 262 |
| native/grain-runtime/hermes-journey.sh | 398 |
| native/grain-runtime/policy-crash-acceptance.sh | 280 |
| native/grain-runtime/prepare-agent-controller-configs.sh | 59 |
| native/grain-runtime/provider-direct.sh | 151 |
| native/grain-runtime/receipt-recovery-acceptance.sh | 269 |
| native/grain-runtime/bootstrap-native-controller.py | 128 |
| native/grain-runtime/journeys/byok-native.py | 337 |
| deploy/grain-host/mini-grain-controller@.service (context only) | 20 |
| deploy/grain-host/README.md (context only) | 175 |
| **total** | **24,513** |

Appendices: A (function inventory of main.rs), B (every subprocess call site), C (admin commands and dispatch RPCs), D (MCP tools and their gates), E (external-effect notes and derivability), F (reconciliation actions), G (journal field index). The crate-synthesis table is at `/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/gr-A/subcommand-table.md`.

Also read for cross-checks (not owned by this shard, cited where used): `src/journal_io.rs`, `src/controller_digest.rs`, `src/public_status.rs`, `src/grain_source.rs` (first 80 lines), `src/resource_tools.rs` (birth planner 284-438), `src/systemd_manager.rs` (158-310), `deploy/grain-host/bwrap`, `deploy/hermes/mini-hermes.service`, `protocol/host-operations.json`, `Host/Main.lean` (ops 19, 30, 31), `Host/ProviderUsage.lean`, `Host/Json.lean:2540-2570`, `Kernel/NativeHostContext.lean:41-112`, `Compiler/GrainResourceBirthController.lean:1-46`.

## Executive summary (15 lines)

1. `grain-runtime serve CONFIG` is a single-threaded, journal-driven supervisor for one AgentGrain task: one `mpsc` input channel fed by three socket threads (control, private admin, optional SPK dispatch), a blocking `input.recv()` loop (main.rs:17470-17900), and 20 ms poll loops inside long operations.
2. It never speaks the Host framing itself: every native read and write is a subprocess of the pinned `mini` client (`query`, `submit`, `retry --mode lookup`, `author`, `profile`, `continuity`, `meter`, `workspace`, 13 `agent-*` verbs) or `minidregg-host CONFIG inspect ...`; it reads raw reply frames only for op 255, 19, 30 and 31, and those byte checks agree with the Lean arms (Host/Main.lean:6744-6754, 7317-7324).
3. Rust *authors* every grain intent JSON (`grain_source::source`, main.rs:8222-8225; birth sources via `resource_tools::plan_content_birth`), retains it, and lets Lean admit it; Lean is the gate for authority, holds and the provider tariff quote.
4. Rust is the gate for: every price except provider metering (operator-configured `reserve`/`charge` per command, tool, dispatch and foreground profile, settled verbatim, main.rs:14114-14118, 14967-14971, 12433-12439, 6468-6474); which tools a worker may call (main.rs:12221-12514); provider row selection (main.rs:335-344); and retry/no-retry semantics, all bounded by Lean only through `charge <= reserved`.
5. It also makes two *inferences about native history* that no Lean check backs: "lookup absent + submitter stopped = never happened" (main.rs:11505-11516, still charges the configured fee) and the `OwnManagedLaw` reservation-identity proof used to auto-settle a parent hold after a restart (main.rs:16360-16386, 16840-16847).
6. Lost reply: every native call is journaled as `Pending{attempt}` before `mini submit` (main.rs:8281-8296); an unresolved call is only ever looked up, never resubmitted (main.rs:16986-17173); a provider response is journaled before the worker is acknowledged (main.rs:9900-10005), so a crash between provider answer and delivery leaves the provider purse held for an audited Lean-quoted settlement and the HTTP request is never re-sent.
7. Hole (F1): an `uncertain:` provider outcome (for example an upstream timeout mid-stream) or a crash after the durable send boundary but before any outcome (`send_started && outcome == None`) has no settlement path at all, and `attach`/`hermes`/`run` all refuse while it is retained (main.rs:13547-13549, 14374-14376): `metered_audit_path` refuses it (main.rs:1586-1596) and `abort` refuses it (main.rs:16687-16689); the purse stays reserved indefinitely unless something native expires it.
8. Secrets: no provider bearer ever enters the process (broker ticket, main.rs:9560-9625); custody keys are passed by *path* in argv to `mini` (main.rs:8307-8309) and by path in env to the launcher, which refuses to mount them (deploy/grain-host/bwrap:55-71). Worker stderr is inherited into the controller's log (main.rs:14621).
9. Sandbox: Linux workers run through the operator's `deploy/grain-host/bwrap` launcher (user/pid/ipc/uts/cgroup/net namespaces, `--clearenv`, transient user-systemd unit, MemoryMax 2G, no seccomp); the Rust-side check of that confinement is a basename/argv-shape check (main.rs:2931-2935, 392-410, 14390-14400); allowlisted `run NAME` commands need no confinement at all (main.rs:2927).
10. Size: 20,075 lines = 1,836 test lines (main.rs:18240-20075, 44 tests) + 18,239 code; about 5,450 code lines (30%) are the SPK application-API dispatch purse in three live generations (v1 digest reserve, v2 op58/59, v3 event26 "lifetime"), with no `TODO` and no deleted twin.
11. Within main.rs the twins are: v2/v3 pairs of reserve, inspect, sign-payer, mark-send, recover and poll (eight pairs, ~2,000 lines); a 380-line foreground preflight duplicating each tool's argument checks (main.rs:12520-12898); three copies of the 15-arm input pump (main.rs:13388-13446, 14126-14197, 15096-15167); and the attach/reserve/settle/disconnect tool-purse cycle hand-rolled four times despite `reserve_tool_operation` (main.rs:11160).
12. All 53 declared modules (49 non-test) are reached (most through `impl Runtime` blocks in sibling files); four are test-only; `provider_bridge` is a second binary, `provider_choice` and `provider_homelab_tests` are `#[path]` submodules, and `credentials.rs` is compiled into resource-client too.
13. Reachability: the controller is exercised by seven crate drivers; the strongest recorded run is `hermes-journey.sh` (SIGKILL mid-write, automatic recovery; docs/evidence/2026-09-30-hermes-participant) with a scripted ACP agent; the README's own table says Hermes is "executed ... off on the public node" (README.md:83).
14. Deploy mismatch: the production unit `deploy/hermes/mini-hermes.service` is not named `mini-grain-controller@TASK.service`, yet scoped workers require exactly that unit's MainPID (main.rs:17212-17240, 689) and a root registration or three env vars (systemd_manager.rs:158-183); the shipped template sets one of the three, so it refuses to start without a registration.
15. A demo-critical minimum (one Hermes prompt with a provider, MCP workspace/publish tools, hard/soft attach, restart recovery) can drop the whole dispatch subsystem, foreground tools, legacy birth families and the v2/v3 duplicates: roughly 8,000 of main.rs's 18,239 code lines.

## The seven questions the lead asked, settled

**(1) Main loop, what it reads, what it writes.** The loop is `serve` (main.rs:17470-17900): `control::start` on `controlSocket` (main.rs:17506), `control::start_admin` on `stateDir/admin.sock` (main.rs:17507-17509), optional `dispatch_custody::start(socket_path, host_uid)` (main.rs:17510-17515); three forwarding threads push `Input` values (enum at main.rs:17176-17198) into one channel; `startup_recovery()` runs before the first `recv` (main.rs:17517); then `loop { input.recv() ... }` (main.rs:17593-17899). There is no fn/NNTP client (README.md:369-370: "`fn_read` is not advertised until a fixed-config NNTP path is wired") and no direct Host socket I/O: `UnixStream::connect` appears in main.rs only to probe a stale control socket (main.rs:17911). Reads from the Host: signed resource and policy views through `query_observation_via` / `query_policy_observation` (main.rs:7746-7752, implemented in query_observation.rs:126-138), exact lookups via `mini retry --attempt A --mode lookup [--socket S]` (main.rs:17054-17064, 3627-3641, 7460-7465), `mini profile` (main.rs:9629-9644), `mini continuity` (main.rs:9834-9852), `mini meter` (main.rs:10122-10141), `mini agent-*-lookup` (main.rs:3722-3729, 3829-3836), and `minidregg-host CONFIG inspect ...` (main.rs:2480-2489, 5551-5561, 6227-6238, 6278-6289). Writes: `mini submit --intent-kind grain-intent` (main.rs:8298-8318), `grain-policy-install-intent` (main.rs:7851-7868), `grain-birth-intent` or `binary` (main.rs:10923-10944), `mini workspace --action submit|create` (main.rs:11349-11360, 11984-11997), and the v2/v3 `mini agent-*` seal/submit verbs (main.rs:4527-4547, 4939-4957, 5429-5439, 5695). Frames it reads byte-wise: 255 (pre-submit refusal, main.rs:2461-2467), 19 (provider quote, main.rs:10260-10263), 30/31 (current birth author, main.rs:7162-7169).

**(2) Where it decides.** Provider choice: Rust (`provider_task_row` -> `ProviderTable::select`, main.rs:335-344; "Absent: the first row listing `model`", main.rs:285-288), operator table is the policy, Lean prices the route and checks it at settle (main.rs:2627-2637). Budget arithmetic: Rust computes a pre-reserve maximum (main.rs:1701-1727, 9445-9458) and validates the Lean quote (main.rs:1729-1842); for everything that is not a provider call the charge is an operator constant from the controller config, settled verbatim (section 3). Retry on provider failure: none, by Rust policy; uncertain stays held (main.rs:9990-9994); an SDK retry of identical bytes gets the cached response (main.rs:9645-9722). Deliverable outcome: Rust stages resident completion/final delivery only on ACP `stopReason == "end_turn"` (main.rs:14977-14983). Session failure classification: delegated to `hermes_outcome` (main.rs:14878-14893, 15016-15019) and `session_failure` (admin command main.rs:17727-17734). Tool permission: Rust allowlists (main.rs:12221-12514, 12946-12966, 14203-14206) with Lean admitting each native write by capability.

**(3) Lost reply between provider answer and Host delivery.** Ordering: the gateway reports `Outcome`; `provider_record_outcome` writes `provider-N.controller-outcome` and headers with `write_new` (fsync) and saves the journal with `outcome = "received:..."` *before* the reply channel acknowledges (main.rs:9958-10004, 9220-9247); the Lean quote is fetched and journaled (main.rs:10006-10172); only after a successful local socket write does `Delivery` push a replay entry and save (main.rs:10300-10411), and only then is settlement attempted (main.rs:9262-9269). On restart: `recover` re-looks-up any pending provider transition (main.rs:15957), notes "crossed durable send boundary ... uncertain" only when there is no outcome (main.rs:15958-15966), tries `recover_delivered_provider_response` (main.rs:16056, provider_recovery.rs:109), then `fence_provider` disconnects a still-reserved purse (status 3 -> 5/7) and records "provider reservation fenced; external send/response requires exact audit" (main.rs:13874-13901). The operator's `reconcile provider audited` re-quotes the retained response through Lean without a live lease and settles that charge (main.rs:16435-16660). The request is never re-sent; the Hermes turn is lost (the worker is gone). If the crash came after `send_started` was saved but before any outcome, there is no settlement route at all (see finding F1).

**(4) Secrets.** Provider keys: never in the controller; `provider_route` asks the key broker (`mini_keys::client::Broker::load(credential_broker, euid)`, main.rs:9568-9579) for a single-use ticket (main.rs:9588-9605), refuses a ticketless non-homelab authorization (main.rs:9607-9609); the audit line prints provider, credential label and endpoint only (main.rs:9195-9204). Custody keys: by path in argv (`--key PATH`, main.rs:7861-7862, 8307-8309, 10937-10938, 5690-5691) and by path in env to the launcher (main.rs:3462-3472); no key bytes are read by main.rs. byok-native.py checks that no plaintext bearer reaches controller state (journeys/byok-native.py:330-335).

**(5) Sandbox.** Scoped Linux workers: `deploy/grain-host/bwrap` (namespaces and `--clearenv` at bwrap:116-133, transient unit limits at bwrap:159-162, mount refusal of controller secrets at bwrap:55-71) plus the sibling `launch-gate` fence (main.rs:17267-17281). Rust checks only that the program basename is `bwrap` (main.rs:2931-2935), the argv shape for provider prompts (main.rs:392-410), and the gate protocol string (main.rs:3436-3445). Unscoped commands get `setsid` and process-group signals only (main.rs:14024-14032, 13583-13665). macOS uses `sandbox-exec` with an operator profile; acceptance passes `(version 1)(allow default)` (acceptance.sh:526-534), i.e. no confinement. No seccomp anywhere.

**(6) Why 20K lines.** 1,836 test lines (9.1%); ~5,450 lines of SPK application-API dispatch custody in three generations; ~2,000 lines of v2/v3 near-duplicates within that; ~380 lines of preflight duplicating tool argument checks; ~180 lines of three copied input pumps; repeated "is anything unresolved" walls (62 reads of `/grain/status` as string codes). Table in section 6.

**(7) Modules called vs declared.** All 49 non-test modules (of 53 declared at main.rs:3-62) are reached from `serve` or a subcommand; 10 have no `module::` reference in main.rs and are reached through `impl Runtime` methods or other modules (list in section 5.1 and the scratch table `/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/gr-A/subcommand-table.md`).

---

## 1. What this code is and does

### 1.1 Cargo.toml (32 lines)

Package `minidregg-grain-runtime` 0.1.0, AGPL, `publish = false` (Cargo.toml:1-7). Two binaries: `grain-runtime` from `src/main.rs` and `grain-provider-bridge` from `src/provider_bridge.rs` (Cargo.toml:9-15); the second is the in-sandbox HTTP-to-Unix bridge the launcher executes as `/agent/grain-provider-bridge` (deploy/grain-host/bwrap:134-135). Dependencies are exact-pinned: `libc =0.2.189`, `serde =1.0.229`, `serde_json =1.0.151`, `serde_yaml =0.9.34` (deprecated, README.md:216-217 admits it), `sha2 =0.10.9`, `ring =0.17.14`, and four path crates: `signed-api-path`, `inference-scheduler`, `compatible-upgrade-custody`, `mini-keys` with `default-features = false` "the key broker client ... it holds no key" (Cargo.toml:17-28); the dev-dependency enables the full broker so tests send through a real one (Cargo.toml:30-32). The crate has no `[workspace]` table and no `Cargo.lock`; it is a member of the root workspace (`/Users/ember/dev/minidregg/Cargo.toml` members list). Yet `native/grain-runtime/target/` exists (2.9 GB measured with `du -sh`) and every driver defaults to `$HERE/target/debug/grain-runtime` or `target/release` (acceptance.sh:82, receipt-recovery-acceptance.sh:14), and README.md:9-13 says "Build this small crate independently ... `cargo build --manifest-path native/grain-runtime/Cargo.toml`", which for a workspace member writes to the root `target/`. The crate-local `target/` and those defaults are leftovers of a pre-workspace layout (guess: drift, not a deliberate separation).

### 1.2 README.md (413 lines) and the prose contracts

README.md is the operator manual for the controller and doubles as its specification. It states the model: "The Lean native host decides every transition. The Rust controller reads the task through signed `mini query`, authors a `grain-intent` through the Lean host via `mini submit`, and retains each exact signed attempt" (README.md:3-7). It documents the connector protocol (`attach hard|soft`, `run NAME`, `hermes PROMPT`, `status`, `recover`, `disconnect`, README.md:23-26), the admin socket (README.md:27-32), hard vs soft semantics (README.md:34-41), the foreground tool protocol with a client-chosen 32-hex request ID and `tool-result`/`tool-ack` (README.md:43-64), the config shape (README.md:66-105), the provider task, gateway and metering rules (README.md:107-205), wall clocks and the MCP timeout config parse (README.md:207-229), ACP session retention and the receipt-report-in-next-prompt rule (README.md:231-258), the read/publish tools (README.md:264-297), the resource workspace tools (README.md:299-306), managed worker-law renewal (README.md:308-316), the launch gate and cgroup proofs (README.md:317-349, 398-403), and the reconciliation verbs (README.md:350-359). The README is accurate to the code in every place I checked (for example the 16-entry replay bound README.md:165 vs main.rs:9382-9384, 10386-10388; the 4 KiB receipt report README.md:249 vs main.rs:7558-7560; `maxIterations` 1..6 README.md:132-135 vs main.rs:346-352). It is also prose that changed with every lane: it contains present-tense claims that cite specific historical runs ("Native scripted fixture `him5` proved ...", README.md:395-396) and a paragraph saying "These source consumers require the corresponding native feature bundle and native qualification before deployment" (README.md:412-413).

| contract file | what it specifies | implemented in | status from this shard's view |
|---|---|---|---|
| BYOK.md | member provider keys via `mini key`, broker custody, `grain-runtime provider-provision TEMPLATE POLICY NEW` (BYOK.md:57) | main.rs:17986-17992 -> provider_provision.rs | exercised by journeys/byok-native.py:251-258 |
| CONFIG-MIGRATION.md | `config-migrate active|stopped`, request schema, archive layout, owner-key adoption | main.rs:17938-17943, admin `config migrate` main.rs:17665-17673 -> config_migration.rs | no crate journey; "staged for the owner's shared Rust batch; no additional compiler was started by this lane" (CONFIG-MIGRATION.md:145-146) |
| CONTROLLER-WRITE-SCOPES.md | `controller-write-scopes [preflight|receipt] CONFIG [REQUEST]`, v2 response type | main.rs:17932-17937 -> controller_write_scopes.rs | no crate journey |
| RESIDENT-DELIVERY.md | resident final delivery plan/deliver | main.rs:17950-17955, admin main.rs:17706-17717 | no crate journey |
| RESIDENT-OUTCOMES.md | `resident-outcome` supersession of a historical completion | main.rs:17956-17961, admin main.rs:17718-17726 | no crate journey; forensic operator assertion baked in (RESIDENT-OUTCOMES.md:20-27) |
| RESIDENT-REQUESTS.md | `hermes-room resident CONFIG`, queue limits, preflight/prepare/admission | main.rs:18009-18014, admin main.rs:17674-17693 | J14 evidence outside crate |
| RESOURCE-WORKSPACE-EVIDENCE-2026-09-28.md | a dated *partial* run: refused restart, operator-assisted repair, then failed on missing `config.yaml` | (evidence, not a contract) | a historical diary entry living beside the specs |
| RESOURCE-WORKSPACE-MIGRATION.md | workspace tools vs legacy fixed birth families, deletion criterion for the twin | main.rs:12267-12317 | the twin is still present (section 5) |
| SESSION-FAILURE.md | `session-failure` retrospective closure, including a "legacy forensic admission" restricted to "task8781 / operation94" (SESSION-FAILURE.md:96-98) | main.rs:17962-17967, admin main.rs:17727-17735 | a one-incident receiver kept in the product binary |
| SYSTEMD-MANAGERS.md | root registration `/etc/mini/controllers/TASK.json`, manager selection, `controller-launch` | main.rs:17922-17931 -> systemd_manager.rs | contradicts the shipped template unit (section 7) |
| TERMINAL.md | `terminal SOCKET [soft]`, `attach terminal-v1` framed protocol | main.rs:18154-18174 -> terminal.rs; serve arms main.rs:17616-17646, 17844-17886 | no crate journey |

### 1.3 main.rs, part by part

The table maps every line range of main.rs to its role. Prose follows for the big pieces.

| lines | content |
|---|---|
| 1-62 | crate doc, 53 `mod` declarations (4 `#[cfg(test)]`; `credentials` under `#[allow(dead_code)]` because "One source shared with `mini key`", main.rs:32-35) |
| 63-82 | imports, `type Result<T> = Result<T, String>` (main.rs:82) |
| 84-467 | configuration types: `Config` (86-116), `ToolTask` (120-171), `ForegroundToolProfile` (175-178), `DispatchTask` (184-203), `DispatchSignerPin` (207-213), `lifetime_purse_signers` (219-252), `ProviderTask` (256-311), `OnBehalfOf` (318-321), `ProviderRouteRecord` (326-331), `provider_task_row` (335-344), `provider_max_iterations` (346-352), `select_provider_metering` (357-382), `provider_required_network` / `provider_command_route` (384-410), `checked_lifetime_worker_wall` (412-430), `PublicationGrant` (434-439), `Authority` (442-448), `AllowedCommand` (452-467) |
| 469-1210 | the journal: `Journal` (471-567, 45 fields), `Connection` (571-576), `Pending` (580-589), workspace records (593-727), publication records (731-761), birth records (765-1066), `ForegroundAttempt` and tombstone (800-890), `HoldProof` (625-643), `managed_law_candidates` (651-666), `derivable_effect_note` (670-676), `prove_prior_run_stopped` (681-693), `ChildRecord` (1142-1156), `HeldCharge` (1160-1179), `ReserveAnchor` (1183-1210) |
| 1212-1600 | provider and dispatch attempt records: `ProviderAttempt` (1214-1253), `DispatchAttempt` (1259-1300), `LifetimeDispatchCustody` (1304-1345), `ApplicationApiAttempt` (1352-1380), lifetime reply verification (1390-1492), `ApplicationApiPhase` (1496-1503), `ActiveApplicationApi`/`ApplicationApiRoute` (1505-1540), `DispatchSettlement`/`ProviderSettlement` (1553-1578), `metered_audit_path` (1586-1596) |
| 1598-1842 | provider tariff slice: `ProviderMeteringPin` (1603-1614), `provider_route_code` (1617-1624), `provider_hold_amount` (1628-1634), `provider_route_pin` (1637-1687), `provider_metering_metadata` (1689-1699), `provider_max_charge_bound` (1701-1727), `provider_quote_charge` (1729-1842) |
| 1844-2267 | `ProviderReplay`, `AuthoritySlot`, `HermesSession`, `impl Journal` validators (1897-2218) and `Journal::fresh` (2219-2266) |
| 2269-2499 | file helpers (`write_new`, `retain_exact_private`, `bounded_policy_bytes`, `sha256_*`, `retained_exact`, `bounded_regular_file`) and `inspected_pre_submit_refusal` (2372-2499) |
| 2501-2717 | small helpers: workspace names, retry evidence names (2515-2552), `atomic_json` (2554-2557), `decimal` (2559-2566), `previous_accepted_index` (2568-2587), observation grants (2589-2615), provider coordinate checks (2617-2660), Hermes home and SQLite fingerprint (2662-2717) |
| 2719-3290 | config validation `validate_with_workspace` (2722-3239) and `validate_resource_workspace_record` (3244-3290) |
| 3292-3342 | `PHASE_*` constants, `ActiveProvider` (with `Drop` revoking the gateway, 3304-3311), `Runtime` (3313-3342) |
| 3344-3533 | `impl Runtime` basics: work origin, parent work lease, emit, gateway revoke, `claim_completion`, worker unit naming, launch gate, `worker_env`, authority builders |
| 3534-6797 | SPK application-API dispatch purse custody (v1 `dispatch_reserve`, v2 `dispatch_reserve_v2` + inspect + sign-payer, v3 `dispatch_reserve_v3` + inspect + sign-payer + mark-send-v3 + settlement inspection), `dispatch_rpc` (6637-6779), `answer_dispatch` (6780-6797) |
| 6798-6920 | `provider()` authority, `open`/`open_mode` (6812-6915), `save` (6916-6920) |
| 6921-7401 | receipt reconstruction: publication (6921-7032), birth (7033-7217), born registry checks (7218-7280), provider settlement (7281-7401) |
| 7402-7562 | `verified_publication_report` (the receipt block injected into the next prompt) |
| 7563-7752 | subprocess helpers (`next_id`, `command_output`, `work_output`, `supervised_*`), shared-app resolution (7654-7736), query wrappers (7737-7752) |
| 7753-7958 | managed worker law: subjects, `renew_worker_policy` (7774-7892), `require_managed_worker_policy` (7893-7938), `author_grain_policy_bytes` (7939-7958) |
| 7959-8467 | the core native transition: `mark_hold_as` (7976-8009), `record_reserve_confirmation` (8010-8101), `transition_as_with_witness` (8112-8467) |
| 8468-9172 | MCP tool dispatch entry `handle_tool` (8468-8493) and the forward application-API caller (v2 and lifetime): begin (8494-8717), poll (8719-9096), inspect (9102-9172) |
| 9173-10488 | provider gateway handling: lease check, `handle_provider` (9185-9272), drain (9273-9306), prepare/reserve/route/profile/replay (9307-9722), before-send and native continuity (9723-9899), outcome, Lean quote, delivery, settle (9900-10488) |
| 10489-11007 | fixed-family and application/session resource birth (`finish_no_birth`, `create_resource`) |
| 11009-12219 | resource workspace tools: read-only, propose, tool purse helpers, submit, recover, attempts, import/export reference, create, recover-birth |
| 12221-12515 | `tool_call`: the MCP tool table |
| 12517-13449 | foreground tools: preflight (12520-12898), `foreground_tool` (12903-13157), result/ack/audit (13159-13361), foreground API pump (13363-13449) |
| 13450-14200 | attachment and physical control: reconnect, `conversation_new`, `attach` (13523-13582), `stop_and_reap_owned` (13583-13665), `disconnect` (13672-13784), `fence_dispatch|provider|tool` (13785-13944), `run` (13945-14200) |
| 14201-15261 | tool catalog (14203-14312) and the Hermes ACP driver: `hermes`, `hermes_session`, `hermes_session_inner` (14318-15022), `acp_response` (15024-15261) |
| 15262-16090 | restart recovery: v2/v3 dispatch reserve recovery (15262-15734), `recover` (15736-16090) |
| 16091-17173 | operator reconciliation: dispatch audit (16095-16239), hold reconcile (16240-16431), provider audit (16432-16660), aborts (16661-16784), `needs_startup_recovery` (16785-16806), `startup_recovery` (16811-16835), `automatic_reconcile` (16840-16875), effects acknowledgement (16877-16942), worker audit (16943-16978), `retry_pending_slot` (16986-17173) |
| 17176-17468 | `Input` enum; free functions for signals, systemd, launch gate, cgroup proof, process table, ACP framing, display forwarding, hard interrupt |
| 17470-17918 | `serve` and `clear_stale_control_socket` |
| 17920-18238 | `main`: 25 subcommands |
| 18240-20075 | `#[cfg(test)] mod tests` (44 `#[test]` functions) |

#### 1.3.1 Configuration (`Config` and friends, main.rs:84-467)

`Config` is `deny_unknown_fields` camelCase JSON (main.rs:84-116): pinned `mini` and `host` executables and `hostConfig`, optional `hostSocket`, `controlSocket`, the parent `custodyKey`, `stateDir`, `cwd`, decimal `task`, `subject`, `capability`, `queryCapability`, optional `policyControlCapability`, optional `toolTask`, `foregroundTool`, `dispatchTask`, `providerTask`, and the `commands` allowlist "selected by its configured name. Its arguments are fixed by the operator" (main.rs:112-115).

`ToolTask` (main.rs:120-171) is a separately owned grain for MCP effects: its own subject, capabilities, custody key, parent witness capabilities, fixed `reserve`/`charge`, `allowedPublications`, `allowedReads`, an optional `resourceWorkspace` directory, three birth-family allowlists, `registeredSharedApplications`, `allowedApplicationApiRoutes` (event21), `allowedApplicationLifetimeRoutes` (event26), three Host SHA-256 pins gating those features (`agentApiHostSha256`, `lifetimeApiHostSha256`, `currentBirthHostSha256`), and an optional `room` (main.rs:166-170).

`DispatchTask` (main.rs:184-203) is a third grain, the "AgentGrain purse for app API attempts", with an external `socket_path` and `host_uid` (the SPK resident host's peer UID), an optional private `operator_socket` for "source-owned v2 reserve planning/assembly", and a `reserve_signer` pin. `lifetime_purse_signers` (main.rs:219-252) accepts exactly three slots with roles 4, 8, 1 at index 0 whose decoded signing headers name the pinned key ID and epoch, and returns approval records that include the key *path*.

`ProviderTask` (main.rs:256-311) is a fourth grain: `homelab` scheduling config, `reserve`, `maxInputTokens`/`maxOutputTokens` ("an operator contract", main.rs:273-276), optional `contextWindowTokens`, `model`, `providers` (the operator table path), optional `provider` row pin, optional `onBehalfOf` member, `credentialBroker`, `gatewayBind`, byte and time bounds, optional `maxIterations`, and `localFixtureHostNetwork`. The doc comment says "Every provider call is charged by the Host's per-route tariff (`Kernel/ProviderRoute.lean`); there is no fixed provider charge" (main.rs:266-271), and a test confirms a legacy `charge` field now fails to parse (main.rs:19611-19614).

`AllowedCommand` (main.rs:452-467): `name`, absolute `program`, fixed `args`, `systemdScope`, optional `wallTimeSeconds`, decimal `reserve` and `charge` with the comment "an operator configured charge, not a cryptographic measurement" (main.rs:464-466).

Validation (`validate_with_workspace`, main.rs:2722-3239) enforces absolute paths, `controlSocket` directly inside `stateDir` (main.rs:2741-2743), canonical decimals, `toolTask` requires `policyControlCapability` (main.rs:2755-2757), `foregroundTool` requires `toolTask` and charge <= reserve (main.rs:2758-2774), `dispatchTask` is refused off Linux ("requires Linux SO_PEERCRED", main.rs:2775-2778) and must be a distinct task, subject and key, with an owner-private operator socket (main.rs:2826-2850), a non-root host UID different from the controller's (main.rs:2867-2876) and safe socket ancestors (main.rs:2881-2900); command names are unique alphanumeric, the program is absolute and neither `mini` nor `host` (main.rs:2910-2930), `systemdScope` requires basename `bwrap` (main.rs:2931-2935), `wallTimeSeconds` is 1..1800 and scoped only (main.rs:2936-2941); tool-task family tariffs must fit the tool reserve (main.rs:3106-3129); the event21/event26/current-birth features each require their exact Host SHA-256 and a host socket (main.rs:3019-3056, 3130-3140); `providerTask` requires `hostSocket` (main.rs:3143-3145), distinct identity and keys, a broker path outside `stateDir` (main.rs:3169-3179), tokens 1..131072 and 1..8192 (main.rs:3189-3196), a loopback `gatewayBind` (127.0.0.1 unless fixture, main.rs:3201-3212), bounds (main.rs:3213-3224), and a `hermes-acp` command whose argv matches the launcher shape (main.rs:3225-3236).

#### 1.3.2 The journal (main.rs:469-2267)

All controller state lives in one JSON document `stateDir/journal.json`, `format: "minidregg-grain-runtime-v1"` (main.rs:2221), whose `binding` is `{"config": <full Config>, "configPath": ...}` and must equal the current config exactly at open (main.rs:6853-6864). Fields (main.rs:471-567):

| group | fields |
|---|---|
| identity | `format`, `binding`, `next_operation_id` |
| attachment | `connection` (`detached|hard|soft|fenced`, main.rs:571-576), `hard_reconnect_pending`, `prompt_witness` |
| per-authority custody (4 slots: Parent, Tool, Dispatch, Provider; main.rs:1872-1877, 2187-2218) | `pending`, `tool_pending`, `dispatch_pending`, `provider_pending` (each `Pending{operation_id, operation, attempt, uncertain, publication}`, main.rs:580-589); `parent_hold`, `tool_hold`, `dispatch_hold`, `provider_hold` (`HeldCharge`, main.rs:1160-1179) |
| worker | `child` (`ChildRecord{operation_id,pid,program,pgid,unit,launch_gate_protocol}`, main.rs:1142-1156), `settlement_due` |
| provider | `provider_attempt`, `provider_settlement`, `provider_replays` (<=16), `provider_prompt_requests` |
| dispatch / app API | `dispatch_attempt`, `application_api_attempt`, `application_api_history` (<=16) |
| resident | `resident_prompt_origin`, `resident_delivery`, `resident_completion` |
| foreground | `foreground_attempt`, `foreground_history` (<=256) |
| receipts | `publication_receipts` (<=32 with eviction of reported ones, main.rs:8232-8244), `born_resources` (<=8,192 members, main.rs:2159-2161), `birth_next_ordinal`, `birth_operation`, `birth_pending` |
| workspace / room | `workspace_proposals` (<=64), `workspace_attempt`, `workspace_birth`, `workspace_resolutions` (<=256), `room_attempt`, `room_resolutions` (unbounded `Vec<Value>`) |
| law | `managed_law_generation` |
| audit | `reconciliation_log` (unbounded `Vec<Value>`), `unresolved_external` (strings) |
| Hermes | `hermes_session` (`HermesSession{id, workspace, load_verified, state_fingerprint, retention_issue, pending_prompt}`, main.rs:1881-1895), `prior_hermes_sessions` (<=32, main.rs:13502-13505) |

Every save goes through `config_migration::ensure_process_current` and `session_failure::ensure_publication_known` and then `journal_io::write` (main.rs:6916-6920), which writes a fresh `O_EXCL` stage file, fsyncs it, checks inode identity and renames it over `journal.json`, then fsyncs the directory; abandoned stage files "are retained evidence, never promoted or deleted" (journal_io.rs:1-2, 21-47). `next_id` saves the whole journal for every allocated operation ID (main.rs:7563-7568).

Attempt directories retained under `stateDir` (each named from a 16-digit operation ID): `attempt-N/` (the `mini submit` dir: `call.bin`, `outcome.bin`, `outcome.json`, `retry-NNNN.{bin,json}`), `source-N.json` (the intent), `policy-source-N.json`, `policy-attempt-N/`, `policy-check-N/`, `provider-N.controller-request|controller-outcome|controller-response-headers`, `provider-meter-N/` and `.metadata.json`, `provider-continuity-N/`, `dispatch-N.canonical-request`, `dispatch-reserve-source-N.json`, `dispatch-lifetime-source-N.json`, `agent-reserve-N/`, `agent-lifetime-reserve-N/`, `agent-lifetime-paid-N`, `agent-payer-*`, approvals, `application-api-N.json` and `-reply-N.json`, `foreground-N.{request,result}.json`, `foreground-request-ID.json` tombstones, `workspace-proposal-N.json`, `workspace-birth-N.predicate.json`, `workspace-import-N.json`, `current-author-N/`, `shared-app-refs/`, `mcp-N.sock`, `provider-gateway.sock`, `controller.lock`, `control.sock` (configured), `admin.sock`, resident files, migration archives. Nothing in main.rs ever deletes an attempt directory; growth is unbounded by design.

#### 1.3.3 State machines

*Attachment* (`Connection`): `detached -> attach -> soft|hard` (main.rs:13557-13575, the journal first goes to `fenced` and only after the signed attach to soft/hard, main.rs:13563-13571); `soft -> hard` by a hard reconnect and a later `mode` transition (main.rs:13457-13478, 13516-13522); `hard -> fenced` on hard EOF or any failure (`disconnect`, main.rs:13686), then `-> detached` once every fence and lookup resolves (main.rs:13762-13779). Startup forces `fenced` if a child, foreground attempt, hard connection or hard reconnect was outstanding (main.rs:6906-6913).

*Worker completion race* (`completion_phase`: IDLE 0, RUNNING 1, SETTLING 2, CANCELLED 3, main.rs:3292-3295): the worker loop claims RUNNING->SETTLING and journals `settlement_due` (main.rs:3407-3418); the hard-interrupt closure CASes RUNNING->CANCELLED (main.rs:17487-17492); whichever wins decides between settle and fence.

*Native grain status* is read from signed views as decimal strings and branched on in 62 places (`grep -c 'grain/status'`): "0" idle/paused, "1" attached, "2" soft-idle, "3" reserved (hard), "4" reserved (soft), "5"/"7" fenced with a held reservation, "6" terminal (my reading of the branches at main.rs:2617-2660, 7791-7792, 13719-13760, 15790-15796, 16297-16299; the Lean enum is not imported, these are magic strings).

*Per-authority native call*: `mark_hold_as` (pre-reserve generation and root, main.rs:7976-8009) -> `transition_as_with_witness` journals `Pending` and the hold's `reserve_attempt` *before* the subprocess (main.rs:8281-8296) -> success records reserve confirmation / publication receipt / settlement and clears pending, a settle clears the hold (main.rs:8341-8403) -> failure is "refused" only on an explicit decoded refusal or a Lean-inspected pre-submit refusal, otherwise `uncertain` (main.rs:8404-8466).

*Foreground tool* (`ForegroundPhase`, main.rs:902-909): Prepared -> Reserved -> Executing -> Definite | Uncertain | Audited (main.rs:13029-13127, 13288-13361).

*Application API* (`ApplicationApiPhase`, main.rs:1496-1503): Prepared -> BindingVerified -> DispatchStarted -> Definite | Uncertain | NoDispatch (main.rs:8594-8644, 9002-9094).

*Workspace submission resolution*: `performed|refused|uncertain` with a `basis` string (main.rs:1908-1923, 11414-11537).

*Resource birth*: `birth_operation{no_native_submit:true}` saved before attach/reserve (main.rs:10722-10733) -> `no_native_submit=false` + `birth_pending` + `tool_pending` saved together before `mini submit` (main.rs:10910-10921) -> confirmed record pushed to `born_resources` (main.rs:10946-10969) or zero-charge release and tail-ordinal return (main.rs:10489-10573, 1016-1050).

*Provider attempt*: request retained -> attach -> hold -> joint reserve with parent witness (main.rs:9475-9545) -> `send_started=true` after continuity (main.rs:9723-9790) -> outcome `received:|not-sent:|uncertain:` (main.rs:9913-9957) -> Lean quote (main.rs:10006-10172) -> delivery (main.rs:10300-10411) -> settle at the quote, then disconnect (main.rs:10413-10488).

#### 1.3.4 The core native transition (`transition_as_with_witness`, main.rs:8112-8467)

The slot is chosen by matching `authority.task` against the four configured tasks (main.rs:8129-8154). An outstanding pending call on that slot refuses (main.rs:8155-8157). It queries the signed grain (main.rs:8158), and for a reserve requires the observed root and generation to equal the hold's pre-reserve origin (main.rs:8160-8174). It allocates an ID, builds an optional provider continuity descriptor for guarded provider settles and held disconnects (main.rs:8175-8182), builds the parent witness from `prompt_witness` for joint publications or provider reserves (main.rs:8183-8209), builds observation grants (main.rs:8210-8221), and authors the intent with `grain_source::source` (main.rs:8222-8225; grain_source.rs:67-80 writes `task`, `subject`, `capability`, `schemaVersion:"1"`, `expectedTargetRoot`, `context{operationId,payload}`, `before{generation,status,remaining,reserved}`, `operation`, `publications`, `observeCapability`). The operation ID is a SHA-256-derived decimal of `DREGG/GRAIN-CONTROLLER/OPERATION/v1\0` + controller task, task, subject and local counter (grain_source.rs:6-32). It writes `source-N.json` with `write_new` (main.rs:8262-8267), journals `Pending` (main.rs:8281-8296), and runs `mini submit --host --config --intent --intent-kind grain-intent --key KEYPATH --dir attempt-N [--socket] [--provider-continuity DESC]` (main.rs:8297-8318). "Work" submits (reserve, attach, settle-with-publication) go through the custody gate so a hard EOF can stop the child; a `BeforeSpawn` cancel proves no child existed, clears the pending record and zeroes the hold's charge (main.rs:8319-8337).

#### 1.3.5 Startup and restart recovery (main.rs:6812-6915, 15736-16090, 16785-16875)

`open_mode` creates `stateDir` 0700 and requires it owned and not a symlink (main.rs:6821-6830), takes an exclusive non-blocking `flock` on `controller.lock` (main.rs:6831-6842), binds the systemd manager context (main.rs:6844), checks session-failure publication state (main.rs:6845), runs config-migration startup recovery and re-reads the config if a migration was published (main.rs:6846-6851), validates (main.rs:6852), loads or creates the journal with an exact binding (main.rs:6853-6877), activates migration (main.rs:6878), and fences if a child or hard state was outstanding (main.rs:6904-6913). `serve` then runs `startup_recovery` (main.rs:16811-16835): it records `prior_run_stopped` from the unit/cgroup proof (main.rs:16812-16813), and if anything is outstanding runs `recover` then `automatic_reconcile`, logging the result to `reconciliation_log` and stderr; a failure leaves the task fenced but the process keeps serving.

`recover` (main.rs:15736-16090) in order: (1) a stranded child is fenced only if it has a unit and the launch-gate protocol, by gate fence + unit kill + cgroup proof, never by signalling the saved PID, and leaves the note "worker operation N stopped after controller restart; external effects need acknowledgement" (main.rs:15737-15770); (2) v2 and v3 dispatch reserve recovery via the `submit-marker.json` rule (main.rs:15771-15772, 15262-15734); (3) dispatch pending lookup and a cascade of dispatch cleanup proofs (main.rs:15773-15956); (4) provider pending lookup and the send-boundary note (main.rs:15957-15966); (5) birth-marker consistency (main.rs:15967-15987); (6) tool lookup, room recovery, workspace operation and workspace birth recovery with lookup, no-birth cleanup, parent lookup (main.rs:15988-16007); (7) a due local settlement is settled if the grain is still reserved (main.rs:16012-16032); (8) a parent hold with no child fences with a note (main.rs:16033-16054); (9) provider refusal retirement and delivered-response recovery (main.rs:16055-16056); (10) if fenced, fence tool/dispatch/provider, `interrupt` the parent if it is attached or reserved, and detach unless a dispatch reservation is held for audit (main.rs:16057-16088).

`automatic_reconcile` (main.rs:16840-16875) then settles a parent hold with the `OwnManagedLaw` proof (main.rs:16841-16847) and, if every unresolved note matches `derivable_effect_note` (main.rs:670-676) and every configured command is scoped with `--network none` somewhere in its args (main.rs:16855-16864) and no agent effect is retained, clears the external-effect notes with a "derived" acknowledgement (main.rs:16872-16874).

#### 1.3.6 The Hermes driver (main.rs:14314-15261)

`hermes PROMPT` -> `hermes_session(Invocation::Prompt)` (main.rs:14318-14346). For resident prompts it validates the source-issued origin, requires a retained preparation, refuses an already-entered or preadmission-refused ID, re-runs preflight and fsyncs the entry marker (main.rs:14323-14337, implemented in resident_preflight.rs:116-184). `hermes_session_inner` refuses while a resident delivery is pending (main.rs:14349-14351), refuses an already-admitted resident ID (main.rs:14352-14358), bounds the prompt to 1..16,384 bytes (main.rs:14359-14361), requires attachment and no unresolved custody (main.rs:14362-14382), requires the `hermes-acp` command's basename to be `sandbox-exec` or `bwrap` and one argument ending in `hermes-acp` (main.rs:14383-14400), derives the worker workspace (main.rs:14401-14418), checks session continuity against the SQLite fingerprint (main.rs:14420-14475), starts the provider gateway and writes the worker's Hermes profile with a fresh token (main.rs:14476-14529), validates the private MCP timeout for scoped workers (main.rs:14530-14539), proves the controller unit and launcher (main.rs:14545-14549), reserves the parent (main.rs:14550), journals the resident origin (main.rs:14575-14584), clears the per-prompt replay scope (main.rs:14585-14591), arms the launch gate (main.rs:14592-14597), starts the MCP broker socket `mcp-N.sock` (main.rs:14598-14604), spawns the wrapper with piped stdin/stdout and *inherited stderr* (main.rs:14615-14635) after a durable `pid:0` child marker (main.rs:14636-14644), reads newline-delimited ACP frames up to 1 MiB in a thread (main.rs:14701-14720, 17385-17418), sends `initialize`, `session/new` or `session/load` with the `mini-grain` MCP server pointing at `/agent/grain-runtime mcp-stdio /run/mini-grain.sock` (main.rs:14734-14798, 14605-14614), prepends the verified receipt report to the prompt (main.rs:14809-14817), activates the provider lease and the broker, sends `session/prompt` with `_meta.miniResidentOrigin` (main.rs:14822-14852), and runs `acp_response` (main.rs:14854-14864). Afterwards it drains the provider (45 s, main.rs:9273-9306), revokes the gateway, handles a refused-provider stop (main.rs:14876-14894), validates completion (main.rs:14895-14909), fences on error with the note "Hermes prompt {id}: {error}" (main.rs:14942-14955), otherwise reaps the worker and settles the parent at the *configured* charge (main.rs:14956-14976), stages resident completion and final reply on `end_turn` (main.rs:14977-14984), refreshes the fingerprint and marks reported receipts (main.rs:14985-15013).

`acp_response` (main.rs:15024-15261) is the inner pump: it polls the application-API call, handles up to 2 provider commands and 4 broker tool requests per iteration (main.rs:15058-15095), handles connector input (main.rs:15096-15167), refuses every `session/request_permission` with `cancelled` (main.rs:15241-15246), forwards `session/update` text to the display channel with `try_send` (dropped under backpressure, main.rs:15247-15253), answers other peer requests with "unsupported client method" (main.rs:15254-15259), and returns the matching response or a typed failure (main.rs:15213-15239).

#### 1.3.7 Provider path (main.rs:9173-10488)

`handle_provider` (main.rs:9185-9272) dispatches five gateway commands. `provider_reserve` (main.rs:9353-9552) checks the lease, model and size, loads the Host profile via `mini profile` and selects this task's tariff (main.rs:9369-9370), refuses if any prior provider custody remains (main.rs:9371-9376), serves an exact replay first (main.rs:9377-9379), enforces the per-prompt request budget and replay bound (main.rs:9380-9384), re-reads the parent (main.rs:9388-9396), resolves the route and broker ticket at the parent's signed height (main.rs:9397-9411), checks a homelab placement against the scheduler plan (main.rs:9412-9440), pins the route's tariff slice and hold and checks the maximum charge fits (main.rs:9443-9458), refreshes the parent witness (main.rs:9460-9474), retains the request and increments the prompt counter *before* the attempt (main.rs:9475-9512), attaches the purse if idle (main.rs:9513-9533), and submits the joint reserve `{type:reserve, amount, route}` with the parent witness (main.rs:9535-9544). `provider_before_send` (main.rs:9723-9790) re-reads parent and purse, runs `mini continuity` and requires the returned anchor to equal the retained reserve receipt (main.rs:9791-9899), re-reads the parent, and durably sets `send_started` (main.rs:9788-9789). `provider_record_outcome`, `provider_meter_quote_inner`, `validated_metered_charge_for_reserve`, `provider_delivery` and `provider_settle` complete the cycle (main.rs:9900-10488).

#### 1.3.8 MCP tools (`tool_call`, main.rs:12221-12514)

Guard: a room-restricted resident may call only room tools and `mini_room_attempts` (main.rs:12222-12227); the task must be running a worker or foreground operation with no parent, provider or dispatch custody outstanding (main.rs:12228-12241); `mini_workspace_recover`, `mini_room_attempts`, `mini_workspace_attempts` are allowed with retained effects (main.rs:12242-12250); anything else requires no retained tool effect (main.rs:12251-12261). Table: room tools -> `room_call` (room_task.rs); `mini_workspace_{list,describe,read}` -> `mini workspace` read-only (main.rs:11022-11082); `mini_workspace_propose|submit|create|import_reference|export_reference`; `mini_grain_status` (parent and tool signed views, main.rs:12275-12282); `mini_read_resource` (allowlisted or verified-born read, main.rs:12283-12303); `mini_create_resource` (refused if the workspace can create, main.rs:12304-12311); `mini_create_application`, `mini_create_application_session`; `mini_publish` (1..8 publications, 32 KiB, attach/reserve/settle-with-publications/disconnect, zero-charge release on a definite refusal, main.rs:12318-12512). `mini_application_api` and `__mini_gitweb_http_raw` are intercepted earlier in `acp_response` (main.rs:15066-15091).

#### 1.3.9 SPK application-API dispatch (main.rs:3534-6797, 8494-9172, 15262-15734, 16095-16239)

A Hermes tool call `mini_application_api` or the git worker's raw call (main.rs:15070-15083) begins a forward HTTP call to an SPK resident host over a peer-credential-checked Unix socket (`application_api_tools::start_exchange_once(route.socket_path, route.host_uid, ...)`, main.rs:8621-8633). The SPK host calls back on the dispatch socket with `dispatch_custody::Command` RPCs (main.rs:6637-6779) to reserve a separate purse, have the controller sign as payer, mark the one-shot send boundary, and settle. Three generations coexist: v1 (`Reserve`, `MarkSend`, `SettleDefinite`, `AbortNoSend`, `Inspect`): a plain grain reserve with payload `DREGG/APPLICATION/AGENT-DISPATCH-RESERVE/v1/{digest}` (main.rs:5742-5949); v2 (`ReserveV2`, `InspectV2`, `SignPayerV2`): `mini agent-reserve-plan|seal|submit|lookup` and `mini agent-payer-sign` against private Host ops 58/59 and 48 (main.rs:4652-5123, 5474-5740); v3 "lifetime" (`ReserveV3`, `InspectV3`, `InspectSettlementV3`, `SignPayerV3`, `MarkSendV3`): `mini agent-lifetime-reserve-*`, `agent-lifetime-paid-plan`, `agent-lifetime-paid-payer-sign`, and two `minidregg-host inspect` calls (main.rs:4083-4646, 5125-5468, 6073-6398, 6504-6578).

#### 1.3.10 Foreground tools (main.rs:12517-13449)

A model-free caller on the control socket sends `tool-v1 SIZE` + a JSON frame `{requestId, name, arguments}` (agent-two-participant-foreground-journey.sh:90-92). `foreground_tool` bounds the frame to 256 KiB, requires a 32-hex lowercase request ID (main.rs:12909-12916), refuses reuse of a request ID with different bytes or the same bytes ("durably claimed ... inspect it without resubmitting", main.rs:12917-12936), allowlists 17 tool names (main.rs:12946-12967), runs the argument preflight (main.rs:12973), requires an attached idle reconciled task (main.rs:12974-13001), writes a tombstone and request copy before reserve (main.rs:13019-13040), reserves the parent foreground profile, runs the tool, retains the result (bounded to ~1 MB with an explicit error substitute, main.rs:877-890) and settles the parent at the configured charge (main.rs:13041-13156).

#### 1.3.11 Subcommands (`main`, main.rs:17920-18238)

Twenty-five argv shapes: `--controller-manager-protocol`, `controller-launch`, `controller-write-scopes`, `config-migrate`, `resident-completion`, `resident-delivery`, `resident-outcome`, `session-failure`, `quiescence-transport`, `quiescence`, `resident-reconcile`, `provider-provision`, `provider-table check`, `hermes-room resident`, `hermes-room ...`, `concierge ...`, `tool-id`, `tool-result`, `tool-ack`, `tool`, `mcp-stdio`, `connect SOCKET`, `terminal`, `connect SOCKET MODE`, `admin`, `serve`. The usage string (main.rs:18222) lists 10 of them. Each delegates to one sibling module (table in section 5.1).

### 1.4 Wire formats spoken

| channel | format | where |
|---|---|---|
| control socket (`controlSocket`, mode via owner-only `stateDir`) | newline lines `attach hard|soft`, `attach terminal-v1 hard|soft`, `run NAME`, `hermes PROMPT`, `status`, `recover`, `conversation new`, `disconnect`, `terminal status|hermes|hermes-resident ...`, `tool result ID`, `tool ack ID`, and `tool-v1 SIZE` + raw frame | control.rs (shard C); dispatch in main.rs:17539-17592, 17603-17893 |
| admin socket (`stateDir/admin.sock`) | one command line -> one reply line (`ok`, `error: ...`, or JSON) | main.rs:17653-17813 |
| dispatch socket (`dispatchTask.socketPath`, peer UID `hostUid`) | JSON `dispatch_custody::Command` -> JSON reply (`refused` + `detail` on error) | main.rs:6780-6797 |
| ACP to Hermes (worker stdin/stdout) | newline-delimited JSON-RPC 2.0, frames <= 1 MiB | main.rs:17385-17425, 14735-14852 |
| MCP broker (`stateDir/mcp-N.sock`, bound into the sandbox at `/run/mini-grain.sock`) | `mcp::BrokerRequest{name, arguments, prompt_epoch, reply}`; replies `{isError, text}` | main.rs:8468-8493 |
| provider gateway (`stateDir/provider-gateway.sock` + loopback `gatewayBind`) | `provider::ProviderCommand` channel | main.rs:9185-9272 |
| SPK forward API | `mini-spk-agent-api-v3` JSON (`dispatch-v3`, `http-v3`, `refused-v3`, `uncertain-v3`, `inspect-v3`/`inspection-v3`) and v2 equivalents | main.rs:1418-1480, 8719-8925, 9102-9172 |
| `mini` subprocess | argv + files in attempt directories (`intent.json`, `call.bin`, `outcome.bin`, `outcome.json`, `retry-NNNN.json`, `receipt.json`, `plan-inspected.json`, `request-inspected.json`, `continuity.json`, `meter.json`, `reply.frame`) | throughout |
| launcher | argv `--workspace W --runtime-root R --network none|host -- /agent/PROGRAM ...`, env listed below, `--launch-gate-protocol` -> `mini-grain-launch-gate-v1\n` | main.rs:3436-3496, 392-410 |
| journal | pretty JSON, camelCase, `deny_unknown_fields` | main.rs:469-567, 2554-2557 |

Approval JSON documents written for `mini` signing helpers: `minidregg-agent-lifetime-reserve-approval-v1` (main.rs:4432-4441), `minidregg-agent-reserve-approval-v1` (main.rs:4883-4892), `minidregg-agent-lifetime-payer-approval-v1` (main.rs:5398-5409), `minidregg-agent-payer-approval-v1` (main.rs:5625-5639). Each contains `keyPath` for the purse key, never key bytes.

### 1.5 Processes, sockets, files and environment touched

Processes spawned by main.rs (31 `Command::new` sites): `mini` (all native I/O), `minidregg-host` (inspect, from main.rs:2480, 5551, 6227, 6278), the configured command programs (main.rs:14016, 14615), the launcher's sibling `launch-gate` (main.rs:17268), `systemctl` via `systemd_manager::{controller_command, worker_command}` (main.rs:17214, 17244, 17285, 17304), `/bin/ps -axo pgid=,stat=` (main.rs:17349).

Environment variables *set* for the launcher (main.rs:3446-3496): `MINI_GRAIN_UNIT`, `MINI_GRAIN_CONTROLLER_UNIT`, `MINI_GRAIN_STATE_DIR`, `MINI_GRAIN_CUSTODY_KEY`, `MINI_GRAIN_TASK_CONFIG`, `MINI_GRAIN_HOST_CONFIG`, `MINI_GRAIN_RUNTIME_MAX_SEC`, `MINI_GRAIN_TOOL_CUSTODY_KEY`, `MINI_GRAIN_PROVIDER_CUSTODY_KEY`, `MINI_GRAIN_CREDENTIAL_BROKER`, `MINI_GRAIN_PROVIDER_SOCKET`, `MINI_GRAIN_PROVIDER_PORT`, `MINI_GRAIN_BROKER_SOCKET`, plus `systemd_manager::lifetime_environment` (main.rs:3454); `HERMES_HOME` for unscoped workers (main.rs:14622-14624). Environment *read* (via systemd_manager): `MINI_GRAIN_CONTROLLER_REGISTRATION`, `MINI_GRAIN_CONTROLLER_MANAGER`, `MINI_GRAIN_WORKER_MANAGER`, `MINI_GRAIN_CONTROLLER_UNIT` (systemd_manager.rs:186-199; SYSTEMD-MANAGERS.md:42-52).

Linux files read: `/proc/self/cgroup` and `/sys/fs/cgroup/...` (main.rs:683-692, 17340-17341), `/dev/urandom` (main.rs:18036; journal_io.rs:33).

### 1.6 Drivers in the crate root

| driver | what it does | controller surface exercised | recorded evidence |
|---|---|---|---|
| acceptance.sh (872) | fresh genesis and birth of 3-4 grains via `mini bootstrap`/`submit` (acceptance.sh:175-340), policy author/compare (342-382), witness and publication delegations (384-482), `BOOTSTRAP_ONLY` exit for other drivers (484-521), then a controller run: soft run, hard run + disconnect, stale-witness refusal, `admin reconcile parent audited`, `reconcile effects`, recover, ACP fixture prompt with `mini_publish`/`mini_read_resource` through `mcp-stdio`, worker-law renewal check (523-872) | serve, connect, attach soft/hard, run, disconnect, admin, recover, hermes (fixture), mcp-stdio, renew_worker_policy | docs/evidence/2026-09-26-grain-* directories exist by name; not opened in this review |
| hermes-journey.sh (398) | humans' Store via newparticipant-acceptance; hosted grain; scripted ACP agent in real bwrap; SIGKILL controller mid-write; automatic startup recovery; delegation and reference export; hard breaker; soft detach (hermes-journey.sh:1-17) | serve under `systemd-run --user` with the three env vars (211-216), workspace tools, startup_recovery, automatic_reconcile, disconnect | docs/evidence/2026-09-30-hermes-participant (runs j3, j4); journey row `hermes` (scripts/pipeline/journey-rows:444-458) |
| policy-crash-acceptance.sh (280) | kills the controller after the g+1 policy install confirms but before attach; restart; `recover` must look up, not resubmit (policy-crash-acceptance.sh:90-105, 192, 244-258) | renew_worker_policy, retry_pending lookup | none found by name |
| receipt-recovery-acceptance.sh (269) | drops the MCP reply of a `mini_publish` (fixture/broker-drop.rs), interrupts, audited reconcile, next prompt must carry the receipt and use `--mode lookup` (receipt-recovery-acceptance.sh:176-260) | verified_publication_report, session/load | docs/evidence/2026-09-26-grain-publication-receipt-linux (by name, unverified) |
| provider-direct.sh (151) | no controller: shell-driven provider joint reserve, overbudget refusal and stale witness refusal (provider-direct.sh:84-151) | none (tests Lean gates) | docs/evidence/2026-09-26-grain-provider-direct |
| agent-two-participant-preflight.sh (262) | read-only: pins and op55 replay lookups for two agent configs (agent-two-participant-preflight.sh:178-200) | none | 09-27 agent evidence |
| agent-two-participant-foreground-journey.sh (233) | foreground `mini_grain_status` lost-reply by ID, duplicate refusal, changed-bytes refusal, ack; `mini_application_api` GET to gitweb; hard-EOF observation (exit 3 by design) | foreground_tool, tool-result/ack, application API v2 | 09-27 evidence |
| prepare-agent-controller-configs.sh (59) | adds `foregroundTool` to two configs | none | - |
| bootstrap-native-controller.py (128) | extracts and `exec`s the Python embedded in `native/resource-client/journey.d/jpay6.sh` to bootstrap a Store and writes a controller config (bootstrap-native-controller.py:49-82) | none (config only) | - |
| journeys/byok-native.py (337) | real member key choice, broker, provisioning, scripted provider; reserve/send/settle at the user fee; key replacement; revoke; clone refusal; optional real sshd forced proxy and native key rotation | provider-provision, serve with `localFixtureHostNetwork` and `--network host` (byok-native.py:164-167), provider gateway | BYOK.md:66 says the matched "c29 fixture is compatibility evidence" |

Two drivers (`bootstrap-native-controller.py:49-61`, `journeys/byok-native.py:53-73`) obtain their bootstrap by string-splitting another script's heredoc and `exec`-ing it with text substitutions; a change to `jpay6.sh` silently changes these journeys (they do refuse when the anchors move).

### 1.7 The systemd units that run it (context)

`deploy/grain-host/mini-grain-controller@.service` (20 lines) is a *user* template (`WantedBy=default.target`, :20) with `ExecStart=/opt/mini/bin/grain-runtime serve /opt/mini/grains/%i.json` (:10), `Restart=on-failure` (:11), `UMask=0077`, `NoNewPrivileges`, `TasksMax=64`, `MemoryMax=1G` (:13-17), and only `Environment=MINI_GRAIN_CONTROLLER_UNIT=%n` (:9). deploy/grain-host/README.md:60-64 calls it "historical" and says `install-controller` writes the real unit. `deploy/hermes/mini-hermes.service` (not owned here, read for the mismatch) is a *system* unit `mini-hermes.service`, `User=mini`, `ExecStart=/var/lib/mini/candidate/current/bin/grain-runtime serve /var/lib/mini/hermes/controller.json` (:27-31), sandboxed with `ProtectSystem=strict`, `ReadWritePaths=/var/lib/mini/hermes /var/lib/mini/store/node/public` (:37-41). See section 7 for why neither matches what main.rs requires.

---

## 2. What it assumes of its surroundings

### 2.1 Host protocol operations (all indirect except four reply bytes)

main.rs speaks to the Lean Host only through the `mini` client and the `minidregg-host` executable. The table lists every Host operation main.rs depends on with the evidence in main.rs, the registry entry from `protocol/host-operations.json`, and the Lean side.

| op | registry symbol / receiver | how main.rs depends on it | Lean cross-check | agree? |
|---|---|---|---|---|
| 1 | AUTHORIZED_PREPARE, dispatchSession | the custody client's pre-submit refusal marker must say `"operation":1`, `"stage":"prepare"` (main.rs:2405-2411); the op-255 reply bytes are decoded by `minidregg-host CONFIG inspect outcome` and must give `type:"refused"`, `phase:"70726570617265"` (hex of "prepare") (main.rs:2468-2497) | Host/Json.lean:4808-4813 emits `("phase", hexJson phase)`; the inspect arm is Host/Main.lean:9160 | yes for the phase encoding; the marker file itself is written by resource-client (not Lean) |
| 2 / 3 | SUBMIT / LOOKUP, fnDispatch | every `mini submit` and `mini retry --mode lookup` (main.rs:8298-8318, 17054-17064); v2/v3 comments "only the marked public op2 phase can mutate Mini ... never triggers a second submit" (main.rs:4648-4651), "Exact public op3 is the only permissible recovery probe" (main.rs:3828) | Host/Main.lean:2024 `| 2 | 3 => fnDispatch` | yes at the level visible here; confirmation strings `installed|replayed` (main.rs:3645-3648, 6993-6998) are client-produced |
| 17 | PROVIDER_CONTINUITY, fnDispatch | `mini continuity ... --call --outcome --dir` -> `continuity.json` must be `minidregg-provider-continuity-v1`, `status:"confirmed"`, `continuous:true`, matching `providerResourceId`, anchor `verified-mini-native-prefix-v1` equal to the retained reserve receipt (main.rs:9834-9898) | Host/Main.lean:6718-6724 `runProviderContinuitySession`; the JSON shape is produced by resource-client (native/resource-client/src/main.rs:3027, 3049; provider_continuity.rs:112) | the Rust consumer and the resource-client producer agree on field names; whether Lean's continuity verdict maps 1:1 to `continuous:true` needs the Lean reader (Q8.3) |
| 19 | PROVIDER_USAGE_QUOTE, fnDispatch | `mini meter` retains `reply.frame`; main.rs requires `frame[0] == 19` and `frame[1..] == meter.json bytes` (main.rs:10260-10263), and re-validates every report field (main.rs:1748-1841) | Host/Main.lean:6744-6754 returns `((19 : UInt8), report.compress.toUTF8.toList)` or `(255, failure ...)`; Host/ProviderUsage.lean:295-313 writes `status` `quoted-per-operation|quoted-reported-usage`, `requestBytes`, `reserve`, `charge`, `operation{type,charge,route}`, and the two exact `claim` strings main.rs:1736-1747 expects; metadata keys `version, providerResourceId, route, status, contentType, reserve` (ProviderUsage.lean:340) equal main.rs:1696-1698 | yes |
| 30 / 31 | APPLICATION_CURRENT_BIRTH / APPLICATION_SESSION_CURRENT_BIRTH, fnDispatch | `mini current-application-intent|current-session-intent` retains `reply.frame`; main.rs requires `frame[0]` = 30 or 31 and `frame[1..] == intent.bin` (main.rs:7162-7183) | Host/Main.lean:7317-7324 returns `((30 : UInt8), intent)` / `((31 : UInt8), intent)` | yes |
| 48 | AGENT_PAID_DISPATCH_PLAN, fnDispatch (operator route) | v2 payer signing: "The resident supplies an op48 paid plan" (main.rs:5470-5473); the plan is inspected by `minidregg-host CONFIG inspect application-agent-paid-dispatch-plan` (main.rs:5551-5561) | receiver not read (Q8.6) | not settled |
| 55 | GRAIN_SHARE_ISSUE_LOOKUP, operator | preflight script only (`mini grain-share-issue-receipt-lookup`, agent-two-participant-preflight.sh:185-197) | not read | not settled |
| 58 / 59 | AGENT_RESERVE_PLAN / ASSEMBLE, operator | `mini agent-reserve-plan|seal` (main.rs:4745-4763, 4939-4949), "private op58/59 phases expose and seal a plan" (main.rs:4649) | not read | not settled |
| 76-80 | AGENT_LIFETIME_* (76 serveFrame, 77 dispatchSession, 78-80 fnDispatch) | v3: "exact op80 plan" (main.rs:4175-4178), "source-owned op78" (main.rs:5353), "op79 assembly and fresh op76 delivery remain the resident's separate custody phase" (main.rs:5243-5245) | not read | not settled |
| 255 (marker) | "Host refusal/outcome envelope" | pre-submit refusal frame `frame[0] == 255` (main.rs:2461-2467) | registry `response_markers` | yes |

No other op byte appears in main.rs. main.rs does not use the generated `native/host-operations.rs`.

Other Host-executable surfaces used directly: `minidregg-host CONFIG inspect outcome BODY OUT` (main.rs:2480-2489), `inspect application-agent-paid-dispatch-plan` (main.rs:5551-5561), `inspect-agent-lifetime-paid-ingress` (main.rs:6227-6238; note the hyphenated single verb versus the two-word `inspect ...` form of its neighbours), `inspect application-agent-lifetime-dispatch-committed` (main.rs:6278-6289). `mini profile --host --config` returns the Host profile JSON whose `providerMeterings` list carries the tariffs (main.rs:357-382, 9629-9644).

### 2.2 The `mini` client verbs main.rs depends on

`submit` (intent kinds `grain-intent`, `grain-policy-install-intent`, `grain-birth-intent`, `binary`), `retry --mode lookup`, `query` (through query_observation.rs), `author --kind predicate|grain-policy` (main.rs:7939-7958), `profile`, `continuity`, `meter`, `workspace --action list|describe|read|propose|submit|recover|create|import|publish-delegation`, `current-application-intent`, `current-session-intent`, `historical-call-receipt-lookup` (main.rs:7671-7696), `kind.recipient_lookup_command()` (main.rs:7704-7729), `agent-reserve-plan|seal|submit|lookup`, `agent-payer-sign`, `agent-lifetime-reserve-plan|seal|submit|lookup`, `agent-lifetime-paid-plan`, `agent-lifetime-paid-payer-sign`. The controller trusts the client's decoded `outcome.json` (`type:"refused"`) as a definitive native refusal (main.rs:8408-8427, 7877-7880); only the pre-submit path re-decodes bytes through the Host.

### 2.3 Operating system

Linux-only features: cgroup v2 unified hierarchy (`/proc/self/cgroup` line `0::`, main.rs:683-692), `systemd` user or system manager through `systemctl` (main.rs:17212-17294), `waitid(P_PID, WEXITED|WNOHANG|WNOWAIT)` (main.rs:17366-17383), `flock` (main.rs:6840), `SO_PEERCRED` for the dispatch socket (main.rs:2775-2778, in dispatch_custody.rs), `setsid` and process-group `kill(-pgid)` (main.rs:14024-14032, 17200-17210), `/bin/ps` (main.rs:17349). The worker sandbox requires `bwrap` with unprivileged user namespaces and a user systemd manager (deploy/grain-host/README.md:160-162). macOS compiles (`#[cfg(not(target_os = "linux"))]`, main.rs:2775) and acceptance.sh has a Darwin branch with `sandbox-exec` (acceptance.sh:525-538).

### 2.4 Network services

None directly. OpenAI-compatible providers are reached by the key broker or by provider.rs on the controller's behalf (the controller holds a ticket, main.rs:9615-9624); homelab backends through `minidregg-inference-scheduler` (main.rs:9337-9350); SPK resident hosts over a local Unix socket with peer-UID check (main.rs:8621-8633). No Solana, Discord, fn/NNTP or gitweb client code in main.rs (gitweb is reached through mcp.rs -> gitweb_worker.rs and the application-API path).

### 2.5 Files and configs the operator must provide

The controller JSON (`Config`, main.rs:86-116); custody key files for parent, tool, provider and dispatch identities (paths only); the Host config `hostConfig` (byte-compared against attempt copies, main.rs:2442-2448, 10287-10290, 11436-11440); the provider table (`credentials::ProviderTable::load`, main.rs:9327, 9566); the broker client config `keys-client.json` (main.rs:9568); for scoped workers the launcher `bwrap` and sibling `launch-gate`, the worker runtime root containing `grain-runtime`, `hermes-acp` and `grain-provider-bridge` (deploy/grain-host/bwrap:85, 121); for non-provider scoped Hermes a private `/workspace/.hermes/config.yaml` with `timeouts.mcp.tool_call` (main.rs:14530-14539; README.md:211-215); optionally a resource workspace directory initialised by `mini workspace --action init` (main.rs:3244-3290); the root registration `/etc/mini/controllers/TASK.json` or the three fixture env vars (systemd_manager.rs:158-237).

### 2.6 Other crates

Path deps (Cargo.toml:24-28): `minidregg-signed-api-path`, `minidregg-inference-scheduler` (used in main.rs:9338-9350, 16521-16524), `minidregg-compatible-upgrade-custody` (used by config_migration), `minidregg-mini-keys` client (main.rs:3474, 9568). Binary deps at runtime: `mini` (resource-client), `minidregg-host` (Lean), `minidregg-link-sqlite-store` and the signature verifier (for the Host, in drivers). Source shared out: `src/credentials.rs` is compiled into resource-client via `#[path = "../../grain-runtime/src/credentials.rs"]` (native/resource-client/src/keys.rs:35), which is why main.rs carries `#[allow(dead_code)] mod credentials;` (main.rs:32-35).

---

## 3. Does it decide anything semantic?

The design test: "Rust decides nothing semantic". main.rs is careful in most of its 18,239 code lines to *retain and compare* rather than decide; every write is a signed intent the Lean Host admits. The places below are where the Rust code, not a Lean admission, is the decision. Each row says whether Lean would refuse if Rust got it wrong.

### 3.1 Violations: Rust IS the decision

| # | site | what Rust decides | Lean side today | what the Lean counterpart should be | blast radius if wrong |
|---|---|---|---|---|---|
| V1 | main.rs:14114-14118 (`run`), 14963-14971 (Hermes prompt), 13121-13125 (foreground), 12433-12439 (`mini_publish`), 11406-11412 + 11451-11455 (workspace submit), 6468-6474 (dispatch definite), 16418-16424 (`reconcile settle`), 16136-16140 (dispatch audit) | the price of every non-provider operation: a constant `charge` string from the controller config (`AllowedCommand.charge` main.rs:464-466, `ToolTask.charge`, `ForegroundToolProfile.charge`, `DispatchTask.charge`), settled verbatim whatever the worker did (a command that exited non-zero is charged the same, main.rs:14110-14118) | AgentGrain `settle` admits any charge up to the signed reservation (my reading of the provider analogue in Compiler/GrainResourceBirthController.lean:195 `charge <= toolBefore.reserved`; Kernel/AgentGrain not opened) | a Lean-side tariff for commands, prompts and tool effects, the way `Kernel/ProviderRoute.lean` already prices provider calls (comment main.rs:266-271) | the grain owner's budget; at most `reserve` per operation; the operator, not the member, picks the number |
| V2 | main.rs:11451-11455 (`native-refusal` -> configured charge), 11509-11516 (`absent-after-submitter-stop` -> configured charge), 11517-11524 (`uncertain` -> configured charge, then the purse is settled and the attempt cleared at 11545) | that a native refusal, a proven-absent call and an unresolved call all cost the full configured tool charge (test main.rs:19986-19998 asserts `toolCharge == "1"` for the absent case) | nothing; Lean sees only an ordinary settle | Lean should price a refused or absent operation (zero, or a Lean-declared refusal fee) | members pay for actions Mini refused |
| V3 | main.rs:11505-11516 | "lookup says absent and every process that could have sent the call is gone, therefore the call never happened" (`resolution: refused`, basis `absent-after-submitter-stop`); the justification is a claim about the Host server, "The pinned `mini serve` handles one connection at a time in accept order" (main.rs:11505-11508) | nothing certifies non-commit; a generic lookup refusal is treated as uncertain elsewhere ("Generic lookup refusal is not evidence that an old call could never commit", main.rs:17060-17062) | a Lean "never-admissible" witness for the exact call (an expired deadline or a consumed nonce), as the guarded provider resolver apparently has ("additional exact-prefix and expired-call witness", main.rs:17061-17062) | if the frame is still in flight in a concurrent server, the controller records "refused", releases the hold, and the agent re-issues the write: one intent becomes two effects (run j3 in docs/evidence/2026-09-30-hermes-participant/README.md: "`refused`, `absent-after-submitter-stop` ... Hermes rewrote it (op 55 `performed`)") |
| V4 | main.rs:16360-16386, invoked automatically at startup by main.rs:16840-16847 | that a parent reservation still held on a shared Store is *the* reservation this controller confirmed, because the installed law equals the controller's managed worker law and no parent attempt is pending (`HoldProof::OwnManagedLaw`), then settles it at `hold.charge` with no operator | a parent settle carries no reference to the reserve receipt | settle-by-anchor: the settle intent should name the reserve's transaction/event so Lean refuses settling a different reservation | wrong charge against the owner's own allowance; scope limited by the owner key being controller custody |
| V5 | main.rs:5950-6070 (`dispatch_mark_send`, v1) and 6402-6503 (`dispatch_settle_definite`) | for a v1 dispatch the controller records the SPK host's claimed `transaction_id`, `event_id`, `permit_sha256` without inspecting them ("this marker does not inspect or mint that permit", main.rs:5950-5952) and later settles the fixed charge on the SPK host's word that a response was definite | v1 reserve is a plain grain reserve with an opaque payload (main.rs:5850-5858); no Lean link between permit and settle | delete v1; v2 and v3 already route plans and committed frames through Lean inspection (main.rs:5551-5561, 6227-6355) | an SPK host process with `hostUid` can make the controller charge its dispatch purse per call |
| V6 | main.rs:10706-10719 | birth quotas: `max_births` per family and an 8,192-member registry; ordinals map to target and capability IDs by arithmetic in Rust (resource_tools.rs:340-350) | Lean authors the descriptor from the Rust-supplied source and the Host-config tariff (Host/Json.lean:2540-2569) | quotas and namespace allocation belong in the factory/birth law | exceeding the quota or reusing an ID is refused by Lean only if the namespace law checks it (Q8.5) |
| V7 | main.rs:9307-9312, 9483-9485 | per-prompt provider request budget (`maxIterations`, counted before the attempt, never restored) | none | arguably a physical resource bound; acceptable in Rust if labelled so | a member's prompt is cut short; no money moves |
| V8 | main.rs:14977-14983 | that an ACP `stopReason == "end_turn"` makes a resident reply deliverable | delivery itself pays a Book turn natively (RESIDENT-DELIVERY.md:23-26) | agent-protocol semantics; acceptable in Rust | a truncated turn is delivered as final |

### 3.2 Mirrors: Rust pre-checks, Lean is still the gate

| site | what Rust checks | the Lean gate |
|---|---|---|
| main.rs:1701-1727, 9445-9458 | maximum metered charge at the token ceilings fits the hold before reserve | the provider purse law and the quote (`ProviderUsage.lean:281` "reported usage quote exceeds the held allowance or tariff bound") |
| main.rs:1628-1634 | user-route hold equals the per-op fee | "the purse law refuses any other user hold" (main.rs:268-270) |
| main.rs:1729-1842 | the quote report matches the pinned task, route, tariff, hold, byte lengths, claim strings, token ceilings | the report is Lean-authored (Host/Main.lean:6744-6754); Rust refuses to sign a mismatching settle |
| main.rs:2627-2637 | the purse's recorded route equals the attempt's route | the purse records the route at reserve and Lean charges by it at settle (main.rs comment 1600-1602, 2625-2626; Lean purse law not read, Q8.2) |
| main.rs:9585-9587 | pool route: `max_tokens` present and <= `maxOutputTokens` | the broker's per-call cap and the purse reserve |
| main.rs:3106-3129 | family tariffs fit the tool reserve | Lean birth uses the Host-config tariff (Kernel/NativeHostGrainBirth.lean:48; Compiler/GrainResourceBirthController.lean:39-41) |
| main.rs:7893-7938 | the installed law is byte-equal to a Host-authored managed law for an accepted generation | the policy-install intent is admitted by Lean |
| main.rs:12221-12514, 12520-12898 | which tools exist and their argument syntax | every effect is a signed intent admitted against capabilities |
| main.rs:7146-7184 | a retained birth source re-plans byte-identically and the op30/31 intent equals the submitted bytes | Lean authors and admits the birth |
| main.rs:6227-6355 | v3 ingress and committed-frame inspections match the paid plan | Lean inspection (`authority: "structural-only-not-fresh-admission"`, main.rs:6250-6251) plus native admission of the dispatch |
| main.rs:9791-9899 | continuity anchor equals the retained reserve receipt | Lean op17 |
| main.rs:2372-2499 | pre-submit refusal evidence is exact and decodes as a prepare-phase refusal | `minidregg-host inspect outcome` decodes it |

### 3.3 Correct deferrals worth naming

Authority and admission: every mutation is `mini submit` of a Rust-authored intent that Lean admits (main.rs:8298-8318); Rust "cannot infer admission from this observation" (main.rs:9385-9387). Provider charge: "a provider call is charged only by the Host's route quote" (main.rs:10420-10422). Lost replies: an unresolved call is only looked up (main.rs:16986-17173) and the test suite checks the call bytes do not change across relookups (main.rs:20029-20045). Birth and policy bytes are authored by the Host (`mini author`, `current-*-intent`). Pre-submit refusal bytes are decoded by the Host (main.rs:2480-2497).

### 3.4 Physical decisions Rust legitimately owns, but makes brittly

`derivable_effect_note` (main.rs:670-676) decides from string prefixes which "external effects" notes may be auto-acknowledged; the prefix `"Hermes prompt "` matches every ACP failure note pushed at main.rs:14946-14948, so any Hermes protocol fault on an all-`--network none` deployment is acknowledged without an operator (test main.rs:19816 confirms "Hermes prompt 9: ACP stream closed" is derivable). The `--network none` test is a substring scan of the command's argv (main.rs:16855-16861), not a check of the launcher's behaviour. Grain status codes are 62 magic strings (section 1.3.3); a Lean renumbering would silently change these branches.

---

## 4. Flaws noticed

Severity is my judgment for the near goal (a small public demo). Every finding names the exact lines and a failure scenario.

### F1 (high): an uncertain provider send bricks the whole grain; no code path can settle it

`metered_audit_path` accepts only a proven no-send or a complete `received:` response (main.rs:1586-1596; test main.rs:19510-19526 asserts `metered_audit_path(true, None)` and `uncertain:lost-reply` are errors). `abort_refused_provider_request_with` refuses once `send_started` or any outcome exists (main.rs:16687-16689). `retire_refused_provider_request` is eligible only when `!send_started && outcome.is_none()` (provider_retirement.rs:5-13). `reconcile_provider_evidence` calls `metered_audit_path` unless a settlement already exists (main.rs:16495-16518). Meanwhile `attach` refuses while `provider_attempt` is present (main.rs:13547-13549), `hermes` refuses (main.rs:14374-14376), `run` refuses (main.rs:13958-13960), `acknowledge_effects_with` refuses (main.rs:16889-16890), and `provider_reserve` refuses "prior provider request needs exact reconciliation" (main.rs:9371-9376).

Scenario A: the upstream provider stalls mid-stream past `timeoutSeconds`; the gateway reports `ProviderOutcome::Uncertain` (main.rs:9945-9956); the note "may have reached upstream; exact response uncertain" is pushed (main.rs:9990-9994). The prompt ends, the parent settles, and from then on no prompt, run, attach or reconciliation verb can proceed; the provider purse is held at status 5/7 after the fence (main.rs:13886-13901). Scenario B: the controller is SIGKILLed after `send_started=true` is saved (main.rs:9788-9789) and before the outcome; restart records "crossed durable send boundary" (main.rs:15958-15966) and the same dead end follows. The only exits are editing `journal.json` by hand (which the binding check makes risky) or a native expiry the controller does not know about (Q8.4). README.md:200 states the design ("uncertain send keeps the allowance held and prevents another upstream request"), but the absence of *any* audited exit turns one network timeout into a permanently unusable member grain.

### F2 (high): unbounded blocking subprocesses wedge the single-threaded controller

`command_output` runs `Command::output()` with no timeout and outside the custody gate (main.rs:7569-7583). It is used for every non-"work" native transition (`settle`, `interrupt`, `disconnect`, `mode`, provider settle and fence, policy install: main.rs:8338-8340, 7869), every exact lookup (main.rs:17063, 3641, 7465, 7502), `mini continuity` (main.rs:9834), `mini meter` (main.rs:10122), `agent-*-lookup` (main.rs:3722, 3829, 15335, 15589), and `mini profile` (main.rs:9630-9637, also on every provider prepare and reserve, main.rs:9325, 9369). `serve` is one loop (main.rs:17593-17899). Scenario: the Host's persistent socket stops accepting (or a `mini` child blocks on a full pipe); the controller blocks inside `transition` forever; systemd sees a live MainPID and never restarts it; the hard-interrupt closure still kills the worker from the control thread (main.rs:17481-17504), but the Mini `interrupt` fence never runs, the input channel (`mpsc::channel()`, unbounded, main.rs:17518) keeps growing, and the private admin socket cannot run reconciliation because admin requests are serviced by the same blocked loop. `work_output` and `supervised_json_command` go through `custody_gate::run_capture` and can be cancelled (main.rs:7584-7653), so the fix exists in the file but is not applied uniformly.

### F3 (high for correctness, by design in the text): "absent" lookups become final refusals and uncertain writes are settled and dropped

See V3 and V2. `workspace_recover_operation` resolves `absent` + `submitter_stopped` as `refused` (main.rs:11509-11516) and resolves `absent` without that proof as `uncertain` but still runs `finish_tool_operation(&charge)` and clears `workspace_attempt` (main.rs:11517-11524, 11538-11568). `workspace_submitter_stopped` for a previous run depends on `prior_run_stopped` (main.rs:11582-11588), which requires the cgroup path to end with `/mini-grain-controller@TASK.service` (main.rs:689-691). After the attempt is cleared, `tool_call` admits new tools (main.rs:12251-12261), so the agent can re-propose and resubmit the same write. Recorded consequence: run j3 resolved the killed write `refused` and "Hermes rewrote it (op 55 `performed`)" (docs/evidence/2026-09-30-hermes-participant/README.md table). That was correct there only because the first call really was absent.

### F4 (medium): the journal grows without bound and is rewritten with fsync on every operation ID

`reconciliation_log: Vec<Value>` (main.rs:558-559) and `room_resolutions: Vec<Value>` (main.rs:545) are never trimmed (no truncation site in main.rs; `grep` finds only pushes). Each startup recovery appends a record that embeds the full `unresolvedExternal` list (main.rs:16821-16828); each attach recovery and each reconciliation appends more. `born_resources` may hold 8,192 members with full `tool_view`/`parent_view` JSON each (main.rs:784-785, 2159-2161). `next_id` saves the whole pretty-printed journal (main.rs:7563-7568) and most steps call `save()` several times; each save is stage-file write + fsync + rename + directory fsync (journal_io.rs:21-47), and failed saves leave stage files that "are retained evidence, never promoted or deleted" (journal_io.rs:1-2). `open_mode` reads the journal with an unbounded `fs::read` (main.rs:6856). Cost grows linearly with history on every tool call.

### F5 (medium): model and worker output reaches operator logs

The Hermes wrapper's stderr is `Stdio::inherit()` (main.rs:14621), so worker stderr is the controller's stderr, i.e. the systemd journal. Every serve-loop error is `eprintln!("grain-runtime: {e}")` (main.rs:17896), and `command_output` embeds the child's stderr in its error (main.rs:7574-7580). Provider audit lines print provider, credential label (`user:SUBJECT`) and endpoint for every call (main.rs:9195-9204). On a public demo this puts member prompt fragments, tool chatter and member subject IDs into host logs. No bearer is printed.

### F6 (medium): confinement is asserted by file name and argv shape

`systemdScope` requires the program's basename to be `bwrap` (main.rs:2931-2935); a Hermes command requires basename `sandbox-exec` or `bwrap` and some argument ending in `hermes-acp` (main.rs:14390-14400); the provider route checks argv positions (main.rs:392-410); automatic effect acknowledgement checks that argv contains the pair `--network none` (main.rs:16855-16861). An allowlisted `run NAME` command needs no confinement at all (main.rs:2927-2930 only forbid `mini` and `host`). An unscoped Hermes command naming the real `/usr/bin/bwrap` with permissive arguments, or any script named `bwrap`, passes. README.md:317-318 says "an operator-selected OS confinement wrapper is mandatory". The macOS acceptance path uses `sandbox-exec -p "(version 1)(allow default)"` (acceptance.sh:531-534), i.e. no confinement. The operator config is trusted, so this is a misconfiguration hazard, not a remote hole.

### F7 (medium): deploy units do not satisfy the controller's own unit checks

`prove_controller_unit` requires this process to be the active MainPID of `mini-grain-controller@TASK.service` (main.rs:17212-17240) before any scoped `run` or Hermes prompt (main.rs:13974-13978, 14545-14549); `prove_prior_run_stopped` requires the cgroup to end with that unit name (main.rs:689-691); `systemd_manager::load` requires either `/etc/mini/controllers/TASK.json` or all three of `MINI_GRAIN_CONTROLLER_MANAGER=user`, `MINI_GRAIN_WORKER_MANAGER=user`, `MINI_GRAIN_CONTROLLER_UNIT=<exact>` (systemd_manager.rs:158-183, 207-218), and `Runtime::open` fails otherwise (main.rs:6844). The template `deploy/grain-host/mini-grain-controller@.service:9` sets only `MINI_GRAIN_CONTROLLER_UNIT`, so without a root registration the controller refuses to start ("unregistered managed fixture requires explicit user controller, user worker, and exact canonical controller unit", systemd_manager.rs:173). The production `deploy/hermes/mini-hermes.service` is named `mini-hermes.service` (:16, :31), so even with a registration every provider prompt (which requires a scoped `hermes-acp`, main.rs:3225-3236) fails `prove_controller_unit`, and `prior_run_stopped` is always false (making F3's "uncertain" branch the norm after restarts). The journeys pass because they run the controller as `systemd-run --user --unit=mini-grain-controller@TASK` with the three env vars (hermes-journey.sh:211-216).

### F8 (medium): the v1 dispatch path trusts the SPK host's word for money

See V5 (main.rs:5950-6070, 6402-6503). An SPK resident host process running as `hostUid` can call `MarkSend` with any transaction/event/permit strings and then `SettleDefinite` with any response digest, causing a fixed-charge settlement of the dispatch purse per reserve. v2 and v3 close this with Lean inspection; v1 is still dispatched (main.rs:6646-6653, 6717-6729, 6747-6751).

### F9 (low): Host binary hashed repeatedly on hot paths

`sha256_file(&self.config.host)` runs on every validate (main.rs:3023, 3051, 3134), every tool catalog build (main.rs:14222, called per prompt at main.rs:14599 and after each application birth at main.rs:8479-8481), every application API begin (main.rs:8544, 8658), every application birth (main.rs:10652) and every foreground preflight of those tools (main.rs:12781, 12866). The Host is a large native image; each call reads all of it.

### F10 (low): repeated SQLite hashing and a hard 512 MiB ceiling

`hermes_state_fingerprint` hashes `state.db` and `state.db-wal` fully at prompt start and end (main.rs:2686-2717, 14446, 14985) and refuses either file above 512 MiB (main.rs:2706-2711), which turns a long-lived conversation into a retention error requiring `conversation new`.

### F11 (low): duplicated, undeduplicated external-effect notes

`provider_record_outcome` (main.rs:9990-9994) and `fence_tool` (main.rs:13931-13934) push notes without the `contains` check every other site uses; repeated failures accumulate identical notes. Harmless for safety, noisy for operators.

### F12 (low): verification directories accumulate inside attempts

`inspected_pre_submit_refusal` creates `prepare-refusal-verify-PID-NANOS/` inside the attempt on every call (main.rs:2468-2479); `retry_pending_slot` calls it on each recovery pass for a pending attempt without `call.bin` (main.rs:16993). `next_retry_json` exhausts after 9,999 lookups per attempt (main.rs:2543-2552).

### F13 (low): drivers default to a crate-local target directory

acceptance.sh:82, receipt-recovery-acceptance.sh:14 and provider-direct.sh:12 default to `$HERE/target/...`, `../../native/resource-client/target/...`, `native/hyperdocument-link-sqlite-store/target/...`, while the crates are workspace members whose builds land in the root `target/`. A fresh checkout following README.md:9-13 does not produce the binaries these defaults name.

### Things checked and found sound

* No `unwrap`/`expect` on untrusted bytes in main.rs: the 24 non-test sites (`grep`) are on journal invariants established a few lines earlier (for example main.rs:8885 after main.rs:8825-8829; main.rs:13043 after main.rs:13029-13040) or on `serde_json::to_string_pretty` of an owned `Value` (main.rs:7836, 8266). The one `expect` (main.rs:3481) parses a `gatewayBind` that `validate` already parsed (main.rs:3201-3204).
* ACP frames are newline-delimited and capped at 1 MiB before JSON parsing (main.rs:17387-17418; test main.rs:19738-19745); foreground frames at 256 KiB (main.rs:12909-12911); MCP results at 1 MiB with an explicit substitute (main.rs:877-890).
* A crashed controller never signals a saved PID or PGID (main.rs:1146-1148, 6904-6913, 15751-15753).
* The child marker is durable before spawn (main.rs:14033-14043, 14636-14644), the parent `Pending` before `mini submit` (main.rs:8281-8296), the foreground tombstone before reserve (main.rs:13019-13040), the birth no-submit marker before attach (main.rs:10725-10733).
* No provider bearer and no key bytes are handled by main.rs (see "The seven questions", answer (4)).

---

## 5. Unwired / undone

### 5.1 Module reachability from main.rs

Counts are `module::` references in main.rs (from `grep -c "\bmodule::"`); "via" names how a zero-reference module is reached.

| module | lines | refs in main.rs | reached via | shard |
|---|---|---|---|---|
| application_api_tools | 2,764 | 58 | dispatch/app-API paths | C? |
| provider | 3,197 | 42 | gateway | B |
| resource_tools | 1,579 | 28 | tools, births | (unassigned) |
| credentials | 1,888 | 24 | provider table, owner | B |
| control | 948 | 19 | sockets, connect | C |
| dispatch_custody | 476 | 18 | dispatch socket, hex | (unassigned) |
| application_tools | 813 | 13 | app/session births | C |
| systemd_manager | 568 | 13 | units, env | C |
| shared_app_refs | 805 | 11 | shared app resolution | (unassigned) |
| custody_gate | 382 | 8 | cancellable children | B |
| mcp | 926 | 8 | broker | B |
| hermes_outcome | 136 | 8 | ACP outcome typing | (unassigned) |
| config_migration | 2,033 | 6 | open/save/admin/subcommand | B |
| terminal | 600 | 6 | terminal protocol | (unassigned) |
| resident_delivery | 1,341 | 4 | journal field, admin | C |
| session_failure | 705 | 4 | open/save, admin, subcommand | (unassigned) |
| resident_origin | 52 | 4 | resident identity | C |
| hermes_session_verify | 147 | 4 | Invocation type, admin | (unassigned) |
| grain_source | 117 | 4 | intent authoring | (unassigned) |
| homelab | 190 | 4 | scheduler placement | (unassigned) |
| provider_resolution | 543 | 4 | guarded provider lookup | B |
| controller_digest | 28 | 3 | SHA-256 | (unassigned) |
| room_task | 447 | 3 | room tools, validation | C |
| resident_completion | 939 | 3 | journal field, admin | C |
| provider_profile | 257 | 3 | worker profile | B |
| provider_history | 618 | 3 | continuity descriptor, fences | B |
| legacy_custody_audit | 819 | 3 | admin `reconcile tool legacy b44|zero` (main.rs:17800-17801) | (unassigned) |
| cgroup_stop | 443 | 2 | prior-run and worker proofs | (unassigned) |
| quiescence_transport | 717 | 2 | admin, subcommand | C |
| journal_io, public_status, concierge, hermes_room, room_resident, quiescence, resident_reconcile, resident_outcomes, controller_write_scopes, provider_provision | various | 1 each | subcommand or one call | B/C |
| resident_context | 203 | 0 | hermes_room.rs, room_resident.rs, resource_tools.rs | C |
| resident_requests | 660 | 0 | hermes_room.rs, room_resident.rs, quiescence.rs, resource_tools.rs | C |
| resident_preflight | 337 | 0 | `impl Runtime` methods called at main.rs:14325-14336, 17675, 17683, 17689 | C |
| gitweb_worker | 898 | 0 | mcp.rs (`__mini_gitweb_http_raw`, mcp.rs:525) | B |
| pending_prepare | 395 | 0 | `reprepare_parent_settlement` main.rs:17038 | (unassigned) |
| provider_owner | 197 | 0 | config_migration.rs, provider_provision.rs | B |
| provider_retirement | 126 | 0 | main.rs:14340, 14884-14891, 16055 | B |
| provider_recovery | 175 | 0 | main.rs:13856-13857, 16056, 16437 | B |
| provider_continuity_rejection | 609 | 0 | provider_resolution.rs, provider_history.rs | B |
| query_observation | 460 | 0 | main.rs:7748, 7751 | (unassigned) |
| birth_lifecycle_tests, dispatch_runtime_tests, hermes_catalogue_probe, publication_refusal_tests | 143, 643, 93, 821 | test-only | `#[cfg(test)]` (main.rs:26-27, 38-39, 46-47, 58-59) | - |
| provider_bridge | 296 | not declared | second binary (Cargo.toml:13-15) | B |
| provider_choice | 202 | not declared | `#[path]` submodule of credentials (credentials.rs:32) | B |
| provider_homelab_tests | 506 | not declared | `#[path]` test submodule of provider.rs (provider.rs:3196) | B |

Nothing declared is dead code in the strict sense. The "(unassigned)" modules are not named in the B or C briefs the lead gave me; I read journal_io, controller_digest, public_status and the first 80 lines of grain_source; the rest still need a reader.

### 5.2 Reachability of main.rs subsystems from journeys and units

| subsystem | reached by | recorded run |
|---|---|---|
| serve, attach, run, disconnect, reconcile parent audited, reconcile effects, recover | acceptance.sh | not opened |
| Hermes prompt with scripted ACP, MCP workspace tools, SIGKILL recovery, automatic reconcile, hard breaker, soft detach | hermes-journey.sh; journey row `hermes` | docs/evidence/2026-09-30-hermes-participant (j3, j4) |
| policy-install crash and lookup-only recovery | policy-crash-acceptance.sh | not found by name |
| lost MCP reply -> receipt report in next prompt | receipt-recovery-acceptance.sh | not verified |
| provider gateway, broker tickets, provisioning, user-route fee | journeys/byok-native.py (with `localFixtureHostNetwork` + `--network host`, byok-native.py:164-167) | docs/evidence/2026-09-30-hermes-keys (13/13), 2026-10-01-hermes-tariff |
| private Unix gateway with `--network none` + `grain-provider-bridge` | no crate driver uses it (acceptance.sh omits providerTask; byok uses the fixture host network) | README.md:380-385 says the op17 consumer "requires a separate source-matched native run" |
| foreground tools, application API v2 (event21) | agent-two-participant-foreground-journey.sh (needs an SPK fixture outside the crate) | 09-27 evidence (source/test gates per their READMEs) |
| application API v3 / lifetime (event26), payer signing v3, mark-send v3 | no driver in the crate | docs/evidence/2026-09-27-agent-lifetime-* (names only) |
| dispatch v1 (`Reserve`/`MarkSend`/`SettleDefinite`) | none found | docs/evidence/2026-09-27-hermes-agent-api-caller/README.md: "The current reverse dispatch reserve still uses a v1 digest-only nonce and cannot authorize event21" |
| application/session current birth (op30/31) | no crate driver | - |
| fixed-family resource birth (`mini_create_resource`) | no crate driver | RESOURCE-WORKSPACE-MIGRATION.md:9 names it the twin to delete |
| config migration, controller-write-scopes, session-failure, resident-outcome, resident-delivery, resident-completion, quiescence | no crate driver | per their docs |
| `reconcile tool legacy b44|zero` | admin only (main.rs:17800-17801) | a single historical incident receiver |
| terminal | no crate driver | - |

### 5.3 Versioned siblings and twins inside main.rs

| twin pair | sites | which is reachable | which to delete |
|---|---|---|---|
| dispatch reserve v1 / v2 / v3 | `dispatch_reserve` main.rs:5742-5949; `dispatch_reserve_v2` 4652-5040; `dispatch_reserve_v3` 4179-4646 | all three dispatched by `dispatch_rpc` (main.rs:6646-6671) | v1 (cannot authorize event21 per its own evidence); then v2 if event26 is the forward route |
| reverse fixed-request verification v2 / v3 | `verified_reverse_fixed_request` 3997-4076; `verified_reverse_lifetime_fixed_request` 4083-4173 (the same 17-field JSON template written twice) | both | keep one, parameterised |
| dispatch inspect v2 / v3 | 5042-5123 / 5125-5241 | both | as above |
| payer signing v2 / v3 | `dispatch_sign_payer_v2` 5474-5740 / `dispatch_sign_payer_v3` 5246-5468 | both | as above |
| mark-send v1 / v3 | `dispatch_mark_send` 5953-6070 / `dispatch_mark_send_v3` 6073-6398 | both | v1 |
| reserve-hold verification v1 / v2 / lifetime | three branches of `verified_dispatch_reserve_hold` 3658-3992 | all | v1 branch |
| restart reserve recovery v2 / v3 | `recover_v2_dispatch_reserve` 15262-15522 / `recover_v3_dispatch_reserve` 15524-15734 | both called from `recover` (main.rs:15771-15772) | one |
| forward API begin v2 / lifetime | `begin_application_api` 8494-8644 / `begin_application_lifetime_api` 8646-8717 | both | one |
| forward API poll v2 / lifetime | `poll_application_api` 8954-9096 / `poll_lifetime_application_api` 8719-8925 | both | one |
| fixed-family resource birth / workspace create | `mini_create_resource` -> `create_resource(None)` 10575-11007 / `workspace_create` 11879-12009 | both; the fixed route is refused only when the workspace can create (main.rs:12304-12311) | fixed family, per RESOURCE-WORKSPACE-MIGRATION.md:9 |
| legacy one-resource birth / application bundle birth | `BirthPending.route == None` vs `Some` throughout 765-1003, 7063-7184 | both | legacy after migration |
| tool purse lifecycle | `reserve_tool_operation` + `finish_tool_operation` 11160-11233 ("One ToolTask purse lifecycle for both workspace and room effects") vs hand-rolled copies in `create_resource` 10734-10761, `workspace_create` 11944-11971, `mini_publish` 12405-12431, `workspace_recover_birth` 12171-12211 | all | the hand-rolled copies |
| tool argument validation | `preflight_foreground_arguments` 12520-12898 vs the checks inside each tool (for example workspace name rules at 2501-2505, 11046-11051, 11886-11895, 12542-12548, 12606-12610) | both | one validator per tool, called from both paths |
| connector input pump | `foreground_application_api` 13388-13446, `run` 14126-14197, `acp_response` 15096-15167 | all three | one function |
| "is any custody unresolved" walls | `needs_startup_recovery` 16785-16806 and about ten hand-written variants (12974-13001, 13480-13500, 13539-13556, 13949-13966, 14365-14382, 16258-16272, 16882-16901, 13298-13317, 16665-16674, 16747-16759) | all | one predicate family |
| legacy journal shapes | `work_origin: None` means Hermes session (main.rs:792-798, 934-944), `no_native_submit` default false for old journals (main.rs:1010-1013), old provider metering scalar refused by name (main.rs:358-360), `retained_identity` accepts both local and hashed operation IDs (grain_source.rs:52-54) | all | after a typed journal migration |

### 5.4 Built but undone or deferred, in the code's own words

* `fn_read is not advertised until a fixed-config NNTP path is wired and tested` (README.md:369-370).
* The private Unix provider gateway's continuity consumer "requires a separate source-matched native run before its receiving claim" (README.md:383-385).
* "This path does not automatically settle a still-held response: that requires the separate native history-bound admission work" (README.md:394-395).
* "These source consumers require the corresponding native feature bundle and native qualification before deployment" (README.md:412-413).
* RESOURCE-WORKSPACE-EVIDENCE-2026-09-28.md:45-49: the next acceptance "needs an explicit private Hermes profile", and "The stale signed worker-law generation after hard-stop remains a service continuity gap" (since addressed by `managed_law_generation`, main.rs:553-557, 651-666).
* SESSION-FAILURE.md:96-98 hard-codes one incident ("task8781 / operation94 / invocationc2fdf82e...") into a product receiver path.
* No `TODO`, `FIXME`, `todo!` or `unimplemented!` in main.rs (`grep` count 0). `#[allow(dead_code)]` only on `mod credentials` (main.rs:34); `#[allow(clippy::too_many_arguments)]` at main.rs:6072 and 15023.

### 5.5 Tests in main.rs (main.rs:18240-20075, 44 tests)

The tests are unit tests of controller bookkeeping. They fall into three kinds:

1. Pure-function tests with real teeth: `checked_lifetime_worker_wall` (18244-18284), `lifetime_purse_signers` ordering and key pins (18386-18424), lifetime reply verification (18426-18528), quote validation with every field perturbed (19398-19450), user-route quote (19452-19488), maximum-charge rounding (19490-19507), `metered_audit_path` (19509-19526), audit coordinates (19528-19555), tariff selection (19557-19581), route pins (19583-19615), argv-route positional check (19710-19728), ACP frame bound (19738-19745), `managed_law_candidates` (19796-19808), `derivable_effect_note` positives and negatives (19810-19830), birth bundle shape (18841-18887), ordinal retirement (18889-18986). These test the Rust function against hand-built inputs; they do not touch Lean, so a Lean-side change to the quote format would not be caught here (it would be caught by drivers).
2. Fake-`mini` integration tests: `publish_returns_only_its_own_confirmed_receipt_without_reporting_it` (19056-19260) and the four `restart_*` tests (19986-20074) run `Runtime` against a shell script standing in for `mini` (main.rs:19073-19105, 19852-19901) that flips a status file on `grep '"type": "reserve"'`. They check controller bookkeeping (receipt selection, resolution records, no resubmission of `call.bin`) and assert the policy choices of V2/V3 (for example `toolCharge == "1"` after an absent lookup, main.rs:19996). They test the fixture's model of Mini, not Mini.
3. Physical tests: `hard_stop_reaps_a_descendant_after_the_group_leader_exits` spawns `sh -c "sleep 30 & wait"` and kills its group (19757-19794); `legacy_launcher_cannot_arm_a_recoverable_worker` checks `/bin/true` is refused (19730-19736); `prepare_refusal_requires_exact_attempt_and_native_inspection` uses a shell stand-in for the Host's `inspect outcome` (18988-19054).

No test is a tautology; several test only the fixture's behaviour (kind 2). Test files use `std::env::temp_dir()` with PID+nanosecond names (for example main.rs:18288-18295); `provider_retry_replays_exact_retained_response_without_new_reserve` and `retained_lookup_uses_next_native_retry_result` use PID-only names (main.rs:19320-19322, 19749) and would collide across concurrent runs in one process ID namespace only in theory.

---

## 6. Size and shape

### 6.1 Lines per file in this shard

| file | lines | of which tests |
|---|---|---|
| src/main.rs | 20,075 | 1,836 (main.rs:18240-20075, 44 `#[test]`) plus 4 test-only modules declared here (1,700 lines in their own files) |
| README.md + 11 prose contracts | 1,222 | - |
| drivers (8 shell, 2 python) | 3,189 | all of it is test/acceptance tooling |
| Cargo.toml | 32 | - |

### 6.2 main.rs by subsystem

| subsystem | lines | count |
|---|---|---|
| header, mods, imports | 1-82 | 82 |
| config types + provider/route helpers | 84-467 | 384 |
| journal + records (non-dispatch) | 469-1254 | 786 |
| dispatch/app-API records + lifetime reply checks | 1255-1596 | 342 |
| provider tariff slice | 1598-1842 | 245 |
| replay/slot/session types, journal validators, `fresh` | 1844-2267 | 424 |
| file helpers + pre-submit refusal | 2269-2499 | 231 |
| small helpers, coordinates, Hermes home | 2501-2717 | 217 |
| config validation | 2719-3290 | 572 |
| `Runtime` struct + basics | 3292-3533 | 242 |
| **dispatch purse custody (v1/v2/v3 + rpc)** | 3534-6797 | **3,264** |
| open/save | 6798-6920 | 123 |
| receipt reconstruction (publication, birth, provider settle) | 6921-7401 | 481 |
| publication report | 7402-7562 | 161 |
| subprocess helpers, shared apps, queries | 7563-7752 | 190 |
| managed worker law | 7753-7958 | 206 |
| core native transition | 7959-8467 | 509 |
| `handle_tool` + app-API caller (v2 + lifetime) | 8468-9172 | 705 |
| provider gateway handling | 9173-10488 | 1,316 |
| resource birth (fixed + app/session) | 10489-11007 | 519 |
| workspace tools | 11009-12219 | 1,211 |
| `tool_call` table | 12221-12515 | 295 |
| foreground tools (+ foreground API pump) | 12517-13449 | 933 |
| attach / disconnect / fences / run | 13450-14200 | 751 |
| tool catalog | 14201-14312 | 112 |
| Hermes ACP driver | 14314-15261 | 948 |
| v2/v3 dispatch reserve recovery | 15262-15734 | 473 |
| `recover` | 15736-16090 | 355 |
| dispatch audit | 16091-16239 | 149 |
| reconcile / abort / startup / auto / ack / worker / retry | 16240-17173 | 934 |
| free functions (signals, systemd, cgroup, ACP framing) | 17176-17468 | 293 |
| `serve` | 17470-17918 | 449 |
| `main` subcommands | 17920-18238 | 319 |
| tests | 18240-20075 | 1,836 |

Proportions: tests 9.1%; SPK application-API dispatch in all its places (records 342, validation ~190 at 2775-2909 and 3001-3056, custody 3,264, caller 705, foreground API pump ~87, recovery 473 + ~185 inside `recover`, audit 149, `fence_dispatch` 61) about **5,450 lines, 30% of code**; within it, eight v2/v3 (and v1) twin pairs of about 2,000 lines; provider path 1,316 + 245 + parts of records ≈ 1,700 (9%); workspace 1,211 (7%); foreground 933 (5%); Hermes driver 948 (5%).

Why 20,000 lines: every feature landed in main.rs with its own copy of the custody envelope (retain bytes, journal pending, query, compare, submit, classify, look up, reconcile), and older versions stayed beside newer ones (v1/v2/v3 dispatch, fixed birth vs workspace create, legacy journal shapes). Duplication with sibling modules is low: siblings attach behaviour with `impl Runtime` blocks (18 files, list from `grep -ln "impl Runtime"`) rather than copying it; the duplication is internal to main.rs.

### 6.3 A minimal version for the demo-critical path

Demo-critical path assumed: one controller per member grain; Hermes prompts through the private provider gateway (user or pool route) with Lean metering; MCP workspace tools (`list/describe/read/propose/submit/recover/attempts`) and `mini_publish`/`mini_read_resource`; hard/soft attach over `connect`/`grain-ssh`; restart recovery and the admin reconcile verbs; the scoped bwrap worker.

Can be dropped from main.rs (line counts from 6.2):

| drop | lines |
|---|---|
| dispatch purse custody v1/v2/v3 + rpc (3534-6797) | 3,264 |
| dispatch/app-API records and lifetime reply checks (1255-1596, most) | ~300 |
| `DispatchTask`, signer pins, `lifetime_purse_signers`, dispatch validation (180-252, 2775-2909, 3001-3056) | ~260 |
| app-API caller v2 + lifetime (8494-9172) | ~680 |
| foreground tools and foreground API pump (12517-13449) | 933 |
| v2/v3 dispatch reserve recovery (15262-15734) | 473 |
| dispatch parts of `recover` (15771-15956) and `fence_dispatch` (13785-13845) | ~245 |
| dispatch audit (16091-16239) | 149 |
| fixed-family and application/session birth (10489-11007) and their receipt reconstruction (7033-7280) and records (765-1066, 2135-2185) | ~1,100 |
| birth/app/shared parts of the tool catalog and `tool_call` | ~150 |
| legacy shapes, legacy admin verbs (`reconcile tool legacy b44|zero`) | ~50 |
| dedupe input pumps, unresolved-custody walls, tool-purse cycle, preflight | ~500 |
| **total** | **~8,100** |

What remains is about 10,100 code lines in main.rs. Sibling files that would drop with it (crate-level, for the synthesis; owned by other shards): `application_api_tools.rs` (2,764), `dispatch_custody.rs` (476), `shared_app_refs.rs` (805), `application_tools.rs` (813), `gitweb_worker.rs` (898), `legacy_custody_audit.rs` (819), `dispatch_runtime_tests.rs` (643), `birth_lifecycle_tests.rs` (143); `homelab.rs` (190) if no homelab route is offered. That is another ~7,550 lines.

---

## 7. Deployability on a small public Linux VM

### 7.1 What must exist on the box

| item | why | evidence |
|---|---|---|
| `grain-runtime` binary (and a copy as `/agent/grain-runtime` in each worker runtime root) | controller; in-sandbox `mcp-stdio` client | main.rs:14605-14614; acceptance.sh:544 |
| `grain-provider-bridge` in the worker runtime root | in-sandbox HTTP bridge for the private gateway | deploy/grain-host/bwrap:85, 134-135 |
| `mini` (resource-client), `minidregg-host`, Store and signature verifier helpers, a running `mini serve` (or `serve-operator`) on `hostSocket` | every native read/write | section 2.1-2.2 |
| `deploy/grain-host/bwrap` launcher, compiled `launch-gate` beside it, `/usr/bin/bwrap`, unprivileged user namespaces (on Ubuntu 24.04 an AppArmor profile, see deploy/grain-host/README.md:36-39) | scoped workers | main.rs:3436-3445, 17267-17281 |
| systemd with a *user* manager for the service account (workers are always user units: bwrap:165, 175; lingering must be enabled) and cgroup v2 | worker units, MainPID and cgroup proofs | main.rs:683-692, 17212-17342 |
| a controller unit named exactly `mini-grain-controller@TASK.service` | `prove_controller_unit`, `prove_prior_run_stopped` | main.rs:17212-17240, 689 |
| `/etc/mini/controllers/TASK.json` (root-owned registration) or the three fixture env vars | `systemd_manager::initialize` at open | main.rs:6844; systemd_manager.rs:158-237 |
| key broker (`mini-keys`) service and root-owned `keys-client.json`; root-owned provider table `/etc/mini/providers.json` | provider route and tickets | main.rs:9566-9579; BYOK.md:20-42 |
| the upstream `hermes-acp` executable in the runtime root, and for non-provider scoped Hermes a private `config.yaml` with `timeouts.mcp.tool_call` | Hermes | main.rs:14530-14539 |
| one Unix account per member grain | the control socket's only protection is the owner-only `stateDir` | main.rs:2741-2743, 6821-6830; deploy/grain-host/README.md:157-158 |

Neither shipped unit satisfies the controller (F7): the template lacks two of three env vars and the production unit has the wrong name. A demo deploy must render `mini-grain-controller@TASK.service` units (as `install-controller` does per deploy/grain-host/README.md:60-64) with a root registration.

### 7.2 What is operator-configured

The controller JSON with every task, subject and capability ID matching an already-born and delegated native grain set (today produced by `acceptance.sh BOOTSTRAP_ONLY=1`, the `jpay6.sh` extraction in bootstrap-native-controller.py, or `provider-provision` from a template); custody key files; every `reserve` and `charge` (which are the prices, V1); provider token ceilings, byte bounds, timeouts, `maxIterations`; the provider table and grants; Host SHA-256 pins for optional features; command allowlists and wall times; worker workspace and runtime roots.

### 7.3 What is dangerous to expose

* The control socket: any process that can connect can attach, run allowlisted commands, issue Hermes prompts that spend the grain's budget, and run foreground tools (main.rs:17603-17893). Its only guard is file-system ownership of `stateDir` (0700, main.rs:6829). `grain-ssh` forwards an SSH user to it (deploy/grain-host/README.md:130-152).
* The admin socket `stateDir/admin.sock`: settles held allowances at the configured charge, acknowledges external effects, audits workers, runs config migrations and the legacy B44 settlement (main.rs:17653-17813). Must never be reachable from a member.
* The dispatch socket: moves money on an SPK host's word in v1 (F8); peer-UID checked (main.rs:2867-2876).
* Logs: worker stderr and controller errors (F5).

### 7.4 What a stranger on the internet could exercise

Nothing directly: main.rs opens no TCP listener (`UnixStream`/`TcpStream` connects only, section 2.4; the provider gateway's loopback bind is created by provider.rs, shard B). A stranger reaches the controller only through a front end that relays to `connect` (SSH forced command, the hosted shell, the Discord entrance), so exposure equals that front end's authentication.

### 7.5 What a malicious enrolled member could exercise

With the grain's connector: spend the grain's allowance up to its native budget through prompts and allowlisted commands (each settled at the configured charge, V1); choose prompt text that steers the agent through the tool allowlist; trigger fences by hard disconnects (each one a native `interrupt` and an audited or automatic reconcile). Through the agent (a prompt-injected model inside the sandbox): call any allowlisted MCP tool within Lean capabilities and the tool reserve; consume the per-prompt provider request budget (main.rs:9307-9312); write arbitrary stderr into operator logs (F5); corrupt or grow its own `state.db` past 512 MiB to force `conversation new` (F10). With a BYOK user route, revoke or replace their key mid-session (refused before send, journeys/byok-native.py:301-304). A member cannot cause F1 deliberately unless they influence the upstream's latency; any member can be its victim.

### 7.6 Operational notes for a small VM

Each native step is a `mini` subprocess with its own Host round trips, and many steps also query first (section 1.3.4); `next_id` and `save` fsync the full journal (F4); the Host binary is re-hashed on hot paths (F9). The README's own honest-state table measured room-scoped actions at "seconds to minutes (Scout G: workroom template 224-270 s on a development world)" (README.md:76). The controller unit's `MemoryMax=1G`/`TasksMax=64` (template :16-17) and the worker unit's `MemoryMax=2G`/`TasksMax=128` (bwrap:161) need to fit the VM.

---

## 8. Questions for the Lean side

Each is phrased so a Lean reader can answer by pointing at a declaration.

1. **AgentGrain settle bound.** Which declaration in `Kernel/AgentGrain*.lean` admits `{"type":"settle","charge":C}` for a grain, and does it bound `C` by anything other than the signed `reserved` amount? Is there any Lean tariff for non-provider grain work (commands, prompts, tool effects)? (V1)
2. **Provider purse route law.** Which declaration records the route code at `{"type":"reserve","amount":A,"route":R}` (main.rs:9539) and refuses (a) a user-route hold other than the tariff's `perOp` (main.rs:268-270, 1628-1634) and (b) a settle whose `route` differs from the recorded one (main.rs:2627-2637, 10467-10473)? The code points at `Kernel/ProviderRoute.lean` (main.rs:270).
3. **op17 continuity.** In `runProviderContinuitySession` (Host/Main.lean:6723), what exactly makes the verdict `continuous`, and is an intervening *fence* of the same purse the only allowed later provider event (the client's `allowedFence`, native/resource-client/src/provider_continuity.rs:855)?
4. **Held reservation expiry.** Does any Lean rule release or expire a reserved AgentGrain (status 3, 5 or 7) without a controller-authored settle? If not, the uncertain-send dead end (F1) is permanent; name the declaration either way.
5. **Grain birth tariff and namespace.** Does the grain-birth receiver (Kernel/NativeHostGrainBirth.lean:48 uses `config.grainBirthTariffValue`) refuse a source whose `tariff` object (resource_tools.rs:418) differs from the Host-config pin? Does the birth law refuse a target or capability ID already in use, given that Rust computes them as `start + ordinal` (resource_tools.rs:340-350)? (V6)
6. **Private agent ops.** For ops 48, 58, 59, 76, 77, 78, 79, 80 (registry entries in protocol/host-operations.json), which receiver arms perform fresh admission, and are the `inspect application-agent-paid-dispatch-plan`, `inspect-agent-lifetime-paid-ingress` and `inspect application-agent-lifetime-dispatch-committed` verbs pure decoders ("structural-only-not-fresh-admission", main.rs:6250-6251)?
7. **Absent-then-admitted.** On one persistent `mini serve`, can a SUBMIT (op2) frame that was fully written before its sender died be admitted *after* a LOOKUP (op3) for the same call returned `absent`? Name the declaration that serialises frames (the Rust comment main.rs:11505-11508 assumes one connection at a time in accept order). (V3)
8. **Status enum.** Name the AgentGrain status type and confirm the meaning of the decimal codes main.rs branches on: 0, 1, 2, 3, 4, 5, 6, 7 (for example main.rs:2617-2660, 7791-7792, 13719-13760, 16297-16299).
9. **Worker-law install.** Does the `grain-policy-install-intent` receiver require `expectedVersion`, `expectedAddress` and `expectedPreRoot` (main.rs:7811-7824) and refuse when the installed predicate changed, so a stale renewal cannot overwrite a custom law?
10. **Parent witness.** For a tool `settle` carrying `publications` and a `parentWitness` (main.rs:8183-8209), which declaration checks in the same transaction that the parent is still at the witnessed generation and reserved, so an old prompt cannot publish after a hard fence (README.md:274-277)?
11. **Pre-submit refusal finality.** Is an op-255 reply to op1 AUTHORIZED_PREPARE (decoded phase "prepare", main.rs:2495-2497) a guarantee that no signed call for that intent can later be admitted, or only that this prepare failed?
12. **Quote inputs.** Does `ProviderUsage.quotePayload` (Host/ProviderUsage.lean) bind `requestBytes` and `responseBytes` to the actual bytes it is given and enforce the per-task token ceilings itself (ProviderUsage.lean:90 refers to "the token bound"), or are the ceilings only the Rust-side check at main.rs:1832-1840?
13. **Policy byte equality.** Are `mini author --kind predicate` and `--kind grain-policy` (main.rs:7939-7958) both canonical Lean encodings, so that the byte comparison at main.rs:7933 is a sound "same law" test?
14. **Settle-by-anchor.** Is there a Lean form of settle that names the reserve receipt (transaction/event) so that the `OwnManagedLaw` inference (main.rs:16360-16386) could be replaced by a native refusal? (V4)

---

## Appendix B. Every subprocess call site in main.rs (non-test)

"Gate" means `custody_gate::run_capture`, which a hard disconnect can cancel; "plain" means `Command::output()`/`status()` with no timeout and no cancellation (finding F2).

| line | program and verb | path | purpose |
|---|---|---|---|
| 2480 | `minidregg-host CONFIG inspect outcome` | plain `status()` | decode a retained op-255 prepare refusal |
| 3437 | launcher `--launch-gate-protocol` | plain | protocol probe |
| 3641 | `mini retry --mode lookup` | plain | verify a dispatch settlement on the current image |
| 3722 | `mini agent-lifetime-reserve-lookup` | plain | v3 receipt-only lookup |
| 3829 | `mini agent-reserve-lookup` | plain | v2 receipt-only lookup |
| 3979 | `mini retry --mode lookup` | plain | v1 dispatch reserve lookup |
| 4308 | `mini agent-lifetime-reserve-plan` | gate | v3 op80 plan |
| 4527 | `mini agent-lifetime-reserve-seal` | gate | v3 seal with the approval |
| 4539 | `mini agent-lifetime-reserve-submit` | gate | v3 public op2 |
| 4592 | `mini agent-lifetime-reserve-lookup` | gate | v3 op3 |
| 4745 | `mini agent-reserve-plan` | gate | v2 op58 |
| 4939 | `mini agent-reserve-seal` | gate | v2 op59 seal |
| 4953 | `mini agent-reserve-submit` | gate | v2 op2 |
| 4994 | `mini agent-reserve-lookup` | gate | v2 op3 |
| 5336 | `mini agent-lifetime-paid-plan` | gate | v3 paid plan (op78) |
| 5429 | `mini agent-lifetime-paid-payer-sign` | gate | v3 detached payer signatures |
| 5551 | `minidregg-host CONFIG inspect application-agent-paid-dispatch-plan` | gate | v2 paid-plan inspection |
| 5695 | `mini agent-payer-sign ... --key KEYPATH` | gate | v2 payer signature |
| 6227 | `minidregg-host CONFIG inspect-agent-lifetime-paid-ingress` | gate | v3 ingress inspection |
| 6278 | `minidregg-host CONFIG inspect application-agent-lifetime-dispatch-committed` | gate | v3 committed frame inspection |
| 7465, 7502 | `mini retry --mode lookup` | plain | publication and birth receipts before the next prompt |
| 7671 | `mini historical-call-receipt-lookup` | gate | shared app birth lookup |
| 7704 | `mini <recipient_lookup_command>` | gate | shared app issue lookup |
| 7732, 10805, 12302 | `mini` resource read (resource_tools::read_resource_with) | gate | signed bounded reads |
| 7869 | `mini submit --intent-kind grain-policy-install-intent` | plain | managed worker law install |
| 7957 | `mini author --kind predicate|grain-policy` | plain | Lean-authored policy bytes for comparison |
| 8320 | `mini submit --intent-kind grain-intent` (work labels) | gate | attach / reserve / settle-with-publications |
| 8339 | `mini submit --intent-kind grain-intent` (all other labels) | plain | settle, release, disconnect, interrupt, mode, provider settle and fence |
| 9630 | `mini profile` | plain | Host provider tariffs, on every provider prepare and reserve |
| 9834 | `mini continuity` | plain | op17 before every upstream send |
| 10122 | `mini meter` | plain | op19 Lean quote |
| 10857 | `mini current-application-intent|current-session-intent` | gate | op30/op31 author |
| 10945 | `mini submit --intent-kind binary|grain-birth-intent` | gate | resource birth |
| 11024 | `mini workspace --action list|describe|read` | gate | read-only workspace |
| 11118, 11308 | `mini workspace --action propose` | gate | proposal and re-authoring |
| 11360 | `mini workspace --action submit` | gate | workspace submission |
| 11483, 11656, 12099 | `mini workspace --action recover` | gate | exact lookup |
| 11784 | `mini workspace --action import --from-ref` | gate | import a reference |
| 11854 | `mini workspace --action publish-delegation` | gate | export a reference |
| 11997, 12126 | `mini workspace --action create` | gate | workspace birth (and reference completion) |
| 14016 | allowlisted `run` program | spawned child, `setsid` | worker |
| 14615 | `hermes-acp` wrapper | spawned child, `setsid`, stderr inherited | Hermes worker |
| 15335 | `mini agent-reserve-lookup` | plain | v2 restart recovery |
| 15589 | `mini agent-lifetime-reserve-lookup` | plain | v3 restart recovery |
| 17063 | `mini retry --mode lookup` | plain | generic pending lookup in `retry_pending_slot` |
| 17214, 17244, 17285, 17304 | `systemctl` (via systemd_manager) | plain | unit MainPID, kill, state, cgroup |
| 17269 | `launch-gate ACTION STATE UNIT` | plain | init / fence |
| 17349 | `/bin/ps -axo pgid=,stat=` | plain | process-group liveness |

## Appendix C. Admin socket commands and dispatch RPCs

| admin command (exact string, main.rs) | handler | effect |
|---|---|---|
| `config migrate PATH` (17665) | `migrate_config` (config_migration.rs) | config publication |
| `resident prepare SHA256` (17674) | `prepare_resident_prompt` (resident_preflight.rs:117) | issue a prompt ID |
| `resident admission ID SHA256` (17679) | `resident_admission` (resident_preflight.rs:168) | read-only refusal lookup |
| `resident preflight` (17688) | `preflight_resident_prompt` (resident_preflight.rs:184) | readiness snapshot |
| `resident completion-plan PATH` (17694) | `plan_resident_completion` | plan |
| `resident receive-completion PATH` (17700) | `receive_resident_completion` | receive |
| `resident delivery-plan PATH` (17706) | `plan_resident_delivery` | plan |
| `resident deliver-final PATH` (17712) | `deliver_resident_final` | native say + payment |
| `resident supersede-completion PATH` (17718) | `supersede_unsupported_completion` | historical correction |
| `session reconcile-failure PATH` (17727) | `reconcile_session_failure` | historical closure |
| `quiescence transport PATH` (17736) | `inspect_quiescence_transport` | read-only |
| `quiescence status` / `quiescence inspect PATH|none` (17745) | `quiescence_status` / `inspect_quiescence` | read-only |
| `resident reconcile-failed PATH SHA` (17759) | `reconcile_failed_resident` | closure |
| `hermes verify-session` (17771) | `verify_hermes_session` | session/load readiness |
| `inspect application api` (17780) | `inspect_application_api` (9102) | read-only SPK inspection |
| `reconcile parent` / `reconcile tool` (17790-17791) | `reconcile_hold(_, false)` | settle at configured charge with same-image proof |
| `reconcile parent audited` / `reconcile tool audited` (17792-17793) | `reconcile_hold(_, true)` | settle at configured charge, operator-audited |
| `reconcile provider audited` (17794) | `reconcile_provider_audited` | settle at the Lean quote / 0 |
| `reconcile dispatch audited fixed|zero` (17795-17796) | `reconcile_dispatch_audited` | settle dispatch purse |
| `reconcile provider abort` (17797) | `abort_refused_provider_request` | clear unsent attempt |
| `reconcile parent abort` / `reconcile tool abort` (17798-17799) | `abort_unsubmitted_hold` | clear unsubmitted hold |
| `reconcile tool legacy b44` / `reconcile tool legacy zero` (17800-17801) | legacy_custody_audit | one historical incident |
| `reconcile effects` (17802) | `acknowledge_effects` | clear external-effect notes |
| `reconcile worker audited` (17803) | `reconcile_worker_audited` | clear stranded child |
| `reconcile foreground audited` (17804) | `reconcile_foreground_audited` | close a foreground attempt |

| dispatch RPC (`dispatch_custody::Command`, main.rs:6645-6778) | handler | generation |
|---|---|---|
| `Reserve{http_operation_id, source_request_digest, canonical_request_hex}` | `dispatch_reserve` 5742 | v1 |
| `ReserveV2{route_name, forward_operation_id, fixed_request}` | `dispatch_reserve_v2` 4652 | v2 |
| `ReserveV3{..., binding_sha256, worker_wall_seconds, ...}` | `dispatch_reserve_v3` 4179 | v3 |
| `InspectV2` / `InspectV3` | 5042 / 5125 | v2 / v3 |
| `InspectSettlementV3` | 6504 | v3 |
| `SignPayerV2` / `SignPayerV3` | 5474 / 5246 | v2 / v3 |
| `MarkSend` / `MarkSendV3` | 5953 / 6073 | v1 / v3 |
| `SettleDefinite` | 6402 | v1 and v3 |
| `AbortNoSend` | 6582 | all |
| `Inspect` | 6752-6777 | v1 report |

## Appendix D. MCP tools and their gates

| tool | Rust gate (main.rs) | native effect | Lean gate |
|---|---|---|---|
| room tools (`resource_tools::is_room_tool`) | room config; resident restriction 12222-12227 | room writes paid by the room's `hermes/turn` (main.rs:166-169) | room capabilities (room_task.rs, shard C) |
| `mini_room_attempts` | none beyond running state | read-only | - |
| `mini_workspace_list|describe|read` | workspace configured, name syntax | signed read | read capability |
| `mini_workspace_propose` | `minidregg-workspace-proposal-v1` with action `invoke|install-policy|delegate`, 32 KiB, 64 retained (11084-11157) | none (proposal authored by the client) | - |
| `mini_workspace_submit` | proposal retained and unsubmitted; tool purse reserved (11235-11381) | client-authored intent | admission + tool purse settle |
| `mini_workspace_create` | pinned birth context and namespace root (11914-11919) | workspace birth | birth law + settle |
| `mini_workspace_recover` / `mini_workspace_attempts` | operation ID retained | lookup / read-only | - |
| `mini_workspace_import_reference` / `export_reference` | reference type, 64 KiB; performed delegation | local reference files | hint-only (main.rs:11805, 11876) |
| `mini_grain_status` | no arguments | two signed reads | read capabilities |
| `mini_read_resource` | allowlisted name or verified born resource (12283-12303) | signed bounded read | observe capability |
| `mini_create_resource` | allowlisted family; refused if workspace create exists (12304-12311) | grain birth | birth law, Host-config tariff |
| `mini_create_application|_session` | allowlisted family; current-birth Host pin (10647-10658) | op30/31 author + binary submit | birth law |
| `mini_publish` | 1..8 publications to configured or born targets, 32 KiB (12318-12399) | joint settle with parent witness | publication capabilities + witness |
| `mini_application_api` / `__mini_gitweb_http_raw` | route allowlist, Host pins, born or registered app/session (8494-8717) | SPK forward HTTP + dispatch purse | event21/event26 permit, purse law |

## Appendix E. External-effect notes and their automatic derivability

| note text (main.rs line) | derivable by `derivable_effect_note` (main.rs:670-676)? |
|---|---|
| "metered provider request N retained a response without a valid Lean quote; held allowance needs reconciliation" (9240) | no |
| "provider gateway did not drain after prompt; exact attempt may have external effects" (9292) | no |
| "provider request N may have reached upstream; exact response uncertain" (9991-9993) | no |
| "provider request N returned raw headers inconsistent with reported metadata" (9997-9999) | no |
| "provider response N was retained but local HTTP delivery failed; client may retry" (10320-10323) | no |
| "dispatch reservation fenced; app send/response needs exact audit" (13831) | no |
| "provider reservation fenced; external send/response requires exact audit" (13889-13890) | no |
| "delegated tool reservation fenced with uncertain external effects" (13933) | no |
| "Hermes prompt {id}: {error}" (14946-14948) | **yes** (prefix `"Hermes prompt "`) |
| "worker operation N stopped after controller restart; external effects need acknowledgement" (15765-15768) | yes |
| "dispatch reservation survived controller restart; app delivery requires exact audit" (15946) | no |
| "provider request N crossed durable send boundary before controller restart; upstream result uncertain" (15960) | no |
| "controller restarted with a held allowance but no retained worker completion; effects require acknowledgement" (16048) | yes |
| "dispatch request N external effects require explicit acknowledgement" (16225-16228) | no |
| "{parent|tool} confirmed reservation was externally settled; explicit effects acknowledgement required" (16312) | no |
| "{parent|tool} reserved operation may have external effects; explicit operator acknowledgement required" (16389) | yes for `parent`, no for `tool` |
| "provider request N external effects require explicit acknowledgement" (16640-16643) | no |

## Appendix F. `reconciliation_log` actions written by main.rs

`foreground-audited-terminal` (13339), `attach-recovery` (13534), `post-disconnect-reconcile` (13774), `recover-gated-worker` (15759), `settle-held-dispatch-audited` (16149, 16234), `settle-held-allowance` (16286), `settle-provider-source-metered-charge` (16529), `abort-definitively-unreserved-provider-request` (16719), `abort-unsubmitted-hold` (16775), `startup-recovery` (16822), `derive-no-unaccounted-external-effects` / `acknowledge-external-effects` (16938), `clear-stranded-child-after-physical-audit` (16971), `recognize-native-pre-submit-refusal` (17008); legacy_custody_audit.rs adds more. None is ever trimmed (F4).

## Appendix A. Function inventory of main.rs (outside the test module)

Generated from the source (`fn` definitions and the doc comments directly above them, quoted and truncated); subsystem from the table in 6.2.

| line | fn | subsystem | doc comment (quoted, truncated) |
|---|---|---|---|
| 219 | `lifetime_purse_signers` | config | A one-target observed `NativeHost.prepareLoaded (.invoke ...)` has the target, observation, and authority signing incidences in this order. They al... |
| 335 | `provider_task_row` | config | The task's provider table row. A `localFixtureHostNetwork` task may only reach a loopback HTTP row: the host network route exists for fixtures. |
| 346 | `provider_max_iterations` | config |  |
| 357 | `select_provider_metering` | config | The configured task's tariff from the Host profile's one service list (`providerMeterings`). A profile from a Host that still emits the retired sca... |
| 384 | `provider_required_network` | config |  |
| 392 | `provider_command_route` | config |  |
| 412 | `checked_lifetime_worker_wall` | config |  |
| 636 | `label` | journal |  |
| 651 | `managed_law_candidates` | journal | Worker generations whose exact managed law a renewal accepts as its own. A paused grain may carry the law for its current generation or, after an i... |
| 670 | `derivable_effect_note` | journal | Unresolved-effect notes whose only possible effects, for a network-none scoped worker with every Mini attempt resolved, are already accounted for. |
| 681 | `prove_prior_run_stopped` | journal | Startup proof that no process of an earlier run of this controller's unit survives: this process is the unit's active MainPID and the unit cgroup l... |
| 827 | `foreground_tombstone_path` | journal |  |
| 831 | `read_foreground_tombstone` | journal |  |
| 864 | `valid_foreground_request_id` | journal |  |
| 871 | `foreground_request_id` | journal |  |
| 877 | `bounded_foreground_result` | journal |  |
| 892 | `managed_worker_policy_source` | journal |  |
| 925 | `members` | journal |  |
| 933 | `validate_members` | journal |  |
| 1016 | `retire_no_birth_operation` | journal |  |
| 1044 | `persist_retired_no_birth_operation` | journal |  |
| 1068 | `same_publication_confirmation` | journal |  |
| 1082 | `current_publication_receipt` | journal |  |
| 1107 | `publication_receipt_json` | journal |  |
| 1121 | `birth_receipt_json` | journal |  |
| 1191 | `from_confirmed` | journal |  |
| 1390 | `verified_lifetime_definite_reply` | dispatch records |  |
| 1418 | `recovered_lifetime_http` | dispatch records |  |
| 1482 | `checked_lifetime_reserve_plan_hex` | dispatch records |  |
| 1527 | `socket_path` | dispatch records |  |
| 1534 | `host_uid` | dispatch records |  |
| 1542 | `cancel_application_api_on_acp_failure` | dispatch records |  |
| 1586 | `metered_audit_path` | dispatch records |  |
| 1617 | `provider_route_code` | provider tariff | The code the provider purse records for a route (field 4). |
| 1628 | `provider_hold_amount` | provider tariff | The hold one attempt takes: the user fee exactly on the user route, the configured metered hold otherwise. |
| 1637 | `provider_route_pin` | provider tariff | The attempt's slice of the pinned per-route tariff for `route`. |
| 1689 | `provider_metering_metadata` | provider tariff |  |
| 1701 | `provider_max_charge_bound` | provider tariff |  |
| 1729 | `provider_quote_charge` | provider tariff |  |
| 1898 | `validate_workspace` | journal validators |  |
| 2008 | `validate_application_api` | journal validators |  |
| 2069 | `validate_foreground` | journal validators |  |
| 2135 | `validate_birth_registry` | journal validators |  |
| 2180 | `born_resource_count` | journal validators |  |
| 2187 | `pending_for` | journal validators |  |
| 2195 | `pending_for_mut` | journal validators |  |
| 2203 | `hold_for` | journal validators |  |
| 2211 | `hold_for_mut` | journal validators |  |
| 2219 | `fresh` | journal validators |  |
| 2269 | `write_new` | file helpers |  |
| 2285 | `retain_exact_private` | file helpers | Re-enter a private pre-send artifact only if its entire retained byte sequence is unchanged. A partial prior write stays explicit and cannot silent... |
| 2299 | `bounded_policy_bytes` | file helpers |  |
| 2307 | `sha256_file` | file helpers |  |
| 2311 | `sha256_bytes` | file helpers |  |
| 2315 | `retained_exact` | file helpers |  |
| 2347 | `bounded_regular_file` | file helpers |  |
| 2372 | `inspected_pre_submit_refusal` | file helpers | A socket prepare refusal is definitive only when the custody client retained its exact op-255 reply before any call existed. The marker binds the a... |
| 2501 | `valid_workspace_name` | helpers |  |
| 2507 | `workspace_resolution_json` | helpers |  |
| 2515 | `retained_retry_names` | helpers |  |
| 2530 | `newest_new_retry` | helpers | The native record written by the lookup just run, if any. A lookup that wrote nothing (transport failure) is not an answer. |
| 2543 | `next_retry_json` | helpers |  |
| 2554 | `atomic_json` | helpers |  |
| 2559 | `decimal` | helpers |  |
| 2568 | `previous_accepted_index` | helpers |  |
| 2589 | `grain_observation_grants` | helpers |  |
| 2617 | `provider_reserve_coordinates` | helpers |  |
| 2627 | `provider_signed_route` | helpers | The purse's recorded route must be the attempt's: a call the controller sent with one payer's bearer is never settled under another's route. |
| 2639 | `provider_audit_coordinates` | helpers |  |
| 2662 | `hermes_workspace_home` | helpers |  |
| 2686 | `hermes_state_fingerprint` | helpers |  |
| 2719 | `validate` | config validation |  |
| 2722 | `validate_with_workspace` | config validation |  |
| 3241 | `validate_resource_workspace` | config validation |  |
| 3244 | `validate_resource_workspace_record` | config validation |  |
| 3305 | `drop` | runtime basics |  |
| 3345 | `current_work_origin` | runtime basics |  |
| 3369 | `reserve_parent_work_lease` | runtime basics |  |
| 3391 | `emit` | runtime basics |  |
| 3396 | `revoke_provider_gateway` | runtime basics |  |
| 3407 | `claim_completion` | runtime basics |  |
| 3429 | `worker_unit` | runtime basics |  |
| 3433 | `launch_gate` | runtime basics |  |
| 3436 | `prove_launcher_gate` | runtime basics |  |
| 3446 | `worker_env` | runtime basics |  |
| 3497 | `parent` | runtime basics |  |
| 3506 | `tool` | runtime basics |  |
| 3520 | `dispatch` | runtime basics |  |
| 3534 | `dispatch_settlement_record` | DISPATCH |  |
| 3588 | `verified_dispatch_settlement` | DISPATCH |  |
| 3616 | `verified_dispatch_settlement_record` | DISPATCH |  |
| 3658 | `verified_dispatch_reserve_hold` | DISPATCH | Audit-only reconstruction of a reserve that may have committed just before the wrapper copied its operation/gen/postroot into the attempt. This nev... |
| 3997 | `verified_reverse_fixed_request` | DISPATCH | Retain one exact source-authored HTTP request before its separately paid AgentGrain reserve. The source digest is checked against the full request ... |
| 4083 | `verified_reverse_lifetime_fixed_request` | DISPATCH | Compare a v3 reverse reserve request with the exact durable forward HTTP and immutable event22/event27 route pins before any purse signer is opened... |
| 4179 | `dispatch_reserve_v3` | DISPATCH | Source-owned event26 reserve for one retained v3 forward call. The exact op80 plan and current signed parent/purse are checked before the protected... |
| 4302 | `path` | DISPATCH |  |
| 4652 | `dispatch_reserve_v2` | DISPATCH | Source-owned v2 reserve for exactly the active forward API call. The private op58/59 phases expose and seal a plan; only the marked public op2 phas... |
| 4740 | `string` | DISPATCH |  |
| 5042 | `dispatch_inspect_v2` | DISPATCH |  |
| 5125 | `dispatch_inspect_v3` | DISPATCH |  |
| 5246 | `dispatch_sign_payer_v3` | DISPATCH | Return only detached payer signatures for this exact v3 source plan. Resident app/grant keys never enter this process; op79 assembly and fresh op76... |
| 5330 | `path` | DISPATCH |  |
| 5474 | `dispatch_sign_payer_v2` | DISPATCH | The resident supplies an op48 paid plan, but only the controller's retained reserve, protected signer pin, and a fresh source inspection can approv... |
| 5742 | `dispatch_reserve` | DISPATCH |  |
| 5953 | `dispatch_mark_send` | DISPATCH | Persist the one-shot external boundary before the physical host writes to fd3. The host must already have inspected the exact committed Mini permit... |
| 6073 | `dispatch_mark_send_v3` | DISPATCH |  |
| 6402 | `dispatch_settle_definite` | DISPATCH | Only a definite response to this exact marked attempt permits the fixed operator charge. A lost fd3 reply leaves the reservation held. |
| 6504 | `dispatch_inspect_settlement_v3` | DISPATCH |  |
| 6582 | `dispatch_abort_no_send` | DISPATCH | A definite pre-send refusal releases this one purse at zero. Once the send marker exists, only a definite response or audited reconciliation may se... |
| 6637 | `dispatch_rpc` | DISPATCH |  |
| 6780 | `answer_dispatch` | DISPATCH |  |
| 6798 | `provider` | open/save |  |
| 6812 | `open` | open/save |  |
| 6817 | `open_mode` | open/save | The migration entrypoint never calls serve or any worker/provider action. Its only relaxed seam is cross-file transport validation before publication. |
| 6916 | `save` | open/save |  |
| 6921 | `confirmed_publication_receipt` | receipts |  |
| 7033 | `confirmed_birth_record` | receipts |  |
| 7218 | `verify_born_record` | receipts |  |
| 7241 | `verified_born_named` | receipts |  |
| 7259 | `verified_born_target` | receipts |  |
| 7281 | `provider_settlement_record` | receipts |  |
| 7356 | `verified_provider_settlement` | receipts |  |
| 7402 | `verified_publication_report` | receipt report |  |
| 7563 | `next_id` | subprocess/queries |  |
| 7569 | `command_output` | subprocess/queries |  |
| 7584 | `work_output` | subprocess/queries |  |
| 7612 | `supervised_resource_read` | subprocess/queries |  |
| 7633 | `supervised_json_command` | subprocess/queries |  |
| 7654 | `resolve_shared_app` | subprocess/queries |  |
| 7737 | `query` | subprocess/queries |  |
| 7741 | `query_as` | subprocess/queries |  |
| 7746 | `query_as_via` | subprocess/queries | Only the query-only topology receiver can construct this transport token. The shared bounded read path preserves this exact admitted socket on retr... |
| 7750 | `query_policy` | subprocess/queries |  |
| 7753 | `managed_worker_subjects` | worker law |  |
| 7774 | `renew_worker_policy` | worker law |  |
| 7893 | `require_managed_worker_policy` | worker law |  |
| 7939 | `author_grain_policy_bytes` | worker law |  |
| 7959 | `transition` | core transition |  |
| 7963 | `mark_hold` | core transition |  |
| 7976 | `mark_hold_as` | core transition |  |
| 8010 | `record_reserve_confirmation` | core transition |  |
| 8102 | `transition_as` | core transition |  |
| 8112 | `transition_as_with_witness` | core transition |  |
| 8468 | `handle_tool` | app-API caller |  |
| 8494 | `begin_application_api` | app-API caller |  |
| 8646 | `begin_application_lifetime_api` | app-API caller |  |
| 8719 | `poll_lifetime_application_api` | app-API caller |  |
| 8927 | `finish_application_api_no_dispatch` | app-API caller |  |
| 8954 | `poll_application_api` | app-API caller |  |
| 9102 | `inspect_application_api` | app-API caller | After a crash, inspect the exact operation ID under the original saved binding. The current protected socket may belong to a new invocation; the ho... |
| 9173 | `provider_lease_current` | provider |  |
| 9185 | `handle_provider` | provider |  |
| 9273 | `drain_provider_after_prompt` | provider |  |
| 9307 | `provider_prompt_budget` | provider |  |
| 9314 | `provider_prepare` | provider |  |
| 9353 | `provider_reserve` | provider |  |
| 9560 | `provider_route` | provider | Resolve this request's route: the task's table row and the bearer the row's credential kind calls for. A `user` row uses only the pinned friend's c... |
| 9629 | `provider_native_profile` | provider | Pinned provider tariff and settlement capability metadata. Exact native admission remains authoritative; this check rejects incompatible bundles be... |
| 9645 | `provider_replay` | provider |  |
| 9723 | `provider_before_send` | provider |  |
| 9791 | `verify_provider_reserve_continuity` | provider |  |
| 9900 | `provider_record_outcome` | provider |  |
| 10006 | `provider_meter_quote` | provider |  |
| 10009 | `provider_meter_quote_inner` | provider |  |
| 10173 | `validated_metered_charge` | provider |  |
| 10184 | `validated_metered_charge_for_reserve` | provider |  |
| 10300 | `provider_delivery` | provider |  |
| 10413 | `provider_settle` | provider |  |
| 10489 | `finish_no_birth` | birth |  |
| 10575 | `create_resource` | birth |  |
| 11009 | `workspace_root` | workspace |  |
| 11014 | `workspace_proposal_paths` | workspace |  |
| 11022 | `workspace_readonly` | workspace |  |
| 11084 | `workspace_propose` | workspace |  |
| 11160 | `reserve_tool_operation` | workspace | One ToolTask purse lifecycle for both workspace and room effects. |
| 11202 | `finish_tool_operation` | workspace |  |
| 11235 | `workspace_submit` | workspace |  |
| 11383 | `workspace_recover_operation` | workspace |  |
| 11571 | `push_workspace_resolution` | workspace |  |
| 11582 | `workspace_submitter_stopped` | workspace | True only when no process that could hold this attempt's custody child is alive: this process reaps its own children before returning from the cust... |
| 11592 | `workspace_attempts` | workspace | Read-only: one retained resolution, the pending attempt, or the bounded newest-first list. Nothing here touches Mini. |
| 11640 | `workspace_relookup_uncertain` | workspace | Re-look-up a retained `uncertain` resolution. A confirmation upgrades it to `performed`; nothing is ever resubmitted and no allowance moves. |
| 11694 | `workspace_recover` | workspace |  |
| 11726 | `supervised_text_command` | workspace |  |
| 11750 | `workspace_import_reference` | workspace | Accept a recipient reference another participant published for this grain's subject. The common client checks the recipient and receipt; the stored... |
| 11811 | `workspace_export_reference` | workspace | Publish the recipient reference for a delegation this grain proposed and whose submission resolved `performed`. The common client does an exact his... |
| 11879 | `workspace_create` | workspace |  |
| 12011 | `workspace_recover_birth` | workspace |  |
| 12221 | `tool_call` | tool table |  |
| 12520 | `preflight_foreground_arguments` | foreground | Reject definite input errors before taking a signed parent allowance. This is only a syntax/operator-profile preflight; the normal tool path still ... |
| 12903 | `foreground_tool` | foreground | Run one model-free tool call under the same signed parent/tool custody. The foreground operation ID is durable before reserve or any native submit;... |
| 13159 | `foreground_result` | foreground |  |
| 13206 | `acknowledge_foreground` | foreground |  |
| 13258 | `answer_foreground_result` | foreground |  |
| 13274 | `answer_foreground_ack` | foreground |  |
| 13288 | `reconcile_foreground_audited` | foreground |  |
| 13363 | `foreground_application_api` | foreground |  |
| 13450 | `check_not_cancelled` | attach/run |  |
| 13457 | `finish_reconnected_mode` | attach/run |  |
| 13479 | `conversation_new` | attach/run |  |
| 13516 | `note_hard_reconnect` | attach/run |  |
| 13523 | `attach` | attach/run |  |
| 13583 | `stop_and_reap_owned` | attach/run |  |
| 13666 | `kill_child` | attach/run |  |
| 13672 | `disconnect` | attach/run |  |
| 13785 | `fence_dispatch` | attach/run |  |
| 13846 | `fence_provider` | attach/run |  |
| 13905 | `fence_tool` | attach/run |  |
| 13945 | `run` | attach/run |  |
| 14203 | `room_tools_restricted` | catalog | Prepare bounded tool-discovery names from exact retained Mini births. The catalog never substitutes for admission on a later tool call. |
| 14208 | `tool_catalog` | catalog |  |
| 14318 | `hermes` | hermes | Drive the real upstream `hermes-acp` through an operator-selected OS confinement wrapper. ACP permission requests are refused; built-in tools are s... |
| 14322 | `hermes_session` | hermes |  |
| 14347 | `hermes_session_inner` | hermes |  |
| 15024 | `acp_response` | hermes |  |
| 15262 | `recover_v2_dispatch_reserve` | dispatch recovery |  |
| 15524 | `recover_v3_dispatch_reserve` | dispatch recovery |  |
| 15736 | `recover` | recover |  |
| 16095 | `reconcile_dispatch_audited` | dispatch audit | Operator-only recovery of one held dispatch request. The operator chooses the fixed charge or zero after auditing external effects; an uncertain fd... |
| 16240 | `reconcile_hold` | reconcile |  |
| 16250 | `reconcile_hold_with` | reconcile |  |
| 16432 | `reconcile_provider_audited` | reconcile |  |
| 16435 | `reconcile_provider_evidence` | reconcile |  |
| 16661 | `abort_refused_provider_request` | reconcile |  |
| 16664 | `abort_refused_provider_request_with` | reconcile |  |
| 16743 | `abort_unsubmitted_hold` | reconcile |  |
| 16785 | `needs_startup_recovery` | reconcile |  |
| 16811 | `startup_recovery` | reconcile | Runs before `serve` admits any input. The supervisor restarted this controller; it repairs what it can prove and leaves the rest fenced for the ope... |
| 16840 | `automatic_reconcile` | reconcile | Settle what `recover` fenced when the identity of the held allowance is machine-provable, then derive the external-effect acknowledgement when ever... |
| 16877 | `acknowledge_effects` | reconcile |  |
| 16881 | `acknowledge_effects_with` | reconcile |  |
| 16943 | `reconcile_worker_audited` | reconcile |  |
| 16979 | `retry_pending` | reconcile |  |
| 16986 | `retry_pending_slot` | reconcile |  |
| 17200 | `signal_group` | free fns |  |
| 17212 | `prove_controller_unit` | free fns |  |
| 17242 | `kill_unit` | free fns |  |
| 17267 | `launch_gate` | free fns |  |
| 17283 | `unit_inactive` | free fns |  |
| 17296 | `prove_worker_unit_stopped` | free fns |  |
| 17348 | `group_has_live_member` | free fns | Read-only process table inspection. This counts all non-zombie members, including grandchildren after the leader exits. The child leader stays unre... |
| 17366 | `child_exited_unreaped` | free fns | WNOWAIT observes exit without reaping the group leader. Reaping it before group cleanup would permit PGID reuse while descendants are being killed. |
| 17387 | `read_acp_frame` | free fns |  |
| 17420 | `acp_send` | free fns |  |
| 17427 | `forward_display` | free fns |  |
| 17439 | `interrupt_from_input` | free fns |  |
| 17470 | `serve` | serve |  |
| 17902 | `clear_stale_control_socket` | serve |  |
| 17920 | `main` | main |  |

249 functions outside the test module.

## Appendix G. Journal field index

Generated: for each `Journal` field (main.rs:471-567), the number of `journal.FIELD` references in main.rs outside tests, the first lines, and the other source files that touch the same field. Fields touched by many sibling files are the coupling that makes the journal hard to split.

| field (decl line) | refs in main.rs code (`journal.FIELD`) | sample lines | other src files referencing it |
|---|---|---|---|
| `format` (472) | 0 |  | - |
| `binding` (473) | 0 |  | config_migration.rs, provider_provision.rs, publication_refusal_tests.rs, query_observation.rs, quiescence_transport.rs, resident_completion.rs, resident_delivery.rs, resident_outcomes.rs, session_failure.rs |
| `next_operation_id` (474) | 7 | 6879, 7564, 7565, 13532, 13772, 16820, 17861 | legacy_custody_audit.rs, provider_history.rs, provider_provision.rs, publication_refusal_tests.rs, query_observation.rs, resident_completion.rs, resident_delivery.rs |
| `connection` (475) | 54 | 3420, 3421, 4014, 4101, 5267, 5490, 5734, 5759 ... | dispatch_runtime_tests.rs, hermes_outcome.rs, hermes_session_verify.rs, provider_provision.rs, publication_refusal_tests.rs, resident_preflight.rs |
| `pending` (476) | 23 | 7779, 7842, 7872, 7882, 7883, 12231, 12982, 13063 ... | legacy_custody_audit.rs, pending_prepare.rs, provider_recovery.rs, provider_retirement.rs, query_observation.rs, room_resident.rs |
| `tool_pending` (478) | 25 | 1020, 10493, 10661, 10914, 10958, 10976, 10991, 11161 ... | birth_lifecycle_tests.rs, legacy_custody_audit.rs, pending_prepare.rs, provider_recovery.rs, provider_retirement.rs, publication_refusal_tests.rs, room_task.rs |
| `provider_pending` (480) | 19 | 8391, 9371, 9725, 10464, 12232, 12990, 13222, 13308 ... | hermes_outcome.rs, legacy_custody_audit.rs, pending_prepare.rs, provider_history.rs, provider_recovery.rs, provider_resolution.rs, provider_retirement.rs, query_observation.rs |
| `hard_reconnect_pending` (482) | 7 | 6909, 13459, 13471, 13517, 13765, 16008, 16085 | - |
| `child` (483) | 31 | 5760, 6906, 8506, 9178, 12230, 12980, 13482, 13540 ... | dispatch_runtime_tests.rs, legacy_custody_audit.rs, pending_prepare.rs, provider_recovery.rs, provider_retirement.rs, publication_refusal_tests.rs, quiescence.rs |
| `settlement_due` (484) | 18 | 3415, 8398, 12997, 13227, 13311, 13494, 13544, 13748 ... | pending_prepare.rs, provider_retirement.rs |
| `parent_hold` (486) | 16 | 12983, 13062, 13217, 13299, 13486, 13545, 13747, 13956 ... | legacy_custody_audit.rs, pending_prepare.rs, publication_refusal_tests.rs |
| `tool_hold` (488) | 24 | 10503, 10540, 10561, 10662, 10959, 11161, 11205, 11215 ... | birth_lifecycle_tests.rs, hermes_outcome.rs, legacy_custody_audit.rs, pending_prepare.rs, provider_retirement.rs, publication_refusal_tests.rs, resident_delivery.rs, resident_preflight.rs, room_task.rs |
| `dispatch_pending` (490) | 29 | 4210, 4660, 5761, 5993, 6151, 6427, 6551, 6595 ... | pending_prepare.rs, provider_recovery.rs, provider_retirement.rs |
| `dispatch_hold` (492) | 36 | 4211, 4661, 5186, 5762, 6552, 6599, 6624, 6762 ... | dispatch_runtime_tests.rs, pending_prepare.rs, provider_retirement.rs |
| `dispatch_attempt` (494) | 34 | 4212, 4461, 4662, 4901, 5763, 5795, 6497, 6553 ... | dispatch_runtime_tests.rs, pending_prepare.rs, provider_retirement.rs |
| `application_api_attempt` (496) | 21 | 6528, 8507, 8603, 8744, 8781, 8885, 8898, 8915 ... | dispatch_runtime_tests.rs, hermes_session_verify.rs, provider_retirement.rs |
| `application_api_history` (498) | 9 | 8917, 8918, 8920, 8947, 8948, 8950, 9088, 9089 ... | - |
| `provider_hold` (500) | 20 | 8390, 9372, 12233, 12991, 13223, 13309, 13489, 13548 ... | hermes_outcome.rs, legacy_custody_audit.rs, pending_prepare.rs, provider_history.rs, provider_recovery.rs, provider_resolution.rs, provider_retirement.rs |
| `provider_attempt` (502) | 19 | 9195, 9373, 9486, 10170, 10486, 12234, 12992, 13310 ... | hermes_outcome.rs, pending_prepare.rs, provider_history.rs, provider_recovery.rs, provider_retirement.rs |
| `provider_settlement` (504) | 4 | 8367, 9482, 13855, 17151 | hermes_session_verify.rs |
| `provider_replays` (508) | 7 | 9321, 9377, 9382, 10386, 10389, 14585, 14588 | hermes_outcome.rs, hermes_session_verify.rs, provider_recovery.rs, resident_completion.rs, resident_delivery.rs, session_failure.rs |
| `provider_prompt_requests` (512) | 4 | 9308, 9485, 14585, 14589 | hermes_session_verify.rs |
| `resident_prompt_origin` (514) | 7 | 14577, 14580, 14803, 14850, 15210, 15231, 17873 | hermes_outcome.rs, resident_completion.rs, resident_delivery.rs, resident_preflight.rs |
| `resident_delivery` (516) | 1 | 14349 | resident_delivery.rs |
| `resident_completion` (518) | 1 | 14349 | resident_completion.rs |
| `foreground_attempt` (520) | 22 | 6907, 12929, 12981, 13029, 13043, 13047, 13078, 13092 ... | hermes_session_verify.rs, provider_retirement.rs, publication_refusal_tests.rs |
| `foreground_history` (522) | 12 | 13002, 13011, 13093, 13141, 13152, 13154, 13231, 13238 ... | publication_refusal_tests.rs |
| `publication_receipts` (526) | 8 | 8232, 8243, 8350, 12503, 15001, 17081, 17092, 17094 | publication_refusal_tests.rs |
| `birth_next_ordinal` (531) | 1 | 1028 | birth_lifecycle_tests.rs |
| `birth_operation` (533) | 14 | 1017, 1040, 10490, 10659, 10725, 10956, 12255, 12988 ... | birth_lifecycle_tests.rs |
| `birth_pending` (535) | 16 | 1020, 10493, 10660, 10913, 10957, 10975, 10990, 12256 ... | - |
| `born_resources` (537) | 10 | 1029, 7242, 7264, 10679, 10955, 12833, 12885, 14234 ... | birth_lifecycle_tests.rs |
| `workspace_proposals` (539) | 2 | 11085, 11145 | publication_refusal_tests.rs, room_task.rs |
| `workspace_attempt` (541) | 13 | 11085, 11257, 11293, 11566, 11605, 11612, 11926, 12251 ... | hermes_outcome.rs, publication_refusal_tests.rs, resident_preflight.rs, room_task.rs |
| `room_attempt` (543) | 10 | 11085, 11257, 11926, 12251, 12986, 13927, 13951, 14367 ... | resident_delivery.rs, room_task.rs |
| `room_resolutions` (545) | 0 |  | resident_delivery.rs, room_task.rs |
| `workspace_birth` (547) | 10 | 11925, 11973, 12000, 12212, 12252, 12987, 13927, 13952 ... | room_task.rs |
| `workspace_resolutions` (552) | 6 | 11572, 11573, 11575, 11648, 11682, 11690 | - |
| `managed_law_generation` (557) | 1 | 7873 | - |
| `reconciliation_log` (559) | 12 | 13337, 13533, 13773, 15758, 16147, 16233, 16527, 16653 ... | legacy_custody_audit.rs, pending_prepare.rs, provider_history.rs, provider_resolution.rs, publication_refusal_tests.rs |
| `hermes_session` (561) | 13 | 13501, 13503, 14420, 14442, 14454, 14460, 14733, 14766 ... | hermes_outcome.rs, hermes_session_verify.rs, publication_refusal_tests.rs, quiescence.rs, resident_completion.rs, session_failure.rs |
| `prior_hermes_sessions` (563) | 2 | 13502, 13506 | - |
| `prompt_witness` (565) | 11 | 3385, 4248, 4701, 5785, 8689, 9473, 13126, 13766 ... | dispatch_runtime_tests.rs, hermes_outcome.rs, hermes_session_verify.rs, provider_retirement.rs, publication_refusal_tests.rs |
| `unresolved_external` (566) | 33 | 9241, 9242, 9299, 9991, 9997, 10324, 10325, 12998 ... | dispatch_runtime_tests.rs, hermes_outcome.rs, hermes_session_verify.rs, legacy_custody_audit.rs |
