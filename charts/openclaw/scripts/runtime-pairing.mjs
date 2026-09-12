// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
export function pairingClient({k,json,chart,values,name,pod,peer,secretName}){
 const secret=json(['get','secret',secretName,'-o','json']);
 const token=Buffer.from(secret.data[values.auth.key],'base64').toString();
 const code=fs.readFileSync(path.join(chart,'scripts/pairing-client.cjs'),'utf8');
 const policy={apiVersion:'networking.k8s.io/v1',kind:'NetworkPolicy',metadata:{name:'openclaw-pairing-test'},spec:{podSelector:{matchLabels:{'app.kubernetes.io/instance':json(['get','pod',pod,'-o','json']).metadata.labels['app.kubernetes.io/instance'],'app.kubernetes.io/component':'gateway'}},policyTypes:['Ingress'],ingress:[{from:[{podSelector:{matchLabels:{app:'openclaw-provider'}}}],ports:[{protocol:'TCP',port:18789}]}]}};
 const run=({wrongToken=false,wrongOrigin=false}={})=>{
  const env={TEST_GATEWAY_TOKEN:wrongToken?'incorrect-pairing-token':token,TEST_GATEWAY_WS_URL:`ws://${name}:${values.service.port}`,TEST_ORIGIN:wrongOrigin?'https://untrusted.example.invalid':values.gateway.controlUi.allowedOrigins[0]};
  // Send credentials only through stdin, never process arguments or logs.
  return JSON.parse(k(['exec','-i',peer,'-c','provider','--','node'],`Object.assign(process.env,${JSON.stringify(env)});\n${code}`));
 };
 const cli=(args)=>JSON.parse(k(['exec',pod,'-c','openclaw','--','node','/app/openclaw.mjs','devices',...args,'--json']));
 return {
  async enroll(){
   k(['apply','-f','-'],JSON.stringify(policy));await new Promise(r=>setTimeout(r,1000));
   try{
    const pending=run();assert.equal(pending.ok,false);assert.equal(pending.code,'PAIRING_REQUIRED');assert(pending.requestId);
    const requested=cli(['list']).pending.filter(x=>x.requestId===pending.requestId&&x.deviceId===pending.deviceId);
    assert.equal(requested.length,1,'Approve only the exact test device');
    cli(['approve',pending.requestId]);
    assert.equal(run().ok,true);
    assert.equal(run({wrongToken:true}).code,'AUTH_TOKEN_MISMATCH');
    assert.equal(run({wrongOrigin:true}).code,'CONTROL_UI_ORIGIN_NOT_ALLOWED');
    console.log('PASS remote signed Control UI pairing, exact approval, token and origin rejection');
   }finally{k(['delete','networkpolicy','openclaw-pairing-test']);}
  },
  async reconnect(){
   k(['apply','-f','-'],JSON.stringify(policy));await new Promise(r=>setTimeout(r,1000));
   try{assert.equal(run().ok,true);console.log('PASS paired device reconnects after gateway upgrade');}
   finally{k(['delete','networkpolicy','openclaw-pairing-test']);}
  }
 };
}
