# grain-runtime, shard C: resident, room, control sockets, quiescence, systemd, terminal, application tools, resource tools

| field | value |
|---|---|
| shard | grain-runtime C, "resident, room, control sockets, quiescence, systemd, terminal, application tools, resource tools" |
| crate | `/Users/ember/dev/minidregg/native/grain-runtime` (package `minidregg-grain-runtime`, bin `grain-runtime`) |
| reviewer | Opus reader, fan-out review 2026-10-26 |
| date | 2026-10-26 |
| method | every file below read in full; `path:line` cited for every claim about code; no build, no test run; Lean receivers read only where named |
| companion | shard A report `docs/review/2026-10-26-native-crates/grain-runtime--A-main.md` (main.rs); its V1-V8 and F1-F13 are referenced as "A-V1", "A-F7" |

Paths below are relative to `native/grain-runtime/` unless they start with a top-level directory (`deploy/`, `Host/`, `Kernel/`, `protocol/`, `docs/`, `native/`).

## Files covered

| file | lines | of which test module | `#[test]` count |
|---|---|---|---|
| src/resident_context.rs | 203 | 59 | 5 |
| src/resident_preflight.rs | 337 | 123 (+8 lines of `#[cfg(test)]` fixtures at 204-214) | 6 |
| src/resident_outcomes.rs | 416 | 94 | 5 |
| src/resident_reconcile.rs | 489 | 175 | 8 |
| src/resident_requests.rs | 660 | 219 | 15 |
| src/resident_delivery.rs | 1,341 | 336 | 13 |
| src/resident_completion.rs | 939 | 212 (+42 lines of `#[cfg(test)]` fixture at 684-726) | 6 |
| src/resident_origin.rs | 52 | 18 | 2 |
| src/room_task.rs | 447 | 219 | 13 |
| src/room_resident.rs | 542 | 188 | 9 |
| src/concierge.rs | 757 | 125 | 10 |
| src/quiescence.rs | 987 | 274 | 15 |
| src/quiescence_transport.rs | 717 | 228 | 8 |
| src/session_failure.rs | 705 | 160 | 6 |
| src/control.rs | 948 | 252 | 5 |
| src/cgroup_stop.rs | 443 | 242 | 10 (1 `#[ignore]`) |
| src/systemd_manager.rs | 568 | 150 | 10 |
| src/terminal.rs | 600 | 91 | 6 |
| src/controller_write_scopes.rs | 46 | 0 | 0 |
| src/controller_digest.rs | 28 | 16 | 2 |
| src/public_status.rs | 23 | 14 | 1 |
| src/journal_io.rs | 104 | 53 | 4 (1 `#[ignore]` worker) |
| src/birth_lifecycle_tests.rs | 143 | 143 (whole file `#[cfg(test)]`, main.rs:26-27) | 3 |
| src/publication_refusal_tests.rs | 821 | 821 (whole file `#[cfg(test)]`, main.rs:58-59) | 8 |
| src/application_tools.rs | 813 | 180 | 4 |
| src/application_api_tools.rs | 2,764 | 915 | 19 |
| src/resource_tools.rs | 1,579 | 320 | 11 |
| src/shared_app_refs.rs | 805 | 286 | 8 |
| **src subtotal** | **18,277** | **5,913 (32%)** | **212** |
| examples/current_birth_provider.rs | 278 | - | - |
| examples/README.md | 20 | - | - |
| fixture/broker-drop.rs | 38 | - | - |
| fixture/RECEIPT-RECOVERY.md | 21 | - | - |
| fixture/hermes-acp (sh) | 21 | - | - |
| fixture/hermes-deterministic-acp (python3) | 235 | - | - |
| fixture/hermes-acp-recovery (sh) | 43 | - | - |
| fixture/observe-mini-retry (sh) | 18 | - | - |
| fixture/sleep-fixed (sh) | 7 | - | - |
| **Rust total (src + example + broker-drop)** | **18,593** | | |

Context prose read in full: RESIDENT-DELIVERY.md (62), RESIDENT-OUTCOMES.md (61), RESIDENT-REQUESTS.md (104), SESSION-FAILURE.md (105), SYSTEMD-MANAGERS.md (96), TERMINAL.md (9), CONTROLLER-WRITE-SCOPES.md (66), RESOURCE-WORKSPACE-MIGRATION.md (9); `deploy/grain-host/grain-ssh` (19), `deploy/grain-host/README.md` (lines 120-175), `deploy/grain-host/probe_control.rs` (44), `deploy/grain-host/mini-grain-controller@.service` (20), `deploy/grain-host/install-controller` (lines 150-215), `deploy/hermes/mini-hermes.service` (48), `deploy/hermes-dispatch/README.md` (lines 1-80). Cross-checked in main.rs: `serve` (17470-17918), `main` (17920-18238), `hermes_session` (14322-14345, 14570-14590, 14970-14990), `tool_call` (12221-12270), `prove_prior_run_stopped` (681-693), `prove_controller_unit` (17212-17240), file helpers (2269-2365, 2554-2557, 6916-6919), `verified_reverse_lifetime_fixed_request` (4083-4173), v3 reserve inspection call (4330-4380), lifetime API poll (8695-8925). Lean read: `Host/Main.lean:6809-6870` (ops 96-101, 180). Not owned but read for twin analysis: `src/hermes_room.rs:1-60`, `native/spk-host/src/agent_api_lifetime_wire_v3.rs:70-225`.

## Executive summary (15 lines)

1. This shard is four things bolted to the controller: the control/terminal socket front end (control.rs, terminal.rs), a room-resident driver with seven receiver modules (room_resident.rs + resident_*.rs + room_task.rs, 5,426 lines), operator incident receivers (session_failure.rs, resident_outcomes.rs, quiescence_transport.rs, resident_reconcile.rs) and tool planners (resource_tools.rs, application_tools.rs, application_api_tools.rs, shared_app_refs.rs).
2. The control socket's only access control is the 0600 socket inside the 0700 `stateDir` (control.rs:299-300, main.rs:6829); no SO_PEERCRED; one attachment at a time; 8 connections silently dropped beyond the cap (control.rs:318-321); lines bounded at 16 KiB, `tool-v1` frames at 256 KiB (control.rs:19-20).
3. `deploy/grain-host/probe_control.rs:29-42` no longer compiles against `control::Event`: its `match` lacks `InspectAttached` and `Tool` (control.rs:31-37).
4. Rust IS the decision in four new places beyond shard A: the concierge's paid-membership rule (concierge.rs:147-180, ledger loop 380-478), the "every room write is a turn" payment sequencing and its full-charge-on-refusal (room_task.rs:110-112, resource_tools.rs:686-690; Lean `Kernel/FleetTurn.lean` knows no room tariff), resident queue admission/fairness and paid status notices (resident_requests.rs:257-342, 160-208), and "a refused/absent doc write never happened" (resource_tools.rs:1206-1217, the A-V3 inference again).
5. Concierge money bugs: the ledger key is `ledger:HEIGHT` (concierge.rs:389), so a second payment landing at the same height is skipped forever (never honoured, never refunded), and its proposal id `renew-h{height}` collides (concierge.rs:459); a failed refund is journaled as a final `refund-failed` decision (concierge.rs:452, read back as decided at 236-247), so the till keeps the payment; the `refunding` set is never consulted (only echoed at 405).
6. The v3 "lifetime" app-API path cannot work end to end: the transport decodes every reply strictly as the v1 `HostReply` enum (application_api_tools.rs:505-545, 1646-1647), but spk-host answers `binding-v3`/`http-v3`/`refused-v3`/`uncertain-v3` (native/spk-host/src/agent_api_lifetime_wire_v3.rs:179-225), so every v3 Hello comes back `Uncertain`; independently `verify_lifetime_reserve_inspection` reads `operation_id` (application_api_tools.rs:993) from a retained `dispatch-v3` frame whose key is `operationId` (main.rs:4134-4136). Unit tests mask both.
7. A failed (non-`end_turn`) admitted resident prompt for a selected room request has no closing receiver: after `resident-reconcile failed` clears `resident.json.pending`, `resident_requests::reconcile` demands a native delivered/refused final receipt and errors at every driver start (resident_requests.rs:420-430, room_resident.rs:306), so that room's resident is wedged permanently (the resident analogue of A-F1).
8. Admin replies are read with the 16 KiB line bound (control.rs:149-158, 509-511) but written unbounded (control.rs:146); a `resident delivery-plan` reply embeds the requester's entry text (up to 12,000 bytes, resident_requests.rs:237) plus the 3,000-byte final twice (resident_delivery.rs:655-658), so a long question makes `drain_completed` fail at every start: a second permanent resident wedge.
9. session_failure.rs is a one-incident receiver kept in the product: it scrapes `journalctl --user` for a historical Rust `Debug` error string (session_failure.rs:96-107, 198-214); its doc pins task8781/operation94/invocation c2fdf82e (SESSION-FAILURE.md:96-98) and names a "preparation helper" that exists nowhere in the tree; its freeze marker is checked on every serve-loop input and every save (main.rs:17598-17599, 6916-6918) and has no reset (SESSION-FAILURE.md:103-105).
10. resident_outcomes.rs (one historical completion, RESIDENT-OUTCOMES.md:22 `historicalOperationId:78`) is likewise woven into the hot path: `qualified_count` gates every resident loop iteration (room_resident.rs:308, 345, 350).
11. systemd/cgroup proofs are careful (fd-relative cgroup2 traversal with identity rechecks, cgroup_stop.rs:83-155; strict root registration, systemd_manager.rs:80-109) but bind to the literal unit `mini-grain-controller@TASK.service` (systemd_manager.rs:77-79, main.rs:689); both shipped renderers set only `MINI_GRAIN_CONTROLLER_UNIT` (deploy/grain-host/mini-grain-controller@.service:9, deploy/grain-host/install-controller:189), which `fixture` refuses (systemd_manager.rs:169-174); correction to A-F7: with zero env vars and no registration the runtime opens unscoped (systemd_manager.rs:166-168, 207-218) and only scoped work fails.
12. Twins: three copies of the `resident.json` schema (room_resident.rs:34, resident_reconcile.rs:10, quiescence.rs:356), three origin structs, two assignment prefixes, two flock-transfer drains, five "closed boundary" predicates, three journal publication paths, two birth-namespace planners (resource_tools.rs vs application_tools.rs), two room-write executors (room_task.rs vs hermes_room.rs), v2/v3 route and wire pairs.
13. Reachability: control, terminal (live evidence docs/evidence/2026-09-26-terminal-live), systemd/cgroup, journal_io and resource reads are on the demo path; concierge is journeyed (native/resource-client/journey.d/j17.sh, docs/evidence/2026-10-01-p-credit); the room-resident stack, session-failure, resident-outcome, quiescence-transport and v3 have no recorded run (docs/review/2026-10-26-deploy/AFFORDANCES.md:386 says "none" for room resident C).
14. Size: 18,277 src lines, 32% tests; a demo without rooms keeps about 5,100 lines of this shard (drops about 13,500); a demo with a room resident keeps about 11,300 (drops about 7,300, all of it one-incident receivers, v2/v3 app API, app/session births and the fixed-family birth twin).
15. Deploy: a small VM must run each grain as its own Unix account, render `mini-grain-controller@TASK.service` with a root registration `/etc/mini/controllers/TASK.json`, enable lingering for the user worker manager, and never expose `admin.sock`; nothing in this shard opens a TCP listener except the loopback test example (examples/current_birth_provider.rs:56).

## The nine questions the lead asked, settled

**(1) control.rs.** Protocol: the first line selects the mode, exactly one of `attach hard`, `attach soft`, `attach terminal-v1 hard`, `attach terminal-v1 soft`, `attach terminal-v1 inspect` (control.rs:358-370); anything else gets the refusal line `first line must be attach hard|soft or attach terminal-v1 hard|soft` and the connection closes (control.rs:364-368). After attach every further line is an `Event::Line` (control.rs:468-472) except `disconnect` (breaks, control.rs:444) and `tool-v1 N` followed by exactly N raw bytes (framed non-inspect only, 1..=262,144, canonical decimal, control.rs:445-460). Inspect attachments may send only lines starting `tool result ` or `tool ack ` (control.rs:461-467). The serve loop then interprets lines: `attach hard|soft` (synthesised from `Attached`), `status`, `recover`, `conversation new`, `disconnect`, `run NAME`, `hermes PROMPT`, `terminal status A R`, `terminal hermes A R PROMPT`, `terminal hermes-resident A R ID SHA PROMPT`, `tool result ID`, `tool ack ID` (main.rs:17540-17580, 17602-17900). Framing bounds: control lines 16,384 bytes (control.rs:19, 526-531), first-line read timeout 10 s then none (control.rs:354, 405), outbound queue 128 per attachment (control.rs:21, 371), framed writer write timeout 2 s (control.rs:413), terminal event frames ≤ 4,096 bytes (control.rs:241), tool events ≤ 1 MiB (control.rs:203). Who may connect: anyone who can `connect(2)` to the 0600 socket file (control.rs:299-300), i.e. the owning UID or root; the `stateDir` is created 0700 (main.rs:6829); no peer credential check anywhere in control.rs. Event enum: `Attached{id,soft}`, `InspectAttached{id}`, `Line{id,text}`, `Tool{id,frame}`, `Detached{id,hard}` (control.rs:31-37); `deploy/grain-host/probe_control.rs:29-42` matches only `Attached`, `Line`, `Detached`, so it fails exhaustiveness (E0004) and cannot build. Hard-EOF semantics: on any read error, EOF or `disconnect`, `detach` runs the `HardInterrupt` callback *while holding the attachment lock* if the mode is Hard (control.rs:484-494), then sets `detaching` so no replacement attachment can win the race, then blocks sending `Detached{hard}` (control.rs:495-506); the callback (main.rs:17481-17504) revokes the provider gateway, kills the worker unit, fences the launch gate and cancels the custody and application-API send gates before the serve loop ever sees `Input::Disconnect`.

**(2) Resident-in-a-room.** The driver is `grain-runtime hermes-room resident CONFIG` (main.rs:18009-18014 -> room_resident.rs:271). Each loop: `hermes_room::prepare_resident` gathers signed room state (room_resident.rs:309, not in this shard), `resident_requests::select` admits/queues/selects one addressed request (room_resident.rs:320), the driver attaches to the controller's control socket as `attach terminal-v1 soft`, asks `terminal status`, obtains a fresh source prompt id over the admin socket (`resident prepare SHA`, resident_preflight.rs:80-85), marks the request started, and sends `terminal hermes-resident ...` (room_resident.rs:108-182). The controller's `hermes_session` repeats preflight, writes `resident-entered-ID.json` before any reserve (main.rs:14322-14336, resident_preflight.rs:137-148), records the origin (main.rs:14576-14583), and on ACP `end_turn` stages `residentCompletion` and `residentDelivery` (main.rs:14977-14983). The driver then drains completion (resident_completion.rs:611-648) and delivery (resident_delivery.rs:942-986) through admin commands, which post the final as a paid `mini_say` (resident_delivery.rs:874-880 -> room_task.rs:164-226). Rust-owned decisions: concierge membership pricing (concierge.rs:147-180; Lean admits only the delegation, concierge.rs:24-30), "deliverable" = provider SSE ends `finish_reason:"stop"` with one assistant text choice ≤ 3,000 bytes equal to the ACP capture (resident_delivery.rs:71-143, 520-522, 553-555), "failed" = the controller's presentation projection (terminal.rs:103-122) consumed by resident_reconcile.rs:126-136, request queue limits (64 pending, 8 per author, 16 MiB, resident_requests.rs:5-17, 301-321), preflight (resident_preflight.rs:184-202). Lean owns: every native write (turn payment via fleet ops 96-99, document writes, final say) and the ToolTask purse. The Book turn payment on delivery (RESIDENT-DELIVERY.md:23-26) is real: `deliver_resident_final` allocates the operation id durably (resident_delivery.rs:883-904), `room_call_with_id` reserves the ToolTask purse (room_task.rs:184), pays the room turn with `mini credit --action turn` under an operation record (room_task.rs:193, resource_tools.rs:1082-1115) and only then writes (room_task.rs:211-212); recovery uses `lookup_operation` (room_task.rs:142-154, resource_tools.rs:1056-1077). Twins among the seven resident modules: see section 5.3.

