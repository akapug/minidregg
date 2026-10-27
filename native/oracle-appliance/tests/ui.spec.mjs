// Browser contract fixture only; does not establish hosted Mini tenancy or Oracle correctness.
export async function checkOracleUi(page, html) {
  let checks=0;
  const assert = (value, label) => { checks++; if (!value) throw new Error(label); };
  const requests = [], errors = [];
  let queries=0, invokes=0;
  const live={id:'specialist.units.answer',name:'Units',description:'Length conversions',availability:'live_direct',input_schema:{type:'object',properties:{text:{type:'string'}},required:['text']},examples:[{arguments:{text:'Convert 5 miles to km.'},source:'declared; not measured'}],limitations:['Direct call bypasses global guards.']};
  const textOnly={id:'head.explain',name:'Explain a topic',availability:'text_only',input_schema:{type:'object'},examples:[]};
  const unavailable={id:'missing.operation',name:'Unavailable fixture',availability:'unavailable',input_schema:{type:'object'},examples:[]};
  page.on('pageerror', error => errors.push(error.message));
  await page.unrouteAll({behavior:'wait'});
  await page.route('http://oracle-ui.test/**',async route=>{
    const req=route.request(), url=new URL(req.url());
    if(url.pathname==='/') return route.fulfill({contentType:'text/html',body:html});
    requests.push({method:req.method(),path:url.pathname,query:url.search,body:req.postData(),headers:req.headers()});
    const reply=(data,status=200,headers={})=>route.fulfill({status,contentType:'application/json',headers,body:JSON.stringify(data)});
    if(url.pathname==='/query') {
      queries++;
      if(queries===1) return route.abort('failed');
      if(queries===2) return reply({outcome:'error',error:'bridge_busy',state_may_have_changed:false},400,{'x-sandstorm-app-http-status':'429'});
      if(queries===3) return reply({outcome:'completed',reply:{status:'withheld',response:'<img src=x onerror="window.injected=true"> Cannot convert length to mass.',path:'units>mismatch',references:['fixture'],provenance:{limitation:'No cross-dimension conversion'}}});
      if(queries===4) return reply({outcome:'error',error:'conversation_reset_required',executed:false,fresh_conversation_required:true},409);
      return reply({outcome:'completed',reply:{status:'answered',response:'391.',path:'compute'}});
    }
    if(url.pathname==='/operations') return reply({operations:url.searchParams.get('offset')==='2'?[unavailable]:[live,textOnly],total:3,next_offset:url.searchParams.get('offset')==='2'?null:2});
    if(url.pathname.startsWith('/operations/')) return reply([live,textOnly,unavailable].find(x=>x.id===url.pathname.split('/').pop()));
    if(url.pathname==='/invoke') {
      invokes++;
      if(invokes===1) return reply({outcome:'error',error:'backend_timeout',state_may_have_changed:true,retryable:false},504);
      return route.fulfill({contentType:'application/json',body:'{"outcome":"completed","reply":{"status":"answered","result":9007199254740993,"evidence":"fixture"}}'});
    }
    return reply({error:'unexpected_route'},404);
  });
  await page.setViewportSize({width:1100,height:900});
  await page.goto('http://oracle-ui.test/');
  assert(requests.length===0,'page must not query on load');
  const originalConversation=await page.locator('#conversation').inputValue();
  await page.locator('#question').fill('Convert 5 miles to kilograms.');
  await page.locator('#ask').click();
  await page.locator('#write-notice').filter({hasText:'No conclusive reply'}).waitFor();
  assert(await page.locator('#ask').isDisabled(),'uncertain delivery must block new query');
  assert(await page.locator('#conversation').isDisabled(),'pending conversation must be frozen');
  await page.locator('#question').fill('Changed draft must not change retry');
  await page.getByRole('button',{name:'Retry exact request',exact:true}).click();
  await page.locator('#write-notice').filter({hasText:'Oracle is busy'}).waitFor();
  assert(await page.getByRole('button',{name:'Retry exact request',exact:true}).isVisible(),'forwarded 429 must retain retry');
  await page.getByRole('button',{name:'Retry exact request',exact:true}).click();
  await page.locator('#history .notice').first().filter({hasText:'Oracle status: withheld'}).waitFor();
  assert(queries===3,'no automatic retries');
  assert(requests.filter(r=>r.path==='/query').every(r=>r.body===requests[0].body),'query retry must retain exact bytes including ID');
  assert(await page.locator('#history img').count()===0,'answer must not inject HTML');
  assert((await page.locator('#history').textContent()).includes('<img src=x'),'answer text must remain complete');
  assert(await page.locator('#history summary').filter({hasText:'full evidence'}).count()===2,'busy and completed evidence must both survive');
  assert(!await page.locator('#ask').isDisabled(),'resolved reply should unlock new request');
  await page.locator('#ask').click();
  await page.locator('#write-notice').filter({hasText:'must be restarted'}).waitFor();
  assert(await page.locator('#ask').isDisabled(),'reset_required must block submit');
  await page.locator('#new-conversation').click();
  const newConversation=await page.locator('#conversation').inputValue();
  assert(newConversation!==originalConversation,'new conversation requires fresh ID');
  assert(queries===4,'starting conversation must not resubmit');
  await page.locator('#question').fill('What is 17 times 23?');
  await page.locator('#ask').click();
  await page.locator('#history .notice').first().filter({hasText:'Oracle status: answered'}).waitFor();
  assert(JSON.parse(requests.filter(r=>r.path==='/query').at(-1).body).conversation_id===newConversation,'new query must use selected conversation');
  await page.locator('#search').fill('units & conversion');
  await page.locator('#search-button').click();
  await page.locator('#catalog-notice').filter({hasText:'2 shown of 3'}).waitFor();
  assert(new URLSearchParams(requests.at(-1).query).get('q')==='units & conversion','search must encode user text');
  await page.locator('#more').click();
  await page.locator('#catalog-notice').filter({hasText:'3 shown of 3'}).waitFor();
  assert(!await page.locator('#more').isVisible(),'last page must hide pagination');
  await page.getByRole('button',{name:'Units',exact:true}).click();
  await page.locator('#operation-name').filter({hasText:'Units'}).waitFor();
  await page.getByRole('button',{name:'Load example 1',exact:true}).click();
  assert(invokes===0,'loading operation example must not execute it');
  assert((await page.locator('#arguments').inputValue()).includes('Convert 5 miles'),'example loads arguments');
  await page.locator('#arguments').fill('{"number":9007199254740993,"decimal":1.2300}');
  await page.locator('#invoke').click();
  await page.locator('#write-notice').filter({hasText:'request is unresolved'}).waitFor();
  await page.locator('#arguments').fill('{"number":2}');
  await page.getByRole('button',{name:'Retry exact request',exact:true}).click();
  await page.locator('#history .notice').first().filter({hasText:'Oracle status: answered'}).waitFor();
  const posts=requests.filter(r=>r.path==='/invoke');
  assert(posts.length===2 && posts[0].body===posts[1].body,'invoke retry must retain exact bytes');
  assert(posts[0].body.includes('9007199254740993') && posts[0].body.includes('1.2300'),'argument numbers must not be rounded or reformatted');
  assert((await page.locator('#history article').first().textContent()).includes('"result":9007199254740993'),'full raw result must retain integer precision');
  assert((await page.locator('#history article').first().locator('.answer').textContent()).includes('9007199254740993'),'primary structured result must retain integer precision');
  await page.getByRole('button',{name:'Explain a topic',exact:true}).click();
  await page.locator('#operation-name').filter({hasText:'Explain a topic'}).waitFor();
  assert(await page.locator('#invoke').isDisabled(),'text-only operation must not invoke');
  await page.getByRole('button',{name:'Unavailable fixture',exact:true}).click();
  await page.locator('#operation-name').filter({hasText:'Unavailable fixture'}).waitFor();
  assert(await page.locator('#invoke').isDisabled(),'unavailable operation must not invoke');
  assert(requests.every(r=>!Object.keys(r.headers).some(k=>k.toLowerCase().includes('tenant'))),'browser must not select or transmit a tenant');
  assert(errors.length===0,'unexpected browser script errors: '+errors.join('; '));
  await page.setViewportSize({width:390,height:844});
  assert(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),'mobile layout must not overflow horizontally');
  return {checks,queryAttempts:queries,invokeAttempts:invokes,requests:requests.length,consoleErrors:errors,mobileWidth:390};
}

