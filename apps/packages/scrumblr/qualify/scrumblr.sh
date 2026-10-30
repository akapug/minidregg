# shellcheck shell=bash
# state, app, out, dir and here are supplied by featured-qualify.sh (here = its spk-platform
# dir). The market-batch row is stubbed upstream (b3.sh: native-conversation-receiver-not-
# attached; 6678fabd1 moved conversation bindings to native fixtures, and binding.py drives
# only http and ddp, so the typed row refuses scrumblr's conversation declaration with
# binding-protocol-unsupported -- deterministic, no bin in flight fixes it). This row follows
# the WBO precedent (apps/packages/wbo): a resident's script writes through the app's own
# socket.io -- served at /socketio in this snapshot, engine.io 4 -- and reads the card back
# in a fresh client's initCards. On top of it, the repackaged manifest's contract: the
# installed descriptor must list both api and web (bridgeConfig.apiPath "/").
write_Scrumblr() {
  local w res descriptor
  w=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  res=$(python3 -I "$w/scrumblr-sio.py" "$dir" /featured "$here/market-writes/rt-sio.py" 2>&1 | tail -1)
  [[ $res == *'"ok": true'* ]] || { echo "0 socket.io write: $res"; return; }
  descriptor="$state/apps/$app/install/launch-descriptor/package-v1/descriptor-inspection.json"
  if [[ -f $descriptor ]] && jq -e '.interfaces | map(.kind) | (index("api") != null and index("web") != null)' "$descriptor" >/dev/null; then
    cp "$descriptor" "$out/scrumblr-descriptor-inspection.json"
    echo "1 socket.io createCard, read back in a fresh client's initCards ($res); descriptor lists api and web (bridgeConfig.apiPath /)"
  else
    echo "0 socket.io write passed, but installed descriptor does not list both api and web: $descriptor"
  fi
}
