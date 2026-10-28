#!/bin/bash
# Internal: choose an intake budget; the real grain install still decides admission.
set -euo pipefail
host=$1 file=$2 raw=$3 decoded=$4 evidence=$5
here=$(cd "$(dirname "$0")" && pwd)
read -r rawlimit decodedlimit seconds < <("$host" import-limits standard-v1 "$raw")
profile=$(python3 "$here/store-sweep-data.py" profile "$raw" "$decoded" "$rawlimit" "$decodedlimit")
if [[ $profile == standard-v1 ]]; then
  # Bytes alone do not predict Cap'n Proto's segment count. Let the candidate's
  # bounded decoder name that structural limit; do not implement an SPK parser here.
  # Other preflight refusals are retained, but only the real install judges the app.
  status=0
  timeout --kill-after=5s "$seconds" "$host" qualify --import-profile standard-v1 "$file" \
    >"$evidence.out" 2>"$evidence.err" || status=$?
  printf '%s\n' "$status" >"$evidence.exit"
  if [[ $status != 0 ]] && grep -Eq "^spk-host: too many Cap'n Proto segments: [0-9]+ exceeds bound [0-9]+$" "$evidence.err"; then
    profile=market-large-v1
  fi
fi
printf '%s\n' "$profile"
