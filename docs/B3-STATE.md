# B3 state (app market batch B3 and the gate blockers it picked up)

Present-state, rewritten whole. Author: the B3 faerie, 2026-10-28, handed off at about 550k context. A successor starts from this file.

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

## Open (gate red, product red): the manager signs with a capability the member holds
- delegation-check red: routed to acec1de6f1c53a04c, ruled child capability to the manager. (The B3 faerie does NOT implement it; the japps-rows faerie owns apps_worker.rs.)
- Stage named by main 9bd52317c's composed run (/build/c-9bd523/w/log/store.log:7):
  `application-grain-share-issue: grain-backed app share issue refused: app delegation check` = admitNative
  branch 10, `ApplicationShareIssueDelegation.check`; `authorize` (Kernel/ApplicationShareIssueDelegation.lean:151-159)
  runs `capabilityEvidenceChecked prepared.wanted spec.appDelegateCapability ... signature`.
- Evidence: /build/c-9bd523/inputs/evidence/app-930001/hooks/*/081-cap-head.json: capability 960001 (app 930001; verbs
  observe/mutate/delegate/append/place) is HELD by the member 9382847935541690129; the ticket's issuer and signer is the
  manager 7. So the manager cites a capability it does not hold.
- Product has the same shape: apps.rs:868-884 `app_birth_source` makes the member creator and owner; apps_worker.rs
  `route()` (~1172-1191) passes appOwnerCapability as appDelegateCapability with issuer = the management subject. Works
  only when member = manager (japps may be green for that reason: UNCONFIRMED, check whether the japps member is the
  management subject; native/resource-client/journey.d/japps.sh uses a fake route for alice).
- Ruled (deputy a308118209b4a48ea): issuer stays the manager (Kernel/ApplicationDispatchAdmission.lean:624 requires it at
  dispatch). After `delegate_lifecycle` the member delegates a child of appOwnerCapability to the manager (holder = manager,
  verbs including `delegate`); record its id where `route()` reads it; `route()` and the composed fixture
  (ws-continuity-fixture.py / same-store-app.py `birth_app`, delegate() already supports `by=`) name the child as
  appDelegateCapability. Issuing as the member is rejected.
- Steps ruled: (1) confirm japps member = manager, and if so add a japps step with member != manager, red before the fix;
  (2) the fix with a filtered unit test red-proofed by a planted fault; (3) two-subject japps row on hbox under flock -o;
  (4) push, send sha to the integrator (a34bdb948f1cf4796) as "gate blocker" copying the deputy. STOP and ask the deputy
  first if the lifecycle selector format must change or a new registry op is needed.
- Harness b332e565c (creator as issuer, main 2c2c31d39) stays: it is right and did not clear the red alone.

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

## Statement item status (continued)
- lane/un-share-window-statement d9e31bd5e..3baaa9d73: scratch/ShareIssueWindowStatement.lean has the poles, the
  determinacy lemma, the delegation-leg note and the Accepted change as a comment block. NOT yet elaborated: a worktree
  /build/lanes/b3-elab2 on dregg-ref (lanes) was being seeded (scratch/elab.sh in app-market-b3 worktree; PID file
  scratch/elab.pid); lane-check it there as lanes (takes closure-lock itself), then send the elaborated sha and file:line
  ranges to the statements auditor af7a93e7b8ba729d4, copying the deputy. Remove the worktree after.
- Also queued by the deputy (A-C, after the gate red): the confirming rows; see the deputy's messages.
