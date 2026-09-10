// SPDX-License-Identifier: Apache-2.0
import fs from 'node:fs';
import {spawn} from 'node:child_process';
const port=process.env.MEMOS_PORT;
if(fs.existsSync('/database-runtime/dsn'))process.env.MEMOS_DSN=fs.readFileSync('/database-runtime/dsn','utf8');
const child=spawn('/bootstrap-bin/memos',[],{env:{...process.env,MEMOS_ADDR:'127.0.0.1'},stdio:['ignore','pipe','pipe']});
let diagnostics='';for(const stream of [child.stdout,child.stderr])stream.on('data',b=>{diagnostics=(diagnostics+b).slice(-16000);});
let spawnError;child.on('error',error=>{spawnError=error;});
const base='http://127.0.0.1:'+port;
const request=async(path,body)=>fetch(base+path,{...(body?{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)}:{}),signal:AbortSignal.timeout(5000)});
try {
 let ready=false;const deadline=Date.now()+120000;
 while(Date.now()<deadline&&child.exitCode===null&&!spawnError){try{if((await request('/healthz')).ok){ready=true;break;}}catch{}await new Promise(r=>setTimeout(r,250));}
 if(!ready)throw new Error('Private bootstrap listener did not become ready: '+(spawnError?.message||diagnostics));
 const profileResponse=await request('/api/v1/instance/profile');if(!profileResponse.ok)throw new Error('Unable to read native setup state');
 const profile=await profileResponse.json();
 if(typeof profile.version!=='string')throw new Error('Native instance profile is incomplete');
 if(profile.needsSetup===true){
  const password=fs.readFileSync('/bootstrap-auth/password','utf8');const username=process.env.BOOTSTRAP_USERNAME;
  const response=await request('/api/v1/users',{username,password,displayName:process.env.BOOTSTRAP_DISPLAY_NAME});
  if(!response.ok)throw new Error('Native administrator creation failed with HTTP '+response.status);
  const user=await response.json();if(user.role!=='ADMIN')throw new Error('Native bootstrap did not create ADMIN role');
  const login=await request('/api/v1/auth/signin',{passwordCredentials:{username,password}});if(!login.ok)throw new Error('New administrator cannot authenticate');
  console.log('Initial administrator created and authenticated on loopback before public exposure');
 }else if(profile.needsSetup===false||profile.needsSetup===undefined){
  // Protobuf JSON can omit the default false field. The instance profile endpoint succeeded.
  console.log('Existing instance preserved; no account or password reset');
 }else throw new Error('Unexpected native setup state');
}finally{
 if(child.exitCode===null&&!spawnError){child.kill('SIGTERM');const deadline=Date.now()+30000;while(child.exitCode===null&&Date.now()<deadline)await new Promise(r=>setTimeout(r,100));if(child.exitCode===null){child.kill('SIGKILL');throw new Error('Private bootstrap server did not shut down gracefully');}}
}
