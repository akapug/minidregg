# composed-resident.jq: the mini-same-world-resident-binding-v1 composed-inputs.sh writes (jq -n -f);
# testing/journeys/same-world-resident.py validate() is its consumer.
#   $inputs $base           platform-inputs.json; the frame root whose var/lib/mini/store/node is the node
#   $a0 $a1 $witness        authors (a0 founds: the app and room owner) and the provider witness
#   $ownerWorkspace $document  a0's workspace and the connector's document name; connector-authority.py
#                           leaves a0 the simple alias connector-source-<document> of the room's notes
#   $registration $op $acp $acpsha $prov $provsha
{protocol: "mini-same-world-resident-binding-v1", platformInputs: $inputs, base: $base, authors: [$a0, $a1], providerWitness: $witness,
 room: {alias: ($op + "-room"), mode: "adopt"},
 sharedDocumentReference: ($ownerWorkspace + "/refs/connector-source-" + $document + ".json"),
 registration: $registration, task: 8802,
 fixtureAcp: {path: $acp, sha256: $acpsha}, fixtureProvider: {path: $prov, sha256: $provsha},
 requestCounts: [1, 1], preserveOnSuccess: true}
