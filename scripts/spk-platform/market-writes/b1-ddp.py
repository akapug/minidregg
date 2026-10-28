#!/usr/bin/env python3
"""b1-ddp.py ROUTE_DIR: TextEditor's write beneath the HTML over Meteor DDP.

Source: the package's server/server.js (Data = Mongo.Collection "Data", DATA_ID "default_id",
publication "thedocument", Data.allow update for sandstorm permission owner/modify; the client
saves with Data.update(DATA_ID, {$set: {value}})). Framing is ddp-coedit.py's. Writes through one
connection, reads back through a second one's subscription.

The write connection first completes the app's Sandstorm login rendezvous (package
programs/server/packages/kenton_accounts-sandstorm.js): the DDP method loginWithSandstorm(token) blocks
up to 10 s until an HTTP POST /.sandstorm-login with Content-Type application/x-sandstorm-login-token
and the same token as its body arrives; that POST is what carries the X-Sandstorm-* headers, so it goes
through the grain route like any browser request. Without it every method fails with 400 "Client did not
complete authentication handshake" and the Data.allow rule (permission owner or modify) cannot be read. Prints "1 <detail>" or "0 <reason>".
"""
import importlib.util, os, sys, time

here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("ddpcoedit", os.path.join(here, "..", "ddp-coedit.py"))
ddp = importlib.util.module_from_spec(spec); spec.loader.exec_module(ddp)
spec2 = importlib.util.spec_from_file_location("sandstormlogin", os.path.join(here, "sandstorm-login.py"))
sl = importlib.util.module_from_spec(spec2); spec2.loader.exec_module(sl)


def main():
    route = sys.argv[1]
    text = "written by a resident %d" % int(time.time())
    try:
        a = ddp.connect(route); a.ddp()
        logged, posted = sl.login(a.send, a.until, route)
        if not logged or "error" in logged:
            print("0 loginWithSandstorm refused: %s; POST /.sandstorm-login: %s" % (str(logged)[:160], posted[:100])); return
        a.send({"msg": "method", "method": "/Data/update", "id": "1",
                "params": [{"_id": "default_id"}, {"$set": {"value": text}}]})
        res = a.until(lambda m: m.get("msg") == "result" and m.get("id") == "1", 120)
        if not res or "error" in res:
            print("0 /Data/update refused: %s" % str(res)[:200]); return
        b = ddp.connect(route); b.ddp()
        b.send({"msg": "sub", "id": "d", "name": "thedocument", "params": []})
        got = b.until(lambda m: m.get("msg") == "added" and m.get("collection") == "Data", 120)
        if got and got.get("fields", {}).get("value") == text:
            print("1 DDP method /Data/update ok; sub thedocument read back the value")
        else:
            print("0 read-back mismatch: %s" % str(got)[:200])
    except (EOFError, OSError, SystemExit) as e:
        print("0 ddp failed: %s" % str(e)[:200])


main()
