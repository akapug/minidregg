#!/usr/bin/env python3
"""b6-hb.py ROUTE_DIR: the Hummingbird write, a tracking beacon read back over the dashboard's socket.io.

Hummingbird (mnutt/hummingbird as packaged: /opt/app/sandstorm.js, lib/tracker.js, lib/dashboard.js,
lib/metrics/*.js) has no HTTP read of its data. GET /tracking_pixel* (permission `tracker`) answers the
GIF and calls Metric.insert; every metric then emits its running count on its interval (view_totals
every 50 ms) through io.volatile.emit to socket.io clients that hold `view-data`. So: connect socket.io
on the owner route, send the beacon over the same route, and wait for a view_totals event of at least 1.
Prints one JSON line; exit 0 only when the beacon was accepted (200) and the count event arrived.
"""
import http.client, importlib.util, json, os, socket, sys, time

route = sys.argv[1]
spec = importlib.util.spec_from_file_location("rtsio", os.path.join(os.path.dirname(os.path.abspath(__file__)), "rt-sio.py"))
rt = importlib.util.module_from_spec(spec); spec.loader.exec_module(rt)


class Unix(http.client.HTTPConnection):
    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(60)
        self.sock.connect(os.path.join(route, "http.sock"))


def beacon():
    sess = open(os.path.join(route, "browser.token")).read().strip()
    c = Unix("grain.test")
    c.request("GET", "/tracking_pixel.gif?featured=resident&url=https%3A%2F%2Fgrain.test%2Ffeatured",
              headers={"Host": "grain.test", "Origin": "https://grain.test", "Cookie": f"__Host-mini_spk_session={sess}"})
    r = c.getresponse(); r.read()
    return r.status


try:
    s = rt.SIO(route, "")
except Exception as e:  # noqa: BLE001
    print(json.dumps({"ok": False, "refused": f"socket.io {e}"})); sys.exit(1)
status = beacon()
if status != 200:
    print(json.dumps({"ok": False, "refused": f"beacon {status}"})); sys.exit(1)
seen = []
end = time.time() + 30
for ev in s.events(30):
    seen.append(ev[0])
    if ev[0] == "view_totals" and isinstance(ev[1], (int, float)) and ev[1] >= 1:
        print(json.dumps({"ok": True, "beacon": status, "event": ev[0], "count": ev[1]})); sys.exit(0)
    if time.time() > end:
        break
print(json.dumps({"ok": False, "refused": "beacon accepted but no view_totals >= 1", "events": sorted(set(map(str, seen)))[:8]}))
sys.exit(1)
