#!/bin/sh
# Check fresh agent allocation data without creating keys, a Store or code.
set -eu
[ "$#" -eq 1 ] || { echo "usage: $0 ALLOCATION_JSON" >&2; exit 2; }
HERE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO=$(CDPATH='' cd -- "$HERE/../.." && pwd)
. "$REPO/scripts/workroom/agent-enrollment.sh"
workroom_agent_validate "$1"
