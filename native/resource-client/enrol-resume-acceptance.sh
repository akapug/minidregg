#!/bin/sh
# Enrolment under a ticking clock: a retained plan is resumed while current, re-planned under the
# SAME request once the source has moved, and never planned twice for one name.
#
#   enrol-resume-acceptance.sh HOST MINI STORE VERIFIER NEW_PRIVATE_DIRECTORY
#
# On a fresh private Store (newparticipant-acceptance.sh) the sponsor plans the newcomer's
# enrollment; the clock ticks (`mini clock --action tick`, the real ticker) as the clock and
# certifier timers do on a box. Asserted:
#   1. `enroll plan` again, same --dir, no commit in between: the same custody (subject, keyId,
#      plan bytes), nothing planned (no new replanned/);
#   2. after a tick, `enroll plan` again, same --dir: the stale plan retires under replanned/NN and
#      the same request is planned again (same subject and keyId, new plan bytes);
#   3. `enroll plan` for the same name with ANOTHER --dir is refused naming the retained plan;
#   4. after a tick, `seal` of the retained plan is refused and points at `plan`; `plan` re-plans,
#      `seal` then signs; a tick before `submit` has the Host refuse with no record, on which
#      `plan` re-plans in place and seal + submit admit (or the Host admits at once: either way,
#      exactly one admission);
#   5. the admitted subject and keyId are the first plan's; the namespace holds one request record
#      and one binding for the name.
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
said() { grep -q "$2" "$LOG/$1.stderr" || { echo "step $1 did not say: $2" >&2; tail -3 "$LOG/$1.stderr" >&2; exit 1; }; }
nohup "$MINI" serve --host "$HOST" --config "$CONFIG" --socket "$SOCKET" >>"$ROOT/public/serve.log" 2>&1 </dev/null &
printf '%s\n' "$!" >"$ROOT/public/server.pid"
trap 'kill -TERM "$(cat "$ROOT/public/server.pid")" 2>/dev/null || true' EXIT
waited=0; until [ -S "$SOCKET" ]; do waited=$((waited + 1)); [ "$waited" -lt 1200 ] || { echo 'socket did not appear' >&2; exit 1; }; sleep 0.1; done
tick() { step "$1" ok "$MINI" clock --action tick --workspace "$ROOT/clock"; }
NS=$(jq -r .namespaceRoot "$ROOT/sponsor/workspace.json")
A="$ROOT/attempts/newcomer"
plan() { step "$1" "$2" "$MINI" enroll --action plan --sponsor-workspace "$ROOT/sponsor" --factory-ref factory \
  --name newcomer --new-key "$ROOT/newcomer.key" --dir "$3"; }
plan_sha() { sha256sum "$A/plan.bin" | cut -d' ' -f1; }
same_identity() { [ "$(jq -er .subject "$LOG/$1.stdout")" = "$SUBJECT" ] && [ "$(jq -er .keyId "$LOG/$1.stdout")" = "$KEYID" ]; }

plan plan-1 ok "$A"
SUBJECT=$(jq -er .subject "$LOG/plan-1.stdout"); KEYID=$(jq -er .keyId "$LOG/plan-1.stdout")
P1=$(plan_sha)
# 1. resumption: nothing moved, nothing planned again
plan plan-resume ok "$A"
same_identity plan-resume; [ "$(plan_sha)" = "$P1" ]; [ ! -e "$A/replanned" ]
said plan-resume 'a validated plan is retained'
# 2. after a tick the retained plan is stale: re-planned under the same request
tick tick-1
plan plan-after-tick ok "$A"
same_identity plan-after-tick; [ "$(plan_sha)" != "$P1" ]; [ -s "$A/replanned/01/plan.bin" ]
said plan-after-tick 'the retained plan is stale against the moved source'
[ "$(ls "$NS" | grep -c '^released-')" = 1 ]
# 3. another --dir for the same name is refused, naming the retained plan
plan plan-elsewhere fail "$ROOT/attempts/newcomer-again"
said plan-elsewhere "already planned at $A"
[ ! -e "$ROOT/attempts/newcomer-again/pin.json" ]
# 4. a tick before seal: the consent provider refuses the stale plan and points at plan
tick tick-2
step seal-stale fail "$MINI" enroll --action seal --dir "$A"
said seal-stale 'plans the same request again'
plan plan-2 ok "$A"
same_identity plan-2; [ -s "$A/replanned/02/plan.bin" ]
step seal-2 ok "$MINI" enroll --action seal --dir "$A"
tick tick-3
set +e; "$MINI" enroll --action submit --dir "$A" >"$LOG/submit-1.stdout" 2>"$LOG/submit-1.stderr"; code=$?; set -e
printf '%s\n' "$code" >"$LOG/submit-1.exit"; printf 'submit-1\t%s\n' "$code" >>"$ROOT/steps.tsv"
if [ "$code" -ne 0 ]; then
  [ -s "$A/submit-refused.json" ] || { echo "submit refused without the no-record marker:" >&2; tail -5 "$LOG/submit-1.stderr" >&2; exit 1; }
  said submit-1 'refused by the Host with no record'
  step seal-refused fail "$MINI" enroll --action seal --dir "$A"
  said seal-refused 'plan again'
  plan plan-3 ok "$A"
  same_identity plan-3; [ -s "$A/replanned/03/submit-refused.json" ]
  step seal-3 ok "$MINI" enroll --action seal --dir "$A"
  step submit-3 ok "$MINI" enroll --action submit --dir "$A"
  PATH_TAKEN=submit-refused-no-record-then-replanned
else
  PATH_TAKEN=submit-admitted-across-the-tick
fi
# 5. one identity, one record, one binding
[ "$(jq -er .subject "$A/enrollment.json")" = "$SUBJECT" ]
[ "$(jq -er .keyId "$A/enrollment.json")" = "$KEYID" ]
[ "$(jq -er .authority "$A/enrollment.json")" = admitted-key-only ]
records=$(for f in "$NS"/request-*.json; do jq -r 'select(.request=="newcomer") | .request' "$f"; done | wc -l | tr -d ' ')
[ "$records" = 1 ] || { echo "namespace holds $records request records for newcomer" >&2; exit 1; }
bindings=$(ls "$NS" | grep -c '^binding-' || true)
[ "$bindings" = 1 ] || { echo "namespace holds $bindings bindings" >&2; exit 1; }
step lookup ok "$MINI" enroll --action lookup --dir "$A"
echo "enrol-resume: PASS ($PATH_TAKEN) subject=$SUBJECT keyId=$KEYID"
