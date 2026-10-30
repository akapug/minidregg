import base64
import copy
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
from urllib.parse import parse_qs, unquote

from binding import Engine, Refusal, Uncertain, dav_decode, digest, encode_http, decode_http, load, run_scenario, tools, validate
from ddp import DDP


class MemoryApp:
    """Independent fake HTTP/DAV/DDP receiving endpoints. No manifest templates reused."""
    def __init__(self, app):
        self.app = app
        self.requests = []
        self.files = {}
        self.directories = set()
        self.issue = None
        self.comments = []
        self.collections = {c: [] for c in ['boards', 'lists', 'swimlanes', 'cards']}
        self.count = 0

    def http(self, r):
        self.requests.append(r)
        p, m = unquote(r['path']), r['method']
        response = lambda v, status=200: (status, {'content-type': 'application/json'}, json.dumps(v).encode())
        if self.app == 'gogs':
            if p == 'api/v1/user':
                return response({'id': 1, 'login': 'member-a'})
            if p == 'api/v1/user/repos' and m == 'POST':
                value = json.loads(r['body'])
                assert value['auto_init'] and value['private']
                return response({'id': 10, 'name': value['name'], 'owner': {'id': 1, 'login': 'member-a'}}, 201)
            if p.endswith('/comments'):
                if m == 'POST':
                    self.comments.append({'id': 3, **json.loads(r['body'])})
                    return response(self.comments[-1], 201)
                return response(self.comments)
            if p.endswith('/issues') and m == 'POST':
                self.issue = {'id': 2, 'number': 1, 'state': 'open', **json.loads(r['body'])}
                return response(self.issue, 201)
            if p.endswith('/issues/1'):
                return response(self.issue)
            raise AssertionError((m, p))
        assert p.startswith('dav/')
        if m == 'MKCOL':
            self.directories.add(p); return (201, {}, b'')
        if m == 'PUT':
            self.files[p] = r['body']; return (201, {}, b'')
        if m == 'MOVE':
            destination = unquote(r['headers']['destination']).lstrip('/')
            assert r['headers']['overwrite'] == 'F'
            self.files[destination] = self.files.pop(p); return (201, {}, b'')
        if m == 'GET':
            return (200, {'content-type': 'application/octet-stream'}, self.files[p])
        if m == 'PROPFIND':
            assert r['headers']['depth'] == '1'
            href = next(k for k in self.files if k.startswith(p + '/'))
            return (207, {'content-type': 'application/xml'}, dav_xml('/' + href))
        raise AssertionError((m, p))

    def ddp(self, binding, args, context, write=False):
        # Interpret the emitted wire params through an independent simulated collection server.
        from binding import resolve
        self.requests.append((binding, args))
        if binding.get('method') == 'boardStatus':
            return {'mode': 'auto', 'lazy': False, 'cards': len(self.collections['cards'])}
        if binding['kind'] == 'snapshot':
            board = args['board']
            return {c: [copy.deepcopy(v) for v in vs if v.get('boardId', v['id']) == board]
                    for c, vs in self.collections.items()}
        self.count += 1
        doc = resolve(binding['params'], args, {**context, 'userId': 'member-a', 'nowMs': 0,
                                               'operationId': str(self.count)})[0]
        coll = binding['method'].split('/')[1]
        doc['id'] = doc.pop('_id')
        self.collections[coll].append(doc)
        return {'id': doc['id']}


def dav_xml(href='/dav/a'):
    return (f'<D:multistatus xmlns:D="DAV:"><D:response><D:href>{href}</D:href>'
            '<D:propstat><D:prop><D:resourcetype/><D:getcontentlength>8</D:getcontentlength>'
            '<D:getetag>"v1"</D:getetag></D:prop><D:status>HTTP/1.1 200 OK</D:status>'
            '</D:propstat></D:response></D:multistatus>').encode()


class Channel:
    def __init__(self, frames=()):
        self.frames = list(frames)
        self.sent = []

    def send(self, raw):
        self.sent.append(json.loads(raw))

    def settimeout(self, t):
        assert 0 < t <= 30

    def recv(self):
        if not self.frames:
            raise EOFError('lost response')
        return json.dumps(self.frames.pop(0))


