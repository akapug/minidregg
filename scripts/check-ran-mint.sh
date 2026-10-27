#!/usr/bin/env bash
# check-ran-mint.sh -- `Ran.mk` is mentioned, by term and theorems included, only by receiverVerifier
# (scripts/RanMintCensus.lean).  Complements scripts/check-receiver-verifier.sh (text) with a check that
# does not depend on spelling: any forged proof of the process-answered fact contains the constant Ran.mk.
# Tests the instrument every time: each plant is appended to a copy of the census and the run MUST fail
# naming it:
#   (a) `theorem ... : oracleAnswered (.live c) q a := ⟨⟩`   (forge through the unfolded def)
#   (b) `theorem ... : (receiverVerifier (.live c)).Answered q a := ⟨⟩`
# Requires the research umbrella (AxiomCensusResearch) built; it never builds.
# usage: scripts/check-ran-mint.sh [--no-self-test]
set -euo pipefail
root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel); cd "$root"
census=scripts/RanMintCensus.lean
run() { lake env lean "$1" 2>&1; }
if [ "${1:-}" != "--no-self-test" ]; then
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  plant() { # NAME LEAN-TEXT
    local copy="$tmp/Plant_$1.lean"
    python3 - "$census" "$copy" "$2" <<'PY'
import sys
s = open(sys.argv[1]).read()
anchor = 'open RanMintCensus in\nrun_cmd do'
assert s.count(anchor) == 1, 'census anchor moved'
open(sys.argv[2], 'w').write(s.replace(anchor, sys.argv[3] + '\n\n' + anchor))
PY
    if out=$(run "$copy"); then echo "check-ran-mint: INSTRUMENT BROKEN: plant $1 did not fail"; exit 1; fi
    grep -q "Minidregg.RanPlant.$1 mentions Ran.mk" <<<"$out" || { echo "check-ran-mint: INSTRUMENT BROKEN: plant $1 failed without naming itself"; echo "$out" | tail -5; exit 1; }
    echo "check-ran-mint: plant $1 red (as it must be)"
  }
  plant unfolded 'theorem Minidregg.RanPlant.unfolded (c : Minidregg.Compiler.CredentialSignatureIO.NativeConfig) (q : Minidregg.Theory.Receiving.SigQuery) (a : Bool) :
    Minidregg.Compiler.CredentialSignatureAdmission.oracleAnswered (.live c) q a := ⟨⟩'
  plant answered 'theorem Minidregg.RanPlant.answered (c : Minidregg.Compiler.CredentialSignatureIO.NativeConfig) (q : Minidregg.Theory.Receiving.SigQuery) (a : Bool) :
    (Minidregg.Compiler.CredentialSignatureAdmission.receiverVerifier (.live c)).Answered q a := ⟨⟩'
fi
out=$(run "$census") || { echo "$out"; echo "check-ran-mint: RED"; exit 1; }
echo "$out" | grep 'ran-mint census'
echo "check-ran-mint: GREEN"
