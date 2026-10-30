#!/usr/bin/env bash
# Build the Perplexity Sudoku SPK on dregg-forge (root, x86_64). Idempotent.
set -euo pipefail
# Run in a private mount namespace: the smoke rootfs's /proc mount cannot leak to, or be unmounted by,
# anything else, and it vanishes with this process.
if [[ ${1:-} != --private-mount-namespace ]]; then
  exec unshare --mount --propagation private bash "$0" --private-mount-namespace
fi
BASE=/srv/spk-build/kiwix
RECIPE="$BASE/recipe"; WORK="$BASE/work"; BUNDLE="$BASE/package"; ROOTFS="$BUNDLE/rootfs"
OUT="$BASE/out"; LOGS="$BASE/logs"
SPK=/var/lib/spk-fresh/tools/spk
INCLUDE=/var/lib/spk-fresh/tools/sandstorm-308/usr/include
BRIDGE=/var/lib/spk-fresh/tools/sandstorm-308/bin/sandstorm-http-bridge
KEYRING="$BASE/kiwix.key"
KT_VERSION=3.8.2
KT_SHA256=b0ae98dd344aa0469a15ab42feff6d5aafb79541a82fb4e2647c74b073123815
KT_URL="https://download.kiwix.org/release/kiwix-tools/kiwix-tools_linux-x86_64-$KT_VERSION.tar.gz"
EXPECTED_APP_ID=7xx4myv7aafdqtm4rh4fj3ju1eck9dfqnnjca3y6513gradphzv0
PACKAGES=(bash coreutils python3)
[[ $(id -u) -eq 0 && -x $SPK && -s $KEYRING && $(stat -c %a "$KEYRING") == 600 ]]
[[ $(cat "$BASE/app-id") == "$EXPECTED_APP_ID" ]]
mkdir -p "$WORK" "$BUNDLE" "$OUT" "$LOGS"
curl -fL --retry 3 -o "$WORK/kt.tar.gz" "$KT_URL"
printf '%s  %s\n' "$KT_SHA256" "$WORK/kt.tar.gz" | sha256sum -c -
rm -rf "$ROOTFS" "$WORK/src"; mkdir -p "$WORK/src"
tar -xzf "$WORK/kt.tar.gz" -C "$WORK/src" --strip-components=1
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
install -m 755 "$WORK/src/kiwix-serve" "$ROOTFS/opt/app/kiwix-serve"
cp "$RECIPE/adapter.py" "$RECIPE/launcher.sh" "$ROOTFS/opt/app/"; chmod 755 "$ROOTFS/opt/app/launcher.sh"
cp -a "$BRIDGE" "$ROOTFS/sandstorm-http-bridge"
printf '%s\n' "$KT_VERSION" > "$ROOTFS/opt/app/UPSTREAM_VERSION"
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
python3 -I "$RECIPE/smoke.py" http://127.0.0.1:8000 "$RECIPE/test.zim" | tee "$OUT/smoke.json"
cleanup; trap - EXIT
assert_no_mounts
rm -rf "$ROOTFS/var" "$ROOTFS/tmp" "$ROOTFS/dev" "$ROOTFS/proc"; mkdir -p "$ROOTFS/var" "$ROOTFS/tmp"; chmod 1777 "$ROOTFS/tmp"
find "$ROOTFS" -name __pycache__ -prune -exec rm -rf {} +
printf '%s\n' sandstorm-manifest sandstorm-http-bridge-config sandstorm-http-bridge > "$BUNDLE/sandstorm-files.list"
cp "$RECIPE/sandstorm-pkgdef.capnp" "$RECIPE/description.md" "$RECIPE/changelog.md" "$RECIPE/kiwix.svg" "$RECIPE/version.txt" "$BUNDLE/"
( cd "$BUNDLE" && "$SPK" pack -I"$INCLUDE" -k"$KEYRING" -p"sandstorm-pkgdef.capnp:pkgdef" "$OUT/kiwix.spk" )
"$SPK" verify --details "$OUT/kiwix.spk" | tee "$LOGS/verify-details.txt"
sha256sum "$OUT/kiwix.spk" | tee "$OUT/kiwix.spk.sha256"
date -u +%Y-%m-%dT%H:%M:%SZ > "$OUT/build-date-utc.txt"
