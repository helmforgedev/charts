// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync,spawn} from 'node:child_process';
import https from 'node:https';
import {fileURLToPath} from 'node:url';
import {login} from './browser-smoke.mjs';
import {X509Certificate,createHash,randomUUID} from 'node:crypto';
import {chromium} from 'playwright';
const [context,namespace,release]=process.argv.slice(2);
assert.equal(context,'k3d-helmforge-tests-wsl');assert.ok(namespace&&release);
const k=args=>execFileSync('kubectl',['--context',context,'-n',namespace,...args],{encoding:'utf8',timeout:100000});
const values=JSON.parse(execFileSync('helm',['get','values',release,'-n',namespace,'--kube-context',context,'-a','-o','json'],{encoding:'utf8'}));
const deployment=JSON.parse(k(['get','deploy','-l','app.kubernetes.io/instance='+release+',app.kubernetes.io/name=opencloud','-o','json'])).items[0];
assert.ok(deployment);
if(values.externalSecrets.enabled){for(const item of values.externalSecrets.items){const name=item.fullnameOverride;assert.ok(name);k(['wait','externalsecret/'+name,'--for=condition=Ready=True','--timeout=60s']);}console.log('PASS ExternalSecret Ready and application consumes the synchronized bootstrap Secret');}
const origin=values.server.publicUrl||'https://'+deployment.metadata.name+'.'+namespace+'.svc:'+values.service.port;
const address=new URL(origin);
assert.equal(Number(address.port||443),Number(values.server.port),'Native TLS fixture forwards the canonical issuer port');
const volumes=deployment.spec.template.spec.volumes;
const readSecret=name=>JSON.parse(k(['get','secret',name,'-o','json'])).data;
const auth=readSecret(volumes.find(v=>v.name==='bootstrap-auth').secret.secretName);
const password=Buffer.from(auth[values.bootstrap.passwordKey],'base64').toString();
const tls=readSecret(volumes.find(v=>v.name==='tls').secret.secretName);
const ca=Buffer.from(tls['ca.crt'],'base64');
const certificate=new X509Certificate(Buffer.from(tls['tls.crt'],'base64'));
if(values.gatewayAPI.enabled&&values.server.tls.enabled){
 const policy=JSON.parse(k(['get','backendtlspolicy',deployment.metadata.name,'-o','json']));assert.equal(policy.spec.validation.hostname,address.hostname);assert.equal(policy.spec.targetRefs[0].name,deployment.metadata.name);
 if(!values.server.tls.existingSecret){const name=policy.spec.validation.caCertificateRefs[0].name;const config=JSON.parse(k(['get','configmap',name,'-o','json']));const root=new X509Certificate(config.data['ca.crt']);assert.ok(root.ca);assert.ok(certificate.verify(root.publicKey));assert.equal(config.data['ca.crt'],ca.toString());console.log('PASS Gateway backend TLS policy uses the actual native certificate CA and canonical DNS identity');}
}
const spki=createHash('sha256').update(certificate.publicKey.export({type:'spki',format:'der'})).digest('base64');