**(3) Operator reconciliation surfaces.** `quiescence.rs` is a general, pure projection plus a locked fresh inspection (quiescence.rs:269-349, 602-692) and is used by config migration, preflight and every receiver; keep it. `resident_reconcile.rs` is a narrow but general receiver (any authoritative failed/review-needed completion, resident_reconcile.rs:78-145). `session_failure.rs` and `resident_outcomes.rs` are one-incident receivers: SESSION-FAILURE.md:27-34 restricts itself to "the bounded historical form `mini-hermes-observed-acp-failure-v1`" and SESSION-FAILURE.md:96-98 pins "task8781 / operation94 / invocationc2fdf82ef7ca45fcaed78e7715d155c6"; the receiver parses one historical error message format (session_failure.rs:198-214). RESIDENT-OUTCOMES.md:20-27 pins one historical operation (78) by operator assertion. `quiescence_transport.rs` is a one-topology upgrade surface (root-attested admission, public relay unit, management socket; quiescence_transport.rs:53-67, 361-438) with no recorded run. A clean design: one typed per-prompt outcome record written by the controller at the moment of failure (the "future source-owned per-prompt failure artifact" SESSION-FAILURE.md:33-34 promises), one closure receiver keyed by that record, and delete both historical receivers and their hot-path hooks once the incident state is archived.

**(4) systemd_manager + cgroup_stop.** Proofs: `prove_controller_unit` (main.rs:17212-17240) requires this PID to be MainPID of the active `mini-grain-controller@TASK.service` under the manager chosen by `systemd_manager::current` (systemd_manager.rs:265-281); `prove_prior_run_stopped` (main.rs:681-693) adds that `/proc/self/cgroup` ends in that unit and then `cgroup_stop::prove` walks the controller cgroup twice by fd, requiring the root to hold only this PID and every descendant `populated 0` with empty `cgroup.procs`, unchanged inode identities, on a real cgroup2 filesystem (cgroup_stop.rs:83-182). Worker proof is the same walk with an empty root (cgroup_stop.rs:188-200). Root registration `/etc/mini/controllers/TASK.json` (systemd_manager.rs:190), read with `custody::root_bytes` (root-owned, systemd_manager.rs:221), schema `mini-controller-registration-v1` with `task`, canonical `config`, `manager`, `workerManager` (must be `user`, systemd_manager.rs:92), `serviceUid` (must equal euid, systemd_manager.rs:91), optional `residentConfig`, optional `roomRouting` (systemd_manager.rs:40-61, 80-109). F7 holds: `mini-hermes.service` (deploy/hermes/mini-hermes.service:31) is not the canonical unit name, so even with a registration `prove_controller_unit` fails; with no registration and no env it opens unscoped (systemd_manager.rs:166-168) and scoped Hermes fails at `current()` (systemd_manager.rs:277-279). A demo deploy must: render `mini-grain-controller@TASK.service` as a system unit with `User=` the service account, write the root registration with `manager:"system"`, `workerManager:"user"`, `serviceUid`, enable lingering so `/run/user/UID/bus` exists (systemd_manager.rs:289-295), install a launcher answering `--controller-manager-protocol` with `mini-controller-manager-v1` because the managers differ (systemd_manager.rs:404-417), and pass `MINI_GRAIN_CONTROLLER_REGISTRATION` only if the registration is not at the default path.

**(5) terminal.rs.** The `terminal-v1` framed protocol: client sends `attach terminal-v1 hard|soft`; controller answers one JSONL `{"v":1,"type":"socket-attached","attachmentId":N,"mode":...}` (control.rs:414-425); thereafter controller sends `output` frames (escaped model/ACP text, control.rs:429-431) and controller-authored `state`/`prompt-complete` frames bound to the attachment and request ids (terminal.rs:88-122, control.rs:237-256); client sends `terminal status A R` and `terminal hermes A R PROMPT` lines (terminal.rs:354-437). Frames ≤ 8 MiB, input lines ≤ 16,256 bytes, input queue 64 (terminal.rs:14-16, 168-170, 202-204). Reachable: subcommand `grain-runtime terminal SOCKET [hard|soft]` (main.rs:18154-18174), recorded live in docs/evidence/2026-09-26-terminal-live/README.md; the same framing is the room resident's wire (room_resident.rs:96-118, 134) and the foreground tool client's (control.rs:597-642).

**(6) application_tools / application_api_tools / shared_app_refs.** application_tools.rs is not the API client; it plans application and session *births* (op30/31 sources, application_tools.rs:484-632). application_api_tools.rs is the SPK app-API client: model input parsing (application_api_tools.rs:1758-1848), v2 wire `hello`/`dispatch`/`inspect` under protocol string `mini-spk-agent-api-v1` (sic, application_api_tools.rs:30, 74-76, 144-166), v3 wire `hello-v3`/`dispatch-v3` under `mini-spk-agent-api-v3` (application_api_tools.rs:31, 78-80, 128-142), binding verification (601-632, 423-470), reserve/paid inspection comparators for the event26 lifetime path (917-1090), and the peer-UID checked Unix transport (1164-1725). Trusted from the SPK host: the binding (as a transport identity, application_api_tools.rs:598-600), the HTTP reply bytes as the tool result, and its retained definite-reply bytes on inspection (732-769); money flows through the controller's dispatch purse checked by Lean in v2/v3 (main.rs, shard A). Duplication with spk-host: the wire is defined twice, once per side (`native/spk-host/src/agent_api_wire.rs`, `agent_api_lifetime_wire_v3.rs`, `agent_api_lifetime_v3.rs`); fingerprints are recomputed on both sides (application_api_tools.rs:387-421, 2285-2306 "golden vector"); the two sides already disagree on the v3 reply tags (finding C-F3). Duplication with main.rs: main.rs's v1/v2/v3 dispatch custody and app-API caller consume these helpers (main.rs:3997-4173, 8494-9172; shard A). Yes, these three files plus birth_lifecycle_tests.rs are 4,525 of the ~7,550 lines shard A says the demo drops; the rest is dispatch_custody.rs, gitweb_worker.rs, legacy_custody_audit.rs, dispatch_runtime_tests.rs and homelab.rs (other shards).

**(7) resource_tools.** Birth planning: `AllowedBirthFamily` (resource_tools.rs:27-46) with operator `targetStart`, `ownerCapabilityStart`, `controlCapabilityStart`, `maxBirths` ≤ 1,024 (108-110); IDs are `start + ordinal` with checked u64 addition (resource_tools.rs:59-68, 340-350); namespaces are checked against each other and against configured reads, publications and peers (resource_tools.rs:158-256). The `tariff` object `{"base":tariffBase,"perBirth":tariffPerBirth}` is copied verbatim into the source (resource_tools.rs:418) and `planned_birth_charge` = base + perBirth is a reserve bound only (resource_tools.rs:281-296). Twin: fixed-family `mini_create_resource` (this planner, main.rs:10615, 10768-10770) vs `mini_workspace_create` (main.rs:11879-12009); RESOURCE-WORKSPACE-MIGRATION.md:5, 9 keeps the fixed twin until a full migration journey passes. application_tools.rs repeats the same namespace arithmetic for app/session families (application_tools.rs:133-152, 380-388, 418-473).

**(8) Small utilities.** journal_io.rs is a sound atomic writer (fresh O_EXCL stage name, fsync, identity recheck, `renameat`, directory fsync, journal_io.rs:20-51); `controller_digest.rs` is streaming SHA-256 (28 lines, fine); `public_status.rs` reuses the terminal projection (23 lines, fine); `controller_write_scopes.rs` is a 46-line descriptor plus two migration verbs delegated to config_migration.rs. The "retained stage files never deleted" policy (journal_io.rs:1-2) is not sane as stated: a stage file is evidence of nothing once `rename` has or has not happened, and under persistent write failure (ENOSPC) every save leaves a new partial stage file (journal_io.rs:34-42), growing disk use exactly when disk is short; and because `atomic_json` (main.rs:2554-2557) routes requests.json, notices.json, resident.json and the controller journal through it, the leak covers all of them. A startup sweep of owned `.NAME.stage-*` files older than the committed file, or unlinking the stage on a pre-rename error, is safe.

**(9) Test modules.** Both test the *controller's bookkeeping against a shell fixture's model of Mini*, not Lean behaviour. birth_lifecycle_tests.rs replaces `mini` with a script that flips `status`/`reserved` files on `grep '"type": "settle"'` and requires `"charge": "0"` (birth_lifecycle_tests.rs:7-45); publication_refusal_tests.rs's stub fabricates outcomes, a pre-submit refusal frame and a fake `inspect outcome` Host (publication_refusal_tests.rs:32-108), and depends on `/usr/bin/openssl` and `jq` (publication_refusal_tests.rs:71, 304). They have teeth for journal invariants (no resubmission, holds retained on uncertainty) but say nothing about whether Lean would refuse or admit the same intents.

---

## 1. What this code is and does

### 1.1 The control plane

#### control.rs (948 lines)

The persistent controller socket, the admin socket and their clients. Server side: `start` binds the control socket, chmods it 0600, records its `(dev,ino)` identity, and spawns a nonblocking accept loop that admits at most 8 concurrent connection threads (control.rs:294-345); `Drop` unlinks the socket only if it is still the same inode (control.rs:282-292). `serve_connection` reads the first line with a 10 s timeout, selects `Mode::{Hard,Soft,Inspect}` and `framed`, takes the single `State.active` slot (refusing with `controller already has an attachment` if occupied or `detaching`), allocates a monotonically increasing attachment id, emits `Attached`/`InspectAttached`, spawns a writer thread draining a bounded 128-entry `Outbound` queue, then loops on input (control.rs:347-477). `detach` orders hard interruption before releasing the slot (control.rs:484-507).

`OutputHandle` gives the controller three send paths: `try_output` drops display text when no frontend or the queue is full (control.rs:224-233); `try_terminal_event_for` *blocks* on the queue so a completion is not lost behind output (control.rs:237-256); `try_tool_event_for` sends `tool-complete`/`tool-acknowledged` (≤ 1 MiB) only to the original framed attachment (control.rs:199-214).

Admin socket: `start_admin` binds `stateDir/admin.sock` 0600, accepts up to 4 concurrent connections, reads one line (10 s timeout), forwards an `AdminRequest{command, reply, deadline=+300 s, phase}` into a sync channel of 8, waits up to 300 s for the reply and writes one response line (control.rs:66-147). `phase` is a three-state atomic: 0 queued, 1 dispatched (set by the serve loop, main.rs:17654-17663), 2 done, 3 expired; a timeout before dispatch reports `admin action expired before dispatch`, after dispatch `admin action may have begun; inspect durable journal and exact attempt` (control.rs:128-141).

Clients: `admin_call` (control.rs:149-159, 310 s read timeout), `connect` (SSH stdio bridge; optional fixed attach line; reads the first server line before copying stdin, control.rs:544-593), `tool_connect` (one foreground `tool-v1` request with 1,810 s timeout, control.rs:597-642), `tool_result_connect` / `tool_ack_connect` over `attach terminal-v1 inspect` (control.rs:644-695).

Wire formats:

| direction | bytes | bound | source |
|---|---|---|---|
| client -> server, line mode | UTF-8 line ending `\n` (optional `\r` stripped) | 16,384 bytes | control.rs:509-538 |
| client -> server, foreground tool | `tool-v1 N\n` + N bytes of JSON `{"requestId":32-hex,"name":...,"arguments":...}` | N in 1..=262,144 | control.rs:445-460, main.rs:18108-18120 |
| server -> raw client | display text as-is | none beyond ACP's 1 MiB frames upstream | control.rs:432 |
| server -> framed client | JSONL `{"v":1,"type":"socket-attached"\|"output"\|"state"\|"prompt-complete"\|"tool-complete"\|"tool-acknowledged",...}` | 4 KiB for state/completion, 1 MiB for tool events | control.rs:414-433, 199-256 |
| admin client -> server | one line | 16,384 bytes | control.rs:112, 150 |
| admin server -> client | one line, any length | **unbounded on write, 16,384 on read** | control.rs:146 vs 158 |

#### terminal.rs (600 lines)

Presentation-only human client and the projection functions the controller uses for `state`/`prompt-complete` frames. `selected_state` (terminal.rs:18-85) derives `ready|busy|review-needed` from 15 journal keys (`pending`, `toolPending`, `providerPending`, `dispatchPending`, their `uncertain` flags, holds, `dispatchAttempt`, `settlementDue`, `roomAttempt`, `child`, `connection` fenced/detached, `hardReconnectPending`, `hermesSession.retentionIssue`/`pendingPrompt`, `unresolvedExternal`). `completion` maps success+ready to `completed`, review to `review-needed`, else `failed` (terminal.rs:103-122). Parsers for `terminal status`, `terminal hermes`, `terminal hermes-resident` (terminal.rs:124-151); bounded frame and input readers (153-214); `render_untrusted` prefixes every model line with `│ ` and prints control and bidi characters as `\u{..}` (216-240); `connect` runs a two-thread client with one prompt at a time, `/status`, `/new`, `/recover`, `/quit` (274-508). Projection omits paths, keys, receipts (test terminal.rs:514-543). Note that `selected_state` does *not* look at `resident_delivery`, `resident_completion`, `workspace_attempt`, `birth_*` or `application_api_attempt` markers, so `activity` can say `ready` while those are retained; quiescence.rs:173-267 is the complete inventory and the two are a near-twin.

#### public_status.rs (23 lines)

`project` = `terminal::state(journal,0,0,n)` minus ids plus `"type":"mini-grain-status-v1"` (public_status.rs:4-9); used for the raw `status` line (main.rs:17605-17614). The `expect` at public_status.rs:6 is on a `json!` object constructed two lines earlier and cannot fail.

### 1.2 The resident-in-a-room path

#### room_resident.rs (542 lines): the driver

Config `mini-hermes-room-resident-v1`: `controller`, `inbox`, `state`, `maxPrompts` (null = continuous, else 1..1000), `intervalSeconds` 5..3600, `maxPendingRequests`, `maxRequestsPerAuthor`, `discoveryPageSize` (room_resident.rs:8-30, 274-277). Startup: state directory must be a direct child of the controller `stateDir` (room_resident.rs:280), `resident.lock` flock exclusive nonblocking (287-288), config re-read after lock (290-292), `config_migration::ensure_resident_current` (293), then drain in a fixed order: preadmission refusal (300), completion (301), refuse if still pending (303), delivery (304), request reconcile (306), notices (307). Loop (308-351): prepare signed room inputs, dismissal -> cancel queue + `return_budget` + exit (310-315), select a request or fall back to maintenance (316-330), publish notices (333), refuse a selected request whose prompt would exceed the control frame (334-339), `prompt` (340), drain completion and delivery again (341-342), print `resident-completed` (345), reconcile and publish (346-347), sleep (350).

