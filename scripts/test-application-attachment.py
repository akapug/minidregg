#!/usr/bin/env python3
"""Attachment orchestration tests; fake transport is not native admission evidence."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("attachment", ROOT / "scripts/application-attachment.py")
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)


class AttachmentTests(unittest.TestCase):
    def test_inspection_mode_is_explicit_without_fallback(self):
        op = M.Attachment.__new__(M.Attachment)
        with tempfile.TemporaryDirectory() as directory:
            op.mini = Path(directory) / "mini"; op.mini.write_bytes(b"qualified image")
            op.operator = Path(directory) / "operator.sock"
            op.contract = {}
            self.assertEqual(op.inspection_args(), ["--served", op.mini, op.operator, M.sha(op.mini)])
            op.contract = {"inspectionMode": "detached"}
            self.assertEqual(op.inspection_args(), [])

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.alloc = M.read(ROOT / "deploy/oracle/acceptance/agent-allocation.json")
        self.a = self.alloc["agents"][0]
        self.caps = self.a["plannedCaps"]
        def file(name, data):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            M.write(path, data)
            return str(path)
        self.file = file
        binaries = {key: file("bin/" + key, key.encode()) for key in ("mini", "host", "spkHost", "grainRuntime")}
        self.config = file("operator.json", {"expectedSeed": "17", "domain": "1"})
        package = self.root / "state/apps/9101/install/launch-descriptor/package-v1"
        self.file(str(package.relative_to(self.root) / "schema-inspection.json"), {"root": "41", "version": "3"})
        self.file(str(package.relative_to(self.root) / "descriptor-inspection.json"), {"interfaces": [{"kind": "api", "id": "9", "version": "2", "root": "42"}]})
        self.file(str(package.parent.relative_to(self.root) / "launch-inspection.json"), {"root": "43"})
        paths = dict(binaries, hostConfig=self.config, participantSocket=str(self.root / "participant.sock"),
            operatorSocket=str(self.root / "operator.sock"), repo=str(ROOT), controllerHome=str(self.root / "home"),
            controllerConfig=str(self.root / "controller.json"), outputDir=str(self.root / "attachment"))
        paths["profile"] = file("profile.json", {"miniConfig": self.config, "miniConfigSha256": M.sha(self.config),
            "miniHostSha256": M.sha(binaries["host"]), "miniOperatorSocket": paths["operatorSocket"], "stateRoot": str(self.root / "state")})
        controller = {"host": binaries["host"], "mini": binaries["mini"], "hostConfig": self.config,
            "hostSocket": paths["participantSocket"], "controlSocket": str(self.root / "home/state/control.sock"),
            "task": self.a["controller"]["task"], "subject": self.a["controller"]["subject"],
            "capability": self.caps["parentOwner"], "queryCapability": self.caps["parentOwner"], "commands": [{"name": "keep-me"}]}
        for field, role, cap in (("toolTask", "tool", "toolOwner"), ("dispatchTask", "dispatch", "dispatchOwner")):
            controller[field] = {"task": self.a[role]["task"], "subject": self.a[role]["subject"],
                                 "capability": self.caps[cap], "queryCapability": self.caps[cap]}
        controller["toolTask"]["registeredSharedApplications"] = [{"name": "other-app"}]
        file("controller.json", controller)
        signers = []
        for index, role in enumerate(("controller", "tool", "dispatch")):
            signers.append({"keyId": self.a[role]["keyId"], "keyEpoch": "77", "algorithm": "1",
                "keyPath": file(role + ".key", bytes([index + 1]) * 32), "publicKeyPath": file(role + ".pub", bytes([index + 4]) * 32)})
        app = {"app": "9101", "packageManifest": "9102", "snapshotManifest": "9103",
               "appOwnerCapability": "501", "packageOwnerCapability": "502", "snapshotOwnerCapability": "503"}
        self.confirmed = {"type": "confirmed", "confirmation": "installed", "transactionId": "1", "eventId": "2", "acceptedCount": "8", "worldRoot": "3"}
        file("birth/call.bin", b"native birth placeholder")
        file("birth/outcome.json", self.confirmed)
        file("bootstrap/ingress.bin", b"native issue placeholder")
        file("bootstrap/receipt-anchor.json", {"receipt": M.receipt(self.confirmed)})
        app_input = {"birthSource": file("birth-source.json", {"applicationGrainBirth": {"applicationBirth": {"application": app}}}),
            "birthAttempt": str(self.root / "birth"), "bootstrapTicketRequest": file("bootstrap-request.json", {
                "spec": {"ticket": {"resource": "520", "scope": {"app": "9101"}}, "ticketOwnerCapability": "521"}}),
            "bootstrapTicketAttempt": str(self.root / "bootstrap"), "packageDirectory": str(package)}
        self.contract = {"protocol": "mini-application-attachment-v1", "paths": paths,
            "allocation": file("allocation.json", self.alloc), "application": app_input, "signers": signers,
            "issuer": {"subject": "313", "keyPath": signers[0]["keyPath"], "payer": "314", "funding": [],
                "sourceCapabilities": ["315"], "reserveAmount": "7", "tool": {"task": "316", "capability": "317", "observeCapability": "318"},
                "parent": {"task": "319", "capability": "320", "observeCapability": "321"}},
            "sessionProfile": {"genesis": {}, "factoryTarget": "10"}}
        self.path = file("attachment-input.json", self.contract)

    def rewrite(self, path, value):
        Path(path).write_text(json.dumps(value))

    def prepared_legacy_repair(self):
        op = M.Attachment(self.path, "prepare-config")
        op.bootstrap_name = "oracle-app-bootstrap"
        def delegate(label, *args):
            directory = op.calls / (label + "-attempt")
            directory.mkdir(mode=0o700)
            M.write(directory / "outcome.json", self.confirmed)
            return M.receipt(self.confirmed)
        op.delegate_observe = delegate
        op.prepare_config()
        # The historical helper omitted this allowance as well as misnaming
        # the bootstrap reference. Preserve both old defects in this fixture.
        legacy_config = M.read(op.controller_stage)
        legacy_config.pop("foregroundTool", None)
        self.rewrite(op.controller_stage, legacy_config)
        legacy_stage = M.read(op.root / "controller-stage.json")
        legacy_stage["configSha256"] = M.sha(op.controller_stage)
        self.rewrite(op.root / "controller-stage.json", legacy_stage)
        previous = self.file("old-attachment.py", b"original prepared orchestration source")
        pin = M.read(op.root / "attachment.json")
        pin["files"]["orchestrator"] = previous
        pin["sha256"]["orchestrator"] = M.sha(previous)
        self.rewrite(op.root / "attachment.json", pin)
        status = self.file("stopped.json", {"store": "0123456789abcdef", "stopped": True,
            "controllerUid": M.os.getuid() + 10000,
            "stoppedUnits": [f"mini-grain-controller@{self.a['controller']['task']}.service"],
            "controllerConfigSha256": M.sha(op.controller_stage),
            "runtimeSha256": pin["sha256"]["grainRuntime"]})
        evidence = self.file("export.json", {"protocol": "mini-spk-controller-evidence-v1", "store": "0123456789abcdef",
            "files": {"controller.lock": {"sha256": M.hashlib.sha256(b"").hexdigest(), "base64": ""}}})
        request = self.file("repair.json", {"protocol": "mini-application-attachment-bootstrap-repair-v1",
            "previousOrchestrator": previous, "controllerStatus": status,
            "controllerEvidence": evidence, "expectedStore": "0123456789abcdef",
            "expectedRuntimeSha256": pin["sha256"]["grainRuntime"]})
        return op, Path(request)

    def test_prepared_bootstrap_repair_preserves_delegations_and_is_exactly_reentrant(self):
        op, request = self.prepared_legacy_repair()
        before_config = M.read(op.controller_stage)
        original_input = Path(self.contract["paths"]["controllerConfig"]).read_bytes()
        native = {str(p): p.read_bytes() for p in op.calls.rglob("*") if p.is_file()}
        with patch.object(M.subprocess, "run", side_effect=AssertionError("repair invoked native code")):
            result = M.repair_prepared_bootstrap(Path(self.path), request)
            self.assertEqual(M.repair_prepared_bootstrap(Path(self.path), request), result)
        self.assertEqual(M.read(op.root / "controller-stage.json")["nextTool"]["arguments"]["application"], "oracle-bootstrap-app")
        config = M.read(op.controller_stage)
        config["toolTask"]["registeredSharedApplications"][-1]["name"] = "oracle-app-bootstrap"
        self.assertEqual(config, before_config)
        self.assertEqual(Path(self.contract["paths"]["controllerConfig"]).read_bytes(), original_input)
        self.assertEqual({str(p): p.read_bytes() for p in op.calls.rglob("*") if p.is_file()}, native)
        self.assertEqual(M.read(op.root / "attachment.json")["sha256"]["orchestrator"], M.sha(M.__file__))
        self.assertTrue((Path(result["archive"]) / "source-before.py").is_file())
        # A later ordinary phase accepts the explicitly adopted orchestrator.
        M.Attachment(self.path, "issue-grant")

    def test_prepared_bootstrap_repair_accepts_external_runtime_with_explicit_stopped_pin(self):
        self.contract["paths"].pop("grainRuntime")
        self.rewrite(self.path, self.contract)
        # Build ordinary fixture with a temporary runtime pin, then represent
        # the external controller-run contract used by the real split-UID lane.
        self.contract["paths"]["grainRuntime"] = str(self.root / "bin/grainRuntime")
        self.rewrite(self.path, self.contract)
        op, request = self.prepared_legacy_repair()
        self.contract["paths"].pop("grainRuntime")
        self.rewrite(self.path, self.contract)
        pin = M.read(op.root / "attachment.json")
        pin["contract"] = self.contract
        del pin["files"]["grainRuntime"]
        del pin["sha256"]["grainRuntime"]
        self.rewrite(op.root / "attachment.json", pin)
        result = M.repair_prepared_bootstrap(Path(self.path), request)
        self.assertEqual(result["newName"], "oracle-bootstrap-app")

    def test_prepared_bootstrap_repair_initializes_only_explicit_minimal_foreground_allowance(self):
        op, request = self.prepared_legacy_repair()
        value = M.read(request)
        value["initializeForegroundTool"] = True
        self.rewrite(request, value)
        result = M.repair_prepared_bootstrap(Path(self.path), request)
        self.assertTrue(result["initializedForegroundTool"])
        self.assertEqual(M.read(op.controller_stage)["foregroundTool"], {"reserve": "1", "charge": "0"})
        self.assertNotIn("foregroundTool", M.read(op.root / "repair-prepared-bootstrap/before-controller.json"))
        self.assertEqual(M.repair_prepared_bootstrap(Path(self.path), request), result)

    def test_prepare_preserves_explicit_foreground_allowance(self):
        config = M.read(self.contract["paths"]["controllerConfig"])
        config["foregroundTool"] = {"reserve": "12", "charge": "4"}
        self.rewrite(self.contract["paths"]["controllerConfig"], config)
        op = M.Attachment(self.path, "prepare-config")
        op.delegate_observe = lambda *args: M.receipt(self.confirmed)
        op.prepare_config()
        self.assertEqual(M.read(op.controller_stage)["foregroundTool"], {"reserve": "12", "charge": "4"})

    def test_prepared_bootstrap_repair_refuses_later_phase_and_controller_journal(self):
        op, request = self.prepared_legacy_repair()
        before = op.controller_stage.read_bytes()
        later = op.root / "native-create-session"
        later.mkdir()
        with self.assertRaisesRegex(ValueError, "only the completed"):
            M.repair_prepared_bootstrap(Path(self.path), request)
        later.rmdir()
        evidence = M.read(request)["controllerEvidence"]
        exported = M.read(evidence)
        exported["files"]["journal.json"] = {"base64": "e30=", "sha256": M.hashlib.sha256(b"{}").hexdigest()}
        self.rewrite(evidence, exported)
        with self.assertRaisesRegex(ValueError, "never admitted"):
            M.repair_prepared_bootstrap(Path(self.path), request)
        self.assertEqual(op.controller_stage.read_bytes(), before)

    def test_prepared_bootstrap_repair_rejects_foreign_proof_or_changed_source_inputs(self):
        op, request = self.prepared_legacy_repair()
        status_path = M.read(request)["controllerStatus"]
        status = M.read(status_path)
        for key, value in (("stopped", False), ("store", "fedcba9876543210"), ("controllerConfigSha256", "0" * 64)):
            wrong = dict(status, **{key: value})
            self.rewrite(status_path, wrong)
            with self.assertRaisesRegex(ValueError, "stopped controller"):
                M.repair_prepared_bootstrap(Path(self.path), request)
        self.rewrite(status_path, status)
        Path(self.contract["paths"]["mini"]).write_bytes(b"changed binary")
        with self.assertRaisesRegex(ValueError, "repair input changed"):
            M.repair_prepared_bootstrap(Path(self.path), request)

    def test_prepared_bootstrap_repair_resumes_partial_publication_without_delegation(self):
        op, request = self.prepared_legacy_repair()
        replace = M.os.replace
        count = 0
        def interrupted(source, target):
            nonlocal count
            count += 1
            if count == 2: raise OSError("simulated interrupted publication")
            replace(source, target)
        with patch.object(M.os, "replace", side_effect=interrupted):
            with self.assertRaisesRegex(OSError, "interrupted publication"):
                M.repair_prepared_bootstrap(Path(self.path), request)
        with self.assertRaisesRegex(ValueError, "repair is incomplete"):
            M.Attachment(self.path, "issue-grant")
        with patch.object(M.subprocess, "run", side_effect=AssertionError("repair replayed delegate")):
            M.repair_prepared_bootstrap(Path(self.path), request)
        self.assertTrue((op.root / "repair-prepared-bootstrap/complete.json").is_file())

    def test_root_export_supports_private_controller_host_metadata(self):
        config = M.read(self.contract["paths"]["controllerConfig"])
        config["hostConfig"] = "/private/controller/host-config.json"
        self.rewrite(self.contract["paths"]["controllerConfig"], config)
        export = self.file("exported-host.json", M.read(self.config))
        self.contract["paths"]["controllerHostConfigExport"] = export
        self.rewrite(self.path, self.contract)
        op = M.Attachment(self.path, "prepare-config")
        self.assertEqual(M.read(op.root / "attachment.json")["files"]["controllerHostConfigExport"], export)
        self.rewrite(export, {"expectedSeed": "another-store"})
        with self.assertRaisesRegex(ValueError, "same Store"):
            M.Attachment(self.path, "issue-grant")

    def test_same_store_and_binary_pins_before_phase_side_effects(self):
        self.rewrite(self.config, {"expectedSeed": "other"})
        with self.assertRaisesRegex(ValueError, "same pinned Store"):
            M.Attachment(self.path, "prepare-config")
        self.assertFalse(Path(self.contract["paths"]["outputDir"]).exists())

    def test_phase_is_exclusive_and_input_drift_refuses(self):
        op = M.Attachment(self.path, "prepare-config")
        with self.assertRaises(FileExistsError):
            M.Attachment(self.path, "prepare-config")
        Path(self.contract["paths"]["mini"]).write_bytes(b"different")
        with self.assertRaisesRegex(ValueError, "inputs changed"):
            M.Attachment(self.path, "issue-grant")
        self.assertFalse((op.root / "native-issue-grant").exists())

    def test_existing_controller_update_requires_retained_config(self):
        op = M.Attachment(self.path, "prepare-config")
        config = M.read(self.contract["paths"]["controllerConfig"])
        config["commands"].append({"name": "unexpected"})
        self.rewrite(self.contract["paths"]["controllerConfig"], config)
        with self.assertRaisesRegex(ValueError, "outside retained"):
            M.Attachment(self.path, "issue-grant")
        self.assertFalse((op.root / "native-issue-grant").exists())

    def test_prepare_preserves_existing_tools_and_native_session_selectors(self):
        op = M.Attachment(self.path, "prepare-config")
        delegated = []
        def delegate(*args):
            delegated.append(args)
            return M.receipt(self.confirmed)
        op.delegate_observe = delegate
        result = M.read(op.prepare_config())
        config = M.read(op.controller_stage)
        self.assertEqual(config["commands"], [{"name": "keep-me"}])
        self.assertEqual(config["toolTask"]["registeredSharedApplications"][0], {"name": "other-app"})
        family = config["toolTask"]["allowedSessionFamilies"][0]
        self.assertEqual(family["participantSubject"], self.a["controller"]["subject"])
        self.assertEqual(family["namespace"]["sessionOwnerCapability"], self.caps["sessionOwner"])
        self.assertNotIn("sessionOwner", family["namespace"])
        self.assertEqual(config["foregroundTool"], {"reserve": "1", "charge": "0"})
        self.assertEqual(len(delegated), 6)
        self.assertEqual(delegated[-1][-1], self.a["controller"]["subject"])
        self.assertEqual(result["nextTool"]["arguments"]["application"], "oracle-bootstrap-app")
        self.assertEqual(M.read(self.contract["paths"]["controllerConfig"])["toolTask"]["registeredSharedApplications"], [{"name": "other-app"}])

    def test_bootstrap_reference_keeps_native_application_suffix_and_bound(self):
        self.contract["names"] = {"application": "weather-app"}
        self.rewrite(self.path, self.contract)
        op = M.Attachment(self.path, "prepare-config")
        self.assertEqual(op.bootstrap_name, "weather-bootstrap-app")
        self.assertTrue(op.bootstrap_name.endswith("-app"))
        self.contract["names"]["application"] = "x" * 60 + "-app"
        self.rewrite(self.path, self.contract)
        with self.assertRaisesRegex(ValueError, "native 64-byte"):
            M.Attachment(self.path, "prepare-config")

    def test_existing_name_collision_refuses_before_native_delegation(self):
        config = M.read(self.contract["paths"]["controllerConfig"])
        config["toolTask"]["registeredSharedApplications"].append({"name": "oracle-bootstrap-app"})
        self.rewrite(self.contract["paths"]["controllerConfig"], config)
        op = M.Attachment(self.path, "prepare-config")
        with patch.object(op, "delegate_observe") as delegated:
            with self.assertRaisesRegex(ValueError, "before delegation"):
                op.prepare_config()
            delegated.assert_not_called()

    def test_route_render_uses_pinned_served_operator_and_propagates_refusal(self):
        op = M.Attachment(self.path, "prepare-config")
        op.controller_stage.parent.mkdir(parents=True)
        M.write(op.controller_stage, {})
        grant = self.root / "grant"
        grant.mkdir()
        M.write(grant / "lookup-0001.outcome.json", {})
        M.write(op.root / "issued-grant.json", {"grantAttempt": str(grant)})
        layout = self.file("route-layout.json", {"controllerHome": "/home/controller",
            "listenerSocket": "/listener.sock", "reverseSocket": "/reverse.sock",
            "operatorSocket": "/operator.sock", "controllerUid": M.os.getuid() + 10000})
        seen = []
        def refused(label, argv):
            seen.append((label, argv))
            raise ValueError("served inspection refused")
        with patch.object(op, "validate_layout"), patch.object(op, "call", side_effect=refused):
            with self.assertRaisesRegex(ValueError, "served inspection refused"):
                op.prepare_route(ROOT, layout)
        self.assertEqual(len(seen), 1)  # no detached replay after refusal
        argv = seen[0][1]
        offset = argv.index("--served")
        self.assertEqual(argv[offset + 1:offset + 4], [op.mini, op.operator, M.sha(op.mini)])
        pins = M.read(op.calls / "operator-pins.json")
        self.assertEqual([(p["role"], p["index"]) for p in pins["payerPins"]], [("4", "0"), ("1", "0")])
        self.assertEqual([(p["role"], p["index"]) for p in pins["appSigners"]],
                         [("4", "0"), ("4", "1"), ("8", "0"), ("8", "1"), ("1", "0"),
                          ("9", "0"), ("9", "1"), ("9", "2"), ("9", "3")])
        for pin in pins["payerPins"]:
            self.assertEqual(pin["keyId"], self.a["dispatch"]["keyId"])
            self.assertEqual(pin["keyEpoch"], "77")
            self.assertNotIn("seedPath", pin)

    def test_layout_keeps_controller_and_dispatch_separate(self):
        op = M.Attachment(self.path, "prepare-config")
        config = M.read(self.contract["paths"]["controllerConfig"])
        layout = {"controllerHome": self.contract["paths"]["controllerHome"], "controllerUid": 1002,
                  "reverseSocket": "/reverse.sock", "operatorSocket": "/operator.sock", "operatorPeerUid": 1001}
        config["dispatchTask"].update(socketPath="/reverse.sock", hostUid=1001,
                                      operatorSocket="/operator.sock", operatorPeerUid=1001)
        with patch.object(M.os, "getuid", return_value=1001):
            op.validate_layout(layout, config)
            config["dispatchTask"]["hostUid"] = 1002
            with self.assertRaisesRegex(ValueError, "dispatch transport"):
                op.validate_layout(layout, config)
            layout["controllerUid"] = 1001
            with self.assertRaisesRegex(ValueError, "distinct non-root"):
                op.validate_layout(layout, config)

    def test_explicit_issuer_and_source_generation_drive_ticket(self):
        op = M.Attachment(self.path, "issue-grant")
        source = self.file("session-result.json", {"type": "tool-complete", "isError": False, "result": {"isError": False,
            "text": json.dumps({"type": "confirmed-mini-application-birth-v1", "route": "session",
                "bornResources": [{"target": self.a["session"]}, {"target": self.a["descriptor"]}]})}})
        def query(label, *args):
            output = op.calls / label
            output.mkdir()
            M.write(output / "view.json", {"cell": {"grain": {"generation": "93"}, "entries": [{"key": {"field": "2"}, "value": "4"}]}})
            return output
        op.query = query
        op.reserve_issuer_tool = lambda: None
        class PreviewReached(Exception): pass
        def call(label, args):
            self.assertEqual(label, "ticket-plan")
            self.assertIn(str(op.operator), [str(x) for x in args])
            raise PreviewReached()
        op.call = call
        with self.assertRaises(PreviewReached): op.issue_grant(source)
        request = M.read(op.calls / "ticket-request.json")
        self.assertEqual(request["spec"]["issuer"], "313")
        self.assertEqual(request["payer"], "314")
        self.assertEqual(request["tool"], self.contract["issuer"]["tool"])
        self.assertEqual(request["parent"], self.contract["issuer"]["parent"])
        participant = request["spec"]["ticket"]["participant"]
        self.assertEqual(participant["origin"]["generation"], "93")
        self.assertEqual(participant["origin"]["task"], self.a["controller"]["task"])
        self.assertEqual(participant["subject"], self.a["controller"]["subject"])
        self.assertFalse((op.calls / "grant-issue").exists())

    def test_source_signer_epoch_is_selected_not_hardcoded(self):
        op = M.Attachment(self.path, "issue-grant")
        slot = {"role": "4", "index": "0", "headerHex": "ab", "signing": {
            "decoded": True, "algorithm": "1", "keyId": self.a["controller"]["keyId"], "keyEpoch": "77"}}
        self.assertEqual(op.slot_signers([slot], "headerHex")[0]["keyEpoch"], "77")
        slot["signing"]["keyEpoch"] = "2"
        with self.assertRaises(ValueError): op.slot_signers([slot], "headerHex")
        slot["signing"]["keyId"] = "unknown"
        with self.assertRaises(ValueError): op.slot_signers([slot], "headerHex")

    def test_failed_native_call_keeps_command_and_never_repeats(self):
        op = M.Attachment(self.path, "issue-grant")
        with patch.object(M.subprocess, "run") as run:
            run.return_value.returncode = 7
            with self.assertRaisesRegex(RuntimeError, "retain attempt"):
                op.call("grant-submit", [op.mini, "agent-lifetime-grant-submit", "--attempt", op.calls / "grant-issue"])
            with self.assertRaises(FileExistsError):
                op.call("grant-submit", [op.mini, "agent-lifetime-grant-submit", "--attempt", op.calls / "grant-issue"])
            self.assertEqual(run.call_count, 1)
        self.assertEqual(M.read(op.calls / "grant-submit-exit.json")["returncode"], 7)
        (op.calls / "grant-issue").mkdir()
        status = M.Attachment(self.path, "status").status()
        self.assertEqual(status["phases"][0]["lookupCommands"], [[str(op.mini), "agent-lifetime-grant-lookup", "--attempt", str(op.calls / "grant-issue")]])

    def test_status_uses_original_attempts_when_live_inputs_are_missing_or_changed(self):
        op = M.Attachment(self.path, "issue-grant")
        (op.calls / "grant-issue").mkdir()
        Path(self.config).unlink()
        Path(self.contract["paths"]["controllerConfig"]).write_text("invalid live config")
        self.contract["paths"]["mini"] = "/different/mini"
        self.rewrite(self.path, self.contract)
        with patch.object(M.subprocess, "run") as native:
            status = M.Attachment(self.path, "status").status()
            native.assert_not_called()
        self.assertEqual(status["phases"][0]["lookupCommands"][0][0], str(op.mini))
        self.assertTrue({"contract", "hostConfig", "controllerConfig"}.issubset({d["input"] for d in status["pinDiagnostics"]}))
        self.assertFalse((op.root / "native-status").exists())

    def test_host_metadata_adds_target_without_overwriting_provider_or_other_targets(self):
        config = M.read(self.config)
        config["providerServices"] = [{"providerResourceId": 889, "tariff": {"public": "data"}}]
        self.rewrite(self.config, config)
        output = self.root / "new-host.json"
        M.render_host_config(self.config, self.contract["allocation"], output)
        result = M.read(output)
        self.assertEqual(result["providerServices"], config["providerServices"])
        target = result["agentLifetimeDispatchTargets"][0]
        self.assertEqual(target["legacy"]["parentTask"], int(self.a["controller"]["task"]))
        self.assertEqual(target["legacy"]["purseTask"], int(self.a["dispatch"]["task"]))
        self.assertEqual(M.controller_host_metadata(output), output.read_bytes())
        target["legacy"]["purseTask"] += 1
        self.rewrite(output, result)
        with self.assertRaisesRegex(ValueError, "conflicts"):
            M.render_host_config(output, self.contract["allocation"], self.root / "conflict.json")

    def test_legacy_adapter_uses_shared_operations_and_old_name(self):
        spec = importlib.util.spec_from_file_location("legacy_agent", ROOT / "deploy/oracle/acceptance/agent.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertEqual(module.Operator.issue_grant.__code__.co_filename, str(ROOT / "scripts/application-attachment.py"))
        run = self.root / "legacy"
        (run / "agent-lifetime").mkdir(parents=True)
        M.write(run / "agent-lifetime/allocation.json", self.alloc)
        (run / "world/evidence").mkdir(parents=True)
        M.write(run / "world/evidence/profile-result.json", {"profilePath": "/legacy/profile.json", "stateRoot": "/legacy/state"})
        op = module.Operator(run, "issue-grant")
        self.assertEqual(op.bootstrap_name, "oracle-bootstrap-app")
        self.assertEqual(op.grant_relative, Path("state/oracle-grant"))
        self.assertEqual(op.ticket_name, "agent-ticket.bin")
        self.assertEqual(op.issuer["subject"], "8")
        self.assertEqual(op.controller_stage, run / "agent-lifetime/controller-stage/controller.json")
        self.assertEqual(op.application["birthSource"], str(run / "world/evidence/a-app-author/source.json"))


if __name__ == "__main__":
    unittest.main()
