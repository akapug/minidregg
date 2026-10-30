#!/usr/bin/env bash
# Root-only disposable physical fixture. Supply the independently built test
# binary, this directory's peer helper, and an empty private evidence directory.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo 'requires sudo on the designated Linux test host' >&2; exit 2; }
[ "$#" = 3 ] || { echo 'usage: mapped-controller-review.sh TEST_BINARY PEER_PY EVIDENCE' >&2; exit 2; }
test_binary=$1 peer=$2 evidence=$3
mkdir -m 700 "$evidence"
exec 9>/run/mini-spk-world-install.lock
flock -x 9
store=$(python3 -c 'import secrets; print(secrets.token_hex(8))')
account="mini-c-$store"
world="/var/lib/mini-spk-worlds/$store"
uid=165534
! getent passwd "$uid" >/dev/null
! getent group "$uid" >/dev/null
! getent passwd "$account" >/dev/null
[ ! -e "$world" ]
python3 - "$uid" <<'PY'
import glob,json,sys
uid=int(sys.argv[1])
def contains(o):
    if isinstance(o,dict): return any(contains(v) for v in o.values())
    if isinstance(o,list): return any(contains(v) for v in o)
    return type(o) is int and o == uid
for p in glob.glob('/etc/mini-spk-volumes/*.json') + glob.glob('/etc/mini-spk-controller-reservations/*'):
    try:
        with open(p) as f: obj=json.load(f)
    except (OSError, ValueError) as e:
        raise SystemExit(f'cannot safely inspect reservation {p}: {e}')
    if contains(obj): raise SystemExit(f'candidate UID is already registered: {p}')
PY
created=0
group_created=0
pids=()
cleanup() {
    for p in "${pids[@]}"; do [ -z "$p" ] || kill "$p" 2>/dev/null || :; done
    for p in "${pids[@]}"; do [ -z "$p" ] || wait "$p" 2>/dev/null || :; done
    if [ "$created" = 1 ]; then userdel "$account"; fi
    if [ "$group_created" = 1 ] && getent group "$account" >/dev/null; then groupdel "$account"; fi
    if [ -d "$world" ]; then rm -rf --one-file-system -- "$world"; fi
}
trap cleanup EXIT
groupadd --system --gid "$uid" "$account"
group_created=1
useradd --system --uid "$uid" --gid "$account" --no-user-group --no-create-home --no-log-init --home-dir "$world/controller/home" --shell /usr/sbin/nologin "$account"
created=1
getent passwd "$account" > "$evidence/passwd.txt"
getent group "$account" > "$evidence/group.txt"
mkdir -p "$world/controller/home" "$world/controller/reverse" "$world/agent" "$world/attest" "$world/spk" "$world/foreign"
chmod 755 "$world" "$world/controller" "$world/attest" "$world/spk"
cp "$peer" "$world/peer.py"
chmod 644 "$world/peer.py"
peer="$world/peer.py"
chown 65534:65534 "$world/foreign"
chmod 755 "$world/foreign"
chown "$uid:$uid" "$world/controller/home"
chmod 700 "$world/controller/home"
chown "$uid:$uid" "$world/controller/reverse"
chmod 711 "$world/controller/reverse"
chown hbox:hbox "$world/agent"
chmod 700 "$world/agent"
printf '{}' > "$world/config.json"
printf witness > "$world/attest/$store-grain.witness"
python3 - "$store" "$uid" "$world/controller/namespace.json" <<'PY'
import json,sys
store,uid,path=sys.argv[1],int(sys.argv[2]),sys.argv[3]
d={'protocol':'mini-spk-controller-namespace-v1','store':store,'deploymentId':'1'*64,'hostId':'2'*64,'operatorUid':1000,'operatorGid':1000,'controllerUid':uid,'controllerGid':uid,'account':'mini-c-'+store}
with open(path,'w') as f: json.dump(d,f,separators=(',',':'))
PY
chmod 644 "$world/controller/namespace.json" "$world/config.json" "$world/attest/$store-grain.witness"
setpriv --reuid "$uid" --regid "$uid" --clear-groups python3 "$peer" reverse "$world" >"$evidence/reverse.log" 2>&1 & pids+=("$!")
setpriv --reuid 65534 --regid 65534 --clear-groups python3 "$peer" foreign-reverse "$world" >"$evidence/foreign-reverse.log" 2>&1 & pids+=("$!")
for i in $(seq 1 1000); do [ -e "$world/controller/reverse/reverse-ready" ] && [ -e "$world/foreign/reverse-ready" ] && break; sleep .02; done
[ -e "$world/controller/reverse/reverse-ready" ]
[ -e "$world/foreign/reverse-ready" ]
runuser -u hbox -- env REVIEW_CONTROLLER_WORLD="$world" REVIEW_CONTROLLER_STORE="$store" REVIEW_CONTROLLER_UID="$uid" "$test_binary" agent_api_server::review_controller::mapped_controller_receipt_forward_and_reverse_peers --exact --ignored --nocapture --test-threads=1 >"$evidence/rust.log" 2>&1 & testpid=$!; pids+=("$testpid")
for i in $(seq 1 1000); do [ -e "$world/agent/ready" ] && break; kill -0 "$testpid"; sleep .02; done
[ -e "$world/agent/ready" ]
setpriv --reuid 65534 --regid 65534 --clear-groups python3 "$peer" foreign "$world" >"$evidence/foreign.log" 2>&1
grep -q '^foreign-forward-acl-refused$' "$evidence/foreign.log"
setpriv --reuid "$uid" --regid "$uid" --clear-groups python3 "$peer" controller "$world" >"$evidence/controller.log" 2>&1
wait "$testpid"
pids[2]=""
wait "${pids[0]}"
pids[0]=""
kill "${pids[1]}" 2>/dev/null || :
wait "${pids[1]}" 2>/dev/null || :
pids=()
grep -q '^reverse-controller-responded$' "$evidence/reverse.log"
grep -q 'mapped-registered-controller-forward-and-reverse-pass' "$evidence/rust.log"
printf 'mapped controller, foreign ACL refusal, forward and reverse peer: passed\n' > "$evidence/result.txt"
