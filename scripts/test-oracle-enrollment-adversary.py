#!/usr/bin/env python3
"""Focused adversarial checks on the consent storage custody boundary.

Uses actual helper functions and disposable local files; no root, Store mutation,
Mini admission or deployed systemd service. Set CONSENT_FS_SOURCE to helper path.
"""
import hashlib
import importlib.util
import json
import os
import pwd
import grp
import secrets
import shutil
import socket
import struct
import subprocess
import time
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(os.environ.get('CONSENT_FS_SOURCE', '/Users/ember/workbox/oracle-consent-fs/deploy/spk-host/controller-world.py'))


def load():
    spec = importlib.util.spec_from_file_location('review_consent_storage', SOURCE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ConsentStorageAdversary(unittest.TestCase):
    def setUp(self):
        if not SOURCE.is_file():
            self.skipTest('storage repair source unavailable')
        self.mod = load()
        if not hasattr(self.mod, 'consent_storage'):
            self.skipTest('storage repair not yet present')
        self.tmp = tempfile.TemporaryDirectory(prefix='enrollment-adversary-')
        self.addCleanup(self.tmp.cleanup)
        self.parent = Path(self.tmp.name).resolve() / 'private'
        self.parent.mkdir(mode=0o700)
        self.store = self.parent / 'store'
        self.store.mkdir(mode=0o700)
        self.db = self.store / 'forward-link.sqlite3'
        self.lock = self.parent / 'store.head-anchor.lock'
        self.anchor = self.parent / 'store.head-anchor'
        self.db.write_bytes(b'fixture database')
        self.lock.write_bytes(b'')
        self.anchor.write_bytes(b'MINIANC2' + b'a' * 112)
        for p in (self.db, self.lock, self.anchor):
            p.chmod(0o600)
        self.uid = os.getuid()
        self.settings = json.dumps({'storageRoot': str(self.store)}).encode()
        # /tmp or a platform-specific temporary ancestor is not a trusted real
        # deployment path. Validate the fixture subtree only; no root claim.
        def subtree(path, owners):
            path = Path(path)
            while path != self.parent.parent:
                m = path.lstat()
                self.assertFalse(path.is_symlink())
                self.assertEqual(m.st_uid, self.uid)
                self.assertFalse(m.st_mode & 0o022)
                path = path.parent
        if not hasattr(os, 'listxattr'):
            self.mac_xattr = patch.object(os, 'listxattr', return_value=[], create=True)
            self.mac_xattr.start()
            self.addCleanup(self.mac_xattr.stop)
        self.ancestry = patch.object(self.mod, 'ancestry', side_effect=subtree)
        self.ancestry.start()
        self.addCleanup(self.ancestry.stop)

    def selected(self):
        # The production code additionally checks ancestors above the fixture.
        return self.mod.consent_storage(self.settings, self.uid)

    def test_database_and_lock_replacement_change_the_custody_pin(self):
        initial = self.selected()
        for path, key in ((self.db, 'database'), (self.lock, 'lock')):
            old = path.with_name(path.name + '.old')
            path.rename(old)
            path.write_bytes(old.read_bytes()); path.chmod(0o600)
            changed = self.selected()
            self.assertNotEqual(changed[key]['ino'], initial[key]['ino'])
            path.unlink(); old.rename(path)
        self.assertEqual(self.selected(), initial)

    def test_anchor_can_be_atomically_replaced_but_must_remain_private_and_well_formed(self):
        initial = self.selected()
        replacement = self.parent / 'replacement'
        replacement.write_bytes(b'MINIANC2' + b'b' * 112); replacement.chmod(0o600)
        replacement.replace(self.anchor)
        self.assertEqual(self.selected(), initial)
        self.anchor.chmod(0o644)
        with self.assertRaises(ValueError): self.selected()
        self.anchor.chmod(0o600); self.anchor.write_bytes(b'bad')
        with self.assertRaises(ValueError): self.selected()

    def test_symlink_and_permission_substitution_refuse(self):
        self.db.rename(self.parent / 'real-db')
        self.db.symlink_to(self.parent / 'real-db')
        with self.assertRaises((ValueError, OSError)): self.selected()
        self.db.unlink(); (self.parent / 'real-db').rename(self.db)
        self.store.chmod(0o755)
        with self.assertRaises(ValueError): self.selected()

    def test_partial_archive_resumes_only_exact_prefix(self):
        target = self.parent / 'receipt'
        temporary = self.parent / '.receipt-publishing'
        temporary.write_bytes(b'exact-'); temporary.chmod(0o600)
        self.mod.publish_exact(target, b'exact-bytes', self.uid, os.getgid())
        self.assertEqual(target.read_bytes(), b'exact-bytes')
        self.assertFalse(temporary.exists())
        self.mod.publish_exact(target, b'exact-bytes', self.uid, os.getgid())
        with self.assertRaises(ValueError):
            self.mod.publish_exact(target, b'other-bytes', self.uid, os.getgid())
        self.assertEqual(target.read_bytes(), b'exact-bytes')

    def test_conflicting_partial_archive_never_changes_final(self):
        target = self.parent / 'receipt'
        temporary = self.parent / '.receipt-publishing'
        temporary.write_bytes(b'wrong'); temporary.chmod(0o600)
        with self.assertRaises(ValueError):
            self.mod.publish_exact(target, b'exact-bytes', self.uid, os.getgid())
        self.assertFalse(target.exists())
        self.assertEqual(temporary.read_bytes(), b'wrong')

    def test_config_paths_and_duplicate_storage_fields_refuse(self):
        for raw in (b'{"storageRoot":"/a/../b"}',
                    b'{"storageRoot":"/one","storageRoot":"/two"}',
                    b'{"storageRoot":"relative"}'):
            with self.subTest(raw=raw), self.assertRaises((ValueError, OSError)):
                self.mod.consent_storage(raw, self.uid)



def physical():
    """Disposable actual Lean/SQLite systemd sandbox experiment; Linux root only."""
    import sys
    if os.geteuid() != 0 or not sys.platform.startswith('linux'):
        raise RuntimeError('physical probe requires Linux root on the designated host')
    source = Path('/othersys/lanes/oracle-u3-r2-private')
    mini = Path('/othersys/lanes/oracle-u3-consent-rust-r2-evidence/mini')
    parent = Path('/othersys/lanes')
    controller, op = pwd.getpwnam('nobody'), pwd.getpwnam('hbox')
    uid = controller.pw_uid
    if uid == 0 or uid == op.pw_uid or controller.pw_gid != uid:
        raise RuntimeError('unexpected nobody fixture identity')
    if op.pw_uid != 1000 or op.pw_gid != 1000:
        raise RuntimeError('unexpected operator identity')
    fixture = parent / ('oracle-enrollment-sandbox-' + secrets.token_hex(6))
    fixture.mkdir(mode=0o755)
    fixture.chmod(0o755)
    private = fixture / 'private'
    shutil.copytree(source, private, ignore=shutil.ignore_patterns('consent-anchors', '__pycache__'))
    for path in [private, *private.rglob('*')]:
        if not path.is_symlink(): os.chown(path, op.pw_uid, op.pw_gid)
    private.chmod(0o700)
    store = private / 'store'; store.chmod(0o700)
    config_path = private / 'deployment/private-copy-config.json'
    config = json.loads(config_path.read_text())
    for k in ('storageRoot', 'storageBinary', 'signatureBinary', 'checkpointKey'):
        old = config.get(k)
        if isinstance(old, str) and old.startswith(str(source) + '/'):
            config[k] = str(private) + old[len(str(source)):]
    config_path.write_text(json.dumps(config, separators=(',', ':')))
    os.chmod(config_path, 0o600)
    for p in (store / 'forward-link.sqlite3', private / 'store.head-anchor', private / 'store.head-anchor.lock'):
        p.chmod(0o600)
    provider = private / 'provider'
    def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
    expected = {
        'mini': '68f8eefadfb0d7bfa9a8bc69f7656a362e32688553ac7114b32cfd07bd9a1d48',
        'provider': '1fca63aa1c82aefc2d9ea4f5161af951b505bb6a72edb6b34d8bac3d3ebe2717',
        'db': '8db2090b6a22e5b148e5bbec7a93d593967d39392093161b832242ca15f047aa',
        'anchor': '6f7197630c8845e6d96afe6fc54b4f42ee874dba9387c2e7c6341b7d38214787'}
    for label, path in (('mini', mini), ('provider', provider), ('db', store / 'forward-link.sqlite3'), ('anchor', private / 'store.head-anchor')):
        if sha(path) != expected[label]: raise RuntimeError('fixture identity mismatch: ' + label)
    sockdir = fixture / 'socket'; sockdir.mkdir(mode=0o700); os.chown(sockdir, uid, uid)
    intent = (private / 'birth-attempt/intent.bin').read_bytes(); key = (private / 'controller.pub').read_bytes()
    if len(key) != 32: raise RuntimeError('fixture key length')
    tag = b'MINI-CONTROLLER-CONSENT/v1\0'
    hello = tag + bytes.fromhex(sha(provider)) + bytes.fromhex(sha(config_path))
    client = r'''import json,os,socket,struct,sys,time
j=json.load(sys.stdin); os.setgroups([]);os.setgid(j['uid']);os.setuid(j['uid'])
s=socket.socket(socket.AF_UNIX);s.settimeout(1100);s.connect(j['path'])
def exact(n):
 b=b''
 while len(b)<n:
  x=s.recv(n-len(b))
  if not x: raise EOFError('connection closed without consent')
  b+=x
 return b
def call(b):
 s.sendall(struct.pack('<I',len(b))+b);n=struct.unpack('<I',exact(4))[0]
 if not 0<n<=12102760: raise ValueError('frame limit')
 return exact(n)
def pair(a,b): return struct.pack('<I',len(a))+a+b
h=bytes.fromhex(j['hello']); assert call(h)==h
i=bytes.fromhex(j['intent']);k=bytes.fromhex(j['key']);r=call(b'\xdc'+pair(i,pair(k,b'')))
assert r==b'\xdc'+i
bad=call(b'\xdc'+pair(i+b'\0',pair(k,b'')));assert bad[:1]==b'\xff'
print(json.dumps({'valid':True,'malformed_refused':True}))
'''
    runid = secrets.token_hex(6)
    results = {'protocol': 'oracle-consent-systemd-storage-probe-v1', 'fixture': str(fixture),
               'scope': 'private copied Store; actual pinned Lean consent and socket transport; no signing or Store submission',
               'source_hashes': expected, 'config_sha256': sha(config_path), 'phases': {}}
    for writable in (False, True):
        label = 'fixed' if writable else 'baseline'
        stem = 'oracle-enrollment-adversary-' + runid + '-' + label
        socket_unit, service_unit = stem + '.socket', stem + '.service'
        sock = sockdir / (label + '.sock')
        anchors = private / ('anchors-' + label); anchors.mkdir(mode=0o700); os.chown(anchors, op.pw_uid, op.pw_gid)
        units = Path('/run/systemd/system')
        socket_file, service_file = units / socket_unit, units / service_unit
        rw = f'{anchors}' + (f' {private}' if writable else '')
        socket_text = (f'[Socket]\nListenStream={sock}\nSocketUser={uid}\nSocketGroup={uid}\nSocketMode=0600\nAccept=no\nService={service_unit}\n')
        service_text = (f'[Service]\nUser={op.pw_uid}\nGroup={op.pw_gid}\nExecStart={mini} serve-controller-consent '
            f'--socket {sock} --consent {provider} --config {config_path} --consent-sha256 {sha(provider)} '
            f'--config-sha256 {sha(config_path)} --controller-uid {uid} --anchors {anchors}\n'
            f'Environment=HOME={private}\nReadWritePaths={rw}\nNoNewPrivileges=yes\nPrivateTmp=yes\n'
            'ProtectSystem=strict\nProtectHome=yes\nMemoryMax=2G\nMemorySwapMax=0\nCPUQuota=100%\nTasksMax=128\n')
        def command(args, **kw): return subprocess.run(args, check=True, capture_output=True, text=True, **kw)
        def send():
            body = json.dumps({'uid':uid,'path':str(sock),'hello':hello.hex(),'intent':intent.hex(),'key':key.hex()})
            return subprocess.run([sys.executable, '-c', client], input=body, capture_output=True, text=True, timeout=1200)
        try:
            for path, data in ((socket_file, socket_text), (service_file, service_text)):
                fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY | os.O_NOFOLLOW, 0o644)
                with os.fdopen(fd, 'w') as f: f.write(data)
            command(['systemctl', 'daemon-reload'])
            command(['systemctl', 'start', socket_unit])
            first = send()
            log = subprocess.run(['journalctl','-u',service_unit,'--no-pager','-o','cat'],capture_output=True,text=True).stdout
            if writable:
                if first.returncode != 0: raise RuntimeError('fixed first exchange failed: ' + first.stderr[-2000:] + '\n' + log[-4000:])
                frontier = anchors / 'frontier'
                if not frontier.is_file(): raise RuntimeError('fixed service did not retain frontier')
                first_frontier = sha(frontier)
                command(['systemctl','stop',service_unit])
                restart = send()
                if restart.returncode != 0: raise RuntimeError('fixed restart exchange failed: ' + restart.stderr[-2000:])
                results['phases'][label] = {'unit':service_unit, 'service_sha256':hashlib.sha256(service_text.encode()).hexdigest(), 'first':json.loads(first.stdout),'restart':json.loads(restart.stdout),'frontier_sha256':first_frontier}
            else:
                if first.returncode == 0 or 'readonly' not in log.lower() and 'read-only' not in log.lower() and 'ero fs' not in log.lower() and 'ero fs' not in first.stderr.lower():
                    raise RuntimeError('baseline did not reproduce read-only filesystem: ' + first.stderr[-2000:] + '\n' + log[-4000:])
                results['phases'][label] = {'unit':service_unit, 'service_sha256':hashlib.sha256(service_text.encode()).hexdigest(), 'refused_without_success': True, 'read_only_error_observed': True}
            (fixture / (label + '.service.log')).write_text(log)
            print(label + ' completed', flush=True)
        finally:
            subprocess.run(['systemctl','stop',socket_unit,service_unit],capture_output=True)
            for path in (socket_file,service_file):
                try: path.unlink()
                except FileNotFoundError: pass
            subprocess.run(['systemctl','daemon-reload'],capture_output=True)
            subprocess.run(['systemctl','reset-failed',service_unit],capture_output=True)
    (fixture / 'report.json').write_text(json.dumps(results,indent=2)+'\n')
    print(json.dumps(results,indent=2),flush=True)


if __name__ == '__main__':
    import sys
    if sys.argv[1:] == ['--physical']:
        physical()
    else:
        unittest.main()
