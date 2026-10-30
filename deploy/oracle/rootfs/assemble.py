#!/usr/bin/env python3
"""Build a new Linux Python rootfs from retained hash-locked inputs.

This is artifact preparation, not Mini authority or a runtime proof checker.
Requires Linux, dpkg-deb, tar, and an existing pip-capable Python interpreter.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def prune_dangling_links(root):
    """Drop base-image links to omitted pseudo-filesystems/development files."""
    removed = []
    for path in sorted(root.rglob('*')):
        if not path.is_symlink():
            continue
        relative = path.relative_to(root).as_posix()
        pending, resolved, hops = relative.split('/'), [], 0
        while pending:
            part = pending.pop(0)
            if part in ('', '.'):
                continue
            if part == '..':
                if not resolved:
                    raise ValueError('link escapes image: ' + relative)
                resolved.pop()
                continue
            candidate = root.joinpath(*resolved, part)
            if candidate.is_symlink():
                hops += 1
                if hops > 64:
                    raise ValueError('symlink cycle: ' + relative)
                dest = os.readlink(candidate)
                if dest.startswith('/'):
                    resolved = []
                pending = dest.split('/') + pending
            else:
                resolved.append(part)
        if not root.joinpath(*resolved).exists():
            removed.append({'path': relative, 'target': os.readlink(path)})
            path.unlink()
    return removed


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--inputs', type=Path, required=True)
    ap.add_argument('--lock', type=Path, required=True)
    ap.add_argument('--target', type=Path, required=True)
    ap.add_argument('--pip-python', type=Path, required=True)
    args = ap.parse_args()
    inputs, target = args.inputs.resolve(), args.target.absolute()
    if target.exists() or target.is_symlink():
        raise SystemExit('target exists; use a new dedicated directory')
    lock = json.loads(args.lock.read_text())
    items = [{'filename': 'ubuntu-base.tar', 'sha256': lock['base']['export_sha256']}]
    items += [dict(i, filename='debs/' + i['filename']) for i in lock['debs']]
    items += [dict(i, filename='wheels/' + i['filename']) for i in lock['wheels']]
    items += [{'filename': 'requirements.lock', 'sha256': lock['requirements_sha256']}]
    for item in items:
        path = inputs / item['filename']
        if path.is_symlink() or not path.is_file() or sha(path) != item['sha256']:
            raise SystemExit('input hash mismatch: ' + str(path))
    # The retained export is a public OCI image, not a host filesystem capture.
    # Verify names before extraction; absolute in-image symlink targets are valid.
    with tarfile.open(inputs / 'ubuntu-base.tar') as archive:
        for item in archive:
            if item.name.startswith('/') or '..' in Path(item.name).parts or item.isdev() or item.isfifo():
                raise SystemExit('unexpected base archive member: ' + item.name)
    target.mkdir(parents=True)
    subprocess.run(['tar', '--no-same-owner', '-xf', str(inputs / 'ubuntu-base.tar'), '-C', str(target)], check=True)
    for item in lock['debs']:
        subprocess.run(['dpkg-deb', '-x', str(inputs / 'debs' / item['filename']), str(target)], check=True)
    site = target / 'usr/local/lib/python3.12/dist-packages'
    subprocess.run([str(args.pip_python), '-m', 'pip', '--disable-pip-version-check', '--no-cache-dir',
                    'install', '--no-compile', '--no-deps', '--no-index', '--require-hashes',
                    '--find-links', str(inputs / 'wheels'), '--target', str(site),
                    '-r', str(inputs / 'requirements.lock')], check=True)
    # All deletion below is confined to this newly created tree. Keep licenses
    # and package metadata, but not image instance state or generated CLI wrappers.
    for rel in ('var', 'tmp', 'proc', 'dev', 'run', 'sys', 'opt'):
        path = target / rel
        if path.is_symlink() or path.is_file():
            path.unlink()
        elif path.exists():
            shutil.rmtree(path)
        path.mkdir(mode=0o755)
    if (site / 'bin').exists():
        shutil.rmtree(site / 'bin')
    for path in target.rglob('*'):
        if path.is_file() and not path.is_symlink():
            path.chmod(path.stat().st_mode & 0o777)  # remove set-id bits in the private image
    (target / 'etc/hostname').write_text('oracle-appliance\n')
    (target / 'etc/hosts').write_text('127.0.0.1 localhost\n::1 localhost\n')
    (target / 'etc/resolv.conf').write_text('')  # query runtime has no external DNS dependency
    # No pip executable or build environment is copied into the appliance.
    if not (target / 'usr/bin/python3.12').is_file() or (target / 'usr/bin/python3.12').is_symlink():
        raise SystemExit('regular Python 3.12 executable missing')
    removed_links = prune_dangling_links(target)
    print(json.dumps({'removed_dangling_links': removed_links, 'rootfs': str(target), 'input_lock_sha256': sha(args.lock),
                      'scope': 'Assembly only; run check-runtime.py inside this rootfs on Linux.'}))


if __name__ == '__main__':
    main()
