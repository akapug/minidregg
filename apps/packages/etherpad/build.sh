#!/usr/bin/env bash
set -euo pipefail

BASE=/var/lib/spk-fresh/apps/etherpad
RECIPE="$BASE/recipe"
ADAPTER="$BASE/packaging"
DOWNLOADS="$BASE/downloads"
WORK="$BASE/work"
BUNDLE="$BASE/bundle"
OUT="$BASE/out/etherpad.spk"
SPK=/var/lib/spk-fresh/tools/spk
INCLUDE=/var/lib/spk-fresh/tools/sandstorm-308/usr/include
BRIDGE=/var/lib/spk-fresh/tools/sandstorm-308/bin/sandstorm-http-bridge
KEYRING="$BASE/etherpad.keyring"

UPSTREAM_TAG=v3.3.12
UPSTREAM_COMMIT=f534756571d1c816e85af08acdc472a5822f5761
UPSTREAM_TARBALL="$DOWNLOADS/etherpad-v3.3.12.tar.gz"
UPSTREAM_URL=https://codeload.github.com/ether/etherpad/tar.gz/refs/tags/v3.3.12
UPSTREAM_SHA256=ed0632716df6e6cfd693b8b2ca314a74fceb47f18a07f4944b2a8338bcefc800
DEB="$DOWNLOADS/etherpad_3.3.12-1_amd64.deb"
DEB_URL=https://github.com/ether/etherpad/releases/download/v3.3.12/etherpad_3.3.12-1_amd64.deb
DEB_SHA256=db8e27e6d1cb0dae562fb245268b79070b581c177b28bca0031a64726c9121e9
NODE_TARBALL="$DOWNLOADS/node-v24.22.2-linux-x64.tar.xz"
NODE_URL=https://nodejs.org/dist/v24.22.2/node-v24.22.2-linux-x64.tar.xz
NODE_SHA256=48cc0e21e048790e54c0cf5749c2725005313d652651c40b7a21feb9697aaf75
ADAPTER_COMMIT=129febbbab38d19fcf0efd71f0cab43d233f1865

fetch() {
  local url=$1 dest=$2 sha=$3
  if [[ ! -f "$dest" ]]; then
    curl -fL --retry 3 -o "$dest" "$url"
  fi
  printf '%s  %s\n' "$sha" "$dest" | sha256sum -c -
}

[[ $(id -u) -eq 0 ]]
[[ -x "$SPK" && -d "$INCLUDE" && -x "$BRIDGE" ]]
[[ -s "$KEYRING" && -s "$BASE/app-id" ]]
[[ $(cat "$BASE/app-id") == ksyn7qa4szjwa14v89r7znxwrpjs0dez5q2u8s810d0awnuswmfh ]]
mkdir -p "$DOWNLOADS" "$WORK" "$BASE/out" "$BASE/logs"

if [[ ! -d "$ADAPTER/.git" ]]; then
  git clone https://github.com/sandstorm-org/etherpad-lite-sandstorm.git "$ADAPTER"
fi
[[ $(git -C "$ADAPTER" rev-parse HEAD) == "$ADAPTER_COMMIT" ]]

fetch "$UPSTREAM_URL" "$UPSTREAM_TARBALL" "$UPSTREAM_SHA256"
fetch "$DEB_URL" "$DEB" "$DEB_SHA256"
fetch "$NODE_URL" "$NODE_TARBALL" "$NODE_SHA256"
curl -fL --retry 3 -o "$DOWNLOADS/node-v24.22.2-SHASUMS256.txt" \
  https://nodejs.org/dist/v24.22.2/SHASUMS256.txt
grep ' node-v24.22.2-linux-x64.tar.xz$' "$DOWNLOADS/node-v24.22.2-SHASUMS256.txt"