`assignment_fingerprint` strips `roomStatus` and the renderer's observation height so that budget movement does not buy another turn (room_resident.rs:45-69). `prompt_assignment` compacts the brief: context projection via `resident_context::brief`, doc gutter removal, transaction ids removed from member changes (71-87). `prompt` (108-182) is the exact send protocol described in question (2); a lost connection leaves `pending` durable. `return_budget` (187-210) runs `mini credit --action return` once under `return-operation.json`; an unconfirmed result keeps `returnPending`. `publish_notices` (247-269) pays (`mini_status` turn) then writes typed `say --status` notices, classifying failures by exact lookup.

The `ResidentState` struct (room_resident.rs:32-43) is the third copy of the resident journal schema (section 5.3). `ASSIGNMENT_PREFIX` (room_resident.rs:6) is the current instruction preamble; resident_delivery.rs:6 keeps the historical one.

#### resident_requests.rs (660 lines): request custody

Data: `Queue{binding, pending[Request], selected, lastAuthor, cursors, maintenanceRevision, maintenancePending}` in `requests.json` (resident_requests.rs:28-41), `Request{identity:{binding,cell,sequence,author}, entry, started}` (20-27), and `notices.json` `{next, notices[Notice]}` (124-145). Limits default 64/8/64 (8-17), whole-file bound 16 MiB with 512 KiB reserve (5-6). `select` (257-342): replaced binding cancels all unstarted (271-275) but refuses if a started request exists (272); pending requests are re-validated against current membership and author withdrawals (278-285); the selected one likewise (286-300); new addressed `say` entries above the accepted height are admitted in `(height,author,cell,sequence)` order, with per-author and total caps and the byte cap producing immutable `request-ID-refused.json` outcomes (301-321); round-robin by author string order (322-328); cursors advance from signed discovery (329-332); the brief carries exactly one member entry (334-341). Outcomes are immutable `request-{sha}-{status}.json` (88-98). Terminal transitions: `refuse_selected` (343-348), `receive_preadmission_refusal` (351-387), `reconcile` against controller `resident-delivered-OP.json` / `resident-final-refused-OP.json` (412-441), `dismiss` (402-409).

Notice state machine: `owe` adds one `owed` notice per status per request, one terminal per request, retention 256 with settled ones pruned first, else `skipped` (157-175); `publish_notices` assigns `op = "rs{next}"` durably before paying, then `pay(op)` then `write(op)`, recording `published|skipped` or leaving `owed` on uncertainty (184-208).

#### resident_context.rs (203 lines)

`collect` reads the program document and ≤ 8 declared documents with `mini_doc_context`, refuses incomplete projections, refuses references rebound from the accepted assignment, and returns `(program text, mini-context-bundle-v1)` (resident_context.rs:17-49). `brief` removes row text from the program source and from rows that exceed a 4,096-byte budget (52-68). `reviewed_arguments` validates `mini_doc_review` input: exactly `context` + `targets`, 1..16 sources, 1..8 targets, each target an ordinary `document` payload with 1..16 actions, 64 KiB context and 16 KiB request (74-118). `retain_review_file` is create-new-or-identical for review inputs (123-144).

#### resident_preflight.rs (337 lines)

Readiness snapshot and prompt-identity issuance. `preflight_resident_prompt` requires no active or retained work (quiescence status), a configured `hermes-acp` command whose program basename is `bwrap` or `sandbox-exec` and an argument ending `hermes-acp`, for scoped commands `prove_controller_unit`, the launch gate and launcher manager protocol, and a live private operator (`mini operator-status`, response `mini-operator-drain-v1` serving, PIDs nonzero, instance id and nonce 64-hex, Host and config hashes equal to local files) (resident_preflight.rs:34-58, 184-202). `prepare_resident_prompt` issues a random id and writes `resident-prepared-ID.json` binding task, config digest, binding digest and text digest (117-127). `enter_resident_prompt` writes `resident-entered-ID.json` before any native effect (137-148). `record_resident_preadmission_refusal` writes `resident-preadmission-refused-ID.json` with `admitted:false, effects:"none", modelRequests:0` (149-167). `resident_admission` is the read-only lookup (168-183). Free functions `prepare` and `lookup_refusal` are the driver-side admin clients (80-115). `Ready`/`checked` (6-32) are used only by tests (resident_preflight.rs:222-227); in non-test builds `checked` and `Ready` are dead code that the compiler should warn about.

#### resident_origin.rs (52 lines)

`ResidentPromptOrigin{residentPromptId, promptSha256, promptOperationId, sessionId}` (resident_origin.rs:3-10), `valid_digest` (64 lowercase hex, 11-13), `validate` (text digest equals, 14-19), `archive` writing `resident-origin-id-ID.json` at admission and `resident-origin-OP.STAGE.json` (21-29), `is_current` (30-33).

#### resident_completion.rs (939 lines)

Receives one model turn's completion into `resident.json` exactly once. `CompletedTurn` binds origin, binding/config digests, the ACP result (must be `end_turn` with `miniSourceFinalText`), provider replay digest, session before/after (resident_completion.rs:15-28, 107-141). `stage_resident_completion` runs inside the controller after reap/settle and before the session's `pendingPrompt` is cleared, writes the journal marker `residentCompletion` and `resident-completion-OP.source.json` (362-410). `transition` defines the only legal resident edit: `completed += 1`, `lastInput := pending.inputSha256`, `pending := null`, `lastCompletion := frame` (181-231). `receive_resident_completion` under the resident lock validates the receiving archive, takes fresh quiescence (allowing only the resident/hermes pending markers and the one stale fingerprint error, 254-287), archives the status content-addressed (300-329), restages the final delivery from the ACP result (524), publishes session, resident and receipt in that order (527-531). `drain` is the driver side (611-648). `require_source_receipt` lets the driver accept a `completed` frame only if the controller has the marker (560-575).

#### resident_delivery.rs (1,341 lines)

Posts the final answer as a paid room reply. `FinalRecord` (resident_delivery.rs:9-25) is built from the last settled metered provider replay for this prompt: request/response/meter re-hashed (480-519), the assignment recovered from the request's unique user message whose digest equals the origin's prompt digest under one of two prefixes (194-222), the addressed source entry selected (224-278, at most 20 entries, single recipient), the SSE final parsed strictly (71-143) and compared with the ACP capture (520-522). `AcpCapture` accumulates `agent_message_chunk` text since the last tool transition, ≤ 3,000 bytes, and overwrites any peer-supplied `miniSourceFinalText` (148-192). `stage_resident_final` -> `install_final` writes the journal marker `residentDelivery` then `resident-final-OP.json` (549-593). Receivers: `plan_resident_delivery` (read-only, 646-660), `deliver_resident_final` (793-881): check receipt, recover any exact prior room attempt, require fresh closed quiescence except the delivery marker, reuse an already performed resolution (`retained_final_resolution`, 673-697, with legacy proof `prove_ordinary_final_reply` via `mini operation-proof`, 702-751), else check the current signed reply number (753-775), bind it, allocate the op id (883-904) and `room_call_with_id("mini_say")`. `finish_delivery` writes `resident-delivered-OP.json` or `resident-final-refused-OP.json` before clearing the marker (906-934). Room-call admission hooks used by room_task.rs: `admits_room_call`, `room_origin`, `expected_reply` (382-448). `drain_completed` is the driver side (942-986).

#### resident_reconcile.rs (489 lines)

Clears `resident.json.pending` for one authoritative failed or review-needed completion frame whose `residentPendingSha256` binds the pending prompt, only when fresh quiescence shows the resident prompt as the sole retained marker and all purses unreserved (resident_reconcile.rs:78-183). Archive `failed-reconciliations/PRIORSHA-DECISION/` with before/after/controller/quiescence/decision/committed (209-272). Also exports `decode_resident_state` and `bound_failed_pending` used by resident_outcomes.rs:224 and session_failure.rs:357-358.

#### resident_outcomes.rs (416 lines)

`supersede_unsupported_completion`: operator request `mini-hermes-completion-supersession-v1` pairing a historical controller journal and resident file (by path + SHA) with one completed ordinal; requires the historical config to equal the current one except three provider operational fields, zero admitted provider requests, the frame without `residentOrigin`, an assertion of 100..4096 characters (resident_outcomes.rs:146-204); archives under `outcome-reviews/review-OP/` and writes `outcome-corrections/completed-ORDINAL.json` (206-303). `qualified_count = recorded - valid selections` (95-145) is read by the driver every loop.

#### room_task.rs (447 lines)

Room tools inside the AgentGrain controller. `Attempt` (room_task.rs:6-27) tracks `tool_lifecycle_started`, `payment_started`, `payment`, `write_started`, `submitter_stopped`, `resolution`. `validate_pins_with_workspace` requires room tools to share the delegated workspace, client, Host and socket pins and a private home inside `stateDir` (29-53). `require_acp_catalogue` checks the patched ACP adapter reports exactly the room tool names (57-71). `room_call_with_id` (164-226): reads pass straight to `RoomTools::read`; writes validate, check delivery admission, refuse if any room/workspace/tool custody is unresolved, journal the attempt, reserve the ToolTask purse, pay the turn, journal the payment, write with the stable reply guard, record the resolution. `record_room_resolution` persists before settling and settles the ToolTask purse at the configured `charge` if a payment exists or a write started, else "0" (102-121). `recover_room` resolves by exact operation record (127-158). `room_resolutions` capped at 64 (75, 118).

#### concierge.rs (757 lines)

`grain-runtime concierge step|serve CONFIG [SECONDS]` (main.rs:18024-18032, concierge.rs:602-631). Config `minidregg-concierge-controller-v1` with `mini`, `workspace`, `program`, `inbox`, `outbox`, `journal` (concierge.rs:45-60, 588-597). One pass (`step`, 337-543): adopt references, check the program names this workspace's subject and the room/till (348-364), read the room tariff now (359-361), read the till's incoming ledger for topic `renew` above the journal cursor (374-379, Host op 180), and for each entry: skip if already decided (389-392), journal a recovered refund found on the till's `refund` topic (397-409, Host op 100), parse the memo `room R week W at H` (105-115), read the tariff at H (410-423), read the room's standing members once (424-434), `decide` (147-180) and either refund with `mini credit --action refund` (439-457) or issue a member window with `mini credit --action renew` under proposal `renew-h{height}` (458-474). Free rooms: every `request-*.json` in the inbox naming the room issues `height + period` to a standing member (480-541). Journal: append-only JSONL, re-read every pass (202-280).

### 1.3 Operator reconciliation surfaces

#### quiescence.rs (987 lines)

`Status` (quiescence.rs:18-41) is the inventory: disposition (`active|evidence-required|restart-with-retained-uncertainty|closed-checkpoint`), retained marker names (22 journal slots by macro plus session, history and resident markers, 173-267), active work (child, prompt, foreground, startup recovery, custody gate, provider lease/gateway, 501-530), fresh signed observations of every configured purse (631-652), session fingerprint check (653-671), physical stop proof (546-571), `exact_recovery` list (52-134). `signed_unreserved_boundary` = grain status in {0,1,2,6} and reserved 0 (166-171). `ResidentGuard` (367-498) is the resident lock shared by every receiver: requires a private real directory that is a direct child of `stateDir`, opens `resident.lock` without following symlinks, flocks it, snapshots `resident.json` (≤ 64 KiB) and `requests.json` bytes, and `assert_unchanged` compares both. `client` is the admin CLI (377-396).

#### quiescence_transport.rs (717 lines)

Root-attested alternative query routing for quiescence only. `Admission` (quiescence_transport.rs:53-67) pins controller config path/digest/binding digest, `mini`/Host/Host-config digests, a profile, Store root and seed, public and management sockets, backend process identity and the public relay unit. `AuthorizedTransport::load` reads it with `custody::root_bytes` (327-342); `recheck` re-hashes images, runs `mini profile` and requires the Store/profile match (376-388), requires the public relay unit to be loaded, inactive or failed, MainPID/ControlPID 0, no job or trigger, empty cgroup (389-418), the public socket to refuse connections (269-312, 421), and `mini operator-status` on the management socket to match the admitted backend (422-433). `inspect_quiescence_transport` runs the normal locked inspection through that socket and re-checks afterwards (442-463).

#### session_failure.rs (705 lines)

See question (3). Mechanics: request `mini-hermes-session-failure-reconciliation-v1` (session_failure.rs:7-21) with optional `legacyForensicAdmission` (22-33); failure envelope `mini-hermes-observed-acp-failure-v1` (34-49) authenticated against `journalctl --user --output=json _SYSTEMD_INVOCATION_ID=…` (92-128): exactly one prompt worker unit message from `/usr/bin/systemd-run`, the error record's `_EXE` ending `/grain-runtime`, `_CMDLINE` ending ` serve CONFIG`, monotonic ordering, and the error MESSAGE parsed out of `grain-runtime: Hermes ACP outcome uncertain: Hermes ACP: {json}; local stop=Ok(ExitStatus(unix_wait_status(N))); Mini/tool/provider fence=Ok(())` (129-216). The historical runtime binary (≤ 256 MiB) must hash to the envelope (352-355). The unique settled provider replay must contain the resident's pending text as last user message (366-407). Fresh boundary must show exactly `["hermes_pending_prompt","resident_pending_prompt"]` retained (229-248). Archive `failed-session-reconciliations/prompt-P-decision-D/` with full journals, provider artifacts, trusted invocation, copies of `state.db`/`state.db-wal` up to 512 MiB each (426-487). Publication by `atomic_json` with outcome classification; an unknown outcome writes `failed-session-publication-uncertain.json` and sets a process-global atomic that freezes all mutation (268-294, 490-518).

### 1.4 Host/OS custody

#### systemd_manager.rs (568 lines)

Constants `PROTOCOL = "mini-controller-manager-v1"` and four env names (systemd_manager.rs:8-12). `Registration` and `RoomRouting` schemas (40-61) and `validate_registration` (80-109). `launch_client` = `grain-runtime controller-launch CONFIG REGISTRATION`: root-owned registration named `TASK.json`, launcher gate and manager protocol checks for scoped commands, live private operator, prints `mini-controller-launch-v1` projection with environment and hashes (113-157). `load` resolves registration-or-fixture (184-247); `initialize` binds the context once per process in a `OnceLock` (250-264); `current` re-loads and requires equality on every manager operation (265-281). `command` builds `/usr/bin/systemctl --system|--user --no-pager` with `LC_ALL=C` and UID-bound bus addresses (282-305). `worker_task` parses `mini-grain-tTASK-oOP` (310-323). `lifetime_environment` observes the controller's MainPID/ActiveState/InvocationID and exports `MINI_GRAIN_CONTROLLER_PID`, `MINI_GRAIN_CONTROLLER_INVOCATION_ID`, managers, unit, bus addresses and registration path to the launch gate (357-393). `require_launcher_protocol` runs `PROGRAM --controller-manager-protocol` when managers differ (404-417).

#### cgroup_stop.rs (443 lines)

Read-only physical snapshot described in question (4). Bounds: depth 16, 256 cgroups (cgroup_stop.rs:90-92); files ≤ 64 KiB (38-48); symlinks refused (108-110); filesystem magic `0x63677270` (168). Uses `/proc/self/fd/N` to enumerate (101), so Linux-only at runtime.

### 1.5 Tools

#### resource_tools.rs (1,579 lines)

