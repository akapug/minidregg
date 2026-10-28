import json
from pathlib import Path
import unittest
from urllib.parse import unquote

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


if __name__ == '__main__':
    unittest.main()
