# rt batch: writes that ride a realtime channel or a cookie-bound form. Recipes below are REASONED
# from each app's source and docs, not proven by a live write (see the lifecycle rows in the report).
rt_py="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/rt-sio.py"

# WBO 1.20 (github.com/lovasoa/whitebophir): server.js `socket.on("getboard")` joins the board and answers one
# `broadcast` event with the board's items; `socket.on("broadcast")` applies {board, data:{tool,type,id,...}}.
# A getboard on a second socket proves only the server's memory. The row passes only when the item is also in the
# SAVED board: boardData.js writes $WBO_HISTORY_DIR (/var/wbo_data) board-<name>.json after SAVE_INTERVAL (2 s) of
# inactivity, and GET /download/<board> serves that file (a missing or unreadable file is a 500, serveError). So
# the row needs both the getboard read-back and /download/<board> holding the id after the save interval; a save
# that fails is a product red (data loss on restart), reported with the app's own error line.
write_WBO() {
  local board=featured res
  res=$(python3 -I "$rt_py" wbo "$dir" "$board" 2>&1 | tail -1)
  [[ $res == *'"ok": true'* ]] || { echo "0 socket.io write or getboard read-back: ${res:0:200}"; return; }
  local id; id=$(sed 's/.*"id": "\([^"]*\)".*/\1/' <<<"$res")
  local dl try
  for try in 1 2 3 4 5 6; do
    dl=$(req GET "/download/$board")
    [[ $dl == 200 ]] && grep -q "$id" "$body" && { echo "1 socket.io broadcast Rectangle $id: in memory (second socket's getboard) and saved (GET /download/$board $dl, try $try)"; return; }
    sleep 4
  done
  echo "0 item $id is in the server's memory (getboard) but not in the saved board: GET /download/$board $dl after $try tries [$(head -c 100 "$body" | tr '\r\n\t' '   ')]"
}

# The typed declarations own Wekan/Gogs methods, authentication and read-back.
# These rows exercise the same source that emits their Hermes schemas.
write_Wekan() { typed_app_row wekan; }
write_Gogs() { typed_app_row gogs; }
