# resource-client, shard F: chat, story, Hermes, activities, private rooms, fn, selected-source publication, refusals

| | |
|---|---|
| Shard | `native/resource-client`, shard F: "chat, story, hermes, activities, private, fn, roomkey, selected-source publication, refusals" |
| Crate | `minidregg-resource-client` (binary `mini`, `native/resource-client/Cargo.toml:9-11`), a root-workspace member. Every file below is a module of the one `mini` binary, declared in `src/main.rs:21-142` except `private.rs` and `roomkey.rs`, which are declared inside `workspace.rs` with `#[path]` (`src/workspace.rs:43-48`), so their paths are `crate::workspace::private` and `crate::workspace::roomkey`. |
| Date | 2026-10-26 |
| Reader | Opus, read-only. No build or test was run. Every claim comes from reading source and evidence files; `path:line` is given for each. |
| Scratch | `/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/rc-F/` (`ops.txt` = the registry dump, `sizes.tsv` = line/test counts, `testlines.py`) |

Files covered, every one read in full (paths under `native/resource-client/src/` unless noted):

| File | Lines | of which `#[cfg(test)]` | `#[test]` count |
|---|---:|---:|---:|
| `chat.rs` | 2,642 | 311 | 14 |
| `story.rs` | 1,246 | 103 | 7 |
| `hermes.rs` | 1,011 | 203 | 12 |
| `hermes_handoff.rs` | 1,359 | 328 | 13 |
| `activity.rs` | 323 | 0 | 0 |
| `bend_session.rs` | 75 | 0 | 0 |
| `objective_invoke.rs` | 69 | 0 | 0 |
| `provider_continuity.rs` | 1,272 | 429 | 14 |
| `private.rs` | 1,440 | 511 | 27 |
| `fn_namespace.rs` | 704 | 158 | 4 |
| `fn_frontier.rs` | 758 | 108 | 5 |
| `roomkey.rs` | 3,863 | 989 | 34 |
| `publisher.rs` | 552 | 126 | 5 |
| `selected_publisher.rs` | 635 | 141 | 4 |
| `selected_exchange.rs` | 978 | 131 | 6 |
| `selected_release.rs` | 411 | 127 | 2 |
| `native/resource-client/selected-release-drop-reply.rs` | 95 | 0 | 0 |
| `replan.rs` | 561 | 258 | 14 |
| `prepare_refusal.rs` | 160 | 77 | 2 |
| `query_refusal.rs` | 151 | 80 | 2 |
| `capture.rs` | 125 | 20 | 1 |
| **Total** | **18,430** | **4,100** (22%) | **166** |

Context also read (not owned): `Cargo.toml`; root `README.md` "Honest state"; `native/resource-client/README.md` (relevant sections); `SELECTED-EXCHANGE.md`; `SELECTED-SOURCE-PUBLISHER.md`; `journey.d/jchat.sh`, `j14.sh`, `j15.sh`, `jpriv1.sh` (headers and every `mini` call), `journey-private.sh`, `selected-exchange-journey.sh` (phases called), `selected-release-acceptance.sh:375-390`, `selected-source-drop-reply.sh`, `activity_world.py:320-445`, the `objective-*.py` drivers (which `mini` verbs they call); `scripts/pipeline/journey-rows` (row list); `docs/OBJECTIVE-BEND-EVENTS.md:140-200`; `docs/SEATS.md:14-15`; `deploy/hermes-dispatch/README.md`; the room/Hermes templates under `deploy/shell/templates/`; `protocol/host-operations.json` (every byte this shard sends); the Lean receivers named in section 2; `Kernel/PrivateRoomKeys.lean:1-88`; the headers of `Kernel/RoomRelease*.lean`, `Kernel/RoomKick.lean`, `Kernel/PrivateRoomWrapGrant.lean`; `Assurance/StoryLaw.lean` (declaration list); `scripts/gen-storylaw.py` (header); and these evidence directories: `docs/evidence/2026-10-01-p-hermes-room/`, `2026-10-01-p-story/`, `2026-10-01-p-credit/`, `2026-10-08-selected-exchange-local-fn/`, `2026-09-27-fn-namespace-custody/`, `2026-09-27-fn-namespace-native-r3/`, `2026-09-27-fn-frontier-receiving/`, `2026-09-27-fn-consumer-namespace-frontier/`.

## Executive summary

1. The shard is seven families inside one binary: (A) the refusal-retention and re-plan engine every signed command uses (`replan.rs`, `prepare_refusal.rs`, `query_refusal.rs`, 872 lines); (B) the "composing" shell verbs chat, story and Hermes plus the in-process runner `capture.rs` (5,024 lines); (C) private-room cryptography and the room-key protocol (`private.rs` + `roomkey.rs`, 5,303 lines); (D) the Hermes resident handoff and inference-provider continuity (`hermes_handoff.rs`, `provider_continuity.rs`, 2,631 lines); (E) Objective Bend activity/invoke/session signing (467 lines); (F) the fn consumer custody (`fn_namespace.rs`, `fn_frontier.rs`, 1,462 lines); (G) selected-source publication and exchange (`publisher.rs`, `selected_publisher.rs`, `selected_exchange.rs`, `selected_release.rs`, drop-reply fixture, 2,671 lines).
2. **"In-process operations: 336b7c0e" does not mean chat bypasses the Host.** Commit `336b7c0e` replaced chat's child `mini` processes with `crate::run` called in the same process under a process-wide fd-1/fd-2 swap (`capture.rs:60-104`, `chat.rs:657-668`). Every chat read is still a signed query over the socket (`chat.rs:763-825` → `main.rs:2169-2185`) and every write still a workspace propose/submit. What chat decides locally is presentation: the merge order, "only the founder's topic and pin count", reactions (`chat.rs:29-46`, `:930-1038`). That is a Rust-defined room semantic no Lean module states.
3. **README's chat row is stale in one direction:** J14 PASS (`docs/evidence/2026-10-01-p-hermes-room/j14.tsv:33,38`, `tail-final.txt`) ran `chat new`, `chat invite`, `say`, `tail` and `ask` through `mini shell` against a native Host on a lane build. That run predates both `336b7c0e` and ROOM-SCHEMA v2, so the current chat code has no recorded run. JCHAT is SKIPPED in all three 10-01 results.
4. **Retry policy is decided in Rust in chat, outside `replan.rs`.** `chat.rs` has its own stale-root loop (10 tries, `chat.rs:683-758`, `:785-807`), matched on stderr text (`"refused: stale-root"`, `:686`). It wraps `replan.rs`'s loop (5 re-plans, `replan.rs:37`), so one `say` can make up to 60 signed attempts. It also has a re-propose loop that authors a NEW proposal (a fresh nonce) whenever a refusal's text contains `staleTarget` (`chat.rs:1558-1571`). `replan.rs` itself replans only on (a) Lean's `stale-root` reason, (b) the local consent provider's stale-observation flag, (c) in the append path, a decoded final `admission`-phase refusal or the exact `DeclaredResourceController.Reject.staleTarget` prepare detail, each plus a signed read proving the preimage moved. Plain `submit`/`query` replans re-submit the **same** intent; only the append path and chat's staleTarget loop author a different operation (section 3, V4-V5).
5. **`story.rs` is the law emitter, and Lean imitates it.** `player_law` generates the sealed law installed on every player's cell for any author-supplied table (`story.rs:311-359`), and `table_of` is the only checker of tables (`story.rs:146-259`). `Assurance/StoryLaw.lean` proves its theorems about a Lean `law` that `scripts/gen-storylaw.py` checks by `rfl` against this generator's output **for the one built-in tale only**. This is ATLAS law 13 inverted: Rust emits, Lean imitates.
6. **Room keys and membership.** A room key is a random 32-byte XChaCha20-Poly1305 key per epoch. The founder's client draws it (`private.rs:146-157`) and wraps it to each member's hybrid X25519 + ML-KEM-768 key in the room's `keys` cell (`roomkey.rs:1-111`). Membership authority is Lean's: room grants are delegations, a kick is revocations (`Kernel/RoomKick.lean`), and the `who` view decides who is current (`Host/Json.lean:1509`). **Key entitlement is Rust's alone.** Who gets epoch e+1 is computed client-side as members at the head epoch, intersected with `who`, minus the kicked subject (`roomkey.rs:1301-1326`, `:2582-2629`), and the epoch chain, founder-key chain and release state machine are all client verification. `Kernel/PrivateRoomKeys.lean`'s `keysLaw` checks only atom ids and writers. A Lean release receiver (`Kernel/RoomRelease*.lean`, `Host/RoomKeyReleaseAuthor.lean`, "event67") exists but is imported only by `ResearchWip.lean:91-116`: unwired.
7. **`private.rs` talks to no backend.** It is pure client cryptography (envelopes, wraps, Argon2id key cache). It has no dependency on the `private-backend` crate (`Cargo.toml` lists none) and no socket call; `roomkey.rs` moves its bytes through ordinary content writes and signed reads.
8. **The fn consumer is unreached.** `fn_namespace.rs` and `fn_frontier.rs` are reached only by their six `mini fn-*` arms (`main.rs:4232-4299`) and by `selected-exchange --phase cover-plan|cover-advance` (`selected_exchange.rs:594-623`). No journey, unit or script calls either. The one native run on record (2026-09-27 r3) ended with op 40 refused and op 41 absent (`docs/evidence/2026-09-27-fn-namespace-native-r3/README.md`).
9. **Selected-source publication.** The four modules are not one twin set: `selected_release.rs` (ops 20/21) and `selected_publisher.rs` (Host-CLI ops 24/25 + NNTP POST) are layers that `selected_exchange.rs` composes. `publisher.rs` (`origin-publish`) **is** a twin of `selected_publisher.rs`'s POST custody, with a different repost rule (one re-POST after transport loss, `publisher.rs:264-281`, versus never, `selected_publisher.rs:357-375`). The 2026-10-08 evidence ran only `prepare`, `publish`, `receive-transport` and `verify-transport` (`selected-exchange-journey.sh:417-556`). `receive`, `cover-*`, `ack`, `verify`, `origin-publish` and `selected-release-retry` have no caller.
10. **Byte agreement with Lean holds for every op checked:** 7-11 (local codec), 17 v1/v2/v3, 18, 20/21, 40-43, 60-65, 144, 210-214. Exceptions: the local-consent endpoints 224/226/227 are absent from `protocol/host-operations.json`, and `activity.rs` prints a 255 frame as lossy text instead of asking Lean to decode it (`activity.rs:61-74`).
11. Lost-reply hazards. `mini activity --action submit` mints a fresh nonce on every run for non-`invoke` turns (`activity.rs:114-127`), so re-running a lost `topUp` with a new `--out` authors a second operation. A kick whose rotation fails leaves a revoked member holding the live epoch (`roomkey.rs:2756-2768`). A chat invite is a non-atomic four-step sequence (grant, stream, roster row, wrap; `chat.rs:2147-2212`).
12. Laws authored in Rust: chat's author law and private-room laws come from template files (`include_str!`, `chat.rs:137`, `roomkey.rs:133-135`). Hermes's till and budget account get permit-all laws (`hermes.rs:621-625`, `:637`). Every delegation hard-codes `maxCost "50000"` (`chat.rs:1979`, `hermes.rs:522`, `story.rs:878`, `roomkey.rs:2145`).
13. Twins: `fn_namespace.rs`/`fn_frontier.rs` are structurally duplicated (same pin/approval/marker/lookup machine). There are two fd-swap mechanisms (`capture::streams` and `hermes::quietly`). `story::render`/`explained` re-implement `Compiler/RefusalReason.lean` `renderClause`/`LawLeaf.explained`. Hermes field literals `"1008"`/`"1009"` duplicate `room_schema::TARIFF_FIELDS`. `roomkey.rs`'s release state machine is the live twin of the unwired Lean event67 receiver.
14. Tests: 166 `#[test]` in 4,100 lines. Most are real negative/positive pole tests of local state machines. Several only test the module's own fixtures: `roomkey`'s `FakeHost`, `publisher`/`selected_publisher` `post_action` tables, and the chat merge tests run on a hand-built `Entry` list. None exercises the Lean side.
15. For a Hetzner demo without rooms, only the 872-line refusal/re-plan core in this shard is needed, plus `activity.rs`/`objective_invoke.rs` (392) if Objective is shown. The rest (17,166 lines) is droppable from this shard, but `private.rs`/`roomkey.rs` are referenced from `workspace.rs`, `shell.rs`, `key_rotation.rs`, `main.rs`, `context_projection.rs`, `doc_search.rs` and `render/mod.rs`, so dropping them needs edits in other shards. `keygen` also uses `private.rs` (notice, hosted marker, escrow, `main.rs:1140-1166`), so that slice must stay (section 6).

---

## 1. What this code is and does

### 1.0 The lead's eight questions, settled

**(1) roomkey.rs: what a room key is, who derives it, who decides membership, whether Lean should own any of it.**
- *What it is.* A room key `k_R^e` is a 32-byte XChaCha20-Poly1305 key with a `u32` epoch (`private.rs:146-180`). It is drawn from OS randomness (`RoomKey::generate`, `private.rs:152-157`), never derived; "rotation draws a fresh key; it is not derived from the old one" (`private.rs:144-145`).
- *Who derives it.* The founder's client draws `k^0` at `found` (`roomkey.rs:2198-2256`). Every later epoch is drawn by whoever is the tip of the founder-key chain at `rotate`/`kick` (`roomkey.rs:2582-2629`, `require_tip` `:1809-1814`). Members never derive a key; they unwrap a wrap addressed to their hybrid key (`roomkey.rs:1164-1177`, `sync` `:1550-1612`).
- *Where it lives.* Wraps live in the room's `keys` content cell, partitioned by atom id (`roomkey.rs:15-37`, `wrap_atom_id` `:925-927`, `release_atom_id` `:718-720`, `transition_atom_id` `:530-532`). The node stores wraps, never keys. Clients keep held epochs in an Argon2id-sealed cache `ROOT/private/keys.cache` (`roomkey.rs:1443-1461`, `private.rs:688-777`).
- *Membership.* Who is in the room is a capability question. The room grant is a delegation (`chat.rs:1977-1989`, `roomkey::admit_invitation_grant` `:1697-1701`). A kick is "every standing grant the member holds under the room" revoked (`roomkey.rs:2765-2766` → `workspace::room_kick`), and Lean's `who` view is what clients read as "current members" (`chat.rs:1044-1058`, `roomkey.rs:1789-1796`). Lean owns that.
- *Is adding/removing a member a re-keying?* Removing is: `kick` = revoke, then `rotate` with `dropped = subject` (`roomkey.rs:2756-2768`). Adding is not: an invite releases the **current** epoch (or, with `--past`, every held epoch) to the invitee (`roomkey.rs:2476-2557`).
- *Rust decisions Lean could own.* Which members receive epoch e+1 (`rotation`, `roomkey.rs:1301-1326`: members at the head ∩ `who` − dropped); which epoch is current and whether a served lineage is acceptable (`check_epoch_chain` `:271-310`, `verify_lineage` `:856-884`, `check_chain_not_rolled_back` `:341-350`); the founder-key chain (`FounderChain::verify` `:667-699`); the two-phase release state machine (`run_release` `:2059-2110`). `Kernel/PrivateRoomKeys.lean:46-55` itself says "Which epoch is current, that a wrap is the founder's, that a re-wrap is addressed to the member's CURRENT record ... The clients decide". The *cryptography* cannot move to Lean. The *entitlement* (who must hold a wrap at the head epoch) can, and a Lean candidate exists: `Kernel/RoomReleaseCurrent.lean`'s header says it checks "every recipient's encryption record and offline room read entitlement". It is not on the import path of the Host; only `ResearchWip.lean:91-116` imports it.
- *Lean room ops.* The ones that exist and are live: `Kernel/RoomBirthGate*.lean`, `Kernel/RoomKick.lean` (imported by `Kernel.lean:11`), `Kernel/PrivateRoomKeys.lean` (`Kernel.lean:155`), `Kernel/PrivateRoomWrapGrant.lean` (`Kernel.lean:156`, self-described "AUTHORED, NOT COMPILED" at `Kernel.lean:156`). No Lean module knows the chat roster (fields `ROSTER_FROM..`, `room_schema.rs:30`). The roster is a Rust-defined data structure in a founder-written cell.

**(2) chat.rs "in-process operations".** Answered in executive summary item 2. `chat::client` (`chat.rs:657-668`) calls `capture::command` (`capture.rs:81-104`), which builds an `Args` and calls `crate::run(args)` in this process, with fds 1 and 2 pointed at anonymous `tmpfile(3)` files (`capture.rs:22-77`). The ending is produced by the same `crate::main_ending` that `main` uses (`main.rs:4527-4535`). Every workspace operation inside still goes to the Host over the selected socket (`main.rs:596-613`). Ops 7-11 go to the local codec child, as for any command (`main.rs:603-605`). This is not a twin of the Host's receiver. It is a twin of the *child-process boundary*, and it has a sibling, `hermes::quietly` (`hermes.rs:405-435`), which redirects fd 1 to `/dev/null` by hand-declared `extern "C" dup/dup2/close`.

**(3) Hermes from the client side; who decides what.** Five cooperating pieces:
- *Founder's `mini shell`.* `summon`/`ask`/`dismiss`/`hermes status|cancel` (`hermes.rs`) compose ordinary signed operations: till birth, a funded account, chat invite, role document laws and delegations, the program document, room fields, and a signed handoff bundle (`hermes.rs:568-738`, `hermes_handoff::seal` `:190-232`).
- *Operator dispatcher.* `deploy/hermes-dispatch/mini-hermes-dispatch.py:72` runs `mini hermes-handoff --action dispatch`, which verifies the bundle and stages it into the resident's inbox (`hermes_handoff.rs:961-994`, `publish` `:885-930`).
- *Resident controller.* `native/grain-runtime/src/hermes_room.rs:516-529` runs `mini hermes-handoff --action check-delivery|check-dismissal` before acting.
- *Inference-provider continuity.* `grain-runtime` calls `mini submit --provider-continuity DESCRIPTOR` (`native/grain-runtime/src/main.rs:8317`) and `mini provider-continuity --guarded-attempt` (`native/grain-runtime/src/provider_resolution.rs:387-394`).
- *What Lean decides.* Every grant, birth, law install, write, revoke and transfer. Op 144 key status (`Host/Main.lean:7027-7039`). Historical-call lookup. Op 17 continuity verdicts (`Host/Main.lean:6718-6724`, `runProviderContinuitySession` around `:5552`). The `author`/`assemble`/`pin-plan-height`/`inspect` codecs.
- *What grain-runtime decides* (other shard). When to act, provider calls, holds.
- *What this shard's Rust decides.* Which registered resident a summon selects (`select_registration`, `hermes.rs:480-511`). Whether a handoff bundle is acceptable (Ed25519 `verify_strict` over a domain-separated payload, `hermes_handoff.rs:71-124`; founder key current via op 144; origin call re-verified, `:305-493`). Which assignment is "current" (by comparing `acceptedCount` strings, `point_current` `:691-744`). Request-status classification and "cancellable" (`hermes.rs:201-240`). Whether a guarded provider attempt is "retire-expired-contention" (`provider_continuity::expiration` `:436-477`, decision string `:832`).
- *What `provider_continuity` re-derives.* It re-runs exact lookup of the retained call (`:653-672`). It re-decodes every retained outcome and plan through the pinned Host and compares them with the retained JSON (`:712-739`). It re-checks that the pinned plan differs from the original only in each slot's `validUntil` and canonical header (`verify_pinned` `:227-266`). It re-authors the settlement command with `author grain` and checks it is the plan's `finalizedDraft` (`:741-758`). It re-assembles the call from plan + signatures and compares bytes (`:759-774`). It re-sends op 17 v3 with the original checked point (`:816-825`). It computes expiry from the Host profile's `genesisHeight` + `checkedAcceptedCount` against every signed `validUntil` (`:436-477`).

