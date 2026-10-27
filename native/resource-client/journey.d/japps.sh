#!/usr/bin/env bash
# J-APPS: a member installs any app from the Sandstorm market (docs/APP-MARKET-2026-10-27.md §6).
#
#   japps.sh --dry BIN-DIR [INSPECT]   anywhere (the Mac has egress): the catalogue over the recorded index
#                                      fixture (search, show, an unknown appId refused by name); the real
#                                      fetcher brings the two journey packages into a scratch quarantine
#                                      (SHA-256 prefix == packageId, size within the standard profile), the
#                                      stream reader's `inspect` verifies their signatures and signed appIds,
#                                      a tampered copy is refused by name; the grain front dispatches by
#                                      Host and credential against a fake custodian (404 / 403 / form / 200).
#                                      BIN-DIR holds mini; INSPECT is spk-package-stream's inspect example
#                                      (cargo build -p minidregg-spk-package-stream --example inspect).
#                                      MINI_MARKET_CACHE=DIR reuses already-downloaded <packageId>.spk files.
#   japps.sh --box BIN-DIR             on a Linux box with the candidate's bin/ (dregg-build or the demo):
#                                      everything --dry does, plus `spk-host qualify` on four exhibits, all
#                                      accepted: Hacker Slides, Simple Todos, Etherpad (saveIdentityCaps:
#                                      the identity custody serves it) and Tiny Tiny RSS (expectAppHooks).
#                                      With a grain world (GRAINS_ROOT, BROKER_SOCKET, SPK_HOST profile as
#                                      scripts/spk-platform/grain-journey.sh wants them) it installs, starts,
#                                      reaches, stops and exports both apps on a scratch Store through that
#                                      script; without one it says UNCONFIGURED for that part and still passes
#                                      the rows above.
#
# Output: one row per check (`PASS|FAIL<TAB>row<TAB>detail`), then `J-APPS PASS n/n` or `J-APPS FAIL k/n`
# as the last line of stdout and stderr. Exit 0 only on PASS; 5 when a required input is absent.
# A process this script starts is stopped by the PID in its PID file, and only that.
set -uo pipefail
umask 077
HERE=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
REPO=$(CDPATH='' cd -- "$HERE/../.." && pwd)
FIXTURE=$HERE/tests/fixtures/sandstorm-index-2026-10-27.json
FETCH=$REPO/deploy/market/mini-market-fetch
# The two installs, and the two bridge-facility exhibits (bridge configs decoded 2026-10-27:
# Etherpad saveIdentityCaps=true, TT-RSS expectAppHooks=true; both served since the identity custody).
SLIDES_APP=7qvcjh7gk0rzdx1s3c8gufd288sesf6vvdt297756xcv4q8xxvhh SLIDES_PKG=f0277a5dce2e1c6af0cce188241411a4
TODOS_APP=0dp7n6ehj8r5ttfc0fj0au6gxkuy1nhw2kx70wussfa1mqj8tf80 TODOS_PKG=5830d70137cdae158118884da8790870
ETHERPAD_PKG=aee0806c9547d1f53c1ccef38ac195ba TTRSS_PKG=ac6dfded255f6ea86172fb62064772fc
UNKNOWN_APP=zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz

mode=${1:-}
BIN=${2:-}
rows=0 fails=0
row() { rows=$((rows + 1)); if [ "$2" = 1 ]; then printf 'PASS\t%s\t%s\n' "$1" "$3"; else fails=$((fails + 1)); printf 'FAIL\t%s\t%s\n' "$1" "$3"; fi; }
verdict() {
  local v="J-APPS PASS $rows/$rows"; [ "$fails" = 0 ] || v="J-APPS FAIL $fails/$rows"
  echo "$v"; echo "$v" >&2; [ "$fails" = 0 ]
}
unconfigured() { echo "$*" >&2; exit 5; }
[ -n "$BIN" ] && [ -x "$BIN/mini" ] || unconfigured "usage: japps.sh --dry|--box BIN-DIR [INSPECT]; no mini in ${BIN:-?}"
MINI=$BIN/mini
W=$(mktemp -d "${TMPDIR:-/tmp}/japps.XXXXXX")
PIDS=()
stop_all() { local p; for p in "${PIDS[@]}"; do [ -f "$p" ] && kill "$(cat "$p")" 2>/dev/null; rm -f "$p"; done; }
trap stop_all EXIT

