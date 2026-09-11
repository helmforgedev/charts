// SPDX-License-Identifier: Apache-2.0
import fs from 'node:fs';
import path from 'node:path';
const state='/home/node/.openclaw';
const policy=process.env.CONFIG_POLICY;
if(!['managed','seed'].includes(policy))throw new Error('Invalid configuration policy');
function directory(p){fs.mkdirSync(p,{recursive:true,mode:0o700});if(!fs.lstatSync(p).isDirectory())throw new Error('State path must be a directory');fs.chmodSync(p,0o700);}
directory(state);directory(path.join(state,'workspace'));directory('/home/node/.config');directory('/home/node/.config/openclaw');
for(const [source,target] of [['openclaw.json',path.join(state,'openclaw.json')],['AGENTS.md',path.join(state,'workspace/AGENTS.md')],['SOUL.md',path.join(state,'workspace/SOUL.md')]]){
 const data=fs.readFileSync('/helmforge/'+source);
 if(source!=='openclaw.json'&&!data.length)continue;
 if(fs.existsSync(target)){if(!fs.lstatSync(target).isFile())throw new Error('Managed configuration must be a regular file');if(policy==='seed')continue;}
 const tmp=target+'.helmforge-'+process.pid;
 try{fs.writeFileSync(tmp,data,{flag:'wx',mode:0o600});fs.renameSync(tmp,target);}finally{if(fs.existsSync(tmp))fs.unlinkSync(tmp);}
}
console.log('OpenClaw configuration initialized with '+policy+' ownership');
