#!/usr/bin/env bash
# Build the Perplexity Sudoku SPK on dregg-forge (root, x86_64). Idempotent.
set -euo pipefail
# Run in a private mount namespace: the smoke rootfs's /proc mount cannot leak to, or be unmounted by,
# anything else, and it vanishes with this process.
if [[ ${1:-} != --private-mount-namespace ]]; then
  exec unshare --mount --propagation private bash "$0" --private-mount-namespace
fi
BASE=/srv/spk-build/navidrome
RECIPE="$BASE/recipe"; WORK="$BASE/work"; BUNDLE="$BASE/package"; ROOTFS="$BUNDLE/rootfs"
OUT="$BASE/out"; LOGS="$BASE/logs"
SPK=/var/lib/spk-fresh/tools/spk
INCLUDE=/var/lib/spk-fresh/tools/sandstorm-308/usr/include
BRIDGE=/var/lib/spk-fresh/tools/sandstorm-308/bin/sandstorm-http-bridge
KEYRING="$BASE/navidrome.key"
ND_VERSION=0.64.2
ND_SHA256=fdd87fd107818667c2c50bc24dc6ce856962c795b3822a91f95c066cfad2c53e
ND_URL="https://github.com/navidrome/navidrome/releases/download/v$ND_VERSION/navidrome_${ND_VERSION}_linux_amd64.tar.gz"
EXPECTED_APP_ID=cvs53nmnfn463htz3yyyr8zunufczacrdg31n14j61n7g4dpeadh
PACKAGES=(bash coreutils python3 ca-certificates)
[[ $(id -u) -eq 0 && -x $SPK && -s $KEYRING && $(stat -c %a "$KEYRING") == 600 ]]
[[ $(cat "$BASE/app-id") == "$EXPECTED_APP_ID" ]]
mkdir -p "$WORK" "$BUNDLE" "$OUT" "$LOGS"
curl -fL --retry 3 -o "$WORK/nd.tar.gz" "$ND_URL"
printf '%s  %s\n' "$ND_SHA256" "$WORK/nd.tar.gz" | sha256sum -c -
rm -rf "$ROOTFS" "$WORK/src"; mkdir -p "$WORK/src"
tar -xzf "$WORK/nd.tar.gz" -C "$WORK/src"
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
install -m 755 "$WORK/src/navidrome" "$ROOTFS/opt/app/navidrome"; install -m 644 "$WORK/src/LICENSE" "$ROOTFS/opt/app/LICENSE"
cp "$RECIPE/adapter.py" "$RECIPE/launcher.sh" "$ROOTFS/opt/app/"; chmod 755 "$ROOTFS/opt/app/launcher.sh"
cp -a "$BRIDGE" "$ROOTFS/sandstorm-http-bridge"
printf '%s\n' "$ND_VERSION" > "$ROOTFS/opt/app/UPSTREAM_VERSION"
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
mknod -m 666 "$ROOTFS/dev/null" c 1 3; mknod -m 666 "$ROOTFS/dev/zero" c 1 5; mknod -m 666 "$ROOTFS/dev/full" c 1 7
mknod -m 666 "$ROOTFS/dev/random" c 1 8; mknod -m 666 "$ROOTFS/dev/urandom" c 1 9
mount -t proc proc "$ROOTFS/proc"
setsid chroot --userspec=65534:65534 "$ROOTFS" /usr/bin/env -i PATH=/usr/local/bin:/usr/bin:/bin HOME=/var TMPDIR=/var/tmp /bin/bash /opt/app/launcher.sh > "$LOGS/smoke.log" 2>&1 &
echo $! > "$BASE/smoke.pid"
sleep 3
python3 -I "$RECIPE/smoke.py" http://127.0.0.1:8000 | tee "$OUT/smoke.json"
cleanup; trap - EXIT
assert_no_mounts
rm -rf "$ROOTFS/var" "$ROOTFS/tmp" "$ROOTFS/dev" "$ROOTFS/proc"; mkdir -p "$ROOTFS/var" "$ROOTFS/tmp"; chmod 1777 "$ROOTFS/tmp"
find "$ROOTFS" -name __pycache__ -prune -exec rm -rf {} +
printf '%s\n' sandstorm-manifest sandstorm-http-bridge-config sandstorm-http-bridge > "$BUNDLE/sandstorm-files.list"
cp "$RECIPE/sandstorm-pkgdef.capnp" "$RECIPE/description.md" "$RECIPE/changelog.md" "$RECIPE/navidrome.svg" "$RECIPE/version.txt" "$BUNDLE/"
( cd "$BUNDLE" && "$SPK" pack -I"$INCLUDE" -k"$KEYRING" -p"sandstorm-pkgdef.capnp:pkgdef" "$OUT/navidrome.spk" )
"$SPK" verify --details "$OUT/navidrome.spk" | tee "$LOGS/verify-details.txt"
sha256sum "$OUT/navidrome.spk" | tee "$OUT/navidrome.spk.sha256"
date -u +%Y-%m-%dT%H:%M:%SZ > "$OUT/build-date-utc.txt"
