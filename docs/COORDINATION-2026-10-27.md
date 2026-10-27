# How minidregg is developed (present state, 2026-10-27)

The one description of how this project is coordinated. It is rewritten whole when the state
changes, never appended to. It replaces the process parts of `CLAUDE.md`, `AGENTS.md`,
`docs/PIPELINE-HBOX.md` and the plan's §4 (`docs/DEMO-PREFIX-2026-10-26.md`), and the dated
orientation documents named in §7. Ember's ruling that it answers (2026-10-27): "We've been
accepting various limitations and restrictions as if they are a fact of life … please stop
accepting these things. We need to pursue development rapidity and product excellence and that
includes taking a critical eye to the 'gates' we are trying to achieve."

## 1. What we optimise

**Development rapidity and product excellence.** The one gate that matters to anyone outside this
tree is the demo's public-opening contract (plan §1: advertised surfaces work, tenancy holds,
uncertain effects recover safely, performance is measured and published). Everything else in the
apparatus is instrumentation: it exists to tell us something true, faster than a stranger would,
and it is judged by that. An instrument that costs a commit per landing, or an hour of a lane's
day, or that goes red on ordinary edits, is measured against what it has ever caught; when the
answer is "its own bookkeeping", it goes.

**Performance is published, never a gate** (ember, 2026-10-27). Numbers go on the join page and in
the plan; they never block a rehearsal or the opening. One consequence is already measured: the
journey's 57 s `growth` outlier on hbox was 80 client fsyncs inside a co-tenant I/O episode on an
HDD mirror with no SLOG (disks 69 % busy, load 22); the same write on the demo box's SSD is p50
1.35 s, max 1.56 s. hbox's `/tank` measures disk contention, not Mini (§5).

The measured shape we are leaving (`docs/review/2026-10-26-history/HISTORY.md` §4): 61 % of 222
lane-hours spent waiting; 0.86 commits per lane-hour; 89 gate-bookkeeping commits on one day;
"delete" the most expensive move a lane could make; the deploy that was batched behind a composed
gate that never went green. The rule that follows: **the gate never grows ahead of the surfaces**,
and nothing is added to the apparatus without naming the landing cost it adds.

## 2. The gates, triaged

