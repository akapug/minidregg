#!/usr/bin/env python3
"""Host CPU per document submit on a fresh scratch world (doc-write-native-acceptance.py's flow, N appends).

  usage: doc-submit-bench.py --bin CANDIDATE_BIN_DIR --root NEW_DIR --src REPO_SRC [--n 20]

Measures utime+stime (clock ticks -> ms) of every process under the world's `mini serve`
(the Lean Host included) around each propose and submit. Prints one TSV row per step.
"""
import argparse,json,os,pathlib,signal,subprocess,sys,time
os.umask(0o077)
ap=argparse.ArgumentParser();ap.add_argument('--bin',required=True);ap.add_argument('--root',required=True)
ap.add_argument('--src',required=True);ap.add_argument('--n',type=int,default=20)
a=ap.parse_args()
root=pathlib.Path(a.root).resolve();bin_=pathlib.Path(a.bin).resolve();src=pathlib.Path(a.src).resolve()
host,mini,store,verifier=[bin_/n for n in ['minidregg-host','mini','minidregg-link-sqlite-store','minidregg-credential-signature-verifier']]
if root.exists():raise SystemExit('root exists')
root.mkdir(mode=0o700);T=root/'transcript';T.mkdir()
TICK=os.sysconf('SC_CLK_TCK')
def sh(tag,*cmd):
    r=subprocess.run([str(c) for c in cmd],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    (T/f'{tag}.err').write_bytes(r.stderr)
    if r.returncode:raise SystemExit(f'FAILED {tag} rc={r.returncode}: {r.stderr.decode(errors="replace")[-1500:]}')
    return r
def tree(pid):
    out=[pid];kids=pathlib.Path(f'/proc/{pid}/task/{pid}/children')
    try:
        for k in kids.read_text().split(): out+=tree(int(k))
    except OSError: pass
    return out
def cpu(pid):
    total=0;names=[]
    for p in tree(pid):
        try:
            f=pathlib.Path(f'/proc/{p}/stat').read_text().rsplit(')',1)[1].split()
            total+=int(f[11])+int(f[12])
        except OSError: pass
    return total*1000//TICK
w=root/'w';sock=w/'public'/'mini.sock';sponsor=w/'sponsor'
t0=time.time()
sh('genesis','sh',src/'native/resource-client/newparticipant-acceptance.sh',host,mini,store,verifier,w,sock)
pid=int((w/'public'/'server.pid').read_text())
print(f'genesis\t{time.time()-t0:.2f}s wall',flush=True)
try:
    law={"type":"any","predicates":[{"type":"memberOf","slot":"request/verb","values":["1","3","4","5"]},
        {"type":"all","predicates":[{"type":"eq","slot":"request/verb","value":"2"},
            {"type":"le","slot":"content/payload-bytes/after","value":"16384"}]}]}
    (root/'draft-law.json').write_text(json.dumps(law))
    c=cpu(pid);t=time.time()
    sh('doc-new',mini,'workspace','--action','doc-new','--dir',sponsor,'--name','paper','--predicate',root/'draft-law.json')
    print(f'doc-new\twall_ms={int((time.time()-t)*1000)}\thost_cpu_ms={cpu(pid)-c}',flush=True)
    print('step\tlabel\twall_ms\thost_cpu_ms',flush=True)
    for i in range(a.n):
        label=f'a{i+1}'
        req={'type':'minidregg-workspace-proposal-v1','action':'invoke',
             'targets':[{'name':'paper','payload':{'type':'document','actions':[{'type':'append','text':f'paragraph {i} '+'x'*64}]}}]}
        (root/f'{label}.json').write_text(json.dumps(req))
        for step,cmd in (('propose',[mini,'workspace','--action','propose','--dir',sponsor,'--request',root/f'{label}.json','--proposal-id',label]),
                         ('submit',[mini,'workspace','--action','submit','--dir',sponsor,'--intent',sponsor/'proposals'/label/'intent.json','--attempt',sponsor/'attempts'/label])):
            c=cpu(pid);t=time.time()
            sh(f'{label}-{step}',*cmd)
            print(f'{step}\t{label}\t{int((time.time()-t)*1000)}\t{cpu(pid)-c}',flush=True)
        o=json.loads((sponsor/'attempts'/label/'outcome.json').read_text())
        if o.get('type')!='confirmed' or o.get('confirmation')!='installed':raise SystemExit(f'{label} not installed: {o}')
finally:
    os.kill(pid,signal.SIGTERM)
