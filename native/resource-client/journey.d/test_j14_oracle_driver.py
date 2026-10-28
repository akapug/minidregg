"""Physical readiness regression; no native admission or external services."""
import importlib.util
from pathlib import Path
import socket
import os
import tempfile
import threading
import time
import unittest
import sys
from unittest.mock import patch
from types import SimpleNamespace

spec=importlib.util.spec_from_file_location('j14_oracle_driver',Path(__file__).with_name('j14-oracle.py'))
driver=importlib.util.module_from_spec(spec);spec.loader.exec_module(driver)

class ReadinessTests(unittest.TestCase):
    def test_start_requires_native_idle_readiness_for_the_selected_task(self):
        with tempfile.TemporaryDirectory() as directory:
            response=Path(directory)/'idle.json'
            j=driver.Journey.__new__(driver.Journey);j.c={'taskBase':'100'}
            correct={'type':'mini-grain-idle-readiness-v1','ready':True,'task':'101'}
            for value,accepted in [(correct,True),({**correct,'task':'102'},False),({**correct,'ready':False},False),({'socketReady':True},False)]:
                response.write_text(driver.json.dumps(value))
                with patch.object(j,'fixed',return_value=response) as fixed:
                    if accepted:j.start_controller()
                    else:
                        with self.assertRaisesRegex(ValueError,'native idle readiness'):j.start_controller()
                    self.assertEqual([call.args for call in fixed.call_args_list],[('controller-start',),('controller-prepare-idle',)])

    def test_retained_socket_inode_is_not_a_ready_listener(self):
        with tempfile.TemporaryDirectory(prefix='j14-ready-',dir='/tmp') as root:
            path=Path(root)/'listener.sock'
            stale=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM);stale.bind(str(path));stale.close()
            ready=threading.Event()
            def listener():
                time.sleep(.15)
                path.unlink()
                with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as server:
                    server.bind(str(path));server.listen();ready.set()
                    server.settimeout(3)
                    connection,_=server.accept();connection.close()
            worker=threading.Thread(target=listener,daemon=True);worker.start()
            driver.Journey.__new__(driver.Journey).wait_socket(path)
            self.assertTrue(ready.is_set(),'inode existence must not report readiness')
            worker.join(timeout=4);self.assertFalse(worker.is_alive())

class AttachmentContinuationTests(unittest.TestCase):
    def test_resident_repeated_label_preserves_every_prior_request(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);world=root/'world';world.mkdir()
            driver.write(world/'genesis.json',{'factoryControllerCapability':'17'})
            legacy=root/'resident-refused.json';legacy.write_text('prior failed invocation')
            j=driver.Journey.__new__(driver.Journey);j.root=root;j.prompts=0;j.counter=10
            j.layout={'controllerHome':str(root/'home')};j.c={'controllerRoot':str(root/'home/grain'),
                'world':str(world),'sponsorWorkspace':str(root/'sponsor')};j.inbox=str(root/'inbox');j.mini=root/'mini'
            copied=[]
            def controller_run(program,args,files):
                copied.append(files[0]);j.counter+=1
                self.assertEqual(str(args[-1]),str(root/'home'/files[0]['destination']))
                return Path(files[0]['source'])
            def run(*args,**kwargs):j.counter+=1
            with patch.object(j,'controller_run',side_effect=controller_run),patch.object(j,'run',side_effect=run):
                first=j.resident('refused');before=first.read_bytes();second=j.resident('refused')
            self.assertNotEqual(first,second)
            self.assertEqual(first.read_bytes(),before)
            self.assertEqual(legacy.read_text(),'prior failed invocation')
            self.assertEqual([driver.read(f['source'])['maxPrompts'] for f in copied],[1,2])
            self.assertEqual(len({f['destination'] for f in copied}),2)

    def test_later_phase_uses_exact_retained_orchestrator_and_refuses_changed_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);helper=root/'retained.py';helper.write_text('# retained implementation')
            contract=root/'input.json';driver.write(contract,{'paths':{'outputDir':str(root)}})
            driver.write(root/'attachment.json',{'files':{'orchestrator':str(helper)},'sha256':{'orchestrator':driver.sha(helper)}})
            j=driver.Journey.__new__(driver.Journey)
            with patch.object(j,'run') as run:
                j.attachment_phase(contract,'issue-grant','--input',root/'result.json')
                self.assertEqual(run.call_args.args[1][1],helper)
                helper.write_text('# changed')
                with self.assertRaisesRegex(ValueError,'orchestrator differs'):j.attachment_phase(contract,'issue-grant')
                self.assertEqual(run.call_count,1)

    def test_session_error_or_other_request_never_acknowledges_or_issues_grant(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);session=root/'session.json';j=driver.Journey.__new__(driver.Journey)
            for value in [{'requestId':'wrong','type':'tool-complete','isError':False},
                          {'requestId':'selected','type':'tool-complete','isError':True},
                          {'requestId':'selected','type':'tool-complete','isError':False,'result':{'isError':True,'text':'refused'}}]:
                session.write_text(driver.json.dumps(value))
                with patch.object(j,'fixed') as fixed,patch.object(j,'attachment_phase') as phase:
                    with self.assertRaises(ValueError):j.finish_session_attachment(root/'input.json',session,'selected')
                    fixed.assert_not_called();phase.assert_not_called()

