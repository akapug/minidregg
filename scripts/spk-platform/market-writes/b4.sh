# B4 publishing writes. Reasoned recipes (NOT proven by a run): the lifecycle rows of the first
# pass are the only evidence; no app's write endpoint was probed live (COORDINATION section 4).
# $dir is .../apps/<app>/routes/owner-web, so the app's publishing socket is ../../www.sock.

# b4_www PATH: GET PATH through the resident's publishing socket; status on stdout, body in $body.www
b4_www() {
  curl -sS --max-time 120 --unix-socket "${dir%/routes/*}/www.sock" -H 'Host: grain.test' \
    -o "$body.www" -w '%{http_code}' "http://grain.test$1" 2>>"$out/curl.err"
}

# WordPress: lifecycle PASS (row evidence: php-fpm + nginx started, page 200). Recipe from
# https://developer.wordpress.org/rest-api/using-the-rest-api/authentication/ (cookie auth +
# X-WP-Nonce, nonce read from wpApiSettings in /wp-admin/post-new.php); Sandstorm's WordPress
# logs the owner in from the bridge permissions. The read-back is the app's own rendering of the
# post (/?p=ID over the owner route); www.sock is probed and its status named, not gated on,
# because WordPress renders dynamically rather than writing /var/www.
write_WordPress() {
  local page; page=$(req GET /wp-admin/post-new.php)
  local nonce; nonce=$(grep -o '"nonce":"[0-9a-f]*"' "$body" | head -1 | sed 's/.*:"//; s/"//')
  [[ $page == 200 && -n $nonce ]] || { echo "0 post-new.php $page, no REST nonce (wpApiSettings)"; return; }
  local made; made=$(req POST /wp-json/wp/v2/posts -H "X-WP-Nonce: $nonce" -H 'Content-Type: application/json' \
    --data '{"title":"featured","content":"published by a resident","status":"publish"}')
  local id; id=$(jq -r '.id // empty' "$body" 2>/dev/null)
  [[ $made =~ ^20 && -n $id ]] || { echo "0 POST wp-json/wp/v2/posts $made: $(head -c 120 "$body" | tr -d '\n')"; return; }
  local got; got=$(req GET "/?p=$id")
  local www; www=$(b4_www "/?p=$id")
  [[ $got == 200 ]] && grep -q 'published by a resident' "$body" && echo "1 POST wp/v2/posts $made id $id; GET /?p=$id $got (owner preview); www.sock $www"
}

# Hugo: the install ingest timed out on the loaded box (spk-ingest unit TIMEOUT at 2 min, 436 s row),
# so no grain ran and nothing of the app was seen. Recipe reasoned from the Sandstorm Hugo package
# (https://github.com/sandstorm-io/... hugo app: an editor over /var/www/content and a build that writes
# /var/www): create a content file, run the build, read the generated page through www.sock.
# Endpoints are a guess; the first request discovers the editor's form actions and the row names it.
write_Hugo() {
  local home; home=$(req GET /)
  [[ $home == 200 ]] || { echo "0 GET / $home"; return; }
  local made; made=$(req PUT /content/featured.md -H 'Content-Type: text/markdown' --data-binary $'---\ntitle: featured\n---\nwritten by a resident\n')
  [[ $made =~ ^20 ]] || { echo "0 PUT /content/featured.md $made: editor endpoint unconfirmed (reasoned recipe)"; return; }
  local built; built=$(req POST /build)
  local got; got=$(b4_www /featured/)
  [[ $got == 200 ]] && grep -q 'written by a resident' "$body.www" && echo "1 PUT content $made; POST /build $built; www.sock GET /featured/ $got"
}

# Hacker CMS: refused at install by the platform ("bridge-only SPK lacks signed config", row evidence,
# install-l.stderr): the package carries no signed config, so no grain exists. Recipe reasoned from
# Hacker CMS being a HackSession app that writes pages under /var/www: POST the page to the editor,
# read it back through www.sock (served by the resident for getPublicId apps).
write_HackerCMS() {
  local saved; saved=$(req POST /save --data-urlencode 'path=featured.html' --data-urlencode 'content=<p>written by a resident</p>')
  [[ $saved =~ ^(200|302|303)$ ]] || { echo "0 POST /save $saved: editor endpoint unconfirmed (reasoned recipe)"; return; }
  local got; got=$(b4_www /featured.html)
  [[ $got == 200 ]] && grep -q 'written by a resident' "$body.www" && echo "1 POST /save $saved; www.sock GET /featured.html $got"
}

# Hakyll CMS: lifecycle red at START (row evidence: resident unit exited before START completion,
# app-output empty; install itself passed). Recipe reasoned from Hakyll CMS's edit-and-rebuild flow:
# save a page source, trigger the site rebuild, read the built page through www.sock.
write_HakyllCMS() {
  local saved; saved=$(req POST /edit/featured.md --data-urlencode $'body=---\ntitle: featured\n---\nwritten by a resident\n')
  [[ $saved =~ ^(200|302|303)$ ]] || { echo "0 POST /edit/featured.md $saved: editor endpoint unconfirmed (reasoned recipe)"; return; }
  local built; built=$(req POST /rebuild)
  local got; got=$(b4_www /featured.html)
  [[ $got == 200 ]] && grep -q 'written by a resident' "$body.www" && echo "1 POST /edit $saved; POST /rebuild $built; www.sock GET /featured.html $got"
}
