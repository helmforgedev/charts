// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync,spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const [context,namespace,release]=process.argv.slice(2);
assert.match(context??'',/^k3d-/);assert.ok(namespace&&release);
const kubectl=(args,options={})=>execFileSync('kubectl',['--context',context,'-n',namespace,...args],{encoding:'utf8',timeout:90000,...options});
const values=JSON.parse(execFileSync('helm',['get','values',release,'-n',namespace,'--kube-context',context,'-a','-o','json'],{encoding:'utf8'}));
const selector=`app.kubernetes.io/instance=${release},app.kubernetes.io/name=text-embeddings-inference`;
const deploy=JSON.parse(kubectl(['get','deploy','-l',selector,'-o','json'])).items[0];assert.ok(deploy);
const pods=()=>JSON.parse(kubectl(['get','pods','-l',selector,'-o','json'])).items.filter(p=>!p.metadata.deletionTimestamp);
const apiEnv=deploy.spec.template.spec.containers.find(c=>c.name==='tei').env.find(e=>e.name==='API_KEY');
const secretName=apiEnv?.valueFrom.secretKeyRef.name;
const readKey=()=>secretName?Buffer.from(JSON.parse(kubectl(['get','secret',secretName,'-o','json'])).data[values.auth.secretKey],'base64').toString():'';
const apiKey=readKey();if(values.auth.enabled)assert.ok(apiKey.length>=8);
if(values.externalSecrets.enabled){
 const items=JSON.parse(kubectl(['get','externalsecrets','-o','json'])).items;
 assert.ok(items.length>0);
 for(const item of items){
  kubectl(['wait','externalsecret/'+item.metadata.name,'--for=condition=Ready=True','--timeout=60s']);
  const synced=JSON.parse(kubectl(['get','externalsecret',item.metadata.name,'-o','json']));
  assert.ok(synced.status.conditions.some(c=>c.type==='Ready'&&c.status==='True'&&c.reason==='SecretSynced'));
 }
 console.log('PASS External Secrets Ready and SecretSynced before authenticated inference');
}
const auth=key=>key?{Authorization:'Bearer '+key}:{};
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function forward(resource,port,action){
 const child=spawn('kubectl',['--context',context,'-n',namespace,'port-forward',resource,':'+port,'--address=127.0.0.1'],{windowsHide:true,stdio:['ignore','pipe','pipe']});let output='';for(const s of [child.stdout,child.stderr])s.on('data',b=>output+=b);
 let actionFailed=false;
 try{const deadline=Date.now()+20000;while(!/127\.0\.0\.1:(\d+) ->/.test(output)&&Date.now()<deadline&&child.exitCode===null)await sleep(100);const local=output.match(/127\.0\.0\.1:(\d+) ->/)?.[1];assert.ok(local,'Port-forward unavailable');return await action('http://127.0.0.1:'+local);}
 catch(error){actionFailed=true;throw error;}
 finally{try{if(child.exitCode===null&&child.signalCode===null){if(process.platform==='win32'){try{execFileSync('taskkill',['/PID',String(child.pid),'/T','/F'],{stdio:'ignore'});}catch(error){try{process.kill(child.pid,0);throw error;}catch(probe){if(probe.code!=='ESRCH')throw probe;}}}else child.kill();}}catch(error){if(actionFailed)console.error('Port-forward cleanup also failed:',String(error.message).slice(0,200));else throw error;}}
}
const request=(base,path,options={})=>fetch(base+path,{signal:AbortSignal.timeout(45000),...options});
const post=(base,path,data,key=apiKey)=>request(base,path,{method:'POST',headers:{'Content-Type':'application/json',...auth(key)},body:JSON.stringify(data)});
const input=['A cat sits on the mat.','A cat sits on the mat.','The stock market closed lower today.'];
const dot=(a,b)=>a.reduce((s,n,i)=>s+n*b[i],0);
let reference;
async function check(base,negative=false){
 assert.equal((await request(base,'/health')).status,200);
 for(const path of ['/metrics','//metrics','/%6Detrics','/docs','/api-doc/openapi.json'])assert.equal((await request(base,path)).status,404,'Private/documentation path exposed: '+path);
 if(values.auth.enabled){for(const key of ['',apiKey+'-wrong'])assert.equal((await post(base,'/embed',{inputs:input[0]},key)).status,401);}
 const info=await request(base,'/info',{headers:auth(apiKey)});assert.equal(info.status,200);const metadata=await info.json();
 assert.equal(metadata.version,'1.9.3');assert.equal(metadata.model_id,values.model.source==='hub'?values.model.id:'/models');
 if(values.model.source==='hub')assert.equal(metadata.model_sha,values.model.revision);
 assert.equal(metadata.max_concurrent_requests,values.inference.maxConcurrentRequests);assert.equal(metadata.max_client_batch_size,values.inference.maxClientBatchSize);
 assert.equal(metadata.max_batch_tokens,values.inference.maxBatchTokens);assert.equal(metadata.max_batch_requests,values.inference.maxBatchRequests);
 assert.equal(metadata.auto_truncate,values.inference.autoTruncate);assert.equal(metadata.tokenization_workers,values.inference.tokenizationWorkers);assert.equal(metadata.model_dtype,values.model.dtype);
 const response=await post(base,'/embed',{inputs:input,normalize:true});assert.equal(response.status,200);const vectors=await response.json();
 assert.equal(vectors.length,3);for(const v of vectors){assert.equal(v.length,384);assert.ok(v.every(Number.isFinite));assert.ok(Math.abs(Math.sqrt(dot(v,v))-1)<0.001);}
 assert.ok(dot(vectors[0],vectors[1])>0.9999);assert.ok(dot(vectors[0],vectors[2])<0.9,'Semantically unrelated text must differ');
 if(reference)assert.ok(dot(reference,vectors[0])>0.9999,'Model output changed across replicas/replacement');else reference=vectors[0];
 const compatible=await post(base,'/v1/embeddings',{input:[input[0]],model:values.model.servedName||metadata.model_id});assert.equal(compatible.status,200);const result=await compatible.json();
 assert.equal(result.object,'list');assert.equal(result.data[0].index,0);assert.equal(result.model,values.model.servedName||metadata.model_id);assert.ok(result.usage.total_tokens>0);assert.ok(dot(result.data[0].embedding,vectors[0])>0.9999);
 if(negative){
  assert.equal((await post(base,'/embed',{inputs:[]})).status,400);
  assert.equal((await post(base,'/embed',{inputs:Array(values.inference.maxClientBatchSize+1).fill('test')})).status,422);
  assert.equal((await post(base,'/embed',{inputs:'x'.repeat(values.inference.payloadLimit+100)})).status,413);
  const long='hello '.repeat(metadata.max_input_length+20);assert.equal((await post(base,'/embed',{inputs:long,truncate:false})).status,422);assert.equal((await post(base,'/embed',{inputs:long,truncate:true})).status,200);
  assert.equal((await post(base,'/rerank',{query:'cat',texts:['cat','market']})).status,424);
 }
}
for(const p of pods()){
 assert.equal(p.spec.automountServiceAccountToken,false);
 assert.ok(!p.spec.volumes.some(v=>v.projected?.sources?.some(s=>s.serviceAccountToken)));
 assert.equal(p.spec.securityContext.runAsUser,1000);
 for(const c of p.spec.containers){assert.equal(c.securityContext.readOnlyRootFilesystem,true);assert.equal(c.securityContext.allowPrivilegeEscalation,false);}
 await forward('pod/'+p.metadata.name,values.proxy.port,base=>check(base,true));
 const logs=kubectl(['logs',p.metadata.name,'-c','tei']);if(apiKey)assert.ok(!logs.includes(apiKey),'Native logs exposed API credentials');
}
console.log('PASS native model identity, finite normalized semantic embeddings, OpenAI equivalence, authentication and admission limits');
const peer='tei-isolation-peer';
const peerPod={apiVersion:'v1',kind:'Pod',metadata:{name:peer,labels:{'helmforge.dev/runtime-fixture':'true'}},spec:{terminationGracePeriodSeconds:1,automountServiceAccountToken:false,restartPolicy:'Never',securityContext:{runAsNonRoot:true,runAsUser:1000,runAsGroup:1000,seccompProfile:{type:'RuntimeDefault'}},containers:[{name:'curl',image:values.image.repository+':'+values.image.tag,command:['/bin/sh','-c','sleep 600'],args:[],securityContext:{allowPrivilegeEscalation:false,readOnlyRootFilesystem:true,capabilities:{drop:['ALL']}},resources:{requests:{cpu:'10m',memory:'32Mi'},limits:{cpu:'100m',memory:'128Mi'}}}]}};
console.log('Checking isolated peer');kubectl(['apply','-f','-'],{input:JSON.stringify(peerPod)});kubectl(['wait','--for=condition=Ready','pod/'+peer,'--timeout=60s']);
console.log('Isolated peer ready');
const peerCurl=(url)=>kubectl(['exec',peer,'--','curl','--silent','--show-error','--max-time','4','--output','/dev/null','--write-out','%{http_code}',url],{timeout:10000,stdio:['ignore','pipe','pipe']});
function denied(action){try{const result=action();assert.equal(result.trim(),'000','Unexpected network connectivity');}catch(error){assert.ok(error.status===7||error.status===28||error.status===6,'Unexpected denial: '+String(error.message).slice(0,120));}}
try{
 console.log('Checking public health and native loopback boundary');
 const pod=pods()[0],ip=pod.status.podIP.includes(':')?'['+pod.status.podIP+']':pod.status.podIP;
 assert.equal(peerCurl(`http://${ip}:${values.proxy.port}/health`),'200');
 if(values.service.ipFamilyPolicy==='RequireDualStack'||values.service.ipFamilies.includes('IPv6')){
  const ipv6=pod.status.podIPs.find(p=>p.ip.includes(':'))?.ip;assert.ok(ipv6,'IPv6 Pod address is required');
  assert.equal(peerCurl(`http://[${ipv6}]:${values.proxy.port}/health`),'200');
  const service=JSON.parse(kubectl(['get','service',deploy.metadata.name,'-o','json']));
  const serviceV6=service.spec.clusterIPs.find(ip=>ip.includes(':'));assert.ok(serviceV6,'IPv6 Service address is required');
  assert.equal(peerCurl(`http://[${serviceV6}]:${values.service.port}/health`),'200');
  console.log('PASS native health through IPv6 Pod and Service listeners');
 }
 denied(()=>peerCurl(`http://${ip}:8081/health`));
 if(values.metrics.enabled){
  denied(()=>peerCurl(`http://${ip}:${values.metrics.port}/metrics`));
  await forward('pod/'+pod.metadata.name,values.metrics.port,async base=>{
   const m=await request(base,'/metrics');assert.equal(m.status,200);const text=await m.text();assert.match(text,/te_request_count/);assert.match(text,/te_request_success/);assert.match(text,/te_request_inference_duration/);assert.equal((await post(base,'/embed',{inputs:'test'})).status,404);
  });
  if(values.metrics.serviceMonitor.enabled){
   kubectl(['rollout','status','statefulset/prometheus-tei-monitor','--timeout=90s']);
   await forward('service/tei-monitor',9090,async base=>{
    const query='te_request_success{namespace="'+namespace+'"}';const deadline=Date.now()+45000;let series=[];
    do{const r=await(await request(base,'/api/v1/query?query='+encodeURIComponent(query))).json();series=r.data?.result??[];if(series.some(s=>Number(s.value[1])>0))break;await sleep(2000);}while(Date.now()<deadline);
    assert.ok(series.some(s=>Number(s.value[1])>0),'Real Prometheus did not observe successful inference');
    const up=await(await request(base,'/api/v1/query?query='+encodeURIComponent('up{namespace="'+namespace+'",endpoint="metrics"}'))).json();assert.ok(up.data.result.some(s=>s.value[1]==='1'));
    if(values.metrics.prometheusRule.enabled){
     const rules=await(await request(base,'/api/v1/rules')).json();const rule=rules.data.groups.flatMap(g=>g.rules).find(r=>r.name==='TextEmbeddingsInferenceUnavailable');assert.ok(rule);assert.match(rule.query,/absent\(/);
     const absentQuery=rule.query.replace(/service="[^"]+"/g,'service="tei-missing-target"');
     const absent=await(await request(base,'/api/v1/query?query='+encodeURIComponent(absentQuery))).json();assert.ok(absent.data.result.some(s=>s.value[1]==='1'),'The actual alert expression must detect an absent target');
    }
   });
  }
  console.log('PASS private native Prometheus metrics, denied unrelated peer and real successful-inference scrape');
 }
 if(values.model.source==='local'){
  const policy=JSON.parse(kubectl(['get','networkpolicy',deploy.metadata.name,'-o','json'])).spec;
  assert.ok(policy.policyTypes.includes('Egress'));
  assert.deepEqual(policy.egress??[],[]);
  const api=JSON.parse(execFileSync('kubectl',['--context',context,'-n','default','get','service','kubernetes','-o','json'],{encoding:'utf8'})).spec.clusterIP;
  const apiUrl='https://'+(api.includes(':')?'['+api+']':api)+':443';
  const good=kubectl(['exec',peer,'--','curl','-k','--silent','--max-time','5','--output','/dev/null','--write-out','%{http_code}',apiUrl]);assert.match(good,/^(401|403)$/);
  denied(()=>kubectl(['exec',pod.metadata.name,'-c','tei','--','curl','-k','--silent','--max-time','4','--output','/dev/null','--write-out','%{http_code}',apiUrl],{timeout:10000,stdio:['ignore','pipe','pipe']}));
  console.log('PASS local read-only model inference with all egress denied and positive network control');
 }
}finally{kubectl(['delete','pod',peer,'--wait=true','--timeout=30s']);}
if(values.autoscaling.enabled){
 const deadline=Date.now()+90000;let hpa;
 do{hpa=JSON.parse(kubectl(['get','hpa',deploy.metadata.name,'-o','json']));if(hpa.status?.currentMetrics?.some(m=>m.containerResource?.current?.averageUtilization!==undefined))break;await sleep(2000);}while(Date.now()<deadline);
 assert.ok(hpa.status.currentMetrics.some(m=>m.containerResource?.current?.averageUtilization!==undefined),'CPU HPA must observe real container metrics');assert.ok(hpa.status.currentReplicas>=values.autoscaling.minReplicas);
 console.log('PASS multiple independent model replicas and real CPU HPA metrics');
}
if(values.cache.persistence.enabled)kubectl(['exec',pods()[0].metadata.name,'-c','tei','--','sh','-c','printf retained > /data/helmforge-cache-marker']);
if(values.auth.enabled&&!values.auth.existingSecret){
 execFileSync('helm',['upgrade',release,fileURLToPath(new URL('../',import.meta.url)),'-n',namespace,'--kube-context',context,'--reuse-values','--wait','--timeout','120s'],{encoding:'utf8',timeout:130000});
 assert.ok(readKey()===apiKey,'Generated credential changed during Helm upgrade');
 console.log('PASS generated API credential retained by real Helm upgrade');
}
kubectl(['rollout','restart','deployment/'+deploy.metadata.name]);kubectl(['rollout','status','deployment/'+deploy.metadata.name,'--timeout=120s'],{timeout:130000});
assert.ok(readKey()===apiKey,'API credential changed after Pod replacement');
for(const p of pods())await forward('pod/'+p.metadata.name,values.proxy.port,base=>check(base));
if(values.cache.persistence.enabled)assert.equal(kubectl(['exec',pods()[0].metadata.name,'-c','tei','--','cat','/data/helmforge-cache-marker']),'retained');
console.log('PASS native inference, model identity and original API credential after Pod replacement'+(values.cache.persistence.enabled?', retained cache volume':''));
