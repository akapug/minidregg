#!/usr/bin/env bash
# One runtime-only qualification from a frozen U3 overlay.
set -euo pipefail
[ "$#" -ge 4 ] || { echo 'usage: oracle-u3-enrollment-batch.sh SOURCE TARGET NEW_EVIDENCE FILTER...' >&2; exit 2; }
source=$1 target=$2 evidence=$3; shift 3
[ ! -e "$evidence" ]
mkdir -m 700 "$evidence"
cd "$source"
export CARGO_TARGET_DIR="$target"
find native -type f -print0 | sort -z | xargs -0 sha256sum > "$evidence/source-files.sha256"
sha256sum Cargo.toml Cargo.lock protocol/host-operations.json >> "$evidence/source-files.sha256"
i=0
for filter in "$@"; do
  i=$((i+1)); log="$evidence/test-$i.log"
  printf '%s\n' "$filter" > "$evidence/test-$i.filter"
  SWARM_MEM_MAX=4G swarm-build taskset -c 22,23 cargo test -j2 --offline --locked \
    -p minidregg-grain-runtime --bin grain-runtime "$filter" -- --nocapture > "$log" 2>&1
  grep -Eq '^running [1-9][0-9]* tests?$' "$log" || { echo "no tests matched: $filter" >&2; exit 1; }
done
SWARM_MEM_MAX=4G swarm-build taskset -c 22,23 cargo build -j2 --offline --locked --release \
  -p minidregg-grain-runtime --bin grain-runtime > "$evidence/release.log" 2>&1
install -m 0555 "$target/release/grain-runtime" "$evidence/grain-runtime"
sha256sum -c "$evidence/source-files.sha256" > "$evidence/source-recheck.log"
sha256sum "$evidence/grain-runtime" > "$evidence/binary.sha256"
printf 'scoped_tests_and_release=passed\n' > "$evidence/result.txt"
