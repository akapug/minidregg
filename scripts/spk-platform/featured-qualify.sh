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
write_Davros() { typed_app_row davros; }

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