Three unrelated things. (a) Operator-named signed reads: `AllowedResourceRead` (resource_tools.rs:440-450), `validate_reads` (452-496), `select_read` (498-516), `read_resource_with` builds a query intent in `stateDir/resource-read-NONCE/` and runs `mini query --view resource` with the tool custody key, optional `--presentation fn-inbox-resource`, then bounds the view (546-675). (b) Fixed-family content births (22-438, question 7). (c) Room tools: `RoomToolsConfig` (695-716), nine tool schemas (719-760), `validate_room_write` (763-788), `RoomTools::line_with_input` runs `mini shell --line "…"` under Hermes's workspace with model arguments interpolated only after decimal/name validation (902-943, 968-1035), `operation_record` (1039-1052), `lookup_operation` (1056-1077), `pay` (1082-1115), `write_with_reply_guard` (1129-1199), `lookup` (1203-1222), `write_status` (1228-1250), unmetered `notice` (1254-1257). `last_json` (865-874) and `rendered_links` (878-892) parse client output.

#### application_tools.rs (813 lines)

App/session birth planning: `BirthProfile`, `ApplicationNamespace` (3 targets, 6 capabilities), `SessionNamespace` (2 targets, 4 capabilities), families (application_tools.rs:16-110); `validate_families` checks every range against every other and against fixed peers (234-378); `planned_charge` = base + perBirth × resources (185-201); `plan_application_birth` and `plan_session_birth` build `applicationGrainBirth` / `applicationSessionGrainBirth` sources and the born members (484-632).

#### application_api_tools.rs (2,764 lines)

See question (6). Model input profile: exactly six fields, operator-selected application name, methods GET/HEAD/POST/PUT/PATCH/DELETE, relative path without `?#`, 18 ordinary headers including `cookie` (application_api_tools.rs:33-52), body ≤ 24 KiB (24, 1733-1754), path+query ≤ 8 KiB (1800). Transport frame: 4-byte big-endian length + JSON, request ≤ 256 KiB, reply ≤ 256 KiB or 1 MiB for `inspect` (1589-1591, 1627-1637). Transport discipline: socket ancestors must be root-, host-UID- or our-UID-owned and not group/world-writable unless root sticky (1521-1544); socket identity before and after connect; SO_PEERCRED (Linux) or getpeereid (macOS) must equal the route's host UID (1476-1507, 1570-1577); nonblocking connect with deadline, cancellation and a `getpeername` completion proof (1309-1474); a first-byte gate shared with hard interrupt classifies `BeforeSend` vs `Uncertain` (1164-1245, 1592-1622). Runs on an I/O thread (`PendingExchange`, 1652-1725).

#### shared_app_refs.rs (805 lines)

Operator-pinned names for applications born by another controller: `SharedApplicationRef` with four targets, four observe capabilities, an exact birth receipt pin and a share-issue pin of kind `bareEvent15` or `grainBackedEvent22` (shared_app_refs.rs:71-135); staged inputs must canonicalise inside `stateDir/shared-app-refs` and hash-match before and after lookup (306-334, 419-435); `resolve_with` performs birth lookup (op3), issue lookup (op29 or op55 via `share-issue-receipt-lookup` / `grain-share-issue-receipt-lookup`, 110-115) and four signed reads, each through a caller-supplied supervised runner (392-480). It explicitly creates no authority (shared_app_refs.rs:1-8).

### 1.6 Utilities

journal_io.rs, controller_digest.rs, controller_write_scopes.rs: see question (8). `controller_write_scopes::describe_config` emits `mini-controller-write-scopes-v2` with `credentialBroker`, `providerTableSha256`, provider row and route (controller_write_scopes.rs:8-30); `client` dispatches `CONFIG`, `preflight CONFIG REQUEST`, `receipt CONFIG REQUEST` to config_migration.rs (31-46); config_migration.rs:1350-1417 calls `describe_config` (shard B).

### 1.7 Tests in their own files

birth_lifecycle_tests.rs (143): three restart cases for the fixed-family birth no-submit marker, all against a stub `mini` (question 9). publication_refusal_tests.rs (821): eight cases covering workspace prepare-refusal recovery, foreground status tool against the real control socket with 18 requests and ack, next-generation worker policy, publication refusal release, pre-submit refusal on restart, definitive refusal then same-prompt retry, uncertain zero-charge release, uncertain disconnect.

### 1.8 Examples and fixtures

examples/current_birth_provider.rs (278): loopback OpenAI-compatible SSE provider on `127.0.0.1:PORT` that walks four fixed stages (create application, stop, create session, stop), persisting the stage before replying; synthetic usage 1/1 tokens (examples/current_birth_provider.rs:56, 141-154, 232-277; examples/README.md:14-20). No script in the tree builds or runs it (grep finds it only in its own README and source). fixture/broker-drop.rs (38): writes one MCP broker line and shuts down its read half (fixture/broker-drop.rs:28-36); used by receipt-recovery-acceptance.sh (fixture/RECEIPT-RECOVERY.md:15). fixture/hermes-acp (21): three-message ACP peer gated by ready/release files, used by acceptance.sh. fixture/hermes-acp-recovery (43): first process faults after creating `state.db`, second must `session/load` and receive the recovery block (`jq` checks). fixture/hermes-deterministic-acp (235): python3 ACP agent that executes `@import/@read/@write/@delegate/@export/@attempts/@tools` directives through the MCP server and keeps a sqlite transcript; used by hermes-journey.sh (docs/evidence/2026-09-30-hermes-participant). fixture/observe-mini-retry (18): polls `ps` for the exact `mini retry --attempt A --mode` process. fixture/sleep-fixed (7): `sleep 5|3600` worker for acceptance.sh.

### 1.9 Processes, sockets, files, directories and environment touched

| kind | name | module |
|---|---|---|
| socket (listen) | `controlSocket` (config), 0600 | control.rs:294-300 |
| socket (listen) | `stateDir/admin.sock`, 0600 | control.rs:66-72, main.rs:17507-17509 |
| socket (connect) | SPK resident host socket per route, peer UID checked | application_api_tools.rs:1546-1585 |
| socket (connect) | public Host socket probe (must refuse) | quiescence_transport.rs:269-312 |
| subprocess | `mini operator-status --socket … --host … --config …` | resident_preflight.rs:51-53, quiescence_transport.rs:422-432 |
| subprocess | `mini profile --host … --config …` | quiescence_transport.rs:379-387 |
| subprocess | `mini query … --view resource --dir stateDir/resource-read-N/attempt` | resource_tools.rs:580-603 |
| subprocess | `mini shell --socket --host --config --workspace --home --line "…"` | resource_tools.rs:906-943 |
| subprocess | `mini credit --action turn\|lookup-operation\|return\|adopt\|room\|ledger\|refund\|renew` | resource_tools.rs:1064-1103, room_resident.rs:195-199, concierge.rs:348-574 |
| subprocess | `mini fleet --action poll`, `mini workspace --action who` | concierge.rs:425, 548 |
| subprocess | `mini operation-proof --dir --operation-record --socket` | resident_delivery.rs:715-718 |
| subprocess | `/usr/bin/systemctl --system\|--user …` | systemd_manager.rs:282-305, quiescence_transport.rs:389-400 |
| subprocess | `/usr/bin/journalctl --user --output=json _SYSTEMD_INVOCATION_ID=…` | session_failure.rs:96-107 |
| subprocess | `LAUNCHER --controller-manager-protocol` | systemd_manager.rs:406-409 |
| file (root) | `/etc/mini/controllers/TASK.json` or `$MINI_GRAIN_CONTROLLER_REGISTRATION` | systemd_manager.rs:186-190 |
| file (root) | quiescence transport admission (any path, root-owned) | quiescence_transport.rs:328 |
| files | `/proc/self/cgroup`, `/sys/fs/cgroup/…/cgroup.{events,procs}` | main.rs:683-692, cgroup_stop.rs:38-65, quiescence_transport.rs:409-417 |
| files in stateDir | `journal.json` (+ `.journal.json.stage-*`), `resident-prepared-ID.json`, `resident-entered-ID.json`, `resident-preadmission-refused-ID.json`, `resident-origin-id-ID.json`, `resident-origin-OP.{admitted,session,…}.json`, `resident-completion-OP.{source,receiving,received,quiescence-SHA}.json`, `resident-final-OP.json`, `resident-delivered-OP.json`, `resident-final-refused-OP.json`, `resident-append-proof-P-O.json`, `resource-read-N/`, `failed-session-reconciliations/`, `failed-session-publication-uncertain.json`, `shared-app-refs/` | as cited in 1.2-1.5 |
| files in resident dir | `resident.lock`, `resident.json`, `requests.json`, `notices.json`, `request-SHA-STATUS.json`, `return-operation.json`, `delivery-request-SHA.json`, `completion-request-SHA.json`, `failed-reconciliations/`, `outcome-reviews/`, `outcome-corrections/` | as cited |
| files in room workspace/home | `room-operations/OP-{payment,write}.json`, `home/requests/hr-OP.txt`, `hr-OP-{context,review}.json`, `proposals/hr-OP/`, `attempts/hr-OP/` | resource_tools.rs:957-965, 1039-1052, 1158-1196 |
| env read | `MINI_GRAIN_CONTROLLER_REGISTRATION`, `MINI_GRAIN_CONTROLLER_MANAGER`, `MINI_GRAIN_WORKER_MANAGER`, `MINI_GRAIN_CONTROLLER_UNIT` | systemd_manager.rs:9-12 |
| env set (children) | the four above plus `MINI_GRAIN_CONTROLLER_PID`, `MINI_GRAIN_CONTROLLER_INVOCATION_ID`, `XDG_RUNTIME_DIR`, `DBUS_SESSION_BUS_ADDRESS`, `DBUS_SYSTEM_BUS_ADDRESS`, `LC_ALL` | systemd_manager.rs:282-305, 378-391 |


---

## 2. What it assumes of its surroundings

### 2.1 Host protocol operations

No file in this shard writes a Host frame. Every native read or write is a child process of the pinned `mini` client (resource-client) or a socket conversation with an SPK resident host. The table maps each dependency to the registry entry in `protocol/host-operations.json` and, where read, the Lean arm.

| op (registry) | how this shard reaches it | Lean side | agree? |
|---|---|---|---|
| 3 LOOKUP, fnDispatch | `shared_app_refs` birth lookup over the staged exact call (shared_app_refs.rs:292-299, 409-418); room write recovery via `mini shell --line "lookup hr-OP"` (resource_tools.rs:1209); `mini operation-proof` exact append lookup (resident_delivery.rs:715-718) | Host/Main.lean:2024 `| 2 | 3 => fnDispatch` (per shard A) | the Rust side checks only the client's decoded JSON (`type:"confirmed"`, `confirmation:"replayed"`, four receipt fields, shared_app_refs.rs:336-361); the decode is resource-client's |
| 5 AUTHORIZED_QUERY (signed reads) | `mini query --view resource` (resource_tools.rs:580-603); quiescence observations through `query_as_via` (quiescence.rs:644) | dispatchSession | view shape checked: `type:"resource"` with object `cell`, or `fn-inbox-resource-summary-v1` with array `entries` (resource_tools.rs:619-631) |
| 6 PROFILE | `mini profile --host --config` in transport recheck (quiescence_transport.rs:379-387) | dispatchSession | Rust requires `runtime:"minidregg-native"`, `nativeChecked:true`, canonical `domain` and `semantics` (quiescence_transport.rs:195-209); producer not read (Q8.7) |
| 29 APPLICATION_SHARE_ISSUE_LOOKUP / 55 GRAIN_SHARE_ISSUE_LOOKUP, fnDispatch | `share-issue-receipt-lookup` / `grain-share-issue-receipt-lookup` client verbs selected by pinned kind (shared_app_refs.rs:107-116) | not read | Q8.6 |
| 30 / 31 APPLICATION_CURRENT_BIRTH / APPLICATION_SESSION_CURRENT_BIRTH | sources planned by application_tools.rs:484-632, submitted by main.rs (shard A) | Host/Main.lean:7317-7324 per shard A | shard A verified the reply byte check |
| 96-99 FLEET_TURN_PLAN/ASSEMBLE/SUBMIT/LOOKUP, fnDispatch | room turn payment `mini credit --action turn --room R --account A --memo "op OP TOOL" --operation-record …` (resource_tools.rs:1082-1104); budget return `--action return` (room_resident.rs:195-199); concierge refund `--action refund` (concierge.rs:445-446); recovery `--action lookup-operation` (resource_tools.rs:1064-1068) | Host/Main.lean:6809-6837: 96 `fleetPlanAuthorizedLoaded` refuses with 255 `fleet-plan` refusal, 98 `fleetSubmitLoaded`, 99 `fleetLookupLoaded`; Kernel/FleetTurn.lean:1-24: a turn posts the pinned base tariff to the collector and may move value to another account, authority is a `transfer` capability | Rust classifies out-of-budget by finding the substring `bookRefused` in the client's stderr (resource_tools.rs:1109-1111) rather than a typed code; Lean has no notion of a room's `hermes/turn` price (Q8.1) |
| 100 FLEET_TOPIC_POLL | concierge `mini fleet --action poll --topic refund` (concierge.rs:548) | Host/Main.lean:6838-6849 | fine; the concierge scans the whole poll result each entry (concierge.rs:549-555) |
| 180 FLEET_INCOMING_LEDGER | concierge `mini credit --action ledger --topic renew --since CURSOR` (concierge.rs:375-378) | Host/Main.lean:6857-6869 `fleetIncomingAuthorizedLoaded` | Rust uses `height` as the decision key; the Lean view carries `transactionId` (concierge.rs:384) which is the right key (C-F1) |
| delegation (ordinary SUBMIT of a delegate intent) | concierge `mini credit --action renew … --proposal-id renew-h{H}` (concierge.rs:571-574; client honours the id, native/resource-client/src/credit.rs:895-905) | admission of the delegation under the founder's grant; `validUntil` enforced by the kernel (concierge.rs:24-26) | Lean does not check that a delegation followed a payment (concierge.rs:27-30, "K-BOOK-SLOTS") |
| none (not a Host op) | `mini operator-status` against the operator control endpoint (resident_preflight.rs:51-53, quiescence_transport.rs:422-432) | Rust expects `format:"mini-operator-drain-v1"`, `phase:"serving"`, `admissionClosed:false`, `drained:false`, nonzero `processId`/`hostProcessId`, 64-hex `instanceId`/`requestNonce`, `hostSha256`/`configSha256` (resident_preflight.rs:34-46) | producer is resource-client `serve-operator`; not read |
| room client verbs (via `mini shell --line`) | `room ls … --import --json`, `room status`, `credit ACCOUNT`, `tail --in R --json [-n N] [--since H] [--entry C:S] [--discover-json -]`, `doc context`, `doc show`, `doc link`, `doc append`, `doc review`, `submit`, `lookup`, `say --in R [--to] [--re] [--expect-re-cell C --expect-re-sequence S] [--status S] --operation-record F --file F` (resource_tools.rs:968-1035, 1129-1257) | each resolves to SUBMIT/LOOKUP/queries inside the client | text is passed by file, never interpolated (resource_tools.rs:1139, 1188, 1244); interpolated arguments are validated decimals or `[A-Za-z0-9-]{1,64}` names (resource_tools.rs:829-845) |

SPK resident host protocol (not a Host op; `native/spk-host` is the peer):

