#!/usr/bin/env python3
"""Compare the projection of native/mini-sdk/golden/lean-intents.json (and its coverage of
intents.json) with the hand-written scripts/pipeline/intent-vector-authority.txt. Exit 1 on any
difference, naming it. The authority is never written by a generator."""
import json, sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
golden = root / "native/mini-sdk/golden"
auth = (root / "scripts/pipeline/intent-vector-authority.txt").read_text().splitlines()
fx = json.loads((golden / "lean-intents.json").read_text())
inputs = json.loads((golden / "intents.json").read_text())
rows = {r["name"]: r for r in fx["vectors"]}
bad = []

frames = {}
ok, refuse, same, distinct = set(), {}, [], []
for line in auth:
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    if line.startswith(("frame =", "idFrame =")):
        k, v = line.split(" = ", 1); frames[k] = v
    elif line.startswith("ok "):
        ok.add(line[3:].strip())
    elif line.startswith("refuse "):
        n, phrase = line[7:].split("|", 1); refuse[n.strip()] = phrase.strip()
    elif line.startswith("same "):
        same.append(line.split()[1:])
    elif line.startswith("distinct "):
        distinct.append(line.split()[1:])
    else:
        bad.append(f"unreadable authority line: {line}")

if fx.get("frame") != frames["frame"]: bad.append(f"frame {fx.get('frame')!r} != {frames['frame']!r}")
if fx.get("idFrame") != frames["idFrame"]: bad.append(f"idFrame {fx.get('idFrame')!r} != {frames['idFrame']!r}")
named = ok | set(refuse)
if named != set(rows): bad.append(f"rows differ: only in fixture {sorted(set(rows)-named)}, only in authority {sorted(named-set(rows))}")
if [i["name"] for i in inputs] != [r["name"] for r in fx["vectors"]]: bad.append("lean-intents.json does not cover intents.json in order")
f, idf = frames["frame"].encode().hex(), frames["idFrame"].encode().hex()
for n in sorted(ok & set(rows)):
    r = rows[n]
    if r["result"] != "ok": bad.append(f"{n}: authority says admitted, fixture says {r['result']}"); continue
    if not r["bytes"].startswith(f): bad.append(f"{n}: bytes do not begin with the intent frame")
    if r["idPreimage"] != idf + r["bytes"]: bad.append(f"{n}: idPreimage is not idFrame || bytes")
for n, phrase in refuse.items():
    r = rows.get(n)
    if r is None: continue
    if r["result"] != "refused": bad.append(f"{n}: authority says refused, fixture says {r['result']}")
    elif phrase not in r["reason"]: bad.append(f"{n}: reason {r['reason']!r} lacks {phrase!r}")
for g in same:
    if len({rows[n]["bytes"] for n in g}) != 1: bad.append(f"same {g}: bytes differ")
for g in distinct:
    if len({rows[n]["bytes"] for n in g}) != len(g): bad.append(f"distinct {g}: two rows share bytes")

if bad:
    print("intent-vector-authority: RED"); [print("  " + b) for b in bad]; sys.exit(1)
print(f"intent-vector-authority: OK ({len(ok)} admitted, {len(refuse)} refused, {len(same)} same-groups, {len(distinct)} distinct-groups)")
