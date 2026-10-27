#!/usr/bin/env python3
"""Bounded fixture guards only; no Mini admission, real Store, or root actions.

Run: python3 scripts/test-oracle-controller-continuation.py
The successful real preflight is separate acceptance evidence.
"""
import importlib.util
import json
from pathlib import Path
import shlex
import socket
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('continuation', REPO / 'deploy/oracle/acceptance/continue_controller.py')
CONTINUATION = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CONTINUATION)


class ContinuationGuards(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='oc-', dir='/tmp')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.run = self.root / 'run'
        (self.run / 'agent-lifetime').mkdir(parents=True)
        (self.run / 'world/evidence').mkdir(parents=True)
        (self.run / 'world/sock/operator').mkdir(parents=True)
        (self.run / 'exit.json').write_text(json.dumps({
            'execution_exit': 1, 'cleanup_exit': 0, 'namespace_preserved': True}))
        (self.root / 'journey-v5.log').write_text(
            "configuration error - unknown item 'CREATE_MAIL_SPOOL'\ncontroller setup refused:")
        (self.run / 'agent-lifetime/controller-create.json').write_bytes(b'')
        for phase in ('store', 'birth-a', 'install-a', 'birth-b', 'install-b', 'share-a'):
            (self.run / f'world/evidence/{phase}.exit').write_text('0\n')

    def refused(self, reason):
        unused = Path('/unused-fixture-input')
        with self.assertRaisesRegex(ValueError, reason):
            CONTINUATION.prepare(self.run, unused, unused, unused, unused, check_only=True)
        self.assertFalse((self.run / 'continuations').exists())

    def test_other_prior_failure_refuses(self):
        (self.run / 'exit.json').write_text('{}')
        self.refused('definite preserved failure')

    def test_existing_session_attempt_refuses(self):
        (self.run / 'agent-lifetime/session-birth.request-id').write_text('retained-attempt')
        self.refused('controller work already began')

    def test_incomplete_install_refuses(self):
        (self.run / 'world/evidence/install-b.exit').write_text('1\n')
        self.refused('prior phase did not complete')

    def test_any_start_attempt_refuses(self):
        (self.run / 'world/evidence/start-a.cmd').write_text('attempted')
        self.refused('START was already attempted')

    def test_live_socket_refuses_without_sending_a_frame(self):
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as listener:
            path = self.run / 'world/sock/operator/host.sock'
            listener.bind(str(path))
            path.chmod(0o600)
            listener.listen()
            self.refused('still has a listener')
            peer, _ = listener.accept()
            with peer:
                self.assertEqual(peer.recv(1), b'')

    def test_changed_manifest_bytes_refuse(self):
        source = self.root / 'bytes'
        source.write_bytes(b'changed')
        manifest = self.root / 'manifest'
        manifest.write_text('0' * 64 + '  ' + str(source) + '\n')
        with self.assertRaisesRegex(ValueError, 'retained bytes changed'):
            CONTINUATION.manifest(manifest)

    def shell(self, body):
        script = ('set -eu\n. ' + shlex.quote(str(REPO / 'deploy/oracle/acceptance/world.sh'))
                  + '\nrun=' + shlex.quote(str(self.run)) + '\n' + body)
        subprocess.run(['bash'], input=script, text=True, check=True, capture_output=True, timeout=10)

    def test_preflight_failure_preserves_old_exit(self):
        before = (self.run / 'exit.json').read_bytes()
        self.shell('configured=0 preserve_existing_exit=1\n'
                   'if (world_cleanup 1); then exit 2; fi\n')
        self.assertEqual((self.run / 'exit.json').read_bytes(), before)

    def test_continuation_exit_has_its_own_path(self):
        before = (self.run / 'exit.json').read_bytes()
        self.shell('configured=0 preserve_existing_exit=0\n'
                   'continuation=$run/continuations/one\nmkdir -p "$continuation"\n'
                   '(world_cleanup 1) || [[ $? == 1 ]]\n')
        self.assertEqual((self.run / 'exit.json').read_bytes(), before)
        self.assertEqual(json.loads((self.run / 'continuations/one/exit.json').read_bytes())['execution_exit'], 1)

    def test_measurement_failure_still_stops_controller(self):
        self.shell('controller_staged=1 installer=/fixture/installer store=fixture helper=/fixture/helper\n'
                   'world_consent_snapshot() { return 7; }\n'
                   'timeout() { printf "%s\\n" fixture-stop-called; }\n'
                   'if world_controller_stop fixture; then exit 2; else result=$?; fi\n'
                   '[[ $result == 7 ]]\n')
        self.assertEqual((self.run / 'agent-lifetime/controller-stop-fixture.json').read_text(),
                         'fixture-stop-called\n')


if __name__ == '__main__':
    unittest.main()
