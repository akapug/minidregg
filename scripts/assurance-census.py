#!/usr/bin/env python3
"""assurance-census.py — per-module census of Assurance/ against the Host.Main and Deployed closures.

On demand (plan C2, docs/DEMO-PREFIX-2026-10-26.md); not a gate. Run from anywhere in the repo:
    scripts/assurance-census.py > /tmp/assurance.tsv      # TSV on stdout, summary on stderr
Closures are computed exactly as scripts/check-host-closure.sh does (git ls-files, lean_imports).
Theorem count is an approximation: lines starting with `theorem` or `lemma` (after modifiers
such as `private`/`protected`/attributes on the same line). Poles: case-insensitive word counts of
satisfiab*, teeth, inhabit* anywhere in the file (comments included; the convention is prose + names).
Class: DEPLOYED (in the Deployed.lean closure); DEPLOYED-SUBJECT (not, but every non-Assurance
module reached through Assurance-only imports is in the Host closure); RESEARCH (otherwise).
"""
import re, subprocess, sys, os
here = os.path.dirname(os.path.abspath(__file__))
root = subprocess.check_output(["git", "-C", here, "rev-parse", "--show-toplevel"]).decode().strip()
os.chdir(root); sys.path.insert(0, here)
from lean_imports import file_imports
libs = re.findall(r'^\[\[lean_lib\]\]\s*\nname\s*=\s*"([^"]+)"', open("lakefile.toml").read(), re.M)
files = [f for f in subprocess.check_output(["git", "ls-files", "-z", "--", "*.lean"]).decode().split("\0") if f]
mods = {f[:-5].replace("/", "."): f for f in files if f.split("/")[0].removesuffix(".lean") in libs}
def norm(m):
    return m[len("Minidregg."):] if m.startswith("Minidregg.") and m[len("Minidregg."):] in mods else m
def closure(roots):
    seen, st = set(), list(roots)
    while st:
        m = norm(st.pop())
        if m in seen or m not in mods: continue
        seen.add(m); st.extend(file_imports(mods[m]))
    return seen
host = closure(["Host.Main"]); dep = closure(["Deployed"])
lib = lambda m: m.split(".")[0]
THM = re.compile(r'^\s*(?:@\[[^\]]*\]\s*)?(?:(?:private|protected|nonrec)\s+)*(?:theorem|lemma)\s', re.M)
POLE = {k: re.compile(p, re.I) for k, p in
        {"sat": r"satisfiab", "teeth": r"teeth", "inh": r"inhabit"}.items()}
def subject(m):
    """non-Assurance modules reached from m, traversing only Assurance modules."""
    seen, out, st = set(), set(), [m]
    while st:
        x = st.pop()
        for i in file_imports(mods[x]):
            i = norm(i)
            if i not in mods: continue
            if lib(i) == "Assurance":
                if i not in seen: seen.add(i); st.append(i)
            else: out.add(i)
    return out
rows = []
for m in sorted(x for x in mods if lib(x) == "Assurance" and x != "Assurance"):
    txt = open(mods[m], encoding="utf-8").read()
    s = subject(m)
    kern = sorted(x for x in s if x in host)
    res = sorted(x for x in s if x not in host)
    cls = "DEPLOYED" if m in dep else ("DEPLOYED-SUBJECT" if not res else "RESEARCH")
    why = [x for x in res if lib(x) == "Selvage" or (lib(x) == "Theory")]
    rows.append(dict(m=m, host="y" if m in host else "n", dep="y" if m in dep else "n", cls=cls,
        thm=len(THM.findall(txt)), lines=txt.count("\n"),
        sat=len(POLE["sat"].findall(txt)), teeth=len(POLE["teeth"].findall(txt)), inh=len(POLE["inh"].findall(txt)),
        nd=len(kern), nr=len(res), res=res, sel=sum(1 for x in res if lib(x) == "Selvage"),
        th=sum(1 for x in res if lib(x) == "Theory"), ok=sum(1 for x in res if lib(x) not in ("Selvage", "Theory"))))
print("module\thost\tdeployed\tclass\ttheorems\tlines\tsat\tteeth\tinhab\tdeployed_subject_n\tresearch_subject_n\tselvage_n\ttheory_unreached_n\tother_unreached_n\tresearch_examples")
for r in rows:
    print("\t".join(map(str, [r["m"], r["host"], r["dep"], r["cls"], r["thm"], r["lines"], r["sat"], r["teeth"], r["inh"],
        r["nd"], r["nr"], r["sel"], r["th"], r["ok"], ",".join(r["res"][:3])])))
e = sys.stderr.write
e(f"Host.Main closure: {len(host)} modules; Deployed closure: {len(dep)}\n")
try:
    ceil = [l for l in open("scripts/gates/host-closure.max") if l.strip() and not l.startswith("#")][0].split()[0]
    e(f"host-closure.max ceiling: {ceil} ({'AGREE' if int(ceil) == len(host) else 'DIFFER'})\n")
except OSError: pass
for c in ("DEPLOYED", "DEPLOYED-SUBJECT", "RESEARCH"):
    rs = [r for r in rows if r["cls"] == c]
    e(f"{c:17s} modules {len(rs):4d}  theorems {sum(r['thm'] for r in rs):6d}  lines {sum(r['lines'] for r in rs):6d}  "
      f"files-with sat {sum(1 for r in rs if r['sat']):3d} teeth {sum(1 for r in rs if r['teeth']):3d} inhab {sum(1 for r in rs if r['inh']):3d}\n")
e(f"total Assurance modules {len(rows)}, theorems {sum(r['thm'] for r in rows)}, in Host closure {sum(1 for r in rows if r['host']=='y')}\n")
for L in ("Theory", "Selvage", "Assurance"):
    t = [x for x in mods if lib(x) == L]
    e(f"{L}: reached {sum(1 for x in t if x in host)} unreached {sum(1 for x in t if x not in host)} total {len(t)}\n")
