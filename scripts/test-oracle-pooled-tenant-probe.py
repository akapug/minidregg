#!/usr/bin/env python3
"""Tests report joins only; a fixture is not hosted tenant qualification."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('oracle_report',ROOT/'deploy/oracle/acceptance/report.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)


class PooledProbeTests(unittest.TestCase):
    def fixture(self,run):
        def write(name,value):
            p=run/name;p.parent.mkdir(parents=True,exist_ok=True)
            p.write_text(value if isinstance(value,str) else json.dumps(value))
        write('pooled-tenant-probe-request.json',{'protocol':'mini-oracle-pooled-tenant-probe-v1','app':'9101','path':'/query',
            'request':{'request_id':'mini-u3-weather-structured','conversation_id':'mini-owner-pool-collision','text':'Who wrote Leaves of Grass?'}})
        write('world/evidence/share-a.stdout',{'protocol':'mini-spk-grain-route-v1','app':'9101','subject':'8','session':'9110','kind':'api','issueIndex':'28'})
        write('agent-lifetime/controller-active-initial.json',{'toolTask':{'allowedApplicationLifetimeRoutes':[
            {'name':'oracle-app','appResource':'9101','participantSubject':'20010','sessionResource':'29420','grantDigest':'fixture'}]}})
        write('agent-lifetime/probe/cases.json',[{'name':'weather-structured','tool':'mini_oracle_call','arguments':{
            'requestId':'mini-u3-weather-structured','operationId':'specialist.meteorology-v2.heat_index_f'}}])
        value={'status':200,'bodyText':json.dumps({'operation_id':'specialist.meteorology-v2.heat_index_f',
            'reply':{'status':'answered','unit':'degF','result':[83.29043364000009,'NWS Rothfusz regression']}})}
        write('agent-lifetime/probe/weather-structured.http.json',value)
        write('agent-lifetime/probe-after-restart/weather-structured.http.json',value)
        write('world/evidence/post-a15-body.body',{'reply':{'status':'answered','response':'Walt Whitman'}})
        write('world/evidence/post-a15-body.headers','HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n')
        return write

    def require(self,name,condition):
        self.assertTrue(condition,name)

    def test_distinct_principals_one_grain_and_original_agent_reply_survive(self):
        with tempfile.TemporaryDirectory() as tmp:
            run=Path(tmp);self.fixture(run)
            result=r.pooled_tenant_probe(run,self.require)
            self.assertEqual(result['owner_route']['app'],result['agent_route']['appResource'])
            self.assertIn('same-principal isolation is not tested',result['scope'])

    def test_wrong_grain_collision_failure_or_changed_replay_refuses(self):
        for change in ('wrong-grain','owner-conflict','changed-replay','same-session','same-principal'):
            with self.subTest(change=change),tempfile.TemporaryDirectory() as tmp:
                run=Path(tmp);write=self.fixture(run)
                if change in ('wrong-grain','same-session','same-principal'):
                    p=run/'agent-lifetime/controller-active-initial.json';j=json.loads(p.read_bytes())
                    key,value={'wrong-grain':('appResource','9201'),'same-session':('sessionResource','9110'),
                               'same-principal':('participantSubject','8')}[change]
                    j['toolTask']['allowedApplicationLifetimeRoutes'][0][key]=value;p.write_text(json.dumps(j))
                elif change=='owner-conflict':write('world/evidence/post-a15-body.headers','HTTP/1.1 409 Conflict\r\n')
                else:write('agent-lifetime/probe-after-restart/weather-structured.http.json',{'status':200,'bodyText':'{}'})
                with self.assertRaises(AssertionError):r.pooled_tenant_probe(run,self.require)

    def test_optional_probe_absence_preserves_ordinary_journey(self):
        with tempfile.TemporaryDirectory() as tmp:self.assertIsNone(r.pooled_tenant_probe(Path(tmp),self.require))


if __name__=='__main__':unittest.main()
