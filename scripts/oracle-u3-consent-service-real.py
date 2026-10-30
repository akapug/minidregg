#!/usr/bin/env python3
"""Disposable actual distinct-UID consent service over a copied R2 Store."""
import hashlib, json, os, pwd, grp, selectors, signal, socket, struct, subprocess, sys, tempfile, time
from pathlib import Path
assert os.geteuid()==0
mini, fixture, out = map(Path,sys.argv[1:]); out.mkdir(mode=0o700,exist_ok=False)
try: pwd.getpwuid(65533); raise RuntimeError('fixture UID belongs to account')
except KeyError: pass
try: grp.getgrgid(65533); raise RuntimeError('fixture GID belongs to group')
except KeyError: pass
uid=65533; op=pwd.getpwnam('hbox'); assert op.pw_uid==1000 and op.pw_gid==1000
provider=fixture/'provider'; config=fixture/'deployment/private-copy-config.json'; db=fixture/'store/forward-link.sqlite3'; anchor=fixture/'store.head-anchor'; intent=(fixture/'birth-attempt/intent.bin').read_bytes(); key=(fixture/'controller.pub').read_bytes(); assert len(key)==32
def sha(b): return hashlib.sha256(b).hexdigest()
def pin(p): return sha(p.read_bytes())
before={str(p):pin(p) for p in (config,db,anchor)}
image=bytes.fromhex(pin(provider)); settings=bytes.fromhex(pin(config)); hello=b'MINI-CONTROLLER-CONSENT/v1\0'+image+settings
anchors=fixture/'consent-anchors'; anchors.mkdir(mode=0o700); os.chown(anchors,1000,1000)
client_code=r'''import json,os,socket,struct,sys,time
j=json.load(sys.stdin); assert not os.access(j['provider'],os.R_OK) and not os.access(j['config'],os.R_OK)
s=socket.socket(socket.AF_UNIX); s.settimeout(1200); s.connect(j['socket'])
def exact(n):
 b=b''
 while len(b)<n:
  v=s.recv(n-len(b))
  if not v: raise EOFError('short frame')
  b+=v
 return b
def call(b):
 start=time.monotonic(); s.sendall(struct.pack('<I',len(b))+b); n=struct.unpack('<I',exact(4))[0]
 if not 0<n<=12102760: raise ValueError('frame bound')
 return exact(n),time.monotonic()-start
reply,_=call(bytes.fromhex(j['hello'])); assert reply==bytes.fromhex(j['hello'])
intent=bytes.fromhex(j['intent']); key=bytes.fromhex(j['key'])
def pair(a,b): return struct.pack('<I',len(a))+a+b
frames=[('valid',b'\xdc'+pair(intent,pair(key,b'')))]
if j['first']:
 frames += [('wrong-key',b'\xdc'+pair(intent,pair(bytes([key[0]^1])+key[1:],b''))),('malformed-intent',b'\xdc'+pair(intent+b'\0',pair(key,b''))),('unsupported-224',b'\xe0'+pair(b'\xff',b'')),('valid-after',b'\xdc'+pair(intent,pair(key,b'')))]
answers={}
for name,body in frames:
 reply,sec=call(body)
 if name.startswith('valid'): assert reply==b'\xdc'+intent
 elif name=='wrong-key': assert reply[:1]==b'\xff' and b'local intent subject differs from custody signer' in reply
 elif name=='malformed-intent': assert reply[:1]==b'\xff' and b'noncanonical retained local intent' in reply
 else: assert reply[:1]==b'\xff' and b'unsupported specialized consent adapter' in reply
 import hashlib
 answers[name]={'seconds':sec,'sha256':hashlib.sha256(reply).hexdigest(),'bytes':len(reply)}
print(json.dumps(answers))
'''

def start(path):
 listener=socket.socket(socket.AF_UNIX); listener.bind(str(path)); os.chown(path,uid,uid); os.chmod(path,0o600); listener.listen(4)
 pid=os.fork()
 if pid==0:
  try:
   fd=listener.fileno()
   if fd!=3: os.dup2(fd,3)
   os.set_inheritable(3,True); os.setgroups([]); os.setgid(1000); os.setuid(1000)
   log=os.open(str(out/'service.log'),os.O_WRONLY|os.O_CREAT|os.O_APPEND,0o600); os.dup2(log,1); os.dup2(log,2)
   env=dict(os.environ,LISTEN_PID=str(os.getpid()),LISTEN_FDS='1')
   args=[str(mini),'serve-controller-consent','--socket',str(path),'--consent',str(provider),'--config',str(config),'--consent-sha256',image.hex(),'--config-sha256',settings.hex(),'--controller-uid',str(uid),'--anchors',str(anchors)]
   os.execve(args[0],args,env)
  finally: os._exit(127)
 listener.close(); return pid

def stop(pid):
 try: os.kill(pid,signal.SIGTERM)
 except ProcessLookupError: pass
 try: os.waitpid(pid,0)
 except ChildProcessError: pass

def client(path,first):
 payload={'socket':str(path),'provider':str(provider),'config':str(config),'hello':hello.hex(),'intent':intent.hex(),'key':key.hex(),'first':first}
 r=subprocess.run(['setpriv','--reuid',str(uid),'--regid',str(uid),'--clear-groups',sys.executable,'-c',client_code],input=json.dumps(payload).encode(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=1300)
 if r.returncode: raise RuntimeError('controller exchange failed: '+r.stderr.decode(errors='replace')[-2000:])
 return json.loads(r.stdout)
with tempfile.TemporaryDirectory(prefix='mini-consent-real-') as tmp:
 os.chmod(tmp,0o755); sockdir=Path(tmp)/'socket'; sockdir.mkdir(); os.chown(sockdir,uid,uid); os.chmod(sockdir,0o711); path=sockdir/'consent.sock'
 # The service UID can append its own log without exposing the fixture to controller.
 os.chown(out,1000,1000); os.chmod(out,0o700)
 pid=start(path)
 try:
  first=client(path,True)
  frontier=anchors/'frontier'; assert frontier.is_file() and frontier.stat().st_size>0
  frontier_hash=pin(frontier)
  children=Path(f'/proc/{pid}/task/{pid}/children').read_text().split()
  assert len(children)==1, f'provider child count: {children}'
  child=int(children[0]); status=Path(f'/proc/{child}/status').read_text()
  hwm=next((int(line.split()[1]) for line in status.splitlines() if line.startswith('VmHWM:')),None)
 finally: stop(pid)
 path.unlink()
 pid=start(path)
 try:
  second=client(path,False)
  assert frontier.is_file() and frontier.stat().st_size>0
 finally: stop(pid)
for p in (config,db,anchor): assert pin(p)==before[str(p)], f'copied input changed: {p}'
report={'schema':'oracle-u3-real-consent-service-v1','passed':True,'scope':'actual Lean provider, copied R2 Store, distinct UID socket and durable restart; no signing or submission', 'mini_sha256':pin(mini),'provider_sha256':image.hex(),'config_sha256':settings.hex(),'intent_sha256':sha(intent),'public_key_sha256':sha(key),'store_sha256':before[str(db)],'head_anchor_sha256':before[str(anchor)],'provider_peak_rss_kib_at_first_completion':hwm,'frontier_sha256_after_first':frontier_hash,'first':first,'restart':second,'controller_cannot_read_provider_or_config':True}
(out/'report.json').write_text(json.dumps(report,indent=2)+'\n'); print(json.dumps(report,indent=2))
