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


class SiteDeclarations(unittest.TestCase):
    def test_hugo_source_is_read_back_without_publishing(self):
        d=load('hugo');state={};requests=[]
        class Receiver:
            def http(self,r):
                requests.append(r)
                if r['method']=='PUT':state[r['path']]=r['body'];return 201,{},b''
                return 200,{'content-type':'text/plain'},state[r['path']]
        run_scenario(Engine(d,Receiver(),{'runId':'typed-site'}))
        self.assertEqual(len(requests),2)
        self.assertEqual(requests[0]['path'],'admin/api/v1/fs/content/typed-site.md')
        self.assertTrue(d['operations']['site.publish']['write'])

    def test_wordpress_draft_stays_draft_after_edit(self):
        d=load('wordpress');state={};seen=[]
        class Receiver:
            def http(self,r):
                from urllib.parse import parse_qs
                seen.append(r)
                if r['path']=='wp-admin/install.php':return 302,{},b''
                q=parse_qs(r['query']);route=q['rest_route'][0]
                if route=='/wp/v2/users/me':v={'id':7,'name':'Routed member','slug':'member'};status=200
                elif r['method']=='POST':
                    incoming=json.loads(r['body'])
                    if route=='/wp/v2/posts':state.update(id=12,status='draft');status=201
                    else:status=200
                    state.update(title={'raw':incoming['title']},content={'raw':incoming['content']});v=state
                else:v=state;status=200
                return status,{'content-type':'application/json'},json.dumps(v).encode()
        run_scenario(Engine(d,Receiver(),{'runId':'typed-post'}))
        self.assertEqual(state['content']['raw'],'Typed draft revised')
        self.assertEqual(state['status'],'draft')
        self.assertEqual(d['auth']['appCookies'],'omit')
        self.assertFalse(any('nonce' in str(r).lower() for r in seen))

class CalendarDeclaration(unittest.TestCase):
    def test_radicale_etag_scope_without_claiming_time_filter(self):
        d=load('radicale');state={};version=0;puts=[]
        class Receiver:
            def http(self,r):
                nonlocal version
                from xml.sax.saxutils import escape
                path='radicale/owner/typed-calendar.ics/typed-event.ics'
                if r['method']=='MKCALENDAR':return 201,{},b''
                if r['method']=='PUT':
                    self_check=r['path']==path
                    if not self_check:raise AssertionError('foreign calendar')
                    puts.append(r)
                    if state and (r['headers'].get('if-none-match')=='*' or r['headers'].get('if-match')!=f'"v{version}"'):return 412,{},b''
                    version+=1;state['text']=r['body'];return 201,{'etag':f'"v{version}"'},b''
                if r['method']=='REPORT':
                    self_check=b'time-range' not in r['body']
                    if not self_check:raise AssertionError('unsupported time filter advertised')
                    xml=f'<D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav"><D:response><D:href>/{path}</D:href><D:propstat><D:prop><D:getetag>"v{version}"</D:getetag><C:calendar-data>{escape(state["text"].decode())}</C:calendar-data></D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response></D:multistatus>'
                    return 207,{'content-type':'application/xml'},xml.encode()
                return 200,{'content-type':'text/calendar'},state['text']
        e=Engine(d,Receiver(),{'runId':'typed-calendar'});run_scenario(e)
        self.assertEqual(version,2)
        self.assertIn(b'SUMMARY:Revised calendar event',state['text'])
        with self.assertRaises(Refusal):
            e.call('event.update',{'calendar':'typed-calendar','event':'typed-event','startUtc':'20261101T120000Z','endUtc':'20261101T150000Z','stampUtc':'20261028T000000Z','summary':'Stale update','etag':'"v1"'})
        self.assertEqual(version,2)
        self.assertEqual(len(puts),3)
        self.assertEqual(set(d['operations']['event.list']['input']['properties']),{'calendar'})

if __name__=='__main__':unittest.main()
