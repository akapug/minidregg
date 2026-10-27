#!/usr/bin/env bash
# Scoped qualification of a frozen, independent Rust source and target.
set -euo pipefail
[ "$#" -eq 2 ] || { echo 'usage: oracle-u3-rust-batch.sh SNAPSHOT NEW_EVIDENCE_DIR' >&2; exit 2; }
snapshot=$1 evidence=$2
[ ! -e "$evidence" ] || { echo 'batch evidence exists' >&2; exit 1; }
mkdir -m 700 "$evidence"
cd "$snapshot"
export CARGO_TARGET_DIR="$snapshot/target"
find native -type f ! -path '*/target/*' -print0 | sort -z | xargs -0 sha256sum > "$evidence/source-files.sha256"
sha256sum Cargo.toml Cargo.lock Kernel/ContentResource.lean Host/Main.lean protocol/host-operations.json >> "$evidence/source-files.sha256"
run() {
  local name=$1; shift
  SWARM_MEM_MAX=4G swarm-build taskset -c 22,23 cargo test -j2 --offline --locked "$@" -- --nocapture > "$evidence/$name.log" 2>&1
}
run source-stop -p minidregg-spk-host --lib source_stop
run stop-inspection-host -p minidregg-spk-host --lib stop_inspection
run agent-route -p minidregg-spk-host --lib grain::agent_route::tests::
run stop-inspection-client -p minidregg-resource-client --bin mini stop_inspection
run operator-peer-client -p minidregg-resource-client --bin mini operator_peer
run public-proxy -p minidregg-resource-client --bin mini public_proxy::tests
run application-tools -p minidregg-grain-runtime --bin grain-runtime application_tools::tests
run supervised-read -p minidregg-grain-runtime --bin grain-runtime supervised_read_runner_can_refuse_before_native_spawn
run shared-app-refs -p minidregg-grain-runtime --bin grain-runtime shared_app_refs::tests
run operator-peer-runtime -p minidregg-grain-runtime --bin grain-runtime operator_peer
SWARM_MEM_MAX=4G swarm-build taskset -c 22,23 cargo build -j2 --offline --locked --release \
  -p minidregg-spk-host --bin spk-host --bin mini-spk-broker --bin mini-spk-volume-helper --bin spk-data-publish \
  -p minidregg-resource-client --bin mini -p minidregg-grain-runtime --bin grain-runtime > "$evidence/release.log" 2>&1
mkdir -m 700 "$evidence/bin"
for bin in spk-host mini-spk-broker mini-spk-volume-helper spk-data-publish mini grain-runtime; do
  install -m 0555 "$CARGO_TARGET_DIR/release/$bin" "$evidence/bin/$bin"
done
sha256sum "$evidence/bin/"* > "$evidence/binaries.sha256"
printf 'scoped_tests_and_release=passed\n' > "$evidence/result.txt"