| message | grain-runtime | spk-host | agree? |
|---|---|---|---|
| v2 request types `hello`, `dispatch`, `inspect` with `protocol:"mini-spk-agent-api-v1"`, snake_case `operation_id`, `body_hex`, `binding_sha256` | application_api_tools.rs:30, 74-76, 144-166 | `native/spk-host/src/agent_api_wire.rs` (not read in full) | assumed by the unit tests here only |
| v2 replies `binding`, `http`, `refused`, `uncertain`, `inspection` (kebab tag `type`) | `HostReply`, application_api_tools.rs:505-545 | same file | not verified here |
| v3 request types `hello-v3`, `dispatch-v3` with camelCase `operationId`, `bindingSha256`, `bodyHex` | application_api_tools.rs:78-80, 128-142 | `Request::{HelloV3, DispatchV3, InspectV3}` (native/spk-host/src/agent_api_lifetime_wire_v3.rs:74-100) | yes |
| v3 replies `binding-v3`, `http-v3`, `refused-v3`, `uncertain-v3` | expected by main.rs:8757, 8864 and `verify_lifetime_binding_reply` (application_api_tools.rs:431) | `Reply::{BindingV3, HttpV3, RefusedV3, UncertainV3}` (agent_api_lifetime_wire_v3.rs:179-225) | **no**: the transport rejects them before main.rs sees them, because `exchange_once_guarded` first decodes the payload as the v1 `HostReply` (application_api_tools.rs:1646-1647) whose variants are only `binding|http|refused|uncertain|inspection` (C-F3) |
| framing | 4-byte big-endian length + JSON (application_api_tools.rs:1589-1591) | not read | Q for spk-host reader |

### 2.2 Operating system

Linux-only at runtime: cgroup v2 (`/proc/self/cgroup` `0::` line, cgroup2 magic, `/proc/self/fd/N` directory listing; main.rs:683-692, cgroup_stop.rs:101, 159-172), systemd system and user managers via `/usr/bin/systemctl` with `/run/user/UID/bus` and `/run/dbus/system_bus_socket` (systemd_manager.rs:282-305), `journalctl --user` (session_failure.rs:96), `/sys/fs/cgroup/.../cgroup.events` (quiescence_transport.rs:409-417), `SO_PEERCRED` (application_api_tools.rs:1476-1496), nonblocking `AF_UNIX` connect with `SOCK_CLOEXEC` (application_api_tools.rs:1345-1349, quiescence_transport.rs:281-287), `flock` (quiescence.rs:439, room_resident.rs:288, resident_completion.rs:616-645). macOS compiles: `getpeereid` and `sun_len` branches (application_api_tools.rs:1336-1374, 1498-1507), `public_closed` refuses (quiescence_transport.rs:313-316). Required helpers on the box: `/usr/bin/systemctl`, `/usr/bin/journalctl` (only for session-failure), `/usr/bin/systemd-run` (named in the trusted-record check, session_failure.rs:158, 188), a `bwrap` launcher and its `launch-gate` (resident_preflight.rs:191-199).

### 2.3 Network services

None directly. Model providers are reached by the controller (shard B); this shard's only TCP code is the loopback test provider (examples/current_birth_provider.rs:56). SPK resident hosts are local Unix sockets. Solana, Discord, fn/NNTP and gitweb are not touched (gitweb is consumed through the app-API raw-reply mode, main.rs:8895-8915).

### 2.4 Files and configuration the operator must provide

Controller JSON fields consumed here: `controlSocket`, `stateDir`, `hostSocket`, `mini`, `host`, `hostConfig`, `commands[]` (a `hermes-acp` entry with `systemdScope`), `toolTask.room` (`RoomToolsConfig`: `restrictTools`, `mini`, `host`, `hostConfig`, `socket`, `workspace`, `home`, `room`, `account`), `toolTask.allowedReads`, `allowedBirthFamilies`, `allowedApplicationFamilies`, `allowedSessionFamilies`, `registeredSharedApplications`, `allowedApplicationApiRoutes`, `allowedApplicationLifetimeRoutes`, `currentBirthHostSha256`, `agentApiHostSha256`, `lifetimeApiHostSha256` (struct literal in resource_tools.rs:1361-1384), `providerTask.credentialBroker` and `providers` (controller_write_scopes.rs:18-28). Separate files: the resident config `mini-hermes-room-resident-v1` (room_resident.rs:8-26), the concierge config and program (concierge.rs:45-73), the root registration (systemd_manager.rs:40-61), the quiescence transport admission (quiescence_transport.rs:53-67), staged shared-app calls/ingress under `stateDir/shared-app-refs` (shared_app_refs.rs:306-334), the room workspace `workspace.json` with Host/config/key/subject/socket pins (room_task.rs:34, validated in main.rs).

### 2.5 Other crates

`minidregg-compatible-upgrade-custody` (`canonical`, `root_bytes`: systemd_manager.rs:5, 89, 145, 221; quiescence_transport.rs:7, 150, 328; controller_write_scopes.rs:9, 19); `minidregg-signed-api-path` (`checked_prefix`, `route`: application_api_tools.rs:177, 205, 579, 853, 1125); `sha2` directly (application_api_tools.rs:9, shared_app_refs.rs:14, controller_digest.rs:2); `libc`. Runtime binaries: `mini` (resource-client) for everything native; spk-host as the application-API peer.

---

## 3. Does it decide anything semantic?

Numbering continues shard A's V1-V8 as C-V1… Only the "IS the decision" class is a law violation.

### 3.1 Violations: Rust IS the decision

| # | site | what Rust decides | Lean side today | what the Lean counterpart should be | blast radius if wrong |
|---|---|---|---|---|---|
| C-V1 | concierge.rs:147-180 (`decide`), applied at 436-474; window arithmetic 177-178; free-room issuance 516-536 | whether a payment buys membership: asset equals the workspace's pinned credit asset (156-158, asset read from the Host config file, 325-334), quote within 64 heights (133-142, `PRICE_SLACK` 95), quoted price equals the tariff at the quoted height (168-170), amount ≥ week (171-173), payer is a standing member or room `open` (174-176); and the window `notAfter = max(current, height) + period` where `current` comes from the concierge's own local journal (177, 237-242); refund amount = full payment | the delegation is admitted under the founder's grant to the concierge and `validUntil` is enforced (concierge.rs:24-27); "What the kernel does not yet check is that each delegation followed a payment (K-BOOK-SLOTS, PLACE §4.8)" (concierge.rs:27-30) | a Lean "paid slot" admission: the delegate intent carries the ledger entry (transaction id) and Lean checks amount, asset, tariff-at-quote and consumes the entry once (a nullifier), so a concierge cannot issue unpaid or skip paid entries; the money reader calls this D2 (docs/review/2026-10-26-native-crates/resource-client--C-pay-credit-money.md:582-588) | room membership for the whole room; a faulty concierge can issue windows for free, keep payments (C-F1), or shorten windows after losing its journal |
| C-V2 | room_task.rs:164-226 with resource_tools.rs:686-690, 698-701 | that every room write is preceded by one turn payment from Hermes's budget account to the till, and that `restrictTools:false` (the default, resource_tools.rs:700-701) still lets the model use generic workspace writes that bypass the turn payment ("Generic workspace mutations would bypass the room turn payment", resource_tools.rs:698-699); when `account` is absent writes are "not metered" (resource_tools.rs:712-715, 1083-1085) | each payment and each write are separately admitted; Kernel/FleetTurn.lean:1-24 prices only the deployment base tariff and has no room `hermes/turn` notion; the amount transferred is chosen by the client from the room's account fields | either a Lean law on the room's documents/stream that requires a same-transaction turn payment (a joint transaction), or declare the turn price a client convenience and stop calling it a price | the room founder's budget model; a prompt-injected resident with `restrictTools:false` writes without paying |
| C-V3 | room_task.rs:110-112 | the ToolTask charge for a room write: the configured `toolTask.charge` whenever a payment exists or a write started, including `refused` outcomes such as `paid-but-write-not-started` (room_task.rs:146-149) and Host refusals (resource_tools.rs:1218-1220); "0" only if no payment was made | Lean settles any charge ≤ reserve (A-V1) | same as A-V1/A-V2: a Lean price for refused or never-written operations | members' grain budget charged for refused room writes, on top of the turn already paid |
| C-V4 | resource_tools.rs:1203-1222 (`RoomTools::lookup`), consumed by room_task.rs:153 | for document writes: no `call.bin` => `refused, not-submitted`; client lookup prints `absent` => `refused, absent-after-submitter-stop`; client exit code 3 or `outcome.json` `refused` => `refused, host-refusal` | nothing certifies non-commit (same as A-V3) | a Lean never-admissible witness for the exact call | if the old submitter's frame is still in a concurrent Host connection, the write is recorded refused, the hold released and the model may write again: one intent, two effects |
| C-V5 | resident_requests.rs:257-342 | which room member's request gets a paid model turn and when: FIFO per author, round-robin by author string order (322-328), 64 pending / 8 per author, overflow refused with an immutable outcome (308-311) | none (local custody) | arguably resource scheduling; acceptable in Rust if the limits are labelled as operator policy, as RESIDENT-REQUESTS.md:15-23 does | fairness only; no authority |
| C-V6 | resident_requests.rs:88-98, 157-208 with room_resident.rs:247-269 | spending the room budget on status notices: up to three paid turns per request (`queued`, `started`, one terminal), paid with tool `mini_status` (room_resident.rs:262) | each turn admitted by Lean | policy; should at least be an operator switch; today unconditional whenever an account is configured | the founder's Hermes budget drains three turns faster per request than the replies themselves |
| C-V7 | resident_delivery.rs:71-143, 520-522, 549-563 | that a model turn produced a deliverable final: SSE with one generation id, one choice index 0, no tool calls, `finish_reason:"stop"`, `[DONE]`, non-empty text ≤ 3,000 bytes, equal to the ACP capture since the last tool transition | the final `mini_say` is admitted natively | agent-protocol semantics (like A-V8); acceptable in Rust | a truncated or tool-trailing turn is not delivered; the request stays started (C-F5) |
| C-V8 | terminal.rs:18-122, consumed by resident_reconcile.rs:126-136 and room_resident.rs:159-177 | that a prompt `failed`, `completed` or `review-needed`, computed from journal markers, not from any native outcome | none | local presentation; acceptable only as presentation, but resident_reconcile uses it to clear custody | a `failed` label lets an operator clear the resident pending marker (with fresh quiescence), never native state |

### 3.2 Mirrors: Rust pre-checks, Lean is still the gate

| site | what Rust checks | the Lean gate |
|---|---|---|
| resource_tools.rs:84-259, application_tools.rs:234-378 | birth namespaces do not overlap each other, configured reads/publications or peers; `maxBirths` ≤ 1,024; tariff base > 0 | Lean authors the descriptor from the source and the Host-config tariff (A-V6, Kernel/NativeHostGrainBirth.lean:48 per shard A); whether Lean refuses an ID already in use is Q8.5 |
| resource_tools.rs:281-296, application_tools.rs:184-201 | reserve bound = base + perBirth × n | Lean derives the actual fee (comment application_tools.rs:184) |
| resource_tools.rs:763-788, resident_context.rs:74-118 | room write arguments before paying | the client authors and Lean admits each write against grants and the document law |
| room_task.rs:57-71 | the patched ACP adapter exposes exactly the room tools | nothing native; this is a worker confinement check |
| application_api_tools.rs:1758-1848 | HTTP method/path/header/body profile before reserving | event21/event26 admission of the dispatch (shard A) |
| application_api_tools.rs:601-632, 423-470 | SPK host binding equals operator pins and hashes correctly | "never substitutes for event21's fresh native admission" (application_api_tools.rs:598-600) |
| application_api_tools.rs:932-1090 | source reserve and paid plans equal the retained forward call, route pins and signed current roots | native op46/event26 admission (comments application_api_tools.rs:472-474, 1029-1032) |
| shared_app_refs.rs:204-284, 336-361 | references name allowlisted families, distinct observe grants, receipts match pins | op3/op29/op55 historical lookups and Lean session-birth admission (shared_app_refs.rs:1-8) |
| resident_preflight.rs:184-202 | no retained work, confined launcher, controller unit, private operator before a resident prompt | the prompt's native reserve/settle; "preflight is a snapshot, not a reservation" (RESIDENT-REQUESTS.md:70) |
| quiescence.rs:166-171 | purses unreserved at status 0/1/2/6 with reserved 0 | the signed Host view is the input; the status code meaning is Lean's (Q8.8 of shard A) |

### 3.3 Correct deferrals worth naming

Room payment and write recovery never resend: an unknown payment is looked up by its exact operation record, never re-paid (room_task.rs:123-158, resource_tools.rs:1054-1077). Resident delivery allocates one durable operation id before the room call and re-enters by lookup (resident_delivery.rs:883-904, 858-862). Resident prompts get a fresh source id and an entered fence before any reserve, so a prompt cannot run twice (resident_preflight.rs:117-148, main.rs:14322-14336). Shared application references are hints that never enter `born_resources` (shared_app_refs.rs:1-8). The app-API transport distinguishes "no byte sent" from "maybe sent" and never retries (application_api_tools.rs:1164-1166, 1509-1511).

### 3.4 Physical decisions Rust legitimately owns, made brittly

`pay` classifies out-of-budget by substring `bookRefused` in stderr (resource_tools.rs:1109); `LineRun::ending` picks the first line starting `refused: `, `error: `, `usage: `, `undecided: `, `not here: ` (resource_tools.rs:815-826); `lookup` treats client exit code 3 as a Host refusal (resource_tools.rs:1218); session_failure parses a historical `Debug` rendering of `Result<ExitStatus>` (session_failure.rs:201-209). Each couples Rust policy to another program's human-readable output.

---

## 4. Flaws noticed

Severity is my judgment for a small public demo. "C-F" numbers are this shard's.

### C-F1 (high, money): the concierge drops or keeps payments

1. **Same-height payments.** The decision key is `ledger:{height}` (concierge.rs:389) and the cursor is the greatest decided height (concierge.rs:243-246, 272-274). If two `renew` payments land at the same height, the first is decided and journaled; the second hits `journal.decided.contains("ledger:H")` and is skipped (concierge.rs:390-392) in this pass and every later one. The payer is neither issued a window nor refunded; the till keeps the money, contradicting "the till never keeps a payment it did not honour" (concierge.rs:16-17). The proposal id `renew-h{height}` (concierge.rs:459) and the refund memo prefix `refund room R ledger:H ` (concierge.rs:401) collide the same way, so even fixing the key alone would make the second issue look up the first proposal (the client honours `--proposal-id`, native/resource-client/src/credit.rs:895-905) and fail the window check (concierge.rs:578-583), and `published_refund` would match the first entry's refund as the second's. The Lean view gives each entry a `transactionId` (concierge.rs:384); key, proposal and memo on it.
2. **Failed refunds are final.** When `mini credit --action refund` fails, the concierge appends `{"decision":"refund-failed",…}` and returns the error (concierge.rs:451-455). On the next open, any `decision` other than `deciding` inserts the key into `decided` (concierge.rs:229-247), and `append` does the same live (262-276). The entry is never retried: a transient Host outage forfeits the payer's money. Conversely, if the refund was actually sent and the client merely failed afterwards, nothing double-pays, but nothing records it either (no `refunded` line).
3. **`refunding` is write-only.** `Journal::refunding` (concierge.rs:209-211) is filled from `deciding` lines with a refund (230-233, 263-265) but read only to set the `resumed` flag on an already-found refund (concierge.rs:405). The doc comment says begun refunds are "never re-sent (a refund is a transfer, not an exact lookup)" (concierge.rs:209-210). The real guard is the poll of the `refund` topic (397-409); if the poll does not show a sent refund (bounded poll window, lag), the loop decides again and sends a second refund.
4. **Windows from a local journal.** `current` for the extension is the concierge's own `windows` map (concierge.rs:437, 237-242), not the Host's grant view. Losing or rotating the journal file makes renewals start from the payment height and shortens paid time; restoring an old journal re-decides newer entries.
5. **Unbounded rereads.** Every 5 s pass re-reads the whole JSONL journal (concierge.rs:225) and the whole `refund` topic once per undecided entry (concierge.rs:548-555); `Runner::mini` has no timeout (concierge.rs:289-292).

