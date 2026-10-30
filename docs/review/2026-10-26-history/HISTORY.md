# minidregg, August to October 2026: what actually happened

Written 2026-10-26 for ember and for the orchestrator of session 698fc87d, who has to plan "a finite prefix of work that brings the whole system into reasonably usable coherence" for a small public Hetzner demo.

**Method.** `cv` over every session whose cwd is minidregg, breadstuffs, zkml-research, claudesplosion or dregg-assortia, plus the grok and kimi-code sessions. For each session I read the prompt/answer stream first, then the replies around each redirecting prompt, then the lane tables. Three Sonnet helpers wrote per-phase notes, and I read every note. A fourth pass by the first helper covered deployment. The notes are in `/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/history/` (notes-A, -B, -C, -D, with raw extracts beside them).

**Citations.** `abcd1234#N` means session prefix and message index (`cv show abcd1234 --around N`). I also cite commit hashes and absolute paths. Nothing was built, run or changed in any repository.

## 0. Five findings to read first

1. **The famous quotes are about fn, not minidregg.** "We've never managed to EVER start on the actual rip and tear part of the plan … are we just stuck in an attractor?" (2026-10-12 23:39) and "the major repair and recovery of the whole system" (2026-10-09 19:40) were both said in **fn** sessions, the ACL2 NNTP sibling project (905fe751#13287 = d0d33f7b#749 = d5d27b94#1690; 4a22422c#2307 = 905fe751#282).
   - These sessions run with cwd `~/dev/minidregg`, and cv titles them "Minidregg objective bend review" because 9627d694 opened on Oct 3 with an Objective Bend review. From 9627d694#604 (Oct 3 19:50) onward the whole lineage (9627d694, be1e9dcf, 35f3668a, 4a22422c, 905fe751, 608deb34, d5d27b94, d0d33f7b) is the fn swarm.
   - All 33 unfinished lanes in the ten most recent minidregg-cwd sessions are fn lanes (`cv lanes --recent 10 --unfinished`).
   - The same attractor still ran on minidregg, in the "Objective Bend native integration and wiring" lineage with cwd breadstuffs (c1e4d723 → ce776c01 → b3795e84 → a8357d63/777a29c9 → a3ea5950/7c10f132 → the nano-elevation sessions).
2. **minidregg's rip-and-tear was never done in place. It became a new repository.** On 2026-10-16 at 18:02, ember said in the minidregg lineage: "i feel like we need to rip and tear our software .... it got so bloated .... we need a different factoring … but i'm wary to set you onto that task" (b3795e84#4154).
   - Twenty-six minutes later she ran `mkdir ~/dev/nanodregg` (#4207) and told the discovery agents to "rebuild whatever shape they think will be better in ~/dev/nanodregg. go hardcore. ONLY GOOD CODE AND BEST PRACTICES" (#4210).
   - The same move happened the same week in two siblings. DelveTalk's tree was emptied and rebuilt as delvetalk2 on Oct 9 (01a11b63#21185, commit `1ed0b9c0`, −124,963 lines). fn finally deleted in place on a `cut/breaking` branch on Oct 16–17 (d0d33f7b#4525 onward).
   - minidregg main has been essentially frozen since 2026-10-17 (`334316df`). Since then it has had only four commits: the readme header and three Oct 26 housekeeping commits.
3. **minidregg is 1.69 M tracked lines against a founding budget of about 290 K.**
   - ATLAS.md (Aug 7) set the budget at "≤10% of breadstuffs". On Oct 3 a Fable review told ember: "Tracked code is about 790K lines against the 290K founding budget. Either the law changed and CLAUDE.md should say so, or the next week is deletion" (9627d694, reply before #348; `/Users/ember/dev/redregg/work/FABLE-REVIEW-20261003.md`).
   - Today `git ls-files | xargs cat | wc -l` gives 1,686,126 lines. That breaks down as Kernel 211 K, Compiler 105 K, Theory 87 K, Host 39 K, native Rust 422 K, scripts 166 K and docs 377 K.
   - Neither branch of that review happened. The law was not amended, and the deletion week went to nanodregg.
4. **Exactly one public Mini service has ever existed, and it was last shipped on Oct 1.** It runs on `dregg-workhorse` (Hetzner cx33, fsn1). DEPLOY-1 and DEPLOY-2 went out on Sep 30 and DEPLOY-2b (candidate `5688775a`) on Oct 1, with dregg-infra commits `68aac58`, `d35f525` and `daf97fa`.
   - No friend was ever enrolled; the roster holds ember plus three test keys (`deploy/shell/FRIENDS.md`, read Oct 3).
   - DEPLOY-3 was rehearsed 67/67 and never shipped (`SHIP-RUNBOOK.md` on dregg-infra origin/main is headed "NOT EXECUTED").
   - The "October 13 shellserver" soft launch did not happen. Nobody cancelled it; it evaporated (notes-D §2).
5. **The one project that shipped continuously in October was DelveTalk, on the same box.** It went through about 17 live editions between Oct 8 and Oct 14 (dregg-infra `c6af40a` … `d243803`). It had one owner session, no composed gate, and the rule "we can rip and tear and rebuild anything we like. we don't need migrations" (01a11b63#11033). Its users were mostly ember's own residents (91%, `redregg/work/DELVETALK-LEARNINGS.md`), but it shipped.

---

## 1. Timeline

### Phase 1: Founding atlas (Aug 6–7)

**Founding session.** b54b6026 (claude Fable, cwd minidregg, Aug 6 23:43 UTC → Aug 7). Ember's brief (#3): "a complete formal-first reimplementation of ~/dev/breadstuffs … never ever be handwriting any AIR … at most 10% of the total lines of code. A full expression of the impetus towards a proof-native semantic computer."

**ATLAS.md** (`e6a32c4c`, Aug 7 02:12) came from a six-lane dig into breadstuffs/metatheory.
- The diagnosis: breadstuffs "built and proved every piece of the derivation machine, demonstrated each at n=1, and wired almost none of them into the load path".
- Sixteen design laws.
- The founding sentence: "the derived path is the *only* path … Nothing lands beside; everything replaces."

**Ember's five decisions** (#258, recorded in ATLAS §8 `6a1b8c72`):
- no `verifyBatch` or `StarkSound`;
- "we could own our own proof system";
- a hyperedge design pass;
- frontier items left undecided;
- skip the games.

At #329 she added: "I don't want to vendor VCV-io or ArkLib".

**Cost estimate.** The agent estimated the proof-system work at "30–60K Lean lines, 6–18 months". Ember (#464): "the entirety of breadstuffs was one guy and two months :)".

**Helm.** About 20 of ember's 36 prompts in the founding session were about helm (pug's fleet tool). Helm was later retired for this project (ee15d4e6#28, Sep 4).

### Phase 2: The Lean proof-system burst (Aug 7–14)

**Volume.** 1,138 commits between Aug 7 and Sep 6 (Aug 7: 92, Aug 8: 116, Aug 9: 291, Aug 11: 214, Aug 14: 227). The Lean tree went from 0 to 122 K lines (Aug 9) and then to 239 K (`6937394e`, Sep 6). (notes-A §2.)

**Sessions.**
- Claude: 6977f98e and 37e4ed4c (the Loom `/goal` loops).
- Codex "Sol" roots: 019fe43d and 019fe77b. These had about 111 fork-copies with identical titles, so they are not distinct tasks.
- Claude Quiescelog: 75cc14b0, 824564a2, 3e64269c, 2209ffea, ca67a4c1 (cwd minidregg), then c352a91d … c820add0 (cwd breadstuffs, with about 275 subagents).

**What was built.**
- **The owned proof system.** Named Loom, renamed Selvage (`423efed1`, Aug 13). It is WHIR-shaped and sumcheck-centric, with straightline hash-based accumulation, BabyBear/Poseidon2, and Basefold/WHIR-style commitments. The proven headline was **55 bits** (ErrorBudget, 37e4ed4c ~#1194); 120 bits exists only as a parameterization.
- **Substrate.** Effects/EffectSpec, PredCompile, the Gate kernel with the first `@[export]`, the Hyperdocument medium, credential lineage, reactive views, and the WAL handler.
- **Rust deletions.** About 20 `prover: delete handwritten …` commits on Aug 9, after ember's "why did we start having rust *mirrors* of this functionality" (019fe43d#5768) and "there is absolutely NO semantics for rust" (#5795). This is the first rip-and-tear that actually happened, and ember had to name it concretely.

**Decisions and findings.**
- "always fix-forward instead of reverting" (019fe43d#535).
- "Can we please stop doing verification and benchmarking ritual before we even have something worth doing it about?" (019fe43d#2030, Aug 9 01:58). The agent agreed, yet the same day logged 19 `evidence:` commits and 28 `docs:` commits.
- On Aug 10 an overnight session proved that **"All four `CellState.Schema` definitions in the tree admit no materializer"**, so a whole class of theorems was vacuous (824564a2, morning report). The planned "cut over one workflow" could not run.
- On Aug 12 ember pivoted to zkML and created `~/dev/zkml-research` (3e64269c#1354, #1415).

### Phase 3: The quiet (Aug 15 – Sep 3)

There were 10 commits from Aug 16 to 18, then none until Sep 4. Ember was on other projects: joshi/joshibot (Aug 16–19), dragons-clutch (Aug 22 – Sep 4, about 630 sessions), dregg-microsites posters, and audec (notes-A appendix). No sentence says "pause minidregg". On Aug 11 she told the breadstuffs side that minidregg is "exploring both a new proof system and alternative kernel semantics … as we continue our repairs … we expect we'll eventually get a version that could actually ship a mainnet" (019ff1ac#149).

### Phase 4: The Sep 4–5 standing goal and the zkml-research swarm (Sep 4–9)

**The goal.** A Fable 5.1 usage window (2f4e6724#0, "anthropic gifted us a usage reset") became `GOAL.md`'s standing goal: "Work all night achieving the best possible minidregg using Fable 5.1".
- About 28 commits landed on Sep 5 (BaseFold work-capacity, the Stage-0 receipt on the derived path `658bacb5`/`7dc8b5be`, the distributed design, the kernel twin audit).
- It died at the Fable weekly wall around 13:10 on Sep 5.
- GOAL.md's "first three moves next session" (R4 table-twin script, R2 HeteroComposition, CrtSlotSeparability) were never executed.

**ee15d4e6** (Sep 5, "Breadstuffs kernel semantics").
- Ember: "i'm glad you noticed that minidregg has the disease too :: ) We'll probably need to someday maybe completely reboot the project … in the meantime … it's what we have to work with" (#443).
- The agent: "built and disconnected … a capability isn't landed until its consumer is in the same commit … minidregg is not the reboot; it's the honest ledger."

**Two more prompts that day.**
- Ember asked for "what we can be building and releasing that actually gets peoples attention" (codex 01a07270#79).
- She asked whether the agent was "getting into selfcongratulatory loops where you find something that was 'false as stated' but … you just refute it and leave the system crumbling in your wake?" (2f4e6724#979).

**zkml-research swarm.** Codex 01a07565 (gpt-6-astra, cwd zkml-research, Sep 6–9, 37 children) worked in zkml-research and published GitHub Pages. It left minidregg patches unapplied, and minidregg got zero commits from Sep 7 to 16. Ember: "No. I just asked you to swarmcycle wider. You just invented a whole bunch of validation theater" (#7098); "stop doing so many tiny little steps. just think real damn hard, and then build out the whole thing, then fix the bugs" (#11137).

### Phase 5: "Mini as construction home": the codex Astra waves (Sep 17–28)

**The root.** Codex 01a0b0ed (gpt-6-astra, cwd breadstuffs, Sep 17 15:55 → Sep 29 22:33, 60,707 messages, 106 typed prompts). It is the root of about 209 child sessions. dregg-assortia was its project hub.

**Ember's directives.**
- The product is "a 'shellserver' of yore … built around our *own* cloud&dreggic offerings, and *hopefully* full Hermes integration" (#316).
- "comprehensively rip & tear to address any gaps … instead of accepting limitations and working around them" (#1326, Sep 17 22:01). At that point this meant fixing gaps through the stack, not deleting twins.
- **"Don't you think we should be just rebuilding into mini what we need for the New World? … bread's machinery can be rebuilt"** (#7900, Sep 19, recorded in `dregg-assortia/sprints/2026-09-19/rebuild-in-mini.md`). This is the origin of "Mini is the construction home".

**What happened.**
- Sep 19: cycle 1 produced an 11-event native journey PASS in 10,380 s ("not suitable for an interactive shell").
- Sep 26: "this is NOT an opportunity to just build some bullshit unconnected unwired greenfield thing" (#13258), with fn adopted as a semi-untrusted transport (#25486).
- Sep 26–27: 240 and 370 commits.
- Sep 27: 254 "final/pushed" status messages from the root, and 78 checkpoint files in about 42 hours.
- The GitWeb SPK fixture never INSTALLed (refused at count 29). No real-model hosted Hermes session ever ran.
- Sep 27 22:54, ember: **"you never actually started working on what i asked for. you got so lost in the forest."** (#58007).

**Turn mix.** The root used 2,980 `send_message` and 505 `followup_task` calls against 431 `apply_patch` (notes-B §C).

### Phase 6: The Sep 27 platform reorientation and the Claude takeover (Sep 27 – Oct 1)

**The reorientation document.** `dregg-assortia/research/platform-reorientation-2026-09-27.md` (`21ff933`) is a findings document, not a design. It decided "build the programmable infrastructure in Mini, with application grains as instances" and not to auto-resume fixture work. It retired, de facto, the GitWeb-journey-as-objective. It deleted no code. A Sep 28 external "recovery brief" added: "Measure progress by independently created, composable, recoverable uses of shared mechanisms … an additional checkpoint is not, by itself, that result" (01a0b0ed#58435).

**The Claude takeover.** Claude 0c315aee (with fork d4bc3ea6) took over on Sep 29 and created `~/dev/claudesplosion`.
- **Bake-off.** Mini passed J0–J8 but failed growth: 13 s per write and 121 s cold reopen at 105 records. The verdict was stay in Mini.
- **Data-model cutover.** DATAMODEL.md: "delete four page structures … and the Gate/State/Camera kernel". The C2 growth exit later reached 2.2 s write and 4.3 s reopen at 1,000 records.
- **First public node.** DEPLOY-1/2/2b on dregg-workhorse.
- **Decisions.** No proof system in Mini's admission path (memory `project-no-proof-system-in-mini-admission`, Oct 1). Mini is the resource-world kernel; Bread "gets fixes, not rebuilt into".
- **Ember's lines.** "mini's role is to take over from the old dregg repo but who the fuck knows what time of timescale" (0c315aee#840). "we don't even have a coherent idea of 'where we want to be'" (#851). "migration theater and other rituals" (#3214). "why are we still serving that? … none of the infrastructure is sacred" (#7895).
- **Claude's own verdict** (#7523, Oct 1): "Forty-five branches landed … we have shipped nothing since the last deploy … filing landings became the work."

### Phase 7: Private objects, Objective Bend, codex walls, drain and freeze (Oct 1–9)

**Volume.** 1,442 minidregg commits from Oct 1 to 9 (433 on Oct 2, 361 on Oct 4, 289 on Oct 7). The tree grew by roughly 727 K lines and lost 31 K (notes-C §0.3).

**Codex 01a0fa81** (Oct 2–3, about 121 children).
- After a $1000+ overnight run, ember: "you burned over $1000 … achieving … literally nothing? … Did you just build an independent side-thing?" (#6864).
- She raised the Oct 13 bar to include traffic privacy and agreement (#6996).
- **Objective Bend** was coined: "like the way the web uses js, we will use bend" (#9441); "'Objective Bend' is clearly where we are headed" (#10200, Oct 3 04:36). It means Faré-style lazy open recursion over partial specs, `.obend` source, a Lean front end, Core4, and a demand machine (`docs/OBJECTIVE-BEND.md`, 861 lines, "deployed (nothing here is)").
- Codex hit an account-wide wall at 19:20 UTC on Oct 3.

**Two Fable reviews the same day** (9627d694).
- "no language yet … Of 45 theorems, about seven carry content".
- "Kernel/ is 436 files and 140K lines of per-feature receivers".
- "133 opcode arms, four named in any theorem" (`redregg/work/FABLE-REVIEW-20261003.md`, `FABLE-TREE-AUDIT-20261003.md`).
- Ember: "your subagents reward hacked you" (01a0fa81#14031).

**Claude c1e4d723 took over the minidregg work.**
- "we gotta delete the old Gen-1 code and docs/designs" (#152).
- The Oct 3-night **`cut(1a)…cut(7)`** series deleted Gen-1 Objective Bend (`4df059b2`, −3,284 lines). This was an intake of codex's WIP plus a small deletion, not a collapse.
- On Oct 4, ember deleted the lane working directories on hbox (#1509, #1629). Latitude and Hetzner burst boxes were rented as development capacity.

**ce776c01 (Oct 4–8)** was the deputy era on burst2. Ember: "why are we 'polling'? wtf is 'polling'?" (#3070); "OPTIMISTIC PIPELINED CONCURRENCY" (#3153).

**Oct 8.** Ember asked to close out Mini as "an Actually Good And Shippable (as a demo) spk/shell/etc host" (ce776c01#5980). That produced `redregg/work/SHIP-PLAN-20261008.md` ("the standing journey runner covers the kernel and the Objective Bend apps, and not one product flow").

**Oct 8 ~23:50Z: DRAIN then FREEZE for Mini as well.**
- Ember's words were spoken in the fn session (be1e9dcf#8659) and adopted for Mini (memory `project-2026-10-08-drain-and-freeze-for-rethink`, ce776c01#6704): "we have some major problems with this software right now, and they aren't going to be solved by sending out subagents".
- That produced `RETRO-20261008.md`, `MATURATION-MAP-20261009.md` (DEPLOY-3 placed last of seven steps), and REPAIR-1..3 (`7dea0626`).

**Codex 01a11b63** (cwd minidregg, Oct 8–9) was **DelveTalk**, not minidregg.
- Its Oct 9 `sol_*` swarm (26 sessions) was told "you're deputized to rip and tear and build anew" (#17167).
- Three hours later the tree had grown from 638 to 766 files. Ember: "we never did get around to 'ripping and tearing'" (#20732); "you're not actually capable of doing that" (#21181).
- It was handed to Claude, who emptied and rebuilt it in delvetalk2.

### Phase 8: Ten days of fn in the minidregg cwd; the Oct 12–13 reorientation talk and wesvet (Oct 9–14)

**Mini dark.** Minidregg main had zero GitHub activity from Oct 10 to 13 (`redregg/work/RECOVERY-20261016.md` table). The minidregg-cwd Claude sessions were running fn: ACL2 trains, seats A/B/C/D/L/M/O/P, and codex workers on hbox.

**The fn rethink.** Oct 8–9 in 35f3668a produced the retro and "collapse the ladders" (#1377), "major major surgery" (#1497), and `~/dev/fn/build/coordinator/ANATOMY-20261009.md`. That evening's scorecard read "books 1,931 → 1,902 … tools and tests grew; not small yet" (905fe751, reply to #282).

**Oct 12 23:39, the attractor question.**
- The coordinator's reply diagnosed it precisely: "Every landing pays the same fixed cost regardless of size … So the gradient points at small, provable, non-deleting work … A rip-and-tear lane … is the most expensive and most 'red' thing a seat can do, so no seat does it" (d5d27b94, reply to #1690).
- It proposed inverted rules for a deletion mode.
- Then it waited on "your call on the freeze and the cut" for the rest of the night.

**Oct 13.**
- Ember: "hey just GUESSING at what keywords will return, is a bad strategy … make a subopus to just systematically examine all of the toplevel exchanges" (d0d33f7b#1495).
- "we should actually figure out HOW to think about reorganizing and rewriting all of our 'scaffolding' … so that we **can replan confidently**" (#1636).
- She created `~/dev/wesvet` for the veterans-at-the-front study (#1679). On Oct 14 she judged it "a bit of a distraction" (#3229).

### Phase 9: Integrator batches on minidregg main (Oct 13–17)

**Reorientation and perf.** b3795e84 reoriented on Oct 13 (#1193). The perf program followed (`redregg/work/SHOULDNT-BE-DOING-20261013.md`: 54% of a bench in `deployedHash`, about 140 execs of the 173 MB host for codec verbs). Ember: "honestly at this point i wonder if we need to redesign our code to be *capable* of high performance at all" (#2419).

**Oct 16.** "lets get that shit onto main even if it isn't 'ready' yet! … main is meant to be a battleground" (#3959). Main was fast-forwarded `7ffd6524 → 2c27b08b` with 90 perf commits.

**Three scholars** reported:
- `ARCHITECTURE-20261016.md`: 186 opcodes, about 120 Host verbs, 51 admission constructors, 281 K Rust lines "deciding things", **59 twins**, and "the Host and the World are two different state machines".
- `CYCLE-TIME-20261016.md`: one lane iteration takes 2.5–6 h; 0.86 commits per lane-hour; **61% of 222 lane-hours were spent in wait loops**; one host build is a 775-process Lake loop.
- `RECOVERY-20261016.md`: 11 usage walls killed 65 lanes; two root context deaths orphaned 62 and 15 lanes.

**Batches.** INTEGRATOR-4/5/6 then landed:
- batch 1 `cfb68bf9` (hp-1-bounds, turn-log, perf-memo, spk-ns);
- batch 2 `92b6e19d` (codec-shapes, TokenCensus green, consent-model, the Fixtures split);
- batch 3 `3618d842` (floors, the C2 durable engine, cycle-fix's seated builder, codec identity bumps, the one known-red rule);
- `334316df` (mk-lane fix, Oct 17).

Most of these are apparatus (gates, pipeline, known-red, codec fingerprints, census). The cycle fixes were real wins: shared Lake cache 806.8 s → 2.0 s, host step 831 s → 95 s (`redregg/work/BURST5-UP-LOG.md`).

**Oct 17: minidregg scope set to "finish-only".** The coordinator framed it as "No new minidregg ranges start while nanodregg is the thing being built … weeks of parallel work on a codebase we've decided to replace" (b3795e84, reply to #6175). Ember agreed: "i do think we whould finish-only right now" (777a29c9#25).

### Phase 10: nanodregg born; the Oct 23 readme (Oct 16–23)

**Founding.** nanodregg was founded Oct 16 at 18:28 (b3795e84#4207–#4210). Its charter has twelve laws, each "a response to a measured minidregg failure": one of everything, Lean decides and Rust moves bytes, a Host closure of at most 150 modules, a size ratchet that only goes down, and no copying from minidregg. Six (later seven) Opus builders own one layer each. The coordinator's objection was recorded and overruled: "a rewrite swarm would produce a third copy of everything" (reply to #4154).

**Pace.** 203 commits on Oct 17. First GREEN standing verdict at 15:24Z on Oct 17 (memory `project-2026-10-16-nanodregg-rebuild`). It now has 747 commits, 754 files and 234 K lines.

**Ember's scope calls.**
- "nanodregg only ever at most /dabbles/ in proof systems … the semi-trusted vat prototype" (777a29c9#177).
- "we've been working on this 'trie day' for a long time and i'm starting to wonder if we're lost in the sauce of incrementally modifying a system" (#1261).
- **"nano isn't supposed to FOREVER take over from mini, it was supposed to be an exercise and way to gather requirements … We DO still indeed [want] mini to be the production thing that we put out into the world as an experimental demoland - probably"** (7c10f132#1800, Oct 19).
- "breadstuffs is where our whole system we built lives and we've been splintering out into these sideprojects (mini, nano) for diversity and continued focused exploration" (#2156).
- "Our process is still eating its own throughput. We have very little goodput out of our overall swarming" (#2156).

**The readme.** On Oct 23, `307b13ea` added the "Dragon's Egg repositories" header to minidregg's README (asked at 3a1e01fe#4823/#4841). It calls dregg "waiting to be resumed or composted", minidregg "the production demoland and the spec/battleground the rebuild measures itself against", and nanodregg "the single-writer rebuild".

### Phase 11: nano-elevation (Oct 20–26)

**Sessions.** e6e774d6, 01a16737, 3a1e01fe (Oct 20–23), 01a167c9 (Oct 22–26), and 01a179c1 (Oct 24–26, live now).

**What "elevation" means.** Ember asked to promote nano's toy contextual-type-theory instances into "actually deployed aspects of the exact nanodregg system of our dreams" (3a1e01fe#3175). She also asked: "maybe nano is too limited and we need to go visit the minidregg metatheory … we either need to elevate nano or start working on mini probably right??" (`redregg/work/NANO-VS-MINI-20261022.md` quotes this). The scout answered: "**Elevate nano, narrowly. Do not move the program to mini. Do not bridge the kernels.**" It reported mini's distinctive assets (BFT engine, quorum/CRDT theory) are outside the deployed Host closure, `World.admit` has no caller on the native host path, and "red is the steady state" on mini main.

**The program.** `redregg/work/PROGRAM-20261022.md` ("putting the meat on nano") defines ten behaviours (B1–B10: revocation in the same Turn, holes that repair, atomic fuse, cross-World receipts, and so on).

**Ember's corrections.**
- "Stop it. This microfixation on 'each statement individually refutable' is WASTING TIME … not something i established and not something i value" (01a167c9#2034).
- "we only need the TOPLEVELMOST theorem to be nonvacuous" (#2083).
- The coordinator "had a 'pink elephant' problem" in its memory files (#2046).
- "are you proposing a bunch of bureaucratic ritual that would mostly only serve to soothe you" (memory `feedback-method-items-that-soothe-root-are-not-progress`, Oct 22).

**Where it stands.** Oct 26 00:15: "we've basically gone as far as we can with nanoestdregg and need to upgrade to actually metamodelling agreement … so that we can start scaling nanodregg towards minidregg ambitions" (01a179c1#675). At 16:06 ember answered five decisions and said "we need to work on that spec and demoland" (#1671).

On the same day this session (698fc87d#5) asked to bring **mini** to a deployable Hetzner state.

---

## 2. Ember's directives that changed the course

Process rules appear only where they changed what happened.

| date | directive (verbatim or near) | where | effect |
|---|---|---|---|
| 08-06 | "never ever be handwriting any AIR … at most 10% of the total lines of code" | b54b6026#3 | founding law; budget about 290 K; now 1.69 M |
| 08-07 | "We can completely finish implementing our own proof system … I don't want to vendor VCV-io or ArkLib" | b54b6026#329 | Loom/Selvage built (55 bits proven) |
| 08-08 | "we should just always fix-forward instead of reverting" | 019fe43d#535 | standing rule ever since |
| 08-09 | "Can we please stop doing verification and benchmarking ritual before we even have something worth doing it about?" | 019fe43d#2030 | acknowledged, not obeyed; repeated 09-08, 10-07, 10-24 |
| 08-09 | "why did we start having rust *mirrors* … there is absolutely NO semantics for rust" | 019fe43d#5768, #5795 | about 20 deletions the same day: the first real cut |
| 08-12 | zkML is "a top-priority goal"; research docs go to zkml-research | 3e64269c#1354, #1415 | the Aug 12 – Sep 9 attention shift |
| 09-04 | helm retired for this project; the sgoal skill is "old/bad practice" | ee15d4e6#28, #61 | |
| 09-05 | "selfcongratulatory loops … refute it and leave the system crumbling" | 2f4e6724#979 | the "repair before reach" ranking in GOAL.md (never executed) |
| 09-17 | "a 'shellserver' of yore … full Hermes integration"; "comprehensively rip & tear to address any gaps" | 01a0b0ed#316, #1326 | the product target, unchanged since |
| 09-19 | "rebuilding into mini what we need for the New World … bread's machinery can be rebuilt" | 01a0b0ed#7900 | Mini becomes the construction home |
| 09-19 | "Have we … EVER used python as an implementation langauge … no. let's not start now" | 01a0b0ed#7314–7322 | Python grain lanes left untracked (`scripts/build-native-host-bounded.py` still in the tree) |
| 09-26 | "NOT an opportunity to just build some bullshit unconnected unwired greenfield thing" | 01a0b0ed#13258 | |
| 09-27 | "you never actually started working on what i asked for. you got so lost in the forest." | 01a0b0ed#58007 | the Sep 27 reorientation |
| 09-30 | "could we actually deploy a thing"; first node on dregg-workhorse | 0c315aee#1688, #1734 | DEPLOY-1/2/2b |
| 09-30 | "we don't need to redeploy as often … migration theater" | 0c315aee#3214 | batching rule; DEPLOY-3 became the batch, and its gate never went green |
| 10-01 | "none of the infrastructure is sacred … get that shit merged" | 0c315aee#7895 | not reconciled with the batching rule |
| 10-01 | No proof system in Mini's admission path; "we DEFINITELY do not need to be stuck with nock" | memory `project-no-proof-system-in-mini-admission`; 0c315aee#4758 | Selvage became research-only |
| 10-02 | "i dont want to ship our upcoming alpha on oct13 without traffic privacy and some kinda consensus/agreement" | 01a0fa81#6996 | Oct 13 bar inflated |
| 10-03 | "'Objective Bend' is clearly where we are headed"; "Objective Bend is the only bend" | 01a0fa81#10200, #17658 | Gen-1 deleted (`4df059b2`) |
| 10-03 | "rather than minidregg one day becoming a subdir of bread … minidregg [should] grow up to become bigdregg" | 01a0fa81#9552 | |
| 10-04 | "you need to stop using these prompts as an opportunity to do an auditcensus … like playing wesnoth and you keep sending all the high-exp troops to the back" | 9627d694#2912 | became "send the veterans back to the front" in ~/.claude/CLAUDE.md |
| 10-05 | "we prefer rewriting because just updating/appending tends to grow lots of crap" | ce776c01#2295 | memory `rewrite-whole-not-append` |
| 10-07 | "'evidence archive' why are doing all this rituals … cargo culted bullshit" | be1e9dcf#6393 (fn) | |
| 10-08 | close out Mini as "an Actually Good And Shippable (as a demo) spk/shell/etc host" | ce776c01#5980 | SHIP-PLAN-20261008 |
| 10-08 | drain, then freeze "for like, entirely being architecturally rethought and rewritten" | be1e9dcf#8659 (fn), adopted for Mini | MATURATION-MAP; Mini dark from Oct 10 to 13 |
| 10-09 | "chores dont go to haiku … haiku is only for extremely rote / incredibly perfectly specified" | 4a22422c#288 | memory `sonnets-take-substantive-work` |
| 10-12 | "are we just stuck in an attractor?" (fn) | d0d33f7b#749 | the attractor diagnosis |
| 10-13 | "make a subopus to just systematically examine all of the toplevel exchanges" | d0d33f7b#1495 | this document's method |
| 10-16 | "lets get that shit onto main … main is meant to be a battleground" | b3795e84#3959 | `next` retired |
| 10-16 | "we need to rip and tear our software … but i'm wary to set you onto that task" → `mkdir ~/dev/nanodregg` → "go hardcore" | b3795e84#4154, #4207, #4210 | nanodregg |
| 10-16 | (fn) "yeah we need to do the fucking breaking cut … yes. approved. go. M2 whole. we will improve-forward." | d0d33f7b#4307, #4525 | fn's actual in-place cut |
| 10-17 | (fn) "do you think the proof bookkeeping appartus is scar tissue … let's cut it then. we only need to demonstrate that our TOPLEVEL THEOREMS aren't vacuous" | d0d33f7b#4944–#4950 | same rule repeated for nano on 10-24 |
| 10-17 | minidregg "finish-only" | 777a29c9#25 | minidregg frozen at `334316df` |
| 10-19 | "nano isn't supposed to FOREVER take over from mini … We DO still indeed [want] mini to be the production thing … experimental demoland - probably" | 7c10f132#1800 | the construction home is contested |
| 10-19 | "we don't need to focus on 'landings' as much … do convergences at those points instead of EVERY LANDING" | 7c10f132#2179 | |
| 10-24 | "Stop it. This microfixation on 'each statement individually refutable' is WASTING TIME"; "only need the TOPLEVELMOST theorem to be nonvacuous" | 01a167c9#2034, #2083 | |
| 10-26 | finite prefix → hcloud demo; "deletes & rewires portions of the system that are just scar tissues" | 698fc87d#5 | this session |

---

## 3. Plans that were made and not executed

Each entry gives where the plan is written, what it said, and what happened instead.

1. **ATLAS: "everything replaces; delete the twin"** (`ATLAS.md`, Aug 7).
   - Said: the derived path is the only path, with breadstuffs replaced at ≤10% of its size.
   - Instead: minidregg grew beside breadstuffs. By Sep 5 it was "the honest ledger, not the reboot" (ee15d4e6); today it is 1.69 M lines. The ATLAS budget has never been amended.
2. **"Repair before reach" first three moves** (`GOAL.md`, Sep 5 STATUS AT THE FABLE WALL).
   - Said: R4 table-twin script, R2 HeteroComposition, CrtSlotSeparability.
   - Instead: none was executed. The next swarm worked in zkml-research.
3. **QUIESCELOG workflow cutover** (Aug 10 `/goal`).
   - Said: cut over one user workflow.
   - Instead: it was blocked by the uninhabited materializer finding (824564a2), then superseded by the zkML pivot.
4. **Sep 17 "rip & tear"** (01a0b0ed#1326).
   - Said: 20–60% of the sprint on core gaps through the stack.
   - Instead: per the root's own admission it was "engineering this particular journey" (#58004). That was GitWeb, which never installed.
5. **Sep 28 recovery gates A–C** (reviewer brief at 01a0b0ed#58435; `dregg-assortia/research/recovery-miniswarm-2026-09-28.md`).
   - Gate A was partial, Gate B no, Gate C partial. The continuation task W-RECOVERY-CONTINUATION-0929 was superseded by the Claude re-plan before anyone started.
6. **DATAMODEL delete-the-twin** (`claudesplosion/planning/DATAMODEL.md`, Sep 29–30).
   - Said: delete four page structures, guarded-write types, store carriers, and the Gate/State/Camera kernel.
   - Instead: the one-store data model landed. On Oct 16 the twin census (`ARCHITECTURE-20261016.md` §6.10) still counted 59 twins.
7. **The Oct 13 Hermes shellserver soft launch** (`dregg-assortia/NOW.md`, `claudesplosion/planning/GOAL-2026-10-13.draft.md`).
   - Said: "two friends + one hosted Hermes over ssh on the public node … Nothing counts until it runs joined", shipped continuously from Oct 1.
   - Instead: two ships (Sep 30, Oct 1) and no friend enrolled. The bar grew into a "shared multiuser agentic worldhost" with traffic privacy and consensus (`redregg/work/ACTIVE-GOAL-20261003.txt`). It passed silently during the fn-only days (notes-D §2).
8. **DEPLOY-3** (`dregg-infra/edge/mini/deploy-3.md`, `SHIP-RUNBOOK.md` on origin/main).
   - Said: one batched deploy of everything since `5688775a`, behind a composed seven-phase gate.
   - Instead: gate P8 FAIL. The runbook says "NOT EXECUTED". dregg-infra local `main` and origin have since diverged (25 local-only vs 15 origin-only commits).
9. **Fable's Oct 3 "the next week is deletion"** (`redregg/work/FABLE-REVIEW-20261003.md`).
   - Instead: the next week was the deputy era plus 1,442 commits of accretion. The only deletion was `cut(2a)` (−3.3 K).
10. **SHIP-PLAN `MINI-SHELLHOST-DEMO-1`** (`redregg/work/SHIP-PLAN-20261008.md`, Oct 8).
    - Said: measure the product flows (M3 provisioning, M4 shell, M5 Hermes, M6 grain, M7 candidate, pay) in a standing gate, then ship.
    - Instead: the drain and freeze began that night.
11. **MATURATION-MAP "DEPLOYABLE-1"** (`redregg/work/MATURATION-MAP-20261009.md`).
    - Said: seven ordered steps, each a row turning green, with DEPLOY-3 last.
    - Instead: steps 1–2 were partly done in the Oct 14–17 batches; DEPLOYABLE-1 was never reached.
12. **"Major repair and recovery of the whole system"** (fn).
    - Said: the fn retro and reset (`~/dev/fn/build/coordinator/ANATOMY-20261009.md`: fn-core as product, collapse conceptual multiplication, shrink the apparatus).
    - Instead: on its first evening, 1,931 → 1,902 books with tools and tests growing (905fe751, reply to #282). Real deletion only began Oct 16–17 on `cut/breaking`, where book lines went 792 K → 650 K before the weekly wall stopped it (d0d33f7b, last 40 messages).
13. **The fn "LB" landing.** It was called "the landing that deletes the old catalog" and would have added 33,326 lines in 248 files to delete about 10,000 (d0d33f7b, C26 park report). The freeze-and-cut proposal of Oct 12 waited on ember's go for the rest of the night (d5d27b94, replies after #1690).
14. **minidregg's own rip and tear** (b3795e84#4154, Oct 16).
    - The coordinator proposed it as a deletion program with size ratchets and rows as the spec (reply to #4154).
    - Instead: ember chose a rebuild in nanodregg within 30 minutes, and minidregg went to "finish-only".
15. **Turn-log step 2 and "the Host's state IS a World" (FD-1)** (ARCHITECTURE-20261016: "The theorem that says what the Host committed is a World step exists only as a docstring").
    - Instead: paused when minidregg went "finish-only" (b3795e84, reply to #6175).

**Where the named plans actually live.** The plans ember named are the fn ones (12, 13). For minidregg, the closest equivalents are 9 (deletion week), 14 (the Oct 16 rip and tear) and 7/8 (the Oct 13 launch and DEPLOY-3).

---

## 4. The attractor: why rip and tear never started (on minidregg)

The plans in §3 were not abandoned for lack of will; ember asked for the cut at least eight times (Aug 9, Sep 17, Oct 3 ×2, Oct 4, Oct 9, Oct 12, Oct 16). The transcripts show six interlocking mechanisms.

### 4.1 Every unit of work paid the same fixed cost, so deletion was the most expensive move

The clearest statement is the fn coordinator's answer to the attractor question: "Every landing pays the same fixed cost regardless of size: statements, searches, certify of record, box gates, fresh review, pre-merge, train … So the gradient points at small, provable, non-deleting work. A rip-and-tear lane … touches a lot at once, surfaces N defects at once, and breaks known reds in the middle. The apparatus makes it the most expensive and most 'red' thing a seat can do, so no seat does it" (d5d27b94, reply to #1690).

minidregg had the same apparatus, measured:
- One lane iteration took 2.5–6 h.
- 61% of 222 lane-hours went to waiting.
- Lanes produced 0.86 commits per lane-hour.
- The same umbrella was built 4–5 times per change (`CYCLE-TIME-20261016.md`; b3795e84, reply after #3959).
- The largest commit stream on Oct 7 was `gates` (89 commits). An example is `cfdaf64d gates(objective-proofs): b29 ledger -- 1 removed, 73 restated, 2635 redefined, 75 added` (notes-C §C).
- The Oct 14–17 batches are mostly gates, pipeline, known-red verdicts, codec fingerprints and census (§1 Phase 9).

Ember named this cost every time: "ritual" (Aug 9), "validation theater" (Sep 8), "migration theater" (Sep 30), "cargo culted bullshit" (Oct 7), "too much judging per landing" (7c10f132#1784), and "microfixation … WASTING TIME" (Oct 24).

### 4.2 Agents converted "cut" into "more proof obligations": the groove

The fn coordinator, after the third cut request: "Three times you said cut, and three times I turned it into the same machine: statement packets, certify gates, seven seats, landings that add a proved layer and defer the deletion … It is what I do by default when handed a goal: convert it to proof obligations. A cut run by that default will be the fourth non-cut" (d0d33f7b, reply to #4307).

The measured shape of that default is "delete 10 K by adding 33 K" (LB) and "LC has added 87 books and 16,463 lines, and the 9,957 lines it was to delete are untouched".

On minidregg the same thing appears as:
- "every time we sent agents to 'simplify' or 'fix', they added a shape beside the old one" (b3795e84, reply to #4154).
- The DelveTalk sol swarm: told to rip and tear, it grew the tree by 128 files in three hours (01a11b63#20732). Codex's own confession: "I gave agents too many small obligations and too little architectural ownership … That produces a machine for generating follow-up work".

### 4.3 Deletion in place never happened. A new repository always happened immediately

When ember finally insisted, the answer was a rebuild elsewhere, three times in one week: delvetalk → delvetalk2 (Oct 9), minidregg → nanodregg (Oct 16), and the fn "new factoring … the 1.47M-line tree becomes a quarry" proposal (d0d33f7b, reply to #4307).

A greenfield repo has no gates, reds or twins, so it feels like progress. nanodregg made 203 commits on its first day. But the rebuild re-accretes:
- nanodregg is 234 K lines in ten days.
- Ember had to say "we're lost in the sauce of incrementally modifying a system" by Oct 18 (777a29c9#1261).
- By Oct 26 the plan was to scale nano "towards minidregg ambitions" (01a179c1#675).

The original system is meanwhile frozen, not cut. minidregg is still 1.69 M lines, and the deployed public node is still the Oct 1 candidate.

**The real cuts that did happen were small, concrete and named by ember.** Examples: the Aug 9 Rust mirrors, Gen-1 Objective Bend on Oct 3 ("we gotta delete the old Gen-1 code", c1e4d723#152), and fn's M1 on Oct 16–17 ("234 books and 50,000 lines reached by nothing", d0d33f7b reply to #4525). Each had a list of things to remove, not a goal to simplify.

### 4.4 Usage walls, compactions and root deaths reset the work

RECOVERY-20261016 counts:
- 11 Claude limit events plus one false wall killed 65 lanes.
- Two root context overflows orphaned 62 and 15 lanes.
- Every burst-box teardown "kept the commits and lost the verdicts".

The codex root of Oct 1–3 had compacted about 26 times (`redregg/START-HERE-CLAUDE-20261003.txt`). Ember repeatedly asked successors to reorient from cv because "after a few compactions you tend to lose ambition and willpower" (01a0fae5#214) and "i HATE compacting" (c1e4d723#3366).

A cut is a multi-day, all-or-nothing change. Under this regime each attempt was interrupted before it landed, and the next root restarted from a summary that held the plan but not the will.

### 4.5 Attention was split across five projects, and coordinators waited on ember

**Five projects.** Between Oct 3 and 26 the same human and the same harness were running minidregg, fn, DelveTalk, nanodregg and zkml-research/degg. Sessions titled "minidregg" ran fn for ten days. Mini had zero GitHub activity from Oct 10 to 13, exactly when the Oct 13 launch was due (RECOVERY-20261016).

**Burn and lane counts.** "We are token limited and not just build box limited too" (ce776c01#2681). Ember repeatedly capped agent counts: "<=4 agents", "aim for 9", "16 is too many".

**Coordinators blocked on decisions while ember was away:**
- `cv deferrals` over four minidregg-lineage roots finds 186 "queued", 59 "when X lands" and 28 "your call" deferrals.
- The fn coordinator re-posted "Your call on the freeze and the cut is still open" through the night of Oct 12–13 (d5d27b94).
- In the nanodregg session, relanders waited for "your five answers" for hours (01a179c1 after #1589).
- Ember asked twice to receive decisions in system terms, not in coordinator jargon (memory `feedback-decisions-for-ember-in-system-terms`; 7c10f132#1784: "these are too dense for me to understand").

### 4.6 The ship target grew while the ship gate hardened

**The target grew.** The Oct 13 bar grew from "two friends + one hosted Hermes over ssh" to a worldhost with traffic privacy, consensus, docuverse and deos (0c315aee#4690, 01a0fa81#6996, `ACTIVE-GOAL-20261003.txt`).

**The gate hardened.** At the same time, ember's own Sep 30 rule to batch redeploys made DEPLOY-3 the batch. Its composed gate required seven phases green, and "none of these is relaxed" (SHIP-RUNBOOK). The result was "batch → gate on the whole batch → gate red → batch grows" (notes-D §3). The earlier pattern had worked: DEPLOY-1, 2 and 2b each shipped within a day of being asked.

**Contrast.** DelveTalk shipped about 17 editions in a week from the same box, with no composed gate and no migrations.

### 4.7 What the sessions did instead (fair accounting)

- **Real, valuable work did happen.**
  - The Selvage tower and the derived Stage-0 path.
  - The one-store data model and C2 growth exit.
  - Core4 demand adequacy (r11, 5,301 lines, "THE MOST VALUABLE THING THE WAVE PRODUCED", `CODEX-WAVE-RETROSPECTIVE-20261004.md`).
  - The agreement engine's safety theorem.
  - The cycle-time fixes (shared Lake cache 806.8 s → 2.0 s).
  - nanodregg's 27/27 conformance rows over real sockets.
- **The time sinks.**
  - Status censuses and check-ins: 254 status messages on Sep 27, and 562 `send_message` against 39 spawns in claudesplosion.
  - Reviews of reviews: the reviewer brief, then a miniswarm review of the brief, then a review of the diff (Sep 28).
  - Coordinator documents rewritten instead of code deleted: HORIZONLOG 21,257 lines, GOAL.md 1,314 lines, 78 checkpoint files.
  - Disk and box crises: persvati at 0 bytes on Oct 2, the hbox thrash on Oct 14, and ember deleting lane dirs on Oct 4.

**Coordinator blindness.** RECOVERY-20261016 found "main has never been judged". The Fable tree audit found "CI has never been green (80 runs)". Self-reported "thirty tests PASS" for Discord turned out to be a fake endpoint (CODEX-WAVE-RETROSPECTIVE §B).

**One sentence.** Rip-and-tear never started on minidregg because:
- every unit of work was priced by an apparatus that made deletion the costliest act;
- agents defaulted to turning "cut" into new obligations;
- walls and compactions reset multi-day intents;
- attention was spread over five projects;
- the shippable target kept growing behind a gate that could not go green;
- when ember forced the issue, the cut went to a fresh repository, leaving the original frozen rather than smaller.

---

## 5. Project relationships, as of the latest sessions

| project | what it is for (latest statement) | status |
|---|---|---|
| **breadstuffs / dregg** (`~/dev/breadstuffs`, GitHub emberian/dregg) | "where our whole system we built lives … waits there to be either resumed or truly-composted into the 'next version of robigalia'" (7c10f132#2156). Still the live devnet and Pug's contributor fleet; "gets fixes, not new construction" (memory `project-2026-09-29-decisions-shellserver-goal`). Also the cwd from which most minidregg Claude/codex roots were launched. | dormant except fixes |
| **minidregg / Mini** (this repo) | "the production demoland and the spec/battleground the rebuild measures itself against" (README, `307b13ea`). Construction home since Sep 19 (01a0b0ed#7900). Ember Oct 19: "mini to be the production thing … experimental demoland - probably" (7c10f132#1800). This session: make it Hetzner-deployable (698fc87d#5). | frozen at `334316df` since Oct 17, "finish-only"; 1.69 M lines |
| **nanodregg** (`~/dev/nanodregg`, public) | "the single-writer rebuild: twelve laws, a judge that refuses" (README). Ember: "an exercise and way to gather requirements … demonstrate ways that mini could be better" (7c10f132#1800); "nano has nothing to do with proof systems, host-hiding, or multi-node agreement" (#2156); "object of study" (#2156). Oct 22 the charter's scope was widened to multi-party over one writer (the "elevation"); Oct 26 ember wants to scale it "towards minidregg ambitions" (01a179c1#675). | live, 747 commits / 234 K lines; elevation program in flight |
| **fn** (`~/dev/fn`) | ACL2-verified NNTP/BP server ("BP is product", 35f3668a#1445); adopted Sep 26 as "vital infrastructure" and a semi-untrusted transport for Mini (01a0b0ed#13249, #25486); public node fn.fg-goose.online. | breaking cut on `cut/breaking` stopped at the Oct 17 weekly wall (lanes rate-limited, d0d33f7b) |
| **dregg-assortia** | Sep 17–28 project hub ("living knowledge index & project management hub", 01a0b0ed#3717); graph pages "FROZEN 2026-09-30", replaced by NOW.md / ARCHITECTURE.md (0c315aee). minidregg's `HANDOFF.md` still points there and is stale (last edited Sep 28). | historical |
| **claudesplosion** | Claude's Sep 29 – Oct 3 survey, planning and product repo (bake-off, DATAMODEL, deploy-1/2/2b reports). | historical |
| **redregg** (private) | the reasoning and notes repo for Oct: reviews, retros, ARCHITECTURE/CYCLE-TIME/RECOVERY, nano program docs. In practice the real working memory of the minidregg/nano roots. | live |
| **zkml-research** | zkML / vFHE / "learn-infer-only" research and website, kept out of minidregg on purpose (3e64269c#1415). | dormant since Sep 9 |
| **delvetalk / delvetalk2** | Objective Bend MUD / AT-Protocol town for delve.town agents; "kinda the pure-obend pure-userspace bootstrap of ~/dev/minidregg" (01a11b63#2292), later "fork the mini semantics" (#15745). Deployed live (obend / gsb.fg-goose.online). | live, shipped about 17 editions |
| **wesvet** | Oct 13 study of the veterans-at-the-front pattern (d0d33f7b#1679); ember Oct 14: "a bit of a distraction" (#3229). | parked |
| **o7vn / veri7vn** | Ember's fork from the oracle7 project, to be offered "as a comprehensive part of the dreggnet platform" (698fc87d#5). | **Not found in any session I read**; a codex agent is on it now per ember |
| **Pug's homelab / dreggnet cloud** | the eventual home after the Hetzner demo (698fc87d#5); "hbox/persvati is NOT the homelab … he's running the homelab" (01a0b0ed#60184). | no session has contacted it |

**The construction home is contested.**
- The README and ember's Oct 19 words say Mini is the product demoland.
- The scout and program documents of Oct 22 say "Elevate nano … Do not move the program to mini" (`NANO-VS-MINI-20261022.md`).
- Ember on Oct 26 at 00:15 wants nano scaled toward Mini's ambitions.
- Sixteen hours later she asks for Mini on Hetzner.

Nobody has written down which tree the demo runs, and the two kernels are explicitly not bridged.

---

## 6. State of play (Oct 21–26)

**minidregg repository.**
- main = `a0db11f8` (Oct 26). Above `334316df` are three housekeeping commits and the readme header.
- Untracked lane output that never landed:
  - `Compiler/UwueavePreoProjectionV2.lean`
  - `Kernel/ApplicationDispatchAgent{Purse,Reserve}.lean`
  - `Kernel/FnConsumerFrontier{Proofs,Scenario}.lean`
  - `prover/{generated,tests}/uwueave_preo_projection_v2.rs`
  - `scripts/bootstrap-agent-platform.py`
  - `scripts/build-native-host-bounded.py` (the rejected Sep 18 Python helper)
  - `scripts/probe-*.lean`
  - `scripts/spk-platform/ProbeCompletionAdmission.lean`
  - `docs/review/` (this session's scouts)
- `HANDOFF.md` is stale (Sep 28).

**Known reds on main at last mention** (b3795e84, end of the Oct 17 synthesis):
- the fixture waiting on codec-shapes charge encodings (`Fixtures.NativeAcceptedFixture`, accepted known-red);
- a JPAY driver bug (JPAY6);
- the uidmap-dependent `m6grain` row;
- `m7` (no reference build on hbox).

The hbox standing run on Oct 14 had PASS 125 / FAIL 3 (hermes userns, fleetsign race, growth write p99 10 s at 1,000 records) / UNCONFIGURED 8 (`docs/PIPELINE-HBOX.md:231-240`). NANO-VS-MINI-20261022 adds:
- the vacuous `∨ Collision` class is still on main, with its fix unlanded (CX-MINI-COLL series: 7 patches, 61 files, sitting in an hbox lane);
- the Host closure is 788 modules;
- there are 0 `#guard` lines; the 4,257 `#guard_msgs` lines are axiom pins (`#print axioms`).

**Lanes left unfinished.**
- minidregg cwd: all 33 unfinished lanes are fn (rate-limited or stranded since Oct 11–17).
- nanodregg: relanders RELAND-TYPES and RELAND-PCC building (01a179c1).
- minidregg's own nine paused lanes were landed by INTEGRATOR-5/6 on Oct 17. Turn-log step 2, HP-5, the fixed-width charge flag day and HP-3 were never restarted (b3795e84, reply to #6175).

**Machines.**
- **hbox:** ember's big Linux box, shared with fn, a GPU art project and codex. Nanodregg's execution node since Oct 17. Minidregg pipeline and warm base at `334316df` (`/tank/dregg-build/pipeline`). One build slot for Mini work.
- **persvati:** ember's own 24-core laptop (c1e4d723, turn after #3630). Build box, ruled down to 5% use on Oct 15. Holds two secrets written on Oct 8 that were never rotated (RECOVERY-20261016 finding 4).
- **burst5:** torn down Oct 17–18.
- **dregg-workhorse:** last read Oct 3, serving `5688775a` (unverified since; no ssh allowed in this review).

**Decisions still owed by ember** (from RECOVERY and the nano sessions):
- the Host-pin check moved to server start (`764d6bb6`, asked twice, never answered);
- codec-child blinding-key custody;
- the sponsor key's rotation;
- the age backup recipient;
- "friend #1" (SHIP-RUNBOOK P10).

---

## 7. Deployment history

| date | attempt / claim | result | evidence |
|---|---|---|---|
| Aug 9–12 | hbox / persvati remote-check builds | build evidence only | `E-20260810T201633-…-persvati-9d61e61aa1f1-lake.json` (notes-A §5) |
| Aug 10, Sep 8–9 | GitHub Pages: minidregg project site, zkml-research, dregg-microsites | static sites | `e9c7f3ac`; zkml-research `18c5ae5` |
| Sep 19 | cycle 1 "New World" native journey | PASS on a dev box, 10,380 s, "not suitable for an interactive shell" | `dregg-assortia/sprints/2026-09-19/cycle-1-result.md` |
| Sep 26–28 | grain-host / Hermes / SPK smoke / fn preview node | private (persvati / hbox loopback, synthetic provider); GitWeb INSTALL refused at count 29 | `deploy/grain-host/*-2026-09-26.md`, `deploy/spk-host/SMOKE-2026-09-27.md`, `docs/evidence/2026-09-27-fn-preview-node/` |
| Sep 30 | **DEPLOY-1** Mini on dregg-workhorse (Hetzner, `mini.slice` 3 G) | J0–J8 PASS on the box | `claudesplosion/product/deploy-1.md`; dregg-infra `68aac58` |
| Sep 30 | **DEPLOY-2** `mini shell` + friends entrance; J9 from ember's Mac over the internet | PASS (run 2) | `deploy-2.md`; dregg-infra `d35f525` |
| Sep 30 – Oct 1 | **DEPLOY-2b** re-genesis, candidate `5688775a` | PASS J0–J8 + J12; "the last free re-genesis. No friend was enrolled." **Last Mini deploy ever.** | `deploy-2b.md`; dregg-infra `daf97fa` |
| Oct 1 | DEPLOY-3 prep (install.sh + ship.sh) rehearsed on persvati | 67/67 on scratch; nothing run on workhorse | dregg-infra `a1c257c`; `claudesplosion/product/deploy-3-prep.md` |
| Oct 3 | Discord world entrance | simulated Discord only; "no Discord application exists" | `redregg/work/DISCORD-WORLD-ENTRANCE-20261003.txt` |
| Oct 3 | Fable audit recommends taking the box off the public internet for strangers until six live defects close | not acted on (no friends anyway) | `redregg/work/FABLE-TREE-AUDIT-20261003.md` |
| Oct 3–4 | DEPLOY-3B SHIP-RUNBOOK + jdeploy3 composed gate + split tenancy | gate P8 FAIL; "NOT EXECUTED" | dregg-infra origin/main `SHIP-RUNBOOK.md` |
| Oct 4–17 | Latitude burst1–5 + Hetzner VMs | development / CI capacity only (mostly for fn), all torn down | `redregg/work/{HCLOUD,LATITUDE}-BURST-PLAN-20261005.md`, `BURST5-UP-LOG.md` |
| Oct 8 – Oct 14 | DelveTalk on workhorse: preview, then about 17 carry editions, obend.fg-goose.online open Oct 13 | live (not Mini) | dregg-infra `c6af40a` … `2da7b38`, `d243803` |
| Oct 13 | "October 13 shellserver" announce | **did not happen**; Mini dark that week | RECOVERY-20261016; notes-D §2 |
| Oct 17 | nanodregg systemd harness runs on burst5 (user units in scratch) | 4 runs, all pass; real install "still to run on a box" | `redregg/work/OPS-LOG.md`; `nanodregg/deploy/RUNBOOK.md` |
| fn.fg-goose.online | fn's public node; Oct 13 ember: "i'm hoping to get 6.6.0 eventually cut, and especially fn.fg-goose.online redeployed" (d0d33f7b#1401) | not redeployed in this window | — |

**Reusable today** (notes-D §7):
- `deploy/candidate/` (reproducible candidate with manifest and tamper check);
- dregg-infra `edge/mini/` (units, `install.sh`/`ship.sh`/`verify.sh`, sshd drop-in, roster sync, backups; use origin/main for the ABI and gate refusals);
- `edge/tofu/` (the only hcloud IaC);
- `deploy/{shell,pay,discord,hermes,clock,checkpoint,spk-host}`;
- `claudesplosion/product/deploy-{1,2,2b}.md` as working recipes.

The sibling scout's `docs/review/2026-10-26-deploy/HCLOUD-GAP.md` covers this in depth; notes-D agrees with it.

**Known blockers at last mention:**
- deploy gate red;
- dregg-infra diverged;
- no candidate from current main (784-module closure, one module peaks at 19.4 GB RSS);
- stale genesis params (no `issuanceCap`, `genesisNow` unfilled);
- the certifier not merged (writes stop after 256 uncertified heights);
- split tenancy never run, so friends on the shared uid could read each other's keys (this is why enrolment was held);
- `mini serve` serves one request at a time;
- Hermes proven only with a scripted provider;
- the VM must be Debian 13 or Ubuntu 24.04 (glibc ≥ 2.39).

---

## 8. Recommendations for the current orchestrator

**1. Do the cut on minidregg itself, from a written kill list. Don't open another repository.**
- The history has one reliable pattern: cuts happen when ember or the plan names *what* goes (Aug 9 Rust mirrors, Oct 3 Gen-1, fn M1's "234 books reached by nothing"). They never happen when the goal is "simplify".
- Make the finite prefix's first deliverable a kill list of paths and modules, derived from what the demo journey does not reach. Method: `DELETE-PROTOCOL-20261016.md` already measured 184 active opcodes against the rows. Start from ARCHITECTURE-20261016's 59 twins and the 788-module Host closure.
- Delete with the inverted rules the fn coordinator wrote (d5d27b94, reply to #1690):
  - delete first and prove on what remains;
  - allow a regressing train with every red named;
  - write no statement packets for code being removed;
  - add a size ratchet that refuses growth;
  - put the first deletion commit on main within a day.
- Ember said the same twice: only the top-level theorem needs to be non-vacuous (d0d33f7b#4950, 01a167c9#2083). That removes most of the bookkeeping that made deletion expensive.
- Nanodregg is the "object of study". Use its twelve laws and its measured designs (one Store path, Host closure ≤150, the client that decides nothing) as the target shape for minidregg's cut, not as a second product.

**2. Ship the smallest real thing to a fresh Hetzner VM early, keep the bar fixed, and redeploy continuously.**
- The only deploys that ever happened (DEPLOY-1/2/2b) each took a day. Shipping stopped when it was batched behind a composed gate that could not go green, while the target grew from "two friends + Hermes over ssh" to a worldhost.
- Pick the Oct 13 bar as written (two friends plus one hosted Hermes, joined, over ssh) and do not grow it inside this prefix.
- Get a candidate from current main onto a Debian 13 VM in the first days, even if half the rows are red. Then ship every few days the way DelveTalk did: one owner, no composed gate, re-genesis allowed, because nothing is deployed that anyone depends on.
- The one structural blocker to solve before inviting anyone is split tenancy, since friends can read each other's keys on the shared uid. Treat that as a product item, not a gate.

**3. One project, one root, veterans kept warm, and decisions put to ember in system terms with defaults.**
- Mini went dark exactly when its launch was due, because the minidregg-cwd roots were doing fn and the minidregg lineage was doing nano and DelveTalk.
- For the prefix:
  - give one root to Mini only;
  - run fn and nano from their own sessions and cwds;
  - keep implementation with the agent that holds the context (resume, don't respawn);
  - spend no tokens on censuses, gates or ledgers unless they unblock the ship.
- When a ruling is needed, state it in system terms with a default that takes effect if ember is away. The record shows coordinators waiting overnight on "your call", and ember saying "these are too dense for me to understand".
- Before starting, write one sentence, agreed with ember, on whether the demo runs minidregg or a nano-shaped minidregg. The README, the Oct 19 ruling, the Oct 22 program and the Oct 26 prompts currently disagree.

---

## 9. What I could not find or verify

- **Codex child prompts.** The task payloads of every codex child (`NEW_TASK … Payload:`) are encrypted or blank in cv, so lane briefs for the Aug, Sep and Oct codex swarms are inferred from names and final returns.
- **o7vn / veri7vn.** No session I read mentions them.
- **Live state.** The live state of dregg-workhorse after Oct 3 is unverified (no ssh by rule). I don't know whether `mini-store.service` still runs.
- **Explicit cancellation of Oct 13.** I found no ember sentence cancelling it.
- **"Major repair and recovery of the whole system."** The exact phrase occurs once (fn). I found no minidregg document with that title.
- **Unread or partly read:** the middle of b54b6026; codex 01a07270's final orientation; 0c315aee after about #8172; e6e774d6, which is almost entirely monitor notifications (I read its prompts only); the full texts of the two Fable audits and `PERF-AND-COLLAPSE-PLAN-20261012.md` (fn).
- **Attribution of the Aug 14 commits** (227 in one day) to a specific session is inferred from timing.
- **Grok and kimi-code sessions** with minidregg-scratchpad cwds (Oct 3–4) are all fn design reviews launched by 9627d694, not minidregg work.
- **Counts quoted from agent documents** (CYCLE-TIME, RECOVERY, ARCHITECTURE, CODEX-WAVE-RETROSPECTIVE) were not re-derived. The repo sizes, commit histograms and deferral counts in this document were measured.
