#!/usr/bin/env bash
# An isolated test snapshot with the review hook and test already injected.
set -euo pipefail
: "${REVIEW_SNAPSHOT:?set isolated snapshot path}"
: "${REVIEW_FIXTURE_PARENT:?set protected app-searchable fixture parent}"
: "${CARGO_TARGET_DIR:?set independent cargo target}"
cd "$REVIEW_SNAPSHOT"
if [ "$#" -eq 0 ]; then set -- positive private acl early-exit; fi
for mode in "$@"; do
    fixture=$(mktemp -d "$REVIEW_FIXTURE_PARENT/mapped-worker.XXXXXXXX")
    mounted=0
    cleanup() {
        if [ "$mounted" = 1 ]; then sudo -n umount "$fixture/var"; fi
        sudo -n rm -rf --one-file-system -- "$fixture"
    }
    trap cleanup EXIT
    chmod 755 "$fixture"
    mkdir -p "$fixture/world/attest" "$fixture/world/spk" "$fixture/source" "$fixture/image/opt/oracle-data" "$fixture/image/var" "$fixture/image/tmp" "$fixture/image/proc" "$fixture/image/dev" "$fixture/var"
    chmod -R go-w "$fixture/world" "$fixture/image" "$fixture/source"
    chmod 755 "$fixture/world" "$fixture/world/attest" "$fixture/world/spk" "$fixture/source" "$fixture/image" "$fixture/image/opt" "$fixture/image/opt/oracle-data" "$fixture/image/var" "$fixture/image/tmp" "$fixture/image/proc" "$fixture/image/dev"
    printf witness > "$fixture/world/attest/store-grain.witness"
    chmod 600 "$fixture/world/attest/store-grain.witness"
    printf 'public fixture\n' > "$fixture/source/probe.txt"
    gcc -static -Os -s mapped-probe.c -o "$fixture/image/probe"
    chmod 555 "$fixture/image/probe"
    sudo -n mount -t tmpfs -o size=16m,mode=0700,uid=100000,gid=100000,nosuid,nodev mapped-review-var "$fixture/var"
    mounted=1
    REVIEW_MOUNT_DIR="$fixture" REVIEW_MOUNT_MODE="$mode" SWARM_MEM_MAX=4G \
        swarm-build taskset -c 22,23 cargo test -j2 --offline -p minidregg-spk-host --lib \
        resident_launch::review_mount_test::mapped_worker_public_data_mount_and_preflight -- \
        --exact --ignored --nocapture --test-threads=1 > "mapped-$mode.log" 2>&1
    cleanup
    trap - EXIT
    echo "mapped-$mode: passed"
done
