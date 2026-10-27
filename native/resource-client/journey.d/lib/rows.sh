# journey.d/lib/rows.sh: the row table the FB5 hooks (jescrow, jfleet-incoming, jstorylaw, jr17) share.
# Sourced, not executed. A row is PASS or FAIL beside what was expected and what was observed; a hook
# ends with `rows_finish`, which prints the table path on stdout and the verdict on stderr.
#
# What counts as the Host's decision (never a local notice, and never an exit status alone: a program
# that does nothing exits 0 with no output, so every "admitted" below asks for a thing only a decided
# write leaves behind):
#   confirmed_count WS   the number of confirmed outcome files under WS/attempts (the Host's receipts)
#   want_admitted        rc 0 AND confirmed_count rose (a write), or the stdout the read must carry
#   want_refused         rc 3 AND the first stderr line is `refused: REASON: …` naming the clause
#   want_undecided       rc 4 AND the first stderr line is `undecided: …`
# A row that checks a client-side refusal (nothing was sent) says so in its name: "client:".

rows_init() { # ID: RID, D (the hook's directory), T (the table), N, BAD
  RID=$1
  D=$JOURNEY_STEP_DIR/$RID
  mkdir -p -m 700 "$D/log"
  T=$D/$RID.tsv
  printf 'verdict\tcheck\texpected\tobserved\n' >"$T"
  N=0; BAD=0; FIRST_BAD=""
}

row() { # CHECK EXPECTED OBSERVED OK(1/0)
  N=$((N + 1))
  if [ "$4" = 1 ]; then printf 'PASS\t%s\t%s\t%s\n' "$1" "$2" "$3" >>"$T"
  else
    printf 'FAIL\t%s\t%s\t%s\n' "$1" "$2" "$3" >>"$T"
    BAD=$((BAD + 1)); [ -n "$FIRST_BAD" ] || FIRST_BAD="$1: expected $2, observed $3"
  fi
}

# run NAME CMD…: keeps NAME.{out,err,rc} under $D/log; sets RC OUT ERR.
run() {
  local name=$1; shift
  OUT=$D/log/$name.out; ERR=$D/log/$name.err
  "$@" >"$OUT" 2>"$ERR" </dev/null
  RC=$?
  echo "$RC" >"$D/log/$name.rc"
}

# shline NAME WORKSPACE HOME LINE: one line in a `mini shell --line` session; sets RC OUT ERR.
shline() {
  local name=$1 ws=$2 home=$3 line=$4
  mkdir -p -m 700 "$home"
  printf '%s\n' "$line" >"$D/log/$name.line"
  run "$name" "$SHELL_BIN" shell --socket "$SOCKET" --host "$HOST" --config "$CONFIG" \
    --workspace "$ws" --home "$home" --line "$line"
}

first_line() { grep -m1 -E '^(refused|undecided|error|usage): ' "$ERR"; }
short() { tr '\n\t' '  ' | cut -c1-"${1:-160}"; }

# confirmed_count WS: confirmed outcome files under WS/attempts (outcome.json and retry-*.json).
confirmed_count() {
  find "$1/attempts" \( -name outcome.json -o -name 'retry-*.json' \) -print0 2>/dev/null \
    | xargs -0 -r jq -r 'select(.type == "confirmed") | .transactionId' 2>/dev/null | wc -l | tr -d ' '
}

want_admitted() { # CHECK BEFORE_COUNT WS: rc 0 and the Host confirmed a new outcome in WS
  local after; after=$(confirmed_count "$3")
  row "$1" "admitted (rc 0, a new confirmed outcome)" "rc $RC, confirmed $2 -> $after; $(first_line | cut -c1-100)" \
    "$([ "$RC" = 0 ] && [ "$after" -gt "$2" ] && echo 1 || echo 0)"
}

want_refused() { # CHECK CLAUSE: rc 3 and `refused: REASON: …CLAUSE…`
  local first; first=$(first_line)
  row "$1" "refused naming $2 (rc 3)" "rc $RC: $(printf '%s' "$first" | cut -c1-180)" \
    "$([ "$RC" = 3 ] && case "$first" in "refused: "*"$2"*) true ;; *) false ;; esac && echo 1 || echo 0)"
}

want_undecided() { # CHECK: rc 4 and `undecided: …`
  local first; first=$(first_line)
  row "$1" "undecided (rc 4)" "rc $RC: $(printf '%s' "$first" | cut -c1-160)" \
    "$([ "$RC" = 4 ] && case "$first" in "undecided: "*) true ;; *) false ;; esac && echo 1 || echo 0)"
}

rows_finish() { # prints the table on stdout (the deciding artifact) and the verdict on stderr
  echo "$T"
  if [ "$BAD" = 0 ]; then echo "$RID: $N of $N rows as expected ($T)" >&2; exit 0; fi
  echo "$RID: $BAD of $N rows not as expected; first: $FIRST_BAD" >&2; exit 1
}
