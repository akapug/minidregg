#!/usr/bin/env bash
# Frozen pre-merge cohort plus the separately hashed five-file patch only.
set -euo pipefail
[ "$#" = 3 ] || { echo 'usage: controller-batch.sh SOURCE TARGET NEW_EVIDENCE' >&2; exit 2; }
source=$1 target=$2 evidence=$3
[ ! -e "$evidence" ]
mkdir -m 700 "$evidence"
cd "$source"
export CARGO_TARGET_DIR="$target"
find native -type f ! -path '*/target/*' -print0 | sort -z | xargs -0 sha256sum > "$evidence/source-files.sha256"
sha256sum Cargo.toml Cargo.lock protocol/host-operations.json >> "$evidence/source-files.sha256"
run() { local name=$1; shift; SWARM_MEM_MAX=4G swarm-build taskset -c "${REVIEW_CORES:-22,23}" cargo test -j2 --offline --locked -p minidregg-spk-host --lib "$@" -- --nocapture > "$evidence/$name.log" 2>&1; }
run controller namespace_identity::controller_tests::
run forward agent_api_server::tests::
run reverse agent_api_native::tests::
SWARM_MEM_MAX=4G swarm-build taskset -c "${REVIEW_CORES:-22,23}" cargo build -j2 --offline --locked --release \
 -p minidregg-spk-host --bin spk-host --bin mini-spk-broker --bin mini-spk-volume-helper --bin spk-data-publish \
 -p minidregg-resource-client --bin mini -p minidregg-grain-runtime --bin grain-runtime > "$evidence/release.log" 2>&1
mkdir -m 700 "$evidence/bin"
for bin in spk-host mini-spk-broker mini-spk-volume-helper spk-data-publish mini grain-runtime; do install -m 0555 "$target/release/$bin" "$evidence/bin/$bin"; done
sha256sum "$evidence/bin/"* > "$evidence/binaries.sha256"
sha256sum -c "$evidence/source-files.sha256" > "$evidence/source-recheck.log"
printf 'scoped_tests_and_release=passed\n' > "$evidence/result.txt"
