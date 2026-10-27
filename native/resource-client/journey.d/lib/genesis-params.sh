# native/resource-client/journey.d/lib/genesis-params.sh -- which genesis-clock helper a driver runs.
# Sourced (POSIX sh) by every driver that fills a genesis clock:
#
#   . "$TREE/native/resource-client/journey.d/lib/genesis-params.sh"
#   resolve_params_sh "$TREE" || exit 2      # sets GENESIS_PARAMS_SH (exported)
#   sh "$GENESIS_PARAMS_SH" fill-genesis PARAMS.json
#
# Policy: when a candidate is in play (CANDIDATE: the manifest's `candidate` entry, the set's
# provenance.json or the set directory), the helper is the one that candidate SHIPS:
# $(dirname CANDIDATE)/params.sh. A candidate without params.sh is refused by name, never
# replaced by the source copy. Only with no candidate at all (a dev run from the tree) is the
# source tree's deploy/candidate/params.sh used. One stderr line says which.
resolve_params_sh() {  # resolve_params_sh SOURCE_TREE_ROOT
  if [ -n "${CANDIDATE:-}" ]; then
    if [ -d "$CANDIDATE" ]; then _gp_dir=$CANDIDATE; else _gp_dir=$(dirname -- "$CANDIDATE"); fi
    GENESIS_PARAMS_SH=$_gp_dir/params.sh
    [ -f "$GENESIS_PARAMS_SH" ] || {
      echo "genesis-params: the candidate $_gp_dir ships no params.sh (CANDIDATE=$CANDIDATE); rebuild the set" >&2
      return 1; }
    echo "genesis-params: params.sh from the candidate: $GENESIS_PARAMS_SH" >&2
  else
    GENESIS_PARAMS_SH=${1:?resolve_params_sh SOURCE_TREE_ROOT}/deploy/candidate/params.sh
    [ -f "$GENESIS_PARAMS_SH" ] || {
      echo "genesis-params: no candidate in play and no source helper at $GENESIS_PARAMS_SH" >&2
      return 1; }
    echo "genesis-params: params.sh from the source tree (no candidate in play): $GENESIS_PARAMS_SH" >&2
  fi
  export GENESIS_PARAMS_SH
}

# A driver that runs genesis.sh itself (not `run.sh init`) fills the grain platform's completion
# custodian the way init does (deploy/candidate/run.sh, deploy/market/INSTALL.md §0): a fresh key pair
# under DIR/keys/completion.{seed,pub}, its public half into .grainPlatform.completionCustodianKey.
# Params without a grainPlatform, or with the key already filled, are left as they are. The key is a
# test key of this run, like every other key the driver makes.
fill_completion_custodian() {  # fill_completion_custodian PARAMS.json DIR MINI
  jq -e 'has("grainPlatform") and .grainPlatform.completionCustodianKey == null' "$1" >/dev/null || return 0
  mkdir -p -m 700 "$2/keys"
  "$3" keygen --secret "$2/keys/completion.seed" --public "$2/keys/completion.pub" --no-prerotation \
    >"$2/keys/completion.pub.hex" || { echo "genesis-params: completion custodian keygen failed" >&2; return 1; }
  _gp_key=$(od -An -tx1 -v "$2/keys/completion.pub" | tr -d ' \n')
  jq --arg k "$_gp_key" '.grainPlatform.completionCustodianKey = $k' "$1" >"$1.filled" && mv "$1.filled" "$1"
}
