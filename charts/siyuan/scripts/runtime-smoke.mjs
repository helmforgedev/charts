// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {execFileSync,spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const [context,namespace,release]=process.argv.slice(2);assert.match(context??'',/^k3d-/);assert.ok(namespace&&release);
const k=args=>execFileSync('kubectl',['--context',context,'-n',namespace,...args],{encoding:'utf8',timeout:90000});
const values=JSON.parse(execFileSync('helm',['get','values',release,'-n',namespace,'--kube-context',context,'-a','-o','json'],{encoding:'utf8'}));
const deployment=JSON.parse(k(['get','deploy','-l',`app.kubernetes.io/instance=${release},app.kubernetes.io/name=siyuan`,'-o','json'])).items[0];assert.ok(deployment);assert.equal(deployment.spec.replicas,1);
const env=deployment.spec.template.spec.containers[0].env.find(e=>e.name==='SIYUAN_ACCESS_AUTH_CODE');const secretName=env.valueFrom.secretKeyRef.name;
const secret=JSON.parse(k(['get','secret',secretName,'-o','json'])).data;const accessCode=Buffer.from(secret[values.auth.accessCodeKey],'base64').toString();
if(values.externalSecrets.enabled){const items=JSON.parse(k(['get','externalsecrets','-o','json'])).items;assert.ok(items.length);assert.ok(items.every(e=>e.status?.conditions?.some(c=>c.type==='Ready'&&c.status==='True')));}
const pod=()=>JSON.parse(k(['get','pods','-l',`app.kubernetes.io/instance=${release},app.kubernetes.io/name=siyuan`,'-o','json'])).items.find(p=>!p.metadata.deletionTimestamp).metadata.name;
async function forward(test){
 const child=spawn('kubectl',['--context',context,'-n',namespace,'port-forward','pod/'+pod(),`:${values.server.port}`,'--address=127.0.0.1'],{windowsHide:true,stdio:['ignore','pipe','pipe']});let out='';for(const stream of [child.stdout,child.stderr])stream.on('data',b=>out+=b);
 try{const deadline=Date.now()+20000;while(!/127\.0\.0\.1:(\d+) ->/.test(out)&&Date.now()<deadline&&child.exitCode===null)await new Promise(r=>setTimeout(r,100));const port=out.match(/127\.0\.0\.1:(\d+) ->/)?.[1];assert.ok(port);await test('http://127.0.0.1:'+port);}
 finally{if(process.platform==='win32'&&child.exitCode===null){try{execFileSync('taskkill',['/PID',String(child.pid),'/T','/F'],{stdio:'ignore'});}catch(error){let gone=false;try{process.kill(child.pid,0);}catch(e){if(e.code==='ESRCH')gone=true;else throw e;}if(!gone)throw error;}}else child.kill();}
}
let notebook,document,originalContent;
async function authenticated(base,action){
 const raw=(path,data,cookie)=>fetch(base+path,{method:'POST',headers:{'Content-Type':'application/json',...(cookie?{Cookie:cookie}:{})},body:JSON.stringify(data),redirect:'manual',signal:AbortSignal.timeout(20000)});
 const login=await raw('/api/system/loginAuth',{authCode:accessCode,rememberMe:false,captcha:''});assert.equal(login.status,200);const body=await login.json();assert.equal(body.code,0,JSON.stringify(body));const cookie=login.headers.getSetCookie().map(c=>c.split(';')[0]).join('; ');assert.ok(cookie);
 const api=async(path,data={})=>{const response=await raw(path,data,cookie);assert.equal(response.status,200);const json=await response.json();assert.equal(json.code,0,JSON.stringify(json));return json.data;};
 await action(api,raw,cookie);
}
await forward(async base=>{
 const health=await fetch(base+'/api/system/version');assert.equal(health.status,200);
 await authenticated(base,async(api,raw)=>{
  const denied=await raw('/api/notebook/lsNotebooks',{});let deniedData;try{deniedData=await denied.json();}catch{}assert.ok(denied.status!==200||deniedData?.code!==0,'Anonymous notebook access must be denied');
  notebook=(await api('/api/notebook/createNotebook',{name:'helmforge-fixture'})).notebook.id;
  document=await api('/api/filetree/createDocWithMd',{notebook,path:'/fixture',markdown:'# HelmForge\n\nPersistent Unicode: ação 日本語'});
  originalContent=(await api('/api/export/exportMdContent',{id:document,yfm:false,addTitle:false})).content;assert.ok(originalContent.includes('Persistent Unicode: ação 日本語'));
  const disposable=(await api('/api/notebook/createNotebook',{name:'remove-fixture'})).notebook.id;await api('/api/notebook/removeNotebook',{notebook:disposable});const listing=await api('/api/notebook/lsNotebooks');assert.ok(!listing.notebooks.some(n=>n.id===disposable));
 });
});
if(values.persistence.enabled){
 k(['rollout','restart','deployment/'+deployment.metadata.name]);k(['rollout','status','deployment/'+deployment.metadata.name,'--timeout=90s']);
 await forward(base=>authenticated(base,async api=>{const data=await api('/api/export/exportMdContent',{id:document,yfm:false,addTitle:false});assert.equal(data.content,originalContent,'Full notebook content must survive pod replacement');}));
}
if(values.oidc.enabled){
 const client=readFileSync(new URL('./oidc-fixture-client.cjs',import.meta.url),'utf8');
 const output=k(['exec',pod(),'-c','oidc-fixture','--','node','-e',client]);assert.ok(output.includes('PASS native OIDC'));console.log(output.trim());
}
execFileSync('helm',['upgrade',release,fileURLToPath(new URL('..',import.meta.url)),'--kube-context',context,'-n',namespace,'--reuse-values','--wait','--timeout','60s'],{encoding:'utf8',timeout:75000});assert.deepEqual(JSON.parse(k(['get','secret',secretName,'-o','json'])).data,secret,'Helm upgrade must retain access code');

