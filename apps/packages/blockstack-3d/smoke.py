import json, sys, urllib.request
base = sys.argv[1]
H = {"Content-Type": "application/json", "X-Sandstorm-User-Id": "smoke", "X-Sandstorm-Preferred-Handle": "smoke"}
def call(method, path, body=None):
    req = urllib.request.Request(base + path, method=method, data=None if body is None else json.dumps(body).encode(), headers=H)
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.read().decode()
call("POST", "/api.php", {"bestScore": 77})
got = json.loads(call("GET", "/api.php?action=getbestscore&key=bestScore"))
assert int(got["value"]) >= 77, got
print(json.dumps({"status": "PASS", "bestScore": got["value"]}))
