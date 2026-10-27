#!/usr/bin/env python3
"""Check a prepared Linux rootfs's ELF loader closure using chroot, without query execution."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument('--rootfs', type=Path, required=True)
ap.add_argument('--bridge', type=Path, required=True)
ap.add_argument('--out', type=Path, required=True)
a = ap.parse_args()
root = a.rootfs.resolve()
if a.out.exists():
    raise SystemExit('refuse to replace evidence')
probe = root / 'tmp/bridge-elf-probe'
if probe.exists() or probe.is_symlink():
    raise SystemExit('probe target exists')
shutil.copyfile(a.bridge, probe)
probe.chmod(0o755)
try:
    files = []
    for path in sorted(root.rglob('*')):
        if path.is_symlink() or not path.is_file():
            continue
        with path.open('rb') as f:
            if f.read(4) != b'\x7fELF':
                continue
        files.append(path)
    results = []
    for path in files:
        relative = '/' + path.relative_to(root).as_posix()
        command = ['/usr/sbin/chroot', str(root), '/lib64/ld-linux-x86-64.so.2']
        # Wheel-private helper libraries inherit this search directory from
        # their importing extension's RPATH; list them in that same context.
        wheel_lib = path.parent.name.endswith('.libs')
        if wheel_lib:
            command += ['--library-path', '/' + path.parent.relative_to(root).as_posix()]
        command += ['--list', relative]
        run = subprocess.run(command, capture_output=True, text=True, timeout=30,
                             env={'PATH': '/usr/sbin:/usr/bin:/bin', 'LANG': 'C.UTF-8'})
        results.append({'path': relative, 'wheel_private_library_path': wheel_lib, 'exit_code': run.returncode,
                        'stdout': run.stdout, 'stderr': run.stderr})
    failures = [r for r in results if r['exit_code'] != 0 or 'not found' in r['stdout'] or 'not found' in r['stderr']]
    output = {'scope': 'Dynamic-loader dependency listing, not application execution.',
              'rootfs': str(root), 'bridge_sha256': hashlib.sha256(a.bridge.read_bytes()).hexdigest(),
              'elf_files': len(files), 'failures': len(failures), 'results': results}
    a.out.write_text(json.dumps(output, indent=2, sort_keys=True) + '\n')
    print(json.dumps({k: v for k, v in output.items() if k != 'results'}))
    if failures:
        raise SystemExit(1)
finally:
    probe.unlink()