Every gate, pin, census and ledger in the tree, with what it protects, what it has cost per landing
(October's history), and the verdict. KEEP = strong, end-to-end, cheap. FOLD = merged into one
cheaper check or moved to the nightly. DELETE = bookkeeping that measured itself. The DELETE and
FOLD rows marked ✓ are executed in this document's commit series; the Lean axiom pins are KEEP.

| instrument | protects | cost per landing (Oct) | verdict |
|---|---|---|---|
| the demo journey rows (`scripts/pipeline/journey-rows`, `required-rows` names; J0–J8, m3/m4, hermes, jpay, exchange, hostupgrade…) | the opening contract's part 1, on a fresh Store | one standing run (~15 min), the nightly's | **KEEP** as the nightly's rows; a candidate's gate is the tour (§6) |
| `jdeploy3` + `ship.sh --rehearsal` (dregg-infra) | the candidate that ships ran its journey, world and composed scenario; reds named | one run per candidate | **KEEP**; growth/perf/births rows non-blocking (plan §1.4) |
| the workspace membership gate (L9) | every crate builds or is excluded by name; ran-from-passed | seconds | **KEEP** |
| `lake build` umbrella / `build-native-host.sh` | the tree elaborates; the Host links | the build itself | **KEEP** (it is the work) |
| `host-operations` registry check | request bytes ↔ Host receivers ↔ routes | seconds | **KEEP** |
| `import-boundary` (`check-import-boundary.sh`) | `Theory/`, `Selvage/` candidate-independent | seconds | **KEEP** |
| wire-byte controls: `fn-wire` (pinned BLAKE3 grammar), codec identity (`codec-shapes-regen.py`; 4 `codec!` bumps Oct 16–17), `prover-glue`, `drift`, `native-transcripts`, `zkml-suite-artifact`, `kernel-transport` | persisted bytes and emitted twins never move silently | a re-emit commit only when a persisted identity really changes | **KEEP**: that commit is the honest cost of a wire change |
| Assurance axiom pins (`#guard_msgs … #print axioms`, 4,257) | a proof's axiom footprint is where it is stated | re-pin only when a footprint moves | **KEEP**: cheap and honest |
| `proof-hygiene`, `build-closure`, `exports` (3-row allowlist), `shell-paths` (4-row allowlist), `unit-tests` floors, `cold-start`, `axiom-census`, `world-sim`, `rust-tests` (filtered rows), `spk-shell`, `deploy-scripts`, `objective-frontend`/`world-cohorts`/`objective-examples`, `canonical-policy-portal`, `tower-controller`, `audit-corrupted-leaf`, `website`, `fixture-authority` (git-only) | each a named, cheap, end-to-end property | seconds to minutes, no ledger churn | **KEEP** |
| `objective-c`, `objective-cgen`, `transparency` | the C machine agrees with `runBounded` | minutes; need bun | **KEEP until R10**: they retire with `runtime.c` |
| `check-host-closure.sh` + `host-closure.pin` (841 lines) | the Host does not silently grow | re-pinned **53 times since Oct 1**; red on every edit that adds or removes a module | **FOLD ✓** → `host-closure.max`: one number, refuses growth, `--update REASON` moves it |
| the known-red ceremony (`known-red-verdict`, `known-red-modules`, `known-red ROW CV-TASK` lines, landing.sh's cv-task demand) | a red is owned | **10 commits** to required-rows/known-red since Oct 1; a base refused when a listed module *builds* | **DELETE ✓**: reds are named in the run's output; a pre-existing red prints PRE-RED and blocks nothing; the lane brief names the owner |
| the Objective contract manifests (`scripts/gates/objective-manifest/` 610 files, 42,711 rows, 32 MB; `objective-contract-decisions.txt` 9,011 lines; `objective-manifest.py`; two scanner scripts; `Verify/ObjectiveManifest*.lean`) | a restated theorem is noticed | **33 commits since Oct 1** ("531 events, each with its reason"; "1334 events"); two full scanner elaborations + six planted copies per gate run | **DELETE ✓**: the axiom pins and the build keep what mattered; a restated top-level theorem is caught by its adversarial audit (statement-first) |
| `guard-discipline` (655-line checker + baseline) | `#guard` counts only fall | ~2 s, a self-test, a ledger | **DELETE ✓**: the count is 0 |
| waste-model (`check-waste-model` 439 lines, fixture, decisions, `WASTE-MODEL.md [deleted 3b2aa109]`) | instruction-count ceilings per journey step | a decisions line per raise | **DELETE ✓**: performance is published |
| hypothesis ledger as a gate row (`check-hypothesis-ledger.sh`, empty baseline, the `ledger` job) | no vacuous / toothless statement families | builds `AxiomCensusResearch` + a ledger run per landing | **FOLD ✓** → on demand before a research move (C2); only a lane's top-level theorem must be non-vacuous (plan rule 3) |
| `TokenCensus` (+ fixtures, plants, defects ratchet), `scripts-elab`, `char2-vacuity` | private tokens minted at home; every script elaborates; no empty-carrier quantification | elaborates the research umbrella per landing | **FOLD ✓** → the nightly on `dregg-build` (§6) |
| carrier census + `check-repository-trust.sh` | "521 unwitnessed carriers is today's honest number" | a census that gated only itself | **DELETE ✓** |
| `check-objective-machine-perf.sh` | a perf floor | wired to nothing | **DELETE ✓** |
| rust-tests/unit-tests `known_red` rows (a test "must still fail") | ran-from-passed on a known failure | one row each; red the day it passes | **FOLD**: delete each row with its fix; add no new ones (name the red in the run instead) |
| `journey-unbuilt.tsv` (one row: M6) | a pinned step that passes is noticed | one line | **DELETE** with L9's `m6.sh` (the row vanishes with the reason) |
| required-rows `pending` lines (`births`, `HERMES-LIVE`, `jcertify`) | the opening contract's not-yet rows | none | **KEEP** (they are the contract's names) |
| `instruments.tsv` (which self-tests run when) | a changed instrument re-proves itself | none | **KEEP**, shrunk to the instruments that remain |

What a landing costs now, per the gate scripts after this commit series: the umbrella (warm,
minutes) and the cheap end-to-end checks; the tour and the standing rows belong to the candidate and the nightly (§6). No per-landing pin
regeneration, no decisions ledger, no census of the research tree, no accepted-red list.

## 3. How a lane works

- **One worktree per lane, on a `lane/<name>` branch**, under `/Users/ember/dev/minidregg-lanes/<name>`
  (or `/build/lanes/<name>` on the build box). Never the main worktree; never `git stash`; named-file
  commits with prose messages via `git commit -F <own-file>`.
- **The brief carries**: the system framing (what the lane changes and why it is on the critical
  path), the exact report sections, `path:line` pointers to every file it touches, the deliverable,
  the verification it must run and where (§5), the deletions it owns (plan rules 1–2), the current
  `/build/CANDIDATE-*.md` and the standing world (below), and the isolation lines (below), the
  last quoted verbatim.
- **Think ahead; run a check once per coherent batch.** A lane does not rerun a build to see what
  changed; it reads the first run, plans the whole fix, applies it, and runs again. One build per
  batch, filtered tests only (`-E 'test(<pattern>)'`), never an unfiltered suite.
- **Lean is REPL-first.** Each edit is checked with `lean-ask check <File.lean>` on the box (`--reload`
  after a fetch or rebase; never a bare `lake env lean` then: it reads stale import oleans) or, on the
  Mac, `lake env lean <file>` when its `.lake` is warm (§5). The Host closure builds once per batch,
  not per edit.
- **Linux checks run where Linux is**: `ssh dregg-build`, a worktree under `/build/lanes/<lane>`,
  `cargo nextest run -p <crate> -E '...'`, `lake env lean <file>`, every build under `swarm-build`.
  There is no more "owed to hbox": a lane that cannot run something on the Mac runs it there
  itself. What truly cannot run anywhere the lane reaches (a demo-box drill, a mainnet pay) goes in
  the lane's **BATCH FOR THE PARENT**, one list at the end of the report, not a message per item.
- **A lane runs its own rows.** Its brief names the current candidate (`/build/CANDIDATE-*.md`) and
  the standing world (`world-up.sh` / the world template); the lane re-runs the rows it owns against
  that candidate and world itself and reads the result, rather than handing a tip to the integrator
  and waiting for a relay (nine such round trips cost about 57 min each).
- **Box runs never hold a turn.** Start the job detached on the box with a PID file
  (`nohup JOB > job.log 2>&1 < /dev/null & echo $! > job.pid`), then make ONE background call,
  `scripts/pipeline/box-wait --pid /build/lanes/<lane>/job.pid --show <log> --cmd '<verdict lines>'`
  (Claude Code: `run_in_background`), and do the next batch meanwhile; its completion is the wake-up.
  The wait runs on the box inside one ssh session, reconnects if the session drops, and reads the PID
  without ever signalling it. No PID file, no wait (it exits 2 and says so). Never a foreground
  `for i in $(seq …); do sleep …` loop: the 10-minute cap re-woke a full context 63 times.
- **One journey run reports every red, and one red step reruns alone.** The standing rows run
  `journey.sh` with `JOURNEY_KEEP_GOING=1`: a step whose dependency failed still runs and its detail
  names the failed dependency (a failed J0 still blocks: no world, nothing to run). To rerun one step,
  `journey.sh --only STEP [--only STEP2] MANIFEST NEW_ROOT` runs it and exactly its dependency closure
  (read from the script's own `run_step` lines), in minutes rather than the whole journey's hours.
- **Reader discipline.** No whole-file `Read` over 2,000 lines (read ranges, or `rg` first); notes
  are written to the lane's scratch directory as it goes, not held in context; a synthesis over many
  documents runs in a fresh lane over the notes' summary sections, never in the lane that read them.
- **Isolation, quoted in every brief:**
  - `export CARGO_TARGET_DIR=<the lane's own directory>` (`$DEST/rust-target` on the box); never
    another lane's or the shared one (three lanes hit another's stale build).
  - Scratch files live in `<lane dir>/scratch/` (commit-message files uniquely named, e.g. `<lane>-msg-<n>.txt`); never
    a bare name in the shared scratchpad (a lane overwrote another's `msg1.txt`).
  - Every process a lane starts gets a PID file (`… & echo $! > <lane dir>/<job>.pid`); it is stopped
    by that PID and nothing else. No `pkill -f <anything>`, no `pkill -x <bare word>`, no `killall`,
    no `kill -u`. No PID file, no kill: tell the parent.
  - No "was it red before me" runs. A red is named in the run's output; the lane fixes what its
    change touches and does not stash, revert or re-run a baseline to learn the history of the tree.
- **Decisions are taken by default and recorded**, in the report, in system terms; questions are
  batched into the same list. Only money, dates and credentials go to ember (§4).
- **Finish fast, push, report in ≤ 20 lines**: what landed (branch tip), what was verified and
  where, the reds by name, the batch for the parent. A lane reports on events (a batch done, a red,
  a block, a handoff), never step by step.

## 4. How the orchestrator works

- **One root per project.** minidregg's root does minidregg; fn and nano have their own sessions
  and cwds (HISTORY §4.5: Mini went dark exactly when its launch was due).
- **Veterans are resumed, never respawned.** The agent that diagnosed a failure fixes it; a
  successor is spawned only when context is the problem, and then from the predecessor's own
  continuation file.
- **Distill at 400k, not at death.** The token curve bends there (58 % of tokens were spent above
  it; four lanes died of context). `cv distill --keep-last 10` for code lanes, `--keep-last 14` for
  box and infra lanes (their last calls carry live PIDs and candidate paths). Hub lanes rotate per
  task cluster whatever their size.
- **Before any swarm, the permission allowlist is in place**: write-side heredocs and `git`/`ssh`
  in lane worktrees, applied once with `fewer-permission-prompts` (one unanswered prompt held a lane
  164 min; the class cost about 3.2 lane-hours).
- **Phase transitions are pre-authorised.** When a phase completes and the next has a default, the
  root launches it and tells ember afterwards; it does not end its turn to wait (one such wait idled
  the fleet 2 h 58 min). Only money, dates and credentials stop it.
- **A multi-model council reads any ruling before it reaches ember**, as the plan's council did
  (`docs/review/2026-10-26-council/`). Engineering decisions are the orchestrator's after that
  synthesis; **only money, dates and credentials go to ember**, stated in system terms with the
  default that applies while she is away.
- **Integration is continuous; there is no cut cadence** (ember, 2026-10-27 night: "DELETE THAT RITUAL").
  A lane's per-file-checked work lands on main the moment it is pushed: the lane merges origin/main into its
  branch and the integrator merges the branch into main at once (fast-forward where possible), in
  dependency order only when two land together. `dregg-build` builds main continuously and incrementally on
  a warm tree (whatever is newest when the previous build finishes), and the gate runs on the newest built
  main; reds are named within minutes with file:line and owning lane and fixed forward. A "candidate" is
  simply the newest built main that passed the gate. Work found in the shared worktree is committed as found.
- **Rehearsal ships when ember says**, from the newest gated main, with reds named (`ship.sh --rehearsal`; re-genesis is free);
  the opening waits for the §1 contract and nothing else (§6 states the gate).
- No status censuses, no reviews of reviews, no ledgers unless they unblock the ship.
- **Lanes may build and run again, warm and incremental, on a box** (ember, 2026-10-27 late night, lifting the earlier ban: "our snipers are allowed to do builds; they just need to make sure they are doing it somewhere warm and incremental"). A lane elaborates and builds only in a warm tree on dregg-ref or hbox (packages seeded, `build/` restored from a built tree by copy, never a cold build, never hard links), runs its own rows on its own world there, and stops its own processes by PID file. The integrator still merges into main, builds and gates main continuously, and fixes the reds it finds against its warm tree. Never search the filesystem from `/` or `~` (a whole-disk `find` for `*.spk` overflowed the Mac's file table and stopped every agent).
- **No Lean builds on the Mac** (2026-10-27 night: four concurrent lane builds put the Mac at 72 of 74 GB swap). The Mac edits, runs `cargo check` and filtered Rust tests; every `lake build` and every large elaboration runs on dregg-ref (lanes, through `closure-lock`) or is the continuous main build on dregg-build. Each lane and faerie works only in its own worktree.
- **No lane waits on its own closure build** (ember, 2026-10-27 night: "we need to avoid having the dependence on these closure builds"). A lane per-file elaborates its changed files and their direct importers, pushes, and moves on; the continuous build of main is the closure, and its reds are named within minutes and fixed forward by the owning lane. A lane's own closure runs only in the background (dregg-ref, closure-lock) when a change touches importers it cannot check per file. The iteration-speed lane is replacing per-file batch checks with a live Lean server per lane and Lean 4.30's module system.
- **One Lean closure per box at a time; the cut's is on `dregg-build`, the lanes' on `dregg-ref`.**
  `dregg-build` builds main's Host closure continuously; a lane elaborates per file (`lean-ask`,
  `lake env lean`) and runs its closure on `dregg-ref` through `closure-lock swarm-build <cmd>` (one closure at a time on the box, `closure-lock --who` names the holder; the nightly at 00:03 UTC and M7's reference build hold the same lock; seed only `.lake/packages`, never a hard-linked `build/`) (the lanes' second Linux box, shared with
  nanodregg's announced measurement windows: ember, 2026-10-27 evening, "USE all these machines while we
  have them"), or on the Mac's warm `.lake`, or waits for the cut (2026-10-27
  afternoon: four concurrent closures put the box at load 25 and a cut's host build was killed by
  memory). A lane that needs a box closure asks the orchestrator for the slot after the cut's host stage.
- **Design the whole change before the first build.** A Lean change that adds a kind, a field or a
  frame is planned from the import graph and `rg` over every exhaustive site and downstream match first,
  written as one commit, and built once; iterating "build, fix the next error the compiler names, build"
  is the loop the audit measured. The same for a journey: one run with `JOURNEY_KEEP_GOING=1`, every red
  read together, one fix set, one confirming run.
- **Converge.** A lane whose piece is not on the opening contract (plan §1) stops after its current
  piece with a state file in the tree and is resumed after the opening; the box, the cuts and the
  orchestrator's attention go to the lanes that are. Every run's end stops its own servers (an EXIT trap
  on the PID file); an idle `mini serve` from a finished run is a leak, not a fixture.

## 5. Boxes

| box | what it is for | the one wrapper | never |
|---|---|---|---|
| **the Mac** | editing, `cargo check`, filtered unit tests that run on macOS, `lake env lean` only when `.lake` is warm | none | a Lean rebuild (its `.lake` is stale); an unfiltered suite |
| **`dregg-build`** (Hetzner `ccx33`, 8 dedicated vCPU / 32 GB, Debian 13, fsn1, `178.105.4.114`; dregg-infra `edge/tofu-build/`) | every lane's Linux checks (the fake Lean Host, `mini-spk-volume-helper`, broker fixtures, hermes), Lean builds, the integration build, candidates, the nightly (§6), **and every journey row that times anything** (`growth`, `births`, `perf`) on its SSD volume | `swarm-build <cmd>` (MemoryMax 28 G, swap 0, prints the build's peak RSS); Lean fan-out bounded by `scripts/build-native-host.sh`'s seats (`MINIDREGG_LEAN_SEATS=2`) | production secrets; any key to the demo box; the hcloud token; `pkill`/`killall` (stop by PID file only) |
| **hbox** | the pipeline's standing run and the warm base; co-tenant (nanodregg builds, codex's `poly`); a one-slot queue | `swarm-build` (there: 96 G cap, `taskset 0-15`) | a lane's default box; any timing measurement (`/tank` is an HDD mirror with no SLOG: §1) |
| **`dregg-demo`** (`ccx23`, `167.233.199.225`) | rehearsals and the opening; the box drills; the published performance numbers (the baseline is the demo's own: write p50 1.35 s, max 1.56 s at the measured level) | `ship.sh` from the Mac | a build; a credential for another box |

The first measured cold Lean build, on `dregg-build` at main `c77ef2f9` (the number three council
reviewers asked for): 1,308 modules (the 787-module Host closure plus the umbrella) in **7,197 s =
2 h 00 min** with 2 seats × 4 threads under a 28 G cap, cgroup peak 17.2 GiB, the heaviest module
18.5 GiB (`Kernel.PayEnrolReceiver`); mathlib from the cache in 77 s. With the measured RSS table the
same build runs at 4 seats. A warm `cargo check --workspace` is 22 s. Details and the table:
dregg-infra `edge/tofu-build/README.md`.

Teardown: `dregg-build` carries `expires = 2026-11-11`, the demo's shutdown date; `tofu destroy` in
`edge/tofu-build/` is the whole teardown. Disk pressure on any box is a pause-and-tell condition,
never a delete.

## 6. Cadence

- **Definition of done** = the public-opening contract holds on a rehearsal candidate (plan §1).
  Nothing else is "done" in a way the project reports upward.
- **The gate is the tour.** A rehearsal or the opening is judged by `jtour` (the web journey's rows
  driven against the candidate's own Host) plus the composed scenario, and by nothing else. The
  standing rows are the nightly's: they name their reds in the morning report and never name a
  candidate's (plan §1; ember, 2026-10-27: no row burndown). When a brief says "fix the rows", ask
  what a stranger would touch.
- **Integration is continuous** (§4); **rehearsal ships** when ember says, from the newest gated main, reds named.
- **The nightly** is the only scheduled run: the kernel journey (L9's split of the journey into a
  demo journey inside the gate and a nightly kernel journey), the timing rows (`growth` at 1000,
  `births` at 1000, the 10k soak when designed) on `dregg-build`'s SSD or the demo box, and the
  censuses folded out of the landing gate: `lake build TokenCensus TokenCensus.Fixtures`,
  `bash scripts/check-scripts-elab.sh`, `bash scripts/check-char2-vacuity.sh`. Its reds are named
  in the morning report; it blocks nothing.
- **No per-landing ceremony**: a landing is the umbrella green (or its reds named) and the cheap
  checks of §2. No baseline comparison, no ledger of accepted reds.

## 7. What this replaces

Superseded and deleted in this commit series (git keeps them): `GOAL.md` (the September standing
goal, 1,314 lines), `REORIENTATION.md` (August), `FORCODEX.md` (August), `WASTE-MODEL.md [deleted 3b2aa109]`,
`scripts/gates/objective-manifest/` and its decisions ledger, `host-closure.pin`, the known-red
scripts and lines, `guard-discipline`, `check-waste-model`, the carrier census.

Superseded and shrunk to a pointer here: `CLAUDE.md` and `AGENTS.md` (they now say only what is
true and point here), `PROJECT.md`'s "Work discipline", "Performance and evidence discipline" and
"Public-claim gate" sections, `docs/PIPELINE-HBOX.md`'s "Baseline-relative landing rule" and "The
bar per landing" (hbox is the standing run; the rule is §2's), the plan's §4 (this document's §3–§6
are the rules; the plan keeps the work).

Still authority: `ATLAS.md` §6 (the sixteen laws; law 8 "gate the gates" is why §2 deletes
instruments that cannot red-proof themselves, law 16 "one lane can hold it" is why §3 is one
worktree per lane), `docs/DEMO-PREFIX-2026-10-26.md` (the work and the opening contract),
`HANDOFF.md` (where to start), the review corpus under `docs/review/`.
