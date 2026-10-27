#!/usr/bin/env bash
# JSLK (DEMO-EXPERIENCE A7/A8; the SHELL path of the tour's doors 11 and 12): a law the member
# installs and then lives under, a kind the member defines and revises, and the built-in story,
# through `mini shell --line` on this journey's live Store. journey.d/jweb-frontend.sh asserts the
# same decided outcomes through the web front end (tour rows rules-*, story-*); these rows assert
# them by name on the shell path, so a regression in either path shows in its own step.
#
#   law     `law check` answers; a note document is born (admitted); a law that refuses every write is
#           installed (admitted: installs stay allowed); an append is REFUSED by that law (law-denied,
#           its clause named); a revised law is installed (admitted); the append is ADMITTED
#   kind    a kind with three fields is defined (admitted), shown (revision 1), an instance born from
#           it (admitted); a vote is admitted, the same vote again REFUSED (the append discipline);
#           the kind is revised (admitted) and shown at revision 2
#   story   the built-in tale: new (admitted, or undecided while the nineteen transitions land, then
#           looked up), seal (admitted), invite (admitted), join (the invitation is imported), look
#           (answered), one legal move admitted, the same move again REFUSED by the sealed story law
#
# Hook contract: journey.sh (executed). Needs SHELL_BIN MINI HOST CONFIG SOCKET SPONSOR_WS
# SPONSOR_SUBJECT JOURNEY_STEP_DIR. Last stdout line: the row table. Last stderr line: the detail.
set -u
umask 077
HERE=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
. "$HERE/lib/rows.sh"
: "${JOURNEY_STEP_DIR:?}" "${SHELL_BIN:?}" "${MINI:?}" "${HOST:?}" "${CONFIG:?}" "${SOCKET:?}" "${SPONSOR_WS:?}" "${SPONSOR_SUBJECT:?}"
rows_init JSLK
WS=$SPONSOR_WS
H=$D/home
mkdir -p -m 700 "$H/requests"
SUF=$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')
say() { shline "$@"; }       # say NAME LINE: as shline, in the sponsor's workspace and this hook's home
sh1() { local name=$1; shift; shline "$name" "$WS" "$H" "$*"; }
admit() { # CHECK LINE: a write line (Transition) that must be admitted
  local before; before=$(confirmed_count "$WS"); sh1 "$1" "$2"; want_admitted "$1" "$before" "$WS"
}
turn() { # CHECK ID LINE: a proposed line then its submit; the submit must be admitted
  local before; before=$(confirmed_count "$WS")
  sh1 "$1-propose" "$3"
  if [ "$RC" != 0 ]; then row "$1" "admitted" "the proposal itself ended rc $RC: $(first_line | cut -c1-140)" 0; return; fi
  sh1 "$1-submit" "submit $2"; want_admitted "$1" "$before" "$WS"
}
turn_refused() { # CHECK ID LINE CLAUSE: a proposed line whose submit the Host refuses naming CLAUSE
  sh1 "$1-propose" "$3"
  if [ "$RC" != 0 ]; then row "$1" "refused naming $4" "the proposal ended rc $RC before any submit: $(first_line | cut -c1-140)" 0; return; fi
  sh1 "$1-submit" "submit $2"; want_refused "$1" "$4"
}

# ---- law
RULES=rules$SUF
STRICT='any [ not (verb == write), slot "content/payload-bytes/after" <= 0 ]'
LOOSE='any [ not (verb == write), slot "content/payload-bytes/after" <= 16384 ]'
sh1 law-check "law check '$STRICT'"
row "law check: the Host answers whether the law can ever pass (a read; nothing installed)" "rc 0 and an answer" \
  "rc $RC, $(short 140 <"$OUT")$(first_line | cut -c1-60)" "$([ "$RC" = 0 ] && [ -s "$OUT" ] && echo 1 || echo 0)"
admit law-doc "doc new $RULES note"
turn law-install "lw1$SUF" "law lw1$SUF $RULES '$STRICT'"
turn_refused law-refused "la1$SUF" "doc append la1$SUF $RULES 'under the strict law'" law-denied
turn law-revised "lw2$SUF" "law lw2$SUF $RULES '$LOOSE'"
turn law-admitted "la2$SUF" "doc append la2$SUF $RULES 'under the revised law'"

# ---- kind
KIND=kind$SUF; INST=inst$SUF
cat >"$H/requests/poll-v1.json" <<'JSON'
{"descriptor":{"revision":"1","fields":[
 {"id":"1","name":"question","meaning":"the poll question","codec":"bytes","discipline":"rom"},
 {"id":"2","name":"open","meaning":"whether the poll accepts votes","codec":"nat","discipline":"ram"},
 {"id":"3","name":"votes","meaning":"one immutable vote keyed by member subject","codec":"nat","discipline":"append"}]},
 "defaults":[{"field":"1","key":"0","value":"4c756e63683f"},{"field":"2","key":"0","value":"1"}]}
