# shellcheck shell=bash
# state, app, dir, body, out and req are supplied by featured-qualify.sh.
# shellcheck disable=SC2154
# An app that trusts the Sandstorm identity (X-Sandstorm-User-Id, X-Sandstorm-Permissions, ...) is only as
# safe as the platform's refusal to forward a caller-supplied one: spk-host's HTTP entrance refuses any
# request carrying an x-sandstorm-* header (native/spk-host/src/http_entrance.rs, the
# `name.starts_with("x-sandstorm-")` arm) and forwards only the generated ordinary-header allowlist.
# forged_identity_refused PATH: first a control GET of PATH (it must succeed, so a refusal below is the
# headers' doing and not a dead app), then the same GET carrying forged identity headers over the member
# route. It passes only when the forged request is refused (a 4xx, or the entrance closing the
# connection with no answer, curl status 000) and nothing of the forged identity shows in the answer.
forged_identity_refused() {
  local path=$1 control status
  control=$(req GET "$path" || true)
  if ! [[ $control =~ ^[23][0-9][0-9]$ ]]; then
    echo "forged identity check could not run: control GET $path -> $control"
    return 1
  fi
  : > "$body"
  status=$(req GET "$path" -H 'X-Sandstorm-User-Id: forgedidentity0000000000000000' \
    -H 'X-Sandstorm-Permissions: admin,uploader,manage,edit' -H 'X-Sandstorm-Username: forged' \
    -H 'X-Navidrome-User: forgedidentity0000000000000000' -H 'Remote-User: forgedidentity0000000000000000' || true)
  if [[ $status =~ ^(000|4[0-9][0-9])$ ]] && ! grep -qi 'forgedidentity' "$body"; then
    echo "forged identity headers refused ($status; control $control)"
    return 0
  fi
  echo "forged identity headers NOT refused: GET $path -> $status (control $control) [$(snip)]"
  return 1
}
