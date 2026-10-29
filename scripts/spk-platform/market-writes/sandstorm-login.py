#!/usr/bin/env python3
"""sandstorm-login.py: the one Sandstorm login rendezvous for the Meteor apps (TextEditor, Wekan).

The apps' package (kenton:accounts-sandstorm; Wekan's wekan-accounts-sandstorm) refuses every DDP method
with 400 "Client did not complete authentication handshake" until the connection has called
loginWithSandstorm(token) and an HTTP POST /.sandstorm-login (Content-Type
application/x-sandstorm-login-token, body the token) has rendezvoused with it within 10 s. That POST is
what carries the X-Sandstorm-* headers, so it goes through the grain route like any browser request.
Import with importlib (the file name has a dash). `login(send, wait, route)` takes the caller's DDP
transport so ddp-coedit's and rt-sio's connections both use it.
"""
import os, socket, time


def post_login_token(route, token):
    cookie = open(os.path.join(route, "browser.token")).read().strip()
    body = token.encode()
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(60)
    s.connect(os.path.join(route, "http.sock"))
    s.sendall(("POST /.sandstorm-login HTTP/1.1\r\nHost: grain.test\r\nOrigin: https://grain.test\r\n"
               "Cookie: __Host-mini_spk_session=%s\r\nContent-Type: application/x-sandstorm-login-token\r\n"
               "Content-Length: %d\r\nConnection: close\r\n\r\n" % (cookie, len(body))).encode() + body)
    reply = b""
    while True:
        chunk = s.recv(4096)
        if not chunk:
            break
        reply += chunk
    # One line, whole status plus the first 400 bytes of the body (a 500 carries the app's stack trace).
    text = reply.split(b"\r\n", 1)[0].decode("latin1") + " " + reply.split(b"\r\n\r\n", 1)[-1][:400].decode("latin1")
    return " ".join(text.split())


def timed(route, method, path, body=b"", ctype=None, limit=90):
    """One request over the route's socket, timed: 'METHOD path status ttfb=..s total=..s' (ttfb = first
    response byte). The evidence for the grain-route latency question."""
    cookie = open(os.path.join(route, "browser.token")).read().strip()
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(limit)
    s.connect(os.path.join(route, "http.sock"))
    head = ("%s %s HTTP/1.1\r\nHost: grain.test\r\nOrigin: https://grain.test\r\nCookie: __Host-mini_spk_session=%s\r\n"
            % (method, path, cookie))
    if ctype:
        head += "Content-Type: %s\r\n" % ctype
    head += "Content-Length: %d\r\nConnection: close\r\n\r\n" % len(body)
    t0 = time.time()
    s.sendall(head.encode() + body)
    first = None
    reply = b""
    try:
        while True:
            chunk = s.recv(65536)
            if not chunk:
                break
            if first is None:
                first = time.time() - t0
            reply += chunk
    except socket.timeout:
        pass
    total = time.time() - t0
    status = reply.split(b"\r\n", 1)[0].decode("latin1")[:40] or "no-reply"
    return "%s %s %s ttfb=%s total=%.2fs" % (method, path, status, ("%.2fs" % first) if first is not None else "none", total)


def login(send, wait, route, mid="0"):
    """send(msg_dict); wait(pred, seconds) -> message or None. Returns (result_message_or_None, post_note).

    The app waits only 10 s for the POST after the method call, and every request through the route is a
    custodian-checked exchange with its own latency, so the POST goes out at once on a thread and is
    repeated while the app answers 500 "no current login request" (the method not yet registered). The
    note carries the timings so a timeout names which leg was slow."""
    import threading
    token = "login-%d" % int(time.time() * 1000)
    t0 = time.time()
    notes = []

    def poster():
        for attempt in range(1, 6):
            ts = time.time()
            note = post_login_token(route, token)
            notes.append("POST#%d %.1fs@%.1fs %s" % (attempt, time.time() - ts, ts - t0, note[:90]))
            if " 204 " in note.split(" Error")[0] + " " or note.startswith("HTTP/1.1 204"):
                return
            if "no current login request" not in note:
                return
            time.sleep(0.3)

    send({"msg": "method", "method": "loginWithSandstorm", "id": mid, "params": [token]})
    sent = time.time() - t0
    th = threading.Thread(target=poster, daemon=True)
    th.start()
    res = wait(lambda m: m.get("msg") == "result" and m.get("id") == mid, 40)
    th.join(90)
    return res, "method sent %.1fs, result at %.1fs; %s" % (sent, time.time() - t0, " | ".join(notes))
