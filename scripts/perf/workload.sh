#!/usr/bin/env bash
# scripts/perf/workload.sh -- THE fixed performance workload (docs/PERF-WORKLOAD.md).
#
#   scripts/perf/workload.sh BIN_DIR NEW_ROOT [N_BIRTHS M_UPDATES K_READS]
#
# BIN_DIR is a candidate's bin/ (minidregg-host, mini, minidregg-link-sqlite-store,
# minidregg-credential-signature-verifier). NEW_ROOT must not exist; it holds the scratch Store,
# the transcript and the results (results.tsv, table.txt, summary.json). Defaults N=20 M=16 K=8 (the smallest that crosses height 64 before the checkpoint phase: 10 + 2N + M > 64).
# Env: PERF_SEED (default 20261013), PERF_BUDGET_S (default 180: the wall bound the run is judged by),
# PERF_UNDER_LOAD=1 (run on a busy box anyway; recorded), PERF_INSTRUCTIONS=0 (no perf stat).
# The harness serves ONE named slow operation, births/create (an Objective object born); the other
# phases are its context. It is a measurement to take when a Store change claims a speedup, not a
# per-commit ceremony.
# Refuses (exit 3, naming the busy job) unless the box is quiet (scripts/perf/box.py quiet).
# Exit 0 when every phase completed AND the whole run took < PERF_BUDGET_S; 1 otherwise, with the
# reason as the last stderr line. Results: NEW_ROOT/{results.tsv,table.txt,summary.json,settings.json,
# quiet.json}; instructions:u per phase when `perf stat` works here.
set -uo pipefail
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
bin=${1:?BIN_DIR}; root=${2:?NEW_ROOT}
n=${3:-20}; m=${4:-16}; k=${5:-8}
budget=${PERF_BUDGET_S:-180}
case "$root" in /*) ;; *) root=$PWD/$root ;; esac
[ ! -e "$root" ] || { echo "workload: $root exists" >&2; exit 2; }
# The Store's socket lives under NEW_ROOT/w/public: it must fit sun_path (107 bytes).
sock="$root/w/public/mini.sock"
[ "${#sock}" -le 107 ] || { echo "workload: root too long for a Unix socket ($sock is ${#sock} bytes)" >&2; exit 2; }
for f in minidregg-host mini minidregg-link-sqlite-store minidregg-credential-signature-verifier; do
  [ -x "$bin/$f" ] || { echo "workload: $bin/$f is not executable" >&2; exit 2; }
done
seed=${PERF_SEED:-20261013}
python3 "$here/box.py" quiet "$root.quiet.json" >"$root.quiet.out"; q=$?
if [ "$q" != 0 ] && [ "${PERF_UNDER_LOAD:-0}" != 1 ]; then
  echo "workload REFUSED: $(tail -1 "$root.quiet.out") (PERF_UNDER_LOAD=1 runs anyway)" >&2
  rm -f "$root.quiet.json" "$root.quiet.out"; exit 3
fi
python3 "$here/box.py" settings "$root.settings.json" "$bin" "$n" "$m" "$k" "$seed" "$budget" "$root" || exit 2
run=(python3 "$here/workload.py" --bin "$bin" --root "$root" --births "$n" --updates "$m" --reads "$k" --seed "$seed")
perf_ok=0
if [ "${PERF_INSTRUCTIONS:-1}" = 1 ] && command -v perf >/dev/null && perf stat -e instructions:u -o /dev/null true 2>/dev/null; then
  perf_ok=1; run=(perf stat --no-scale -I 250 -x, -e instructions:u -o "$root.perf.csv" -- "${run[@]}")
fi
t0=$(date +%s.%N)
[ "$perf_ok" = 1 ] && echo "$t0" >"$root.perf.t0"   # perf's start: step attribution of intervals starts from it
"${run[@]}" >"$root.log" 2>&1
rc=$?
t1=$(date +%s.%N)
for f in quiet.json quiet.out settings.json perf.csv perf.t0; do [ -d "$root" ] && [ -e "$root.$f" ] && mv "$root.$f" "$root/$f"; done
if [ -f "$root/summary.json" ]; then
  if [ "$q" != 0 ]; then jq '.underLoad = true' "$root/summary.json" >"$root/summary.tmp" && mv "$root/summary.tmp" "$root/summary.json"; fi
  jq --slurpfile s "$root/settings.json" '.inputKey = $s[0].inputKey' "$root/summary.json" >"$root/summary.tmp" \
    && mv "$root/summary.tmp" "$root/summary.json"
  # raw counts (--no-scale): a run that does not say so is not comparable
  [ "$perf_ok" = 1 ] && jq '.perfCounting = "raw"' "$root/summary.json" >"$root/summary.tmp" && mv "$root/summary.tmp" "$root/summary.json"
  [ "$perf_ok" = 1 ] && { python3 "$here/box.py" instructions "$root" "$root/perf.csv" "$t0" || echo "workload: instruction attribution failed" >&2; }
fi
wall=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.1f", b-a}')
mv "$root.log" "$root/workload.log" 2>/dev/null || true
[ -f "$root/table.txt" ] && cat "$root/table.txt"
[ "$q" = 0 ] || echo "workload: UNDER LOAD: $(tail -1 "$root/quiet.out" 2>/dev/null)" >&2
# The verdict comes from the run's own summary, not the exit status (perf stat reports its own).
jq -e '(.phasesFailed | length) == 0 and .allTurnsOk' "$root/summary.json" >/dev/null 2>&1 || rc=1
reasons=()
if [ "$rc" != 0 ]; then
  failed=$(jq -r '[.phasesFailed[]] + (if .allTurnsOk then [] else ["(a turn judged red)"] end) | join(",")' "$root/summary.json" 2>/dev/null)
  reasons+=("phases not completed: ${failed:-unknown (no summary; see $root/workload.log)}")
fi
awk -v w="$wall" -v b="$budget" 'BEGIN{exit !(w < b)}' || reasons+=("wall ${wall}s not under the ${budget}s bound")
if [ "${#reasons[@]}" -gt 0 ]; then
  echo "workload FAIL: $(IFS=';'; echo "${reasons[*]}" | sed 's/;/; /g') (N=$n M=$m K=$k)" >&2
  exit 1
fi
echo "workload PASS: N=$n M=$m K=$k, every phase completed, wall ${wall}s < ${budget}s" >&2
