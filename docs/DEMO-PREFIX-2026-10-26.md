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

Also settled (2026-10-26/27): every surface on (ssh hosted shell, web docuverse, one SPK grain, Hermes
residents, PAY, Discord, fleet, fn transport, the veri7vn oracle appliance as an SPK app);
hcloud project `dreggnet-demo`, same account; `demo.dregg.online` and `calc.demo.dregg.online`;
security kernels rebooted as soon as available; operator ssh on 22; clock tick per minute;
Caddy terminates TLS with hybrid X25519MLKEM768 + X25519 fallback; EtherCalc on its own
origin; Studio out until a producer exists; `m6.sh` wraps `two-world-journey.sh`; the roster
landmine fixed (explicit per-box roster, `BOX` file); `*.demo.dregg.online` wildcard DNS as code and a
**wildcard certificate** via Caddy's Gandi DNS-01 module (ember, 2026-10-27: "wildcard approved"), which
puts a DNS token on the box as a written CONFINEMENT §2 exception and makes Caddy security updates our
own rebuild; every installed grain gets one fixed origin `<grain>.demo.dregg.online`.

## 1. The bar, the gate, and the public-opening contract

The bar: a stranger with the URL exercises every surface, for as long as the demo stands (to 11 Nov
2026), without the operator babysitting, and finds a coherent product, not a set of prototypes
(`docs/DEMO-EXPERIENCE-2026-10-27.md` is what that product is). There is no "week-1" scope and no
degraded first edition; half-built prototypes are compost for the one design.

**The gate is the tour** (ember, 2026-10-27 morning: no row burndown). A rehearsal ships when ember says, from the
newest green candidate, with its reds named; it tests a CONVERGED sprint, never green alone (ember,
2026-10-27 late evening: no rehearsal this sprint; the next carries ALL outstanding work, including the
one re-genesis of the platform cell, the activity effects and checkpoint v4, after a harness restart); the only reds a rehearsal or the opening is judged by are (a) the stranger's tour,
`jtour`: the web journey's rows driven against the box's own Host (the twelve steps of the experience
document, parity over every verb leaf, the lost reply and its exact retry, the paste-the-yes), and
(b) the composed scenario over N forced-ssh members (rooms, churn, documents, apps, connector,
residents, restart). The 148-row standing run is the nightly's on `dregg-build`; it names its reds
in the morning report and never names a candidate's. Performance is measured and published, never a
gate.

**Public opening** needs one contract, measured on the demo box itself:

1. **The tour runs for a stranger**: every spine step of the experience document admitted/refused/
   undecided as the step says, from a browser with nothing installed; the composed scenario's phases
   pass; one real Hermes resident through the pool route; one app installed from the real store and
   opened on its own origin; one mainnet pay-to-enrol.
2. **Tenancy holds**: split tenancy on the box, no member can read another's key, the operator socket
   is unreachable from a tenant, Lean-emitted default laws replace permit-all.
3. **Uncertain effects recover safely**: no undecided outcome is shown as a refusal; no money or
   write path reruns without a record; provider failures of all four classes leave a decided purse;
   restart, certifier failure and backup drills pass.
4. **Performance is measured and published**, on the join page and here, never a gate.

**The opening target is 2026-10-29**, re-estimated from rehearsal #3's evidence (round 4's candidate,
a re-genesis carrying the grain platform), and announced when the contract holds. Mainnet
pay-to-enrol from the first open day (ember, 2026-10-27).

## 2. Where we stand (2026-10-27, mid-morning UTC; rewritten whole)

**What "there" is** is now written once: `docs/DEMO-EXPERIENCE-2026-10-27.md` (the fifteen-minute
tour a stranger takes from a browser, the parity law that everything the shell can do is done
visually in the browser, the box as a member posting its own operations as receipts, the ranked
ambitions A0–A9). The join page, the front page, the README table and the demo journey derive from
it. This section says where the work is against it.