**(4) private.rs and the private backend.** `private.rs` does not reach the `private-backend` crate (no dependency in `native/resource-client/Cargo.toml:13-39`), does not open a socket, and does not call the Host. It is a library of pure functions:
- `PrivateEnvelope/v2` seal/open with a cSHAKE256 commitment bound to (room, cell, address, epoch) (`private.rs:274-393`);
- 64-byte length classes (`:238-253`);
- hybrid wraps (`:572-656`), escrow (`:659-669`);
- the encryption keyring kept across signing-key rotations (`:486-562`);
- the Argon2id key cache (`:673-777`);
- `legacy_content` (`:788-820`), which refuses any fresh private document text ("requires protected-document audience enrollment").
The Host sees only ciphertext atoms whose kind is `inlineObject(schema)` (`private.rs:3-9`).

**(5) fn_namespace / fn_frontier.** Confirmed: no journey row, systemd unit, deploy script or other crate calls any of the six `fn-namespace-*`/`fn-frontier-*` commands (grep over `scripts/ deploy/ native/ testing/` finds no caller). The only indirect path, `selected-exchange --phase cover-plan|cover-advance`, is also never called (`selected-exchange-journey.sh` calls only `prepare`, `publish`, `receive-transport`, `verify-transport`: `:417`, `:420`, `:433`, `:446-447`, `:556`).
- Evidence: a unit-level checkpoint (`docs/evidence/2026-09-27-fn-namespace-custody/README.md`: "This is a **client state-machine** result"), and one manual native attempt that ended "op40 definite admission refusal … op41 exact original absent" (`2026-09-27-fn-namespace-native-r3/README.md`, the artifact table).
- What they need to be live:
  - (a) A Host whose fn consumer `service` is configured; otherwise ops 40/42/43/64/65 return 255 "fn consumer service is not configured" (`Host/Main.lean:7493-7495`, `:7288-7290`).
  - (b) An enrolled gateway key and a hand-written approval JSON that mirrors ~21-28 inspection fields (`fn_namespace.rs:178-229`, `fn_frontier.rs:330-391`). No tool authors that approval.
  - (c) An operator-private socket (`check_private_socket`).
  - (d) For the frontier, fn-e accepted articles. Current fn POST stores fn-r, and SELECTED-EXCHANGE.md says the cover path "refuses `fn-r`".
  - (e) A driver: a journey row, a timer unit or an operator runbook. None exists.
  - (f) A Lean-side diagnosis of the r3 op40 refusal ("source-side read-only diagnosis is pending", r3 README).

**(6) publisher / selected_publisher / selected_exchange / selected_release.**
- *`selected_release.rs`.* Transports a Lean-authored recipient ingress over ops 20/21 with markers and exact retry (`selected_release.rs:158-283`).
- *`selected_publisher.rs`.* Signs the source `.delegateObject` header the Host selects (`sign_source`, `:11-77`, Host CLI `selected-release-source-plan`/`-assemble`). It admits event14 through Host-CLI routes `selected-source-publication-submit|lookup` (ops 24/25, "currently Host stdio only, socket route not present", `protocol/host-operations.json` codes 24-25; Lean arms at `Host/Main.lean:2093-2098`). It then POSTs the exact article once (`:388-493`).
- *`selected_exchange.rs`.* Composes those two with Host CLI `query`, `selected-release-prepare|assemble|source-check|fn-poll|fn-legacy-poll|fn-ack` and `fn_frontier` (`selected_exchange.rs:232-652`).
- *`publisher.rs`.* A separate origin-outbox publisher (op 16 via `origin_outbox_prepare`, ordinary submit, op 18 export, NNTP POST) with its own two-attempt POST rule (`publisher.rs:192-425`).
- Twins: `publisher.rs` ↔ `selected_publisher.rs` POST custody (both `durable_json`, `digest`, `read_json`, a `post_action` state machine, the literal `"240 article received OK"` / `"441 posting failed; this article is already stored here"`).
- Wired, from journey or acceptance scripts: `selected-exchange` (row `exchange`, `scripts/pipeline/journey-rows:782-811`), `selected-release-submit|lookup|sign` (`selected-release-acceptance.sh`), `selected-source-sign|publish` (`selected-source-publisher-acceptance.sh`).
- Unwired: `origin-publish` (manual run only, 2026-09-26, per `native/resource-client/README.md:528-533`) and `selected-release-retry`.
- The 10-08 evidence ran `prepare` → `publish` (source sign, op 24 via Host CLI, one NNTP POST) → `receive-transport` (Host `selected-release-fn-legacy-poll`, op 20 recipient submit) → an exact-retry pass → `verify-transport` (signed recipient read), twice green and once planted-red (`docs/evidence/2026-10-08-selected-exchange-local-fn/README.md`, `jobs.tsv`). It is "transport only: no schema-1 fn-e authorship verdict, event17 coverage or fn cursor ACK".

**(7) The refusal decoders and replan.** Exactly these refusal classes trigger a re-plan (details in 1.1 and section 3):
- `replan::stale_root` (`replan.rs:213-217`): the Host outcome's `type=="refused" && reason=="stale-root"`, read from the Host's own decoding of the 255 frame (`:89-105`), or the local consent provider's stale-observation flag (`client_consent::take_stale_observation`). Used by `submit` (`main.rs:1859-1864`), `query_retained` (`main.rs:2179-2184`) and batch reads (`main.rs:2275-2277`). In these paths the **same** intent file is observed and signed again; the attempt directory keeps the superseded files under `replanned/NN` (`replan.rs:223-252`). No new operation is authored.
- The workspace text-append path (`workspace.rs:3608-3650`) additionally accepts `is_final_admission_refusal`: a decoded `type=="refused"` with `phase == hex("admission")`, either an `Outcome` or a `RefusedFrame` whose command is `submit` (`replan.rs:109-117`), **and** `call.bin` exists. It also accepts `is_prepare_stale_target`: the exact prepare detail `invocation preparation: Minidregg.Kernel.DeclaredResourceController.Reject.staleTarget` (`replan.rs:121-126`). Either one must be followed by `append_preimage_moved` proving the client-selected preimage changed (`workspace.rs:3641-3644`). That path then **authors a new proposal** `append-<nonce>` (`workspace.rs:3613-3628`): a different operation under the same request.
- `workspace::propose_request` replans when the error string equals `OBSERVATIONS_MOVED` (`workspace.rs:2929-2934`); nothing is signed in propose.
- Outside `replan.rs`, `chat.rs` loops on the stderr prefix `refused: stale-root` (`chat.rs:685-687`) and re-proposes on the substring `staleTarget` (`chat.rs:1561`).
- *Can a replan submit a different operation under the same consent?* In `submit`/`query`, no: the intent bytes are fixed and each attempt is a fresh observation plus fresh header signature over the same intent. In the append path and chat's staleTarget loop, yes: a new intent with a new nonce is authored after a decoded refusal. Its safety rests on Lean never answering `refused` after committing (Q8.1, Q8.2).
- `prepare_refusal.rs` and `query_refusal.rs` do not decide anything. They retain the exact 255 frame plus four SHA-256 bindings for op 1 and op 5 respectively (`prepare_refusal.rs:27-82`, `query_refusal.rs:13-70`). `capture.rs` is the in-process runner (above).

**(8) story / activity / bend_session / objective_invoke and ops 210-219.**
- *`story.rs`.* Not Objective Bend. It is the PLACE §2.8 story game: transition-table laws (section 3 V1).
- *`activity.rs`.* `mini activity` over ops 210-214 (`activity.rs:1-25`). Byte check against `Host/Main.lean:5965-6002`:
  - op 210 payload = the canonical command bytes from op 7 `author objective-activity` (`activity.rs:133-135`; Lean `activityPlanLoaded … payload`, `:5971-5972`);
  - op 211 payload = `u32 LE len ‖ plan ‖ 64-byte signature` (`activity.rs:92-97`, `:239`; Lean `splitPair`, `:5978`);
  - ops 212/213 payload = the ingress (`activity.rs:254`, `:302`, `:307`; Lean `:5985-5993`, replies `outcomeCodec`, decoded by Rust through op 8 `outcome`);
  - op 214 payload = a JSON request (`activity.rs:99-102`; Lean `parseViewRequest`, `:5996`), reply JSON with `authorityRoot` (`Host/ObjectiveActivityJson.lean:579`, read at `activity.rs:108-111`).
  - The invoke-nonce rule (`opId`, no top-level nonce) is enforced by Lean (`Host/ObjectiveActivityJson.lean:233-250`) and mirrored by Rust (`activity.rs:114-127`).
  - Seats (215-219) are `seat.rs`, not in this shard. They share the dispatcher (`Host/Main.lean:7269-7270`).
- *`bend_session.rs`.* Signs Objective custody headers only after local consent endpoint 227 re-derives the plan (`bend_session.rs:56-57`; `Host/ClientConsentCore.lean:606`). It is reached only by the pre-parse arm `bend-session-sign` (`main.rs:4508-4513`), and nothing calls that arm.
- *`objective_invoke.rs`.* Derives the command on the local Host (`objective-quote`), signs a prepare intent, has endpoint 227 re-derive and compare the whole plan, then assembles and submits (`objective_invoke.rs:15-69`). It is reached by `objective-native-acceptance.py` (journey row `objective`, PASS at `4795b657` per root README).

### 1.1 Family A: refusal retention and the re-plan engine

#### `replan.rs` (561 lines; code 1-303, tests 304-561)

This is the one re-observe-and-re-plan loop for operations that observe and then act (`replan.rs:1-23`).

**Process-global state.** `MAX` (default `DEFAULT_MAX = 5`, `:37`, `:42`), `COUNT` (re-plans since last `take_count`, `:43`, `:60-62`), `CONFIGURED` (`:49`), and the test-only `TEST_LOCK` (`:47-48`). `configure` reads `--replan-max N` (0..=100) or, once per process, the env var `MINI_REPLAN_MAX` (`:65-86`). It is called at the top of every `run` (`main.rs:3166`).

**Classifiers.** All read `HostDecision` values that `main.rs` recorded from the Host's own op-8 decoding of a 255 frame:
- `outcome_is_stale_root` and `is_stale_root` (`:89-105`): `type=="refused" && reason=="stale-root"`, either as `Outcome` or as a decoded `RefusedFrame`. An undecoded frame is not one.
- `is_final_admission_refusal` (`:109-117`): `type=="refused" && phase=="61646d697373696f6e"` (hex of `admission`), only from `Outcome` or a `RefusedFrame` whose `command=="submit"`.
- `is_prepare_stale_target` (`:121-126`): a prepare `RefusedFrame` with `reason=="operation-rejected"`, `phase==hex("prepare")` and the exact detail hex of `invocation preparation: Minidregg.Kernel.DeclaredResourceController.Reject.staleTarget`.
- `stale_root` (`:213-217`), the default race predicate: `is_stale_root(decision) || client_consent::take_stale_observation()`. Both are always read so a stale local flag never outlives the attempt.

**The loop** `replan(what, attempt, race, retire)` (`:133-180`):
1. Clear any previous Host decision and stale flag (`:147-148`), so an earlier command's refusal cannot classify this attempt; the test `earlier_command_refusal_does_not_authorize_this_attempt` is at `:500-507`.
2. Run the attempt. On error, take the decision, ask `race`, re-record the decision for the caller (`:157-161`).
3. If not raced, return the error. If `replans >= max`, return "concurrent source changes exhausted …".
4. Otherwise call `retire(n)`, `pause(n)` (0 ms for the first re-plan, then `100·(n-1) + jitter(0..150)` ms, `:185-194`), count, print a stderr line, loop.
5. `measure` appends `what\treplans\tending\ttotal_ms\tsuperseded_ms` to `$MINI_REPLAN_LOG` if set (`:198-210`); write errors are swallowed (`:205-209`).

**Evidence custody.**
- `retire(dir, n, keep)` moves every entry except `replanned/` and `keep` into `dir/replanned/NN`, refuses an existing slot, and fsyncs both directories (`:223-252`).
- `retire_attempt` refuses to retire a directory holding an accepted outcome (`holds_accepted`, `:256-273`: `outcome.json` or `retry-*.json` with `type=="confirmed"` and confirmation `installed|recoveredAfterUncertainResponse|replayed`; unreadable or invalid JSON is skipped, `:263-264`).
- `retire_next` picks the next free slot (`:290-302`).

**Callers.** `main.rs:1859` (`submit`), `:2179` (`query_retained`), `:2275` (batch reads); `workspace.rs:2929-2934`, `:2950-2955` (propose, race = `OBSERVATIONS_MOVED`), `:3604-3650` (append recovery); also `client_consent.rs:611`, `participant_enrollment.rs:123-125`, `:855`, `:939`, `participant_provisioning.rs:393`, and `shell.rs:2578-2584` (`take_count` per line).

#### `prepare_refusal.rs` (160 lines; code 1-83, tests 84-160)

`retain(destination, request, config, frame)` (`:27-82`) is called "only at the submit path's socket op 1" (`:3-4`; call site `main.rs:1365-1371`, shard A). It refuses unless all of the following hold:
- the frame is a bounded op-255 frame (`:33-35`);
- the destination is `ATTEMPT/plan.bin` (`:39-44`) and config is `ATTEMPT/config.json` (`:45-47`);
- `call.bin` and `plan.bin` are absent (`:48-49`);
- the request equals the retained `signed-observation.bin` (`:50-56`);
- `attempt.json` says `format=minidregg-resource-client-attempt-v1`, `operation=submit`, and the config path (`:57-66`).

It then writes `pre-submit-refusal.frame` (exact frame) and `pre-submit-refusal.json`. The JSON has type `minidregg-pre-submit-refusal-v1` and the SHA-256 of frame, request, Host config and attempt manifest (`:67-80`), and the directory ancestors are synced (`:81`). It interprets nothing; per its doc, "the runtime still rechecks the exact files and asks Lean to decode the retained Outcome" (`:3-4`).

#### `query_refusal.rs` (151 lines; code 1-71, tests 72-151)

`query_refusal.rs` is the op-5 twin of `prepare_refusal.rs` (`:11-70`). Its destination is `view.bin`, and it requires none of `view.bin`, `view.json`, `plan.bin`, `call.bin`, `outcome.bin`, `outcome.json` to exist, even as symlinks (`:32-44`). It requires a non-empty signed observation equal to the request (`:45-51`) and manifest `operation=query` (`:55-60`). It writes `query-refusal.frame` and `query-refusal.json` (type `minidregg-query-refusal-v1`, `operation: 5`). The marker "never authorizes a submit" (`:1-2`). The two files share four helper shapes (bounded-frame check, manifest check, four-digest marker, private writes): a small twin pair that one function with a `stage` parameter would replace.

#### `capture.rs` (125 lines; code 1-105, tests 106-125)

`capture.rs` runs a `mini` command in-process with captured streams.
- `anonymous()` makes an unlinked `tmpfile(3)`, dups its fd and closes the `FILE*` (`:22-35`).
- `streams(body)` flushes stdout, dup2s the two anonymous files onto fds 1 and 2, runs the body, flushes, restores and reads both back (`:60-77`).
- `command(name, flags)` builds `crate::Args`, clears the per-thread decision slots, swaps the exit status, runs `crate::run` under `catch_unwind`, and produces `crate::main_ending(parsed, status)` (`:81-104`).
- The module doc says the swap "is process-wide. Only the single-threaded command-line verbs call this; a server thread never does" (`:14-15`). The only caller is `chat::client` (`chat.rs:659`). `web/resident.rs:57` calls `chat::room_feed`, which does not reach `client` (it uses `signed_read` → `query_retained` directly), so the web server never swaps descriptors through this path.

### 1.2 Family B: chat, story and Hermes (shell verbs)

These three modules have no CLI arm of their own except `story-law` and `hermes-handoff` (the latter is family D). They are parsed and run by `mini shell`: `shell.rs:1132-1135` (`chat::plan`, `story::plan`), `shell.rs:2840-2844` (`chat::run`, `story::run`). `chat::plan` also routes `room ls` and the Hermes verbs (`chat.rs:237-245`). Their client operations run in-process through `chat::client` (`chat.rs:657-668`).

#### `chat.rs` (2,642 lines; code 1-2330, tests 2331-2642)

**Data model.**
- `Line`, one per shell verb (`:160-182`): `Say` (room, to, re, text, via, operation_record, expected_reply, status), `Tail` (room, count, since, follow, json, held, entry, discovery), `Topic`, `Pin`, `Unpin`, `React`, `New{private}`, `Adopt`, `Invite{enc, verbs, i_know}`, `Ls`, `Hermes`, `Join`, `Enter`, `Rooms`, `Name`.
- `Room {name, grant, stream}` is the session's record (`:586-591`), persisted as `HOME/chat/rooms/ROOM.json` with `type: mini-chat-room-v1` (`:609-614`), plus a `founder` field written after `chat new|adopt|join` (`:2056-2058`, `:2110-2113`, `:2318-2322`).
- `Roster {founder, members: Vec<(subject, stream)>}` (`:836-841`) is parsed from a ROOM-SCHEMA v2 resource view (`roster_of`, `:847-866`, delegating the schema check to `room_schema::check_room_view`).
- `Entry {height, author, cell, sequence, topic, to, re, payload: Payload, owner}` (`:877-889`), parsed from a STREAM-TAIL/v2 view (`entries_of`, `:892-928`). `Payload` is `Verified(text) | Absent | Mismatch | Binary`, and only `payloadState=="verified"` with hex that decodes to UTF-8 is text.
- `Kind` (`:939-952`) is the typed payload: `say`, `topic`, `pin`, `unpin`, `react`, `withdraw` (needs `ref`), `request-status` (needs `ref`, status ∈ `REQUEST_STATES` `:956`), `Raw`, `Unavailable`.
- `Feed {feed, founder, topic, pin, reactions}` (`:999-1009`).
- `Held` (`:1206-1214`) is a reader's state between signed reads (keys, workspace record, grant, observe capability, roster, per-stream entries and next sequence, missing streams).

**Wire.**
- *Writes.* Every write is a `minidregg-workspace-proposal-v1` request. The intent is authored by the Host via `workspace propose` and submitted via `workspace submit`. Requests used:
  - append to the speaker's stream: `{"type":"invoke","targets":[{"name":STREAM,"payload":{"type":"append","topic","text","to","ref":{"cell","sequence"}}}]}` (`:1546-1554`);
  - room grant: `action: delegate` with `verbs`, `maxCost "50000"`, `room: true` (`:1978-1979`), then `publish-delegation` (`:1983-1986`);
  - roster rows: `invoke` with `{"type":"scalar","actions":[{"type":"create","key":{"type":"object","field":F},"value":V}]}` (`:2017-2025`);
  - cell birth: `workspace --action create` with `--storage`, `--predicate` (a law JSON written to `HOME/requests/chat-law-NAME.json`), `--in`, `--owner`, `--room-template`, `--fields` (`:1950-1973`);
  - `import` (`:1991-2014`).
