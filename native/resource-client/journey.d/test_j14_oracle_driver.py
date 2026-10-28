"""Physical readiness regression; no native admission or external services."""
import importlib.util
from pathlib import Path
import socket
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('j14_oracle_driver',Path(__file__).with_name('j14-oracle.py'))
driver=importlib.util.module_from_spec(spec);spec.loader.exec_module(driver)

class ReadinessTests(unittest.TestCase):
    def test_retained_socket_inode_is_not_a_ready_listener(self):
        with tempfile.TemporaryDirectory(prefix='j14-ready-',dir='/tmp') as root:
            path=Path(root)/'listener.sock'
            stale=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM);stale.bind(str(path));stale.close()
            ready=threading.Event()
            def listener():
                time.sleep(.15)
                path.unlink()
                with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as server:
                    server.bind(str(path));server.listen();ready.set()
                    server.settimeout(3)
                    connection,_=server.accept();connection.close()
            worker=threading.Thread(target=listener,daemon=True);worker.start()
            driver.Journey.__new__(driver.Journey).wait_socket(path)
            self.assertTrue(ready.is_set(),'inode existence must not report readiness')
            worker.join(timeout=4);self.assertFalse(worker.is_alive())

class CheckpointTests(unittest.TestCase):
    def test_checkpoint_restores_coordinates_but_refuses_changed_native_inputs(self):
        with tempfile.TemporaryDirectory(prefix='j14-checkpoint-',dir='/tmp') as temp:
            root=Path(temp)/'oracle';root.mkdir(mode=0o700);(root/'commands').mkdir()
            binary=root/'native';binary.write_bytes(b'pinned test executable')
            (root/'spk-host').write_bytes(b'pinned application host')
            config=root/'host.json';config.write_text('{}')
            j=driver.Journey.__new__(driver.Journey)
            j.root=root;j.logs=root/'commands';j.bins=root;j.installer=driver.REPO/'deploy/spk-host/install-user-world'
            j.mini=j.host=j.runtime=j.provider=str(binary)
            j.counter=7;j.daemons=[];j.processes=[];j.world_pid=123
            j.c={'root':str(root),'repo':str(driver.REPO),'hostConfig':str(config)}
            checkpoint=j.checkpoint('prepare_application');checkpoint.chmod(0o600)
            retained=driver.read(checkpoint)
            self.assertNotIn('processes',retained['state']);self.assertNotIn('world_pid',retained['state'])
            with patch.dict(driver.os.environ,{'JOURNEY_STEP_DIR':temp}):
                resumed=driver.Journey.from_checkpoint(checkpoint)
                self.assertEqual(resumed.resume_phase,'prepare_application')
                self.assertEqual(resumed.counter,7);self.assertEqual(resumed.processes,[])
                binary.write_bytes(b'changed executable')
                with self.assertRaisesRegex(ValueError,'input changed'):
                    driver.Journey.from_checkpoint(checkpoint)

if __name__=='__main__':unittest.main()
