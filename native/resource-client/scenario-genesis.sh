#!/bin/sh
# native/resource-client/scenario-genesis.sh -- a test scenario's genesis through the ONE template.
#
#   scenario-genesis.sh DIR SPONSOR_PUBLIC_HEX OVERLAY_JQ [ENROLLMENTS.json]
#   env: HOST STORE VERIFIER MINI (the binaries), GENESIS_PARAMS_SH (journey.d/lib/genesis-params.sh
#        resolve_params_sh: the candidate's params.sh)
#
# A scenario says only how its world differs from genesis-params.example.json: OVERLAY_JQ is a jq
# program applied to the example (e.g. 'del(.grainPlatform) | .domain = 8527 | .sponsor.initialBalance
# = 1000'), and ENROLLMENTS, if given, is an absolute path to its further genesis enrollments in the
# compact form genesis.sh completes ({subject, keyId, publicKey, accountId, spendCapabilityId,
# controlCapabilityId, factoryObserveCapabilityId, initialBalance}). Everything the frame requires
# (the clock subject and its ticker, the pay and clock control capabilities, the platform object,
# the semantics digest, the next frame's fields) is genesis.sh's, so a frame bump touches genesis.sh
# and the example alone, never a scenario.
#
# Writes into DIR (which must not hold them): genesis-params.json (the example with the overlay,
# its clock filled by params.sh fill-genesis, a kept grain platform's completion custodian filled as
# `run.sh init` does), genesis-clock.key/.pub (the clock subject's test key), and genesis.sh's
# operator.json (storageRoot DIR/store), profile.json, genesis.json, sponsor- and
# clock-birth-context.json. The caller then runs `mini bootstrap --config DIR/operator.json
# --source DIR/genesis.json`. A scenario may enrol more than genesis.sh's deployment bound of 8
# (GENESIS_EXTRA_ENROLLMENTS_MAX, set here to 256).
set -eu
umask 077
die() { echo "scenario-genesis: $*" >&2; exit 2; }
[ "$#" -eq 3 ] || [ "$#" -eq 4 ] || die "usage: $0 DIR SPONSOR_PUBLIC_HEX OVERLAY_JQ [ENROLLMENTS.json]"
dir=$1 public=$2 overlay=$3 extra=${4:-}
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
absolute() {  # an executable's absolute path (genesis.sh takes only absolute ones)
  case "$1" in /*) printf '%s\n' "$1" ;; *) printf '%s/%s\n' "$(CDPATH='' cd -- "$(dirname -- "$1")" && pwd)" "$(basename -- "$1")" ;; esac
}
for name in HOST STORE VERIFIER MINI GENESIS_PARAMS_SH; do
  eval "value=\${$name:-}"
  [ -n "$value" ] || die "$name is not set"
done
host=$(absolute "$HOST") store=$(absolute "$STORE") verifier=$(absolute "$VERIFIER") mini=$(absolute "$MINI")
dir=$(CDPATH='' cd -- "$dir" && pwd) || die "not a directory: $1"
[ -z "$extra" ] || case "$extra" in /*) ;; *) die "ENROLLMENTS must be an absolute path" ;; esac
[ ! -e "$dir/genesis-params.json" ] || die "refusing existing $dir/genesis-params.json"

jq "$overlay" "$here/genesis-params.example.json" >"$dir/genesis-params.json" ||
  die "the overlay does not apply to genesis-params.example.json: $overlay"
sh "$GENESIS_PARAMS_SH" fill-genesis "$dir/genesis-params.json"
. "$here/journey.d/lib/genesis-params.sh"
fill_completion_custodian "$dir/genesis-params.json" "$dir" "$mini"
"$mini" keygen --secret "$dir/genesis-clock.key" --public "$dir/genesis-clock.pub" --no-prerotation \
  >"$dir/genesis-clock.pub.hex" || die "clock subject keygen failed"
clock=$(od -An -tx1 -v "$dir/genesis-clock.pub" | tr -d ' \n')
EXTRA_GENESIS_ENROLLMENTS=$extra GENESIS_EXTRA_ENROLLMENTS_MAX=256 \
  sh "$here/genesis.sh" "$dir/genesis-params.json" "$public" "$clock" "$host" "$store" "$verifier" "$dir"
