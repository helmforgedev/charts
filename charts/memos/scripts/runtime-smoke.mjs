// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {execFileSync,spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const [context,namespace,release]=process.argv.slice(2);assert.match(context??'',/^k3d-/);assert.ok(namespace&&release);
const k=args=>execFileSync('kubectl',['--context',context,'-n',namespace,...args],{encoding:'utf8',timeout:90000});
const values=JSON.parse(execFileSync('helm',['get','values',release,'-n',namespace,'--kube-context',context,'-a','-o','json'],{encoding:'utf8'}));
const selector=`app.kubernetes.io/instance=${release},app.kubernetes.io/name=memos`;
const workload=JSON.parse(k(['get','statefulsets','-l',selector,'-o','json'])).items[0];assert.ok(workload);
assert.ok(values.bootstrap.enabled,'Runtime fixture requires protected bootstrap');
const secretName=workload.spec.template.spec.volumes.find(v=>v.name==='bootstrap-auth').secret.secretName;
const secret=JSON.parse(k(['get','secret',secretName,'-o','json'])).data;const password=Buffer.from(secret[values.bootstrap.passwordKey],'base64').toString();
const pod=()=>JSON.parse(k(['get','pods','-l',selector,'-o','json'])).items.find(p=>!p.metadata.deletionTimestamp).metadata.name;
async function forward(test,target=pod()){
 const child=spawn('kubectl',['--context',context,'-n',namespace,'port-forward','pod/'+target,':'+values.app.port,'--address=127.0.0.1'],{windowsHide:true,stdio:['ignore','pipe','pipe']});let out='';for(const stream of [child.stdout,child.stderr])stream.on('data',b=>out+=b);
 try{const deadline=Date.now()+20000;while(!/127\.0\.0\.1:(\d+) ->/.test(out)&&Date.now()<deadline&&child.exitCode===null)await new Promise(r=>setTimeout(r,100));const port=out.match(/127\.0\.0\.1:(\d+) ->/)?.[1];assert.ok(port);await test('http://127.0.0.1:'+port);}
 finally{if(process.platform==='win32'&&child.exitCode===null){try{execFileSync('taskkill',['/PID',String(child.pid),'/T','/F'],{stdio:'ignore'});}catch(error){let gone=false;try{process.kill(child.pid,0);}catch(e){if(e.code==='ESRCH')gone=true;else throw e;}if(!gone)throw error;}}else child.kill();}
}
let accessToken,refreshCookie,memoName,attachmentName;
const marker='HelmForge persistent memo: ação 日本語';const content=Buffer.from('HelmForge attachment: ação 日本語\n');
function client(base){return async(path,{method='GET',body,auth=true,status=200,headers={}}={})=>{const response=await fetch(base+path,{method,headers:{'Content-Type':'application/json',...(auth?{Authorization:'Bearer '+accessToken}:{}),...headers},...(body?{body:JSON.stringify(body)}:{}),redirect:'manual',signal:AbortSignal.timeout(15000)});assert.equal(response.status,status,method+' '+path);return response;};}
await forward(async base=>{
 const api=client(base);const profile=await(await api('/api/v1/instance/profile',{auth:false})).json();assert.notEqual(profile.needsSetup,true);
 const login=await api('/memos.api.v1.AuthService/SignIn',{auth:false,method:'POST',body:{passwordCredentials:{username:values.bootstrap.username,password}}});const data=await login.json();assert.equal(data.user.role,'ADMIN');accessToken=data.accessToken;assert.ok(accessToken);
 const cookies=login.headers.getSetCookie();assert.ok(cookies.some(c=>/HttpOnly/i.test(c)&&/SameSite=Lax/i.test(c)));refreshCookie=cookies.map(c=>c.split(';')[0]).join('; ');
 if(values.provisioning.manageGeneralSettings&&!values.provisioning.existingSecret&&values.provisioning.disallowUserRegistration){const response=await fetch(base+'/api/v1/users',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:'unapproved',password:'fixture-only-password'})});assert.ok(response.status===401||response.status===403,'New registration must be denied');}
 const memo=await(await api('/api/v1/memos',{method:'POST',body:{content:'Initial fixture',visibility:'PRIVATE'}})).json();memoName=memo.name;assert.match(memoName,/^memos\//);
 await api('/api/v1/'+memoName+'?updateMask=content',{method:'PATCH',body:{content:marker}});assert.equal((await(await api('/api/v1/'+memoName)).json()).content,marker);
 const attachment=await(await api('/api/v1/attachments',{method:'POST',body:{filename:'fixture.txt',type:'text/plain',content:content.toString('base64'),memo:memoName}})).json();attachmentName=attachment.name;assert.match(attachmentName,/^attachments\//);
 if(workload.metadata.name==='memos-s3'){
  const url=new URL(attachment.externalLink);assert.equal(url.hostname,'fixture-integrations');assert.ok(url.searchParams.has('X-Amz-Signature'));
  const proof=`const https=require('node:https'),fs=require('node:fs'),assert=require('node:assert/strict');const url=new URL(${JSON.stringify(attachment.externalLink)});const get=url=>new Promise((resolve,reject)=>{https.get(url,{ca:fs.readFileSync('/tls/ca.crt')},res=>{const chunks=[];res.on('data',b=>chunks.push(b));res.on('end',()=>resolve({status:res.statusCode,body:Buffer.concat(chunks)}));}).on('error',reject);});(async()=>{const signed=await get(url);assert.equal(signed.status,200);assert.equal(signed.body.toString('base64'),${JSON.stringify(content.toString('base64'))});url.search='';assert.equal((await get(url)).status,403);console.log('PASS native signed S3 URL with exact object bytes and unsigned denial over trusted HTTPS');})().catch(e=>{console.error(e.message);process.exitCode=1;});`;
  console.log(execFileSync('kubectl',['--context',context,'-n',namespace,'exec','-i','deployment/fixture-integrations','-c','proxy','--','node','-'],{input:proof,encoding:'utf8',timeout:30000}).trim());
 }else{
  const file=k(['exec',pod(),'-c','memos','--','find',values.persistence.mountPath+'/assets','-type','f','-name','*fixture.txt']).trim().split(/\r?\n/).find(Boolean);assert.ok(file,'Default attachments must exist on the data volume');
  const checksum=k(['exec',pod(),'-c','memos','--','sha256sum',file]).split(/\s/)[0];assert.equal(checksum,createHash('sha256').update(content).digest('hex'));
 }
 const download=await api('/file/'+attachmentName+'/fixture.txt');assert.deepEqual(Buffer.from(await download.arrayBuffer()),content);
 for(const path of ['/api/v1/'+memoName,'/file/'+attachmentName+'/fixture.txt']){const denied=await fetch(base+path,{redirect:'manual'});assert.notEqual(denied.status,200,'Private content must reject anonymous access');}
 const patResponse=await(await api('/api/v1/users/'+values.bootstrap.username+'/personalAccessTokens',{method:'POST',body:{description:'HelmForge MCP fixture',expiresInDays:1}})).json();assert.ok(patResponse.token);
 let rpcId=0;
 const rpc=async(method,params,token=patResponse.token)=>{const response=await fetch(base+'/mcp',{method:'POST',headers:{'Content-Type':'application/json',Accept:'application/json, text/event-stream',...(token?{Authorization:'Bearer '+token}:{})},body:JSON.stringify({jsonrpc:'2.0',id:++rpcId,method,params}),signal:AbortSignal.timeout(15000)});assert.equal(response.status,200);return response.json();};
 const initialized=await rpc('initialize',{protocolVersion:'2025-06-18',capabilities:{},clientInfo:{name:'helmforge-runtime',version:'1.0.0'}});assert.equal(initialized.result.serverInfo.name,'memos');
 const list=await rpc('tools/list',{});assert.ok(list.result.tools.some(t=>t.name==='memo_create_memo'));
 const created=await rpc('tools/call',{name:'memo_create_memo',arguments:{body:{content:'HelmForge MCP persistent operation',visibility:'PRIVATE'}}});assert.notEqual(created.result.isError,true);const mcpMemo=created.result.structuredContent.name;assert.match(mcpMemo,/^memos\//);assert.equal((await(await api('/api/v1/'+mcpMemo)).json()).content,'HelmForge MCP persistent operation');
 const read=await rpc('tools/call',{name:'memo_get_memo',arguments:{memo:mcpMemo}});assert.equal(read.result.structuredContent.content,'HelmForge MCP persistent operation');
 const denied=await rpc('tools/call',{name:'memo_get_memo',arguments:{memo:mcpMemo}},'');assert.equal(denied.result.isError,true);assert.equal(denied.result.structuredContent,undefined);
 const removed=await rpc('tools/call',{name:'memo_delete_memo',arguments:{memo:mcpMemo}});assert.notEqual(removed.result.isError,true);await api('/api/v1/'+mcpMemo,{status:404});
 await api('/api/v1/'+patResponse.personalAccessToken.name,{method:'DELETE'});const revoked=await rpc('tools/call',{name:'auth_get_current_user',arguments:{}});assert.equal(revoked.result.isError,true);
 console.log('PASS native PAT-authenticated MCP initialization, tool discovery, actual private memo CRUD, anonymous denial and revocation');
 if(workload.metadata.name==='memos-oauth'){const {oauthSmoke}=await import('./oauth-smoke.mjs');await oauthSmoke({context,namespace,base,api,username:values.bootstrap.username,memoName});}
});
if(values.replicaCount>1){
 const replicas=JSON.parse(k(['get','pods','-l',selector,'-o','json'])).items.filter(p=>!p.metadata.deletionTimestamp);assert.equal(replicas.length,values.replicaCount);
 for(const replica of replicas)await forward(async base=>{const api=client(base);assert.equal((await(await api('/api/v1/'+memoName)).json()).content,marker);assert.deepEqual(Buffer.from(await(await api('/file/'+attachmentName+'/fixture.txt')).arrayBuffer()),content);},replica.metadata.name);
 console.log('PASS identical private memo, attachment and native identity through every SQL-backed replica sharing the data claim');
}
if(values.persistence.enabled||values.persistence.existingClaim){
 k(['rollout','restart','statefulset/'+workload.metadata.name]);k(['rollout','status','statefulset/'+workload.metadata.name,'--timeout=90s']);
 await forward(async base=>{const api=client(base);assert.equal((await(await api('/api/v1/'+memoName)).json()).content,marker);assert.deepEqual(Buffer.from(await(await api('/file/'+attachmentName+'/fixture.txt')).arrayBuffer()),content);const refreshResponse=await api('/memos.api.v1.AuthService/RefreshToken',{method:'POST',auth:false,body:{},headers:{Cookie:refreshCookie}});const refreshed=await refreshResponse.json();assert.ok(refreshed.accessToken);accessToken=refreshed.accessToken;const rotated=refreshResponse.headers.getSetCookie();if(rotated.length)refreshCookie=rotated.map(c=>c.split(';')[0]).join('; ');});
}
execFileSync('helm',['upgrade',release,fileURLToPath(new URL('..',import.meta.url)),'--kube-context',context,'-n',namespace,'--reuse-values','--wait','--timeout','60s'],{encoding:'utf8',timeout:75000});assert.deepEqual(JSON.parse(k(['get','secret',secretName,'-o','json'])).data,secret);
if(workload.metadata.name==='memos-oauth')await forward(async base=>{const {oauthSmoke}=await import('./oauth-smoke.mjs');await oauthSmoke({context,namespace,base,api:client(base),username:values.bootstrap.username,memoName});});
if(workload.metadata.name==='memos-restore'){
 assert.equal(values.database.driver,'sqlite');
 const originalPod=pod();const podObject=JSON.parse(k(['get','pod',originalPod,'-o','json']));
 const claim=podObject.spec.volumes.find(v=>v.name==='data').persistentVolumeClaim.claimName;
 k(['scale','statefulset/'+workload.metadata.name,'--replicas=0']);k(['wait','--for=delete','pod/'+originalPod,'--timeout=60s']);
 const original=JSON.parse(k(['get','pvc',claim,'-o','json'])),restoreName=workload.metadata.name+'-recovered';
 const pvc={apiVersion:'v1',kind:'PersistentVolumeClaim',metadata:{name:restoreName,labels:{'helmforge.dev/runtime-fixture':'true'}},spec:{accessModes:original.spec.accessModes,resources:original.spec.resources,...(original.spec.storageClassName!==undefined?{storageClassName:original.spec.storageClassName}:{})}};
 const archive="const fs=require('node:fs'),cp=require('node:child_process'),assert=require('node:assert/strict');const entries=fs.readdirSync('/source');assert.ok(entries.includes('memos_prod.db'));cp.execFileSync('tar',['-czf','/tmp/memos.tar.gz','-C','/source','--',...entries]);cp.execFileSync('tar',['-xzf','/tmp/memos.tar.gz','-C','/recovered']);assert.ok(fs.statSync('/recovered/memos_prod.db').size>0);console.log('memos-archive-restored');";
 const copy={apiVersion:'v1',kind:'Pod',metadata:{name:'memos-recovery',labels:{'helmforge.dev/runtime-fixture':'true'}},spec:{restartPolicy:'Never',automountServiceAccountToken:false,securityContext:workload.spec.template.spec.securityContext,containers:[{name:'restore',image:values.bootstrap.image.repository+':'+values.bootstrap.image.tag,command:['node','-e',archive],securityContext:values.securityContext,resources:{requests:{cpu:'50m',memory:'64Mi'},limits:{cpu:'500m',memory:'256Mi'}},volumeMounts:[{name:'source',mountPath:'/source',readOnly:true},{name:'recovered',mountPath:'/recovered'},{name:'tmp',mountPath:'/tmp'}]}],volumes:[{name:'source',persistentVolumeClaim:{claimName:claim}},{name:'recovered',persistentVolumeClaim:{claimName:restoreName}},{name:'tmp',emptyDir:{sizeLimit:'1Gi'}}]}};
 for(const object of [pvc,copy])execFileSync('kubectl',['--context',context,'-n',namespace,'apply','-f','-'],{input:JSON.stringify(object),encoding:'utf8',timeout:30000});
 k(['wait','pod/memos-recovery','--for=jsonpath={.status.phase}=Succeeded','--timeout=60s']);assert.ok(k(['logs','memos-recovery']).includes('memos-archive-restored'));k(['delete','pod/memos-recovery','--wait=true','--timeout=30s']);
 // The claim template is immutable; recreate only the quiesced controller, preserving both PVCs.
 k(['delete','statefulset/'+workload.metadata.name,'--cascade=orphan','--wait=true','--timeout=30s']);
 execFileSync('helm',['upgrade',release,fileURLToPath(new URL('..',import.meta.url)),'--kube-context',context,'-n',namespace,'--reuse-values','--set','persistence.existingClaim='+restoreName,'--wait','--timeout','60s'],{encoding:'utf8',timeout:75000});
 await forward(async base=>{const api=client(base);assert.equal((await(await api('/api/v1/'+memoName)).json()).content,marker);assert.deepEqual(Buffer.from(await(await api('/file/'+attachmentName+'/fixture.txt')).arrayBuffer()),content);const refreshResponse=await api('/memos.api.v1.AuthService/RefreshToken',{method:'POST',auth:false,body:{},headers:{Cookie:refreshCookie}});const refreshed=await refreshResponse.json();assert.ok(refreshed.accessToken);accessToken=refreshed.accessToken;const rotated=refreshResponse.headers.getSetCookie();if(rotated.length)refreshCookie=rotated.map(c=>c.split(';')[0]).join('; ');});
 console.log('PASS quiesced complete SQLite and assets archive restored into a fresh PVC, retained native token/refresh identity and exact memo/attachment');
}
await forward(async base=>{const api=client(base);await api('/api/v1/'+attachmentName,{method:'DELETE'});await api('/api/v1/'+memoName,{method:'DELETE'});await api('/api/v1/'+memoName,{status:404});});
console.log('PASS protected loopback bootstrap, native administrator login, registration policy, private memo and exact attachment CRUD, retained initial password'+((values.persistence.enabled||values.persistence.existingClaim)?', persisted data and refresh session after pod replacement':''));
