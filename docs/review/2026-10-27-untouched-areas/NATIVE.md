# The native and script areas the sprint never touched

Scout report, 2026-10-27, worktree `lane/glm-native-scout` off `origin/main` 7151d2bf. Method: each
area's self-description, its callers (`rg -l` over Cargo.tomls, scripts, deploy units, journey rows),
`git log -1` per path, and one `cargo check` per crate (`CARGO_TARGET_DIR` in the worktree; no test
suites). Compiles-green: signed-api-path (0.6 s), compatible-upgrade-custody (4.8 s),
inference-scheduler (2.2 s), private-backend (25 s, 7 warnings). Verdicts are RESCUE / REPAIR /
DELETE / MOVE per the triage ruling.

**The headline: "untouched" is not "dead".** Three of the five native crates are load-bearing
dependencies of shipped surfaces; most script families are live gate machinery. What the sprint
actually left behind is two stranger-facing surfaces (fn, Objective Bend), one unit list that quietly
dropped three services, and two MOVEs already scheduled but never executed.

## Native crates

### private-backend — MOVE (already scheduled; execute it)
- **What:** reference asynchronous MPC protocols — PrivSend, ASKS/IndexGather/VABA/ACS, dZK, ACSS-Id,
  Sh2t-Id, TripleKing, claim codecs — with its qualification limits stated in its own header
  (`native/private-backend/CONSTRUCTION.txt:1-40`). 28,993 lines, its own `[workspace]` and Cargo.lock.
- **Who calls it:** nobody in the tree. Excluded from the workspace with the reason on the line:
  "research crate leaving for degg-research (DEMO-PREFIX R5)" (`Cargo.toml:32-34`). The pipeline runs
  four of its focused checks (`scripts/check-rust-tests.sh:175,484,525,530`).
- **Last substantive:** a102f980 2026-10-04 (Gather ACK quorum adversary).
- **Compiles:** yes.
- **Verdict MOVE.** R5 says it; nothing demo-facing depends on it. The move is a directory transplant
  plus re-pointing four check lines — half a day that removes ~29,000 lines from the demo tree and
  makes the next sweep honest.

### inference-scheduler — RESCUE at re-genesis (not a stranger surface today)
- **What:** shared homelab inference placement — allocates physical inference capacity among Mini
  controllers; receives digests and bounds, never prompt text; no API keys, no ledger
  (`native/inference-scheduler/README.md:1-16`).
- **Who calls it:** `native/grain-runtime/Cargo.toml:25` (the provider/homelab bridge,
  `src/homelab.rs`, `src/provider.rs`); the binary ships in every candidate
  (`deploy/candidate/package.py:55,80`); its core test runs in the pipeline
  (`scripts/check-rust-tests.sh:545`).
