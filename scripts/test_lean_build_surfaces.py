import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("surfaces", Path(__file__).with_name("lean-build-surfaces.py"))
surfaces = importlib.util.module_from_spec(spec)
spec.loader.exec_module(surfaces)

class BuildSurfaces(unittest.TestCase):
    def fixture(self, root):
        subprocess.run(["git", "init", "-q", str(root)], check=True)
        (root / "lakefile.toml").write_text("".join('[[lean_lib]]\nname = "' + n + '"\n' for n in ["Minidregg", *surfaces.GROUPS, "ResearchWip"]))
        (root / "Minidregg.lean").write_text("")
        for roots in surfaces.GROUPS.values():
            for name in roots:
                p = root / (name.replace(".", "/") + ".lean")
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text("namespace Fixture\nend Fixture\n")
        # The tests author Compiler modules; no qualification group roots live
        # under Compiler/ any more, so the fixture must create the directory.
        (root / "Compiler").mkdir(exist_ok=True)
        (root / "docs/construction").mkdir(parents=True)
        (root / "docs/construction/source-intake-20261003.json").write_text('{"files": []}')
        (root / "protocol").mkdir()
        subprocess.run(["git", "add", "."], cwd=root, check=True)

    def test_authored_modules_and_programs_get_distinct_targets(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t); self.fixture(root)
            (root / "Compiler/Unjoined.lean").write_text("def pending : Nat := 0\n")
            (root / "Host").mkdir()
            (root / "Host/Standalone.lean").write_text("def main : IO Unit := pure ()\n")
            data = surfaces.build(root)
            self.assertIn("Host.Standalone", data["programRoots"])
            self.assertIn("import Compiler.Unjoined", (root / "ResearchWip.lean").read_text())
            self.assertNotIn("Host.Standalone", (root / "ResearchWip.lean").read_text())
            self.assertNotIn("compilerPass", data)

    def test_missing_qualification_root_refuses_generation(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t); self.fixture(root)
            name = next(iter(surfaces.GROUPS.values()))[0]
            (root / (name.replace(".", "/") + ".lean")).unlink()
            with self.assertRaisesRegex(ValueError, "Missing qualification"):
                surfaces.build(root)

    def test_check_refuses_untracked_or_stale_emitted_targets_and_ignores_edits(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t); self.fixture(root)
            script = str(Path(__file__).with_name("lean-build-surfaces.py"))
            check = lambda: subprocess.run(["python3", script, "check", "--root", str(root)], capture_output=True, text=True)
            subprocess.run(["python3", script, "generate", "--root", str(root)], check=True, capture_output=True)
            # the emitted targets exist but git does not track them: red by name
            run = check()
            self.assertNotEqual(run.returncode, 0); self.assertIn("not tracked", run.stdout)
            subprocess.run(["git", "add", *surfaces.EMITTED], cwd=root, check=True)
            self.assertEqual(check().returncode, 0)
            # an ordinary source edit is no event (the old pin called it "source drift")
            (root / "Minidregg.lean").write_text("-- changed\n")
            self.assertEqual(check().returncode, 0)
            # a new unrooted module makes the emitted ResearchWip stale: red until regenerated
            (root / "Compiler/New.lean").write_text("def newSource : Nat := 0\n")
            run = check()
            self.assertNotEqual(run.returncode, 0); self.assertIn("ResearchWip.lean is stale", run.stdout)
            self.assertFalse((root / "protocol/lean-build-surfaces.json").exists())

if __name__ == "__main__":
    unittest.main()
