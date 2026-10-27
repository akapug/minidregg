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
# A standing world hosts many apps: every app birth reserves on the workroom's tool task and every
# share issues a metered ticket, so the provisioner's single-journey defaults (tool budget 50) run
# out after three apps. A standing world takes the platform provisioner's allocations instead.
export WORKROOM_TOOL_BUDGET=${WORKROOM_TOOL_BUDGET:-1000000} WORKROOM_PARENT_BUDGET=${WORKROOM_PARENT_BUDGET:-1000000}
export WORKROOM_TOOL_BALANCE=${WORKROOM_TOOL_BALANCE:-1000000} WORKROOM_SPONSOR_BALANCE=${WORKROOM_SPONSOR_BALANCE:-1000000}
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
runid=$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')
helper=/usr/local/libexec/mini-spk-volume-helper-$runid
# The Store first: its native profile names the store tag the world is keyed by.
BIN="$run/bin" GRAINS_ROOT=/var/lib/mini-spk-worlds/0000000000000000 \
  BROKER_SOCKET=/var/lib/mini-spk-worlds/0000000000000000/runtime-0000000000000000/broker.sock \
  "$here/grain-journey.sh" phase "$run/w" store | tee "$run/w/store-phase.log"
config=$run/w/store/base/workroom/deployment/pinned-config.json
"$run/bin/minidregg-host" "$config" profile >"$run/w/native-profile.json"
store=$(jq -er '.storeTag | select(test("^[0-9a-f]{16}$"))' "$run/w/native-profile.json")
root=/var/lib/mini-spk-worlds/$store
# A free 16-ID slice of the operator's subordinate allocation: a lane box carries several standing
# worlds, and the installer refuses a slice another world's registry already names.
read -r start count < <(awk -F: -v user="$op_name" '$1==user && $3>=16 {print $2,$3;exit}' /etc/subuid)
[[ $start =~ ^[0-9]+$ && $count =~ ^[0-9]+$ ]] || { echo "no /etc/subuid range for $op_name" >&2; exit 1; }
end=$((start + count))
while ((start + 16 <= end)); do
  occupied=0
  for registry in /etc/mini-spk-volumes/*.json; do
    [[ -f $registry ]] || continue
    if jq -e --argjson first "$start" --argjson last "$((start + 16))" '.appUids | any(. >= $first and . < $last)' "$registry" >/dev/null 2>&1; then occupied=1; break; fi
  done
  [[ $occupied == 1 ]] || break
  start=$((start + 16))
done
((start + 16 <= end)) || { echo "no unused 16-ID subordinate slice for $op_name" >&2; exit 1; }
bwrap=$(sh "$repo/deploy/grain-host/resolve-bwrap") || exit 1
deployment=$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')
host=$(sha256sum /etc/machine-id | cut -d ' ' -f1)
printf 'ROOT SETUP BEGIN store=%s\n' "$store" | tee -a "$run/root-setup.log"
sudo -n -- "$installer" install "$run/bin/mini-spk-volume-helper" "$helper" "$store" "$deployment" "$host" "$op_uid" "$start" 16 >>"$run/root-setup.log" 2>&1
printf 'ROOT SETUP store=%s helper=%s\n' "$store" "$helper" | tee -a "$run/root-setup.log"
registry=/etc/mini-spk-volumes/$store.json
# MINI_IMPORT_PROFILE is the operator's physical intake budget for materialising a package
# (standard-v1: 120 s; operator-appliance-v1: 1800 s, the oracle runtime's 15,155 members).
import_profile=${MINI_IMPORT_PROFILE:-standard-v1}
case $import_profile in standard-v1|operator-appliance-v1) ;; *) echo "unknown MINI_IMPORT_PROFILE $import_profile" >&2; exit 2;; esac
jq -n --slurpfile registry "$registry" --arg binary "$run/bin/spk-host" --arg sha "$(sha256sum "$run/bin/spk-host" | cut -d ' ' -f1)" --arg ingest "$run/bin/spk-ingest" --arg op "$op_name" \
  --arg bwrap "$bwrap" --arg bwrapSha "$(sha256sum "$bwrap" | cut -d ' ' -f1)" --arg importProfile "$import_profile" '
  $registry[0] as $r | {protocol:"mini-spk-broker-config-v3",store:$r.store,grainsRoot:$r.grainsRoot,spkRoot:($r.grainsRoot+"/spk"),brokerSocket:($r.grainsRoot+"/runtime-"+$r.store+"/broker.sock"),operatorUser:$op,unitPrefix:"mini",spkHost:$binary,spkHostSha256:$sha,bwrap:$bwrap,bwrapSha256:$bwrapSha,ingestHelper:$ingest,volumeHelper:$r.helper,appUids:$r.appUids,residentHomeReadOnlyPaths:[],importProfile:$importProfile}' >"$root/broker/config.json"
chmod 600 "$root/broker/config.json"
sed "s|%h/.local/libexec/mini-spk-broker|$run/bin/mini-spk-broker|" "$repo/deploy/spk-host/mini-spk-broker@.service" >"$units/mini-spk-broker@$store.service"
systemctl --user daemon-reload
systemctl --user start "mini-spk-broker@$store.service"
socket=$root/runtime-$store/broker.sock
for attempt in $(seq 1 100); do [[ ! -S $socket ]] || break; sleep 0.1; done
[[ -S $socket && $(stat -c '%u:%a' "$socket") == "$op_uid:600" ]] || { echo 'operator broker socket custody failed' >&2; exit 1; }
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
printf 'WORLD UP store=%s grains=%s broker=%s profile=%s\n' "$store" "$root" "$socket" "$profile" | tee -a "$run/result.log"
echo "$run/WORLD.env"
