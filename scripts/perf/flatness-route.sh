#!/usr/bin/env bash
# flatness-route.sh CANDIDATE NEW_ROOT [N=1000] [LO=10]
# Own fresh SandMD world; all binaries from one candidate. Requires the normal
# operator world installer and its user bus. Run as the operator, never root.
set -euo pipefail
umask 077
[[ $# -ge 2 && $# -le 4 ]] || { echo "usage: $0 CANDIDATE NEW_ROOT [N] [LO]" >&2; exit 2; }
candidate=$(realpath "$1"); root=$(realpath -m "$2"); n=${3:-1000}; lo=${4:-10}
here=$(cd "$(dirname "$0")" && pwd)
repo=${FLATNESS_SOURCE:-$(cd "$here/../.." && pwd)}
[[ $(id -u) != 0 && ! -e $root ]] || { echo 'requires non-root operator and fresh root' >&2; exit 2; }
# The standard world's resident inventory contains no /home paths. Its own
# copied binaries and key custody therefore need an operator-owned scratch
# directory outside /home (on hbox use /ci/<lane>/...).
case "$root" in /home/*|/root/*) echo 'route world needs scratch outside /home and /root (resident custody inventory)' >&2; exit 2 ;; esac
mkdir -m 700 "$root"
export CANDIDATE=$candidate MINI_OPERATOR_UID=$(id -u) MINI_OPERATOR_NAME=$(id -un)
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$MINI_OPERATOR_UID}
export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}
export MINI_CONSENT_ANCHOR_DIR=$root/a
export WORKROOM_SPONSOR_BALANCE=1000000000 WORKROOM_METER_ALLOWANCE=1000000000000
world=$root/world
cleanup() {
  local rc=$?
  if [[ -f $world/WORLD.env || -f $world/broker-setup/recovery.json ]]; then
    bash "$repo/scripts/spk-platform/world-down.sh" "$world" >"$root/down.log" 2>&1 || rc=2
  fi
  if [[ -d $root/a ]]; then
    bash "$repo/scripts/spk-platform/stop-residents.sh" "$root" >>"$root/down.log" 2>&1 || rc=2
  fi
  exit "$rc"
}
trap cleanup EXIT
bash "$repo/scripts/spk-platform/world-up.sh" "$candidate/bin" "$candidate/bin" "$world" >"$root/up.log" 2>&1 &
echo $! >"$root/up.pid"; wait "$(cat "$root/up.pid")"
. "$world/WORLD.env"
pkg=fc037a205dc9017cf1941ffdcb6029ea
mkdir -p "$root/market/quarantine"
if [[ -n ${MINI_MARKET_CACHE:-} && -f $MINI_MARKET_CACHE/$pkg.spk ]]; then
  cp "$MINI_MARKET_CACHE/$pkg.spk" "$root/market/quarantine/$pkg.spk"
else
  bash "$repo/deploy/market/mini-market-fetch" --state "$root/market" --mini "$BIN/mini" fetch "$pkg" >"$root/fetch.log" 2>&1 &
  echo $! >"$root/fetch.pid"; wait "$(cat "$root/fetch.pid")"
fi
export BIN GRAINS_ROOT BROKER_SOCKET SPK_J=$root/market/quarantine/$pkg.spk KIND_J=web GET_PATH_J=/ CLASS_J=S
export ROLE_BASIS_J='{"type":"allAccess"}'
sh "$repo/scripts/spk-platform/grain-journey.sh" phase "$RUN" birth-j install-j share-j start-j enroll-j get-j >"$root/route.log" 2>&1 &
echo $! >"$root/route.pid"; wait "$(cat "$root/route.pid")"
wr=$RUN/store/base/workroom
subject=$(jq -er .factoryControllerSubject "$wr/genesis.json")
control=$(jq -er .factoryControllerCapability "$wr/genesis.json")
"$BIN/mini" workspace --action init --dir "$root/certifier" --host "$HOST" --config "$CONFIG" \
  --socket "$OSOCK" --key "$wr/controller.key" --subject "$subject" \
  --birth-context "$wr/sponsor-birth-context.json" --namespace-root "$root/ns" --no-prerotation >"$root/certifier.log" 2>&1 &
echo $! >"$root/certifier.pid"; wait "$(cat "$root/certifier.pid")"
state=$(jq -er .stateRoot "$PROFILE")
app=$(jq -er '.applicationGrainBirth.applicationBirth.application.app' "$RUN/evidence/j-app-source.json")
python3 "$here/flatness-route.py" --route "$state/apps/$app/routes/owner-web" \
  --pid-file "$RUN/sock/operator.pid" --root "$root/measure" --mini "$BIN/mini" \
  --workspace "$root/certifier" --control "$control" --n "$n" --lo "$lo" &
echo $! >"$root/measure.pid"; wait "$(cat "$root/measure.pid")"
