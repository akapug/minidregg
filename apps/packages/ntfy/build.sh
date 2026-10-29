#!/usr/bin/env bash
# Build the pinned sntfy adapter in a dedicated Debian rootfs on dregg-forge.
set -euo pipefail

ROOT=${NTFY_BUILD_ROOT:-/srv/spk-build/ntfy}
SOURCE=$ROOT/upstream
ROOTFS=$ROOT/rootfs
OUT=$ROOT/out
KEYRING=${NTFY_KEYRING:-$ROOT/ntfy.key}
APP_ID_FILE=${NTFY_APP_ID_FILE:-$ROOT/app-id}
SPK_BUNDLE=${SPK_BUNDLE:-/var/lib/spk-fresh/tools/sandstorm-308}
COMMIT=8d50e76b1024f5820e177f3e22944b47d051641c

[[ $(id -u) == 0 ]] || { echo "run as root on dregg-forge" >&2; exit 2; }
[[ -s $KEYRING && -s $APP_ID_FILE ]] || { echo "generate the app key and app-id first (see README.md)" >&2; exit 2; }
mkdir -p "$ROOT" "$OUT"
if [[ ! -d $SOURCE/.git ]]; then
  git clone --filter=blob:none https://github.com/orblivion/ntfy.git "$SOURCE"
fi
git -C "$SOURCE" checkout --detach "$COMMIT"
git -C "$SOURCE" reset --hard "$COMMIT"
[[ $(git -C "$SOURCE" rev-parse HEAD) == "$COMMIT" ]]

app_id=$(tr -d '\n' <"$APP_ID_FILE")
[[ $app_id =~ ^[0-9a-z]{52}$ ]] || { echo "invalid app ID" >&2; exit 2; }
sed -i -E "s/^  id = \"[0-9a-z]+\",$/  id = \"$app_id\",/" "$SOURCE/.sandstorm/sandstorm-pkgdef.capnp"
sed -i \
  -e '/pgpSignature = embed "metadata\/pgp-signature",/d' \
  -e '/pgpKeyring = embed "metadata\/pgp-keyring",/d' \
  "$SOURCE/.sandstorm/sandstorm-pkgdef.capnp"
if grep -Eq '^[[:space:]]*(pgpSignature|pgpKeyring)[[:space:]]*=' "$SOURCE/.sandstorm/sandstorm-pkgdef.capnp"; then
  echo "old app-ID-bound PGP metadata remains" >&2
  exit 1
fi
grep -q '^  apiPath = "/",$' "$SOURCE/.sandstorm/sandstorm-pkgdef.capnp"
grep -q 'appVersion = 20,' "$SOURCE/.sandstorm/sandstorm-pkgdef.capnp"
grep -q 'appMarketingVersion = (defaultText = "v2.34.0-sandstorm-20"),' "$SOURCE/.sandstorm/sandstorm-pkgdef.capnp"

if [[ ! -f $ROOTFS/etc/os-release ]]; then
  debootstrap --variant=minbase \
    --include=ca-certificates,curl,wget,sudo,git,make,build-essential,pkg-config,libsqlite3-dev,python3-pip,xz-utils,shared-mime-info,tzdata \
    trixie "$ROOTFS" https://deb.debian.org/debian
fi

mkdir -p "$ROOTFS/opt/sandstorm"
nspawn=(systemd-nspawn --quiet --machine=spk-ntfy --resolv-conf=bind-host
  --property=MemoryMax=6G --property=TasksMax=1024
  --directory="$ROOTFS" --bind="$SOURCE:/opt/app"
  --bind-ro="$SPK_BUNDLE:/opt/sandstorm/latest" --bind="$OUT:/out")

if [[ ! -f $ROOTFS/.minidregg-ntfy-setup ]]; then
  "${nspawn[@]}" /bin/bash -lc '
    set -euo pipefail
    export HOME=/root USER=root DEBIAN_FRONTEND=noninteractive
    apt-get update
    cd /opt/app
    bash .sandstorm/setup.sh
    touch /.minidregg-ntfy-setup
  '
fi

install -m 0755 "$SPK_BUNDLE/bin/sandstorm-http-bridge" "$ROOTFS/sandstorm-http-bridge"
ln -sfn /proc/self/mounts "$ROOTFS/etc/mtab"
touch "$ROOTFS/ntfy.key"
# The command's variables are expanded by bash inside the container.
# shellcheck disable=SC2016
"${nspawn[@]}" --bind-ro="$KEYRING:/ntfy.key" /bin/bash -lc '
  set -euo pipefail
  export HOME=/root USER=root DEBIAN_FRONTEND=noninteractive
  export PATH=/usr/local/go/bin:/root/go/bin:$PATH
  cd /opt/app
  bash .sandstorm/build.sh
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
  /opt/sandstorm/latest/bin/spk --keyring=/ntfy.key pack /out/ntfy.spk
  /opt/sandstorm/latest/bin/spk verify /out/ntfy.spk > /out/verified-app-id
  sha256sum /out/ntfy.spk > /out/ntfy.spk.sha256
  stat -c %s /out/ntfy.spk > /out/ntfy.spk.size
'
