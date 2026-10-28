#!/usr/bin/env python3
"""Untrusted J14 input assembly; native receivers check every selector.

The context names this journey's actual enrolled identities, bootstrap tasks,
and selected Store. It never imports identities or genesis from another world.
"""
import argparse
import hashlib
import json
from pathlib import Path


def read(path): return json.loads(Path(path).read_text())
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def write(path, value):
    with Path(path).open('x') as out: json.dump(value,out,indent=2);out.write('\n')

def authority(c):
    w=Path(c['world']); ws=Path(c['sponsorWorkspace']); params=read(w/'genesis-params.json')
    context=read(w/'sponsor-birth-context.json')
    cfg=read(c['hostConfig'])
    def task(name):
        r=read(ws/'refs'/f'{name}.json')
        return {'task':r['target'],'capability':r['operationCapability'],'observeCapability':r['observeCapability']}
    factory=read(ws/'refs/factory.json')
    return {'owner':str(params['sponsor']['subject']),
            'ownerAccountCapability':str(params['sponsor']['spendCapabilityId']),
            'tool':task('tool'),'parent':task('parent'),
            'factory':{'target':factory['target'],'capability':factory['observeCapability']},
            'template':{k:str(cfg[k]) for k in ['issuer','ownerBudget','lifetime']},
            'tariff':{'base':str(cfg['grainBirthTariff']['base']),'perBirth':str(cfg['grainBirthTariff']['perBirth'])}}


def allocation(c):
    roles={}
    role_names={'controller':'hhost','tool':'hermes','provider':'hprov','dispatch':'hdisp'}
    for role,name in role_names.items():
        enrolled=read(Path(c['root'])/'subjects'/f'{name}.json')
        birth=read(Path(c['root'])/'homes'/name/'provision/birth-context.json')
        account=next(g for g in birth['grants'] if g['kind']=='account')
        factory=next(g for g in birth['grants'] if g['kind']=='object')
        roles[role]={'account':account['target'],'factoryObserveCapability':factory['capability'],
                     'subject':enrolled['subject'],'keyId':enrolled['keyId'],
                     'task':str(int(c['taskBase'])+1+['controller','tool','provider','dispatch'].index(role))}
    caps={'parentOwner':'9870011','parentControl':'9870012','toolOwner':'9870013','toolTaskControl':'9870014',
          'providerOwner':'9870015','providerTaskControl':'9870016','dispatchOwner':'9870017','dispatchTaskControl':'9870018'}
    for index,name in enumerate(['sessionOwner','sessionControl','descriptorOwner','descriptorControl',
        'ticketOwner','ticketControl','ticketObserve','appObserve','manifestObserve','snapshotObserve',
        'bootstrapTicketObserve','controllerAppObserve','controllerManifestObserve','agentTicketToolObserve',
        'grantOwner','grantControl','grantObserve']): caps[name]=str(9891100+index)
    agent={'route':'oracle-agent','sessionKind':'api','session':'9891001','descriptor':'9891002',
           'ticket':'9891003','persistentGrant':'9891004',**roles,'plannedCaps':caps}
    return {'protocol':'mini-spk-integrated-allocation-v1','status':'reserved-coordinates-only',
            'app':'9890001','packageManifest':'9890002','snapshotManifest':'9890003','humans':[],'agents':[agent]}


