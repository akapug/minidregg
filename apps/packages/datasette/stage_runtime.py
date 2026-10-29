"""Copy the CPython runtime and its dynamic-library closure into the SPK root."""

import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import sysconfig


root = Path(sys.argv[1])
if not root.is_absolute():
    raise SystemExit("rootfs path must be absolute")
copied = set()


def copy_absolute(name):
    source = Path(name)
    if not source.is_absolute():
        raise ValueError(name)
    source = Path(os.path.normpath(source))
    if source in copied:
        return
    copied.add(source)
    destination = root / source.relative_to("/")
    destination.parent.mkdir(parents=True, exist_ok=True)
    if source.is_symlink():
        link = os.readlink(source)
        if destination.is_symlink() or destination.exists():
            destination.unlink()
        destination.symlink_to(link)
        target = Path(link) if os.path.isabs(link) else source.parent / link
        copy_absolute(target)
    elif source.is_dir():
        shutil.copytree(source, destination, symlinks=True, dirs_exist_ok=True)
    else:
        shutil.copy2(source, destination)


copy_absolute("/usr/bin/python3")
copy_absolute(Path("/usr/bin/python3").resolve())
copy_absolute(sysconfig.get_path("stdlib"))
if Path("/etc/mime.types").is_file():
    copy_absolute("/etc/mime.types")

shared_objects = [root / Path("/usr/bin/python3").resolve().relative_to("/")]
shared_objects.extend(
    path
    for directory in (root / "usr/lib/python3.13", root / "opt/app/venv")
    for path in directory.rglob("*")
    if path.is_file() and ".so" in path.name
)

libraries = set()
for binary in shared_objects:
    result = subprocess.run(
        ["ldd", str(binary)], check=True, text=True, capture_output=True
    )
    libraries.update(re.findall(r"(?:=>\s*)?(/[^\s]+)", result.stdout))

for library in sorted(libraries):
    copy_absolute(library)

(root / "etc").mkdir(parents=True, exist_ok=True)
print(f"Staged {len(shared_objects)} executables/extensions and {len(libraries)} libraries")