**The box.** `dregg-demo` (Hetzner `ccx23`, fsn1, Debian 13, `167.233.199.225` / `2a01:4f8:c17:873b::1`)
serves **rehearsal ship #1** of candidate a0db11f8a8bc under `ship.sh --rehearsal`: every login
closed, the reds named in the login notice, `mini-health` OK, Store, public ingress, key broker
(sealed OpenRouter pool key with a $40 ceiling and $0.10 per call under ember's $50 cap; BYOK on),
certifier and clock timers, Caddy 2.11.7 (our build, Gandi DNS-01 module, pinned by hash) serving
`demo.`, `calc.demo.`, `nano.demo.` and the `*.demo.dregg.online` wildcard certificate with hybrid
X25519MLKEM768 + classical fallback; per-IP 443 limits box-wide; backups to
`dreggnet-demo-mini-backups` (Object Lock COMPLIANCE, 22 days) with the restore check green; ember's
narrow Gandi PAT root-only on the box; consent `full` on this candidate (the O(1) consent arrives with
rehearsal #2). Off, with reasons recorded in `edge/demo/CHECKLIST.md`: Hermes (no controller yet),
Discord (gateway mode arrives with rehearsal #2; the bot token is installed root-only and the
drop-in is staged), PAY (devnet, no observer key), the door (not in this candidate), roster sync.
nano's testground is live on the box from its own origin (`https://nano.demo.dregg.online/`,
kernel e16403be, Landlock+seccomp self-confinement, per-IP enrol budget). The older public node
`dregg-workhorse` still runs candidate 5688775a of Sep 30 for nobody; its Mini slice is torn down at
the opening.

**The build box.** `dregg-build` (ccx33, 8 dedicated vCPU / 32 GB, fsn1, `178.105.4.114`, dies with
the demo on 2026-11-11): Lean + Rust toolchains, warm Lake cache, the `lanes` user, anonymous fetch
from GitHub, no push, no production secret. Lanes run their Linux checks and the integration build
there; hbox keeps the standing run and the warm base on `/tank`, lane hot work on its SSD
(`/othersys/lanes`), every job in its own `swarm-build` cgroup, in parallel. The Mac holds a warm
`.lake` of the host closure (3,739 jobs, 51 min cold) and is the per-file Lean box. The first clean
cold Lean build of the host umbrella on `dregg-build`: 1,308 modules in 2 h 00 min at 2 seats, cgroup
peak 17.2 GiB (heaviest module 18.5 GiB); 4 seats are safe with the measured per-module RSS table.

**Discord, settled.** Ember lost admin access to the account owning application 1507638321877090374
(Dragon's Egg), so no Interactions Endpoint URL will be set; the portal saves that failed were made
on a different application (1554678232631091200). The entrance now has a **gateway mode**
(`lane/door` bce88a74, merged into integration): the bot connects out to `gateway.discord.gg`,
receives `INTERACTION_CREATE` there, answers through the REST callback; token as a systemd credential;
outbound 443 only, no inbound route. The box side is staged for rehearsal #2.

**Integration round 2** (`integration/2026-10-26`, integrator lane): final at **45f45d15**: round 1's
branches plus L3 fence 5aaf1a32, L4 hermes a9e0dd70, L5 door bce88a74, L13 app-market fc4e2c7d, L12
web-frontend db7f3171, L1 lean-critical 181e44e6, coordination 179a21c2, m7 c851d8c4; built on `dregg-build`
(`/build/candidates/45f45d15…`, 21 roles including the web gateway and its root helper; host 1,598 s,
consent 323 s, rust 220 s; the host-closure ceiling held); its standing rows on `dregg-build`:
**PASS 113 / FAIL 24 / UNCONFIGURED 7 / UNJUDGED 3** (wall 6,482 s); composed scenario: rooms, churn,
documents, restart PASS, apps/connector/residents blocked (no script yet produces a scratch world's SPK
platform, resident and protected-document inputs; L13 is writing `composed-inputs`). The reds are
driver-side or environment, not the product: the stranger driver and the demo set counted only the old
refusal byte (J5 and its cascade; fixed at 9f144c2b, the rest with the L2 successor), the `--again`
class and the unbounded loops (fixed at 2c15e48c: with those drivers seats, bounty, send, domain,
objectrecord, upgrade and JPAY4 all PASS), chargedfailure (L2 successor), jserve timing and births/perf
under load, m6grain/JPAY6's `sudo -n true` probe. The web journey against this Host: 24/24.
**Rehearsal ship #2 is SERVING** (2026-10-27 ~10:54 UTC, `--rehearsal --regenesis`, every login
closed, the 36 reds in the notice): `mini-health` OK (0.79 s), the door on 8796 (`/join` held closed),
mini-keys in the split shape with the sealed pool key and its caps, **Discord over the gateway, READY
as Dragon's Egg**, the web gateway and root helper up with Caddy's `import mini_app`, the app front on
8799 and the index fetcher reaching the store (98 apps), consent full; drills green (advance, Store and
relay restart, certifier not-due, backup 121 MB pushed + restore check OK). Not yet live, each with its
owner: the `public` member (its `enroll plan` goes stale while the clock writes: client lane), so the
front page answers 502 as the public reader; the apps world's metered tasks (L13's bootstrap verb);
the Hermes controller (L4 resumed to stand it up and run HERMES-LIVE).
**Round 3** started at integration 6236826f (custody-drivers, m7, web-frontend d14ca3c8 with
app-market inside, the stranger-driver fix). **M7 PASS** for this candidate: a cold build of the same commit on the second Debian 13
box `dregg-ref` reproduces all 26 outputs byte for byte (the first reproducible-build verdict across two
machines this project has had; the earlier hbox reference differed only by Ubuntu's GCC startup objects).
Cold build on `dregg-ref`: 790 Lean modules in 35.8 min, 53 min total, on an idle box (the earlier 78.8 min
shared `dregg-build` with another lane's builds; not isolated). Evidence: `lane/m7` f5ed535b. Round 1's full journey on hbox (candidate 55e483e0, load 88–118): PASS 118 / FAIL
23 / UNCONFIGURED 4; the new reds are journey drivers still speaking the pre-L2 wire (an L2 successor
lane is on them), JPAY4's fixture tariff, and hbox's tmpfs/load. Round 3 already has L12 3bb0a248 and L2's driver successor 2c15e48c. Then: the whole Lean tree once per box (the cSHAKE/KMAC kernels change a Core olean;
`scripts/build-mini-kernels.sh` first), Linux tests on `dregg-build`, the demo journey rows, J14 on the
ACP resident, the rehearsal #2 candidate → infra ships #2 (door on 8796, mini-keys split shape,
Hermes controller via `grain create`, frame grain units without `RestrictSUIDSGID`, gateway Discord).

