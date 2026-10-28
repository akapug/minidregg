#!/usr/bin/env python3
"""b3-sio.py MODE ROUTE_DIR ARG: socket.io writes for the b3 batch, over a grain's owner route.

Reuses rt-sio.py's WS and SIO classes (the websocket upgrade with the route cookie, the engine.io
open, the ping answers); only the per-app event payloads are new.
  etherdraw ROUTE_DIR ROOM      a pencil stroke as draw:progress + draw:end; read back as the
                                project:load a second subscriber gets
  scrumblr  ROUTE_DIR ROOM      a sticky note as a createCard message; read back as initCards
Prints one JSON line; exit 0 only when the stored object was read back.
"""
import importlib.util, json, os, sys, time

_here = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("rt_sio", os.path.join(_here, "rt-sio.py"))
rt = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(rt)


def etherdraw(route, room):
    name = "featured-" + os.urandom(4).hex()
    uid = "resident" + os.urandom(3).hex()
    pt = lambda x, y: ["Point", x, y]  # noqa: E731  (paper.js JSON of a Point)
    stroke = {"tool": "pencil", "name": name, "start": pt(40, 40), "end": pt(160, 90),
              "rgba": {"red": 0.2, "green": 0.4, "blue": 0.8, "opacity": 1},
              "path": [{"top": pt(70, 55), "bottom": pt(70, 57)}, {"top": pt(110, 70), "bottom": pt(110, 72)}]}
    body = json.dumps(stroke)
    a = rt.SIO(route, "")
    a.emit("subscribe", {"room": room})
    time.sleep(2)  # the room's paper project exists once subscribe is handled; load events are drained below
    a.emit("draw:progress", room, uid, body)
    a.emit("draw:end", room, uid, body)
    acked = False
    for ev in a.events(20):
        if ev[0] == "draw:end":
            acked = True; break
        if ev[0] == "project:load:error":
            print(json.dumps({"ok": False, "refused": "project:load:error"})); return 1
    if not acked:
        print(json.dumps({"ok": False, "refused": "noDrawEndEcho"})); return 1
    time.sleep(3)  # db.storeProject runs on draw:end
    b = rt.SIO(route, "")
    b.emit("subscribe", {"room": room})
    for ev in b.events(30):
        if ev[0] == "project:load" and name in json.dumps(ev[1]):
            print(json.dumps({"ok": True, "name": name})); return 0
    print(json.dumps({"ok": False, "refused": "strokeNotInProjectLoad", "name": name})); return 1


def scrumblr(route, room):
    cid = "card" + str(int.from_bytes(os.urandom(4), "big"))
    text = "sticky from a resident " + cid
    a = rt.SIO(route, "")
    a.emit("message", {"action": "joinRoom", "data": room})
    for ev in a.events(30):
        if ev[0] == "message" and ev[1].get("action") == "roomAccept":
            break
    else:
        print(json.dumps({"ok": False, "refused": "noRoomAccept"})); return 1
    a.emit("message", {"action": "createCard", "data": {"id": cid, "text": text, "x": 58, "y": 120, "rot": 3, "colour": "yellow"}})
    time.sleep(2)  # redis write is async; the read-back is a fresh client's initCards
    for attempt in range(1, 6):
        b = rt.SIO(route, "")
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
    mode, route, arg = sys.argv[1:4]
    try:
        sys.exit({"etherdraw": etherdraw, "scrumblr": scrumblr}[mode](route, arg))
    except Exception as e:  # noqa: BLE001
        print(json.dumps({"ok": False, "refused": str(e)[:300]})); sys.exit(1)
