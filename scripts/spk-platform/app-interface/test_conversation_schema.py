"""Closed conversation declarations; execution belongs to the native SDK."""
import copy
import json
import os
from pathlib import Path
from unittest import TestCase, main
from jsonschema import Draft202012Validator
from binding import ROOT

class ConversationSchema(TestCase):
    def validator(self):
        schema = json.loads(Path(os.environ.get('CONVERSATION_SCHEMA', ROOT / 'format.schema.json')).read_text())
        Draft202012Validator.check_schema(schema)
        return Draft202012Validator(schema)

    def declaration(self, wire='json-v1'):
        d = json.loads((ROOT / 'swagger-editor.json').read_text())
        d['operations'] = {'sample': {'description': 'source-derived codec sample',
            'input': {'type': 'object'}, 'output': {'type': 'object'}, 'write': False,
            'binding': {'protocol': 'conversation', 'wire': wire, 'path': ['channel'],
                'steps': [{'id': 'reply', 'receive': {'where': [{'path': ['type'], 'equals': 'reply'}]}}],
                'result': {'result': ['reply']}}}}
        d['qualification'] = []
        return d

    def test_json_terminals_and_scoped_http_cookies(self):
        d = self.declaration()
        binding = d['operations']['sample']['binding']
        binding['steps'] = [{'send': {'type': 'request'}},
            {'receiveAll': [{'id': 'reply', 'where': [{'path': ['type'], 'equals': 'reply'}]},
                            {'id': 'idle', 'where': [{'path': ['state'], 'equals': 'idle'}]}]},
            {'id': 'http', 'http': {'protocol': 'http', 'method': 'GET', 'path': ['file'],
                'decode': 'base64', 'status': [200], 'cookies': {'token': {'result': ['reply', 'token']}}}}]
        self.assertTrue(self.validator().is_valid(d))

    def test_pinned_socketio_and_correlated_array_contains(self):
        d = self.declaration('socket.io-eio4')
        d['operations']['sample']['binding']['steps'] = [
            {'emit': 'subscribe', 'args': ['hits']},
            {'id': 'hits', 'receive': {'event': 'hits', 'where': [
                {'path': [0], 'contains': {'url': {'arg': 'url'}}}]}}]
        self.assertTrue(self.validator().is_valid(d))
        d['operations']['sample']['binding']['wire'] = 'auto-probe'
        self.assertFalse(self.validator().is_valid(d))

    def test_closed_step_and_wire_shapes_and_reserved_cookie(self):
        d = self.declaration()
        binding = d['operations']['sample']['binding']
        for bad in [{'send': {}, 'emit': 'two-operations', 'args': []},
                    {'id': 'x', 'receive': {'event': 'not-json-framing', 'where': [{'path': [], 'exists': True}]}},
                    {'id': 'x', 'http': {'protocol': 'http', 'method': 'GET', 'path': ['file'],
                        'decode': 'status', 'status': [200], 'cookies': {'__Host-mini_spk_session': 'forbidden'}}}]:
            binding['steps'] = [bad]
            self.assertFalse(self.validator().is_valid(d))
        d = self.declaration('socket.io-eio4')
        self.assertFalse(self.validator().is_valid(d))  # Socket.IO receive needs event.

if __name__ == '__main__':
    main()
