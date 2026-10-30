"""Direct authenticated DokuWiki edit and exact raw-page read-back."""

import http.cookiejar
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from html.parser import HTMLParser

base = sys.argv[1].rstrip("/")
headers = {
    "X-Sandstorm-User-Id": "spk-smoke-user",
    "X-Sandstorm-Username": "SPK%20Smoke",
    "X-Sandstorm-Permissions": "admin,manager,user",
    "X-Sandstorm-Tab-Id": "spk-smoke-tab",
}
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


opener = urllib.request.build_opener(
    urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()),
    NoRedirect(),
)


class EditForm(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_form = False
        self.fields = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "form" and attrs.get("id") == "dw__editform":
            self.in_form = True
        elif self.in_form and tag == "input" and attrs.get("type") == "hidden":
            self.fields.append((attrs.get("name", ""), attrs.get("value", "")))

    def handle_endtag(self, tag):
        if tag == "form" and self.in_form:
            self.in_form = False


def request(path, data=None):
    req = urllib.request.Request(
        base + path,
        data=None if data is None else urllib.parse.urlencode(data).encode(),
        headers=headers,
    )
    try:
        response = opener.open(req, timeout=30)
    except urllib.error.HTTPError as error:
        if error.code not in (301, 302, 303, 307, 308):
            raise
        response = error
    with response:
        return response.status, response.read().decode()


for attempt in range(90):
    try:
        status, edit = request("/doku.php?id=featured&do=edit")
        form = EditForm()
        form.feed(edit)
        assert status == 200 and form.fields
        assert any(name == "sectok" and value for name, value in form.fields)
        break
    except Exception:
        if attempt == 89:
            raise
        time.sleep(1)

expected = "====== Featured ======\nwritten by the direct package smoke\n"
fields = form.fields + [
    ("wikitext", expected),
    ("summary", "direct package smoke"),
    ("do[save]", "Save"),
]
status, _ = request("/doku.php?id=featured", fields)
assert status in (200, 302, 303)
status, raw = request("/doku.php?id=featured&do=export_raw")
assert status == 200
assert raw.strip() == expected.strip(), (raw, expected)
print(json.dumps({"edit": "authenticated", "readback": "exact", "version": "2026-07-14c"}))
