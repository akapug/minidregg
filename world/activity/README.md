# world/activity — the tally resident

`Tally.obend` (and `TallyV2.obend`, its upgrade): an activity that awaits one answer slot decided by a
named subject; a reply of `amount` is an `add` to the object's declared state `{total: Nat}`, applied by the
kernel to the state the activity was resumed with (never an overwrite). Plans: `await` only.

## Native evidence
Admitted on the ACTIVITY route (`scripts/world-native-admit.sh activity --route activity --scenario tally`,
driver `native/resource-client/world-activity-admit.py`), candidate 203ed84c, scratch world, 2026-10-27.
Publish, create and birth installed (birth transaction
50356855733520666980309516481568153777286778974294617838125534746483861330259, height 14, declared state
`total = 0`, phase awaiting). Law: replies add (5 then 7 gives `total = 12`, generation 2, heights 16 and 18),
the Host's decided outcomes. Refusal by name: a non-decider's resolve is
`Reject.kernel (Refusal.slot (AnswerSlot.Refusal.notDecider))`. Evidence:
`docs/evidence/2026-10-27-world-native/tally-activity-route/`. The wider tally acceptance (exhaustion, timeout,
upgrade) is `native/resource-client/objective-activity-native-acceptance.py`.
