// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import fs from 'node:fs';
import http from 'node:http';
import https from 'node:https';
import {createHash,X509Certificate} from 'node:crypto';
import {chromium} from 'playwright';

export async function createPasskeyFixture({origin,expectedUserId}){
 const url=new URL(origin);assert.equal(url.origin,'https://pocket-id.example.test:18443');
 const cert=fs.readFileSync(new URL('../ci/tls/tls.crt',import.meta.url));
 const key=fs.readFileSync(new URL('../ci/tls/tls.key',import.meta.url));
 const ca=fs.readFileSync(new URL('../ci/tls/ca.crt',import.meta.url));
 const leaf=new X509Certificate(cert);
 const pin=createHash('sha256').update(leaf.publicKey.export({type:'spki',format:'der'})).digest('base64');
 let upstream;
 const server=https.createServer({key,cert},(request,response)=>{
  if(!upstream){response.writeHead(503).end();return;}
  const destination=new URL(request.url,upstream);
  const proxy=http.request(destination,{agent:false,method:request.method,headers:{...request.headers,host:url.host,'x-forwarded-proto':'https'}},reply=>{
   response.writeHead(reply.statusCode,reply.headers);reply.pipe(response);
  });
  proxy.on('error',error=>{console.error('Fixture upstream transport error:',error.code,error.syscall??'');if(!response.headersSent)response.writeHead(502);response.end();});
  request.pipe(proxy);
 });
 await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(Number(url.port),'127.0.0.1',resolve);});
 let browser,context,page,cdp,authenticatorId,credentialId;
 const read=path=>page.evaluate(async path=>{const response=await fetch(path);const text=await response.text();return {status:response.status,body:text?JSON.parse(text):null};},path);
 async function currentUser(){const response=await read('/api/users/me');assert.equal(response.status,200);assert.equal(response.body.id,expectedUserId);assert.equal(response.body.isAdmin,true);}
 async function logout(){
  await page.getByRole('button',{name:'My Account',exact:true}).click();
  await page.getByRole('menuitem',{name:'Logout',exact:true}).click();
  await page.waitForURL(value=>value.pathname==='/login');
  assert.equal((await read('/api/users/me')).status,401);
 }
 async function login(){
  const finished=page.waitForResponse(r=>new URL(r.url()).pathname==='/api/webauthn/login/finish'&&r.request().method()==='POST');
  await page.getByRole('button',{name:'Authenticate',exact:true}).click();
  assert.equal((await finished).status(),200);
  await page.waitForURL(value=>value.pathname.startsWith('/settings'));
  await currentUser();
  const credentials=await read('/api/webauthn/credentials');assert.equal(credentials.status,200);assert.equal(credentials.body.length,1);assert.equal(credentials.body[0].id,credentialId);
 }
 async function verifyTls(){
  await new Promise((resolve,reject)=>{
   const request=https.get({hostname:'127.0.0.1',port:Number(url.port),servername:url.hostname,ca,path:'/healthz',rejectUnauthorized:true},response=>{
    const authorized=response.socket.authorized;
    response.resume();response.on('end',()=>{try{assert.equal(response.statusCode,204);assert.equal(authorized,true);resolve();}catch(error){reject(error);}});
   });request.on('error',reject);
  });
  let rejected=false;
  await new Promise(resolve=>{const request=https.get({hostname:'127.0.0.1',port:Number(url.port),servername:url.hostname,path:'/healthz',rejectUnauthorized:true},response=>{response.resume();response.on('end',resolve);});request.on('error',error=>{rejected=['UNABLE_TO_VERIFY_LEAF_SIGNATURE','UNABLE_TO_GET_ISSUER_CERT_LOCALLY','SELF_SIGNED_CERT_IN_CHAIN'].includes(error.code);resolve();});});
  assert.equal(rejected,true,'Fixture issuer must be rejected without its trusted CA');
 }
 return {
  async enroll(base,token){
   upstream=base;await verifyTls();
   browser=await chromium.launch({headless:true,args:['--no-proxy-server','--host-resolver-rules=MAP '+url.hostname+' 127.0.0.1','--ignore-certificate-errors-spki-list='+pin]});
   context=await browser.newContext({locale:'en-US'});page=await context.newPage();page.setDefaultTimeout(20000);
   cdp=await context.newCDPSession(page);await cdp.send('WebAuthn.enable');
   ({authenticatorId}=await cdp.send('WebAuthn.addVirtualAuthenticator',{options:{protocol:'ctap2',transport:'internal',hasResidentKey:true,hasUserVerification:true,isUserVerified:true,automaticPresenceSimulation:true}}));
   await page.goto(origin+'/login');
   assert.equal(await page.evaluate(()=>window.isSecureContext),true);assert.equal(await page.evaluate(()=>location.origin),origin);
   const status=await page.evaluate(async token=>(await fetch('/api/one-time-access-token/'+token,{method:'POST'})).status,token);assert.equal(status,200);
   await page.goto(origin+'/signup/add-passkey');
   await page.getByRole('heading',{name:'Set up your passkey',exact:true}).waitFor();
   const options=page.waitForResponse(r=>new URL(r.url()).pathname==='/api/webauthn/register/start');
   const finished=page.waitForResponse(r=>new URL(r.url()).pathname==='/api/webauthn/register/finish'&&r.request().method()==='POST');
   await page.getByRole('button',{name:'Add Passkey',exact:true}).click();
   const challenge=await(await options).json();assert.equal(challenge.publicKey?.rp?.id??challenge.rp?.id,url.hostname);
   assert.equal((await finished).status(),200);
   await page.waitForURL(value=>value.pathname==='/settings/account');
   const credentials=await read('/api/webauthn/credentials');assert.equal(credentials.status,200);assert.equal(credentials.body.length,1);credentialId=credentials.body[0].id;assert.ok(credentialId);
   await currentUser();await logout();await login();
   const {verifyOidc}=await import('./oidc-smoke.mjs');await verifyOidc({page,origin,expectedUserId});
   await logout();
   console.log('PASS trusted fixture TLS and exact Chromium certificate pin; new native passkey enrollment, logout and WebAuthn login without seeded credentials');
  },
  async afterReplacement(base){upstream=base;await page.goto(origin+'/settings/account');if((await read('/api/users/me')).status===200)await logout();else await page.goto(origin+'/login');await login();console.log('PASS same browser authenticator and persisted passkey authenticate after pod replacement');},
  async close(){await browser?.close();server.closeAllConnections();await new Promise(resolve=>server.close(resolve));},
 };
}
