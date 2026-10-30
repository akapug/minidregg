#!/bin/sh
# Probe an already provisioned, running controller through its real tool API.
# This does not provision authority. A mock runtime tests only this harness.
# Lost replies stop here: retain the request ID and inspect, never resend.
set -eu
umask 077
fail() { echo "Oracle lifetime journey: $*" >&2; exit 2; }
if [ "$#" -eq 4 ] && [ "$1" = prepare-controller ]; then
  run=$2 repo=$3 home=$4
  exec python3 "$repo/deploy/oracle/acceptance/agent.py" prepare-controller "$run" "$home"
fi
if [ "$#" -eq 4 ] && { [ "$1" = prepare-worker-policy ] || [ "$1" = prepare-bootstrap-dispatch ]; }; then
  phase=$1 run=$2 repo=$3 input=$4
  exec python3 "$repo/deploy/oracle/acceptance/agent.py" "$phase" "$run" "$input"
fi
if [ "$#" -eq 4 ] && [ "$1" = issue-grant ]; then
  run=$2 repo=$3 result=$4
  exec python3 "$repo/deploy/oracle/acceptance/agent.py" issue-grant "$run" "$result"
fi
if [ "$#" -eq 4 ] && { [ "$1" = prepare-route ] || [ "$1" = activate ]; }; then
  phase=$1 run=$2 repo=$3 input=$4
  exec python3 "$repo/deploy/oracle/acceptance/agent.py" "$phase" "$run" "$input" --repo "$repo"
