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
EVIDENCE=$2
MINI=${MINI:-"$REPO/native/resource-client/target/debug/mini"}
STORE_BINARY=${STORE_BINARY:-"$REPO/native/hyperdocument-link-sqlite-store/target/debug/minidregg-link-sqlite-store"}
SIGNATURE_BINARY=${SIGNATURE_BINARY:-"$REPO/native/credential-signature-verifier/target/debug/minidregg-credential-signature-verifier"}
SOURCE="$REPO/scripts/workroom/provision.sh"
MEMBER_INITIAL_BALANCE=${MEMBER_INITIAL_BALANCE-100}
case "$MEMBER_INITIAL_BALANCE" in ''|0?*|*[!0-9]*) echo "member balance must be canonical decimal" >&2; exit 2;; esac
export MEMBER_INITIAL_BALANCE
test ! -e "$EVIDENCE" || { echo "evidence directory exists" >&2; exit 2; }
test ! -e "$EVIDENCE.source-stage" || {
  echo "private source stage already exists" >&2; exit 2;
}
# Keep exact staged source and input hashes on failure; the sibling stays 0700
# and is never copied into a public artifact. Runtime keys stay under EVIDENCE.
STAGE=$EVIDENCE.source-stage
mkdir -m 700 "$STAGE"
STAGE=$(CDPATH='' cd -- "$STAGE" && pwd)
SERVICE_PID=
cleanup() {
  if [ -n "$SERVICE_PID" ]; then kill "$SERVICE_PID" 2>/dev/null || :; wait "$SERVICE_PID" 2>/dev/null || :; fi
}
trap cleanup EXIT HUP INT TERM