class RefusalContinuationTests(unittest.TestCase):
    def test_refusal_continuation_needs_exact_existing_ask_and_no_provider_dispatch(self):
        good={'askNumber':'1','paidBefore':0}
        driver.Journey.validate_refusal_resume(good,[])
        for value in [None,{},dict(good,askNumber='01'),dict(good,paidBefore=True),dict(good,paidBefore=-1),dict(good,extra=True)]:
            with self.assertRaisesRegex(ValueError,'exact ask'):driver.Journey.validate_refusal_resume(value,[])
        with self.assertRaisesRegex(ValueError,'no provider dispatch'):
            driver.Journey.validate_refusal_resume(good,['{"id":"or-call"}'])

class SelectedRequestTests(unittest.TestCase):
    def test_native_oldest_selection_wins_over_latest_matching_text(self):
        row={'author':'20','cell':'90','sequence':2,'height':124,'n':2,'text':'oracle: question','to':'8','kind':'say'}
        newer={**row,'n':4,'sequence':4,'height':130}
        call={'selectedRequest':{'binding':{'task':'7'},'author':'20','cell':'90','sequence':2},'selectedEntry':row}
        self.assertEqual(driver.Journey.selected_ask(call,[row,newer],'20','8','question'),row)
        call['selectedEntry']=newer
        with self.assertRaisesRegex(ValueError,'exact native'):driver.Journey.selected_ask(call,[row,newer],'20','8','question')

    def test_native_completed_count_bounds_exactly_one_new_prompt(self):
        import base64,hashlib
        def exported(state):
            raw=driver.json.dumps(state).encode()
            return {'files':{'resident/resident.json':{'base64':base64.b64encode(raw).decode(),'sha256':hashlib.sha256(raw).hexdigest()}}}
        self.assertEqual(driver.Journey.completed_prompts(exported({'completed':7,'pending':None})),7)
        for state in [{'completed':7,'pending':{'requestId':2}},{'completed':7,'returnPending':True},{'completed':True}]:
            with self.assertRaises(ValueError):driver.Journey.completed_prompts(exported(state))

    def test_unadmitted_old_ask_prevents_a_fresh_duplicate(self):
        ask={'author':'20','to':'8','kind':'say','text':'oracle: question','cell':'90','sequence':2,'n':2}
        self.assertEqual(driver.Journey.unanswered_asks([ask],'20','8','question'),[ask])
        unrelated={'author':'8','to':'20','kind':'say','re':2,'reCell':'91','reSequence':2}
        self.assertEqual(driver.Journey.unanswered_asks([ask,unrelated],'20','8','question'),[ask])
        exact={**unrelated,'reCell':'90'}
        self.assertEqual(driver.Journey.unanswered_asks([ask,exact],'20','8','question'),[])

    def test_started_native_custody_blocks_another_probe_and_no_text_guessing(self):
        import base64,hashlib
        value={'selected':{'identity':{},'entry':{},'started':{'residentPromptId':'original'}},'pending':[]}
        raw=driver.json.dumps(value).encode()
        exported={'files':{'resident/requests.json':{'base64':base64.b64encode(raw).decode(),'sha256':hashlib.sha256(raw).hexdigest()}}}
        with self.assertRaisesRegex(ValueError,'started retained'):driver.Journey.retained_requests(exported)
        value['selected']['started']=None;raw=driver.json.dumps(value).encode()
        exported['files']['resident/requests.json']={'base64':base64.b64encode(raw).decode(),'sha256':hashlib.sha256(raw).hexdigest()}
        self.assertEqual(len(driver.Journey.retained_requests(exported)),1)

