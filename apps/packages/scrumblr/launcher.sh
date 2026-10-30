#!/bin/bash
set -euo pipefail

export HOME=/var
export NODE_ENV=production
export TMPDIR=/tmp

mkdir -p /var/redis

# Scrumblr keeps all board state in Redis; run it inside the grain with
# persistence under /var so boards survive grain restarts.
# redis 8 exits when setlocale() fails; grains have no locale data.
LC_ALL=C /opt/app/redis/bin/redis-server \
  --port 6379 \
  --bind 127.0.0.1 \
  --dir /var/redis \
  --pidfile /var/redis/redis.pid \
  --appendonly yes \
  --daemonize yes \
  --logfile /var/redis/redis.log \
  --save ""

# With --daemonize yes redis-server exits only after its child is accepting
# connections, so one sanity ping is enough. Fail loudly if it is not there.
if [[ $(LC_ALL=C /opt/app/redis/bin/redis-cli -h 127.0.0.1 -p 6379 ping 2>/dev/null) != PONG ]]; then
  echo "scrumblr launcher: redis did not start" >&2
  while IFS= read -r line; do echo "redis: $line" >&2; done < /var/redis/redis.log || true
  exit 1
fi

cd /opt/app
exec /opt/app/node/bin/node server.js
