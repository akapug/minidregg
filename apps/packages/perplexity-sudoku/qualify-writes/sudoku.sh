# shellcheck shell=bash
# state, app, dir, body, out and req are supplied by featured-qualify.sh.
# shellcheck disable=SC2154
# A saved game is a row per Sandstorm user: POST /api/new-game makes it, PUT /api/game/<id> saves a
# board and time, GET reads it back. Then the installed descriptor must list api beside web.
write_PerplexitySudoku() {
  local made id board put got descriptor
  made=$(req POST /api/new-game -H 'Content-Type: application/json' -d '{"difficulty":"easy"}')
  id=$(jq -r 'select(.success == true) | .game_id // empty' "$body" 2>/dev/null)
  [[ $made == 200 && -n $id ]] || { echo "0 POST /api/new-game $made: $(head -c 120 "$body" | tr -d '\n')"; return; }
  board=$(jq -c '.puzzle' "$body")
  put=$(req PUT "/api/game/$id" -H 'Content-Type: application/json' \
    -d "{\"board_state\":$board,\"time_spent\":4242,\"is_complete\":false}")
  got=$(req GET "/api/game/$id")
  if [[ $put == 200 && $got == 200 ]] && jq -e '.success == true and .game.time_spent == 4242 and .game.is_complete == false' "$body" >/dev/null 2>&1; then
    descriptor="$state/apps/$app/install/launch-descriptor/package-v1/descriptor-inspection.json"
    if [[ -f $descriptor ]] && jq -e '.interfaces | map(.kind) | (index("api") and index("web"))' "$descriptor" >/dev/null; then
      cp "$descriptor" "$out/sudoku-descriptor-inspection.json"
      echo "1 POST /api/new-game $made (game $id); PUT $put; GET $got holds time_spent 4242; descriptor lists api and web"
    else
      echo "0 write passed, but installed descriptor does not list both api and web: $descriptor"
    fi
  else
    echo "0 PUT /api/game/$id $put, GET $got: saved game not read back"
  fi
}
