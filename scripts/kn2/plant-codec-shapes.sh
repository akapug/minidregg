#!/usr/bin/env bash
# Plants for the structural half of the persisted codec census. Mutates temp
# copies only; each must turn the census RED and name the identity.
#  shape-user : a new codec that USES an existing identity's owner with another
#               structure (identity unchanged) -> its fingerprint moves, red by name.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
OUT=${1:?usage: plant-codec-shapes.sh OUT}
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
SCRATCH=$(mktemp -d); trap 'rm -rf "$SCRATCH"' EXIT
cd "$ROOT"

run_census() {
  lake env lean "$1/ShapePlant.lean"
}

expect_red() {
  local name=$1 source_root=$2 expected=$3
  if run_census "$source_root" >"$OUT/$name.log" 2>&1; then
    printf 'FAIL shape plant %s unexpectedly green\n' "$name"; exit 1
  fi
  grep -F 'persisted codec structure changed under an unchanged identity' "$OUT/$name.log" >/dev/null ||
    { cat "$OUT/$name.log"; printf 'FAIL shape plant %s red without the structural verdict\n' "$name"; exit 1; }
  grep -F "$expected" "$OUT/$name.log" >/dev/null ||
    { cat "$OUT/$name.log"; printf 'FAIL shape plant %s did not name %s\n' "$name" "$expected"; exit 1; }
  printf 'RED as intended: shape %s (%s)\n' "$name" "$expected"
}

python3 - "$ROOT" "$SCRATCH" <<'PY'
import pathlib, sys
root, scratch = map(pathlib.Path, sys.argv[1:])
census = (root / "Compiler/PersistedCodecTagCensus.lean").read_text()
pins = (root / "Compiler/PersistedCodecShapes.lean").read_text()
marker = "\n#assert_persisted_codec_tags\nend Minidregg.Compiler.PersistedCodecTagCensus"
assert census.count(marker) == 1
probe = ("\ndef encodeShapePlant (n : Nat) : List UInt8 :=\n"
         "  Minidregg.Compiler.DurableReceiverCodec.wireFrame ++"
         " Minidregg.Compiler.Tower256ConcreteBackend.StreamCodec.nat.encode n\n")
mutated = census.replace(marker, probe + marker)
assert mutated != census
t = scratch / "shape-user"; t.mkdir(parents=True)
(t / "ShapePlant.lean").write_text(mutated)
print("MUTATION ASSERTED shape-user: a new codec user of DREGG.DURABLE.IMAGE", flush=True)
PY
expect_red shape-user "$SCRATCH/shape-user" "DREGG.DURABLE.IMAGE"
echo "PASS codec shape plants"
