# Mini resource client

`mini` (`native/resource-client`, one binary, `Cargo.toml` `[[bin]]`) is the physical custody and evidence client
for `minidregg-host`. The Lean host authors every semantic binary value and is the only receiver that decides
admission. The Rust process holds raw keys, signs the exact headers the host printed (after the local consent check
re-derives the plan, `src/client_consent.rs`), and retains every byte needed to recover from an uncertain response.
Rust does not author intents, plans, calls or outcomes.

The command surface is `USAGE` in `src/main.rs:690`; `mini` with no arguments prints it. This file does not copy it.
Each module's `//!` header states its contract; the ones named below are the entry points.

Build: `CARGO_BUILD_JOBS=2 cargo build --manifest-path native/resource-client/Cargo.toml`.

## Where things live

| concern | where |
|---|---|
| one signing and submit flow (observe, plan, consent, sign, assemble, submit, lookup) | `native/mini-sdk/src/flow.rs`; the CLI's side of it is `CliHost` (`src/main.rs:1797`, `:1832`) and `submit` runs `mini_sdk::flow::Flow` (`src/main.rs:1865`, `:1948`, `:2075`) |
| attempt custody: an exact call and what became of it; lost reply is answered by lookup of the same call, never by a new nonce | `native/mini-sdk/src/custody.rs:1-27`; used by `src/main.rs`, `src/workspace.rs`, `src/app_document.rs` |
| Host socket transport, envelope, per-operation bounds, uncertainty | `src/transport.rs` |
| consent plans (which operations the signer re-derives before signing) | `src/client_consent.rs:286`, from the generated registry `protocol/host-operations.json` |
| participant workspace: references, retained attempts, proposals, delegation, birth, append recovery | `src/workspace.rs` (header), `src/replan.rs` (the one bounded re-observe loop, `--replan-max`) |
| operator custody for an application share, an event21 purse reserve, a paid dispatch | `src/share_issue.rs`, `src/agent_reserve.rs`, `src/agent_payer.rs` (each header states the approval it checks) |
| selected public release and its fn transport | `src/selected_release.rs`, `src/selected_exchange.rs`, `SELECTED-EXCHANGE.md`, unit `deploy/fn/mini-fn-receive@.service` |
| provider continuity and metering quotes | `src/provider_continuity.rs`, `src/meter.rs` |
| portable prefix evidence (`export-evidence`, `verify-evidence`) | `USAGE` (`src/main.rs:832-833`); codec `Compiler/FnEvidenceCodec.lean` |
| the shell | `src/shell.rs`, `src/shell_grammar.rs`, `src/shell/`; `deploy/shell/` |
| `mini web` | `src/web.rs` and `src/web/`; `docs/WEB-FRONTEND-2026-10-27.md` |
| the hybrid key exchange every wrap uses | `native/hybrid_kem.rs` |

## Facts a reader needs

- **Outcome markers.** `NO_RECORD` is 253 and `HOST_OUTCOME` is 255, generated constants
  (`native/host-operations.rs:401,405`, from `protocol/host-operations.json` by `scripts/host-operations.py`) and
  imported by the client (`src/main.rs:275`). A frame under 253 is the Host's decision that nothing was appended; the
  rest of the contract is in the `src/main.rs:228-280` comments and `native/mini-sdk/src/flow.rs:109`.
- **Socket envelope v2 only.** The service refuses envelope v1 by name ("socket envelope v1 is retired",
  `src/transport.rs` `split_envelope`). A v2 envelope carries the SHA-256 of the client's chosen Host image, and a
  service running other bytes refuses it. Every sender pins: `transport::invoke_pinned*`, `mini enrollment-view
  --host HOST|--host-sha256 HEX`, `mini_sdk::operator::{request, Operator::new}` (the pin is not optional), and the
  journey scripts that hand-build frames (`journey-stranger.py`, `jnock2/3/3p/5`, `jjob`, `jjob1`, `jjob-money`,
  `jeval`, `jsync`, `jpay-e4`, `jworld-method`, `j12x`'s `raw`). `j12x` keeps one row that sends v1 on purpose and
  asserts the socket's refusal by name.
- **Shell grammar is data.** `src/shell_grammar.rs` describes each verb once (`GRAMMARS`, 69 grammars, `:478`); the
  parser, `help`, completion and the web forms consume it. The `VERBS` rows in `src/shell.rs:54` only hold the order:
  every one has empty usage and operation strings, rendered from the grammar (`rendered_row`). The module header's
  "verbs land here one by one" (`src/shell_grammar.rs:8-9`) predates the last conversion.
- **`mini web` is not read-only.** The loopback server (`--listen 127.0.0.1:PORT`) serves signed reads and POST forms
  for document edit and creation (`src/web.rs:8-19`, the POST routes at `:297`, `:679-680`). `--body` (and
  `--anonymous`) is the face the web gateway uses. The source-studio routes (`/studio`, `src/web/studio.rs`) are
  still compiled and served on the loopback server (`src/web.rs:679-708`) and answer 404 on the body face
  (`src/web/body.rs:261`); their deletion is assigned in `docs/DEMO-PREFIX-2026-10-26.md` (L2, ruling D7).
- **No pure-X25519 path.** `native/hybrid_kem.rs` is the only key exchange in `native/` and `x25519_dalek` appears
  nowhere else (`rg x25519_dalek --glob '*.rs'`).

## Journeys and acceptance

The definition of done is the journey, `docs/JOURNEY.md`: `native/resource-client/journey.sh` with hooks in
`journey.d/`. The older `*-acceptance.sh` scripts in this directory are not gates (see that document for which are
called); `newparticipant-acceptance.sh` is J0's body and `provisioning-acceptance.sh` is M3's.

## Other documents in this directory

`SELECTED-EXCHANGE.md`, `PAID-COLD-ENTRY.md`, `PLATFORM-PROVISION.md`, `PUBLIC-INGRESS.md`, `KEY-ADOPTION.md`,
`MEMBER-WORKSPACE.md`, `JOINED-MEMBER-JOURNEY.md`, `WELCOME-CONTINUITY.md`, `FRESH-CONTINUITY.md`, `WORLD-PROGRAMMER.md`;
the traffic-privacy research line (`pq_mailbox.rs`, `cohort_tcp.rs`) is `PQ-MAILBOX.md` and `COHORT-TCP.md`.
