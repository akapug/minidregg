# The demo prefix: from main to a public Mini on Hetzner, with every surface on

Present-state plan, rewritten whole on 2026-10-26 (evening) after a three-model council
(GLM-5.3, Kimi k3.1-pro, Astra/codex; their reviews are in `docs/review/2026-10-26-council/`)
read the first draft against the review corpus under `docs/review/2026-10-26-*`. Every number
below cites that corpus. The companion for the box is `~/dev/dregg-infra` (`main` 5501f4f and
branch `demo-vm`; `MERGE-2026-10-26.md` there).

## 0. Settled

The Hetzner demo runs **minidregg**, repaired and consolidated in place (rescue, repair,
delete, in that order), shipped as operator rehearsals to a fresh confined VM in its own
hcloud project from the first days, and **opened to strangers when one public-opening
contract holds** (§1). nanodregg stays the object of study whose laws are the target shape of
the consolidation. The council (all three) ruled this already decided by ember's words of
Oct 19 and Oct 26 and the README of Oct 23; it is not re-asked.

Also settled today: every surface on (ssh hosted shell, web docuverse, one SPK grain, Hermes
residents, PAY, Discord, fleet, fn transport, the veri7vn oracle appliance as an SPK app);
hcloud project `dreggnet-demo`, same account; `demo.dregg.online` and `calc.demo.dregg.online`;
security kernels rebooted as soon as available; operator ssh on 22; clock tick per minute;
Caddy terminates TLS with hybrid X25519MLKEM768 + X25519 fallback; EtherCalc on its own
origin; Studio out until a producer exists; `m6.sh` wraps `two-world-journey.sh`; the roster
landmine fixed (explicit per-box roster, `BOX` file); `*.demo.dregg.online` wildcard DNS as code and a
**wildcard certificate** via Caddy's Gandi DNS-01 module (ember, 2026-10-27: "wildcard approved"), which
puts a DNS token on the box as a written CONFINEMENT §2 exception and makes Caddy security updates our
own rebuild; every installed grain gets one fixed origin `<grain>.demo.dregg.online`.

## 1. The bar and the public-opening contract

