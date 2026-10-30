#!/usr/bin/env bash
# Package Wekan's signed 12.68 Sandstorm release under the minidregg app key.
set -euo pipefail

BASE=${WEKAN_BUILD_ROOT:-/srv/spk-build/wekan}
RECIPE=${WEKAN_RECIPE:-$BASE/recipe}
DOWNLOADS=$BASE/downloads
SOURCE=$BASE/source
UNPACKED=$BASE/upstream-spk
PACKAGE=$BASE/package
OUT=$BASE/out
SPK=/var/lib/spk-fresh/tools/spk
INCLUDE=/var/lib/spk-fresh/tools/sandstorm-308/usr/include
KEYRING=${WEKAN_KEYRING:-$BASE/wekan.keyring}
APP_ID=wpe8yvzdpjsst9314ucecmpmyzju0830ujm815ew5mjuen173kg0
OLD_APP_ID=m86q05rdvj14yvn78ghaxynqz7u2svw6rnttptxx49g1785cdv1h
VERSION=12.68
SOURCE_SHA256=94f77ae1239bd31a2e248802ef6847447f862e2ea6028690917d54461f4408c5
RELEASE_SPK_SHA256=8c8c4b8212bc7bc36d370370d6a86bc0147697152d65bdcd5101ae8fb7a32043

fetch() {
  local url=$1 destination=$2 digest=$3
  if [[ ! -f $destination ]]; then
    curl -fL --retry 3 -o "$destination.partial" "$url"
    mv "$destination.partial" "$destination"
  fi
  printf '%s  %s\n' "$digest" "$destination" | sha256sum -c -
}

verified_app_id() {
  $SPK verify "$1" | python3 -I -c 'import re,sys; m=re.search(r"^\{ \"appId\": \"([0-9a-z]{52})\",$", sys.stdin.read(), re.M); assert m; print(m.group(1))'
}

[[ $(id -u) == 0 ]]
case "$BASE" in
  ''|/) printf 'Refusing unsafe WEKAN_BUILD_ROOT: %s\n' "$BASE" >&2; exit 2 ;;
esac
[[ $($SPK --version) == 'Sandstorm version 308' ]]
[[ -s $KEYRING && $(stat -c %a "$KEYRING") == 600 ]]
[[ -s $BASE/app-id && $(<"$BASE/app-id") == "$APP_ID" ]]
mkdir -p "$DOWNLOADS" "$OUT"
fetch "https://github.com/wekan/wekan/archive/refs/tags/v$VERSION.tar.gz" \
  "$DOWNLOADS/wekan-v$VERSION.tar.gz" "$SOURCE_SHA256"
fetch "https://github.com/wekan/wekan/releases/download/v$VERSION/wekan-$VERSION-sandstorm.spk" \
  "$DOWNLOADS/wekan-$VERSION-sandstorm.spk" "$RELEASE_SPK_SHA256"
[[ $(verified_app_id "$DOWNLOADS/wekan-$VERSION-sandstorm.spk") == "$OLD_APP_ID" ]]

# These are generated directories owned by this recipe, never source checkouts.
rm -rf "$SOURCE" "$UNPACKED" "$PACKAGE"
mkdir -p "$SOURCE" "$PACKAGE"
tar -xzf "$DOWNLOADS/wekan-v$VERSION.tar.gz" -C "$SOURCE" --strip-components=1
$SPK unpack "$DOWNLOADS/wekan-$VERSION-sandstorm.spk" "$UNPACKED" >"$OUT/upstream-app-id"
[[ $(<"$OUT/upstream-app-id") == "$OLD_APP_ID" ]]
# spk pack synthesizes both from the adapted definition. Leaving the signed
# upstream copies in the input would carry its old identity into the new package.
rm -f "$UNPACKED/sandstorm-manifest" "$UNPACKED/sandstorm-http-bridge-config"
python3 -I "$RECIPE/adapt_pkgdef.py" \
  "$SOURCE/sandstorm-pkgdef.capnp" "$PACKAGE/sandstorm-pkgdef.capnp" "$APP_ID"
cp -a "$SOURCE/meta" "$SOURCE/CHANGELOG.md" "$PACKAGE/"

(
  cd "$PACKAGE"
  $SPK pack -I"$INCLUDE" -k"$KEYRING" "$OUT/wekan.spk"
)
verified_app_id "$OUT/wekan.spk" >"$OUT/verified-app-id"
[[ $(<"$OUT/verified-app-id") == "$APP_ID" ]]
$SPK verify --details "$OUT/wekan.spk" | tee "$OUT/verify.txt"
sha256sum "$OUT/wekan.spk" | tee "$OUT/wekan.spk.sha256"
date -u +%Y-%m-%dT%H:%M:%SZ >"$OUT/build-date-utc"
