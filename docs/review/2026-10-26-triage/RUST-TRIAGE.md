# Rust triage: rescue, repair, delete (second opinion, 2026-10-26)

Main at `a0db11f8`. This is an independent read of the native-crate review, the deploy review and the
ATLAS laws, made under ember's two rulings of today: rescue and repair as much as we can, and also name
what is truly scar tissue. **Every surface is on for the public demo**: the ssh shell, the web docuverse,
SPK grains, Hermes residents, PAY, Discord, fleet, fn transport and the SDKs.

**What I read.**
- Crate-level reports in full: `deploy.md`, `tiny-crates-and-shared-root.md`, `resource-client.md`,
  `grain-runtime.md` and `verifier-keys-testprovider.md`.
- The small-bundle reports: `bend-objective.md`, `discord-spkrpc.md`, `mini-sdk.md`, `prover.md` and
  `scheduler-pay-linkstore.md`.
- spk-host and private-backend exist only as shards (`spk-host--{A,B,C}`, `private-backend--{A,B}`). For
  those I read the executive summaries and sections 3, 5 and 6.
- Also `AFFORDANCES.md` §1, §6, §7 and §8, `WEB-SPK-PUBLIC.md` §6 and §7, and ATLAS §1 and §6.

**Source I opened**, each time to settle one claim:
- `Host/ProviderUsage.lean:264-268` and `native/grain-runtime/src/main.rs:9222-9245` (pool-route non-200);
- `native/resource-client/src/main.rs:1348-1366` and `shell.rs:2452-2468` (255 shown as refused);
- `native/hybrid_kem.rs:1-15` against `channel.rs [deleted 17d61469]:23-24,50` (the "no pure X25519" claim);
- `native/resource-client/src/main.rs:651,695,697,1067-1133` (the sponsor-escrow flow);
- `main.rs:3233-3237` (tombstones);
- `wc -l` on every file a DELETE row counts.

Nothing was built or run.

Reference shorthand: **rc** = `resource-client.md`, **gr** = `grain-runtime.md`, **dep** = `deploy.md`,
**tiny** = `tiny-crates-and-shared-root.md`, **vk** = `verifier-keys-testprovider.md`, **spkA/B/C** and
**pbA/B** = the shards, **sdk**, **bo** (bend-objective), **ds** (discord-spkrpc), **spl**
(scheduler-pay-linkstore), **prv** (prover), **AFF** = `AFFORDANCES.md`, **WSP** = `WEB-SPK-PUBLIC.md`.

---

## 1. The tests I applied

Each item is judged once, by the first test it fails.

**Scar (delete).** An item is a scar if any one of these holds:
1. **No surface reaches it, and no surface ember wants would use it.** "Reaches" means a unit, a journey
   row, a script on the demo path, another crate's live call, or a shell verb. Evidence directories from a
   lane, or from before a rewrite, do not count as reach.
2. **It is a duplicate, and a better twin is kept.** Law 13 decides which one is better: the one that is
   derived, live, bounded, or the newer generation the design moved to. "Delete the twin" means one of
   the two goes, and this row names which.
3. **It is a route the repo's own records have disowned.** Examples: a superseded generation that only
   refuses by name in Lean, a premise the current fn or Host no longer produces, an ember ruling (D2, D7),
   or a migration document that names its own deletion.
4. **It is a claim in docs, a README or comments that the code contradicts.** The fix is to rewrite the
   prose whole (`rewrite-whole-not-append`). Stale `#![allow(dead_code)]` headers count: they hide real
   dead code from the compiler.
5. **It is a test that cannot fail.** That covers constant-vs-constant asserts, tests that return early
   and pass when an env var is unset, tests pinned to a wire the Host now refuses, gates that compare
   bytes but never compile, and test code shipped in a production binary.

**Rescue.** An item is a rescue if it serves a surface that is on, and if wiring and fixing it is
bounded, with steps I can name. A rescue usually retires a twin: the rescued path becomes the only path.

**Repair.** An item needs repair if a surface reaches it and uses it, but it is defective in a named way.
I rank repairs by blast radius on a public box: first what a stranger or newly enrolled member can
trigger against others, then money, then availability, then hygiene.

**Decision rows.** Some items fail test 1 only because their surface is research, not demo. Deleting or
keeping them is ember's call, and I give my lean. They are counted separately and are not in the DELETE
total.

---

## 2. DELETE: the bullshit and scars

Lines are `wc -l` unless marked "~", which means a range a report cited or my estimate from it.
Confidence: **H** = I would delete today; **M** = delete, but one named fact should be checked first.

### 2.1 Delete now

