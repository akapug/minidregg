"""Typed data boundaries; these checks exercise declarations, never application recipes."""
import json
from pathlib import Path
import unittest
from binding import check_declaration, encode_http, validate, Refusal, ROOT

class DataDeclarations(unittest.TestCase):
    def declaration(self, name):
        d = json.loads((ROOT / (name + '.json')).read_text())
        check_declaration(d)
        return d

    def test_notebook_contents_preserve_structured_cells(self):
        d = self.declaration('ipython-notebook')
        op = d['operations']['notebook.put']
        nb = {'nbformat': 4, 'nbformat_minor': 0, 'metadata': {}, 'cells': [
            {'cell_type': 'code', 'metadata': {}, 'source': '6 * 7', 'execution_count': 1,
             'outputs': [{'output_type': 'execute_result', 'data': {'text/plain': '42'}, 'metadata': {}, 'execution_count': 1}]}]}
        args = {'path': 'analysis/with space.ipynb', 'notebook': nb}
        validate(d, op['input'], args)
        req = encode_http(d, op, args, {})
        self.assertEqual(req['path'], 'api/contents/analysis/with%20space.ipynb')
        self.assertEqual(json.loads(req['body']), {'type': 'notebook', 'content': nb})
        with self.assertRaises(Refusal):
            validate(d, op['input'], {**args, 'path': '../secret.ipynb'})

    def test_expense_requires_positive_amount_before_dispatch(self):
        d = self.declaration('expenseowl')
        op = d['operations']['expense.create']
        with self.assertRaises(Refusal):
            validate(d, op['input'], {'name': 'bad', 'category': 'Other', 'amount': -3, 'date': '2026-10-28T12:00:00Z'})

    def test_editor_text_roundtrip_is_not_literal_template(self):
        d = self.declaration('swagger-editor')
        op = d['operations']['spec.put']
        req = encode_http(d, op, {'yaml': 'Unicode: λ\nsecond line'}, {})
        self.assertEqual(req['body'], 'Unicode: λ\nsecond line'.encode())

    def test_poll_is_finite_and_topic_is_one_segment(self):
        d = self.declaration('sntfy')
        op = d['operations']['notifications.poll']
        req = encode_http(d, op, {'topic': 'jobs', 'since': 'all'}, {})
        self.assertEqual(req['query'], 'poll=1&since=all')
        with self.assertRaises(Refusal):
            validate(d, op['input'], {'topic': '../private', 'since': 'all'})

if __name__ == '__main__':
    unittest.main()
