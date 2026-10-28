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
import subprocess
import sys
import tempfile
import unittest
from types import SimpleNamespace
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

    def test_runtime_and_child_pin_short_consent_anchor_directory(self):
        for version in (1, 2):
            with self.subTest(version=version):
                r = self.record() if version == 1 else self.consent_record()
                r['home'] = '/var/lib/mini-spk-worlds/abababababababab/controller/home'
                pins = None if version == 1 else {'providerSha256': '12'*32, 'configSha256': '34'*32,
                                                  'storage': {'writableParent': '/private/store-parent'}}
                units = c.unit_bytes(r, Path('/base'), Path('/operator.sock'), pins)
                self.assertIn('Environment=MINI_CONSENT_ANCHOR_DIR=' + r['home'] + '/a\n', units[r['units'][0]].decode())
                r['_consentEnvironment'] = {'MINI_CONSENT_ANCHOR_DIR': '/unwanted/override'}
                class SpawnObserved(Exception): pass
                with patch.object(c.subprocess, 'Popen', side_effect=SpawnObserved) as spawn:
                    with self.assertRaises(SpawnObserved): c.controller_child(r, ['/fixed/native'])
                    self.assertEqual(spawn.call_args.kwargs['env']['MINI_CONSENT_ANCHOR_DIR'], r['home'] + '/a')
                    self.assertEqual(spawn.call_args.kwargs['env']['MINI_CODEC_RESIDENT'], '0')
                    self.assertEqual(spawn.call_args.kwargs['env']['MINI_CONSENT_RESIDENT'], '0')
                self.assertNotIn('MINI_CODEC_RESIDENT=0', units[r['units'][0]].decode())

    def worker_record(self):
        r = self.consent_record(); r['workerTask'] = '9870001'
        r['units'] = c.names(r['store'], True, r['workerTask'])
        return r

    def worker_config_value(self, r):
        home = Path(r['home']); base = self.root / 'base'; root = home / 'grain'
        (home / 'keys').mkdir(mode=0o700, exist_ok=True)
        key = home / 'keys/hhost.key'; key.write_bytes(b'x' * 32); key.chmod(0o600)
        value = {'task': r['workerTask'], 'subject': '601', 'capability': '701', 'queryCapability': '701',
            'custodyKey': str(key), 'stateDir': str(root / 'state'), 'controlSocket': str(root / 'state/control.sock'),
            'cwd': str(root), 'mini': str(base / 'bin/mini'), 'host': str(base / 'bin/minidregg-host'),
            'hostConfig': str(home / 'host-config.json'), 'hostSocket': '/public/host.sock',
            'commands': [{'name': 'hermes-acp', 'program': str(base / 'worker/launcher/bwrap'),
                'args': ['--workspace', str(home / 'worker-work'), '--runtime-root', str(base / 'worker/runtime-root'),
                         '--network', 'none', '--', '/agent/hermes-acp'],
                'systemdScope': True, 'wallTimeSeconds': 1800, 'reserve': '3', 'charge': '1'}]}
        value['toolTask'] = {'task': '9870002', 'subject': '602', 'capability': '702', 'queryCapability': '702',
                             'custodyKey': str(key), 'parentCapability': '703', 'parentObserveCapability': '703'}
        return base, value

    def test_worker_paths_and_units_bind_task_and_private_native_environment(self):
        r = self.worker_record(); base = self.root / 'base'
        pins = {'providerSha256': '12'*32, 'configSha256': '34'*32, 'storage': {'writableParent': '/private/store'}}
        runtime = c.unit_bytes(r, base, Path('/operator.sock'), pins)[r['units'][0]].decode()
        self.assertEqual(r['units'][0], 'mini-grain-controller@9870001.service')
        self.assertIn(' serve ' + str(Path(r['home']) / 'grain/controller.json'), runtime)
        self.assertIn('MINI_GRAIN_CONTROLLER_MANAGER=system', runtime)
        self.assertIn('MINI_GRAIN_WORKER_MANAGER=user', runtime)
        self.assertIn('MINI_GRAIN_CONTROLLER_REGISTRATION=' + str(base / 'registrations/9870001.json'), runtime)
        self.assertIn('XDG_RUNTIME_DIR=/run/user/' + str(r['uid']), runtime)
        self.assertEqual(c.worker_state(r), Path(r['home']) / 'grain/state')
        self.assertEqual(c.worker_state(self.record()), Path(r['home']) / 'state')

    def test_worker_input_copy_rejects_escape_duplicates_and_store_destination(self):
        source = self.file('metadata.json', b'{}')
        request = {'protocol': 'mini-controller-worker-prepare-v1', 'task': '9870001',
                   'files': [{'source': str(source), 'destination': 'host-config.json'}], 'directories': ['bootstrap/namespace'],
                   'launcherDirectory': '/launcher', 'runtimeRoot': '/runtime'}
        data, directories = c.worker_inputs(request, self.uid)
        self.assertEqual(data, {'host-config.json': b'{}'})
        self.assertTrue({'bootstrap', 'bootstrap/namespace', 'grain', 'worker-work'} <= directories)
        for destination in ('../escape', 'keys/../escape', '/root/key', 'store/forward-link.sqlite3', 'bin/mini'):
            changed = {**request, 'files': [{'source': str(source), 'destination': destination}]}
            with self.subTest(destination=destination), self.assertRaises(ValueError): c.worker_inputs(changed, self.uid)
        with self.assertRaises(ValueError): c.worker_inputs({**request, 'files': request['files'] * 2}, self.uid)

    def test_worker_configuration_rejects_launcher_scope_or_custody_changes(self):
        r = self.worker_record(); base, config = self.worker_config_value(r)
        c.validate_worker_config(config, base, r)
        for field, value in (('program', '/bin/sh'), ('systemdScope', False), ('wallTimeSeconds', 1801)):
            changed = json.loads(json.dumps(config)); changed['commands'][0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError): c.validate_worker_config(changed, base, r)
        changed = {**config, 'custodyKey': str(self.root / 'sponsor.key')}
        with self.assertRaises(ValueError): c.validate_worker_config(changed, base, r)
        changed = {**config, 'subject': '999'}
        with self.assertRaises(ValueError): c.validate_worker_config(changed, base, r, config)

    def test_worker_command_executes_only_fixed_native_program_and_stages_after_drop(self):
        r = self.worker_record(); (self.root / 'requests').mkdir(mode=0o700)
        source = self.file('room-input.json', b'{"native":"data"}')
        request = {'program': 'mini', 'args': ['hermes-handoff', '--action', 'registration'],
                   'inputs': [{'source': str(source), 'destination': 'requests/room.json'}]}
        path = self.file('run.json', c.encoded(request))
        pins = {'providerSha256': '12'*32, 'configSha256': '34'*32}
        def child(record, argv, setup=None, timeout=None):
            self.assertEqual(argv[0], str(self.root / 'bin/mini'))
            self.assertFalse((self.root / 'requests/room.json').exists())
            self.assertEqual(record['uid'], self.uid)
            setup()
            self.assertEqual((self.root / 'requests/room.json').read_bytes(), source.read_bytes())
            return 0
        with patch.object(c, 'load', return_value=({}, self.root, r)), patch.object(c, 'checked_units', return_value={'consent': pins}), \
             patch.object(c, 'worker_manager'), patch.object(c, 'controller_child', side_effect=child) as execute:
            self.assertEqual(c.controller_run(r['store'], '/unused', str(path)), 0)
            request['program'] = '/bin/sh'; path.write_bytes(c.encoded(request))
            with self.assertRaises(ValueError): c.controller_run(r['store'], '/unused', str(path))
            self.assertEqual(execute.call_count, 1)

    def test_worker_runtime_copy_refuses_links_without_following_them(self):
        source = self.root / 'runtime-source'; source.mkdir(mode=0o700)
        secret = self.file('not-a-runtime-file', b'private')
        (source / 'escape').symlink_to(secret)
        with patch.object(c.os, 'chown'):
            with self.assertRaises((ValueError, OSError)):
                c.copy_worker_tree(source, self.root / 'copied-runtime', self.uid)
        self.assertEqual(secret.read_bytes(), b'private')
        self.assertEqual(list((self.root / 'copied-runtime').iterdir()), [])

    def test_birth_transfer_refuses_hardlinks_before_ownership_changes(self):
        root = self.root / 'birth'; root.mkdir(mode=0o700)
        artifact = root / 'call.bin'; artifact.write_bytes(b'exact'); artifact.chmod(0o600)
        os.link(artifact, root / 'alias')
        with patch.object(c.os, 'fchown') as change:
            with self.assertRaises(ValueError): c.transfer_birth_tree(root, self.uid, self.uid, self.gid)
            change.assert_not_called()
        (root / 'alias').unlink()
        c.transfer_birth_tree(root, self.uid, self.uid, self.gid)
        self.assertEqual(artifact.read_bytes(), b'exact')
        self.assertEqual(stat.S_IMODE(artifact.stat().st_mode), 0o600)

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

    def consent_record(self):
        r = self.record()
        r['protocol'] = 'mini-spk-controller-v2'
        r['units'] = c.names(r['store'], True)
        return r

    def test_v2_consent_units_keep_exact_pins_and_operator_boundary(self):
        r = self.consent_record(); r['uid'] = r['gid'] = 100032
        r['operatorUid'] = r['operatorGid'] = 1000
        pins = {'providerSha256': '12'*32, 'configSha256': '34'*32, 'storage':{'writableParent':'/private/store-parent'}}
        base = Path('/var/lib/mini-spk-worlds/abababababababab/controller')
        units = c.unit_bytes(r, base, Path('/operator/private.sock'), pins)
        runtime, _, _, listener, service = [units[n].decode() for n in r['units']]
        self.assertIn('User=1000\nGroup=1000', service)
        self.assertIn('SocketUser=100032', listener)
        self.assertIn('SocketMode=0600', listener)
        self.assertIn('--anchors ' + str(base / 'consent/anchors'), service)
        self.assertIn('ReadWritePaths=' + str(base / 'consent/anchors') + ' /private/store-parent\n', service)
        self.assertNotIn('ReadWritePaths=/operator', service)
        self.assertIn('--consent-sha256 ' + pins['providerSha256'], service)
        self.assertIn('--config-sha256 ' + pins['configSha256'], service)
        for key, value in c.consent_environment(r, base, pins).items():
            self.assertIn(f'Environment={key}={value}\n', runtime)
        self.assertIn('MINI_CONSENT_PEER_UID=0', runtime)
        self.assertNotIn('MINI_THIN_CONSENT', runtime)
        with self.assertRaises(ValueError): c.unit_bytes(r, base, Path('/operator/private.sock'))
        legacy = self.record()
        self.assertEqual(c.binary_names(legacy), c.BINS)
        self.assertEqual(len(c.unit_bytes(legacy, base, Path('/operator/private.sock'))), 3)
        self.assertEqual(c.consent_environment(legacy, base, {}), {})
        self.assertIn(c.CONSENT_BIN, c.binary_names(r))

    def test_v2_checks_both_config_copies_and_provider_before_use(self):
        r = self.consent_record()
        config = b'{"exact":"host-settings"}'
        binaries = {name: ('binary:' + name).encode() for name in c.binary_names(r)}
        unit_data = {name: ('unit:' + name).encode() for name in r['units']}
        stage = {'units': {n:c.sha(v) for n,v in unit_data.items()},
                 'binaries': {n:c.sha(v) for n,v in binaries.items()},
                 'consent': {'providerSha256':c.sha(binaries[c.CONSENT_BIN]), 'configSha256':c.sha(config)}}
        paths = {self.root/'stage.json':c.encoded(stage),
                 **{c.UNITS/n:v for n,v in unit_data.items()},
                 **{self.root/'bin'/n:v for n,v in binaries.items()},
                 self.root/'consent/config.json':config, self.root/'host-config.json':config}
        def read(path, owner, maximum, *args, **kwargs): return paths[path]
        with patch.object(c, 'read_file', side_effect=read), patch.object(c, 'metadata'):
            self.assertEqual(c.checked_units(self.root, r)['consent'], stage['consent'])
            for path in (self.root/'host-config.json', self.root/'consent/config.json',
                         self.root/'bin'/c.CONSENT_BIN):
                old = paths[path]; paths[path] = b'changed'
                with self.subTest(path=path), self.assertRaises(ValueError): c.checked_units(self.root, r)
                paths[path] = old

    def test_v2_readiness_does_not_claim_native_admission(self):
        r = self.consent_record()
        pins = {'providerSha256':'12'*32,'configSha256':'34'*32}
        record = c.consent_record(self.root, r, {'consent':pins, 'binaries':{'mini':'56'*32}})
        self.assertEqual(record['serviceUid'], r['operatorUid'])
        self.assertEqual(record['controllerUid'], r['uid'])
        self.assertEqual(record['activationPeerUid'], 0)
        with patch.object(c, 'manager_properties', return_value={'ActiveState':'failed','MainPID':'0'}):
            with self.assertRaises(ValueError): c.consent_readiness(self.root, r, {'consent':pins, 'binaries':{'mini':'56'*32}})

    def test_consent_readiness_binds_process_identity_and_actual_socket_mode(self):
        r = self.consent_record(); pins = {'providerSha256':'12'*32,'configSha256':'34'*32}
        (self.root/'bin').mkdir(); executable = self.file('bin/mini', b'fixed-mini', 0o700)
        (self.root/'consent').mkdir(mode=0o700)
        listener = c.socket.socket(c.socket.AF_UNIX, c.socket.SOCK_STREAM)
        listener.bind(str(self.root/'consent/peer.sock')); self.addCleanup(listener.close)
        (self.root/'consent/peer.sock').chmod(0o600)
        process = Path('/proc/12345')
        identity = {'uid':self.uid}
        observed = {'ActiveState':'active','MainPID':'12345','InvocationID':'ab'*16}
        original_stat, original_text = Path.stat, Path.read_text
        def stat_path(path, *args, **kwargs):
            if path == process: return SimpleNamespace(st_uid=identity['uid'])
            if path == process/'exe': return original_stat(executable)
            return original_stat(path, *args, **kwargs)
        def text_path(path, *args, **kwargs):
            if path == process/'stat': return '12345 (mini) ' + ' '.join(['S'] + ['0']*18 + ['789'])
            return original_text(path, *args, **kwargs)
        with patch.object(c, 'manager_properties', return_value=observed), \
                patch.object(Path, 'stat', stat_path), patch.object(Path, 'read_text', text_path):
            ready = c.consent_readiness(self.root, r, {'consent':pins, 'binaries':{'mini':'56'*32}})
            self.assertEqual(ready['processStartTicks'], 789)
            self.assertEqual(ready['readiness'], 'process-and-socket-only')
            self.assertFalse(ready['independentAdmissionObserved'])
            identity['uid'] = self.uid + 1000
            with self.assertRaises(ValueError): c.consent_readiness(self.root, r, {'consent':pins, 'binaries':{'mini':'56'*32}})
            identity['uid'] = self.uid
            (self.root/'consent/peer.sock').chmod(0o666)
            with self.assertRaises(ValueError): c.consent_readiness(self.root, r, {'consent':pins, 'binaries':{'mini':'56'*32}})

    def test_v2_config_update_cannot_retarget_consent_settings(self):
        r = self.consent_record()
        data = {'commands':[], 'stateDir':str(self.root/'state'),
                'controlSocket':str(self.root/'state/control.sock'), 'cwd':str(self.root/'workspace'),
                'hostConfig':'/unrelated/settings.json'}
        source = self.file('next.json', c.encoded(data))
        with patch.object(c, 'load', return_value=({},self.root,r)), patch.object(c, 'checked_units'), patch.object(c, 'no_processes'):
            with self.assertRaisesRegex(ValueError, 'consent-bound'):
                c.config_update(r['store'], '/unused', str(source))

    def test_consent_archive_preserves_partial_initialization_and_refuses_drift(self):
        r = self.consent_record()
        source = self.root/'consent/anchors'; source.mkdir(parents=True, mode=0o700)
        (source/'binding').write_bytes(b'fixed-binding'); (source/'binding').chmod(0o600)
        (source/'lock').write_bytes(b''); (source/'lock').chmod(0o600)
        history = self.root/'history'; history.mkdir(mode=0o700)
        original_read, original_mkdir, original_write = c.read_file, c.mkdir, c.write_new
        def read(path, owner, *args, **kwargs): return original_read(path, self.uid, *args, **kwargs)
        def mkdir(path, *args, **kwargs): return original_mkdir(path, self.uid, self.gid, kwargs.get('mode', 0o700))
        def write(path, data, *args, **kwargs): return original_write(path, data, self.uid, self.gid)
        original_meta = c.metadata
        def meta(path, owner=None, mode=None): return original_meta(path, self.uid if owner == 0 else owner, mode)
        with patch.object(c, 'HISTORY', history), patch.object(c, 'ancestry'), patch.object(c, 'metadata', side_effect=meta), \
                patch.object(c, 'read_file', side_effect=read), patch.object(c, 'mkdir', side_effect=mkdir), patch.object(c, 'write_new', side_effect=write):
            receipt = c.preserve_consent_state(self.root, r)
            self.assertEqual(set(receipt['files']), {'binding','lock'})
            self.assertEqual((Path(receipt['directory'])/'binding').read_bytes(), b'fixed-binding')
            self.assertEqual(c.preserve_consent_state(self.root, r), receipt)
            (source/'binding').write_bytes(b'changed-binding')
            with self.assertRaises(ValueError): c.preserve_consent_state(self.root, r)
            (source/'unknown').write_bytes(b'unknown')
            with self.assertRaises(ValueError): c.preserve_consent_state(self.root, r)
        self.assertIsNone(c.preserve_consent_state(self.root, self.record()))

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

    def registry_value(self, store='ab'*8):
        return {'protocol':'mini-spk-volume-registry-v1','store':store,'deploymentId':'cd'*32,'hostId':'ef'*32,
                'grainsRoot':str(c.WORLDS/store),'operatorUid':1000,'operatorGid':1000,'appUids':[100000,100001],
                'helper':'/usr/local/libexec/mini-spk-volume-helper','helperSha256':'12'*32}

    def reservation_value(self, store='ab'*8):
        return {'protocol':'mini-spk-controller-namespace-v1','store':store,'deploymentId':'cd'*32,'hostId':'ef'*32,
                'operatorUid':1000,'operatorGid':1000,'controllerUid':100032,'controllerGid':100032,'account':'mini-c-'+store}

    def test_subordinate_intersection_excludes_other_principals_and_numeric_aliases(self):
        raw = b'operator:100000:16\n1000:100016:16\nother:100004:2\n9999:100020:2\n'
        def passwd(name):
            if name == 'operator': return SimpleNamespace(pw_uid=1000)
            if name == 'other': return SimpleNamespace(pw_uid=2000)
            raise KeyError(name)
        with patch.object(c, 'read_file', return_value=raw), patch.object(c.pwd, 'getpwnam', side_effect=passwd):
            own, foreign = c.subordinate_ranges(Path('/etc/subuid'), 1000)
        self.assertEqual(own, [(100000,100032)])
        self.assertEqual(foreign, [(100004,100006),(100020,100022)])
        self.assertEqual(c.intersection(own,[(100008,100024)]),[(100008,100024)])
        self.assertFalse(c.in_ranges(100032,own))

    def test_subordinate_malformed_and_overflow_rows_fail_closed(self):
        for raw in [b'1000:1:0', b'1000:4294967294:2', b'1000:100000:no', b'1000:100000:1:extra']:
            with self.subTest(raw=raw), patch.object(c,'read_file',return_value=raw), self.assertRaises(ValueError):
                c.subordinate_ranges(Path('/etc/subuid'),1000)

    def test_allocator_skips_app_tombstone_foreign_and_nss_ids(self):
        with patch.object(c,'occupied_ids',return_value={100000,100001}), \
             patch.object(c,'delegated',return_value=([(100000,100008)],[(100002,100004)])), \
             patch.object(c,'nss_ids',return_value={100004}) as snapshot, patch.object(c,'delegation_owners',return_value=(set(),set())), \
             patch.object(c,'nss_free',side_effect=lambda identity, used: identity not in used):
            self.assertEqual(c.allocate_identity(1000,"mini-c-"+"ab"*8),100005)
            snapshot.assert_called_once_with()
        with patch.object(c,'occupied_ids',return_value={100000,100001}), \
             patch.object(c,'delegated',return_value=([(100000,100002)],[])), patch.object(c,'nss_ids',return_value=set()),patch.object(c,'delegation_owners',return_value=(set(),set())):
            with self.assertRaises(ValueError): c.allocate_identity(1000,"mini-c-"+"ab"*8)

    def test_controller_cannot_inherit_stale_subordinate_grants(self):
        with patch.object(c,'occupied_ids',return_value=set()),patch.object(c,'delegated',return_value=([(100000,100004)],[])), \
             patch.object(c,'nss_ids',return_value=set()),patch.object(c,'nss_free',return_value=True), \
             patch.object(c,'delegation_owners',return_value=({'mini-c-'+ 'ab'*8},set())):
            with self.assertRaisesRegex(ValueError,'already has subordinate grants'): c.allocate_identity(1000,'mini-c-'+'ab'*8)
        with patch.object(c,'occupied_ids',return_value=set()),patch.object(c,'delegated',return_value=([(100000,100004)],[])), \
             patch.object(c,'nss_ids',return_value=set()),patch.object(c,'nss_free',return_value=True), \
             patch.object(c,'delegation_owners',return_value=(set(),{100000,100001})):
            self.assertEqual(c.allocate_identity(1000,'mini-c-'+'ab'*8),100002)

    def test_root_identity_schema_duplicates_and_alias_shapes_refuse(self):
        c.namespace_record(self.reservation_value())
        for key,value in [('controllerUid',65534),('controllerGid',2**32-1),('operatorUid',True),('account','another')]:
            r=self.reservation_value();r[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):c.namespace_record(r)
        with self.assertRaises(ValueError):c.strict_json(b'{"controllerUid":100032,"controllerUid":100033}')

    def test_permanent_reservation_survives_world_removal_and_blocks_app_allocation(self):
        root=self.root; registry=root/'registry'; reservations=root/'reservations'; history=root/'history'
        for p in (registry,reservations,history):p.mkdir(mode=0o700)
        with patch.object(c,'REGISTRY',registry),patch.object(c,'RESERVATIONS',reservations),patch.object(c,'HISTORY',history):
            world=registry/('ab'*8+'.json');reservation=reservations/('ab'*8+'.json')
            world.write_text(json.dumps(self.registry_value()));reservation.write_text(json.dumps(self.reservation_value()))
            def listing(directory):return sorted(directory.glob('*.json'))
            with patch.object(c,'bounded_json_paths',side_effect=listing),patch.object(c,'read_file',side_effect=lambda p,*a,**k:p.read_bytes()):
                self.assertIn(100032,c.occupied_ids())
                world.unlink() # Tombstone remains authoritative after ordinary world cleanup.
                self.assertIn(100032,c.occupied_ids())
                reservation.write_text('{"protocol":"broken"}')
                with self.assertRaises(ValueError):c.occupied_ids()
        with patch.object(c,'occupied_ids',return_value={100032}),patch.object(c,'delegated',return_value=([(100000,165536)],[])), \
             patch.object(c,'nss_ids',return_value=set()),patch.object(c,'nss_free',return_value=True),patch.dict(c.os.environ,{'SUDO_UID':'1000'}):
            with self.assertRaises(ValueError):c.check_app_allocation('cd'*8,'/usr/local/libexec/mini-spk-volume-helper','1000','100032','2')

    def test_pending_allocation_without_reservation_refuses(self):
        registry=self.root/'registry';registry.mkdir();worlds=self.root/'worlds';worlds.mkdir()
        controller=worlds/('ab'*8)/'controller';controller.mkdir(parents=True)
        with patch.object(c,'REGISTRY',registry),patch.object(c,'WORLDS',worlds):
            record=registry/('ab'*8+'.json');record.write_text(json.dumps(self.registry_value()))
            with patch.object(c,'bounded_json_paths',side_effect=lambda directory:[record] if directory==registry else []), \
                 patch.object(c,'read_file',side_effect=lambda p,*a,**k:p.read_bytes()),patch.object(c,'ancestry'):
                with self.assertRaisesRegex(ValueError,'lacks permanent'):c.occupied_ids()

    def test_reservation_is_durable_before_account_creation_failure(self):
        base=self.root/'controller';reservations=self.root/'reservations';events=[]
        registry=self.registry_value()
        def write(path,data,uid=0,gid=0,mode=0o600):
            path.write_bytes(data);path.chmod(mode)
            if path.parent==reservations:events.append('reserved')
        def directory(path,uid=0,gid=0,mode=0o700):path.mkdir(mode=mode)
        def command(args,**kwargs):
            events.append(Path(args[0]).name)
            if args[0]=='/usr/sbin/useradd':raise ValueError('injected account creation failure')
        with patch.object(c,'store_context',return_value=(registry,base)),patch.object(c,'RESERVATIONS',reservations), \
             patch.object(c,'HISTORY',self.root/'history'),patch.object(c,'allocate_identity',return_value=100032), \
             patch.object(c.pwd,'getpwall',return_value=[]),patch.object(c.grp,'getgrall',return_value=[]), \
             patch.object(c,'mkdir',side_effect=directory),patch.object(c,'write_new',side_effect=write), \
             patch.object(c,'ancestry'),patch.object(c,'account_defaults'),patch.object(c,'run',side_effect=command):
            with self.assertRaisesRegex(ValueError,'injected'):c.create('ab'*8,registry['helper'])
        self.assertEqual(events,['reserved','groupadd','useradd'])
        self.assertTrue((reservations/('ab'*8+'.json')).exists())
        self.assertTrue((base/'pending.json').exists())
        self.assertFalse((base/'namespace.json').exists())

    def test_useradd_uses_system_account_contract_without_invalid_defaults_keys(self):
        with patch.object(c,'run',return_value=SimpleNamespace(stdout=b'CREATE_MAIL_SPOOL=no\nGROUPS=\n')):
            c.account_defaults()
        for raw in (b'CREATE_MAIL_SPOOL=yes\n', b'CREATE_MAIL_SPOOL=no\nGROUPS=operators\n',
                    b'CREATE_MAIL_SPOOL=no\nCREATE_MAIL_SPOOL=yes\n', b'GROUPS=\n'):
            with self.subTest(raw=raw), patch.object(c,'run',return_value=SimpleNamespace(stdout=raw)):
                with self.assertRaises(ValueError): c.account_defaults()
        with patch.object(c,'run') as execute, patch.object(c,'delegation_owners',return_value=(set(),set())):
            c.create_account(self.root, 'mini-c-'+'ab'*8, 100032)
        args = execute.call_args.args[0]
        self.assertEqual(args, ['/usr/sbin/useradd','--system','--uid','100032','--gid','100032',
                               '--no-user-group','--no-create-home','--no-log-init',
                               '--home-dir',str(self.root/'home'),'--shell','/usr/sbin/nologin','mini-c-'+'ab'*8])
        with patch.object(c,'run'), patch.object(c,'delegation_owners',return_value=({'mini-c-'+'ab'*8},set())):
            with self.assertRaises(ValueError): c.create_account(self.root, 'mini-c-'+'ab'*8, 100032)

    def test_pending_resume_binds_exact_group_intent_and_exclusive_delegation(self):
        registry, reservation = self.registry_value(), self.reservation_value()
        name, identity = reservation['account'], reservation['controllerUid']
        base = self.root/'pending-controller'; base.mkdir(mode=0o755)
        pending = {'store':registry['store'],'name':name,'operatorUid':registry['operatorUid']}
        (base/'pending.json').write_bytes(c.encoded(pending))
        (base/'lifecycle.lock').write_bytes(b'controller lifecycle lock\n')
        reservation_path = c.RESERVATIONS/(registry['store']+'.json')
        group = SimpleNamespace(gr_name=name,gr_gid=identity,gr_mem=[])
        def read(path,*args,**kwargs):
            return c.encoded(reservation) if path == reservation_path else path.read_bytes()
        with c.contextlib.ExitStack() as stack:
            for owner, attr, kwargs in [
                (c,'ancestry',{}),(c,'metadata',{}),(c,'read_file',{'side_effect':read}),
                (c,'occupied_ids',{'return_value':{identity}}),
                (c,'delegated',{'return_value':([(100000,165536)],[])}),
                (c,'delegation_owners',{'return_value':(set(),set())}),
                (c.pwd,'getpwall',{'return_value':[]}), (c.pwd,'getpwnam',{'side_effect':KeyError(name)}),
                (c.pwd,'getpwuid',{'side_effect':KeyError(identity)}),
                (c.grp,'getgrall',{'return_value':[group]}), (c.grp,'getgrnam',{'return_value':group}),
                (c.grp,'getgrgid',{'return_value':group}), (c,'no_processes',{}),
                (c,'manager_properties',{'return_value':{'LoadState':'not-found'}}),
                (c,'HISTORY',{'new':self.root/'history'}),(c,'UNITS',{'new':self.root/'units'})]:
                stack.enter_context(patch.object(owner,attr,**kwargs))
            self.assertEqual(c.pending_create_identity(registry,base), reservation)
            foreign = SimpleNamespace(gr_name='foreign',gr_gid=identity,gr_mem=[])
            for groups in ([foreign],[group,foreign],[SimpleNamespace(gr_name=name,gr_gid=identity,gr_mem=['foreign'])]):
                with patch.object(c.grp,'getgrall',return_value=groups), self.assertRaises(ValueError):
                    c.pending_create_identity(registry,base)
            for own, foreign_ranges in (([],[]), ([(100000,165536)],[(identity,identity+1)])):
                with patch.object(c,'delegated',return_value=(own,foreign_ranges)), self.assertRaises(ValueError):
                    c.pending_create_identity(registry,base)
            with patch.object(c.pwd,'getpwuid',return_value=SimpleNamespace(pw_uid=identity)), self.assertRaises(ValueError):
                c.pending_create_identity(registry,base)
            with patch.object(c,'no_processes',side_effect=ValueError('live identity')), self.assertRaises(ValueError):
                c.pending_create_identity(registry,base)
            with patch.object(c,'manager_properties',return_value={'LoadState':'loaded'}), self.assertRaises(ValueError):
                c.pending_create_identity(registry,base)
            reservation['hostId'] = '00'*32
            with self.assertRaises(ValueError): c.pending_create_identity(registry,base)
            reservation['hostId'] = registry['hostId']
            (base/'pending.json').write_bytes(c.encoded({**pending,'operatorUid':2000}))
            with self.assertRaises(ValueError): c.pending_create_identity(registry,base)
            (base/'pending.json').write_bytes(c.encoded(pending))
            (base/'home').mkdir()
            with self.assertRaises(ValueError): c.pending_create_identity(registry,base)

    def test_resume_reuses_reserved_identity_without_allocation_or_group_creation(self):
        registry, reservation = self.registry_value(), self.reservation_value()
        events = []
        with patch.object(c,'store_context',return_value=(registry,self.root)), \
             patch.object(c,'pending_create_identity',return_value=reservation), patch.object(c,'account_defaults'), \
             patch.object(c,'allocate_identity') as allocate, patch.object(c,'run') as direct_command, \
             patch.object(c,'create_account',side_effect=lambda *args:events.append(args)), \
             patch.object(c,'finish_create',return_value={'controllerUid':reservation['controllerUid']}) as finish:
            result = c.resume_create(registry['store'],registry['helper'])
        allocate.assert_not_called(); direct_command.assert_not_called()
        self.assertEqual(events,[(self.root,reservation['account'],reservation['controllerUid'])])
        finish.assert_called_once_with(registry,self.root,reservation)
        self.assertTrue(result['resumedPendingCreation'])

    def test_controller_export_accepts_normal_history_and_caps_4096_files(self):
        state=self.root/'state';state.mkdir(mode=0o700)
        r={'home':str(self.root),'uid':self.uid}
        with patch.object(c,'load',return_value=(None,self.root,r)),patch.object(c,'checked_units'):
            for i in range(513):(state/str(i)).write_bytes(b'evidence')
            self.assertEqual(len(c.export_state('fixture','/unused')['files']),513)
            for i in range(513,4096):(state/str(i)).write_bytes(b'evidence')
            self.assertEqual(len(c.export_state('fixture','/unused')['files']),4096)
            (state/'4096').write_bytes(b'evidence')
            with self.assertRaisesRegex(ValueError,'file bound'):c.export_state('fixture','/unused')

    def test_controller_export_retains_byte_file_and_depth_bounds(self):
        state=self.root/'state';state.mkdir(mode=0o700);r={'home':str(self.root),'uid':self.uid}
        with patch.object(c,'load',return_value=(None,self.root,r)),patch.object(c,'checked_units'):
            oversized=state/'oversized'
            with oversized.open('wb') as f:f.truncate(8*1024*1024+1)
            with self.assertRaisesRegex(ValueError,'mode/size'):c.export_state('fixture','/unused')
            oversized.unlink()
            for i in range(5):(state/str(i)).write_bytes(b'budget fixture')
            with patch.object(c,'read_file',return_value=b'x'*(8*1024*1024)):
                with self.assertRaisesRegex(ValueError,'byte bound'):c.export_state('fixture','/unused')
            for p in state.iterdir():p.unlink()
            nested=state
            for _ in range(17):nested=nested/'d';nested.mkdir()
            with self.assertRaisesRegex(ValueError,'directory bound'):c.export_state('fixture','/unused')

    def test_controller_export_directory_count_stays_bounded(self):
        state=self.root/'state';state.mkdir(mode=0o700);r={'home':str(self.root),'uid':self.uid}
        with patch.object(c,'load',return_value=(None,self.root,r)),patch.object(c,'checked_units'):
            for i in range(1023):(state/str(i)).mkdir()
            self.assertEqual(c.export_state('fixture','/unused')['files'],{})
            (state/'1023').mkdir()
            with self.assertRaisesRegex(ValueError,'directory bound'):c.export_state('fixture','/unused')

    def test_exact_reserve_export_has_eight_files_and_no_custody(self):
        r=self.record();prefix='agent-lifetime-reserve-0000000000000042'
        (self.root/'state').mkdir(mode=0o700)
        path=self.root/'state'/prefix;path.mkdir(mode=0o700)
        names=('source.json','pin.json','request.bin','plan.bin','plan.frame','call.bin','receipt.json','submit-marker.json')
        for n in names:
            p=path/n;p.write_bytes(n.encode());p.chmod(0o600)
        (path/'not-exported.key').write_bytes(b'not evidence')
        with patch.object(c,'load',return_value=({},self.root,r)):
            result=c.reserve_export(r['store'],'/unused','42')
            for bad in ['-1','00','../42',str(2**64)]:
                with self.assertRaises(ValueError):c.reserve_export(r['store'],'/unused',bad)
        self.assertEqual(set(result['files']),{prefix+'/'+n for n in names})
        for n in names:self.assertEqual(result['files'][prefix+'/'+n]['sha256'],hashlib.sha256(n.encode()).hexdigest())

    def test_service_logs_use_only_recorded_services_and_observed_invocations(self):
        r = self.consent_record(); r['uid'] = 100032; r['operatorUid'] = 1000
        stage = {'units':{n:'recorded' for n in r['units']}}
        def observed(unit):
            return {'LoadState':'loaded','FragmentPath':str(c.UNITS/unit),'Transient':'no',
                    'User':str(r['uid'] if unit == r['units'][0] else r['operatorUid']),
                    'InvocationID':'ab'*16 if unit == r['units'][0] else ''}
        with patch.object(c,'load',return_value=({},self.root,r)), patch.object(c,'checked_units',return_value=stage), \
                patch.object(c,'manager_properties',side_effect=observed), patch.object(c,'bounded_service_journal',return_value=b'private journal\n') as journal:
            result=c.service_logs(r['store'],'/unused')
        self.assertEqual([row['unit'] for row in result['services']], [n for n in r['units'] if n.endswith('.service')])
        self.assertEqual(journal.call_args_list[0].args,(r['units'][0],'ab'*16))
        self.assertEqual(result['services'][0]['selection'],'observed-invocation')
        self.assertEqual(result['services'][1]['selection'],'fixed-unit-recent-history')
        self.assertTrue(result['privateEvidence'])
        with patch.object(c,'load',return_value=({},self.root,r)), patch.object(c,'checked_units',return_value=stage), \
                patch.object(c,'manager_properties',return_value={**observed(r['units'][0]),'User':'0'}), \
                patch.object(c,'bounded_service_journal') as journal:
            with self.assertRaises(ValueError):c.service_logs(r['store'],'/unused')
            journal.assert_not_called()

    def test_service_journal_output_bound_and_owned_child_reap(self):
        spawn=subprocess.Popen; children=[]; calls=[]
        def child(args,**kwargs):
            calls.append(args)
            process=spawn([sys.executable,'-c','import sys; sys.stdout.buffer.write(b"x" * 1048577)'],**kwargs)
            children.append(process);return process
        with patch.object(c.subprocess,'Popen',side_effect=child):
            with self.assertRaisesRegex(ValueError,'1 MiB'):c.bounded_service_journal('fixed.service','ab'*16)
        self.assertTrue(all(process.poll() is not None for process in children))
        self.assertEqual(calls[0],['/usr/bin/journalctl','--quiet','--no-pager','--lines=256',
                                  '--output=short-iso-precise','--unit=fixed.service','_SYSTEMD_INVOCATION_ID='+'ab'*16])
        with patch.object(c.subprocess,'Popen') as start:
            with self.assertRaises(ValueError):c.bounded_service_journal('fixed.service','bad invocation')
            start.assert_not_called()

    def storage_fixture(self, parent):
        parent.mkdir(mode=0o700)
        root=parent/'store';root.mkdir(mode=0o700)
        for path,data in ((root/'forward-link.sqlite3',b'database fixture'),
                          (parent/'store.head-anchor',b'MINIANC2'+b'a'*112),
                          (parent/'store.head-anchor.lock',b'')):
            path.write_bytes(data);path.chmod(0o600)
        return c.encoded({'storageRoot':str(root)})

    def test_storage_pins_reject_replacements_but_allow_atomic_anchor_advance(self):
        settings=self.storage_fixture(self.root/'store-parent')
        expected=c.consent_storage(settings,self.uid)
        root=Path(expected['root']);anchor=Path(expected['replaceableAnchor'])
        new=anchor.with_name('next');new.write_bytes(b'MINIANC2'+b'b'*112);new.chmod(0o600);new.replace(anchor)
        self.assertEqual(c.consent_storage(settings,self.uid),expected)
        for path in (root/'forward-link.sqlite3',Path(str(root)+'.head-anchor.lock')):
            data=path.read_bytes();new=path.with_name(path.name+'.next');new.write_bytes(data);new.chmod(0o600);new.replace(path)
            self.assertNotEqual(c.consent_storage(settings,self.uid),expected)
            expected=c.consent_storage(settings,self.uid)
        original=root.parent; moved=original.with_name('renamed-parent');original.rename(moved)
        original.symlink_to(moved,target_is_directory=True)
        with self.assertRaises(ValueError):c.consent_storage(settings,self.uid)
        original.unlink();moved.rename(original)
        anchor.chmod(0o644)
        with self.assertRaises(ValueError):c.consent_storage(settings,self.uid)
        for path in ('/tmp/x\nReadWritePaths=/', '/tmp/%h/store', '/tmp/../store'):
            with self.assertRaises(ValueError):c.consent_storage(c.encoded({'storageRoot':path}),self.uid)

    @c.contextlib.contextmanager
    def storage_upgrade_fixture(self, suffix=''):
        base=self.root/('upgrade-controller'+suffix);base.mkdir(mode=0o700)
        home=base/'home';home.mkdir(mode=0o700)
        for p in (base/'bin',base/'configs',base/'consent',base/'consent/anchors'):
            p.mkdir(mode=0o700)
        units=self.root/('units'+suffix);units.mkdir(mode=0o700)
        settings=self.storage_fixture(self.root/('upgrade-store-parent'+suffix))
        r=self.consent_record();r['home']=str(home)
        binaries={n:('fixture:'+n).encode() for n in c.binary_names(r)}
        pins={'providerSha256':c.sha(binaries[c.CONSENT_BIN]),'configSha256':c.sha(settings)}
        storage=c.consent_storage(settings,self.uid)
        files=c.unit_bytes(r,base,Path('/operator/private.sock'),{**pins,'storage':storage})
        unit=r['units'][4]
        files[unit]=files[unit].replace((' '+storage['writableParent']+'\n').encode(),b'\n')
        for n,data in files.items():
            p=units/n;p.write_bytes(data);p.chmod(0o644)
        for n,data in binaries.items():
            p=base/'bin'/n;p.write_bytes(data);p.chmod(0o755)
        for p in (base/'consent/config.json',home/'host-config.json'):
            p.write_bytes(settings);p.chmod(0o600)
        stage={'units':{n:c.sha(data) for n,data in files.items()},
               'binaries':{n:c.sha(data) for n,data in binaries.items()},'consent':pins}
        stage_raw=c.encoded(stage);(base/'stage.json').write_bytes(stage_raw);(base/'stage.json').chmod(0o600)
        original_read,original_write,original_publish=c.read_file,c.write_new,c.publish_exact
        def publish(path,data,uid=0,gid=0,mode=0o600,bound=65536):return original_publish(path,data,self.uid if uid==0 else uid,self.gid if gid==0 else gid,mode,bound)
        def read(path,owner,*args,**kwargs):return original_read(path,self.uid if owner==0 else owner,*args,**kwargs)
        def write(path,data,uid=0,gid=0,mode=0o600):return original_write(path,data,self.uid if uid==0 else uid,self.gid if gid==0 else gid,mode)
        def manager(unit):return {'LoadState':'loaded','Transient':'no','FragmentPath':str(units/unit),
                                  'ActiveState':'inactive','MainPID':'0','ControlPID':'0','User':str(self.uid)}
        with patch.object(c,'load',return_value=({},base,r)),patch.object(c,'UNITS',units), \
             patch.object(c,'no_processes'),patch.object(c,'manager_properties',side_effect=manager), \
             patch.object(c,'read_file',side_effect=read),patch.object(c,'write_new',side_effect=write),patch.object(c,'publish_exact',side_effect=publish),patch.object(c,'run'):
            yield base,r,units,stage_raw,files[unit]

    @c.contextlib.contextmanager
    def public_listener_fixture(self, suffix=''):
        with self.storage_upgrade_fixture(suffix) as (base,r,units,raw,service):
            parent=self.root/('participant'+suffix);parent.mkdir(mode=0o710)
            public=parent/'host.sock';(parent/'host.lock').write_bytes(b'');(parent/'host.lock').chmod(0o600)
            newbin=self.file('new-mini'+suffix,b'qualified public mini',0o700)
            stage=json.loads(raw);stage['publicSocket']=str(public);stage['acl']=[]
            after='user::rwx\nuser:'+str(r['uid'])+':--x\ngroup::---\nmask::--x\nother::---\n\n'
            before='user::rwx\ngroup::---\nother::---\n\n'
            for i,target in enumerate((parent,public),1):
                m=parent.stat();intent={'path':str(target),'dev':m.st_dev,'ino':m.st_ino if target==parent else 999,'before':before}
                entry={**intent,'after':after}
                c.publish_exact(base/f'acl-{i:03}.json',c.encoded(intent))
                c.publish_exact(base/f'acl-{i:03}.after.json',c.encoded(entry));stage['acl'].append(entry)
            (base/'stage.json').write_bytes(c.encoded(stage))
            config=b'{"fixed":"controller"}'
            (base/'home/controller.json').write_bytes(config);(base/'home/controller.json').chmod(0o600)
            c.publish_exact(base/'configs'/(c.sha(config)+'.json'),config)
            (base/'home/bin').mkdir(mode=0o700)
            runtime=base/'home/bin/grain-runtime';runtime.write_bytes((base/'bin/grain-runtime').read_bytes());runtime.chmod(0o500)
            original_metadata=c.metadata
            def metadata(path,owner=None,mode=None):
                return original_metadata(path,self.uid if owner==0 else owner,mode)
            def mkdir(path,uid=0,gid=0,mode=0o700):
                path.mkdir(mode=mode);path.chmod(mode)
            with patch.object(c,'load',return_value=({'operatorGid':self.gid},base,r)), \
                 patch.object(c,'metadata',side_effect=metadata),patch.object(c,'mkdir',side_effect=mkdir), \
                 patch.object(c,'acl_text',return_value=after):
                yield base,r,stage,public,newbin,after

    def test_public_listener_register_is_separate_exact_and_restart_safe(self):
        with self.public_listener_fixture() as (base,r,stage,public,binary,after):
            old=(base/'stage.json').read_bytes();client=(base/'bin/mini').read_bytes()
            status=c.register_public_listener(r['store'],'helper',str(binary))
            self.assertTrue(status['stopped']);self.assertEqual(status['stageSha256'],c.sha(old))
            self.assertEqual(status['consent'],stage['consent'])
            self.assertEqual(status['publicListener']['binarySha256'],c.sha(binary.read_bytes()))
            self.assertEqual(public.with_suffix('.controller').read_bytes(),c.listener_pin(r))
            self.assertEqual((base/'stage.json').read_bytes(),old);self.assertEqual((base/'bin/mini').read_bytes(),client)
            self.assertEqual(c.register_public_listener(r['store'],'helper',str(binary)),status)
            binary.write_bytes(b'other binary')
            with self.assertRaises(ValueError):c.register_public_listener(r['store'],'helper',str(binary))

    def test_public_listener_upgrade_recovers_exact_record_and_binary_boundaries(self):
        for fail_at in (1,2,3,4,5,6,7):
            with self.subTest(fail_at=fail_at),self.public_listener_fixture('upgrade'+str(fail_at)) as (base,r,stage,public,binary,after):
                prior=c.register_public_listener(r['store'],'helper',str(binary))
                old=binary.read_bytes(); old_sha=c.sha(old)
                binary.write_bytes(b'new opcode55 qualified mini'); new_sha=c.sha(binary.read_bytes())
                publish=c.publish_exact; calls=[0]
                def interrupted(*args,**kwargs):
                    calls[0]+=1
                    if calls[0]==fail_at:raise OSError('publication interrupted')
                    return publish(*args,**kwargs)
                with patch.object(c,'publish_exact',side_effect=interrupted):
                    with self.assertRaises(OSError):c.upgrade_public_listener(r['store'],'helper',str(binary),old_sha,new_sha)
                result=c.upgrade_public_listener(r['store'],'helper',str(binary),old_sha,new_sha)
                self.assertEqual(result['publicListener']['binarySha256'],new_sha)
                self.assertEqual((base/'public-listener'/(old_sha+'.binary')).read_bytes(),old)
                self.assertEqual({k:v for k,v in result['publicListener'].items() if k!='binarySha256'},
                                 {k:v for k,v in prior['publicListener'].items() if k!='binarySha256'})
                self.assertEqual(c.upgrade_public_listener(r['store'],'helper',str(binary),old_sha,new_sha),result)
                with self.assertRaises(ValueError):c.upgrade_public_listener(r['store'],'helper',str(binary),'0'*64,new_sha)

    def test_recover_session_only_invokes_fixed_private_admin_command(self):
        r=self.consent_record();base=self.root/'controller';r['home']=str(base/'home')
        request='ab'*16
        with patch.object(c,'load',return_value=({},base,r)),patch.object(c,'checked_units'),patch.object(c,'controller_child',return_value=0) as child:
            self.assertEqual(c.recover_session(r['store'],'helper',request),0)
            args=child.call_args
            self.assertEqual(args.args[1],[str(base/'bin/grain-runtime'),'admin',str(base/'home/state/admin.sock'),'recover foreground session '+request])
            self.assertEqual(args.kwargs,{'timeout':1800})
            for bad in ('',request+'; quit','AB'*16,'../request'):
                with self.assertRaises(ValueError):c.recover_session(r['store'],'helper',bad)
            self.assertEqual(child.call_count,1)

    def test_public_listener_refuses_busy_lock_live_socket_and_changed_custody(self):
        with self.public_listener_fixture() as (base,r,stage,public,binary,after):
            with open(public.with_suffix('.lock'),'rb') as lock:
                fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
                with self.assertRaises(BlockingIOError):c.register_public_listener(r['store'],'helper',str(binary))
            public.write_bytes(b'not an owned socket')
            with self.assertRaises(ValueError):c.register_public_listener(r['store'],'helper',str(binary))
            public.unlink()
            with patch.object(c,'acl_text',return_value=after.replace('--x','rwx')):
                with self.assertRaises(ValueError):c.register_public_listener(r['store'],'helper',str(binary))
            c.register_public_listener(r['store'],'helper',str(binary))
            pin=public.with_suffix('.controller');pin.write_bytes(b'MINI-PUBLIC-CONTROLLER/v1\n999\n')
            with self.assertRaises(ValueError):c.controller_status(r['store'],'helper')
            pin.write_bytes(c.listener_pin(r));target=base/'public-listener/mini';target.chmod(0o755);target.write_bytes(b'foreign')
            with self.assertRaises(ValueError):c.controller_status(r['store'],'helper')

    def test_public_listener_registration_resumes_exact_interrupted_publication(self):
        for fail_at in range(1,4):
            with self.subTest(fail_at=fail_at),self.public_listener_fixture(str(fail_at)) as (base,r,stage,public,binary,after):
                original=c.publish_exact;count=[0]
                def crash(*args,**kwargs):
                    original(*args,**kwargs);count[0]+=1
                    if count[0]==fail_at:raise OSError('simulated publication interruption')
                with patch.object(c,'publish_exact',side_effect=crash),self.assertRaises(OSError):
                    c.register_public_listener(r['store'],'helper',str(binary))
                self.assertEqual(c.register_public_listener(r['store'],'helper',str(binary))['publicListener']['controllerUid'],r['uid'])

    def test_public_listener_teardown_holds_native_lock_and_never_adopts_socket(self):
        with self.public_listener_fixture() as (base,r,stage,public,binary,after):
            c.register_public_listener(r['store'],'helper',str(binary))
            with self.assertRaisesRegex(RuntimeError,'retained'):
                with c.public_listener_teardown(base,stage,r):raise RuntimeError('retained')
            self.assertTrue(public.with_suffix('.controller').exists())
            public.write_bytes(b'new inode')
            with self.assertRaises(ValueError):
                with c.public_listener_teardown(base,stage,r):pass
            self.assertEqual(public.read_bytes(),b'new inode');public.unlink()
            with c.public_listener_teardown(base,stage,r) as record:
                self.assertEqual(record['socket'],str(public))
                with open(public.with_suffix('.lock'),'rb') as lock:
                    with self.assertRaises(BlockingIOError):fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
                public.parent.chmod(0o700) # Model the exact recorded ancestor ACL restoration.
            self.assertFalse(public.with_suffix('.controller').exists())
            self.assertTrue((base/'public-listener.json').exists())

    def test_registered_remove_restores_ancestors_without_touching_replacement_socket(self):
        with self.public_listener_fixture() as (base,r,stage,public,binary,after):
            c.register_public_listener(r['store'],'helper',str(binary))
            r['name']='mini-c-'+r['store']
            history=self.root/'history';history.mkdir(mode=0o700)
            original_ancestry=c.ancestry
            def ancestry(path,owners):return original_ancestry(path,owners|{self.uid})
            with patch.object(c,'HISTORY',history),patch.object(c,'service'), \
                 patch.object(c,'preserve_consent_state',return_value={'retained':True}),patch.object(Path,'read_text',return_value=''), \
                 patch.object(c,'ancestry',side_effect=ancestry),patch.object(c.grp,'getgrnam',side_effect=KeyError), \
                 patch.object(c,'run') as run:
                result=c.remove(r['store'],'helper')
            self.assertFalse(public.with_suffix('.controller').exists());self.assertFalse(base.exists())
            restores=[call for call in run.call_args_list if '--restore=-' in call.args[0]]
            self.assertEqual(len(restores),1)
            self.assertEqual(restores[0].kwargs['input'].decode().splitlines()[0],'# file: '+str(public.parent))
            retained=json.loads(Path(result['receipt']).read_bytes())
            self.assertEqual(retained['publicListener']['socket'],str(public))
            self.assertEqual(retained['stage']['acl'],stage['acl'])

    def test_storage_upgrade_retries_only_exact_old_new_publication_states(self):
        with self.storage_upgrade_fixture() as (base,r,units,old_stage,old_unit):
            original=c.replace_root_record; calls=[]
            def fail_after_unit(path,data,mode):
                original(path,data,mode);calls.append(path)
                if len(calls)==1:raise OSError('injected unit publication interruption')
            with patch.object(c,'replace_root_record',side_effect=fail_after_unit):
                with self.assertRaises(OSError):c.consent_storage_upgrade(r['store'],'/unused')
            self.assertEqual((base/'stage.json').read_bytes(),old_stage)
            self.assertNotEqual((units/r['units'][4]).read_bytes(),old_unit)
            result=c.consent_storage_upgrade(r['store'],'/unused')
            new_stage=(base/'stage.json').read_bytes();new_unit=(units/r['units'][4]).read_bytes()
            self.assertEqual(result['stageSha256'],c.sha(new_stage))
            # The inverse partial state and interrupted manager reload are also
            # exact retained transitions, not license to accept arbitrary bytes.
            (units/r['units'][4]).write_bytes(old_unit)
            with patch.object(c,'run',side_effect=OSError('injected reload failure')):
                with self.assertRaises(OSError):c.consent_storage_upgrade(r['store'],'/unused')
            self.assertEqual((units/r['units'][4]).read_bytes(),new_unit)
            self.assertEqual((base/'stage.json').read_bytes(),new_stage)
            c.consent_storage_upgrade(r['store'],'/unused')
            self.assertEqual((base/'stage.json').read_bytes(),new_stage)
            changed=units/r['units'][4];changed.write_bytes(new_unit+b'Environment=FORGED=1\n')
            with self.assertRaises(ValueError):c.consent_storage_upgrade(r['store'],'/unused')

    def test_storage_upgrade_config_drift_and_live_units_refuse_before_publication(self):
        with self.storage_upgrade_fixture() as (base,r,units,old_stage,old_unit):
            config=base/'consent/config.json';config.write_bytes(b'{"storageRoot":"/other"}')
            with self.assertRaisesRegex(ValueError,'configuration bytes differ'):
                c.consent_storage_upgrade(r['store'],'/unused')
            self.assertEqual((units/r['units'][4]).read_bytes(),old_unit)
            with patch.object(c,'manager_properties',return_value={'LoadState':'loaded','Transient':'no',
                    'FragmentPath':str(units/r['units'][0]),'ActiveState':'active','MainPID':'123'}):
                with self.assertRaisesRegex(ValueError,'must be stopped'):c.consent_storage_upgrade(r['store'],'/unused')

    def test_storage_upgrade_retries_after_each_archive_intent_and_temporary_write(self):
        for fault in range(1,8):
            with self.subTest(fault=fault), self.storage_upgrade_fixture(str(fault)) as (base,r,units,old_stage,old_unit):
                original=c.write_new;writes=[]
                def interrupt(path,data,*args,**kwargs):
                    original(path,data,*args,**kwargs);writes.append(path)
                    if len(writes)==fault:raise OSError('injected durable write interruption')
                with patch.object(c,'write_new',side_effect=interrupt):
                    with self.assertRaises(OSError):c.consent_storage_upgrade(r['store'],'/unused')
                result=c.consent_storage_upgrade(r['store'],'/unused')
                self.assertEqual(c.sha((base/'stage.json').read_bytes()),result['stageSha256'])
                self.assertTrue((base/'configs'/('consent-storage-'+c.sha(old_stage)+'.stage')).exists())
                self.assertTrue((base/'configs'/('consent-storage-'+c.sha(old_unit)+'.service')).exists())
                # The real receiving check refuses persistent object substitution
                # after staging even when replacement bytes/mode are identical.
                store=Path(result['consent']['storage']['root'])
                database=store/'forward-link.sqlite3';replacement=store/'replacement'
                replacement.write_bytes(database.read_bytes());replacement.chmod(0o600);replacement.replace(database)
                with self.assertRaisesRegex(ValueError,'persistent inode pins differ'):c.checked_units(base,r)

    def test_runtime_upgrade_recovers_each_publication_step_and_preserves_old_bytes(self):
        for fault in range(1,9):
            with self.subTest(fault=fault), self.storage_upgrade_fixture('runtime'+str(fault)) as (base,r,units,old_stage,old_unit):
                home=Path(r['home']);(home/'bin').mkdir(mode=0o700)
                old=(base/'bin/grain-runtime').read_bytes()
                (home/'bin/grain-runtime').write_bytes(old);(home/'bin/grain-runtime').chmod(0o500)
                source=self.file('runtime-source-'+str(fault),b'qualified new runtime fixture',0o700)
                original=c.write_new;writes=[]
                def interrupt(path,data,*args,**kwargs):
                    writes.append(path)
                    if len(writes)==fault and fault!=7:
                        original(path,data[:max(1,len(data)//2)],*args,**kwargs)
                        raise OSError('injected runtime partial write')
                    original(path,data,*args,**kwargs)
                    if len(writes)==fault:raise OSError('injected runtime durable write interruption')
                with patch.object(c,'write_new',side_effect=interrupt):
                    with self.assertRaises(OSError):c.runtime_upgrade(r['store'],'/unused',str(source))
                result=c.runtime_upgrade(r['store'],'/unused',str(source))
                self.assertEqual(result['runtimeSha256'],c.sha(source.read_bytes()))
                self.assertEqual((base/'bin/grain-runtime').read_bytes(),source.read_bytes())
                self.assertEqual((home/'bin/grain-runtime').read_bytes(),source.read_bytes())
                self.assertEqual(stat.S_IMODE((home/'bin/grain-runtime').stat().st_mode),0o500)
                self.assertEqual((base/'configs'/('runtime-upgrade-'+c.sha(old)+'.binary')).read_bytes(),old)
                self.assertEqual((base/'configs'/('runtime-upgrade-'+c.sha(old_stage)+'.stage')).read_bytes(),old_stage)
                self.assertEqual(c.runtime_upgrade(r['store'],'/unused',str(source)),result)
                current=(base/'stage.json').read_bytes()
                forged=json.loads(current);forged['foreign']='record edit'
                (base/'stage.json').write_bytes(c.encoded(forged))
                with self.assertRaises(ValueError):c.runtime_upgrade(r['store'],'/unused',str(source))
                (base/'stage.json').write_bytes(current)
                # Neither a staged caller-selected change nor a changed home
                # binary can be adopted by replaying the retained transaction.
                (home/'bin/grain-runtime').chmod(0o700);(home/'bin/grain-runtime').write_bytes(b'foreign');(home/'bin/grain-runtime').chmod(0o500)
                with self.assertRaises(ValueError):c.runtime_upgrade(r['store'],'/unused',str(source))

    def test_enroll_runs_fixed_native_command_once_and_brackets_only_inactive_helpers(self):
        with self.storage_upgrade_fixture('enroll') as (base,r,units,old_stage,old_unit):
            c.consent_storage_upgrade(r['store'],'/unused')
            home=Path(r['home']);config=b'{"retained":"config fixture"}'
            for path in (home/'controller.json',base/'configs'/(c.sha(config)+'.json')):
                path.write_bytes(config);path.chmod(0o600)
            request={'protocol':'mini-controller-application-enrollment-v1','mode':'bootstrap-dispatch',
                     'expectedBindingSha256':'ab'*32,'targetConfigSha256':c.sha(config)}
            source=self.file('enroll-request.json',c.encoded(request))
            calls=[]
            def manager(unit):
                return {'LoadState':'loaded','Transient':'no','FragmentPath':str(units/unit),
                        'ActiveState':'active' if unit == r['units'][3] else 'inactive',
                        'MainPID':'0','ControlPID':'0','User':str(self.uid)}
            def child(record,args,setup=None,timeout=0):
                setup();calls.append((args,timeout,record['_consentEnvironment']));return 1
            with patch.object(c,'manager_properties',side_effect=manager),patch.object(c,'controller_child',side_effect=child),patch.object(c,'run') as execute:
                self.assertEqual(c.enroll(r['store'],'/unused',str(source)),1)
            self.assertEqual(len(calls),1)
            args,timeout,environment=calls[0]
            self.assertEqual(args[:4],[str(base/'bin/grain-runtime'),'application-enroll','stopped',str(home/'controller.json')])
            self.assertEqual(Path(args[4]).read_bytes(),source.read_bytes())
            self.assertEqual(timeout,1800)
            self.assertEqual(environment,c.consent_environment(r,base,c.checked_units(base,r)['consent']))
            self.assertEqual(len(environment),7)
            commands=[call.args[0] for call in execute.call_args_list]
            self.assertEqual(commands[0],['/usr/bin/systemctl','start',r['units'][1],r['units'][3],r['units'][4]])
            self.assertEqual(commands[1],['/usr/bin/systemctl','stop',r['units'][1],r['units'][2],r['units'][4]])
            self.assertNotIn(r['units'][0],commands[0])
            self.assertTrue(Path(args[4]).exists()) # Native refusal never erases the request.
            source.write_bytes(c.encoded({**request,'targetConfigSha256':'00'*32}))
            with patch.object(c,'controller_child') as child:
                with self.assertRaisesRegex(ValueError,'config differs'):c.enroll(r['store'],'/unused',str(source))
                child.assert_not_called()

    def test_enroll_retains_exclusive_lifecycle_lock_after_releasing_allocator(self):
        lock=self.file('allocator.lock');lifecycle=self.file('lifecycle.lock',b'controller lifecycle lock\n')
        opened=open
        def selected(path,*args,**kwargs):
            return opened(lock if path=='/run/mini-spk-world-install.lock' else path,*args,**kwargs)
        def child(*args):
            with opened(lock,'rb') as global_probe,opened(lifecycle,'rb') as local_probe:
                fcntl.flock(global_probe,fcntl.LOCK_EX|fcntl.LOCK_NB)
                with self.assertRaises(BlockingIOError):fcntl.flock(local_probe,fcntl.LOCK_EX|fcntl.LOCK_NB)
            return 1
        with patch('builtins.open',side_effect=selected),patch.object(c.os,'geteuid',return_value=0), \
             patch.object(c,'store_context',return_value=({},self.root)),patch.object(c,'ancestry'), \
             patch.object(c.os,'fstat',return_value=SimpleNamespace(st_mode=stat.S_IFREG|0o600,st_uid=0,st_nlink=1)), \
             patch.object(c,'enroll',side_effect=child):
            self.assertEqual(c.main(['controller-enroll','ab'*8,'/unused','/request']),1)
        with opened(lifecycle,'rb') as released:fcntl.flock(released,fcntl.LOCK_EX|fcntl.LOCK_NB)

    def test_enroll_start_and_stop_failures_do_not_resend_or_erase_request(self):
        for failure in ('start','stop'):
            with self.subTest(failure=failure),self.storage_upgrade_fixture('enroll-'+failure) as (base,r,units,old_stage,old_unit):
                c.consent_storage_upgrade(r['store'],'/unused')
                home=Path(r['home']);config=b'{"retained":"config"}'
                for path in (home/'controller.json',base/'configs'/(c.sha(config)+'.json')):
                    path.write_bytes(config);path.chmod(0o600)
                source=self.file('enroll-'+failure+'.json',c.encoded({'protocol':'mini-controller-application-enrollment-v1',
                    'mode':'application','expectedBindingSha256':'ab'*32,'targetConfigSha256':c.sha(config)}))
                native=[];commands=[]
                def command(args,**kwargs):
                    commands.append(args)
                    if args[1]==failure:raise OSError('injected '+failure+' failure')
                def child(record,args,setup=None,timeout=0):setup();native.append(args);return 0
                with patch.object(c,'run',side_effect=command),patch.object(c,'controller_child',side_effect=child):
                    with self.assertRaises(OSError):c.enroll(r['store'],'/unused',str(source))
                self.assertTrue(source.exists())
                self.assertEqual(len(native),0 if failure=='start' else 1)
                if native:self.assertTrue(Path(native[0][-1]).exists())
                self.assertEqual([args[1] for args in commands],['start','stop'])

    def test_exact_publication_recovers_mid_write_prefix_and_preserves_conflicts(self):
        target=self.root/'archive';data=b'exact durable archive bytes'
        original=c.write_new
        def interrupted(path,content,*args,**kwargs):
            original(path,content[:8],*args,**kwargs)
            raise OSError('injected short durable write')
        with patch.object(c,'write_new',side_effect=interrupted):
            with self.assertRaises(OSError):c.publish_exact(target,data,self.uid,self.gid)
        self.assertFalse(target.exists())
        partial=self.root/'.archive-publishing'
        self.assertEqual(partial.read_bytes(),data[:8])
        c.publish_exact(target,data,self.uid,self.gid)
        self.assertEqual(target.read_bytes(),data)
        self.assertFalse(partial.exists())
        c.publish_exact(target,data,self.uid,self.gid)
        with self.assertRaises(ValueError):c.publish_exact(target,b'other bytes',self.uid,self.gid)
        self.assertEqual(target.read_bytes(),data)
        other=self.root/'other';orphan=self.root/'.other-publishing'
        orphan.write_bytes(b'conflicting prefix');orphan.chmod(0o600)
        with self.assertRaises(ValueError):c.publish_exact(other,data,self.uid,self.gid)
        self.assertEqual(orphan.read_bytes(),b'conflicting prefix')
        self.assertFalse(other.exists())

    def config_files(self,base,r,suffix):
        home=Path(r['home'])
        old=c.encoded({'commands':[],'stateDir':str(home/'state'),'controlSocket':str(home/'state/control.sock'),
                       'hostConfig':str(home/'host-config.json'),'cwd':str(home/'workspace'),'version':1})
        new=c.encoded({**json.loads(old),'version':2})
        for path in (home/'controller.json',base/'configs'/(c.sha(old)+'.json')):
            path.write_bytes(old);path.chmod(0o600)
        source=self.file('config-source-'+suffix,new)
        return old,new,source

    def test_config_publication_recovers_mid_write_intent_archive_and_home_stage(self):
        for fault in (1,2,3):
            with self.subTest(fault=fault),self.storage_upgrade_fixture('config'+str(fault)) as (base,r,units,stage,unit):
                old,new,source=self.config_files(base,r,str(fault))
                original=c.write_new;writes=[]
                def interrupted(path,data,*args,**kwargs):
                    writes.append(path)
                    if len(writes)==fault:
                        original(path,data[:max(1,len(data)//2)],*args,**kwargs)
                        raise OSError('injected config partial write')
                    return original(path,data,*args,**kwargs)
                with patch.object(c,'write_new',side_effect=interrupted):
                    with self.assertRaises(OSError):c.config_update(r['store'],'/unused',str(source))
                self.assertEqual((Path(r['home'])/'controller.json').read_bytes(),old)
                result=c.config_update(r['store'],'/unused',str(source))
                self.assertEqual((Path(r['home'])/'controller.json').read_bytes(),new)
                self.assertEqual(result['previousSha256'],c.sha(old))
                repeated=c.config_update(r['store'],'/unused',str(source))
                self.assertTrue(repeated['replayed'])
                self.assertEqual(repeated['previousSha256'],c.sha(old))
                self.assertEqual((base/'configs'/(c.sha(old)+'.json')).read_bytes(),old)

    def test_config_rename_fsync_failure_is_recoverable_without_rollback_permission(self):
        with self.storage_upgrade_fixture('config-sync') as (base,r,units,stage,unit):
            old,new,source=self.config_files(base,r,'sync');home=Path(r['home'])
            original=c.sync_directory;calls=[]
            def interrupted(path):
                if path==home:
                    calls.append(path)
                    if len(calls)==2:raise OSError('injected final config directory fsync failure')
                return original(path)
            with patch.object(c,'sync_directory',side_effect=interrupted):
                with self.assertRaises(OSError):c.config_update(r['store'],'/unused',str(source))
            self.assertEqual((home/'controller.json').read_bytes(),new)
            self.assertTrue(c.config_update(r['store'],'/unused',str(source))['replayed'])
            # Model losing the unsynced rename: only the exact retained previous
            # state is accepted, and replay republishes the intended new config.
            (home/'controller.json').write_bytes(old)
            c.config_update(r['store'],'/unused',str(source))
            self.assertEqual((home/'controller.json').read_bytes(),new)
            historical=self.file('historical-config',old)
            with self.assertRaisesRegex(ValueError,'noncurrent config lacks'):c.config_update(r['store'],'/unused',str(historical))


if __name__ == '__main__':
    unittest.main()
