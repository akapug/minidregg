#!/usr/bin/env python3
"""jupyter-exec.py ROUTE_DIR KERNEL_ID CODE: run one code cell on a Jupyter 4.2 kernel.

Jupyter's REST API has no execute call: a kernel is started over REST (POST /api/kernels) and a cell runs
as an execute_request on its websocket, /api/kernels/<id>/channels (notebook 4.2 JSON message framing, one
JSON object per text frame). Reuses the WS client of rt-sio.py. Prints one JSON line
{"ok": true, "stdout": "..."} once the kernel reports idle for the request; exit 0 only on ok.
"""
import importlib.util, json, os, sys, time, uuid

here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("rtsio", os.path.join(here, "rt-sio.py"))
rt = importlib.util.module_from_spec(spec); spec.loader.exec_module(rt)


def main():
    route, kid, code = sys.argv[1:4]
    ws = rt.WS(route, "/api/kernels/%s/channels" % kid)
    msg_id, session = uuid.uuid4().hex, uuid.uuid4().hex
    ws.send(json.dumps({
        "header": {"msg_id": msg_id, "username": "resident", "session": session,
                   "msg_type": "execute_request", "version": "5.0"},
        "parent_header": {}, "metadata": {}, "channel": "shell",
        "content": {"code": code, "silent": False, "store_history": True,
                    "user_expressions": {}, "allow_stdin": False, "stop_on_error": True}}))
    out, err, deadline = "", None, time.time() + 150
    while time.time() < deadline:
        m = json.loads(ws.recv())
        if m.get("parent_header", {}).get("msg_id") != msg_id:
            continue
        t, c = m.get("msg_type") or m["header"]["msg_type"], m.get("content", {})
        if t == "stream":
            out += c.get("text", "")
        elif t == "error":
            err = "%s: %s" % (c.get("ename"), c.get("evalue"))
        elif t == "status" and c.get("execution_state") == "idle":
            break
    else:
        print(json.dumps({"ok": False, "error": "no idle status within 150 s"})); sys.exit(1)
    print(json.dumps({"ok": err is None, "stdout": out, **({"error": err} if err else {})}))
    sys.exit(0 if err is None else 1)


main()
