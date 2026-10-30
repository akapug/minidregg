#!/usr/bin/env python3
"""Disposable OS primitives only; does not run the Mini helper or signal other processes."""
import json
import os
from pathlib import Path
import pty
import select
import signal
import stat
import subprocess
import tempfile
import time

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    reference = root / 'recipient-reference.json'
    private = root / 'private-fixture'
    private.write_text('TEST-PRIVATE-CONTENT')
    reference.write_text(json.dumps({'type': 'minidregg-delegated-reference-v1', 'recipient': '7', 'target': '42'}))
    assert stat.S_ISREG(reference.lstat().st_mode)
    assert json.loads(reference.read_text())['recipient'] == '7'
    reference.unlink()
    reference.symlink_to(private)
    print('source_swap:', reference.read_text())
    destination = root / 'doc.42.json'
    temporary = destination.with_suffix('.tmp')
    victim = root / 'victim-fixture'
    victim.write_text('PRESERVE')
    temporary.symlink_to(victim)
    temporary.write_text('REFERENCE')
    print('destination_symlink_target:', victim.read_text())
    temporary.rename(destination)
    print('renamed_destination_is_symlink:', destination.is_symlink())

master, slave = pty.openpty()
code = ('import signal,sys; signal.signal(signal.SIGHUP, signal.SIG_IGN); '
        'print("READY",flush=True); line=sys.stdin.readline(); '
        'print("EXECUTED:"+line.strip(),flush=True)')
child = subprocess.Popen(['python3', '-u', '-c', code], stdin=slave, stdout=slave,
                         stderr=slave, start_new_session=True)
os.close(slave)
try:
    assert select.select([master], [], [], 2)[0]
    print('before:', os.read(master, 4096).decode().strip())
    os.kill(child.pid, signal.SIGHUP)
    os.write(master, b'run-after-revoke\n')
    assert select.select([master], [], [], 2)[0]
    time.sleep(0.05)
    print('after:', os.read(master, 4096).decode().strip())
    child.wait(timeout=2)
finally:
    if child.poll() is None:
        child.kill()
        child.wait()
    os.close(master)
