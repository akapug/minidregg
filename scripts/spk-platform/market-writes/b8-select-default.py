#!/usr/bin/env python3
"""b8-select-default.py NAME < page.html: the value a browser would submit for <select name=NAME>:
the selected <option>, else the first. Prints it (nothing when the select is absent)."""
import sys
from html.parser import HTMLParser


class P(HTMLParser):
    def __init__(self, name):
        super().__init__()
        self.name, self.inside, self.first, self.chosen = name, False, None, None

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "select":
            self.inside = a.get("name") == self.name
        elif self.inside and tag == "option":
            v = a.get("value", "")
            if self.first is None:
                self.first = v
            if "selected" in a and self.chosen is None:
                self.chosen = v

    def handle_endtag(self, tag):
        if tag == "select":
            self.inside = False


p = P(sys.argv[1])
p.feed(sys.stdin.buffer.read().decode("utf-8", "replace"))
v = p.chosen if p.chosen is not None else p.first
if v is not None:
    sys.stdout.write(v)