class ApplicationClosureTests(unittest.TestCase):
    def test_uncertain_custody_preserves_app_and_settled_stop_requires_exact_unit(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);journal=root/'journal.json';receipt=root/'stop.json'
            j=driver.Journey.__new__(driver.Journey);j.bins=root;j.profile=root/'profile.json';j.application_unit='owned.service'
            for field in ('applicationApiAttempt','dispatchHold','foregroundAttempt','parentHold','pending','providerHold','child'):
                journal.write_text(driver.json.dumps({field:{'uncertain':True}}))
                with patch.object(j,'fixed',return_value=journal),patch.object(j,'run') as run:
                    with self.assertRaisesRegex(ValueError,'unsettled'):j.stop_qualified_application()
                    run.assert_not_called()
            journal.write_text('{}')
            for unit,accepted in [('foreign.service',False),('owned.service',True)]:
                receipt.write_text(driver.json.dumps({'protocol':'mini-spk-grain-stop-v1','app':'9890001','unit':unit,'activeState':'inactive'}))
                with patch.object(j,'fixed',return_value=journal) as fixed,patch.object(j,'run',return_value=receipt) as run:
                    if accepted:self.assertEqual(j.stop_qualified_application(),receipt)
                    else:
                        with self.assertRaisesRegex(ValueError,'stopped test unit'):j.stop_qualified_application()
                    self.assertEqual([c.args for c in fixed.call_args_list],[('controller-stop',),('controller-journal',)])
                    self.assertEqual(run.call_args.args[1],[root/'spk-host','grain','stop',j.profile,'9890001'])

