#!/usr/bin/env python3
"""Private edge and host/origin composition tests; no live Mini admission claim."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import http.client
import socket
import ssl
import threading
import time

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('browser_edge',ROOT/'deploy/oracle/acceptance/browser_edge.py')
b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)


class BrowserFixtureTests(unittest.TestCase):
    def test_origin_is_explicit_loopback_and_edge_never_rewrites_it(self):
        self.assertEqual(b.host('18443'),'localhost:18443')
        for port in ('0','443','018443','65536','18443/x','18443\n','example.com:18443'):
            with self.subTest(port=port),self.assertRaises(ValueError):b.host(port)
        text=b.config('localhost:18443',Path('/private/route'),Path('/private/browser'))
        self.assertIn('bind 127.0.0.1',text)
        self.assertIn('https://localhost:18443',text)
        self.assertNotIn('header_up',text)
        self.assertNotIn('0.0.0.0',text)

    def test_evidence_requires_actual_positive_and_negative_browser_cases(self):
        ready={'url':'https://localhost:18443/','route_custodian_sha256':'a'*64}
        result={**ready,'protocol':'mini-oracle-browser-probe-v1','root_status':200,'catalog_status':200,
                'query_status':200,'anonymous_status':401,'wrong_origin_status':403,
                'bootstrap_used':True,'root_ui_rendered':True,'query_answer':'Walt Whitman'}
        b.validate(result,ready)
        for field,value in [('wrong_origin_status',200),('anonymous_status',200),('root_ui_rendered',False),
                            ('query_status',500),('route_custodian_sha256','b'*64)]:
            with self.subTest(field=field),self.assertRaises(ValueError):b.validate({**result,field:value},ready)

    def test_shell_curl_uses_native_pinned_host_and_origin_for_both_kinds(self):
        source=(ROOT/'scripts/spk-platform/grain-journey.sh').read_text()
        cred='cred() {'+source.split('cred() {',1)[1].split('\n}',1)[0]+'\n}\n'
        get='http_get() ('+source.split('http_get() (',1)[1].split('\n)',1)[0]+'\n)\n'
        post='http_post() ('+source.split('http_post() (',1)[1].split('\n)',1)[0]+'\n)\n'
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);bin_dir=root/'bin';bin_dir.mkdir();ev=root/'evidence';ev.mkdir()
            capture=root/'args.json';curl=bin_dir/'curl'
            curl.write_text('#!/usr/bin/env python3\nimport os,json,sys\nopen(os.environ["CAPTURE"],"w").write(json.dumps(sys.argv[1:]))\nprint("200")\n');curl.chmod(0o755)
            env={**os.environ,'PATH':str(bin_dir)+':'+os.environ['PATH'],'CAPTURE':str(capture)}
            for host in ('grain.test','localhost:18443'):
                for kind in ('api','web'):
                    route=root/'apps/9201/routes'/('owner-'+kind);route.mkdir(parents=True,exist_ok=True)
                    (route/'custodian.json').write_text(json.dumps({'expectedHost':host}))
                    (route/'browser.token').write_text('fixture');(route/'api.token').write_text('fixture')
                    for command in (f'http_get sample 9201 / {kind}',f'http_post sample 9201 {kind} /query body application/json'):
                        subprocess.run(['sh','-eu','-c',f'STATE={root}; EV={ev};\n'+cred+get+post+command],
                                       env=env,check=True,stdout=subprocess.PIPE)
                        args=json.loads(capture.read_bytes());self.assertIn('Host: '+host,args)
                        self.assertEqual(args[-1],'http://'+host+('/query' if 'http_post' in command else '/'))
                        if kind=='web':self.assertIn('Origin: https://'+host,args)

    @unittest.skipUnless(hasattr(os,'pidfd_open'), 'Linux recorded-process cleanup')
    def test_external_stop_waits_and_kills_only_recorded_stubborn_child(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory=Path(tmp)
            child=subprocess.Popen(['python3','-u','-c','import signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); print("ready",flush=True); time.sleep(30)'],stdout=subprocess.PIPE)
            try:
                self.assertEqual(child.stdout.readline(),b'ready\n')
                (directory/'edge-process.json').write_text(json.dumps(b.process_identity(child.pid)))
                b.stop(directory,grace=.1)
                self.assertTrue(b.stopped(json.loads((directory/'edge-process.json').read_bytes())))
                self.assertEqual(child.wait(timeout=2),-9)
            finally:
                if child.poll() is None:child.kill();child.wait(timeout=2)
                child.stdout.close()

    @unittest.skipUnless(os.environ.get('ORACLE_TEST_CADDY'), 'requires pinned fixture Caddy')
    def test_real_caddy_preserves_host_and_origin_over_private_unix_route(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);route=root/'route';route.mkdir();edge=root/'edge';edge.mkdir()
            (edge/'data').mkdir();(edge/'config').mkdir()
            with socket.socket() as reservation:
                reservation.bind(('127.0.0.1',0));port=reservation.getsockname()[1]
            expected=b.host(str(port));captured=[]
            with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as upstream:
                upstream.bind(str(route/'http.sock'));upstream.listen();upstream.settimeout(15)
                def receive():
                    for _ in range(2):
                        stream,_=upstream.accept()
                        with stream:
                            data=b''
                            while b'\r\n\r\n' not in data:data+=stream.recv(4096)
                            captured.append(data.decode())
                            stream.sendall(b'HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok')
                thread=threading.Thread(target=receive,daemon=True);thread.start()
                subprocess.run(['openssl','req','-x509','-newkey','ec','-pkeyopt','ec_paramgen_curve:P-256',
                    '-nodes','-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost',
                    '-keyout',str(edge/'key.pem'),'-out',str(edge/'cert.pem')],check=True,capture_output=True)
                (edge/'Caddyfile').write_text(b.config(expected,route,edge))
                with (edge/'caddy.log').open('wb') as log:
                    child=subprocess.Popen([os.environ['ORACLE_TEST_CADDY'],'run','--config',str(edge/'Caddyfile'),
                        '--adapter','caddyfile'],stdout=log,stderr=log,
                        env={**os.environ,'HOME':str(edge),'XDG_DATA_HOME':str(edge/'data'),'XDG_CONFIG_HOME':str(edge/'config')})
                    try:
                        deadline=time.monotonic()+10
                        while True:
                            try:
                                with socket.create_connection(('127.0.0.1',port),timeout=.1):break
                            except OSError:
                                if child.poll() is not None or time.monotonic()>deadline:self.fail((edge/'caddy.log').read_text())
                                time.sleep(.05)
                        context=ssl.create_default_context(cafile=str(edge/'cert.pem'))
                        for origin in ('https://'+expected,'https://wrong.example'):
                            connection=http.client.HTTPSConnection('localhost',port,context=context,timeout=5)
                            connection.request('GET','/',headers={'Origin':origin})
                            response=connection.getresponse();self.assertEqual(response.status,200);response.read();connection.close()
                        thread.join(timeout=5);self.assertFalse(thread.is_alive())
                        self.assertIn('Host: '+expected,captured[0]);self.assertIn('Origin: https://'+expected,captured[0])
                        self.assertIn('Origin: https://wrong.example',captured[1])
                    finally:
                        child.terminate();child.wait(timeout=10)

    def test_invalid_browser_host_refuses_before_source_steps(self):
        source=(ROOT/'scripts/spk-platform/grain-journey.sh').read_text()
        body=source.split('share() (',1)[1].split('  descriptor=',1)[0]
        for expected in ('evil.example:18443','localhost:0443','localhost:65536'):
            result=subprocess.run(['sh','-c','fail() { exit 19; }; set -- b 9201 9210 9220 3111 10 web;'+body],
                env={**os.environ,'GRAIN_EXPECTED_HOST_B':expected})
            self.assertEqual(result.returncode,19)


if __name__=='__main__':unittest.main()
