// SPDX-License-Identifier: Apache-2.0
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {createRequire} from 'node:module';
const work='/work', archive=work+'/backup.tar.gz', target='/home/node';
const require=createRequire('/app/package.json');
const action=process.argv[2];
const key=process.env.RESTORE_MANIFEST_KEY;
const completed=target+'/.helmforge-restore.json';
const incomplete=target+'/.helmforge-restore-incomplete';
function native(args){
 const result=spawnSync('node',['/app/openclaw.mjs','backup',...args,'--json'],{encoding:'utf8',maxBuffer:20*1024*1024,env:{...process.env,DO_NOT_TRACK:'1'}});
 if(result.status!==0)throw new Error('Native backup command failed: '+result.stderr.slice(-3000));
 try{return JSON.parse(result.stdout);}catch{throw new Error('Native backup did not return a single JSON result');}
}
async function checksum(file){const h=crypto.createHash('sha256');for await(const b of fs.createReadStream(file))h.update(b);return h.digest('hex');}
function json(file){return JSON.parse(fs.readFileSync(file,'utf8'));}
function emptyTarget(){
 if(!fs.lstatSync(target).isDirectory())throw new Error('Recovery target must be a directory');
 if(fs.existsSync(incomplete))throw new Error('Interrupted recovery requires operator inspection and a fresh empty claim');
 if(fs.readdirSync(target).some(n=>n!=='lost+found'))throw new Error('Refusing to overwrite nonempty state');
}
if(action==='backup'){
 if(fs.existsSync(archive))throw new Error('Archive destination already exists');
 const result=native(['create','--output',archive,'--verify']);
 if(result.verified!==true||result.dryRun!==false||result.archivePath!==archive||!result.includeWorkspace||result.onlyConfig)throw new Error('Native archive result is not a complete verified snapshot');
 if(!result.assets?.some(a=>a.sourcePath==='/home/node/.openclaw'))throw new Error('State asset missing from snapshot');
 const run='openclaw-'+new Date().toISOString().replaceAll('-','').replaceAll(':','').replace(/\.\d{3}Z$/,'Z')+'-'+crypto.randomBytes(8).toString('hex');
 const size=fs.statSync(archive).size,sha256=await checksum(archive);
 fs.writeFileSync(work+'/manifest.json',JSON.stringify({schemaVersion:1,application:'openclaw',image:process.env.OPENCLAW_IMAGE,run,archive:'backup.tar.gz',size,sha256,createdAt:result.createdAt}),{mode:0o600,flag:'wx'});
 fs.writeFileSync(work+'/upload.tsv',`${run}\t${size}\t${sha256}\n`,{mode:0o600,flag:'wx'});
 console.log('Native SQLite-consistent archive verified for S3 publication');
}else if(action==='prepare-restore'){
 if(fs.existsSync(completed)){
  if(json(completed).manifestKey!==key)throw new Error('Existing recovery identity differs from requested manifest');
  fs.writeFileSync(work+'/skip-restore','complete',{mode:0o600});
 }else emptyTarget();
}else if(action==='restore'){
 if(fs.existsSync(work+'/skip-restore'))process.exit(0);
 emptyTarget();
 const manifest=json(work+'/manifest.json');
 if(process.env.OPENCLAW_IMAGE && manifest.image!==process.env.OPENCLAW_IMAGE)throw new Error('Recovery requires the exact backup image; restore before upgrading');
 if(manifest.schemaVersion!==1||manifest.application!=='openclaw'||manifest.archive!=='backup.tar.gz'||!Number.isSafeInteger(manifest.size)||manifest.size<=0||manifest.size>Number(process.env.MAX_ARCHIVE_BYTES)||!/^[a-f0-9]{64}$/.test(manifest.sha256))throw new Error('Invalid recovery manifest');
 if(fs.lstatSync(archive).size!==manifest.size||await checksum(archive)!==manifest.sha256)throw new Error('Archive size/checksum mismatch');
 const tar=require('tar');let expanded=0;
 await tar.t({file:archive,onReadEntry(entry){expanded+=entry.size;if(expanded>Number(process.env.MAX_EXPANDED_BYTES))throw new Error('Expanded archive exceeds configured limit');}});
 const stage=work+'/restored';
 const restored=native(['restore',archive,'--target',stage]);
 if(restored.ok!==true||restored.targetPath!==stage)throw new Error('Native restore did not validate staging');
 const root=path.resolve(stage,restored.archiveRoot);
 if(!root.startsWith(stage+'/'))throw new Error('Invalid archive root');
 const nativeManifest=json(root+'/manifest.json');
 const assets=nativeManifest.assets;
 if(!Array.isArray(assets)||!assets.some(a=>a.sourcePath==='/home/node/.openclaw'))throw new Error('Restored state asset missing');
 // Native verification validates symlinks and payloads. Activation only accepts
 // assets in this chart's persisted home; external roots require manual recovery.
 const moves=assets.map(a=>{
  const source=path.resolve(stage,a.archivePath),destination=path.resolve(a.sourcePath);
  if(!source.startsWith(root+'/')||!destination.startsWith(target+'/'))throw new Error('Archive requires manual recovery of external assets');
  return {source,destination};
 }).sort((a,b)=>a.destination.length-b.destination.length);
 fs.writeFileSync(incomplete,key,{flag:'wx',mode:0o600});
 for(const move of moves){
  if(moves.some(parent=>parent!==move&&move.destination.startsWith(parent.destination+'/')))continue;
  fs.mkdirSync(path.dirname(move.destination),{recursive:true,mode:0o700});
  fs.cpSync(move.source,move.destination,{recursive:true,errorOnExist:true,force:false,verbatimSymlinks:true});
 }
 fs.writeFileSync(completed,JSON.stringify({manifestKey:key,sha256:manifest.sha256}),{flag:'wx',mode:0o600});
 fs.unlinkSync(incomplete);
 console.log('Verified OpenClaw state activated into the empty volume');
}else throw new Error('Unknown archive operation');
