# What Mini exposes: an affordance inventory

Review report, 2026-10-26. Main is at `a0db11f8`. The live node is `dregg-workhorse`, which serves
candidate `5688775a`. Nothing was built, run against a Store, or sent over ssh. The one binary I ran was
`native/resource-client/target/release/mini --help`: built Oct 19, needs no Store, and its source was
last changed `e1d53913` on Oct 17. Its output is the CLI list used below.

**Every affordance carries a status, and the status comes from code and evidence, never from a doc
sentence:**

- **exists**: the code is in main and a test or journey hook exercises it.
- **journeyed**: either a recorded Linux run exists in `docs/evidence/`, or the row id is a required
  row in `scripts/pipeline/required-rows`. Lines marked `known-red` or `pending` there do not count as
  green.
- **deployed**: the node at `5688775a` has it. The authority for that is `deploy/shell/FRIENDS.md:11-37`
  (node read on 2026-10-03) and `docs/review/2026-10-26-deploy/HCLOUD-GAP.md` §1 and §3.
- **authored**: the code is there but nothing exercises it.
- **doc only**: a doc describes it and no code was found.

One caveat for every "journeyed (required row)" entry: the standing-run `results.tsv` files live on hbox,
not in the tree. Main's last recorded verdict is in commit `27a4fdae` (main `cfb68bf9`, 10-16: PASS 136,
FAIL 2). **No standing-run result for batch 3 (`3618d842`) or later is recorded anywhere I could read.**

---

## 0. The answer in eight lines

1. **CLI: yes.** `mini` has about 127 live top-level commands (`main.rs:3196-4530`). About 45 of them
   are reached by no journey, unit, script or other crate (resource-client review §Executive 2).
   **Shell: yes.** `mini shell` has 54 verbs plus chat, Hermes and story verbs. Main has many verbs the
   node lacks: the node answers 25 of them (`git show 5688775a:native/resource-client/src/shell.rs:49-80`, matching `FRIENDS.md:13-16`).
2. **SDK: two, and neither is a product yet.**
   - The Rust `native/mini-sdk` is a library of custody and signing parts. Its end-to-end
     `flow::Client` has no test and no caller.
   - The `mini` CLI re-implements the same path and does **not** use the SDK's confirmation-gated
     signing.
   - `native/mini-sdk-ts` is private, has no transport (it builds and signs only), has no lockfile, and
     is not gated.
3. **Raw protocol.**
   - 184 active Host operations: 113 public, 69 operator-only and 2 stdio-only.
   - 107 of the 113 public operations have a `mini` verb. Six can only be reached by a raw frame:
     133, 135-137, 201 and 202.
4. **From outside**, a stranger today meets only the hosted ssh shell, and only once ember has enrolled
   them by hand.
   - Fleet, fleet-sign, the fn selected exchange, the pay rail and proxy mode are journeyed in main and
     absent from the node.
   - Discord and the enrollment HTTP endpoint exist only against fakes and unit tests.
   - `mini web` is loopback-only.
5. **Inside Hermes**, a resident gets a fixed, operator-pinned MCP tool catalogue: room read and post,
   document read and append, typed propose, and app API calls. It runs in a bwrap jail with no network
   except the provider socket. It holds no keys, and every write is a paid, Host-admitted transaction.
   - There are three Hermes runtimes, and only the one that bypasses the gateway, purse and key broker
     has a room journey.
   - Nothing Hermes runs on the node.
6. **The datamodel** is one World of cells of 18 kinds, written only by `World.admit`. The nouns:
   participants and keys, capabilities, laws (`Pred`), a Book (accounts, assets, wells, floors),
   hyperdocuments, streams, activities and objects, seats, and grains. It persists as an append-only
   SQLite `durable_log` with MAC'd checkpoints.
7. **Performance: yes, there is work to do now**, and it is specific.
   - The bar is write p99 ≤ 5 s and cold reopen ≤ 60 s at 1000 records (`docs/JOURNEY.md:70-72`). Its
     per-landing row `births` is still `pending`.
   - The only recorded p99 at 1000 records is **10 s, which fails** (hbox, 10-14).
   - Room create takes 262 s, and SPK STOP takes 7–51 minutes.
   - The work that has landed since (resident consent, kept checkpoints, perf-memo, trie) **has no
     post-landing measurement in the tree**.
8. **What a public demo ships today** is shape A: the ssh shell's documents, boards, delegation, laws
   and refusal explanations. Everything else is "main has it, the node doesn't".

---

## 1. The surfaces

### 1.1 The `mini` CLI (native/resource-client)

Dispatch is at `native/resource-client/src/main.rs:3196-4530`, and the help text at `main.rs:642-839`.
The help text leaves out 12 live commands, including `activity` and `seat`, which back required rows
(resource-client review §Exec 1). Under `--remote` only 12 commands are allowed (`main.rs:847-850`,
`3187-3194`).

| group | verbs | who | status | evidence | what a person can do |
|---|---|---|---|---|---|
| keys and identity | `keygen`, `rotate-key`, `key-status`, `adopt-next-key`, `key` (two unrelated families: provider keys and hiding keys, `main.rs:3226-3232`), `enc-public`, `escrow-recover` | member | journeyed: `journey/JROT`, `JROTL` (required) | `journey.d/jrot.sh`; `required-rows` | Make a key with a pre-committed next key, and rotate to it later without losing grants. |
| join and enroll | `join` (4 routes, `main.rs:3198-3202`), `enroll` (plan/offer/welcome/possess/seal/submit/lookup; `cosign` is undocumented, `participant_enrollment.rs:1749`), `session-enrollment-*`, `pay-claim`, `enrollment-view` | sponsor, member | journeyed: `journey/J1`, `m4`, `welcomecontinuity` (required); deployed: `enroll` | `journey.sh:285`; `FRIENDS.md:14` | A sponsor admits a newcomer key, with no genesis edit. |
| workspace and documents | `workspace --action …`, about 80 actions (`workspace.rs:6208-7073`), `member`, `operation-proof` | member | journeyed: J2-J8 (required), J12 134/134 (`docs/evidence/2026-09-30-shell-docs`); deployed: the subset the shell exposes | `required-rows`; FRIENDS:22 | Birth resources, write, read, delegate, install laws, retry exactly. |
| rooms (private keys) | `workspace --action room-key …` (`workspace.rs:6386-6544`) | member | journeyed: the `rooms` row is required, but `jpriv1.expected.tsv:1-3` says "NOT FROM A RUN" | `journey-rows:55-66` | Found, invite, rotate and kick in hybrid-PQ wrapped private rooms ("DEVNET QUALITY; PRIVACY NOT AUDITED", help text). |
| fleet | `fleet --action join/send/publish/transfer/receipt/lookup/poll/feed/incoming` (`fleet.rs:1139-1262`), `fleet-sign` (`fleet_sign.rs:52`) | agent | journeyed: `m8`, `fleetsign` (required); `docs/evidence/2026-09-30-fleet-surface`, `2026-10-06-fleet-migration` | `journey-rows:569-570` | An agent joins under a sponsor, posts fee-paying signed turns to its own topic, pays others, and polls topics it may observe. |
| credit and pay | `credit` (`credit.rs:698-1003`), `pay` (`pay.rs:2242-2336`), `well` (new/mint/burn/floor/ledger) | member, observer, operator | `jpay/JPAY1-4` required; `JPAY6` known-red (`required-rows`); credit journeyed only as J17 lane evidence (`docs/evidence/2026-10-01-p-credit`) | — | Pay a room's week, top up Hermes, mint from a well under its floor. |
| jobs and markets | `job --action post/claim/fund/answer/check/settle/list` (`job.rs:956-964`); the shell's `market/bid/reveal` | member | exists (JJOB, JJOBM, JMKT hooks; not required). `journey.sh` defines `step_JJOBM` twice (`:1053`, `:1060`) | — | Post a priced compute job against a program, then claim it and settle with a bond. |
| objective, activity, seat | `objective-invoke` (`main.rs:4373`), `activity` (`:3222`), `seat` (`:3223`) | author, agent | `activity`, `seats`, `call`, `send`, `domain`, `upgrade`, `objectrecord`, `bounty` required; `objective` runs but is not required | `required-rows:23-32` | See §1.13. |
| operator and serve | `serve`, `serve-operator`, `serve-public-proxy`, `operator-status`, `drain-operator`, `bootstrap`, `socket-proxy`, `clock`, `checkpoint`, `consent-resident` | operator | used by every row; `hostupgrade` required; `jserve` known flaky (`docs/PIPELINE-HBOX.md:237-240`) | — | Run a Store, an operator socket and a public relay. |
| generic Host calls | `author`, `submit`, `query`, `retry`, `inspect`, `profile`, `describe`, `current-*-intent` | agent, test | journeyed indirectly (J0-J8 go through them) | — | Speak any intent kind with exact-retry custody. |
| evidence and audit | `store audit`, `audit`, `export-evidence`, `verify-evidence` | auditor | `journey/JAUDIT` required; export/verify have no live caller (resource-client review §Exec 2) | `journey.sh:1073` | Re-derive the whole Store from genesis and re-admit every ingress. |
| fn transport | `consumer-*`, `reply-consumer-*`, `origin-*`, `fn-namespace-*`, `fn-frontier-*`, `meter`, `continuity` | operator gateway | authored: evidence dirs from 09-26/27 only, no row, no live caller | `docs/evidence/2026-09-27-fn-*` | Gateway loops for Mini over NNTP. |
| selected exchange | `selected-exchange --phase …`, `selected-release-*`, `selected-source-*` | operator, member | `exchange` required, for 4 phases | §1.7 | A second Store receives one owner-selected content version through fn. The fn transport is not on this demo; the exchange row runs in the nightly against a loopback peer when its image exists. |
| agent reserves | `agent-reserve-*`, `agent-lifetime-*`, `agent-payer-sign` | operator, agent | authored: evidence dirs 09-27, no row | — | Operator-approved purses for agent grains. |
| channel and relay | `relay*`, `channel`, `traffic`, `mix`, `mix-live` | relay operator | exists (KCH hooks), not required | `jchan-*.sh` | Constant-rate cover-traffic chat outside Host admission. |
| SPK share issue | `share-issue-*`, `grain-share-issue-*`, `historical-call-receipt-lookup` | operator | `m6grain` known-red | `required-rows` | Issue sharing tickets for grains. |

