#!/usr/bin/env python3
"""rt-sio.py MODE ROUTE_DIR ARG: realtime writes for the rt batch, over a grain's owner route.

ROUTE_DIR holds http.sock and browser.token (the custodian-minted participant session).
  wbo      ROUTE_DIR BOARD     a Rectangle item as a socket.io `broadcast` on WBO's /socket.io/
  hedgedoc ROUTE_DIR NOTE_ID   a text insert as a socket.io `operation` (OT, base revision from `doc`)
  wekan    ROUTE_DIR TITLE     DDP over /websocket: sandstorm login, then board, list and card inserts
Prints one JSON line; exit 0 only when the server acknowledged the write. The read-back is the
caller's (HTTP GET) except for wekan, which reads the card back from its own subscription.
"""
import base64, importlib.util, json, os, socket, struct, sys, time

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
    time.sleep(3)  # the server applies broadcasts in order; GET /boards/<board>.json is the read-back
    print(json.dumps({"ok": True, "id": item["id"]}))
    return 0


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


def wekan(route, title):
    ws = WS(route, "/websocket")
    n = [0]

    def call(method, params, seconds=60):
        n[0] += 1; mid = str(n[0])
        ws.send(json.dumps({"msg": "method", "method": method, "id": mid, "params": params}))
        end = time.time() + seconds
        while time.time() < end:
            m = json.loads(ws.recv())
            if m.get("msg") == "ping":
                ws.send(json.dumps({"msg": "pong"}))
            elif m.get("msg") == "result" and m.get("id") == mid:
                return m
        return None

    ws.send(json.dumps({"msg": "connect", "version": "1", "support": ["1", "pre2", "pre1"]}))
    while json.loads(ws.recv()).get("msg") != "connected":
        pass
    # Wekan 12.65 logs in as TextEditor does (wekan-accounts-sandstorm): loginWithSandstorm plus the
    # POST /.sandstorm-login rendezvous, one shared path (sandstorm-login.py). The old {sandstorm: true}
    # `login` method has no handler in this version ("Unrecognized options for login request").
    here = os.path.dirname(os.path.abspath(__file__))
    spec = importlib.util.spec_from_file_location("sandstormlogin", os.path.join(here, "sandstorm-login.py"))
    sl = importlib.util.module_from_spec(spec); spec.loader.exec_module(sl)

    def send(msg):
        ws.send(json.dumps(msg))

    def wait(pred, seconds):
        end = time.time() + seconds
        while time.time() < end:
            m = json.loads(ws.recv())
            if m.get("msg") == "ping":
                ws.send(json.dumps({"msg": "pong"}))
            elif pred(m):
                return m
        return None

    login, posted = sl.login(send, wait, route)
    if not login or "error" in login:
        print(json.dumps({"ok": False, "refused": "loginRefused", "result": login, "post": posted[:100]})); return 1
    uid = login["result"]["userId"]
    now = {"$date": int(time.time() * 1000)}
    rid = lambda: os.urandom(8).hex()  # noqa: E731
    board, lst, swim, card = rid(), rid(), rid(), rid()
    steps = [
        ("/boards/insert", {"_id": board, "title": "featured board", "permission": "private", "color": "belize",
                            "members": [{"userId": uid, "isAdmin": True, "isActive": True}], "createdAt": now}),
        ("/swimlanes/insert", {"_id": swim, "title": "Default", "boardId": board, "sort": 0, "createdAt": now}),
        ("/lists/insert", {"_id": lst, "title": "To do", "boardId": board, "sort": 0, "createdAt": now}),
        ("/cards/insert", {"_id": card, "title": title, "listId": lst, "boardId": board, "swimlaneId": swim,
                           "sort": 0, "userId": uid, "createdAt": now}),
    ]
    for method, doc in steps:
        r = call(method, [doc])
        if not r or "error" in r:
            print(json.dumps({"ok": False, "refused": method, "result": r})); return 1
    ws.send(json.dumps({"msg": "sub", "id": "b", "name": "board", "params": [board, False]}))
    end = time.time() + 60
    while time.time() < end:
        m = json.loads(ws.recv())
        if m.get("msg") == "ping":
            ws.send(json.dumps({"msg": "pong"}))
        elif m.get("msg") == "added" and m.get("collection") == "cards" and m.get("fields", {}).get("title") == title:
            print(json.dumps({"ok": True, "board": board, "card": m.get("id")})); return 0
    print(json.dumps({"ok": False, "refused": "cardNotReadBack", "board": board})); return 1


if __name__ == "__main__":
    mode, route, arg = sys.argv[1:4]
    try:
        sys.exit({"wbo": wbo, "hedgedoc": hedgedoc, "wekan": wekan}[mode](route, arg))
    except Exception as e:  # noqa: BLE001
        print(json.dumps({"ok": False, "refused": str(e)[:300]})); sys.exit(1)
