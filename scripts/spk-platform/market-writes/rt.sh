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

# Wekan (12.65): Meteor app; Sandstorm login is the DDP `login` method with {sandstorm:true}
# (models/users.js sandstorm handler), then client-allowed collection inserts
# (/boards/insert, /swimlanes/insert, /lists/insert, /cards/insert) and the `board` publication.
# The 2026-10-27 run never reached it: the install is refused by name ("SPK exceeds decoded bound").
write_Wekan() {
  local res; res=$(python3 -I "$rt_py" wekan "$dir" "featured card by a resident" 2>&1 | tail -1)
  [[ $res == *'"ok": true'* ]] && echo "1 DDP login+inserts, card read back from the board subscription: ${res:0:120}" || echo "0 DDP: ${res:0:200}"
}

# Gogs 0.11.34: reverse-proxy (Sandstorm header) login; forms carry `_csrf` and are bound to the
# session cookies Gogs sets (i_like_gogits, _csrf), so this recipe uses jreq (featured-qualify.sh), a cookie jar on top of
# the route token. Create: POST /repo/create (routers/repo/repo.go CreatePost: user_id, repo_name,
# auto_init). File: POST /<owner>/<repo>/_new/master/ (routers/repo/editor.go NewFilePost:
# tree_path, content, commit_summary, commit_choice=direct). Read: GET /<owner>/<repo>/raw/master/<file>.
# `git push` needs streamed request bodies, which the bridge does not serve yet: waiting on streamed bodies.
write_Gogs() {
  jar=""
  jreq GET /repo/create; local form=$JS
  local csrf uid; csrf=$(grep -o 'name="_csrf" value="[^"]*"' "$body" | head -1 | sed 's/.*value="//; s/"//')
  uid=$(grep -o 'name="user_id" value="[0-9]*"' "$body" | head -1 | sed 's/.*value="//; s/"//')
  [[ $form == 200 && -n $csrf && -n $uid ]] || { echo "0 GET /repo/create $form, _csrf '${csrf:-}', user_id '${uid:-}'"; return; }
  jreq POST /repo/create --data-urlencode "_csrf=$csrf" --data-urlencode "user_id=$uid" \
    --data-urlencode repo_name=featured --data-urlencode 'description=made by a resident' --data-urlencode auto_init=on \
    --data-urlencode readme=Default; local made=$JS
  local repo; repo=$(grep -i '^location:' "$body.headers" | tr -d '\r' | awk '{print $2}'); repo=${repo#https://grain.test}
  [[ $made =~ ^30 && -n $repo ]] || { echo "0 POST /repo/create $made (app output names the cause)"; return; }
  jreq GET "$repo/_new/master/"; local ed=$JS
  csrf=$(grep -o 'name="_csrf" value="[^"]*"' "$body" | head -1 | sed 's/.*value="//; s/"//')
  [[ $ed == 200 && -n $csrf ]] || { echo "0 GET $repo/_new/master/ $ed, _csrf '${csrf:-}'"; return; }
  jreq POST "$repo/_new/master/" --data-urlencode "_csrf=$csrf" --data-urlencode tree_path=featured.txt \
    --data-urlencode 'content=filed by a resident' --data-urlencode 'commit_summary=resident' --data-urlencode commit_choice=direct; local save=$JS
  jreq GET "$repo/raw/master/featured.txt"; local got=$JS
  [[ $save =~ ^30 && $got == 200 ]] && grep -q 'filed by a resident' "$body" && echo "1 POST /repo/create $made -> $repo; _new save $save; raw $got"
}
