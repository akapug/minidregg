#!/usr/bin/env python3
"""Harness predicates only. These mocks never qualify native recovery."""
import base64
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'deploy/oracle/acceptance'))
spec=importlib.util.spec_from_file_location('recover_foreground',ROOT/'deploy/oracle/acceptance/recover_foreground.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)


class RecoveryTests(unittest.TestCase):
    def fixture(self):
        request_id='ab'*16; state='/private/state'
        request={'requestId':request_id,'name':'mini_create_application_session',
                 'arguments':{'application':'oracle-bootstrap-app','family':'oracle-session'}}
        raw=json.dumps(request).encode();digest=hashlib.sha256(raw).hexdigest()
        attempt={'requestId':request_id,'operationId':13,'name':request['name'],'phase':'uncertain',
                 'requestPath':state+'/foreground-0000000000000013.request.json','requestSha256':digest,
                 'resultPath':None,'resultSha256':None,'reported':False}
        journal={'format':'minidregg-grain-runtime-v1','binding':{'config':{'stateDir':state}},
                 'foregroundAttempt':attempt,'bornResources':[],'birthNextOrdinal':{},'unresolvedExternal':[],
                 'parentHold':{'reserveConfirmed':True,'reserveRefused':False,'reserve':'1','charge':'0',
                               'reserveAttempt':state+'/attempt-0000000000000016','reserveBoundary':'boundary'}}
        files={'journal.json':json.dumps(journal).encode(),'foreground-0000000000000013.request.json':raw,
               'foreground-request-'+request_id+'.json':json.dumps({k:attempt[k] for k in ('requestId','operationId','requestSha256')}).encode(),
               'attempt-0000000000000016/call.bin':b'retained native call',
               'attempt-0000000000000016/outcome.bin':b'native confirmed outcome',
               'attempt-0000000000000016/outcome.json':json.dumps({'type':'confirmed','confirmation':'installed','worldRoot':'boundary'}).encode()}
        export={'protocol':'mini-spk-controller-evidence-v1','store':'fixture','files':{name:{'sha256':hashlib.sha256(data).hexdigest(),'base64':base64.b64encode(data).decode()} for name,data in files.items()}}
        return request_id,export

    def change_journal(self,export,change):
        value=json.loads(base64.b64decode(export['files']['journal.json']['base64']))
        change(value);raw=json.dumps(value).encode()
        export['files']['journal.json']={'base64':base64.b64encode(raw).decode(),'sha256':hashlib.sha256(raw).hexdigest()}

    def test_exact_prebirth_hold_is_preserved_and_never_authorizes_resend(self):
        request,export=self.fixture();original=copy.deepcopy(export)
        boundary=r.prebirth(export,'fixture',request,13)
        self.assertEqual(boundary['operation_id'],13)
        self.assertEqual(boundary['parent_hold']['reserve'],'1')
        self.assertEqual(export,original)

    def test_changed_or_effectful_boundary_refuses(self):
        changes=[lambda j:j['foregroundAttempt'].update(operationId=14),
                 lambda j:j['foregroundAttempt'].update(resultPath='/result'),
                 lambda j:j.update(birthPending={'possiblySubmitted':True}),
                 lambda j:j.update(bornResources=[{'target':'session'}]),
                 lambda j:j.update(toolHold={'reserve':'5'}),
                 lambda j:j['parentHold'].update(reserveConfirmed=False),
                 lambda j:j['parentHold'].update(reserve='2')]
        for change in changes:
            with self.subTest(change=change):
                request,export=self.fixture();self.change_journal(export,change)
                with self.assertRaises(ValueError):r.prebirth(export,'fixture',request,13)
        request,export=self.fixture()
        export['files']['foreground-0000000000000013.request.json']['sha256']='0'*64
        with self.assertRaises(ValueError):r.prebirth(export,'fixture',request,13)

    def test_definite_result_requires_exact_request_and_settled_native_journal(self):
        request='ab'*16;plan={'request_id':request,'operation_id':13,'store':'fixture'}
        result={'isError':False,'text':'native session result'}
        raw=json.dumps(result).encode();digest=hashlib.sha256(raw).hexdigest()
        recovered={'type':'mini-foreground-session-recovery-v1','requestId':request,'operationId':'13',
                   'resultSha256':digest,'resultReady':True,'acknowledged':False}
        retained={'type':'tool-complete','requestId':request,'operationId':'13','isError':False,'result':result}
        journal={'binding':{'config':{'stateDir':'/private/state'}},
                 'foregroundAttempt':{'requestId':request,'operationId':13,'phase':'definite','reported':False,
                     'resultPath':'/private/state/foreground-0000000000000013.result.json','resultSha256':digest},
                 'bornResources':[{'target':'29420'},{'target':'29421'}]}
        files={'journal.json':json.dumps(journal).encode(),'foreground-0000000000000013.result.json':raw}
        exported={'protocol':'mini-spk-controller-evidence-v1','store':'fixture','files':{name:{
            'sha256':hashlib.sha256(data).hexdigest(),'base64':base64.b64encode(data).decode()} for name,data in files.items()}}
        r.validate_result(plan,recovered,retained,journal,exported)
        for field,value in [('parentHold',{'reserve':'1'}),('toolPending',{'uncertain':True})]:
            bad=copy.deepcopy(journal);bad[field]=value
            with self.assertRaises(ValueError):r.validate_result(plan,recovered,retained,bad,exported)
        for field,value in [('acknowledged',True),('requestId','cd'*16),('resultSha256','0'*64),('resultReady',False)]:
            bad=copy.deepcopy(recovered);bad[field]=value
            with self.assertRaises(ValueError):r.validate_result(plan,bad,retained,journal,exported)
        bad=copy.deepcopy(retained);bad['result']['text']='different result'
        with self.assertRaises(ValueError):r.validate_result(plan,recovered,bad,journal,exported)

    def test_report_joins_recovery_without_rewriting_original_failure(self):
        report_spec=importlib.util.spec_from_file_location('oracle_report',ROOT/'deploy/oracle/acceptance/report.py')
        report=importlib.util.module_from_spec(report_spec);report_spec.loader.exec_module(report)
        with tempfile.TemporaryDirectory() as tmp:
            run=Path(tmp);directory=run/'continuations/foreground-13'
            (directory/'prior').mkdir(parents=True);(directory/'phases').mkdir()
            (run/'agent-lifetime').mkdir()
            def write(path,value):
                path.write_text(json.dumps(value));return hashlib.sha256(path.read_bytes()).hexdigest()
            request,export=self.fixture()
            predecessor=run/'predecessor.json';write(predecessor,export)
            write(run/'world-identity.json',{'store':'fixture'})
            original=run/'agent-lifetime/session-birth.result.json'
            original_sha=write(original,{'type':'tool-complete','requestId':request,'operationId':'13','isError':True})
            runtime=run/'runtime';runtime.write_bytes(b'qualified fixture runtime')
            mini=run/'mini';mini.write_bytes(b'qualified fixture mini')
            qualification=run/'qualified.txt'
            qualification.write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p)+'\n' for p in (runtime,mini)))
            pin=lambda p:{'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
            plan={'run':str(run),'store':'fixture','request_id':request,'operation_id':13,
                  'predecessor_export':pin(predecessor),'runtime':pin(runtime),'public_mini':pin(mini),
                  'qualification_manifest':pin(qualification)}
            prepared={'protocol':'mini-oracle-foreground-recovery-prepared-v1','plan':plan,
                'snapshot_files':{},'source_manifest':{},'resend':False,'automatic_retry':False,
                'acknowledge_before_settlement':False,'original_result_sha256':original_sha,
                'boundary':r.prebirth(export,'fixture',request,13)}
            write(directory/'prepared.json',prepared)
            result={'isError':False,'text':'native result'};raw=json.dumps(result).encode()
            digest=hashlib.sha256(raw).hexdigest()
            receipt={'type':'mini-foreground-session-recovery-v1','requestId':request,'operationId':'13',
                'resultSha256':digest,'resultReady':True,'acknowledged':False}
            retained={'type':'tool-complete','requestId':request,'operationId':'13','isError':False,'result':result}
            journal={'binding':{'config':{'stateDir':'/private/state'}},'foregroundAttempt':{
                'requestId':request,'operationId':13,'phase':'definite','reported':False,'resultSha256':digest,
                'resultPath':'/private/state/foreground-0000000000000013.result.json'},
                'bornResources':[{'target':'29420'},{'target':'29421'}]}
            files={'journal.json':json.dumps(journal).encode(),'foreground-0000000000000013.result.json':raw}
            settled={'protocol':'mini-spk-controller-evidence-v1','store':'fixture','files':{name:{
                'sha256':hashlib.sha256(data).hexdigest(),'base64':base64.b64encode(data).decode()} for name,data in files.items()}}
            for name,value in [('recovery-result.json',receipt),('retained-result.json',retained),
                               ('settled-journal.json',journal),('settled-export.json',settled)]:write(directory/name,value)
            write(run/'agent-lifetime/session-birth.retained-result.json',retained)
            write(run/'agent-lifetime/session-birth.ack.json',{'type':'tool-acknowledged','requestId':request})
            for name in ('runtime-upgrade','public-listener-upgrade','services','controller-start',
                         'exact-foreground-recovery','session-grant'):
                start=directory/'phases'/(name+'.started.json');digest=write(start,{'phase':name,'state':'started'})
                write(directory/'phases'/(name+'.completed.json'),{'phase':name,'state':'completed',
                    'started_sha256':digest,'permits_automatic_retry':False,'evidence':{}})
            def require(name,condition):self.assertTrue(condition,name)
            evidence=report.foreground_recovery(run,require)
            self.assertEqual(evidence['receipt'],receipt)
            self.assertEqual(report.sha(original),original_sha)
            write(original,retained)
            with self.assertRaises(AssertionError):report.foreground_recovery(run,require)

    def test_shell_recovery_has_one_fixed_admin_and_no_tool_resubmission(self):
        source=(ROOT/'deploy/oracle/acceptance/world.sh').read_text()
        body=source.split('world_recover_foreground() {',1)[1].split('\n}\n',1)[0]
        self.assertEqual(body.count('"$installer" controller-recover-session'),1)
        self.assertNotIn('controller-tool "',body)
        self.assertNotIn('tool-id',body)
        self.assertLess(body.index('recover_foreground.py" result'),body.index('controller-tool-ack'))


if __name__=='__main__':unittest.main()
