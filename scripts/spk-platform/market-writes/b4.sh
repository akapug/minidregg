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
  local made; made=$(req POST /?rest_route=/wp/v2/posts -H "X-WP-Nonce: $nonce" -H 'Content-Type: application/json' \
    --data '{"title":"featured","content":"published by a resident","status":"publish"}')
  local id; id=$(jq -r '.id // empty' "$body" 2>/dev/null)
  [[ $made =~ ^20 && -n $id ]] || { echo "0 POST ?rest_route=/wp/v2/posts $made: $(head -c 120 "$body" | tr -d '\n')"; return; }
  local got; got=$(req GET "/?p=$id")
  local www; www=$(b4_www "/?p=$id")
  [[ $got == 200 ]] && grep -q 'published by a resident' "$body" && echo "1 POST wp/v2/posts $made id $id; GET /?p=$id $got (owner preview); www.sock $www"
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

# Hakyll CMS (package 49a44b77, sshakyll): lifecycle red at START ("resident exited before START", app output
# empty; install passed). From the package: action "New Hakyll CMS Site" is `sandstorm-http-bridge 8000 --
# /startup.sh`; startup.sh writes /var/www/index.html, runs `cp -a /source /var`, then /bin/sshakyll, whose
# options are HOST 127.0.0.1, PORT, DIR default "var" (a RELATIVE path, so the process's working directory
# decides where /var/source and /var/public land). CAUSE NOT PROVEN (no logs are readable here); the
# candidates, in order: (1) the resident's working directory is not "/" or not writable, so sshakyll cannot
# open `var`; (2) `cp -a /source /var` fails on ownership preservation in the unprivileged launch worker and
# the later steps depend on it; (3) sshakyll binds a port other than the bridge's 8000 (it takes --port, and
# startup.sh passes none). The first fix to try is the launch's cwd = "/" plus /var writable; the resident's
# stderr from `sshakyll` is the evidence to read first. Not a recipe defect.
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
