"""Exercise the real intake helper up to its systemd boundary, without starting units."""
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

HELPER = Path(__file__).resolve().parents[3] / "deploy/spk-host/spk-ingest"


@unittest.skipUnless(sys.platform == "linux" and os.geteuid() != 0,
                     "Linux operator custody and GNU tools required")
class IngestProfiles(unittest.TestCase):
    def exercise(self, profile=None, size=3):
        with tempfile.TemporaryDirectory() as raw:
            work = Path(raw)
            root = work / "0123456789abcdef/spk"
            (root / "inbox").mkdir(parents=True, mode=0o700)
            (root / "packages").mkdir(mode=0o755)
            package = root / "inbox/package.spk"
            with package.open("wb") as out:
                out.truncate(size)
            package.chmod(0o600)
            host = work / "host"
            host.write_text("#!/bin/sh\nexit 98\n")
            host.chmod(0o700)
            marker = work / "args"
            # Retain exactly what the real helper would ask the service manager
            # to run. Exit before any actual host process or image publication.
            unit = work / "systemd-run"
            unit.write_text('#!/bin/bash\nprintf "%s\\0" "$@" > "$UNIT_ARGS"\nexit 99\n')
            unit.chmod(0o700)
            args = ["bash", str(HELPER), "--root", str(root)]
            if profile is not None:
                args += ["--import-profile", profile]
            args += [str(host), hashlib.sha256(host.read_bytes()).hexdigest(),
                     str(package), "64010"]
            result = subprocess.run(args, capture_output=True, text=True, timeout=10,
                                    env=dict(os.environ, UNIT_ARGS=str(marker),
                                             PATH=str(work) + os.pathsep + os.environ["PATH"]))
            unit_args = marker.read_bytes().split(b"\0")[:-1] if marker.exists() else []
            return result, [value.decode() for value in unit_args]

    def test_standard_budget_and_exact_host_arguments(self):
        result, args = self.exercise()
        self.assertEqual(result.returncode, 99, result.stderr)
        self.assertIn("RuntimeMaxSec=120", args)
        self.assertIn("LimitFSIZE=805306368", args)
        host_args = args[args.index("--") + 1:]
        self.assertEqual(host_args[1:4], ["materialize", "--import-profile", "standard-v1"])
        self.assertEqual(host_args[-1], "64010")

    def test_operator_budget_is_explicit_and_memory_stays_bounded(self):
        result, args = self.exercise("operator-appliance-v1")
        self.assertEqual(result.returncode, 99, result.stderr)
        self.assertIn("RuntimeMaxSec=1800", args)
        self.assertIn("LimitFSIZE=21474836480", args)
        self.assertIn("MemoryMax=2G", args)
        self.assertIn("operator-appliance-v1", args)

    def test_unknown_profile_never_reaches_unit(self):
        result, args = self.exercise("unlimited")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(args, [])

    def test_standard_raw_cap_refuses_sparse_oversize_before_hash_or_unit(self):
        result, args = self.exercise(size=256 * 1024 * 1024 + 1)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(args, [])


if __name__ == "__main__":
    unittest.main()
