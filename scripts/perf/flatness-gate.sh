#!/usr/bin/env bash
# Candidate gate entry: both receiving paths, even when the first one fails.
# flatness-gate.sh CANDIDATE NEW_ROOT [N=1000] [LO=10]
# Writes gate.tsv in the integrator's NAME<TAB>VERDICT<TAB>DETAIL convention.
# A broken/missing measurement is FAIL, never skipped or a successful empty run.
set -uo pipefail
umask 077
[[ $# -ge 2 && $# -le 4 ]] || { echo "usage: $0 CANDIDATE NEW_ROOT [N] [LO]" >&2; exit 2; }
candidate=$(realpath "$1"); root=$(realpath -m "$2"); n=${3:-1000}; lo=${4:-10}
here=$(cd "$(dirname "$0")" && pwd)
repo=${FLATNESS_SOURCE:-$(cd "$here/../.." && pwd)}
[[ ! -e $root ]] || { echo 'flatness gate requires a fresh root' >&2; exit 2; }
mkdir -m 700 "$root" || exit 2
# Publish pessimistic rows before starting: interrupted runs cannot leave a green gate.
printf 'flatness-submit\tFAIL\tnot completed\nflatness-get\tFAIL\tnot completed\n' >"$root/gate.tsv"
sha256sum "$candidate/SHA256SUMS" >"$root/candidate.sha256" || exit 2
(cd "$candidate" && sha256sum -c SHA256SUMS) >"$root/verify-candidate.log" 2>&1 || exit 2
python3 "$here/test_flatness.py" >"$root/self-test.log" 2>&1 || exit 2
python3 "$here/flatness-bench.py" --bin "$candidate/bin" --root "$root/submit" \
  --src "$repo" --n "$n" --lo "$lo" >"$root/submit.log" 2>&1 &
echo $! >"$root/submit.pid"; wait "$(cat "$root/submit.pid")"; submit=$?
bash "$here/flatness-route.sh" "$candidate" "$root/get" "$n" "$lo" >"$root/get.log" 2>&1 &
echo $! >"$root/get.pid"; wait "$(cat "$root/get.pid")"; get=$?
# Zero exit alone is insufficient: all named metrics and every requested turn
# must have a passing result. An early FAIL keeps its measured failure code.
result_passes() {
  python3 - "$1" "$n" "$lo" "$2" <<'PYRESULT'
import json, sys
r = json.load(open(sys.argv[1]))
if not (r['verdict'] == 'PASS' and r['n'] == int(sys.argv[2]) and r['lo'] == int(sys.argv[3])
        and all(r['metrics'][m]['verdict'] == 'PASS' for m in sys.argv[4].split())):
    sys.exit('missing complete passing flatness result')
PYRESULT
}
if [[ $submit == 0 ]]; then
  result_passes "$root/submit/result.json" 'submit_cpu_ms submit_wall_ms propose_cpu_ms propose_wall_ms' || submit=2
fi
if [[ $get == 0 ]]; then
  result_passes "$root/get/measure/result.json" 'get_cpu_ms get_wall_ms' || get=2
fi
printf 'flatness-submit\t%s\trc=%s; %s/submit.log\nflatness-get\t%s\trc=%s; %s/get.log\n' \
  "$([[ $submit == 0 ]] && echo PASS || echo FAIL)" "$submit" "$root" \
  "$([[ $get == 0 ]] && echo PASS || echo FAIL)" "$get" "$root" >"$root/gate.tsv.new"
mv "$root/gate.tsv.new" "$root/gate.tsv"
cat "$root/gate.tsv"
[[ $submit == 0 && $get == 0 ]]
