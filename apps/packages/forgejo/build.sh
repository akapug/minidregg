#!/usr/bin/env bash
set -euo pipefail

# Keep the smoke rootfs's proc/dev mounts private to this build. No sibling
# mount or cleanup can make them disappear, and nothing propagates to the host.
if [[ ${1:-} != --private-mount-namespace ]]; then
  exec unshare --mount --propagation private bash "$0" --private-mount-namespace
fi

BASE=/srv/spk-build/forgejo
RECIPE="$BASE/recipe"
DOWNLOADS="$BASE/downloads"
WORK="$BASE/work"
BUNDLE="$BASE/bundle"
ROOTFS="$BUNDLE/rootfs"
OUT="$BASE/out/forgejo.spk"
SPK=/var/lib/spk-fresh/tools/spk
INCLUDE=/var/lib/spk-fresh/tools/sandstorm-308/usr/include
BRIDGE=/var/lib/spk-fresh/tools/sandstorm-308/bin/sandstorm-http-bridge
KEYRING="$BASE/forgejo.key"
APP_ID=3g05nj7mpryyd3a0erndy30my7fsr72s3xghnhewkqw7km08g34h
VERSION=17.0.1
BINARY_SHA256=51a8cdf4a1252e79f4b3855d7a7891af6c6635105420768c460e2f0690385d6f
SOURCE_SHA256=d6b32ac77e71af0737f30613d985a0dc335b694b8b989d609a0cc88972f2fd4d
BINARY="$DOWNLOADS/forgejo-$VERSION-linux-amd64"
SOURCE="$DOWNLOADS/forgejo-src-$VERSION.tar.gz"

fetch() {
  local url=$1 dest=$2 sha=$3
  if [[ ! -f "$dest" ]]; then
    curl -fL --retry 3 -o "$dest.partial" "$url"
    mv "$dest.partial" "$dest"
  fi
  printf '%s  %s\n' "$sha" "$dest" | sha256sum -c -
}

[[ $(id -u) -eq 0 ]]
[[ -x "$SPK" && -d "$INCLUDE" && -x "$BRIDGE" ]]
[[ $($SPK --version) == 'Sandstorm version 308' ]]
[[ -s "$KEYRING" && $(stat -c %a "$KEYRING") == 600 ]]
[[ -s "$BASE/app-id" && $(<"$BASE/app-id") == "$APP_ID" ]]
[[ $(git --version) == 'git version 2.47.3' ]]
mkdir -p "$DOWNLOADS" "$WORK" "$BASE/out" "$BASE/logs"
rm -f "$BASE/out/build-date-utc"
fetch "https://codeberg.org/forgejo/forgejo/releases/download/v$VERSION/forgejo-$VERSION-linux-amd64" "$BINARY" "$BINARY_SHA256"
fetch "https://codeberg.org/forgejo/forgejo/releases/download/v$VERSION/forgejo-src-$VERSION.tar.gz" "$SOURCE" "$SOURCE_SHA256"

rm -rf "$BUNDLE" "$WORK/upstream"
mkdir -p "$WORK/upstream" "$ROOTFS/opt/app" "$ROOTFS/bin" \
  "$ROOTFS/usr/bin" "$ROOTFS/usr/lib" "$ROOTFS/usr/share" \
  "$ROOTFS/etc/ssl/certs" "$ROOTFS/var" "$ROOTFS/tmp"
chmod 1777 "$ROOTFS/tmp"
tar -xzf "$SOURCE" -C "$WORK/upstream" --strip-components=1 \
  "forgejo-src-$VERSION/assets/logo.svg" "forgejo-src-$VERSION/LICENSE"
install -m 755 "$BINARY" "$ROOTFS/opt/app/forgejo"
install -m 644 "$WORK/upstream/LICENSE" "$ROOTFS/opt/app/LICENSE"
install -m 755 "$RECIPE/launcher.sh" "$ROOTFS/opt/app/launcher.sh"
install -m 644 "$RECIPE/app.ini" "$ROOTFS/opt/app/app.ini.example"
install -m 755 "$BRIDGE" "$ROOTFS/sandstorm-http-bridge"
cp -a /usr/bin/git /usr/bin/env /usr/bin/cat /usr/bin/basename /usr/bin/dirname "$ROOTFS/usr/bin/"
cp -a /usr/lib/git-core "$ROOTFS/usr/lib/"
cp -a /usr/share/git-core "$ROOTFS/usr/share/"
cp -a /bin/bash /bin/dash /bin/sh /bin/mkdir "$ROOTFS/bin/"
cp -a /etc/ssl/certs/ca-certificates.crt "$ROOTFS/etc/ssl/certs/"

