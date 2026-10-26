# The demo prefix: from main `d6e6fbe0` to a public Mini on Hetzner, with every surface on

Present-state plan, written 2026-10-26 by the orchestrating session from the review corpus under
`docs/review/2026-10-26-*` (every number below has a cited source there). This file is rewritten
whole when the state changes; it is not a diary. Its companion for the box is
`~/dev/dregg-infra` (`main` and branch `demo-vm`; `MERGE-2026-10-26.md` there).

## 0. The sentence

> The Hetzner demo runs **minidregg**, repaired and consolidated in place from a written triage
> (rescue, repair, delete, in that order), shipped early to a fresh confined VM in its own hcloud
> project and redeployed every few days with re-genesis allowed; nanodregg stays the object of
> study whose laws are the target shape of the consolidation, not a second product.

Status: the orchestrator's default, stated to ember on 2026-10-26 evening and not contradicted.
The README (Oct 23), ember's Oct 19 words and this session agree; the Oct 22 nano program
("do not move the program to mini") is about nano's *program*, not the demo. If ember rules
otherwise, this file is rewritten.

## 1. The bar

A stranger with the URL `demo.dregg.online` exercises the system for a week without the operator
babysitting. Every surface is **on** (ember, 2026-10-26: "it's important that we have *everything*
up"): the ssh hosted shell, the web docuverse, one SPK grain (EtherCalc at
`calc.demo.dregg.online`), Hermes residents in rooms, PAY (pay-to-enrol on Solana mainnet),
Discord, the fleet surface, fn as transport, and the veri7vn oracle appliance that a codex
session is packaging as an SPK app right now (`native/oracle-appliance`, `deploy/oracle/`).

The floor underneath, fixed on 2026-09-29 and never met: two friends plus one hosted Hermes,
joined, over ssh, at 1000 records with write p99 ≤ 5 s and cold reopen ≤ 60 s.

Honest sizing from the lanes: "everything in week 1" is about **two weeks of lane work** across
six to eight parallel lanes, with four long poles (§3).

## 2. Where we stand

- **One public node exists**: `dregg-workhorse` (cx33, fsn1) serves candidate `5688775a` of
  Sep 30 over ssh in a 3 GiB slice shared with Bread, DelveTalk and headscale. J0–J8 and J12
  passed on it over the internet on Oct 1. No second person has ever used it. It is torn down
  once the new box is up (ember's permission, 2026-10-26).
- **main `a0db11f8` → `d6e6fbe0`** carries the Oct 14–17 integrator batches plus today's
  housekeeping and the review corpus. Known-red on main: `Fixtures.NativeAcceptedFixture`
  (fixture-only), required rows `jpay/JPAY6`, `m6grain`, `m7`; pending rows `births`,
  `HERMES-LIVE`, `jcertify`. The hbox standing run of Oct 16 was PASS 136 / FAIL 2 /
  UNCONFIGURED 6 / UNJUDGED 3.
- **A candidate of main `a0db11f8` was built on hbox today**
  (`docs/review/2026-10-26-deploy/HBOX-CANDIDATE-a0db11f8.md`): 35 minutes from fetch to
  candidate off the warm base (host C-compile + link 454 s; the cold Lean time is still
  unmeasured because every module replayed). Journey rows: PASS 136 / FAIL 2 / UNCONFIGURED 6 /
  UNJUDGED 3, the same shape as main's Oct 16 baseline (JPAY6 fails on a 70-byte socket-path
  row in the journey driver; m6grain needs a sudoers rule). **`jdeploy3` FAILS** twice over:
  (1) growth is over the write bar at every level on a loaded box (max 6.1 s at 10 records;
  p99 12.3 s, max 57.3 s at 1000; reopen 11.8 s is fine); (2) the composed scenario never
  started because dregg-infra's `candidate_manifest()` (`edge/mini/lib.sh`) rewrites the
  manifest without the `minidregg-candidate-manifest-v2` type that Mini's `run.sh` has
  required since `295cab11` (Oct 8). `ship.sh:185` uses the same function, so **no v2
  candidate can ship until dregg-infra is fixed**.
