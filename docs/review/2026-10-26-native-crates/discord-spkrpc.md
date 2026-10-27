# native/discord-entrance and native/spk-rpc: reader report (2026-10-26)

Scope: every file in `native/discord-entrance` (src, bin, tests, examples, Cargo.toml) and `native/spk-rpc` (src, build.rs, README, all 28 `.capnp` files, SHA256SUMS, fixtures), plus the deploy files and sibling-crate call sites needed to answer the brief. Both crates are workspace members (`Cargo.toml:3`). Nothing was built or run. Each section has two parts: **(a)** discord-entrance, **(b)** spk-rpc.

## EXECUTIVE SUMMARY

**discord-entrance** (2,316 Rust lines + 137 Python) is two binaries. `mini-discord` is a Discord *interactions endpoint* over plain HTTP behind Caddy. It verifies Discord's Ed25519 signature, maps the Discord user id to a Mini session NAME through a root-owned roster file, and runs the one `line` option through the ssh forced command (`deploy/shell/mini-shell-ssh` → `mini shell --line`). `mini-discord-mirror` bridges one chat room and one channel. It posts room → channel through the `mini-keys` broker and runs channel → room as `say --via discord` under the bridge's own key. **The Discord-to-Mini identity binding is a hand-edited JSON file that Rust enforces** (`roster.rs`, `server.rs:200-214`); Lean never sees a Discord id. The entrance holds **no bot token**. The mirror's webhook URL and bot token are kept by the `mini-keys` broker. Duplicate interactions are deduplicated by a durable custody record per interaction id, with the phases accepted/started/completed: a started line is never re-run. In Rust, the crate decides who may enter (the roster), the retry and dedup policy, admission throttling and timeouts, and for the mirror, disclosure and which Discord authors may speak in a room. None of this vocabulary appears in `protocol/host-operations.json` or in Lean. The worst concrete flaw: any non-2xx reply from the webhook, including a definite 429 rate limit, wedges the mirror as UNKNOWN until an operator runs `--resolve-up`. That command needs a Discord message id that does not exist for a post that was never sent. `mini-discord-mirror` is also not in the candidate package, and `native/discord-entrance/tests/native-world.py` plus the mirror section of `deploy/discord/README.md` describe an environment the binary now refuses.

**spk-rpc** (1,803 Rust lines; 6,126 schema lines) is a library only. It is the supervisor side of Sandstorm's two-party Cap'n Proto connection on fd3: getViewInfo, newSession (Web/Api), typed WebSession GET/HEAD/POST/PUT/PATCH/DELETE, openWebSocket, and a decoder for the signed `BridgeConfig`. **All 27 pinned schemas are unmodified Sandstorm originals** (digests verified OK). `capnp/persistent.capnp` is a modified Cap'n Proto file and is not pinned. Only 10 schemas plus persistent are compiled; **17 vendored schemas (2,256 lines) are compiled by nothing**. The only consumer is `spk-host`; grain-runtime does not depend on it. The Cap'n Proto wire and the JSON host wire do **not** describe the same operations: host-operations.json carries Lean admission (`APPLICATION_DISPATCH_*`), and spk-rpc carries physical delivery to the app. The real twins are permission-schema validation (copied from `Kernel/ApplicationPermissionSchema.lean:110-128`, with diverging bounds) and `permission_schema_source`, which has no production caller and is twinned by `spk-host/src/materialize.rs:322`. The README still says WebSocket is unconnected.

---

## 1. What it is and does

### 1(a) discord-entrance

Per-file line counts are in §6. The crate exposes one library and two binaries (`Cargo.toml:9-23`): `mini-discord` (`src/main.rs`), `mini-discord-mirror` (`src/bin/mini-discord-mirror.rs`), and an example `fake-discord`.

**Endpoint flow (`mini-discord`).**
- `main.rs:26-55` takes no arguments (exit 64 if any are given), builds `Config::from_env`, binds a `TcpListener` on `MINI_DISCORD_LISTEN` (default `127.0.0.1:8793`, `server.rs:67`), and calls `App::serve`.
- `server.rs:355-377` spawns one OS thread per accepted connection, capped at `MAX_CONNECTIONS = 64` (`server.rs:26`). Connections over the cap are dropped silently.
- `http.rs:47-116` reads one request per connection: a head of at most 16 KiB, a body of at most 64 KiB, `Content-Length` only (any `transfer-encoding` gets 411), and a 10 s read timeout per `read()`.
- `App::handle` (`server.rs:150-272`):
  1. `/healthz` GET returns 200; any other path returns 404; any method other than POST returns 405.
  2. Signature check: `signature.rs:44-73` verifies Ed25519 `verify_strict` over `X-Signature-Timestamp || body`, then refuses a timestamp more than 300 s from now (`MAX_SKEW_S`, `signature.rs:10`).
  3. `interaction::parse` (`interaction.rs:49-84`): type 1 gets PONG; type 2 is read as a Command with `id, application_id, token`, the user id from `member.user.id` or `user.id`, `data.name`, the `line`, `target` and `page` options; any other type gets 400.
  4. Shape checks: `application_id` must equal the configured value, and the id, token and user id must be well-shaped (`server.rs:177-182`).
  5. Command dispatch (`server.rs:186-198`): `/mini` takes `line`; `/mini-help` becomes `help`; `/mini-world` becomes `home --json` or `home TARGET --json` (`navigation.rs:7-13`); `/mini-status` has an empty line and is a custody lookup.
  6. `Roster::load` runs on every request (`roster.rs:35-48`). An unrostered user gets an immediate ephemeral `error:` (`server.rs:207-214`).
  7. `Sessions::open` (`session.rs:220-231`) requires `SESSIONS/NAME` to exist already. The workspace is `MINI_SPONSOR_WORKSPACE` for the sponsor and `HOME/workspace` for everyone else.
  8. `/mini-status target:ID` reads `custody/APP-ID.json` and shows it only if `binding.user` and `binding.session` match the caller (`server.rs:226-238`).
  9. `check_line` (`session.rs:236-248`) allows at most 1,000 chars, no blank line and no control characters.
  10. Inflight limit: at most `MINI_DISCORD_MAX_INFLIGHT` (default 4) lines run at once (`server.rs:246-252`).
  11. Custody: `Record::lock(custody, "APP-ID")` from `mini_sdk::store` (`server.rs:254-258`). The binding is `{application,user,session,workspace,home,line,worldPage}`. A different binding returns 409; an existing non-accepted phase returns the retained content; a new interaction saves `phase:"accepted"` (`server.rs:259-269`).
  12. The endpoint replies with DEFERRED (type 5, ephemeral).
