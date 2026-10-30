# grain-runtime: crate synthesis

| field | value |
|---|---|
| crate | `/Users/ember/dev/minidregg/native/grain-runtime` (package `minidregg-grain-runtime`; bins `grain-runtime` = `src/main.rs`, `grain-provider-bridge` = `src/provider_bridge.rs`) |
| size | 55,895 Rust lines: `src/main.rs` 20,075 + 27 sibling files read by shard B (17,227) + 28 sibling files read by shard C (18,277) + example and fixture Rust (316) |
| role | the Hermes AgentGrain controller: one supervisor process per member grain |
| synthesizer | Opus crate synthesizer, fan-out review 2026-10-26 |
| inputs | `grain-runtime--A-main.md` (A, 1,160 lines), `grain-runtime--B-provider-credentials-custody.md` (B, 847), `grain-runtime--C-resident-control-tools.md` (C, 688); A's scratch table `/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/gr-A/subcommand-table.md` |
| method | the three reports read in full; Rust source opened only to settle five disagreements (section 9, each with `path:line`); no build, no test run |

Citations: `A §x`, `B §x`, `C §x` point into the shard reports, which carry the `path:line` evidence. Finding IDs are kept as the readers wrote them: A's `V1`-`V8` and `F1`-`F13`, B's `BV1`-`BV8` and `B-F1`-`B-F20`, C's `C-V1`-`C-V8` and `C-F1`-`C-F14`. Paths are relative to `native/grain-runtime/` unless they start with a top-level directory.

## Summary

1. grain-runtime is one journal-driven, single-threaded supervisor per member grain. It never speaks the Host wire. Every native read and write is a `mini` subprocess or a `minidregg-host CONFIG inspect` call, and every write is a Rust-authored intent that Lean admits.
2. Lean admits authority. Rust still sets every price except provider metering, and it decides what refused, absent and uncertain work costs (full fee). It also picks who pays the provider and holds member quotas, concierge membership-for-payment and room-turn sequencing. It treats "lookup absent + submitter stopped" as "never happened" in three separate implementations. Section 3 merges these into 24 rows.
3. The lost-reply envelope is real: Pending is journaled before submit, recovery only looks up and never resubmits, and the provider outcome is journaled before the worker is acknowledged. It has three kinds of hole. One upstream timeout, oversized header block or metered 429 leaves a provider purse held with **no** path out, and the grain refuses all further work (A F1 + B-F1/F2/F3). "Absent" lookups become refusals, and the model then repeats the write (V3/C-V4/BV5/BV6). The resident and concierge paths can wedge permanently or lose money (C-F1, C-F2, C-F4). Section 4.
4. Reachability is thin. Nothing in this crate runs on the public node. README's "Hermes in a room: executed" row (J14) exercised the legacy `hermes-room step` chat-completions runner, **not** the ACP grain controller (`native/resource-client/journey.d/j14.sh:197, 386, 419`). The strongest recorded controller runs are `hermes-journey.sh` (2026-09-30, scripted ACP) and `byok-native.py` (2026-09-30/10-01, scripted provider, host-network fixture mode). The production `--network none` path with `grain-provider-bridge` has never run.
5. Twins and dead code: three dispatch generations in main.rs (~5,450 lines, ~2,000 of them v1/v2/v3 duplicates). v3 app-API is dead in two independent places (C-F3, confirmed). There are three one-incident receivers (1,940 lines) and an unrun config migration (2,033). `credentials.rs` is compiled into three crates.
6. Demo-minimal controller, reconciled across A, B and C: **~24,500 lines remain of 55,895** (~8,500 out of main.rs, ~21,600 sibling lines deleted, ~1,250 moved to mini-keys). With a room resident it is ~31,500. Section 6.
7. Neither shipped unit satisfies the controller's own checks (A F7, refined in section 9). A Hetzner deploy must render `mini-grain-controller@TASK.service` plus a root registration, and today nothing in `deploy/` writes the registration.

---

## 1. What the crate is

### 1.1 The controller's shape in one page