def provision(c):
    w=Path(c['world']); a=authority(c); params=read(w/'genesis-params.json'); profile=read(c['profileResult'])
    app={'app':'9890001','packageManifest':'9890002','snapshotManifest':'9890003'}
    for index,name in enumerate(['appOwnerCapability','appControlCapability','packageOwnerCapability',
        'packageControlCapability','snapshotOwnerCapability','snapshotControlCapability']):app[name]=str(9890101+index)
    d={'subject':a['owner'],'session':'9892001','descriptor':'9892002','ticket':'9892003',
       'sessionKind':'api','expectedHost':'oracle-j14.localhost'}
    for index,name in enumerate(['cap','sessionControlCapability','descriptorOwnerCapability','descriptorControlCapability',
                                'appObserve','pkgObserve','ticketOwner','ticketControl','ticketObserve']):d[name]=str(9892101+index)
    config=read(c['hostConfig']); native=read(c['nativeProfile'])
    return {'protocol':'mini-spk-same-store-attach-v1','root':str(Path(c['root'])/'application'),
            'manifest':c['manifest'],'expectedSourceCommit':read(c['manifest'])['sourceCommit'],
            'miniConfig':c['hostConfig'],'miniConfigSha256':sha(c['hostConfig']),
            'publicSocket':c['publicSocket'],'privateSocket':c['operatorSocket'],
            'workspace':c['sponsorWorkspace'],'genesis':str(w/'genesis.json'),
            'profileResult':c['profileResult'],'initStoreResult':profile['initStoreResult'],'grainsRoot':profile['grainsRoot'],
            'brokerSocket':profile['brokerSocket'],'spk':c['spk'],'spkSha256':sha(c['spk']),'sizeClass':'L',
            'authority':a,'namespace':{'domain':str(config['domain']),'semantics':str(native['semantics'])},
            'room':c['room'],'application':app,'delegates':{'bootstrap':d},
            'keys':{a['owner']:{'keyId':str(params['sponsor']['keyId']),'keyEpoch':str(params['sponsor']['keyEpoch']),
                              'seedPath':str(w/'sponsor.key'),'publicKeyPath':str(w/'sponsor.pub')}}}


def attachment(c):
    w=Path(c['world']); root=Path(c['root']); a=authority(c); params=read(w/'genesis-params.json')
    roles=read(c['allocation'])['agents'][0]; native=read(c['controllerConfig'])
    # Grain creation uses noPrerotation on these freshly enrolled identities.
    # Native signing plans still require this exact epoch/algorithm to match.
    signers=[]
    for role,name in [('controller','hhost'),('tool','hermes'),('provider','hprov'),('dispatch','hdisp')]:
        signers.append({'keyId':roles[role]['keyId'],'keyEpoch':'1','algorithm':'1',
                        'keyPath':str(root/'homes'/name/'keys/mini.key'),
                        'publicKeyPath':str(root/'homes'/name/'keys/mini.key.pub')})
    signers.append({'keyId':str(params['sponsor']['keyId']),'keyEpoch':str(params['sponsor']['keyEpoch']),'algorithm':'1',
                    'keyPath':str(w/'sponsor.key'),'publicKeyPath':str(w/'sponsor.pub')})
    birth=read(root/'homes/hermes/provision/birth-context.json')
    # Use the native provisioned payer and factory grant, never guessed IDs.
    grants=birth['grants']
    factory=next(g for g in grants if g['kind']=='object' and g['target']==str(params['factoryId']))
    account=next(g for g in grants if g['kind']=='account')
    session={'genesis':read(w/'genesis.json'),'template':a['template'],
             'factoryTarget':factory['target'],'factoryObserveCapability':factory['capability'],
             'payerAccount':account['target'],'payerCapability':account['capability'],'payerObserveCapability':account['capability'],
             'tariffBase':a['tariff']['base'],'tariffPerBirth':a['tariff']['perBirth']}
    return {'protocol':'mini-application-attachment-v1','allocation':c['allocation'],
            'paths':{'mini':c['mini'],'host':c['host'],'spkHost':c['spkHost'],'hostConfig':c['hostConfig'],
                     'participantSocket':c['publicSocket'],'operatorSocket':c['operatorSocket'],
                     'profile':read(c['profileResult'])['profilePath'],'repo':c['repo'],
                     'controllerConfig':c['controllerConfig'],'controllerHostConfigExport':c['controllerHostConfigExport'],'controllerHome':c['controllerRoot'],
                     'outputDir':str(root/'attachment')},
            'application':read(c['preparedApplication'])['applications']['bootstrap'],
            'issuer':{'subject':a['owner'],'keyPath':str(w/'sponsor.key'),'payer':a['owner'],'funding':[],
                      'sourceCapabilities':[a['ownerAccountCapability']],'tool':a['tool'],'parent':a['parent'],'reserveAmount':'5'},
            'signers':signers,'sessionProfile':session}


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('phase',choices=['allocation','provision','attachment']);p.add_argument('context');p.add_argument('output')
    args=p.parse_args();write(args.output,globals()[args.phase](read(args.context)))
if __name__=='__main__':main()
