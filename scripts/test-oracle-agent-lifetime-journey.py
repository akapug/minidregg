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


def factory_lean_probe(predicate, agents):
    """Render emitted JSON syntax into production Pred.eval checks; no evaluator here."""
    def lean(node):
        if node["type"] == "eq" and set(node) == {"type","slot","value"}:
            return "(.eq " + json.dumps(node["slot"]) + " " + str(int(node["value"])) + ")"
        if node["type"] in ("all","any") and set(node) == {"type","predicates"}:
            return "(." + node["type"] + " [" + ",".join(map(lean,node["predicates"])) + "])"
        raise ValueError("unexpected emitted factory predicate syntax")
    lines = ["import Pred.Core", "open Minidregg.Pred", "def fixtureLaw : Pred := " + lean(predicate)]
    for subject in (7,8,9,20010,20011,20012,20013):
        for verb, mode in ((1,False),(2,False),(2,True)):
            slots = [("request/subject",subject),("request/verb",verb)]
            if mode: slots.append(("birth/mode/grain-backed",1))
            state = "⟨[" + ",".join("("+json.dumps(k)+","+str(v)+")" for k,v in slots) + "]⟩"
            expected = subject == 7 or (subject in ((8,20011) if agents else (8,)) and (verb == 1 or mode))
            lines.append("#guard eval fixtureLaw ⟨[]⟩ " + state + " == " + str(expected).lower())
    return "\n".join(lines) + "\n"


