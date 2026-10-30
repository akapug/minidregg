#!/usr/bin/env bash
set -euo pipefail
ROOTFS=/srv/spk-build/mediawiki/package/rootfs
APP="$ROOTFS/opt/app/mediawiki"
[[ $ROOTFS == /srv/spk-build/mediawiki/package/rootfs ]]
[[ -x $ROOTFS/sandstorm-http-bridge && -d $APP ]]

# Keep the complete MediaWiki application, including every interface language.
# Drop operating-system documentation/gettext catalogs: PHP intl uses ICU, not
# these catalogs. Also drop source maps and upstream developer documentation.
rm -rf "$ROOTFS/usr/share/doc" "$ROOTFS/usr/share/man" \
  "$ROOTFS/usr/share/info" "$ROOTFS/usr/share/locale"
rm -rf "$APP/docs"
rm -f "$APP/HISTORY"
find "$APP" -type f \( -name '*.map' -o -name '*.map.json' \) -delete

# The distributed bridge contains debug information; symbols are not runtime
# inputs and materially increase the uncompressed Cap'n Proto archive.
strip --strip-unneeded "$ROOTFS/sandstorm-http-bridge"

# Archive-bound trimming: the Cap'n Proto archive may hold at most 512 segments.
# CodeEditor (an Ace bundle) and the mobile-only MinervaNeue skin are not loaded;
# upstream test suites are not runtime inputs.
rm -rf "$APP/extensions/CodeEditor" "$APP/skins/MinervaNeue"
find "$APP/vendor" "$APP/skins" "$APP/extensions" -type d \
  \( -name tests -o -name test -o -name Tests -o -name docs \) -prune -exec rm -rf {} +
