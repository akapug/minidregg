import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec=importlib.util.spec_from_file_location('inputs',Path(__file__).with_name('j14-oracle-inputs.py'))
inputs=importlib.util.module_from_spec(spec);spec.loader.exec_module(inputs)

class InputsTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=Path(self.tmp.name)
        self.c={'taskBase':'1900000000000','root':str(self.root),'world':str(self.root/'world'),'sponsorWorkspace':str(self.root/'sponsor'),
                'hostConfig':str(self.root/'host.json')}
        for p in ['world','subjects','sponsor/refs']:(self.root/p).mkdir(parents=True,exist_ok=True)
        self.save('world/genesis-params.json',{'sponsor':{'subject':17,'keyId':7717,'keyEpoch':9,'spendCapabilityId':61},'factoryId':20})
        self.save('world/sponsor-birth-context.json',{})
        self.save('host.json',{'issuer':15,'ownerBudget':999,'lifetime':888,'grainBirthTariff':{'base':4,'perBirth':2}})
        for name,target in [('tool','401'),('parent','402')]:
            self.save('sponsor/refs/'+name+'.json',{'target':target,'operationCapability':str(int(target)+100),'observeCapability':str(int(target)+200)})
        self.save('sponsor/refs/factory.json',{'target':'20','observeCapability':'72'})
        for i,name in enumerate(['hhost','hermes','hprov','hdisp']):
            self.save('subjects/'+name+'.json',{'subject':str(800+i),'keyId':str(900+i)})
            self.save('homes/'+name+'/provision/birth-context.json',{'grants':[{'kind':'object','target':'20','capability':str(1000+i)},
                        {'kind':'account','target':str(1100+i),'capability':str(1200+i)}]})
    def save(self,name,value):
        path=self.root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(value))
    def test_actual_bootstrap_tasks_and_management_authority_are_selected(self):
        a=inputs.authority(self.c)
        self.assertEqual(a['owner'],'17');self.assertEqual(a['factory'],{'target':'20','capability':'72'})
        self.assertEqual(a['tool'],{'task':'401','capability':'501','observeCapability':'601'})
        self.assertEqual(a['tariff'],{'base':'4','perBirth':'2'})
    def test_allocation_uses_enrolled_identities_and_provisioned_accounts(self):
        a=inputs.allocation(self.c)['agents'][0]
        self.assertEqual(a['dispatch']['subject'],'803');self.assertEqual(a['dispatch']['keyId'],'903')
        self.assertEqual(a['tool']['account'],'1101');self.assertEqual(a['tool']['factoryObserveCapability'],'1001')
        self.assertEqual(a['controller']['task'],'1900000000001');self.assertEqual(a['dispatch']['task'],'1900000000004')
        self.assertEqual(len(set(a['plannedCaps'].values())),len(a['plannedCaps']))
    def test_missing_native_provision_context_refuses_assembly(self):
        (self.root/'homes/hermes/provision/birth-context.json').unlink()
        with self.assertRaises(FileNotFoundError):inputs.allocation(self.c)

if __name__=='__main__':unittest.main()
