# demo-path lane: state (lane/demo-path, rewritten whole, 2026-10-29 wind-down)

Base origin/main (local `main` lags). Candidates: hbox /home/hbox/lanes/integ/candidates/<sha> (the old
/othersys/... paths are gone; candidates built there are no longer runnable). Run roots must be SHORT: /ci/dp-NAME
(a long root under /tank/lanes made J0's consent child die). Harness = the candidate's source.tar, not a stale tree.
hbox scratch: /tank/lanes/demo-path (jsgm.sh, tour.sh, budget.sh, src3 = b39563f1 source). All my worlds are down.
hbox memory: the kernel OOM killer on swarm.slice kills fresh worlds' consent child / world-up under the integrator's
Lean host stage; run worlds only in the integrator's quiet window.

## Landed (merged into integration/staging by the integrator)
- 8148992f6 (658536adf): jstorygm concurrent story-invite row. Red on b26630168 (the walked view.bin error), green on
  2b8f75dcb (JSGM 39/39); also fixes the late-enrolment section clobbering the log directory variable.
- 0be1e5b4b (lane/demo-path-web): the tour's web story reds. Cause traced from a captured page: the /tour page's
  operations room printed "this session has no room operations" in a red <pre>; the journey's pre_of read the first
  <pre>, so every story step saw that instead of the invitation. Fix: operations() checks the session's room record
  and shows a note; pre_of skips the ops section. Unit test red with the guard disabled, green with it.
  AWAITING a green journey re-run (story-invite, page-invited, front-notice, join-refused, join, move, refused) on a
  build carrying it.

## Held
- 27db3d1b7 (lane/demo-path-market, on lane/spk-fresh): fresh-index.py, fresh-adopt, INSTALL.md, and the real featured
  test (apps_every_featured_app_id_resolves_to_an_installable_package). RED by design for FEATURED ids with no built
  package yet (Davros, DokuWiki, Hledger; Wekan follows apps/interfaces/*.json); send when those are built and
  /var/lib/spk-fresh/index regenerated (fixture native/resource-client/tests/fixtures/fresh-local-index-2026-10-29.json).

## Open
- 206-GET budget (SandMD route): 206 GETs return 200, GET 207 on returns 403 "refused undisclosed" (hot-path
  age-2b8f.log). Not the ticket lifetime (notAfter 1e9). Every dispatch is a chain turn charged by
  ApplicationDispatchPending.charge (turnBytes = the request's canonical bytes among the dimensions); suspect a
  per-account budget (app ownerBudget 100000, the route enrollment's maxCost, or the member purse). NEXT: with
  budget.sh (fix its unbound `n`), bring up a SandMD route world in a quiet window, GET to the 403, read the retained
  refusal frames and Host stderr for the clause and budget; then make reads cheap/uncharged or size the budget, and
  carry the internal clause to the operator log (logOperatorRefusal exists for submissions; the Ready path's
  `stopped` in Host/ApplicationDispatchReady.lean drops it).
- OwnTracks write: POST /pub answers 200 [] (header, query and topic forms) but /var/store/last never appears, no
  recorder error (ot-recorder 0.6.9). Needs a look inside the sandbox, or the spk-fresh repackage replaces it.
- Hummingbird write: lifecycle green, write red qualification-write-readback-absent (typed interface, socket.io hit).
- WordPress: green (lifecycle + typed write). IPython run-a-cell and the japps owed rows: not run. Public-reader
  J-COLD-READ row: on main (18dc7c645), not run.
