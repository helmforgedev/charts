// SPDX-License-Identifier: Apache-2.0
const assert = require('node:assert/strict');
const base = 'http://127.0.0.1:6806';
(async () => {
  for (const identity of ['allowed', 'denied']) {
    const jar = new Map();
    const request = async (url, options = {}) => {
      const response = await fetch(url, {...options, redirect: 'manual', signal: AbortSignal.timeout(15000), headers: {...options.headers, Cookie: [...jar].map(([k,v]) => k + '=' + v).join('; ')}});
      for (const item of response.headers.getSetCookie()) {const part = item.split(';')[0]; const i = part.indexOf('='); jar.set(part.slice(0,i), part.slice(i+1));}
      return response;
    };
    const start = await request(base + '/api/system/oidc/start', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({flow: 'web', to: '/', rememberMe: false})});
    const data = await start.json(); assert.equal(data.code, 0, JSON.stringify(data));
    const auth = new URL(data.data.authURL); assert.ok(auth.searchParams.get('nonce')); assert.equal(auth.searchParams.get('code_challenge_method'), 'S256'); auth.searchParams.set('fixture_identity', identity);
    const authorize = await fetch(auth, {redirect: 'manual'}); assert.equal(authorize.status, 302);
    const callback = await request(authorize.headers.get('location')); await callback.text();
    const response = await request(base + '/api/notebook/lsNotebooks', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: '{}'});
    let result; try {result = await response.json();} catch {}
    if (identity === 'allowed') {
      assert.equal(response.status, 200); assert.equal(result.code, 0);
      const created = await request(base + '/api/notebook/createNotebook', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({name: 'oidc-fixture'})});
      const notebook = await created.json(); assert.equal(notebook.code, 0); assert.ok(notebook.data.notebook.id);
      await request(base + '/api/system/logoutAuth', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: '{}'});
    } else assert.ok(response.status !== 200 || result?.code !== 0, 'Signed but unapproved identity must not access the workspace');
  }
  console.log('PASS native OIDC discovery, JWKS signature, PKCE, nonce, admitted mutation and rejected identity');
})().catch(error => {console.error(error.message); process.exitCode = 1;});
