#!/usr/bin/env bash
# Disposable root-created systemd socket activation credential control.
# The actual mini proxy needs a separate integration check.
set -euo pipefail
[ "$#" -eq 1 ] || { echo 'usage: oracle-u3-systemd-peer-probe.sh NEW_EVIDENCE_DIR' >&2; exit 2; }
evidence=$1
[ ! -e "$evidence" ] || { echo 'evidence exists' >&2; exit 1; }
mkdir -m 700 "$evidence"
uid=$(id -u); user=$(id -un)
runtime="/run/user/$uid"
[ -d "$runtime" ] || { echo 'user runtime absent' >&2; exit 1; }
fixture=$(mktemp -d "$runtime/oracle-u3-peer.XXXXXXXX")
chmod 700 "$fixture"
name="oracle-u3-peer-${fixture##*.}"
socket_unit="/run/systemd/system/$name.socket"
service_unit="/run/systemd/system/$name.service"
created=0
cleanup() {
  if [ "$created" = 1 ]; then
    sudo -n systemctl stop "$name.socket" "$name.service" >/dev/null 2>&1 || true
    sudo -n rm -f -- "$socket_unit" "$service_unit"
    sudo -n systemctl daemon-reload >/dev/null
  fi
  rm -rf --one-file-system -- "$fixture"
}
trap cleanup EXIT
cat > "$fixture/server.py" <<'PY'
import os, socket
assert int(os.environ['LISTEN_PID']) == os.getpid() and os.environ['LISTEN_FDS'] == '1'
s = socket.socket(fileno=3)
c, _ = s.accept()
c.sendall(str(os.geteuid()).encode('ascii'))
c.close()
PY
cat > "$fixture/service.unit" <<EOF2
[Unit]
Description=Disposable oracle U3 socket credential fixture
[Service]
User=$user
ExecStart=/usr/bin/python3 $fixture/server.py
EOF2
cat > "$fixture/socket.unit" <<EOF2
[Unit]
Description=Disposable oracle U3 socket credential fixture
[Socket]
ListenStream=$fixture/mini.sock
SocketUser=$user
SocketMode=0600
Service=$name.service
EOF2
sudo -n python3 - "$fixture/socket.unit" "$socket_unit" "$fixture/service.unit" "$service_unit" <<'PY'
import pathlib, sys
# Exclusive create: never overwrite a pre-existing system unit.
made = []
try:
    for source, dest in ((sys.argv[1],sys.argv[2]), (sys.argv[3],sys.argv[4])):
        with open(dest, 'xb') as output:
            made.append(dest)
            output.write(pathlib.Path(source).read_bytes())
except BaseException:
    for dest in made:
        pathlib.Path(dest).unlink(missing_ok=True)
    raise
PY
created=1
sudo -n systemctl daemon-reload
sudo -n systemctl start "$name.socket"
python3 - "$fixture/mini.sock" "$uid" > "$evidence/peer.json" <<'PY'
import json, socket, struct, sys
s = socket.socket(socket.AF_UNIX)
s.settimeout(10)
s.connect(sys.argv[1])
pid, uid, gid = struct.unpack('3i', s.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))
service_uid = int(s.recv(64))
assert uid == 0, (pid, uid, gid)
assert service_uid == int(sys.argv[2]), service_uid
print(json.dumps({'socket_creator_peer_pid':pid, 'socket_creator_peer_uid':uid,
                  'socket_creator_peer_gid':gid, 'activated_service_uid':service_uid}))
PY
printf 'actual-root-socket-operator-service=passed\n' > "$evidence/result.txt"
