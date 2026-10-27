#!/usr/bin/env bash
# J-PRIVATE: the research-labelled in-process four-party MPC door (docs/review/2026-10-26-native-crates/
# private-backend.md R1; owner ruling 2026-10-27). A DOOR, not the spine: it needs no Store, no Host and
# no socket; it is not listed in required-rows and not in journey.sh's SPINE/DEMO_STEPS/KERNEL_STEPS.
#
#   jprivate.sh BIN-DIR [SCRATCH]   BIN-DIR holds `mini` and `mini-private-compute`
#                                   (cargo build --release --features demo --bin mini-private-compute
#                                   in native/private-backend). One computation, ~15-60 s.
#
# Rows (`PASS|FAIL<TAB>row<TAB>detail` on stdout, then `J-PRIVATE PASS n/n` or `J-PRIVATE FAIL k/n` as the
# last line of stdout and stderr; exit 0 only on PASS):
#   run            `mini private-compute --left 173 --right 59` exits 0 and prints the sum 232
#   label          the first line is the research banner, with the label verbatim
#   transcript     the curious-holder transcript is present: its frame count, its phases, the witness
#                  comparison (0 differing frames outside the random-oracle classes; king, layer-mpc and
#                  output byte-identical)
#   no-input       neither input value (173, 59) appears as a token anywhere in the report
#   bad-value      256, -1 and a non-number are refused naming the bound; nothing runs
#   no-binary      a missing mini-private-compute is a named refusal, not a crash
#   label-drift    a binary whose report loses the label is refused by `mini` (the check has teeth)
# Plant: JPRIVATE_PLANT=leak makes the `no-input` row read a report with an input value appended,
# JPRIVATE_PLANT=drop-label one with the label cut from its first line: each row must go FAIL by name.
# A process this script starts is its foreground child; nothing is signalled.
set -uo pipefail
umask 077
BIN=${1:?usage: jprivate.sh BIN-DIR [SCRATCH]}
S=${2:-$(mktemp -d "${TMPDIR:-/tmp}/jprivate.XXXXXX")}
mkdir -p -m 700 "$S"
MINI=$BIN/mini PC=$BIN/mini-private-compute
LABEL='single process, n = 4, static f = 1, no simulator, no GOD'
rows=0 fails=0
row() {  # NAME OK DETAIL
  rows=$((rows + 1))
  if [ "$2" = 1 ]; then printf 'PASS\t%s\t%s\n' "$1" "$3"; else fails=$((fails + 1)); printf 'FAIL\t%s\t%s\n' "$1" "$3"; fi
}
[ -x "$MINI" ] && [ -x "$PC" ] || { echo "jprivate: $MINI or $PC is not executable" >&2; exit 98; }
export MINI_PRIVATE_COMPUTE_BIN=$PC

"$MINI" private-compute --left 173 --right 59 >"$S/report.txt" 2>"$S/report.err"; rc=$?
report=$(cat "$S/report.txt")
case "${JPRIVATE_PLANT:-}" in
  leak) report="$report"$'\n'"  holder 3 input share 173" ;;
  drop-label) report=$(sed '1s/: .*//' <<<"$report") ;;
esac
row run "$([ "$rc" = 0 ] && grep -q '^output: 232 ' <<<"$report" && echo 1 || echo 0)" "rc=$rc $(grep -m1 '^output:' <<<"$report") $(tail -1 "$S/report.err" | cut -c1-120)"
first=$(head -1 <<<"$report")
row label "$([ "$first" = "RESEARCH DEMONSTRATION: $LABEL" ] && echo 1 || echo 0)" "first line: $first"
frames=$(sed -n 's/^  frames delivered to holder 3: \([0-9][0-9]*\) in \([0-9][0-9]*\) phases$/\1 frames \2 phases/p' <<<"$report")
row transcript "$([ -n "$frames" ] && grep -q '^  differing frames outside those classes: 0$' <<<"$report" && grep -q '^  king, layer-mpc and output frames: all byte-identical$' <<<"$report" && grep -q '^curious holder 3 followed the protocol' <<<"$report" && echo 1 || echo 0)" "${frames:-no frame count}; $(grep -m1 'byte-identical frames' <<<"$report" | sed 's/^ *//')"
leak=""; for t in $(tr -c 'A-Za-z0-9\n' '\n' <<<"$report" | grep -v '^$' | sort -u); do case $t in 173|59) leak="$leak $t";; esac; done
row no-input "$([ -z "$leak" ] && [ -n "$report" ] && echo 1 || echo 0)" "input values in the report:${leak:- none}"
bad=0; detail=""
for args in "--left 256 --right 1" "--left -1 --right 1" "--left x --right 1"; do
  # shellcheck disable=SC2086
  out=$("$MINI" private-compute $args 2>&1); r=$?
  { [ "$r" != 0 ] && grep -q '0..=255' <<<"$out"; } || { bad=1; detail="$detail [$args rc=$r]"; }
done
row bad-value "$([ "$bad" = 0 ] && echo 1 || echo 0)" "three out-of-range or non-numeric values refused naming 0..=255;${detail:- all refused}"
out=$(MINI_PRIVATE_COMPUTE_BIN="$S/absent" "$MINI" private-compute --left 1 --right 2 2>&1); r=$?
row no-binary "$([ "$r" != 0 ] && grep -q 'cannot run' <<<"$out" && echo 1 || echo 0)" "rc=$r $(head -1 <<<"$out" | cut -c1-140)"
printf '#!/bin/sh\necho "RESEARCH DEMONSTRATION"\necho "output: 3"\n' >"$S/drifted"; chmod 700 "$S/drifted"
out=$(MINI_PRIVATE_COMPUTE_BIN="$S/drifted" "$MINI" private-compute --left 1 --right 2 2>&1); r=$?
row label-drift "$([ "$r" != 0 ] && grep -q 'research banner' <<<"$out" && ! grep -q '^output: 3' <<<"$out" && echo 1 || echo 0)" "rc=$r $(head -1 <<<"$out" | cut -c1-140)"

v="J-PRIVATE PASS $rows/$rows"; [ "$fails" = 0 ] || v="J-PRIVATE FAIL $fails/$rows"
echo "$v"; echo "$v" >&2
[ "$fails" = 0 ]
