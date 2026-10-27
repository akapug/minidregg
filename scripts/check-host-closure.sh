#!/usr/bin/env bash
# check-host-closure.sh — what the deployed Host is built from: measured, and a size ratchet.
#
# The umbrella elaborates every library module; the minidregg-host executable is
# built from the import closure of Host.Main only. A theorem in a module outside
# that closure is about something the Host never runs. This gate computes the
# closure of Host.Main over tracked library modules, prints how many modules of
# each library it reaches against the library's total, and refuses when the
# closure has GROWN past the one number in scripts/gates/host-closure.max.
#
# It was a pinned module list (scripts/gates/host-closure.pin, 841 lines) that
# went red on every ordinary edit and was re-pinned 53 times in October; the
# ratchet keeps what the pin protected (the Host does not silently grow) at the
# cost of one line (docs/COORDINATION-2026-10-27.md §2; the plan's rule 2).
#   scripts/check-host-closure.sh --update "why the ceiling moves"
set -euo pipefail
root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
cd "$root"
python3 - "$@" <<'PY'
import re, subprocess, sys, datetime, os
sys.path.insert(0, "scripts")
from lean_imports import file_imports
MAX = "scripts/gates/host-closure.max"
libs = re.findall(r'^\[\[lean_lib\]\]\s*\nname\s*=\s*"([^"]+)"', open("lakefile.toml").read(), re.M)
files = [f for f in subprocess.check_output(["git", "ls-files", "-z", "--", "*.lean"]).decode().split("\0") if f]
mods = {}
for f in files:
    top = f.split("/")[0].removesuffix(".lean")
    if top in libs:
        mods[f[:-5].replace("/", ".")] = f
def imports(m):
    return file_imports(mods[m])
def closure(roots):
    seen, stack = set(), list(roots)
    while stack:
        m = stack.pop()
        if m.startswith("Minidregg.") and m[len("Minidregg."):] in mods:
            m = m[len("Minidregg."):]
        if m in seen or m not in mods:
            continue
        seen.add(m)
        stack.extend(imports(m))
    return seen
host = closure(["Host.Main"])
exe_roots = re.findall(r'^\[\[lean_exe\]\]\s*\nname\s*=\s*"[^"]+"\s*\nroot\s*=\s*"([^"]+)"',
                       open("lakefile.toml").read(), re.M)
# what the lake-build gate builds: every lean_lib root and every lean_exe root
umbrella = closure(libs + exe_roots)
lib_of = lambda m: m.split(".")[0]
print(f"{'library':10s} {'Host.Main':>10s} {'gate 2':>9s} {'total':>6s}  built-but-not-deployed")
rows = []
for L in libs:
    tot = sum(1 for m in mods if lib_of(m) == L)
    if tot == 0:
        continue
    h = sum(1 for m in host if lib_of(m) == L)
    u = sum(1 for m in umbrella if lib_of(m) == L)
    rows.append(f"{L} {h} {tot}")
    print(f"{L:10s} {h:>10d} {u:>9d} {tot:>6d}  {u - h}")
host_only = sorted(host - umbrella)
print(f"Host.Main reaches {len(host)} of {len(mods)} library modules; gate 2 builds {len(umbrella)}; "
      f"in the Host closure but not built by gate 2: {len(host_only)}")
for m in host_only:
    print(f"  host-only (not built by gate 2): {m}")
HEADER = ("# The CEILING on the Host.Main import closure (module count): a size ratchet, not a module list.\n"
          "# scripts/check-host-closure.sh is red when the closure GROWS past it; a deletion lowers it with\n"
          "#   scripts/check-host-closure.sh --update REASON\n"
          "# and a module the Host must now reach raises it the same way, with the reason on the line.\n")
def read_max():
    for l in open(MAX):
        l = l.strip()
        if l and not l.startswith("#"):
            return int(l.split()[0])
    sys.exit(f"host-closure: no ceiling in {MAX}")
if "--update" in sys.argv:
    i = sys.argv.index("--update")
    reason = sys.argv[i + 1].strip() if i + 1 < len(sys.argv) else ""
    if not reason:
        sys.exit("host-closure: --update needs a reason")
    old = open(MAX).read().splitlines() if os.path.exists(MAX) else []
    log = [l for l in old if l.startswith("# updated ")]
    log.append(f"# updated {datetime.date.today()}: {len(host)} modules: {reason}  [" + ", ".join(rows) + "]")
    with open(MAX, "w") as fh:
        fh.write(HEADER + "\n".join(log) + "\n" + f"{len(host)}\n")
    print(f"host-closure: ceiling set to {len(host)} modules")
    sys.exit(0)
if not os.path.exists(MAX):
    sys.exit(f"host-closure: no ceiling at {MAX}; run with --update REASON")
ceiling = read_max()
if len(host) > ceiling:
    print(f"host-closure: FAIL: Host.Main reaches {len(host)} modules, over the ceiling {ceiling} ({MAX}); a Host "
          f"that must reach more raises it on purpose: scripts/check-host-closure.sh --update REASON")
    sys.exit(1)
print(f"host-closure: OK: {len(host)} modules, ceiling {ceiling}"
      + (" (lower it: scripts/check-host-closure.sh --update REASON)" if len(host) < ceiling else ""))
PY
