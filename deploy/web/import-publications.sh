#!/usr/bin/env bash
# deploy/web/import-publications.sh — the public reader imports what
# collect-publications.sh delivered (runs as mini-pubread, before each render).
#
# Each inbox file NAME.TARGET.json becomes a workspace reference. The first
# publication of a name gets NAME; a later one with the same name and a
# different capability (another author, or a re-publication after a revoke)
# gets NAME-CAPABILITY, so no author can take over another's page. A reference
# whose capability is already imported is skipped. Import is local: it records
# a hint, and the render's signed reads decide what is shown.
set -euo pipefail
: "${MINI:?}" "${PUBREAD_WS:?}" "${PUBREAD_INBOX:?}"
shopt -s nullglob
for file in "$PUBREAD_INBOX"/*.json; do
  base=${file##*/}; base=${base%.json}; name=${base%%.*}
  [[ $name =~ ^[A-Za-z0-9-]{1,64}$ ]] || continue
  capability=$(jq -er '.capability | select(test("^[0-9]{1,40}$"))' "$file" 2>/dev/null) || continue
  refs=("$PUBREAD_WS"/refs/*.json)
  if [ ${#refs[@]} -gt 0 ] && jq -e --arg c "$capability" 'select(.observeCapability == $c)' "${refs[@]}" </dev/null >/dev/null 2>&1; then
    continue
  fi
  [ -e "$PUBREAD_WS/refs/$name.json" ] && name="$name-$capability"
  [ ${#name} -le 64 ] || name="p-$capability"
  "$MINI" workspace --action import --dir "$PUBREAD_WS" --name "$name" --from-ref "$file" \
    || echo "import-publications: $file refused (see above)" >&2
done
