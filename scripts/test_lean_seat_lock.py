"""Runs scripts/test-lean-seat-lock.sh (the seated-Lean allocation lock regression) under unittest."""
import pathlib
import subprocess
import unittest


class LeanSeatLock(unittest.TestCase):
    def test_lock_script(self):
        script = pathlib.Path(__file__).resolve().parent / "test-lean-seat-lock.sh"
        done = subprocess.run(["bash", str(script)], capture_output=True, text=True, timeout=300)
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)


if __name__ == "__main__":
    unittest.main()
