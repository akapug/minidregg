# world/send — asynchronous sends between objects

`Sends.obend`: a method may yield `send {to, method, args}`, answered in the same turn with `queued {slot}`; the
message is delivered later, by anyone, in its own turn (Kernel/ObjectiveSend).

## Native evidence
Admitted on the send route (`scripts/world-native-admit.sh send --route activity --scenario send`, driver
`native/resource-client/world-activity-admit.py`), candidate 203ed84c, scratch world, 2026-10-27, objects poster,
counter. `poster.post(counter, 4)` installs and queues a message; the counter is still 0 (height 17). The SECOND
subject delivers it (installed, height 18): counter 4, landing once; delivering it again is refused `conflict`.
Refusal by name: a send to a cell with no record is `CallRefusal.notAnObject`. Evidence:
`docs/evidence/2026-10-27-world-native/send/`. The full send journey (S1-S21) is
`native/resource-client/objective-send-native-journey.py`.
