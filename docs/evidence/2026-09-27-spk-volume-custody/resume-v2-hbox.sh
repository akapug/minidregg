#!/usr/bin/env bash
# Re-attest only the task-owned source-volume-bound fixture after a remount.
# This never resubmits create.
set -euo pipefail

scratch=/tank/chreatures/mini-spk-var-attest-v2-20260927
source_script=/tank/chreatures/spk-var-volume-source-20260927
[[ -f $scratch/var-spk/images/991025.ext4 ]] || { echo 'retained image absent' >&2; exit 1; }
[[ -f $scratch/etc-minidregg/spk/volumes/991025.conf ]] || { echo 'retained registration absent' >&2; exit 1; }
[[ ! -e /var/lib/minidregg && ! -e /etc/minidregg && ! -e /run/minidregg ]] || {
  echo 'host mountpoint already exists; refusing fixture' >&2; exit 1;
}
sudo install -o root -g root -m 755 -- "$source_script" "$scratch/spk-var-volume"
sudo install -d -o root -g root -m 755 /var/lib/minidregg /var/lib/minidregg/spk /etc/minidregg /run/minidregg
cleanup_mountpoints() {
  sudo rmdir /var/lib/minidregg/spk /var/lib/minidregg /etc/minidregg /run/minidregg
}
trap cleanup_mountpoints EXIT

sudo unshare -m --propagation private /bin/bash -s <<'INNER'
set -euo pipefail
scratch=/tank/chreatures/mini-spk-var-attest-v2-20260927
script=$scratch/spk-var-volume
resource=991025
mount --bind "$scratch/var-spk" /var/lib/minidregg/spk
mount --bind "$scratch/etc-minidregg" /etc/minidregg
mount --bind "$scratch/run-minidregg" /run/minidregg
mount -t ext4 -o loop,nosuid,nodev,noatime \
  "/var/lib/minidregg/spk/images/$resource.ext4" "/var/lib/minidregg/spk/vars/$resource"
"$script" attest "$resource"
cp -- "/run/minidregg/spk/volume-attest/$resource.witness" "$scratch/first.witness"
echo 'first witness:'
cat "$scratch/first.witness"

umount "/var/lib/minidregg/spk/vars/$resource"
mount -t ext4 -o loop,nosuid,nodev,noatime \
  "/var/lib/minidregg/spk/images/$resource.ext4" "/var/lib/minidregg/spk/vars/$resource"
"$script" attest "$resource"
cmp -- "$scratch/first.witness" "/run/minidregg/spk/volume-attest/$resource.witness"
echo 'same-host remount witness: identical'

sed -i 's/^deployment_id=.*/deployment_id=cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc/' \
  /etc/minidregg/spk/host-identity
if "$script" attest "$resource" >/dev/null 2>&1; then
  echo 'changed deployment identity unexpectedly admitted' >&2
  exit 1
fi
echo 'changed deployment identity: refused'
printf 'deployment_id=%064d\nhost_id=%064d\n' 1 2 > /etc/minidregg/spk/host-identity
chmod 600 /etc/minidregg/spk/host-identity

umount "/var/lib/minidregg/spk/vars/$resource"
umount /var/lib/minidregg/spk
umount /etc/minidregg
umount /run/minidregg
INNER

echo 'fixture image and witness retained in root-owned private scratch'
