#!/usr/bin/env python3
"""Private browser fixture; Mini's route remains the admission authority."""
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import socket
import subprocess
import sys
import time


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def host(port):
    if not re.fullmatch(r'[1-9][0-9]{3,4}', str(port)) or not 1024 <= int(port) <= 65535:
        raise ValueError('browser port must be canonical decimal 1024..65535')
    return 'localhost:' + str(port)


def config(expected_host, route, directory):
    if expected_host != host(expected_host.removeprefix('localhost:')):
        raise ValueError('browser expected Host differs')
    for path in (route, directory):
        if not path.is_absolute() or re.search(r'[^A-Za-z0-9_./-]', str(path)):
            raise ValueError('browser paths must be simple absolute paths')
    return ('{\n admin off\n auto_https off\n storage file_system ' + str(directory/'data') + '\n}\n'
            'https://' + expected_host + ' {\n bind 127.0.0.1\n tls ' + str(directory/'cert.pem') + ' ' +
            str(directory/'key.pem') + '\n reverse_proxy unix/' + str(route/'http.sock') + '\n}\n')


def validate(result, ready):
    if result.get('protocol') != 'mini-oracle-browser-probe-v1' or result.get('url') != ready['url']:
        raise ValueError('browser result identity differs')
    if result.get('route_custodian_sha256') != ready['route_custodian_sha256']:
        raise ValueError('browser route binding differs')
    if not all(result.get(k) == 200 for k in ('root_status','catalog_status','query_status')):
        raise ValueError('browser did not receive successful root/catalog/query replies')
    if result.get('anonymous_status') not in (401,403) or result.get('wrong_origin_status') not in (401,403):
        raise ValueError('browser anonymous access was not refused')
    if result.get('bootstrap_used') is not True or result.get('root_ui_rendered') is not True:
        raise ValueError('browser did not bootstrap and render the UI')
    if 'Whitman' not in result.get('query_answer',''):
        raise ValueError('browser query did not answer the supplied question')


def process_identity(pid):
    fields=(Path('/proc')/str(pid)/'stat').read_text().rsplit(')',1)[1].split()
    return {'pid':pid,'start_ticks':int(fields[19])}


def stopped(identity):
    try:
        path=Path('/proc')/str(identity['pid'])/'stat'
        fields=path.read_text().rsplit(')',1)[1].split()
        return int(fields[19]) != identity['start_ticks'] or fields[0] == 'Z'
    except FileNotFoundError:
        return True


def stop(directory, grace=5):
    path=directory/'edge-process.json'
    if not path.exists() or (directory/'edge-stopped.json').exists():
        return
    saved=json.loads(path.read_bytes())
    if stopped(saved):
        return
    # Bind signals to this process instance, even if its numeric PID is reused.
    try:
        pidfd=os.pidfd_open(saved['pid'])
    except ProcessLookupError:
        return
    try:
        if process_identity(saved['pid']) != saved:
            raise ValueError('edge PID was reused; refusing to signal')
        signal.pidfd_send_signal(pidfd,signal.SIGTERM)
        deadline=time.monotonic()+grace
        while not stopped(saved) and time.monotonic()<deadline:time.sleep(.05)
        if not stopped(saved):
            signal.pidfd_send_signal(pidfd,signal.SIGKILL)
            deadline=time.monotonic()+5
            while not stopped(saved) and time.monotonic()<deadline:time.sleep(.05)
        if not stopped(saved):raise ValueError('recorded edge process remains alive after bounded cleanup')
    except (ProcessLookupError,FileNotFoundError):
        pass
    finally:
        os.close(pidfd)



