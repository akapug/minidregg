# journey.d/lib/attempt.sh: read an attempt's retained answer through `mini attempt-state`, never the
# file itself. Sourced (POSIX sh) by every hook that judges an attempt's outcome.
#
#   attempt_answer ATTEMPT/outcome.json      the answer JSON on stdout (exit 1, silent, when absent)
#   attempt_answer ATTEMPT/retry-0001.json   one retry's answer
#   attempt_state ATTEMPT                    the whole state ({"outcome","retries","last","standing",...})
#
# `mini attempt-state` repairs the attempt from its seal.record first (mini_sdk::phase invariant 3),
# so a hook never reads a cache a crash left torn. MINI is the journey's client (journey.sh exports
# it to every hook).
attempt_answer() {
  "${MINI:?attempt_answer needs MINI}" attempt-state --attempt "$(dirname -- "$1")" --file "$(basename -- "$1")" 2>/dev/null
}
attempt_state() {
  "${MINI:?attempt_state needs MINI}" attempt-state --attempt "$1" --json 2>/dev/null
}
