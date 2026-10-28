"""Composed scenario keeps going: one red phase blocks only its dependents.

The phases' native work is replaced by recorders; what is under test is the
scheduler (_run), the per-phase ledgers, the gate verdict and the preflight.
"""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("composed_scenario", HERE / "composed-scenario.py")
cs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cs)


def world(root):
    members = {}
    for index, name in enumerate(["ember", "member-1", "member-2", "member-3"]):
        members[name] = {"subject": str(100 + index), "workspace": str(root / name), "home": str(root / name),
                         "sshKeyFile": str(root / (name + ".key")), "entry": "sponsor" if index == 0 else None}
    value = {"type": "mini-world-identity-v1", "members": members, "unitUser": "lanes",
             "ssh": {"host": "127.0.0.1", "port": 2222, "knownHosts": str(root / "known")},
             "restart": {"argv": [str(root / "restart.sh")]}}
    path = root / "WORLD-IDENTITY.json"
    path.write_text(json.dumps(value))
    return path


class KeepGoing(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        os.chmod(self.root, 0o700)
        self.world = world(self.root)
        self.binding = self.root / "resident-binding.json"
        self.binding.write_text("{}")
        self.spec = cs.generate(str(self.world), str(self.root / "state"), 4, "jd3", residents=str(self.binding))
        # An app phase bound by a direct input (no world-derived selection to check).
        self.spec["apps"] = {"sheet": {"input": str(self.root / "attach.json")}}
        self.spec["connector"] = {"input": str(self.root / "provision.json"),
                                  "journeyInput": str(self.root / "journey.json")}
        self.ran = []

    def tearDown(self):
        self.tmp.cleanup()

    def run_with(self, failing, reds=None):
        test = self

        def phase(name):
            def body(self, *args):
                test.ran.append(name)
                # Each phase's ledger is its own: a step left pending here
                # must not fence any later phase.
                self.ledger.step(name + ":work", lambda: (_ for _ in ()).throw(RuntimeError(name + " refused: clause X"))
                                 if name in failing else None, str(self.root / "evidence"), keep=True,
                                 reentrant=True)
            return body

        def generic(self, name):
            return phase(name)(self)

        def restart(self, prefix="restart"):
            return phase(prefix)(self)

        with patch.object(cs.Scenario, "rooms", phase("rooms")), patch.object(cs.Scenario, "churn", phase("churn")), \
                patch.object(cs.Scenario, "documents", phase("documents")), patch.object(cs.Scenario, "generic", generic), \
                patch.object(cs.Scenario, "world_restart", restart), \
                patch.object(cs, "preflight", lambda spec, p, passed=(): dict(reds or {})), \
                patch.object(cs, "readiness", lambda spec, p: {ph: "ready" for ph in p["phases"]}):
            return cs.Scenario(self.spec, str(self.root / "spec.json")).run()

    def test_red_apps_blocks_only_its_chain(self):
        report = self.run_with({"apps"})
        phases = report["phases"]
        self.assertEqual([phases[p] for p in ("rooms", "churn", "documents")], ["pass"] * 3)
        self.assertTrue(phases["apps"].startswith("fail: apps refused: clause X"), phases["apps"])
        self.assertTrue(phases["connector"].startswith("blocked: prerequisite apps"))
        self.assertTrue(phases["residents"].startswith("blocked: prerequisite connector"))
        self.assertTrue(phases["restart"].startswith("blocked: prerequisite residents"))
        # The Store restart does not depend on the app chain: it ran.
        self.assertEqual(phases["store-restart"], "pass")
        self.assertIn("store-restart", self.ran)
        self.assertEqual(set(report["pending"]), {"apps"})

    def test_red_early_phase_still_runs_independent_later_phases(self):
        report = self.run_with({"churn"})
        phases = report["phases"]
        self.assertTrue(phases["churn"].startswith("fail:"))
        for later in ("documents", "apps", "connector", "residents", "restart", "store-restart"):
            self.assertEqual(phases[later], "pass", later)

    def test_resume_reenters_only_the_red_phase(self):
        self.run_with({"apps"})
        self.ran.clear()
        report = self.run_with(set())
        self.assertEqual(self.ran, ["apps", "connector", "residents", "restart"])
        self.assertTrue(all(v == "pass" for v in report["phases"].values()), report["phases"])

    def test_preflight_red_fails_phase_without_running_it(self):
        report = self.run_with(set(), reds={"connector": "selection names no connector"})
        self.assertEqual(report["phases"]["connector"], "fail: preflight: selection names no connector")
        self.assertNotIn("connector", self.ran)
        self.assertTrue(report["phases"]["residents"].startswith("blocked: prerequisite connector"))
        self.assertEqual(report["phases"]["store-restart"], "pass")

    def test_gate_names_every_red(self):
        test = self
        with patch.object(cs.Scenario, "run", lambda self: {"phases": {**{p: "pass" for p in cs.PHASES},
                                                                       "apps": "fail: x", "connector": "blocked: y"},
                                                            "failed": [], "pending": {}, "state": str(test.root)}):
            spec_path = self.root / "spec.json"
            spec_path.write_text(json.dumps(self.spec))
            result = cs.gate(self.spec, str(spec_path), str(self.root / "gate.json"))
        self.assertEqual(result["verdict"], "FAIL")
        self.assertEqual(result["reasons"], ["apps: fail: x", "connector: blocked: y"])


class FailureLine(unittest.TestCase):
    def test_follows_the_retained_native_stderr(self):
        with tempfile.TemporaryDirectory() as tmp:
            inner = Path(tmp) / "117-command.stderr"
            inner.write_text("\nmini: share issue outcome did not confirm\n")
            line = cs.failure_line(f"noise\nsame-Store app: command failed; retained {inner}\n")
            self.assertEqual(line, f"same-Store app: command failed; retained {inner} <- mini: share issue outcome did not confirm")
            self.assertEqual(cs.failure_line(""), "no stderr")


if __name__ == "__main__":
    unittest.main()
