// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

export async function validateRecovery({k,json,helm,values,name,pod,python,chart,namespace,release}) {
  if(!values.backup.enabled) return;
  const moduleSource=fs.readFileSync(path.join(chart,'files','archive.py'),'utf8');
  const acceptance=fs.readFileSync(path.join(chart,'scripts','archive-accept.py'),'utf8');
  console.log(python(`import types\nmodule=types.ModuleType('archive_contract')\nexec(compile(${JSON.stringify(moduleSource)},'archive.py','exec'),module.__dict__)\n${acceptance}\nvalidate(module)\n`,'hermes',pod,['HERMES_HOME=/tmp/hermes-archive-contract']).trim());
  const job='hermes-acceptance-backup';
  k(['create','job',job,`--from=cronjob/${name}-backup`]);
  k(['wait','--for=condition=complete',`job/${job}`,'--timeout=60s']);
  assert.match(k(['logs',`job/${job}`,'-c','snapshot']),/Strict native snapshot verified/);
  const output=k(['logs',`job/${job}`,'-c','upload']);
  const match=output.match(/s3:\/\/[^/]+\/(.+\/manifest\.json)/);
  assert(match,'Backup upload must publish its completed manifest');
  console.log('PASS native SQLite snapshot, HTTPS S3 upload and remote byte verification');
  const restoreName=`${name.slice(0,40)}-recovered`;
  const restored=structuredClone(values);
  restored.fullnameOverride=restoreName;
  restored.persistence.existingClaim='';
  restored.persistence.retain=false;
  restored.auth.existingSecret='';
  restored.backup.enabled=false;
  restored.restore.enabled=true;
  restored.restore.manifestKey=match[1];
  restored.metrics.enabled=false;
  restored.metrics.serviceMonitor.enabled=false;
  restored.metrics.prometheusRule.enabled=false;
  restored.dashboard.enabled=false;
  restored.externalSecrets.enabled=false;
  restored.ingress.enabled=false;
  restored.gatewayAPI.enabled=false;
  restored.config.policy='managed';
  restored.networkPolicy.extraEgress.push(...values.backup.networkPolicy.extraEgress);
  const temporary=fs.mkdtempSync(path.join(os.tmpdir(),'hf-hermes-restore-'));
  const file=path.join(temporary,'values.json');
  const recoveryRelease='hermes-acceptance-recovery';
  try {
    fs.writeFileSync(file,JSON.stringify(restored));
    helm(['install',recoveryRelease,chart,'-f',file,'--wait','--timeout','60s']);
    assert.match(k(['logs',`${restoreName}-0`,'-c','restore']),/Offline restore verified and completed/);
    const accept=fs.readFileSync(path.join(chart,'scripts','agent-accept.py'),'utf8');
    for(const prompt of ['HF_HISTORY_CHECK','HF_MEMORY_CHECK']) console.log(python(accept,'hermes',`${restoreName}-0`,[`TEST_PROMPT=${prompt}`]).trim());
    // Restart recovery init containers: the completed marker prevents a second
    // restore or dependency on downloading S3 objects on ordinary restarts.
    k(['delete','pod',`${restoreName}-0`,'--wait=true','--timeout=60s']);
    k(['wait','--for=condition=Ready',`pod/${restoreName}-0`,'--timeout=60s']);
    assert.match(k(['logs',`${restoreName}-0`,'-c','restore']),/already completed/);
    console.log('PASS independent empty-volume restore, real state reuse and idempotent restart');
  } finally {
    try {helm(['uninstall',recoveryRelease,'--wait','--timeout','60s']);}
    finally {fs.rmSync(file,{force:true});fs.rmdirSync(temporary);}
  }
}
