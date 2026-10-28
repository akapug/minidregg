"""Package-protocol fixtures: declaration execution, not deployed qualification."""
import json
import unittest
from binding import Engine, Refusal, load, run_scenario

class KnowledgeDeclarations(unittest.TestCase):
    def test_mediawiki_revision_and_token_are_bound(self):
        d=load('mediawiki'); requests=[]; revisions={}; revision=0
        class Receiver:
            def http(self, r):
                nonlocal revision
                from urllib.parse import parse_qs
                requests.append(r); q=parse_qs(r['query'])
                if r['method']=='POST':
                    q=parse_qs(r['body'].decode()); self_check=q['token']==['csrf+\\']
                    if not self_check: raise AssertionError('token binding changed')
                    title=q['title'][0]
                    if 'createonly' in q and title in revisions:return 200,{'content-type':'application/json'},b'{"error":{"code":"articleexists"}}'
                    if 'baserevid' in q and int(q['baserevid'][0])!=revision:return 200,{'content-type':'application/json'},b'{"error":{"code":"editconflict"}}'
                    revision+=1;revisions[title]=q['text'][0];v={'edit':{'result':'Success','pageid':1,'title':title,'newrevid':revision}}
                elif q.get('meta')==['userinfo']:v={'batchcomplete':'','query':{'userinfo':{'id':1,'name':'Member'}}}
                elif q.get('meta')==['tokens']:v={'batchcomplete':'','query':{'tokens':{'csrftoken':'csrf+\\'}}}
                else:
                    title=q['page'][0];v={'parse':{'title':title,'pageid':1,'revid':revision,'wikitext':{'*':revisions[title]}}}
                return 200,{'content-type':'application/json'},json.dumps(v).encode()
        e=Engine(d,Receiver(),{'runId':'typed-fixture'})
        run_scenario(e)
        self.assertEqual(revision,2)
        self.assertEqual(revisions['typed-fixture'],'typed wiki revised')
        with self.assertRaises(Refusal):e.call('page.update',{'title':'typed-fixture','text':'lost update','summary':'stale','baseRevision':1})
        self.assertEqual(revisions['typed-fixture'],'typed wiki revised')
        self.assertEqual([r['method'] for r in requests[:3]],['GET','GET','POST'])

    def test_etherpad_uses_import_not_disabled_api(self):
        d=load('etherpad');state={}
        class Receiver:
            def http(self,r):
                self_check=r['path'].startswith('p/typed-fixture/')
                if not self_check:raise AssertionError('pad identity changed')
                if r['method']=='POST':
                    self_check=r['path'].endswith('/import') and r['headers']['content-type'].startswith('multipart/form-data; boundary=')
                    if not self_check:raise AssertionError('wrong import transport')
                    self_check=b'filename="document.txt"' in r['body'] and b'typed document\n' in r['body']
                    if not self_check:raise AssertionError('wrong file bytes')
                    state['text']=b'typed document\n';return 200,{'content-type':'application/json'},b'{"code":0,"message":"ok","data":{"directDatabaseAccess":false}}'
                return 200,{'content-type':'text/plain'},state['text']
        run_scenario(Engine(d,Receiver(),{'runId':'typed-fixture'}))

    def test_ethercalc_sheet_identity_and_exact_csv(self):
        d=load('ethercalc');state={}
        class Receiver:
            def http(self,r):
                if r['method']=='PUT':
                    state[r['path']]=r['body'];return 201,{},b''
                if r['path'].endswith('/csv.json'):
                    return 200,{'content-type':'application/json'},b'[["item","qty"],["widgets","3"]]'
                return 200,{'content-type':'text/csv'},state[r['path'][:-4]]
        e=Engine(d,Receiver(),{'runId':'typed-fixture'});run_scenario(e)
        self.assertEqual(state,{'_/typed-fixture':b'item,qty\nwidgets,3\n'})
        with self.assertRaises(Refusal):e.call('sheet.read',{'sheet':'../foreign'})

if __name__=='__main__':unittest.main()
