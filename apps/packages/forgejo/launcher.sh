#!/bin/bash
set -euo pipefail

export USER=forgejo
export HOME=/var/forgejo/home
export TMPDIR=/tmp
export GIT_AUTHOR_NAME=Forgejo
export GIT_AUTHOR_EMAIL=forgejo@localhost
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

mkdir -p /var/forgejo/custom/conf /var/forgejo/data /var/forgejo/repositories \
  /var/forgejo/home /var/forgejo/log /var/forgejo/avatars
CONFIG=/var/forgejo/custom/conf/app.ini
if [[ ! -f "$CONFIG" ]]; then
  secret_key=$(/opt/app/forgejo generate secret SECRET_KEY)
  internal_token=$(/opt/app/forgejo generate secret INTERNAL_TOKEN)
  http_port=${FORGEJO_HTTP_PORT:-8000}
  config=$(</opt/app/app.ini.example)
  config=${config/__SECRET_KEY__/$secret_key}
  config=${config/__INTERNAL_TOKEN__/$internal_token}
  config=${config//__HTTP_PORT__/$http_port}
  printf '%s\n' "$config" >"$CONFIG"
fi

cd /var/forgejo
exec /opt/app/forgejo --work-path /var/forgejo \
  --custom-path /var/forgejo/custom --config "$CONFIG" web
