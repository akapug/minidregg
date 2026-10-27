#!/bin/bash
# apps-e2e.sh WORLD.env OUT_DIR APP-ID [APP-ID...]: the first real `mini apps install`, end to end,
# on a standing world (world-up.sh), as the member turn docs/APP-MARKET-2026-10-27.md §3 describes:
#   - the manager (the workroom's subject 8, tool.key) and a member (the workroom's subject 9,
#     member.key) each get a workspace over their own key and birth context;
#   - the manager imports the world's metered tool and parent references and delegates observe and
#     the grain operation on both to the member (`delegate`, `submit`, `publish`), leaving the
#     recipient references in the member's HOME/inbox exactly as mini-reenroll's apps_member_grants
#     does on the box;
#   - apps.json (mini-apps-config-v1) and the worker's apps-world.json are written; the worker runs
#     (its PID in OUT/worker.pid) with --dev-member member (no mini-s-* accounts on a lane box);
#   - the member runs `mini apps install` for each APP-ID over the recorded index with the packages
#     pre-seeded in a quarantine (MINI_MARKET_CACHE), retrying on `fetching`/`undecided` until
#     decided, then `apps list`, `apps status`, `apps open`;
#   - the origin check: one authenticated GET through the grain's route socket with the route's
#     browser cookie and the grain's Host, as the edge would send it.
# Every step is one real verb; nothing is faked. Stop the worker by its PID file only.
set -uo pipefail
umask 077
[[ $# -ge 3 ]] || { echo "usage: $0 WORLD.env OUT_DIR APP-ID [APP-ID...]" >&2; exit 2; }
env_file=$1 out=$2; shift 2
# shellcheck disable=SC1090
. "$env_file"
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
FIXTURE=$repo/native/resource-client/tests/fixtures/sandstorm-index-2026-10-27.json
[[ ! -e $out ]] || { echo "fresh OUT_DIR required" >&2; exit 2; }
mkdir -m 700 "$out"
rows=0 fails=0
row() { rows=$((rows + 1)); if [ "$2" = 1 ]; then printf 'PASS\t%s\t%s\n' "$1" "$3"; else fails=$((fails + 1)); printf 'FAIL\t%s\t%s\n' "$1" "$3"; fi; }
verdict() { local v="J-APPS-E2E PASS $rows/$rows"; [ "$fails" = 0 ] || v="J-APPS-E2E FAIL $fails/$rows"; echo "$v"; echo "$v" >&2; [ "$fails" = 0 ]; }
MINI=$BIN/mini
WR=$RUN/store/base/workroom
GENESIS=$WR/genesis.json
[[ -f $GENESIS && -f $WR/tool.key && -f $WR/member.key ]] || { echo "the world's workroom lacks genesis.json, tool.key or member.key" >&2; exit 1; }
# `--socket` is a client option after the command (never before it).
mini() { local command=$1; shift; "$MINI" "$command" --socket "$PSOCK" "$@"; }

# ---- two workspaces over the workroom's own keys ----------------------------------------------
context() { # SUBJECT FACTORY-CAP ACCOUNT-CAP -> file
  local s=$1 fcap=$2 acap=$3 f=$out/context-$1.json
  jq -n --slurpfile g "$GENESIS" --arg s "$s" --arg f "$fcap" --arg a "$acap" '
    {type:"minidregg-participant-birth-context-v1",genesis:$g[0],template:{issuer:"5",ownerBudget:"100000",lifetime:"10000"},
     feePayer:$s,sourceCapabilities:[$a],funding:[],
     grants:[{kind:"object",target:"10",capability:$f},{kind:"account",target:$s,capability:$a}]}' >"$f"
  echo "$f"
}
init_ws() { # NAME SUBJECT KEY CONTEXT
  local ws=$out/ws-$1 home=$out/home-$1
  mkdir -m 700 -p "$home/inbox" "$out/ns-$1"
  mini workspace --action init --dir "$ws" --host "$HOST" --config "$CONFIG" --key "$3" --subject "$2" \
    --birth-context "$4" --namespace-root "$out/ns-$1" --next-pub "$3.next.pub" >"$out/init-$1.out" 2>"$out/init-$1.err" \
    || mini workspace --action init --dir "$ws" --host "$HOST" --config "$CONFIG" --key "$3" --subject "$2" \
      --birth-context "$4" --namespace-root "$out/ns-$1" --no-prerotation >>"$out/init-$1.out" 2>>"$out/init-$1.err"
  [[ -f $ws/workspace.json ]]
}
init_ws manager 8 "$WR/tool.key" "$(context 8 55 42)"; row "manager workspace (subject 8) over the workroom's tool key" "$([ -f "$out/ws-manager/workspace.json" ] && echo 1 || echo 0)" "$(tail -1 "$out/init-manager.err" 2>/dev/null | cut -c1-120)"
init_ws member 9 "$WR/member.key" "$(context 9 57 43)"; row "member workspace (subject 9) over the workroom's member key" "$([ -f "$out/ws-member/workspace.json" ] && echo 1 || echo 0)" "$(tail -1 "$out/init-member.err" 2>/dev/null | cut -c1-120)"
WSM=$out/ws-manager WS9=$out/ws-member HOME9=$out/home-member

# ---- the manager's references to the metered tasks, delegated to the member ---------------------
mini workspace --action import --dir "$WSM" --name tool --kind object --target 7902 --observe-capability 81 --operation-capability 81 >"$out/import-tool.out" 2>&1
mini workspace --action import --dir "$WSM" --name parent --kind object --target 7901 --observe-capability 73 --operation-capability 73 >"$out/import-parent.out" 2>&1
row "the manager holds tool and parent references" "$([ -f "$WSM/refs/tool.json" ] && [ -f "$WSM/refs/parent.json" ] && echo 1 || echo 0)" "$(tail -1 "$out/import-parent.out" | cut -c1-100)"
delegate() { # REF
  local id=apps-$1-member
  printf '{"type":"minidregg-workspace-proposal-v1","action":"delegate","name":"%s","recipient":"9","verbs":["observe","mutate"],"maxCost":"1000"}\n' "$1" >"$out/delegate-$1.json"
  mini workspace --action propose --dir "$WSM" --request "$out/delegate-$1.json" --proposal-id "$id" >"$out/propose-$1.out" 2>&1 || return 1
  mini workspace --action submit --dir "$WSM" --intent "$WSM/proposals/$id/intent.json" --attempt "$WSM/attempts/$id" >"$out/submit-$1.out" 2>&1 || return 1
  mini workspace --action publish-delegation --dir "$WSM" --proposal-id "$id" --attempt "$WSM/attempts/$id" >"$out/publish-$1.out" 2>&1 || return 1
  cp "$WSM/proposals/$id/recipient-reference.json" "$HOME9/inbox/$1.json"
}
ok=1; delegate tool || ok=0; delegate parent || ok=0
row "the manager delegates observe+mutate on both tasks to the member; references land in HOME/inbox" "$ok" "$(for r in tool parent; do tail -1 "$out/publish-$r.out" 2>/dev/null | cut -c1-80; done | tr '\n' ' ')"

# ---- the world's apps config and the worker --------------------------------------------------------
mkdir -m 700 -p "$out/quarantine" "$out/wanted" "$out/verdicts" "$out/meta" "$out/state"
chmod 755 "$out/verdicts" "$out/meta"
for f in "${MINI_MARKET_CACHE:-/nonexistent}"/*.spk; do [ -f "$f" ] && cp "$f" "$out/quarantine/"; done
printf '{"protocol":"mini-apps-config-v1","managementSubject":"8","toolRef":"tool","parentRef":"parent","tariff":{"base":"2","perBirth":"1"}}\n' >"$out/apps.json"
jq -n --arg profile "$PROFILE" --arg mini "$MINI" --arg psock "$PSOCK" --arg genesis "$GENESIS" --arg q "$out/quarantine" --arg w "$out/wanted" --arg v "$out/verdicts" --arg nonce "$out/nonce" '
  {protocol:"mini-apps-world-v1",profile:$profile,mini:$mini,publicSocket:$psock,managementKeyId:"8008",
   toolTask:"7902",toolCapability:"81",parentTask:"7901",parentCapability:"73",genesis:$genesis,
   quarantine:$q,wanted:$w,verdicts:$v,domain:"demo.test",nonceFile:$nonce,roleBasis:{type:"allAccess"}}' >"$out/apps-world.json"
nohup "$MINI" apps-worker --state "$out/state" --world "$out/apps-world.json" --member-socket "$out/worker.sock" --edge-socket "$out/edge.sock" --dev-member member >"$out/worker.log" 2>&1 &
echo $! >"$out/worker.pid"
for _ in $(seq 1 50); do [ -S "$out/worker.sock" ] && break; sleep 0.1; done
row "the worker serves its member socket" "$([ -S "$out/worker.sock" ] && echo 1 || echo 0)" "pid $(cat "$out/worker.pid")"
stop_worker() { [ -f "$out/worker.pid" ] && kill "$(cat "$out/worker.pid")" 2>/dev/null; rm -f "$out/worker.pid"; }
trap stop_worker EXIT

# ---- the install, as the member -------------------------------------------------------------------
export MINI_MARKET_INDEX=$FIXTURE MINI_MARKET_META=$out/meta MINI_APPS_VERDICTS=$out/verdicts MINI_APPS_WORKER_SOCKET=$out/worker.sock MINI_APPS_CONFIG=$out/apps.json
install_app() { # APP-ID
  local app=$1 attempt=1 outcome rid
  outcome=$(mini apps install --dir "$WS9" --home "$HOME9" --app "$app" --class S --json 2>"$out/install-$app.err")
  rid=$(grep -oE 'request [0-9a-f]{32}' <<<"$outcome" | head -1 | cut -d' ' -f2)
  [ -n "$rid" ] || rid=$(ls "$WS9/apps/requests/" 2>/dev/null | grep -E '^[0-9a-f]{32}\.json$' | tail -1 | cut -d. -f1)
  while [ $attempt -le 20 ] && ! grep -q '"decided": true' <<<"$outcome"; do
    attempt=$((attempt + 1)); sleep 15
    outcome=$(mini apps install --dir "$WS9" --home "$HOME9" --app "$app" --retry "$rid" --json 2>>"$out/install-$app.err")
  done
  printf '%s\n' "$outcome" >"$out/install-$app.json"
  grep -q '"state": "running"' <<<"$outcome"
}
for app in "$@"; do
  name=$(jq -r --arg a "$app" '.apps[] | select(.appId == $a or .packageId == $a) | .name' "$FIXTURE" | head -1)
  if install_app "$app"; then
    grain=$(grep -oE '"grain": "a[0-9]+"' "$out/install-$app.json" | head -1 | grep -oE 'a[0-9]+')
    row "install $name as the member: running, grain $grain" 1 "$(jq -r '.receipt.origin' "$out/install-$app.json" 2>/dev/null)"
    # the origin check: one authenticated GET through the route socket with the route's cookie and the grain's Host
    rdir=$(jq -r --arg m member '.routes[$m].directory' "$out/state/grains/$grain.json")
    code=$(curl -sS --max-time 900 --unix-socket "$rdir/http.sock" -H "Host: $grain.demo.test" -H "Origin: https://$grain.demo.test" \
      -H "Cookie: __Host-mini_spk_session=$(cat "$rdir/browser.token")" -o "$out/$grain.body" -w '%{http_code}' "http://$grain.demo.test/" 2>"$out/$grain.curl.err" || echo 000)
    anon=$(curl -sS --max-time 120 --unix-socket "$rdir/http.sock" -H "Host: $grain.demo.test" -o /dev/null -w '%{http_code}' "http://$grain.demo.test/" 2>/dev/null || echo 000)
    row "origin check $grain: authenticated GET 200 through the route, anonymous refused" "$([ "$code" = 200 ] && [ "$anon" != 200 ] && echo 1 || echo 0)" "authed=$code anon=$anon $(head -c 60 "$out/$grain.body" | tr '\n' ' ')"
    open=$(mini apps open --dir "$WS9" --grain "$grain" --json 2>&1); row "apps open $grain hands the member the one-time bootstrap token" "$(grep -q bootstrapToken <<<"$open" && echo 1 || echo 0)" "$(grep -oE '"origin": "[^"]*"' <<<"$open")"
  else
    row "install $name as the member" 0 "$(tail -1 "$out/install-$app.err" | cut -c1-160) $(grep -oE '"(refused|state|detail)": "[^"]*"' "$out/install-$app.json" | tr '\n' ' ' | cut -c1-200)"
  fi
done
listed=$(mini apps list --dir "$WS9" --json 2>&1); row "apps list shows the member's grains" "$(grep -q '"grains"' <<<"$listed" && echo 1 || echo 0)" "$(grep -oE '"grain": "a[0-9]+"' <<<"$listed" | tr '\n' ' ')"
cp "$out/state/grains/"*.json "$out/" 2>/dev/null
verdict