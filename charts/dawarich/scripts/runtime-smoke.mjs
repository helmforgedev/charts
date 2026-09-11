// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync,spawn} from 'node:child_process';
import {randomUUID,createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {restore} from './restore-smoke.mjs';
import http from 'node:http';
import {verifyMetrics} from './metrics-smoke.mjs';
import {verifyBrowserForms} from './browser-smoke.mjs';
import {enableAndVerifyOtp,finishOtpLogin} from './otp-smoke.mjs';
const [context,namespace,release]=process.argv.slice(2);assert.equal(context,'k3d-helmforge-tests-wsl');
const k=args=>execFileSync('kubectl',['--context',context,'-n',namespace,...args],{encoding:'utf8',timeout:100000});
const values=JSON.parse(execFileSync('helm',['get','values',release,'--kube-context',context,'-n',namespace,'-a','-o','json'],{encoding:'utf8'}));
const selector='app.kubernetes.io/instance='+release+',app.kubernetes.io/name=dawarich';
const deployment=JSON.parse(k(['get','deployment','-l',selector,'-o','json'])).items[0];assert.ok(deployment);
const pod=()=>JSON.parse(k(['get','pods','-l',selector,'-o','json'])).items.find(item=>!item.metadata.deletionTimestamp).metadata.name;
const secretName=deployment.spec.template.spec.volumes.find(volume=>volume.name==='bootstrap-auth').secret.secretName;
const password=Buffer.from(JSON.parse(k(['get','secret',secretName,'-o','json'])).data[values.bootstrap.passwordKey],'base64').toString();
const identityName=deployment.spec.template.spec.containers[0].env.find(item=>item.name==='SECRET_KEY_BASE').valueFrom.secretKeyRef.name;
const identityData=()=>JSON.stringify(Object.entries(JSON.parse(k(['get','secret',identityName,'-o','json'])).data).sort());
const originalIdentity=identityData();
const origin=new URL(values.server.publicUrl||'http://'+deployment.metadata.name+'.'+namespace+'.svc:'+values.service.port);
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function forward(test,port=values.server.port,target='pod/'+pod()){const process=spawn('kubectl',['--context',context,'-n',namespace,'port-forward',target,'0:'+port,'--address=127.0.0.1'],{windowsHide:true,stdio:['ignore','pipe','pipe']});let output='';for(const stream of [process.stdout,process.stderr])stream.on('data',data=>output+=data);try{const deadline=Date.now()+20000;while(!/Forwarding from/.test(output)&&Date.now()<deadline&&process.exitCode===null)await delay(100);const match=output.match(/127\.0\.0\.1:(\d+)/);assert.ok(match,'Port-forward did not start');await test('http://127.0.0.1:'+match[1]);}finally{if(process.exitCode===null&&process.signalCode===null){if(globalThis.process.platform==='win32')execFileSync('taskkill',['/PID',String(process.pid),'/T','/F'],{stdio:'ignore'});else process.kill();}}}
let apiKey,importId,otpState,importHash;
function client(base){return async(path,{method='GET',json,body,anonymous=false}={})=>{
 const headers={Host:origin.host,'X-Forwarded-Proto':origin.protocol.slice(0,-1),...(json?{'Content-Type':'application/json'}:{}),...(!anonymous&&apiKey?{Authorization:'Bearer '+apiKey}:{})};
 let payload=json?Buffer.from(JSON.stringify(json)):undefined;
 if(body){const encoded=new Response(body);payload=Buffer.from(await encoded.arrayBuffer());headers['Content-Type']=encoded.headers.get('content-type');}
 if(payload)headers['Content-Length']=String(payload.length);
 return new Promise((resolve,reject)=>{const request=http.request(new URL(base+path),{method,headers,signal:AbortSignal.timeout(15000)},response=>{const chunks=[];response.on('data',chunk=>chunks.push(chunk));response.on('error',reject);response.on('end',()=>resolve(new Response([204,304].includes(response.statusCode)?null:Buffer.concat(chunks),{status:response.statusCode,headers:response.headers})));});request.on('error',reject);request.end(payload);});
};}
async function login(request){const response=await request('/api/v1/auth/login',{method:'POST',anonymous:true,json:{email:values.bootstrap.email,password}});assert.ok([200,202].includes(response.status),'Native administrator login failed');let result=await response.json();if(response.status===202)result=await finishOtpLogin(request,result,otpState);assert.equal(result.email,values.bootstrap.email);assert.ok(result.api_key);return result.api_key;}
function verifyAttachment(expectedDatabase=values.postgresql.enabled?values.postgresql.auth.database:values.database.name){
 const code="require 'digest'; puts 'HELMFORGE_DATABASE=' + ActiveRecord::Base.connection.current_database; puts 'HELMFORGE_FILE_SHA256=' + Digest::SHA256.hexdigest(Import.find("+JSON.stringify(importId)+").file.download)";
 const output=k(['exec',pod(),'-c','dawarich','--','sh','-ec','unset BUNDLE_PATH BUNDLE_BIN; exec bundle exec ruby /helmforge/entrypoint.rb runner "$1"','sh',code]);
 assert.equal(output.match(/HELMFORGE_DATABASE=([^\r\n]+)/)?.[1],expectedDatabase,'Native application must connect to the intended database');
 assert.equal(output.match(/HELMFORGE_FILE_SHA256=([a-f0-9]{64})/)?.[1],importHash,'Native ActiveStorage download must retain the exact uploaded GPX bytes');
}
try{
 const listeners=JSON.parse(k(['exec',pod(),'-c','dawarich','--','node','-e',"const fs=require('fs');const rows=['/proc/net/tcp','/proc/net/tcp6'].flatMap(p=>fs.readFileSync(p,'utf8').trim().split('\\n').slice(1).map(l=>l.trim().split(/\\s+/))).filter(f=>f[3]==='0A'&&f[1].endsWith(':0BC2')).map(f=>f[1]);console.log(JSON.stringify(rows));"]));
 assert.deepEqual(listeners,['0100007F:0BC2'],'Native Rails listener must be exclusively IPv4 loopback');
 await forward(async base=>{const request=client(base);
  assert.equal((await request('/api/v1/health')).status,200);
  for(const path of ['/api/v1/auth/register','/api/v1/auth/register.json','/api/v1/auth/register/','/api/v1/auth/%72egister','/api/v1/auth%2fregister','//api/v1/auth/register','/api/v1/auth/apple','/api/v1/auth/google','/users','/users.json','/users/sign_up','/users/auth/openid_connect'])assert.equal((await request(path,{method:'POST',anonymous:true,json:{email:'never-created@example.test',password:'Owned-fixture-never-created'}})).status,403,'Public self-registration route must be denied: '+path);
  assert.equal((await request('/metrics',{anonymous:true})).status,404);
  assert.equal((await request('/api/v1/auth/login',{method:'POST',anonymous:true,json:{email:'demo@dawarich.app',password:'safepassword'}})).status,401);
  assert.equal((await request('/api/v1/auth/login',{method:'POST',anonymous:true,json:{email:values.bootstrap.email,password:'incorrect-owned-fixture'}})).status,401);
  apiKey=await login(request);
  assert.equal((await request('/api/v1/users/me',{anonymous:true})).status,401);
  const me=await request('/api/v1/users/me');assert.equal(me.status,200);assert.equal((await me.json()).user.email,values.bootstrap.email);
  const fixtureTime=Date.now()-86400000;
  const name='helmforge-'+randomUUID()+'.gpx';const xml='<?xml version="1.0"?><gpx version="1.1" creator="HelmForge" xmlns="http://www.topografix.com/GPX/1/1"><trk><name>Owned runtime fixture</name><trkseg><trkpt lat="-23.5505" lon="-46.6333"><time>'+new Date(fixtureTime).toISOString()+'</time></trkpt><trkpt lat="-23.5515" lon="-46.6343"><time>'+new Date(fixtureTime+300000).toISOString()+'</time></trkpt></trkseg></trk></gpx>';
  importHash=createHash('sha256').update(xml).digest('hex');
  const form=new FormData();form.set('file',new Blob([xml],{type:'application/gpx+xml'}),name);
  const upload=await request('/api/v1/imports',{method:'POST',body:form});assert.equal(upload.status,201,'Native GPX import submission failed');importId=(await upload.json()).id;assert.ok(importId);
  const deadline=Date.now()+70000;let imported;
  while(Date.now()<deadline){const response=await request('/api/v1/imports/'+importId);assert.equal(response.status,200);imported=await response.json();assert.notEqual(imported.status,'failed','Native Sidekiq GPX import failed');if(imported.status==='completed'&&imported.processed>=2)break;await delay(2000);}
  assert.equal(imported.status,'completed','Native Sidekiq import did not complete');assert.ok(imported.processed>=2);
  const pointsResponse=await request('/api/v1/points?import_id='+importId+'&include_anomalies=true&order=asc');assert.equal(pointsResponse.status,200);const points=await pointsResponse.json();assert.equal(points.length,2);assert.equal(Number(points[0].latitude),-23.5505);assert.equal(Number(points[0].longitude),-46.6333);assert.equal(Number(points[1].latitude),-23.5515);assert.equal(Number(points[1].longitude),-46.6343);
  if(deployment.metadata.name==='dawarich-browser')await verifyBrowserForms({base,email:values.bootstrap.email,password,publicUrl:values.server.publicUrl});
  otpState=await enableAndVerifyOtp({request,password,email:values.bootstrap.email,apiKey});
  console.log('PASS native private administrator, unsafe seed rejection, normalized signup containment and completed Sidekiq GPX import');
 });
 verifyAttachment();
 if(deployment.metadata.name==='dawarich-external'||deployment.metadata.name==='dawarich-s3')console.log(k(['exec',pod(),'-c','dawarich','--','sh','-ec','unset BUNDLE_PATH BUNDLE_BIN; exec bundle exec ruby /helmforge/tls-admission.rb "$1"','sh',importHash]).trim());
 if(values.metrics.enabled)await verifyMetrics({k,forward,values,namespace,context,deployment});
 if(deployment.metadata.name==='dawarich-production'){
  const workloads=JSON.parse(k(['get','pods','-l','app.kubernetes.io/instance='+release,'-o','json'])).items;
  assert.equal(workloads.length,3,'Production must validate the application and both dependencies');
  for(const item of workloads)for(const volume of item.spec.volumes??[])
   assert.ok(!(volume.projected?.sources??[]).some(source=>source.serviceAccountToken),'Production Pods must not receive Kubernetes API tokens');
  const before=JSON.parse(k(['get','pod',pod(),'-o','json']));
  assert.equal(before.status.containerStatuses.find(item=>item.name==='worker').ready,true);
  k(['exec',pod(),'-c','worker','--','sh','-ec','kill -TSTP 1']);
  let quiet=false;const deadline=Date.now()+45000;
  while(Date.now()<deadline){
   const current=JSON.parse(k(['get','pod',pod(),'-o','json']));
   if(current.status.containerStatuses.find(item=>item.name==='worker').ready===false){quiet=true;break;}
   await delay(2000);
  }
  assert.ok(quiet,'A quiet native Sidekiq process must stop reporting worker readiness');
  console.log('PASS tokenless application/PostGIS/Redis Pods and withdrawn readiness for a quiet native worker');
 }
 if(deployment.metadata.name==='dawarich-restore')restore({k,context,namespace,release,chartPath:fileURLToPath(new URL('../',import.meta.url)),deployment,pod,values});
 else{k(['rollout','restart','deployment/'+deployment.metadata.name]);k(['rollout','status','deployment/'+deployment.metadata.name,'--timeout=90s']);}
 await forward(async base=>{const request=client(base);assert.equal(await login(request),apiKey,'Native API key changed across restart');const response=await request('/api/v1/imports/'+importId);assert.equal(response.status,200);const imported=await response.json();assert.equal(imported.status,'completed');assert.ok(imported.processed>=2);
  const pointsResponse=await request('/api/v1/points?import_id='+importId+'&include_anomalies=true&order=asc');
  assert.equal(pointsResponse.status,200);const points=await pointsResponse.json();
  assert.deepEqual(points.map(point=>[Number(point.latitude),Number(point.longitude)]),[[-23.5505,-46.6333],[-23.5515,-46.6343]],'Exact imported locations must survive Pod replacement and coordinated recovery');
 });
 verifyAttachment(deployment.metadata.name==='dawarich-restore'?'dawarich_recovered':undefined);
 assert.ok(identityData()===originalIdentity,'All four native identity and OTP keys must be retained');
 assert.match(k(['logs',pod(),'-c','bootstrap']),/Existing native identity preserved/);
 console.log('PASS retained native identity/API key, imported locations and completed job state after Pod replacement');
}catch(error){console.error(String(error.stack??error).replaceAll(password,'[REDACTED]').replaceAll(apiKey??'no-secret-value','[REDACTED]'));throw Error('Dawarich native runtime validation failed');}
