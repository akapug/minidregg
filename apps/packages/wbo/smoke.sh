#!/usr/bin/env bash
# Smoke-test the staged WBO server on dregg-forge before packing.
set -euo pipefail
WORKDIR=${WORKDIR:-/var/lib/spk-fresh/apps/wbo}
ATTEMPT=${1:-1}
[[ $ATTEMPT =~ ^[a-z0-9-]+$ ]]
RUN="$WORKDIR/work/smoke-$ATTEMPT"
PIDFILE="$WORKDIR/out/smoke-$ATTEMPT.pid"
LOG="$WORKDIR/out/smoke-$ATTEMPT.log"
[[ ! -e $RUN && ! -e $PIDFILE ]]
mkdir -p "$RUN/history" "$RUN/home"

cd "$WORKDIR/build/source"
env PATH="$WORKDIR/runtime/node/bin:/usr/local/bin:/usr/bin:/bin" \
  LD_LIBRARY_PATH="$WORKDIR/runtime/node/lib" NODE_ENV=production \
  HOME="$RUN/home" PORT=18080 HOST=127.0.0.1 \
  WBO_HISTORY_DIR="$RUN/history" WBO_DEFAULT_BOARD=board \
  "$WORKDIR/runtime/node/bin/node" server/server.mjs >"$LOG" 2>&1 &
pid=$!
printf '%s\n' "$pid" >"$PIDFILE"
cleanup() {
  if [[ -f $PIDFILE ]]; then
    pid=$(<"$PIDFILE")
    kill -TERM "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -f "$PIDFILE"
  fi
}
trap cleanup EXIT INT TERM

ready=0
for ((i=0; i<60; i++)); do
  if curl -fsS http://127.0.0.1:18080/boards/board >"$RUN/board.html" 2>/dev/null; then
    ready=1
    break
  fi
  sleep 1
done
[[ $ready == 1 ]]
grep -q 'WBO' "$RUN/board.html"
printf 'WBO staged server passed GET /boards/board; log: %s\n' "$LOG"
