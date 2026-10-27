# grain-runtime, shard B: provider gateway, credentials, custody gate, config migration, MCP, gitweb, pending prepare, query observation

| field | value |
|---|---|
| shard | grain-runtime B, "provider gateway, credentials, custody gate, config migration, MCP, gitweb, pending prepare, query observation" |
| crate | `/Users/ember/dev/minidregg/native/grain-runtime` (package `minidregg-grain-runtime`; bins `grain-runtime` = `src/main.rs`, `grain-provider-bridge` = `src/provider_bridge.rs`, Cargo.toml:9-15) |
| reviewer | Opus reader, fan-out review 2026-10-26 |
| date | 2026-10-26 |
| method | every file below read in full; `path:line` cited for each claim; no build, no test run (operator rule). Unqualified file names (`provider.rs:123`) are under `native/grain-runtime/src/`. `main.rs` lines are cited only as call sites; main.rs itself belongs to shard A (`docs/review/2026-10-26-native-crates/grain-runtime--A-main.md`, cited as "A"). |

Files covered (line counts from `wc -l`; "test" = lines from the first `#[cfg(test)]` to end of file, or the whole file for test-only files):

| file | lines | code | test | role |
|---|---|---|---|---|
| provider.rs | 3,197 | 1,635 | 1,562 | loopback/Unix OpenAI-compatible gateway the sandboxed Hermes talks to |
| provider_homelab_tests.rs | 506 | 0 | 506 | `#[path]` test submodule of provider.rs (provider.rs:3195-3197) |
| homelab.rs | 190 | 190 | 0 | inference-scheduler placement adapter |
| provider_profile.rs | 257 | 143 | 114 | worker Hermes `config.yaml` writer, gateway token |
| provider_bridge.rs | 296 | 274 | 22 | second binary: in-sandbox TCP->Unix bridge |
| provider_history.rs | 618 | 447 | 171 | continuity descriptor, fence records |
| provider_resolution.rs | 543 | 429 | 114 | expired-contention retirement of a guarded provider settle |
| provider_continuity_rejection.rs | 609 | 330 | 279 | "before-signing" continuity rejection marker verifier |
| provider_recovery.rs | 175 | 133 | 42 | delivered-response settlement resume |
| provider_retirement.rs | 126 | 88 | 38 | retire a definitively unsent refused provider reserve |
| credentials.rs | 1,888 | 1,206 | 682 | provider table + sealed credential store; compiled into three crates |
| provider_choice.rs | 202 | 202 | 0 | `#[path]` submodule of credentials.rs (credentials.rs:32-33): signed member choice |
| provider_provision.rs | 228 | 199 | 29 | `grain-runtime provider-provision` |
| provider_owner.rs | 197 | 197 | 0 | native owner-key and grant observations |
| custody_gate.rs | 382 | 283 | 99 | cancellable `mini` child gate |
| dispatch_custody.rs | 476 | 387 | 89 | SPK host dispatch purse RPC socket (SO_PEERCRED) |
| dispatch_runtime_tests.rs | 643 | 0 | 643 | test-only (Linux) |
| legacy_custody_audit.rs | 819 | 796 | 23 | one-incident "B44" operator audit receiver |
| config_migration.rs | 2,033 | 1,430 | 603 | typed controller config publication |
| mcp.rs | 926 | 565 | 361 | MCP broker socket (controller side) + `mcp-stdio` edge (sandbox side) |
| gitweb_worker.rs | 898 | 671 | 227 | Git smart-HTTP loopback proxy run inside the sandboxed MCP edge |
| hermes_catalogue_probe.rs | 93 | 0 | 93 | `#[ignore]`d test; its script does not exist |
| hermes_outcome.rs | 136 | 81 | 55 | ACP turn outcome classification |
| hermes_session_verify.rs | 147 | 112 | 35 | `Invocation` enum + `verify-session` |
| hermes_room.rs | 670 | 601 | 69 | legacy chat-completions room runner + resident assignment preparation |
| grain_source.rs | 117 | 89 | 28 | grain intent JSON authoring + operation identity |
| pending_prepare.rs | 395 | 267 | 128 | re-prepare an interrupted parent settlement |
| query_observation.rs | 460 | 232 | 228 | signed resource/policy reads with bounded stale-root retry |
| **total (28 files)** | **17,227** | **10,987** | **6,240 (36.2%)** | |

Context read (not owned): `native/grain-runtime/Cargo.toml`, `README.md` (via A), `BYOK.md` (66), `CONFIG-MIGRATION.md` (182); `deploy/hermes/README.md:71-101`; `deploy/hermes/mini-hermes.service`; `deploy/grain-host/bwrap:1-140`; `native/mini-keys/src/lib.rs:1-31`, `src/wire.rs:1-60`, `src/server/provider.rs:1-433` (grep plus 186-366 read), `src/server/mod.rs:15-25`, `Cargo.toml`; `native/resource-client/src/keys.rs:1-80`, `src/provider_continuity.rs:1-40, 760-840`; `native/inference-scheduler/src/lib.rs:1-40`; `Host/ProviderUsage.lean:1-40, 180-335`; `Kernel/ProviderRoute.lean:1-60`; `Host/Main.lean:850-880, 5520-5632, 6718-6754`; `Host/Json.lean:2640-2775`; `protocol/host-operations.json` entries 5, 17, 19, 30, 31, 144; main.rs call sites (listed in section 5.1).

Scratch notes: `/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/gr-B/notes.md`.

## Executive summary (15 lines)

1. `provider.rs` is a per-prompt, single-request HTTP/1.1 gateway (TCP on loopback only, provider.rs:569-571, or a 0600 Unix socket in the state dir, provider.rs:406-445) authenticated by a 64-hex per-prompt token compared in constant time (provider.rs:331-348, provider_profile.rs:54-66); it never holds a provider key: the mini-keys broker performs the send against a single-use ticket (provider.rs:1475-1505).
2. It does not stream: the broker returns the whole provider body in one frame and the gateway writes it with a `Content-Length` (provider.rs:868, 1120-1123), so a streaming Hermes waits for the full completion; total time is capped by `timeoutSeconds` <= 600 s plus 30 s (provider.rs:576-578, 1482).
3. It computes no tokens and no charge (no usage parsing anywhere in the shard); prices come only from the Lean op-19 quote (`Host/ProviderUsage.lean:264-284`) that main.rs requests; the input-token ceiling is validated as a config number but never measured (provider.rs:587-596, 611-613).
4. Member prompts and model replies are retained **in plaintext forever** in the controller state dir: `provider-N.request/.response/.headers` (provider.rs:1456-1470, 1558-1566) and again as `provider-N.controller-outcome/.controller-response-headers` (main.rs:9958-9973); the broker deletes its own copies (mini-keys server/provider.rs:203-207, 284).
5. Shard A's F1 hole is wider than stated: besides upstream timeouts and crashes after `send_started`, a **fully received** response becomes `Uncertain` when its headers exceed 32 KiB (the broker allows 64 KiB), lack a Content-Type, carry a non-identity Content-Encoding, or arrive after a lease revoke (provider.rs:1555-1556, 1595-1624; mini-keys server/provider.rs:29), and every **non-200 response on a metered route** (pool/homelab) is unquotable by Lean (`ProviderUsage.lean:268`) and therefore unsettleable by `reconcile provider audited` (main.rs:16498-16516): one provider 429 bricks a pool-route grain.
6. A concrete bug creates the same dead state with nothing sent: after the durable send boundary, a homelab endpoint mismatch returns 503 without reporting any outcome (provider.rs:1073-1076), leaving `send_started && outcome == None`.
7. The 16-entry replay cache is per prompt and only filled after local delivery (main.rs:10386-10409, cleared at 14585-14591); an identical request is never sent upstream twice within one gateway lifetime (`last_permit_id`, provider.rs:1044-1051; held-attempt refusal, main.rs:9371-9376); the 16 bound is unreachable because `maxIterations` <= 6 (provider_profile.rs:90).
8. `credentials.rs` is compiled into **three** crates by `#[path]` (grain-runtime main.rs:34, resource-client keys.rs:35, mini-keys server/mod.rs:20-22), each with `#[allow(dead_code)]`; its 700-line sealed `CredentialStore` executes only inside the mini-keys broker; grain-runtime uses only the table, owner, grant parser and choice verifier.
9. Rust decisions without a Lean counterpart in this shard: the payer route (table row selection, credentials.rs:358-368, acknowledged by `Kernel/ProviderRoute.lean:30-35`), member-key per-day and per-call quotas counted against the wall clock (credentials.rs:1135-1190, 678-683), member provider-choice authenticity (provider_choice.rs:127-129), "expired so can never commit" retirement arithmetic (provider_resolution.rs:121-161, twin of resource-client), and two "absent after submitter stop = refused" inferences in the legacy room runner (hermes_room.rs:336-347, 430-433).
10. `legacy_custody_audit.rs` (819 lines) is a receiver for exactly one historical incident (operation 44, prompt 36, tasks 7803/7804, 13 pinned SHA-256s, legacy_custody_audit.rs:16-36, 286-295); it is dead weight on any other deployment.
11. `config_migration.rs` (2,033 lines) migrates only three provider throttles, one owner public key, and root-admitted Mini/Host transport changes (config_migration.rs:566-590); no journey runs it, and its own document says its tests were "staged ... no additional compiler was started" (CONFIG-MIGRATION.md:136-138).
12. `mcp.rs`'s refusal of `__*` tool names (mcp.rs:404-406, 505-506) and every restriction in `gitweb_worker.rs` run **inside the sandbox**, so they are advisory; the real gates are controller-side (`handle_tool` epoch check main.rs:8469, `begin_application_api` route allowlist main.rs:8501-8560) and Lean admission; I found no tool path that bypasses Lean admission.
13. `grain_source::source` emits exactly the fields `Host/Json.lean:grainSource` accepts (Host/Json.lean:2645-2765, exact-key check at 2648-2652); the `context.payload` label is hashed into the signed nonce (Json.lean:2700-2707, 2753), so it is identity, not decoration.
14. `hermes_room.rs` is a second Hermes driver (a Rust chat-completions loop) that sends no Authorization header (hermes_room.rs:201-206) so it cannot talk to this crate's gateway, meters nothing, and is reached only by `journey.d/j14.sh` and a deploy template README.
15. A demo-critical grain-runtime can drop about 6,100 lines of this shard outright (config_migration, legacy audit, dispatch custody and its tests, gitweb worker, homelab, provisioning, catalogue probe), defer about 1,600 more, and move about 1,300 lines of credential custody into mini-keys (section 6.3).

## The nine questions the lead asked, settled

**(1) provider.rs gateway.** Bind: `GatewayConfig.bind` must be loopback (provider.rs:569-571); when `unix_socket` is set (production: `state_dir/provider-gateway.sock` unless `localFixtureHostNetwork`, main.rs:14494-14495) no TCP listener is opened at all and `bind` is only the in-sandbox port the bridge listens on (provider.rs:406-445). Auth: `Authorization: Bearer <token>` (provider.rs:795-797), token 32..128 bytes `[A-Za-z0-9_-]` (provider.rs:270-280), production token 64 hex from `/dev/urandom` (provider_profile.rs:54-66) written into the worker's `config.yaml` (provider_profile.rs:125-127); rotated per prompt and refused if equal to the last one (provider.rs:289-293); constant-time compare (provider.rs:560-566). Bounds: headers 16 KiB, request <= `max_request_bytes` <= 1 MiB, response <= `max_response_bytes` <= 8 MiB, timeout <= 600 s (provider.rs:22-26, 572-580); 10 s request-read deadline (provider.rs:746, 829); exactly one in-flight request plus at most 4 "busy" responders that drain and answer 503 (provider.rs:475-496); exact request line `POST /v1/chat/completions HTTP/1.1` (provider.rs:774); no Transfer-Encoding/Content-Encoding/Expect (provider.rs:801-803); duplicate authority headers refused (provider.rs:804-806). Metered profile rewriting: an allowlist of 20 Chat Completions fields, `n`/`best_of` = 1, text-only messages and modalities, function tools only, `stream` requires `stream_options.include_usage`, `max_tokens` pinned to <= the output ceiling, re-serialized to drop duplicate keys (provider.rs:614-735). Streaming: none toward the worker (summary item 2). Retained on disk: request, response and headers per attempt, plaintext, 0600, never deleted (summary item 4). `Uncertain` arises from 11 distinct sites (Appendix A). From this side F1 looks like: `serve_client` answers 502 "provider outcome is uncertain; no retry was sent" (provider.rs:1124-1129) and the controller records `uncertain:REASON` with charge `None` (main.rs:9944-9956, 9990-9994); nothing in this shard can ever turn that into a settlement. Tokens/charges: provider.rs never parses `usage`; the only charge inputs are the Lean quote (main.rs) and, for retirement, `"0"`. Replay: 16 entries per prompt, filled only after local delivery, so a same-bytes SDK retry after delivery gets the cached bytes and cannot reach upstream; a retry before delivery is refused (held attempt) (main.rs:9371-9384, 10386-10409). Two upstream sends of one request are not possible inside one prompt; across prompts the cache is cleared deliberately (main.rs:14585-14591).

**(2) credentials.rs + provider_choice.rs.** The table is `mini-provider-table-v2`: 1..32 rows `{name, endpoint, kind=openai-compatible, models[1..64], credential=user|pool|homelab, caps (pool only)}` (credentials.rs:242-335); endpoints must be `https://` or loopback `http://` with path `v1/chat/completions` or `api/v1/chat/completions` (credentials.rs:207-239); the file must be root-owned and not group/world-writable in production (credentials.rs:337-352, called with owner 0 at main.rs:14482, provider_provision.rs:103, provider_owner.rs:99). Custody at rest (executed only by mini-keys): `ROOT/SUBJECT/PUBKEY-HEX/PROVIDER.key` = `{"type":"mini-provider-credential-v1","provider","nonce","sealed"}` sealed with ChaCha20-Poly1305 under a 32-byte key file, AAD binding type, namespace and provider (credentials.rs:768-811); `PROVIDER.grants.json` (`mini-provider-grants-v1|v2`, <= 64 grants, credentials.rs:847-892); `PROVIDER.usage.json` per-runner day counters (credentials.rs:1135-1190); `choice-TASK.json` signed choice (provider_choice.rs:150-160). The member can choose provider and model among `user` rows whose model list includes it, for one runner and task, pinned to the exact table digest (provider_choice.rs:132-142); the member sets per-call/per-day/expiry/model on their grant (credentials.rs:374-409). The operator overrides via the table (rows, models, caps), the provisioning policy (`mini-member-provider-provision-v1`, routes x models, pinned to the template digest, provider_provision.rs:21-63), and the controller config (`provider`, `model`, `maxOutputTokens`, `maxIterations`). Shared-source pattern: judged in section 5.4 (twins) and 4 (B-F15): it is a misplaced home, not just a twin.

**(3) provider_bridge.rs.** Argv must be exactly `--socket /run/mini-provider.sock --port P --seconds 1..1800 -- /agent/PROGRAM ...` (provider_bridge.rs:194-218); it binds `127.0.0.1:P` inside the worker's network namespace (provider_bridge.rs:219-221), spawns the worker with inherited stdio (provider_bridge.rs:223-229), proxies at most 5 concurrent connections (provider_bridge.rs:18, 245-249), each one Content-Length request (<= 1 MiB + 16 KiB) and one Content-Length response (<= 8 MiB + 16 KiB) with no TE/CE/Expect (provider_bridge.rs:33-166), and writes one byte `1` to the gateway after the response reached the TCP client (provider_bridge.rs:188), which the gateway takes as "local write completed" (provider.rs:1137-1165). It trusts nothing it reads beyond framing; the token check happens in the gateway. Reachability: under `deploy/grain-host/bwrap` with `--network none` the sandbox has only `/run/mini-provider.sock` and `/run/mini-grain.sock` (bwrap:124-128) and `--unshare-net` (bwrap:127-128), so the agent can reach the gateway and the MCP broker and nothing else on the network; the mini-keys broker socket is never mounted (bwrap refuses a mount containing `MINI_GRAIN_CREDENTIAL_BROKER`, bwrap:55-71, set to the broker socket at main.rs:3475). No crate driver runs this path (A section 5.2).

**(4) custody gate / dispatch custody / legacy audit.** `CustodyGate` serializes one `mini` child, lets a hard-EOF callback kill it, captures stdout/stderr up to 1 MiB each, and reports `BeforeSpawn` only when it provably spawned nothing (custody_gate.rs:26-33, 83-223); it has **no wall-clock timeout of its own** (only `cancel`), so it does not fix shard A's F2 for a hung child unless a hard EOF arrives. `dispatch_custody` listens on a Linux-only Unix socket, mode 0600 plus an exact ACL `u:HOST_UID:rw` verified by `getfacl` (dispatch_custody.rs:266-362), checks `SO_PEERCRED` uid == `hostUid` before reading anything (dispatch_custody.rs:164-182, 223-225), reads one big-endian-length JSON frame <= 22 MiB (dispatch_custody.rs:18, 192-205) and queues it with a 300 s or 1,800 s reply deadline and a "not started => refused / started => uncertain" phase handshake (dispatch_custody.rs:102-115, 235-259). The legacy "b44/zero" receiver can act only on one hard-coded incident and is dead weight elsewhere (B-F12).