# ---- the catalogue over the recorded fixture -------------------------------------------------
search=$("$MINI" apps search --index "$FIXTURE" --term slides 2>&1)
row "search finds Hacker Slides in the recorded index" "$(grep -q "$SLIDES_APP" <<<"$search" && echo 1 || echo 0)" "$(grep -c "$SLIDES_APP" <<<"$search") line(s)"
show=$("$MINI" apps show --index "$FIXTURE" --app "$TODOS_PKG" --json 2>&1)
row "show by packageId names the index's claims and an unverified verdict" \
  "$(grep -q '"name": "Simple Todos"' <<<"$show" && grep -q '"state": "unverified"' <<<"$show" && echo 1 || echo 0)" "$(grep -o '"state": "[a-z]*"' <<<"$show" | head -1)"
unknown=$("$MINI" apps show --index "$FIXTURE" --app "$UNKNOWN_APP" 2>&1)
row "an unknown appId is refused by name" "$(grep -q '^unknownApp' <<<"$unknown" || grep -q 'unknownApp:' <<<"$unknown" && echo 1 || echo 0)" "$(head -1 <<<"$unknown" | cut -c1-80)"
mkdir -p "$W/state"
check=$("$MINI" apps index-check --in "$FIXTURE" --out "$W/state/index.json" 2>&1)
row "index-check re-renders the 98 known entries" "$(grep -q '98 apps' <<<"$check" && [ -s "$W/state/index.json" ] && echo 1 || echo 0)" "$check"

# ---- the fetcher: two real packages into a scratch quarantine ---------------------------------
mkdir -p "$W/state/quarantine"
seed() { # PKG: reuse a cached download when MINI_MARKET_CACHE has it, else the fetcher downloads
  local c=${MINI_MARKET_CACHE:-}/$1.spk
  if [ -n "${MINI_MARKET_CACHE:-}" ] && [ -f "$c" ]; then cp "$c" "$W/state/quarantine/$1.spk"; chmod 0640 "$W/state/quarantine/$1.spk"; fi
}
for pkg in $SLIDES_PKG $TODOS_PKG; do
  seed "$pkg"
  out=$(bash "$FETCH" --state "$W/state" --mini "$MINI" fetch "$pkg" 2>&1)
  ok=0; grep -qE "^(fetched|verified) $pkg sha256=$pkg" <<<"$out" && [ -f "$W/state/meta/$pkg.json" ] && ok=1
  row "fetcher: $pkg in quarantine, SHA-256 prefix equals packageId, meta written" "$ok" "$(tail -1 <<<"$out" | cut -c1-120)"
done
bad=$(bash "$FETCH" --state "$W/state" --mini "$MINI" fetch "not-a-package-id" 2>&1); rc=$?
row "fetcher refuses a malformed packageId" "$([ "$rc" != 0 ] && echo 1 || echo 0)" "$(tail -1 <<<"$bad")"
# The verdict table, as the worker would write it: the catalogue shows it beside the index's claims.
mkdir -p "$W/verdicts"
printf '{"verdict":"verified","signedAppId":"h37dm17aa89yrd8zuqpdn36p6zntumtv08fjpu8a8zrte7q1cn60","facilities":["saveIdentityCaps"]}\n' >"$W/verdicts/$ETHERPAD_PKG.json"
pad=$("$MINI" apps show --index "$FIXTURE" --verdicts "$W/verdicts" --meta "$W/state/meta" --app "$ETHERPAD_PKG" 2>&1)
row "the catalogue shows the ingest's verdict beside Etherpad" "$(grep -q 'verdict    verified' <<<"$pad" && echo 1 || echo 0)" "$(grep verdict <<<"$pad" | head -1 | tr -s ' ')"
slides=$("$MINI" apps show --index "$FIXTURE" --verdicts "$W/verdicts" --meta "$W/state/meta" --app "$SLIDES_APP" 2>&1)
row "a fetched package's size and class come from the fetcher's meta" "$(grep -q 'class      S' <<<"$slides" && grep -q '16778192 bytes' <<<"$slides" && echo 1 || echo 0)" "$(grep -E 'size|class' <<<"$slides" | tr -s ' ' | tr '\n' ';')"

