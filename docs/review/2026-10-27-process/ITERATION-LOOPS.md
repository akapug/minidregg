# Iteration loops in the 2026-10-26/27 demo session

Scope: root session `698fc87d` (Claude Code), 85 sub-agents, read with `cv lanes`, `cv show --json`,
`cv doctor` and `cv deferrals` at about 08:10 EDT on 10-27. All times are EDT. Lane ids are `cv`
agent prefixes; `#N` is a message index in that lane's `cv show` transcript. The work lanes are the
34 analysed in depth (L1–L13, forks, integrator, infra, hbox candidate, successors, the review
leads). Together they hold 108.6 of the session's 120.7 lane-hours and 2,324M of its 3,174M tokens.
Tokens are `cv`'s count: each API message counted once, by message id. A tool call's token cost is
the context of the turn that issued it, split evenly across that turn's calls.

**Classification:** a *wait* is a Bash `sleep`/`until`/`while kill -0` loop; *idle* is a gap over
5 minutes with no foreground tool, named by what ended it; model time is the residual. These are
heuristics, not instrumentation.

## A. The loops

| lane | loop | count | wall | tokens | mechanism |
|---|---|---|---|---|---|
| Integrator `a67de9cf` | foreground `until ssh … kill -0 $(cat X.pid); do sleep; done` on box builds and journeys | 93 wait calls, 32 hit the 10-min tool cap and were reissued | 6.51 h of 8.39 h | 39.2M | no waiter that wakes the lane; brief said "verify on the box" |
| Integrator `a67de9cf` | round-2 driver killed and relaunched as tips moved | 5–6 kills (#828, #878, #1140, #1212, #1279), 01:25–03:21 | round 2 took 00:24→03:37 | — | root forwarded 66 messages, 22 of them superseding an earlier tip |
| hbox candidate `a2d6b7e6` | 19×30 s poll loops on hbox `COMMANDS.log` | 72 waits; `jdeploy3` alone polled 8× (#217–#241, 17:59–19:08) | 7.46 h of 11.92 h | 16.5M | old composed gate on the hbox HDD (`jdeploy3` 4,809 s, rc=1) |
| L4 Hermes `aa09ceb2` | rerun the whole journey after each single fix | `jpay6-iso` 1–7 (#387–#744, 22:48–23:49), `j14-acp` 1–12 (#765–#1123, 23:50–01:22) | ~2.5 h | 18.4M in waits | J14 stops at the first false row; each run boots a fresh world |
| L4 distilled `a6d30cc8` | same journey, same shape | `j14-1`…`j14-8` (#95–#620, 07:02–07:59) | ~1 h | — | the same, plus a sudoers blocker routed via the root (#58) |
| L1 Lean `a8b5515a` | "waiting, bounded" loops on Host-closure builds | 43 waits; 21 `lake build`, 6 `lean-ask`/`lake env lean`; rounds 1–6 at #1265–#1436 | 3.11 h of 9.57 h | 27.2M | whole-closure build per round; REPL barely used; hbox "I/O-bound, even git is slow" (#757) |
| L13 app market `abc0f69b` | one compound write sat on a permission prompt | 1 call (#1055), 04:24→07:07 | **163.6 min** | — | background lane hit an interactive permission check nobody could answer |
| Hot path `aeba1c79` | same, smaller | 2 calls (#325, #333) | 21.5 min | — | same |
| L2 custody `a6ace691` | edit → filtered `cargo test` → edit in a growing context | 97 Mac build/test runs (15 identical commands); context 234k (#147) → 751k | 33 min of tool time | 49.6M | per-file habit; each check costs a full-context turn |
| L2 custody `a6ace691` | "was it red before me?" baseline runs in a detached `$SP/base` worktree | 11 (#435, #698, #717, #776, #783, #819, #860, #976, #1369, #1412, #1431) | ~3 min | 6.2M | habit that the global CLAUDE.md forbids |
| L11 perf `a6e199f9` | 10-min polls for soak "chunk 1" | 25 waits (#477–#527, 23:02–23:44) | 72 min | 5.8M | a measurement phase, struck from briefs later that night |
| L5, L6 (`a593382e`, `a8db5ca5`) | edit/check loops like L2's | 44 Mac builds each | 10–12 min | 19.1M, 14.4M | same as L2 |
| Web front end `ab1094b4` | 57 Mac and 33 remote builds; died "Prompt is too long" at 972k after 2.88 h | — | — | 148.7M | tool-call arguments (0.96 MB of Python edit heredocs) were its largest context source |
| Web distilled `a4ac34a3` | lane → integrator → root → lane round trip for a one-line assertion | gaps of 48 min (#260) and 54 min (#265) | 1.7 h | — | "I have no copy of that candidate's path, so I did not rerun it myself" |
| Infra `aa1562a2` | one lane held as the box operator for 36 parent tasks (#226–#2041) | 36 tasks, 106 ssh, 91 journey calls | 13.96 h (10.38 h parked between tasks) | 323.7M | a hub lane never rotated; died at 977k |
| Reader `a711b937` | read an 8,800-line file in 12 consecutive `Read`s (#137–#231) | 2.06 MB of results | 1.02 h | 48.8M | brief said "read the shard"; died at 973k |
| Review lead `a5e2b50c` | read every shard report into its own context to synthesise | 42 `Read`s of 50–58 KB reports | 1.25 h | 34.6M | synthesiser in the same context; died at 977k |

**Integrator.** The largest single loop: every box job went through a foreground `until` loop,
the 10-minute tool cap returned it 32 times, and every return re-sent a 200–670k context. The harness refused a bare `sleep` twice. Separately, 176
calls across the work lanes were auto-backgrounded with the notice "you will be notified, do not
poll", and lanes polled again anyway. **Alteration:** a `box-wait <host> <pidfile|marker>` helper
launched with `run_in_background`, so the harness wakes the lane exactly once, plus one brief line
forbidding foreground wait loops.

**Merge churn.** The integrator received 66 parent messages, 58 distinct tips for 15 lanes, and 22
"supersedes / correction / final-final" notes (#138 "now FINAL", #185 "Final-final"). Each moved
tip during round 2 meant killing and relaunching the box driver. **Alteration:** a fixed cut. The
integrator takes whatever each `lane/*` tip is at the cut time, and nobody relays tips.

**hbox candidate and perf.** These are the old gate and a measurement phase. The candidate polled an
80-minute `jdeploy3` that failed, and perf polled a soak. Both kinds of work are now nightly or
struck (`docs/COORDINATION-2026-10-27.md` §6). **Alteration:** already applied; keep timing rows out
of lane briefs.

**L4 and J14.** About 20 J14 runs went into one fix each, roughly 4 minutes apart. Examples: world
bootstrap (#977), row 68 key set (#1005), token bounds (#1040), room home (#1050), missing tsv
(#1057), summon (#1065), Host refused (#1083), program document (#1098), "context source has no
document" (#1108). Each failure surfaced alone after a full world boot. **Alteration:** journeys continue past a false row and print every failure, and a
standing world (`world-up.sh` from L13) can re-run one step.

**L1 Lean.** The lane waited on six Mac rounds of the 3,700-job Host closure, 10–30 minutes each,
and on a 2-hour cold build on dregg-build. It made 6 REPL calls against 21 `lake build`s.
**Alteration:** the brief names `scripts/pipeline/lean-ask` and `lake env lean <file>` as the
iteration loop, with the closure built once per batch. That is the owner's REPL ruling turned into
a template line.

**L13 and the permission stall.** A single denied compound `cat > … <<EOF` cost 2 h 44 min of a
running lane. **Alteration:** a background-lane permission allowlist for heredoc writes into the
lane worktrees (the `fewer-permission-prompts` skill), applied before launch.

**L2 and the edit/check lanes.** Each filtered test is seconds, but at 500k context every check is
a 0.5M-token turn. The 11 baseline runs are the "pre-existing?" question that CLAUDE.md says
teaches nothing. **Alteration:** batch edits before checking (COORDINATION §3 already says so),
quote the no-baseline rule in the brief, and distill at 400k (F).

**Web, round trips.** Reds found by the integrator on a candidate came back through the root. The
lane could not run the candidate itself. Nine such round trips appear in the long-gap table:
a18a4af6 ×2, a4ac34a3 ×2, ac30e28a ×2, aee3983a, afd2d900 ×2. Each took 48–107 minutes, median
about 57. **Alteration:** every lane gets the candidate path (`/build/CANDIDATE-*.md`) and a
standing world on dregg-build, and re-runs its own rows.

**Infra.** A hub lane that keeps being resumed builds context it never sheds. Its distilled
successor finished the rest in 48 min (F).
**Alteration:** rotate (distill) a hub after each task cluster, or at 400k, whichever comes first.

**Readers.** Two context deaths came from reading whole: a source file, and every sibling report.
**Alteration:** readers write notes as they go and grep or section large files. Synthesis is a fresh
lane that reads the reports' summary sections.

## B. The five largest sinks

1. **The read-only review phase (16:36–18:10):** about 41 reader, summariser and synthesiser lanes,
   **870M tokens (27% of the session)**, 10.4 lane-hours, two context deaths (`a711b937`,
   `a5e2b50c`). It bought the kill list and the plan, but each reader re-paid a 50–100k context
   floor and read files whole.
2. **Foreground waits on box runs:** 526 wait calls, **25.2 lane-hours (23% of the 108.6 analysed),
   213.5M tokens**. By target: hbox journeys 7.8 h, dregg-build journeys 7.1 h, hbox builds 3.9 h,
   Mac builds 2.8 h, dregg-build builds 2.6 h. Of that, 25.6M tokens were the 63 ten-minute
   timeouts being re-woken.
3. **Context growth:** **58% of the analysed lanes' tokens (1,344M of 2,317M) were spent in turns
   whose context was over 400k**, which is 35% of the turns. Over 500k: 41% of tokens. Over 700k:
   17%. The five heaviest are infra 285M, integrator 134M, L2 129M, web 126M and L1 123M above 400k.
4. **Reading by shell (`sed -n`/`grep`/`cat`):** 3,007 calls, 879M context tokens. Mostly sink 3 per call:
   cheap reads from expensive contexts.
5. **Integration churn:** the integrator (197.6M tokens, 8.39 h) plus 66 root messages to it.
   There were 51 merges of 17 lane branches into `integration/2026-10-26`, so 34 were re-merges.
   `lane/app-market` was merged 7×, `lane/web-frontend` 6×, `lane/lean-critical` and `lane/fence`
   5× each. Four candidate rounds ran in about 9 hours.

## C. The waiting

Across the 34 work lanes, the 108.6 lane-hours divide as follows:

- 25.2 h (23%) were spent in foreground wait loops.
- 48.3 h (44%) were idle gaps over 5 minutes. 45.6 h of those ended with a parent message, which
  means a lane that had reported and was later re-tasked. Another 1.95 h ended with a background
  notification.
- 4.2 h went to foreground builds and tests, and 5.2 h to other tools.
- About 25.8 h (24%) were model time.

**Waiting is 67%**, against HISTORY §4.1's 61%. About two-thirds of the idle is parked capacity,
not blocked work. Its cost is the context that parked lanes hold, which is sink 3.

What the waiting was on:

1. **Box runs** (sink 2). Journeys outweigh builds 15 h to 9 h.
2. **The root.** Lanes reported, then waited for the root to forward the next red or tip. The
   root's re-task latency after a lane return was median 6 min, p75 30 min, maximum 308 min
   (`ab4e58c7`, waiting on ember's rulings on its DECISION list).
3. **The owner.** After "All eight lanes are complete" (root #559, 19:24), the root ended its turn,
   and the next human prompt came at 22:22 (#562). Nothing new launched in those **2 h 58 min**.
   The implementation lanes L1–L11 started at 22:26.
4. **Permission prompts:** 7 denied calls in the work lanes, 189 min, 164 of them in L13.

**The root's own loop.** 294 SendMessage calls, about 298k characters: 66 to the integrator, 53 to
infra, 26 to L1 and 21 to the nano root. The root received 330 returns and notices. `cv deferrals`
finds 24 deferrals, 12 of them "queued". Twenty-six root texts are status/pending updates. The root
compacted once at 968.8k (#2039, 02:08). Much of the routing was relaying: a tip to the
integrator, a red back to a lane, a box fact to infra. That traffic exists only because lanes could
not see the candidate or each other's tips.

## D. The handoffs and merges

- `integration/2026-10-26` has 51 lane merges between 22:41 on 10-26 and 07:56 on 10-27, of which
  34 re-merge a branch already merged. The integrator was told 58 tips for 15 lanes:
  `web-frontend` 11, `app-market` 9, `fence` 6, `lean-critical` 6, `custody` 5.
- Round 2 began with its merge list at 00:24 (#519). Its tip, 45f45d15, was fixed at 03:37
  (#1417), after 5–6 driver relaunches. Warm rounds 3 and 4 then cost about 20 min of build on
  dregg-build (347 s + 827 s), against cold umbrellas of 4,582 s (hbox, rc=1) and 5,111 s
  (dregg-build).
- Messages that arrived mid-build said "take the tip you find" (#874), and the integrator then
  killed the build to take it.

**A merge queue or a fixed cadence would have been cheaper.** The measured warm build is about 20
min, so a cut every 60–90 minutes gives each lane at most one merge per cut. A lane that misses a
cut waits about 1 h for the next. The alternative was 2 h of relaunches. It also deletes the relay
messages: the integrator reads `git ls-remote origin 'lane/*'` at the cut, and reds go back to the
lane by name in one report, not through the root.

## E. Ten workflow alterations, ranked

1. **Pre-launch permission allowlist** for background lanes (heredoc writes and `git`/`ssh` in lane
   worktrees), applied once with `fewer-permission-prompts`: about 3.2 h of stalled lane time, one
   settings change. *Who: the orchestrator, before any swarm.*
2. **Pre-authorised phase transitions.** When a phase completes and the next one has a default, the
   root launches it and tells ember, instead of ending its turn and waiting: 2 h 58 min of fleet
   idle. *Who: the orchestrator's rule (COORDINATION §4).*
3. **`box-wait` plus a no-foreground-wait rule.** A script runs in the background on the box and
   wakes the lane once on a PID-file exit or marker. Lanes do other batch work meanwhile: 25.2
   lane-hours of blocked turns and about 210M tokens. *Who: a script in `scripts/pipeline/`, plus a
   brief template line.*
4. **Lanes run their own candidate rows.** Every brief names the current `/build/CANDIDATE-*.md`
   and a standing world (`world-up.sh`). Removes the 9 observed round trips of about 57 min each
   (about 8.5 h of lane latency) and most of the root's relay traffic. *Who: a box change on
   dregg-build, plus a brief line.*
5. **Fixed-cut integration**, every 60–90 min. No tip messages: the integrator reads `lane/*` at
   the cut. Removes 34 re-merges' worth of relaunch churn (about 2 h in round 2) and 22 correction
   messages. *Who: the orchestrator's rule and the integrator's brief.*
6. **Distill at 400k.** `cv distill --keep-last 10` for code lanes and 14 for box/infra lanes; hubs
   rotate per task cluster. Targets the 58% of tokens spent above 400k, and four context deaths.
   *Who: the orchestrator's rule.*
7. **REPL-first Lean iteration.** `lean-ask` or `lake env lean <file>` in the warm Mac `.lake` per
   edit, the Host closure once per batch: about 3 h of L1 waits. *Who: a brief template line.*
8. **Journeys report every failure and re-run single steps** on a standing world: about 2.5 h of
   J14/JPAY6 reruns across L4 and its successor. *Who: a change to the journey library
   (`journey.d/lib`).*
9. **Reader discipline.** No whole-file `Read` over 2,000 lines, notes written as the lane goes, and
   synthesis in a fresh lane over summary sections: two context deaths and part of the 870M review
   cost. *Who: the reader brief template.*
10. **Per-lane isolation and no baselines.** A per-lane `CARGO_TARGET_DIR` (three lanes hit
    another's stale build: `a18a4af6`, `a6fc5066`, `aee3983a`), a per-lane scratch subdirectory
    (L5 overwrote another lane's `msg1.txt`), a PID file for every started process (five reports of
    orphans with none, so ember had to clear them), and the no-"was it red before" rule quoted (11
    runs in L2). *Who: brief template lines.*

## F. What the distilled resumes show about context budgets

| successor | predecessor at death | pack's first context | compression | keep-last | first productive action | outcome |
|---|---|---|---|---|---|---|
| L4 `a6d30cc8` | `aa09ceb2`, ~561k (completed; distilled ahead) | 101k | 5.5× | 10 | box command at 06:58, 1 min after the resume message | 8 J14 runs, still running at 384k after 6.3 h |
| Web `a4ac34a3` | `ab1094b4`, 972k (died) | 109k | 8.9× | 10 | an edit by 07:59, 2 min in | regrew to 493k in 4.2 h (~90k/h); `cv` marks it stranded on background task `b1doypt47` |
| Infra `a8850c5b` | `aa1562a2`, 977k (died) | 183k | 5.3× | 14 | commit and ship-side edit within 2 min | finished in 48 min, 30.5M tokens |

**What was kept:** the brief, every parent message verbatim, the lane's own words, and an index of
commits, hosts and errors. None of the three re-read the predecessor's files, and each was acting
on live state within 1–2 minutes.

**What was lost:** private reasoning, which the pack itself warns about. The web successor shows
the remaining risk: it re-grew at the same rate as its predecessor and stopped on a promise.

**Recommendation.** Distill at about 400k, not at death. That is where the token curve bends (B.3),
and it leaves room for one full batch. Use keep-last 10 for code lanes. Use 14 for lanes whose last
calls carry live box state (PIDs, candidate paths). Rotate hubs per task cluster whatever their
size.

## What I could not measure

- Box-side run time is known only where an `END rc= wall=` line reached a transcript.
  Background jobs are measured only by the gap they left.
- Model time is a residual, and the wait/idle classes are regex heuristics.
- Lanes still running at about 08:10 (L1, integrator, L13, L4-distilled, L2 successor, oracle) are
  measured to that point.
- Codex lanes, the nano root and hbox co-tenants are outside this session.
- `cv show --agent` refused the exact ids of the three distilled lanes as ambiguous with their
  `.flat` sidecars, so those were read from the raw subagent JSONL through the same analyser. That
  is a `cv` bug worth fixing: an exact id should win.
- Whether a loop's runs were necessary is judged from their commands and results, not re-run.
