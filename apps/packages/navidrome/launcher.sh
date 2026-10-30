#!/bin/bash
set -euo pipefail
export HOME=/var PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
mkdir -p /var/navidrome /var/music /var/tmp
cd /var/navidrome
export ND_DATAFOLDER=/var/navidrome ND_MUSICFOLDER=/var/music ND_ADDRESS=127.0.0.1 ND_PORT=48191
export ND_REVERSEPROXYUSERHEADER=X-Navidrome-User ND_REVERSEPROXYWHITELIST=127.0.0.0/8
export ND_SCANSCHEDULE=0 ND_LOGLEVEL=warn ND_ENABLEINSIGHTSCOLLECTOR=false ND_ENABLETRANSCODINGCONFIG=false
export ND_ENABLESHARING=false ND_SESSIONTIMEOUT=24h
/opt/app/navidrome &
nd_pid=$!
trap 'kill "$nd_pid" 2>/dev/null || true' EXIT TERM INT
for _ in $(seq 1 100); do
  (exec 3<>/dev/tcp/127.0.0.1/48191) 2>/dev/null && break
  kill -0 "$nd_pid"
  sleep 0.2
done
cd /var
/usr/bin/python3 /opt/app/adapter.py &
ad_pid=$!
wait -n "$nd_pid" "$ad_pid"
