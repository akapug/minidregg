# B3 state (app market batch B3 and the gate blockers it picked up)

Present-state, rewritten whole. Author: the B3 faerie, 2026-10-28, near 500k context.

## Landed (on main)
- B3 table `scripts/spk-platform/market-batches/b3.tsv` and writes `market-writes/b3.sh`, `b3-sio.py`.
  Run on b26630168 (hbox): EtherDraw, Scrumblr, SwaggerEditor pass lifecycle and write; all three are in
  FEATURED (63ff068c2). DiagramsNet is refused by name, "unsupported: declares permissions without a signed
  bridge schema" (0870373ae, non-bridge ViewInfo check); out of FEATURED.
- HackerCMS write: www 404 was the old www socket refusing a /var/www symlink; fixed on main (efdb8563d).
- Pinned-read blocker: 2ae1ccf96 and ccc527405 (on main as 31c96d923 and 7007d5068), the pinned config's
  parent need only be non-writable, not owner-private.
- Composed harness: b332e565c (main 2c2c31d39): the ticket is issued and paid by the creator (manager),
  as apps_worker route() does. It did NOT clear the red (ci-349d fails at the same place).
- Stage names in the grain share-issue refusal: 9c4db6a19 (main 4b3101fc8).

## Parked (recipe-only, per ruling)
- ExpenseOwl: `PUT /expense`, not POST (the page's own script). WordPress: not installed; the recipe needs the
  install step first. Both unchanged in the tree.

## Open: composed apps:sheet (`mini grain-share-issue-submit` refused inside admitNative)
- Evidence (read-only): /build/ci-349d on dregg-build. Issuer = payer = 7, source cap 41, one key (7007, epoch 2)
  signs all plan slots and approvals. Heights equal: plan height 127 = genesis 10 + 117, store head-anchor last
  written 15:39:59, plan 15:40:07.9, submit 15:40:10.4: no accepted turn between plan and submit.
- The three earlier store.log lines (stale-target, audienceTransition, fieldNotNamed) are the documents phase's
  deliberate negative rows, not the ticket issue.
- AWAITING: the stage line from main 9bd52317c's composed run (first build carrying 9c4db6a19). The integrator
  (a34bdb948f1cf4796) sends the store.log line. Then:
  - "app delegation prepare" or "app delegation check": the member owns the app, the manager lacks its
    .delegateObject; fix the harness so birth_app gives the manager the delegate capability through the worker's
    birth path (not member-pays provisioning).
  - "grain birth admission: <Reject>": a law clause; send the deputy (a308118209b4a48ea) the exact constructor
    first, change nothing.
  - "source descriptor differs": see the statement item below, but heights matched in ci-349d so look elsewhere.

## Statement item (lane/un-share-window-statement, scratch/ShareIssueWindowStatement.lean)
Admission rebuilds the ticket descriptor at the SUBMIT height (ambient.height = genesisHeight + accepted-turn
count) and demands equality with the plan-height one (ApplicationShareIssueSource.lean:215-216 notBefore/notAfter,
ApplicationShareIssueGrainAdmission.lean Accepted.sourceDescriptor). A busy room refuses. The statement relaxes it
to PlannedWithinWindow (some p, p <= h < p + lifetime, descriptor = rebuild at p). Not the cause in ci-349d.
Rulings: keep p existential; add a determinacy lemma (notBefore in the grants equals p); check the app
delegation leg's use of the height; replace the placeholder with the real Accepted change; elaborate on dregg-ref
in my own worktree as lanes; send the elaborated sha and file:line ranges to the statements auditor
af7a93e7b8ba729d4, copying the deputy.

## Boxes and rules in force
- hbox: flock -o /tank/lanes/world-up.lock for world-up only; staging under /tank/lanes/<lane>; no
  /build/candidates deletion; stop only by PID file. dregg-build is the integrator's, off limits to runs.
- dregg-ref: lake and git as lanes only, in my own worktree; never in /build/minidregg; lane-check takes
  closure-lock itself. My worktree there (b3-elab) was removed; a new one is needed for the elaboration.
- Context: stop at about 580k with this file current.
