#!/usr/bin/env python3
"""rt-sio.py MODE ROUTE_DIR ARG: realtime writes for the rt batch, over a grain's owner route.

ROUTE_DIR holds http.sock and browser.token (the custodian-minted participant session).
  wbo      ROUTE_DIR BOARD     a Rectangle item as a socket.io `broadcast` on WBO's /socket.io/
  hedgedoc ROUTE_DIR NOTE_ID   a text insert as a socket.io `operation` (OT, base revision from `doc`)
Prints one JSON line; exit 0 only when the server acknowledged the write. The read-back is the
caller's (HTTP GET) for both modes.
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


def wbo(route, board):
    s = SIO(route, "")
    s.emit("getboard", board)
    item = {"tool": "Rectangle", "type": "rect", "id": "featured" + os.urandom(4).hex(),
            "color": "#123456", "size": 4, "x": 10, "y": 10, "x2": 120, "y2": 90}
    s.emit("broadcast", {"board": board, "data": item})
    time.sleep(3)  # the server applies broadcasts in order
    # Read-back by WBO's own protocol: a second socket joins the board with getboard and the server answers
    # one `broadcast` event whose _children are the board's items (sockets.js onGetBoard).
    r = SIO(route, "")
    r.emit("getboard", board)
    seen = 0
    for ev in r.events(60):
        if ev[0] == "broadcast" and isinstance(ev[1], dict) and "_children" in ev[1]:
            kids = ev[1]["_children"]
            seen = len(kids)
            if any(k.get("id") == item["id"] for k in kids):
                print(json.dumps({"ok": True, "id": item["id"], "items": seen, "readback": "getboard"}))
                return 0
            break
    print(json.dumps({"ok": False, "refused": "itemNotInGetboard", "id": item["id"], "items": seen}))
    return 1


def hedgedoc(route, note):
    s = SIO(route, f"noteId={note}")
    doc = None
    for ev in s.events(60):
        if ev[0] == "doc":
            doc = ev[1]; break
    if doc is None:
        print(json.dumps({"ok": False, "refused": "noDocEvent"})); return 1
    text = "# featured\nwritten by a resident over socket.io\n"
    ops = [text] + ([len(doc.get("str", ""))] if doc.get("str") else [])
    s.emit("operation", doc.get("revision", 0), ops, None)
    for ev in s.events(30):
        if ev[0] == "ack":
            print(json.dumps({"ok": True, "revision": doc.get("revision", 0)})); return 0
    print(json.dumps({"ok": False, "refused": "noAck"})); return 1


if __name__ == "__main__":
    mode, route, arg = sys.argv[1:4]
    try:
        sys.exit({"wbo": wbo, "hedgedoc": hedgedoc}[mode](route, arg))
    except Exception as e:  # noqa: BLE001
        print(json.dumps({"ok": False, "refused": str(e)[:300]})); sys.exit(1)
