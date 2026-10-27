Candidate 3315a908, driver native/resource-client/world-activity-admit.py (World from activity_world.py, unforked policy).
Same scratch world, three attempts at the activity route (publish + create installed in all):
 1. entry dues(terms, deposit), birth input a 2-field record
      birth refused: Reject.kernel (Refusal.inputType)   -- the kernel applies the entry to ONE input value
 2. packaging-only entry begin(o: Opening{terms, deposit}) -> dues(o.terms, o.deposit)  (not kept in the tree)
      birth refused: Reject.kernel (Refusal.outcomeProtocol "reply")
      Kernel/ObjectiveActivity.lean loadProgram: the response type must carry a `reply` row;
      outcomeProtocol: the response must be `resumed {outcome, view}` typed for every kernel outcome.
 Dues declares Response = event | settled | refused and yields `pay` Plans.
 Kernel/ObjectiveActivity.lean decodePlan: "the kernel performs only `await` Plans" (write/on/patience).
 So dues' Plan and Response vocabulary are not the activity kernel's; not an entry/packaging difference.
