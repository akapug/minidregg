#!/bin/sh
# Fresh grain-host Store: the reviewed workroom provisioner (positive byte
# tariff, grain-birth tariff, member workroom) plus this host's lifecycle
# management identity and completion custodian key in genesis config. It
# births no application: applications are ordinary resource births, and a
# signed package is installed on one by `spk-host grain install`.
#
# Runs as the grain operator (`mini`, never root): residents run as the same
# user, because PrivateOperator requires the operator socket's owner; the app
# identity is a distinct mapped subordinate uid; both parsers drop all caps.
set -eu
umask 077

if [ "$#" -ne 5 ]; then
  echo "usage: $0 NEW_ROOT HOST MINI STORE_BINARY SIGNATURE_BINARY" >&2
  exit 2
fi
ROOT=$1 HOST=$2 MINI=$3 STORE_BINARY=$4 SIGNATURE_BINARY=$5
HERE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO=$(CDPATH='' cd -- "$HERE/../.." && pwd)
# a staged provision.sh resolves its genesis-clock helper from this tree (scripts/workroom/provision.sh)
export GENESIS_PARAMS_TREE="${GENESIS_PARAMS_TREE:-$REPO}"
fail() { echo "grain store: $*" >&2; exit 2; }
for path in "$ROOT" "$HOST" "$MINI" "$STORE_BINARY" "$SIGNATURE_BINARY"; do
  case "$path" in /*) ;; *) fail "absolute path required: $path" ;; esac
done
for executable in "$HOST" "$MINI" "$STORE_BINARY" "$SIGNATURE_BINARY"; do
  [ -x "$executable" ] || fail "not executable: $executable"
done
[ ! -e "$ROOT" ] && [ ! -L "$ROOT" ] || fail "root already exists"
command -v jq >/dev/null 2>&1 || fail "jq required"

mkdir -m 700 "$ROOT" "$ROOT/custody" "$ROOT/source-stage"
"$MINI" keygen --secret "$ROOT/custody/completion.seed" \
  --public "$ROOT/custody/completion.pub" >"$ROOT/custody/completion-keygen.txt"
SPK_COMPLETION_PUBLIC=$(od -An -tx1 -v "$ROOT/custody/completion.pub" | tr -d ' \n')
[ "${#SPK_COMPLETION_PUBLIC}" = 64 ] || fail "completion public key length"
export SPK_COMPLETION_PUBLIC

# Preserve caller-selected operator fields, but refuse conflicting custody or
# management identities: this Store must use the key generated above and tool 8.
if [ -n "${WORKROOM_OPERATOR_POLICY-}" ]; then
  case "$WORKROOM_OPERATOR_POLICY" in /*) ;; *) fail "operator policy must be absolute" ;; esac
  [ -f "$WORKROOM_OPERATOR_POLICY" ] || fail "operator policy absent"
  cp "$WORKROOM_OPERATOR_POLICY" "$ROOT/source-stage/operator-policy-input.json"
else
  printf '{}\n' >"$ROOT/source-stage/operator-policy-input.json"
fi
jq -se 'length == 1 and (.[0] | type == "object")' \
  "$ROOT/source-stage/operator-policy-input.json" >/dev/null ||
  fail "operator policy must contain one JSON object"
jq -n --arg key "$SPK_COMPLETION_PUBLIC" '
  {completionCustodianKey:$key,
   lifecycleManagement:{managementSubject:8,managementKeyId:8008}}' \
  >"$ROOT/source-stage/operator-policy-required.json"
cp "$REPO/scripts/workroom/provision.sh" "$ROOT/source-stage/provision-grain.sh"
chmod 700 "$ROOT/source-stage/provision-grain.sh"

# Explicit fresh-genesis agent allocation. The overlay generates only native
# enrollment/birth/delegation source; it never imports a retained Store or key.
# An absent variable preserves the historical workroom-only provision path.
PROVISION_GRAIN="$ROOT/source-stage/provision-grain.sh"
if [ "${SPK_AGENT_ALLOCATION+x}" = x ]; then
  case "$SPK_AGENT_ALLOCATION" in /*) ;; *) fail "agent allocation must be an absolute file" ;; esac
  [ -f "$SPK_AGENT_ALLOCATION" ] && [ ! -L "$SPK_AGENT_ALLOCATION" ] || fail "agent allocation absent or linked"
  cp "$SPK_AGENT_ALLOCATION" "$ROOT/source-stage/agent-allocation.json"
  chmod 600 "$ROOT/source-stage/agent-allocation.json"
  SPK_AGENT_ALLOCATION="$ROOT/source-stage/agent-allocation.json"
  export SPK_AGENT_ALLOCATION
  # Stable authoring selectors are pinned before genesis. Historical event22
  # and event27 indices are deliberately absent: later native authoring still
  # verifies those exact admitted receipts and current authority.
  SPK_AGENT_TARGETS=$(jq -ce '
    def exactnat: if type == "string" and test("^[1-9][0-9]{0,14}$")
      then tonumber else error("agent selector exceeds exact integer range") end;
    . as $allocation | [.agents[] | . as $agent | .plannedCaps as $caps |
      {legacy:{ticketResource:(.ticket|exactnat),
        packageManifest:($allocation.packageManifest|exactnat),
        snapshotManifest:($allocation.snapshotManifest|exactnat),
        sessionObserve:($caps.sessionOwner|exactnat),
        manifestObserve:($caps.controllerManifestObserve|exactnat),
        enrollmentObserve:($caps.descriptorOwner|exactnat),
        parentTask:(.controller.task|exactnat),
        parentCapability:($caps.parentOwner|exactnat),parentObserve:($caps.parentOwner|exactnat),
        purseTask:(.dispatch.task|exactnat),purseCapability:($caps.dispatchOwner|exactnat),
        purseObserve:($caps.dispatchOwner|exactnat),payerSubject:(.dispatch.subject|exactnat),
        reserveAmount:1,maximumCharge:1},
       grantResource:(.persistentGrant|exactnat),grantObserveCapability:($caps.grantObserve|exactnat)}]
  ' "$SPK_AGENT_ALLOCATION") || fail "explicit lifetime authoring targets invalid"
  export SPK_AGENT_TARGETS
  jq --argjson targets "$SPK_AGENT_TARGETS" '. + {agentLifetimeDispatchTargets:$targets}' \
    "$ROOT/source-stage/operator-policy-required.json" \
    >"$ROOT/source-stage/operator-policy-required-agents.json"
  mv "$ROOT/source-stage/operator-policy-required-agents.json" \
    "$ROOT/source-stage/operator-policy-required.json"
  sh "$HERE/agent-genesis-overlay.sh" "$PROVISION_GRAIN" "$SPK_AGENT_ALLOCATION" \
    "$ROOT/source-stage/provision-with-agents.sh"
  PROVISION_GRAIN="$ROOT/source-stage/provision-with-agents.sh"
fi

# A caller may repeat the required values, but cannot silently replace them.
# Other operator fields survive the merge and the final pinned-config check.
jq --slurpfile required "$ROOT/source-stage/operator-policy-required.json" '
  . as $supplied | $required[0] as $required |
  if all($required | to_entries[];
    . as $entry | ($supplied | has($entry.key) | not) or
      $supplied[$entry.key] == $entry.value)
  then $supplied + $required
  else error("operator policy conflicts with grain-host custody or authoring targets") end
' "$ROOT/source-stage/operator-policy-input.json" \
  >"$ROOT/source-stage/operator-policy.json" || fail "conflicting operator policy"
WORKROOM_OPERATOR_POLICY="$ROOT/source-stage/operator-policy.json"
export WORKROOM_OPERATOR_POLICY

# native-positive-base.sh runs APP_SOURCE from inside its private stage; this
# one only provisions the member workroom and births nothing.
cat >"$ROOT/source-stage/workroom-only.sh" <<'EOF'
#!/bin/sh
set -eu
umask 077
HERE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO=$(CDPATH='' cd -- "$HERE/../.." && pwd)
mkdir -m 700 "$2"
/bin/sh "$REPO/scripts/grain-birth/native-share-member.sh" "$1" "$2/workroom" \
  >"$2/workroom.stdout" 2>"$2/workroom.stderr"
EOF
chmod 700 "$ROOT/source-stage/workroom-only.sh"

sha256sum "$0" "$HOST" "$MINI" "$STORE_BINARY" "$SIGNATURE_BINARY" \
  "$REPO/scripts/workroom/provision.sh" "$REPO/scripts/grain-birth/native-share-member.sh" \
  "$REPO/scripts/application-share-issue/native-positive-base.sh" \
  "$ROOT/source-stage/provision-grain.sh" "$ROOT/source-stage/workroom-only.sh" \
  "$ROOT/source-stage/operator-policy-input.json" \
  "$ROOT/source-stage/operator-policy-required.json" "$WORKROOM_OPERATOR_POLICY" \
  >"$ROOT/source-stage/input-sha256.txt"
if [ "$PROVISION_GRAIN" != "$ROOT/source-stage/provision-grain.sh" ]; then
  sha256sum "$HERE/agent-genesis-overlay.sh" "$SPK_AGENT_ALLOCATION" "$PROVISION_GRAIN" \
    >>"$ROOT/source-stage/input-sha256.txt"
fi

PROVISION_SOURCE="$PROVISION_GRAIN" \
MEMBER_SOURCE="$REPO/scripts/grain-birth/native-share-member.sh" \
APP_SOURCE="$ROOT/source-stage/workroom-only.sh" \
MINI="$MINI" STORE_BINARY="$STORE_BINARY" SIGNATURE_BINARY="$SIGNATURE_BINARY" \
  /bin/sh "$REPO/scripts/application-share-issue/native-positive-base.sh" \
    "$HOST" "$ROOT/base" >"$ROOT/source-stage/base.stdout" 2>"$ROOT/source-stage/base.stderr"

CONFIG="$ROOT/base/workroom/deployment/pinned-config.json"
jq -e --arg key "$SPK_COMPLETION_PUBLIC" '
  .completionCustodianKey == $key and
  .lifecycleManagement == {managementSubject:8,managementKeyId:8008} and
  (has("completionManagement") or has("residentBeginManagement") or
   has("residentClaimManagement") | not)' "$CONFIG" >/dev/null ||
  fail "pinned config lacks the host lifecycle identity"
jq -e --slurpfile policy "$WORKROOM_OPERATOR_POLICY" '
  . as $config | all($policy[0] | to_entries[];
    . as $entry | $config[$entry.key] == $entry.value)
' "$CONFIG" >/dev/null || fail "pinned config differs from requested operator policy"
sha256sum -c "$ROOT/source-stage/input-sha256.txt" >"$ROOT/source-stage/input-recheck.txt"
echo "grain store ready at $ROOT/base/workroom (no application born)"
