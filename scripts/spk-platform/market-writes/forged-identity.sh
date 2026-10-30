# shellcheck shell=bash
# state, app, dir, body, out and req are supplied by featured-qualify.sh.
# shellcheck disable=SC2154
# An app that trusts the Sandstorm identity (X-Sandstorm-User-Id, X-Sandstorm-Permissions, ...) is only as
# safe as the platform's refusal to forward a caller-supplied one: spk-host's HTTP entrance refuses any
# request carrying an x-sandstorm-* header (native/spk-host/src/http_entrance.rs, the
# `name.starts_with("x-sandstorm-")` arm) and forwards only the generated ordinary-header allowlist.
# forged_identity_refused PATH: sends PATH with forged identity headers over the member route and passes only
# when the request is refused (4xx) and nothing of the forged identity shows in the answer.
forged_identity_refused() {
  local path=$1 status
  status=$(req GET "$path" -H 'X-Sandstorm-User-Id: forgedidentity0000000000000000' \
    -H 'X-Sandstorm-Permissions: admin,uploader,manage,edit' -H 'X-Sandstorm-Username: forged' \
    -H 'X-Navidrome-User: forgedidentity0000000000000000' -H 'Remote-User: forgedidentity0000000000000000')
  if [[ $status =~ ^4[0-9][0-9]$ ]] && ! grep -qi 'forgedidentity' "$body"; then
    echo "forged identity headers refused ($status)"
    return 0
  fi
  echo "forged identity headers NOT refused: GET $path -> $status [$(snip)]"
  return 1
}