`grain-runtime serve CONFIG` supervises exactly one AgentGrain task (the member's grain) and up to three auxiliary grains it owns custody keys for: a **ToolTask** purse for MCP effects, a **ProviderTask** purse for model calls, and a **DispatchTask** purse for SPK application-API calls. Together with the parent these are "the four grain purses", each with its own `pending`/`hold` slot in the journal (A §1.3.2).

* **One loop.** Three socket threads feed one unbounded `mpsc` channel, consumed by a blocking `input.recv()` loop (main.rs:17470-17900). Long operations poll at 20 ms inside that loop, and every `mini` child it spawns runs on that thread (A §1.3, F2).
* **Three sockets**, all Unix:
  * the **control socket** (`controlSocket`, 0600 inside a 0700 `stateDir`, no `SO_PEERCRED`; attach, run, prompt, foreground tools, terminal frames; C §1.1);
  * the **admin socket** `stateDir/admin.sock` (one-line commands: reconcile, resident receivers, migration, quiescence; A App. C);
  * the optional **dispatch socket** (`dispatchTask.socketPath`, 0600 + ACL + `SO_PEERCRED == hostUid`; the SPK resident host calls back to reserve, sign as payer, mark send and settle the dispatch purse; B §1.4).

  Per prompt it also opens `mcp-N.sock` (the MCP broker, bind-mounted into the sandbox as `/run/mini-grain.sock`) and `provider-gateway.sock` (or a loopback TCP port in fixture mode) (B §1.1, §1.6).
* **One journal.** `stateDir/journal.json` (`minidregg-grain-runtime-v1`, ~45 fields) binds the exact controller config and is rewritten atomically with fsync on every save. Attempt directories are retained forever (A §1.3.2).
* **Everything native via `mini`.** `mini submit|retry --mode lookup|query|author|profile|continuity|meter|workspace|agent-*|credit|shell|key|operator-status|provider-continuity|operation-proof` and `minidregg-host CONFIG inspect …`. Raw reply bytes are read only for ops 255, 19, 30 and 31, and those checks agree with the Lean arms (A §2.1). The `mini` client's decoded `outcome.json` `type:"refused"` is trusted as a definitive native refusal. Only the pre-submit path re-decodes the bytes through the Host (A §2.2).
* **The worker.** `hermes-acp` runs under the operator's `deploy/grain-host/bwrap` launcher (user/pid/net namespaces, `--clearenv`, a transient user-systemd unit with MemoryMax 2G, no seccomp). It is driven over ACP (newline JSON-RPC, 1 MiB frames) and reaches the controller only through the MCP broker and the provider gateway (A §1.3.6, B §1.1).
* **Provider calls.** The provider key never enters the controller. The gateway asks the `mini-keys` broker for a single-use ticket and the broker performs the HTTP send. The charge is the Lean op-19 quote (B §1.1, A §1.3.7).

### 1.2 Module map by family

| family | files (lines) | family lines | reader |
|---|---|---|---|
| entry point and core | main.rs (20,075) | 20,075 | A |
| provider HTTP edge | provider.rs 3,197; provider_bridge.rs 296 (second binary); provider_profile.rs 257; provider_homelab_tests.rs 506 (test); homelab.rs 190 | 4,446 | B |
| provider custody recovery (op 17) | provider_history.rs 618; provider_resolution.rs 543; provider_continuity_rejection.rs 609; provider_recovery.rs 175; provider_retirement.rs 126 | 2,071 | B |
| provisioning and keys | credentials.rs 1,888; provider_choice.rs 202; provider_provision.rs 228; provider_owner.rs 197 | 2,515 | B |
| custody and dispatch | custody_gate.rs 382; dispatch_custody.rs 476; dispatch_runtime_tests.rs 643 (test) | 1,501 | B |
| one-incident and migration | legacy_custody_audit.rs 819; config_migration.rs 2,033; session_failure.rs 705; resident_outcomes.rs 416 | 3,973 | B, C |
| MCP and GitWeb | mcp.rs 926; gitweb_worker.rs 898 | 1,824 | B |
| Hermes support | hermes_outcome.rs 136; hermes_session_verify.rs 147; hermes_room.rs 670; hermes_catalogue_probe.rs 93 (ignored test) | 1,046 | B |
| authoring and observation | grain_source.rs 117; pending_prepare.rs 395; query_observation.rs 460 | 972 | B |
| control plane | control.rs 948; terminal.rs 600; public_status.rs 23 | 1,571 | C |
| room resident | room_resident.rs 542; resident_requests.rs 660; resident_context.rs 203; resident_preflight.rs 337; resident_origin.rs 52; resident_completion.rs 939; resident_delivery.rs 1,341; resident_reconcile.rs 489; room_task.rs 447 | 5,010 | C |
| concierge | concierge.rs 757 | 757 | C |
| operator surfaces | quiescence.rs 987; quiescence_transport.rs 717 | 1,704 | C |
| host custody | systemd_manager.rs 568; cgroup_stop.rs 443 | 1,011 | C |
| tools and births | resource_tools.rs 1,579; application_tools.rs 813; application_api_tools.rs 2,764; shared_app_refs.rs 805 | 5,961 | C |
| utilities | journal_io.rs 104; controller_digest.rs 28; controller_write_scopes.rs 46 | 178 | C |
| test files | birth_lifecycle_tests.rs 143; publication_refusal_tests.rs 821 | 964 | C |
| example and fixtures (Rust) | examples/current_birth_provider.rs 278; fixture/broker-drop.rs 38 | 316 | C |
| **total** | | **55,895** | |

The three readers together cover all 53 declared modules plus the three undeclared ones (`provider_bridge` as a `[[bin]]`; `provider_choice` and `provider_homelab_tests` as `#[path]` submodules). A's "(unassigned)" list was resolved by B and C (section 9.2). Non-Rust crate content: README.md (413) and 11 prose contracts (809), 8 shell and 2 Python drivers (3,189), and 7 fixture scripts (A §1.2, §1.6; C §1.8).

### 1.3 The 25 subcommands

`main` (main.rs:17920-18238) accepts 25 argv shapes. The usage string lists 10 of them (A §1.3.11; C App. C).

| # | argv | handler module |
|---|---|---|
| 1 | `--controller-manager-protocol` | systemd_manager |
| 2 | `controller-launch CONFIG REGISTRATION` | systemd_manager |
| 3 | `controller-write-scopes [preflight\|receipt] CONFIG [REQUEST]` | controller_write_scopes -> config_migration |
| 4 | `config-migrate active\|stopped` | config_migration |
| 5 | `resident-completion plan\|receive` | resident_completion |
| 6 | `resident-delivery plan\|deliver` | resident_delivery |
| 7 | `resident-outcome` | resident_outcomes |
| 8 | `session-failure` | session_failure |
| 9 | `quiescence-transport` | quiescence_transport |
| 10 | `quiescence status\|inspect` | quiescence |
| 11 | `resident-reconcile failed` | resident_reconcile |
| 12 | `provider-provision TEMPLATE POLICY NEW` | provider_provision |
| 13 | `provider-table check` | credentials |
| 14 | `hermes-room resident CONFIG` | room_resident |
| 15 | `hermes-room step\|serve CONFIG` | hermes_room (legacy runner) |
| 16 | `concierge step\|serve CONFIG` | concierge |
| 17 | `tool-id` | (urandom) |
| 18 | `tool-result` / `tool-ack` | control |
| 19 | `tool SOCKET MODE ID NAME ARGS` | control |
| 20 | `mcp-stdio SOCKET` | mcp (+gitweb_worker), runs inside the sandbox |
| 21 | `connect SOCKET` | control |
| 22 | `terminal SOCKET [mode]` | terminal |
| 23 | `connect SOCKET MODE` | control |
| 24 | `admin SOCKET CMD` | control |
| 25 | `serve CONFIG` | everything |

### 1.4 The two binaries

* `grain-runtime`: the controller (`serve`), its clients (`connect`, `terminal`, `admin`, `tool*`), the in-sandbox MCP edge (`mcp-stdio`, copied into each worker runtime root as `/agent/grain-runtime`), and operator receivers.
* `grain-provider-bridge` (provider_bridge.rs, 296): runs inside the worker's network namespace. It binds `127.0.0.1:P`, spawns the worker, proxies Content-Length HTTP to `/run/mini-provider.sock`, and writes one ack byte once the response reaches the client. It is packaged by `deploy/candidate/package.py:64`, but **no driver has run it** (B §1.1, §5.2; A §5.2).

### 1.5 The units that run it, and why neither satisfies the controller's own checks

The controller refuses scoped work unless two conditions hold.

* `prove_controller_unit` (main.rs:17212-17240) requires that this PID is the active MainPID of exactly `mini-grain-controller@TASK.service`. `prove_prior_run_stopped` (main.rs:681-693) requires the cgroup to end in that unit.
* `systemd_manager::load` requires either a root-owned registration `/etc/mini/controllers/TASK.json` or all three of `MINI_GRAIN_CONTROLLER_MANAGER=user`, `MINI_GRAIN_WORKER_MANAGER=user` and `MINI_GRAIN_CONTROLLER_UNIT=<canonical>`. With **none** of the three variables set and no registration it returns `None` (unscoped). With **some but not all** set it is a hard error (`fixture`, systemd_manager.rs:158-183, read for this synthesis).

| unit | shape | outcome (ruling in section 9.1) |
|---|---|---|
| `deploy/grain-host/mini-grain-controller@.service` (template, "historical" per its README) | user unit, `Environment=MINI_GRAIN_CONTROLLER_UNIT=%n` only (:9) | with no registration, `Runtime::open` **fails** ("unregistered managed fixture requires …", systemd_manager.rs:173-174). A is right. |
| `deploy/grain-host/install-controller` (renders the real unit, :159-189) | same single env var (:189). The script writes no registration (no `controllers/` or registration path in it) | same failure, unless the operator writes `/etc/mini/controllers/TASK.json` by hand |
| `deploy/hermes/mini-hermes.service` (production, `User=mini`, system unit) | no env vars; unit name `mini-hermes.service` (:16, :31) | with no registration it **opens unscoped** (C's correction), and every scoped `hermes-acp` prompt then fails at `systemd_manager::current()`. With a registration, `prove_controller_unit` fails on the name. Either way no Hermes prompt can run, and `prior_run_stopped` is always false, so every restart takes the "uncertain" branch (A F3). |

The journeys pass because they launch the controller as `systemd-run --user --unit=mini-grain-controller@TASK` with all three env vars (hermes-journey.sh:211-216; A F7).

---

## 2. Subcommand and subsystem reachability

Verdict vocabulary:

| verdict | meaning |
|---|---|
| **deployed** | runs on the public node. Nothing in this crate qualifies: README row 18 "Hermes in a room: executed … off on the public node", row 17 split tenancy "compiled; run on no box". |
| **demo-needed** | on the demo-critical path, executed by a journey but not deployed |
| **wired-but-unrun** | reachable from an entry point; no driver or evidence runs it |
| **unreached** | no production entry point reaches it (test-only, or no caller) |
| **broken** | cannot work as written |
| **one-incident** | exists to repair one historical incident |

"Latest run" names the newest evidence directory a reader found; "(name)" means the reader matched the directory by name but did not open it.

### 2.1 Subcommands

| subcommand | lines (handler) | reached by | latest recorded run | verdict |
|---|---|---|---|---|
| `serve` | main.rs ~18,200 code + all siblings | every crate driver; both units (section 1.5) | 2026-09-30-hermes-participant (j3, j4); 2026-09-30-hermes-keys 13/13; 2026-10-01-hermes-tariff | demo-needed |
| `connect` (both forms) | control.rs 948 (shared) | all drivers; `deploy/grain-host/grain-ssh:19` | 2026-09-30-hermes-participant | demo-needed |
| `admin` | control.rs | acceptance.sh:737, 745; receipt-recovery-acceptance.sh:215, 222 (only `reconcile parent audited` and `reconcile effects` are exercised) | 2026-09-26-grain-* (name) | demo-needed |
| `mcp-stdio` | mcp.rs 926 (+gitweb 898) | acceptance.sh:794; inside every scoped worker | 2026-09-30-hermes-participant | demo-needed |
| `terminal` | terminal.rs 600 | none in the crate; room_resident framing | 2026-09-26-terminal-live | demo-needed if a web or terminal UI is offered, else optional |
| `--controller-manager-protocol` | systemd_manager.rs | bwrap / launch-gate probe | via hermes-journey | demo-needed |
| `controller-launch` | systemd_manager.rs:113-157 | root launcher (SYSTEMD-MANAGERS.md:64); no driver | none | wired-but-unrun |
| `provider-provision` | provider_provision.rs 228 (+provider_owner 197) | journeys/byok-native.py:251-258 | 2026-09-30-hermes-keys | executed; optional for the demo (operator can write the config) |
| `provider-table check` | credentials.rs | none | none | wired-but-unrun (trivial) |
| `tool-id` / `tool` / `tool-result` / `tool-ack` | control.rs 597-695 + main.rs 12517-13449 (933) | agent-two-participant-foreground-journey.sh | 2026-09-27 agent evidence (needs an SPK fixture outside the crate) | executed, not demo |
| `hermes-room step\|serve` (legacy runner) | hermes_room.rs ~450 of 670 | `native/resource-client/journey.d/j14.sh:197, 386, 419` | 2026-10-01-p-hermes-room: **this is README's "Hermes in a room: executed" row** | executed, but it is the twin to delete (no Authorization header, so it cannot talk to the gateway; no metering; B T6) |
| `hermes-room resident` | room_resident.rs 542 + resident_* stack | none (A's table attributes J14 to it; wrong, section 9.3) | none: docs/review/2026-10-26-deploy/AFFORDANCES.md:386 says "none" | wired-but-unrun; two permanent wedges (C-F2, C-F4) |
| `concierge step\|serve` | concierge.rs 757 | `native/resource-client/journey.d/j17.sh:168-169` | 2026-10-01-p-credit (J17 rows) | executed; money bugs (C-F1) |
| `resident-completion` / `resident-delivery` / `resident-reconcile` | 939 / 1,341 / 489 | none | none (RESIDENT-DELIVERY.md:60-62 cites an "operation396 native proof" with no evidence directory) | wired-but-unrun |
| `resident-outcome` | resident_outcomes.rs 416 | none | one historical completion (operation 78) | one-incident; also runs on every resident loop iteration |
| `session-failure` | session_failure.rs 705 | none | task8781/operation94; the "preparation helper" it relies on is absent from the tree (C-F6) | one-incident; hooks on every serve input and save |
| `quiescence` | quiescence.rs 987 | operator stack | 2026-09-26-operator-stack ("source-matched quiescence action") | executed; keep (general) |
| `quiescence-transport` | quiescence_transport.rs 717 | none | none | wired-but-unrun (one topology) |
| `config-migrate` | config_migration.rs 2,033 | none (grep over drivers, journeys, deploy, scripts) | none; the author did not run its tests (CONFIG-MIGRATION.md:136-138) | wired-but-unrun; on the hot path via `ensure_process_current` on every save |
| `controller-write-scopes` | controller_write_scopes.rs 46 -> config_migration | none | none | wired-but-unrun |

### 2.2 Major subsystems inside `serve`

| subsystem | lines | reached by | latest run | verdict |
|---|---|---|---|---|
| core transition + journal + recovery (`transition_as_with_witness`, `recover`, `startup_recovery`, `automatic_reconcile`, `retry_pending_slot`) | main.rs ~2,500 + journal_io, grain_source, query_observation, pending_prepare, cgroup_stop, systemd_manager | acceptance.sh, hermes-journey.sh (SIGKILL mid-write), policy-crash-acceptance.sh, receipt-recovery-acceptance.sh | 2026-09-30-hermes-participant | demo-needed |
| Hermes ACP driver | main.rs 14314-15261 (948) + hermes_outcome, hermes_session_verify | hermes-journey.sh (scripted ACP), byok-native.py, acceptance.sh fixture | 2026-09-30-hermes-participant | demo-needed; never run against a real model on the production unit |
| provider gateway, user route (BYOK) | main.rs 9173-10488 (1,316) + provider.rs, provider_profile, provider_history, provider_recovery, provider_retirement, credentials | journeys/byok-native.py in **host-network fixture mode** (`localFixtureHostNetwork`, `--network host`) | 2026-09-30-hermes-keys 13/13; 2026-10-01-hermes-tariff | demo-needed; executed only in fixture topology |
| provider gateway, pool route | same | no driver distinguishes it | none | wired-but-unrun; broken in practice: one non-200 response bricks the grain (B-F1) |
| private Unix gateway + `grain-provider-bridge` (`--network none`) | provider.rs Unix branch + provider_bridge.rs 296 | **none** | none; README.md:380-385 says the op17 consumer "requires a separate source-matched native run" | wired-but-unrun, demo-needed (the only production-safe topology) |
| homelab placement | homelab.rs 190 + provider.rs branches | provider_homelab_tests.rs only | none | unreached in production; B-F2 bug |
| provider custody retirements (`provider_resolution`, `provider_continuity_rejection`) | 543 + 609 | unit tests only | none | wired-but-unrun |
| MCP tools: workspace list/describe/read/propose/submit/recover/attempts/import/export/create | main.rs 11009-12219 (1,211) + mcp.rs | hermes-journey.sh (scripted ACP `@import/@write/@delegate/@export`) | 2026-09-30-hermes-participant | demo-needed |
| MCP tools: `mini_publish`, `mini_read_resource`, `mini_grain_status` | main.rs 12221-12515 + resource_tools reads (~300) | acceptance.sh:794, receipt-recovery-acceptance.sh | 2026-09-26-grain-publication-receipt-linux (name) | demo-needed |
| MCP tool `mini_create_resource` (fixed-family birth) | main.rs 10575-11007 + resource_tools births (~420) | none | "retained acceptance evidence" only | twin of `mini_workspace_create`, delete (RESOURCE-WORKSPACE-MIGRATION.md:9) |
| MCP tools `mini_create_application[_session]` (op30/31 births) | main.rs part of 10489-11007 + application_tools 813 + shared_app_refs 805 | none in the crate; examples/current_birth_provider.rs is built by no script | 2026-09-27-application-current-birth, -hosted-current-birth-9601, -shared-app-refs (names) | wired-but-unrun |
| MCP tools `mini_application_api` v2 (event21) + dispatch v2 | main.rs ~2,000 of the 5,450 dispatch lines + application_api_tools v2 half + dispatch_custody | agent-two-participant-foreground-journey.sh | 2026-09-27-agent-api-controller-v2 | executed, not demo |
| `mini_application_api` v3 "lifetime" (event26) + dispatch v3 + `__mini_gitweb_http_raw` + `mini_gitweb_read\|edit` | main.rs ~2,500 + application_api_tools v3 half + gitweb_worker 898 | none | 2026-09-27-agent-lifetime-*: these predate C-F3 and cannot describe current source | **broken**: the transport decodes v3 replies as the v1 `HostReply` enum (application_api_tools.rs:1646-1647, confirmed), and `operation_id` is read where the frame has `operationId` (:993, confirmed) |
| dispatch v1 (`Reserve`/`MarkSend`/`SettleDefinite`) | main.rs 5742-6070, 6402-6503 + v1 branches | dispatch_runtime_tests.rs (pins the weakness, B §1.4) | none; its own evidence says it "cannot authorize event21" | unreached in any journey; money hole (V5) |
| foreground tools (`tool-v1`) | main.rs 12517-13449 (933) | agent-two-participant-foreground-journey.sh; publication_refusal_tests | 2026-09-27 | executed, not demo |
| resident / room (`room_task` tools in the grain, resident admin receivers) | room_task 447 + resident stack 4,563 + main.rs hooks | none for the grain path | none | wired-but-unrun; C-F2/C-F4 wedges |
| concierge | 757 | j17 | 2026-10-01-p-credit | executed; C-F1 |
| config migration | 2,033 | none | none | wired-but-unrun |
| legacy custody audit (`reconcile tool legacy b44\|zero`) | 819 | admin only | no reconciliation recorded (`grep zero-settlement-confirmed docs` empty, B-F12) | one-incident |
| session_failure | 705 | admin + hot-path hook | none | one-incident |
| terminal | 600 | terminal subcommand, room resident | 2026-09-26-terminal-live | executed |
| quiescence | 987 | admin; config migration; every receiver | 2026-09-26-operator-stack | executed; keep |
| `verify-session` admin | hermes_session_verify ~75 | none | none | wired-but-unrun |
| `hermes_catalogue_probe` | 93 | `#[ignore]` test | asserts `deploy/hermes/runtime-inputs/probe-catalogue.py`, which does not exist | broken |
| `deploy/grain-host/probe_control.rs` (outside src) | 44 | none | does not compile: its `match` lacks `InspectAttached` and `Tool` (C §1.1) | broken |

---

## 3. Rust decides semantics, crate-wide

The table merges A's V1-V8 and §3.4, B's BV1-BV8 and §3.4, and C's C-V1-C-V8 and §3.4, deduplicated and ranked by blast radius (money first, then correctness of effects, then liveness, then cosmetics). **IS** means Rust is the decision and Lean would admit either answer. **MIRROR** means Rust pre-checks something Lean also gates; those rows are listed only where the mirror carries drift risk. The "Lean owner" column names the declaration that exists, or the one that should.

| # | decision Rust makes | sites (from the reports) | IS / MIRROR | Lean today | Lean counterpart that should own it | blast radius |
|---|---|---|---|---|---|---|
| R1 | **Every non-provider price is an operator constant, settled verbatim.** Commands, Hermes prompts, foreground tools, `mini_publish`, workspace submit, dispatch definite, room writes, `reconcile settle`. A command that exited non-zero pays the same. | V1 (main.rs:14114-14118, 14963-14971, 13121-13125, 12433-12439, 11406-11455, 6468-6474, 16418-16424, 16136-16140); C-V3 (room_task.rs:110-112) | IS | AgentGrain `settle` admits any charge ≤ the signed reservation (A Q1, unconfirmed). There is no tariff for non-provider work. | a grain work tariff in `Kernel/AgentGrain*`, priced the way `Kernel/ProviderRoute.lean` prices provider calls (main.rs:266-271 already says provider calls have "no fixed charge") | every member grain's budget, up to `reserve` per operation; the operator picks the number |
| R2 | **Refused, proven-absent and uncertain work is charged the full fee.** Workspace `native-refusal`, `absent-after-submitter-stop` and `uncertain` all settle the configured charge, and the attempt is then cleared. Room writes pay `toolTask.charge` on `paid-but-write-not-started` and on Host refusals, on top of the turn already paid. | V2 (main.rs:11451-11524, 11545; test 19986-19998 asserts `toolCharge == "1"`); C-V3 (room_task.rs:110-112, 146-149; resource_tools.rs:1218-1220) | IS | nothing; Lean sees an ordinary settle | Lean prices a refused or never-admitted operation (zero, or a declared refusal fee) | members pay for actions Mini refused, and an uncertain write is paid **and** forgotten (R7) |
| R3 | **Who pays the provider.** Table row selection: an explicit row, else "the first row listing the model", which fixes the route `user\|pool\|homelab` and the ticket. | BV1 (credentials.rs:358-368; main.rs:335-344; mini-keys server/provider.rs:123-137) | IS | `Kernel/ProviderRoute.lean:30-35`: "the controller resolves the route and the bearer together". Lean only enforces that settle charges the route recorded at reserve. | a provider-purse clause that binds the reserve's route to an operator table digest pinned in Host settings (B Q3) | reordering the table silently moves members between their own key and the pool, at the other route's tariff |
| R4 | **Member key and pool quotas.** Calls per UTC day per runner, max `max_tokens` per call, `notAfter` height, counted at ticket mint, never refunded, wall-clock day. A grant is "sufficient" only if `per_call ≥ maxOutputTokens`. | BV2 (credentials.rs:1135-1190, 677-683); BV8 (provider_owner.rs:116-118; config_migration.rs:498) | IS (physical policy unlabelled) | none; executed in the broker | either Lean-held counters on the grant resource, or an explicit "physical rate limit, not a semantic bound" label (B Q10) | a reset clock or deleted `usage.json` resets limits; refused sends burn daily calls |
| R5 | **Concierge membership-for-payment.** It checks that a payment buys a window (asset, quote within 64 heights, tariff at quote, amount ≥ week, payer standing or room open), sets `notAfter = max(local journal window, height) + period`, refunds in full, and issues free-room windows from inbox files. | C-V1 (concierge.rs:147-180, 436-474, 516-536) | IS | the delegation is admitted under the founder's grant and `validUntil` is enforced. "What the kernel does not yet check is that each delegation followed a payment (K-BOOK-SLOTS)" (concierge.rs:27-30). | a paid-slot admission: the delegate intent carries the ledger `transactionId`, and Lean checks amount, asset and tariff-at-quote and consumes the entry once (the money reader's D2, `resource-client--C-pay-credit-money.md:582-588`) | room membership for a whole room; today payments are lost or kept (C-F1) |
| R6 | **Room-turn payment sequencing.** Every room write must be preceded by one turn payment; the amount comes from the room's account fields; no `account` means "not metered"; `restrictTools:false` (the default) lets the model use generic workspace writes that bypass the turn. | C-V2 (room_task.rs:164-226; resource_tools.rs:686-701, 712-715, 1083-1085) | IS | payment and write are admitted separately; `Kernel/FleetTurn.lean:1-24` prices only the deployment base tariff and has no room `hermes/turn` notion | a joint transaction (turn payment + write) required by the room's document/stream law, or drop the word "price" (C Q1) | the founder's budget model; a prompt-injected resident writes without paying |
| R7 | **"Lookup absent + submitter stopped => the call never happened."** Workspace submit, room document writes, the legacy room runner's `say` (absent from the last 100 signed entries => refused), and its "any client error => host refusal". | V3 (main.rs:11505-11516, justified by a claim that `mini serve` "handles one connection at a time in accept order"); C-V4 (resource_tools.rs:1203-1222, room_task.rs:153); BV5 (hermes_room.rs:336-347); BV6 (hermes_room.rs:425-434) | IS | nothing certifies non-commit. main.rs itself says elsewhere that a generic lookup refusal "is not evidence that an old call could never commit" (main.rs:17060-17062). | a Lean never-admissible witness for the exact call (an expired deadline, or a consumed nonce) returned by the Host (A Q7, C Q5, B Q4) | one intent, two effects: the hold is released, the model is told "refused", and it rewrites. Run j3 shows exactly this, correct only because the first call really was absent (docs/evidence/2026-09-30-hermes-participant). |
| R8 | **`OwnManagedLaw` auto-settle.** A parent reservation still held on a shared Store is taken to be *the* reservation this controller confirmed, because the installed law equals the managed law and no attempt is pending. It is settled at `hold.charge` with no operator, automatically at startup. | V4 (main.rs:16360-16386, 16840-16847) | IS | a parent settle names no reserve receipt | settle-by-anchor: the settle names the reserve's transaction/event and Lean refuses any other (A Q14) | wrong charge against the owner's own allowance |
| R9 | **v1 dispatch trusts the SPK host for money.** The host's claimed `transaction_id`/`event_id`/`permit_sha256` is recorded without inspection, and the fixed charge is settled on its word that the response was definite. | V5 / F8 (main.rs:5950-6070, 6402-6503); pinned as expected by dispatch_runtime_tests.rs:460-469 | IS | v1 reserve is a plain grain reserve with an opaque payload | delete v1; v2 and v3 route plans through Lean inspection | any process running as `hostUid` drains the dispatch purse one fixed charge per reserve |
| R10 | **Expired-call retirement arithmetic.** `genesisHeight + checkedAcceptedCount == checkedHeight` and every `validUntil < checkedHeight` => "this contended settle can never commit", which clears `provider_pending`. Its twin lives in resource-client. | BV4 (provider_resolution.rs:121-161; resource-client provider_continuity.rs:820-823) | IS (Lean supplies the heights; Rust draws the conclusion) | op 17 reply and profile `genesisHeight` | the same never-admissible witness as R7, computed by the Host (B Q4) | a late admission would settle a hold the controller thinks unsettled; mitigated because the hold is not released |
| R11 | **Auto-acknowledging external effects.** If every unresolved note matches a string prefix (`"Hermes prompt "` matches every ACP failure) and every command has `--network none` somewhere in its argv, the notes are cleared as "derived". | A §3.4 (main.rs:670-676, 16855-16864, test 19816) | IS | none | a Lean-visible effects ledger, or keep it Rust-only but key it on a typed failure record instead of note text | an ACP fault on a mis-specified deployment is waved through without an operator |
| R12 | **Member provider/model choice and grant authenticity.** An Ed25519 signature checked in Rust; no nonce or expiry; grant expiry measured against a height the controller supplies. | BV3 (provider_choice.rs:83-142; credentials.rs:374-409, 1060-1062) | IS | op 144 owner-key currency only | a signed member intent admitted by Lean (choice as a resource or delegation) (B Q10) | a stale choice provisions a route the member no longer wants; bounded by the operator running `provider-provision` |
| R13 | **Birth quotas and namespace allocation.** `maxBirths` per family (≤1,024), an 8,192-member registry, IDs = `start + ordinal`; app/session families repeat the arithmetic. | V6 (main.rs:10706-10719; resource_tools.rs:340-350); C §3.2 (application_tools.rs:380-388) | IS (allocation) / MIRROR (tariff) | Lean authors the descriptor from the Rust source plus the Host-config tariff (Kernel/NativeHostGrainBirth.lean:48) | the factory/birth law refuses a reused ID and enforces quotas (A Q5, C Q9) | ID collision is caught only if the namespace law checks it |
| R14 | **Paid status notices.** Up to three paid turns per request (`queued`, `started`, terminal), unconditional whenever an account is configured. | C-V6 (resident_requests.rs:88-98, 157-208; room_resident.rs:247-269) | IS (policy) | each turn admitted | an operator switch; or a Lean room law | the founder's budget drains about 3x faster per request |
| R15 | **Refusal classification from another program's text.** Out-of-budget = stderr contains `bookRefused`; the first line starting `refused:`/`error:`/…; client exit 3 = Host refusal; legacy runner "out of budget" by error prefix; session_failure parses an old `Debug` rendering. | C §3.4 (resource_tools.rs:815-826, 1109, 1218); BV7 (hermes_room.rs:402-416); C-F6 (session_failure.rs:198-214) | IS (brittle physical) | typed refusal constructors exist in Lean (`refusalFrame "fleet-plan" …`, Host/Main.lean:6812-6816) | the client should emit the typed Lean refusal code and Rust should match on it (C Q4) | a client message change flips custody classification |
| R16 | **Received vs uncertain by header shape.** Header block > 32 KiB (the broker allows 64), missing or duplicate Content-Type, non-identity encoding, lease ended after a complete reply, `withheld`: a fully received response becomes `Uncertain`. | B §3.4, B-F1 (provider.rs:1555-1624) | IS (physical, but it decides custody) | none | physical; align the bounds with the broker, and make "complete but malformed" a quotable or zero-settleable state (section 4) | turns provider quirks into permanently bricked grains |
| R17 | **Resident queue admission and fairness.** FIFO per author, round-robin by author string order, 64 pending / 8 per author / 16 MiB, overflow refused with an immutable outcome. | C-V5 (resident_requests.rs:257-342) | IS (scheduling) | none | acceptable in Rust if labelled operator policy (RESIDENT-REQUESTS.md:15-23 does) | fairness only |
| R18 | **"Failed / completed / review-needed" from journal markers.** A presentation label is used by `resident_reconcile` to clear custody. | C-V8 (terminal.rs:18-122; resident_reconcile.rs:126-136) | IS | none | a controller-written typed per-prompt outcome record (C §3, question 3) | an operator can clear `resident.json.pending` on a label (with fresh quiescence) |
| R19 | **Deliverable final.** ACP `stopReason == "end_turn"` stages delivery; the resident additionally requires an SSE final with `finish_reason:"stop"` and ≤ 3,000 bytes equal to the ACP capture. | V8 (main.rs:14977-14983); C-V7 (resident_delivery.rs:71-143, 520-522) | IS (agent protocol) | the final `mini_say` is admitted natively | acceptable in Rust (agent-protocol semantics) | a truncated turn is delivered (V8), or a valid one is never delivered and wedges the resident (C-F2) |
| R20 | **Per-prompt provider request budget.** `maxIterations` ≤ 6, counted before the attempt, never restored. | V7 (main.rs:9307-9312, 9483-9485) | IS (physical bound) | none | acceptable if labelled physical | a prompt is cut short; no money moves |
| R21 | **Grain status codes as 62 magic strings.** "0" through "7" branched on throughout; quiescence's "unreserved boundary" = status {0,1,2,6} with reserved 0. | A §1.3.3, §3.4; C §3.2 (quiescence.rs:166-171) | MIRROR with drift risk | the AgentGrain status type (not imported) | export the enum through the host-operations registry or a Lean-emitted constant table (A Q8, C Q8) | a Lean renumbering silently changes about 60 branches |
| R22 | **Which tools exist and their argument syntax** (the MCP table and a 380-line foreground preflight duplicating it). | A (main.rs:12221-12514, 12520-12898) | MIRROR | every effect is a signed intent admitted against capabilities | fine as a mirror; collapse to one validator per tool | none beyond UX |
| R23 | **Provider quote validation and pre-reserve maximum charge.** | A §3.2 (main.rs:1701-1842, 9445-9458); B §3.2 (provider.rs:614-735) | MIRROR | `ProviderUsage.quotePayload` (Host/ProviderUsage.lean:264-284, 295-313) authors the report | whether the token ceilings are enforced in Lean or only in Rust is open (A Q12) | if the ceilings are Rust-only, an over-ceiling quote is refused locally only |
| R24 | **Which config fields may change without reprovisioning** (`permitted_diff`). | B §3.2 (config_migration.rs:549-668) | MIRROR (local binding only) | every later effect is still admitted | none needed; delete with config migration (section 6) | none |

**Reading of the table.** R1-R6 together mean that the grain's economy (what a turn, a command, a refusal, a room write and a membership cost, and who pays the model) is authored in Rust and operator JSON, not Lean. That directly contradicts README's "Rust decides nothing semantic". R7 and R10 are one missing Lean concept, a **never-admissible witness for a retained exact call**; three Rust implementations approximate it, and one (V3) rests on a claim about the Host server's connection discipline. R8 is one missing Lean form, **settle-by-anchor**. R9 is deletable today.

---

## 4. The lost-reply / retry contract as it exists

### 4.1 The custody envelope the controller does apply

The readers agree this envelope is real and carefully built (A §3.3, B §3.3, C §3.3):

1. **Journal before effect.** `transition_as_with_witness` writes `source-N.json` with `write_new`, journals `Pending{attempt}` and the hold's `reserve_attempt`, saves, and only then runs `mini submit` (main.rs:8262-8318). Child markers (`pid:0`) are durable before spawn (main.rs:14033-14043, 14636-14644). Foreground tombstones are durable before reserve (main.rs:13019-13040). The birth no-submit marker is durable before attach (main.rs:10725-10733). Resident prompts get `resident-entered-ID.json` before any reserve (resident_preflight.rs:137-148). Room payments and writes record an operation id first (room_task.rs:178-183; resident_delivery.rs:883-904).
2. **Lookup, never resubmit.** An unresolved call is only ever looked up with `mini retry --mode lookup` (main.rs:16986-17173). A test checks that `call.bin` does not change across relookups (main.rs:20029-20045). Room payments are looked up by exact operation record and never re-paid (room_task.rs:123-158). The one re-submission, `pending_prepare`, re-prepares a parent settle only after proving no `call.bin` exists anywhere in the ancestry and the controller cgroup is sole member (pending_prepare.rs:128-265). Its safety depends on Lean nonce replay protection (B Q6).
3. **Provider outcome before worker ack.** The gateway reports `Outcome`. `provider_record_outcome` writes `provider-N.controller-outcome` and headers with fsync and saves the journal **before** the reply channel acknowledges (main.rs:9958-10004). The Lean quote is fetched and journaled next. `Delivery` then records a replay entry only after a successful local write (main.rs:10300-10411), and only then is settlement attempted. A crash between answer and delivery leaves the purse held for an audited, Lean-quoted settlement. The HTTP request is never re-sent (A §"seven questions" (3)).
4. **Send-boundary linearization.** `send_started` is set durably only after `mini continuity` (op 17) confirms the reserve anchor (main.rs:9723-9899). Broker connect + frame send happen inside the lease lock that `revoke` also takes (provider.rs:1486-1505, 304-316). `NotSent` is reported only when nothing left the process (provider.rs:1451-1540).
5. **Same-bytes replay inside one prompt.** A 16-entry per-prompt cache serves an SDK retry of identical bytes after delivery, and a retry before delivery is refused (main.rs:9371-9384, 10386-10409). The 16 bound is unreachable because `maxIterations` ≤ 6 (B-F19).
6. **Retirements never release a hold.** Every provider retirement record carries `heldAllowanceReleased:false` (B §3.3).
7. **App-API first-byte gate.** `BeforeSend` vs `Uncertain` is decided by a gate shared with hard interrupt, and the call is never retried (application_api_tools.rs:1164-1245, 1592-1622).

### 4.2 Every hole

Four kinds: **dead** states (custody held with no exit), **false-refusal** states (one intent, two effects), **lost money**, and **wedges** (liveness lost without money moving).

| # | hole | kind | how it arises | why nothing exits | source |
|---|---|---|---|---|---|
| H1 | uncertain provider send | dead | upstream stalls past `timeoutSeconds` (≤ 600 s; the gateway does not stream, so an 8,192-token answer at 10 tok/s takes 819 s), broker closes, lease revoked mid-wait | `metered_audit_path` accepts only proven-no-send or complete `received:`; `abort` refuses once `send_started`; `retire` needs `!send_started && outcome == None`. `attach`, `hermes`, `run`, `acknowledge_effects` and `provider_reserve` all refuse while `provider_attempt` is retained. | A F1 (main.rs:1586-1596, 16687-16689, 13547-13549, 14374-14376, 13958-13960, 16889-16890, 9371-9376); B-F5 |
| H2 | crash after the send boundary, before any outcome | dead | SIGKILL between `send_started=true` (main.rs:9788-9789) and the outcome | the same as H1. Restart notes "crossed durable send boundary" and stops there. | A F1 scenario B |
| H3 | **received but malformed** | dead | headers 32-64 KiB, no/duplicate Content-Type, non-identity encoding, folded headers, > 8 blocks, lease ended after a complete fsynced reply, curl `complete:false`, response echoed the bearer (`withheld`) | each becomes `Uncertain` (11 sites, B App. A), hence H1 | B-F1 (provider.rs:1541-1624; mini-keys server/provider.rs:29, 296-304) |
| H4 | **non-200 metered reply** (pool, homelab) | dead | 429 rate limit, 400 context too long | `quoteResponse` throws "provider HTTP status is not 200" (Host/ProviderUsage.lean:267-268), and `reconcile provider audited` re-quotes through the same function. **One 429 bricks a pool-route grain.** The user route is unaffected: its quote ignores status and charges the per-op fee. | B-F1 (main.rs:9226-9243, 16498-16516) |
| H5 | homelab endpoint mismatch after the send boundary | dead (nothing was sent) | provider.rs:1073-1076 writes 503 and returns without `report_outcome`, leaving `send_started && outcome == None`. The homelab guard drops as `NotSent`, so the scheduler frees the slot while the controller is wedged. | as H2 | B-F2 |
| H6 | 503 exits with a confirmed reserve and no outcome | operator-only | permit mismatch, permit replay, `Reserve` reply lost after the controller reserved (provider.rs:995-1001, 1032-1051). Also: `report_outcome` gives up after 30 s for non-`Received` outcomes, so a controller blocked by H12 never journals them. The last case is **dead** (`send_started && outcome == None`). | `metered_audit_path` classifies the first three as `ProvenNoSend`, so `reconcile provider audited` works, but nothing automatic does | B-F3 |
| H7 | absent => refused => the model repeats the write | false-refusal | workspace submit `absent + submitter stopped` is recorded refused and the hold released; `absent` without that proof is recorded `uncertain` **but still settled at full charge and the attempt cleared**, after which `tool_call` admits new tools | R7. Because the production unit name defeats `prior_run_stopped` (section 1.5), the "uncertain + cleared" branch is the norm after restarts. | A F3/V3 (main.rs:11509-11568, 12251-12261); C-V4 (room document writes) |
| H8 | legacy room runner (`hermes_room`) | false-refusal | a `say` absent from the last 100 entries is recorded refused (BV5); any `RoomTools::write` error is recorded `host-refusal` (BV6); `deciding` without `paid` becomes `uncertain` at restart | the model sees an error and writes again | B-F7 |
| H9 | GitWeb edit at the agent level | false-refusal | an edit that fails after its receive-pack POST was settled returns an error, and the model calls `mini_gitweb_edit` again, cloning fresh and pushing a new commit | the app-API attempt is settled, so no custody blocks the second call (moot today: v3 is dead, C-F3) | B-F9 |
| H10 | **concierge: same-height payments** | lost money | the decision key is `ledger:HEIGHT`; a second `renew` payment at the same height is skipped forever, neither honoured nor refunded. Proposal id `renew-h{H}` and refund memo collide the same way. | the Lean ledger carries `transactionId`; Rust keys on height | C-F1.1 (concierge.rs:389-392, 459, 401) |
| H11 | **concierge: failed refunds never retried** | lost money | a failed `credit --action refund` is journaled as final `refund-failed`. Conversely, `refunding` is write-only, so a refund the bounded poll does not show is sent twice. Windows come from the local journal, not the Host grant view. | design | C-F1.2-4 (concierge.rs:451-455, 229-247, 209-211, 405, 437) |
| H12 | unbounded blocking subprocesses | wedge (and feeds H6) | `command_output` / `Command::output()` with no timeout for every non-work transition, every lookup, `mini profile/continuity/meter`, room tools, operator-status, journalctl. `CustodyGate` is cancel-only (hard EOF), not a timeout. | systemd sees a live MainPID; the admin socket is serviced by the same blocked loop, so the operator cannot reconcile | A F2; B-F6; C-F9 |
| H13 | **resident wedge 1: failed admitted prompt** | wedge | an admitted resident prompt ends without `end_turn`; `resident-reconcile failed` clears `pending`; `resident_requests::reconcile` then demands a delivered or final-refused receipt that can never exist | no `failed` request status, no closing receiver; `select` refuses while a request is started. The room's Hermes is dead until `requests.json` is hand-edited. | C-F2 (resident_requests.rs:420-430, 272; room_resident.rs:306) |
| H14 | **resident wedge 2: admin reply bound** | wedge | `resident delivery-plan` embeds the requester's text (≤ 12,000 B) and the final twice; the admin reply is written unbounded but read with a 16 KiB line bound | `drain_completed` fails at every start. Any member can trigger it with one long question. | C-F4 (control.rs:146, 149-158; resident_delivery.rs:655-658) |
| H15 | partial `write_new` | wedge | a crash or ENOSPC mid-write leaves a partial file; `retain_exact_private` refuses forever | by design, but there is no receiver to inspect and clear it | C-F12 (main.rs:2269-2297) |
| H16 | session-failure freeze | wedge | `failed-session-publication-uncertain.json` freezes all mutation and "this command supplies no generic reset" | one-incident code on the hot path | C-F5 (SESSION-FAILURE.md:103-105; main.rs:17597-17599, 6916-6918) |
| H17 | Hermes turn lost on a provider crash | accepted loss | after a crash between provider answer and delivery the request is not re-sent (correct), but the worker is gone and the turn is lost | design; the member re-prompts | A (3) |

### 4.3 The one contract the crate should have

> **Every native or external effect the controller starts ends in exactly one of three Lean-recognised terminal states, each reachable by a typed transition: `performed` (a receipt), `never-admitted` (a Lean witness that the exact retained call can no longer be admitted), or `settled-uncertain` (a Lean-admitted settle at a Lean-declared charge with the retained evidence bytes as its argument). Rust journals before it starts anything, only ever looks up after a lost reply, and never infers any of the three states from local facts (process liveness, string matching, ledger heights, header shapes).**

What that contract changes, row by row:

* H1-H6: one Lean transition, **settle-uncertain-provider**. For a held provider purse with `send_started` and evidence `(retained request, partial or complete response or none, reason)`, it admits a settle at a Lean-declared charge: the per-op fee on the user route, a declared "uncertain" charge or the hold on metered routes, or zero when Lean can see the call never left. `Kernel/ProviderRoute.lean:25-28` already allows "a metered call nothing or at least its fee". H5 is also a plain bug: move the endpoint check before `BeforeSend`, or report `NotSent`. H3 also needs the gateway and broker header bounds aligned (32 vs 64 KiB).
* H7, H8, H10 (`provider_resolution`): a Host-returned **never-admissible witness** replaces `absent-after-submitter-stop`, `said_already` and the expiry arithmetic. Until it exists, "absent" must stay `uncertain`, keep the hold, and block the tool. That costs liveness, not double effects. R2's full-fee settle of uncertain work goes away with it.
* H10, H11: the concierge keys on `transactionId`. Its refund is an exact-lookup operation with an operation record, like room payments. Membership-for-payment moves into the paid-slot admission (R5).
* H12: every subprocess gets a wall-clock deadline, and a timeout is classified like a lost reply (uncertain, lookup later). The admin socket must not share the blocked loop for read-only inspection.
* H13, H16 (and R11, R18): one controller-written typed **per-prompt outcome record** (`completed` / `failed-after-admission` / `review-needed`), written at the moment of failure. It is the only input to `resident_reconcile`, to the request queue's terminal status, and to effects acknowledgement (replacing R11's prefix match). It retires `session_failure.rs` and `resident_outcomes.rs`.
* H14: a length-prefixed admin protocol (or a read bound equal to the write), and no requester text in the plan.

The Lean questions this contract depends on (numbers refer to section 8): Q2 held-reservation expiry or an uncertain settle; Q3 a complete-but-unquotable metered settle; Q4 absent-then-admitted serialisation; Q5 a never-admissible witness; Q6 settle-by-anchor; Q15 nonce replay; Q20 paid-slot admission and ledger identity.

---

## 5. Twins and dead code census

Line counts come from the reports' `wc -l` figures or cited ranges. "Delete" names the copy that goes; "keep" names the survivor.

### 5.1 Versioned generations

| twin | sites and lines | reachable | keep / delete |
|---|---|---|---|
| dispatch purse custody v1 / v2 / v3 | main.rs 3534-6797 (3,264), plus app-API caller 8494-9172 (705), restart recovery 15262-15734 (473), dispatch audit 16091-16239 (149), records 1255-1596 (342), validation ~190, dispatch parts of `recover` ~185, `fence_dispatch` 61. **About 5,450 lines, 30% of main.rs code.** Eight v1/v2/v3 pairs inside it total **about 2,000 duplicate lines**: reserve (5742-5949 / 4652-5040 / 4179-4646), fixed-request verification (3997-4076 / 4083-4173, the same 17-field template twice), inspect (5042-5123 / 5125-5241), sign-payer (5474-5740 / 5246-5468), mark-send (5953-6070 / 6073-6398), reserve-hold verification (three branches of 3658-3992), restart recovery (15262-15522 / 15524-15734), forward begin and poll (8494-8644 / 8646-8717; 8954-9096 / 8719-8925) | v1: no journey; v2: 09-27 journey; v3: broken (C-F3) | delete v1 now (R9). v3 is dead, so either fix C-F3 and delete v2, or delete v3 and keep v2. For a demo without SPK dispatch, delete all of it (section 6). |
| app-API v2 / v3 in application_api_tools.rs (2,764) | route types `RoutePin`+`validate_routes` (251-270, 1092-1162) vs `LifetimeRoutePin`+`validate_lifetime_routes` (300-328, 806-909); wire `hello/dispatch/inspect` (74-76, 144-166) vs `hello-v3/dispatch-v3` (78-80, 128-142); `HostReply` (505-545) vs untyped v3 JSON in main.rs; fingerprints v1 (561-596) vs v3 (387-470); v3 reserve/paid comparators (917-1090). About 400 v3-only code lines plus their tests. | v2 live, v3 dead | one generation. The wire also exists a second time in spk-host (`agent_api_wire.rs`, `agent_api_lifetime_wire_v3.rs`); the two sides already disagree. Move the shared wire into `native/spk-rpc` (C §5.3). |
| dispatch RPC enum | dispatch_custody.rs 23-99: v1 `reserve/mark-send/settle-definite/abort-no-send/inspect`, v2 3 verbs, v3 5 verbs | all decoded | with the above |
| member grants v1 / v2; `authorize` / `authorize_model` / `authorize_model_epoch` | credentials.rs 47-48, 853-886, 993-1071 | both | v2 and one entry point, in mini-keys (B §5.5) |
| operation identity: legacy local counter vs namespaced SHA id | grain_source.rs 34-55 | both accepted | namespaced, after a journal migration |
| fence indexing: indexed vs legacy 4,096-dir scan | provider_history.rs 247-357 (~110) | both | indexed |
| resident assignment preamble current / historical; final provenance current / historical; legacy append proof via `mini operation-proof` | resident_delivery.rs 6, 194-222, 300-303, 535-540, 702-751 (~250) | both | current |
| controller client upgrade admission `compatibleAdmission` / `miniAdmission` | config_migration.rs 21-24, 627-666 | both | moot if config migration goes |
| legacy journal shapes | `work_origin: None` = Hermes (main.rs:792-798), `no_native_submit` default (1010-1013), legacy provider metering scalar refused by name (358-360) | all | after a typed journal migration (~50) |

### 5.2 Same thing implemented more than once

| twin | copies (sites) | count | keep |
|---|---|---|---|
| birth planners | fixed-family `mini_create_resource` (main.rs 10575-11007; resource_tools.rs 261-438) vs `mini_workspace_create` (main.rs 11879-12009). RESOURCE-WORKSPACE-MIGRATION.md:9 names the twin and its deletion bar. Separately, application_tools.rs 133-152, 234-388, 418-482 repeats resource_tools' namespace arithmetic for app/session families. | 2 (+1 namespace planner) | workspace create; one `Namespace` + `plan_birth(shape)` |
| legacy one-resource birth vs application bundle birth | `BirthPending.route == None` vs `Some` (main.rs 765-1003, 7063-7184) | 2 | bundle |
| Hermes drivers | ACP driver (main.rs 14314-15261, 948) vs legacy chat-completions runner (hermes_room.rs 236-505, 558-600, ~450). The legacy one has no Authorization header, no metering, success detected by `contains(" 200 ")`. | 2 | ACP; keep only `prepare_resident` (hermes_room.rs 507-556) if rooms stay |
| room-write executors | room_task.rs (exact operation records, ToolTask purse) vs hermes_room.rs write path (signed-tail matching; room_task.rs:123-126 calls that "NOT an operation identity"). `RoomTools::write` and `notice` serve only the legacy runner (resource_tools.rs 1124-1126, 1254-1257). | 2 | room_task |
| `resident.json` schema | room_resident.rs 32-43; resident_reconcile.rs 8-19; quiescence.rs 353-365 | 3 | one `resident_state.rs` |
| resident origin structs | resident_origin.rs 3-10; resident_reconcile.rs 54-56; room_resident.rs 212-219 | 3 | resident_origin |
| "closed boundary / settled" predicate | resident_reconcile.rs 156-171; resident_completion.rs 254-287; session_failure.rs 229-248; resident_delivery.rs 844-857; resident_outcomes.rs 239-245 | 5 | `Status::closed_except(&[markers], allow_stale_fingerprint)` |
| "is any custody unresolved" walls in main.rs | `needs_startup_recovery` 16785-16806 + about 10 hand-written variants (12974-13001, 13480-13500, 13539-13556, 13949-13966, 14365-14382, 16258-16272, 16882-16901, 13298-13317, 16665-16674, 16747-16759) | ~11 | one predicate family, ideally the quiescence inventory |
| status projection | terminal.rs 18-85 (15 keys; misses resident, workspace, birth and app-API markers) vs quiescence.rs 173-267 (complete) | 2 | quiescence, projected |
| journal write paths | `Runtime::save` -> `atomic_json` -> `journal_io::write` (main.rs 6916-6919); `atomic_json` direct (session_failure.rs 490); `config_migration::publish_bytes` with deterministic tmp name and plain rename (resident_completion.rs 548-557) | 3 | `journal_io::write` |
| tool-purse lifecycle | `reserve_tool_operation` + `finish_tool_operation` (main.rs 11160-11233) vs hand-rolled copies in `create_resource`, `workspace_create`, `mini_publish`, `workspace_recover_birth` | 5 | the helper |
| connector input pump | main.rs 13388-13446, 14126-14197, 15096-15167 (~180) | 3 | one function |
| tool argument validation | `preflight_foreground_arguments` (main.rs 12520-12898, ~380) vs the per-tool checks | 2 | one validator per tool |
| flock-transfer drain | resident_completion.rs 611-648 vs resident_delivery.rs 942-986 | 2 | one |
| retained-source re-derivation validators | provider_history.rs 50-106; provider_continuity_rejection.rs 207-292; pending_prepare.rs 26-93 | 3 | one `verify_retained_source` |
| "sender stopped" proofs | legacy_custody_audit.rs 166-268 (procfs argv scan, "not a proof"); hermes_room.rs 249-257 (cmdline contains `shell`); `prove_prior_run_stopped` + cgroup_stop | 3 | the cgroup proof |
| expiry arithmetic | provider_resolution.rs 121-161 vs resource-client provider_continuity.rs 820-823 | 2 (cross-crate) | one, on the Lean side (R10) |
| bounded / owned file readers | provider_resolution.rs 37-64; provider_continuity_rejection.rs 61-83; legacy_custody_audit.rs 91-117; config_migration.rs 100-113; provider.rs 1292-1303; credentials.rs 550-560 and 643-655; main.rs `bounded_regular_file`, `retained_exact`; resident_outcomes.rs 52-89; session_failure.rs 57-84; quiescence_transport.rs 87-110; resident_reconcile.rs 185-207 | **13** (the brief said 8; B and C together list 13) | one `custody_read(path, OwnerRule, ModeRule, bound)` |
| hex encode/decode | credentials.rs 657-675; gitweb_worker.rs 82-109; dispatch_custody.rs 369-386; provider_profile.rs 59-64; provider.rs 1397-1399 (delegates); application_api_tools.rs 64-72, 96-107, 771-789, 1733-1754; controller_digest.rs 6; shared_app_refs.rs 64-68 | ~8 in-crate (+ mini-keys `wire::hex`) | `mini_keys::wire::{hex, unhex}`, already a dependency |
| SHA-256 helpers | provider_provision.rs 5-11; config_migration.rs 89-94; grain_source.rs 4-12; main.rs `sha256_bytes`/`sha256_file`; controller_digest.rs; direct `sha2` in application_api_tools.rs and shared_app_refs.rs | 4+ | controller_digest |
| canonical-JSON SHA helpers | resident_outcomes.rs 48-51; session_failure.rs 53-56; quiescence_transport.rs 77-80; resident_delivery.rs 46-48; resident_completion.rs 78-80; resident_requests.rs 42-44; resident_reconcile.rs 67-69 | 7 | one |
| 64-hex validators | resident_origin.rs 11-13; resident_reconcile.rs 71-76; quiescence_transport.rs 81-86; shared_app_refs.rs 161-166; application_api_tools.rs 554-559 | 5 | one |
| hand-written HTTP/1.1 parsers | provider.rs 742-847 (request), 1305-1395 (response headers); provider_bridge.rs 33-166; gitweb_worker.rs 127-250; hermes_room.rs 190-223 | 5 | one bounded Content-Length parser with per-use policy |
| last-JSON-of-stdout parsers | resource_tools.rs 865-874; concierge.rs 304-315 | 2 | one |
| stale socket handling | provider.rs 406-431; main.rs `clear_stale_control_socket` | 2 | one |
| owner-key currency check | provider_owner.rs 27-81 vs mini-keys server/provider.rs 83-91 | 2 (cross-crate) | the broker's |
| binding fingerprint | grain-runtime and spk-host each recompute (application_api_tools.rs 387-421, 2285-2306 "golden vector") | 2 (cross-crate) | shared crate |

### 5.3 One-incident handlers

| file | lines | the incident | hot-path cost |
|---|---|---|---|
| legacy_custody_audit.rs | 819 | operation 44, prompt 36, tasks 7803/7804, 13 pinned SHA-256s (legacy_custody_audit.rs:16-36, 275-298); no evidence that the reconciliation ever happened | `zero_phase_active` consulted at main.rs:16255 |
| session_failure.rs | 705 | task8781 / operation94 / invocation c2fdf82e (SESSION-FAILURE.md:96-98); scrapes `journalctl --user` for an old `Debug` string; the doc's "preparation helper" is not in the tree | `ensure_publication_known` on **every** serve-loop input and every save (main.rs:17597-17599, 6916-6918); a freeze with no reset |
| resident_outcomes.rs | 416 | one historical completion, `historicalOperationId:78` (RESIDENT-OUTCOMES.md:20-27) | `qualified_count` re-hashes every correction file on every resident loop (room_resident.rs:308, 345, 350) |
| **total** | **1,940** | | |

### 5.4 Built, unrun or broken

| item | lines | state |
|---|---|---|
| config_migration.rs | 2,033 | migrates three provider throttles, one owner key and transport fields; no driver runs it; its author staged the tests without running them (CONFIG-MIGRATION.md:136-138). `ensure_process_current` runs on every save and serve input. It exists only because the journal binds the exact config. |
| controller_write_scopes.rs | 46 | delegates to config_migration; no driver |
| quiescence_transport.rs | 717 | one-topology upgrade surface; no run |
| hermes_catalogue_probe.rs | 93 | `#[ignore]`; asserts a script (`deploy/hermes/runtime-inputs/probe-catalogue.py`) that does not exist |
| `deploy/grain-host/probe_control.rs` | 44 | no longer compiles against `control::Event` (missing `InspectAttached`, `Tool`; E0004) |
| examples/current_birth_provider.rs | 278 | no script builds or runs it |
| provider_resolution.rs, provider_continuity_rejection.rs | 543 + 609 | unit-tested only |
| v3 app-API + `__mini_gitweb_http_raw` + gitweb tools | ~2,500 in main.rs + ~400 in application_api_tools + gitweb_worker 898 | broken (C-F3, confirmed at application_api_tools.rs:1646-1647 and :993) |
| `resident_preflight::{Ready, checked}` | ~26 | dead in non-test builds |
| `GatewayConfig.max_output_tokens == None` branch; replay bound 16 | small | test-only / unreachable (B §5.2, B-F19) |
| `verify-session` admin command | ~75 | no driver |

### 5.5 Misplacement and literals

* **credentials.rs (1,888) belongs in mini-keys.** It is compiled by `#[path]` into three crates, each with `#[allow(dead_code)]`: grain-runtime main.rs:34, `native/resource-client/src/keys.rs:35` and `native/mini-keys/src/server/mod.rs:20` (all three confirmed). Its ~700-line sealed `CredentialStore` executes only in the broker. Its doc still says "one source, two consumers" and "the controller resolves a route and a credential at provider-reserve time". `CredentialStore.key` is not zeroed on drop, and `count_call`'s lock file is opened without `O_NOFOLLOW` (B-F15).
* **62 magic grain status strings** (`grep -c 'grain/status'` in main.rs) interpret an AgentGrain enum that Rust does not import (R21). The readers even disagree on what status 2 means (section 9.6).
* **Hard-coded room and client literals.** The room's `hermes/turn` account field, the `ROOM-hermes` account convention and `restrictTools` default false (resource_tools.rs:686-716); the stderr substring `bookRefused` (:1109); first-line prefixes `refused:`/`error:`/`usage:`/`undecided:`/`not here:` (:815-826); exit code 3 = Host refusal (:1218); worker unit name `mini-grain-t{task}-o{op}.service` re-derived in session_failure.rs:142-145; Hermes failure note prefix `"Hermes prompt "` as an auto-ack key (main.rs:670-676); payload label strings as recovery discriminators (provider_history.rs:72-75, provider_continuity_rejection.rs:239-244). Each couples controller custody to another program's human-readable output (R15).
* **Prose contracts that are diaries.** RESOURCE-WORKSPACE-EVIDENCE-2026-09-28.md is a dated partial run living beside the specs. README.md cites specific historical runs in present tense (A §1.2).
* **Crate-local `target/` (2.9 GB) and driver defaults** pointing at `$HERE/target/...` are leftovers of a pre-workspace layout. The crate is a root-workspace member with no `[workspace]` table or `Cargo.lock` (A §1.1, F13).

---

## 6. Size and shape

### 6.1 Lines by family, and tests vs code

The family table in section 1.2 sums to 55,895. Test share, by shard:

| shard | src lines | test lines | share | character of the tests |
|---|---|---|---|---|
| A (main.rs) | 20,075 | 1,836 (44 `#[test]`) | **9.1%** | pure-function tests with teeth (quote validation, tariff, route pins, ACP frame bound); fake-`mini` shell fixtures for restart bookkeeping; physical process-group tests |
| B | 17,227 | 6,240 (136) | **36.2%** | real gateway + real broker + real scheduler + fake upstream; shell stand-ins for `mini`/Host elsewhere |
| C | 18,277 | 5,913 (212) | **32.4%** | strong pure tests (SSE final, render_untrusted, cgroup races, queue fairness); shell fixtures for Mini |
| **crate** | **55,579** (+316 example/fixture) | **13,989 (392)** | **25.2%** | |

No reader found a tautological test. All three note the same limit: the tests check the controller's bookkeeping against a **fixture's model of Mini**, never Lean's admission. Two tests pin a weakness as expected behaviour: the v1 dispatch test accepts arbitrary SPK strings (dispatch_runtime_tests.rs:460-469), and a restart test asserts the absent-lookup full charge (main.rs:19996). The v3 tests mask C-F3 by bypassing the transport and building frames with the v1 builder.

Why it is this large, in one line per cause:

* every feature landed in main.rs with its own copy of the custody envelope (retain, journal, query, compare, submit, classify, look up, reconcile), and old generations stayed beside new ones (A §6.2);
* every resident receiver re-implements the same envelope a further time (C §6.2);
* history is kept in the product: three one-incident receivers, legacy preambles and journal shapes;
* the SPK application API exists in three generations, on both sides of a socket.

### 6.2 The demo-minimal controller

**Demo scope** (A §6.3, B §6.3, C §6.3 scenario A, reconciled): one controller per member grain; Hermes prompts through the gateway on the **BYOK `user` route only** (the pool route bricks on a 429, H4); the private Unix gateway + `grain-provider-bridge` with `--network none`; MCP workspace tools plus `mini_publish`/`mini_read_resource`/`mini_grain_status`; hard/soft attach over `connect`/`grain-ssh` (and `terminal` if a terminal UI is offered); restart recovery and the admin reconcile verbs; the scoped bwrap worker. **Not** in scope: SPK dispatch, foreground tools, app/session births, fixed-family births, homelab, GitWeb, config migration, provisioning (the operator writes the controller config), rooms, resident, concierge.

#### main.rs (A's list, plus the hooks of things B and C drop)

| drop from main.rs | lines |
|---|---|
| dispatch purse custody v1/v2/v3 + rpc (3534-6797) | 3,264 |
| dispatch/app-API records, lifetime reply checks, `DispatchTask`, signer pins, dispatch validation | ~560 |
| app-API caller v2 + lifetime (8494-9172) | ~680 |
| foreground tools + foreground pump (12517-13449) | 933 |
| v2/v3 dispatch reserve recovery, dispatch parts of `recover`, `fence_dispatch`, dispatch audit | ~870 |
| fixed-family and app/session birth, its receipt reconstruction and records | ~1,100 |
| birth/app/shared parts of the tool catalog and `tool_call`; legacy shapes and legacy admin verbs | ~200 |
| room tools in `tool_call`/catalog, room recovery, resident parts of `hermes_session`, 13 resident/session/quiescence-transport/migration admin arms, 11 subcommand arms (17938-18032), `ensure_process_current`/`ensure_publication_known` hooks, resident journal fields | ~400 (synthesizer's estimate from the ranges A and C cite) |
| dedupe: input pumps, unresolved-custody walls, tool-purse cycle, preflight remnants | ~500 (rewritten, not dropped) |
| **total** | **~8,500** -> about 11,600 lines remain |

#### Sibling files

| group | files (lines) | subtotal |
|---|---|---|
| SPK app API, dispatch, shared apps, GitWeb | application_api_tools 2,764; dispatch_custody 476; dispatch_runtime_tests 643; shared_app_refs 805; application_tools 813; gitweb_worker 898; examples/current_birth_provider 278 | 6,677 |
| fixed-family birth twin and room tools | birth_lifecycle_tests 143; resource_tools births + room tools ~1,280 (reads stay) | ~1,423 |
| homelab | homelab 190; provider_homelab_tests 506 | 696 |
| one-incident receivers | legacy_custody_audit 819; session_failure 705; resident_outcomes 416 | 1,940 |
| config migration | config_migration 2,033; controller_write_scopes 46 | 2,079 |
| provisioning | provider_provision 228; provider_owner 197 | 425 |
| deferred provider retirements (their states fall to `reconcile provider audited`) | provider_resolution 543; provider_continuity_rejection 609 | 1,152 |
| rooms, resident, concierge | resident stack + room_task 5,010; concierge 757; quiescence_transport 717; hermes_room 670 | 7,154 |
| broken | hermes_catalogue_probe 93 | 93 |
| **deleted from the crate** | | **~21,640** |
| **moved to mini-keys** | `CredentialStore`, `Secret`, sealing, grants persistence and their tests (~700 code + ~550 test of credentials.rs) | **~1,250** |

**Reconciled number:** 55,895 − 8,500 (main.rs) − 21,640 (siblings deleted) − 1,250 (moved) ≈ **24,500 lines remain**: about 11,600 in main.rs and 12,900 in siblings. The survivors are provider.rs (minus homelab branches), provider_bridge, provider_profile, provider_history, provider_recovery, provider_retirement, the slim credentials table/choice part (~450), custody_gate, mcp.rs (minus the gitweb branch), hermes_outcome, hermes_session_verify (`Invocation`), grain_source, pending_prepare, query_observation, control, terminal, public_status, systemd_manager, cgroup_stop, journal_io, controller_digest, quiescence (minus resident evidence), resource_tools reads, publication_refusal_tests and fixture/broker-drop.

How the three readers' numbers fit together:

* **A** dropped 8,100 of main.rs + 7,551 of siblings = 15,650. Its demo kept config migration, the one-incident receivers and rooms because they were outside its shard.
* **B** dropped 6,083 + deferred 1,600 + moved 1,300 within its shard (8,983).
* **C** dropped about 13,490 for no rooms.
* A's sibling list overlaps B's by 3,026 lines (dispatch_custody, dispatch_runtime_tests, gitweb_worker, legacy_custody_audit, homelab) and C's by 4,525 (application_api_tools, application_tools, shared_app_refs, birth_lifecycle_tests). The union is 15,650 + 8,983 + 13,490 − 7,551 ≈ 30,570 deleted or moved.
* This synthesis gets 31,390. The ~800 difference is the main.rs hooks for rooms, resident and migration that A did not count (~400), the whole of hermes_room (670) instead of B's legacy-runner part (~450) once rooms go, and C's resource_tools rounding.

**With a room resident in the demo** (C scenario B), add back the resident stack and room_task (5,010 minus resident_outcomes, which stays deleted), `prepare_resident` (~220), the resource_tools room tools (~860), the concierge (757, only until R5 moves into Lean) and the main.rs hooks (~400): **≈ 31,700 lines remain**. Fix C-F2, C-F4 and C-F1 first, and set `restrictTools:true`.

### 6.3 What stays duplicated in the minimal controller, and should still collapse

The bounded-reader, hex, SHA, HTTP-parser and "unresolved custody" families (section 5.2) survive the demo cut. Collapsing them is a few hundred more lines, and it would remove a class of drift where each copy has its own owner/mode rule.

---

## 7. Deployability on the Hetzner VM

### 7.1 What must exist on the box

| item | why | evidence |
|---|---|---|
| `grain-runtime` binary, plus a copy as `/agent/grain-runtime` in each worker runtime root | controller; in-sandbox `mcp-stdio` | main.rs:14605-14614 |
| `grain-provider-bridge` in the runtime root, executable | the only production-safe provider topology (`--network none`); bwrap:85 requires it when a provider socket is passed | B §7.1; deploy/candidate/package.py:64 |
| `mini` (resource-client) and `minidregg-host` at pinned paths; a running `mini serve` / `serve-operator` on `hostSocket` that answers `operator-status` | every native read and write; resident preflight and `controller-launch` | A §2.1-2.2; C §7.1 |
| Store and signature-verifier helpers for the Host | Host dependencies | A §7.1 |
| `mini-keys` broker running as its **own account**, with `/etc/mini/keys/broker.json`, the credential root and seal key; root-owned `/etc/mini/keys-client.json` and `/etc/mini/providers.json` | provider tickets; the table must be root-owned and not g/w-writable | B §7.1; BYOK.md:20-42; credentials.rs:337-352 |
| `deploy/grain-host/bwrap` launcher and its compiled `launch-gate` sibling; `/usr/bin/bwrap`; unprivileged user namespaces (Ubuntu 24.04 needs an AppArmor profile, deploy/grain-host/README.md:36-39) | scoped workers | A §7.1 |
| a **systemd user manager** for each service account with **lingering** enabled (`/run/user/UID/bus`) | workers are always user units (`workerManager` must be `user`, systemd_manager.rs:92) | C §1.4 |
| cgroup v2 unified hierarchy; `/usr/bin/systemctl` at that fixed path | MainPID and cgroup proofs (fd-relative cgroup2 walk, magic `0x63677270`) | C §1.4, §2.2 |
| the upstream Hermes runtime (`hermes-acp`) in the runtime root; a worker-writable `config.yaml` home; for non-provider scoped Hermes, a private `config.yaml` with `timeouts.mcp.tool_call` | Hermes | A §2.5, B §1.1 |
| **one Unix account per member grain**, `stateDir` 0700 owned by it | the control and admin sockets' only protection | A §7.1, C §7.1 |
| disk headroom and a pruning policy | unbounded journal (`reconciliation_log`, `room_resolutions`), attempt directories, plaintext provider spools (up to ~102 MiB per prompt), retained stage files on ENOSPC, about a dozen resident files per turn | A F4; B-F4; C-F8, C-F11 |
| `/usr/bin/git` (GitWeb only), `setfacl`/`getfacl` (dispatch only), `journalctl` (session-failure only) | none needed for the demo scope | B §7.1, C §2.2 |

### 7.2 The exact unit shape that satisfies `prove_controller_unit` and `systemd_manager`

One of these two shapes, per member grain with task `T`. (section 9.1 settles which of A's and C's readings applies to which unit.)

**Shape 1, recommended for a system-managed host (root registration):**

* a system unit named exactly **`mini-grain-controller@T.service`**, with `User=<grain account>`, `ExecStart=/opt/mini/bin/grain-runtime serve /path/T.json`, `UMask=0077`, `Restart=on-failure`, `KillMode=control-group`, MemoryMax/TasksMax sized for the VM;
* the env var `MINI_GRAIN_CONTROLLER_UNIT` is optional, and if set must equal the canonical unit. `MINI_GRAIN_CONTROLLER_MANAGER` and `MINI_GRAIN_WORKER_MANAGER`, if set, must agree with the registration (systemd_manager.rs, `load`: "controller environment contradicts root manager registration");
* a root-owned **`/etc/mini/controllers/T.json`**: `protocol: mini-controller-registration-v1`, `task: T`, canonical `config` path, `manager: "system"`, `workerManager: "user"`, `serviceUid: <grain account uid>`, optional `residentConfig`/`roomRouting` (systemd_manager.rs:40-61, 80-109). Use `MINI_GRAIN_CONTROLLER_REGISTRATION` only if it is not at the default path; the file name must be exactly `T.json`;
* lingering for the grain account, and a launcher that answers `--controller-manager-protocol` with `mini-controller-manager-v1`, because the managers differ (systemd_manager.rs:404-417).

**Shape 2, matching what the journeys run (user-manager fixture, no registration):**

* a user unit `mini-grain-controller@T.service` under the grain account's user manager, with **all three** of `MINI_GRAIN_CONTROLLER_MANAGER=user`, `MINI_GRAIN_WORKER_MANAGER=user`, `MINI_GRAIN_CONTROLLER_UNIT=mini-grain-controller@T.service` (hermes-journey.sh:211-216).

Today's `deploy/grain-host/install-controller` renders Shape 2's name with only one of the three variables and writes no registration. `deploy/hermes/mini-hermes.service` has the wrong name. **Neither works without editing** (section 1.5). The smallest fix is to add the two missing `Environment=` lines to install-controller:189 (Shape 2), or to have install-controller write the registration (Shape 1). Separately, retire `mini-hermes.service` or rename it to the template.

### 7.3 Operator configuration surface

* the controller JSON (`deny_unknown_fields`): pinned `mini`/`host`/`hostConfig`/`hostSocket`, `controlSocket` inside `stateDir`, four task/subject/capability sets matching already-born and delegated native grains, four custody key **paths**, `commands` allowlist with fixed argv, `systemdScope`, `wallTimeSeconds`, and every `reserve`/`charge` (these are the prices, R1);
* `providerTask`: `providers` table path, `credentialBroker`, `gatewayBind` (loopback), byte/time bounds (`timeoutSeconds` ≤ 600: choose with H1 in mind, since the gateway does not stream), `maxInputTokens`/`maxOutputTokens`, `model`, optional `provider` row pin (**set it**, to avoid R3's "first row listing the model"), `onBehalfOf`, `maxIterations`; never `localFixtureHostNetwork` in production (the installers refuse it, install-controller:147);
* `toolTask`: `allowedPublications`, `allowedReads`, `resourceWorkspace`, birth families (drop for the demo), Host SHA-256 pins for optional features, `room` (`restrictTools:true` if rooms are ever enabled);
* the provider table, member grants (via `mini key`), the registration, the bwrap launcher's mount list.

Grains today come from `acceptance.sh BOOTSTRAP_ONLY=1`, from `bootstrap-native-controller.py` (which string-splits and `exec`s the Python embedded in `native/resource-client/journey.d/jpay6.sh`), or from `provider-provision` (A §1.6, §7.2). There is no first-class "create a member grain and its controller config" command. That is a demo blocker the review should name.

### 7.4 Dangerous sockets

| socket | who can reach it | what it can do | guard |
|---|---|---|---|
| control (`controlSocket`) | any process of the grain's UID, or root | attach; run allowlisted commands; issue Hermes prompts that spend the budget; `tool-v1` foreground frames; `terminal hermes-resident` (still needs an admin-minted preparation) | 0600 in a 0700 `stateDir`; no `SO_PEERCRED`; one attachment slot. `grain-ssh` forwards an SSH key to it; with the plain `connect SOCKET` form the key holder chooses the first line (C §7.3). |
| admin (`stateDir/admin.sock`) | the grain's UID | settles held allowances at the configured charge, acknowledges external effects, clears resident custody, runs config migration and legacy B44 settlement | file mode only. **Never share the service UID with member shells.** The room resident driver must run as that UID because it uses this socket. |
| dispatch (`dispatchTask.socketPath`) | `hostUid` (peer-checked + ACL) | v1 moves money on the host's word (R9); allocates up to 22 MiB from a length prefix | `SO_PEERCRED`; out of demo scope |
| mini-keys broker | any caller whose UID has the `provider` role | mint tickets, forward to homelab without a ticket | `SO_PEERCRED` uid only. Today only bwrap's mount list keeps it out of the sandbox (bwrap:55-71, 120-128), and the worker runs **under the controller's UID** in a user namespace (B §7.3). |
| `mcp-N.sock` (bind-mounted as `/run/mini-grain.sock`) | any process inside the sandbox (Unix `connect` works on a read-only bind) | any tool name, including `__mini_gitweb_http_raw` and `__catalog`; the `__*` refusal lives only in the in-sandbox edge | controller-side `prompt_epoch` check and Lean admission (B-F8) |
| provider gateway | sandbox processes (Unix mode); any local user in fixture TCP mode | hold the single request slot for 10 s per connection (B-F10) | per-prompt 64-hex token, constant-time compare |

### 7.5 Logs and retention

* Worker stderr is `Stdio::inherit()` into the controller's stderr, i.e. the systemd journal. Serve-loop errors embed child stderr, and provider audit lines print provider, `user:SUBJECT` and endpoint (A F5).
* The room resident prints model text, and the concierge prints payer subjects (C §7.3).
* **Member prompts and model replies are retained in plaintext forever**: `provider-N.request/.response/.headers` from the gateway, and again as `.controller-outcome/.controller-response-headers`. The broker deletes its own copies (B-F4).
* On a public demo, a privacy notice and a retention/rotation policy are prerequisites, not polish.

### 7.6 What a stranger can reach

Nothing directly. The crate opens no non-loopback listener: the gateway refuses non-loopback binds, the bridge and gitweb listeners live inside the sandbox netns, and everything else is a Unix socket in `stateDir`. The only TCP code outside tests is the unused loopback example (A §7.4, B §7.4, C §7.4). Exposure equals the front end that relays to `connect`: an SSH forced command, the hosted shell, the Discord entrance.

### 7.7 What a malicious member or prompt-injected agent can do

Merged from A §7.5, B §7.5 and C §7.5:

| actor | action | consequence | ref |
|---|---|---|---|
| member | spend the grain's allowance through prompts and allowlisted commands, each at the configured charge | budget burn, bounded by native budget | R1 |
| member | hard-disconnect repeatedly | each break is a native `interrupt` plus an audited or automatic reconcile | A §7.5 |
| member (pool route) | provoke a non-200 upstream reply (over-long context) | **bricks their own provider grain**; on a shared pool it also consumes operator caps | H4 |
| member (BYOK) | revoke or replace their key mid-session | refused before send (fine); daily counts still consumed by refused sends | B §7.5, R4 |
| member (room) | post a > 16 KiB-reply-producing question | **wedges the room's resident for everyone** | H14 |
| member (room) | eight requests per author | each costs the founder up to three paid notice turns plus the reply | R14 |
| member (room) | hold the single attachment slot through `connect` | stops the resident's prompts | C-F7.3, C-F7.6 |
| member (paid room) | pay twice in one height; or time a payment to a Host outage | loses the second payment; makes refunds fail permanently | H10, H11 |
| agent | call any catalog tool (and raw `__*` names through the socket) within Lean capabilities and the tool reserve | effects only via Lean admission; no bypass found | B §3.3 |
| agent | consume the per-prompt request budget (≤ 6) | prompt cut short | R20 |
| agent | write arbitrary stderr | lands in operator logs | A F5 |
| agent | create `/workspace/.hermes/.config.yaml.tmp` | every later prompt fails before reserve until an operator deletes it | B-F11 |
| agent | grow `state.db` past 512 MiB | forces `conversation new` | A F10 |
| agent | hold the gateway request slot | denies its own grain's provider calls | B-F10 |
| agent (homelab) | cause an uncertain send | quarantines a shared GPU slot | B §7.5 |
| agent (room, `restrictTools:false`) | generic workspace writes | room writes without paying turns | R6 |
| agent | call `mini_read_resource` in a loop | fills `stateDir` with `resource-read-N/` | C-F8 |
| anyone | none of the above lets an agent read a provider bearer (withheld if echoed) or a custody key (paths only, refused as mounts) | | A (4), B §4 sound |

---

## 8. Questions for the Lean side

The 36 questions (A 14, B 10, C 12) merge into 22. Each names the declaration a reader pointed at, and the findings it decides.

1. **Grain settle bound and a work tariff.** Which declaration in `Kernel/AgentGrain*.lean` admits `{"type":"settle","charge":C}`, and does it bound `C` by anything except the signed `reserved`? Is there, or should there be, a Lean tariff for non-provider work (commands, prompts, tool effects, room writes), including the price of a refused or never-admitted operation? (A Q1; R1, R2; C-V3)
2. **Held reservation exit.** Does any Lean rule release, expire or settle a reserved grain or provider purse (status 3, 5 or 7) whose request may have reached upstream but whose response is unknown, without a controller-authored settle? If not, is a reserve deadline or an "uncertain settle" planned, and where? (A Q4, B Q2; H1, H2, H5)
3. **Complete but unquotable metered reply.** `ProviderUsage.quoteResponse` refuses metered status ≠ 200 (Host/ProviderUsage.lean:267-268). Which declaration admits a settle (zero or per-op fee) for a complete retained non-200 reply? `Kernel/ProviderRoute.lean:25-28` says "nothing or at least its fee". Relatedly: is a user-route call the broker refused before sending settleable at zero, and which theorem separates "never left" from "left" (ProviderRoute.lean:22-23)? (B Q1, Q7; H4)
4. **Absent then admitted.** On one persistent `mini serve`, can an op-2 SUBMIT frame fully written before its sender died be admitted **after** an op-3 LOOKUP for the same call returned `absent`? Name the declaration that serialises frames (main.rs:11505-11508 assumes "one connection at a time in accept order"). The same question applies to room document writes through `mini shell --line "submit hr-OP"`. (A Q7, C Q5; R7, H7)
5. **Never-admissible witness.** For a retained signed call whose every slot has `validUntil < checkedHeight`, which admission clause guarantees it can never be admitted later, and is `checkedHeight = genesisHeight + acceptedCount` the height that clause compares against (provider_resolution.rs:121-161)? Is an op-255 reply to op-1 AUTHORIZED_PREPARE (decoded phase "prepare") a guarantee that no signed call for that intent can later be admitted, or only that this prepare failed? Could the Host return such a witness directly? (B Q4, A Q11; R7, R10)
6. **Settle by anchor.** Is there a Lean form of settle that names the reserve receipt (transaction/event), so that the `OwnManagedLaw` inference (main.rs:16360-16386) becomes a native refusal? (A Q14; R8)
7. **Provider route law.** Which declaration records the route at `{"type":"reserve","amount":A,"route":R}`, refuses a user-route hold other than the tariff's `perOp`, and refuses a settle whose route differs (main.rs:2627-2637; Host/Json.lean:2683-2685)? Is there any declaration tying the reserve's route to the operator table (a digest in Host settings), so that Lean could refuse a wrong-payer reserve? (A Q2, B Q3; R3)
8. **op 17 continuity.** In `runProviderContinuitySession` (Host/Main.lean:5548-5632, 6718-6724), what makes the verdict `continuous`, and is a fence of the same purse the only allowed later event (provider_continuity.rs:855)? Since the docstring says the check "does not lease the provider resource across a later external send" (Main.lean:5543-5547), which declaration stops another controller settling or disconnecting the purse between the check and the settle? (A Q3, B Q5)
9. **Status enum.** Name the AgentGrain status type and the meaning of codes 0-7 that main.rs branches on 62 times. Is status 2 "soft-idle" (A) or "soft-running" (C, quiescence.rs:166-171)? Can any status hold value with `reserved = 0`? (A Q8, C Q8; R21)
10. **Birth tariff and namespace reuse.** Does the grain-birth receiver (Kernel/NativeHostGrainBirth.lean:48, `config.grainBirthTariffValue`) refuse a source whose `tariff` object differs from the Host-config pin? Does it, and the op-30/31 app/session birth receivers, refuse a target or capability ID already in use, given that Rust computes `start + ordinal`? (A Q5, C Q9; R13)
11. **Private agent ops and app-API admission.** For ops 48, 58, 59 and 76-80, which receiver arms perform fresh admission? Are `inspect application-agent-paid-dispatch-plan`, `inspect-agent-lifetime-paid-ingress` and `inspect application-agent-lifetime-dispatch-committed` pure decoders ("structural-only-not-fresh-admission", main.rs:6250-6251)? Does the event21 receiver re-derive generations itself, so a stale SPK `FixedBinding` can never be the basis of admission, and does event26 check `operationFingerprint` or only the HTTP digest? (A Q6, C Q10)
12. **Worker-law install.** Does the `grain-policy-install-intent` receiver require `expectedVersion`, `expectedAddress` and `expectedPreRoot` (main.rs:7811-7824) and refuse a changed predicate? Are `mini author --kind predicate` and `--kind grain-policy` canonical Lean encodings, so that byte comparison is a sound "same law" test (main.rs:7933)? (A Q9, Q13)
13. **Parent witness.** For a tool `settle` carrying `publications` and a `parentWitness`, which declaration checks, in the same transaction, that the parent is still at the witnessed generation and reserved, so an old prompt cannot publish after a hard fence (README.md:274-277)? (A Q10)
14. **Quote inputs.** Does `ProviderUsage.quotePayload` bind `requestBytes`/`responseBytes` to the bytes it is given and enforce the per-task token ceilings itself (ProviderUsage.lean:90), or are the ceilings Rust-only (main.rs:1832-1840)? (A Q12; R23)
15. **Nonce replay.** `grainSource` hashes `(operationId, payload)` into the command nonce (Host/Json.lean:2700-2707, 2753). Does Lean refuse a second admission of the same nonce for the same subject, and is that what makes `pending_prepare`'s re-prepare safe if the original prepare was in fact sent? (B Q6)
16. **Profile strings.** Is `providerContinuityAdmission: "exact-height-v1"` (Host/Main.lean:861, SourceAgreementReader.lean:140) tied by a declaration to `NativeProviderHistory.checkPrior` and the v3 frame, or hand-maintained? Which declaration produces the op-6 PROFILE fields `runtime:"minidregg-native"`, `nativeChecked`, `domain`, `semantics` that quiescence_transport.rs:195-209 requires? (B Q8, C Q7)
17. **Op 144.** What exactly do `isCurrent` and `currentRevoked` mean (current at the walked head?), and is `keyEpoch` monotone per subject (Host/Main.lean:7027; provider_owner.rs:59-70)? (B Q9)
18. **Member quotas and choice.** Should `perDay`, `perCall`, `notAfter` and the member's provider/model choice be Lean facts (a grant or choice resource, a delegation), or are they explicitly physical broker policy? If Lean, which resource holds the counter? (B Q10; R4, R12)
19. **Room turn price and refusal codes.** Does any declaration bind a fleet turn's amount to the room's `hermes/turn` field, or is the amount whatever the signed turn says (`Kernel/FleetTurn.lean:1-24`)? Which `fleetPlanAuthorizedLoaded` refusal constructor (Host/Main.lean:6812-6816) means "payer cannot fund" (the `bookRefused` string Rust greps for), and is its name stable? (C Q1, Q4; R6, R15)
20. **Paid membership.** Is there a receiver (the "K-BOOK-SLOTS" of concierge.rs:27-30) that refuses a member delegation unless a matching `renew` ledger entry is consumed in the same transaction? What is the unique key of an incoming ledger entry in `fleetIncomingAuthorizedLoaded` (Host/Main.lean:6865): can two share a height? Which declaration enforces `Admissible.validUntil`, and does a later delegation with a larger `notAfter` supersede or add to the earlier one? (C Q2, Q3, Q12; R5, H10)
21. **Share-issue lookups.** Do ops 29 and 55 replay a historical receipt as `type:"confirmed", confirmation:"replayed"` with the four receipt fields shared_app_refs.rs:336-361 compares, and refuse an ingress of the other event kind (event15 vs event22)? (C Q6; A §2.1 op 55)
22. **Stable reply guard.** For the resident's final `mini_say` with `--expect-re-cell/--expect-re-sequence`, which Lean check refuses the append if the replied-to entry changed (resource_tools.rs:1128-1153)? (C Q11)

Questions 2, 3, 4, 5, 6, 15 and 20 are the ones section 4.3's contract depends on. Questions 1, 7, 18, 19 and 20 decide whether R1-R6 move into Lean or get relabelled as operator policy.

---

## 9. Disagreements between the reports, and rulings

### 9.1 A F7 vs C's "correction": what the shipped units do

* **A:** the template sets one of three env vars, "so it refuses to start without a registration". `mini-hermes.service` has the wrong name, so even with a registration every provider prompt fails `prove_controller_unit`.
* **C:** "correction to A-F7: with zero env vars and no registration the runtime opens unscoped and only scoped work fails".
* **Ruling: both are right, about different units.** I read systemd_manager.rs `fixture` and `load` (systemd_manager.rs:158-247). With all three variables unset and no registration file, `fixture` returns `Ok(None)`: unscoped. With any subset set it returns the error at :173-174.
  * The template (`deploy/grain-host/mini-grain-controller@.service:9`) and `install-controller:189` set exactly one variable, so without a registration they **fail to open**. A is right for them; C says the same in its summary item 11.
  * `deploy/hermes/mini-hermes.service` (read in full; no `Environment=`) sets none, so without a registration it **opens unscoped**. C's correction applies here. Its first scoped Hermes prompt then fails at `systemd_manager::current()`; with a registration, `prove_controller_unit` fails on the name. A's conclusion that no provider prompt can run under the production unit stands. The failure is later and quieter than "refuses to start".
* **New point neither reader made:** `install-controller` writes no registration (grep finds no `controllers/` or registration path in it), so the shipped installer cannot produce a working controller as written.

### 9.2 A's "(unassigned)" modules

A listed journal_io, controller_digest, public_status, grain_source, homelab, cgroup_stop, custody_gate, dispatch_custody, legacy_custody_audit, pending_prepare, query_observation, terminal, shared_app_refs, application_api_tools, hermes_outcome, hermes_session_verify, hermes_catalogue_probe, session_failure, controller_write_scopes and the test modules as "need a reader".

**Ruling: all are covered.** B read custody_gate, dispatch_custody, dispatch_runtime_tests, legacy_custody_audit, pending_prepare, query_observation, grain_source, homelab, hermes_outcome, hermes_session_verify and hermes_catalogue_probe. C read journal_io, controller_digest, public_status, cgroup_stop, terminal, session_failure, controller_write_scopes, shared_app_refs, application_api_tools, resource_tools and the two test files. Section 1.2's table sums the three shards to exactly 55,895, with no module missing or double-counted.

A's finer claim that "nothing declared is dead code" is true at module granularity only. B and C found dead or test-only items inside modules: `resident_preflight::{Ready, checked}`, `RoomTools::write/notice` (legacy runner only), the `max_output_tokens == None` gateway branch, the replay bound 16, and all of v3 (section 5.4).

### 9.3 Shard overlap on hermes_room, and the J14 attribution

A's scratch table attributes "J14 evidence 2026-10-01-p-hermes-room" to `hermes-room resident CONFIG` (room_resident).

* **B** (owner of hermes_room.rs) says j14 runs the legacy runner.
* **C** says room_resident has no recorded run (AFFORDANCES.md:386 "none") and that the j14 artifact is `hermes-journal.jsonl`, the legacy runner's.

**Ruling: B and C are right.** `native/resource-client/journey.d/j14.sh:10, 197, 386, 419` invoke `grain-runtime hermes-room step`, the legacy chat-completions runner in hermes_room.rs, not `hermes-room resident`. Consequence for the deletion plan: **README row 18 ("Hermes in a room: executed", evidence J14) is evidence for the twin that should be deleted (B T6), not for the ACP controller's room path.** Retiring the legacy runner retires the only recorded "Hermes in a room" run. The honest-state table should say that the ACP room resident is unrun.

There is no conflict on ownership. B owns hermes_room.rs; C read its first 60 lines for the room-write twin, and C's room-executor row agrees with B's T6.

### 9.4 Does the custody gate fix A's F2?

* **A:** "`work_output` and `supervised_json_command` go through `custody_gate::run_capture` and can be cancelled … so the fix exists in the file but is not applied uniformly".
* **B:** `CustodyGate` "has no wall-clock timeout of its own (only `cancel`), so it does not fix shard A's F2 for a hung child unless a hard EOF arrives" (custody_gate.rs:139-222).

**Ruling: B is right.** The gate converts a hung child into a cancellable one only when someone cancels it, i.e. on a hard connector EOF. Under a soft attach, or during startup recovery, a hung `mini` blocks the loop either way. H12's fix is a deadline, not wider use of the gate.

### 9.5 How many crates compile credentials.rs

A says two (grain-runtime, resource-client); B says three. **Ruling: B is right**, confirmed by `#[path = "../../../grain-runtime/src/credentials.rs"]` at `native/mini-keys/src/server/mod.rs:20` and `native/resource-client/src/keys.rs:35`.

### 9.6 What grain status 2 means

A reads status 2 as "soft-idle" from main.rs branches; C quotes quiescence.rs calling it "soft-running", inside the unreserved boundary {0,1,2,6}. **Unresolved without Lean**: this is Q9. That two careful readers disagree is itself the evidence for R21: the codes should be a Lean-exported table.

### 9.7 v3 lifetime app-API: evidence vs dead code

* **A** lists v3 as reached by "no driver in the crate", with docs/evidence/2026-09-27-agent-lifetime-* existing "(names only)".
* **C** shows it cannot work.

**Ruling: C is right.** I confirmed both failures. `begin_application_lifetime_api` calls `start_exchange_once` (main.rs:8699), which reaches `exchange_once_guarded`. That decodes every reply as `HostReply` (application_api_tools.rs:1646-1647), whose kebab-case variants are `binding|http|refused|uncertain|inspection` (application_api_tools.rs:505-512), while spk-host answers `binding-v3` etc. (`native/spk-host/src/agent_api_lifetime_wire_v3.rs:179-181`). Separately, `verify_lifetime_reserve_inspection` reads `operation_id` (application_api_tools.rs:993) from a frame keyed `operationId`. The 09-27 lifetime evidence directories predate the current source and cannot be cited for it.

### 9.8 The demo's provider route

A's demo path says "user or pool route"; B's says the BYOK user route. **Ruling: user route only**, until H4 has a Lean settle. On the pool route any 429 bricks the grain (B-F1). All three demo-minimal estimates were made with the same exclusions otherwise, and section 6.2 reconciles their different scopes (A kept rooms, migration and incident receivers out of view; C counted only its shard; B deferred rather than deleted the retirements) into one number.

### 9.9 Not disagreements, but layered findings worth keeping apart

* A V8 (`end_turn` = deliverable) and C-V7 (SSE `finish_reason:"stop"`, ≤ 3,000 bytes, equal to the ACP capture) are two layers of the same judgement, controller then resident (R19).
* A F1 and B-F1/F2/F3 are one hole family (H1-H6). B widens A's two scenarios to eleven `Uncertain` sites plus the metered non-200 case and a no-outcome bug.
* A V3, C-V4 and B BV5/BV6 are one inference (R7), implemented three times, once with a 100-entry signed-tail heuristic.
