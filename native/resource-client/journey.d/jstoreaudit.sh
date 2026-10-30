#!/usr/bin/env bash
# JAUDIT (KN2-STORE-OPEN, `mini store audit`): the Store re-derived from genesis, on the journey's
# live Store, after its last write.
#
#   clean       `mini store audit` exits 0 and prints both lines: the store audit line (records,
#               chain, tags, accumulator, spent map, checkpoints, head root) and then the
#               `audited N accepted records` line of the existing audit
#   usage       the Host's store-audit arm refuses a stray option with exit 2
#   control     a COPY of the Store, untouched, audits clean (the copy procedure moves nothing)
#   planted     in another COPY one byte of a NON-HEAD durable_log record is flipped; the byte is
#               asserted changed BEFORE the verdict is read; `mini store audit` exits 1, stderr is
#               `store audit refused: ...` and names that height, and the second (re-admission)
#               audit never ran behind the refused store
#   evidence    (R9) `mini export-evidence` of an accepted signed call from the journey's own workspace
#               writes a package; `mini verify-evidence` re-derives the native prefix from it and
#               prints the receipt the Host gave the call (transaction id and accepted count equal the
#               attempt's retained outcome). One flipped byte of the package is refused by verify with
#               nothing written; a flipped byte of the call is refused by export (noncanonical, or
#               absent from the Store's history) with no package written.
#
# Hook contract: journey.sh exports MINI HOST CONFIG SOCKET JOURNEY_WORLD JOURNEY_STEP_DIR.
# Last stdout line = artifact; last stderr line = detail.
set -u
umask 077
D=$JOURNEY_STEP_DIR/jstoreaudit
mkdir -p -m 700 "$D"
T=$D/jstoreaudit.tsv; : >"$T"
N=0; BAD=0
row() {  # row CHECK EXPECTED OBSERVED OK(0/1)
  N=$((N + 1))
  if [ "$4" = 1 ]; then printf 'PASS\t%s\t%s\t%s\n' "$1" "$2" "$3" >>"$T"
  else printf 'FAIL\t%s\t%s\t%s\n' "$1" "$2" "$3" >>"$T"; BAD=$((BAD + 1)); fi
}
audit() {  # audit NAME CONFIG : mini store audit, rc and streams kept
  "$MINI" store audit --host "$HOST" --config "$2" >"$D/$1.out" 2>"$D/$1.err"
  echo $? >"$D/$1.rc"
}
rc() { cat "$D/$1.rc"; }

# clean, on the live Store.
audit clean "$CONFIG"
row "mini store audit on the journey Store" "exit 0, store audit line then audited line" \
  "exit=$(rc clean) $(head -1 "$D/clean.out" | cut -c1-90) | $(tail -n +2 "$D/clean.out" | head -1 | cut -c1-70)" \
  "$([ "$(rc clean)" = 0 ] && head -1 "$D/clean.out" | grep -q '^store audit: [0-9][0-9]* records; chain, tags, accumulator (' \
      && sed -n 2p "$D/clean.out" | grep -q '^audited [0-9][0-9]* accepted records: ' && echo 1 || echo 0)"

# usage: exit 2, nothing on stdout.
"$HOST" "$CONFIG" store-audit --bogus >"$D/usage.out" 2>"$D/usage.err"; echo $? >"$D/usage.rc"
row "store-audit with a stray option" "exit 2, no stdout, usage on stderr" \
  "exit=$(rc usage) stdout=$(wc -c <"$D/usage.out") $(head -1 "$D/usage.err")" \
  "$([ "$(rc usage)" = 2 ] && [ ! -s "$D/usage.out" ] && grep -q '^usage: store-audit' "$D/usage.err" && echo 1 || echo 0)"

