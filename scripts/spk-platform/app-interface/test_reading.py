"""Pinned reading-app protocol fixtures; no claim of live package qualification."""
import json
import unittest
from binding import Engine,Refusal,load,run_scenario,tools

class ReadingInterface(unittest.TestCase):
    def test_ttrss_internal_session_and_owned_annotation(self):
        d=load('ttrss');articles={};sessions=set();count=0;writes=[]
        class Receiver:
            def http(self,r):
                nonlocal count
                q=json.loads(r['body']);op=q['op']
                if op=='login':
                    self_check=q['user']=='admin' and q['password']==''
                    if not self_check:raise AssertionError('wrong single-user contract')
                    count+=1;sid='session-'+str(count);sessions.add(sid);v={'session_id':sid,'api_level':18}
                else:
                    if q['sid'] not in sessions:raise AssertionError('session result binding lost')
                    if op=='shareToPublished':
                        writes.append(op);articles[42]={'id':42,'title':q['title'],'link':q['url'],'content':q['content'],'note':None};v={'status':'OK'}
                    elif op=='getHeadlines':
                        matches=[a for a in articles.values() if q['search'] in a['title']]
                        v=matches[q['skip']:q['skip']+q['limit']]
                    elif op=='getArticle':v=[articles[q['article_id']]] if q['article_id'] in articles else []
                    elif op=='updateArticle':
                        writes.append(op);a=articles[q['article_ids']];a['note']=q['data'];v={'status':'OK','updated':1}
                    else:raise AssertionError('undeclared method')
                return 200,{'content-type':'text/json'},json.dumps({'seq':1,'status':0,'content':v}).encode()
        e=Engine(d,Receiver(),{'runId':'typed-reading'});run_scenario(e)
        self.assertEqual(articles[42]['note'],'Typed annotation')
        self.assertEqual(writes,['shareToPublished','updateArticle'])
        self.assertEqual(e.call('article.list',{'feed':-2,'limit':20,'offset':20,'search':'typed-reading','view':'all_articles'})['content'],[])
        with self.assertRaises(Refusal):e.call('article.note.update',{'article':999,'note':'foreign'})
        self.assertEqual(writes,['shareToPublished','updateArticle'])
        self.assertNotIn('mini_ttrss_session_open',[t['name'] for t in tools(d)])
        self.assertGreaterEqual(count,6)

class LinkDirectory(unittest.TestCase):
    def test_link_append_preserves_human_sheet_and_quotes(self):
        import csv,io
        d=load('linksholder');rows=[['#','Existing directory','','']]
        class Receiver:
            def http(self,r):
                if r['method']=='POST':
                    if r['path']!='_/sheet1':raise AssertionError('wrong human directory')
                    rows.extend(list(csv.reader(io.StringIO(r['body'].decode(),newline=''))))
                    return 202,{'content-type':'application/json'},b'{"command":[]}'
                if r['path']!='_/sheet1/csv.json':raise AssertionError('wrong read directory')
                return 200,{'content-type':'application/json'},json.dumps(rows).encode()
        run_scenario(Engine(d,Receiver(),{'runId':'typed-link'}))
        self.assertEqual(rows[0],['#','Existing directory','',''])
        self.assertEqual(rows[1],['https://example.invalid/typed-link','Typed, quoted "link" typed-link','',''])

if __name__=='__main__':unittest.main()
