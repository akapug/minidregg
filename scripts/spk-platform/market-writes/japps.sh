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

# Hacker Slides' editor PUTs /slides.md (opt/app/main.py). That same route copies the
# markdown to /var/www/slides.md; no separate publish endpoint exists. The read-back is
# anonymous through the publishing socket, exactly as the static reveal.js deck loads it.
write_HackerSlides() {
  local marker='published by a resident through slides.md'
  printf '# %s\n\n---\n\n## Mini market write\n' "$marker" >"$body.slides.md"
  local saved; saved=$(req PUT /slides.md -H 'Content-Type: text/markdown' --data-binary @"$body.slides.md")
  [[ $saved == 200 ]] || { echo "0 PUT /slides.md $saved"; return; }
  local pub; pub=$(curl -sS --max-time 120 --unix-socket "${dir%/routes/*}/www.sock" -H 'Host: grain.test' \
    -o "$body.www" -w '%{http_code}' http://grain.test/slides.md 2>>"$out/curl.err")
  [[ $pub == 200 ]] && grep -Fq "$marker" "$body.www" && \
    echo "1 PUT /slides.md $saved; anonymous www.sock GET /slides.md $pub"
}