# The release binary and bridge are static. Git and the small shell toolset are
# Debian 13 binaries; close over their dynamic dependencies without recursively
# including any host system directory.
RAW_DEPS="$WORK/raw-deps.txt"
: >"$RAW_DEPS"
find "$ROOTFS/bin" "$ROOTFS/usr/bin" "$ROOTFS/usr/lib/git-core" -type f -executable -print0 >"$WORK/executables.bin"
while IFS= read -r -d '' exe; do
  ldd "$exe" 2>/dev/null | awk '/=> \// {print $3} /^[[:space:]]*\// {print $1}' >>"$RAW_DEPS" || true
done <"$WORK/executables.bin"
sort -u "$RAW_DEPS" >"$WORK/sorted-deps.txt"
while IFS= read -r path; do
  [[ -e "$path" ]] || continue
  rel=${path#/}
  mkdir -p "$ROOTFS/$(dirname "$rel")"
  # The host has merged-/usr symlinks. The package rootfs deliberately has
  # ordinary /lib and /lib64 directories, so put each dependency's target at
  # the exact path the dynamic loader reported rather than preserving a link
  # whose target would not exist in the sandbox.
  rm -f "$ROOTFS/$rel"
  cp -aL "$path" "$ROOTFS/$rel"
  printf '%s\n' "$rel"
done <"$WORK/sorted-deps.txt" | sort -u >"$BUNDLE/sandstorm-files.list"
# These two files are synthesized by spk pack from pkgdef. They must be named
# explicitly; alwaysInclude cannot substitute for their file-list entries.
printf '%s\n' sandstorm-manifest sandstorm-http-bridge-config >>"$BUNDLE/sandstorm-files.list"
sort -u -o "$BUNDLE/sandstorm-files.list" "$BUNDLE/sandstorm-files.list"

cp -a "$RECIPE/sandstorm-pkgdef.capnp" "$RECIPE/description.md" "$RECIPE/changelog.md" "$BUNDLE/"
cp -a "$WORK/upstream/assets/logo.svg" "$BUNDLE/logo.svg"

# Exercise the actual packaged rootfs before packing. The smoke scenario mirrors
# the declaration: identity, repository create, issue create, comment create,
# then exact issue and comment read-back through the HTTP API.
SMOKE_PID_FILE="$WORK/smoke.pid"
SMOKE_MOUNTS=0
cleanup_smoke() {
  if [[ -f "$SMOKE_PID_FILE" ]]; then
    local pid
    pid=$(<"$SMOKE_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid"
      wait "$pid" 2>/dev/null || true
    fi
    rm -f "$SMOKE_PID_FILE"
  fi
  if [[ $SMOKE_MOUNTS == 1 ]]; then
    umount "$ROOTFS/proc"
    umount -R "$ROOTFS/dev"
    SMOKE_MOUNTS=0
  fi
}
trap cleanup_smoke EXIT
mkdir -p "$ROOTFS/dev" "$ROOTFS/proc"
chown -R 65534:65534 "$ROOTFS/var"
mount --rbind /dev "$ROOTFS/dev"
mount --make-rslave "$ROOTFS/dev"
mount -t proc proc "$ROOTFS/proc"
mount --make-rslave "$ROOTFS/proc"
SMOKE_MOUNTS=1
chroot --userspec=65534:65534 "$ROOTFS" /bin/bash -c \
  '[[ -e /proc/self/exe && -c /dev/null ]]' || {
    echo 'smoke rootfs preflight: /proc or /dev is unavailable' >&2
    exit 1
  }
: >"$BASE/logs/smoke.log"
SMOKE_PORT=${SMOKE_PORT:-18080}
FORGEJO_HTTP_PORT="$SMOKE_PORT" chroot --userspec=65534:65534 "$ROOTFS" /bin/bash /opt/app/launcher.sh >>"$BASE/logs/smoke.log" 2>&1 &
echo $! >"$SMOKE_PID_FILE"
python3 -I "$RECIPE/smoke.py" "http://127.0.0.1:$SMOKE_PORT" "$BASE/out/smoke.json"
cleanup_smoke
trap - EXIT
rm -rf "$ROOTFS/var" "$ROOTFS/tmp" "$ROOTFS/dev" "$ROOTFS/proc"
mkdir -p "$ROOTFS/var" "$ROOTFS/tmp"
chmod 1777 "$ROOTFS/tmp"

(
  cd "$BUNDLE"
  "$SPK" pack -I"$INCLUDE" -k"$KEYRING" -p"sandstorm-pkgdef.capnp:pkgdef" "$OUT"
)
"$SPK" verify --details "$OUT" | tee "$BASE/out/verify.txt"
sha256sum "$OUT" | tee "$BASE/out/forgejo.spk.sha256"
date -u +%Y-%m-%dT%H:%M:%SZ >"$BASE/out/build-date-utc"
printf 'app_id=%s\nartifact=%s\n' "$APP_ID" "$OUT"