- **Last substantive:** 3f9eb1b4 2026-10-27 (README rewritten to say what deploys it).
- **Compiles:** yes.
- **Verdict RESCUE — but the surface is pug, not the demo.** The demo's residents reach the GLM
  provider route over the operator's provider table; the scheduler is the placement broker for the
  homelab fleet after re-genesis (helm's substrate). Smallest wiring step at pug: the README's own
  unit (`/etc/mini/inference.json`, 0700 state dir, control socket) plus one journey row running a
  resident through a homelab row. Nothing is owed for the opening beyond not uninstalling it.

### signed-api-path — wired and load-bearing (no action)
- **What:** exact routing under an SPK's signature-verified legacy HTTP API prefix; deliberately
  authority-free (`native/signed-api-path/src/lib.rs:1-4`). 159 lines.
- **Who calls it:** `native/grain-runtime/Cargo.toml:24` and `native/spk-host/Cargo.toml:34` — the
  routed reserve-HTTP path every grain's application API call goes through
  (`native/grain-runtime/src/application_api_tools.rs:185-215`) and the agent-API-v3 custody binding
  (`native/spk-host/src/agent_api_lifetime_server_v3.rs:90,145`). That is tour step 7 (apps on their
  own origins) underneath.
- **Last substantive:** 295cab11 2026-10-08 (M7 candidate reproduction). **Compiles:** yes.
- **Verdict: already rescued by construction.** The journey row that proves it is the app row
  (`japps.sh` installing two real SPKs, L13). Record the fact and move on.

### compatible-upgrade-custody — REPAIR (one unused dependency)
- **What:** trusted local root admission for a compatible Mini image transition — authenticates
  operator custody and exact pins (`native/compatible-upgrade-custody/src/lib.rs:1-2`). 369 lines.
- **Who calls it:** `native/spk-host/Cargo.toml:21` (and the `fixture-os` feature at `:18`),
  `native/grain-runtime/Cargo.toml:26`; it backs the required `hostupgrade` row
  (`scripts/pipeline/required-rows:68`) and `deploy/spk-host/PROFILE-UPGRADE.md`.
- **Last substantive:** 81cecae5 2026-10-07 (OS boundary seam). **Compiles:** yes.
- **Defect:** `native/resource-client/Cargo.toml:18` declares this dependency and the crate's source
  never names it (rg over `native/resource-client/src` finds no `compatible_upgrade` — the only
  "compatible" strings are `openai-compatible` provider kinds). Either the client-side upgrade verb
  never landed or the dep is dead weight: drop the line or wire the verb. One-line fix, name it now.

### objective-emit — REPAIR (one PENDING authority; otherwise alive)
- **What:** not a crate — the Objective Bend differential harness: C differential, mutant generation,
  transparency replay, cohorts (`native/objective-emit/`: `differential.py`, `cdiff-mutants.py`,
  `transparency.py`, `runtime.c`, cohort JSONs). The compiler's evidence machine.
- **Who calls it:** `scripts/check-objective-proofs.sh:11-23` (stages c, cgen, mutants, transparency).
- **Last substantive:** d74947d2 2026-10-26 — deletions only, which is what "untouched" measured.
- **Verdict REPAIR:** the one open item is its fixture authority, still `PENDING`
  (`scripts/pipeline/fixture-authorities.txt:21`). Convert to `checked` or archive the fixtures.

## Script families

Most of the ~13,000 "untouched" script lines are **live gate machinery** — the sweep's file-count
method counted them untouched because gates are stable, not because they are dead:

- **kn2** (44 files): api-faults and coprocess-faults run in every merge gate
  (`scripts/pipeline/merge-gate-checks.sh:99,103`). A caller-less member was already deleted
  (9bb11984 2026-10-27). Keep.
- **plants**: journey rows build patched Hosts from `scripts/plants/domain-blind.py` and
  `drain-blind.py` for the `call`/`drain-blind` rows (`scripts/pipeline/journey-rows:176,192`). Keep.
- **ports**: the full-loaded ratchet is a merge gate (`merge-gate-checks.sh:96`). Keep.
- **grain-birth + workroom**: the spk-platform grain journeys source
  `scripts/workroom/provision.sh` and `scripts/grain-birth/native-share-member.sh`
  (`scripts/spk-platform/grain-store.sh:21,49,112-128`). Keep.
- **burst**: hbox pull/build plumbing (`scripts/pipeline/box-env`, `fetch-artifacts`). Keep.
- **native-accepted-fixture**: its authority is `checked` (`fixture-authorities.txt:17`). Keep.
- **consent**: `own-base-plant.lean` is a full-loaded caller
  (`scripts/ports/full-loaded-callers.txt`). Keep.
- **fn-e1e2 + fn-b3**: the two-Store fn research drivers. They are hbox-fresh-gate fixtures
  (`scripts/fn-e1e2/README.md:8-9`) and the evidence base for the fn surface below. Keep, and see the
  fn plan: they are the seed of the demo row, not scrap.
- **terminal** — DELETE. `drive.sh` and `frame-probe.rs` have no caller newer than
  `docs/evidence/2026-09-26-terminal-recovery`. The kept twin is the L12 web terminal (xterm.js pane,
  its own drivers under `native/mini-web`).
- **provider-services** — REPAIR. `Check.lean` is the unbuilt half of JPAY6 (known-red; commit
  5fb20bc5 says "UNBUILT"). It is owed consent-lane work, not deletion.

## Directories

- **examples/** (objective-bend-world), **testing/** (agreement-carrier, journeys),
  **tests/** (consent, objective-*): consumed by `scripts/check-objective-examples.sh`,
  `check-objective-frontend.sh`, `check-world-cohorts.sh`, `check-objective-proofs.sh`. Live. Keep.
- **benchmarks/** — MOVE. `bounded_page_materializer/` holds two raw 2026-08-11 bash logs and nothing
  else; `forward_link_e2e/` is cited only by `docs/review/2026-10-26-native-crates/`. Measurement
  residue: move under `docs/evidence/` with its review links, or delete once the reviews cite the
  moved path.
- **coordination/** — MOVE. A wall-time WIP snapshot committed as-is (008fd5e7 2026-10-03), self-tested
  only (`scripts/test_lean_scoped_dag.py`), superseded by the docs-only coordination rewrite. Goes to
  the research repo with private-backend.

## Deploy units

- **deploy/clock** — wired. `mini-clock-tick.service/.timer` are in both the old and door-era demo
  unit lists (`deploy/door/infra/dregg-infra.patch:214-216`) and the infra patch adds the clock note
  at `:276`. The clock subject ticks; `mini clock` is its client. No action.
- **deploy/checkpoint** — REPAIR. `mini-checkpoint-certify.service/.timer`
  (`ExecStart=… checkpoint --action certify …`, `deploy/checkpoint/mini-checkpoint-certify.service:24`)
  are in no install list; the demo runs `mini-backup.timer` instead. The restore drill is a script,
  not a cadence (blind spot B9). Smallest step: enable the certify timer beside the backup timer and
  surface its digest in the operations room (door 13).
- **deploy/grain-host** — RESCUE at pug. The Linux launcher for a `grain-runtime` worker host
  (`deploy/grain-host/README.md:1-3`), sourced by the spk-platform journeys. It is the homelab grain
  worker path for after the demo, alongside inference-scheduler.
- **deploy/hermes-dispatch** — REPAIR (reconcile). The registered-delivery bridge
  (`mini hermes-handoff`, `native/resource-client/src/hermes_handoff.rs`; README rewritten today).
  The door-era infra patch **dropped** `mini-inference.service`, `mini-hermes.service` and
  `mini-hermes-dispatch.service` from the install list (`dregg-infra.patch:214-216`). Step 5 of the
  tour needs a live resident: name which delivery path the L4/ACP controller actually uses, then
  either install the dispatch unit or delete it as the superseded twin. Do not let the unit list and
  the spine disagree through the opening.

## Surface: fn and the second node

**What "fn on the demo" means for a stranger:** a post leaves `demo.dregg.online` over NNTP to a
second Mini node on another machine, is admitted there as an event13 under a release law, and a reply
arrives back — one visible round trip with receipts on both ends. Not "a loopback exchange works".

**What exists:** the receive worker as a hardened unit (`deploy/fn/mini-fn-receive@.service`,
timer every 5 min) that runs `mini selected-exchange --phase receive-transport` against the local fn
node's control socket, with exact-retry semantics and no network in the unit — "the NNTP leg between
machines is fn-to-fn peering on 119/563, which fn's own unit owns"; the `selected-exchange` CLI
family; the required row `exchange` (`scripts/pipeline/journey-rows:837-877`), which needs two
pipeline inputs, `MINI_FN_LAUNCHER` and `MINI_FN_CORE` (`:840-841`) — the frozen fn image the row
wants and dregg-build lacks — and asserts a loopback shape (`.localFn.host=="127.0.0.1"`, `:869`);
the plan's L8 lane (fn-r route, one NNTP repost rule, ops 13/15 operator-only, `docs/DEMO-PREFIX-2026-10-26.md:259`); and the research drivers above. AFFORDANCES 1.7: tamper/wrong-signer/wrong-root refused, exact retry replays — but fn-e verdicts, event17 cover and the cursor ACK are not covered, and nothing crosses two machines.

**Smallest honest plan to be on by the opening:**
1. Build the frozen fn image once on dregg-build from the fn repo's pinned qualified source (fn-b3's
   README names e160442f) under `swarm-build`; register the two `MINI_FN_*` inputs. The standing
   `exchange` row goes from UNCONFIGURED to green on loopback — that is the gate, and it is honest
   about being one machine.
2. Run the fn node on dregg-demo (fn's own unit owns 119/563) and the `mini-fn` receive user per the
   service header's setup block.
3. The second node runs **on dregg-build (ccx33)** — already ours, dies 11 Nov with the demo, no new
   spend: a minimal second Mini Store with its own genesis and distinct domain (the row's own shape)
   plus a peered fn node and `mini-fn-receive@NAME.timer`.
4. One operator-selected post (the tour's welcome document is the natural one) published from the
   demo box, admitted at the second node, and a reply release published back; shown as a line in the
   operations room and a receipt in the public stream, labelled with what is not covered (fn-e
   verdicts, event17, cursor ACK).
5. Prove it with one new demo journey row (`exchange-remote`), asserting the two-machine article, the
   refused tamper control, and the exact-retry replay — the loopback `exchange` row stays as the
   standing gate.
Fallback if the image build stalls: keep fn loopback-only and say exactly that on the page. The
dishonest versions are implying a network leg that is not there, or letting the required row stay
UNCONFIGURED silently.

## Surface: Objective Bend authoring

**What exists:** the whole language — front end, Core4 checker, demand machine, native admission with
byte-identical re-run and declared-envelope tariff (`docs/OBJECTIVE-BEND.md:1-17`;
`Kernel/ObjectiveBendNativeAdmission.lean`) — and two routes: Route A, `mini objective-invoke`, which
requires **a local native Host binary as a subprocess** (`native/resource-client/src/objective_invoke.rs:16-18`
— an absolute `--host` path, not the deployed socket), and Route B, the activity kernel, which goes
over the deployed socket (`activity.rs:66`, `session_invoke`; public ops 210-219, AFFORDANCES 1.13).
The `objective` journey row runs on scratch worlds (`journey-rows:81-87`). No shell verb, no SDK
wrapper, no web form, nothing deployed.

**Smallest verb and form (recommended, about a lane-day):** a `bend` shell verb riding Route B, which
is already socket-wired and required-row-proven: `bend new` pastes or uploads `.obend` source and
publishes it as a document; `bend run` wraps activity create/birth/invoke and shows the one outcome
partial — admitted effect, height, root, tariff charged from the invoker's purse; a malformed source
shows the front end's refusal like any clause. The web form is one no-JS textarea + Run, derived from
the verb registry per the parity ruling. The honesty labels: the invoker pays the declared envelope,
not measured work; the demand machine's outputs are Plans, calls and activities — no I/O, no digests.
Journey row: `jbend` — author one bend, run it, see the admitted append and the charge, then one
refusal.

**The stay-out sentence, if no lane takes it before the opening:** "Programs a member writes run in
the kernel today only through the activity route; the `.obend` authoring face is the CLI against a
local Host, and is not on the demo." Say that on the laws page rather than leaving the surface
unmentioned — ember's ruling is that "later in the week" never means "out".

## The five that matter

1. **fn on the demo = the second node.** Build the frozen fn image on dregg-build (un-UNCONFIGURE the
   required `exchange` row), peer 119/563, run the second Store on ccx33, and show one honest round
   trip. The only missing stranger-visible surface with all its parts already written.
2. **Objective Bend's `bend` verb + form on the activity route** (ops 210-219 are public and
   required-row-proven; the verb is thin), or the stay-out sentence on the laws page — decide which
   before the opening.
3. **The demo unit list dropped three services** (`mini-inference`, `mini-hermes`,
   `mini-hermes-dispatch`, `dregg-infra.patch:214-216`) while step 5 needs a live resident. Reconcile:
   which delivery path does the L4 controller use? Install it or delete the superseded twin.
4. **The checkpoint certify timer is unwired beside running backups** — enable it and feed door 13;
   it is also blind spot B9's cadence.
5. **Execute the scheduled MOVEs:** private-backend → degg-research (R5), coordination/ and the
   benchmarks logs out of the tree — ~30,000 lines of "untouched" that should stop being in the demo
   tree, plus the one-line unused-dependency fix in `resource-client/Cargo.toml:18`.