- `connection` (`server.rs:332-353`) writes the deferral, closes the socket, and runs the job only if the write succeeded.
- `run_job` (`server.rs:290-330`):
  1. Takes a per-session mutex, then re-checks the roster (a revoked user stops queued work).
  2. Saves `phase:"started"` and calls `Deployment::run`.
  3. Writes `discord.log`.
  4. Saves `phase:"completed"`, which stores content, ending, full stdout and stderr, exit status, and `delivery:"pending"`.
  5. PATCHes `{api_base}/webhooks/{app}/{token}/messages/@original` through curl and marks `delivery:"confirmed"` on 2xx.
- `Deployment::run` (`session.rs:77-151`) has two modes.
  - **Single tenancy:** exec `MINI_SHELL_WRAPPER MINI HOST CONFIG SOCKET WORKSPACE HOME` with `SSH_ORIGINAL_COMMAND=line`.
  - **Split tenancy:** `/usr/bin/sudo -n -- MINI_SESSION_RUNNER NAME` with the line on stdin.
  - Both modes clear the environment, set `PATH=/usr/bin:/bin` and `LANG=C.UTF-8`, run in their own process group, capture at most 1 MiB per stream, and kill the group after `MINI_LINE_TIMEOUT_S` (default 120). A timeout gives the ending `undecided`.
- `reply.rs:36-52` classifies the result: exit 0 is `ok`; otherwise the result is the first stderr line starting with `error:|usage:|refused:|undecided:`, verbatim. `code_block_limit` (`reply.rs:72-88`) fences and truncates output to Discord's 2,000-character limit.
- `curl.rs:34-55`, `124-155`: outbound POST or PATCH through `/usr/bin/curl --config -`. The URL, which contains the token, goes on stdin. The body goes in a 0600 spool file in `MINI_DISCORD_SPOOL` (default `/run/mini-discord`), created with `create_new`.

**Environment (endpoint).** The `main.rs:6-20` table, plus the undocumented `MINI_DISCORD_CURL` (`server.rs:77`). Split shape: `MINI_SESSION_RUNNER` and `MINI_DISCORD_STATE` must appear together (`server.rs:86-93`).

**Files written by the endpoint.**
- Custody: `SESSIONS/.discord-custody/APP-ID.json` (single tenancy) or `STATE/custody/` (split).
- Log: `HOME/discord.log` or `STATE/log/NAME.discord.log` (`server.rs:275-287`), opened 0600 append (`session.rs:251-256`).
- Spool files under `/run/mini-discord`.

**Mirror (`mini-discord-mirror`).**
- `main` (`mini-discord-mirror.rs:354-436`):
  - Requires `MINI_MIRROR_PUBLISH_ROOM_TO_CHANNEL=yes` and a room name.
  - **Refuses to start** if `MINI_MIRROR_WEBHOOK_URL`, `MINI_MIRROR_CHANNEL_URL` or `MINI_MIRROR_BOT_TOKEN` is set (`:371-375`).
  - Loads the broker client config (`MINI_MIRROR_BROKER`, default `mini_keys::client::CLIENT_CONFIG`) and uses `hello` to get `discordChannel`.
  - Takes a bridge lease `HOME/mirror/ROOM-bridge`, bound to `{room,channel,subject,workspace}` (`:402-405`).
  - Loops every `MINI_MIRROR_INTERVAL_S` seconds (minimum 5, default 30), or runs once with `--once`. `--resolve-up CELL SEQ MSGID` records operator evidence for an UNKNOWN publication (`:406-414`).
- `up` (`:248-290`), room → channel:
  - Writes a discovery request file and runs `tail --in ROOM --json -n 20 --discover FILE` through the same forced command.
  - `PublicFeed::from_docs` (`:108-136`) refuses any feed whose header or entries do not carry a boolean `private:false`, or that carry `sealed`.
  - For each new `(cell, sequence)`, `outbound` (`:151-178`) formats `**name**: text` and defuses `@` mentions. A `Delivery` custody record `up-CELL-SEQ` is moved Fresh → started → completed around a broker `discord-post` call (`:271-284`).
- `down` (`:295-350`), channel → room:
  - Scan phase: broker `discord-read` pages backwards (limit 50) down to the watermark and saves each page to `ROOM-operations/page-N.json`.
  - Drain phase: oldest first, at most 20 per poll. Each human message is written to `requests/discord-ID.txt` (`create_new`) and posted with `say --in ROOM --via discord --via-id A --via-name N --operation-record … --file …` (`:338`).

**Test and dev surfaces.**
- `native/discord-entrance/tests/endpoint.rs`: in-process endpoint with a fake forced command, a fake runner and a fake PATCH sink.
- `examples/fake-discord.rs`: signer plus fake REST API.
- `native/discord-entrance/tests/native-world.py`: real Host/Store scenario.

### 1(b) spk-rpc

Library only: no binary and no listener (`README.md:3-10`, `lib.rs:1-5`).

