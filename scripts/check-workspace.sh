#!/usr/bin/env bash
# check-workspace.sh -- every Cargo package in the tree is a member of the root workspace or an
# explicit `exclude` with its reason, and every member resolves and compiles (local gate `workspace`).
#
#   scripts/check-workspace.sh              membership + lock + per-member compile check
#   scripts/check-workspace.sh --self-test  the membership checker against planted faults only
#
# Why: on 2026-10-08 the root [workspace] arrived and three crates outside it (prover,
# hyperdocument-link-store, bend-ir2-proof) stopped building; their tests silently stopped for 18
# days while byte-only gates stayed green (review 2026-10-26, SYNTHESIS §C.5). ATLAS §6 law 8.
#
# Phase 1, membership (any host). RED when:
#   - a package directory (any tracked or untracked-unignored Cargo.toml outside docs/) is neither
#     in `members` nor in `exclude`;
#   - an `exclude` entry has no reason: the line above it must be a `# ...` comment;
#   - a `members`/`exclude` entry names no package;
#   - a member carries its own [workspace] table or its own Cargo.lock (the root lock is the one
#     lock of every member);
#   - an excluded package has no Cargo.lock of its own (it would build unpinned);
#   - `cargo metadata --locked --offline` refuses (the root lock is stale), or cargo's own
#     workspace_members differ from the parsed `members`.
#   The phase self-tests first: each planted fault above must be refused, or the gate is red.
# Phase 2, compile (Linux only; the deployed crates are Linux-x86-64 code). Each member is
#   `cargo check --all-targets --locked --offline`, one verdict line per member, so a member whose
#   test targets rotted is red by name. On another OS phase 2 cannot run, and the gate says so and
#   is red, unless WORKSPACE_GATE_MEMBERSHIP_ONLY=1, which prints the escape on every run.
set -uo pipefail
root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
cd "$root" || exit 2
export PATH=$HOME/.cargo/bin:$PATH

