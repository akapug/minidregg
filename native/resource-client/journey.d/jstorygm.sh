#!/usr/bin/env bash
# JSGM (DEMO-EXPERIENCE door 11): a story told by a GM who is not its author, through `mini shell` on this
# journey's live Store: the author seals it and invites the GM, the GM joins and narrates once, and the
# author (not the GM) is refused when narrating. The scenes law is re-installed under the scenes
# reference's own control capability (shared_names::existing_authority; demo-dry red on 2d8b7ed54).
#
# Every friend is enrolled and provisioned the way OPERATOR.md does it (the
# sponsor's shell enrolls; the sponsor's `provision` writes a birth context
# that the operator delivers to HOME/provision/), then runs `init` in their own
# shell with no other operator step. Every line after that is typed into a
# friend's own `mini shell` session (`--line`, the ssh forced command's mode).
#
# Refusal rows assert exit 3, the reason and its text on the shell's first
# stderr line, and the same reason in the Host's own decoding of the retained
# frame (HOME/refusals/*.json, written by the Host's `inspect outcome`).
#
# Hook contract: journey.sh (executed, not sourced). Last stdout line: the row
# table. Last stderr line: the detail. Exit 0 only when every row is ok.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/../journey-private.sh"
umask 077
: "${JOURNEY_STEP_DIR:?}" "${SHELL_BIN:?}" "${MINI:?}" "${HOST:?}" "${CONFIG:?}" "${SOCKET:?}" "${SPONSOR_WS:?}"
SD=$JOURNEY_STEP_DIR
H=$SD/h; WS=$SD/w; L=$SD/log
mkdir -p -m 700 "$H" "$WS" "$L"
TABLE=$SD/jsgm.tsv
printf 'n\tstep\twho\tline\texpect\trc\tverdict\tnote\n' >"$TABLE"
N=0; FAILED=0; FIRST_FAIL=""

ws_of() { if [ "$1" = sponsor ]; then echo "$SPONSOR_WS"; else echo "$WS/$1"; fi; }

# say WHO LINE: one line in WHO's own shell session; sets RC, OUT, ERR.
say() {
  local who=$1 line=$2
  N=$((N + 1))
  local stem; stem=$(printf '%03d-%s' "$N" "$who")
  printf '%s\n' "$line" >"$L/$stem.line"
  "$SHELL_BIN" shell --socket "$SOCKET" --host "$HOST" --config "$CONFIG" \
    --workspace "$(ws_of "$who")" --home "$H/$who" --line "$line" >"$L/$stem.out" 2>"$L/$stem.err"
  RC=$?
  OUT=$L/$stem.out; ERR=$L/$stem.err
}

record() { # step who line expect verdict note
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$N" "$1" "$2" "$3" "$4" "$RC" "$5" "$6" >>"$TABLE"
  if [ "$5" != ok ]; then
    FAILED=$((FAILED + 1))
    [ -n "$FIRST_FAIL" ] || FIRST_FAIL="row $N ($1 $2: $3): $6"
  fi
}

# ok STEP WHO LINE: the line must succeed.
ok() {
  say "$2" "$3"
  if [ "$RC" = 0 ]; then record "$1" "$2" "$3" 0 ok ""
  else record "$1" "$2" "$3" 0 FAIL "$(grep -m1 -E '^(refused|undecided|error|usage): ' "$ERR")"; fi
}

# refused STEP WHO LINE REASON TEXT: exit 3; stderr's first line is
# `refused: REASON: …TEXT…`; the Host's decoding of the retained frame, when
# the refusal was a frame, names the same reason.
refused() {
  local step=$1 who=$2 line=$3 reason=$4 text=$5 first evidence decoded
  say "$who" "$line"
  first=$(grep -m1 -E '^(refused|undecided|error|usage): ' "$ERR")
  if [ "$RC" != 3 ]; then record "$step" "$who" "$line" 3 FAIL "rc $RC: $first"; return; fi
  case "$first" in
    "refused: $reason: "*"$text"*) ;;
    *) record "$step" "$who" "$line" 3 FAIL "want refused: $reason: …$text…; got: $first"; return ;;
  esac
  evidence=$(sed -n 's/^  evidence: //p' "$ERR" | head -1)
  if [ -n "$evidence" ]; then
    decoded=${evidence%.bin}.json
    if [ "$(jq -r '.reason // empty' "$decoded" 2>/dev/null)" != "$reason" ]; then
      record "$step" "$who" "$line" 3 FAIL "the Host's decoding $decoded does not name $reason"; return
    fi
  fi
  record "$step" "$who" "$line" 3 ok "$first"
}

