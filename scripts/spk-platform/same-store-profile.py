#!/usr/bin/env python3
"""Create SPK host profile for an EXISTING pinned Store, without new genesis/services."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import sys
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('fixture',HERE/'ws-continuity-fixture.py');f=importlib.util.module_from_spec(spec);spec.loader.exec_module(f)

def prepare(path):
    f.require(os.getuid()!=0,'run as Store operator')
    c=f.load(path);f.require(c['protocol']=='mini-spk-same-store-profile-input-v1','wrong profile contract')
    import_profile=c.get('importProfile','standard-v1')
    f.require(import_profile in ['standard-v1','market-large-v1','operator-appliance-v1'],'unknown import profile')
    agent_route_profile=c.get('agentRouteProfile','standard-v1')
    f.require(agent_route_profile in ['standard-v1','shared-64-v1'],'unknown agent route profile')
    m=f.load(c['manifest']);f.require(m['sourceCommit']==c['expectedSourceCommit'],'manifest source differs')
    for role in ['host','mini','spkHost']:
        f.require(f.sha(m[role])==m['sha256'][role],'candidate image differs')
    config=f.absolute(c['miniConfig']);f.require(f.sha(config)==c['miniConfigSha256'],'existing config differs')
    value=f.load(config);management=c['management']
    f.require(str(value['lifecycleManagement']['managementSubject'])==management['subject'] and str(value['lifecycleManagement']['managementKeyId'])==management['keyId'],'source management selector differs')
    f.require(value['completionCustodianKey']==Path(c['completionPublicKey']).read_bytes().hex(),'source completion key differs')
    profile=json.loads(__import__('subprocess').check_output([m['host'],str(config),'profile'],timeout=30))
    f.require(str(profile['semantics'])==c['semantics'],'source runtime semantics differs')
    tag=str(profile.get('storeTag',''))
    f.require(len(tag)==16 and all(ch in '0123456789abcdef' for ch in tag),'Host profile lacks its Store tag')
    root=f.absolute(c['root']);f.protected_parent(root.parent);f.require(not root.exists() and not root.is_symlink(),'fresh profile evidence root required');root.mkdir(mode=0o700)
    f.save(root/'input.json',c);f.save(root/'source-profile.json',profile)
    grains=f.absolute(c['grainsRoot']);broker=c.get('brokerSocket',str(f.broker_endpoint(grains)))
    f.require(broker==str(f.broker_endpoint(grains)),'broker must be the selected Store runtime socket')
    args=[m['spkHost'],'grain','init-store',str(grains),m['host'],str(config),'--broker-socket',broker]
    # The exact one-shot attempt/evidence are retained before native invocation.
    rc,out,err=f.logged_run(args,root/'init-store')
    f.require(rc==0,'native SPK Store registration uncertain; inspect retained exact attempt')
    initialized=f.load(out);f.require(initialized['protocol']=='mini-spk-grain-init-store-v1' and initialized.get('brokerSocket')==broker,'native Store registration differs')
    f.save(root/'init-store.json',initialized)
    state=f.absolute(initialized['stateRoot']);f.require(state.is_relative_to(grains) and state.resolve()==state,'native Store root differs')
    f.require(state==grains/tag/'host' and initialized.get('store')==tag,'native Store root is not named by the Host Store tag')
    destination=state/'grain-host.json';f.require(not destination.exists() and not destination.is_symlink(),'profile already exists; preserve and use its retained result')
    host={'protocol':'mini-spk-grain-host-v2','stateRoot':str(state),'grainsRoot':str(grains),'miniHost':m['host'],'miniHostSha256':m['sha256']['host'],
          'miniConfig':str(config),'miniConfigSha256':c['miniConfigSha256'],'miniOperatorSocket':c['privateSocket'],
          'managementSubject':management['subject'],'managementKeyEpoch':management['keyEpoch'],'managementPublicKeyHex':Path(management['publicKeyPath']).read_bytes().hex(),
          'managementSeed':management['seedPath'],'completionCustodianSeed':c['completionSeed'],'completionSemantics':c['semantics'],
          'bwrap':c['bwrap'],'bwrapSha256':f.sha(c['bwrap']),'spkHost':m['spkHost'],'spkHostSha256':m['sha256']['spkHost'],
          'wsAuthorityLeaseSeconds':c.get('leaseSeconds',120)}
    host['brokerSocket']=broker
    # Native importer enforces the selected policy; this only carries its name.
    host['importProfile']=import_profile
    if agent_route_profile != 'standard-v1':
        host['agentRouteProfile']=agent_route_profile
    f.save(destination,host);os.chmod(destination,0o600)
    result={'protocol':'mini-spk-grain-profile-result-v1','profilePath':str(destination),'stateRoot':str(state),'grainsRoot':str(grains),
            'miniConfig':str(config),'miniConfigSha256':c['miniConfigSha256'],'initStoreResult':str(root/'init-store.json'),'brokerSocket':broker}
    f.save(root/'profile-result.json',result)
    return dict(result,profileResult=str(root/'profile-result.json'))
def main():
    os.umask(0o077);p=argparse.ArgumentParser(description=__doc__);p.add_argument('input');a=p.parse_args();print(json.dumps(prepare(a.input)))
if __name__=='__main__':main()
