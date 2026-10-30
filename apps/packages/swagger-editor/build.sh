#!/usr/bin/env bash
set -euo pipefail

# Assemble, smoke-test, pack and verify the Swagger Editor .spk on
# dregg-forge. Run as root with this recipe directory on the box. The app
# tree comes from the step-2 build (see spk-notes/swagger-editor.md):
# upstream v5.10.0 built with `npm run build:app`, output in build/.

BASE=/srv/spk-build/swagger-editor
TOOLS=/var/lib/spk-fresh/tools
SPK=$TOOLS/spk
INCLUDE=$TOOLS/sandstorm-308/usr/include
BRIDGE=$TOOLS/sandstorm-308/bin/sandstorm-http-bridge
NODE_BIN=/srv/spk-build/etherpad/toolchain/node/bin/node
SRC=$BASE/source/swagger-editor-5.10.0/build
PKG=$BASE/package-5.10.0-2
OUT=$BASE/out/swagger-editor-5.10.0-2.spk
KEYRING=$BASE/swagger-editor.keyring
APP_ID=xm16d84ksseg44ef58z7n2aw7qt1n6psk0cewzr0e0arfjk5r4fh
RECIPE=$(cd "$(dirname "$0")" && pwd)

[[ $(id -u) -eq 0 ]]
[[ -x "$SPK" && -d "$INCLUDE" && -x "$BRIDGE" && -x "$NODE_BIN" ]]
[[ -f "$SRC/index.html" && -s "$KEYRING" ]]
[[ $("$SPK" listkeys -k"$KEYRING" | head -1) == "$APP_ID" ]]
mkdir -p "$BASE/out" "$BASE/logs" "$BASE/pids"

# ---- package tree --------------------------------------------------------
rm -rf "$PKG"
mkdir -p "$PKG/rootfs/opt/app/node/bin" "$PKG/rootfs/opt/app/swagger-editor"
# Upstream build minus sourcemaps (~65 MiB of *.js.map excluded). The
# node_modules/ wasm files are runtime parser dependencies and stay.
rsync -a --exclude='*.map' "$SRC"/ "$PKG/rootfs/opt/app/swagger-editor/"
cp -a "$NODE_BIN" "$PKG/rootfs/opt/app/node/bin/node"
cp -a "$(dirname "$NODE_BIN")/../LICENSE" "$PKG/rootfs/opt/app/node/LICENSE"
cp -a "$BRIDGE" "$PKG/rootfs/sandstorm-http-bridge"
cp -a "$RECIPE/launcher.sh" "$PKG/rootfs/opt/app/launcher.sh"
cp -a "$RECIPE/static-server.js" "$PKG/rootfs/opt/app/static-server.js"
chmod 755 "$PKG/rootfs/opt/app/launcher.sh"
cp -a "$RECIPE/sandstorm-pkgdef.capnp" "$RECIPE/CHANGELOG.md" "$PKG/"
cp -a "$RECIPE/branding" "$PKG/branding"

# ---- runtime closure copied into the rootfs (self-contained, like the
# qualified etherpad r6 bundle; no host sourceMap, no files.list) -----------
RAW_DEPS="$BASE/work-raw-deps.txt"
EXES="$BASE/work-exes.txt"
: > "$RAW_DEPS"
printf '%s\n' /bin/bash /bin/sh "$PKG/rootfs/opt/app/node/bin/node" > "$EXES"
while IFS= read -r exe; do
  ldd "$exe" 2>/dev/null | awk '/=> \// {print $3} /^[[:space:]]*\// {print $1}' >> "$RAW_DEPS" || true
done < "$EXES"
printf '%s\n' /bin/bash /bin/sh /etc/localtime >> "$RAW_DEPS"
while IFS= read -r path; do
  [[ -e "$path" ]] || continue
  printf '%s\n' "${path#/}"
  resolved=$(readlink -f "$path")
  printf '%s\n' "${resolved#/}"
done < "$RAW_DEPS" | sort -u > "$BASE/work-copy-list.txt"
while IFS= read -r rel; do
  mkdir -p "$PKG/rootfs/$(dirname "$rel")"
  # -L: a listed soname is often a symlink to the versioned file; copy the
  # content under both names so the loader finds either.
  cp -aL "/$rel" "$PKG/rootfs/$rel"
done < "$BASE/work-copy-list.txt"

# ---- smoke test: same server code the grain runs, against the packaged tree -
SMOKE_PORT=19171
SMOKE_PID_FILE=$BASE/pids/smoke.pid
SMOKE_LOG=$BASE/logs/smoke.log
cleanup_smoke() {
  if [[ -f "$SMOKE_PID_FILE" ]]; then
    pid=$(cat "$SMOKE_PID_FILE")
    kill -0 "$pid" 2>/dev/null && kill "$pid" || true
    rm -f "$SMOKE_PID_FILE"
  fi
}
trap cleanup_smoke EXIT
PORT=$SMOKE_PORT DOCROOT=$PKG/rootfs/opt/app/swagger-editor \
  "$PKG/rootfs/opt/app/node/bin/node" "$PKG/rootfs/opt/app/static-server.js" \
  > "$SMOKE_LOG" 2>&1 &
echo $! > "$SMOKE_PID_FILE"
ready=0
for _ in $(seq 1 30); do
  if curl -fsS --max-time 2 "http://127.0.0.1:$SMOKE_PORT/" \
       > "$BASE/work-smoke-index.html" 2>/dev/null; then
    ready=1
    break
  fi
  sleep 1
done
[[ $ready -eq 1 ]]
grep -qi '<html' "$BASE/work-smoke-index.html"
# One hashed asset referenced by index.html must be served.
ASSET=$(grep -oE '(assets|static)/[A-Za-z0-9._/-]+' "$BASE/work-smoke-index.html" | head -1)
[[ -n "$ASSET" ]]
curl -fsS --max-time 5 "http://127.0.0.1:$SMOKE_PORT/$ASSET" -o "$BASE/work-smoke-asset.bin"
[[ -s "$BASE/work-smoke-asset.bin" ]]
# HEAD works, traversal is refused, missing paths 404.
[[ $(curl -sS -o /dev/null -w '%{http_code}' -I "http://127.0.0.1:$SMOKE_PORT/") == 200 ]]
[[ $(curl -sS -o /dev/null -w '%{http_code}' \
     --path-as-is "http://127.0.0.1:$SMOKE_PORT/../../etc/passwd") == 403 \
   || $(curl -sS -o /dev/null -w '%{http_code}' \
     --path-as-is "http://127.0.0.1:$SMOKE_PORT/../../etc/passwd") == 404 ]]
[[ $(curl -sS -o /dev/null -w '%{http_code}' "http://127.0.0.1:$SMOKE_PORT/no-such-file") == 404 ]]
cleanup_smoke
trap - EXIT

# ---- pack + verify --------------------------------------------------------
(
  cd "$PKG"
  "$SPK" pack -I"$INCLUDE" -k"$KEYRING" -p"sandstorm-pkgdef.capnp:pkgdef" "$OUT"
)
"$SPK" verify --details "$OUT" | tee "$BASE/logs/verify-details.txt"
sha256sum "$OUT" | tee "$BASE/logs/spk-sha256.txt"
date -u +%Y-%m-%dT%H:%M:%SZ > "$BASE/out/build-date-utc.txt"
printf 'artifact=%s\n' "$OUT"
