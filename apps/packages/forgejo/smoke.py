"""Direct rootfs smoke gate for the Forgejo SPK; no third-party imports."""
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

BASE = sys.argv[1].rstrip("/")
OUT = Path(sys.argv[2])
IDENTITY = {
    "X-Sandstorm-User-Id": "smoke-owner",
    "X-Sandstorm-Username": "Smoke Owner",
    "X-Sandstorm-Permissions": "modify",
}


def call(method, path, expected, payload=None, identity=True):
    body = None if payload is None else json.dumps(payload).encode()
    headers = dict(IDENTITY if identity else {})
    if body is not None:
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(BASE + path, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            status = response.status
            raw = response.read()
    except urllib.error.HTTPError as error:
        status = error.code
        raw = error.read()
    if status != expected:
        raise AssertionError(f"{method} {path}: expected {expected}, got {status}: {raw[:500]!r}")
    return json.loads(raw) if raw else None


deadline = time.monotonic() + 90
while True:
    try:
        version = call("GET", "/api/v1/version", 200, identity=False)
        break
    except (OSError, urllib.error.URLError):
        if time.monotonic() >= deadline:
            raise
        time.sleep(1)
assert version["version"].startswith("17.0.1"), version

user = call("GET", "/api/v1/user", 200)
assert user["login"] == "smoke-owner", user
repo = call("POST", "/api/v1/user/repos", 201, {
    "name": "forgejo-smoke",
    "description": "rootfs write/read-back",
    "auto_init": True,
    "private": True,
    "readme": "Default",
})
assert repo["name"] == "forgejo-smoke" and repo["owner"]["login"] == user["login"], repo
issue = call("POST", "/api/v1/repos/smoke-owner/forgejo-smoke/issues", 201, {
    "title": "packaged rootfs issue",
    "body": "issue body written beneath the HTML",
})
comment = call("POST", f"/api/v1/repos/smoke-owner/forgejo-smoke/issues/{issue['number']}/comments", 201, {
    "body": "comment body written beneath the HTML",
})
read_issue = call("GET", f"/api/v1/repos/smoke-owner/forgejo-smoke/issues/{issue['number']}", 200)
assert read_issue["title"] == issue["title"] and read_issue["body"] == issue["body"], read_issue
comments = call("GET", f"/api/v1/repos/smoke-owner/forgejo-smoke/issues/{issue['number']}/comments", 200)
assert any(item["id"] == comment["id"] and item["body"] == comment["body"] for item in comments), comments

OUT.write_text(json.dumps({
    "status": "PASS",
    "version": version,
    "user": {"id": user["id"], "login": user["login"]},
    "repository": {"id": repo["id"], "name": repo["name"], "owner": repo["owner"]["login"]},
    "issue": {"id": issue["id"], "number": issue["number"], "title": read_issue["title"], "body": read_issue["body"]},
    "comment": {"id": comment["id"], "body": comment["body"]},
}, indent=2) + "\n")
print("Forgejo rootfs smoke: repository, issue and comment write/read-back PASS")
