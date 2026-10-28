import hashlib
import json
from pathlib import Path
import unittest

from binding import Engine, Refusal, resolve


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


if __name__ == '__main__':
    unittest.main()
