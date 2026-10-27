#!/usr/bin/env bash
# The Objective invocation policy a world's genesis pins (`objectiveInvocation` in genesis-params),
# authored by the SHIPPED Host: the policy names that Host's own Lean front end and generic codec, so
# it is made at genesis from the candidate's binary, never committed as a constant. The numbers
# (maximum envelope, source bound, tariff) are native/resource-client/activity_world.py's, the same
# policy every activity journey world pins (`policy_of`).
#
#   scripts/author-objective-policy.sh HOST OUT.hex
#       prints the hex (also written to OUT.hex) and `sha256 <digest of the hex>` on stderr
#   scripts/author-objective-policy.sh --check HOST GENESIS-PARAMS.json
#       0 when the file's .objectiveInvocation equals the policy HOST authors now; 1 (with both
#       digests) when it differs or is absent
#
# Without this pin the Host refuses every activity turn (ops 210-214) on the world: the `bend` verb
# and every Objective program need it.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
check=0
if [[ ${1:-} == --check ]]; then check=1; shift; fi
[[ $# == 2 ]] || { sed -n '2,17p' "$0" >&2; exit 2; }
host=$1 target=$2
[[ -x $host ]] || { echo "author-objective-policy: $host is not executable" >&2; exit 2; }
tmp=$(mktemp -d "${TMPDIR:-/tmp}/objective-policy.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
"$host" /dev/null objective-constants >"$tmp/constants.json"
python3 -I - "$here/native/resource-client" "$tmp/constants.json" "$tmp/policy.json" <<'PY'
import json, sys
sys.path.insert(0, sys.argv[1])
from activity_world import policy_of
constants = json.load(open(sys.argv[2]))
json.dump(policy_of(constants), open(sys.argv[3], 'w'), indent=1)
PY
"$host" /dev/null author objective-policy "$tmp/policy.json" "$tmp/policy.hex" >/dev/null
hex=$(tr -d ' \n' <"$tmp/policy.hex")
sha() { printf '%s' "$1" | { sha256sum 2>/dev/null || shasum -a 256; } | cut -d' ' -f1; }
if [[ $check == 1 ]]; then
  have=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1])).get("objectiveInvocation") or "")' "$target")
  if [[ $have == "$hex" ]]; then echo "objectiveInvocation OK: authored by $host (sha256 $(sha "$hex"))"; exit 0; fi
  if [[ -z $have ]]; then echo "objectiveInvocation ABSENT in $target (want sha256 $(sha "$hex"))"; exit 1; fi
  echo "objectiveInvocation DIFFERS: file sha256 $(sha "$have"), $host authors sha256 $(sha "$hex")"; exit 1
fi
printf '%s\n' "$hex" >"$target"
printf '%s\n' "$hex"
echo "sha256 $(sha "$hex")" >&2
