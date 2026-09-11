// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync,spawn} from 'node:child_process';
import {randomUUID} from 'node:crypto';
import {collaboration} from './collaboration-smoke.mjs';
import {fileURLToPath} from 'node:url';
const [context,namespace,release]=process.argv.slice(2);assert.equal(context,'k3d-helmforge-tests-wsl');
const k=args=>execFileSync('kubectl',['--context',context,'-n',namespace,...args],{encoding:'utf8',timeout:100000});
const values=JSON.parse(execFileSync('helm',['get','values',release,'--kube-context',context,'-n',namespace,'-a','-o','json'],{encoding:'utf8'}));
const selector='app.kubernetes.io/instance='+release+',app.kubernetes.io/name=affine';
const deployment=JSON.parse(k(['get','deployment','-l',selector,'-o','json'])).items[0];assert.ok(deployment);
const pod=()=>JSON.parse(k(['get','pods','-l',selector,'-o','json'])).items.find(p=>!p.metadata.deletionTimestamp).metadata.name;
const secretName=deployment.spec.template.spec.volumes.find(v=>v.name==='bootstrap-auth').secret.secretName;
const secret=JSON.parse(k(['get','secret',secretName,'-o','json']));const password=Buffer.from(secret.data[values.bootstrap.passwordKey],'base64').toString();
const origin=values.server.publicUrl||'http://'+deployment.metadata.name+'.'+namespace+'.svc:'+values.service.port;
let cookies=new Map(),workspace,blobPath;const bytes=Buffer.from('AFFiNE native GraphQL private workspace and multipart blob fixture\n');
const keyHash=()=>k(['exec',pod(),'-c','affine','--','sha256sum','/home/node/.affine/config/private.key']);const originalKey=keyHash();
async function forward(test,port=values.server.port,target){const child=spawn('kubectl',['--context',context,'-n',namespace,'port-forward',target??'pod/'+pod(),'0:'+port,'--address=127.0.0.1'],{windowsHide:true,stdio:['ignore','pipe','pipe']});let output='';for(const stream of [child.stdout,child.stderr])stream.on('data',b=>output+=b);try{const deadline=Date.now()+20000;while(!/Forwarding from/.test(output)&&Date.now()<deadline&&child.exitCode===null)await new Promise(r=>setTimeout(r,100));const match=output.match(/127\.0\.0\.1:(\d+)/);assert.ok(match,output);return await test('http://127.0.0.1:'+match[1]);}finally{if(child.exitCode===null&&child.signalCode===null){if(process.platform==='win32')execFileSync('taskkill',['/PID',String(child.pid),'/T','/F'],{stdio:'ignore'});else child.kill();}}}
function client(base){return async(path,{method='GET',json,body,anonymous=false,headers={}}={})=>{const response=await fetch(base+path,{method,headers:{Host:new URL(origin).host,Origin:origin,...(!anonymous&&cookies.size?{Cookie:[...cookies].map(([k,v])=>k+'='+v).join('; '),'x-affine-csrf-token':decodeURIComponent(cookies.get('affine_csrf_token')??'')}:{}),...(json?{'Content-Type':'application/json'}:{}),...headers},body:json?JSON.stringify(json):body,signal:AbortSignal.timeout(15000)});if(!anonymous)for(const cookie of response.headers.getSetCookie()){const pair=cookie.split(';',1)[0],i=pair.indexOf('=');cookies.set(pair.slice(0,i),pair.slice(i+1));}return response;};}
async function gql(request,query,variables={}){const response=await request('/graphql',{method:'POST',json:{query,variables}});assert.equal(response.status,200);const data=await response.json();assert.equal(data.errors,undefined,JSON.stringify(data.errors));return data.data;}
async function login(request){cookies=new Map();const wrong=await request('/api/auth/sign-in',{method:'POST',anonymous:true,json:{email:values.bootstrap.email,password:'wrong-'+randomUUID()}});assert.ok([400,401,403].includes(wrong.status));const response=await request('/api/auth/sign-in',{method:'POST',json:{email:values.bootstrap.email,password}});assert.equal(response.status,200);const user=(await gql(request,'query { currentUser { id email features } }')).currentUser;assert.equal(user.email,values.bootstrap.email);assert.ok(user.features.includes('Admin'));return user.id;}
async function verify(request){const data=await gql(request,'query($id:String!){workspace(id:$id){id public}}',{id:workspace});assert.equal(data.workspace.id,workspace);assert.equal(data.workspace.public,false);const response=await request(blobPath);assert.equal(response.status,200);assert.deepEqual(Buffer.from(await response.arrayBuffer()),bytes);const anonymous=await request(blobPath,{anonymous:true});assert.ok([401,403,404].includes(anonymous.status));}
try{
 if(deployment.metadata.name==='affine-production'){
  const pods=JSON.parse(k(['get','pods','-l','app.kubernetes.io/instance='+release,'-o','json'])).items;
  assert.ok(pods.length>=3);
  for(const item of pods)assert.ok(!(item.spec.volumes??[]).some(volume=>(volume.projected?.sources??[]).some(source=>source.serviceAccountToken)),'Production workload projects an unnecessary API token: '+item.metadata.name);
  console.log('PASS production application and bundled dependencies have no projected Kubernetes API token');
 }
 if(!values.postgresql.enabled||!values.redis.enabled)console.log(k(['exec',pod(),'-c','affine','--','node','/helmforge/tls-admission.mjs']));
 await forward(async base=>{const request=client(base);assert.equal((await gql(request,'query { serverConfig { initialized } }')).serverConfig.initialized,true);
  const setup=await request('/api/setup/create-admin-user',{method:'POST',anonymous:true,json:{email:'unrelated@example.test',password:'Owned-fixture-never-created'}});assert.equal(setup.status,403);
  const email='unrelated-'+randomUUID()+'@example.test';const preflight=await request('/api/auth/preflight',{method:'POST',anonymous:true,json:{email}});assert.equal(preflight.status,201);const methods=await preflight.json();assert.equal(methods.registered,false);assert.equal(methods.methods.magicLink.available,false);assert.equal((await request('/api/auth/sign-in',{method:'POST',anonymous:true,json:{email}})).status,403);
  await login(request);workspace=(await gql(request,'mutation { createWorkspace { id public } }')).createWorkspace.id;assert.ok(workspace);
  await gql(request,'mutation($input:UpdateWorkspaceInput!){updateWorkspace(input:$input){id public enableSharing}}',{input:{id:workspace,public:false,enableSharing:false}});
  const form=new FormData();form.set('operations',JSON.stringify({query:'mutation($workspaceId:String!,$blob:Upload!){setBlob(workspaceId:$workspaceId,blob:$blob)}',variables:{workspaceId:workspace,blob:null}}));form.set('map',JSON.stringify({'0':['variables.blob']}));form.set('0',new Blob([bytes],{type:'application/octet-stream'}),'helmforge-fixture.txt');
  const upload=await request('/graphql',{method:'POST',body:form,headers:{'Apollo-Require-Preflight':'true'}});assert.equal(upload.status,200);const result=await upload.json();assert.equal(result.errors,undefined,JSON.stringify(result.errors));assert.equal(result.data.setBlob,'helmforge-fixture.txt');blobPath='/api/workspaces/'+workspace+'/blobs/'+result.data.setBlob;await verify(request);
  const scratch=(await gql(request,'mutation { createWorkspace { id } }')).createWorkspace.id;assert.equal((await gql(request,'mutation($id:String!){deleteWorkspace(id:$id)}',{id:scratch})).deleteWorkspace,true);
  await collaboration({base,origin,cookies,workspace,k,pod,create:true});
  if(values.metrics.enabled){const {verifyMetrics}=await import('./metrics-smoke.mjs');await verifyMetrics({k,forward,values,namespace,context,deployment});}
  console.log('PASS native administrator/session, rejected setup and closed signup, GraphQL workspace CRUD, multipart blob bytes and anonymous denial');
 });
 if(values.persistence.enabled){
  if(deployment.metadata.name==='affine-restore'){const {restore}=await import('./restore-smoke.mjs');restore({k,context,namespace,release,chartPath:fileURLToPath(new URL('../',import.meta.url)),deployment,pod,values});}
  else{k(['rollout','restart','deployment/'+deployment.metadata.name]);k(['rollout','status','deployment/'+deployment.metadata.name,'--timeout=90s']);}
  assert.equal(keyHash(),originalKey);await forward(async base=>{const request=client(base);await verify(request);await login(request);await verify(request);await collaboration({base,origin,cookies,workspace,k,pod});});const logs=k(['logs',pod(),'-c','bootstrap']);assert.match(logs,/Existing identity preserved; private bootstrap HTTP server not started/);console.log('PASS exact native SEC1 key, retained session, fresh login, workspace and blob survive replacement without reopening bootstrap');
 }
}catch(error){console.error(String(error.stack??error).replaceAll(password,'[REDACTED]'));throw Error('AFFiNE native runtime verification failed');}
