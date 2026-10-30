#!/usr/bin/env bash
# Run the sandbox-floor probe as an app inside a resident sandbox, through the
# production path: the resident bootstrap (mapped {operator, app} user namespace,
# launch worker), PreparedResident::prepare, and spawn_gate::spawn_bounded through
# the worker. Linux only; run as the OPERATOR (never root), which needs a
# /etc/subuid grant, newuidmap/newgidmap, unprivileged user namespaces and a
# systemd user manager. sudo is used only to build and remove the throwaway image.
#
#   sandbox-floor-audit.sh TEST_ELF PROBE_ELF BWRAP EVIDENCE_DIR [APP_UID APP_GID]
#
# TEST_ELF is the spk-host lib test executable (`cargo test --lib --no-run`), PROBE_ELF
# the built `spk-sandbox-probe`. Each audit test forks a single-threaded child for the
# namespace entry (the harness thread would make setns(CLONE_NEWUSER) EINVAL), so no
# --test-threads setting is involved. APP_UID/APP_GID default to the first identity of the
# operator's /etc/subuid grant (the one newuidmap maps). SPK_AUDIT_ROOT (default
# /var/lib/spk-floor-audit, root:root 0755, as on dregg-build) is the parent of the
# throwaway audit directory: it must be exec-capable and neither it nor an ancestor
# group/world writable; the operator's sudoers rule is anchored on it. The script builds a throwaway
# image (the probe plus the shared objects `ldd` names, at their own paths), mounts a
# 16 MiB tmpfs owned by the app UID as the separate /var, runs the two audit tests in
# transient user units, and removes everything it created. Evidence: the unit
# transcripts and hashes.
set -euo pipefail

