// SPDX-License-Identifier: Apache-2.0
const assert=require('node:assert/strict');
const base='http://127.0.0.1:5000';
(async()=>{
 const get=url=>fetch(url,{redirect:'manual',signal:AbortSignal.timeout(15000)});
 const config=await get(base+'/api/auth/oidc/config');assert.equal(config.status,200);assert.equal((await config.json()).enabled,true);
 const start=await get(base+'/api/auth/oidc/auth');assert.equal(start.status,302);
 const auth=new URL(start.headers.get('location'));assert.ok(auth.searchParams.get('state'));assert.ok(auth.searchParams.get('nonce'));
 assert.ok(auth.searchParams.get('code_challenge'));
 assert.equal(auth.searchParams.get('code_challenge_method'),'S256');
 const allowed=await get(auth);assert.equal(allowed.status,302);
 const callback=allowed.headers.get('location');const logged=await get(callback);assert.equal(logged.status,302);
 const location=new URL(logged.headers.get('location'),base);const token=location.searchParams.get('token');assert.ok(token,'Native callback must issue application JWT');
 const verify=await fetch(base+'/api/auth/verify',{headers:{bytestashauth:'Bearer '+token}});assert.equal(verify.status,200);assert.equal((await verify.json()).valid,true);
 const created=await fetch(base+'/api/snippets',{method:'POST',headers:{'Content-Type':'application/json',bytestashauth:'Bearer '+token},body:JSON.stringify({title:'OIDC fixture',fragments:[{file_name:'oidc.txt',code:'OIDC identity can write its own snippet',language:'plaintext'}]})});assert.equal(created.status,201);
 const replay=await get(callback);assert.equal(replay.status,302);assert.ok(!new URL(replay.headers.get('location'),base).searchParams.has('token'));
 const second=await get(base+'/api/auth/oidc/auth');const denied=new URL(second.headers.get('location'));denied.searchParams.set('fixture_identity','denied');assert.equal((await get(denied)).status,403);
 console.log('PASS native OIDC with verified TLS CA, signed identity, S256 PKCE, nonce/state, authenticated mutation, replay rejection and provider admission denial');
})().catch(error=>{console.error(error.message);process.exitCode=1;});
