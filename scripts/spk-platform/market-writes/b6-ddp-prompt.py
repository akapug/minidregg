#!/usr/bin/env python3
"""b6-ddp-prompt.py ROUTE_DIR TEXT: SandForms (Meteor 1.2.1) over its DDP WebSocket: call the
server method Prompts.create(TEXT, false), then subscribe to the public `prompts` publication
and require the new prompt to arrive as an `added` message. Prints `1 <detail>` or `0 <reason>`.
Framing is ddp-coedit.py's (the sibling of the market-writes directory, or the frozen tree's)."""
import importlib.util, os, sys

here = os.path.dirname(os.path.abspath(__file__))
for cand in (os.path.join(here, "..", "ddp-coedit.py"), "/build/lanes/app-market-frozen/src/scripts/spk-platform/ddp-coedit.py"):
    if os.path.exists(cand):
        spec = importlib.util.spec_from_file_location("ddpcoedit", cand)
        mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
        break
else:
    print("0 ddp-coedit.py not found"); sys.exit(0)

route, text = sys.argv[1], sys.argv[2]
try:
    c = mod.connect(route)
    c.ddp()
    c.send({"msg": "method", "method": "Prompts.create", "id": "1", "params": [text, False]})
    r = c.until(lambda m: m.get("msg") == "result" and m.get("id") == "1", 120)
    if not r or "error" in r:
        print("0 Prompts.create refused: %s" % (r,)); sys.exit(0)
    c.send({"msg": "sub", "id": "p", "name": "prompts", "params": []})
    seen = c.until(lambda m: m.get("msg") == "added" and m.get("collection") == "prompts"
                   and m.get("fields", {}).get("text") == text, 120)
    print("1 DDP method Prompts.create -> %s; sub prompts added text=%r" % (r.get("result"), text) if seen
          else "0 prompt not published back after Prompts.create")
except SystemExit as e:
    print("0 ddp refused: %s" % e)
except Exception as e:
    print("0 ddp error: %r" % (e,))
