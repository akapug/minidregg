"""A useful read-only tool must not masquerade as a write/read-back qualification."""
import unittest
import binding


class QualificationGate(unittest.TestCase):
    def declaration(self, steps):
        return {'operations': {'put': {'write': True}, 'get': {'write': False}},
                'qualification': steps}

    def test_no_write_or_no_later_asserted_read_is_refused(self):
        for steps in ([], [{'op': 'get', 'assert': [{'path': [], 'equals': 1}]}],
                      [{'op': 'put'}], [{'op': 'put'}, {'op': 'get'}],
                      [{'op': 'get', 'assert': [{}]}, {'op': 'put'}]):
            with self.subTest(steps=steps):
                with self.assertRaisesRegex(binding.Refusal, 'qualification-write-readback-absent'):
                    binding.require_write_readback(self.declaration(steps))

    def test_write_then_asserted_read_can_qualify(self):
        binding.require_write_readback(self.declaration([
            {'op': 'put'}, {'op': 'get', 'assert': [{'path': [], 'equals': 1}]}]))

    def test_correlated_compound_event_is_readback_without_resubscribing(self):
        d = self.declaration([{'op': 'put', 'assert': [{'contains': {'url': 'unique'}}]}])
        d['operations']['put']['binding'] = {
            'protocol': 'conversation',
            'steps': [{'id': 'beacon', 'http': {'method': 'GET'}},
                      {'id': 'hit', 'receive': {'where': [{'path': [0], 'contains': {'url': 'unique'}}]}}],
            'result': {'result': ['hit', 0]}}
        binding.require_write_readback(d)
        for bad in ('earlier', 'unreturned', 'uncorrelated'):
            import copy
            changed = copy.deepcopy(d)
            b = changed['operations']['put']['binding']
            if bad == 'earlier': b['steps'].reverse()
            elif bad == 'unreturned': b['result'] = {'ok': True}
            else: b['steps'][1]['receive']['where'] = []
            with self.subTest(bad=bad), self.assertRaisesRegex(binding.Refusal, 'qualification-write-readback-absent'):
                binding.require_write_readback(changed)
