"""Generic CSV expression and heterogeneous JSON membership contracts."""
import unittest
from binding import Refusal,resolve,run_scenario,load,check_declaration

class CSVExpression(unittest.TestCase):
    def test_rfc4180_exact_bytes_and_nested_argument(self):
        value=resolve({'csv':[[{'arg':'url'},{'arg':'title'},'','plain']]},{'url':'https://example.invalid/a,b','title':'A "quote"\nnext line'},{})
        self.assertEqual(value,'"https://example.invalid/a,b","A ""quote""\nnext line",,plain\r\n')
        self.assertEqual(resolve({'csv':[]},{},{}),'')
        for bad in ['text',[1],[[None]],[[1]],[[{}]]]:
            with self.subTest(bad=bad),self.assertRaises(Refusal):resolve({'csv':bad},{},{})

    def test_csv_expression_schema_is_closed(self):
        d=load('gogs'); b=d['operations']['repo.create']['binding']
        b.pop('json'); b['text']={'csv':[['a']]}
        check_declaration(d)
        b['text']['extra']=True
        with self.assertRaises(Refusal):check_declaration(d)

    def test_contains_json_value_or_object_subset(self):
        class E:
            context={}
            d={'name':'test','qualification':[{'id':'read','op':'read','args':{},'assert':[{'contains':['url','title','','']}]}]}
            value=[['url','title','','']]
            def tool_call(self,*args):return {'structuredContent':{'value':self.value}}
        e=E();run_scenario(e)
        e.d['qualification'][0]['assert']=[{'contains':{'id':'owned'}}]
        e.value=[None,'wrong',{'id':'owned','extra':True}];run_scenario(e)
        e.value=[None,'wrong',[]]
        with self.assertRaises(Refusal):run_scenario(e)
        e.d['qualification'][0]['assert']=[{'contains':True}]
        e.value=[1]
        with self.assertRaises(Refusal):run_scenario(e)

if __name__=='__main__':unittest.main()
