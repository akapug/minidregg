#!/bin/bash
set -euo pipefail

export HOME=/var
export NODE_ENV=production
export ETHERPAD_PRODUCTION=true
export TMPDIR=/tmp
export NODE_OPTIONS=--max-old-space-size=2048

mkdir -p /var/sandstorm/keys /var/sandstorm/plugins-initialized /var/js
# This package intentionally has no external plugins. Seed the per-grain
# manifest so upstream does not invoke pnpm for a legacy node_modules migration.
if [[ ! -f /var/installed_plugins.json ]]; then
  printf '%s\n' '{"plugins":[]}' > /var/installed_plugins.json
fi

cd /opt/app/etherpad-lite
exec /opt/app/node/bin/node \
  --require /opt/app/etherpad-lite/src/node_modules/tsx/dist/cjs/index.cjs \
  /opt/app/etherpad-lite/src/node/server.ts \
  --sessionkey /var/sandstorm/keys/SESSIONKEY.txt \
  --apikey /var/sandstorm/keys/APIKEY.txt
