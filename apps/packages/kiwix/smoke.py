import base64, json, sys, time, urllib.request
base, zim = sys.argv[1], sys.argv[2]
data = open(zim, "rb").read()
boundary = "xBOUNDARYx"
def mp(fields, fname, payload):
    out = b""
    for k, v in fields.items():
        out += ("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n" % (boundary, k, v)).encode()
    out += ("--%s\r\nContent-Disposition: form-data; name=\"file\"; filename=\"%s\"\r\nContent-Type: application/octet-stream\r\n\r\n" % (boundary, fname)).encode() + payload + ("\r\n--%s--\r\n" % boundary).encode()
    return out
H = {"X-Sandstorm-Permissions": "uploader", "Content-Type": "multipart/form-data; boundary=" + boundary}
body = mp({"contentRange": "bytes 0-%d/%d" % (len(data) - 1, len(data))}, "library.zim", data)
r = urllib.request.urlopen(urllib.request.Request(base + "/upload", data=body, headers=H), timeout=30)
res = json.load(r)
assert res["files"][0]["size"] == len(data), res
for _ in range(20):
    try:
        page = urllib.request.urlopen(base + "/kiwix/A/Hello", timeout=10).read().decode()
        break
    except Exception:
        time.sleep(1)
assert "Mini native typed library" in page, page[:200]
print(json.dumps({"status": "PASS", "size": res["files"][0]["size"]}))
