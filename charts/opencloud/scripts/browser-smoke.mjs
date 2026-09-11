// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {createPublicKey,createHash,verify,constants,randomUUID} from 'node:crypto';

export async function login({browser,origin,oidc,password,request,wrong=false}){
 const context=await browser.newContext(),page=await context.newPage();page.setDefaultTimeout(20000);page.setDefaultNavigationTimeout(30000);
 let authorization,callback,successfulToken=false;
 page.on('request',req=>{const u=new URL(req.url());if(u.origin===origin&&u.pathname===new URL(oidc.authorization_endpoint).pathname&&u.searchParams.get('response_type')==='code')authorization=u.searchParams;if(u.origin===origin&&u.searchParams.has('code')&&u.searchParams.has('state'))callback=u.searchParams;});
 page.on('response',response=>{if(response.url()===oidc.token_endpoint&&response.request().method()==='POST'&&response.status()===200)successfulToken=true;});
 try{
  const tokenPromise=wrong?null:page.waitForResponse(response=>response.url()===oidc.token_endpoint&&response.request().method()==='POST'&&response.status()===200,{timeout:60000}).then(response=>({response}),error=>({error}));
  await page.goto(origin,{waitUntil:'domcontentloaded'});await page.locator('input[type="password"]').waitFor({state:'visible'});
  await page.locator('input[autocomplete~="username"]').fill('admin');await page.locator('input[type="password"]').fill(wrong?'wrong-'+randomUUID():password);
  const logon=page.waitForResponse(response=>new URL(response.url()).pathname==='/signin/v1/identifier/_/logon'&&response.request().method()==='POST').then(response=>({response}),error=>({error}));
  await page.locator('button[type="submit"]').click();const logonResult=await logon;if(logonResult.error)throw logonResult.error;
  if(wrong){assert.ok([204,400,401,403].includes(logonResult.response.status()),'Wrong password must be rejected by the native identifier');assert.equal(successfulToken,false);console.log('PASS native wrong-password login is rejected without issuing an OIDC access token');return;}
  assert.equal(logonResult.response.status(),200);const outcome=await tokenPromise;if(outcome.error)throw outcome.error;const tokens=await outcome.response.json();assert.ok(tokens.access_token&&tokens.id_token);
  assert.ok(authorization&&callback);assert.equal(authorization.get('client_id'),'web');assert.equal(authorization.get('code_challenge_method'),'S256');assert.ok(authorization.get('state'));assert.equal(callback.get('state'),authorization.get('state'));
  const exchange=new URLSearchParams(outcome.response.request().postData());assert.equal(exchange.get('grant_type'),'authorization_code');assert.equal(exchange.get('code'),callback.get('code'));assert.equal(exchange.get('redirect_uri'),authorization.get('redirect_uri'));assert.ok(exchange.get('code_verifier'));assert.equal(createHash('sha256').update(exchange.get('code_verifier')).digest('base64url'),authorization.get('code_challenge'));
  const [h,p,s]=tokens.id_token.split('.'),header=JSON.parse(Buffer.from(h,'base64url')),claims=JSON.parse(Buffer.from(p,'base64url'));
  const response=await request(new URL(oidc.jwks_uri).pathname);assert.equal(response.status,200);const key=JSON.parse(response.body).keys.find(key=>key.kid===header.kid);assert.ok(key);assert.equal(key.d,undefined);assert.equal(header.alg,'PS256');assert.equal(key.kty,'RSA');
  assert.ok(verify('sha256',Buffer.from(h+'.'+p),{key:createPublicKey({key,format:'jwk'}),padding:constants.RSA_PKCS1_PSS_PADDING,saltLength:32},Buffer.from(s,'base64url')));
  const now=Date.parse(outcome.response.headers()['date'])/1000;assert.ok(Number.isFinite(now)&&Math.abs(now-Date.now()/1000)<60);assert.equal(claims.iss,origin);assert.ok([claims.aud].flat().includes('web'));if(authorization.has('nonce'))assert.equal(claims.nonce,authorization.get('nonce'));assert.ok(claims.sub&&claims.exp>now&&Number.isFinite(claims.iat)&&claims.iat<=now+5);
  console.log('PASS native browser OIDC with S256, callback state, signed PS256 ID token, issuer/audience and bounded timestamps');
  return {token:tokens.access_token,subject:claims.sub};
 }finally{await context.close();}
}
