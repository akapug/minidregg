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

# letter  name         packageId                         class  page   kind  [role: the owner role id when role 0 cannot write]
apps="j EtherCalc 9b3b76152e7d8db9f54dba7455ea9239 S / web
k HedgeDoc ff642cdb65178a6a2dff96ca15dd7028 M / web
l Davros 15bf92664a1b14a784bf737e502e13b7 M / web
m sntfy bc424d5fd3cf60977cacdac328adfbee S / web
n DokuWiki dda6d7e22e8e2566bdc804d8e3f9165f S /doku.php web
o HledgerWeb 23321185cf7dd1ae7a74e5b7deb6caba S / web
p Datasette 547714ee1f01bae653fe9276d6d30ce9 M / web"
# A batch brings its own table (same columns) and its write functions:
# QUALIFY_TABLE=scripts/spk-platform/market-batches/bN.tsv, and every
# scripts/spk-platform/market-writes/*.sh (and QUALIFY_WRITES/*.sh, a batch's own directory) is
# sourced after the functions below.
# QUALIFY_STOP=1 stops each grain after its write (a shared box keeps memory for the next app).
[[ -z ${QUALIFY_TABLE:-} ]] || apps=$(grep -v '^#' "$QUALIFY_TABLE")
want=" ${*:-$(awk '{printf "%s ", $1}' <<<"$apps")} "

package() { # ID -> path
  local id=$1 f=$out/state/quarantine/$1.spk
  [[ -f $f ]] || { [[ -n ${MINI_MARKET_CACHE:-} && -f $MINI_MARKET_CACHE/$id.spk ]] && cp "$MINI_MARKET_CACHE/$id.spk" "$f"; }
  [[ -f $f ]] || bash "$repo/deploy/market/mini-market-fetch" --state "$out/state" --mini "$BIN/mini" fetch "$id" >/dev/null 2>&1
  [[ -f $f ]] && echo "$f"
}
basis() { # SPK -> the owner's role basis
  # The grain's owner holds every permission the package declares (Sandstorm's owner is not a role), so
  # the basis is allAccess, "all current schema bits". Role 0 is the package's first and usually weakest role
  # (sntfy "api", Davros "viewer", hledger-web "viewer"), under which sntfy's page answers 401 and the
  # Davros and hledger-web writes are refused by the app itself.
  echo '{"type":"allAccess"}'
}
# One request over a route: METHOD PATH [CURL ARGS...]; prints the status, body in $body.
req() {
  local method=$1 path=$2; shift 2
  curl -sS --max-time 900 --unix-socket "$dir/http.sock" -X "$method" -H 'Host: grain.test' \
    -H "Cookie: __Host-mini_spk_session=$(cat "$dir/browser.token")" -H 'Origin: https://grain.test' \
    -o "$body" -D "$body.headers" -w '%{http_code}' "$@" "http://grain.test$path" 2>>"$out/curl.err"
}

# Like req, but keeps the cookies the app sets (PHP and CSRF sessions bind a form token to them) in $jar,
# on top of the route token. Reset with jar="" at the start of a write. NOT called inside $(...) (a
# subshell would drop the jar): the status is left in $JS.
jreq() {
  local method=$1 path=$2; shift 2
  JS=$(curl -sS --max-time 900 --unix-socket "$dir/http.sock" -X "$method" -H 'Host: grain.test' \
    -H "Cookie: __Host-mini_spk_session=$(cat "$dir/browser.token")${jar:+; $jar}" -H 'Origin: https://grain.test' \
    -o "$body" -D "$body.headers" -w '%{http_code}' "$@" "http://grain.test$path" 2>>"$out/curl.err")
  local c; while read -r c; do
    jar=$(printf '%s\n%s\n' "${jar//; /$'\n'}" "$c" | awk -F= 'NF&&!seen[$1]++{printf "%s%s", (n++?"; ":""), $0}')
  done < <(grep -i '^set-cookie:' "$body.headers" | tr -d '\r' | sed 's/^[Ss]et-[Cc]ookie: *//; s/;.*//')
}

# snip: the first 160 bytes of the last response body ($body) on one line, for a failure's detail.
snip() { head -c 160 "$body" 2>/dev/null | tr '\r\n\t' '   '; }

