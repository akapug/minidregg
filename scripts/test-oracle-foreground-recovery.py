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
import subprocess
import os
import unittest
from unittest.mock import patch

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

    def test_hardlinked_binary_refuses_before_prepared_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            run=Path(tmp);(run/'world/evidence').mkdir(parents=True);(run/'continuations').mkdir()
            (run/'world-identity.json').write_text(json.dumps({'store':'fixture'}))
            source=run/'source';source.write_bytes(b'fixture')
            linked=run/'runtime';linked.hardlink_to(source)
            pin={'path':str(source),'sha256':hashlib.sha256(source.read_bytes()).hexdigest()}
            plan={'protocol':'mini-oracle-foreground-recovery-plan-v1','run':str(run),'store':'fixture','operation_id':13}
            for key in ('predecessor_export','predecessor_status','runtime','public_mini','spk','inventory','benchmark','qualification_manifest'):
                plan[key]=pin.copy()
            plan['runtime']['path']=str(linked)
            path=run/'plan.json';path.write_text(json.dumps(plan))
            output=run/'continuations/foreground-13'
            with patch.object(r,'verify_lock'), self.assertRaisesRegex(ValueError,'exactly one hardlink'):
                r.prepare(path,run/'unused-export',run/'unused-status',run/'unused-sources',output)
            self.assertFalse(output.exists())

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

    def test_public_binary_selection_checks_stopped_pin_without_repeating_upgrade(self):
        source=(ROOT/'deploy/oracle/acceptance/world.sh').read_text()
        start=source.index('  if [[ $old_mini == "$new_mini" ]]; then')
        branch=source[start:source.index('\n  fi\n',start)+len('\n  fi\n')]
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);installer=root/'installer';calls=root/'calls'
            installer.write_text('#!/usr/bin/env python3\nimport json,os,sys\nopen(os.environ["CALLS"],"a").write(sys.argv[1]+"\\n")\nprint(os.environ["STATUS"])\n')
            installer.chmod(0o755)
            for index,(old,new,stopped,wanted,ok) in enumerate((
                ('same','same',True,'same',True),('old','new',True,'new',True),
                ('same','same',False,'same',False),('same','same',True,'wrong',False))):
                continuation=root/str(index);continuation.mkdir();calls.write_text('')
                setup=f'installer={installer}; continuation={continuation}; old_mini={old}; new_mini={new}; candidate=/fixture; store=fixture; helper=/helper;'
                setup+='timeout() { shift; "$@"; }; sudo() { shift 2; "$@"; }; fail() { exit 19; };'
                result=subprocess.run(['bash','-eu','-c',setup+branch],env={**os.environ,'CALLS':str(calls),
                    'STATUS':json.dumps({'stopped':stopped,'publicListener':{'binarySha256':wanted}})},capture_output=True)
                self.assertEqual(result.returncode==0,ok,result.stderr)
                self.assertEqual(calls.read_text().splitlines(),['controller-status' if old==new else 'controller-public-listener-upgrade'])
                if ok and old==new:self.assertEqual(json.loads((continuation/'public-listener.json').read_bytes())['publicListenerSelection'],'already-qualified')

    def test_terminal_refusal_boundary_requires_consumed_ordinal_and_native_evidence(self):
        request,export=self.fixture()
        self.change_journal(export,lambda j:j.update(birthNextOrdinal={'oracle-session':1}))
        prefix='attempt-0000000000000039/'
        def add(name,raw):
            export['files'][name]={'sha256':hashlib.sha256(raw).hexdigest(),'base64':base64.b64encode(raw).decode()}
        add(prefix+'attempt.json',b'{}');add(prefix+'pre-submit-refusal.frame',b'native refusal frame')
        proof={'type':'minidregg-pre-submit-refusal-v1','stage':'prepare','operation':1,
               'frameSha256':hashlib.sha256(b'native refusal frame').hexdigest(),
               'attemptManifestSha256':hashlib.sha256(b'{}').hexdigest()}
        add(prefix+'pre-submit-refusal.json',json.dumps(proof).encode())
        add(prefix+'prepare-refusal-verify-fixture/outcome.json',json.dumps({
            'type':'refused','reason':'law-denied','phase':'70726570617265'}).encode())
        r.prebirth(export,'fixture',request,13,39)
        with self.assertRaises(ValueError):r.prebirth(export,'fixture',request,13)
        for marker in ('call.bin','submit-marker.json','outcome.bin'):
            bad=copy.deepcopy(export);bad['files'][prefix+marker]={'sha256':hashlib.sha256(b'x').hexdigest(),'base64':base64.b64encode(b'x').decode()}
            with self.assertRaises(ValueError):r.prebirth(bad,'fixture',request,13,39)
        bad=copy.deepcopy(export);self.change_journal(bad,lambda j:j.update(birthNextOrdinal={'oracle-session':2}))
        with self.assertRaises(ValueError):r.prebirth(bad,'fixture',request,13,39)
        plan={'run':'/fixture','operation_id':13,'goal':'settle-refusal','native_operation_id':39}
        self.assertEqual(str(r.evidence_directory(plan)),'/fixture/continuations/foreground-13-refusal-settlement')
        with self.assertRaises(ValueError):r.settle_only(dict(plan,goal='automatic-retry'))

    def test_terminal_result_joins_typed_refusal_and_all_settlements(self):
        request='ab'*16;plan={'request_id':request,'operation_id':13,'store':'fixture',
                             'goal':'settle-refusal','native_operation_id':39}
        payload={'type':'mini-resource-birth-refused-v1','reason':'law-denied','phase':'prepare',
                 'born':False,'toolCharge':'0','nativeOperationId':'39'}
        def fixture(body=payload):
            result={'isError':True,'text':json.dumps(body)};raw=json.dumps(result).encode();digest=hashlib.sha256(raw).hexdigest()
            recovered={'type':'mini-foreground-session-recovery-v1','requestId':request,'operationId':'13',
                       'resultSha256':digest,'resultReady':True,'acknowledged':False}
            retained={'type':'tool-complete','requestId':request,'operationId':'13','isError':True,'result':result}
            journal={'binding':{'config':{'stateDir':'/private/state'}},'foregroundAttempt':{
                'requestId':request,'operationId':13,'phase':'definite','reported':False,
                'resultPath':'/private/state/foreground-0000000000000013.result.json','resultSha256':digest},
                'bornResources':[],'birthNextOrdinal':{'oracle-session':1},'unresolvedExternal':[]}
            files={'journal.json':json.dumps(journal).encode(),'foreground-0000000000000013.result.json':raw}
            exported={'protocol':'mini-spk-controller-evidence-v1','store':'fixture','files':{name:{
                'sha256':hashlib.sha256(data).hexdigest(),'base64':base64.b64encode(data).decode()} for name,data in files.items()}}
            return recovered,retained,journal,exported
        r.validate_result(plan,*fixture())
        for key,value in [('type','other-error'),('reason','unknown'),('phase','submit'),('born',True),('toolCharge','1'),('nativeOperationId','40')]:
            with self.subTest(key=key),self.assertRaises(ValueError):r.validate_result(plan,*fixture(dict(payload,**{key:value})))
        for key,value in [('parentHold',{'reserve':'1'}),('bornResources',[{'target':'29420'}]),('dispatchPending',{'pending':True}),('unresolvedExternal',['unknown'])]:
            recovered,retained,journal,exported=fixture();journal[key]=value
            raw=json.dumps(journal).encode();exported['files']['journal.json']={'sha256':hashlib.sha256(raw).hexdigest(),'base64':base64.b64encode(raw).decode()}
            with self.subTest(key=key),self.assertRaises(ValueError):r.validate_result(plan,recovered,retained,journal,exported)
        recovered,retained,journal,exported=fixture();recovered['resultSha256']='0'*64
        with self.assertRaises(ValueError):r.validate_result(plan,recovered,retained,journal,exported)
        with self.assertRaises(ValueError):r.validate_result(dict(plan,goal='resume-session'),*fixture())

    def test_terminal_shell_returns_after_ack_without_grant(self):
        source=(ROOT/'deploy/oracle/acceptance/world.sh').read_text()
        start=source.index('  if [[ ${preserve_retained_namespace:-0} == 1 ]]; then')
        end=source.index('  (set -o noclobber; cat "$continuation/retained-result.json"',start)
        branch=source[start:end]
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);calls=root/'calls';installer=root/'installer'
            installer.write_text('#!/usr/bin/env python3\nimport json,os,sys\nopen(os.environ["CALLS"],"a").write(sys.argv[1]+"\\n")\nprint(json.dumps({"type":"tool-acknowledged","requestId":"fixture"}) if sys.argv[1]=="controller-tool-ack" else "{}")\n')
            installer.chmod(0o755)
            setup='timeout() { shift; "$@"; }; sudo() { shift 2; "$@"; }; world_phase_record() { :; };'
            setup+=f'installer={installer}; continuation={root}; store=fixture; helper=/helper; request_id=fixture; preserve_retained_namespace=1;'
            result=subprocess.run(['bash','-eu','-c',setup+'finish() {\n'+branch+'echo unexpected-grant; }; finish; test "$foreground_settlement_only" = 1'],
                                  env={**os.environ,'CALLS':str(calls)},capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual(calls.read_text().splitlines(),['controller-tool-ack','controller-journal'])
            self.assertNotIn('unexpected-grant',result.stdout)

    def test_successful_terminal_cleanup_preserves_namespace(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);(root/'continuation').mkdir();calls=root/'calls'
            setup='source "$REPO/deploy/oracle/acceptance/world.sh"; '
            setup+='world_controller_stop() { :; }; systemctl() { :; }; journalctl() { :; }; '
            setup+='world_cleanup_volumes() { printf "%s\\n" "$1" > "$CALLS"; }; '
            setup+='sudo() { echo forbidden-remove >&2; return 99; }; '
            setup+='configured=1; controller_created=1; controller_staged=0; preserve_retained_namespace=1; preserve_existing_exit=0; '
            setup+='run=$RUN; continuation=$RUN/continuation; repo=$REPO; journey=/usr/bin/true; store=fixture; helper=/helper; installer=/installer; units=/unused; state=; world_cleanup 0'
            result=subprocess.run(['bash','-eu','-c',setup],env={**os.environ,'REPO':str(ROOT),'RUN':str(root),'CALLS':str(calls)},capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual(calls.read_text().strip(),'true')
            self.assertEqual(json.loads((root/'continuation/exit.json').read_bytes()),{
                'execution_exit':0,'cleanup_exit':0,'namespace_preserved':True})

    def test_shell_recovery_has_one_fixed_admin_and_no_tool_resubmission(self):
        source=(ROOT/'deploy/oracle/acceptance/world.sh').read_text()
        body=source.split('world_recover_foreground() {',1)[1].split('\n}\n',1)[0]
        self.assertEqual(body.count('"$installer" controller-recover-session'),1)
        self.assertNotIn('controller-tool "',body)
        self.assertNotIn('tool-id',body)
        self.assertLess(body.index('recover_foreground.py" result'),body.index('controller-tool-ack'))


if __name__=='__main__':unittest.main()
