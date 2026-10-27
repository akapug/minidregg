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
command -v rg >/dev/null 2>&1 || fail "rg required"

mkdir -m 700 "$ROOT" "$ROOT/custody" "$ROOT/source-stage"
"$MINI" keygen --secret "$ROOT/custody/completion.seed" \
  --public "$ROOT/custody/completion.pub" >"$ROOT/custody/completion-keygen.txt"
SPK_COMPLETION_PUBLIC=$(od -An -tx1 -v "$ROOT/custody/completion.pub" | tr -d ' \n')
[ "${#SPK_COMPLETION_PUBLIC}" = 64 ] || fail "completion public key length"
export SPK_COMPLETION_PUBLIC

# One management identity (subject 8, key 8008: the workroom tool key) for
# every application this host manages. No application is named here.
# shellcheck disable=SC2016 # Preserve the provisioner's literal variables.
sed 's|"storageRoot":"$EVIDENCE/store","signatureBinary"|"storageRoot":"$EVIDENCE/store","completionCustodianKey":"$SPK_COMPLETION_PUBLIC","lifecycleManagement":{"managementSubject":8,"managementKeyId":8008},"signatureBinary"|' \
  "$REPO/scripts/workroom/provision.sh" >"$ROOT/source-stage/provision-grain.sh"
[ "$(rg -c 'lifecycleManagement' "$ROOT/source-stage/provision-grain.sh")" = 2 ] ||
  fail "provisioner shape changed; review the lifecycle overlay"
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
  # shellcheck disable=SC2016 # Expanded only inside the staged provisioner.
  sed 's|"lifecycleManagement":{"managementSubject":8,"managementKeyId":8008},|"lifecycleManagement":{"managementSubject":8,"managementKeyId":8008},"agentLifetimeDispatchTargets":$SPK_AGENT_TARGETS,|' \
    "$PROVISION_GRAIN" >"$ROOT/source-stage/provision-grain-agents.sh"
  [ "$(rg -c 'agentLifetimeDispatchTargets' "$ROOT/source-stage/provision-grain-agents.sh")" = 2 ] ||
    fail "provisioner lifecycle shape changed"
  PROVISION_GRAIN="$ROOT/source-stage/provision-grain-agents.sh"
  sh "$HERE/agent-genesis-overlay.sh" "$PROVISION_GRAIN" "$SPK_AGENT_ALLOCATION" \
    "$ROOT/source-stage/provision-with-agents.sh"
  PROVISION_GRAIN="$ROOT/source-stage/provision-with-agents.sh"
fi

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
if [ "${SPK_AGENT_ALLOCATION+x}" = x ]; then
  jq -e --argjson expected "$SPK_AGENT_TARGETS" '.agentLifetimeDispatchTargets == $expected' \
    "$CONFIG" >/dev/null || fail "pinned config differs from explicit agent authoring targets"
fi
sha256sum -c "$ROOT/source-stage/input-sha256.txt" >"$ROOT/source-stage/input-recheck.txt"
echo "grain store ready at $ROOT/base/workroom (no application born)"