# The beneath-HTML write per app: what a resident does instead of clicking.
write_EtherCalc() {
  local put; put=$(req PUT /_/featured -H 'Content-Type: text/csv' --data-binary $'item,qty\nwidgets,3\n')
  local got; got=$(req GET /_/featured/csv)
  [[ $put =~ ^20 && $got == 200 ]] && grep -q widgets "$body" && echo "1 PUT /_/featured text/csv $put; GET csv $got"
}
# HedgeDoc's package (ff642cdb) lacks node_modules/iconv-lite/encodings, which the packager's trace
# never touched: every request body it parses (text, form or JSON) throws "Cannot find module
# '../encodings'" in the app (400 or 500; POST /new answered 400 on w11). So its write never sends a
# body over HTTP: GET /new makes the note (303 to /<id>) and the text goes in as a socket.io
# `operation`, the one recipe shared with the rt table (write_HedgeDocRT in market-writes/rt.sh).
write_HedgeDoc() { write_HedgeDocRT; }
write_Davros() {
  local put; put=$(req PUT /remote.php/webdav/featured.txt -H 'Content-Type: text/plain' --data-binary 'filed by a resident')
  local putbody; putbody=$(snip)
  local got; got=$(req GET /remote.php/webdav/featured.txt)
  [[ $put =~ ^20 && $got == 200 ]] && grep -q 'filed by a resident' "$body" && { echo "1 PUT webdav/featured.txt $put; GET $got"; return; }
  echo "0 PUT webdav/featured.txt $put [$putbody]; GET $got [$(snip)]"
}
write_sntfy() {
  local post; post=$(req POST /featured --data-binary 'job done, from a resident')
  local postbody; postbody=$(snip)
  local got; got=$(req GET '/featured/json?poll=1&since=all')
  [[ $post == 200 && $got == 200 ]] && grep -q 'job done' "$body" && { echo "1 POST /featured $post; poll $got"; return; }
  echo "0 POST /featured $post [$postbody]; poll $got [$(snip)]"
}
# DokuWiki: the edit form (id dw__editform) posts sectok, id, rev, date, prefix, suffix, changecheck and
# target as hidden fields next to wikitext, summary and the button do[save]. sectok is a hash of the PHP
# session id, so the form GET and the POST must share the session cookie the GET sets (jreq keeps it);
# the first recipe sent a bare sectok with no cookie, and DokuWiki refused the save.
write_DokuWiki() {
  jar=""
  jreq GET '/doku.php?id=featured&do=edit'; local edit=$JS
  local fields=() f
  while IFS= read -r -d '' f; do fields+=(--data-urlencode "$f"); done < <(python3 -I "$here/market-writes/form-fields.py" dw__editform <"$body")
  [[ $edit == 200 && ${#fields[@]} -gt 0 ]] || { echo "0 edit form $edit, no dw__editform hidden fields"; return; }
  [[ " ${fields[*]} " == *sectok=* ]] || { echo "0 edit form $edit carries no sectok"; return; }
  jreq POST '/doku.php?id=featured' "${fields[@]}" --data-urlencode $'wikitext======= Featured ======\nwritten by a resident\n' \
    --data-urlencode 'summary=resident' --data-urlencode 'do[save]=Save'; local save=$JS
  jreq GET '/doku.php?id=featured&do=export_raw'; local got=$JS
  [[ $save =~ ^(200|302|303)$ && $got == 200 ]] && grep -q 'written by a resident' "$body" && { echo "1 POST do[save] $save; export_raw $got"; return; }
  echo "0 POST do[save] $save; export_raw $got without the text"
}
# hledger-web 1.31 runs with --allow=sandstorm (the owner holds view, add, manage): its JSON API takes
# PUT /add with the full JSON of one transaction (the form needs a Yesod _token). The read-back is
# GET /transactions (JSON). tsourcepos is a pair of SourcePos objects in 1.31 (the first run, with the older
# {tag: JournalSourcePos} shape, was refused: "expected Array, but encountered Object").
write_HledgerWeb() {
  local amt='{"aprice":null,"acommodity":"$","aquantity":{"floatingPoint":@Q@,"decimalPlaces":10,"decimalMantissa":@M@},"aismultiplier":false,"astyle":{"ascommodityside":"L","asdigitgroups":null,"ascommodityspaced":false,"asprecision":2,"asdecimalmark":".","asrounding":"NoRounding"}}'
  local a1=${amt//@Q@/3}; a1=${a1//@M@/30000000000}; local a2=${amt//@Q@/-3}; a2=${a2//@M@/-30000000000}
  local post1='{"pbalanceassertion":null,"pstatus":"Unmarked","pamount":['"$a1"'],"ptransaction_":"1","paccount":"expenses:demo","pdate":null,"ptype":"RegularPosting","pcomment":"","pdate2":null,"ptags":[],"poriginal":null}'
  local post2='{"pbalanceassertion":null,"pstatus":"Unmarked","pamount":['"$a2"'],"ptransaction_":"1","paccount":"assets:cash","pdate":null,"ptype":"RegularPosting","pcomment":"","pdate2":null,"ptags":[],"poriginal":null}'
  local txn='{"tcomment":"","tpostings":['"$post1,$post2"'],"ttags":[],"tsourcepos":[{"sourceName":"","sourceLine":1,"sourceColumn":1},{"sourceName":"","sourceLine":1,"sourceColumn":1}],"tdate":"2026-10-27","tcode":"","tindex":1,"tprecedingcomment":"","tdate2":null,"tdescription":"featured by a resident","tstatus":"Unmarked"}'
  local add; add=$(req PUT /add -H 'Content-Type: application/json' --data "$txn")
  local addbody; addbody=$(snip)
  local got; got=$(req GET /transactions)
  [[ $add =~ ^20 && $got == 200 ]] && grep -q 'featured by a resident' "$body" && { echo "1 PUT /add $add; GET /transactions $got"; return; }
  echo "0 PUT /add $add [$addbody]; GET /transactions $got [$(snip)]"
}
# Datasette 0.63 has no HTTP write (a database is uploaded through the page's own form), so the row is
# a RECORDED READ and passes as one: the grain answers the JSON API beneath the HTML and the database
# list is read back. Any other outcome fails.
write_Datasette() {
  local got; got=$(req GET '/-/versions.json')
  [[ $got == 200 ]] && grep -q '"datasette"' "$body" || { echo "0 GET /-/versions.json $got"; return; }
  local dbs; dbs=$(req GET '/-/databases.json')
  [[ $dbs == 200 ]] && echo "1 read-only by design (no HTTP write in 0.63): recorded GET /-/versions.json $got, GET /-/databases.json $dbs"
}
for f in "$here"/market-writes/*.sh ${QUALIFY_WRITES:+"$QUALIFY_WRITES"/*.sh}; do [[ -f $f ]] && . "$f"; done

while read -r letter name pkg class page kind role; do
  [[ $want == *" $letter "* ]] || continue
  spk=$(package "$pkg") || { row "$name: package $pkg fetched and verified" 0 "fetch failed"; continue; }
  b=$(basis "$spk"); U=$(tr a-p A-P <<<"$letter")
  [[ -z ${role:-} ]] || b="{\"type\":\"role\",\"id\":\"$role\"}"  # a table row may name the role its owner needs for the write
  started=$(date +%s)
  if env BIN="$BIN" "SPK_$U=$spk" "KIND_$U=$kind" "GET_PATH_$U=$page" "CLASS_$U=$class" "ROLE_BASIS_$U=$b" \
      sh "$repo/scripts/spk-platform/grain-journey.sh" phase "$RUN" "birth-$letter" "install-$letter" "share-$letter" \
      "start-$letter" "enroll-$letter" "get-$letter" >"$out/$letter-world.out" 2>"$out/$letter-world.err"; then ok=1; else ok=0; fi
  row "$name: create, install, share, start, enrol, page $page" "$ok" "$(( $(date +%s) - started )) s $(tail -1 "$out/$letter-world.err" | cut -c1-120)$([[ $ok == 1 ]] || { f=$RUN/evidence/$(grep -o '^[a-z]*-'"$letter"' .*exit=[1-9]' "$out/$letter-world.out" | head -1 | cut -d' ' -f1)-body; echo " [failed $(basename "$f"): $(head -n 1 "$f.headers" 2>/dev/null | tr -d '\r') $(head -c 160 "$f.body" 2>/dev/null | tr '\r\n\t' '   ')]"; })"
  [[ $ok == 1 ]] || { bash "$here/collect-app-output.sh" "$env_file" "$out/evidence-$letter" "$letter" || :; continue; }
  app=$(jq -er '.applicationGrainBirth.applicationBirth.application.app' "$RUN/evidence/$letter-app-source.json")
  dir=$state/apps/$app/routes/owner-$kind body=$out/bodies/$letter
  result=$("write_$name" 2>&1 | tail -1)
  row "$name: one write beneath the HTML by a resident's script" "$([ "${result%% *}" = 1 ] && echo 1 || echo 0)" "${result#* }"
  [[ ${result%% *} == 1 ]] || bash "$here/collect-app-output.sh" "$env_file" "$out/evidence-$letter" "$letter" || :
  [[ ${QUALIFY_STOP:-} != 1 ]] || env BIN="$BIN" sh "$repo/scripts/spk-platform/grain-journey.sh" phase "$RUN" "stop-$letter" \
    >>"$out/$letter-world.out" 2>>"$out/$letter-world.err" || row "$name: stopped after its write" 0 "$(tail -1 "$out/$letter-world.err" | cut -c1-120)"
done <<<"$apps"
grep -c '^PASS' "$rows" | xargs -I{} echo "featured: {} PASS of $(wc -l <"$rows") rows"
