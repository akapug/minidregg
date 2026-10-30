import json, sys, time, urllib.request
base = sys.argv[1]
H = {"X-Sandstorm-User-Id": "smokeowner1", "X-Sandstorm-Permissions": "manage"}
def get(path, headers=H):
    return json.load(urllib.request.urlopen(urllib.request.Request(base + path, headers=headers), timeout=30))
Q = "v=1.16.1&c=smoke&f=json"
for _ in range(30):
    try:
        ok = get("/rest/ping?" + Q)["subsonic-response"]["status"] == "ok"
        if ok: break
    except Exception:
        time.sleep(1)
else:
    raise SystemExit("never came up")
made = get("/rest/createPlaylist?" + Q + "&name=smoke-list")["subsonic-response"]
assert made["status"] == "ok", made
names = [p["name"] for p in get("/rest/getPlaylists?" + Q)["subsonic-response"]["playlists"]["playlist"]]
assert "smoke-list" in names, names
other = {"X-Sandstorm-User-Id": "smokeguest2"}
assert get("/rest/ping?" + Q, other)["subsonic-response"]["status"] == "ok"
try:
    urllib.request.urlopen(urllib.request.Request(base + "/rest/ping?" + Q), timeout=10); raise SystemExit("anonymous was admitted")
except urllib.error.HTTPError as e:
    assert e.code == 401
print(json.dumps({"status": "PASS", "playlists": names}))
