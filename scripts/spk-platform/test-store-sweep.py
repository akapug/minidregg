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
import socket
import uuid
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

    def test_retry_stage_only_archives_packages_in_the_selected_index(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            apps = [dict(appId=f'app{i}', packageId=f'{i:032x}', name=f'App {i}') for i in range(2)]
            for app in apps:
                sweep.record(out, 'a'*40, app, 'FAIL', 'install', 'native refusal', '/ev', 'standard-v1', 1, 2)
            index = out/'selected-index.json'
            index.write_text(json.dumps(dict(apps=[apps[1]])))
            subprocess.run([sys.executable, str(Path(__file__).with_name('store-sweep-data.py')),
                            'retry-stage', str(out), 'a'*40, 'install', str(index)], check=True)
            self.assertEqual([r['packageId'] for r in sweep.records(out, 'a'*40)], [apps[0]['packageId']])
            self.assertEqual(len(list((out/'records'/'history').glob('*/*.json'))), 1)

    def test_profile_uses_both_bounds(self):
        self.assertEqual(sweep.profile(256, 768, 256, 768), 'standard-v1')
        self.assertEqual(sweep.profile(257, 768, 256, 768), 'market-large-v1')
        self.assertEqual(sweep.profile(100, 769, 256, 768), 'market-large-v1')

    def test_profile_uses_native_segment_limit_without_judging_admission(self):
        here = Path(__file__).resolve().parent
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            host = root/'spk-host'
            host.write_text('''#!/bin/bash
if [[ $1 == import-limits ]]; then echo '256 768 10'; exit 0; fi
[[ $1 == qualify && $2 == --import-profile && $3 == standard-v1 ]] || exit 99
echo "$SWEEP_TEST_NATIVE_REFUSAL" >&2
[[ -z $SWEEP_TEST_NATIVE_REFUSAL ]]
''')
            host.chmod(0o755)
            timeout = root/'timeout'
            timeout.write_text('#!/bin/bash\nshift 2\nexec "$@"\n')
            timeout.chmod(0o755)
            cmd = ['bash', str(here/'store-sweep-profile.sh'), str(host), str(root/'package.spk'),
                   '100', '700', str(root/'native')]
            env = dict(os.environ, PATH=str(root)+os.pathsep+os.environ['PATH'])
            for refusal, expected in (
                ("spk-host: too many Cap'n Proto segments: 809 exceeds bound 512", 'market-large-v1'),
                ('spk-host: archive hash mismatch', 'standard-v1'),
                ('', 'standard-v1'),
            ):
                env['SWEEP_TEST_NATIVE_REFUSAL'] = refusal
                result = subprocess.run(cmd, env=env, capture_output=True, text=True, check=True)
                self.assertEqual(result.stdout.strip(), expected)
            env['SWEEP_TEST_NATIVE_REFUSAL'] = 'spk-host: scratch parent custody refused'
            result = subprocess.run(cmd, env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0, 'broken preflight custody is not a standard-profile result')

    def test_world_import_profile_keeps_broker_and_grain_consistent_before_apps(self):
        here = Path(__file__).resolve().parent
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            bins, grains, state = root/'bin', root/'grains', root/'state'
            for path in (bins, grains/'broker', state):
                path.mkdir(parents=True)
            profile = root/'host.json'
            profile.write_text(json.dumps(dict(stateRoot=str(state))))
            broker = grains/'broker/config.json'
            broker.write_text(json.dumps(dict(importProfile='standard-v1')))
            commands = root/'commands'
            (bins/'systemctl').write_text('''#!/bin/bash
echo "$*" >> "$SWEEP_TEST_COMMANDS"
if [[ $2 == start ]]; then
  jq -e '.importProfile == "market-large-v1"' "$SWEEP_TEST_PROFILE" >/dev/null &&
  jq -e '.importProfile == "market-large-v1"' "$SWEEP_TEST_BROKER" >/dev/null || exit 99
fi
''')
            (bins/'stat').write_text('#!/bin/bash\necho "$(id -u):600"\n')
            for path in bins.iterdir():
                path.chmod(0o755)
            with socket.socket(socket.AF_UNIX) as sock:
                sockpath = root/'broker.sock'
                sock.bind(str(sockpath))
                sock.listen()
                world = root/'WORLD.env'
                world.write_text(f'PROFILE={profile}\nGRAINS_ROOT={grains}\nSTORE=test\nBROKER_SOCKET={sockpath}\n')
                env = dict(os.environ, PATH=str(bins)+os.pathsep+os.environ['PATH'],
                           SWEEP_TEST_COMMANDS=str(commands), SWEEP_TEST_PROFILE=str(profile),
                           SWEEP_TEST_BROKER=str(broker))
                cmd = ['bash', str(here/'world-import-profile.sh'), str(world), 'market-large-v1']
                result = subprocess.run(cmd, env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(profile.read_text())['importProfile'], 'market-large-v1')
                self.assertEqual(json.loads(broker.read_text())['importProfile'], 'market-large-v1')
                self.assertEqual(commands.read_text().splitlines(),
                                 ['--user stop mini-spk-broker@test.service', '--user start mini-spk-broker@test.service'])
                (state/'apps/a6101').mkdir(parents=True)
                result = subprocess.run(cmd, env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 2)
                self.assertIn('world with no apps', result.stderr)
                self.assertEqual(len(commands.read_text().splitlines()), 2, 'used world must refuse before stopping anything')

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

    def test_world_down_accepts_valid_partial_broker_locator_only(self):
        here = Path(__file__).resolve().parent
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            driver, bins, run = root/'driver', root/'bin', root/'world'
            for path in (driver, bins, run/'broker-setup'):
                path.mkdir(parents=True)
            shutil.copy(here/'world-down.sh', driver/'world-down.sh')
            # No real service manager, sudo, filesystem cleanup, or residents in this fixture.
            for name in ('systemctl', 'journalctl', 'rm', 'find'):
                script = bins/name
                script.write_text('#!/bin/bash\ncase " $* " in *" is-active "*) exit 3;; esac\nexit 0\n')
                script.chmod(0o755)
            (bins/'sudo').write_text('#!/bin/bash\necho unexpected-sudo >&2\nexit 99\n')
            (bins/'sudo').chmod(0o755)
            (driver/'stop-residents.sh').write_text('#!/bin/bash\nexit 0\n')
            (driver/'stop-residents.sh').chmod(0o755)
            store = uuid.uuid4().hex[:16]
            grains = '/var/lib/mini-spk-worlds/' + store
            locator = dict(protocol='mini-spk-world-recovery-v1', store=store, grainsRoot=grains,
                           brokerSocket=grains+'/runtime-'+store+'/broker.sock',
                           helper='/usr/local/libexec/mini-spk-volume-helper-'+store)
            path = run/'broker-setup/recovery.json'
            path.write_text(json.dumps(locator))
            env = dict(os.environ, PATH=str(bins)+os.pathsep+os.environ['PATH'])
            cmd = ['bash', str(driver/'world-down.sh'), str(run)]
            result = subprocess.run(cmd, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('removal_assertions=0', result.stdout)
            locator['brokerSocket'] = '/another-world/broker.sock'
            path.write_text(json.dumps(locator))
            result = subprocess.run(cmd, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 2, 'mismatched locator must refuse before cleanup')


if __name__ == '__main__':
    unittest.main()