### 1.2 `mini shell` verbs (the hosted product)

The verb table is `native/resource-client/src/shell.rs:54-107`, plus `chat.rs:68-74`, `hermes.rs:55-58`
and `story.rs:71-76`. The node's verb set is in `FRIENDS.md:13-16`.

| verb | a person can… | status | evidence | node |
|---|---|---|---|---|
| `whoami`, `help`, `exit` | see their session, subject and encryption key id | journeyed (`m4`) | shell-journey 89/89 (`docs/evidence/2026-09-30-shell-journey`) | **deployed** |
| `keygen` | make a key, plus `.next` on main | journeyed | m4 | **deployed** (one key, no next key) |
| `init`, `enroll` | bind provisioning; sponsor a newcomer | journeyed | m4 | **deployed** |
| `refs`, `read`, `describe`, `import`, `export`, `inbox` | list, read, describe and pass references | journeyed (m4; J12) | shell-journey; shell-docs | **deployed** |
| `create`, `invoke`, `delegate`, `revoke`, `law` | birth a cell, write, grant narrower rights, revoke, install a law | journeyed | m4; J12 | **deployed** (JSON laws only; `create` takes no fields) |
| `propose`, `submit`, `lookup`, `retry`, `publish`, `history` | the attempt lifecycle, with exact retry after a lost reply | journeyed | m4 | **deployed** |
| `doc new/show/append/edit/link/backlinks` | shared documents | journeyed (J12 134/134) | `docs/evidence/2026-09-30-shell-docs` | **deployed** |
| `doc insert/move/mark/annotate/transclude/history/diff/pull/push/search/--at/--html` (about 40 subverbs) | full hyperdocument editing, transclusion, history | exists (K12*, JDV, JPD hooks) | `jdocuverse.sh`; `protected-document-journey.sh:180-297` | main only (FRIENDS:25) |
| `board` | a task board | journeyed (J12) | shell-docs | **deployed** |
| `can`, `inspect`, `why`, `renounce` | dry-run which verbs pass; Lean views; explain the last refusal | exists (J12A, JINSPECT, K10C) | — | main only (FRIENDS:24) |
| `key-status`, `rotate-key`, `adopt-next-key` | pre-rotated key rotation | journeyed (JROT; rooms) | jrot.sh | main only |
| `provision` | account plus factory grant for a newcomer | exists | jchat, jpriv2 | main only: absent from the 5688775a VERBS (checked), so OPERATOR.md:19-20, which says the shipped client must have it, is wrong for the node |
| `room …`, `chat`, `say`, `tail`, `unpin`, `forget` | rooms, templates, private rooms, chat | journeyed (`rooms` required; J14/J15/J17 lane runs) | `docs/evidence/2026-10-01-p-hermes-room/j14.tsv`, `p-story`, `p-credit` | main only |
| `topic`, `pin`, `react` | room control entries | exists (JCHAT, not required) | — | main only |
| `pay`, `credit`, `tariff`, `topup` | a paid week in a room; fund Hermes | journeyed as J14/J17 lane evidence only | `p-credit/j17.tsv` | main only |
| `summon`, `ask`, `dismiss` | bring a Hermes librarian into a room | journeyed as J14 lane evidence (scripted provider) | `p-hermes-room/journey-result.json` | main only |
| `hermes status/cancel` | — | authored | none | main only |
| `story`, `look`, `go`, `take`, `act`, `narrate` | story rooms (collective fiction under a law) | journeyed as J15 lane evidence | `docs/evidence/2026-10-01-p-story` | main only |
| `kind`, `program`, `instance` | member-defined world kinds, Nock methods, instances | exists (P7KR; the `jworld-*.sh` hooks are not in STEPS, `journey.sh:192`) | — | main only |
| `market`, `bid`, `reveal`, `bids`, `job`, `jobs` | sealed-bid markets; compute jobs | exists (JMKT, JJOB) | — | main only |
| `app`, `home`, `key`, `channel` | app status; my resources; provider keys; relay chat | authored (unit tests) | `shell.rs:4178-4199`; `keys.rs:452-509` | main only |

**Mismatches between FRIENDS.md and the code:**
- FRIENDS:22 lists a `lock` verb. No such verb exists: `lock` is a proposal id inside `law lock`
  (`shell.rs:3623`).
- FRIENDS:29 says chat has no recorded native-Host run. J14 contradicts that: it has `chat new/invite/join`,
  five `say` rows and `tail` against `minidregg-host-phr1`.
- FRIENDS:3-4 describes main at `5216e02f`.

### 1.3 Rust SDK (`native/mini-sdk`, `publish = false`)

The header is `src/lib.rs:1-31`. The default features are an "offline core" that the header says
builds on wasm32. The only evidence for that is commit messages `20ff06ac` and `f1a41d19`: no gate, no
Linux run.

