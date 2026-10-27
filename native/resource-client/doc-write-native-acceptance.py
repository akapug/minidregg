#!/usr/bin/env python3
"""A member's ordinary document write on a fresh scratch world, retained for Fixtures.NativeDocWriteFixture.

The same calls `mini shell` makes for `doc new paper draft` and `doc append a1 paper TEXT`
(shell.rs: `doc-new` with the `draft` law; `document_proposal` = a workspace proposal
{"action":"invoke","targets":[{"name":..,"payload":{"type":"document","actions":[{"type":"append",..}]}}]}
then propose + submit), through the public socket of a native Host and `mini serve` built from
one candidate. A fresh private one-sponsor Store (newparticipant-acceptance.sh), no Objective
policy. Never a live or common world.

  usage: doc-write-native-acceptance.py --bin DIR --root NEW_DIR

Writes ROOT/state.json and ROOT/results/doc-write.json; the retained calls are
ROOT/w/sponsor/attempts/<id>/{call.bin,outcome.json}. Stops the world's `mini serve` at the end.
"""
import argparse,hashlib,json,os,pathlib,signal,subprocess,sys
os.umask(0o077)
HERE=pathlib.Path(__file__).resolve().parent
ap=argparse.ArgumentParser();ap.add_argument('--bin',required=True);ap.add_argument('--root',required=True)
a=ap.parse_args()
root=pathlib.Path(a.root).resolve();bin_=pathlib.Path(a.bin).resolve();T=root/'transcript'
host,mini,store,verifier=[bin_/n for n in ['minidregg-host','mini','minidregg-link-sqlite-store','minidregg-credential-signature-verifier']]
for p in [host,mini,store,verifier,bin_/'minidregg-client-consent']:
    if not p.is_file():raise SystemExit(f'missing {p}')
if root.exists():raise SystemExit('root exists')
root.mkdir(mode=0o700);T.mkdir()
def sh(tag,*cmd):
    r=subprocess.run([str(c) for c in cmd],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    (T/f'{tag}.cmd').write_text(' '.join(str(c) for c in cmd)+'\n');(T/f'{tag}.out').write_bytes(r.stdout);(T/f'{tag}.err').write_bytes(r.stderr)
    if r.returncode:raise SystemExit(f'FAILED {tag} rc={r.returncode}: {r.stderr.decode(errors="replace")[-1500:]}')
    return r
w=root/'w';sock=w/'public'/'mini.sock';sponsor=w/'sponsor'
sh('genesis','sh',HERE/'newparticipant-acceptance.sh',host,mini,store,verifier,w,sock)
pid=int((w/'public'/'server.pid').read_text())
try:
    # shell.rs `document_law("draft")`: any holder of mutate may append and edit, a bounded payload
    law={"type":"any","predicates":[{"type":"memberOf","slot":"request/verb","values":["1","3","4","5"]},
        {"type":"all","predicates":[{"type":"eq","slot":"request/verb","value":"2"},
            {"type":"le","slot":"content/payload-bytes/after","value":"16384"}]}]}
    (root/'draft-law.json').write_text(json.dumps(law))
    sh('doc-new',mini,'workspace','--action','doc-new','--dir',sponsor,'--name','paper','--predicate',root/'draft-law.json')
    out={}
    texts=['first paragraph','second paragraph, appended by the same member']
    for label,text in zip(('a1','a2'),texts):
        req={'type':'minidregg-workspace-proposal-v1','action':'invoke',
             'targets':[{'name':'paper','payload':{'type':'document','actions':[{'type':'append','text':text}]}}]}
        (root/f'{label}.json').write_text(json.dumps(req))
        sh(f'{label}-propose',mini,'workspace','--action','propose','--dir',sponsor,'--request',root/f'{label}.json','--proposal-id',label)
        sh(f'{label}-submit',mini,'workspace','--action','submit','--dir',sponsor,'--intent',sponsor/'proposals'/label/'intent.json','--attempt',sponsor/'attempts'/label)
        o=json.loads((sponsor/'attempts'/label/'outcome.json').read_text())
        if o.get('type')!='confirmed' or o.get('confirmation')!='installed':raise SystemExit(f'{label} not installed: {o}')
        out[label]=o
    sh('read',mini,'workspace','--action','read','--dir',sponsor,'--name','paper')
    view=json.loads((T/'read.out').read_text())
    payloads={e.get('payload') for e in view['cell']['entries'] if e.get('type')=='atom'}
    for t in texts:
        if t.encode().hex() not in payloads:raise SystemExit(f'readback: {t!r} is not an atom of the document')
    (root/'results').mkdir()
    (root/'results'/'doc-write.json').write_text(json.dumps(out,indent=1)+'\n')
    (root/'state.json').write_text(json.dumps({'type':'minidregg-doc-write-native-acceptance-v1','root':str(root),'bin':str(bin_),
        'bin_dir':str(bin_),'config':str(w/'deployment'/'pinned-config.json'),'socket':str(sock),'sponsor':str(sponsor),
        'hostSha256':hashlib.sha256(host.read_bytes()).hexdigest()},indent=1)+'\n')
    print(root/'state.json')
finally:
    os.kill(pid,signal.SIGTERM)
