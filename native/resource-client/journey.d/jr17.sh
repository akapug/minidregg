#!/usr/bin/env bash
# JR17 (R17): the verbs the shell grammar has and no journey touched, on this journey's live Store, each
# row ending in the Host's decision or in a refusal that names its reason.
#
#   home            `home --json` lists the member's resources (discovery only); `home REF --json` is
#                   SOURCE-CHECKED: the Host's signed observation of REF (its height and world root)
#   key             `key providers` and `key ls` answer from the member's home; `key grant` for a
#                   provider the member holds no key for is refused by name
#   app             `app status REF` asks the Host whether REF is an authorized app and says no
#   adopt-next-key  on an identity that already committed a next key the adoption is refused by name
#   hermes          `hermes status` and `hermes cancel` in a room with no Hermes are refused by name
#
# Hook contract: journey.sh (executed). Needs SHELL_BIN MINI HOST CONFIG SOCKET SPONSOR_WS
# SPONSOR_SUBJECT JOURNEY_STEP_DIR. Last stdout line: the row table. Last stderr line: the detail.
set -u
umask 077
HERE=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
. "$HERE/lib/rows.sh"
: "${JOURNEY_STEP_DIR:?}" "${SHELL_BIN:?}" "${MINI:?}" "${HOST:?}" "${CONFIG:?}" "${SOCKET:?}" "${SPONSOR_WS:?}" "${SPONSOR_SUBJECT:?}"
rows_init JR17
WS=$SPONSOR_WS
H=$D/home
SUF=$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')
sh1() { local name=$1; shift; shline "$name" "$WS" "$H" "$*"; }
RES=r17$SUF

before=$(confirmed_count "$WS")
sh1 doc "doc new $RES note"
want_admitted "setup: a note document $RES is admitted" "$before" "$WS"

sh1 home "home --json"
row "home --json: the member's resources, discovery only" "mini-member-workspace-v1, subject $SPONSOR_SUBJECT, lists $RES, currentness discovery-only" \
  "rc $RC, $(jq -c '{type,subject,currentness,n:(.resources|length)}' "$OUT" 2>/dev/null | cut -c1-140)" \
  "$([ "$RC" = 0 ] && jq -e --arg r "$RES" --arg s "$SPONSOR_SUBJECT" '.type == "mini-member-workspace-v1" and (.subject | tostring) == $s and .currentness == "discovery-only" and ([.resources[].name] | index($r)) != null' "$OUT" >/dev/null 2>&1 && echo 1 || echo 0)"
sh1 homeref "home $RES --json"
row "home REF --json: the Host's signed observation of $RES" "currentness source-checked, an observed height and world root" \
  "rc $RC, $(jq -c '{currentness,height:.observation.height,root:(.observation.worldRoot|tostring|.[0:16])}' "$OUT" 2>/dev/null | cut -c1-140)" \
  "$([ "$RC" = 0 ] && jq -e '.currentness == "source-checked" and (.observation.height | tostring | length > 0) and (.observation.worldRoot | tostring | length > 0)' "$OUT" >/dev/null 2>&1 && echo 1 || echo 0)"
sh1 homenone "home nosuch$SUF --json"
row "client: home for a reference the member does not hold ends with an error" "rc != 0, nothing printed on stdout" \
  "rc $RC, $(first_line | cut -c1-120)$(head -1 "$ERR" | cut -c1-80)" "$([ "$RC" != 0 ] && [ ! -s "$OUT" ] && [ -s "$ERR" ] && echo 1 || echo 0)"

# key: the broker's client config is a deployment file; without it the verbs end in a named refusal
# of the broker, which is not a decision about the member: the rows then end the step UNCONFIGURED.
KEYS_OK=1; [ -r /etc/mini/keys-client.json ] || KEYS_OK=0
if [ "$KEYS_OK" = 1 ]; then
  sh1 keyproviders "key providers"
  row "key providers: the providers the member can choose" "rc 0 and a list" "rc $RC, $(short 120 <"$OUT")" "$([ "$RC" = 0 ] && [ -s "$OUT" ] && echo 1 || echo 0)"
  sh1 keyls "key ls"
  row "key ls: the member's provider grants" "rc 0 and an answer" "rc $RC, $(short 120 <"$OUT")$(short 80 <"$ERR")" "$([ "$RC" = 0 ] && { [ -s "$OUT" ] || [ -s "$ERR" ]; } && echo 1 || echo 0)"
fi

# The three below end in the client before anything is sent (no app session, no continuity custody, no
# Hermes in the room): rows named "client:", asserted by the exact sentence, never by exit status alone.
sh1 appstatus "app status $RES"
row "client: app status for a reference with no app session says so, sends nothing" "rc 1: App session is not configured for this reference" \
  "rc $RC, $(tail -1 "$ERR" | cut -c1-120)" "$([ "$RC" = 1 ] && grep -q '^error: App session is not configured for this reference$' "$ERR" && [ ! -s "$OUT" ] && echo 1 || echo 0)"
before=$(confirmed_count "$WS")
sh1 adopt "adopt-next-key no-such-next-key"
row "client: adopt-next-key without authenticated continuity custody is refused, nothing admitted" "rc 1: key adoption requires existing authenticated continuity custody; no new outcome" \
  "rc $RC, confirmed $before -> $(confirmed_count "$WS"), $(tail -1 "$ERR" | cut -c1-120)" \
  "$([ "$RC" = 1 ] && grep -q 'key adoption requires existing authenticated continuity custody' "$ERR" && [ "$(confirmed_count "$WS")" = "$before" ] && echo 1 || echo 0)"
sh1 hstatus "hermes status $RES"
row "client: hermes status in a room with no Hermes says so" "rc 2: usage: there is no Hermes in $RES" \
  "rc $RC, $(tail -1 "$ERR" | cut -c1-120)" "$([ "$RC" = 2 ] && grep -q "^usage: there is no Hermes in $RES\$" "$ERR" && echo 1 || echo 0)"
before=$(confirmed_count "$WS")
sh1 hcancel "hermes cancel 1 $RES"
row "client: hermes cancel in a room with no Hermes withdraws nothing" "rc 2: usage: there is no Hermes in $RES; no new outcome" \
  "rc $RC, confirmed $before -> $(confirmed_count "$WS"), $(tail -1 "$ERR" | cut -c1-100)" \
  "$([ "$RC" = 2 ] && grep -q "^usage: there is no Hermes in $RES\$" "$ERR" && [ "$(confirmed_count "$WS")" = "$before" ] && echo 1 || echo 0)"
if [ "$KEYS_OK" = 0 ] && [ "$BAD" = 0 ]; then
  echo "$T"
  echo "UNCONFIGURED: the key rows need /etc/mini/keys-client.json (the broker's client config); the other $N rows are as expected ($T)" >&2
  exit 5
fi
rows_finish
