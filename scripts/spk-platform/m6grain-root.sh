#!/bin/bash
# scripts/spk-platform/m6grain-root.sh -- the m6grain row's root steps as ONE sudoers target.
#
# two-world-journey.sh runs as the operator; the pipeline runner (another uid) needs root for three
# things around it: stream the operator's run root into its own copy, remove that root after, and
# check that ROOT CLEANUP left nothing behind. One targeted rule covers all three:
#   RUNNER ALL=(root) NOPASSWD: <tree>/scripts/spk-platform/m6grain-root.sh
# and journey-rows probes exactly that rule (`sudo -n -l <this file>`), so a broad rule (`sudo -n
# true`, `rm`, `sh -c`) is never required. Every path is checked against the one shape the row uses
# before anything runs as root.
#   mirror OPERATOR_RUN     a tar stream of the files the row reads, on stdout (the runner extracts it)
#   remove OPERATOR_RUN     rm -rf --one-file-system of the operator's run root
#   survives PATH           exit 0 when a root artifact of a scratch world still exists
set -euo pipefail
usage() { echo "usage: $0 mirror OPERATOR_RUN | remove OPERATOR_RUN | survives PATH" >&2; exit 2; }
[[ $EUID == 0 ]] || { echo 'm6grain root steps require root' >&2; exit 1; }
[[ $# == 2 ]] || usage
run_root() { [[ $1 =~ ^/run/user/[0-9]+/m6g-[0-9a-f]{16}$ && -d $1 ]] || { echo "not an m6grain run root: $1" >&2; exit 2; }; }
case $1 in
  mirror)
    run_root "$2"
    cd "$2"
    exec tar -cf - --ignore-failed-read result.log root-setup.log root-cleanup.log cross-world-plant \
      binary-sha256.txt volume-helper.log cleanup-services.log broker-*.log a/evidence b/evidence 2>/dev/null ;;
  remove)
    run_root "$2"
    exec rm -rf --one-file-system -- "$2" ;;
  survives)
    [[ $2 =~ ^(/etc/mini-spk-volumes/[0-9a-f]{16}\.json|/etc/sudoers\.d/mini-spk-[0-9a-f]{16}|/var/lib/mini-spk-worlds/[0-9a-f]{16}|/run/user/[0-9]+/systemd/user/mini-spk-broker@[0-9a-f]{16}\.service)$ ]] \
      || { echo "not a scratch world's root artifact: $2" >&2; exit 2; }
    exec test -e "$2" ;;
  *) usage ;;
esac
