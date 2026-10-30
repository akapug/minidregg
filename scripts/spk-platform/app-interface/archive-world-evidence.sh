#!/bin/bash
# Preserve bounded private custody/driver evidence before removing an OWN world.
set -euo pipefail
[[ $# == 2 && -f $1/WORLD.env && ! -e $2 ]] || { echo 'usage: archive-world-evidence.sh OWN_WORLD NEW_ARCHIVE_DIR' >&2; exit 2; }
world=$(realpath "$1")
archive=$2
umask 077
mkdir -m 700 "$archive"
. "$world/WORLD.env"
[[ $STORE =~ ^[0-9a-f]{16}$ && $GRAINS_ROOT == /var/lib/mini-spk-worlds/"$STORE" ]] || { echo 'own world path identity refused' >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
# One shared bound covers native journals and driver evidence. A partial archive
# lacks COMPLETE; callers must not remove the world after any archive failure.
sudo -n python3 "$here/archive-world-evidence.py" "$world" "$GRAINS_ROOT" "$STORE" > "$archive/evidence.tar" 2> "$archive/archive.log"
sha256sum "$archive/evidence.tar" > "$archive/SHA256SUMS"
printf 'PRIVATE EVIDENCE ARCHIVED store=%s\n' "$STORE" > "$archive/COMPLETE"
cat "$archive/COMPLETE"
