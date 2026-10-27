#!/usr/bin/env python3
"""form-fields.py FORM_ID < page.html: the hidden inputs of one <form id=FORM_ID>, as NAME=VALUE
strings separated by NUL (so a shell loop can feed them to curl --data-urlencode)."""
import sys
from html.parser import HTMLParser


class P(HTMLParser):
    def __init__(self, form_id):
        super().__init__()
        self.form_id, self.inside, self.out = form_id, False, []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "form":
            self.inside = a.get("id") == self.form_id
        elif self.inside and tag == "input" and a.get("type") == "hidden" and a.get("name"):
            self.out.append("%s=%s" % (a["name"], a.get("value") or ""))

    def handle_endtag(self, tag):
        if tag == "form":
            self.inside = False


p = P(sys.argv[1])
p.feed(sys.stdin.buffer.read().decode("utf-8", "replace"))
sys.stdout.write("".join(f + "\0" for f in p.out))
