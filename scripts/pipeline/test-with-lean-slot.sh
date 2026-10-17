#!/usr/bin/env bash
# scripts/pipeline/test-with-lean-slot.sh -- with-lean-slot's queue on a scratch slot dir (Linux: flock, GNU touch).
# Seconds; builds nothing. Checks: two waiters that arrive together on two free slots BOTH start at once (no slot
# idles a poll: the old "only the oldest ticket may try" rule started the second one 15 s late); grants follow
# ticket order (a priority ticket first), up to the N-1 places by which waiters granted in the same poll may
# swap; at most N run at once; a waiter whose WITH_LEAN_SLOT_PIDFILE lives outside the queue is still served (the
# installed copy's starvation); waits.tsv has one line per run.
set -uo pipefail
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
T=$(mktemp -d "${TMPDIR:-/tmp}/wls-test.XXXXXX"); trap 'rm -rf "$T"' EXIT
export PIPELINE_ROOT=$T PIPELINE_LEAN_SLOT_DIR=$T/slots PIPELINE_LEAN_SLOTS=2 LAKE_ARTIFACT_CACHE=false
mkdir -p "$T/slots"
job() { echo "start $1 $(date +%s.%N)" >> "$T/events"; sleep "$2"; echo "end $1 $(date +%s.%N)" >> "$T/events"; }
export -f job; export T
fail() { echo "test-with-lean-slot: FAIL: $*"; exit 1; }
# two holders, then five waiters enqueued one second apart (mtime resolution), one with an outside PID file
t0=$(date +%s.%N)
# holders outlast every enqueue below (5 waiters by ~5.4 s, the priority ticket at ~6.5 s), so all six queue behind them
"$here/with-lean-slot" bash -c 'job h1 9' & "$here/with-lean-slot" bash -c 'job h2 9' &
sleep 1
for i in 1 2 3 4 5; do
  if [ "$i" = 3 ]; then WITH_LEAN_SLOT_PIDFILE=$T/outside.pid "$here/with-lean-slot" bash -c "job w$i 2" &
  else "$here/with-lean-slot" bash -c "job w$i 2" & fi
  sleep 1.1
done
WITH_LEAN_SLOT_PRIORITY=1 "$here/with-lean-slot" bash -c 'job p 2' &
wait
order=$(sort -k3 -n "$T/events" | awk '$1=="start"{print $2}' | tr '\n' ' ')
late=$(awk -v t0="$t0" '$1=="start" && ($2=="h1" || $2=="h2") && $3 - t0 > 3 {print $2}' "$T/events" | tr '\n' ' ')
[ -z "$late" ] || fail "free slot left idle: $late started more than 3 s after launch (order: $order)"
# ticket order p w1 w2 w3 w4 w5 after the holders; waiters granted in one poll may swap by at most N-1 = 1 place
echo "$order" | awk '{ split("h h p w1 w2 w3 w4 w5", e, " "); bad = ""
  for (i = 1; i <= NF; i++) { x = $i; if (x ~ /^h/) x = "h"; for (j = 1; j <= 8; j++) if (e[j] == x && (j - i > 1 || i - j > 1)) bad = bad " " $i }
  if (NF != 8 || bad != "") exit 1 }' || fail "grant order: $order"
max=$(sort -k3 -n "$T/events" | awk '$1=="start"{n++; if(n>m)m=n} $1=="end"{n--} END{print m}')
[ "$max" -le 2 ] || fail "$max concurrent over 2 slots"
[ "$(wc -l < "$T/slots/waits.tsv")" = 8 ] || fail "waits.tsv has $(wc -l < "$T/slots/waits.tsv") lines, not 8"
echo "test-with-lean-slot: PASS (order: $order; holders started together; max concurrent $max; waits.tsv 8 lines)"
