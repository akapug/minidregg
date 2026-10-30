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
            # The Host answers `import-limits` as spk-host does (spk-package-stream Limits):
            # raw and decoded bounds, then 60 s + 3 s per raw MiB up to the profile's cap.
            host.write_text("#!/bin/sh\n[ \"$1\" = import-limits ] || exit 98\n"
                            "mib=$(( ($3 + 1048575) / 1048576 )); s=$((60 + 3 * mib))\n"
                            "case $2 in standard-v1) r=268435456 d=805306368 c=900;;"
                            " market-large-v1) r=536870912 d=2147483648 c=1800;;"
                            " operator-appliance-v1) r=8589934592 d=21474836480 c=1800;; *) exit 2;; esac\n"
                            "[ $s -le $c ] || s=$c; echo \"$r $d $s\"\n")
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
        self.assertIn("RuntimeMaxSec=63", args)
        self.assertIn("LimitFSIZE=805306368", args)
        host_args = args[args.index("--") + 1:]
        self.assertEqual(host_args[1:4], ["materialize", "--import-profile", "standard-v1"])
        self.assertEqual(host_args[-1], "64010")

    def test_operator_budget_is_explicit_and_memory_stays_bounded(self):
        result, args = self.exercise("operator-appliance-v1")
        self.assertEqual(result.returncode, 99, result.stderr)
        self.assertIn("RuntimeMaxSec=63", args)
        self.assertIn("LimitFSIZE=21474836480", args)
        self.assertIn("MemoryMax=2G", args)
        self.assertIn("operator-appliance-v1", args)

    def test_wall_clock_scales_with_the_package(self):
        result, args = self.exercise(size=75 * 1024 * 1024)
        self.assertEqual(result.returncode, 99, result.stderr)
        self.assertIn("RuntimeMaxSec=285", args)

    def test_market_large_raises_only_the_byte_bounds(self):
        result, args = self.exercise("market-large-v1", size=300 * 1024 * 1024)
        self.assertEqual(result.returncode, 99, result.stderr)
        self.assertIn("LimitFSIZE=2147483648", args)
        self.assertIn("MemoryMax=2G", args)
        self.assertIn("RuntimeMaxSec=960", args)

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
