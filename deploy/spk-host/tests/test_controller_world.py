#!/usr/bin/env python3
"""Unprivileged checks of the actual controller installer's custody boundaries."""
import importlib.util
import json
import fcntl
import shutil
import hashlib
import re
import os
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('controller_world', Path(__file__).parents[1] / 'controller-world.py')
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)


class ControllerWorldTests(unittest.TestCase):
    def setUp(self):
        # /tmp has intentionally untrusted world-write ancestry, so a custody
        # positive belongs beneath the actual operator's protected home.
        self.temp = tempfile.TemporaryDirectory(prefix='.mini-controller-test-', dir=Path.home())
        self.root = Path(self.temp.name)
        self.uid, self.gid = os.getuid(), os.getgid()
        # Linux-only xattr syscall is exercised by the Linux run; macOS tests
        # still check all ordinary descriptor/copy gates.
        if not hasattr(c.os, 'listxattr'):
            self.xattrs = patch.object(c.os, 'listxattr', return_value=[], create=True)
            self.xattrs.start(); self.addCleanup(self.xattrs.stop)

    def tearDown(self):
        self.temp.cleanup()

    def file(self, name, data=b'bounded source', mode=0o600):
        p = self.root / name
        p.write_bytes(data); p.chmod(mode)
        return p

    def test_installer_pins_the_exact_companion_source(self):
        installer = Path(__file__).parents[1] / 'install-user-world'
        source = Path(__file__).parents[1] / 'controller-world.py'
        digest = re.search(r"hexdigest\(\) != '([0-9a-f]{64})'", installer.read_text()).group(1)
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest)
        self.assertIn("compile(code, path, 'exec')", installer.read_text())

    def test_path_rejects_unit_escaping_and_aliases(self):
        self.assertEqual(c.canonical('/var/lib/mini-spk-worlds/ab/controller'), Path('/var/lib/mini-spk-worlds/ab/controller'))
        for value in ['/a/../b', '/a/./b', '/a//b', '/a/', 'relative', '/a b', '/a\nUser=root', '/a%h']:
            with self.subTest(value=value), self.assertRaises(ValueError): c.canonical(value)

    def test_source_regular_bounds_owner_links_and_setuid(self):
        p = self.file('source')
        self.assertEqual(c.read_file(p, self.uid, 100), b'bounded source')
        with self.assertRaises(ValueError): c.read_file(p, self.uid, 3)
        with self.assertRaises(ValueError): c.read_file(p, self.uid + 1000, 100)
        p.chmod(0o4600)
        with self.assertRaises(ValueError): c.read_file(p, self.uid, 100)
        p.chmod(0o600)
        alias = self.root / 'alias'; alias.symlink_to(p)
        with self.assertRaises(OSError): c.read_file(alias, self.uid, 100)
        alias.unlink(); os.link(p, alias)
        with self.assertRaises(ValueError): c.read_file(p, self.uid, 100)

    def test_private_key_mode_is_checked_on_opened_descriptor(self):
        p = self.file('key', b'k' * 32)
        self.assertEqual(c.read_file(p, self.uid, 32, required_mode=0o600), b'k' * 32)
        for mode in (0o640, 0o644):
            p.chmod(mode)
            with self.assertRaises(ValueError): c.read_file(p, self.uid, 32, required_mode=0o600)

    @unittest.skipUnless(shutil.which('getfacl') and shutil.which('setfacl'), 'Linux ACL utilities required')
    def test_actual_acl_grant_and_exact_restore(self):
        p = self.file('acl-target')
        before = c.acl_text(p)
        entry = c.grant_acl(p, 999 if self.uid != 999 else 998, '-w-', self.uid)
        self.assertNotEqual(entry['after'], before)
        c.run(['/usr/bin/setfacl', '--restore=-'], input=(f'# file: {p}\n' + entry['before']).encode())
        self.assertEqual(c.acl_text(p), before)

    def test_controller_shared_lock_excludes_lifecycle_mutation(self):
        p = self.file('lock')
        with open(p, 'rb') as call, open(p, 'rb') as change:
            fcntl.flock(call, fcntl.LOCK_SH | fcntl.LOCK_NB)
            with self.assertRaises(BlockingIOError): fcntl.flock(change, fcntl.LOCK_EX | fcntl.LOCK_NB)
            fcntl.flock(call, fcntl.LOCK_UN)
            fcntl.flock(change, fcntl.LOCK_EX | fcntl.LOCK_NB)

    def test_capability_bearing_binary_refused(self):
        p = self.file('binary', b'executable', 0o700)
        with patch.object(c.os, 'listxattr', return_value=['security.capability']):
            with self.assertRaises(ValueError): c.read_file(p, self.uid, 100, executable=True)

    def test_parent_symlink_and_writable_directory_refused(self):
        real = self.root / 'real'; real.mkdir(mode=0o700)
        p = real / 'file'; p.write_bytes(b'data'); p.chmod(0o600)
        alias = self.root / 'alias'; alias.symlink_to(real, target_is_directory=True)
        with self.assertRaises(ValueError): c.read_file(alias / 'file', self.uid, 100)
        real.chmod(0o777)
        with self.assertRaises(ValueError): c.read_file(p, self.uid, 100)

    def test_copy_is_single_creation_and_private(self):
        p = self.root / 'copied'
        c.write_new(p, b'exact bytes', self.uid, self.gid)
        self.assertEqual(c.read_file(p, self.uid, 100), b'exact bytes')
        self.assertEqual(stat.S_IMODE(p.stat().st_mode), 0o600)
        with self.assertRaises(FileExistsError): c.write_new(p, b'replacement', self.uid, self.gid)
        self.assertEqual(p.read_bytes(), b'exact bytes')

    def record(self):
        return {'store':'ab'*8, 'uid':self.uid, 'gid':self.gid, 'operatorUid':self.uid,
                'operatorGid':self.gid, 'home':str(self.root), 'units':c.names('ab'*8)}

    def test_units_never_execute_as_root_and_distinguish_activation(self):
        r = self.record(); r['uid'] = 999; r['gid'] = 999; r['operatorUid'] = 1000; r['operatorGid'] = 1000
        units = c.unit_bytes(r, Path('/var/lib/mini/controller'), Path('/operator/private.sock'))
        runtime, socket, proxy = [units[n].decode() for n in r['units']]
        self.assertIn('User=999\nGroup=999', runtime)
        self.assertIn('SocketUser=999\nSocketGroup=999', socket)
        self.assertIn('SocketMode=0600', socket)
        self.assertIn('User=1000\nGroup=1000', proxy)
        self.assertIn('serve-agent-operator-proxy', proxy)
        self.assertIn('--controller-uid 999', proxy)
        self.assertNotIn('User=root', runtime + proxy)
        self.assertIn('ReadWritePaths=', runtime)
        self.assertIn('RuntimeMaxSec=10800', runtime)

    def test_tool_uses_owned_exclusive_regular_request_file(self):
        r = self.record(); (self.root / 'tool-requests').mkdir(mode=0o700)
        args = self.file('arguments.json', b'{"family":"oracle-session"}')
        request = 'cd'*16
        calls = []
        def child(record, argv, setup=None):
            setup(); calls.append(argv); return 0
        with patch.object(c, 'load', return_value=({}, self.root, r)), patch.object(c, 'checked_units'), patch.object(c, 'controller_child', side_effect=child):
            self.assertEqual(c.tool(r['store'], '/unused', 'tool', request, ['mini_create_application_session', str(args)]), 0)
            with self.assertRaises(FileExistsError): c.tool(r['store'], '/unused', 'tool', request, ['mini_create_application_session', str(args)])
            with self.assertRaises(ValueError): c.tool(r['store'], '/unused', 'tool', 'wrong', ['mini_create_application_session', str(args)])
            with self.assertRaises(ValueError): c.tool(r['store'], '/unused', 'tool', 'ef'*16, ['shell', str(args)])
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][1:6], ['tool', str(self.root / 'state/control.sock'), 'soft', request, 'mini_create_application_session'])
        retained = self.root / 'tool-requests' / (request + '.args.json')
        self.assertEqual(retained.read_bytes(), args.read_bytes())
        self.assertEqual(stat.S_IMODE(retained.stat().st_mode), 0o600)

    def test_extended_acl_is_refused_without_mutating_other_users(self):
        path = self.file('public-endpoint')
        with patch.object(c, 'acl_text', return_value='user::rw-\nuser:123:rwx\ngroup::---\nmask::---\nother::---\n'), patch.object(c, 'run') as execute:
            with self.assertRaises(ValueError): c.grant_acl(path, 999, '-w-', self.uid)
            execute.assert_not_called()

    def test_empty_evidence_is_allowed_but_empty_source_is_not(self):
        p = self.file('empty', b'')
        with self.assertRaises(ValueError): c.read_file(p, self.uid, 100)
        self.assertEqual(c.read_file(p, self.uid, 100, allow_empty=True), b'')


if __name__ == '__main__':
    unittest.main()
