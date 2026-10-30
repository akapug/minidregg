#!/usr/bin/env bash
# Build the 3D Blockstack SPK on dregg-forge (root, x86_64). Idempotent.
set -euo pipefail
# Run in a private mount namespace: the smoke rootfs's /proc mount cannot leak to, or be unmounted by,
# anything else, and it vanishes with this process.
if [[ ${1:-} != --private-mount-namespace ]]; then
  exec unshare --mount --propagation private bash "$0" --private-mount-namespace
fi
BASE=/srv/spk-build/firefly
RECIPE="$BASE/recipe"; WORK="$BASE/work"; BUNDLE="$BASE/package"; ROOTFS="$BUNDLE/rootfs"
OUT="$BASE/out"; LOGS="$BASE/logs"
SPK=/var/lib/spk-fresh/tools/spk
INCLUDE=/var/lib/spk-fresh/tools/sandstorm-308/usr/include
BRIDGE=/var/lib/spk-fresh/tools/sandstorm-308/bin/sandstorm-http-bridge
KEYRING="$BASE/firefly.key"
FF_VERSION=6.7.9
FF_SHA256=f905729c3be6e66d5333c22992281224ef1dc7e21cea13f4ef09af643d09b825
FF_URL="https://github.com/firefly-iii/firefly-iii/releases/download/v$FF_VERSION/FireflyIII-v$FF_VERSION.tar.gz"
SURY_FPR=15058500A0235D97F5D10063B188E2B695BD4743
EXPECTED_APP_ID=cd6fk64x5ndeem7ya2t3qfjkjsjjhts5y2eg54jpdy0g0whtwx40
PACKAGES=(bash coreutils nginx ca-certificates curl gnupg)
PHP_PACKAGES=(php8.5-fpm php8.5-cli php8.5-bcmath php8.5-curl php8.5-gd php8.5-intl php8.5-mbstring php8.5-sqlite3 php8.5-xml php8.5-zip)
[[ $(id -u) -eq 0 && -x $SPK && -s $KEYRING && $(stat -c %a "$KEYRING") == 600 ]]
[[ $(cat "$BASE/app-id") == "$EXPECTED_APP_ID" ]]
mkdir -p "$WORK" "$BUNDLE" "$OUT" "$LOGS"
curl -fL --retry 3 -o "$WORK/ff.tar.gz" "$FF_URL"
printf '%s  %s\n' "$FF_SHA256" "$WORK/ff.tar.gz" | sha256sum -c -
rm -rf "$ROOTFS" "$WORK/src"; mkdir -p "$WORK/src"
tar -xzf "$WORK/ff.tar.gz" -C "$WORK/src"
curl -fL --retry 3 -o "$WORK/sury.gpg" https://packages.sury.org/php/apt.gpg
[[ $(gpg --show-keys --with-colons "$WORK/sury.gpg" | awk -F: '/^fpr/ {print $10; exit}') == "$SURY_FPR" ]] \
  || { echo "FATAL: sury signing key fingerprint mismatch" >&2; exit 1; }
