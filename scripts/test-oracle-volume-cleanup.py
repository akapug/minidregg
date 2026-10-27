#!/usr/bin/env python3
"""Focused checks for the physical cleanup observer, without root effects."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('volume_cleanup', Path(__file__).parents[1] / 'deploy/oracle/acceptance/volume_cleanup.py')
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)


class CleanupTests(unittest.TestCase):
    def setUp(self):
        self.store = 'ab' * 8
        self.root = '/var/lib/mini-spk-worlds/' + self.store
        self.request = {'verb':'create','store':self.store,'deploymentId':'cd'*32,'grain':'9101',
                        'volumePath':self.root+'/vars/'+self.store+'-9101','appUid':100048,
                        'sizeMib':2048,'volumeId':'ef'*32}
        self.inventory = {'protocol':'mini-spk-volumes-status-v1','store':self.store,
                          'volumesRoot':self.root+'/volumes', 'volumes':[
                              {'request':{**self.request,'verb':'mount'},'mounted':False,'settled':True,'paused':False}]}

    def run_plan(self, inventory=None, request=None, observation=(1,b'',b'')):
        return v.plan(self.root, inventory or self.inventory,
                      [('volume-9101.json', json.dumps(request or self.request).encode())],
                      lambda path: observation)

    def test_repeated_absent_observation_skips_without_mutating_request(self):
        original = copy.deepcopy(self.inventory)
        for _ in range(2):
            plan = self.run_plan()
            self.assertEqual(plan['volumes'][0]['action'], 'already-unmounted')
            self.assertEqual(plan['volumes'][0]['request']['verb'], 'unmount')
        self.assertEqual(self.inventory, original)
        self.assertEqual(self.request['verb'], 'create')

    def test_present_volume_still_requires_native_unmount(self):
        self.inventory['volumes'][0]['mounted'] = True
        result = self.run_plan(observation=(0,(self.request['volumePath']+'\n').encode(),b''))
        self.assertEqual(result['volumes'][0]['action'], 'unmount')

    def test_probe_errors_unexpected_paths_and_disagreement_refuse(self):
        for observation in ((2,b'',b''),(1,b'',b'error'),(1,b'output',b''),
                            (0,b'/different\n',b''),(0,(self.request['volumePath']+'\n').encode(),b'')):
            with self.subTest(observation=observation), self.assertRaises(ValueError):
                self.run_plan(observation=observation)

    def test_registration_identity_drift_and_foreign_world_refuse(self):
        for key, value in (('volumeId','00'*32),('appUid',100049),('sizeMib',1024),
                           ('deploymentId','00'*32),('store','00'*8),('volumePath','/other')):
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.run_plan(request={**self.request,key:value})

    def test_unsettled_paused_duplicates_and_missing_registration_refuse(self):
        for key,value in (('settled',False),('paused',True),('mounted',0)):
            changed=copy.deepcopy(self.inventory); changed['volumes'][0][key]=value
            with self.subTest(key=key), self.assertRaises(ValueError): self.run_plan(inventory=changed)
        for rows in ([],self.inventory['volumes']*2,self.inventory['volumes']*65):
            with self.assertRaises(ValueError): self.run_plan(inventory={**self.inventory,'volumes':rows})

    def test_bounded_regular_no_symlink_input_and_duplicate_json_keys(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'request.json'; path.write_bytes(b'{"ok":true}')
            self.assertEqual(v.read(path,32),path.read_bytes())
            with self.assertRaises(ValueError): v.read(path,2)
            alias=Path(directory)/'alias'; alias.symlink_to(path)
            with self.assertRaises(OSError): v.read(alias,32)
        with self.assertRaises(ValueError): v.decode(b'{"mounted":false,"mounted":true}')


if __name__ == '__main__':
    unittest.main()
