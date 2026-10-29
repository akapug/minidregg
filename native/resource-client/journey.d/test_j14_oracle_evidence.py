import copy
import importlib.util
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('evidence',Path(__file__).with_name('j14-oracle-evidence.py'))
evidence=importlib.util.module_from_spec(spec);spec.loader.exec_module(evidence)

class EvidenceTests(unittest.TestCase):
    def setUp(self):
        import json
        http={'protocol':'mini-spk-agent-api-v3','type':'http-v3','status':200,
              'bodyText':json.dumps({'outcome':'completed','operation_id':'core.query','reply':{'status':'answered','response':'Walt Whitman.'}}),
              'operationId':'77','committedReceipt':{'native':'receipt'},'responseSha256':'a'*64,
              'bindingSha256':'b'*64,'operationFingerprint':'c'*64}
        self.log=[{'id':'or-call','question':'Who wrote Leaves of Grass?','result':{'ok':http}}]
        self.journal={'applicationApiHistory':[{'operationId':77,'routeName':'oracle-app','phase':'definite','reported':True,
            'bindingSha256':http['bindingSha256'],'operationFingerprint':http['operationFingerprint'],
            'lifetimeCommittedReceipt':http['committedReceipt'],'lifetimeSettledResponseSha256':http['responseSha256'],
            'lifetimeSettlement':{'forwardOperationId':77,'settlement':{'operation':'dispatch settle'}}}]}
    def check(self):return evidence.answered(self.log,self.journal,route='oracle-app',expected='Whitman',question='Who wrote Leaves of Grass?')
    def test_answer_joins_exact_native_settlement(self):self.assertEqual(self.check()['operationId'],'77')
    def test_old_success_cannot_hide_last_refusal(self):
        self.log.append({'id':'or-call','question':'Who wrote Leaves of Grass?','result':{'error':'oracle-not-granted'}})
        with self.assertRaisesRegex(ValueError,'last Oracle'):self.check()
    def test_http_answer_without_settlement_is_not_success(self):
        self.journal['applicationApiHistory'][0]['lifetimeSettlement']={}
        with self.assertRaisesRegex(ValueError,'not settled'):self.check()
    def test_empty_or_unrelated_body_is_not_success(self):
        self.log[0]['result']['ok']['bodyText']='{}'
        with self.assertRaisesRegex(ValueError,'selected query'):self.check()
    def test_different_receipt_or_duplicate_native_attempt_is_not_success(self):
        original=copy.deepcopy(self.journal)
        self.journal['applicationApiHistory'][0]['lifetimeCommittedReceipt']={}
        with self.assertRaisesRegex(ValueError,'differs'):self.check()
        self.journal=original;self.journal['applicationApiHistory']*=2
        with self.assertRaisesRegex(ValueError,'exactly one'):self.check()

if __name__=='__main__':unittest.main()
