#!/bin/bash
# stop-residents-partial-row.sh BIN SCRATCH_ROOT: the partial-world path of stop-residents.sh.
# Starts a world-up in its own process group (PID file SCRATCH_ROOT/up.pid), waits until the world
# has live residents, kills the world-up group by that PID file mid-store-phase (no WORLD.env ever
# exists), runs stop-residents.sh on the root, and asserts that no resident and no descendant of
# one survives. PASS/FAIL line; exit 0 only on PASS. Needs the operator environment world-up needs.
set -uo pipefail
[[ $# == 2 && -d $1 && ! -e $2 ]] || { echo "usage: $0 BIN FRESH_SCRATCH_ROOT" >&2; exit 2; }
bin=$1 root=$2
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$(dirname "$root")"; mkdir -m 700 "$root"
setsid bash "$here/world-up.sh" "$bin" "$bin" "$root/world" >"$root/up.log" 2>&1 &
echo $! >"$root/up.pid"
live=()
for _ in $(seq 1 600); do
  live=()
  for f in "$root"/world/w/a/c-*.pid "$root"/world/w/a/r-*.pid; do
    [[ -f $f ]] || continue
    p=$(tr -d '[:space:]' <"$f"); [[ $p =~ ^[0-9]+$ && -d /proc/$p ]] && live+=("$p")
  done
  (( ${#live[@]} > 0 )) && break
  kill -0 "$(cat "$root/up.pid")" 2>/dev/null || break
  sleep 0.5
done
descs() { local c; for c in $(pgrep -P "$1" || true); do echo "$c"; descs "$c"; done; }
tree=()
for p in "${live[@]}"; do tree+=("$p" $(descs "$p")); done
fail() { echo "FAIL	stop-residents partial world	$*"; kill -- "-$(cat "$root/up.pid")" 2>/dev/null; exit 1; }
(( ${#live[@]} > 0 )) || fail "no resident came up before world-up ended; see $root/up.log"
[[ ! -e $root/world/WORLD.env ]] || fail "the world finished; the kill was not mid-store-phase"
kill -- "-$(cat "$root/up.pid")" 2>/dev/null   # the world-up's own group, by its PID file
sleep 1
"$here/stop-residents.sh" "$root/world" || fail "stop-residents.sh reported a survivor"
for p in "${tree[@]}"; do
  [[ -d /proc/$p ]] && fail "pid $p (resident or descendant) survived"
done
echo "PASS	stop-residents partial world	${#live[@]} residents, ${#tree[@]} processes in their trees, none survived"
