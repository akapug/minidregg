#!/usr/bin/env python3
"""Harness checks only; mocked transport is never native lifetime qualification."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts/oracle-agent-lifetime-journey.sh"
OVERLAY = ROOT / "scripts/spk-platform/agent-genesis-overlay.sh"


class HarnessTests(unittest.TestCase):
    def test_fixed_cases_cover_bounded_operations_and_errors(self):
        cases = json.loads((ROOT / "deploy/oracle/acceptance/agent-cases.json").read_text())
        self.assertEqual(len(cases), 9)
        self.assertEqual(len({case["name"] for case in cases}), len(cases))
        calls = [case for case in cases if case["tool"] == "mini_oracle_call"]
        self.assertEqual(len({case["arguments"]["requestId"] for case in calls}), len(calls))
        self.assertEqual({case["status"] for case in cases}, {200, 400, 404})
        for case in cases:
            self.assertNotIn("application", case["arguments"])
            self.assertLess(len(json.dumps(case["arguments"]).encode()), 65536)
        self.assertTrue(any(case["bodyContains"].get("reply", {}).get("status") == "withheld" for case in calls))
        self.assertTrue(any(case["arguments"].get("operationId") == "artist.compose" for case in calls))

    def test_activation_requires_current_native_generation(self):
        spec = importlib.util.spec_from_file_location("oracle_agent", ROOT / "deploy/oracle/acceptance/agent.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        start = {"app": "9101", "generation": "2", "unit": "oracle-g2.service"}
        active = {"generation": "2", "unit": "oracle-g2.service", "state": "running", "unitActiveState": "active"}
        def status(runs):
            return {"protocol": "mini-spk-grain-status-v2", "app": "9101", "runs": runs}
        module.require_current_start(start, status([active]))
        for runs in [[], [active, active], [dict(active, generation="1")],
                     [dict(active, unit="wrong.service")], [dict(active, state="stopped")],
                     [dict(active, unitActiveState="inactive")]]:
            with self.subTest(runs=runs), self.assertRaises(ValueError):
                module.require_current_start(start, status(runs))

    def test_route_renderer_legacy_and_explicit_allocation_guards(self):
        source = (ROOT / "scripts/spk-platform/prepare-lifetime-route.sh").read_text()
        # Execute the renderer's actual jq guard, not a parallel validator.
        expression = re.search(r'''jq -e --argjson expected "\$EXPECTED" --argjson custodyOnly "\$CUSTODY_ONLY" '(.*?)' "\$PINS"''',
                               source, re.S).group(1)
        pins = dict.fromkeys([
            "enrollmentObserveCapability", "manifestObserveCapability", "maximumCharge",
            "parentCapability", "parentObserve", "purseCapability", "purseObserve",
            "reserveAmount", "sessionObserveCapability"], "1")
        pins.update(appSigners=[{}], grantSigner={}, payerPins=[{}, {}, {}],
                    hostUid=1000, hostUnit="oracle.service", socketPath="/private/agent.sock",
                    controllerRouteName="workroom-app", signedApiPath="/repo.git/",
                    packageManifest="8402", snapshotManifest="8403", purseResource="7940", payerSubject="10")
        expected = {"packageManifest": "9102", "snapshotManifest": "9103",
                    "purseResource": "27940", "payerSubject": "20012"}
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "pins.json"
            def check(value, selected, custody_only=False):
                path.write_text(json.dumps(value))
                return subprocess.run(["jq", "-e", "--argjson", "expected", json.dumps(selected),
                                       "--argjson", "custodyOnly", json.dumps(custody_only), expression, str(path)], capture_output=True).returncode == 0
            self.assertTrue(check(pins, None))
            modern = dict(pins, **expected, controllerRouteName="oracle-app", signedApiPath="/")
            self.assertTrue(check(modern, expected))
            self.assertTrue(check(dict(modern, hostUnit=None), expected, True))
            self.assertFalse(check(dict(modern, hostUnit=None), expected))
            self.assertFalse(check(modern, None))
            self.assertFalse(check(dict(modern, payerSubject="20010"), expected))
            for bad in ["relative/", "/../", "/?q=x/", "/%2e/"]:
                self.assertFalse(check(dict(modern, signedApiPath=bad), expected))

    def test_allocation_old_and_oracle_generate_native_source(self):
        for filename in ["scripts/spk-platform/allocation-v1.json",
                         "deploy/oracle/acceptance/agent-allocation.json"]:
            with self.subTest(filename=filename), tempfile.TemporaryDirectory() as tmp:
                output = Path(tmp) / "provision.sh"
                subprocess.run(["sh", str(OVERLAY), str(ROOT / "scripts/workroom/provision.sh"),
                                str(ROOT / filename), str(output)], check=True)
                subprocess.run(["sh", "-n", str(output)], check=True)
                source = output.read_text()
                self.assertIn('"$MINI" bootstrap', source)
                self.assertIn('birth-with-agents.json', source)
                self.assertIn('parent-delegations.jsonl', source)
                self.assertNotIn('for route in hermes-a hermes-b', source)

    def test_allocation_collision_and_shell_name_refused(self):
        original = json.loads((ROOT / "deploy/oracle/acceptance/agent-allocation.json").read_text())
        for mutation in ["duplicate", "shell", "empty"]:
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as tmp:
                data = json.loads(json.dumps(original))
                if mutation == "duplicate":
                    data["agents"][0]["dispatch"]["task"] = data["agents"][0]["tool"]["task"]
                elif mutation == "shell":
                    data["agents"][0]["route"] = "oracle;touch-bad"
                else:
                    data["agents"] = []
                path = Path(tmp) / "allocation.json"
                path.write_text(json.dumps(data))
                result = subprocess.run(["sh", str(OVERLAY), str(ROOT / "scripts/workroom/provision.sh"),
                                         str(path), str(Path(tmp) / "out.sh")], capture_output=True)
                self.assertNotEqual(result.returncode, 0)

    def run_probe(self, mode):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            # Fake executable emits the already-verified result shapes only.
            # This exercises the probe's evidence joins, not Mini signatures.
            runtime = root / "runtime"
            runtime.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
r=pathlib.Path(__file__).parent
mode=os.environ['PROBE_TEST_MODE']
request='a'*32
receipt={'transactionId':'1','eventId':'2','acceptedCount':'3','worldRoot':'4'}
http={'protocol':'mini-spk-agent-api-v3','type':'http-v3','operationId':'10',
 'status':200,'bodyText':json.dumps({'protocol':'oracle-operations-v1'}),
 'bindingSha256':'b'*64,'operationFingerprint':'123',
 'committedReceipt':receipt,'responseSha256':'c'*64}
if mode=='receiving': http['type']='http'
if mode=='wrong-body': http['bodyText']='{}'
attempt={'operationId':10,'routeName':'oracle-app','phase':'definite','reported':True,
 'bindingSha256':http['bindingSha256'],'operationFingerprint':http['operationFingerprint'],
 'lifetimeCommittedReceipt':receipt,'lifetimeSettledResponseSha256':http['responseSha256'],
 'lifetimeSettlement':{'forwardOperationId':10,'settlement':{'operation':'dispatch settle'}}}
if mode=='unsettled': attempt.pop('lifetimeSettlement')
result={'type':'tool-complete','requestId':request,'isError':False,
 'result':{'isError':False,'text':json.dumps(http)}}
if sys.argv[1]=='tool-id': print(request)
elif sys.argv[1]=='tool':
 args=json.loads(pathlib.Path(sys.argv[6]).read_text())
 assert args['application']=='oracle-app'
 (r/'journal.json').write_text(json.dumps({'applicationApiHistory':[attempt]}))
 print(json.dumps(result))
elif sys.argv[1]=='tool-result': print(json.dumps(result))
elif sys.argv[1]=='tool-ack': print('{}')
else: sys.exit(2)
''')
            runtime.chmod(0o700)
            host = root / "host"
            host.write_bytes(b"host-pin-only")
            digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
            config = root / "controller.json"
            config.write_text(json.dumps({
                "host": str(host), "controlSocket": str(root / "control.sock"), "stateDir": str(root),
                "task": "1", "subject": "1", "foregroundTool": {"reserve": "1", "charge": "0"},
                "toolTask": {"task": "2", "subject": "2", "lifetimeApiHostSha256": digest(host),
                    "applicationServices": [{"application": "oracle-app", "protocol": "oracle-operations-v1"}],
                    "allowedApplicationLifetimeRoutes": [{"name": "oracle-app"}]},
                "dispatchTask": {"task": "3", "subject": "3", "operatorSocket": "/unused", "reserveSigner": {}}
            }))
            cases = root / "cases.json"
            cases.write_text(json.dumps([{"name": "discovery", "tool": "mini_oracle_discover", "arguments": {},
                                          "status": 200, "bodyContains": {"protocol": "oracle-operations-v1"}}]))
            env = dict(os.environ, QUALIFIED_RUNTIME_SHA256=digest(runtime),
                       QUALIFIED_LIFETIME_HOST_SHA256=digest(host), PROBE_TEST_MODE=mode)
            with socket.socket(socket.AF_UNIX) as server:
                server.bind(str(root / "control.sock"))
                result = subprocess.run(["sh", str(HELPER), str(runtime), str(config), "oracle-app",
                                         str(cases), str(root / "evidence")], env=env, capture_output=True, text=True)
            if mode == "pass":
                self.assertEqual(result.returncode, 0, result.stderr)
            else:
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse((root / "evidence/result.json").exists())

    def test_probe_requires_lifetime_and_settlement_and_body(self):
        for mode in ["pass", "receiving", "unsettled", "wrong-body"]:
            with self.subTest(mode=mode):
                self.run_probe(mode)


if __name__ == "__main__":
    unittest.main()
