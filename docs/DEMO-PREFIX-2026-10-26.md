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
landmine fixed (explicit per-box roster, `BOX` file).

## 1. The bar and the public-opening contract

The bar: a stranger with the URL exercises every surface for a week without the operator
babysitting.

Rehearsal ships (operator-only, re-genesis allowed) happen on the day planned with every red
named: that is how DelveTalk shipped seventeen editions in a week and how DEPLOY-3 died when
it was batched behind a composed gate (HISTORY §8). **Public opening** needs one contract, all
four parts, measured on the demo box itself:

1. **Advertised surfaces work**: the demo journey's rows for every surface that is on pass
   on the candidate that ships (ssh shell J0–J8+J12, docuverse static render, EtherCalc
   two-browser co-edit + restart, Hermes room resident with a real pool/homelab call, one
   mainnet pay-to-enrol, Discord slash entrance, fn consumer worker, fleet row, oracle grain).
2. **Tenancy holds**: split tenancy on the box (`jsplit-tenancy.sh` green), no member can read
   another's key, the operator socket is unreachable from a tenant, Lean-emitted default
   policies replace permit-all before the door opens.
3. **Uncertain effects recover safely**: no undecided outcome is shown as a refusal; no
   money or write path reruns without a record; provider failures (non-200, timeout,
   malformed, crash-after-send) leave a decided purse; a failed first CREATE on a grain is
   recoverable; restart, certifier failure and backup drills pass.
4. **Performance and week scale**: the growth judge's criterion is write **maximum ≤ 5 s**
   (not p99: `native/resource-client/journey.sh:858-866`) and cold reopen ≤ 60 s at 1000
   records, measured on the demo box (not a loaded build box), plus a 10k-record soak (a
   week of minute ticks alone is ~10,080 records) with the numbers written down.

The composed gate `jdeploy3` runs on every rehearsal candidate and its reds are named; it
must be green for the candidate that opens. "Every surface in ~two weeks" is a target the
council unanimously called not yet evidence-backed; the date is re-estimated after Phase 0's
evidence spike (§3), not promised now.

## 2. Where we stand (2026-10-26 evening)

