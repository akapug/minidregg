#!/usr/bin/env python3
"""scrumblr-sio.py ROUTE_DIR ROOM RT_SIO_PY: one write beneath the HTML for the repackaged
Scrumblr 0.5-1, over the grain's owner browser route.

The 2026-10-23 snapshot serves socket.io 4.8.1 and moved it off /socket.io to /socketio
(server.js: `const options = { path: '/socketio' }`), so rt-sio.py's SIO class (which
hardcodes /socket.io/) cannot reach it; this script reuses only rt-sio's WS upgrade and
speaks engine.io 4 itself: open 0{...}, namespace connect 40 -> 40{sid}, events 42[...],
ping 2 -> pong 3. The dance is the old market row's, against the wire contract server.js
still speaks: joinRoom -> roomAccept, createCard, then a fresh client's initializeMe ->
initCards must list the card (so it went through the inner redis). Prints one JSON line;
exit 0 only when the card was read back.
"""
import importlib.util, json, os, sys, time

_spec = importlib.util.spec_from_file_location("rt_sio", sys.argv[3])
rt = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(rt)


class Sio4:
    """socket.io v5 (engine.io 4) over rt-sio's websocket upgrade, at /socketio."""

    def __init__(self, route):
        self.ws = rt.WS(route, "/socketio/?EIO=4&transport=websocket")
        first = self.ws.recv()
        if first[:1] != "0":
            raise RuntimeError("noOpen " + first[:120])
        self.ws.send("40")  # namespace connect
        ack = self.ws.recv()
        if ack[:2] != "40":
            raise RuntimeError("noNamespaceConnect " + ack[:120])

    def emit(self, *args):
        self.ws.send("42" + json.dumps(list(args)))

    def events(self, seconds):
        end = time.time() + seconds
        while time.time() < end:
            self.ws.s.settimeout(max(1, end - time.time()))
            try:
                t = self.ws.recv()
            except rt.socket.timeout:
                return
            if t == "2":  # engine.io ping
                self.ws.send("3"); continue
            if t[:2] == "42":
                yield json.loads(t[2:])
            elif t[:2] == "44":
                yield ["connect_error", t[2:]]


def main():
    route, room = sys.argv[1], sys.argv[2]
    cid = "card" + str(int.from_bytes(os.urandom(4), "big"))
    text = "sticky from a resident " + cid
    a = Sio4(route)
    a.emit("message", {"action": "joinRoom", "data": room})
    for ev in a.events(30):
        if ev[0] == "message" and ev[1].get("action") == "roomAccept":
            break
    else:
        print(json.dumps({"ok": False, "refused": "noRoomAccept"})); return 1
    a.emit("message", {"action": "createCard", "data": {"id": cid, "text": text,
          "x": 58, "y": 120, "rot": 3, "colour": "yellow"}})
    time.sleep(2)  # the redis write is async; the read-back is a fresh client's initCards
    for attempt in range(1, 6):
        b = Sio4(route)
        b.emit("message", {"action": "joinRoom", "data": room})
        for ev in b.events(10):
            if ev[0] == "message" and ev[1].get("action") == "roomAccept":
                b.emit("message", {"action": "initializeMe", "data": None})
            if ev[0] == "message" and ev[1].get("action") == "initCards":
                cards = ev[1].get("data") or []
                if any(isinstance(c, dict) and c.get("id") == cid and c.get("text") == text for c in cards):
                    print(json.dumps({"ok": True, "id": cid, "attempt": attempt})); return 0
                break
        time.sleep(2)
    print(json.dumps({"ok": False, "refused": "cardNotInInitCards", "id": cid})); return 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:  # noqa: BLE001
        print(json.dumps({"ok": False, "refused": str(e)[:300]})); sys.exit(1)
