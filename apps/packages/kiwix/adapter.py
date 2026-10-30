#!/usr/bin/env python3
"""ZIM upload adapter in front of kiwix-serve, inside a Sandstorm grain.

POST /upload   multipart (contentRange "bytes a-b/total", file *.zim): chunked import into an
               empty library; answers {"files":[{name,type,size,total_size}]} (text/html, the
               jQuery-File-Upload convention of the original Kiwix Sandstorm uploader).
GET  /         the upload page, or a link to the library once imported.
GET  /kiwix/*  kiwix-serve, proxied (redirects are followed here so a client sees the article).
Writes need the "uploader" permission (X-Sandstorm-Permissions)."""
import json, os, re, subprocess, sys, threading, http.client
from email.parser import BytesParser
from email.policy import HTTP
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit

DATA = "/var/data"
CHUNKING = os.path.join(DATA, "chunking")
LIBRARY = os.path.join(DATA, "kiwix.zim")
MAX_CHUNK = 16 * 1024 * 1024
MAX_TOTAL = 100 * 1024 ** 3
KIWIX_PORT = 48081
LOCK = threading.Lock()
SERVER = None


def start_kiwix():
    global SERVER
    if SERVER is None and os.path.exists(LIBRARY):
        # No --address: kiwix-serve would validate it against getifaddrs(), which the grain sandbox
        # refuses (no AF_NETLINK). The grain has no network beyond loopback, so listening on all is safe.
        SERVER = subprocess.Popen(["/opt/app/kiwix-serve", "--port", str(KIWIX_PORT),
                                   "--urlRootLocation", "/kiwix", LIBRARY], stdout=sys.stderr, stderr=sys.stderr)


PAGE = """<!doctype html><meta charset=utf-8><title>Kiwix</title>
<h1>Kiwix</h1>%s"""
UPLOAD = """<p>Choose a .zim file to import (one library per grain).</p>
<input type=file id=f accept=.zim><button id=b>Upload</button> <progress id=p value=0 max=1></progress> <span id=m></span>
<script>
b.onclick=async()=>{const file=f.files[0];if(!file)return;const N=1<<20;let off=0;
while(off<file.size||off==0){const end=Math.min(off+N,file.size);const fd=new FormData();
fd.append('contentRange','bytes '+off+'-'+(end-1)+'/'+file.size);fd.append('file',file.slice(off,end),file.name);
const r=await fetch('upload',{method:'POST',body:fd});if(!r.ok){m.textContent=await r.text();return}
off=end;p.value=off/file.size;if(end>=file.size)break}location.reload()}
</script>"""


