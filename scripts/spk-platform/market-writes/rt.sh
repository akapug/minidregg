# rt batch: writes that ride a realtime channel or a cookie-bound form. Recipes below are REASONED
# from each app's source and docs, not proven by a live write (see the lifecycle rows in the report).
rt_py="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/rt-sio.py"

# WBO 1.20 (github.com/lovasoa/whitebophir): server.js `socket.on("getboard")` joins the board,
# `socket.on("broadcast")` applies {board, data:{tool,type,id,...}}; GET /boards/<name>.json is
# boardData.getAll() (routes in server/sockets.js and server/server.js).
write_WBO() {
  local board=featured res
  res=$(python3 -I "$rt_py" wbo "$dir" "$board" 2>&1 | tail -1)
  [[ $res == *'"ok": true'* ]] || { echo "0 socket.io broadcast: ${res:0:160}"; return; }
  local id; id=$(sed 's/.*"id": "\([^"]*\)".*/\1/' <<<"$res")
  local got; got=$(req GET "/boards/$board.json")
  [[ $got == 200 ]] && grep -q "$id" "$body" && { echo "1 socket.io broadcast Rectangle $id; GET /boards/$board.json $got"; return; }
  echo "0 socket.io broadcast sent as $id; GET /boards/$board.json $got without it [$(head -c 160 "$body" | tr '\r\n\t' '   ')]"
}

# HedgeDoc 1.9.8: GET /new makes a note (303 to /<id>, row evidence from the featured table's
# write_HedgeDoc); lib/realtime.js `operation` (revision, TextOperation JSON, selection) on
# /socket.io/?noteId=<id> never reaches body-parser, so the package's missing iconv-lite is not hit.
# The note is persisted on the server's dirty-note timer, so the read-back polls /download.
write_HedgeDocRT() {
  local made; made=$(req GET /new)
  local note; note=$(grep -i '^location:' "$body.headers" | tr -d '\r' | awk '{print $2}'); note=${note#https://grain.test}; note=${note#/}
  [[ $made =~ ^30 && -n $note ]] || { echo "0 GET /new $made: no note id"; return; }
  local res; res=$(python3 -I "$rt_py" hedgedoc "$dir" "$note" 2>&1 | tail -1)
  [[ $res == *'"ok": true'* ]] || { echo "0 socket.io operation on $note: ${res:0:160}"; return; }
  local i got
  for i in $(seq 1 20); do
    got=$(req GET "/$note/download")
    [[ $got == 200 ]] && grep -q 'written by a resident over socket.io' "$body" && { echo "1 socket.io operation -> $note; GET download $got (poll $i)"; return; }
    sleep 3
  done
  echo "0 operation acked but /$note/download never showed the text (last $got)"
}

# The typed declarations own Wekan/Gogs methods, authentication and read-back.
# These rows exercise the same source that emits their Hermes schemas.
write_Wekan() { typed_app_row wekan; }
write_Gogs() { typed_app_row gogs; }