| module | an integrator can… | status | evidence |
|---|---|---|---|
| `profile` | derive keys from a 64-byte seed: `dregg/0` for Bread, `mini/<gen>` for Mini (`profile.rs:17-67`) | journeyed as a unit gate (`sdk-golden`, `check-rust-tests.sh:537-540`) | — |
| `signer` | sign Ed25519 or hybrid Ed25519 + ML-DSA-65 (`signer.rs:35-42`) | exists (`sdk-pq` row) | `check-rust-tests.sh:238-244` |
| `contracts` | build typed intents with canonical bytes pinned to Lean (`contracts.rs:105-401`) | exists (`sdk-lean-pin`; `sdk-lean-codec` armed) | `check-rust-tests.sh:246,254` |
| `explain`, `confirm`, `sign` | render a Host-presented plan, bind a nonce confirmation, and sign only under it (`confirm.rs:33-90`, `sign.rs:28-48`) | exists but mostly ungated; `confirm.rs` has 0 tests | — |
| `custody`, `store`, `durable`, `lock` | the attempt state machine and retained attempt directories | exists (`sdk-custody`) | `check-rust-tests.sh:204-218` |
| `operator` | operator-socket client over a unix socket or `ssh:DEST`, with every failure classed unsent or uncertain (`operator.rs:1-60,347-557`) | journeyed: `sshe2e` (required) | `journey-rows:316-334` |
| `consent`, `host`, `frame` | clients for the Lean consent process and the Host codec ops 7-11 | `host.rs` authored (0 tests) | — |
| `flow::Client` | the whole prepare → seal → transmit path (`flow.rs:25-99`) | **authored only**: 0 tests, 0 callers | `docs/SDK.md:51+` |

**Who uses it:**
- `native/resource-client` (`Cargo.toml:16`) and `native/discord-entrance` (`Cargo.toml:29`), for
  helpers only: decimal, hex, private, durable, store, operator-ssh and so on.
- Nobody uses `flow`, `explain`, `confirm`, `sign`, `contracts` or `profile`.
- grain-runtime, pay-watcher and mini-keys do not depend on it at all.

### 1.4 TypeScript SDK (`native/mini-sdk-ts`, `@minidregg/sdk`)

- `package.json:6-13`: `private: true`, node ≥ 23.6.
- It wraps the Rust core compiled to wasm (`src/core.ts:1-54`), with a native TS `explain` that is
  differentially tested against the Rust one.
- **No transport**: there is no socket, fetch or child_process in `src/`. Reaching a Host is left to a
  "native-messaging bridge" that is doc only (`index.ts:6-7`, `SDK-DESIGN.md:118-127`).
- No lockfile; `node_modules` and `wasm` are absent; no script, journey or CI row runs it.
- The only run on record: 15/15 tests on ember's Mac (commit `f1a41d19`).
- **Status: authored. Not runnable as checked out.**

### 1.5 Raw protocol (`protocol/host-operations.json`)

- 186 entries: 184 active and 2 reserved (191, 192).
- Routes: 113 public+operator active, 69 operator-only, 2 stdio-only (24, 25). These counts agree with
  `scripts/host-operations.py check`.
- The operator-only 69 break down as: spk 19, spk-lifecycle 16, hermes 16, fn-services 10, pay
  self-enrollment 4 (117-120) and spk-recovery 4 (206-209).

| public group | ops | `mini` verb |
|---|---|---|
| kernel-client | 12 (0-11: describe, prepare, submit, lookup, challenge, query, author …) | submit, query, retry, author, inspect |
| payments | 21 (103-116, 121, 181-186) | `pay`, `pay-claim`, `enrollment-view` |
| identity | 17 (86-95, 140-144, 187-190) | enroll, join, rotate-key, adopt-next-key |
| fleet | 8 (96-102, 180) | `fleet` |
| nock | 7 (131-137) | 131, 132 and 134 via `world_kind.rs`; **133, 135, 136, 137 by raw frame only** (`transport.rs:331`) |
| fn-services | 6 (12-18) | consumer, origin verbs |
| world | 5 (91, 123-125, 130) | `current-resource-intent`, `well` |
| activity / seats | 5 + 5 (210-219) | `activity`, `seat` |
| spk | 4 (28-31) | share-issue, current-*-intent |
| clock / history / job-money | 4 + 4 + 4 | `clock`, `checkpoint`, `job` |
| inference, selected-release, app-dispatch, laws, continuity | 2 + 2 + 2 + 1 + 2 | `meter`, selected-release, `member`, `law-sat`, `continuity` |
| resource-reserve-birth | 2 (201, 202) | **raw frame only** (`transport.rs:312`) |

**Socket contracts** (`deploy/candidate/INTERFACES.md:198-280`):

- `mini serve`:
  - socket directory 0700, socket 0600, "only that account can connect";
  - 10 s each to receive and to reply; the client waits 600 s.
- `serve-operator` admits its own uid plus each `--peer-uid` (`transport.rs:1192-1222`).
- `serve-public-proxy` relays the registry's public routes, with 64 connections at 10 s each
  (`public_proxy.rs:67-73`).
- **INTERFACES.md:208 is stale.** It says serve "handles one request at a time". In fact connections
  are concurrent (64 connections, a Host queue of 32, 60 s queue residence) and only the Host exchange
  is serial (`transport.rs:1524-1551`, `:1752`).
- **INTERFACES.md:203-204 is also stale.** It describes "one short process per durable read" and per
  signature. Both helpers serve in-process since `9309a9be` and `4eeb1b1f`.

### 1.6 Fleet surface (agents)

See the fleet row of §1.1. More detail:
- every turn pays `tariff.base` as a real Book fee, and there is no faucet (`docs/FLEET-SURFACE.md:25-27`,
  `180-190`);
- a turn costs about 15 Host requests and about 2.1 s (`FLEET-SURFACE.md:238-243`);
- throughput falls from 0.186 to 0.083 admitted/s as concurrent writers grow, with up to 8 re-plans per
  turn (`:197-215`).

`fleet --action incoming` is called by no script. **Status:** journeyed (`m8`, `fleetsign` required),
not deployed.

### 1.7 fn and a second Mini node

