#!/usr/bin/env python3
"""Flatness gate (ember 10-29: "the system should NEVER GET SLOWER OVER TIME, except by at most a
logarithmic factor"). Appends to one document on a fresh scratch world and compares the Host's CPU per
submit (and the submit's wall time) early versus late:

  usage: flatness-bench.py --bin CANDIDATE_BIN_DIR --root NEW_DIR --src REPO_SRC [--n 1000] [--lo 10]

The early window is the median over appends [lo/2, lo], the late window the median over the last lo
appends. The gate passes when late <= early * max(1.5, log2(n) / log2(lo)): cost may grow by at most a
log factor in the history length. Prints the per-append TSV, then one verdict line:
  FLATNESS submit_cpu early=.. late=.. ratio=.. bound=.. PASS|FAIL  (and the same for submit_wall)
Exit 0 on PASS, 1 on FAIL, 2 on a broken run. The same Host CPU reading as doc-submit-bench.py (every
process under the world's `mini serve`). GET through an app route: scripts/perf/flatness-route.sh.
"""
import argparse,json,math,os,pathlib,signal,statistics,subprocess,sys,time
os.umask(0o077)
ap=argparse.ArgumentParser()
ap.add_argument('--bin',required=True);ap.add_argument('--root',required=True);ap.add_argument('--src',required=True)
ap.add_argument('--n',type=int,default=1000);ap.add_argument('--lo',type=int,default=10)
a=ap.parse_args()
if a.n < 4*a.lo: raise SystemExit('--n must be at least 4x --lo')
root=pathlib.Path(a.root).resolve();bin_=pathlib.Path(a.bin).resolve();src=pathlib.Path(a.src).resolve()
host,mini,store,verifier=[bin_/n for n in ['minidregg-host','mini','minidregg-link-sqlite-store','minidregg-credential-signature-verifier']]
if root.exists():raise SystemExit('root exists')
root.mkdir(mode=0o700);T=root/'transcript';T.mkdir()
TICK=os.sysconf('SC_CLK_TCK')
os.environ.setdefault('CANDIDATE',str(bin_.parent))
def sh(tag,*cmd):
    r=subprocess.run([str(c) for c in cmd],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    if r.returncode:
        (T/f'{tag}.err').write_bytes(r.stderr)
        print(f'FLATNESS broken: {tag} rc={r.returncode}: {r.stderr.decode(errors="replace")[-800:]}',flush=True); sys.exit(2)
    return r
def tree(pid):
    out=[pid]
    try:
        for k in pathlib.Path(f'/proc/{pid}/task/{pid}/children').read_text().split(): out+=tree(int(k))
    except OSError: pass
    return out
def cpu(pid):
    total=0
    for p in tree(pid):
        try:
            f=pathlib.Path(f'/proc/{p}/stat').read_text().rsplit(')',1)[1].split(); total+=int(f[11])+int(f[12])
        except OSError: pass
    return total*1000//TICK
w=root/'w';sock=w/'public'/'mini.sock';sponsor=w/'sponsor'
sh('genesis','sh',src/'native/resource-client/newparticipant-acceptance.sh',host,mini,store,verifier,w,sock)
pid=int((w/'public'/'server.pid').read_text())
rows=[]
try:
    law={"type":"any","predicates":[{"type":"memberOf","slot":"request/verb","values":["1","3","4","5"]},
        {"type":"all","predicates":[{"type":"eq","slot":"request/verb","value":"2"},
            {"type":"le","slot":"content/payload-bytes/after","value":str(64*a.n+65536)}]}]}
    (root/'draft-law.json').write_text(json.dumps(law))
    sh('doc-new',mini,'workspace','--action','doc-new','--dir',sponsor,'--name','paper','--predicate',root/'draft-law.json')
    print('append\tsubmit_wall_ms\tsubmit_cpu_ms\tpropose_wall_ms\tpropose_cpu_ms',flush=True)
    for i in range(a.n):
        label=f'a{i+1}'
        req={'type':'minidregg-workspace-proposal-v1','action':'invoke',
             'targets':[{'name':'paper','payload':{'type':'document','actions':[{'type':'append','text':f'paragraph {i} '+'x'*32}]}}]}
        (root/f'{label}.json').write_text(json.dumps(req))
        out=[]
        for step,cmd in (('propose',[mini,'workspace','--action','propose','--dir',sponsor,'--request',root/f'{label}.json','--proposal-id',label]),
                         ('submit',[mini,'workspace','--action','submit','--dir',sponsor,'--intent',sponsor/'proposals'/label/'intent.json','--attempt',sponsor/'attempts'/label])):
            c=cpu(pid);t=time.time(); sh(f'{label}-{step}',*cmd); out.append((int((time.time()-t)*1000),cpu(pid)-c))
        o=json.loads((sponsor/'attempts'/label/'outcome.json').read_text())
        if o.get('type')!='confirmed' or o.get('confirmation')!='installed':
            print(f'FLATNESS broken: {label} not installed: {o}',flush=True); sys.exit(2)
        rows.append((out[1][0],out[1][1],out[0][0],out[0][1]))
        print(f'{i+1}\t{out[1][0]}\t{out[1][1]}\t{out[0][0]}\t{out[0][1]}',flush=True)
finally:
    os.kill(pid,signal.SIGTERM)
bound=max(1.5,math.log2(a.n)/math.log2(a.lo))
ok=True
for col,name in ((1,'submit_cpu'),(0,'submit_wall'),(3,'propose_cpu'),(2,'propose_wall')):
    early=statistics.median(r[col] for r in rows[a.lo//2-1:a.lo]);late=statistics.median(r[col] for r in rows[-a.lo:])
    ratio=late/max(early,1);verdict='PASS' if ratio<=bound else 'FAIL'
    if name.startswith('submit') and verdict=='FAIL': ok=False
    print(f'FLATNESS {name} early={early} late={late} ratio={ratio:.2f} bound={bound:.2f} {verdict}',flush=True)
sys.exit(0 if ok else 1)