- **`build.rs`.**
  - Compiles `schema/capnp/persistent.capnp` plus `util, identity, powerbox, activity, grain, supervisor, ip, web-session, api-session` with `capnpc` (`build.rs:5-22`).
  - Asserts the SHA-256 of `package.capnp` (`:30-34`), renames `categoryInfo` to `categoryAnnotation` (12 occurrences, `:36-37`), copies all schemas to `OUT_DIR`, and compiles the derived `package-rust.capnp` (`:59-70`).
  - Needs the external `capnp` compiler and its `/capnp/c++.capnp` include, which every schema imports (`grain.capnp:19`, etc.).
- **`protocol.rs`** (production code at lines 1-381):
  - `SessionParameters` (`:11-20`); `ViewInfo`, `PermissionDefinition`, `RoleDefinition`, `LocalizedText` (`:22-61`).
  - `decode_view_info` (`:140-205`) applies bounds (4,096 permissions and roles, 4 KiB text, 32 localizations) and rejects names that are not `[A-Za-z][A-Za-z0-9]*`, duplicate names, and more than one default role.
  - `SupervisorConnection::from_connected_stream` (`:217-232`): the Server side of a two-party `VatNetwork` on a tokio `UnixStream`, 16 MiB traversal limit and nesting depth 64 (`:124-129`). It exports `MinimalSandstormApi`, which has no methods implemented (`:95-96`), and bootstraps the app's `UiView`.
  - `get_view_info` (`:234-237`).
  - `new_web_session` / `new_api_session` (`:239-312`): fill `UserInfo` (display name, handle, 32-byte identityId, raw permission bits, and an `Identity` capability that answers `getProfile` from those same parameters, `:101-119`), a `SessionContext` with no methods implemented (`:98-99`), a tabId, and the session type id with its params.
  - `get_inline` (`:316-380`): the legacy GET path, which refuses streaming.
- **`web.rs`.**
  - Request and response model (`:10-128`).
  - `validate` (`:163-229`): relative path without `#`; CR, LF and NUL banned; 8 MiB body; 128 fields of 8 KiB each; body required for POST, PUT and PATCH and forbidden for GET, HEAD and DELETE; Sandstorm's request header whitelist (`allowed_header`, `:140-162`); q-value at most 1000.
  - `ResponseStream`, a `ByteStream` server with a bounded accumulator that checks `expectSize` and duplicate `done` (`:231-292`).
  - `parse_response` (`:368-508`) maps the full Response union to status codes and refuses response headers outside the whitelist.
  - `dispatch_web` (`:527-621`) wraps every call in `tokio::time::timeout`, giving "deadline exceeded; delivery uncertain".
  - `open_web_socket` / `send_to_app` (`:623-755`): opaque byte relay; a 16-message queue from the app; 1 MiB per message; the app's chosen subprotocol must be one the client offered.
- **`bridge_config.rs`** (`:23-73`): exact, unpacked, at most 64 KiB, no trailing bytes. `apiPath` must start and end with `/`, be at most 4,096 bytes and contain no NUL. A non-empty `powerboxApis` is refused.
- **`permission_schema.rs`** (`:10-73`): projects `ViewInfo` to the JSON `minidregg-application-permission-schema-source-v1`, re-validating 256-entry bounds, names and the single default.

Sockets: only the caller-supplied, already-connected fd3 `UnixStream`. There are no env vars, files or ports.

---

## 2. What it assumes of its surroundings

### 2(a) discord-entrance

**host-operations.json and Host/Json.lean.** No operation code, symbol or JSON key from `protocol/host-operations.json` is emitted or parsed. A grep for `discord` across all `.lean` files returns nothing. The crate talks only to the **`mini shell` CLI grammar** (resource-client, Rust). The verbs and JSON vocabulary it depends on, with where they are defined:

| Used here | Where defined | Lean receiver |
|---|---|---|
| `help`, `home --json`, `home NAME --json` (`server.rs:191`, `navigation.rs:9-10`) | resource-client | none (CLI) |
| `"type":"mini-member-workspace-v1"`, `subject`, `currentness`, `resources[].actions[].command`, … (`navigation.rs:22-39`) | `native/resource-client/src/member.rs` | none found |
| `tail --in R --json -n N --discover F`; header `mini-chat-room-v1`, `discoveryCursors`, `selectedEntries`, `unreadable`, `private`; entries `cell, sequence, author, name, kind, text, via, private, sealed` (`mirror.rs:252-266`) | `native/resource-client/src/chat.rs`, `grain-runtime/src/resident_requests.rs` | none found |
| `mini-resident-discovery-v1` request file (`mirror.rs:251`) | chat.rs, grain-runtime | none found |
| `say --in R --via discord --via-id --via-name --operation-record --file` (`mirror.rs:338`) | `chat.rs:328` (accepts only network `discord`) | none found |
| `workspace.json` → `subject` (`mirror.rs:237-241`) | resource-client workspace | none |
| stderr ending words `error/usage/refused/undecided` (`reply.rs:12`) | mini shell convention | none |

All of this is Rust-to-Rust vocabulary. Admission happens later, when `mini shell` submits to the Host.

**Other assumptions.**
- **Caddy** terminates TLS and forwards only `/interactions` (`deploy/discord/README.md:86-94`).
- **`deploy/shell/mini-shell-ssh`** takes exactly 6 absolute paths and runs `--line "$SSH_ORIGINAL_COMMAND"` (`mini-shell-ssh:12-25`). With an empty variable it would start an interactive shell; the entrance never sends an empty line (`check_line`).
- **The session layout of `render-authorized-keys.sh`** (`session.rs:11-16`). That script is **not in this repo** (dregg-infra), so the NAME → home/workspace rule exists twice, across two repositories.
- **`mini-session-run`**, the root runner for split tenancy, is also not in this repo (only `deploy/discord/discord.env.example` and the README mention it). The README says it re-checks the roster (`README.md:57`).
- **`mini_sdk::store::Record`** for leases and atomic JSON, and **`mini_keys::client::Broker`** with ops `discord-post {body}` and `discord-read {before,limit}`. These match `mini-keys/src/server/discord.rs:125-171`.
- **Discord** must send `member.user.id` or `user.id` and the option names `line`, `target`, `page`. The command catalog `deploy/discord/commands.json` matches (`max_length:1000` on line, 160 on target, page 1..10000).

