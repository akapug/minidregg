#!/usr/bin/env bash
# Build and sign WBO 2.18.26 with the pinned Sandstorm 308 SPK tool.
set -euo pipefail

WORKDIR=${WORKDIR:-/var/lib/spk-fresh/apps/wbo}
RECIPE_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
SPK=${SPK:-/var/lib/spk-fresh/tools/spk}
KEYRING=${KEYRING:-$WORKDIR/wbo.key}

UPSTREAM_VERSION=2.18.26
UPSTREAM_COMMIT=254753602f008d3014c5bd03c9d6492a20014d05
UPSTREAM_ARCHIVE=whitebophir-$UPSTREAM_VERSION.tar.gz
UPSTREAM_URL=https://codeload.github.com/lovasoa/whitebophir/tar.gz/refs/tags/v$UPSTREAM_VERSION
UPSTREAM_SHA256=ff08e993c4758710034e1c5c131b143a4d0a2dc7128c4f4e0a925a3ab3ccaa1c
NODE_VERSION=22.23.4
NODE_ARCHIVE=node-v$NODE_VERSION-linux-x64.tar.xz
NODE_URL=https://nodejs.org/dist/v$NODE_VERSION/$NODE_ARCHIVE
NODE_SHA256=1805bcd35e6815559bd2eb97db438d3fdb0eb3a5e6a977b7c1badca76337e9ce

case "$WORKDIR" in ''|/) printf 'Refusing unsafe WORKDIR: %s\n' "$WORKDIR" >&2; exit 2;; esac
for executable in git curl tar sha256sum ldd awk; do command -v "$executable" >/dev/null; done
test -x "$SPK"
test -r "$KEYRING"
actual_commit=$(git ls-remote https://github.com/lovasoa/whitebophir.git refs/tags/v$UPSTREAM_VERSION | awk '{print $1}')
test "$actual_commit" = "$UPSTREAM_COMMIT"

mkdir -p "$WORKDIR/downloads" "$WORKDIR/build" "$WORKDIR/runtime" "$WORKDIR/package-content" "$WORKDIR/package" "$WORKDIR/out"
download() {
  local url=$1 destination=$2
  if [ ! -f "$destination" ]; then
    curl -fL --retry 3 -o "$destination.partial" "$url"
    mv "$destination.partial" "$destination"
  fi
}
download "$UPSTREAM_URL" "$WORKDIR/downloads/$UPSTREAM_ARCHIVE"
download "$NODE_URL" "$WORKDIR/downloads/$NODE_ARCHIVE"
printf '%s  %s\n' "$UPSTREAM_SHA256" "$WORKDIR/downloads/$UPSTREAM_ARCHIVE" | sha256sum -c -
printf '%s  %s\n' "$NODE_SHA256" "$WORKDIR/downloads/$NODE_ARCHIVE" | sha256sum -c -

for generated in "$WORKDIR/build/source" "$WORKDIR/runtime/node" "$WORKDIR/runtime/loader" "$WORKDIR/package-content/whitebophir"; do
  if [ -e "$generated" ]; then
    printf 'Refusing to overwrite generated build directory: %s\n' "$generated" >&2
    exit 2
  fi
done
mkdir -p "$WORKDIR/build/source" "$WORKDIR/runtime/node" "$WORKDIR/runtime/loader" "$WORKDIR/package-content/whitebophir"
tar -xzf "$WORKDIR/downloads/$UPSTREAM_ARCHIVE" -C "$WORKDIR/build/source" --strip-components=1
tar -xJf "$WORKDIR/downloads/$NODE_ARCHIVE" -C "$WORKDIR/runtime/node" --strip-components=1

export PATH="$WORKDIR/runtime/node/bin:/usr/local/bin:/usr/bin:/bin"
export NODE_OPTIONS=--max-old-space-size=4096
export npm_config_jobs=4
cd "$WORKDIR/build/source"
npm ci --omit=dev --ignore-scripts --no-audit --no-fund

# Ship only runtime code and production dependencies, not tests or developer tools.
cp -a client-data server package.json package-lock.json LICENSE app.json node_modules \
  "$WORKDIR/package-content/whitebophir/"
rm -rf -- "$WORKDIR/runtime/node/lib/node_modules" "$WORKDIR/runtime/node/include" "$WORKDIR/runtime/node/share"
rm -f -- "$WORKDIR/runtime/node/bin/corepack" "$WORKDIR/runtime/node/bin/npm" "$WORKDIR/runtime/node/bin/npx"

# Carry the runtime's ELF closure inside the SPK rather than relying on host libs.
mkdir -p "$WORKDIR/runtime/node/lib"
{
  printf '%s\0' "$WORKDIR/runtime/node/bin/node"
  find "$WORKDIR/build/source/node_modules" -type f -name '*.node' -print0
} | while IFS= read -r -d '' elf; do
  ldd "$elf" 2>/dev/null || true
done | awk '/=> \// { print $3 } /^\// { print $1 }' | sort -u | while IFS= read -r library; do
  cp -L "$library" "$WORKDIR/runtime/node/lib/"
done
interpreter=/lib64/ld-linux-x86-64.so.2
test -r "$interpreter"
cp -L "$interpreter" "$WORKDIR/runtime/loader/ld-linux-x86-64.so.2"
export LD_LIBRARY_PATH="$WORKDIR/runtime/node/lib"
"$WORKDIR/runtime/node/bin/node" --version
cd "$WORKDIR/build/source"
"$WORKDIR/runtime/node/bin/node" -e "require('socket.io'); require('handlebars'); require('jsonwebtoken')"

cp "$RECIPE_DIR/sandstorm-pkgdef.capnp" "$RECIPE_DIR/sandstorm-files.list" \
  "$RECIPE_DIR/bootstrap.mjs" "$RECIPE_DIR/description.md" "$RECIPE_DIR/changelog.md" \
  "$WORKDIR/package/"
cd "$WORKDIR/package"
"$SPK" pack -k"$KEYRING" "$WORKDIR/out/wbo.spk"
"$SPK" verify --details "$WORKDIR/out/wbo.spk" | tee "$WORKDIR/out/verify.txt"
sha256sum "$WORKDIR/out/wbo.spk" | tee "$WORKDIR/out/sha256.txt"
date -u +%Y-%m-%dT%H:%M:%SZ | tee "$WORKDIR/out/build-date.txt"
