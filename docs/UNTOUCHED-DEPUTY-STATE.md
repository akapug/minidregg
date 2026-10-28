# Untouched-areas deputy: state (rewritten whole, 2026-10-28)

Read this whole before dispatching anything. (A resume once spawned a duplicate japps faerie before reading it.)
Inputs: docs/review/2026-10-27-untouched-areas/{LEAN,NATIVE}.md, docs/review/2026-10-27-blind-spots/BLIND-SPOTS.md Sweep 1; docs/APP-MARKET-2026-10-27.md; docs/ROWS-OWED.md §0/§3.

## Rules in force
- Integration is continuous; the integrator (a34bdb948f1cf4796) merges lane shas, builds main on dregg-build, names candidates, and fixes reds in its own build. Re-genesis is free.
- Boxes: dregg-build is the integration box only (OOM at 08:57). Faerie world runs and builds go to hbox under /tank/lanes/<lane> (never /, 85% used); each faerie deletes its own staging when done. Lean closures only on dregg-ref through `closure-lock swarm-build <cmd>`. Warm incremental trees only; seed only .lake/packages; no Lean on the Mac; never search from / or ~.
- hbox world-up: `flock -o /tank/lanes/world-up.lock <world-up>` (world-up phase only; plain flock leaks the fd into long-lived servers and wedges the lock). Shared with the rows validator (a373556d56d56744d). hbox umask 0002: `chmod -R go-w` staged deploy/ and bins before world-up. Substitute operator on hbox: MINI_OPERATOR_UID=1000 (user hbox has NOPASSWD sudo).
- Kills: never by pattern. A process is stopped by its PID file. STANDING (coordinator): a faerie may stop its OWN world's surviving residents by exact PID after that world's world-down, once each command line names that world.
- Statements go to the statements auditor (af7a93e7b8ba729d4), copying the deputy.
- Context: continuation file by ~580k tokens, distill/hand off at ~600k (deputy and faeries).
- Intake budget is not raised; if quiet-box installs starve again, the product change is a progress-based intake timeout.
- Not ours (sibling product deputy a5a600787670d2be5): invite codes, Host request rate, web3.js serializer, grain class slices, the MPC demo door.
- Owed after the demo (ember): kernel effects come from a revived Effects/ derivation engine; un-effects' transfer/commit are hand-written (EFFECTS.md has the Phase-3 design).

## Candidates
- b26630168 (conversion, fresh genesis): /build/candidates/b26630168b63024c9c46311745fa0b25fa09c13f. Runs below are on it.
- 349e59ef1 READY: /build/candidates/349e59ef1647fb04bd9cb051012d14f6bf86d271 (fresh genesis; the rehearsal candidate). Carries hosted install + pinned read (7007d5068), HackerCMS /var/www hop (efdb8563d), public reader, `delegate observe 0`, FEATURED 27. Gate running (integrator sends the verdict). Handed to B5 (OwnTracks + b2/b4/b6 recipe reds), B8 (IPython strace), japps-rows confirming run, infra demo-dry confirmations.

