# world/call — synchronous calls between objects

`Calls.obend`: every object pins this package; a method takes the view of its object's declared state and
returns `{result, write}`; its Plan is `call` only (Kernel/ObjectiveCall).

## Native evidence
Admitted on the call route (`scripts/world-native-admit.sh call --route activity --scenario call`, driver
`native/resource-client/world-activity-admit.py`), candidate 203ed84c, scratch world, 2026-10-27, three objects
(counter, relayA, relayB). Publish and creates installed; `counter.deposit(5)` leaves `total = 5` (`docs/evidence/2026-10-27-world-native/call/results.json`). Law: a second call in the same turn is shown the
first's applied write (`relayA.twice(counter, 2)` reports 9 = 5 + 2 + 2, counter 9). Refusal by name: relayA to
relayB back into relayA is a charged failure `reentry` naming relayA, with counter and relays unchanged (height 20
to 21 is the fee only). The full call journey (C1-C11) is `native/resource-client/objective-call-native-journey.py`.