**Main advances every cut** (ember, 2026-10-27 morning): integration was merged into main at
6b824270 (cut 4) and main has moved continuously since; another session's edits in the shared
worktree are committed as found on sight. Landed on main today besides the lanes: the README rewritten
whole; the L10 docs lane (~35 contradicted documents rewritten against the code, 7 stale files deleted);
the dead-path census repaired across ~100 documents (96 → 6); Studio composted (ruling D7) and the
TypeScript SDK made honest; four tests that could not fail now go red on a planted fault; the GitWeb
ingest chain and six uncalled acceptance scripts deleted with the grep that proves no caller; the Store
and pay-watcher units hardened; the measured lane rules in `docs/COORDINATION-2026-10-27.md` and
`mk-lane.sh`'s brief template; a read-only permission allowlist; three reviews (`docs/review/
2026-10-27-genesis-coupling/`, `2026-10-27-process/`, `2026-10-27-platform-cell-statements/`) and the
harvested backlog (`docs/BACKLOG-2026-10-27.md`: 34 landed, 72 open, 14 superseded, 9 in flight).

**Past cuts** (integration is continuous now; no cadence): cut 6 = 23861533
(tour 38 PASS / 0 FAIL / 1 UNCONFIGURED, the headless-Chromium row now configured on the build box;
composed rooms/churn/documents/restart PASS, apps/connector/residents blocked only on the scratch world's
genesis, now fixed in dregg-infra; the enrol acceptance PASS with five members back to back under a
ticker). Cut 7 (the pay-law genesis v7) building; cut 8 takes the enrolment pin, the platform statements
and the driver fixes.

**Lanes, present tips.** L1 lane/lean-critical 38bfc427 (S1 pay law + control unconditional at every
genesis, frame v7; the platform cell and meter refill as audited statements with their proofs of
ordering, validity and the reference receiver; the enrolment pin that survives ticks; the receiver's
hand-off file; a successor builds the receiver: cell kind → install receiver → Host arms 240–243 →
genesis seed v8 → births priced from the cell → `Intent.credit` + refill ops). L2 successor
lane/custody-drivers 843e0a90 (every driver red of rounds 2–3 fixed; the seal re-inspection fix; the
world template; `--keep-going`, `--only STEP`, `box-wait`; a read-only attempt-state verb next). L3
successor lane/fence (the Debian 13 floor audit PASS; now the SPK resident reading marker 253). L4
lane/hermes 0b8cc8bb (the real upstream Hermes agent through bwrap → bridge → gateway → broker → provider
→ v4 settle on the build box, 105 rows PASS; the v4 `leg` frame; reconcile after the record; the demo-box
install sequence and worker root; the ask pass's completion boundary and the librarian fixture are its
last reds). L12 web lane lane/web-frontend abf33668 (parity 203/203 leaves with 0 refusals; JWF 40/40 on the build box at 42e2db98; "Export my world" end to end on the box (a member's documents, receipts and key as one archive streamed through the gateway, deleted after download, manifest root equal to the live world; the 10 Nov notice on the front page); the Subscribe page for the GLM tier (price, allowance, window as a date; `pay subscribers week` then Join from the inbox invitation; ember's policy sentence a marked placeholder); the seven pay-page audit fixes; tour-chromium green on the box at a0f9c246; the grants page fills progressively and a bare `can` answers a named "N of M grants judged" notice instead of a 504; "Pay with your wallet" on the paid route with sol-misc's adapter and web3.js vendored and pinned; the join page publishes the door's funding figure from its config; the tour's Chromium drive fixed at its causes; an aged world under load showed `mini shell` taking 51 s to start and a one-reference `can` six minutes, now a hot-path item;
the tour's doors 11 and 12; progressive `can`; "Pay with your wallet" on the paid route; the door's
funding figure). L13 lane/app-market f68de59f+ (Hacker Slides and Simple Todos through create, install,
share, start, enrol and page load on a live world; `HackSessionContext` served; the member's own install
pays from the member's account (ruling); `composed-inputs.sh`; `mini apps bootstrap`; the genesis
pass-through for the grain platform). Oracle lane lane/oracle-grain (the design, the data volume, the
`joracle` row; the 15 GB dataset syncing to the build box). Hot-path successor (the codec resident
re-applied; J12X's malformed codec frames; thin consent's JP2).

**Published numbers** (the demo box's own soak, candidate a0db11f8-era binaries, consent in full
mode; read back 2026-10-27; seconds, p50 / p99 / max; performance is published, never a gate):

| level | propose | submit | cold reopen |
|---|---|---|---|
| ~100 records | 0.55–0.63 / ≤0.80 / 0.80 | 0.71–0.81 / ≤0.85 / 0.85 | 1.1–3.9 |
| records 102–1,105 | 1.34 / 2.07 / 2.18 | 0.83 / 0.96 / 1.12 | 1.5 |
| ~1,100 records | 2.10–2.21 / ≤2.30 / 2.30 | 0.86–0.93 / ≤1.20 / 1.20 | 16–17.6 |
| records 1,191–1,770 | 2.63 / 3.40 / 3.54 | 0.90 / 1.08 / 1.82 | 18.0 |

The soak stopped at 1,770 records when the box rebooted for a security kernel (as ruled). Propose
grows ~1.2 ms per record (the consent re-check the box still runs in full mode; the O(1) provider
switches on when thin consent's JP2 is green); submit is flat near 0.9 s; the cold reopen's growth
(the full open re-hashes the whole chain before the light open) is a hot-path item with the
before/after at 1.7k records owed.

**First Linux runs that never happened before** (dregg-build, cut 6's candidate, 2026-10-27): `objective-cgen`
PASS; `objective-c` 1,218 of 1,219 packet differentials with one Lean timeout under a loaded box
(StressCount; a nightly matter); the demo journey 19/40 in a 5,000 s run budget (its K12 docuverse
steps take ~15 min each; the nightly gets the full 10,800 s and measures rather than truncates);
`m6grain` on Debian 13 rerunning after the test-SPK cache path was provided. None of these gates a
rehearsal: the gate is the tour plus the composed scenario.

**Consent mode, decided** (2026-10-27 afternoon): the box stays on full consent; with the O(1) recheck
(`ConsentAnchor.recheckHeld`, in every candidate since round 2) the propose cost is flat, so thin consent buys
nothing the demo needs and lacks a birth arm (JP2 refuses a thin birth by name until a thin-birth design
exists: Phase 3). The soak's propose slope was the pre-recheck binaries.

**The meter.** Found by L1 from the genesis review: `meterAllowance` is a lifetime lane never
replenished; at ~1,000 turnBytes per record the demo's 10^7 lane holds ~10^4 records and the per-minute
clock alone would have emptied it in about 7 days. Rehearsal #3's genesis raises it to 10^10 per lane;
the refill is the platform receiver's last piece.

**Ember's codex session** is landing the veri7vn oracle appliance in the main worktree (uncommitted
`deploy/oracle/`, `native/oracle-appliance`, `native/spk-package-stream`): the split recipe keeps the
15 GB public stores outside the SPK on a fixed `/opt/oracle-data` mount; the signed runtime SPK is
91.9 MB; Mini acceptance is separate work. It reconciles with `lane/fence` and `lane/app-market`'s
spk-host edits when it commits.

**Known reds on main**: `Fixtures.NativeAcceptedFixture` (fixture-only); `jpay/JPAY6` (L1, on its
branch); `m6grain` (sudoers path, fixed on hbox); `m7` PASS on the round-2 candidate (reference on `dregg-ref`); pending `births`,
`HERMES-LIVE`, `jcertify`.

**Owner items**: none outstanding. Optional: three orphaned `mini consent-resident` processes on
hbox (PIDs 1479414, 1526819, 1531493, no PID file) idle until someone with the authority kills them
by PID.

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
| C9 | **Self-confinement instead of bwrap** for Hermes workers and SPK residents on Debian 13: the child applies Landlock (ABI ≥3; Debian 13's 6.12 kernel is ABI 6) + seccomp to itself before exec (nanodregg's CLIENT-48, `redregg/work/promo/DESIGN-SANDBOX.md`), so the units take the plain hardening contract (RestrictNamespaces, ProtectKernelTunables, ProcSubset=pid, RestrictSUIDSGID, `@system-service @sandbox`) with no user/mount/pid namespaces, no `openat2` dependence (bwrap 0.12 died under systemd's sxid filter), no pinned bwrap copy | M |
| C8 | Performance beyond the bar: in-process codec (~68% of a read), the serial Host submit profile, STOP's re-hashes, room create 262 s | M each |

## 4. Rules for the prefix (binding on every lane brief)

How lanes, the orchestrator, the boxes and the cadence work is [`docs/COORDINATION-2026-10-27.md`](docs/COORDINATION-2026-10-27.md) §3–§6
(2026-10-27; it replaced the seven rules that stood here). Three rules are specific to this prefix
and stay here:

1. Rescue, repair, delete, in that order; "delete the twin" keeps and repairs the better one.
2. Every lane's deletions are named in its brief; the first deletion commit lands within a day of the
   lane's repair going green; `scripts/gates/host-closure.max` (one number) refuses growth of the Host
   closure.
3. Lean interface changes land first and rebuild early (on `dregg-build`); no statement packets for
   code being removed; only a lane's top-level theorem must be non-vacuous.
4. Rehearsals ship on the day with reds named; the opening waits for the §1 contract and
   nothing else; the gate is the tour plus the composed scenario and never grows ahead of the
   surfaces; standing rows are nightly and never a candidate's reds.
5. One root per project; resume the agent that holds the context; no censuses or ledgers
   unless they unblock the ship; every lane brief carries the system framing, the report
   sections, `path:line` pointers, the worktree and branch, and the verification it must run.
6. Engineering decisions are made by the orchestrator after a multi-model synthesis; only
   money, dates and credentials go to ember.
7. `swarm-build` around every build (COORDINATION §5 says which box); named-file commits; no `git stash`;
   no pattern kills; filtered tests only. The per-lane isolation, no-foreground-wait and reader rules are
   COORDINATION §3's, and the integration cadence is §4's.

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
backup retention defaults to 7 days after shutdown. **Mainnet** for pay-to-enrol (ember, 2026-10-27
morning; two mainnet providers; the sponsor's total cap and per-stranger funding amount are the door's
configured values, published on the join page). The oracle lands as a grain if it can be got away with
(ember, same morning). **The app market ships a curated, agent-hackable set** (ember, same afternoon: "a
more comprehensive selection of SPK apps than just etherpad … easy but powerful datamodels … because
agents will be running ham beneath the human-visible html layer"): two to three dozen apps (ember, same evening: "way more apps … like 2–3 dozen"), the featured 13 first, chosen for the data
model and API a resident can drive beneath the HTML, each proven by the lifecycle rows plus one
beneath-HTML write; selection evidence `docs/review/2026-10-27-spk-selection/`; L13 owns it. **fn is out of this demo** (ember, same evening: "fn is not yet ready"; the page says so; the `exchange` row stays UNCONFIGURED by name). **The `bend` verb is in** (Objective Bend authoring on the activity route with its derived form; the untouched-areas deputy builds it). **No daily restore drill** (the one at each ship is the infra lane's). **private-backend stays in the tree** (ember, same evening): the substrate rescues (pinned execution as one copy, the gated Lean codec fixtures, the crash WAL repaired and promoted, the capsule's key epoch bound) now; the in-process four-party MPC as a research-labelled door after the opening; a networked MPC service is weeks away (no transport, no release law) and not before 11 Nov. **The policy text** on the join, subscribe and export pages, with a research-consent checkbox at the door recorded as a member fact and honoured by the teardown (consented worlds exported, age-encrypted, into the backup bucket's `research-cc0/` prefix for ember's own privacy review before any release, eventually on HuggingFace; the rest deleted): "Nothing you make here is retained after the 11 November 2026 deletion, except encrypted backups that expire within 22 days and cannot be opened by anyone but the operator, unless you tick the box to contribute it for research, in which case you dedicate it to the public domain under CC0; we keep contributed data privately and release it, if at all, only after a privacy review. That choice is recorded in your world and shown on your export page. When you use the AI features, your prompts and the documents the agent reads are sent to the model provider (OpenRouter, or Z.ai on the subscriber tier) under their terms." **A subscriber tier** (its house Hermes on glm-5.3-flash: ember, 2026-10-27 evening) (ember, 2026-10-27 afternoon): a flat 4000 DREGG per month
(the price exists to stop spam) buys a generous Hermes allowance on GLM models (glm-5.3, glm-5.3-flash)
through ember's Z.AI coding-plan key, whose weekly quota is large and underused and holds three one-time
resets valid to 2026-12-22; built as existing machinery (a `subscribers` room whose concierge grants the
GLM provider-route capability for 30 days on `pay subscribers 4000`; L4 builds the Anthropic-messages
adapter and the row; infra seals the key; the web lane the Subscribe form). Whether the coding plan's
terms permit serving third parties' agents is ember's call, flagged; the join page carries the sentence
ember supplies. The 1Password state bundle is re-saved in a few days when the state stabilises.
Main advances after every integration round; other sessions' work in the shared worktree is committed
as found and fixed forward.

## 6. What this file is not

It is not a claim that any of it has run. Phase 0's re-run, each rehearsal's gate verdict
and the live node's health say so, in that order.
