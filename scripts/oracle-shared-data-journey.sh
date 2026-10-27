#!/usr/bin/env bash
# Actual Mini receiving journey: a new private Store, signed runtime install,
# current share/enrollment and dispatch, two grains, refusal and restart.
# Cross-file globals come from world.sh; redirects deliberately stay operator-owned.
# shellcheck disable=SC2024,SC2154,SC2174
set -euo pipefail
umask 077
usage() {
  cat <<'HELP'
usage: scripts/oracle-shared-data-journey.sh [--resume] BASE_BIN OWN_BIN NEW_RUN_ROOT SIGNED_RUNTIME_SPK DATA_SOURCE INVENTORY_JSON

Linux operator account with user systemd/linger, subordinate UID/GID allocation,
passwordless access to deploy/spk-host/install-user-world, bwrap, jq, curl, python3.
BASE_BIN: qualified Host, mini, sqlite-store, signature verifier, client consent.
OWN_BIN: current spk-host, mini-spk-broker, mini-spk-volume-helper, spk-data-publish.
All paths absolute; NEW_RUN_ROOT must have protected ancestors. Without --resume
it must not exist. --resume uses its exact retained Store and prepared receipts.
Creates and removes only a fresh scratch Store namespace. Keeps evidence in RUN.
The input data is read only; publication copies it once into this Store's custody.
No public deployment and no direct fd3 calls. Uses the same current receiving
path as the grain API: event22 share, event28 enrollment and admitted dispatch.
Run inside a bounded operator unit, e.g. RuntimeMaxSec=10800 CPUQuota=200%.
HELP
}
[[ ${1:-} != --help ]] || { usage; exit 0; }
mode=new
if [[ ${1:-} == --resume ]]; then mode=resume; shift; fi
[[ $# == 6 ]] || { usage >&2; exit 2; }
base=$1 own=$2 run=$3 spk=$4 source=$5 inventory=$6
repo=$(cd "$(dirname "$0")/.." && pwd)
journey=$repo/scripts/spk-platform/grain-journey.sh
fail() { echo "Oracle shared-data journey: $*" >&2; exit 1; }
[[ $(uname -s) == Linux ]] || fail 'Linux required'
for path in "$base" "$own" "$run" "$spk" "$source" "$inventory"; do
  [[ $path == /* && $path != *[!a-zA-Z0-9_./-]* && $path != */../* && $path != */./* && $path != *//* ]] || fail "simple absolute canonical path required: $path"
done
if [[ $mode == new ]]; then
  [[ ! -e $run && ! -L $run ]] || fail 'run directory already exists'
else
  [[ -d $run && ! -L $run && $(stat -c '%u:%a' "$run") == "$(id -u):700" ]] || fail 'retained run custody differs'
  [[ -f $run/initial-attempt/input-sha256.txt ]] || fail 'preserve original attempt evidence before resume'
  [[ $(sha256sum "$spk" | cut -d ' ' -f1) == $(awk 'NR==1{print $1}' "$run/initial-attempt/input-sha256.txt") ]] || fail 'resume package differs'
  [[ $(sha256sum "$inventory" | cut -d ' ' -f1) == $(awk 'NR==2{print $1}' "$run/initial-attempt/input-sha256.txt") ]] || fail 'resume inventory differs'
  sha256sum -c "$run/binary-sha256.txt" >"$run/resume-binary-check.txt"
fi
ancestor=$(dirname "$run")
while :; do
  [[ -d $ancestor && ! -L $ancestor ]] || fail "ancestor absent or linked: $ancestor"
  (( (8#$(stat -c '%a' "$ancestor") & 8#022) == 0 )) || fail "writable ancestor: $ancestor"
  [[ $ancestor == / ]] && break
  ancestor=$(dirname "$ancestor")
done
for tool in jq curl python3 sha256sum timeout; do command -v "$tool" >/dev/null || fail "missing $tool"; done
[[ -f $spk && ! -L $spk && -f $inventory && ! -L $inventory && -d $source && ! -L $source ]] || fail 'inputs absent or linked'
[[ $(stat -c '%s' "$spk") -le 268435456 ]] || fail 'runtime exceeds Mini signed package admission cap'
# The publisher, signed package inspector and Mini decide identity/acceptance.
# These are preflight and evidence pins only.
inventory_sha=$(sha256sum "$inventory" | cut -d ' ' -f1)
export SPK=$spk CLASS_A=L CLASS_B=L GET_PATH_A=/health GET_PATH_B=/health
export KIND_A=api KIND_B=api ROLE_BASIS_A='{"type":"role","id":"0"}' ROLE_BASIS_B='{"type":"role","id":"0"}'
export POST_PATH_A=/query POST_PATH_B=/query POST_TYPE_A=application/json POST_TYPE_B=application/json
. "$repo/deploy/oracle/acceptance/world.sh"
configured=0
trap world_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
export ORACLE_IMPORT_PROFILE=${ORACLE_IMPORT_PROFILE:-operator-appliance-v1}
case "$ORACLE_IMPORT_PROFILE" in standard-v1|operator-appliance-v1) ;; *) fail 'unknown operator import profile';; esac
if [[ $mode == new ]]; then
  world_prepare "$base" "$own" "$run" "$repo"
else
  world_resume "$run" "$repo"
fi
jq --argjson bytes "$(stat -c '%s' "$spk")" '
  {selected_profile:(.importProfile // "standard-v1"),
   deadline_seconds:(if .importProfile=="operator-appliance-v1" then 1800 else 120 end),
   signed_spk_bytes:$bytes,mini_raw_admission_cap_bytes:268435456}'   "$GRAINS_ROOT/broker/config.json" >"$run/import-profile.json"
sha256sum "$spk" "$inventory" "$0" "$repo/deploy/oracle/acceptance/world.sh" "$repo/deploy/oracle/acceptance/report.py" >"$run/input-sha256.txt"
cp "$inventory" "$run/inventory.json"
phase() { timeout 1800 "$journey" phase "$run/world" "$@"; }
# Publication is physical custody; it does not manufacture a Mini grant.
timeout 3600 "$BIN/spk-data-publish" publish --store "$GRAINS_ROOT/spk/public-data" \
  --source "$source" --inventory "$inventory" >"$run/publication.json" 2>"$run/publication.stderr"
publication=$GRAINS_ROOT/spk/public-data/sha256-$inventory_sha
[[ -d $publication && ! -L $publication ]] || fail 'publisher did not produce exact inventory slot'
phase birth-a install-a share-a start-a floor-a enroll-a get-a
# This HTTP route invokes the current Mini request admission on every call.
# A process/socket existing is not counted as admission or query success.
request() {
  local letter=$1 label=$2 id=$3 conversation=$4 question=$5
  local body
  body=$(jq -nc --arg id "$id" --arg conversation "$conversation" --arg question "$question" \
    '{request_id:$id,conversation_id:$conversation,text:$question}')
  if [[ $letter == a ]]; then export POST_BODY_A=$body; else export POST_BODY_B=$body; fi
  phase "post-$letter$label"
}
request a 1 oracle-isolation oracle-acceptance 'Who wrote Leaves of Grass?'
request a 2 oracle-austen oracle-followup 'Who wrote Emma?'
request a 3 oracle-pronoun oracle-followup 'When was she born?'
request a 4 oracle-isa oracle-weather 'ISA temperature at 3,000 m altitude?'
request a 5 oracle-bad-units oracle-weather 'ISA temperature at 3,000 m/s altitude?'
request a 9 oracle-mars-supplied oracle-mars 'Earth takes 365.25 days to orbit the Sun and Mars takes 687 days. How many Earth years are 3 Mars years?'
request a 10 oracle-shakespeare oracle-dates 'When was William Shakespeare born?'
request a 11 oracle-salinger oracle-dates 'When was J. D. Salinger born?'
request a 12 oracle-order-salinger oracle-order-salinger 'Who is older, J. D. Salinger or Jimmy Carter?'
request a 13 oracle-order-shakespeare oracle-order-shakespeare 'Who is older, William Shakespeare or Isaac Newton?'
request a 14 oracle-order-uncertain oracle-order-uncertain 'Who is older, Hildegard of Bingen or William Shakespeare?'
phase birth-b install-b share-b start-b floor-b enroll-b get-b
# Reusing both IDs with a different body would conflict in a shared journal.
request b 1 oracle-isolation oracle-acceptance 'Who wrote Emma?'
request a 6 oracle-isolation oracle-acceptance 'Who wrote Leaves of Grass?'
cmp "$run/world/evidence/post-a1-body.body" "$run/world/evidence/post-a6-body.body"
"$BIN/spk-host" grain status "$profile" 9101 >"$run/before-stop-a.json"
"$BIN/spk-host" grain status "$profile" 9201 >"$run/before-stop-b.json"
# Keep the native configs/receipts before the scratch namespace is removed.
mkdir -m 700 "$run/receiving"
retain() {
  local app=$1 generation configfile image_dir
  for configfile in "$state/apps/$app"/g*/resident.json; do
    [[ -f $configfile ]] || continue
    generation=$(basename "$(dirname "$configfile")")
    mkdir -p -m 700 "$run/receiving/$app/$generation"
    cp "$configfile" "$run/receiving/$app/$generation/resident.json"
    for file in "$(dirname "$configfile")"/*completed*.json "$(dirname "$configfile")"/*admitted*.json; do
      [[ ! -f $file ]] || cp "$file" "$run/receiving/$app/$generation/"
    done
  done
  cp "$state/apps/$app/install/launch-descriptor/launch-inspection.json" "$run/receiving/$app/launch-inspection.json"
  cp "$state/apps/$app/install/install-completed-v2.json" "$run/receiving/$app/install-completed-v2.json"
  image_dir=$(jq -er .imageDir "$state/apps/$app/install/install.json")
  cp "$image_dir/import-policy.json" "$run/receiving/$app/import-policy.json"
  cp "$image_dir/root/opt/oracle/APPLIANCE.json" "$run/receiving/$app/APPLIANCE.json"
  cp "$image_dir/root/minidregg-data.json" "$run/receiving/$app/minidregg-data.json"
}
retain 9101; retain 9201
# Native config and Linux mount evidence: inspect only processes in these two
# Store-qualified units. sudo is read-only here, never a mount or app launch.
capture_mounts() {
  local app=$1 unit cg pid resident
  unit=$("$BIN/spk-host" grain status "$profile" "$app" | jq -er '[.runs[] | select(.state=="running")][-1].unit')
  cg=$(systemctl --user show "$unit" -p ControlGroup --value)
  mkdir -p -m 700 "$run/receiving/$app/mounts"
  mkdir -p -m 700 "$run/receiving/$app/namespaces"
  resident=$(systemctl --user show "$unit" -p MainPID --value)
  [[ $resident =~ ^[1-9][0-9]*$ ]] || fail 'running resident PID absent'
  sudo -n cat "/proc/$resident/uid_map" >"$run/receiving/$app/namespaces/$resident.uid_map"
  sudo -n cat "/proc/$resident/gid_map" >"$run/receiving/$app/namespaces/$resident.gid_map"
  while read -r pid; do
    [[ $pid =~ ^[1-9][0-9]*$ ]] || continue
    sudo -n cat "/proc/$pid/mountinfo" >"$run/receiving/$app/mounts/$pid.txt" || fail 'cannot inspect app mount custody'
  done <"/sys/fs/cgroup$cg/cgroup.procs"
}
capture_mounts 9101; capture_mounts 9201
phase stop-a
# These mutations affect only this journey's freshly published directory.
# Rename preserves the original files/inodes/fingerprints exactly for restore.
held=$GRAINS_ROOT/spk/public-data/withheld-$inventory_sha
mv "$publication" "$held"
restore_publication() {
  if [[ -d $held ]]; then
    [[ ! -d $publication ]] || mv "$publication" "$run/wrong-publication"
    mv "$held" "$publication"
  fi
}
# Restore before cleanup even after any negative-test failure.
trap 'original=$?; restore_publication; world_cleanup "$original"' EXIT
refuse_start() {
  local label=$1 result failed_unit invocation
  "$BIN/spk-host" grain status "$profile" 9101 >"$run/$label-before.json"
  set +e
  timeout 120 "$BIN/spk-host" grain start "$profile" 9101 >"$run/$label.stdout" 2>"$run/$label.stderr"
  result=$?
  set -e
  [[ $result != 0 && $result != 124 ]] || fail "$label did not refuse promptly"
  printf '%s\n' "$result" >"$run/$label.exit"
  "$BIN/spk-host" grain status "$profile" 9101 >"$run/$label-after.json"
  jq -e 'all(.runs[]; .state == "stopped" or .state == "never-begun")' "$run/$label-after.json" >/dev/null || fail "$label left live or uncertain lifecycle"
  : >"$run/$label.unit.log"
  while read -r failed_unit; do
    [[ $failed_unit == mini-spk-s$store-a9101-g*.service ]] || fail 'refusal unit outside this Store'
    invocation=$(systemctl --user show "$failed_unit" -p InvocationID --value)
    if [[ $invocation =~ ^[0-9a-f]{32}$ ]]; then
      journalctl --user --no-pager -u "$failed_unit" "_SYSTEMD_INVOCATION_ID=$invocation" >>"$run/$label.unit.log"
    else fail 'failed resident invocation identity absent'; fi
  done < <(jq -r '.runs[] | select(.state=="never-begun") | .unit' "$run/$label-after.json")
  [[ -z $(systemctl --user list-units --state=running --plain --no-legend "mini-spk-s$store-a9101-*.service") ]] || fail "$label launched a resident"
}
refuse_start missing-data
mkdir -m 755 "$publication"
jq '.files[0].sha256 = ("0" * 64)' "$held/inventory.json" >"$publication/inventory.json"
cp "$held/receipt.json" "$publication/receipt.json"
chmod 444 "$publication/inventory.json" "$publication/receipt.json"
mkdir -m 555 "$publication/data"
# Match a real publication's immutable directory modes so this case reaches
# the signed inventory mismatch instead of stopping at a custody-mode refusal.
chmod 555 "$publication"
refuse_start wrong-data
grep -q "published inventory differs from signed attachment digest" "$run/wrong-data.stderr" "$run/wrong-data.unit.log" || fail 'wrong inventory refused for an unrelated reason'
restore_publication
phase start-a2 floor-a2 enroll-a2 get-a2
capture_mounts 9101
request a 7 oracle-isolation oracle-acceptance 'Who wrote Leaves of Grass?'
cmp "$run/world/evidence/post-a1-body.body" "$run/world/evidence/post-a7-body.body"
request a 8 oracle-pronoun oracle-followup 'When was she born?'
cmp "$run/world/evidence/post-a3-body.body" "$run/world/evidence/post-a8-body.body"
request b 2 oracle-isolation oracle-acceptance 'Who wrote Emma?'
cmp "$run/world/evidence/post-b1-body.body" "$run/world/evidence/post-b2-body.body"
retain 9101; retain 9201
phase status-a status-b stop-a2 stop-b
sha256sum -c "$run/input-sha256.txt" >"$run/input-recheck.txt"
if [[ -f $run/resume-retained-install-sha256.txt ]]; then
  sha256sum -c "$run/resume-retained-install-sha256.txt" >"$run/resume-retained-install-recheck.txt"
fi
journalctl --user --no-pager -u "mini-spk-ingest-s$store-*.service" -o json >"$run/import-units.jsonl"
python3 "$repo/deploy/oracle/acceptance/report.py" "$run" "$inventory_sha"
echo "Oracle shared-data acceptance passed: $run/report.json"
