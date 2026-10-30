import copy
import unittest

from binding import Engine, Refusal, Uncertain, decode_http, load


def operation(mode='json-string-fragment', internal=True):
    return {'write': False, 'internal': internal,
            'binding': {'decode': mode, 'status': [200],
                        'fragment': {'prefix': 'csrfToken: ', 'suffix': ','}}}


class AuthFragments(unittest.TestCase):
    def test_fixed_json_string_fragment_and_refusal_poles(self):
        declaration = {'limits': {'replyBytes': 1024}}
        op = operation()
        self.assertEqual(decode_http(declaration, op, (200, {}, b'flags:{ csrfToken: "abc\\u003d", data:0 }')), 'abc=')
        for body in [b'no token', b'csrfToken: "one", csrfToken: "two",',
                     b'csrfToken: {"token":"wrong-type"},', b'csrfToken: "abc";',
                     b'csrfToken: "\\ud800",', b'csrfToken: "unfinished']:
            with self.assertRaises(Refusal):
                decode_http(declaration, op, (200, {}, body))
        with self.assertRaises(Refusal):
            decode_http(declaration, operation(internal=False), (200, {}, b'csrfToken: "secret",'))

    def test_header_projection_is_orthogonal_and_bounded(self):
        declaration = {'limits': {'replyBytes': 1024}}
        op = operation('text')
        op['binding']['responseHeaders'] = {'version': 'x-sandstorm-app-data-version'}
        response = (200, {'x-sandstorm-app-data-version': '12'}, b'body')
        self.assertEqual(decode_http(declaration, op, response), {'body': 'body', 'headers': {'version': '12'}})
        for headers in [{}, {'x-sandstorm-app-data-version': 'bad\r\nheader'},
                        {'x-sandstorm-app-data-version': 'x' * 4097}]:
            with self.assertRaises(Refusal):
                decode_http(declaration, op, (200, headers, b'body'))
        for forbidden in ['set-cookie', 'authorization', 'www-authenticate', 'x-arbitrary-secret']:
            unsafe = copy.deepcopy(op)
            unsafe['binding']['responseHeaders'] = {'value': forbidden}
            with self.assertRaises(Refusal):
                decode_http(declaration, unsafe, (200, {forbidden: 'secret'}, b'body'))

    def test_successful_write_with_missing_reply_header_is_uncertain(self):
        declaration = load('filedrop')
        declaration['operations']['file.put']['binding']['responseHeaders'] = {'version': 'etag'}
        class Receiver:
            calls = 0
            def http(self, request):
                self.calls += 1
                return 201, {}, b''
        receiver = Receiver()
        with self.assertRaises(Uncertain):
            Engine(declaration, receiver, {}).call('file.put', {'path': 'test.bin', 'contentBase64': 'AA=='})
        self.assertEqual(receiver.calls, 1)

    def test_empty_json_default_does_not_replace_nonempty_invalid_data(self):
        declaration = {'limits': {'replyBytes': 1024}}
        op = operation('json')
        op['binding']['emptyValue'] = {'jobs': []}
        self.assertEqual(decode_http(declaration, op, (200, {'content-type': 'application/json'}, b'')), {'jobs': []})
        for body in [b' ', b'\n', b'{broken']:
            with self.assertRaises(Refusal):
                decode_http(declaration, op, (200, {'content-type': 'application/json'}, body))
        with self.assertRaises(Refusal):
            decode_http(declaration, op, (500, {'content-type': 'application/json'}, b''))


if __name__ == '__main__':
    unittest.main()