# fails STEP WHO LINE RC TEXT: a client-side ending (usage 2 / error 1) with TEXT.
fails() {
  local first
  say "$2" "$3"
  first=$(grep -m1 -E '^(refused|undecided|error|usage): ' "$ERR")
  case "$RC:$first" in
    "$4:"*"$5"*) record "$1" "$2" "$3" "$4" ok "$first" ;;
    *) record "$1" "$2" "$3" "$4" FAIL "want rc $4 with …$5…; got rc $RC: $first" ;;
  esac
}

# check STEP DESCRIPTION COMMAND…: a condition on retained artifacts.
check() {
  local step=$1 what=$2; shift 2
  N=$((N + 1)); RC=-
  if "$@" >/dev/null 2>&1; then record "$step" check "$what" - ok ""
  else record "$step" check "$what" - FAIL "condition false"; fi
}

# operator STEP WHAT COMMAND…: an operator action outside any shell.
operator() {
  local step=$1 what=$2; shift 2
  N=$((N + 1))
  "$@" >"$L/$(printf '%03d' "$N")-operator.out" 2>"$L/$(printf '%03d' "$N")-operator.err"
  RC=$?
  if [ "$RC" = 0 ]; then record "$step" OPERATOR "$what" 0 ok ""
  else record "$step" OPERATOR "$what" 0 FAIL "$(tail -1 "$L/$(printf '%03d' "$N")-operator.err")"; fi
}

finish() {
  echo "$TABLE"
  if [ "$FAILED" = 0 ]; then
    echo "JSGM: $N rows ok ($TABLE)" >&2; exit 0
  fi
  echo "JSGM: $FAILED of $N rows failed; first: $FIRST_FAIL" >&2; exit 1
}


mkdir -p -m 700 "$H/sponsor"
printf '%s\n' '{"type":"all","predicates":[]}' >"$SD/permit-all.json"
declare -A SUBJ
for f in gm; do
  mkdir -p -m 700 "$H/$f"
  ok setup "$f" "keygen mini.key"
  operator setup "CUSTODY: copy $f's secret into the sponsor home" \
    install_private 0600 "$H/$f/keys/mini.key" "$H/sponsor/keys/$f.key"
  ok setup sponsor "enroll plan $f $f.key $(xxd -p -c 256 "$H/$f/keys/mini.key.next.pub") $(xxd -p -c 256 "$H/$f/keys/mini.key.next.cosign")"
  ok setup sponsor "enroll seal $f"
  ok setup sponsor "enroll submit $f"
  SUBJ[$f]=$(jq -r '.subject // empty' "$OUT")
  check setup "$f is enrolled as its own subject" test -n "${SUBJ[$f]}"
  operator setup "CUSTODY: remove the copy" rm -f "$H/sponsor/keys/$f.key"
  operator setup "PROVISION: factory observation + a funded account owned by $f" \
    "$MINI" workspace --action provision --dir "$SPONSOR_WS" --name "$f" --holder "${SUBJ[$f]}" \
      --funding 1000 --account-predicate "$SD/permit-all.json" --factory-ref factory
  operator setup "DELIVER: the birth context into $f's HOME/provision/" \
    install_private 0600 "$SPONSOR_WS/provisions/$f/birth-context.json" "$H/$f/provision/birth-context.json"
  ok setup "$f" "init mini.key ${SUBJ[$f]}"
done
G=${SUBJ[gm]}
S=gmtale
ok story sponsor "story new $S --from tale --gm $G"
for i in $(seq 1 24); do
  say sponsor "story seal $S"
  grep -q 'has no story' "$ERR" "$OUT" 2>/dev/null || break
  sleep 15
