#!/usr/bin/env python3
"""Write one WBO 2.18 Rectangle and read it from a fresh socket's replay."""
import importlib.util, json, os, sys, time

_here = os.path.dirname(os.path.abspath(__file__))
_candidates = [
    os.path.abspath(os.path.join(_here, "../../../../scripts/spk-platform/market-writes/rt-sio.py")),
    os.path.abspath(os.path.join(_here, "../../src/scripts/spk-platform/market-writes/rt-sio.py")),
]
_rt_path = next((path for path in _candidates if os.path.isfile(path)), None)
if _rt_path is None:
    raise RuntimeError("cannot locate the platform socket.io helper")
_spec = importlib.util.spec_from_file_location("rt_sio", _rt_path)
rt = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(rt)


def initial_replay(socket, seconds=30):
    for event in socket.events(seconds):
        if event[0] == "connect_error":
            raise RuntimeError("socket connect_error " + json.dumps(event[1])[:160])
        if event[0] == "broadcast" and isinstance(event[1], dict) and "_children" in event[1]:
            return event[1]["_children"]
    raise RuntimeError("no initial board replay")


def main(route, board):
    query = "board=" + board + "&baselineSeq=0"
    writer = rt.SIO(route, query)
    initial_replay(writer)
    item = {
        "tool": 3,
        "type": 1,
        "id": "featured" + os.urandom(4).hex(),
        "clientMutationId": "resident" + os.urandom(4).hex(),
        "color": "#123456",
        "size": 10,
        "opacity": 1,
        "x": 10,
        "y": 10,
        "x2": 120,
        "y2": 90,
    }
    writer.emit("broadcast", item)
    acknowledged = False
    for event in writer.events(30):
        if event[0] == "mutation_rejected":
            raise RuntimeError("mutation rejected " + json.dumps(event[1])[:160])
        if event[0] != "broadcast" or not isinstance(event[1], dict):
            continue
        mutation = event[1].get("mutation")
        if isinstance(mutation, dict) and mutation.get("id") == item["id"]:
            acknowledged = True
            break
    if not acknowledged:
        raise RuntimeError("create was not acknowledged")
    time.sleep(3)

    reader = rt.SIO(route, query)
    children = initial_replay(reader, 60)
    if not any(isinstance(child, dict) and child.get("id") == item["id"] for child in children):
        print(json.dumps({"ok": False, "refused": "itemNotInReplay", "id": item["id"], "items": len(children)}))
        return 1
    print(json.dumps({"ok": True, "id": item["id"], "items": len(children), "readback": "freshSocketReplay"}))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1], sys.argv[2]))
    except Exception as error:  # noqa: BLE001
        print(json.dumps({"ok": False, "refused": str(error)[:300]}))
        sys.exit(1)