**(5) config_migration.rs.** Migrates: `providerTask.contextWindowTokens`, `.maxIterations`, `.maxRequestBytes`, `providerTask.onBehalfOf.publicKey` (same subject, observed current and granted), and transport fields `/mini`, `/host`, `/hostConfig`, `/hostSocket` and the room equivalents under a root-owned admission artifact (config_migration.rs:566-590, 627-666). Mechanism: a prepared/published/activated pointer `config-migration.json` plus an immutable archive `config-migrations/migration-N/` with before/after blobs for config, journal and optional workspace (config_migration.rs:134-175, 691-756, 1097-1233). It exists because the journal binds the exact controller config (`binding == {"config":old,"configPath":path}`, config_migration.rs:800, 893), so any config edit to a used controller needs it. Still needed only if live controllers must be retuned without reprovisioning; no journey runs it (section 5.2). Versioned siblings: one format `mini-controller-config-migration-v1` plus an optional `miniAdmission` (Mini-only) sibling of `compatibleAdmission` (config_migration.rs:21-24, 247-339).

**(6) mcp.rs + gitweb_worker.rs.** What a prompt-injected model can do: call any tool in the catalog (mcp.rs:283-402) through the stdio edge, or connect directly to `/run/mini-grain.sock` from any process in the sandbox (the socket is a ro bind mount, bwrap:125; Unix `connect` works on read-only mounts) and send any `{"name","arguments"}` line including `__mini_gitweb_http_raw` and `__catalog`. The controller handles `__mini_gitweb_http_raw` with the same `begin_application_api` as `mini_application_api`, differing only in returning the raw reply (main.rs:15066-15091, 8494-8545), and refuses every tool request whose `prompt_epoch != 1` (main.rs:8469-8473). Every effect is a signed intent Lean admits (A Appendix D). `gitweb_worker` restrictions (read cannot POST receive-pack, one receive-pack per edit, path profile, 16 HTTP requests, 180 s) are all inside the sandboxed MCP process (gitweb_worker.rs:369-384) and so are UX, not security; the model can bypass them with `mini_application_api`, which the catalog exposes for the same apps (mcp.rs:373-399). Bounds: broker request line 64 KiB (mcp.rs:148-162), controller reply to stdio edge 16 MiB (mcp.rs:426-431), stdio frames 64 KiB (mcp.rs:466-477), 8 concurrent broker connections (mcp.rs:104-107), queue of 8 (mcp.rs:92). No tool bypasses Lean admission (section 3.3).