- **dregg-infra is reconciled locally** (merge `7260dee`, roster landmine fix `4fd80fa`,
  `demo-vm` branch with the confined box: `edge/demo/`, `edge/tofu-demo/`, merged with main at
  `bfa0972`). Nothing pushed, nothing applied. The tail-bound certifier branch
  `edge/mini-certify` is not merged (six design conflicts with split tenancy).
- **The tree**: 1.69M tracked lines against a ~290K founding budget. Rust ≈ 290K in `native/` +
  `prover/`. Lean ≈ 590K, of which the host executable's closure is 330K / 784 modules. Very
  little Lean is dead; the mass is version strata, twins, and ~110K lines of proof-system
  research that no executable depends on.

## 3. The prefix

Phases are serial; lanes inside a phase run in parallel. Each lane is a **repair lane**: it
rescues or repairs first and ends its merge with its deletions. Sizes: S < 1 day, M 1–3 days,
L > 3 days. Sources: `SYNTHESIS.md` §F (Rust), `LEAN-TRIAGE.md` §3–§4 (Lean),
`WEB-SPK-PUBLIC.md` §7 (surfaces), `HCLOUD-GAP.md` §7 (box, gap numbers `#n`),
`RUST-TRIAGE.md` §2–§4 (deletes and the five repairs).

### Phase 0: unblock (ember + one integrator, days 1–2, serial)

