#!/usr/bin/env python3
"""J14 for hosted apps through Hermes: one Store, one controller, typed app tools (Davros).

Derives from the J14_ORACLE driver (the native phases are shared). The differences:
  * the app is a repackaged Davros whose package declares an api interface;
  * the controller config carries a typed attachment (toolTask.typedApplications) instead of
    an Oracle service profile;
  * the provider route is the operator's pool row (OpenRouter) by default, the real model, with
    the key read from J14_APPS_POOL_KEY (a private file; never printed or logged);
  * the probe is one Hermes task: refused without the room's apps grant, then put and get.

J14_APPS_UNTIL names the last phase to run (world, prepare_platform, prepare_application,
worker, room, attach, probe). Extra env: J14_APPS_DECLARATION (apps/interfaces/davros.json),
J14_APPS_MODEL, J14_APPS_POOL_KEY.
"""
import fcntl, hashlib, importlib.util, json, os, shutil, sys, time
from pathlib import Path
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('j14_oracle',HERE/'j14-oracle.py')
m=importlib.util.module_from_spec(spec);sys.modules['j14_oracle']=m;spec.loader.exec_module(m)
read,write,sha=m.read,m.write,m.sha
ORDER=['world','prepare_platform','prepare_application','worker','room','attach','probe']
POOL='pool'

def declaration_digest(value):
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()

