# Sourced by the seated Lean wrapper (build-native-host.sh copies this file beside bin/lean) and by
# scripts/test-lean-seat-lock.sh. The host-wide seat-allocation lock.
#
# The lock is a FILE, made by hard-linking a private temp file that already holds the owner's pid:
# link(2) is atomic and fails if the name exists, so a lock that exists always carries its pid (the old
# `mkdir` then `echo pid > dir/pid` left a pid-less lock if the process died between the two steps, and
# nothing reclaimed it: 2026-10-27, 1 h 53 m). The name is NOT the old `.alloc-lock` directory: `ln` onto a
# directory nests instead of failing, and rename(2) of a directory onto an EMPTY directory succeeds.
#
# Stale rule: the lock is stale when its owner pid is dead (`kill -0` fails), or when it names no pid and its
# mtime is older than LEAN_SEAT_LOCK_STALE_SECS (default 5). A stale lock is reclaimed by renaming it to a
# serialised by a second link-created lock (lockfile.reclaim, held for microseconds): under it the stale
# verdict is re-checked and the lock removed, so a reclaimer can never delete a lock another process took
# after the verdict (a rename-away-and-link-back reclaim was tried and the 50-round test caught it: the put-back
# gap lets a third acquirer in). A reclaim lock whose owner is dead is moved aside; two reclaimers can then
# overlap only if one died holding it AND a third process races the break -- narrower still, and the seats
# themselves are mkdir-atomic, so a double lock-holder cannot double-seat a compiler.
#
# Caller sets: lockfile (path). Uses/sets: locked (0/1). Optional: LEAN_SEAT_LOCK_TRIES (default 600, 0.05 s each).
lockfile=${lockfile:-}
locked=${locked:-0}
lean_seat_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null; }
# 0 stale (content in $stale_content), 1 live, 2 vanished
lean_seat_lock_stale() {
  local mt now
  [[ -e "$lockfile" ]] || return 2
  stale_content=$(cat "$lockfile" 2>/dev/null) || return 2
  if [[ -n "$stale_content" ]]; then
    kill -0 "$stale_content" 2>/dev/null && return 1
    return 0
  fi
  mt=$(lean_seat_mtime "$lockfile") || return 2
  now=$(date +%s)
  (( now - mt > ${LEAN_SEAT_LOCK_STALE_SECS:-5} ))
}
lean_seat_lock_reclaim() {   # $1 = the caller's pid file (a private hard-link source)
  local mtx="$lockfile.reclaim" prior=$stale_content owner tomb
  if ! ln "$1" "$mtx" 2>/dev/null; then
    # another reclaimer is working: leave it be unless its pid is dead
    owner=$(cat "$mtx" 2>/dev/null || true)
    if [[ -n "$owner" ]] && ! kill -0 "$owner" 2>/dev/null; then
      tomb="$mtx.stale.$$.$RANDOM"; mv "$mtx" "$tomb" 2>/dev/null && rm -f "$tomb"
    fi
    return 0
  fi
  # we are the only reclaimer. Only reclaimers (and a dead owner, who cannot) remove a stale lock, so a lock
  # still judged stale with the same content is the very file we saw: removing it cannot take a live lock.
  if lean_seat_lock_stale && [[ "$stale_content" == "$prior" ]]; then rm -f "$lockfile"; fi
  rm -f "$mtx"
}
lean_seat_lock() {
  local tries=0 tmp="$lockfile.new.$$" rc
  printf '%s\n' "$$" > "$tmp" || return 1
  while :; do
    if ln "$tmp" "$lockfile" 2>/dev/null; then rm -f "$tmp"; locked=1; return 0; fi
    rc=0; lean_seat_lock_stale || rc=$?
    if (( rc == 0 )); then lean_seat_lock_reclaim "$tmp"; continue; fi
    (( rc == 2 )) && continue
    tries=$((tries + 1)); (( tries < ${LEAN_SEAT_LOCK_TRIES:-600} )) || { rm -f "$tmp"; return 1; }
    sleep 0.05
  done
}
lean_seat_unlock() {
  if (( locked )); then
    [[ "$(cat "$lockfile" 2>/dev/null)" == "$$" ]] && rm -f "$lockfile"
    locked=0
  fi
}
