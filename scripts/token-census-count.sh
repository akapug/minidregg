#!/usr/bin/env bash
# token-census-count.sh — the public TokenCensus number, from the table itself.
# A census row is a non-comment line of TokenCensus/Table.lean whose first field is not `restrict`;
# the scripted fault modes are the mode list of scripts/kn2/plant-token-census-v2.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
rows=$(grep -vE '^(#|restrict \|)' TokenCensus/Table.lean | grep -cE '^[A-Za-z][^|]* \| [^|]* \| [^|]* \| ' || true)
defect=$(grep -vE '^#' TokenCensus/Table.lean | grep -cE '^[A-Za-z][^|]* \| [^|]* \| defect ' || true)
restrict=$(grep -cE '^restrict \| ' TokenCensus/Table.lean || true)
modes=$(sed -n 's/^  \([a-z|-]*\)) ;;$/\1/p' scripts/kn2/plant-token-census-v2.sh | head -1 | tr '|' '\n' | grep -c .)
echo "token-census: $rows private constructors reviewed ($defect open defect rows, $restrict restrict rows); a forgery is planted for every row by TokenCensus/SelfTest.lean, plus $modes scripted fault modes (plant-token-census-v2.sh); table last changed $(git log -1 --format=%cs -- TokenCensus/Table.lean)"
