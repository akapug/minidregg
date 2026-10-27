#!/usr/bin/env bash
# scripts/gen-default-laws.sh [--check]: emit (or check) deploy/shell/templates/defaults/ from
# Kernel/DefaultLaw.lean. Run from anywhere in the repository; needs the Lean build of
# Kernel.DefaultLaw and Host.Json (lake env lean --run elaborates the script against them).
set -euo pipefail
cd "$(dirname "$0")/.."
exec lake env lean --run scripts/gen-default-laws.lean "$@"
