"""Protocol composition regressions: independent response-bound token and body checks."""
import copy
import json
import unittest
from email import policy
from email.parser import BytesParser
from urllib.parse import parse_qs
from binding import Engine, Refusal, check_declaration, decode_http, encode_http, load, tools

class Composition(unittest.TestCase):
    def test_text_and_json_lines_decode(self):
        d=load('gogs'); op=copy.deepcopy(d['operations']['user.read'])
        op['binding']['decode']='text'
        self.assertEqual(decode_http(d,op,(200,{},b'hello\n')), 'hello\n')
        op['binding']['decode']='json-lines'
        self.assertEqual(decode_http(d,op,(200,{},b'{"id":1}\n\n{"id":2}\n')), [{'id':1},{'id':2}])

    def test_internal_token_preparation_is_not_a_tool(self):
        d=load('gogs'); token=copy.deepcopy(d['operations']['user.read'])
        token.update(internal=True, output={'type':'object'})
        token['binding']['path']=['token']
        edit=copy.deepcopy(d['operations']['repo.create'])
        edit.update(input={'type':'object'},output={'type':'object'},prepare=[{'id':'csrf','op':'token.read','args':{}}])
        edit['binding'].pop('json'); edit['binding'].update(path=['edit'],status=[200],form={'token':{'result':['csrf','token']},'text':{'arg':'text'}})
        d['operations']={'token.read':token,'edit':edit}; d['qualification']=[]
        check_declaration(d)
        self.assertEqual(len(tools(d)),1)
        class Receiver:
            def http(self,r):
                if r['path']=='token': return 200,{'content-type':'application/json'},b'{"token":"s&cret"}'
                assert parse_qs(r['body'].decode())=={'token':['s&cret'],'text':['a + b']}
                assert r['redact'] is True
                return 200,{'content-type':'application/json'},b'{"ok":true}'
        self.assertEqual(Engine(d,Receiver(),{}).call('edit',{'text':'a + b'}),{'ok':True})
        d['operations']['token.read']['prepare']=[{'id':'bad','op':'edit','args':{}}]
        with self.assertRaises(Refusal): check_declaration(d)

    def test_multipart_exact_binary_and_text(self):
        d=load('davros'); op=copy.deepcopy(d['operations']['file.put'])
        op['binding'].pop('base64'); op['binding']['multipart']=[{'name':'file','filename':'test.bin','contentType':'application/octet-stream','base64':{'arg':'bytes'}},{'name':'title','text':{'arg':'title'}}]
        r=encode_http(d,op,{'path':'a','bytes':'AP8=','title':'one\ntwo'}, {})
        parsed=BytesParser(policy=policy.default).parsebytes(('Content-Type: '+r['headers']['content-type']+'\r\n\r\n').encode()+r['body'])
        parts=list(parsed.iter_parts()); self.assertEqual(parts[0].get_payload(decode=True),b'\0\xff'); self.assertEqual(parts[1].get_payload(decode=True),b'one\ntwo')
        self.assertEqual(parts[0].get_filename(),'test.bin')
        op['binding']['multipart'][0]['filename']='bad\r\nHeader: injected'
        with self.assertRaisesRegex(Refusal,'multipart'): encode_http(d,op,{'path':'a','bytes':'AP8=','title':'t'}, {})

if __name__=='__main__': unittest.main()