### C-F2 (high, liveness): a failed admitted resident prompt wedges the room's resident forever

Sequence: a request is selected and `started` (room_resident.rs:137-139, resident_requests.rs:394-401); the prompt is admitted (origin recorded, main.rs:14576-14583) and ends without `end_turn` (provider error, ACP failure, tool fault). The controller emits a `prompt-complete` frame with `outcome:"failed"` or `"review-needed"` and the `residentOrigin` (main.rs:17870-17880); the driver retains it and exits with an error (room_resident.rs:176-177). On restart it refuses while `pending` is set (room_resident.rs:303). The operator runs `resident-reconcile failed` which clears `pending` (resident_reconcile.rs:172-174). On the next start `resident_requests::reconcile` sees the selected request `started`, a completion frame whose origin matches, and looks for `resident-delivered-OP.json` or `resident-final-refused-OP.json` (resident_requests.rs:420-430); neither can exist because no final was ever staged (staging requires `end_turn`, main.rs:14977-14983, resident_delivery.rs:553-555). It returns "selected request completed without native terminal receipt; recovery required" and the driver exits at room_resident.rs:306, on every start. There is no request status `failed` (resident_requests.rs:154), no receiver that closes a started request after an admitted failure, and `select` refuses to replace the assignment while a request is started (resident_requests.rs:272). RESIDENT-REQUESTS.md:47-49 calls this "This blocks only that resident/controller", which for a room means its Hermes is dead until someone edits `requests.json` by hand. The fix is a typed `failed-after-admission` request outcome sourced from the controller's own per-prompt failure record (the artifact SESSION-FAILURE.md:33-34 promises), paid model turns already settled.

### C-F3 (high for v3, fail-closed): the lifetime app-API path is dead in two independent places

1. **Reply tags.** `exchange_once_guarded` validates every reply by `serde_json::from_slice::<HostReply>(&payload)` (application_api_tools.rs:1644-1647). `HostReply` is `#[serde(tag="type", rename_all="kebab-case", deny_unknown_fields)]` with variants `Binding`, `Http`, `Refused`, `Uncertain`, `Inspection` (application_api_tools.rs:505-545). spk-host's v3 replies are `binding-v3`, `http-v3`, `refused-v3`, `uncertain-v3` (native/spk-host/src/agent_api_lifetime_wire_v3.rs:179-225). Every v3 Hello therefore returns `TransportError::Uncertain("host reply wire: …")`; main.rs reports it to the model and drops the call (main.rs:8735-8751). The v3 unit test checks `verify_lifetime_binding_reply` on a hand-built JSON value (application_api_tools.rs:2221-2283) and never sends it through the transport. `__mini_gitweb_http_raw` uses the same lifetime transport (shard A, main.rs:8895-8915), so it is dead too.
2. **Field name.** `verify_lifetime_reserve_inspection` compares `httpOperationId` with `retained_forward.get("operation_id")` (application_api_tools.rs:989-996). In production `retained_forward` is the retained `dispatch-v3` frame, which main.rs requires to carry `operationId` (main.rs:4134-4136) and which `lifetime_dispatch_request` writes as `operationId` (application_api_tools.rs:136-137). The lookup returns `None` and the reverse reserve fails with "retained lifetime forward operation ID absent" at main.rs:4374. The test passes because it builds the retained frame with the v1 `dispatch_request` (application_api_tools.rs:2335-2336), which uses `operation_id`.

Both failures refuse rather than move money, so this is dead code, not a hole; but the docs/evidence/2026-09-27-agent-lifetime-* directories cannot describe the current source.

### C-F4 (high, liveness): admin reply bound makes resident delivery fail deterministically

