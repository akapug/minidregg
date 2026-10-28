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


def login(send, wait, route, mid="0"):
    """send(msg_dict); wait(pred, seconds) -> message or None. Returns (result_message_or_None, post_status)."""
    token = "login-%d" % int(time.time() * 1000)
    send({"msg": "method", "method": "loginWithSandstorm", "id": mid, "params": [token]})
    time.sleep(0.5)
    posted = post_login_token(route, token)
    return wait(lambda m: m.get("msg") == "result" and m.get("id") == mid, 30), posted