JSON
jq '.descriptor.revision="2" | .descriptor.fields[2].meaning="vote weight times ten"' "$H/requests/poll-v1.json" >"$H/requests/poll-v2.json"
admit kind-create "kind create $KIND @poll-v1.json open"
sh1 kind-show1 "kind show $KIND"
row "kind show: the signed definition at revision 1" "revision 1, three fields" \
  "rc $RC, revision $(jq -r '.value.descriptor.revision // "none"' "$OUT" 2>/dev/null), $(jq -r '.value.descriptor.fields | length' "$OUT" 2>/dev/null) fields" \
  "$([ "$RC" = 0 ] && jq -e '.value.descriptor.revision == "1" and (.value.descriptor.fields | length) == 3' "$OUT" >/dev/null 2>&1 && echo 1 || echo 0)"
admit kind-instance "create $INST --from $KIND open"
sh1 inst-show "instance show $INST"
turn kind-vote "kv1$SUF" "instance set kv1$SUF $INST votes $SPONSOR_SUBJECT 1"
turn_refused kind-vote-twice "kv2$SUF" "instance set kv2$SUF $INST votes $SPONSOR_SUBJECT 2" operation-rejected
turn kind-revise "kr1$SUF" "kind revise kr1$SUF $KIND @poll-v2.json"
sh1 kind-show2 "kind show $KIND"
row "kind show: the revision the Host admitted" "revision 2" "rc $RC, revision $(jq -r '.value.descriptor.revision // "none"' "$OUT" 2>/dev/null)" \
  "$([ "$RC" = 0 ] && jq -e '.value.descriptor.revision == "2"' "$OUT" >/dev/null 2>&1 && echo 1 || echo 0)"

# ---- story
TALE=tale$SUF
before=$(confirmed_count "$WS")
sh1 story-new "story new $TALE --from tale"
if [ "$RC" = 4 ]; then
  want_undecided "story new: the nineteen transitions still deciding (the Host has not said)"
else
  want_admitted "story new: the tale's table and scenes are admitted" "$before" "$WS"
fi
SEAL_RC=1
for i in $(seq 1 24); do
  before=$(confirmed_count "$WS")
  sh1 story-seal "story seal $TALE"
  grep -q 'has no story' "$ERR" "$OUT" 2>/dev/null || break
  sleep 15
done
want_admitted "story seal: the story law is sealed" "$before" "$WS"
before=$(confirmed_count "$WS")
sh1 story-invite "story invite $TALE $SPONSOR_SUBJECT"
INVITE=$(sed -n "s/^story join $TALE //p" "$OUT" | head -1)
row "story invite: the member's own grant as the player" "admitted, and a join line to paste" \
  "rc $RC, confirmed $before -> $(confirmed_count "$WS"), invitation $(printf '%s' "$INVITE" | cut -c1-40)…" \
  "$([ "$RC" = 0 ] && [ -n "$INVITE" ] && [ "$(confirmed_count "$WS")" -gt "$before" ] && echo 1 || echo 0)"
printf '%s\n' "$INVITE" >"$H/requests/invitation.txt"
sh1 story-join "story join $TALE @invitation.txt"
row "story join: the invitation is imported" "rc 0 and a notice naming the story" "rc $RC, $(short 120 <"$OUT")$(first_line | cut -c1-60)" \
  "$([ "$RC" = 0 ] && grep -qi 'join' "$OUT" "$ERR" && echo 1 || echo 0)"
sh1 story-look "look"
row "look: the signed reads print the member's scene" "rc 0 and a scene" "rc $RC, $(short 120 <"$OUT")" "$([ "$RC" = 0 ] && [ -s "$OUT" ] && echo 1 || echo 0)"
before=$(confirmed_count "$WS")
sh1 story-move "go north"
row "go north: one legal move is admitted by the sealed story law" "rc 0, a new confirmed outcome, the anteroom" \
  "rc $RC, confirmed $before -> $(confirmed_count "$WS"), $(short 100 <"$OUT")" \
  "$([ "$RC" = 0 ] && [ "$(confirmed_count "$WS")" -gt "$before" ] && echo 1 || echo 0)"
sh1 story-again "go north"
want_refused "go north again: the impossible move is refused by the sealed story law" law-denied
sh1 story-law "story law $TALE"
row "story law: the law a player is judged by, printed" "rc 0 and clauses" "rc $RC, $(short 100 <"$OUT")" "$([ "$RC" = 0 ] && [ -s "$OUT" ] && echo 1 || echo 0)"
rows_finish
