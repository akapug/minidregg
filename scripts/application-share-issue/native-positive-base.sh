#!/bin/sh
# Fresh two-subject app/session base with a positive, operator-pinned initial
# payload byte tariff. Configuration is supplied explicitly; private source
# copies preserve the reviewed inputs byte for byte.
set -eu
umask 077

if [ "$#" -ne 2 ]; then
  echo "usage: $0 SOURCE_MATCHED_HOST NEW_EVIDENCE_DIRECTORY" >&2
  exit 2
fi
HOST=$1
EVIDENCE=$2
# a staged provision.sh resolves its genesis-clock helper from this tree (scripts/workroom/provision.sh)
GENESIS_PARAMS_TREE=${GENESIS_PARAMS_TREE:-$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)}
export GENESIS_PARAMS_TREE
PROVISION_SOURCE=${PROVISION_SOURCE:?set exact reviewed provision.sh}
MEMBER_SOURCE=${MEMBER_SOURCE:?set exact reviewed native-share-member.sh}
APP_SOURCE=${APP_SOURCE:?set exact reviewed native-share-base.sh}
MINI=${MINI:?set source-matched Mini}
STORE_BINARY=${STORE_BINARY:?set source-matched SQLite Store helper}
SIGNATURE_BINARY=${SIGNATURE_BINARY:?set source-matched signature helper}
[ ! -e "$EVIDENCE" ] || { echo "evidence directory exists" >&2; exit 2; }
[ ! -e "$EVIDENCE.source-stage" ] || {
  echo "source stage already exists" >&2; exit 2;
}
for file in "$PROVISION_SOURCE" "$MEMBER_SOURCE" "$APP_SOURCE"; do
  [ -f "$file" ] || { echo "missing reviewed source: $file" >&2; exit 2; }
done
STAGE=$EVIDENCE.source-stage
mkdir -m 700 "$STAGE"
sha256sum "$0" "$HOST" "$MINI" "$STORE_BINARY" "$SIGNATURE_BINARY" \
  "$PROVISION_SOURCE" "$MEMBER_SOURCE" "$APP_SOURCE" \
  >"$STAGE/input-sha256.txt"
sha256sum -c "$STAGE/input-sha256.txt" >"$STAGE/input-precheck.txt"
mkdir -p "$STAGE/scripts/workroom" "$STAGE/scripts/grain-birth" \
  "$STAGE/scripts/application-current-birth"
cp "$PROVISION_SOURCE" "$STAGE/scripts/workroom/provision.sh"
cp "$MEMBER_SOURCE" "$STAGE/scripts/grain-birth/native-share-member.sh"
cp "$APP_SOURCE" "$STAGE/scripts/application-current-birth/native-share-base.sh"
chmod 700 "$STAGE/scripts/workroom/provision.sh" \
  "$STAGE/scripts/grain-birth/native-share-member.sh" \
  "$STAGE/scripts/application-current-birth/native-share-base.sh"
sha256sum "$STAGE/scripts/workroom/provision.sh" \
  "$STAGE/scripts/grain-birth/native-share-member.sh" \
  "$STAGE/scripts/application-current-birth/native-share-base.sh" \
  >"$STAGE/private-source-sha256.txt"
sha256sum -c "$STAGE/private-source-sha256.txt" \
  >"$STAGE/private-source-precheck.txt"
# Fund the positive-byte fixture generously unless its caller chose balances.
# The member starts at one so the subsequent funding journey remains observable.
WORKROOM_SPONSOR_BALANCE=${WORKROOM_SPONSOR_BALANCE-1000000}
WORKROOM_TOOL_BALANCE=${WORKROOM_TOOL_BALANCE-1000000}
WORKROOM_TARIFF_PER_INITIAL_PAYLOAD_BYTE=1
MEMBER_INITIAL_BALANCE=1
export WORKROOM_SPONSOR_BALANCE WORKROOM_TOOL_BALANCE
export WORKROOM_TARIFF_PER_INITIAL_PAYLOAD_BYTE MEMBER_INITIAL_BALANCE
MINI="$MINI" STORE_BINARY="$STORE_BINARY" SIGNATURE_BINARY="$SIGNATURE_BINARY" \
  /bin/sh "$STAGE/scripts/application-current-birth/native-share-base.sh" \
    "$HOST" "$EVIDENCE" \
    >"$STAGE/base.stdout" 2>"$STAGE/base.stderr"
cp "$STAGE/base.stdout" "$EVIDENCE/positive-base.stdout"
cp "$STAGE/base.stderr" "$EVIDENCE/positive-base.stderr"
cp "$STAGE/input-sha256.txt" "$EVIDENCE/positive-input-sha256.txt"
cp "$STAGE/private-source-sha256.txt" "$EVIDENCE/private-source-sha256.txt"
cp "$STAGE/scripts/workroom/provision.sh" "$EVIDENCE/positive-provision.sh"
cp "$STAGE/scripts/grain-birth/native-share-member.sh" \
  "$EVIDENCE/positive-member.sh"
jq -e '.tariffPerInitialPayloadByte == 1' \
  "$EVIDENCE/workroom/operator.json" >/dev/null
jq -e '.tariffPerInitialPayloadByte == "1"' \
  "$EVIDENCE/workroom/genesis.json" >/dev/null
sha256sum -c "$EVIDENCE/positive-input-sha256.txt" \
  >"$EVIDENCE/positive-input-recheck.txt"
sha256sum -c "$EVIDENCE/private-source-sha256.txt" \
  >"$EVIDENCE/private-source-recheck.txt"
echo "positive byte-tariff app/session base PASS"
