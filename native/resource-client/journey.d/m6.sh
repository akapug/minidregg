#!/usr/bin/env bash
# Journey hook m6 (list item 6; ruling D9, WEB-SPK-PUBLIC section 4.7): a thin delegate, not a second
# scenario. It runs the pipeline row m6grain's own scenario, scripts/spk-platform/two-world-journey.sh
# full, on its own two scratch worlds, with the edge phase required (a Caddy in front of each world's
# route socket: authenticated GET 200, anonymous refused, WebSocket 101). It never acts on the
# journey's Store.
#
# Inputs (exit 5 = UNCONFIGURED, naming the first one absent; the probes are row_m6grain's):
#   the candidate's bin/ (CANDIDATE's directory, else SPK_HOST_BIN's): mini minidregg-host
#     minidregg-link-sqlite-store minidregg-credential-signature-verifier minidregg-client-consent
#     spk-host mini-spk-broker mini-spk-volume-helper
#   this journey running AS the operator (MINI_OPERATOR_UID / MINI_OPERATOR_NAME, default 1001 / ember),
#     with linger, a /etc/subuid range of at least 32, newuidmap/newgidmap, and
#     sudo -n for deploy/spk-host/install-user-world of THIS tree
#   CADDY (else caddy on PATH) and openssl, for the edge phase
#   the pinned signed sntfy: MINI_TEST_SPK, else scripts/spk-platform/fetch-test-spk.sh
# Last stdout line: the scenario's result.log. Last stderr line: the verdict or the first failing step.
set -u
HERE=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
REPO=$(CDPATH='' cd -- "$HERE/../.." && pwd)
. "$HERE/journey.d/lib/shortdir.sh"
unconfigured() { echo "$*" >&2; exit 5; }

if [ -n "${CANDIDATE:-}" ]; then bin=$(dirname -- "$CANDIDATE")/bin
elif [ -n "${SPK_HOST_BIN:-}" ]; then bin=$(dirname -- "$SPK_HOST_BIN")
else unconfigured "missing input: CANDIDATE or SPK_HOST_BIN (the candidate's bin/)"; fi
for b in mini minidregg-host minidregg-link-sqlite-store minidregg-credential-signature-verifier \
    minidregg-client-consent spk-host mini-spk-broker mini-spk-volume-helper; do
  [ -x "$bin/$b" ] || unconfigured "missing input: $bin/$b"
done
op_uid=${MINI_OPERATOR_UID:-1001} op_name=${MINI_OPERATOR_NAME:-ember}
[ "$(id -u)" = "$op_uid" ] || unconfigured "missing input: M6 runs as the operator uid $op_uid ($op_name); this journey runs as $(id -u)"
[ "$(loginctl show-user "$op_uid" -p Linger --value 2>/dev/null)" = yes ] || unconfigured "missing input: linger for operator uid $op_uid"
awk -F: -v user="$op_name" '$1==user && $3>=32 {ok=1} END {exit !ok}' /etc/subuid 2>/dev/null \
  || unconfigured "missing input: /etc/subuid range (>=32) for $op_name"
for t in /usr/bin/newuidmap /usr/bin/newgidmap; do [ -x "$t" ] || unconfigured "missing input: $t (uidmap)"; done
installer=$REPO/deploy/spk-host/install-user-world
sudo -n -l "$installer" >/dev/null 2>&1 || unconfigured "missing input: sudoers rule $op_name ALL=(root) NOPASSWD: $installer"
CADDY=${CADDY:-$(command -v caddy 2>/dev/null || :)}
[ -n "$CADDY" ] && [ -x "$CADDY" ] || unconfigured "missing input: CADDY (no caddy on PATH) for the edge phase"
command -v openssl >/dev/null 2>&1 || unconfigured "missing input: openssl for the edge phase's test certificate"
spk=${MINI_TEST_SPK:-}
if [ -z "$spk" ]; then
  spk=$(sh "$REPO/scripts/spk-platform/fetch-test-spk.sh" 2>"$JOURNEY_STEP_DIR/fetch-spk.err") \
    || unconfigured "missing input: the pinned sntfy (fetch-test-spk.sh: $(tail -1 "$JOURNEY_STEP_DIR/fetch-spk.err"))"
fi
[ -f "$spk" ] || unconfigured "missing input: signed SPK $spk"

journey_shortdir m6   # both worlds' Store sockets live under the short directory, kept as $JOURNEY_STEP_DIR/rt
mkdir -m 700 "$JOURNEY_D"
run=$JOURNEY_D/g
CADDY=$CADDY MINI_OPERATOR_UID=$op_uid MINI_OPERATOR_NAME=$op_name \
  bash "$REPO/scripts/spk-platform/two-world-journey.sh" full "$bin" "$bin" "$run" "$spk" \
  >"$JOURNEY_STEP_DIR/m6.out" 2>"$JOURNEY_STEP_DIR/m6.err"
rc=$?
echo "$run/result.log"
if [ "$rc" != 0 ]; then
  echo "two-world-journey.sh exit $rc: $(tail -1 "$JOURNEY_STEP_DIR/m6.err" 2>/dev/null)" >&2
  exit "$rc"
fi
for w in a b; do
  [ "$(cat "$run/$w/evidence/edge-a.exit" 2>/dev/null)" = 0 ] || { echo "world $w: the edge phase did not pass" >&2; exit 1; }
done
grep -q '^PASS two-world ' "$run/result.log" || { echo "result.log has no PASS two-world line" >&2; exit 1; }
echo "two worlds: install, start, http, edge (GET 200 / anonymous refused / WebSocket 101), stop, restart, second instance: $(cat "$run/a/evidence/edge-a.result")" >&2
