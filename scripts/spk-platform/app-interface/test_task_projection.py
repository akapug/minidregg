import hashlib
import json
from pathlib import Path
import unittest

from binding import Engine, Refusal, load, resolve, validate


class TaskProjection(unittest.TestCase):
    def test_sha256_is_utf8_and_refuses_nontext(self):
        self.assertEqual(resolve({'sha256': {'arg': 'body'}}, {'body': 'héllo\n'}, {}),
                         hashlib.sha256('héllo\n'.encode()).hexdigest())
        with self.assertRaises(Refusal):
            resolve({'sha256': {'arg': 'body'}}, {'body': 12}, {})

    def test_map_values_projection_checks_filter_and_shape(self):
        declaration = json.loads((Path(__file__).resolve().parents[3] /
                                  'apps/interfaces/filedrop.json').read_text())
        op = declaration['operations']['file.list']
        op['projection'].update(values=True, where={'name': {'arg': 'name'}})
        op['input']['properties']['name'] = {'type': 'string'}
        class Receiver:
            def http(self, request):
                return 200, {'content-type': 'application/json'}, b'{"entries":{"a":{"name":"one"},"b":{"name":"two"}}}'
        self.assertEqual(Engine(declaration, Receiver(), {}).call('file.list', {'name': 'two'}), [{'name': 'two'}])
        class InvalidReceiver:
            def http(self, request):
                return 200, {'content-type': 'application/json'}, b'{"entries":{"a":42}}'
        with self.assertRaises(Refusal):
            Engine(declaration, InvalidReceiver(), {}).call('file.list', {'name': 'two'})

    def test_unique_by_refuses_duplicate_job_ids_before_auth_or_write(self):
        declaration = load('prioritize')
        class Receiver:
            calls = 0
            def http(self, request):
                self.calls += 1
                raise AssertionError('invalid IDs reached transport')
        receiver = Receiver()
        job = {'title': 'one', 'period': 86400000, 'lastDone': None, 'urgencyGrowth': 'linear'}
        with self.assertRaises(Refusal):
            Engine(declaration, receiver, {}).call('jobs.replace', {
                'jobs': [{'k': 1, 'v': job}, {'k': 1, 'v': {**job, 'title': 'two'}}],
                'expectedVersion': '0'})
        self.assertEqual(receiver.calls, 0)

    def test_unique_by_scalar_keys_and_malformed_entries(self):
        declaration = load('prioritize')
        schema = {'type': 'array', 'uniqueBy': 'id', 'maxItems': 1000}
        validate(declaration, schema, [{'id': 1}, {'id': '1'}])
        for entries in [[{'id': 1}, {'id': 1}], [{}], [3], [{'id': True}], [{'id': []}]]:
            with self.assertRaises(Refusal):
                validate(declaration, schema, entries)


if __name__ == '__main__':
    unittest.main()
