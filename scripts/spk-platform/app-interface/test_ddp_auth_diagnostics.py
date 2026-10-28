"""Safe, correlated evidence for the two-leg Meteor authentication handshake."""
import json
import unittest
from unittest.mock import patch

from binding import Refusal, load
from ddp import DDP


class Channel:
    def __init__(self):
        self.frames = []
        self.sent = []

    def send(self, raw):
        self.sent.append(json.loads(raw))

    def settimeout(self, value):
        pass

    def recv(self):
        if not self.frames:
            raise EOFError()
        return json.dumps(self.frames.pop(0))


class AuthDiagnostics(unittest.TestCase):
    def test_http_failure_preserves_ddp_timeout_without_secrets(self):
        channel, events = Channel(), []
        ddp = DDP(channel, diagnostic=events.append)
        calls = []
        def post(request):
            calls.append(request)
            if len(calls) == 1:
                channel.frames.append({'msg': 'result', 'id': channel.sent[0]['id'],
                                       'error': {'error': 'timeout', 'reason': 'private reason'}})
            return 500, {}, b'private HTTP text'
        with patch('ddp.time.sleep'):
            with self.assertRaisesRegex(Refusal, 'auth-rendezvous-refused: 500'):
                ddp.authenticate(load('wekan')['auth'], post)
        self.assertEqual(len(calls), 4)
        self.assertEqual(len(channel.sent), 1)
        self.assertEqual(events[-1]['auth']['code'], 'timeout')
        self.assertEqual([e['auth']['event'] for e in events],
                         ['method-sent'] + ['rendezvous-post'] * 4 + ['method-refused'])
        evidence = json.dumps(events)
        self.assertNotIn(calls[0]['body'].decode(), evidence)
        self.assertNotIn('private', evidence)
        self.assertTrue(all(e['auth']['elapsedMs'] >= 0 for e in events))

    def test_credential_resume_uses_server_token_and_standard_login_result(self):
        channel = Channel()
        ddp = DDP(channel)
        auth = {'kind': 'credential-resume', 'credentialsPath': '/.sandstorm-credentials',
                'tokenField': 'token', 'method': 'login', 'userIdField': 'id'}
        def request(value):
            self.assertEqual(value['method'], 'GET')
            self.assertEqual(value['path'], '.sandstorm-credentials')
            return 200, {'content-type': 'application/json'}, b'{"meteorId":"member-a","token":"server-secret"}'
        original = channel.send
        def send(raw):
            original(raw)
            method = channel.sent[-1]
            self.assertEqual(method['params'], [{'resume': 'server-secret'}])
            channel.frames.extend([{'msg': 'result', 'id': method['id'], 'result': {'id': 'member-a'}},
                                   {'msg': 'updated', 'methods': [method['id']]}])
        channel.send = send
        self.assertEqual(ddp.authenticate(auth, request), 'member-a')


if __name__ == '__main__':
    unittest.main()
