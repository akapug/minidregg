"""Physical relay regression with a toy provider, not Lean admission evidence.

Linux root only: set MINI_CONSENT_TEST_BINARY to the exact built mini binary.
Creates a disposable second-UID socket under a temporary directory, no accounts.
"""
import hashlib
import os
import pwd
import grp
from pathlib import Path
import socket
import struct
import subprocess
import sys
import tempfile
import time
import unittest

PROVIDER = r'''
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static int rd(void *p,size_t n){return fread(p,1,n,stdin)==n;}
static void answer(unsigned char op,const char *s){uint32_t n=1+(uint32_t)strlen(s);fwrite(&n,4,1,stdout);fputc(op,stdout);fwrite(s,1,n-1,stdout);fflush(stdout);}
int main(void){int admitted=0; uint32_t n; while(rd(&n,4)){if(!n||n>1000000)return 1;unsigned char *p=malloc(n);if(!p||!rd(p,n))return 1;
 switch(p[0]) {case 228: answer(228,"");break; case 233: answer(233,"");break;
 case 229: if(admitted)answer(229,"frontier");else answer(255,"no admitted prefix");break;
 case 226: answer(226,"possession");break; case 220: admitted=1;answer(220,"ok");break;
 case 221: admitted=1;answer(255,"refused");break;
 default: answer(255,"unsupported");break;} free(p);}return 0;}
'''
TAG = b'MINI-CONTROLLER-CONSENT/v1\0'


def framed(payload):
    return struct.pack('<I', len(payload)) + payload


def readframe(sock):
    def exact(n):
        out = b''
        while len(out) < n:
            chunk = sock.recv(n - len(out))
            if not chunk:
                raise EOFError('short frame')
            out += chunk
        return out
    size, = struct.unpack('<I', exact(4))
    if not 0 < size <= 12_102_760:
        raise ValueError('bad frame')
    return exact(size)


