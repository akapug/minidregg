# shellcheck shell=bash
# state, app, dir, body, out and req are supplied by featured-qualify.sh.
# shellcheck disable=SC2154
# The high score: POST /api.php {bestScore} saves it, GET getbestscore and /highscores.php read it back;
# then the installed descriptor must list api beside web.
write_3DBlockstack() {
  local score=77 p g h descriptor
  p=$(req POST /api.php -H 'Content-Type: application/json' -d "{\"bestScore\":$score}")
  g=$(req GET '/api.php?action=getbestscore&key=bestScore')
  jq -e --argjson s "$score" '(.value | tonumber) >= $s' "$body" >/dev/null 2>&1 || { echo "0 POST /api.php $p; GET getbestscore $g: $(head -c 120 "$body" | tr -d '\n')"; return; }
  h=$(req GET /highscores.php)
  if [[ $p == 200 && $g == 200 && $h == 200 ]] && grep -q "<strong>$score</strong>" "$body"; then
    descriptor="$state/apps/$app/install/launch-descriptor/package-v1/descriptor-inspection.json"
    if [[ -f $descriptor ]] && jq -e '.interfaces | map(.kind) | (index("api") and index("web"))' "$descriptor" >/dev/null; then
      cp "$descriptor" "$out/blockstack-descriptor-inspection.json"
      echo "1 POST /api.php $p (bestScore $score); GET getbestscore $g; GET /highscores.php $h lists it; descriptor lists api and web"
    else
      echo "0 write passed, but installed descriptor does not list both api and web: $descriptor"
    fi
  else
    echo "0 GET /highscores.php $h: score $score not listed"
  fi
}
