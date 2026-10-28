import json
import hashlib
from pathlib import Path
import unittest
from urllib.parse import unquote, parse_qs

from binding import Engine, Refusal, check_declaration, run_scenario


class FileDropReceiver:
    def __init__(self):
        self.files = {}

    def http(self, request):
        path = unquote(request['path'])
        if path == 'file/' and request['method'] == 'GET':
            return 200, {'content-type': 'application/json'}, json.dumps(
                {'entries': [{'name': name} for name in self.files]}).encode()
        name = path.removeprefix('file/')
        if '/' in name or not name:
            return 404, {}, b''
        if request['method'] == 'PUT':
            created = name not in self.files
            self.files[name] = request['body']
            return (201 if created else 204), {}, b''
        return 200, {}, self.files[name]


class RealtimeDeclarations(unittest.TestCase):
    def test_filedrop_binary_scenario_and_flat_name_refusal(self):
        declaration = json.loads((Path(__file__).resolve().parents[3] /
                                  'apps/interfaces/filedrop.json').read_text())
        check_declaration(declaration)
        receiver = FileDropReceiver()
        engine = Engine(declaration, receiver, {'runId': 'typed-file'})
        result = run_scenario(engine)
        self.assertEqual(receiver.files['typed-file.bin'], b'\x00\xffagent\n')
        self.assertEqual(result['empty'], [])
        self.assertEqual(result['list'], [{'name': 'typed-file.bin'}])
        with self.assertRaises(Refusal):
            engine.call('file.put', {'path': 'directory/file', 'contentBase64': 'AA=='})
        self.assertEqual(len(receiver.files), 1)

    def test_orgtodo_snapshot_hash_and_conflict(self):
        declaration = json.loads((Path(__file__).resolve().parents[3] /
                                  'apps/interfaces/orgtodo.json').read_text())
        check_declaration(declaration)
        class Receiver:
            def __init__(self):
                self.entries = {}
            def http(self, request):
                if request['method'] == 'POST':
                    entry = json.loads(request['body'])
                    assert entry['hash'] == hashlib.sha256(entry['fulltext'].encode()).hexdigest()
                    previous = self.entries.get(entry['id'])
                    if previous and previous['hash'] != parse_qs(request['query'])['oldhash'][0]:
                        return 409, {'content-type': 'application/json'}, json.dumps(previous).encode()
                    self.entries[entry['id']] = {**entry, 'epochUpdateMsecs': 1}
                    return 200, {}, b'OK'
                return 200, {'content-type': 'application/json'}, json.dumps({'entries': self.entries}).encode()
        receiver = Receiver()
        engine = Engine(declaration, receiver, {'runId': 'typed-task'})
        result = run_scenario(engine)
        self.assertIn('typed-task', receiver.entries)
        self.assertEqual(len(result['read']), 1)
        with self.assertRaisesRegex(Refusal, 'app-conflict: 409'):
            engine.call('task.put', {'id': 'typed-task', 'fulltext': '* DONE changed', 'expectedHash': 'f' * 64})
        self.assertIn('* TODO typed task', receiver.entries['typed-task']['fulltext'])


if __name__ == '__main__':
    unittest.main()
