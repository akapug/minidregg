#!/usr/bin/env bash
# Build EtherCalc 0.20261026.0 for Sandstorm without installing global tools.
# Run on dregg-forge with BASE=/var/lib/spk-fresh/apps/ethercalc.
set -euo pipefail

BASE="${BASE:-/var/lib/spk-fresh/apps/ethercalc}"
UPSTREAM_VERSION="0.20261026.0"
UPSTREAM_COMMIT="964efab030d17a78fb2d9b2358c4cd8ef4c6af93"
SOURCE_SHA256="3a1a78145743be6dabdddedab31b84ef329417ca25909f9f4983d64661f01316"
BUN_VERSION="1.3.14"
BUN_SHA256="951ee2aee855f08595aeec6225226a298d3fea83a3dcd6465c09cbccdf7e848f"
SOURCE_URL="https://codeload.github.com/audreyt/ethercalc/tar.gz/refs/tags/${UPSTREAM_VERSION}"
BUN_URL="https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-x64.zip"
SRC="$BASE/work/build-src"
PACKAGING="$BASE/packaging"
BUN_DIR="$BASE/tools/bun-${BUN_VERSION}/bun-linux-x64"

mkdir -p "$BASE/sources" "$BASE/tools/download" "$BASE/tools/bin" "$BASE/work" "$BASE/out"

if [[ ! -f "$BASE/sources/ethercalc-${UPSTREAM_VERSION}.tar.gz" ]]; then
  curl -fL --retry 3 "$SOURCE_URL" -o "$BASE/sources/ethercalc-${UPSTREAM_VERSION}.tar.gz"
fi
if [[ ! -f "$BASE/tools/download/bun-linux-x64.zip" ]]; then
  curl -fL --retry 3 "$BUN_URL" -o "$BASE/tools/download/bun-linux-x64.zip"
fi
printf '%s  %s\n' "$SOURCE_SHA256" "$BASE/sources/ethercalc-${UPSTREAM_VERSION}.tar.gz" | sha256sum -c -
printf '%s  %s\n' "$BUN_SHA256" "$BASE/tools/download/bun-linux-x64.zip" | sha256sum -c -

if [[ ! -x "$BUN_DIR/bun" ]]; then
  mkdir -p "$BASE/tools/bun-${BUN_VERSION}"
  unzip -q "$BASE/tools/download/bun-linux-x64.zip" -d "$BASE/tools/bun-${BUN_VERSION}"
fi
ln -sfn "$BUN_DIR/bun" "$BASE/tools/bin/bun"
ln -sfn "$BUN_DIR/bun" "$BASE/tools/bin/bunx"
# The release's install helper has a node shebang. Bun supplies its Node API.
ln -sfn "$BUN_DIR/bun" "$BASE/tools/bin/node"
export PATH="$BASE/tools/bin:/usr/local/bin:/usr/bin:/bin"
export HOME="$BASE/work/home"
export TMPDIR="$BASE/work/tmp"
export JOBS=8
export UV_THREADPOOL_SIZE=8
export GOMAXPROCS=8
export NODE_OPTIONS="--max-old-space-size=8192"
mkdir -p "$HOME" "$TMPDIR"

if [[ -e "$SRC" ]]; then
  printf 'Refusing to overwrite existing build directory: %s\n' "$SRC" >&2
  exit 2
fi
mkdir "$SRC"
tar -xzf "$BASE/sources/ethercalc-${UPSTREAM_VERSION}.tar.gz" -C "$SRC" --strip-components=1

cp "$PACKAGING/sandstorm-pkgdef.capnp" "$SRC/sandstorm-pkgdef.capnp"
cp "$PACKAGING/run_grain.sh" "$SRC/run_grain.sh"
cp "$PACKAGING/DESCRIPTION.mkdn" "$SRC/DESCRIPTION.mkdn"
cp "$PACKAGING/CHANGELOG.mkdn" "$SRC/CHANGELOG.mkdn"
chmod +x "$SRC/run_grain.sh"

cd "$SRC"
bun install --frozen-lockfile --ignore-scripts
bun run --cwd packages/client build
bun run --cwd packages/client-multi build
bash scripts/build-assets.sh
bash scripts/build-workerd-bundle.sh

mkdir -p "$SRC/runtime"
cp "$BUN_DIR/bun" "$SRC/runtime/bun"
WORKERD_VERSION="1.20260714.1"
WORKERD="$SRC/node_modules/.bun/@cloudflare+workerd-linux-64@${WORKERD_VERSION}/node_modules/@cloudflare/workerd-linux-64/bin/workerd"
if [[ ! -x "$WORKERD" ]]; then
  printf 'Pinned workerd %s binary was not installed\n' "$WORKERD_VERSION" >&2
  exit 1
fi
cp "$WORKERD" "$SRC/runtime/workerd"
chmod 755 "$SRC/runtime/bun" "$SRC/runtime/workerd"

cat > "$BASE/out/build-source.json" <<EOF
{
  "upstreamVersion": "${UPSTREAM_VERSION}",
  "upstreamTag": "${UPSTREAM_VERSION}",
  "upstreamCommit": "${UPSTREAM_COMMIT}",
  "sourceUrl": "${SOURCE_URL}",
  "sourceSha256": "${SOURCE_SHA256}",
  "bunVersion": "${BUN_VERSION}",
  "bunUrl": "${BUN_URL}",
  "bunSha256": "${BUN_SHA256}",
  "workerdVersion": "${WORKERD_VERSION}",
  "buildDateUtc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
printf 'Build complete: %s\n' "$SRC"
