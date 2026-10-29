#!/usr/bin/env python3
import importlib.util
import io
from pathlib import Path
import socket
import subprocess
import sys
import tarfile
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("archive_evidence", Path(__file__).with_name("archive-world-evidence.py"))
archiver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(archiver)


class ArchiveEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.world, self.grains, self.store = self.root / "world", self.root / "grains", "0123456789abcdef"

    def write(self, path, body=b"evidence"):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(body)

    def test_only_custody_journals_and_regular_driver_evidence_are_archived(self):
        app = self.grains / self.store / "host" / "apps" / "7101"
        self.write(app / "g2" / "stop-claim" / "op26-frame.bin", b"exact reply")
        self.write(app / "custody" / "management.json")
        self.write(app / "install" / "begin.bin")
        self.write(app / "volume" / "op26-frame.bin", b"app file, not evidence")
        self.write(app / "g2" / "volumes" / "op26-frame.bin", b"also excluded")
        self.write(self.grains / "volumes" / "op26-frame.bin")
        self.write(self.grains / self.store / "host" / "packages" / "op26-frame.bin")
        self.write(self.world / "w" / "evidence" / "stop-a.stderr")
        self.write(self.world / "w" / "evidence" / "cache" / "op26-frame.bin")
        self.write(self.world / "w" / "sock" / "operator.pid")
        self.write(self.world / "w" / "sock" / "operator" / "cache.json")
        (app / "g2" / "linked-volume").symlink_to(app / "volume", target_is_directory=True)
        endpoint = self.world / "w" / "sock" / "driver.log"
        with socket.socket(socket.AF_UNIX) as sock:
            sock.bind(str(endpoint))
            output = io.BytesIO()
            count, size = archiver.archive(self.world, self.grains, self.store, output)
        with tarfile.open(fileobj=io.BytesIO(output.getvalue())) as tar:
            self.assertEqual(set(tar.getnames()), {
                "native/apps/7101/g2/stop-claim/op26-frame.bin",
                "native/apps/7101/custody/management.json", "native/apps/7101/install/begin.bin",
                "driver/w/evidence/stop-a.stderr", "driver/w/sock/operator.pid"})
            self.assertEqual(tar.extractfile("native/apps/7101/g2/stop-claim/op26-frame.bin").read(), b"exact reply")
        self.assertEqual(count, 5)
        self.assertLess(size, 100)

    def test_aggregate_and_count_bounds_refuse_before_writing_archive(self):
        self.write(self.world / "w" / "evidence" / "a", b"abc")
        self.write(self.world / "w" / "evidence" / "b", b"def")
        for limits in ({"max_files": 1}, {"max_bytes": 5}):
            output = io.BytesIO()
            with self.assertRaisesRegex(ValueError, "bound exceeded"):
                archiver.archive(self.world, self.grains, self.store, output, **limits)
            self.assertEqual(output.getvalue(), b"")

    def test_symlinked_custody_root_is_refused(self):
        target = self.root / "volume"
        target.mkdir()
        apps = self.grains / self.store / "host" / "apps"
        apps.parent.mkdir(parents=True)
        apps.symlink_to(target, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "symlink refused"):
            archiver.archive(self.world, self.grains, self.store, io.BytesIO())

    def test_failed_archive_prevents_following_cleanup(self):
        path = self.world / "w" / "evidence" / "too-large.bin"
        self.write(path)
        with path.open("r+b") as stream:
            stream.truncate(archiver.MAX_FILE_BYTES + 1)  # sparse, no large allocation
        cleanup = self.root / "cleanup-was-called"
        # The own runner's archive-before-down guard: destructive command only
        # follows successful completion of the real archive subprocess.
        result = subprocess.run(["bash", "-c", 'set -e; "$1" "$2" "$3" "$4" "$5" > "$6"; touch "$7"',
            "fixture", sys.executable, str(Path(archiver.__file__)), str(self.world),
            str(self.grains), self.store, str(self.root / "archive.tar"), str(cleanup)], capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"bound exceeded", result.stderr)
        self.assertFalse(cleanup.exists())


if __name__ == "__main__":
    unittest.main()
