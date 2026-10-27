#!/usr/bin/env python3
"""ddp-coedit.py ROUTE_DIR_A ROUTE_DIR_B: two browser sessions co-edit one Meteor grain.

Each ROUTE_DIR is a grain route directory (http.sock and the 0600 browser.token the
custodian minted for that participant). Session B opens the grain's DDP WebSocket
through its own route, subscribes to the first public list's todos; session A, through
its own route, inserts a todo into that list; B must receive it as an `added` message.
This is the tour's "a second browser co-edits" on Simple Todos (the Meteor todos
example: collections lists/todos, publications publicLists and todos(listId), client
inserts allowed). Prints one JSON line; exit 0 only when B saw A's edit.
"""
import base64, json, os, socket, struct, sys, time

COOKIE = "__Host-mini_spk_session"


def connect(route):
    token = open(os.path.join(route, "browser.token")).read().strip()
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(900)
    s.connect(os.path.join(route, "http.sock"))
    key = base64.b64encode(os.urandom(16)).decode()
    s.sendall((
        "GET /websocket HTTP/1.1\r\nHost: grain.test\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\nOrigin: https://grain.test\r\n"
        f"Cookie: {COOKIE}={token}\r\n\r\n").encode())
    head = b""
    while b"\r\n\r\n" not in head:
        chunk = s.recv(4096)
        if not chunk:
            raise SystemExit(json.dumps({"ok": False, "refused": "handshakeClosed", "route": route, "head": head[:300].decode("latin1")}))
        head += chunk
    status = head.split(b"\r\n", 1)[0]
    if b" 101 " not in status + b" ":
        raise SystemExit(json.dumps({"ok": False, "refused": "noUpgrade", "route": route, "status": status.decode("latin1")}))
    return Conn(s, head.split(b"\r\n\r\n", 1)[1])


class Conn:
    def __init__(self, sock, rest):
        self.s, self.buf = sock, rest

    def send(self, value):
        data = json.dumps(value).encode()
        mask = os.urandom(4)
        n = len(data)
        header = bytes([0x81]) + (bytes([0x80 | n]) if n < 126 else bytes([0x80 | 126]) + struct.pack(">H", n))
        self.s.sendall(header + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))

    def _need(self, n):
        while len(self.buf) < n:
            chunk = self.s.recv(65536)
            if not chunk:
                raise EOFError("websocket closed")
            self.buf += chunk

    def recv(self):
        while True:
            self._need(2)
            op, n = self.buf[0] & 0x0F, self.buf[1] & 0x7F
            off = 2
            if n == 126:
                self._need(4); n = struct.unpack(">H", self.buf[2:4])[0]; off = 4
            elif n == 127:
                self._need(10); n = struct.unpack(">Q", self.buf[2:10])[0]; off = 10
            self._need(off + n)
            payload, self.buf = self.buf[off:off + n], self.buf[off + n:]
            if op == 0x9:  # ping
                self.s.sendall(bytes([0x8A, 0x80]) + os.urandom(4))
                continue
            if op == 0x8:
                raise EOFError("websocket close frame")
            if op == 0x1:
                text = payload.decode()
                # Meteor's raw /websocket speaks DDP JSON; a SockJS-framed reply starts with a/o/h.
                if text[:1] == "a":
                    for item in json.loads(text[1:]):
                        return json.loads(item)
                if text[:1] in "oh":
                    continue
                return json.loads(text)

    def ddp(self):
        self.send({"msg": "connect", "version": "1", "support": ["1", "pre2", "pre1"]})
        while True:
            m = self.recv()
            if m.get("msg") == "ping":
                self.send({"msg": "pong"})
            if m.get("msg") == "connected":
                return m["session"]
            if m.get("msg") == "failed":
                raise SystemExit(json.dumps({"ok": False, "refused": "ddpFailed", "detail": m}))

    def until(self, pred, seconds):
        end = time.time() + seconds
        self.s.settimeout(seconds)
        while time.time() < end:
            m = self.recv()
            if m.get("msg") == "ping":
                self.send({"msg": "pong"})
                continue
            if pred(m):
                return m
        return None


def main():
    route_a, route_b = sys.argv[1], sys.argv[2]
    started = time.time()
    b = connect(route_b)
    session_b = b.ddp()
    b.send({"msg": "sub", "id": "lists", "name": "publicLists", "params": []})
    first = b.until(lambda m: m.get("msg") == "added" and m.get("collection") == "lists", 300)
    if not first:
        print(json.dumps({"ok": False, "refused": "noPublicList"})); return 1
    list_id = first["id"]
    b.send({"msg": "sub", "id": "todos", "name": "todos", "params": [list_id]})
    b.until(lambda m: m.get("msg") == "ready" and "todos" in m.get("subs", []), 300)
    a = connect(route_a)
    session_a = a.ddp()
    todo = "coedit" + os.urandom(6).hex()
    text = f"written in browser A at {int(time.time())}"
    a.send({"msg": "method", "method": "/todos/insert", "id": "1",
            "params": [{"_id": todo, "listId": list_id, "text": text, "checked": False,
                        "createdAt": {"$date": int(time.time() * 1000)}}]})
    result = a.until(lambda m: m.get("msg") == "result" and m.get("id") == "1", 300)
    if not result or "error" in result:
        print(json.dumps({"ok": False, "refused": "insertRefused", "result": result})); return 1
    seen = b.until(lambda m: m.get("msg") == "added" and m.get("collection") == "todos" and m.get("id") == todo, 120)
    ok = bool(seen) and seen.get("fields", {}).get("text") == text
    print(json.dumps({"ok": ok, "list": list_id, "todo": todo, "sessionA": session_a, "sessionB": session_b,
                      "seenByB": seen, "seconds": round(time.time() - started, 1)}))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
