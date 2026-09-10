// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync, spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {readFileSync} from 'node:fs';
const [context, namespace, release] = process.argv.slice(2);
assert.match(context ?? '', /^k3d-/); assert.ok(namespace && release);
const k = args => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {encoding:'utf8', timeout:90000});
const values = JSON.parse(execFileSync('helm', ['get','values',release,'-n',namespace,'--kube-context',context,'-a','-o','json'], {encoding:'utf8'}));
const selector = `app.kubernetes.io/instance=${release},app.kubernetes.io/component=server`;
const deployment = JSON.parse(k(['get','deploy','-l',selector,'-o','json'])).items[0]; assert.ok(deployment);
const secretData = name => JSON.parse(k(['get','secret',name,'-o','json'])).data;
const volumes = deployment.spec.template.spec.volumes;
const jwtName = volumes.find(v => v.name === 'auth').secret.secretName;
const originalJwt = secretData(jwtName);
const bootstrapName = volumes.find(v => v.name === 'bootstrap').secret.secretName;
const originalBootstrap = secretData(bootstrapName);
const password = Buffer.from(originalBootstrap[values.bootstrap.passwordKey], 'base64').toString();
if (values.externalSecrets.enabled) assert.ok(JSON.parse(k(['get','externalsecrets','-o','json'])).items.every(e => e.status?.conditions?.some(c => c.type === 'Ready' && c.status === 'True')));
const pod = () => JSON.parse(k(['get','pods','-l',selector,'-o','json'])).items.find(p => !p.metadata.deletionTimestamp).metadata.name;
async function forward(test) {
 const child = spawn('kubectl', ['--context',context,'-n',namespace,'port-forward','pod/'+pod(),':5000','--address=127.0.0.1'], {windowsHide:true, stdio:['ignore','pipe','pipe']});
 let out = ''; for (const stream of [child.stdout,child.stderr]) stream.on('data', b => out += b);
 try {
  const deadline = Date.now()+20000;
  while (!/127\.0\.0\.1:(\d+) ->/.test(out) && Date.now()<deadline && child.exitCode===null) await new Promise(r => setTimeout(r,100));
  const port=out.match(/127\.0\.0\.1:(\d+) ->/)?.[1]; assert.ok(port);
  await test('http://127.0.0.1:'+port+values.server.basePath);
 } finally {
  if (process.platform==='win32' && child.exitCode===null) {
   try { execFileSync('taskkill',['/PID',String(child.pid),'/T','/F'],{stdio:'ignore'}); }
   catch(error) { let gone=false; try {process.kill(child.pid,0);} catch(e) {if(e.code==='ESRCH')gone=true;else throw e;} if(!gone)throw error; }
  } else child.kill();
 }
}
let token, snippetId;
const marker = 'Persistent Unicode: ação 日本語';
function client(base) {
 return async (path, {method='GET',body,auth=true,status=200,headers={}}={}) => {
  const response = await fetch(base+path,{method,headers:{'Content-Type':'application/json',...(auth?{bytestashauth:'Bearer '+token}:{}),...headers},...(body?{body:JSON.stringify(body)}:{}),signal:AbortSignal.timeout(15000)});
  assert.equal(response.status,status,method+' '+path); return response.json();
 };
}
await forward(async base => {
 const api = client(base);
 const config = await api('/api/auth/config',{auth:false}); assert.equal(config.hasUsers,true); assert.equal(config.allowNewAccounts,values.auth.allowNewAccounts);
 if (!values.auth.allowNewAccounts) await api('/api/auth/register',{method:'POST',auth:false,status:403,body:{username:'takeover',password:'fixture-password'}});
 await api('/api/snippets',{auth:false,status:401});
 const login = await api('/api/auth/login',{method:'POST',auth:false,body:{username:values.bootstrap.username,password}}); token=login.token; assert.ok(token); assert.equal(login.user.is_admin,true);
 const snippet = await api('/api/snippets',{method:'POST',status:201,body:{title:'HelmForge fixture',description:marker,categories:['validation'],fragments:[{file_name:'fixture.txt',code:marker,language:'plaintext'}]}}); snippetId=snippet.id; assert.ok(snippetId);
 const listing = await api('/api/snippets'); assert.ok(listing.data.some(s=>s.id===snippetId&&s.fragments.some(f=>f.code===marker)));
 const key = await api('/api/keys',{method:'POST',status:201,body:{name:'runtime-fixture'}}); assert.ok(key.key);
 const mcp = await api('/mcp',{method:'POST',auth:false,headers:{Accept:'application/json, text/event-stream','x-api-key':key.key},body:{jsonrpc:'2.0',id:1,method:'tools/list',params:{}}}); assert.ok(mcp.result.tools.some(t=>t.name==='list_snippets'));
 await api('/api/keys/'+key.id,{method:'DELETE'});
 await api('/mcp',{method:'POST',auth:false,status:401,headers:{Accept:'application/json, text/event-stream','x-api-key':key.key},body:{jsonrpc:'2.0',id:2,method:'tools/list',params:{}}});
});
if (values.persistence.enabled) {
 k(['rollout','restart','deployment/'+deployment.metadata.name]); k(['rollout','status','deployment/'+deployment.metadata.name,'--timeout=90s']);
 await forward(async base => {const api=client(base); assert.equal((await api('/api/auth/verify')).valid,true); const list=await api('/api/snippets'); assert.ok(list.data.some(s=>s.id===snippetId&&s.fragments.some(f=>f.code===marker))); const login=await api('/api/auth/login',{method:'POST',auth:false,body:{username:values.bootstrap.username,password}}); assert.equal(login.user.is_admin,true);});
}
execFileSync('helm',['upgrade',release,fileURLToPath(new URL('..',import.meta.url)),'--kube-context',context,'-n',namespace,'--reuse-values','--wait','--timeout','60s'],{encoding:'utf8',timeout:75000});
assert.deepEqual(secretData(jwtName),originalJwt); assert.deepEqual(secretData(bootstrapName),originalBootstrap);
if(values.oidc.enabled){const output=k(['exec',pod(),'-c','oidc-fixture','--','node','-e',readFileSync(new URL('./oidc-fixture-client.cjs',import.meta.url),'utf8')]);assert.ok(output.includes('PASS native OIDC'));console.log(output.trim());}
if (values.backup.enabled) {
 const cron=JSON.parse(k(['get','cronjobs','-o','json'])).items[0]; assert.ok(cron);
 for(let i=0;i<3;i++) {const job='snapshot-'+i;k(['create','job',job,'--from=cronjob/'+cron.metadata.name]);k(['wait','--for=condition=Complete','job/'+job,'--timeout=60s']);assert.ok(k(['logs','job/'+job]).includes('SQLite online snapshot verified'));k(['delete','job/'+job,'--wait=true','--timeout=30s']);}
 const originalPod=pod(); k(['scale','deployment/'+deployment.metadata.name,'--replicas=0']);k(['wait','--for=delete','pod/'+originalPod,'--timeout=60s']);
 const originalClaim=JSON.parse(k(['get','pvc',volumes.find(v=>v.name==='workspace').persistentVolumeClaim.claimName,'-o','json']));
 const restored=deployment.metadata.name+'-restored';
 const pvc={apiVersion:'v1',kind:'PersistentVolumeClaim',metadata:{name:restored},spec:{accessModes:originalClaim.spec.accessModes,resources:originalClaim.spec.resources,storageClassName:originalClaim.spec.storageClassName}};
 const backupClaim=cron.spec.jobTemplate.spec.template.spec.volumes.find(v=>v.name==='backups').persistentVolumeClaim.claimName;
 const script="const fs=require('fs');const files=fs.readdirSync('/backups').filter(f=>f.endsWith('.db')).sort();if(files.length!==2)throw Error('retention failed');fs.copyFileSync('/backups/'+files.at(-1),'/restored/snippets.db');console.log('verified snapshot restored');";
 const copy={apiVersion:'v1',kind:'Pod',metadata:{name:'snapshot-restore'},spec:{restartPolicy:'Never',automountServiceAccountToken:false,securityContext:values.podSecurityContext,containers:[{name:'restore',image:deployment.spec.template.spec.containers[0].image,command:['node','-e',script],securityContext:values.securityContext,resources:values.backup.resources,volumeMounts:[{name:'backups',mountPath:'/backups',readOnly:true},{name:'restored',mountPath:'/restored'}]}],volumes:[{name:'backups',persistentVolumeClaim:{claimName:backupClaim}},{name:'restored',persistentVolumeClaim:{claimName:restored}}]}};
 for(const object of [pvc,copy]) execFileSync('kubectl',['--context',context,'-n',namespace,'apply','-f','-'],{input:JSON.stringify(object),encoding:'utf8',timeout:30000});
 k(['wait','pod/snapshot-restore','--for=jsonpath={.status.phase}=Succeeded','--timeout=60s']);assert.ok(k(['logs','snapshot-restore']).includes('verified snapshot restored'));k(['delete','pod/snapshot-restore','--wait=true','--timeout=30s']);
 execFileSync('helm',['upgrade',release,fileURLToPath(new URL('..',import.meta.url)),'--kube-context',context,'-n',namespace,'--reuse-values','--set','persistence.existingClaim='+restored,'--wait','--timeout','60s'],{encoding:'utf8',timeout:75000});
 await forward(async base=>{const api=client(base);assert.equal((await api('/api/auth/verify')).valid,true);const list=await api('/api/snippets');assert.ok(list.data.some(s=>s.id===snippetId&&s.fragments.some(f=>f.code===marker)));});
 console.log('PASS three verified online snapshots, retention of two copies, fresh PVC restore, original JWT and Unicode content');
}
console.log('PASS protected administrator bootstrap, registration denial, authenticated Unicode snippets, native MCP API key and revocation, retained credentials'+(values.persistence.enabled?', persistent data and JWT session across pod replacement':''));
