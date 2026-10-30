"""Evidence checks for the live apps journey; these fixtures do not establish admission."""
import base64
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest
import tempfile
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('j14_apps', Path(__file__).with_name('j14-apps.py'))
driver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(driver)


def record(value):
    data = json.dumps(value).encode()
    return {'base64': base64.b64encode(data).decode(), 'sha256': hashlib.sha256(data).hexdigest()}


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.j = driver.Apps.__new__(driver.Apps)
        self.j.c = {'controllerRoot': '/controller/grain'}

    def test_partial_broker_registration_is_torn_down_without_broker_result(self):
        with tempfile.TemporaryDirectory() as root:
            self.j.root = Path(root)
            recovery = self.j.root / 'broker-0047/recovery.json'
            recovery.parent.mkdir(); recovery.write_text('{"store":"fixture"}')
            self.j.controller = False
            self.j.daemons = []; self.j.processes = []
            calls = []
            self.j.run = lambda label, args: calls.append((label, args))
            with patch.object(driver.m.Journey, 'cleanup') as parent:
                self.j.cleanup()
            self.assertEqual([label for label, _ in calls], ['world-down'])
            self.assertEqual((self.j.root / 'teardown/broker-setup/recovery.json').read_bytes(), recovery.read_bytes())
            parent.assert_called_once()

    def test_failure_capture_keeps_original_failure_and_tries_both_evidence_sources(self):
        with tempfile.TemporaryDirectory() as root:
            self.j.root=Path(root);self.j.controller=True
            failure=self.j.root/'failure.json';failure.write_text('{"lastCommand":95}')
            calls=[]
            def fixed(verb):
                calls.append(verb)
                if verb=='controller-service-logs':raise ValueError('log unavailable')
            self.j.fixed=fixed;self.j.capture_failure()
            self.assertEqual(calls,['controller-service-logs','controller-export'])
            self.assertEqual(json.loads(failure.read_text()),{'lastCommand':95})
            self.assertEqual(json.loads((self.j.root/'failure-evidence-errors.json').read_text())[0]['command'],
                             'controller-service-logs')

    def test_refusal_must_be_a_tool_result_linked_to_a_real_call(self):
        messages = [{'role': 'assistant', 'content': 'typed-apps-not-granted'}]
        exported = {'files': {'provider-1.controller-request': record({'messages': messages})}}
        self.assertEqual(self.j.provider_tool_results(exported), [])
        messages += [
            {'role': 'assistant', 'tool_calls': [{'id': 'call1', 'function': {
                'name': 'mcp__mini_grain__mini_app_dav_file_put_text',
                'arguments': '{"path":"refused.txt","content":"x"}'}}]},
            {'role': 'tool', 'tool_call_id': 'call1', 'content': 'typed-apps-not-granted'},
        ]
        exported['files']['provider-1.controller-request'] = record({'messages': messages})
        self.assertEqual(len(self.j.provider_tool_results(exported)), 1)
        messages[-1]['tool_call_id'] = 'unrelated'
        exported['files']['provider-1.controller-request'] = record({'messages': messages})
        self.assertEqual(self.j.provider_tool_results(exported), [])

    def test_put_get_require_definite_receipts_and_exact_retained_bytes(self):
        attempts, files = [], {}
        for index, method in enumerate(('PUT', 'GET')):
            request, reply = f'call-{index}.json', f'reply-{index}.json'
            files[request] = record({'method': method, 'path': 'dav/notes.txt',
                                    'operationId':str(index),'bindingSha256':'b'*64})
            identity={'bindingSha256':'b'*64,'operationFingerprint':'f'*64}
            files[reply] = record({'protocol':'mini-spk-agent-api-v3','type': 'http-v3', 'status': 200,
                                  'operationId':str(index),'committedReceipt':{'eventId':'1'},
                                  'responseSha256':'a'*64,**identity})
            attempts.append({'phase': 'definite', 'operationId':index,**identity,
                             'lifetimeCommittedReceipt': {'eventId': '1'},
                             'lifetimeSettledResponseSha256':'a'*64,
                             'lifetimeSettlement': {'dispatchAttemptId': index,'forwardOperationId':index,
                                                    'settlement':{'operation':'dispatch settle'}},
                             'requestPath': '/controller/grain/state/' + request,
                             'requestSha256': files[request]['sha256'],
                             'replyPath': '/controller/grain/state/' + reply,
                             'replySha256': files[reply]['sha256']})
        exported = {'files': files}
        self.j.dispatch_evidence(attempts, exported)
        with self.assertRaisesRegex(ValueError, 'both the requested put and get'):
            self.j.dispatch_evidence(attempts[:1], exported)
        for field, value in [('phase', 'uncertain'), ('lifetimeSettlement', None)]:
            bad = copy.deepcopy(attempts); bad[0][field] = value
            with self.assertRaisesRegex(ValueError, 'definite admission and settlement'):
                self.j.dispatch_evidence(bad, exported)
        bad=copy.deepcopy(attempts);bad[0]['lifetimeCommittedReceipt']={'eventId':'2'}
        with self.assertRaisesRegex(ValueError,'do not join the same call'):
            self.j.dispatch_evidence(bad,exported)
        exported['files']['reply-0.json'] = record({'type': 'http-v3', 'status': 403})
        with self.assertRaisesRegex(ValueError, 'digest differs'):
            self.j.dispatch_evidence(attempts, exported)


if __name__ == '__main__':
    unittest.main()
