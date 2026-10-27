#!/bin/sh
# Enrolment under a ticking clock: a retained plan is resumed, never planned again.
#
#   enrol-resume-acceptance.sh HOST MINI STORE VERIFIER NEW_PRIVATE_DIRECTORY
#
# On a fresh private Store (newparticipant-acceptance.sh): the sponsor plans the newcomer's
# enrollment; the clock ticks (`mini clock --action tick`, the real ticker) between the plan and
# every later step, as the clock and certifier timers do on a box; then
#   1. `enroll plan` again with the SAME --dir prints the same custody (subject, keyId, plan) and
#      plans nothing (no replanned/, one namespace record for the name);
#   2. `enroll plan` for the same name with ANOTHER --dir is refused naming the retained plan;
#   3. seal and submit: either the plan is admitted, or the Host refuses it with no record
#      (stale-root), in which case `enroll plan` in the same --dir retires it and plans the same
#      request again, the newcomer seals that plan, and submit admits it;
#   4. the admitted subject is the one the first plan reserved; the namespace holds exactly one
#      request record and one binding for the name.
# Every step leaves cmd/stdout/stderr/exit under ROOT/log (provisioning-acceptance.sh's shape).
set -eu
umask 077
[ "$#" -eq 5 ] || { echo "usage: $0 HOST MINI STORE VERIFIER NEW_PRIVATE_DIRECTORY" >&2; exit 2; }
HOST=$1 MINI=$2 STORE=$3 VERIFIER=$4 ROOT=$5
HERE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
command -v jq >/dev/null 2>&1 || { echo 'jq is required' >&2; exit 2; }
"$HERE/newparticipant-acceptance.sh" "$HOST" "$MINI" "$STORE" "$VERIFIER" "$ROOT" >"$ROOT.bootstrap.stdout"
ROOT=$(CDPATH='' cd -- "$ROOT" && pwd)
mv "$ROOT.bootstrap.stdout" "$ROOT/bootstrap-handoff.stdout"
CONFIG="$ROOT/deployment/pinned-config.json"
SOCKET="$ROOT/public/mini.sock"
LOG="$ROOT/log"; mkdir -m 700 "$LOG"
printf 'step\texit\n' >"$ROOT/steps.tsv"
step() { # NAME EXPECT(ok|fail) COMMAND...
  name=$1 expect=$2; shift 2
  printf '%s\n' "$*" >"$LOG/$name.cmd"
  set +e; "$@" >"$LOG/$name.stdout" 2>"$LOG/$name.stderr"; code=$?; set -e
  printf '%s\n' "$code" >"$LOG/$name.exit"; printf '%s\t%s\n' "$name" "$code" >>"$ROOT/steps.tsv"
  if [ "$expect" = ok ] && [ "$code" -ne 0 ]; then echo "step $name failed ($code)" >&2; tail -20 "$LOG/$name.stderr" >&2; exit 1; fi
  if [ "$expect" = fail ] && [ "$code" -eq 0 ]; then echo "step $name unexpectedly succeeded" >&2; exit 1; fi
}
nohup "$MINI" serve --host "$HOST" --config "$CONFIG" --socket "$SOCKET" >>"$ROOT/public/serve.log" 2>&1 </dev/null &
printf '%s\n' "$!" >"$ROOT/public/server.pid"
trap 'kill -TERM "$(cat "$ROOT/public/server.pid")" 2>/dev/null || true' EXIT
waited=0; until [ -S "$SOCKET" ]; do waited=$((waited + 1)); [ "$waited" -lt 1200 ] || { echo 'socket did not appear' >&2; exit 1; }; sleep 0.1; done
tick() { step "$1" ok "$MINI" clock --action tick --workspace "$ROOT/clock"; }
NS=$(jq -r .namespaceRoot "$ROOT/sponsor/workspace.json")
A="$ROOT/attempts/newcomer"
plan() { step "$1" "$2" "$MINI" enroll --action plan --sponsor-workspace "$ROOT/sponsor" --factory-ref factory \
  --name newcomer --new-key "$ROOT/newcomer.key" --dir "$3"; }

plan plan-1 ok "$A"
SUBJECT=$(jq -er .subject "$LOG/plan-1.stdout"); KEYID=$(jq -er .keyId "$LOG/plan-1.stdout")
PLAN_SHA=$(sha256sum "$A/plan.bin" | cut -d' ' -f1)
tick tick-1
# 1. the same --dir resumes: same custody, nothing planned again
plan plan-again ok "$A"
[ "$(jq -er .subject "$LOG/plan-again.stdout")" = "$SUBJECT" ]
[ "$(jq -er .keyId "$LOG/plan-again.stdout")" = "$KEYID" ]
[ "$(sha256sum "$A/plan.bin" | cut -d' ' -f1)" = "$PLAN_SHA" ]
[ ! -e "$A/replanned" ]
grep -q 'a validated plan is retained' "$LOG/plan-again.stderr"
# 2. another --dir for the same name is refused, naming the retained plan
plan plan-elsewhere fail "$ROOT/attempts/newcomer-again"
grep -q "already planned at $A" "$LOG/plan-elsewhere.stderr"
[ ! -e "$ROOT/attempts/newcomer-again/pin.json" ]
tick tick-2
# 3. seal and submit under the moved clock
step seal-1 ok "$MINI" enroll --action seal --dir "$A"
tick tick-3
set +e; "$MINI" enroll --action submit --dir "$A" >"$LOG/submit-1.stdout" 2>"$LOG/submit-1.stderr"; code=$?; set -e
printf '%s\n' "$code" >"$LOG/submit-1.exit"; printf 'submit-1\t%s\n' "$code" >>"$ROOT/steps.tsv"
if [ "$code" -ne 0 ]; then
  [ -s "$A/submit-refused.json" ] || { echo "submit refused without the no-record marker:" >&2; tail -5 "$LOG/submit-1.stderr" >&2; exit 1; }
  grep -q 'refused by the Host with no record' "$LOG/submit-1.stderr"
  ls "$NS" | grep -q "^released-" || { echo 'the namespace binding was not released' >&2; exit 1; }
  step seal-refused fail "$MINI" enroll --action seal --dir "$A"
  plan plan-2 ok "$A"
  [ -d "$A/replanned/01" ] && [ -s "$A/replanned/01/submit-refused.json" ]
  [ "$(jq -er .subject "$LOG/plan-2.stdout")" = "$SUBJECT" ]
  [ "$(jq -er .keyId "$LOG/plan-2.stdout")" = "$KEYID" ]
  step seal-2 ok "$MINI" enroll --action seal --dir "$A"
  step submit-2 ok "$MINI" enroll --action submit --dir "$A"
  PATH_TAKEN=refused-then-replanned
else
  PATH_TAKEN=admitted-first
fi
# 4. one identity, one record, one binding
[ "$(jq -er .subject "$A/enrollment.json")" = "$SUBJECT" ]
[ "$(jq -er .authority "$A/enrollment.json")" = admitted-key-only ]
records=$(for f in "$NS"/request-*.json; do jq -r 'select(.request=="newcomer") | .request' "$f"; done | wc -l | tr -d ' ')
[ "$records" = 1 ] || { echo "namespace holds $records request records for newcomer" >&2; exit 1; }
bindings=$(ls "$NS" | grep -c '^binding-' || true)
[ "$bindings" = 1 ] || { echo "namespace holds $bindings bindings" >&2; exit 1; }
echo "enrol-resume: PASS ($PATH_TAKEN) subject=$SUBJECT keyId=$KEYID"