### 2(b) spk-rpc

**host-operations.json and Host/Json.lean.** spk-rpc emits and parses no host-wire operation. The JSON it produces, `minidregg-application-permission-schema-source-v1` with keys `type, version, permissions[{name,obsolete}], roles[{permissions,obsolete,default}], denied` (`permission_schema.rs:48-64`), **matches exactly** the closed key set that Lean parses (`Host/ApplicationPermissionSchemaAuthoring.lean:79-101`, `exactObject` with those five keys; permission `["name","obsolete"]`, role `["permissions","obsolete","default"]`). Version is a canonical decimal string on both sides (Lean `canonicalNat`, `:43-49`; Rust `version.to_string()`). Lean's check fixtures read `native/spk-rpc/tests/fixtures/permission-schema-source-v1.json` (`Host/ApplicationPermissionSchemaAuthoringCheck.lean:67`, `…RouteCheck.lean:20`).

**Is the same operation on both wires?** No. host-operations.json describes **Lean admission and receipts**: `APPLICATION_DISPATCH_SUBMIT/LOOKUP/PLAN/ASSEMBLE` (codes 34-37), `APPLICATION_ROUTE_BOUND_DISPATCH` (164), `APPLICATION_DISPATCH_READY/AUTHENTICATED_PLAN` (193-194), and session enrollment (82-85). The Cap'n Proto wire is the **physical delivery** of an already-admitted request to the app process (`newSession`, `WebSession.get/post/...`, `openWebSocket`). The only shared content is the request *shape* (method, path, body), which spk-host's `dispatch_web_input.rs` maps from the admitted dispatch into `WebRequest`. That is a projection, not a second definition of an operation.

**Other assumptions.**
- The caller drives the returned `RpcSystem` on a tokio `LocalSet` for the app's whole life (`protocol.rs:207-211`).
- The caller (spk-host `rpc_adapter.rs`) has already decided the identity, permission bits and admission (`lib.rs:3-5`).
- The package's `sandstorm-http-bridge` is the two-party client on fd3.
- `BridgeConfig` comes from a signature-verified SPK tree (`bridge_config.rs:1-4`).
- A `capnp` compiler and its standard includes exist at build time.

---

## 3. Does it decide anything semantic?

### 3(a) discord-entrance: yes, several things, and Lean owns none of them

1. **Identity binding, Discord user → Mini session.** This is `roster.rs:35-77` plus `server.rs:200-214`. The binding is an operator-edited JSON file whose only integrity rule is "owned by the configured uid and not group/other-writable" (`roster.rs:40-45`). The session's Mini key sits on the box in `SESSIONS/NAME`, so **any rostered Discord account acts with that participant's custodial key**. Lean sees only the key's subject and has no record that a Discord account, rather than the key holder, proposed the turn. Lean counterpart: none (no `discord` in any `.lean`; the closest are `PARTICIPANT_KEY_ENROLLMENT_*` and `PARTICIPANT_PROVISIONING_*` in host-operations.json, which bind keys, not external accounts). Note also `endpoint.rs:313`: two Discord ids may map to the same NAME, so several humans can share one key.
2. **Who may enter.** Roster membership plus the existence of a pre-made home (`session.rs:220-231`), and the inflight cap (`server.rs:246-252`), are admission decisions made in Rust before any Lean check.
3. **Workspace/home derivation from NAME** (`session.rs:229`). This decides which workspace, and therefore which key, acts. It duplicates a shell script in another repo (§2a).
4. **Retry and dedup policy.**
   - Same interaction id with the same binding returns the retained output; a different binding returns 409 (`server.rs:261-262`).
   - "accepted but not started" runs again on retry (`server.rs:263`, `383`).
   - "started" is permanently UNKNOWN and never re-run (`server.rs:384`).
   - This is consistent with the README rule ("a lost reply keeps the original operation"), but it is enforced at the **entrance** layer and keyed on a Discord id, not on a Lean operation id. Lean-level idempotency exists only for verbs that themselves keep operation records.
5. **Line policy.** At most 1,000 characters and no control characters (`session.rs:236-248`) decide which lines reach the shell. This is minor and arguably physical.
6. **Timeout policy.** 120 s, then SIGKILL of the process group (`session.rs:123-133`). This can kill a `mini shell` in the middle of a submit, after which the outcome is undecided. The policy is Rust-decided.
7. **What counts as success.** `Ending::of_shell` (`reply.rs:36-52`): exit 0 is `ok`. This is presentational, but it is also what `run_job` uses to choose between the rendered world view and the ending line (`server.rs:307-309`).
8. **Status visibility.** `/mini-status` shows custody only to the same Discord user *and* the same session (`server.rs:233`). Rust decides who may read a stored transcript.
9. **Mirror: disclosure.** Whether a room's content goes to a third-party channel is decided by (i) the operator flag `MINI_MIRROR_PUBLISH_ROOM_TO_CHANNEL=yes` (`mirror.rs:366`) and (ii) Rust's `PublicFeed` check on a `private` stamp that resource-client (also Rust) writes (`mirror.rs:108-136`). The README says so itself: membership does not establish consent to external publication (`deploy/discord/README.md:129`). Lean counterpart: none found.
10. **Mirror: who speaks in a room.** `inbound` (`mirror.rs:182-218`) lets *every* non-bot, non-webhook author in the Discord channel `say` into the Mini room under the **bridge's** key. Lean admits the bridge subject; the Discord author is just a payload field (`via`). In effect, everyone in the Discord channel gets room-say authority, and only Rust decides it.
11. **Mirror: loop prevention and ordering.** Rust drops `via` entries and the bridge's own entries going up, drops webhook and bot messages coming down, and orders by snowflake (`mirror.rs:160-165`, `196-198`, `216`).

