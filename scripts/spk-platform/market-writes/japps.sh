# shellcheck shell=bash
# shellcheck disable=SC2154 # $body is the caller's scratch response path.
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
