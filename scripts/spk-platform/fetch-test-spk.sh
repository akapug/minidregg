#!/bin/sh
# A pinned, signed test SPK, measured in the 2026-09-27 app-selection and
# 2026-09-28 qualification records. SPK install still verifies its signature.
#   TEST_SPK=sntfy (default)  sntfy v2.28.0-sandstorm-18
#   TEST_SPK=ethercalc        the qualified EtherCalc (docs/evidence/2026-09-27-spk-app-selection),
#                             whose _/SHEET/csv export the app-document connector captures
set -eu
umask 077
[ "$#" -le 1 ] || { echo "usage: [TEST_SPK=sntfy|ethercalc] $0 [CACHE_DIR_OUTSIDE_SRC]" >&2; exit 2; }
cache=${1:-/srv/lanes/prod-spk/cache}
case ${TEST_SPK:-sntfy} in
  sntfy) name=sntfy size=17379772
    package=bc424d5fd3cf60977cacdac328adfbee
    sha=bc424d5fd3cf60977cacdac328adfbee4de94f88d57383ad38b3d472c0c24f2d ;;
  ethercalc) name=ethercalc size=11983992
    package=93bd2c296692368252ea7b5610a7930d
    sha=93bd2c296692368252ea7b5610a7930db60e5b283340a60b6be8a812c7e309ee ;;
  *) echo "unknown TEST_SPK ${TEST_SPK}" >&2; exit 2 ;;
esac
here=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
repo=$(CDPATH='' cd -- "$here/../.." && pwd)
case "$cache" in /*) ;; *) echo 'absolute cache directory required' >&2; exit 2;; esac
case "$cache/" in "$repo/"*) echo 'SPK cache must be outside src' >&2; exit 2;; esac
mkdir -p -m 700 "$cache"
[ ! -L "$cache" ] && [ "$(realpath "$cache")" = "$cache" ] || { echo 'SPK cache custody refused' >&2; exit 1; }
path=$cache/$name-$sha.spk
check() {
  [ -f "$1" ] && [ ! -L "$1" ] && [ "$(stat -c '%s' "$1")" = "$size" ] &&
    [ "$(sha256sum "$1" | cut -d ' ' -f1)" = "$sha" ]
}
if [ -e "$path" ] || [ -L "$path" ]; then
  check "$path" || { echo 'test SPK pinned sha256 mismatch' >&2; exit 1; }
else
  temp=$(mktemp "$cache/.$name.XXXXXXXX")
  trap 'rm -f "$temp"' EXIT HUP INT TERM
  curl --fail --location --proto '=https' --tlsv1.2 --connect-timeout 20 --max-time 180 \
    "https://app-index.sandstorm.io/packages/$package" -o "$temp"
  check "$temp" || { echo 'test SPK pinned sha256 mismatch' >&2; exit 1; }
  chmod 400 "$temp"
  ln "$temp" "$path"
  rm "$temp"
  trap - EXIT HUP INT TERM
fi
printf '%s\n' "$path"
