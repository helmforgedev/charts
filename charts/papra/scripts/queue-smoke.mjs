// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

export function readExtractionJob({k,pod,documentId}) {
  const script=`const {createRequire}=require('node:module');const r=createRequire('/app/package.json');const {createClient}=r('@libsql/client');const db=createClient({url:'file:/app/app-data/db/tasks.sqlite'});db.execute({sql:'SELECT id,status,error FROM jobs WHERE task_name=? AND json_extract(data,?)=? ORDER BY created_at DESC',args:['extract-document-file-content','$.documentId',process.argv[1]]}).then(result=>{console.log(JSON.stringify(result.rows));db.close()}).catch(error=>{console.error(error.message);process.exitCode=1});`;
  const rows=JSON.parse(k(['exec',pod(),'-c','papra','--','node','-e',script,documentId]));
  assert.equal(rows.length,1,'Upload must enqueue exactly one extraction job');
  return rows[0];
}

export async function verifyPendingQueue({k,pod,documentId,deployment,context,namespace,release,chartPath,forward,verifyDocument,waitForSearch}) {
  assert.equal(deployment.metadata.name,'papra-queue');
  const before=readExtractionJob({k,pod,documentId});assert.equal(before.status,'pending');
  k(['rollout','restart','deployment/'+deployment.metadata.name]);k(['rollout','status','deployment/'+deployment.metadata.name,'--timeout=90s']);
  const retained=readExtractionJob({k,pod,documentId});assert.equal(retained.id,before.id);assert.equal(retained.status,'pending');
  await forward(verifyDocument);
  execFileSync('helm',['upgrade',release,chartPath,'--kube-context',context,'-n',namespace,'--reuse-values','--set','tasks.workerEnabled=true','--wait','--timeout','90s'],{encoding:'utf8',timeout:105000});
  await forward(waitForSearch);
  const deadline=Date.now()+10000;let completed;
  do {completed=readExtractionJob({k,pod,documentId});if(completed.status==='completed')break;await new Promise(r=>setTimeout(r,500));}while(Date.now()<deadline);
  assert.equal(completed.id,before.id);assert.equal(completed.status,'completed');
  console.log('PASS same pending extraction job survives pod replacement and completes after native worker resumes, without re-upload or SQL mutation');
}