## Running now (each reports on events)
- japps rows: OWNER acec1de6f1c53a04c (the original faerie). a16c6e6a2655a4ca9 was a DUPLICATE spawned after a resume: it finishes jr-run1 on its w5 world, sends rows to both, tears down, stops (its 9acb2317e and 6566216c8 stay). lane/un-japps-rows, hbox /tank/lanes/un-japps-rows on b26630168. Rows owed ON MAIN in japps.sh: (1) restart then write with no manual enroll (World::enroll after every START, bf5ead3fa) plus a separate `apps renew` row with the stale-generation refusal by name; (2) fresh-world `apps bootstrap` then first member install admitted (parent `reserve 1` fits its birth law: witnessTouchState wants gen 1, status 3). The bootstrap birthStale is a PRODUCT red, not timing: `apps bootstrap` authored its two-task birth from genesis, and the birth window admits only within 64 heights, so every world past ~h64 refuses it (demo-dry passed only because it was young). Fix 6566216c8 (apps.rs: Host authors the birth at the current height via current-resource-intent, as `workspace create` does; L4c's 6325a6045 is the same cause for grain-runtime create). Run w5 with that `mini` (bin2) queued on the lock; then funding from tariff + measured debit + margin with spend-over-funding refused by name, crediting 777096dc/3eefbe6d; one commit set, sha to the integrator.
- B3 a85d12892ea6de3ca: B3 table on b26630168 (EtherDraw, Scrumblr, SwaggerEditor; DiagramsNet stays refused by name, "unsupported: declares permissions without a signed bridge schema", out of FEATURED, ruled).
- B7 abf203f357754001b: rt world on b26630168. WBO: write read a nonexistent route; recipe now reads /download/<board> (783f8c84b, hook text a0d37f410), WBO-only confirming run in flight. Wekan: lifecycle PASS (887 s), write red on grain-route latency (login rendezvous XHR), no recipe change. TextEditor write likewise blocked on latency only.
- B8 a13f0bc9626b1320a: IPython kernel dies with EAFNOSUPPORT ("Address family not supported", tcp_address.cpp:161); seccomp.rs refuses AF_NETLINK with exactly that errno; inference: libzmq getifaddrs. NO policy change yet: B8 proves it on 349e59ef1 (strace of the kernel's socket calls + the kernel connection file's ip/transport) and names the narrowest fix (none / app config / NETLINK_ROUTE only with protocol filtered, and whether the grain holds CAP_NET_ADMIN in its netns). A sandbox widening goes to the coordinator first. Harness 20f2ea776 collects journals + app output on a red. HedgeDoc / HedgeDocRT socket.io close frame unexamined.
- Grain-route latency: a6603277e4ffe2d70 (~420k), lane/un-route-latency (4d136bed). Every request through the grain route costs 6-13 s inside author_and_submit (GET / ttfb 12.7 s without a websocket, so per request); TextEditor's /.sandstorm-login needs < 10 s. Fix at the cause with a timed POST row under a budget, red first.
- Parked, waiting for the next candidate: B5 a0ef59eabda7075b4 (OwnTracks re-qualify, Lean fix 3a943f85e not in b26630168; ExpenseOwl 405, WordPress REST nonce, HackerCMS www 404, Hummingbird get-m 22, one world at a time). Story faerie acf88647b53657831 idle.

## App market (taken over from L13)
- japps --box on b26630168: 29/29 (a4e312352a7091f59, retired). Co-edit over DDP (hot route admitted), Hacker Slides publish + write after restart and enroll-a2 (japps.sh:238 is the manual renew), Etherpad, export, qualify/signature, tampered copy. JAPPS-STATE.md at lane/un-stream-continuity f0df4bc24. Recorded with the rows validator for ROWS-OWED §0.
- FEATURED (native/resource-client/src/apps.rs) is 27 on main; target 2-3 dozen. An app enters on lifecycle + beneath-HTML write green, one commit each, filtered test count = real length.
- Green and featured: Etherpad, Hacker Slides, EtherCalc, DokuWiki, Datasette, HedgeDoc (lifecycle), Davros, sntfy, HledgerWeb, Mercurial, MediaWiki, Firefly III, FileDrop, Kiwix, Groove Basin, Tube, 2048, Perplexity Sudoku, 3D Blockstack, Simple Chat, and the earlier set (see apps.rs).
- Other passes recorded by the validator (ROWS-OWED §0): SandMD, Permanote, Dillinger, YetAnotherTODO, Hugo, HakyllCMS, SandForms, Badgepack, Gogs (l+w).
- Open market reds: listed under "Running now" plus SandCal / HackerCMS / HakyllCMS "SPK staging remains" (load-sensitive; un-ingest-stale-stage 1f9a757de on main expected to close it; recheck one world at a time) and OrgTodo ingest timeout (starvation).
- Later: bodies > 8 MiB (APP-MARKET §2b), the member install debit into INSTALL.md §4, Cap'n Proto-native apps.

## Landed on main (verified; history only)
Generic Simplex gate; bend verb + lost reply + seed (14adcc13a); world apps native (Tally/call/send; effect, dues, bounty, play, ballot, story, commons on the effect Plan kernel; cohort gates green); Assurance census, Door 11, StoryHistory, Kernel/StoryLaw (+ namespace pin 523163eee); native rows; moves/deletes; fixtures; seat lock; private-backend R2/R3/R7/R8, twins, helpers, child()/Generation::derived, P6 (ee908664b); un-effects; Vouchers sweep (un-pred-census 44479e30); stream continuity (op154 hot route); shared names (one batched view; jtemplates 196/196); story GM install (a8376ce8f, JSGM ef055c952); tale welcome; front-doc; public reader (6d59cde34, 86ad31dd3, 2add39053); poisoned consent reconnect (0b88b837f + b71898658; our 02a03960f dropped as a twin); pinned read (ccc527405); un-ns-owner-clean 3a8109059 (317 bound, resident fds, in-world PID files, stop-residents, bounded SQLITE_PROTOCOL retry); journey repeat suffix 789b9b478; anchor label 391311929; un-enroll-renew bf5ead3fa (stale-generation refusal, World::enroll, apps renew, bootstrap activation, --dir fix); market install docs/unit 886c43dfd; spk-host io context 5cb33bbdf; nonbridge refusal 0870373ae; importProfile 50ec8de76; featured-qualify owner allAccess 817e8c7f1.

## Open, recorded (do not re-ask)
- SQLite failure 15 at world start: OPEN in ROWS-OWED (e80f56422); not reproduced (3 tries x 6 world-ups); WAL-retry hypothesis; bounded retry on main. The flock stays the rule.
- Effect-record codec pin re-emit (ACTIVITY-RECORD v9): the integrator's build runs the regen.

## Next three
1. Read the b26630168 results as they arrive (japps rows, B3, B7 rt, B8 IPython); fix reds through the faerie holding the context; greens into FEATURED; shas to the integrator.
2. On the rehearsal candidate 349e59ef1: confirm with infra (a298031c78e86d651) that hosted `apps install`, the public reader and the story seed pass in demo-dry; then B5's OwnTracks and recipe fixes on the next candidate.
3. Grain-route latency fix (a6603277e4ffe2d70); then TextEditor's write and the HedgeDoc/IPython websocket family.