- *Reads.* Signed queries `{"subject","nonce","purpose":{"type":"query","kind","target","view", …extra},"grants":[…]}` (`:777-782`) for views `resource` (roster), `tail` (with `start`, `count`), `who`, `since` (with `height`). They go through `crate::query_retained` (`:793`), i.e. challenge (op 4) and query (op 5) on the session socket, each wrapped in `replan`.
- *Merge order.* `(height, author, cell, sequence)` numerically (`merge_order`, `:931-937`), then de-duplicated by `(cell, sequence)` (`:1013`).
- *JSON feed.* `tail --json` emits one header line `mini-chat-room-v1` (room, private, founder, members, topic, pin, entries, selectedEntries, discoveryCursors, unreadable, former) and one object per entry with `private` on each (`json_feed`, `:1811-1824`). The Discord mirror consumes it (comment `:1806-1809`).

**State machines.**
- *`propose_submit_in`* (`:707-758`).
  1. Write the request file. Run `workspace propose` with a fresh proposal id. On `refused: stale-root` retry with a new id, up to `FRESH_CHALLENGES = 10` (`:683`).
  2. Run `workspace submit --intent proposals/ID/intent.json --attempt attempts/ID[-rN]`. On `refused: stale-root` retry the same intent in a new attempt directory, up to 10.
  3. The last JSON document of stdout is the outcome (`:753-757`).
- *`signed_read`* (`:763-825`) has its own 10-try stale-root loop with a fresh nonce per try (`:785-807`). After success it deletes older reads of the same label (`:810-816`).
- *`append_recorded`* (`:1532-1572`).
  1. Refuse a payload over `MAX_PAYLOAD = 4096` (`:133`, `:1538-1540`).
  2. In a private room, clear the plaintext topic (`:1544-1545`) and pass `--private ROOM` so `workspace propose` seals the text (`:719-721`).
  3. Without `--operation-record`: loop `propose_submit_in` while the refusal text contains `staleTarget`, at most 3 re-plans (`:1558-1571`).
  4. With `--operation-record`: `append_operation` (`:1608-1636`). It creates a durable fleet operation record (`crate::fleet::operation_record`), proposes once, submits once into the record's attempt, then recovers exactly (`fleet::recover_operation`). A second run with an existing record only recovers (`:1613-1620`). The record's path is confined to `HOME/requests` or `WORKSPACE/room-operations`, reached by descriptor without following symlinks (`operation_path`, `:1582-1604`).
- *`Held::stream`* (`:1234-1263`) pages a stream in windows of `WINDOW = 256` (`:123`), at most 64 windows per call (`:1240`), and opens sealed entries in place (`open_sealed`, `:1174-1202`, delegating to `roomkey::open_in_room`).
- *`tail --follow`* (`:1866-1922`) polls a signed `since` view every `FOLLOW_INTERVAL_S = 3` s (`:121`), forever, re-reading only the streams the since view names, plus the roster when the room cell moved.
- *`tail --held`* (`read_held`, `:1275-1316`) re-renders the retained `view.bin`s with the local Host's `inspect` (`crate::inspect`, `:1292`), asking nothing of the Host socket.
- *`chat new`* (`:2032-2062`): birth the room (`declared` storage, the author law from `deploy/shell/templates/room/chat/law.author.json` via `include_str!` at `:137`, room template `chat` or `private`, `credit::room_declared_fields()`), birth `ROOM-me` (a `stream` under the same author law, in the room), grant the founder the room (observe, append), import it as `ROOM-room`, write roster founder row, member 1 subject and member 1 stream, save state.
- *`chat adopt`* (`:2080-2117`): the same for an existing room whose reference carries `controlCapability`. Each step is skipped if already done. It refuses if the roster names another founder (`adopt_decision`, `:2121-2126`).
- *`chat invite`* (`:2147-2212`):
  1. Refuse non-founders by a signed roster read (`:2171-2174`).
  2. For a private room, run `room-key --op invite-check` (`:2179-2184`).
  3. Publish the room grant to the invitee (`:2189`).
  4. Reuse the invitee's existing roster stream if any, or birth `ROOM-<last10 of subject>` under the invitee's author law and write roster rows at slot `members.len()+1` (`:2188-2197`).
  5. For a private room, run `room-key --op invite` to release the key (`:2198-2205`).
  6. Save the invitation under `HOME/chat/invites/` (`:2209-2211`) and print `chat join ROOM <invitation JSON>` (`:2135-2141`).
- *`chat join`* (`:2291-2329`) checks that `recipient == me` (local; `:2303-2305`), imports the grant, reads the roster, and imports the member's stream if the roster lists one.
- *`room ls`* (`:2220-2289`) lists the cells written above a height under the room (signed `since` view). With `--import` it writes references `ROOM-cell-ID` for unnamed cells, carrying the private-room sealing hint (`:2246-2257`).

**Who may set the topic and pin, decided here.** `merge` sets `feed.topic` and `feed.pin` only from entries whose author equals the roster's founder field (`:1017-1024`). Renderers mark everyone else's as "(ignored: only X, the founder, …)" (`:1381-1386`). Reactions are open, deduplicated per author and emoji (`:1025-1032`).

**Files and env.**
- `HOME/chat/{rooms/ROOM.json, rooms/ROOM.cache.json, rooms/ROOM.requests.json, current, petnames.json, reads/ROOM/LABEL.NONCE/…, invites/ROOM-SUBJECT.json}`;
- `HOME/requests/*.json` (request files, `say --file`, `--discover`, invitations);
- `HOME/inbox/NAME.json`;
- `WORKSPACE/{proposals,attempts,refs,room-operations}`.
- The only env var is `MINI_KEYCACHE_PASSPHRASE`, reached through `roomkey` for private rooms.

**Parsing bounds.**
- Names 1..40 `[A-Za-z0-9-]` (`ref_name`, `:184-192`); decimals ≤40 digits (`:194-199`); petnames 1..24, not all digits (`:520-529`).
- Topic ≤64 bytes (`:132`, `:254-255`); reaction ≤32 bytes, no whitespace (`:228-233`); `-n` 1..100,000 (`:401-407`).
- Discovery cursors: stdin read capped at 262,145 bytes and refused above 262,144 (`:1084-1089`), ≤1,024 streams and ≤1,024 retained refs (`:1103`).

#### `story.rs` (1,246 lines; code 1-1143, tests 1144-1246)

PLACE §2.8 stories (`:1-51`).
- *The table.* A document `NAME/table` whose non-empty, non-`#` lines are rows (`rows`, `:141-143`): `title`, `scene N TITLE | TEXT`, `start N`, `end N`, `item NAME N`, `exit N WORD M [needs ITEM]`, `act N VERB M [needs ITEM]`.
- *`table_of`* (`:146-259`) parses and validates it, fail-closed. It refuses: unknown scenes; a self-loop; an exit from an end; a need of an unplaced item; two ways per scene pair; a word used twice in a scene; a scene unreachable from the start; and a non-end scene with no way on. It sorts ways by `(from, to)`.
- *`player_fields`* (`:272-274`): `scene`, `turn`, then `carries/ITEM` in name order.
- *`player_clauses`* (`:311-355`) generates the law of one player's cell as JSON predicates over slots `request/verb`, `request/subject`, `resource/field/N/{before,after,delta}`:
  - clause 0 `management`: verb ∈ {1, 2};
  - `mover`: subject == S;
  - `turn`: field-1 delta == 1;
  - `exits`: field-0 delta == 0, or one table edge;
  - one `needs` clause per conditional edge;
  - one `here` and one `once` clause per item;
  - `progress`.
  - Every game clause is `any[…, not(verb == write)]` (`guard`, `:297-300`).
- *Other laws.* `table_open_law` (author only, `:362-364`), `table_sealed_law` (`all[ guard(any[]) , verb ∈ {1,2} ]`, `:369-371`), `staging_law` (`:374-376`), `scenes_law` (GM only for verbs 2 and 7, `:379-381`).
- *Rendering.* `render` (`:412-434`) prints a clause "as `Compiler/RefusalReason.lean` `renderClause` writes it", `explained` (`:438-449`) mirrors the Host's `LawLeaf.explained`, and `clause_named` (`:458-468`) finds which generated clause a `law-denied:` refusal text names.
- *Verbs.* `story new` runs the shell line `room new NAME --template story` in-process (`crate::shell::line`, `:812`), births and fills the table, and links it from `NAME/index` (`:805-854`). `seal` installs `table_sealed_law` (`:856-871`). `invite` births `NAME/p-SUBJECT` with declared fields `0-(n-1)` under `staging_law`, writes start values (create where absent, write with `expected` where present), installs the player's law and grants the room (`:890-948`). `join` (`:950-983`). `look` (`:1055-1072`). `go|take|act` is one scalar write of field 0 or the item field plus turn+1 with `expected` values (`mv`, `:1080-1131`). `narrate` (`:1133-1142`).
- *Player-side check.* Before every move `my_cell` checks the cell's policy predicate equals `player_law(table, me)` with an unconditional local selector (`carries_unconditional_local_law`, `:701-711`), and that an unmoved cell stands at the start (`:987-1006`).
- *`mini story-law`* (`law_command`, `:472-493`) prints the generator's JSON for `scripts/gen-storylaw.py`.
- *Files.* `HOME/story/{NAME.json, current, invites/NAME-SUBJECT.json}`; `HOME/requests/FILE` for `--from @FILE`.

#### `hermes.rs` (1,011 lines; code 1-809, tests 810-1011)

**Verbs.** `summon ROOM as librarian|runner [--budget N] [--every N] [--program @FILE] [--hermes SUBJECT] [--i-know]`, `ask [ROOM] TEXT`, `hermes status [ROOM]`, `hermes cancel N [ROOM]`, `dismiss ROOM` (`:54-59`, parse `:79-169`). The `gm` role is refused by name (`:340-342`).

**Roles** are compiled-in templates (`deploy/shell/templates/hermes/{librarian,runner}/{grants,budget,program.md}` via `include_str!`, `:44-48`), parsed as `mini-hermes-role-grants-v2` (`role`, `:336-367`). For example the librarian holds `observe, append` under the room and `observe, mutate` on `{ROOM}-index` and `{ROOM}-digest`, whose laws are shell law-grammar text (`deploy/shell/templates/hermes/librarian/grants.json`). A runner's inputs and outputs come from two marked lines of its program (`runner_cells`, `:380-397`).

**Registration.** Selection of the resident (`registration`, `:460-467`):
- *Order of sources.* `HOME/hermes/registry.json`, else `/etc/mini/hermes-residents.json`, else (only if no registry) the legacy `HOME/hermes/node.json`.
- *Presence rule.* An existing but broken registry is an error; only absence falls back (`:469-478`).
- *Selection.* `select_registration` (`:480-511`) needs exactly one record for this room cell (and `--hermes` subject if given), with decimal subject/task/roomCell and a 64-hex `encryptionKey`.

**`summon`** (`:568-738`) is resumable from `HOME/hermes/ROOM_CELL.json` (`state_path`, `:446-448`; note the file is keyed by the room *cell*, `:598`):
- Precondition: founder only, by the local room record's `founder` field (`:581-586`). A private room requires `--i-know` (`hosted_private_invite(private, true, i_know)`, `:588`). A dismissed state is archived to `HOME/hermes/history/` (`:600-604`). A different prior assignment refuses (`:605-609`). A random `assignment` nonce is drawn once (`:610`).
- (1) The till, if the room has none: a `declared`/`account` cell under `sources/credit-permit-all.json` (`crate::credit::write_permit`), written into the room's `till` field (`:619-631`).
- (2) Hermes's budget account `h-a{assignment}-hermes`, owned by H and funded `fund` from the founder, law `{"type":"all","predicates":[]}` (`:634-643`).
- (3) `chat::invite` H with the role's room verbs (`:646-652`).
- (4) Per role document: born with its law, or law installed; then delegated to H with `maxCost "50000"` (`:672-689`, `delegate` `:520-537`, `ensure_doc` `:545-553`).
- (5) The program document `{ROOM}-hermes-{role}` born under its law and appended once (`:702-710`).
- (6) Room fields `hermes`, `hermes/account`, `hermes/assignment` set by `credit::set_fields_exact` with operation id `summon-{assignment}` (`:712-718`).
- (7) The manifest `mini-hermes-summon-v1` written to `HOME/outbox/H/room-CELL/assignment-N/summon-ROOM.json` and sealed into `handoff.json` (`:720-730`).

**The rest.**
- *`ask`* is `say --to H` where H is the room cell's `hermes` field from a signed read (`room_hermes`, `:743-748`; `ask`, `:750-761`).
- *`dismiss`* (`:763-808`) revokes the room grant and every role delegation, zeroes the three fields under operation `dismiss-{assignment}`, seals `dismissal.json` and writes `dismiss-ROOM.json`. The budget "comes back as a transfer Hermes's controller signs on its next attach" (`:28-35`).
- *`request_rows`* (`:220-240`) classifies a member's requests to H from the merged feed. Only H's `request-status` entries count, and the first terminal status (completed, refused, cancelled) is final (`terminal`, `:213-215`). `cancellable` = not withdrawn and status `unacknowledged|queued` (`:208-210`).
- *`home_request_status`* (`:292-301`) reports the last classification cached in `HOME/chat/rooms/ROOM.requests.json` (written at `:252-253`), labelled `origin: last-signed-hermes-status-read`.

### 1.3 Family C: private rooms (`private.rs`, `roomkey.rs`)

#### `private.rs` (1,440 lines; code 1-929, tests 930-1440)

**Frames and labels.** `DREGG/PRIVATE-CELL/v2` (envelope), `DREGG/PRIVATE-WRAP/v3` (wrap), `DREGG/SEED-ESCROW/v2`, `DREGG/PRIVATE-KEYCACHE/v2`, plus cSHAKE256 customization labels for commit, schema, X25519 secret, KEK (named for the suite), ML-KEM seed and key id (`:36-47`). Sizes: blocks of 64, blinder 32, nonce 24, tag 16, key 32, plaintext ≤ 1 MiB, envelope header 81 bytes, overhead 133 (`:49-59`). Argon2id: 64 MiB, 3 passes, 1 lane (`:61-64`). Cache file ≤ 4 MiB (`:65`).

**Passphrase custody.** `adopt_keycache_passphrase` moves `MINI_KEYCACHE_PASSPHRASE` out of the environment into a `OnceLock<Zeroizing<Vec<u8>>>` before any thread or child exists (`:81-89`; called first in `main`, `main.rs:4505`). Its doc still says "the shell's own `mini` subprocess, is handed it explicitly (`chat::client`)" (`:79-80`), which is stale since `336b7c0e` removed that subprocess.

**Room keys and rings.**
- `RoomKey {epoch, key: Zeroizing<[u8;32]>}` (`:146-180`).
- `Keyring {rooms: room → epoch → key, forgotten: room → epochs}`. `forget` deletes an epoch and records it so a sync does not unwrap it again (`:186-234`).

**Envelope.**
- `envelope_len(n) = ceil((133+n)/64)·64`, so values 0..59 share the 192-byte class (`:241-253`).
- `commitment = cSHAKE256_COMMIT(room, cell, address, epoch, blinder, value)` (`:277-288`).
- AEAD data is the length-prefixed frame, place, epoch and commit (`:290-301`).
- `seal`/`seal_committed` encrypt `blinder ‖ len ‖ zero-padded value` (`:317-355`).
- `open` decrypts, checks canonical zero padding, and re-derives the commitment (`:357-393`).
- `PrivateEnvelope::from_bytes` requires the frame, a length that is a multiple of 64, and at least 192 bytes, which guarantees the later slices are in range (`:416-429`). Its error text still says `DREGG/PRIVATE-CELL/v1` (`:419`).

**Member keys and the encryption keyring.**
- One 32-byte seed per friend signs (Ed25519) and, through `derive_enc_key`, yields the X25519 secret as `cSHAKE256(ENC_LABEL, seed)` and the ML-KEM-768 seed `cSHAKE256-XOF(KEM_SEED_LABEL, seed)` (`:461-471`).
- `KEY.enc-ring` keeps past encryption secrets across signing-key rotations (`minidregg-encryption-keyring-v2`; v1 refused by name, `:486-562`).
- `KEY.hosted` marks a key that lives on a shared box (`:446-454`).

**Wraps.**
- Bytes: `ephemeral(32) ‖ ML-KEM ciphertext(1088) ‖ nonce(24) ‖ box(48)` = 1,192 bytes, exact length enforced (`:572-594`).
- `seal_to`/`open_from` use `hybrid_kem::encapsulate/decapsulate` and XChaCha20-Poly1305 over the transcript (`:596-626`).
- `wrap_room_key` binds `(room, epoch, member)` (`:628-656`); escrow binds the subject (`:659-669`).
- Known-answer tests against independent Python implementations: `:1188-1237`.

**Key cache.** `save_cache`/`load_cache` (`:688-777`): `frame ‖ salt ‖ nonce ‖ AEAD(Argon2id(passphrase, salt), json{rooms, forgotten})`, written 0600 via temp + rename (`fsio::replace_private`).

**View hooks.**
- `legacy_content` (`:788-820`) admits only structural actions and strikes that retain the exact old ciphertext. Fresh private text is refused.
- `is_private_kind`/`opened_text` (`:825-840`).
- `open_view`/`annotate`/`private_note` (`:846-928`) annotate every private atom in a signed view with `{epoch, commit, text|hex}`, the sealed marker, or `{refused, label}`.

#### `roomkey.rs` (3,863 lines; code 1-2874, tests 2875-3863)

The module doc (`:1-111`) is the protocol specification.

**Data structures**, each with exact byte layouts:
- `EpochCertificate` (192 bytes: room, keys, epoch, parent identity, key commitment, signer, signer epoch, signer public key, Ed25519 signature; `:181-239`).
- `WrapAttestation`, `EpochHead {epoch, identity}` (`:241-251`).
- `FounderTransition` (248 bytes signed by the old **and** new key, at atom id `(2^31+1+i)<<96`; `:520-605`), `FounderChain {keys, after}` (`:639-699`).
- `ReleaseStatement` (232 bytes, founder-signed commitment to the exact wrap bytes, at atom id `((2^30+1+e)<<96)|g<<64|m`; `:710-800`).
- `EncRecord` (1,333 bytes: key epoch, X25519 + ML-KEM key, room, keys cell, custody byte, member signing key, signature; v1/v2 refused by name; `:894-1044`).
- `WrapAtom` (1,232 or 1,532 bytes at atom id `(e+1)<<96 | g<<64 | m`, `MAX_EPOCH = 2^30 − 1`; `:907-1178`).
- `Lineage {wraps, releases, certificates, head, chain}` (`:833-852`).
- `Synced` (`:1520-1534`).
- `ReleaseSpec`/`ReleaseState {Drafted, Applied, Disclosed, Dead}`/`RetainedReleaseDraft` (`:1743-1991`).
- The `ReleaseHost` trait, which tests fake (`:1763-1786`).

**Authority model: out-of-band pins.**
- `pin_founder` writes `ROOT/private/room-founder-ROOM.json` (TOFU; a different key refuses without `--replace true`, `:403-423`).
- `pin_member` writes `room-members-ROOM.json` from a member's signed v3 declaration (`:457-487`).
- `authenticate_recipient` accepts a record only under the founder's pin for that member (`:491-497`).
- Served certificates and wraps verify under the pinned founder key or a later key on the founder chain (`verify_lineage`, `:856-884`).
- A retained head may not go backwards or equivocate (`advance_head` `:253-261`, `check_epoch_chain` `:271-310`, `read/retain_epoch_head` `:312-366`).
- A served founder chain shorter than one already authenticated is refused as rollback (`:341-350`).

