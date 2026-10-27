#!/usr/bin/env python3
"""A minimal RFC 6455 client for jweb-frontend.sh: open the terminal WebSocket with the session
cookie and our Origin, type `whoami`, and exit 0 when the member's subject appears in the pty
output within ten seconds. Stdlib only (the box and the journey have no websocket package).

usage: jweb-frontend-ws.py HOST PORT PATH ORIGIN COOKIE SUBJECT
"""
import base64
import os
import socket
import struct
import sys
import time

host, port, path, origin, cookie, subject = sys.argv[1:7]
key = base64.b64encode(os.urandom(16)).decode()
s = socket.create_connection((host, int(port)), timeout=10)
s.sendall(
    (
        f"GET {path} HTTP/1.1\r\nHost: {host}:{port}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\nOrigin: {origin}\r\nCookie: {cookie}\r\n\r\n"
    ).encode()
)
head = b""
while b"\r\n\r\n" not in head:
    chunk = s.recv(4096)
    if not chunk:
        print("connection closed during the handshake", file=sys.stderr)
        sys.exit(2)
    head += chunk
status_line, _, rest = head.partition(b"\r\n\r\n")
if not status_line.startswith(b"HTTP/1.1 101"):
    print("handshake refused: " + status_line.split(b"\r\n")[0].decode(errors="replace"), file=sys.stderr)
    sys.exit(2)


def frame(opcode, payload):
    mask = os.urandom(4)
    masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
    n = len(payload)
    if n < 126:
        head = bytes([0x80 | opcode, 0x80 | n])
    elif n < 65536:
        head = bytes([0x80 | opcode, 0x80 | 126]) + struct.pack(">H", n)
    else:
        head = bytes([0x80 | opcode, 0x80 | 127]) + struct.pack(">Q", n)
    return head + mask + masked


buf = bytearray(rest)
out = bytearray()
deadline = time.time() + 10
sent = False
s.settimeout(0.5)


def frames():
    """Yield (opcode, payload) for every complete server frame in buf."""
    while True:
        if len(buf) < 2:
            return
        fin_op, l = buf[0], buf[1] & 0x7F
        off = 2
        if l == 126:
            if len(buf) < 4:
                return
            l = struct.unpack(">H", bytes(buf[2:4]))[0]
            off = 4
        elif l == 127:
            if len(buf) < 10:
                return
            l = struct.unpack(">Q", bytes(buf[2:10]))[0]
            off = 10
        if len(buf) < off + l:
            return
        payload = bytes(buf[off : off + l])
        del buf[: off + l]
        yield fin_op & 0x0F, payload


s.sendall(frame(0x1, b'{"resize":[100,30]}'))
while time.time() < deadline:
    try:
        chunk = s.recv(65536)
        if not chunk:
            break
        buf += chunk
    except socket.timeout:
        pass
    for op, payload in frames():
        if op == 0x2 or op == 0x1:
            out += payload
        elif op == 0x9:
            s.sendall(frame(0xA, payload))
        elif op == 0x8:
            deadline = 0
    text = out.decode(errors="replace")
    if not sent and "mini>" in text:
        s.sendall(frame(0x2, b"whoami\r"))
        sent = True
    if sent and subject in text and text.count("mini>") >= 2:
        s.sendall(frame(0x2, b"exit\r"))
        time.sleep(0.2)
        s.sendall(frame(0x8, struct.pack(">H", 1000)))
        print(text[-600:])
        sys.exit(0)
print(out.decode(errors="replace")[-600:])
print("subject %s not seen in the terminal output (sent whoami: %s)" % (subject, sent), file=sys.stderr)
sys.exit(1)
