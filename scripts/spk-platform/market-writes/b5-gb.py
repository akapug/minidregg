#!/usr/bin/env python3
"""b5-gb.py ROUTE_DIR: the Groove Basin write, an audio upload that needs a live websocket session.

Groove Basin authorises HTTP by the `token` cookie of a connected websocket client (lib/server.js
createHasPermMiddleware: playerServer.clients[token]), so this opens the websocket on the owner route,
reads the `token` message, subscribes to `library`, then POSTs /upload (multipart, one WAV part) with
that cookie beside the route session, and waits for the track to appear in the `library` subscription.
Read-back is that subscription plus GET /library/<track.file> (the music directory, token cookie too).
Prints one JSON line; exit 0 only when both read-backs hold. The file is a 0.5 s WAV (about 8 KB), far
under the 8 MiB request bound; /stream.mp3 is an endless response and is not exercised.
"""
import http.client, importlib.util, json, math, os, socket, struct, sys, time, urllib.parse

route = sys.argv[1]
spec = importlib.util.spec_from_file_location("rtsio", os.path.join(os.path.dirname(os.path.abspath(__file__)), "rt-sio.py"))
rt = importlib.util.module_from_spec(spec); spec.loader.exec_module(rt)


def wav():
    rate, n = 8000, 4000
    pcm = b"".join(struct.pack("<h", int(8000 * math.sin(2 * math.pi * 440 * i / rate))) for i in range(n))
    def info(k, v):
        v = v.encode() + b"\0"
        return k + struct.pack("<I", len(v)) + v + (b"\0" if len(v) % 2 else b"")
    lst = b"INFO" + info(b"INAM", "Featured Tone") + info(b"IART", "Featured Artist") + info(b"IPRD", "Featured Album") + info(b"ITRK", "1")
    fmt = struct.pack("<HHIIHH", 1, 1, rate, rate * 2, 2, 16)
    body = b"WAVE" + b"fmt " + struct.pack("<I", len(fmt)) + fmt + b"data" + struct.pack("<I", len(pcm)) + pcm + b"LIST" + struct.pack("<I", len(lst)) + lst
    return b"RIFF" + struct.pack("<I", len(body)) + body


class Unix(http.client.HTTPConnection):
    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(300)
        self.sock.connect(os.path.join(route, "http.sock"))


def call(method, path, token, body=None, headers=None):
    c = Unix("grain.test")
    sess = open(os.path.join(route, "browser.token")).read().strip()
    h = {"Host": "grain.test", "Origin": "https://grain.test", "Cookie": f"__Host-mini_spk_session={sess}; token={token}"}
    h.update(headers or {})
    c.request(method, path, body=body, headers=h)
    r = c.getresponse()
    return r.status, r.read()


def msgs(ws, seconds):
    end = time.time() + seconds
    while time.time() < end:
        ws.s.settimeout(max(1, end - time.time()))
        try:
            t = ws.recv()
        except socket.timeout:
            return
        try:
            yield json.loads(t)
        except ValueError:
            pass


def fail(why):
    print(json.dumps({"ok": False, "refused": why})); sys.exit(1)


ws = rt.WS(route, "/")
token = None
for m in msgs(ws, 30):
    if m.get("name") == "token":
        token = m["args"]; break
if not token:
    fail("noTokenMessage")
ws.send(json.dumps({"name": "subscribe", "args": {"name": "library"}}))
data = wav()
b = "----b5gb" + os.urandom(6).hex()
def part(name, value, filename=None, ctype=None):
    disp = f'form-data; name="{name}"' + (f'; filename="{filename}"' if filename else "")
    return (f"--{b}\r\nContent-Disposition: {disp}\r\n" + (f"Content-Type: {ctype}\r\n" if ctype else "") + "\r\n").encode() + value + b"\r\n"
body = part("size", str(len(data)).encode()) + part("files", data, "featured-tone.wav", "audio/wav") + f"--{b}--\r\n".encode()
st, resp = call("POST", "/upload", token, body, {"Content-Type": f"multipart/form-data; boundary={b}"})
if st != 200:
    fail(f"POST /upload {st}: {resp[:120].decode('latin1')}")
track = None
for m in msgs(ws, 90):
    if m.get("name") == "library" and isinstance(m.get("args"), dict):
        for k, t in m["args"].items():
            if isinstance(t, dict) and ("Featured Tone" in json.dumps(t) or "featured-tone" in json.dumps(t)):
                track = t
        if track:
            break
if not track:
    fail("uploadedButNotInLibrarySubscription")
rel = track.get("file")
st2, got = call("GET", "/library/" + "/".join(urllib.parse.quote(p) for p in rel.split("/")), token) if rel else (0, b"")
if st2 != 200 or got != data:
    fail(f"GET /library/{rel} {st2}, {len(got)} bytes against {len(data)}")
print(json.dumps({"ok": True, "file": rel, "name": track.get("name"), "bytes": len(got)}))