class CheckpointTests(unittest.TestCase):
    def test_checkpoint_restores_coordinates_but_refuses_changed_native_inputs(self):
        with tempfile.TemporaryDirectory(prefix='j14-checkpoint-',dir='/tmp') as temp:
            root=Path(temp)/'oracle';root.mkdir(mode=0o700);(root/'commands').mkdir()
            binary=root/'native';binary.write_bytes(b'pinned test executable')
            (root/'spk-host').write_bytes(b'pinned application host')
            config=root/'host.json';config.write_text('{}')
            j=driver.Journey.__new__(driver.Journey)
            j.root=root;j.logs=root/'commands';j.bins=root;j.installer=driver.REPO/'deploy/spk-host/install-user-world'
            j.mini=j.host=j.runtime=j.provider=str(binary)
            j.counter=7;j.daemons=[{'pid':11,'label':'stopped','argv':[str(binary)]},{'pid':12,'label':'live','argv':[str(binary)]}]
            j.processes=[SimpleNamespace(pid=11,poll=lambda:1),SimpleNamespace(pid=12,poll=lambda:None)];j.world_pid=123
            driver.write(j.logs/'0007-ready.argv.json',['native','read'])
            driver.write(j.logs/'0007-ready.result.json',{'exitCode':0})
            j.c={'root':str(root),'repo':str(driver.REPO),'hostConfig':str(config)}
            checkpoint=j.checkpoint('prepare_application');checkpoint.chmod(0o600)
            retained=driver.read(checkpoint)
            self.assertNotIn('processes',retained['state']);self.assertNotIn('world_pid',retained['state'])
            self.assertEqual([d['label'] for d in retained['state']['daemons']],['live'])
            with patch.dict(driver.os.environ,{'JOURNEY_STEP_DIR':temp}):
                resumed=driver.Journey.from_checkpoint(checkpoint)
                self.assertEqual(resumed.resume_phase,'prepare_application')
                self.assertEqual(resumed.counter,7);self.assertEqual(resumed.processes,[])
                resumed._lock.close()
                adopted=driver.Journey.adopt_checkpoint_source(checkpoint,'reviewed helper relocation before staging')
                successor=driver.read(adopted)
                self.assertEqual(successor['pins'][str(binary)],retained['pins'][str(binary)])
                self.assertEqual(successor['sourceAdoption']['sha256'],driver.sha(checkpoint))
                staged=root/'staged-checkpoint.json';changed=driver.json.loads(driver.json.dumps(retained))
                changed['state']['controller']=True;driver.write(staged,changed);staged.chmod(0o600)
                with self.assertRaisesRegex(ValueError,'staged controller'):
                    driver.Journey.adopt_checkpoint_source(staged,'must refuse installed custody')
                binary.write_bytes(b'changed executable')
                with self.assertRaisesRegex(ValueError,'input changed'):
                    driver.Journey.from_checkpoint(checkpoint)
                binary.write_bytes(b'pinned test executable')
                driver.write(j.logs/'0008-later.argv.json',['native','effect'])
                driver.write(j.logs/'0008-later.result.json',{'exitCode':0})
                with self.assertRaisesRegex(ValueError,'newer command'):
                    driver.Journey.from_checkpoint(checkpoint)
                retained['nextPhase']='attach';checkpoint.write_text(driver.json.dumps(retained))
                with self.assertRaisesRegex(ValueError,'unsupported'):
                    driver.Journey.from_checkpoint(checkpoint)

    def test_native_birth_checkpoint_requires_spec_pins_and_existing_controller(self):
        with tempfile.TemporaryDirectory(prefix='j14-birth-',dir='/tmp') as temp:
            root=Path(temp)/'oracle';root.mkdir(mode=0o700);logs=root/'commands';logs.mkdir()
            basis=[]
            for name in ('worker-prepare.json','grain-spec.json'):
                path=root/name;driver.write(path,{});basis.append({'path':str(path),'sha256':driver.sha(path)})
            driver.write(logs/'0001-birth.argv.json',['native','exact-birth'])
            driver.write(logs/'0001-birth.result.json',{'exitCode':1})
            pins={str(driver.REPO/rel):driver.sha(driver.REPO/rel) for rel in ('deploy/spk-host/install-user-world','deploy/spk-host/controller-world.py')}
            value={'protocol':'mini-j14-worker-birth-checkpoint-v1','nextPhase':'worker_birth','sourceCommit':'test',
                   'workerPreparation':str(root/'worker-prepare.json'),'pins':pins,'basis':basis,
                   'state':{'root':str(root),'logs':str(logs),'counter':1,'controller':True,'daemons':[], 'c':{}}}
            path=root/'birth-checkpoint.json';driver.write(path,value);path.chmod(0o600)
            with patch.dict(driver.os.environ,{'JOURNEY_STEP_DIR':temp}):
                bad={**value,'basis':[]};path.write_text(driver.json.dumps(bad))
                with self.assertRaisesRegex(ValueError,'exact retained'):driver.Journey.from_checkpoint(path)
                bad={**value,'state':{**value['state'],'controller':False}};path.write_text(driver.json.dumps(bad))
                with self.assertRaisesRegex(ValueError,'exact retained'):driver.Journey.from_checkpoint(path)
                path.write_text(driver.json.dumps(value));resumed=driver.Journey.from_checkpoint(path)
                self.assertEqual(resumed.resume_phase,'worker_birth');resumed._lock.close()

class ControllerPublicRelayTests(unittest.TestCase):
    def test_rebind_selects_native_controller_acl_and_preserves_other_arguments(self):
        j=driver.Journey.__new__(driver.Journey);j.layout={'controllerUid':os.getuid()+100000}
        j.c={'publicSocket':'/s/public.sock','operatorSocket':'/s/private/operator.sock','hostConfig':'/p/config.json'}
        argv=['/p/mini','serve-public-proxy','--socket',j.c['publicSocket'],'--upstream',j.c['operatorSocket'],'--config',j.c['hostConfig']]
        selected=j.controller_public_args(argv);self.assertEqual(selected,argv+['--controller-uid',str(j.layout['controllerUid'])])
        self.assertEqual(j.controller_public_args(selected),selected)
        with self.assertRaisesRegex(ValueError,'recipient differs'):j.controller_public_args(argv+['--controller-uid','1'])
        with self.assertRaisesRegex(ValueError,'identity differs'):j.controller_public_args(argv+['--socket-gid','1'])
        stopped=[];process=SimpleNamespace(pid=99,poll=lambda:None,terminate=lambda:stopped.append(99),wait=lambda timeout:0)
        j.processes=[process];j.daemons=[{'pid':99,'argv':argv}]
        with patch.object(j,'spawn') as spawn,patch.object(j,'wait_socket') as ready:
            j.ensure_controller_public_proxy();spawn.assert_called_once_with('participant-controller',selected);ready.assert_called_once_with('/s/public.sock')
        self.assertEqual(stopped,[99])

