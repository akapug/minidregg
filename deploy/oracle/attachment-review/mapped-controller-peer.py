#!/usr/bin/env python3
"""Initial-namespace peers for the disposable mapped-controller audit."""
import json
import os
import socket
import struct
import subprocess
import sys
import time

role, world = sys.argv[1:]
if role == "controller":
    try:
        os.setuid(1000)
    except PermissionError:
        pass
    else:
        raise AssertionError("controller switched to operator")
if role in ("reverse", "foreign-reverse"):
    path = world + ("/controller/reverse/custody.sock" if role == "reverse" else "/foreign/reverse.sock")
    sock = socket.socket(socket.AF_UNIX)
    sock.bind(path)
    os.chmod(path, 0o600)
    if role == "reverse":
        subprocess.run(["setfacl", "-m", "u:1000:rw", path], check=True)
    sock.listen(1)
    with open(world + ("/controller/reverse/reverse-ready" if role == "reverse" else "/foreign/reverse-ready"), "w") as marker:
        marker.write("ready")
    sock.settimeout(30)
    conn, _ = sock.accept()
    with conn:
        def read_exact(n):
            chunks = bytearray()
            while len(chunks) < n:
                data = conn.recv(n - len(chunks))
                if not data:
                    raise EOFError("short frame")
                chunks.extend(data)
            return bytes(chunks)
        length = struct.unpack(">I", read_exact(4))[0]
        assert json.loads(read_exact(length)) == {"probe": True}
        result = b'{"ok":true}'
        conn.sendall(struct.pack(">I", len(result)) + result)
    print("reverse-controller-responded")
elif role in ("controller", "foreign"):
    path = world + "/agent/forward.sock"
    deadline = time.monotonic() + 25
    while role == "controller" and not os.path.exists(world + "/agent/ready"):
        if time.monotonic() >= deadline:
            raise TimeoutError("forward listener not ready")
        time.sleep(0.02)
    sock = socket.socket(socket.AF_UNIX)
    try:
        sock.connect(path)
    except PermissionError:
        if role != "foreign":
            raise
        print("foreign-forward-acl-refused")
    else:
        if role == "foreign":
            raise AssertionError("foreign peer connected through ACL")
        print("controller-forward-connected")
        sock.close()
else:
    raise ValueError(role)