- **One public node exists** (`dregg-workhorse`, cx33 fsn1, candidate 5688775a of Sep 30 over
  ssh; nobody but ember's harness has used it). It is torn down once the new box is up.
- **main `d4f30d1f`** = the Oct 14–17 integrator batches + today's housekeeping, review corpus
  and this plan. Tracked lines 1.69M (HISTORY §0.3; its "422K native Rust" counts every
  tracked file under `native/`; the `.rs`-only count is 292K: both exceed the 290K founding
  budget on their own). Host executable closure 784 modules / 330K Lean lines.
- **Today's candidate of main** (HBOX-CANDIDATE): 35 min fetch-to-candidate off the warm base
  (cold Lean time still unmeasured; the M7 reference build now in flight measures it); rows
  PASS 136 / FAIL 2 / UNCONFIGURED 6 / UNJUDGED 3 against a baseline of 137/2/5/3 (the one
  delta, m6grain, is a harness path, now being fixed); `jdeploy3` FAIL: growth over the MAX
  bar at every level on a loaded box; the composed scenario never ran because dregg-infra's
  manifest rewrite dropped the v2 contract.
- **dregg-infra** is reconciled and PUSHED (main 5501f4f, demo-vm dbc17c7, both remotes): the
  full v2 manifest rebuilt from provenance (18/18 self-test), the DelveTalk candidate restored
  by a forward commit, the certifier merged onto split tenancy (its 320-record claim still
  only the branch's own report), genesis `issuanceCap` and `lifetime` 200000 set, the roster
  fix. The confined box (`edge/demo/`, `edge/tofu-demo/`) is written and validated, unapplied.
- **Known reds on main**: `Fixtures.NativeAcceptedFixture` (fixture-only); `jpay/JPAY6` (a
  70-byte socket-path row in the journey driver, AND the consent allowlist lacks fields:
  both diagnoses are being fixed); `m6grain` (sudoers path, being fixed); `m7` (no reference,
  being built); pending `births`, `HERMES-LIVE`, `jcertify`.
- **In flight right now** (lanes, each on its own `lane/*` branch in a worktree): L1 Lean
  critical path (hbox), L2 custody, L3 fence+sandbox, L4 Hermes+rooms, L5 door+PAY+Discord,
  L6 keys+store, L7 web, L8 fn+fleet, L9 build gating, L11 performance, the infra lane, the
  hbox lane (composed-gate re-run on the fixed frame, then the M7 reference build). Ember's
  codex session is landing the oracle appliance in the main worktree (`native/oracle-appliance`,
  `native/spk-package-stream`, `deploy/oracle/`, an SPK `import-profile`); it is the oracle lane.

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
| **L1 Lean** (hbox lane, Fable) | ★(a) JPAY6: the driver's 70-byte socket row AND the consent allowlist fields; ★(b) a no-effect class on `Outcome` + the positive `NO_RECORD` frame, stated as a theorem first (NO_RECORD ⇒ the durable log is unchanged by that request); ★(c) a settle that leaves the purse decided for all four provider failure classes (non-200, timeout, malformed, crash-after-send); ★(g) Lean-emitted default `Pred` policies replacing permit-all on member accounts, tills, room cells (R11, moved into Phase 1 by all three reviewers); (h) the clock-law bypass on the PAY path (`Compiler/CanonicalCellRegistry.lean:108-112`: PayObservation/PayEnrol advance the clock without judging the law); (e) consent op list and response-marker table emitted from the registry; (d) op 35 receiver confirmed; (f) the 33 vacuous `∨ Collision` rewrites, demoted to last/optional | three uncalled V1/V2 submit receivers (383); census-only V1 lifecycle modules (347); orphan battery files (3,188) |
| **L1b Lean economy** (after L1 pushes (a)–(c)) | ★ a minimal Lean-owned grain work tariff and ceiling, with the provider route bound to an operator table digest, before paid grain operations are exposed (R12: the council rejected "after the demo" as a containment shipped ahead of the fix, ATLAS law 15); the full economy (C6) stays Phase 3 | — |
| **L2 custody** | ★ the refusal-semantics core first (the four 255 sites by decoded type; `fleet-sign` `uncertain`; record-less reruns refused for `credit`/`well`/`activity`/`workspace submit`; chat's outer retry loop); THEN `flow::Client` as the one signing path (the client's working path moved into the SDK) | traffic stacks 1 and 3 (3,774), `session_reenroll.rs` (1,150), `bend_session.rs`, `web/surface.rs` + `world_surface.rs`, unreached arms, Studio (D7) |
| **L3 fence + sandbox** | ★ per-signed-call dispatch fence (today one `contention` locks every member out for 19–51 min); STOP lookups and deadlines; `broker_home::render` renders real hardening; seccomp gaps; the floor audit runnable on the production spawn path; bounded dispatch directories; the route socket accepts the edge gid (W6); v4 failed-START recovery, Rust half | `spk-hostd`/`endpoint.rs`/`serve_resident`, five harness binaries (2,168), `claim_descriptor.rs`, `setid_bound.rs`, stale `allow(dead_code)` headers; agent API v1 only after v3 demonstrably supersedes it (R7) |
| **L4 Hermes + rooms** | ★ units that open; a first-class `grain create`; the three-state outcome record; length-prefixed admin protocol; concierge keyed on `transactionId`; subprocess deadlines; provider failure classes decided and clearable (Rust half); the real room resident run once on hbox; the `--network none` + bridge topology run once | legacy `hermes-room` runner (after J14 re-points to the ACP resident), `session_failure`/`resident_outcomes` (after the typed record), dispatch v1, `config_migration`, `legacy_custody_audit` (~3,100 + 2,900) |
| **L5 door + PAY + Discord** | ★ the self-serve join door (unprivileged queue uid; a root processor that is the only writer of accounts, keys, `authorized_keys`, roster) with the `possess` custody flow and NO sponsor-held copies of member keys; pay-to-enrol onto a HOSTED account; `journalFloor` from the signed tariff; PAY pagination/dust, nullifier attribution, stuck-tick quarantine; Discord slash entrance via `/mini link CODE`, retry only on a decoded undecided outcome, a unit shape that holds under split tenancy; the mirror behind a flag, default off (needs a bot token + intent) | discord dead code; `join_solana` v1 after v2 is the door's route |
| **L6 keys + store** | ★ mini-keys in the split shape (NOT `singleAccount`: it bypasses the broker's identity checks, `server/mod.rs:340-354`); grant caps enforced against the parsed body or a Lean reserve; op-144 answer pinned to the socket owner's uid and key-compared; per-uid slots and frame caps; image hashed once per candidate; tickets durable before the quota count; audit failure refuses; SQ: bound violations refuse loudly, typed full-disk read errors, crash/hold verbs out of the production binary, DURABLE-STORE.md rewritten to schema 5 | `verify-mldsa` + `fips204`, `Broker::default_box` |
| **L7 web** | ★ the two render repairs (a malformed shared-name link breaks every reader; raw terminal escapes in history/diff); `mini web --read-only`; `--render-static` with `--public-origin`; the `public` reader subject + snapshot timer as `mini-pubread` with no network; Caddy snippet; join page with the D8 sentence | templates move into the crate |
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

**For ember** (the residue all three reviewers left; answer when convenient, the lanes do not
block on it):

1. **Money**: the OpenRouter hard spend cap; the sponsor's total funding cap and the
   per-stranger provisioning amount; week-1 pay-to-enrol on mainnet (one real payment from
   your wallet to accept it) or devnet-only.
2. **Lifetime**: the shutdown date the demo advertises and the backup retention period.

Everything else you supply is a provisioning action, listed in Phase 0.3.

## 6. What this file is not

It is not a claim that any of it has run. Phase 0's re-run, each rehearsal's gate verdict
and the live node's health say so, in that order.
