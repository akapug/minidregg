#!/usr/bin/env bash
# Generate a real runtime file list, pack, and verify the signed EtherCalc SPK.
set -euo pipefail
BASE="${BASE:-/var/lib/spk-fresh/apps/ethercalc}"
SPK="${SPK:-/var/lib/spk-fresh/tools/spk}"
SRC="$BASE/work/build-src"
OUT="$BASE/out"

python3 -I - "$SRC" <<'PY'
import os, pathlib, re, subprocess, sys
src = pathlib.Path(sys.argv[1])
files = {
    "run_grain.sh",
    "sandstorm-manifest",
    "sandstorm-http-bridge",
    "sandstorm-http-bridge-config",
    "sandstorm-pkgdef.capnp",
    "DESCRIPTION.mkdn",
    "CHANGELOG.mkdn",
    "LICENSE.txt",
    "API.md",
    "bin/ethercalc",
    "runtime/bun",
    "runtime/workerd",
    "static/img/davy/gfx/screenshot.png",
    "packages/worker/workerd/config.capnp",
    "packages/worker/workerd/worker/index.js",
}
for directory in (
    "assets",
    "app-graphics",
    "packages/cli/src",
    "packages/migrate/src",
):
    for path in (src / directory).rglob("*"):
        if path.is_file() and not path.is_symlink():
            files.add(path.relative_to(src).as_posix())

system_binaries = [
    "/bin/bash", "/usr/bin/curl", "/usr/bin/dirname", "/usr/bin/mkdir",
    "/usr/bin/env", "/usr/bin/seq", "/usr/bin/sleep", "/usr/bin/touch",
]
for name in system_binaries:
    path = pathlib.Path(name)
    if not path.is_file():
        raise SystemExit(f"missing required system binary: {name}")
    files.add(name.lstrip("/"))

ldd_pattern = re.compile(r"(?:=>\s*)?(/[A-Za-z0-9_./+:-]+)")
for binary in system_binaries + [str(src / "runtime/bun"), str(src / "runtime/workerd")]:
    output = subprocess.check_output(["ldd", binary], text=True)
    for line in output.splitlines():
        match = ldd_pattern.search(line.strip())
        if not match:
            continue
        path = pathlib.Path(match.group(1))
        if not path.exists():
            raise SystemExit(f"missing shared library for {binary}: {path}")
        files.add(str(path).lstrip("/"))
        # SPK preserves symlinks. Include every direct target as well as the
        # fully resolved path: resolving /lib64/ld-linux through /usr alone
        # leaves the packed /lib64 symlink pointing at an absent /lib target.
        link = path
        seen = set()
        while link.is_symlink() and link not in seen:
            seen.add(link)
            target = pathlib.Path(os.readlink(link))
            if not target.is_absolute():
                target = link.parent / target
            link = pathlib.Path(os.path.normpath(target))
            files.add(str(link).lstrip("/"))
        resolved = path.resolve()
        files.add(str(resolved).lstrip("/"))

virtual_files = {"sandstorm-manifest", "sandstorm-http-bridge", "sandstorm-http-bridge-config", "proc/cpuinfo"}
missing = sorted(name for name in files if name not in virtual_files and not (
    (src / name).exists() or pathlib.Path("/" + name).exists()
))
if missing:
    raise SystemExit("package inputs missing: " + ", ".join(missing))
(src / "sandstorm-files.list").write_text("\n".join(sorted(files)) + "\n")
print(f"Generated {len(files)} runtime file entries")
PY

cd "$SRC"
"$SPK" pack -k"$BASE/ethercalc.keyring" "$OUT/ethercalc.spk"
"$SPK" verify --details "$OUT/ethercalc.spk" | tee "$OUT/verify.txt"
sha256sum "$OUT/ethercalc.spk" | tee "$OUT/package.sha256"
