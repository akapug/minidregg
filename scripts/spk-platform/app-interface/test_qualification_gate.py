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
