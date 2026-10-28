# Batch B7 (doors): write recipes, reasoned from each package's own source (no live probe).
# All four unpack to well under 64 MiB raw: class S.

# 2048 0.0.2 (package 10da5d47: php-fpm + nginx behind the bridge on 8000; /opt/app/api.php over
# /var/db2048.sqlite, one row per Sandstorm user: bestScore and gameState). The page's own calls
# (js/local_storage_manager.js) are POST /api.php with a JSON body {key, bestScore} or {key, gamestate},
# and GET /api.php?action=getbestscore|getgamestate. The saved score and the saved board are the grain's
# storage; the write is both, read back through the page's own getters.
write_2048() {
  local score=20480
  local p1; p1=$(req POST /api.php -H 'Content-Type: application/json' -d "{\"key\":\"bestScore\",\"bestScore\":$score}")
  local p2; p2=$(req POST /api.php -H 'Content-Type: application/json' \
    -d '{"key":"gameState","gamestate":{"grid":{"size":4,"cells":[]},"score":4096,"over":false,"won":false,"keepPlaying":false}}')
  local g1; g1=$(req GET '/api.php?action=getbestscore&key=bestScore')
  jq -e --argjson s "$score" '(.value | tonumber) >= $s' "$body" >/dev/null 2>&1 || { echo "0 POST /api.php $p1 $p2; GET getbestscore $g1: $(head -c 120 "$body" | tr -d '\n')"; return; }
  local g2; g2=$(req GET '/api.php?action=getgamestate&key=gameState')
  [[ $p1 == 200 && $p2 == 200 && $g1 == 200 && $g2 == 200 ]] && jq -e '.value.score == 4096' "$body" >/dev/null 2>&1 \
    && echo "1 POST /api.php $p1 (bestScore $score) and $p2 (gamestate); GET getbestscore $g1 and getgamestate $g2 read both back" \
    || echo "0 POST /api.php $p1 $p2; GET getgamestate $g2: gamestate not read back"
}

# Perplexity Sudoku 0.0.1 (package 70f47fff: a Flask app, `python3 run.py` on 5000, SQLAlchemy over
# /var/sudoku_games.db; /opt/app/app.py). Its saved game is a row per Sandstorm user. Routes read: POST
# /api/new-game {difficulty} makes a puzzle and a row (returns game_id and the puzzle); PUT /api/game/<id>
# {board_state, time_spent, is_complete} saves it; GET /api/game/<id> returns it. All JSON, so
# Content-Type: application/json (request.get_json needs it).
write_PerplexitySudoku() {
  local made; made=$(req POST /api/new-game -H 'Content-Type: application/json' -d '{"difficulty":"easy"}')
  local id; id=$(jq -r 'select(.success == true) | .game_id // empty' "$body" 2>/dev/null)
  [[ $made == 200 && -n $id ]] || { echo "0 POST /api/new-game $made: $(head -c 120 "$body" | tr -d '\n')"; return; }
  local board; board=$(jq -c '.puzzle' "$body")
  local put; put=$(req PUT "/api/game/$id" -H 'Content-Type: application/json' \
    -d "{\"board_state\":$board,\"time_spent\":4242,\"is_complete\":false}")
  local got; got=$(req GET "/api/game/$id")
  [[ $put == 200 && $got == 200 ]] && jq -e '.success == true and .game.time_spent == 4242 and .game.is_complete == false' "$body" >/dev/null 2>&1 \
    && echo "1 POST /api/new-game $made (game $id); PUT /api/game/$id $put; GET $got holds time_spent 4242" \
    || echo "0 PUT /api/game/$id $put, GET $got: saved game not read back"
}

# 3D Blockstack 0.0.2 (package 97291f51: php-fpm + nginx behind the bridge on 8000; /opt/app/api.php over
# /var/db3d.sqlite). Js/script.js saves the high score with POST /api.php {bestScore} and loads it with
# GET /api.php?action=getbestscore&key=bestScore, which answers {"value":"<n>"}. highscores.php lists the
# table; the write is read back through both.
write_3DBlockstack() {
  local score=77
  local p; p=$(req POST /api.php -H 'Content-Type: application/json' -d "{\"bestScore\":$score}")
  local g; g=$(req GET '/api.php?action=getbestscore&key=bestScore')
  jq -e --argjson s "$score" '(.value | tonumber) >= $s' "$body" >/dev/null 2>&1 || { echo "0 POST /api.php $p; GET getbestscore $g: $(head -c 120 "$body" | tr -d '\n')"; return; }
  local h; h=$(req GET /highscores.php)
  [[ $p == 200 && $g == 200 && $h == 200 ]] && grep -q "<strong>$score</strong>" "$body" \
    && echo "1 POST /api.php $p (bestScore $score); GET getbestscore $g; GET /highscores.php $h lists it" \
    || echo "0 GET /highscores.php $h: score $score not listed"
}

# Simple Chat 0.6.1 (package 91ae6a99: NO http-bridge; /serve serves WebSession itself, source
# wholezero/simple-chat src/serve.c++). Routes: GET /chats and /topic answer text/plain (a "?new"
# suffix long-polls, so it is not used); POST /chats appends "<handle>: <text>\n" and redirects to "/";
# PUT /topic sets the topic and logs "<handle> set the topic to: ...". The logged-room action (/serve -i)
# keeps these in /var/chats and /var/topic, so the read-back is the grain's storage.
