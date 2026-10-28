#!/usr/bin/env python3
"""Untrusted orchestration for a fresh Hermes + Oracle receiving journey.

Every transition uses native Mini; the fixed installer handles cross-UID
transport. Retained command outputs and exact native attempts survive failure.
"""
import importlib.util
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import signal
import socket
import subprocess
import time

HERE=Path(__file__).resolve().parent
REPO=HERE.parents[2]
spec=importlib.util.spec_from_file_location('inputs',HERE/'j14-oracle-inputs.py')
inputs=importlib.util.module_from_spec(spec);spec.loader.exec_module(inputs)
read,write,sha=inputs.read,inputs.write,inputs.sha

def available_port():
    with socket.socket() as listener:
        listener.bind(('127.0.0.1',0))
        return listener.getsockname()[1]

def need(name):
    value=os.environ.get(name)
    if not value:raise ValueError('J14 Oracle requires '+name)
    return str(Path(value).resolve(strict=True))

class Journey:
    def __init__(self):
        os.umask(0o077)
        self.root=Path(os.environ['JOURNEY_STEP_DIR'])/'oracle'
        self.root.mkdir(mode=0o700)
        self.logs=self.root/'commands';self.logs.mkdir()
        self.processes=[];self.counter=0;self.controller=False
        # A separate fresh private root avoids sharing controller traversal ACLs
        # with another preserved world (including /run/user/UID).
        socket_parent=Path(os.environ.get('J14_ORACLE_SOCKET_PARENT','/build/lanes'))
        self.sockets=socket_parent/('j14-o7-s-'+secrets.token_hex(4));self.sockets.mkdir(mode=0o700)
        self.bins=Path(need('J14_ORACLE_BIN'))
        self.mini=need('MINI');self.host=need('HOST');self.runtime=need('GRAIN_RUNTIME')
        self.provider=need('TEST_PROVIDER');self.hermes_root=need('J14_HERMES_ROOT')
        self.candidate_manifest=need('J14_ORACLE_CANDIDATE_MANIFEST')
        self.spk=need('J14_ORACLE_SPK');self.data=need('J14_ORACLE_DATA_SOURCE');self.inventory=need('J14_ORACLE_INVENTORY')
        for name in ['spk-host','spk-ingest','spk-data-publish','mini-spk-broker','mini-spk-volume-helper',
                     'mini','minidregg-host','grain-runtime','minidregg-client-consent','mini-keys','grain-provider-bridge','launch-gate']:
            if not os.access(self.bins/name,os.X_OK):raise ValueError('missing selected executable '+name)
        for name,path in [('mini',self.mini),('minidregg-host',self.host),('grain-runtime',self.runtime)]:
            if sha(path)!=sha(self.bins/name):raise ValueError('selected binary cohort differs: '+name)
        self.installer=REPO/'deploy/spk-host/install-user-world'
        self.c={'root':str(self.root),'repo':str(REPO),'mini':self.mini,'host':self.host,'spkHost':str(self.bins/'spk-host'),'spk':self.spk,'taskBase':str(1000000000000+secrets.randbelow(1000000000000))}
        self.c['socketDirectory']=str(self.sockets)
        write(self.root/'allocation-context.json',self.c)
        self.homes=self.root/'homes';self.homes.mkdir();self.workspaces=self.root/'workspaces';self.workspaces.mkdir()
        (self.root/'subjects').mkdir()
        self.subjects={}
        self.pin_candidate()

    def pin_candidate(self):
        candidate=read(self.candidate_manifest)
        source_files=[HERE/'j14-oracle.py',HERE/'j14-oracle-inputs.py',HERE/'j14-oracle-evidence.py',
            REPO/'scripts/application-attachment.py',REPO/'scripts/spk-platform/same-store-app.py',
            REPO/'scripts/spk-platform/same-store-profile.py',REPO/'scripts/spk-platform/ws-continuity-fixture.py',
            REPO/'scripts/spk-platform/broker-world-up.sh',REPO/'deploy/spk-host/install-user-world',
            REPO/'deploy/spk-host/controller-world.py',REPO/'native/resource-client/newparticipant-acceptance.sh']
        m={'sourceCommit':candidate['sourceCommit'],'sha256':{},'candidateManifest':self.candidate_manifest,
           'candidateManifestSha256':sha(self.candidate_manifest),'overlays':{'grainRuntime':sha(self.runtime),'testProvider':sha(self.provider)},
           'orchestrationSource':{'commit':os.environ.get('J14_ORACLE_ORCHESTRATION_COMMIT'),
                                  'files':{str(p.relative_to(REPO)):sha(p) for p in source_files}}}
        for role,path in [('host',self.host),('mini',self.mini),('store',need('STORE')),('verifier',need('VERIFIER')),('spkHost',str(self.bins/'spk-host'))]:
            digest=sha(path)
            if digest!=candidate['sha256'][role]:raise ValueError('selected candidate artifact differs: '+role)
            m[role]=path;m['sha256'][role]=digest
        manifest=self.root/'candidate.json';write(manifest,m);self.c['manifest']=str(manifest)

    def task(self,role):
        return str(int(self.c['taskBase'])+['controller','tool','provider','dispatch'].index(role)+1)

    def run(self,label,args,env=None,timeout=1800):
        self.counter+=1;stem=self.logs/f'{self.counter:04d}-{label}'
        argv=list(map(str,args));write(stem.with_suffix('.argv.json'),argv)
        with stem.with_suffix('.stdout').open('w') as out,stem.with_suffix('.stderr').open('w') as err:
            result=subprocess.run(argv,stdout=out,stderr=err,env=env,timeout=timeout)
        write(stem.with_suffix('.result.json'),{'exitCode':result.returncode})
        if result.returncode:raise RuntimeError(f'{label} failed ({result.returncode}); retained {stem}')
        return stem.with_suffix('.stdout')

    def spawn(self,label,args):
        out=(self.logs/(label+'.stdout')).open('w');err=(self.logs/(label+'.stderr')).open('w')
        p=subprocess.Popen(list(map(str,args)),stdout=out,stderr=err);out.close();err.close();self.processes.append(p)
        write(self.logs/(label+'.process.json'),{'pid':p.pid,'argv':list(map(str,args))})
        return p

    def wait_socket(self,path):
        deadline=time.monotonic()+120
        while time.monotonic()<deadline:
            if Path(path).is_socket():return
            time.sleep(.1)
        raise RuntimeError('socket did not appear: '+str(path))

    def shell(self,who,line):
        ws=self.c['sponsorWorkspace'] if who=='sponsor' else str(self.workspaces/who)
        return self.run('shell-'+who,[self.mini,'shell','--socket',self.c['operatorSocket'],'--host',self.host,
            '--config',self.c['hostConfig'],'--workspace',ws,'--home',self.homes/who,'--line',line])

    def fixed(self,verb,*args,timeout=1800):
        return self.run(verb,['sudo','-n',self.installer,verb,self.broker['store'],self.broker['helper'],*args],timeout=timeout)

    def controller_run(self,program,args,files=None):
        request=self.root/f'controller-request-{self.counter+1:04d}.json';write(request,{'program':program,'args':list(map(str,args)),**({'inputs':files} if files else {})})
        return self.fixed('controller-run',request)

    def world(self):
        tariff=self.root/'provider-services.json';write(tariff,[{'providerResourceId':int(self.task('provider')),'tariff':{
            'version':'1','model':'mini-hermes-protocol-fixture','routes':{'user':{'perOp':'5'},
            'pool':{'perOp':'7','inputMicroPerMillion':'100000','outputMicroPerMillion':'200000'},
            'homelab':{'perOp':'3','inputMicroPerMillion':'0','outputMicroPerMillion':'0'}}}}])
        w=self.root/'world';sock=self.sockets/'operator.sock'
        # Each run needs a distinct Store tag for its registered physical world.
        env=dict(os.environ,NEWPARTICIPANT_GRAIN_PLATFORM='1',NEWPARTICIPANT_SERVE='serve-operator',
                 NEWPARTICIPANT_TEMPLATE_DIR='',NEWPARTICIPANT_PROVIDER_SERVICES=str(tariff),NEWPARTICIPANT_SPONSOR_BALANCE='1000000')
        self.run('world',[REPO/'native/resource-client/newparticipant-acceptance.sh',self.host,self.mini,need('STORE'),need('VERIFIER'),w,sock],env=env)
        h=read(w/'handoff.json');self.c.update(world=str(w),hostConfig=h['config'],sponsorWorkspace=h['sponsorWorkspace'],operatorSocket=str(sock),publicSocket=str(self.sockets/'participant.sock'))
        self.world_pid=int((w/'public/server.pid').read_text())
        params=read(w/'genesis-params.json');self.sponsor=str(params['sponsor']['subject'])
        (self.homes/'sponsor/keys').mkdir(parents=True)
        self.run('app-tasks',[self.mini,'apps','bootstrap','--dir',self.c['sponsorWorkspace'],'--budget','20000'])
        permit=self.root/'permit-all.json';write(permit,{'type':'all','predicates':[]})
        for who,funding in [('alice',5000),('bob',100),('hermes',10000),('hhost',0),('hprov',0),('hdisp',0)]:
            (self.homes/who).mkdir()
            self.shell(who,'keygen mini.key')
            key=self.homes/who/'keys/mini.key';copy=self.homes/'sponsor/keys'/f'j14-{who}.key'
            shutil.copyfile(key,copy)
            self.shell('sponsor',f'enroll plan j14-{who} j14-{who}.key --no-prerotation')
            self.shell('sponsor',f'enroll seal j14-{who}')
            enrolled=read(self.shell('sponsor',f'enroll submit j14-{who}'))
            write(self.root/'subjects'/f'{who}.json',enrolled);self.subjects[who]=enrolled['subject'];copy.unlink()
            self.run('provision-'+who,[self.mini,'workspace','--action','provision','--dir',self.c['sponsorWorkspace'],
                '--name','j14-'+who,'--holder',enrolled['subject'],'--funding',funding,'--account-predicate',permit,'--factory-ref','factory'])
            (self.homes/who/'provision').mkdir()
            shutil.copyfile(Path(self.c['sponsorWorkspace'])/'provisions'/('j14-'+who)/'birth-context.json',self.homes/who/'provision/birth-context.json')
            if who in ['alice','bob']:self.shell(who,f'init mini.key {enrolled["subject"]} --no-prerotation')
        self.shell('alice','chat new lab');self.shell('alice',f"doc new lab-index 'any [ not (verb == write), subject == {self.subjects['alice']} ]' --in lab")
        self.shell('alice','tariff lab set hermes/turn 10')
        self.shell('alice',f"chat invite lab {self.subjects['bob']} bob --verbs observe,place,append")
        (self.homes/'bob/requests').mkdir(exist_ok=True)
        shutil.copyfile(self.homes/'alice/chat/invites'/f"lab-{self.subjects['bob']}.json",self.homes/'bob/requests/lab-invite.json')
        self.shell('bob','chat join lab @lab-invite.json')
        # The app issuer observes this actual room through the founder's grant.
        self.shell('alice',f'room invite oracle-host lab {self.sponsor} --verbs observe')
        for line in ['submit oracle-host','publish oracle-host']:self.shell('alice',line)
        reference=self.shell('alice','export oracle-host').read_text().strip()
        self.shell('sponsor','import oracle-room '+reference)
        room=read(Path(self.c['sponsorWorkspace'])/'refs/oracle-room.json')
        self.c['room']={'target':room['target'],'capability':room['observeCapability']}
        allocation=self.root/'allocation.json';write(allocation,inputs.allocation(self.c));self.c['allocation']=str(allocation)
        fresh=self.root/'operator-with-oracle.json'
        self.run('lifetime-target',['python3',REPO/'scripts/application-attachment.py','render-host-config',self.c['hostConfig'],allocation,fresh])
        os.kill(self.world_pid,signal.SIGTERM)
        deadline=time.monotonic()+60
        while Path('/proc',str(self.world_pid)).exists() and time.monotonic()<deadline:time.sleep(.1)
        if Path('/proc',str(self.world_pid)).exists():raise RuntimeError('own operator did not stop before settings update')
        shutil.copyfile(fresh,self.c['hostConfig'])
        self.spawn('operator',[self.mini,'serve-operator','--host',self.host,'--config',self.c['hostConfig'],'--socket',sock]);self.world_pid=None
        self.wait_socket(sock)
        self.spawn('participant',[self.mini,'serve-public-proxy','--socket',self.c['publicSocket'],'--upstream',sock,'--config',self.c['hostConfig']]);self.wait_socket(self.c['publicSocket'])
        native=self.run('native-profile',[self.host,self.c['hostConfig'],'profile']);self.c['nativeProfile']=str(native)

    def application(self):
        env=dict(os.environ,MINI_IMPORT_PROFILE='operator-appliance-v1')
        self.run('broker-world',[REPO/'scripts/spk-platform/broker-world-up.sh',self.bins,self.c['hostConfig'],self.root/'broker'],env=env)
        self.broker=read(self.root/'broker/broker.json')
        self.layout=read(self.fixed('controller-create'));self.c['controllerRoot']=str(Path(self.layout['controllerHome'])/'grain')
        params=read(Path(self.c['world'])/'genesis-params.json')
        manifest=Path(self.c['manifest']);m=read(manifest)
        w=Path(self.c['world']);p={'protocol':'mini-spk-same-store-profile-input-v1','manifest':str(manifest),'expectedSourceCommit':m['sourceCommit'],
            'miniConfig':self.c['hostConfig'],'miniConfigSha256':sha(self.c['hostConfig']),
            'management':{'subject':self.sponsor,'keyId':str(params['sponsor']['keyId']),'keyEpoch':str(params['sponsor']['keyEpoch']),'publicKeyPath':str(w/'sponsor.pub'),'seedPath':str(w/'sponsor.key')},
            'completionPublicKey':str(w/'keys/completion.pub'),'completionSeed':str(w/'keys/completion.seed'),
            'semantics':str(read(self.c['nativeProfile'])['semantics']),'root':str(self.root/'profile'),
            'grainsRoot':self.broker['grainsRoot'],'brokerSocket':self.broker['brokerSocket'],'privateSocket':self.c['operatorSocket'],
            'bwrap':self.run('bwrap',['sh',REPO/'deploy/grain-host/resolve-bwrap']).read_text().strip(),'importProfile':'operator-appliance-v1'}
        path=self.root/'profile-input.json';write(path,p)
        result=read(self.run('profile',['python3',REPO/'scripts/spk-platform/same-store-profile.py',path]));self.c['profileResult']=result['profileResult']
        path=self.root/'application-input.json';write(path,inputs.provision(self.c))
        prepared=self.run('application-prepare',['python3',REPO/'scripts/spk-platform/same-store-app.py','prepare',path],timeout=14400)
        self.c['preparedApplication']=str(prepared)
        self.run('publish-data',[self.bins/'spk-data-publish','publish','--store',Path(self.broker['grainsRoot'])/'spk/public-data','--source',self.data,'--inventory',self.inventory],timeout=3600)

    def cleanup(self):
        if self.controller:
            try:self.fixed('controller-stop',timeout=120)
            except Exception:pass
        for p in reversed(self.processes):
            if p.poll() is None:
                p.terminate()
                try:p.wait(timeout=30)
                except subprocess.TimeoutExpired:pass
        if getattr(self,'world_pid',None):
            try:os.kill(self.world_pid,signal.SIGTERM)
            except ProcessLookupError:pass

    def await_worker_release(self):
        selected=os.environ.get('J14_ORACLE_WORKER_RELEASE')
        if not selected:return
        if Path(self.runtime)!=self.bins/'grain-runtime':
            raise ValueError('worker release may update only the selected owned bin overlay')
        path=Path(selected)
        if not path.is_absolute():raise ValueError('worker release path must be absolute')
        previous=sha(self.runtime);deadline=time.monotonic()+1800
        write(self.root/'worker-wait.json',{'releasePath':str(path),'previousRuntimeSha256':previous,'maximumWaitSeconds':1800})
        while not path.exists():
            if time.monotonic()>=deadline:raise TimeoutError('worker release not supplied; native Store and application attempts retained')
            time.sleep(1)
        metadata=path.lstat()
        if path.is_symlink() or not path.is_file() or metadata.st_uid!=os.getuid() or metadata.st_mode&0o077:
            raise ValueError('worker release must be an operator-private regular file')
        release=read(path)
        if set(release)!={'runtime','sha256','sourceCommit'} or re.fullmatch('[0-9a-f]{64}',release['sha256']) is None or re.fullmatch('[0-9a-f]{40}',release['sourceCommit']) is None:
            raise ValueError('worker release pin contract differs')
        source=Path(release['runtime'])
        if not source.is_absolute() or source.is_symlink() or not source.is_file() or not os.access(source,os.X_OK) or sha(source)!=release['sha256']:
            raise ValueError('released runtime differs from selected pin')
        if sha(self.runtime)!=previous:raise ValueError('initial runtime changed while preparation was running')
        temporary=self.bins/('grain-runtime-release-'+secrets.token_hex(6))
        shutil.copyfile(source,temporary);temporary.chmod(0o755)
        if sha(temporary)!=release['sha256']:raise ValueError('runtime changed during release copy')
        write(self.root/'worker-runtime-successor.json',{'protocol':'mini-j14-runtime-successor-v1',
            'previousRuntimeSha256':previous,'initialCandidateManifest':self.c['manifest'],'release':release})
        os.replace(temporary,self.runtime)

    def worker(self):
        home=Path(self.layout['controllerHome']);base=home.parent;grain=home/'grain'
        staged=self.root/'worker';staged.mkdir();launcher=staged/'launcher';launcher.mkdir()
        physical=self.run('bwrap',['sh',REPO/'deploy/grain-host/resolve-bwrap']).read_text().strip()
        self.run('launcher',['python3',REPO/'deploy/grain-host/materialize-bwrap.py','--physical-bwrap',physical,'--physical-sha256',sha(physical),'--output',launcher/'bwrap'])
        shutil.copyfile(self.bins/'launch-gate',launcher/'launch-gate');os.chmod(launcher/'launch-gate',0o700)
        runtime=staged/'runtime-root'
        # Dereference the selected source once as the ordinary operator. The
        # root installer only accepts the resulting bounded regular tree.
        shutil.copytree(self.hermes_root,runtime,symlinks=False)
        for name in ['grain-runtime','grain-provider-bridge']:
            shutil.copyfile(self.bins/name,runtime/name);os.chmod(runtime/name,0o755)
        pins=read(runtime/'pins.json')
        pins.update(grainRuntimeSha256=sha(runtime/'grain-runtime'),grainProviderBridgeSha256=sha(runtime/'grain-provider-bridge'),
                    candidateManifest=self.candidate_manifest,candidateManifestSha256=sha(self.candidate_manifest),
                    runtimeOverlay={'path':self.runtime,'sha256':sha(self.runtime)})
        (runtime/'pins.json').write_text(json.dumps(pins,indent=2)+'\n')
        table=runtime/'providers.json';port=int(os.environ['J14_PROVIDER_PORT']) if 'J14_PROVIDER_PORT' in os.environ else available_port()
        write(table,{'type':'mini-provider-table-v2','providers':[{'name':'friendkey','kind':'openai-compatible',
            'endpoint':f'http://127.0.0.1:{port}/v1/chat/completions','models':['mini-hermes-protocol-fixture'],'credential':'user'}]})
        self.provider_process=self.spawn('provider',[self.provider,f'127.0.0.1:{port}',self.root/'provider.log','--room-librarian'])
        deadline=time.monotonic()+30
        while f'http://127.0.0.1:{port}/v1' not in (self.logs/'provider.stdout').read_text():
            if self.provider_process.poll() is not None or time.monotonic()>=deadline:raise RuntimeError('selected provider did not bind its loopback port')
            time.sleep(.1)
        self.keyroot=Path(self.broker['grainsRoot'])/'j14-provider';self.keyroot.mkdir(mode=0o711)
        keysocket=self.keyroot/'keys.sock';keyclient=runtime/'keys-client.json'
        write(keyclient,{'type':'mini-keys-client-v1','socket':str(keysocket),'uid':os.getuid()})
        (self.keyroot/'credentials').mkdir(mode=0o700)
        key=self.keyroot/'credentials.key';key.write_bytes(secrets.token_bytes(32));key.chmod(0o600)
        brokerconfig=self.keyroot/'broker.json'
        write(brokerconfig,{'type':'mini-keys-broker-v1','socket':str(keysocket),'audit':str(self.keyroot/'audit.jsonl'),
            'spool':str(self.keyroot/'spool'),'singleAccount':True,
            'peers':[{'role':'member','gids':[os.getgid()]},{'role':'provider','uids':[self.layout['controllerUid']]},
                     {'role':'operator','uids':[os.getuid()]}],
            'credentials':{'host':self.host,'hostSha256':sha(self.host),'hostConfig':self.c['hostConfig'],
                'publicSocket':self.c['operatorSocket'],'publicSocketUid':os.getuid(),'providers':str(base/'worker/runtime-root/providers.json'),
                'root':str(self.keyroot/'credentials'),'key':str(key)}})
        params=read(Path(self.c['world'])/'genesis-params.json');cfg=read(self.c['hostConfig'])
        role=lambda name:{'key':str(home/'keys'/f'{name}.key'),'subject':self.subjects[name],'noPrerotation':True}
        spec={'type':'mini-grain-create-v1','mini':str(base/'bin/mini'),'host':str(base/'bin/minidregg-host'),
            'hostConfig':str(home/'host-config.json'),'hostSocket':str(home/'operator/mini.sock'),
            'genesis':str(home/'bootstrap/genesis.json'),'namespaceRoot':str(home/'bootstrap/namespace'),'root':str(grain),'nonce':'987000',
            'sponsor':{'key':str(Path(self.c['world'])/'sponsor.key'),'subject':self.sponsor,
                'accountCapability':str(params['sponsor']['spendCapabilityId']),
                'grants':read(Path(self.c['world'])/'sponsor-birth-context.json')['grants']},
            'template':{k:str(cfg[k]) for k in ['issuer','ownerBudget','lifetime']},'owner':role('hhost'),'workerKey':role('hermes'),
            'task':self.task('controller'),'toolTask':self.task('tool'),'capabilities':{'parentObserve':'9870011','parentControl':'9870012','toolObserve':'9870013','toolControl':'9870014'},
            'budgets':{'parent':'20000','tool':'20000','witnessMaxCost':'50000'},
            'worker':{'launcher':str(base/'worker/launcher/bwrap'),'runtimeRoot':str(base/'worker/runtime-root'),
                'workspace':str(home/'worker-work'),'network':'none','wallTimeSeconds':1800,'reserve':'3','charge':'1'},
            'toolCharges':{'reserve':'5','charge':'1'},
            'provider':{'key':role('hprov'),'task':self.task('provider'),'observeCapability':'9870015','controlCapability':'9870016','budget':'50000',
                'gateway':{'providers':str(base/'worker/runtime-root/providers.json'),'credentialBroker':str(base/'worker/runtime-root/keys-client.json'),
                    'gatewayBind':f'127.0.0.1:{available_port()}','model':'mini-hermes-protocol-fixture','provider':'friendkey',
                    'onBehalfOf':{'subject':self.subjects['alice'],'publicKey':(self.homes/'alice/keys/mini.key.pub').read_bytes().hex()},
                    'reserve':'30000','maxInputTokens':131072,'maxOutputTokens':64,'maxRequestBytes':1048576,'maxResponseBytes':8388608,
                    'timeoutSeconds':600,'localFixtureHostNetwork':False}},
            'dispatch':{'key':role('hdisp'),'task':self.task('dispatch'),'observeCapability':'9870017','controlCapability':'9870018','budget':'20000',
                'transport':{'reserve':'1','charge':'1','socketPath':self.layout['reverseSocket'],'hostUid':os.getuid(),
                    'operatorSocket':str(home/'operator/mini.sock'),'operatorPeerUid':0,
                    'reserveSigner':{'role':'4','index':'0','publicKey':(self.homes/'hdisp/keys/mini.key.pub').read_bytes().hex(),
                                     'keyId':read(self.root/'subjects/hdisp.json')['keyId'],'keyEpoch':'1'}}},
            'room':{'mini':str(base/'bin/mini'),'host':str(base/'bin/minidregg-host'),'hostConfig':str(home/'host-config.json'),
                'socket':str(home/'operator/mini.sock'),'workspace':str(grain/'state/resource-workspace'),'home':str(grain/'state/room-home'),
                'room':'lab','account':'unsummoned'}}
        # Public Host frames use the public endpoint; reserve authoring uses
        # the separate, controller-only operator proxy.
        spec['hostSocket']=self.c['publicSocket']
        source=self.root/'grain-spec.json';write(source,spec)
        files=[{'source':self.c['hostConfig'],'destination':'host-config.json'},
               {'source':str(Path(self.c['world'])/'genesis.json'),'destination':'bootstrap/genesis.json'},
               {'source':str(source),'destination':'requests/grain-spec.json'}]
        for name in ['hhost','hermes','hprov','hdisp']:
            files.append({'source':str(self.homes/name/'keys/mini.key'),'destination':f'keys/{name}.key'})
        prepare=self.root/'worker-prepare.json';write(prepare,{'protocol':'mini-controller-worker-prepare-v1','task':self.task('controller'),
            'files':files,'directories':['bootstrap/namespace','requests','requests/inbox','worker-work/.hermes','worker-work/.cache','worker-work/.config','worker-work/.local/share'],
            'launcherDirectory':str(launcher),'runtimeRoot':str(runtime)})
        self.fixed('controller-worker-prepare',prepare,self.bins,self.c['operatorSocket'],self.c['publicSocket'])
        self.controller=True
        self.fixed('controller-worker-birth',source)
        self.controller_run('grain-runtime',['create',home/'requests/create.json'])
        self.fixed('controller-worker-publish')
        self.c['controllerHostConfigExport']=str(self.fixed('controller-host-config-export'))
        self.controller_config()
        self.spawn('keys',[self.bins/'mini-keys','serve','--config',brokerconfig]);self.wait_socket(keysocket)
        self.run('provider-socket-acl',['setfacl','-m',f"u:{self.layout['controllerUid']}:rw-",keysocket])
        secret=self.root/'provider-key.secret';secret.write_text('j14-fixture-key\n');secret.chmod(0o600)
        self.run('provider-key',[self.mini,'key','--action','set','--dir',self.workspaces/'alice','--provider','friendkey','--secret',secret,'--broker',keyclient]);secret.unlink()
        self.run('provider-key-grant',[self.mini,'key','--action','grant','--dir',self.workspaces/'alice','--provider','friendkey',
            '--runner',self.subjects['hprov'],'--per-call','64','--per-day','200','--until','1000000000','--broker',keyclient])

    def controller_config(self):
        exported=self.fixed('controller-config-export');self.c['controllerConfig']=str(exported)
        return read(exported)

    def room(self):
        home=Path(self.layout['controllerHome']);grain=Path(self.c['controllerRoot'])
        room=read(self.workspaces/'alice/refs/lab.json')
        registration=self.controller_run('mini',['hermes-handoff','--action','registration','--dir',grain/'state/resource-workspace',
            '--task',self.task('controller'),'--room-cell',room['target'],'--inbox',home/'requests/inbox','--socket',home/'operator/mini.sock'])
        regs=self.root/'registrations';regs.mkdir();shutil.copyfile(registration,regs/(self.task('controller')+'.json'))
        registry=self.run('registry',[self.mini,'hermes-handoff','--action','registry','--registrations',regs,'--socket',self.c['operatorSocket']])
        (self.homes/'alice/hermes').mkdir(exist_ok=True);shutil.copyfile(registry,self.homes/'alice/hermes/registry.json')
        summoned=self.shell('alice','summon lab as librarian --budget 1000').read_text()
        match=re.search(r'hand-off in (.+)',summoned)
        if not match:raise ValueError('summon did not provide its sealed handoff directory')
        outbox=Path(match.group(1).strip());summon=read(outbox/'summon-lab.json')
        self.shell('alice','tariff lab set hermes/provider '+self.task('provider'))
        config=self.controller_config();config['toolTask']['room']['account']=summon['account']['name']
        update=self.root/'summoned-controller.json';write(update,config)
        self.fixed('controller-config',update);self.controller_config()
        dispatched=self.controller_run('mini',['hermes-handoff','--action','dispatch','--registration',home/'requests/registration.json',
            '--bundle',home/'requests/handoff.json','--socket',home/'operator/mini.sock'],files=[
                {'source':str(registration),'destination':'requests/registration.json'},
                {'source':str(outbox/'handoff.json'),'destination':'requests/handoff.json'}])
        self.inbox=read(dispatched)['inbox'];self.prompts=0

    def attach(self):
        contract=self.root/'attachment-input.json';write(contract,inputs.attachment(self.c));self.contract=contract
        def phase(name,*extra):
            return self.run('attachment-'+name,['python3',REPO/'scripts/application-attachment.py',contract,name,*extra],timeout=3600)
        # The CLI returns its retained result path, whose JSON is the phase result.
        def result(path):return read(path.read_text().strip())
        prepared=result(phase('prepare-config'))
        self.fixed('controller-config',prepared['stage'])
        exported=self.controller_config()
        # Preserve the original exported filename selected in the pinned input;
        # the attachment permits only its exact prepared/activated successor.
        shutil.copyfile(self.c['controllerConfig'],read(contract)['paths']['controllerConfig'])
        self.fixed('controller-start')
        request=secrets.token_hex(16);args=self.root/'session-arguments.json';write(args,prepared['nextTool']['arguments'])
        write(self.root/'session-request.json',{'requestId':request,'tool':prepared['nextTool']['name'],'arguments':str(args)})
        session=self.fixed('controller-tool',request,prepared['nextTool']['name'],args)
        value=read(session)
        if value.get('type')!='tool-complete' or value.get('isError') is not False:raise ValueError('session tool not complete; retain request ID for native tool-result')
        retained=self.fixed('controller-tool-result',request)
        if session.read_bytes()!=retained.read_bytes():raise ValueError('session retained result differs')
        self.fixed('controller-stop')
        phase('issue-grant','--input',session)
        layout=dict(self.layout,controllerHome=self.c['controllerRoot'])
        path=self.root/'attachment-layout.json';write(path,layout)
        phase('prepare-route','--input',path)
        self.profile=read(self.c['profileResult'])['profilePath']
        start=self.run('app-start',[self.bins/'spk-host','grain','start',self.profile,'9890001'],timeout=2400)
        self.application_unit=read(start)['unit']
        activated=result(phase('activate','--input',start))
        self.fixed('controller-config',activated['bundle']);self.controller_config()
        self.fixed('controller-start')
        self.fixed('controller-tool-ack',request)
        self.application_unit=read(start)['unit']

    def resident(self,label):
        home=Path(self.layout['controllerHome']);grain=Path(self.c['controllerRoot']);self.prompts+=1
        source=self.root/f'resident-{label}.json';destination=f'requests/resident-{label}.json'
        write(source,{'type':'mini-hermes-room-resident-v1','controller':str(grain/'controller.json'),'inbox':self.inbox,
            'state':str(grain/'state/resident'),'maxPrompts':self.prompts,'intervalSeconds':5})
        result=self.controller_run('grain-runtime',['hermes-room','resident',home/destination],files=[{'source':str(source),'destination':destination}])
        self.run('certify',[self.mini,'checkpoint','--action','certify','--workspace',self.c['sponsorWorkspace'],
            '--control',str(read(Path(self.c['world'])/'genesis.json')['factoryControllerCapability'])])
        return result

    def paid(self):
        result=read(self.run('paid-turns',[self.mini,'credit','--action','ledger','--dir',self.workspaces/'alice',
            '--account','lab-till','--topic','hermes']))
        return len([e for e in result['entries'] if e.get('subject')==self.subjects['hermes'] and e.get('amount')=='10'])

    def web(self,label,granted):
        output=self.logs/f'web-{label}.stdout';p=self.spawn('web-'+label,[self.mini,'web','--dir',self.workspaces/'bob','--home',self.homes/'bob','--listen','127.0.0.1:0'])
        try:
            deadline=time.monotonic()+30;url=None
            while time.monotonic()<deadline:
                match=re.search(r'http://127\.0\.0\.1:[0-9]+/[0-9a-f]+/',output.read_text())
                if match:url=match.group(0);break
                if p.poll() is not None:break
                time.sleep(.1)
            if not url:raise ValueError('resident web face did not open')
            response=self.run('web-page-'+label,['curl','--fail','--silent','--show-error','--max-time','60',url+'room/lab/resident'])
            page=response.read_text();expected='true' if granted else 'false'
            if f'data-tool="oracle" data-granted="{expected}"' not in page:raise ValueError('browser resident grant view differs')
            if not granted and 'data-refusal="oracle-not-granted"' not in page:raise ValueError('browser did not explain the named refusal')
        finally:
            p.terminate();p.wait(timeout=30)

    def probe(self):
        question='Who wrote Leaves of Grass?';oraclelog=self.root/'provider.oracle.jsonl'
        prior_operation=None;asks=set()
        def transcript():
            path=self.shell('alice','tail --in lab --json -n 200')
            return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
        def turn(label,answer):
            nonlocal prior_operation
            old_lines=oraclelog.read_text().splitlines() if oraclelog.exists() else []
            before=self.paid();self.shell('bob','ask lab oracle: '+question)
            rows=transcript()
            selected=[r for r in rows if r.get('author')==self.subjects['bob'] and r.get('to')==self.subjects['hermes']
                      and question in r.get('text','')]
            if not selected:raise ValueError('selected room ask absent from signed history')
            number=str(selected[-1]['n'])
            if number in asks:raise ValueError('room ask did not create a fresh entry')
            asks.add(number)
            self.resident(label)
            all_lines=oraclelog.read_text().splitlines()
            if all_lines[:len(old_lines)]!=old_lines:raise ValueError('provider log prefix changed')
            new_lines=all_lines[len(old_lines):]
            phase_log=self.root/f'oracle-{label}.jsonl';phase_log.write_text('\n'.join(new_lines)+'\n')
            calls=[json.loads(line) for line in new_lines if json.loads(line).get('id')=='or-call']
            if not calls or calls[-1].get('question')!=question:raise ValueError('fresh provider call did not name selected question')
            expected='Whitman' if answer else 'oracle-not-granted'
            replies=[r for r in transcript() if r.get('author')==self.subjects['hermes'] and r.get('to')==self.subjects['bob']
                     and str(r.get('re'))==number and r.get('kind')=='say']
            if not any(expected in r.get('text','') for r in replies):raise ValueError('fresh room reply lacks expected Oracle outcome')
            if self.paid()<=before:raise ValueError('fresh Oracle room reply was not a paid turn')
            if not answer:
                if expected not in calls[-1].get('content',''):raise ValueError('Oracle refusal did not name missing room grant')
                return
            journal=self.fixed('controller-journal')
            path=self.run('answer-evidence-'+label,['python3',HERE/'j14-oracle-evidence.py',phase_log,journal,
                '--route','oracle-app','--expected',expected,'--question',question])
            operation=read(path)['operationId']
            if operation==prior_operation:raise ValueError('fresh turn reused an earlier native operation')
            prior_operation=operation
            return path
        turn('refused',False);self.web('refused',False)
        self.shell('alice','tariff lab set hermes/tools 8');self.web('granted',True)
        evidence=turn('answered',True)
        self.fixed('controller-stop');self.fixed('controller-start')
        turn('controller-restarted',True)
        write(self.root/'result.json',{'protocol':'mini-j14-oracle-result-v1','passed':True,
            'store':self.broker['store'],'controllerUid':self.layout['controllerUid'],'operatorUid':os.getuid(),
            'rows':['same-store-provision','native-grain-create-dispatch','room-refusal','resident-page-grant-state',
                    'native-answer-and-settlement','paid-room-reply','controller-restart-answer'],
            'residentPageEvidence':'HTTP/HTML; rendered browser is covered separately',
            'answerEvidence':str(evidence),'applicationUnit':self.application_unit,
            'applicationRestart':'covered by the separate shared-data lifetime recovery journey'})
        table=self.root/'j14.tsv';table.write_text('step\tverdict\n'+''.join(row+'\tok\n' for row in read(self.root/'result.json')['rows']))
        print(table)


def main():
    j=Journey()
    try:
        for phase in ['world','application','worker','room','attach','probe']:
            if phase=='worker':j.await_worker_release()
            getattr(j,phase)()
            write(j.root/('context-after-'+phase+'.json'),j.c)
    except Exception as error:
        write(j.root/'failure.json',{'phase':phase,'error':str(error),'passed':False,'lastCommand':j.counter,
            'recovery':'Inspect retained exact native attempts; do not repeat an uncertain submission as new work.'})
        raise
    finally:j.cleanup()

if __name__=='__main__':main()
