#!/usr/bin/env bash
# deploy/web/collect-publications.sh — hand the public reader the documents
# authors published to it.
#
# An author publishes from the hosted shell with
#     delegate ID DOC PUBLIC-SUBJECT observe 0
#     submit ID
#     publish ID        # writes proposals/ID/recipient-reference.json
# This script (root, no network, mini-pubread-collect.service) finds every such
# delegated reference addressed to the public subject and copies it into the
# public reader's inbox as NAME.TARGET.json, NAME being the author's reference
# name for the document. It decides nothing: the reference is a hint, and the
# Host's signed read under the public key is what publishes or refuses the
# document at render time (a forged or revoked reference renders nothing).
#
# Environment (the unit sets them):
#   PUBREAD_WS      the public reader's workspace (its workspace.json names the subject)
#   PUBREAD_INBOX   where the references go (owned by mini-pubread)
#   PUBLISH_GLOB    where authors' published references live; default: every
#                   session's workspace under /var/lib/mini/sessions
set -euo pipefail
: "${PUBREAD_WS:?}" "${PUBREAD_INBOX:?}"
glob=${PUBLISH_GLOB:-/var/lib/mini/sessions/*/workspace/proposals/*/recipient-reference.json}
subject=$(jq -er '.subject | select(test("^[0-9]{1,40}$"))' "$PUBREAD_WS/workspace.json")
install -d -o mini-pubread -g mini-pubread -m 0700 "$PUBREAD_INBOX"
shopt -s nullglob
copied=0 seen=0
for ref in $glob; do
  [ -f "$ref" ] && [ ! -L "$ref" ] || continue
  [ "$(stat -c %s "$ref")" -le 65536 ] || continue
  jq -e --arg s "$subject" '.type == "minidregg-delegated-reference-v1" and .recipient == $s
      and (.target | test("^[0-9]{1,40}$"))' "$ref" >/dev/null 2>&1 || continue
  seen=$((seen + 1))
  name=$(jq -r '.delegation.name // empty' "$(dirname "$ref")/proposal.json" 2>/dev/null || true)
  [[ $name =~ ^[A-Za-z0-9-]{1,64}$ ]] || name=doc
  dest="$PUBREAD_INBOX/$name.$(jq -r .target "$ref").json"
  if ! cmp -s "$ref" "$dest"; then
    install -o mini-pubread -g mini-pubread -m 0600 "$ref" "$dest"
    copied=$((copied + 1))
  fi
done
echo "collect-publications: $seen reference(s) addressed to subject $subject, $copied new or changed"
