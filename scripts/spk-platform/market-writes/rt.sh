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
  [[ $got == 200 ]] && grep -q "$id" "$body" && echo "1 socket.io broadcast Rectangle $id; GET /boards/$board.json $got"
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
# session cookies Gogs sets (i_like_gogits, _csrf), so this request keeps a cookie jar on top of
# the route token. Create: POST /repo/create (routers/repo/repo.go CreatePost: user_id, repo_name,
# auto_init). File: POST /<owner>/<repo>/_new/master/ (routers/repo/editor.go NewFilePost:
# tree_path, content, commit_summary, commit_choice=direct). Read: GET /<owner>/<repo>/raw/master/<file>.
# `git push` needs streamed request bodies, which the bridge does not serve yet: waiting on streamed bodies.
gogs_req() { # METHOD PATH [CURL ARGS]; keeps $gogs_jar across calls
  local method=$1 path=$2; shift 2
  curl -sS --max-time 900 --unix-socket "$dir/http.sock" -X "$method" -H 'Host: grain.test' \
    -H "Cookie: __Host-mini_spk_session=$(cat "$dir/browser.token")${gogs_jar:+; $gogs_jar}" -H 'Origin: https://grain.test' \
    -o "$body" -D "$body.headers" -w '%{http_code}' "$@" "http://grain.test$path" 2>>"$out/curl.err"
  local c; while read -r c; do
    gogs_jar=$(printf '%s\n%s\n' "${gogs_jar//; /$'\n'}" "$c" | awk -F= 'NF&&!seen[$1]++{printf "%s%s", (n++?"; ":""), $0}')
  done < <(grep -i '^set-cookie:' "$body.headers" | tr -d '\r' | sed 's/^[Ss]et-[Cc]ookie: *//; s/;.*//')
}
write_Gogs() {
  gogs_jar=""
  local form; form=$(gogs_req GET /repo/create)
  local csrf uid; csrf=$(grep -o 'name="_csrf" value="[^"]*"' "$body" | head -1 | sed 's/.*value="//; s/"//')
  uid=$(grep -o 'name="user_id" value="[0-9]*"' "$body" | head -1 | sed 's/.*value="//; s/"//')
  [[ $form == 200 && -n $csrf && -n $uid ]] || { echo "0 GET /repo/create $form, _csrf '${csrf:-}', user_id '${uid:-}'"; return; }
  local made; made=$(gogs_req POST /repo/create --data-urlencode "_csrf=$csrf" --data-urlencode "user_id=$uid" \
    --data-urlencode repo_name=featured --data-urlencode 'description=made by a resident' --data-urlencode auto_init=on \
    --data-urlencode readme=Default)
  local repo; repo=$(grep -i '^location:' "$body.headers" | tr -d '\r' | awk '{print $2}'); repo=${repo#https://grain.test}
  [[ $made =~ ^30 && -n $repo ]] || { echo "0 POST /repo/create $made (app output names the cause)"; return; }
  local ed; ed=$(gogs_req GET "$repo/_new/master/")
  csrf=$(grep -o 'name="_csrf" value="[^"]*"' "$body" | head -1 | sed 's/.*value="//; s/"//')
  [[ $ed == 200 && -n $csrf ]] || { echo "0 GET $repo/_new/master/ $ed, _csrf '${csrf:-}'"; return; }
  local save; save=$(gogs_req POST "$repo/_new/master/" --data-urlencode "_csrf=$csrf" --data-urlencode tree_path=featured.txt \
    --data-urlencode 'content=filed by a resident' --data-urlencode 'commit_summary=resident' --data-urlencode commit_choice=direct)
  local got; got=$(gogs_req GET "$repo/raw/master/featured.txt")
  [[ $save =~ ^30 && $got == 200 ]] && grep -q 'filed by a resident' "$body" && echo "1 POST /repo/create $made -> $repo; _new save $save; raw $got"
}