if(deployment.metadata.name==='siyuan-restore'){
 assert.ok(values.persistence.enabled);
 const originalPod=pod();
 k(['scale','deployment/'+deployment.metadata.name,'--replicas=0']);
 k(['wait','--for=delete','pod/'+originalPod,'--timeout=60s']);
 const claim=deployment.spec.template.spec.volumes.find(v=>v.name==='workspace').persistentVolumeClaim.claimName;
 const original=JSON.parse(k(['get','pvc',claim,'-o','json']));
 const restoreName=deployment.metadata.name+'-recovered';
 const pvc={apiVersion:'v1',kind:'PersistentVolumeClaim',metadata:{name:restoreName,labels:{'helmforge.dev/runtime-fixture':'true'}},spec:{accessModes:original.spec.accessModes,resources:original.spec.resources,...(original.spec.storageClassName!==undefined?{storageClassName:original.spec.storageClassName}:{})}};
 const copy={apiVersion:'v1',kind:'Pod',metadata:{name:'workspace-recovery',labels:{'helmforge.dev/runtime-fixture':'true'}},spec:{restartPolicy:'Never',automountServiceAccountToken:false,securityContext:deployment.spec.template.spec.securityContext,containers:[{name:'restore',image:deployment.spec.template.spec.containers[0].image,command:['/bin/sh','-ceu','tar -czf /tmp/workspace.tar.gz -C /source .; tar -xzf /tmp/workspace.tar.gz -C /recovered; test -d /recovered/data; echo workspace-archive-restored'],securityContext:values.securityContext,resources:{requests:{cpu:'50m',memory:'64Mi'},limits:{cpu:'500m',memory:'256Mi'}},volumeMounts:[{name:'source',mountPath:'/source',readOnly:true},{name:'recovered',mountPath:'/recovered'},{name:'tmp',mountPath:'/tmp'}]}],volumes:[{name:'source',persistentVolumeClaim:{claimName:claim}},{name:'recovered',persistentVolumeClaim:{claimName:restoreName}},{name:'tmp',emptyDir:{sizeLimit:'1Gi'}}]}};
 for(const object of [pvc,copy])execFileSync('kubectl',['--context',context,'-n',namespace,'apply','-f','-'],{input:JSON.stringify(object),encoding:'utf8',timeout:30000});
 k(['wait','pod/workspace-recovery','--for=jsonpath={.status.phase}=Succeeded','--timeout=60s']);
 assert.ok(k(['logs','workspace-recovery']).includes('workspace-archive-restored'));
 k(['delete','pod/workspace-recovery','--wait=true','--timeout=30s']);
 execFileSync('helm',['upgrade',release,fileURLToPath(new URL('..',import.meta.url)),'--kube-context',context,'-n',namespace,'--reuse-values','--set','persistence.existingClaim='+restoreName,'--wait','--timeout','60s'],{encoding:'utf8',timeout:75000});
 await forward(base=>authenticated(base,async api=>{assert.equal((await api('/api/export/exportMdContent',{id:document,yfm:false,addTitle:false})).content,originalContent,'Fresh PVC recovery must retain complete Unicode document');}));
 console.log('PASS quiesced full-workspace archive restored into a fresh PVC, native login and identical document export');
}

console.log('PASS native login, anonymous rejection, notebook/document create/read/delete, Unicode export'+(values.persistence.enabled?', durable content across pod replacement':'')+', retained access code on Helm upgrade');
