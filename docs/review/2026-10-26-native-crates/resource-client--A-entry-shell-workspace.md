# resource-client, shard A: entry points, shell, workspace

| | |
|---|---|
| Shard | `native/resource-client`, shard A: "entry points, shell, workspace" |
| Crate | `minidregg-resource-client` (binary `mini`, `native/resource-client/Cargo.toml:9-11`), a member of the root workspace (`Cargo.toml:3`); it has no `Cargo.lock` of its own |
| Date | 2026-10-26 |
| Reader | Opus, read-only. No build or test was run; every claim comes from reading source. |
| Scratch | `/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/rc-A/` (`reach.tsv`, `arm-module.tsv`, `other-crate-callers.txt`, `reach.py`) |

Files covered, all read in full:

| File | Lines |
|---|---:|
| `native/resource-client/Cargo.toml` | 43 |
| `native/resource-client/README.md` | 982 |
| `native/resource-client/src/main.rs` | 5,209 |
| `native/resource-client/src/shell.rs` | 4,306 |
| `native/resource-client/src/shell/session_fs.rs` | 218 |
| `native/resource-client/src/shell/doc_render.rs` | 251 |
| `native/resource-client/src/shell/template.rs` | 289 |
| `native/resource-client/src/shell/law.rs` | 666 |
| `native/resource-client/src/workspace.rs` | 8,795 |
| `native/resource-client/src/workspace/studio_preview.rs` | 222 |
| `native/resource-client/src/workspace/web_create.rs` | 424 |
| `native/resource-client/src/workspace/web_author.rs` | 494 |
| `native/resource-client/src/workspace/studio.rs` | 602 |
| **Total** | **22,501** (21,476 Rust: 17,114 code and 4,362 test) |

To check the Rust against the Lean side I also read parts of files owned by other shards: `transport.rs` (envelope, frames, `invoke*`, `exchange_unix`), `replan.rs` (`replan`, `is_*` predicates, `retire*`), `client_consent.rs:1-60`, and `web.rs:362-369`. On the Lean side I read `protocol/host-operations.json` (every byte this shard uses), `Host/Main.lean:1862-1881` (`splitKind`, `splitPair`), `:1948-2128` (`pureCodec`, `dispatchSession`), `:2616-2700` (`serveFrame`, `serveSession`) and `Host/RequestRefusal.lean:40-75`.

## Executive summary

