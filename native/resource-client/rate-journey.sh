#!/bin/sh
# native/resource-client/rate-journey.sh -- the per-subject request rate row
# (Kernel/SubjectRate.lean; docs/PD-HOST-RATE-DESIGN.md §4's owed journey).
#
# A world of its own through the one template (scenario-genesis.sh): requestRate
# {limit 3, windowMs 20000, exempt [the sponsor, subject 7]}, subjects 8 and 9
# enrolled as application-acceptance.sh enrols them. One `mini serve` (one Host
# process: the rate table lives in it and a restart starts every window afresh),
# then signed reads (op 5, `mini query`) through the public socket:
#   pinned-config   the pinned config the Host serves carries the rate
#   admitted-1..3   subject 8's first three reads in the window: admitted
#   refused-4th     the fourth, seconds later: refused `rate-limited` by name,
#                   with the seconds until the window reopens, under NO_RECORD
#   other-subject   subject 9 reads at that same moment: admitted (one subject's
#                   full window never changes another's answer)
#   sponsor-exempt  the exempt sponsor reads five times in the same window
#                   (past the limit): never refused
#   after-window    subject 8 reads again after the window: admitted (the
#                   refusal's retry promise)
#
# usage: rate-journey.sh MINIDREGG_HOST MINI STORE VERIFIER NEW_RUN_DIRECTORY
# Rows: RUN/rate-rows.tsv (id<TAB>PASS|FAIL<TAB>detail), the last stdout line;
# the verdict is the last stderr line. Exit 0 iff every row passed.
set -eu
umask 077
. "$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)/native/resource-client/journey.d/lib/evidence.sh"

if [ "$#" -ne 5 ]; then
  echo "usage: $0 MINIDREGG_HOST MINI STORE VERIFIER NEW_RUN_DIRECTORY" >&2
  exit 2
fi
HOST=$1 MINI=$2 STORE=$3 VERIFIER=$4 RUN=$5
HERE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO=$(CDPATH='' cd -- "$HERE/../.." && pwd)
. "$REPO/native/resource-client/journey.d/lib/genesis-params.sh"
resolve_params_sh "$REPO" || exit 2

for executable in "$HOST" "$MINI" "$STORE" "$VERIFIER"; do
  [ -x "$executable" ] || { echo "not executable: $executable" >&2; exit 2; }
done
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }
[ ! -e "$RUN" ] || { echo "refusing existing run directory: $RUN" >&2; exit 2; }
mkdir -m 700 "$RUN"
RUN=$(CDPATH='' cd -- "$RUN" && pwd)
sha256 "$0" "$HOST" "$MINI" "$STORE" "$VERIFIER" >"$RUN/input-sha256.txt"

LIMIT=3
WINDOW_MS=20000
ROWS=$RUN/rate-rows.tsv
printf 'id\tstatus\tdetail\n' >"$ROWS"
BAD=0
row() {  # row ID OK DETAIL
  printf '%s\t%s\t%s\n' "$1" "$([ "$2" = 0 ] && echo PASS || echo FAIL)" "$3" >>"$ROWS"
  [ "$2" = 0 ] || { BAD=$((BAD + 1)); echo "rate row $1: $3" >&2; }
}

# ---------------------------------------------------------------- the world
"$MINI" keygen --secret "$RUN/sponsor.key" --public "$RUN/sponsor.pub" >/dev/null
"$MINI" keygen --secret "$RUN/eight.key" --public "$RUN/eight.pub" >/dev/null
"$MINI" keygen --secret "$RUN/nine.key" --public "$RUN/nine.pub" >/dev/null
sponsor_public=$(od -An -tx1 -v "$RUN/sponsor.pub" | tr -d ' \n')
eight_public=$(od -An -tx1 -v "$RUN/eight.pub" | tr -d ' \n')
nine_public=$(od -An -tx1 -v "$RUN/nine.pub" | tr -d ' \n')
[ "$sponsor_public" != "$eight_public" ] && [ "$sponsor_public" != "$nine_public" ] &&
  [ "$eight_public" != "$nine_public" ]

