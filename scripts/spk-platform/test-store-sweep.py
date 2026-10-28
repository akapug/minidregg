#!/usr/bin/env python3
"""Data-only sweep checks; no worlds, downloads or app-specific recipes."""
import importlib.util
import json
from pathlib import Path
import tempfile
import subprocess
import os
import sys
import threading
import shutil
import unittest

spec = importlib.util.spec_from_file_location('sweep', Path(__file__).with_name('store-sweep-data.py'))
sweep = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sweep)


class StoreSweep(unittest.TestCase):
    def test_batching_and_candidate_package_resume(self):
        apps = [dict(appId=f'app{i}', packageId=f'{i:032x}', name=f'App {i}') for i in range(16)]
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            self.assertEqual([len(b) for b in sweep.batches(apps, out, 'a'*40, 7)], [7, 7, 2])
            sweep.record(out, 'a'*40, apps[0], 'PASS', 'get', 'HTTP 200', '/evidence/first', 'standard-v1', 12, 24)
            sweep.record(out, 'a'*40, apps[1], 'FAIL', 'install', 'named\trefusal\nreason', '/evidence/second', 'standard-v1', 12, 24)
            self.assertEqual(sum(map(len, sweep.batches(apps, out, 'a'*40, 7))), 14)
            self.assertEqual(sum(map(len, sweep.batches(apps, out, 'b'*40, 7))), 16)
            apps[0]['packageId'] = 'f'*32
            self.assertEqual(sum(map(len, sweep.batches(apps, out, 'a'*40, 7))), 15)
            summary = json.loads((out/'qualification.json').read_text())
            self.assertEqual(summary['counts'], {'PASS': 1, 'FAIL': 1})
            self.assertEqual(summary['apps'][1]['stage'], 'install')
            self.assertEqual(len((out/'verdicts.tsv').read_text().splitlines()), 3)
            with self.assertRaises(ValueError):
                sweep.batches(apps, out, 'a'*40, 8)
            with self.assertRaises(ValueError):
                sweep.record(out, 'a'*40, apps[0], 'PASS', 'install', '', '/ev', '', 0, 0)
            self.assertEqual(sum(map(len, sweep.batches(apps, out, 'a'*40, 7, 'install'))), 16)
            sweep.retry_stage(out, 'a'*40, 'install')
            self.assertEqual(len(sweep.records(out, 'a'*40)), 1)
            self.assertEqual(len(list((out/'records'/'history').glob('*/*.json'))), 1)

    def test_dry_run_whole_index_and_bounded_first_batch(self):
        here = Path(__file__).resolve().parent
        index = here.parent.parent/'native/resource-client/tests/fixtures/sandstorm-index-2026-10-27.json'
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            candidate = root/('a'*40)
            (candidate/'bin').mkdir(parents=True)
            (candidate/'provenance.json').write_text(json.dumps({'source': {'commit': 'a'*40}}))
            cmd = ['bash', str(here/'store-sweep.sh'), '--candidate', str(candidate),
                   '--out', str(root/'out'), '--index', str(index), '--dry-run']
            result = subprocess.run(cmd, check=True, capture_output=True, text=True)
            self.assertIn('14 worlds;', result.stdout)
            plans = [json.loads(line) for line in (root/'out'/('a'*40)/'dry-plan.jsonl').read_text().splitlines()]
            self.assertEqual(sum(map(len, plans)), 98)
            self.assertTrue(all([a['letter'] for a in batch] == list('jklmnop') for batch in plans))
            result = subprocess.run(cmd + ['--max-worlds', '3'], check=True, capture_output=True, text=True)
            self.assertIn('3 worlds;', result.stdout)

    def test_profile_uses_both_bounds(self):
        self.assertEqual(sweep.profile(256, 768, 256, 768), 'standard-v1')
        self.assertEqual(sweep.profile(257, 768, 256, 768), 'market-large-v1')
        self.assertEqual(sweep.profile(100, 769, 256, 768), 'market-large-v1')

    def test_teardown_does_not_need_removed_grain_profile(self):
        here = Path(__file__).resolve().parent
        with tempfile.TemporaryDirectory() as tmp:
            run = Path(tmp)/'world'
            (run/'evidence').mkdir(parents=True)
            # Retained profile result, but the actual grain state was already removed.
            (run/'evidence'/'profile-result.json').write_text('{}')
            result = subprocess.run(['sh', str(here/'grain-journey.sh'), 'stop-services', str(run)],
                                    env=dict(os.environ, GRAINS_ROOT=str(run/'removed'),
                                             BROKER_SOCKET=str(run/'removed/broker.sock'), BIN=tmp),
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_recovery_retains_user_manager_environment_and_cleans_only_own_staging(self):
        here = Path(__file__).resolve().parent
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            driver = root/'driver'
            driver.mkdir()
            shutil.copy(here/'store-sweep-world.sh', driver/'store-sweep-world.sh')
            (driver/'world-down.sh').write_text('''#!/bin/bash
test "$XDG_RUNTIME_DIR" = "/run/user/$(id -u)" || exit 1
test "$DBUS_SESSION_BUS_ADDRESS" = "unix:path=$XDG_RUNTIME_DIR/bus" || exit 1
echo manager-environment-ok
''')
            (driver/'stop-residents.sh').write_text('exit 0\n')
            stage = root/'staging'/'b.recover'
            (stage/'w').mkdir(parents=True)
            (stage/'w'/'WORLD.env').touch()
            out = root/'out'
            (stage/'sweep.json').write_text(json.dumps(dict(out=str(out), candidate='a'*40)))
            env = {k: v for k, v in os.environ.items() if k not in ('XDG_RUNTIME_DIR', 'DBUS_SESSION_BUS_ADDRESS')}
            cmd = ['bash', str(driver/'store-sweep-world.sh'), str(root/('a'*40)),
                   str(out), str(stage.parent), str(stage), '--recover']
            result = subprocess.run(cmd, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(stage.exists())
            self.assertIn('manager-environment-ok', (out/'evidence/b.recover/world-down.log').read_text())
            (stage/'w').mkdir(parents=True)
            (stage/'w'/'WORLD.env').touch()
            (stage/'sweep.json').write_text(json.dumps(dict(out=str(out), candidate='a'*40)))
            counter = root/'cleanup-attempts'
            env['SWEEP_TEST_DOWN_ATTEMPTS'] = str(counter)
            (driver/'world-down.sh').write_text('printf "attempt\\n" >> "$SWEEP_TEST_DOWN_ATTEMPTS"\nexit 1\n')
            result = subprocess.run(cmd, env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertTrue(stage.exists(), 'failed cleanup must retain staging')
            self.assertEqual(counter.read_text().splitlines(), ['attempt'], 'EXIT must not repeat a failed teardown')
            (stage/'sweep.json').write_text(json.dumps(dict(out='another-output', candidate='a'*40)))
            result = subprocess.run(cmd, env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertTrue(stage.exists(), 'never remove another run staging')

    @unittest.skipUnless(sys.platform == 'linux', 'resident PID custody uses /proc')
    def test_resident_cleanup_requires_this_world_in_recorded_pid_command(self):
        here = Path(__file__).resolve().parent
        with tempfile.TemporaryDirectory() as tmp:
            run = Path(tmp)/'world'
            (run/'a').mkdir(parents=True)
            for own_world in (False, True):
                arg = str(run/'settings') if own_world else str(Path(tmp)/'another-world/settings')
                proc = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)',
                                         'consent-resident', arg], stdout=subprocess.DEVNULL)
                (run/'a'/'resident.pid').write_text(str(proc.pid))
                # Reap while stop-residents waits for disappearance from /proc.
                reaper = threading.Thread(target=proc.wait)
                reaper.start()
                try:
                    result = subprocess.run(['bash', str(here/'stop-residents.sh'), str(run)],
                                            capture_output=True, text=True)
                    if own_world:
                        self.assertEqual(result.returncode, 0, result.stderr)
                        self.assertIsNotNone(proc.poll())
                    else:
                        self.assertNotEqual(result.returncode, 0)
                        self.assertIn('outside this world', result.stderr)
                        self.assertIsNone(proc.poll(), 'a different world must survive')
                finally:
                    if proc.poll() is None:
                        proc.terminate()
                    reaper.join()


if __name__ == '__main__':
    unittest.main()
