// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createRequire} from 'node:module';
import {execFileSync,spawn} from 'node:child_process';
const require=createRequire('/app/package.json');
const {createClient}=await import(require.resolve('@libsql/client'));
fs.mkdirSync('/app/app-data/db',{recursive:true});
fs.mkdirSync('/app/app-data/documents',{recursive:true});
execFileSync('pnpm',['migrate:up:prod'],{cwd:'/app',env:process.env,stdio:'inherit',timeout:120000});
const db=createClient({url:process.env.DATABASE_URL,authToken:process.env.DATABASE_AUTH_TOKEN,encryptionKey:process.env.DATABASE_ENCRYPTION_KEY});
let count;
try{const result=await db.execute('SELECT COUNT(*) AS user_count FROM users');count=Number(result.rows[0].user_count);assert.ok(Number.isSafeInteger(count)&&count>=0);}finally{db.close();}
if(count>0){console.log('Existing instance preserved; bootstrap never resets accounts or passwords');process.exit(0);}
const child=spawn('node',['dist/index.js'],{cwd:'/app',env:{...process.env,SERVER_HOSTNAME:'127.0.0.1',AUTH_IS_REGISTRATION_ENABLED:'true',AUTH_FIRST_USER_AS_ADMIN:'true'},stdio:['ignore','pipe','pipe']});
let diagnostics='',spawnError;child.on('error',error=>{spawnError=error;});for(const stream of [child.stdout,child.stderr])stream.on('data',data=>{diagnostics=(diagnostics+data).slice(-16000);});
const base='http://127.0.0.1:'+process.env.PORT;
try{
 const deadline=Date.now()+120000;let ready=false;
 while(Date.now()<deadline&&child.exitCode===null&&child.signalCode===null&&!spawnError){try{const response=await fetch(base+'/api/health',{signal:AbortSignal.timeout(3000)});if(response.ok&&(await response.json()).isEverythingOk){ready=true;break;}}catch{}await new Promise(r=>setTimeout(r,200));}
 assert.ok(ready,'Private bootstrap did not become healthy: '+(spawnError?.message??diagnostics));
 const password=fs.readFileSync('/bootstrap-auth/password','utf8');
 const headers={'Content-Type':'application/json',Origin:process.env.APP_BASE_URL};
 const response=await fetch(base+'/api/auth/sign-up/email',{method:'POST',headers,body:JSON.stringify({email:process.env.BOOTSTRAP_EMAIL,name:process.env.BOOTSTRAP_NAME,password}),signal:AbortSignal.timeout(15000)});
 assert.equal(response.status,200,'Native initial signup must succeed');
 const login=await fetch(base+'/api/auth/sign-in/email',{method:'POST',headers,body:JSON.stringify({email:process.env.BOOTSTRAP_EMAIL,password}),signal:AbortSignal.timeout(15000)});
 assert.equal(login.status,200,'Initial account must authenticate');
 const cookie=login.headers.getSetCookie().map(value=>value.split(';')[0]).join('; ');assert.ok(cookie);
 const permissionDeadline=Date.now()+30000;let administrator=false;
 while(Date.now()<permissionDeadline){const response=await fetch(base+'/api/users/me',{headers:{Cookie:cookie},signal:AbortSignal.timeout(5000)});assert.equal(response.status,200);const {user}=await response.json();if(user.permissions.includes('bo:access')&&user.permissions.includes('users:view')){administrator=true;break;}await new Promise(r=>setTimeout(r,250));}
 assert.ok(administrator,'Native first-user event must grant administrator permissions');
 console.log('Initial administrator created and verified on loopback before public exposure');
}finally{
 if(child.exitCode===null&&child.signalCode===null&&!spawnError){child.kill('SIGTERM');const deadline=Date.now()+30000;while(child.exitCode===null&&child.signalCode===null&&Date.now()<deadline)await new Promise(r=>setTimeout(r,100));if(child.exitCode===null&&child.signalCode===null){child.kill('SIGKILL');throw new Error('Private bootstrap server did not stop gracefully');}}
}
