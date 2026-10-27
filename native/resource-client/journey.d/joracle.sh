#!/usr/bin/env bash
# J-ORACLE: the oracle appliance (veri7vn, Oracle7's sibling) lands as a grain through the app
# market's path (docs/ORACLE-GRAIN-2026-10-27.md): the operator publishes the pinned public dataset
# into the world's public-data catalogue, pins the signed runtime SPK as an index entry, adopts the
# package into the quarantine, and a member installs it with `mini apps install`; one bounded
# question is answered on the grain's origin with its evidence; the grain is stopped.
#
#   joracle.sh --box WORLD.env OUT_DIR RUNTIME.spk DATA_SOURCE_DIR INVENTORY.json
#
# WORLD.env is a standing world from scripts/spk-platform/world-up.sh brought up with
# MINI_IMPORT_PROFILE=operator-appliance-v1 (the runtime's 15,155 members need the 1,800 s intake
# budget); its BIN holds mini, spk-host, the broker, the helper and spk-data-publish. The data
# source is the directory the inventory describes (26 files, 15,046,949,326 bytes for v4); the
# publisher copies it once into GRAINS_ROOT/spk/public-data/sha256-<inventory digest>/ and reuses
# an existing exact publication. JORACLE_APP_ID overrides the signed appId the pin names (default:
# the v4 runtime's; a mismatch is the worker's `appIdMismatch`, by name). JORACLE_QUESTION
# overrides the one question (default: Who wrote Leaves of Grass?, answered from the relation store).
#
# Output: one row per check (`PASS|FAIL<TAB>row<TAB>detail`), then `J-ORACLE PASS n/n` or
# `J-ORACLE FAIL k/n` as the last line. Exit 0 only on PASS; 5 when a required input is absent.
# A process this script starts is stopped by the PID in its PID file, and only that (apps-e2e.sh
# stops its worker that way). Nothing here is deleted except this run's own scratch.
set -uo pipefail
umask 077
HERE=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
REPO=$(CDPATH='' cd -- "$HERE/../.." && pwd)
FIXTURE=$HERE/tests/fixtures/sandstorm-index-2026-10-27.json
FETCH=$REPO/deploy/market/mini-market-fetch
E2E=$REPO/scripts/spk-platform/apps-e2e.sh
DEFAULT_APP_ID=ephaf4h4cx8f9s36hmukm4yzkznyhqjhvj8efp3at9cru2zn10mh
rows=0 fails=0
row() { rows=$((rows + 1)); if [ "$2" = 1 ]; then printf 'PASS\t%s\t%s\n' "$1" "$3"; else fails=$((fails + 1)); printf 'FAIL\t%s\t%s\n' "$1" "$3"; fi; }
verdict() { local v="J-ORACLE PASS $rows/$rows"; [ "$fails" = 0 ] || v="J-ORACLE FAIL $fails/$rows"; echo "$v"; echo "$v" >&2; [ "$fails" = 0 ]; }
unconfigured() { echo "UNCONFIGURED: $*" >&2; exit 5; }
[ "${1:-}" = --box ] && [ $# = 6 ] || unconfigured "usage: joracle.sh --box WORLD.env OUT_DIR RUNTIME.spk DATA_SOURCE_DIR INVENTORY.json"
env_file=$2 out=$3 spk=$4 source=$5 inventory=$6
[ "$(uname -s)" = Linux ] || unconfigured "Linux required (the grain path is bwrap and the operator broker)"
for tool in jq curl python3 sha256sum; do command -v "$tool" >/dev/null || unconfigured "missing $tool"; done
[ -f "$env_file" ] || unconfigured "no WORLD.env at $env_file (scripts/spk-platform/world-up.sh)"
# shellcheck disable=SC1090
. "$env_file"
for path in "$out" "$spk" "$source" "$inventory"; do
  [[ $path == /* && $path != *[!a-zA-Z0-9_./-]* ]] || unconfigured "simple absolute path required: $path"
done
[ -f "$spk" ] && [ ! -L "$spk" ] || unconfigured "no runtime package at $spk"
[ -d "$source" ] && [ ! -L "$source" ] || unconfigured "no data source directory at $source"
[ -f "$inventory" ] && [ ! -L "$inventory" ] || unconfigured "no inventory at $inventory"
[ -x "$BIN/mini" ] && [ -x "$BIN/spk-host" ] || unconfigured "the world's BIN lacks mini or spk-host"
[ -x "$BIN/spk-data-publish" ] || unconfigured "the world's BIN lacks spk-data-publish (built from native/spk-host; world-up.sh installs it from OWN_BIN)"
[ ! -e "$out" ] || unconfigured "fresh OUT_DIR required: $out exists"
mkdir -m 700 "$out"
MINI=$BIN/mini

# ---- 1. the world's physical intake budget --------------------------------------------------------
profile=$(jq -r '.importProfile // "standard-v1"' "$GRAINS_ROOT/broker/config.json" 2>/dev/null)
[ "$profile" = operator-appliance-v1 ] || unconfigured "the world's broker selects importProfile $profile; bring the world up with MINI_IMPORT_PROFILE=operator-appliance-v1 (world-up.sh)"
row "the world's broker selects the operator-appliance-v1 import profile (1,800 s intake)" 1 "$GRAINS_ROOT/broker/config.json"

# ---- 2. the package's identity: packageId = the first 16 bytes of its SHA-256 --------------------
sha=$(sha256sum "$spk" | cut -d ' ' -f1); pkg=${sha:0:32}; bytes=$(stat -c %s "$spk")
app_id=${JORACLE_APP_ID:-}
if [ -z "$app_id" ] && [ -x "$BIN/inspect" ]; then
  mkdir -m 700 "$out/inspect-scratch"
  app_id=$("$BIN/inspect" "$spk" "$out/inspect-scratch" standard-v1 2>"$out/inspect.err" | grep -oE '"app_id":"[a-z0-9]{52}"' | head -1 | cut -d'"' -f4)
fi
app_id=${app_id:-$DEFAULT_APP_ID}
row "the runtime package is within the standard raw bound and names packageId $pkg" "$([ "$bytes" -le 268435456 ] && echo 1 || echo 0)" "sha256=$sha bytes=$bytes appId=$app_id"

# ---- 3. the public dataset, published once into this world's catalogue ---------------------------
inv_sha=$(sha256sum "$inventory" | cut -d ' ' -f1)
store=$GRAINS_ROOT/spk/public-data
pub=$(timeout 3600 "$BIN/spk-data-publish" publish --store "$store" --source "$source" --inventory "$inventory" 2>"$out/publish.err"); rc=$?
printf '%s\n' "$pub" >"$out/publication.json"
ok=0; [ "$rc" = 0 ] && grep -q "\"inventory_sha256\":\"$inv_sha\"" <<<"$pub" && ok=1
row "spk-data-publish publishes the dataset under sha256-$inv_sha (reused when already there)" "$ok" "$(if [ "$rc" = 0 ]; then jq -r '"\(.file_count) files, \(.total_bytes) bytes, reused=\(.reused)"' <<<"$pub"; else tail -1 "$out/publish.err" | cut -c1-160; fi)"
[ "$ok" = 1 ] || { verdict; exit 1; }

# ---- 4. the pin: an operator-local index entry, merged by index-check ----------------------------
jq -n --arg app "$app_id" --arg pkg "$pkg" --arg sha "$sha" '{apps:[{
  appId:$app, packageId:$pkg, name:"veri7vn oracle", version:"4", versionNumber:4,
  author:{name:"ember (local candidate signing identity)"}, upstreamAuthor:"psiloceyeben (Oracle7), veri7vn",
  shortDescription:"Answers questions with evidence: 145 specialists and 161 relation readers over a pinned public dataset; machine-checked kernels where the path names one",
  categories:["Science","Reference"], webLink:"https://huggingface.co/psiloceyeben/oracle7", codeLink:"https://github.com/emberian/minidregg/tree/main/deploy/oracle",
  createdAt:"2026-10-27T03:00:00Z", isOpenSource:true, sha256:$sha, class:"L"}]}' >"$out/local.json"
check=$("$MINI" apps index-check --in "$FIXTURE" --out "$out/index.json" --local "$out/local.json" 2>&1); rc=$?
row "index-check merges the pinned oracle entry into the catalogue (fixture 98 + 1 pinned)" "$([ "$rc" = 0 ] && grep -q '99 apps (1 pinned)' <<<"$check" && echo 1 || echo 0)" "$check"
shown=$("$MINI" apps show --index "$out/index.json" --app "$pkg" --json 2>&1)
row "apps show names the pin: class L, sha256, adopted from a box-local file" "$(grep -q '"suggestedClass": "L"' <<<"$shown" && grep -q "\"sha256\": \"$sha\"" <<<"$shown" && grep -q 'file: adopted' <<<"$shown" && echo 1 || echo 0)" "$(grep -oE '"(suggestedClass|packageUrl)": "[^"]*"' <<<"$shown" | tr '\n' ' ' | cut -c1-160)"

# ---- 5. adopt the package into a quarantine through the fetcher's checks -------------------------
mkdir -m 750 "$out/market"
cp "$out/index.json" "$out/market/index.json"
adopted=$(bash "$FETCH" --state "$out/market" --mini "$MINI" adopt "$pkg" "$sha" "$spk" 2>&1); rc=$?
row "mini-market-fetch adopt: the pinned bytes land in the quarantine with their meta" "$([ "$rc" = 0 ] && [ -f "$out/market/quarantine/$pkg.spk" ] && grep -q "\"sha256\":\"$sha\"" "$out/market/meta/$pkg.json" && echo 1 || echo 0)" "$(tail -1 <<<"$adopted" | cut -c1-160)"
wrong=$(bash "$FETCH" --state "$out/market" --mini "$MINI" fetch "$pkg" 2>&1); rc=$?
row "a fetch of the pinned id verifies the quarantine copy against the pin instead of downloading" "$([ "$rc" = 0 ] && grep -q "^verified $pkg sha256=$sha" <<<"$wrong" && echo 1 || echo 0)" "$(tail -1 <<<"$wrong" | cut -c1-120)"

# ---- 6. the member turn: mini apps install, start, one question, stop ----------------------------
question=${JORACLE_QUESTION:-Who wrote Leaves of Grass?}
jq -n --arg q "$question" '{request_id:"joracle-1",conversation_id:"joracle",text:$q}' >"$out/question.json"
APPS_E2E_INDEX=$out/index.json APPS_E2E_CLASS=L APPS_E2E_ATTEMPTS=130 APPS_E2E_GET_PATH=/health \
  APPS_E2E_POST="/query|application/json|$out/question.json" APPS_E2E_STOP=1 MINI_MARKET_CACHE=$out/market/quarantine \
  bash "$E2E" "$env_file" "$out/e2e" "$pkg" >"$out/e2e.out" 2>"$out/e2e.err"; e2e_rc=$?
while IFS=$'\t' read -r status name detail; do
  case $status in PASS) row "e2e: $name" 1 "$detail" ;; FAIL) row "e2e: $name" 0 "$detail" ;; esac
done < <(grep -E $'^(PASS|FAIL)\t' "$out/e2e.out")
row "apps-e2e.sh completed its rows" "$([ "$e2e_rc" = 0 ] && echo 1 || echo 0)" "$(tail -1 "$out/e2e.out") $(tail -1 "$out/e2e.err" | cut -c1-120)"

# ---- 7. the answer carries its evidence --------------------------------------------------------
body=$(ls "$out"/e2e/a*.post.body 2>/dev/null | head -1)
if [ -n "$body" ] && jq -e . "$body" >/dev/null 2>&1; then
  cp "$body" "$out/answer.json"
  completed=$(jq -r '.outcome' "$body"); status=$(jq -r '.reply.status' "$body"); response=$(jq -r '.reply.response // ""' "$body")
  refs=$(jq -r '.reply.references | length' "$body"); rpath=$(jq -r '.reply.path // ""' "$body"); lm=$(jq -r '.reply.zero_model_gate.lm_calls // "?"' "$body")
  licensed=$(jq -r '.reply.evidential.answer_licensed // "?"' "$body")
  row "the reply is a completed, answered oracle turn" "$([ "$completed" = completed ] && [ "$status" = answered ] && echo 1 || echo 0)" "outcome=$completed status=$status"
  row "the answer names its route and its references (the evidence the page shows), with zero model calls" "$([ -n "$rpath" ] && [ "$refs" -gt 0 ] && [ "$lm" = 0 ] && echo 1 || echo 0)" "path=$(cut -c1-80 <<<"$rpath") references=$refs lm_calls=$lm answer_licensed=$licensed"
  expect=${JORACLE_EXPECT:-Whitman}
  row "the answer to '$question' names $expect" "$(grep -q "$expect" <<<"$response" && echo 1 || echo 0)" "$(cut -c1-140 <<<"$response")"
else
  row "the oracle answered the one question through the grain's route" 0 "no JSON reply body under $out/e2e"
fi
# The grain read the published dataset: the relation store is the only place this answer's wd: references live.
if [ -f "$out/answer.json" ]; then
  row "the references come from the relation store on the shared read-only dataset (wd: ids)" "$(jq -e '.reply.references | any(startswith("wd:"))' "$out/answer.json" >/dev/null 2>&1 && echo 1 || echo 0)" "$(jq -c '.reply.references' "$out/answer.json" | cut -c1-120)"
fi
verdict