done
if [ "$RC" = 0 ]; then record story sponsor "story seal $S" 0 ok ""; else record story sponsor "story seal $S" 0 FAIL "rc $RC: $(grep -m1 -E '^(refused|undecided|error|usage): ' "$ERR")"; fi
ok story sponsor "story seal $S"
check story "a second seal is a no-op that says so" grep -q 'already sealed' "$OUT"
ok story sponsor "story invite $S $G gm"
mkdir -p -m 700 "$H/gm/requests"
sed -n "s/^story join $S //p" "$OUT" | head -1 >"$H/gm/requests/invitation.txt"
check story "the GM's invitation line was printed" test -s "$H/gm/requests/invitation.txt"
ok story gm "story join $S @invitation.txt"
ok story gm "narrate the door groans"
refused story sponsor "narrate the author is not the teller" law-denied ""
# A player's invitation is idempotent: the second `story invite` for the same player prints the saved line and
# writes nothing (demo-dry: "scalar proposal requires 1..64 actions" on a re-invite); an invitation that is not
# one (a non-GM named as GM) is refused by name.
outcomes() { find "$SPONSOR_WS/attempts" -name 'outcome.json' 2>/dev/null | wc -l; }
ok story sponsor "story invite $S $G"
INV1=$(sed -n "s/^story join $S //p" "$OUT" | head -1)
BEFORE=$(outcomes)
ok story sponsor "story invite $S $G"
check story "the second invite wrote nothing (no new outcome)" test "$(outcomes)" = "$BEFORE"
check story "the second invite reprints the same invitation" test "$(sed -n "s/^story join $S //p" "$OUT" | head -1)" = "$INV1"
check story "and says it is already invited" grep -q 'already invited' "$OUT"
fails story sponsor "story invite $S 424242 gm" 2 "not $S's GM"

# Two invites of one home at once (the door's beside the seed's; demo-dry 9bd52317c: "cannot create
# .../reads/story-tale/table.N/view.bin: No such file or directory"): a finished signed read must not sweep
# the other process's in-flight read directory. Several rounds, each pair started together.
CONC_FAIL=""
for round in 1 2 3 4 5 6; do
  for who in a b; do
    "$SHELL_BIN" shell --socket "$SOCKET" --host "$HOST" --config "$CONFIG" --workspace "$SPONSOR_WS" \
      --home "$H/sponsor" --line "story invite $S $G" >"$L/conc-$round-$who.out" 2>"$L/conc-$round-$who.err" &
    eval "CPID_$who=\$!"
  done
  wait "$CPID_a"; RA=$?; wait "$CPID_b"; RB=$?
  for who in a b; do
    grep -q 'No such file or directory' "$L/conc-$round-$who.err" && CONC_FAIL="round $round $who: $(grep -m1 'No such file' "$L/conc-$round-$who.err")"
  done
  [ "$RA$RB" = 00 ] || CONC_FAIL="${CONC_FAIL:-round $round: rc $RA/$RB: $(grep -m1 -E '^(refused|error|usage): ' "$L/conc-$round-a.err" "$L/conc-$round-b.err")}"
done
N=$((N + 1)); RC=-
if [ -z "$CONC_FAIL" ]; then record story check "six pairs of concurrent invites of one home all succeed" - ok ""
else record story check "six pairs of concurrent invites of one home all succeed" - FAIL "$CONC_FAIL"; fi

# An enrolment whose submit marker was written and whose process then died before the Host took the ingress
# (the demo-dry dryguest4 wedge: every retry looked the same absent ingress up forever). The marker is forged
# the way the dead process left it; a later `enroll lookup` retires the attempt, and the same name enrols.
LATE=late
mkdir -p -m 700 "$H/$LATE"
ok setup "$LATE" "keygen mini.key"
operator setup "CUSTODY: copy $LATE's secret into the sponsor home" install_private 0600 "$H/$LATE/keys/mini.key" "$H/sponsor/keys/$LATE.key"
LPLAN="enroll plan $LATE $LATE.key $(xxd -p -c 256 "$H/$LATE/keys/mini.key.next.pub") $(xxd -p -c 256 "$H/$LATE/keys/mini.key.next.cosign")"
ok setup sponsor "$LPLAN"
ok setup sponsor "enroll seal $LATE"
EDIR=$H/sponsor/enroll/$LATE
check setup "the sealed attempt exists" test -s "$EDIR/ingress.bin"
printf '{"format":"minidregg-participant-enrollment-custody-v1","ingressSha256":"%s","operation":88,"status":"may-have-submitted"}\n' \
  "$(sha256sum "$EDIR/ingress.bin" | cut -d' ' -f1)" >"$EDIR/submit-marker.json"
say sponsor "enroll lookup $LATE"
check setup "a later lookup of an ingress the Host never took retires the attempt by name" grep -q 'absent from the Host' "$ERR"
check setup "and leaves the refused-no-record record, not the marker, to plan from" test -e "$EDIR/submit-refused.json" -o -e "$EDIR/replanned"
ok setup sponsor "$LPLAN"
ok setup sponsor "enroll seal $LATE"
ok setup sponsor "enroll submit $LATE"
ok setup sponsor "enroll lookup $LATE"
check setup "the retried name is enrolled as its own subject" test -n "$(jq -r '.subject // empty' "$OUT")"
operator setup "CUSTODY: remove the copy" rm -f "$H/sponsor/keys/$LATE.key"
finish