**(7) query_observation / pending_prepare / grain_source.** Reads: `mini query --view resource|policy` into a fresh `query-N/attempt` directory (query_observation.rs:149-179), then `view.json`/`challenge.json` are trusted as already verified by the pinned client (query_observation.rs:205-229); a retry happens only for a Host-decoded op-255 `stale-root` refusal bound to the exact retained request (query_observation.rs:49-124), at most 3 times (query_observation.rs:6, 22-34). Intent JSON authored by Rust (grain_source.rs:67-88): `{"grain":{task, subject, capability, schemaVersion:"1", expectedTargetRoot, context:{operationId, payload}, before:{generation,status,remaining,reserved[,route]}, operation, publications, observeCapability[, parentWitness]}, "grants":[...], "intentNonce"}`; Lean admits all of it (capability/grants are authority; `expectedTargetRoot` + `before` are the stale check; `operation` is checked by the grain law and route law; `context` is hashed into the nonce, Json.lean:2700-2707). `operationId` is SHA-256(domain-separated controller, task, subject, local counter) rendered as a 256-bit decimal (grain_source.rs:6-32). Trusted, not admitted: which operation to author when (Rust's state machine), the local counter, and the payload label wording (used by Rust as a recovery discriminator, provider_history.rs:72-75, provider_continuity_rejection.rs:239-244). `pending_prepare` re-submits the same retained parent `settle` source into a new `reprepare/` attempt only after proving no `call.bin` exists anywhere in the ancestry and the controller cgroup is sole member (pending_prepare.rs:129-265).

**(8) op-17 continuity story and twins.** Before send, main.rs runs `mini continuity` and requires the returned anchor to equal the retained reserve receipt (A 1.3.7); the descriptor fed to it is `provider_history::provider_continuity_value` (`mini-provider-continuity-v1`, reserve call/outcome/receipt plus an optional fence, provider_history.rs:359-432), and Lean takes the provider id from the signed call, not from the descriptor (Host/Main.lean:5534-5542, 5589-5590). After a crash: `provider_recovery` settles a response that has exact delivery evidence (provider_recovery.rs:6-29, 109-131); `provider_retirement` retires a reserve that was refused before any send (provider_retirement.rs:5-13, 55-86); `provider_continuity_rejection` retires a pending settle/disconnect whose resource-client continuity gate refused before signing (provider_continuity_rejection.rs:298-329, consumed at provider_history.rs:109-138); `provider_resolution` retires a pending settle whose native outcome was `contention` and whose signed deadlines have all expired (provider_resolution.rs:163-327, 330-427). None of them releases a provider hold (every record says `heldAllowanceReleased:false`), so the hold itself still needs `reconcile provider audited`, which cannot handle `uncertain:` (F1). Twins: the three source re-derivation validators (section 5.4 T4) and two bounded readers (T1); otherwise the five modules are complementary, not duplicates.

**(9) hermes_room / hermes_outcome / hermes_session_verify.** "The session failed": `hermes_outcome::validate_completion` accepts only `stopReason == "end_turn"` or a typed `mini-hermes-turn-failure-v1` JSON-RPC error with code -32003 emitted by the worker (hermes_outcome.rs:6-17, 54-66), and refuses completion while any terminal blocker remains (hermes_outcome.rs:20-27, 56-59). "Deliverable": additionally, for a managed provider, the journal must hold no provider pending/hold/attempt and at least one replay for this prompt and generation with status 200 and a retained Lean quote (hermes_outcome.rs:67-78); resident delivery is staged by main.rs on `end_turn` (A V8). `hermes_session_verify` is a zero-charge readiness probe that loads the retained ACP session and requires unchanged signed parent `remaining` and zero `reserved` (hermes_session_verify.rs:36-110). `hermes_room` contains both the resident assignment preparation used by the durable ACP controller (`prepare_resident`, hermes_room.rs:510-556, called at room_resident.rs:309) and a legacy independent runner (`hermes-room step|serve`, hermes_room.rs:560-600).

---

## 1. What this code is and does

### 1.1 The provider gateway family

#### provider.rs (3,197 lines: code 1-1631, `test_broker` 1633-1716, tests 1718-3193, homelab test submodule 3195-3197)

The module doc states the contract: the edge "cannot authorize a provider send"; it asks the controller for a durable native reserve and an exact parent witness, then a durable send-boundary acknowledgement (provider.rs:1-6).

Data model:

* `GatewayConfig` (provider.rs:28-46): `scheduled_homelab`, `bind`, `unix_socket`, `pinned_model`, `private_dir`, `max_request_bytes`, `max_response_bytes`, `timeout`, paired optional `max_input_tokens`/`max_output_tokens`. The only production constructor passes both token ceilings as `Some` (main.rs:14500-14501), so the "unmetered" branch where `bounded_chat_request` is skipped (provider.rs:957) is reachable only from tests.
* `LeaseId {prompt_operation_id, parent_generation}` and `Lease {id, worker_token}` (provider.rs:48-58).
* `ProviderRequest {placement, lease, model, exact_body}` (provider.rs:60-68).
* `Route {endpoint, provider, broker: mini_keys::client::Broker, ticket: Option<String>}` (provider.rs:70-85): `ticket == None` means a homelab row sent without a bearer.
* `ForwardPermit::Fresh {attempt_id, lease, exact_body, route}` / `::Replay {lease, exact_body, status, content_type, exact_response}` (provider.rs:87-105).
* `ProviderOutcome::Received {status, content_type, exact_headers, exact_body}` / `::NotSent {reason}` / `::Uncertain {partial_body, reason}` (provider.rs:107-124).
* `ProviderCommand::{Prepare, Reserve, BeforeSend, Outcome, Delivery}` each with a reply `Sender` (provider.rs:126-149); these are consumed by main.rs `handle_provider` (main.rs:9185-9272).
* `Shared` (provider.rs:157-167): lease mutex, `revoked`, `active_request`, `busy_responders`, `last_permit_id`, the in-flight broker connection `upstream`, the worker connection `client`, `stop`.

Control surface `GatewayControl` (provider.rs:257-391): `activate` (deadline <= 1,800 s, token shape, rotation, refuses while a request is active, provider.rs:263-297); `revoke` (sets `revoked`, clears lease under the lease lock, shuts down the broker connection and the worker connection, never waits, provider.rs:299-322); `is_idle` (provider.rs:327-329); `current(token)` (provider.rs:331-348); `still_active(lease)` (provider.rs:350-366); `with_send_gate` (provider.rs:371-390), the linearization point between revoke and the broker send.

Lifecycle `GatewayEndpoint::start` (provider.rs:400-533): validates config (provider.rs:568-606: loopback bind, bounds, model name, token ceilings 1..131,072 / 1..8,192 and paired, private dir absolute 0700 owned); for a Unix socket requires it directly in `private_dir`, probes an existing owned socket and removes it only if `connect` is refused (provider.rs:406-431), binds, chmods 0600, rechecks owner (provider.rs:432-440) and remembers (path, dev, ino) for `Drop` (provider.rs:543-557). The accept loop polls every 20 ms (provider.rs:471-526); one request at a time is served by `serve_client` on its own thread; overlapping connections get a bounded busy responder (provider.rs:475-496).

`serve_client` (provider.rs:926-1131), the request state machine:

1. `read_request` (provider.rs:742-847) -> 400 on any parse failure (provider.rs:932-938).
2. Lease token -> 401 (provider.rs:942-945).
3. JSON parse -> 400 (provider.rs:946-952); `model` must equal the pinned model -> 403 (provider.rs:953-956).
4. `bounded_chat_request` rewrite -> 400 (provider.rs:957-969).
5. Homelab only: `Prepare` -> optional `homelab::Plan` -> `Plan::wait` for a scheduler placement (provider.rs:976-988).
6. `Reserve` -> `Replay` (validated and written verbatim, provider.rs:1003-1025) or `Fresh` (attempt id nonzero, same lease, same bytes, `validate_endpoint`, provider.rs:1026-1041).
7. `last_permit_id.fetch_max` refuses a non-increasing attempt id (provider.rs:1044-1051).
8. `BeforeSend` -> on failure report `NotSent` and 503 (provider.rs:1052-1072).
9. Homelab: the placement endpoint must equal the route endpoint (provider.rs:1073-1076; B-F2), then the guard outcome defaults to `Uncertain` (provider.rs:1077).
10. `forward` (provider.rs:1442-1631).
11. `report_outcome` (provider.rs:1191-1235): a `Received` outcome waits while the lease is live, anything else at most 30 s (provider.rs:1204-1211).
12. On `Received`: write the response, wait for the bridge byte on Unix (provider.rs:1137-1165), report `Delivery` (provider.rs:1120-1123, 1240-1267). Otherwise 502 "provider outcome is uncertain; no retry was sent" (provider.rs:1124-1129).

`forward` (provider.rs:1442-1631): creates `provider-{id:016}.request` with the exact body and empty `.response`/`.headers` spool files with `create_new` + fsync + directory fsync (provider.rs:1456-1470, 1269-1290); builds the broker request `{"op":"provider-forward","body":HEX,"timeoutMs","maxResponseBytes", "ticket"|"homelab"}` (provider.rs:1475-1481); inside `with_send_gate` connects to the broker, registers the stream for revoke and sends the frame (provider.rs:1486-1518); reads one little-endian length frame up to `mini_keys::wire::MAX_FRAME` (20 MiB) in 50 ms slices so a revoke interrupts it (provider.rs:1403-1440); maps broker refusals to `NotSent` (provider.rs:1532-1540), `withheld` (the response echoed the bearer) to `Uncertain` (provider.rs:1541-1546), writes headers and body into the spool with `O_NOFOLLOW` (provider.rs:1547-1568), re-reads the body bounded, fsyncs, checks the lease, `complete`, and parses headers (provider.rs:1569-1624).

`response_headers` (provider.rs:1305-1395) is exported to main.rs and provider_recovery.rs: at most 8 header blocks, interim 1xx allowed, exactly one final block, RFC 9110 token header names, no folded lines, `Content-Encoding` only `identity` and only once, exactly one printable Content-Type <= 128 bytes.

Error reporting: `native_reserve_refusal` maps a closed list of 16 Host `RefusalReason` names from a `provider reserve refused by Mini: {json}` error to a 403 code (provider.rs:877-906); `refusal_reply` also maps `provider-refused:CODE` (credentials refusals) to 403, or 402 for `no-credit` (provider.rs:908-924); everything else is a generic 503 so that paths do not leak (tests provider.rs:2243-2271).

`test_broker` (provider.rs:1633-1716) starts a real in-process `mini_keys::server::Broker` per endpoint/bearer with a fixture `mini-provider-table-v2` and `mini-keys-broker-v1` config, registers an `atexit` cleanup, and mints tickets; tests (provider.rs:1718-3193, 25 tests) cover output pinning, multiplier refusal, over-limit refusal before reserve, Unix socket lifecycle, bridge ack, revoke/send-gate ordering, header ambiguity, per-permit bearer, named refusals, lost outcome ack, cached replay, client reset, expired deadlines, hard revoke, lost upstream reply, bearer echo withholding, and in-flight revoke. They use a real broker and a fake upstream; the Mini side is the test's own channel replies.

#### provider_homelab_tests.rs (506 lines, all test)

Starts the real `minidregg_inference_scheduler::service::Service` as a child of the test binary (provider_homelab_tests.rs:12-23, 93-97), two gateways with `scheduled_homelab: true`, and a fixture controller that fakes only Mini's reserve/outcome acknowledgements while calling the real `Placement::verify`/`dispatch` (provider_homelab_tests.rs:183-318). Tests: two gateways share one GPU slot and an exact replay bypasses the queue (provider_homelab_tests.rs:398-458); an uncertain send keeps capacity quarantined (`State::Uncertain`) and a revoked queued wait is cancelled without reaching upstream (provider_homelab_tests.rs:460-506). The second test documents that one uncertain homelab call removes that GPU slot from the shared pool until reconciliation.

#### homelab.rs (190 lines)

Physical placement adapter for `native/inference-scheduler` (homelab.rs:1). `Config {socket, controller, domain, principal, pool, backends, queue_timeout_ms}` (homelab.rs:11-23); `Plan {config, request}` (homelab.rs:25-29); `Placement {config, request, lease, endpoint}` (homelab.rs:31-38). `Plan::wait` enqueues, refuses a retained deadline later than the current pin, then polls `Inspect` every 100 ms until `Placed`, mapping `Drained` to `provider-refused:homelab-drained-before-send` and cancelling when the prompt stops (homelab.rs:40-102); `check` pins controller/principal/pool/request (homelab.rs:104-113). `Placement::verify` re-inspects and requires the same lease and endpoint (homelab.rs:116-139), `dispatch` records the Mini attempt id with the scheduler (homelab.rs:141-159), `finish` reports the outcome (homelab.rs:161-172). `Guard::drop` always calls `finish`, logging failure with `eprintln!` only (homelab.rs:175-190).

#### provider_profile.rs (257 lines; tests 144-257)

`require_worker_mcp_timeout` reads the private `config.yaml` (owned, 0600, <= 16 KiB) and requires `timeouts.mcp.tool_call >= wall - 60` (provider_profile.rs:10-50). `random_token` returns 64 lowercase hex from `/dev/urandom` (provider_profile.rs:54-66). `install_worker_profile` validates model, token, loopback gateway, MCP timeout 1..1,740, iterations 1..6, context 1..2,097,152 (provider_profile.rs:79-94), requires an owned 0700 home and an existing config only if it starts with the marker `# mini-grain-generated-provider-v1` (provider_profile.rs:95-121), and writes YAML with `api_key: TOKEN`, `base_url: http://GATEWAY/v1`, disabled memory and title generation, `max_iterations`, `context_history` `current_turn` for room-restricted residents, `platform_toolsets: acp: []` for room-only (provider_profile.rs:122-127), via `.config.yaml.tmp` with `create_new` + fsync + rename + dir fsync (provider_profile.rs:128-141).

#### provider_bridge.rs (296 lines; tests 275-296) -- the second binary

Described in question (3). `read_message` is shared for requests and responses with a 16 KiB header bound, Content-Length required, total bound checked with `checked_add`, header name token check and NUL/CR/LF refusal in values (provider_bridge.rs:26-31, 33-166). `write_bounded` writes 16 KiB chunks under the overall deadline (provider_bridge.rs:168-176). `proxy_one` uses 1 s socket timeouts on both ends, looping on `TimedOut` until the lifetime deadline (provider_bridge.rs:178-191). `main` exits with the child's code, 128 for a signal, 74 on bridge error (provider_bridge.rs:231-237, 265-273). One test checks framing (provider_bridge.rs:279-295).

### 1.2 Provider history and settlement-recovery family

#### provider_history.rs (618 lines; tests 448-618)

* `require_native_support` requires the Host profile string `providerContinuityAdmission == "exact-height-v1"` (provider_history.rs:6-15; emitted at Host/Main.lean:861 and Host/SourceAgreementReader.lean:140). Called before every fresh reserve and prepare (main.rs:9323, 9381).
* `Fence {operation_id, attempt, source_sha256, call_sha256, outcome_path, outcome_sha256, receipt}` with `deny_unknown_fields` (provider_history.rs:17-27).
* `input` re-hashes a retained call (<= 4 MiB) and outcome (<= 1 KiB) before naming them in a descriptor (provider_history.rs:33-48); `prefix` renders a receipt as `verified-mini-native-prefix-v1` (provider_history.rs:29-32).
* `validate_fence_source` (provider_history.rs:50-106) requires a fence source to be a source-owned `disconnect` with payload `"parent hard connection lost"` or `"operator fenced provider request"`, the retained identity, the hold's generation, status `3`, reserved amount and route code, and to be byte-equal to a fresh `grain_source::source` reconstruction.
* `retire_continuity_rejection` (provider_history.rs:109-138) clears `provider_pending` for a `provider settle|recovery settle|disconnect` whose attempt carries a verified rejection marker, logging `recognize-provider-continuity-rejection` with `heldAllowanceReleased:false`.
* `provider_fence_record` / `record_provider_fence` (provider_history.rs:140-245) build and attach the fence after a confirmed provider disconnect; the fence's `acceptedCount` must exceed the reserve's.
* `recover_provider_fence` (provider_history.rs:247-357) is the legacy path for journals that did not index the fence: scans up to 4,096 attempt directories after the reserve for a confirmed source-owned disconnect.
* `provider_continuity_value` / `provider_continuity_descriptor` (provider_history.rs:359-445) build the `mini-provider-continuity-v1` descriptor, re-checking that `intent.json` still hashes to `reserve_source_sha256`, and write `provider-continuity-source-N.json`.

#### provider_resolution.rs (543 lines; tests 430-543)

`resolve_guarded_provider_pending` applies only to `provider settle` / `provider recovery settle` whose `outcome.json` is `{"type":"contention"}` (provider_resolution.rs:330-349); proves the custody senders stopped (quiescence proofs, provider_resolution.rs:350-357), logs `inspect-expired-provider-contention`, runs `mini provider-continuity --guarded-attempt ATTEMPT --dir provider-resolution-N` through `command_output` (provider_resolution.rs:361-399), then `inspect` validates the client's `resolution.json` (provider_resolution.rs:163-327): pinned host/config/socket hashes, every copied input byte-equal at both its original and retained path (provider_resolution.rs:68-90), artifacts canonical inside the proof directory (provider_resolution.rs:91-109), the source equal to `source-N.json` and `verify_source` (provider_resolution.rs:208-221), the lookup presentation equal to its binary, and for `retire-expired-contention`: native lookup `absent`, original `contention`, all guarded inputs, the descriptor equal to the retained one, the reassembled call equal to `call.bin`, the profile's `genesisHeight`, and `expiration` (provider_resolution.rs:121-161): `genesisHeight + checkedAcceptedCount == checkedHeight`, `priorChecked` equals the original prefix, and every signed slot `validUntil` is strictly below `checkedHeight`. It inspects twice around a second stop proof and requires the hold and pending to be unchanged (provider_resolution.rs:400-416), then clears `provider_pending` on retirement (provider_resolution.rs:417-421). The decision itself is produced by Rust in resource-client (`native/resource-client/src/provider_continuity.rs:820-832`), which invokes op 17 (`session_invoke(..., 17, ...)`, provider_continuity.rs:812).

#### provider_continuity_rejection.rs (609 lines; tests 331-609)

Verifies a `provider-continuity-rejection.json` marker (`minidregg-provider-continuity-rejection-v1`, stage `before-signing`, reason `continuity-gate-rejected`, `heldAllowanceReleased:false`, six file bindings, provider_continuity_rejection.rs:16-36, 131-137) that the resource-client continuity gate writes when it refuses before signing. `inspect` (provider_continuity_rejection.rs:298-329) requires the marker, a sender-stopped proof before and after, byte-identical marker across the proof, and absence of every later artifact (`call.bin`, signatures, outcome; dangling symlinks count as present, provider_continuity_rejection.rs:8-14, 84-97). `verify_bindings` (provider_continuity_rejection.rs:114-203) binds intent, copied config, manifest, descriptor and original plan to the controller's own retained copies. `verify_source` (provider_continuity_rejection.rs:207-292) reconstructs the exact provider settle/disconnect source for the pending operation (payload strings fixed per operation at provider_continuity_rejection.rs:239-244; route must be `user|pool|homelab`) and compares byte-for-byte; it is also used by provider_resolution (provider_resolution.rs:221).

#### provider_recovery.rs (175 lines; tests 134-175)

`delivered` (provider_recovery.rs:6-29) requires 20 fields of the attempt and one replay entry to agree (request path/bytes/hash, response path/bytes/hash, status, content type, header custody, meter report path/hash, metered charge, prompt id, generation, `send_started`, `received:STATUS:TYPE`). `lookup_provider_settlement` re-looks-up a retained settlement with `mini retry --mode lookup` and requires `confirmed` + `installed|replayed` + the same anchor (provider_recovery.rs:32-64). `require_delivered_provider_response` revalidates bytes, the Lean quote or the prior settlement, and the raw headers (provider_recovery.rs:66-107). `recover_delivered_provider_response` calls `reconcile_provider_evidence(true)` when no child or pending exists and a delivered replay matches (provider_recovery.rs:109-131; called at main.rs:16056).

#### provider_retirement.rs (126 lines; tests 89-126)

`eligible` = no send boundary, no outcome, reserve not confirmed, and reserve refused or never submitted (provider_retirement.rs:5-13). `retained_reason` reads `outcome.json` or the Host-decoded pre-submit refusal (`inspected_pre_submit_refusal`, main.rs) and requires a lowercase refusal reason (provider_retirement.rs:15-45). `retire_refused_provider_request` additionally requires the whole controller idle (provider_retirement.rs:55-81) and calls main.rs `abort_refused_provider_request_with(true, Some(refusal))` (provider_retirement.rs:85). `refused_provider_for_prompt` lets main.rs recognize the refused-provider stop of a prompt (provider_retirement.rs:48-53; used at main.rs:14340, 14884-14891).

### 1.3 Provisioning family: credentials, choice, provision, owner

#### credentials.rs (1,888 lines; tests 1207-1888)

Header doc (credentials.rs:1-29) describes a layout `/etc/mini/providers.json`, `/etc/mini/credentials.key`, `/var/lib/mini/credentials/SUBJECT/PUBKEY/PROVIDER.{key,grants.json,usage.json}`, `_pool/PROVIDER.key` and "hosted custody" honestly ("does not hide the secret from root or from the service user", credentials.rs:26-29). Contents:

* constants and `REFUSED = "provider-refused:"` (credentials.rs:41-56); `refused(code)` (credentials.rs:69-71).
* `Secret` with redacted `Debug`, no `Display`, zeroing `Drop` (credentials.rs:73-108).
* `CredentialSource::{User, Pool, Homelab}` with `route()` names `user|pool|homelab` (credentials.rs:110-138), documented as the route the purse records and charges by (`Kernel/ProviderRoute.lean`).
* `Caps {per_call, per_day}` (credentials.rs:140-146); `ProviderRow`, `ProviderTable {sha256, rows}` (credentials.rs:148-161); `parse` (credentials.rs:241-335), `load(path, owner_uid)` (credentials.rs:337-352), `select(model, explicit)` (credentials.rs:354-368: explicit row or **the first row listing the model**, with no fall-through to another payer).
* `validate_endpoint` / `is_loopback_http` (credentials.rs:205-239).
* `Grant {runner, per_call, per_day, not_after, model, owner_epoch}` with `validate`, `to_json`, `from_json` (credentials.rs:373-464).
* `Owner {subject, public_key}` (credentials.rs:466-489); `Namespace::{Owner, Pool}`, `namespace_path` (credentials.rs:491-518).
* `CredentialStore {root, key: [u8;32], rooted_namespaces}` (credentials.rs:520-524) with `open` (credentials.rs:704-731), `directory` (credentials.rs:733-766), `aad`/`aead_key` (credentials.rs:768-780), `set` (credentials.rs:782-811), `secret` (credentials.rs:813-845), `grants`/`write_grants` (credentials.rs:847-892), `grant` (credentials.rs:894-914), `revoke` (credentials.rs:916-965, durable empty-grants first), `list` (credentials.rs:967-987), `authorize`/`authorize_model`/`authorize_model_epoch` (credentials.rs:989-1071: counts the call before returning the secret), `verify_grant` (credentials.rs:1073-1102, counts nothing), `pool` (credentials.rs:1104-1133), `count_call` (credentials.rs:1135-1190), `member_service_lock_until` (credentials.rs:686-702).
* filesystem helpers: `private_dir_check`, `root_directory_chain` (every ancestor root-owned, not g/w writable), `private_file_check`, `ensure_private_dir`, `replace_private` (atomic), `lock_until`/`provider_lock(_until)` (flock with a 2 s deadline, `O_NOFOLLOW` lock file) (credentials.rs:526-641).
* `utc_day()` from the system clock (credentials.rs:677-683); `secret_from_input` (credentials.rs:1193-1205).

Tests (15) cover namespace isolation, sealed-record transplant refusal, caps/expiry/revocation, redaction, native epoch, model scope, interrupted revoke, versioned grants, concurrent grants and symlinked locks, signed choice binding, table selection, endpoint shape, and secret input.

Which parts run where: grain-runtime uses `ProviderTable::{load, parse, select}`, `ProviderRow`, `CredentialSource`, `Owner::new`, `Grant::from_json`, `REFUSED`, `refused`, `validate_endpoint`, `is_loopback_http`, `provider_name`, `choice::Choice` (grep of `credentials::` across `src/`, scratch notes). `CredentialStore`, `Secret`, sealing, `count_call`, `secret_from_input` run only in mini-keys (`native/mini-keys/src/server/mod.rs:20-22, 261-266, 295, 355-357`; `server/provider.rs:123-137, 382`) and the resource-client `mini key` client (`keys.rs:73-88, 245, 284`).

#### provider_choice.rs (202 lines; included by credentials.rs:32-33)

`Choice {owner, runner, task, provider, model, table_sha256, signature}` (provider_choice.rs:7-16); `body` is `mini-provider-choice-v1` (provider_choice.rs:18-21); `signing_bytes` = `"mini/provider-choice/v1\0"` + length-prefixed fields (provider_choice.rs:22-37); `signed` and `signed_for_catalogue` sign with an Ed25519 seed whose public key must equal the owner key (provider_choice.rs:43-82); `from_json` checks shape and verifies the Ed25519 signature with `ring` (provider_choice.rs:83-131); `validate_route` requires the exact table digest and a `user` route row listing the model (provider_choice.rs:132-142); `digest` (provider_choice.rs:143-147). `CredentialStore::{choose, selected, choice_grant}` (provider_choice.rs:149-201) store and re-validate a choice and require an exact model-scoped grant plus a sealed secret. No nonce or expiry: a choice is valid until the table digest, grant or secret changes.

#### provider_provision.rs (228 lines; tests 200-228)

`grain-runtime provider-provision TEMPLATE OPERATOR_POLICY NEW_CONTROLLER` (main.rs:17988): parse a template controller config with a pinned `onBehalfOf` (provider_provision.rs:91-102), load the table (owner 0), ask the broker `provider-selected-choice` (provider_provision.rs:104-114), require the choice to name this owner/runner/task and a valid route (provider_provision.rs:115-119), intersect with the root-owned operator policy (provider_provision.rs:21-63, 120), set `provider`/`model` and `validate` (provider_provision.rs:121-128), write `provider-provision-intent.json` (or require an identical retained one) (provider_provision.rs:130-158), open a real `Runtime` on the new state dir and require a query-only journal (provider_provision.rs:75-85, 161-162), read the Host tariff and pin the user route (provider_provision.rs:168-170), query parent/tool/provider and require each source grain `generation/status/reserved == "0"` (provider_provision.rs:64-74, 171-181), observe owner and grant (provider_provision.rs:183-184), write `provider-provision-complete.json` and the controller config (provider_provision.rs:185-192). Idempotent on exact re-run (provider_provision.rs:134-146).

#### provider_owner.rs (197 lines; no tests)

`observe` runs `mini key --action owner-status --host --config --socket --subject --public-key` (op 144 via resource-client), requires `subject-key-status-v1`, `isCurrent`, `!currentRevoked`, a canonical epoch, and unchanged mini/host/config hashes before and after (provider_owner.rs:27-81). `grant_evidence` takes a fresh signed height (`source_height`, provider_owner.rs:126-196: a `mini query` into `owner-observation-NANOS/`), re-observes the epoch, requires a `user` row, asks the broker `provider-verify-grant` (counts nothing), and requires `per_call >= maxOutputTokens` (provider_owner.rs:85-124). Used by provider_provision.rs:183-184 and config_migration.rs:515-516.

### 1.4 Custody, dispatch and the legacy audit

#### custody_gate.rs (382 lines; tests 284-382)

Module doc (custody_gate.rs:1-7): linearizes work-origin Mini child creation with a hard connector break; a child that crossed spawn remains an uncertain exact attempt. `CustodyGate {child: Mutex<Option<Child>>}` (custody_gate.rs:21-24); `CustodyError::{BeforeSpawn, Uncertain(io::Error)}` (custody_gate.rs:26-33); `cancel` kills the tracked child under the lock (custody_gate.rs:57-75); `is_idle` is false on a poisoned lock (custody_gate.rs:77-81); `run_capture` checks `cancelled` under the lock before spawning, refuses a second child, pipes and drains both streams non-blockingly with a 1 MiB cap each (overflow cancels), and treats a descendant that keeps a pipe open more than 300 ms after the leader exits as uncertain (custody_gate.rs:83-223); `reap_after_abort` waits up to 2 s (custody_gate.rs:225-248). Used by main.rs `work_output` and `supervised_json_command` (A F2, main.rs:7584-7653) and checked idle by provider_retirement.rs:67 and pending_prepare.rs:150.

#### dispatch_custody.rs (476 lines; tests 388-476)

Described in question (4). The `Command` enum (dispatch_custody.rs:23-99) is tagged kebab-case with `deny_unknown_fields`: v1 `reserve`, `mark-send`, `settle-definite`, `abort-no-send`, `inspect`; v2 `reserve-v2`, `inspect-v2`, `sign-payer-v2`; v3 `reserve-v3`, `inspect-v3`, `inspect-settlement-v3`, `sign-payer-v3`, `mark-send-v3`. `Request {command, reply, deadline, phase}` and `Server {requests, stop, path, socket_identity}` (dispatch_custody.rs:118-130). `start` binds, chmods, installs and verifies the ACL, requires the inode unchanged, and spawns an accept thread admitting 4 connections (dispatch_custody.rs:266-320). `decode_hex` accepts lowercase only (dispatch_custody.rs:369-386). The commands are executed by main.rs `dispatch_rpc` (A 5.3).

#### dispatch_runtime_tests.rs (643 lines, Linux-only tests)

Three tests compiled under `#[cfg(test)]` from main.rs (A 5.1): the agent route participant subject is the parent subject (dispatch_runtime_tests.rs:4-125); a confirmed v2 reserve recovers the missing purse generation and post-root after a crash (dispatch_runtime_tests.rs:127-294); and the v1 separate dispatch reserve is one-shot, cannot abort after mark-send, and recovers several crash windows (dispatch_runtime_tests.rs:296-643). The last test calls `dispatch_mark_send(id, request_sha, "777", "778", &"a".repeat(64))` and then `dispatch_settle_definite` (dispatch_runtime_tests.rs:460-469): it confirms A's V5 that v1 accepts any SPK-host-supplied transaction/event/permit strings. All run against shell-script `mini` stand-ins.

#### legacy_custody_audit.rs (819 lines; test 797-819)

Module doc (legacy_custody_audit.rs:1-5): an operator audit of one legacy Mini client profile that returned before retaining a call. 13 pinned SHA-256 constants (legacy client, client source, runtime binary and source, Host, source, reserve outcome, attempt manifest, config, challenge bin/json, signed observation) and the reserve boundary decimal (legacy_custody_audit.rs:16-36). `inspect` (legacy_custody_audit.rs:273-450) refuses unless operation 44, prompt 36, parent task 7803, tool task 7804, subject 10, reserve attempt 42, held reserve 2, generation 3 (legacy_custody_audit.rs:275-298), an operator manifest `legacy-b44-audit.json` (`minidregg-legacy-custody-no-dispatch-audit-v1`, legacy_custody_audit.rs:69-89) with matching pins, no later-stage artifact (legacy_custody_audit.rs:135-164), a fenced worker gate and an inactive `systemctl --user` unit with an empty cgroup (legacy_custody_audit.rs:166-220), and no owned process whose argv contains the attempt path (procfs scan, legacy_custody_audit.rs:222-268). `audit_b44` clears the tool pending (legacy_custody_audit.rs:476-606); `settle_b44_zero` fences if needed and settles the tool hold at charge 0, confirmed by exact lookup and a signed paused grain (legacy_custody_audit.rs:608-795). `zero_phase_active` is consulted by main.rs:16255. Admin commands `reconcile tool legacy b44|zero` (main.rs:17800-17801).

### 1.5 config_migration.rs (2,033 lines; tests 1431-2033)

Module doc: "Explicit, recoverable controller configuration publication. This never authorizes a new grain, key, grant, provider payment, or resource operation" (config_migration.rs:1-3).

Data model: `Request` (`mini-controller-config-migration-v1`: expected config hash, expected binding hash, target config path and hash, optional `residentState`, `compatibleAdmission`, `miniAdmission`, config_migration.rs:11-24); `AdmissionPin {path, sha256}`; `Role::{Config, Journal, Workspace}`; `Change {role, path, before_sha256, after_sha256}`; `Transaction` (config_migration.rs:55-71); `Pointer {protocol, transaction, manifest_sha256, phase, activated_pid}` and `Phase::{Prepared, Published, Activated}` (config_migration.rs:72-87); `MiniAdmission` (`mini-controller-client-upgrade-v1`, config_migration.rs:247-262); `OwnerRotation` (`mini-controller-owner-rotation-observation-v1`, config_migration.rs:413-425).

Decisions: `permitted_diff` computes JSON-pointer differences (config_migration.rs:177-194) and allows only the fields listed in question (5) (config_migration.rs:549-668); transport changes require exactly one admission (config_migration.rs:627-666): `admitted_transport` uses the `compatible-upgrade-custody` crate (`custody::load`, `image`, `root_pin`, `root_bytes`) and a unique `hermesProfiles` entry binding old config, binding and Host config (config_migration.rs:195-224, 341-409); `admitted_mini` checks a root-owned Mini-only artifact (config_migration.rs:263-339). Owner rotation requires a fresh native owner observation and grant (config_migration.rs:426-547).

State machine: `migrate_config` (config_migration.rs:1097-1233): read request -> return a completed receipt if this exact publication is activated -> `checked_request` -> fresh owner observation -> under a `ResidentGuard`, take a closed quiescence checkpoint -> retain before/after blobs, quiescence, resident, owner rotation, `transaction.json` -> publish pointer `Prepared` -> `apply_changes` (check every member is old-or-new before replacing any, config_migration.rs:727-756) -> pointer `Published`. Startup: `recover_startup` (config_migration.rs:1000-1048) validates the transaction, proves the prior run stopped, re-observes the owner, re-applies, sets `Published`; `activate_startup` sets `Activated` with the current PID (config_migration.rs:1084-1094); `ensure_process_current` refuses any save/effect in a process that is not the activated PID once a pointer exists (config_migration.rs:963-975; called on every `save`, main.rs:6917, and in the serve loop, main.rs:17595). Clients: `config-migrate active ADMIN_SOCKET REQUEST` and `config-migrate stopped CONFIG REQUEST` (config_migration.rs:1236-1256; main.rs:17938-17941); scope preflight/receipt for credential-scope staging (config_migration.rs:1289-1429; reached through `controller-write-scopes preflight|receipt`, controller_write_scopes.rs:31-45, main.rs:17933).

### 1.6 MCP broker and GitWeb worker

#### mcp.rs (926 lines; tests 566-926)

Two halves in one file:

* Controller side: `start_broker(path, worker_wall, catalog)` binds `state_dir/mcp-N.sock` 0600 (mcp.rs:77-132; called per prompt at main.rs:14598-14604), accepts up to 8 connections (mcp.rs:104-107), reads one line <= 64 KiB with a 5 s deadline (mcp.rs:141-162), answers `__catalog` immediately from the `ToolCatalog` (mcp.rs:169-195), otherwise forwards `BrokerRequest {name, arguments, prompt_epoch, reply}` to the controller over a `sync_channel(8)` and waits `worker_wall + 10 s` (mcp.rs:196-218). `BrokerEndpoint::{activate_prompt, deactivate_prompt, replace_catalog}` (mcp.rs:35-51). `ToolCatalog` (mcp.rs:64-75).
* Sandbox side: `serve_stdio(socket)` implements MCP JSON-RPC over stdin/stdout (mcp.rs:458-564): `initialize`, `ping`, `tools/list` (fetches `__catalog`, validates names, builds tool schemas, mcp.rs:224-281, 283-402), `tools/call` (refuses `__*` names, mcp.rs:404-406, 505-506; runs `gitweb_worker::read|edit` locally for `mini_gitweb_read|edit`, forwarding each Git HTTP request as `__mini_gitweb_http_raw`, mcp.rs:507-549; else proxies the call, mcp.rs:550-552). `call_controller_with_timeout` writes one line and reads a reply <= 16 MiB under a total deadline (1,810 s default, mcp.rs:15-17, 408-437, 439-456).

Tool catalog (mcp.rs:283-402): always `mini_grain_status`, `mini_read_resource`, `mini_publish` (removed for a room-only catalog, mcp.rs:294-296); with a resource workspace nine `mini_workspace_*` tools (mcp.rs:297-327); room tools plus `mini_room_attempts` (mcp.rs:328-333); `mini_workspace_create` (mcp.rs:334-342); legacy `mini_create_resource` only when the workspace cannot create (mcp.rs:343-350); `mini_create_application` (mcp.rs:351-355); `mini_create_application_session` (mcp.rs:356-372); `mini_gitweb_read`, `mini_gitweb_edit`, `mini_application_api` for API apps (mcp.rs:373-400).

#### gitweb_worker.rs (898 lines; tests 672-898)

Runs inside the sandboxed MCP edge (gitweb_worker.rs:1-3). `input` (gitweb_worker.rs:27-80) bounds application (`*-app`), path (<= 256, no `.`/`..`/`.git`/leading `-`, `[A-Za-z0-9._-]` components), content (<= 8 KiB, no NUL), message (<= 256, no control chars). `read`/`edit` (gitweb_worker.rs:428-670) bind a loopback TCP listener on an ephemeral port, generate a 256-bit proxy token (gitweb_worker.rs:119-125), run `/usr/bin/git` with a cleared env, `protocol.version=0`, and `http.extraHeader: X-Mini-Git-Proxy-Token` (gitweb_worker.rs:290-324), and serve Git's HTTP requests (`serve_git`, gitweb_worker.rs:346-419): `read_http` admits only `GET /repo.git/info/refs?service=git-upload-pack|git-receive-pack` and `POST /repo.git/git-upload-pack|git-receive-pack`, body <= 24 KiB, token required (gitweb_worker.rs:127-250); each request becomes a `forward(call)` whose reply must be `http-v3` with a body <= 512 KiB (gitweb_worker.rs:252-288, 385-397). Edit = clone (no mutation) -> write file without following symlinks -> `git add/commit` as "Mini Agent" -> push (exactly one receive-pack POST) -> `ls-remote` verification (gitweb_worker.rs:518-670). Scratch directories in `std::env::temp_dir()` are removed on drop (gitweb_worker.rs:421-426).

### 1.7 Hermes modules

#### hermes_outcome.rs (136 lines; tests 82-136)

`typed_failure` (hermes_outcome.rs:5-17), `failure` (hermes_outcome.rs:18), `terminal_blockers` (hermes_outcome.rs:20-27: the quiescence retained list minus the active prompt's own markers), `validate_refusal_stop` (hermes_outcome.rs:28-35), `retain_failure` / `close_failure` write `hermes-failed-PROMPT.json` / `.closed.json` with the journal hash and provider replays (hermes_outcome.rs:37-52), `validate_completion` (hermes_outcome.rs:54-80). Called by main.rs:14878-14909, 15016-15019 (A).

#### hermes_session_verify.rs (147 lines; tests 113-147)

`Invocation::{Prompt, ResidentPrompt{prompt, resident_id, digest}, Verify}` with `prompt`, `resident_identity`, `is_prompt`, `charge` (`"0"` for Verify), `label` (hermes_session_verify.rs:5-26). `verify_hermes_session` (hermes_session_verify.rs:35-110) requires the controller unit proof, quiescence, a retained session with a fingerprint, a scoped `hermes-acp` command, a zero parent reservation; may temporarily attach and then restore with a native `mode` + `disconnect` (hermes_session_verify.rs:70-84); requires unchanged parent `remaining`, zero reserved, unchanged provider counters and replays, the same session id with `load_verified` (hermes_session_verify.rs:86-101). Admin command at main.rs:17772.

#### hermes_room.rs (670 lines; tests 602-670)

Module doc: the Hermes room runner, "journaled line by line" with `send`/`recv`, `deciding`/`paid`/`submitter`/`resolved` (hermes_room.rs:1-32). `Config` (`mini-hermes-room-runner-v1`: tools, inbox, state, optional provider `{url, model}`, `maxRounds` default 8, hermes_room.rs:45-74). `Journal` replayed from `journal.jsonl` (append + fsync per event, also printed to stdout, hermes_room.rs:80-186). `complete` (hermes_room.rs:190-223): plain HTTP/1.1 POST to a loopback provider, no Authorization header, 600 s read timeout, `read_to_end`, status detected by `contains(" 200 ")`. `Runner` (hermes_room.rs:236-505): `recover` marks unanswered sends `abandoned`, waits up to 600 s for a recorded submitter PID to disappear (`/proc/PID/cmdline` containing `shell` and the marker, hermes_room.rs:246-257), then resolves a `say` by a signed tail of the last 100 entries (`said_already`, hermes_room.rs:333-347) and other writes by `RoomTools::lookup`; `adopt` runs `mini credit --action adopt`, joins the room through the shell line `chat join`, imports the program document reference (hermes_room.rs:354-390); `write` pays first through `RoomTools::pay`, then writes, journaling between (hermes_room.rs:392-435); `dismissed` returns the budget with `mini credit --action return` (hermes_room.rs:437-450); `attach` runs up to `max_rounds` chat-completions rounds with the room tools as functions (hermes_room.rs:452-504). `prepare_resident` (hermes_room.rs:507-556) is the non-legacy part: verifies a dismissal or handoff through `mini hermes-handoff --action check-dismissal|check-delivery`, adopts, collects the program and context (`resident_context::collect`), computes the request discovery cursor, and returns `mini-hermes-resident-assignment-v1` (called at room_resident.rs:309). `step`/`main` implement `grain-runtime hermes-room step|serve CONFIG [SECONDS]` (hermes_room.rs:558-600; main.rs:18016).

#### hermes_catalogue_probe.rs (93 lines, `#[ignore]` test)

An opt-in qualification that starts a broker with a room catalog, runs the installed Hermes runtime inside bwrap three times (installed, historical `venv-before-mcp2`, empty catalogue) with `deploy/hermes/runtime-inputs/probe-catalogue.py` and checks the reported tool catalogue (hermes_catalogue_probe.rs:11-93). The script it asserts exists (hermes_catalogue_probe.rs:30-32) is absent from the tree (`find` over the repo, scratch notes), so the test fails at its first assertion if anyone runs it.

### 1.8 Source authoring and observation

#### grain_source.rs (117 lines; tests 90-117)

`operation_id` (grain_source.rs:6-32): SHA-256 over `"DREGG/GRAIN-CONTROLLER/OPERATION/v1\0"` and four big-endian-length-prefixed fields, rendered in decimal by schoolbook base conversion. `retained_identity` (grain_source.rs:34-55) accepts a source whose `context.operationId == intentNonce` and equals either the legacy local counter or the namespaced id. `Transition {identity, payload, operation, publications, parent_witness, grants}` (grain_source.rs:57-64). `source` (grain_source.rs:66-88) authors the JSON shown in question (7).

#### pending_prepare.rs (395 lines; tests 268-395)

`ancestry` allows only `attempt-N[/reprepare]*` up to 8 levels (pending_prepare.rs:6-24); `validate_source` requires an unconfirmed-uncertain-free `settle` pending with a confirmed hold, `due == hold.charge`, a signed parent in status 3 or 4 with the hold's generation and reservation, the retained identity, and byte equality with a fresh reconstruction (pending_prepare.rs:26-93); `next_attempt` reuses an already-claimed absent path (pending_prepare.rs:106-122); `reprepare_parent_settlement` (pending_prepare.rs:128-265) runs only during startup recovery with nothing else in flight, proves the controller cgroup is sole member (`prove_prior_run_stopped`, pending_prepare.rs:124-126), checks every ancestry directory for absent `call.bin` and matching `intent.json`/`config.json`/`attempt.json`, queries the parent, re-checks stop and absence, journals `reprepare-interrupted-parent-settlement`, points `pending.attempt` at the new path, saves, and runs `mini submit --intent-kind grain-intent` through `command_output`. Called from main.rs:17038 (A).

#### query_observation.rs (460 lines; tests 233-460)

Described in question (7). `stale_query_via_with` (query_observation.rs:57-124) validates the client's `query-refusal.json` marker (`minidregg-query-refusal-v1`, stage `query`, operation 5), the manifest, the copied config and intent, the absence of later artifacts, four artifact hashes, and that the frame starts with byte 255, then has the Host decode it with `HOST CONFIG inspect outcome` (query_observation.rs:181-197). Called by main.rs:7748, 7751 (A).

### 1.9 Data model summary

| type | file:line | persisted where | notes |
|---|---|---|---|
| `GatewayConfig` | provider.rs:28-46 | not persisted | built per prompt at main.rs:14489-14504 |
| `Lease`, `LeaseId` | provider.rs:48-58 | not persisted | token also written to worker `config.yaml` |
| `ProviderOutcome` | provider.rs:107-124 | rendered as `attempt.outcome` string `received:S:T` / `not-sent:R` / `uncertain:R` (main.rs:9913-9956) | |
| `homelab::Placement` | homelab.rs:31-38 | journal (`attempt.placement`, main.rs:16520) | |
| `Fence` | provider_history.rs:17-27 | journal (`provider_attempt.fence`) | |
| `Marker` (rejection) | provider_continuity_rejection.rs:22-36 | `attempt-N/provider-continuity-rejection.json` (written by resource-client) | |
| `ProviderTable`, `ProviderRow`, `CredentialSource`, `Caps` | credentials.rs:116-161 | `/etc/mini/providers.json` (root) | |
| `Grant`, `Owner` | credentials.rs:373-489 | broker credential root | |
| `Choice` | provider_choice.rs:7-16 | broker `choice-TASK.json`; controller `provider-provision-intent.json` | |
| dispatch `Command` | dispatch_custody.rs:23-99 | not persisted (main.rs journals effects) | |
| `AuditManifest` | legacy_custody_audit.rs:69-89 | `state/legacy-b44-audit.json` (operator input) | |
| migration `Request`, `Transaction`, `Pointer`, `OwnerRotation` | config_migration.rs:11-87, 413-425 | `config-migration.json`, `config-migrations/migration-N/` | |
| `BrokerRequest`, `ToolCatalog` | mcp.rs:19-24, 64-75 | not persisted | |
| hermes-room `Journal`, `Op` | hermes_room.rs:82-101 | `STATE/journal.jsonl`, `STATE/adoption.jsonl` | |
| `Invocation` | hermes_session_verify.rs:5-10 | not persisted | |
| `Transition` | grain_source.rs:57-64 | rendered into `source-N.json` and `attempt-N/intent.json` (main.rs) | |

### 1.10 State machines

**Gateway request** (provider.rs:926-1131): `read -> auth -> pin -> [prepare/wait placement] -> reserve -> (replay -> write -> end) | (fresh -> permit-id check -> before-send -> forward -> outcome -> (received -> write -> bridge-ack -> delivery) | (not-sent|uncertain -> 502/503))`. Exits without any outcome report after the controller already holds a reserve: permit mismatch (provider.rs:1010-1022, 1032-1039), permit replay (provider.rs:1044-1051), homelab endpoint mismatch after the send boundary (provider.rs:1073-1076).

**Lease**: `revoked=true` at start (provider.rs:459) -> `activate` -> `revoke` (hard EOF, prompt end) -> `activate` with a new token. The worker deadline (<= 1,800 s) ends a lease without revoke (provider.rs:336-341).

**Provider attempt outcome strings** (main.rs:9913-9956, written by provider.rs outcomes): `received:STATUS:TYPE` -> quote -> delivery -> replay entry -> settle(quote) ; `not-sent:R` -> settle("0") automatically (main.rs:9244-9253) ; `uncertain:R` -> note "may have reached upstream" and no exit (A F1). `uncertain:raw-header-metadata-mismatch` is set when headers parse differently from the reported metadata (main.rs:9990-9998).

**Homelab job** (scheduler side): `Queued -> Placed{lease, endpoint} -> Dispatched{lease, attempt} -> Terminal{Ended|NotSent|Cancelled|Drained} | Uncertain` (homelab.rs:70-91, 151-158; provider.rs:1088-1094).

**Config migration**: `none -> Prepared -> Published -> (restart) -> Published (recovered) -> Activated(pid)` (config_migration.rs:1216-1229, 1041-1043, 1089-1091).

**hermes-room write**: `deciding -> paid|unpaid -> submitter(pid) -> resolved(performed|refused|uncertain)`; at restart `deciding` without `paid` -> `resolved uncertain`; `paid` with submitter -> wait for the PID to vanish -> lookup or signed tail (hermes_room.rs:289-331, 392-435).

### 1.11 Wire formats spoken

| wire | endpoints | framing | file:line |
|---|---|---|---|
| worker -> gateway | Hermes (or bridge) -> `provider-gateway.sock` / `127.0.0.1:P` | HTTP/1.1, Content-Length, `Connection: close`, one request per connection | provider.rs:742-870 |
| bridge -> gateway | `/run/mini-provider.sock` | the same HTTP bytes, then one ack byte `1` from bridge to gateway | provider_bridge.rs:178-191; provider.rs:1137-1165 |
| gateway -> mini-keys broker | `Broker.socket` | u32 LE length + JSON (`provider-forward`), reply `{"ok":true,"complete","headers":HEX,"body":HEX}` or `{"ok":true,"withheld":true}` or `{"refused":CODE,"detail"}` | provider.rs:1475-1505, 1403-1440; mini-keys wire.rs:1-22, server/provider.rs:356-363 |
| controller -> broker (provisioning) | same | `provider-selected-choice`, `provider-verify-grant` | provider_provision.rs:108-114; provider_owner.rs:108-114 |
| gateway -> scheduler | `homelab.socket` | `minidregg_inference_scheduler::request(Command)`, JSON, `MAX_FRAME` 64 KiB | homelab.rs:43-100; inference-scheduler lib.rs:12-40 |
| SPK host -> dispatch socket | `dispatchTask.socketPath` | u32 **BE** length + JSON `Command`, reply u32 BE length + JSON <= 1 MiB | dispatch_custody.rs:192-218 |
| MCP stdio edge -> controller broker | `/run/mini-grain.sock` (sandbox) = `state/mcp-N.sock` | newline-terminated JSON `{"name","arguments"}` <= 64 KiB, reply one line <= 16 MiB | mcp.rs:141-218, 408-437 |
| Hermes -> MCP stdio edge | stdin/stdout | newline-delimited JSON-RPC 2.0, <= 64 KiB per frame | mcp.rs:458-564 |
| git -> gitweb loopback proxy | `127.0.0.1:ephemeral` (sandbox) | HTTP/1.1 smart HTTP, Content-Length only, token header | gitweb_worker.rs:127-288 |
| legacy room runner -> provider | `provider.url` loopback | HTTP/1.1 POST, read to EOF | hermes_room.rs:190-223 |
| continuity descriptor | controller -> `mini continuity` / `mini provider-continuity` | JSON `mini-provider-continuity-v1` `{providerResourceId, reserve:{call:{path,sha256}, outcome:{path,sha256}, receipt:{type:"verified-mini-native-prefix-v1", transactionId, eventId, acceptedCount, worldRoot}}, fence}` | provider_history.rs:29-48, 359-432 |
| resolution report | `mini provider-continuity` -> controller | `mini-provider-continuity-resolution-v1` with `decision`, `inputs`, `lookup`, `expiration`, `originalPrefix`, `freshPrefix`, `freshProof`, ... | provider_resolution.rs:177-327 |
| grain intent | controller -> `mini submit --intent-kind grain-intent` | JSON `{grain, grants, intentNonce}` | grain_source.rs:66-88; Host/Json.lean:2768-2774 |
| query source | controller -> `mini query` | `{subject, nonce, purpose:{type:"query",kind:"object",target,view}, grants:[...]}` | query_observation.rs:154-157; provider_owner.rs:143-145 |
| provision intent/complete | file | `mini-provider-provision-intent-v1`, `mini-provider-provision-complete-v1` | provider_provision.rs:130-131, 185 |
| migration | file | section 1.5 | config_migration.rs |

### 1.12 Processes, sockets, files, directories, environment

* Processes spawned by this shard: Appendix B (28 sites).
* Sockets: `state/provider-gateway.sock` (0600, per prompt, provider.rs:432-445); TCP loopback `gatewayBind` in fixture mode (provider.rs:447-450); `state/mcp-N.sock` (0600, per prompt, mcp.rs:86-88); `dispatchTask.socketPath` (0600 + ACL, dispatch_custody.rs:270-285); in sandbox `127.0.0.1:P` (bridge) and `127.0.0.1:ephemeral` (gitweb); client connections to the mini-keys broker socket and the scheduler socket.
* Files written in `state_dir`: Appendix C.
* Files read: `/etc/mini/providers.json` (root), the broker client config (`credentialBroker`, `mini_keys::client::Broker::load`, provider_provision.rs:106, provider_owner.rs:106), the provisioning policy (root, provider_provision.rs:21-34), worker `config.yaml`, `/dev/urandom` (provider_profile.rs:56; gitweb_worker.rs:121), `/proc/PID/cmdline` (hermes_room.rs:250; legacy_custody_audit.rs:232-265), migration admission artifacts (root, config_migration.rs:315, 350).
* Environment read: none directly in this shard. Environment set: gitweb git children get a cleared environment with `PATH`, `LANG`, `GIT_CONFIG_*` (gitweb_worker.rs:290-324). The launcher env (`MINI_GRAIN_PROVIDER_SOCKET`, `MINI_GRAIN_PROVIDER_PORT`, `MINI_GRAIN_CREDENTIAL_BROKER`, `MINI_GRAIN_BROKER_SOCKET`) is set by main.rs:3465-3492.

---

## 2. What it assumes of its surroundings

### 2.1 Host protocol operations

This shard never opens the Host socket itself; every native read or write is a subprocess of the pinned `mini` client or the `minidregg-host` executable.

| op | symbol (host-operations.json) | how this shard reaches it | Lean receiver | agreement |
|---|---|---|---|---|
| 5 | AUTHORIZED_QUERY (dispatchSession) | `mini query` (query_observation.rs:162-180; provider_owner.rs:147-168) | dispatchSession | Rust reads only the client's `view.json`/`challenge.json`; the refusal frame byte check `frame[0] == 255` (query_observation.rs:119) agrees with the client marker `operation: 5` (query_observation.rs:72-77); decoding is delegated to `HOST CONFIG inspect outcome` (query_observation.rs:185-194), so `stale-root` is the Host's reason name, not Rust's. Agree. |
| 255 | pre-submit / query refusal frame | read from retained files only | - | as above |
| 17 | PROVIDER_CONTINUITY (fnDispatch, status active) | indirectly: main.rs `mini continuity` with the descriptor from provider_history.rs:434-445; resource-client `provider-continuity --guarded-attempt` (provider_resolution.rs:384-399) | Host/Main.lean:6718-6724 -> `runProviderContinuitySession` (Main.lean:5548-5632) | Lean derives the provider id from the signed reserve call (Main.lean:5534-5542, 5589-5590), not from the Rust descriptor's `providerResourceId`; v2/v3 prefixes (Main.lean:5558-5577) match resource-client `V2`/`V3` (provider_continuity.rs:7-8). Reply fields `checkedAcceptedCount`, `checkedWorldRoot`, `priorChecked{acceptedCount, worldRoot}` (Main.lean:5615-5631) are exactly the names provider_resolution.rs:128-145 reads. Agree. |
| 19 | PROVIDER_USAGE_QUOTE (fnDispatch) | main.rs only (A) | Main.lean:6744-6754 -> `ProviderUsage.quotePayload` | not in this shard; the shard's only consumer is `response_headers` metadata (provider.rs:1305-1395) fed to main.rs `provider_metering_metadata`. |
| 144 | KEY_ROTATION_STATUS (fnDispatch) | `mini key --action owner-status` (provider_owner.rs:44-53); also the broker (BYOK.md:28-36) | Main.lean:7027 | Rust requires `subject-key-status-v1`, `isCurrent`, `currentRevoked:false`, `keyEpoch` (provider_owner.rs:59-70); I did not open the 144 arm body (Q8.9). |
| grain-intent prepare | (submit path) | `mini submit --intent-kind grain-intent` (pending_prepare.rs:243-263) | `Host/Json.lean:grainIntent` (2767-2774) -> `grainSource` (2645-2765) | exact key set (Json.lean:2648-2652) equals grain_source.rs:73-86; `schemaVersion` must be 1 (Json.lean:2712-2713, Rust `"1"` grain_source.rs:74); `before.route` optional (Json.lean:2653-2664, Rust grain_source.rs:81-83); settle route must equal recorded route (Json.lean:2683-2685); `context` hashed into the nonce (Json.lean:2700-2707, 2753). Agree. |
| profile | `minidregg-host CONFIG profile` (via resource-client and main.rs) | provider_history.rs:6-15; provider_resolution.rs:303-307 | Main.lean:853-880 | `providerContinuityAdmission:"exact-height-v1"` (Main.lean:861) and `genesisHeight` (Main.lean:878) match. |

### 2.2 Other executables and crates

* `mini` (resource-client) verbs used here: `query`, `submit`, `retry --mode lookup`, `key --action owner-status`, `provider-continuity --guarded-attempt`, `credit --action adopt|return`, `workspace --action import`, `hermes-handoff --action check-delivery|check-dismissal`, and shell lines through `RoomTools` (Appendix B). The shard depends on resource-client artifact conventions: `attempt.json` format `minidregg-resource-client-attempt-v1` (pending_prepare.rs:197-205; provider_continuity_rejection.rs:182-191; query_observation.rs:82-93; legacy_custody_audit.rs:355-362), `call.bin` fsynced before send (pending_prepare.rs:261-262), `query-refusal.json`, `provider-continuity-rejection.json`, `resolution.json`.
* `minidregg-host CONFIG inspect outcome` (query_observation.rs:185-194).
* `/usr/bin/git` (gitweb_worker.rs:291), `/usr/bin/setfacl`, `/usr/bin/getfacl` (dispatch_custody.rs:325, 333), `/usr/bin/systemctl --user` (legacy_custody_audit.rs:186), `/usr/bin/timeout` and `deploy/grain-host/resolve-bwrap` (test only, hermes_catalogue_probe.rs:21-23, 42).
* Crates: `minidregg-mini-keys` (client with `default-features = false`; tests take the full broker, Cargo.toml:26-31), `minidregg-inference-scheduler` (homelab.rs:2-6), `minidregg-compatible-upgrade-custody` (config_migration.rs:6), `ring` (AEAD, Ed25519 in credentials/choice), `sha2`, `serde_yaml` (provider_profile.rs:31).

### 2.3 Operating system

* Unix only throughout (`std::os::unix`). Linux-only pieces: `SO_PEERCRED` + ACL in dispatch custody (non-Linux stubs refuse, dispatch_custody.rs:184-190, 364-367), procfs scans (legacy_custody_audit.rs:232; hermes_room.rs:250 silently returns "not alive" off Linux), `systemctl --user` (legacy), `pre_exec`/rlimits in mini-keys (not this crate). bwrap and user namespaces for the sandbox (deploy, not this crate). No seccomp.
* Filesystem semantics relied on: atomic `rename`, directory fsync, `O_NOFOLLOW`, `create_new`, inode identity checks, and `connect()` on a socket in a read-only bind mount.

### 2.4 Network services

* OpenAI-compatible Chat Completions providers, reached only by the mini-keys broker with curl (`--http1.1 --proto =https|=http --max-redirs 0 --noproxy *`, mini-keys server/provider.rs:213-234), never by this crate.
* Homelab inference endpoints via the scheduler placement and the broker `homelab` op.
* GitWeb application through the SPK application API (main.rs), not directly.
* The legacy room runner's loopback provider (hermes_room.rs:190-223).

### 2.5 Files and configs the operator must provide

`/etc/mini/providers.json` root-owned (credentials.rs:337-352); `/etc/mini/keys-client.json` (`mini-keys-client-v1`, BYOK.md:20-27); the controller config's `providerTask` (`providers`, `credentialBroker`, `gatewayBind`, `maxRequestBytes`, `maxResponseBytes`, `timeoutSeconds`, `maxInputTokens`, `maxOutputTokens`, `model`, optional `provider`, `homelab`, `onBehalfOf`, `contextWindowTokens`, `maxIterations`, `localFixtureHostNetwork`, test fixture at provider_continuity_rejection.rs:348); the provisioning policy and template for `provider-provision`; root admission artifacts for transport migrations; `dispatchTask.hostUid` and `socketPath`; an installed Hermes runtime under the runtime root with `grain-provider-bridge` next to it (bwrap:85; deploy/grain-host/install-controller:156).

### 2.6 Other crates that include this crate's source

`credentials.rs` + `provider_choice.rs` are compiled into `minidregg-mini-keys` (server/mod.rs:18-22) and the resource-client binary (keys.rs:35-37). A change to these files changes three binaries.

---

## 3. Does it decide anything semantic?

### 3.1 Violations: Rust is the decision

| # | site | what Rust decides | Lean side today | what the Lean counterpart should be | blast radius if wrong |
|---|---|---|---|---|---|
| BV1 | credentials.rs:358-368 (`select`), main.rs:335-344 (row selection), mini-keys server/provider.rs:123-137 (ticket per row) | **who pays** the provider (route `user`/`pool`/`homelab`), including "the first row listing the model" when the config names no provider | `Kernel/ProviderRoute.lean:30-35` says outright "What the kernel cannot see is which bearer the controller attached ... The controller resolves the route and the bearer together"; Lean only enforces that the settle charges by the route recorded at reserve | a provider-purse law clause or a signed table digest in the reserve so that Lean can refuse a reserve whose route is not the one the operator table assigns to `(model, provider)` for this purse | an operator table edit (row order) silently moves members from their own key to the pool or vice versa at the next prompt; the purse is charged the other route's tariff |
| BV2 | credentials.rs:1135-1190 (`count_call`), 1063-1064, 1125-1127; time from credentials.rs:677-683 | member-key and pool **quotas**: calls per UTC day per runner, max `max_tokens` per call, counted when a ticket is minted (before the send, never refunded) | none; executed in the broker, not admitted | either Lean-held counters in the purse/grant resource, or an explicit "physical rate limit, not a semantic bound" label in BYOK.md | a broken system clock or a deleted `usage.json` resets the day count; refusals after authorization (ticket expired, reserve refused) still consume a member's daily calls |
| BV3 | provider_choice.rs:83-131, 132-142; credentials.rs:374-409 grant semantics | the member's **provider/model choice** and its authenticity (an Ed25519 signature checked in Rust), and grant expiry measured against a height the controller supplies (credentials.rs:1060-1062; mini-keys server/provider.rs:131) | Lean checks the owner key is current (op 144) but never sees the choice or the grant | a signed member intent admitted by Lean (choice as a resource or a delegation) | a stale or replayed choice provisions a controller on a route the member no longer wants until the grant is revoked; bounded by the operator running `provider-provision` |
| BV4 | provider_resolution.rs:121-161 (and twin resource-client provider_continuity.rs:820-823) | "every signed deadline < checked height, therefore this contended settle can never commit", used to clear `provider_pending` (provider_resolution.rs:418-420) | Lean supplies the heights (op 17 reply, profile `genesisHeight`) but the inequality and its consequence are Rust's | a Lean "never-admissible" witness for a retained call (the expired-call clause the resolver approximates), returned by the Host | if the inference is wrong a later admission of the old call would settle a hold the controller believes unsettled; mitigated because the hold itself is not released (`heldAllowanceReleased:false`) |
| BV5 | hermes_room.rs:336-347 (`said_already`) | a `say` whose text is not among the last 100 signed stream entries "was refused" (`absent-after-submitter-stop (signed tail)`) | none | an exact lookup of the say's write record (resource_tools already resolves writes by `exact-operation-record`, resource_tools.rs:1066-1075) | in a busy room (more than 100 entries since) a performed say is recorded as refused and the runner may say it again |
| BV6 | hermes_room.rs:425-434 | any error from `RoomTools::write` (non-zero client exit, transport error, spawn failure) is journaled `resolved: refused, basis: host-refusal` | none | classify only a Host-decoded refusal as refused; everything else `uncertain` and resolve by lookup (as `recover` does) | a lost reply after a successful submit is recorded as a refusal; the model sees an error and can repeat the write: one intent, two effects |
| BV7 | hermes_room.rs:402-416 | "out of budget" decided from the error string prefix of `RoomTools::pay` and broadcast once per attach | the payment itself is Lean-admitted | carry a typed refusal reason | cosmetic; a mis-prefixed error suppresses all later writes in the attach |
| BV8 | provider_owner.rs:116-118; config_migration.rs:498 | a member grant is "sufficient" only if `per_call >= maxOutputTokens` | none (broker also checks per call) | part of BV2 | refuses provisioning/migration that would work for smaller requests; fail-closed |

### 3.2 Mirrors: Rust pre-checks what Lean (or the broker, or the scheduler) gates anyway

| site | Rust check | the real gate |
|---|---|---|
| provider.rs:614-735 | text-only request profile, `n`=1, `max_tokens` pinned, `include_usage` required for streams | Lean quote parses the exact retained request and response (`ProviderUsage.parseRequest`, `quoteResponse` ProviderUsage.lean:264-284) and refuses ambiguous usage |
| provider.rs:953-956 | `model` equals pinned model | Lean quote `checkModel` (ProviderUsage.lean:216) and the tariff's model |
| provider.rs:1305-1395 | final status and Content-Type | Lean quote requires `text/event-stream` or `application/json` and status 200 on metered routes (ProviderUsage.lean:267-278) |
| provider_profile.rs:79-94 | profile bounds | physical (Hermes config) |
| provider_history.rs:6-15 | Host supports exact-height continuity | Host profile is authoritative |
| provider_history.rs:50-106; provider_continuity_rejection.rs:207-292; pending_prepare.rs:26-93 | retained source equals a fresh reconstruction | Lean admits or refuses the retained bytes on lookup/resubmission |
| provider_retirement.rs:5-45 | refusal evidence is a Host refusal | main.rs re-checks freshly signed idle coordinates before aborting (provider_retirement.rs:83-85) |
| provider_provision.rs:64-74 | source tasks never attached | the controller's later attach is Lean-admitted |
| config_migration.rs:549-668 | which config fields may change | the journal binding is local; every later effect is still Lean-admitted |
| homelab.rs:104-139 | scheduler reply pinned to controller/principal/pool/request/lease | scheduler is physical capacity only (inference-scheduler lib.rs:1) |
| mcp.rs:404-406, gitweb_worker.rs:27-80, 166-175, 369-384 | tool names and Git route profile (inside the sandbox) | controller `handle_tool` / `begin_application_api` and Lean dispatch permits |
| hermes_outcome.rs:67-78 | a managed prompt needs a settled 200 response | the provider settle is Lean-admitted |
| query_observation.rs:205-229 | view names the right task | the client verified the signed view |

### 3.3 Correct deferrals worth naming

* No provider bearer ever enters grain-runtime: the gateway forwards a ticket id and the broker attaches the key (provider.rs:70-85, 1475-1481; mini-keys server/provider.rs:258-268). The bearer reaches curl on stdin, never argv (mini-keys server/provider.rs:257).
* The gateway never decides to send: the permit comes from main.rs only after a durable native reserve and a durable send boundary (provider.rs:989-1072).
* No charge is computed: provider.rs has no usage parsing; `NotSent` is the only locally priced outcome (`"0"`, main.rs:9935-9943).
* Lost replies keep the exact attempt: `NotSent` is reported only when the code can show nothing left the process (provider.rs:1451-1518, 1532-1540); everything after the broker received the frame is `Uncertain` and never resent (provider.rs:1519-1531).
* Stale-read retry depends on the Host's decoding of the op-255 frame, never stderr (query_observation.rs:47-48, 122-123).
* The provider id in continuity comes from the signed call on the Lean side (Main.lean:5534-5542).
* Retirements never release a hold (`heldAllowanceReleased:false` in provider_history.rs:132, provider_resolution.rs:366, 417, provider_continuity_rejection.rs:131-137, pending_prepare.rs:235, legacy_custody_audit.rs:602).
* The MCP broker forwards tool requests only during an active prompt epoch (main.rs:8469-8473), and the raw GitWeb route uses the same controller gate as the public API tool (main.rs:15066-15091, 8494-8560).

### 3.4 Physical decisions Rust legitimately owns, but makes brittly

* Classifying a response as "received" vs "uncertain" by header shape and bounds (provider.rs:1555, 1616-1624) turns provider quirks into permanent custody states (B-F1).
* `submitter_alive` decides a PID is "no longer the submitter" by `cmdline.contains("shell") && contains(marker)` (hermes_room.rs:249-257): Linux-only, and any reused PID whose cmdline happens to match keeps waiting up to 600 s.
* `no_owned_custody_process` treats "no owned process has the attempt path in argv" as stop evidence (legacy_custody_audit.rs:222-268); its own comment says it is "not a proof" (legacy_custody_audit.rs:223-224).
* Busy/queue limits (`MAX_BUSY_RESPONDERS`, 8 MCP connections, 4 dispatch connections, 5 bridge connections) are silent drops in three of four places (mcp.rs:104-107, dispatch_custody.rs:295-298, provider_bridge.rs:245-249).

---

## 4. Flaws noticed

Severity is for the near goal (small public demo). Each finding names the line and a failure scenario.

### B-F1 (high): fully received provider responses become `Uncertain`, and metered non-200 responses are unsettleable; both brick the grain (extends A F1)

A F1 shows no code path settles an `uncertain:` attempt (main.rs:1586-1596, 16687-16689, provider_retirement.rs:5-13). From this side, `Uncertain` is produced for responses that were in fact received completely:

* broker headers between 32 KiB and 64 KiB: the broker allows `MAX_HEADERS = 65_536` (mini-keys server/provider.rs:29), the gateway refuses `headers.len() > MAX_HEADER * 2` = 32 KiB (provider.rs:1555-1556) -> `Uncertain` (provider.rs:1569-1576);
* a response with no Content-Type, a duplicate Content-Type, a `Content-Encoding` other than `identity`, a folded header, or more than 8 header blocks (provider.rs:1316-1394) -> `Uncertain` (provider.rs:1616-1624);
* the lease ended (prompt deadline, hard EOF) between the broker's reply and the final check (provider.rs:1595-1600), even though the spool is complete and fsynced (provider.rs:1587-1594);
* `--max-filesize` or `--max-time` exceeded in curl (`complete = written && status.success()`, mini-keys server/provider.rs:304) -> `complete:false` -> `Uncertain` (provider.rs:1601-1606). Because the gateway does not stream, `timeoutSeconds` (<= 600, provider.rs:577) bounds the whole generation; a slow model producing 8,192 output tokens at 10 tokens/s takes 819 s;
* the upstream echoing the bearer (`withheld`, provider.rs:1541-1546; mini-keys server/provider.rs:296-302).

Separately, for metered routes (`pool`, `homelab`) every **non-200** `Received` response is unquotable: `quoteResponse` throws "provider HTTP status is not 200" (Host/ProviderUsage.lean:267-268); main.rs then notes "retained a response without a valid Lean quote; held allowance needs reconciliation" (main.rs:9226-9243), and the operator's `reconcile provider audited` re-quotes through the same Lean function (main.rs:16498-16516), which fails again. Scenario: a friend without a key uses the pool route; OpenRouter answers 429 (rate limit) or 400 (context too long); the provider purse stays reserved, `provider_reserve` refuses every later request with "prior provider request needs exact reconciliation" (main.rs:9371-9376), and `attach`, `hermes`, `run` refuse (A F1). For the `user` route the quote ignores status and charges the per-op fee (ProviderUsage.lean:256-263, 267), so BYOK grains are not affected by this half.

Fix direction (owner's call): a Lean-admitted zero-charge (or per-op-fee) settle for "complete response, not quotable" with the retained bytes as evidence, which `Kernel/ProviderRoute.lean:25-28` already allows ("a metered call nothing or at least its fee"), plus aligning the gateway and broker header bounds.

### B-F2 (high, low frequency): homelab endpoint mismatch after the send boundary reports no outcome

provider.rs:1052-1072 obtains the durable `send_started` acknowledgement; provider.rs:1073-1076 then compares the placement endpoint with the route endpoint and, on mismatch, writes 503 and returns **without `report_outcome`**. The controller journal holds `send_started=true, outcome=None`, which shard A's F1 Scenario B shows is unsettleable, although nothing was sent. The `Guard` drops with `Outcome::NotSent` (homelab.rs:175-190) because `guard.outcome = Uncertain` is assigned only after the check (provider.rs:1077), so the scheduler releases capacity while the controller is wedged. The check belongs before `BeforeSend` (the reserve already verified the placement, main.rs:9412-9440), or the branch must report `NotSent`.

### B-F3 (medium): other exits leave a confirmed reserve with no outcome

`serve_client` returns 503 without reporting any outcome when a `Fresh` permit fails its own checks (provider.rs:1032-1039), when `last_permit_id` refuses (provider.rs:1044-1051), and when `wait_reply` for `Reserve` fails after the controller already reserved (provider.rs:995-1001). Those states have `!send_started && outcome == None`, which `metered_audit_path` classifies as `ProvenNoSend` (main.rs:1587-1590), so they are operator-recoverable, not bricked; but no automatic path settles them (`retire_refused_provider_request` requires an unconfirmed reserve, provider_retirement.rs:11-12), so every such event needs `reconcile provider audited`. In addition, `report_outcome` gives up after 30 s for non-`Received` outcomes (provider.rs:1204-1211): if the controller loop is blocked longer (A F2: unbounded `mini` subprocesses), an `Uncertain` or `NotSent` outcome is never journaled, leaving `send_started && outcome == None`.

### B-F4 (medium): member prompts and model output retained in plaintext without bound

Per attempt: `provider-N.request` (exact request, the full conversation the SDK sent), `.response`, `.headers` (provider.rs:1456-1462, 1558-1566), plus main.rs's `provider-N.controller-outcome` and `.controller-response-headers` (main.rs:9958-9973), plus `provider-continuity-source-N.json`, `query-N/`, `policy-query-N/`, `owner-observation-NANOS/`, `provider-resolution-N/`, migration archives, `hermes-failed-N.json` (Appendix C). Nothing in the shard deletes or rotates them. With `maxIterations` up to 6 and up to 1 MiB requests and 8 MiB responses, one prompt can write up to 6 x (1 + 2 x 8) MiB = 102 MiB of plaintext. The broker removes its spool copies (mini-keys server/provider.rs:203-207, 284). On a public demo this is a privacy and disk-growth issue (A F4 for the journal).

### B-F5 (medium): the gateway never streams

The worker receives nothing until curl has finished (provider.rs:1519, 1120-1121; mini-keys server/provider.rs:271-283). Hermes's streaming UX is lost, and the total-time cap converts long generations into B-F1 bricks. The design choice is defensible for metering (the quote needs the whole body) but must be stated; README/BYOK do not say it.

### B-F6 (medium): unbounded subprocesses in this shard (A F2, local sites)

`command_output` (no timeout, main.rs:7569-7583) is used at provider_recovery.rs:51, provider_resolution.rs:384-399, legacy_custody_audit.rs:656, pending_prepare.rs:263, query_observation.rs:180, 185-194. Direct `Command::output()` without timeout: provider_owner.rs:44-53 and 147-168, hermes_room.rs:265-270, legacy_custody_audit.rs:186-201, dispatch_custody.rs:325-337 (`setfacl`/`getfacl`, startup only), gitweb_worker.rs:327-329 (inside the sandbox, bounded only by the worker's wall clock). `CustodyGate` has no timeout either (custody_gate.rs:139-222); it is cancellable only by a hard EOF.

### B-F7 (medium): legacy room runner lost-reply and refusal inferences

See BV5 and BV6. Also `complete` reads the provider reply with `read_to_end` into memory without a bound (hermes_room.rs:210-211), detects success by substring (hermes_room.rs:214-216), and `recover` waits up to 600 s per open op on a PID heuristic (hermes_room.rs:307-315). It has no metering and no Authorization header (hermes_room.rs:201-206), so on a real node it cannot use the gateway and would need an unauthenticated provider on loopback.

### B-F8 (medium): sandbox-side gates are described as security properties

`public_tool_name` refuses `__*` names only in the in-sandbox stdio edge (mcp.rs:404-406, 505-506); docs/evidence/2026-09-27-hermes-gitweb-tool/README.md states "Public MCP calls cannot invoke `__*` internal broker operations", but any sandboxed process can write `{"name":"__mini_gitweb_http_raw",...}` to `/run/mini-grain.sock`. The same holds for gitweb's "a read rejects a `git-receive-pack` POST before its Mini call" (gitweb_worker.rs:373-378). I found no privilege gained (the controller applies the same gate, main.rs:8494-8545), so this is a documentation/assurance flaw, not a hole; the controller should be the place that refuses `__*` for anything other than the expected caller, or the claim should be withdrawn.

### B-F9 (medium): GitWeb edit is retry-unsafe at the agent level

An edit that fails after its receive-pack POST was forwarded and settled (for example `write_http` to git fails, gitweb_worker.rs:397, or `ls-remote` verification fails, gitweb_worker.rs:661-664) returns an error to the model (mcp.rs:547-548). Nothing stops the model from calling `mini_gitweb_edit` again, which clones fresh and pushes a new commit: the "never retried automatically" property (mcp.rs:381) holds only within one call. The controller's application API attempt is settled, so no custody blocks the second call.

### B-F10 (low): unauthenticated connections occupy the single request slot

`active_request` is set at accept, before the token is checked (provider.rs:475, 497-518), and `read_request` may take 10 s (provider.rs:746). In fixture TCP mode any local user can keep the slot busy, so the worker's real request gets "provider controller is busy" (provider.rs:476-495). In Unix mode only sandbox processes can do this to their own grain.

### B-F11 (low): worker-writable profile staging file can block every prompt

`install_worker_profile` creates `.config.yaml.tmp` with `create_new` (provider_profile.rs:128-134) inside the worker's own home (`/workspace/.hermes`, provider_profile.rs:68-69). A stale tmp file from a crash, or one the agent creates, makes every later prompt fail before reserve ("Hermes profile temp: File exists"). Self-denial only; needs an operator to delete the file.

### B-F12 (low, parsimony): legacy_custody_audit.rs is a single-incident receiver

Every path refuses unless the journal is exactly the reviewed incident (legacy_custody_audit.rs:275-298, 493-505, 519-521, 623-632, 727-742). On any other controller, `reconcile tool legacy b44|zero` can only fail; its only lasting effect is a predicate main.rs consults (main.rs:16255). 819 lines, 13 hash constants and a procfs scanner serve one historical repair. Delete once that controller is reconciled (no evidence directory records the reconciliation; `grep zero-settlement-confirmed docs` is empty).

### B-F13 (low): `hermes_catalogue_probe.rs` cannot pass

It asserts `deploy/hermes/runtime-inputs/probe-catalogue.py` exists (hermes_catalogue_probe.rs:30-32); the directory does not exist. It is `#[ignore]`d (hermes_catalogue_probe.rs:12), so the suite stays green while the qualification it claims is unrunnable.

### B-F14 (low): config_migration tests were not run by their author

CONFIG-MIGRATION.md:136-138: "These are staged for the owner's shared Rust batch; no additional compiler was started by this lane." I cannot tell from the tree whether a later batch ran them (no evidence directory references `config-migrate`).

### B-F15 (low): `credentials.rs` lives in the wrong crate and drifts in its own docs

The custody store executes only in mini-keys, yet the file lives in grain-runtime and is pulled in three times with `#[allow(dead_code)]` (main.rs:34; resource-client keys.rs:35-37; mini-keys server/mod.rs:18-22). Its doc still says "One source, two consumers" and that "the grain controller ... resolves a route and a credential at provider-reserve time" (credentials.rs:3-6), that every file is owned by "the one service user that runs both the hosted shell and the controller" (credentials.rs:8-10; contradicted by split tenancy, mini-keys lib.rs:3-9), and that `authorize` is "the controller's one question at reserve time" (credentials.rs:989-992). `CredentialStore.key` (credentials.rs:522) is not zeroed on drop, unlike `Secret`. `count_call` opens its lock file without `O_NOFOLLOW` (credentials.rs:1144-1150), unlike `provider_lock_until` (credentials.rs:630-636). The grain-runtime binary carries ChaCha20 sealing and the whole store as dead code.

### B-F16 (low): broker and scheduler failures are logged, not journaled

`homelab::Guard::drop` prints "homelab allocation requires reconciliation" and continues (homelab.rs:182-189); an unfinished placement leaves the shared GPU slot quarantined (provider_homelab_tests.rs:479-482) with no journal entry in the controller.

### B-F17 (low): per-prompt socket and directory litter

`mcp-N.sock` is removed only on clean `Drop` (mcp.rs:53-61); a SIGKILL leaves one socket per prompt in the state dir. `owner-observation-NANOS/`, `query-N/`, `policy-query-N/`, `provider-resolution-N/`, `owner-reobserved-NANOS.json` (config_migration.rs:1071-1074) are never removed. gitweb scratch directories live in the sandbox `/tmp` (gitweb_worker.rs:448-452) and are cleaned on drop.

### B-F18 (low): MCP stdio protocol deviations

An unknown method is answered as `result: {"error": ...}` rather than a JSON-RPC error object (mcp.rs:556); a malformed frame terminates the whole MCP server (mcp.rs:478); `initialize` echoes whatever protocol version the client asked for (mcp.rs:484-485).

### B-F19 (low): replay bound is dead

`provider_replays.len() >= 16` (main.rs:9382-9384, 10386-10388) cannot trigger because `provider_prompt_budget` stops fresh requests at `maxIterations` <= 6 (main.rs:9307-9311; provider_profile.rs:90; config_migration.rs:622) and replays accrue only from fresh requests.

### B-F20 (low): dispatch custody drops excess connections silently and allocates before parsing

More than 4 concurrent connections are closed without a refusal frame (dispatch_custody.rs:295-298). `read_frame` allocates `vec![0u8; len]` up to 22 MiB from the 4-byte length before reading (dispatch_custody.rs:196-203); only the authorized host uid can trigger it (peer check precedes, dispatch_custody.rs:223), so this is a resource note, not an exposure.

### Things checked and found sound

* No `unwrap`/`expect` on untrusted bytes in shard code: the six non-test sites are a 4-byte slice conversion after a length check (provider.rs:1430), `as_object_mut().unwrap()` on a freshly serialized struct (provider_provision.rs:79-80), and serde encodes of owned values (provider_provision.rs:148, provider_owner.rs:146, provider_choice.rs:145).
* Header injection into the worker response is impossible: content types are validated printable ASCII <= 128 (provider.rs:1376-1387) and replays re-checked for CR/LF (provider.rs:1014-1017); gitweb checks the app Content-Type (gitweb_worker.rs:282-284).
* Revoke/send linearization is real: the broker connect + frame send happen inside the lease lock (provider.rs:1486-1505), revoke takes the same lock (provider.rs:304-311) and shuts the registered stream (provider.rs:312-316); test provider.rs:2056-2111.
* The bearer never reaches the worker: a response containing the bearer is withheld (mini-keys server/provider.rs:296-302; test provider.rs:3054-3111); the worker token never reaches upstream (test provider.rs:2500-2501).
* Every file this shard trusts is checked for owner, mode, regular-file type and inode stability before reading (e.g. provider_resolution.rs:37-64, provider_continuity_rejection.rs:61-83, legacy_custody_audit.rs:91-117, config_migration.rs:100-113).
* Config migration applies a receiving vector all-or-nothing in the sense that every member must be old-or-new before the first replacement (config_migration.rs:727-756; test config_migration.rs:1558-1582).

---

## 5. Unwired / undone

### 5.1 Reachability of each file

| file | reached from | journey / unit | recorded evidence |
|---|---|---|---|
| provider.rs | `hermes_session_inner` gateway start (main.rs:14480-14525), `handle_provider` (main.rs:9185) | `journeys/byok-native.py` (TCP fixture mode, A 5.2); `deploy/hermes/mini-hermes.service` | docs/evidence/2026-09-30-hermes-keys, 2026-10-01-hermes-tariff |
| provider_homelab_tests.rs | test only | - | - |
| homelab.rs | `provider_prepare` (main.rs:9313-9351), provider.rs:976-988 | none found in crate drivers | - |
| provider_profile.rs | main.rs:14505-14514, 14530-14539 | byok-native.py, hermes-journey.sh | as above |
| provider_bridge.rs (binary) | `deploy/grain-host/bwrap:134-135`; packaged by deploy/candidate/package.py:64, build.sh:9 | no crate driver runs `--network none` with a provider (A 5.2) | none |
| provider_history.rs | main.rs (continuity before send; fences; startup) | byok-native.py | as above |
| provider_resolution.rs | main.rs (pending recovery; A 5.1 lists 4 refs) | none found | - |
| provider_continuity_rejection.rs | provider_history.rs:116, provider_resolution.rs:221 | none found | - |
| provider_recovery.rs | main.rs:13856-13857, 16056, 16437 | hermes-journey.sh crash recovery (A 5.2) | 2026-09-30-hermes-participant (provider not used there per A) |
| provider_retirement.rs | main.rs:14340, 14884-14891, 16055 | byok-native.py refusal cases (BYOK.md:62-63) | 2026-09-30-hermes-keys |
| credentials.rs | main.rs (table), resource-client `mini key`, mini-keys broker | byok-native.py | 2026-09-30-hermes-keys |
| provider_choice.rs | provider_provision.rs:115; resource-client keys.rs:284; mini-keys | byok-native.py (`key choose`) | 2026-09-30-hermes-keys |
| provider_provision.rs | subcommand main.rs:17988 | byok-native.py | 2026-09-30-hermes-keys |
| provider_owner.rs | provider_provision.rs:183-184, config_migration.rs:515-516 | byok-native.py (owner rotation per BYOK.md:62-63) | - |
| custody_gate.rs | main.rs `work_output`, `supervised_json_command` | acceptance.sh, hermes-journey.sh | 2026-09-30-hermes-participant |
| dispatch_custody.rs | `serve` (main.rs:17510-17515) | agent-two-participant-foreground-journey.sh (needs SPK fixture) | 2026-09-27 evidence (A 5.2) |
| dispatch_runtime_tests.rs | test only, Linux only | - | - |
| legacy_custody_audit.rs | admin `reconcile tool legacy b44|zero` (main.rs:17800-17801), predicate main.rs:16255 | none | none |
| config_migration.rs | open/save (main.rs:6846-6917), serve loop (17595), `config-migrate` (17938-17941), `controller-write-scopes` (17933), resident modules | **none** (grep over crate drivers, resource-client journeys, deploy, scripts) | none |
| mcp.rs | `start_broker` (main.rs:14598-14604), `mcp-stdio` subcommand (main.rs:18136-18137) | acceptance.sh, hermes-journey.sh | 2026-09-30-hermes-participant |
| gitweb_worker.rs | mcp.rs:541-545 | README.md [deleted 68b2214d] (prose) | 2026-09-27-hermes-gitweb-tool (source gate) |
| hermes_catalogue_probe.rs | `#[ignore]` test | - | - |
| hermes_outcome.rs | main.rs:14878-14909, 15016-15019 | hermes-journey.sh | 2026-09-30-hermes-participant |
| hermes_session_verify.rs | `Invocation` throughout main.rs; admin main.rs:17772 | none found for `verify-session` | - |
| hermes_room.rs | `hermes-room` subcommand (main.rs:18016); `prepare_resident` from room_resident.rs:309 | `native/resource-client/journey.d/j14.sh:10, 197, 386, 419` (legacy runner) | 2026-10-01-p-hermes-room (name match, not opened) |
| grain_source.rs | every native transition (main.rs:8222-8225) | all drivers | all |
| pending_prepare.rs | main.rs:17038 | policy-crash/receipt-recovery acceptances may hit it (not verified) | - |
| query_observation.rs | main.rs:7748, 7751 | all drivers | all |

### 5.2 Built but unreachable from any journey or unit

* `config-migrate active|stopped`, `controller-write-scopes preflight|receipt` (config_migration.rs:1236-1429): no driver, no evidence.
* `reconcile tool legacy b44|zero`: no driver; single incident.
* `verify-session` admin command (hermes_session_verify.rs:35-110): no driver found.
* homelab placement (homelab.rs, provider.rs:976-1094 homelab branches): exercised only by provider_homelab_tests.rs.
* The private Unix gateway + `grain-provider-bridge` path: installed by deploy scripts (deploy/grain-host/install-controller:147-156) but run by no driver (A 5.2).
* `provider_resolution` expired-contention retirement and `provider_continuity_rejection`: unit-tested only.
* `GatewayConfig.max_output_tokens == None` branch (provider.rs:957): test-only.
* Replay bound 16 (B-F19).

### 5.3 Markers in the code's own words

No `TODO`, `FIXME`, `todo!`, `unimplemented!` in any shard file (scratch count). `#[allow(dead_code)]` none inside shard files; the shared `credentials.rs` is included with it in all three crates. `#[ignore]` at hermes_catalogue_probe.rs:12. Comments that record undone work: "Older journals did not index the fence" (provider_history.rs:247-249), "legacy room runner requires a provider" (hermes_room.rs:470), "Keep the fixed-family tool only for deployments that have not crossed that migration boundary yet" (mcp.rs:343-346), "None retains the legacy provider-wide grant" (credentials.rs:383), "Legacy callers cannot use a scoped grant" (credentials.rs:1005-1006), "Legacy/v2 request bytes remain compatible" (Main.lean:5555-5556, consumer side).

### 5.4 Twins (two or more implementations of one thing)

| # | thing | sites | reachable | keep / delete |
|---|---|---|---|---|
| T1 | bounded owned-file readers with differing ownership/mode rules | provider_resolution.rs:37-64 (euid, no g/o bits), provider_continuity_rejection.rs:61-83 (root or euid, any mode), legacy_custody_audit.rs:91-117 (euid, exactly 0600, nonempty), config_migration.rs:100-113 (euid, no g/o bits, nlink 1), provider.rs:1292-1303 (no owner check), credentials.rs:550-560 + 643-655, main.rs `bounded_regular_file`, `retained_exact` | all | one `custody_read(path, OwnerRule, ModeRule, bound)` |
| T2 | hex encode/decode | credentials.rs:657-675, gitweb_worker.rs:82-109, dispatch_custody.rs:369-386, provider_profile.rs:59-64, provider.rs:1397-1399 (delegates to `mini_keys::wire::hex`), mini-keys wire.rs:131-150 | all | `mini_keys::wire::{hex, unhex}` (already a dependency) |
| T3 | SHA-256 hex helpers | provider_provision.rs:5-11, config_migration.rs:89-94, grain_source.rs:4-12 (direct), main.rs `sha256_bytes`/`sha256_file` | all | main.rs helper (or `controller_digest`) |
| T4 | "re-derive the retained grain source and compare" validators | provider_history.rs:50-106 (fence), provider_continuity_rejection.rs:207-292 (settle/disconnect), pending_prepare.rs:26-93 (parent settle) | all | one `verify_retained_source(authority, pending, payload, operation)` over `grain_source::source` |
| T5 | hand-written HTTP/1.1 parsers | provider.rs:742-847 (request), provider.rs:1305-1395 (response headers), provider_bridge.rs:33-166, gitweb_worker.rs:127-250, hermes_room.rs:190-223 | all | one bounded Content-Length parser with per-use policy; hermes_room's goes with the legacy runner |
| T6 | Hermes drivers | ACP driver main.rs:14314-15261 (A) vs legacy chat-completions runner hermes_room.rs:236-505, 558-600 | ACP: production; legacy: j14 only | delete the legacy runner, keep `prepare_resident` |
| T7 | broker frame reader | provider.rs:1403-1440 vs mini-keys wire.rs:91-125 `read_frame`/`recv` | both | justified (revocation polling); could become `wire::read_frame_until(stream, stop)` |
| T8 | owner-key currency check | provider_owner.rs:27-81 (controller via `mini key owner-status`) vs mini-keys server/provider.rs:83-91 (`observed_epoch`) | both | keep the broker's; the controller's is used only for provisioning/migration evidence |
| T9 | "sender stopped" proofs | legacy_custody_audit.rs:166-268 (unit + procfs), hermes_room.rs:249-257 (procfs cmdline), main.rs `prove_prior_run_stopped`/cgroup_stop (used by pending_prepare.rs:124-126, config_migration.rs:1017) | all | the cgroup proof |
| T10 | expiry arithmetic | provider_resolution.rs:121-161 vs resource-client provider_continuity.rs:820-823 (`expiration`) | both | one, ideally on the Lean side (BV4) |
| T11 | stale socket handling | provider.rs:406-431 vs main.rs `clear_stale_control_socket` (main.rs:17505-17512, 17914) | both | one helper |

### 5.5 Versioned siblings

| family | versions present | file:line |
|---|---|---|
| dispatch RPC | v1 (`reserve`, `mark-send`, `settle-definite`), v2, v3 | dispatch_custody.rs:25-99 (A 5.3 recommends deleting v1) |
| member grants | `mini-provider-grants-v1` and `-v2` | credentials.rs:47-48, 853-874, 878-886 |
| grant authorization entry points | `authorize`, `authorize_model`, `authorize_model_epoch` (legacy, model, epoch) | credentials.rs:993-1071 |
| provider continuity frames | v2, v3 (consumed through resource-client) | provider_continuity.rs:7-8; Main.lean:5555-5577 |
| operation identity | legacy local counter and namespaced SHA-256 id | grain_source.rs:34-55 |
| fence indexing | indexed fence and legacy scan | provider_history.rs:247-357 |
| MCP catalog | `mini-grain-tool-catalog-v2` only | mcp.rs:184, 250 |
| resource birth tool | `mini_create_resource` (fixed family) and `mini_workspace_create` | mcp.rs:334-350 (A 5.3 twin) |
| controller client upgrade admission | `compatibleAdmission` and `miniAdmission` | config_migration.rs:21-24, 627-666 |
| room runner | legacy `hermes-room` runner and resident ACP preparation | hermes_room.rs:507-600 |

### 5.6 Tests that test the fixture rather than Mini

* provider.rs tests and provider_homelab_tests.rs: real gateway, real broker, real scheduler, fake upstream; Mini acknowledgements are the test's own channel replies. They test the edge's ordering claims well, not Lean.
* dispatch_runtime_tests.rs: a shell `mini` that flips a status file on `grep '"type": "reserve"'` (dispatch_runtime_tests.rs:315-378); the v1 test asserts that arbitrary SPK strings are accepted (dispatch_runtime_tests.rs:460-469), i.e. it pins the V5 weakness as expected behaviour.
* query_observation.rs:376-459 and legacy/config tests use shell stand-ins for `mini` and `host`.
* config_migration tests exercise pure functions and the receiving-vector logic with fixture files; none runs a migration end to end against a controller.
* No tautologies found.

---

## 6. Size and shape

### 6.1 Lines per file

See the header table: 17,227 lines, 10,987 code, 6,240 test (36.2%), 136 `#[test]` functions (scratch count: provider 25, homelab 3, profile 4, provision 2, retirement 1, recovery 1, history 6, resolution 4, rejection 6, bridge 1, credentials 15, custody gate 4, dispatch custody 4, dispatch runtime 3, legacy 1, config migration 21, mcp 9, catalogue 1, outcome 3, session verify 2, room 5, gitweb 4, grain source 2, pending prepare 4, query 5).

### 6.2 Shape by concern (code lines only)

| concern | files | code lines |
|---|---|---|
| provider HTTP edge and bridge | provider.rs, provider_bridge.rs, provider_profile.rs | 2,052 |
| provider custody recovery (op 17 story) | provider_history, provider_resolution, provider_continuity_rejection, provider_recovery, provider_retirement | 1,427 |
| provider provisioning and keys | credentials.rs, provider_choice.rs, provider_provision.rs, provider_owner.rs | 1,804 (of which about 700 are `CredentialStore`, executed only in mini-keys) |
| homelab | homelab.rs | 190 |
| custody gate | custody_gate.rs | 283 |
| dispatch custody | dispatch_custody.rs | 387 |
| legacy incident | legacy_custody_audit.rs | 796 |
| config migration | config_migration.rs | 1,430 |
| MCP and GitWeb | mcp.rs, gitweb_worker.rs | 1,236 |
| Hermes support | hermes_outcome, hermes_session_verify, hermes_room | 794 |
| authoring and observation | grain_source, pending_prepare, query_observation | 588 |

### 6.3 A minimal version for the demo-critical path

Demo path assumed (consistent with A 6.3): one Hermes prompt with a BYOK `user` route through the broker, MCP workspace/publish tools, hard/soft attach, restart recovery, one small VM, no homelab, no SPK dispatch, no GitWeb, controllers written by the operator rather than provisioned.

Drop outright (file, total lines):

| file | lines | condition |
|---|---|---|
| config_migration.rs | 2,033 | reprovision instead of migrating; remove the `ensure_process_current` calls (main.rs:6917, 17595; resident modules) |
| legacy_custody_audit.rs | 819 | after confirming the B44 controller is gone |
| dispatch_custody.rs | 476 | if the dispatch subsystem goes (A 6.3) |
| dispatch_runtime_tests.rs | 643 | with it |
| gitweb_worker.rs | 898 | no GitWeb in the demo (mcp.rs:507-549 branch goes too, about 45 lines) |
| homelab.rs | 190 | no homelab |
| provider_homelab_tests.rs | 506 | with it |
| provider_provision.rs | 228 | operator writes the controller config |
| provider_owner.rs | 197 | used only by provisioning and migration |
| hermes_catalogue_probe.rs | 93 | broken anyway |
| **subtotal** | **6,083** | |

Defer (drop now, re-add when a real incident needs them; the states they resolve then need `reconcile provider audited` or an operator): provider_resolution.rs (543), provider_continuity_rejection.rs (609; its `inspect` call in provider_history.rs:109-138 goes too), the legacy runner part of hermes_room.rs (about 450 of 670; keep `prepare_resident` and the shared `Runner` helpers it needs). **About 1,600 lines.**

Move out of grain-runtime: `CredentialStore`, `Secret`, sealing, grants persistence and their tests (about 700 code + 550 test lines of credentials.rs) into mini-keys; keep in a small shared module (or a `mini-keys` non-crypto feature) only `ProviderTable`, `ProviderRow`, `CredentialSource`, `Owner`, `Grant::from_json`, `REFUSED`, `validate_endpoint` and `Choice` verification (about 450 lines). **About 1,300 lines leave the controller's compile surface.**

Keep: provider.rs (minus homelab branches, about 60 lines), provider_profile.rs, provider_bridge.rs (only if the demo uses `--network none`; with `localFixtureHostNetwork` the worker has host networking and the bridge is unused), provider_history.rs (descriptor needed before every send), provider_recovery.rs, provider_retirement.rs, custody_gate.rs, mcp.rs, hermes_outcome.rs, hermes_session_verify.rs (`Invocation` is used everywhere; `verify_hermes_session` could go), grain_source.rs, pending_prepare.rs, query_observation.rs. Result: this shard would drop from 17,227 to roughly 8,200 lines in grain-runtime.

---

## 7. Deployability on a small public Linux VM

### 7.1 What must exist on the box

* `grain-runtime` and `grain-provider-bridge` in the runtime root (`deploy/candidate/package.py:64`; bwrap:85 requires the bridge to be executable when a provider socket is passed).
* `mini` (resource-client) and `minidregg-host` at pinned paths; the mini-keys broker running as its own account with `/etc/mini/keys/broker.json`, the credential root and seal key (BYOK.md:29-42); `/etc/mini/keys-client.json`; `/etc/mini/providers.json` root-owned (credentials.rs:340-352; unit condition deploy/hermes/mini-hermes.service:21-24).
* Linux user namespaces for bwrap, `/usr/bin/bwrap` or the resolved launcher, the `launch-gate` sibling, a user systemd manager for scoped workers (A F7), `/usr/bin/git` only if GitWeb is used, `/usr/bin/setfacl`/`getfacl` only if a dispatch task is configured (dispatch_custody.rs:325-333).
* An installed Hermes runtime under the runtime root with a `config.yaml` home writable by the worker.
* Disk for unbounded per-attempt plaintext retention (B-F4).

### 7.2 What is operator-configured

`providerTask` fields (section 2.5); table rows, models, caps; whether the worker runs with `--network none` (private Unix gateway + bridge) or `localFixtureHostNetwork` (TCP gateway on host loopback, worker with host networking, bwrap:129-132); `timeoutSeconds` (choose with B-F1/B-F5 in mind); `maxIterations`; the broker's role uids.

### 7.3 What is dangerous to expose

* The worker runs under the controller's uid inside a user namespace (bwrap:116-118). The mini-keys broker authenticates callers only by `SO_PEERCRED` uid (mini-keys lib.rs:11-20): if the broker socket were ever mounted into the sandbox, the agent would hold the controller's `provider` role (authorize tickets, forward to homelab without a ticket, mini-keys server/provider.rs:332-341). Today only bwrap's mount list (bwrap:55-71, 120-128) separates them. Same for the dispatch socket and the control/admin sockets.
* `localFixtureHostNetwork` gives the worker the host network namespace (bwrap:129-132): from inside the sandbox the agent can reach any host loopback service (the TCP gateway, the scheduler if TCP, anything else bound on 127.0.0.1) and the internet. The installers refuse this flag for production (`deploy/grain-host/install-controller:147`, `install-operator-stack:287`); keep it that way.
* Plaintext prompt retention (B-F4) and worker stderr in the journal (A F5).

### 7.4 What a stranger on the internet could exercise

Nothing in this shard listens on a non-loopback address: the gateway refuses non-loopback binds (provider.rs:569-571), the bridge and gitweb listeners are inside the sandbox netns, every other socket is a Unix socket in the state dir. A stranger reaches this code only through whatever front end submits prompts (resource-client, Discord, rooms), i.e. as an enrolled member.

### 7.5 What a malicious enrolled member (or a prompt-injected agent) could exercise

* Any tool the catalog lists, and the raw `__mini_gitweb_http_raw` route, each gated by the controller and Lean (section 3.3); arbitrary HTTP methods/paths to configured SPK apps through `mini_application_api` within route allowlists (mcp.rs:389-399).
* Burn their own grain's budget up to the operator-configured charges and the provider tariff (A V1).
* Brick their own provider grain on a pool route by provoking a non-200 response (B-F1), e.g. an over-long context; on a shared pool this also consumes operator caps.
* Make every later prompt fail by creating `.hermes/.config.yaml.tmp` (B-F11).
* Hold the single gateway request slot from inside the sandbox (B-F10).
* On a homelab route, quarantine a shared GPU slot with an uncertain send (provider_homelab_tests.rs:460-506), affecting other members' queueing.
* Spend their own BYOK key up to their grant's `perDay`; daily counts are consumed even by refused sends (BV2).

---

## 8. Questions for the Lean side

1. **Metered non-200 settlement.** `ProviderUsage.quoteResponse` refuses any metered response with status != 200 (Host/ProviderUsage.lean:267-268). Which declaration admits a provider-purse `settle` for a complete, retained, non-200 metered response, and with what charge (zero, per-op fee)? `Kernel/ProviderRoute.lean:25-28` says a metered call may be charged "nothing or at least its fee"; is a zero settle with the route recorded at reserve admissible after `send_started`, and which theorem states it?
2. **Uncertain sends.** Is there any Lean-admitted transition that releases or charges a provider hold whose request may have reached upstream but whose response is unknown (A F1, B-F1)? If not, is an expiry of a provider reserve (a deadline field in the purse law) planned, and where?
3. **Route assignment.** `Kernel/ProviderRoute.lean:30-35` delegates "which bearer" to the controller. Is there any declaration that ties the route recorded at reserve to the operator's provider table (for example a table digest in the Host settings), so that Lean could refuse a reserve on the wrong payer route (BV1)?
4. **Expired-call retirement.** For a retained signed call whose every slot has `validUntil < checkedHeight` (provider_resolution.rs:121-161), which Lean admission clause guarantees the call can never be admitted later? Point at the declaration that refuses a call past its `validUntil`, and say whether `checkedHeight = genesisHeight + acceptedCount` is the height that clause compares against.
5. **Continuity is not a lease.** `runProviderContinuitySession`'s docstring says the check "does not lease the provider resource across a later external send" (Host/Main.lean:5543-5547). Which declaration prevents a provider purse settle or disconnect by another controller between the continuity check (before send) and the controller's settle (after the response)? Is the purse's controller key exclusive by construction?
6. **Nonce identity.** `grainSource` hashes `(operationId, payload)` into the command nonce (Host/Json.lean:2700-2707, 2753) and `grainIntent` uses `intentNonce` as the intent nonce (Json.lean:2771-2773). Does Lean refuse a second admission of a command with the same nonce for the same subject (replay protection), and is that what makes `pending_prepare`'s re-prepare of the same source safe if the original prepare had somehow been sent?
7. **Per-op fee for a user route.** For `route = user`, `quoteResponse` charges the per-op fee whatever the status (ProviderUsage.lean:256-267). Is a user-route call that the broker refused before sending (ticket expired) settleable at zero, which `Kernel/ProviderRoute.lean:22-23` calls "the release of a call that never left"? Which theorem distinguishes "never left" from "left"?
8. **Profile capability string.** `providerContinuityAdmission: "exact-height-v1"` is a literal in `profileDescription` (Host/Main.lean:861) and in SourceAgreementReader.lean:140. Is there a declaration tying that string to the presence of `NativeProviderHistory.checkPrior` and the v3 frame, or is it a hand-maintained label?
9. **Op 144 semantics.** For `mini key --action owner-status` (op 144, Main.lean:7027), what do `isCurrent` and `currentRevoked` mean exactly (current at the walked head?), and is `keyEpoch` monotone per subject? provider_owner.rs:59-70 relies on all three.
10. **Quota placement.** Should member-key quotas (`perDay`, `perCall`, `notAfter` height) be Lean facts (BV2/BV3), or are they explicitly physical broker policy? If Lean, which resource would hold the counter?

---

## Appendix A. Every way `forward`/`serve_client` classifies a provider attempt

| outcome | cause | provider.rs line | settleable today |
|---|---|---|---|
| NotSent | lease inactive at entry | 1451-1455 | yes, `"0"` automatically (main.rs:9244-9253) |
| NotSent | spool create/sync failed | 1460-1470 | yes |
| NotSent | broker connect failed | 1487-1489 | yes |
| NotSent | stream clone failed / custody lock poisoned | 1490-1499 | yes |
| NotSent | broker did not receive the frame | 1501-1503 | yes |
| NotSent | lease revoked before the send gate | 1513-1517 | yes |
| NotSent | broker refusal (ticket unknown/expired/mismatch, row, spawn) | 1532-1540 | yes |
| NotSent | `BeforeSend` not acknowledged | 1062-1069 | yes |
| Uncertain | lease revoked while waiting for the broker | 1415-1418 via 1523-1530 | no (F1) |
| Uncertain | broker deadline (timeout + 30 s) | 1419-1422 | no |
| Uncertain | broker closed / read failed / frame bound / non-JSON | 1424-1437 | no |
| Uncertain | response echoed the bearer (`withheld`) | 1541-1546 | no |
| Uncertain | broker reply lacks fields, headers > 32 KiB, body > max, spool write failed | 1547-1576 | no |
| Uncertain | body re-read failed | 1578-1586 | no |
| Uncertain | fsync of spool failed | 1587-1594 | no |
| Uncertain | lease revoked after a complete reply | 1595-1600 | no |
| Uncertain | curl incomplete (`complete:false`: timeout, size, reset) | 1601-1606 | no |
| Uncertain | header re-read failed | 1607-1615 | no |
| Uncertain | header block invalid (no/duplicate Content-Type, non-identity encoding, folded, > 8 blocks) | 1616-1624 | no |
| Received | everything else | 1625-1630 | yes if Lean can quote: user route always; metered route only with status 200 and parseable usage (B-F1) |
| (no report) | permit mismatch, permit replay, reserve reply lost | 1010-1022, 1032-1051, 995-1001 | operator audit (ProvenNoSend) |
| (no report) | homelab endpoint mismatch after send boundary | 1073-1076 | **no** (B-F2) |

## Appendix B. Every subprocess call site in this shard (non-test)

| site | program | args (summary) | timeout | gate |
|---|---|---|---|---|
| provider_owner.rs:44-53 | `config.mini` | `key --action owner-status --host --config --socket --subject --public-key` | none | `Command::output` |
| provider_owner.rs:147-168 | `config.mini` | `query --host --config --socket --intent --key PROVIDER_KEY --view resource --dir` | none | `Command::output` |
| provider_recovery.rs:51 | `config.mini` | `retry --attempt A --mode lookup [--socket]` | none | `command_output` |
| provider_resolution.rs:384-399 | `config.mini` | `provider-continuity --host --config --socket --guarded-attempt --dir` | none | `command_output` |
| legacy_custody_audit.rs:186-201 | `/usr/bin/systemctl` | `--user show UNIT -p Id -p ActiveState -p MainPID -p ControlGroup` | none | `output` |
| legacy_custody_audit.rs:656 | `config.mini` | `retry --attempt --mode lookup [--socket]` | none | `command_output` |
| legacy_custody_audit.rs:524, 671, 743, 761 | (via `query_as`) | `mini query` | none | main.rs |
| legacy_custody_audit.rs:751-757, 779-785 | (via `transition_as`) | `mini submit` disconnect / settle 0 | main.rs | main.rs |
| pending_prepare.rs:243-263 | `config.mini` | `submit --host --config --intent --intent-kind grain-intent --key PARENT_KEY --dir [--socket]` | none | `command_output` |
| query_observation.rs:162-180 | `config.mini` | `query --host --config --intent --key --view --dir [--socket]` | none | `command_output` |
| query_observation.rs:185-194 | `config.host` | `CONFIG inspect outcome BIN JSON` | none | `command_output` |
| dispatch_custody.rs:325-329 | `/usr/bin/setfacl` | `-m u:UID:rw PATH` | none | `status` |
| dispatch_custody.rs:333-337 | `/usr/bin/getfacl` | `-cpn PATH` | none | `output` |
| hermes_room.rs:265-270 | `tools.mini` | `credit --action adopt|return`, `workspace --action import`, `hermes-handoff --action check-*`, each with `--socket` | none | `output` |
| hermes_room.rs:368, 400-423, 410, 456 (via RoomTools) | `tools.mini` shell lines | `chat join`, `say`, `doc ...`, `submit`, `lookup` | resource_tools | resource_tools |
| gitweb_worker.rs:467-480, 542-555, 614-622, 640-648 | `/usr/bin/git` (in sandbox) | `clone`, `push --porcelain`, `ls-remote` | 180 s per command (gitweb_worker.rs:17, 362-366) | killed on error |
| gitweb_worker.rs:326-329 (`run_plain`) | `/usr/bin/git` (in sandbox) | `symbolic-ref`, `add`, `commit`, `rev-parse` | none | `output` |
| provider_bridge.rs:223-229 | `/agent/PROGRAM` (worker) | worker argv | lifetime deadline kill (provider_bridge.rs:238-241) | - |
| provider_provision.rs:161-184 (via Runtime) | `mini profile`, `mini query`, owner/grant above | | none | main.rs |
| config_migration.rs:1110, 1117-1129 (via Runtime) | owner/grant, quiescence queries | | none | main.rs |

## Appendix C. On-disk artifacts written by this shard (all under `state_dir` unless noted)

| artifact | written by | contents | retention |
|---|---|---|---|
| `provider-gateway.sock` | provider.rs:432-445 | socket | removed on clean drop (provider.rs:550-556) |
| `provider-{id:016}.request` | provider.rs:1460 | exact request body (plaintext conversation) | forever |
| `provider-{id:016}.response` / `.headers` | provider.rs:1461-1462, 1558-1566 | exact provider body and header spool | forever |
| `provider-continuity-source-{id:016}.json` | provider_history.rs:434-445 | descriptor | forever |
| `provider-resolution-{id:016}/` | resource-client via provider_resolution.rs:361-399 | proof directory | forever |
| `owner-observation-{nanos}/` | provider_owner.rs:136-146 | intent and query attempt | forever |
| `provider-provision-intent.json`, `provider-provision-complete.json` | provider_provision.rs:132-133, 148, 186 | intent; source views, tariff pin, owner and grant evidence | forever |
| `mcp-{id:016}.sock` | mcp.rs:86 | socket | removed on clean drop (mcp.rs:53-61) |
| `query-{id:016}/`, `policy-query-{id:016}/` | query_observation.rs:150-160 | source, attempt, view, challenge, refusal evidence | forever |
| `attempt-N/reprepare[/reprepare...]` | pending_prepare.rs:229-263 | new submit attempt | forever |
| `config-migration.json`, `config-migrations/migration-N/*` | config_migration.rs:134-175, 1143-1212 | pointer; before/after blobs, quiescence, resident, owner rotation, transaction | forever |
| `config-migrations/migration-N/owner-reobserved-{nanos}.json` | config_migration.rs:1071-1074 | fresh owner observation | forever |
| `hermes-failed-{prompt:016}.json`, `.closed.json` | hermes_outcome.rs:37-52 | failure record with journal hash and replays | forever |
| `STATE/journal.jsonl`, `STATE/adoption.jsonl`, `STATE/discovery.json` (room runner state dir) | hermes_room.rs:172-185, 513, 541-543 | event log; discovery cursor | forever (append-only) |
| worker `HOME/config.yaml` | provider_profile.rs:128-141 | Hermes profile with the prompt token | replaced per prompt |
| dispatch socket | dispatch_custody.rs:270-285 | socket + ACL | removed on drop (dispatch_custody.rs:152-161) |
| broker credential root (mini-keys account) | credentials.rs:782-1190 (executed by mini-keys) | sealed keys, grants, usage, choices, lock files | until revoked |

## Appendix D. Function inventory (non-test) of the larger files

**provider.rs**: `GatewayStream` impls 174-230; `GatewayListener` 232-255; `GatewayControl::{activate 263, revoke 304, is_idle 327, current 331, still_active 350, with_send_gate 371}`; `GatewayEndpoint::{start 401, local_addr 535, control 538}`, `Drop` 543; `constant_time_eq` 560; `validate_config` 568; `bounded_chat_request` 614; `read_request` 742; `write_http` 849; `error_reply` 872; `native_reserve_refusal` 880; `refusal_reply` 908; `serve_client` 926; `bridge_delivery_ack` 1137; `wait_reply` 1167; `report_outcome` 1191; `report_delivery` 1240; `write_private` 1269; `create_private` 1281; `read_bounded` 1292; `response_headers` 1308; `hex` 1397; `broker_reply` 1403; `forward` 1442.

**credentials.rs**: `euid` 65; `refused` 69; `Secret::{new 79, expose 92}`, `Debug` 97, `Drop` 103; `CredentialSource::route` 131; `decimal` 163; `provider_name` 174; `object_keys` 188; `string` 198; `validate_endpoint` 207; `is_loopback_http` 230; `ProviderTable::{parse 242, load 340, select 358}`; `Grant::{validate 390, to_json 410, from_json 421}`; `Owner::new` 475; `namespace_path` 500; `private_dir_check` 526; `root_directory_chain` 537; `private_file_check` 550; `ensure_private_dir` 562; `replace_private` 578; `lock_until` 603; `provider_lock` 624; `provider_lock_until` 628; `read_record` 643; `hex` 657; `unhex` 667; `utc_day` 678; `CredentialStore::{member_service_lock_until 687, open 707, directory 733, aad 768, aead_key 776, set 785, secret 813, grants 847, write_grants 878, grant 895, revoke 918, list 968, authorize 993, authorize_model 1007, authorize_model_epoch 1024, verify_grant 1075, pool 1108, count_call 1135}`; `secret_from_input` 1195.

**config_migration.rs**: `digest` 89; `value_digest` 92; `hex` 95; `private` 100; `directory` 114; `sync_parent` 129; `pointer_path` 134; `read_pointer` 137; `publish_bytes` 156; `publish_pointer` 172; `differences` 177; `source_profile_pin` 195; `admitted_client` 226; `mini_coordinates` 263; `admitted_mini` 306; `admitted_transport` 341; `owner_pair` 426; `owner_rotation_shape` 447; `OwnerRotation::validate` 458; `observe_owner_rotation` 506; `retained_owner_rotation` 529; `permitted_diff` 549; `workspace_after` 670; `blob` 691; `retained_blob` 698; `retain_change` 711; `apply_changes` 727; `decode_config` 758; `read_request` 761; `decode_request` 764; `target` 781; `checked_request` 789; `check_stopped_open` 833; `validate_transaction` 843; `ensure_process_current` 965; `ensure_resident_current` 978; `recover_startup` 1000; `recover_receiving_with` 1053; `activate_startup` 1084; `Runtime::migrate_config` 1097; `client` 1236; `matching_publication` 1258; `completed_receipt` 1267; `scope_config` 1290; `scope_lock` 1299; `scope_preflight` 1327; `scope_receipt` 1377.

**legacy_custody_audit.rs**: `bounded_owned` 91; `pinned` 119; `absent_after_prepare` 135; `stopped_unit` 166; `no_owned_custody_process` 225; `inspect` 273; `audit_record` 455; `zero_phase_active` 468; `audit_b44` 476; `exact_zero_lookup` 608; `settle_b44_zero` 692.

**mcp.rs**: `BrokerEndpoint::{activate_prompt 36, deactivate_prompt 40, replace_catalog 44}`, `Drop` 53; `start_broker` 77; `serve_broker_connection` 134; `call_controller` 220; `catalog_names` 224; `catalog_from_reply` 249; `tools_for_catalog` 283; `public_tool_name` 404; `call_controller_with_timeout` 408; `DeadlineRead::read` 444; `serve_stdio` 458.

**gitweb_worker.rs**: `input` 27; `unhex` 82; `hex` 101; `proxy_token` 119; `read_http` 127; `write_http` 252; `git_command` 290; `git_http_command` 314; `run_plain` 326; `serve_git` 346; `Scratch::drop` 422; `read` 428; `edit` 518.

**hermes_room.rs**: `default_rounds` 72; `now` 76; `Journal::{open 104, apply 117, append 172}`; `complete` 191; `functions` 226; `read_json` 242; `submitter_alive` 249; `Runner::{room 260, mini 264, ws 284, recover 289, said_already 336, me 349, adopt 355, write 393, dismissed 437, attach 452}`; `prepare_resident` 510; `step` 560; `main` 576.

**provider_history.rs**: `require_native_support` 6; `prefix` 29; `input` 33; `validate_fence_source` 50; `Runtime::{retire_continuity_rejection 109, provider_fence_record 140, record_provider_fence 229, recover_provider_fence 250, provider_continuity_value 359, provider_continuity_descriptor 434}`.

**provider_resolution.rs**: `string` 31; `read` 37; `json` 65; `copied_input` 68; `artifact` 91; `number` 110; `expiration` 121; `inspect` 163; `Runtime::resolve_guarded_provider_pending` 330.

**provider_continuity_rejection.rs**: `private_owned` 49; `read` 61; `absent_late` 84; `bound` 98; `verify_bindings` 114; `verify_source` 207; `inspect` 298.

**dispatch_custody.rs**: `Command::reply_timeout` 102; `BoundSocket::drop` 141; `Server::drop` 153; `peer_uid` 164/185; `read_frame` 192; `write_frame` 207; `serve_connection` 220; `start` 266; `install_host_acl` 323/365; `decode_hex` 369.

**custody_gate.rs**: `CustodyGate::{new 53, cancel 61, is_idle 79, run_capture 83, run_capture_with_hooks 91, reap_after_abort 225}`; `set_nonblocking` 251; `drain_nonblocking` 263.
