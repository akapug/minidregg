# composed-selection.jq: the mini-spk-same-store-selection-v1 composed-inputs.sh writes (jq -n -f).
# Participants are WORLD inventory names (same-store-inputs.py named_selection resolves them).
# same-store-inputs.py selection_shape is the consumer's field set; tests/test_composed_selection.py
# holds this producer to it.
#   $evidence $grains $broker $spk $sha  the operator's evidence root, the Store's grain root, broker, package
#   $owner $member                       the app owner (also the shared room's owner) and the second session member
#   $op                                  the scenario's operation prefix (the rooms phase's room is "<op>-room")
#   $connector                           null, or {subject, host, ca}: the connector participant and the route
#                                        front's host (HOST[:PORT]) and CA path (null: publicly trusted)
# Allocation: the app takes resources 930001.. (3 app + 3 per member) and capabilities 960001..
# (6 app + 9 per member), as same-store-inputs.py attach lays them out; the connector's session
# takes the next unused block of each.
($op + "-room") as $room
| {owner: {subject: $owner, expectedHost: "grain-owner.test"}, member: {subject: $member, expectedHost: "grain-member.test"}} as $members
| "930001" as $resources | "960001" as $capabilities
| {protocol: "mini-spk-same-store-selection-v1", evidence: $evidence, grainsRoot: $grains, brokerSocket: $broker,
   package: {path: $spk, sha256: $sha}, sizeClass: "S",
   app: {owner: $owner, room: $room, members: $members, resources: $resources, capabilities: $capabilities}}
| if $connector == null then . else .connector = {
    subject: $connector.subject,
    # The route name and the EtherCalc sheet are operator choices; role 1 is the qualified
    # EtherCalc package's signed read-only role (scripts/spk-platform/app-document.md).
    name: "connector", expectedHost: $connector.host, sheet: $op, role: "1",
    # Held reference names in the connector's workspace: connector-authority.py creates the
    # declared task cell and imports the owner-delegated document grant under these names.
    task: ($op + "-connector-task"), document: ($op + "-notes"),
    resources: (($resources | tonumber) + 3 + 3 * ($members | length) | tostring),
    capabilities: (($capabilities | tonumber) + 6 + 9 * ($members | length) | tostring),
    # The independent reader is the app owner reading the room's notes under the name `room new`
    # gave them; connector-authority.py delegates from exactly that reference.
    reader: {subject: $owner, document: ($room + "/notes")},
    endpoint: ("https://" + $connector.host + "/"), ca: $connector.ca, operation: ($op + "-export")} end