### 3(b) spk-rpc: mostly physical, with a few validation twins

1. **Permission-schema validity.** `decode_view_info` (`protocol.rs:156-193`) and `permission_schema.rs:10-40` re-implement `Kernel/ApplicationPermissionSchema.lean:110-128` (`Permission.validName`, `Schema.valid`): the same name rule, no duplicates, at most one default, denied ≤ permissions. The bounds **diverge**: Rust's `decode_view_info` allows 4,096 permissions and roles (`protocol.rs:146-151`), while Lean and `permission_schema.rs:12-15` allow 256. The decoder also does not check role mask ≤ permission count; Lean and `permission_schema.rs:21-28` do. The effect is that an SPK can decode in Rust and then fail at the Lean step. This is harmless as long as Lean stays the gate, but it is a twin that needs maintenance.
2. **Which SPKs are installable.** `bridge_config.rs:56-68` refuses `powerboxApis` and malformed `apiPath`. Downstream, `spk-host/src/materialize.rs:298-315` refuses `saveIdentityCaps` and `expectAppHooks`. These are install-policy decisions made in Rust ("unsupported physical profile"). Lean counterpart: none found.
3. **Header whitelist and response refusal** (`web.rs:140-162`, `384-386`). This mirrors Sandstorm's protocol whitelist, so it is transport legality rather than authority. Treat it as physical.
4. **Identity profile.** `ProfileIdentity::get_profile` (`protocol.rs:101-119`) answers the app's identity callback from the same caller-supplied parameters. It decides nothing, but it gives the app a capability with no authority behind it, and the README says so (`README.md:68-70`).
5. **Permission bits** are passed through raw (`protocol.rs:283-286`). spk-rpc does not compute them; spk-host's `rpc_adapter.rs` is responsible (`rpc_adapter.rs:1-6`, which also has `#![allow(dead_code)] // Staged until Mini exposes a checked current-session projection`).
6. **"Uncertain" on timeout** (`web.rs:618-620`, `741-743`). This is correctly left to the caller and does not retry.

spk-rpc makes no admission, funding, ordering or retry decisions.

---

## 4. Flaws, each with a failure scenario

### 4(a) discord-entrance

1. **The mirror wedges on any non-2xx, including definite non-delivery.**
   - `mirror.rs:278-281` saves "started" and then treats any non-2xx as `UNKNOWN; no automatic repost`.
   - The broker posts with `wait=true` (`mini-keys/src/server/discord.rs:134`) and returns only `{status}`, discarding the message id (`:139`). A 429 or 400 is therefore a definite non-post.
   - Scenario: 6+ room messages arrive within a few seconds. `up` posts up to `BATCH=20` back to back with no pacing (`mirror.rs:59`, `263-288`). Discord rate-limits the webhook with a 429. That entry becomes UNKNOWN and every later poll returns `Err` at `mirror.rs:276`.
   - The operator's only tool is `--resolve-up CELL SEQ DISCORD_MESSAGE_ID` (`:406-414`), which requires a message id that does not exist. The README admits "An actually unsent uncertain post has no automated retry path yet" (`deploy/discord/README.md:137`).
   - Harm: the whole room → channel direction stops permanently for that bridge. The channel → room direction still runs because `down` is independent (`:421`).
2. **A single unreadable Discord message stalls channel → room forever.** `down` refuses the whole page if `todo.len() != expected` (`mirror.rs:314-315`). `inbound` returns `None`, and so drops the message, for a non-snowflake author id or a missing `content` string (`mirror.rs:199-212`). Scenario: a Discord message object without `content`, or with an unusual author shape, lands in the channel. Every poll fails with "cursor retained", and there is no skip command. Harm: no Discord → room traffic until someone edits the state file by hand.
3. **Discord's 3 s deadline versus a line that runs anyway.** `connection` runs the job if `write_response` succeeded (`server.rs:343-351`). A successful local write does not mean Discord accepted it within 3 s. Scenario: slow fsyncs in `Record::lock` and `save` (`server.rs:254-269`) on a loaded disk delay the deferral past 3 s. The line still runs; the user sees "This interaction failed" and re-issues it, which gives a **new interaction id**, a new custody record, and a second execution. Harm: two submits for a non-idempotent verb such as pay or doc submit, unless that verb has its own Lean-side operation record.
4. **A revoked user's deferred interaction never resolves.** `run_job` returns silently when the roster re-check fails (`server.rs:298-300`), with no PATCH. Discord shows "thinking…" until the token expires, and the record stays `accepted` forever. This is minor.
5. **Custody grows without bound and holds sensitive data.** Each completed record stores the full stdout and stderr (up to 1 MiB each, `session.rs:36`, `server.rs:314`) and is never garbage-collected. Scenario: a heavy `/mini-world` user. Disk grows, and under split tenancy the **entrance** account holds every friend's transcripts in `STATE/custody` (`README.md:50` says to protect it like keys).
6. **Slow-loris on the thread pool.** The 10 s timeout applies per `read()` call (`http.rs:48`), so a client sending one byte every 9 s can hold a thread until the 16 KiB head limit. 64 such connections (`server.rs:26`) block the endpoint. This is mitigated only by the deployment, where the listener is private and only Caddy reaches it (`discord.env.example:7`).
7. **The mirror's `me()` re-reads `workspace.json` per entry and falls back to `""`** (`mirror.rs:236-242`). If the read fails mid-run, the bridge's own non-`via` entries are no longer filtered (`:163`) and get echoed to the channel. A startup guard exists (`:404`), but nothing guards inside the loop.
8. **Stale docs and harness (the deploy will misconfigure).**
   - `deploy/discord/README.md:122` tells operators to set `MINI_MIRROR_WEBHOOK_URL`, `MINI_MIRROR_BOT_TOKEN` and `MINI_MIRROR_CHANNEL_URL`. The binary exits 78 when it sees them (`mirror.rs:371-375`).
   - `native/discord-entrance/tests/native-world.py:108` sets the same three variables and no `MINI_MIRROR_BROKER`, so that evidence scenario can no longer pass its mirror rows.
