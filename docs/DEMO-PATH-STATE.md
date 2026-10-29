# demo-path lane: state (lane/demo-path, rewritten whole)

Base: origin/main 1baf18816 (local `main` lags by ~1400 commits; always branch from origin/main).
Worktree: /Users/ember/dev/minidregg-lanes/demo-path. hbox is the only Linux box; no candidate yet in hand.

## Queue
1. Story invite (`cannot create .../reads/story-tale/table.N/view.bin: ENOENT`): CODE FIX ALREADY ON MAIN, 53e71b418
   (signed_read swept a concurrent process's in-flight LABEL.NONCE dir; door invite beside seed invite).
   Walked candidate 9bd52317c predates it. Unit test a_read_another_process_may_be_making_is_never_swept exists
   (age rule only). Owed: red-then-green with two concurrent reads on a candidate; narrate follows from invite.
2. OwnTracks / WordPress / Hummingbird writes: e4dad8b6b (diagnostic recipes) is NOT on main and conflicts with the
   recipes rewritten since (b6-hb.py deleted, b4.sh changed). Cause not yet found; needs a live world.
3. IPython run-a-cell: ifaddrs shim b62ccb0f5 is on main; needs a build carrying it; jupyter-exec.py lives on b8 lane.
4. Japps owed rows: bd9318540, dc8d3a733, b65465c72 are on main. Rows unrun; needs a candidate.
5. Public reader warm-at-spawn: ALREADY ON MAIN, 18dc7c645 (Helper::warm_public, J-COLD-READ rows in the tour).
   Owed: the row's green on a candidate.