**Operations**, dispatched from `workspace --action room-key --op …` (`workspace.rs:6386-6545`, shard A); every write goes through `turn` (`:1653-1692`):
- `turn` proposes once under a fixed proposal id with a per-id lock, never re-authors an incomplete custody, recovers an existing attempt by exact lookup (`super::recover`), and requires a confirmed outcome before continuing.
- `found` (`:2198-2256`): birth the keys cell under `keys_law(founder)` (`deploy/shell/templates/room/private/law.keys.json`), mark the room reference private, pin own key, release genesis to self.
- `sync` (`:1550-1612`): signed read of the keys cell, verify, retain head, unwrap every wrap for me not held or forgotten, save cache.
- `current_key` (`:1616-1637`): the sealing key is the authenticated head epoch's key; nothing older is used.
- `invite_preflight` (`:2450-2470`) and `invite` (`:2476-2557`): authenticate the invitee's signed declaration, enforce the hosted rule (`check_invitee` from `/etc/mini/hosted-subjects` or `MINI_HOSTED_SUBJECTS`, `:1414-1432`, `:2344-2349`; plus the record's own custody byte, `:2373-2376`), pin the member, delegate the keys grant if founder (`keys_grant`, `:2143-2153`), and release the current or past epochs.
- `rotate` (`:2582-2629`): fresh key at `next_epoch` (above head and every burned release epoch, `:845-851`), wrapped to kept recipients.
- `kick` (`:2756-2768`): preflight kept recipients, `room_kick` revokes, then `rotate` with dropped.
- `register` (`:2634-2668`): publish or edit one's own record. `publish_rotation` (`:2674-2699`): after `rotate-key`.
- `rewrap` (`:2706-2753`), `transition` (`:2265-2296`), `founder_rotation_gate` (`:2303-2323`), `list`/`forget`/`open_local` (`:2771-2816`), `tail --private` (`:2843-2868`).

**The release state machine** (`:1712-2110`).
1. DRAFTED: the exact signed deliveries, plus a new epoch's key encrypted in a separate `draft-key.cache`, are retained under `ROOT/private/room-releases/<op>/` (`stage`, `:1878-1927`).
2. Turn 1 (`PROPOSAL-bind`) creates only the release records (commitments, no ciphertext) (`:2090-2091`).
3. A fresh signed view is read back. Head unchanged, exact records present, no wrap yet at the address, every recipient record unchanged, every recipient still in `who` (`check_readback`, `:2022-2050`). Otherwise the release is DEAD forever (`:2094-2097`).
4. APPLIED is marked; turn 2 (`PROPOSAL-wraps`) writes the wraps; DISCLOSED is marked.
5. Starting a release kills every other undisclosed release of the room (`:2071-2075`). A dead release's epoch is burned (`next_epoch`).

**Stream sealing.** `seal_for_room` binds (room, stream cell, sequence) and limits the plaintext to `max_value_within(4096)` = 3,963 bytes (`:1332-1345`). `open_in_room` returns `{epoch, commit, blinder, text|hex}`, the sealed marker, `{unsealed: …}` for plaintext posted into a private room, or `{refused, epoch}` (`:1351-1385`).

**Files.** `ROOT/private/{keys.cache, epoch-head-ROOM.json, room-founder-ROOM.json, room-members-ROOM.json, room-releases/OP/{draft.json,draft-key.cache,applied.json,disclosed.json,dead.json}, roomkey-turns/ID.lock}`, `ROOT/sources/roomkey-*.json`, `ROOT/refs/ROOM-keys.json`, and the operator file `/etc/mini/hosted-subjects`.

### 1.4 Family D: Hermes resident handoff and provider continuity

#### `hermes_handoff.rs` (1,359 lines; code 1-1032, tests 1033-1359)

**Bundle format.**
- Outer: `{"type":"mini-hermes-handoff-v1","payloadHex","publicKey","signature"}`, signed by Ed25519 over `b"mini-hermes-handoff-v1\0" ‖ payload` (`DOMAIN`, `:11`; `message`, `:68-70`) and checked with `verify_strict` (`decode`, `:71-124`).
- Payload: exactly `{type, world, recipient, task, founder, room, roomCell, assignment, origin, files}`. `type` is `mini-hermes-summon-bundle-v1` or `mini-hermes-dismiss-bundle-v1`. `files` holds 3..128 named hex blobs, each ≤ 4 MiB (`LIMIT`, `:12`).
- `validate_files` (`:136-188`) cross-checks the manifest, the invitation (a delegated reference with `room:true`), the account handoff and every document grant against the payload identity, and refuses unrelated files.

**`seal`** (`:190-232`), the producer. It is called by `hermes::summon` after the room-field write is accepted. It reads the files from the outbox. Its `origin` is the accepted attempt's `call.bin`, `plan.bin`, `transaction-signatures.bin`, the intent's draft command and the receipt (`workspace::accepted_outcome`). It signs with the founder workspace key and refuses to overwrite a retained payload that differs (`:223-228`). `seal_dismiss` (`:570-590`) does the same for the dismissal bundle.