class Apps(m.Journey):
    MODEL=os.environ.get('J14_APPS_MODEL','anthropic/claude-sonnet-4.5')
    MAX_INPUT=65536
    MAX_OUTPUT=2048

    def __init__(self):
        super().__init__()
        self.declaration_path=Path(os.environ['J14_APPS_DECLARATION']).resolve(strict=True)
        self.declaration=read(self.declaration_path)
        self.alias='dav'
        self.c['sizeClass']='M'

    # ---- provider: the operator's pool row, the real model -------------------------------------
    def start_provider(self,port):
        write(self.table,{'type':'mini-provider-table-v2','providers':[{'name':POOL,'kind':'openai-compatible',
            'endpoint':'https://openrouter.ai/api/v1/chat/completions','models':[self.MODEL],'credential':'pool',
            'caps':{'perCall':str(self.MAX_OUTPUT),'perDay':'200','ceilingMicroUsd':'12000000','callMicroUsd':'250000',
                    'memberDayMicroUsd':'12000000','memberTotalMicroUsd':'12000000'}}]})

    def gateway_config(self,port,base):
        reserve=7+(self.MAX_INPUT*100000+self.MAX_OUTPUT*200000+999999)//1000000
        return {'providers':str(base/'worker/runtime-root/providers.json'),'credentialBroker':str(base/'worker/runtime-root/keys-client.json'),
            'gatewayBind':f'127.0.0.1:{m.available_port()}','model':self.MODEL,'provider':POOL,
            'reserve':str(reserve+1000),'maxInputTokens':self.MAX_INPUT,'maxOutputTokens':self.MAX_OUTPUT,
            'maxRequestBytes':1048576,'maxResponseBytes':8388608,'timeoutSeconds':600,'localFixtureHostNetwork':False}

    def set_provider_keys(self,keyclient):
        source=Path(os.environ['J14_APPS_POOL_KEY'])
        info=source.stat()
        if info.st_mode&0o077 or source.is_symlink():raise ValueError('pool key file must be private')
        secret=self.root/'pool-key.secret';secret.write_bytes(source.read_bytes());secret.chmod(0o600)
        try:
            self.run('pool-key',[self.mini,'key','--action','set','--pool','true','--provider',POOL,'--secret',secret,'--broker',keyclient])
        finally:secret.unlink()

    # ---- attachment: Davros, the api route, a typed attachment ---------------------------------
    def attach(self):
        d=self.declaration
        self.c['expectedHost']='dav-j14.localhost'
        self.c['attachmentExtras']={
            'names':{'application':'dav-app','family':'dav-session','route':'dav-agent-v1','display':'Davros agent',
                     'handle':'dav-agent','serviceProtocol':None,'applicationFamily':'oracle'},
            'typed':{'alias':self.alias,'declarationSource':str(self.declaration_path),
                     'declarationSha256':declaration_digest(d),'packageId':d['packageId']}}
        super().attach()

    # ---- probe -----------------------------------------------------------------------------
    def transcript(self):
        path=self.shell('alice','tail --in lab --json -n 200')
        return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]

    def replies_to(self,rows):
        return [r for r in rows if r.get('author')==self.subjects['hermes'] and r.get('to')==self.subjects['bob'] and r.get('kind')=='say']

    def task_turn(self,label,text):
        """One ask, one resident invocation; returns the new Hermes replies to bob."""
        exported=read(self.fixed('controller-export'))
        completed=self.completed_prompts(exported)
        known={(r['cell'],r['sequence']) for r in self.replies_to(self.transcript())}
        before=self.paid()
        self.shell('bob','ask lab '+text)
        self.resident(label,completed)
        new=[r for r in self.replies_to(self.transcript()) if (r['cell'],r['sequence']) not in known]
        if not new:raise ValueError('Hermes sent no reply to the ask: '+label)
        if self.paid()<=before:raise ValueError('the reply was not a paid turn: '+label)
        return new

    def application_attempts(self):
        journal=read(self.fixed('controller-journal'))
        history=journal.get('applicationApiHistory') or []
        return [a for a in history if a.get('routeName')=='dav-app' or a.get('route_name')=='dav-app']

    def probe(self):
        marker='Hermes was here %s'%self.root.name
        refused=self.task_turn('refused','Use your hosted Davros tool mini_app_dav_file_put_text to save the text "x" at path refused.txt, '
            'then tell me the exact outcome you received, including any refusal name.')
        write(self.root/'refused-replies.json',refused)
        if not any('typed-apps-not-granted' in r.get('text','') for r in refused):
            raise ValueError('the ungranted task did not meet the named refusal typed-apps-not-granted')
        if self.application_attempts():raise ValueError('a refused task reached the application API')
        self.shell('alice','tariff lab set hermes/tools 16')
        done=self.task_turn('granted','Use your hosted Davros tools in this one task. First call mini_app_dav_file_put_text to save the text "%s" '
            'at path notes.txt, then call mini_app_dav_file_get_text for notes.txt and tell me the exact content you read back.'%marker)
        write(self.root/'granted-replies.json',done)
        if not any(marker in r.get('text','') for r in done):raise ValueError('the reply does not carry the read-back content')
        attempts=self.application_attempts()
        write(self.root/'application-attempts.json',attempts)
        if len(attempts)<2:raise ValueError('expected a put and a get dispatch on the Davros route, saw %d'%len(attempts))
        write(self.root/'result.json',{'protocol':'mini-j14-apps-result-v1','passed':True,'marker':marker,'store':self.broker['store'],
            'rows':['same-store-provision','typed-attachment','room-refusal-by-name','put-and-get-through-mini'],
            'browserRead':'not yet'})
        print(self.root/'result.json')

def main():
    until=os.environ.get('J14_APPS_UNTIL','probe')
    if until not in ORDER:raise SystemExit('J14_APPS_UNTIL must be one of '+','.join(ORDER))
    j=Apps();phase='init'
    try:
        for phase in ORDER[:ORDER.index(until)+1]:
            if phase=='world':
                # hbox convention: world-up serialized by a lock held only around world-up.
                with open('/tank/lanes/world-up.lock','a') as lock:
                    fcntl.flock(lock,fcntl.LOCK_EX);j.world()
            else:getattr(j,phase)()
            write(j.root/('context-after-'+phase+'.json'),j.c)
            print('phase done',phase,flush=True)
    except Exception as error:
        write(j.root/'failure.json',{'phase':phase,'error':str(error),'passed':False,'lastCommand':j.counter})
        raise
    finally:j.cleanup()

if __name__=='__main__':main()
