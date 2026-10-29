# demo-path lane: state (lane/demo-path, rewritten whole)

Base origin/main 1baf18816 (local `main` lags). Candidate under test: hbox
/othersys/lanes/integ/candidates/2b8f75dcbf88118fa2674a1bc58e7af33db640ea. Run roots must be SHORT (/ci/dp-NAME):
a run root under /tank/lanes/... made J0's consent die ("failed to fill whole buffer"). Harness = the candidate's
source.tar (src2), not a stale tree. hbox scratch: /tank/lanes/demo-path. All worlds are down.

## Greened
1. Story invite: GREEN. New row in journey.d/jstorygm.sh (six pairs of concurrent invites of one home). RED on
   b26630168 (the walked error, exactly), GREEN on 2b8f75dcb: JSGM 39/39. 8148992f6 on lane/demo-path. Also fixed
   there: the late-enrolment section reassigned L (the log dir).
   The tour's web story rows (story-invite, page-invited, front-notice, join, move, refused) are red on 2b8f75dcb
   (gate TOUR.tsv); the invite page body was not retained, so the cause is NOT found: reproduce jweb-frontend --dry.
5. Public reader warm-at-spawn: already on main (18dc7c645, Helper::warm_public, J-COLD-READ rows). Row not yet run.
Market (root's new item): 27db3d1b7 on lane/demo-path-market (based on lane/spk-fresh): fresh-index.py, fresh-adopt,
   the real featured test (RED for 4 unbuilt FEATURED ids: Davros, DokuWiki, Hledger, wpe8...), INSTALL.md.

## Diagnosed, not fixed
2. OwnTracks: install red was b26630168 predating 3a943f85e (api prefix without slash); GREEN to the page on 2b8f75dcb.
   Its write is still red: POST /pub answers 200 [] under header, query and topic forms, /var/store/last never
   appears (ot-recorder 0.6.9 stores nothing; no error in its log). Needs a look inside the sandbox.
   WordPress: GREEN, lifecycle and typed write (the old wp_insert_post recipe is obsolete).
   Hummingbird: lifecycle green; write red: qualification-write-readback-absent (typed interface, socket.io hit).
3. IPython run-a-cell: not run. 4. Japps owed rows: not run.