**`verify`** (`:305-493`), the consumer check, in order:
1. Recipient, task, room and world (domain + expected seed from the config, `world`, `:48-60`) match the resident workspace.
2. **Op 144** key status of the founder's bundle key: `isCurrent && !currentRevoked` on first delivery (`:326-343`).
3. The origin call is looked up historically (`historical_call_receipt::lookup_verified`, `:349-361`).
4. The plan + signatures re-assemble to the exact call (`host_files assemble`, `:367-374`).
5. The plan's `finalizedDraft.command` equals the re-authored command (`author resource`, `:399-411`), and the command is exactly the founder's three-field scalar write on the room cell (`validate_origin_command`, `:495-542`; dismissal requires `write` to `"0"` with the old value as `expected`).
6. Signed reads: the room roster (founder and H's stream, `:420-430`); room fields `1008`/`1009`/`1012` equal the assignment (`:431-444`); every delegated reference via `capability` view, whose account evidence must name H as holder with `observe` (`account_evidence`, `:256-304`, computing `operationVerified` and `transferGranted`); the program document.
7. A final re-read that the three fields have not changed (`:473-488`). Every signed read's challenge must be in the same domain (`consistent`, `:238-253`).

**Dispatcher side.**
- `registration_file` requires an operator-owned (uid 0 or euid), not group/world-writable file (`:825-853`).
- `registered` binds a bundle to a registration and computes the inbox path `INBOX/room-CELL/assignment-N`; "no bundle path can choose where a resident receives its files" (`:854-878`).
- `publish` stages into `.staging-ID` and renames atomically (`:885-930`).
- `point_current` writes `room-CELL/current.json` under a service lock and keeps the pointer with the larger `acceptedCount` (length then lexical compare, `:691-744`).
- `activation`, `check_delivery`, `check_dismissal` and `publish_dismissal` re-verify before every resident action (`:543-631`, `:745-785`).
- `registry` (`:786-824`) emits `mini-hermes-registry-v1` from a directory of registrations (≤4,096 files), checking each registration's custody with op 144 (`check_registration_custody`, `:632-666`).

**CLI** `mini hermes-handoff --action registration|activation|registry|dispatch|verify|check-dismissal|check-delivery` (`:931-1031`; arm `main.rs:3263`).

#### `provider_continuity.rs` (1,272 lines; code 1-844, tests 845-1272)

**Wire.** Op 17 payloads (`request_payload`, `:131-156`; `resolution_payload`, `:157-173`):
- legacy: `pair(call, outcome)`;
- v2: `"DREGG/PROVIDER-CONTINUITY/v2\0" ‖ pair(pair(call,outcome), pair(fenceCall,fenceOutcome)|empty)`;
- v3: `"DREGG/PROVIDER-CONTINUITY/v3\0" ‖ pair(v2body, pair(count, root))`;
- `pair` = u32 LE length of the first part, then both (`:120-129`).
- These agree with `Host/Main.lean:5552-5566`: v2 and v3 prefixes, `splitPair`, bounded prior point ≤1,024 bytes, decimal count and root.

**`strict_descriptor`** (`:12-54`) parses JSON with serde, then scans the bytes to refuse duplicate object keys, including escaped aliases.

**Guard path.** `guard` (`:383-432`) runs only when `mini submit --provider-continuity DESCRIPTOR` is used (`main.rs:4313-4326`, `submit_with_continuity` `:1869-1886`, called from `submit_once` at `main.rs:1953-1970`):
1. Retain the descriptor. Build the v2 payload from the retained, SHA-256-checked reserve and fence call/outcome files (`retained_input`, `:76-100`; `proof`, `:184-199`).
2. Send op 17 and require a reply of type 17 whose JSON binds the provider resource id, the reserve receipt as `anchor`, the exact fence as `allowedFence`, and the original plan's `worldRoot` (`verify_prefix`/`verify_reply`, `:201-226`).
3. Run the local Host `pin-plan-height ORIGINAL PLAN` (`:415-427`). Re-inspect, and require that only each slot's `validUntil` (tightened to `min(deadline, height)`) and its canonical header changed (`verify_pinned`, `:227-266`).
4. On any error, `retain_rejection` writes `provider-continuity-rejection.json` with `heldAllowanceReleased:false` and the SHA-256 of intent, config, manifest, descriptor and original plan and presentation (`:297-356`). The caller returns before signing (`main.rs:1959-1966`).

**Resolution path.** `resolve_attempt` (`:607-843`), `mini provider-continuity --guarded-attempt` (`main.rs:3461-3475`), is read-only and has no key parameter:
1. Copy and hash every input (`copy_resolution_input`, `:503-516`). Refuse a different Host, config or socket (`:641-650`).
2. Exact lookup first. A confirmed outcome ends with `decision: already-confirmed` (`:653-672`).
3. Otherwise require the retained outcome to be exactly `{"type":"contention"}` (`require_contention`, `:496-502`).
4. Re-inspect the original and pinned plans and `verify_pinned`. Re-author the grain settlement command and match it to the plan (`:741-758`). Re-assemble the call (`:759-774`). Re-verify the original op-17 reply (`:775-783`). Re-send op 17 v3 with the original checked point and require `priorChecked` to equal it (`:784-830`).
5. Read the Host `profile` (`:826-828`) and compute `expiration` (`:436-477`). This requires `providerContinuityAdmission == "exact-height-v1"`, `genesis + oldCount == pinned.height`, `newCount > oldCount`, and every slot's `validUntil < genesis + newCount`.
6. Write `resolution.json` with `decision: retire-expired-contention` (`:832-842`).

### 1.5 Family E: Objective Bend activity, invocation and session signing

#### `activity.rs` (323 lines, no tests)

`mini activity --action submit|quote|resubmit|lookup|view --workspace DIR …` (`:4-22`, `run` `:275-323`; arm `main.rs:3222`).
- `ws` loads `workspace.json` (≤64 KiB) and pins the Host SHA if present (`:39-59`).
- `invoke` sends one op over the workspace socket through `session_invoke`, so ops 7/8 go to the local codec child (`main.rs:603-605`). It maps a reply byte equal to the op to the body; 255 **or** 254 to `refused: opN: <last 600 bytes, lossy, whitespace-collapsed>`; anything else to "invalid frame" (`:61-74`).
- `command_for` (`:114-127`): an `invoke` turn must carry `opId` (its nonce); every other turn gets `fsio::random_nonce()` per call.
- `quote_front_end` (`:175-209`): plan the turn with the quote's start budget, doubling replay and core bytes up to the ceiling while the plan's `verdict` text contains `frontEndExhausted` or `postageFrontEnd`. Then write `envelope.{replayBytes,coreBytes} = frontEnd` and `postage = loads × postage*Bytes`. Each probe plan is retained in `out/front-end-plan-N`.
- `submit` (`:226-269`): read the current `authorityRoot` from op 214, author with op 7 `objective-activity`, plan with op 210, inspect with op 8 `objective-activity-plan`, sign `header.canonical` with the workspace key, assemble with op 211, retain `ingress.bin` **before** submit, submit with op 212, inspect the outcome with op 8.
- Output adds `transaction`, `report`, `verdict` and `frontEnd` from the plan, and optionally `declared`, `planned` and `plans`.

#### `bend_session.rs` (75 lines, no tests)

`mini bend-session-sign native|return --host --config --intent --role --plan --key --dir` (`main.rs:4508-4513`).
1. Refuse an existing directory. Check the key file is private (`mini_sdk::private::check_file`, `:40`).
2. Retain the intent and plan, then ask local consent endpoint 227 (`client_consent::objective_headers`, `:56-57`) for headers derived from the independent intent and the selected key and role. Bound the count: 1..32, exactly 1 for `return` (`:58-60`).
3. Re-check that the retained files did not change (`:61-63`), sign, and encode signatures (native) or write one detached signature (return).

#### `objective_invoke.rs` (69 lines, no tests)

`mini objective-invoke --host --config --request --intent-nonce --key --dir [--prepare-only]` (`main.rs:4375-4389`).
1. Local Host `author objective-request`, then `objective-quote REQUEST NONCE` (`:31-34`), producing `{intent, command}` in hex.
2. Sign and observe the prepare intent (`authorize_observation`, `:44-45`); `prepare` (`:47`).
3. Endpoint 227 re-derives the command from the same request and compares the whole plan (`:49-55`).
4. Encode signatures, assemble, `sync_retained_call`, `submit`, inspect, `confirmed_outcome` (`:56-68`).
5. A lost reply is recovered by `mini retry --mode lookup` on the retained call (doc `:10-12`).

### 1.6 Family F: fn consumer custody (`fn_namespace.rs`, `fn_frontier.rs`)

Both modules are "operator custody" clients over an owner-private operator socket. They share one machine; the files are near-duplicates (section 5).

**Plan.**
- `fn_namespace::plan` (`fn_namespace.rs:127-176`) sends op 42 with an **empty** payload. Lean refuses a non-empty one (`Host/Main.lean:7509-7510`).
- `fn_frontier::plan` (`fn_frontier.rs:211-310`) has the local Host CLI build the 64-request (`fn-frontier-request KIND TX OUT`, `:240-245`), sends op 64, inspects the plan as `fn-consumer-frontier-plan-v2`, and has the Host CLI export `cursor.fncu` (≤346 bytes), `report.fn-e` (≤3,150,546) and `source.eml` (≤1,500,000) (`:270-293`).
- Both write `plan-attempt.json` before the call, then retain `plan.frame`, `plan.bin`, `plan.json` and a `pin.json` holding the SHA-256 of Host image, config, plan and artifacts.

**Register / advance.** `register` (`fn_namespace.rs:352-518`), `advance` (`fn_frontier.rs:480-622`):
1. Take the directory lock. Re-check the pin (`retained`, `pin_still`).
2. Re-inspect the plan with the pinned Host and require equality (`verify_inspection`).
3. Load a private approval and require it to match the plan SHA, the identity, the signer public key and every listed inspection field (21 fields for the namespace, `fn_namespace.rs:191-217`; 28 plus 5 optional for the frontier, `fn_frontier.rs:337-381`). Require `signingAlgorithm == "1"`.
4. Sign `signingHeaderHex` once (persisted as `signature.bin`, re-checked on reentry).
5. Op 43/65 with `pair(plan, 64-byte signature)` (u32 LE; `fn_namespace.rs:231-240`, `fn_frontier.rs:394-403`), under an `assembly-attempt.json` marker.
6. Write a durable `submit-attempt.json` marker, then exactly one op 40 / 60|62.
7. Any reentry after the marker does only op 41 / 61|63 lookups (up to 16 numbered). An absent lookup returns "exact lookup absent; no automatic resubmit".
8. A transport error writes `submit-transport-uncertain.json`.

**Op routing.** `fn_frontier` selects ops by the plan's `kind` (`selected` → 60/61, `empty` → 62/63; `fn_frontier.rs:59-65`).

**Plan size.** `MAX_PLAN = 12,102,760` (`fn_frontier.rs:11`) equals `bounds::FRAME_BYTES_MAX` (`bounds.rs:7`).

### 1.7 Family G: selected-source publication and exchange

#### `selected_release.rs` (411 lines; code 1-284, tests 285-411)

- *`submit`* (`:210-243`): retain `config.json`, `ingress.bin` (≤ frame bound) and `attempt.json` (`format: minidregg-selected-release-attempt-v1`, host + SHA, config + SHA, socket, ingress SHA), then `invoke(20)`.
- *`invoke`* (`:158-208`):
  1. Write a numbered `request-NNNN.json` marker before the call.
  2. `transport::invoke_pinned` (v2 envelope with Host SHA).
  3. Retain the reply frame. 255 is "Host refused selected release; exact refusal retained".
  4. Retain `request-NNNN.bin` and inspect it with the pinned Host. Accept `confirmed` (or `absent` for lookup).
- *`lookup`* is `invoke(21)` (`:245-252`).
- *`recover`* (`:257-271`) is lookup, then, iff the freshly decoded lookup says `absent`, `invoke(20)` with the **same** ingress.
- *`retry_submit`* (`:273-283`) requires the latest retained marker to be op 21 with matching ingress and socket, and a **re-decoded** `absent` (`latest_lookup_absent_with`, `:81-144`).

#### `selected_publisher.rs` (635 lines; code 1-494, tests 495-635)

- *`sign_source`* (`:11-77`): refuses a socket (direct source Host only); Host CLI `selected-release-source-plan PACKET CAP SPEC HEADER ROOT`; sign the returned header; `selected-release-source-assemble SPEC HEADER SIG INGRESS`; write `pin.json`.
- *`publish`* (`:388-493`):
  1. Pin Host, config, ingress, article, post config, fn port and certificate SHA.
  2. Host CLI `selected-release-source-check INGRESS ARTICLE` (`:436-444`).
  3. `source_receipt` (`:168-268`): a `source-submit-attempt.json` marker, then Host CLI `selected-source-publication-submit` (op 24's stdio route); on re-entry only numbered `selected-source-publication-lookup` (op 25).
  4. `verify_source_lookup` (`:270-326`): one more exact lookup whose receipt must equal the submitted one.
  5. One NNTP POST (`worker::post_exact_carrier`) after a `fn-post-attempt.json` marker. A present attempt without an accepted result is `Hold` forever (`post_action`, `:357-375`).
  6. The accepted status lines are matched literally (`accepted_post`, `:328-348`).

#### `selected_exchange.rs` (978 lines; code 1-847, tests 848-978)

`mini selected-exchange --phase P --contract C --state-dir S [--approval A]` (`run`, `:775-846`; arm `main.rs:3280-3290`). The contract is `minidregg-selected-exchange-v1` with profile `public-peerable-v2`. `pin` hashes the contract, the **running `mini` executable**, and 13 named input files (`:88-124`).

| Phase | What it does |
|---|---|
| `prepare` (`:232-378`) | signed source query (Host CLI `query`); exact atom present once, untombstoned; `selected-release-prepare`; re-query for an unchanged view; `selected_release_sign`; `selected-release-assemble`; `selected_publisher::sign_source`; `selected-release-source-check` |
| `publish` (`:380-398`) | `selected_publisher::publish` |
| `receive` (`:400-456`) | Host CLI `selected-release-fn-poll`, then `selected_release::submit` or `recover` |
| `receive-transport` (`:498-592`) | Host CLI `selected-release-fn-legacy-poll`; check the stored article ends with the authored one; `retrieval.json`; recipient submit or recover |
| `cover-plan` (`:594-612`) / `cover-advance` (`:614-623`) | `fn_frontier::plan` / `fn_frontier::advance` |
| `ack` (`:625-652`) | Host CLI `selected-release-fn-ack` |
| `verify` / `verify-transport` (`:654-745`) | a signed recipient read must contain one untombstoned `inlineObject` atom of schema `"11"` whose id is the receipt's `transactionId` and whose payload is the packet |
| `status` (`:747-773`) | local evidence report |

#### `publisher.rs` (552 lines; code 1-426, tests 427-552)

`mini origin-publish --host --config --socket --key --carrier --state-dir --post-config` (`main.rs:3440-3459`).
1. Pin a JSON of every input (`:45-80`).
2. Retain the carrier (≤1,516,384 bytes, `:298`).
3. `prepare` runs `origin_outbox_prepare` (op 16 via `main.rs`) and requires `proposed-fresh` (`:82-96`).
4. `accepted_outbox` (`:98-147`): `submit` the Lean-authored intent (result ignored, `:107`), then scan retained outcomes and retries for a confirmed transaction. Otherwise `retry lookup`, and on a decoded `absent` one same-call `retry submit` (`:130-145`).
5. `export` sends op 18 over **unpinned** `transport::invoke` and requires `fn-a-origin-outbox-export-v1`, `status: accepted` and the exact carrier (`:149-190`).
6. POST at most twice: a second attempt only after a recorded `transport-uncertain` (`post_action`, `:208-282`).

#### `native/resource-client/selected-release-drop-reply.rs` (95 lines)

A standalone `fn main` fault fixture, not a crate module and not built by cargo. `selected-release-acceptance.sh:381` compiles it with `rustc --edition=2021 -D warnings` into the evidence directory. It accepts one connection on a proxy socket, requires a v2 envelope whose op is 20 (`:63-74`), forwards it upstream, retains the request and the complete reply 0600 (`:31-41`, `:75-84`), and closes without replying (`:85-87`). Frame bound 12,200,000 (`:11`).

### 1.8 Processes, sockets, files and environment touched by the shard

| Kind | What | Where |
|---|---|---|
| Unix socket (member session) | Host session socket from `workspace.json` or `--socket` | `activity.rs:39-74`, chat/story/hermes via `query_retained`/workspace |
| Unix socket (operator) | owner-private operator socket, `check_private_socket` | `fn_namespace.rs:132`, `fn_frontier.rs:226`, `hermes_handoff.rs:323-325` (`SOCKET`) |
| Child process | the pinned Host image (`Command::new(host) CONFIG …`) for inspect, author, assemble, lookup, profile, pin-plan-height and the selected-* / fn-frontier-* CLI routes | `fn_namespace.rs:34-46`, `fn_frontier.rs:27-47`, `:194-207`, `provider_continuity.rs:415-427`, `:760-767`, `selected_exchange.rs:74-86`, `selected_publisher.rs:38-65`, `:114-130` |
| Child process | local consent codec (ops 7-11), endpoints 224/226/227 | `main.rs:603-605`, `bend_session.rs:56`, `objective_invoke.rs:51` |
| Network | NNTP STARTTLS POST to the operator's localhost fn (in `worker.rs`, other shard) | `publisher.rs:391`, `selected_publisher.rs:472` |
| `/etc` files | `/etc/mini/hermes-residents.json`, `/etc/mini/hosted-subjects` | `hermes.rs:463`, `roomkey.rs:139` |
| Env vars | `MINI_KEYCACHE_PASSPHRASE`, `MINI_HOSTED_SUBJECTS`, `MINI_REPLAN_MAX`, `MINI_REPLAN_LOG` | `private.rs:73`, `roomkey.rs:140`, `replan.rs:73`, `:199` |
| Member home | `HOME/{chat,story,hermes,outbox,requests,inbox}/…` | chat, story, hermes as above |
| Workspace | `ROOT/{private,proposals,attempts,sources,refs,room-operations}/…` | roomkey, chat |
| Key-adjacent files | `KEY.enc-ring`, `KEY.hosted` | `private.rs:446-454`, `:489-493` |
| Operator state dirs | fn and selected attempt and state directories (0700) | families F and G |

### 1.9 Record formats this shard defines

The shard defines about 80 distinct JSON `type` strings (grep for `"(mini|minidregg|fn)-…-vN"` across the shard's files). None has a Lean declaration; they are client custody records. This is format sprawl the synthesis should count. Main writers:

| Family | `type` strings (first site) |
|---|---|
| Refusal and attempt | `minidregg-pre-submit-refusal-v1` (`prepare_refusal.rs:68`), `minidregg-query-refusal-v1` (`query_refusal.rs:61`), `minidregg-resource-client-attempt-v1` (read at `prepare_refusal.rs:61`, `query_refusal.rs:55`, `provider_continuity.rs:329`) |
| Chat | `mini-chat-room-v1` (`chat.rs:612`, also the `tail --json` header `:1813`), `mini-room-ls-v1` (`:2263`), `mini-resident-discovery-v1` (`:1100`); requests use `minidregg-workspace-proposal-v1` (`:1553`) |
| Story | `mini-story-v1` (`story.rs:839`), `mini-story-invitation-v1` (`:896`), `mini-story-law-v1` (`:480`) |
| Hermes (shell) | `mini-hermes-summon-state-v1` (`hermes.rs:599`), `mini-hermes-summon-v1` (`:722`), `mini-hermes-dismiss-v1` (`:796`), `mini-hermes-request-status-v1` (`:252`), `mini-hermes-registry-v1` (`:485`), `mini-hermes-role-grants-v2` (`:347`) |
| Hermes handoff | `mini-hermes-handoff-v1` (`hermes_handoff.rs:73`), `mini-hermes-summon-bundle-v1` and `mini-hermes-dismiss-bundle-v1` (`:102-103`), `mini-hermes-handoff-verified-v1` (`:491`), `mini-hermes-dismiss-verified-v1` (`:414`), `mini-hermes-account-custody-v1` (`:295`), `mini-hermes-handoff-delivered-v1` (`:545`), `mini-hermes-handoff-ready-v1` (`:567`), `mini-hermes-dismiss-ready-v1` (`:607`), `mini-hermes-dismiss-dispatch-v1` (`:630`), `mini-hermes-dispatch-registration-v1` (`:676`), `mini-hermes-assignment-pointer-v1` (`:707`), `mini-hermes-assignment-activation-v1` (`:782`), `mini-hermes-dispatch-v1` (`:898`) |
| Provider continuity | `mini-provider-continuity-v1` (descriptor, `provider_continuity.rs:363`), `minidregg-provider-continuity-rejection-v1` (`:336`), `mini-provider-continuity-resolution-v1` (`:661`); the Host's reply type `minidregg-provider-continuity-v1` (test `:855`) |
| Private rooms | `minidregg-encryption-keyring-v2` (`private.rs:486`; v1 refused `:487`), `minidregg-authenticated-room-head-v1` (`roomkey.rs:321`), `minidregg-room-founder-pin-v1` and `minidregg-room-member-pins-v1` (`:379-380`), `minidregg-retained-room-release-v2` (`:1837`), `minidregg-applied-room-release-v1` (`:2098`), `minidregg-disclosed-room-release-v1` (`:2108`), `minidregg-dead-room-release-v1` (`:1952`), `minidregg-signed-room-recipient-v3` (`:2392`; v2 refused `:3597`), `minidregg-private-room-v1` (`:2249`), `minidregg-room-founder-transition-v1` (`:2274`), `minidregg-room-rotation-v1` (`:2625`), `minidregg-room-rewrap-v1` (`:2749`), `minidregg-room-keys-v1` (`:2775`), `minidregg-room-forget-v1` (`:2797`), `minidregg-room-open-v1` (`:2812`), `minidregg-participant-reference-v1` (`:2177`) |
| fn custody | `minidregg-fn-namespace-custody-v1`/`-approval-v1` (`fn_namespace.rs:9-10`), `minidregg-fn-frontier-custody-v1`/`-approval-v1` (`fn_frontier.rs:9-10`); Host plan types `fn-consumer-namespace-plan-v1` (`fn_namespace.rs:93`), `fn-consumer-frontier-plan-v2` (`fn_frontier.rs:106`) |
| Origin publisher | `minidregg-fn-origin-publisher-pin-v1` (`publisher.rs:57`), `fn-exact-post-attempt-v1` (`:388`), `fn-exact-post-result-v1` (`:232`), `fn-exact-post-accepted-v1` (`:324`); Host types `fn-a-origin-outbox-session-v1` (`:88`), `fn-a-origin-outbox-export-v1` (`:163`) |
| Selected publication | `minidregg-selected-source-sign-v1` (`selected_publisher.rs:70`), `minidregg-selected-source-submit-attempt-v1` (`:176`), `minidregg-selected-source-lookup-v1` (`:227`), `minidregg-selected-source-proof-lookup-v1` (`:285`), `minidregg-selected-fn-post-attempt-v1` (`:378`), `minidregg-selected-fn-post-v1` (`:329`), `minidregg-selected-publisher-pin-v1` (`:408`), `minidregg-selected-release-attempt-v1` (`selected_release.rs:13`), `minidregg-selected-exchange-v1` (`selected_exchange.rs:8`), `minidregg-selected-exchange-prepared-v1` (`:211`), `minidregg-selected-exchange-transport-v1` (`:488`), `minidregg-selected-exchange-verified-v1` (`:740`), `minidregg-selected-exchange-status-v1` (`:760`) |

---

## 2. What it assumes of its surroundings

### 2.1 Host protocol operations, with the Lean cross-check

Registry rows are from `protocol/host-operations.json` (dumped to scratch `ops.txt`). "Agree" means the Rust encoding and the Lean decoding match on bytes, fields, reply code and error marker, as far as the cited Lean arm shows.

| Op | Registry symbol / routes / receiver | Rust site in this shard | Lean arm | Verdict |
|---|---|---|---|---|
| 1, 2, 3, 4, 5, 9, 10, 11 | prepare, submit, lookup, challenge, query, signatures, observe-assemble, call-assemble | indirect via `main.rs` (`query_retained`, `submit`, workspace), called by chat/story/hermes/roomkey | `dispatchSession`/`fnDispatch` (shard A verified the framing) | not re-verified here; shard A says agree. `prepare_refusal`/`query_refusal` retain op 1 / op 5 255-frames (`main.rs:1365-1371`) |
| 7 AUTHOR, 8 INSPECT | public,operator / `dispatchSession` | `activity.rs:83-90` (`with_kind`: u16 LE kind length ‖ kind ‖ body, `:76-81`); many `crate::inspect`/`crate::author` calls | always served by the local codec child, not the socket (`main.rs:603-605`) | agree (u16 LE kind, `Host/Main.lean:1862-1869` per shard A) |
| 16 FN_ORIGIN_OUTBOX | public,operator / `fnDispatch` | `publisher.rs:85` → `main.rs` `origin_outbox_prepare` | `Host/Main.lean:6710-6717` | not re-verified (the call site is in `main.rs`) |
| 17 PROVIDER_CONTINUITY | public,operator / `fnDispatch` | `provider_continuity.rs:404`, `:818`; `main.rs:3113-3114` (legacy pair) | `Host/Main.lean:6718-6724`; payload parse `:5552-5566` | agree: legacy, v2 and v3 framings match; reply byte 17 + JSON; 255 on refusal |
| 18 FN_ORIGIN_OUTBOX_EXPORT | public,operator / `fnDispatch` | `publisher.rs:154` (unpinned `transport::invoke`; payload = transaction id ASCII) | `Host/Main.lean:6725-6729`, `runFnOriginOutboxExportSession` `:5489-5503` (≤80 decimal ASCII; refusal is code 18 with `status: refused`) | agree. Rust treats any non-`accepted` status as "identity differs" (`publisher.rs:163-168`), which loses Lean's `reason` |
| 20 SELECTED_RELEASE_SUBMIT, 21 _LOOKUP | public,operator / `dispatchSession` | `selected_release.rs:169-175` (payload = ingress; v2 pinned envelope) | `Host/Main.lean:2078-2083` (`selectedReleaseSubmitSession` `:1274-1280`, which calls `FnSelectiveReleaseReceiver.receiveLoaded … payload`) | agree: reply 20/21 + `outcomeCodec`, decoded by op 8 `outcome` |
| 24, 25 SELECTED_SOURCE_PUBLISH_SUBMIT/_LOOKUP | **no routes** ("Host stdio only, socket route not present") / `dispatchSession` | `selected_publisher.rs:203-209`, `:253-259`, `:303-309` as Host CLI `selected-source-publication-submit|lookup INGRESS OUT` | socket arms at `Host/Main.lean:2093-2098`; the CLI route is in the Host's argument dispatcher (not read) | the Rust sends no op byte; it runs the Host CLI. The registry says the socket route is not present, yet `dispatchSession` has arms for 24/25 (Q8.10) |
| 40 FN_NAMESPACE_SUBMIT | operator / `fnDispatch` | `fn_namespace.rs:455` | `Host/Main.lean:7492-7507` | agree. Lean answers a malformed ingress with code **40** carrying a `refused` outcome, not 255 (`:7498-7500`). Rust then finds the outcome is not `confirmed` and falls through to lookup (`fn_namespace.rs:481-501`), so the refusal reason is not surfaced |
| 41 FN_NAMESPACE_LOOKUP | operator / **`dispatchSession`** | `fn_namespace.rs:329` | `Host/Main.lean:2120-2122` → `fnConsumerNamespaceLookupSession` `:1519-1525` | agree |
| 42 FN_NAMESPACE_PLAN | operator / `fnDispatch` | `fn_namespace.rs:146` (empty payload) | `Host/Main.lean:7508-7522` (refuses a non-empty payload) | agree |
| 43 FN_NAMESPACE_ASSEMBLE | operator / `fnDispatch` | `fn_namespace.rs:416-419` (`pair(plan, sig64)`) | `Host/Main.lean:7523-7540` (`splitPair`) | agree |
| 60/61, 62/63 | operator / `fnDispatch` | `fn_frontier.rs:573-579`, `:450-457` | `Host/Main.lean:7271-7286`; `fnSelectedPollLookupSession` `:1550-1556` | agree |
| 64 FN_FRONTIER_PLAN | operator / `fnDispatch` | `fn_frontier.rs:248` (payload from Host CLI `fn-frontier-request`) | `Host/Main.lean:7287-7298` (`fnFrontierPlanRequestCodec.decode`) | agree (Rust never encodes the codec) |
| 65 FN_FRONTIER_ASSEMBLE | operator / `fnDispatch` | `fn_frontier.rs:546-553` (`pair(plan, sig64)`) | `Host/Main.lean:7299-7312` (re-polls; refuses a changed plan) | agree |
| 144 KEY_ROTATION_STATUS | public,operator / `fnDispatch` | `hermes_handoff.rs:326-343`, `:645-664` (JSON `{subject, publicKey}`) | `Host/Main.lean:7027-7039`; query `Host/Json.lean:4344-4349` (exact object, 32-byte key); reply `:4333-4341` | agree (`type`, `isCurrent`, `currentRevoked`, `keyEpoch`) |
| 210-214 ACTIVITY_* | public,operator / `fnDispatch` | `activity.rs:99-102`, `:135`, `:239`, `:254`, `:302`, `:307` | `Host/Main.lean:5965-6002` via `:7269-7270` | agree (see 1.0 (8)); Rust does not decode 255 frames (section 4, F9) |
| 224, 226, 227 (local consent) | **absent from the registry** | `bend_session.rs:56-57`, `objective_invoke.rs:51-52` (227); `client_consent.rs:1101`, `:1112` (224, 226; other shard) | `Host/ClientConsentCore.lean:606` (227 → `objectiveHeaders`) | not checkable against the registry (Q8.9) |

Response markers used: 254 ("transport refusal: request never forwarded") and 255 ("Host refusal/outcome envelope") (registry `response_markers`). Only `activity.rs:65` names 254, and it renders it as `refused:`.

### 2.2 Views and kernel facts read through signed queries

The Host query views this shard relies on, and the JSON fields it reads from them:
- `resource`: `cell.entries[].key.field`, `.value`; `cell.declaration`, `cell.declaredFrom`; atoms `{type:"atom", id, kind, payload, tombstonedAt}`. Used by `chat.rs:847-866`, `story.rs:664-697`, `roomkey` via `signed_view`, `selected_exchange.rs:244-271`, `:712-736`.
- `tail` (STREAM-TAIL/v2): `entries[].{sequence, author, height, topic(hex), to, ref{cell,sequence}, payload(hex), payloadState}`, `nextSeq` (`chat.rs:892-928`, `:1247`). Lean renders `payloadState` `verified|absent|mismatch` (`Host/Json.lean:5118-5133`).
- `who`: `members[].subject` (`chat.rs:1048-1054`, `roomkey.rs:1789-1796`; Lean `Host/Json.lean:1509`, `:5960`).
- `since`: `entries[].{height, subject, cells[]}` (`chat.rs:1888-1921`, `:2225-2239`).
- `policy`: `{predicate, localSelector{physicalKinds, requestKinds, verbs}, parents, descendants}` (`story.rs:701-711`).
- `capability`: `{type, kind, head{id, holder{type,subject}, verbs}}` (`hermes_handoff.rs:256-304`).
- Refusal outcome JSON: `{type, reason, phase(hex), detail(hex), explain}` (shard A; read by `replan.rs:89-126`).

### 2.3 OS facilities

- Unix only. Almost every module uses Unix sockets, `std::os::unix` permissions or `libc` (`capture.rs:24-50`); the `main.rs` declarations are `#[cfg(unix)]`.
- `libc::tmpfile`, `dup`, `dup2`, `fileno`, `fclose` (`capture.rs`); `dup`, `dup2`, `close` declared by hand in `hermes.rs:407-411`.
- Directory fsync and owner-private files through `fsio`/`durable::create_new` ("absent or complete", `fsio.rs:16-18`).
- `flock`-style service locks (`transport::service_lock`): `fn_namespace.rs:354`, `fn_frontier.rs:482`, `selected_exchange.rs:818`, `selected_publisher.rs:400`, `publisher.rs:294`, `roomkey.rs:1661`, `:1903`, `hermes_handoff.rs:698`.
- Owner-or-root and permission checks: `hermes_handoff.rs:826-835` (uid 0 or euid, no group/world write).
- No bwrap, seccomp, cgroups, systemd or SO_PEERCRED in this shard.

### 2.4 Network services

- NNTP over STARTTLS to an operator-configured localhost fn (POST only, in `worker.rs`; post config `{"type":"minidregg-fn-post-v1","port","certificatePath","username","passwordFile"}` per `native/resource-client/README.md:510-514`).
- fn consumer polling happens inside the Host CLI routes (`selected-release-fn-poll`, `-legacy-poll`, `-fn-ack`, `fn-frontier-export`), which take the fn binary, scope and control socket as arguments (`selected_exchange.rs:413-430`, `:516-534`).
- No HTTP, Solana or Discord calls. The Discord mirror only reads `tail --json` output (`chat.rs:1806-1809`).

### 2.5 Files, config and templates

- Compiled-in templates (`include_str!`):
  - `deploy/shell/templates/room/chat/law.author.json` (`chat.rs:137`);
  - `room/private/law.keys.json` and `law.room.json` (`roomkey.rs:133-135`);
  - `hermes/{librarian,runner}/{grants,budget}.json` and `librarian/program.md` (`hermes.rs:44-48`);
  - `story/tale/table` (`story.rs:65`).
- Operator config files: `/etc/mini/hermes-residents.json`, `/etc/mini/hosted-subjects`, Hermes dispatch registrations (`mini-hermes-dispatch-registration-v1`), fn post config, selected-exchange contract JSON, fn approvals (`minidregg-fn-namespace-approval-v1`, `minidregg-fn-frontier-approval-v1`), provider-continuity descriptors (`mini-provider-continuity-v1`).

### 2.6 Other crates

- `mini-sdk`: decimal, hex, private, store (`publisher.rs:120`), secret.
- `compatible-upgrade-custody`: not used in this shard.
- `minidregg-mini-keys` and `minidregg-pay-watcher`: not used in this shard.
- Crypto crates: `ed25519-dalek`, `chacha20poly1305`, `argon2`, `sha2`, `sha3`, `zeroize`, and through `hybrid_kem.rs` (a file outside `src/`, `main.rs:88-92` per shard A) `x25519-dalek`, `aws-lc-rs`, `aws-lc-sys`.
- Consumers of this shard's commands in other crates: `native/grain-runtime/src/hermes_room.rs:516-529` (`hermes-handoff`), `native/grain-runtime/src/main.rs:8317` and `provider_resolution.rs:387-394` (`provider-continuity`), `deploy/hermes-dispatch/mini-hermes-dispatch.py:72`, and `native/discord-entrance` (`tail --json`, per `jchat.sh:20-21`).

---

## 3. Does it decide anything semantic?

The test from the brief: "mirrors a Lean decision for UX" (Lean still refuses what Rust pre-checks) versus "IS the decision" (nothing on the Lean side would refuse if Rust got it wrong). Rows marked **IS** violate ATLAS §7.

### 3.1 Places where Rust is the decision

**V1 (IS). The story law is generated in Rust for every table** (`story.rs:146-371`).
- *What Rust decides.* `table_of` decides which tables are valid (reachability, dead ends, one way per pair, item placement; `:204-258`). `player_clauses` decides the exact law installed on each player's cell (`:311-355`). `table_sealed_law`, `staging_law` and `scenes_law` decide the other laws (`:362-381`). `my_cell` decides whether a player's client considers its cell fair to play, by comparing the cell's policy with the Rust generator's output (`:987-1006`).
- *Lean counterpart.* `Assurance/StoryLaw.lean` defines `clauses` (`:105`), `law` (`:111`) and proves `sealed_story_scene_monotone` (`:265`) about `law`. But `scripts/gen-storylaw.py` makes Lean *imitate* Rust: it embeds "the client's player law" for the tale, and `tale_embedded_is_law` proves equality by `rfl` (script docstring, lines 1-12). For any `story new --from @FILE` table, no Lean code ever sees the table.
- *What Lean should own.* A Host `author story-law` export that emits `law t S` from Lean's own `Table`, and a Lean table checker. `story.rs` would then keep only parsing and display.
- *Blast radius.* A generator bug installs a law that does not enforce the table (skips, rewinds, unpaid items). The Host enforces exactly what was installed, and every player's `look` accepts it because it compares against the same buggy generator. The theorem covers the tale only.

**V2 (IS, display-level). Chat room semantics** (`chat.rs:29-46`, `:930-1038`, `:1349-1404`).
- *What Rust decides.* The merge order `(height, author, cell, sequence)` and entry numbering `#N`. "Only the founder's topic and pin count" (by the roster's founder row, `:1019-1024`). Reaction aggregation. Which payload shapes are `say`/`topic`/`pin`/`withdraw`/`request-status`. The Discord bridge's `via`/`author` display (`:970-978`, `:1377-1379`).
- *Lean counterpart.* None. The kernel enforces only "a member writes only its own stream" through the author law (`law.author.json`) and the room grant.
- *Blast radius.* Two clients, or the Discord mirror (which consumes `tail --json` `topic`/`pin`), can disagree about the room's topic and pin. Entry numbers drive `pin N`, `react N` and `say --re N` through a local cache (`entry_ref`, `:1495-1509`). The guard `--expect-re-cell/--expect-re-sequence` (`:1647-1652`) exists because renumbering is possible.
- *What Lean could own.* A Host view that returns the merged feed and the room's effective topic and pin by a declared rule.

**V3 (IS). Who may adopt or invite into a chat room** (`chat.rs:2121-2126`, `:2171-2174`, `hermes.rs:581-586`).
- *What Rust decides.* Founder-only is checked client-side, by the roster's founder field (chat) or by a local file's `founder` field (hermes summon, `:581-586`).
- *Lean counterpart.* The Host still judges every grant, birth and roster write. A non-founder cannot write the founder-written room cell under the author law, so for rooms born by `chat new` this is a UX mirror. For adopted open workrooms the doc itself says "a member holding `mutate` under the room may also add a row" (`chat.rs:2075-2079`). If such a member overwrites field `ROSTER_FROM` (the founder row), the Rust "founder" changes, and with it whose topic and pin count. Whether the workroom law forbids that is a Lean question (Q8.6).

**V4 (IS). Chat's retry policy outside `replan.rs`** (`chat.rs:683-758`, `:785-807`, `:1558-1571`).
- *Re-sign loop.* "A `stale-root` answer at either step is not a decision about the request" (`:696-699`): retry propose with a new proposal id, retry submit with the same intent in a new attempt directory, retry reads with a new nonce, each up to 10 times. Detection is by stderr text: `done.1.starts_with("refused: stale-root")` (`:686`, `:800`).
- *Re-propose loop.* On any `EXIT_REFUSED` whose text *contains* `staleTarget`, `append_recorded` re-runs `propose_submit_in`, which **authors a new proposal with a new nonce** for the same request, up to 3 times (`:1558-1571`).
- *Lean counterpart.* Typed refusal classes, with a Lean-stated "retryable after a fresh plan" property.
- *Blast radius.* If Lean ever returns `refused`/`staleTarget` for a call it committed (it should not), chat posts the message twice. The 10 × 6 nesting multiplies load on a busy Host (section 4, F1).

**V5 (policy IS, classification deferred). The re-plan engine** (`replan.rs:89-126`, `:213-217`; `workspace.rs:3634-3645`).
- *Deferred.* The classification itself comes from Lean's decoded outcome: Rust reads `reason`, `phase` and `detail` from op 8, so Rust does not guess the class.
- *Decided in Rust.* The policy "this class means definitely unadmitted, and a new attempt or a new authored operation is allowed". The append path additionally requires Rust's own signed read to show the preimage moved (`append_preimage_moved`).
- *Lean counterpart.* A Lean predicate on `Outcome` naming the retry-safe classes (`stale-root`, admission-phase refusal, `staleTarget`), proved: refused at that phase ⇒ not committed.
- *Blast radius.* Duplicate operations on the append path if a class is misjudged.

**V6 (IS). Laws and budgets authored in Rust when composing rooms and Hermes.**
- The till law is `credit-permit-all.json` (`hermes.rs:621-625`).
- Hermes's budget account law is `{"type":"all","predicates":[]}`, i.e. permit-all (`hermes.rs:637`). Lean admits whatever law the owner installs, so "anyone can write the budget account's law-governed fields" rests on capabilities alone.
- Every delegation in chat, hermes, story and roomkey uses `maxCost "50000"` (`chat.rs:1979`, `hermes.rs:522`, `story.rs:878`, `roomkey.rs:2145`). The spend ceiling of every room grant is a Rust literal.
- Default `--every 3` (`hermes.rs:597`).
- `room new --private` installs `law.room.json` = `{"type":"all","predicates":[]}` on the room cell (`shell.rs:177` → `roomkey.rs:146-148`).
- *Lean counterpart.* Template laws should be Lean-emitted artifacts (ATLAS §7 "every decision point is a Lean export or a Lean-emitted artifact"); budgets come from the tariff (`TARIFF_FIELDS`, `room_schema.rs:34-46`).

**V7 (IS, client-side gate). Hermes handoff acceptance and routing** (`hermes_handoff.rs:71-124`, `:305-493`, `:691-744`).
- *What Rust decides.* The resident's client decides whether a summon is authentic (Ed25519 `verify_strict` with a domain prefix, op-144 currency of the founder key on first delivery only, `:340`). It decides which assignment is current by comparing receipt `acceptedCount` strings (`point_current`, `:728-735`). It decides whether the account custody permits transfer (`transferGranted`, `:298`).
- *Mirror or decision.* The resident's subsequent effects are each re-admitted by Lean, so wrong acceptance cannot spend more than H's grants. But *which room's task the resident works on* is Rust's call.
- *Lean counterpart.* A Host view "current Hermes assignment for room cell C", derived from the room fields and the accepted origin.

**V8 (IS). Provider-allowance expiry** (`provider_continuity.rs:436-477`, `:832`).
- *What Rust decides.* `expiration` concludes that a contention-held, signed-but-unadmitted provider call can never be admitted (every slot's `validUntil < genesisHeight + checkedAcceptedCount`). The report's `decision: retire-expired-contention` is what grain-runtime consumes to release a held allowance (`provider_resolution.rs:387-394`).
- *Lean counterpart.* A typed Host answer "this exact call is expired and never admissible at any height ≥ H". Today Lean supplies the pieces (profile, op 17 v3 `priorChecked`, lookup `absent`, plan decoding) and Rust does the arithmetic.
- *Blast radius.* If the height convention is off by one, or Lean admits at `validUntil` inclusive while Rust treats `>` as expired, an allowance is released while the call could still land: a double spend of the provider allowance. Rust uses `current = genesis + count` (`:455`); `hermes_handoff.rs:386-390` uses `accepted = genesis + count − 1` for the last accepted height (Q8.4).

**V9 (IS by design, documented). Room-key entitlement and lineage** (`roomkey.rs:1301-1326`, `:271-310`, `:667-699`, `:2059-2110`).
- *What Rust decides.* Who receives epoch e+1, which epoch is current, whether a served keys cell is a rollback or a fork, and whether a release may proceed to disclosure. `Kernel/PrivateRoomKeys.lean:46-55` concedes these are client decisions.
- *Lean counterpart that exists but is unwired.* `Kernel/RoomReleaseCurrent.lean` ("every recipient's encryption record and offline room read entitlement are checked"), `RoomReleaseAuthority.lean`, `RoomReleaseIntent.lean`, `RoomReleaseLineage.lean`, `RoomReleaseAdmission.lean`, `Host/RoomKeyReleaseAuthor.lean`, `Compiler/RoomKeyReleaseCodec.lean`. All are imported only by `ResearchWip.lean:91-116`.
- *Blast radius.* Privacy (a kept or removed member mis-selected), not funds. The module labels itself "DEVNET QUALITY; PRIVACY NOT AUDITED" (`roomkey.rs:13`, `private.rs:71`).

**V10 (mirror). Activity front-end quoting** (`activity.rs:175-209`).
- Rust doubles the budget while Lean's verdict text names `frontEndExhausted`/`postageFrontEnd` (Lean constructors at `Kernel/ObjectiveActivityReceiverCore.lean:981`, `:1651`). It declares `postage = loads × planned`.
- Lean prices and refuses the declared envelope (`Delivery.heap_priced`, `docs/OBJECTIVE-BEND-EVENTS.md:183-184`), so this is UX. The coupling is by substring of Lean's rendered verdict.

**V11 (IS, external transport). NNTP repost policy** (`publisher.rs:208-282` versus `selected_publisher.rs:357-375`).
- `publisher.rs` allows one re-POST after `transport-uncertain`; `selected_publisher.rs` never re-POSTs. That is two different idempotency decisions for the same transport.
- Both rely on fn's Message-ID dedupe answering `441 … already stored here`. Not a Lean-admission decision, but a retry decision Rust owns twice, inconsistently.

**V12 (IS, small). Hard-coded Lean representation facts.**
- Room field numbers `"1008"`/`"1009"` (`hermes_handoff.rs:439-440`, `:476`, `:518-519`) duplicate `room_schema::TARIFF_FIELDS` (`room_schema.rs:42-43`).
- Event13 owner packets are atoms of schema `"11"` whose id equals the receipt's transaction id (`selected_exchange.rs:714-731`).
- The roster layout `ROSTER_FROM + 2k − 1, + 2k` (`room_schema.rs:52-55`) has no Lean declaration.

### 3.2 Places where Rust correctly defers

- *Refusal custody.* `prepare_refusal.rs` and `query_refusal.rs` retain bytes and hashes and interpret nothing (`prepare_refusal.rs:24-26`, `query_refusal.rs:11-12`).
- *Selected release.* `selected_release.rs` resubmits only the exact retained ingress, and only after a freshly re-decoded Lean `absent` (`:254-283`). The cached JSON is "only presentation" (`:140-142`).
- *fn custody.* `fn_namespace.rs`/`fn_frontier.rs` sign only the Host-selected header after an exact plan re-inspection. They never encode the fn or Lean codecs ("Rust does not encode either Lean codec", `docs/evidence/2026-09-27-fn-frontier-receiving/README.md`), and they never resubmit after a marker.
- *Objective signing.* `objective_invoke.rs` and `bend_session.rs` sign only headers that local consent endpoint 227 re-derives from the independent intent, with no fallback to the offered plan's headers (`bend_session.rs:1-4`).
- *Activity.* `activity.rs` lets Lean author and plan, and signs Lean's `header.canonical` (`:234-238`). The invoke-nonce rule is Lean's (`Host/ObjectiveActivityJson.lean:233-250`).
- *Chat payloads.* Chat shows text only when Lean's view says `payloadState: verified` (`chat.rs:899-907`), and `tail --held` re-renders through the Host's own renderer (`:1271-1274`).
- *Membership.* Chat and roomkey take the current members from Lean's `who`, not from the roster (`chat.rs:1837-1840`, `roomkey.rs:1789-1796`).
- *roomkey `turn`.* It never re-authors a room operation whose custody is incomplete, and recovers by exact lookup (`roomkey.rs:1666-1690`).
- *Story moves.* Every story move carries `expected` values and is judged by the installed law. A refusal is named by matching Lean's own explanation text (`story.rs:1121-1128`), display only.

---

## 4. Flaws noticed

The flaws are grouped by kind. Each names the exact line and a concrete failure.

### 4.1 Lost-reply and retry hazards

**F1. Chat multiplies retries: up to 60 attempts.**
- `propose_submit_in` retries a stale-root submit up to `FRESH_CHALLENGES = 10` times (`chat.rs:683`, `:733-752`).
- Each try is a `workspace submit`, which runs `main::submit` → `replan::replan` with up to 5 re-plans (`main.rs:1859-1864`, `replan.rs:37`).
- When replan exhausts, it re-records the stale-root decision (`replan.rs:159-161`), so `main_ending` prints `refused: stale-root …` and chat loops again.
- The same holds for reads: `signed_read` (10, `chat.rs:785-807`) wraps `query_retained` (6, `main.rs:2179-2184`).
- *Scenario.* In a busy room every member's `say` can make 60 signed observations plus prepares. The backoff only grows linearly (150 ms × attempt + jitter, `chat.rs:691-694`), so a contention storm feeds itself.
- *Fix shape.* One retry budget, in `replan.rs`.

**F2. Chat classifies refusals by prose.**
- `stale_root` checks `done.1.starts_with("refused: stale-root")` (`chat.rs:686`). `append_recorded` checks `text.contains("staleTarget")` anywhere in the captured refusal block (`chat.rs:1561`); that block includes the Host's detail and any `client:` lines.
- `replan.rs` already offers typed predicates on the decoded `HostDecision` (`is_stale_root`, `is_prepare_stale_target`), but chat sees only the child's stderr text because it runs commands through `capture::command`.
- *Scenario.* A future refusal detail that quotes a predicate or law text containing `staleTarget` triggers a re-proposal with a fresh nonce.

**F3. Re-running a lost `mini activity submit` makes a second operation (non-invoke turns).**
- `command_for` mints `fsio::random_nonce()` on every call for every turn except `invoke` (`activity.rs:114-127`). `submit` refuses an existing `--out` (`create_out`, `:211-213`), but a caller that retries with a new `--out` after a lost op-212 reply authors a new command with a new nonce.
- `ingress.bin` is retained before op 212 (`:240`), and `--action resubmit` exists (`:299-303`). The safe path is documented, not enforced.
- *Scenario.* The op-212 reply for a `topUp` is lost. The operator re-runs `activity --action submit --command topup.json --out attempt-2`. If Lean does not dedupe topUps by content, the purse is funded twice. `deliver` is protected by Lean's consume-once rule (`second_same_await_is_collision`, `docs/OBJECTIVE-BEND-EVENTS.md:168-174`). `topUp` has no such stated rule (Q8.3).

**F4. A failed kick rotation leaves the kicked member on the live key.**
- `kick` = preflight, then `room_kick` (revocations submitted), then `rotate` (`roomkey.rs:2756-2768`).
- If `rotate` fails after the revoke (its readback dies because a kept member published a new record, `check_readback` `:2040-2043`; a Host refusal; the passphrase missing; a transport loss), the room stays at the old epoch.
- Everyone keeps sealing new says under a key the kicked member holds (`current_key`, `:1616-1637`). The kicked member can no longer *read* through the Host, but the operator (who stores the ciphertext) can hand it over.
- The comment calls the preflight "a preflight only" (`:2757-2759`). Nothing marks the room "rotation owed" or refuses to seal until the rotation lands.

**F5. A chat invite is four non-atomic steps, and re-running it duplicates grants.**
- `invite` publishes the room grant (`chat.rs:2189`), births the stream and writes roster rows (`:2190-2197`), wraps the key (`:2198-2205`), then saves the invitation.
- A failure after the grant leaves the invitee holding a room grant with no roster row (it can read, but has no stream to write).
- Re-running `chat invite` calls `room_grant` again, which proposes a **new** delegation (fresh proposal id, `propose_submit`, `:1980`). Each retry adds a standing grant; `room_kick` later has to revoke them all (shell `room kick` revokes "every standing grant").
- Only the stream and rows are reused on re-invite (`prior`, `:2188`).

**F6. The roster slot is computed from a read, then written with `create`.**
- The new member's rows go to `member_fields(roster.members.len() + 1)` (`chat.rs:2191`).
- `roster_of` counts only complete subject+stream pairs (`chat.rs:860-864`). A previous partial write (subject row written, stream row not) yields a slot that collides with that partial row.
- Two concurrent invites by the founder read the same roster and pick the same slot. Whether the second `create` on an existing field is refused (correct) or silently overwrites is a Lean question (Q8.7).

**F7. `hermes summon` moves money before the agent is on the roster.**
- Step 2 funds H's account with the founder's `fund` (`hermes.rs:636-643`) **before** step 3 invites H (`:646-652`).
- The state file gains `hermes`/`role` with the step-2 save (they are set in memory at `:613-614` and persisted at `:641`).
- If step 3 or later fails, the budget sits in an account H owns. `dismiss` then walks `names = [room] + manifest docs` (`:773-778`; `manifest` is absent, so just the room) and proposes a revoke of a room grant H never received (`:781-786`). If Lean refuses that revoke (Q8.12), `dismiss` stops there, before the fields are zeroed and before `dismiss-ROOM.json` is written.
- Recovery of the funds depends on H's controller signing a return transfer "on its next attach" (`:28-35`, `:796-806`). Nothing in this shard enforces that.

**F8. `publisher.rs` swallows submit and retry errors.**
- `let _ = submit(...)` (`publisher.rs:107`), `let _ = retry(&directory, "lookup", false)` (`:131`), `let _ = retry(&directory, "submit", false)` (`:141`). The code then infers state from files.
- A submit that failed before writing `call.bin` reports "outbox submit has no retained exact call; operator review required" (`:125-127`) with the real error lost.
- Op 18 is sent with unpinned `transport::invoke` (`:154`), unlike every other operator path in this shard, which uses `invoke_pinned`.

### 4.2 Refusals that are not loud

**F9. `activity.rs` does not decode refusals and conflates 254 with 255.**
- `invoke` maps both 254 ("never forwarded") and 255 ("Host refusal/outcome envelope") to `refused: opN: <lossy UTF-8 of the last 600 bytes>` (`activity.rs:65-71`).
- A 255 body is a binary `outcomeCodec` value, so the user sees mojibake instead of Lean's reason. Every other path decodes 255 through op 8 (`main.rs` `socket_process`, per shard A).
- The README promises "Every refusal is the Host's, by name" (`activity.rs:24-25`). For 255 frames that promise is not kept.

**F10. fn custody hides Lean's refusal.**
- On op 40/60/62, a 255 frame means no `submit.outcome.bin` is written (`fn_namespace.rs:460-462`, `fn_frontier.rs:584-586`). A code-40 refused outcome (Lean answers a malformed ingress with code 40, `Host/Main.lean:7498-7500`) fails `receipt()` silently (`fn_namespace.rs:487`).
- Both fall to lookup → `absent` → "exact lookup absent; no automatic resubmit". The refusal frame is retained but never decoded or printed.
- The 2026-09-27 r3 run is exactly this: "op40 definite admission refusal … op41 exact original absent … terminal result was `fn namespace exact lookup absent; no automatic resubmit`" (`docs/evidence/2026-09-27-fn-namespace-native-r3/README.md`).

**F11. `publisher.rs` loses the reason for an op-18 refusal.** Lean answers code 18 with `{"status":"refused","reason":…}` (`Host/Main.lean:5499-5502`). Rust reports "accepted outbox export identity differs" (`publisher.rs:163-168`).

### 4.3 Integrity and custody of local files

**F12. A partial roomkey `turn` is resumable, but `publish_rotation` can collide.** `publish_rotation` builds a proposal id from `random_nonce().unwrap_or_default()` (`roomkey.rs:2682-2683`). On an entropy error every room gets the same id `rk-reg-`. The second room's `turn` then finds a retained proposal with a different request and refuses (`:1666-1669`), so later rooms never publish.

**F13. `selected_exchange` pins the running client binary.** `pin` includes `clientSha256` of `env::current_exe()` (`selected_exchange.rs:114`). Any rebuild or upgrade of `mini` between phases refuses every later phase ("contract or pinned input changed", `:119-122`), stranding a half-done exchange whose source event and POST may already be durable. `fnControl` is used (`:420`, `:523`) but not pinned (`file_pins`, `:90-104`).

**F14. One bad registration file blocks the whole Hermes registry.** `registry` aborts on the first malformed registration (`registration_file(&path)?`, `hermes_handoff.rs:802`). The same function treats custody failures per resident on purpose: "It cannot stop unrelated controllers" (`:813-814`). One stray `.json` in the registrations directory stops `/etc/mini/hermes-residents.json` from being regenerated for everyone.

**F15. Story and Hermes read request files unbounded and through symlinks.**
- `story::source` reads `HOME/requests/FILE` with `fs::read_to_string` (`story.rs:648-649`); `story_join` reads `@FILE` with `fs::read` (`:956`); `hermes summon --program @FILE` reads with `fs::read_to_string` (`hermes.rs:659-660`). None is bounded, and all follow symlinks.
- Chat reads the same folder through `crate::shell::session_fs::read` with a 1 MiB bound and descriptor anchoring (`chat.rs:1666`, `:2162`, `:2297`). Commit `336b7c0e` made that discipline gate-checked for `--operation-record` only.

**F16. `replan::holds_accepted` skips unreadable acceptance files.** An `outcome.json` that cannot be read or parsed is skipped (`replan.rs:263-264`), so `retire_attempt` treats the attempt as unaccepted. Retiring moves rather than deletes, and only follows a stale-root of this attempt, so the risk is small. But the guard is fail-open on a corrupt marker.

### 4.4 Panics and process hygiene

**F17. Two process-wide fd swaps, and `quietly` is not panic-safe.**
- `hermes::quietly` dup2s `/dev/null` onto fd 1 around `credit::room`, `workspace::create`, `credit::set_fields(_exact)`, `create_funded_account` and `my_account` (`hermes.rs:405-435`, uses at `:618-630`, `:637`, `:713-720`, `:746`, `:791-793`).
- If any of those panics, fd 1 stays `/dev/null` and the saved fd leaks. The shell runs each line under `catch_unwind` (`shell.rs:2569-2581`, shard A), so the session survives with its stdout silenced for every later line.
- `capture::streams` is safe only because `capture::command` wraps `crate::run` in `catch_unwind` inside the body (`capture.rs:94-95`).

**F18. Key bytes are copied out of `Zeroizing`.** `RoomKey::from_parts(epoch, **key)` dereferences `Zeroizing<[u8;32]>` into a by-value array argument (`private.rs:202`, `:207`, `:655`, `:760`). The temporary stack copy is not zeroized. This is minor key hygiene.

**F19. Overflow in `activity.rs`.** `2 * budget.0` and `quote.loads * decimal_member(...)` are `u128` arithmetic on caller-supplied JSON (`activity.rs:196`, `:203-204`). They panic in debug and wrap in release. A wrapped declaration is refused or charged by Lean, so the effect is a confusing refusal, not a breach.

**F20. Process-global replan counters.** `replan`'s `MAX`, `COUNT` and `CONFIGURED` are process-global atomics (`replan.rs:42-49`). In `mini web` (multi-threaded), concurrent requests share the re-plan bound and the counter. The per-thread `HOST_DECISION` is safe; whether `client_consent::take_stale_observation` is per-thread is not visible here (Q8.11).

### 4.5 Performance and resource use

**F21. Every chat `tail` re-reads every stream from sequence 1.**
- `read_room` calls `held.stream(…, full = true)` for each roster member (`chat.rs:1139-1141`). Each stream is paged 256 entries at a time, up to 64 windows (`:1240-1254`). `tail -n 20` therefore costs O(total room history) signed reads.
- The JCHAT row measures a 200-entry tail (`jchat.sh:321-326`) but has no recorded run.
- The `--follow` path is incremental (`:1873-1922`); the plain path is not.

**F22. `tail --follow` polls forever.** One signed `since` read every 3 s (`chat.rs:1886-1922`), with no bound or idle backoff.

### 4.6 Hermes custody details

**F23. Hard-coded room field numbers.** `"1008"`, `"1009"` are literals (`hermes_handoff.rs:439-440`, `:476`, `:518-519`), while `ASSIGNMENT_FIELD` comes from `room_schema` (`:13`). A schema change would update one and not the other.

**F24. Re-delivery accepts a revoked founder key.** `verify(.., first_delivery=false)` skips the "founder key is current and not revoked" requirement (`hermes_handoff.rs:340`). The comment says a different key may re-sign after rotation (`:221-222`). But re-verification happens before every resident action (`check_delivery`, `:560`). A bundle signed with a founder key that was later *revoked for compromise* keeps activating as long as the room fields still match (Q8.8).

### 4.7 Stale documentation that contradicts code

- `chat.rs:4-7` describes the v1 roster (founder at field 2, member k at fields 2k+1 and 2k+2). The code uses ROOM-SCHEMA v2 (`ROSTER_FROM = 2000`, `room_schema.rs:30`, `:52-55`).
- `deploy/hermes-dispatch/README.md` says "The roster reserves 499 historical non-founder subject slots … A new subject at the boundary receives an explicit refusal". `room_schema.rs:5-15` and `chat.rs:2187` say the tail is unbounded.
- `private.rs:79-80` says the passphrase is handed to "the shell's own `mini` subprocess (`chat::client`)"; that subprocess no longer exists.
- `private.rs:419` says `v1` in a v2 parser's error.
- Root `README.md` (Honest state, Chat row): "no recorded run has joined chat to a native Host". J14 PASS did (`docs/evidence/2026-10-01-p-hermes-room/j14.tsv:33`, `:38`; `tail-final.txt`), on a lane build that predates `336b7c0e` and ROOM-SCHEMA v2.
- Root `README.md` (Objective row): "the call (C1-C8) and send (S1-S7) drivers exist and no journey row runs them". `scripts/pipeline/journey-rows:105-138` now defines `row_call` and `row_send` (not this shard's code; noted for the synthesis).

---

## 5. Unwired / undone

### 5.1 Reachability, entry point by entry point

"Wired" follows the brief: reached from a `fn main` argument arm *and* from a journey script, systemd unit, deploy script or other crate. The search covered `scripts/`, `deploy/`, `native/` and `testing/`, excluding `docs/`, `target/` and `.lake/`.

| Entry point | Module | Reached by | Recorded run |
|---|---|---|---|
| shell `say/tail/topic/pin/unpin/react/chat …/room ls` | `chat.rs` | `mini shell` (`shell.rs:1132`, `:2840`); `journey.d/jchat.sh` (row JCHAT); `j14.sh`; `jpriv1.sh` chat part | J14 PASS on a lane build, 2026-10-01 (`chat new`, `invite`, `say`, `tail`, `ask`), before `336b7c0e` and ROOM-SCHEMA v2; JCHAT SKIPPED in all three 10-01 results; JPRIV1 in no result file |
| shell `story …/look/go/take/act/narrate` | `story.rs` | `mini shell` (`shell.rs:1135`, `:2844`); `j15.sh` (row J15) | J15 PASS, `docs/evidence/2026-10-01-p-story/journey-result.json` |
| `mini story-law` | `story.rs:472-493` | `scripts/gen-storylaw.py` | used to regenerate `Assurance/StoryLaw.lean` §8 |
| shell `summon/ask/dismiss/hermes status|cancel` | `hermes.rs` | `mini shell` via `chat::plan` (`chat.rs:243-245`); `j14.sh` | J14 PASS 2026-10-01 (summon output names the account `lab-hermes`; current code names it `h-a{assignment}-hermes`, `hermes.rs:634`, so the code changed after the run) |
| `mini hermes-handoff --action dispatch|registry|registration` | `hermes_handoff.rs` | `deploy/hermes-dispatch/mini-hermes-dispatch.py:72` (no systemd unit installs it; README only) | none located |
| `mini hermes-handoff --action check-delivery|check-dismissal` | `hermes_handoff.rs` | `native/grain-runtime/src/hermes_room.rs:516-529` | via row `hermes` (`scripts/pipeline/journey-rows:444`) only if that driver reaches assignment activation (not settled here) |
| `mini submit --provider-continuity` and `mini provider-continuity` | `provider_continuity.rs` | `native/grain-runtime/src/main.rs:8317`, `provider_resolution.rs:387-394` | not located in evidence |
| `mini activity` | `activity.rs` | `objective-activity-native-acceptance.py`, `activity_world.py`, `objective-seat-native-acceptance.py`, `objective-charged-failure-journey.py`, `objective-upgrade-native-journey.py` (rows `activity`, `seats`, `chargedfailure`, `upgrade`) | per root README, rows `activity` and `seats` "integrated on scratch worlds" |
| `mini objective-invoke` | `objective_invoke.rs` | `objective-native-acceptance.py` (row `objective`) | PASS at `4795b657` per root README |
| `mini bend-session-sign` | `bend_session.rs` | **nothing** (only `main.rs:4508`; `.spw` maps mention it) | none |
| `mini fn-namespace-plan|register|lookup` | `fn_namespace.rs` | **nothing** | manual r3 attempt 2026-09-27, refused at op 40 |
| `mini fn-frontier-plan|advance|lookup` | `fn_frontier.rs` | **nothing** directly; `selected-exchange --phase cover-plan|cover-advance` is itself unreached | none (only unit, clippy and fmt logs in `2026-09-27-fn-frontier-receiving/`) |
| `mini selected-exchange --phase prepare|publish|receive-transport|verify-transport` | `selected_exchange.rs` | `selected-exchange-journey.sh` (row `exchange`) | 2026-10-08, two green runs and one planted red |
| `--phase receive|cover-plan|cover-advance|ack|verify|status` | `selected_exchange.rs` | **nothing** | none |
| `mini selected-source-sign|selected-source-publish` | `selected_publisher.rs` | `selected-source-publisher-acceptance.sh` (no journey row); `selected_exchange` prepare/publish | via the exchange row |
| `mini selected-release-submit|lookup` | `selected_release.rs` | `selected-release-acceptance.sh`; `selected-exchange-journey.sh:486-488`, `:545-547`; exchange receive phases | via the exchange row |
| `mini selected-release-retry` | `selected_release.rs:273-283` | **nothing** | none |
| `selected_release::recover` | `selected_release.rs:257-271` | exchange `receive`/`receive-transport` on re-entry | exercised by the exchange row's exact-retry pass (`selected-exchange-journey.sh:445-447`) |
| `mini origin-publish` | `publisher.rs` | **nothing** | manual run 2026-09-26 (`native/resource-client/README.md:528-533`) |
| `selected-release-drop-reply` binary | `selected-release-drop-reply.rs` | `selected-release-acceptance.sh:381` (rustc) | input hashes appear in `docs/evidence/2026-09-27-*` source manifests |
| `replan`, `prepare_refusal`, `query_refusal` | core | every signed submit and query | every journey |
| `capture::command` | `capture.rs` | `chat::client` only | J14 ran the earlier child-process version |
| room-key ops (`workspace --action room-key --op …`) | `roomkey.rs`, `private.rs` | shell `room new --private`, `room invite/kick/rotate/…`, `chat new --private`; `jpriv1.sh`; `rooms-e2e.sh` (row `rooms`) | row `rooms` "red on main at `4795b657` (0 of 88 expected rows present)" (root README) |

### 5.2 Dead or vestigial code

- **`bend_session.rs` (75 lines): an orphan.** Its only reach is a hidden pre-parse arm not listed in `USAGE` (shard A, item 1).
- **`fn_namespace.rs` + `fn_frontier.rs` (1,462 lines): orphans** with no driver. They need a configured fn service, approvals and fn-e articles to be live (1.0 (5)).
- **`selected_exchange.rs` fn-e path** (`receive`, `cover_plan`, `cover_advance`, `ack`, `verify`, and `selected_poll`; roughly `:184-207`, `:400-456`, `:594-652`, part of `:654-745`): unreached. SELECTED-EXCHANGE.md says it "remains for a schema-1 `fn-e` accepted-article event; it refuses `fn-r`", and current fn stores `fn-r`.
- **`publisher.rs` (552 lines)** and `selected_release::retry_submit`: no caller.
- **Vestigial parameters and attributes:** `let _ = subject;` (`chat.rs:1068`), `let _ = root;` (`hermes_handoff.rs:230`), `let _ = &ws.root;` (`activity.rs:320`); `#[allow(clippy::too_many_arguments)]` on six-argument `selected_publisher::publish` (`selected_publisher.rs:387-395`).
- **Deleted-helper scars:** blank runs in `fn_namespace.rs:22-26` and `fn_frontier.rs:24-26`.
- **Unwired Lean twin of roomkey's release machine:** `Kernel/RoomRelease{Admission,Authority,Current,Intent,Lineage}.lean`, `Host/RoomKeyReleaseAuthor.lean`, `Compiler/RoomKeyReleaseCodec.lean`, imported only by `ResearchWip.lean:91-116`.
- No `TODO`/`FIXME`/`todo!`/`unimplemented!`/`#[allow(dead_code)]` in the shard (grep).

### 5.3 Twins

| Twin pair | Sites | Reachable | Delete which |
|---|---|---|---|
| fn custody machine | `fn_namespace.rs` (`source_inspect` `:27-46`, `expect_frame` `:48-56`, `Retained`/`retained` `:58-106`, `verify_inspection` `:108-124`, approval check `:178-229`, `pair` `:231-240`, `receipt` `:250-263`, `lookup` `:315-348`, marker logic `:446-518`) ↔ `fn_frontier.rs` (the same names at `:27-47`, `:49-57`, `:67-138`, `:312-328`, `:330-391`, `:394-403`, `:154-168`, `:438-476`, `:405-436`, `:572-622`) | neither | collapse into one "operator custody of one Host-authored plan" module parameterized by op triple and approval field list |
| NNTP POST custody | `publisher.rs:192-425` ↔ `selected_publisher.rs:328-493` (same result JSON shape, same literal status lines, different repost rules) | `selected_publisher` | keep one `post_action` with one repost rule; delete `publisher.rs` if origin-publish is not in the plan |
| Refusal retention | `prepare_refusal.rs:27-82` ↔ `query_refusal.rs:13-70` | both | one function with `stage`, `operation` and destination-name parameters |
| fd capture | `capture::streams` (`capture.rs:60-77`) ↔ `hermes::quietly` (`hermes.rs:405-435`) | both | delete `quietly`; run the composed calls through `capture::command` or have the callees not print |
| Stale-root retry | `replan.rs` (typed, bounded by `--replan-max`) ↔ `chat.rs:683-758`, `:785-807`, `:1558-1571` (prose-matched, fixed 10 and 3) | both | delete chat's loops; let `replan` own the budget |
| Clause rendering | `story::render`/`explained` (`story.rs:412-449`) ↔ `Compiler/RefusalReason.lean` `renderClause` and the Host's `LawLeaf.explained` (cited in `story.rs:410-411`, `:436-437`) | both | have the Host render (a law-explain op exists in shard A's `shell/law.rs` per its report) |
| Story law | `story::player_clauses` (`story.rs:311-355`) ↔ `Assurance/StoryLaw.lean` `clauses`/`law` (`:105`, `:111`) | Rust is live; Lean is the proof object, checked only for the tale | invert: Lean emits, Rust prints |
| Room field numbers | `hermes_handoff.rs:439-440`, `:476`, `:518-519` ↔ `room_schema::TARIFF_FIELDS` (`room_schema.rs:42-43`) | both | use the table |
| Room-key release | `roomkey.rs:1712-2110` ↔ `Kernel/RoomRelease*.lean` (unwired) | Rust | decide which is the future; ATLAS 13 says delete the twin |
| Per-module helpers `digest`/`read_json`/`durable_json`/`member` | redefined in `publisher.rs:7-21`, `selected_publisher.rs:79-95`, `selected_exchange.rs:11-62`, `selected_release.rs:15-17`, `fn_namespace.rs:12-21`, `fn_frontier.rs:14-23`, `prepare_refusal.rs:12-14`, `query_refusal.rs:7-9`, `hermes_handoff.rs:14-47` | all | one shared helper in `fsio` |

### 5.4 Versioned siblings

- Inside files, old wire versions are refused by name rather than kept: v1/v2 encryption records (`roomkey.rs:1003-1008`), v2 auth wraps (`:1207-1211`), v1 keyrings (`private.rs:508-513`), v1 rooms (`room_schema.rs:101-107`). That is the correct pattern.
- `provider_continuity.rs` keeps three op-17 framings (legacy, v2, v3; `:131-173`). The legacy pair is still used by `main.rs:3113` (`request_payload(…, None, false)`).
- `fn_frontier` reads plan type `fn-consumer-frontier-plan-v2` (`fn_frontier.rs:106`, `:264`); no v1 code remains.

### 5.5 Tests that test only their own fixture

- **`roomkey.rs`.** The release state-machine tests run against `FakeHost` (`:3631-3654`). It appends atoms and refuses duplicate ids, but implements none of `keysLaw`. Tests such as `release_binds_records_then_reads_back_then_discloses_the_wrap` (`:3687-3704`) prove the client's order and readback logic, not that the Host admits those writes. The keys-law shape test (`:3557-3574`) compares the template JSON with a literal, a byte check against itself. Its name, `the_template_laws_are_the_ones_the_lean_theorems_name`, claims a link to Lean that the test does not exercise.
- **`publisher.rs`/`selected_publisher.rs`.** The `post_action`/`source_action` tests are truth tables of the module's own function (`publisher.rs:458-534`, `selected_publisher.rs:584-634`). `concurrent_post_claim_is_create_new` (`publisher.rs:536-551`) tests `create_new`, not concurrency.
- **`chat.rs`.** The merge, topic and pin tests run on hand-built `Entry` lists (`:2470-2518`). The roster test uses a hand-written view (`:2575-2597`). No test reaches the Host's real STREAM-TAIL rendering.
- **`hermes.rs`.** `a_librarian_holds_no_verb_that_bears_or_grants` (`:906-915`) checks the template file's verbs against the code's own allow-list.
- **`story.rs`.** `story_law_grammar_is_its_json` (`:1212-1221`) round-trips Rust's renderer through Rust's parser (`shell::law::parse`). Nothing compares it with Lean's `renderClause`.
- **Tests with real teeth.** `replan.rs` tests both poles of every classifier (`:312-349`) and the loop's bounds (`:414-516`). `private.rs` has known-answer vectors from independent implementations (`:1188-1237`). `fn_namespace`'s lost-reply socket test (`:610-703`). `selected_release`'s lost-reply socket test (`:348-410`). `hermes_handoff`'s tamper and origin tests (`:1055-1096`).
- **No tests at all:** `activity.rs`, `bend_session.rs`, `objective_invoke.rs` (467 lines).

---

## 6. Size and shape

### 6.1 Lines per file and family

| Family | File | Total | Test | Code |
|---|---|---:|---:|---:|
| A: refusal and re-plan core | `replan.rs` | 561 | 258 | 303 |
| | `prepare_refusal.rs` | 160 | 77 | 83 |
| | `query_refusal.rs` | 151 | 80 | 71 |
| B: composing shell verbs | `chat.rs` | 2,642 | 311 | 2,331 |
| | `capture.rs` | 125 | 20 | 105 |
| | `story.rs` | 1,246 | 103 | 1,143 |
| | `hermes.rs` | 1,011 | 203 | 808 |
| C: private rooms | `private.rs` | 1,440 | 511 | 929 |
| | `roomkey.rs` | 3,863 | 989 | 2,874 |
| D: resident and provider | `hermes_handoff.rs` | 1,359 | 328 | 1,031 |
| | `provider_continuity.rs` | 1,272 | 429 | 843 |
| E: Objective | `activity.rs` | 323 | 0 | 323 |
| | `objective_invoke.rs` | 69 | 0 | 69 |
| | `bend_session.rs` | 75 | 0 | 75 |
| F: fn custody | `fn_namespace.rs` | 704 | 158 | 546 |
| | `fn_frontier.rs` | 758 | 108 | 650 |
| G: selected publication | `selected_release.rs` | 411 | 127 | 284 |
| | `selected_publisher.rs` | 635 | 141 | 494 |
| | `selected_exchange.rs` | 978 | 131 | 847 |
| | `publisher.rs` | 552 | 126 | 426 |
| | `selected-release-drop-reply.rs` | 95 | 0 | 95 |
| | **Total** | **18,430** | **4,100** | **14,330** |

Family totals: A 872; B 5,024; C 5,303; D 2,631; E 467; F 1,462; G 2,671.

The test column counts the `#[cfg(test)] mod … { }` regions (scratch `testlines.py`). `chat.rs` has two test modules (`:2331-2614`, `:2616-2642`). Every other file has one at the end.

### 6.2 A minimal version for the Hetzner demo

The deployed candidate "has no rooms, chat, key rotation or proxy mode" (root `README.md`, Honest state, first row). The demo-critical path through this shard is therefore the signed-command spine:
- **Keep (872):** `replan.rs`, `prepare_refusal.rs`, `query_refusal.rs`.
- **Keep if Objective Bend is part of the demo (+392):** `activity.rs`, `objective_invoke.rs`. Rows `objective` and `activity` are the integrated ones.

**Tier 1, documents and boards only (no rooms).** Drop 17,166 lines (17,558 without Objective):

| Drop | Lines | Notes |
|---|---:|---|
| `fn_namespace.rs`, `fn_frontier.rs` | 1,462 | no caller |
| `publisher.rs`, `selected_release.rs`, `selected_publisher.rs`, `selected_exchange.rs`, `selected-release-drop-reply.rs` | 2,671 | the exchange row is research transport, not demo |
| `bend_session.rs` | 75 | no caller |
| `hermes.rs`, `hermes_handoff.rs`, `provider_continuity.rs` | 3,642 | Hermes is "off on the public node"; removing `provider_continuity` also needs `grain-runtime` edits (`main.rs:8317`, `provider_resolution.rs:387`) and the `submit --provider-continuity` arm (`main.rs:4313-4326`, `:1953-1970`) |
| `story.rs` | 1,246 | shell `story` verbs; `deploy/shell/templates/story` |
| `chat.rs`, `capture.rs` | 2,767 | shell chat verbs; `web/resident.rs` uses `chat::room_feed` and `hermes::request_rows` |
| `private.rs`, `roomkey.rs` | 5,303 | see the coupling below |

**Coupling that blocks a clean drop.** `private.rs`/`roomkey.rs` are referenced from:
- `workspace.rs` (16 `private::` and 30 `roomkey::` references), e.g. `workspace.rs:43-48`, `:1732`, `:2823`, `:3088`, `:3112`, `:4848`, `:4902-4905`, `:6381-6539`;
- `shell.rs` (`:176-177`, `:456`, `:789`, `:2626`, `:4104`, `:4283`);
- `key_rotation.rs` (`:610-614`, `:822`);
- `main.rs`: `keygen` (`:1140-1166`: `MemberPublic`, `escrow_seed`, `hosted_marker_path`, `KEYGEN_NOTICE`), `enc-public`/`enc-key-id` (`:3650-3669`), `escrow-recover` (`:3683-3688`), and the passphrase adoption at the top of `main` (`:4505`);
- `context_projection.rs:51-52`, `doc_search.rs:87-88`, `render/mod.rs:365-370`.

`private.rs` also carries `legacy_content`, `opened_text` and `is_private_kind`, which `workspace.rs`, `context_projection.rs`, `doc_search.rs` and `render/mod.rs` use for any document holding private atoms. It also carries `keygen`'s notice, hosted marker and opt-in escrow. `keygen` is demo-critical, so a tier-1 build must keep that slice of `private.rs` (or move it next to `keygen`). Dropping Family C therefore means removing private-room support from `workspace.rs` and `shell.rs` (shard A) and making `legacy_content` refuse every private action.

**Tier 2, rooms and chat demo (public rooms, no private rooms, no Hermes, no fn).**
- Keep chat + capture (2,767) and story (1,246, optional) on top of tier 1's keep set.
- Drop 13,153 lines (Families C, D, F, G, plus `hermes.rs` and `bend_session.rs`). This keeps 5,277: the core, chat, capture, story and the 392 Objective lines.
- `chat.rs` itself references `roomkey`/`private` at `:1153-1202`, `:2042`, `:2153-2205`. Those arms would refuse `--private` instead.

---

## 7. Deployability on a small public Linux VM

### 7.1 What must exist on the box for this shard's code to run

- The `mini` binary and the pinned `minidregg-host` image (every module shells out to it or reaches it through `session_invoke`). Linux, because of Unix sockets and `libc` dup2/tmpfile.
- Per member: a session home and a workspace with owner-private folders (`HOME/requests`, `HOME/chat`, `HOME/story`, `HOME/hermes`, `ROOT/private`). `session_fs::private_folder` refuses group-readable folders (`journey-private.sh`, quoting `shell/session_fs.rs`).
- For chat: the room templates are compiled in (`include_str!`). Nothing else.
- For private rooms: `MINI_KEYCACHE_PASSPHRASE` in each member's environment (`roomkey.rs:1436-1441`), and optionally `/etc/mini/hosted-subjects`.
- For Hermes: `/etc/mini/hermes-residents.json` (no installer in `deploy/` creates it), a dispatcher process (`deploy/hermes-dispatch/mini-hermes-dispatch.py`; no systemd unit), registrations with operator-owned modes, resident workspaces and inboxes, the `grain-runtime` resident, and a provider.
- For fn and selected exchange: an fn node (SBCL image, NNTP on localhost; the 10-08 run needed `--dynamic-space-size 8192` and a 24 GiB row limit, per the evidence README), an fn post config with a password file, operator sockets, approvals and contracts. Not demo material.

### 7.2 Operator-configured inputs

| Input | Used by |
|---|---|
| `MINI_KEYCACHE_PASSPHRASE` | private rooms |
| `MINI_HOSTED_SUBJECTS` / `/etc/mini/hosted-subjects` | private-room invites |
| `MINI_REPLAN_MAX`, `MINI_REPLAN_LOG` | every signed command |
| `/etc/mini/hermes-residents.json`, `HOME/hermes/registry.json`, `HOME/hermes/node.json` | `summon` |
| Hermes dispatch registrations; the `mini-hermes-dispatch-service-v1` config (`mini-hermes-dispatch.py:28`) | dispatcher |
| provider-continuity descriptors | grain-runtime |
| fn post config, fn approvals, selected-exchange contracts | Families F and G |

### 7.3 What is dangerous to expose

- **Operator-socket commands** (`fn-*`, `origin-publish`, `selected-*`, `hermes-handoff --action dispatch|registry`) must not be reachable by members. They check that the socket is owner-private (`check_private_socket`) and that registrations are owner-owned, but they run as whoever invokes them. Keep them off the member shell. Shard A's `REMOTE_COMMANDS` (`main.rs:847-850`) already excludes them for `--remote`.
- **`MINI_REPLAN_LOG`** appends to any path the invoking user can write (`replan.rs:199-209`). That is harmless for a member's own account, but an operator unit must not inherit a member-controlled environment.
- **`capture.rs` and `hermes::quietly`** swap process-wide descriptors. They must never be reached from a multi-threaded server: `mini web` or a proxy serving several members in one process. Today `web/resident.rs` reaches only the read-only `chat::room_feed` (no swap).

### 7.4 What a stranger on the internet could exercise

Nothing in this shard is reachable without an enrolled subject and a session. Every chat, story and Hermes verb needs a workspace key and Host admission; the fn and selected commands need operator sockets. A stranger's reach is the shell entrance and Host routes, which are shard A and the Host's concern.

### 7.5 What a malicious enrolled member could exercise

- **Read amplification.** Spam their own stream (each append is admitted under the author law). Every reader's `tail` then re-reads all history: O(history) signed reads per `tail` (F21), up to 64 × 256 entries per stream per call.
- **Spoofed bridge display.** Post a `say` with `"via":"discord","author":{"id":"…","name":"…"}` (the shell accepts `--via discord --via-id --via-name`, `chat.rs:325-338`). Other members see `<member> via discord <name>#<id>: …` (`chat.rs:1377-1379`). The speaker's own petname is shown first, but a Discord-mirror consumer reading `tail --json` gets `via` and `author` fields asserted by any member (`entry_json`, `:1421-1424`). Whether the mirror trusts only its own bridge subject is in `native/discord-entrance` (JCHAT checks "every bridged entry is signed by the bridge's own subject", `jchat.sh:303`, but JCHAT has no recorded run).
- **Ignored control entries and noise.** Post topic, pin and request-status lookalikes. Topic and pin are shown "ignored"; a `request-status` from a non-Hermes author is ignored by `request_rows` (`hermes.rs:231`). Raw JSON is shown as text.
- **Roster rewrites in adopted open workrooms.** Rewrite roster rows. If the workroom law lets members `mutate` the room cell, a member might write `ROSTER_FROM` and so become "founder" for topic and pin purposes (V3, Q8.6).
- **Stories.** As a story author, supply any table. Rust generates the law. Players' clients check the installed law against the same generator, so a buggy generator would be accepted on both sides (V1).
- **Private rooms.** As a private-room member, publish a malformed encryption-key record. It is skipped with a stderr note (`roomkey.rs:1251-1256`). A wrap of the wrong schema in the keys cell is impossible: only the founder writes wraps (`keysLaw`).
- **Self-harm only.** As an invitee, set `MINI_HOSTED_SUBJECTS` to an empty file to dodge the hosted check on one's own invites. The signed custody byte still applies (`roomkey.rs:2373-2376`).
- **Ballooning a founder's spend.** Accept an invitation and do nothing. Each `chat invite` retry by the founder adds a standing grant (F5), and each stream birth is paid by the founder (`chat.rs:2137`, "you paid for it").

---

## 8. Questions for the Lean side

Each question is phrased so a Lean reader can answer it by pointing at a declaration.

**Q8.1 Retry safety of refusals.** For an `Outcome` with `type = refused` and `phase = admission` returned by op 2 (`fnDispatch` SUBMIT), is there a theorem that the submitted call was **not** committed? Which declaration? The workspace append path authors a new operation on this basis (`replan.rs:109-117`, `workspace.rs:3634-3645`).

**Q8.2 `staleTarget`.** `DeclaredResourceController.Reject.staleTarget` is returned at prepare (`Kernel/DeclaredResourceController.lean:2089`). Is it ever returned *after* a write is recorded, through any path (prepare → submit replay, carried history)? Chat re-proposes on the substring `staleTarget` anywhere in a refusal (`chat.rs:1561`), so the answer bounds duplicate chat posts.

**Q8.3 Activity `topUp` and other non-invoke turns.** Each `mini activity submit` gives them a fresh nonce (`activity.rs:114-127`). Does `Kernel/ObjectiveActivityReceiver` refuse or dedupe a second `topUp` with identical content and a different nonce? The same question applies to `publish`, `create`, `birth`, `resolve` and `abandon`. Which declarations state the at-most-once property per turn kind? (`deliver` has `second_same_await_is_collision`.)

**Q8.4 Height convention for provider continuity.** In the native Host, is the admission height of the next transaction `genesisHeight + acceptedCount` and the height of the last accepted one `genesisHeight + acceptedCount − 1`? Is a signed slot with `validUntil = h` admissible at height `h` (inclusive)? `provider_continuity::expiration` treats `validUntil < genesis + newCount` as expired (`provider_continuity.rs:455-470`); `hermes_handoff` computes `acceptedHeight = genesis + count − 1` (`hermes_handoff.rs:383-390`). Point at the declaration that `pin-plan-height` and the op-17 v3 `priorChecked` reply rely on.

**Q8.5 A Lean "expired, never admissible" answer.** Is there, or could there be, a Host lookup outcome stating that an exact retained call can never be admitted (all deadlines passed)? Today Rust derives `retire-expired-contention` (`provider_continuity.rs:832`).

**Q8.6 Roster founder row in adopted rooms.** For a room born with the workroom or social template and then `chat adopt`ed, can a non-founder member holding `mutate` (or `place`) under the room write object field 2000 (`room_schema::ROSTER_FROM`/`FOUNDER_FIELD`) of the room cell? Which law clause or `RoomBirthGate` declaration forbids it? Rust uses that field to decide whose topic and pin count (`chat.rs:1019-1024`).

**Q8.7 `create` on an existing field.** For a scalar action `{"type":"create","key":{"type":"object","field":F},"value":V}` on a declared cell where F already holds a value, does admission refuse (and with what reason)? Chat computes roster slots from a read and writes them with `create` (`chat.rs:2017-2025`, `:2191-2195`).

**Q8.8 Revoked founder keys in Hermes handoffs.** Is there a Host query that distinguishes "key rotated away" from "key revoked for compromise" for a subject's past key? `hermes_handoff::verify` checks currency only on first delivery (`hermes_handoff.rs:340`).

**Q8.9 Local consent endpoints.** Are local-consent endpoints 224, 226 and 227 (`Host/ClientConsentCore.lean:606`, `client_consent.rs:1101`, `:1112`, `:1129`) meant to be in `protocol/host-operations.json`? They share the u8 op space with the registry, and 227 is load-bearing for `objective-invoke` and `bend-session-sign`.

**Q8.10 Ops 24/25 routing.** The registry says "currently Host stdio only, socket route not present" with empty routes, but `dispatchSession` has arms for 24 and 25 (`Host/Main.lean:2093-2098`). Which is current: are these arms reachable on the socket, or dead?

**Q8.11 (for the `client_consent.rs` reader).** Is `client_consent::take_stale_observation` thread-local like `HOST_DECISION`? `replan::stale_root` consumes it (`replan.rs:213-217`).

**Q8.12 Revoking an absent grant.** What does admission answer for a `revoke` request whose recipient holds no grant on the named reference? `hermes::dismiss` revokes the room grant even when `summon` failed before inviting (`hermes.rs:779-787`).

**Q8.13 Story laws.** Is `Assurance/StoryLaw.lean` `law` (`:111`) meant to become the emitter for **every** table (a Host `author story-law` returning `law t S` as predicate JSON)? Is there a Lean counterpart of `story::table_of`'s validity rules (reachability, dead ends, one way per scene pair)? Today they exist only in Rust (`story.rs:204-258`).

**Q8.14 Room-key entitlement.** Is `Kernel/RoomReleaseCurrent.lean` (with `RoomReleaseAuthority`, `RoomReleaseIntent`, `RoomReleaseLineage`, `RoomReleaseAdmission`, `Host/RoomKeyReleaseAuthor.lean`; all imported only by `ResearchWip.lean:91-116`) intended to replace the client-side release state machine (`roomkey.rs:1712-2110`)? If so, which Host op number is reserved for "event67"? None appears in the registry.

**Q8.15 `PrivateRoomWrapGrant` compile status.** `Kernel.lean:156` says "AUTHORED, NOT COMPILED". Is that still true at main? The keys-grant confinement ("a member's grant reads only its own wraps") is what `roomkey::keys_grant` (`roomkey.rs:2143-2153`) relies on for record writes.

**Q8.16 Story player-cell birth.** `story.rs:46-51` says "the room's birth gate judges a placement with the request's slots only; nothing in it names the law the new cell is born with". Is that still true of `Kernel/RoomBirthGate*.lean`? It is why the author must birth every player's cell (and pay for it).

**Q8.17 Who view semantics.** Does `who` (`Host/Json.lean:1509`, `:5960`) list subjects whose *current, unrevoked* capability covers the room cell, including grants with `notAfter` in the past? `roomkey::rotation` and `check_readback` treat `who` as the entitlement set (`roomkey.rs:2045-2047`, `:2595-2601`).

**Q8.18 Activity verdict strings.** Is the plan inspection's `verdict` text (`Host/ObjectiveActivityJson.lean:372-373`) a stable interface? `activity.rs:191-192` branches on the substrings `frontEndExhausted` and `postageFrontEnd`. Would Lean expose a typed field instead?

**Q8.19 Event13 representation.** Is "the recipient's admitted event13 owner packet is an untombstoned `inlineObject` atom of schema `11` whose id equals the receipt's `transactionId`" stated in a Lean declaration? `selected_exchange::verify` hard-codes it (`selected_exchange.rs:714-731`).
