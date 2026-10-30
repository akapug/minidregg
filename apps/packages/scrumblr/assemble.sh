#!/bin/bash
set -euo pipefail
base=/srv/spk-build/scrumblr
pkg=$base/package-0.5-1
src=$base/source
deb=$base/downloads/debs/x
T=/var/lib/spk-fresh/tools
staged=$base/staged   # files scp'd from the lane

# never rm over a live mount (a crashed smoke test can leave one behind)
if grep -qs " $pkg/" /proc/mounts; then
  echo "REFUSING: mounts still present under $pkg" >&2
  grep " $pkg/" /proc/mounts >&2 || true
  exit 1
fi
rm -rf "$pkg"
mkdir -p "$pkg"/rootfs/{bin,lib/x86_64-linux-gnu,lib64,etc,tmp,var} \
         "$pkg"/branding "$base"/out

# --- app tree: upstream source incl. node_modules, minus deploy-only files
mkdir -p "$pkg"/rootfs/opt/app
rsync -a --exclude docker-compose.yaml --exclude dockerfile --exclude fly.toml \
              --exclude forever.sh --exclude .git "$src"/ "$pkg"/rootfs/opt/app/

# --- node runtime shared with the etherpad toolchain
cp -a /srv/spk-build/etherpad/toolchain/node "$pkg"/rootfs/opt/app/node

# --- redis inside the grain
mkdir -p "$pkg"/rootfs/opt/app/redis/bin
cp "$deb"/usr/bin/redis-server "$deb"/usr/bin/redis-cli "$pkg"/rootfs/opt/app/redis/bin/

# --- runtime libs: node's set (mirroring the etherpad package) ...
cp -a /srv/spk-build/etherpad/package-3.3.12-1/rootfs/lib/x86_64-linux-gnu/. \
      "$pkg"/rootfs/lib/x86_64-linux-gnu/
cp /srv/spk-build/etherpad/package-3.3.12-1/rootfs/lib64/ld-linux-x86-64.so.2 \
   "$pkg"/rootfs/lib64/
cp -a /srv/spk-build/etherpad/package-3.3.12-1/rootfs/etc/ssl "$pkg"/rootfs/etc/
# ... plus redis 8's set (host copies; liblzf comes from the deb)
for l in libatomic.so.1 libjemalloc.so.2 libsystemd.so.0 libssl.so.3 libcrypto.so.3 \
         libcap.so.2 libz.so.1 libzstd.so.1; do
  cp -L "/lib/x86_64-linux-gnu/$l" "$pkg"/rootfs/lib/x86_64-linux-gnu/
done
cp -a "$deb"/usr/lib/x86_64-linux-gnu/liblzf.so.1* "$pkg"/rootfs/lib/x86_64-linux-gnu/

# --- shell/mkdir + http bridge (same sources as the etherpad package)
cp /srv/spk-build/etherpad/package-3.3.12-1/rootfs/bin/bash \
   /srv/spk-build/etherpad/package-3.3.12-1/rootfs/bin/sh \
   /srv/spk-build/etherpad/package-3.3.12-1/rootfs/bin/mkdir \
   "$pkg"/rootfs/bin/
cp "$T"/sandstorm-308/bin/sandstorm-http-bridge "$pkg"/rootfs/

# --- staged files from the lane
install -m 755 "$staged"/launcher.sh "$pkg"/rootfs/opt/app/launcher.sh
cp "$staged"/sandstorm-pkgdef.capnp "$pkg"/
cp "$staged"/CHANGELOG.md "$pkg"/
cp "$staged"/branding/scrumblr.svg "$staged"/branding/description.md "$pkg"/branding/

echo "ASSEMBLY OK"
du -sh "$pkg"/rootfs | tail -1