| # | what | who | size |
|---|---|---|---|
| 0.1 | Rulings in §5 taken (defaults apply where silent) | ember | — |
| 0.2 | Push `dregg-infra` main and `demo-vm` to the hbox mirror and the anchor (both fast-forward; fetch both first) | integrator | S |
| 0.3 | hcloud project `dreggnet-demo` + token in 1Password; DNS `demo.dregg.online`, `calc.demo.dregg.online`; `edge/demo/friends/ember.pub`; the external accounts: Discord application, OpenRouter pool key **with a spend limit**, two Solana mainnet RPC endpoints, the enrolment address (#2, #18, #21, PAY) | ember | S |
| 0.4 | Genesis for the new box: `issuanceCap`, `clock.genesisNow`/`maxStepSeconds`, `lifetime` raised from 10,000 records (about 7 days of minute ticks) (#5, #7); sponsor key custody choice (#16) | integrator | S |
| 0.5 | dregg-infra: `candidate_manifest()` emits the v2 manifest type (and `ship.sh` with it); re-run `jdeploy3` on the existing candidate so the composed phases are actually judged | integrator | S |
| 0.6 | hbox: the sudoers rule for `install-user-world` admits the candidate lane's tree so m6grain is exercised; stop the three orphaned journey-world processes in `run-u59970.scope` (no PID file: ember's call) | ember / integrator | S |

### Phase 1: code lanes (days 2–9, parallel; one Host rebuild at the end)

| lane | rescue / repair | deletions at merge | size |
|---|---|---|---|
| **L1 Lean critical path** (forces the Host rebuild; the long pole) | (a) JPAY6 consent allowlist (`Host/ClientConsentCore.lean`); (b) a **no-effect class on `Outcome`** and the Host answering every proven no-append outcome with the positive `NO_RECORD` frame (`Host/Main.lean:2616-2666`); (c) `ProviderUsage` admits a settle for a complete non-200 metered reply so one 429 cannot brick a pool-route grain (`Host/ProviderUsage.lean:267-268`); (d) op 35 lookup live; (e) consent op list and response-marker table emitted from the registry; (f) the 33 vacuous `∨ Collision` statements rewritten on the `RowsCollision` pattern (28 are in the host closure) | the three V1/V2 lifecycle submit receivers `Host/Main.lean` imports but never calls (383 lines); the census-only V1 lifecycle modules (347); the orphan battery files nothing imports (3,188) | M–L |
| **L2 custody (`mini`)** ★ | `mini_sdk::flow::Client` becomes the ONE signing path the CLI reuses (it has no caller today and has drifted: stdio vs codec, 29 vs 31 consent ops, `.charged` read as confirmed); the four `255`-as-refusal sites classify by decoded outcome type; `credit pay/topup/refund`, `well *`, `activity submit`, `workspace submit` refuse a rerun without a record; `fleet-sign` stops treating `uncertain` as never-admitted; chat's outer retry loop removed | the ~15 hand-rolled custody machines, one module at a time; traffic stacks 1 and 3 (3,774; stack 2 kept as the research line); `session_reenroll.rs` (1,150); `scheduled_transport.rs`; Studio (~1,233, ruling D7); `join_solana` v1 (~940); unreached arms | M then S×n |
| **L3 fence + sandbox (spk-host)** ★ | per-signed-call dispatch fence instead of per-generation (today one `contention` locks every member out for 19–51 min); STOP gets op 23/27 lookup and a deadline; `broker_home::render` renders real hardening (today it returns ""); seccomp gaps closed (AIO, `vmsplice`, memory-policy, fd limit, writable `/dev`); the sandbox floor audit re-pointed at the production spawn path and run; per-request dispatch directories bounded; the route socket accepts the edge's group (W6). **Coordinate with the codex o7vn session editing `broker.rs`, `materialize.rs`, `spk-ingest` right now.** | `spk-hostd`/`endpoint.rs`/`serve_resident` (the "503 by design" that is dead code), the five callerless harness binaries (2,168), `claim_descriptor.rs`, `setid_bound.rs`, agent API v1 after hoisting shared lines, 34 stale `allow(dead_code)` headers | M + S + S–M |
| **L4 rooms + Hermes (grain-runtime)** ★ | the Hermes units can open (install-controller renders all three `MINI_GRAIN_*` variables and writes the registration; `mini-hermes.service` retired); a first-class `grain create`; typed per-prompt outcome record; length-prefixed admin protocol (the 16 KiB read bound wedge); concierge keyed on `transactionId` with refund as exact lookup; subprocess deadlines; run the real room resident once (J14 today runs the legacy runner); run the `--network none` + `grain-provider-bridge` topology once | legacy `hermes-room` runner, `resident_outcomes`, `session_failure`, `legacy_custody_audit`, dispatch v1 (a money hole), `config_migration` + `controller_write_scopes` (2,079, no driver, on the hot path) | M then S (~3,100) |
| **L5 door + PAY + Discord** ★ | the self-serve join door: an unprivileged `/join` form that queues, a root processor that creates the account, hosted key and `authorized_keys` line, enrols with fixed funding and issues the Discord link code (G1/G2, #9, #10); pay-to-enrol lands on a hosted account (today a proxy account that cannot sign); `journalFloor` from the signed tariff; Discord roster via `/mini link CODE`; the mirror packaged with a unit and its non-2xx wedge fixed; custody retention (#17) | `join_solana` v1 bootstrap routes; discord dead code | M–L + S + M |
| **L6 keys (mini-keys)** | `singleAccount` shape for week 1; parse the forwarded body against the grant (today caps are checked against the controller's claims); pin the uid answering op 144; refuse unauditable operations; `credentials.rs` moves in from grain-runtime | `verify-mldsa` and the `fips204` dependency (names a Lean declaration that does not exist) | S×4 |
| **L7 web (resource-client)** | `mini web --read-only` and `--render-static` under uid `mini-pubread` with no network, served by Caddy (W1–W3); the `public` reader subject and its snapshot timer; history/diff escapes rendered one-line; a malformed shared-name link renders invalid instead of breaking every reader; a lower per-op Host budget or per-uid share | `web/surface.rs`, `world_surface.rs`; the `include_str!` templates move into the crate | S×3 |
| **L8 fn + fleet + selected** | one unit and one journey row for the fn consumer worker; fn-r route; one NNTP repost rule; `fleet_sign` receipts are Lean's four fields | the fn-e path; `fn_namespace`/`fn_frontier` twins (1,462) after the fn protocol rewrite; `publisher.rs` (552) | M |
| **L9 build + deploy + gate** | every crate a workspace member or an explicit `exclude` with a reason, gated (today `prover`, `hyperdocument-link-store`, `bend-ir2-proof` are unbuildable and their tests silently stopped); `lib.sh` optional roles optional; test fixtures out of `RUST_ROLES`; `hermes-test-provider` leaves the candidate; the journey split into a demo journey inside the 3 h gate and a nightly kernel journey; `m6.sh` as a thin wrapper over `two-world-journey.sh` plus an edge phase (D9) | GitWeb root chain (601, calls a 6-argument contract with 4), `probe_control.rs` (does not compile), `host-frontend.rs` (744, a hand op allowlist), MUD `sim.py` (433, a hand twin of `Pred.eval`), `package.py --capsule` (always dies), stray `Cargo.lock`s, the bend pair (874, ruling Q4) | M |
| **L11 performance (the growth bar)** | measure the write path on a quiet box first (today's G ran at load 7–16); then the named costs: consent replay per signing, the serial Host thread, the 4–5 Host processes per request, room create 262 s; the bar is write p99 ≤ 5 s and reopen ≤ 60 s at 1000 records, and `jdeploy3` refuses without it, so this is Phase 1 work, not Phase 3 | — | M |
| **L10 docs** | present-state rewrite of the 25 documents the code contradicts (`RUST-TRIAGE.md` §2.3), the README honest-state table, FRIENDS.md for the shipped candidate, OPERATOR.md, `DURABLE-STORE.md`, the two SPK contracts, this file's companion HANDOFF.md | the `docs/evidence` dirs that no gate reads are left alone until the research move (§3 Phase 3) | S–M |

Phase 1 deletes ~24,400 Rust lines and ~3,967 Lean lines as the last step of its merges
(`RUST-TRIAGE.md` §2.1, `LEAN-TRIAGE.md` §6) and adds perhaps 3–4K of new Rust (door, outcome
record, per-call fence, mirror fix) and ~1K of Lean.

### Phase 2: ship (days 7–12, serial box steps then parallel lanes)

1. Candidate from the post-Phase-1 tip on hbox (`lane-build.sh` under `swarm-build`, `/tank`),
   packaged by `package.py`; `jdeploy3` on it (every phase must be green now that every surface
   is on: documents, apps, connector, residents, restart, rooms, churn) (#3, #4).
2. The box: `tofu apply` in `edge/tofu-demo` (cx43, Debian 13, fsn1), `install-demo.sh`, the
   split-tenancy scratch run (`jsplit-tenancy.sh`) first on that box (#8), the operator-socket
   topology (#12), the certifier (rebase `edge/mini-certify` onto split tenancy; writes stop after
   256 uncertified heights ≈ 4 h without it) (#6), backups to the locked bucket, alerts to ember
   (#13, #14), sshd and nftables limits (#11), one reboot rehearsal.
3. `ship.sh --regenesis`; roster = `edge/demo/friends`; the join page says "everything on this
   box is world-readable" (D8, #15); Caddy routes `/`, `/join`, `/interactions`, `/mini/v1/*`,
   `calc.`; EtherCalc behind the edge with one real browser run, then `spk-browser-proxy` deleted
   (D2, W9); Hermes on pool + homelab rows only after L1(c) is in the candidate (HERMES-LIVE);
   Discord endpoint registered; one real mainnet payment by ember; the fn consumer worker up.
4. Tear down the workhorse's Mini slice and retire its Store (nothing depends on it).
5. **Redeploy every few days from then on** (one owner, re-genesis allowed, gate green per
   candidate), the way DelveTalk shipped 17 editions in one week.

### Phase 3: coherence (weeks 2–4, with strangers on the box)

| # | what | size |
|---|---|---|
| C1 | **`World.admit` in gate mode on the receive path** (run it, refuse on error, as `Host/WorldSim.lean` already composes): the theorems become about the function the writer runs. ~300–800 Lean lines; the per-session World cost measured first. Closes the HP-3 / RECEIVER step 8 plans that never landed | M–L |
| C2 | **The research move**: 140 Selvage modules outside the host plus their importers (109,639 lines; no executable or qualification library depends on them) to `zkml-research`; `private-backend` (26,139 lines; no service reaches it) to `degg-research`; census-only Assurance decided module by module (up to 35,312). Keep `scripts/check-import-boundary.sh` and `check-prover-glue.sh` green; split `Compiler/Tower256CshakeMerkleController` so the host needs no Selvage, as `Deployed.lean` already claims | M |
| C3 | **Strata consolidation at a re-genesis**: `Kernel.ApplicationLifecycle` 66 → one stratum (7,295 lines of versions alive only for old-record lookups), `PayEnrol` V1 (~3K), dispatch v2/v3 in grain-runtime; old shapes refuse to load, state carries by re-genesis (nanodregg law 1) | M–L |
| C4 | **Emit the laws and tables from Lean**: shell document/room/board laws, default account/room policies replacing permit-all, genesis, the verb-tag table, per-op bounds, the AgentGrain status enum, `validApiPrefix`/`requestSafeFor` as `@[export]`s; delete each Rust twin as its emitter lands | M + S×n |
| C5 | **One wire**: generated op constants at all 159 literal sites, consent namespace 220–233 registered, envelope v1 refused after the three senders and nine scripts migrate, the agent API wire in `spk-rpc` | M |
| C6 | **The grain economy in Lean**: a grain work tariff, the provider route bound to an operator table digest, paid-slot room admission carrying the ledger `transactionId`; delete the Rust concierge decision and room-turn sequencing | L + M |
| C7 | Never-admissible witness + settle-by-anchor (Lean); private rooms owned by Lean (`Kernel/RoomRelease*` wired); receipts with inclusion (op 151); the two choreographies (grain purse lifecycle, SPK lifecycle) as Lean data with projected Rust skeletons | L each |
| C8 | Performance beyond the bar (L11 meets it): a 10k-record week-scale soak, the in-process codec (~68% of a read), the serial Host submit profile, SPK STOP's five re-hashes of the 159 MB image | M each |

## 4. Rules for the prefix (from `HISTORY.md` §8, binding on every lane brief)

1. Rescue, repair, delete, in that order; "delete the twin" keeps and repairs the better one.
2. Every lane's deletions are named in its brief before it starts; the first deletion commit
   lands within a day; a size ratchet refuses growth of the host closure.
3. Allow a regressing train with every red named. Write no statement packets for code being
   removed. Only the top-level theorem of a lane needs to be non-vacuous.
4. Ship on the day planned even if rows are red; the gate hardens as surfaces turn on, never
   ahead of them.
5. One root per project. fn and nano run from their own sessions and cwds. Keep implementation
   with the agent that holds the context; resume, do not respawn.
6. Every ruling put to ember carries a default that applies while she is away.
7. No censuses, ledgers or gate bookkeeping unless they unblock the ship.
8. `swarm-build` on hbox, `/tank` only; named-file commits; no `git stash`; no pattern kills.

## 5. Rulings and their defaults

Taken 2026-10-26: every surface on in week 1; hcloud project not account; `demo.dregg.online`;
security kernels rebooted as soon as available; port 22 for the operator; clock tick per minute;
EtherCalc on its own origin; Caddy terminates TLS with hybrid X25519MLKEM768 + X25519 fallback;
Studio out until a producer exists; hosted signers can read the whole demo Store, said on the
join page; `m6.sh` wraps `two-world-journey.sh`; the roster landmine fixed.

Open, with the default that applies if ember is silent:

| # | question | default |
|---|---|---|
| R1 | §0's sentence: the demo runs minidregg | yes |
| R2 | DelveTalk candidate commit `4d866e4` on dregg-infra main, or a side branch | side branch |
| R3 | Push dregg-infra main + `demo-vm` to hbox mirror and anchor now | yes, after fetching both |
| R4 | Hermes week 1: pool route after L1(c) lands, or BYOK-only until then | pool after L1(c); BYOK rows accepted meanwhile |
| R5 | `private-backend` → `degg-research` (26K lines leave this tree) | yes, Phase 3 |
| R6 | Selvage research → `zkml-research` (110K lines leave this tree) | yes, Phase 3 |
| R7 | Agent API: keep v3 (never run) and delete v1, or keep v2 (ran 09-27) | v3 parked behind a feature; v1 deleted |
| R8 | Lifecycle v4 retry lane (2,255 lines, never run): must a failed first CREATE be recoverable without a new birth | keep |
| R9 | Traffic privacy: keep stack 2 only | yes |
| R10 | Delete the bend pair (second prover stack) and retire `runtime.c` | yes / retire |
| R11 | Replace permit-all defaults with a Lean-emitted default before strangers enrol | yes |
| R12 | Grain prices into Lean (C6) or labelled operator policy with a Lean ceiling | Lean, after the demo |
| R13 | Every crate a workspace member or explicit `exclude`, gated | yes |
| R14 | README honest-state table rewritten whole now | yes (L10) |
| R15 | The oracle appliance (veri7vn) ships in the demo as an SPK app on the same grain path | yes; its codex lane coordinates with L3 |

## 6. What this file is not

It is not a claim that any of it has run. Phase 0's candidate report, Phase 2's gate verdict and
the live node's health are the only three facts that will say so, in that order.
