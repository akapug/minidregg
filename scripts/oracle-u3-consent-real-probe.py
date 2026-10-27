#!/usr/bin/env python3
"""Actual Lean consent with retained inputs; no signing or lifecycle submit."""
import hashlib, json, os, resource, selectors, struct, subprocess, sys, time
from pathlib import Path
binary, config, intent_path, key_path, out = map(Path, sys.argv[1:])
out.mkdir(mode=0o700, exist_ok=False)
def sha(b): return hashlib.sha256(b).hexdigest()
raw_config=config.read_bytes(); config_obj=json.loads(raw_config); root=Path(config_obj['storageRoot']); db=root/'forward-link.sqlite3'; anchor=Path(str(root)+'.head-anchor')
before={str(p):sha(p.read_bytes()) for p in (config, db, anchor)}
intent=intent_path.read_bytes(); key=key_path.read_bytes(); assert intent and len(key)==32
def pair(left,right): return struct.pack('<I',len(left))+left+right
def frame(op,payload):
    body=bytes([op])+payload
    return struct.pack('<I',len(body))+body
proc=subprocess.Popen([str(binary),str(config),'stdio'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=(out/'provider.stderr').open('wb'),bufsize=0)
def exact(n,deadline):
    data=bytearray(); sel=selectors.DefaultSelector(); sel.register(proc.stdout,selectors.EVENT_READ)
    try:
        while len(data)<n:
            if not sel.select(max(0,deadline-time.monotonic())): raise TimeoutError('provider response deadline')
            part=os.read(proc.stdout.fileno(),n-len(data))
            if not part: raise EOFError('provider closed output')
            data.extend(part)
    finally: sel.close()
    return bytes(data)
def call(name,op,payload):
    start=time.monotonic(); proc.stdin.write(frame(op,payload)); proc.stdin.flush(); deadline=start+1200
    n=struct.unpack('<I',exact(4,deadline))[0]
    assert 0<n<=2*1024*1024, (name,n)
    response=exact(n,deadline); (out/(name+'.bin')).write_bytes(response)
    return response, {'seconds':time.monotonic()-start,'bytes':len(response),'sha256':sha(response)}
measure={}
try:
    reply,measure['valid-220']=call('valid-220',220,pair(intent,pair(key,b'')))
    assert reply==bytes([220])+intent, 'valid source consent changed or refused intent'
    wrong=bytes([key[0]^1])+key[1:]
    reply,measure['wrong-key']=call('wrong-key',220,pair(intent,pair(wrong,b'')))
    assert reply[0]==255 and b'local intent subject differs from custody signer' in reply, reply[:512]
    reply,measure['malformed-intent']=call('malformed-intent',220,pair(intent+b'\x00',pair(key,b'')))
    assert reply[0]==255 and b'noncanonical retained local intent' in reply, reply[:512]
    reply,measure['unsupported-224']=call('unsupported-224',224,pair(b'\xff',b''))
    assert reply[0]==255 and b'unsupported specialized consent adapter' in reply, reply[:512]
    reply,measure['valid-after-refusals']=call('valid-after-refusals',220,pair(intent,pair(key,b'')))
    assert reply==bytes([220])+intent
    proc.stdin.close(); assert proc.wait(timeout=30)==0
finally:
    if proc.poll() is None:
        proc.terminate()
        try: proc.wait(timeout=5)
        except subprocess.TimeoutExpired: proc.kill(); proc.wait()
for path in (config,db,anchor): assert sha(path.read_bytes())==before[str(path)], f'retained input changed: {path}'
report={'schema':'oracle-u3-real-consent-v1','passed':True,'scope':'direct full Lean provider, source admission and refusal controls; no signing or lifecycle submission', 'binary_sha256':sha(binary.read_bytes()),'config_sha256':sha(raw_config),'intent_sha256':sha(intent),'public_key_sha256':sha(key),'store_sha256':before[str(db)],'head_anchor_sha256':before[str(anchor)],'child_maxrss_kib':resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,'measurements':measure}
(out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