debootstrap --variant=minbase trixie "$ROOTFS" http://deb.debian.org/debian
printf '#!/bin/sh\nexit 101\n' > "$ROOTFS/usr/sbin/policy-rc.d"; chmod 755 "$ROOTFS/usr/sbin/policy-rc.d"
cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf"
APT="chroot $ROOTFS /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get"
$APT update
$APT install -y --no-install-recommends "${PACKAGES[@]}"
gpg --dearmor < "$WORK/sury.gpg" > "$ROOTFS/usr/share/keyrings/sury-php.gpg"
echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ trixie main" > "$ROOTFS/etc/apt/sources.list.d/sury-php.list"
$APT update
$APT install -y --no-install-recommends "${PHP_PACKAGES[@]}"
$APT purge -y --auto-remove curl gnupg
chroot "$ROOTFS" /usr/bin/dpkg-query -W -f='${Package}=${Version}\n' > "$LOGS/debian-package-versions.txt"
rm -f "$ROOTFS/usr/sbin/policy-rc.d" "$ROOTFS/etc/resolv.conf" "$ROOTFS/etc/apt/sources.list.d/sury-php.list"
rm -rf "$ROOTFS/var/lib/apt/lists" "$ROOTFS/var/cache/apt"/* "$ROOTFS/usr/share/doc" "$ROOTFS/usr/share/man" \
  "$ROOTFS/usr/share/info" "$ROOTFS/usr/share/locale"
mkdir -p "$ROOTFS/opt/app"
(cd "$WORK/src" && tar --exclude=./tests --exclude=./.git -cf - .) | (mkdir -p "$ROOTFS/opt/app/firefly" && tar -xf - -C "$ROOTFS/opt/app/firefly")
rm -rf "$ROOTFS/opt/app/firefly/node_modules"
# The single local patch: the API guard accepts the Sandstorm identity (remote_user_guard) instead of an OAuth
# bearer token, so the package's api interface works for the member the bridge authenticated. Upstream's own
# remote_user_guard only replaces the web guard.
python3 - "$ROOTFS/opt/app/firefly/config/auth.php" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = """        'api'               => [
            'driver'   => 'passport',
            'provider' => 'users',
        ],"""
new = """        'api'               => env_default_when_empty(env('AUTHENTICATION_GUARD'), 'web') === 'remote_user_guard'
            ? ['driver' => 'remote_user_guard', 'provider' => 'remote_user_provider']
            : ['driver' => 'passport', 'provider' => 'users'],"""
if old not in s:
    sys.exit("FATAL: config/auth.php api guard block not found; the patch needs updating for this Firefly release")
open(p, "w").write(s.replace(old, new))
PY
cp "$RECIPE/launcher.sh" "$RECIPE/nginx.conf" "$RECIPE/php-fpm.conf" "$RECIPE/version.txt" "$ROOTFS/opt/app/"; chmod 755 "$ROOTFS/opt/app/launcher.sh"
cp -a "$BRIDGE" "$ROOTFS/sandstorm-http-bridge"
printf '%s\n' "$FF_VERSION" > "$ROOTFS/opt/app/UPSTREAM_VERSION"
# A real initial ledger: migrate and seed an SQLite database at build time; state moves to /var/firefly at
# first start. The build-time APP_KEY is discarded; each grain draws its own.
FFROOT="$ROOTFS/opt/app/firefly"
mkdir -p "$ROOTFS/var/firefly"
cat > "$FFROOT/.env" <<ENV
APP_ENV=production
APP_DEBUG=false
APP_KEY=$(head -c 24 /dev/urandom | base64)
SITE_OWNER=owner@localhost.invalid
TZ=UTC
DB_CONNECTION=sqlite
DB_DATABASE=/var/firefly/database.sqlite
CACHE_DRIVER=file
SESSION_DRIVER=file
ENV
: > "$ROOTFS/var/firefly/database.sqlite"
chroot "$ROOTFS" /bin/bash -c 'cd /opt/app/firefly && /usr/bin/php8.5 artisan migrate --seed --force && /usr/bin/php8.5 artisan firefly-iii:upgrade-database'
rm -f "$FFROOT/.env"
INIT="$ROOTFS/opt/app/init-var"; mkdir -p "$INIT"
mv "$ROOTFS/var/firefly/database.sqlite" "$INIT/database.sqlite"
mv "$FFROOT/storage" "$INIT/storage"; ln -s /var/firefly/storage "$FFROOT/storage"
mkdir -p "$FFROOT/bootstrap/cache"; mv "$FFROOT/bootstrap/cache" "$INIT/bootstrap-cache"; ln -s /var/firefly/bootstrap-cache "$FFROOT/bootstrap/cache"
ln -s /var/firefly/.env "$FFROOT/.env"
rm -f "$INIT"/storage/oauth-*.key
chmod -R a+rX "$INIT"; rm -rf "$ROOTFS/var/firefly"
cp "$RECIPE/version.txt" "$INIT/VERSION.new"; rm -f "$INIT/VERSION.new"
# smoke in a chroot as the grain user
mkdir -p "$ROOTFS/var" "$ROOTFS/tmp" "$ROOTFS/dev" "$ROOTFS/proc"; chmod 1777 "$ROOTFS/tmp"
chown -R 65534:65534 "$ROOTFS/var"
# /dev is a few mknod'd nodes INSIDE the rootfs; the host's /dev is never bind-mounted. Only /proc is a
# mount. Nothing under $ROOTFS is removed unless findmnt shows no mount left beneath it.
assert_no_mounts() {
  if findmnt -rn -o TARGET | grep -F "$ROOTFS/" >&2; then
    echo "FATAL: mounts remain under $ROOTFS; refusing to remove anything" >&2; exit 1
  fi
}
cleanup() {
  if [[ -f $BASE/smoke.pid ]]; then
    kill -TERM -- "-$(cat "$BASE/smoke.pid")" 2>/dev/null || true
    for _ in $(seq 1 50); do kill -0 -- "-$(cat "$BASE/smoke.pid")" 2>/dev/null || break; sleep 0.2; done
    rm -f "$BASE/smoke.pid"
  fi
  if findmnt -rn "$ROOTFS/proc" >/dev/null; then
    umount "$ROOTFS/proc" || { echo "FATAL: cannot unmount $ROOTFS/proc" >&2; exit 1; }
  fi
}
trap cleanup EXIT
mkdir -p "$ROOTFS/dev"
for node in null:1:3 zero:1:5 full:1:7 random:1:8 urandom:1:9; do
  IFS=: read -r n maj min <<<"$node"
  [[ -c $ROOTFS/dev/$n ]] || mknod -m 666 "$ROOTFS/dev/$n" c "$maj" "$min"
done
mount -t proc proc "$ROOTFS/proc"
setsid chroot --userspec=65534:65534 "$ROOTFS" /usr/bin/env -i PATH=/usr/local/bin:/usr/bin:/bin HOME=/var TMPDIR=/var/tmp /bin/bash /opt/app/launcher.sh > "$LOGS/smoke.log" 2>&1 &
echo $! > "$BASE/smoke.pid"
for i in $(seq 1 40); do curl -fs -o /dev/null http://127.0.0.1:8000/ && break; sleep 1; done
python3 -I "$RECIPE/smoke.py" http://127.0.0.1:8000 | tee "$OUT/smoke.json"
cleanup; trap - EXIT
assert_no_mounts
rm -rf "$ROOTFS/var" "$ROOTFS/tmp" "$ROOTFS/dev" "$ROOTFS/proc"; mkdir -p "$ROOTFS/var" "$ROOTFS/tmp"; chmod 1777 "$ROOTFS/tmp"
find "$ROOTFS" -name __pycache__ -prune -exec rm -rf {} +
printf '%s\n' sandstorm-manifest sandstorm-http-bridge-config sandstorm-http-bridge > "$BUNDLE/sandstorm-files.list"
cp "$RECIPE/sandstorm-pkgdef.capnp" "$RECIPE/description.md" "$RECIPE/changelog.md" "$RECIPE/firefly.svg" "$RECIPE/version.txt" "$BUNDLE/"
( cd "$BUNDLE" && "$SPK" pack -I"$INCLUDE" -k"$KEYRING" -p"sandstorm-pkgdef.capnp:pkgdef" "$OUT/firefly-iii.spk" )
"$SPK" verify --details "$OUT/firefly-iii.spk" | tee "$LOGS/verify-details.txt"
sha256sum "$OUT/firefly-iii.spk" | tee "$OUT/firefly-iii.spk.sha256"
date -u +%Y-%m-%dT%H:%M:%SZ > "$OUT/build-date-utc.txt"
