#!/usr/bin/env bash
# journey.d/jweb-frontend.sh — J-WEB-FRONTEND: the Mini web front end end to end
# (docs/WEB-FRONTEND-2026-10-27.md): the root helper (here in --dev, as this user), the keyless
# gateway, the member's body and shell behind it.
#
#   as a journey hook (JWF)     journey.sh exports MINI HOST CONFIG SOCKET NEWCOMER_WS NEWCOMER_SUBJECT
#                               JOURNEY_STEP_DIR; carol (K12C's docuverse author) is the member when her
#                               workspace exists, else the newcomer (whose spine workspace cannot birth a
#                               document: the three document rows then say why).
#   jweb-frontend.sh --dry      the same, from the environment (MINI HOST CONFIG SOCKET WS SUBJECT STEP_DIR);
#                               for a Mac with a running journey world.
#   jweb-frontend.sh --box NAME ON THE DEMO BOX, as root: the real helper and gateway units; writes a login
#                               record for the hosted account NAME as the door would, then the same rows
#                               against the gateway on loopback with the public Origin.
#
# Rows (expect -> got):
#   login-confirm      GET /login/CODE shows the one-shot confirm form (no cookie yet)      -> 200, form
#   login              POST /login exchanges the code for a cookie; the code is spent        -> 303 + cookie; second POST refused
#   stage-member       GET / with the cookie: the member's workspace (its subject on the page) -> 200
#   csrf-refused       POST /doc/new with a wrong csrf token                                 -> 403
#   origin-refused     POST with a foreign Origin                                            -> 403
#   term-open          POST /term makes a terminal; GET /term/ID has the WebSocket address    -> 303, data-ws
#   term-whoami        over the WebSocket, `whoami` prints the member's subject              -> present
#   doc-new            POST /doc/new (law note) through the form                             -> admitted
#   doc-append         POST /doc/NAME/append through the form                               -> admitted; the page shows the text
#   receipt            GET /receipts/ID shows the attempt's decoded outcome                  -> 200, outcome admitted
#   face-coverage      every verb x subcommand leaf in `help` has a route and a no-JS form        -> none missing
#   face-coverage-redproof  a verb the shell lacks has no face                                      -> 404
#   verb-index         /verb lists the catalog                                                       -> 200
#   verb-run           POST /verb/whoami through the derived form                                    -> answered, the subject
#   tour               GET /tour: twelve steps with the real forms                                      -> 200, 12
#   tour-step          POST /tour/4 (`can` through the tour's form) lands an outcome under the step   -> outcome
#   tour-chromium      jtour.mjs: login, /tour, step 4 through the pane, a terminal prompt (needs Playwright) -> PASS
#   logout             POST /logout clears the cookie; the old cookie no longer opens /term   -> 303; 401
#   public-reader      GET / without a session answers (the public body, or a named refusal) -> 200|502, "public reader"
# Output: one row per check (`PASS|FAIL<TAB>row<TAB>detail`), then `J-WEB-FRONTEND PASS n/n` or
# `... FAIL k/n` as the last line of stdout and stderr. Exit 0 only on PASS. Every process this script
# starts is stopped by the PID in its PID file, and only that.
set -uo pipefail
umask 077
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
mode=${1:-hook}
rows=0 fails=0
row() { rows=$((rows + 1)); if [ "$2" = 1 ]; then printf 'PASS\t%s\t%s\n' "$1" "$3"; else fails=$((fails + 1)); printf 'FAIL\t%s\t%s\n' "$1" "$3"; fi; }
verdict() { local v="J-WEB-FRONTEND PASS $rows/$rows"; [ "$fails" = 0 ] || v="J-WEB-FRONTEND FAIL $fails/$rows"; echo "$v"; echo "$v" >&2; [ "$fails" = 0 ]; }
unconfigured() { echo "UNCONFIGURED: $*" >&2; exit 5; }
PIDS=()
stop() { for f in "${PIDS[@]}"; do [ -f "$f" ] && kill "$(cat "$f")" 2>/dev/null; rm -f "$f"; done; }
trap stop EXIT

