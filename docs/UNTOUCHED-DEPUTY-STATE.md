# Untouched-areas deputy: state (rewritten whole; 2026-10-28 morning, after the 2d8b7ed54 runs; SQLite cause corrected)

Inputs: docs/review/2026-10-27-untouched-areas/{LEAN,NATIVE}.md, docs/review/2026-10-27-blind-spots/BLIND-SPOTS.md Sweep 1.
Each lane: /Users/ember/dev/minidregg-lanes/un-<area> on lane/un-<area>.

## Rules in force (ember; COORDINATION §4 on main)
- Lanes may build, elaborate and run rows again, but ONLY in a warm, incremental tree on dregg-ref or hbox: never the Mac, never a cold build, never a hard-linked build/ dir (seed only .lake/packages). Stop only your own processes, by PID file (or the harness task that started them).
- The integrator fixes the reds it finds in main's build itself; only reds needing a design decision come back to the deputy.
- No Lean on the Mac, ever. Each faerie works only in its own worktree. Never search the filesystem from / or ~ (a whole-disk find overflowed the Mac's file table).
- Statements go directly to the statements auditor (af7a93e7b8ba729d4), copying the deputy.
- Integration is continuous (no cuts). Re-genesis is free (flag days are not held).
- Never kill by pattern; no PID file: tell the coordinator.

## Landed (all on main as of e05a19fe)
un-verify (Generic Simplex gate), un-bend (bend verb + lost reply), un-world (Tally/call/send native; DOMAINS.md), un-assurance (census, Door 11, StoryHistory, Kernel/StoryLaw), un-native-rows, un-moves, un-fixtures, un-seats, un-pb-codec (R8), un-pb-exec (R7/P9), un-pb-seal (R3 whole), un-pb-wal (R2 + five two-step dealers), un-pb-twins 134535c2 (§5.3 deletions, Pool/Cut, AnchorFixture -> real serve, P6 verifier), un-pb-helpers 353a6d11d (Lagrange, Horner, PRG/urandom, Nat cursors, outbox/phase codecs), un-web-front 0da04999, un-effects 2acd8acf (effect Plan kernel, keystone 5e116ec9, pass-11 additions, world apps on the kernel protocol), un-pred-census 44479e30 (Vouchers sweep: every receiver a Kernel.Receiving.Family at receiverVerifier, Ran private with one mint, gate rows receiver-verifier and ran-mint), un-stream-continuity 6544ea37 (hot-route op154 fixed at the cause; statement accepted e0916a53).
- World apps native on candidate 0ce31391 (un-effects-rows; commons split into app + scenarios, policy bound kept): effect 19/19, dues 17/17, bounty 21/21, play 27/27, ballot 27/27, story 25/25, commons 20/20; cohort gates ballot 37/37, dues 49/49, commons 64/64. README native lines + evidence at 20f28ac31 (docs only, sent to the integrator a34bdb948f1cf4796).

## In flight
- lane/un-shared-names (Sonnet a852f5df40229de24): 179494a88 on main (room bind reads room pointer, index and target in ONE batched signed view; jtemplates background writer + split tenancy; seed errtail_ and 600 s story limits). The rebased e4acc9df0 (only jtemplates.sh, strictly stronger rows: exact-ID bindings, one exact backlink) went to the integrator. All 13 jtemplates reds are explained: 12 stale expectations (90562d76c, 1a9ce0663, 433d5bc38, 37ffc2706), and backlinks=0 was the regression 621aded18 fixes. The faerie runs the row on the candidate carrying 25cfb86bd + 621aded18.

## Waiting on others
- Codec pin re-emit (ACTIVITY-RECORD v9): the integrator's full build runs the regen once (its state file).
- japps co-edit row on a candidate carrying the stream-continuity fix; then L13 reruns DDP. Faerie a4e312352a7091f59 fixes forward routed reds.
- L1 merges before editing PayEnrolReceiver/V2 and SubjectKeyRotation (forced edits only from the Vouchers sweep).

## Owed / unowned
- ember's ruling (memory "no hand-written kernel effects"): kernel effects must come from a revived Effects/ derivation engine. un-effects' transfer/commit are hand-written in Kernel/ObjectiveActivity.lean: deferrable for the demo, owed after (EFFECTS.md has the Phase-3 design: EffectSpec widened with refusal, authority demand and frame; the dispatch keystone; the hand arm deleted in the same commit).
- private-backend: three child() Generation derivations (acss, dzk, sh2t) not yet checked for twinship.
- private-backend P6 (lost reply on reserve/burn): open; the verifier exists.
- Tier 2 (after the opening): R1 the in-process MPC as a door. The sibling product deputy (a5a600787670d2be5) now owns the MPC demo door, invite codes, Host request rate, web3.js serializer, grain class slices: not ours.

## Web item (done)
- un-web-front 0da04999: the public front page renders the operator's published document. mini-web-spawn reads /etc/mini/front-doc and passes --front-doc to the public body only; it falls back to the index. Infra writes `welcome` there (demo-vm 3b8e729, run-sheet step 9c); its check line: an anonymous GET / renders welcome. Sha sent to the integrator.

## App market (taken over from L13, 2026-10-28; lane/app-market db312c6f is on main)
Sources: docs/APP-MARKET-2026-10-27.md "State at hand-off"; docs/ROWS-OWED.md §0 and §3.
- Every install on 0ce31391 was refused (op69 claim plan vs BEGIN); the fix 25cfb86bd is on main (81bca08c6), not in 1af366fe9; the first candidate carrying it is the build after 1af366fe9. On it: the batch tables run on fresh worlds (validator), and I own the reds.
- app-writes-2 (Kimi) landed only Etherpad 956b91bff and Hacker Slides 8a3682c3e (merged); HakyllCMS, HackerCMS and OrgTodo are covered by faerie app-market-fixups.
- Tale invite (the demo seed's item 4, decided): the door processor joins every enrolled member to `tale` once per world (lane/un-tale-welcome 19bb968e0, 4/4 filtered on dregg-build, sent to the integrator). Infra seam: story.author is the seed's SEED_HOST (demo: house), README bc6c837ba on main. Infra is now ae95a4eac63b0715e.
- Faeries (Sonnet, recipes now, one run on the candidate): lane/app-market-b5 (agent a0ef59eabda7075b4: FileDrop, Kiwix, Groove Basin, Tube; streamed bodies under the 8 MiB bound or the exact missing method named) and lane/app-market-b8 (agent a13f0bc9626b1320a: IPython kept, Mercurial, MediaWiki, Firefly III) started; briefs scratchpad brief-b5.txt/brief-b8.txt. lane/app-market-b3 6f2bfd3bc pushed (DiagramsNet, EtherDraw, Scrumblr, SwaggerEditor; agent a85d12892ea6de3ca), lane/app-market-b7 d8ee43cdb pushed (2048, PerplexitySudoku, 3DBlockstack, SimpleChat; agent abf203f357754001b; its spk-rpc get_view_info UNIMPLEMENTED = empty ViewInfo change reviewed and accepted), lane/app-market-fixups 299c0cb98 (on main). b3 and b7 reviewed and sent to the integrator for main. Shared brief: scratchpad market-common.txt.
- japps co-edit row: faerie a4e312352a7091f59 runs it on the same candidate (stream-continuity 6544ea37 + 25cfb86bd), then L13's DDP rerun is mine to report.
- Later: bodies > 8 MiB (designed §2b), the member install debit (apps-e2e.sh) into INSTALL.md §4. Each green app (lifecycle + write) goes into FEATURED in native/resource-client/src/apps.rs; target 2-3 dozen.

## Decided
fn out; private-backend stays; Effects/ registry is Phase 3 (EFFECTS.md); dues and six more ride the effect Plan; DreggNet lease cluster parked; Contracts Cuts/Snapshot/Refinements/Futures kept; Pred BoundedQuantifiedView/CoordinationDial kept; twin conflict on un-pb-twins resolved to un-pb-wal 68d9f28e's design (82f3710b).

## Resident / world-start reds (lane/un-ns-owner, Sonnet a6603277e4ffe2d70)
- Journal-ancestor refusal on 2d8b7ed54 (4d933739 `unchanged()` owner 0 vs 65534): fixed on lane/un-ns-owner; start-a then passed bootstrap, namespace entry and journal open.
- op 7 `physical report differs` (controlGroup over 256 bytes): 507d6ce78 (bound 4096) is on main as 76758dba6; its candidate build is armed after 7027e0ace. The japps co-edit row runs on the 76758dba6 candidate.
- wip 25537e481 (lane tip) holds only a refinement beyond 507d6ce78: the bound derived from the naming scheme (317 = uid 10 + Store tag 16 x5 + app/generation 18 digits, under the user manager), `controlGroupWithin` shared by the three report versions, decide-examples (260 accepted, 317 accepted, 318 and empty refused), and a Rust broker test building the longest real path from grains_slice/class_slice/app_slice (= 317). Not needed for any row; lands after the codec-resident fix, elaborated on a box.
- PRIORITY: SQLite `failure 15: locking protocol` (SQLITE_PROTOCOL) at world start is a PRODUCT red, not harness. Cause NOT yet found. It is NOT orphan residents: the codec-resident pairs on hbox are all under 30 min old and belong to live worlds (the coordinator had misread ps etime; none were killed). Leads, handed to a6603277e4ffe2d70: concurrent world-ups sharing mini-operator's HOME consent-anchor state or lock files (/home/mini-operator/.mini/consent-anchors/c-*.lock), or one SQLite database/WAL/-shm shared across worlds or a uid boundary. Fix at the cause (per-world state), with a two-worlds-at-once concurrency test that is red without it. Second, as hygiene only: codec-resident idle exit, exit on parent death, and a PID file inside the world so world-down stops a partial world.
- Until it lands: app worlds start ONE AT A TIME. Killing the existing orphans waits on ember's word (no PID file: not ours to kill).
- Box hygiene: hbox staging (candidate copies, worlds, grain installs) under /tank, never / (85% used); each faerie deletes its own staging dirs when its run ends.

## Coordinator status
Candidate 2d8b7ed54 (/build/candidates/2d8b7ed544100acfaeb9ff2f9b597c31b8cb81e6, READY 05:48) carries 25cfb86bd, 621aded18, e4acc9df0, b3/b5/b7/b8, un-tale-welcome. Runs on it (fresh worlds, one at a time from now): b3 a85d12892ea6de3ca, b5 a0ef59eabda7075b4, b7 abf203f357754001b, b8 a13f0bc9626b1320a, jtemplates a852f5df40229de24 (run4 on dregg-build). japps co-edit (a4e312352a7091f59) is parked with world w2 kept as evidence; it reruns once on the 76758dba6 candidate.

## Next three
1. Read the six runs on 2d8b7ed54 and the validator's batch tables; fix reds (recipes or spk-host); add every app green on lifecycle + write to FEATURED in apps.rs; tell the coordinator when DDP can rerun.
2. b5 (e1458689a) and b8 (bec955336) recipes are on main; they run on the candidate along with jtemplates (e4acc9df0) and japps.
3. Owed after the demo: revive Effects/ so transfer/commit come from the derivation engine (EFFECTS.md); private-backend P6 lost reply; the child() twin check.
