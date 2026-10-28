#!/bin/sh
# Fresh, source-owned Mini acceptance for a worker creating a content resource
# under a reserved tool grain and a same-generation parent witness.
set -eu
umask 077

if [ "$#" -ne 2 ]; then
  echo "usage: $0 COMPOSITE_HOST NEW_EVIDENCE_DIRECTORY" >&2
  exit 2
fi
HERE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO=$(CDPATH='' cd -- "$HERE/../.." && pwd)
# a staged provision.sh resolves its genesis-clock helper from this tree (scripts/workroom/provision.sh)
export GENESIS_PARAMS_TREE="${GENESIS_PARAMS_TREE:-$REPO}"
HOST=$1
# The provisioner writes absolute paths into the configs it emits (mini refuses relative consent paths).
EVIDENCE=$(realpath -m -- "$2")
MINI=${MINI:-"$REPO/native/resource-client/target/debug/mini"}
STORE_BINARY=${STORE_BINARY:-"$REPO/native/hyperdocument-link-sqlite-store/target/debug/minidregg-link-sqlite-store"}
SIGNATURE_BINARY=${SIGNATURE_BINARY:-"$REPO/native/credential-signature-verifier/target/debug/minidregg-credential-signature-verifier"}
SOURCE="$REPO/scripts/workroom/provision.sh"
SOURCE_SHA=b6281928df02b79fd79825d1b391e33e244900394f9d7ddf02bcea17952827a3
test "$(sha256sum "$SOURCE" | cut -d ' ' -f 1)" = "$SOURCE_SHA" || {
  echo "workroom source changed; review overlay before use" >&2; exit 2;
}
test ! -e "$EVIDENCE" || { echo "evidence directory exists" >&2; exit 2; }
STAGE=$(mktemp -d)
SERVICE_PID=
cleanup() {
  if [ -n "$SERVICE_PID" ]; then kill "$SERVICE_PID" 2>/dev/null || :; wait "$SERVICE_PID" 2>/dev/null || :; fi
  rm -rf "$STAGE"
}
trap cleanup EXIT HUP INT TERM

# This private exact-source overlay changes only the operator-pinned new
# permission tariff and installed factory law. Owner 7 keeps bare birth;
# worker 8 is permitted only by the grain-backed factory mode slot.
# shellcheck disable=SC2016 # Match the provisioner's literal shell variable.
sed \
  -e 's|"signatureBinary":"$SIGNATURE_BINARY"}|"signatureBinary":"$SIGNATURE_BINARY","grainBirthTariff":{"base":2,"perBirth":1}}|' \
  -e 's|"birth":{"genesis":|"birth":{"grainBirthTariff":{"base":"2","perBirth":"1"},"genesis":|' \
  -e 's|"factoryPredicate":{"type":"all","predicates":\[\]}|"factoryPredicate":{"type":"any","predicates":[{"type":"eq","slot":"request/subject","value":"7"},{"type":"all","predicates":[{"type":"eq","slot":"request/subject","value":"8"},{"type":"any","predicates":[{"type":"eq","slot":"request/verb","value":"1"},{"type":"eq","slot":"birth/mode/grain-backed","value":"1"}]}]}]}|' \
  "$SOURCE" > "$STAGE/provision.sh"
test "$(rg -c 'grainBirthTariff' "$STAGE/provision.sh")" = 6
test "$(rg -c 'birth/mode/grain-backed' "$STAGE/provision.sh")" = 1
chmod 700 "$STAGE/provision.sh"
sha256sum "$STAGE/provision.sh" > "$STAGE/provision.sha256"
WORKROOM_PARENT_TASK=7901 WORKROOM_TOOL_TASK=7902 \
  MINI="$MINI" STORE_BINARY="$STORE_BINARY" SIGNATURE_BINARY="$SIGNATURE_BINARY" \
  "$STAGE/provision.sh" "$HOST" "$EVIDENCE"
cp "$STAGE/provision.sha256" "$EVIDENCE/overlay.sha256"
cp "$STAGE/provision.sh" "$EVIDENCE/overlay-provision.sh"
jq -e '.grainBirthTariff == {base:2,perBirth:1}' "$EVIDENCE/operator.json" >/dev/null
jq -e '.factoryPredicate == {type:"any",predicates:[
    {type:"eq",slot:"request/subject",value:"7"},
    {type:"all",predicates:[
      {type:"eq",slot:"request/subject",value:"8"},
      {type:"any",predicates:[
        {type:"eq",slot:"request/verb",value:"1"},
        {type:"eq",slot:"birth/mode/grain-backed",value:"1"}]}]}]}' \
  "$EVIDENCE/genesis.json" >/dev/null
jq -e '.birth.grainBirthTariff == {base:"2",perBirth:"1"} and
    ([.birth.resources[].target] | index("8301") | not)' \
  "$EVIDENCE/birth-intent.json" >/dev/null

. "$HERE/birth-acceptance.sh"
grain_birth_acceptance
