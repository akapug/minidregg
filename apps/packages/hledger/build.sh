#!/bin/bash
set -euo pipefail

# Package the official static hledger-web release with Sandstorm 308.
BASE=/srv/spk-build/hledger
RECIPE="$BASE/recipe"
PACKAGE_DIR="$BASE/package"
OUT="$BASE/out"
SPK=/var/lib/spk-fresh/tools/spk
VERSION=1.52.4
COMMIT=33fa849e7ae841968bd21c427094c4fb4a4ec38d
ARCHIVE=hledger-linux-x64.tar.gz
URL="https://github.com/hledgerorg/hledger/releases/download/$VERSION/$ARCHIVE"
SHA256=f76a2e4088e162b7658e43077502569d5a6fdacd219b19bfb9aab6588b69643a

for executable in git curl tar sha256sum; do
    command -v "$executable" >/dev/null
done
test "$(uname -m)" = x86_64
test -x "$SPK"
test -f "$BASE/hledger.keyring"
test "$(stat -c %a "$BASE/hledger.keyring")" = 600
grep -q '^    apiPath = "/",$' "$RECIPE/sandstorm-pkgdef.capnp"
actual_commit=$(git ls-remote https://github.com/hledgerorg/hledger.git "refs/tags/$VERSION^{}" | awk '{print $1}')
test "$actual_commit" = "$COMMIT"

mkdir -p "$BASE/downloads" "$OUT"
if [[ ! -f $BASE/downloads/$ARCHIVE ]]; then
    curl -fL --retry 3 -o "$BASE/downloads/$ARCHIVE.partial" "$URL"
    mv "$BASE/downloads/$ARCHIVE.partial" "$BASE/downloads/$ARCHIVE"
fi
printf '%s  %s\n' "$SHA256" "$BASE/downloads/$ARCHIVE" | sha256sum -c -

# PACKAGE_DIR contains only generated runtime and package metadata.
rm -rf -- "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR/opt/app" "$PACKAGE_DIR/bin" \
    "$PACKAGE_DIR/lib/x86_64-linux-gnu" "$PACKAGE_DIR/lib64"
tar -xzf "$BASE/downloads/$ARCHIVE" -C "$PACKAGE_DIR/opt/app" hledger-web
install -m 755 /usr/bin/dash "$PACKAGE_DIR/bin/sh"
cp -L /lib/x86_64-linux-gnu/libc.so.6 "$PACKAGE_DIR/lib/x86_64-linux-gnu/libc.so.6"
cp -L /lib64/ld-linux-x86-64.so.2 "$PACKAGE_DIR/lib64/ld-linux-x86-64.so.2"
install -m 755 "$RECIPE/launcher.sh" "$PACKAGE_DIR/opt/app/launcher.sh"
cp "$RECIPE/sandstorm-pkgdef.capnp" "$RECIPE/sandstorm-files.list" \
    "$RECIPE/description.md" "$RECIPE/changelog.md" \
    "$RECIPE/appGrid.svg" "$RECIPE/grain.svg" "$RECIPE/market.svg" \
    "$RECIPE/screenshot1.png" "$RECIPE/screenshot2.png" "$RECIPE/screenshot3.png" \
    "$PACKAGE_DIR/"

version=$("$PACKAGE_DIR/opt/app/hledger-web" --version)
test "$version" = "hledger-web $VERSION, linux-x86_64"
chroot "$PACKAGE_DIR" /opt/app/hledger-web --version >/dev/null

cd "$PACKAGE_DIR"
rm -f "$OUT/hledger.spk"
"$SPK" pack -k"$BASE/hledger.keyring" "$OUT/hledger.spk"
"$SPK" verify --details "$OUT/hledger.spk" | tee "$OUT/verify.txt"
sha256sum "$OUT/hledger.spk" | tee "$OUT/hledger.spk.sha256"
date -u +%Y-%m-%dT%H:%M:%SZ > "$OUT/build-date-utc"
