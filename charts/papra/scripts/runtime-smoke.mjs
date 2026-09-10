// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {execFileSync,spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const [context,namespace,release]=process.argv.slice(2);assert.match(context??'',/^k3d-/);assert.ok(namespace&&release);
const k=args=>execFileSync('kubectl',['--context',context,'-n',namespace,...args],{encoding:'utf8',timeout:100000});
const values=JSON.parse(execFileSync('helm',['get','values',release,'-n',namespace,'--kube-context',context,'-a','-o','json'],{encoding:'utf8'}));
const selector=`app.kubernetes.io/instance=${release},app.kubernetes.io/name=papra`;
const deployment=JSON.parse(k(['get','deploy','-l',selector,'-o','json'])).items[0];assert.ok(deployment);
const authName=deployment.spec.template.spec.containers[0].env.find(e=>e.name==='AUTH_SECRET').valueFrom.secretKeyRef.name;
const bootstrapName=deployment.spec.template.spec.volumes.find(v=>v.name==='bootstrap-auth').secret.secretName;
const secret=name=>JSON.parse(k(['get','secret',name,'-o','json'])).data;
const authSecret=secret(authName),bootstrapSecret=secret(bootstrapName);
const password=Buffer.from(bootstrapSecret[values.bootstrap.passwordKey],'base64').toString();
const pod=()=>JSON.parse(k(['get','pods','-l',selector,'-o','json'])).items.find(p=>!p.metadata.deletionTimestamp).metadata.name;
async function forward(test){
 const child=spawn('kubectl',['--context',context,'-n',namespace,'port-forward','pod/'+pod(),':'+values.server.port,'--address=127.0.0.1'],{windowsHide:true,stdio:['ignore','pipe','pipe']});let output='';for(const stream of [child.stdout,child.stderr])stream.on('data',b=>output+=b);
 try{const deadline=Date.now()+20000;while(!/127\.0\.0\.1:(\d+) ->/.test(output)&&Date.now()<deadline&&child.exitCode===null)await new Promise(r=>setTimeout(r,100));const port=output.match(/127\.0\.0\.1:(\d+) ->/)?.[1];assert.ok(port);await test('http://127.0.0.1:'+port);}
 finally{if(process.platform==='win32'&&child.exitCode===null){try{execFileSync('taskkill',['/PID',String(child.pid),'/T','/F'],{stdio:'ignore'});}catch(error){let gone=false;try{process.kill(child.pid,0);}catch(e){if(e.code==='ESRCH')gone=true;else throw e;}if(!gone)throw error;}}else child.kill();}
}
let cookie,organizationId,documentId,userId;
const smallContent=Buffer.from('HelmForge persistent invoice\nDocument reference: HFPAPRA2026\nUnicode: ação 日本語\n');
const content=deployment.metadata.name==='papra-s3'?Buffer.concat([smallContent,Buffer.alloc(9*1024*1024,32)]):smallContent;
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const api=(base,path,{method='GET',body,anonymous=false}={})=>fetch(base+path,{method,headers:{Origin:values.server.publicUrl,...(!anonymous&&cookie?{Cookie:cookie}:{}),...(body&&!(body instanceof FormData)?{'Content-Type':'application/json'}:{})},...(body?{body:body instanceof FormData?body:JSON.stringify(body)}:{}),redirect:'manual',signal:AbortSignal.timeout(20000)});
async function login(base){const response=await api(base,'/api/auth/sign-in/email',{method:'POST',anonymous:true,body:{email:values.bootstrap.email,password}});assert.equal(response.status,200,'Native password login');assert.ok(response.headers.getSetCookie().some(c=>/HttpOnly/i.test(c)));cookie=response.headers.getSetCookie().map(c=>c.split(';')[0]).join('; ');assert.ok(cookie);const me=await api(base,'/api/users/me');assert.equal(me.status,200);const {user}=await me.json();assert.ok(user.permissions.includes('bo:access'));if(userId)assert.equal(user.id,userId);else userId=user.id;}
async function verifyDocument(base){const response=await api(base,`/api/organizations/${organizationId}/documents/${documentId}`);assert.equal(response.status,200);const {document}=await response.json();assert.equal(document.originalSha256Hash,hash(content));const file=await api(base,`/api/organizations/${organizationId}/documents/${documentId}/file`);assert.equal(file.status,200);assert.equal(hash(Buffer.from(await file.arrayBuffer())),hash(content));}
async function waitForSearch(base){
 const deadline=Date.now()+60000;let found=false;
 while(Date.now()<deadline){const response=await api(base,`/api/organizations/${organizationId}/documents?searchQuery=HFPAPRA2026`);assert.equal(response.status,200);const data=await response.json();if(data.documents?.some(d=>d.id===documentId)){found=true;break;}await new Promise(r=>setTimeout(r,1000));}
 if(!found){const {readExtractionJob}=await import('./queue-smoke.mjs');const job=readExtractionJob({k,pod,documentId});throw new Error('Native extraction/search failed; job status='+job.status+'; error='+(job.error??'none'));}
}
await forward(async base=>{
 const health=await api(base,'/api/health',{anonymous:true});assert.equal(health.status,200);assert.equal((await health.json()).isDatabaseHealthy,true);
 await login(base);
 if(!values.auth.allowRegistration){const response=await api(base,'/api/auth/sign-up/email',{method:'POST',anonymous:true,body:{email:'unapproved@example.test',name:'Unapproved',password:'fixture-only-password'}});assert.equal(response.status,400);assert.equal((await response.json()).code,'EMAIL_PASSWORD_SIGN_UP_DISABLED');}
 else{
  const signup=await api(base,'/api/auth/sign-up/email',{method:'POST',anonymous:true,body:{email:'member@example.test',name:'Fixture Member',password:'fixture-only-member-password'}});assert.equal(signup.status,200);const memberCookie=signup.headers.getSetCookie().map(c=>c.split(';')[0]).join('; ');assert.ok(memberCookie);
  const response=await fetch(base+'/api/users/me',{headers:{Cookie:memberCookie}});assert.equal(response.status,200);const member=(await response.json()).user;assert.equal(member.email,'member@example.test');assert.equal(member.permissions.includes('bo:access'),false,'Subsequent registrations must not become administrator');
 }
 const organization=await api(base,'/api/organizations',{method:'POST',body:{name:'HelmForge validation'}});assert.equal(organization.status,200);organizationId=(await organization.json()).organization.id;assert.ok(organizationId);
 const form=new FormData();form.append('file',new Blob([content],{type:'text/plain'}),'helmforge-invoice.txt');
 const upload=await api(base,`/api/organizations/${organizationId}/documents`,{method:'POST',body:form});assert.equal(upload.status,200);documentId=(await upload.json()).document.id;assert.ok(documentId);
 await verifyDocument(base);
 const denied=await api(base,`/api/organizations/${organizationId}/documents/${documentId}/file`,{anonymous:true});assert.ok([401,403].includes(denied.status),'Anonymous original download denied');
 if(values.tasks.workerEnabled)await waitForSearch(base);
});
if(deployment.metadata.name==='papra-queue'){
 const {verifyPendingQueue}=await import('./queue-smoke.mjs');
 await verifyPendingQueue({k,pod,documentId,deployment,context,namespace,release,chartPath:fileURLToPath(new URL('..',import.meta.url)),forward,verifyDocument,waitForSearch});
}
if(values.persistence.enabled){k(['rollout','restart','deployment/'+deployment.metadata.name]);k(['rollout','status','deployment/'+deployment.metadata.name,'--timeout=90s']);await forward(async base=>{const session=await api(base,'/api/users/me');assert.equal(session.status,200,'Persisted native session after replacement');await verifyDocument(base);await login(base);});}
execFileSync('helm',['upgrade',release,fileURLToPath(new URL('..',import.meta.url)),'--kube-context',context,'-n',namespace,'--reuse-values','--wait','--timeout','60s'],{encoding:'utf8',timeout:75000});assert.deepEqual(secret(authName),authSecret);assert.deepEqual(secret(bootstrapName),bootstrapSecret);
if(deployment.metadata.name==='papra-restore'){
 assert.equal(values.database.remoteUrl,'');assert.equal(values.storage.driver,'filesystem');
 const originalPod=pod(),claim=deployment.spec.template.spec.volumes.find(v=>v.name==='workspace').persistentVolumeClaim.claimName;
 k(['scale','deployment/'+deployment.metadata.name,'--replicas=0']);k(['wait','--for=delete','pod/'+originalPod,'--timeout=60s']);
 const original=JSON.parse(k(['get','pvc',claim,'-o','json'])),restoreName=deployment.metadata.name+'-recovered';
 const pvc={apiVersion:'v1',kind:'PersistentVolumeClaim',metadata:{name:restoreName,labels:{'helmforge.dev/runtime-fixture':'true'}},spec:{accessModes:original.spec.accessModes,resources:original.spec.resources,...(original.spec.storageClassName!==undefined?{storageClassName:original.spec.storageClassName}:{})}};
 const copy={apiVersion:'v1',kind:'Pod',metadata:{name:'papra-recovery',labels:{'helmforge.dev/runtime-fixture':'true'}},spec:{restartPolicy:'Never',automountServiceAccountToken:false,securityContext:deployment.spec.template.spec.securityContext,containers:[{name:'restore',image:deployment.spec.template.spec.containers[0].image,command:['/bin/sh','-ceu','tar -czf /tmp/papra.tar.gz -C /source db documents; tar --no-same-owner --no-overwrite-dir -xzf /tmp/papra.tar.gz -C /recovered; test -s /recovered/db/db.sqlite; echo papra-archive-restored'],securityContext:values.securityContext,resources:{requests:{cpu:'50m',memory:'64Mi'},limits:{cpu:'500m',memory:'256Mi'}},volumeMounts:[{name:'source',mountPath:'/source',readOnly:true},{name:'recovered',mountPath:'/recovered'},{name:'tmp',mountPath:'/tmp'}]}],volumes:[{name:'source',persistentVolumeClaim:{claimName:claim}},{name:'recovered',persistentVolumeClaim:{claimName:restoreName}},{name:'tmp',emptyDir:{sizeLimit:'1Gi'}}]}};
 for(const object of [pvc,copy])execFileSync('kubectl',['--context',context,'-n',namespace,'apply','-f','-'],{input:JSON.stringify(object),encoding:'utf8',timeout:30000});
 k(['wait','pod/papra-recovery','--for=jsonpath={.status.phase}=Succeeded','--timeout=60s']);assert.ok(k(['logs','papra-recovery']).includes('papra-archive-restored'));k(['delete','pod/papra-recovery','--wait=true','--timeout=30s']);
 execFileSync('helm',['upgrade',release,fileURLToPath(new URL('..',import.meta.url)),'--kube-context',context,'-n',namespace,'--reuse-values','--set','persistence.existingClaim='+restoreName,'--wait','--timeout','60s'],{encoding:'utf8',timeout:75000});
 await forward(async base=>{const session=await api(base,'/api/users/me');assert.equal(session.status,200);await login(base);await verifyDocument(base);});
 console.log('PASS quiesced encrypted database and documents restored into a fresh PVC with retained keys, account, session and exact original checksum');
}
if(values.database.encryptionSecret||values.storage.encryptionSecret){
 const proof=`
 const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
 const {createClient}=require('@libsql/client');
 (async()=>{
 const db=createClient({url:process.env.DATABASE_URL,authToken:process.env.DATABASE_AUTH_TOKEN,encryptionKey:process.env.DATABASE_ENCRYPTION_KEY});
 try{
 const result=await db.execute({sql:'SELECT original_storage_key,file_encryption_key_wrapped,file_encryption_kek_version,file_encryption_algorithm FROM documents WHERE id=?',args:[${JSON.stringify(documentId)}]});
 assert.equal(result.rows.length,1);const row=result.rows[0];
 if(process.env.DOCUMENT_STORAGE_ENCRYPTION_IS_ENABLED==='true'){
  assert.ok(row.file_encryption_key_wrapped);assert.equal(row.file_encryption_algorithm,'aes-256-gcm');assert.ok(row.file_encryption_kek_version);
  if(process.env.DOCUMENT_STORAGE_DRIVER==='filesystem'){
   const root=path.resolve('/app/app-data/documents');const file=path.resolve(root,row.original_storage_key);assert.ok(file.startsWith(root+path.sep));
   assert.equal(fs.readFileSync(file).includes(Buffer.from('HFPAPRA2026')),false,'Original must be encrypted on disk');
  }else{
   const {S3mini}=await import('s3mini');const endpoint=process.env.DOCUMENT_STORAGE_S3_ENDPOINT.replace(/\\/$/,'')+'/'+process.env.DOCUMENT_STORAGE_S3_BUCKET_NAME;
   const s3=new S3mini({endpoint,region:process.env.DOCUMENT_STORAGE_S3_REGION,accessKeyId:process.env.DOCUMENT_STORAGE_S3_ACCESS_KEY_ID,secretAccessKey:process.env.DOCUMENT_STORAGE_S3_SECRET_ACCESS_KEY});
   const object=await s3.getObjectResponse(row.original_storage_key);assert.equal(object.status,200);assert.equal(Buffer.from(await object.arrayBuffer()).includes(Buffer.from('HFPAPRA2026')),false,'S3 object must contain ciphertext');
   const anonymous=await fetch(endpoint+'/'+row.original_storage_key);assert.equal(anonymous.status,403,'Physical S3 object must reject unsigned download');
   console.log('PASS signed physical S3 object read, original ciphertext and anonymous S3 denial');
  }
 }
 if(process.env.DATABASE_ENCRYPTION_KEY){
  const source='/app/app-data/db/db.sqlite';const header=fs.readFileSync(source);
  assert.notEqual(header.subarray(0,16).toString(),'SQLite format 3\\0');assert.equal(header.includes(Buffer.from('HFPAPRA2026')),false);
  const target=fs.mkdtempSync('/tmp/papra-encryption-proof-');fs.copyFileSync(source,path.join(target,'snapshot.sqlite'));
  for(const encryptionKey of [undefined,'deliberately-wrong-fixture-key']){
   let denied=false,other;try{other=createClient({url:'file:'+path.join(target,'snapshot.sqlite'),encryptionKey});await other.execute('SELECT COUNT(*) FROM users');}catch{denied=true;}finally{other?.close();}
   assert.ok(denied,'Missing or wrong key must reject encrypted database');
  }
  const check=await db.execute('PRAGMA integrity_check');assert.equal(check.rows[0].integrity_check,'ok');
  console.log('PASS encrypted database integrity and missing/wrong-key rejection');
 }
 }finally{db.close();}
 console.log('PASS native document encryption metadata and storage ciphertext');
 })().catch(error=>{console.error(error.message);process.exitCode=1;});`;
 console.log(k(['exec',pod(),'-c','papra','--','node','-e',proof]).trim());
}
console.log('PASS protected native administrator, closed registration, organization/document creation, exact original checksum, extraction/search, anonymous denial, retained credentials and persistent session/document across replacement');
