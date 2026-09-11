// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {execFileSync, spawn} from 'node:child_process';
import {chromium} from 'playwright';
import {PDFDocument} from 'pdf-lib';
const [context, namespace, release] = process.argv.slice(2);
assert.match(context ?? '', /^k3d-/);
assert.ok(namespace && release);
const k = args => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {encoding:'utf8',timeout:90000});
const values = JSON.parse(execFileSync('helm',['get','values',release,'-n',namespace,'--kube-context',context,'-a','-o','json'],{encoding:'utf8'}));
const deployment=JSON.parse(k(['get','deploy','-l',`app.kubernetes.io/instance=${release},app.kubernetes.io/name=bentopdf`,'-o','json'])).items[0];
assert.ok(deployment);
async function forward(resource, remote, action) {
 const child=spawn('kubectl',['--context',context,'-n',namespace,'port-forward',resource,`:${remote}`,'--address=127.0.0.1'],{windowsHide:true,stdio:['ignore','pipe','pipe']});
 let output=''; for(const stream of [child.stdout,child.stderr])stream.on('data',b=>output+=b);
 try {
  const until=Date.now()+20000;
  while(!/127\.0\.0\.1:(\d+) ->/.test(output)&&Date.now()<until&&child.exitCode===null)await new Promise(r=>setTimeout(r,100));
  const port=output.match(/127\.0\.0\.1:(\d+) ->/)?.[1];assert.ok(port,'Port forward unavailable');
  await action(`http://127.0.0.1:${port}`);
 } finally {
  if(process.platform==='win32'&&child.exitCode===null){
   try{execFileSync('taskkill',['/PID',String(child.pid),'/T','/F'],{stdio:'ignore'});}
   catch(error){let gone=false;try{process.kill(child.pid,0);}catch(e){if(e.code==='ESRCH')gone=true;else throw e;}if(!gone)throw error;}
  }else child.kill();
 }
}
const request=url=>fetch(url,{signal:AbortSignal.timeout(10000)});
const pods=()=>JSON.parse(k(['get','pods','-l',`app.kubernetes.io/instance=${release},app.kubernetes.io/name=bentopdf`,'-o','json'])).items.filter(p=>!p.metadata.deletionTimestamp);
async function check(base){
 const response=await request(base+'/');assert.equal(response.status,200);
 assert.equal(response.headers.get('cross-origin-opener-policy'),'same-origin');
 assert.ok(response.headers.get('cross-origin-embedder-policy'));
 assert.ok(response.headers.get('content-security-policy'));
 assert.deepEqual(await(await request(base+'/config.json')).json(),values.config);
 assert.equal((await request(base+'/stub_status')).status,404,'Status must not be exposed on the public port');
}
for(const pod of pods())await forward('pod/'+pod.metadata.name,values.server.port,check);
const browser=await chromium.launch({headless:true});
try{
 await forward('pod/'+pods()[0].metadata.name,values.server.port,async base=>{
  const page=await browser.newPage({acceptDownloads:true,locale:'en-US'});const uploads=[];const errors=[];
  page.on('request',r=>{if(r.url().startsWith(base)&&['POST','PUT','PATCH'].includes(r.method()))uploads.push(r.url());});
  page.on('pageerror',e=>errors.push(e.message)); page.on('requestfailed',r=>console.error('REQUEST FAILED',r.url(),r.failure())); page.on('console',m=>{if(m.type()==='error')console.error('BROWSER CONSOLE',m.text());});
  await page.goto(base+'/merge-pdf',{waitUntil:'networkidle'});
  assert.equal(await page.evaluate(()=>crossOriginIsolated),true,'Browser isolation is required for WASM workflows');
  const files=[];
  for(let n=1;n<=2;n++){const doc=await PDFDocument.create();doc.addPage([300+n*10,400]).drawText('HelmForge fixture '+n,{x:30,y:200});files.push({name:`fixture-${n}.pdf`,mimeType:'application/pdf',buffer:Buffer.from(await doc.save())});}
  await page.locator('#file-input').setInputFiles(files);
  await page.waitForFunction(() => document.querySelectorAll('#file-list > [data-file-name]').length === 2);
  await page.locator('#process-btn').waitFor({state:'visible'});
  const download=page.waitForEvent('download',{timeout:60000});
  await page.locator('#process-btn').click();
  let item; try { item=await download; } catch(error) { console.error('BROWSER DIAGNOSTIC', await page.locator('body').innerText(), errors); throw error; }const bytes=await fs.readFile(await item.path());const merged=await PDFDocument.load(bytes);
  assert.equal(merged.getPageCount(),2);assert.deepEqual(merged.getPages().map(p=>p.getWidth()),[310,320]);
  assert.deepEqual(uploads,[],'PDF workflow must not upload data to the application server');
  assert.deepEqual(errors,[],'Browser runtime errors');
  for(const tool of values.config.disabledTools){
   await page.goto(base+'/'+tool,{waitUntil:'networkidle'});
   await page.locator('.ph-prohibit').waitFor({state:'visible'});
   assert.equal(await page.locator('#file-input').count(),0,'Disabled tool UI must be removed');
  }
  await page.close();
 });
}finally{await browser.close();}
if(values.metrics.enabled){
 await forward('pod/'+pods()[0].metadata.name,values.metrics.port,async base=>{
  const response=await request(base+'/metrics');assert.equal(response.status,200);const body=await response.text();assert.match(body,/nginx_up 1/);assert.match(body,/nginx_http_requests_total /);
 });
 if(values.metrics.serviceMonitor.enabled){
  k(['rollout','status','statefulset/prometheus-bentopdf-monitor','--timeout=90s']);
  await forward('service/bentopdf-monitor',9090,async base=>{
   const deadline=Date.now()+45000;let result=[];
   do{const data=await(await request(base+'/api/v1/query?query='+encodeURIComponent('nginx_up{namespace="'+namespace+'"}'))).json();result=data.data?.result??[];if(result.length&&result.every(x=>x.value[1]==='1'))break;await new Promise(r=>setTimeout(r,2000));}while(Date.now()<deadline);
   assert.ok(result.length);assert.ok(result.every(x=>x.value[1]==='1'),'Real Prometheus must scrape NGINX');
   if(values.metrics.prometheusRule.enabled){const data=await(await request(base+'/api/v1/rules')).json();assert.ok(data.data.groups.some(g=>g.rules.some(r=>r.name==='BentoPDFNginxUnavailable')));}
  });
 }
}
if(values.autoscaling.enabled){
 const deadline=Date.now()+90000;let hpa;
 do{hpa=JSON.parse(k(['get','hpa',deployment.metadata.name,'-o','json']));if(hpa.status?.currentMetrics?.some(m=>m.containerResource?.current?.averageUtilization!==undefined))break;await new Promise(r=>setTimeout(r,2000));}while(Date.now()<deadline);
 assert.ok(hpa.status.currentMetrics.some(m=>m.containerResource?.current?.averageUtilization!==undefined),'HPA requires real CPU metrics');
 assert.ok(hpa.status.currentReplicas>=values.autoscaling.minReplicas);
}
k(['rollout','restart','deployment/'+deployment.metadata.name]);k(['rollout','status','deployment/'+deployment.metadata.name,'--timeout=90s']);
for(const pod of pods())await forward('pod/'+pod.metadata.name,values.server.port,check);
console.log('PASS browser PDF merge and parsed download, no application uploads, isolation headers, runtime config, private stub_status, rollout'+(values.metrics.enabled?', NGINX exporter':'')+(values.metrics.serviceMonitor.enabled?', actual Prometheus scrape':''));
