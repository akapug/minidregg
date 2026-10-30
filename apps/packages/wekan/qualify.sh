#!/usr/bin/env bash
# Run on hbox. LANE contains src/ and bin/; CACHE holds only <packageId>.spk.
set -euo pipefail
LANE=${1:?absolute lane directory}
CACHE=${2:?quarantine directory containing the candidate SPK}
ATTEMPT=${3:-1}
[[ $ATTEMPT =~ ^[a-z0-9-]+$ ]]
RECIPE=$(cd "$(dirname "$0")" && pwd)
RUN="$LANE/world-$ATTEMPT"
OUT="$LANE/qualification-$ATTEMPT"
[[ $LANE == /* && -d $LANE/src && -d $LANE/bin && ! -e $RUN && ! -e $OUT ]]
MINI_OPERATOR_UID=$(id -u)
MINI_OPERATOR_NAME=$(id -un)
APP_INTERFACE_PYTHON=${APP_INTERFACE_PYTHON:-$LANE/venv/bin/python}
export MINI_OPERATOR_UID MINI_OPERATOR_NAME APP_INTERFACE_PYTHON
[[ -x $APP_INTERFACE_PYTHON ]] || {
  echo "create $LANE/venv from src/scripts/spk-platform/app-interface/requirements.txt" >&2
  exit 2
}
cleanup() {
  rc=$?
  trap - EXIT
  if [[ -f $RUN/WORLD.env || -f $RUN/broker-setup/recovery.json ]]; then
    down_rc=0
    bash "$LANE/src/scripts/spk-platform/world-down.sh" "$RUN" || down_rc=$?
    if [[ $rc == 0 ]]; then rc=$down_rc; fi
  fi
  exit "$rc"
}
trap cleanup EXIT
MINI_IMPORT_PROFILE=market-large-v1 flock -o /tank/lanes/world-up.lock \
  bash "$LANE/src/scripts/spk-platform/world-up.sh" "$LANE/bin" "$LANE/bin" "$RUN"
MINI_MARKET_CACHE="$CACHE" QUALIFY_TABLE="$RECIPE/qualify.tsv" \
  QUALIFY_WRITES="$RECIPE/qualify-writes" QUALIFY_STOP=1 \
  bash "$LANE/src/scripts/spk-platform/featured-qualify.sh" "$RUN/WORLD.env" "$OUT" l