# Subjects 8 and 9 as application-acceptance.sh enrols them; 9's control
# capability is 53, so the factory controller's moves to 57.
jq -n --arg eight "$eight_public" --arg nine "$nine_public" '[
  {subject: 8, keyId: 8008, publicKey: $eight, accountId: 8, spendCapabilityId: 42,
   controlCapabilityId: 52, factoryObserveCapabilityId: 55, initialBalance: 1000},
  {subject: 9, keyId: 9009, publicKey: $nine, accountId: 9, spendCapabilityId: 43,
   controlCapabilityId: 53, factoryObserveCapabilityId: 56, initialBalance: 1000}]' >"$RUN/enrollments.json"
HOST=$HOST STORE=$STORE VERIFIER=$VERIFIER MINI=$MINI GENESIS_PARAMS_SH=$GENESIS_PARAMS_SH \
  sh "$HERE/scenario-genesis.sh" "$RUN" "$sponsor_public" \
  "del(.grainPlatform) | .factoryControllerCapability = 57 | .sponsor.initialBalance = 1000 |
   .requestRate = {limit: $LIMIT, windowMs: $WINDOW_MS, exempt: [7]}" \
  "$RUN/enrollments.json"
if jq -e --argjson limit "$LIMIT" --argjson window "$WINDOW_MS" \
    '.requestRate == {limit: $limit, windowMs: $window, exempt: [7]}' "$RUN/operator.json" >/dev/null; then
  row genesis-config 0 "operator.json pins requestRate limit $LIMIT window ${WINDOW_MS}ms, sponsor 7 exempt"
else
  row genesis-config 1 "operator.json does not carry requestRate {limit $LIMIT, windowMs $WINDOW_MS, exempt [7]}"
fi
"$MINI" bootstrap --host "$HOST" --config "$RUN/operator.json" \
  --source "$RUN/genesis.json" --dir "$RUN/deployment" >"$RUN/bootstrap.stdout"
CONFIG=$RUN/deployment/pinned-config.json
if jq -e --argjson limit "$LIMIT" --argjson window "$WINDOW_MS" \
    '.requestRate.limit == $limit and .requestRate.windowMs == $window and
     (.requestRate.exempt | index(7) != null)' "$CONFIG" >/dev/null; then
  row pinned-config 0 "the pinned config the Host serves carries the same rate"
else
  row pinned-config 1 "pinned-config.json lost requestRate (limit $LIMIT, windowMs $WINDOW_MS, exempt 7)"
fi

# ---------------------------------------------------------------- the service
# One Host process for every read: the rate table lives in the Host (`RateGate`),
# so a fresh Host per read could never refuse the fourth.
SOCKET=$RUN/host.sock
setsid nohup "$MINI" serve --host "$HOST" --config "$CONFIG" --socket "$SOCKET" \
  >"$RUN/serve.log" 2>&1 </dev/null &
echo $! >"$RUN/serve.pid"
stop_server() {
  pid=$(cat "$RUN/serve.pid" 2>/dev/null) || return 0
  kill -TERM "$pid" 2>/dev/null || return 0
  i=0
  while [ $i -lt 300 ] && kill -0 "$pid" 2>/dev/null; do sleep 0.1; i=$((i + 1)); done
  kill -0 "$pid" 2>/dev/null && echo "rate-journey: server $pid alive 30 s after TERM" >&2
  for kid in $(pgrep -P "$pid" 2>/dev/null); do
    i=0
    while [ $i -lt 100 ] && kill -0 "$kid" 2>/dev/null; do sleep 0.1; i=$((i + 1)); done
    kill -0 "$kid" 2>/dev/null && echo "rate-journey: Host child $kid outlived its server" >&2
  done
  return 0
}
trap stop_server EXIT HUP INT TERM
i=0
until [ -S "$SOCKET" ] && grep -q serving "$RUN/serve.log" 2>/dev/null; do
  kill -0 "$(cat "$RUN/serve.pid")" 2>/dev/null ||
    { echo "mini serve exited: $(tail -1 "$RUN/serve.log")" >&2; exit 1; }
  i=$((i + 1))
  [ "$i" -lt 120 ] || { echo "mini serve startup timed out" >&2; exit 1; }
  sleep 1
done

