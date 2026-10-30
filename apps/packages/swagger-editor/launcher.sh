#!/bin/bash
set -euo pipefail

export HOME=/var
export NODE_ENV=production
cd /opt/app/swagger-editor
exec /opt/app/node/bin/node /opt/app/static-server.js
