#!/usr/bin/env bash
# Exercise the exact legacy REST/SocialCalc behavior used by the Mini interface.
set -euo pipefail
BASE="${BASE:-/var/lib/spk-fresh/apps/ethercalc}"
SRC="$BASE/work/build-src"
RUN="$BASE/work/smoke"
PIDFILE="$BASE/out/smoke-workerd.pid"
LOG="$BASE/out/smoke-workerd.log"
RESULT="$BASE/out/smoke-results.json"
mkdir -p "$RUN/do"
rm -f "$PIDFILE"

export ETHERCALC_DEFAULT_ROOM=sheet
export ETHERCALC_DISABLE_ROOM_INDEX=1
"$SRC/runtime/workerd" serve "$SRC/packages/worker/workerd/config.capnp" \
  -ddo="$RUN/do" -dassets="$SRC/assets" >"$LOG" 2>&1 &
WORKER_PID=$!
printf '%s\n' "$WORKER_PID" > "$PIDFILE"
cleanup() {
  if [[ -f "$PIDFILE" ]]; then
    pid="$(cat "$PIDFILE")"
    kill -TERM "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -f "$PIDFILE"
  fi
}
trap cleanup EXIT INT TERM

ready=0
for ((i=0; i<60; i++)); do
  if curl -fsS http://127.0.0.1:33411/_health > "$RUN/health.txt" 2>/dev/null; then
    ready=1
    break
  fi
  sleep 1
done
if [[ "$ready" != 1 ]]; then
  printf 'workerd did not become healthy\n' >&2
  exit 1
fi

printf 'item,qty\nwidgets,3\nformula,=1+2\n' > "$RUN/input.csv"
PUT_STATUS="$(curl -sS -o "$RUN/put-response.txt" -w '%{http_code}' \
  -X PUT -H 'Content-Type: text/csv; charset=utf-8' \
  --data-binary @"$RUN/input.csv" http://127.0.0.1:33411/_/spkfresh)"
case "$PUT_STATUS" in 200|201|202) ;; *) printf 'CSV PUT returned %s\n' "$PUT_STATUS" >&2; exit 1;; esac
curl -fsS http://127.0.0.1:33411/_/spkfresh/csv > "$RUN/export.csv"
curl -fsS http://127.0.0.1:33411/_/spkfresh/csv.json > "$RUN/export.json"
curl -fsS http://127.0.0.1:33411/_/spkfresh > "$RUN/export.socialcalc"

python3 -I - "$RUN" <<'PY'
import csv, json, pathlib, sys
run = pathlib.Path(sys.argv[1])
with (run / "export.csv").open(newline="") as f:
    rows = list(csv.reader(f))
assert rows[0][:2] == ["item", "qty"], rows
assert rows[1][:2] == ["widgets", "3"], rows
assert rows[2][:2] == ["formula", "3"], rows
data = json.loads((run / "export.json").read_text())
assert data[0][:2] == ["item", "qty"], data
assert data[1][:2] == ["widgets", "3"], data
assert data[2][:2] == ["formula", "3"], data
socialcalc = (run / "export.socialcalc").read_text()
assert "socialcalc" in socialcalc.lower(), socialcalc[:200]
assert "A1" in socialcalc and "item" in socialcalc, socialcalc[:500]
PY

SC_STATUS="$(curl -sS -o "$RUN/sc-put-response.txt" -w '%{http_code}' \
  -X PUT -H 'Content-Type: text/x-socialcalc' \
  --data-binary @"$RUN/export.socialcalc" http://127.0.0.1:33411/_/spkfresh-sc)"
case "$SC_STATUS" in 200|201|202) ;; *) printf 'SocialCalc PUT returned %s\n' "$SC_STATUS" >&2; exit 1;; esac
curl -fsS http://127.0.0.1:33411/_/spkfresh-sc/csv.json > "$RUN/sc-export.json"
python3 -I - "$RUN" "$PUT_STATUS" "$SC_STATUS" <<'PY'
import json, pathlib, sys
run = pathlib.Path(sys.argv[1])
data = json.loads((run / "sc-export.json").read_text())
assert data[0][:2] == ["item", "qty"], data
assert data[1][:2] == ["widgets", "3"], data
assert data[2][:2] == ["formula", "3"], data
result = {
    "health": "pass",
    "csvPutStatus": int(sys.argv[2]),
    "csvExport": "pass",
    "csvJsonExport": "pass",
    "socialCalcExport": "pass",
    "socialCalcPutStatus": int(sys.argv[3]),
    "socialCalcRoundTrip": "pass",
    "formulaDisplayValue": "3"
}
(run.parent.parent / "out" / "smoke-results.json").write_text(json.dumps(result, indent=2) + "\n")
PY
printf 'Smoke test passed; results: %s\n' "$RESULT"
