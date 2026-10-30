"""Direct MediaWiki API smoke: authenticated create and exact read-back."""

import http.cookiejar
import json
import sys
import time
import urllib.parse
import urllib.request

base = sys.argv[1].rstrip("/")
headers = {
    "X-Sandstorm-User-Id": "spk-smoke-user",
    "X-Sandstorm-Username": "SPK%20Smoke",
    "X-Sandstorm-Permissions": "sysop",
    "X-Sandstorm-Tab-Id": "spk-smoke-tab",
}
cookies = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cookies))


def call(**params):
    params["format"] = "json"
    params["formatversion"] = "2"
    data = None
    method = "GET"
    if params.pop("http_post", False):
        data = urllib.parse.urlencode(params).encode()
        method = "POST"
        url = base + "/api.php"
    else:
        url = base + "/api.php?" + urllib.parse.urlencode(params)
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    with opener.open(request, timeout=30) as response:
        assert response.status == 200
        return json.load(response)


for attempt in range(90):
    try:
        identity = call(action="query", meta="userinfo")
        break
    except Exception:
        if attempt == 89:
            raise
        time.sleep(1)
assert identity["query"]["userinfo"]["id"] > 0, identity
assert identity["query"]["userinfo"]["name"].startswith("SPK Smoke"), identity

token = call(action="query", meta="tokens", type="csrf")["query"]["tokens"]["csrftoken"]
assert token and token != "+\\", "anonymous CSRF token"
title = "SPK smoke 1.46.2"
expected = "typed wiki initial\nsecond line"
edited = call(
    http_post=True,
    action="edit",
    title=title,
    text=expected,
    summary="direct package smoke",
    token=token,
)
assert edited["edit"]["result"] == "Success", edited
parsed = call(action="parse", page=title, prop="wikitext|revid")
assert parsed["parse"]["wikitext"] == expected, parsed
print(json.dumps({"identity": identity["query"]["userinfo"], "title": title, "readback": "exact"}))