# ---- signatures: the stream reader's inspect (Mac) and spk-host qualify (box) -----------------
INSPECT=${3:-${INSPECT:-}}
if [ -z "$INSPECT" ] && [ -x "$BIN/inspect" ]; then INSPECT=$BIN/inspect; fi
if [ -n "$INSPECT" ] && [ -x "$INSPECT" ]; then
  mkdir -p "$W/scratch"
  for pair in "$SLIDES_PKG:$SLIDES_APP" "$TODOS_PKG:$TODOS_APP"; do
    pkg=${pair%%:*} app=${pair##*:}
    inv=$("$INSPECT" "$W/state/quarantine/$pkg.spk" "$W/scratch" standard-v1 2>"$W/inspect-$pkg.err")
    ok=0; grep -q "\"signature_verified\":true" <<<"$inv" && grep -q "\"app_id\":\"$app\"" <<<"$inv" && ok=1
    row "inspect verifies $pkg: signature and signed appId == index appId" "$ok" "$(grep -o '"raw_bytes":[0-9]*' <<<"$inv")$(tail -1 "$W/inspect-$pkg.err")"
  done
  cp "$W/state/quarantine/$SLIDES_PKG.spk" "$W/tampered.spk"
  size=$(stat -c %s "$W/tampered.spk" 2>/dev/null || stat -f %z "$W/tampered.spk")
  printf '\xff' | dd of="$W/tampered.spk" bs=1 seek=$((size / 2)) conv=notrunc 2>/dev/null
  if "$INSPECT" "$W/tampered.spk" "$W/scratch" standard-v1 >/dev/null 2>"$W/tampered.err"; then ok=0; else ok=1; fi
  row "a tampered copy is refused by name" "$ok" "$(tail -1 "$W/tampered.err" | cut -c1-120)"
else
  row "inspect available (INSPECT or BIN/inspect)" 0 "no inspect example: cargo build -p minidregg-spk-package-stream --example inspect"
fi
if [ "$mode" = --box ]; then
  if [ -x "$BIN/spk-host" ]; then
    # qualify spools beside its input and refuses a world-writable ancestor (/tmp): the copies sit
    # under the runner's own 0700 cache directory, as the operator's inbox does.
    # Directly under HOME (0700): a shared ~/.cache is often group-writable and refused too.
    Q=${JAPPS_QUALIFY_ROOT:-$HOME}/.mini-japps-qualify.$$
    mkdir -m 0700 "$Q"
    for pair in "$SLIDES_PKG:accept" "$TODOS_PKG:accept" "$ETHERPAD_PKG:accept" "$TTRSS_PKG:accept"; do
      pkg=${pair%%:*} want=${pair##*:}
      seed "$pkg"; bash "$FETCH" --state "$W/state" --mini "$MINI" fetch "$pkg" >/dev/null 2>&1
      cp "$W/state/quarantine/$pkg.spk" "$Q/$pkg.spk" && chmod 0600 "$Q/$pkg.spk"
      if q=$("$BIN/spk-host" qualify --import-profile standard-v1 "$Q/$pkg.spk" 2>"$W/q-$pkg.err"); then got=accept; else got=$(grep -oE 'saveIdentityCaps|expectAppHooks|apiPath' "$W/q-$pkg.err" | head -1); fi
      facilities=$(grep -oE '"saveIdentityCaps":(true|false),"expectAppHooks":(true|false)' <<<"$q" | head -1)
      row "spk-host qualify $pkg -> $want" "$([ "$got" = "$want" ] && echo 1 || echo 0)" "${got:-$(tail -1 "$W/q-$pkg.err" | cut -c1-120)} ${facilities}"
    done
    rm -rf "$Q"
  else
    row "spk-host present for qualify" 0 "no $BIN/spk-host"
  fi
fi

# ---- the front: Host and credential dispatch against a fake custodian ------------------------
mkdir -p "$W/origins"
FAKE=$W/alice.sock
python3 -I - "$FAKE" "$W/fake.pid" <<'PY' &
import os, socket, sys
path, pidfile = sys.argv[1], sys.argv[2]
open(pidfile, "w").write(str(os.getpid()))
s = socket.socket(socket.AF_UNIX); s.bind(path); s.listen(4)
while True:
    c, _ = s.accept()
    head = b""
    while b"\r\n\r\n" not in head:
        d = c.recv(4096)
        if not d: break
        head += d
    line = head.split(b"\r\n", 1)[0].decode("latin1")
    body = ("custodian saw " + line).encode()
    c.sendall(b"HTTP/1.1 200 OK\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % len(body) + body)
    c.close()
PY
PIDS+=("$W/fake.pid")
for _ in $(seq 1 50); do [ -S "$FAKE" ] && break; sleep 0.1; done
tok=a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1
hash=$(printf '%s' "$tok" | shasum -a 256 2>/dev/null | cut -d ' ' -f1); [ -n "$hash" ] || hash=$(printf '%s' "$tok" | sha256sum | cut -d ' ' -f1)
zero=0000000000000000000000000000000000000000000000000000000000000000
printf '{"protocol":"mini-apps-origin-v1","grain":"a4501","routes":[{"member":"alice","socket":"%s","browserTokenSha256":"%s","bootstrapTokenSha256":"%s","apiTokenSha256":"%s"}]}\n' "$FAKE" "$hash" "$zero" "$zero" >"$W/origins/a4501.json"
PORT=$(python3 -I -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1])')
nohup "$MINI" apps-front --listen "127.0.0.1:$PORT" --origins "$W/origins" --domain demo.dregg.online >"$W/front.log" 2>&1 &
echo $! >"$W/front.pid"; PIDS+=("$W/front.pid")
for _ in $(seq 1 50); do curl -s -m 1 -o /dev/null "http://127.0.0.1:$PORT/" && break; sleep 0.1; done
code() { local p=$1; shift; curl -s -m 10 -o "$W/body" -w '%{http_code}' "$@" "http://127.0.0.1:$PORT$p" ; }
c=$(code / -H 'Host: a9.demo.dregg.online'); row "front: unknown grain answers 404" "$([ "$c" = 404 ] && echo 1 || echo 0)" "$c"
c=$(code /pad -H 'Host: a4501.demo.dregg.online'); row "front: no credential answers 403 naming mini apps open" "$([ "$c" = 403 ] && grep -q 'mini apps open --grain a4501' "$W/body" && echo 1 || echo 0)" "$c $(head -c 60 "$W/body")"
c=$(code /__mini/bootstrap -H 'Host: a4501.demo.dregg.online'); row "front: GET /__mini/bootstrap serves the tokenless form" "$([ "$c" = 200 ] && grep -q 'name="token"' "$W/body" && echo 1 || echo 0)" "$c"
c=$(code /pad -H 'Host: a4501.demo.dregg.online' -H "Cookie: __Host-mini_spk_session=$tok"); row "front: the cookie selects alice's route and the custodian sees the request" "$([ "$c" = 200 ] && grep -q 'custodian saw GET /pad' "$W/body" && echo 1 || echo 0)" "$c $(cat "$W/body")"
c=$(code /pad -H 'Host: a4501.demo.dregg.online' -H "Cookie: __Host-mini_spk_session=$zero"); row "front: a wrong cookie is refused without touching the custodian" "$([ "$c" = 403 ] && echo 1 || echo 0)" "$c"
c=$(code /pad -H 'Host: demo.dregg.online'); row "front: the bare domain is not a grain origin" "$([ "$c" = 404 ] && echo 1 || echo 0)" "$c"

# ---- the lifecycle on a grain world (box only) -----------------------------------------------
# JAPPS_WORLD_ENV names a standing world's WORLD.env (scripts/spk-platform/world-up.sh): its
# Store, broker and profile are reused, so the rows run against a world that outlives them.
if [ "$mode" = --box ] && [ -n "${JAPPS_WORLD_ENV:-}" ] && [ -f "$JAPPS_WORLD_ENV" ]; then
  # shellcheck disable=SC1090
  . "$JAPPS_WORLD_ENV"
  export GRAINS_ROOT BROKER_SOCKET
  WORLD_RUN=$RUN
fi
if [ "$mode" = --box ]; then
  if [ -n "${GRAINS_ROOT:-}" ] && [ -n "${BROKER_SOCKET:-}" ] && [ -x "$BIN/spk-host" ] && [ -x "$BIN/minidregg-host" ]; then
    run=${WORLD_RUN:-$W/world}
    ok=0
    # The owner's role basis: role 0 when the signed bridge declares roles, allAccess otherwise.
    basis() { if "$BIN/spk-host" qualify --import-profile standard-v1 "$1" 2>/dev/null | jq -e '.signedSchema.roles | length > 0' >/dev/null; then echo '{"type":"role","id":"0"}'; else echo '{"type":"allAccess"}'; fi; }
    Q2=${JAPPS_QUALIFY_ROOT:-$HOME}/.mini-japps-basis.$$; mkdir -m 0700 "$Q2"
    cp "$W/state/quarantine/$SLIDES_PKG.spk" "$Q2/a.spk"; cp "$W/state/quarantine/$TODOS_PKG.spk" "$Q2/b.spk"
    seed "$ETHERPAD_PKG"; bash "$FETCH" --state "$W/state" --mini "$MINI" fetch "$ETHERPAD_PKG" >/dev/null 2>&1
    cp "$W/state/quarantine/$ETHERPAD_PKG.spk" "$Q2/c.spk"
    BASIS_A=$(basis "$Q2/a.spk"); BASIS_B=$(basis "$Q2/b.spk"); BASIS_C=$(basis "$Q2/c.spk"); rm -rf "$Q2"
    phases="birth-a install-a share-a start-a enroll-a get-a birth-b install-b share-b start-b enroll-b get-b stop-a"
    [ -n "${WORLD_RUN:-}" ] || phases="store services workroom profile $phases"
    # shellcheck disable=SC2086
    if BIN=$BIN SPK_A=$W/state/quarantine/$SLIDES_PKG.spk SPK_B=$W/state/quarantine/$TODOS_PKG.spk \
        KIND_A=web KIND_B=web GET_PATH_A=/ GET_PATH_B=/ CLASS_A=S CLASS_B=S \
        ROLE_BASIS_A=$BASIS_A ROLE_BASIS_B=$BASIS_B GRAINS_ROOT=$GRAINS_ROOT BROKER_SOCKET=$BROKER_SOCKET \
        sh "$REPO/scripts/spk-platform/grain-journey.sh" phase "$run" $phases \
          >"$W/world.out" 2>"$W/world.err"; then ok=1; fi
    row "two market apps on a scratch world: install, share, start, enroll, GET, stop one (grain-journey.sh)" "$ok" "$(tail -1 "$W/world.err" | cut -c1-160)"
    if [ "$ok" = 1 ]; then
      # The stopped app's id is the one grain-journey.sh's birth of app a bound (its retained source).
      app_a=$(jq -er '.applicationGrainBirth.applicationBirth.application.app' "$run/evidence/a-app-source.json" 2>/dev/null)
      exp=$("$BIN/spk-host" grain export "$(jq -er .profilePath "$run/evidence/profile-result.json")" "${app_a:?no app a birth source in $run/evidence}" "$W/export-a" 2>&1); rc=$?
      row "export of the stopped app writes var.ext4, manifest.json and manifest.sig" "$([ "$rc" = 0 ] && [ -f "$W/export-a/manifest.sig" ] && echo 1 || echo 0)" "$(tail -1 <<<"$exp" | cut -c1-120)"
      J="sh $REPO/scripts/spk-platform/grain-journey.sh phase $run"
      jenv() { env BIN="$BIN" GRAINS_ROOT="$GRAINS_ROOT" BROKER_SOCKET="$BROKER_SOCKET" KIND_A=web KIND_B=web KIND_C=web \
        GET_PATH_A=/ GET_PATH_B=/ GET_PATH_C=/p/main CLASS_A=S CLASS_B=S CLASS_C=M ROLE_BASIS_A="$BASIS_A" ROLE_BASIS_B="$BASIS_B" \
        ROLE_BASIS_C="$BASIS_C" SPK_A="$W/state/quarantine/$SLIDES_PKG.spk" SPK_B="$W/state/quarantine/$TODOS_PKG.spk" \
        SPK_C="$W/state/quarantine/$ETHERPAD_PKG.spk" "$@"; }
      req() {
        local method=$1 path=$2; shift 2
        curl -sS --max-time 900 --unix-socket "$dir/http.sock" -X "$method" -H 'Host: grain.test' \
          -H "Cookie: __Host-mini_spk_session=$(cat "$dir/browser.token")" -H 'Origin: https://grain.test' \
          -o "$body" -w '%{http_code}' "$@" "http://grain.test$path" 2>>"$out/curl.err"
      }
      . "$REPO/scripts/spk-platform/market-writes/japps.sh"
      state=$(jq -er .stateRoot "$(jq -er .profilePath "$run/evidence/profile-result.json")")
      # The tour's step 7: a second browser session on the running Simple Todos grain co-edits.
      app_b=$(jq -er '.applicationGrainBirth.applicationBirth.application.app' "$run/evidence/b-app-source.json")
      if jenv $J share-b2 enroll-b2 register-b2 get-b2 >"$W/coedit-world.out" 2>"$W/coedit-world.err"; then
        co=$(python3 "$REPO/scripts/spk-platform/ddp-coedit.py" "$state/apps/$app_b/routes/owner-web" "$state/apps/$app_b/routes/guest2-web" 2>&1 | tail -1)
      else co="second session: $(tail -1 "$W/coedit-world.err")"; fi
      row "a second browser session co-edits Simple Todos (B sees A's todo over DDP)" "$(jq -e .ok <<<"$co" >/dev/null 2>&1 && echo 1 || echo 0)" "$(cut -c1-160 <<<"$co")"
      # The publishing origin: restart the stopped Hacker Slides grain and read its /var/www
      # through the resident's www.sock (the socket the front reaches through the connector).
      app_a_dir=$state/apps/$app_a
      if jenv $J start-a >"$W/www-world.out" 2>"$W/www-world.err"; then
        www=$(curl -sS --max-time 120 --unix-socket "$app_a_dir/www.sock" -H 'Host: grain.test' -o "$W/www-index.body" -D - http://grain.test/ 2>&1 | head -1 | tr -d '\r')
        post=$(curl -sS --max-time 30 --unix-socket "$app_a_dir/www.sock" -X POST -o /dev/null -w '%{http_code}' http://grain.test/ 2>&1)
        esc=$(curl -sS --max-time 30 --unix-socket "$app_a_dir/www.sock" -o /dev/null -w '%{http_code}' --path-as-is 'http://grain.test/../g2/resident.json' 2>&1)
      else www="start-a: $(tail -1 "$W/www-world.err")"; fi
      row "the publishing socket serves Hacker Slides' /var/www (GET / 200, POST 405, an escape 404)" "$([ "${www:-}" = 'HTTP/1.1 200 OK' ] && [ "${post:-}" = 405 ] && [ "${esc:-}" = 404 ] && echo 1 || echo 0)" "${www:-none} post=${post:-} escape=${esc:-} $(head -c 60 "$W/www-index.body" 2>/dev/null | tr -d '\n')"
      # A third market app, Etherpad (saveIdentityCaps): create, install, share, start, enrol, GET.
      if jenv $J birth-c install-c share-c start-c enroll-c get-c >"$W/etherpad-world.out" 2>"$W/etherpad-world.err"; then ep=1; else ep=0; fi
      row "Etherpad on the same world: create, install, share, start, enrol, its pad /p/main 200" "$ep" "$(tail -1 "$W/etherpad-world.err" | cut -c1-160)"
      if [ "$ep" = 1 ]; then
        app_c=$(jq -er '.applicationGrainBirth.applicationBirth.application.app' "$run/evidence/c-app-source.json")
        dir=$state/apps/$app_c/routes/owner-web body=$W/etherpad-write.body out=$W
        result=$(write_Etherpad 2>&1 | tail -1)
        row "Etherpad: one pad import beneath the HTML, exported back" "$([ "${result%% *}" = 1 ] && echo 1 || echo 0)" "${result#* }"
      fi
    fi
    [ -n "${WORLD_RUN:-}" ] || sh "$REPO/scripts/spk-platform/grain-journey.sh" stop-services "$run" >/dev/null 2>&1 || true
  else
    echo "UNCONFIGURED lifecycle rows: need JAPPS_WORLD_ENV=RUN/WORLD.env from scripts/spk-platform/world-up.sh (or GRAINS_ROOT and BROKER_SOCKET), $BIN/spk-host and $BIN/minidregg-host" >&2
  fi
fi

verdict; rc=$?
rm -rf "$W/state/quarantine" "$W/scratch" "$W/tampered.spk"
exit $rc