membership() {  # [--self-test]
python3 - "$@" <<'PY'
import json, os, subprocess, sys, tomllib

def check(root_text, packages, locks, own_workspace, cargo_members):
    """Pure membership rules. packages: set of package dirs (relative); locks: dirs holding a
    Cargo.lock; own_workspace: dirs whose manifest has a [workspace] table; cargo_members: dirs
    cargo reports as workspace members (None = not asked). Returns a list of red lines."""
    red = []
    ws = tomllib.loads(root_text).get("workspace", {})
    members = [m.rstrip("/") for m in ws.get("members", [])]
    exclude = [e.rstrip("/") for e in ws.get("exclude", [])]
    lines = root_text.splitlines()
    for e in exclude:
        at = [i for i, l in enumerate(lines) if l.strip().rstrip(",") in (f'"{e}"', f"'{e}'")]
        if not at or at[0] == 0 or not lines[at[0] - 1].strip().startswith("#") or len(lines[at[0] - 1].strip()) < 8:
            red.append(f"exclude {e}: no reason (the line above the entry must be a '# reason' comment)")
    for d in sorted(set(members) & set(exclude)):
        red.append(f"{d}: both a member and excluded")
    for d in members + exclude:
        if d not in packages:
            red.append(f"{d}: listed in the root workspace but has no Cargo.toml")
    for d in sorted(packages):
        if d not in members and d not in exclude:
            red.append(f"{d}: a package that is neither a workspace member nor an explicit exclude")
    for d in members:
        if d in own_workspace:
            red.append(f"{d}: a member with its own [workspace] table")
        if d in locks:
            red.append(f"{d}: a member with its own Cargo.lock (the root Cargo.lock is the one lock)")
    for d in exclude:
        if d in packages and d not in locks:
            red.append(f"{d}: excluded but has no Cargo.lock of its own (it would build unpinned)")
    if cargo_members is not None and set(cargo_members) != set(members):
        red.append(f"cargo's workspace members {sorted(cargo_members)} differ from the parsed members {sorted(members)}")
    return red

def self_test():
    base = ('[workspace]\nmembers = ["a", "b"]\nexclude = [\n  # research crate, own lock\n  "x",\n]\n')
    ok = dict(root_text=base, packages={"a", "b", "x"}, locks={"x"}, own_workspace={"x"}, cargo_members=["a", "b"])
    assert check(**ok) == [], check(**ok)
    plants = {
        "orphan package": dict(ok, packages={"a", "b", "x", "y"}),
        "exclude without reason": dict(ok, root_text=base.replace("  # research crate, own lock\n", "")),
        "stale member": dict(ok, packages={"a", "x"}),
        "member with [workspace]": dict(ok, own_workspace={"x", "b"}),
        "member with own lock": dict(ok, locks={"x", "a"}),
        "excluded without lock": dict(ok, locks=set()),
        "cargo disagrees": dict(ok, cargo_members=["a"]),
    }
    bad = [name for name, kw in plants.items() if not check(**kw)]
    if bad:
        print(f"workspace: RED: self-test: planted faults NOT refused: {bad}")
        return 1
    print(f"workspace: self-test: {len(plants)} planted faults refused, the clean tree accepted")
    return 0

if self_test():
    sys.exit(1)
if sys.argv[1:] == ["--self-test"]:
    sys.exit(0)

files = subprocess.run(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
                       capture_output=True, check=True).stdout.decode().split("\0")
manifests = [f for f in files if f and os.path.basename(f) == "Cargo.toml" and f != "Cargo.toml"
             and not f.startswith("docs/") and os.path.exists(f)]
packages, own_workspace = set(), set()
for m in manifests:
    t = tomllib.load(open(m, "rb"))
    if "package" in t:
        packages.add(os.path.dirname(m))
    if "workspace" in t:
        own_workspace.add(os.path.dirname(m))
locks = {os.path.dirname(f) for f in files if f and os.path.basename(f) == "Cargo.lock" and f != "Cargo.lock"
         and not f.startswith("docs/") and os.path.exists(f)}
meta = subprocess.run(["cargo", "metadata", "--format-version", "1", "--locked", "--offline"],
                      capture_output=True, text=True)
red = []
cargo_members = None
if meta.returncode != 0:
    why = meta.stderr.strip().splitlines()[-1] if meta.stderr.strip() else "no stderr"
    red.append("cargo metadata --locked --offline refused (stale root Cargo.lock, or an unprimed cache: "
               f"scripts/pipeline/prime-cargo): {why}")
else:
    j = json.loads(meta.stdout)
    rootdir = j["workspace_root"]
    by_id = {p["id"]: p for p in j["packages"]}
    cargo_members = [os.path.relpath(os.path.dirname(by_id[i]["manifest_path"]), rootdir) for i in j["workspace_members"]]
red += check(open("Cargo.toml").read(), packages, locks, own_workspace, cargo_members)
ws = tomllib.load(open("Cargo.toml", "rb"))["workspace"]
for r in red:
    print(f"workspace: RED: {r}")
if not red:
    print(f"workspace: ok: {len(packages)} packages: {len(ws.get('members', []))} members, "
          f"{len(ws.get('exclude', []))} excluded with a reason; root lock current")
for d in ws.get("members", []):
    print(f"MEMBER {d}")
sys.exit(1 if red else 0)
PY
}

if [ "${1:-}" = --self-test ]; then membership --self-test; exit $?; fi

out=$(membership); rc=$?
printf '%s\n' "$out" | grep -v '^MEMBER '
red=$rc
mapfile -t members < <(printf '%s\n' "$out" | sed -n 's/^MEMBER //p')

if [ "$(uname -s)" != Linux ]; then
  if [ "${WORKSPACE_GATE_MEMBERSHIP_ONLY:-0}" = 1 ]; then
    echo "workspace: ESCAPE: WORKSPACE_GATE_MEMBERSHIP_ONLY=1: the per-member compile check did NOT run on $(uname -s)"
  else
    echo "workspace: RED: per-member compile check is Linux-only and this host is $(uname -s) (WORKSPACE_GATE_MEMBERSHIP_ONLY=1 runs membership alone, loudly)"
    red=$((red + 1))
  fi
  exit "$red"
fi

export CARGO_TARGET_DIR=${CARGO_TARGET_DIR:-$root/target-gates}
rust=$(sed -n 's/^channel *= *"\(.*\)"$/\1/p' rust-toolchain.toml)
jobs=${LOCAL_GATES_CARGO_JOBS:-6}
logs=$root/build-logs/workspace; mkdir -p "$logs"
for d in "${members[@]}"; do
  name=$(basename "$d"); log=$logs/$name.log
  if cargo "+$rust" check --all-targets --locked --offline -j "$jobs" --manifest-path "$d/Cargo.toml" >"$log" 2>&1; then
    echo "workspace: ok: $d compiles (all targets)"
  else
    echo "workspace: RED: $d does not compile (all targets): $(grep -m3 '^error' "$log" | tr '\n' ';') ($log)"
    red=$((red + 1))
  fi
done
exit "$red"
