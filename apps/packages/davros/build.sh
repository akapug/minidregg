#!/usr/bin/env bash
# Build the pinned Davros source in a disposable Debian rootfs on dregg-forge.
set -euo pipefail

ROOT=${DAVROS_BUILD_ROOT:-/srv/spk-build/davros}
SOURCE=$ROOT/upstream
ROOTFS=$ROOT/rootfs
OUT=$ROOT/out
KEYRING=${DAVROS_KEYRING:-$ROOT/davros.keyring}
APP_ID_FILE=${DAVROS_APP_ID_FILE:-$ROOT/app-id}
SPK_BUNDLE=${SPK_BUNDLE:-/var/lib/spk-fresh/tools/sandstorm-308}
COMMIT=d323f746f3ab1ff47a2879bf79982c19cb96d5ca

[[ $(id -u) == 0 ]] || { echo "run as root on dregg-forge" >&2; exit 2; }
[[ -s $KEYRING && -s $APP_ID_FILE ]] || { echo "generate the app key and app-id first (see README.md)" >&2; exit 2; }
mkdir -p "$ROOT" "$OUT"
if [[ ! -d $SOURCE/.git ]]; then
  git clone --filter=blob:none https://github.com/mnutt/davros.git "$SOURCE"
fi
git -C "$SOURCE" checkout --detach "$COMMIT"
[[ $(git -C "$SOURCE" rev-parse HEAD) == "$COMMIT" ]]

app_id=$(tr -d '\n' <"$APP_ID_FILE")
[[ $app_id =~ ^[0-9a-z]{52}$ ]] || { echo "invalid app ID" >&2; exit 2; }
sed -i -E "s/^  id = \"[0-9a-z]+\",$/  id = \"$app_id\",/" "$SOURCE/.sandstorm/sandstorm-pkgdef.capnp"
sed -i \
  -e 's/contactEmail = "michael@nutt.im",/upstreamAuthor = "Michael Nutt",/' \
  -e '/pgpSignature = embed "pgp-signature",/d' \
  -e '/pgpKeyring = embed "pgp-keyring",/d' \
  "$SOURCE/.sandstorm/sandstorm-pkgdef.capnp"
if grep -q 'pgpSignature\|pgpKeyring' "$SOURCE/.sandstorm/sandstorm-pkgdef.capnp"; then
  echo "old app-ID-bound PGP metadata remains" >&2
  exit 1
fi
grep -q '^    apiPath = "/",$' "$SOURCE/.sandstorm/sandstorm-pkgdef.capnp"

if [[ ! -f $ROOTFS/etc/os-release ]]; then
  debootstrap --variant=minbase \
    --include=ca-certificates,curl,gnupg,sudo,make,pkg-config,capnproto,libcapnp-dev,clang-19,git \
    trixie "$ROOTFS" https://deb.debian.org/debian
fi

mkdir -p "$ROOTFS/opt/sandstorm"

nspawn=(systemd-nspawn --quiet --machine=spk-davros --resolv-conf=bind-host
  --property=MemoryMax=4G --property=TasksMax=512
  --directory="$ROOTFS" --bind="$SOURCE:/opt/app"
  --bind-ro="$SPK_BUNDLE:/opt/sandstorm/latest" --bind="$OUT:/out")

if [[ ! -f $ROOTFS/.minidregg-davros-setup ]]; then
  "${nspawn[@]}" /bin/bash -lc '
    set -euo pipefail
    export HOME=/root USER=root DEBIAN_FRONTEND=noninteractive
    cd /opt/app
    bash .sandstorm/setup.sh
    touch /.minidregg-davros-setup
  '
fi

if [[ ! -f $ROOTFS/.minidregg-davros-runtime || ! -x $ROOTFS/usr/bin/xz ]]; then
  "${nspawn[@]}" /bin/bash -lc '
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends \
      locales procps iproute2 xz-utils libdbus-1-3 libfreetype6 libglib2.0-0t64 \
      libnuma1 libpng16-16t64 libtirpc3t64
    touch /.minidregg-davros-runtime
  '
fi

install -m 0755 "$SPK_BUNDLE/bin/sandstorm-http-bridge" "$ROOTFS/sandstorm-http-bridge"
ln -sfn /proc/self/mounts "$ROOTFS/etc/mtab"
mkdir -p "$SOURCE/vendor"
touch "$ROOTFS/davros.keyring"
# The command's variables are expanded by bash inside the container.
# shellcheck disable=SC2016
"${nspawn[@]}" --bind-ro="$KEYRING:/davros.keyring" /bin/bash -lc '
  set -euo pipefail
  export HOME=/root USER=root DEBIAN_FRONTEND=noninteractive
  cd /opt/app
  bash .sandstorm/build.sh
  bash .sandstorm/compile_helper.sh
  cd /opt/app/.sandstorm
  missing=0
  while IFS= read -r required; do
    case "$required" in
      ""|\#*|proc/cpuinfo|sandstorm-http-bridge-config|sandstorm-manifest) continue ;;
    esac
    if [[ ! -e "/$required" && ! -L "/$required" ]]; then
      printf "missing package requirement: %s\n" "$required" >&2
      missing=1
    fi
  done < sandstorm-files.list
  [[ $missing == 0 ]] || exit 1
  /opt/sandstorm/latest/bin/spk --keyring=/davros.keyring pack /out/davros.spk
  /opt/sandstorm/latest/bin/spk verify /out/davros.spk > /out/verified-app-id
  sha256sum /out/davros.spk > /out/davros.spk.sha256
'
