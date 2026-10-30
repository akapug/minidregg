#!/usr/bin/env bash
# Run the kern gate-repair checks through the lane journey runner.
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit
max_rc=0
check() {
  local name=$1 rc
  shift
  if "$@"; then rc=0; else rc=$?; fi
  printf '%s: rc=%s\n' "$name" "$rc"
  if (( rc > max_rc )); then max_rc=$rc; fi
}
case ${1:-static} in
  generate-surfaces)
    check build-surfaces-generate python3 scripts/lean-build-surfaces.py generate
    ;;
  static)
    check host-closure bash scripts/check-host-closure.sh
    check full-loaded-ratchet bash scripts/ports/check-full-loaded-callers.sh
    check import-boundary bash scripts/check-import-boundary.sh
    check build-surfaces python3 scripts/lean-build-surfaces.py check
    ;;
  *) printf 'usage: %s [generate-surfaces|static]\n' "$0" >&2; exit 64 ;;
esac
exit "$max_rc"
