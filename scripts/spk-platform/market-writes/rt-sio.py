#!/usr/bin/env python3
"""Legacy shared WebSocket helpers for callers not yet migrated to native declarations.

No WBO app operation lives here. Whiteboard operations belong to their declarations
and the generic native conversation engine.
"""
import base64, json, os, socket, struct, sys, time

COOKIE = "__Host-mini_spk_session"


class WS:
    def __init__(self, route, path):
        token = open(os.path.join(route, "browser.token")).read().strip()
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(120)
        s.connect(os.path.join(route, "http.sock"))
        key = base64.b64encode(os.urandom(16)).decode()
        s.sendall((f"GET {path} HTTP/1.1\r\nHost: grain.test\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                   f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\nOrigin: https://grain.test\r\n"
                   f"Cookie: {COOKIE}={token}\r\n\r\n").encode())
        head = b""
        while b"\r\n\r\n" not in head:
            c = s.recv(4096)
            if not c:
                raise RuntimeError("handshakeClosed " + head[:200].decode("latin1"))
            head += c
        if b" 101 " not in head.split(b"\r\n", 1)[0] + b" ":
            raise RuntimeError("noUpgrade " + head.split(b"\r\n", 1)[0].decode("latin1"))
        self.s, self.buf = s, head.split(b"\r\n\r\n", 1)[1]

    def send(self, text):
        data = text.encode(); n = len(data); mask = os.urandom(4)
        h = bytes([0x81]) + (bytes([0x80 | n]) if n < 126 else bytes([0x80 | 126]) + struct.pack(">H", n))
        self.s.sendall(h + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))

    def _need(self, n):
        while len(self.buf) < n:
            c = self.s.recv(65536)
            if not c:
                raise EOFError("websocket closed")
            self.buf += c

    def recv(self):
        while True:
            self._need(2)
            op, n = self.buf[0] & 0x0F, self.buf[1] & 0x7F; off = 2
            if n == 126:
                self._need(4); n = struct.unpack(">H", self.buf[2:4])[0]; off = 4
            elif n == 127:
                self._need(10); n = struct.unpack(">Q", self.buf[2:10])[0]; off = 10
            self._need(off + n)
            payload, self.buf = self.buf[off:off + n], self.buf[off + n:]
            if op == 0x9:
                self.s.sendall(bytes([0x8A, 0x80]) + os.urandom(4)); continue
            if op == 0x8:
                code = struct.unpack(">H", payload[:2])[0] if len(payload) >= 2 else None
                raise EOFError("close frame code=%s reason=%r" % (code, payload[2:80]))
            if op == 0x1:
                return payload.decode()


class SIO:
    """socket.io over the websocket transport; engine.io 3 first, then 4."""
    def __init__(self, route, path_q):
        err = None
        for eio in (3, 4):
            try:
                self.ws = WS(route, f"/socket.io/?{path_q}&EIO={eio}&transport=websocket")
                first = self.ws.recv()
                if first[:1] != "0":
                    raise RuntimeError("noOpen " + first[:80])
                self.eio = eio
                if eio == 4:
                    self.ws.send("40")
                return
            except Exception as e:  # noqa: BLE001
                err = e
        raise RuntimeError(f"socket.io handshake refused: {err}")

    def emit(self, *args):
        self.ws.send("42" + json.dumps(list(args)))

    def events(self, seconds):
        end = time.time() + seconds
        while time.time() < end:
            self.ws.s.settimeout(max(1, end - time.time()))
            try:
                t = self.ws.recv()
            except socket.timeout:
                return
            if t == "2":
                self.ws.send("3"); continue
            if t[:2] == "42":
                yield json.loads(t[2:])
            elif t[:2] == "44":
                yield ["connect_error", t[2:]]