class Bindings(unittest.TestCase):
    def test_davros_uses_the_canonical_base_for_move(self):
        d = load('davros')
        r = encode_http(d, d['operations']['entry.move'], {'path': 'a', 'destination': 'b'}, {})
        self.assertEqual(r['path'], 'dav/a')
        self.assertEqual(r['headers']['destination'], '/dav/b')
        record = json.loads((Path(__file__).parent / 'fixtures/davros-legacy-move-403.json').read_text())
        with self.assertRaisesRegex(Refusal, 'app-permission-denied'):
            decode_http(d, d['operations']['entry.move'],
                        (record['status'], record['headers'], record['body'].encode()))

    def test_write_server_error_is_uncertain(self):
        record = json.loads((Path(__file__).parent / 'fixtures/gogs-repo-init-500.json').read_text())
        class Broken:
            def http(self, r): return (record['status'], record['headers'], record['body'].encode())
        with self.assertRaises(Uncertain):
            Engine(load('gogs'), Broken(), {}).call('repo.create', {'name': 'x', 'description': ''})

    def test_binary_read_uses_reply_bound_not_write_bound(self):
        d = load('davros')
        class File:
            def http(self, r): return (200, {}, b'x' * (d['limits']['bodyBytes'] * 2))
        result = Engine(d, File(), {}).call('file.get', {'path': 'large.bin'})
        self.assertEqual(len(base64.b64decode(result['contentBase64'])), d['limits']['bodyBytes'] * 2)

    def test_mcp_outputs_are_objects_even_for_lists(self):
        for app in ['gogs', 'wekan', 'davros']:
            for tool in tools(load(app)):
                self.assertEqual(tool['outputSchema'].get('type'), 'object')

    def test_declaration_rejects_missing_ddp_method(self):
        from binding import check_declaration
        d = load('wekan')
        del d['operations']['card.create']['binding']['method']
        with self.assertRaisesRegex(Refusal, 'declaration-invalid'):
            check_declaration(d)

    def test_all_declarations_drive_scenarios_and_emit_same_schemas(self):
        for app in ['gogs', 'davros', 'wekan']:
            with self.subTest(app=app):
                d = load(app)
                backend = MemoryApp(app)
                self.assertTrue(run_scenario(Engine(d, backend, {'runId': 'run-001'})))
                for tool in tools(d):
                    op = d['operations'][tool['_meta']['operation']]
                    self.assertEqual(tool['inputSchema'], {**op['input'], '$defs': d['$defs']})
                    self.assertEqual(tool['_meta']['interfaceDigest'], digest(d))
                self.assertTrue(backend.requests)

    def test_gogs_query_and_json_encoding(self):
        d = load('gogs'); op = d['operations']['issue.list']
        r = encode_http(d, op, {'owner': 'alice', 'repo': 'project', 'state': 'closed', 'page': 3}, {})
        self.assertEqual(r['path'], 'api/v1/repos/alice/project/issues')
        self.assertEqual(parse_qs(r['query']), {'state': ['closed'], 'page': ['3']})
        op = d['operations']['comment.create']
        r = encode_http(d, op, {'owner': 'alice', 'repo': 'project', 'number': 42, 'body': 'λ\n"x"'}, {})
        self.assertEqual(r['path'], 'api/v1/repos/alice/project/issues/42/comments')
        self.assertEqual(json.loads(r['body']), {'body': 'λ\n"x"'})

    def test_gogs_init_selects_a_packaged_readme_template(self):
        d = load('gogs')
        r = encode_http(d, d['operations']['repo.create'], {'name': 'x', 'description': ''}, {})
        self.assertEqual(json.loads(r['body']).get('readme'), 'Default')

    def test_gogs_does_not_advertise_unsupported_all_state(self):
        # 0.11.34 compares state == closed; every other value silently means open.
        d = load('gogs')
        with self.assertRaisesRegex(Refusal, 'input-schema'):
            validate(d, d['operations']['issue.list']['input'],
                     {'owner': 'a', 'repo': 'r', 'state': 'all', 'page': 1})

    def test_schema_rejects_unknown_fields_and_wrong_types_before_dispatch(self):
        d = load('gogs'); backend = MemoryApp('gogs'); e = Engine(d, backend, {})
        for args in [{'owner': 'a', 'repo': 'r', 'number': True}, {'owner': 'a', 'repo': 'r', 'number': '1'},
                     {'owner': 'a', 'repo': 'r', 'number': 1, 'method': 'DELETE'}]:
            with self.assertRaisesRegex(Refusal, 'input-schema'):
                e.call('issue.read', args)
        self.assertEqual(backend.requests, [])

    def test_paths_and_binary_are_validated_without_coercion(self):
        d = load('davros'); backend = MemoryApp('davros'); e = Engine(d, backend, {})
        for path in ['../x', '/x', 'a//b', 'a/./b', 'a/%2e%2e/b', 'a\\b', 'a?x', 'a\r\nb']:
            with self.subTest(path=path), self.assertRaisesRegex(Refusal, 'path-invalid'):
                e.call('file.get', {'path': path})
        with self.assertRaisesRegex(Refusal, 'binary-encoding'):
            e.call('file.put', {'path': 'a', 'contentBase64': '!invalid!'})
        r = encode_http(d, d['operations']['entry.move'], {'path': 'notes/雪 a', 'destination': 'notes/雪 b'}, {})
        self.assertEqual(r['path'], 'dav/notes/%E9%9B%AA%20a')
        self.assertEqual(r['headers']['destination'], '/dav/notes/%E9%9B%AA%20b')
        self.assertEqual(backend.requests, [])

    def test_relation_mismatch_blocks_card_write(self):
        d = load('wekan'); backend = MemoryApp('wekan'); e = Engine(d, backend, {'runId': 'x'})
        backend.collections['boards'] = [{'id': 'b1', 'title': 'one', 'members': []}]
        backend.collections['lists'] = [{'id': 'l2', 'title': 'wrong board', 'boardId': 'b2'}]
        with self.assertRaisesRegex(Refusal, 'relation-not-visible-or-mismatched'):
            e.call('card.create', {'board': 'b1', 'list': 'l2', 'swimlane': 's1', 'title': 'no'})
        self.assertEqual(backend.collections['cards'], [])
        self.assertTrue(all(b['kind'] == 'snapshot' or b.get('method') == 'boardStatus' for b, _ in backend.requests))

    def test_lazy_board_never_silently_reports_an_empty_complete_list(self):
        class Lazy(MemoryApp):
            def __init__(self, app):
                super().__init__(app)
                self.collections['boards'] = [{'id': 'b', 'title': 'board', 'members': []}]
                self.collections['lists'] = [{'id': 'l', 'boardId': 'b', 'title': 'list'}]
            def ddp(self, binding, args, context, write=False):
                if binding.get('method') == 'boardStatus':
                    return {'mode': 'lazy', 'lazy': True, 'cards': 5000}
                return super().ddp(binding, args, context, write)
        with self.assertRaisesRegex(Refusal, 'precondition-failed'):
            Engine(load('wekan'), Lazy('wekan'), {}).call('card.list', {'board': 'b', 'list': 'l'})

    def test_dav_multistatus_namespaces_and_property_errors(self):
        self.assertEqual(dav_decode(dav_xml())[0], {'href': '/dav/a', 'collection': False, 'bytes': 8, 'etag': '"v1"'})
        with self.assertRaisesRegex(Refusal, 'dav-property-refused'):
            dav_decode(dav_xml().replace(b'200 OK', b'403 Forbidden'))
        with self.assertRaisesRegex(Refusal, 'dav-xml-unsafe'):
            dav_decode(b'<!DOCTYPE x [<!ENTITY x "bad">]><x/>')
        with self.assertRaisesRegex(Refusal, 'dav-response-invalid'):
            dav_decode(b'<html>not XML data</html>')

    def test_http_loss_and_malformed_success_are_uncertain_and_not_retried(self):
        d = load('gogs')
        class Lost:
            calls = 0
            def http(self, r):
                self.calls += 1
                raise EOFError()
        lost = Lost()
        with self.assertRaises(Uncertain):
            Engine(d, lost, {}).call('repo.create', {'name': 'x', 'description': ''})
        self.assertEqual(lost.calls, 1)
        class Bad:
            def http(self, r): return (201, {'content-type': 'application/json'}, b'{}')
        with self.assertRaisesRegex(Uncertain, 'reply-uninterpretable'):
            Engine(d, Bad(), {}).call('repo.create', {'name': 'x', 'description': ''})

    def test_http_auth_and_redirect_do_not_fallback_to_html(self):
        d = load('gogs')
        class Denied:
            def http(self, r): return (401, {}, b'private login page')
        with self.assertRaisesRegex(Refusal, 'app-auth-required'):
            Engine(d, Denied(), {}).call('user.read', {})
        class Redirect:
            def http(self, r): return (302, {'location': '/login'}, b'')
        with self.assertRaisesRegex(Refusal, 'app-http-status'):
            Engine(d, Redirect(), {}).call('user.read', {})

    def test_readback_assertion_catches_a_dishonest_receiver(self):
        backend = MemoryApp('davros')
        real = backend.http
        def corrupt(r):
            return (200, {}, b'wrong') if r['method'] == 'GET' else real(r)
        backend.http = corrupt
        with self.assertRaisesRegex(Refusal, 'readback-mismatch'):
            run_scenario(Engine(load('davros'), backend, {'runId': 'x'}))


