#!/usr/bin/env bash
# Run only in a disposable, protected snapshot on Linux. sudo changes ownership
# only inside a freshly-created fixture and deletes only that fixture at exit.
set -euo pipefail
: "${ATTACHMENT_NAMESPACE_PARENT:?set to an operator-owned protected directory}"
: "${CARGO_TARGET_DIR:?set to an independent target directory}"
fixture=$(mktemp -d "$ATTACHMENT_NAMESPACE_PARENT/namespace-review.XXXXXXXX")
cleanup() { sudo -n rm -rf -- "$fixture"; }
trap cleanup EXIT
chmod 700 "$fixture"
mkdir -p "$fixture/root/attest" "$fixture/root/spk/public-data" "$fixture/root/spk/packages" "$fixture/source" "$fixture/foreign" "$fixture/app"
printf '{}' > "$fixture/root/config.json"
printf 'witness' > "$fixture/root/attest/store-grain.witness"
chmod 644 "$fixture/root/config.json" "$fixture/root/attest/store-grain.witness"
chmod 755 "$fixture/root" "$fixture/root/attest" "$fixture/root/spk" "$fixture/foreign" "$fixture/app"
sudo -n chown -R 0:0 "$fixture/root"
sudo -n chown 0:100001 "$fixture/root"
sudo -n chown 1000:0 "$fixture/root/spk/public-data" "$fixture/root/spk/packages"
sudo -n chmod 2755 "$fixture/root/spk/public-data" "$fixture/root/spk/packages"
sudo -n chown 100001:100001 "$fixture/foreign"
sudo -n chown 100000:100000 "$fixture/app"
ln -s root "$fixture/link"
export ATTACHMENT_NAMESPACE_FIXTURE="$fixture"
export ATTACHMENT_BWRAP_SHA256
ATTACHMENT_BWRAP_SHA256=$(sha256sum /usr/local/libexec/mini-grain-bwrap | cut -d ' ' -f 1)
SWARM_MEM_MAX=4G swarm-build cargo run -j2 --offline --manifest-path deploy/oracle/attachment-review/Cargo.toml --bin namespace-review
