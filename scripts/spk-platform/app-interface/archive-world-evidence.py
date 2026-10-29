#!/usr/bin/env python3
"""Bounded private evidence archive; no world operations or authority decisions."""
import os
from pathlib import Path
import re
import stat
import sys
import tarfile

MAX_FILES = 4096
MAX_BYTES = 256 * 1024 * 1024
MAX_FILE_BYTES = 96 * 1024 * 1024
MAX_ARCHIVE_BYTES = 288 * 1024 * 1024
MAX_ENTRIES = 16384
MAX_DEPTH = 16
PRUNE = {".cache", "cache", "caches", "image", "images", "volume", "volumes", "packages", "node_modules"}


def archive(world, grains, store, output, *, max_files=MAX_FILES, max_bytes=MAX_BYTES):
    world, grains = Path(world), Path(grains)
    plan, total, entries = [], 0, 0

    def children(path):
        nonlocal entries
        selected = []
        with os.scandir(path) as scan:
            for child in scan:
                entries += 1
                if entries > MAX_ENTRIES:
                    raise ValueError("evidence traversal bound exceeded")
                selected.append(Path(child.path))
        return sorted(selected)

    def visit(path, name, recursive=True, depth=0):
        nonlocal entries, total
        entries += 1
        if entries > MAX_ENTRIES or depth > MAX_DEPTH:
            raise ValueError("evidence traversal bound exceeded")
        st = path.lstat()
        if stat.S_ISDIR(st.st_mode):
            if recursive:
                for child in children(path):
                    if child.name not in PRUNE:
                        visit(child, name + "/" + child.name, True, depth + 1)
        elif stat.S_ISREG(st.st_mode):
            if st.st_size > MAX_FILE_BYTES or len(plan) >= max_files or total + st.st_size > max_bytes:
                raise ValueError("evidence aggregate/file bound exceeded")
            total += st.st_size
            plan.append((path, name, st))
        # Never follow links or read sockets/devices/FIFOs.

    # grain.rs: state_root = grains_root/store/host; app_dir = state_root/apps/app.
    # Only private custody, install journals and generation journals are selected.
    apps = grains / store / "host" / "apps"
    # Refuse symlinked archive roots rather than traversing outside custody.
    for root in (grains, grains / store, grains / store / "host", apps,
                 world, world / "w", world / "w" / "evidence", world / "w" / "sock"):
        if root.is_symlink():
            raise ValueError("evidence root symlink refused")
    if apps.exists():
        for app in children(apps):
            entries += 1
            if entries > MAX_ENTRIES:
                raise ValueError("evidence traversal bound exceeded")
            if not re.fullmatch(r"[0-9]+", app.name) or not stat.S_ISDIR(app.lstat().st_mode):
                continue
            for child in children(app):
                entries += 1
                if entries > MAX_ENTRIES:
                    raise ValueError("evidence traversal bound exceeded")
                if re.fullmatch(r"custody|install(?:-refused-[0-9]+)?|g[0-9]+", child.name):
                    visit(child, f"native/apps/{app.name}/{child.name}")
    for name in ("WORLD.env", "result.log"):
        if (world / name).exists():
            visit(world / name, "driver/" + name)
    evidence = world / "w" / "evidence"
    if evidence.exists():
        visit(evidence, "driver/w/evidence")
    # sock contains private host/proxy endpoints in subdirectories. Retain only
    # top-level regular driver identity/PID/log files, never endpoint directories.
    sock = world / "w" / "sock"
    if sock.exists():
        for child in children(sock):
            if child.suffix in {".json", ".pid", ".mode", ".pin", ".log"}:
                visit(child, "driver/w/sock/" + child.name, recursive=False)
    class BoundedOutput:
        def __init__(self):
            self.size = 0
        def write(self, data):
            if self.size + len(data) > MAX_ARCHIVE_BYTES:
                raise ValueError("evidence archive output bound exceeded")
            self.size += len(data)
            return output.write(data)
    with tarfile.open(fileobj=BoundedOutput(), mode="w|") as tar:
        for path, name, expected in plan:
            fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
            with os.fdopen(fd, "rb") as stream:
                actual = os.fstat(stream.fileno())
                identity = lambda st: (st.st_dev, st.st_ino, st.st_size, st.st_mtime_ns, st.st_ctime_ns)
                if not stat.S_ISREG(actual.st_mode) or identity(actual) != identity(expected):
                    raise ValueError("evidence source changed before archive")
                info = tarfile.TarInfo(name)
                info.mode, info.size = 0o600, actual.st_size
                tar.addfile(info, stream)
                if identity(os.fstat(stream.fileno())) != identity(expected):
                    raise ValueError("evidence source changed during archive")
    return len(plan), total


if __name__ == "__main__":
    try:
        count, size = archive(sys.argv[1], sys.argv[2], sys.argv[3], sys.stdout.buffer)
        print(f"archived_files={count} source_bytes={size}", file=sys.stderr)
    except Exception as error:
        print(f"evidence archive refused: {error}", file=sys.stderr)
        raise SystemExit(1)
