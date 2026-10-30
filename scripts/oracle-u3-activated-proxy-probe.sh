#!/usr/bin/env bash
# Exercise a disposable root-systemd FD3 listener and the real mini proxy with
# an untrusted bounded fake upstream. This does not establish Mini admission.
set -euo pipefail
[ "$#" -eq 2 ] || { echo 'usage: oracle-u3-activated-proxy-probe.sh MINI NEW_EVIDENCE_DIR' >&2; exit 2; }
mini=$1 evidence=$2
[ -x "$mini" ] && [ ! -e "$evidence" ] || { echo 'binary absent or evidence exists' >&2; exit 1; }
mkdir -m 700 "$evidence"
uid=$(id -u); user=$(id -un)
fixture=$(mktemp -d "/tank/chreatures/oracle-u3-proxy.XXXXXXXX")
chmod 711 "$fixture"
mkdir -m 700 "$fixture/private"
mkdir -m 711 "$fixture/controller"
name="oracle-u3-proxy-${fixture##*.}"
printf "%s\n" "$name" > "$evidence/unit.txt"
socket_unit="/run/systemd/system/$name.socket"
service_unit="/run/systemd/system/$name.service"
created=0; backend_pid=
cleanup() {
  if [ "$created" = 1 ]; then
    sudo -n systemctl stop "$name.socket" "$name.service" >/dev/null 2>&1 || true
    sudo -n rm -f -- "$socket_unit" "$service_unit"
    sudo -n systemctl daemon-reload >/dev/null
  fi
  if [ -n "$backend_pid" ]; then kill "$backend_pid" 2>/dev/null || true; wait "$backend_pid" 2>/dev/null || true; fi
  rm -rf --one-file-system -- "$fixture"
}
trap cleanup EXIT
printf '{}' > "$fixture/private/config.json"
printf '{}' > "$fixture/private/operator.config"
printf operator-v1 > "$fixture/private/operator.mode"
chmod 600 "$fixture/private/"{config.json,operator.config,operator.mode}
cat > "$fixture/backend.py" <<'PY'
import os, socket, struct, sys
path, report = sys.argv[1:]
s = socket.socket(socket.AF_UNIX); s.bind(path); os.chmod(path, 0o600); s.listen(8)
with open(report, 'w', buffering=1) as log:
    while True:
        c, _ = s.accept(); c.settimeout(30)
        try:
            header = c.recv(4)
            if not header: continue # proxy's initial upstream health connect
            if len(header) != 4: raise RuntimeError('partial header')
            count = struct.unpack('<I', header)[0]
            if not 1 <= count <= 65536: raise RuntimeError('frame bound')
            body = bytearray()
            while len(body) < count:
                data = c.recv(count - len(body))
                if not data: raise RuntimeError('partial body')
                body.extend(data)
            operation = body[-2] # fixture sends one-byte payload after opcode
            log.write(f'{operation}\n')
            reply = bytes([operation, 9]); c.sendall(struct.pack('<I', len(reply)) + reply)
        finally: c.close()
PY
python3 "$fixture/backend.py" "$fixture/private/operator.sock" "$evidence/backend.log" >"$evidence/backend.stderr" 2>&1 &
backend_pid=$!
for n in $(seq 1 100); do [ -S "$fixture/private/operator.sock" ] && break; kill -0 "$backend_pid" || exit 1; sleep .1; done
[ -S "$fixture/private/operator.sock" ] || { echo 'fake backend did not bind' >&2; exit 1; }
cat > "$fixture/service.unit" <<EOF2
[Unit]
Description=Disposable oracle U3 activated mini proxy fixture
[Service]
User=$user
MemoryMax=256M
RuntimeMaxSec=120
TasksMax=64
NoNewPrivileges=yes
ExecStart=$mini serve-agent-operator-proxy --socket $fixture/controller/mini.sock --upstream $fixture/private/operator.sock --config $fixture/private/config.json --controller-uid 100000
EOF2
cat > "$fixture/socket.unit" <<EOF2
[Unit]
Description=Disposable oracle U3 activated mini proxy fixture
[Socket]
ListenStream=$fixture/controller/mini.sock
SocketMode=0666
Service=$name.service
EOF2
sudo -n python3 - "$fixture/socket.unit" "$socket_unit" "$fixture/service.unit" "$service_unit" <<'PY'
import pathlib, sys
made = []
try:
    for source, dest in ((sys.argv[1],sys.argv[2]), (sys.argv[3],sys.argv[4])):
        with open(dest, 'xb') as output:
            made.append(dest); output.write(pathlib.Path(source).read_bytes())
except BaseException:
    for dest in made: pathlib.Path(dest).unlink(missing_ok=True)
    raise
PY
created=1
sudo -n systemctl daemon-reload
if ! sudo -n systemctl start "$name.socket" >"$evidence/socket-start.log" 2>&1; then
  sudo -n systemctl status "$name.socket" --no-pager --full >>"$evidence/socket-start.log" 2>&1 || true
  exit 1
fi
cat > "$fixture/client.py" <<'PY'
import json, socket, struct, sys
path, role = sys.argv[1:]
def exchange(op, payload):
    s=socket.socket(socket.AF_UNIX); s.settimeout(30); s.connect(path)
    peer=struct.unpack('3i',s.getsockopt(socket.SOL_SOCKET,socket.SO_PEERCRED,12))
    assert peer[1] == 0, peer
    config=b'{}'; frame=b'\x02'+struct.pack('<I',len(config))+config+b'\xab'*32+bytes([op])+payload
    s.sendall(struct.pack('<I',len(frame))+frame)
    def read(n):
        b=bytearray()
        while len(b)<n:
            part=s.recv(n-len(b))
            if not part: raise RuntimeError('early EOF')
            b.extend(part)
        return bytes(b)
    response=read(struct.unpack('<I',read(4))[0]); s.close(); return response
if role == 'controller':
    assert exchange(80,b'\x01') == bytes([80,9])
    assert exchange(155,b'\x01')[0] == 254
    assert exchange(81,b'\x01')[0] == 254
    print(json.dumps({'controller_allowed_80':True,'blocked_155':True,'blocked_bad_81':True,'socket_peer_uid':0}))
else:
    assert exchange(80,b'\x01')[0] == 254
    print(json.dumps({'other_uid_refused':True,'socket_peer_uid':0}))
PY
chmod 644 "$fixture/client.py"
sudo -n setpriv --reuid=100000 --regid=100000 --clear-groups /usr/bin/python3 "$fixture/client.py" "$fixture/controller/mini.sock" controller > "$evidence/controller.json"
python3 "$fixture/client.py" "$fixture/controller/mini.sock" other > "$evidence/other.json"
sleep .2
[ "$(cat "$evidence/backend.log")" = 80 ] || { echo 'unexpected requests reached fake upstream' >&2; exit 1; }
sudo -n systemctl show "$name.service" -p MainPID -p User > "$evidence/service.txt"
sha256sum "$mini" > "$evidence/mini.sha256"
printf 'actual-activated-mini-proxy=passed\n' > "$evidence/result.txt"
