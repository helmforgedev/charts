// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
export async function verifyMetrics({k,forward,values,namespace,deployment,readSecret}){
 const ref=deployment.spec.template.spec.containers.find(c=>c.name==='opencloud').env.find(e=>e.name==='PROXY_DEBUG_TOKEN').valueFrom.secretKeyRef;
 const token=Buffer.from(readSecret(ref.name)[ref.key],'base64').toString();assert.ok(token.length>=16);
 await forward(async base=>{
  for(const credential of [undefined,'invalid-owned-fixture']){const response=await fetch(base+'/metrics',{headers:credential?{Authorization:'Bearer '+credential}:{}});assert.equal(response.status,401);}
  for(const path of ['/config','/healthz','/debug/pprof/','/metrics?config=1']){const response=await fetch(base+path,{headers:{Authorization:'Bearer '+token}});assert.equal(response.status,404);}
  assert.equal((await fetch(base+'/metrics',{method:'POST',headers:{Authorization:'Bearer '+token}})).status,405);
  const response=await fetch(base+'/metrics',{headers:{Authorization:'Bearer '+token}});assert.equal(response.status,200);const body=await response.text();assert.match(body,/^# HELP /m);assert.match(body,/^# TYPE /m);
  assert.match(body,/^opencloud_proxy_requests_total(?:\{| )/m);assert.match(body,/^opencloud_proxy_build_info(?:\{| )/m);
  console.log('PASS authenticated native OpenCloud metrics; missing/wrong bearer denied, configuration/debug routes blocked');
 },values.metrics.port);
 if(values.metrics.serviceMonitor.enabled){
  k(['rollout','status','statefulset/prometheus-opencloud-monitor','--timeout=90s']);
  await forward(async base=>{
   let result=[];const deadline=Date.now()+45000;
   while(Date.now()<deadline){const response=await fetch(base+'/api/v1/query?query='+encodeURIComponent('up{namespace="'+namespace+'",endpoint="metrics"}'));assert.equal(response.status,200);result=(await response.json()).data.result;if(result.length&&result.every(row=>row.value[1]==='1'))break;await new Promise(r=>setTimeout(r,1500));}
   assert.ok(result.length&&result.every(row=>row.value[1]==='1'),'Real Prometheus must scrape with Secret bearer credentials');
   const response=await fetch(base+'/api/v1/rules');assert.equal(response.status,200);assert.ok((await response.json()).data.groups.some(g=>g.rules.some(r=>r.name==='OpenCloudMetricsUnavailable')));
   console.log('PASS real Prometheus ServiceMonitor up=1 and loaded OpenCloudMetricsUnavailable rule');
  },9090,'service/opencloud-monitor');
 }
}
