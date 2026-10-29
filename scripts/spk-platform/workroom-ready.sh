#!/usr/bin/env bash
# workroom-ready.sh WORLD-IDENTITY.json EVIDENCE_DIR
# The metered workroom for same-Store app births: the parent task reserved in its first generation,
# the tool task attached. same-store-app.py check_task_readiness births only under a reserved hard
# parent and an attached, settled tool; `mini apps bootstrap` registers both paused. The grain
# operations are grain-journey.sh's workroom_ready, by the bootstrap's subject (the sponsor) with
# the sponsor workspace's key, each confirmed; idempotent on the tasks' state.
set -euo pipefail
umask 077
[[ $# == 2 ]] || { echo "usage: $0 WORLD-IDENTITY.json EVIDENCE_DIR" >&2; exit 2; }
world=$1 work=$2
refuse() { echo "workroom-ready: $*" >&2; exit 1; }
sponsor_ws=$(jq -r '.members | to_entries[] | select(.value.entry == "sponsor") | .value.workspace' "$world" | head -1)
[[ -n $sponsor_ws && -f $sponsor_ws/workspace.json ]] || refuse "the inventory names no sponsor workspace"
config=$(jq -r .config "$sponsor_ws/workspace.json") socket=$(jq -r .socket "$sponsor_ws/workspace.json") host=$(jq -r .host "$sponsor_ws/workspace.json")
for role in parent tool; do
  [[ -f $sponsor_ws/refs/$role.json ]] || refuse "meteredTasksRequired: no $sponsor_ws/refs/$role.json; run mini apps bootstrap first"
done
mkdir -m 700 -p "$work"
mini=$(dirname "$host")/mini
[[ -x $mini ]] || refuse "the world's candidate has no mini beside its Host"
sponsor_key=$(jq -r .key "$sponsor_ws/workspace.json")
nonce_base=$(( $(od -An -N4 -tu4 /dev/urandom | tr -d ' ') % 1000000000 + 1000000 ))
task_read() { # NAME SUBJECT TASK CAPABILITY NONCE
  jq -n --arg s "$2" --arg t "$3" --arg c "$4" --arg n "$5" \
    '{subject:$s,nonce:$n,purpose:{type:"query",kind:"object",target:$t,view:"resource"},grants:[{kind:"object",target:$t,capability:$c}]}' >"$work/$1-intent.json"
  rm -rf "${work:?}/$1"
  "$mini" query --host "$host" --config "$config" --socket "$socket" --intent "$work/$1-intent.json" --key "$sponsor_key" \
    --view resource --dir "$work/$1" >"$work/$1.stdout" 2>"$work/$1.stderr" || refuse "workroom read $1 refused: $(tail -n1 "$work/$1.stderr")"
}
task_op() { # NAME SUBJECT TASK CAPABILITY NONCE OPERATION
  # A confirmed attempt is final; an attempt without its outcome is uncertain and never resubmitted.
  if [[ -s $work/$1-attempt/outcome.json ]]; then
    jq -e '.type == "confirmed" and .confirmation == "installed"' "$work/$1-attempt/outcome.json" >/dev/null || refuse "workroom $1 retained outcome is not confirmed"
    return 0
  fi
  [[ ! -e $work/$1-attempt ]] || refuse "workroom $1 attempt is uncertain; recover it exactly (mini submit --dir $work/$1-attempt)"
  task_read "$1-before" "$2" "$3" "$4" "$(( $5 + 1 ))"
  jq -n --arg task "$3" --arg subject "$2" --arg cap "$4" --arg nonce "$5" --argjson operation "$6" --slurpfile read "$work/$1-before/view.json" '
    {grain:{task:$task,subject:$subject,capability:$cap,observeCapability:$cap,schemaVersion:"1",expectedTargetRoot:$read[0].cell.root,
      context:{operationId:$nonce,payload:"composed workroom"},before:($read[0].cell.grain | {generation,status,remaining,reserved}),
      operation:$operation,publications:[]},grants:[{kind:"object",target:$task,capability:$cap}],intentNonce:$nonce}' >"$work/$1-intent.json"
  "$mini" submit --host "$host" --config "$config" --socket "$socket" --intent "$work/$1-intent.json" --intent-kind grain-intent \
    --key "$sponsor_key" --dir "$work/$1-attempt" >"$work/$1.stdout" 2>"$work/$1.stderr" || refuse "workroom $1 refused: $(tail -n1 "$work/$1.stderr")"
  jq -e '.type == "confirmed" and .confirmation == "installed"' "$work/$1-attempt/outcome.json" >/dev/null || refuse "workroom $1 did not confirm"
}
# mini apps bootstrap births both tasks under the subject of the workspace it runs in (apps.rs
# bootstrap_source: creator and owner = that workspace's subject), here the sponsor's: the tasks are
# read and driven as that subject with its key, whether or not genesis names a distinct management.
subject=$(jq -er .subject "$sponsor_ws/workspace.json")
parent_task=$(jq -er .target "$sponsor_ws/refs/parent.json") parent_cap=$(jq -er .operationCapability "$sponsor_ws/refs/parent.json")
tool_task=$(jq -er .target "$sponsor_ws/refs/tool.json") tool_cap=$(jq -er .operationCapability "$sponsor_ws/refs/tool.json")
task_read parent-state "$subject" "$parent_task" "$parent_cap" "$nonce_base"
if ! jq -e '(.cell.grain.status == "3" or .cell.grain.status == "4") and (.cell.grain.reserved | tonumber) > 0' "$work/parent-state/view.json" >/dev/null; then
  jq -e '.cell.grain.status == "0"' "$work/parent-state/view.json" >/dev/null && task_op parent-attach "$subject" "$parent_task" "$parent_cap" "$(( nonce_base + 10 ))" '{"type":"attach","soft":false}'
  task_op parent-reserve "$subject" "$parent_task" "$parent_cap" "$(( nonce_base + 20 ))" '{"type":"reserve","amount":"1"}'
fi
task_read tool-state "$subject" "$tool_task" "$tool_cap" "$(( nonce_base + 30 ))"
if jq -e '.cell.grain.status == "0"' "$work/tool-state/view.json" >/dev/null; then
  task_op tool-attach "$subject" "$tool_task" "$tool_cap" "$(( nonce_base + 40 ))" '{"type":"attach","soft":false}'
fi
