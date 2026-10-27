#!/usr/bin/env python3
"""J5's hostile-client leg: a stranger (a key the Host never enrolled) who does NOT go through
the official client's local consent gate, and so is refused (or not) by the Host alone.

  journey-stranger.py MINI HOST CONFIG SOCKET KEY OUTDIR LABEL=KIND:PATH...

KIND is `intent` (an intent JSON, authored by the Host's pure codec) or `binary` (a retained
intent.bin). Each is signed with KEY (a 32-byte ed25519 seed, as `mini keygen` writes it) and sent
to the Host as an op 4 observation challenge over the socket: the first thing any read or write
needs. One TSV line per input on stdout: `LABEL<TAB>refused<TAB>OP REASON<TAB>TEXT` when the Host
answers with a proven refusal (NO_RECORD, 253: decided before any append), else `LABEL<TAB>NOT-REFUSED<TAB>reply op N`. Exit 0 always;
the journey counts."""
import hashlib, os, socket, struct, subprocess, sys
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

mini, host_bin, config, sock_path, keyfile, outdir = sys.argv[1:7]
seed = open(keyfile, "rb").read()
key = Ed25519PrivateKey.from_private_bytes(seed)
config_bytes = open(config, "rb").read()
HOST_PIN = hashlib.sha256(open(host_bin, "rb").read()).digest()  # envelope v2: the Host image pin (v1 is refused)
TAG = b"DREGG/NATIVE-HOST/OUTCOME/v6"

def frame_of(s):
    def exact(n):
        b = b""
        while len(b) < n:
            c = s.recv(n - len(b))
            if not c: raise EOFError("host closed the connection")
            b += c
        return b
    return exact(struct.unpack("<I", exact(4))[0])

def ask_host(request):
    s = socket.socket(socket.AF_UNIX); s.settimeout(300); s.connect(sock_path)
    body = bytes([2]) + struct.pack("<I", len(config_bytes)) + config_bytes + HOST_PIN + request
    s.sendall(struct.pack("<I", len(body)) + body)
    try: return frame_of(s)
    finally: s.close()

for spec in sys.argv[7:]:
    label, rest = spec.split("=", 1); kind, path = rest.split(":", 1)
    if kind == "intent":
        out = os.path.join(outdir, label + ".intent.bin")
        p = subprocess.run([mini, "author", "--socket", sock_path, "--host", host_bin,
                            "--config", config, "--kind", "intent", "--input", path, "--output", out],
                           capture_output=True, timeout=600)
        if p.returncode != 0:
            print(f"{label}\tNOT-REFUSED\tauthor failed: {p.stderr.decode('utf-8','replace').strip()[-200:]}"); continue
        intent = open(out, "rb").read()
    else:
        intent = open(path, "rb").read()
    reply = ask_host(bytes([4]) + struct.pack("<I", len(intent)) + intent + key.sign(intent))
    open(os.path.join(outdir, label + ".reply"), "wb").write(reply)
    if reply[0] == 253 and reply[1:].startswith(TAG):  # 255 is undecided, never a refusal (L1)
        text = "".join(chr(b) if 32 <= b < 127 else " " for b in reply[1 + len(TAG):])
        text = " ".join(text.split())
        print(f"{label}\trefused\t{text}")
    else:
        print(f"{label}\tNOT-REFUSED\treply op {reply[0]}")