# Preserve the workroom owner/worker law. An explicitly supplied fresh agent
# allocation adds only its tool subjects, each under the same read-or-governed
# birth restriction. Issuer 8 may also create one allocated persistent grant:
# the ordinary source projects its exact post root at birth/<resource>, without
# the grain-backed flag. This is address-scoped factory permission; the lifetime
# source/receiver still checks the grant's full shape, capabilities and witnesses.
FACTORY_PREDICATE='{"type":"any","predicates":[{"type":"eq","slot":"request/subject","value":"7"},{"type":"all","predicates":[{"type":"eq","slot":"request/subject","value":"8"},{"type":"any","predicates":[{"type":"eq","slot":"request/verb","value":"1"},{"type":"eq","slot":"birth/mode/grain-backed","value":"1"}]}]}]}'
if [ "${SPK_AGENT_ALLOCATION+x}" = x ]; then
  case "$SPK_AGENT_ALLOCATION" in /*) ;; *) echo "agent allocation must be absolute" >&2; exit 2;; esac
  [ -f "$SPK_AGENT_ALLOCATION" ] && [ ! -L "$SPK_AGENT_ALLOCATION" ] || exit 2
  jq -e '
    .protocol == "mini-spk-integrated-allocation-v1" and
    .status == "reserved-coordinates-only" and
    (.agents | type == "array" and length >= 1 and length <= 8) and
    ([.agents[].tool.subject] as $tools |
      ($tools | all(.[]; type == "string" and test("^[1-9][0-9]{0,14}$"))) and
      ($tools | unique | length) == ($tools | length) and
      ($tools - (["7","8","9"] + [.agents[] | .controller.subject,.dispatch.subject,.provider.subject])) == $tools) and
    ([.agents[].persistentGrant] as $grants |
      ($grants | all(.[]; type == "string" and test("^[1-9][0-9]*$"))) and
      ($grants | unique | length) == ($grants | length) and
      ($grants - (["7","8","9","10","11","12","99","7003","7503","7901","7902","8001","8301",
        .app,.packageManifest,.snapshotManifest] + [.humans[]? | .session,.descriptor,.ticket] +
        [.agents[] | .session,.descriptor,.ticket] +
        [.agents[] | [.controller,.tool,.dispatch,.provider][] | .account,.task])) == $grants)
  ' "$SPK_AGENT_ALLOCATION" >/dev/null || { echo "invalid fresh agent factory allocation" >&2; exit 2; }
  sha256sum "$SPK_AGENT_ALLOCATION" >"$STAGE/agent-factory-allocation.sha256"
  FACTORY_PREDICATE=$(jq -c --argjson base "$FACTORY_PREDICATE" '
    . as $allocation | $base | .predicates += [ $allocation.agents[].tool.subject |
      {type:"all",predicates:[{type:"eq",slot:"request/subject",value:.},
        {type:"any",predicates:[{type:"eq",slot:"request/verb",value:"1"},
          {type:"eq",slot:"birth/mode/grain-backed",value:"1"}]}]}] |
    .predicates += [$allocation.agents[].persistentGrant | "birth/" + . |
      {type:"all",predicates:[{type:"eq",slot:"request/subject",value:"8"},
        {type:"eq",slot:"request/verb",value:"2"},
        {type:"eq",slot:"birth/count",value:"1"},
        {type:"eqSlots",left:.,right:.}]}]
  ' "$SPK_AGENT_ALLOCATION")
fi
printf '%s\n' "$FACTORY_PREDICATE" >"$STAGE/factory-predicate.json"
# Configuration inputs for the workroom provisioner. Keep actual source hashes
# as run evidence; no baked-in source digest or keyword count is an interface.
if [ -n "${WORKROOM_OPERATOR_POLICY:-}" ]; then
  case "$WORKROOM_OPERATOR_POLICY" in /*) ;; *) echo "operator policy must be absolute" >&2; exit 2;; esac
  jq -se 'length == 1 and (.[0] | type == "object" and
    ((has("grainBirthTariff") | not) or .grainBirthTariff == {base:2,perBirth:1}))' \
    "$WORKROOM_OPERATOR_POLICY" >/dev/null || { echo "conflicting grain birth tariff" >&2; exit 2; }
  jq '. + {grainBirthTariff:{base:2,perBirth:1}}' "$WORKROOM_OPERATOR_POLICY" \
    >"$STAGE/operator-policy.json"
else
  printf '%s\n' '{"grainBirthTariff":{"base":2,"perBirth":1}}' >"$STAGE/operator-policy.json"
fi
cp "$SOURCE" "$STAGE/provision.sh"
sha256sum "$SOURCE" "$STAGE/operator-policy.json" "$STAGE/factory-predicate.json" >"$STAGE/configuration-inputs.sha256"
chmod 700 "$STAGE/provision.sh"
# The provisioner owns enrollment and first-birth phases. No generated shell
# source or insertion anchors are needed for the member or agent allocation.
WORKROOM_PARENT_TASK=7901 WORKROOM_TOOL_TASK=7902 WORKROOM_INCLUDE_MEMBER=1 \
  WORKROOM_OPERATOR_POLICY="$STAGE/operator-policy.json" \
  WORKROOM_FACTORY_PREDICATE="$STAGE/factory-predicate.json" \
  MINI="$MINI" STORE_BINARY="$STORE_BINARY" SIGNATURE_BINARY="$SIGNATURE_BINARY" \
  "$STAGE/provision.sh" "$HOST" "$EVIDENCE"
sha256sum -c "$STAGE/configuration-inputs.sha256" >"$STAGE/configuration-inputs-recheck.txt"
jq -e '.grainBirthTariff == {base:2,perBirth:1}' "$EVIDENCE/operator.json" >/dev/null
jq -e --argjson expected "$FACTORY_PREDICATE" '.factoryPredicate == $expected' \
  "$EVIDENCE/genesis.json" >/dev/null
if [ "${SPK_AGENT_ALLOCATION+x}" = x ]; then
  sha256sum -c "$STAGE/agent-factory-allocation.sha256" >"$STAGE/agent-factory-allocation-recheck.txt"
fi
jq -e '.birth.grainBirthTariff == {base:"2",perBirth:"1"} and
    ([.birth.resources[].target] | index("8301") | not)' \
  "$EVIDENCE/birth-intent.json" >/dev/null

. "$HERE/birth-acceptance.sh"
grain_birth_acceptance
