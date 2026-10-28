#!/bin/bash
# Select the physical intake budget before a fresh world's first app installation.
set -euo pipefail
[[ $# == 2 ]] || { echo 'usage: world-import-profile.sh WORLD.env standard-v1|market-large-v1' >&2; exit 2; }
# shellcheck source=/dev/null
. "$1"
selected_profile=$2
case $selected_profile in standard-v1|market-large-v1) ;; *) echo 'unknown market import profile' >&2; exit 2;; esac
state=$(jq -er .stateRoot "$PROFILE")
if compgen -G "$state/apps/*" >/dev/null; then
  echo 'import profile selection requires a world with no apps' >&2; exit 2
fi
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}
unit=mini-spk-broker@$STORE.service
systemctl --user stop "$unit"
umask 077
for config in "$PROFILE" "$GRAINS_ROOT/broker/config.json"; do
  jq --arg profile "$selected_profile" '.importProfile=$profile' "$config" >"$config.sweep-new"
  mv "$config.sweep-new" "$config"
done
systemctl --user start "$unit"
ready=0
for _ in $(seq 1 1200); do
  # A restart leaves an owned but unbound old socket until the broker replaces it.
  # Check that a listener exists, without sending any broker operation.
  if [[ -S $BROKER_SOCKET && $(stat -c '%u:%a' "$BROKER_SOCKET") == "$(id -u):600" ]] &&
      python3 -c 'import socket,sys; s=socket.socket(socket.AF_UNIX); s.settimeout(0.5); s.connect(sys.argv[1]); s.close()' "$BROKER_SOCKET" 2>/dev/null; then
    ready=1; break
  fi
  sleep 0.1
done
[[ $ready == 1 ]] || {
  echo 'operator broker socket custody failed after import profile selection' >&2; exit 1;
}
printf 'WORLD IMPORT PROFILE %s %s\n' "$STORE" "$selected_profile"
