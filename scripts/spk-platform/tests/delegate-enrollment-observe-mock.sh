#!/bin/sh
# Source-shaped transport fixture only: no Mini Store and no native admission claim.
set -eu
umask 077
here=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d /var/lib/minidregg/spk/fixtures/mini-enrollment-observe-scratch-XXXXXX)
trap 'kill "$listener" 2>/dev/null || :; rm -rf "$scratch"' EXIT
mkdir -m 700 "$scratch/source-stage" "$scratch/continuations" \
  "$scratch/base" "$scratch/base/workroom" "$scratch/base/workroom/deployment"
mkdir -m 700 "$scratch/base/workroom/agents" \
  "$scratch/base/workroom/agents/hermes-a" "$scratch/base/workroom/agents/hermes-b"
cp "$here/allocation-v1.json" "$scratch/source-stage/agent-allocation.json"
printf '{}\n' >"$scratch/base/workroom/deployment/pinned-config.json"
for key in tool member agents/hermes-a/controller agents/hermes-b/controller; do
  printf 'scratch key\n' >"$scratch/base/workroom/$key.key"
done
cp "$here/prepare-enrollment-observe-overlay.sh" "$scratch/overlay-tool.sh"
cp "$here/delegate-enrollment-observe.sh" "$scratch/delegate-tool.sh"
sed -i "s@\$(dirname \"\$0\")/prepare-enrollment-observe-overlay.sh@$scratch/overlay-tool.sh@" \
  "$scratch/delegate-tool.sh"
chmod 700 "$scratch/overlay-tool.sh" "$scratch/delegate-tool.sh"
sh "$scratch/overlay-tool.sh" "$scratch" "$scratch/continuations/overlay.json" >/dev/null
test "$(jq -r '.grants | length' "$scratch/continuations/overlay.json")" = 11

cat >"$scratch/mock-host" <<'HOST'
#!/bin/sh
case "$2:$3" in
  inspect:view-object-capability)
    cap=$(cat "$4")
    case "$cap" in
      143) holder=8; verbs='["observe","delegate"]' ;;
      275) holder=10; verbs='["observe"]' ;;
      171) holder=8; verbs='["observe","delegate"]' ;;
      173) holder=8; verbs='["observe"]' ;;
      *) exit 2 ;;
    esac
    case "$cap" in 171|173) target=8500 ;; *) target=8402 ;; esac
    jq -n --arg cap "$cap" --arg holder "$holder" --argjson verbs "$verbs" \
      --arg target "$target" \
      '{kind:"object",head:{id:$cap,holder:{type:"subject",subject:$holder},
       targets:[$target],verbs:$verbs,ancestors:[],notBefore:"0",notAfter:"100000"}}' >"$5" ;;
  *) exit 2 ;;
esac
HOST
cat >"$scratch/mock-mini" <<'MINI'
#!/bin/sh
cmd=$1; shift
intent= dir= view= mode=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --intent) intent=$2; shift 2 ;;
    --dir|--attempt) dir=$2; shift 2 ;;
    --view) view=$2; shift 2 ;;
    --mode) mode=$2; shift 2 ;;
    *) shift ;;
  esac
done
case "$cmd:$mode" in
  query:)
    mkdir -m 700 "$dir"
    cap=$(jq -r '.grants[0].capability' "$intent")
    printf '%s\n' "$cap" >"$dir/view.bin"
    printf '{"domain":"1","semantics":"2","imageBoundary":"3","signing":[{"authorityRoot":"4"}]}\n' >"$dir/challenge.json"
    printf '{"page":{"root":"5"}}\n' >"$dir/view.json" ;;
  submit:)
    mkdir -m 700 "$dir"
    printf 'one exact call\n' >"$dir/call.bin" ;;
  retry:submit)
    printf '{"type":"confirmed","confirmation":"installed","transactionId":"1","eventId":"2","acceptedCount":"3","imageBoundary":"4"}\n' >"$dir/retry-0000.json" ;;
  retry:lookup)
    printf '{"type":"confirmed","confirmation":"replayed","transactionId":"1","eventId":"2","acceptedCount":"3","imageBoundary":"4"}\n' >"$dir/retry-0001.json" ;;
  *) exit 2 ;;
esac
MINI
chmod 700 "$scratch/mock-host" "$scratch/mock-mini"
socket=$scratch/operator.sock
nc -lU "$socket" >/dev/null 2>&1 & listener=$!
index=0
while [ ! -S "$socket" ]; do
  index=$((index + 1)); [ "$index" -lt 100 ] || exit 1
  sleep 0.01
