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
        pins = {'providerSha256': '12'*32, 'configSha256': '34'*32}
        base = Path('/var/lib/mini-spk-worlds/abababababababab/controller')
        units = c.unit_bytes(r, base, Path('/operator/private.sock'), pins)
        runtime, _, _, listener, service = [units[n].decode() for n in r['units']]
        self.assertIn('User=1000\nGroup=1000', service)
        self.assertIn('SocketUser=100032', listener)
        self.assertIn('SocketMode=0600', listener)
        self.assertIn('--anchors ' + str(base / 'consent/anchors'), service)
        self.assertIn('ReadWritePaths=' + str(base / 'consent/anchors') + '\n', service)
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
             patch.object(c,'ancestry'),patch.object(c,'run',side_effect=command):
            with self.assertRaisesRegex(ValueError,'injected'):c.create('ab'*8,registry['helper'])
        self.assertEqual(events,['reserved','groupadd','useradd'])
        self.assertTrue((reservations/('ab'*8+'.json')).exists())
        self.assertTrue((base/'pending.json').exists())
        self.assertFalse((base/'namespace.json').exists())

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


if __name__ == '__main__':
    unittest.main()
