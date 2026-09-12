// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {validateRecovery} from './runtime-recovery.mjs';
import {pairingClient} from './runtime-pairing.mjs';
const [context,namespace,release]=process.argv.slice(2);
assert.equal(context,'k3d-helmforge-tests-wsl');assert.equal(namespace,'hf-validate-openclaw');
const chart=path.resolve(import.meta.dirname,'..');
const k=(args,input,timeout=180000)=>execFileSync('kubectl',['--context',context,'-n',namespace,...args],{encoding:'utf8',input,timeout,maxBuffer:8*1024*1024,stdio:['pipe','pipe','pipe']});
const helm=args=>execFileSync('helm',[...args,'--kube-context',context,'-n',namespace],{encoding:'utf8',timeout:240000,maxBuffer:8*1024*1024,stdio:'pipe'});
const json=args=>JSON.parse(k(args));
let values=JSON.parse(helm(['get','values',release,'--all','-o','json']));
if(values.agent.model!=='fixture/helmforge-fixture'){
 k(['apply','-f',path.join(chart,'ci/fixtures/agent-values.yaml')]);
 k(['rollout','status','deployment/openclaw-provider','--timeout=120s']);
 helm(['upgrade',release,chart,'--reset-then-reuse-values','-f',path.join(chart,'ci/agent-values.yaml'),'--wait','--timeout','180s']);
 values=JSON.parse(helm(['get','values',release,'--all','-o','json']));
}
const sts=json(['get','statefulset','-l',`app.kubernetes.io/instance=${release}`,'-o','json']).items[0];
const name=sts.metadata.name,pod=name+'-0';
const node=(source,target=pod,container='openclaw',env=[])=>k(['exec','-i',target,'-c',container,'--','env',...env,'node','--input-type=module'],source);
const accept=prompt=>node(fs.readFileSync(path.join(chart,'scripts/agent-accept.mjs'),'utf8'),pod,'openclaw',[`TEST_PROMPT=${prompt}`]);
node(`import assert from 'node:assert/strict';import fs from 'node:fs';assert.equal(process.getuid(),1000);assert(!fs.existsSync('/var/run/secrets/kubernetes.io/serviceaccount/token'));assert.match(fs.readFileSync('/proc/1/comm','utf8'),/tini/);assert.throws(()=>fs.writeFileSync('/etc/helmforge-test','fail'));console.log('PASS restricted runtime and official init');`);
console.log(accept('HF_STORE').trim());
node(`import assert from 'node:assert/strict';import fs from 'node:fs';assert.equal(fs.readFileSync('/home/node/.openclaw/workspace/helmforge-memory.txt','utf8'),'HELMFORGE_PERSISTED_OPENCLAW_MEMORY');`);
console.log(accept('HF_READ').trim());
const secretName=sts.spec.template.spec.containers[0].env.find(x=>x.name==='OPENCLAW_GATEWAY_TOKEN').valueFrom.secretKeyRef.name;
const identity=json(['get','secret',secretName,'-o','json']).data;
if(values.externalSecrets.enabled){
 const secrets=json(['get','externalsecrets','-o','json']).items;
 assert(secrets.length>0);
 for(const secret of secrets)assert(secret.status?.conditions?.some(c=>c.type==='Ready'&&c.status==='True'));
 console.log('PASS External Secrets synchronized and consumed by the gateway');
}
const peer=json(['get','pods','-l','app=openclaw-provider','-o','json']).items[0].metadata.name;
const get=url=>node(`const r=await fetch(${JSON.stringify(url)},{signal:AbortSignal.timeout(3000)});console.log(r.status);` ,peer,'provider');
if(values.networkPolicy.enabled&&!values.networkPolicy.ingressFrom.length)assert.throws(()=>get(`http://${name}:${values.service.port}/healthz`));
const policy={apiVersion:'networking.k8s.io/v1',kind:'NetworkPolicy',metadata:{name:'openclaw-acceptance'},spec:{podSelector:{matchLabels:{'app.kubernetes.io/instance':release,'app.kubernetes.io/component':'gateway'}},policyTypes:['Ingress'],ingress:[{from:[{podSelector:{matchLabels:{app:'openclaw-provider'}}}],ports:[{protocol:'TCP',port:18789}]}]}};
k(['apply','-f','-'],JSON.stringify(policy));
try{await new Promise(r=>setTimeout(r,1500));assert.equal(get(`http://${name}:${values.service.port}/healthz`).trim(),'200');}finally{k(['delete','networkpolicy','openclaw-acceptance']);}
console.log('PASS network peer denial and admission');
const pairing=pairingClient({k,json,chart,values,name,pod,peer,secretName});
await pairing.enroll();
if(values.metrics.enabled&&values.metrics.collector.enabled){
 const metrics=node(`const r=await fetch('http://127.0.0.1:8889/metrics');if(!r.ok)throw new Error('Metrics unavailable');console.log(await r.text());`);
 assert.match(metrics,/openclaw[_.]/,'Collector must expose native OpenClaw metrics');
 if(values.metrics.serviceMonitor.enabled)assert.equal(get(`http://${name}-metrics:8889/metrics`).trim(),'200');
 console.log('PASS native OpenClaw OTLP to Prometheus');
}
const temporary=fs.mkdtempSync(path.join(os.tmpdir(),'hf-openclaw-'));
try{
 const upgradeFile=path.join(temporary,'upgrade.json');fs.writeFileSync(upgradeFile,JSON.stringify({podAnnotations:{'helmforge.dev/acceptance-upgrade':'true'}}));
 helm(['upgrade',release,chart,'--reset-then-reuse-values','-f',upgradeFile,'--wait','--timeout','180s']);
 assert.deepEqual(json(['get','secret',secretName,'-o','json']).data,identity);
 console.log(accept('HF_READ').trim());
 console.log('PASS gateway identity and tool-written state survive upgrade');
 await pairing.reconnect();
}finally{for(const file of fs.readdirSync(temporary))fs.unlinkSync(path.join(temporary,file));fs.rmdirSync(temporary);}
await validateRecovery({k,json,helm,node,values,name,chart,namespace});
console.log('OpenClaw behavioral acceptance passed');
