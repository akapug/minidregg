# B4 publishing writes. Reasoned recipes (NOT proven by a run): the lifecycle rows of the first
# pass are the only evidence; no app's write endpoint was probed live (COORDINATION section 4).
# $dir is .../apps/<app>/routes/owner-web, so the app's publishing socket is ../../www.sock.

# b4_www PATH: GET PATH through the resident's publishing socket; status on stdout, body in $body.www
b4_www() {
  curl -sS --max-time 120 --unix-socket "${dir%/routes/*}/www.sock" -H 'Host: grain.test' \
    -o "$body.www" -w '%{http_code}' "http://grain.test$1" 2>>"$out/curl.err"
}

# WordPress (package d6955e8f, 4.x with php-fpm 7.3 + nginx + sqlite-integration, large class). Lifecycle PASS.
# Source: the package's wordpress-read-only/wp-admin/install.php (Sandstorm's replacement: it calls
# wp_install("example blog", "User", ...) with fixed data and no form) and read-only-plugins/mu-plugins/
# sandstorm.php (auto_login(): if is_blog_installed() and nobody is logged in, it creates or loads a WP user
# from X-Sandstorm-User-Id, maps X-Sandstorm-Permissions admin/editor/author/... to a WP role, and sets the
# auth cookie). The run on e89fe7b8b answered GET /wp-admin/post-new.php 303 to /wp-admin/install.php: the blog
# is NOT installed until something visits install.php, and auto_login does nothing before that. So: GET
# /wp-admin/install.php once (installs, redirects to index.php), then GET post-new.php (auto_login sets the
# cookie on that response), then again WITH the cookie jar so the page's wpApiSettings nonce is bound to the
# logged-in session token, and POST the REST post with that nonce (cookie auth + X-WP-Nonce:
# https://developer.wordpress.org/rest-api/using-the-rest-api/authentication/). The read-back is the app's
# rendering of the post (/?p=ID over the owner route); www.sock is probed and named, not gated on, because
# WordPress renders dynamically rather than writing /var/www.
write_WordPress() {
  jar=""
  jreq GET /wp-admin/install.php; local inst=$JS
  jreq GET /wp-admin/post-new.php
  jreq GET /wp-admin/post-new.php; local page=$JS
  local nonce; nonce=$(grep -o '"nonce":"[0-9a-f]*"' "$body" | head -1 | sed 's/.*:"//; s/"//')
  [[ $page == 200 && -n $nonce ]] || { echo "0 install.php $inst, post-new.php $page, no REST nonce (wpApiSettings): $(grep -i '^location:' "$body.headers" | tr -d '\r' | head -1)"; return; }
  jreq POST '/?rest_route=/wp/v2/posts' -H "X-WP-Nonce: $nonce" -H 'Content-Type: application/json' \
    --data '{"title":"featured","content":"published by a resident","status":"publish"}'
  local made=$JS id; id=$(jq -r '.id // empty' "$body" 2>/dev/null)
  [[ $made =~ ^20 && -n $id ]] || { echo "0 POST ?rest_route=/wp/v2/posts $made: $(head -c 120 "$body" | tr -d '\n')"; return; }
  jreq GET "/?p=$id"; local got=$JS
  local www; www=$(b4_www "/?p=$id")
  [[ $got == 200 ]] && grep -q 'published by a resident' "$body" && echo "1 GET install.php $inst; POST wp/v2/posts $made id $id; GET /?p=$id $got (owner preview); www.sock $www"
}

# Hugo (the member-website app). The package is "hugo-standstorm": launcher.sh keeps a git repo in /var/git
# (copied from /opt/app/template), a Cloud Commander file manager serves it under the prefix /admin
# (root /var/git), and `GET /commit` runs `git add .; git commit` then /opt/app/post-receive, which is
# `hugo -d /var/www`. The ingest wall of the first pass (436 s) is app-market 91429251's, not the recipe's.
# Recipe: write content/featured.md through Cloud Commander's REST (PUT /admin/api/v1/fs/<path> creates the
# file from the body), build with GET /commit ({"ok":true}), then read the page from the grain's -www origin
# ANONYMOUSLY (www.sock, no cookie), which serves /var/www to the public.
write_Hugo() {
  local made; made=$(req PUT /admin/api/v1/fs/content/featured.md -H 'Content-Type: text/markdown' \
    --data-binary $'---\ntitle: featured\ndate: 2026-10-27\ndraft: false\n---\nwritten by a resident\n')
  [[ $made =~ ^20 ]] || { echo "0 PUT /admin/api/v1/fs/content/featured.md $made: $(head -c 120 "$body" | tr -d '\n')"; return; }
  local back; back=$(req GET /admin/api/v1/fs/content/featured.md)
  [[ $back == 200 ]] && grep -q 'written by a resident' "$body" || { echo "0 file not read back through the editor ($back)"; return; }
  local built; built=$(req GET /commit)
  [[ $built == 200 ]] && grep -q '"ok":true' "$body" || { echo "0 GET /commit $built: $(head -c 160 "$body" | tr -d '\n') (hugo -d /var/www did not report ok)"; return; }
  local got; got=$(b4_www /featured/)
  [[ $got == 200 ]] && grep -q 'written by a resident' "$body.www" && echo "1 PUT content/featured.md $made; GET /commit $built; anonymous www.sock GET /featured/ $got"
}

