# shellcheck shell=bash
# state, app, dir, body, out and req are supplied by featured-qualify.sh.
# shellcheck disable=SC2154
wbo_py="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/wbo-sio.py"

# WBO 2.18 joins a board through the socket.io query and sends numeric create
# mutations. Require both a fresh connection's replay and the saved SVG, then
# require the installed package descriptor to export api beside web.
write_WBO() {
  local board=board res id dl try descriptor
  res=$(python3 -I "$wbo_py" "$dir" "$board" 2>&1 | tail -1)
  [[ $res == *'"ok": true'* ]] || { echo "0 socket.io create or replay read-back: ${res:0:240}"; return; }
  id=$(sed 's/.*"id": "\([^"]*\)".*/\1/' <<<"$res")
  for try in 1 2 3 4 5 6; do
    dl=$(req GET "/download/$board")
    if [[ $dl == 200 ]] && grep -q "$id" "$body"; then
      descriptor="$state/apps/$app/install/launch-descriptor/package-v1/descriptor-inspection.json"
      if [[ -f $descriptor ]] && jq -e '.interfaces | map(.kind) | (index("api") and index("web"))' "$descriptor" >/dev/null; then
        cp "$descriptor" "$out/wbo-descriptor-inspection.json"
        echo "1 socket.io Rectangle $id replayed and saved (GET /download/$board $dl, try $try); descriptor lists api and web"
      else
        echo "0 write passed, but installed descriptor does not list both api and web: $descriptor"
      fi
      return
    fi
    sleep 4
  done
  echo "0 item $id replayed but was not saved: GET /download/$board $dl after $try tries [$(head -c 100 "$body" | tr '\r\n\t' '   ')]"
}
