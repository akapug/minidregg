import json, sys, urllib.request
base = sys.argv[1]
def call(method, path, body=None):
    req = urllib.request.Request(base + path, method=method, data=None if body is None else json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json", "X-Sandstorm-User-Id": "smoke"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)
g = call("POST", "/api/new-game", {"difficulty": "easy"})
assert g["success"], g
back = call("GET", "/api/game/%d" % g["game_id"])
assert json.dumps(back).find("board") >= 0 or back.get("success"), back
print(json.dumps({"status": "PASS", "game_id": g["game_id"]}))