class HarnessTests(unittest.TestCase):
    def test_owner_worker_policy_uses_exact_native_source_and_readback(self):
        spec = importlib.util.spec_from_file_location("oracle_agent_policy", ROOT / "deploy/oracle/acceptance/agent.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        allocation = json.loads((ROOT / "deploy/oracle/acceptance/agent-allocation.json").read_text())["agents"][0]
        for fault in (None, "active", "changed-policy", "wrong-readback", "unknown-worker"):
            with self.subTest(fault=fault), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                op = object.__new__(module.Operator)
                op.agent, op.calls, op.workroom = allocation, root, root
                op.mini, op.host, op.config, op.public = map(Path, ("/mini", "/host", "/config", "/socket"))
                a, caps = allocation, allocation["plannedCaps"]
                config = {"task": a["controller"]["task"], "subject": a["controller"]["subject"],
                    "capability": caps["parentOwner"], "queryCapability": caps["parentOwner"],
                    "policyControlCapability": caps["parentControl"],
                    "toolTask": {key:a["tool"][key] for key in ("task", "subject")},
                    "dispatchTask": {key:a["dispatch"][key] for key in ("task", "subject")}}
                if fault == "unknown-worker": config["dispatchTask"]["subject"] = "777"
                config_path = root / "controller.json"
                module.write(config_path, config)
                original = {"owner":a["controller"]["subject"], "workerSubjects":[a[role]["subject"] for role in ("tool", "dispatch", "provider")], "workerGeneration":"1"}
                desired = dict(original, workerSubjects=[a[role]["subject"] for role in ("tool", "dispatch")])
                calls = []
                def query(label, subject, task, capability, key, view="resource"):
                    path = root / label
                    path.mkdir()
                    if view == "resource":
                        value = {"cell":{"grain":{"task":task,"generation":"0","status":"2" if fault == "active" else "0","reserved":"0"}}}
                    else:
                        after = label == "policy-after"
                        value = {"policyId":task,"version":"1" if after else "0", "previous":"old-address" if after else None,
                            "domain":"10","semantics":"20","address":"old-address","canonical":"aa",
                            "predicate":desired if after else original}
                        if fault == "changed-policy" and not after: value["predicate"] = {"changed":True}
                        if fault == "wrong-readback" and after: value["previous"] = "wrong"
                    module.write(path / "view.json", value)
                    module.write(path / "challenge.json", {"authorityRoot":"source-root"})
                    return path
                def call(label, args):
                    calls.append((label,args))
                    if args[1] == "author":
                        source = Path(args[args.index("--input")+1])
                        output = Path(args[args.index("--output")+1])
                        module.write(output, json.dumps(module.read(source),sort_keys=True).encode())
                    elif args[1] == "submit":
                        self.assertEqual(args[args.index("--intent-kind")+1], "grain-policy-install-intent")
                        source = module.read(args[args.index("--intent")+1])
                        self.assertEqual(source["currentSourceHex"],"aa")
                        self.assertEqual(source["expectedPreRoot"],"source-root")
                        self.assertEqual(source["expectedVersion"],"0")
                        self.assertEqual(source["control"],caps["parentControl"])
                        self.assertEqual(source["workerSubjects"],desired["workerSubjects"])
                        path = Path(args[args.index("--dir")+1]); path.mkdir()
                        module.write(path / "outcome.json", {"type":"confirmed","confirmation":"installed", "transactionId":"1","eventId":"2","acceptedCount":"3","worldRoot":"4"})
                    else: self.fail("unexpected native operation")
                op.query, op.call = query, call
                if fault is None:
                    report = module.read(op.prepare_worker_policy(config_path))
                    self.assertEqual(report["workers"],desired["workerSubjects"])
                    self.assertEqual(report["receipt"]["acceptedCount"],"3")
                else:
                    with self.assertRaises(ValueError): op.prepare_worker_policy(config_path)
                    self.assertEqual(sum(args[1] == "submit" for _,args in calls), 1 if fault == "wrong-readback" else 0)

    def test_complete_grain_store_overlay_on_frozen_339_source(self):
        # Run the real grain-store -> positive-base -> native-share-member
        # transformations. Stub only native executables, stopping exactly at
        # bootstrap before a Store exists. This is a source composition test.
        baseline = "339abf3e4b37940be0e69620dbf177470b0aeefc"
        inputs = ["scripts/workroom/provision.sh",
                  "scripts/application-share-issue/native-positive-base.sh",
                  "scripts/grain-birth/native-share-member.sh",
                  "native/resource-client/journey.d/lib/genesis-params.sh",
                  "deploy/candidate/params.sh"]
        for mode in ("legacy", "agents", "unrelated-keywords", "missing-config", "duplicate-config"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                repo = root / "repo"
                for name in inputs:
                    path = repo / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(subprocess.check_output(["git", "show", baseline + ":" + name], cwd=ROOT))
                for name in ("scripts/spk-platform/grain-store.sh", "scripts/spk-platform/agent-genesis-overlay.sh",
                             "scripts/grain-birth/native-share-member.sh"):
                    path = repo / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes((ROOT / name).read_bytes())
                provision = repo / "scripts/workroom/provision.sh"
                original = provision.read_text()
                line = ' "storageRoot":"$EVIDENCE/store","signatureBinary":"$SIGNATURE_BINARY"}'
                if mode == "missing-config":
                    provision.write_text(original.replace(line, line.replace("signatureBinary", "changedSignatureBinary")))
                elif mode == "duplicate-config":
                    provision.write_text(original.replace(line, line + "\n" + line))
                elif mode == "unrelated-keywords":
                    provision.write_text(original + "\n# lifecycleManagement agentLifetimeDispatchTargets\n")
                native = root / "native"
                native.write_text('''#!/usr/bin/env python3
import hashlib,json,os,pathlib,sys
args=sys.argv[1:]
if args[0]=='keygen':
 for option in ('--secret','--public'):
  path=pathlib.Path(args[args.index(option)+1]);path.write_bytes(hashlib.sha256(str(path).encode()).digest())
elif len(args)==2 and args[1]=='profile': print(json.dumps({'semantics':'1'}))
elif args[0]=='bootstrap':
 out=pathlib.Path(os.environ['OVERLAY_CAPTURE'])
 for option,name in (('--config','config.json'),('--source','genesis.json')):
  (out/name).write_bytes(pathlib.Path(args[args.index(option)+1]).read_bytes())
 sys.exit(77)
else: raise SystemExit('unexpected native command: '+repr(args))
''')
                native.chmod(0o700)
                capture = root / "capture"
                capture.mkdir()
                env = {key: value for key, value in os.environ.items()
                       if key not in ("CANDIDATE", "SPK_AGENT_ALLOCATION", "GENESIS_PARAMS_TREE")
                       and not key.startswith("WORKROOM_")}
                env.update(OVERLAY_CAPTURE=str(capture), GENESIS_PARAMS_TREE=str(repo))
                if mode != "legacy":
                    env["SPK_AGENT_ALLOCATION"] = str(ROOT / "deploy/oracle/acceptance/agent-allocation.json")
                result = subprocess.run(["sh", str(repo / "scripts/spk-platform/grain-store.sh"),
                                         str(root / "new-world"), *([str(native)] * 4)],
                                        env=env, capture_output=True, text=True)
                if mode in ("missing-config", "duplicate-config"):
                    self.assertEqual(result.returncode, 2)
                    self.assertIn("configuration shape changed", result.stderr)
                    self.assertFalse((capture / "config.json").exists())
                    continue
                diagnostics = result.stderr + "\n".join(p.read_text() for p in root.rglob("*.stderr"))
                self.assertEqual(result.returncode, 77, diagnostics)
                config = json.loads((capture / "config.json").read_text())
                genesis = json.loads((capture / "genesis.json").read_text())
                self.assertEqual(config["lifecycleManagement"], {"managementSubject": 8, "managementKeyId": 8008})
                self.assertEqual(config["grainBirthTariff"], {"base": 2, "perBirth": 1})
                self.assertEqual(config["tariffPerInitialPayloadByte"], 1)
                self.assertEqual(genesis["tariffPerInitialPayloadByte"], "1")
                self.assertFalse((root / "new-world/base/workroom/deployment").exists())
                # This is the actual predicate emitted by all production source
                # transforms, not a separately generated test policy.
                original_law = {"type":"any","predicates":[
                    {"type":"eq","slot":"request/subject","value":"7"},
                    {"type":"all","predicates":[
                        {"type":"eq","slot":"request/subject","value":"8"},
                        {"type":"any","predicates":[
                            {"type":"eq","slot":"request/verb","value":"1"},
                            {"type":"eq","slot":"birth/mode/grain-backed","value":"1"}]}]}]}
                expected_law = json.loads(json.dumps(original_law))
                if mode != "legacy":
                    addition = json.loads(json.dumps(original_law["predicates"][1]))
                    addition["predicates"][0]["value"] = "20011"
                    expected_law["predicates"].append(addition)
                self.assertEqual(genesis["factoryPredicate"], expected_law)
                predicate_file = next(root.glob("new-world/base/workroom.source-stage/factory-predicate.json"))
                self.assertEqual(json.loads(predicate_file.read_bytes()), expected_law)
                if mode == "legacy":
                    # Exact canonical predicate bytes retain the original literal.
                    self.assertEqual(predicate_file.read_text(), json.dumps(original_law,separators=(",",":"))+"\n")
                else:
                    pin = predicate_file.with_name("agent-factory-allocation.sha256").read_text().split()[0]
                    self.assertEqual(pin,hashlib.sha256((ROOT / "deploy/oracle/acceptance/agent-allocation.json").read_bytes()).hexdigest())
                evidence = os.environ.get("ORACLE_FACTORY_EVIDENCE")
                if evidence:
                    destination = Path(evidence) / (mode + "-predicate.json")
                    with destination.open("x") as out: json.dump(genesis["factoryPredicate"],out,sort_keys=True)
                    with destination.with_suffix(".lean").open("x") as out:
                        out.write(factory_lean_probe(genesis["factoryPredicate"],mode != "legacy"))
                if mode == "legacy":
                    self.assertNotIn("agentLifetimeDispatchTargets", config)
                    self.assertEqual(len(genesis["enrollments"]), 3)
                else:
                    targets = config["agentLifetimeDispatchTargets"]
                    self.assertEqual(len(targets), 1)
                    self.assertEqual(targets[0]["grantResource"], 29530)
                    self.assertEqual(targets[0]["legacy"]["ticketResource"], 29520)
                    self.assertNotIn("issueIndex", targets[0]["legacy"])
                    self.assertNotIn("grantIssueIndex", targets[0])
                    self.assertEqual(len(genesis["enrollments"]), 7)

    def test_actual_factory_allocation_guard(self):
        source = (ROOT / "scripts/grain-birth/native-share-member.sh").read_text()
        start = source.index("FACTORY_PREDICATE=")
        end = source.index("# shellcheck",start)
        for fault in (None,"empty","relative","missing","symlink","duplicate","other-role","owner","nonnumeric"):
            with self.subTest(fault=fault), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                allocation = json.loads((ROOT / "deploy/oracle/acceptance/agent-allocation.json").read_bytes())
                if fault == "duplicate": allocation["agents"].append(allocation["agents"][0])
                if fault == "other-role": allocation["agents"][0]["tool"]["subject"] = allocation["agents"][0]["dispatch"]["subject"]
                if fault == "owner": allocation["agents"][0]["tool"]["subject"] = "7"
                if fault == "nonnumeric": allocation["agents"][0]["tool"]["subject"] = "20011|invalid"
                path = root / "allocation.json";path.write_text(json.dumps(allocation))
                selected = str(path)
                if fault == "empty": selected = ""
                if fault == "relative": selected = "allocation.json"
                if fault == "missing": selected = str(root / "absent")
                if fault == "symlink":
                    linked = root / "link.json";linked.symlink_to(path);selected = str(linked)
                env = dict(os.environ,STAGE=str(root),SPK_AGENT_ALLOCATION=selected)
                result = subprocess.run(["sh","-eu"],input=source[start:end],env=env,capture_output=True,text=True)
                self.assertEqual(result.returncode,0 if fault is None else 2,result.stderr)
                self.assertEqual((root / "factory-predicate.json").exists(),fault is None)

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
