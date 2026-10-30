#!/usr/bin/env bash
# world-native-admit.sh DOMAIN [--entry NAME] [--method FILE.obend] [--candidate DIR] [world flags...]
#
# Run a world/ domain's method through the NATIVE Objective path on a scratch Store:
# world -> publish -> invoke -> readback (native/resource-client/objective-native-acceptance.py),
# against a candidate's binaries. The driver must come from a tree at that candidate's commit
# (its genesis params and the candidate's binaries must agree), so run this from such a worktree
# or set SRC. Each step's refusal is recorded by name, never retried or adapted around.
#
#   --entry NAME     the published entry definition (default: note, the native entry contract)
#   --method FILE    default: the one .obend directly under world/DOMAIN/
#   --candidate DIR  a /build/candidates/<sha> directory (default: newest); its bin/ is --bin
#   other flags      passed to the driver's `world` step (--tariff-replay N --tariff-core N
#                    --maximum KEY=N --sponsor-balance N)
# ACTIVITY ROUTE: `--route activity [--scenario tally] --birth-input JSON --deposit N` runs
# native/resource-client/world-activity-admit.py instead (publish, create, birth, read back, scenario turns).
# Transcript: docs/evidence/2026-10-27-world-native/DOMAIN/ (verdicts.txt plus the driver's
# transcript/ and results/). Linux only (the Store and Host run there); run under swarm-build.
set -uo pipefail
SRC=${SRC:-$(git -C "$(dirname "$0")" rev-parse --show-toplevel)}
domain=${1:?usage: world-native-admit.sh DOMAIN [--entry NAME] [--method FILE] [--candidate DIR] [world flags]}; shift
entry=note; method=; cand=; world_flags=(); route=objective; act_flags=()
while [ $# -gt 0 ]; do
  case $1 in
    --entry) entry=$2; shift 2;;
    --route) route=$2; shift 2;; --scenario|--birth-input|--deposit|--state-type|--seed) act_flags+=("$1" "$2"); shift 2;; --method) method=$2; shift 2;; --candidate) cand=$2; shift 2;;
    *) world_flags+=("$1" "$2"); shift 2;;
  esac
done
[ -n "$cand" ] || cand=$(ls -dt /build/candidates/*/ | head -1)
cand=${cand%/}; bin=$cand/bin
if [ -z "$method" ]; then
  set -- "$SRC"/world/"$domain"/*.obend
  [ $# = 1 ] && [ -f "$1" ] || { echo "world-native-admit: name --method (found: $*)" >&2; exit 2; }
  method=$1
fi
# the candidate's binaries and this tree's genesis params must be the same commit: a driver from another
# commit fails at genesis with "unknown/missing field" (seen 2026-10-27), which says nothing about the method
head=$(git -C "$SRC" rev-parse HEAD 2>/dev/null)
case $(basename "$cand") in "${head:0:8}"*|"$head"*) ;; *)
  [ -n "${ALLOW_TREE_MISMATCH:-}" ] || { echo "world-native-admit: SRC is at ${head:0:8} but the candidate is $(basename "$cand"); use a worktree at the candidate commit (ALLOW_TREE_MISMATCH=1 only for the driver files)" >&2; exit 2; };; esac
d=$SRC/native/resource-client/objective-native-acceptance.py
run=${WORLD_NATIVE_RUN:-/build/lanes/wn-$domain-$$}   # short: unix socket path bound
ev=$SRC/docs/evidence/2026-10-27-world-native/$domain
mkdir -p "$ev"; v=$ev/verdicts.txt
{ echo "candidate $(basename "$cand")  method ${method#$SRC/}  entry $entry  flags ${world_flags[*]:-none}"; } >"$v"
step() { local name=$1; shift; local out rc
  out=$(python3 "$d" "$@" 2>&1); rc=$?
  echo "$name rc=$rc: $(printf '%s' "$out" | grep -v "^$" | tail -1 | cut -c1-700)" | tee -a "$v"
  # the driver reports a refused invocation as a result row, exit 0: a refusal is not an admission
  if [ $rc = 0 ] && printf '%s' "$out" | grep -q '"refused": true'; then echo "$name REFUSED (row above)" | tee -a "$v"; return 1; fi
  return $rc; }
if [ "$route" = activity ]; then
  out=$(python3 "$SRC/native/resource-client/world-activity-admit.py" --bin "$bin" --root "$run" --method "$method" --entry "$entry" "${act_flags[@]}" 2>&1); rc=$?
  printf '%s\n' "$out" | cut -c1-600 | tee -a "$v"
  mkdir -p "$ev"; cp "$run/results.json" "$ev/" 2>/dev/null
  echo "overall rc=$rc" | tee -a "$v"; exit $rc
fi
rc=0
step world world --bin "$bin" --root "$run" "${world_flags[@]}" \
 && step publish publish --root "$run" --method "$method" --entry "$entry" \
 && step invoke invoke --root "$run" --label i1 \
 && step readback readback --root "$run" --label i1 || rc=$?
python3 "$d" stop --root "$run" >/dev/null 2>&1
cp -r "$run/results" "$ev/" 2>/dev/null; mkdir -p "$ev/transcript"; cp "$run"/transcript/{publication,publish-*,i1-invoke,i1-dry*}.{cmd,err,rc} "$ev/transcript/" 2>/dev/null
echo "overall rc=$rc" | tee -a "$v"; exit $rc