class WorkerPreparationTests(unittest.TestCase):
    def test_partial_copy_continuation_keeps_original_spec_and_waits_for_installer(self):
        with tempfile.TemporaryDirectory(prefix='j14-preparation-',dir='/tmp') as temp:
            root=Path(temp);runtime=root/'original-runtime'
            driver.write(root/'worker-prepare.json',{'runtimeRoot':str(runtime)})
            j=driver.Journey.__new__(driver.Journey);j.root=root;j.sockets=root/'sockets';j.bins=root/'bin'
            j.c={'operatorSocket':'/private/operator.sock','publicSocket':'/public/participant.sock'}
            with patch.object(j,'fixed',side_effect=ValueError('partial copy changed')), patch.object(j,'finish_worker') as finish:
                with self.assertRaisesRegex(ValueError,'partial copy changed'): j.worker_preparation()
                finish.assert_not_called()
            with patch.object(j,'fixed') as fixed, patch.object(j,'finish_worker') as finish:
                j.worker_preparation()
                self.assertEqual(fixed.call_args.args,('controller-worker-prepare-resume',root/'worker-prepare.json',root/'bin','/private/operator.sock','/public/participant.sock'))
                finish.assert_called_once_with(root/'grain-spec.json',runtime)

class WorkspaceTransportTests(unittest.TestCase):
    def test_only_socket_changes_and_original_pins_remain_retained(self):
        with tempfile.TemporaryDirectory(prefix='j14-routing-',dir='/tmp') as temp:
            root=Path(temp);sockets=root/'sockets';sockets.mkdir();work=root/'workspaces';work.mkdir()
            sponsor=root/'sponsor';sponsor.mkdir();host=root/'host';host.write_bytes(b'Host')
            old=sockets/'operator.sock';new=sockets/'operator-v2.sock';config=root/'config.json'
            driver.write(old.with_suffix('.config'),{'store':'same','domain':1})
            driver.write(config,{'store':'same','domain':1,'agentLifetimeDispatchTargets':[{'grantResource':17}]})
            before={'socket':str(old),'host':str(host),'hostSha256':driver.sha(host),'config':str(config),
                    'subject':'7','key':'private-key-path','birthContext':'retained-birth'}
            path=sponsor/'workspace.json';driver.write(path,before);path.chmod(0o600)
            j=driver.Journey.__new__(driver.Journey);j.root=root;j.sockets=sockets;j.workspaces=work;j.host=str(host)
            j.c={'operatorSocket':str(new),'hostConfig':str(config),'sponsorWorkspace':str(sponsor)}
            j.migrate_workspace_transport();after=driver.read(path)
            self.assertEqual(after,{**before,'socket':str(new)})
            j.migrate_workspace_transport();self.assertEqual(driver.read(path),after)
            record=driver.read(root/'workspace-transport/00.json')
            self.assertEqual(driver.read(record['before']),before)
            self.assertEqual(driver.read(old.with_suffix('.config')),{'store':'same','domain':1})
            value=driver.read(config);value['store']='foreign';config.write_text(driver.json.dumps(value))
            with self.assertRaisesRegex(ValueError,'identical native Store'):
                j.migrate_workspace_transport()

class RuntimeReleaseTests(unittest.TestCase):
    def test_retained_release_recovers_pre_copy_and_completed_copy_only(self):
        with tempfile.TemporaryDirectory(prefix='j14-release-',dir='/tmp') as temp:
            root=Path(temp);bins=root/'bin';bins.mkdir();current=bins/'grain-runtime';current.write_bytes(b'old')
            source=root/'qualified-runtime';source.write_bytes(b'new');source.chmod(0o700)
            release=root/'release.json';driver.write(release,{'runtime':str(source),'sha256':driver.sha(source),'sourceCommit':'a'*40});release.chmod(0o600)
            j=driver.Journey.__new__(driver.Journey);j.root=root;j.bins=bins;j.runtime=str(current);j.c={'manifest':str(root/'candidate.json')}
            with patch.dict(driver.os.environ,{'J14_ORACLE_WORKER_RELEASE':str(release)}):
                j.await_worker_release();record=(root/'worker-runtime-successor.json').read_bytes()
                j.await_worker_release();self.assertEqual(current.read_bytes(),b'new')
                current.write_bytes(b'old');j.await_worker_release();self.assertEqual(current.read_bytes(),b'new')
                self.assertEqual((root/'worker-runtime-successor.json').read_bytes(),record)
                current.write_bytes(b'foreign')
                with self.assertRaisesRegex(ValueError,'initial runtime changed'):j.await_worker_release()