// Run independently with: node native/oracle-appliance/tests/ui.spec.mjs --size
export async function checkOracleRequestSize(page, html) {
  let checks=0;
  const assert=(value,label)=>{checks++;if(!value)throw new Error(label);};
  const sent=[];
  await page.unrouteAll({behavior:'wait'});
  await page.route('http://oracle-ui.test/**',async route=>{
    if(new URL(route.request().url()).pathname==='/') return route.fulfill({contentType:'text/html',body:html});
    if(route.request().method()!=='POST' || new URL(route.request().url()).pathname!=='/query') return route.fulfill({status:404,body:''});
    sent.push(route.request().postData());
    return route.fulfill({status:sent.length===1?413:200,contentType:'application/json',body:JSON.stringify(sent.length===1?{outcome:'error',error:'request_too_large',state_may_have_changed:false}:{outcome:'completed',reply:{status:'answered',response:'Size fixture only.'}})});
  });
  await page.goto('http://oracle-ui.test/');
  assert(sent.length===0,'size policy must not trigger a startup request');
  await page.locator('#question').fill('x'.repeat(20000));
  await page.locator('#ask').click();
  await page.locator('#write-notice').filter({hasText:'Request error (413)'}).waitFor();
  assert(sent.length===1,'request above 16 KiB must reach adapter');
  assert(!await page.locator('#ask').isDisabled(),'adapter smaller-bound rejection must unlock inputs');
  const conversation_id=await page.locator('#conversation').inputValue();
  const overhead=new TextEncoder().encode(JSON.stringify({request_id:'request-'+'0'.repeat(32),conversation_id,text:''})).length;
  const text='é'+'x'.repeat(65536-overhead-2);
  await page.locator('#question').fill(text);await page.locator('#ask').click();
  await page.locator('#history .notice').first().filter({hasText:'Oracle status: answered'}).waitFor();
  assert(new TextEncoder().encode(sent[1]).length===65536,'exact 64 KiB UTF-8 request must be sent');
  await page.locator('#question').fill(text+'x');await page.locator('#ask').click();
  await page.locator('#write-notice').filter({hasText:'64 KiB limit'}).waitFor();
  assert(sent.length===2,'request one byte above profile bound must stay local');
  return {checks,requestBytes:sent.map(body=>new TextEncoder().encode(body).length)};
}

// Standalone runner: use an already-installed Playwright; no package download.
// node native/oracle-appliance/tests/ui.spec.mjs
// ORACLE_PLAYWRIGHT_MODULE can name an existing absolute Playwright package path.
if (typeof process !== 'undefined' && process.argv[1]) {
  const {fileURLToPath} = await import('node:url');
  const {resolve} = await import('node:path');
  if (resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
    const {readFile} = await import('node:fs/promises');
    const {createRequire} = await import('node:module');
    const {chromium} = createRequire(import.meta.url)(process.env.ORACLE_PLAYWRIGHT_MODULE || 'playwright');
    const browser = await chromium.launch({headless:true});
    try {
      const page = await browser.newPage();
      const html = await readFile(new URL('../src/index.html', import.meta.url),'utf8');
      console.log(JSON.stringify(await (process.argv.includes('--size')?checkOracleRequestSize:checkOracleUi)(page,html)));
    } finally { await browser.close(); }
  }
}
