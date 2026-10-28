"""Bounded readiness waits cannot redispatch mutations or conceal real refusals."""
import copy
import json
from unittest import TestCase, main
from binding import ROOT, Engine, Refusal, check_declaration, run_scenario

class Replies:
    def __init__(self, replies):
        self.replies = iter(replies)
        self.calls = 0
    def http(self, request):
        self.calls += 1
        return next(self.replies)

class AwaitReadiness(TestCase):
    def declaration(self):
        d = json.loads((ROOT / 'swagger-editor.json').read_text())
        d['qualification'] = [{'id': 'read', 'op': 'spec.get', 'args': {},
            'await': {'attempts': 3, 'intervalSeconds': 0, 'retryStatuses': [502]},
            'assert': [{'path': [], 'equals': 'ready'}]}]
        return d

    def test_only_declared_read_statuses_and_assertions_are_polled(self):
        d = self.declaration()
        check_declaration(d)
        transport = Replies([(502, {}, b''), (200, {}, b'pending'), (200, {}, b'ready')])
        self.assertEqual(run_scenario(Engine(d, transport, {})), {'read': 'ready'})
        self.assertEqual(transport.calls, 3)

    def test_mutation_wait_is_refused_before_dispatch(self):
        d = self.declaration()
        d['qualification'][0].update(op='spec.put', args={'yaml': 'never dispatched'})
        with self.assertRaises(Refusal):
            check_declaration(d)

    def test_auth_and_undeclared_status_do_not_poll(self):
        for status, reason in [(403, 'app-permission-denied'), (503, 'app-http-status')]:
            d = self.declaration()
            transport = Replies([(status, {}, b''), (200, {}, b'ready')])
            with self.assertRaises(Refusal) as raised:
                run_scenario(Engine(d, transport, {}))
            self.assertEqual(raised.exception.name, reason)
            self.assertEqual(transport.calls, 1)

    def test_assertion_mismatch_stops_at_bound(self):
        d = self.declaration()
        transport = Replies([(200, {}, b'pending')] * 3)
        with self.assertRaises(Refusal) as raised:
            run_scenario(Engine(d, transport, {}))
        self.assertEqual(raised.exception.name, 'readback-mismatch')
        self.assertEqual(transport.calls, 3)

if __name__ == '__main__':
    main()