| # | path / module | lines | test failed | re-point when it goes | conf |
|---:|---|---:|---|---|---|
| 1 | `native/hyperdocument-link-store/` (whole crate) + `test-hyperdocument-link-local-store.sh [deleted 52c252e3]` (60) + `run-forward-link-e2e-benchmark.sh [deleted 52c252e3]` (58) + README (31) | 713 + 149 | 2 (twin of the shipped `hyperdocument-link-sqlite-store`), 5 (unbuildable since `295cab11`; both scripts are silently dead) | move the 14-byte fixture into SQ (`SQ/tests/lifecycle.rs:12`); decide `Assurance/HyperdocumentLinkLocalFileStore.lean`, which is imported by `…SqliteTransactionalStore.lean:17` (tiny §10.5, spl §5) | H |
| 2 | `native/bend-ir2-proof/` + `native/bend-proof-entropy/` | 874 (+727 text and Python, +1,289 lock) | 1, 2 (a second prover stack on breadstuffs' `dregg-circuit`, the #1 collapse target, beside the chosen Selvage `prover/`), 4 (`QUALIFICATION-R32/R33` cite deleted tests and a root `Cargo.toml` hash that matches none of 384 commits) | `scripts/pipeline/prime-cargo:12` skip notice; `docs/construction/source-intake-20261003.json` | H |
| 3 | `credential-signature-verifier` verb `verify-mldsa` (`main.rs:45-71`, invoke arm) + `mldsa.rs [not in tree]` + the `fips204` dependency | 112 | 1, 4 (cites `CredentialSignatureIO.combineHalves`, which exists nowhere) | none; the hybrid conjunction stays in `mini-sdk/src/signer.rs:155-172` (vk A-F1) | H |
| 4 | discord-entrance dead code: `curl::Poster::get`/`run_get` (`curl.rs:57-122`), `reply::render` (`:55-65`); `http::client_request` moves to `tests/` | ~105 | 1, 5 (test helper in the shipped lib) | none (ds §5a) | H |
| 5 | spk-rpc: 17 schemas compiled by nothing (+ their `SHA256SUMS` rows); `get_inline`/`InlineResponse`/`RejectingResponseStream`; one of the two permission-schema projections (`permission_schema.rs` or `spk-host/src/materialize.rs:322-334`) | 148 Rust + 2,256 capnp | 1, 2 | the in-crate test moves to `dispatch_web` (ds §6b) | H |
| 6 | resource-client traffic stack 1, CH-RELAY: `relay.rs`, `channel.rs`, `channel-lib/` | 2,529 | 1 (red in every CI run: the gate never builds the library), 2 (messaging twin of fleet topics and chat, outside Lean admission), 4 (its raw X25519 makes `hybrid_kem.rs:1-15` false, `channel.rs:23-24,50`) | shell `channel` verb, `relay*`/`channel` arms, `jchan-*.sh`, KCHR/KCHC rows. Once it is gone, the `hybrid_kem` header becomes true | H |
| 7 | resource-client traffic stack 3: `scheduled_transport.rs` (`mini traffic`) | 1,245 | 1 (no caller; not in USAGE), 2 | the orphaned-request re-dispatch hazard (rc §5.1 row 17) goes with it | H |
| 8 | `fn_namespace.rs` + `fn_frontier.rs` + 6 `fn-*` arms + the `selected-exchange --phase cover-*` arms | 1,462 | 1, 2 (structurally identical to each other), 3 (the cover path refuses `fn-r`, which is what fn stores; the one native run was refused, rc §4.9, F 1.6) | re-derive after the fn protocol rewrite (`fn-drain-freeze-2026-10-08`) | M |
| 9 | `publisher.rs` (`origin-publish`) + the origin-outbox arms | 552 | 2 (twin of `selected_publisher`'s POST custody with a contrary repost rule, F V11) | keep the `worker.rs` POST half that `selected_publisher` uses | M |
| 10 | `session_reenroll.rs` (`mini session-reenroll`) | 1,150 | 1, and it authors a raw session-close state transition (rc §3 row 15). Its exit 0 on refusal makes it a lie | `scripts/spk-platform/ws-continuity-fixture.py`; a re-enrol must come from a Lean lifecycle command | H |
| 11 | `agent_reserve/lifetime_v3/paid.rs:432-723` + `agent-lifetime-paid-{seal,submit,lookup}` | ~400 | 1, 2 (broken twin of spk-host's live path; lookup after submit always fails, C F3) | none | H |
| 12 | `bend_session.rs` (hidden `bend-session-sign` pre-parse arm) | 75 | 1 | none | H |
| 13 | `web/surface.rs`, `world_surface.rs` | 330 | 1 (no caller outside their own tests) | none | H |
| 14 | Studio: `web/studio.rs` 359, `workspace/studio.rs` 602, `workspace/studio_preview.rs` 222, plus routes, POST arms, index link and help (`web.rs:25,243,603-604,629-637,747`, `main.rs:702`) | ~1,233 | 3 (ember ruling D7) | the README Studio row; Gen-1 `partial-input.v1` docs | H |
| 15 | `join_solana.rs` v1 flows + `pay.rs:1487-1526` (v1 enrol) | ~940 | 3 (versioned sibling; v2 is the live route) | move about 350 lines of shared helpers to `join_solana_v2`; retire the Lean v1 memo receiver in the same change | M |
| 16 | Unreached arms: `host-command`, `selected-release-retry`, and `key --action export-blinding` (it prints a secret and has no caller) | ~80 | 1 | none | H |
| 17 | Dead branches and duplicates: `pay.rs:685-694,821-830`; `join_solana --view`; the `--peer-uid` branch; 10 of 12 `bounds.rs` constants; the stale TAIL-BOUND arms (`transport.rs:593-597`); `agent_lifetime_grant.rs:39-57`; duplicate hex tests (`main.rs:5186-5209`); `protected_object/source-snapshot.json` (it leaks `/Users/ember/workbox`) | ~144 | 1, 2 | none | H |
| 18 | grain-runtime dispatch **v1** (`Reserve`/`MarkSend`/`SettleDefinite`, `main.rs:5742-6070, 6402-6503` and the v1 branches) + `dispatch_runtime_tests.rs:460-469`, which pins its weakness as expected | ~900 | 1, 3 (a money hole: it settles on the SPK host's word, R9), 5 | none | H |
| 19 | `legacy_custody_audit.rs` (incident: operation 44, tasks 7803/7804, 13 pinned SHAs; no record that the reconciliation ever ran) | 819 | 1, 3 | `zero_phase_active` hook (`main.rs:16255`); `reconcile tool legacy b44\|zero` | H |
| 20 | `config_migration.rs` + `controller_write_scopes.rs` | 2,079 | 1 (no driver; its author staged the tests without running them), and it sits on the hot path through `ensure_process_current` on every save | delete the hook; a redeploy re-genesises, so the operator reprovisions | M |
| 21 | `quiescence_transport.rs` | 717 | 1 (one topology, no run) | admin arm | M |
| 22 | `hermes_catalogue_probe.rs` | 93 | 5 (`#[ignore]`d, and asserts `deploy/hermes/runtime-inputs/probe-catalogue.py`, which does not exist) | none | H |
| 23 | Fixed-family birth `mini_create_resource` (`main.rs:10575-11007`, the births in `resource_tools.rs`, `birth_lifecycle_tests.rs`) | ~850 | 2 (twin of `mini_workspace_create`; `RESOURCE-WORKSPACE-MIGRATION.md:9` names the twin and its deletion bar) | check that bar is met | M |
| 24 | `examples/current_birth_provider.rs` | 278 | 1 (no script builds it) | none | M |
| 25 | `resident_preflight::{Ready, checked}` | 26 | 1 (dead in non-test builds) | none | H |
| 26 | spk-host: `bin/spk-hostd.rs` 42 + `endpoint.rs` 314 + `http_entrance::serve_unavailable`/`serve_resident` ~20, plus the duplicate `init-custodian` | ~376 | 1, 2, 4 (this is the "503 by design" a scout misread) | `package.py:69` role | H |
| 27 | spk-host harness binaries: `spk-smoke` 146, `gitweb-smoke` 590, `gitweb-session-smoke` 312, `gitweb-human-journey` 912, `http_entrance_gitweb_probe.rs` 208 | 2,168 | 1 (no caller since 09-27; GitWeb is not the public app) | `PrivateContinuityReply` can become private | M |
| 28 | `RpcDriver::dispatch`/`dispatch_inner`/`stats`, `hostd::fence_and_stop_manager`, the `main.rs` `broker-serve` arm (a twin of `mini-spk-broker`) | ~90 | 1, 2 | `BROKER-RUNTIME-UPGRADE.md:7` | H |
| 29 | `claim_descriptor.rs` | 310 | 1 (v2 claim, dead; its own header says "not linked") | none | H |
| 30 | `setid_bound.rs`, except `clear_capabilities` (moved into `os.rs`) | ~338 | 1, 2 (one of three hand BPF assemblers; never installed), 4 (its header says "installs this filter on every thread") | spk-host README `:78-96` | H |
| 31 | `broker_volume_custody::{BackupTarget, Copy}`; the static supervisor template (`broker.rs:705-720`) | 56 | 1 | none | H |
| 32 | `dispatch_native::qualification` (`:1311-1857`, feature-only) | 544 | 1 (the candidate passes no features; its rows were authored and never run) | the `cfg(feature)` hooks; `jspk1.sh failstart` | M |
| 33 | The v4 lane's Rust re-implementation of Lean StreamCodec (`lifecycle_v4_retry_native.rs:80-119` and its siblings) | ~120 | 2 (law 13: Rust imitating a Lean codec) | compare Host inspections, as v3 does | H |
| 34 | spk-host shard C dead items (`number()`, six `FreshStopClaim` accessors), tautological tests (`v4_retry_completion:776-781`, `agent_api_native.rs:871-881`), and the **34 stale `#![allow(dead_code)]` headers** (5 in A, 6 in B, 23 in C) | ~114 | 1, 4, 5 | removing the headers lets the compiler surface the rest | H |
| 35 | deploy: the GitWeb root chain (`spk-ingest-prepared`, `spk-stage-prepared-inbox`, `spk-qualify`, `spk-install-phase`, `spk-publish-host-identity`) + its two tests | 601 | 1, and broken: it calls `spk-ingest` with 4 arguments as root against a 6-argument non-root contract (dep 4.2) | none | H |
| 36 | deploy: `grain-host/probe_control.rs` + `probe-shell.sh` | 113 | 5 (does not compile against `control::Event`) | `CONTROL-SSH-2026-09-26.md` becomes history | H |
| 37 | deploy: `grain-host/host-frontend.rs` 616 + `host-frontend-probe.rs` 67 + `HOST-FRONTEND.md` 61 | 744 | 2 (hand-written op allowlist twinning `public_envelope` and the registry) | none; WSP §6 agrees | H |
| 38 | deploy: `shell/templates/mud/sim.py` | 433 | 2 (hand twin of `Pred.eval`) | MUD law rows "proved" by it | H |
| 39 | deploy: `shell/templates/hermes/gm/*` | 81 | 1 (compiled by nothing) | none | H |
| 40 | `launch-gate.rs [deleted a9a68a7f]` | 118 | 2 (prototype twin of `deploy/grain-host/launch-gate.rs`) | none | H |
| 41 | `deploy/grain-host/mini-grain-controller@.service` | 20 | 2, 4 (the README calls it historical; it cannot satisfy the controller, gr §9.1) | `install-controller` renders the real unit | H |
| 42 | `package.py --capsule` route (it always dies in `build_identity`, dep 4.1) | ~40 | 4, 5 | `INTERFACES.md:12-13,181-185`, `package.py:6,26-34` | M |
| 43 | mini-keys `Broker::default_box` | ~5 | 1 | none | H |
| 44 | objective-emit: `build-lean-native.sh` 18, `fastmachine/MachineDiag.lean` 144 (outside every lib, rots unseen), the `OB_MUTATE_*` ifdefs, the 5 unused mutants, and `evidence/` (13 logs, 452 KB, older than the runtime it claims) | ~182 + 452 KB | 1, 4, 5 | `OBJECTIVE-BEND-BACKENDS.md:16` "340/340" | H |
| 45 | SQ (`link-sqlite-store`) crash and hold verbs in the **production** binary (`cas-crash`, `publish-crash`, `publish-hold`, `durable-append-crash`, `journal-append-crash`; `main.rs:47-57,106-159,206-220,239-252,301-306`) | ~110 | 5 (test code shipped where `serve` forwards it) | move them to a test-only binary; the kn2 probes follow | H |
| | **Subtotal, delete now** | **~24,400 code** + ~4,400 non-code (2,256 capnp, 1,289 lock, 876 provisioning and script text) | | | |

### 2.2 Delete after the named rescue or repair lands (sequenced)

| # | item | lines | it goes when | conf |
|---:|---|---:|---|---|
| S1 | `hermes_room.rs` legacy chat-completions runner, keeping `prepare_resident` (`:507-556`) | ~450 | rescue R1: `j14.sh:197,386,419` re-pointed at the ACP resident. Until then J14 is evidence only for this twin (gr §9.3) | H |
| S2 | `session_failure.rs` 705 + `resident_outcomes.rs` 416 | 1,121 | the typed per-prompt outcome record exists (gr §4.3). `session_failure` freezes all mutation with no reset, on the hot path | M |
| S3 | `spk-host/src/bin/spk-browser-proxy.rs` | 840 | the Caddy edge passes M6 and `jspk10-ws.py` runs through it (D2; WSP W9) | H |
| S4 | mini-sdk `flow.rs`, `consent.rs`, `host.rs`, `frame.rs` (the broken twin of resource-client's live path) | ~415 | rescue R5 moves resource-client's working consent and submit path into the SDK | H |
| S5 | memfd sealing copies in `transport.rs:1368-1393` and `seccomp.rs:361-396` | ~60 | rescue R7 makes `pinned_execution` the one implementation | H |
| | **Subtotal, sequenced** | **~2,900** | | |

### 2.3 Documentation that lies about the code (rewrite whole, test 4)

| doc / comment | says | code says | source |
|---|---|---|---|
| `deploy/spk-host/README.md` (244, whole) | root broker on `/run/mini-spk-broker.sock`, `AmbientCapabilities`, `setid_bound`, oneshot supervisor, `/etc/minidregg/spk/host-identity`, 4-argument root `spk-ingest` | operator-owned per-world user broker, bwrap namespace, `$GRAINS/host-identity`, 6-argument non-root ingest | spkB 5.2; dep 10.1-4 |
| `deploy/spk-host/HTTP-CUSTODIAN-CONTRACT.md` (104) | signer and native delivery "unimplemented"; proxy "one connection at a time"; one custodian per participant account | implemented; 136 slots; every route in the resident under the operator uid | spkA 5.2 |
| `deploy/spk-host/MINI-CLAIM-DISPATCH-CONTRACT.md` (105) | the Rust parser and endpoint are "intentionally unavailable" | ops 34/36/37/164 are wired and ran in jspk1 | spkC 5.6 |
| `deploy/spk-host/BROKER-RUNTIME-UPGRADE.md` (117) | falls back to `/run/mini-spk-broker.sock`; root peer credentials | `broker_endpoint.rs:6-27` refuses every other path; the peer is the operator | spkB 5.2 |
| `deploy/candidate/INTERFACES.md` `:12-13,181-185` / `:64-86` / `:203-208` / `:456` | capsule is a route / output table / serve is serial, one process per Store read / waits for `mini: serving` | always refuses / 7 shipped outputs missing / concurrent, in-process / `^mini: host process` | dep 10; AFF §7 |
| root `README.md` honest-state rows | pay quote 49.999992; J5/J8 failing; call/send not rows; chat never joined a Host; "Hermes in a room: executed" | exactly 50; both pass on main; rows since `f5897dd8`; J14 joined (before `336b7c0e`); J14 ran the legacy runner, not the ACP resident | rc §9; gr §9.3 |
| `native/resource-client/README.md:195-198`, `:962` | v1 envelopes are not sent; use `acceptance.sh` | three Rust senders plus nine scripts; `acceptance.sh` is broken | rc §4.10 |
| `native/hybrid_kem.rs:1-15` | "no pure-X25519 … path" | `channel.rs` seals with raw X25519. It becomes true when row 6 goes | checked |
| `verify-mldsa` doc and `mldsa.rs [not in tree]:1-2` | Lean `combineHalves` decides the conjunction | no such declaration | vk A-F1 |
| `deploy/discord/README.md:122`, `native/discord-entrance/tests/native-world.py:108` | set `MINI_MIRROR_WEBHOOK_URL`/`BOT_TOKEN` | the binary exits 78 when it sees them | ds 4a.8 |
| `FRIENDS.md` `:22`, `:29`; `OPERATOR.md:19-20` | a `lock` verb; chat never ran; the node has `provision` | no such verb; J14 ran chat; `5688775a` lacks `provision` | AFF §1.2 |
| `deploy/shell/README.md:75-84` (+ HCLOUD-GAP §3) | proxy friends cannot sign | thin consent exists. It is unjourneyed, not refused | AFF §1.9 |
| `deploy/shell/mini-socket-proxy:12` | `mini --remote … key --action set` | `key` is not in `REMOTE_COMMANDS` | AFF §1.9 |
| `docs/DURABLE-STORE.md:15`; SQ `README.md` | schema 4, two checkpoints; "dependency-free"; silent on the anchor | schema 5, all checkpoints kept; `sha2`+`libc`; the anchor sidecar must be backed up or restore refuses | AFF §7; spl F7 |
| `native/spk-rpc/README.md:60` | WebSocket not connected | `open_web_socket` exists | ds 4b.6 |
| `main.rs:702`, `web.rs:1-14`, `jweb.sh:2`, journey step title | `mini web` is read-only | POST edit and create routes exist | rc §9 #16 |
| `credit.rs:1-13`; `join_solana.rs:3-22`; `workspace.rs:262,3178-3181` | "nothing here decides admission"; `--view` and `--renew` one week; grammar 9 | the concierge decides membership-for-payment; no `--view`; constant is 10 | rc §4.10 |
| spk-host stale comments: `hostd.rs:810-813`, `http_entrance.rs:4-5,47,80,111-122`, `spk-hostd.rs:1-2`, `broker.rs:422-446,494-495,537`, `grain.rs:328-330`, `resident_service.rs:1251`, `spk-var-volume:14`, `lifecycle_selector.rs:5` | "unreachable", "unavailable", "root" | wired, and run as operator | spkA 5.2, spkB 5.2, spkC 5.6 |
| `docs/SPK-LIFECYCLE.md:109-110`; `docs/evidence/2026-09-27-spk-resident-mixed-route/README.md` | v4 is uncompiled; `journey.sh prepare-resident` | compiled and wired; the verb is gone | spkC 5.6 |
| `native/inference-scheduler/README.md` | `deploy/hermes/mini-inference.service` | does not exist | spl §4.23 |
| `credentials.rs` module doc; `mini-keys/src/lib.rs:19`; `mod.rs:108-109` | "one source, two consumers"; provider account `mini-core`; "only a root-owned config can say so" | three consumers; the unit runs as `mini`; the broker's euid suffices | gr §5.5; vk B-F10 |
| `mini-sdk/src/lib.rs:1-6`, `ts/src/index.ts:6-7` | a consent boundary; a native-messaging bridge | a typestate convention (sdk F7); no bridge exists | sdk F7 |
| `deploy/` contradictions dep §10 items 5-25 | pay defect, MUD "never run", genesis zero placeholder, roster ceiling, eqSlots, 600 s ceiling, `controller.sock`, two pool-key recipes, Discord binary path, five binary-path conventions | see dep §10 | dep §10 |
| `docs/JOURNEY.md` | 6 runner rows; call/send are not rows | 30 rows | rc §4.10 |
| traffic diaries (`PQ-MAILBOX.md:184`, `TRAFFIC-ENROLLMENT-CONSTRUCTION.txt`, `COHORT-TCP.md`, `CRYPTO-TRANSIT-CONSTRUCTION.txt`) | MCE2; pure ML-KEM MCA1; uncompiled vs PASS; integration still to do | MCE4; hybrid; PASS 9/9; done | rc §4.10. They go with row 6, or with the stack-2 decision |

That is about 670 lines of contract prose to rewrite whole (the four spk-host contracts and the INTERFACES
sections) plus about 60 sentence-level fixes. These are not counted in the code total.

### 2.4 Tests that cannot fail, kept modules (fix, do not delete the module)

- `hostd.rs:3200-3203`, `:3258-3261` return early and pass when an env var is unset. Make them
  `#[ignore]` (spkA 5.3).
- `resident_launch.rs:578-625`: the sandbox-floor root tests cannot pass with the current
  `spawn_bounded`. The only floor evidence measured the retired root-gate design (spkB F2). This is a
  repair (R-7 below).
- `lifecycle_v3_completion_native.rs:582-658` writes a file and asserts it reads back. It never calls
  `recover_receipt_only`.
- `mini-sdk/tests/golden.rs:98-107` pins a schemaVersion-9 intent the Host now refuses. `ts/test/examples.test.ts`
  is red by construction (sdk F9).
- `dzk_store` test red by reading, ungated (pbB 9).
- `get_router_calls_no_submit_path` is a prose-scanning test (rc E 5.4).
- `deploy/spk-host/tests/var-volume-import-untrusted.sh` plants a setuid file and never asserts on it
  (dep 4.17).
- `scripts/check-prover-glue.sh` says "Glue OK" while the crate cannot compile (prv F1).
- `grain-runtime` `main.rs:19996` asserts the full charge on an absent lookup. It pins R2 as expected.

### 2.5 Decision rows (ember's call; not in the totals)

| item | lines | why it is not a plain scar | my lean |
|---|---:|---|---|
| `native/private-backend/` (whole) + `native/pinned_execution.rs` if R7 is declined | 26,139 (+245) | Research MPC with zero Host ops. Its Lean names do not exist (`Host.JointBackendPartyInner`), its routes 203-205 are unallocated, nothing provisions its worker, and the width-8 fixture producer was deleted in `212c79af`. Still, a private-compute surface could be wanted later | **park it off main** (research branch or its own repo). It fails test 1 for every surface on the list. pbB §6.3's 9.7K-line research trim is the alternative if it stays |
| traffic stack 2: `pq_mailbox.rs`, `cohort_tcp.rs`, `async_dispatch.rs`, `native/crypto_transit.rs` | 5,248 | evidence-only research (traffic-v13). TCP listeners with stranger-reachable resource bugs (rc §4.2). The README row cites it | park with private-backend. `crypto_transit` is shared by exactly these two |
| fn consumer worker: `drain.rs`, the consumer half of `worker.rs`, the `main.rs:2575-3129` block, 12 arms | ~3,600 | fn transport is on, but the journeyed fn path (row `exchange`) uses the Host CLI `selected-release-fn-legacy-poll`, not this worker. Its public ops 13/15 have an open authorization question (rc B Q8.2) | delete now, and re-derive after the fn coordination rewrite. Rescuing it means building against a protocol that is being replaced. If ember wants unattended fn consumption in week 1: rescue, size M (unit + row + fix `drain.rs:1303-1310` + route 13/15 operator-only) |
| Hermes-to-SPK agent API: one of the two generations | ~6,600 on the v1/v2 side (spk-host agent v1 3,386; grain-runtime app-API v2 and dispatch v2 ~1,500; resource-client event21 `agent_reserve` + `agent_payer` ~1,700) | law 13 says one goes. v2 is the only one ever run (09-27), but no agent request has ever reached fd 3 (spkC §1.6). v3 lifetime is broken by two named decode bugs (gr §9.7) | **keep lifetime v3, fix it (R14), delete v1/v2**. v3 is the generation the resident config, the purse model and spk-host already carry |
| MUD template data (`shell/templates/mud/**` minus the 4 files `jclock.sh` uses, minus `sim.py`) | ~4,460 | never shipped game content. It is data, not code, and could seed story or game rooms on the demo | keep only if a game room is on the demo menu; otherwise delete (dep §9) |
| objective-emit C machine: `runtime.c`, `differential.py`, `cdiff*`, `ObjectiveBendEmitC*.lean`, gates `objective-c`/`objective-cgen` | ~1,500 | a hand twin of `stepRaw` with no consumer. The csimp-proved `stepRawFast` overtook it (41-43 ms vs 20 ms). It costs 1,000 programs plus mutants in CI on every push | delete (test 2: the better, proved twin is kept) |
| `joint-agreement-crypto`, `portable-archive` | 709 + 338 | live stdio helpers of Lean research executables (`minidregg-four-source-fixture`; `ResearchWip`) | keep as research. Never ship them. The agreement helper's unauthenticated TCP listener must not face the internet (tiny §1.4) |

---

## 3. RESCUE

Sizes as in WSP §7: S is under a day, M is 1-3 days, L is more than 3 days.

| # | what | surface | concrete steps | size | value | Lean change? |
|---:|---|---|---|---|---|---|
| R1 | **ACP room resident becomes the Hermes-in-a-room path** | Hermes residents | (1) Add a `failed-after-admission` request status with a closing transition, so `resident-reconcile failed` cannot wedge the queue (C-F2, `resident_requests.rs:420-430`). (2) Make the admin protocol length-prefixed, or read with the same bound it writes, and drop requester text from the delivery plan (C-F4, `control.rs:146-158`). (3) Default `restrictTools:true`. (4) Re-point `j14.sh:197,386,419` from `hermes-room step` to `hermes-room resident` and add a required row. (5) Then S1 | M | strangers get a Hermes in a room that is metered and authenticated, and that no single long question can wedge | no |
| R2 | **A controller an operator can actually install** | Hermes residents | Have `install-controller` write `/etc/mini/controllers/T.json` (Shape 1, gr §7.2), or add the two missing `Environment=` lines (Shape 2). Rename or retire `deploy/hermes/mini-hermes.service`. Add a first-class verb that births a member grain and writes its controller config, replacing the Python `exec`'d out of `jpay6.sh` (gr §7.3, "a demo blocker") | M | the door processor (G2) can create Hermes grains without a hand-run fixture | no |
| R3 | **Homelab rows via inference-scheduler** | Hermes (week-1 H3 says pool and homelab) | Write the missing unit. Bind each controller to its own uid, or authenticate the `controller` field beyond peer uid (spl F17). Reconcile the `check`/`serve` owner rule (F22). Give the accept loop a per-connection thread or deadline (F18). Fix grain-runtime B-F2: report `NotSent` on an endpoint mismatch before `BeforeSend` | S-M | the homelab rows WSP H3 plans actually run, and one controller cannot starve another | no |
| R4 | **Discord room mirror** | Discord | Add `mini-discord-mirror` to `package.py:71,88` and give it a unit. Have the broker return the Discord message id (`mini-keys/src/server/discord.rs:134-139`), and treat a definite non-2xx (429, 400) as unsent and retryable with pacing (ds 4a.1). Add an operator `--skip` for an unreadable message, so it cannot stall `down` forever (4a.2). Rewrite `README.md:122` and `native/discord-entrance/tests/native-world.py` | M | room and channel stay bridged past the first burst | no |
| R5 | **mini-sdk becomes the one client** | SDKs; also shell and fleet, which use it | Move resource-client's working `client_consent.rs`, `submit_once` (`main.rs:1888`) and `exchange_unix` into mini-sdk, replacing `flow`, `consent`, `host` and `frame` (sdk F1: `stdio` vs `codec`; 29 vs 31 ops). Fix the custody rules: `.charged` is not success (F3); Refused-then-successor waits on Q2 (F4); rebuild an `Attempt` from an `AttemptDir` (F5); profile writes go through `durable`/`secret` (F6). Then resource-client depends on it, and S4 follows | L | one signing path that integrators and the CLI share: the twin AFF §7 lists first | small: emit the consent op list from Lean (rc Q42) |
| R6 | **mini-sdk-ts honest and gated** | SDKs | Add a lockfile and a `node --test` gate row. Fix the v9 to v10 example drift (sdk F9). Delete the "native-messaging bridge" claim and state the scope as "build and sign; no transport until thin consent" (WSP R7/R8) | S | a TS SDK whose README matches what it does | no |
| R7 | **`pinned_execution.rs` becomes the one sealed-exec helper** | SPK, shell (the Host pin) | Move it into mini-sdk (or a `native/pinned` crate, with the ML-KEM known-answer tests travelling alongside, tiny §15). Adopt it in `transport.rs:1368`, `seccomp.rs:361`, and in spk-host's hash-then-exec-by-path sites (`launch_descriptor_native.rs:88-221`, `PrivateOperator::tool`) and the three `inspect-stop-claim` path execs, which also get a deadline (spkC F4) | M | closes the hash-then-exec race on the public grain host, and leaves one bounded implementation | no |
| R8 | **The sponsor-escrow loop** | ssh shell, rooms | `enc-public` (`main.rs:695`) is the sponsor's input to `keygen --escrow-to-sponsor` (`:651`), and `escrow-recover` (`:697`) is its only exit. The rc report lists both as unreached. Add one journey row: sponsor `enc-public`, newcomer keygen with escrow, recovery | S | escrow stops being write-only | no |
| R9 | **Audit verbs into JAUDIT** | operator and auditor | `export-evidence`/`verify-evidence` are thin Host-CLI wrappers. Give them one row inside `JAUDIT` | S | an outsider can carry evidence off the box and re-verify it | no |
| R10 | **`fleet --action incoming`** | fleet | Wire it into the helm adapter and a fleet row (AFF §1.6: no caller) | S | agents can read their inbound turns: the helm-on-Mini north star | no |
| R11 | **Thin-consent proxy mode** | ssh proxy, SDKs | Make `JP2` (`jpriv2.sh`) a required row. Fix the "proxy cannot sign" docs (2.3) | S | friends sign from their own machines with no Store read | no |
| R12 | **Room-key release decided in Lean** | rooms, private rooms | `Kernel/RoomRelease{Current,Authority,Intent,Lineage,Admission}.lean`, `Host/RoomKeyReleaseAuthor.lean` and `Compiler/RoomKeyReleaseCodec.lean` exist and are imported only by `ResearchWip.lean:91-116` (rc §3 row 13). Wire them into the Host, and make `roomkey.rs:1712-2110` a consumer, not the decider | L | the derived path becomes the only path for who receives epoch e+1. Today "the clients decide" (`PrivateRoomKeys.lean:46-55`) | yes |
| R13 | **One agent-API generation that works** (if the decision row goes my way) | Hermes and SPK | Fix grain-runtime `application_api_tools.rs:1646-1647` (decode v3 replies as `binding-v3`…) and `:993` (`operationId`). Let `grain` write a non-empty `agents[]` (`grain.rs:1116`). Add one row where a Hermes resident reads EtherCalc through fd 3 | M | the first agent request to reach an SPK app | no |
| R14 | **Selected exchange across two machines** | fn transport | The journeyed exchange is loopback on one machine (`selected_exchange.rs:380`, `worker.rs:144-150`). Make the fn node address configurable and add a two-node row | M | "fn transport on" becomes a cross-node claim | no |
| R15 | **The attested-start boundary check** | SPK | `resident_launch::{start_attested, compare_attested_volume}` and `VolumeWitness::compare_open_mount` are written and uncalled; production uses `prepared.start` (spkB 5.1). Wire them, as their comments promise | S | one more physical check on the public grain | no |
| R16 | **Objective transparency check in CI** | Objective authoring | Add `transparency` to `local-gates.sh:84` `GATES`. Give `transparency.py:49` a timeout (bo F12) | S | the only executed check of stored-checkpoint transparency starts running | no |
| R17 | **Unjourneyed shell verbs** | ssh shell | Rows for `hermes status/cancel`, `adopt-next-key`, `app`, `home`, `key`. Put the 12 hidden live commands into USAGE, and make `mini` with no arguments exit non-zero (rc A F10) | S | the verbs a stranger can type are the verbs we have run | no |
| R18 | **`prover/` builds again** (not a demo surface, but the chosen Selvage backend) | proof system | Add an empty `[workspace]` table (or make it a member). Make `check-prover-glue.sh` compile the glue. Record the root `Cargo.lock` in `local-check.sh:410-411`. The untracked Uwueave pair is someone's live work; it is red twice (prv F2), and I leave it to its owner | S | 18 days of silent conformance drift end | no |

**Rescue total:** 2 L, 6 M, 1 S-M, 9 S, about **30 lane-days**. That is roughly one week of wall time across six
parallel lanes, and it can run beside the WSP §7 phase-1 lanes (R1-R4 touch the H and D lanes' files, so
give them to those lanes).

---

## 4. REPAIR, ranked by blast radius for a public box

| rank | defect | failure scenario | fix sketch | size | Lean? |
|---:|---|---|---|---|---|
| 1 | **Shared uid: every member reads every member's secrets.** The sponsor copies each newcomer's daily key into its own home (`OPERATOR.md:44-49`). `rotate-key` keeps the old key, the old next key and the after-next key in `attempts/rotate-ID/` forever (`key_rotation.rs:526-539`, D F-2) | a stranger enrolled by the door runs one `@FILE`-style path bug, or simply reads the files, and takes everyone's keys. Pre-rotation is defeated | run split tenancy (WSP 3.2). Switch onboarding to the existing `--action possess` flow. Delete retained secret copies after adoption | M | no |
| 2 | **One member can hold the single Host thread.** Public ops get a 600 s budget. With one uid, queue fairness degenerates to FIFO, and 32 slots fill (`transport.rs:53-68`, `serve_queue.rs:10-14`). `host_budget` labels ops 0 and 6-11 as Store-free, which is false (rc §3 row 24) | heavy NOCK dry runs, `law-sat`, `can --all` or 4 MiB authors back to back; everyone else gets `254 busy` after 60 s | lower the public Host budget (30-60 s), keep per-uid fair share (it works once rank 1 lands), emit a per-op cost class | S-M | small (cost class) |
| 3 | **Render DoS and terminal escapes on the shared-document path.** One malformed `mini-name` link breaks every reader's `doc show`, web page and search (E F2). OSC 52 and cursor escapes come through `doc history`/`diff` (E F1) | any member poisons a shared demo document. The static docuverse snapshot (WSP W2) fails to render it | render an invalid binding as invalid, never as an error; pass `text::one_line` through history and diff | S | no |
| 4 | **"Undecided" is shown as "refused", and money reruns keep no record.** 255 is shown as refused at four sites (`main.rs:1349-1364` → `shell.rs:2452-2468`, checked; `well.rs:78-85`; `activity.rs:61-74`; web). `credit pay/topup/refund`, `well mint/burn/floor`, `activity submit` and `workspace submit` without `--attempt` author a fresh nonce on rerun (rc §5.2 P4) | an ssh drop after submit, the member reruns: two room payments, or two mints (rc §5.3: high) | classify only by decoded outcome type; refuse a rerun without its operation record (`credit turn/return` already do this) | M | Q1, Q2 answers only |
| 5 | **The public SPK grain fences itself for everyone.** One non-definite op 34/164 leaves `native-dispatch-active.json` in the generation journal, and nothing clears it short of STOP plus a new generation (spkC S1/F1). Every request leaves a `dispatch-op-N/` directory (up to 96.8 MB of inspection) that nothing collects (F2b). Any aux-fd error ends the generation (spkB 12), and `StartLimitBurst=3` then leaves the app down | one guest's request times out. EtherCalc refuses every visitor for 7-51 minutes, and the disk bounds uptime | fence per call: look up the exact call, as the agent paths already do per route. Collect retained dispatch directories after a confirmed outcome. Do not end the generation on aux-fd errors | M | no (Q 8.1 on contention and 255) |
| 6 | **The Hermes pool route bricks on one non-200 reply.** `quoteResponse` throws for non-user routes when the status is not 200 (`Host/ProviderUsage.lean:267-268`, checked), and the controller retains a note it cannot clear (`main.rs:9222-9245`, checked). The same dead state follows an upstream timeout, a malformed header block, or a crash after the send boundary (gr H1-H6). WSP H3 plans **pool and homelab rows only** for week 1 | a 429 from OpenRouter: that member's Hermes refuses all work until an operator reconciles by hand | Lean quotes a non-200 metered reply (fee or zero) and adds one settle-uncertain-provider transition. Align the gateway and broker header bounds (32 vs 64 KiB). Give every subprocess a deadline (H12) | M-L | **yes** |
| 7 | **A compromised resident is the world operator.** The resident runs on the host mount namespace as the operator uid. `broker_home::render` returns an empty drop-in while its name promises hardening (spkB 1, `broker_home.rs:202-208`). The sandbox-floor audit cannot run against today's spawn path (spkB 3). The sandbox gives the app the host hostname, a writable `/dev` and a full `/proc` | an fd-3 parser bug in EtherCalc's bridge yields every participant seed and the Mini operator socket | put the grain in its own `mini-grain` world (WSP W7). Make `broker_home` render real `ProtectSystem`/`ProtectHome`. Re-point `sandbox-floor-audit.sh` at `spawn_bounded`. Add Sandstorm's dummy hostname, a minimal `/dev` and `RLIMIT_NOFILE` | M | no |
| 8 | **mini-keys: DoS and fail-open.** 32 global slots, no per-uid share; a 20 MiB allocation before the op is known; about 700 MB of SHA-256 per member action (vk B-F3). The audit write fails open (B-F7). Op 144 trusts whoever answers at `publicSocket` (B-F4). Grant caps are checked against the controller's claims, not the body (B-F1) | any member with a broker role starves Hermes's provider calls. A full disk keeps unsealing keys with no audit | per-uid slots; read the op byte before sizing the frame; hash the Host image once per process; refuse any operation that cannot be audited; pin the answering uid for op 144; parse the forwarded body's `model`/`max_tokens` | S-M | no |
| 9 | **Discord: sponsor mapping, double execution, unbounded custody.** The example roster maps a Discord id to `ember`, which signs as factory controller (dep 4.14). A deferral that misses Discord's 3 s window makes the user retry, and the retry runs with a new interaction id (ds 4a.3). Custody keeps 2 MiB per interaction forever (4a.5). The unit's `NoNewPrivileges=yes` blocks the split-mode sudo (4a.9) | one roster edit, or a stolen Discord account, acts as the sponsor; a slow disk doubles a pay line | the door-rendered roster refuses sponsor and operator names; write the response before any fsync; retention caps (WSP D2); fix the unit for split mode | S | no |
| 10 | **PAY watcher can lose payments for good.** The journal floor comes from `PAY_JOURNAL_FLOOR`, not the signed tariff, and below-floor transfers pass the cursor (spl F10). A newest-100 window can be flooded with dust (F11). A stuck pending tick halts all PAY with no quarantine verb (F13). Nullifier attribution is guessed (C D3/F4) | the tariff floor drops and the env var does not: a stranger pays and is never enrolled | read `tariff.journalFloor` from the signed view; treat `PageBound` as a refusal; add an operator quarantine for a pending tick; the observation receiver names the spent nullifier | S-M | small (Q34) |
| 11 | **Concierge money bugs.** It keys on `ledger:HEIGHT`, so a second payment at one height is never honoured or refunded (gr H10). A failed refund is final, and `refunding` is write-only (H11) | a member who pays twice in one block loses the second payment | key on `transactionId`; make refund an exact-lookup operation with a record. Long term: paid-slot admission in Lean (R5 row of gr §3) | S-M | long-term yes |
| 12 | **`fleet-sign` treats `uncertain` as never admitted** and deletes the record (`fleet_sign.rs:510-511,545`, D F-3) | double fleet commit on the helm-on-Mini path | treat `uncertain` and `unavailable` as unknown and look up the exact call | S | no |
| 13 | **Key rotation wedges forever** on a refused submit, because op 142 returns its refusal inside a 142 frame (`key_rotation.rs:679-684,748-751`, D F-1; JROT 3/30 red) | a member's rotation is stuck at "submitted" and `--new-attempt` is refused | decode the 142 outcome type; allow a successor after a decoded no-effect refusal | S-M | Q2 |
| 14 | **SQ durable store.** Bound violations come back as exit 4, which Lean reads as CAS conflict and retries forever (spl F1). Reads fsync and fail on a full or read-only disk (F2). The anchor is published before the genesis seed commits (F4) | a codec change livelocks appends. A full disk takes down read-only docuverse queries | a distinct exit code for bound violations; reads never publish; wrap `durable-anchor-enroll`; document the anchor for backup | S | no (map the new exit code) |
| 15 | **Shipped surfaces the box should not carry.** `testProvider` and `launchGate` are production roles; `lib.sh:65-68` demands 15 roles; the Store unit lacks `ProtectSystem`/`RestrictAddressFamilies`/`MemoryMax` (dep 4.6, 4.8, 4.9); `mini-pay-watcher.service` may write all of `/var/lib/mini` (4.13); `MINI_REPLAN_LOG` appends to any writable path | defense in depth only | drop the fixtures from `ROLES`; make optional roles optional; harden the Store unit; narrow `ReadWritePaths` | S | no |
| 16 | **Operator-only ops are protected only by Rust routing.** 69 ops sit behind `allowed_operator_operation`, checked against hand JSON. The v1 envelope is still accepted while the README says it is gone. Fn ACK ops 13/15 are public with an open authorization question | one list slip makes an operator op public. A member pre-ACKs fn transactions if the fn service is configured on the public Host | refuse v1 after migrating its 3 senders and 9 scripts; route 13/15 operator-only until Q8.2 is answered; a Lean statement of which operator ops are safe against any caller (rc Q15) | S (+Lean Q) | partly |
| 17 | **Laws, genesis and defaults authored in Rust.** `document_law`/`room_law`/`board_law` (`shell.rs:147-187,709-719`), story laws (Rust emits, Lean imitates, rc §3 row 5), chat and keys law JSON, permit-all genesis factory and account predicates (`genesis.sh:125,136,146`), permit-all member-account and Hermes till laws | a typo silently changes who may write every demo document. Under permit-all, any holder of a factory observe grant may birth | emit them from Lean, as the job law already is (`Kernel/Job.lean` → `gen-joblaw.py`); add a Lean genesis author | M | **yes** |
| 18 | **Failed-START recovery is v3-only** on both sides (`grain_export.rs:455-480`, `Host/ApplicationFailedStartRecoveryTools.lean:96-101`), while a failed create retries on v4 | a failed public grain start on the retry lane cannot be reconciled | decode v4 in the Lean tool and in `grain_export` | M | yes |
| 19 | **About 15 hand-rolled custody machines** beside `mini_sdk::custody`, with two retry philosophies (rc §4.1, §5.4) | the source of ranks 4, 12 and 13 | one machine (R5), ops and formats as parameters | L | Q5, Q6, Q9 |
| 20 | **Literal op numbers and twin helpers.** 159 literal call sites bypass `native/host-operations.rs`. There are 5 Rust copies of `ordinaryHeaderName`, 8 decimal validators with 3 rules, about 13 bounded readers, and 3 BPF assemblers | drift that byte goldens cannot see | migrate to the generated constants and make the registry check scan for literals; generate the header list from `ApplicationDispatchAdmission.lean:116-120`; one shared helper module per family | M | small (emit tables) |
| 21 | `launch-gate.rs:13` hard-codes the x86-64 value of `O_NOFOLLOW` | silent loss of no-follow if anyone builds on an arm64 (CAX) box | use `libc::O_NOFOLLOW`. Latent: WSP 0.2 picks cx43, which is x86 | S | no |

---

## 5. Where I disagree with the crate reports

1. **Every "demo-minimal" cut was scoped to a shape ember has overruled.** dep §9 deletes `discord/`,
   `pay/`, `hermes/`, `hermes-dispatch/` and most of `spk-host/`. rc §6.2 tier 1 drops pay, chat, private
   rooms, `fleet_sign`, web and Hermes handoff (72.6K lines). gr §6.2 drops rooms, resident, concierge and
   homelab. With every surface on, these are **not deletion numbers**. I count none of them, and several
   of the "drops" are my rescues and repairs (R1-R4, R10, ranks 9-13).
2. **Homelab (gr §6.2 drops 696 lines; spl says the scheduler is not needed).** WSP H3 plans pool and
   homelab rows for week 1, so homelab and inference-scheduler are rescues (R3).
3. **The pool route.** gr §9.8 rules "user route only" because a 429 bricks a pool grain. WSP H3 plans
   "pool and homelab rows only" and no user rows. AFF §8 says it found no outright disagreement; this is
   one. The week-1 Hermes surface needs repair rank 6, which includes a Lean change, before it opens. The
   alternative is to start with user rows, which the door cannot automate.
4. **Provider retirements** (gr §6.2 "deferred", 1,152 lines). Keep them. They are the exits from the very
   dead states rank 6 is about.
5. **`escrow-recover` and `enc-public`** (rc §2 "unreached: delete"). They are the two ends of a flow that
   `keygen --escrow-to-sponsor` already writes (`main.rs:651,695,697`, checked). Deleting them makes
   escrow write-only. They are a rescue (R8).
6. **The `key-service*` tombstones** (rc §2 "delete"). Keep them. Three lines that refuse by name with a
   pointer to `mini-keys` (`main.rs:3233-3237`, checked) are law 10's loud refusal, not dead code.
7. **`pinned_execution.rs`** (tiny §10.5 "delete, or make it the one"). Make it the one. It is the better
   twin, the only bounded one, and spk-host's launch path has the hash-then-exec race it closes (R7).
8. **mini-sdk Part B** (sdk "delete today without breaking a build"). The SDK surface is on. Law 13 says
   keep the better twin and repair it. The working code is resource-client's, but the right home is the
   SDK, so move it in (R5) and delete the SDK's broken copies afterwards (S4). Deleting Part B outright
   would leave the SDK surface with no client at all.
9. **`deploy/shell/mini-shell-ssh-credentials`** (dep §9 "delete: split tenancy on no box"). Keep it.
   Split tenancy is WSP step 3.2, and BYOK credentials ride on it.
10. **`prover/`** (prv "a public demo needs zero lines"). That is true, but it is the chosen Selvage proof
    backend, not a scar. Repair the build (R18); do not count it as deletable. By contrast,
    **bend-ir2-proof** (bo "delete if the Plonky3 route is abandoned"): PROOF-SYSTEM-SURVEY already chose
    Selvage, the crate cannot be reproduced by construction, and it depends on breadstuffs. I delete it.
11. **spk-host v4 retry lane** (spkC §6.3 "optional drop, 2,255"). Keep it. Without it, a failed first
    CREATE on the public grain needs a new app birth. Delete only its Rust StreamCodec (row 33) and fix
    the recovery gap (rank 18).
12. **rc §7.6 "without an authorized ssh key: nothing in this crate."** True of today's node, but week 1
    puts `enrollment-bootstrap` behind Caddy at `/mini/v1/*` (WSP P2). Its accept loop, anchor retention
    and one-shared-rate-bucket defaults (D F-16/F-17) become stranger-facing, and `--trusted-proxy` must
    be set. That belongs with repair rank 15.
13. **The deploy MUD data** (dep §9 "delete"). I make it a decision row. It is game content, not code;
    `sim.py`, the `Pred.eval` twin, is the scar, and I delete that outright (row 38).
14. **The agent API** (gr §5.1 "either fix C-F3 and delete v2, or delete v3 and keep v2"; spkC §6.3 "drop
    both generations for the demo"). With Hermes and SPK both on, keep **one**: lifetime v3, rescued by two
    named bug fixes (R13). Dropping both throws away the only composition of two on surfaces.
15. **The fn consumer worker** (rc §2 "delete outright"). I agree in the end, but not for rc's reason.
    rc's reason is "not demo". Mine is that fn transport is on through the selected exchange, and that the
    consumer would be rebuilt against a protocol being rewritten. It is a decision row, and I give the
    rescue cost.
16. **Studio.** No disagreement: D7 is ember's ruling, rc and WSP agree, and it is deleted (row 14).

---

## 6. The three-line summary

1. **Delete about 24,400 lines of code now** (45 rows, mostly H confidence), plus about 4,400 non-code lines
   (capnp, locks, provisioning). Delete about 2,900 more once their rescue or repair lands. Rewrite about
   670 lines of lying contract prose. Ember's decision rows could remove up to about 47,800 more
   (private-backend 26K, traffic stack 2 5.2K, agent v1/v2 6.6K, fn consumer 3.6K, MUD data 4.5K,
   objective C machine 1.5K).
2. **Rescue effort is about 30 lane-days** (2 L, 6 M, 1 S-M, 9 S), about one week of wall time across six
   lanes. Lean changes are needed for R12 (room-key release) and a small one for R5 (the consent op list).
3. **Five repairs before strangers:**
   (1) end shared-uid secret exposure: split tenancy, no sponsor-held or rotation-retained copies;
   (2) cap Host-thread monopolization with a short public-op budget and per-uid fairness;
   (3) fix the shared-document render DoS and terminal escapes (E F2, E F1);
   (4) stop showing undecided outcomes as refused, and refuse record-less money reruns (credit, well, activity);
   (5) make the public SPK grain fence per call, collect dispatch directories, and survive aux-fd errors.

   Before Hermes opens, also do repair rank 6, the pool-route 429 brick, which needs a Lean change.
