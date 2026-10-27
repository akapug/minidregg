"""Run actual small Rust helpers extracted from the reviewed source; no Host/server.
The only substituted effects are member/entries access and deterministic nonce creation.
"""
from pathlib import Path
import subprocess, json, argparse
root=Path(__file__).resolve().parents[3]
out=root/'scratch/semantic-repro';out.mkdir(exist_ok=True)
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--deps',type=Path,required=True,help='Existing compatible Rust dependency directory; this script never builds dependencies')
args=parser.parse_args()
deps=args.deps
def function(path,name):
    text=(root/path).read_text()
    import re
    hit=re.search(r'^(?:pub(?:\([^\n]*\))?\s+)?fn '+name+r'(?:\b|<)',text,re.M)
    if hit is None: raise RuntimeError(f'missing {name}')
    return text[hit.start():text.index('\n}',hit.start())+2]
def block(path,name):return function('native/resource-client/src/'+path,name)
header='''extern crate self as mini_sdk;
use serde_json::{json,Value};
use crate::html::escape;
type Result<T> = std::result::Result<T,String>;
#[allow(non_snake_case)] fn Error(s:String)->String{s}
fn member<'a>(v:&'a Value,k:&str)->Result<&'a str>{v[k].as_str().ok_or_else(||format!("missing {k}"))}
fn entries(v:&Value)->Result<&Vec<Value>>{v["cell"]["entries"].as_array().ok_or_else(||"missing entries".into())}
fn random_nonce()->Result<String>{Ok("777".into())}
'''
code=header
code+='pub mod decimal {\n'+ '\n'.join(function('native/mini-sdk/src/decimal.rs',n) for n in ['is_digits','is_canonical','is_canonical_max','is_canonical_signed_max'])+'\n}\n'
code+='pub mod hex {use crate::{Error,Result};\n'+function('native/mini-sdk/src/hex.rs','decode')+'\n}\n'
code+='mod html {\n'+block('render/html.rs','escape')+'\n}\n'
code+='mod text {\n'+block('render/text.rs','one_line')+'\n}\n'
code+='#[path = '+json.dumps(str(root/'native/resource-client/src/render/history.rs'))+'] mod history;\n'
for path,names in [('workspace.rs',['decimal','signed_decimal','live_lines','line_atoms','scalar_actions']),('web_actions.rs',['transclusion']),('web.rs',['render_fields'])]:
    code+='\n'.join(block(path,n) for n in names)+'\n'
code+=r'''
fn main(){
 let doc=json!({"order":[{"kind":"atom","atom":"11","struck":false},{"kind":"atom","atom":"33","struck":false},{"kind":"atom","atom":"22","struck":false}]});
 let selected=line_atoms(&doc,"source",1,2).unwrap();
 let view=json!({"cell":{"entries":[{"type":"run","id":"90","atoms":["11","22","33"]},{"type":"atom","id":"11","document":"7","revision":"101","tombstonedAt":null},{"type":"atom","id":"22","document":"7","revision":"102","tombstonedAt":null},{"type":"atom","id":"33","document":"7","revision":"103","tombstonedAt":null}]}});
 assert_eq!(selected,["11","33"]);
 for mode in ["snapshot","live"] {
  let lowered=transclusion("7",&view,&selected,&json!({"mode":mode,"death":"invalidate"})).unwrap();
  let quoted:Vec<_>=lowered["request"]["pins"].as_array().unwrap().iter().map(|p|p["atom"].as_str().unwrap()).collect();
  assert_eq!(quoted,["11","22","33"]);
  println!("R1 {mode}: selected={selected:?}; quoted={quoted:?}");
 }
 let removed=json!({"order":[{"kind":"atom","atom":"11","struck":false},{"kind":"atom","atom":"33","struck":false}]});
 let visible=line_atoms(&removed,"source",1,2).unwrap();
 let lowered=transclusion("7",&view,&visible,&json!({"mode":"snapshot","death":"invalidate"})).unwrap();
 assert_eq!(lowered["request"]["pins"].as_array().unwrap().len(),3);
 println!("R1 detached middle atom: visible={visible:?}; quoted=3 atoms");
 let field="340282366920938463463374607431768211456";
 let actions=json!([{"type":"create","key":{"type":"object","field":field},"value":"7"}]);
 let lowered=scalar_actions(&actions,"9").unwrap();assert_eq!(lowered["actions"][0]["key"]["field"],field);
 let rows=vec![json!({"key":{"type":"object","resource":"9","field":field},"value":"7"})];
 let html=render_fields(&rows,false);assert!(html.contains("data-fields=\"0\""));assert!(!html.contains(field));
 println!("R2 scalar field accepted={field}; visible fields=0");
 // Host lineValueJson omits the atom kind and uses AtomRecord.bodyBytes.
 // The same presentation is therefore produced for plaintext, inline object
 // bytes and ciphertext. Test the actual final history formatter.
 let change=json!({"type":"added","element":"11","after":{"kind":"atom","atom":"11","payload":"63697068657274657874","revision":"101","struck":false}});
 let rendered=history::change_line(&change);assert_eq!(rendered, r#"+ 11 "ciphertext""#);
 println!("R3 history body={rendered}");
}
'''
source=out/'repro.rs';source.write_text(code)
rlib=next(deps.glob('libserde_json-*.rlib'))
cmd=['rustc','--edition=2021',str(source),'--extern',f'serde_json={rlib}','-L',f'dependency={deps}','-o',str(out/'repro')]
p=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True);(out/'rustc.pid').write_text(str(p.pid));stdout,stderr=p.communicate();(out/'rustc.log').write_text(stdout+stderr)
if p.returncode:print(stderr);raise SystemExit(p.returncode)
p=subprocess.Popen([str(out/'repro')],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True);(out/'run.pid').write_text(str(p.pid));stdout,stderr=p.communicate();(out/'run.log').write_text(stdout+stderr);print(stdout+stderr,end='');raise SystemExit(p.returncode)
