#!/usr/bin/env bash
# Run only in an independent source and Cargo snapshot, as the user manager owner.
# Creates exactly one absent unit, then removes only that unit on exit.
set -euo pipefail
[ "$#" -eq 3 ] || { echo 'usage: oracle-u3-manager-probe.sh SNAPSHOT TARGET NEW_EVIDENCE_DIR' >&2; exit 2; }
snapshot=$1 target=$2 evidence=$3
[ ! -e "$evidence" ] || { echo 'evidence directory already exists' >&2; exit 1; }
mkdir -m 700 "$evidence"
unit=mini-spk-s0123456789abcdef-a991007-g1.service
account_dir=$(getent passwd "$(id -u)" | cut -d: -f6)
unitfile="$account_dir/.config/systemd/user/$unit"
[ ! -e "$unitfile" ] || { echo 'fixture unit file already exists' >&2; exit 1; }
[ "$(systemctl --user show "$unit" -p LoadState --value)" = not-found ] || { echo 'fixture unit already loaded' >&2; exit 1; }
created=0
cleanup() {
  if [ "$created" = 1 ]; then
    systemctl --user stop "$unit" >/dev/null 2>&1 || true
    rm -- "$unitfile"
    systemctl --user daemon-reload >/dev/null
  fi
}
trap cleanup EXIT
set -o noclobber
printf '[Unit]\nDescription=Disposable source STOP audit fixture\n[Service]\nType=simple\nExecStart=/usr/bin/sleep 300\n' > "$unitfile"
set +o noclobber
created=1
systemctl --user daemon-reload
systemctl --user start "$unit"
cd "$snapshot"
export CARGO_TARGET_DIR="$target"
SWARM_MEM_MAX=4G swarm-build taskset -c 22,23 cargo test -j2 --offline --locked -p minidregg-spk-host --lib source_stop -- --nocapture > "$evidence/source-stop.log" 2>&1
SWARM_MEM_MAX=4G swarm-build taskset -c 22,23 cargo test -j2 --offline --locked -p minidregg-spk-host --lib hostd::tests::source_stop_already_inactive_actual_manager_probe -- --exact --ignored --nocapture --test-threads=1 > "$evidence/manager.log" 2>&1
printf 'source_stop_tests=passed\nactual_manager_probe=passed\n' > "$evidence/result.txt"
