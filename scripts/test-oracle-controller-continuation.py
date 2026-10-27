#!/usr/bin/env python3
"""Bounded fixture guards only; no Mini admission, real Store, or root actions.

Run: python3 scripts/test-oracle-controller-continuation.py
The successful real preflight is separate acceptance evidence.
"""
import base64
import hashlib
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import shlex
import socket
import subprocess
import tempfile
import unittest
from unittest import mock

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

    def test_phase_start_is_one_shot_even_without_outcome(self):
        CONTINUATION.phase_record(self.root, 'worker-policy', 'started')
        with self.assertRaisesRegex(ValueError, 'already began'):
            CONTINUATION.phase_record(self.root, 'worker-policy', 'started')
        with self.assertRaisesRegex(ValueError, 'validated evidence'):
            CONTINUATION.phase_record(self.root, 'worker-policy', 'completed')
        self.assertFalse((self.root / 'worker-policy.completed.json').exists())

    def test_phase_completion_joins_exact_retained_receipt(self):
        receipt = self.root / 'native-outcome.json'
        receipt.write_text('{"type":"confirmed"}')
        CONTINUATION.phase_record(self.root, 'worker-policy', 'started')
        CONTINUATION.phase_record(self.root, 'worker-policy', 'completed', [receipt])
        result = json.loads((self.root / 'worker-policy.completed.json').read_bytes())
        self.assertEqual(result['started_sha256'], CONTINUATION.sha(self.root / 'worker-policy.started.json'))
        self.assertEqual(result['evidence'], {str(receipt): CONTINUATION.sha(receipt)})
        with self.assertRaises(FileExistsError):
            CONTINUATION.phase_record(self.root, 'worker-policy', 'completed', [receipt])

    def test_failed_atomic_publication_cannot_replace_record(self):
        path = self.root / 'prepared.json'
        CONTINUATION.durable_json(path, {'first': True})
        original = path.read_bytes()
        with self.assertRaises(FileExistsError):
            CONTINUATION.durable_json(path, {'second': True})
        self.assertEqual(path.read_bytes(), original)

    def test_lock_refuses_other_invocation(self):
        path = self.run / 'acceptance.lock'
        fd = os.open(path, os.O_RDWR | os.O_CREAT, 0o600)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result = subprocess.run(['python3', str(REPO / 'deploy/oracle/acceptance/continue_controller.py'),
                '--locked-exec', str(self.run), 'python3', '-c', 'raise SystemExit(42)'],
                capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 1)
            self.assertIn('another acceptance invocation', result.stderr)
            with mock.patch.dict(os.environ, {'ORACLE_ACCEPTANCE_LOCK_FD': str(fd)}):
                CONTINUATION.verify_lock(self.run)
        finally:
            os.close(fd)

    def test_locked_exec_keeps_lock_across_command(self):
        guard = REPO / 'deploy/oracle/acceptance/continue_controller.py'
        result = subprocess.run(['python3', str(guard), '--locked-exec', str(self.run),
            'python3', str(guard), '--verify-lock', str(self.run)], capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.skipUnless(os.environ.get('ORACLE_TEST_PUBLIC_MINI') and Path('/proc').is_dir(),
                         'explicit qualified Linux public proxy required')
    def test_actual_public_service_start_live_pin_restart_and_cleanup(self):
        source = (REPO / 'scripts/spk-platform/grain-journey.sh').read_text()
        functions = source[source.index('service_up() {'):source.index('\nquery() (')]
        binary = Path(os.environ['ORACLE_TEST_PUBLIC_MINI']).resolve(strict=True)
        op = self.run / 'world/sock/operator/host.sock'
        op.parent.chmod(0o700)
        public = self.run / 'world/sock/participant/host.sock'
        public.parent.mkdir(mode=0o700)
        config = self.root / 'config.json'; config.write_text('{}'); config.chmod(0o600)
        op.with_suffix('.config').write_bytes(config.read_bytes()); op.with_suffix('.config').chmod(0o600)
        op.with_suffix('.mode').write_bytes(b'operator-v1'); op.with_suffix('.mode').chmod(0o600)
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as upstream:
            upstream.bind(str(op)); op.chmod(0o600); upstream.listen()
            body = ('set -eu\n' + functions + '\n'
                'fail() { echo "$*" >&2; exit 1; }\nsha() { sha256sum "$1" | cut -d " " -f1; }\n'
                'RUN=' + shlex.quote(str(self.run / 'world')) + '\nMINI=' + shlex.quote(str(binary)) + '\n'
                'CONFIG=' + shlex.quote(str(config)) + '\nOSOCK=' + shlex.quote(str(op)) + '\n'
                'PSOCK=' + shlex.quote(str(public)) + '\nHOST=/unused GRAINS_ROOT=/unused\n')
            def call(command):
                return subprocess.run(['sh'], input=body+command+'\n', text=True,
                    capture_output=True, timeout=20)
            try:
                first=call('service_up participant "$PSOCK" serve-public-proxy')
                self.assertEqual(first.returncode,0,first.stderr+(self.run/'world/sock/participant.log').read_text())
                identity=self.run/'world/sock/participant.pid.identity.json'
                old=json.loads(identity.read_bytes())
                again=call('service_up participant "$PSOCK" serve-public-proxy')
                self.assertEqual(again.returncode,0,again.stderr)
                self.assertEqual(json.loads(identity.read_bytes()),old)
                pin=self.run/'world/sock/participant.pid.pin'; original=pin.read_bytes(); pin.write_text('wrong\n')
                refused=call('service_up participant "$PSOCK" serve-public-proxy')
                self.assertNotEqual(refused.returncode,0); self.assertIn('live service pin differs',refused.stderr)
                pin.write_bytes(original)
                stopped=call('stop_services'); self.assertEqual(stopped.returncode,0,stopped.stderr)
                self.assertFalse(public.exists())
                restarted=call('service_up participant "$PSOCK" serve-public-proxy')
                self.assertEqual(restarted.returncode,0,restarted.stderr)
                self.assertNotEqual(json.loads(identity.read_bytes())['pid'],old['pid'])
            finally:
                stopped=call('stop_services')
                self.assertEqual(stopped.returncode,0,stopped.stderr)
                self.assertFalse(public.exists())

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


    def cleanup_fixture(self, action, preserve, fail_unmount=False):
        plan = self.root / 'plan.json'
        plan.write_text(json.dumps({'volumes': [{'action': action, 'request': {'verb': 'unmount'}}]}))
        effects = self.root / 'effects'
        self.shell('repo=/fixture/repo GRAINS_ROOT=/fixture/world store=fixture helper=/fixture/helper\n'
                   'fixture_plan=' + shlex.quote(str(plan)) + '\n'
                   'fixture_effects=' + shlex.quote(str(effects)) + '\n'
                   'jq() { if [[ ${*: -1} == /etc/mini-spk-volumes/fixture.json ]]; then '
                   'printf "%s\\n" \'{"verb":"volumes-status"}\'; else command jq "$@"; fi; }\n'
                   'python3() { cat "$fixture_plan"; }\n'
                   'timeout() { local verb; verb=$(command jq -r .verb <<<"${*: -1}"); '
                   'if [[ $verb == volumes-status ]]; then printf "%s\\n" \'{}\'; '
                   'else printf "%s\\n" "$verb" >>"$fixture_effects"; '
                   + ('[[ $verb != unmount ]] || return 9; ' if fail_unmount else '')
                   + 'fi; }\n'
                   + ('if ' if fail_unmount else '')
                   + 'world_cleanup_volumes ' + str(preserve).lower() + ' "$run/volume-evidence"'
                   + ('; then exit 2; else [[ $? == 9 ]]; fi' if fail_unmount else '') + '\n')
        return effects.read_text().splitlines() if effects.exists() else []

    def test_preserved_unmounted_volume_skips_effect(self):
        self.assertEqual(self.cleanup_fixture('already-unmounted', True), [])

    def test_mounted_volume_unmounts_before_successful_destroy(self):
        self.assertEqual(self.cleanup_fixture('unmount', False), ['unmount', 'destroy'])

    def test_unmount_failure_prevents_destroy(self):
        self.assertEqual(self.cleanup_fixture('unmount', False, True), ['unmount'])

    def enrollment_fixture(self, fail_native=False, change_other=False):
        bundle = self.root / 'bundle'
        bundle.mkdir()
        (bundle / 'controller.json').write_text('{"dispatchTask": {"task": "123"}}')
        before = {'binding': {'configPath': '/fixture/controller.json', 'config': {}}, 'pending': None}
        after = {'binding': {'configPath': '/fixture/controller.json', 'config': {'dispatchTask': {'task': '123'}}},
                 'pending': 'unexpected' if change_other else None}
        (self.root / 'before.json').write_text(json.dumps(before))
        (self.root / 'after.json').write_text(json.dumps(after))
        stub = self.root / 'native.py'
        stub.write_text("import hashlib,json,pathlib,sys\np=pathlib.Path(sys.argv[1]);r=pathlib.Path(sys.argv[2])\n"
            "j=json.loads((p/'after.json').read_text())\n"
            "b=json.dumps(j['binding'],sort_keys=True,separators=(',',':'),ensure_ascii=False).encode()\n"
            "print(json.dumps({'protocol':'mini-controller-application-enrollment-v1','status':'enrolled',"
            "'replayed':False,'requestSha256':hashlib.sha256(r.read_bytes()).hexdigest(),"
            "'bindingSha256':hashlib.sha256(b).hexdigest()}))\n")
        body = ('installer=/fixture/installer store=fixture helper=/fixture/helper\n'
                'fixture_root=' + shlex.quote(str(self.root)) + '\n'
                'count=0\n'
                'timeout() { local verb=${6}; printf "%s\\n" "$verb" >>"$fixture_root/effects"; '
                'case $verb in controller-journal) count=$((count+1)); '
                'if [[ $count == 1 ]]; then cat "$fixture_root/before.json"; else cat "$fixture_root/after.json"; fi;; '
                'controller-config) printf "%s\\n" \'{}\';; controller-enroll) '
                + ('return 23;' if fail_native else 'python3 "$fixture_root/native.py" "$fixture_root" "${*: -1}";')
                + ' esac; }\nworld_controller_enroll bootstrap-dispatch "$fixture_root/bundle" fixture\n')
        if fail_native or change_other:
            with self.assertRaises(subprocess.CalledProcessError):
                self.shell(body)
        else:
            self.shell(body)
        return (self.root / 'effects').read_text().splitlines()

    def test_native_enrollment_orders_exact_stopped_transition(self):
        self.assertEqual(self.enrollment_fixture(),
                         ['controller-journal', 'controller-config', 'controller-enroll', 'controller-journal'])
        request = json.loads((self.run / 'agent-lifetime/enrollment-fixture/request.json').read_text())
        self.assertEqual(request['mode'], 'bootstrap-dispatch')
        self.assertEqual(request['targetConfigSha256'], hashlib.sha256((self.root / 'bundle/controller.json').read_bytes()).hexdigest())

    def test_native_enrollment_failure_is_not_retried(self):
        self.assertEqual(self.enrollment_fixture(fail_native=True),
                         ['controller-journal', 'controller-config', 'controller-enroll'])

    def test_native_enrollment_other_journal_change_refuses(self):
        self.enrollment_fixture(change_other=True)

    def test_second_continuation_refuses_changed_original_exit(self):
        first = self.run / 'continuations/controller-create-1'
        first.mkdir(parents=True)
        (first / 'prepared.json').write_text(json.dumps({'prior_exit': {}}))
        with self.assertRaisesRegex(ValueError, 'original failure receipt differs'):
            CONTINUATION.prepare_session(self.run, Path('/unused'), Path('/unused'), Path('/unused'),
                                         Path('/unused'), Path('/unused'), check_only=True)
        self.assertFalse((self.run / 'continuations/session-refusal-1').exists())

    def test_only_recorded_controller_traverse_acl_is_permitted(self):
        acl = 'user::rwx\nuser:100064:--x\ngroup::---\nmask::--x\nother::---'
        CONTINUATION.validate_run_acl(1000, 0o710, 1000, 100064, acl)
        for bad in (acl.replace('100064', '100065'), acl.replace('group::---', 'group::--x'),
                    acl.replace('other::---', 'other::--x'), acl.replace('--x', 'r-x'),
                    acl + '\nuser:100065:--x'):
            with self.assertRaisesRegex(ValueError, 'exact installed-controller'):
                CONTINUATION.validate_run_acl(1000, 0o710, 1000, 100064, bad)
        with self.assertRaisesRegex(ValueError, 'exact installed-controller'):
            CONTINUATION.validate_run_acl(1001, 0o710, 1000, 100064, acl)

    def test_prepared_resume_refuses_any_repair_receipt(self):
        root = self.root / 'prepared'; root.mkdir()
        for name in ('prepared.json', 'prior', 'bin', 'recovery-input-sha256.txt', 'consent-storage.json'):
            (root / name).touch()
        with self.assertRaisesRegex(ValueError, 'newer repair or attempt'):
            CONTINUATION.resume_prepared_archive(root, {}, Path('/unused'), True)
        self.assertFalse((root / 'source-resume-1.json').exists())

    def test_prepared_resume_refuses_changed_store(self):
        root = self.root / 'prepared'; root.mkdir()
        for name in ('prior', 'bin', 'recovery-input-sha256.txt'):
            (root / name).touch()
        (root / 'prepared.json').write_text(json.dumps({'store_before': {'store': 'old'}}))
        with self.assertRaisesRegex(ValueError, 'boundary changed: store_before'):
            CONTINUATION.resume_prepared_archive(root, {'store_before': {'store': 'new'}}, Path('/unused'), True)
        self.assertFalse((root / 'source-resume-1.json').exists())


class CheckpointGuards(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='oc-checkpoint-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.run = self.root / 'run'
        self.old = self.run / 'continuations/session-refusal-1'
        (self.old / 'bin').mkdir(parents=True)
        (self.run / 'bin').mkdir()
        (self.run / 'agent-lifetime/controller-stage').mkdir(parents=True)
        (self.run / 'world/sock').mkdir(parents=True)
        (self.old / 'bin/grain-runtime').write_bytes(b'new-runtime')
        (self.run / 'bin/grain-runtime').write_bytes(b'old-runtime')
        config = self.run / 'agent-lifetime/controller-stage/controller.json'
        config.write_text('{}')
        self.current = dict(run=str(self.run), store='fixture', boundary={'request_id': '1'*32},
            original_inputs={}, original_binaries={}, native_files_before={}, run_custody={'controller_uid': 123},
            store_before={'db': 'same'}, native_profile_sha256='same', host_config_sha256='same', stopped_services={})
        self.write(self.old / 'prepared.json', dict(self.current, prior_files={}))
        raw_consent = {'configSha256': 'config', 'providerSha256': 'provider', 'storage': {'root': '/fixture/store'}}
        storage = {'store': 'fixture', 'consent': {**raw_consent, 'serviceUid': 1000}}
        self.write(self.old / 'consent-storage.json', storage)
        runtime = {'store': 'fixture', 'stageSha256':'stage',
            'runtimeSha256':CONTINUATION.sha(self.old / 'bin/grain-runtime'),
            'previousRuntimeSha256':CONTINUATION.sha(self.run / 'bin/grain-runtime')}
        self.write(self.old / 'runtime-upgrade.json', runtime)
        exit_value = {'execution_exit':1, 'cleanup_exit':0, 'namespace_preserved':True}
        self.write(self.old / 'exit.json', exit_value)
        self.status = self.root / 'status.json'
        self.write(self.status, {'store':'fixture','controllerUid':123,'stopped':True,'stageSha256':'stage',
            'runtimeSha256':runtime['runtimeSha256'],'controllerConfigSha256':CONTINUATION.sha(config),
            'consent':raw_consent})
        self.export = self.root / 'export.json'; self.write(self.export,{})
        self.failure = self.root / 'failure.json'
        self.write(self.failure, {'schema':'mini-oracle-physical-repair-service-failure-v1', 'run':str(self.run),
            'store':'fixture','failed_phase':'services','physical_repairs_completed':['consent-storage','controller-runtime-upgrade'],
            'exit':exit_value,'source_policy_started':False,'native_enrollment_started':False,
            'new_session_tool_started':False,'start_attempted':False,'files':{}})
        for name in ('cleanup.log','broker.log','native-state.tar'):
            (self.run / name).write_bytes(b'preserved')
        self.output = self.run / 'checkpoints/physical.json'
        self.sources = self.root / 'sources.sha256'
        self.sources.write_text(CONTINUATION.sha(self.export)+'  '+str(self.export)+'\n')
        self.addCleanup(mock.patch.stopall)
        mock.patch.object(CONTINUATION,'verify_lock').start()
        mock.patch.object(CONTINUATION,'prepare_session',return_value=self.current).start()

    @staticmethod
    def write(path,value):
        path.write_text(json.dumps(value))

    def seal(self):
        return CONTINUATION.repair_checkpoint(self.run, self.root, self.root, self.root, self.root,
            self.export,self.status,self.failure,self.output)

    def begin(self):
        return CONTINUATION.begin_checkpoint(self.output,self.root,self.root,self.root,self.root,
            self.export,self.status,self.sources)

    def test_exact_physical_boundary_retains_old_receipts_and_archives_mutable_files(self):
        prior = (self.old/'exit.json').read_bytes()
        self.seal(); execution=self.begin()
        value=json.loads((execution/'checkpoint.json').read_bytes())
        self.assertEqual(value['repeated_phases'],[])
        self.assertEqual((execution/'prior/cleanup.log').read_bytes(),b'preserved')
        self.assertEqual((self.old/'exit.json').read_bytes(),prior)
        with self.assertRaisesRegex(ValueError,'already attempted'):
            self.begin()

    def test_changed_logical_state_cannot_seal(self):
        self.current['store_before']={'db':'changed'}
        with self.assertRaisesRegex(ValueError,'boundary changed'):
            self.seal()
        self.assertFalse(self.output.exists())

    def test_unjoined_installed_runtime_cannot_seal(self):
        status=json.loads(self.status.read_bytes()); status['runtimeSha256']='other'; self.write(self.status,status)
        with self.assertRaisesRegex(ValueError,'repair pins differ'):
            self.seal()

    def test_unknown_raw_stage_consent_field_refuses(self):
        status=json.loads(self.status.read_bytes()); status['consent']['unexpected']='field'; self.write(self.status,status)
        with self.assertRaisesRegex(ValueError,'repair pins differ'):
            self.seal()

    def test_later_source_phase_is_not_an_automatic_checkpoint(self):
        self.seal(); value=json.loads(self.output.read_bytes()); value['next_phase']='worker-policy'; self.write(self.output,value)
        with self.assertRaisesRegex(ValueError,'unsupported checkpoint'):
            self.begin()

    def test_replaced_predecessor_receipt_refuses(self):
        self.seal(); self.write(self.old/'exit.json',{})
        with self.assertRaisesRegex(ValueError,'predecessor evidence changed'):
            self.begin()


class SessionRefusalGuards(unittest.TestCase):
    def setUp(self):
        self.request_id = '1' * 32
        self.result = {'isError': True, 'operationId': None, 'requestId': self.request_id,
                       'result': 'foreground tool requires an attached, reconciled idle task',
                       'type': 'tool-complete', 'v': 1}
        self.journal = dict.fromkeys(('pending toolPending providerPending child settlementDue parentHold '
            'toolHold dispatchPending dispatchHold dispatchAttempt applicationApiAttempt providerHold '
            'providerAttempt providerSettlement foregroundAttempt birthOperation birthPending workspaceAttempt '
            'roomAttempt workspaceBirth managedLawGeneration hermesSession promptWitness').split())
        self.journal.update({key: [] for key in ('applicationApiHistory providerReplays foregroundHistory '
            'publicationReceipts bornResources workspaceProposals roomResolutions workspaceResolutions '
            'reconciliationLog priorHermesSessions unresolvedExternal').split()})
        self.journal.update(format='minidregg-grain-runtime-v1', connection='fenced', nextOperationId=2,
                            birthNextOrdinal={}, hardReconnectPending=False, providerPromptRequests=0)
        names = ('controller.lock journal.json query-0000000000000001/attempt/attempt.json '
                 'query-0000000000000001/attempt/config.json query-0000000000000001/attempt/intent.bin '
                 'query-0000000000000001/attempt/intent.json query-0000000000000001/intent-source.json '
                 'shared-app-refs/app-birth.bin shared-app-refs/bootstrap-ticket.bin').split()
        self.export = {'protocol': 'mini-spk-controller-evidence-v1', 'store': 'fixture',
                       'files': {name: self.entry(b'') for name in names}}
        self.export['files']['query-0000000000000001/attempt/attempt.json'] = self.entry(json.dumps({
            'format': 'minidregg-resource-client-attempt-v1', 'operation': 'query'}).encode())

    @staticmethod
    def entry(raw):
        return {'base64': base64.b64encode(raw).decode(), 'sha256': hashlib.sha256(raw).hexdigest()}

    def check(self):
        self.export['files']['journal.json'] = self.entry(json.dumps(self.journal).encode())
        return CONTINUATION.session_refusal(self.request_id, self.result, self.journal, self.export, 'fixture')

    def test_exact_definite_refusal_never_permits_resend(self):
        self.assertFalse(self.check()['permits_resend'])

    def test_unrelated_error_is_not_this_boundary(self):
        self.result['result'] = 'timeout'
        with self.assertRaisesRegex(ValueError, 'exact definite'):
            self.check()

    def test_existing_birth_state_refuses(self):
        self.journal['bornResources'] = [{'resource': 'session'}]
        with self.assertRaisesRegex(ValueError, 'pending or completed work'):
            self.check()

    def test_sealed_query_refuses(self):
        self.export['files']['query-0000000000000001/attempt/observation.bin'] = self.entry(b'sealed')
        with self.assertRaisesRegex(ValueError, 'another operation or sealed'):
            self.check()

    def test_different_request_refuses(self):
        self.result['requestId'] = '2' * 32
        with self.assertRaisesRegex(ValueError, 'exact definite'):
            self.check()


if __name__ == '__main__':
    unittest.main()