9. **The split-tenancy unit and sudo.** `deploy/discord/mini-discord.service:27` sets `NoNewPrivileges=yes`. That prevents setuid `sudo` from elevating, which `Deployment::run` needs in split mode (`session.rs:65-70`). This only works if dregg-infra's drop-in overrides it, and that drop-in is not visible here. Scenario: a fresh install with the unit as written plus `MINI_SESSION_RUNNER` makes every line fail with a sudo error, reported as an `error:` ending.
10. **`MINI_DISCORD_ROSTER_OWNER_UID` is parsed with `as u32`** (`server.rs:72`), so a value larger than u32 wraps silently. This is cosmetic.

### 4(b) spk-rpc

1. **A streamed response must finish before anything returns.** `dispatch_web` waits for `done` (`web.rs:596-614`), bounded by `max_response` of at most 8 MiB and by the deadline. Scenario: an app that streams (server-sent events, long-poll, a large download over 8 MiB) never returns or overflows, and the caller sees "delivery uncertain" or "stream failed". Harm: whole classes of Sandstorm apps (streaming downloads, long-poll fallbacks) do not work. spk-host's `rpc_adapter` uses `MAX_RESPONSE_BYTES = 8 MiB` and a 30 s limit (`rpc_adapter.rs:29-30`).
2. **A response header outside the whitelist or not lowercase rejects the whole response** (`web.rs:384-386`). If the packaged bridge passes an app's mixed-case `X-OC-MTime` unchanged, the request fails instead of the header being dropped. I could not confirm from these files whether Sandstorm's bridge lowercases; this is a risk, not an observed failure.
3. **`MinimalSandstormApi` and `MinimalSessionContext` implement nothing** (`protocol.rs:95-99`). Any app that calls `SandstormApi` (stayAwake, activity, powerbox request/offer, identity lookups) or `SessionContext` (`activity`, `offer`, `request`) gets `unimplemented`. Scenario: apps that post activity events or open the powerbox fail at that call. This fails closed by design, but it marks the limit of which apps can run.
4. **Bounds differ from Lean's** (§3b.1): a 300-permission app decodes and then fails Lean authoring, with an error message that comes from a different layer than the decode. This is low severity.
5. **`persistent.capnp` is modified and unpinned.** It is not in `SHA256SUMS` (that file lists 27 entries, all of `schema/*.capnp`), even though `README.md:16-21` says it was edited from the Cap'n Proto 1.5.0 original. A drift there would be invisible to the digest check.
6. **The README is stale.** `README.md:60` says "WebSocket … not connected", but `web.rs:623-755` implements `open_web_socket` (commit 655160c2). `README.md:72-73` recommends an unfiltered `cargo nextest run` for the crate. That is acceptable for a crate this small, but it conflicts with the house rule as worded.

---

## 5. Unwired / undone / dead / twins

### 5(a) discord-entrance

- **Dead code:**
  - `curl::Poster::get` and `run_get` (`curl.rs:57-122`) have no caller since the mirror moved to the broker (commit 7bb016a3).
  - `reply::render` (`reply.rs:56-65`) is used only by its own test.
  - `http::client_request` (`http.rs:134-162`) is a test and fake helper compiled into the shipped library.
- **Legacy state:** `State.height` (`mirror.rs:72`) is read and passed to `outbound` (`:268`) but never written. It survives only as a migration watermark (`README.md:138`).
- **Not packaged:** `mini-discord-mirror` is absent from `deploy/candidate/package.py:71`/`88`, which lists only `"discord": "mini-discord"`. `deploy/discord/` has no systemd unit for the mirror either. The mirror is therefore not deployable through the candidate pipeline.
- **Twins:**
  - **curl wrappers:** `discord-entrance/src/curl.rs`, `mini-keys/src/server/discord.rs:77-121` (its own `curl()` and `plain_url`), `pay-watcher/src/transport.rs:179` (its own `CURL`), and `resource-client/src/app_document.rs:385`. That is four implementations of "curl with config on stdin".
  - **`is_snowflake`:** `interaction.rs:111` and `mini-keys/src/server/discord.rs:143`.
  - **HTTP request readers:** `http.rs:47` versus `spk-host/src/http_entrance.rs:663`, `resource-client/src/enrollment_bootstrap.rs:154`, `grain-runtime/src/provider.rs:742`.
  - **The NAME → workspace rule**, duplicated with `render-authorized-keys.sh` in dregg-infra.
  - The custody store was already deduplicated into `mini-sdk` (commit 4b2f299d, `Cargo.toml:27-28`).
- **Stubs and TODOs:** no `todo!` or `unimplemented!`. The README lists undone items: no autonomous reply recovery after restart (`:53`), no automatic retry for an unsent uncertain post (`:137`), attachments not imported (`:134`).
- **Test-only code in the binary:** only `client_request`; `fake-discord` is an example.

### 5(b) spk-rpc

