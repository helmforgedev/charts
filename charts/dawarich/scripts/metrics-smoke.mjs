// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));

export async function verifyMetrics({k,forward,values,namespace,context,deployment}) {
 const name=deployment.metadata.name;
 const authName=deployment.spec.template.spec.containers[0].env.find(item=>item.name==='METRICS_PASSWORD').valueFrom.secretKeyRef.name;
 const secret=JSON.parse(k(['get','secret',authName,'-o','json'])).data;
 const username=Buffer.from(secret[values.metrics.auth.usernameKey],'base64').toString();
 const password=Buffer.from(secret[values.metrics.auth.passwordKey],'base64').toString();
 const authorization='Basic '+Buffer.from(username+':'+password).toString('base64');
 for(const [port,kind] of [[values.metrics.port,'web'],[9394,'worker']]) await forward(async base=>{
  assert.equal((await fetch(base+'/metrics')).status,401,'Native metrics must require authentication');
  assert.equal((await fetch(base+'/metrics',{headers:{Authorization:'Basic '+Buffer.from(username+':incorrect-owned-fixture').toString('base64')}})).status,401);
  const response=await fetch(base+'/metrics',{headers:{Authorization:authorization}});assert.equal(response.status,200);
  const body=await response.text();const families=[...body.matchAll(/^# TYPE (\S+) /gm)].map(match=>match[1]);
  assert.ok(families.some(family=>family.startsWith('sidekiq_')),'Native worker metrics missing');
  assert.ok(body.split('\n').some(line=>line.startsWith('sidekiq_jobs_success_total{')&&line.includes('queue="imports"')&&Number(line.split('} ')[1])>0),'Successful native import job counter missing');
  if(kind==='web'){
   assert.ok(families.some(family=>family.startsWith('rails_')),'Native Rails metrics missing');
   assert.equal((await fetch(base+'/api/v1/health',{headers:{Authorization:authorization}})).status,404,'Private proxy must expose only metrics');
  }
  console.log('PASS authenticated native '+kind+' metrics ('+families.length+' families), including successful Sidekiq imports');
 },port);
 if(name==='dawarich-metrics') {
  const probeName='dawarich-metrics-denied';
  const code=`const delay=ms=>new Promise(r=>setTimeout(r,ms));async function control(){const end=Date.now()+20000;while(Date.now()<end){try{if((await fetch('http://${name}:${values.service.port}/api/v1/health',{signal:AbortSignal.timeout(3000)})).ok)return;}catch{}await delay(500);}throw Error('Positive application control failed');}await control();for(const port of [${values.metrics.port},9394])for(let n=0;n<2;n++){let connected=false;try{await fetch('http://${name}-metrics:'+port+'/metrics',{signal:AbortSignal.timeout(3000)});connected=true;}catch{}if(connected)throw Error('Unrelated peer reached metrics port '+port);}await control();console.log('Application reachable; both metrics ports denied');`;
  const probe={apiVersion:'v1',kind:'Pod',metadata:{name:probeName,labels:{'helmforge.dev/runtime-fixture':'true'}},spec:{restartPolicy:'Never',automountServiceAccountToken:false,securityContext:values.podSecurityContext,containers:[{name:'probe',image:values.image.repository+':'+values.image.tag,command:['node','--input-type=module','-e',code],securityContext:values.securityContext,resources:{requests:{cpu:'25m',memory:'64Mi'},limits:{cpu:'500m',memory:'128Mi'}}}]}};
  execFileSync('kubectl',['--context',context,'-n',namespace,'apply','-f','-'],{input:JSON.stringify(probe),encoding:'utf8'});
  try{const end=Date.now()+60000;let phase;while(Date.now()<end){phase=JSON.parse(k(['get','pod',probeName,'-o','json'])).status.phase;if(['Succeeded','Failed'].includes(phase))break;await delay(500);}assert.equal(phase,'Succeeded',k(['logs',probeName]));}finally{k(['delete','pod/'+probeName,'--wait=true','--timeout=30s']);}
  console.log('PASS unrelated peer cannot reach either metrics port while public application remains reachable');
 }
 if(!values.metrics.serviceMonitor.enabled)return;
 await forward(async base=>{
  const end=Date.now()+45000;let results=[];
  while(Date.now()<end){const response=await fetch(base+'/api/v1/query?query='+encodeURIComponent('up{namespace="'+namespace+'",service="'+name+'-metrics"}'));assert.equal(response.status,200);results=(await response.json()).data?.result??[];if(results.length===2&&results.every(row=>row.value[1]==='1'))break;await delay(1500);}
  assert.equal(results.length,2,'Real Prometheus must discover web and worker targets');assert.ok(results.every(row=>row.value[1]==='1'));
  if(values.metrics.prometheusRule.enabled){const response=await fetch(base+'/api/v1/rules');assert.equal(response.status,200);assert.ok((await response.json()).data.groups.some(group=>group.rules.some(rule=>rule.name==='DawarichMetricsUnavailable')));}
  console.log('PASS actual ServiceMonitor basic-auth scrape up=1 for both web and Sidekiq targets, with loaded alert rule');
 },9090,'service/dawarich-monitor');
}
