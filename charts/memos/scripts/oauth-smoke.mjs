// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import https from 'node:https';
import {randomBytes,createHash} from 'node:crypto';
import {execFileSync,spawn} from 'node:child_process';

export async function oauthSmoke({context,namespace,base,api,username,memoName}){
 const k=args=>execFileSync('kubectl',['--context',context,'-n',namespace,...args],{encoding:'utf8',timeout:30000});
 const ca=Buffer.from(JSON.parse(k(['get','secret','fixture-oauth-tls','-o','json'])).data['ca.crt'],'base64');
 const child=spawn('kubectl',['--context',context,'-n',namespace,'port-forward','deployment/fixture-oauth',':8443',':8081','--address=127.0.0.1'],{windowsHide:true,stdio:['ignore','pipe','pipe']});let output='';
 for(const stream of [child.stdout,child.stderr])stream.on('data',b=>output+=b);
 try{
  const deadline=Date.now()+20000;while((!output.match(/127\.0\.0\.1:(\d+) -> 8443/)||!output.match(/127\.0\.0\.1:(\d+) -> 8081/))&&Date.now()<deadline&&child.exitCode===null)await new Promise(r=>setTimeout(r,100));
  const tlsPort=output.match(/127\.0\.0\.1:(\d+) -> 8443/)?.[1],controlPort=output.match(/127\.0\.0\.1:(\d+) -> 8081/)?.[1];assert.ok(tlsPort&&controlPort);
  const request=(url,trust=ca)=>new Promise((resolve,reject)=>{const req=https.get(url,{ca:trust,rejectUnauthorized:true},res=>{res.resume();res.on('end',()=>resolve({status:res.statusCode,headers:res.headers}));});req.on('error',reject);req.setTimeout(5000,()=>req.destroy(new Error('Issuer request timeout')));});
  await assert.rejects(request('https://127.0.0.1:'+tlsPort+'/health',null));
  const redirectUri='https://memos.example.test/auth/callback',idpName='identity-providers/hf-fixture';
  async function credentials(subject){
   assert.equal((await fetch('http://127.0.0.1:'+controlPort+'/subject?sub='+subject)).status,200);
   const verifier=randomBytes(48).toString('base64url'),state=randomBytes(32).toString('base64url');
   const url=new URL('https://127.0.0.1:'+tlsPort+'/authorize');for(const [key,value]of Object.entries({client_id:'memos-fixture',redirect_uri:redirectUri,response_type:'code',scope:'openid profile email',state,code_challenge:createHash('sha256').update(verifier).digest('base64url'),code_challenge_method:'S256'}))url.searchParams.set(key,value);
   const response=await request(url);assert.equal(response.status,302);const callback=new URL(response.headers.location);assert.equal(callback.searchParams.get('state'),state);assert.equal(callback.origin,'https://memos.example.test');
   return {idpName,code:callback.searchParams.get('code'),redirectUri,codeVerifier:verifier};
  }
  const provider=await(await api('/api/v1/'+idpName)).json();assert.equal(provider.name,idpName);
  const identityPath='/api/v1/users/'+username+'/linkedIdentities';
  const existing=(await(await api(identityPath)).json()).linkedIdentities??[];
  if(!existing.length){const linked=await(await api(identityPath,{method:'POST',body:await credentials('hf-admin')})).json();assert.equal(linked.externUid,'hf-admin');}
  else assert.equal(existing.find(i=>i.idpName===idpName)?.externUid,'hf-admin');
  const signin=body=>fetch(base+'/api/v1/auth/signin',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({ssoCredentials:body}),signal:AbortSignal.timeout(15000)});
  const valid=await credentials('hf-admin'),login=await signin(valid);assert.equal(login.status,200);const result=await login.json();assert.equal(result.user.name,'users/'+username);assert.equal(result.user.role,'ADMIN');assert.ok(result.accessToken);
  const memo=await fetch(base+'/api/v1/'+memoName,{headers:{Authorization:'Bearer '+result.accessToken}});assert.equal(memo.status,200);
  const before=(await(await api('/api/v1/users')).json()).users.map(u=>u.name).sort();
  for(const subject of ['hf-new','hf-other']){const denied=await signin(await credentials(subject));assert.equal(denied.status,403);assert.equal((await denied.json()).accessToken,undefined);}
  const after=(await(await api('/api/v1/users')).json()).users.map(u=>u.name).sort();assert.deepEqual(after,before);
  await api(identityPath,{method:'POST',body:await credentials('hf-other'),status:409});
  for(const invalid of [valid,{...await credentials('hf-admin'),codeVerifier:'wrong-verifier'}]){const denied=await signin(invalid);assert.notEqual(denied.status,200);assert.equal((await denied.json()).accessToken,undefined);}
  const retained=(await(await api(identityPath)).json()).linkedIdentities;assert.equal(retained.find(i=>i.idpName===idpName).externUid,'hf-admin');
  console.log('PASS native OAuth2 trusted HTTPS, explicit account linkage, provider-enforced S256 and one-use code, closed enrollment and subject-change denial');
 }finally{
  if(process.platform==='win32'&&child.exitCode===null){try{execFileSync('taskkill',['/PID',String(child.pid),'/T','/F'],{stdio:'ignore'});}catch(error){let gone=false;try{process.kill(child.pid,0);}catch(e){if(e.code==='ESRCH')gone=true;else throw e;}if(!gone)throw error;}}else child.kill();
 }
}
