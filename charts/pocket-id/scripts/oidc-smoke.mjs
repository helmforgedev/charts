// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {randomBytes,createHash,createPublicKey,verify,constants} from 'node:crypto';

export async function verifyOidc({page,origin,expectedUserId}){
 const request=(path,options={})=>page.evaluate(async ({path,options})=>{
  const response=await fetch(path,{...options,headers:{...(options.body?{'Content-Type':'application/json'}:{}),...options.headers}});
  const text=await response.text();let body;try{body=JSON.parse(text);}catch{body=null;}return {status:response.status,body,date:response.headers.get('Date')};
 },{path,options});
 const callback=origin+'/fixture/oidc-callback';
 const created=await request('/api/oidc/clients',{method:'POST',body:JSON.stringify({name:'HelmForge native OIDC fixture',callbackURLs:[callback],isPublic:true,pkceEnabled:true,skipConsent:false})});
 assert.equal(created.status,201);const clientId=created.body.id;assert.ok(clientId);assert.equal(created.body.skipConsent,false);
 const discovery=await request('/.well-known/openid-configuration');assert.equal(discovery.status,200);const metadata=discovery.body;
 assert.equal(metadata.issuer,origin);
 for(const key of ['authorization_endpoint','token_endpoint','jwks_uri','userinfo_endpoint'])assert.equal(new URL(metadata[key]).origin,origin);
 await page.route(value=>value.origin===origin&&value.pathname==='/fixture/oidc-callback',route=>route.fulfill({status:200,contentType:'text/html',body:'<!doctype html><title>Owned OIDC callback</title>'}));
 async function authorize(requireConsent=false){
  const verifier=randomBytes(48).toString('base64url'),state=randomBytes(24).toString('base64url'),nonce=randomBytes(24).toString('base64url');
  const params=new URLSearchParams({client_id:clientId,redirect_uri:callback,response_type:'code',scope:'openid profile email',state,nonce,code_challenge:createHash('sha256').update(verifier).digest('base64url'),code_challenge_method:'S256'});
  const received=page.waitForRequest(request=>{const value=new URL(request.url());return value.origin===origin&&value.pathname==='/fixture/oidc-callback';});
  await page.goto(metadata.authorization_endpoint+'?'+params);
  if(requireConsent||new URL(page.url()).pathname!=='/fixture/oidc-callback')await page.getByRole('button',{name:'Sign in',exact:true}).click();
  const result=new URL((await received).url());assert.equal(result.searchParams.get('state'),state);assert.equal(result.searchParams.has('error'),false);const code=result.searchParams.get('code');assert.ok(code);
  await page.waitForURL(value=>value.pathname==='/fixture/oidc-callback');
  return {code,verifier,nonce};
 }
 const exchange=({code,verifier})=>request(new URL(metadata.token_endpoint).pathname,{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'authorization_code',client_id:clientId,redirect_uri:callback,code,code_verifier:verifier}).toString()});
 const wrong=await authorize(true);const wrongExchange=await exchange({...wrong,verifier:randomBytes(48).toString('base64url')});assert.ok([400,401].includes(wrongExchange.status));assert.equal(wrongExchange.body.access_token,undefined);
 const authorized=await authorize();const token=await exchange(authorized);assert.equal(token.status,200);assert.ok(token.body.access_token&&token.body.id_token);
 const [headerPart,payloadPart,signature]=token.body.id_token.split('.');assert.ok(signature);
 const header=JSON.parse(Buffer.from(headerPart,'base64url')),claims=JSON.parse(Buffer.from(payloadPart,'base64url'));
 const jwks=await request(new URL(metadata.jwks_uri).pathname);assert.equal(jwks.status,200);const jwk=jwks.body.keys.find(key=>key.kid===header.kid);assert.ok(jwk);assert.equal(jwk.d,undefined);
 const publicKey=createPublicKey({key:jwk,format:'jwk'});let algorithm,options={key:publicKey};
 switch(header.alg){
  case 'RS256':assert.equal(jwk.kty,'RSA');algorithm='RSA-SHA256';options.padding=constants.RSA_PKCS1_PADDING;break;
  case 'PS256':assert.equal(jwk.kty,'RSA');algorithm='sha256';options.padding=constants.RSA_PKCS1_PSS_PADDING;options.saltLength=32;break;
  case 'ES256':assert.equal(jwk.kty,'EC');assert.equal(jwk.crv,'P-256');algorithm='sha256';options.dsaEncoding='ieee-p1363';break;
  case 'EdDSA':assert.equal(jwk.kty,'OKP');assert.equal(jwk.crv,'Ed25519');algorithm=null;break;
  default:throw new Error('Unsupported native ID-token algorithm: '+header.alg);
 }
 assert.equal(verify(algorithm,Buffer.from(headerPart+'.'+payloadPart),options,Buffer.from(signature,'base64url')),true,'Native ID token signature must match discovery JWKS');
 const issuerNow=Date.parse(token.date)/1000;assert.ok(Number.isFinite(issuerNow));assert.ok(Math.abs(issuerNow-Date.now()/1000)<60,'Issuer and validation clocks must remain within a bounded 60-second skew');
 assert.equal(claims.iss,origin);assert.ok([claims.aud].flat().includes(clientId));assert.equal(claims.nonce,authorized.nonce);assert.equal(claims.sub,expectedUserId);assert.ok(claims.exp>issuerNow);assert.ok(Number.isFinite(claims.iat)&&claims.iat<=issuerNow+5);
 const userinfo=await request(new URL(metadata.userinfo_endpoint).pathname,{headers:{Authorization:'Bearer '+token.body.access_token}});assert.equal(userinfo.status,200);assert.equal(userinfo.body.sub,expectedUserId);
 const replay=await exchange(authorized);assert.ok([400,401].includes(replay.status));assert.equal(replay.body.access_token,undefined);
 let badCallback=false;
 await page.route(value=>value.origin===origin&&value.pathname==='/fixture/unregistered-callback',route=>{badCallback=true;return route.fulfill({status:200,body:'owned unexpected callback'});});
 const invalid=new URLSearchParams({client_id:clientId,redirect_uri:origin+'/fixture/unregistered-callback',response_type:'code',scope:'openid',state:'owned-invalid-callback',code_challenge:createHash('sha256').update('owned-invalid-verifier').digest('base64url'),code_challenge_method:'S256'});
 await page.goto(metadata.authorization_endpoint+'?'+invalid);await page.getByText(/is not registered for this client\./).waitFor();assert.equal(badCallback,false,'Unregistered callback must never receive an authorization response');
 assert.notEqual(new URL(page.url()).pathname,'/fixture/unregistered-callback');
 await page.goto(origin+'/settings/account');
 console.log('PASS native OIDC consent and authorization code, S256 wrong-verifier denial, signed ID-token issuer/audience/nonce/subject, userinfo, code replay and unregistered callback denial');
}
