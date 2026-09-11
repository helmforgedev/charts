// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
const token=process.env.OPENCLAW_GATEWAY_TOKEN;
const prompt=process.env.TEST_PROMPT??'HF_STORE';
const url='http://127.0.0.1:18789/v1/chat/completions';
const payload={model:'openclaw/default',user:'helmforge-acceptance',messages:[{role:'user',content:prompt}]};
const denied=await fetch(url,{method:'POST',headers:{'content-type':'application/json',authorization:'Bearer invalid'},body:JSON.stringify(payload)});
assert.equal(denied.status,401,'Invalid gateway token must fail');
const response=await fetch(url,{method:'POST',headers:{'content-type':'application/json',authorization:'Bearer '+token},body:JSON.stringify(payload),signal:AbortSignal.timeout(90000)});
const body=await response.json();
assert.equal(response.status,200,JSON.stringify(body));
assert(body.choices?.[0]?.message?.content,'Gateway must return real provider output');
if(prompt==='HF_READ')assert.match(body.choices[0].message.content,/HELMFORGE_PERSISTED_OPENCLAW_MEMORY/);
console.log('PASS authenticated agent request '+prompt);