class ProxyAdversary(unittest.TestCase):
    def setUp(self):
        binary = os.environ.get('MINI_CONSENT_TEST_BINARY')
        if not sys.platform.startswith('linux') or os.geteuid() != 0 or not binary:
            self.skipTest('Linux root and MINI_CONSENT_TEST_BINARY required for distinct peer')
        self.binary = Path(binary)
        if not self.binary.is_absolute() or not self.binary.is_file():
            self.skipTest('configured mini binary unavailable')
        self.tmp = tempfile.TemporaryDirectory(prefix='consent-adversary-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        os.chmod(self.root, 0o755)
        self.client_uid = 65533
        try:
            pwd.getpwuid(self.client_uid)
        except KeyError:
            pass
        else:
            self.skipTest('disposable test UID is allocated to an account')
        try:
            grp.getgrgid(self.client_uid)
        except KeyError:
            pass
        else:
            self.skipTest('disposable test GID is allocated to a group')
        self.socket_dir = self.root / 'socket'
        self.socket_dir.mkdir(mode=0o700)
        os.chown(self.socket_dir, self.client_uid, self.client_uid)
        self.socket_path = self.socket_dir / 'peer.sock'
        self.anchors = self.root / 'anchors'
        self.anchors.mkdir(mode=0o700)
        self.config = self.root / 'config.json'
        self.config.write_bytes(b'{}')
        source = self.root / 'provider.c'
        source.write_text(PROVIDER)
        self.provider = self.root / 'provider'
        subprocess.run(['cc', '-O0', '-o', str(self.provider), str(source)], check=True, capture_output=True)
        self.provider_hash = hashlib.sha256(self.provider.read_bytes()).digest()
        self.config_hash = hashlib.sha256(self.config.read_bytes()).digest()
        self.hello = TAG + self.provider_hash + self.config_hash
        self.server = None
        self.addCleanup(self.stop)

    def start(self):
        if self.socket_path.exists():
            self.socket_path.unlink()
        listener = socket.socket(socket.AF_UNIX)
        listener.bind(str(self.socket_path))
        os.chown(self.socket_path, self.client_uid, self.client_uid)
        os.chmod(self.socket_path, 0o600)
        listener.listen(4)
        # Set LISTEN_PID in the child itself before exec. FD 3 is the already-bound listener.
        pid = os.fork()
        if pid == 0:
            try:
                fd = listener.fileno()
                if fd != 3:
                    os.dup2(fd, 3)
                os.set_inheritable(3, True)
                env = dict(os.environ, LISTEN_PID=str(os.getpid()), LISTEN_FDS='1')
                args = [str(self.binary), 'serve-controller-consent', '--socket', str(self.socket_path),
                        '--consent', str(self.provider), '--config', str(self.config),
                        '--consent-sha256', self.provider_hash.hex(), '--config-sha256', self.config_hash.hex(),
                        '--controller-uid', str(self.client_uid), '--anchors', str(self.anchors)]
                os.execve(args[0], args, env)
            finally:
                os._exit(127)
        listener.close()
        self.server = pid

    def stop(self):
        if self.server:
            try:
                os.kill(self.server, 15)
            except ProcessLookupError:
                pass
            try:
                os.waitpid(self.server, 0)
            except ChildProcessError:
                pass
            self.server = None

    def exchange(self, payloads, hello=None):
        code = r'''import os,socket,struct,sys
os.setgroups([]);os.setgid(int(sys.argv[1]));os.setuid(int(sys.argv[1]))
s=socket.socket(socket.AF_UNIX);s.settimeout(5);s.connect(sys.argv[2])
def recv(n):
 b=b''
 while len(b)<n:
  x=s.recv(n-len(b))
  if not x: raise EOFError()
  b+=x
 return b
for h in sys.argv[3:]:
 b=bytes.fromhex(h);s.sendall(struct.pack('<I',len(b))+b)
 n=struct.unpack('<I',recv(4))[0];print(recv(n).hex(),flush=True)
'''
        proc = subprocess.run([sys.executable, '-c', code, str(self.client_uid), str(self.socket_path),
                               (self.hello if hello is None else hello).hex(), *[p.hex() for p in payloads]],
                              capture_output=True, text=True, timeout=10)
        return proc.returncode, proc.stdout.splitlines(), proc.stderr

    def test_fake_provider_bootstrap_possession_then_admission_and_restart(self):
        self.start()
        rc, lines, error = self.exchange([bytes([226]), bytes([220])])
        self.assertEqual(rc, 0, error)
        self.assertEqual([bytes.fromhex(x) for x in lines], [self.hello, b'\xe2possession', b'\xdcok'])
        self.assertTrue((self.anchors / 'frontier').is_file())
        self.stop()
        self.start()
        rc, lines, error = self.exchange([bytes([220])])
        self.assertEqual(rc, 0, error)
        self.assertEqual(bytes.fromhex(lines[-1]), b'\xdcok')

    def test_source_refusal_retains_frontier_before_return(self):
        self.start()
        rc, lines, error = self.exchange([bytes([221])])
        self.assertEqual(rc, 0, error)
        self.assertEqual(bytes.fromhex(lines[-1]), b'\xffrefused')
        self.assertIn(b'frontier', (self.anchors / 'frontier').read_bytes())
        self.stop()
        self.start()
        rc, lines, error = self.exchange([bytes([220])])
        self.assertEqual(rc, 0, error)
        self.assertEqual(bytes.fromhex(lines[-1]), b'\xdcok')

    def test_anchor_write_failure_never_returns_success_and_poisons_worker(self):
        self.start()
        rc, _, error = self.exchange([bytes([220])])
        self.assertEqual(rc, 0, error)
        frontier = self.anchors / 'frontier'
        frontier.unlink()
        frontier.mkdir(mode=0o700)  # Force atomic replacement to fail after the provider answers.
        rc, lines, _ = self.exchange([bytes([220])])
        self.assertNotEqual(rc, 0, 'failed durable anchor returned successful consent')
        self.assertEqual([bytes.fromhex(x) for x in lines], [self.hello])
        rc, lines, _ = self.exchange([bytes([220])])
        self.assertNotEqual(rc, 0, 'poisoned worker returned successful consent')
        self.assertEqual([bytes.fromhex(x) for x in lines], [self.hello])

    def test_missing_and_corrupt_durable_frontier_never_restart_as_genesis(self):
        self.start()
        rc, _, error = self.exchange([bytes([220])])
        self.assertEqual(rc, 0, error)
        self.stop()
        frontier = self.anchors / 'frontier'
        saved = frontier.read_bytes()
        for value in (None, b'corrupt'):
            if frontier.exists():
                frontier.unlink()
            if value is not None:
                frontier.write_bytes(value)
                os.chmod(frontier, 0o600)
            self.start()
            rc, _, _ = self.exchange([bytes([220])])
            self.assertNotEqual(rc, 0, 'missing or corrupt anchor admitted')
            self.stop()
        frontier.write_bytes(saved)
        os.chmod(frontier, 0o600)

    def test_changed_service_config_and_provider_refuse_restart(self):
        self.start()
        rc, _, error = self.exchange([bytes([220])])
        self.assertEqual(rc, 0, error)
        self.stop()
        original_config = self.config.read_bytes()
        self.config.write_bytes(b'{"changed":true}')
        self.start()
        rc, _, _ = self.exchange([bytes([220])])
        self.assertNotEqual(rc, 0, 'changed service config was accepted')
        self.stop()
        self.config.write_bytes(original_config)
        original_provider = self.provider.read_bytes()
        self.provider.write_bytes(original_provider + b'changed')
        self.start()
        rc, _, _ = self.exchange([bytes([220])])
        self.assertNotEqual(rc, 0, 'changed provider was accepted')
        self.stop()
        self.provider.write_bytes(original_provider)
        self.start()
        rc, _, error = self.exchange([bytes([220])])
        self.assertEqual(rc, 0, error)

    def test_other_peer_is_rejected_before_handshake(self):
        self.start()
        with socket.socket(socket.AF_UNIX) as s:
            s.settimeout(5)
            s.connect(str(self.socket_path))  # root can pass DAC, but is not the controller UID.
            try:
                s.sendall(framed(self.hello))
                received = s.recv(4)
            except (ConnectionResetError, BrokenPipeError):
                received = b''
            self.assertEqual(received, b'')

    def test_wrong_binding_and_internal_operation_cannot_reach_provider(self):
        self.start()
        rc, _, _ = self.exchange([], hello=TAG + b'\0' * 64)
        self.assertNotEqual(rc, 0)
        rc, lines, _ = self.exchange([bytes([229])])
        self.assertNotEqual(rc, 0)
        self.assertEqual(bytes.fromhex(lines[0]), self.hello)


if __name__ == '__main__':
    unittest.main()