# ---------------------------------------------------------------- the reads
# query LABEL SUBJECT TARGET CAPABILITY KEY NONCE: one signed read (op 5) of the
# factory (10) through the public socket; sets QUERY_RC.
QUERY_RC=0
query() {
  label=$1 subject=$2 target=$3 capability=$4 key=$5 nonce=$6
  jq -n --arg subject "$subject" --arg target "$target" \
    --arg capability "$capability" --arg nonce "$nonce" \
    '{subject:$subject,nonce:$nonce,
      purpose:{type:"query",kind:"object",target:$target,view:"resource"},
      grants:[{kind:"object",target:$target,capability:$capability}]}' >"$RUN/$label-intent.json"
  if "$MINI" query --host "$HOST" --config "$CONFIG" --socket "$SOCKET" \
      --intent "$RUN/$label-intent.json" --key "$key" --view resource \
      --dir "$RUN/$label" >"$RUN/$label.stdout" 2>"$RUN/$label.stderr"; then
    QUERY_RC=0
  else
    QUERY_RC=$?
  fi
}
first_ending() { grep -m1 -E '^(refused|undecided|error|usage): ' "$1" || true; }

for n in 1 2 3; do
  query "eight-$n" 8 10 55 "$RUN/eight.key" "410$n"
  if [ "$QUERY_RC" = 0 ] && [ -s "$RUN/eight-$n/view.bin" ]; then
    row "admitted-$n" 0 "subject 8's read $n of $LIMIT in the window: admitted"
  else
    row "admitted-$n" 1 "subject 8's read $n: rc $QUERY_RC: $(first_ending "$RUN/eight-$n.stderr")"
  fi
done

query eight-4 8 10 55 "$RUN/eight.key" 4104
ending=$(first_ending "$RUN/eight-4.stderr")
seconds=$(printf '%s' "$ending" | sed -n 's/^refused: rate-limited: this subject has used its request rate for now; retry in \([1-9][0-9]*\) s (phase op 5)$/\1/p')
if [ "$QUERY_RC" = 3 ] && [ -n "$seconds" ] && [ "$seconds" -le $((WINDOW_MS / 1000)) ] &&
   grep -q 'Host refused query with no record' "$RUN/eight-4.stderr"; then
  row refused-4th 0 "the 4th read in the window: refused rate-limited, retry in ${seconds}s, no record (a fresh attempt is safe)"
else
  row refused-4th 1 "the 4th read: rc $QUERY_RC: ${ending:-$(tail -1 "$RUN/eight-4.stderr")}"
fi

query nine-at-limit 9 10 56 "$RUN/nine.key" 4201
if [ "$QUERY_RC" = 0 ] && [ -s "$RUN/nine-at-limit/view.bin" ]; then
  row other-subject 0 "subject 9 reads at the moment 8 is refused: admitted"
else
  row other-subject 1 "subject 9's read at 8's refusal: rc $QUERY_RC: $(first_ending "$RUN/nine-at-limit.stderr")"
fi

sponsor_ok=0
for n in 1 2 3 4 5; do
  query "sponsor-$n" 7 10 54 "$RUN/sponsor.key" "430$n"
  [ "$QUERY_RC" = 0 ] || break
  sponsor_ok=$n
done
if [ "$sponsor_ok" = 5 ]; then
  row sponsor-exempt 0 "the exempt sponsor reads 5 times in the same window (limit $LIMIT): never refused"
else
  row sponsor-exempt 1 "the sponsor's read $((sponsor_ok + 1)) of 5: rc $QUERY_RC: $(first_ending "$RUN/sponsor-$((sponsor_ok + 1)).stderr")"
fi

# The refusal promised at most WINDOW_MS/1000 s; sleep past the whole window.
sleep $((WINDOW_MS / 1000 + 2))
query eight-retry 8 10 55 "$RUN/eight.key" 4105
if [ "$QUERY_RC" = 0 ] && [ -s "$RUN/eight-retry/view.bin" ]; then
  row after-window 0 "subject 8 reads again after the ${WINDOW_MS}ms window: admitted, the retry promise held"
else
  row after-window 1 "subject 8's read after the window: rc $QUERY_RC: $(first_ending "$RUN/eight-retry.stderr")"
fi

total=$(($(wc -l <"$ROWS") - 1))
if [ "$BAD" = 0 ]; then
  echo "rate: $total rows PASS: limit $LIMIT per ${WINDOW_MS}ms; the 4th signed read refused rate-limited with its retry; another subject and the exempt sponsor admitted; after the window admitted" >&2
else
  echo "rate: $BAD of $total rows FAIL" >&2
fi
echo "$ROWS"
[ "$BAD" = 0 ]