fi
if [ "$#" -eq 3 ] && [ "$1" = provision ]; then
  run=$2 repo=$3
  case "$run:$repo" in /*:/*) ;; *) fail 'absolute run and repository paths required' ;; esac
  [ -d "$run" ] && [ ! -L "$run" ] || fail 'run directory absent or linked'
  mkdir -m 700 "$run/agent-lifetime"
  allocation=$run/agent-lifetime/allocation.json
  cp "$repo/deploy/oracle/acceptance/agent-allocation.json" "$allocation"
  chmod 600 "$allocation"
  # Validate the retained allocation before genesis; no provision source is generated.
  sh "$repo/scripts/spk-platform/check-agent-allocation.sh" "$allocation"
  sha256sum "$allocation" "$repo/scripts/spk-platform/check-agent-allocation.sh" \
    "$repo/scripts/workroom/agent-enrollment.sh" \
    >"$run/agent-lifetime/enrollment-input-sha256.txt"
  printf '%s\n' "$allocation"
  exit 0
fi
[ "$#" -eq 5 ] || fail 'usage: RUNTIME CONTROLLER.json APPLICATION CASES.json NEW_EVIDENCE_DIR'
runtime=$1 config=$2 application=$3 cases=$4 evidence=$5
: "${QUALIFIED_RUNTIME_SHA256:?exact runtime binary SHA required}"
: "${QUALIFIED_LIFETIME_HOST_SHA256:?exact source Host SHA required}"
driver=${ORACLE_CONTROLLER_INSTALLER:-}
if [ -n "$driver" ]; then
  : "${ORACLE_CONTROLLER_STORE:?dedicated controller Store required}"
  : "${ORACLE_CONTROLLER_HELPER:?fixed world helper required}"
  : "${QUALIFIED_LIFETIME_HOST_BINARY:?operator-readable identical Host binary required}"
  case "$driver" in /*) ;; *) fail 'installer must be an absolute path' ;; esac
  [ -f "$driver" ] && [ -x "$driver" ] && [ ! -L "$driver" ] || fail 'fixed installer unavailable'
fi
# The optional driver preserves the controller OS boundary. Only its fixed
# tool/result/ack/journal verbs run as that account, never arbitrary commands.
invoke() {
  verb=$1; shift
  if [ -z "$driver" ]; then "$runtime" "$verb" "$@"; return; fi
  case "$verb" in
    tool)
      shift 2 # configured socket and fixed soft mode; installer owns both
      sudo -n -- "$driver" controller-tool "$ORACLE_CONTROLLER_STORE" "$ORACLE_CONTROLLER_HELPER" "$@" ;;
    tool-result|tool-ack)
      shift # installer owns the selected control socket
      sudo -n -- "$driver" "controller-$verb" "$ORACLE_CONTROLLER_STORE" "$ORACLE_CONTROLLER_HELPER" "$@" ;;
    *) fail 'unsupported controller driver operation' ;;
  esac
}
for path in "$runtime" "$config" "$cases" "$evidence"; do
  case "$path" in /*) ;; *) fail 'absolute paths required' ;; esac
done
for path in "$runtime" "$config" "$cases"; do
  [ -f "$path" ] && [ ! -L "$path" ] || fail "regular input absent: $path"
done
[ -x "$runtime" ] || fail 'runtime not executable'
[ ! -e "$evidence" ] && [ ! -L "$evidence" ] || fail 'evidence directory already exists'
sha() { sha256sum "$1" | cut -d ' ' -f1; }
[ "$(sha "$runtime")" = "$QUALIFIED_RUNTIME_SHA256" ] || fail 'runtime pin differs'
jq -e --arg app "$application" --arg host "$QUALIFIED_LIFETIME_HOST_SHA256" '
  .toolTask.lifetimeApiHostSha256 == $host and
  ([.toolTask.applicationServices[] | select(.application == $app and
    .protocol == "oracle-operations-v1")] | length == 1) and
  ([.toolTask.allowedApplicationLifetimeRoutes[] | select(.name == $app)] | length == 1) and
  (.task as $parent | .dispatchTask.task != $parent) and
  .dispatchTask.task != .toolTask.task and .dispatchTask.subject != .subject and
  .dispatchTask.subject != .toolTask.subject and
  .dispatchTask.operatorSocket != null and .dispatchTask.reserveSigner != null and
  (.foregroundTool.reserve | type == "string" and test("^[1-9][0-9]*$")) and
  (.foregroundTool.charge | type == "string" and test("^(0|[1-9][0-9]*)$"))
' "$config" >/dev/null || fail 'controller lacks lifetime service or distinct purse'
host=${QUALIFIED_LIFETIME_HOST_BINARY:-$(jq -er .host "$config")}
[ "$(sha "$host")" = "$QUALIFIED_LIFETIME_HOST_SHA256" ] || fail 'Host pin differs'
socket=$(jq -er .controlSocket "$config")
state=$(jq -er .stateDir "$config")
if [ -z "$driver" ]; then [ -S "$socket" ] || fail 'controller socket absent'; fi
# Cases are fixed data, never a program or caller-selected HTTP endpoint.
# Include a positive call, invalid arguments, unknown operation and refusal
# cases for the selected appliance. bodyContains is a recursive JSON subset.
jq -e '
  type == "array" and length > 0 and length <= 32 and
  all(.[];
    (keys | sort) == (["name","tool","arguments","status","bodyContains"] | sort) and
    (.name | type == "string" and test("^[A-Za-z0-9_-]{1,64}$")) and
    (.tool == "mini_oracle_discover" or .tool == "mini_oracle_call") and
    (.arguments | type == "object" and (has("application") | not)) and
    (.status | type == "number" and floor == . and . >= 100 and . <= 599) and
    (.bodyContains | type == "object")) and
  ([.[].name] | unique | length) == length
' "$cases" >/dev/null || fail 'case data invalid'
mkdir -m 700 "$evidence"
sha256sum "$0" "$runtime" "$host" "$config" "$cases" >"$evidence/input-sha256.txt"
cp "$cases" "$evidence/cases.json"
count=$(jq length "$cases")
index=0
while [ "$index" -lt "$count" ]; do
  case_json=$(jq -c --argjson i "$index" '.[$i]' "$cases")
  name=$(printf '%s' "$case_json" | jq -er .name)
  tool=$(printf '%s' "$case_json" | jq -er .tool)
  args=$(printf '%s' "$case_json" | jq -c --arg app "$application" '.arguments + {application:$app}')
  printf '%s\n' "$args" >"$evidence/$name.arguments.json"
  request_id=$("$runtime" tool-id)
  printf '%s\n' "$request_id" >"$evidence/$name.request-id"
  jq -n --arg id "$request_id" --arg tool "$tool" --argjson args "$args" \
    '{requestId:$id,name:$tool,arguments:$args}' >"$evidence/$name.request.json"
  if ! invoke tool "$socket" soft "$request_id" "$tool" "$evidence/$name.arguments.json" \
      >"$evidence/$name.result.json" 2>"$evidence/$name.transport.log"; then
    fail "$name transport incomplete; inspect retained request ID, do not resend"
  fi
  jq -e --arg id "$request_id" '.type == "tool-complete" and .requestId == $id and
    .isError == false and .result.isError == false' "$evidence/$name.result.json" \
    >/dev/null || fail "$name did not complete through the controller"
  jq '.result.text | fromjson' "$evidence/$name.result.json" >"$evidence/$name.http.json"
  jq -e --argjson expected "$case_json" '
    .protocol == "mini-spk-agent-api-v3" and .type == "http-v3" and
    .status == $expected.status and
    (.bodyText | fromjson | contains($expected.bodyContains)) and
    (.operationId | type == "string") and .committedReceipt != null and
    (.responseSha256 | type == "string" and test("^[0-9a-f]{64}$"))
  ' "$evidence/$name.http.json" >/dev/null || fail "$name HTTP or application expectation differs"
  # A receiving-session HTTP reply cannot satisfy this event26 + settlement
  # join. Copy only the matched application attempt, never custody keys.
  journal=$state/journal.json
  if [ -n "$driver" ]; then
    journal=$evidence/$name.controller-journal.json
    # shellcheck disable=SC2024 # Evidence belongs to the invoking operator.
    sudo -n -- "$driver" controller-journal "$ORACLE_CONTROLLER_STORE" "$ORACLE_CONTROLLER_HELPER" >"$journal"
  fi
  jq -e --slurpfile reply "$evidence/$name.http.json" --arg app "$application" '
    .dispatchAttempt == null and .dispatchHold == null and .dispatchPending == null and
    ([.applicationApiHistory[] | select(
      (.operationId | tostring) == $reply[0].operationId and .routeName == $app and
      .phase == "definite" and .reported == true and
      .bindingSha256 == $reply[0].bindingSha256 and
      .operationFingerprint == $reply[0].operationFingerprint and
      .lifetimeCommittedReceipt == $reply[0].committedReceipt and
      .lifetimeSettledResponseSha256 == $reply[0].responseSha256 and
      .lifetimeSettlement.forwardOperationId == .operationId and
      .lifetimeSettlement.settlement.operation == "dispatch settle")] | length == 1)
  ' "$journal" >/dev/null || fail "$name has no definite joined lifetime settlement"
  jq --slurpfile reply "$evidence/$name.http.json" '
    .applicationApiHistory[] | select((.operationId | tostring) == $reply[0].operationId)
  ' "$journal" >"$evidence/$name.lifetime-attempt.json"
  invoke tool-result "$socket" "$request_id" >"$evidence/$name.retained-result.json"
  cmp "$evidence/$name.result.json" "$evidence/$name.retained-result.json" \
    >/dev/null || fail "$name retained tool result differs"
  invoke tool-ack "$socket" "$request_id" >"$evidence/$name.ack.json"
  index=$((index + 1))
done
sha256sum -c "$evidence/input-sha256.txt" >"$evidence/input-recheck.txt"
jq -n --arg app "$application" --argjson count "$count" \
  '{protocol:"mini-oracle-lifetime-tool-probe-v1",application:$app,cases:$count,
    result:"all-cases-have-definite-lifetime-delivery-and-settlement"}' >"$evidence/result.json"
cat "$evidence/result.json"