`serve_admin_connection` writes the whole response with `writeln!` (control.rs:146); `admin_call` reads it with `read_line`, bounded to `MAX_LINE = 16_384` bytes (control.rs:149-158, 19, 509-511, 526-531). `plan_resident_delivery` returns `plan` (the full `FinalRecord`, including `source_entry` with the requester's text up to 12,000 bytes, resident_requests.rs:237, and `final_text` up to 3,000) plus `arguments` (the final text again) (resident_delivery.rs:655-658). With a 10 KB question and a 3 KB answer the JSON exceeds 16 KiB (more with escaped newlines), `admin_call` returns "control line too long", and `drain_completed` fails at resident_delivery.rs:956-959 before building the request. The driver calls it before every loop and on startup (room_resident.rs:304, 342), so the resident is stuck permanently, though the delivery marker blocks all other prompts (RESIDENT-DELIVERY.md:20-22). The same bound applies to `grain-runtime resident-delivery plan`, `quiescence status|inspect` (a full `Status` with all observations) and `config migrate` replies; mutating commands whose reply exceeds 16 KiB report failure after the durable action happened. Fix: make the admin protocol length-prefixed or raise the read bound to the write's reality, and stop embedding the requester's text in the plan.

### C-F5 (medium): one-incident receivers sit on the hot path

`session_failure::ensure_publication_known` runs before every serve-loop input and every `save` (main.rs:17597-17599, 6916-6918, also resident_completion.rs:549-550). If `failed-session-publication-uncertain.json` exists (written by `mark_publication_uncertain`, session_failure.rs:283-294) or the process-global `PUBLICATION_UNCERTAIN` is set (268), the controller refuses all mutation, and "this command supplies no generic reset" (SESSION-FAILURE.md:103-105). `resident_outcomes::qualified_count` reads and re-hashes every correction and decision file on each resident loop (room_resident.rs:308, 345, 350; resident_outcomes.rs:95-145). Both receivers exist for single historical incidents (SESSION-FAILURE.md:96-98, RESIDENT-OUTCOMES.md:20-27).

### C-F6 (medium): session_failure trusts log text as evidence

The receiver authenticates a failure by finding exact records in `journalctl --user` for one invocation and parsing the error string emitted by an older binary (session_failure.rs:96-128, 198-214). User-journal records with `_UID` equal to ours (session_failure.rs:150) can be written by any process of that UID (`systemd-cat`, `logger`), so "trusted invocation records" are only as trusted as the service account; `_SYSTEMD_INVOCATION_ID` and `_EXE` are journald-trusted fields, `MESSAGE` is not. It also hard-codes `/usr/bin/journalctl --user` (so a system-manager controller, the SYSTEMD-MANAGERS.md:25-26 production shape, has no records there) and the worker unit naming `mini-grain-t{task}-o{op}.service` (session_failure.rs:142-145). SESSION-FAILURE.md:96-98 describes a "private qualification request preparation helper … restricted to reviewed task8781 / operation94 / invocationc2fdf82e…"; a repository-wide search finds that invocation id and the request formats only in SESSION-FAILURE.md and session_failure.rs, so the helper the doc relies on is not in the tree.

### C-F7 (medium): control socket hygiene

1. Over-cap connections are accepted and dropped without a word (control.rs:318-321; admin 83-86), so a client sees EOF where it expected a refusal; `connect` then reports "attachment closed before a response" (control.rs:562-563).
2. `connect` recognises refusals by exact text, but its expected string `first line must be attach hard|soft` (control.rs:565) is a prefix of what the server sends (`first line must be attach hard|soft or attach terminal-v1 hard|soft`, control.rs:366); harmless today only because `connect` always sends a valid first line.
3. An `inspect` attachment occupies the single attachment slot (control.rs:376-390), so `grain-runtime tool-result` or `tool-ack` polling blocks every hard/soft attach and the room resident's prompt attach while it waits (up to 30 s read timeout, control.rs:667-669).
4. The socket is bound before it is chmodded (control.rs:298-300); between the two calls its mode follows the process umask. The shipped unit sets `UMask=0077` (deploy/grain-host/mini-grain-controller@.service:13) and `stateDir` is 0700 (main.rs:6829), so this is defence in depth only.
5. `read_line_bounded` reads one byte per `read(2)` (control.rs:513-538): 16 K syscalls for a maximal line.
6. The room resident and a human connector exclude each other: the resident's `attach terminal-v1 soft` gets the non-JSON line `controller already has an attachment`, `terminal::read_frame` fails on it (terminal.rs:175-176), and the driver exits with an error (room_resident.rs:113-116).

### C-F8 (medium): resident custody leaks files

Per resident prompt the controller writes `resident-prepared`, `resident-entered`, `resident-origin-id`, `resident-origin-OP.admitted`, `.session`, `resident-completion-OP.source`, `.receiving`, `.received`, one `.quiescence-SHA` per receiving attempt, `resident-final`, `resident-delivered` (resident_preflight.rs:124, 146; resident_origin.rs:21-29; resident_completion.rs:409, 519-529, 326-327; resident_delivery.rs:567-591, 929-930); the driver writes `completion-request-SHA`, `delivery-request-SHA`, `request-SHA-STATUS` (resident_completion.rs:631-632, resident_delivery.rs:969-970, resident_requests.rs:93-94); each signed read creates `stateDir/resource-read-N/` (resource_tools.rs:561-562); `resident prepare` writes a file per call even if the prompt is never sent (resident_preflight.rs:117-127). Nothing is ever pruned. A continuous resident (`maxPrompts:null`, RESIDENT-REQUESTS.md:10) grows `stateDir` by more than a dozen files per turn indefinitely. `room_resolutions` is capped at 64 (room_task.rs:118) and notices at 256 (resident_requests.rs:122), so those are fine.

### C-F9 (medium): unbounded blocking children on the controller thread (A-F2, in this shard)

`require_private_operator` (resident_preflight.rs:51-53), `RoomTools::line_with_input` (resource_tools.rs:908-937), `lookup_operation` (1064-1068), `pay` (1086-1104), `prove_ordinary_final_reply`'s `supervised_json_command` is cancellable but the room tools are not; `command_json` in quiescence_transport (257-266) and the systemctl call (389-401); `journal_records` waits for `journalctl` with no deadline (session_failure.rs:120). The room tools run inside `tool_call` on the single serve loop, so a hung `mini shell` hangs the controller (the custody gate that shard A says cancels other children is not used here).

### C-F10 (low): `RoomTools::line_with_input` can deadlock

It writes the whole stdin payload (≤ 256 KiB discovery cursor) before reading stdout or stderr (resource_tools.rs:928-937). If the client emits more than a pipe buffer of output before it finishes reading stdin, both block. The client probably reads the cursor first; nothing here guarantees it.

### C-F11 (low): journal stage files are retained forever

See question (8): journal_io.rs:1-2, 34-42; every `atomic_json` file shares the policy (main.rs:2554-2557).

### C-F12 (low): `write_new` partials become permanent refusals

`write_new` creates the file and then writes (main.rs:2269-2280); a crash or ENOSPC mid-write leaves a partial file, and `retain_exact_private` thereafter refuses forever because the bytes differ (main.rs:2285-2297). Every resident receipt goes through `retain` -> `retain_exact_private` (resident_delivery.rs:61-67, resident_completion.rs:82-88). This is the stated design ("A partial prior write stays explicit", main.rs:2282-2284), but there is no receiver to inspect and clear it, so a disk-full event during a receipt write is another permanent resident wedge.

### C-F13 (low): two journal publication primitives for one file

`Runtime::save` uses `atomic_json` -> `journal_io::write` (random stage name, identity rechecks, main.rs:6916-6919); `session_failure` calls `atomic_json` directly (session_failure.rs:490); resident_completion publishes via `config_migration::publish_bytes`, which uses a deterministic `.journal.json.migration-TAG.tmp`, no symlink/hardlink checks on the target and a plain `fs::rename` (resident_completion.rs:548-557, config_migration.rs:156-171). Two crash-recovery stories for one file.

### C-F14 (low): small correctness and hygiene items

- `RoomTools::request_file` writes model text with default permissions (umask), `remove_file` then `fs::write` (resource_tools.rs:958-964); review inputs instead use 0600 create-new (resident_context.rs:126).
- `bounded_decimal(arguments,"cell",78)` accepts leading zeros (resource_tools.rs:837-845, 1000), unlike `decimal` (main.rs:2559-2561).
- concierge `number(&then,"week").unwrap_or(0)` turns a missing tariff field at H into "free room" and refunds (concierge.rs:417, 165-167); `period` falls back to the *current* period (418).
- concierge `u128` additions on Host-supplied numbers (`from + priced.period`, concierge.rs:178; `height + period`, 526) are unchecked (wrap in release builds).
- `resource_tools::tests::room_tools_are_seven_and_writes_are_metered` asserts nine names (resource_tools.rs:1539-1541).
- control.rs tests create fixed `/tmp/gt-PID`, `/tmp/gf-PID`, `/tmp/ga-PID` directories with `create_dir(...).unwrap()` (control.rs:705-706, 769-770, 915-916): a crashed run poisons the next run with the same PID; resident_requests tests use PID-only names (resident_requests.rs:445).
- publication_refusal_tests.rs needs `/usr/bin/openssl` and `jq` (publication_refusal_tests.rs:71, 304), so the suite is not hermetic.
- `terminal::selected_state` ignores resident, workspace, birth and app-API markers (terminal.rs:24-53) while quiescence.rs:173-267 counts them, so the terminal can show `ready` while the controller would refuse a prompt.

### Things checked and found sound

- Model text cannot forge controller events: framed output is wrapped in an `output` frame (control.rs:429-431); state/completion frames are controller-authored and bound to attachment and request ids (control.rs:237-256, terminal.rs:250-256, 454-501); the room resident ignores unscoped frames for completion (room_resident.rs:96-104); tests control.rs:767-815, room_resident.rs:386-394.
- Hard EOF interrupts exactly once and before any replacement attachment (control.rs:484-507; test 817-883).
- No `unwrap`/`expect` on untrusted bytes in non-test code: the 35 non-test sites (the four in resident_preflight.rs:204-212 are `#[cfg(test)]` fixtures) are on just-set journal fields (room_task.rs:109, 114, 189-213; resident_delivery.rs:871, 900), `json!` objects (public_status.rs:6, room_resident.rs:317-327, resident_requests.rs:336-337), or invariants established by validation (resident_requests.rs:314-325 after `request()` at 229-242; resident_outcomes.rs:287 on a value set at 268; session_failure.rs:262, 412 after `planned_session` at 250-255).
- Room payments and writes are never resent; an unknown payment stays `owed`/uncertain with the ToolTask hold retained (room_task.rs:398-413 test, 155-157).
- cgroup proof is fd-relative, identity-rechecked and refuses symlinks and non-cgroup2 roots (cgroup_stop.rs:23-37, 99-110, 134-155, 159-172).
- App-API transport: socket ancestry, inode identity before/after connect, peer UID, strict deadline, first-byte gate (application_api_tools.rs:1521-1622).
- resident_completion re-entry: every cut between marker, receiving archive, session publication, resident publication and receipt is re-enterable with the same bytes (resident_completion.rs:465-533; tests 764-830).


---

## 5. Unwired / undone

### 5.1 Reachability of every module in the shard

"Entry" is the `fn main` arm, admin command or serve-loop input that reaches it; "run evidence" is a journey, driver or evidence directory that records an execution.

| module | entry (main.rs) | driver / unit | run evidence |
|---|---|---|---|
| control.rs | `serve` 17506-17509; `connect` 18145-18153, 18175-18191; `admin` 18192-18229; `tool`, `tool-result`, `tool-ack` 18051-18135 | `deploy/grain-host/grain-ssh:19`; every crate driver | docs/evidence/2026-09-26-terminal-live, 2026-09-30-hermes-participant |
| terminal.rs | `terminal` 18154-18174; serve loop 17616-17645, 17842-17889 | room_resident.rs (framing) | docs/evidence/2026-09-26-terminal-live/README.md |
| public_status.rs | serve loop `status` 17605-17614 | grain-ssh users | indirect |
| room_resident.rs | `hermes-room resident CONFIG` 18009-18014 | none in deploy/ or journeys | none; docs/review/2026-10-26-deploy/AFFORDANCES.md:386 lists evidence "none" |
| resident_requests.rs, resident_context.rs | via room_resident.rs (and hermes_room.rs `prepare_resident`, resource_tools.rs:777) | none | none |
| resident_preflight.rs | admin `resident prepare` 17674-17678, `resident admission` 17679-17687, `resident preflight` 17688-17693; `hermes_session` 14322-14336; `controller-launch` (systemd_manager.rs:149) | none | none found |
| resident_origin.rs | `hermes_session` 14576-14583; terminal parser | none | none |
| resident_completion.rs | admin `resident completion-plan` 17694-17699, `resident receive-completion` 17700-17705; subcommand `resident-completion` 17944-17949; `hermes_session` 14980 | none | none found |
| resident_delivery.rs | admin `resident delivery-plan` 17706-17711, `resident deliver-final` 17712-17717; subcommand `resident-delivery` 17950-17955; `hermes_session` 14981, 15036; journal validation 1900 | none | RESIDENT-DELIVERY.md:60-62 cites "actual operation396 native proof"; no evidence directory found by name |
| resident_reconcile.rs | admin `resident reconcile-failed` 17759-17770; subcommand `resident-reconcile` 17980-17985 | none | none |
| resident_outcomes.rs | admin `resident supersede-completion` 17718-17726; subcommand `resident-outcome` 17956-17961; driver loop room_resident.rs:308 | none | one historical incident (RESIDENT-OUTCOMES.md:20-27) |
| room_task.rs | `tool_call` room tools 12264-12266, `mini_room_attempts` 12245-12247; recovery 15989 | controller with `toolTask.room` | none for the grain path (the j14 run in docs/evidence/2026-10-01-p-hermes-room is the hermes_room.rs runner: its artifact is `hermes-journal.jsonl`) |
| concierge.rs | `concierge step\|serve` 18024-18032 | native/resource-client/journey.d/j17.sh:168-169 | docs/evidence/2026-10-01-p-credit (J17 rows, per the money reader) |
| quiescence.rs | admin `quiescence status\|inspect` 17745-17758; subcommand `quiescence` 17974-17979; used by config_migration.rs:4, hermes_session_verify.rs:44, every receiver | operator stack (docs/evidence/2026-09-26-operator-stack/README.md:5 "source-matched `quiescence` action") | yes |
| quiescence_transport.rs | admin `quiescence transport` 17736-17744; subcommand `quiescence-transport` 17968-17973 | none | none |
| session_failure.rs | admin `session reconcile-failure` 17727-17735; subcommand `session-failure` 17962-17967; hot-path hooks 17597-17599, 6916-6918 | none | one historical incident; helper missing (C-F6) |
| systemd_manager.rs | `--controller-manager-protocol` 17922-17925; `controller-launch` 17926-17931; `Runtime::open` 6844; manager commands 17214, 17244, 17271, 17285, 17303 | hermes-journey.sh fixture env (per shard A, hermes-journey.sh:211-216) | docs/evidence/2026-09-30-hermes-participant |
| cgroup_stop.rs | `prove_prior_run_stopped` 692; worker proof 17341 | as above | as above |
| journal_io.rs, controller_digest.rs | every save and hash (main.rs:2556, 2308-2312) | all | all |
| controller_write_scopes.rs | `controller-write-scopes` 17932-17937; config_migration.rs:1350-1417 | none found | CONTROLLER-WRITE-SCOPES.md only |
| resource_tools.rs | reads 12283-12303, births 10615-10804, room tools 12264 | reads: hermes-journey.sh / acceptance.sh (publication + read); births: none (RESOURCE-WORKSPACE-MIGRATION.md:9) | reads yes; fixed births "retained acceptance evidence" only |
| application_tools.rs | app/session births main.rs:10489-11007 (shard A) | examples/current_birth_provider.rs is meant for it, but no script builds it | docs/evidence/2026-09-27-hosted-current-birth-9601, 2026-09-27-application-current-birth (names) |
| application_api_tools.rs | app-API caller main.rs:8494-9172, dispatch custody 3534-6797 (shard A) | agent-two-participant-foreground-journey.sh for v2 (shard A) | v2: docs/evidence/2026-09-27-agent-api-controller-v2; v3: evidence predates C-F3 |
| shared_app_refs.rs | main.rs:7671-7729 (shard A) | none in crate | docs/evidence/2026-09-27-shared-app-refs, 2026-09-27-shared-app-recipient-refs |
| birth_lifecycle_tests.rs, publication_refusal_tests.rs | `#[cfg(test)] mod` at main.rs:26-27, 58-59 | `cargo test` | nextest logs in evidence dirs |
| examples/current_birth_provider.rs | `cargo build --example` only | none | none |
| fixture/*.rs and scripts | acceptance.sh, hermes-journey.sh, receipt-recovery-acceptance.sh | crate drivers | docs/evidence/2026-09-30-hermes-participant (hermes-deterministic-acp) |

### 5.2 TODO, dead code, ignored tests

No `TODO`, `FIXME`, `todo!` or `unimplemented!` in any file of the shard (grep). `#[allow(dead_code)]` once: quiescence.rs:355 (`ResidentJournal`, "Full strict schema is retained even for fields not projected"). `#[allow(clippy::too_many_arguments)]` at concierge.rs:558. Dead in non-test builds: `resident_preflight::{Ready, checked}` (resident_preflight.rs:6-32; only tests call `checked`, 222-227). `#[ignore]` tests: cgroup_stop.rs:408-442 (needs an isolated systemd user controller), journal_io.rs:81-89 (a worker spawned by its sibling test). The seams `mini_doc_quote` and `mini_doc_history` are explicitly not offered (resource_tools.rs:692-694). `RoomTools::write` (resource_tools.rs:1124-1126) is called only by the non-grain runner (hermes_room.rs:421); the grain path calls `write_with_reply_guard` directly (room_task.rs:212). `RoomTools::notice` (resource_tools.rs:1254-1257) likewise serves only hermes_room.rs:410.

### 5.3 Twins and near-twins

| twin | sites | reachable | keep | delete |
|---|---|---|---|---|
| resident journal schema | `room_resident::ResidentState` (room_resident.rs:32-43), `resident_reconcile::ResidentState` (resident_reconcile.rs:8-19), `quiescence::ResidentJournal` (quiescence.rs:353-365) | all three | one type in resident_origin.rs or a new resident_state.rs | the other two |
| resident origin | `resident_origin::ResidentPromptOrigin` (resident_origin.rs:3-10), `resident_reconcile::ResidentOrigin` (resident_reconcile.rs:54-56), `room_resident::ResidentOrigin` (room_resident.rs:212-219) | all | the first | the two private copies |
| assignment preamble | `room_resident::ASSIGNMENT_PREFIX` (room_resident.rs:6) vs `resident_delivery::PREFIX` (resident_delivery.rs:6), both accepted by `assignment` (resident_delivery.rs:211-214) | current + historical | current | historical, once no undelivered pre-change final remains |
| final provenance | `source-acp-and-settled-provider-final` vs `historical-settled-provider-final-and-completed-resident-origin` (resident_delivery.rs:300-303, 535-540); legacy append proof via `mini operation-proof` (702-751) | both | ACP capture path | historical path |
| flock-transfer drain | `resident_completion::drain` (611-648) vs `resident_delivery::drain_completed` (942-986) | both | one function parameterised by verb pair | the copy |
| "closed boundary" predicate | resident_reconcile.rs:156-171, resident_completion.rs:254-287, session_failure.rs:229-248, resident_delivery.rs:844-857, resident_outcomes.rs:239-245 | all | one `Status::closed_except(&[allowed markers], allow_stale_fingerprint)` | five inline copies |
| canonical-JSON SHA helper | resident_outcomes.rs:48-51 `canonical`, session_failure.rs:53-56 `hash`, quiescence_transport.rs:77-80 `hash`, resident_delivery.rs:46-48, resident_completion.rs:78-80, resident_requests.rs:42-44 `digest`, resident_reconcile.rs:67-69 | all | one | six |
| 64-hex validator | resident_origin.rs:11-13, resident_reconcile.rs:71-76, quiescence_transport.rs:81-86, shared_app_refs.rs:161-166, application_api_tools.rs:554-559 | all | one | four |
| private file / directory custody | resident_outcomes.rs:52-89, session_failure.rs:57-84, quiescence_transport.rs:87-110, resident_reconcile.rs:185-207 | all | one pair in main.rs beside `bounded_regular_file` | the rest |
| journal publication | `Runtime::save` (main.rs:6916-6919), `atomic_json` direct (session_failure.rs:490), `config_migration::publish_bytes` (resident_completion.rs:548-557) | all | `journal_io::write` | `publish_bytes` for the journal |
| last-JSON-of-stdout parser | resource_tools.rs:865-874 vs concierge.rs:304-315 | both | one | one |
| hex encode/decode | application_api_tools.rs:64-72, 96-107, 771-789, 1733-1754; controller_digest.rs:6; shared_app_refs.rs:64-68 | all | one module | five copies |
| SHA-256 | controller_digest.rs vs direct `sha2` in application_api_tools.rs:9 and shared_app_refs.rs:14 | all | controller_digest | direct uses |
| birth namespace planner | resource_tools.rs:59-82, 84-259, 328-438 vs application_tools.rs:133-152, 234-388, 418-482 | all | one `Namespace` + `plan_birth(shape)` | the duplicate arithmetic and source builders |
| fixed-family birth vs workspace create | resource_tools.rs:261-438 (`mini_create_resource`) vs main.rs:11879-12009 (`mini_workspace_create`) | both | workspace create | fixed family (RESOURCE-WORKSPACE-MIGRATION.md:9 sets the bar) |
| room-write executor | room_task.rs (grain controller, ToolTask purse, operation records) vs hermes_room.rs (non-grain room runner, `journal.jsonl`, "for a `say` by a signed tail of Hermes's own stream", hermes_room.rs:21-25) | both; j14 runs hermes_room | room_task (exact records; room_task.rs:123-126 calls stream text matching "NOT an operation identity") | hermes_room's write path |
| status projection | terminal.rs:18-85 vs quiescence.rs:173-267 | both | quiescence inventory, projected | the hand-picked key list |
| app-API route | `RoutePin` + `validate_routes` (application_api_tools.rs:251-270, 1092-1162) vs `LifetimeRoutePin` + `validate_lifetime_routes` (300-328, 806-909) | v2 live, v3 dead (C-F3) | one | one |
| app-API wire | `hello`/`dispatch`/`inspect` (74-76, 144-166) vs `hello-v3`/`dispatch-v3` (78-80, 128-142); `HostReply` (505-545) vs untyped v3 JSON handled in main.rs | both | one | one |
| binding fingerprint | v1 `FixedBinding::fingerprint` (561-596) vs v3 `verify_lifetime_binding_reply` digest (460-468) and `lifetime_operation_fingerprint` (387-421); spk-host recomputes each | both sides | one shared crate (`native/spk-rpc` is a workspace member) | per-side reimplementations |
| incident receivers | session_failure.rs (one incident), resident_outcomes.rs (one incident), resident_reconcile.rs (general) | all | resident_reconcile plus a typed per-prompt failure record | the two incident receivers, after archiving their one result |

### 5.4 Versioned siblings still present

`mini-controller-write-scopes-v2` replaced v1 in place (controller_write_scopes.rs:5-7, CONTROLLER-WRITE-SCOPES.md:12-14), good. App API: v2 (`mini-spk-agent-api-v1` protocol string, event21) and v3 (`mini-spk-agent-api-v3`, event26/27) both compiled, configured by separate route lists, counted together against one limit of 16 (application_api_tools.rs:814-815). Resident: historical and current preamble and provenance (5.3). Legacy forensic admission inside session_failure.rs (SESSION-FAILURE.md:67-98).

### 5.5 Tests that test the fixture, not the system

- birth_lifecycle_tests.rs and publication_refusal_tests.rs: shell stand-ins for `mini` and the Host (question 9).
- resident_requests.rs tests write `resident-delivered-…json` receipts by hand (resident_requests.rs:499-500, 566-567); they test the queue's reading of a receipt shape, which is the controller's own (resident_delivery.rs:924-925), so this is a consistent self-test, not a Mini test.
- room_task.rs tests use the `restart_resolution_fixture` stub `mini` (room_task.rs:239-258) whose `sim/status` file stands in for the grain (room_task.rs:358, 411).
- application_api_tools.rs transport tests use local `UnixListener` peers (application_api_tools.rs:2459-2534); the v3 binding test bypasses the transport (C-F3). None exercises spk-host.
- concierge.rs tests cover `decide` and journal parsing only (concierge.rs:653-756); no test has two entries at one height or a failed refund (C-F1).
- No test is a tautology. Strong pure tests: `sse_final` (resident_delivery.rs:1015-1037), `render_untrusted` (terminal.rs:571-581), cgroup topology races (cgroup_stop.rs:254-406), `relay_properties` (quiescence_transport.rs:647-663), `public_closed` against a live listener (674-690), resident queue fairness and byte bounds (resident_requests.rs:448-533).

---

## 6. Size and shape

### 6.1 Lines per file

See the table in the header. Totals: 18,277 src lines, of which 5,913 (32.4%) are test modules or whole test files; 212 `#[test]` functions. By group:

| group | files | lines | test lines |
|---|---|---|---|
| control plane | control, terminal, public_status | 1,571 | 357 |
| room resident | room_resident, resident_requests, resident_context, resident_preflight, resident_origin, resident_completion, resident_delivery, resident_reconcile, resident_outcomes, room_task | 5,426 | 1,643 |
| concierge | concierge | 757 | 125 |
| operator surfaces | quiescence, quiescence_transport, session_failure | 2,409 | 662 |
| host custody | systemd_manager, cgroup_stop | 1,011 | 392 |
| tools | resource_tools, application_tools, application_api_tools, shared_app_refs | 5,961 | 1,701 |
| utilities | journal_io, controller_digest, controller_write_scopes | 178 | 69 |
| test files | birth_lifecycle_tests, publication_refusal_tests | 964 | 964 |
| example + fixture Rust | current_birth_provider, broker-drop | 316 | - |

### 6.2 Why it is this large

1. Every resident receiver re-implements the same envelope: private file custody, canonical hash, resident lock, fresh quiescence, closed-boundary predicate, immutable archive directory, typed decision, publication (5.3 lists five boundary predicates and seven hash helpers).
2. Historical compatibility is kept beside the current path: two preambles, two provenances, the legacy append-proof route, legacy forensic admission, a one-incident completion supersession.
3. The application API is implemented in two generations with their own route types, wire types and fingerprints, and both sides of the socket reimplement them.
4. Births are planned twice (content families and app/session families), and the fixed-family birth is kept beside workspace create.

### 6.3 A minimal version for the demo-critical path

Shard A's demo assumption: one controller per member grain, Hermes prompts through the provider gateway, MCP workspace tools and `mini_publish`/`mini_read_resource`, hard/soft attach over `connect`/`grain-ssh`, restart recovery, admin reconcile verbs, scoped bwrap worker.

**Scenario A: no rooms in the demo.** Keep: control.rs (948), terminal.rs (600; or drop if only SSH `connect` is offered), public_status.rs (23), systemd_manager.rs (568, minus `RoomRouting` and `controller-launch` if the installer renders units directly), cgroup_stop.rs (443), journal_io.rs (104), controller_digest.rs (28), quiescence.rs (987, minus resident evidence), resource_tools.rs reads only (about 300 code lines of 1,579 plus their tests), publication_refusal_tests.rs (821), controller_write_scopes.rs (46) only if config migration stays. About **5,100** lines remain.

Drop (line counts from `wc -l`):

| file | lines | reason |
|---|---|---|
| application_api_tools.rs | 2,764 | app API v2 and v3 (v3 dead, C-F3) |
| application_tools.rs | 813 | app/session births |
| shared_app_refs.rs | 805 | shared app references |
| birth_lifecycle_tests.rs | 143 | fixed-family birth tests |
| examples/current_birth_provider.rs | 278 | app/session birth fixture, unused |
| resident_delivery.rs | 1,341 | room resident |
| resident_completion.rs | 939 | room resident |
| resident_requests.rs | 660 | room resident |
| resident_reconcile.rs | 489 | room resident |
| resident_outcomes.rs | 416 | one historical incident |
| resident_preflight.rs | 337 | room resident |
| resident_context.rs | 203 | room resident |
| resident_origin.rs | 52 | room resident |
| room_resident.rs | 542 | room resident |
| room_task.rs | 447 | room tools inside the grain |
| concierge.rs | 757 | paid rooms (decision belongs in Lean, C-V1) |
| session_failure.rs | 705 | one historical incident, hot-path hook |
| quiescence_transport.rs | 717 | one-topology upgrade surface, no run |
| resource_tools.rs birth families and room tools | about 1,280 | fixed-family twin; room tools |
| **total** | **about 13,490** | |

**Scenario B: rooms with a resident in the demo.** Keep the room resident stack, room_task, room tools, terminal framing, quiescence; drop application_api_tools (2,764), application_tools (813), shared_app_refs (805), birth_lifecycle_tests (143), the example (278), session_failure (705), resident_outcomes (416), quiescence_transport (717), resource_tools birth families (about 420), resident_delivery's historical preamble/provenance/append-proof path (about 250): about **7,300** lines dropped, about 11,300 kept, and fix C-F2 and C-F4 before exposing it. The concierge stays only until its rule moves into Lean.

Shard A's crate-level list of sibling files the demo drops (application_api_tools, dispatch_custody, shared_app_refs, application_tools, gitweb_worker, legacy_custody_audit, dispatch_runtime_tests, birth_lifecycle_tests, homelab; about 7,550 lines) is consistent: 4,525 of those lines are in this shard.

---

## 7. Deployability on a small public Linux VM

### 7.1 What must exist on the box (for this shard's parts)

| item | why | evidence |
|---|---|---|
| one Unix account per member grain, `stateDir` 0700 owned by it | the control and admin sockets' only protection | control.rs:299-300, 71-72; main.rs:6829 |
| `mini-grain-controller@TASK.service` as the controller unit name (not `mini-hermes.service`) | `prove_controller_unit`, `prove_prior_run_stopped` | systemd_manager.rs:77-79; main.rs:689, 17212-17240 |
| root-owned `/etc/mini/controllers/TASK.json` with `protocol`, `task`, canonical `config`, `manager`, `workerManager:"user"`, `serviceUid` | managed proof; the shipped renderers' lone `MINI_GRAIN_CONTROLLER_UNIT` is refused without it | systemd_manager.rs:80-109, 158-183; deploy/grain-host/mini-grain-controller@.service:9; deploy/grain-host/install-controller:189 |
| systemd user manager for the service UID (lingering), `/run/user/UID/bus` | worker units are always user units | systemd_manager.rs:92, 289-295 |
| launcher answering `--controller-manager-protocol` with `mini-controller-manager-v1` when the controller runs under the system manager | cross-manager launch | systemd_manager.rs:404-417; SYSTEMD-MANAGERS.md:33-40 |
| cgroup v2 unified hierarchy | proofs | cgroup_stop.rs:159-172 |
| `/usr/bin/systemctl` (fixed path) | all manager commands | systemd_manager.rs:283; quiescence_transport.rs:389 |
| a running `mini serve-operator` on `hostSocket` answering `operator-status` | resident preflight and `controller-launch` | resident_preflight.rs:49-58; systemd_manager.rs:149 |
| for rooms: Hermes's room workspace and a private home inside `stateDir`, a funded `ROOM-hermes` account | room tools | room_task.rs:29-53; resource_tools.rs:686-690 |
| for the resident: the resident state directory as a direct child of `stateDir`, run as the same UID (it talks to `admin.sock`) | resident custody | room_resident.rs:280-288; resident_preflight.rs:82 |

### 7.2 What is operator-configured

Every price in this shard: `toolTask.charge` for room writes (C-V3), the room's turn price via the account fields read by the client (C-V2), concierge tariffs set by founders (`credit.rs:31` per the money reader), birth family tariffs (resource_tools.rs:39-40). Queue limits and intervals in the resident config. App-API routes and Host pins (v2/v3). The quiescence transport admission. `restrictTools` (default false: change it to true for any room resident, C-V2).

### 7.3 What is dangerous to expose

- `stateDir/admin.sock`: settles holds, clears resident custody (`resident reconcile-failed`, `resident supersede-completion`, `session reconcile-failure`), runs config migration (main.rs:17653-17813). Anyone with the service UID can drive it; the room resident driver must run as that UID because it uses it (resident_preflight.rs:82, resident_completion.rs:620-623, resident_delivery.rs:955-958). Never share the service UID with member shells.
- The control socket: anyone who can connect spends the grain's budget (shard A 7.3). `grain-ssh` forwards an SSH key to it (deploy/grain-host/grain-ssh:19); with the plain `connect SOCKET` (no mode) a key holder can send any first line, including `attach terminal-v1 soft`, and then `tool-v1` foreground frames (control.rs:445-460) and `terminal hermes-resident …` lines (main.rs:17847); the latter still require a preparation file only the admin socket can mint (resident_preflight.rs:128-136).
- The SPK resident host socket per route: peer-UID checked (application_api_tools.rs:1570-1577); the host UID's processes can feed the model arbitrary HTTP bodies and, in v1 dispatch, move the dispatch purse (shard A A-V5).
- Logs: room resident prints `resident-output` model text and receipts to stdout (room_resident.rs:158, resident_requests.rs:96), the concierge prints decisions with payer subjects (concierge.rs:619-623).

### 7.4 What a stranger on the internet could exercise

Nothing directly: no TCP listener in this shard outside the test example (examples/current_birth_provider.rs:56 binds 127.0.0.1). Exposure equals the front end that relays to `connect` (SSH forced command, hosted shell, Discord entrance).

### 7.5 What a malicious enrolled member could exercise

- In a room with a resident: post addressed requests up to the per-author cap (8) and the 12,000-byte text bound; a long request triggers C-F4 and wedges the resident for everyone; each request costs the founder up to three paid notice turns plus the reply turn (C-V6); with `restrictTools:false` a prompt-injected resident can write without paying turns (C-V2).
- Withdraw requests (cancels only unstarted ones, resident_requests.rs:292-296).
- Pay the concierge twice in one height to lose the second payment (C-F1, self-harm), or exploit a concierge outage to make refunds fail permanently for others (C-F1.2).
- Through the model: call room read tools freely (they cost no turn) and fill `stateDir` with `resource-read-N/` directories via `mini_read_resource` (C-F8).
- Through a direct `connect` session: hold the single attachment slot (C-F7.3, C-F7.6) and thereby stop the room resident's prompts.

### 7.6 Operational notes for a small VM

Each room write runs three to five `mini` children (reserve, turn payment, write proposal, submit, settle) on the controller thread (room_task.rs:184-214); each resident turn adds admin round trips for prepare, completion plan/receive and delivery plan/deliver (section 1.2). File growth per resident turn (C-F8) and per signed read needs a pruning policy on a small disk. The controller unit's `MemoryMax=1G`/`TasksMax=64` (deploy/grain-host/mini-grain-controller@.service:16-17) must also hold the app-API I/O threads (application_api_tools.rs:1680-1724) and admin connection threads (control.rs:89-92).

---

## 8. Questions for the Lean side

1. **Room turn price.** Does any Lean declaration bind the amount of a fleet turn that pays a room's till to the room's `hermes/turn` account field, or is the amount whatever the signed turn says? Kernel/FleetTurn.lean:1-24 mentions only the pinned base tariff and an optional transfer. If the latter, C-V2 is a client convention, not a price.
2. **Paid membership.** Is there a Lean receiver (the "K-BOOK-SLOTS" of concierge.rs:27-30) that refuses a member delegation under a room unless a matching `renew` payment entry is consumed in the same transaction? Name it, or confirm none exists, so C-V1 can be scoped.
3. **Ledger identity.** In `NativeHost.fleetIncomingAuthorizedLoaded` (Host/Main.lean:6865) and `Minidregg.Host.Json.fleetIncomingJson`, can two entries share one `height`? What is the unique key of an incoming ledger entry (transaction id, (height, sequence))? (C-F1)
4. **Fleet plan refusal codes.** `fleetPlanAuthorizedLoaded` returns a `refusalFrame "fleet-plan" refusal` (Host/Main.lean:6812-6816). Which constructor means "payer cannot fund" (the string `bookRefused` that resource_tools.rs:1109 searches for), and is that name stable?
5. **Absent then admitted (rooms).** For a document write submitted by `mini shell --line "submit hr-OP"`, can the Host admit the call after a `lookup` returned `absent`, if the submitter died mid-send? (Same as shard A Q8.7, for C-V4.)
6. **Share issue lookups.** Do ops 29 and 55 (APPLICATION_SHARE_ISSUE_LOOKUP, GRAIN_SHARE_ISSUE_LOOKUP) replay a historical receipt with `type:"confirmed", confirmation:"replayed"` and the four receipt fields that shared_app_refs.rs:336-361 compares, and do they refuse an ingress carried by the other event kind (event15 vs event22, shared_app_refs.rs:86-89)?
7. **Profile fields.** Which declaration produces the PROFILE (op 6) JSON with `runtime:"minidregg-native"`, `nativeChecked`, `domain`, `semantics` that quiescence_transport.rs:195-209 requires?
8. **Unreserved statuses.** quiescence.rs:166-171 treats grain status 0, 1, 2, 6 with reserved 0 as an unreserved boundary and calls status 2 "soft-running". Confirm the meaning of each code in the AgentGrain status type, and that no other status can have `reserved = 0` while still holding value.
9. **Birth namespace reuse.** Does the application and session birth receiver (op30/31 sources built by application_tools.rs:484-632) refuse a target or capability ID that already exists, given that Rust computes them as `start + ordinal` (application_tools.rs:380-388)? (Shard A Q8.5 asks the same for content births.)
10. **Event21/event26 independence from the SPK binding.** For v2 dispatch, does the Lean event21 receiver re-derive app/session/parent/purse generations itself, so a stale `FixedBinding` (application_api_tools.rs:488-503) can never be the basis of admission? For v3, does the event26 receiver check `operationFingerprint` (application_api_tools.rs:387-421) or only the HTTP digest?
11. **Delivery receipt.** For the resident's final `mini_say` (an append to Hermes's stream with `--expect-re-cell/--expect-re-sequence`), which Lean check refuses the append if the replied-to entry's cell/sequence changed (the "stable reply guard", resource_tools.rs:1128-1153)?
12. **Validity windows.** concierge.rs:24-26 says the kernel enforces `Admissible.validUntil` for issued member windows. Name the declaration, and say whether a later delegation to the same subject with a larger `notAfter` supersedes or adds to the earlier grant (concierge.rs:177 assumes extension).

---

## Appendix A. Controller journal fields owned by this shard

| journal field (main.rs) | type | written by | cleared by |
|---|---|---|---|
| `residentPromptOrigin` (514) | `resident_origin::ResidentPromptOrigin` | `hermes_session` (main.rs:14576-14583) | next resident prompt overwrites; never cleared otherwise |
| `residentDelivery` (516) | `resident_delivery::Pending` | `install_final` (resident_delivery.rs:565-593); op id and reply number (868-873, 883-904) | `finish_delivery` after the receipt (resident_delivery.rs:931-932); receipt-present re-entry (809-819) |
| `residentCompletion` (518) | `resident_completion::Pending` | `stage_resident_completion` (resident_completion.rs:407-409) | `receive_resident_completion` after the receipt (resident_completion.rs:530-531, 500-503) |
| `roomAttempt` (543) | `room_task::Attempt` | `room_call_with_id` (room_task.rs:178-183) | `record_room_resolution` on a definite result (room_task.rs:114) |
| `roomResolutions` (545) | `Vec<Value>`, capped 64 | `record_room_resolution` (room_task.rs:115-118) | oldest dropped |
| `hermesSession` fields `pendingPrompt`, `stateFingerprint`, `loadVerified` | `HermesSession` | session_failure publication (session_failure.rs:261-266); completion publication (resident_completion.rs:535-546) | - |
| validation hook | - | `resident_delivery::validate_pending`, `resident_completion::validate_pending` run on journal validation (main.rs:1900-1901) | - |

## Appendix B. Admin commands owned by this shard (exact strings, main.rs)

| command | handler | effect |
|---|---|---|
| `resident prepare SHA256` (17674) | resident_preflight.rs:117 | writes `resident-prepared-ID.json`; does not set `phase` to 2 (main.rs:17674-17678), cosmetic |
| `resident admission ID SHA256` (17679) | resident_preflight.rs:168 | read-only; also does not set `phase` 2 |
| `resident preflight` (17688) | resident_preflight.rs:184 | read-only snapshot |
| `resident completion-plan PATH` (17694) | resident_completion.rs:444 | read-only plan |
| `resident receive-completion PATH` (17700) | resident_completion.rs:465 | publishes resident counter and session |
| `resident delivery-plan PATH` (17706) | resident_delivery.rs:646 | read-only plan (reply may exceed 16 KiB, C-F4) |
| `resident deliver-final PATH` (17712) | resident_delivery.rs:793 | paid room say |
| `resident supersede-completion PATH` (17718) | resident_outcomes.rs:206 | one-incident correction |
| `session reconcile-failure PATH` (17727) | session_failure.rs:339 | one-incident closure |
| `quiescence transport PATH` (17736) | quiescence_transport.rs:442 | read-only via management socket |
| `quiescence status` / `quiescence inspect PATH\|none` (17745) | quiescence.rs:575, 602 | read-only |
| `resident reconcile-failed PATH SHA` (17759) | resident_reconcile.rs:275 | clears `resident.json.pending` |

## Appendix C. Client subcommands owned by this shard (main.rs)

`--controller-manager-protocol` (17922), `controller-launch CONFIG REGISTRATION` (17926), `controller-write-scopes …` (17932), `resident-completion plan|receive ADMIN PATH` (17944), `resident-delivery plan|deliver ADMIN PATH` (17950), `resident-outcome ADMIN REQUEST` (17956), `session-failure ADMIN REQUEST` (17962), `quiescence-transport ADMIN REQUEST` (17968), `quiescence status|inspect ADMIN [PATH|none]` (17974), `resident-reconcile failed ADMIN STATE SHA` (17980), `hermes-room resident CONFIG` (18009), `concierge step|serve CONFIG [SECONDS]` (18024), `connect SOCKET [hard|soft]` (18145, 18175), `terminal SOCKET [hard|soft]` (18154), `admin ADMIN COMMAND` (18192), `tool`, `tool-result`, `tool-ack` (18051-18135). The usage string printed on a bad invocation lists none of the resident, quiescence, session-failure, concierge, controller-launch or hermes-room verbs (main.rs:18221-18223).