The bar: a stranger with the URL exercises every surface, for as long as the demo stands (to 11 Nov
2026), without the operator babysitting, and finds a coherent product, not a set of prototypes. There
is no "week-1" scope and no degraded first edition (ember, 2026-10-27: "we've let week-1 become a
hobgoblin of our minds and we must kill it and raise our ambitions"); half-built prototypes are compost
for the one design, never exposed as a hodgepodge.

Rehearsal ships (operator-only, re-genesis allowed) happen on the day planned with every red
named: that is how DelveTalk shipped seventeen editions in a week and how DEPLOY-3 died when
it was batched behind a composed gate (HISTORY §8). **Public opening** needs one contract, all
four parts, measured on the demo box itself:

1. **Advertised surfaces work**: the demo journey's rows for every surface that is on pass
   on the candidate that ships (ssh shell J0–J8+J12, the browser front end (terminal, documents, boards, rooms, apps, receipts),
   the app market (any Sandstorm SPK installed by a member and opened on its own origin), EtherCalc
   two-browser co-edit + restart, Hermes room resident with a real pool/homelab call, one
   mainnet pay-to-enrol, Discord slash entrance, fn consumer worker, fleet row, oracle grain).
2. **Tenancy holds**: split tenancy on the box (`jsplit-tenancy.sh` green), no member can read
   another's key, the operator socket is unreachable from a tenant, Lean-emitted default
   policies replace permit-all before the door opens.
3. **Uncertain effects recover safely**: no undecided outcome is shown as a refusal; no
   money or write path reruns without a record; provider failures (non-200, timeout,
   malformed, crash-after-send) leave a decided purse; a failed first CREATE on a grain is
   recoverable; restart, certifier failure and backup drills pass.
4. **Performance is measured and published, never a gate** (ember, 2026-10-27: "growth / perf
   isn't a good reason to avoid deploying this demo right now, we'll do more focused performance
   engineering later"). The growth judge's numbers (write MAX, p99, reopen at 1000 records; the
   journey's criterion is MAX ≤ 5 s, `native/resource-client/journey.sh:858-866`) and a 10k-record
   soak are measured on the demo box and written on the join page and in the plan; they do not
   block a rehearsal or the opening. L11 continues as engineering, off the critical path.

The composed gate `jdeploy3` runs on every rehearsal candidate and its reds are named; for the
candidate that opens, its composed phases and its non-performance journey rows must be green
(growth/perf/births rows are non-blocking by the ruling above; `ship.sh` encodes this as a named,
tested rule). The date is re-estimated from each rehearsal's evidence, never promised.

## 2. Where we stand (2026-10-27, early)

- **Rehearsal ship #1 is SERVING on the demo box** (2026-10-27, ~04:30 UTC): `dregg-demo`
  (Hetzner `ccx23`, fsn1, Debian 13, `167.233.199.225` / `2a01:4f8:c17:873b::1`; `demo.`, `calc.demo.`,
  `nano.demo.dregg.online` resolve) runs candidate a0db11f8a8bc under `ship.sh --rehearsal` with every
  login closed and the reds named in the notice; `mini-health` OK (signed read 0.33 s); Store, public
  ingress, key broker (sealed OpenRouter pool key, BYOK row), certifier and clock timers, Caddy with
  valid TLS are up; `/join` answers 503 with the maintenance text and the 11 Nov shutdown line; Hermes
  (no controller.json yet), Discord (bot in zero guilds), PAY (devnet config, no observer key), the
  door (not in this candidate) and roster sync (rehearsal) are off with their reasons recorded. Known
  reds: nano's writer fails in bwrap (ENOSYS on /dev; with the nano root); thin consent refuses a
  signed write on this candidate (consent = full until the incremental refresh lands). Seven frame
  bugs found by the first real split-tenancy ship are fixed on dregg-infra main 587169b / demo-vm 8991808.
- **nano's testground is live on the box** (2026-10-27): `wss://nano.demo.dregg.online/ws` serves
  (writer under the admitted bwrap exception: `RestrictSUIDSGID=no` + `NoExecPaths`, because systemd's
  sxid filter returns ENOSYS for `openat2`, which bwrap 0.12 needs); a Chromium visitor at the Pages
  link joins the box's World as a member in ~0.6 s. The first browser-reachable surface on the box.
- **A dedicated Linux build box exists**: `dregg-build` (Hetzner ccx33, 8 dedicated vCPU / 32 GB, SSD,
  fsn1, `178.105.4.114`, dies with the demo on 2026-11-11; dregg-infra `demo-vm` `edge/tofu-build/`):
  Lean + Rust toolchains, warm Lake cache, a `lanes` user; lanes run their Linux checks and the
  integration build there instead of queueing on hbox's HDD. hbox's SSD (`rpool`, `/othersys/lanes`) now
  holds lane hot work; `/tank` keeps the warm base and candidates. The Mac rebuilt the host closure in
  ~25 minutes and is the Lean box for per-file work.
- **The coordination rewrite is on `lane/coordination`** (34460623): `docs/COORDINATION-2026-10-27.md`
  (one present-state description of how the project is developed) and the deletion of the gate
  bookkeeping that measured itself: 653 files, −116,517 lines (Objective contract manifests, the
  known-red ceremony, guard-discipline, waste-model, carrier census; host-closure.pin folded to one
  number; the hypothesis ledger and censuses moved to the nightly). Merges in integration round 2.
- **One older public node still runs** (`dregg-workhorse`, candidate 5688775a of Sep 30; nobody
  but ember's harness has used it). It is torn down once the demo box serves.
- **main `1f180a75`** = the Oct 14–17 batches + today's housekeeping, review corpus, council and
  plan. Tracked lines 1.69M; host executable closure 784 modules / 330K Lean lines.
- **Lane branches pushed and done** (integration into `integration/2026-10-26` running):
  `lane/custody` (L2 core: one signing path in the SDK, the four refusal fixes; L2 continues
  with call sites and deletions), `lane/web` (L7), `lane/build` (L9, contains web), `lane/fn-fleet`
  (L8), `lane/door` (L5), `lane/keys-store` (L6), `lane/fence` (L3, one follow-up commit coming:
  absent-after-lost-reply is undecided, not no-record). Still working: `lane/lean-critical`
  (L1, hbox), `lane/hermes` (L4), `lane/perf` (L11).
- **Today's candidate of main a0db11f8** (HBOX-CANDIDATE): 35 min fetch-to-candidate off the
  warm base; rows PASS 136 / FAIL 2 / UNCONFIGURED 6 / UNJUDGED 3 against 137/2/5/3; `jdeploy3`
  FAIL (growth over the write MAX bar on a loaded box; the composed scenario never ran because
  the infra manifest rewrite dropped the v2 contract: fixed in dregg-infra 5501f4f; the
  composed phases are being re-run now, with the M7 reference build and the `exchange` row).
- **dregg-infra** main 5501f4f and `demo-vm` 8fca5ad, pushed to both remotes: the full v2
  manifest, the certifier on split tenancy, genesis `issuanceCap` + `lifetime` 200000, the
  roster fix, the confined box roots, the nano tenant contract. Queued on `demo-vm`: the
  door's infra patch (L5) and the mini-keys config changes (L6), effective at rehearsal #2.
- **Known reds on main**: `Fixtures.NativeAcceptedFixture` (fixture-only); `jpay/JPAY6` (driver
  row AND consent fields, both in L1); `m6grain` (sudoers path, hbox lane); `m7` (reference being
  built); pending `births`, `HERMES-LIVE`, `jcertify`.
- **Ember's codex session** is landing the oracle appliance in the main worktree (uncommitted:
  `native/oracle-appliance`, `native/spk-package-stream`, `deploy/oracle/`, the SPK
  `import-profile`); it is the oracle lane and reconciles with `lane/fence` when it commits.

## 3. The prefix

Three phases. Lanes are repair lanes: rescue or repair first, deletions as the last step of
each merge. Sizes S < 1 day, M 1–3 days, L > 3 days. Sources: SYNTHESIS §F, LEAN-TRIAGE §3–4,
WEB-SPK-PUBLIC §7, HCLOUD-GAP §7 (`#n`), RUST-TRIAGE §2–4, the council reviews.

### Phase 0: evidence spike + provisioning (now; mostly in flight)

| # | what | status |
|---|---|---|
| 0.1 | Re-run the composed gate on today's candidate with the fixed frame (first time the composed phases ever execute); fix m6grain's sudoers path; build the M7 reference (also the first cold Lean build time) | hbox lane, running |
| 0.2 | The two measurements that size the schedule: cold Lean rebuild time (0.1); the write MAX at 1000 records on a quiet box (the demo cx43 itself, once it exists) | after 0.3 |
| 0.3 | Provisioning inputs (owner actions, not rulings): hcloud project + token in 1Password; DNS for the two names; `edge/demo/friends/ember.pub`; Discord application (+ bot token and Message Content intent only if the mirror is wanted); OpenRouter pool key with a HARD spend cap; two Solana mainnet RPC endpoints; the enrolment address | ember |
| 0.4 | `tofu apply` in `edge/tofu-demo` (cx43 Debian 13), `install-demo.sh`, then the two never-run items as scratch runs on the real box: split tenancy (`jsplit-tenancy.sh`) and M6 (one grain) on Debian 13 | infra lane, after 0.3 |
| 0.5 | Workspace membership gate (L9's first item): every crate a member or an explicit `exclude`; formerly-unbuildable crates' tests run once, ran-from-passed reported | L9, running |

### Phase 1: repair lanes (parallel; Lean interfaces land FIRST and rebuild early)

The council's strongest correction: the Lean interface changes (NO_RECORD, the provider
settle, emitted defaults) are not "one rebuild at the end"; L1 pushes after (a)–(c) so every
Rust lane rebases onto the new Outcome semantics early. Ownership is single: `fleet_sign.rs`
is L2's; `credentials.rs` moves in L6 (L4 consumes); spk-host's `broker.rs`/`materialize.rs`
/`spk-ingest` are the oracle lane's, L3 stays surgical there.

| lane | rescue / repair (critical-path items ★) | deletions at merge |
|---|---|---|
| **L1 Lean** (hbox lane, Fable) | ★(a) JPAY6: the driver's 70-byte socket row AND the consent allowlist fields; ★(b) a no-effect class on `Outcome` + the positive `NO_RECORD` frame, stated as a theorem first (NO_RECORD ⇒ the durable log is unchanged by that request); ★(c) a settle that leaves the purse decided for all four provider failure classes (non-200, timeout, malformed, crash-after-send); ★(g) Lean-emitted default `Pred` policies replacing permit-all on member accounts, tills, room cells (R11); (h) the clock-law bypass on the PAY path (`Compiler/CanonicalCellRegistry.lean:108-112`: PayObservation/PayEnrol advance the clock without judging the law); (e) consent op list and response-marker table emitted from the registry; (d) op 35 receiver confirmed; (f) the 33 vacuous `∨ Collision` rewrites, demoted to last/optional | three uncalled V1/V2 submit receivers (383); census-only V1 lifecycle modules (347); orphan battery files (3,188) |
| **L1b Lean economy** (after L1 pushes (a)–(c)) | ★ a minimal Lean-owned grain work tariff and ceiling, with the provider route bound to an operator table digest, before paid grain operations are exposed (R12: the council rejected "after the demo" as a containment shipped ahead of the fix, ATLAS law 15); the full economy (C6) stays Phase 3 | — |
| **L2 custody** | ★ the refusal-semantics core first (the four 255 sites by decoded type; `fleet-sign` `uncertain`; record-less reruns refused for `credit`/`well`/`activity`/`workspace submit`; chat's outer retry loop); THEN `flow::Client` as the one signing path (the client's working path moved into the SDK) | traffic stacks 1 and 3 (3,774), `session_reenroll.rs` (1,150), `bend_session.rs`, `web/surface.rs` + `world_surface.rs`, unreached arms, Studio (D7) |
| **L3 fence + sandbox** | ★ per-signed-call dispatch fence (today one `contention` locks every member out for 19–51 min); STOP lookups and deadlines; `broker_home::render` renders real hardening; seccomp gaps; the floor audit runnable on the production spawn path; bounded dispatch directories; the route socket accepts the edge gid (W6); v4 failed-START recovery, Rust half | `spk-hostd`/`endpoint.rs`/`serve_resident`, five harness binaries (2,168), `claim_descriptor.rs`, `setid_bound.rs`, stale `allow(dead_code)` headers; agent API v1 only after v3 demonstrably supersedes it (R7) |
| **L4 Hermes + rooms** | ★ units that open; a first-class `grain create`; the three-state outcome record; length-prefixed admin protocol; concierge keyed on `transactionId`; subprocess deadlines; provider failure classes decided and clearable (Rust half); the real room resident run once on hbox; the `--network none` + bridge topology run once | legacy `hermes-room` runner (after J14 re-points to the ACP resident), `session_failure`/`resident_outcomes` (after the typed record), dispatch v1, `config_migration`, `legacy_custody_audit` (~3,100 + 2,900) |
| **L5 door + PAY + Discord** | ★ the self-serve join door (unprivileged queue uid; a root processor that is the only writer of accounts, keys, `authorized_keys`, roster) with the `possess` custody flow and NO sponsor-held copies of member keys; pay-to-enrol onto a HOSTED account; `journalFloor` from the signed tariff; PAY pagination/dust, nullifier attribution, stuck-tick quarantine; Discord slash entrance via `/mini link CODE`, retry only on a decoded undecided outcome, a unit shape that holds under split tenancy; the mirror behind a flag, default off (needs a bot token + intent) | discord dead code; `join_solana` v1 after v2 is the door's route |
| **L6 keys + store** | ★ mini-keys in the split shape (NOT `singleAccount`: it bypasses the broker's identity checks, `server/mod.rs:340-354`); grant caps enforced against the parsed body or a Lean reserve; op-144 answer pinned to the socket owner's uid and key-compared; per-uid slots and frame caps; image hashed once per candidate; tickets durable before the quota count; audit failure refuses; SQ: bound violations refuse loudly, typed full-disk read errors, crash/hold verbs out of the production binary, DURABLE-STORE.md rewritten to schema 5 | `verify-mldsa` + `fips204`, `Broker::default_box` |
| **L7 web** | ★ the two render repairs (a malformed shared-name link breaks every reader; raw terminal escapes in history/diff); `mini web --read-only`; `--render-static` with `--public-origin`; the `public` reader subject + snapshot timer as `mini-pubread` with no network; Caddy snippet; join page with the D8 sentence | templates move into the crate |
| **L12 web front end** | ★ the browser front end a stranger uses (ember: "at minimum some high quality lightweight embedded terminal plus nice reasonably minimal html forms"): one gateway uid `mini-web` on loopback behind Caddy (`/app/*`, `/ws/*`) holding no key and no Store access; a tiny root helper `mini-web-spawn` that, given a session the door's root processor issued at enrolment, spawns `mini shell` (or a `mini` verb for a form action) as the member's own uid under a pty in the same per-member scope ssh uses and hands back the fd (sshd-style privilege separation); xterm.js vendored (no CDN; the box has no egress); per-member `mini web` proxied under `/app/doc/*` for documents/boards/history (reusing L7's code); minimal no-JS forms for append/edit, boards, explain-refusal, receipts, delegate, law, retry, each showing the decoded outcome; a `jweb-frontend` journey row | the loopback-only assumptions in `web.rs` as the gateway replaces them |
| **L13 app market** | ★ any Sandstorm SPK from app.sandstorm.io: a cached index read by `mini apps search/show`; `mini apps install` as a MEMBER turn (admission + funding) with the download as uid `mini-market` (the one egress to app.sandstorm.io) into quarantine, signature/appId verified by `sandstorm-package`, streamed through `spk-package-stream` into the broker's ingest under the standard import profile, the grain created and started by lifecycle v3 with L3's per-call fence, a receipt with the grain's URL; every grain on its own origin `https://<grain>.demo.dregg.online` (wildcard DNS as code + Caddy DNS-01/on-demand TLS, hybrid with fallback) routed to the custodian via `edgeGid`; member lifecycle verbs with decoded outcomes; `japps.sh` installs two real apps from the index | the GitWeb-specific chain and hand-copied `.spk` paths as the market lands |
| **L8 fn + fleet** | ★ ops 13/15 (fn ACK) operator-only until Lean answers who may ACK a public delivery; the consumer worker as a hardened unit + a journey row on a recorded fixture; fn-r route; one NNTP repost rule | `publisher.rs` (552); the fn-e path; one of the `fn_namespace`/`fn_frontier` twins |
| **L9 build + deploy + gate** | ★ 0.5 first; optional roles optional; `--capsule` deleted or fixed; the journey split into a demo journey inside the 3 h gate + a nightly kernel journey; `m6.sh` runnable | `hyperdocument-link-store`, the bend pair (R10), GitWeb root chain, `probe_control.rs`, `host-frontend.rs`, MUD `sim.py`, `gm/*`, the controller template, objective-emit dead bits |
| **L11 performance** | ★ where the write seconds go, by phase, with A/B on the same box within minutes (the 57 s MAX outlier is the target, not the median); the biggest Rust-side fix (consent replay growth, Host spawns, STOP's five re-hashes); the 10k-record soak designed and, hbox time allowing, run; Lean asks specified file:function | — |
| **oracle** (ember's codex session) | ★ the veri7vn appliance as an SPK grain on the same admitted grain path: today `deploy/oracle/README.md` records `spk_packable: false` (six SQLite members exceed SPK's 512 MiB member limit) so a format/materializer or immutable-data contract is needed, plus a signed package and an acceptance journey; it joins the public-opening contract when green and otherwise misses a redeploy cycle, not the date | — |
| **L10 docs** | present-state rewrite of the ~25 documents the code contradicts (RUST-TRIAGE §2.3), the README honest-state table, FRIENDS.md/OPERATOR.md for the shipped candidate, DURABLE-STORE.md (L6), the two SPK contracts (L3) | — |

### Phase 2: rehearsal ships, then the opening

1. From the merged tip: candidate on hbox (`lane-build.sh` under `swarm-build`), `jdeploy3`
   on it, reds named; `ship.sh --regenesis` to the demo box as an operator rehearsal, every
   few days, re-genesis allowed. The first rehearsal happens as soon as 0.4 is done, with
   whatever is green, so the box, the frame, the certifier and the backups are exercised early.
2. Each rehearsal runs the box drills: restart, certifier failure, backup + `mini-restore-check`,
   one reboot, the alerting path to ember (#13), sshd/nftables limits (#11).
3. **Opening**: when the §1 contract holds on a rehearsal candidate, the join page goes live,
   strangers enrol through the door, and the workhorse's Mini slice is torn down.

### Phase 3: coherence (with strangers on the box)

| # | what | size |
|---|---|---|
| C1 | `World.admit` in gate mode on the receive path (run it, refuse on error, as `Host/WorldSim.lean` composes): the theorems become about the function the writer runs; the refusing-path gap in `HostRefinesWorldCore.lean:418-434` measured first; ~300–800 Lean lines | M–L |
| C2 | The research move: 140 Selvage modules outside the host + importers (109,639 lines, no exe depends on them) to zkml-research; `private-backend` (26,139) to degg-research after its named WAL/custody rescues are decided; census-only Assurance module by module; split `Compiler/Tower256CshakeMerkleController` so the host needs no Selvage, as `Deployed.lean` claims | M |
| C3 | Strata consolidation at a re-genesis: `Kernel.ApplicationLifecycle` 66 → one (7,295 lines alive for old-record lookups), `PayEnrol` V1 (~3K), grain-runtime dispatch v2/v3 | M–L |
| C4 | Emit the remaining laws and tables from Lean (shell document/room/board laws, genesis, verb tags, per-op bounds, status enums, `@[export]`ed predicates); delete each Rust twin as its emitter lands | M + S×n |
| C5 | One wire: generated op constants at all 159 literal sites, consent namespace 220–233 registered, envelope v1 refused after migration, the agent API wire in `spk-rpc` | M |
| C6 | The full grain economy in Lean (L1b's tariff widened; paid-slot room admission; delete the Rust concierge decision) | L + M |
| C7 | Never-admissible witness + settle-by-anchor; private rooms owned by Lean; receipts with inclusion; the two choreographies; `runtime.c` retired once the fast Lean machine is wired as the differential reference | L each |
| C8 | Performance beyond the bar: in-process codec (~68% of a read), the serial Host submit profile, STOP's re-hashes, room create 262 s | M each |

## 4. Rules for the prefix (binding on every lane brief)

1. Rescue, repair, delete, in that order; "delete the twin" keeps and repairs the better one.
2. Every lane's deletions are named in its brief; the first deletion commit lands within a
   day of the lane's repair going green; a size ratchet refuses growth of the host closure.
3. Lean interface changes land first and rebuild early; no statement packets for code being
   removed; only a lane's top-level theorem must be non-vacuous.
4. Rehearsals ship on the day with reds named; the opening waits for the §1 contract and
   nothing else; the gate is never relaxed and never grown ahead of the surfaces.
5. One root per project; resume the agent that holds the context; no censuses or ledgers
   unless they unblock the ship; every lane brief carries the system framing, the report
   sections, `path:line` pointers, the worktree and branch, and the verification it must run.
6. Engineering decisions are made by the orchestrator after a multi-model synthesis; only
   money, dates and credentials go to ember.
7. `swarm-build` on hbox, `/tank` only; named-file commits; no `git stash`; no pattern kills;
   filtered tests only.

## 5. Decisions

**Taken by engineering after the council** (all three reviewers agreed these are not the
owner's): R1 settled (§0); R2 the DelveTalk candidate restored by a forward commit (done);
R3 pushed (done); R4 Hermes pool route only from a candidate carrying L1(c)'s four-class
settle AND a real HERMES-LIVE pass, BYOK rows accepted as operator tests, never as the
stranger path; R5/R6 the research moves in Phase 3 with the boundary and prover-glue gates
kept green; R7 repair and run agent API v3 for the oracle/Hermes composition, delete v1 now,
v2 only after v3 demonstrably supersedes it; R8 keep the v4 retry lane and make failed-START
recovery work on it (L3 + Lean ask); R9 keep traffic stack 2 as research-only, outside the
public candidate, delete stacks 1 and 3; R10 delete the bend pair now, retire `runtime.c`
only when the Lean fast machine is the differential reference; R11 Lean-emitted defaults in
Phase 1 (L1(g)), the door opens after; R12 a minimal Lean-owned tariff and ceiling before paid
grain operations (L1b), the full economy in Phase 3; R13 workspace gate day one (L9); R14
README rewritten whole as lanes land and once more against the shipped candidate; R15 the
oracle ships through the same grain gate, with its format blocker owned by the oracle lane.

**Answered by ember (2026-10-27)**: the OpenRouter pool key exists at `~/.openrouter-key` with
a $50 hard cap set at OpenRouter (the broker's pool ceiling is $40, $0.10 worst-case per call;
BYOK on); the Dragon's Egg bot (application 1507638321877090374) is in guild 1507637841235017768;
the demo's **shutdown date is 2026-11-11**, written on the join page and in the teardown plan;
backup retention defaults to 7 days after shutdown. Still open, with the engineering default that
applies meanwhile: **mainnet vs devnet for pay-to-enrol** (default: devnet, two providers,
until ember says mainnet; the sponsor's total cap and per-stranger funding amount are the door's
configured values, published on the join page).

## 6. What this file is not

It is not a claim that any of it has run. Phase 0's re-run, each rehearsal's gate verdict
and the live node's health say so, in that order.