def run(run_root,state,caddy,digest,port):
    expected=host(port);route=state/'apps/9201/routes/owner-web'
    policy=json.loads((route/'custodian.json').read_bytes())
    if policy.get('expectedHost') != expected or policy.get('fixedSessionKind') != 'web':
        raise ValueError('native browser route differs from selected loopback origin')
    if not caddy.is_absolute() or caddy.is_symlink() or sha(caddy) != digest:
        raise ValueError('Caddy executable differs from qualification pin')
    directory=run_root/'browser';directory.mkdir(mode=0o700)
    (directory/'data').mkdir(mode=0o700);(directory/'config').mkdir(mode=0o700)
    (directory/'Caddyfile').write_text(config(expected,route,directory))
    with (directory/'openssl.log').open('xb') as log:
        subprocess.run(['openssl','req','-x509','-newkey','ec','-pkeyopt','ec_paramgen_curve:P-256',
            '-nodes','-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost',
            '-keyout',str(directory/'key.pem'),'-out',str(directory/'cert.pem')],check=True,stdout=log,stderr=log)
    environment={**os.environ,'HOME':str(directory),'XDG_DATA_HOME':str(directory/'data'),'XDG_CONFIG_HOME':str(directory/'config')}
    with (directory/'caddy.log').open('xb') as log:
        child=subprocess.Popen([str(caddy),'run','--config',str(directory/'Caddyfile'),'--adapter','caddyfile'],
            env=environment,stdout=log,stderr=log,start_new_session=True)
        (directory/'edge-process.json').write_text(json.dumps(process_identity(child.pid))+'\n')
        try:
            deadline=time.monotonic()+20
            while True:
                if child.poll() is not None:raise ValueError('private edge exited during startup')
                try:
                    with socket.create_connection(('127.0.0.1',int(port)),timeout=.2):break
                except OSError:
                    if time.monotonic()>deadline:raise ValueError('private edge readiness expired')
                    time.sleep(.1)
            ready={'protocol':'mini-oracle-browser-ready-v1','url':'https://'+expected+'/',
                'route_custodian_sha256':sha(route/'custodian.json'),'bootstrap_token_path':str(route/'bootstrap.token'),
                'certificate_path':str(directory/'cert.pem'),'caddy_sha256':digest,'app':'9201',
                'result_path':str(directory/'result.json'),'question':'Who wrote Leaves of Grass?',
                'deadline_seconds':1800}
            (directory/'ready.json').write_text(json.dumps(ready,indent=2)+'\n')
            deadline=time.monotonic()+1800
            while not (directory/'result.json').is_file():
                if child.poll() is not None:raise ValueError('private edge exited during browser probe')
                if time.monotonic()>deadline:raise ValueError('browser probe deadline expired')
                time.sleep(1)
            validate(json.loads((directory/'result.json').read_bytes()),ready)
            if not (route/'bootstrap.used').is_file():raise ValueError('native browser bootstrap marker absent')
            (directory/'passed.json').write_text(json.dumps({'protocol':'mini-oracle-browser-acceptance-v1',
                'result_sha256':sha(directory/'result.json'),'ready_sha256':sha(directory/'ready.json'),
                'bootstrap_marker_sha256':sha(route/'bootstrap.used'),'admission':'native owner-web route'})+'\n')
        finally:
            stop(directory)
            try:child.wait(timeout=20)
            except subprocess.TimeoutExpired:
                if process_identity(child.pid)==json.loads((directory/'edge-process.json').read_bytes()):
                    child.kill();child.wait(timeout=10)
            (directory/'edge-stopped.json').write_text(json.dumps({'pid':child.pid,'returncode':child.returncode})+'\n')


if __name__=='__main__':
    try:
        if len(sys.argv)==3 and sys.argv[1]=='stop':stop(Path(sys.argv[2]))
        elif len(sys.argv)==7 and sys.argv[1]=='run':run(Path(sys.argv[2]),Path(sys.argv[3]),Path(sys.argv[4]),sys.argv[5],sys.argv[6])
        else:raise ValueError('usage: browser_edge.py run RUN STATE CADDY SHA256 PORT | stop BROWSER_DIR')
    except (ValueError,OSError,subprocess.SubprocessError) as error:
        raise SystemExit('browser probe stopped: '+str(error))
