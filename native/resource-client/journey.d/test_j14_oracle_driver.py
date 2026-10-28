"""Physical readiness regression; no native admission or external services."""
import importlib.util
from pathlib import Path
import socket
import tempfile
import threading
import time
import unittest

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

if __name__=='__main__':unittest.main()