[ $# -ge 4 ] || { echo "usage: $0 TEST_ELF PROBE_ELF BWRAP EVIDENCE_DIR [APP_UID APP_GID]" >&2; exit 2; }
TEST_ELF=$(realpath "$1")
PROBE_ELF=$(realpath "$2")
BWRAP=$3
EVIDENCE=$4
[ "$(id -u)" != 0 ] || { echo "run as the operator, not root" >&2; exit 2; }
FIRST_SUBUID=$(awk -F: -v u="$(id -un)" '$1==u{print $2; exit}' /etc/subuid)
APP_UID=${5:-$FIRST_SUBUID}
APP_GID=${6:-$FIRST_SUBUID}
[ -n "$APP_UID" ] || { echo "no /etc/subuid grant for $(id -un)" >&2; exit 2; }
[ "$APP_UID" != 0 ] && [ "$APP_GID" != 0 ] || { echo "app UID/GID must not be 0" >&2; exit 2; }
mkdir -p "$EVIDENCE"

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
# The audit root carries two conditions the production image root carries, checked
# here by name before anything is built. (1) Exec-capable: a bind mount made in an
# unprivileged user namespace cannot clear a `noexec` locked on its source mount, and
# Debian 13 mounts /run noexec (dregg-build, 2026-10-27: `bwrap: execvp
# /spk-sandbox-probe: Permission denied` with nothing else wrong); Ubuntu does not
# (persvati, 2026-09-30). (2) Neither the root nor any ancestor group/world writable:
# PreparedResident::prepare refuses the image otherwise ("image or ancestor is
# task-owned or group/world writable"), which rules out /var/tmp and /tmp. The box
# root is /var/lib/spk-floor-audit (root:root 0755); the operator's sudoers rule
# must be anchored on "$SPK_AUDIT_ROOT/spk-sandbox-floor-audit-*".
ROOT=${SPK_AUDIT_ROOT:-/var/lib/spk-floor-audit}
HINT="Set SPK_AUDIT_ROOT to a directory that is exec-capable and not group/world writable at any level (/var/lib/spk-floor-audit, root:root 0755, is the box's) and anchor the operator's sudoers rule on \$SPK_AUDIT_ROOT/spk-sandbox-floor-audit-*."
[ -d "$ROOT" ] || { echo "audit root $ROOT is not a directory. $HINT" >&2; exit 2; }
ROOT_MOUNT=$(findmnt -no SOURCE,FSTYPE,OPTIONS -T "$ROOT")
if echo "$ROOT_MOUNT" | tr ' ,' '\n\n' | grep -qx noexec; then
  echo "$ROOT is on a noexec mount ($ROOT_MOUNT): the sandbox cannot exec an image under it. $HINT" >&2
  exit 2
fi
level=$(realpath "$ROOT")
while :; do
  mode=$(stat -c %a "$level")
  if (( 8#$mode & 8#022 )); then
    echo "$level is group/world writable (mode $mode): PreparedResident::prepare refuses an image beneath it. $HINT" >&2
    exit 2
  fi
  [ "$level" != / ] || break
  level=$(dirname "$level")
done
DIR=$ROOT/spk-sandbox-floor-audit-$STAMP
UNIT=spk-sandbox-floor-audit-$STAMP

cleanup() {
  sudo -n umount "$DIR/var" 2>/dev/null || true
  sudo -n rm -rf --one-file-system "$DIR"
}
trap cleanup EXIT

# The audit directory belongs to the operator (the app output log is written
# there); the image beneath it stays root-owned, as an installed image is.
sudo -n install -d -o "$(id -u)" -g "$(id -g)" -m 0755 "$DIR"
sudo -n install -d -o root -g root -m 0755 "$DIR/image" "$DIR/var"
for mountpoint in var tmp proc dev; do
  sudo -n install -d -o root -g root -m 0755 "$DIR/image/$mountpoint"
done
sudo -n install -o root -g root -m 0555 "$PROBE_ELF" "$DIR/image/spk-sandbox-probe"
# Dynamic loader and libraries at the paths the ELF names.
ldd "$PROBE_ELF" | grep -oE '/[^ ]+' | sort -u | while read -r lib; do
  sudo -n install -D -o root -g root -m 0555 "$(realpath "$lib")" "$DIR/image$lib"
done
sudo -n mount -t tmpfs -o "size=16m,mode=0700,uid=$APP_UID,gid=$APP_GID,nosuid,nodev" \
  spk-audit-var "$DIR/var"

BWRAP_SHA=$(sha256sum "$BWRAP" | cut -d' ' -f1)
{
  echo "stamp=$STAMP"
  echo "host=$(hostname) kernel=$(uname -r)"
  echo "bwrap=$BWRAP sha256=$BWRAP_SHA version=$("$BWRAP" --version)"
  echo "bwrap_package=$(dpkg-query -W -f='${Package} ${Version}' bubblewrap 2>/dev/null || echo unknown)"
  echo "test_elf_sha256=$(sha256sum "$TEST_ELF" | cut -d' ' -f1)"
  echo "probe_sha256=$(sha256sum "$PROBE_ELF" | cut -d' ' -f1)"
  echo "app_uid=$APP_UID app_gid=$APP_GID"
  echo "image_files:"
  (cd "$DIR/image" && sudo -n find . -type f -exec sha256sum {} +) | sort -k2
  echo "var_mount=$(findmnt -no SOURCE,FSTYPE,OPTIONS "$DIR/var")"
  echo "audit_root=$ROOT root_mount=$ROOT_MOUNT"
  echo "unprivileged_userns_clone=$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || echo absent)"
  echo "apparmor_restrict_unprivileged_userns=$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns 2>/dev/null || echo absent)"
} > "$EVIDENCE/environment.txt"

# The resident unit's own hardening, so bwrap is proven to START under it on
# this host (a unit-level seccomp layer that returns ENOSYS for openat2, as
# systemd 257's RestrictSUIDSGID=yes does, kills bwrap >= 0.11 at its first
# mount). Mirror of the broker-rendered resident unit (broker.rs install-unit)
# and its drop-in (broker_home.rs `hardening`); keep the three in step.
RESIDENT_PROPS=(-p NoNewPrivileges=no -p UMask=0077 -p KillMode=control-group
  -p LimitCORE=0 -p LimitNOFILE=8192 -p KeyringMode=private)
for prop in "${RESIDENT_PROPS[@]}"; do
  [[ $prop != RestrictSUIDSGID=* && $prop != SystemCallFilter=* ]] \
    || { echo "resident hardening must not add a unit seccomp layer: $prop" >&2; exit 2; }
done

run() {
  local name=$1 test=$2
  set +e
  systemd-run --user --unit="$UNIT-$name" --wait --pipe --collect \
    "${RESIDENT_PROPS[@]}" -p MemoryMax=256M -p TasksMax=64 -p RuntimeMaxSec=120 \
    --setenv=SPK_AUDIT_DIR="$DIR" --setenv=SPK_AUDIT_BWRAP="$BWRAP" \
    --setenv=SPK_AUDIT_BWRAP_SHA256="$BWRAP_SHA" \
    --setenv=SPK_AUDIT_UID="$APP_UID" --setenv=SPK_AUDIT_GID="$APP_GID" \
    -- "$TEST_ELF" --ignored --exact "$test" --nocapture \
    > "$EVIDENCE/$name.transcript" 2>&1
  local status=$?
  set -e
  echo "$name unit=$UNIT-$name test=$test exit=$status" | tee -a "$EVIDENCE/results.txt"
  sudo -n cat "$DIR/app-output-$name.log" > "$EVIDENCE/app-output-$name.log" 2>/dev/null || true
  # Name the openat2 class loudly rather than as a generic probe failure. bwrap's
  # stderr and the probe's JSON report share the app-output pipe; only bwrap's own
  # `bwrap: ...` lines count (the probe reports its held seccomp refusals as
  # "Function not implemented (os error 38)" inside JSON, on a passing run).
  if grep -q "^bwrap: .*Function not implemented" "$EVIDENCE/app-output-$name.log" 2>/dev/null; then
    echo "$name: bwrap hit ENOSYS under the unit's hardening (openat2 filtered?)" | tee -a "$EVIDENCE/results.txt"
  fi
  return $status
}

: > "$EVIDENCE/results.txt"
floor=0; control=0
run floor resident_launch::tests::operator_probe_holds_inside_production_resident_sandbox || floor=$?
run pre-floor resident_launch::tests::operator_probe_breaches_under_pre_floor_arguments || control=$?
shim=0
run shim resident_launch::tests::operator_probe_holds_with_platform_shim || shim=$?
[ "$floor" = 0 ] && [ "$control" = 0 ] && [ "$shim" = 0 ]