class DdpState(unittest.TestCase):
    def test_malformed_method_error_is_uncertain_after_send(self):
        c = Channel([{'msg': 'result', 'id': 'm', 'error': 'not an error object'}])
        with self.assertRaises(Uncertain):
            DDP(c).finish('m', mutation=True)

    def test_unrelated_results_cannot_grow_unbounded(self):
        c = Channel([{'msg': 'result', 'id': 'foreign', 'result': 1}])
        with self.assertRaisesRegex(Refusal, 'ddp-buffer-over-bound'):
            DDP(c, limit=0).pump(__import__('time').monotonic() + 30)

    def test_result_and_updated_can_arrive_in_either_order(self):
        result = {'msg': 'result', 'id': 'm', 'result': 'doc'}
        updated = {'msg': 'updated', 'methods': ['m']}
        for frames in ([result, updated], [updated, result]):
            c = Channel([{'msg': 'ping', 'id': 'heartbeat'}, *frames]); d = DDP(c)
            self.assertEqual(d.finish('m', mutation=True), 'doc')
            self.assertEqual(c.sent, [{'msg': 'pong', 'id': 'heartbeat'}])

    def test_result_without_updated_is_uncertain(self):
        c = Channel([{'msg': 'result', 'id': 'm', 'result': 'doc'}])
        with self.assertRaises(Uncertain):
            DDP(c).finish('m', mutation=True)
        self.assertEqual(c.sent, [])

    def test_method_error_is_named(self):
        c = Channel([{'msg': 'result', 'id': 'm', 'error': {'error': 403, 'reason': 'private'}}])
        with self.assertRaisesRegex(Refusal, 'ddp-method-refused: 403'):
            DDP(c).finish('m', mutation=True)

    def test_rendezvous_posts_same_token_and_never_injects_identity(self):
        auth = load('wekan')['auth']; c = Channel(); d = DDP(c); posts = []
        def post(r):
            posts.append(r)
            sent = c.sent[0]
            self.assertEqual(sent['method'], 'loginWithSandstorm')
            self.assertEqual(sent['params'], [r['body'].decode()])
            self.assertEqual(r['headers'], {'content-type': 'application/x-sandstorm-login-token'})
            if len(posts) == 1: return (500, {}, b'')  # HTTP won the registration race
            c.frames.extend([{'msg': 'result', 'id': sent['id'], 'result': {'userId': 'member-a'}},
                             {'msg': 'updated', 'methods': [sent['id']]}])
            return (204, {}, b'')
        with patch('ddp.time.sleep'):
            self.assertEqual(d.authenticate(auth, post), 'member-a')
        self.assertEqual(len(c.sent), 1)
        self.assertEqual(len(posts), 2)

    def test_snapshot_waits_ready_applies_changed_cleared_and_removed(self):
        c = Channel(); d = DDP(c)
        original_send = c.send
        def send(raw):
            original_send(raw); sid = c.sent[-1]['id']
            c.frames.extend([
                {'msg': 'added', 'collection': 'cards', 'id': 'one', 'fields': {'title': 'before', 'obsolete': True}},
                {'msg': 'added', 'collection': 'cards', 'id': 'two', 'fields': {'title': 'deleted'}},
                {'msg': 'changed', 'collection': 'cards', 'id': 'one', 'fields': {'title': 'after'}, 'cleared': ['obsolete']},
                {'msg': 'removed', 'collection': 'cards', 'id': 'two'},
                {'msg': 'ready', 'subs': [sid]}])
        c.send = send
        got = d.snapshot({'publication': 'board', 'params': [{'arg': 'board'}, False], 'collections': ['cards']}, {'board': 'b'}, {})
        self.assertEqual(got, {'cards': [{'id': 'one', 'title': 'after'}]})
        self.assertEqual(DDP(Channel()).documents, {})  # new member starts with no prior projection

    def test_subscription_refusal_and_snapshot_bound(self):
        c = Channel(); d = DDP(c, limit=0)
        c.frames = [{'msg': 'added', 'collection': 'cards', 'id': 'one'}]
        with self.assertRaisesRegex(Refusal, 'ddp-snapshot-over-bound'):
            d.pump(__import__('time').monotonic() + 30)
        c = Channel(); original = c.send
        def send(raw):
            original(raw); c.frames.append({'msg': 'nosub', 'id': c.sent[-1]['id'], 'error': {'error': 403}})
        c.send = send
        with self.assertRaisesRegex(Refusal, 'ddp-subscription-refused'):
            DDP(c).snapshot({'publication': 'board', 'params': [], 'collections': []}, {}, {})


if __name__ == '__main__':
    Path('scratch/cx-app-interface/tests.pid').write_text(str(os.getpid()))
    unittest.main()
