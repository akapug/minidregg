#!/usr/bin/env python3
"""Repair orchestration checks; fake native transport is not admission evidence."""
import copy
import base64
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("payer_successor", Path(__file__).with_name("application-payer-successor.py"))
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)


class PayerSuccessorTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.root = self.base / "attachment"
        self.root.mkdir(mode=0o700)
        self.calls = []
        self.pins = [{"role": role, "index": "0", "keyId": "3", "keyEpoch": "2", "publicKeyHex": "ab" * 32}
                     for role in ("4", "8", "1")]
        self.custody = {"payerPins": self.pins, "lineage": {"appResource": "91", "sessionResource": "92", "parentTask": "93"}, "grant": "original"}
        self.file("old/custody/resident-custody-v3.json", self.custody)
        self.file("old/pins.json", {"payerPins": self.pins, "hostUnit": None, "other": "unchanged"})
        self.old_request = {"name": "oracle-agent-v1", "custody": str(self.base / "old/custody/resident-custody-v3.json"), "socket": "/private/api.sock"}
        self.file("old/request.json", self.old_request)
        self.file("native/old.json", {"registration": self.old_request, "custodyHex": M.raw(self.base / "old/custody/resident-custody-v3.json").hex()})
        self.file("grant/call.bin", b"original grant")
        self.file("grant/lookup.json", {"confirmation": "replayed"})
        self.registration = {"layout": {"store": "abc", "controllerUid": 100071, "controllerHome": str(self.base / "controller")},
            "pins": str(self.base / "old/pins.json"), "sourceRoute": str(self.base / "old/custody"),
            "request": str(self.base / "old/request.json"), "grantAttempt": str(self.base / "grant"),
            "lookup": str(self.base / "grant/lookup.json"),
            "registration": {"name": "oracle-agent-v1", "registration": str(self.base / "native/old.json")}}
        self.file("attachment/registered-agent-route.json", self.registration)
        self.request = {"protocol": "mini-application-payer-successor-v1", "attachmentRoot": str(self.root),
            "correctedRepo": str(self.base / "newrepo"), "outputDir": str(self.root / "repair-payer-custody"),
            "successorName": "oracle-agent-v2", "inspectionMode": "detached"}
        for role, content in {"allocation": {"app": "91", "agents": [{"route": "controller"}]},
            "profile": {"stateRoot": str(self.base / "native")}, "host": b"host", "hostConfig": {}, "spkHost": b"spk",
            "controllerStatus": {"stopped": True, "store": "abc", "controllerUid": 100071},
            "controllerJournal": {"unresolvedExternal": [], "binding": {"config": {"task": "93"}, "configPath": str(self.base / "controller/controller.json")}},
            "stopReceipt": {"protocol": "mini-spk-grain-stop-v1", "app": "91", "generation": "2", "unit": "app-g2.service", "activeState": "inactive"}}.items():
            self.request[role] = str(self.file(role, content))
        self.file("newrepo/scripts/application-attachment.py", b"new helper")
        self.file("newrepo/deploy/oracle/acceptance/agent.py", b"new adapter")
        self.file("newrepo/scripts/spk-platform/prepare-lifetime-route.sh", b"new renderer")
        journal = M.raw(self.request["controllerJournal"])
        self.request["controllerEvidence"] = str(self.file("controllerEvidence", {"protocol": "mini-spk-controller-evidence-v1", "store": "abc",
            "files": {"journal.json": {"base64": base64.b64encode(journal).decode(), "sha256": M.digest(journal)}}}))
        self.input = self.file("request.json", self.request)
        self.status = {"protocol": "mini-spk-grain-status-v2", "app": "91", "runs": [
            {"generation": "2", "unit": "app-g2.service", "state": "stopped"}]}

    def file(self, name, value):
        path = self.base / name
        path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        M.write(path, value)
        return path

    def fake(self, args, stdout, **kwargs):
        args = list(map(str, args)); self.calls.append(args)
        if args[1:3] == ["grain", "status"]:
            stdout.write(M.encode(self.status))
        elif args[0] == "sh":
            routes = Path(args[8]); routes.mkdir(mode=0o700)
            M.write(routes / "resident-custody-v3.json", M.narrowed(self.custody))
        elif args[1:3] == ["grain", "agent-route"]:
            request = M.read(args[-1])
            target = self.base / "native/new.json"
            M.write(target, {"registration": request, "custodyHex": M.raw(request["custody"]).hex()})
            stdout.write(M.encode({"protocol": "mini-spk-grain-agent-route-registered-v1", "app": "91",
                "name": request["name"], "registration": str(target), "grantIssued": False, "activation": "next-resident-generation"}))
        else:
            self.fail(args)
        return type("Result", (), {"returncode": 0})()

    def repair(self):
        repair = M.Repair(self.input)
        self.addCleanup(os.close, repair.lock)
        return repair

    def test_only_exact_observation_slot_is_removed(self):
        expected = copy.deepcopy(self.custody); expected["payerPins"] = [self.pins[0], self.pins[2]]
        self.assertEqual(M.narrowed(self.custody), expected)
        for change in (lambda p: p.reverse(), lambda p: p[1].update(keyId="99"), lambda p: p[2].update(index="1")):
            wrong = copy.deepcopy(self.custody); change(wrong["payerPins"])
            with self.assertRaises(ValueError): M.narrowed(wrong)

    def test_native_successor_retains_original_grant_and_registry(self):
        before = M.raw(self.base / "native/old.json")
        with patch.object(M.subprocess, "run", side_effect=self.fake):
            repair = self.repair(); complete = M.read(repair.run())
            self.assertFalse(complete["grantChanged"])
            after = M.read(self.root / "registered-agent-route.json")
            self.assertEqual(after["grantAttempt"], self.registration["grantAttempt"])
            self.assertEqual(M.raw(self.base / "native/old.json"), before)
            self.assertEqual(M.read(after["request"])["replaces"], "oracle-agent-v1")
            self.assertEqual([p["role"] for p in M.read(Path(after["sourceRoute"]) / "resident-custody-v3.json")["payerPins"]], ["4", "1"])
            repair.run()
            self.assertEqual(sum(a[1:3] == ["grain", "agent-route"] for a in self.calls), 1)

    def test_live_or_newer_application_refused_before_registration(self):
        with patch.object(M.subprocess, "run", side_effect=self.fake):
            repair = self.repair()
            self.status["runs"][0]["state"] = "running"
            with self.assertRaisesRegex(ValueError, "not stopped"): repair.run()
            self.status["runs"][0].update(state="stopped", generation="4", unit="app-g4.service")
            with self.assertRaisesRegex(ValueError, "latest native"): repair.run()
        self.assertFalse(any(a[1:3] == ["grain", "agent-route"] for a in self.calls))

    def test_uncertain_registration_is_never_resubmitted(self):
        real = self.fake
        def interrupted(args, **kwargs):
            if list(map(str, args))[1:3] == ["grain", "agent-route"]:
                raise TimeoutError("native registration outcome unknown")
            return real(args, **kwargs)
        with patch.object(M.subprocess, "run", side_effect=interrupted):
            repair = self.repair()
            with self.assertRaises(TimeoutError): repair.run()
        with patch.object(M.subprocess, "run", side_effect=self.fake):
            with self.assertRaisesRegex(ValueError, "interrupted"): repair.run()
        self.assertEqual(M.read(self.root / "registered-agent-route.json"), self.registration)

    def test_partial_publication_resumes_exactly(self):
        publish = M.publish
        def crash(path, before, after):
            publish(path, before, after)
            raise RuntimeError("after CAS")
        with patch.object(M.subprocess, "run", side_effect=self.fake):
            repair = self.repair()
            with patch.object(M, "publish", side_effect=crash):
                with self.assertRaises(RuntimeError): repair.run()
            repair.run()
        self.assertEqual(sum(a[1:3] == ["grain", "agent-route"] for a in self.calls), 1)

    def test_generic_adoption_changes_only_two_sources_and_repo(self):
        old_helper = self.file("oldrepo/scripts/application-attachment.py", b"old helper")
        old_renderer = self.file("oldrepo/scripts/spk-platform/prepare-lifetime-route.sh", b"old renderer")
        immutable = self.file("immutable", b"native receipt")
        contract = {"paths": {"repo": str(self.base / "oldrepo")}, "application": "unchanged"}
        contract_path = self.file("contract.json", contract)
        pins = {"contract": contract, "files": {"orchestrator": str(old_helper), "routeRenderer": str(old_renderer), "native": str(immutable)}}
        pins["sha256"] = {k: M.digest(M.raw(p)) for k, p in pins["files"].items()}
        self.file("attachment/attachment.json", pins)
        self.request["contract"] = str(contract_path)
        self.input.write_bytes(M.encode(self.request))
        with patch.object(M.subprocess, "run", side_effect=self.fake): self.repair().run()
        updated = M.read(self.root / "attachment.json")
        self.assertEqual(updated["files"]["native"], pins["files"]["native"])
        self.assertEqual(updated["sha256"]["native"], pins["sha256"]["native"])
        self.assertEqual(updated["contract"]["application"], "unchanged")
        self.assertEqual(M.read(contract_path), updated["contract"])
        self.assertEqual(M.raw(old_helper), b"old helper")

    def test_pending_controller_and_changed_native_custody_refused(self):
        with self.assertRaises(ValueError):
            M.check_settled(M.read(self.request["controllerStatus"]), {"unresolvedExternal": [], "parentHold": {}}, self.registration)
        native = M.read(self.base / "native/old.json"); native["custodyHex"] = b"{}".hex()
        (self.base / "native/old.json").write_bytes(M.encode(native))
        with self.assertRaisesRegex(ValueError, "old native registration"): self.repair()

    def test_every_native_work_family_and_resident_queue_blocks_repair(self):
        status = M.read(self.request["controllerStatus"])
        journal = M.read(self.request["controllerJournal"])
        for field in ("birthPending", "birthOperation", "workspaceBirth", "residentDelivery", "residentCompletion", "promptWitness"):
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "unsettled custody"):
                M.check_settled(status, dict(journal, **{field: {}}), self.registration)
        journal["binding"]["config"]["toolTask"] = {"room": {"room": "lab"}}
        def exported(pending):
            files = {"journal.json": journal, "resident/resident.json": {"pending": None, "returnPending": False},
                     "resident/requests.json": {"selected": None, "maintenancePending": None, "pending": pending}}
            return {"protocol": "mini-spk-controller-evidence-v1", "store": "abc", "files": {
                k: {"base64": base64.b64encode(M.encode(v)).decode(), "sha256": M.digest(M.encode(v))} for k, v in files.items()}}
        M.check_settled(status, journal, self.registration, exported([]))
        with self.assertRaisesRegex(ValueError, "pending work"):
            M.check_settled(status, journal, self.registration, exported([{"ask": "not consumed"}]))
        wrong = exported([]); wrong["files"]["journal.json"]["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "digest differs"):
            M.check_settled(status, journal, self.registration, wrong)

    def test_retained_source_and_native_receipt_cannot_change_on_resume(self):
        repair = self.repair()
        (self.base / "host").write_bytes(b"another Host")
        os.close(repair.lock)
        # Remove its registered cleanup: this case deliberately releases before reentry.
        self._cleanups.pop()
        with self.assertRaisesRegex(ValueError, "successor input changed"):
            M.Repair(self.input)

    def test_mini_adoption_requires_exact_installed_upgrade_chain(self):
        old = self.file("old-mini", b"old image")
        new = self.file("new-mini", b"qualified new image")
        installed = self.file("controller-mini", b"qualified new image")
        old_sha, new_sha = M.digest(M.raw(old)), M.digest(M.raw(new))
        previous = {"contract": {"paths": {"mini": str(old)}}, "files": {"mini": str(old)}, "sha256": {"mini": old_sha}}
        receipt = {"store": "abc", "previousMiniSha256": old_sha, "miniSha256": new_sha,
                   "miniUpgrade": f"/var/lib/mini-spk-worlds/abc/controller/mini-upgrade-{new_sha}.json"}
        proof = self.file("upgrade.json", receipt)
        request = {"binary": str(new), "receipt": str(proof)}
        journal = {"binding": {"config": {"mini": str(installed)}}}
        result = M.adopt_mini(previous, request, journal, {"store": "abc"})
        self.assertEqual(result["contract"]["paths"]["mini"], str(new))
        self.assertEqual(result["sha256"]["mini"], new_sha)
        self.assertEqual(previous["sha256"]["mini"], old_sha)
        for key, value in (("store", "foreign"), ("previousMiniSha256", "0" * 64), ("miniSha256", "0" * 64)):
            proof.write_bytes(M.encode(dict(receipt, **{key: value})))
            with self.assertRaisesRegex(ValueError, "does not bind"):
                M.adopt_mini(previous, request, journal, {"store": "abc"})
        proof.write_bytes(M.encode(receipt)); installed.write_bytes(b"unexpected installed image")
        with self.assertRaisesRegex(ValueError, "does not bind"):
            M.adopt_mini(previous, request, journal, {"store": "abc"})


if __name__ == "__main__": unittest.main()
