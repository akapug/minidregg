# Event28 observe-only custody preparation

The retained r3 allocation and accepted session births provide each participant's
session/descriptor owner grants. `ApplicationGrainSessionBirth.Ready.grantsCurrent`
gives those object owners observe and mutate verbs. Event28's joint mutation and
three observation requests all use the **participant command subject**. Thus Bob
and Hermes cannot borrow Alice's app/package signing key for their own read slots.

| Participant | Session owner / descriptor owner | App observe | Manifest observe | Ticket observe |
|---|---|---|---|---|
| Alice Web (8) | 147 / 149 | 141 | 143 | 173, delegate from 171 after event22 |
| Bob Web (9) | 151 / 153 | 184, delegate from 141 | 185, delegate from 143 | 183, delegate from 181 after event22 |
| Alice API (8) | 161 / 163 | 141 | 143 | 193, delegate from 191 after event22 |
| Hermes A (10) | 241 / 243 | 274, delegate from 141 | 275, delegate from 143 | 273, delegate from 271 after event22 |
| Hermes B (20) | 341 / 343 | 374, delegate from 141 | 375, delegate from 143 | 373, delegate from 371 after event22 |

The three manifest child IDs are a new append-only overlay; the original r3
allocation and signed births remain unchanged. Event22 births only ticket
owner/control grants, not the participant's ticket observe grant. Each child
grant is observe-only and requires a separate native accepted delegation. The
scripts retain the reviewed parent capability and current signed resource
read, exact prepared call, durable send marker, original-call lookup, and
recipient signed readback. A lost send/lookup reply never triggers another
delegation send.

Operator sequence for each row: run
`prepare-enrollment-observe-overlay.sh ROOT NEW_OVERLAY.json` once; then
`delegate-enrollment-observe.sh prepare ROOT HOST CONFIG MINI SOCKET OVERLAY ROUTE KIND STAGE|- NEW_ATTEMPT HOST_SHA MINI_SHA`.
`CONFIG` is the protected qualified operator configuration, not a presumed
historical fixture file; its absolute path and SHA are retained in the attempt.
For `ticket`, `STAGE` is the exact accepted event22 issuer staging directory;
for `app` and `manifest`, it is `-`. Review the retained `intent.json`, native
`plan.json` and `call.bin` before `delegate-enrollment-observe.sh send NEW_ATTEMPT`.
Use `delegate-enrollment-observe.sh lookup NEW_ATTEMPT` after a successful or
uncertain send. `lookup` may repeat with numbered native and readback attempts;
`send` cannot repeat. Do each grant in its own new attempt directory.

Order for a new Store image: finish INSTALL; author each event22 ticket and
delegate its ticket-observe child; delegate Bob/Hermes app and manifest observe
children; initialize human entrances; START; author event28 against the actual
serving generation; only then dispatch. Event27 additionally needs its exact
accepted event22/grant source checks and may be staged once its ticket read
grant exists. Current r3 has no accepted event22 or these child delegations.

`schema-mock.log` is a scratch transport/schema fixture, not a native admission
or same-Store result. It covers prepare, one send, replayed exact lookup,
recipient readback, interrupted local publication recovery, corrupt cached
readback refusal, changed event22 plan refusal before send, and altered
overlay refusal before a native call. `syntax.log` and `shellcheck.log` are
the narrow static checks. No r3 Store or retained r3 files were modified.