class H(BaseHTTPRequestHandler):
    server_version = "kiwix-adapter"
    protocol_version = "HTTP/1.1"

    def send_body(self, code, body, ctype="text/html; charset=utf-8", extra=()):
        if isinstance(body, str):
            body = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        for k, v in extra:
            self.send_header(k, v)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def can_upload(self):
        return "uploader" in self.headers.get("X-Sandstorm-Permissions", "").split(",")

    def do_HEAD(self):
        self.do_GET()

    def do_GET(self):
        path = urlsplit(self.path).path
        if path == "/":
            if os.path.exists(LIBRARY):
                return self.send_body(200, PAGE % '<p><a href="kiwix/">Open the library</a></p>')
            return self.send_body(200, PAGE % (UPLOAD if self.can_upload() else "<p>No library yet.</p>"))
        if path == "/kiwix" or path.startswith("/kiwix/"):
            return self.proxy()
        self.send_body(404, "not found", "text/plain")

    def proxy(self):
        if not os.path.exists(LIBRARY):
            return self.send_body(404, "no library imported", "text/plain")
        start_kiwix()
        target = re.sub(r"^/kiwix/([A-Za-z-])/", r"/kiwix/content/kiwix/\1/", self.path)
        # The library file is kiwix.zim, so kiwix-serve names its book "kiwix"; old-style
        # /kiwix/A/<article> paths (namespace first) are served from that book.
        for _ in range(4):
            conn = http.client.HTTPConnection("127.0.0.1", KIWIX_PORT, timeout=30)
            try:
                conn.request("GET", target)
                r = conn.getresponse()
            except OSError:
                return self.send_body(503, "kiwix-serve starting", "text/plain", [("Retry-After", "1")])
            if r.status in (301, 302, 307) and r.getheader("Location", "").startswith("/kiwix"):
                r.read()
                target = r.getheader("Location")
                conn.close()
                continue
            data = r.read()
            conn.close()
            headers = [(k, v) for k, v in r.getheaders()
                       if k.lower() in ("etag", "cache-control", "location")]
            return self.send_body(r.status, data, r.getheader("Content-Type", "application/octet-stream"), headers)
        self.send_body(502, "redirect loop", "text/plain")

    def fail(self, code, result, message):
        result["error"] = message
        return self.send_body(code, json.dumps({"files": [result]}))

    def do_POST(self):
        if urlsplit(self.path).path != "/upload":
            return self.send_body(404, "not found", "text/plain")
        if not self.can_upload():
            return self.send_body(403, "forbidden", "text/plain")
        n = int(self.headers.get("Content-Length", "0"))
        if n <= 0 or n > MAX_CHUNK:
            return self.send_body(413, json.dumps({"files": [{"error": "chunk too large"}]}))
        raw = self.rfile.read(n)
        msg = BytesParser(policy=HTTP).parsebytes(
            b"Content-Type: " + self.headers["Content-Type"].encode() + b"\r\n\r\n" + raw)
        fields, upload = {}, None
        for part in msg.iter_parts():
            name = part.get_param("name", header="content-disposition")
            if part.get_filename() is not None:
                upload = (os.path.basename(part.get_filename()), part.get_content_type(), part.get_payload(decode=True))
            else:
                fields[name] = part.get_payload(decode=True).decode()
        if upload is None:
            return self.send_body(400, json.dumps({"files": [{"error": "no file"}]}))
        filename, mime, data = upload
        m = re.fullmatch(r"bytes (\d+)-(\d+)/(\d+)", fields.get("contentRange", ""))
        frm, to, total = (int(x) for x in m.groups()) if m else (0, len(data) - 1, len(data))
        result = {"name": filename, "type": mime, "size": 0, "total_size": total}
        with LOCK:
            os.makedirs(CHUNKING, exist_ok=True)
            part_path = os.path.join(CHUNKING, re.sub(r"[^A-Za-z0-9._-]", "_", filename))
            if os.path.exists(LIBRARY):
                return self.fail(409, result, "File already uploaded")
            if not filename.endswith(".zim"):
                return self.fail(400, result, "File type not allowed")
            if total > MAX_TOTAL:
                return self.fail(400, result, "File too big")
            if frm == 0 and os.path.exists(part_path):
                os.remove(part_path)
            have = os.path.getsize(part_path) if os.path.exists(part_path) else 0
            if frm != have:
                if os.path.exists(part_path):
                    os.remove(part_path)
                return self.fail(400, result, "Chunks out of order")
            try:
                with open(part_path, "ab") as out:
                    out.write(data)
            except OSError as e:
                return self.fail(409, result, "File error: %s" % e)
            result["size"] = os.path.getsize(part_path)
            if to + 1 >= total:
                os.rename(part_path, LIBRARY)
                start_kiwix()
        self.send_body(200, json.dumps({"files": [result]}))

    def log_message(self, fmt, *args):
        sys.stderr.write("%s\n" % (fmt % args))


if __name__ == "__main__":
    os.makedirs(CHUNKING, exist_ok=True)
    for stale in os.listdir(CHUNKING):
        os.remove(os.path.join(CHUNKING, stale))
    start_kiwix()
    ThreadingHTTPServer(("0.0.0.0", 8000), H).serve_forever()
