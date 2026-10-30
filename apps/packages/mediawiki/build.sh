#!/usr/bin/env bash
set -euo pipefail

BASE=/srv/spk-build/mediawiki
RECIPE="$BASE/recipe"
DOWNLOADS="$BASE/downloads"
WORK="$BASE/work"
BUNDLE="$BASE/package"
ROOTFS="$BUNDLE/rootfs"
APP_SRC="$WORK/mediawiki-1.46.2"
OUT="$BASE/out"
LOGS="$BASE/logs"
SPK=/var/lib/spk-fresh/tools/spk
INCLUDE=/var/lib/spk-fresh/tools/sandstorm-308/usr/include
BRIDGE=/var/lib/spk-fresh/tools/sandstorm-308/bin/sandstorm-http-bridge
KEYRING="$BASE/mediawiki.key"
UPSTREAM_URL=https://releases.wikimedia.org/mediawiki/1.46/mediawiki-1.46.2.tar.gz
UPSTREAM_TARBALL="$DOWNLOADS/mediawiki-1.46.2.tar.gz"
UPSTREAM_SHA256=8f7f937f8bbc1acd4cef1c5362a95f248dcd242020f2588798eb2f73ac2e69ba
EXPECTED_APP_ID=vhq5azzdxf68v536fh0je6ckz6wp56f82t3swt2ws3x91nwk19ch
PACKAGES=(
  bash ca-certificates coreutils diffutils nginx
  php-cli php-fpm php-curl php-gd php-intl php-mbstring php-sqlite3 php-xml
)
BASE_PACKAGES="$BASE/base-packages.txt"
SMOKE_PID_FILE="$LOGS/smoke.pid"

[[ $(id -u) -eq 0 ]]
[[ $(uname -m) == x86_64 ]]
[[ -x $SPK && -d $INCLUDE && -x $BRIDGE ]]
[[ -s $KEYRING && $(stat -c %a "$KEYRING") == 600 ]]
[[ $(cat "$BASE/app-id") == "$EXPECTED_APP_ID" ]]
[[ $ROOTFS == /srv/spk-build/mediawiki/package/rootfs ]]
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
  chroot "$ROOTFS" /usr/bin/env DEBIAN_FRONTEND=noninteractive \
    apt-get update
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
  "$BUNDLE/mediawiki.svg" "$BUNDLE/version.txt" "$BUNDLE/description.md" "$BUNDLE/changelog.md"
tar -xzf "$UPSTREAM_TARBALL" -C "$APP_SRC" --strip-components=1
python3 -I "$RECIPE/adapt.py" "$APP_SRC"
cp -a "$APP_SRC" "$ROOTFS/opt/app/mediawiki"
cp -a "$RECIPE/SandstormAuth-extension" "$ROOTFS/opt/app/mediawiki/extensions/SandstormAuth"
cp "$RECIPE/LocalSettings.php" "$RECIPE/launcher.sh" "$RECIPE/nginx.conf" \
  "$RECIPE/php-fpm.conf" "$RECIPE/version.txt" "$ROOTFS/opt/app/"
chmod 755 "$ROOTFS/opt/app/launcher.sh"
chroot "$ROOTFS" /usr/bin/php8.4 -l /opt/app/LocalSettings.php
chroot "$ROOTFS" /usr/bin/php8.4 -l \
  /opt/app/mediawiki/extensions/SandstormAuth/includes/SandstormSessionProvider.php

# Build a real initial wiki without carrying a LocalSettings.php or password
# database from the old package. The generated admin password is discarded;
# SandstormAuth is the package's only web identity provider.
admin_password="$(openssl rand -base64 48)"
chroot "$ROOTFS" /usr/bin/php8.4 /opt/app/mediawiki/maintenance/install.php \
  --dbtype sqlite --dbpath /var/wiki --dbname wiki --lang en \
  --server http://localhost "--scriptpath=" --pass "$admin_password" \
  Wiki SandstormAdmin
unset admin_password
printf '<?php $wgSecretKey = "%s";\n' "$(openssl rand -base64 48)" > "$ROOTFS/var/wgSecretKey.php"
cp "$RECIPE/LocalSettings.php" "$ROOTFS/opt/app/mediawiki/LocalSettings.php"
chroot "$ROOTFS" /usr/bin/php8.4 /opt/app/mediawiki/maintenance/update.php --quick
mkdir -p "$ROOTFS/opt/app/init-var"
mv "$ROOTFS/var/wiki" "$ROOTFS/opt/app/init-var/wiki"
chmod -R a+rX "$ROOTFS/opt/app/init-var"
cp "$RECIPE/version.txt" "$ROOTFS/opt/app/init-var/VERSION"
cp "$RECIPE/sandstorm-pkgdef.capnp" "$RECIPE/sandstorm-files.list" \
  "$RECIPE/mediawiki.svg" "$RECIPE/version.txt" "$RECIPE/description.md" \
  "$RECIPE/changelog.md" "$BUNDLE/"
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

"$RECIPE/prune.sh"

(
  cd "$BUNDLE"
  "$SPK" pack -I"$INCLUDE" -k"$KEYRING" -p"sandstorm-pkgdef.capnp:pkgdef" "$OUT/mediawiki.spk"
)
"$SPK" verify --details "$OUT/mediawiki.spk" | tee "$LOGS/verify-details.txt"
sha256sum "$OUT/mediawiki.spk" | tee "$OUT/mediawiki.spk.sha256"
date -u +%Y-%m-%dT%H:%M:%SZ > "$OUT/build-date-utc.txt"
printf 'artifact=%s\n' "$OUT/mediawiki.spk"
