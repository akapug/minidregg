#!/bin/bash
# world-up.sh BASE_BIN OWN_RUST_BIN NEW_RUN_ROOT: ONE standing grain world for a lane box
# (docs/APP-MARKET-2026-10-27.md §6): the same ROOT SETUP, operator broker and Store phases
# two-world-journey.sh performs, without its teardown trap, so `japps.sh --box` and a real
# `mini apps install` can run against it; `world-down.sh RUN_ROOT` removes it with the same
# checked cleanup. The operator is MINI_OPERATOR_UID / MINI_OPERATOR_NAME; the script runs AS
# that uid (on dregg-build: lanes is both runner and operator). Root is reached only through the
# deployment installer (sudo -n) and the fixed-verb volume helper it registers.
# Writes RUN_ROOT/WORLD.env: BIN GRAINS_ROOT BROKER_SOCKET STORE PROFILE RUN HOST CONFIG OSOCK PSOCK HELPER.
set -euo pipefail
umask 077
[[ $# == 3 ]] || { echo "usage: $0 BASE_BIN OWN_RUST_BIN NEW_RUN_ROOT" >&2; exit 2; }
base=$1 own=$2 run=$3
op_uid=${MINI_OPERATOR_UID:-1001} op_name=${MINI_OPERATOR_NAME:-ember}
[[ $(id -u) == "$op_uid" ]] || { echo "world-up requires operator uid $op_uid" >&2; exit 1; }
[[ $(getent passwd "$op_uid" | cut -d: -f1) == "$op_name" ]] || { echo "operator uid $op_uid is not $op_name" >&2; exit 1; }
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$op_uid}
units=/run/user/$op_uid/systemd/user
[[ $run == /* && $run != *[!a-zA-Z0-9_./-]* && ! -e $run ]] || { echo 'fresh simple absolute run root required' >&2; exit 2; }
ancestor=$(dirname "$run")
while :; do
  [[ -d $ancestor && ! -L $ancestor ]] || exit 2
  (( (8#$(stat -c '%a' "$ancestor") & 8#022) == 0 )) || { echo "scratch custody refuses writable ancestor: $ancestor" >&2; exit 2; }
  [[ $ancestor == / ]] && break
  ancestor=$(dirname "$ancestor")
done
# A standing world hosts many apps: every app birth reserves 5 on the workroom's tool task and
# every share issues a metered ticket of 3, so the provisioner's single-journey tool budget (50)
# runs out after about six apps. A standing world takes 100 (scripts/grain-birth/native-share-member.sh
# checks the provisioned remainder against this budget).
export WORKROOM_TOOL_BUDGET=${WORKROOM_TOOL_BUDGET:-100}
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
installer=$repo/deploy/spk-host/install-user-world
systemctl --user is-active default.target >/dev/null
[[ $(loginctl show-user "$op_uid" -p Linger --value) == yes ]] || { echo 'operator linger is required' >&2; exit 1; }
mkdir -m 700 -p "$units" "$run/bin" "$run/w/evidence"
# Lean roles from the candidate; the Rust roles (mini with the apps verbs, spk-host with the
# identity custody, the broker, the volume helper) from the lane's own build.
for binary in minidregg-host minidregg-link-sqlite-store minidregg-credential-signature-verifier minidregg-client-consent; do
  install -m 755 "$base/$binary" "$run/bin/$binary"
done
for binary in mini spk-host mini-spk-broker mini-spk-volume-helper; do
  install -m 755 "$own/$binary" "$run/bin/$binary"
done
# The public-data publisher (the oracle's shared dataset) when the lane built it; optional otherwise.
[[ ! -x $own/spk-data-publish ]] || install -m 755 "$own/spk-data-publish" "$run/bin/spk-data-publish"
install -m 755 "$repo/deploy/spk-host/spk-ingest" "$run/bin/spk-ingest"
sha256sum "$run/bin/"* >"$run/binary-sha256.txt"
# The Store first: its native profile names the store tag the world is keyed by.
BIN="$run/bin" GRAINS_ROOT=/var/lib/mini-spk-worlds/0000000000000000 \
  BROKER_SOCKET=/var/lib/mini-spk-worlds/0000000000000000/runtime-0000000000000000/broker.sock \
  "$here/grain-journey.sh" phase "$run/w" store | tee "$run/w/store-phase.log"
config=$run/w/store/base/workroom/deployment/pinned-config.json
broker_status=0
"$here/broker-world-up.sh" "$run/bin" "$config" "$run/broker-setup" >"$run/broker-setup.stdout" || broker_status=$?
# Root installation can succeed before a later broker check fails. Preserve
# the recovery locator in the old caller-visible place on either outcome.
[[ ! -f $run/broker-setup/root-setup.log ]] || cp "$run/broker-setup/root-setup.log" "$run/root-setup.log"
[[ ! -f $run/broker-setup/native-profile.json ]] || cp "$run/broker-setup/native-profile.json" "$run/w/native-profile.json"
((broker_status == 0)) || exit "$broker_status"
store=$(jq -er .store "$run/broker-setup/broker.json")
root=$(jq -er .grainsRoot "$run/broker-setup/broker.json")
socket=$(jq -er .brokerSocket "$run/broker-setup/broker.json")
helper=$(jq -er .helper "$run/broker-setup/broker.json")
# The Store's services, the workroom's metered tasks and the grain-host profile.
BIN="$run/bin" GRAINS_ROOT="$root" BROKER_SOCKET="$socket" "$here/grain-journey.sh" phase "$run/w" services workroom profile
profile=$(jq -er .profilePath "$run/w/evidence/profile-result.json")
cat >"$run/WORLD.env" <<ENV
BIN=$run/bin
GRAINS_ROOT=$root
BROKER_SOCKET=$socket
STORE=$store
PROFILE=$profile
RUN=$run/w
HOST=$run/bin/minidregg-host
CONFIG=$config
OSOCK=$run/w/sock/operator/host.sock
PSOCK=$run/w/sock/participant/host.sock
HELPER=$helper
ENV
chmod 600 "$run/WORLD.env"
# Dispatches are durable turns, including GETs. Without the ordinary operator
# certifier a standing world fills its 256-record tail and every app stops.
mkdir -m 700 "$run/certifier"
jq -n --arg host "$run/bin/minidregg-host" --arg socket "$run/w/sock/operator/host.sock" \
  --arg config "$config" --arg key "$run/w/store/base/workroom/controller.key" \
  --arg subject "$(jq -er .factoryControllerSubject "$run/w/store/base/workroom/genesis.json")" \
  '{type:"minidregg-participant-workspace-v1",host:$host,socket:$socket,
    config:$config,key:$key,subject:$subject}' >"$run/certifier/workspace.json"
"$run/bin/mini" checkpoint --action view --workspace "$run/certifier" >"$run/certifier/initial-view.json"
certifier=mini-spk-certify-$store.service
cat >"$units/$certifier" <<UNIT
[Unit]
Description=Mini standing-world certifier $store
[Service]
Type=simple
ExecStart=/bin/bash $here/world-certifier.sh $run
Restart=on-failure
RestartSec=2
MemoryMax=512M
StandardOutput=append:$run/certifier/operator.log
StandardError=append:$run/certifier/operator.log
UNIT
systemctl --user daemon-reload
systemctl --user start "$certifier"
systemctl --user show "$certifier" -p MainPID --value >"$run/certifier/pid"

printf 'WORLD UP store=%s grains=%s broker=%s profile=%s\n' "$store" "$root" "$socket" "$profile" | tee -a "$run/result.log"
echo "$run/WORLD.env"
