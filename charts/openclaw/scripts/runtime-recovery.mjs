// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
export async function validateRecovery({k,json,helm,node,values,name,chart,namespace}){
 if(!values.backup.enabled)return;
 const negativeName='openclaw-recovery-guards';
 const negativeSource=`import fs from 'node:fs';import assert from 'node:assert/strict';import {spawnSync} from 'node:child_process';
fs.writeFileSync('/work/backup.tar.gz','invalid');fs.writeFileSync('/work/manifest.json',JSON.stringify({schemaVersion:1,application:'openclaw',archive:'backup.tar.gz',size:7,sha256:'0'.repeat(64)}));
let result=spawnSync('node',['/recovery/archive.mjs','restore'],{encoding:'utf8'});assert.notEqual(result.status,0);assert.match(result.stderr,/Archive size\\/checksum mismatch/);
fs.writeFileSync('/home/node/occupied','preserve');result=spawnSync('node',['/recovery/archive.mjs','prepare-restore'],{encoding:'utf8'});assert.notEqual(result.status,0);assert.match(result.stderr,/Refusing to overwrite nonempty state/);assert.equal(fs.readFileSync('/home/node/occupied','utf8'),'preserve');console.log('PASS corrupt archive and occupied target refused');`;
 const guard={apiVersion:'batch/v1',kind:'Job',metadata:{name:negativeName},spec:{backoffLimit:0,activeDeadlineSeconds:60,template:{spec:{restartPolicy:'Never',automountServiceAccountToken:false,securityContext:{runAsNonRoot:true,runAsUser:1000,runAsGroup:1000,fsGroup:1000,seccompProfile:{type:'RuntimeDefault'}},containers:[{name:'guards',image:values.image.repository+':'+values.image.tag,command:['node','--input-type=module','-e',negativeSource],env:[{name:'MAX_ARCHIVE_BYTES',value:'1000'},{name:'MAX_EXPANDED_BYTES',value:'1000'},{name:'RESTORE_MANIFEST_KEY',value:'test/manifest.json'}],securityContext:{readOnlyRootFilesystem:true,allowPrivilegeEscalation:false,capabilities:{drop:['ALL']}},resources:{requests:{cpu:'50m',memory:'64Mi'},limits:{cpu:'500m',memory:'256Mi'}},volumeMounts:[{name:'home',mountPath:'/home/node'},{name:'work',mountPath:'/work'},{name:'recovery',mountPath:'/recovery',readOnly:true}]}],volumes:[{name:'home',emptyDir:{}},{name:'work',emptyDir:{}},{name:'recovery',configMap:{name:name+'-recovery'}}]}}}};
 try{k(['apply','-f','-'],JSON.stringify(guard));k(['wait','--for=condition=complete',`job/${negativeName}`,'--timeout=60s']);assert.match(k(['logs',`job/${negativeName}`]),/corrupt archive and occupied target refused/);}
 finally{k(['delete','job',negativeName,'--ignore-not-found=true','--wait=true','--timeout=60s']);}
 console.log('PASS corrupt recovery data and occupied state fail closed');
 const job='openclaw-acceptance-backup';let manifestKey;
 try{
  k(['create','job',job,`--from=cronjob/${name}-backup`]);
  k(['wait','--for=condition=complete',`job/${job}`,'--timeout=120s']);
  assert.match(k(['logs',`job/${job}`,'-c','snapshot']),/Native SQLite-consistent archive verified/);
  const match=k(['logs',`job/${job}`,'-c','upload']).match(/s3:\/\/[^/]+\/(.+\/manifest\.json)/);
  assert(match,'Offsite backup must publish a completion manifest');manifestKey=match[1];
 }finally{k(['delete','job',job,'--ignore-not-found=true','--wait=true','--timeout=60s']);}
 console.log('PASS native SQLite snapshot and TLS S3 remote byte verification');
 const restored=structuredClone(values);const restoredName=name.slice(0,40)+'-recovered';
 restored.fullnameOverride=restoredName;restored.persistence.existingClaim='';restored.persistence.retain=false;
 restored.backup.enabled=false;restored.restore={...restored.restore,enabled:true,manifestKey};
 restored.metrics.enabled=false;restored.metrics.serviceMonitor.enabled=false;restored.metrics.prometheusRule.enabled=false;
 restored.externalSecrets.enabled=false;restored.ingress.enabled=false;restored.gatewayAPI.enabled=false;
 restored.auth.existingSecret=json(['get','statefulset',name,'-o','json']).spec.template.spec.containers[0].env.find(x=>x.name==='OPENCLAW_GATEWAY_TOKEN').valueFrom.secretKeyRef.name;
 restored.networkPolicy.extraEgress.push(...values.backup.networkPolicy.extraEgress);
 const temporary=fs.mkdtempSync(path.join(os.tmpdir(),'hf-openclaw-recovery-'));const file=path.join(temporary,'values.json');
 const release='openclaw-acceptance-recovery';const pod=restoredName+'-0';
 try{
  fs.writeFileSync(file,JSON.stringify(restored));
  helm(['install',release,chart,'-f',file,'--wait','--timeout','180s']);
  assert.match(k(['logs',pod,'-c','restore']),/Verified OpenClaw state activated/);
  console.log(node(fs.readFileSync(path.join(chart,'scripts/agent-accept.mjs'),'utf8'),pod,'openclaw',['TEST_PROMPT=HF_READ']).trim());
  node(`import assert from 'node:assert/strict';import fs from 'node:fs';import {DatabaseSync} from 'node:sqlite';
for(const f of ['/home/node/.openclaw/state/openclaw.sqlite','/home/node/.openclaw/agents/default/agent/openclaw-agent.sqlite']){assert(fs.existsSync(f),f);const db=new DatabaseSync(f,{readOnly:true});assert.equal(db.prepare('PRAGMA integrity_check').get().integrity_check,'ok');db.close();}console.log('PASS native restored SQLite integrity');`,pod);
  k(['delete','pod',pod,'--wait=true','--timeout=60s']);
  k(['rollout','status',`statefulset/${restoredName}`,'--timeout=120s']);
  assert(!k(['logs',pod,'-c','download']).includes('download failed'));
  console.log(node(fs.readFileSync(path.join(chart,'scripts/agent-accept.mjs'),'utf8'),pod,'openclaw',['TEST_PROMPT=HF_READ']).trim());
  console.log('PASS empty-volume activation, real recovered agent and idempotent restart');
 }finally{
  try{helm(['uninstall',release,'--wait','--timeout','60s']);}finally{fs.unlinkSync(file);fs.rmdirSync(temporary);}
 }
}