done
host_sha=$(sha256sum "$scratch/mock-host" | cut -d ' ' -f 1)
mini_sha=$(sha256sum "$scratch/mock-mini" | cut -d ' ' -f 1)
attempt=$scratch/continuations/hermes-a-manifest
sh "$scratch/delegate-tool.sh" prepare "$scratch" "$scratch/mock-host" \
  "$scratch/base/workroom/deployment/pinned-config.json" "$scratch/mock-mini" \
  "$socket" "$scratch/continuations/overlay.json" \
  hermes-a manifest - "$attempt" "$host_sha" "$mini_sha" >/dev/null
test -s "$attempt/native/call.bin"
if sh "$scratch/delegate-tool.sh" lookup "$attempt" >/dev/null 2>&1; then
  echo 'lookup without send marker accepted' >&2; exit 1
fi
sh "$scratch/delegate-tool.sh" send "$attempt" >/dev/null
if sh "$scratch/delegate-tool.sh" send "$attempt" >/dev/null 2>&1; then
  echo 'second send accepted' >&2; exit 1
fi
printf 'interrupted candidate\n' >"$attempt/confirmed-candidate-stale.json"
sh "$scratch/delegate-tool.sh" lookup "$attempt" >/dev/null
jq -e '.receipt == {transactionId:"1",eventId:"2",acceptedCount:"3",imageBoundary:"4"}' \
  "$attempt/confirmed.json" >/dev/null
jq -e '.head.id == "275" and .head.holder.subject == "10" and .head.verbs == ["observe"]' \
  "$attempt/child-inspected.json" >/dev/null
sh "$scratch/delegate-tool.sh" lookup "$attempt" >/dev/null
rm "$attempt/child-inspected.json"
printf 'partial inspector output\n' >"$attempt/child-inspected-0001.json"
sh "$scratch/delegate-tool.sh" lookup "$attempt" >/dev/null
jq -e '.head.id == "275"' "$attempt/child-inspected.json" >/dev/null
printf 'corrupt cached readback\n' >"$attempt/child-inspected.json"
if sh "$scratch/delegate-tool.sh" lookup "$attempt" >/dev/null 2>&1; then
  echo 'corrupt cached child readback accepted' >&2; exit 1
fi
stage=$scratch/continuations/alice-ticket-stage
mkdir -m 700 "$stage" "$stage/issue"
printf 'same plan\n' >"$stage/preview-plan.bin"
cp "$stage/preview-plan.bin" "$stage/issue/plan.bin"
printf '%s\n' '{"type":"application-grain-share-issue-plan-v1","request":{"spec":{"ticket":{"resource":"8500","participant":{"subject":"8","ticketObserveCapability":"173"}},"ticketOwnerCapability":"171"}}}' >"$stage/preview-plan.json"
printf '%s\n' '{"type":"minidregg-grain-share-issue-receipt-anchor-v1","receipt":{"acceptedCount":"9"}}' >"$stage/issue/receipt-anchor.json"
sh "$scratch/delegate-tool.sh" prepare "$scratch" "$scratch/mock-host" \
  "$scratch/base/workroom/deployment/pinned-config.json" "$scratch/mock-mini" \
  "$socket" "$scratch/continuations/overlay.json" \
  alice-web ticket "$stage" "$scratch/continuations/alice-ticket-delegate" \
  "$host_sha" "$mini_sha" >/dev/null
test -s "$scratch/continuations/alice-ticket-delegate/native/call.bin"
printf 'changed plan\n' >"$stage/issue/plan.bin"
if sh "$scratch/delegate-tool.sh" send "$scratch/continuations/alice-ticket-delegate" \
  >/dev/null 2>&1; then
  echo 'changed accepted event22 plan allowed send' >&2; exit 1
fi
test ! -e "$scratch/continuations/alice-ticket-delegate/send-requested.json"
if sh "$scratch/delegate-tool.sh" prepare "$scratch" "$scratch/mock-host" \
  "$scratch/base/workroom/deployment/pinned-config.json" "$scratch/mock-mini" \
  "$socket" "$scratch/continuations/overlay.json" \
  alice-web ticket "$stage" "$scratch/continuations/tampered-ticket" \
  "$host_sha" "$mini_sha" >/dev/null 2>&1; then
  echo 'changed accepted event22 plan accepted' >&2; exit 1
fi
jq '.grants[8].childCapability = "999"' "$scratch/continuations/overlay.json" \
  >"$scratch/continuations/tampered.json"
if sh "$scratch/delegate-tool.sh" prepare "$scratch" "$scratch/mock-host" \
  "$scratch/base/workroom/deployment/pinned-config.json" "$scratch/mock-mini" \
  "$socket" "$scratch/continuations/tampered.json" \
  hermes-a manifest - "$scratch/continuations/refused" "$host_sha" "$mini_sha" \
  >/dev/null 2>&1; then
  echo 'altered overlay accepted' >&2; exit 1
fi
test ! -e "$scratch/continuations/refused/native"
echo 'schema mock PASS: one send, exact lookup/readback, tampered overlay refused'