free_port() { python3 -I -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1])'; }
token() { head -c 32 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=\n'; }
sha256() { printf '%s' "$1" | (shasum -a 256 2>/dev/null || sha256sum) | cut -c1-64; }

case $mode in
hook|--dry)
  if [ "$mode" = hook ]; then
    D=${JOURNEY_STEP_DIR:?}; WS=${NEWCOMER_WS:?}; SUBJECT=${NEWCOMER_SUBJECT:?}
    # The document rows birth a document, which the spine's newcomer cannot (no birth context, and
    # `shared` is under J8's deny-all law); after K12C the docuverse's carol can, so she is the member.
    if [ -f "${JOURNEY_WORLD:?}/carol-workspace/workspace.json" ]; then
      WS=$JOURNEY_WORLD/carol-workspace; SUBJECT=$(jq -r .subject "$WS/workspace.json")
    fi
  else
    D=${STEP_DIR:?STEP_DIR}; WS=${WS:?WS}; SUBJECT=${SUBJECT:?SUBJECT}
  fi
  : "${MINI:?}" "${HOST:?}" "${CONFIG:?}" "${SOCKET:?}"
  BIN=$(dirname "$MINI")
  GATEWAY=${MINI_WEB_BIN:-$BIN/mini-web}; HELPER=${MINI_WEB_SPAWN_BIN:-$BIN/mini-web-spawn}
  [ -x "$GATEWAY" ] && [ -x "$HELPER" ] || unconfigured "no mini-web / mini-web-spawn beside $MINI (cargo build -p minidregg-mini-web -p minidregg-mini-web-spawn), or set MINI_WEB_BIN / MINI_WEB_SPAWN_BIN"
  WRAPPER=$REPO/deploy/shell/mini-shell-ssh
  [ -x "$WRAPPER" ] || unconfigured "no $WRAPPER"
  # A workspace that pins its Host's socket must be addressed by that exact path.
  pinned=$(jq -r '.socket // empty' "$WS/workspace.json" 2>/dev/null); [ -z "$pinned" ] || SOCKET=$pinned
  R=$D/jwf; mkdir -p "$R/state" "$R/home" "$R/pubhome"
  # Unix sockets need a short path (sun_path); the step directory can be long.
  RUNDIR=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/jwf.XXXXXX"); trap 'stop; rm -rf "$RUNDIR"' EXIT
  HOMEDIR=$R/home
  cat >"$R/dev.json" <<EOF
{"mini":"$MINI","host":"$HOST","config":"$CONFIG","socket":"$SOCKET","wrapper":"$WRAPPER",
 "sessions":{"alice":{"workspace":"$WS","home":"$HOMEDIR"}},
 "public":{"workspace":"$WS","home":"$R/pubhome"}}
EOF
  HSOCK=$RUNDIR/spawn.sock
  nohup "$HELPER" --dev "$R/dev.json" --socket "$HSOCK" --state "$R/state" --run "$RUNDIR" >"$R/helper.log" 2>&1 &
  echo $! >"$R/helper.pid"; PIDS+=("$R/helper.pid")
  PORT=$(free_port); ORIGIN=http://127.0.0.1:$PORT
  nohup "$GATEWAY" --listen "127.0.0.1:$PORT" --helper "$HSOCK" --origin "$ORIGIN" --shutdown "the end of this journey" >"$R/gateway.log" 2>&1 &
  echo $! >"$R/gateway.pid"; PIDS+=("$R/gateway.pid")
  for _ in $(seq 1 50); do curl -s -m 1 "$ORIGIN/healthz" >/dev/null 2>&1 && [ -S "$HSOCK" ] && break; sleep 0.1; done
  CODE=$(token)
  printf '{"name":"alice","expires":%d}\n' "$(( $(date +%s) + 3600 ))" >"$R/state/logins/$(sha256 "$CODE").json"
  COOKIE_NAME=mini_session
  ;;