SRC_DIR="$BASE/src/upstream"
DEB_DIR="$WORK/deb"
NODE_DIR="$WORK/node"
rm -rf "$SRC_DIR" "$DEB_DIR" "$NODE_DIR" "$BUNDLE"
mkdir -p "$SRC_DIR" "$DEB_DIR" "$NODE_DIR" "$BUNDLE/rootfs/opt/app"
tar -xzf "$UPSTREAM_TARBALL" -C "$SRC_DIR" --strip-components=1
dpkg-deb -x "$DEB" "$DEB_DIR"
tar -xJf "$NODE_TARBALL" -C "$NODE_DIR" --strip-components=1
[[ $(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' \
  "$DEB_DIR/opt/etherpad/package.json") == 3.3.12 ]]

APP_ROOT="$BUNDLE/rootfs/opt/app/etherpad-lite"
mkdir -p "$APP_ROOT" "$BUNDLE/rootfs/opt/app/node/bin"
cp -a "$DEB_DIR/opt/etherpad/." "$APP_ROOT/"
cp -a "$NODE_DIR/bin/node" "$BUNDLE/rootfs/opt/app/node/bin/node"
cp -a "$NODE_DIR/LICENSE" "$BUNDLE/rootfs/opt/app/node/LICENSE"
cp -a "$BRIDGE" "$BUNDLE/rootfs/sandstorm-http-bridge"
cp -a "$ADAPTER/.sandstorm/branding" "$BUNDLE/branding"
cp -a "$RECIPE/sandstorm-pkgdef.capnp" "$RECIPE/CHANGELOG.md" "$BUNDLE/"
cp -a "$RECIPE/settings.json" "$APP_ROOT/settings.json"
cp -a "$RECIPE/launcher.sh" "$BUNDLE/rootfs/opt/app/launcher.sh"
chmod 755 "$BUNDLE/rootfs/opt/app/launcher.sh"

for p in "$RECIPE"/patches/*.patch; do
  patch --dry-run -d "$APP_ROOT" -p1 -i "$p"
  patch -d "$APP_ROOT" -p1 --no-backup-if-mismatch -i "$p"
done

# The Mini interface depends on these exact current-upstream route implementations.
cmp "$SRC_DIR/src/node/handler/ImportHandler.ts" "$APP_ROOT/src/node/handler/ImportHandler.ts"
cmp "$SRC_DIR/src/node/hooks/express/importexport.ts" "$APP_ROOT/src/node/hooks/express/importexport.ts"

ln -s /var "$APP_ROOT/var"
ln -s /var/sandstorm/keys/APIKEY.txt "$APP_ROOT/APIKEY.txt"
ln -s /var/sandstorm/keys/SESSIONKEY.txt "$APP_ROOT/SESSIONKEY.txt"
ln -s /var/sandstorm/plugins-initialized/self "$APP_ROOT/src/.ep_initialized"

# Include the closed set of executables and shared-library symlink targets used
# by the standalone runtime and native modules. No host system directory is
# recursively included.
RAW_DEPS="$WORK/etherpad-raw-deps.txt"
: > "$RAW_DEPS"
while IFS= read -r exe; do
  [[ -f "$exe" ]] || continue
  ldd "$exe" 2>/dev/null | awk '/=> \// {print $3} /^[[:space:]]*\// {print $1}' >> "$RAW_DEPS" || true
done < <(printf '%s\n' /bin/bash /bin/mkdir /bin/sh "$BUNDLE/rootfs/opt/app/node/bin/node"; \
         find "$APP_ROOT" -type f -name '*.node' -print)
printf '%s\n' /bin/bash /bin/mkdir /bin/sh /etc/localtime /etc/ssl/openssl.cnf >> "$RAW_DEPS"
while IFS= read -r path; do
  [[ -e "$path" ]] || continue
  printf '%s\n' "${path#/}"
  resolved=$(readlink -f "$path")
  printf '%s\n' "${resolved#/}"
done < "$RAW_DEPS" | sort -u > "$BUNDLE/sandstorm-files.list"

# Direct smoke test, not Mini qualification. Redirect the app's var symlink into
# this lane for the test and restore the package's /var mapping before packing.
TEST_VAR="$WORK/smoke-var"
TEST_LOG="$BASE/logs/smoke.log"
SMOKE_PID_FILE="$WORK/smoke.pid"
rm -rf "$TEST_VAR"
mkdir -p "$TEST_VAR/sandstorm/keys" "$TEST_VAR/sandstorm/plugins-initialized"
printf '%s\n' '{"plugins":[]}' > "$TEST_VAR/installed_plugins.json"
cleanup_smoke() {
  if [[ -f "$SMOKE_PID_FILE" ]]; then
    pid=$(cat "$SMOKE_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid"
      wait "$pid" 2>/dev/null || true
    fi
    rm -f "$SMOKE_PID_FILE"
  fi
  if [[ -L "$APP_ROOT/var" ]]; then
    ln -sfn /var "$APP_ROOT/var"
  fi
}
trap cleanup_smoke EXIT
ln -sfn "$TEST_VAR" "$APP_ROOT/var"
printf 'typed document\n' > "$WORK/smoke-expected.txt"
(
  cd "$APP_ROOT"
  SANDSTORM=1 HOME="$TEST_VAR" TMPDIR="$WORK" NODE_ENV=production ETHERPAD_PRODUCTION=true \
    NODE_OPTIONS=--max-old-space-size=2048 \
    "$BUNDLE/rootfs/opt/app/node/bin/node" \
    --require "$APP_ROOT/src/node_modules/tsx/dist/cjs/index.cjs" \
    "$APP_ROOT/src/node/server.ts" \
    --sessionkey "$TEST_VAR/sandstorm/keys/SESSIONKEY.txt" \
    --apikey "$TEST_VAR/sandstorm/keys/APIKEY.txt" \
    > "$TEST_LOG" 2>&1 &
  echo $! > "$SMOKE_PID_FILE"
)
ready=0
for _ in $(seq 1 90); do
  if curl -fsS --max-time 2 http://127.0.0.1:9001/health > "$WORK/smoke-health.json" 2>/dev/null; then
    ready=1
    break
  fi
  sleep 1
done
[[ $ready -eq 1 ]]
[[ $(curl -sS -o /dev/null -w '%{redirect_url}' http://127.0.0.1:9001/) == http://127.0.0.1:9001/p/main ]]
curl -fsS -H 'X-Sandstorm-Permissions: modify' \
  -F 'file=@'"$WORK/smoke-expected.txt"';filename=document.txt;type=text/plain' \
  http://127.0.0.1:9001/p/mini-smoke/import > "$WORK/smoke-import.json"
python3 -I -c 'import json,sys; x=json.load(open(sys.argv[1])); assert x["code"] == 0 and x["message"] == "ok", x' \
  "$WORK/smoke-import.json"
curl -fsS -H 'X-Sandstorm-Permissions: modify' \
  http://127.0.0.1:9001/p/mini-smoke/export/txt > "$WORK/smoke-export.txt"
cmp "$WORK/smoke-expected.txt" "$WORK/smoke-export.txt"
[[ $(curl -sS -o "$WORK/smoke-readonly.txt" -w '%{http_code}' \
  -H 'X-Sandstorm-Permissions:' -F 'file=@'"$WORK/smoke-expected.txt"';filename=document.txt;type=text/plain' \
  http://127.0.0.1:9001/p/mini-smoke/import) == 403 ]]
cleanup_smoke
trap - EXIT

(
  cd "$BUNDLE"
  "$SPK" pack -I"$INCLUDE" -k"$KEYRING" -p"sandstorm-pkgdef.capnp:pkgdef" "$OUT"
)
"$SPK" verify --details "$OUT" | tee "$BASE/logs/verify-details.txt"
sha256sum "$OUT" | tee "$BASE/logs/spk-sha256.txt"
date -u +%Y-%m-%dT%H:%M:%SZ > "$BASE/out/build-date-utc.txt"
printf 'upstream_commit=%s\n' "$UPSTREAM_COMMIT"
printf 'artifact=%s\n' "$OUT"
