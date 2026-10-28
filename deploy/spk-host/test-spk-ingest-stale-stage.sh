#!/bin/bash
# A stage left by a killed ingest must not fail the next install of the world. Runs spk-ingest
# against a stub Host (import-limits and materialize only) under the user manager: with the sweep
# the ingest verifies and the stale stage is gone; without it (SWEEP=off) the ingest fails with
# `SPK staging remains after unit success`. Needs a user systemd (XDG_RUNTIME_DIR) and a root
# whose parent directory is named by a 16-hex store id.
# usage: test-spk-ingest-stale-stage.sh FRESH_ROOT [sweep|off]
set -euo pipefail
umask 077
root=$1 mode=${2:-sweep}
here=$(cd "$(dirname "$0")" && pwd)
store=0123456789abcdef
base=$root/$store/spk
mkdir -p "$base/inbox" "$base/packages"
chmod 700 "$root" "$root/$store" "$base" "$base/inbox" "$base/packages"
cat >"$root/host" <<'STUB'
#!/bin/bash
case $1 in
  import-limits) echo "1048576 1048576 60" ;;
  materialize)
    package=$4; packages=$5
    sha=$(sha256sum "$package" | cut -d ' ' -f1)
    mkdir -p "$packages/sha256-$sha/root"; cp "$package" "$packages/sha256-$sha/package.spk"
    chmod 444 "$packages/sha256-$sha/package.spk"; chmod 555 "$packages/sha256-$sha" "$packages/sha256-$sha/root" ;;
esac
STUB
chmod 700 "$root/host"
host_sha=$(sha256sum "$root/host" | cut -d ' ' -f1)
printf 'package' >"$base/inbox/a.spk"; chmod 600 "$base/inbox/a.spk"
# the stale stage: sealed 0555 directories, as a killed materialize leaves them
stale=$base/packages/.spk-stage-4242-1
mkdir -p "$stale/root/dir"; : >"$stale/root/dir/file"; chmod -R a-w "$stale"
script=$here/spk-ingest
if [[ $mode == off ]]; then
  sed '/^while IFS= read -r -d .. stale; do$/,/^done < <(find/d' "$script" >"$root/spk-ingest"; chmod 700 "$root/spk-ingest"; script=$root/spk-ingest
fi
rc=0
out=$("$script" --root "$base" "$root/host" "$host_sha" "$base/inbox/a.spk" 1000 2>&1) || rc=$?
echo "$out" | tail -3
chmod -R u+rwX "$stale" 2>/dev/null || true
if [[ $mode == sweep ]]; then
  [[ $rc == 0 && ! -e $stale ]] && echo "PASS	stale stage swept, ingest verified" || { echo "FAIL	rc=$rc stale=$([[ -e $stale ]] && echo present || echo gone)"; exit 1; }
else
  [[ $rc != 0 && $out == *'SPK staging remains after unit success'* ]] && echo "PASS	without the sweep the ingest fails as reported" || { echo "FAIL	expected the staging refusal, rc=$rc"; exit 1; }
fi