--box)
  NAME=${2:?usage: jweb-frontend.sh --box NAME}
  [ "$(id -u)" = 0 ] || { echo "jweb-frontend --box runs as root on the box" >&2; exit 2; }
  id -u "mini-s-$NAME" >/dev/null 2>&1 || unconfigured "no hosted account mini-s-$NAME"
  D=$(mktemp -d /tmp/jwf.XXXXXX); R=$D
  SUBJECT=$(jq -r .subject "/var/lib/mini/sessions/$NAME/workspace/workspace.json")
  PORT=${MINI_WEB_PORT:-8797}; ORIGIN=${MINI_WEB_ORIGIN:-https://demo.dregg.online}
  CODE=$(token)
  mkdir -p /var/lib/mini-web-spawn/logins
  printf '{"name":"%s","expires":%d}\n' "$NAME" "$(( $(date +%s) + 3600 ))" >"/var/lib/mini-web-spawn/logins/$(sha256 "$CODE").json"
  chmod 600 "/var/lib/mini-web-spawn/logins/$(sha256 "$CODE").json"
  COOKIE_NAME=__Host-mini_session
  ;;
*) echo "usage: jweb-frontend.sh [--dry | --box NAME]" >&2; exit 2 ;;
esac

BASE=http://127.0.0.1:$PORT
JAR=$R/jar
# curl talks to the loopback gateway; the browser's Origin and fetch-site headers are supplied as a browser would.
req() { # METHOD PATH [curl args...] -> body on stdout; status via st (a file: req runs in a subshell), headers in $R/h
  local method=$1 path=$2; shift 2
  curl -s -o "$R/body" -D "$R/h" -w '%{http_code}' -X "$method" -b "$JAR" -c "$JAR" -H "Origin: $ORIGIN" -H 'Sec-Fetch-Site: same-origin' "$@" "$BASE$path" >"$R/status"
  cat "$R/body"
}
st() { cat "$R/status" 2>/dev/null; }
csrf_of() { grep -o 'name="csrf" value="[^"]*"' "$R/body" | head -1 | sed 's/.*value="//; s/"$//'; }

