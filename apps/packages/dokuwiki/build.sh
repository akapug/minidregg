#!/usr/bin/env bash
set -euo pipefail

BASE=/srv/spk-build/dokuwiki
RECIPE="$BASE/recipe"
DOWNLOADS="$BASE/downloads"
WORK="$BASE/work"
BUNDLE="$BASE/package"
ROOTFS="$BUNDLE/rootfs"
APP_SRC="$WORK/dokuwiki-2026-07-14c"
OUT="$BASE/out"
LOGS="$BASE/logs"
SPK=/var/lib/spk-fresh/tools/spk
INCLUDE=/var/lib/spk-fresh/tools/sandstorm-308/usr/include
BRIDGE=/var/lib/spk-fresh/tools/sandstorm-308/bin/sandstorm-http-bridge
KEYRING="$BASE/dokuwiki.key"
UPSTREAM_URL=https://github.com/dokuwiki/dokuwiki/releases/download/release-2026-07-14c/dokuwiki-2026-07-14c.tgz
UPSTREAM_TARBALL="$DOWNLOADS/dokuwiki-2026-07-14c.tgz"
UPSTREAM_SHA256=7e9b4dcb5ecb91a57f71b9b77dcec7bcf929959881464796611349ed1d183176
EXPECTED_APP_ID=f3c9rjszvmqgvnhan8c6m5cpwkqmwu6t6de0qxa8vnx0rqreafqh
PACKAGES=(
  bash ca-certificates coreutils diffutils nginx rsync
  php-cli php-fpm php-curl php-gd php-intl php-mbstring php-sqlite3 php-xml php-zip
)
BASE_PACKAGES="$BASE/base-packages.txt"
SMOKE_PID_FILE="$LOGS/smoke.pid"

[[ $(id -u) -eq 0 ]]
[[ $(uname -m) == x86_64 ]]
[[ -x $SPK && -d $INCLUDE && -x $BRIDGE ]]
[[ -s $KEYRING && $(stat -c %a "$KEYRING") == 600 ]]
[[ $(cat "$BASE/app-id") == "$EXPECTED_APP_ID" ]]
[[ $ROOTFS == /srv/spk-build/dokuwiki/package/rootfs ]]
mkdir -p "$DOWNLOADS" "$WORK" "$BUNDLE" "$OUT" "$LOGS"

if [[ ! -f $UPSTREAM_TARBALL ]]; then
  curl -fL --retry 3 -o "$UPSTREAM_TARBALL" "$UPSTREAM_URL"
fi
printf '%s  %s\n' "$UPSTREAM_SHA256" "$UPSTREAM_TARBALL" | sha256sum -c -
printf '%s\n' "${PACKAGES[@]}" > "$WORK/expected-packages.txt"

