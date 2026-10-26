#!/bin/sh
# Event28 initial-enrollment gate on a COPY of a quiet, accepted serving Store.
# Input snapshot must already contain an admitted matching event22 ticket and
# actual participant app/manifest/ticket observe grants. The older birth-only
# fixtures cannot satisfy op82 and are deliberately refused.
set -eu
umask 077

fail() { echo "session enrollment acceptance: $*" >&2; exit 2; }
sha() { sha256sum "$1" | cut -d ' ' -f 1; }
[ "$#" -eq 5 ] || fail "usage: $0 HOST MINI STORE_BINARY QUIET_SNAPSHOT NEW_EVIDENCE"
host=$1 mini=$2 store_binary=$3 snapshot=$4 evidence=$5
for path in "$host" "$mini" "$store_binary" "$snapshot" "$evidence"; do
  case "$path" in /*) ;; *) fail "absolute paths required" ;; esac
done
for path in "$host" "$mini" "$store_binary"; do [ -x "$path" ] || fail "binary missing: $path"; done
[ -d "$snapshot" ] && [ ! -L "$snapshot" ] && [ ! -e "$evidence" ] || fail "snapshot absent or evidence exists"
# Never use the retained integrated r3 tree as the input to this fixture.
case "$snapshot" in /var/lib/minidregg/spk/fixtures/gitweb-v2-20260927-client-session-r3/*)
  fail "copy the quiet serving Store into a separate staging snapshot first" ;; esac
for name in config.json request.json keys.json; do
  [ -f "$snapshot/$name" ] && [ ! -L "$snapshot/$name" ] || fail "missing $name"
done
[ -d "$snapshot/store" ] && [ ! -L "$snapshot/store" ] || fail "missing snapshot Store"
command -v jq >/dev/null || fail "jq required"
command -v xxd >/dev/null || fail "xxd required"
mkdir -m 700 "$evidence"
evidence=$(CDPATH='' cd -- "$evidence" && pwd)
cp -a "$snapshot/store" "$evidence/store"
cp "$snapshot/config.json" "$evidence/source-config.json"
cp "$snapshot/request.json" "$evidence/request.json"
cp "$snapshot/keys.json" "$evidence/keys.json"
chmod 600 "$evidence"/*.json
src_root=$(jq -er '.storageRoot' "$evidence/source-config.json")
[ "$src_root" = "$snapshot/store" ] || fail "source config does not name exact snapshot Store"
jq --arg root "$evidence/store" '.storageRoot=$root' \
  "$evidence/source-config.json" >"$evidence/config.json"
chmod 600 "$evidence/config.json"
sha "$evidence/source-config.json" >"$evidence/source-config.sha256"
sha "$evidence/request.json" >"$evidence/request.sha256"
sha "$evidence/keys.json" >"$evidence/keys.sha256"
"$store_binary" read-to "$evidence/store" "$evidence/before-image.bin"
sha "$evidence/before-image.bin" >"$evidence/before-image.sha256"

socket="$evidence/operator/mini.sock"
mkdir -m 700 "$evidence/operator"
pid=
cleanup() {
  if [ -n "$pid" ]; then kill "$pid" 2>/dev/null || :; wait "$pid" 2>/dev/null || :; fi
}
trap cleanup EXIT HUP INT TERM
"$mini" serve-operator --host "$host" --config "$evidence/config.json" \
  --socket "$socket" >"$evidence/operator/stdout" 2>"$evidence/operator/stderr" &
pid=$!
tick=0
until [ -S "$socket" ]; do
  kill -0 "$pid" 2>/dev/null || fail "operator service exited"
  tick=$((tick + 1)); [ "$tick" -lt 120 ] || fail "operator service did not open"
  sleep 1
done

# A source plan is the precondition witness: it reselects the exact event22
# issue and actual current serving app, installed manifest, and ticket.
"$mini" session-enrollment-plan --host "$host" --config "$evidence/config.json" \
  --operator-socket "$socket" --request "$evidence/request.json" \
  --dir "$evidence/initial" >"$evidence/initial-plan.stdout"
jq -e --slurpfile request "$evidence/initial/request-inspected.json" '
  .type == "application-session-enrollment-plan-v1" and
  .request == $request[0] and .previousAtomHex == null and
  (.slots | length >= 4 and length <= 16) and
  all(.slots[]; .signing.decoded == true and (.headerHex | length > 0))
' "$evidence/initial/plan-inspected.json" >/dev/null || fail "source plan is not initial enrollment"

# Negative probes are pre-sign and must leave the copied Store unchanged.
issue=$(jq -er '.issueIndex | tonumber' "$evidence/request.json")
jq --arg issue "$((issue + 1000000))" '.issueIndex=$issue' \
  "$evidence/request.json" >"$evidence/wrong-issue.json"
if "$mini" session-enrollment-plan --host "$host" --config "$evidence/config.json" \
    --operator-socket "$socket" --request "$evidence/wrong-issue.json" \
    --dir "$evidence/wrong-issue" >"$evidence/wrong-issue.stdout" \
    2>"$evidence/wrong-issue.stderr"; then
  fail "wrong issue index produced a plan"
fi
[ ! -f "$evidence/wrong-issue/plan.bin" ] || fail "wrong issue retained a plan"
jq '.role.basis={type:"allAccess"}' "$evidence/request.json" >"$evidence/over-ceiling.json"
if "$mini" session-enrollment-plan --host "$host" --config "$evidence/config.json" \
    --operator-socket "$socket" --request "$evidence/over-ceiling.json" \
    --dir "$evidence/over-ceiling" >"$evidence/over-ceiling.stdout" \
    2>"$evidence/over-ceiling.stderr"; then
  fail "all-access role exceeded the fixture's bounded ticket ceiling"
fi
[ ! -f "$evidence/over-ceiling/plan.bin" ] || fail "over-ceiling retained a plan"
"$store_binary" read-to "$evidence/store" "$evidence/after-refusals.bin"
cmp -s "$evidence/before-image.bin" "$evidence/after-refusals.bin" || fail "refusal changed Store image"

# The key map is custody input, not source authority. Every ordered slot's
# decoded key ID/epoch and exact header hash are checked again by the client.
jq -e 'type == "array" and all(.[]; (.keyId|type)=="string" and
  (.keyEpoch|type)=="string" and (.keyPath|type)=="string" and
  (.publicPath|type)=="string")' "$evidence/keys.json" >/dev/null || fail "key map shape"
: >"$evidence/signers.ndjson"
count=$(jq -er '.slots | length' "$evidence/initial/plan-inspected.json")
index=0
while [ "$index" -lt "$count" ]; do
  slot=$(jq -cer --argjson i "$index" '.slots[$i]' "$evidence/initial/plan-inspected.json")
  key_id=$(printf '%s\n' "$slot" | jq -er '.signing.keyId')
  key_epoch=$(printf '%s\n' "$slot" | jq -er '.signing.keyEpoch')
  mapping=$(jq -cer --arg id "$key_id" --arg epoch "$key_epoch" \
    '[.[] | select(.keyId==$id and .keyEpoch==$epoch)] |
     if length == 1 then .[0] else error("missing or ambiguous signer") end' \
    "$evidence/keys.json") || fail "slot signer not uniquely mapped"
  key_path=$(printf '%s\n' "$mapping" | jq -er '.keyPath')
  public_path=$(printf '%s\n' "$mapping" | jq -er '.publicPath')
  [ -f "$key_path" ] && [ -f "$public_path" ] || fail "signer files missing"
  public=$(od -An -tx1 -v "$public_path" | tr -d ' \n')
  header=$(printf '%s\n' "$slot" | jq -er '.headerHex')
  header_sha=$(printf '%s' "$header" | xxd -r -p | sha256sum | cut -d ' ' -f 1)
  printf '%s\n' "$slot" | jq -c --arg public "$public" --arg headerSha "$header_sha" \
    --arg keyPath "$key_path" \
    '{role,index,keyId:.signing.keyId,keyEpoch:.signing.keyEpoch,
      publicKey:$public,headerSha256:$headerSha,keyPath:$keyPath}' \
    >>"$evidence/signers.ndjson"
  index=$((index + 1))
done
request_sha=$(sha "$evidence/initial/request.bin")
plan_sha=$(sha "$evidence/initial/plan.bin")
inspection_sha=$(sha "$evidence/initial/plan-inspected.json")
jq -s --arg request "$request_sha" --arg plan "$plan_sha" \
  --arg inspection "$inspection_sha" \
  '{type:"minidregg-session-enrollment-approval-v1",requestSha256:$request,
    planSha256:$plan,planInspectionSha256:$inspection,signers:.}' \
  "$evidence/signers.ndjson" >"$evidence/approval.json"
"$mini" session-enrollment-seal --attempt "$evidence/initial" \
  --approval "$evidence/approval.json" >"$evidence/initial-seal.stdout"
"$mini" session-enrollment-submit --attempt "$evidence/initial" \
  >"$evidence/initial-submit.stdout"
jq -e '.type == "confirmed" and .confirmation == "installed"' \
  "$evidence/initial/submit.outcome.json" >/dev/null || fail "initial enrollment not freshly installed"
"$mini" session-enrollment-lookup --attempt "$evidence/initial" \
  >"$evidence/initial-lookup.stdout"
jq -e --slurpfile receipt "$evidence/initial/receipt.json" '
  .type == "confirmed" and .confirmation == "replayed" and
  .transactionId == $receipt[0].transactionId and
  .eventId == $receipt[0].eventId and
  .acceptedCount == $receipt[0].acceptedCount and
  .imageBoundary == $receipt[0].imageBoundary
' "$evidence/initial/lookup-0000.outcome.json" >/dev/null || fail "original receipt lookup differs"
"$store_binary" read-to "$evidence/store" "$evidence/after-lookup.bin"
"$mini" session-enrollment-lookup --attempt "$evidence/initial" \
  >"$evidence/initial-lookup-again.stdout"
"$store_binary" read-to "$evidence/store" "$evidence/after-lookup-again.bin"
cmp -s "$evidence/after-lookup.bin" "$evidence/after-lookup-again.bin" || fail "lookup changed Store"
printf '%s\n' 'PASS copied serving Store: initial event28 installed, exact receipt replayed, refusal and lookup images stable'
