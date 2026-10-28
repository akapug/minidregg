#!/bin/bash
# Internal: one batch, invoked by store-sweep.sh while holding the shared world lock.
set -euo pipefail
umask 077
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}
candidate=$1 out=$2 staging=$3 batch=$4 sha=${1##*/}
here=$(cd "$(dirname "$0")" && pwd)
data=$here/store-sweep-data.py
if [[ ${5:-} == --recover ]]; then
  stage=$batch
  jq -e --arg out "$out" --arg sha "$sha" '.out == $out and .candidate == $sha' "$stage/sweep.json" >/dev/null
else
  # A killed runner cannot execute its EXIT trap. Recover only our own recorded
  # staging, under the same world lock, before making another world.
  for old in "$staging"/b.*; do
    [[ -d $old ]] || continue
    [[ -f $old/sweep.json ]] || { echo "unidentified sweep staging: $old; inspect before continuing" >&2; exit 1; }
    "$0" "$candidate" "$out" "$staging" "$old" --recover
  done
  [[ ${5:-} != --recover-all ]] || exit 0
  stage=$(mktemp -d "$staging/b.XXXXXX")
  jq -n --arg out "$out" --arg sha "$sha" '{out:$out,candidate:$sha}' >"$stage/sweep.json"
fi
printf '%s\n' $$ >"$stage/runner.pid"
world=$stage/w
export MINI_CONSENT_ANCHOR_DIR=$world/w/a
ev=$out/evidence/${stage##*/}
mkdir -p "$ev" "$stage/packages"
[[ ${5:-} == --recover ]] || cp "$batch" "$ev/batch.json"
if [[ ${5:-} != --recover ]]; then
  mkdir -p "$ev/driver"
  cp "$0" "$data" "$here/store-sweep-profile.sh" "$here/world-import-profile.sh" "$here/grain-journey.sh" "$here/world-up.sh" "$here/broker-world-up.sh" "$here/world-down.sh" "$here/stop-residents.sh" "$ev/driver/"
fi
cleanup_attempted=0
cleanup() {
  local rc=0
  [[ $cleanup_attempted == 0 ]] || return 0
  cleanup_attempted=1
  if [[ -f $world/WORLD.env || -f $world/broker-setup/recovery.json ]]; then
    bash "$here/world-down.sh" "$world" >"$ev/world-down.log" 2>&1 || rc=1
  elif [[ -d $world/w ]]; then
    BIN="$candidate/bin" GRAINS_ROOT=/var/lib/mini-spk-worlds/0000000000000000 \
      BROKER_SOCKET=/var/lib/mini-spk-worlds/0000000000000000/runtime-0000000000000000/broker.sock \
      sh "$here/grain-journey.sh" stop-services "$world/w" >"$ev/stop-services.log" 2>&1 || rc=1
  fi
  if [[ -d $world ]]; then
    bash "$here/stop-residents.sh" "$world" >"$ev/stop-residents.log" 2>&1 || rc=1
    if [[ -d $world/w/evidence ]]; then
      mkdir -p "$ev/journey"
      cp -a "$world/w/evidence/." "$ev/journey/" || rc=1
    fi
    for f in "$world"/*.log "$world"/binary-sha256.txt "$world"/WORLD.env; do
      [[ ! -f $f ]] || cp "$f" "$ev/" || rc=1
    done
    if [[ -d $world/broker-setup ]]; then
      mkdir -p "$ev/broker-setup"
      cp -a "$world/broker-setup/." "$ev/broker-setup/" || rc=1
    fi
  fi
  if [[ $rc == 0 ]]; then
    rm -rf -- "$stage" # only this invocation's mktemp directory, after checked teardown
  else
    echo "cleanup failed; retained $stage (see $ev); sweep stops" >&2
  fi
  return "$rc"
}
trap 'rc=$?; trap - EXIT; cleanup || rc=1; exit "$rc"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
if [[ ${5:-} == --recover ]]; then cleanup; exit 0; fi
record() {
  python3 "$data" record "$out" "$sha" "$entry" "$1" "$2" "$3" "$ev" "${profile:-unknown}" "${raw:-0}" "${decoded:-0}"
  printf '%s\t%s\t%s\t%s\n' "$1" "$(jq -r .name <<<"$entry")" "$2" "$3"
}
read -r rawlimit decodedlimit _ < <("$candidate/bin/spk-host" import-limits standard-v1 0)
read -r large_raw large_decoded _ < <("$candidate/bin/spk-host" import-limits market-large-v1 0)
world_profile=standard-v1
: >"$stage/ready.jsonl"
while IFS= read -r entry; do
  id=$(jq -r .packageId <<<"$entry")
  raw=0 decoded=0 profile=unknown
  file=$stage/packages/$id.spk
  # Same fixed public endpoint and SHA-256 prefix as mini-market-fetch. Large intake
  # uses the candidate's published limit, not the fetcher's standard-only ceiling.
  if ! curl --fail --silent --show-error --proto '=https' --tlsv1.2 --noproxy '*' \
      --connect-timeout 20 --max-time 900 --max-filesize "$large_raw" \
      "https://app-index.sandstorm.io/packages/$id" -o "$file" >"$ev/$id-fetch.out" 2>"$ev/$id-fetch.err"; then
    record FAIL fetch "$(tail -c 1000 "$ev/$id-fetch.err")"; continue
  fi
  raw=$(stat -c %s "$file")
  digest=$(sha256sum "$file" | cut -d' ' -f1)
  if [[ $digest != "$id"* ]]; then record FAIL fetch "packageIdMismatch:$digest"; continue; fi
  # SPK is an eight-byte magic followed by XZ. Its index gives an uncompressed-size
  # hint without materialising GB of data; Mini's actual decoder still enforces it.
  tail -c +9 "$file" >"$stage/package.xz"
  if ! xz --robot --list "$stage/package.xz" >"$ev/$id-size.txt" 2>"$ev/$id-size.err"; then
    record FAIL package-size "$(tail -c 1000 "$ev/$id-size.err")"; continue
  fi
  decoded=$(awk '$1=="totals" {print $5}' "$ev/$id-size.txt")
  rm "$stage/package.xz"
  [[ $decoded =~ ^[0-9]+$ ]] || { record FAIL package-size invalid-xz-size; continue; }
  if ((raw > large_raw || decoded > large_decoded)); then record FAIL package-size sizeOverMarketLargeProfile; continue; fi
  profile=$(python3 "$data" profile "$raw" "$decoded" "$rawlimit" "$decodedlimit")
  [[ $profile == standard-v1 ]] || world_profile=market-large-v1
  class=S; ((raw < 64*1024*1024)) || class=M
  [[ $profile == standard-v1 ]] || class=L
  jq -c --arg p "$profile" --arg c "$class" --argjson raw "$raw" --argjson decoded "$decoded" \
    '. + {importProfile:$p,class:$c,rawBytes:$raw,decodedBytes:$decoded}' <<<"$entry" >>"$stage/ready.jsonl"
done < <(jq -c '.[]' "$batch")
[[ -s $stage/ready.jsonl ]] || exit 0
export MINI_IMPORT_PROFILE=$world_profile
printf 'WORLD %s profile=%s %s\n' "$world" "$world_profile" "$(date -u +%FT%TZ)"
if ! bash "$here/world-up.sh" "$candidate/bin" "$candidate/bin" "$world" >"$ev/world-up.log" 2>&1; then
  while IFS= read -r entry; do
    raw=$(jq -r .rawBytes <<<"$entry") decoded=$(jq -r .decodedBytes <<<"$entry") profile=$world_profile
    record FAIL world-up "$(tail -c 1000 "$ev/world-up.log")"
  done <"$stage/ready.jsonl"
  exit 1
fi
# shellcheck source=/dev/null
. "$world/WORLD.env"
PROFILE=${PROFILE:?world profile not set}
export BIN GRAINS_ROOT BROKER_SOCKET
# Native qualification requires root/operator-owned ancestry, which a shared lane
# directory need not have. Probe inside this world's protected intake, before any
# app exists. Its anonymous spools and this temporary copy leave with the world.
initial_profile=$world_profile
: >"$stage/profiled.jsonl"
while IFS= read -r entry; do
  id=$(jq -r .packageId <<<"$entry")
  if [[ $(jq -r .importProfile <<<"$entry") == standard-v1 ]]; then
    probe=$GRAINS_ROOT/spk/sweep-profile-$id.spk
    cp "$stage/packages/$id.spk" "$probe"
    profile=$("$here/store-sweep-profile.sh" "$candidate/bin/spk-host" "$probe" \
      "$(jq -r .rawBytes <<<"$entry")" "$(jq -r .decodedBytes <<<"$entry")" "$ev/$id-profile")
    rm "$probe"
    if [[ $profile == market-large-v1 ]]; then
      world_profile=$profile
      entry=$(jq -c '.importProfile="market-large-v1" | .class="L"' <<<"$entry")
    fi
  fi
  printf '%s\n' "$entry" >>"$stage/profiled.jsonl"
done <"$stage/ready.jsonl"
mv "$stage/profiled.jsonl" "$stage/ready.jsonl"
cp "$stage/ready.jsonl" "$ev/profiles.jsonl"
if [[ $world_profile != "$initial_profile" ]]; then
  "$here/world-import-profile.sh" "$world/WORLD.env" "$world_profile" >"$ev/import-profile.log" 2>&1
  export MINI_IMPORT_PROFILE=$world_profile
fi
while IFS= read -r entry; do
  letter=$(jq -r .letter <<<"$entry") upper=$(tr a-p A-P <<<"$letter")
  id=$(jq -r .packageId <<<"$entry") class=$(jq -r .class <<<"$entry")
  raw=$(jq -r .rawBytes <<<"$entry") decoded=$(jq -r .decodedBytes <<<"$entry") profile=$world_profile
  ok=1
  for phase in birth install share start enroll get; do
    if ! env "SPK_$upper=$stage/packages/$id.spk" "CLASS_$upper=$class" "KIND_$upper=web" \
      "GET_PATH_$upper=/" "ROLE_BASIS_$upper={\"type\":\"allAccess\"}" \
      sh "$here/grain-journey.sh" phase "$RUN" "$phase-$letter" >"$ev/$letter-$phase.out" 2>"$ev/$letter-$phase.err"; then
      detail=$(tail -c 1500 "$RUN/evidence/$phase-$letter.stderr" 2>/dev/null || true)
      [[ -n $detail ]] || detail=$(tail -c 1500 "$ev/$letter-$phase.err")
      record FAIL "$phase" "${detail:-phase failed (see evidence)}"; ok=0; break
    fi
    if [[ $phase == install ]]; then
      app=$(jq -er .app "$RUN/evidence/install-$letter.stdout")
      state=$(jq -er .stateRoot "$PROFILE")
      # This is the native inspection already checked against the signed SPK by
      # descriptor_native; its appId field is the hex of the base32 appId text.
      identity=$state/apps/$app/install/launch-descriptor/package-v1/descriptor-inspection.json
      apphex=$(jq -jr .appId <<<"$entry" | od -An -tx1 | tr -d ' \n')
      if ! cp "$identity" "$ev/$letter-install-identity.json" || ! jq -e --arg id "$apphex" \
        --arg pkg "$id" '.signedAppId == $id and (.rawSha256 | startswith($pkg))' \
        "$ev/$letter-install-identity.json" >/dev/null; then
        record FAIL install 'appIdMismatch: signed installation identity differs from index'; ok=0; break
      fi
    fi
  done
  if [[ $ok == 1 ]]; then
    code=$(tail -1 "$RUN/evidence/get-$letter.stdout")
    if [[ $code =~ ^[23][0-9][0-9]$ ]]; then record PASS get "HTTP $code"; else record FAIL get "HTTP $code"; fi
  fi
  # Free the app's resources before the next app. A start refusal is still cleaned
  # by world-down; failure to stop a successfully started app stops this batch.
  if [[ -f $RUN/evidence/start-$letter.exit && $(cat "$RUN/evidence/start-$letter.exit") == 0 ]]; then
    sh "$here/grain-journey.sh" phase "$RUN" "stop-$letter" >"$ev/$letter-stop.out" 2>"$ev/$letter-stop.err"
  fi
  rm -f "$stage/packages/$id.spk"
done <"$stage/ready.jsonl"
cleanup
