#!/usr/bin/env python3
"""Sandstorm front for Navidrome.

Navidrome trusts a reverse-proxy user header but requires the user to exist. This adapter takes the
bridge's X-Sandstorm-User-Id, makes sure a Navidrome user of that name exists (the first visitor, the
grain owner, is created as the admin; later ones as ordinary users with random unused passwords),
and forwards the request with X-Navidrome-User set. Incoming X-Navidrome-User is never trusted.
PUT /music/<relative path> (permission "manage") adds a file to the library and starts a scan."""
import http.client, json, os, secrets, sys, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote, urlsplit

BACKEND = ("127.0.0.1", 48191)
MUSIC = "/var/music"
STATE = "/var/navidrome-adapter.json"
LOCK = threading.Lock()
HOP = {"connection", "keep-alive", "proxy-authenticate", "proxy-authorization", "te", "trailers",
       "transfer-encoding", "upgrade", "host", "content-length"}
MAX_PUT = 512 * 1024 * 1024


def backend(method, path, body=None, headers=None):
    c = http.client.HTTPConnection(*BACKEND, timeout=60)
    c.request(method, path, body=body, headers=headers or {})
    r = c.getresponse()
    data = r.read()
    c.close()
    return r.status, data


def load():
    try:
        return json.load(open(STATE))
    except OSError:
        return {"admin": None, "users": []}


def save(s):
    tmp = STATE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(s, f)
    os.chmod(tmp, 0o600)
    os.rename(tmp, STATE)


def ensure_user(name):
    with LOCK:
        s = load()
        if name in s["users"]:
            return
        pw = secrets.token_hex(24)
        if s["admin"] is None:
            st, data = backend("POST", "/auth/createAdmin", json.dumps({"username": name, "password": pw}),
                               {"Content-Type": "application/json"})
            if st != 200:
                raise RuntimeError("createAdmin %s %s" % (st, data[:200]))
            s["admin"] = {"username": name, "password": pw}
        else:
            a = s["admin"]
            st, data = backend("POST", "/auth/login", json.dumps({"username": a["username"], "password": a["password"]}),
                               {"Content-Type": "application/json"})
            if st != 200:
                raise RuntimeError("admin login %s" % st)
            token = json.loads(data)["token"]
            st, data = backend("POST", "/api/user", json.dumps({"userName": name, "name": name, "password": pw, "isAdmin": False}),
                               {"Content-Type": "application/json", "x-nd-authorization": "Bearer " + token})
            if st not in (200, 201):
                raise RuntimeError("create user %s %s" % (st, data[:200]))
        s["users"].append(name)
        save(s)


class H(BaseHTTPRequestHandler):
    server_version = "navidrome-adapter"

    def text(self, code, msg):
        b = msg.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def user(self):
        u = self.headers.get("X-Sandstorm-User-Id", "")
        return u if u and all(ch.isalnum() for ch in u) else None

    def forward(self):
        user = self.user()
        if user is None:
            return self.text(401, "sign in to Sandstorm to use this music server")
        try:
            ensure_user(user)
        except Exception as e:  # noqa: BLE001
            sys.stderr.write("provision failed: %r\n" % (e,))
            return self.text(503, "music server is starting")
        n = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(n) if n else None
        headers = {k: v for k, v in self.headers.items() if k.lower() not in HOP and k.lower() != "x-navidrome-user"}
        headers["X-Navidrome-User"] = user
        c = http.client.HTTPConnection(*BACKEND, timeout=3600)
        try:
            c.request(self.command, self.path, body=body, headers=headers)
            r = c.getresponse()
        except OSError:
            return self.text(503, "music server is starting")
        self.send_response(r.status)
        for k, v in r.getheaders():
            if k.lower() not in HOP:
                self.send_header(k, v)
        self.send_header("Connection", "close")
        self.end_headers()
        if self.command != "HEAD":
            while True:
                chunk = r.read(65536)
                if not chunk:
                    break
                try:
                    self.wfile.write(chunk)
                except OSError:
                    break
        c.close()

    do_GET = do_HEAD = do_POST = do_DELETE = forward

    def do_PUT(self):
        path = urlsplit(self.path).path
        if path.startswith("/music/"):
            return self.put_music(unquote(path[len("/music/"):]))
        self.forward()

    def put_music(self, rel):
        if "manage" not in self.headers.get("X-Sandstorm-Permissions", "").split(","):
            return self.text(403, "forbidden")
        parts = [p for p in rel.split("/") if p]
        if not parts or any(p in (".", "..") or "\x00" in p for p in parts):
            return self.text(400, "bad path")
        n = int(self.headers.get("Content-Length") or 0)
        if n <= 0 or n > MAX_PUT:
            return self.text(413, "bad size")
        dest = os.path.join(MUSIC, *parts)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        tmp = dest + ".part"
        left = n
        with open(tmp, "wb") as f:
            while left:
                chunk = self.rfile.read(min(left, 1 << 20))
                if not chunk:
                    os.remove(tmp)
                    return self.text(400, "short body")
                f.write(chunk)
                left -= len(chunk)
        os.rename(tmp, dest)
        user = self.user()
        if user:
            try:
                ensure_user(user)
                backend("GET", "/rest/startScan?v=1.16.1&c=adapter&f=json", None, {"X-Navidrome-User": user})
            except Exception as e:  # noqa: BLE001
                sys.stderr.write("scan failed: %r\n" % (e,))
        self.text(201, "stored %s" % "/".join(parts))

    def log_message(self, fmt, *args):
        sys.stderr.write("%s\n" % (fmt % args))


if __name__ == "__main__":
    os.makedirs(MUSIC, exist_ok=True)
    ThreadingHTTPServer(("0.0.0.0", 8000), H).serve_forever()