- **Production callers:** only `spk-host` (`spk-host/Cargo.toml:32`; uses in `rpc_adapter.rs`, `dispatch_web_input.rs`, `http_response.rs`, `web_socket.rs`, `materialize.rs`, `claim_descriptor.rs`, `descriptor_native.rs`, `resident_launch.rs`, `resident_service.rs`, `grain_route.rs`, `hostd.rs`, plus the smoke bins). **grain-runtime does not depend on spk-rpc.**
- **Dead or unused:**
  - `SupervisorConnection::get_inline`, `InlineResponse` and `RejectingResponseStream` (`protocol.rs:88-93`, `121-122`, `314-380`) are used only in spk-rpc's own test.
  - `permission_schema_source` and `permission_schema_source_bytes` (`permission_schema.rs`, 73 lines) have **no production caller**. spk-host uses its own `signed_schema_source` (`spk-host/src/materialize.rs:322-334`), which builds the identical JSON *without* the bounds and name validation. That is a twin, and Lean (`Host/ApplicationPermissionSchemaAuthoring.lean`) is the real validator for both.
  - `ViewInfo.permission_names` and `role_count`, the "compatibility summary" (`protocol.rs:31-34`), are used only by the smoke bins (`spk-smoke.rs`, `gitweb-smoke.rs`, `gitweb-session-smoke.rs`).
  - Generated modules `supervisor_capnp`, `ip_capnp`, `powerbox_capnp`, `activity_capnp` and `persistent_capnp` are exported (`lib.rs:24-66`) but no other crate uses them. They are needed only to satisfy import closure (`supervisor.capnp:23-27`, `ip.capnp:44`, `grain.capnp:21-24`).
  - `BridgeConfig.save_identity_caps` and `expect_app_hooks` are decoded only so that spk-host can refuse them (`materialize.rs:298-308`).
- **17 vendored schemas compiled by nothing**, 2,256 lines: `appid-replacements(-test)`, `backend`, `bridge-proxy`, `control-socket`, `email`, `email-impl`, `hack-session`, `identity-impl`, `api-session-impl`, `mime`, `payments`, `persistentuiview`, `sandstorm-http-bridge`, `sandstorm-http-bridge-internal`, `update-tool`, `web-publishing`. None is imported by a compiled schema. `build.rs:41-50` copies them into `OUT_DIR` without using them.
- **Schema provenance:** every file in `schema/*.capnp` carries a "Sandstorm Development Group" copyright header, and `shasum -c schema/SHA256SUMS` passes for all 27 files. **No schema is minidregg-authored.** The only modifications are (i) the unpinned `capnp/persistent.capnp`, edited to drop an annotation, and (ii) the build-time rename in a derived copy of `package.capnp`.
- **Unwired protocol surface:** SandstormApi and SessionContext callbacks, streaming request bodies, WebDAV methods, persistence (`save`/`restore`), powerbox, and `Grain`/`MainView` beyond `UiView` (`README.md:60-61`). In spk-host, `rpc_adapter.rs:6` is `#![allow(dead_code)] // Staged`.

---

## 6. Size and shape

### 6(a) discord-entrance

| File | Lines | Notes |
|---|---|---|
| src/bin/mini-discord-mirror.rs | 619 | ~437 production, ~182 test |
| src/server.rs | 386 | |
| src/session.rs | 302 | ~270 production |
| src/interaction.rs | 176 | ~120 production |
| src/curl.rs | 169 | 66 dead (`get`) |
| src/signature.rs | 136 | ~88 production |
| src/reply.rs | 135 | ~88 production; `render` dead |
| src/http.rs | 162 | 29 test-only (`client_request`) |
| src/roster.rs | 131 | ~78 production |
| src/lib.rs | 69 | |
| src/navigation.rs | 56 | |
| src/main.rs | 55 | |
| native/discord-entrance/tests/endpoint.rs | 316 | |
| examples/fake-discord.rs | 215 | |
| native/discord-entrance/tests/native-world.py | 137 | stale (§4a.8) |
| Cargo.toml | 36 | |

Dependencies: `ed25519-dalek`, `libc`, `serde_json`, `mini-sdk` (features `native`: blake3, fips204/ML-DSA, sha2, zeroize), and `mini-keys` (client, default features off). That is 45 unique crates in the normal-dependency tree (`cargo tree --offline`). Most of the weight comes from mini-sdk; the entrance itself needs only lease and atomic JSON.

**Demo-minimal cut.**
- **Keep** for the Discord surface: lib, main, server, http (without `client_request`), signature, interaction, roster, session, reply (without `render`), curl (`send` only), and navigation (for `/mini-world`).
- **Keep the mirror** only if the demo includes room ↔ channel. It must then be added to `package.py` and given a unit, and flaws 4a.1 and 4a.2 should be fixed first, or the demo channel will wedge at the first burst.
- **Delete today:** `curl.rs:57-122`, `reply.rs:55-65` and their tests. Fix or delete `native/discord-entrance/tests/native-world.py`, and rewrite `deploy/discord/README.md:122`.

### 6(b) spk-rpc

| File | Lines |
|---|---|
| src/protocol.rs | 794 (381 production, 412 test) |
| src/web.rs | 755 (no tests in file) |
| src/bridge_config.rs | 108 (74 production) |
| src/permission_schema.rs | 73 |
| src/lib.rs | 73 |
| build.rs | 71 |
| README.md | 97 |
| compiled schemas (10 + persistent) | 3,870 |
| uncompiled schemas (17) | 2,256 |

Dependencies: `capnp 0.27` (unaligned), `capnp-rpc`, `futures`, `serde_json`, `tokio` (net, rt, macros, time), `tokio-util` (compat); build-time `capnpc` and `sha2`. That is 38 unique normal crates. The build also needs the external `capnp` binary.