# Hacker CMS (package d269b9e9, server/ssjekyll.c++ in bin/ssjekyll, editor in client/index.html). The package
# has no sandstorm-http-bridge-config; 365aaad7 gives it the canonical empty bridge config, so it installs.
# Editor routes, read from client/index.html and the binary: GET /file is the source tree as JSON, GET|PUT|DELETE
# /file/<path> reads, writes and removes a file under /var/src, POST /publish runs
# `jekyll build -s /var/src -d /var/www --config /var/src/_config_published.yaml`, and the grain's -www origin
# serves /var/www. Recipe: PUT /file/featured.md (empty front matter, so Jekyll converts it to /featured.html
# with no layout), read it back from GET /file/featured.md and from the GET /file tree, POST /publish, then
# read /featured.html through the publishing socket (www.sock). Jekyll is Ruby and slow, so the www read polls.
write_HackerCMS() {
  local saved; saved=$(req PUT /file/featured.md -H 'Content-Type: text/plain' --data-binary $'---\n---\nwritten by a resident\n')
  [[ $saved =~ ^20 ]] || { echo "0 PUT /file/featured.md $saved: $(head -c 120 "$body" | tr -d '\n')"; return; }
  local back; back=$(req GET /file/featured.md)
  [[ $back == 200 ]] && grep -q 'written by a resident' "$body" || { echo "0 source not read back through GET /file/featured.md ($back)"; return; }
  local tree; tree=$(req GET /file)
  [[ $tree == 200 ]] && jq -e 'has("featured.md")' "$body" >/dev/null || { echo "0 GET /file ($tree) does not list featured.md"; return; }
  local pub; pub=$(req POST /publish)
  [[ $pub =~ ^20 ]] || { echo "0 POST /publish $pub: $(head -c 120 "$body" | tr -d '\n')"; return; }
  local got=000 i
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    got=$(b4_www /featured.html)
    [[ $got == 200 ]] && grep -q 'written by a resident' "$body.www" && { echo "1 PUT /file/featured.md $saved; POST /publish $pub; www.sock GET /featured.html $got"; return; }
    sleep 5
  done
  echo "0 www.sock GET /featured.html $got after publish $pub"
}

# Hakyll CMS (package 49a44b77, sshakyll). First-pass lifecycle red: "resident unit ... is  before START
# completion" after 125 s, an EMPTY state. Cause (run evidence, dregg-build app-batch-4-runs/w1): not the
# package. The resident unit ran from 20:48:04 until the harness stopped the world at 20:51:40; the wait loop
# read an empty `systemctl --user show` (the box OOM-killed another lane's scope at that second) as a
# stopped unit. Fixed in spk-host grain.rs (an unreadable state is absorbed, not a verdict). The package
# itself starts under the Mini floor: action `sandstorm-http-bridge 8000 -- /startup.sh` writes /var/www,
# `cp -a /source /var`, then /bin/sshakyll, which listens on 127.0.0.1:8000 with cwd "/" (DIR default "var").
# Recipe (API read from the binary): the site source is a tree served as /api/file/<path> (GET reads, PUT
# writes, DELETE removes), config.json routes `posts/*` through templates/post.html, POST /api/publish
# rebuilds into /var/www, and the grain's -www origin serves it. A new post is posts/<name>.md, built to
# /posts/<name>.html.
write_HakyllCMS() {
  local name=2026-10-27-featured
  local saved; saved=$(req PUT "/api/file/posts/$name.md" -H 'Content-Type: text/plain' --data-binary $'---\ntitle: featured\n---\nwritten by a resident\n')
  [[ $saved =~ ^20 ]] || { echo "0 PUT /api/file/posts/$name.md $saved: $(head -c 120 "$body" | tr -d '\n')"; return; }
  local back; back=$(req GET "/api/file/posts/$name.md")
  [[ $back == 200 ]] && grep -q 'written by a resident' "$body" || { echo "0 source not read back ($back)"; return; }
  local pub; pub=$(req POST /api/publish)
  local got; got=$(b4_www "/posts/$name.html")
  [[ $got == 200 ]] && grep -q 'written by a resident' "$body.www" && echo "1 PUT posts/$name.md $saved; POST /api/publish $pub; www.sock GET /posts/$name.html $got"
}
