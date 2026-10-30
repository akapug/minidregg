"""Run the real launcher through its manager preflight without launching a worker."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

class LauncherPreflightTests(unittest.TestCase):
    def test_unavailable_manager_is_not_reported_as_existing_worker(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);launcher=root/'launcher';launcher.mkdir()
            shutil.copy2(Path(__file__).with_name('bwrap'),launcher/'bwrap')
            gate=launcher/'launch-gate';gate.write_text('#!/bin/sh\nprintf "mini-grain-launch-gate-v1\\n"\n');gate.chmod(0o700)
            commands=root/'bin';commands.mkdir();systemctl=commands/'systemctl'
            workspace=root/'workspace';workspace.mkdir();runtime=root/'runtime';runtime.mkdir()
            state=root/'state';state.mkdir()
            for name in ('key','task.json','host.json'):(root/name).write_text('private')
            env={**os.environ,'PATH':str(commands)+':/usr/bin:/bin','MINI_GRAIN_UNIT':'mini-grain-t10-o20',
                 'MINI_GRAIN_STATE_DIR':str(state),'MINI_GRAIN_CUSTODY_KEY':str(root/'key'),
                 'MINI_GRAIN_TASK_CONFIG':str(root/'task.json'),'MINI_GRAIN_HOST_CONFIG':str(root/'host.json')}
            args=[str(launcher/'bwrap'),'--workspace',str(workspace),'--runtime-root',str(runtime),'--network','none','--','/agent/hermes-acp']
            for body,code,message in [('echo "bus permission denied" >&2; exit 1',69,'worker manager observation failed'),
                                      ('echo loaded',73,'unit already exists'),('exit 0',73,'unrecognized state')]:
                systemctl.write_text('#!/bin/sh\n'+body+'\n');systemctl.chmod(0o700)
                result=subprocess.run(args,env=env,text=True,capture_output=True)
                self.assertEqual(result.returncode,code,result.stderr)
                self.assertIn(message,result.stderr)
                if code==69:
                    self.assertIn('bus permission denied',result.stderr)
                    self.assertNotIn('unit already exists',result.stderr)

if __name__=='__main__':unittest.main()