page=$(req GET "/login/$CODE")
row login-confirm "$([ "$(st)" = 200 ] && grep -q 'action="/login"' <<<"$page" && echo 1 || echo 0)" "$(st)"
req POST /login --data-urlencode "code=$CODE" >/dev/null
has_cookie=$(grep -c "$COOKIE_NAME" "$JAR" || true)
req POST /login --data-urlencode "code=$CODE" -b /dev/null -c /dev/null >"$R/second"
row login "$([ "$has_cookie" -ge 1 ] && [ "$(st)" = 403 ] && echo 1 || echo 0)" "cookie=$has_cookie second=$(st)"
page=$(req GET /)
row stage-member "$([ "$(st)" = 200 ] && grep -q "$SUBJECT\|alice\|mini-s-" <<<"$page" && ! grep -q 'public reader' <<<"$page" && echo 1 || echo 0)" "$(st)"
CSRF=$(csrf_of)
req POST /doc/new --data-urlencode "csrf=nope" --data-urlencode "name=x" --data-urlencode "law=note" >/dev/null
row csrf-refused "$([ "$(st)" = 403 ] && echo 1 || echo 0)" "$(st)"
evil=$(curl -s -o /dev/null -w '%{http_code}' -X POST -b "$JAR" -H 'Origin: https://evil.example' --data-urlencode "csrf=$CSRF" --data-urlencode "name=x" --data-urlencode "law=note" "$BASE/doc/new")
row origin-refused "$([ "$evil" = 403 ] && echo 1 || echo 0)" "$evil"
req POST /term --data-urlencode "csrf=$CSRF" --data-urlencode cols=100 --data-urlencode rows=30 >/dev/null
TERM_PATH=$(grep -i '^location:' "$R/h" | awk '{print $2}' | tr -d '\r')
page=$(req GET "$TERM_PATH")
WSPATH=$(grep -o 'data-ws="[^"]*"' <<<"$page" | head -1 | sed 's/data-ws="//; s/"$//')
row term-open "$([ -n "$WSPATH" ] && echo 1 || echo 0)" "${TERM_PATH:-none} ws=${WSPATH:-none}"
COOKIE_VALUE=$(awk -v n="$COOKIE_NAME" '$6==n {print $7}' "$JAR" | tail -1)
out=$(python3 -I "$HERE/jweb-frontend-ws.py" "127.0.0.1" "$PORT" "$WSPATH" "$ORIGIN" "$COOKIE_NAME=$COOKIE_VALUE" "$SUBJECT" 2>"$R/ws.err"); ws_rc=$?
row term-whoami "$([ "$ws_rc" = 0 ] && echo 1 || echo 0)" "$(tail -c 200 <<<"$out" | tr '\n' ' ' | cut -c1-160) $(tail -1 "$R/ws.err")"
DOC="jwf$(od -An -N3 -tu4 /dev/urandom | tr -d ' ' | cut -c1-6)"
page=$(req POST /doc/new --data-urlencode "csrf=$CSRF" --data-urlencode "name=$DOC" --data-urlencode "law=note")
row doc-new "$(grep -q 'outcome admitted' <<<"$page" && echo 1 || echo 0)" "$(st) $(grep -o 'class="headline">[^<]*' <<<"$page" | head -1 | cut -c18-120)"
TEXT="hello from the browser $(date +%s)"
page=$(req POST "/doc/$DOC/append" --data-urlencode "csrf=$CSRF" --data-urlencode "text=$TEXT")
RID=$(grep -o '/receipts/w-[0-9a-f]*' <<<"$page" | head -1 | cut -d/ -f3)
docpage=$(req GET "/doc/$DOC")
row doc-append "$(grep -q 'outcome admitted' <<<"$page" && grep -q "$TEXT" <<<"$docpage" && echo 1 || echo 0)" "$(st) receipt=${RID:-none} $(grep -o 'class="headline">[^<]*' <<<"$page" | head -1 | cut -c18-120)"
page=$(req GET "/receipts/${RID:-none}")
row receipt "$([ "$(st)" = 200 ] && grep -q 'outcome admitted' <<<"$page" && echo 1 || echo 0)" "$(st)"
# Parity (docs/DEMO-EXPERIENCE-2026-10-27.md §1a): every verb the shell's `help` lists has a form at
# /verb/NAME in the body; a verb with no face is red by name.
help=$("$MINI" shell --socket "$SOCKET" --workspace "$WS" --home "${HOMEDIR:-$R/home}" --host "$HOST" --config "$CONFIG" --line help 2>/dev/null)
# FACE COVERAGE (not yet parity: parity needs an outcome test per leaf): every verb x subcommand leaf
# the shell's `help` lists (each usage alternative's leading literal words) has a route and a no-JS
# form in the body; a leaf without one is red by name.
verbs=$(awk '/^  [a-z][a-z-]* / {print $1}' <<<"$help" | sort -u)
missing=""; count=0; leaves=0
for v in $verbs; do
  count=$((count + 1))
  page=$(req GET "/verb/$v")
  if [ "$(st)" != 200 ] || ! grep -q "action=\"/verb/$v\"" <<<"$page"; then missing="$missing $v"; continue; fi
  usage=$(awk -v v="$v" '$1==v && /^  [a-z]/ {sub(/^  [a-z-]+ +/, ""); print; exit}' <<<"$help")
  while IFS= read -r alt; do
    lits=""; for w in $alt; do case $w in [a-z]*) [[ $w =~ ^[a-z/-]+$ ]] && lits="$lits $w" || break;; *) break;; esac; done
    lits=${lits# }; [ -n "$lits" ] || continue
    leaves=$((leaves + 1))
    grep -qF "<h2><code>$lits</code></h2>" <<<"$page" || missing="$missing $v($lits)"
  done < <(sed 's/ | /\n/g' <<<"$usage")
done
row face-coverage "$([ "$count" -gt 40 ] && [ "$leaves" -gt 100 ] && [ -z "$missing" ] && echo 1 || echo 0)" "$count verbs, $leaves leaves in help; without a face:${missing:- none}"
# Red-proof: a verb the shell does not have must have no face (the check can go red).
req GET /verb/no-such-verb-x >/dev/null
row face-coverage-redproof "$([ "$(st)" = 404 ] && echo 1 || echo 0)" "$(st) for a verb the shell lacks"
page=$(req GET /verb)
row verb-index "$([ "$(st)" = 200 ] && grep -q '/verb/delegate' <<<"$page" && echo 1 || echo 0)" "$(st)"
page=$(req POST /verb/whoami --data-urlencode "csrf=$CSRF" --data-urlencode "alt=0")
row verb-run "$(grep -q 'outcome answered' <<<"$page" && grep -q "$SUBJECT" <<<"$page" && echo 1 || echo 0)" "$(st) whoami through the derived form answers (a local verb, never admitted)"
# The tour (DEMO-EXPERIENCE §1): twelve steps whose forms are the real forms; step 4's `can` runs
# through /tour/4 and its outcome lands under the step.
page=$(req GET /tour)
row tour "$([ "$(st)" = 200 ] && [ "$(grep -c 'class="step"' <<<"$page")" = 12 ] && grep -q 'action="/tour/4"' <<<"$page" && echo 1 || echo 0)" "$(st) steps=$(grep -c 'class="step"' <<<"$page")"
page=$(req POST /tour/4 --data-urlencode "csrf=$CSRF" --data-urlencode "verb=can" --data-urlencode "alt=0")
row tour-step "$(grep -q 'id="step-4"' <<<"$page" && grep -q 'step-outcome' <<<"$page" && grep -qE 'outcome (admitted|refused|undecided)' <<<"$page" && echo 1 || echo 0)" "$(st) $(grep -o 'class="headline">[^<]*' <<<"$page" | head -1 | cut -c18-100)"
# The same, headless through Chromium (jtour.mjs), with a second one-time code; needs Playwright.
PW=${PLAYWRIGHT_DIR:-$HOME/tools/playwright/node_modules}
if [ -f "$PW/playwright/index.mjs" ] && command -v node >/dev/null && [ "$mode" != --box ]; then
  CODE2=$(token); printf '{"name":"alice","expires":%d}\n' "$(( $(date +%s) + 3600 ))" >"$R/state/logins/$(sha256 "$CODE2").json"
  out=$(PLAYWRIGHT_DIR=$PW node "$HERE/jtour.mjs" "$BASE" "$CODE2" "$SUBJECT" 2>"$R/jtour.err"); rc=$?
  row tour-chromium "$([ "$rc" = 0 ] && echo 1 || echo 0)" "$out $(tail -1 "$R/jtour.err" | cut -c1-120)"
else
  printf 'UNCONFIGURED\ttour-chromium\tno Playwright at %s (PLAYWRIGHT_DIR), or --box\n' "$PW"
fi
req POST /logout --data-urlencode "csrf=$CSRF" >/dev/null
logout_status=$(st)
after=$(curl -s -o /dev/null -w '%{http_code}' -H "Cookie: $COOKIE_NAME=$COOKIE_VALUE" "$BASE/term")
row logout "$([ "$logout_status" = 303 ] && [ "$after" = 401 ] && echo 1 || echo 0)" "logout=$logout_status then /term=$after"
pub=$(curl -s -o "$R/body" -w '%{http_code}' "$BASE/")
row public-reader "$(grep -q 'public reader' "$R/body" && echo 1 || echo 0)" "$pub $(grep -o 'class="headline">[^<]*' "$R/body" | head -1 | cut -c18-120)"
verdict