**Demo-minimal cut (SPK grains on).**
- **Keep:** lib, protocol (production part), web, bridge_config, and the 10 compiled schemas plus persistent.
- **Delete today** with no effect on spk-host:
  - the 17 uncompiled schemas, and their entries in SHA256SUMS. If they are wanted as reference, keep them outside the crate.
  - `get_inline`, `InlineResponse` and `RejectingResponseStream`, about 75 lines. The in-crate test would move to `dispatch_web`.
  - **one** of the two schema-source projections: either `permission_schema.rs` or `spk-host/src/materialize.rs:322-334`. Since Lean validates, the smaller one is enough.
  - `permission_names` and `role_count`, once the smoke bins read `permissions` and `roles`.

---

## 7. Deployability on a small public Linux VM

### 7(a) discord-entrance

- **Build:** pure Rust (`ed25519-dalek` with `fast`). No C dependencies beyond libc.
- **Runtime system dependencies:** `/usr/bin/curl` (hard-coded default, `curl.rs:14`), `bash` (for `mini-shell-ssh`), and `/usr/bin/sudo` in split mode. Debian has all of these, though curl is not always in a minimal image; install it.
- **Ports:** one plain-HTTP listener. The env example uses `10.10.1.10:8793` (`discord.env.example:7`), which assumes the two-box anchor/workhorse topology. On a single VM, use `127.0.0.1:8793` with Caddy on the same host. Discord needs a public HTTPS URL; Caddy handles TLS and ACME.
- **Privileges:** runs as `mini`, or `mini-discord` in split mode. No root and no capabilities.
- **Persistent state:**
  - the roster `/etc/mini/discord-roster.json`, root 0644;
  - custody under `SESSIONS/.discord-custody` or `/var/lib/mini-discord/custody`;
  - logs in session homes or in state.
  - `/run/mini-discord` spool is created by `RuntimeDirectory=`.
- **Secrets:** none for the endpoint. The public key and app id are not secret (`discord.env.example:2-3`). The bot token is used once from ember's machine to register commands (`README.md:98-100`).
- **Mirror secrets:** the mirror needs the `mini-keys` broker running with `discord-mirror.json` (webhook URL, channel URL, bot token) and a `discord` peer role. The Message Content privileged intent must be enabled (`README.md:123`).
- **systemd:** `deploy/discord/mini-discord.service` exists and is hardened. The mirror has no unit.
- **What breaks on a fresh Debian box:**
  1. The listen address assumes a private 10.10.x network.
  2. `Requires=mini-store.service` and `ReadWritePaths=/var/lib/mini/store/node/{sponsor,public}` (`mini-discord.service:11`, `38`) assume the whole Mini node layout.
  3. Split mode requires `mini-session-run` and a sudoers rule from dregg-infra (not in this repo), and conflicts with `NoNewPrivileges=yes` (§4a.9).
  4. Sessions must be pre-created by `render-authorized-keys.sh` (dregg-infra).
  5. The mirror is not in the candidate set.
  6. With `ProtectSystem=strict`, split-mode `MINI_DISCORD_STATE=/var/lib/mini-discord` is not writable unless the drop-in adds it to `ReadWritePaths` or `StateDirectory`.

### 7(b) spk-rpc

- **Build:** requires the `capnp` compiler plus its `/capnp/c++.capnp` include at build time. The repo's own burst scripts build capnp **1.5.0** from source with a pinned sha256 (`scripts/burst/remote/root.sh:91-98`) and check for exactly that version (`scripts/burst/remote/check.sh:23`). Debian's packaged `capnproto` is older (bookworm ships 0.9.x). I have not verified that capnpc 0.27 works with it, so treat "apt install capnproto" as untested.
- **Runtime:** none of its own. It is linked into spk-host, uses no ports or files, and runs inside the spk-host process on the inherited fd3 socketpair.
- **systemd:** not applicable. Secrets: none.
- **What breaks:** a build host without capnp, or a CI or candidate builder that lacks capnp. Also, `build.rs:30-34` panics if `package.capnp` has drifted, by design.

---

## 8. Questions for the Lean side

1. Should a Discord account → participant binding be a governed Lean fact rather than `/etc/mini/discord-roster.json`, for example a `PARTICIPANT_*`-style receipt naming the external account, so that turns proposed via Discord are attributable to a Discord identity and revocation is a Lean event? Today Lean cannot tell a Discord-proposed turn from an ssh one, and two Discord ids can share one custodial key (`native/discord-entrance/tests/endpoint.rs:313`).
2. Is "every non-bot member of a Discord channel may `say` in room R through the bridge's key" an authority Lean should grant explicitly, as a delegation from the room to the bridge with a scope, rather than something Rust decides in `inbound` (`mirror.rs:182-218`)?
3. Should room → external-channel disclosure be a Lean-checked consent (a room law or attestation) rather than `MINI_MIRROR_PUBLISH_ROOM_TO_CHANNEL=yes` plus a Rust check of a Rust-written `private` stamp? Is there a Lean definition of room privacy that the `tail --json` `private` field is meant to project? I found none by grep.
4. Which `mini shell` verbs are idempotent under a re-issued Discord interaction (new interaction id, same line)? If `submit` and pay verbs do not carry a Lean operation record by default, the 3-second-deadline double-run (§4a.3) can double-submit.
5. For the permission schema: is `Kernel/ApplicationPermissionSchema.lean:120-128` the single source of truth? If so, may Rust's `decode_view_info` name and default checks (`protocol.rs:156-193`) and `permission_schema.rs:10-40` be deleted, with the 4,096 vs 256 bound mismatch resolved toward Lean?
6. Is refusing `powerboxApis`, `saveIdentityCaps` and `expectAppHooks` (`bridge_config.rs:63-68`, `spk-host/src/materialize.rs:298-308`) a Lean install-law decision that should appear in a Lean descriptor or refusal, or a permanent physical limit?
7. Should "a deferral written but possibly not seen by Discord" and "a line killed at 120 s" produce a Lean-visible operation state (via `--operation-record`) for every `/mini` line, rather than only an entrance-local custody phase?
