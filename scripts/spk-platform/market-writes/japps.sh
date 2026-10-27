# shellcheck shell=bash
# shellcheck disable=SC2154 # $body is the caller's scratch response path.
# Etherpad's Sandstorm build rejects every /api call in src/node/handler/APIHandler.js.
# Its own pad UI instead POSTs multipart field `file` to /p/:pad/import; a .txt upload
# reaches pad.setText(), and /p/:pad/export/txt is the package's read-back route.
write_Etherpad() {
  local text='written by a resident through the pad import'
  printf '%s\n' "$text" >"$body.import"
  local put; put=$(req POST /p/featured/import -F "file=@$body.import;filename=featured.txt;type=text/plain")
  if [[ $put != 200 ]] || ! jq -e '.code == 0' "$body" >/dev/null 2>&1; then
    echo "0 POST /p/featured/import $put: $(head -c 120 "$body")"; return
  fi
  local got; got=$(req GET /p/featured/export/txt)
  [[ $got == 200 ]] && grep -Fq "$text" "$body" && \
    echo "1 POST /p/featured/import $put; GET export/txt $got"
}
