#!/bin/bash
# featured-qualify.sh WORLD.env OUT_DIR [LETTER...]: qualify the market's featured set
# (docs/APP-MARKET-2026-10-27.md section 2a) on a standing world (world-up.sh): each app
# through create, install, share, start, enrol and page load (grain-journey.sh phases, the
# owner as the operator's participant), then ONE write beneath the HTML by a script standing
# in for a resident, over the grain's own route (the custodian checks it exactly as for a
# browser). Rows go to OUT_DIR/rows.tsv as PASS|FAIL<TAB>row<TAB>detail. Letters j..p; Etherpad,
# Hacker Slides and Simple Todos are japps.sh's rows (a..c).
#
# Packages come from MINI_MARKET_CACHE (a quarantine directory of <packageId>.spk), else the
# fetcher downloads them into OUT_DIR/state.
set -u
[[ $# -ge 2 ]] || { echo "usage: $0 WORLD.env OUT_DIR [LETTER...]" >&2; exit 2; }
env_file=$1 out=$2; shift 2
# shellcheck disable=SC1090
. "$env_file"; export GRAINS_ROOT BROKER_SOCKET
here=$(cd "$(dirname "$0")" && pwd); repo=$(cd "$here/../.." && pwd)
mkdir -p "$out/state/quarantine" "$out/bodies"
rows=$out/rows.tsv; : >"$rows"
row() { printf '%s\t%s\t%s\n' "$([ "$2" = 1 ] && echo PASS || echo FAIL)" "$1" "$3" | tee -a "$rows"; }
state=$(jq -er .stateRoot "$PROFILE")

# letter  name         packageId                         class  page   kind
apps="j EtherCalc 9b3b76152e7d8db9f54dba7455ea9239 S / web
k HedgeDoc ff642cdb65178a6a2dff96ca15dd7028 M / web
l Davros 15bf92664a1b14a784bf737e502e13b7 M / web
m sntfy bc424d5fd3cf60977cacdac328adfbee S / web
n DokuWiki dda6d7e22e8e2566bdc804d8e3f9165f S /doku.php web
o HledgerWeb 23321185cf7dd1ae7a74e5b7deb6caba S / web
p Datasette 547714ee1f01bae653fe9276d6d30ce9 M / web"
want=" ${*:-j k l m n o p} "

package() { # ID -> path
  local id=$1 f=$out/state/quarantine/$1.spk
  [[ -f $f ]] || { [[ -n ${MINI_MARKET_CACHE:-} && -f $MINI_MARKET_CACHE/$id.spk ]] && cp "$MINI_MARKET_CACHE/$id.spk" "$f"; }
  [[ -f $f ]] || bash "$repo/deploy/market/mini-market-fetch" --state "$out/state" --mini "$BIN/mini" fetch "$id" >/dev/null 2>&1
  [[ -f $f ]] && echo "$f"
}
basis() { # SPK -> role basis, as japps.sh picks it
  local q=$HOME/.mini-featured-basis.$$; mkdir -m 0700 "$q"; cp "$1" "$q/p.spk"
  if "$BIN/spk-host" qualify --import-profile standard-v1 "$q/p.spk" 2>/dev/null | jq -e '.signedSchema.roles | length > 0' >/dev/null
  then echo '{"type":"role","id":"0"}'; else echo '{"type":"allAccess"}'; fi
  rm -rf "$q"
}
# One request over a route: METHOD PATH [CURL ARGS...]; prints the status, body in $body.
req() {
  local method=$1 path=$2; shift 2
  curl -sS --max-time 900 --unix-socket "$dir/http.sock" -X "$method" -H 'Host: grain.test' \
    -H "Cookie: __Host-mini_spk_session=$(cat "$dir/browser.token")" -H 'Origin: https://grain.test' \
    -o "$body" -D "$body.headers" -w '%{http_code}' "$@" "http://grain.test$path" 2>>"$out/curl.err"
}

# The beneath-HTML write per app: what a resident does instead of clicking.
write_EtherCalc() {
  local put; put=$(req PUT /_/featured -H 'Content-Type: text/csv' --data-binary $'item,qty\nwidgets,3\n')
  local got; got=$(req GET /_/featured/csv)
  [[ $put =~ ^20 && $got == 200 ]] && grep -q widgets "$body" && echo "1 PUT /_/featured text/csv $put; GET csv $got"
}
write_HedgeDoc() {
  local made; made=$(req POST /new -H 'Content-Type: text/markdown' --data-binary $'# featured\nwritten by a resident\n')
  local note; note=$(grep -i '^location:' "$body.headers" | tr -d '\r' | awk '{print $2}'); note=${note#https://grain.test}
  [[ $made =~ ^30 && -n $note ]] || return
  local got; got=$(req GET "$note/download")
  [[ $got == 200 ]] && grep -q 'written by a resident' "$body" && echo "1 POST /new $made -> $note; GET download $got"
}
write_Davros() {
  local put; put=$(req PUT /remote.php/webdav/featured.txt -H 'Content-Type: text/plain' --data-binary 'filed by a resident')
  local got; got=$(req GET /remote.php/webdav/featured.txt)
  [[ $put =~ ^20 && $got == 200 ]] && grep -q 'filed by a resident' "$body" && echo "1 PUT webdav/featured.txt $put; GET $got"
}
write_sntfy() {
  local post; post=$(req POST /featured --data-binary 'job done, from a resident')
  local got; got=$(req GET '/featured/json?poll=1&since=all')
  [[ $post == 200 && $got == 200 ]] && grep -q 'job done' "$body" && echo "1 POST /featured $post; poll $got"
}
write_DokuWiki() {
  local edit; edit=$(req GET '/doku.php?id=featured&do=edit')
  local sectok; sectok=$(grep -o 'name="sectok" value="[0-9a-f]*"' "$body" | head -1 | sed 's/.*value="//; s/"//')
  [[ $edit == 200 && -n $sectok ]] || { echo "0 edit form $edit, sectok '${sectok:-}'"; return; }
  local save; save=$(req POST /doku.php --data-urlencode id=featured --data-urlencode "sectok=$sectok" \
    --data-urlencode 'do[save]=1' --data-urlencode 'summary=resident' --data-urlencode $'wikitext======= Featured ======\nwritten by a resident\n')
  local got; got=$(req GET '/doku.php?id=featured&do=export_raw')
  [[ $save =~ ^(200|302|303)$ && $got == 200 ]] && grep -q 'written by a resident' "$body" && echo "1 POST do=save $save; export_raw $got"
}
write_HledgerWeb() {
  local add; add=$(req POST /add --data-urlencode "date=$(date -u +%Y-%m-%d)" --data-urlencode 'description=featured by a resident' \
    --data-urlencode 'account=assets:cash' --data-urlencode 'amount=$3' --data-urlencode 'account=expenses:demo' --data-urlencode 'amount=')
  local got; got=$(req GET /journal)
  [[ $add =~ ^(200|302|303)$ && $got == 200 ]] && grep -q 'featured by a resident' "$body" && echo "1 POST /add $add; GET /journal $got"
}
write_Datasette() {
  local got; got=$(req GET '/-/versions.json')
  # Datasette 0.63 has no write API; its write is the upload of a database through the page.
  [[ $got == 200 ]] && echo "0 read-only: GET /-/versions.json $got; Datasette 0.63 has no HTTP write (upload is the page's form)"
}

while read -r letter name pkg class page kind; do
  [[ $want == *" $letter "* ]] || continue
  spk=$(package "$pkg") || { row "$name: package $pkg fetched and verified" 0 "fetch failed"; continue; }
  b=$(basis "$spk"); U=$(tr a-p A-P <<<"$letter")
  started=$(date +%s)
  if env BIN="$BIN" "SPK_$U=$spk" "KIND_$U=$kind" "GET_PATH_$U=$page" "CLASS_$U=$class" "ROLE_BASIS_$U=$b" \
      sh "$repo/scripts/spk-platform/grain-journey.sh" phase "$RUN" "birth-$letter" "install-$letter" "share-$letter" \
      "start-$letter" "enroll-$letter" "get-$letter" >"$out/$letter-world.out" 2>"$out/$letter-world.err"; then ok=1; else ok=0; fi
  row "$name: create, install, share, start, enrol, page $page" "$ok" "$(( $(date +%s) - started )) s $(tail -1 "$out/$letter-world.err" | cut -c1-120)"
  [[ $ok == 1 ]] || continue
  app=$(jq -er '.applicationGrainBirth.applicationBirth.application.app' "$RUN/evidence/$letter-app-source.json")
  dir=$state/apps/$app/routes/owner-$kind body=$out/bodies/$letter
  result=$("write_$name" 2>&1 | tail -1)
  row "$name: one write beneath the HTML by a resident's script" "$([ "${result%% *}" = 1 ] && echo 1 || echo 0)" "${result#* }"
done <<<"$apps"
grep -c '^PASS' "$rows" | xargs -I{} echo "featured: {} PASS of $(wc -l <"$rows") rows"