The fn transport is not on this demo; the exchange row runs in the nightly against a loopback peer when its image exists. (ember's ruling, 2026-10-27; every network leg below is the nightly's loopback, not the demo's.)

Required row `exchange` (`journey-rows:782-811`). Evidence:
`docs/evidence/2026-10-08-selected-exchange-local-fn/README.md` and
`2026-09-30-selected-exchange-two-credentials/README.md`.

**What a second node can do today, precisely:**
1. Store A publishes one owner-selected content version as an NNTP article to a fn node it reaches by
   port, which in practice means loopback (`selected_exchange.rs:380`, `worker.rs:144-150`).
2. Store B reads it over fn's local control socket and admits that exact packet into an inbox it created
   under a release law.
3. Tampering, a wrong signer or a wrong root are refused, and an exact retry replays.

**What it cannot do yet:** fn-e verdicts, event17 cover, the cursor ACK, or anything across two
machines. The `consumer-*` worker family has no row. **Status:** journeyed (one machine), not deployed.

### 1.8 Discord

- `native/discord-entrance` serves `/mini <line>` (one `mini shell --line` as the rostered session),
  `/mini-help`, `/mini-world` and `/mini-status` (`src/server.rs:185-236`).
- A room mirror says Discord text through the bridge's own key (`src/bin/mini-discord-mirror.rs:1-40`).
- Limits (`server.rs:26,73,160-167`):
  - 1000 characters per line;
  - 4 lines in flight;
  - 300 s timestamp window.
- The roster is root-owned and edited by hand (`src/roster.rs:1-77`). An unrostered user is told
  "nothing ran. Ember must add you" (`server.rs:206-212`).
- **Status:** exists, with fake-Discord runs: `docs/evidence/2026-09-30-discord-entrance` (27/0) and
  `2026-10-03-discord-world`. JCHAT is not required. Not deployed, and no Discord application exists
  (`FRIENDS.md:34`).

### 1.9 SSH entrance

| | hosted (`mode=shell`) | proxy (`mode=proxy`, `mini --remote`) |
|---|---|---|
| forced command | `deploy/shell/mini-shell-ssh:21-26` | `deploy/shell/mini-socket-proxy`, also a `mini-provider-credentials-v1` branch to mini-keys (`:29-31`) |
| key lives | on the box, readable by every member on today's single `mini` uid (`FRIENDS.md:50-52`) | on the friend's machine |
| status | **deployed**, journeyed (m4; shell-journey 89/89; DEPLOY-2b over the internet, 132 rows) | journeyed only through the SDK ssh client (`sshe2e`); JP2 (`jpriv2.sh`) not required |

**The "proxy friends cannot sign" claim is stale.** `deploy/shell/README.md:75-84` and HCLOUD-GAP §3 both
make it. But thin consent (`MINI_THIN_CONSENT=1`, frames 230-232, "read no Store",
`client_consent.rs:262-267`) exists, and `jpriv2.sh:134-150` enrolls and writes over `--remote` with a
nonexistent `storageRoot`. No recorded run of it exists, so the claim should become "unjourneyed", not
"refused".

One more mismatch: `mini-socket-proxy:12` advertises `mini --remote … key --action set`, but `key` is
not in `REMOTE_COMMANDS` (`main.rs:847-849`), so that form is refused.

### 1.10 Web

| affordance | status | note |
|---|---|---|
| `mini web --listen 127.0.0.1:PORT` read pages: doc, history, diff, `at/H`, object, board, room, search (`web.rs:625-660`) | exists (WEB step; JDV J24; byte-equality with `doc show --format html`) | loopback enforced in code: `web.rs:106-114`, `:200-212`; per-launch secret path |
| editor, new-document and Studio POST routes (`web.rs:599-607`) | authored (unit tests: editor 3, studio 2, create 0) | **contradicts the "read-only" help text and the step title** (`journey.sh:230`) |
| Studio Publish / Instantiate / Evolve | doc only: the buttons are disabled (`web/studio.rs:52`) | — |
| `enrollment-bootstrap` HTTP (`/mini/v1`, `/mini/v2`; `enrollment_bootstrap.rs:280-288`) | exists (unit tests) | rate limits at `:17-31`; no Caddy route |
| SPK browser (`spk-browser-proxy`, bound to 127.0.0.1) | journeyed on loopback only (`2026-10-02-spk-browser-tls`) | the node answers 503 (`serve-http-unavailable`) |
| public docuverse | none | HCLOUD-GAP #19 |

### 1.11 SPK grains (`spk-host grain …`, `native/spk-host/src/grain.rs:1376-1548`)

| verb | status | timings recorded |
|---|---|---|
| `install` (`--import` is restore) | journeyed (lane: grain-running, jspk1 44/44) | install 120 s |
| `route` (share) | journeyed (lane) | 249.5 s and 882.5 s (grain-running); 275–675 s (jspk1) |
| `start`, `prepare-resident` | journeyed (lane) | — |
| `stop` | journeyed (lane) | 412 s, 1492 s, 1638 s; jspk1 `stop-a` **3062 s (51 min)** |
| `supervise` (failed-START recovery, ops 206-209) | journeyed (jspk1 `s1-kill-a`) | 2529 s |
| `export`, `backup` (freeze) | journeyed (jspk1) | — |
| browser WebSocket co-editing (EtherCalc) | journeyed (loopback, older binaries) | WS open 13.6 s and 15.8 s; edits propagate in 0.04 s |

**What holds and what doesn't:**
- The sandbox floor holds 24/24 (`docs/evidence/2026-09-30-sandbox-floor`).
- `m6grain` is required but **known-red** (`required-rows`). On hbox the `setgroups` EPERM under
  AppArmor userns (`docs/PIPELINE-HBOX.md:186-191`).
- Not deployed.

**Trust fact for any public SPK:** the custodian signs Mini dispatches *as the participant* with the
participant's seed (`grain_route.rs:198-222`). Whoever holds the cookie can have the host sign any
Lean-admissible request as that member (spk-host review §Exec 4).

### 1.12 Hermes residents

See §3. In short: J14 (runner A, scripted provider) is lane evidence. The `hermes` row is required but
runs UNCONFIGURED on hbox because of userns (`PIPELINE-HBOX.md:184`). `HERMES-LIVE` is pending. Not
deployed.

### 1.13 Objective Bend authoring

**Can a member author and install a program today?** Yes, on scratch native worlds, and only through
the CLI.

Route A, native admission (row `objective`, not required):
1. Write a `.obend` file.
2. Publish it: `minidregg-host CONFIG objective-publication SPEC generic OUT` (`Host/Main.lean:6334-6346`),
   then store the payload with an ordinary document proposal (`workspace propose/submit`,
   `objective-native-acceptance.py:206-215`).
3. Invoke it with `mini objective-invoke` (`objective_invoke.rs:15-69`).
4. At admission the receiver re-runs the Lean front end and requires a byte-identical core. It also
   checks `tariffExact` on the declared envelope and the signer's compute budget
   (`Kernel/ObjectiveBendNativeAdmission.lean:423-445,553-562,610-678`).
5. The signer pays the tariff on the declared envelope, not on measured work.

Route B, the activity kernel: `mini activity --action submit` with `publish`, then `create`, `birth`,
`invoke` (Host ops 210-214). Seats work the same way through `mini seat` (ops 215-219). All of
`activity`, `seats`, `call`, `send`, `domain`, `upgrade`, `objectrecord`, `chargedfailure` and `bounty`
are **required rows**.

**What a program can produce:**
- Native Plans: `createDocument`, `createAtom` and stream `append`
  (`Compiler/ObjectiveBendNativePlanData.lean:55-89`).
- Call frames: `call`, `send` (with escrowed postage), `stop` and `cancel` (`Kernel/ObjectiveCall.lean:583-619`).
- Activities: only `await` reply/height (`Kernel/ObjectiveActivity.lean:1515-1540`).
- Seats: `reallocate`, `mint`, `exit` and `terminate`.

**What it cannot do:** I/O, network, digests, dynamic `get`, objects holding capabilities, or a storage
charge (`docs/OBJECTIVE-BEND.md:78,627-629,830`).

**What is missing as a product:** no shell verb, no SDK wrapper (`mini-sdk/src/consent.rs:7`: "227
Objective … not wrapped"), and no working Studio publish. **Nothing is deployed:** the 5688775a tree has
no objective, seat or Studio code.

---

## 2. Outside vs inside: who can talk to what

```
                     ┌────────────────────────── the box (one `mini` uid today) ─────────────────────────┐
 stranger ──ssh──X   │                                                                                     │
  (no roster line:   │   sshd Match User mini ──forced cmd──> mini shell ──unix──> mini serve ──stdio──> Host│
   refused by sshd)  │        (key on box, readable by     (verb grammar is     (64 conns; ONE    (Lean:    │
                     │         every member: FRIENDS:50)    the only fence)      Host thread)     admits)  │
 enrolled friend ────┼──ssh──────────────┘                                          ▲                       │
  (hosted)           │                                                            │ unix (same uid)       │
 friend w/ own key ──┼──ssh──> mini socket-proxy ──bytes──────────────────────────┤  [main only]          │
  (proxy, main only) │                                                            │                       │
 agent via SDK ──────┼──ssh:DEST (operator.rs) ─────────────────────────────────────┤  [library; no public  │
                     │                                                            │   consumer]           │
 Discord user ──HTTPS┼──> mini-discord (no app exists) ──> mini shell --line as rostered session [not on node]│
 resident (Hermes) ──┼── inside bwrap, --network none, only /run/mini-provider.sock; tools = `mini` children │
                     │   run by the controller under Hermes's own workspace key  [not on node]           │
 second Mini node ───┼── NNTP article via a fn node (loopback in every run) ──> selected-exchange receive    │
                     │                                                         [one machine only]        │
 browser ────────────┼── 127.0.0.1 only: mini web / spk-browser-proxy (ssh -L blocked: AllowTcpForwarding no)│
                     └─────────────────────────────────────────────────────────────────────────────────────┘
```

| who | how they authenticate | may read | may write | may spend | may delegate | where it stands |
|---|---|---|---|---|---|---|
| stranger | none | nothing (sshd refuses keys with no roster line; unauthenticated Host frames cost them nothing, HCLOUD-GAP §5) | nothing | nothing | nothing | the node |
| hosted friend | ssh key → forced command; the Mini key lives on the box | whatever their capabilities grant, via signed reads | through the law of each cell they hold a grant on | their provisioned account (sponsor-funded, synthetic Book) | narrower grants of what they hold (J3) | **deployed** |
| proxy friend | ssh key → byte proxy; signs locally (thin consent) | same | same | same | same | main only, unjourneyed for thin consent |
| agent (fleet / SDK) | Ed25519 or hybrid key, admitted by a sponsor's factory grant | topics it holds observe grants for | its own topic stream (fee-paying FleetTurns) | its own account, capped by the grant's `maxCost` (`FLEET-SURFACE.md:35-37`) | observe-only grants on its account | journeyed, not deployed |
| Discord user | Discord id → root-owned roster → session NAME | as that session | as that session (the key is on the box; Discord sees all content) | as that session | as that session | fake Discord only |
| resident | none of its own: the controller holds custody keys; the worker holds none | room roster, streams, documents its grants allow, and an operator allowlist | room posts, document append/link/review, typed propose | `ROOM-hermes` turns and tool/provider purses, never free-form | resources it holds, via typed propose | lane evidence; not deployed |
| second node | owner-signed packet; B enrolls A's public key and installs a release law | — | one admitted packet into B's inbox | — | — | journeyed on one box |
| browser | three static 256-bit tokens per route (SPK); per-launch secret path (`mini web`) | app pages; the docuverse | app requests, each one Lean-admitted, signed by the custodian *as the member* | via the dispatch purse | — | loopback only |

---

## 3. Inside Hermes: exactly what a resident can and cannot do

### There are three Hermes runtimes

| runtime | entry | provider path | sandbox | who pays | journey |
|---|---|---|---|---|---|
| A. room runner | `grain-runtime hermes-room step\|serve` (`grain-runtime/src/main.rs:18015`, `hermes_room.rs:576`) | direct HTTP to a **loopback** provider (`hermes_room.rs:191-198`); no gateway, no key broker | **none** | `ROOM-hermes` Book account, one turn per write (`hermes_room.rs:26-32`) | J14 PASS, 136 rows, 598.9 s, persvati, lane binaries, scripted provider (`docs/evidence/2026-10-01-p-hermes-room`) |
| B. AgentGrain ACP | `grain-runtime serve CONFIG` + real `hermes-acp` (`main.rs:14318,14752`) | gateway → mini-keys broker → curl | bwrap, `--network none` | parent, tool and provider purses | `2026-09-30-hermes-participant` (ACP fixture, no inference); hermes-keys; hermes-tariff |
| C. room resident | `grain-runtime hermes-room resident` (`room_resident.rs:271`) | B's machinery, `restrictTools` | as B | B's purses plus a room turn | **none** |

The runtime that has a room journey (A) is the one that bypasses the gateway, the purse and mini-keys.
Nothing says what serves A's loopback provider on a real node.

### Can and cannot

| capability | answer | enforced by |
|---|---|---|
| read room context | yes: `mini_room_ls`, `mini_room_status`, `mini_stream_tail`, offered only when `roomTools` is set | catalogue `mcp.rs:328-333`; each call is a signed read the Host judges (`resource_tools.rs:680-733`) |
| read documents | yes, under a grant: `mini_doc_show`, `mini_doc_context`; `mini_read_resource` reads only an operator allowlist | `resource_tools.rs:741-746`; `main.rs:12282-12300` |
| write documents | yes, under a grant: `mini_doc_append`, `_link`, `_review`. Each write validates, then reserves, pays, writes. Without a grant it is refused `no-grant` (J14 `edit-refusal.json`) | `room_task.rs:164-215`; Host law |
| post to the room | yes: `mini_say`, a paid turn; `bookRefused` becomes "out of budget" | `resource_tools.rs:1082-1114` |
| spend | only implicitly, through turn and tool purses; no free-form pay tool | AgentGrain law `Kernel/AgentGrain.lean:93-147`; Book admission |
| call a model | B/C: only through `/run/mini-provider.sock` with broker authorization at reserve. A: loopback only | `main.rs:384-409` (`--network none` required), `main.rs:9560-9612`; `credentials.rs:1030-1190` |
| summon other residents | **no**: no summon tool exists; `summon` is a founder-only shell verb | `mcp.rs:283-401`; `hermes.rs:578-585` |
| network | none for the provider worker; allowlisted `run` commands may choose `--network host` | `deploy/grain-host/bwrap:46-51,127-133` |
| filesystem | `/usr` and `/agent` read-only, `/workspace` read-write, `/tmp` tmpfs; mounting keys exits 77. MemoryMax 2G, TasksMax 128, 600 s default runtime. **No seccomp, no `--disable-userns`, no cap-drop on the Hermes worker** (SPK has all three) | `bwrap:55-71,93-99,116-122,159-161` |
| arbitrary Mini ops | **no**: a fixed catalogue; restricted mode lists and allows room tools only | `main.rs:12221-12227,14203-14214` |
| hold keys | the worker holds none; the controller holds per-task Mini keys by path; provider keys stay with `mini-keys` and are never returned | `mini-keys/src/lib.rs:1-25`; SO_PEERCRED roles `mini-keys/src/server/mod.rs:65-75` |

### Funding and caps

- **Who pays.** The provider table row decides, with no fallthrough (`deploy/hermes/README.md:9-27`):
  - `user`: the friend's own key; the purse pays `perOp`.
  - `pool`: the operator's sealed key; the purse pays `perOp` plus the metered charge.
  - `homelab`: no authorization header.
- **Room turns** are paid from `ROOM-hermes`, which the founder funds at summon (`hermes.rs:637`,
  default 100). `dismiss` refunds what is left (`hermes.rs:763-800`).
- **Purse rules in Lean:**
  - a reserve needs `reserved == 0` and a non-increasing budget; settle releases at most the hold
    (`Kernel/AgentGrain.lean:93-147`);
  - provider `reserveRule` and `settleRule` are at `Kernel/ProviderRoute.lean:186-207`.
- **Caps:**
  - per-call tokens, calls per UTC day per runner, and grant expiry height (`credentials.rs:1060-1192`);
  - `maxInputTokens` ≤ 131072, `maxOutputTokens` ≤ 8192, `maxIterations` ≤ 6 (grain-runtime README:132-189).
- **Where Rust decides, not Lean.** Rust chooses every price except provider metering (operator
  constants settled verbatim), the tool allowlist and provider row selection. Lean bounds this only
  through `charge ≤ reserved` (grain-runtime review §Exec 4).
- **A hole.** A crash after the send boundary but before any provider outcome has no settlement path,
  so the purse stays reserved (grain-runtime review §Exec 7).
- **Orphaned files.** `Kernel/ApplicationDispatchAgentPurse.lean` and `…AgentReserve.lean` are
  untracked, and nothing imports them.

### What the operator supplies and sees

- `/etc/mini/providers.json` (root-owned), `/etc/mini/credentials.key` (readable by mini-keys only),
  the sealed store `/var/lib/mini/credentials/…`, `controller.json`, and the resident and dispatch
  registrations (`deploy/hermes/README.md:65-145`; `deploy/hermes-dispatch/README.md:14-18`).
- The operator sees the broker audit log (digests only), the controller journal, the retained read
  views, and `reconcile … audited` commands.
- `mini-hermes.service` is installed and not enabled. Scoped workers require a unit name the shipped
  template does not use (grain-runtime review §Exec 14).

---

## 4. The datamodel on one page

```
Participant(SubjectId; KeyRecord{epoch, publicKey, nextKeyDigest}) ──holds──> Capability{id, holder, scope(18 verbs), notBefore..notAfter, ancestors}
      │ signs                                                                         │ checked by capabilityRefusal + the cell's Pred law
      ▼                                                                               ▼
Command{subject, nonce, targets[cell, cap, Payload]} ──execute──> IntentRecord ──> durable_log[h] (+KMAC tag, chain)
      │                                     └─ Turn.ofIntent ─> Turn ─ World.admit ─> World{cells, system}
      ▼                                                                         head=(h, logRoot) → Receipt{acceptedCount, worldRoot}
Cell{kind ∈ 18, store}: content{document→element→run/atom, link, mark, annotation, transclusion, tombstones}
  · stream head→entry (room / topic) · authority{caps, keys, revoked, parent} · resourceBook{accounts, assets, wells, floors, leases}
  · pay · clock · system{journal, head, spent, allowance} · objectiveActivity{record, slot, state, package, object, inbox} · seat · worldKind→worldInstance
```

| noun | Lean type | identity | who may change it | persists as |
|---|---|---|---|---|
| World | `Kernel/World.lean:265` | `(height, logRoot)`; root = compressed trie, cSHAKE `WORLD-ROOT/v2` (`Kernel/WorldRoot.lean:21-23`) | only `World.admit` (`World.lean:647`) | rebuilt on open; checkpoints hold the state |
| cell / resource | `World.lean:105`; `CellId := Nat` | a Nat; derived ids for stream entries (`Compiler/StreamCell.lean:189`) and activity/seat cells (`Kernel/SeatCell.lean:7`) | legs of admitted turns; retired only when empty (`World.lean:562-603`) | post bytes inside each log record |
| kind | 18 constructors, `Compiler/CanonicalCellRegistry.lean:88-127` | a 1-byte tag | fixed; who writes each kind is `Kind.lawClass` (`:212-245`) | in the cell bytes |
| member kind / instance / method | `Compiler/WorldKindDescriptor.lean:95`; `Kernel/WorldKindInstance.lean:20`; `Kernel/WorldKindMethods.lean:34` | layout digest; cell id; program digest | law-bearing; a method selects a program and grants nothing | worldKind / worldInstance cells |
| participant / key | `Theory/CredentialSigningKey.lean:32` | SubjectId + epoch | rotation only to the committed `nextKeyDigest` (`Theory/KeyPreRotation.lean:82-106`) | authority cell |
| capability | `Theory/TypedAuthorization.lean:872` | CapabilityId | delegate, revoke and renounce families; genesis grants expire at `height + lifetime` (`Host/Json.lean:2070`) | authority cell, with append-only `revoked` |
| law | `Pred/Core.lean:170`; `Compiler/PolicySourceCell.lean` | (PolicyId, revision) → content address | `policyInstall`, judged by the *old* law | policySource cell |
| Book | `Theory/CanonicalResourceKernel.lean:84` | AccountId, AssetId; a well's account id = its asset id | 7 operations (transfer, mint, burn, fee, lease, setFloor, sweep), each with `amount ≤ balance + floor` (`:151-163,278`); kernel-only | resourceBook cell |
| issuance cap / floor | `floors` (`:88`) | (account, asset) | genesis installs `issuanceCap` as the well floor (`Kernel/NativeHostGenesis.lean:112-115`) | Book |
| tariff / meter | three tariff types: `Kernel/PayTariff.lean:70`, `ObjectiveTariff.lean:24`, `ProviderMetering.lean:78`; 10 meter lanes (`World.lean:490`) | lane | the World refuses `chargeMismatch` / `overAllowance` (`World.lean:550-551`) | system allowance; pay cell |
| transaction / turn | `Command` `Kernel/ResourceTransaction.lean:114`; `Turn` `World.lean:371` | (subject, nonce) → txId | signature, then capability, then law | **IntentRecords, not Turns, are persisted** (`Kernel/TurnLog.lean:10-11`) |
| receipt / outcome | `Compiler/NativeHostCodec.lean:296,331` | (acceptedCount, worldRoot) | computed by the Host | the root after each entry is carried in its tag |
| document and parts | `Theory/Hyperdocument.lean:313-628` (atom, run, element, link, mark, annotation, transclusion snapshot/live, version event; tombstones as `tombstonedAt`) | digest identifiers in 12 domains (`:43-55`) | 15 content actions (`Kernel/ContentResource.lean:278-321`); marks by author or owner only | content cell, `hyperdocument-content/v7` |
| stream / room / topic | `Compiler/StreamCell.lean:67-117` | head = cell id; topic head = cSHAKE of the stream | stream: law-bearing; entries: kernel-only `[declaredResourceController, fleetTurn]` | stream + streamEntry cells; payload kept in the signed command |
| chat room | **not a Lean type**: a declared roster cell plus per-member streams (`native/resource-client/src/room_schema.rs:1-13`) | cell id | a founder law the Rust client authors (`shell.rs:172-187`) | declaredObject + stream cells |
| activity / object record / seat | `Kernel/ObjectiveActivity.lean:176`; `Kernel/ObjectRecord.lean:123`; `Kernel/Seat.lean:757` | protected coordinates | kernel-only `[objectiveActivity]`, `[seat]` | tags 19 and 20 |
| grain / session | `Kernel/ApplicationGrain.lean:36`, `AgentGrain.lean:25` | object id ("never a process id") | declared-object law plus receiver families | declaredObject cells |

**The Store.** SQLite, in `native/hyperdocument-link-sqlite-store/src/lib.rs`:
- `durable_seed` (`:560`): written once.
- `durable_log(height, record, tag)` (`:561`): one record per height.
- `durable_checkpoint` (`:562`): **every checkpoint is kept**, not "the latest two" as
  `docs/DURABLE-STORE.md:15` says.
- `durable_node` (`:559`): accumulator nodes.
- `archive_journal` (`:565`).
- Schema version `user_version=5`, while the doc says 4.

**What open replays.** The full open (`Compiler/DurableReceiverCore.lean:1207-1293`):
- reads every entry;
- re-hashes the whole chain;
- verifies every tag;
- replays only the records after the checkpoint.

A session runs that full open, then a light open that reads only from the checkpoint onward
(`Compiler/DurableServed.lean:847`, `Kernel/NativeHostSession.lean:155-158`). So cold open still grows
with the log through hashing, though not through re-admission. `store audit` re-admits all of history.

---

## 5. Performance: numbers against the bar

### The bar

- A signed write in ≤ 5 s and a cold reopen in ≤ 60 s, at 1000 accepted records (`docs/JOURNEY.md:70-72`).
- It is now judged per landing on `births` (64 creates), with 1000 in a nightly
  (`docs/PIPELINE-HBOX.md:136-162`).
- The row is `pending births when-green-at-main` (`scripts/pipeline/required-rows`). **It is not yet
  green at main, so it blocks nothing.**

### The numbers we have

| measurement | value | vs bar | source |
|---|---|---|---|
| growth: write p99 at 1000 records, hbox, 10-14 | **10 s** | **FAIL ×2** | `PIPELINE-HBOX.md:235` |
| growth at 1000, persvati (older build) | write 2.2 s, reopen 4.3 s | pass | via HCLOUD-GAP §6 (`NOW.md`) |
| J4 write / reopen on the workhorse, 09-30 | about 5 s / 7.8 s | at the bar / pass | HCLOUD-GAP §6 (deploy-1) |
| signed read at height 28, via ssh | 0.90–1.12 s | — | `docs/PERFORMANCE-REVIEW-2026-10-03.md:24` |
| fleet turn | about 2.1 s, about 15 Host requests; 0.186 → 0.083 turns/s as writers grow | — | `docs/FLEET-SURFACE.md:197-243` |
| room create / each shared-name resolve | **262 s** / about 6 s | far over | dregg-infra `origin/main:edge/mini/SHIP-RUNBOOK.md:20` (P7) |
| workroom template | 224–270 s | — | `README.md:80` |
| Hermes paid write | about 11 processes, 5 submits, about 8 reads, about 110 Host round trips | — | `PERFORMANCE-REVIEW-2026-10-03.md:294-301` |
| SPK share / STOP | 4–15 min / **7–51 min** | — | §1.11 |
| SPK WebSocket open | 13.6–15.8 s | — | `2026-10-02-spk-browser-tls` |
| waste ratio (instructions done / necessary), after STORE-ROOT | update 1,647×, birth 1,933×, current read 385×, past read 6,656×, cold open 11× | — | `WASTE-MODEL.md [deleted 3b2aa109]:23-38` |
| growth to 1000 records, wall time | 2,436–5,401 s | — | `PIPELINE-HBOX.md:149` |

**What landed after those numbers, all ancestors of main and none re-measured in the tree:**

| commit | change |
|---|---|
| `fc1e98a9` | Host image hashed once per inode |
| `1f9ccc5a` | client exchange reductions |
| `9309a9be`, `4eeb1b1f` | verifier and Store helpers serve in-process |
| `1f5920fe` | compressed world trie |
| `e0bbfb1d` | refresh validates only new records |
| `b7b007db`, `ba6f9379` | **resident consent provider**, W1: −92% client instructions in its stepbench |
| `d951d57a` | **kept-checkpoint past reads**, W3: 27.9 s → 15 ms at h=7,500 in its bench |
| `fa004154` | **perf-memo**, the resident Host holds package replays, W4 |
| `58b3ae50` | ByteArray codec cursor |
| `995c2bdb` | CellTable / durable engine, merged as WIP |

So the honest current state: the largest named wastes were attacked in the week of 10-14 to 10-17,
**and there is no post-landing births, growth or waste-model number for main in the tree**.

### Known remaining causes, as the docs and code name them

1. **One Host thread per world.** `mini serve` serialises every Host exchange (`transport.rs:1752`). The
   HP-DESIGN resident batched loop (`docs/HP-DESIGN.md:17-23`) is not built: `Host.Resident [not in tree]` does
   not exist, and `batchTurnsMax` appears only in `Kernel/Bounds.lean`. Concurrency shows up as queueing
   and as stale-root re-plans (up to 5, `main.rs` usage).
2. **Global staleness.** Preconditions are checked against a world-level root, so concurrent writers
   invalidate each other (`PERFORMANCE-REVIEW:318-330`). Fleet throughput halves from K=1 to K>1.
3. **A Lean process per `mini` invocation for its codec child.** It costs 0.38 G instructions, about 68%
   of a current read (`WASTE-MODEL.md:119`, W5). Every ssh command is one `mini` process
   (`PERFORMANCE-REVIEW:255`).
4. **Unattributed server submit.** Op 2 p50 586 ms, never profiled, because the Host runs from a memfd
   (`WASTE-MODEL.md:116`, W2).
5. **Bytes as `List UInt8`.** 360 instructions/byte to decode against 8 needed (W7). The list-shaped
   image is still in `Kernel/DurableReceiver.lean:179,185` (`accepted ++ [record]`, `eraseDups`).
   Whether the hot path still reaches it after CellTable is unverified.
6. **Every app HTTP request is a full Mini transaction plus a history append** (`PERFORMANCE-REVIEW:42-124`).
   The decisive remedy is a per-session HTTP lease (1c), which is not started.
7. **Hermes spawns `mini shell` per tool call** and polls `room ls --since 0`, which grows with history
   (`PERFORMANCE-REVIEW:288-316`).
8. **Room-scoped verbs multiply exchanges.** About 19 exchanges for `room new` and about 70 for a shared
   `read` before `1f9ccc5a`. The 262 s room create is from r2; I found no newer number.
9. **Week scale is unmeasured.** The clock alone adds about 1440 heights a day, so about 10k records a
   week (HCLOUD-GAP §7 #7). Nothing past 1000 records is measured. Cold-open whole-state hashing
   breaks a 1 s budget at about 85 MB of state (`WASTE-MODEL.md:210-213`).

### Is there more performance work to do now? Yes, ranked by what it buys a public demo

| # | work | buys | size |
|---|---|---|---|
| 1 | **Measure main.** Run `births` at N=64 and 1000, `growth`, and `workload.sh` under `perf stat --no-scale` on a quiet box. Flip `births` to required when green | tells us whether batch 1–3 already meets the bar; without it every claim here is from before the fixes | S (hours of hbox wall time) |
| 2 | **Room-scoped latency** (P7): re-measure `room new` / `resolve` on main, then cut exchanges | rooms and chat are the most "social" shell verbs; at 262 s they cannot be shown | S to measure; M to fix |
| 3 | **Week soak**: a 10k-record run, or slow the clock to 5 minutes | a public week doesn't fall over on day 3; also answers the consent-replay-per-signing question at that size | M |
| 4 | **Codec in-process or resident** (W5; HP-DESIGN §1 `serveCodec`) | about 2/3 off every read, fewer Lean starts per ssh command | M (Lean + Rust) |
| 5 | **Profile op 2** from a file-backed Host (W2) | names the largest unattributed term in every write | S |
| 6 | **Footprint-scoped staleness** (Lean) | concurrent strangers stop forcing each other to re-plan | M–L |
| 7 | **Resident batched admission loop** (HP-DESIGN §1) | throughput past one-turn-at-a-time; the end state | L |
| 8 | **SPK: HTTP session leases (1c); STOP/START cost** | needed before any public grain; no gain for shapes A and B | L |
| 9 | **Hermes: in-process tools, `--since LAST`, a composite paid-tool turn** | Hermes cost per tool drops from about 110 round trips | M; only if Hermes ships |

For shape A, items 1–3 are the gate, and 4–5 are the cheap structural wins.

---

## 6. What we would be shipping

**Shape A: ssh shell only.**
- A stranger gets an ssh account after ember adds their key by hand.
- They land in `mini shell` on a devnet that gets re-genesised.
- They can:
  - make a key;
  - create shared documents and boards;
  - append, edit and link, and follow backlinks;
  - delegate narrower rights to another member;
  - install a law and watch it refuse even its own owner;
  - ask why something was refused;
  - lose a reply and retry it exactly, without a second effect.
- Every one of those actions is a signed transaction that the Lean kernel admits and a durable log
  keeps.
- Their signing key sits on the box, readable by other members until split tenancy runs.
- Writes take about 1–5 s each.
- That is what passed J0–J8 and J12 on the Hetzner box itself (10-01). It is the product we can show
  honestly.

**Shape B: plus a web docuverse.** Main has a real hypertext docuverse: document pages, history, diffs,
reads at an older height, rooms, search, and a Studio for composing Objective Bend modules. A stranger
would get it only once a public read gateway exists, because today it binds 127.0.0.1 behind a
per-launch secret and the box blocks port forwarding. The editor and Studio write paths have never run
in a journey. Shipping B means building the gateway (HCLOUD-GAP #19), not switching something on.

**Shape C: plus one SPK grain.**
- The stranger would open a Sandstorm-style app (EtherCalc is the only one shown co-editing) in a
  browser.
- Each request is Lean-admitted and signed by the custodian as them.
- Behind it: a bwrap and seccomp sandbox that held 24/24.
- Today that has run only on loopback with older binaries, behind PQ-only TLS.
- Lifecycle operations take minutes (STOP up to 51), the `m6grain` row is known-red, and the browser
  path is not in a journey.
- It is a research demo, not a stranger-proof product.

**Ten verbs for a shape-A FRIENDS.md.** Every one of these is journeyed and in main:
1. `keygen`
2. `whoami`
3. `doc` (new / show / append / edit / link / backlinks / history / diff)
4. `board`
5. `create`
6. `delegate`
7. `law` (one-line laws, `law check`, `law show`)
8. `why` (plus `can` and `inspect`)
9. `history` (plus `retry` and `lookup`)
10. `export` / `import`

The node has nine of these today (all but `why`), some in reduced form. `why`, `can`, the richer `doc` and the one-line laws
need a candidate cut from main. If the room-latency measurement (§5 #2) comes back interactive, add
`room` and `say`/`tail` as an eleventh and twelfth.

---

## 7. Gaps and twins noticed

**Twins (two or more ways to do one thing):**
- **Signing paths:** `mini-sdk` `flow::Client` vs resource-client `submit_once` (`flow.rs:2` says so
  itself). The consent opcode lists have drifted: 29 in the SDK (`consent.rs:18-21`) vs 31 in the client
  (`client_consent.rs:1093-1094`). Nine private `fn pair` copies.
- **Messaging:** fleet topics, chat rooms (per-member streams), `mini channel` (relay cells outside
  admission), the activity inbox, and the Discord mirror.
- **Spending:** `pay` (Solana → Book), `credit` (Book → room till), `pay refill` (Book → AgentGrain
  purse; JPAY6 known-red), `agent-payer`, `job fund`, `fleet transfer`. The one shell verb `pay` splits
  across two commands (`shell.rs:1761-1851`).
- **Newcomer routes, seven of them:** `join`, `join --solana`, `join v2`, `pay-claim`,
  `session-enrollment`, `fleet join`, `enroll`.
- **Hermes:** three runtimes (§3).
- **Objective install:** route A (document atoms + `objective-invoke`) vs route B (`activity publish`).
  Only B's rows are required.
- **Member programming:** Nock world kinds (`WORLD-PROGRAMMER.md`, the `jworld-*` hooks, not in STEPS)
  vs Objective Bend.
- **Turn representations:** `World.Turn`, the persisted `IntentRecord`, `Kernel/Turn.lean`, and the
  Gen-1 `Kernel/State.lean`. HP-DESIGN says the log is Turns; the code persists IntentRecords.
- **Tariffs and allowlists:** three tariff types. Three hand-written copies of Lean's HTTP header
  allowlist in spk-host (spk-host review §Exec 11). `grain-host/host-frontend.rs` hard-codes its own
  public-operation allowlist (deploy review §Exec 10).
- **Hand-written laws:** `document_law`, `room_law` and `board_law` in `shell.rs:147-187,709-719`, with
  no Lean emitter.

**Surfaces with no journey:**
- Studio and the `mini web` write paths.
- `flow::Client`, all of mini-sdk-ts, and the wasm32 build.
- Room resident C, the hermes-dispatch pump, `inference-scheduler`.
- The fn consumer worker family, `export-evidence`/`verify-evidence`, the agent-reserve verbs, and
  `fleet --action incoming`.
- `hermes status/cancel`, `adopt-next-key`, `app`, `home`, the `key` shell verb.
- Thin-consent proxy mode (JP2 is not required).
- `enrollment-bootstrap` HTTP.
- SPK M6 (`journey.d/m6.sh` is UNBUILT, HCLOUD-GAP §3).

**Journeyed surfaces the node doesn't have:** rooms, chat, key rotation, proxy over the SDK (`sshe2e`),
fleet (`m8`, `fleetsign`), the selected exchange, `jpay/JPAY1-4`, the activity, seats, call, send and
upgrade rows, J14, J15 and J17.

**Docs contradicted by code:**

| doc | says | code |
|---|---|---|
| `INTERFACES.md:203-208` | serial serve; a process per Store/verifier call | concurrent connections, serial Host thread; helpers in-process |
| `deploy/shell/README.md:75-84` and HCLOUD-GAP §3 | proxy signing refused | thin consent exists |
| `FRIENDS.md` / `OPERATOR.md` | FRIENDS: a `lock` verb, chat never ran. OPERATOR: the node's client has `provision` | no `lock` verb; J14 ran chat; 5688775a has no `provision` verb |
| `docs/DURABLE-STORE.md:15` | schema 4, two checkpoints kept | schema 5, all checkpoints kept |
| `docs/OBJECTIVE-BEND-EVENTS.md:145,318` | 11 turns, no upgrade turn | 15 turns, `adopt`/`migrate` exist |
| `docs/STUDIO-SOURCE-WORKSPACE.md:39-46` | Gen-1 `partial-input.v1` | v1 refused (`workspace/studio.rs:12-16`) |
| `mini web` help, WEB step title | read-only | has POST routes |
| `docs/HOSTED-PROVIDER-CUSTODY.md:42-49` | `--network host` | `--network none` required |

Also: `deploy/spk-host/README.md` describes a root broker, while `USER-TENANCY.md` refuses one.

**Hidden commands:** 12 live commands are missing from `mini --help`, `activity` and `seat` among them.

**A live bypass:** PayObservation and PayEnrol advance the clock cell without judging the clock law
(`CanonicalCellRegistry.lean:110-112`, cv `01a1087d-8a58`).

---

## 8. Agreement with the sibling reviews (`docs/review/2026-10-26-native-crates/`)

**Where they agree with me:**
- **resource-client A** finds 127 commands, about 45 with no caller, the shell authoring laws in Rust,
  and Studio reachable only on loopback.
- **spk-host A** says the HTTP entrance is not internet-facing and every app request is Lean-gated, and
  adds the custodian-signs-as-member fact I used in §1.11.
- **grain-runtime A** has the same Hermes picture: Rust decides prices and tools; a crash
  before outcome leaves a reserved purse with no settlement; Hermes is executed but not deployed.
- **deploy** says the single shared `mini` uid is the biggest security fact, and that a demo needs
  about 57 deploy files.

**Where they add to or sharpen mine:**
- resource-client A §Exec 4: **every 255 reply is shown to the user as a "refusal"**, including
  `uncertain` and "host session reopening". That invites a second operation after an undecided one. This
  is a UX trap for shape A worth fixing before strangers arrive.
- grain-runtime A §Exec 9 says "no seccomp anywhere" for Hermes workers. I agree for Hermes; SPK grains
  do have seccomp (`native/spk-host/src/sandbox.rs:434-446`).

I found no outright disagreements.

---

## 9. What I could not verify

- **The node's state after 2026-10-03** (no ssh, per the brief). Every "deployed" here is as of that read.
- **Any standing-run result after main `cfb68bf9` (10-16).** That includes the batch-3 state of every
  "journeyed (required row)": the results live on hbox.
- **Current-main performance.** No births, growth or waste-model run after the 10-15 to 10-17 perf
  landings is in the tree. Neither is runtime RSS, or room-create latency newer than r2's 262 s.
- **Whether the list-shaped `Image.accepted` / `cellIds` path is still hot** after CellTable (`995c2bdb`,
  merged as WIP).
- **Whether `home`, `job`, `credit` and the other in-shell verbs work over `--remote`.** In-shell verbs
  skip the REMOTE_COMMANDS gate (`shell.rs:2580`); not exercised.
- **The wasm32 build and the TS SDK tests on Linux.** Only commit messages from a Mac exist.
- **Thin-consent proxy signing end to end.** The code and hook exist; no recorded run.
- **Whether the binary on the node matches the 5688775a source.** I read that tree's VERBS table (25
  verbs, no `provision`), not the running binary.
- **Discord, Hermes with a real provider, and SPK in a public browser.** None was ever recorded against
  real external services.
