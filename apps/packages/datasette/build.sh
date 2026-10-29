#!/bin/bash
set -euo pipefail

BASE=/var/lib/spk-fresh/apps/datasette
RECIPE="$BASE/recipe"
PACKAGE_DIR="$BASE/package"
ROOTFS="$PACKAGE_DIR/rootfs"
OUT="$BASE/out"
LOGS="$BASE/logs"
SPK=/var/lib/spk-fresh/tools/spk
PIP_WHEEL="$BASE/downloads/bootstrap/pip-26.2.2-py3-none-any.whl"
WHEELHOUSE="$BASE/downloads/wheelhouse"
SOURCES="$BASE/downloads/sources"
SMOKE_PID_FILE="$LOGS/smoke.pid"
SMOKE_PORT=18765

if [[ "$(uname -m)" != x86_64 ]]; then
    echo "The locked wheels require Linux x86_64" >&2
    exit 1
fi
python3 -I -c 'import sys; assert sys.version_info[:2] == (3, 13), sys.version'
test -x "$SPK"
test -f "$BASE/datasette.keyring"
test "$(stat -c %a "$BASE/datasette.keyring")" = 600
test -f "$RECIPE/requirements.lock"
grep -q '^    apiPath = "/",$' "$RECIPE/sandstorm-pkgdef.capnp"
mkdir -p "$BASE/downloads/bootstrap" "$WHEELHOUSE" "$SOURCES" "$OUT" "$LOGS"

fetch() {
    local url=$1 destination=$2 digest=$3
    if [[ ! -f "$destination" ]]; then
        curl -fsSL "$url" -o "$destination"
    fi
    printf '%s  %s\n' "$digest" "$destination" | sha256sum -c -
}

fetch \
    https://files.pythonhosted.org/packages/3f/06/3e4420302363fbb71be3c7f35ce042f54bfca330e3e66b3a2e3c4cca579f/pip-26.2.2-py3-none-any.whl \
    "$PIP_WHEEL" \
    fd7f4dfa8190e014013b9f08f3e973f4e4c26ffd179a204895533a7254813a70
fetch \
    https://files.pythonhosted.org/packages/98/4a/75224122c9cc725b6dcc9466fff8a720c99a2d7b67ce866a82c52a5f2141/datasette-0.65.5.tar.gz \
    "$SOURCES/datasette-0.65.5.tar.gz" \
    8d16ab1bf9a2753089cd3cb079045885d440f11267973e89e08e7fecf555264a
fetch \
    https://files.pythonhosted.org/packages/a7/2b/e9563e1273c58f3ea4313f7531aaecedfd8ae368459767e432adc45e17b3/datasette-sandstorm-support-0.2.tar.gz \
    "$SOURCES/datasette-sandstorm-support-0.2.tar.gz" \
    9f54c9ddc5e2a8fcc330e536a6a197ee60a029b1c38e1f5af80e077950a838ce

# Populate a fresh wheelhouse without resolving dependencies or unpinned versions.
cd "$BASE"
PYTHONPATH="$PIP_WHEEL" python3 -m pip --isolated download \
    --no-deps --only-binary=:all: --require-hashes \
    --dest "$WHEELHOUSE" -r "$RECIPE/requirements.lock"

rm -rf "$PACKAGE_DIR"
mkdir -p "$ROOTFS/opt/app"
cp "$RECIPE/sandstorm-pkgdef.capnp" "$RECIPE/sandstorm-files.list" \
    "$RECIPE/datasette.svg" "$RECIPE/version" "$RECIPE/description.md" \
    "$RECIPE/changelog.md" "$PACKAGE_DIR/"
cp "$RECIPE/launcher.py" "$RECIPE/metadata.yml" "$ROOTFS/opt/app/"