1. `mini` has **127 live top-level commands**: 125 arms in `run` (`main.rs:3196-4499`) plus two dispatched in `main` before argument parsing (`bend-session-sign`, `fleet-sign`, `main.rs:4508-4516`). Three more names are tombstones that refuse by name (`key-service*`, `main.rs:3235`). `USAGE` (`main.rs:642-839`) leaves out 12 live commands: `activity`, `checkpoint`, `clock`, `consent-resident`, `hermes-handoff`, `member`, `mix`, `mix-live`, `seat`, `story-law`, `traffic`, `bend-session-sign`.
2. Reachability. **About 45 commands are reached by no journey script, systemd unit, deploy script or other crate.** About 20 more are reached only from `scripts/` or from `grain-runtime` subprocess calls. The whole fn-consumer family (12 commands, `drain.rs`, `worker.rs`, `publisher.rs`), `export-evidence`/`verify-evidence`, `operation-proof`, `traffic`/`mix`/`mix-live`, `escrow-recover`/`enc-*`, `fn-namespace-*`/`fn-frontier-*`, `session-reenroll` and `selected-release-retry` have no live caller. The table in section 1.3 is the spine for the crate synthesis.
3. Framing. Requests to the Lean Host are a 4-byte LE length prefix, then an envelope: `[1|2]`, u32 LE config length, the exact config bytes, (v2 only) a 32-byte Host-image SHA-256, the op byte, then the payload (`transport.rs:930-947`). `main.rs` builds payloads for ops 0-11, 12-18, 112, 130 and 150 with literal bytes (`main.rs:1310-1341`, `:2588-2606`, `:2940`, `:2981`, `:3114`, `:3137`, `:3152`). It does not use the generated `native/host-operations.rs` constants; only `member_app.rs:8-11` does. The Rust and Lean encodings agree byte for byte: kind = u16 LE (`Host/Main.lean:1862-1869`), pair = u32 LE (`:1871-1876`).
4. Response markers. 254 means "the Rust broker never forwarded this" (`transport.rs:964`, `:1136`). 255 is the Host's outcome envelope. **But Rust classifies every 255 as a Host refusal**, and Lean also uses 255 for `.unavailable "host session reopening"` and for any `IO.Error` thrown by a handler (`Host/Main.lean:2646-2654`, `Host/RequestRefusal.lean:66-72`). The shell then exits 3 (`shell.rs:2452-2467`), and the web editor and create forms say "The Store refused this operation" for any recorded decision, including `uncertain` (`web_author.rs:230-251`, `web_create.rs:181-188`). That invites a user to make a second operation after an undecided one.
5. `workspace.rs` (7,079 code lines) is a full client-side authoring layer. It builds every intent JSON itself (subject, nonces, grants, targets, roots), reserves resource and capability IDs in a Rust namespace (`participant_namespace::reserve`), and derives the child capability record (verbs, maxCost, `notBefore = max(parent, height)`, ancestors; `workspace.rs:3281-3425`). It lowers line-level document edits into element-tree edits with its own line numbering and a Wagner-Fischer diff (`:2041-2138`, `:5634-5840`). It keeps a "seen" snapshot as the edit base (`:5236-5258`). Lean still authors canonical bytes (`author intent`, `:3546-3552`) and admits.
6. Retry semantics are decided in Rust in three places. (a) **Append recovery** authors a new proposal with a fresh nonce after a decoded final `refused` at phase `admission` plus a signed read showing the root moved (`workspace.rs:3599-3657`, `replan.rs:109-118`). (b) **Birth release** re-authors after the SDK's `Standing::Refused` (`workspace.rs:4308-4342`, `:4707-4713`); reserved IDs make a second birth collide. (c) **Stale-root replan** of `submit` and `query` (`main.rs:1849-1865`). Each is guarded by a decoded Lean refusal, so a retry becomes a second operation only if Lean can answer `refused` after committing (section 8, Q1 and Q2). `mini workspace --action submit` **without `--attempt`** can submit the same ordinary invoke intent twice in two fresh attempts (`workspace.rs:3592-3594`); only append and delegation proposals bind one attempt.
7. The shell (`shell.rs`, 3,161 code lines) owns syntax: `words()` at `:894`, and `plan()` at `:1131` maps a line to one `Plan`. It runs verbs **in-process** through `main::run` under `catch_unwind` (`:2569-2581`). It computes no Host answer locally, except the discovery-only verbs (`whoami`, `inbox`, `history`, `room list`, `export`, `help`). It does **author law JSON**: `document_law` (`:147-162`), `room_law` (`:172-187`) and `board_law` (`:709-719`) are hand-written policy terms with no Lean emitter. A second hand-written twin is the law grammar parser in `shell/law.rs` with its hard-coded verb-tag table (`law.rs:59-67`).
8. Studio, `web_create` and `web_author` **are reachable from a binary route**: `mini web --listen 127.0.0.1:PORT` (`main.rs:3213`, `web.rs:52-65`, routes at `web.rs:603-637`, `web/create.rs`, `web/editor.rs`, `web/studio.rs`). The route is loopback-only, and no unit or journey reaches the Studio routes. `jweb.sh` and `jdocuverse.sh` exercise `mini web` but no Studio path. This matches the README row "no member-reachable route". Studio preview shells out to GNU `timeout` (`studio_preview.rs:71-72`), which macOS lacks.
9. Tests: 149 `#[test]` across the shard, 4,362 of 21,476 Rust lines. Several test only the code's own model: the document-push tests replay actions on a Rust re-implementation of the kernel's `editElementStep` (`workspace.rs:7269-7329`), and the replan test drives a closure fixture (`:8107-8136`). There are also two duplicate hex test modules (`main.rs:5186-5209`).
10. For the Hetzner demo the minimum is: the `shell`, `socket-proxy`, `serve` (plus `serve-public-proxy` for split tenancy), `workspace`, `enroll`/`join`, `keygen`, `bootstrap`, `clock`, `checkpoint` and `pay` arms, and the core submit/query/retry/author/inspect pipeline. Section 6 lists the files a demo-only build could drop (about 14.4K lines of this shard's surface, much more crate-wide).

---

## 1. What this code is and does

### 1.1 `Cargo.toml` and `README.md`

`Cargo.toml` (43 lines) declares the package `minidregg-resource-client`, the binary `mini` at `src/main.rs` (`Cargo.toml:9-11`), license AGPL, and `publish = false`. Every dependency is pinned with `=`. The heavy cryptographic stack: `ed25519-dalek` (zeroize), `x25519-dalek`, `chacha20poly1305`, `sha2`/`sha3`, `argon2`, `ring`, `rustls` + `rustls-pemfile` + `x509-parser` (NNTP STARTTLS and certificate pins), and `aws-lc-rs` + `aws-lc-sys` (ML-KEM-768 seeded keygen, `Cargo.toml:31-34`). Path dependencies: `mini-sdk` (feature `native`), `compatible-upgrade-custody`, `minidregg-mini-keys` (client side only, `default-features = false`; the full broker is a dev-dependency so tests run against the real server, `:41-43`) and `minidregg-pay-watcher` (its bounded HTTP transport, `:38-39`). There is no clap; arguments are parsed by hand (section 1.2).

`README.md` (982 lines) is a command manual. It covers workspace init/import/read/submit/recover/propose/delegate/create, the persistent `serve` socket, the operator share-issue and agent-reserve custody, selected release, the fn consumer family, origin-publish, continuity, meter, portable evidence, the E1 consumer, keygen, bootstrap, author kinds, draft constructors and the acceptance scripts. The "Honest state" table the brief mentions is in the **root** `README.md` (lines 71-99), not here. Most of the README describes commands that section 1.3 finds unreached by any journey or unit (fn consumer, origin publish, evidence export).

### 1.2 `src/main.rs` (5,209 lines; code 1-4557, tests 4558-5209)

**Module tree.** Lines 14-179 declare 91 `mod` items, 61 of them `#[cfg(unix)]`. Two pull files from outside `src/` with `#[path]`: `../../hybrid_kem.rs` and `../../crypto_transit.rs` (`main.rs:88-92`). Six come from `protected_object/` (`:160-177`). Every crate module is declared here, so `main.rs` is the crate root for the whole 290K-line Rust tree in this crate. Only `workspace` and `shell` (and their children) belong to this shard.

**Process-wide state** (`main.rs:181-262`):
- `SOCKET: OnceLock<PathBuf>`: the selected transport, a local path or `ssh:DEST`.
- `SSH_IDENTITY`.
- `EXPECTED_HOST_SHA`: a worker or remote Host pin.
- `WORKSPACE_HOST_PIN: (path, sha)`, so the about 150 MB Host image is not re-hashed (`:185-193`).
- `VERIFY_HOST`, `QUIET_WORKER`.
- `EXIT_STATUS: AtomicU8`: the highest code wins (`:198-202`).
- Thread-locals: `COMMAND_ENDING` (`:221-229`), `HOST_DECISION` (`:252-262`), `SIGNER` (`:275-277`) and `LINE_REFUSAL` (`:358-368`). Thread-local so concurrent browser/native views cannot consume one another's refusal; the test `concurrent_requests_keep_exact_refusal_and_recovery_class` is at `:5160-5184`.

**Data model.**
- `CommandEnding { Client | Refused | Undecided }` renders exit codes 1, 3 and 4 (`:207-220`).
- `HostDecision { RefusedFrame { command, byte, encoded, decoded: Option<Value> }, Outcome(Value) }` (`:235-248`). It is noted at the point the Host answered, so the shell can tell a Host decision from client prose.
- `SignerContext { host, config, subject, public }` (`:268-273`). It is recorded only for JSON intents (`note_signer`, `:282-296`). After a `bad-signature` refusal the client asks key status (op 144) and names a rotated-away key (`not_current_key_note` `:309-324`, `bad_signature_explanation` `:329-337`).

**Refusal rendering.**
- `outcome_text` (`:375-395`) decodes a hex field to text and falls back to hex when the text holds control characters.
- `refusal_line` (`:400-418`) builds `refused: <reason>: <detail> (phase …)` from the Host's own decoded outcome, preferring the Host's `explain`.
- `refusal_hint` (`:425-432`) matches the prose `CapabilityDelegationController.Reject.descent` in the detail to add a hint. This is display-only prose matching.
- `host_refusal_ending` (`:436-456`) is the final line `mini` prints.

**Host image identity** (`:458-593`). `host_image_sha256` returns the pinned digest without reading the file when a workspace pinned this path, unless `--verify-host` or `MINI_VERIFY_HOST=1` is set (`:502-507`). Otherwise it hashes once per `(dev, ino, size, mtime, ctime)` identity and refuses a file that changed while it was hashed (`:526-555`). An empty path means a remote client; it must use `EXPECTED_HOST_SHA` (`:495-501`).

**Session transport entry.** `session_invoke` (`:596-613`) has two paths:
- Ops 7-11 (author, inspect, signatures, observe-assemble, assemble) never go to the socket. `client_consent::codec_frame` runs them against a separately selected **local** Host image (`client_consent.rs:50-56`).
- Every other op calls `transport::invoke_pinned_with_local` with the selected Host's SHA-256, a v2 envelope.

`pin_worker_host_image` (`:616-640`) reads `pin.json` of a v2 worker state.

**Argument parser** (`Args`, `:853-983`). The first token is the command. `--verify-host` and `--remote DEST` may precede it (`:863-871`).
- `pay X` and `store X` become `--action X` (`:877-881`).
- `channel ACTION ROOM [@NAME TEXT…]` is positional (`:885-908`).
- `join --solana|--wait|--renew` becomes `--mode` (`:917-922`).
- `--no-prerotation` is the only valueless switch (`:928-931`). Every other `--flag` takes exactly one value.
- `required`/`optional` remove a pair, `repeated` collects all, and `finish` refuses leftovers or duplicates (`:940-982`).

`REMOTE_COMMANDS` (`:847-850`) is the 12-command participant surface allowed over `--remote` (`workspace, enroll, join, pay-claim, shell, submit, query, retry, author, inspect, describe, profile`). It is enforced at `:1186-1195`.

**Host process paths.**
- `process` (`:1231-1244`): pure codec verbs go to `client_consent::codec_process`; with a socket, to `socket_process`; otherwise to `local_process`.
- `local_process` (`:1246-1270`) runs `HOST CONFIG args…`. Any nonzero exit becomes "request status uncertain".
- `socket_process` (`:1280-1383`) translates a CLI-shaped verb into an op byte and payload (table in section 1.4).
  - On reply byte 255 it asks the same Host to decode the frame with op 8 `inspect outcome`. Through `session_invoke` that is the local codec child, since 8 is in 7..=11.
  - It records `HostDecision::RefusedFrame`. For `prepare` and `query` it retains the refusal (`prepare_refusal::retain`, `query_refusal::retain`, `:1365-1371`) and returns an error.
  - Otherwise it writes `reply[1..]` to the destination path and fakes a successful `Output` (`:1374-1382`).

**The signed-operation pipeline.**
- `authorize_observation` (`:1792-1842`), in order:
  1. author the intent, or copy a binary intent;
  2. `client_consent::intent` binds custody;
  3. sign the intent bytes;
  4. `challenge` (op 4);
  5. inspect the challenge;
  6. sign the consent-checked headers;
  7. `signatures` (op 9);
  8. `observe-assemble` (op 10) produces `signed-observation.bin`.
- `submit` (`:1849-1865`) wraps `submit_once` in `replan::replan(…, replan::stale_root, retire_attempt)`.
- `submit_once` (`:1888-2009`), in order:
  1. `receipt_continuity::begin_attempt`;
  2. copy intent and config; write `attempt.json` (`write_manifest`, `:1735-1758`);
  3. observe;
  4. `prepare` (op 1) produces `plan.bin`;
  5. inspect the plan;
  6. optional provider-continuity guard (`:1953-1970`);
  7. sign the plan headers through `client_consent::plan`;
  8. `assemble` (op 11) produces `call.bin`;
  9. **fsync `call.bin` and its directory ancestry** (`sync_retained_call`, `:1411-1416`);
  10. unless prepare-only, `submit` (op 2) produces `outcome.bin`;
  11. inspect the outcome and finish continuity;
  12. `confirmed_outcome` (`:1700-1712`).
  
  `confirmed_outcome` notes `HostDecision::Outcome` for **every** non-`confirmed` type, including `uncertain`, `unavailable` and `contention`.
- `dry_run` (`:2056-2124`) plans, signs and sends op 130.
- `observation_stale` (`:2132-2148`) probes a retained factory observation with `query` to tell the stale-root race from a real refusal.
- `query_retained`/`query_once` (`:2169-2230`): observe, `query` (op 5), inspect `view-*`, then `verify_query_presentation`. That checks the hiding opening for resource, at and resource-scope views (`hiding::verify_view`, `:2232-2262`).
- `query_batch_*` (`:2267-2375`) handles 1-16 signed reads in one op-4/op-5 batch. It refuses challenges whose `domain, semantics, worldRoot, height, authorityRoot` differ (`:2341-2348`).

**Exact retry** (`retry_with_upgrade`, `:2444-2529`).
1. It requires `call.bin` and fsyncs it.
2. It may short-circuit through `receipt_continuity::carry::retry_lookup`.
3. It reads the manifest (`manifest_paths` `:2397-2438`, which pins SSH identity, consent pins and the Host pin from `attempt.json`).
4. It allocates the next `retry-NNNN.{bin,json}` (`mini_sdk::store::AttemptDir::next_retry`, `:2440-2442`).
5. It sends `submit` or `lookup` **with the exact same `call.bin`**.

The upgrade variant (used only by `consumer-host-upgrade`) re-verifies the migration evidence, config bytes and call bytes against the durable record before using the new Host (`:2472-2519`).

**fn consumer, origin, continuity, enrollment view.**
- `host_command` (`:2541-2573`) passes 15 allowlisted Host/Main fn commands through, direct CLI only.
- `consumer_poll` (`:2701-2764`), op 12 for B or op 14 for A: retains `reply.frame`, then validates the type, the status and the canonical lowercase `intentHex`. `validate_skip_decision` (`:2644-2684`) bounds the scan to 1..16 positions, `to ≤ u32::MAX`.
- `consumer_ack` (`:2847-2879`), op 13 or 15. `parse_ack_result` (`:2774-2844`) separates `durable-accepted` from `covered-by-durable-frontier` and checks own-R cursor arithmetic.
- `origin_outbox_prepare` (`:2925-2958`) is op 16 with a 1,516,384-byte carrier cap. `origin_outbox_export` (`:2961-3045`) is op 18 and checks several canonical decimal fields.
- `continuity` (`:3094-3129`) is op 17 with `provider_continuity::request_payload`.
- `enrollment_view` (`:3136-3163`) sends op 112, then op 8 `inspect pay-enrolment-view`, and requires the view `DREGG/PAY/ENROLMENT-VIEW/v3`.

**Key generation** (`keygen` and `generate_key`, `:1081-1191`). It creates the seed (mode 0600), the public key, optionally the NEXT key, its public half and a co-signature (FIX-IDENTITY, `:1167-1189`), an optional hosted marker, and an optional seed escrow to the sponsor's hybrid key (`:1130-1146`). It refuses to overwrite any existing file (`:1105-1127`). The seed buffer is zeroed after writing (`:1148`, `:1173`).

**Bootstrap** (`:1433-1478`), in order:
1. create the directory and `checkpoint.key` (32 random bytes, mode 0600, `:1426-1431`);
2. copy the genesis source and operator config;
3. run `profile` and `author genesis`;
4. run `genesis`, which writes `pinned-config.json`;
5. run `bootstrap`, `describe` and `pay-ledger` (into `pay-ledger-genesis.json`).

It requires direct Host CLI; a socket is refused at `:3808-3810`.

**Dispatch** (`run`, `:3165-4501`). It configures `--replan-max`, `--ssh-identity`, `--socket`/`--remote`/`--host-sha256` and the remote allowlist, then matches the command name (full table in 1.3). `main` (`:4503-4525`) adopts the key-cache passphrase out of the environment first (`workspace::private::adopt_keycache_passphrase`; it removes `MINI_KEYCACHE_PASSPHRASE` from the environment, `private.rs:84-89`). It routes `bend-session-sign` and `fleet-sign`, then calls `main_ending` (`:4537-4551`). That prints a recorded `CommandEnding`, else a Host refusal line (exit 3), else `mini: error` (exit `max(status, 1)`). `mini` with no arguments prints USAGE and **exits 0** (`:862`, `:4545`).

**Tests** (`:4558-5209`, 25 tests): argv building, Host-digest caching by inode and ctime, pin plus `--verify-host` refusal, option ordering, fn decision and ACK parsers, public-schema inspection, header signing, refusal rendering, keygen no-clobber and next-key co-signature, `read_secret` custody, `selected_release_sign` against a shell-script fake Host, exact retry evidence numbering, thread-local isolation, and two decoder modules that repeat each other (`ascii_hex_regression` `:5186-5196` and `decode_hex_tests` `:5198-5209`).

### 1.3 The full command surface (the spine for the crate synthesis)

Columns:
- **Module** is the function the arm calls.
- **J** counts files among the 134 journey and acceptance scripts under `native/resource-client` (`journey.sh`, `journey.d/*`, `*-journey.*`, `*-acceptance.*`) whose text has a `mini`/`MINI` token followed within 30 characters by the command word.
- **D** is the same count over the 154 non-Markdown files under `deploy/`.
- **S** is the same count over `scripts/`.
- **X** names other crates that spawn `mini <cmd>` (`grain-runtime`).

The counts come from `scratchpad/rc-A/reach.py`. They are heuristic, so false positives are possible for generic words: `key` matches `mini-keys`, `store` matches `mini-store`. Commands at zero in every column were re-checked with a plain repository-wide grep (excluding `src/` and docs). "Unreached" below means no `fn main` caller, unit, deploy script, journey or other crate.

| Command | main.rs arm | Module / function | J | D | S | X / note |
|---|---|---|---:|---:|---:|---|
| `join` (memo v2) | 3198 | `join_solana_v2::run` | 1 | 1 | 3 | `jpay-v2.sh` |
| `join --solana/--wait/--renew` | 3200 | `join_solana::run` | 1 | 0 | 0 | `jpay-bootstrap-budget.py` |
| `join` (plain) | 3202 | `participant_enrollment::join` | 6 | 2 | 1 | FRIENDS.md path; `deploy/candidate/build.sh` |
| `socket-proxy` | 3204 | `proxy::serve` | 1 | 1 | 1 | **deploy**: `deploy/shell/mini-socket-proxy:35` |
| `workspace` | 3210 | `workspace::run` | 83 | 5 | 8 | **deploy**: `deploy/candidate/run.sh:237-246`, `deploy/pay/mini-pay-watcher:31` |
| `member` | 3211 | `member::run` | 2 | 1 | 2 | not in USAGE |
| `web` | 3213 | `web::run` | 4 | 0 | 0 | `jweb.sh`, `jdocuverse.sh`, `doc-search-journey.py` |
| `operation-proof` | 3215 | `append_proof::run` | 0 | 0 | 0 | X: `grain-runtime/src/resident_delivery.rs` |
| `enroll` | 3217 | `participant_enrollment::run` | 11 | 0 | 0 | shell `enroll` verb |
| `clock` | 3218 | `clock::run` | 10 | 3 | 0 | **deploy**: `deploy/clock/mini-clock-tick.service:49`; not in USAGE |
| `checkpoint` | 3219 | `checkpoint::run` | 3 | 1 | 2 | **deploy**: `deploy/checkpoint/mini-checkpoint-certify.service:24`; not in USAGE |
| `job` | 3221 | `job::run` | 5 | 0 | 0 | shell `job`/`jobs` |
| `activity` | 3222 | `activity::run` | 5 | 0 | 2 | objective journeys; not in USAGE |
| `seat` | 3223 | `seat::run` | 2 | 0 | 0 | not in USAGE |
| `shell` | 3225 | `shell::run` | 17 | 8 | 6 | **deploy**: `deploy/shell/mini-shell-ssh:23,26`; Discord entrance through ssh |
| `key` (credential store) | 3229 | `keys::run` | (36) | (4) | (9) | counts inflated by `mini-keys`; shell `key` verb |
| `key-service`, `key-service-config`, `key-namespace` | 3235 | tombstone: refuses by name | 0 | 0 | 0 | dead names kept as refusals |
| `fleet` | 3238 | `fleet::run` | 2 | 0 | 0 | `fleet-journey.sh`, `j17.sh` |
| `relay` | 3240 | `relay::run_relay` | 3 | 2 | 0 | `jchan-*` |
| `relay-emit` | 3242 | `relay::run_emit` | 1 | 0 | 0 | |
| `relay-witness` | 3244 | `relay::run_witness` | 2 | 0 | 0 | |
| `relay-key` | 3246 | `relay::run_key` | 2 | 0 | 0 | |
| `channel` | 3248 | `channel::run` | 2 | 0 | 0 | shell `channel` verb |
| `traffic` | 3250 | `scheduled_transport::run` | 0 | 0 | 0 | **unreached**; not in USAGE |
| `mix` | 3252 | `pq_mailbox::run` | 0 | 0 | 0 | **unreached**; not in USAGE |
| `mix-live` | 3254 | `cohort_tcp::run` | 0 | 0 | 0 | named in `cohort-native-tcp.py`, which is not a journey; not in USAGE |
| `adopt-next-key` | 3256 | `key_adoption::run` | 0 | 1 | 0 | `deploy/hermes-dispatch/receiving.py`; shell verb; `journey-key-adoption.py` |
| `rotate-key` | 3258 | `key_rotation::rotate_key` | 3 | 1 | 0 | `jrot*.sh` |
| `key-status` | 3260 | `key_rotation::key_status` | 3 | 0 | 1 | |
| `credit` | 3262 | `credit::run` | 2 | 0 | 0 | shell `credit`/`pay ROOM`/`tariff`/`topup`/`room status` |
| `hermes-handoff` | 3263 | `hermes_handoff::run` | 0 | 2 | 0 | `deploy/hermes-dispatch/*.py`; X: `grain-runtime/src/hermes_room.rs`; not in USAGE |
| `story-law` | 3265 | `story::law_command` | 0 | 1 | 1 | `scripts/gen-storylaw.py`; not in USAGE |
| `well` | 3266 | `well::run` | 4 | 0 | 0 | |
| `pay` | 3267 | `pay::run` | 12 | 3 | 0 | **deploy**: `deploy/pay/mini-pay-watcher:77,102` |
| `pay-claim` | 3269 | `pay_claim::run` | 0 | 0 | 0 | only `jpay-claim-law-tests.sh`, which tests a jq file; **unreached** |
| `enrollment-bootstrap` | 3271 | `enrollment_bootstrap::run` | 2 | 0 | 0 | |
| `enrollment-view` | 3272 | `main.rs::enrollment_view` (op 112, op 8) | 3 | 0 | 0 | |
| `selected-exchange` | 3280 | `selected_exchange::run` | 1 | 0 | 0 | `selected-exchange-journey.sh` |
| `serve` | 3291 | `transport::serve` | 55 | 7 | 18 | **deploy**: `deploy/candidate/run.sh:157,182`, `deploy/grain-host/install-operator-stack:133` |
| `consent-resident` | 3306 | `client_consent::resident` | 0 | 0 | 0 | **unreached**; not in USAGE |
| `serve-operator` | 3313 | `transport::serve_operator` | 3 | 0 | 2 | |
| `serve-public-proxy` | 3326 | `public_proxy::serve` | 3 | 0 | 1 | |
| `operator-status`, `drain-operator` | 3338 | `operator_drain::command` | 0 | 0 | 0 | X: `grain-runtime/src/quiescence_transport.rs`, `resident_preflight.rs`; `public-ingress-process.py`, `platform-service-cut.py` (not journeys) |
| `host-command` | 3349 | `main.rs::host_command` | 0 | 0 | 0 | **unreached** |
| `consumer-poll`, `reply-consumer-poll` | 3357 | `main.rs::consumer_poll` (op 12/14) | 0 | 0 | 0 | only in `.patch` files under `scripts/fn-e1e2`; **unreached** |
| `consumer-ack`, `reply-consumer-ack` | 3377 | `main.rs::consumer_ack` (op 13/15) | 0 | 0 | 0 | **unreached** |
| `origin-outbox-prepare` | 3402 | `main.rs::origin_outbox_prepare` (op 16) | 0 | 0 | 0 | **unreached** |
| `origin-outbox-export` | 3417 | `main.rs::origin_outbox_export` (op 18) | 0 | 0 | 0 | **unreached** |
| `origin-publish` | 3435 | `publisher::publish` | 0 | 0 | 0 | **unreached** (ran once on 2026-09-26: `docs/evidence/2026-09-26-workroom-content-publisher/`) |
| `provider-continuity` | 3461 | `provider_continuity::resolve_attempt` | 0 | 0 | 0 | X: `grain-runtime/src/provider_resolution.rs`, `provider_continuity_rejection.rs` |
| `continuity` | 3476 | `main.rs::continuity` (op 17) | 0 | 0 | 0 | X: `grain-runtime/src/main.rs` |
| `meter` | 3492 | `meter::meter` | 0 | 0 | 0 | X: `grain-runtime/src/main.rs`, `hermes_outcome.rs` |
| `consumer-drain-once`, `reply-consumer-drain-once` | 3512 | `drain::run`, `drain::run_reply` | 0 | 0 | 0 | **unreached** (evidence 2026-09-26 only) |
| `consumer-resume-ack`, `reply-consumer-resume-ack` | 3546 | `drain::resume_held_ack`, `resume_held_reply_ack` | 0 | 0 | 0 | **unreached** |
| `consumer-host-upgrade` | 3569 | `drain::upgrade_host` | 0 | 0 | 0 | **unreached** |
| `consumer-worker`, `reply-consumer-worker` | 3603 | `worker::run`, `worker::run_reply` | 0 | 0 | 0 | **unreached** |
| `store` (`store audit`) | 3625 | `main.rs::store_run` (Host `store-audit`) | (10) | (11) | (18) | counts inflated by `mini-store` |
| `audit` | 3626 | Host `audit` through `process` | 18 | 0 | 1 | |
| `profile`, `describe` | 3638 | `process` (op 6, op 0) | 3, 1 | 0 | 4, 2 | |
| `enc-public` | 3650 | `workspace::roomkey::enc_public_hex` | 0 | 0 | 0 | **unreached** |
| `enc-key-id` | 3661 | `workspace::roomkey::enc_key_id_hex` | 0 | 0 | 0 | **unreached** (shell `whoami` uses the same function in-process) |
| `escrow-recover` | 3673 | `workspace::private::recover_escrowed_seed` | 0 | 0 | 0 | **unreached** |
| `keygen` | 3696 | `main.rs::keygen` | 31 | 2 | 9 | **deploy**: `deploy/candidate/run.sh:79,84`; shell `keygen` |
| `verify-view` | 3729 | `hiding::verify_view` | 1 | 0 | 0 | `jhide.sh` |
| `key` (hiding: `export-blinding`, `cell-blinding`, `derive-salt`) | 3738 | `hiding::*` | 1 | 0 | 0 | `jhide.sh` (cell-blinding, derive-salt); `export-blinding` **unreached** |
| `bootstrap` | 3807 | `main.rs::bootstrap` | 16 | 2 | 7 | **deploy**: `deploy/candidate/run.sh:91` |
| `author` | 3818 | `main.rs::author` (local codec) | 5 | 1 | 5 | |
| `inspect` | 3827 | `main.rs::inspect_public` (2 kinds) | 1 | 1 | 0 | `jgateway.sh` |
| `current-application-intent`, `current-session-intent`, `current-resource-intent` | 3841 | `current_birth::author` | 0 | 0 | 3,1,0 | X: application and session through `grain-runtime/src/main.rs`; `current-resource-intent` **unreached** as a command (workspace calls `current_birth::author` in-process, `workspace.rs:4742`) |
| `agent-reserve-plan/seal/submit/lookup` | 3869-3903 | `agent_reserve::*` | 0 | 0 | 0 | X: `grain-runtime/src/main.rs` |
| `agent-lifetime-reserve-*` (4) | 3906-3940 | `agent_reserve::lifetime_*` | 0 | 0 | 0 | X: `grain-runtime` |
| `agent-lifetime-paid-plan`, `-payer-sign` | 3943-3956 | `agent_reserve::lifetime_paid_*` | 0 | 0 | 0 | X: `grain-runtime` |
| `agent-lifetime-paid-seal/submit/lookup` | 3958-3975 | `agent_reserve::lifetime_paid_*` | 0 | 0 | 0 | **unreached** |
| `agent-lifetime-grant-plan/seal/submit/lookup` | 3977-4004 | `agent_lifetime_grant::*` | 0 | 0 | 1 | only `scripts/spk-platform/issue-agent-lifetime-grant.sh` |
| `session-reenroll` | 4006 | `session_reenroll::run` | 0 | 0 | 0 | **unreached** |
| `session-enrollment-plan/seal/submit/lookup` | 4023-4050 | `session_enrollment::*` | 0 | 0 | 2-3 | `scripts/session-enrollment/native-acceptance.sh`, `scripts/spk-platform/grain-journey.sh` |
| `agent-payer-sign` | 4052 | `agent_payer::sign` | 0 | 0 | 0 | X: `grain-runtime/src/main.rs` |
| `share-issue-prepare/submit/lookup` | 4074-4097 | `share_issue::*` | 0 | 0 | 1 | only `scripts/application-share-issue/native-acceptance.sh` |
| `share-issue-receipt-lookup` | 4099 | `share_issue_receipt::lookup` | 0 | 0 | 0 | X: `grain-runtime/src/shared_app_refs.rs` |
| `grain-share-issue-plan/prepare/submit/lookup` | 4131-4166 | `grain_share_issue::*` | 0 | 0 | 4-8 | `scripts/spk-platform/*`, `scripts/application-share-issue/*` |
| `grain-share-issue-receipt-lookup` | 4168 | `share_issue_receipt::lookup_grain` | 0 | 0 | 0 | X: `grain-runtime/src/shared_app_refs.rs` |
| `historical-call-receipt-lookup` | 4200 | `historical_call_receipt::lookup` | 0 | 0 | 0 | X: `grain-runtime/src/main.rs` |
| `fn-namespace-plan/register/lookup` | 4232-4259 | `fn_namespace::*` | 0 | 0 | 0 | **unreached** |
| `fn-frontier-plan/advance/lookup` | 4261-4299 | `fn_frontier::*` | 0 | 0 | 0 | **unreached** |
| `submit` | 4300 | `main.rs::submit_with_continuity` / `submit` | 58 | 0 | 29 | core |
| `query` | 4328 | `main.rs::query` (optional `workspace::load`) | 10 | 1 | 26 | core |
| `objective-invoke` | 4373 | `objective_invoke::submit` | 1 | 0 | 0 | `objective-native-acceptance.py` |
| `retry` | 4390 | `main.rs::retry` | 7 | 0 | 8 | core; shell `retry` |
| `selected-release-submit` | 4411 | `selected_release::submit` | 2 | 0 | 0 | |
| `selected-release-sign` | 4423 | `main.rs::selected_release_sign` | 2 | 0 | 0 | |
| `selected-source-sign`, `selected-source-publish` | 4433, 4447 | `selected_publisher::*` | 1 | 0 | 0 | `selected-source-publisher-acceptance.sh` |
| `selected-release-lookup` | 4458 | `selected_release::lookup` | 1 | 0 | 0 | |
| `selected-release-retry` | 4464 | `selected_release::retry_submit` | 0 | 0 | 0 | **unreached** |
| `export-evidence`, `verify-evidence` | 4469, 4484 | Host CLI through `host_files` | 0 | 0 | 0 | **unreached** |
| `bend-session-sign` (pre-parse) | 4508 | `bend_session::run` | n/a | | | not in USAGE; check grain-runtime and spk-host |
| `fleet-sign` (pre-parse) | 4514 | `fleet_sign::run` | n/a | | | `fleet-sign-journey.sh` |

Commands with no live caller anywhere: `traffic`, `mix`, `mix-live`, `consent-resident`, `host-command`, all 12 fn-consumer arms (`consumer-*`, `reply-consumer-*`, `origin-outbox-*`, `origin-publish`), `pay-claim`, `enc-public`, `enc-key-id`, `escrow-recover`, `key --action export-blinding`, `current-resource-intent`, `agent-lifetime-paid-seal/submit/lookup`, `session-reenroll`, the six `fn-namespace-*`/`fn-frontier-*`, `selected-release-retry`, `export-evidence` and `verify-evidence`. That is **about 45 entry names**. Reached only from `scripts/` (not a journey or unit by the brief's definition): `agent-lifetime-grant-*` (4), `session-enrollment-*` (4), `share-issue-*` (3), `grain-share-issue-*` (4). Reached only from `grain-runtime` (so only through `mini-hermes.service` / `mini-grain-controller@.service`, which run grain-runtime, `deploy/hermes/mini-hermes.service:31`, `deploy/grain-host/mini-grain-controller@.service:10`): `operation-proof`, `operator-status`, `drain-operator`, `provider-continuity`, `continuity`, `meter`, `current-application-intent`, `current-session-intent`, `agent-reserve-*`, `agent-lifetime-reserve-*`, `agent-lifetime-paid-plan`, `agent-lifetime-paid-payer-sign`, `agent-payer-sign`, `share-issue-receipt-lookup`, `grain-share-issue-receipt-lookup`, `historical-call-receipt-lookup`, `hermes-handoff`. Per the root README, Hermes is off on the public node.

Deployed path (the units and scripts under `deploy/`): `serve`, `shell`, `socket-proxy`, `workspace`, `keygen`, `bootstrap`, `clock`, `checkpoint`, `pay`, plus whatever `shell` reaches in-process.

### 1.4 How the client frames requests to the Lean Host

**Socket path.** It comes from `--socket PATH`, `--remote DEST` (which becomes `ssh:DEST` through `transport::remote_address`, `main.rs:3170-3178`), a workspace's pinned `socket` (`workspace.rs:372-387`), or an attempt manifest's `socket` (`main.rs:2433-2436`, `:2463-2467`). `enrollment-view` defaults the config to `SOCKET.with_extension("config")` (`main.rs:3276`), the copy `serve` writes beside its socket.

**Wire layout, client to broker** (`transport.rs:930-947` for `invoke_inner`; `:914-935` is the deadline variant):

```
u32 LE frame length | envelope
envelope := version(1|2) | u32 LE config_len | config bytes (exact) | [v2: 32-byte Host image SHA-256] | op u8 | payload
```

`main.rs` always uses v2 through `session_invoke` (`main.rs:612`). `transport::invoke` (v1, no pin) is used only by `enrollment_view` (`main.rs:3137`, `:3152`). The broker checks the config bytes and the image pin before forwarding (`transport.rs:173-217`). Frames are bounded by `HOST_MAX_FRAME = bounds::FRAME_BYTES_MAX` (`transport.rs:18`); `read_frame` refuses length 0 or over the bound and grows its buffer only as bytes arrive (`transport.rs:629-662`). `exchange_unix` sets a 10 s write timeout and a 600 s read deadline (`transport.rs:1154-1184`).

**Response markers** (`protocol/host-operations.json` `response_markers`):
- **254**: "Transport refusal: request never forwarded". Rust maps it to `Err("socket rejected request: …")` without recording a `HostDecision` (`transport.rs:964-969`, `:1136-1141`). If a write fails after the broker already refused, Rust reads the waiting 254 and treats it as certain (`:1157-1172`).
- **255**: "Host refusal/outcome envelope". `response_operation_matches` admits reply byte == op or 255 (`transport.rs:1088-1096`). In `socket_process` and the fn routes every 255 is treated as a refusal (`main.rs:1349-1373`, `:2706`, `:2863`, `:2942`, `:2983`, `:3116`).
- **164**: the dispatch no-record refusal (not used in this shard).

**Op table used by this shard**, with the Rust site, the registry entry and the Lean receiver:

| Op | Registry symbol / receiver | Rust payload (site) | Lean decode (site) | Agree? |
|---:|---|---|---|---|
| 0 | DESCRIBE / `dispatchSession` | empty (`main.rs:1311`) | refuses a nonempty payload (`Host/Main.lean:2015-2018`) | yes |
| 1 | AUTHORIZED_PREPARE / `dispatchSession` | signed observation bytes (`main.rs:1313`) | `prepareAuthorizedLoaded`; error becomes `255 refusalFrame "prepare"` (`:2019-2024`) | yes |
| 2 | SUBMIT / `fnDispatch` | exact `call.bin` (`main.rs:1314`) | delegated to `fnDispatch` (`:2025`), not read here | see Q1 |
| 3 | LOOKUP / `fnDispatch` | exact `call.bin` (`main.rs:1315`) | `fnDispatch` | see Q1 |
| 4 | OBSERVATION_CHALLENGE / `dispatchSession` | `pair(intent, signature)` u32 LE (`main.rs:1295-1301`, `:1316`); batch: Lean-authored batch (`:1318`) | `challengeWireLoaded` (`:2026-2031`) | yes (pair layout = `splitPair`, `:1871-1876`) |
| 5 | AUTHORIZED_QUERY / `dispatchSession` | signed observation, or batch (`main.rs:1317`, `:1319`) | `queryWireLoaded` (`:2032-2040`) | yes |
| 6 | PROFILE | empty (`main.rs:1312`) | refuses a nonempty payload (`:2041-2043`) | yes |
| 7 | AUTHOR | `u16 LE kind_len, kind, input` (`main.rs:1302-1309`, `:1320-1322`); in practice handled by the **local codec child** (`main.rs:603-605`, `:1232-1236`) | `splitKind` (`:1862-1869`), `pureCodec` (`:1960-1968`) | yes |
| 8 | INSPECT | `kind_payload` (`main.rs:1323-1325`); also `object-audience*` over the socket (`:1326-1332`) | `pureCodec` or session kinds (`:2045-2066`); a `sessionInspectKind` refuses in `pureCodec` (`:1971-1972`) | yes |
| 9 | SIGNATURES | JSON list bytes (`main.rs:1333`) | `Json.signatures` (`:1983-1987`) | yes |
| 10 | OBSERVATION_ASSEMBLE | `pair(challenge, signatures)` (`main.rs:1334-1336`) | `splitPair` plus codecs (`:1988-1994`) | yes |
| 11 | CALL_ASSEMBLE | `pair(plan, signatures)` (`main.rs:1337`) | (`:1995-2001`) | yes |
| 12/13 | FN_POLL / FN_ACK / `fnDispatch` | empty / canonical decimal transaction (`main.rs:2704`, `:2861`) | fnDispatch, not read; the broker restricts bodies (`transport.rs:73-86`) | not settled (Q6) |
| 14/15 | FN_REPLY_POLL / ACK | same | same | not settled |
| 16 | FN_ORIGIN_OUTBOX | carrier bytes ≤ 1,516,384 (`main.rs:2931-2940`) | fnDispatch | not settled |
| 17 | PROVIDER_CONTINUITY | `provider_continuity::request_payload(call, outcome)` (`main.rs:3113-3114`) | fnDispatch | not settled |
| 18 | FN_ORIGIN_OUTBOX_EXPORT | decimal transaction (`main.rs:2981`) | fnDispatch | not settled |
| 112 | PAY_ENROLLMENT_VIEW | empty, envelope **v1** (`main.rs:3137`) | fnDispatch | not settled |
| 130 | AFFORDANCE_DRY_RUN | `pair(signed observation, signatures)` (`main.rs:1338-1340`) | `DryRun.dryRunLoaded`; `.stopped` becomes `255 outcomeCodec` (`:2067-2075`) | yes |
| 144 | KEY_ROTATION_STATUS | through `key_rotation::status_if_enrolled` (`main.rs:333`) | fnDispatch | other shard |
| 150 | LAW_SAT | law request bytes (`main.rs:1341`) | `LawSatWire.lawSatSession` (`:2076-2078`) | yes |

What the Lean side puts under 255 (`Host/Main.lean:2646-2654`, `Host/RequestRefusal.lean:66-72`):
1. an explicit `refusalFrame` outcome (`refused`, phase prepare or observation);
2. `outcomeCodec.encode (.unavailable "host session reopening")` when the session was invalidated by the error;
3. for any other `IO.Error`, `refused operationRejected` with phase `op N` and the exception text, or `refused malformed` / `refused overBound` for tagged errors.

So 255 does **not** always mean refused (case 2), and a generic `refused operationRejected` can come from an I/O failure in the handler (case 3). Section 4, F1 has the consequences.

### 1.5 `src/shell.rs` (4,306 lines; code 1-3161, tests 3162-4306)

**Purpose and contract** (`shell.rs:1-25`). This is a line-oriented session bound to one workspace and one session HOME. "Every verb is exactly one client-contract operation." Exit codes: 0 done, 1 client, 2 usage, 3 refused by the Host, 4 Host outcome not a decision.

**Session HOME layout** (doc comment `:11-21`, plus code): `keys/`, `enroll/NAME/`, `keys/NAME.pub`, `requests/`, `inbox/`, `refusals/`, `provision/birth-context.json`, `namespace/`, `outbox/`, `channels/`, `concierge/NAME.json`. All folders are created owner-private from a held descriptor (`admit_session_paths`, `:2532-2555`, through `session_fs::private_folder`).

**Verb table** (`VERBS`, `:54-107`, 52 rows). `command_catalog()` chains in `chat::VERBS`, `hermes::VERBS` and `story::VERBS` (`:111-113`). Help and completion derive subcommands from the usage strings (`subcommands_after`, `:120-134`).

**Line grammar** (`words`, `:894-983`). Whitespace separates words. `'…'` is literal. `"…"` honours `\"` and `\\`. A word that starts with `{` or `[` is one JSON value up to its balancing bracket (string-aware) and must be followed by a space or the end of the line. `#` at the start of a word begins a comment. There is no expansion.

**Names and arguments.**
- `workspace_name`: 1..64 `[A-Za-z0-9-]` (`:990-998`).
- `ref_name` delegates to `workspace::validate_ref_name` (`:1003-1006`).
- `session_file`: a plain name with no leading dot (`:1013-1026`).
- `@FILE` always means `HOME/requests/FILE`, read through `session_fs::read` with bounds: 4 KiB text, 8 KiB key declaration, 1 MiB JSON or law (`:731-745`, `:780-790`, `:1044-1076`).

**`plan()`** (`:1131-2370`) is pure apart from reading `@FILE`s and `workspace.json`. It returns a `Plan` (`:853-886`): `Client{command, flags, writes}`, `Whoami`, `Inbox`, `Guide`, `NotHere`, `Export`, `Rooms`, `Template`, `Text`, `History`, `Help`, `Chat`, `Story`, `Exit`, `Nothing`. Chat and story lines are tried first (`:1132-1137`).

How each verb is implemented:

| Verb(s) | Plan | Forwards to |
|---|---|---|
| `app status`, `home` | Client | `mini member` (`:1154-1195`) |
| `app delegate-lifecycle …` | Client | `workspace --action app-lifecycle` |
| `whoami`, `inbox`, `history`, `room list`, `room template list/show`, `export`, `help`, `exit` | local | **computed in Rust from local files**, labelled "authority: discovery-only" (`:2618-2761`) |
| `keygen` | Client | `mini keygen --hosted yes` into HOME/keys (`:1600-1612`) |
| `init` | Client or `NotHere` | `workspace --action init` with the delivered birth context and HOME/namespace (`:1613-1646`) |
| `enroll plan/seal/offer/submit/lookup/welcome` | Client | `mini enroll`; hex key words become files written into HOME (`:1647-1744`) |
| `provision` | Client | `workspace --action provision` |
| `refs`, `read`, `describe`, `import`, `can`, `inspect`, `why` | Client | the corresponding `workspace --action` |
| `create`, `create --from` | Client | `workspace --action create` / `instance-create`; the law is spelled by `law_argument` (`:2104-2139`) |
| `kind *`, `program create`, `instance *` | Client | `workspace --action kind-* / program-create / instance-*` |
| `propose`, `invoke`, `delegate`, `revoke`, `renounce` | Client | `workspace --action propose` with a request JSON **spelled by the shell** (`:1211-1239`, `:2140-2174`) |
| `law ID REF TEXT` | Client | `propose` an `install-policy`, with consent flags `--allow-unsatisfiable`, `--i-lock-myself-out`, `--freeze-roster` (`:2275-2313`) |
| `law check`, `law show`, `law export` | Client | `workspace --action law-check / law-show / law-export-show`, `propose install-export` |
| `market *`, `bid`, `reveal`, `bids` | Client | `workspace --action market-*` |
| `submit`, `lookup`, `retry`, `publish` | Client | `workspace --action submit --attempt attempts/ID`; `recover`; **`mini retry --mode submit`**; `publish-delegation` (`:2314-2362`) |
| `doc *` (30 forms) | Client | `workspace --action doc-*`, `mark`, `unmark`, `transclude`, `follow`, …; `append/edit/link/annotate` become `propose` with `{"type":"document"}` actions (`:1256-1477`); element-tree verbs go through `doc_render::doc_flags` |
| `board new/add/move/take` | Client | `workspace create` with the **Rust-authored `board_law`**, or `propose` scalar actions; field = 2·task+2 or +3 (`:1478-1551`) |
| `room new/invite/kick/seal/rotate/transition/register/rewrap/keys/leave/members/law/status/renew/concierge/index/bind/rename/unbind/resolve/welcome` | Client or Template | `workspace --action create / room-key / room-kick / shared-name / who / describe`, `credit --action …` (`room_plan`, `:265-701`) |
| `forget` | Client | `workspace --action room-key --op forget` |
| `job`, `jobs` | Client | `mini job` |
| `channel` | Client | `mini channel` |
| `pay`, `credit`, `tariff`, `topup` | Client | `mini credit` / `mini pay` |
| `key-status`, `adopt-next-key`, `rotate-key` | Client | corresponding commands |
| `key` | Client | `keys::shell_plan` |

**Verbs that compute something locally.** The discovery-only verbs listed above, plus the **law and template authoring**: `document_law("draft"|"note"|"index")` (`:147-162`), `room_law("open"|"private"|"realm")` (`:172-187`), `board_law()` (`:709-719`), the default invite verbs `observe,place` and default `maxCost 50000` (`:428-433`), and the board field arithmetic (`:1482-1489`). None of these answers a Host question. They are policy content that the Host then enforces as written.

**Execution** (`execute`, `:2557-2611`):
1. confine every path;
2. write each request file exactly once; an identical repeat is idempotent, a different one is refused (`write_once`, `:2483-2491`);
3. clear the thread-local slots;
4. call `super::run(args)` **in the same process** under `catch_unwind`;
5. print `(re-planned N×)` if a replan happened;
6. classify the result: `Done`, `Client`, `Host{…}` or `LineRefused`.

A refused frame is retained under HOME/refusals and decoded by the Host's own `inspect outcome` (`decode_refusal`, `:2495-2518`).

**Rendering** (`render`, `:2432-2477`). Every non-success line starts with `usage:`, `error:`, `refused:` or `undecided:`. `HostDecision::Outcome` takes its code from the outcome type (refused 3; uncertain, unavailable, contention, absent 4; `outcome_line`, `:2407-2427`). **Every `RefusedFrame` gets code 3**, whatever the decoded outcome type (`:2452-2468`).

**Terminal and entry.** `Raw` switches the terminal with `stty -icanon -echo -isig` and restores the three flags by name (`:2957-2978`). `read_line` (`:2993-3084`) supports backspace, Ctrl-U, Ctrl-C, Ctrl-D, Tab and Up/Down history. `run` (`:3088-3160`):
1. require an absolute `--workspace` and `--home`;
2. take `--host`/`--config`, or derive them from a remote workspace's pin;
3. require a socket;
4. run one `--line`, a tty loop, or a stdin script (which stops at the first non-zero line);
5. finish with `std::process::exit(code)` (`:3159`).

### 1.6 Shell children

**`shell/session_fs.rs`** (218 lines; tests 109-185). This is descriptor-anchored path confinement, explicitly "not same-UID process isolation" (`:1-3`).
- `parent()` walks the components with `openat(O_DIRECTORY|O_NOFOLLOW)` and refuses `..` and absolute paths (`:16-33`).
- `confined()` accepts an absent leaf, a regular file or a directory, and refuses symlinks, FIFOs, sockets and devices (`:42-59`).
- `read()` opens the leaf `O_NOFOLLOW|O_NONBLOCK` and bounds its size (`:61-75`).
- `private_folder()` runs `mkdirat 0700` and checks ownership and mode (`:82-107`).
- `replace()` writes a temp file, fsyncs it and `renameat`s it under the held descriptor (`:190-218`). Its only caller in this shard is the test `atomic_replacement_retains_foreign_bytes_during_leaf_swap` (`:114-142`); other modules may call it (`pub(crate)`).

**`shell/doc_render.rs`** (251 lines; tests 180-251). `doc_flags` maps `doc show/history/diff/pull/range/outline/backlinks/links/transclusions/mark/unmark/insert/move/remove/transclude/follow` word vectors to `workspace` flags (`:13-178`). Line numbers must be ≥ 1 (`number`, `:15-21`). Mark kinds are restricted to five (`:101-103`).

**`shell/template.rs`** (289 lines; tests 159-289).
- Room templates are shell-line files compiled in with `include_str!` from `deploy/shell/templates/room/{workroom,social,story}/` (`:25-41`).
- `source` resolves a built-in or `@FILE`. Note that `@FILE` is read with **plain `fs::File::open`** (it follows symlinks), not `session_fs::read` (`:78-92`).
- `bind` substitutes `$NAME` placeholders and refuses unknown ones (`:97-132`).
- `shell.rs` `template_plan` (`:192-212`) plans every line before any runs and forbids nested templates.
- `run_template` stops at the first line that does not end `Done`; the lines before it stand (`:217-234`).

**`shell/law.rs`** (666 lines; tests 416-666). The one-line law grammar (header `:5-24`) compiles to the Host's `Pred` JSON. Tokens (`:79-149`) include canonical signed decimals of any width. The recursive-descent `Parser` (`:151-405`) produces `all/any/not/ran/monotone/writeOnce/eq/le/memberOf/eqSlots/leSlots/leSlotsOff/hashEq`. Verb names map through the hard-coded `VERBS` table: read 1, write 2, delegate 3, install 4, revoke 5, append 7, place 10 (`:59-67`). It refuses a `witnessed` clause (`:255-258`) and `monotone`/`writeOnce` on non-`after` views (`:369-375`). The test `job_law_grammar_is_the_template_json` checks the grammar against `deploy/shell/templates/job/law.job.{shell,json}` (`:620-637`); the comment says the `.shell` side is written by `scripts/gen-joblaw.py`. `host_renderings_parse_back` (`:513-534`) asserts sample strings in the Host's rendering parse back. It uses hand-typed samples, not Lean output.

### 1.7 `src/workspace.rs` (8,795 lines; code 1-7083, tests 5242-5245 and 7084-8795)

**Role** (`:1-3`). Participant-owned references and custody over the Mini client: "A reference is a discovery hint. Every read and operation still goes through the signed observation, current Plan, and Lean admission."

**Submodules declared here.** The files I read are `web_author`, `studio` (with `studio_preview`) and `web_create`. The others belong to other shards: `app_document`, `doc_search`, `context_projection`, `private`, `roomkey`, `content_privacy`, `protected_format`, `protected_document`, `can`, `inspect_views`, `lawsat`, `world_kind`, `world_surface`, `world_prototype`, `law_export`, `app_lifecycle`, `shared_names` (`:5-79`, `:725-726`).

**On-disk layout of a workspace ROOT** (created by `init_impl`, `:611-616`, and by the actions):

| Path | Written by | Contents |
|---|---|---|
| `workspace.json` | `init_impl` `:633-654`; `record_next_public` `:439-447`; `receipt_continuity` | type `minidregg-participant-workspace-v1`; host (or null), hostSha256, config, key, subject, socket, sshIdentity, birthContext, namespaceRoot, enrollment, localConsent, prerotation, nextPublicKey, receiptContinuity/freshContinuity |
| `refs/NAME.json` (with `/` written as `.`) | `import_complete` `:806-825`; `complete_birth` `:4159-4170` | type `minidregg-participant-reference-v1`; kind (object, account, program), target, observe/operation/control capability, provenance (birth receipt and reservation), `authority: "hint-only"`, room, sealedIn/sealedRoom, private |
| `enrollment.json`, `birth-context.json` | `init_impl` `:617-632` | retained copies |
| `namespace/` | `namespace_root` `:231-246` | Rust ID reservations (`participant_namespace`) |
| `sources/q-NONCE.json`, `qb-NONCE-N.json` | reads `:1012`, `:1344` | query intents |
| `sources/create-NAME.request.json`, `create-NAME.json`, `create-NAME.authoring/gNNNN/` | `birth` `:4515-4681`, `author_generations` `:4381-4459` | birth request (with nonce), birth source, op91 authoring generations (`factory-observation.bin`, `reply.frame`, `source.json`, `released.json`) |
| `sources/create-NAME.handoff.json` | `create_funded_account` `:4963-4968` | sponsor handoff |
| `sources/kick-ID.json`, `transclude-*.json`, `{label}-NONCE.json` | `room_kick`, `transclude`, `submit_content` | requests |
| `proposals/ID/` | `propose_summary_once` `:3533-3558` | `request.json`, `intent.json` (Rust-built), `intent.bin` (Lean-authored), `proposal.json` (summary with `intentSha256`), optional `append-origin.json`, `companions.json`, `recipient-reference.json`, `append-attempt.json`, `append-submit.lock` |
| `attempts/a-NONCE/`, `attempts/ID/`, `attempts/create-NAME/`, `attempts/create-NAME.released-NNNN/`, `attempts/web-create-ID/` | `main.rs` pipeline | `attempt.json`, `config.json`, `intent.json`/`intent-source.bin`, `intent.bin`, `intent-signature.bin`, `challenge.{bin,json}`, `observation-signatures.{json,bin}`, `signed-observation.bin`, `plan.{bin,json}`, `transaction-signatures.{json,bin}`, `call.bin`, `outcome.{bin,json}`, `retry-NNNN.{bin,json}`, `replanned/NN/`, `refusal.frame`, `view.{bin,json}`, `stale-probe.view` |
| `seen/NAME.json` | `retain_seen_value` `:5247-5258` | the "as I last read it" snapshot (type `minidregg-workspace-seen-document-v2`, up to 16 MiB, `:5504`) |
| `read-journal.tsv` (+`.1`) | `read_journal` `:938-957` | one line per ephemeral read, rotated at 1 MiB |
| `provisions/NAME/` | `provision` `:5005-5078` | `observe/`, `birth-context.json`, `provision.json` |
| `web-creates/ID/`, `web-creates/name-NAME.json` | `web_create.rs` | browser creation custody |
| `web-edits/ID/` | `web_author.rs` | browser edit custody |
| `studio-packages/ID/` | `studio.rs` | Studio drafts, compositions, captures, previews |

**What it caches of Lean's state.**
1. `seen/NAME.json`: a full signed resource view, the Host's `view-document` and the read coordinates. Later `doc edit`, `doc annotate` and `doc push` name lines against this snapshot (`document_actions`, `:5306-5426`; `read_seen`, `:5506-5516`). The Host refuses a stale edit (`staleAtom`, `staleElement`), so the snapshot is a base, not an authority.
2. `refs/*.json`: target, capability IDs, room membership and sealing context, all labelled hint-only.
3. Proposal summaries record the reserved child capability (`:3423-3429`). `delegated_capability` (`:6139-6163`) and `delegations_from` (`:3867-3899`) reconstruct "what I delegated" from them. `revoke` without `capability` trusts this local record (`:3454-3460`); the Host still checks the revocation.
4. `workspace.json` `hostSha256`: a pin that stops later processes from hashing the Host image (`main.rs:185-193`).

**Read path.** `read_reference` (`:983-1056`) builds the query intent itself (`{subject, nonce, purpose:{type:"query", kind, target, view}, grants:[…observeCapability]}`), retains it, calls `query_retained` and adds `judgedAt` from the challenge. In ephemeral mode it removes the attempt and source and keeps one journal line. `signed_views_mixed` and `signed_read_batches` (`:1186-1314`) batch up to 16 reads, add the shared-name guard reads and refuse mixed images (`check_read_coordinates`, `:1306-1314`).

**Proposal preparation** (`propose_request` → `propose_summary_once`, `:2921-3560`). `replan` re-runs the authoring when the reads disagree (`OBSERVATIONS_MOVED`, `:2875-2876`, `:2929-2934`). The action arms:
- **invoke** (`:2986-3194`):
  1. validate the shape (1-16 named targets, an optional `run` claim, an optional `family` with a hard-coded route allowlist, `:287-288`);
  2. resolve the references and take signed `resource` views of every target in one image;
  3. check `expectedTargetRoot` and `expectedObserveCapability` pins (`:3045-3051`, `:3069`);
  4. lower each payload (`stream_append`, `scalar_actions`, `content_actions`, `document_actions`, `world_kind::*`, `protected_format::lower`, private sealing);
  5. pick the operation or observe capability;
  6. set `schemaVersion` (`invocation_schema_version`, `:266-275`), `expectedTargetRoot` from the signed root, and a fresh command nonce;
  7. produce the intent `{subject, nonce, purpose:{type:"prepare", draft:{type:"invoke", command}}, grants}`.
- **install-policy / install-export** (`:3195-3215`): signed policy view, `expectedPreRoot` = the authority root, `expected` = the current policy version and address, a fresh nonce.
- **delegate** (`:3216-3438`): signed resource, policy and parent-capability views in one image. Pre-checks: the parent covers the target, the parent holds `delegate`, the verbs are within the parent and include `observe`, `maxCost ≤ parent`, `notBefore = max(parent.notBefore, height) ≤ parent.notAfter`, an optional `notAfter` within the window (`:3281-3347`). Then reserve or probe the child ID (`:3362-3386`) and build the full child capability record (`:3394-3422`).
- **revoke** (`:3439-3477`), **renounce** (`:3478-3523`).

Then the client writes `request.json` and `intent.json`, and **Lean authors `intent.bin`** with `author intent` (`:3546-3552`).

**Consent.** Signing consent is checked locally by `client_consent::{intent, observation, plan}` (`main.rs:1815`, `:1827`, `:1979`) against a local native Host ("Local native consent over a warm independently admitted source prefix", `client_consent.rs:1-12`). "Thin consent" mode (`MINI_THIN_CONSENT=1`) adds signed resource reads of every target before signing (`thin_views`, `workspace.rs:3684-3721`). Lean remains the admission gate. The docs/DEVELOPING.md:99-102 "consent" story ("Repeating the same method proposal ID retains its intent and consent") is implemented by the proposal directory plus the `write_once` request file in the shell. `propose_summary_once` itself uses `create_private` (create-new), so re-proposing an existing ID fails (`:3534-3545`) unless `law_export::retained` short-circuits (`:2973-2975`).

**Submit** (`submit_intent`, `:3562-3677`):
- An explicit `--attempt` must be an unused direct child of `attempts/` (`:3580-3591`). Otherwise a fresh random `a-NONCE` is allocated (`:3592-3594`).
- Delegation proposals are bound to exactly one attempt through the namespace (`bind_delegation_attempt`, `:3936-4004`).
- **Append recovery path** (`:3599-3657`), only for an unpinned single-target `document` request whose actions are all text `append` (`append_request_name`, `:3772-3787`). One durable `append-attempt.json` binds the proposal to one attempt before anything happens (`bind_append_attempt`, `:3723-3767`), and a lock is held (`:3574-3577`). The loop:
  1. `submit_once`;
  2. on stale-root, or on a decoded final refusal at phase `admission` with `call.bin` present, or on a prepare `staleTarget` refusal (`replan.rs:109-129`), an **independent signed read** checks whether the document root changed (`append_preimage_moved`, `:3827-3847`);
  3. if it changed, retire the old call into `replanned/NN`, author a **new derived proposal** `append-NONCE` with a fresh nonce (marked `append-origin.json`, so it cannot be submitted alone, `:3795-3799`), check it carries the same subject, target, capabilities and text (`check_append_successor`, `:3816-3825`), and submit it in the same attempt.
  
  Stdout carries only the final outcome (`:3651-3656`).
- Otherwise it calls `main::submit` (stale-root replan only) and prints a renounce note.

**Recover** (`recover`, `:4006-4014`) is **lookup only** on the exact retained call. `retained_attempt_outcome` and `accepted_outcome` (`:4019-4050`) use the SDK's `AttemptDir::standing` (a confirmation wins; otherwise only the newest outcome or retry decides) plus `receipt_continuity`.

**Birth / create** (`birth`, `:4463-4806`):
1. reject unsupported storage and kind combinations;
2. retain an immutable create request with a random nonce, or require byte equality on resume (`:4535-4551`);
3. reserve target, owner and control IDs in the namespace (`:4570-4577`);
4. compose funding and source capabilities from the birth context (`:4578-4616`);
5. **derive the cell blinding from the member seed** (`:4646-4653`);
6. retain the birth source;
7. if a prior attempt is "definitely unadmitted" (no `call.bin`, or the newest outcome is `refused`, `:4308-4316`), release it (mark the authoring generation released, unbind the namespace, rename the attempt to `.released-NNNN`, `:4323-4367`);
8. author through op91 generations (`author_generations` with `current_birth::author`, superseding refused or released generations, stale-root probes through `observation_stale`, bounded by `--replan-max`; `:4381-4459`);
9. bind the namespace to the exact intent SHA (`:4768-4774`);
10. if an attempt exists, take the `accepted_outcome` or run an exact lookup (`:4775-4789`); otherwise `submit` the Lean-authored binary intent (`:4795-4805`).

`complete_birth` (`:4121-4176`) writes the reference only after a confirmed receipt whose resources match the reservation.

**Documents** (`:5131-5945`): `content_page` and `cell_storage` infer the storage kind from the JSON shape (`:5149-5181`); `atom_record` builds the exact `before` record; `pulled_lines`/`pull_text`; `line_diff` (Wagner-Fischer, ≤ 2048 lines a side, `:5634-5677`); `TreeModel` (a Rust model of containers and revisions, `:5683-5758`); `push_actions` (≤ 64 KiB, ≤ 64 actions, `:5771-5840`); `stale_lines` (after a refused push, which pinned lines changed, `:5844-5885`); `doc_push` (`:5887-5945`). Other actions: `place_new_leaf`, `move_line`, `doc_range`, `doc_insert`, `doc_move`, `doc_remove`, `mark`, `unmark`, `transclude`, `rendered_document` (Host `view-document` over this workspace's own reads, historical re-reads for snapshots, `:1794-2001`), `doc_history` and `doc_diff` (Host-rendered from `since` and `at` reads, `:2567-2606`).

**Rooms**: `sealing_a_room` (`:5954-5978`) refuses a law that admits nothing on a room cell without `--freeze-roster`. `frozen_roster` rewrites an error that **contains the prose** `law-denied` and `sealed` (`:5982-5991`). `standing_grants` reads the Host's signed `who` view (`:5997-6009`). `room_kick` issues one revoke per standing grant, with companions submitted in turn (`:6046-6122`), and `kick_remaining` re-reads `who` (`:6127-6137`).

**`run`** (`:6165-7082`) dispatches 76 `--action` values (75 match arms plus `init`, handled first at `:6168`): init, onboard, the continuity family, shared-name, import, list, doc-*, describe/read, who, tail, room-key (16 ops), submit, room-kick, transclude, doc-search*, doc-context, context-review, can, inspect, law-check, propose, law-export-show, program-create, instance-*, kind-*, create, provision, provision-lookup, recover, publish-delegation, doc-share/revoke/membership-recover/accept/device/epoch-*/protect*, doc-new, doc-range, doc-pull, doc-push, law-show and market-*. The error message listing the valid actions (`:7078-7080`) names only 42 of them; it is stale.

### 1.8 Studio and browser custody

**`workspace/studio.rs`** (602 lines; tests 539-602). It keeps a local draft of an Objective Bend package composition: `studio-packages/ID/draft.json` with type `mini-studio-package-draft-v2`; v1 refuses (`:16-17`, `:162-164`).
- `Manifest::parse` checks the exact keys, 1-256 modules, distinct names, imports only to earlier modules, and that only `Base` may have an empty alias (`:66-129`).
- `create`, `save_manifest` (revision CAS, history `composition-{n}.json`), `compose` (add-module, entry, add-import, remove-import), `manifest_version`, `fork`, `retain_submission` (keeps a malformed or stale submission), `projects`.
- `editor` opens a `web_author` edit session on a module's document (`:424-461`).
- `snapshot` reads every module with a fresh signed read at **one coordinate** (`check_read_coordinates`), writes `module-N.bend` and `package-input.json`, and records `"producer":"unavailable","publication":"unavailable"` (`:465-520`).

There is no publication path; the README row agrees.

**`workspace/studio_preview.rs`** (222 lines; tests 189-222). It is enabled only by `MINIDREGG_STUDIO_PREVIEW_CONFIG`, a JSON file `{schema: mini-studio-preview-tooling-v3, host:{path, sha256}}` (`:10`, `:27-34`).
- `run` validates the typed arguments: ≤ 16 values, depth 8, budget 256 (`:35-52`).
- It re-reads every captured module's document (`admitted_capture`, `:56-65`).
- It runs `timeout --kill-after=2s 45s HOST /dev/null objective-front capture …` and then `… preview …` (`child`, `:66-77`).
- It validates the capture and result bindings against hashes (`:78-109`) and retains everything under `previews/RUN/` (`:110-147`).

**`workspace/web_create.rs`** (424 lines; tests 366-424). Browser document creation runs as two exact operations: the birth (`attempts/create-NAME`) and `createDocument` (`attempts/web-create-ID`).
- `open` makes a session; with a room it does a signed read of the room (`:33-52`).
- `submit` takes a lock, claims the name (`web-creates/name-NAME.json` plus refs and sources checks), writes `started.json`, takes the law from **`crate::shell::document_law`** (`:237`), then calls `create` and `initialize`.
- `lookup` runs an exact recover on any attempt holding `call.bin` and no outcome, and rebuilds the reference only through `create` after a confirmed birth (`:317-364`).
- `record_error` labels the result `refused` whenever a `HostDecision` is recorded (`:181-193`).

**`workspace/web_author.rs`** (494 lines; tests 334-494). Each browser tab keeps its own signed base in `web-edits/ID/session.json` (`:40-72`).
- `submit_operation` takes a lock, writes `started.json` before anything is read or sent, plans either a whole-text push (`push_actions`) or a structured action (`web_actions::plan`), then proposes and submits into a fixed attempt (`:168-228`).
- A repeated POST with the same text only reads (`:179-185`).
- `lookup` performs exact recovery only (`:295-332`).
- Errors are labelled `refused` when any `HostDecision` was recorded (`:229-249`).

**Reachability.** All four are reachable only through `mini web --dir WS --listen 127.0.0.1:PORT` (`main.rs:3213`; `web.rs:52-65` binds loopback only; Studio routes at `web.rs:603-604`, `:629-637`; create at `web/create.rs:6-54`; editor at `web/editor.rs:88-117`). `jweb.sh` launches `mini web` (`journey.d/jweb.sh:96`, `:135-139`) but no journey touches `/studio`. No systemd unit runs `mini web`. This is consistent with the README Honest-state row "no member-reachable route".

### 1.9 Processes, sockets, files and environment touched by this shard

- **Child processes**:
  - `minidregg-host CONFIG …` (`local_process`, `main.rs:1246-1270`; `store_run` `:1218-1221`; `selected_release_sign`);
  - the local codec Host child (`client_consent`);
  - `stty` (`shell.rs:2961-2976`);
  - `timeout` plus the Host `objective-front` (`studio_preview.rs:71-75`);
  - `ssh` through `MINI_SSH` (transport, other shard).
- **Sockets**: the Unix socket of `mini serve` (client side); serving lives in `transport` (other shard).
- **Environment variables**: `MINI_VERIFY_HOST` (`main.rs:570`), `MINI_AUDIT_TIMING` (`:1252`), `MINI_REPLAN_MAX` and `MINI_REPLAN_LOG` (`replan.rs:73`, `:199`), `MINI_KEYCACHE_PASSPHRASE` (adopted and removed, `private.rs:73-89`), `MINIDREGG_STUDIO_PREVIEW_CONFIG` (`studio_preview.rs:10`), `MINI_LOCAL_HOST`, `MINI_THIN_CONSENT`, `MINI_CONSENT_*` and `HOME` (`client_consent.rs:51`, `:105-162`, `:267`, `:377`, `:463`).
- **Fixed path**: `/usr/local/lib/mini/FRIENDS.md` (`shell.rs:141`).

---

## 2. What it assumes of its surroundings

**Host protocol operations.** See the table in 1.4. Ops 0-11, 130 and 150 were checked against `dispatchSession`, `pureCodec`, `splitKind` and `splitPair`; byte layouts agree. Ops 2, 3, 12-18, 112 and 144 go to `fnDispatch`, which I did not read (Q1, Q6). The registry (`protocol/host-operations.json`) lists all the bytes used, with `routes ["public","operator"]`. `main.rs` does not use the generated constants (`native/host-operations.rs`), so a reallocation in the registry would not reach these literals (section 5).

**OS facilities.**
- Unix-only for almost everything (`#[cfg(unix)]` on 61 modules; `socket_process` non-unix returns an error, `main.rs:1385-1393`).
- `libc::openat`, `fstatat`, `mkdirat`, `renameat` and `O_NOFOLLOW` (`shell/session_fs.rs`); fsync of files and directories (`main.rs:1411-1416`).
- `stty` for the interactive shell (`shell.rs:2961`).
- GNU coreutils `timeout --kill-after` for Studio preview (`studio_preview.rs:71-72`); absent on stock macOS.
- No bwrap, seccomp, cgroups or SO_PEERCRED in this shard (peer UID lives in `transport.rs:1944-1996`, other shard).

**Network services.** None directly in this shard. fn/NNTP, Solana and providers are reached by other modules that `main.rs` dispatches to (`publisher`, `worker`, `join_solana*`, `meter`).

**File layouts and config.**
- The pinned config JSON (bytes are compared exactly by the broker).
- `workspace.json` and the layout in 1.7.
- The birth context (`minidregg-participant-birth-context-v1`, `workspace.rs:4512-4514`).
- The enrollment result (`minidregg-participant-enrollment-result-v1` with `authority: "admitted-key-only"`, `:510-514`).
- Attempt manifests (`minidregg-resource-client-attempt-v1`, `main.rs:1738`, `:2403`).
- Worker pins (`minidregg-{b-consumer,a-reply-consumer}-worker-pin-v2`, `main.rs:620-623`).
- Room templates compiled from `deploy/shell/templates/room/*` (`shell/template.rs:25-41`); job law files for a test (`shell/law.rs:622`).
- The test `content_invocation_version_matches_source_admission_contract` reads `Kernel/ContentResource.lean` at compile time with `include_str!` (`workspace.rs:7207-7210`).

**Other crates.** `mini-sdk` (hex, decimal, lock `Lease`, `store::AttemptDir`, `custody::Standing`, `private::*`, `signer`), `minidregg-mini-keys`, `minidregg-pay-watcher`, `compatible-upgrade-custody`. Binaries: `minidregg-host` (Lean), plus the SQLite Store and signature helpers named by the config (outside this shard).

**Remote clients need a local Host.** `--remote` participants are told their workspace "has no Host image" (USAGE `main.rs:833-834`). Yet the pure codec operations (author, inspect, signatures, assembly, and the decoding of every 255 frame) need a local Host image from `MINI_LOCAL_HOST` or the consent pins (`client_consent.rs:50-56`). A friend running `mini --remote` therefore needs a local `minidregg-host` build. Neither USAGE nor this shard's README says so.

---

## 3. Does it decide anything semantic?

I separate **mirrors** (Rust pre-checks what Lean refuses anyway) from **decisions** (nothing on the Lean side refuses if Rust gets it wrong).

### 3.1 Decisions (violations or near-violations of ATLAS §7, "Authors nothing")

| # | Site | What Rust decides | Lean counterpart that should own it | Blast radius if wrong |
|---|---|---|---|---|
| D1 | `shell.rs:147-162` `document_law`; `:172-187` `room_law`; `:709-719` `board_law` | The **content of laws** installed on documents, rooms and boards ("draft" = payload ≤ 16384 on mutate; "note" = no edits or tombstones; "realm" = only founder and referees may `place`; board = monotone state, write-once owner on fields 2-5). Lean enforces whatever JSON these build. | Lean-emitted law templates, as the job law already is (`deploy/shell/templates/job/law.job.{shell,json}`, generated by `scripts/gen-joblaw.py`, `law.rs:616-619`) | Every room, document and board created by the shell or web (`web_create.rs:237` also uses `document_law`) carries a Rust-authored policy. A typo silently changes who may write. Law 13: "emit, never imitate". |
| D2 | `shell/law.rs:59-67` `VERBS` | The meaning of `verb == write` and the others as numeric tags. It is a hand-copy of `CredentialAuthorityEntryCodec.verbTag`. | That Lean codec, as an emitted table | A drift silently compiles `verb == place` to a wrong tag, so the law means something else. Only hand-typed samples test it. |
| D3 | `shell/law.rs:79-405` the whole grammar | Parse-direction twin of Lean's `Compiler/RefusalReason.lean` `renderClause` (cited `law.rs:43-55`) | A Lean parser for the same grammar (or emit `Pred` JSON only from Lean) | A mismatch between what `law show` prints and what `law` installs |
| D4 | `workspace.rs:2791-2820` `sealing_room`, `:2867-2870` `holds_sealed`, `:3075-3094`; `:878-887` `require_room_member` | **Whether a write to a private-room cell is encrypted**, and whether an imported document's sealing context is retained. Lean has no law that refuses plaintext into a private room's cell. | A room law clause or Kernel check that a private room cell only accepts sealed atoms, if privacy is meant to be enforced; otherwise accept it as Rust-owned crypto custody. Private rooms are labelled "DEVNET QUALITY; PRIVACY NOT AUDITED" (`main.rs:700`). | A plaintext leak into a private room if the local refs are wrong |
| D5 | `workspace.rs:4308-4342`, `:4707-4713` `attempt_definitely_unadmitted` and `release_unadmitted_attempt` | That a birth attempt whose newest outcome is `refused` is definitely unadmitted, so a **new** birth intent may be authored | A Lean-side definitive statement: lookup op 3 answering "absent / never admitted" for the exact call | Backstopped: the same reserved target ID makes a second birth collide (`:4570-4577`, `:4628`). Without that backstop, funded births (`create_funded_account`, `provision`) would double-fund. |
| D6 | `workspace.rs:3599-3657` append recovery, with `replan.rs:109-118` | That a decoded `refused` at phase `admission` (hex `61646d697373696f6e`), plus a moved root, licenses a **new** append proposal and call | A Lean theorem that a `refused` outcome at admission implies no event was appended | Section 4, F2. Guarded by the phase string, so the generic `operationRejected` answer (phase `op N`, `RequestRefusal.lean:66-72`) cannot trigger it. |
| D7 | `participant_namespace::reserve` from `workspace.rs:3364-3374`, `:4570-4577` | **Fresh resource and capability IDs** (random 63-bit draws, per `workspace.rs:226-230`) | Lean is "the final collision and authority checker" (README `:153`) | A collision is refused by Lean, so this is a mirror in effect. But Rust authors identifiers. |
| D8 | `workspace.rs:4646-4653` | The cell **blinding** (K-NARROW-HIDE) from the member seed | Physical key custody; acceptable as Rust's job | If wrong, the owner cannot recompute salts for its own fields (`hiding::verify_view` would fail on reads) |
| D9 | `workspace.rs:266-268` `CONTENT_COMMAND_VERSION = "10"`, `SCALAR_COMMAND_VERSION = "1"`; `:287-288` family routes; `:2625-2635` delegation field names | Hand-copied Kernel constants. Only the content version is test-guarded against `Kernel/ContentResource.lean` (`:7204-7218`). The comment at `:3178-3181` still says "(9)". | Emitted constants | Lean refuses mismatches, so a stale value refuses loudly (mirror-safe), but these are twins |
| D10 | `workspace.rs:5162-5181` `cell_storage` | Infers content, declared, stream or world storage **from JSON shape**, and picks `document` vs `mini:KIND/ID` link targets (`:5410-5417`) | A typed storage field in the Host's view JSON | A wrong link record type. Lean may accept either (unknown, Q9). |

### 3.2 Mirrors (Lean is still the gate; listed for completeness and UX accuracy)

| Site | Mirror |
|---|---|
| `workspace.rs:3281-3347` | Delegation descent pre-checks: target coverage, `delegate` verb, verbs ⊆ parent, maxCost, lifetime window. Lean's `CapabilityDelegationController` re-checks (cf. `refusal_hint`, `main.rs:425-432`). |
| `workspace.rs:108-120` | Requiring `observe` in workspace delegations is **stricter** than Lean (README `:115-117`). It fails closed. |
| `workspace.rs:5954-5978`, `workspace.rs:6794-6799` with `lawsat::install_check` | The refusal of unsatisfiable or self-lockout laws and of sealing a room without `--freeze-roster`. Satisfiability itself is asked of the Host (op 150). The decision to refuse is a client consent gate, stricter than Lean. |
| `workspace.rs:2041-2138`, `:5683-5840` | Line numbering and element-tree edit planning. Every edit names the container revision it read, so Lean refuses stale ones (`staleElement`, `staleAtom`). |
| `workspace.rs:2880-2889`, `:3045-3051` | Explicit caller pins compared to fresh signed reads before authoring |
| `main.rs:2644-2684`, `:2774-2844`, `:2882-2922`, `:3048-3091` | Validation of Host JSON replies (fn, outbox, continuity): Rust refuses an inconsistent Host answer and fails closed |
| `main.rs:2232-2262` | Hiding-opening verification of signed views (`hiding::verify_view`): Rust re-checks a commitment over Host output; fails closed |
| `shell.rs:1131-2370` | Usage and name validation before building paths; the client checks again |

### 3.3 Correct deferrals

- `refusal_line` reads `reason` from the Host's decoding and never from text (`main.rs:397-418`, with the tests at `:4891-4931`).
- `history_refused` keys on `reason == "no-grant"` (`workspace.rs:2522-2533`).
- Only Lean authors intent, plan, call and signature-list bytes; Rust signs the exact headers the Host returns (`main.rs:1637-1677`).
- `selected_release_sign` signs only bytes the Host re-encoded identically (`main.rs:1041-1061`).
- `inspect_public` requires the canonical bytes to equal the input (`main.rs:1528-1552`).
- `can` uses Host op 130 dry runs.
- `law check` uses Host op 150.

---

## 4. Flaws noticed

**F1. A 255 reply is not always a refusal, but the shell and browser say "refused".**
- Lean writes 255 for `.unavailable "host session reopening"` (`Host/Main.lean:2649-2652`) and for any handler exception (`:2654`, `RequestRefusal.lean:66-72`). `socket_process` records every 255 as `RefusedFrame` (`main.rs:1349-1364`).
- The shell maps every `RefusedFrame` to exit 3 (`shell.rs:2452-2468`), even when its own `outcome_line` says `undecided:`.
- `confirmed_outcome` records `HostDecision::Outcome` for **any** non-confirmed outcome (`main.rs:1702-1704`). `web_author::submit_operation` then labels "The Store refused this operation" whenever `take_host_decision().is_some()` (`web_author.rs:230-251`); `web_create::record_error` does the same (`web_create.rs:182-183`).

Scenario: op 2 submit hits a post-commit I/O error that invalidates the session. The client gets 255 `unavailable`. The browser says "refused". The user opens a fresh editor and saves again. The second save diffs against a fresh read, so a landed first save usually shows up as "unchanged". But a whole-text save made while the first was still uncertain can produce a second operation (for example, a re-typed insert of the same new line). Fix: classify by the decoded outcome type, not by the presence of a decision. The append path already does this (`replan.rs:109-118`).

**F2. Append recovery creates a second operation if "refused at admission" can coexist with a committed event.** `workspace.rs:3634-3644` treats `is_final_admission_refusal` plus an independent "root moved" read as proof the first call did not land. If the first call actually landed (and moved the root itself) but the client was told `refused` at phase `admission`, the client authors and submits a new append, giving **duplicate text**. Whether Lean can ever do this depends on `fnDispatch`'s submit arm (Q1). The "root moved" check cannot tell "someone else wrote" from "my own call landed".

**F3. `workspace --action submit` without `--attempt` can repeat an ordinary invoke.** Each run allocates a fresh `attempts/a-NONCE` and re-observes, re-prepares and re-signs the same `intent.json` (`workspace.rs:3592-3594`, then `main.rs:1849-2009`). Only append and delegation proposals bind one attempt (`:3578-3579`, `:3595-3597`). The shell always passes `--attempt attempts/ID`, which must be unused (`shell.rs:2314-2326`, `workspace.rs:3588-3590`), so the shell is safe. The CLI and the README pattern (`README.md:77-81`) are not. Whether Lean refuses the second one depends on replay protection of the command nonce inside `intent.json` (Q3).

**F4. A shell `retry ID` resubmits; it does not look up first.** `retry ID` maps to `mini retry --mode submit` (`shell.rs:2339-2349`); `lookup ID` is the read-only one. Resubmitting the exact `call.bin` is what the README promises, and Lean's replay should answer `replayed` (`replan.rs:263-264` counts `replayed` as accepted). Still, a user who reads "retry" as "check again" appends a submit event attempt. DEVELOPING.md:101 calls `retry` "exact-call recovery". This is a naming hazard, not a double operation.

**F5. Host upgrades break workspace transport until a carry migration.** A workspace pins `hostSha256` at init (`workspace.rs:546-565`, `:646-648`). Every later process names that digest in the v2 envelope without re-hashing (`main.rs:502-507`, `:612`). After the Host binary at the same path is replaced, `serve` refuses the envelope ("host image pin mismatch", `transport.rs:207-217`), so every workspace verb fails with a client error (254, exit 1). The only writer that re-pins is `receipt_continuity/carry.rs:344` (continuity-carry migration). `--verify-host` refuses instead of helping (`main.rs:557-562`). The behaviour is fail-closed but operationally sharp for a demo that redeploys.

**F6. Possible panic on an empty reply.** `socket_process` indexes `reply[0]` (`main.rs:1349`), and `consumer_poll`, `consumer_ack` and the origin and continuity routes index `frame[0]` (`:2706`, `:2863`, `:2942`, `:2983`, `:3116`). On the Unix path `read_frame` guarantees at least 1 byte (`transport.rs:651`). On the `--remote` path `invoke_inner` indexes `reply[0]` after `crate::proxy::exchange` (`transport.rs:1131-1136`) with no emptiness check visible here (the deadline variant does check, `:961`). Whether `proxy::exchange` can return an empty Vec is a shard-B question. Codec frames for ops 7-11 come from `client_consent::codec_frame` (other shard).

**F7. Prose matching in control flow.**
- `frozen_roster` rewrites any error containing both `law-denied` and `sealed` (`workspace.rs:5983`).
- `refusal_hint` matches a Lean constructor path in the detail text (`main.rs:426`).
- `web::refusal_text` splits on `"host refused "` and `"; encoded refusal: "` (`web.rs:362-369`).

All three are display-only, but they contradict the stated rule "never from error prose" (`main.rs:231-233`).

**F8. The template `@FILE` read follows symlinks.** `template::session_text` uses `fs::File::open` (`shell/template.rs:86-90`), while every other `@FILE` read uses `session_fs::read` with `O_NOFOLLOW` (`shell.rs:735`, `:785`, `:1048`, `:1067`). A symlink in HOME/requests would let a template "line" be read from any file the session UID can read, and error messages echo the line (`shell.rs:204`). The risk is the same UID and a member who cannot create symlinks through the shell, so it is low; it is still an inconsistency in the confinement story.

**F9. Unbounded recursion in the law parser.** `Parser::clause` recurses for `not( … )`, `any[…]` and `all[…]` with no depth bound (`shell/law.rs:229-249`). A law of about 100K nested `not(` from a 1 MiB `@FILE` or stdin (`law_from_stdin`, `shell.rs:1079-1089`) overflows the stack and aborts that `mini` process. It is a self-DoS only. A Discord `--line` would go through `mini-shell-ssh`; the line size bound there is unknown.

**F10. Exit 0 with no arguments.** `Args::parse` returns `Err(USAGE)` when no command is given (`main.rs:862`), and `main_ending` maps `USAGE` to exit 0 on stdout (`main.rs:4545`). A script that runs `mini` with an empty variable "succeeds".

**F11. A stale actions list.** The workspace `run` error lists 42 actions; 76 exist (`workspace.rs:7078-7080`).

**F12. Studio preview TOCTOU and portability.** The configured Host is hashed (`checked_path`, `studio_preview.rs:14-18`) and later executed by path (`:71-72`). A swap in between runs unhashed bytes. Locally the operator owns the path, so this is low risk. `timeout` is GNU-only.

**F13. Key material.**
- `key --action export-blinding` prints the blinding key to stdout (`main.rs:3742-3746`). This is deliberate, with a notice.
- `escrow-recover` writes a recovered seed (`main.rs:3688-3692`). Zeroization depends on `recover_escrowed_seed`'s return type (other shard).
- `generate_key` zeroes the seed buffers (`main.rs:1148`, `:1173`), but `SigningKey` values live until drop (zeroize feature on).
- The key-cache passphrase comes from the environment and is removed early (`private.rs:84-89`); environment exposure before `main` remains.
- The shell banner states plainly that hosted keys are readable by root (`shell.rs:138`).

**F14. Process-wide state under in-process shell execution.** The shell runs every line through `main::run` in one process (`shell.rs:2580`). The `OnceLock`s (`SOCKET`, `WORKSPACE_HOST_PIN`, `EXPECTED_HOST_SHA`, `SSH_IDENTITY`) are set once. `pin_workspace_host` refuses a second, different pin in the same process (`main.rs:581-585`). So `retry ID` on an attempt whose manifest recorded an older `hostSha256` fails inside a shell session ("pinned workspace Host image differs within one process"). It is fail-closed but confusing.

**F15. Two rendering vocabularies for one decision.** `main_ending` gives exit 1 for a `RefusedFrame` whose decoded type is not `refused` (`host_refusal_ending` returns `None` at `main.rs:438-448`). The shell gives exit 3 for the same frame (F1). The same Host answer gets different exit codes depending on the entrance.

Error swallowing and unbounded reads:
- `observation_stale` writes `{decision:?}` with a `let _ =` (`main.rs:2142`).
- `inspect_public` reads a non-schema inspection output with no bound (`main.rs:1615-1616`). The output is Host-produced in a private temp dir, so the risk is low.

No `unwrap` on network bytes was found in this shard's non-test code apart from F6. The `expect`s (`shell.rs:158`, `:1092`, `:1366`, `:2264`, `:2628`; `workspace.rs:3091`, `:3428`, `:5421`) are on locally constructed values.

---

## 5. Unwired / undone

- **Unreached commands**, from section 1.3: about 45 names. The largest dead clusters by code (module files belong to other shards; sizes left to them): `drain.rs`, `worker.rs` and `publisher.rs` (the fn consumer, 12 arms plus `main.rs:2575-3045`, about 470 lines of `main.rs`); `scheduled_transport`, `pq_mailbox` and `cohort_tcp` (traffic privacy: `traffic`, `mix`, `mix-live`); `fn_namespace` and `fn_frontier`; `session_reenroll`; `append_proof` (CLI unreached; only grain-runtime calls it); `export-evidence`/`verify-evidence`; `escrow-recover`, `enc-*` and `export-blinding`; `consent-resident`; `host-command`; `pay-claim` (the jq law test does not run the command).
- **Not in USAGE but live**: `activity`, `checkpoint`, `clock`, `consent-resident`, `hermes-handoff`, `member`, `mix`, `mix-live`, `seat`, `story-law`, `traffic`, `bend-session-sign`.
- **Tombstones** kept as code: `key-service`, `key-service-config`, `key-namespace` (`main.rs:3235-3237`).
- **Versioned and retired shapes still parsed.**
  - Envelope v1 alongside v2: `transport::invoke` (v1) is still used for `enrollment-view` (`main.rs:3137`, `:3152`). The README says "the client does not fall back to the legacy v1 envelope" (`README.md:197-198`); this is a counter-example.
  - The legacy `mini-web-edit-v1` session is still loaded (`web_author.rs:12`, `:78-80`, `:186-191`).
  - The Studio v1 draft and `prototype` field are recognized only to refuse (`studio.rs:17`, `:162-174`, `:335-337`). The fallback reads legacy `manifest-{n}.json` history (`studio.rs:331`).
  - The `minidregg-workspace-seen-document-v2` type has a refusal path for older shapes (`workspace.rs:5512-5514`).
- **Twins.**
  1. Op bytes written as literals in `main.rs` (`:1311-1341`, `:2588-2606`, `:2940`, `:2981`, `:3114`, `:3137`, `:3152`) vs the generated `native/host-operations.rs`, which only `member_app.rs` uses. Delete the literals and use the generated constants.
  2. `shell::document_law` / `room_law` / `board_law` vs (missing) Lean-emitted templates (D1).
  3. The `shell/law.rs` grammar vs Lean `renderClause` (D3); `law.rs` `VERBS` vs `CredentialAuthorityEntryCodec.verbTag` (D2).
  4. Two hex decoder test modules (`main.rs:5186-5196`, `:5198-5209`).
  5. The private-room disclaimer exists both as text in usage strings and as `PRIVACY_DISCLAIMER`, with a test enforcing they agree (`shell.rs:4263-4279`). A twin by design.
  6. `workspace::validate_name` vs `shell::workspace_name` (same rule, `workspace.rs:122-132`, `shell.rs:990-998`). The shell comment admits the duplication ("The client checks again", `shell.rs:988-989`).
  7. The `TreeModel` (`workspace.rs:5683-5758`) and the test's `applied` (`:7269-7329`) both re-implement the kernel's element-tree step semantics.
- **Tests that test only their own model.**
  - The `doc_push_*` tests (`workspace.rs:7419-7529`) assert that `push_actions` output replayed through the test's own kernel model reproduces the file. Nothing ties this to Lean's `editElementStep`.
  - `replan_propose_reads_that_disagree_are_made_again_and_nothing_else_is` (`:8107-8136`) exercises `replan` with a closure, not `propose`.
  - `host_renderings_parse_back` (`law.rs:513-534`) uses hand-typed strings. The comment calls them "the Host renders a refused clause in this grammar", but they are not produced by Lean.
  - The `job_law_grammar_is_the_template_json` test is meaningful, because both files are generated from Lean.
- **TODO / FIXME / `unimplemented!` / `todo!` / `#[allow(dead_code)]`**: none in this shard's 13 files (I read every line; there are no such markers). Studio's `"producer":"unavailable","publication":"unavailable"` (`studio.rs:511`) is the explicit not-yet.

---

## 6. Size and shape

| File | Total | Code | Tests | `#[test]` count | Test region(s) |
|---|---:|---:|---:|---:|---|
| `src/main.rs` | 5,209 | 4,557 | 652 | 25 | 4558-5157, 5159-5184, 5186-5196, 5198-5209 |
| `src/shell.rs` | 4,306 | 3,161 | 1,145 | 39 | 3162-4306 |
| `src/shell/session_fs.rs` | 218 | 141 | 77 | 3 | 109-185 |
| `src/shell/doc_render.rs` | 251 | 179 | 72 | 2 | 180-251 |
| `src/shell/template.rs` | 289 | 158 | 131 | 4 | 159-205, 207-289 |
| `src/shell/law.rs` | 666 | 415 | 251 | 10 | 416-666 |
| `src/workspace.rs` | 8,795 | 7,079 | 1,716 | 61 | 5242-5245 (fixture), 7084-8702, 8704-8795 |
| `src/workspace/studio_preview.rs` | 222 | 188 | 34 | 4 | 189-222 |
| `src/workspace/studio.rs` | 602 | 538 | 64 | 2 | 539-602 |
| `src/workspace/web_author.rs` | 494 | 333 | 161 | 5 | 334-494 |
| `src/workspace/web_create.rs` | 424 | 365 | 59 | 3 | 366-424 |
| `Cargo.toml` | 43 | | | | |
| `README.md` | 982 | | | | |
| **Rust total** | **21,476** | **17,114** | **4,362** (20.3%) | **149** | |

**A minimal demo-critical version of this shard.** It would keep: `main.rs` parsing, the Host transport glue, the submit, query, retry, author and inspect pipeline, keygen, bootstrap, serve and the socket-proxy arms; `shell.rs` with its document, room, enroll, init, read, can and law verbs; `session_fs`, `doc_render` and `law.rs` (until D2 and D3 are emitted from Lean); and `workspace.rs` with init, refs, reads, propose, submit, recover, create/birth, documents, rooms and provision.

Removable from this shard's files:

| Removal | Lines |
|---|---:|
| `main.rs` fn-consumer / origin / continuity block (`:2575-3129`) plus its arms (`:3349-3624`) and tests (`:4666-4819`) | ~985 |
| `main.rs` arms for unreached commands: agent-*, session-*, share-issue*, grain-share*, historical-call*, fn-namespace/frontier, selected-*, export/verify-evidence, enc/escrow, traffic/mix/mix-live, consent-resident, host-command (`:3650-3695` and `:3869-4299` minus kept ones) | ~520 |
| `main.rs` USAGE lines for the above | ~110 |
| `workspace/studio.rs` | 602 |
| `workspace/studio_preview.rs` | 222 |
| `workspace/web_create.rs` (if `mini web` is not in the demo) | 424 |
| `workspace/web_author.rs` | 494 |
| `shell/template.rs` (if templated rooms are not demo-critical) | 289 |
| `workspace.rs` continuity, carry, app-document, app-lifecycle and market action arms that dispatch to other shards (`:6198-6268`, `:7035-7077`) | ~110 |
| `workspace.rs` thin consent and kick companions (if dropped) | ~150 |
| Their tests | ~900 |
| **Total** | **~4.8K** of this shard's 21.5K (about 22%) |

The far larger savings are in the module files these arms dispatch to (other shards): `drain`, `worker`, `publisher`, `agent_reserve`, `agent_lifetime_grant`, `session_*`, `share_issue*`, `grain_share_issue`, `fn_*`, `selected_*`, `pq_mailbox`, `cohort_tcp`, `scheduled_transport`, `relay`, `channel`. The crate synthesis will total those.

---

## 7. Deployability on a small public Linux VM

**Must exist on the box.**
- `minidregg-host` (Lean), its SQLite Store helper and Ed25519 verifier.
- `mini` at `/usr/local/bin/mini` (`deploy/clock/mini-clock-tick.service:47`, `deploy/checkpoint/mini-checkpoint-certify.service:20`).
- A `mini` user and group (the units run `User=mini`).
- `/var/lib/mini/{store,clock,sessions,…}`.
- The `mini-store.service` unit is referenced by `After=`/`Requires=` (`deploy/clock/mini-clock-tick.service:36-37`) but lives outside this repository (dregg-infra).
- The `mini serve` socket in a `0700` directory (README `:165-180`); for split tenancy, `serve-public-proxy` with `--socket-gid` (`main.rs:784-786`).
- The ssh forced commands `deploy/shell/mini-shell-ssh` (runs `mini shell`) and `deploy/shell/mini-socket-proxy` (runs `mini socket-proxy`).
- `/usr/local/lib/mini/FRIENDS.md` (`shell.rs:141`).
- `stty` (interactive shell).
- GNU `timeout` only if Studio preview is enabled.

Kernel features needed: Unix sockets, `openat`, `renameat`. No bwrap, cgroups or seccomp in this shard.

**Operator-configured.** The pinned config JSON; the genesis source (`bootstrap`); `checkpoint.key` (generated); the clock and checkpoint workspace environment (`MINI_CLOCK_WORKSPACE`, `MINI_CHECKPOINT_*`); `MINI_KEYCACHE_PASSPHRASE` for private rooms; `MINIDREGG_STUDIO_PREVIEW_CONFIG` (optional); per-friend session HOMEs and the `provision/birth-context.json` a sponsor delivers (`shell.rs:1619-1625`).

**Dangerous to expose.**
- The operator socket (`serve-operator`) must never be reachable by members. The public socket refuses ops 32 and 33 (README `:226-229`).
- `mini web` binds loopback only and checks the Host header (`web.rs:11-12`, `:60-65`). Exposing it through a reverse proxy would hand any visitor that workspace's signing key.
- The hosted shell keeps keys as files root can read (`shell.rs:138`).
- `key --action export-blinding` prints a secret.
- A member who knows the socket path cannot reach operator ops (shard B).

**What a stranger on the internet can exercise.** Nothing in this shard listens on a network port. The network surfaces are sshd forced commands and, if deployed, the Discord entrance, `enrollment-bootstrap --listen 127.0.0.1:8794` (USAGE `main.rs:689`) and the pay watcher. A stranger with an accepted ssh key gets `mini shell` lines (each line is one client operation) or the byte proxy. J8 shows a stranger is refused by the Host at `challenge` (`docs/evidence/2026-09-30-shell-journey/README.md`). The root README notes main at `4795b657` failed J5 and J8 in some cases, a Host-side issue.

**What a malicious enrolled member can exercise.**
- Every shell verb under its own key.
- Templates from its own `requests/` (F8).
- Deeply nested law text (F9, self-DoS).
- Unbounded proposal IDs are prevented (64-char names).
- Writes under its HOME are confined by `session_fs`.
- Repeated CLI submits (F3) are possible only through `--remote` or the CLI, not the shell.
- Resource pressure on the shared Host through batch reads (≤ 16 per batch) and dry runs (`can --all` runs one dry run per verb per reference, Host op 130).

The in-process shell means a panic in any verb is caught (`shell.rs:2580-2581`), but a stack overflow (F9) aborts the process.

---

## 8. Questions for the Lean side

1. **Q1 (submit commit vs refusal).** In `fnDispatch`'s op 2 (SUBMIT) arm, can the handler append an event to the Store and *then* throw or return, so that `serveFrame` writes `255 refused operationRejected` (phase `op 2`), or `255 unavailable "host session reopening"` (`Host/Main.lean:2646-2654`)? Point to the declaration that orders "append durable event" before any fallible step, or prove that a `refused` outcome implies no append.
2. **Q2 (append-recovery premise).** Is there a theorem or invariant that an outcome `refused` with phase `"admission"` (the bytes `replan.rs:117` checks) is produced only when no event was appended for that call? Name it. If not, D6/F2 can duplicate text.
3. **Q3 (replay of re-prepared intents).** If the same `intent.json` (same command `nonce`, same observation `nonce`) is observed, prepared and signed twice and submitted as two different `call.bin`s, does admission refuse the second (nullifier or nonce spent), answer `replayed` with the first receipt, or admit both? Point to the nonce or nullifier check.
4. **Q4 (lookup "absent").** Does op 3 LOOKUP have a definitive "never admitted" answer (type `absent`) that is final for that exact call bytes? If so, which declaration guarantees it cannot later become admitted? That would replace the Rust "newest refused" rule (D5).
5. **Q5 (session invalidation after commit).** When `state` becomes `none` inside op 2 (`Host/Main.lean:2648-2652`), is the call guaranteed not to have committed, or is `unavailable` exactly "unknown"? The client should treat it as the latter (F1).
6. **Q6 (fn ops payloads).** Confirm the `fnDispatch` decoders for ops 12-18 and 112: empty poll body; ACK body = canonical decimal ≤ 80 bytes; op 16 carrier ≤ 1,516,384 bytes; op 17 payload layout = `provider_continuity::request_payload(call, outcome, None, false)`. Point to their arms.
7. **Q7 (verb tags).** Is `CredentialAuthorityEntryCodec.verbTag` exactly read 1, write 2, delegate 3, install 4, revoke 5, append 7, place 10 (`shell/law.rs:59-67`)? Can it be emitted as a table the client imports?
8. **Q8 (law templates).** Can `document_law("draft"|"note"|"index")`, `room_law("open"|"realm"|"private")` and `board_law` be emitted by Lean, as the job law already is (`Kernel/Job.lean` through `scripts/gen-joblaw.py`)? Which Lean module should own them?
9. **Q9 (link targets).** Does content admission accept a `link` whose target is `{"type":"document","id":X}` when X is not a content cell, or `external mini:KIND/ID` when it is? (`workspace.rs:5410-5417` decides this from `cell_storage`.)
10. **Q10 (private room enforcement).** Is there any Kernel or law check that a private room's cells accept only sealed atoms (`inlineObject` with the private schema, or `sealedObject`)? If not, confirm that privacy is client-enforced only (D4).
11. **Q11 (codec frames for refusals).** For a 255 frame produced by `RequestRefusal.frame`, is `inspect outcome` on the *local codec* Host (ops 7-11 run locally, `main.rs:603-605`) guaranteed to decode it identically to the serving Host when the images differ? The client decodes every refusal with its local image.
12. **Q12 (content command version).** `workspace.rs:266` sends `schemaVersion "10"`. Confirm `Kernel/ContentResource.commandVersion = 10` at the current main, and that v9 is refused (the comment at `workspace.rs:262-263` says "v1–v8 are refused").