# Two copies of the Store: control and planted.
ROOT=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["storageRoot"])' "$CONFIG")
copy() {
  mkdir -m 700 "$D/$1"
  cp -a "$ROOT" "$D/$1/store"
  [ -e "$ROOT.head-anchor" ] && cp -a "$ROOT.head-anchor" "$D/$1/store.head-anchor"
  python3 - "$CONFIG" "$D/$1/store" "$D/$1/config.json" <<'PY'
import json, os, sys
c = json.load(open(sys.argv[1])); c["storageRoot"] = sys.argv[2]
fd = os.open(sys.argv[3], os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
os.write(fd, json.dumps(c).encode()); os.close(fd)
PY
}
copy control; copy planted
audit control "$D/control/config.json"
row "an untouched copy of the Store" "exit 0 and the same store audit line" \
  "exit=$(rc control) $(head -1 "$D/control.out" | cut -c1-60)" \
  "$([ "$(rc control)" = 0 ] && [ "$(head -1 "$D/control.out")" = "$(head -1 "$D/clean.out")" ] && echo 1 || echo 0)"

python3 - "$D/planted/store/forward-link.sqlite3" >"$D/planted/mutation.txt" 2>"$D/planted/mutation.err" <<'PY'
import sqlite3, sys
db = sqlite3.connect(sys.argv[1])
top = db.execute("select max(height) from durable_log").fetchone()[0]
height = max(1, top // 2)
if not (1 <= height < top):
    sys.exit(f"no non-head record: top {top}")
before = db.execute("select record from durable_log where height = ?", (height,)).fetchone()[0]
index = len(before) // 2
after = bytearray(before); after[index] ^= 0x01
db.execute("update durable_log set record = ? where height = ?", (bytes(after), height))
db.commit()
stored = db.execute("select record from durable_log where height = ?", (height,)).fetchone()[0]
assert stored != before and len(stored) == len(before), "mutation did not take"
print(f"{height} {index} {top}")
PY
mrc=$?
read -r MH MI MTOP <"$D/planted/mutation.txt" || :
row "the planted fault took: one byte of a non-head record changed" "exit 0, height < head" \
  "rc=$mrc height=${MH:-?} byte=${MI:-?} head=${MTOP:-?} $(head -1 "$D/planted/mutation.err")" \
  "$([ "$mrc" = 0 ] && [ -n "${MH:-}" ] && [ "$MH" -lt "$MTOP" ] && echo 1 || echo 0)"
if [ "$mrc" = 0 ]; then
  audit planted "$D/planted/config.json"
  row "mini store audit on the planted copy" "exit 1; stderr store audit refused naming height $MH; no re-admission line" \
    "exit=$(rc planted) stdout=$(wc -c <"$D/planted.out")B $(tail -1 "$D/planted.err" | cut -c1-140)" \
    "$([ "$(rc planted)" = 1 ] && grep -q '^store audit refused: ' "$D/planted.err" \
        && grep -qE "(^|[^0-9])$MH([^0-9]|\$)" "$D/planted.err" && ! grep -q '^audited ' "$D/planted.out" && echo 1 || echo 0)"
fi

# evidence (R9): an accepted call's package, verified, then the two refusals.
CALL=""; OUTCOME=""
for c in $(find "$JOURNEY_WORLD" -name call.bin -path '*/attempts/*' 2>/dev/null | sort); do
  o=$(dirname "$c")/outcome.json
  if [ -s "$o" ] && jq -e '.type == "confirmed"' "$o" >/dev/null 2>&1; then CALL=$c; OUTCOME=$o; break; fi
done
E=$D/evidence; mkdir -m 700 "$E"
row "an accepted signed call of the journey's own workspace exists" "a call.bin with a confirmed outcome" "${CALL:-none}" "$([ -n "$CALL" ] && echo 1 || echo 0)"
if [ -n "$CALL" ]; then
  "$MINI" export-evidence --host "$HOST" --config "$CONFIG" --call "$CALL" --output "$E/package.bin" >"$E/export.out" 2>"$E/export.err"; erc=$?
  row "mini export-evidence of the accepted call" "exit 0 and a package" "exit=$erc package=$(wc -c <"$E/package.bin" 2>/dev/null || echo none)B $(head -1 "$E/export.err" | cut -c1-80)" \
    "$([ "$erc" = 0 ] && [ -s "$E/package.bin" ] && echo 1 || echo 0)"
  "$MINI" verify-evidence --host "$HOST" --config "$CONFIG" --package "$E/package.bin" --output "$E/verified.json" >"$E/verify.out" 2>"$E/verify.err"; vrc=$?
  row "mini verify-evidence of that package" "exit 0; verified-mini-native-prefix-v1 with the attempt's transaction id and accepted count" \
    "exit=$vrc $(jq -c '{type,transactionId,acceptedCount}' "$E/verified.json" 2>/dev/null | cut -c1-120) vs $(jq -c '{transactionId,acceptedCount}' "$OUTCOME" 2>/dev/null)" \
    "$([ "$vrc" = 0 ] && jq -e --slurpfile o "$OUTCOME" '.type == "verified-mini-native-prefix-v1" and .transactionId == ($o[0].transactionId | tostring) and .acceptedCount == ($o[0].acceptedCount | tostring)' "$E/verified.json" >/dev/null 2>&1 && echo 1 || echo 0)"
  python3 - "$E/package.bin" "$E/package-planted.bin" >"$E/planted-package.txt" 2>&1 <<'PY'
import sys
b = bytearray(open(sys.argv[1], "rb").read())
i = len(b) // 2
b[i] ^= 0x01
assert bytes(b) != open(sys.argv[1], "rb").read()
open(sys.argv[2], "xb").write(bytes(b))
print(i, len(b))
PY
  prc=$?
  row "the planted fault took: one byte of the package changed" "exit 0" "rc=$prc $(cat "$E/planted-package.txt" | cut -c1-60)" "$([ "$prc" = 0 ] && echo 1 || echo 0)"
  "$MINI" verify-evidence --host "$HOST" --config "$CONFIG" --package "$E/package-planted.bin" --output "$E/planted-verified.json" >"$E/planted-verify.out" 2>"$E/planted-verify.err"; pvrc=$?
  row "mini verify-evidence of the planted package" "exit != 0, a refusal on stderr, no result written" \
    "exit=$pvrc $(tail -1 "$E/planted-verify.err" | cut -c1-140)" \
    "$([ "$pvrc" != 0 ] && [ -s "$E/planted-verify.err" ] && [ ! -e "$E/planted-verified.json" ] && echo 1 || echo 0)"
  python3 - "$CALL" "$E/call-planted.bin" >"$E/planted-call.txt" 2>&1 <<'PY'
import sys
b = bytearray(open(sys.argv[1], "rb").read())
i = len(b) // 2
b[i] ^= 0x01
assert bytes(b) != open(sys.argv[1], "rb").read()
open(sys.argv[2], "xb").write(bytes(b))
print(i, len(b))
PY
  crc=$?
  "$MINI" export-evidence --host "$HOST" --config "$CONFIG" --call "$E/call-planted.bin" --output "$E/planted-package.bin" >"$E/planted-export.out" 2>"$E/planted-export.err"; xrc=$?
  row "mini export-evidence of a call with one byte changed" "exit != 0 naming noncanonical or absent-from-history; no package written" \
    "plant=$crc exit=$xrc $(tail -1 "$E/planted-export.err" | cut -c1-140)" \
    "$([ "$crc" = 0 ] && [ "$xrc" != 0 ] && grep -Eq 'noncanonical native signed call|exact signed call is absent or conflicts' "$E/planted-export.err" && [ ! -e "$E/planted-package.bin" ] && echo 1 || echo 0)"
fi

echo "$T"
if [ "$BAD" = 0 ]; then
  echo "JAUDIT: $N/$N checks; $(head -1 "$D/clean.out" | cut -c1-80); planted height $MH refused: $(tail -1 "$D/planted.err" | cut -c1-100)" >&2
  exit 0
fi
echo "JAUDIT: $BAD of $N checks failed (see $T)" >&2
exit 1
