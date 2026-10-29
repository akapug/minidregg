#!/bin/bash
set -euo pipefail

# Reproducible HedgeDoc 1.12.0 Sandstorm package build. No global packages.
WORKDIR=${WORKDIR:-/var/lib/spk-fresh/apps/hedgedoc}
RECIPE_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
SPK=${SPK:-/var/lib/spk-fresh/tools/spk}
KEYRING=${KEYRING:-$WORKDIR/hedgedoc.keyring}

UPSTREAM_VERSION=1.12.0
UPSTREAM_COMMIT=b9335040716278d029b5872e3825b92821d9cb70
UPSTREAM_ARCHIVE=hedgedoc-1.12.0.tar.gz
UPSTREAM_URL=https://github.com/hedgedoc/hedgedoc/releases/download/1.12.0/$UPSTREAM_ARCHIVE
UPSTREAM_SHA256=e84c4ea2e635a84f8a3d77e2a1797e01ecbe695ae1277724af2ce7e6aa40b6e5
NODE_VERSION=22.23.4
NODE_ARCHIVE=node-v$NODE_VERSION-linux-x64.tar.xz
NODE_URL=https://nodejs.org/dist/v$NODE_VERSION/$NODE_ARCHIVE
NODE_SHA256=1805bcd35e6815559bd2eb97db438d3fdb0eb3a5e6a977b7c1badca76337e9ce

case "$WORKDIR" in
  ''|/) printf 'Refusing unsafe WORKDIR: %s\n' "$WORKDIR" >&2; exit 2 ;;
esac
for executable in git curl tar sha256sum ldd awk; do
  command -v "$executable" >/dev/null
done
test -x "$SPK"
test -r "$KEYRING"

actual_commit=$(git ls-remote https://github.com/hedgedoc/hedgedoc.git refs/tags/$UPSTREAM_VERSION | awk '{print $1}')
test "$actual_commit" = "$UPSTREAM_COMMIT"

mkdir -p "$WORKDIR/downloads" "$WORKDIR/build" "$WORKDIR/runtime" "$WORKDIR/out"
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

# These are generated build directories, never source or key directories.
rm -rf -- "$WORKDIR/build/source" "$WORKDIR/runtime/node" "$WORKDIR/runtime/loader" "$WORKDIR/package"
mkdir -p "$WORKDIR/build/source" "$WORKDIR/runtime/node" "$WORKDIR/runtime/loader" "$WORKDIR/package"
tar -xzf "$WORKDIR/downloads/$UPSTREAM_ARCHIVE" -C "$WORKDIR/build/source" --strip-components=1
tar -xJf "$WORKDIR/downloads/$NODE_ARCHIVE" -C "$WORKDIR/runtime/node" --strip-components=1

cd "$WORKDIR/build/source"
git apply --check "$RECIPE_DIR/patches/sandstorm-adaptations.patch"
git apply "$RECIPE_DIR/patches/sandstorm-adaptations.patch"
git apply --check "$RECIPE_DIR/patches/yarn-lock.patch"
git apply "$RECIPE_DIR/patches/yarn-lock.patch"
mkdir -p lib/web/auth/sandstorm
cp "$RECIPE_DIR/auth-plugin/index.js" lib/web/auth/sandstorm/index.js
cp "$RECIPE_DIR/config.json" config.json

export PATH="$WORKDIR/runtime/node/bin:$PATH"
export COREPACK_HOME="$WORKDIR/runtime/corepack"
export XDG_CACHE_HOME="$WORKDIR/runtime/xdg-cache"
export YARN_CACHE_FOLDER="$WORKDIR/runtime/yarn-cache"
export YARN_ENABLE_GLOBAL_CACHE=false
export YARN_ENABLE_IMMUTABLE_INSTALLS=true
export NODE_OPTIONS=--max-old-space-size=12288
mkdir -p "$COREPACK_HOME" "$XDG_CACHE_HOME" "$YARN_CACHE_FOLDER"
corepack yarn workspaces focus --all --production

# Copy every shared object reported for Node and its native modules. Keeping
# this closure below /opt/app/node/lib makes the SPK independent of host libs.
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

# Corepack, npm, headers and documentation are build inputs, not runtime files.
rm -rf -- "$WORKDIR/runtime/node/lib/node_modules" \
  "$WORKDIR/runtime/node/include" "$WORKDIR/runtime/node/share" \
  "$WORKDIR/build/source/.yarn"
rm -f -- "$WORKDIR/runtime/node/bin/corepack" \
  "$WORKDIR/runtime/node/bin/npm" "$WORKDIR/runtime/node/bin/npx"

export LD_LIBRARY_PATH="$WORKDIR/runtime/node/lib"
"$WORKDIR/runtime/node/bin/node" -e "require('$WORKDIR/build/source/node_modules/sqlite3'); require('$WORKDIR/build/source/node_modules/toobusy-js'); require('$WORKDIR/build/source/node_modules/passport-custom')"

cp "$RECIPE_DIR/sandstorm-pkgdef.capnp" \
  "$RECIPE_DIR/sandstorm-files.list" "$RECIPE_DIR/description.md" \
  "$RECIPE_DIR/changelog.md" "$RECIPE_DIR/bootstrap.js" "$WORKDIR/package/"
cd "$WORKDIR/package"
"$SPK" pack -k"$KEYRING" "$WORKDIR/out/hedgedoc.spk"
"$SPK" verify --details "$WORKDIR/out/hedgedoc.spk" | tee "$WORKDIR/out/verify.txt"
sha256sum "$WORKDIR/out/hedgedoc.spk" | tee "$WORKDIR/out/sha256.txt"
date -u +%Y-%m-%dT%H:%M:%SZ | tee "$WORKDIR/out/build-date.txt"
