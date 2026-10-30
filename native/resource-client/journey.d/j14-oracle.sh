#!/usr/bin/env bash
# Fresh composed J14: a room resident and its Oracle share one native Store.
# Runtime/data inputs are operator assets; no preissued task/route is accepted.
set -euo pipefail
here=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec python3 "$here/j14-oracle.py"