class ProcessEvidenceTests(unittest.TestCase):
    def test_repeated_service_keeps_prior_process_and_output_bytes(self):
        with tempfile.TemporaryDirectory(prefix='j14-process-',dir='/tmp') as temp:
            root=Path(temp);j=driver.Journey.__new__(driver.Journey);j.logs=root;j.processes=[];j.daemons=[]
            for suffix in ['stdout','stderr','process.json']:(root/('provider.'+suffix)).write_text('prior evidence')
            process=j.spawn('provider',[sys.executable,'-c','print("new process")'])
            self.assertEqual(process.wait(timeout=5),0)
            self.assertEqual(process.journey_stdout.read_text(),'new process\n')
            for suffix in ['stdout','stderr','process.json']:self.assertEqual((root/('provider.'+suffix)).read_text(),'prior evidence')
            self.assertEqual(j.daemons[0]['label'],'provider-01')

class OperatorTransportTests(unittest.TestCase):
    def fixture(self,root):
        root=Path(root);sockets=root/'sockets';sockets.mkdir(mode=0o700)
        work=root/'workspaces';work.mkdir();sponsor=root/'sponsor';sponsor.mkdir();(work/'alice').mkdir()
        provider=sockets/'provider';provider.mkdir();state=root/'state';state.mkdir()
        host=root/'host';host.write_bytes(b'pinned Host')
        def private(path,value):
            driver.write(path,value);path.chmod(0o600);return path
        config=private(root/'host.json',{'store':'same','domain':7,'keys':'unchanged'})
        old=sockets/'operator-v2.sock';old.with_suffix('.config').write_bytes(config.read_bytes());old.with_suffix('.config').chmod(0o600)
        profile=private(state/'grain-host.json',{'miniOperatorSocket':str(old),'miniConfig':str(config),
            'miniConfigSha256':driver.sha(config),'miniHost':str(host),'miniHostSha256':driver.sha(host),
            'stateRoot':str(state),'managementSeed':'unchanged-private-path','managementSubject':'7'})
        result=private(root/'profile-result.json',{'profilePath':str(profile),'stateRoot':str(state)})
        workspace={'socket':str(old),'config':str(config),'host':str(host),'hostSha256':driver.sha(host),
                   'subject':'7','key':'unchanged-private-key-path'}
        paths=[profile,private(sponsor/'workspace.json',workspace),private(work/'alice/workspace.json',{**workspace,'subject':'8'})]
        paths.append(private(provider/'broker.json',{'socket':str(provider/'keys.sock'),'credentials':{
            'publicSocket':str(old),'hostConfig':str(config),'host':str(host),'hostSha256':driver.sha(host),
            'publicSocketUid':driver.os.getuid(),'key':'unchanged-broker-key'}}))
        request=private(root/'relocate.json',{'protocol':'mini-j14-operator-relocation-v1','previousSocket':str(old),
            'socket':str(sockets/'private/operator.sock'),'hostConfigSha256':driver.sha(config)})
        j=driver.Journey.__new__(driver.Journey);j.root=root;j.sockets=sockets;j.workspaces=work;j.host=str(host)
        j.controller=True;j.resume_phase='worker_birth';j.layout={'controllerUid':driver.os.getuid()+100}
        j.c={'operatorSocket':str(old),'publicSocket':str(sockets/'participant.sock'),'hostConfig':str(config),
             'profileResult':str(result),'sponsorWorkspace':str(sponsor)}
        j.restart_daemons=[{'label':'operator','argv':[str(host),'serve-operator','--socket',str(old)],'socket':str(old)},
            {'label':'public','argv':[str(host),'serve-public-proxy','--socket',j.c['publicSocket'],'--upstream',str(old)],'socket':j.c['publicSocket']}]
        return j,request,paths

    def test_prebirth_relocation_changes_only_transport_and_retains_exact_reentry(self):
        with tempfile.TemporaryDirectory(prefix='j14-operator-',dir='/tmp') as temp:
            j,request,paths=self.fixture(temp);before=[driver.read(path) for path in paths]
            settings=Path(j.c['hostConfig']).read_bytes()
            with patch.dict(driver.os.environ,{'J14_ORACLE_OPERATOR_RELOCATION':str(request)}):
                j.prepare_operator_relocation();new=j.c['operatorSocket']
                after=[driver.read(path) for path in paths]
                self.assertEqual(after[0],{**before[0],'miniOperatorSocket':new})
                for i in [1,2]:self.assertEqual(after[i],{**before[i],'socket':new})
                expected=driver.json.loads(driver.json.dumps(before[3]));expected['credentials']['publicSocket']=new
                self.assertEqual(after[3],expected)
                self.assertEqual(Path(j.c['hostConfig']).read_bytes(),settings)
                plan=Path(j.c['operatorTransportTransition']);retained=plan.read_bytes()
                j.prepare_operator_relocation();self.assertEqual(plan.read_bytes(),retained)
                self.assertEqual(j.restart_daemons[0]['socket'],new)
                self.assertEqual(j.restart_daemons[1]['argv'][-1],new)
                with patch.object(j,'fixed',return_value=Path(temp)/'endpoint-receipt.json') as fixed:
                    j.finish_operator_relocation()
                    self.assertEqual([call.args for call in fixed.call_args_list],[('controller-stop',),('controller-operator-endpoint',new)])
                changed=driver.read(paths[1]);changed['subject']='foreign';paths[1].write_text(driver.json.dumps(changed))
                with self.assertRaisesRegex(ValueError,'outside retained'):j.prepare_operator_relocation()

    def test_relocation_refuses_active_profile_or_changed_store_before_metadata_write(self):
        for control in ['active','store','later','daemon','archive-link']:
            with self.subTest(control=control), tempfile.TemporaryDirectory(prefix='j14-operator-',dir='/tmp') as temp:
                j,request,paths=self.fixture(temp);before=[path.read_bytes() for path in paths]
                if control=='active':(paths[0].parent/'active-profile.json').write_text('{}')
                elif control=='store':Path(j.c['hostConfig']).write_text('{"store":"foreign"}')
                elif control=='later':j.application_unit='already-started.service'
                elif control=='daemon':j.restart_daemons[0]['argv'][-1]='/foreign.sock'
                elif control=='archive-link':
                    foreign=Path(temp)/'foreign';foreign.mkdir(mode=0o700);(Path(temp)/'operator-transport').symlink_to(foreign)
                with patch.dict(driver.os.environ,{'J14_ORACLE_OPERATOR_RELOCATION':str(request)}):
                    with self.assertRaises(ValueError):j.prepare_operator_relocation()
                self.assertEqual([path.read_bytes() for path in paths],before)

    def test_private_operator_child_does_not_share_public_parent_permissions(self):
        with tempfile.TemporaryDirectory(prefix='j14-operator-',dir='/tmp') as temp:
            j,_,_=self.fixture(temp)
            j.sockets.chmod(0o710)
            path=j.private_operator_socket('operator-v2.sock')
            self.assertEqual(path.parent.stat().st_mode&0o777,0o700)
            path.parent.chmod(0o750)
            with self.assertRaisesRegex(ValueError,'private operator custody'):j.private_operator_socket()

    def test_public_socket_rebind_reapplies_only_controller_connect_acl(self):
        with tempfile.TemporaryDirectory(prefix='j14-operator-',dir='/tmp') as temp:
            j,_,_=self.fixture(temp);path=Path(j.c['publicSocket'])
            with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as server:
                server.bind(str(path));server.listen()
                with patch.object(j,'run') as run:
                    j.restore_public_socket_access(path)
                    self.assertEqual(run.call_args.args,('public-socket-acl',['setfacl','-m',f"u:{j.layout['controllerUid']}:-w-",'--',path]))
                j.layout['controllerUid']=True
                with self.assertRaisesRegex(ValueError,'recipient or custody'):j.restore_public_socket_access(path)
                j.layout['controllerUid']=driver.os.getuid()
                with self.assertRaisesRegex(ValueError,'recipient or custody'):j.restore_public_socket_access(path)

if __name__=='__main__':unittest.main()
