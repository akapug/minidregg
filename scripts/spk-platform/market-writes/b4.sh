# B4 publishing writes. Reasoned recipes (NOT proven by a run): the lifecycle rows of the first
# pass are the only evidence; no app's write endpoint was probed live (COORDINATION section 4).
# $dir is .../apps/<app>/routes/owner-web, so the app's publishing socket is ../../www.sock.

# b4_www PATH: GET PATH through the resident's publishing socket; status on stdout, body in $body.www
b4_www() {
  curl -sS --max-time 120 --unix-socket "${dir%/routes/*}/www.sock" -H 'Host: grain.test' \
    -o "$body.www" -w '%{http_code}' "http://grain.test$1" 2>>"$out/curl.err"
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