const selector='app.kubernetes.io/instance='+release+',app.kubernetes.io/name=opencloud';
const pod=()=>JSON.parse(k(['get','pods','-l',selector,'-o','json'])).items.find(p=>!p.metadata.deletionTimestamp).metadata.name;
const fingerprint=()=>k(['exec',pod(),'-c','opencloud','--','sha256sum','/etc/opencloud/opencloud.yaml','/var/lib/opencloud/idp/encryption.key','/var/lib/opencloud/idp/private-key.pem']);
const originalFingerprint=fingerprint();
async function forward(test,port=values.server.port,target='pod/'+pod()){
 const child=spawn('kubectl',['--context',context,'-n',namespace,'port-forward',target,(port===values.server.port?port:0)+':'+port,'--address=127.0.0.1'],{windowsHide:true,stdio:['ignore','pipe','pipe']});
 let output='';for(const stream of [child.stdout,child.stderr])stream.on('data',b=>output+=b);
 try{const deadline=Date.now()+20000;while(!output.includes('Forwarding from')&&Date.now()<deadline&&child.exitCode===null)await new Promise(r=>setTimeout(r,100));const match=output.match(/Forwarding from 127\.0\.0\.1:(\d+)/);assert.ok(match,output);return await test('http://127.0.0.1:'+match[1]);}
 finally{if(child.exitCode===null&&child.signalCode===null){if(process.platform==='win32')execFileSync('taskkill',['/PID',String(child.pid),'/T','/F'],{stdio:'ignore'});else child.kill();}}
}
const request=(path,{token,method='GET',body,trust=true}={})=>new Promise((resolve,reject)=>{
 const req=https.request({hostname:'127.0.0.1',servername:address.hostname,port:values.server.port,path,method,agent:false,ca:trust?ca:undefined,headers:{Host:address.host,...(token?{Authorization:'Bearer '+token}:{}),...(body?{'Content-Type':'text/plain','If-None-Match':'*'}:{})},timeout:10000},response=>{const chunks=[];response.on('data',b=>chunks.push(b));response.on('end',()=>resolve({status:response.statusCode,body:Buffer.concat(chunks)}));});req.on('error',reject);req.on('timeout',()=>req.destroy(new Error('TLS request timed out')));req.end(body);
});
let browser,oidc,identityId,oidcSubject,filePath;
const payload=Buffer.from('HelmForge native OIDC and persistent WebDAV fixture\n');
async function authenticated(){
 const session=await login({browser,origin,oidc,password,request});
 const userinfo=await request(new URL(oidc.userinfo_endpoint).pathname,{token:session.token});assert.equal(userinfo.status,200);assert.equal(JSON.parse(userinfo.body).sub,session.subject);
 if(oidcSubject)assert.equal(session.subject,oidcSubject);else oidcSubject=session.subject;
 const response=await request('/graph/v1.0/me',{token:session.token});assert.equal(response.status,200);const identity=JSON.parse(response.body);assert.ok(identity.id);assert.equal(identity.onPremisesSamAccountName,'admin');
 if(identityId)assert.equal(identity.id,identityId);else identityId=identity.id;
 return session.token;
}
async function verifyFile(token){const response=await request(filePath,{token});assert.equal(response.status,200);assert.deepEqual(response.body,payload);assert.notEqual((await request(filePath)).status,200);assert.notEqual((await request(filePath,{token:'owned-invalid-token'})).status,200);}
try{
 browser=await chromium.launch({headless:true,args:['--no-proxy-server','--host-resolver-rules=MAP '+address.hostname+' 127.0.0.1','--ignore-certificate-errors-spki-list='+spki]});
 await forward(async()=>{
  const response=await request('/.well-known/openid-configuration');assert.equal(response.status,200);oidc=JSON.parse(response.body);assert.equal(oidc.issuer,origin);
  for(const key of ['authorization_endpoint','token_endpoint','jwks_uri','userinfo_endpoint'])assert.equal(new URL(oidc[key]).origin,origin);
  await assert.rejects(request('/.well-known/openid-configuration',{trust:false}));assert.notEqual((await request('/graph/v1.0/me')).status,200);
  await login({browser,origin,oidc,password,request,wrong:true});
  const token=await authenticated(),drives=await request('/graph/v1.0/me/drives',{token});assert.equal(drives.status,200);const drive=JSON.parse(drives.body).value.find(d=>d.driveType==='personal');assert.ok(drive?.root?.webDavUrl);const dav=new URL(drive.root.webDavUrl);assert.equal(dav.origin,origin);
  filePath=dav.pathname.replace(/\/$/,'')+'/'+encodeURIComponent('helmforge-'+randomUUID()+'.txt');assert.ok([201,204].includes((await request(filePath,{token,method:'PUT',body:payload})).status));await verifyFile(token);
 });
 if(values.persistence.enabled){
  k(['rollout','restart','deployment/'+deployment.metadata.name]);k(['rollout','status','deployment/'+deployment.metadata.name,'--timeout=90s']);assert.equal(fingerprint(),originalFingerprint);
  await forward(async()=>await verifyFile(await authenticated()));
  console.log('PASS native identity keys, fresh OIDC login and private WebDAV content survive pod replacement');
 }
 if(deployment.metadata.name==='opencloud-restore'){
  k(['exec',pod(),'-c','opencloud','--','/bin/sh','-ceu','printf fixture > /var/lib/opencloud/.helmforge-recovery-sentinel; setfattr -n user.helmforge_recovery -v retained-xattr /var/lib/opencloud/.helmforge-recovery-sentinel']);
  const {restore}=await import('./restore-smoke.mjs');restore({k,context,namespace,release,chartPath:fileURLToPath(new URL('..',import.meta.url)),deployment,pod,values});assert.equal(fingerprint(),originalFingerprint);
  assert.equal(k(['exec',pod(),'-c','opencloud','--','getfattr','--only-values','-n','user.helmforge_recovery','/var/lib/opencloud/.helmforge-recovery-sentinel']).trim(),'retained-xattr');
  await forward(async()=>await verifyFile(await authenticated()));console.log('PASS fresh-PVC archive recovery preserves extended attributes, exact identity keys, native OIDC and private file bytes');
 }
 execFileSync('helm',['upgrade',release,fileURLToPath(new URL('..',import.meta.url)),'--kube-context',context,'-n',namespace,'--reuse-values','--wait','--timeout','60s'],{encoding:'utf8',timeout:75000});assert.equal(fingerprint(),originalFingerprint);assert.deepEqual(readSecret(volumes.find(v=>v.name==='tls').secret.secretName),tls);assert.deepEqual(readSecret(volumes.find(v=>v.name==='bootstrap-auth').secret.secretName),auth);
 await forward(async()=>{const token=await authenticated();await verifyFile(token);assert.ok([200,204].includes((await request(filePath,{token,method:'DELETE'})).status));assert.equal((await request(filePath,{token})).status,404);});
 if(values.metrics.enabled){const {verifyMetrics}=await import('./metrics-smoke.mjs');await verifyMetrics({k,forward,values,namespace,deployment,readSecret});}
 console.log('PASS trusted TLS, native OIDC and Graph identity, private WebDAV CRUD, retained configuration and upgrade');
}catch(error){console.error(String(error.stack??error).replaceAll(password,'[REDACTED]'));throw new Error('OpenCloud runtime verification failed; see sanitized diagnostic');}finally{await browser?.close();}
