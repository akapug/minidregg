#!/bin/bash
set -euo pipefail
BASE=/srv/spk-build/scrumblr
PKG=$BASE/package-0.5-1
ROOTFS=$PKG/rootfs
OUT=$BASE/out
LOGS=$BASE/logs
SPK=/var/lib/spk-fresh/tools/spk
INCLUDE=/var/lib/spk-fresh/tools/sandstorm-308/usr/include
KEYRING=$BASE/scrumblr.key
KEYHOME=$BASE/keyhome
SMOKE_PID_FILE=$LOGS/smoke.pid

[[ $(id -u) -eq 0 ]]
[[ -x $SPK && -d $INCLUDE ]]

# --- 1. keyring (idempotent)
if [[ ! -s $KEYRING ]]; then
  mkdir -p "$KEYHOME"
  HOME="$KEYHOME" "$SPK" keygen
  mv "$KEYHOME/.sandstorm-keyring" "$KEYRING"
fi
chmod 600 "$KEYRING"

# --- 2. chroot smoke test of the assembled rootfs
cleanup_smoke() {
  if [[ -f $SMOKE_PID_FILE ]]; then
    local pid; pid=$(cat "$SMOKE_PID_FILE")
    kill "$pid" 2>/dev/null || true
  fi
  if [[ -f $ROOTFS/var/redis/redis.pid ]]; then
    local rpid; rpid=$(cat "$ROOTFS/var/redis/redis.pid")
    kill "$rpid" 2>/dev/null || true
  fi
  # let the killed processes actually die before unmounting
  for i in $(seq 1 100); do
    local alive=0
    [[ -f $SMOKE_PID_FILE ]] && kill -0 "$(cat "$SMOKE_PID_FILE")" 2>/dev/null && alive=1
    [[ -f $ROOTFS/var/redis/redis.pid ]] && kill -0 "$(cat "$ROOTFS/var/redis/redis.pid")" 2>/dev/null && alive=1
    [[ $alive -eq 0 ]] && break
    sleep 0.1
  done
  umount "$ROOTFS/dev" 2>/dev/null || umount -l "$ROOTFS/dev" 2>/dev/null || true
  umount "$ROOTFS/proc" 2>/dev/null || umount -l "$ROOTFS/proc" 2>/dev/null || true
}
trap cleanup_smoke EXIT

chown -R 65534:65534 "$ROOTFS/var"
chmod 1777 "$ROOTFS/tmp"
mkdir -p "$ROOTFS/dev" "$ROOTFS/proc"
# this host's /dev is minimal (no zero/urandom; tools use getrandom(2));
# binding it whole matches the configuration the smoke test validates.
mount --bind /dev "$ROOTFS/dev"
mount --bind /proc "$ROOTFS/proc"
nohup chroot --userspec=65534:65534 "$ROOTFS" /bin/bash /opt/app/launcher.sh \
  > "$LOGS/smoke.log" 2>&1 < /dev/null &
echo "$!" > "$SMOKE_PID_FILE"

smoke_ok=0
for i in $(seq 1 120); do
  code=$(curl -s -o "$LOGS/smoke-root.html" -w '%{http_code}' http://127.0.0.1:8080/ || true)
  if [[ $code == 200 ]]; then smoke_ok=1; break; fi
  if ! kill -0 "$(cat "$SMOKE_PID_FILE")" 2>/dev/null; then break; fi
  sleep 1
done
if [[ $smoke_ok -ne 1 ]]; then
  echo "SMOKE FAILED (last http_code=$code)" >&2
  tail -20 "$LOGS/smoke.log" >&2 || true
  exit 1
fi
if ! grep -qi "<html\|<!doctype" "$LOGS/smoke-root.html"; then
  echo "SMOKE FAILED (no HTML in response)" >&2
  head -5 "$LOGS/smoke-root.html" >&2 || true
  exit 1
fi
echo "SMOKE OK (http 200, html served)"
cleanup_smoke
trap - EXIT

# reset grain-writable state before packing
cleanup_smoke
trap - EXIT
for m in dev proc; do
  if grep -qs " $ROOTFS/$m " /proc/mounts; then
    echo "REFUSING rm: $ROOTFS/$m still mounted" >&2
    exit 1
  fi
done
rm -rf "$ROOTFS/var" "$ROOTFS/dev" "$ROOTFS/proc"
mkdir -p "$ROOTFS/var" "$ROOTFS/tmp"

# --- 3. pack + verify
mkdir -p "$OUT"
(
  cd "$PKG"
  "$SPK" pack -I"$INCLUDE" -k"$KEYRING" -p"sandstorm-pkgdef.capnp:pkgdef" \
    "$OUT/scrumblr-0.5-1.spk"
)
"$SPK" verify --details "$OUT/scrumblr-0.5-1.spk" | tee "$LOGS/verify-details.txt"
sha256sum "$OUT/scrumblr-0.5-1.spk" | tee "$OUT/scrumblr-0.5-1.spk.sha256"
date -u +%Y-%m-%dT%H:%M:%SZ > "$OUT/build-date-utc.txt"

# app id: spk pack rewrites the id in the pkgdef to the keyring's app id
appid=$(sed -n 's/^.*id = "\([a-z0-9]\+\)".*/\1/p' "$PKG/sandstorm-pkgdef.capnp" | head -1)
printf '%s\n' "$appid" > "$BASE/app-id"
echo "APP_ID=$appid"
echo "PACK OK: $OUT/scrumblr-0.5-1.spk"