python3 -m venv --without-pip "$ROOTFS/opt/app/venv"
PYTHONPATH="$PIP_WHEEL" "$ROOTFS/opt/app/venv/bin/python" -m pip --isolated install \
    --no-index --no-deps --only-binary=:all: --require-hashes \
    --find-links "$WHEELHOUSE" -r "$RECIPE/requirements.lock"

"$ROOTFS/opt/app/venv/bin/python" -I -c '
import importlib.metadata as m
assert m.version("datasette") == "0.65.5"
assert m.version("datasette-sandstorm-support") == "0.2"
for name in ("datasette-upload-dbs", "datasette-insert", "datasette-write"):
    try:
        m.version(name)
    except m.PackageNotFoundError:
        pass
    else:
        raise AssertionError(f"legacy write plugin installed: {name}")
'
python3 -I "$RECIPE/stage_runtime.py" "$ROOTFS"

# Run the staged root itself, with a real SQLite database, before signing it.
mkdir -p "$ROOTFS/var/databases" "$ROOTFS/var/tmpfs"
python3 -I -c '
import sqlite3, sys
connection = sqlite3.connect(sys.argv[1])
connection.execute("create table records (id integer primary key, value text not null)")
connection.execute("insert into records values (1, ?)", ("read-only",))
connection.commit()
connection.close()
' "$ROOTFS/var/databases/smoke.db"

cleanup_smoke() {
    if [[ -f "$SMOKE_PID_FILE" ]]; then
        local pid
        pid=$(<"$SMOKE_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            wait "$pid" 2>/dev/null || true
        fi
        rm -f "$SMOKE_PID_FILE"
    fi
}
trap cleanup_smoke EXIT
python3 -I -c 'import socket, sys; s = socket.socket(); s.bind(("127.0.0.1", int(sys.argv[1]))); s.close()' "$SMOKE_PORT"
DATASETTE_PORT="$SMOKE_PORT" nohup chroot "$ROOTFS" \
    /opt/app/venv/bin/python -I /opt/app/launcher.py \
    > "$LOGS/smoke.log" 2>&1 &
echo "$!" > "$SMOKE_PID_FILE"

curl -fsS --retry 30 --retry-connrefused --retry-delay 1 \
    "http://127.0.0.1:$SMOKE_PORT/-/versions.json" -o "$OUT/versions.json"
curl -fsS "http://127.0.0.1:$SMOKE_PORT/-/databases.json" -o "$OUT/databases.json"
curl -fsS "http://127.0.0.1:$SMOKE_PORT/smoke.json?sql=select%20id,value%20from%20records&_shape=objects&_size=1000" \
    -o "$OUT/query.json"
curl -fsS "http://127.0.0.1:$SMOKE_PORT/smoke.json?sql=select%20id,value%20from%20records&_shape=array&_size=1000" \
    -o "$OUT/query-array.json"
python3 -I -c '
import json, sys
versions, databases, query, query_array = [json.load(open(path)) for path in sys.argv[1:]]
assert versions["datasette"]["version"] == "0.65.5", versions
assert isinstance(databases, list) and any(row.get("name") == "smoke" for row in databases), databases
assert isinstance(query, dict) and query["ok"] is True, query
assert query["rows"] == [{"id": 1, "value": "read-only"}], query
assert query_array == [{"id": 1, "value": "read-only"}], query_array
print("JSON smoke checks passed: versions, databases, objects envelope, array rows")
' "$OUT/versions.json" "$OUT/databases.json" "$OUT/query.json" "$OUT/query-array.json"
cleanup_smoke
trap - EXIT
rm -rf "$ROOTFS/var"

cd "$PACKAGE_DIR"
rm -f "$OUT/datasette.spk"
"$SPK" pack -k"$BASE/datasette.keyring" "$OUT/datasette.spk"
"$SPK" verify --details "$OUT/datasette.spk" | tee "$OUT/verify.txt"
sha256sum "$OUT/datasette.spk" | tee "$OUT/datasette.spk.sha256"
date -u +%Y-%m-%dT%H:%M:%SZ > "$OUT/build-date-utc"
