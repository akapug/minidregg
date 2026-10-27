#!/usr/bin/env python3
"""Bounded smoke-runner contract tests; no claim of real Oracle execution."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer

spec = importlib.util.spec_from_file_location("smoke", Path(__file__).with_name("oracle-transport-smoke.py"))
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)

class TenantSmokeTests(unittest.TestCase):
    def test_probe_scope_matches_exact_bridge_vector(self):
        self.assertEqual(smoke.probe_tenant(), "7ee2ad3454d58f2cda8213344f2e3432fb41b894687ea992ccf8e99a1e6b124c")
        self.assertNotEqual(smoke.probe_tenant(), smoke.probe_tenant(4))

    def test_fixed_pool_command_keeps_runtime_and_workspace_separate(self):
        args=SimpleNamespace(python=Path('/venv/python'),adapter=Path('/adapter/serve.py'),runtime=Path('/runtime'))
        command=smoke.adapter_command(args,Path('/private/workspace'),7070)
        self.assertEqual(command[:3],['/venv/python','-B','/adapter/serve.py'])
        for flag,value in [('--runtime','/runtime'),('--workspace','/private/workspace'),('--max-resident','1'),('--max-tenants','8')]:
            self.assertEqual(command[command.index(flag)+1],value)
        self.assertIn('--tenant-pool',command)

    def test_direct_replay_sends_one_tenant_header_except_health(self):
        seen=[]
        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                seen.append((self.path,self.headers.get_all('X-Mini-Oracle-Tenant',[])))
                self.send_response(200);self.send_header('Content-Length','2');self.end_headers();self.wfile.write(b'{}')
            def log_message(self,*args):pass
        with HTTPServer(('127.0.0.1',0),Handler) as server:
            worker=threading.Thread(target=lambda:[server.handle_request() for _ in range(3)])
            worker.start()
            try:
                for path,tenant in [('/health',None),('/capabilities',None),('/operations',smoke.probe_tenant(4))]:
                    self.assertEqual(smoke.direct(server.server_port,'GET',path,timeout=2,tenant=tenant),(200,b'{}'))
            finally:worker.join(timeout=3)
            self.assertFalse(worker.is_alive())
        self.assertEqual(seen,[('/health',[]),('/capabilities',[smoke.probe_tenant()]),('/operations',[smoke.probe_tenant(4)])])

if __name__=='__main__':unittest.main()
