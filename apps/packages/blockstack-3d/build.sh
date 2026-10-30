#!/usr/bin/env bash
# Build the 3D Blockstack SPK on dregg-forge (root, x86_64). Idempotent.
set -euo pipefail
BASE=/srv/spk-build/blockstack
RECIPE="$BASE/recipe"; WORK="$BASE/work"; BUNDLE="$BASE/package"; ROOTFS="$BUNDLE/rootfs"
OUT="$BASE/out"; LOGS="$BASE/logs"
SPK=/var/lib/spk-fresh/tools/spk
INCLUDE=/var/lib/spk-fresh/tools/sandstorm-308/usr/include
BRIDGE=/var/lib/spk-fresh/tools/sandstorm-308/bin/sandstorm-http-bridge
KEYRING="$BASE/blockstack.key"
SRC_SHA=2c1ecb27ee5dc1a8a787b7feffa380986f2f1972
SRC_URL="https://github.com/ocdtrekkie/3D-Blockstack-sandstorm/archive/$SRC_SHA.tar.gz"
EXPECTED_APP_ID=reh7pa3e7jt8ryvjgje97ke5rkyztfg70grru8dewevmunj6ugn0
PACKAGES=(bash coreutils nginx php-fpm php-sqlite3)
[[ $(id -u) -eq 0 && -x $SPK && -s $KEYRING && $(stat -c %a "$KEYRING") == 600 ]]
[[ $(cat "$BASE/app-id") == "$EXPECTED_APP_ID" ]]
mkdir -p "$WORK" "$BUNDLE" "$OUT" "$LOGS"
curl -fL --retry 3 -o "$WORK/src.tar.gz" "$SRC_URL"
rm -rf "$ROOTFS" "$WORK/src"; mkdir -p "$WORK/src"
tar -xzf "$WORK/src.tar.gz" -C "$WORK/src" --strip-components=1
debootstrap --variant=minbase trixie "$ROOTFS" http://deb.debian.org/debian
printf '#!/bin/sh\nexit 101\n' > "$ROOTFS/usr/sbin/policy-rc.d"; chmod 755 "$ROOTFS/usr/sbin/policy-rc.d"
cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf"
chroot "$ROOTFS" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get update
chroot "$ROOTFS" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${PACKAGES[@]}"
chroot "$ROOTFS" /usr/bin/dpkg-query -W -f='${Package}=${Version}\n' > "$LOGS/debian-package-versions.txt"
rm -f "$ROOTFS/usr/sbin/policy-rc.d" "$ROOTFS/etc/resolv.conf"
rm -rf "$ROOTFS/var/lib/apt/lists" "$ROOTFS/var/cache/apt"/* "$ROOTFS/usr/share/doc" "$ROOTFS/usr/share/man" \
  "$ROOTFS/usr/share/info" "$ROOTFS/usr/share/locale"
mkdir -p "$ROOTFS/opt/app"
mkdir -p "$ROOTFS/opt/app/site"
(cd "$WORK/src" && tar --exclude=./.git --exclude=./.github --exclude=./.sandstorm --exclude=./preview -cf - .) | tar -xf - -C "$ROOTFS/opt/app/site"
cp "$RECIPE/launcher.sh" "$RECIPE/nginx.conf" "$RECIPE/php-fpm.conf" "$ROOTFS/opt/app/"; chmod 755 "$ROOTFS/opt/app/launcher.sh"
cp -a "$BRIDGE" "$ROOTFS/sandstorm-http-bridge"
printf '%s\n' "$SRC_SHA" > "$ROOTFS/opt/app/UPSTREAM_COMMIT"
# smoke in a chroot as the grain user
mkdir -p "$ROOTFS/var" "$ROOTFS/tmp" "$ROOTFS/dev" "$ROOTFS/proc"; chmod 1777 "$ROOTFS/tmp"
chown -R 65534:65534 "$ROOTFS/var"
cleanup() { [[ -f $BASE/smoke.pid ]] && kill "$(cat "$BASE/smoke.pid")" 2>/dev/null || true; rm -f "$BASE/smoke.pid"
  umount "$ROOTFS/proc" 2>/dev/null || true; umount -R "$ROOTFS/dev" 2>/dev/null || true; }
trap cleanup EXIT
mount --rbind /dev "$ROOTFS/dev"; mount --make-rslave "$ROOTFS/dev"; mount -t proc proc "$ROOTFS/proc"
chroot --userspec=65534:65534 "$ROOTFS" /usr/bin/env -i PATH=/usr/local/bin:/usr/bin:/bin HOME=/var TMPDIR=/var/tmp /bin/bash /opt/app/launcher.sh > "$LOGS/smoke.log" 2>&1 &
echo $! > "$BASE/smoke.pid"
for i in $(seq 1 40); do curl -fs -o /dev/null http://127.0.0.1:8000/ && break; sleep 1; done
python3 -I "$RECIPE/smoke.py" http://127.0.0.1:8000 | tee "$OUT/smoke.json"
cleanup; trap - EXIT
rm -rf "$ROOTFS/var" "$ROOTFS/tmp" "$ROOTFS/dev" "$ROOTFS/proc"; mkdir -p "$ROOTFS/var" "$ROOTFS/tmp"; chmod 1777 "$ROOTFS/tmp"
find "$ROOTFS" -name __pycache__ -prune -exec rm -rf {} +
printf '%s\n' sandstorm-manifest sandstorm-http-bridge-config sandstorm-http-bridge > "$BUNDLE/sandstorm-files.list"
cp "$RECIPE/sandstorm-pkgdef.capnp" "$RECIPE/description.md" "$RECIPE/changelog.md" "$WORK/src/bigicon.png" "$RECIPE/version.txt" "$BUNDLE/"
( cd "$BUNDLE" && "$SPK" pack -I"$INCLUDE" -k"$KEYRING" -p"sandstorm-pkgdef.capnp:pkgdef" "$OUT/3d-blockstack.spk" )
"$SPK" verify --details "$OUT/3d-blockstack.spk" | tee "$LOGS/verify-details.txt"
sha256sum "$OUT/3d-blockstack.spk" | tee "$OUT/3d-blockstack.spk.sha256"
date -u +%Y-%m-%dT%H:%M:%SZ > "$OUT/build-date-utc.txt"