if [[ ! -f $ROOTFS/etc/debian_version ]] || ! cmp -s "$WORK/expected-packages.txt" "$BASE_PACKAGES"; then
  rm -rf "$ROOTFS"
  debootstrap --variant=minbase trixie "$ROOTFS" http://deb.debian.org/debian
  printf '#!/bin/sh\nexit 101\n' > "$ROOTFS/usr/sbin/policy-rc.d"
  chmod 755 "$ROOTFS/usr/sbin/policy-rc.d"
  cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf"
  chroot "$ROOTFS" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get update
  chroot "$ROOTFS" /usr/bin/env DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends "${PACKAGES[@]}"
  rm -f "$ROOTFS/usr/sbin/policy-rc.d" "$ROOTFS/etc/resolv.conf"
  rm -rf "$ROOTFS/var/lib/apt/lists" "$ROOTFS/var/cache/apt"/*
  cp "$WORK/expected-packages.txt" "$BASE_PACKAGES"
fi
chroot "$ROOTFS" /usr/bin/php8.4 -r 'printf("PHP %s\n", PHP_VERSION);'
chroot "$ROOTFS" /usr/bin/dpkg-query -W -f='${Package}=${Version}\n' > "$LOGS/debian-package-versions.txt"

rm -rf "$APP_SRC" "$ROOTFS/opt/app" "$ROOTFS/var"
mkdir -p "$APP_SRC" "$ROOTFS/opt/app" "$ROOTFS/var"
rm -f "$BUNDLE/sandstorm-pkgdef.capnp" "$BUNDLE/sandstorm-files.list" \
  "$BUNDLE/appGrid.png" "$BUNDLE/grain.png" "$BUNDLE/market.png" \
  "$BUNDLE/version.txt" "$BUNDLE/description.md" "$BUNDLE/changelog.md"
tar -xzf "$UPSTREAM_TARBALL" -C "$APP_SRC" --strip-components=1
grep -q '^2026-07-14c ' "$APP_SRC/VERSION"
[[ -f $APP_SRC/vendor/autoload.php ]]
(
  cd "$APP_SRC"
  for path in conf data lib/plugins lib/tpl; do
    mv "$path" "$path.orig"
  done
  ln -s /var/lib/dokuwiki/conf conf
  ln -s /var/lib/dokuwiki/data data
  ln -s /var/lib/dokuwiki/lib/plugins lib/plugins
  ln -s /var/lib/dokuwiki/lib/tpl lib/tpl
)
cp -a "$APP_SRC" "$ROOTFS/opt/app/dokuwiki"
cp -a "$RECIPE/plugin" "$ROOTFS/opt/app/plugin"
cp "$RECIPE/acl.auth.php" "$RECIPE/local.php" "$RECIPE/local.protected.php" \
  "$RECIPE/launcher.sh" "$RECIPE/nginx.conf" "$RECIPE/php-fpm.conf" \
  "$RECIPE/version.txt" "$ROOTFS/opt/app/"
chmod 755 "$ROOTFS/opt/app/launcher.sh"
chroot "$ROOTFS" /usr/bin/php8.4 -l /opt/app/plugin/sandstorm/auth.php
chroot "$ROOTFS" /usr/bin/php8.4 -l /opt/app/local.php
chroot "$ROOTFS" /usr/bin/php8.4 -l /opt/app/local.protected.php
cp "$RECIPE/sandstorm-pkgdef.capnp" "$RECIPE/sandstorm-files.list" \
  "$RECIPE/appGrid.png" "$RECIPE/grain.png" "$RECIPE/market.png" \
  "$RECIPE/version.txt" "$RECIPE/description.md" "$RECIPE/changelog.md" "$BUNDLE/"
cp -a "$BRIDGE" "$ROOTFS/sandstorm-http-bridge"

cleanup_smoke() {
  local file pid
  for file in "$ROOTFS/var/run/nginx-supervisor.pid" "$ROOTFS/var/run/php-fpm-supervisor.pid" "$SMOKE_PID_FILE"; do
    [[ -f $file ]] || continue
    pid=$(cat "$file")
    [[ $pid =~ ^[0-9]+$ ]] || continue
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
  done
  if [[ -f $SMOKE_PID_FILE ]]; then
    pid=$(cat "$SMOKE_PID_FILE")
    wait "$pid" 2>/dev/null || true
    rm -f "$SMOKE_PID_FILE"
  fi
}
trap cleanup_smoke EXIT
chown -R 65534:65534 "$ROOTFS/var"
chmod 1777 "$ROOTFS/tmp"
nohup chroot --userspec=65534:65534 "$ROOTFS" /bin/bash /opt/app/launcher.sh \
  > "$LOGS/smoke.log" 2>&1 < /dev/null &
echo "$!" > "$SMOKE_PID_FILE"
python3 -I "$RECIPE/smoke.py" http://127.0.0.1:8000 | tee "$OUT/direct-smoke.json"
cleanup_smoke
trap - EXIT
rm -rf "$ROOTFS/var"
mkdir -p "$ROOTFS/var"

(
  cd "$BUNDLE"
  "$SPK" pack -I"$INCLUDE" -k"$KEYRING" -p"sandstorm-pkgdef.capnp:pkgdef" "$OUT/dokuwiki.spk"
)
"$SPK" verify --details "$OUT/dokuwiki.spk" | tee "$LOGS/verify-details.txt"
sha256sum "$OUT/dokuwiki.spk" | tee "$OUT/dokuwiki.spk.sha256"
date -u +%Y-%m-%dT%H:%M:%SZ > "$OUT/build-date-utc.txt"
printf 'artifact=%s\n' "$OUT/dokuwiki.spk"
