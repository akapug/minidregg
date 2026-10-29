#!/usr/bin/env bash
# Exercise one existing browser route across the standing world's tail boundary.
# No retries: each refused/uncertain response is retained and fails the run.
set -euo pipefail
[[ $# == 4 || $# == 5 ]] || { echo "usage: $0 WORLD.env ROUTE_DIR NEW_OUT COUNT [PATH]" >&2; exit 2; }
. "$1"
route=$2 out=$3 count=$4 page=${5:-/}
[[ $count =~ ^[1-9][0-9]*$ && ! -e $out ]] || exit 2
umask 077
mkdir -p "$out"
world=$(dirname "$1")
"$BIN/mini" checkpoint --action view --workspace "$world/certifier" >"$out/before.json"
failed=0
for ((i=1; i<=count; i++)); do
  : >"$out/last.headers"
  : >"$out/last.body"
  code=$(curl --silent --show-error --max-time 120 --unix-socket "$route/http.sock" \
    -H 'Host: grain.test' -H 'Origin: https://grain.test' \
    -H "Cookie: __Host-mini_spk_session=$(cat "$route/browser.token")" \
    -D "$out/last.headers" -o "$out/last.body" -w '%{http_code}' "http://grain.test$page") || code=transport-error
  printf '%s\t%s\n' "$i" "$code" | tee -a "$out/gets.tsv"
  if [[ $code != 200 ]]; then
    cp "$out/last.body" "$out/refused-$i.body"
    cp "$out/last.headers" "$out/refused-$i.headers"
    failed=1
    break
  fi
done
"$BIN/mini" checkpoint --action view --workspace "$world/certifier" >"$out/after.json"
# A sweep longer than L must actually cross a certification, not quietly reuse
# one dispatch receipt. The Host's public view supplies both coordinates.
jq -e --argjson count "$count" --slurpfile before "$out/before.json" '
  (.head|tonumber) >= (($before[0].head|tonumber) + $count) and
  ((.tail|tonumber) <= (.tailBound|tonumber)) and
  (if $count > (.tailBound|tonumber) then
    (.certifiedHeight|tonumber) > ($before[0].certifiedHeight|tonumber)
   else true end)' "$out/after.json" >/dev/null || failed=1
[[ $failed == 0 ]] && echo "PASS $count fresh GET dispatches; bounded tail and advancing certification" || {
  echo 'FAIL route browsing; retained reply and before/after system views name the boundary' >&2
  exit 1
}
