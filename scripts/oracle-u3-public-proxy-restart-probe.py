#!/usr/bin/env python3
"""Disposable real ordinary public-proxy restart and ACL fixture (Linux root)."""
import hashlib, json, os, pwd, grp, shutil, signal, socket, struct, subprocess, sys, tempfile, time
from pathlib import Path
assert os.geteuid()==0
mini=Path(sys.argv[1]); evidence=Path(sys.argv[2]); evidence.mkdir(mode=0o700,exist_ok=False)
assert mini.is_absolute() and mini.is_file()
operator=pwd.getpwnam('hbox'); assert operator.pw_uid==1000 and operator.pw_gid==1000
controller=65533
try: pwd.getpwuid(controller); raise RuntimeError('fixture controller UID belongs to an account')
except KeyError: pass
try: grp.getgrgid(controller); raise RuntimeError('fixture controller GID belongs to a group')
except KeyError: pass
root=Path(tempfile.mkdtemp(prefix='mini-u3-public-',dir='/run')); os.chmod(root,0o711)
children=[]
def cmd(*args): subprocess.run(args,check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
def drop(): os.setgroups([]); os.setgid(1000); os.setuid(1000)
def terminate(p):
 if p.poll() is None:
  p.terminate()
  try: p.wait(timeout=5)
  except subprocess.TimeoutExpired: p.kill(); p.wait()
def acl_valid(p):
 cmd('setfacl','-b',str(p)); os.chmod(p,0o700)
 cmd('setfacl','-m',f'u:{controller}:--x,m::--x',str(p))
def proxy_args(parent, uid=controller):
 args=[str(mini),'serve-public-proxy','--socket',str(parent/'mini.sock'),'--upstream',str(private/'operator.sock'),'--config',str(private/'config.json')]
 if uid is not None: args += ['--controller-uid',str(uid)]
 return args

def refuse(label,parent,uid=controller,extra=()):
 p=subprocess.run(proxy_args(parent,uid)+list(extra),preexec_fn=drop,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=15)
 (evidence/(label+'.stderr')).write_bytes(p.stderr)
 assert p.returncode!=0 and not (parent/'mini.sock').exists(), (label,p.returncode,p.stderr)
 return p.stderr

def start(parent):
 old_inode=(parent/'mini.sock').lstat().st_ino if (parent/'mini.sock').exists() else None
 p=subprocess.Popen(proxy_args(parent),preexec_fn=drop,stdout=subprocess.DEVNULL,stderr=(evidence/'proxy.log').open('ab'))
 children.append(p); deadline=time.monotonic()+20
 while not ((parent/'mini.sock').is_socket() and (parent/'mini.sock').lstat().st_ino != old_inode):
  if p.poll() is not None: raise RuntimeError('proxy exited before binding')
  if time.monotonic()>deadline: raise TimeoutError('proxy bind')
  time.sleep(.02)
 return p
client=r'''import json,os,socket,struct,sys
j=json.load(sys.stdin); s=socket.socket(socket.AF_UNIX); s.settimeout(10)
try: s.connect(j['socket'])
except PermissionError:
 if j['foreign']: print(json.dumps({'denied':True})); sys.exit(0)
 raise
if j['foreign']: raise AssertionError('foreign connected')
def req(op):
 config=b'{"domain":"7"}'; payload=bytes([op])+(b'\x01' if op in (22,152) else b'')
 body=b'\x02'+struct.pack('<I',len(config))+config+b'\xab'*32+payload
 s.sendall(struct.pack('<I',len(body))+body)
 def read(n):
  out=b''
  while len(out)<n:
   part=s.recv(n-len(out))
   if not part: raise EOFError('short response')
   out+=part
  return out
 n=struct.unpack('<I',read(4))[0]; return read(n)
# Each public connection carries one frame.
r=req(j['op']); print(json.dumps({'reply':r.hex()}))
'''
def exchange(path,uid,op,foreign=False):
 inp=json.dumps({'socket':str(path),'op':op,'foreign':foreign}).encode()
 p=subprocess.run(['setpriv','--reuid',str(uid),'--regid',str(uid),'--clear-groups',sys.executable,'-c',client],input=inp,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=20)
 assert p.returncode==0,(uid,op,p.stderr)
 return json.loads(p.stdout)
backend=r'''import os,socket,struct,sys
p,log=sys.argv[1:]; s=socket.socket(socket.AF_UNIX); s.bind(p); os.chmod(p,0o600); s.listen(8)
with open(log,'w',buffering=1) as out:
 while True:
  c,_=s.accept(); c.settimeout(10)
  with c:
   x=c.recv(4)
   if not x: continue
   while len(x)<4: x+=c.recv(4-len(x))
   n=struct.unpack('<I',x)[0]; b=b''
   while len(b)<n:
    q=c.recv(n-len(b))
    if not q: raise EOFError()
    b+=q
   op=b[-1]; out.write(str(op)+'\n'); reply=bytes([op,9]); c.sendall(struct.pack('<I',len(reply))+reply)
'''
try:
 cmd('setfacl','-m',f'u:{controller}:--x,m::--x',str(root))
 private=root/'private'; private.mkdir(mode=0o700); os.chown(private,1000,1000)
 public=root/'public'; public.mkdir(mode=0o700); os.chown(public,1000,1000)
 for name,data in [('config.json',b'{"domain":"7"}'),('operator.config',b'{"domain":"7"}'),('operator.mode',b'operator-v1')]:
  p=private/name; p.write_bytes(data); os.chown(p,1000,1000); os.chmod(p,0o600)
 backend_log=private/'backend.log'
 back=subprocess.Popen([sys.executable,'-c',backend,str(private/'operator.sock'),str(backend_log)],preexec_fn=drop,stdout=subprocess.DEVNULL,stderr=(evidence/'backend.stderr').open('wb')); children.append(back)
 deadline=time.monotonic()+15
 while not (private/'operator.sock').is_socket():
  if back.poll() is not None or time.monotonic()>deadline: raise RuntimeError('backend did not bind')
  time.sleep(.02)
 acl_valid(public)
 # Parent custody negatives precede any binding or persistent pin.
 cmd('setfacl','-b',str(public)); os.chmod(public,0o700); cmd('setfacl','-m','u:65534:--x,m::--x',str(public)); refuse('wrong-named-user',public)
 acl_valid(public); cmd('setfacl','-m','g:65534:r-x,m::r-x',str(public)); refuse('extra-group',public)
 acl_valid(public); cmd('setfacl','-m','m::---',str(public)); refuse('mask-denies',public)
 acl_valid(public); cmd('setfacl','-d','-m',f'u::rwx,u:{controller}:--x,g::---,m::--x,o::---',str(public)); refuse('default-acl',public); cmd('setfacl','-k',str(public))
 acl_valid(public); link=root/'link'; link.symlink_to(public); refuse('symlink-parent',link)
 os.chown(public,65534,65534); refuse('foreign-owner',public); os.chown(public,1000,1000)
 acl_valid(public)
 first=start(public); path=public/'mini.sock'
 acl=subprocess.check_output(['getfacl','-cpn',str(path)],text=True)
 assert set(acl.strip().splitlines())=={'user::rw-',f'user:{controller}:-w-','group::---','mask::-w-','other::---'},acl
 assert exchange(path,controller,0)['reply']=='0009'
 for op in (22,152): assert bytes.fromhex(exchange(path,controller,op)['reply'])[0]==254
 assert exchange(path,65534,0,True)['denied']
 terminate(first); children.remove(first)
 # A stale socket is deliberate: the ordinary service must recreate its ACL.
 second=start(public); path=public/'mini.sock'
 acl2=subprocess.check_output(['getfacl','-cpn',str(path)],text=True)
 assert set(acl2.strip().splitlines())=={'user::rw-',f'user:{controller}:-w-','group::---','mask::-w-','other::---'},acl2
 assert exchange(path,controller,0)['reply']=='0009'
 terminate(second); children.remove(second)
 path.unlink(missing_ok=True)
 # Exact stored controller identity survives restart and rejects omission/drift.
 cmd('setfacl','-b',str(public)); os.chmod(public,0o700)
 assert b'public controller selection is retained' in refuse('omitted-controller',public,None)
 cmd('setfacl','-b',str(root)); os.chmod(root,0o711); cmd('setfacl','-m','u:65534:--x,m::--x',str(root))
 cmd('setfacl','-m','u:65534:--x,m::--x',str(public))
 assert b'retained host config differs from requested service config' in refuse('changed-controller',public,65534)
 assert backend_log.read_text().splitlines()==['0','0']
 report={'schema':'oracle-u3-public-proxy-restart-v1','passed':True,'scope':'real mini ordinary proxy and physical UID/ACL boundary with fake upstream; not Mini admission','mini_sha256':hashlib.sha256(mini.read_bytes()).hexdigest(),'allowed_op0_count':2,'private_ops_refused':[22,152],'foreign_uid_denied':True,'socket_acl_recreated':True,'parent_negatives':['wrong-named-user','extra-group','mask-denies','default-acl','symlink-parent','foreign-owner'],'persistent_identity_negatives':['omitted-controller','changed-controller']}
 (evidence/'report.json').write_text(json.dumps(report,indent=2)+'\n'); print(json.dumps(report,indent=2))
finally:
 for p in reversed(children): terminate(p)
 shutil.rmtree(root)
