#!/usr/bin/env bash
set -euo pipefail
BASE=/srv/spk-build/mediawiki
ROOTFS="$BASE/package/rootfs"
LOGS="$BASE/logs"
OUT="$BASE/out"
SPK=/srv/spk-build/etherpad/toolchain/sandstorm-308-unpack/sandstorm-308/bin/spk
INCLUDE=/srv/spk-build/etherpad/toolchain/sandstorm-308-unpack/sandstorm-308/usr/include
SMOKE_PID_FILE="$LOGS/repack-smoke.pid"
cleanup_smoke() {
  local file pid
  for file in "$ROOTFS/var/run/nginx-supervisor.pid" "$ROOTFS/var/run/php-fpm-supervisor.pid" "$SMOKE_PID_FILE"; do
    [[ -f $file ]] || continue
    pid=$(cat "$file")
    [[ $pid =~ ^[0-9]+$ ]] || continue
    if kill -0 "$pid" 2>/dev/null; then kill "$pid" 2>/dev/null || true; fi
  done
  if [[ -f $SMOKE_PID_FILE ]]; then
    pid=$(cat "$SMOKE_PID_FILE")
    wait "$pid" 2>/dev/null || true
    rm -f "$SMOKE_PID_FILE"
  fi
}
trap cleanup_smoke EXIT
"$BASE/recipe/prune.sh"
du -sh "$ROOTFS"
chroot "$ROOTFS" /usr/bin/php8.4 -l /opt/app/LocalSettings.php
rm -rf "$ROOTFS/var"
mkdir -p "$ROOTFS/var"
chown -R 65534:65534 "$ROOTFS/var"
chmod 1777 "$ROOTFS/tmp"
nohup chroot --userspec=65534:65534 "$ROOTFS" /bin/bash /opt/app/launcher.sh \
  > "$LOGS/repack-smoke-server.log" 2>&1 < /dev/null &
echo "$!" > "$SMOKE_PID_FILE"
python3 -I "$BASE/recipe/smoke.py" http://127.0.0.1:8000 | tee "$OUT/repack-direct-smoke.json"
cleanup_smoke
trap - EXIT
rm -rf "$ROOTFS/var"
mkdir -p "$ROOTFS/var"
(
  cd "$BASE/package"
  "$SPK" pack -I"$INCLUDE" -k"$BASE/mediawiki.key" \
    -p"sandstorm-pkgdef.capnp:pkgdef" "$OUT/mediawiki.spk"
)
"$SPK" -k"$BASE/mediawiki.key" verify --details "$OUT/mediawiki.spk" | tee "$OUT/repack-verify-details.txt"
sha256sum "$OUT/mediawiki.spk" | tee "$OUT/mediawiki.spk.sha256"
date -u +%Y-%m-%dT%H:%M:%SZ > "$OUT/repack-date-utc.txt"
