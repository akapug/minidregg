#!/usr/bin/env bash
# Regression for the seated-Lean wrapper's allocation lock (scripts/lean-seat-lock.sh).
# 2026-10-27: a build killed between taking the lock and writing its pid left a pid-less lock that nothing
# reclaimed; it stalled every build for 1 h 53 m. Cases: dead-pid lock and pid-less lock are reclaimed within
# the stale window; a live holder's lock is never stolen; concurrent acquirers never overlap (50 rounds).
# `--red` runs the killed-between-steps case against the OLD mkdir-then-pid code and must report a hang.
# Own timeouts: every acquirer runs as a separate bash process killed by its recorded pid.
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
lib=$here/lean-seat-lock.sh
scratch=$(mktemp -d "${TMPDIR:-/tmp}/lean-seat-lock-test.XXXXXX")
pids=()
cleanup() { for p in ${pids[@]+"${pids[@]}"}; do kill "$p" 2>/dev/null || true; done; rm -rf "$scratch"; }
trap cleanup EXIT
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

# run_to SECS cmd...: run cmd, kill it by its pid after SECS; rc 124 on timeout
run_to() {
  local secs=$1 p i; shift
  "$@" & p=$!; pids+=("$p")
  for ((i = 0; i < secs * 20; i++)); do kill -0 "$p" 2>/dev/null || { wait "$p"; return $?; }; sleep 0.05; done
  kill "$p" 2>/dev/null; wait "$p" 2>/dev/null; return 124
}
acquire_new() { # root: acquire, hold briefly, release
  bash -c 'lockfile=$1/alloc.lock; source "$2"; lean_seat_lock && lean_seat_unlock' _ "$1" "$lib"
}
dead_pid() { sleep 0 & local p=$!; wait "$p"; echo "$p"; }

if [[ ${1:-} == --red ]]; then
  # the OLD code, verbatim: mkdir, then pid
  old=$scratch/old.sh
  cat > "$old" <<'OLD'
lockdir=$1/.alloc-lock; locked=0
lock() {
  local tries=0 owner
  until mkdir "$lockdir" 2>/dev/null; do
    owner=$(cat "$lockdir/pid" 2>/dev/null || true)
    if [[ -n "$owner" ]] && ! kill -0 "$owner" 2>/dev/null; then rm -f "$lockdir/pid"; rmdir "$lockdir" 2>/dev/null || true; continue; fi
    tries=$((tries + 1)); (( tries < 600 )) || return 1
    sleep 0.05
  done
  echo "$$" > "$lockdir/pid"; locked=1
}
lock
OLD
  mkdir -p "$scratch/r"; mkdir "$scratch/r/.alloc-lock"   # killed between mkdir and pid write
  run_to 8 bash "$old" "$scratch/r"; rc=$?
  if (( rc == 124 )); then printf 'RED  old code hangs on a pid-less lock (killed after 8 s)\n'; exit 1; fi
  printf 'old code did not hang (rc=%s): red-proof void\n' "$rc"; exit 0
fi

# 1. pid of a dead process
r=$scratch/dead; mkdir -p "$r"; dead_pid > "$r/alloc.lock"
t0=$(date +%s); run_to 10 acquire_new "$r"; rc=$?; el=$(( $(date +%s) - t0 ))
(( rc == 0 && el <= 3 )) && ok "dead-pid lock reclaimed (${el}s)" || bad "dead-pid lock (rc=$rc, ${el}s)"

# 2. no pid at all (killed between the steps of the old code): reclaimed only after the stale window
r=$scratch/pidless; mkdir -p "$r"; : > "$r/alloc.lock"
t0=$(date +%s); run_to 15 acquire_new "$r"; rc=$?; el=$(( $(date +%s) - t0 ))
(( rc == 0 && el >= 4 && el <= 10 )) && ok "pid-less lock reclaimed after the 5 s window (${el}s)" || bad "pid-less lock (rc=$rc, ${el}s)"

# 3. a live holder is never stolen, not even when it is pid-less-looking old: its pid is alive
r=$scratch/live; mkdir -p "$r"; sleep 60 & holder=$!; pids+=("$holder"); echo "$holder" > "$r/alloc.lock"
touch -t 200001010000 "$r/alloc.lock"
run_to 10 bash -c 'lockfile=$1/alloc.lock; LEAN_SEAT_LOCK_TRIES=60 source "$2"; LEAN_SEAT_LOCK_TRIES=60 lean_seat_lock' _ "$r" "$lib"; rc=$?
[[ "$(cat "$r/alloc.lock")" == "$holder" && $rc -eq 1 ]] && ok "live holder's lock not stolen (acquirer gave up rc=1)" || bad "live holder (rc=$rc, lock=$(cat "$r/alloc.lock" 2>/dev/null))"
kill "$holder" 2>/dev/null

# 4. mutual exclusion: 50 rounds, 4 racers each; every 3rd round starts from a dead-pid lock
viol=0
for round in $(seq 1 50); do
  r=$scratch/race$round; mkdir -p "$r"
  (( round % 3 == 0 )) && dead_pid > "$r/alloc.lock"
  racers=()
  for n in 1 2 3 4; do
    bash -c 'lockfile=$1/alloc.lock; source "$2"
      lean_seat_lock || { echo nolock >> "$1/errors"; exit 0; }
      mkdir "$1/crit" 2>/dev/null || echo overlap >> "$1/errors"
      sleep 0.02; rmdir "$1/crit" 2>/dev/null; lean_seat_unlock' _ "$r" "$lib" & racers+=("$!"); pids+=("$!")
  done
  for p in "${racers[@]}"; do wait "$p"; done
  [[ -e "$r/errors" ]] && { viol=$((viol + 1)); cat "$r/errors" | sort | uniq -c; }
  [[ -e "$r/alloc.lock" ]] && { viol=$((viol + 1)); echo "lock left behind in round $round"; }
done
(( viol == 0 )) && ok "50 rounds x 4 racers: never two holders, lock always released" || bad "mutual exclusion ($viol violating rounds)"

exit $fail
